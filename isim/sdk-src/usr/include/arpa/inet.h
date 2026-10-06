/* isim SDK (self-authored) */
#pragma once
#include <_isim_cdefs.h>
#include <netinet/in.h>
__BEGIN_DECLS
in_addr_t inet_addr(const char *);
char *inet_ntoa(struct in_addr);
int inet_aton(const char *, struct in_addr *);
int inet_pton(int, const char *, void *);
const char *inet_ntop(int, const void *, char *, socklen_t);
__END_DECLS
