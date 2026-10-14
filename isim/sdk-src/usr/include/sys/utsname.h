#pragma once
/* isim SDK (self-authored, Apple's layout): uname(3). Like Apple's Simulator, it describes the Mac (Darwin, x86_64). */
#include <_isim_cdefs.h>
__BEGIN_DECLS
#define _SYS_NAMELEN 256
struct utsname {
    char sysname[_SYS_NAMELEN];
    char nodename[_SYS_NAMELEN];
    char release[_SYS_NAMELEN];
    char version[_SYS_NAMELEN];
    char machine[_SYS_NAMELEN];
};
int uname(struct utsname *);
__END_DECLS
