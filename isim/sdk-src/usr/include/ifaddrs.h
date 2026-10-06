#pragma once
#include <_isim_cdefs.h>
#include <sys/socket.h>
struct ifaddrs {
    struct ifaddrs *ifa_next;
    char *ifa_name;
    unsigned int ifa_flags;
    struct sockaddr *ifa_addr;
    struct sockaddr *ifa_netmask;
    struct sockaddr *ifa_dstaddr;
    void *ifa_data;
};
__BEGIN_DECLS
int getifaddrs(struct ifaddrs **);
void freeifaddrs(struct ifaddrs *);
__END_DECLS
