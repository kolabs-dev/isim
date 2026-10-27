#pragma once
/* isim SDK (self-authored, Apple's declarations and values): CFSocket, a BSD socket whose readiness is delivered to
 * callbacks on the run loops its run loop source is added to (adapted: the socket is watched by a dispatch source and
 * the source is signalled when it is readable, writable or connected). Addresses are Darwin socket addresses
 * (struct sockaddr_in / sockaddr_in6 / sockaddr_un in a CFData). The name registry (CFSocketRegisterValue, ...) is a
 * stub: there is no name server, and its functions fail. */
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFData.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFDate.h>
#include <CoreFoundation/CFRunLoop.h>

__BEGIN_DECLS
CF_IMPLICIT_BRIDGING_ENABLED
_Pragma("clang assume_nonnull begin")

typedef int CFSocketNativeHandle;
typedef struct __attribute__((objc_bridge_mutable(id))) __CFSocket *CFSocketRef;

typedef CF_ENUM(CFIndex, CFSocketError) {
    kCFSocketSuccess = 0,
    kCFSocketError = -1L,
    kCFSocketTimeout = -2L
};

typedef struct {
    SInt32 protocolFamily;
    SInt32 socketType;
    SInt32 protocol;
    CFDataRef address;
} CFSocketSignature;

typedef CF_OPTIONS(CFOptionFlags, CFSocketCallBackType) {
    kCFSocketNoCallBack = 0,
    kCFSocketReadCallBack = 1,
    kCFSocketAcceptCallBack = 2,
    kCFSocketDataCallBack = 3,
    kCFSocketConnectCallBack = 4,
    kCFSocketWriteCallBack = 8
};

/* socket flags (CFSocketSetSocketFlags) */
enum : CFOptionFlags {
    kCFSocketAutomaticallyReenableReadCallBack = 1,
    kCFSocketAutomaticallyReenableAcceptCallBack = 2,
    kCFSocketAutomaticallyReenableDataCallBack = 3,
    kCFSocketAutomaticallyReenableWriteCallBack = 8,
    kCFSocketLeaveErrors = 64,
    kCFSocketCloseOnInvalidate = 128
};

/* address: the peer (accept, data callbacks); data: the accepted CFSocketNativeHandle * (accept), the CFDataRef read
   (data: empty at end of stream), an SInt32 * error or NULL (connect) */
typedef void (*CFSocketCallBack)(CFSocketRef s, CFSocketCallBackType type, CFDataRef _Nullable address, const void *_Nullable data,
                                 void *_Nullable info);
typedef struct {
    CFIndex version;
    void *_Nullable info;
    const void *_Nullable (*_Nullable retain)(const void *_Nullable info);
    void (*_Nullable release)(const void *_Nullable info);
    CFStringRef _Nonnull (*_Nullable copyDescription)(const void *_Nullable info);
} CFSocketContext;

CF_EXPORT CFTypeID CFSocketGetTypeID(void);
CF_EXPORT CFSocketRef _Nullable CFSocketCreate(CFAllocatorRef _Nullable allocator, SInt32 protocolFamily, SInt32 socketType, SInt32 protocol,
                                               CFOptionFlags callBackTypes, CFSocketCallBack _Nullable callout,
                                               const CFSocketContext *_Nullable context);
CF_EXPORT CFSocketRef _Nullable CFSocketCreateWithNative(CFAllocatorRef _Nullable allocator, CFSocketNativeHandle sock, CFOptionFlags callBackTypes,
                                                         CFSocketCallBack _Nullable callout, const CFSocketContext *_Nullable context);
/* a socket bound (and, for streams, listening) at the signature's address */
CF_EXPORT CFSocketRef _Nullable CFSocketCreateWithSocketSignature(CFAllocatorRef _Nullable allocator, const CFSocketSignature *signature,
                                                                  CFOptionFlags callBackTypes, CFSocketCallBack _Nullable callout,
                                                                  const CFSocketContext *_Nullable context);
/* a socket connected to the signature's address (a negative timeout connects in the background) */
CF_EXPORT CFSocketRef _Nullable CFSocketCreateConnectedToSocketSignature(CFAllocatorRef _Nullable allocator, const CFSocketSignature *signature,
                                                                         CFOptionFlags callBackTypes, CFSocketCallBack _Nullable callout,
                                                                         const CFSocketContext *_Nullable context, CFTimeInterval timeout);

CF_EXPORT CFSocketError CFSocketSetAddress(CFSocketRef s, CFDataRef address);
CF_EXPORT CFSocketError CFSocketConnectToAddress(CFSocketRef s, CFDataRef address, CFTimeInterval timeout);
CF_EXPORT void CFSocketInvalidate(CFSocketRef s);
CF_EXPORT Boolean CFSocketIsValid(CFSocketRef s);
CF_EXPORT CFDataRef _Nullable CFSocketCopyAddress(CFSocketRef s);
CF_EXPORT CFDataRef _Nullable CFSocketCopyPeerAddress(CFSocketRef s);
CF_EXPORT void CFSocketGetContext(CFSocketRef s, CFSocketContext *context);
CF_EXPORT CFSocketNativeHandle CFSocketGetNative(CFSocketRef s);
CF_EXPORT CFRunLoopSourceRef _Nullable CFSocketCreateRunLoopSource(CFAllocatorRef _Nullable allocator, CFSocketRef s, CFIndex order);
CF_EXPORT CFOptionFlags CFSocketGetSocketFlags(CFSocketRef s);
CF_EXPORT void CFSocketSetSocketFlags(CFSocketRef s, CFOptionFlags flags);
CF_EXPORT void CFSocketDisableCallBacks(CFSocketRef s, CFOptionFlags callBackTypes);
CF_EXPORT void CFSocketEnableCallBacks(CFSocketRef s, CFOptionFlags callBackTypes);
CF_EXPORT CFSocketError CFSocketSendData(CFSocketRef s, CFDataRef _Nullable address, CFDataRef data, CFTimeInterval timeout);

/* the name registry (stub: no name server; registering and looking up fail with kCFSocketError) */
CF_EXPORT CFSocketError CFSocketRegisterValue(const CFSocketSignature *nameServerSignature, CFTimeInterval timeout, CFStringRef name,
                                              CFPropertyListRef _Nullable value);
CF_EXPORT CFSocketError CFSocketCopyRegisteredValue(const CFSocketSignature *nameServerSignature, CFTimeInterval timeout, CFStringRef name,
                                                    CFPropertyListRef _Nullable *_Nullable value,
                                                    CFDataRef _Nullable *_Nullable nameServerAddress);
CF_EXPORT CFSocketError CFSocketRegisterSocketSignature(const CFSocketSignature *nameServerSignature, CFTimeInterval timeout, CFStringRef name,
                                                        const CFSocketSignature *signature);
CF_EXPORT CFSocketError CFSocketCopyRegisteredSocketSignature(const CFSocketSignature *nameServerSignature, CFTimeInterval timeout,
                                                              CFStringRef name, CFSocketSignature *signature,
                                                              CFDataRef _Nullable *_Nullable nameServerAddress);
CF_EXPORT CFSocketError CFSocketUnregister(const CFSocketSignature *nameServerSignature, CFTimeInterval timeout, CFStringRef name);
CF_EXPORT void CFSocketSetDefaultNameRegistryPortNumber(UInt16 port);
CF_EXPORT UInt16 CFSocketGetDefaultNameRegistryPortNumber(void);
CF_EXPORT const CFStringRef kCFSocketCommandKey;
CF_EXPORT const CFStringRef kCFSocketNameKey;
CF_EXPORT const CFStringRef kCFSocketValueKey;
CF_EXPORT const CFStringRef kCFSocketResultKey;
CF_EXPORT const CFStringRef kCFSocketErrorKey;
CF_EXPORT const CFStringRef kCFSocketRegisterCommand;
CF_EXPORT const CFStringRef kCFSocketRetrieveCommand;

_Pragma("clang assume_nonnull end")
CF_IMPLICIT_BRIDGING_DISABLED
__END_DECLS
