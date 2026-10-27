/* isim CoreFoundation (ARC): CFSocket (adapted). A socket is an Objective-C object (CFRetain / CFRelease work on it)
 * over a BSD socket of isim's libSystem (Darwin socket addresses). Read, accept and data readiness come from a dispatch
 * read source, write readiness and background connects from a write source, both on a private queue; a ready
 * callback type is disabled until it has been delivered, then re-enabled when the socket's flags say so. Callbacks run
 * when a run loop the socket's run loop source is added to performs the source (CFSocketCreateRunLoopSource).
 * Self-authored. */
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

const CFStringRef kCFSocketCommandKey = CFSTR("Command"), kCFSocketNameKey = CFSTR("Name"), kCFSocketValueKey = CFSTR("Value"),
    kCFSocketResultKey = CFSTR("Result"), kCFSocketErrorKey = CFSTR("Error"), kCFSocketRegisterCommand = CFSTR("Register"),
    kCFSocketRetrieveCommand = CFSTR("Retrieve");

enum { ISIM_CF_SOCKET = 0x5e42 };
enum { CB_READ_KIND = 3 };                       /* the read, accept and data types share the low bits */

@interface __IsimCFSocket : NSObject {
@public
    int fd;
    BOOL valid, connecting, readSuspended, writeSuspended;
    CFOptionFlags types;                         /* the callback types asked for */
    CFOptionFlags enabled;                       /* those that may fire now */
    CFOptionFlags pending;                       /* ready, not delivered yet */
    CFOptionFlags flags;                         /* CFSocketSetSocketFlags */
    SInt32 connectError;
    CFSocketCallBack callout;
    CFSocketContext context;
    dispatch_queue_t queue;
    dispatch_source_t readSource, writeSource;
    CFRunLoopSourceRef rlSource;                 /* (not retained: it retains the socket) */
    NSMutableArray<NSArray *> *loops;           /* (run loop, mode) the source is in */
    NSMutableArray *dataQueue;                   /* data callbacks: (bytes read, sender address), not delivered */
    NSMutableArray *acceptQueue;                 /* accept callbacks: (handle, address) */
}
@end
@implementation __IsimCFSocket
- (CFTypeID)_isimCFTypeID { return ISIM_CF_SOCKET; }
- (void)dealloc {
    if (context.release && context.info) context.release(context.info);
    if (!valid) return;
    if (readSuspended) dispatch_resume(readSource);              /* (a suspended source must not be released) */
    if (writeSuspended) dispatch_resume(writeSource);
    dispatch_source_cancel(readSource); dispatch_source_cancel(writeSource);
    if (fd >= 0 && (flags & kCFSocketCloseOnInvalidate)) close(fd);
}
- (NSString *)description { return [NSString stringWithFormat:@"<CFSocket %p [fd %d]>", self, fd]; }
@end

CFTypeID CFSocketGetTypeID(void) { return ISIM_CF_SOCKET; }
static __IsimCFSocket *S(CFSocketRef s) { return (__bridge __IsimCFSocket *)s; }

static void sock_wake(__IsimCFSocket *s) {
    CFRunLoopSourceRef src; NSArray *loops;
    @synchronized (s) { src = s->rlSource; loops = [s->loops copy]; }
    if (!src) return;
    CFRunLoopSourceSignal(src);
    for (NSArray *l in loops) CFRunLoopWakeUp((__bridge CFRunLoopRef)l[0]);
}
/* the sources run while a type that needs them is enabled and nothing of theirs waits for delivery */
static void sock_update(__IsimCFSocket *s) {
    if (!s->valid) return;
    BOOL wantRead = (s->enabled & CB_READ_KIND) && (s->types & CB_READ_KIND) && !(s->pending & CB_READ_KIND);
    BOOL wantWrite = ((s->enabled & kCFSocketWriteCallBack) && (s->types & kCFSocketWriteCallBack) && !(s->pending & kCFSocketWriteCallBack)) ||
                     (s->connecting && !(s->pending & kCFSocketConnectCallBack));
    if (s->readSource && wantRead == s->readSuspended) {
        if (wantRead) dispatch_resume(s->readSource); else dispatch_suspend(s->readSource);
        s->readSuspended = !wantRead;
    }
    if (s->writeSource && wantWrite == s->writeSuspended) {
        if (wantWrite) dispatch_resume(s->writeSource); else dispatch_suspend(s->writeSource);
        s->writeSuspended = !wantWrite;
    }
}
static NSData *peer_of(int fd) {
    struct sockaddr_storage ss; socklen_t n = sizeof ss;
    if (getpeername(fd, (struct sockaddr *)&ss, &n) != 0) return nil;
    return [NSData dataWithBytes:&ss length:n];
}
/* on the socket's queue: the socket is readable (the socket I/O runs outside the lock and never blocks: a readiness
   event can be stale) */
static void sock_readable(__IsimCFSocket *s) {
    CFOptionFlags kind;
    int fd;
    @synchronized (s) { if (!s->valid) return; kind = s->types & CB_READ_KIND; fd = s->fd; }
    struct pollfd p = { .fd = fd, .events = POLLIN };
    BOOL ready = poll(&p, 1, 0) > 0;
    id item = nil;
    if (ready && kind == kCFSocketAcceptCallBack) {
        struct sockaddr_storage ss; socklen_t n = sizeof ss;
        int c = accept(fd, (struct sockaddr *)&ss, &n);
        if (c >= 0) item = @[@(c), [NSData dataWithBytes:&ss length:n]];
    } else if (ready && kind == kCFSocketDataCallBack) {
        uint8_t buf[65536];
        struct sockaddr_storage from; socklen_t fl = sizeof from;
        ssize_t n = recvfrom(fd, buf, sizeof buf, MSG_DONTWAIT, (struct sockaddr *)&from, &fl);
        if (n >= 0 || (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)) {
            NSData *peer = n >= 0 && fl > 0 && fl <= sizeof from ? [NSData dataWithBytes:&from length:fl] : peer_of(fd);
            item = @[n > 0 ? [NSData dataWithBytes:buf length:(NSUInteger)n] : [NSData data], peer ?: [NSNull null]];
        }
    }
    BOOL wake = NO;
    @synchronized (s) {
        if (!s->valid) { if (item && kind == kCFSocketAcceptCallBack) close([item[0] intValue]); return; }
        if (item && kind == kCFSocketAcceptCallBack) { [s->acceptQueue addObject:item]; s->pending |= kCFSocketAcceptCallBack; wake = YES; }
        else if (item && kind == kCFSocketDataCallBack) { [s->dataQueue addObject:item]; s->pending |= kCFSocketDataCallBack; wake = YES; }
        else if (ready && kind == kCFSocketReadCallBack) { s->pending |= kCFSocketReadCallBack; wake = YES; }
        sock_update(s);
    }
    if (wake) sock_wake(s);
}
static void sock_writable(__IsimCFSocket *s) {
    BOOL wake = NO;
    @synchronized (s) {
        if (!s->valid) return;
        if (s->connecting) {
            int err = 0; socklen_t n = sizeof err;
            getsockopt(s->fd, SOL_SOCKET, SO_ERROR, &err, &n);
            s->connecting = NO; s->connectError = err;
            if (s->types & kCFSocketConnectCallBack) { s->pending |= kCFSocketConnectCallBack; wake = YES; }
            if (!err) fcntl(s->fd, F_SETFL, fcntl(s->fd, F_GETFL) & ~O_NONBLOCK);
        } else if ((s->enabled & kCFSocketWriteCallBack) && (s->types & kCFSocketWriteCallBack)) {
            s->pending |= kCFSocketWriteCallBack; wake = YES;
        }
        sock_update(s);
    }
    if (wake) sock_wake(s);
}

static CFSocketRef sock_make(int fd, CFOptionFlags types, CFSocketCallBack callout, const CFSocketContext *ctx) {
    if (fd < 0) return NULL;
    __IsimCFSocket *s = [__IsimCFSocket new];
    s->fd = fd; s->valid = YES; s->types = types; s->enabled = types; s->callout = callout;
    s->flags = kCFSocketAutomaticallyReenableReadCallBack | kCFSocketAutomaticallyReenableAcceptCallBack |
               kCFSocketAutomaticallyReenableDataCallBack | kCFSocketCloseOnInvalidate;
    if (ctx) { s->context = *ctx; if (ctx->retain && ctx->info) s->context.info = (void *)ctx->retain(ctx->info); }
    s->loops = [NSMutableArray array]; s->dataQueue = [NSMutableArray array]; s->acceptQueue = [NSMutableArray array];
    s->queue = dispatch_queue_create("com.apple.CFSocket", DISPATCH_QUEUE_SERIAL);
    __weak __IsimCFSocket *weak = s;
    s->readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)fd, 0, s->queue);
    dispatch_source_set_event_handler(s->readSource, ^{ __IsimCFSocket *me = weak; if (me) sock_readable(me); });
    s->writeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, (uintptr_t)fd, 0, s->queue);
    dispatch_source_set_event_handler(s->writeSource, ^{ __IsimCFSocket *me = weak; if (me) sock_writable(me); });
    s->readSuspended = s->writeSuspended = YES;          /* (created suspended; resumed while scheduled) */
    return (CFSocketRef)CFBridgingRetain(s);
}

CFSocketRef CFSocketCreate(CFAllocatorRef allocator, SInt32 family, SInt32 type, SInt32 protocol, CFOptionFlags types,
                           CFSocketCallBack callout, const CFSocketContext *context) {
    if (family <= 0) family = PF_INET;
    if (type <= 0) type = SOCK_STREAM;
    if (protocol <= 0 && family != PF_UNIX && family != PF_LOCAL) protocol = type == SOCK_DGRAM ? IPPROTO_UDP : IPPROTO_TCP;
    int fd = socket(family, type, family == PF_UNIX ? 0 : protocol);
    if (fd >= 0 && family != PF_UNIX) { int one = 1; setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one); }
    return sock_make(fd, types, callout, context);
}
CFSocketRef CFSocketCreateWithNative(CFAllocatorRef allocator, CFSocketNativeHandle sock, CFOptionFlags types, CFSocketCallBack callout,
                                     const CFSocketContext *context) {
    return sock_make(sock, types, callout, context);
}
CFSocketRef CFSocketCreateWithSocketSignature(CFAllocatorRef allocator, const CFSocketSignature *sig, CFOptionFlags types,
                                              CFSocketCallBack callout, const CFSocketContext *context) {
    CFSocketRef s = CFSocketCreate(allocator, sig->protocolFamily, sig->socketType, sig->protocol, types, callout, context);
    if (s && sig->address && CFSocketSetAddress(s, sig->address) != kCFSocketSuccess) { CFSocketInvalidate(s); CFRelease(s); return NULL; }
    return s;
}
CFSocketRef CFSocketCreateConnectedToSocketSignature(CFAllocatorRef allocator, const CFSocketSignature *sig, CFOptionFlags types,
                                                     CFSocketCallBack callout, const CFSocketContext *context, CFTimeInterval timeout) {
    CFSocketRef s = CFSocketCreate(allocator, sig->protocolFamily, sig->socketType, sig->protocol, types, callout, context);
    if (s && sig->address && CFSocketConnectToAddress(s, sig->address, timeout) != kCFSocketSuccess) { CFSocketInvalidate(s); CFRelease(s); return NULL; }
    return s;
}

/* binds the socket to `address`, and listens when it is a stream socket */
CFSocketError CFSocketSetAddress(CFSocketRef ref, CFDataRef address) {
    __IsimCFSocket *s = S(ref);
    NSData *a = (__bridge NSData *)address;
    if (!s->valid || a.length < 2) return kCFSocketError;
    if (bind(s->fd, a.bytes, (socklen_t)a.length) != 0) return kCFSocketError;
    int type = 0; socklen_t n = sizeof type;
    getsockopt(s->fd, SOL_SOCKET, SO_TYPE, &type, &n);
    if (type == SOCK_STREAM && listen(s->fd, 256) != 0) return kCFSocketError;
    return kCFSocketSuccess;
}
/* connects to `address`: waiting up to `timeout` seconds (0: forever), or in the background for a negative timeout
   (the connect callback reports how it went) */
CFSocketError CFSocketConnectToAddress(CFSocketRef ref, CFDataRef address, CFTimeInterval timeout) {
    __IsimCFSocket *s = S(ref);
    NSData *a = (__bridge NSData *)address;
    if (!s->valid || a.length < 2) return kCFSocketError;
    int fl = fcntl(s->fd, F_GETFL);
    BOOL nonblocking = timeout != 0;
    if (nonblocking) fcntl(s->fd, F_SETFL, fl | O_NONBLOCK);
    int rc = connect(s->fd, a.bytes, (socklen_t)a.length);
    int err = rc == 0 ? 0 : errno;
    if (rc != 0 && err != EINPROGRESS) { fcntl(s->fd, F_SETFL, fl); return kCFSocketError; }
    if (rc != 0 && timeout < 0) {
        @synchronized (s) { s->connecting = YES; sock_update(s); }
        return kCFSocketSuccess;
    }
    if (rc != 0) {
        struct pollfd p = { .fd = s->fd, .events = POLLOUT };
        int pr = poll(&p, 1, (int)(timeout * 1000));
        if (pr == 0) { fcntl(s->fd, F_SETFL, fl); return kCFSocketTimeout; }
        socklen_t n = sizeof err;
        getsockopt(s->fd, SOL_SOCKET, SO_ERROR, &err, &n);
    }
    fcntl(s->fd, F_SETFL, fl);
    if (err) return kCFSocketError;
    if (s->types & kCFSocketConnectCallBack) {
        @synchronized (s) { s->pending |= kCFSocketConnectCallBack; s->connectError = 0; }
        sock_wake(s);
    }
    return kCFSocketSuccess;
}

void CFSocketInvalidate(CFSocketRef ref) {
    __IsimCFSocket *s = S(ref);
    CFRunLoopSourceRef src;
    CFSocketContext ctx;
    @synchronized (s) {
        if (!s->valid) return;
        s->valid = NO;
        if (s->readSuspended) dispatch_resume(s->readSource);
        if (s->writeSuspended) dispatch_resume(s->writeSource);
        dispatch_source_cancel(s->readSource); dispatch_source_cancel(s->writeSource);
        if (s->flags & kCFSocketCloseOnInvalidate) close(s->fd);
        for (NSArray *a in s->acceptQueue) close([a[0] intValue]);
        [s->acceptQueue removeAllObjects]; [s->dataQueue removeAllObjects];
        src = s->rlSource; s->rlSource = NULL;
        ctx = s->context; memset(&s->context, 0, sizeof s->context);
    }
    if (src) CFRunLoopSourceInvalidate(src);
    if (ctx.release && ctx.info) ctx.release(ctx.info);
}
Boolean CFSocketIsValid(CFSocketRef s) { return S(s)->valid; }
CFDataRef CFSocketCopyAddress(CFSocketRef ref) {
    struct sockaddr_storage ss; socklen_t n = sizeof ss;
    if (!S(ref)->valid || getsockname(S(ref)->fd, (struct sockaddr *)&ss, &n) != 0) return NULL;
    return (CFDataRef)CFBridgingRetain([NSData dataWithBytes:&ss length:n]);
}
CFDataRef CFSocketCopyPeerAddress(CFSocketRef ref) {
    NSData *d = S(ref)->valid ? peer_of(S(ref)->fd) : nil;
    return d ? (CFDataRef)CFBridgingRetain(d) : NULL;
}
void CFSocketGetContext(CFSocketRef ref, CFSocketContext *context) { if (context) *context = S(ref)->context; }
CFSocketNativeHandle CFSocketGetNative(CFSocketRef ref) { return S(ref)->fd; }
CFOptionFlags CFSocketGetSocketFlags(CFSocketRef ref) { return S(ref)->flags; }
void CFSocketSetSocketFlags(CFSocketRef ref, CFOptionFlags flags) { @synchronized (S(ref)) { S(ref)->flags = flags; } }
void CFSocketDisableCallBacks(CFSocketRef ref, CFOptionFlags types) {
    __IsimCFSocket *s = S(ref);
    @synchronized (s) { s->enabled &= ~types; sock_update(s); }
}
void CFSocketEnableCallBacks(CFSocketRef ref, CFOptionFlags types) {
    __IsimCFSocket *s = S(ref);
    @synchronized (s) { s->enabled |= types & s->types; if (s->rlSource) sock_update(s); }
}
CFSocketError CFSocketSendData(CFSocketRef ref, CFDataRef address, CFDataRef data, CFTimeInterval timeout) {
    __IsimCFSocket *s = S(ref);
    NSData *a = (__bridge NSData *)address, *d = (__bridge NSData *)data;
    if (!s->valid || !d) return kCFSocketError;
    if (timeout > 0) {
        struct timeval tv = { (time_t)timeout, (int)((timeout - (time_t)timeout) * 1e6) };
        setsockopt(s->fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);
    }
    ssize_t n = a.length ? sendto(s->fd, d.bytes, d.length, 0, a.bytes, (socklen_t)a.length) : send(s->fd, d.bytes, d.length, 0);
    if (n < 0) return errno == EAGAIN || errno == EWOULDBLOCK ? kCFSocketTimeout : kCFSocketError;
    return (NSUInteger)n == d.length ? kCFSocketSuccess : kCFSocketError;
}

/* ---- the run loop source ---- */
static void src_schedule(void *info, CFRunLoopRef rl, CFRunLoopMode mode) {
    __IsimCFSocket *s = (__bridge __IsimCFSocket *)info;
    BOOL wake;
    @synchronized (s) {
        [s->loops addObject:@[(__bridge NSRunLoop *)rl, (__bridge NSString *)mode]];
        sock_update(s);
        wake = s->pending != 0;
    }
    if (wake) sock_wake(s);
}
static void src_cancel(void *info, CFRunLoopRef rl, CFRunLoopMode mode) {
    __IsimCFSocket *s = (__bridge __IsimCFSocket *)info;
    @synchronized (s) {
        for (NSUInteger i = 0; i < s->loops.count; i++)
            if (s->loops[i][0] == (__bridge NSRunLoop *)rl && [s->loops[i][1] isEqualToString:(__bridge NSString *)mode]) { [s->loops removeObjectAtIndex:i]; break; }
    }
}
/* delivers what is ready, in Apple's order (connect, then read / accept / data, then write) */
static void src_perform(void *info) {
    __IsimCFSocket *s = (__bridge __IsimCFSocket *)info;
    CFSocketRef ref = (__bridge CFSocketRef)s;
    for (;;) {
        CFOptionFlags type = 0; NSData *address = nil; id payload = nil; SInt32 err = 0;
        @synchronized (s) {
            if (!s->valid) return;
            if (s->pending & kCFSocketConnectCallBack) {
                type = kCFSocketConnectCallBack; err = s->connectError; s->pending &= ~kCFSocketConnectCallBack;
                s->types &= ~kCFSocketConnectCallBack; s->enabled &= ~kCFSocketConnectCallBack;     /* (once) */
            } else if (s->pending & CB_READ_KIND) {
                type = s->pending & CB_READ_KIND;
                if (type == kCFSocketAcceptCallBack && s->acceptQueue.count) {
                    payload = s->acceptQueue[0][0]; address = s->acceptQueue[0][1]; [s->acceptQueue removeObjectAtIndex:0];
                } else if (type == kCFSocketDataCallBack && s->dataQueue.count) {
                    payload = s->dataQueue[0][0]; id from = s->dataQueue[0][1]; [s->dataQueue removeObjectAtIndex:0];
                    address = from == [NSNull null] ? nil : from;
                }
                BOOL more = (type == kCFSocketAcceptCallBack && s->acceptQueue.count) || (type == kCFSocketDataCallBack && s->dataQueue.count);
                if (!more) {
                    s->pending &= ~CB_READ_KIND;
                    BOOL eof = type == kCFSocketDataCallBack && [payload length] == 0;
                    if (!(s->flags & type) || eof) s->enabled &= ~type;              /* not automatically re-enabled */
                }
            } else if (s->pending & kCFSocketWriteCallBack) {
                type = kCFSocketWriteCallBack; s->pending &= ~kCFSocketWriteCallBack;
                if (!(s->flags & kCFSocketAutomaticallyReenableWriteCallBack)) s->enabled &= ~kCFSocketWriteCallBack;
            }
            if (!type) { sock_update(s); return; }
        }
        CFSocketCallBack cb = s->callout;
        if (cb) {
            if (type == kCFSocketConnectCallBack) cb(ref, type, NULL, err ? &err : NULL, s->context.info);
            else if (type == kCFSocketAcceptCallBack) {
                CFSocketNativeHandle h = [payload intValue];
                if (payload) cb(ref, type, (__bridge CFDataRef)address, &h, s->context.info);
            } else if (type == kCFSocketDataCallBack) { if (payload) cb(ref, type, (__bridge CFDataRef)address, (__bridge const void *)payload, s->context.info); }
            else cb(ref, type, NULL, NULL, s->context.info);
        } else if (type == kCFSocketAcceptCallBack && payload) close([payload intValue]);
        @synchronized (s) { if (s->valid) sock_update(s); }
    }
}
static const void *src_retain(const void *info) { return CFRetain(info); }
static void src_release(const void *info) { CFRelease(info); }

CFRunLoopSourceRef CFSocketCreateRunLoopSource(CFAllocatorRef allocator, CFSocketRef ref, CFIndex order) {
    __IsimCFSocket *s = S(ref);
    @synchronized (s) {
        if (!s->valid) return NULL;
        if (s->rlSource) return (CFRunLoopSourceRef)CFRetain(s->rlSource);
    }
    CFRunLoopSourceContext ctx = { 0, (void *)ref, src_retain, src_release, NULL, NULL, NULL, src_schedule, src_cancel, src_perform };
    CFRunLoopSourceRef src = CFRunLoopSourceCreate(allocator, order, &ctx);
    @synchronized (s) { s->rlSource = src; }
    return src;
}

/* ---- the name registry (stub: there is no name server) ---- */
static UInt16 registryPort = 2454;
CFSocketError CFSocketRegisterValue(const CFSocketSignature *ns, CFTimeInterval timeout, CFStringRef name, CFPropertyListRef value) { return kCFSocketError; }
CFSocketError CFSocketCopyRegisteredValue(const CFSocketSignature *ns, CFTimeInterval timeout, CFStringRef name, CFPropertyListRef *value,
                                          CFDataRef *nameServerAddress) {
    if (value) *value = NULL;
    if (nameServerAddress) *nameServerAddress = NULL;
    return kCFSocketError;
}
CFSocketError CFSocketRegisterSocketSignature(const CFSocketSignature *ns, CFTimeInterval timeout, CFStringRef name, const CFSocketSignature *sig) {
    return kCFSocketError;
}
CFSocketError CFSocketCopyRegisteredSocketSignature(const CFSocketSignature *ns, CFTimeInterval timeout, CFStringRef name,
                                                    CFSocketSignature *sig, CFDataRef *nameServerAddress) {
    if (nameServerAddress) *nameServerAddress = NULL;
    return kCFSocketError;
}
CFSocketError CFSocketUnregister(const CFSocketSignature *ns, CFTimeInterval timeout, CFStringRef name) { return kCFSocketError; }
void CFSocketSetDefaultNameRegistryPortNumber(UInt16 port) { registryPort = port; }
UInt16 CFSocketGetDefaultNameRegistryPortNumber(void) { return registryPort; }
