/* isim Foundation (ARC): NSStream, NSInputStream, NSOutputStream (data, file, memory, buffer), socket streams to a
 * host (+getStreamsToHostWithName:port:inputStream:outputStream:, TCP, TLS through the host's OpenSSL with
 * NSStreamSocketSecurityLevelKey / kCFStreamPropertySSLSettings) and bound stream pairs
 * (+getBoundStreamsWithBufferSize:inputStream:outputStream:). Self-authored.
 * Events go to the delegate on every run loop and mode the stream is scheduled in (none when unscheduled: the
 * stream is then polled, like iOS); a pending event is not posted twice before it is delivered. Reads of socket and
 * bound streams block until bytes arrive (check hasBytesAvailable first, as on iOS). */
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <poll.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
#include <isim_host.h>
#include "isim_foundation.h"

NSStreamPropertyKey const NSStreamDataWrittenToMemoryStreamKey = @"kCFStreamPropertyDataWritten", NSStreamFileCurrentOffsetKey = @"kCFStreamPropertyFileCurrentOffset",
    NSStreamSocketSecurityLevelKey = @"kCFStreamPropertySocketSecurityLevel", NSStreamSOCKSProxyConfigurationKey = @"kCFStreamPropertySOCKSProxy",
    NSStreamNetworkServiceType = @"kCFStreamNetworkServiceType";
NSStreamSocketSecurityLevel const NSStreamSocketSecurityLevelNone = @"kCFStreamSocketSecurityLevelNone",
    NSStreamSocketSecurityLevelSSLv2 = @"kCFStreamSocketSecurityLevelSSLv2", NSStreamSocketSecurityLevelSSLv3 = @"kCFStreamSocketSecurityLevelSSLv3",
    NSStreamSocketSecurityLevelTLSv1 = @"kCFStreamSocketSecurityLevelTLSv1", NSStreamSocketSecurityLevelNegotiatedSSL = @"kCFStreamSocketSecurityLevelNegotiatedSSL";
NSStreamNetworkServiceTypeValue const NSStreamNetworkServiceTypeVoIP = @"kCFStreamNetworkServiceTypeVoIP",
    NSStreamNetworkServiceTypeVideo = @"kCFStreamNetworkServiceTypeVideo", NSStreamNetworkServiceTypeBackground = @"kCFStreamNetworkServiceTypeBackground",
    NSStreamNetworkServiceTypeVoice = @"kCFStreamNetworkServiceTypeVoice", NSStreamNetworkServiceTypeCallSignaling = @"kCFStreamNetworkServiceTypeCallSignaling";
NSErrorDomain const NSStreamSocketSSLErrorDomain = @"NSStreamSocketSSLErrorDomain", NSStreamSOCKSErrorDomain = @"NSStreamSOCKSErrorDomain";
/* CFStream SSL settings (kCFStreamPropertySSLSettings and its keys, as their string values) */
static NSString *const kSSLSettings = @"kCFStreamPropertySSLSettings", *const kSSLValidatesChain = @"kCFStreamSSLValidatesCertificateChain",
    *const kSSLPeerName = @"kCFStreamSSLPeerName", *const kSSLLevel = @"kCFStreamSSLLevel", *const kNativeHandle = @"kCFStreamPropertySocketNativeHandle",
    *const kRemoteHostName = @"kCFStreamPropertySocketRemoteHostName", *const kRemotePort = @"kCFStreamPropertySocketRemotePortNumber",
    *const kShouldCloseNative = @"kCFStreamPropertyShouldCloseNativeSocket";

static NSError *posix_error(int err, NSString *path) {
    NSInteger code = err == ENOENT ? 4 : err == EACCES || err == EPERM ? 513 : err == EEXIST ? 516 : err == ENOSPC ? 640 : 512;
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:[NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil] forKey:NSUnderlyingErrorKey];
    if (path) info[@"NSFilePath"] = path;
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:info];
}

/* ================= NSStream ================= */
@implementation NSStream {
    __weak id<NSStreamDelegate> _streamDelegate;
    NSMutableArray<NSArray *> *_schedules;            /* @[run loop, mode] */
    NSUInteger _pending;                              /* events posted, not delivered yet */
@package
    NSMutableDictionary *_properties;
    /* a CoreFoundation client (CFReadStreamSetClient): called instead of the delegate, on the run loops or the queue */
    CFOptionFlags _cfEvents;
    void (*_cfCallback)(id stream, CFStreamEventType type, void *info);
    CFStreamClientContext _cfContext;
    dispatch_queue_t _cfQueue;
}
- (void)dealloc { if (_cfContext.release && _cfContext.info) _cfContext.release(_cfContext.info); }
- (id<NSStreamDelegate>)delegate { return _streamDelegate ?: (id<NSStreamDelegate>)self; }
- (void)setDelegate:(id<NSStreamDelegate>)d { _streamDelegate = d; }
- (void)open {}
- (void)close {}
- (id)propertyForKey:(NSStreamPropertyKey)key { @synchronized (self) { return _properties[key]; } }
- (BOOL)setProperty:(id)property forKey:(NSStreamPropertyKey)key {
    @synchronized (self) { if (!_properties) _properties = [NSMutableDictionary dictionary]; _properties[key] = property; }
    return YES;
}
- (void)scheduleInRunLoop:(NSRunLoop *)rl forMode:(NSRunLoopMode)mode {
    if (!rl || !mode) return;
    BOOL first;
    @synchronized (self) {
        if (!_schedules) _schedules = [NSMutableArray array];
        for (NSArray *s in _schedules) if (s[0] == rl && [s[1] isEqualToString:mode]) return;
        first = !_schedules.count;
        [_schedules addObject:@[rl, mode]];
    }
    if (first) [self _isim_scheduled];
}
- (void)removeFromRunLoop:(NSRunLoop *)rl forMode:(NSRunLoopMode)mode {
    @synchronized (self) {
        for (NSUInteger i = 0; i < _schedules.count; i++) if (_schedules[i][0] == rl && [_schedules[i][1] isEqualToString:mode]) { [_schedules removeObjectAtIndex:i]; break; }
    }
}
/* a stream first scheduled after it opened learns its state */
- (void)_isim_scheduled {}
- (NSStreamStatus)streamStatus { return NSStreamStatusNotOpen; }
- (NSError *)streamError { return nil; }
/* one event to the CF client (when it asked for it) or the delegate */
- (void)_isim_deliver:(NSStreamEvent)event {
    if (self.streamStatus == NSStreamStatusClosed) return;
    void (*cb)(id, CFStreamEventType, void *); CFOptionFlags events; void *info;
    @synchronized (self) { cb = _cfCallback; events = _cfEvents; info = _cfContext.info; }
    if (cb) { if (events & event) cb(self, (CFStreamEventType)event, info); return; }
    id<NSStreamDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(stream:handleEvent:)]) [d stream:self handleEvent:event];
}
- (void)_isim_post:(NSStreamEvent)event {
    NSArray *schedules;
    dispatch_queue_t queue;
    @synchronized (self) {
        queue = _cfCallback ? _cfQueue : nil;
        if ((!_schedules.count && !queue) || (_pending & event)) return;
        _pending |= event;
        schedules = [_schedules copy];
    }
    if (queue) {
        dispatch_async(queue, ^{
            @synchronized (self) { self->_pending &= ~event; }
            [self _isim_deliver:event];
        });
        return;
    }
    NSMapTable *byLoop = [NSMapTable strongToStrongObjectsMapTable];
    for (NSArray *s in schedules) {
        NSMutableArray *modes = [byLoop objectForKey:s[0]];
        if (!modes) { modes = [NSMutableArray array]; [byLoop setObject:modes forKey:s[0]]; }
        [modes addObject:s[1]];
    }
    __block BOOL delivered = NO;
    for (NSRunLoop *rl in byLoop) {
        [rl performInModes:[byLoop objectForKey:rl] block:^{
            @synchronized (self) { if (delivered) return; delivered = YES; self->_pending &= ~event; }
            [self _isim_deliver:event];
        }];
    }
}
@end

/* ================= data and file input streams ================= */
@implementation NSInputStream { NSData *_data; NSUInteger _pos; int _fd; NSString *_path; NSStreamStatus _status; NSError *_error; BOOL _eof; }
+ (instancetype)inputStreamWithData:(NSData *)data { return [[self alloc] initWithData:data]; }
+ (instancetype)inputStreamWithFileAtPath:(NSString *)path { return [[self alloc] initWithFileAtPath:path]; }
+ (instancetype)inputStreamWithURL:(NSURL *)url { return [[self alloc] initWithURL:url]; }
- (instancetype)init { if ((self = [super init])) _fd = -1; return self; }
- (instancetype)initWithData:(NSData *)data { if ((self = [super init])) { _data = [data copy]; _fd = -1; } return self; }
- (instancetype)initWithFileAtPath:(NSString *)path { if ((self = [super init])) { _path = [path copy]; _fd = -1; } return self; }
- (instancetype)initWithURL:(NSURL *)url { return url.isFileURL ? [self initWithFileAtPath:url.path] : nil; }
- (void)dealloc { if (_fd >= 0) close(_fd); }
- (NSStreamStatus)streamStatus { return _status; }
- (NSError *)streamError { return _error; }
- (void)_isim_scheduled {
    if (_status == NSStreamStatusOpen) [self _isim_post:self.hasBytesAvailable ? NSStreamEventHasBytesAvailable : NSStreamEventEndEncountered];
}
- (void)open {
    if (_status != NSStreamStatusNotOpen) return;
    if (_path) {
        _fd = open(_path.UTF8String, O_RDONLY);
        if (_fd < 0) { _error = posix_error(errno, _path); _status = NSStreamStatusError; [self _isim_post:NSStreamEventErrorOccurred]; return; }
    }
    _status = NSStreamStatusOpen;
    [self _isim_post:NSStreamEventOpenCompleted];
    [self _isim_post:self.hasBytesAvailable ? NSStreamEventHasBytesAvailable : NSStreamEventEndEncountered];
}
- (void)close { if (_fd >= 0) close(_fd); _fd = -1; _status = NSStreamStatusClosed; }
- (BOOL)hasBytesAvailable { return _status == NSStreamStatusOpen && (_data ? _pos < _data.length : !_eof); }
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if (_status != NSStreamStatusOpen && _status != NSStreamStatusAtEnd) return -1;
    NSInteger n;
    if (_data) {
        n = (NSInteger)MIN(len, _data.length - _pos);
        memcpy(buffer, (const char *)_data.bytes + _pos, (size_t)n); _pos += (NSUInteger)n;
        if (_pos >= _data.length) _eof = YES;
    } else {
        ssize_t r = read(_fd, buffer, len);
        if (r < 0) { _error = posix_error(errno, _path); _status = NSStreamStatusError; [self _isim_post:NSStreamEventErrorOccurred]; return -1; }
        n = r; if (r == 0) _eof = YES;
    }
    if (_eof && (n == 0 || _data)) _status = NSStreamStatusAtEnd;
    [self _isim_post:_eof ? NSStreamEventEndEncountered : NSStreamEventHasBytesAvailable];
    return n;
}
- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
    if (!_data || _status != NSStreamStatusOpen) return NO;
    *buffer = (uint8_t *)_data.bytes + _pos; *len = _data.length - _pos;
    return YES;
}
- (id)propertyForKey:(NSStreamPropertyKey)key {
    if ([key isEqualToString:NSStreamFileCurrentOffsetKey]) return _data ? @(_pos) : @((unsigned long long)lseek(_fd, 0, SEEK_CUR));
    return [super propertyForKey:key];
}
- (BOOL)setProperty:(id)property forKey:(NSStreamPropertyKey)key {
    if ([key isEqualToString:NSStreamFileCurrentOffsetKey]) {
        unsigned long long o = [property unsignedLongLongValue];
        if (_data) { _pos = (NSUInteger)MIN(o, (unsigned long long)_data.length); _eof = _pos >= _data.length; return YES; }
        if (_fd >= 0) { _eof = NO; return lseek(_fd, (off_t)o, SEEK_SET) >= 0; }
        return NO;
    }
    return [super setProperty:property forKey:key];
}
@end

/* ================= memory, buffer and file output streams ================= */
@implementation NSOutputStream { NSMutableData *_mem; int _fd; NSString *_path; BOOL _append; NSStreamStatus _status; NSError *_error; uint8_t *_buf; NSUInteger _cap, _len; }
+ (instancetype)outputStreamToMemory { return [[self alloc] initToMemory]; }
+ (instancetype)outputStreamToFileAtPath:(NSString *)path append:(BOOL)a { return [[self alloc] initToFileAtPath:path append:a]; }
+ (instancetype)outputStreamWithURL:(NSURL *)url append:(BOOL)a { return [[self alloc] initWithURL:url append:a]; }
+ (instancetype)outputStreamToBuffer:(uint8_t *)buffer capacity:(NSUInteger)capacity { return [[self alloc] initToBuffer:buffer capacity:capacity]; }
- (instancetype)init { if ((self = [super init])) _fd = -1; return self; }
- (instancetype)initToMemory { if ((self = [super init])) { _mem = [NSMutableData data]; _fd = -1; } return self; }
- (instancetype)initToBuffer:(uint8_t *)buffer capacity:(NSUInteger)capacity { if ((self = [super init])) { _buf = buffer; _cap = capacity; _fd = -1; } return self; }
- (instancetype)initToFileAtPath:(NSString *)path append:(BOOL)a { if ((self = [super init])) { _path = [path copy]; _append = a; _fd = -1; } return self; }
- (instancetype)initWithURL:(NSURL *)url append:(BOOL)a { return url.isFileURL ? [self initToFileAtPath:url.path append:a] : nil; }
- (void)dealloc { if (_fd >= 0) close(_fd); }
- (NSStreamStatus)streamStatus { return _status; }
- (NSError *)streamError { return _error; }
- (void)_isim_scheduled { if (_status == NSStreamStatusOpen) [self _isim_post:NSStreamEventHasSpaceAvailable]; }
- (void)open {
    if (_status != NSStreamStatusNotOpen) return;
    if (_path) {
        _fd = open(_path.UTF8String, O_WRONLY | O_CREAT | (_append ? O_APPEND : O_TRUNC), 0644);
        if (_fd < 0) { _error = posix_error(errno, _path); _status = NSStreamStatusError; [self _isim_post:NSStreamEventErrorOccurred]; return; }
    }
    _status = NSStreamStatusOpen;
    [self _isim_post:NSStreamEventOpenCompleted]; [self _isim_post:NSStreamEventHasSpaceAvailable];
}
- (void)close { if (_fd >= 0) close(_fd); _fd = -1; _status = NSStreamStatusClosed; }
- (BOOL)hasSpaceAvailable { return _status == NSStreamStatusOpen && (!_buf || _len < _cap); }
- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    if (_status != NSStreamStatusOpen) return -1;
    NSInteger n = (NSInteger)len;
    if (_mem) [_mem appendBytes:buffer length:len];
    else if (_buf) { n = (NSInteger)MIN(len, _cap - _len); memcpy(_buf + _len, buffer, (size_t)n); _len += (NSUInteger)n; if (_len == _cap) _status = NSStreamStatusAtEnd; }
    else {
        ssize_t w = write(_fd, buffer, len);
        if (w < 0) { _error = posix_error(errno, _path); _status = NSStreamStatusError; [self _isim_post:NSStreamEventErrorOccurred]; return -1; }
        n = w;
    }
    if (_status == NSStreamStatusOpen) [self _isim_post:NSStreamEventHasSpaceAvailable];
    return n;
}
- (id)propertyForKey:(NSStreamPropertyKey)key {
    if ([key isEqualToString:NSStreamDataWrittenToMemoryStreamKey]) return _mem ? [_mem copy] : nil;
    if ([key isEqualToString:NSStreamFileCurrentOffsetKey]) return _fd >= 0 ? @((unsigned long long)lseek(_fd, 0, SEEK_CUR)) : @(_mem.length);
    return [super propertyForKey:key];
}
@end

/* ================= a shared byte pipe: socket and bound streams ================= */
@interface __IsimPipe : NSObject {
@public
    pthread_mutex_t lock;
    pthread_cond_t cond;
    NSMutableData *buf;              /* bytes waiting for the input stream */
    NSUInteger capacity;             /* bound pairs: the buffer size; sockets: 0 (unbounded) */
    BOOL writerClosed, readerClosed, failed;
}
@end
@implementation __IsimPipe
- (instancetype)init {
    if ((self = [super init])) { pthread_mutex_init(&lock, NULL); pthread_cond_init(&cond, NULL); buf = [NSMutableData data]; }
    return self;
}
- (void)dealloc { pthread_mutex_destroy(&lock); pthread_cond_destroy(&cond); }
@end

/* ================= socket streams ================= */
@class __IsimSocketInputStream, __IsimSocketOutputStream;
@interface __IsimSocket : NSObject {
@public
    NSString *host; NSInteger port;
    NSData *address; int family, type, protocol;   /* or a socket address to connect to (CFSocketSignature) */
    BOOL adopted;                    /* or a connected native socket (CFStreamCreatePairWithSocket) */
    BOOL closeNative;                /* close the socket with the streams (kCFStreamPropertyShouldCloseNativeSocket) */
    int fd;
    struct isim_tls *tls;
    pthread_mutex_t tlsLock;
    __IsimPipe *in;
    NSStreamStatus status;           /* NotOpen -> Opening -> Open -> AtEnd / Error */
    NSError *error;
    BOOL started;
    __weak __IsimSocketInputStream *input;
    __weak __IsimSocketOutputStream *output;
}
@end
@interface __IsimSocketInputStream : NSInputStream { @public __IsimSocket *_sock; BOOL _opened, _closed; }
@end
@interface __IsimSocketOutputStream : NSOutputStream { @public __IsimSocket *_sock; BOOL _opened, _closed; }
@end

static NSError *net_error(int err) { return [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil]; }

@implementation __IsimSocket
- (instancetype)init {
    if ((self = [super init])) { fd = -1; closeNative = YES; in = [__IsimPipe new]; pthread_mutex_init(&tlsLock, NULL); }
    return self;
}
- (void)dealloc {
    if (tls) isim_tls_close(tls);
    if (fd >= 0 && closeNative) close(fd);
    pthread_mutex_destroy(&tlsLock);
}
/* the settings of whichever stream has them (they are shared, like CFStream's) */
- (id)_setting:(NSString *)key {
    id v = [input propertyForKey:key]; if (v) return v;
    return [output propertyForKey:key];
}
- (void)_postBoth:(NSStreamEvent)e {
    __IsimSocketInputStream *i = input; __IsimSocketOutputStream *o = output;
    if (i && i->_opened && !i->_closed) [i _isim_post:e];
    if (o && o->_opened && !o->_closed && e != NSStreamEventHasBytesAvailable && e != NSStreamEventEndEncountered) [o _isim_post:e];
}
- (void)_fail:(NSError *)e {
    @synchronized (self) { error = e; status = NSStreamStatusError; }
    pthread_mutex_lock(&in->lock); in->failed = YES; pthread_cond_broadcast(&in->cond); pthread_mutex_unlock(&in->lock);
    [self _postBoth:NSStreamEventErrorOccurred];
}
/* a socket connected to `address` (a Darwin socket address), or -1 with errno */
static int connect_address(NSData *address, int family, int type, int protocol) {
    const struct sockaddr *sa = address.bytes;
    if (address.length < 2) { errno = EINVAL; return -1; }
    int s = socket(family ?: sa->sa_family, type ?: SOCK_STREAM, protocol);
    if (s < 0) return -1;
    if (connect(s, sa, (socklen_t)address.length) != 0) { int e = errno; close(s); errno = e; return -1; }
    return s;
}
/* connect (and the TLS handshake), then read until the peer closes */
- (void)_run {
    if (!adopted && address) {
        int s = connect_address(address, family, type, protocol);
        if (s < 0) { [self _fail:net_error(errno ?: ECONNREFUSED)]; return; }
        fd = s;
    } else if (!adopted) [self _connectToHost];
    if (fd < 0) return;
    [self _pump];
}
- (void)_connectToHost {
    struct addrinfo hints = { .ai_family = AF_UNSPEC, .ai_socktype = SOCK_STREAM }, *res = NULL;
    char portstr[16]; snprintf(portstr, sizeof portstr, "%ld", (long)port);
    int rc = getaddrinfo(host.UTF8String, portstr, &hints, &res);
    if (rc != 0 || !res) {
        [self _fail:[NSError errorWithDomain:@"kCFErrorDomainCFNetwork" code:-72000 /* kCFHostErrorUnknown */
                                    userInfo:@{ @"kCFGetAddrInfoFailureKey": @(rc), NSLocalizedDescriptionKey: @"The host could not be found" }]];
        return;
    }
    int s = -1, err = 0;
    for (struct addrinfo *a = res; a; a = a->ai_next) {
        s = socket(a->ai_family, a->ai_socktype, a->ai_protocol);
        if (s < 0) { err = errno; continue; }
        if (connect(s, a->ai_addr, a->ai_addrlen) == 0) break;
        err = errno; close(s); s = -1;
    }
    freeaddrinfo(res);
    if (s < 0) { [self _fail:net_error(err ?: ECONNREFUSED)]; return; }
    fd = s;
}
/* the TLS handshake (when asked for), then read until the peer closes */
- (void)_pump {
    NSString *level = [self _setting:NSStreamSocketSecurityLevelKey];
    NSDictionary *ssl = [self _setting:kSSLSettings];
    if ([ssl[kSSLLevel] isKindOfClass:[NSString class]]) level = ssl[kSSLLevel];
    if (ssl && !level) level = NSStreamSocketSecurityLevelNegotiatedSSL;
    if (level && ![level isEqualToString:NSStreamSocketSecurityLevelNone]) {
        BOOL verify = !ssl[kSSLValidatesChain] || [ssl[kSSLValidatesChain] boolValue];
        id peer = ssl[kSSLPeerName];
        NSString *name = [peer isKindOfClass:[NSString class]] ? peer : peer == [NSNull null] ? nil : host;
        char msg[256] = {0}; int code = 0;
        int minVersion = [level isEqualToString:NSStreamSocketSecurityLevelTLSv1] ? 0x0301 : 0;
        tls = isim_tls_connect(fd, name.UTF8String, verify, NULL, minVersion, msg, sizeof msg, &code);
        if (!tls) {
            [self _fail:[NSError errorWithDomain:NSOSStatusErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey: @(msg) }]];
            return;
        }
    }
    if (tls) fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);   /* one session, read and written from two threads */
    @synchronized (self) { status = NSStreamStatusOpen; }
    __IsimSocketInputStream *i = input; __IsimSocketOutputStream *o = output;
    if (i && i->_opened) [i _isim_post:NSStreamEventOpenCompleted];
    if (o && o->_opened) { [o _isim_post:NSStreamEventOpenCompleted]; [o _isim_post:NSStreamEventHasSpaceAvailable]; }
    char chunk[16384];
    for (;;) {
        struct pollfd p = { .fd = fd, .events = POLLIN };
        int pr = poll(&p, 1, 250);
        if (pr < 0 && errno != EINTR) { [self _fail:net_error(errno)]; return; }
        @synchronized (self) { if (status == NSStreamStatusClosed) return; }
        if (in->readerClosed) return;
        if (pr <= 0) continue;
        long n;
        if (tls) {
            pthread_mutex_lock(&tlsLock); errno = 0; n = isim_tls_read_nb(tls, chunk, sizeof chunk); pthread_mutex_unlock(&tlsLock);
            if (n == -2) continue;                        /* a record that carried no data (a session ticket) */
            if (n < 0 && errno == 0) n = 0;               /* the peer closed without close_notify: end of stream */
        }
        else n = read(fd, chunk, sizeof chunk);
        if (n < 0 && (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK)) continue;
        if (n < 0) { [self _fail:net_error(errno)]; return; }
        pthread_mutex_lock(&in->lock);
        if (n == 0) in->writerClosed = YES; else [in->buf appendBytes:chunk length:(NSUInteger)n];
        pthread_cond_broadcast(&in->cond);
        pthread_mutex_unlock(&in->lock);
        __IsimSocketInputStream *inStream = input;
        if (n == 0) { if (inStream && inStream->_opened) [inStream _isim_post:NSStreamEventEndEncountered]; return; }
        if (inStream && inStream->_opened) [inStream _isim_post:NSStreamEventHasBytesAvailable];
    }
}
- (void)_start {
    @synchronized (self) { if (started) return; started = YES; status = NSStreamStatusOpening; }
    __IsimSocket *me = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ [me _run]; });
}
- (void)_closeOne {
    __IsimSocketInputStream *i = input; __IsimSocketOutputStream *o = output;
    BOOL both = (!i || i->_closed) && (!o || o->_closed);
    if (o && o->_closed && fd >= 0 && closeNative) shutdown(fd, SHUT_WR);
    if (!both) return;
    @synchronized (self) { status = NSStreamStatusClosed; }
    pthread_mutex_lock(&in->lock); in->readerClosed = YES; pthread_cond_broadcast(&in->cond); pthread_mutex_unlock(&in->lock);
}
@end

/* the properties a socket stream reports: its native socket, the host and port it connects to */
static id socket_property(__IsimSocket *sock, NSString *key) {
    if ([key isEqualToString:kNativeHandle] && sock->fd >= 0) { int f = sock->fd; return [NSData dataWithBytes:&f length:sizeof f]; }
    if ([key isEqualToString:kRemoteHostName]) return sock->host;
    if ([key isEqualToString:kRemotePort] && sock->host) return @(sock->port);
    if ([key isEqualToString:kShouldCloseNative]) return @(sock->closeNative);
    return nil;
}

@implementation __IsimSocketInputStream
- (void)_isim_openedLate {   /* opened after the connection was made */
    NSStreamStatus s; @synchronized (_sock) { s = _sock->status; }
    if (s == NSStreamStatusOpen) { [self _isim_post:NSStreamEventOpenCompleted]; if (self.hasBytesAvailable) [self _isim_post:NSStreamEventHasBytesAvailable]; }
}
- (NSStreamStatus)streamStatus {
    if (_closed) return NSStreamStatusClosed;
    if (!_opened) return NSStreamStatusNotOpen;
    NSStreamStatus s; @synchronized (_sock) { s = _sock->status; }
    if (s == NSStreamStatusOpen) {
        pthread_mutex_lock(&_sock->in->lock);
        BOOL end = _sock->in->writerClosed && !_sock->in->buf.length;
        pthread_mutex_unlock(&_sock->in->lock);
        if (end) return NSStreamStatusAtEnd;
    }
    return s;
}
- (NSError *)streamError { @synchronized (_sock) { return _sock->error; } }
- (void)open { if (_opened) return; _opened = YES; [_sock _start]; [self _isim_openedLate]; }
- (void)close { if (_closed) return; _closed = YES; [_sock _closeOne]; }
- (void)_isim_scheduled { if (self.hasBytesAvailable) [self _isim_post:NSStreamEventHasBytesAvailable]; }
- (BOOL)hasBytesAvailable {
    if (!_opened || _closed) return NO;
    pthread_mutex_lock(&_sock->in->lock); BOOL b = _sock->in->buf.length > 0; pthread_mutex_unlock(&_sock->in->lock);
    return b;
}
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if (!_opened || _closed) return -1;
    __IsimPipe *p = _sock->in;
    pthread_mutex_lock(&p->lock);
    while (!p->buf.length && !p->writerClosed && !p->failed && !p->readerClosed) pthread_cond_wait(&p->cond, &p->lock);
    if (p->failed && !p->buf.length) { pthread_mutex_unlock(&p->lock); return -1; }
    NSUInteger n = MIN(len, p->buf.length);
    memcpy(buffer, p->buf.bytes, n);
    [p->buf replaceBytesInRange:NSMakeRange(0, n) withBytes:NULL length:0];
    BOOL more = p->buf.length > 0, end = p->writerClosed && !p->buf.length;
    pthread_mutex_unlock(&p->lock);
    if (more) [self _isim_post:NSStreamEventHasBytesAvailable];
    else if (end && n) [self _isim_post:NSStreamEventEndEncountered];
    return (NSInteger)n;
}
- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len { return NO; }
- (id)propertyForKey:(NSStreamPropertyKey)key {
    id v = socket_property(_sock, key);
    return v ?: [super propertyForKey:key];
}
- (BOOL)setProperty:(id)property forKey:(NSStreamPropertyKey)key {
    if ([key isEqualToString:kShouldCloseNative]) _sock->closeNative = [property boolValue];
    return [super setProperty:property forKey:key];
}
@end

@implementation __IsimSocketOutputStream
- (void)_isim_openedLate {
    NSStreamStatus s; @synchronized (_sock) { s = _sock->status; }
    if (s == NSStreamStatusOpen) { [self _isim_post:NSStreamEventOpenCompleted]; [self _isim_post:NSStreamEventHasSpaceAvailable]; }
}
- (NSStreamStatus)streamStatus {
    if (_closed) return NSStreamStatusClosed;
    if (!_opened) return NSStreamStatusNotOpen;
    @synchronized (_sock) { return _sock->status; }
}
- (NSError *)streamError { @synchronized (_sock) { return _sock->error; } }
- (void)open { if (_opened) return; _opened = YES; [_sock _start]; [self _isim_openedLate]; }
- (void)close { if (_closed) return; _closed = YES; [_sock _closeOne]; }
- (void)_isim_scheduled { if (self.hasSpaceAvailable) [self _isim_post:NSStreamEventHasSpaceAvailable]; }
- (BOOL)hasSpaceAvailable { return self.streamStatus == NSStreamStatusOpen; }
- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    if (self.streamStatus != NSStreamStatusOpen) return -1;
    long n;
    if (_sock->tls) {
        for (;;) {
            pthread_mutex_lock(&_sock->tlsLock); n = isim_tls_write_nb(_sock->tls, buffer, (long)len); pthread_mutex_unlock(&_sock->tlsLock);
            if (n != -2) break;
            struct pollfd p = { .fd = _sock->fd, .events = POLLOUT | POLLIN };
            poll(&p, 1, 100);
        }
    }
    else
        for (;;) {                                       /* (an adopted socket may be non-blocking) */
            n = send(_sock->fd, buffer, len, 0);
            if (n >= 0 || (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)) break;
            struct pollfd p = { .fd = _sock->fd, .events = POLLOUT };
            poll(&p, 1, 100);
        }
    if (n < 0) { [_sock _fail:net_error(errno ?: EPIPE)]; return -1; }
    [self _isim_post:NSStreamEventHasSpaceAvailable];
    return n;
}
- (id)propertyForKey:(NSStreamPropertyKey)key {
    id v = socket_property(_sock, key);
    return v ?: [super propertyForKey:key];
}
- (BOOL)setProperty:(id)property forKey:(NSStreamPropertyKey)key {
    if ([key isEqualToString:kShouldCloseNative]) _sock->closeNative = [property boolValue];
    return [super setProperty:property forKey:key];
}
@end

/* ================= bound pairs ================= */
@interface __IsimBoundInputStream : NSInputStream { @public __IsimPipe *_pipe; BOOL _opened, _closed; __weak NSOutputStream *_peer; }
@end
@interface __IsimBoundOutputStream : NSOutputStream { @public __IsimPipe *_pipe; BOOL _opened, _closed; __weak __IsimBoundInputStream *_peer; }
@end
@implementation __IsimBoundInputStream
- (NSStreamStatus)streamStatus {
    if (_closed) return NSStreamStatusClosed;
    if (!_opened) return NSStreamStatusNotOpen;
    pthread_mutex_lock(&_pipe->lock); BOOL end = _pipe->writerClosed && !_pipe->buf.length; pthread_mutex_unlock(&_pipe->lock);
    return end ? NSStreamStatusAtEnd : NSStreamStatusOpen;
}
- (NSError *)streamError { return nil; }
- (void)open {
    if (_opened) return;
    _opened = YES;
    [self _isim_post:NSStreamEventOpenCompleted];
    if (self.hasBytesAvailable) [self _isim_post:NSStreamEventHasBytesAvailable];
}
- (void)close {
    if (_closed) return;
    _closed = YES;
    pthread_mutex_lock(&_pipe->lock); _pipe->readerClosed = YES; pthread_cond_broadcast(&_pipe->cond); pthread_mutex_unlock(&_pipe->lock);
}
- (void)_isim_scheduled { if (self.hasBytesAvailable) [self _isim_post:NSStreamEventHasBytesAvailable]; else if (self.streamStatus == NSStreamStatusAtEnd) [self _isim_post:NSStreamEventEndEncountered]; }
- (BOOL)hasBytesAvailable {
    if (!_opened || _closed) return NO;
    pthread_mutex_lock(&_pipe->lock); BOOL b = _pipe->buf.length > 0; pthread_mutex_unlock(&_pipe->lock);
    return b;
}
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if (!_opened || _closed) return -1;
    pthread_mutex_lock(&_pipe->lock);
    while (!_pipe->buf.length && !_pipe->writerClosed && !_pipe->readerClosed) pthread_cond_wait(&_pipe->cond, &_pipe->lock);
    NSUInteger n = MIN(len, _pipe->buf.length);
    memcpy(buffer, _pipe->buf.bytes, n);
    [_pipe->buf replaceBytesInRange:NSMakeRange(0, n) withBytes:NULL length:0];
    BOOL more = _pipe->buf.length > 0, end = _pipe->writerClosed && !_pipe->buf.length;
    pthread_cond_broadcast(&_pipe->cond);
    pthread_mutex_unlock(&_pipe->lock);
    NSOutputStream *peer = _peer;
    if (n && peer) [peer _isim_post:NSStreamEventHasSpaceAvailable];
    if (more) [self _isim_post:NSStreamEventHasBytesAvailable];
    else if (end) [self _isim_post:NSStreamEventEndEncountered];
    return (NSInteger)n;
}
- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len { return NO; }
@end
@implementation __IsimBoundOutputStream
- (NSStreamStatus)streamStatus {
    if (_closed) return NSStreamStatusClosed;
    if (!_opened) return NSStreamStatusNotOpen;
    pthread_mutex_lock(&_pipe->lock); BOOL gone = _pipe->readerClosed; pthread_mutex_unlock(&_pipe->lock);
    return gone ? NSStreamStatusError : NSStreamStatusOpen;
}
- (NSError *)streamError { return self.streamStatus == NSStreamStatusError ? net_error(EPIPE) : nil; }
- (void)open {
    if (_opened) return;
    _opened = YES;
    [self _isim_post:NSStreamEventOpenCompleted];
    [self _isim_post:NSStreamEventHasSpaceAvailable];
}
- (void)close {
    if (_closed) return;
    _closed = YES;
    pthread_mutex_lock(&_pipe->lock); _pipe->writerClosed = YES; pthread_cond_broadcast(&_pipe->cond); pthread_mutex_unlock(&_pipe->lock);
    __IsimBoundInputStream *peer = _peer;
    if (peer && peer.streamStatus == NSStreamStatusAtEnd) [peer _isim_post:NSStreamEventEndEncountered];
}
- (void)_isim_scheduled { if (self.hasSpaceAvailable) [self _isim_post:NSStreamEventHasSpaceAvailable]; }
- (BOOL)hasSpaceAvailable {
    if (!_opened || _closed) return NO;
    pthread_mutex_lock(&_pipe->lock); BOOL b = _pipe->buf.length < _pipe->capacity && !_pipe->readerClosed; pthread_mutex_unlock(&_pipe->lock);
    return b;
}
/* writes what fits; waits for space when the buffer is full (like a pipe) */
- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    if (!_opened || _closed) return -1;
    pthread_mutex_lock(&_pipe->lock);
    while (_pipe->buf.length >= _pipe->capacity && !_pipe->readerClosed) pthread_cond_wait(&_pipe->cond, &_pipe->lock);
    if (_pipe->readerClosed) { pthread_mutex_unlock(&_pipe->lock); return -1; }
    NSUInteger n = MIN(len, _pipe->capacity - _pipe->buf.length);
    [_pipe->buf appendBytes:buffer length:n];
    BOOL space = _pipe->buf.length < _pipe->capacity;
    pthread_cond_broadcast(&_pipe->cond);
    pthread_mutex_unlock(&_pipe->lock);
    __IsimBoundInputStream *peer = _peer;
    if (n && peer && peer->_opened) [peer _isim_post:NSStreamEventHasBytesAvailable];
    if (space) [self _isim_post:NSStreamEventHasSpaceAvailable];
    return (NSInteger)n;
}
@end

@implementation NSStream (NSSocketStreamCreationExtensions)
+ (void)getStreamsToHostWithName:(NSString *)hostname port:(NSInteger)port inputStream:(NSInputStream **)inputStream outputStream:(NSOutputStream **)outputStream {
    __IsimSocket *s = [__IsimSocket new];
    s->host = [hostname copy]; s->port = port;
    __IsimSocketInputStream *i = [__IsimSocketInputStream new]; i->_sock = s; s->input = i;
    __IsimSocketOutputStream *o = [__IsimSocketOutputStream new]; o->_sock = s; s->output = o;
    if (inputStream) *inputStream = i;
    if (outputStream) *outputStream = o;
}
+ (void)getBoundStreamsWithBufferSize:(NSUInteger)bufferSize inputStream:(NSInputStream **)inputStream outputStream:(NSOutputStream **)outputStream {
    __IsimPipe *p = [__IsimPipe new];
    p->capacity = MAX(bufferSize, (NSUInteger)1);
    __IsimBoundInputStream *i = [__IsimBoundInputStream new]; i->_pipe = p;
    __IsimBoundOutputStream *o = [__IsimBoundOutputStream new]; o->_pipe = p;
    i->_peer = o; o->_peer = i;
    if (inputStream) *inputStream = i;
    if (outputStream) *outputStream = o;
}
@end

/* ================= CoreFoundation: CFReadStream / CFWriteStream (toll-free bridged with the classes above) ================= */
const CFStringRef kCFStreamPropertyDataWritten = CFSTR("kCFStreamPropertyDataWritten");
const CFStringRef kCFStreamPropertyAppendToFile = CFSTR("kCFStreamPropertyAppendToFile");
const CFStringRef kCFStreamPropertyFileCurrentOffset = CFSTR("kCFStreamPropertyFileCurrentOffset");
const CFStringRef kCFStreamPropertySocketNativeHandle = CFSTR("kCFStreamPropertySocketNativeHandle");
const CFStringRef kCFStreamPropertySocketRemoteHostName = CFSTR("kCFStreamPropertySocketRemoteHostName");
const CFStringRef kCFStreamPropertySocketRemotePortNumber = CFSTR("kCFStreamPropertySocketRemotePortNumber");

enum { ISIM_CF_READSTREAM = 0x5e40, ISIM_CF_WRITESTREAM };
CFTypeID CFReadStreamGetTypeID(void) { return ISIM_CF_READSTREAM; }
CFTypeID CFWriteStreamGetTypeID(void) { return ISIM_CF_WRITESTREAM; }
@implementation NSInputStream (IsimCFReadStream)
- (CFTypeID)_isimCFTypeID { return ISIM_CF_READSTREAM; }
@end
@implementation NSOutputStream (IsimCFWriteStream)
- (CFTypeID)_isimCFTypeID { return ISIM_CF_WRITESTREAM; }
@end

#define RS(s) ((__bridge NSInputStream *)(s))
#define WS(s) ((__bridge NSOutputStream *)(s))

CFReadStreamRef CFReadStreamCreateWithBytesNoCopy(CFAllocatorRef alloc, const UInt8 *bytes, CFIndex length, CFAllocatorRef dealloc) {
    NSData *d = dealloc == kCFAllocatorNull ? [NSData dataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length freeWhenDone:NO]
                                            : [NSData dataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length freeWhenDone:YES];
    return (CFReadStreamRef)CFBridgingRetain([[NSInputStream alloc] initWithData:d]);
}
CFWriteStreamRef CFWriteStreamCreateWithBuffer(CFAllocatorRef alloc, UInt8 *buffer, CFIndex capacity) {
    return (CFWriteStreamRef)CFBridgingRetain([[NSOutputStream alloc] initToBuffer:buffer capacity:(NSUInteger)capacity]);
}
CFWriteStreamRef CFWriteStreamCreateWithAllocatedBuffers(CFAllocatorRef alloc, CFAllocatorRef bufferAllocator) {
    return (CFWriteStreamRef)CFBridgingRetain([[NSOutputStream alloc] initToMemory]);
}
CFReadStreamRef CFReadStreamCreateWithFile(CFAllocatorRef alloc, CFURLRef url) {
    NSURL *u = (__bridge NSURL *)url;
    return u.isFileURL ? (CFReadStreamRef)CFBridgingRetain([[NSInputStream alloc] initWithFileAtPath:u.path]) : NULL;
}
/* (appends when kCFStreamPropertyAppendToFile is set before it opens) */
@interface __IsimCFFileOutputStream : NSOutputStream { @public NSString *_cfPath; NSOutputStream *_inner; }
@end
@implementation __IsimCFFileOutputStream
- (void)open {
    if (_inner) return;
    _inner = [[NSOutputStream alloc] initToFileAtPath:_cfPath append:[[super propertyForKey:(__bridge NSString *)kCFStreamPropertyAppendToFile] boolValue]];
    [_inner open];
    if (_inner.streamStatus == NSStreamStatusOpen) { [self _isim_post:NSStreamEventOpenCompleted]; [self _isim_post:NSStreamEventHasSpaceAvailable]; }
    else [self _isim_post:NSStreamEventErrorOccurred];
}
- (void)close { [_inner close]; }
- (NSStreamStatus)streamStatus { return _inner ? _inner.streamStatus : NSStreamStatusNotOpen; }
- (NSError *)streamError { return _inner.streamError; }
- (void)_isim_scheduled { if (self.streamStatus == NSStreamStatusOpen) [self _isim_post:NSStreamEventHasSpaceAvailable]; }
- (BOOL)hasSpaceAvailable { return _inner.hasSpaceAvailable; }
- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    NSInteger n = _inner ? [_inner write:buffer maxLength:len] : -1;
    if (n >= 0) [self _isim_post:NSStreamEventHasSpaceAvailable]; else if (_inner) [self _isim_post:NSStreamEventErrorOccurred];
    return n;
}
- (id)propertyForKey:(NSStreamPropertyKey)key {
    if ([key isEqualToString:NSStreamFileCurrentOffsetKey]) return [_inner propertyForKey:key];
    return [super propertyForKey:key];
}
@end
CFWriteStreamRef CFWriteStreamCreateWithFile(CFAllocatorRef alloc, CFURLRef url) {
    NSURL *u = (__bridge NSURL *)url;
    if (!u.isFileURL) return NULL;
    __IsimCFFileOutputStream *s = [__IsimCFFileOutputStream new];
    s->_cfPath = u.path;
    return (CFWriteStreamRef)CFBridgingRetain(s);
}
void CFStreamCreateBoundPair(CFAllocatorRef alloc, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream, CFIndex size) {
    NSInputStream *i; NSOutputStream *o;
    [NSStream getBoundStreamsWithBufferSize:(NSUInteger)MAX(size, (CFIndex)1) inputStream:&i outputStream:&o];
    if (readStream) *readStream = (CFReadStreamRef)CFBridgingRetain(i);
    if (writeStream) *writeStream = (CFWriteStreamRef)CFBridgingRetain(o);
}
static void socket_pair(__IsimSocket *s, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream) {
    __IsimSocketInputStream *i = [__IsimSocketInputStream new]; i->_sock = s; s->input = i;
    __IsimSocketOutputStream *o = [__IsimSocketOutputStream new]; o->_sock = s; s->output = o;
    if (readStream) *readStream = (CFReadStreamRef)CFBridgingRetain(i);
    if (writeStream) *writeStream = (CFWriteStreamRef)CFBridgingRetain(o);
}
void CFStreamCreatePairWithSocket(CFAllocatorRef alloc, CFSocketNativeHandle sock, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream) {
    __IsimSocket *s = [__IsimSocket new];
    s->fd = sock; s->adopted = YES; s->closeNative = NO;
    socket_pair(s, readStream, writeStream);
}
void CFStreamCreatePairWithSocketToHost(CFAllocatorRef alloc, CFStringRef host, UInt32 port, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream) {
    __IsimSocket *s = [__IsimSocket new];
    s->host = [(__bridge NSString *)host copy]; s->port = port;
    socket_pair(s, readStream, writeStream);
}
void CFStreamCreatePairWithPeerSocketSignature(CFAllocatorRef alloc, const CFSocketSignature *sig, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream) {
    __IsimSocket *s = [__IsimSocket new];
    s->address = [(__bridge NSData *)sig->address copy];
    s->family = sig->protocolFamily; s->type = sig->socketType; s->protocol = sig->protocol;
    socket_pair(s, readStream, writeStream);
}

CFStreamStatus CFReadStreamGetStatus(CFReadStreamRef s) { return (CFStreamStatus)RS(s).streamStatus; }
CFStreamStatus CFWriteStreamGetStatus(CFWriteStreamRef s) { return (CFStreamStatus)WS(s).streamStatus; }
CFErrorRef CFReadStreamCopyError(CFReadStreamRef s) { NSError *e = s ? RS(s).streamError : nil; return e ? (CFErrorRef)CFBridgingRetain(e) : NULL; }
CFErrorRef CFWriteStreamCopyError(CFWriteStreamRef s) { NSError *e = s ? WS(s).streamError : nil; return e ? (CFErrorRef)CFBridgingRetain(e) : NULL; }
/* a stream error as a domain and code: POSIX, OSStatus, getaddrinfo (kCFStreamErrorDomainNetDB) or custom */
static CFStreamError stream_error(NSError *e) {
    CFStreamError r = { 0, 0 };
    if (!e) return r;
    if ([e.domain isEqualToString:NSPOSIXErrorDomain]) { r.domain = kCFStreamErrorDomainPOSIX; r.error = (SInt32)e.code; }
    else if ([e.domain isEqualToString:NSOSStatusErrorDomain]) { r.domain = kCFStreamErrorDomainMacOSStatus; r.error = (SInt32)e.code; }
    else if (e.userInfo[@"kCFGetAddrInfoFailureKey"]) { r.domain = 12; r.error = [e.userInfo[@"kCFGetAddrInfoFailureKey"] intValue]; }
    else if ([e.userInfo[NSUnderlyingErrorKey] isKindOfClass:[NSError class]]) return stream_error(e.userInfo[NSUnderlyingErrorKey]);
    else { r.domain = kCFStreamErrorDomainCustom; r.error = (SInt32)e.code; }
    return r;
}
CFStreamError CFReadStreamGetError(CFReadStreamRef s) { return stream_error(RS(s).streamError); }
CFStreamError CFWriteStreamGetError(CFWriteStreamRef s) { return stream_error(WS(s).streamError); }

Boolean CFReadStreamOpen(CFReadStreamRef s) {
    if (RS(s).streamStatus != NSStreamStatusNotOpen) return false;
    [RS(s) open];
    return RS(s).streamStatus != NSStreamStatusError;
}
Boolean CFWriteStreamOpen(CFWriteStreamRef s) {
    if (WS(s).streamStatus != NSStreamStatusNotOpen) return false;
    [WS(s) open];
    return WS(s).streamStatus != NSStreamStatusError;
}
void CFReadStreamClose(CFReadStreamRef s) { [RS(s) close]; }
void CFWriteStreamClose(CFWriteStreamRef s) { [WS(s) close]; }
Boolean CFReadStreamHasBytesAvailable(CFReadStreamRef s) { return RS(s).hasBytesAvailable; }
CFIndex CFReadStreamRead(CFReadStreamRef s, UInt8 *buffer, CFIndex len) {
    NSStreamStatus st = RS(s).streamStatus;
    if (st == NSStreamStatusAtEnd) return 0;
    if (st != NSStreamStatusOpen && st != NSStreamStatusOpening) return -1;
    return [RS(s) read:buffer maxLength:(NSUInteger)MAX(len, (CFIndex)0)];
}
const UInt8 *CFReadStreamGetBuffer(CFReadStreamRef s, CFIndex maxBytesToRead, CFIndex *numBytesRead) {
    uint8_t *buf = NULL; NSUInteger n = 0;
    if (![RS(s) getBuffer:&buf length:&n]) { if (numBytesRead) *numBytesRead = RS(s).streamStatus == NSStreamStatusError ? -1 : 0; return NULL; }
    if (maxBytesToRead > 0 && n > (NSUInteger)maxBytesToRead) n = (NSUInteger)maxBytesToRead;
    /* the bytes count as read */
    NSNumber *pos = [RS(s) propertyForKey:NSStreamFileCurrentOffsetKey];
    [RS(s) setProperty:@(pos.unsignedLongLongValue + n) forKey:NSStreamFileCurrentOffsetKey];
    if (numBytesRead) *numBytesRead = (CFIndex)n;
    return buf;
}
Boolean CFWriteStreamCanAcceptBytes(CFWriteStreamRef s) { return WS(s).hasSpaceAvailable; }
CFIndex CFWriteStreamWrite(CFWriteStreamRef s, const UInt8 *buffer, CFIndex len) {
    if (WS(s).streamStatus != NSStreamStatusOpen) return -1;
    return [WS(s) write:buffer maxLength:(NSUInteger)MAX(len, (CFIndex)0)];
}
CFTypeRef CFReadStreamCopyProperty(CFReadStreamRef s, CFStreamPropertyKey key) {
    if (!s || !key) return NULL;
    id v = [RS(s) propertyForKey:(__bridge NSString *)key];
    return v ? CFBridgingRetain(v) : NULL;
}
CFTypeRef CFWriteStreamCopyProperty(CFWriteStreamRef s, CFStreamPropertyKey key) {
    if (!s || !key) return NULL;
    id v = [WS(s) propertyForKey:(__bridge NSString *)key];
    return v ? CFBridgingRetain(v) : NULL;
}
Boolean CFReadStreamSetProperty(CFReadStreamRef s, CFStreamPropertyKey key, CFTypeRef value) {
    return s && key && [RS(s) setProperty:(__bridge id)value forKey:(__bridge NSString *)key];
}
Boolean CFWriteStreamSetProperty(CFWriteStreamRef s, CFStreamPropertyKey key, CFTypeRef value) {
    return s && key && [WS(s) setProperty:(__bridge id)value forKey:(__bridge NSString *)key];
}

static Boolean set_client(NSStream *s, CFOptionFlags events, void *cb, CFStreamClientContext *ctx) {
    CFStreamClientContext old;
    @synchronized (s) {
        old = s->_cfContext;
        memset(&s->_cfContext, 0, sizeof s->_cfContext);
        if (cb && events) {
            s->_cfCallback = cb; s->_cfEvents = events;
            if (ctx) { s->_cfContext = *ctx; if (ctx->retain && ctx->info) s->_cfContext.info = ctx->retain(ctx->info); }
        } else { s->_cfCallback = NULL; s->_cfEvents = 0; }
    }
    if (old.release && old.info) old.release(old.info);
    if (cb && events) [s _isim_scheduled];             /* a client set on an open stream learns its state */
    return true;
}
Boolean CFReadStreamSetClient(CFReadStreamRef s, CFOptionFlags events, CFReadStreamClientCallBack cb, CFStreamClientContext *ctx) {
    return set_client(RS(s), events, (void *)cb, ctx);
}
Boolean CFWriteStreamSetClient(CFWriteStreamRef s, CFOptionFlags events, CFWriteStreamClientCallBack cb, CFStreamClientContext *ctx) {
    return set_client(WS(s), events, (void *)cb, ctx);
}
void CFReadStreamScheduleWithRunLoop(CFReadStreamRef s, CFRunLoopRef rl, CFRunLoopMode mode) { [RS(s) scheduleInRunLoop:(__bridge NSRunLoop *)rl forMode:(__bridge NSString *)mode]; }
void CFWriteStreamScheduleWithRunLoop(CFWriteStreamRef s, CFRunLoopRef rl, CFRunLoopMode mode) { [WS(s) scheduleInRunLoop:(__bridge NSRunLoop *)rl forMode:(__bridge NSString *)mode]; }
void CFReadStreamUnscheduleFromRunLoop(CFReadStreamRef s, CFRunLoopRef rl, CFRunLoopMode mode) { [RS(s) removeFromRunLoop:(__bridge NSRunLoop *)rl forMode:(__bridge NSString *)mode]; }
void CFWriteStreamUnscheduleFromRunLoop(CFWriteStreamRef s, CFRunLoopRef rl, CFRunLoopMode mode) { [WS(s) removeFromRunLoop:(__bridge NSRunLoop *)rl forMode:(__bridge NSString *)mode]; }
static void set_queue(NSStream *s, dispatch_queue_t q) {
    @synchronized (s) { s->_cfQueue = q; }
    if (q) [s _isim_scheduled];
}
void CFReadStreamSetDispatchQueue(CFReadStreamRef s, dispatch_queue_t q) { set_queue(RS(s), q); }
void CFWriteStreamSetDispatchQueue(CFWriteStreamRef s, dispatch_queue_t q) { set_queue(WS(s), q); }
dispatch_queue_t CFReadStreamCopyDispatchQueue(CFReadStreamRef s) { @synchronized (RS(s)) { return RS(s)->_cfQueue; } }
dispatch_queue_t CFWriteStreamCopyDispatchQueue(CFWriteStreamRef s) { @synchronized (WS(s)) { return WS(s)->_cfQueue; } }
