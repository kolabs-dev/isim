#pragma once
#include <_isim_cdefs.h>
#define IFNAMSIZ 16
#define IF_NAMESIZE IFNAMSIZ
#define IFF_UP 0x1
#define IFF_BROADCAST 0x2
#define IFF_DEBUG 0x4
#define IFF_LOOPBACK 0x8
#define IFF_POINTOPOINT 0x10
#define IFF_RUNNING 0x40
#define IFF_NOARP 0x80
#define IFF_PROMISC 0x100
#define IFF_ALLMULTI 0x200
#define IFF_MULTICAST 0x8000
__BEGIN_DECLS
unsigned int if_nametoindex(const char *);
char *if_indextoname(unsigned int, char *);
__END_DECLS
