/*===-- gupcr_lock_sup.c - UPC Runtime Support Library -------------------===
|*
|*                     The LLVM Compiler Infrastructure
|*
|* Copyright 2012-2014, Intel Corporation.  All rights reserved.
|* This file is distributed under a BSD-style Open Source License.
|* See LICENSE-INTEL.TXT for details.
|*
|*===---------------------------------------------------------------------===*/

#include "gupcr_config.h"
#include "gupcr_defs.h"
#include "gupcr_lib.h"
#include "gupcr_lock_sup.h"
#include "gupcr_sup.h"
#include "gupcr_fabric.h"
#include "gupcr_iface.h"
#include "gupcr_utils.h"
#include "gupcr_lock_sup.h"
#include "gupcr_runtime.h"

/**
 * @file gupcr_lock_sup.c
 * GUPC Libfabric locks implementation support routines.
 *
 * @addtogroup LOCK GUPCR Lock Functions
 * @{
 */

/** Index of the local memory location */
#define GUPCR_LOCAL_INDEX(addr) \
	(void *) ((char *) addr - (char *) USER_PROG_MEM_START)

/** Lock memory region counter */
static size_t gupcr_lock_lmr_count;
/** Lock memory remote access counter */
static size_t gupcr_lock_mr_count;

/** Lock buffer for CSWAP operation */
static char gupcr_lock_buf[16];

/** Fabric communications endpoint resources */
/** RX Endpoint comm resource  */
fab_ep_t gupcr_lock_rx_ep;
/** TX Endpoint comm resource  */
fab_ep_t gupcr_lock_tx_ep;
/** Completion remote counter (target side) */
fab_cntr_t gupcr_lock_ct;
/** Completion counter */
fab_cntr_t gupcr_lock_lct;
/** Completion remote queue (target side) */
fab_cq_t gupcr_lock_cq;
/** Completion queue for errors  */
fab_cq_t gupcr_lock_lcq;
/** Remote access memory region  */
fab_mr_t gupcr_lock_mr;
#if MR_LOCAL_NEEDED
/** Local memory access memory region  */
fab_mr_t gupcr_lock_lmr;
#endif

/** Lock endpoint */
fab_ep_t gupcr_lock_ep;
#if !GUPCR_FABRIC_SCALABLE_CTX
/** Address vector for remote endpoints  */
fab_av_t gupcr_lock_av;
/** Lock endpoint names  */
char *gupcr_lock_epnames;
#endif

/** Target endpoint */
#if GUPCR_FABRIC_SCALABLE_CTX
#define GUPCR_TARGET_ADDR(target) \
	fi_rx_addr ((fi_addr_t)target, \
	GUPCR_SERVICE_LOCK, GUPCR_SERVICE_BITS)
#else
#define GUPCR_TARGET_ADDR(target) \
	fi_rx_addr ((fi_addr_t)target, 0, 1)
#endif

/**
 * Execute lock-related atomic fetch and store remote operation.
 *
 * Value "val" is written into the specified remote location and the
 * old value is returned.
 *
 * A fabric 'atomic write' operation is used when the acquiring thread must
 * atomically determine if the lock is available.  A pointer to the thread's
 * local lock waiting list link is atomically written into the lock's 'last'
 * field, and the current value of the 'last' field is returned.  If NULL,
 * the acquiring thread is the new owner, otherwise it must insert itself
 * onto the waiting list.
 *
 * NOTE: Libfabric atomic type is determined from the argument 'size'.
 *       Only one element of that size is being used.
 */
void
gupcr_lock_swap (size_t dest_thread,
		 size_t dest_offset, void *val, void *old, size_t size)
{
  int status;
  gupcr_debug (FC_LOCK, "%lu:0x%lx",
	       (long unsigned) dest_thread, (long unsigned) dest_offset);
  gupcr_fabric_call (fi_fetch_atomic,
		     (gupcr_lock_tx_ep, GUPCR_LOCAL_INDEX (val), 1,
		      NULL, GUPCR_LOCAL_INDEX (old),
		      NULL, GUPCR_TARGET_ADDR (dest_thread),
		      dest_offset, GUPCR_MR_LOCK, gupcr_get_atomic_datatype (size),
		      FI_ATOMIC_WRITE, NULL));

  gupcr_lock_lmr_count += 1;
  gupcr_fabric_call_nc (fi_cntr_wait, status,
			(gupcr_lock_lct, gupcr_lock_lmr_count,
			 GUPCR_TRANSFER_TIMEOUT));
  GUPCR_CNT_ERROR_CHECK (status, "lock_swap", gupcr_lock_lcq);
}

/**
 * Execute a lock-related atomic compare and swap operation.
 *
 * The value  pointed to by 'val' is written into the remote location
 * given by ('dest_thread', 'dest_addr) only if value in the destination
 * is identical to 'cmp'.
 *
 * A fabric compare and swap atomic operation is used during the lock
 * release phase when the owner of the lock must atomically determine if
 * there are threads waiting on the lock.  This is accomplished by using
 * the fabric FI_CSWAP atomic operation, where a NULL pointer is written
 * into the lock's 'last' field only if this field contains the pointer
 * to the owner's local lock link structure.
 *
 * NOTE: Libfabric atomic type is determined from the argument 'size'.
 *       Only one element of that size is being used.
 *
 * @retval Return TRUE if the operation was successful.
 */

int
gupcr_lock_cswap (size_t dest_thread,
		  size_t dest_offset, void *cmp, void *val, size_t size)
{
  int status;
  gupcr_debug (FC_LOCK, "%lu:0x%lx",
	       (long unsigned) dest_thread, (long unsigned) dest_offset);

  gupcr_fabric_call (fi_compare_atomic,
		     (gupcr_lock_tx_ep, GUPCR_LOCAL_INDEX (val), 1,
		      NULL, GUPCR_LOCAL_INDEX (cmp),
		      NULL, GUPCR_LOCAL_INDEX (gupcr_lock_buf),
		      NULL, GUPCR_TARGET_ADDR (dest_thread),
		      dest_offset, GUPCR_MR_LOCK, gupcr_get_atomic_datatype (size),
		      FI_CSWAP, NULL));

  gupcr_lock_lmr_count += 1;
  gupcr_fabric_call_nc (fi_cntr_wait, status,
			(gupcr_lock_lct, gupcr_lock_lmr_count,
			 GUPCR_TRANSFER_TIMEOUT));
  GUPCR_CNT_ERROR_CHECK (status, "lock_cswap", gupcr_lock_lcq);
  return !memcmp (cmp, gupcr_lock_buf, size);
}

/*
 * Execute a network put operation on the lock-related NC.
 *
 * Execute a put operation on the NC that is reserved for
 * lock-related operations.  This separate NC is used
 * to make it possible to count only put operations on the
 * 'signal' or 'next' words of a UPC lock wait list entry.
 *
 * gupcr_lock_put() is used to 'signal' the remote thread that:
 * - ownership of the lock is passed to a remote thread if the remote
 * thread is the next thread on the waiting list
 * - a pointer to the calling thread's local control block has
 * been appended to the lock's waiting list
 */
void
gupcr_lock_put (size_t dest_thread, size_t dest_addr, void *val, size_t size)
{
  int status;
  gupcr_debug (FC_LOCK, "%lu:0x%lx",
	       (long unsigned) dest_thread, (long unsigned) dest_addr);
  if (size <= GUPCR_MAX_OPTIM_SIZE)
    {
      gupcr_fabric_call (fi_inject_write,
			 (gupcr_lock_tx_ep, GUPCR_LOCAL_INDEX (val), size,
			  GUPCR_TARGET_ADDR (dest_thread),
			  dest_addr, GUPCR_MR_LOCK));
    }
  else
    {
      gupcr_fabric_call (fi_write,
			 (gupcr_lock_tx_ep, GUPCR_LOCAL_INDEX (val), size,
			  NULL, GUPCR_TARGET_ADDR (dest_thread), dest_addr,
			  GUPCR_MR_LOCK, NULL));
    }
  gupcr_lock_lmr_count += 1;
  gupcr_fabric_call_nc (fi_cntr_wait, status,
			(gupcr_lock_lct, gupcr_lock_lmr_count,
			 GUPCR_TRANSFER_TIMEOUT));
  GUPCR_CNT_ERROR_CHECK (status, "lock_put", gupcr_lock_lcq);
}

/*
 * Execute a get operation on the lock-related NC.
 *
 * All operations on lock/link data structures must be performed
 * through the network interface to prevent data tearing.
 */
void
gupcr_lock_get (size_t dest_thread, size_t dest_addr, void *val, size_t size)
{
  int status;
  char *loc_addr = (char *) val - (size_t) USER_PROG_MEM_START;

  gupcr_debug (FC_LOCK, "%lu:0x%lx",
	       (long unsigned) dest_thread, (long unsigned) dest_addr);
  gupcr_fabric_call (fi_read,
		     (gupcr_lock_tx_ep, GUPCR_LOCAL_INDEX (loc_addr), size,
		      NULL, GUPCR_TARGET_ADDR (dest_thread), dest_addr,
		      GUPCR_MR_LOCK, NULL));
  gupcr_lock_lmr_count += 1;
  gupcr_fabric_call_nc (fi_cntr_wait, status,
			(gupcr_lock_lct, gupcr_lock_lmr_count,
			 GUPCR_TRANSFER_TIMEOUT));
  GUPCR_CNT_ERROR_CHECK (status, "lock_get", gupcr_lock_lcq);
}

/**
 * Wait for the next counting event to be posted to lock NC.
 *
 * This function is called when it has been determined that
 * the current thread needs to wait until the lock is is released.
 *
 * Wait until the next counting event is posted
 * to the MR reserved for this purpose and then return.
 * The caller will check whether the lock was in fact released,
 * and if not, will call this function again to wait for the
 * next lock-related event to come in.
 */
void
gupcr_lock_wait (void)
{
  int status;
  gupcr_debug (FC_LOCK, "");
  gupcr_lock_mr_count++;
  gupcr_fabric_call_nc (fi_cntr_wait, status,
			(gupcr_lock_ct, gupcr_lock_mr_count,
			 GUPCR_TRANSFER_TIMEOUT));
  GUPCR_CNT_ERROR_CHECK (status, "lock_wait", gupcr_lock_cq);
}

/**
 * Initialize lock resources.
 * @ingroup INIT
 */
void
gupcr_lock_init (void)
{
  int sep_ctx;
  cntr_attr_t cntr_attr = { 0 };
  cq_attr_t cq_attr = { 0 };
  tx_attr_t tx_attr = { 0 };
  rx_attr_t rx_attr = { 0 };

  gupcr_log (FC_LOCK, "lock init called");

  /* Create context endpoints for LOC transfers.  */
#if GUPCR_FABRIC_SCALABLE_CTX
  gupcr_lock_ep = gupcr_ep;
  sep_ctx = GUPCR_SERVICE_LOCK;
#else
  gupcr_lock_ep = gupcr_fabric_endpoint ("lock", &gupcr_lock_epnames, &gupcr_lock_av);
  sep_ctx = 0;
#endif
  tx_attr.op_flags = FI_DELIVERY_COMPLETE;
  gupcr_fabric_call (fi_tx_context,
		     (gupcr_lock_ep, sep_ctx, &tx_attr, &gupcr_lock_tx_ep,
		      NULL));
  gupcr_fabric_call (fi_rx_context,
		     (gupcr_lock_ep, sep_ctx, &rx_attr, &gupcr_lock_rx_ep,
		      NULL));

  /* ... and completion counter/eq for remote read/write.  */
  cntr_attr.events = FI_CNTR_EVENTS_COMP;
  cntr_attr.flags = 0;
  gupcr_fabric_call (fi_cntr_open, (gupcr_fd, &cntr_attr,
				    &gupcr_lock_lct, NULL));
  gupcr_fabric_call (fi_ep_bind, (gupcr_lock_tx_ep, &gupcr_lock_lct->fid,
				  FI_READ | FI_WRITE));
  gupcr_lock_lmr_count = 0;
  gupcr_lock_mr_count = 0;

  /* ... and completion queue for remote target transfer errors.  */
  cq_attr.size = 1;
  cq_attr.format = FI_CQ_FORMAT_MSG;
  cq_attr.wait_obj = FI_WAIT_NONE;
  gupcr_fabric_call (fi_cq_open, (gupcr_fd, &cq_attr, &gupcr_lock_lcq, NULL));
  /* Use FI_SELECTIVE_COMPLETION flag to report errors only.  */
  gupcr_fabric_call (fi_ep_bind, (gupcr_lock_tx_ep, &gupcr_lock_lcq->fid,
				  FI_WRITE | FI_READ |
				  FI_SELECTIVE_COMPLETION));

#if LOCAL_MR_NEEDED
  /* NOTE: Create a local memory region before enabling endpoint.  */
  /* ... and memory region for local memory accesses.  */
  gupcr_fabric_call (fi_mr_reg, (gupcr_fd, USER_PROG_MEM_START,
				 USER_PROG_MEM_SIZE, FI_READ | FI_WRITE,
				 0, 0, 0, &gupcr_lock_lmr, NULL));
  /* NOTE: There is no need to bind local memory region to endpoint.  */
  /*       Hmm ... ? We can probably use only one throughout the runtime,  */
  /*       as counters and events are bound to endpoint.  */
  gupcr_fabric_call (fi_ep_bind, (gupcr_lock_tx_ep, &gupcr_lock_lmr->fid,
				  FI_READ | FI_WRITE));
#endif

  /* Enable TX endpoint.  */
  gupcr_fabric_call (fi_enable, (gupcr_lock_tx_ep));

  /* ... and memory region for remote inbound accesses.  */
  gupcr_fabric_call (fi_mr_reg, (gupcr_fd, gupcr_gmem_base, gupcr_gmem_size,
				 FI_REMOTE_READ | FI_REMOTE_WRITE, 0,
				 GUPCR_MR_LOCK, 0, &gupcr_lock_mr, NULL));
  /* ... and counter for remote inbound writes.  */
  cntr_attr.events = FI_CNTR_EVENTS_COMP;
  cntr_attr.flags = 0;
  gupcr_fabric_call (fi_cntr_open, (gupcr_fd, &cntr_attr,
				    &gupcr_lock_ct, NULL));
  gupcr_fabric_call (fi_mr_bind, (gupcr_lock_mr, &gupcr_lock_ct->fid,
				  FI_REMOTE_WRITE));
  /* ... and completion queue for remote inbound errors.  */
  cq_attr.size = 1;
  cq_attr.format = FI_CQ_FORMAT_MSG;
  cq_attr.wait_obj = FI_WAIT_NONE;
  gupcr_fabric_call (fi_cq_open, (gupcr_fd, &cq_attr, &gupcr_lock_cq, NULL));
  gupcr_fabric_call (fi_mr_bind, (gupcr_lock_mr, &gupcr_lock_cq->fid,
			          FI_REMOTE_WRITE | FI_SELECTIVE_COMPLETION));
  /* Enable RX endpoint and bind MR.  */
  gupcr_fabric_call (fi_enable, (gupcr_lock_rx_ep));
  gupcr_fabric_call (fi_ep_bind, (gupcr_lock_rx_ep, &gupcr_lock_mr->fid,
			          FI_REMOTE_READ | FI_REMOTE_WRITE));
  gupcr_log (FC_LOCK, "lock init completed");

  /* Initialize link blocks.  */
  gupcr_lock_link_init ();
  /* Initialize the lock free list.  */
  gupcr_lock_free_init ();
  /* Initialize the heap allocator locks.  */
  gupcr_lock_heap_sup_init ();
}

/**
 * Release lock resources.
 * @ingroup INIT
 */
void
gupcr_lock_fini (void)
{
  int status;
  gupcr_log (FC_LOCK, "lock fini called");
  gupcr_fabric_call (fi_close, (&gupcr_lock_ct->fid));
  gupcr_fabric_call (fi_close, (&gupcr_lock_lct->fid));
  gupcr_fabric_call (fi_close, (&gupcr_lock_cq->fid));
  gupcr_fabric_call (fi_close, (&gupcr_lock_mr->fid));
#if LOCAL_MR_NEEDED
  gupcr_fabric_call (fi_close, (&gupcr_lock_lmr->fid));
#endif
  /* NOTE: Do not check for errors.  Fails occasionally.  */
#if 0
  gupcr_fabric_call_nc (fi_close, status, (&gupcr_lock_rx_ep->fid));
  gupcr_fabric_call_nc (fi_close, status, (&gupcr_lock_tx_ep->fid));
#endif
#if !GUPCR_FABRIC_SCALABLE_CTX
  gupcr_fabric_call_nc (fi_close, status, (&gupcr_lock_ep->fid));
  gupcr_fabric_call_nc (fi_close, status, (&gupcr_lock_av->fid));
  free (gupcr_lock_epnames);
#endif
}

/** @} */