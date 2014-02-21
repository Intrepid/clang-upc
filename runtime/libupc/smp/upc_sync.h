/*===-- upc_sync.h - UPC Runtime Support Library -------------------------===
|*
|*                     The LLVM Compiler Infrastructure
|*
|* Copyright 2012-2014, Intrepid Technology, Inc.  All rights reserved.
|* This file is distributed under a BSD-style Open Source License.
|* See LICENSE-INTREPID.TXT for details.
|*
|*===---------------------------------------------------------------------===*/

#ifndef _UPC_SYNC_H_
#define _UPC_SYNC_H_

//begin lib_fence_defs

/*

The following table is excerpted from
"Implementing the UPC memory consistency model for
shared-memory architectures", Dan Bonachea et al.

CPU		Write fence		Read fence
--------------------------------------------------
Power/PowerPC	lwsync			isync
Alpha		wmb			mb
x86		lock; addl $0,0(%%esp)  none reqd.
Athlon/Opteron	mfence			none reqd.
Itanium		mf			none reqd.
SPARC		stbar			none reqd.
MIPS		sync			none reqd.
PA-RISC		SYNC			none reqd. */

#define GUPCR_FENCE() { GUPCR_READ_FENCE (); GUPCR_WRITE_FENCE (); }

#if defined (PPC) || defined (__PPC__)
#define GUPCR_WRITE_FENCE() asm __volatile__ ("lwsync":::"memory")
#define GUPCR_READ_FENCE() asm __volatile__ ("isync":::"memory")
#elif defined (alpha)
#define GUPCR_WRITE_FENCE() asm __volatile__ ("wmb":::"memory")
#define GUPCR_READ_FENCE() asm __volatile__ ("mb":::"memory")
#elif defined (__x86_64__)
#define GUPCR_WRITE_FENCE() asm __volatile__ ("mfence":::"memory")
#define GUPCR_READ_FENCE() asm __volatile__ ("":::"memory")
#elif defined (__ia64__)
#define GUPCR_WRITE_FENCE() asm __volatile__ ("mf":::"memory")
#define GUPCR_READ_FENCE() asm __volatile__ ("":::"memory")
#elif defined (i386)
#define GUPCR_WRITE_FENCE() asm __volatile__ ("lock; addl $0,0(%%esp)":::"memory")
#define GUPCR_READ_FENCE() asm __volatile__ ("":::"memory")
#elif defined (sparc)
#define GUPCR_WRITE_FENCE() asm __volatile__ ("stbar":::"memory")
#define GUPCR_READ_FENCE() asm __volatile__ ("":::"memory")
#elif defined (mips)
#define GUPCR_WRITE_FENCE() asm __volatile__ ("sync":::"memory")
#define GUPCR_READ_FENCE() asm __volatile__ ("":::"memory")
#elif defined (hppa)
#define GUPCR_WRITE_FENCE() asm __volatile__ ("SYNC":::"memory")
#define GUPCR_READ_FENCE() asm __volatile__ ("":::"memory")
#else
# error "No memory fence  operations provided for this cpu."
#endif
//end lib_fence_defs

//begin lib_atomic
#if defined (__GCC_HAVE_SYNC_COMPARE_AND_SWAP_8) \
    || defined (__GCC_HAVE_SYNC_COMPARE_AND_SWAP_4)
  /* Use GCC's builtin implementation, if available.  */
  #define __upc_atomic_cas(PTR, OLD_VAL, NEW_VAL) \
    __sync_bool_compare_and_swap (PTR, OLD_VAL, NEW_VAL)
#elif defined(__GCC_ATOMIC_LONG_LOCK_FREE) \
    || defined (__GCC_ATOMIC_INT_LOCK_FREE)
  #define __upc_atomic_cas(PTR, OLD_VAL, NEW_VAL) \
    ({ typeof(*(PTR)) __oval = (OLD_VAL); \
       typeof(*(PTR)) __nval = (NEW_VAL); \
       __atomic_compare_exchange (PTR, (void*)&__oval, &__nval, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST); })
#else
  extern int __upc_atomic_cas (os_atomic_p, os_atomic_t, os_atomic_t);
#endif

#if defined (HAVE_SYNC_FETCH_AND_ADD_8) \
    || defined (HAVE_SYNC_FETCH_AND_ADD_4)
#define __upc_sync_fetch_and_add(PTR, INC) \
    __sync_fetch_and_add (PTR, INC)
#else
__attribute__ ((__always_inline__))
static inline
int
__upc_sync_fetch_and_add (int *addr, int inc)
{
  int old_val, new_val;
  do
    {
      old_val = *addr;
      new_val = old_val + inc;
    }
  while (!__upc_atomic_cas (addr, old_val, new_val));
  return old_val;
}
#endif
//end lib_atomic

//begin lib_spin_until

/* Give up control of the cpu for a small time interval. */
#ifdef __sgi__
#define __upc_yield_cpu() do { sginap(0); } while (0)
#else
# ifdef _POSIX_PRIORITY_SCHEDULING
# define __upc_yield_cpu() do { sched_yield(); } while (0)
# else
# define __upc_yield_cpu() do { usleep(1000L); } while (0)
# endif
#endif

/* Number of cpu's available */
extern int __upc_num_cpus;

/* Max. number of iterations to poll waiting for a
 * spinlock loop condition to be satisfied.
 */
#define OS_MAX_SPIN_COUNT (__upc_num_cpus > 1 ? 500 : 0)
/* Keep spinning until PREDICATE is true,
 * (this needs to be a macro, to ensure that
 * PREDICATE is re-evaluated on each iteration. */
#define __upc_spin_until(PREDICATE) \
    { \
      int i = 0; \
      while (!(PREDICATE)) \
	{ \
	  if (++i >= OS_MAX_SPIN_COUNT) \
	    { \
	      __upc_yield_cpu (); \
	      i = 0; \
	    } \
	} \
    }
//end lib_spin_until

#endif /* _UPC_SYNC_H_ */
