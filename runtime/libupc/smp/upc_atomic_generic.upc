/*===-- upc_atomic.tpl - UPC Runtime Support Library ----------------------===
|*
|*                     The LLVM Compiler Infrastructure
|*
|* Copyright 2014, Intrepid Technology, Inc.  All rights reserved.
|* This file is distributed under a BSD-style Open Source License.
|* See LICENSE-INTREPID.TXT for details.
|*
|*===---------------------------------------------------------------------===*/
/* Process the definitions file with autogen to produce tow UPC atomic files,
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
#include "upc_config.h"
#include "upc_atomic_sup.h"

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


typedef int I_type;
typedef unsigned int UI_type;
typedef long L_type;
typedef unsigned long UL_type;
typedef long long LL_type;
typedef unsigned long long ULL_type;
typedef int32_t I32_type;
typedef uint32_t UI32_type;
typedef int64_t I64_type;
typedef uint64_t UI64_type;
typedef float F_type;
typedef double D_type;
typedef shared void * PTS_type;


#define ATOMIC_ACCESS_OPS (UPC_GET | UPC_SET | UPC_CSWAP)

#define ATOMIC_NUM_OPS (UPC_ADD | UPC_MULT | UPC_MIN | UPC_MAX | UPC_SUB | UPC_INC | UPC_DEC)

#define ATOMIC_BIT_OPS (UPC_AND | UPC_OR | UPC_XOR)
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
    {
    case UPC_INT:
    case UPC_UINT:
    case UPC_LONG:
    case UPC_ULONG:
    case UPC_LLONG:
    case UPC_ULLONG:
    case UPC_INT32:
    case UPC_UINT32:
    case UPC_INT64:
    case UPC_UINT64:
    case UPC_FLOAT:
    case UPC_DOUBLE:
    case UPC_PTS:
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
    {
    case UPC_INT:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS | ATOMIC_BIT_OPS;
    case UPC_UINT:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS | ATOMIC_BIT_OPS;
    case UPC_LONG:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS | ATOMIC_BIT_OPS;
    case UPC_ULONG:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS | ATOMIC_BIT_OPS;
    case UPC_LLONG:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS | ATOMIC_BIT_OPS;
    case UPC_ULLONG:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS | ATOMIC_BIT_OPS;
    case UPC_INT32:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS | ATOMIC_BIT_OPS;
    case UPC_UINT32:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS | ATOMIC_BIT_OPS;
    case UPC_INT64:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS | ATOMIC_BIT_OPS;
    case UPC_UINT64:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS | ATOMIC_BIT_OPS;
    case UPC_FLOAT:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS;
    case UPC_DOUBLE:
      return ATOMIC_ACCESS_OPS | ATOMIC_NUM_OPS;
    case UPC_PTS:
      return ATOMIC_ACCESS_OPS;
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
    {
    case UPC_ADD_OP:
      return "UPC_ADD";
    case UPC_MULT_OP:
      return "UPC_MULT";
    case UPC_AND_OP:
      return "UPC_AND";
    case UPC_OR_OP:
      return "UPC_OR";
    case UPC_XOR_OP:
      return "UPC_XOR";
    case UPC_MIN_OP:
      return "UPC_MIN";
    case UPC_MAX_OP:
      return "UPC_MAX";
    case UPC_GET_OP:
      return "UPC_GET";
    case UPC_SET_OP:
      return "UPC_SET";
    case UPC_CSWAP_OP:
      return "UPC_CSWAP";
    case UPC_SUB_OP:
      return "UPC_SUB";
    case UPC_INC_OP:
      return "UPC_INC";
    case UPC_DEC_OP:
      return "UPC_DEC";
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
    {
    case UPC_INT:
      return "UPC_INT";
    case UPC_UINT:
      return "UPC_UINT";
    case UPC_LONG:
      return "UPC_LONG";
    case UPC_ULONG:
      return "UPC_ULONG";
    case UPC_LLONG:
      return "UPC_LLONG";
    case UPC_ULLONG:
      return "UPC_ULLONG";
    case UPC_INT32:
      return "UPC_INT32";
    case UPC_UINT32:
      return "UPC_UINT32";
    case UPC_INT64:
      return "UPC_INT64";
    case UPC_UINT64:
      return "UPC_UINT64";
    case UPC_FLOAT:
      return "UPC_FLOAT";
    case UPC_DOUBLE:
      return "UPC_DOUBLE";
    case UPC_PTS:
      return "UPC_PTS";
    }
    return NULL;
}

#define REQ_FETCH_PTR 0b00000001
#define REQ_OPERAND1  0b00000010
#define REQ_OPERAND2  0b00000100
#define NULL_OPERAND1 0b00001000
#define NULL_OPERAND2 0b00010000

static const unsigned int operand_check[] =
  {
    /* UPC_ADD_OP */ REQ_OPERAND1 | NULL_OPERAND2,
    /* UPC_MULT_OP */ REQ_OPERAND1 | NULL_OPERAND2,
    /* UPC_AND_OP */ REQ_OPERAND1 | NULL_OPERAND2,
    /* UPC_OR_OP */ REQ_OPERAND1 | NULL_OPERAND2,
    /* UPC_XOR_OP */ REQ_OPERAND1 | NULL_OPERAND2,
    /* UPC_LOGAND_OP */ 0,
    /* UPC_LOGOR_OP */ 0,
    /* UPC_MIN_OP */ REQ_OPERAND1 | NULL_OPERAND2,
    /* UPC_MAX_OP */ REQ_OPERAND1 | NULL_OPERAND2,
    /* UPC_GET_OP */ REQ_FETCH_PTR | NULL_OPERAND1 | NULL_OPERAND2,
    /* UPC_SET_OP */ REQ_OPERAND1 | NULL_OPERAND2,
    /* UPC_CSWAP_OP */ REQ_OPERAND1 | REQ_OPERAND2,
    /* UPC_SUB_OP */ REQ_OPERAND1 | NULL_OPERAND2,
    /* UPC_INC_OP */ NULL_OPERAND1 | NULL_OPERAND2,
    /* UPC_DEC_OP */ NULL_OPERAND1 | NULL_OPERAND2,
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
}

static void
__upc_atomic_I (
	I_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared I_type * restrict target,
	I_type * restrict operand1 __attribute__((unused)),
	I_type * restrict operand2 __attribute__((unused)))
{
  I_type orig_value __attribute__((unused));
  I_type new_value __attribute__((unused));
  
  I_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	*target_ptr += *operand1;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_AND_OP:
	orig_value = *target_ptr;
	*target_ptr &= *operand1;
        break;
      case UPC_OR_OP:
	orig_value = *target_ptr;
	*target_ptr |= *operand1;
        break;
      case UPC_XOR_OP:
	orig_value = *target_ptr;
	*target_ptr ^= *operand1;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	*target_ptr -= *operand1;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	*target_ptr += (int) 1;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	*target_ptr -= (int) 1;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_UI (
	UI_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared UI_type * restrict target,
	UI_type * restrict operand1 __attribute__((unused)),
	UI_type * restrict operand2 __attribute__((unused)))
{
  UI_type orig_value __attribute__((unused));
  UI_type new_value __attribute__((unused));
  
  UI_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	*target_ptr += *operand1;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_AND_OP:
	orig_value = *target_ptr;
	*target_ptr &= *operand1;
        break;
      case UPC_OR_OP:
	orig_value = *target_ptr;
	*target_ptr |= *operand1;
        break;
      case UPC_XOR_OP:
	orig_value = *target_ptr;
	*target_ptr ^= *operand1;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	*target_ptr -= *operand1;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	*target_ptr += (unsigned int) 1;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	*target_ptr -= (unsigned int) 1;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_L (
	L_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared L_type * restrict target,
	L_type * restrict operand1 __attribute__((unused)),
	L_type * restrict operand2 __attribute__((unused)))
{
  L_type orig_value __attribute__((unused));
  L_type new_value __attribute__((unused));
  
  L_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	*target_ptr += *operand1;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_AND_OP:
	orig_value = *target_ptr;
	*target_ptr &= *operand1;
        break;
      case UPC_OR_OP:
	orig_value = *target_ptr;
	*target_ptr |= *operand1;
        break;
      case UPC_XOR_OP:
	orig_value = *target_ptr;
	*target_ptr ^= *operand1;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	*target_ptr -= *operand1;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	*target_ptr += (long) 1;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	*target_ptr -= (long) 1;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_UL (
	UL_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared UL_type * restrict target,
	UL_type * restrict operand1 __attribute__((unused)),
	UL_type * restrict operand2 __attribute__((unused)))
{
  UL_type orig_value __attribute__((unused));
  UL_type new_value __attribute__((unused));
  
  UL_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	*target_ptr += *operand1;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_AND_OP:
	orig_value = *target_ptr;
	*target_ptr &= *operand1;
        break;
      case UPC_OR_OP:
	orig_value = *target_ptr;
	*target_ptr |= *operand1;
        break;
      case UPC_XOR_OP:
	orig_value = *target_ptr;
	*target_ptr ^= *operand1;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	*target_ptr -= *operand1;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	*target_ptr += (unsigned long) 1;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	*target_ptr -= (unsigned long) 1;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_LL (
	LL_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared LL_type * restrict target,
	LL_type * restrict operand1 __attribute__((unused)),
	LL_type * restrict operand2 __attribute__((unused)))
{
  LL_type orig_value __attribute__((unused));
  LL_type new_value __attribute__((unused));
  
  LL_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	*target_ptr += *operand1;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_AND_OP:
	orig_value = *target_ptr;
	*target_ptr &= *operand1;
        break;
      case UPC_OR_OP:
	orig_value = *target_ptr;
	*target_ptr |= *operand1;
        break;
      case UPC_XOR_OP:
	orig_value = *target_ptr;
	*target_ptr ^= *operand1;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	*target_ptr -= *operand1;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	*target_ptr += (long long) 1;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	*target_ptr -= (long long) 1;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_ULL (
	ULL_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared ULL_type * restrict target,
	ULL_type * restrict operand1 __attribute__((unused)),
	ULL_type * restrict operand2 __attribute__((unused)))
{
  ULL_type orig_value __attribute__((unused));
  ULL_type new_value __attribute__((unused));
  
  ULL_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	*target_ptr += *operand1;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_AND_OP:
	orig_value = *target_ptr;
	*target_ptr &= *operand1;
        break;
      case UPC_OR_OP:
	orig_value = *target_ptr;
	*target_ptr |= *operand1;
        break;
      case UPC_XOR_OP:
	orig_value = *target_ptr;
	*target_ptr ^= *operand1;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	*target_ptr -= *operand1;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	*target_ptr += (unsigned long long) 1;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	*target_ptr -= (unsigned long long) 1;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_I32 (
	I32_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared I32_type * restrict target,
	I32_type * restrict operand1 __attribute__((unused)),
	I32_type * restrict operand2 __attribute__((unused)))
{
  I32_type orig_value __attribute__((unused));
  I32_type new_value __attribute__((unused));
  
  I32_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	*target_ptr += *operand1;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_AND_OP:
	orig_value = *target_ptr;
	*target_ptr &= *operand1;
        break;
      case UPC_OR_OP:
	orig_value = *target_ptr;
	*target_ptr |= *operand1;
        break;
      case UPC_XOR_OP:
	orig_value = *target_ptr;
	*target_ptr ^= *operand1;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	*target_ptr -= *operand1;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	*target_ptr += (int32_t) 1;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	*target_ptr -= (int32_t) 1;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_UI32 (
	UI32_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared UI32_type * restrict target,
	UI32_type * restrict operand1 __attribute__((unused)),
	UI32_type * restrict operand2 __attribute__((unused)))
{
  UI32_type orig_value __attribute__((unused));
  UI32_type new_value __attribute__((unused));
  
  UI32_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	*target_ptr += *operand1;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_AND_OP:
	orig_value = *target_ptr;
	*target_ptr &= *operand1;
        break;
      case UPC_OR_OP:
	orig_value = *target_ptr;
	*target_ptr |= *operand1;
        break;
      case UPC_XOR_OP:
	orig_value = *target_ptr;
	*target_ptr ^= *operand1;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	*target_ptr -= *operand1;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	*target_ptr += (uint32_t) 1;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	*target_ptr -= (uint32_t) 1;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_I64 (
	I64_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared I64_type * restrict target,
	I64_type * restrict operand1 __attribute__((unused)),
	I64_type * restrict operand2 __attribute__((unused)))
{
  I64_type orig_value __attribute__((unused));
  I64_type new_value __attribute__((unused));
  
  I64_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	*target_ptr += *operand1;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_AND_OP:
	orig_value = *target_ptr;
	*target_ptr &= *operand1;
        break;
      case UPC_OR_OP:
	orig_value = *target_ptr;
	*target_ptr |= *operand1;
        break;
      case UPC_XOR_OP:
	orig_value = *target_ptr;
	*target_ptr ^= *operand1;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	*target_ptr -= *operand1;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	*target_ptr += (int64_t) 1;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	*target_ptr -= (int64_t) 1;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_UI64 (
	UI64_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared UI64_type * restrict target,
	UI64_type * restrict operand1 __attribute__((unused)),
	UI64_type * restrict operand2 __attribute__((unused)))
{
  UI64_type orig_value __attribute__((unused));
  UI64_type new_value __attribute__((unused));
  
  UI64_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	*target_ptr += *operand1;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_AND_OP:
	orig_value = *target_ptr;
	*target_ptr &= *operand1;
        break;
      case UPC_OR_OP:
	orig_value = *target_ptr;
	*target_ptr |= *operand1;
        break;
      case UPC_XOR_OP:
	orig_value = *target_ptr;
	*target_ptr ^= *operand1;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	*target_ptr -= *operand1;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	*target_ptr += (uint64_t) 1;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	*target_ptr -= (uint64_t) 1;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_F (
	F_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared F_type * restrict target,
	F_type * restrict operand1 __attribute__((unused)),
	F_type * restrict operand2 __attribute__((unused)))
{
  F_type orig_value __attribute__((unused));
  F_type new_value __attribute__((unused));
  
  F_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	new_value = orig_value + *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	new_value = orig_value - *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	new_value = orig_value + (float) 1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	new_value = orig_value - (float) 1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_D (
	D_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared D_type * restrict target,
	D_type * restrict operand1 __attribute__((unused)),
	D_type * restrict operand2 __attribute__((unused)))
{
  D_type orig_value __attribute__((unused));
  D_type new_value __attribute__((unused));
  
  D_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_ADD_OP:
	orig_value = *target_ptr;
	new_value = orig_value + *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MULT_OP:
	orig_value = *target_ptr;
	new_value = orig_value * *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MIN_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 < orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_MAX_OP:
	orig_value = *target_ptr;
	new_value = (*operand1 > orig_value) ? *operand1 : orig_value;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      case UPC_SUB_OP:
	orig_value = *target_ptr;
	new_value = orig_value - *operand1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_INC_OP:
	orig_value = *target_ptr;
	new_value = orig_value + (double) 1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      case UPC_DEC_OP:
	orig_value = *target_ptr;
	new_value = orig_value - (double) 1;
        if (orig_value != new_value)
	  *target_ptr = new_value;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

static void
__upc_atomic_PTS (
	PTS_type * restrict fetch_ptr,
	upc_op_num_t op_num,
	shared PTS_type * restrict target,
	PTS_type * restrict operand1 __attribute__((unused)),
	PTS_type * restrict operand2 __attribute__((unused)))
{
  PTS_type orig_value __attribute__((unused));
  PTS_type new_value __attribute__((unused));
  
  int op_ok __attribute__((unused));
  PTS_type *target_ptr = __cvtaddr (*(upc_shared_ptr_t *)&target);
  __upc_atomic_lock ();
  switch (op_num)
    {
      case UPC_GET_OP:
        orig_value = *target_ptr;
        break;
      case UPC_SET_OP:
	if (fetch_ptr != NULL)
	  orig_value = *target_ptr;
	*target_ptr = *operand1;
        break;
      case UPC_CSWAP_OP:
	orig_value = *operand1;
	if (*target_ptr == orig_value)
	  {
	    *target_ptr = *operand2;
	  }
	else
	    orig_value = *target_ptr;
        break;
      default: break;
    }
  __upc_atomic_release ();
  if (fetch_ptr != NULL)
    *fetch_ptr = orig_value;
}

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
    {
    case UPC_INT:
      __upc_atomic_I (
	       (I_type *) fetch_ptr,
	       op_num,
	       (shared I_type *) target,
	       (I_type *) operand1,
	       (I_type *) operand2);
      break;
    case UPC_UINT:
      __upc_atomic_UI (
	       (UI_type *) fetch_ptr,
	       op_num,
	       (shared UI_type *) target,
	       (UI_type *) operand1,
	       (UI_type *) operand2);
      break;
    case UPC_LONG:
      __upc_atomic_L (
	       (L_type *) fetch_ptr,
	       op_num,
	       (shared L_type *) target,
	       (L_type *) operand1,
	       (L_type *) operand2);
      break;
    case UPC_ULONG:
      __upc_atomic_UL (
	       (UL_type *) fetch_ptr,
	       op_num,
	       (shared UL_type *) target,
	       (UL_type *) operand1,
	       (UL_type *) operand2);
      break;
    case UPC_LLONG:
      __upc_atomic_LL (
	       (LL_type *) fetch_ptr,
	       op_num,
	       (shared LL_type *) target,
	       (LL_type *) operand1,
	       (LL_type *) operand2);
      break;
    case UPC_ULLONG:
      __upc_atomic_ULL (
	       (ULL_type *) fetch_ptr,
	       op_num,
	       (shared ULL_type *) target,
	       (ULL_type *) operand1,
	       (ULL_type *) operand2);
      break;
    case UPC_INT32:
      __upc_atomic_I32 (
	       (I32_type *) fetch_ptr,
	       op_num,
	       (shared I32_type *) target,
	       (I32_type *) operand1,
	       (I32_type *) operand2);
      break;
    case UPC_UINT32:
      __upc_atomic_UI32 (
	       (UI32_type *) fetch_ptr,
	       op_num,
	       (shared UI32_type *) target,
	       (UI32_type *) operand1,
	       (UI32_type *) operand2);
      break;
    case UPC_INT64:
      __upc_atomic_I64 (
	       (I64_type *) fetch_ptr,
	       op_num,
	       (shared I64_type *) target,
	       (I64_type *) operand1,
	       (I64_type *) operand2);
      break;
    case UPC_UINT64:
      __upc_atomic_UI64 (
	       (UI64_type *) fetch_ptr,
	       op_num,
	       (shared UI64_type *) target,
	       (UI64_type *) operand1,
	       (UI64_type *) operand2);
      break;
    case UPC_FLOAT:
      __upc_atomic_F (
	       (F_type *) fetch_ptr,
	       op_num,
	       (shared F_type *) target,
	       (F_type *) operand1,
	       (F_type *) operand2);
      break;
    case UPC_DOUBLE:
      __upc_atomic_D (
	       (D_type *) fetch_ptr,
	       op_num,
	       (shared D_type *) target,
	       (D_type *) operand1,
	       (D_type *) operand2);
      break;
    case UPC_PTS:
      __upc_atomic_PTS (
	       (PTS_type *) fetch_ptr,
	       op_num,
	       (shared PTS_type *) target,
	       (PTS_type *) operand1,
	       (PTS_type *) operand2);
      break;
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
{
  return UPC_ATOMIC_PERFORMANCE_NOT_FAST;
}

/** @} */
