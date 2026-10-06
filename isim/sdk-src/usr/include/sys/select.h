#pragma once
#include <_isim_cdefs.h>
#include <sys/time.h>
#define FD_SETSIZE 1024
typedef struct fd_set { int fds_bits[FD_SETSIZE / 32]; } fd_set;
#define FD_SET(n, p) ((p)->fds_bits[(unsigned)(n) / 32] |= (int)(1u << ((unsigned)(n) % 32)))
#define FD_CLR(n, p) ((p)->fds_bits[(unsigned)(n) / 32] &= ~(int)(1u << ((unsigned)(n) % 32)))
#define FD_ISSET(n, p) (((p)->fds_bits[(unsigned)(n) / 32] & (int)(1u << ((unsigned)(n) % 32))) != 0)
#define FD_ZERO(p) __builtin_memset((p), 0, sizeof(*(p)))
__BEGIN_DECLS
int select(int, fd_set *, fd_set *, fd_set *, struct timeval *);
__END_DECLS
