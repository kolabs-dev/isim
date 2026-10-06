/* isim Foundation: NSObject root class, block classes, autorelease pool, NSLog & friends (MRC). */
#import <Foundation/Foundation.h>
#include <objc/isim_internal.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include <Block.h>
#include "isim_foundation.h"

@implementation NSObject
+ (void)load {}
+ (void)initialize {}
+ (instancetype)alloc { return [self allocWithZone:NULL]; }
+ (instancetype)allocWithZone:(NSZone *)zone { return class_createInstance(self, 0); }
+ (instancetype)new { return [[self alloc] init]; }
- (instancetype)init { return self; }
- (void)dealloc { object_dispose(self); }

- (instancetype)retain { return _objc_rootRetain(self); }
- (oneway void)release { _objc_rootRelease(self); }
- (instancetype)autorelease { return _objc_rootAutorelease(self); }
- (NSUInteger)retainCount { return _objc_rootRetainCount(self); }
- (NSZone *)zone { return NULL; }
+ (instancetype)retain { return (id)self; }
+ (oneway void)release {}
+ (instancetype)autorelease { return (id)self; }
+ (NSUInteger)retainCount { return NSUIntegerMax; }

- (Class)class { return object_getClass(self); }
+ (Class)class { return self; }
- (Class)superclass { return class_getSuperclass(object_getClass(self)); }
+ (Class)superclass { return class_getSuperclass(self); }
- (instancetype)self { return self; }
- (BOOL)isProxy { return NO; }
- (BOOL)isKindOfClass:(Class)cls {
    for (Class c = object_getClass(self); c; c = class_getSuperclass(c)) if (c == cls) return YES;
    return NO;
}
+ (BOOL)isKindOfClass:(Class)cls {
    for (Class c = object_getClass(self); c; c = class_getSuperclass(c)) if (c == cls) return YES;
    return NO;
}
- (BOOL)isMemberOfClass:(Class)cls { return object_getClass(self) == cls; }
+ (BOOL)isMemberOfClass:(Class)cls { return object_getClass(self) == cls; }
+ (BOOL)isSubclassOfClass:(Class)cls {
    for (Class c = self; c; c = class_getSuperclass(c)) if (c == cls) return YES;
    return NO;
}
- (BOOL)respondsToSelector:(SEL)sel { return class_respondsToSelector(object_getClass(self), sel); }
+ (BOOL)respondsToSelector:(SEL)sel { return class_respondsToSelector(object_getClass(self), sel); }
+ (BOOL)instancesRespondToSelector:(SEL)sel { return class_respondsToSelector(self, sel); }
- (BOOL)conformsToProtocol:(Protocol *)p { return [object_getClass(self) conformsToProtocol:p]; }
+ (BOOL)conformsToProtocol:(Protocol *)p {
    for (Class c = self; c; c = class_getSuperclass(c)) if (class_conformsToProtocol(c, p)) return YES;
    return NO;
}
- (IMP)methodForSelector:(SEL)sel { return class_getMethodImplementation(object_getClass(self), sel); }
- (void)doesNotRecognizeSelector:(SEL)sel {
    [NSException raise:NSInvalidArgumentException format:@"-[%s %s]: unrecognized selector sent to instance %p",
        object_getClassName(self), sel_getName(sel), self];
}
- (id)forwardingTargetForSelector:(SEL)sel { return nil; }

- (id)performSelector:(SEL)sel { return ((id (*)(id, SEL))[self methodForSelector:sel])(self, sel); }
- (id)performSelector:(SEL)sel withObject:(id)o { return ((id (*)(id, SEL, id))[self methodForSelector:sel])(self, sel, o); }
- (id)performSelector:(SEL)sel withObject:(id)a withObject:(id)b { return ((id (*)(id, SEL, id, id))[self methodForSelector:sel])(self, sel, a, b); }
- (void)performSelector:(SEL)sel withObject:(id)arg afterDelay:(NSTimeInterval)delay {
    isim_schedule_perform(self, sel, arg, delay);
}
- (void)performSelectorOnMainThread:(SEL)sel withObject:(id)arg waitUntilDone:(BOOL)wait {
    if (wait && pthread_main_np()) { [self performSelector:sel withObject:arg]; return; }
    isim_schedule_perform(self, sel, arg, 0);
}
+ (void)cancelPreviousPerformRequestsWithTarget:(id)target { isim_cancel_performs(target); }

- (BOOL)isEqual:(id)o { return self == o; }
- (NSUInteger)hash { return (NSUInteger)self; }
+ (NSUInteger)hash { return (NSUInteger)self; }
+ (BOOL)isEqual:(id)o { return self == o; }
- (NSString *)description { return [NSString stringWithFormat:@"<%s: %p>", object_getClassName(self), self]; }
+ (NSString *)description { return [NSString stringWithUTF8String:class_getName(self)]; }
- (NSString *)debugDescription { return [self description]; }
+ (NSString *)debugDescription { return [self description]; }
- (id)copy { return [(id<NSCopying>)self copyWithZone:NULL]; }
- (id)mutableCopy { return [(id<NSMutableCopying>)self mutableCopyWithZone:NULL]; }
+ (id)copyWithZone:(NSZone *)zone { return self; }
+ (id)copy { return self; }
@end

/* ---- blocks: libclosure isa storage is "class-ified" with these (see objc_rt.c) ---- */
@interface __NSBlockBase : NSObject @end
@implementation __NSBlockBase
- (id)copy { return _Block_copy(self); }
- (id)copyWithZone:(NSZone *)z { return _Block_copy(self); }
- (instancetype)retain { return _Block_copy(self); }
- (oneway void)release { _Block_release(self); }
- (instancetype)autorelease { return _objc_rootAutorelease(self); }
- (NSUInteger)retainCount { return 1; }
- (void)dealloc { }
@end
@interface __NSStackBlock__ : __NSBlockBase @end
@implementation __NSStackBlock__
- (instancetype)retain { return self; }          /* stack blocks are not refcounted */
- (oneway void)release {}
@end
@interface __NSMallocBlock__ : __NSBlockBase @end
@implementation __NSMallocBlock__ @end
@interface __NSGlobalBlock__ : __NSBlockBase @end
@implementation __NSGlobalBlock__
- (id)copy { return self; }
- (instancetype)retain { return self; }
- (oneway void)release {}
@end

@implementation NSAutoreleasePool { void *_token; }
- (instancetype)init { if ((self = [super init])) _token = objc_autoreleasePoolPush(); return self; }
- (void)drain { objc_autoreleasePoolPop(_token); object_dispose(self); }
- (oneway void)release { [self drain]; }
- (instancetype)retain { return self; }
@end

/* ---- functions ---- */
static pthread_mutex_t log_lock = PTHREAD_MUTEX_INITIALIZER;
void NSLogv(NSString *format, va_list args) {
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    time_t t = time(NULL); struct tm tm; localtime_r(&t, &tm);
    char ts[32]; strftime(ts, sizeof ts, "%Y-%m-%d %H:%M:%S", &tm);
    struct timespec now; clock_gettime(CLOCK_REALTIME, &now);
    const char *prog = isim_process_name();
    pthread_mutex_lock(&log_lock);
    fprintf(stderr, "%s.%03ld %s[%d:%lx] %s\n", ts, now.tv_nsec / 1000000, prog, getpid(),
            (unsigned long)(uintptr_t)pthread_self() & 0xffffff, [msg UTF8String]);
    fflush(stderr);
    pthread_mutex_unlock(&log_lock);
    [msg release];
}
void NSLog(NSString *format, ...) { va_list ap; va_start(ap, format); NSLogv(format, ap); va_end(ap); }

NSString *NSStringFromSelector(SEL s) { return s ? [NSString stringWithUTF8String:sel_getName(s)] : nil; }
SEL NSSelectorFromString(NSString *s) { return s ? sel_registerName([s UTF8String]) : NULL; }
/* Swift classes have mangled runtime names ("_TtC4main6Person"); Foundation shows them as "main.Person" */
static NSString *demangle_swift_class(const char *n) {
    if (strncmp(n, "_TtC", 4)) return nil;
    const char *p = n + 4; NSMutableArray *parts = [NSMutableArray array];
    while (*p >= '0' && *p <= '9') {
        long len = strtol(p, (char **)&p, 10);
        if (len <= 0 || (long)strlen(p) < len) return nil;
        [parts addObject:[[[NSString alloc] initWithBytes:p length:(NSUInteger)len encoding:NSUTF8StringEncoding] autorelease]];
        p += len;
        if (*p == 'C') p++;           /* nested class marker */
    }
    return *p == 0 && parts.count >= 2 ? [parts componentsJoinedByString:@"."] : nil;
}
NSString *NSStringFromClass(Class c) {
    if (!c) return nil;
    const char *n = class_getName(c);
    NSString *d = demangle_swift_class(n);
    return d ?: [NSString stringWithUTF8String:n];
}
Class NSClassFromString(NSString *s) {
    if (!s) return Nil;
    const char *n = [s UTF8String];
    Class c = objc_getClass(n);
    if (!c && strchr(n, '.')) {                   /* "Module.Class" -> Swift's mangled name, else the unqualified name */
        NSArray *parts = [s componentsSeparatedByString:@"."];
        NSMutableString *m = [NSMutableString stringWithString:@"_TtC"];
        for (NSUInteger i = 0; i < parts.count; i++) [m appendFormat:@"%s%lu%@", i > 1 ? "C" : "", (unsigned long)[parts[i] length], parts[i]];
        if (parts.count > 2) { m = [NSMutableString stringWithString:@"_TtC"]; for (NSUInteger i = 0; i < parts.count; i++) { if (i == 1) [m appendString:@""]; [m appendFormat:@"%lu%@", (unsigned long)[parts[i] length], parts[i]]; } [m insertString:[@"" stringByPaddingToLength:parts.count - 2 withString:@"C" startingAtIndex:0] atIndex:4]; }
        c = objc_getClass([m UTF8String]);
        if (!c) c = objc_getClass(strrchr(n, '.') + 1);
    }
    return c;
}
NSString *NSStringFromProtocol(Protocol *p) { return [NSString stringWithUTF8String:protocol_getName(p)]; }
NSString *NSStringFromRange(NSRange r) { return [NSString stringWithFormat:@"{%lu, %lu}", (unsigned long)r.location, (unsigned long)r.length]; }
NSString *NSStringFromCGPoint(CGPoint p) { return [NSString stringWithFormat:@"{%g, %g}", p.x, p.y]; }
NSString *NSStringFromCGSize(CGSize s) { return [NSString stringWithFormat:@"{%g, %g}", s.width, s.height]; }
NSString *NSStringFromCGRect(CGRect r) { return [NSString stringWithFormat:@"{{%g, %g}, {%g, %g}}", r.origin.x, r.origin.y, r.size.width, r.size.height]; }

/* ================= CoreFoundation memory functions =================
 * isim's CF types (CGColor, CTFont, ...) and the toll-free bridged ones are Objective-C objects. */
#include <CoreFoundation/CoreFoundation.h>
CFTypeRef CFRetain(CFTypeRef cf) { return cf ? (CFTypeRef)[(id)cf retain] : NULL; }
void CFRelease(CFTypeRef cf) { if (cf) [(id)cf release]; }
CFTypeRef CFAutorelease(CFTypeRef cf) { return cf ? (CFTypeRef)[(id)cf autorelease] : NULL; }
CFIndex CFGetRetainCount(CFTypeRef cf) { return cf ? (CFIndex)[(id)cf retainCount] : 0; }
Boolean CFEqual(CFTypeRef a, CFTypeRef b) { return a == b || (a && b && [(id)a isEqual:(id)b]); }
CFHashCode CFHash(CFTypeRef cf) { return cf ? [(id)cf hash] : 0; }
