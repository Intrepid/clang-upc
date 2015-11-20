[= Autogen5 template upc =]
/*===-- upc_atomic.tpl - UPC Runtime Support Library ----------------------===
|*
|*                     The LLVM Compiler Infrastructure
|*
|* Copyright 2014, Intrepid Technology, Inc.  All rights reserved.
|* This file is distributed under a BSD-style Open Source License.
|* See LICENSE-INTREPID.TXT for details.
|*
|*===---------------------------------------------------------------------===*/
/* Process the definitions file with autogen to produce two UPC atomic files,
   optimized and generic versions:

   autogen -DHAVE_BUILTIN_ATOMICS -bupc_atomic_builtin -L ../include upc_atomic.def
   autogen -bupc_atomic_generic -L ../include upc_atomic.def

*/

#include <upc.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <upc_atomic.h>
#include "upc_config.h"[=
IF (not (exist? "have_builtin_atomics")) =]
#include "upc_atomic_sup.h"[=
ENDIF =]

/**
 * @file __upc_atomic.upc
 * GUPC Portals4 UPC atomics implementation.
 */

/**
 * @addtogroup ATOMIC GUPCR Atomics Functions
 * @{
 */

/** Atomic domain representation */
struct upc_atomicdomain_struct
{
  upc_op_t ops;
  upc_type_t optype;
};

/* Represent a bit-encoded operation as an integer.  */
typedef unsigned int upc_op_num_t;

[= FOR upc_type =][=
  IF (exist? "type_atomic_ok") =][=
    (define abbrev-type (string-append (get "type_abbrev") "_type")) =]
typedef [=type_c_name=] [= (. abbrev-type) =];[=
  ENDIF =][=
ENDFOR =]

[= (define access-ops "") =][=
  FOR upc_op =][=
    (if (and (exist? "op_atomic_ok") (= (get "op_mode") "access"))
      (begin
        (if (> (string-length access-ops) 0)
               (set! access-ops (string-append access-ops " | ")))
        (set! access-ops (string-append access-ops
	                    (get "op_upc_name"))))) =][=
  ENDFOR =]
#define ATOMIC_ACCESS_OPS ([= (. access-ops) =])
[= (define num-ops "") =][=
  FOR upc_op =][=
    (if (and (exist? "op_atomic_ok") (= (get "op_mode") "numeric"))
      (begin
        (if (> (string-length num-ops) 0)
               (set! num-ops (string-append num-ops " | ")))
        (set! num-ops (string-append num-ops (get "op_upc_name"))))) =][=
  ENDFOR =]
#define ATOMIC_NUM_OPS ([= (. num-ops) =])
[= (define bit-ops "") =][=
  FOR upc_op =][=
    (if (and (exist? "op_atomic_ok") (= (get "op_mode") "logical"))
      (begin
        (if (> (string-length bit-ops) 0)
               (set! bit-ops (string-append bit-ops " | ")))
        (set! bit-ops (string-append bit-ops (get "op_upc_name"))))) =][=
  ENDFOR =]
#define ATOMIC_BIT_OPS ([= (. bit-ops) =])
#define ATOMIC_ALL_OPS (ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS \
                        | ATOMIC_BIT_OPS)

/**
 * Check if OP is a valid atomic operation type.
 *
 * @param [in] op UPC atomic operation
 * @retval TRUE if op is a valid atomic operation
 */
static inline bool
__upc_atomic_is_valid_op (upc_op_t op)
{
  return !((op & ~(-op)) || (op & ~ATOMIC_ALL_OPS));
}

/**
 * Convert the bit-encoded OP into an integer.
 *
 * @param [in] op UPC atomic operation
 * @retval op represented as integer index
 *  (UPC_ADD_OP, UPC_MULT_OP ...)
 */
static inline upc_op_num_t
__upc_atomic_op_num (upc_op_t op)
{
  return (LONG_LONG_BITS - 1) - __builtin_clzll ((long long) op);
}

/**
 * Check if UPC_TYPE is a valid atomic operation type.
 *
 * @param [in] upc_type UPC atomic type
 * @retval TRUE if atomic operations are supported on UPC_TYPE
 */
static bool
__upc_atomic_is_valid_type (upc_type_t upc_type)
{
  switch (upc_type)
    {[=
FOR upc_type =][=
  IF (exist? "type_atomic_ok") =]
    case [=type_upc_name=]:[=
  ENDIF =][=
ENDFOR =]
      return true;
    default: break;
    }
    return false;
}

/**
 * Return the atomic operations supported for type UPC_TYPE.
 *
 * @param [in] upc_type UPC atomic type
 * @retval bit vector of supported atomic operations.
 */
static upc_op_t
__upc_atomic_supported_ops (upc_type_t upc_type)
{
  switch (upc_type)
    {[=
FOR upc_type =][=
  IF (exist? "type_atomic_ok") =][=
    (define valid-ops "ATOMIC_ACCESS_OPS")
    (if (exist? "type_numeric_op_ok")
        (set! valid-ops (string-append
	                   valid-ops " | ATOMIC_NUM_OPS")))
    (if (exist? "type_bit_op_ok")
        (set! valid-ops (string-append
	                   valid-ops " | ATOMIC_BIT_OPS"))) =]
    case [=type_upc_name=]:
      return [= (. valid-ops) =];[=
  ENDIF =][=
ENDFOR =]
    }
    return 0;
}

/**
 * Convert UPC atomic operation into a string.
 *
 * @param [in] upc_op UPC atomic operation
 * @retval Character string
 */
static const char *
__upc_atomic_op_name (upc_op_num_t op_num)
{
  switch (op_num)
    {[=
FOR upc_op =][=
  IF (exist? "op_atomic_ok") =]
    case [=op_upc_name=]_OP:
      return "[=op_upc_name=]";[=
  ENDIF =][=
ENDFOR =]
    }
    return NULL;
}

/**
 * Convert UPC atomic type into a string.
 *
 * @param [in] upc_type UPC atomic type
 * @retval Character string
 */
static const char *
__upc_atomic_type_name (upc_type_t upc_type)
{
  switch (upc_type)
    {[=
FOR upc_type =][=
  IF (exist? "type_atomic_ok") =]
    case [=type_upc_name=]:
      return "[=type_upc_name=]";[=
  ENDIF =][=
ENDFOR =]
    }
    return NULL;
}

#define REQ_FETCH_PTR 0b00000001
#define REQ_OPERAND1  0b00000010
#define REQ_OPERAND2  0b00000100
#define NULL_OPERAND1 0b00001000
#define NULL_OPERAND2 0b00010000

static const unsigned int operand_check[] =
  {[=
FOR upc_op =]
    /* [=op_upc_name=]_OP */ [=
  (define nil '())
  (define check-bits nil) =][=
  IF (exist? "op_atomic_ok") =][=
  (if (exist? "op_require_fetch_ptr")
      (set! check-bits (append check-bits '("REQ_FETCH_PTR"))))
  (if (exist? "op_require_operand1")
      (set! check-bits (append check-bits '("REQ_OPERAND1"))))
  (if (exist? "op_require_operand2")
      (set! check-bits (append check-bits '("REQ_OPERAND2"))))
  (if (exist? "op_null_operand1")
      (set! check-bits (append check-bits '("NULL_OPERAND1"))))
  (if (exist? "op_null_operand2")
      (set! check-bits (append check-bits '("NULL_OPERAND2")))) =][=
  ELSE =][=
      (set! check-bits (append check-bits "0")) =][=
  ENDIF =][=
  (. (join " | " check-bits)) =],[=
ENDFOR =]
  };

static inline void
__upc_atomic_check_operands (upc_op_num_t op_num,
		   void * restrict fetch_ptr,
		   const void * restrict operand1,
		   const void * restrict operand2)
{
  const unsigned int check = operand_check[op_num];
  if ((check & REQ_FETCH_PTR) && fetch_ptr == NULL)
    __upc_fatal ("atomic operation `%s' "
                 "requires a non-NULL fetch pointer",
		 __upc_atomic_op_name (op_num));
  if ((check & REQ_OPERAND1) && operand1 == NULL)
    __upc_fatal ("atomic operation `%s' "
                 "requires a non-NULL operand1 pointer",
		 __upc_atomic_op_name (op_num));
  if ((check & REQ_OPERAND2) && operand2 == NULL)
    __upc_fatal ("atomic operation `%s' "
                 "requires a non-NULL operand2 pointer",
		 __upc_atomic_op_name (op_num));
  if ((check & NULL_OPERAND1) && operand1 != NULL)
    __upc_fatal ("atomic operation `%s' "
                 "requires a NULL operand1 pointer",
		 __upc_atomic_op_name (op_num));
  if ((check & NULL_OPERAND2) && operand2 != NULL)
    __upc_fatal ("atomic operation `%s' "
                 "requires a NULL operand2 pointer",
		 __upc_atomic_op_name (op_num));
}[=
FOR upc_type =][= IF (exist? "type_atomic_ok") =][=
    (define abbrev-type (string-append (get "type_abbrev") "_type")) =]

static void
__upc_atomic_[=type_abbrev=] (
	[= (. abbrev-type) =] * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared [= (. abbrev-type) =] * restrict target,
	[= (. abbrev-type) =] * restrict operand1 __attribute__((unused)),
	[= (. abbrev-type) =] * restrict operand2 __attribute__((unused)))
{
  [= (. abbrev-type) =] orig_value __attribute__((unused));
  [= (. abbrev-type) =] new_value __attribute__((unused));
  [=IF (= (get "type_abbrev") "PTS") =]
  int op_ok __attribute__((unused));[=
  ENDIF =]
  [= (. abbrev-type) =] *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);[=
  IF (exist? "have_builtin_atomics") =][=
    INCLUDE "upc_atomic_builtin.tpl" =][=
  ELSE =][=
    INCLUDE "upc_atomic_generic.tpl" =][=
  ENDIF =]
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}[=
  ENDIF =][=
ENDFOR =]

/**
 * UPC atomic relaxed operation.
 *
 * @param [in] domain Atomic domain
 * @param [in] fetch_ptr Target of the update
 * @param [in] op Atomic operation
 * @param [in] target Target address of the operation
 * @param [in] operand1 Operation required argument
 * @param [in] operand2 Operation required argument
 *
 * @ingroup UPCATOMIC UPC Atomic Functions
 */
void
upc_atomic_relaxed (upc_atomicdomain_t *domain,
		   void * restrict fetch_ptr,
		   upc_op_t op,
		   shared void * restrict target,
		   const void * restrict operand1,
		   const void * restrict operand2)
{
  struct upc_atomicdomain_struct *ldomain =
    (struct upc_atomicdomain_struct *) &domain[MYTHREAD];
  upc_op_num_t op_num;
  GUPCR_OMP_CHECK ();
  if (op & ~(-op))
    __upc_fatal ("atomic operation (0x%llx) may have only "
                 "a single bit set", (long long)op);
  if (!__upc_atomic_is_valid_op (op))
    __upc_fatal ("invalid atomic operation (0x%llx)",
                 (long long)op);
  op_num = __upc_atomic_op_num (op);
  if (op & ~ldomain->ops)
    __upc_fatal ("invalid operation (%s) for specified domain",
	         __upc_atomic_op_name (op_num));
  __upc_atomic_check_operands (op_num, fetch_ptr, operand1, operand2);
  switch (ldomain->optype)
    {[=
    FOR upc_type =][= IF (exist? "type_atomic_ok") =][=
    (define abbrev-type (string-append (get "type_abbrev") "_type")) =]
    case [=type_upc_name=]:
      __upc_atomic_[=type_abbrev=] (
	       ([= (. abbrev-type) =] *) fetch_ptr,
	       op_num,
	       (shared [= (. abbrev-type) =] *) target,
	       ([= (. abbrev-type) =] *) operand1,
	       ([= (. abbrev-type) =] *) operand2);
      break;[=
    ENDIF =][= ENDFOR =]
    }
}

/**
 * UPC atomic strict operation.
 *
 * @param [in] domain Atomic domain
 * @param [in] fetch_ptr Target of the update
 * @param [in] op Atomic operation
 * @param [in] target Target address of the operation
 * @param [in] operand1 Operation required argument
 * @param [in] operand2 Operation required argument
 *
 * @ingroup UPCATOMIC UPC Atomic Functions
 */
void
upc_atomic_strict (upc_atomicdomain_t *domain,
		   void * restrict fetch_ptr,
		   upc_op_t op,
		   shared void * restrict target,
		   const void * restrict operand1,
		   const void * restrict operand2)
{
  GUPCR_OMP_CHECK ();
  upc_fence;
  upc_atomic_relaxed (domain, fetch_ptr, op, target, operand1, operand2);
  upc_fence;
}

/**
 * Collective allocation of atomic domain.
 *
 * Implementation uses native Portals4 atomic functions and the
 * hint field is ignored.
 *
 * @parm [in] type Atomic operation type
 * @parm [in] ops Atomic domain operations
 * @parm [in] hints Atomic operation hint
 * @retval Allocated atomic domain pointer
 *
 * @ingroup UPCATOMIC UPC Atomic Functions
 */
upc_atomicdomain_t *
upc_all_atomicdomain_alloc (upc_type_t type,
			    upc_op_t ops,
			    __attribute__((unused)) upc_atomichint_t hints)
{
  upc_atomicdomain_t *domain;
  struct upc_atomicdomain_struct *ldomain;
  upc_op_t supported_ops;
  GUPCR_OMP_CHECK ();
  if (!__upc_atomic_is_valid_type (type))
    __upc_fatal ("unsupported atomic type: 0x%llx",
                 (long long) type);
  supported_ops = __upc_atomic_supported_ops (type);
  if ((ops & ~supported_ops) != 0)
    __upc_fatal ("one/more requested atomic operations (0x%llx) unsupported "
                 "for type `%s'", (long long) ops,
		 __upc_atomic_type_name (type));
  domain = (upc_atomicdomain_t *)
    upc_all_alloc (THREADS, sizeof (struct upc_atomicdomain_struct));
  if (domain == NULL)
    __upc_fatal ("unable to allocate atomic domain");
  ldomain = (struct upc_atomicdomain_struct *)&domain[MYTHREAD];
  ldomain->ops = ops;
  ldomain->optype = type;
  return domain;
}

/**
 * Collective free of the atomic domain.
 *
 * @param [in] domain Pointer to atomic domain
 *
 * @ingroup UPCATOMIC UPC Atomic Functions
 */
void
upc_all_atomicdomain_free (upc_atomicdomain_t * domain)
{
  assert (domain != NULL);
  GUPCR_OMP_CHECK ();
  upc_barrier;
  if (MYTHREAD == 0)
    {
      upc_free (domain);
    }
  upc_barrier;
}

/**
 * Query implementation for expected performance.
 *
 * @parm [in] ops Atomic domain operations
 * @parm [in] optype Atomic operation type
 * @parm [in] addr Atomic address
 * @retval Expected performance
 *
 * @ingroup UPCATOMIC UPC Atomic Functions
 */
int
upc_atomic_isfast (__attribute__((unused)) upc_type_t optype,
	 	   __attribute__((unused)) upc_op_t ops,
		   __attribute__((unused)) shared void *addr)
{[=
IF (exist? "have_builtin_atomics") =]
  /* We could make the distinction that only operations
     directly supported by the builtin atomics are "fast",
     but for now ... everything in the SMP runtime is
     defined to be fast.  */
  return UPC_ATOMIC_PERFORMANCE_FAST;[=
ELSE =]
  return UPC_ATOMIC_PERFORMANCE_NOT_FAST;[=
ENDIF =]
}

/** @} */
