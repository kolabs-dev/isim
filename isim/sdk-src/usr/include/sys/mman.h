#pragma once
/* isim SDK (self-authored, Apple's values): memory mapping. isim's libSystem translates the flags for the host. */
#include <_isim_cdefs.h>
#include <sys/types.h>
__BEGIN_DECLS
#define PROT_NONE 0x00
#define PROT_READ 0x01
#define PROT_WRITE 0x02
#define PROT_EXEC 0x04
#define MAP_SHARED 0x0001
#define MAP_PRIVATE 0x0002
#define MAP_FIXED 0x0010
#define MAP_RENAME 0x0020
#define MAP_NORESERVE 0x0040
#define MAP_NOCACHE 0x0400
#define MAP_JIT 0x0800
#define MAP_FILE 0x0000
#define MAP_ANON 0x1000
#define MAP_ANONYMOUS MAP_ANON
#define MAP_FAILED ((void *)-1)
#define MCL_CURRENT 0x0001
#define MCL_FUTURE 0x0002
#define MS_ASYNC 0x0001
#define MS_INVALIDATE 0x0002
#define MS_SYNC 0x0010
#define MS_KILLPAGES 0x0004
#define MS_DEACTIVATE 0x0008
#define POSIX_MADV_NORMAL 0
#define POSIX_MADV_RANDOM 1
#define POSIX_MADV_SEQUENTIAL 2
#define POSIX_MADV_WILLNEED 3
#define POSIX_MADV_DONTNEED 4
#define MADV_NORMAL POSIX_MADV_NORMAL
#define MADV_RANDOM POSIX_MADV_RANDOM
#define MADV_SEQUENTIAL POSIX_MADV_SEQUENTIAL
#define MADV_WILLNEED POSIX_MADV_WILLNEED
#define MADV_DONTNEED POSIX_MADV_DONTNEED
#define MADV_FREE 5
#define MADV_ZERO_WIRED_PAGES 6
#define MADV_FREE_REUSABLE 7
#define MADV_FREE_REUSE 8
#define MADV_CAN_REUSE 9
#define MINHERIT_SHARE 0
#define MINHERIT_COPY 1
#define MINHERIT_NONE 2
void *mmap(void *, size_t, int, int, int, off_t);
int munmap(void *, size_t);
int mprotect(void *, size_t, int);
int msync(void *, size_t, int);
int madvise(void *, size_t, int);
int posix_madvise(void *, size_t, int);
int mlock(const void *, size_t);
int munlock(const void *, size_t);
int mlockall(int);
int munlockall(void);
int minherit(void *, size_t, int);
int mincore(const void *, size_t, char *);
__END_DECLS
