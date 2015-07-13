/*===-- gupcr_gmem.c - UPC Runtime Support Library -----------------------===
|*
|*                     The LLVM Compiler Infrastructure
|*
|* Copyright 2012-2014, Intel Corporation.  All rights reserved.
|* This file is distributed under a BSD-style Open Source License.
|* See LICENSE-INTEL.TXT for details.
|*
|*===---------------------------------------------------------------------===*/

/**
 * @file gupcr_gmem.c
 * GUPC Libfabric shared memory interface.
 */

/**
 * @addtogroup GMEM GUPCR Shared Memory Access
 * @{
 */

#include "gupcr_config.h"
#include "gupcr_defs.h"
#include "gupcr_sup.h"
#include "gupcr_fabric.h"
#include "gupcr_node.h"
#include "gupcr_gmem.h"
#include "gupcr_utils.h"
#include "gupcr_sync.h"
#include "gupcr_runtime.h"
#include "gupcr_iface.h"

/** Thread's default shared heap size */
#define GUPCR_GMEM_DEFAULT_HEAP_SIZE 256*1024*1024
/** Index of the local memory location */
#define GUPCR_LOCAL_INDEX(addr) \
	(void *) ((char *) addr - (char *) USER_PROG_MEM_START)

/** Shared memory base and size */
void *gupcr_gmem_base;
size_t gupcr_gmem_size;

/** GET event tracking */
gupcr_gmem_xfer_info_t gupcr_gmem_gets;
/** PUT event tracking */
gupcr_gmem_xfer_info_t gupcr_gmem_puts;

/** PUT "bounce buffer" type */
typedef char gupcr_gmem_put_bb_t[GUPCR_BOUNCE_BUFFER_SIZE];
/** PUT "bounce buffer" space */
static gupcr_gmem_put_bb_t gupcr_gmem_put_bb;
/** PUT "bounce buffer" used counter */
size_t gupcr_gmem_put_bb_used;

/** Previous operation was a strict put */
int gupcr_pending_strict_put;

/** Heap base offset relative to start of UPC shared region */
size_t gupcr_gmem_heap_base_offset;

/** Size of UPC shared region reserved for the heap */
size_t gupcr_gmem_heap_size;

/** Remote puts flow control */
static const size_t gupcr_gmem_high_mark_puts = GUPCR_MAX_OUTSTANDING_PUTS;
static const size_t gupcr_gmem_low_mark_puts = GUPCR_MAX_OUTSTANDING_PUTS / 2;

/** Fabric communications contextual endpoint resources */
/** RX Endpoint comm resource  */
fab_ep_t gupcr_gmem_rx_ep;
/** TX Endpoint comm resource  */
fab_ep_t gupcr_gmem_tx_ep;
/** Completion queue for errors  */
fab_cq_t gupcr_gmem_cq;
/** Remote access memory region  */
fab_mr_t gupcr_gmem_mr;
#if MR_LOCAL_NEEDED
/** Local memory access memory region  */
fab_mr_t gupcr_gmem_lmr;
#endif

/**
 * Allocate memory for this thread's shared space contribution.
 *
 * Calculate needed memory size and let the node allocate
 * shared memory and map other thread's shared memory into
 * the current thread memory space.
 */
static void
gupcr_gmem_alloc_shared (void)
{
  size_t heap_size = GUPCR_ROUND (gupcr_get_shared_heap_size (), C64K);
  size_t data_size = GUPCR_ROUND (GUPCR_SHARED_SECTION_END -
				  GUPCR_SHARED_SECTION_START, C64K);
  gupcr_gmem_heap_base_offset = data_size;
  gupcr_gmem_heap_size = heap_size;
  gupcr_gmem_size = heap_size + data_size;

  /* Allocate this thread's shared space.  */
  gupcr_gmem_base = gupcr_node_local_alloc (gupcr_gmem_size);
}

/**
 * Complete all outstanding remote GET operations.
 *
 * This procedure waits for all outstanding GET operations
 * to complete.  If the wait on the GET counting event returns
 * a failure, a full event queue is checked for failure specifics
 * and the program aborts.
 */
void
gupcr_gmem_sync_gets (void)
{
  int status;
  /* Sync all outstanding local accesses.  */
  GUPCR_MEM_BARRIER ();
  /* Sync all outstanding remote get accesses.  */
  if (gupcr_gmem_gets.num_pending > 0)
    {
      size_t num_initiated =
	gupcr_gmem_gets.num_completed + gupcr_gmem_gets.num_pending;
      gupcr_debug (FC_MEM, "outstanding gets: %lu",
		   (long unsigned) gupcr_gmem_gets.num_pending);
      gupcr_fabric_call_nc (fi_cntr_wait, status,
			    (gupcr_gmem_gets.ct_handle, num_initiated,
			     GUPCR_TRANSFER_TIMEOUT));
      GUPCR_CNT_ERROR_CHECK (status, "sync gets", gupcr_gmem_cq);
      gupcr_gmem_gets.num_pending = 0;
      gupcr_gmem_gets.num_completed = num_initiated;
    }
}

/**
 * Complete outstanding remote PUT operations.
 *
 * This procedure waits for all outstanding PUT operations
 * to complete.  If the wait on the Portals PUT counting event returns
 * a failure, a full event queue is checked for failure specifics
 * and the program aborts.
 */
void
gupcr_gmem_sync_puts (void)
{
  int status;
  /* Sync all outstanding local accesses.  */
  GUPCR_MEM_BARRIER ();
  /* Sync all outstanding remote put accesses.  */
  if (gupcr_gmem_puts.num_pending > 0)
    {
      size_t num_initiated =
	gupcr_gmem_puts.num_completed + gupcr_gmem_puts.num_pending;
      gupcr_debug (FC_MEM, "outstanding puts: %lu",
		   (long unsigned) gupcr_gmem_puts.num_pending);
      gupcr_fabric_call_nc (fi_cntr_wait, status,
			    (gupcr_gmem_puts.ct_handle, num_initiated,
			     GUPCR_TRANSFER_TIMEOUT));
      GUPCR_CNT_ERROR_CHECK (status, "sync puts", gupcr_gmem_cq);
      gupcr_gmem_puts.num_pending = 0;
      gupcr_gmem_puts.num_completed = num_initiated;
      gupcr_pending_strict_put = 0;
      gupcr_gmem_put_bb_used = 0;
    }
}

/**
 * Complete all outstanding remote operations.
 *
 * Check and wait for completion of all PUT/GET operations.
 */
void
gupcr_gmem_sync (void)
{
  gupcr_gmem_sync_gets ();
  gupcr_gmem_sync_puts ();
}

/**
 * Read data from remote shared memory.
 *
 * A GET request is broken into multiple GET requests
 * if the number of requested bytes is greater then
 * the configuration limited maximum message size.
 *
 * @param [in] dest Local memory to receive remote data
 * @param [in] thread Remote thread to request data from
 * @param [in] offset Remote address
 * @param [in] n Number of bytes to transfer
 */
void
gupcr_gmem_get (void *dest, int thread, size_t offset, size_t n)
{
  char *loc_addr = (char *) dest - (size_t) USER_PROG_MEM_START;
  size_t dest_offset = offset;
  size_t n_rem = n;

  gupcr_debug (FC_MEM, "%d:0x%lx 0x%lx",
	       thread, (long unsigned) offset, (long unsigned) dest);
  while (n_rem > 0)
    {
      size_t n_xfer;
      n_xfer = GUPCR_MIN (n_rem, GUPCR_MAX_MSG_SIZE);
      ++gupcr_gmem_gets.num_pending;
      gupcr_fabric_call (fi_read,
			 (gupcr_gmem_tx_ep, loc_addr, n_xfer, NULL,
			  fi_rx_addr ((fi_addr_t) thread, GUPCR_SERVICE_GMEM,
				      GUPCR_SERVICE_BITS),
			  dest_offset, GUPCR_MR_GMEM, NULL));
      n_rem -= n_xfer;
      loc_addr += n_xfer;
      dest_offset += n_xfer;
    }
}

/**
 * Write data to remote shared memory.
 *
 * For data requests smaller then maximum safe size, the data is first
 * copied into a bounce buffer.  In this way, the put operation
 * can be non-blocking and there are no restrictions placed upon
 * the caller's use of the source data buffer.
 * Otherwise,  a synchronous operation is performed
 * and this function returns to the caller after the operation completes.
 *
 * @param [in] thread Destination thread
 * @param [in] offset Destination offset
 * @param [in] src Local source pointer to data
 * @param [in] n Number of bytes to transfer
 */
void
gupcr_gmem_put (int thread, size_t offset, const void *src, size_t n)
{
  int must_sync = (n > GUPCR_GMEM_MAX_SAFE_PUT_SIZE);
  char *src_addr = (char *) src;
  size_t n_rem = n;
  gupcr_debug (FC_MEM, "0x%lx %d:0x%lx",
	       (long unsigned) src, thread, (long unsigned) offset);
  /* Large puts must be synchronous, to ensure that it is
     safe to re-use the source buffer upon return.  */
  while (n_rem > 0)
    {
      size_t n_xfer;
      size_t local_offset;
      n_xfer = GUPCR_MIN (n_rem, GUPCR_MAX_MSG_SIZE);
      if (n_xfer <= GUPCR_MAX_OPTIM_SIZE)
	{
	  /* Use optimized version of RMA write.  */
	  gupcr_fabric_call (fi_inject_write,
			     (gupcr_gmem_tx_ep, GUPCR_LOCAL_INDEX (src_addr),
			      n_xfer, fi_rx_addr ((fi_addr_t) thread,
						  GUPCR_SERVICE_GMEM,
						  GUPCR_SERVICE_BITS), offset,
			      GUPCR_MR_GMEM));
	}
      else
	{
	  if (must_sync)
	    {
	      local_offset = src_addr - (char *) USER_PROG_MEM_START;
	    }
	  else
	    {
	      char *bounce_buf;
	      /* If this transfer will overflow the bounce buffer,
	         then first wait for all outstanding puts to complete.  */
	      if ((gupcr_gmem_put_bb_used + n_xfer) >
		  GUPCR_BOUNCE_BUFFER_SIZE)
		gupcr_gmem_sync_puts ();
	      bounce_buf = &gupcr_gmem_put_bb[gupcr_gmem_put_bb_used];
	      memcpy (bounce_buf, src_addr, n_xfer);
	      local_offset = (size_t) bounce_buf;
	      gupcr_gmem_put_bb_used += n_xfer;
	    }
	  gupcr_fabric_call (fi_write,
			     (gupcr_gmem_tx_ep,
			      GUPCR_LOCAL_INDEX (local_offset), n_xfer, NULL,
			      fi_rx_addr ((fi_addr_t) thread,
					  GUPCR_SERVICE_GMEM,
					  GUPCR_SERVICE_BITS), offset,
			      GUPCR_MR_GMEM, NULL));
	}
      n_rem -= n_xfer;
      src_addr += n_xfer;
      ++gupcr_gmem_puts.num_pending;
      if (gupcr_gmem_puts.num_pending == gupcr_gmem_high_mark_puts)
	{
	  int status;
	  size_t wait_cnt = gupcr_gmem_puts.num_completed
	    + gupcr_gmem_puts.num_pending - gupcr_gmem_low_mark_puts;
	  gupcr_fabric_call_nc (fi_cntr_wait, status,
				(gupcr_gmem_puts.ct_handle, wait_cnt,
				 GUPCR_TRANSFER_TIMEOUT));
          GUPCR_CNT_ERROR_CHECK (status, "gmem put", gupcr_gmem_cq);
	  gupcr_gmem_puts.num_pending -= wait_cnt -
	    gupcr_gmem_puts.num_completed;
	  gupcr_gmem_puts.num_completed = wait_cnt;
	}
    }
  if (must_sync)
    gupcr_gmem_sync_puts ();
}

/**
 * Copy remote shared memory from the source thread
 * to the destination thread.
 *
 * Bulk copy from one thread to another.
 * The put bounce buffer is used as an intermediate buffer.
 * Caller assumes responsibility for checking the validity
 * of the remote thread id's and/or shared memory offsets.
 *
 * @param [in] dthread Destination thread
 * @param [in] doffset Destination offset
 * @param [in] sthread Source thread
 * @param [in] soffset Source offset
 * @param [in] n Number of bytes to transfer
 */
void
gupcr_gmem_copy (int dthread, size_t doffset,
		 int sthread, size_t soffset, size_t n)
{
  size_t n_rem = n;
  size_t dest_addr = doffset;
  size_t src_addr = soffset;
  gupcr_debug (FC_MEM, "%d:0x%lx %d:0x%lx %lu",
	       sthread, (long unsigned) soffset,
	       dthread, (long unsigned) doffset, (long unsigned) n);
  while (n_rem > 0)
    {
      size_t n_xfer;
      char *bounce_buf;
      size_t local_offset;
      /* Use the entire put "bounce buffer" if the transfer
         count is sufficiently large.  */
      n_xfer = GUPCR_MIN (n_rem, GUPCR_BOUNCE_BUFFER_SIZE);
      if ((gupcr_gmem_put_bb_used + n_xfer) > GUPCR_BOUNCE_BUFFER_SIZE)
	gupcr_gmem_sync_puts ();
      bounce_buf = &gupcr_gmem_put_bb[gupcr_gmem_put_bb_used];
      gupcr_gmem_put_bb_used += n_xfer;
      /* Read the source data into the bounce buffer.  */
      gupcr_gmem_get (bounce_buf, sthread, src_addr, n_xfer);
      gupcr_gmem_sync_gets ();
      local_offset = (size_t) bounce_buf;
      ++gupcr_gmem_puts.num_pending;
      gupcr_fabric_call (fi_write,
			 (gupcr_gmem_tx_ep,
			  GUPCR_LOCAL_INDEX (local_offset), n_xfer, NULL,
			  fi_rx_addr ((fi_addr_t) dthread,
				      GUPCR_SERVICE_GMEM,
				      GUPCR_SERVICE_BITS), dest_addr,
			  GUPCR_MR_GMEM, NULL));
      n_rem -= n_xfer;
      src_addr += n_xfer;
      dest_addr += n_xfer;
    }
}

/**
 * Write the same byte value into the bytes of the
 * destination thread's memory at the specified offset.
 *
 * The put bounce buffer is used as an intermediate buffer.
 * The last write of a chunk of data is non-blocking.
 * Caller assumes responsibility for checking the validity
 * of the remote thread id's and/or shared memory offsets.
 *
 * @param [in] thread Destination thread
 * @param [in] offset Destination offset
 * @param [in] c Set value
 * @param [in] n Number of bytes to transfer
 */
void
gupcr_gmem_set (int thread, size_t offset, int c, size_t n)
{
  size_t n_rem = n;
  int already_filled = 0;
  size_t dest_addr = offset;
  gupcr_debug (FC_MEM, "0x%x %d:0x%lx %lu", c, thread,
	       (long unsigned) offset, (long unsigned) n);
  while (n_rem > 0)
    {
      size_t n_xfer;
      char *bounce_buf;
      size_t local_offset;
      /* Use the entire put "bounce buffer" if the transfer
         count is sufficiently large.  */
      n_xfer = GUPCR_MIN (n_rem, (size_t) GUPCR_BOUNCE_BUFFER_SIZE);
      if ((gupcr_gmem_put_bb_used + n_xfer) > GUPCR_BOUNCE_BUFFER_SIZE)
	gupcr_gmem_sync_puts ();
      bounce_buf = &gupcr_gmem_put_bb[gupcr_gmem_put_bb_used];
      gupcr_gmem_put_bb_used += n_xfer;
      /* Fill the bounce buffer, if we haven't already.  */
      if (!already_filled)
	{
	  memset (bounce_buf, c, n_xfer);
	  already_filled = (bounce_buf == gupcr_gmem_put_bb
			    && n_xfer == GUPCR_BOUNCE_BUFFER_SIZE);
	}
      local_offset = (size_t) bounce_buf;
      ++gupcr_gmem_puts.num_pending;
      gupcr_fabric_call (fi_write,
			 (gupcr_gmem_tx_ep, GUPCR_LOCAL_INDEX (local_offset),
			  n_xfer, NULL, fi_rx_addr ((fi_addr_t) thread,
						    GUPCR_SERVICE_GMEM,
						    GUPCR_SERVICE_BITS),
			  dest_addr, GUPCR_MR_GMEM, NULL));
      n_rem -= n_xfer;
      dest_addr += n_xfer;
    }
}

/**
 * Initialize gmem resources.
 * @ingroup INIT
 */
void
gupcr_gmem_init (void)
{
  cntr_attr_t cntr_attr = { 0 };
  cq_attr_t cq_attr = { 0 };
  tx_attr_t tx_attr = { 0 };
  rx_attr_t rx_attr = { 0 };

  gupcr_log (FC_MEM, "gmem init called");

  /* Allocate memory for this thread's contribution to shared memory.  */
  gupcr_gmem_alloc_shared ();

  /* Create context endpoints for LOC transfers.  */
  tx_attr.op_flags = FI_DELIVERY_COMPLETE;
  /* Create context endpoints for GMEM transfers.  */
  gupcr_fabric_call (fi_tx_context,
		     (gupcr_ep, GUPCR_SERVICE_GMEM, &tx_attr, &gupcr_gmem_tx_ep,
		      NULL));
  gupcr_fabric_call (fi_rx_context,
		     (gupcr_ep, GUPCR_SERVICE_GMEM, &rx_attr, &gupcr_gmem_rx_ep,
		      NULL));

  /* NOTE: for read/write we create counters and event queues. EQs are supposed
     to be used for errors only, but at this time it is not clear how.  It is
     also not clear how do we detect an error, at this point it seems that we
     just hang if remote operation does not complete.  */

  /* ... and completion counter/eq for remote reads.  */
  gupcr_gmem_gets.num_pending = 0;
  gupcr_gmem_gets.num_completed = 0;

  cntr_attr.events = FI_CNTR_EVENTS_COMP;
  cntr_attr.flags = 0;
  gupcr_fabric_call (fi_cntr_open, (gupcr_fd, &cntr_attr,
				    &gupcr_gmem_gets.ct_handle, NULL));
  gupcr_fabric_call (fi_ep_bind, (gupcr_gmem_tx_ep,
			          &gupcr_gmem_gets.ct_handle->fid, FI_READ));

  /* ... and completion counter/eq for remote writes.  */
  gupcr_gmem_puts.num_pending = 0;
  gupcr_gmem_puts.num_completed = 0;
  cntr_attr.events = FI_CNTR_EVENTS_COMP;
  cntr_attr.flags = 0;
  gupcr_fabric_call (fi_cntr_open, (gupcr_fd, &cntr_attr,
				    &gupcr_gmem_puts.ct_handle, NULL));
  gupcr_fabric_call (fi_ep_bind, (gupcr_gmem_tx_ep,
			          &gupcr_gmem_puts.ct_handle->fid, FI_WRITE));

  /* Create completion queue for remote target transfer errors.  There
     is only one completion queue for read and writes and minimum
     size of one message is enough for error reporting.  */
  cq_attr.size = 1;
  cq_attr.format = FI_CQ_FORMAT_MSG;
  cq_attr.wait_obj = FI_WAIT_NONE;
  gupcr_fabric_call (fi_cq_open, (gupcr_fd, &cq_attr, &gupcr_gmem_cq, NULL));
  /* Use FI_SELECTIVE_COMPLETION flag to report errors only.  */
  gupcr_fabric_call (fi_ep_bind, (gupcr_gmem_tx_ep,
			          &gupcr_gmem_cq->fid,
			          FI_WRITE | FI_READ |
				  FI_SELECTIVE_COMPLETION));

#if LOCAL_MR_NEEDED
  /* Create a memory region for local memory accesses.  */
  gupcr_fabric_call (fi_mr_reg, (gupcr_fd, USER_PROG_MEM_START,
				 USER_PROG_MEM_SIZE, FI_READ | FI_WRITE,
				 0, 0, 0, &gupcr_gmem_lmr, NULL));
  /* NOTE: No need to bind, it is done implictly.  */
  gupcr_fabric_call (fi_ep_bind, (gupcr_gmem_tx_ep,
			          &gupcr_gmem_lmr->fid, FI_READ | FI_WRITE));
#endif
  gupcr_fabric_call (fi_enable, (gupcr_gmem_tx_ep));

  /* Create a memory region for remote inbound accesses.  */
  gupcr_fabric_call (fi_mr_reg, (gupcr_fd, gupcr_gmem_base, gupcr_gmem_size,
				 FI_REMOTE_READ | FI_REMOTE_WRITE, 0,
				 GUPCR_MR_GMEM, 0, &gupcr_gmem_mr, NULL));
  gupcr_fabric_call (fi_enable, (gupcr_gmem_rx_ep));
  gupcr_fabric_call (fi_ep_bind, (gupcr_gmem_rx_ep,
			          &gupcr_gmem_mr->fid,
			          FI_REMOTE_READ | FI_REMOTE_WRITE));
  gupcr_log (FC_MEM, "gmem created");
}

/**
 * Release gmem resources.
 * @ingroup INIT
 */
void
gupcr_gmem_fini (void)
{
  int status;
  gupcr_log (FC_MEM, "gmem fini called");
  gupcr_fabric_call (fi_close, (&gupcr_gmem_puts.ct_handle->fid));
  gupcr_fabric_call (fi_close, (&gupcr_gmem_gets.ct_handle->fid));
  gupcr_fabric_call (fi_close, (&gupcr_gmem_cq->fid));
  gupcr_fabric_call (fi_close, (&gupcr_gmem_mr->fid));
#if LOCAL_MR_NEEDED
  gupcr_fabric_call (fi_close, (&gupcr_gmem_lmr->fid));
#endif
  /* NOTE: Do not check for errors. Fails occasionally.  */
  gupcr_fabric_call_nc (fi_close, status, (&gupcr_gmem_tx_ep->fid));
  gupcr_fabric_call_nc (fi_close, status, (&gupcr_gmem_rx_ep->fid));
}

/** @} */