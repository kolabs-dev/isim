#pragma once
#include <_isim_cdefs.h>
#define FIOCLEX 0x20006601UL
#define FIONCLEX 0x20006602UL
#define FIONREAD 0x4004667fUL
#define FIONBIO 0x8004667eUL
__BEGIN_DECLS
int ioctl(int, unsigned long, ...);
__END_DECLS
