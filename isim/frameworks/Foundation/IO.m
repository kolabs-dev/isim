/* isim Foundation (ARC): NSFileHandle, NSStream / NSInputStream / NSOutputStream, NSScanner, and the
 * NSProcessInfo additions (thermal state, low power mode, memory, OS version, activities). */
#import <Foundation/Foundation.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <sys/socket.h>
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
NSNotificationName const NSFileHandleConnectionAcceptedNotification = @"NSFileHandleConnectionAcceptedNotification";
NSString *const NSFileHandleNotificationFileHandleItem = @"NSFileHandleNotificationFileHandleItem",
    *const NSFileHandleNotificationMonitorModes = @"NSFileHandleNotificationMonitorModes";

static NSError *posix_error(int err, NSString *path) {
    NSInteger code = err == ENOENT ? 4 : err == EACCES || err == EPERM ? 513 : err == EEXIST ? 516 : err == ENOSPC ? 640 : 512;
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:[NSError errorWithDomain:@"NSPOSIXErrorDomain" code:err userInfo:nil] forKey:@"NSUnderlyingError"];
    if (path) info[@"NSFilePath"] = path;
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:info];
}

/* ================= NSFileHandle ================= */
@implementation NSFileHandle { int _fd; BOOL _close; BOOL _closed; pthread_t _reader; BOOL _readerRunning, _writerRunning; }
@synthesize readabilityHandler = _readabilityHandler, writeabilityHandler = _writeabilityHandler;
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
/* ---- background reads, accepts and waits: the work runs on another thread, the notification is posted on the
 * calling thread's run loop in the given modes (NSDefaultRunLoopMode by default), like iOS ---- */
- (void)_isim_background:(NSNotificationName)name modes:(NSArray<NSRunLoopMode> *)modes work:(NSDictionary *(^)(void))work {
    NSRunLoop *rl = NSRunLoop.currentRunLoop;
    NSArray *m = modes.count ? modes : @[NSDefaultRunLoopMode];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSDictionary *info = work();
        [rl performInModes:m block:^{ [NSNotificationCenter.defaultCenter postNotificationName:name object:self userInfo:info]; }];
    });
}
static NSDictionary *read_result(NSData *data, int err) {
    return err ? @{ NSFileHandleNotificationDataItem: data ?: [NSData data], @"NSFileHandleError": @(err) } : @{ NSFileHandleNotificationDataItem: data ?: [NSData data] };
}
- (void)readInBackgroundAndNotifyForModes:(NSArray<NSRunLoopMode> *)modes {
    int fd = _fd;
    [self _isim_background:NSFileHandleReadCompletionNotification modes:modes work:^NSDictionary *{
        char buf[65536];
        for (;;) {
            ssize_t r = read(fd, buf, sizeof buf);
            if (r < 0 && errno == EINTR) continue;
            return read_result(r > 0 ? [NSData dataWithBytes:buf length:(NSUInteger)r] : [NSData data], r < 0 ? errno : 0);
        }
    }];
}
- (void)readInBackgroundAndNotify { [self readInBackgroundAndNotifyForModes:nil]; }
- (void)readToEndOfFileInBackgroundAndNotifyForModes:(NSArray<NSRunLoopMode> *)modes {
    int fd = _fd;
    [self _isim_background:NSFileHandleReadToEndOfFileCompletionNotification modes:modes work:^NSDictionary *{
        NSMutableData *all = [NSMutableData data];
        char buf[65536];
        for (;;) {
            ssize_t r = read(fd, buf, sizeof buf);
            if (r < 0 && errno == EINTR) continue;
            if (r <= 0) return read_result(all, r < 0 ? errno : 0);
            [all appendBytes:buf length:(NSUInteger)r];
        }
    }];
}
- (void)readToEndOfFileInBackgroundAndNotify { [self readToEndOfFileInBackgroundAndNotifyForModes:nil]; }
/* a listening socket: the next connection, as a file handle that closes it on dealloc */
- (void)acceptConnectionInBackgroundAndNotifyForModes:(NSArray<NSRunLoopMode> *)modes {
    int fd = _fd;
    [self _isim_background:NSFileHandleConnectionAcceptedNotification modes:modes work:^NSDictionary *{
        for (;;) {
            int c = accept(fd, NULL, NULL);
            if (c < 0 && errno == EINTR) continue;
            if (c < 0) return @{ @"NSFileHandleError": @(errno) };
            return @{ NSFileHandleNotificationFileHandleItem: [[NSFileHandle alloc] initWithFileDescriptor:c closeOnDealloc:YES] };
        }
    }];
}
- (void)acceptConnectionInBackgroundAndNotify { [self acceptConnectionInBackgroundAndNotifyForModes:nil]; }
- (void)waitForDataInBackgroundAndNotifyForModes:(NSArray<NSRunLoopMode> *)modes {
    int fd = _fd;
    [self _isim_background:NSFileHandleDataAvailableNotification modes:modes work:^NSDictionary *{
        struct pollfd p = { .fd = fd, .events = POLLIN };
        while (poll(&p, 1, -1) < 0 && errno == EINTR) {}
        return nil;
    }];
}
- (void)waitForDataInBackgroundAndNotify { [self waitForDataInBackgroundAndNotifyForModes:nil]; }
/* called (on another thread) whenever the descriptor can take more data, while the handler is set */
static void *writer_thread(void *arg) {
    NSFileHandle *h = (__bridge_transfer NSFileHandle *)arg;
    for (;;) {
        void (^handler)(NSFileHandle *) = h.writeabilityHandler;
        if (!handler || h.fileDescriptor < 0) break;
        struct pollfd p = { .fd = h.fileDescriptor, .events = POLLOUT };
        int r = poll(&p, 1, 200);
        if (r < 0 && errno != EINTR) break;
        if (r > 0 && (p.revents & POLLOUT)) { @autoreleasepool { handler(h); } }
        if (r > 0 && (p.revents & (POLLERR | POLLHUP | POLLNVAL))) break;
    }
    return NULL;
}
- (void (^)(NSFileHandle *))writeabilityHandler { @synchronized (self) { return _writeabilityHandler; } }
- (void)setWriteabilityHandler:(void (^)(NSFileHandle *))handler {
    BOOL start;
    @synchronized (self) { _writeabilityHandler = [handler copy]; start = handler && !_writerRunning; if (start) _writerRunning = YES; }
    if (start) {
        pthread_t t;
        pthread_create(&t, NULL, writer_thread, (__bridge_retained void *)self);
        pthread_detach(t);
    }
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
