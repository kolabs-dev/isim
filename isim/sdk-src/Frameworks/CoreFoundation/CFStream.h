#pragma once
/* isim SDK (self-authored, Apple's declarations and values): CFReadStream and CFWriteStream, toll-free bridged with
 * Foundation's NSInputStream and NSOutputStream (a CFReadStreamRef is the NSInputStream: adapted, the functions call the
 * stream's methods). A client (CFReadStreamSetClient) is called on the run loops the stream is scheduled on, or on its
 * dispatch queue, for the events it asked for; a stream with a client does not call its NSStream delegate. Socket
 * streams connect to a host, an address (CFStreamCreatePairWithPeerSocketSignature) or adopt a connected native socket
 * (CFStreamCreatePairWithSocket); TLS (CFNetwork's kCFStreamPropertySSLSettings) is set up when the stream opens. */
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFURL.h>
#include <CoreFoundation/CFRunLoop.h>
#include <CoreFoundation/CFSocket.h>
#include <CoreFoundation/CFError.h>
#include <dispatch/dispatch.h>

__BEGIN_DECLS
CF_IMPLICIT_BRIDGING_ENABLED
_Pragma("clang assume_nonnull begin")

typedef CFStringRef CFStreamPropertyKey CF_EXTENSIBLE_STRING_ENUM;

typedef CF_ENUM(CFIndex, CFStreamStatus) {
    kCFStreamStatusNotOpen = 0,
    kCFStreamStatusOpening,
    kCFStreamStatusOpen,
    kCFStreamStatusReading,
    kCFStreamStatusWriting,
    kCFStreamStatusAtEnd,
    kCFStreamStatusClosed,
    kCFStreamStatusError
};

typedef CF_OPTIONS(CFOptionFlags, CFStreamEventType) {
    kCFStreamEventNone = 0,
    kCFStreamEventOpenCompleted = 1,
    kCFStreamEventHasBytesAvailable = 2,
    kCFStreamEventCanAcceptBytes = 4,
    kCFStreamEventErrorOccurred = 8,
    kCFStreamEventEndEncountered = 16
};

typedef struct {
    CFIndex version;
    void *_Nullable info;
    void *_Nullable (*_Nullable retain)(void *_Nullable info);
    void (*_Nullable release)(void *_Nullable info);
    CFStringRef _Nullable (*_Nullable copyDescription)(void *_Nullable info);
} CFStreamClientContext;

typedef struct __attribute__((objc_bridge_mutable(NSInputStream))) __CFReadStream *CFReadStreamRef;
typedef struct __attribute__((objc_bridge_mutable(NSOutputStream))) __CFWriteStream *CFWriteStreamRef;

typedef void (*CFReadStreamClientCallBack)(CFReadStreamRef _Null_unspecified stream, CFStreamEventType type,
                                           void *_Null_unspecified clientCallBackInfo);
typedef void (*CFWriteStreamClientCallBack)(CFWriteStreamRef _Null_unspecified stream, CFStreamEventType type,
                                            void *_Null_unspecified clientCallBackInfo);

CF_EXPORT CFTypeID CFReadStreamGetTypeID(void);
CF_EXPORT CFTypeID CFWriteStreamGetTypeID(void);

/* the bytes written to a CFWriteStreamCreateWithAllocatedBuffers stream (CFData) */
CF_EXPORT const CFStreamPropertyKey kCFStreamPropertyDataWritten;

CF_EXPORT CFReadStreamRef CFReadStreamCreateWithBytesNoCopy(CFAllocatorRef _Nullable alloc, const UInt8 *bytes, CFIndex length,
                                                           CFAllocatorRef _Nullable bytesDeallocator);
CF_EXPORT CFWriteStreamRef CFWriteStreamCreateWithBuffer(CFAllocatorRef _Nullable alloc, UInt8 *buffer, CFIndex bufferCapacity);
CF_EXPORT CFWriteStreamRef CFWriteStreamCreateWithAllocatedBuffers(CFAllocatorRef _Nullable alloc, CFAllocatorRef _Nullable bufferAllocator);
CF_EXPORT CFReadStreamRef _Nullable CFReadStreamCreateWithFile(CFAllocatorRef _Nullable alloc, CFURLRef _Nullable fileURL);
CF_EXPORT CFWriteStreamRef _Nullable CFWriteStreamCreateWithFile(CFAllocatorRef _Nullable alloc, CFURLRef _Nullable fileURL);
CF_EXPORT void CFStreamCreateBoundPair(CFAllocatorRef _Nullable alloc, CFReadStreamRef _Nullable *_Nullable readStream,
                                       CFWriteStreamRef _Nullable *_Nullable writeStream, CFIndex transferBufferSize);

/* a file write stream appends (CFBoolean, set before opening) */
CF_EXPORT const CFStreamPropertyKey kCFStreamPropertyAppendToFile;
/* the position in a file stream (CFNumber) */
CF_EXPORT const CFStreamPropertyKey kCFStreamPropertyFileCurrentOffset;
/* a socket stream's socket: CFData holding a CFSocketNativeHandle */
CF_EXPORT const CFStreamPropertyKey kCFStreamPropertySocketNativeHandle;
/* a socket stream's host name (CFString) and port (CFNumber) */
CF_EXPORT const CFStreamPropertyKey kCFStreamPropertySocketRemoteHostName;
CF_EXPORT const CFStreamPropertyKey kCFStreamPropertySocketRemotePortNumber;

/* streams over a connected native socket (closed with the streams only when kCFStreamPropertyShouldCloseNativeSocket
   is true), to a host and port, or to the address of a signature */
CF_EXPORT void CFStreamCreatePairWithSocket(CFAllocatorRef _Nullable alloc, CFSocketNativeHandle sock,
                                            CFReadStreamRef _Nullable *_Nullable readStream, CFWriteStreamRef _Nullable *_Nullable writeStream);
CF_EXPORT void CFStreamCreatePairWithSocketToHost(CFAllocatorRef _Nullable alloc, CFStringRef host, UInt32 port,
                                                  CFReadStreamRef _Nullable *_Nullable readStream,
                                                  CFWriteStreamRef _Nullable *_Nullable writeStream);
CF_EXPORT void CFStreamCreatePairWithPeerSocketSignature(CFAllocatorRef _Nullable alloc, const CFSocketSignature *signature,
                                                         CFReadStreamRef _Nullable *_Nullable readStream,
                                                         CFWriteStreamRef _Nullable *_Nullable writeStream);

CF_EXPORT CFStreamStatus CFReadStreamGetStatus(CFReadStreamRef stream);
CF_EXPORT CFStreamStatus CFWriteStreamGetStatus(CFWriteStreamRef stream);
CF_EXPORT CFErrorRef _Nullable CFReadStreamCopyError(CFReadStreamRef _Nullable stream);
CF_EXPORT CFErrorRef _Nullable CFWriteStreamCopyError(CFWriteStreamRef _Nullable stream);

CF_EXPORT Boolean CFReadStreamOpen(CFReadStreamRef stream);
CF_EXPORT Boolean CFWriteStreamOpen(CFWriteStreamRef stream);
CF_EXPORT void CFReadStreamClose(CFReadStreamRef stream);
CF_EXPORT void CFWriteStreamClose(CFWriteStreamRef stream);

CF_EXPORT Boolean CFReadStreamHasBytesAvailable(CFReadStreamRef stream);
/* bytes read; 0 at the end; -1 on an error. Blocks until bytes arrive. */
CF_EXPORT CFIndex CFReadStreamRead(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength);
/* the stream's own buffer when it has one (data streams), else NULL */
CF_EXPORT const UInt8 *_Nullable CFReadStreamGetBuffer(CFReadStreamRef stream, CFIndex maxBytesToRead, CFIndex *numBytesRead);

CF_EXPORT Boolean CFWriteStreamCanAcceptBytes(CFWriteStreamRef stream);
CF_EXPORT CFIndex CFWriteStreamWrite(CFWriteStreamRef stream, const UInt8 *buffer, CFIndex bufferLength);

CF_EXPORT CFTypeRef _Nullable CFReadStreamCopyProperty(CFReadStreamRef _Nullable stream, CFStreamPropertyKey _Nullable propertyName);
CF_EXPORT CFTypeRef _Nullable CFWriteStreamCopyProperty(CFWriteStreamRef _Nullable stream, CFStreamPropertyKey _Nullable propertyName);
CF_EXPORT Boolean CFReadStreamSetProperty(CFReadStreamRef _Nullable stream, CFStreamPropertyKey _Nullable propertyName,
                                          CFTypeRef _Nullable propertyValue);
CF_EXPORT Boolean CFWriteStreamSetProperty(CFWriteStreamRef _Nullable stream, CFStreamPropertyKey _Nullable propertyName,
                                           CFTypeRef _Nullable propertyValue);

/* the client called for `streamEvents` (kCFStreamEventNone or a NULL callback removes it) */
CF_EXPORT Boolean CFReadStreamSetClient(CFReadStreamRef stream, CFOptionFlags streamEvents, CFReadStreamClientCallBack _Nullable clientCB,
                                        CFStreamClientContext *_Nullable clientContext);
CF_EXPORT Boolean CFWriteStreamSetClient(CFWriteStreamRef stream, CFOptionFlags streamEvents, CFWriteStreamClientCallBack _Nullable clientCB,
                                         CFStreamClientContext *_Nullable clientContext);
CF_EXPORT void CFReadStreamScheduleWithRunLoop(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);
CF_EXPORT void CFWriteStreamScheduleWithRunLoop(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);
CF_EXPORT void CFReadStreamUnscheduleFromRunLoop(CFReadStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);
CF_EXPORT void CFWriteStreamUnscheduleFromRunLoop(CFWriteStreamRef stream, CFRunLoopRef runLoop, CFRunLoopMode runLoopMode);
/* the client is called on `q` (NULL: not on a queue) */
CF_EXPORT void CFReadStreamSetDispatchQueue(CFReadStreamRef stream, dispatch_queue_t _Nullable q);
CF_EXPORT void CFWriteStreamSetDispatchQueue(CFWriteStreamRef stream, dispatch_queue_t _Nullable q);
CF_EXPORT dispatch_queue_t _Nullable CFReadStreamCopyDispatchQueue(CFReadStreamRef stream);
CF_EXPORT dispatch_queue_t _Nullable CFWriteStreamCopyDispatchQueue(CFWriteStreamRef stream);

typedef CF_ENUM(CFIndex, CFStreamErrorDomain) {
    kCFStreamErrorDomainCustom = -1L,
    kCFStreamErrorDomainPOSIX = 1,
    kCFStreamErrorDomainMacOSStatus
};
typedef struct {
    CFIndex domain;
    SInt32 error;
} CFStreamError;
CF_EXPORT CFStreamError CFReadStreamGetError(CFReadStreamRef stream);
CF_EXPORT CFStreamError CFWriteStreamGetError(CFWriteStreamRef stream);

_Pragma("clang assume_nonnull end")
CF_IMPLICIT_BRIDGING_DISABLED
__END_DECLS
