#pragma once
/* isim SDK (self-authored, Apple's declarations and values): CFNetwork's error domain, the CFHost codes and their keys */
#include <CoreFoundation/CoreFoundation.h>
__BEGIN_DECLS
CF_IMPLICIT_BRIDGING_ENABLED
#ifndef CFN_EXPORT
#define CFN_EXPORT CF_EXPORT
#endif
CFN_EXPORT const CFStringRef kCFErrorDomainCFNetwork;
CFN_EXPORT const CFStringRef kCFErrorDomainWinSock;
typedef CF_ENUM(int, CFNetworkErrors) {
    kCFHostErrorHostNotFound = 1,
    kCFHostErrorUnknown = 2,
};
/* the getaddrinfo() error (EAI_*) behind a kCFHostErrorUnknown */
CFN_EXPORT const CFStringRef kCFGetAddrInfoFailureKey;
CF_IMPLICIT_BRIDGING_DISABLED
__END_DECLS
