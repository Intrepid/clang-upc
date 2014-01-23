/*===-- upc_defs.h - UPC Runtime Support Library -------------------------===
|*
|*                     The LLVM Compiler Infrastructure
|*
|* Copyright 2012-2014, Intrepid Technology, Inc.  All rights reserved.
|* This file is distributed under a BSD-style Open Source License.
|* See LICENSE-INTREPID.TXT for details.
|*
|*===---------------------------------------------------------------------===*/

#ifndef _UPC_DEFS_H_
#define _UPC_DEFS_H_

#include "upc_pts.h"

//begin lib_max_threads_def
/* Maximum number of THREADS supported in this implementation */
#define GUPCR_THREAD_SIZE 12
#define GUPCR_THREADS_MAX (1 << GUPCR_THREAD_SIZE)
//end lib_max_threads_def

#if GUPCR_PTS_PACKED_REP && (GUPCR_THREADS_SIZE > GUPCR_PTS_THREAD_SIZE)
#error GUPCR_THREADS_MAX exceeds the size of the packed sptr threads field.
#endif


/* UPC thread-specific information */
typedef struct upc_thread_info_struct
  {
    pid_t pid;
    int sched_affinity;
    int mem_affinity;
#ifdef GUPCR_USE_PTHREADS
    pthread_t os_thread;
    int exit_status;
#endif
  } upc_thread_info_t;
typedef upc_thread_info_t *upc_thread_info_p;

#define GUPCR_PROCBITS_PER_WORD OS_BITS_PER_ATOMIC_WORD

#define GUPCR_NUM_PROCBIT_WORDS ((GUPCR_THREADS_MAX + (GUPCR_PROCBITS_PER_WORD - 1)) \
			    / GUPCR_PROCBITS_PER_WORD)

/* Bit vector used to manage processes */
typedef os_atomic_t upc_procbits_vec_t[GUPCR_NUM_PROCBIT_WORDS];

/* UPC thread barrier ID  */
extern GUPCR_THREAD_LOCAL int __upc_barrier_id;

/* There is one global page table per UPC program.
   The global page table maps (thread, page) into
   a global page number in the global memory region. */
typedef upc_page_num_t upc_pte_t;
typedef upc_pte_t *upc_pte_p;

/* scheduling policies */
enum upc_sched_policy_enum
  {
    GUPCR_SCHED_POLICY_AUTO,	/* kernel's scheduling policy */
    GUPCR_SCHED_POLICY_NODE,	/* schedule across nodes */
    GUPCR_SCHED_POLICY_CPU,	/* schedule across cpus - multiple threads per CPU */
    GUPCR_SCHED_POLICY_CPU_STRICT	/* schedule across cpus - one thread per CPU */
  };
typedef enum upc_sched_policy_enum upc_sched_policy_t;

/* Non-Uniform Memory Allocation */
enum upc_mem_policy_enum
  {
    GUPCR_MEM_POLICY_AUTO,	/* kernel's default NUMA policy */
    GUPCR_MEM_POLICY_NODE,	/* allocate memory from the local node first */
    GUPCR_MEM_POLICY_STRICT	/* allocate memory from the local node only */
  };
typedef enum upc_mem_policy_enum upc_mem_policy_t;

/* Data structure used keep track of cpu's that must ba avoided */
typedef struct upc_cpu_avoid_struct upc_cpu_avoid_t;
typedef upc_cpu_avoid_t *upc_cpu_avoid_p;

/* UPC system-wide information */
typedef struct upc_info_struct
  {
    char *program_name;
    char *host_name;
    pid_t monitor_pid;
    int partial_attach_start;
    os_heap_p runtime_heap;
    os_lock_t lock;
    upc_page_num_t init_page_alloc;
    upc_shared_ptr_t init_heap_base;
    size_t init_heap_size;
    int smem_fd;
    char *mmap_file_name;
    upc_pte_p gpt;
    upc_page_num_t cur_page_alloc;
    upc_shared_ptr_t all_lock;
    upc_thread_info_t thread_info[GUPCR_THREADS_MAX];
    int num_cpus;
    int num_nodes;
    upc_sched_policy_t sched_policy;
    upc_mem_policy_t mem_policy;
  } upc_info_t;
typedef upc_info_t *upc_info_p;

/* system wide info */
extern upc_info_p __upc_info;

/* The filename of the location where a runtime
   error was detected.  This is set by the various
   debug-enabled ('g') UPC runtime library routines.  */
extern GUPCR_THREAD_LOCAL const char *__upc_err_filename;

/* The line number of the location where a runtime
   error was detected.  This is set by the various
   debug-enabled ('g') UPC runtime library routines.  */
extern GUPCR_THREAD_LOCAL unsigned int __upc_err_linenum;

#define GUPCR_SET_ERR_LOC() \
  do \
    { \
      __upc_err_filename = filename; \
      __upc_err_linenum  = linenum; \
    } while (0)

#define GUPCR_CLEAR_ERR_LOC() \
  do \
    { \
      __upc_err_filename = NULL; \
      __upc_err_linenum  = 0; \
    } while (0)

/* The base address of the UPC shared section */
extern char GUPCR_SHARED_SECTION_START[1];

/* The ending address (plus one) of the UPC shared section */
extern char GUPCR_SHARED_SECTION_END[1];

/* The base address of the UPC compiled program info. section */
extern char GUPCR_PGM_INFO_SECTION_START[1];

/* The ending address (plus one) of the UPC compiled program info. section */
extern char GUPCR_PGM_INFO_SECTION_END[1];

#ifndef __UPC__
/* The value of THREADS when defined at run time */
extern int THREADS;

/* Current thread id */
extern GUPCR_THREAD_LOCAL int MYTHREAD;

#ifdef GUPCR_USE_PTHREADS
/* The value of UPC_PTHREADS when defined at run time */
extern int UPC_PTHREADS;
#endif

#endif

#endif /* _UPC_DEFS_H_ */
