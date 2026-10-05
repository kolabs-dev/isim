#pragma once
#include <_isim_cdefs.h>
__BEGIN_DECLS
extern int *__error(void);
__END_DECLS
#define errno (*__error())
#define EPERM 1
#define ENOENT 2
#define EINTR 4
#define EIO 5
#define ENOMEM 12
#define EACCES 13
#define EBUSY 16
#define EEXIST 17
#define EINVAL 22
#define EAGAIN 35
#define ETIMEDOUT 60
#define ESRCH 3
#define E2BIG 7
#define EBADF 9
#define ECHILD 10
#define EDEADLK 11
#define EFAULT 14
#define ENOTDIR 20
#define EISDIR 21
#define ENFILE 23
#define EMFILE 24
#define ENOSPC 28
#define ERANGE 34
#define EDOM 33
#define EWOULDBLOCK EAGAIN
#define EINPROGRESS 36
#define ENOTSUP 45
#define ENOSYS 78
#define EOVERFLOW 84
#define EILSEQ 92
