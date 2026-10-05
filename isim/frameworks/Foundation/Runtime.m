/* isim Foundation (ARC): exceptions, bundle + plist, dates, run loop/timers, notifications,
 * process info, user defaults, libdispatch subset. */
#import <Foundation/Foundation.h>
#include <objc/isim_internal.h>
#include <pthread.h>
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

@implementation NSException
+ (NSException *)exceptionWithName:(NSExceptionName)n reason:(NSString *)r userInfo:(NSDictionary *)u { return [[self alloc] initWithName:n reason:r userInfo:u]; }
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

/* ================= property lists (XML) ================= */
typedef struct { const char *p, *end; } px_t;
static void px_ws(px_t *x) { while (x->p < x->end && (*x->p == ' ' || *x->p == '\n' || *x->p == '\r' || *x->p == '\t')) x->p++; }
static void px_skip_meta(px_t *x) {
    for (;;) {
        px_ws(x);
        if (x->p + 4 < x->end && !strncmp(x->p, "<!--", 4)) { const char *e = strstr(x->p, "-->"); x->p = e ? e + 3 : x->end; continue; }
        if (x->p + 1 < x->end && x->p[0] == '<' && (x->p[1] == '?' || x->p[1] == '!')) { while (x->p < x->end && *x->p != '>') x->p++; x->p++; continue; }
        return;
    }
}
static NSString *px_text_until(px_t *x, const char *close) {
    const char *e = strstr(x->p, close);
    if (!e) e = x->end;
    NSMutableString *s = [NSMutableString string];
    for (const char *q = x->p; q < e;) {
        if (*q == '&') {
            const char *ents[][2] = { { "&amp;", "&" }, { "&lt;", "<" }, { "&gt;", ">" }, { "&quot;", "\"" }, { "&apos;", "'" } };
            BOOL hit = NO;
            for (int i = 0; i < 5; i++) { size_t n = strlen(ents[i][0]); if (!strncmp(q, ents[i][0], n)) { [s appendString:@(ents[i][1])]; q += n; hit = YES; break; } }
            if (hit) continue;
        }
        const char *r = q; while (r < e && *r != '&') r++;
        if (r == q) r++;
        NSString *chunk = [[NSString alloc] initWithBytes:q length:(NSUInteger)(r - q) encoding:NSUTF8StringEncoding];
        [s appendString:chunk];
        q = r;
    }
    x->p = e + strlen(close);
    return [s copy];
}
static id px_value(px_t *x) {
    px_skip_meta(x);
    if (x->p >= x->end || *x->p != '<') return nil;
    char tag[32] = {0}; int n = 0;
    const char *q = x->p + 1;
    while (q < x->end && *q != '>' && *q != ' ' && *q != '/' && n < 31) tag[n++] = *q++;
    while (q < x->end && *q != '>') q++;
    BOOL selfClosing = q[-1] == '/';
    x->p = q + 1;
    if (!strcmp(tag, "plist")) { id v = px_value(x); px_skip_meta(x); return v; }
    if (!strcmp(tag, "true")) return @YES;
    if (!strcmp(tag, "false")) return @NO;
    if (!strcmp(tag, "dict")) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        if (selfClosing) return d;
        for (;;) {
            px_skip_meta(x);
            if (!strncmp(x->p, "</dict>", 7)) { x->p += 7; break; }
            if (strncmp(x->p, "<key>", 5)) return d;
            x->p += 5;
            NSString *k = px_text_until(x, "</key>");
            id v = px_value(x);
            if (v) d[k] = v;
        }
        return d;
    }
    if (!strcmp(tag, "array")) {
        NSMutableArray *a = [NSMutableArray array];
        if (selfClosing) return a;
        for (;;) {
            px_skip_meta(x);
            if (!strncmp(x->p, "</array>", 8)) { x->p += 8; break; }
            id v = px_value(x);
            if (!v) break;
            [a addObject:v];
        }
        return a;
    }
    if (selfClosing) return !strcmp(tag, "string") ? @"" : nil;
    char close[40]; snprintf(close, sizeof close, "</%s>", tag);
    NSString *text = px_text_until(x, close);
    if (!strcmp(tag, "string") || !strcmp(tag, "date")) return text;
    if (!strcmp(tag, "integer")) return @([text longLongValue]);
    if (!strcmp(tag, "real")) return @([text doubleValue]);
    return [NSNull null];                         /* <data> etc. not supported */
}
id isim_plist_parse(const char *xml, NSUInteger len) {
    if (len >= 8 && !memcmp(xml, "bplist00", 8)) { NSLog(@"isim: binary property lists are not supported"); return nil; }
    px_t x = { xml, xml + len };
    return px_value(&x);
}

/* ================= NSBundle ================= */
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
- (id)objectForInfoDictionaryKey:(NSString *)key { return self.infoDictionary[key]; }
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
- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)t {
    if (!key) return value ?: @"";
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
    return value.length ? value : key;
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
@end
@implementation __IsimRunLoopItem @end

static pthread_mutex_t rl_lock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableArray<__IsimRunLoopItem *> *rl_items;

static void rl_add(__IsimRunLoopItem *it) {
    pthread_mutex_lock(&rl_lock);
    if (!rl_items) rl_items = [NSMutableArray array];
    it.valid = YES;
    [rl_items addObject:it];
    pthread_mutex_unlock(&rl_lock);
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
            if (it.timer) [it.timer fire];
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

/* ================= libdispatch subset ================= */
struct dispatch_queue_s {
    int kind;                         /* 0 main, 1 global (concurrent), 2 serial */
    const char *label;
    pthread_mutex_t lock; pthread_cond_t cond;
    void **blocks; size_t n, cap; int running;
};
struct dispatch_queue_s _dispatch_main_q = { 0, "com.apple.main-thread", PTHREAD_MUTEX_INITIALIZER, PTHREAD_COND_INITIALIZER, NULL, 0, 0, 0 };
static struct dispatch_queue_s global_q = { 1, "com.apple.root.default-qos", PTHREAD_MUTEX_INITIALIZER, PTHREAD_COND_INITIALIZER, NULL, 0, 0, 0 };

dispatch_queue_t dispatch_get_global_queue(long identifier, unsigned long flags) { return &global_q; }
dispatch_queue_t dispatch_queue_create(const char *label, void *attr) {
    struct dispatch_queue_s *q = calloc(1, sizeof *q);
    q->kind = 2; q->label = label ? strdup(label) : "";
    pthread_mutex_init(&q->lock, NULL); pthread_cond_init(&q->cond, NULL);
    return q;
}
static void *run_block_thread(void *b) {
    @autoreleasepool { ((__bridge dispatch_block_t)b)(); }
    _Block_release(b);
    return NULL;
}
static void *serial_worker(void *arg) {
    struct dispatch_queue_s *q = arg;
    for (;;) {
        pthread_mutex_lock(&q->lock);
        if (!q->n) { q->running = 0; pthread_mutex_unlock(&q->lock); return NULL; }
        void *b = q->blocks[0]; memmove(q->blocks, q->blocks + 1, --q->n * sizeof(void *));
        pthread_mutex_unlock(&q->lock);
        @autoreleasepool { ((__bridge dispatch_block_t)b)(); }
        _Block_release(b);
    }
}
void dispatch_async(dispatch_queue_t q, dispatch_block_t block) {
    if (q->kind == 0) { rl_add_block(0, block); return; }
    void *b = _Block_copy((__bridge void *)block);
    pthread_t t;
    if (q->kind == 1) { pthread_create(&t, NULL, run_block_thread, b); pthread_detach(t); return; }
    pthread_mutex_lock(&q->lock);
    if (q->n == q->cap) { q->cap = q->cap ? q->cap * 2 : 8; q->blocks = realloc(q->blocks, q->cap * sizeof(void *)); }
    q->blocks[q->n++] = b;
    int start = !q->running; q->running = 1;
    pthread_mutex_unlock(&q->lock);
    if (start) { pthread_create(&t, NULL, serial_worker, q); pthread_detach(t); }
}
void dispatch_sync(dispatch_queue_t q, dispatch_block_t block) {
    if (q->kind != 0 || pthread_main_np()) { block(); return; }   /* isim: serial/global sync runs inline */
    __block int done = 0;
    pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER; pthread_cond_t c = PTHREAD_COND_INITIALIZER;
    pthread_mutex_t *mp = &m; pthread_cond_t *cp = &c;
    rl_add_block(0, ^{ block(); pthread_mutex_lock(mp); done = 1; pthread_cond_signal(cp); pthread_mutex_unlock(mp); });
    pthread_mutex_lock(&m); while (!done) pthread_cond_wait(&c, &m); pthread_mutex_unlock(&m);
}
dispatch_time_t dispatch_time(dispatch_time_t when, int64_t delta) {
    uint64_t base = when == DISPATCH_TIME_NOW ? (uint64_t)(mono_now() * 1e9) : when;
    return base + delta;
}
void dispatch_after(dispatch_time_t when, dispatch_queue_t q, dispatch_block_t block) {
    double delay = when == DISPATCH_TIME_FOREVER ? 1e9 : (double)when / 1e9 - mono_now();
    if (q->kind == 0) { rl_add_block(delay > 0 ? delay : 0, block); return; }
    rl_add_block(delay > 0 ? delay : 0, ^{ dispatch_async(q, block); });
}
void dispatch_once(dispatch_once_t *pred, dispatch_block_t block) {
    static pthread_mutex_t lk = PTHREAD_RECURSIVE_MUTEX_INITIALIZER;
    if (__atomic_load_n(pred, __ATOMIC_ACQUIRE) == ~0L) return;
    pthread_mutex_lock(&lk);
    if (*pred != ~0L) { block(); __atomic_store_n(pred, ~0L, __ATOMIC_RELEASE); }
    pthread_mutex_unlock(&lk);
}

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
    o.name = name; o.object = obj; o.hasObject = obj != nil; o.block = block; o.observer = o;
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

@implementation NSUserDefaults { NSMutableDictionary *_d; NSString *_file; }
+ (NSUserDefaults *)standardUserDefaults { static NSUserDefaults *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [NSUserDefaults new]; }); return u; }
- (instancetype)init {
    if ((self = [super init])) {
        NSString *ident = NSBundle.mainBundle.bundleIdentifier ?: @(isim_process_name());
        _file = [NSString stringWithFormat:@"%@/Library/Preferences/%@.plist", NSHomeDirectory(), ident];
        _d = [[NSDictionary dictionaryWithContentsOfFile:_file] mutableCopy] ?: [NSMutableDictionary dictionary];
    }
    return self;
}
- (void)_save { [isim_plist_xml(_d) writeToFile:_file atomically:YES encoding:NSUTF8StringEncoding error:NULL]; }
- (id)objectForKey:(NSString *)k { @synchronized (self) { return _d[k]; } }
- (void)setObject:(id)v forKey:(NSString *)k { @synchronized (self) { _d[k] = v; [self _save]; } }
- (void)removeObjectForKey:(NSString *)k { @synchronized (self) { [_d removeObjectForKey:k]; [self _save]; } }
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
- (NSString *)localizedDescription {
    NSString *s = _userInfo[NSLocalizedDescriptionKey];
    return s ?: [NSString stringWithFormat:@"The operation couldn’t be completed. (%@ error %ld.)", _domain, (long)_code];
}
- (NSString *)localizedFailureReason { return _userInfo[NSLocalizedFailureReasonErrorKey]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"Error Domain=%@ Code=%ld \"%@\"", _domain, (long)_code, self.localizedDescription]; }
@end

@implementation NSCoder @end

/* function-pointer variants (used by C/C++ clients such as the Swift runtime) */
void dispatch_async_f(dispatch_queue_t q, void *ctx, dispatch_function_t f) { dispatch_async(q, ^{ f(ctx); }); }
void dispatch_once_f(dispatch_once_t *pred, void *ctx, dispatch_function_t f) { dispatch_once(pred, ^{ f(ctx); }); }
