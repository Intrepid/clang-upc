/*===-- upc_pts.h - UPC Runtime Support Library --------------------------===
|*
|*                     The LLVM Compiler Infrastructure
|*
|* Copyright 2012-2014, Intrepid Technology, Inc.  All rights reserved.
|* This file is distributed under a BSD-style Open Source License.
|* See LICENSE-INTREPID.TXT for details.
|*
|*===---------------------------------------------------------------------===*/

#ifndef _UPC_PTS_H_
#define _UPC_PTS_H_ 1

//begin lib_pts_defs

/* UPC pointer representation */

#if (defined(GUPCR_PTS_STRUCT_REP) + defined(GUPCR_PTS_WORD_PAIR_REP) \
     + defined(GUPCR_PTS_PACKED_REP)) == 0
# error Unknown PTS representation.
#elif (defined(GUPCR_PTS_STRUCT_REP) + defined(GUPCR_PTS_WORD_PAIR_REP) \
     + defined(GUPCR_PTS_PACKED_REP)) != 1
# error Only one UPC shared pointer representaion setting is permitted.
#endif

#ifdef GUPCR_PTS_STRUCT_REP

#if GUPCR_PTS_THREAD_SIZE == 32
#undef GUPCR_PTS_THREAD_TYPE
#define GUPCR_PTS_THREAD_TYPE u_intSI_t
#elif GUPCR_PTS_THREAD_SIZE == 16
#undef GUPCR_PTS_THREAD_TYPE
#define GUPCR_PTS_THREAD_TYPE u_intHI_t
#endif
#if GUPCR_PTS_PHASE_SIZE == 32
#undef GUPCR_PTS_PHASE_TYPE
#define GUPCR_PTS_PHASE_TYPE u_intSI_t
#elif GUPCR_PTS_PHASE_SIZE == 16
#undef GUPCR_PTS_PHASE_TYPE
#define GUPCR_PTS_PHASE_TYPE u_intHI_t
#endif
#if GUPCR_PTS_VADDR_SIZE == 64
#undef GUPCR_PTS_VADDR_TYPE
#define GUPCR_PTS_VADDR_TYPE u_intDI_t
#elif GUPCR_PTS_VADDR_SIZE == 32
#undef GUPCR_PTS_VADDR_TYPE
#define GUPCR_PTS_VADDR_TYPE u_intSI_t
#elif GUPCR_PTS_VADDR_SIZE == 16
#undef GUPCR_PTS_VADDR_TYPE
#define GUPCR_PTS_VADDR_TYPE u_intHI_t
#endif

typedef struct shared_ptr_struct
  {
#if GUPCR_PTS_VADDR_FIRST
    GUPCR_PTS_VADDR_TYPE  vaddr;
    GUPCR_PTS_THREAD_TYPE thread;
    GUPCR_PTS_PHASE_TYPE  phase;
#else
    GUPCR_PTS_PHASE_TYPE  phase;
    GUPCR_PTS_THREAD_TYPE thread;
    GUPCR_PTS_VADDR_TYPE  vaddr;
#endif
  } upc_shared_ptr_t
#ifdef GUPCR_PTS_ALIGN
  __attribute__ ((aligned (GUPCR_PTS_ALIGN)))
#endif
  ;
typedef upc_shared_ptr_t *upc_shared_ptr_p;
/* upc_dbg_shared_ptr_t is used by debugger to figure out
   shared pointer layout */
typedef upc_shared_ptr_t upc_dbg_shared_ptr_t;

#define GUPCR_PTS_TO_REP(V) *((upc_shared_ptr_t *)&(V)) 
#define GUPCR_PTS_IS_NULL(P) (!(P).vaddr && !(P).thread && !(P).phase)
#define GUPCR_PTS_SET_NULL_SHARED(P) \
   {(P).vaddr = 0; (P).thread = 0; (P).phase = 0;}

#define GUPCR_PTS_VADDR(P) ((size_t)(P).vaddr - (size_t)GUPCR_SHARED_SECTION_START)
#define GUPCR_PTS_OFFSET(P) ((size_t)(P).vaddr - (size_t)GUPCR_SHARED_SECTION_START)
#define GUPCR_PTS_THREAD(P) (P).thread
#define GUPCR_PTS_PHASE(P) (P).phase

#define GUPCR_PTS_SET_VADDR(P,V) (P).vaddr = (GUPCR_PTS_VADDR_TYPE)((char *)(V) \
			+ (size_t)GUPCR_SHARED_SECTION_START)
#define GUPCR_PTS_INCR_VADDR(P,V) (P).vaddr += ((size_t)(V))
#define GUPCR_PTS_SET_THREAD(P,V) (P).thread = (size_t)(V)
#define GUPCR_PTS_SET_PHASE(P,V) (P).phase = (size_t)(V)

#elif GUPCR_PTS_PACKED_REP

#if GUPCR_PTS_VADDR_FIRST
#define GUPCR_PTS_VADDR_SHIFT	(GUPCR_PTS_THREAD_SHIFT + GUPCR_PTS_THREAD_SIZE)
#define GUPCR_PTS_THREAD_SHIFT	GUPCR_PTS_PHASE_SIZE
#define GUPCR_PTS_PHASE_SHIFT	0
#else
#define GUPCR_PTS_VADDR_SHIFT   0
#define GUPCR_PTS_THREAD_SHIFT  GUPCR_PTS_VADDR_SIZE
#define GUPCR_PTS_PHASE_SHIFT   (GUPCR_PTS_THREAD_SHIFT + GUPCR_PTS_THREAD_SIZE)
#endif
#define GUPCR_PTS_TO_REP(V) *((upc_shared_ptr_t *)&(V)) 
#if GUPCR_TARGET64
#define GUPCR_ONE 1L
#define GUPCR_PTS_REP_T unsigned long
#else
#define GUPCR_ONE 1LL
#define GUPCR_PTS_REP_T unsigned long long
#endif
#define GUPCR_PTS_VADDR_MASK	((GUPCR_ONE << GUPCR_PTS_VADDR_SIZE) - GUPCR_ONE)
#define GUPCR_PTS_THREAD_MASK	((GUPCR_ONE << GUPCR_PTS_THREAD_SIZE) - GUPCR_ONE)
#define GUPCR_PTS_PHASE_MASK	((GUPCR_ONE << GUPCR_PTS_PHASE_SIZE) - GUPCR_ONE)

/* upc_dbg_shared_ptr_t is used by debugger to figure out
   shared pointer layout */
typedef struct shared_ptr_struct
  {
#if GUPCR_PTS_VADDR_FIRST
    unsigned long long vaddr:GUPCR_PTS_VADDR_SIZE;
    unsigned int thread:GUPCR_PTS_THREAD_SIZE;
    unsigned int phase:GUPCR_PTS_PHASE_SIZE;
#else
    unsigned int phase:GUPCR_PTS_PHASE_SIZE;
    unsigned int thread:GUPCR_PTS_THREAD_SIZE;
    unsigned long long vaddr:GUPCR_PTS_VADDR_SIZE;
#endif
  } upc_dbg_shared_ptr_t;

typedef GUPCR_PTS_REP_T upc_shared_ptr_t;
typedef upc_shared_ptr_t *upc_shared_ptr_p;

#define GUPCR_PTS_IS_NULL(P) !(P)
#define GUPCR_PTS_SET_NULL_SHARED(P) { (P) = 0; }

/* access functions are optiimzed for a representation of the
   form (vaddr,thread,phase) and where the value is unsigned.
   Thus, right shift is logical (not arithmetic), and masking
   is avoided for vaddr, and shifting is avoided for phase. 
   Further, the value being inserted must fit into the field.
   It will not be masked.  */
#define GUPCR_PTS_VADDR(P)  \
  (void *)((size_t)((P)>>GUPCR_PTS_VADDR_SHIFT & GUPCR_PTS_VADDR_MASK))
#define GUPCR_PTS_THREAD(P) ((size_t)((P)>>GUPCR_PTS_THREAD_SHIFT & GUPCR_PTS_THREAD_MASK))
#define GUPCR_PTS_PHASE(P)  ((size_t)((P)>>GUPCR_PTS_PHASE_SHIFT & GUPCR_PTS_PHASE_MASK))
#define GUPCR_PTS_OFFSET(P) ((size_t)((P)>>GUPCR_PTS_VADDR_SHIFT & GUPCR_PTS_VADDR_MASK))

#define GUPCR_PTS_SET_VADDR(P,V) \
  (P) = ((P) & ~(GUPCR_PTS_VADDR_MASK << GUPCR_PTS_VADDR_SHIFT)) \
         	| ((GUPCR_PTS_REP_T)(V) << GUPCR_PTS_VADDR_SHIFT)
#define GUPCR_PTS_SET_THREAD(P,V) (P) = ((P) & ~(GUPCR_PTS_THREAD_MASK << GUPCR_PTS_THREAD_SHIFT)) \
                                     | ((GUPCR_PTS_REP_T)(V) << GUPCR_PTS_THREAD_SHIFT)
#define GUPCR_PTS_SET_PHASE(P,V) (P) = ((P) & ~(GUPCR_PTS_PHASE_MASK << GUPCR_PTS_PHASE_SHIFT)) \
                                     | ((GUPCR_PTS_REP_T)(V) << GUPCR_PTS_PHASE_SHIFT)
#define GUPCR_PTS_INCR_VADDR(P,V) \
  ((P) += ((GUPCR_PTS_REP_T)(V) << GUPCR_PTS_VADDR_SHIFT))
#elif GUPCR_PTS_WORD_PAIR_REP
#error UPC word pair representation is unsupported.
#endif /* GUPCR_PTS_*_REP__ */
//end lib_pts_defs

#endif /* !_UPC_PTS_H_ */
