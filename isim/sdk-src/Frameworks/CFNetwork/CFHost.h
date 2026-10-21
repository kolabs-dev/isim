#pragma once
/* isim SDK (self-authored, Apple's declarations and values): CFHost, name and address resolution. Adapted: through the
   host's resolver (getaddrinfo / getnameinfo, Darwin socket addresses); reachability is SystemConfiguration's. */
#include <CoreFoundation/CoreFoundation.h>
#include <CFNetwork/CFNetworkErrors.h>
__BEGIN_DECLS
/* like Apple's header: nullability given, not audited for ARC (Swift sees Unmanaged<CFHost> from the Create functions) */
_Pragma("clang assume_nonnull begin")
typedef struct __CFHost *CFHostRef;
CFN_EXPORT const SInt32 kCFStreamErrorDomainNetDB;                /* the error is a getaddrinfo() EAI_* value */
CFN_EXPORT const SInt32 kCFStreamErrorDomainSystemConfiguration;
typedef CF_ENUM(int, CFHostInfoType) {
    kCFHostAddresses = 0,
    kCFHostNames = 1,
    kCFHostReachability = 2
};
typedef struct {
    CFIndex version;
    void *_Nullable info;
    const void *_Nullable (*_Nullable retain)(const void *_Nullable info);
    void (*_Nullable release)(const void *_Nullable info);
    CFStringRef _Nullable (*_Nullable copyDescription)(const void *_Nullable info);
} CFHostClientContext;
typedef void (*CFHostClientCallBack)(CFHostRef theHost, CFHostInfoType typeInfo, const CFStreamError *_Nullable error, void *_Nullable info);

CFN_EXPORT CFTypeID CFHostGetTypeID(void);
CFN_EXPORT CFHostRef CFHostCreateWithName(CFAllocatorRef _Nullable allocator, CFStringRef hostname);
CFN_EXPORT CFHostRef CFHostCreateWithAddress(CFAllocatorRef _Nullable allocator, CFDataRef addr);
CFN_EXPORT CFHostRef CFHostCreateCopy(CFAllocatorRef _Nullable alloc, CFHostRef host);
/* without a client (CFHostSetClient) it resolves before returning; with one, in the background, and the client's
   callback runs on the run loops the host is scheduled on */
CFN_EXPORT Boolean CFHostStartInfoResolution(CFHostRef theHost, CFHostInfoType info, CFStreamError *_Nullable error);
/* CFArray of CFData (struct sockaddr) */
CFN_EXPORT CFArrayRef _Nullable CFHostGetAddressing(CFHostRef theHost, Boolean *_Nullable hasBeenResolved);
CFN_EXPORT CFArrayRef _Nullable CFHostGetNames(CFHostRef theHost, Boolean *_Nullable hasBeenResolved);
/* CFData holding SCNetworkReachabilityFlags */
CFN_EXPORT CFDataRef _Nullable CFHostGetReachability(CFHostRef theHost, Boolean *_Nullable hasBeenResolved);
CFN_EXPORT void CFHostCancelInfoResolution(CFHostRef theHost, CFHostInfoType info);
CFN_EXPORT Boolean CFHostSetClient(CFHostRef theHost, CFHostClientCallBack _Nullable clientCB, CFHostClientContext *_Nullable clientContext);
CFN_EXPORT void CFHostScheduleWithRunLoop(CFHostRef theHost, CFRunLoopRef runLoop, CFStringRef runLoopMode);
CFN_EXPORT void CFHostUnscheduleFromRunLoop(CFHostRef theHost, CFRunLoopRef runLoop, CFStringRef runLoopMode);
_Pragma("clang assume_nonnull end")
__END_DECLS
