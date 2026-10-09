#pragma once
/* flock(2); the LOCK_* values match Linux, so flock is a passthrough */
#include <_isim_cdefs.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>
__BEGIN_DECLS
#define LOCK_SH 0x01
#define LOCK_EX 0x02
#define LOCK_NB 0x04
#define LOCK_UN 0x08
int flock(int, int);
__END_DECLS
