/* isim Foundation (ARC): NSFileHandle, NSStream / NSInputStream / NSOutputStream, NSScanner, and the
 * NSProcessInfo additions (thermal state, low power mode, memory, OS version, activities). */
#import <Foundation/Foundation.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <objc/runtime.h>
#include "isim_foundation.h"
int ftruncate(int, off_t);
int fsync(int);

NSExceptionName const NSFileHandleOperationException = @"NSFileHandleOperationException";
NSNotificationName const NSFileHandleReadCompletionNotification = @"NSFileHandleReadCompletionNotification",
    NSFileHandleReadToEndOfFileCompletionNotification = @"NSFileHandleReadToEndOfFileCompletionNotification",
    NSFileHandleDataAvailableNotification = @"NSFileHandleDataAvailableNotification";
NSString *const NSFileHandleNotificationDataItem = @"NSFileHandleNotificationDataItem";

static NSError *posix_error(int err, NSString *path) {
    NSInteger code = err == ENOENT ? 4 : err == EACCES || err == EPERM ? 513 : err == EEXIST ? 516 : err == ENOSPC ? 640 : 512;
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:[NSError errorWithDomain:@"NSPOSIXErrorDomain" code:err userInfo:nil] forKey:@"NSUnderlyingError"];
    if (path) info[@"NSFilePath"] = path;
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:info];
}

/* ================= NSFileHandle ================= */
@implementation NSFileHandle { int _fd; BOOL _close; BOOL _closed; pthread_t _reader; BOOL _readerRunning; }
@synthesize readabilityHandler = _readabilityHandler;
+ (NSFileHandle *)fileHandleWithStandardInput { static NSFileHandle *h; static dispatch_once_t o; dispatch_once(&o, ^{ h = [[NSFileHandle alloc] initWithFileDescriptor:0 closeOnDealloc:NO]; }); return h; }
+ (NSFileHandle *)fileHandleWithStandardOutput { static NSFileHandle *h; static dispatch_once_t o; dispatch_once(&o, ^{ h = [[NSFileHandle alloc] initWithFileDescriptor:1 closeOnDealloc:NO]; }); return h; }
+ (NSFileHandle *)fileHandleWithStandardError { static NSFileHandle *h; static dispatch_once_t o; dispatch_once(&o, ^{ h = [[NSFileHandle alloc] initWithFileDescriptor:2 closeOnDealloc:NO]; }); return h; }
+ (NSFileHandle *)fileHandleWithNullDevice { return [[NSFileHandle alloc] initWithFileDescriptor:open("/dev/null", O_RDWR) closeOnDealloc:YES]; }
+ (instancetype)_open:(NSString *)path flags:(int)flags error:(NSError **)error {
    int fd = path ? open(path.UTF8String, flags) : -1;
    if (fd < 0) { if (error) *error = posix_error(errno, path); return nil; }
    return [[self alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
}
+ (instancetype)fileHandleForReadingAtPath:(NSString *)path { return [self _open:path flags:O_RDONLY error:NULL]; }
+ (instancetype)fileHandleForWritingAtPath:(NSString *)path { return [self _open:path flags:O_WRONLY error:NULL]; }
+ (instancetype)fileHandleForUpdatingAtPath:(NSString *)path { return [self _open:path flags:O_RDWR error:NULL]; }
+ (instancetype)fileHandleForReadingFromURL:(NSURL *)url error:(NSError **)error { return [self _open:url.path flags:O_RDONLY error:error]; }
+ (instancetype)fileHandleForWritingToURL:(NSURL *)url error:(NSError **)error { return [self _open:url.path flags:O_WRONLY error:error]; }
+ (instancetype)fileHandleForUpdatingURL:(NSURL *)url error:(NSError **)error { return [self _open:url.path flags:O_RDWR error:error]; }
- (instancetype)initWithFileDescriptor:(int)fd closeOnDealloc:(BOOL)c { if ((self = [super init])) { _fd = fd; _close = c; } return self; }
- (instancetype)initWithFileDescriptor:(int)fd { return [self initWithFileDescriptor:fd closeOnDealloc:NO]; }
- (instancetype)init { return [self initWithFileDescriptor:-1 closeOnDealloc:NO]; }
- (void)dealloc { if (_close && !_closed && _fd >= 0) close(_fd); }
- (int)fileDescriptor { return _fd; }
- (BOOL)_check:(NSError **)error {
    if (_closed || _fd < 0) { if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:512 userInfo:nil]; return NO; }
    return YES;
}
- (NSData *)readDataToEndOfFileAndReturnError:(NSError **)error {
    if (![self _check:error]) return nil;
    NSMutableData *d = [NSMutableData data]; char buf[65536]; ssize_t r;
    while ((r = read(_fd, buf, sizeof buf)) > 0) [d appendBytes:buf length:(NSUInteger)r];
    if (r < 0) { if (error) *error = posix_error(errno, nil); return nil; }
    return d;
}
- (NSData *)readDataUpToLength:(NSUInteger)length error:(NSError **)error {
    if (![self _check:error]) return nil;
    NSMutableData *d = [NSMutableData data]; char buf[65536];
    while (d.length < length) {
        ssize_t r = read(_fd, buf, MIN(sizeof buf, length - d.length));
        if (r < 0) { if (error) *error = posix_error(errno, nil); return nil; }
        if (r == 0) break;
        [d appendBytes:buf length:(NSUInteger)r];
    }
    return d;
}
- (NSData *)readDataToEndOfFile { return [self readDataToEndOfFileAndReturnError:NULL] ?: [NSData data]; }
- (NSData *)readDataOfLength:(NSUInteger)length { return [self readDataUpToLength:length error:NULL] ?: [NSData data]; }
- (NSData *)availableData {
    NSData *pending = objc_getAssociatedObject(self, "isim.pending");
    if (pending) { objc_setAssociatedObject(self, "isim.pending", nil, OBJC_ASSOCIATION_RETAIN); return pending; }
    char buf[65536]; ssize_t r = _closed ? 0 : read(_fd, buf, sizeof buf);
    return r > 0 ? [NSData dataWithBytes:buf length:(NSUInteger)r] : [NSData data];
}
- (BOOL)writeData:(NSData *)data error:(NSError **)error {
    if (![self _check:error]) return NO;
    const char *p = data.bytes; NSUInteger left = data.length;
    while (left) {
        ssize_t w = write(_fd, p, left);
        if (w < 0) { if (errno == EINTR) continue; if (error) *error = posix_error(errno, nil); return NO; }
        p += w; left -= (NSUInteger)w;
    }
    return YES;
}
- (void)writeData:(NSData *)data {
    NSError *e = nil;
    if (![self writeData:data error:&e]) [NSException raise:NSFileHandleOperationException format:@"*** -[NSFileHandle writeData:]: %@", e];
}
- (BOOL)getOffset:(unsigned long long *)offset error:(NSError **)error {
    if (![self _check:error]) return NO;
    off_t o = lseek(_fd, 0, SEEK_CUR);
    if (o < 0) { if (error) *error = posix_error(errno, nil); return NO; }
    if (offset) *offset = (unsigned long long)o;
    return YES;
}
- (unsigned long long)offsetInFile { unsigned long long o = 0; [self getOffset:&o error:NULL]; return o; }
- (BOOL)seekToEndReturningOffset:(unsigned long long *)offset error:(NSError **)error {
    if (![self _check:error]) return NO;
    off_t o = lseek(_fd, 0, SEEK_END);
    if (o < 0) { if (error) *error = posix_error(errno, nil); return NO; }
    if (offset) *offset = (unsigned long long)o;
    return YES;
}
- (unsigned long long)seekToEndOfFile { unsigned long long o = 0; [self seekToEndReturningOffset:&o error:NULL]; return o; }
- (BOOL)seekToOffset:(unsigned long long)offset error:(NSError **)error {
    if (![self _check:error]) return NO;
    if (lseek(_fd, (off_t)offset, SEEK_SET) < 0) { if (error) *error = posix_error(errno, nil); return NO; }
    return YES;
}
- (void)seekToFileOffset:(unsigned long long)offset { [self seekToOffset:offset error:NULL]; }
- (BOOL)truncateAtOffset:(unsigned long long)offset error:(NSError **)error {
    if (![self _check:error]) return NO;
    if (ftruncate(_fd, (off_t)offset) != 0 || lseek(_fd, (off_t)offset, SEEK_SET) < 0) { if (error) *error = posix_error(errno, nil); return NO; }
    return YES;
}
- (void)truncateFileAtOffset:(unsigned long long)offset { [self truncateAtOffset:offset error:NULL]; }
- (BOOL)synchronizeAndReturnError:(NSError **)error { if (![self _check:error]) return NO; fsync(_fd); return YES; }
- (void)synchronizeFile { [self synchronizeAndReturnError:NULL]; }
- (BOOL)closeAndReturnError:(NSError **)error {
    if (_closed) return YES;
    _closed = YES; _readabilityHandler = nil;
    if (_fd >= 0 && close(_fd) != 0) { if (error) *error = posix_error(errno, nil); return NO; }
    return YES;
}
- (void)closeFile { [self closeAndReturnError:NULL]; }
static void *reader_thread(void *arg) {
    NSFileHandle *h = (__bridge_transfer NSFileHandle *)arg;
    char buf[65536];
    for (;;) {
        void (^handler)(NSFileHandle *) = h.readabilityHandler;
        if (!handler || h.fileDescriptor < 0) break;
        ssize_t r = read(h.fileDescriptor, buf, sizeof buf);
        if (r <= 0) { if (r < 0 && errno == EINTR) continue; break; }
        /* the handler reads -availableData; hand it the bytes we already read */
        objc_setAssociatedObject(h, "isim.pending", [NSData dataWithBytes:buf length:(NSUInteger)r], OBJC_ASSOCIATION_RETAIN);
        @autoreleasepool { handler(h); }
    }
    return NULL;
}
- (void (^)(NSFileHandle *))readabilityHandler { @synchronized (self) { return _readabilityHandler; } }
- (void)setReadabilityHandler:(void (^)(NSFileHandle *))handler {
    @synchronized (self) { _readabilityHandler = [handler copy]; }
    if (handler && !_readerRunning) {
        _readerRunning = YES;
        pthread_create(&_reader, NULL, reader_thread, (__bridge_retained void *)self);
        pthread_detach(_reader);
    }
}
@end

/* ================= NSStream ================= */
NSStreamPropertyKey const NSStreamDataWrittenToMemoryStreamKey = @"kCFStreamPropertyDataWritten", NSStreamFileCurrentOffsetKey = @"kCFStreamPropertyFileCurrentOffset";
@implementation NSStream { __weak id<NSStreamDelegate> _streamDelegate; }
- (id<NSStreamDelegate>)delegate { return _streamDelegate ?: (id<NSStreamDelegate>)self; }
- (void)setDelegate:(id<NSStreamDelegate>)d { _streamDelegate = d; }
- (void)open {}
- (void)close {}
- (id)propertyForKey:(NSStreamPropertyKey)key { return nil; }
- (BOOL)setProperty:(id)property forKey:(NSStreamPropertyKey)key { return NO; }
- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode {}
- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode {}
- (NSStreamStatus)streamStatus { return NSStreamStatusNotOpen; }
- (NSError *)streamError { return nil; }
@end

@implementation NSInputStream { NSData *_data; NSUInteger _pos; int _fd; NSString *_path; NSStreamStatus _status; NSError *_error; BOOL _scheduled; BOOL _eof; }
+ (instancetype)inputStreamWithData:(NSData *)data { return [[self alloc] initWithData:data]; }
+ (instancetype)inputStreamWithFileAtPath:(NSString *)path { return [[self alloc] initWithFileAtPath:path]; }
+ (instancetype)inputStreamWithURL:(NSURL *)url { return [[self alloc] initWithURL:url]; }
- (instancetype)initWithData:(NSData *)data { if ((self = [super init])) { _data = [data copy]; _fd = -1; } return self; }
- (instancetype)initWithFileAtPath:(NSString *)path { if ((self = [super init])) { _path = [path copy]; _fd = -1; } return self; }
- (instancetype)initWithURL:(NSURL *)url { return url.isFileURL ? [self initWithFileAtPath:url.path] : nil; }
- (void)dealloc { if (_fd >= 0) close(_fd); }
- (NSStreamStatus)streamStatus { return _status; }
- (NSError *)streamError { return _error; }
- (void)_post:(NSStreamEvent)event {
    if (!_scheduled) return;
    id<NSStreamDelegate> d = self.delegate;
    if (![d respondsToSelector:@selector(stream:handleEvent:)]) return;
    dispatch_async(dispatch_get_main_queue(), ^{ if (self->_status != NSStreamStatusClosed) [d stream:self handleEvent:event]; });
}
- (void)scheduleInRunLoop:(NSRunLoop *)rl forMode:(NSRunLoopMode)mode { _scheduled = YES; }
- (void)removeFromRunLoop:(NSRunLoop *)rl forMode:(NSRunLoopMode)mode { _scheduled = NO; }
- (void)open {
    if (_status != NSStreamStatusNotOpen) return;
    if (_path) {
        _fd = open(_path.UTF8String, O_RDONLY);
        if (_fd < 0) { _error = posix_error(errno, _path); _status = NSStreamStatusError; [self _post:NSStreamEventErrorOccurred]; return; }
    }
    _status = NSStreamStatusOpen;
    [self _post:NSStreamEventOpenCompleted];
    [self _post:self.hasBytesAvailable ? NSStreamEventHasBytesAvailable : NSStreamEventEndEncountered];
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
        if (r < 0) { _error = posix_error(errno, _path); _status = NSStreamStatusError; [self _post:NSStreamEventErrorOccurred]; return -1; }
        n = r; if (r == 0) _eof = YES;
    }
    if (_eof && n == 0) _status = NSStreamStatusAtEnd;
    [self _post:self.hasBytesAvailable ? NSStreamEventHasBytesAvailable : NSStreamEventEndEncountered];
    if (_eof && _data) _status = NSStreamStatusAtEnd;
    return n;
}
- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len { return NO; }
- (id)propertyForKey:(NSStreamPropertyKey)key {
    if ([key isEqualToString:NSStreamFileCurrentOffsetKey]) return _data ? @(_pos) : @((unsigned long long)lseek(_fd, 0, SEEK_CUR));
    return nil;
}
@end

@implementation NSOutputStream { NSMutableData *_mem; int _fd; NSString *_path; BOOL _append; NSStreamStatus _status; NSError *_error; BOOL _scheduled; uint8_t *_buf; NSUInteger _cap, _len; }
+ (instancetype)outputStreamToMemory { return [[self alloc] initToMemory]; }
+ (instancetype)outputStreamToFileAtPath:(NSString *)path append:(BOOL)a { return [[self alloc] initToFileAtPath:path append:a]; }
+ (instancetype)outputStreamWithURL:(NSURL *)url append:(BOOL)a { return [[self alloc] initWithURL:url append:a]; }
+ (instancetype)outputStreamToBuffer:(uint8_t *)buffer capacity:(NSUInteger)capacity { return [[self alloc] initToBuffer:buffer capacity:capacity]; }
- (instancetype)initToMemory { if ((self = [super init])) { _mem = [NSMutableData data]; _fd = -1; } return self; }
- (instancetype)initToBuffer:(uint8_t *)buffer capacity:(NSUInteger)capacity { if ((self = [super init])) { _buf = buffer; _cap = capacity; _fd = -1; } return self; }
- (instancetype)initToFileAtPath:(NSString *)path append:(BOOL)a { if ((self = [super init])) { _path = [path copy]; _append = a; _fd = -1; } return self; }
- (instancetype)initWithURL:(NSURL *)url append:(BOOL)a { return url.isFileURL ? [self initToFileAtPath:url.path append:a] : nil; }
- (void)dealloc { if (_fd >= 0) close(_fd); }
- (NSStreamStatus)streamStatus { return _status; }
- (NSError *)streamError { return _error; }
- (void)scheduleInRunLoop:(NSRunLoop *)rl forMode:(NSRunLoopMode)mode { _scheduled = YES; }
- (void)removeFromRunLoop:(NSRunLoop *)rl forMode:(NSRunLoopMode)mode { _scheduled = NO; }
- (void)_post:(NSStreamEvent)event {
    if (!_scheduled) return;
    id<NSStreamDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(stream:handleEvent:)]) dispatch_async(dispatch_get_main_queue(), ^{ if (self->_status != NSStreamStatusClosed) [d stream:self handleEvent:event]; });
}
- (void)open {
    if (_status != NSStreamStatusNotOpen) return;
    if (_path) {
        _fd = open(_path.UTF8String, O_WRONLY | O_CREAT | (_append ? O_APPEND : O_TRUNC), 0644);
        if (_fd < 0) { _error = posix_error(errno, _path); _status = NSStreamStatusError; [self _post:NSStreamEventErrorOccurred]; return; }
    }
    _status = NSStreamStatusOpen;
    [self _post:NSStreamEventOpenCompleted]; [self _post:NSStreamEventHasSpaceAvailable];
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
        if (w < 0) { _error = posix_error(errno, _path); _status = NSStreamStatusError; [self _post:NSStreamEventErrorOccurred]; return -1; }
        n = w;
    }
    [self _post:NSStreamEventHasSpaceAvailable];
    return n;
}
- (id)propertyForKey:(NSStreamPropertyKey)key {
    if ([key isEqualToString:NSStreamDataWrittenToMemoryStreamKey]) return _mem ? [_mem copy] : nil;
    if ([key isEqualToString:NSStreamFileCurrentOffsetKey]) return _fd >= 0 ? @((unsigned long long)lseek(_fd, 0, SEEK_CUR)) : @(_mem.length);
    return nil;
}
@end

/* ================= NSScanner ================= */
@implementation NSScanner { NSString *_string; unichar *_u; NSUInteger _n; }
+ (instancetype)scannerWithString:(NSString *)s { return [[self alloc] initWithString:s]; }
+ (id)localizedScannerWithString:(NSString *)s { NSScanner *sc = [[self alloc] initWithString:s]; sc.locale = NSLocale.currentLocale; return sc; }
- (instancetype)initWithString:(NSString *)s {
    if ((self = [super init])) {
        _string = [s copy] ?: @""; _n = _string.length; _u = malloc(sizeof(unichar) * (_n + 1)); [_string getCharacters:_u range:NSMakeRange(0, _n)];
        _charactersToBeSkipped = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    }
    return self;
}
- (void)dealloc { free(_u); }
- (id)copyWithZone:(NSZone *)z { NSScanner *s = [[NSScanner alloc] initWithString:_string]; s.scanLocation = _scanLocation; s.charactersToBeSkipped = _charactersToBeSkipped; s.caseSensitive = _caseSensitive; s.locale = _locale; return s; }
- (NSString *)string { return _string; }
- (void)_skip { if (_charactersToBeSkipped) while (_scanLocation < _n && [_charactersToBeSkipped characterIsMember:_u[_scanLocation]]) _scanLocation++; }
- (BOOL)isAtEnd { NSUInteger save = _scanLocation; [self _skip]; BOOL end = _scanLocation >= _n; _scanLocation = save; return end; }
- (BOOL)scanString:(NSString *)str intoString:(NSString **)result {
    NSUInteger save = _scanLocation; [self _skip];
    NSUInteger len = str.length;
    if (!len || _scanLocation + len > _n) { _scanLocation = save; return NO; }
    NSString *sub = [_string substringWithRange:NSMakeRange(_scanLocation, len)];
    BOOL ok = _caseSensitive ? [sub isEqualToString:str] : [sub caseInsensitiveCompare:str] == NSOrderedSame;
    if (!ok) { _scanLocation = save; return NO; }
    _scanLocation += len;
    if (result) *result = sub;
    return YES;
}
- (BOOL)scanCharactersFromSet:(NSCharacterSet *)set intoString:(NSString **)result {
    NSUInteger save = _scanLocation; [self _skip];
    NSUInteger start = _scanLocation;
    while (_scanLocation < _n && [set characterIsMember:_u[_scanLocation]]) _scanLocation++;
    if (_scanLocation == start) { _scanLocation = save; return NO; }
    if (result) *result = [_string substringWithRange:NSMakeRange(start, _scanLocation - start)];
    return YES;
}
- (BOOL)scanUpToCharactersFromSet:(NSCharacterSet *)set intoString:(NSString **)result {
    NSUInteger save = _scanLocation; [self _skip];
    NSUInteger start = _scanLocation;
    while (_scanLocation < _n && ![set characterIsMember:_u[_scanLocation]]) _scanLocation++;
    if (_scanLocation == start) { _scanLocation = save; return NO; }
    if (result) *result = [_string substringWithRange:NSMakeRange(start, _scanLocation - start)];
    return YES;
}
- (BOOL)scanUpToString:(NSString *)str intoString:(NSString **)result {
    NSUInteger save = _scanLocation; [self _skip];
    NSUInteger start = _scanLocation;
    NSRange r = [_string rangeOfString:str options:_caseSensitive ? 0 : NSCaseInsensitiveSearch range:NSMakeRange(start, _n - start)];
    NSUInteger end = r.location == NSNotFound ? _n : r.location;
    if (end == start) { _scanLocation = save; return NO; }
    _scanLocation = end;
    if (result) *result = [_string substringWithRange:NSMakeRange(start, end - start)];
    return YES;
}
/* digits (with an optional sign) as a C string; advances on success */
- (BOOL)_scanNumber:(char *)buf size:(size_t)size floating:(BOOL)fp hex:(BOOL)hex {
    NSUInteger save = _scanLocation; [self _skip];
    NSUInteger i = _scanLocation; size_t k = 0;
    NSString *dec = _locale ? [(NSLocale *)_locale decimalSeparator] : @".";
    unichar decChar = dec.length ? [dec characterAtIndex:0] : '.';
    if (i < _n && (_u[i] == '-' || _u[i] == '+')) { if (k < size - 1) buf[k++] = (char)_u[i]; i++; }
    if (hex && i + 1 < _n && _u[i] == '0' && (_u[i + 1] == 'x' || _u[i + 1] == 'X')) i += 2;
    BOOL digits = NO, seenDot = NO, seenExp = NO;
    while (i < _n && k < size - 1) {
        unichar c = _u[i];
        if ((c >= '0' && c <= '9') || (hex && ((c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')))) { buf[k++] = (char)c; digits = YES; i++; }
        else if (fp && c == decChar && !seenDot && !seenExp) { buf[k++] = '.'; seenDot = YES; i++; }
        else if (fp && (c == 'e' || c == 'E') && digits && !seenExp && i + 1 < _n && (isdigit(_u[i + 1]) || ((_u[i + 1] == '-' || _u[i + 1] == '+') && i + 2 < _n && isdigit(_u[i + 2])))) {
            buf[k++] = 'e'; seenExp = YES; i++;
            if (_u[i] == '-' || _u[i] == '+') buf[k++] = (char)_u[i++];
        }
        else break;
    }
    buf[k] = 0;
    if (!digits) { _scanLocation = save; return NO; }
    _scanLocation = i;
    return YES;
}
- (BOOL)scanLongLong:(long long *)result { char b[64]; if (![self _scanNumber:b size:sizeof b floating:NO hex:NO]) return NO; errno = 0; long long v = strtoll(b, NULL, 10); if (errno == ERANGE) v = b[0] == '-' ? LLONG_MIN : LLONG_MAX; if (result) *result = v; return YES; }
- (BOOL)scanUnsignedLongLong:(unsigned long long *)result { char b[64]; if (![self _scanNumber:b size:sizeof b floating:NO hex:NO]) return NO; if (result) *result = strtoull(b, NULL, 10); return YES; }
- (BOOL)scanInt:(int *)result { long long v; if (![self scanLongLong:&v]) return NO; if (result) *result = v > INT_MAX ? INT_MAX : v < INT_MIN ? INT_MIN : (int)v; return YES; }
- (BOOL)scanInteger:(NSInteger *)result { long long v; if (![self scanLongLong:&v]) return NO; if (result) *result = (NSInteger)v; return YES; }
- (BOOL)scanDouble:(double *)result { char b[128]; if (![self _scanNumber:b size:sizeof b floating:YES hex:NO]) return NO; if (result) *result = strtod(b, NULL); return YES; }
- (BOOL)scanFloat:(float *)result { double v; if (![self scanDouble:&v]) return NO; if (result) *result = (float)v; return YES; }
- (BOOL)scanHexLongLong:(unsigned long long *)result { char b[64]; if (![self _scanNumber:b size:sizeof b floating:NO hex:YES]) return NO; if (result) *result = strtoull(b, NULL, 16); return YES; }
- (BOOL)scanHexInt:(unsigned *)result { unsigned long long v; if (![self scanHexLongLong:&v]) return NO; if (result) *result = (unsigned)v; return YES; }
- (BOOL)scanHexDouble:(double *)result { return [self scanDouble:result]; }
- (BOOL)scanHexFloat:(float *)result { return [self scanFloat:result]; }
- (NSString *)_isim_scanNumberString:(BOOL)floating { char b[128]; return [self _scanNumber:b size:sizeof b floating:floating hex:NO] ? @(b) : nil; }
@end

/* ================= NSProcessInfo additions ================= */
NSNotificationName const NSProcessInfoThermalStateDidChangeNotification = @"NSProcessInfoThermalStateDidChangeNotification",
    NSProcessInfoPowerStateDidChangeNotification = @"NSProcessInfoPowerStateDidChangeNotification";
@implementation NSProcessInfo (IsimDevice)
- (NSProcessInfoThermalState)thermalState { return NSProcessInfoThermalStateNominal; }
- (BOOL)isLowPowerModeEnabled { return NO; }
- (BOOL)isiOSAppOnMac { return NO; }
- (BOOL)isMacCatalystApp { return NO; }
- (NSUInteger)activeProcessorCount { return self.processorCount; }
/* the simulated device's memory (by model, like the real hardware) */
- (unsigned long long)physicalMemory {
    const char *d = getenv("ISIM_DEVICE"); NSString *dev = d ? @(d) : @"iphone15";
    unsigned long long gb = [dev hasPrefix:@"iphonese"] ? 4 : [dev hasPrefix:@"iphone13"] || [dev hasPrefix:@"iphone14"] ? 4 :
                            [dev isEqualToString:@"iphone15"] || [dev isEqualToString:@"iphone15plus"] ? 6 :
                            [dev hasPrefix:@"ipadpro"] ? 16 : 8;
    return gb << 30;
}
- (NSOperatingSystemVersion)operatingSystemVersion {
    const char *v = getenv("ISIM_OS_VERSION"); NSString *s = v && *v ? @(v) : @"18.0";
    NSArray *p = [s componentsSeparatedByString:@"."];
    NSOperatingSystemVersion r = { p.count > 0 ? [p[0] integerValue] : 18, p.count > 1 ? [p[1] integerValue] : 0, p.count > 2 ? [p[2] integerValue] : 0 };
    return r;
}
- (NSString *)operatingSystemVersionString { NSOperatingSystemVersion v = self.operatingSystemVersion; return [NSString stringWithFormat:@"Version %ld.%ld%@", (long)v.majorVersion, (long)v.minorVersion, v.patchVersion ? [NSString stringWithFormat:@".%ld", (long)v.patchVersion] : @""]; }
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)v {
    NSOperatingSystemVersion c = self.operatingSystemVersion;
    if (c.majorVersion != v.majorVersion) return c.majorVersion > v.majorVersion;
    if (c.minorVersion != v.minorVersion) return c.minorVersion > v.minorVersion;
    return c.patchVersion >= v.patchVersion;
}
- (NSString *)hostName { return @"localhost"; }
- (NSString *)globallyUniqueString {
    static unsigned long long counter;
    return [NSString stringWithFormat:@"%@-%d-%016llX", [[NSUUID UUID] UUIDString], getpid(), __sync_add_and_fetch(&counter, 1)];
}
- (id<NSObject>)beginActivityWithOptions:(NSActivityOptions)options reason:(NSString *)reason { return [NSObject new]; }
- (void)endActivity:(id<NSObject>)activity {}
- (void)performActivityWithOptions:(NSActivityOptions)options reason:(NSString *)reason usingBlock:(void (NS_NOESCAPE ^)(void))block { block(); }
- (void)performExpiringActivityWithReason:(NSString *)reason usingBlock:(void (^)(BOOL expired))block {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{ block(NO); });
}
@end
