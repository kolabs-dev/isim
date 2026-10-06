/* isim SDK (self-authored): Internet addresses, Darwin layouts. */
#pragma once
#include <_isim_cdefs.h>
#include <stdint.h>
#include <sys/socket.h>
typedef uint16_t in_port_t;
typedef uint32_t in_addr_t;
struct in_addr { in_addr_t s_addr; };
struct sockaddr_in { unsigned char sin_len; sa_family_t sin_family; in_port_t sin_port; struct in_addr sin_addr; char sin_zero[8]; };
struct in6_addr { union { uint8_t __u6_addr8[16]; uint16_t __u6_addr16[8]; uint32_t __u6_addr32[4]; } __u6_addr; };
#define s6_addr __u6_addr.__u6_addr8
struct sockaddr_in6 { unsigned char sin6_len; sa_family_t sin6_family; in_port_t sin6_port; uint32_t sin6_flowinfo; struct in6_addr sin6_addr; uint32_t sin6_scope_id; };
struct ip_mreq { struct in_addr imr_multiaddr; struct in_addr imr_interface; };
struct ipv6_mreq { struct in6_addr ipv6mr_multiaddr; unsigned int ipv6mr_interface; };
#define IPPROTO_IP 0
#define IPPROTO_ICMP 1
#define IPPROTO_TCP 6
#define IPPROTO_UDP 17
#define IPPROTO_IPV6 41
#define IPPROTO_ICMPV6 58
#define IPPROTO_RAW 255
#define INADDR_ANY ((in_addr_t)0x00000000)
#define INADDR_BROADCAST ((in_addr_t)0xffffffff)
#define INADDR_LOOPBACK ((in_addr_t)0x7f000001)
#define INADDR_NONE ((in_addr_t)0xffffffff)
#define INET_ADDRSTRLEN 16
#define INET6_ADDRSTRLEN 46
#define IP_HDRINCL 2
#define IP_TOS 3
#define IP_TTL 4
#define IP_MULTICAST_IF 9
#define IP_MULTICAST_TTL 10
#define IP_MULTICAST_LOOP 11
#define IP_ADD_MEMBERSHIP 12
#define IP_DROP_MEMBERSHIP 13
#define IPV6_UNICAST_HOPS 4
#define IPV6_JOIN_GROUP 12
#define IPV6_LEAVE_GROUP 13
#define IPV6_V6ONLY 27
__BEGIN_DECLS
extern const struct in6_addr in6addr_any;
extern const struct in6_addr in6addr_loopback;
__END_DECLS
/* byte order (x86_64 and arm64 are little-endian) */
static __inline__ uint16_t __isim_bswap16(uint16_t x) { return __builtin_bswap16(x); }
static __inline__ uint32_t __isim_bswap32(uint32_t x) { return __builtin_bswap32(x); }
#define htons(x) __isim_bswap16(x)
#define ntohs(x) __isim_bswap16(x)
#define htonl(x) __isim_bswap32(x)
#define ntohl(x) __isim_bswap32(x)
