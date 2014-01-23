/*===-- upc_numa.c - UPC Runtime Support Library -------------------------===
|*
|*                     The LLVM Compiler Infrastructure
|*
|* Copyright 2012-2014, Intrepid Technology, Inc.  All rights reserved.
|* This file is distributed under a BSD-style Open Source License.
|* See LICENSE-INTREPID.TXT for details.
|*
|*===---------------------------------------------------------------------===*/

#include <numa.h>
#include "upc_config.h"
#include "upc_sysdep.h"
#include "upc_defs.h"
#include "upc_sup.h"
#include "upc_affinity.h"

int
__upc_numa_supported (void)
{
  return 1;
}

int
__upc_numa_init (const upc_info_p u, const char **ARG_UNUSED (err_msg))
{
  u->num_nodes = numa_max_node () + 1;
  return 1;
}

int
__upc_numa_allocate (const upc_info_p u, const int thread_id,
		     int *sched_affinity, int *mem_affinity,
		     const char **ARG_UNUSED (err_msg))
{
  int pelem;
  /* schedule threads over nodes */
  pelem = thread_id % u->num_nodes;
  *sched_affinity = pelem;
  *mem_affinity = pelem;
  return 1;
}

/* Set node scheduling policy. */

void
__upc_numa_sched_set (const upc_info_p u, const int thread_id)
{
#if defined(LIBNUMA_API_VERSION) && (LIBNUMA_API_VERSION==2)
  struct bitmask *set = numa_allocate_cpumask(); 
  numa_node_to_cpus (u->thread_info[thread_id].sched_affinity, set);
  if (numa_sched_setaffinity (0, set))
    {
      __upc_fatal ("Scheduling cannot be set");
    }
#else
  cpu_set_t set;
  CPU_ZERO (&set);
  numa_node_to_cpus (u->thread_info[thread_id].sched_affinity,
		     (unsigned long *) &set, sizeof (set));
  if (sched_setaffinity (0, sizeof (set), &set))
    {
      __upc_fatal ("Scheduling cannot be set");
    }
#endif
}

/* Set memory allocation policy */

void
__upc_numa_memory_affinity_set (const upc_info_p u, const int thread_id)
{
  if (u->mem_policy == GUPCR_MEM_POLICY_NODE)
    {
      numa_set_preferred (u->thread_info[thread_id].mem_affinity);
    }
  else if (u->mem_policy == GUPCR_MEM_POLICY_STRICT)
    {
#if defined(LIBNUMA_API_VERSION) && (LIBNUMA_API_VERSION==2)
      struct bitmask *nodemask = numa_bitmask_alloc(u->num_nodes);
      numa_bitmask_setbit (nodemask, u->thread_info[thread_id].mem_affinity);
      numa_set_membind (nodemask);
      numa_bitmask_free (nodemask);
#else
      nodemask_t nodemask;
      nodemask_zero (&nodemask);
      nodemask_set (&nodemask, u->thread_info[thread_id].mem_affinity);
      numa_set_membind (&nodemask);
#endif
    }
}

/* Set affinity for memory region */

void
__upc_numa_memory_region_affinity_set (const upc_info_p u,
				       const int thread_id,
				       const void *region, const size_t size)
{
  if ((u->sched_policy != GUPCR_SCHED_POLICY_AUTO) &&
         (u->mem_policy != GUPCR_MEM_POLICY_AUTO))
    {
      /* memory is being allocated with affinity to "thread" */
      if (thread_id == MYTHREAD)
	numa_tonode_memory ((void *) region, size,
			    u->thread_info[thread_id].mem_affinity);
    }
}
