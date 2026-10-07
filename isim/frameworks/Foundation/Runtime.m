/* isim Foundation (ARC): exceptions, bundle + plist, dates, run loop/timers, notifications,
 * process info, user defaults, libdispatch subset. */
#import <Foundation/Foundation.h>
#include <objc/isim_internal.h>
#include <objc/objc-exception.h>
#include <dlfcn.h>
#include <pthread.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <Block.h>
#include "isim_foundation.h"

extern int *_NSGetArgc(void);
extern char ***_NSGetArgv(void);
extern char ***_NSGetEnviron(void);
extern int _NSGetExecutablePath(char *buf, uint32_t *size);
extern long sysconf(int name);

static double wall_now(void) { struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts); return ts.tv_sec + ts.tv_nsec / 1e9; }
static double mono_now(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return ts.tv_sec + ts.tv_nsec / 1e9; }
#define REF_EPOCH 978307200.0   /* 2001-01-01 relative to 1970 */

/* ================= NSException ================= */
NSExceptionName const NSGenericException = @"NSGenericException";
NSExceptionName const NSRangeException = @"NSRangeException";
NSExceptionName const NSInvalidArgumentException = @"NSInvalidArgumentException";
NSExceptionName const NSInternalInconsistencyException = @"NSInternalInconsistencyException";

@interface NSException () { @public NSArray<NSNumber *> *_isimCallStack; } @end
/* exception preprocessor (libobjc): records the throw site's return addresses (frame pointer chain) */
static id isim_exception_preprocessor(id e) {
    if ([e isKindOfClass:[NSException class]] && !((NSException *)e)->_isimCallStack) {
        NSMutableArray *a = [NSMutableArray array];
        void **fp = __builtin_frame_address(0);
        for (int i = 0; i < 128 && fp && !((uintptr_t)fp & 7); i++) {
            void **next = fp[0]; void *ret = fp[1];
            if (!ret) break;
            [a addObject:@((uintptr_t)ret)];
            if (next <= fp) break;
            fp = next;
        }
        ((NSException *)e)->_isimCallStack = [a copy];
    }
    return e;
}
static NSUncaughtExceptionHandler *uncaught_handler;
NSUncaughtExceptionHandler *NSGetUncaughtExceptionHandler(void) { return uncaught_handler; }
void NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler *h) {
    uncaught_handler = h;
    objc_setUncaughtExceptionHandler((objc_uncaught_exception_handler)h);
}
__attribute__((constructor)) static void isim_install_exception_preprocessor(void) { objc_setExceptionPreprocessor(isim_exception_preprocessor); }

@implementation NSException
+ (NSException *)exceptionWithName:(NSExceptionName)n reason:(NSString *)r userInfo:(NSDictionary *)u { return [[self alloc] initWithName:n reason:r userInfo:u]; }
+ (void)raise:(NSExceptionName)name format:(NSString *)format arguments:(va_list)ap {
    [[self exceptionWithName:name reason:[[NSString alloc] initWithFormat:format arguments:ap] userInfo:nil] raise];
    __builtin_unreachable();
}
- (NSArray<NSNumber *> *)callStackReturnAddresses { return _isimCallStack ?: @[]; }
- (NSArray<NSString *> *)callStackSymbols {
    NSMutableArray *out = [NSMutableArray array];
    NSUInteger i = 0;
    for (NSNumber *n in self.callStackReturnAddresses) {
        Dl_info di; void *pc = (void *)(uintptr_t)n.unsignedLongValue;
        const char *img = "???", *sym = NULL; uintptr_t off = 0;
        if (dladdr(pc, &di)) {
            if (di.dli_fname) { const char *b = strrchr(di.dli_fname, '/'); img = b ? b + 1 : di.dli_fname; }
            if (di.dli_sname) { sym = di.dli_sname; off = (uintptr_t)pc - (uintptr_t)di.dli_saddr; }
        }
        [out addObject:sym ? [NSString stringWithFormat:@"%-3lu %-35s 0x%016lx %s + %lu", (unsigned long)i, img, (unsigned long)(uintptr_t)pc, sym, (unsigned long)off]
                           : [NSString stringWithFormat:@"%-3lu %-35s 0x%016lx", (unsigned long)i, img, (unsigned long)(uintptr_t)pc]];
        i++;
    }
    return out;
}
- (instancetype)initWithName:(NSExceptionName)n reason:(NSString *)r userInfo:(NSDictionary *)u {
    if ((self = [super init])) { _name = [n copy]; _reason = [r copy]; _userInfo = [u copy]; }
    return self;
}
- (void)raise { objc_exception_throw(self); }
+ (void)raise:(NSExceptionName)name format:(NSString *)format, ... {
    va_list ap; va_start(ap, format);
    NSString *reason = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    [[self exceptionWithName:name reason:reason userInfo:nil] raise];
    __builtin_unreachable();
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"%@: %@", _name, _reason]; }
@end

/* property lists: PropertyList.m (isim_plist_parse) */

/* ================= NSBundle ================= */
/* bundles of app extensions loaded into this process (isim hosts custom keyboards in-process):
 * their code asks Bundle.main for its strings, so the main bundle falls back to them */
static NSMutableArray<NSBundle *> *extension_bundles;
@interface NSBundle (IsimLookup)
- (NSString *)_isim_lookup:(NSString *)key table:(NSString *)t;
@end
@implementation NSBundle { NSString *_path; NSDictionary *_info; NSMutableDictionary *_tables; }
+ (NSBundle *)mainBundle {
    static NSBundle *main;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        char buf[4096]; uint32_t size = sizeof buf;
        NSString *exe = _NSGetExecutablePath(buf, &size) == 0 ? @(buf) : @".";
        main = [[NSBundle alloc] init];
        main->_path = [exe stringByDeletingLastPathComponent];
    });
    return main;
}
+ (instancetype)bundleWithPath:(NSString *)path { return [[self alloc] initWithPath:path]; }
- (instancetype)initWithPath:(NSString *)path {
    BOOL dir = NO;
    if (!path || ![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&dir] || !dir) return nil;
    if ((self = [super init])) _path = [path copy];
    return self;
}
/* the bundle whose executable contains the class's code (app, or an extension loaded in-process) */
+ (NSBundle *)bundleForClass:(Class)cls {
    Dl_info di;
    if (cls && dladdr((__bridge void *)cls, &di) && di.dli_fname) {
        NSString *dir = [@(di.dli_fname) stringByDeletingLastPathComponent];
        if ([dir isEqualToString:NSBundle.mainBundle.bundlePath]) return NSBundle.mainBundle;
        if ([dir hasSuffix:@".appex"] || [dir hasSuffix:@".bundle"] || [dir hasSuffix:@".app"]) return [NSBundle bundleWithPath:dir] ?: NSBundle.mainBundle;
    }
    return NSBundle.mainBundle;
}
+ (NSBundle *)bundleWithIdentifier:(NSString *)ident {
    if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:ident]) return NSBundle.mainBundle;
    for (NSBundle *b in extension_bundles) if ([b.bundleIdentifier isEqualToString:ident]) return b;
    return nil;
}
- (NSString *)builtInPlugInsPath { return [_path stringByAppendingPathComponent:@"PlugIns"]; }
- (NSString *)bundlePath { return _path; }
- (NSString *)resourcePath { return _path; }
- (NSString *)executablePath {
    NSString *name = self.infoDictionary[@"CFBundleExecutable"];
    return name ? [_path stringByAppendingPathComponent:name] : nil;
}
- (NSDictionary *)infoDictionary {
    if (!_info) _info = [NSDictionary dictionaryWithContentsOfFile:[_path stringByAppendingPathComponent:@"Info.plist"]] ?: @{};
    return _info;
}
/* like iOS: values localized in <lang>.lproj/InfoPlist.strings win (e.g. CFBundleDisplayName) */
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (!key) return nil;
    NSString *loc = [self _isim_lookup:key table:@"InfoPlist"];
    return loc ?: self.infoDictionary[key];
}
- (NSDictionary *)localizedInfoDictionary {
    NSMutableDictionary *d = [self.infoDictionary mutableCopy];
    for (NSString *k in self.infoDictionary) { NSString *loc = [self _isim_lookup:k table:@"InfoPlist"]; if (loc) d[k] = loc; }
    return d;
}
- (NSString *)bundleIdentifier { return self.infoDictionary[@"CFBundleIdentifier"]; }
- (NSArray<NSString *> *)localizations {
    NSMutableArray *out = [NSMutableArray array];
    NSArray *declared = self.infoDictionary[@"CFBundleLocalizations"];
    NSMutableArray *candidates = [NSMutableArray arrayWithArray:declared ?: @[]];
    for (NSString *l in isim_preferred_languages()) { [candidates addObject:l]; [candidates addObject:[l componentsSeparatedByString:@"-"].firstObject]; }
    for (NSString *c in @[@"Base", @"en"]) [candidates addObject:c];
    if (self.developmentLocalization) [candidates addObject:self.developmentLocalization];
    for (NSString *c in candidates) {
        if ([out containsObject:c]) continue;
        NSString *dir = [_path stringByAppendingPathComponent:[c stringByAppendingString:@".lproj"]];
        if (access(dir.UTF8String, R_OK) == 0) [out addObject:c];
    }
    return out;
}
- (NSString *)developmentLocalization { return self.infoDictionary[@"CFBundleDevelopmentRegion"] ?: @"en"; }
/* Matches preferred languages against available localizations the way iOS does in spirit:
 * exact match ("pt-BR"), then language-only ("pt"), then a same-language variant ("pt-PT"). */
+ (NSArray<NSString *> *)preferredLocalizationsFromArray:(NSArray<NSString *> *)available {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *pref in isim_preferred_languages()) {
        NSString *lang = [pref componentsSeparatedByString:@"-"].firstObject;
        NSString *hit = nil;
        for (NSString *a in available) if ([a caseInsensitiveCompare:pref] == NSOrderedSame || [[a stringByReplacingOccurrencesOfString:@"_" withString:@"-"] caseInsensitiveCompare:pref] == NSOrderedSame) hit = a;
        if (!hit) for (NSString *a in available) if ([a isEqualToString:lang]) hit = a;
        if (!hit) for (NSString *a in available) if ([a hasPrefix:[lang stringByAppendingString:@"-"]] || [a hasPrefix:[lang stringByAppendingString:@"_"]]) { hit = a; break; }
        if (hit) { [out addObject:hit]; break; }
    }
    return out;
}
- (NSArray<NSString *> *)preferredLocalizations {
    NSMutableArray *avail = [NSMutableArray array];
    for (NSString *l in self.localizations) if (![l isEqualToString:@"Base"]) [avail addObject:l];
    NSArray *pref = [NSBundle preferredLocalizationsFromArray:avail];
    if (pref.count) return pref;
    return avail.count ? @[[avail containsObject:self.developmentLocalization] ? self.developmentLocalization : avail.firstObject] : @[self.developmentLocalization];
}
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext inDirectory:(NSString *)sub forLocalization:(NSString *)loc {
    NSString *file = ext.length ? [name stringByAppendingPathExtension:ext] : name;
    NSString *dir = sub.length ? [_path stringByAppendingPathComponent:sub] : _path;
    NSString *p = [(loc ? [dir stringByAppendingPathComponent:[loc stringByAppendingString:@".lproj"]] : dir) stringByAppendingPathComponent:file];
    return access(p.UTF8String, R_OK) == 0 ? p : nil;
}
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext {
    NSString *p = [self pathForResource:name ofType:ext inDirectory:nil forLocalization:nil];
    if (p) return p;
    for (NSString *loc in [self.preferredLocalizations arrayByAddingObjectsFromArray:@[@"Base", self.developmentLocalization]])
        if ((p = [self pathForResource:name ofType:ext inDirectory:nil forLocalization:loc])) return p;
    return nil;
}
void isim_bundle_register_extension(NSString *path) {
    NSBundle *b = [NSBundle bundleWithPath:path];
    if (!b) return;
    @synchronized ([NSBundle class]) { if (!extension_bundles) extension_bundles = [NSMutableArray array]; [extension_bundles addObject:b]; }
}
- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)t {
    if (!key) return value ?: @"";
    NSString *hit = [self _isim_lookup:key table:t];
    if (!hit && self == NSBundle.mainBundle) {
        NSArray *exts; @synchronized ([NSBundle class]) { exts = [extension_bundles copy]; }
        for (NSBundle *b in exts) if ((hit = [b _isim_lookup:key table:t])) break;
    }
    return hit ?: (value.length ? value : key);
}
- (NSString *)_isim_lookup:(NSString *)key table:(NSString *)t {
    NSString *table = t.length ? t : @"Localizable";
    @synchronized (self) {
        if (!_tables) _tables = [NSMutableDictionary dictionary];
        for (NSString *loc in [self.preferredLocalizations arrayByAddingObject:self.developmentLocalization]) {
            NSString *cacheKey = [NSString stringWithFormat:@"%@/%@", loc, table];
            NSDictionary *strings = _tables[cacheKey];
            if (!strings) {
                NSString *path = [self pathForResource:table ofType:@"strings" inDirectory:nil forLocalization:loc];
                strings = (path ? isim_parse_strings_file(path) : nil) ?: @{};
                _tables[cacheKey] = strings;
            }
            NSString *hit = strings[key];
            if (hit) return hit;
        }
    }
    return nil;
}
@end

/* ================= NSDate ================= */
@implementation NSDate { NSTimeInterval _t; }
+ (NSTimeInterval)timeIntervalSinceReferenceDate_isim { return wall_now() - REF_EPOCH; }
+ (instancetype)date { return [[self alloc] initWithTimeIntervalSinceReferenceDate:wall_now() - REF_EPOCH]; }
+ (instancetype)dateWithTimeIntervalSinceNow:(NSTimeInterval)s { return [[self alloc] initWithTimeIntervalSinceReferenceDate:wall_now() - REF_EPOCH + s]; }
+ (instancetype)dateWithTimeIntervalSince1970:(NSTimeInterval)s { return [[self alloc] initWithTimeIntervalSinceReferenceDate:s - REF_EPOCH]; }
+ (NSDate *)distantFuture { return [[self alloc] initWithTimeIntervalSinceReferenceDate:63113904000.0]; }
+ (NSDate *)distantPast { return [[self alloc] initWithTimeIntervalSinceReferenceDate:-63114076800.0]; }
- (instancetype)init { return [self initWithTimeIntervalSinceReferenceDate:wall_now() - REF_EPOCH]; }
- (instancetype)initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)t { if ((self = [super init])) _t = t; return self; }
- (NSTimeInterval)timeIntervalSinceReferenceDate { return _t; }
- (NSTimeInterval)timeIntervalSince1970 { return _t + REF_EPOCH; }
- (NSTimeInterval)timeIntervalSinceNow { return _t - (wall_now() - REF_EPOCH); }
- (NSTimeInterval)timeIntervalSinceDate:(NSDate *)d { return _t - d.timeIntervalSinceReferenceDate; }
- (NSDate *)dateByAddingTimeInterval:(NSTimeInterval)ti { return [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:_t + ti]; }
- (NSComparisonResult)compare:(NSDate *)o { NSTimeInterval b = o.timeIntervalSinceReferenceDate; return _t < b ? NSOrderedAscending : _t > b ? NSOrderedDescending : NSOrderedSame; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSDate class]] && [self compare:o] == NSOrderedSame; }
- (NSUInteger)hash { return (NSUInteger)_t; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description {
    time_t s = (time_t)(_t + REF_EPOCH); struct tm tm; gmtime_r(&s, &tm);
    char b[64]; strftime(b, sizeof b, "%Y-%m-%d %H:%M:%S +0000", &tm);
    return @(b);
}
@end

/* ================= run loop: timers, delayed performs, main-queue blocks ================= */
@interface __IsimRunLoopItem : NSObject
@property double fireAt, interval;
@property BOOL repeats, valid;
@property (copy) void (^block)(void);
@property (strong) id target, arg;
@property SEL sel;
@property (weak) NSTimer *timer;
@property (strong) NSTimer *scheduled;     /* the run loop keeps a scheduled timer alive until it is invalidated */
@end
@implementation __IsimRunLoopItem @end

static pthread_mutex_t rl_lock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableArray<__IsimRunLoopItem *> *rl_items;

static pthread_cond_t rl_cond = PTHREAD_COND_INITIALIZER;
void (*isim_main_wakeup_hook)(void);      /* set by UIKit: wakes the UI event loop */
static void rl_add(__IsimRunLoopItem *it) {
    pthread_mutex_lock(&rl_lock);
    if (!rl_items) rl_items = [NSMutableArray array];
    it.valid = YES;
    [rl_items addObject:it];
    pthread_cond_broadcast(&rl_cond);
    pthread_mutex_unlock(&rl_lock);
    if (!pthread_main_np() && isim_main_wakeup_hook) isim_main_wakeup_hook();
}
void isim_schedule_perform(id target, SEL sel, id arg, NSTimeInterval delay) {
    __IsimRunLoopItem *it = [__IsimRunLoopItem new];
    it.fireAt = mono_now() + delay; it.target = target; it.sel = sel; it.arg = arg;
    rl_add(it);
}
void isim_cancel_performs(id target) {
    pthread_mutex_lock(&rl_lock);
    for (__IsimRunLoopItem *it in [rl_items copy]) if (it.target == target && !it.timer) { it.valid = NO; [rl_items removeObject:it]; }
    pthread_mutex_unlock(&rl_lock);
}
static void rl_add_block(double delay, dispatch_block_t block) {
    __IsimRunLoopItem *it = [__IsimRunLoopItem new];
    it.fireAt = mono_now() + delay; it.block = block;
    rl_add(it);
}

/* main-queue services for the dispatch implementation (Dispatch.mrc.m) */
void isim_main_enqueue_f(double delay, void (*f)(void *), void *ctx) { rl_add_block(delay, ^{ f(ctx); }); }
double isim_main_fire_due(void) { return [NSRunLoop.mainRunLoop _isim_fireDue]; }
/* seconds until the next main run loop item is due (0 if one is due now) without firing anything */
double isim_main_next_due(void) {
    double next = 1e9, now = mono_now();
    pthread_mutex_lock(&rl_lock);
    for (__IsimRunLoopItem *it in rl_items) if (it.fireAt - now < next) next = it.fireAt - now;
    pthread_mutex_unlock(&rl_lock);
    return next < 0 ? 0 : next;
}
void isim_main_wait(double seconds) {
    if (seconds <= 0) return;
    struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
    double t = ts.tv_sec + ts.tv_nsec / 1e9 + seconds;
    ts.tv_sec = (time_t)t; ts.tv_nsec = (long)((t - (double)ts.tv_sec) * 1e9);
    pthread_mutex_lock(&rl_lock);
    BOOL due = NO; double now = mono_now();
    for (__IsimRunLoopItem *it in rl_items) if (it.fireAt <= now) { due = YES; break; }
    if (!due) pthread_cond_timedwait(&rl_cond, &rl_lock, &ts);
    pthread_mutex_unlock(&rl_lock);
}

@interface NSTimer ()
@property (strong) __IsimRunLoopItem *item;
@property (copy) void (^timerBlock)(NSTimer *);
@property (strong) id target;
@property SEL selector;
@end
@implementation NSTimer
+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)i repeats:(BOOL)r block:(void (^)(NSTimer *))block {
    NSTimer *t = [NSTimer new];
    t->_timeInterval = i; t.timerBlock = block;
    __IsimRunLoopItem *it = [__IsimRunLoopItem new];
    it.interval = i > 0.0001 ? i : 0.0001; it.repeats = r; it.timer = t;
    t.item = it;
    return t;
}
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)i repeats:(BOOL)r block:(void (^)(NSTimer *))block {
    NSTimer *t = [self timerWithTimeInterval:i repeats:r block:block];
    [[NSRunLoop mainRunLoop] addTimer:t forMode:NSDefaultRunLoopMode];
    return t;
}
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)i target:(id)target selector:(SEL)sel userInfo:(id)info repeats:(BOOL)r {
    NSTimer *t = [self timerWithTimeInterval:i repeats:r block:nil];
    t.target = target; t.selector = sel; t->_userInfo = info;
    [[NSRunLoop mainRunLoop] addTimer:t forMode:NSDefaultRunLoopMode];
    return t;
}
- (void)fire {
    if (self.timerBlock) self.timerBlock(self);
    else if (self.target) ((void (*)(id, SEL, id))[self.target methodForSelector:self.selector])(self.target, self.selector, self);
}
- (void)invalidate {
    pthread_mutex_lock(&rl_lock);
    self.item.valid = NO;
    [rl_items removeObject:self.item];
    pthread_mutex_unlock(&rl_lock);
    self.item.scheduled = nil;
    self.target = nil; self.timerBlock = nil;
}
- (BOOL)isValid { return self.item.valid; }
- (NSDate *)fireDate { return [NSDate dateWithTimeIntervalSinceNow:self.item.fireAt - mono_now()]; }
- (void)setFireDate:(NSDate *)d { self.item.fireAt = mono_now() + d.timeIntervalSinceNow; }
@end

NSRunLoopMode const NSDefaultRunLoopMode = @"kCFRunLoopDefaultMode";
NSRunLoopMode const NSRunLoopCommonModes = @"kCFRunLoopCommonModes";

@implementation NSRunLoop
+ (NSRunLoop *)mainRunLoop { static NSRunLoop *rl; static dispatch_once_t o; dispatch_once(&o, ^{ rl = [NSRunLoop new]; }); return rl; }
+ (NSRunLoop *)currentRunLoop { return [self mainRunLoop]; }   /* isim: one (main) run loop */
- (void)addTimer:(NSTimer *)t forMode:(NSRunLoopMode)mode {
    t.item.fireAt = mono_now() + t.item.interval;
    t.item.scheduled = t;
    rl_add(t.item);
}
- (NSTimeInterval)_isim_fireDue {
    double now = mono_now();
    NSMutableArray *due = [NSMutableArray array];
    pthread_mutex_lock(&rl_lock);
    for (__IsimRunLoopItem *it in rl_items) if (it.fireAt <= now) [due addObject:it];
    for (__IsimRunLoopItem *it in due) {
        if (it.repeats) { it.fireAt += it.interval; if (it.fireAt < now) it.fireAt = now + it.interval; }
        else [rl_items removeObject:it];
    }
    pthread_mutex_unlock(&rl_lock);
    for (__IsimRunLoopItem *it in due) {
        @autoreleasepool {
            if (!it.valid) continue;
            if (!it.repeats) it.valid = NO;
            if (it.timer) { NSTimer *t = it.timer; [t fire]; if (!it.repeats) it.scheduled = nil; }
            else if (it.block) it.block();
            else if (it.target) ((void (*)(id, SEL, id))[it.target methodForSelector:it.sel])(it.target, it.sel, it.arg);
        }
    }
    double next = 1e9;
    pthread_mutex_lock(&rl_lock);
    for (__IsimRunLoopItem *it in rl_items) if (it.fireAt - mono_now() < next) next = it.fireAt - mono_now();
    pthread_mutex_unlock(&rl_lock);
    return next < 0 ? 0 : next;
}
- (void)runUntilDate:(NSDate *)limit {
    for (;;) {
        double left = limit.timeIntervalSinceNow;
        if (left <= 0) return;
        double next = [self _isim_fireDue];
        double s = next < left ? next : left;
        if (s > 0.05) s = 0.05;
        struct timespec ts = { 0, (long)(s * 1e9) }; nanosleep(&ts, NULL);
    }
}
- (void)run { [self runUntilDate:[NSDate distantFuture]]; }
@end

/* ================= NSNotificationCenter ================= */
@implementation NSNotification
+ (instancetype)notificationWithName:(NSNotificationName)n object:(id)o userInfo:(NSDictionary *)u {
    NSNotification *x = [self new]; x->_name = [n copy]; x->_object = o; x->_userInfo = [u copy]; return x;
}
- (id)copyWithZone:(NSZone *)z { return self; }
@end

@interface __IsimObserver : NSObject
@property (weak) id observer;
@property SEL sel;
@property (copy) NSString *name;
@property (weak) id object;
@property BOOL hasObject;
@property (copy) void (^block)(NSNotification *);
@end
@implementation __IsimObserver @end

@implementation NSNotificationCenter { NSMutableArray<__IsimObserver *> *_obs; }
+ (NSNotificationCenter *)defaultCenter { static NSNotificationCenter *c; static dispatch_once_t o; dispatch_once(&o, ^{ c = [NSNotificationCenter new]; }); return c; }
- (instancetype)init { if ((self = [super init])) _obs = [NSMutableArray array]; return self; }
- (void)addObserver:(id)observer selector:(SEL)sel name:(NSNotificationName)name object:(id)obj {
    __IsimObserver *o = [__IsimObserver new];
    o.observer = observer; o.sel = sel; o.name = name; o.object = obj; o.hasObject = obj != nil;
    @synchronized (self) { [_obs addObject:o]; }
}
- (id<NSObject>)addObserverForName:(NSNotificationName)name object:(id)obj queue:(NSOperationQueue *)q usingBlock:(void (^)(NSNotification *))block {
    __IsimObserver *o = [__IsimObserver new];
    o.name = name; o.object = obj; o.hasObject = obj != nil; o.observer = o;
    o.block = q ? ^(NSNotification *n) { if (q == NSOperationQueue.currentQueue) block(n); else [q addOperationWithBlock:^{ block(n); }]; } : block;
    @synchronized (self) { [_obs addObject:o]; }
    return o;
}
- (void)postNotification:(NSNotification *)n {
    NSArray *snapshot; @synchronized (self) { snapshot = [_obs copy]; }
    for (__IsimObserver *o in snapshot) {
        if (o.name && ![o.name isEqualToString:n.name]) continue;
        if (o.hasObject && o.object != n.object) continue;
        if (o.block) o.block(n);
        else { id target = o.observer; if (target) ((void (*)(id, SEL, id))[target methodForSelector:o.sel])(target, o.sel, n); }
    }
}
- (void)postNotificationName:(NSNotificationName)name object:(id)obj { [self postNotificationName:name object:obj userInfo:nil]; }
- (void)postNotificationName:(NSNotificationName)name object:(id)obj userInfo:(NSDictionary *)u {
    [self postNotification:[NSNotification notificationWithName:name object:obj userInfo:u]];
}
- (void)removeObserver:(id)observer { [self removeObserver:observer name:nil object:nil]; }
- (void)removeObserver:(id)observer name:(NSNotificationName)name object:(id)obj {
    @synchronized (self) {
        for (__IsimObserver *o in [_obs copy]) {
            if (o.observer != observer && o != observer) continue;
            if (name && ![o.name isEqualToString:name]) continue;
            if (obj && o.object != obj) continue;
            [_obs removeObject:o];
        }
    }
}
@end

/* ================= NSProcessInfo / NSUserDefaults ================= */
const char *isim_process_name(void) {
    static char name[256];
    if (!name[0]) { char **argv = *_NSGetArgv(); const char *s = argv && argv[0] ? argv[0] : "app"; const char *b = strrchr(s, '/'); snprintf(name, sizeof name, "%s", b ? b + 1 : s); }
    return name;
}
@implementation NSProcessInfo
+ (NSProcessInfo *)processInfo { static NSProcessInfo *p; static dispatch_once_t o; dispatch_once(&o, ^{ p = [NSProcessInfo new]; p.processName = @(isim_process_name()); }); return p; }
- (NSArray<NSString *> *)arguments {
    NSMutableArray *a = [NSMutableArray array];
    int argc = *_NSGetArgc(); char **argv = *_NSGetArgv();
    for (int i = 0; i < argc; i++) [a addObject:@(argv[i])];
    return a;
}
- (NSDictionary<NSString *, NSString *> *)environment {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (char **e = *_NSGetEnviron(); e && *e; e++) {
        const char *eq = strchr(*e, '=');
        if (!eq) continue;
        NSString *k = [[NSString alloc] initWithBytes:*e length:(NSUInteger)(eq - *e) encoding:NSUTF8StringEncoding];
        d[k] = @(eq + 1);
    }
    return d;
}
- (int)processIdentifier { return getpid(); }
- (NSUInteger)processorCount { return (NSUInteger)sysconf(58 /* Darwin _SC_NPROCESSORS_ONLN */); }
- (NSTimeInterval)systemUptime { return mono_now(); }
@end

/* System-wide preferences (the global domain, ".GlobalPreferences"): written by the Settings app,
 * read by every app (languages, region, appearance, keyboards, ...). Environment variables win. */
NSString *const NSGlobalDomain = @"NSGlobalDomain";
extern NSString *isim_data_dir(void);
static NSString *global_prefs_path(void) {
    return [isim_data_dir() stringByAppendingPathComponent:@"Library/Preferences/.GlobalPreferences.plist"];
}
NSDictionary *isim_global_preferences(void) {
    static NSDictionary *cache; static struct timespec mtime; static pthread_mutex_t lk = PTHREAD_MUTEX_INITIALIZER;
    struct stat st;
    pthread_mutex_lock(&lk);
    if (stat(global_prefs_path().UTF8String, &st) != 0) { cache = @{}; mtime = (struct timespec){ 0, 0 }; }
    else if (!cache || st.st_mtimespec.tv_sec != mtime.tv_sec || st.st_mtimespec.tv_nsec != mtime.tv_nsec) {
        cache = [NSDictionary dictionaryWithContentsOfFile:global_prefs_path()] ?: @{};
        mtime = st.st_mtimespec;
    }
    NSDictionary *d = cache;
    pthread_mutex_unlock(&lk);
    return d;
}
static void mkdir_p(NSString *dir) {
    char buf[4096]; snprintf(buf, sizeof buf, "%s", dir.UTF8String);
    for (char *p = buf + 1; *p; p++) if (*p == '/') { *p = 0; mkdir(buf, 0755); *p = '/'; }
    mkdir(buf, 0755);
}

@implementation NSUserDefaults { NSMutableDictionary *_d; NSString *_file; BOOL _global, _standard; }
+ (NSUserDefaults *)standardUserDefaults {
    static NSUserDefaults *u; static dispatch_once_t o;
    dispatch_once(&o, ^{ u = [NSUserDefaults new]; u->_standard = YES; });
    return u;
}
- (instancetype)init {
    if ((self = [super init])) {
        NSString *ident = NSBundle.mainBundle.bundleIdentifier ?: @(isim_process_name());
        _file = [NSString stringWithFormat:@"%@/Library/Preferences/%@.plist", NSHomeDirectory(), ident];
        _d = [[NSDictionary dictionaryWithContentsOfFile:_file] mutableCopy] ?: [NSMutableDictionary dictionary];
    }
    return self;
}
/* suites: ".GlobalPreferences" / NSGlobalDomain is the system domain; other names are shared (app group) domains */
- (instancetype)initWithSuiteName:(NSString *)suite {
    if (!suite.length || [suite isEqualToString:NSBundle.mainBundle.bundleIdentifier]) return [self init];
    if ((self = [super init])) {
        _global = [suite isEqualToString:@".GlobalPreferences"] || [suite isEqualToString:NSGlobalDomain];
        _file = _global ? global_prefs_path()
                        : [NSString stringWithFormat:@"%@/Shared/AppGroup/%@/Library/Preferences/%@.plist", isim_data_dir(), suite, suite];
        mkdir_p(_file.stringByDeletingLastPathComponent);
        _d = [[NSDictionary dictionaryWithContentsOfFile:_file] mutableCopy] ?: [NSMutableDictionary dictionary];
    }
    return self;
}
/* re-read the domain from disk (the Settings app writes an app's Settings.bundle values there); YES if it changed */
- (BOOL)_isim_reloadFromDisk {
    NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:_file] ?: @{};
    @synchronized (self) {
        if ([disk isEqualToDictionary:_d]) return NO;
        _d = [disk mutableCopy];
    }
    return YES;
}
- (void)_save {
    [isim_plist_xml(_d) writeToFile:_file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    if (_global) dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimGlobalPreferencesChanged" object:nil];
    });
}
/* NSArgumentDomain: "-key value" launch arguments override everything (as on iOS; e.g. Xcode scheme arguments) */
static NSDictionary *argument_domain(void) {
    static NSDictionary *args; static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        NSArray *a = NSProcessInfo.processInfo.arguments;
        for (NSUInteger i = 1; i + 1 < a.count; i++) {
            NSString *k = a[i];
            if (k.length > 1 && [k hasPrefix:@"-"] && ![k hasPrefix:@"--"]) { d[[k substringFromIndex:1]] = a[i + 1]; i++; }
        }
        args = [d copy];
    });
    return args;
}
- (id)objectForKey:(NSString *)k {
    id v = _standard ? argument_domain()[k] : nil;
    if (v) return v;
    @synchronized (self) { v = _d[k]; }
    if (!v && _standard) v = isim_global_preferences()[k];        /* search list: app domain, then global domain */
    return v;
}
- (void)setObject:(id)v forKey:(NSString *)k { @synchronized (self) { if (v) _d[k] = v; else [_d removeObjectForKey:k]; [self _save]; } }
- (void)removeObjectForKey:(NSString *)k { @synchronized (self) { [_d removeObjectForKey:k]; [self _save]; } }
- (NSDictionary *)dictionaryRepresentation { @synchronized (self) { return [_d copy]; } }
- (NSInteger)integerForKey:(NSString *)k { return [[self objectForKey:k] integerValue]; }
- (void)setInteger:(NSInteger)v forKey:(NSString *)k { [self setObject:@(v) forKey:k]; }
- (BOOL)boolForKey:(NSString *)k { return [[self objectForKey:k] boolValue]; }
- (void)setBool:(BOOL)v forKey:(NSString *)k { [self setObject:@(v) forKey:k]; }
- (NSString *)stringForKey:(NSString *)k { id v = [self objectForKey:k]; return [v isKindOfClass:[NSString class]] ? v : nil; }
- (double)doubleForKey:(NSString *)k { return [[self objectForKey:k] doubleValue]; }
- (void)setDouble:(double)v forKey:(NSString *)k { [self setObject:@(v) forKey:k]; }
- (NSArray *)arrayForKey:(NSString *)k { id v = [self objectForKey:k]; return [v isKindOfClass:[NSArray class]] ? v : nil; }
- (NSDictionary *)dictionaryForKey:(NSString *)k { id v = [self objectForKey:k]; return [v isKindOfClass:[NSDictionary class]] ? v : nil; }
- (void)registerDefaults:(NSDictionary *)defaults { @synchronized (self) { for (NSString *k in defaults) if (!_d[k]) _d[k] = defaults[k]; } }
- (BOOL)synchronize { @synchronized (self) { [self _save]; } return YES; }
@end

/* ================= NSError ================= */
NSErrorDomain const NSCocoaErrorDomain = @"NSCocoaErrorDomain";
NSErrorDomain const NSPOSIXErrorDomain = @"NSPOSIXErrorDomain";
NSErrorDomain const NSOSStatusErrorDomain = @"NSOSStatusErrorDomain";
NSErrorUserInfoKey const NSLocalizedDescriptionKey = @"NSLocalizedDescription";
NSErrorUserInfoKey const NSUnderlyingErrorKey = @"NSUnderlyingError";
NSErrorUserInfoKey const NSLocalizedFailureReasonErrorKey = @"NSLocalizedFailureReason";
@implementation NSError
+ (instancetype)errorWithDomain:(NSErrorDomain)d code:(NSInteger)c userInfo:(NSDictionary *)u { return [[self alloc] initWithDomain:d code:c userInfo:u]; }
- (instancetype)initWithDomain:(NSErrorDomain)d code:(NSInteger)c userInfo:(NSDictionary *)u {
    if ((self = [super init])) { _domain = [d copy]; _code = c; _userInfo = [u copy] ?: @{}; }
    return self;
}
/* through the accessors: the Swift runtime's NSError subclass for bridged Swift errors overrides them */
- (NSString *)localizedDescription {
    NSString *s = self.userInfo[NSLocalizedDescriptionKey];
    return s ?: [NSString stringWithFormat:@"The operation couldn’t be completed. (%@ error %ld.)", self.domain, (long)self.code];
}
- (NSString *)localizedFailureReason { return self.userInfo[NSLocalizedFailureReasonErrorKey]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"Error Domain=%@ Code=%ld \"%@\"", self.domain, (long)self.code, self.localizedDescription]; }
@end

/* NSCoder: Archiver.m */

/* function-pointer variants (used by C/C++ clients such as the Swift runtime) */

/* CGColor objects (CoreGraphics allocates these so CGColorRef is retainable by ARC/Swift).
 * Layout must match struct CGColor in CoreGraphics.c: isa, 4 components, refs. */
@interface __NSCGColor : NSObject { @public CGFloat _c[4]; int _refs; int _space; CGFloat _comp[5]; void *_pattern; }
@end
@implementation __NSCGColor
- (void)dealloc { if (_pattern) CFRelease(_pattern); }
- (NSString *)description { return [NSString stringWithFormat:@"<CGColor %p> [%g %g %g %g]", self, _c[0], _c[1], _c[2], _c[3]]; }
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass:[__NSCGColor class]] && !memcmp(_c, ((__NSCGColor *)o)->_c, sizeof _c)); }
- (NSUInteger)hash { return (NSUInteger)(_c[0] * 255) << 24 ^ (NSUInteger)(_c[1] * 255) << 16 ^ (NSUInteger)(_c[2] * 255) << 8 ^ (NSUInteger)(_c[3] * 255); }
@end

/* CGPath / CGImage / CGContext objects (allocated by CoreGraphics; layouts must match CoreGraphics.c) */
@interface __NSCGPath : NSObject { @public void *_els; long _count, _cap; }
@end
@implementation __NSCGPath
- (void)dealloc { free(_els); }
- (NSString *)description { return [NSString stringWithFormat:@"<CGPath %p> %ld elements", self, _count]; }
@end
@interface __NSCGImage : NSObject { @public int _handle; double _x, _y, _w, _h; void *_owner; void *_ext; }
@end
@implementation __NSCGImage
- (void)dealloc { if (_owner) CFRelease(_owner); if (_ext) CFRelease(_ext); }
- (NSString *)description { return [NSString stringWithFormat:@"<CGImage %p> (%g x %g)", self, _w, _h]; }
@end
@interface __NSCGContext : NSObject { @public void (*_fin)(void *); }
@end
@implementation __NSCGContext
- (void)dealloc { if (_fin) _fin((__bridge void *)self); }
@end
/* other Core Graphics / ImageIO objects (color spaces, data providers, gradients, ...): a finalizer + private storage */
@interface __NSCGObject : NSObject { @public void (*_fin)(void *); const char *_kind; }
@end
@implementation __NSCGObject
- (void)dealloc { if (_fin) _fin((__bridge void *)self); }
- (NSString *)description { return [NSString stringWithFormat:@"<%s %p>", _kind ?: "CGObject", self]; }
@end

/* NSThread: identity objects for the calling pthread (one per thread, via a key) */
static pthread_key_t thread_key;
static NSThread *main_thread_obj;
static void thread_obj_release(void *p) { NSThread *t = (__bridge_transfer NSThread *)p; (void)t; }
@implementation NSThread
+ (void)initialize { if (self == [NSThread class]) pthread_key_create(&thread_key, thread_obj_release); }
+ (BOOL)isMainThread { return pthread_main_np() != 0; }
- (BOOL)isMainThread { return self == main_thread_obj; }
+ (NSThread *)currentThread {
    if (pthread_main_np()) return [self mainThread];
    NSThread *t = (__bridge NSThread *)pthread_getspecific(thread_key);
    if (!t) { t = [NSThread new]; pthread_setspecific(thread_key, (__bridge_retained void *)t); }
    return t;
}
+ (NSThread *)mainThread { static dispatch_once_t o; dispatch_once(&o, ^{ main_thread_obj = [NSThread new]; main_thread_obj.name = @"main"; }); return main_thread_obj; }
+ (void)sleepForTimeInterval:(NSTimeInterval)ti { if (ti > 0) { struct timespec ts = { (time_t)ti, (long)((ti - (time_t)ti) * 1e9) }; nanosleep(&ts, NULL); } }
+ (void)detachNewThreadWithBlock:(void (^)(void))block { dispatch_async(dispatch_get_global_queue(0, 0), block); }
@end

/* ================= NSOperationQueue ================= */
static char opq_key;
@implementation NSOperationQueue { dispatch_queue_t _q; dispatch_group_t _g; }
+ (NSOperationQueue *)mainQueue {
    static NSOperationQueue *m; static dispatch_once_t o;
    dispatch_once(&o, ^{ m = [NSOperationQueue new]; m->_q = dispatch_get_main_queue(); m.name = @"NSOperationQueue Main Queue"; m.maxConcurrentOperationCount = 1;
                         dispatch_queue_set_specific(m->_q, &opq_key, (__bridge void *)m, NULL); });
    return m;
}
+ (NSOperationQueue *)currentQueue { return pthread_main_np() ? self.mainQueue : (__bridge NSOperationQueue *)dispatch_get_specific(&opq_key); }
- (instancetype)init {
    if ((self = [super init])) {
        _q = dispatch_queue_create("NSOperationQueue", DISPATCH_QUEUE_CONCURRENT);
        _g = dispatch_group_create();
        _maxConcurrentOperationCount = -1;
        dispatch_queue_set_specific(_q, &opq_key, (__bridge void *)self, NULL);
    }
    return self;
}
- (void)setMaxConcurrentOperationCount:(NSInteger)n {
    _maxConcurrentOperationCount = n;
    if (n == 1 && _q != dispatch_get_main_queue()) { _q = dispatch_queue_create("NSOperationQueue (serial)", NULL); dispatch_queue_set_specific(_q, &opq_key, (__bridge void *)self, NULL); }
}
- (void)addOperationWithBlock:(void (^)(void))block {
    if (!_g) _g = dispatch_group_create();
    dispatch_group_async(_g, _q, ^{ @autoreleasepool { block(); } });
}
- (void)addBarrierBlock:(void (^)(void))barrier { [self addOperationWithBlock:barrier]; }
- (void)waitUntilAllOperationsAreFinished { if (_g && _q != dispatch_get_main_queue()) dispatch_group_wait(_g, DISPATCH_TIME_FOREVER); }
- (void)cancelAllOperations {}
@end
