#pragma once
extern int *__error(void);
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
