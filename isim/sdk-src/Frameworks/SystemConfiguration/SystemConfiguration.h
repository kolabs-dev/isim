#pragma once
/* isim SystemConfiguration: network reachability (SCNetworkReachability) from the host's connectivity: a host or address
   is reachable while the host has a network connection (Wi-Fi or wired; never WWAN: isim simulates no cellular radio).
   Adapted: names are not resolved first, and changes are noticed by polling every two seconds. */
#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <dispatch/dispatch.h>
__BEGIN_DECLS
typedef const struct __SCNetworkReachability *SCNetworkReachabilityRef;
typedef CF_OPTIONS(uint32_t, SCNetworkReachabilityFlags) {
    kSCNetworkReachabilityFlagsTransientConnection = 1 << 0, kSCNetworkReachabilityFlagsReachable = 1 << 1,
    kSCNetworkReachabilityFlagsConnectionRequired = 1 << 2, kSCNetworkReachabilityFlagsConnectionOnTraffic = 1 << 3,
    kSCNetworkReachabilityFlagsInterventionRequired = 1 << 4, kSCNetworkReachabilityFlagsConnectionOnDemand = 1 << 5,
    kSCNetworkReachabilityFlagsIsLocalAddress = 1 << 16, kSCNetworkReachabilityFlagsIsDirect = 1 << 17,
    kSCNetworkReachabilityFlagsIsWWAN = 1 << 18,
    kSCNetworkReachabilityFlagsConnectionAutomatic = kSCNetworkReachabilityFlagsConnectionOnTraffic,
};
typedef struct {
    CFIndex version; void *info;
    const void *(*retain)(const void *info); void (*release)(const void *info); CFStringRef (*copyDescription)(const void *info);
} SCNetworkReachabilityContext;
typedef void (*SCNetworkReachabilityCallBack)(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);
SCNetworkReachabilityRef SCNetworkReachabilityCreateWithName(CFAllocatorRef allocator, const char *nodename) CF_RETURNS_RETAINED;
SCNetworkReachabilityRef SCNetworkReachabilityCreateWithAddress(CFAllocatorRef allocator, const struct sockaddr *address) CF_RETURNS_RETAINED;
SCNetworkReachabilityRef SCNetworkReachabilityCreateWithAddressPair(CFAllocatorRef allocator, const struct sockaddr *localAddress,
                                                                    const struct sockaddr *remoteAddress) CF_RETURNS_RETAINED;
Boolean SCNetworkReachabilityGetFlags(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags *flags);
Boolean SCNetworkReachabilitySetCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityCallBack callout, SCNetworkReachabilityContext *context);
Boolean SCNetworkReachabilitySetDispatchQueue(SCNetworkReachabilityRef target, dispatch_queue_t queue);
CFTypeID SCNetworkReachabilityGetTypeID(void);
__END_DECLS
