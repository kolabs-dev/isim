/* isim Foundation (ARC): NSStream, NSInputStream, NSOutputStream (data, file, memory, buffer), socket streams to a
 * host (+getStreamsToHostWithName:port:inputStream:outputStream:, TCP, TLS through the host's OpenSSL with
 * NSStreamSocketSecurityLevelKey / kCFStreamPropertySSLSettings) and bound stream pairs
 * (+getBoundStreamsWithBufferSize:inputStream:outputStream:). Self-authored.
 * Events go to the delegate on every run loop and mode the stream is scheduled in (none when unscheduled: the
 * stream is then polled, like iOS); a pending event is not posted twice before it is delivered. Reads of socket and
 * bound streams block until bytes arrive (check hasBytesAvailable first, as on iOS). */
#import <Foundation/Foundation.h>
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
    *const kSSLPeerName = @"kCFStreamSSLPeerName", *const kSSLLevel = @"kCFStreamSSLLevel", *const kNativeHandle = @"kCFStreamPropertySocketNativeHandle";

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
}
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
- (void)_isim_post:(NSStreamEvent)event {
    NSArray *schedules;
    @synchronized (self) {
        if (!_schedules.count || (_pending & event)) return;
        _pending |= event;
        schedules = [_schedules copy];
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
            if (self.streamStatus == NSStreamStatusClosed) return;
            id<NSStreamDelegate> d = self.delegate;
            if ([d respondsToSelector:@selector(stream:handleEvent:)]) [d stream:self handleEvent:event];
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
    if ((self = [super init])) { fd = -1; in = [__IsimPipe new]; pthread_mutex_init(&tlsLock, NULL); }
    return self;
}
- (void)dealloc {
    if (tls) isim_tls_close(tls);
    if (fd >= 0) close(fd);
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
/* connect (and the TLS handshake), then read until the peer closes */
- (void)_run {
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
        if (n < 0 && errno == EINTR) continue;
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
    if (o && o->_closed && fd >= 0) shutdown(fd, SHUT_WR);
    if (!both) return;
    @synchronized (self) { status = NSStreamStatusClosed; }
    pthread_mutex_lock(&in->lock); in->readerClosed = YES; pthread_cond_broadcast(&in->cond); pthread_mutex_unlock(&in->lock);
}
@end

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
    if ([key isEqualToString:kNativeHandle] && _sock->fd >= 0) { int f = _sock->fd; return [NSData dataWithBytes:&f length:sizeof f]; }
    return [super propertyForKey:key];
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
    else n = send(_sock->fd, buffer, len, 0);
    if (n < 0) { [_sock _fail:net_error(errno ?: EPIPE)]; return -1; }
    [self _isim_post:NSStreamEventHasSpaceAvailable];
    return n;
}
- (id)propertyForKey:(NSStreamPropertyKey)key {
    if ([key isEqualToString:kNativeHandle] && _sock->fd >= 0) { int f = _sock->fd; return [NSData dataWithBytes:&f length:sizeof f]; }
    return [super propertyForKey:key];
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
