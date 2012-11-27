/*===-- config.h.cmake - UPC Runtime Support Library --------------------===*
|*
|*                     The LLVM Compiler Infrastructure
|*
|* Copyright 2012, Intrepid Technology, Inc.  All rights reserved.
|* This file is distributed under a BSD-style Open Source License.
|* See LICENSE-INTREPID.TXT for details.
|*
|*===---------------------------------------------------------------------===*/

/* config.h.in.  Generated from configure.ac by autoheader.  */

#ifndef __CONFIG_H__
#define __CONFIG_H__ 1


//begin gupcr_config_h

/* Define path to preferred GDB for backtrace */
#undef GUPCR_BACKTRACE_GDB

/* Define to preferred signal for UPC backtrace. */
#undef GUPCR_BACKTRACE_SIGNAL

/* Size of get/put bounce buffer */
#undef GUPCR_BOUNCE_BUFFER_SIZE

/* upc_global_exit() timeout in seconds. */
#undef GUPCR_GLOBAL_EXIT_TIMEOUT

/* Define to 1 if UPC runtime checks are supported. */
#undef GUPCR_HAVE_CHECKS

/* Define to 1 if UPC runtime debugging mode is enabled. */
#undef GUPCR_HAVE_DEBUG

/* Define if UPC GUM debug server is supported. */
#undef GUPCR_HAVE_GUM_DEBUG

/* Define to 1 if UPC runtime statistics collection is supported. */
#undef GUPCR_HAVE_STATS

/* Define to 1 if UPC runtime tracing is supported. */
#undef GUPCR_HAVE_TRACE

/* Maximum number of locks held per thread */
#define GUPCR_MAX_LOCKS @UPC_MAX_LOCKS@

/* Define to 1 if UPC runtime will use node local memory accesses. */
#undef GUPCR_NODE_LOCAL_MEM

/* Define to 1 if UPC node local access uses mmap-ed file. */
#undef GUPCR_NODE_LOCAL_MEM_MMAP

/* Define to 1 if UPC node local access uses Posix shared memory. */
#undef GUPCR_NODE_LOCAL_MEM_POSIX

/* Portals4 PTE base index. */
#undef GUPCR_PTE_BASE

/* Maximum number of children at each level of a collective operation tree. */
#define GUPCR_TREE_FANOUT @UPC_TREE_FANOUT@

/* Define to 1 if UPC runtime will use Portals4 triggered operations. */
#undef GUPCR_USE_PORTALS4_TRIGGERED_OPS

//end gupcr_config_h

/* Define to 1 if the target assembler supports .symver directive. */
#undef HAVE_AS_SYMVER_DIRECTIVE

/* Define to 1 if the target supports __attribute__((alias(...))). */
#undef HAVE_ATTRIBUTE_ALIAS

/* Define to 1 if the target supports __attribute__((dllexport)). */
#undef HAVE_ATTRIBUTE_DLLEXPORT

/* Define to 1 if the target supports __attribute__((visibility(...))). */
#undef HAVE_ATTRIBUTE_VISIBILITY

/* Define to 1 if you have the `backtrace' function. */
#undef HAVE_BACKTRACE

/* Define to 1 if you have the `backtrace_symbols' function. */
#undef HAVE_BACKTRACE_SYMBOLS

/* Define to 1 if you have the `backtrace_symbols_fd' function. */
#undef HAVE_BACKTRACE_SYMBOLS_FD

/* Define if the POSIX Semaphores do not work on your system. */
#undef HAVE_BROKEN_POSIX_SEMAPHORES

/* Define to 1 if the target assembler supports thread-local storage. */
#undef HAVE_CC_TLS

/* Define to 1 if you have the `clock_gettime' function. */
#undef HAVE_CLOCK_GETTIME

/* Define to 1 if you have the declaration of `sys_siglist', and to 0 if you
   don't. */
#undef HAVE_DECL_SYS_SIGLIST

/* Define to 1 if you have the <dlfcn.h> header file. */
#undef HAVE_DLFCN_H

/* Define to 1 if you have the <execinfo.h> header file. */
#undef HAVE_EXECINFO_H

/* Define to 1 if you have the <fcntl.h> header file. */
#undef HAVE_FCNTL_H

/* Define to 1 if you have the `fork' function. */
#undef HAVE_FORK

/* Define to 1 if you have the `ftruncate' function. */
#undef HAVE_FTRUNCATE

/* Define to 1 if you have the `getcwd' function. */
#undef HAVE_GETCWD

/* Define to 1 if you have the `gethostbyname' function. */
#undef HAVE_GETHOSTBYNAME

/* Define to 1 if you have the `gethostname' function. */
#undef HAVE_GETHOSTNAME

/* Define to 1 if you have the `getloadavg' function. */
#undef HAVE_GETLOADAVG

/* Define to 1 if you have the `getpagesize' function. */
#undef HAVE_GETPAGESIZE

/* Define if the compiler has a thread header that is non single. */
#undef HAVE_GTHR_DEFAULT

/* Define to 1 if you have the <inttypes.h> header file. */
#undef HAVE_INTTYPES_H

/* Use BFD library for improved backtrace. */
#undef HAVE_LIBBFD

/* Define to 1 if you have the <limits.h> header file. */
#undef HAVE_LIMITS_H

/* Define to 1 if your system has a GNU libc compatible `malloc' function, and
   to 0 otherwise. */
#undef HAVE_MALLOC

/* Define to 1 if you have the <memory.h> header file. */
#undef HAVE_MEMORY_H

/* Define to 1 if you have the `memset' function. */
#undef HAVE_MEMSET

/* Define to 1 if you have the `mkdir' function. */
#undef HAVE_MKDIR

/* Define to 1 if you have a working `mmap' system call. */
#undef HAVE_MMAP

/* Define to 1 if you have the `munmap' function. */
#undef HAVE_MUNMAP

/* Define to 1 if you have the <netdb.h> header file. */
#undef HAVE_NETDB_H

/* Define to 1 if you have the <netinet/in.h> header file. */
#undef HAVE_NETINET_IN_H

/* Define to 1 if pthread_{,attr_}{g,s}etaffinity_np is supported. */
#undef HAVE_PTHREAD_AFFINITY_NP

/* Define to 1 if the system has the type `ptrdiff_t'. */
#undef HAVE_PTRDIFF_T

/* Define to 1 if you have the <sched.h> header file. */
#undef HAVE_SCHED_H

/* Define to 1 if you have the <semaphore.h> header file. */
#undef HAVE_SEMAPHORE_H

/* Define to 1 if you have the 'shm_open' function. */
#undef HAVE_SHM_OPEN

/* Define to 1 if you have the `socket' function. */
#undef HAVE_SOCKET

/* Define to 1 if `stat' has the bug that it succeeds when given the
   zero-length file name argument. */
#undef HAVE_STAT_EMPTY_STRING_BUG

/* Define to 1 if you have the <stddef.h> header file. */
#undef HAVE_STDDEF_H

/* Define to 1 if you have the <stdint.h> header file. */
#undef HAVE_STDINT_H

/* Define to 1 if you have the <stdlib.h> header file. */
#undef HAVE_STDLIB_H

/* Define to 1 if you have the `strcasecmp' function. */
#undef HAVE_STRCASECMP

/* Define to 1 if you have the `strdup' function. */
#undef HAVE_STRDUP

/* Define to 1 if you have the `strerror' function. */
#undef HAVE_STRERROR

/* Define to 1 if you have the <strings.h> header file. */
#undef HAVE_STRINGS_H

/* Define to 1 if you have the <string.h> header file. */
#undef HAVE_STRING_H

/* Define to 1 if you have the `strtol' function. */
#undef HAVE_STRTOL

/* Define to 1 if you have the `strtoull' function. */
#undef HAVE_STRTOULL

/* Define to 1 if the target supports __sync_*_compare_and_swap. */
#undef HAVE_SYNC_BUILTINS

/* Define to 1 if the compiler provides the __sync_fetch_and_add function for
   uint32 */
#undef HAVE_SYNC_FETCH_AND_ADD_4

/* Define to 1 if the compiler provides the __sync_fetch_and_add function for
   uint64 */
#undef HAVE_SYNC_FETCH_AND_ADD_8

/* Define to 1 if you have the <sys/loadavg.h> header file. */
#undef HAVE_SYS_LOADAVG_H

/* Define to 1 if you have the <sys/socket.h> header file. */
#undef HAVE_SYS_SOCKET_H

/* Define to 1 if you have the <sys/stat.h> header file. */
#undef HAVE_SYS_STAT_H

/* Define to 1 if you have the <sys/types.h> header file. */
#undef HAVE_SYS_TYPES_H

/* Define to 1 if you have <sys/wait.h> that is POSIX.1 compatible. */
#undef HAVE_SYS_WAIT_H

/* Define to 1 if the target supports thread-local storage. */
#undef HAVE_TLS

/* Define to 1 if you have the <unistd.h> header file. */
#undef HAVE_UNISTD_H

/* Define to 1 if UPC backtrace is enabled. */
#undef HAVE_UPC_BACKTRACE

/* Define to 1 if UPC backtrace with GDB is enabled. */
#undef HAVE_UPC_BACKTRACE_GDB

/* Define to 1 if UPC backtrace signal is enabled. */
#undef HAVE_UPC_BACKTRACE_SIGNAL

/* Define to 1 if UPC link script is supported. */
#undef HAVE_UPC_LINK_SCRIPT

/* Define to 1 if you have the `vfork' function. */
#undef HAVE_VFORK

/* Define to 1 if you have the <vfork.h> header file. */
#undef HAVE_VFORK_H

/* Define to 1 if `fork' works. */
#undef HAVE_WORKING_FORK

/* Define to 1 if `vfork' works. */
#undef HAVE_WORKING_VFORK

/* Define to 1 if GNU symbol versioning is used for libgupc. */
#undef LIBGUPC_GNU_SYMBOL_VERSIONING

/* Define to 1 if `lstat' dereferences a symlink specified with a trailing
   slash. */
#undef LSTAT_FOLLOWS_SLASHED_SYMLINK

/* Define to the sub-directory in which libtool stores uninstalled libraries.
   */
#undef LT_OBJDIR

/* Name of package */
#undef PACKAGE

/* Define to the address where bug reports for this package should be sent. */
#undef PACKAGE_BUGREPORT

/* Define to the full name of this package. */
#undef PACKAGE_NAME

/* Define to the full name and version of this package. */
#undef PACKAGE_STRING

/* Define to the one symbol short name of this package. */
#undef PACKAGE_TARNAME

/* Define to the home page for this package. */
#undef PACKAGE_URL

/* Define to the version of this package. */
#undef PACKAGE_VERSION

/* The size of `char', as computed by sizeof. */
#undef SIZEOF_CHAR

/* The size of `int', as computed by sizeof. */
#undef SIZEOF_INT

/* The size of `long', as computed by sizeof. */
#undef SIZEOF_LONG

/* The size of `short', as computed by sizeof. */
#undef SIZEOF_SHORT

/* The size of `void *', as computed by sizeof. */
#undef SIZEOF_VOID_P

/* Define to 1 if you have the ANSI C header files. */
#undef STDC_HEADERS

/* Define if you can safely include both <string.h> and <strings.h>. */
#undef STRING_WITH_STRINGS

/* Define to 1 if you can safely include both <sys/time.h> and <time.h>. */
#undef TIME_WITH_SYS_TIME

/* Version number of package */
#undef VERSION

/* Number of bits in a file offset, on hosts where this is settable. */
#undef _FILE_OFFSET_BITS

/* Define for large files, on AIX-style hosts. */
#undef _LARGE_FILES

/* Define to empty if `const' does not conform to ANSI C. */
#undef const

/* Define to `__inline__' or `__inline' if that's what the C compiler
   calls it, or to nothing if 'inline' is not supported under any name.  */
#ifndef __cplusplus
#undef inline
#endif

/* Define to rpl_malloc if the replacement function should be used. */
#undef malloc

/* Define to `int' if <sys/types.h> does not define. */
#undef mode_t

/* Define to `long int' if <sys/types.h> does not define. */
#undef off_t

/* Define to `int' if <sys/types.h> does not define. */
#undef pid_t

/* Define to `unsigned int' if <sys/types.h> does not define. */
#undef size_t

/* Define as `fork' if `vfork' does not work. */
#undef vfork

/* Define to empty if the keyword `volatile' does not work. Warning: valid
   code using `volatile' can become incorrect without. Disable with care. */
#undef volatile


#ifndef ARG_UNUSED
# define ARG_UNUSED(NAME) NAME __attribute__ ((__unused__))
#endif



#endif /* __CONFIG_H__ */

