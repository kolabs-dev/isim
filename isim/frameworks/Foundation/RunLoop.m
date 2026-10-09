/* isim Foundation (ARC): NSRunLoop (one per thread, with modes), NSTimer, NSPort, delayed / ordered performs, the main
 * run loop's services for dispatch and UIKit, and NSThread (pthreads).
 *
 * A run loop holds items: timers, delayed performs, ordered performs and blocks, each registered in a set of modes
 * (NSRunLoopCommonModes stands for the loop's common modes: the default mode, plus UITrackingRunLoopMode on the main
 * loop once UIKit adds it). Running in a mode fires the due items of that mode; ports keep a loop with nothing else to
 * do running. The main run loop is driven by UIKit's event loop (-_isim_fireDue in the mode UIKit runs it in) or
 * dispatch_main(); main-queue blocks run in its common modes, as on iOS. */
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "isim_foundation.h"

extern int pthread_setname_np(const char *);
@interface NSThread (IsimRunLoop)
- (NSRunLoop *)_isim_runLoop;
@end

static double mono_now(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return ts.tv_sec + ts.tv_nsec / 1e9; }

NSRunLoopMode const NSDefaultRunLoopMode = @"kCFRunLoopDefaultMode";
NSRunLoopMode const NSRunLoopCommonModes = @"kCFRunLoopCommonModes";

/* ================= run loop items ================= */
@interface __IsimRunLoopItem : NSObject
@property double fireAt, interval;
@property BOOL repeats, valid;
@property BOOL source;                     /* a perform or block (not a timer): running it ends -runMode:beforeDate: */
@property NSUInteger order;                /* -performSelector:target:argument:order:modes: */
@property (copy) void (^block)(void);
@property (strong) id target, arg;
@property SEL sel;
@property (weak) NSTimer *timer;
@property (strong) NSTimer *scheduled;     /* the run loop keeps a scheduled timer alive until it is invalidated */
@property (strong) NSMutableSet<NSString *> *modes;
@property (weak) NSRunLoop *loop;
@end
@implementation __IsimRunLoopItem @end

@interface NSTimer ()
@property (strong) __IsimRunLoopItem *item;
@property (copy) void (^timerBlock)(NSTimer *);
@property (strong) id target;
@property SEL selector;
@end

@interface NSRunLoop () {
@public
    pthread_mutex_t _lock;
    pthread_cond_t _cond;
    NSMutableArray<__IsimRunLoopItem *> *_items;
    NSMutableSet<NSString *> *_commonModes;
    NSMutableDictionary<NSString *, NSMutableArray<NSPort *> *> *_ports;
    NSString *_currentMode;
    BOOL _isMain;
    NSUInteger _wakeups;
}
- (void)_isim_addItem:(__IsimRunLoopItem *)it;
- (void)_isim_removeItem:(__IsimRunLoopItem *)it;
@end

void (*isim_main_wakeup_hook)(void);      /* set by UIKit: wakes the UI event loop */
static NSString *main_mode;                /* the mode UIKit runs the main loop in (nil: default) */

static BOOL item_in_mode(NSRunLoop *rl, __IsimRunLoopItem *it, NSString *mode) {
    if ([it.modes containsObject:mode]) return YES;
    return [it.modes containsObject:NSRunLoopCommonModes] && [rl->_commonModes containsObject:mode];
}
static NSMutableSet *modes_of(NSArray *modes) {
    NSMutableSet *s = [NSMutableSet setWithArray:modes.count ? modes : @[NSDefaultRunLoopMode]];
    return s;
}

/* ================= NSRunLoop ================= */
static NSRunLoop *main_loop;

@implementation NSRunLoop
- (instancetype)init {
    if ((self = [super init])) {
        pthread_mutex_init(&_lock, NULL);
        pthread_cond_init(&_cond, NULL);
        _items = [NSMutableArray array];
        _commonModes = [NSMutableSet setWithObject:NSDefaultRunLoopMode];
        _ports = [NSMutableDictionary dictionary];
    }
    return self;
}
+ (NSRunLoop *)mainRunLoop {
    static dispatch_once_t o;
    dispatch_once(&o, ^{ main_loop = [NSRunLoop new]; main_loop->_isMain = YES; });
    return main_loop;
}
+ (NSRunLoop *)currentRunLoop {
    if (pthread_main_np()) return [self mainRunLoop];
    return [NSThread.currentThread _isim_runLoop];
}
- (NSString *)description { return [NSString stringWithFormat:@"<NSRunLoop %p>%@%@", self, _isMain ? @" (main)" : @"", _currentMode ? [@" mode " stringByAppendingString:_currentMode] : @""]; }
- (NSRunLoopMode)currentMode {
    if (_currentMode) return _currentMode;
    if (_isMain && isim_main_wakeup_hook) return main_mode ?: NSDefaultRunLoopMode;   /* UIKit is running it */
    return nil;
}
- (void)_isim_wake {
    pthread_mutex_lock(&_lock);
    _wakeups++;
    pthread_cond_broadcast(&_cond);
    pthread_mutex_unlock(&_lock);
    if (_isMain && !pthread_main_np() && isim_main_wakeup_hook) isim_main_wakeup_hook();
}
- (void)_isim_addItem:(__IsimRunLoopItem *)it {
    pthread_mutex_lock(&_lock);
    it.valid = YES; it.loop = self;
    if (![_items containsObject:it]) [_items addObject:it];
    _wakeups++;
    pthread_cond_broadcast(&_cond);
    pthread_mutex_unlock(&_lock);
    if (_isMain && !pthread_main_np() && isim_main_wakeup_hook) isim_main_wakeup_hook();
}
- (void)_isim_removeItem:(__IsimRunLoopItem *)it {
    pthread_mutex_lock(&_lock);
    [_items removeObject:it];
    pthread_mutex_unlock(&_lock);
}

/* ---- timers and ports ---- */
/* a timer is in one run loop; adding it again (another mode) adds the mode */
- (void)addTimer:(NSTimer *)t forMode:(NSRunLoopMode)mode {
    __IsimRunLoopItem *it = t.item;
    if (!it || !mode || !t.isValid) return;
    if (it.loop && it.loop != self) return;
    pthread_mutex_lock(&_lock);
    if (!it.modes) it.modes = [NSMutableSet set];
    [it.modes addObject:mode];
    pthread_mutex_unlock(&_lock);
    if (isnan(it.fireAt)) it.fireAt = mono_now() + it.interval;
    it.scheduled = t;
    [self _isim_addItem:it];
}
- (void)addPort:(NSPort *)port forMode:(NSRunLoopMode)mode {
    if (!port || !mode) return;
    pthread_mutex_lock(&_lock);
    NSMutableArray *list = _ports[mode] ?: (_ports[mode] = [NSMutableArray array]);
    if (![list containsObject:port]) [list addObject:port];
    pthread_mutex_unlock(&_lock);
    [self _isim_wake];
}
- (void)removePort:(NSPort *)port forMode:(NSRunLoopMode)mode {
    pthread_mutex_lock(&_lock);
    [_ports[mode] removeObject:port];
    pthread_mutex_unlock(&_lock);
}
/* a valid port, or a timer, in the mode (locked) */
- (BOOL)_isim_hasInputInMode:(NSString *)mode {
    for (NSString *m in _ports) {
        if (!([m isEqualToString:mode] || ([m isEqualToString:NSRunLoopCommonModes] && [_commonModes containsObject:mode]))) continue;
        for (NSPort *p in _ports[m]) if (p.isValid) return YES;
    }
    for (__IsimRunLoopItem *it in _items) if (it.valid && item_in_mode(self, it, mode)) return YES;
    return NO;
}

/* fires the items of the mode that are due; returns the seconds until the next one of the mode (1e9: none) and, in
 * *handled, whether a source (a perform or a block, not a timer) ran */
- (double)_isim_fireDueInMode:(NSString *)mode handled:(BOOL *)handled {
    double now = mono_now();
    NSMutableArray *due = [NSMutableArray array];
    pthread_mutex_lock(&_lock);
    for (__IsimRunLoopItem *it in _items) if (it.fireAt <= now && item_in_mode(self, it, mode)) [due addObject:it];
    for (__IsimRunLoopItem *it in due) {
        if (it.repeats) { it.fireAt += it.interval; if (it.fireAt < now) it.fireAt = now + it.interval; }
        else [_items removeObject:it];
    }
    pthread_mutex_unlock(&_lock);
    /* ordered performs run first, by order; then everything else in the order it was added */
    [due sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(__IsimRunLoopItem *a, __IsimRunLoopItem *b) {
        BOOL oa = a.order != NSNotFound, ob = b.order != NSNotFound;
        if (oa != ob) return oa ? NSOrderedAscending : NSOrderedDescending;
        if (oa && a.order != b.order) return a.order < b.order ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSString *saved = _currentMode;
    _currentMode = mode;
    for (__IsimRunLoopItem *it in due) {
        @autoreleasepool {
            if (!it.valid) continue;
            if (!it.repeats) it.valid = NO;
            if (it.source && handled) *handled = YES;
            if (it.timer) { NSTimer *t = it.timer; [t fire]; if (!it.repeats) it.scheduled = nil; }
            else if (it.block) it.block();
            else if (it.target) ((void (*)(id, SEL, id))[it.target methodForSelector:it.sel])(it.target, it.sel, it.arg);
        }
    }
    _currentMode = saved;
    double next = 1e9;
    pthread_mutex_lock(&_lock);
    now = mono_now();
    for (__IsimRunLoopItem *it in _items) if (item_in_mode(self, it, mode) && it.fireAt - now < next) next = it.fireAt - now;
    pthread_mutex_unlock(&_lock);
    return next < 0 ? 0 : next;
}
- (NSTimeInterval)_isim_fireDue { return [self _isim_fireDueInMode:main_mode ?: NSDefaultRunLoopMode handled:NULL]; }

- (NSDate *)limitDateForMode:(NSRunLoopMode)mode {
    double next = [self _isim_fireDueInMode:mode handled:NULL];
    pthread_mutex_lock(&_lock);
    BOOL input = [self _isim_hasInputInMode:mode] || _isMain;
    pthread_mutex_unlock(&_lock);
    if (!input) return nil;
    return next >= 1e9 ? [NSDate distantFuture] : [NSDate dateWithTimeIntervalSinceNow:next];
}
/* waits (on this loop's condition) until an item is due, the loop is woken or the limit passes */
- (void)_isim_waitUntil:(double)limit next:(double)next {
    double now = mono_now(), until = now + next;
    if (until > limit) until = limit;
    if (until <= now) return;
    struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
    double t = ts.tv_sec + ts.tv_nsec / 1e9 + (until - now);
    ts.tv_sec = (time_t)t; ts.tv_nsec = (long)((t - (double)ts.tv_sec) * 1e9);
    pthread_mutex_lock(&_lock);
    NSUInteger seen = _wakeups;
    while (_wakeups == seen) if (pthread_cond_timedwait(&_cond, &_lock, &ts) != 0) break;
    pthread_mutex_unlock(&_lock);
}
/* one run of the loop in a mode: fires due timers until a source is handled or the limit passes. NO when the mode has
 * nothing to wait for (no ports, timers or performs; the main loop always has its main queue) */
- (BOOL)runMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate {
    if (!mode) return NO;
    double limit = mono_now() + (limitDate ? limitDate.timeIntervalSinceNow : 0);
    pthread_mutex_lock(&_lock);
    BOOL input = [self _isim_hasInputInMode:mode] || (_isMain && [_commonModes containsObject:mode]);
    pthread_mutex_unlock(&_lock);
    if (!input) return NO;
    for (;;) {
        BOOL handled = NO;
        double next = [self _isim_fireDueInMode:mode handled:&handled];
        if (handled || mono_now() >= limit) return YES;
        [self _isim_waitUntil:limit next:next];
        if (mono_now() >= limit) { [self _isim_fireDueInMode:mode handled:NULL]; return YES; }
    }
}
- (void)acceptInputForMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate { [self runMode:mode beforeDate:limitDate]; }
- (void)runUntilDate:(NSDate *)limitDate {
    while (limitDate.timeIntervalSinceNow > 0 && [self runMode:NSDefaultRunLoopMode beforeDate:limitDate]) {}
}
- (void)run { while ([self runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {} }

/* ---- performs ---- */
static __IsimRunLoopItem *perform_item(double delay, NSArray *modes) {
    __IsimRunLoopItem *it = [__IsimRunLoopItem new];
    it.fireAt = mono_now() + delay; it.modes = modes_of(modes); it.order = NSNotFound; it.source = delay <= 0;
    return it;
}
- (void)performInModes:(NSArray<NSRunLoopMode> *)modes block:(void (^)(void))block {
    __IsimRunLoopItem *it = perform_item(0, modes); it.block = block;
    [self _isim_addItem:it];
}
- (void)performBlock:(void (^)(void))block { [self performInModes:@[NSRunLoopCommonModes] block:block]; }
- (void)performSelector:(SEL)sel target:(id)target argument:(id)arg order:(NSUInteger)order modes:(NSArray<NSRunLoopMode> *)modes {
    __IsimRunLoopItem *it = perform_item(0, modes); it.target = target; it.sel = sel; it.arg = arg; it.order = order;
    [self _isim_addItem:it];
}
- (void)_isim_cancelTarget:(id)target selector:(SEL)sel argument:(id)arg all:(BOOL)all ordered:(BOOL)ordered {
    pthread_mutex_lock(&_lock);
    for (__IsimRunLoopItem *it in [_items copy]) {
        if (it.timer || it.target != target || (ordered != (it.order != NSNotFound))) continue;
        if (!all && (it.sel != sel || !(it.arg == arg || [it.arg isEqual:arg]))) continue;
        it.valid = NO; [_items removeObject:it];
    }
    pthread_mutex_unlock(&_lock);
}
- (void)cancelPerformSelector:(SEL)sel target:(id)target argument:(id)arg { [self _isim_cancelTarget:target selector:sel argument:arg all:NO ordered:YES]; }
- (void)cancelPerformSelectorsWithTarget:(id)target { [self _isim_cancelTarget:target selector:NULL argument:nil all:YES ordered:YES]; }
@end

void isim_runloop_set_main_mode(NSRunLoopMode mode) {
    main_mode = [mode isEqualToString:NSDefaultRunLoopMode] ? nil : [mode copy];
    [NSRunLoop.mainRunLoop _isim_wake];
}
void isim_runloop_add_common_mode(NSRunLoop *rl, NSRunLoopMode mode) {
    if (!rl || !mode) return;
    pthread_mutex_lock(&rl->_lock);
    [rl->_commonModes addObject:mode];
    pthread_mutex_unlock(&rl->_lock);
}

/* ================= NSObject performs ================= */
/* -performSelector:withObject:afterDelay: and friends run on the calling thread's run loop, in the default mode */
void isim_schedule_perform(id target, SEL sel, id arg, NSTimeInterval delay) {
    __IsimRunLoopItem *it = perform_item(delay, @[NSDefaultRunLoopMode]);
    it.target = target; it.sel = sel; it.arg = arg;
    [NSRunLoop.currentRunLoop _isim_addItem:it];
}
void isim_cancel_performs(id target) { [NSRunLoop.currentRunLoop _isim_cancelTarget:target selector:NULL argument:nil all:YES ordered:NO]; }

@implementation NSObject (NSDelayedPerforming)
- (void)performSelector:(SEL)sel withObject:(id)arg afterDelay:(NSTimeInterval)delay inModes:(NSArray<NSRunLoopMode> *)modes {
    if (!modes.count) return;
    __IsimRunLoopItem *it = perform_item(delay, modes);
    it.target = self; it.sel = sel; it.arg = arg;
    [NSRunLoop.currentRunLoop _isim_addItem:it];
}
+ (void)cancelPreviousPerformRequestsWithTarget:(id)target selector:(SEL)sel object:(id)arg {
    [NSRunLoop.currentRunLoop _isim_cancelTarget:target selector:sel argument:arg all:NO ordered:NO];
}
@end

/* ================= main run loop services (dispatch's main queue, UIKit) ================= */
/* main-queue blocks: the main loop's common modes */
void isim_main_enqueue_f(double delay, void (*f)(void *), void *ctx) {
    __IsimRunLoopItem *it = perform_item(delay, @[NSRunLoopCommonModes]);
    it.block = ^{ f(ctx); };
    [NSRunLoop.mainRunLoop _isim_addItem:it];
}
double isim_main_fire_due(void) { return [NSRunLoop.mainRunLoop _isim_fireDue]; }
/* seconds until the next main run loop item of UIKit's mode is due (0 if one is due now) without firing anything */
double isim_main_next_due(void) {
    NSRunLoop *rl = NSRunLoop.mainRunLoop;
    NSString *mode = main_mode ?: NSDefaultRunLoopMode;
    double next = 1e9, now = mono_now();
    pthread_mutex_lock(&rl->_lock);
    for (__IsimRunLoopItem *it in rl->_items) if (item_in_mode(rl, it, mode) && it.fireAt - now < next) next = it.fireAt - now;
    pthread_mutex_unlock(&rl->_lock);
    return next < 0 ? 0 : next;
}
void isim_main_wait(double seconds) {
    if (seconds <= 0) return;
    NSRunLoop *rl = NSRunLoop.mainRunLoop;
    if (isim_main_next_due() <= 0) return;
    [rl _isim_waitUntil:mono_now() + seconds next:seconds];
}

/* ================= NSTimer ================= */
@implementation NSTimer { BOOL _invalidated; }
@synthesize tolerance = _tolerance;
- (instancetype)initWithFireDate:(NSDate *)date interval:(NSTimeInterval)i target:(id)t selector:(SEL)s userInfo:(id)ui repeats:(BOOL)rep {
    return [self initWithIsimFireDate:date interval:i target:t selector:s userInfo:ui repeats:rep];
}
- (instancetype)initWithIsimFireDate:(NSDate *)date interval:(NSTimeInterval)i target:(id)t selector:(SEL)s userInfo:(id)ui repeats:(BOOL)rep {
    if (!(self = [super init])) return nil;
    _timeInterval = i;
    __IsimRunLoopItem *it = [__IsimRunLoopItem new];
    it.interval = i > 0.0001 ? i : 0.0001; it.repeats = rep; it.timer = self; it.order = NSNotFound;
    it.fireAt = date ? mono_now() + date.timeIntervalSinceNow : NAN;     /* NAN: the interval after it is scheduled */
    _item = it;
    _target = t; _selector = s; _userInfo = ui;
    return self;
}
- (instancetype)init { return [self initWithIsimFireDate:nil interval:0 target:nil selector:NULL userInfo:nil repeats:NO]; }
- (instancetype)initWithFireDate:(NSDate *)date interval:(NSTimeInterval)i repeats:(BOOL)r block:(void (^)(NSTimer *))block {
    if ((self = [self initWithIsimFireDate:date interval:i target:nil selector:NULL userInfo:nil repeats:r])) _timerBlock = [block copy];
    return self;
}
+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)i repeats:(BOOL)r block:(void (^)(NSTimer *))block {
    NSTimer *t = [[self alloc] initWithIsimFireDate:nil interval:i target:nil selector:NULL userInfo:nil repeats:r];
    t.timerBlock = block;
    return t;
}
+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)i target:(id)target selector:(SEL)sel userInfo:(id)info repeats:(BOOL)r {
    return [[self alloc] initWithIsimFireDate:nil interval:i target:target selector:sel userInfo:info repeats:r];
}
/* scheduled timers go to the current thread's run loop, in the default mode */
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)i repeats:(BOOL)r block:(void (^)(NSTimer *))block {
    NSTimer *t = [self timerWithTimeInterval:i repeats:r block:block];
    [NSRunLoop.currentRunLoop addTimer:t forMode:NSDefaultRunLoopMode];
    return t;
}
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)i target:(id)target selector:(SEL)sel userInfo:(id)info repeats:(BOOL)r {
    NSTimer *t = [self timerWithTimeInterval:i target:target selector:sel userInfo:info repeats:r];
    [NSRunLoop.currentRunLoop addTimer:t forMode:NSDefaultRunLoopMode];
    return t;
}
- (void)fire {
    if (self.timerBlock) self.timerBlock(self);
    else if (self.target) ((void (*)(id, SEL, id))[self.target methodForSelector:self.selector])(self.target, self.selector, self);
    if (!self.item.repeats) [self invalidate];
}
- (void)invalidate {
    _invalidated = YES;
    __IsimRunLoopItem *it = self.item;
    it.valid = NO;
    [it.loop _isim_removeItem:it];
    it.scheduled = nil;
    self.target = nil; self.timerBlock = nil;
}
- (BOOL)isValid { return !_invalidated; }
- (NSDate *)fireDate {
    double at = self.item.fireAt;
    return [NSDate dateWithTimeIntervalSinceNow:isnan(at) ? self.item.interval : at - mono_now()];
}
- (void)setFireDate:(NSDate *)d {
    self.item.fireAt = mono_now() + d.timeIntervalSinceNow;
    [self.item.loop _isim_wake];
}
- (NSTimeInterval)tolerance { return _tolerance; }
- (void)setTolerance:(NSTimeInterval)t { _tolerance = t > 0 ? t : 0; }     /* accepted: isim fires timers on time */
@end


NSTimer *isim_scheduled_common_timer(NSTimeInterval interval, BOOL repeats, void (^block)(NSTimer *)) {
    NSTimer *t = [NSTimer timerWithTimeInterval:interval repeats:repeats block:block];
    [NSRunLoop.currentRunLoop addTimer:t forMode:NSRunLoopCommonModes];
    return t;
}

/* ================= NSPort ================= */
NSNotificationName const NSPortDidBecomeInvalidNotification = @"NSPortDidBecomeInvalidNotification";
@implementation NSPort { BOOL _invalid; }
+ (NSPort *)port { return [NSMachPort new]; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (BOOL)isValid { return !_invalid; }
- (void)invalidate {
    if (_invalid) return;
    _invalid = YES;
    [NSNotificationCenter.defaultCenter postNotificationName:NSPortDidBecomeInvalidNotification object:self];
}
- (void)scheduleInRunLoop:(NSRunLoop *)rl forMode:(NSRunLoopMode)mode { [rl addPort:self forMode:mode]; }
- (void)removeFromRunLoop:(NSRunLoop *)rl forMode:(NSRunLoopMode)mode { [rl removePort:self forMode:mode]; }
@end
@implementation NSMachPort { uint32_t _port; }
static uint32_t next_port = 0x1003;
+ (NSPort *)portWithMachPort:(uint32_t)p { NSMachPort *m = [NSMachPort new]; m->_port = p; return m; }
- (instancetype)init { if ((self = [super init])) _port = __atomic_fetch_add(&next_port, 4, __ATOMIC_RELAXED); return self; }
- (uint32_t)machPort { return _port; }
@end

/* ================= NSThread ================= */
NSNotificationName const NSWillBecomeMultiThreadedNotification = @"NSWillBecomeMultiThreadedNotification";
NSNotificationName const NSDidBecomeSingleThreadedNotification = @"NSDidBecomeSingleThreadedNotification";
NSNotificationName const NSThreadWillExitNotification = @"NSThreadWillExitNotification";

/* the NSThread object of each pthread (created on first use for threads NSThread did not start) */
static pthread_key_t thread_key;
static NSThread *main_thread_obj;
static BOOL multithreaded;
static void thread_obj_release(void *p) { NSThread *t = (__bridge_transfer NSThread *)p; (void)t; }

@interface NSThread () {
@public
    void (^_block)(void);
    id _target, _argument;
    SEL _selector;
    NSRunLoop *_runLoop;
    pthread_t _pthread;
    BOOL _executing, _finished, _cancelled, _started;
}
@end
@implementation NSThread
@synthesize threadDictionary = _threadDictionary, stackSize = _stackSize, threadPriority = _threadPriority, qualityOfService = _qualityOfService;
+ (void)initialize { if (self == [NSThread class]) pthread_key_create(&thread_key, thread_obj_release); }
- (instancetype)init {
    if ((self = [super init])) { _threadDictionary = [NSMutableDictionary dictionary]; _threadPriority = 0.5; _qualityOfService = NSQualityOfServiceDefault; _stackSize = 512 * 1024; }
    return self;
}
- (instancetype)initWithTarget:(id)target selector:(SEL)sel object:(id)arg {
    if ((self = [self init])) { _target = target; _selector = sel; _argument = arg; }
    return self;
}
- (instancetype)initWithBlock:(void (^)(void))block { if ((self = [self init])) _block = [block copy]; return self; }
+ (BOOL)isMainThread { return pthread_main_np() != 0; }
- (BOOL)isMainThread { return self == main_thread_obj; }
+ (NSThread *)mainThread {
    static dispatch_once_t o;
    dispatch_once(&o, ^{ main_thread_obj = [NSThread new]; main_thread_obj.name = @"main"; main_thread_obj->_executing = YES; main_thread_obj->_started = YES; });
    return main_thread_obj;
}
+ (NSThread *)currentThread {
    if (pthread_main_np()) return [self mainThread];
    NSThread *t = (__bridge NSThread *)pthread_getspecific(thread_key);
    if (!t) { t = [NSThread new]; t->_executing = YES; t->_started = YES; t->_pthread = pthread_self(); pthread_setspecific(thread_key, (__bridge_retained void *)t); }
    return t;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<NSThread: %p>{number = %lu, name = %@}", self, self == main_thread_obj ? 1UL : (unsigned long)(((uintptr_t)self >> 4) & 0xffff), self.name ?: @"(null)"];
}
/* the thread's run loop: NSRunLoop.currentRunLoop on that thread (created here when another thread asks first) */
- (NSRunLoop *)_isim_runLoop {
    if (self == main_thread_obj) return NSRunLoop.mainRunLoop;
    @synchronized (self) { if (!_runLoop) _runLoop = [NSRunLoop new]; return _runLoop; }
}
+ (BOOL)isMultiThreaded { return multithreaded; }
- (BOOL)isExecuting { return _executing; }
- (BOOL)isFinished { return _finished; }
- (BOOL)isCancelled { return _cancelled; }
- (void)cancel { _cancelled = YES; }
- (void)main {
    if (_block) _block();
    else if (_target) ((void (*)(id, SEL, id))[_target methodForSelector:_selector])(_target, _selector, _argument);
}
static void thread_finish(NSThread *t) {
    [NSNotificationCenter.defaultCenter postNotificationName:NSThreadWillExitNotification object:t];
    t->_executing = NO; t->_finished = YES;
    t->_block = nil; t->_target = nil; t->_argument = nil;
}
static void *thread_entry(void *p) {
    NSThread *t = (__bridge_transfer NSThread *)p;
    pthread_setspecific(thread_key, (__bridge_retained void *)t);
    if (t.name.length) pthread_setname_np(t.name.UTF8String);
    @autoreleasepool {
        [t main];
        thread_finish(t);
    }
    return NULL;
}
- (void)start {
    if (_started) [NSException raise:NSInvalidArgumentException format:@"*** -[NSThread start]: attempt to start the thread again"];
    _started = YES;
    if (_cancelled) { _finished = YES; return; }
    if (!multithreaded) {
        multithreaded = YES;
        [NSNotificationCenter.defaultCenter postNotificationName:NSWillBecomeMultiThreadedNotification object:nil];
    }
    _executing = YES;
    pthread_attr_t a; pthread_attr_init(&a);
    pthread_attr_setdetachstate(&a, PTHREAD_CREATE_DETACHED);
    if (_stackSize >= 16384) pthread_attr_setstacksize(&a, (_stackSize + 4095) & ~(size_t)4095);
    void *arg = (__bridge_retained void *)self;
    if (pthread_create(&_pthread, &a, thread_entry, arg) != 0) {
        _executing = NO; _finished = YES;
        NSThread *dropped = (__bridge_transfer NSThread *)arg; (void)dropped;
    }
    pthread_attr_destroy(&a);
}
+ (void)detachNewThreadWithBlock:(void (^)(void))block { [[[NSThread alloc] initWithBlock:block] start]; }
+ (void)detachNewThreadSelector:(SEL)sel toTarget:(id)target withObject:(id)arg { [[[NSThread alloc] initWithTarget:target selector:sel object:arg] start]; }
+ (void)sleepForTimeInterval:(NSTimeInterval)ti {
    if (ti > 0) { struct timespec ts = { (time_t)ti, (long)((ti - (time_t)ti) * 1e9) }; while (nanosleep(&ts, &ts) != 0) {} }
}
+ (void)sleepUntilDate:(NSDate *)date { [self sleepForTimeInterval:date.timeIntervalSinceNow]; }
+ (void)exit {
    NSThread *t = self.currentThread;
    if (t == main_thread_obj) exit(0);
    thread_finish(t);
    pthread_exit(NULL);
}
+ (double)threadPriority { return self.currentThread.threadPriority; }
+ (BOOL)setThreadPriority:(double)p { self.currentThread.threadPriority = p; return YES; }   /* adapted: recorded, not applied */
+ (NSArray<NSNumber *> *)callStackReturnAddresses {
    NSMutableArray *a = [NSMutableArray array];
    void **fp = __builtin_frame_address(0);
    for (int i = 0; i < 128 && fp && !((uintptr_t)fp & 7); i++) {
        void **next = fp[0]; void *ret = fp[1];
        if (!ret) break;
        [a addObject:@((uintptr_t)ret)];
        if (next <= fp) break;
        fp = next;
    }
    return a;
}
+ (NSArray<NSString *> *)callStackSymbols { return isim_symbolicate(self.callStackReturnAddresses); }
@end

/* ================= NSObject (NSThreadPerformAdditions) ================= */
static void perform_on(NSRunLoop *rl, BOOL here, id target, SEL sel, id arg, BOOL wait, NSArray *modes) {
    if (wait && here) { ((void (*)(id, SEL, id))[target methodForSelector:sel])(target, sel, arg); return; }
    __IsimRunLoopItem *it = perform_item(0, modes.count ? modes : @[NSRunLoopCommonModes]);
    it.target = target; it.sel = sel; it.arg = arg;
    if (!wait) { [rl _isim_addItem:it]; return; }
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    it.target = nil;
    it.block = ^{ ((void (*)(id, SEL, id))[target methodForSelector:sel])(target, sel, arg); dispatch_semaphore_signal(done); };
    [rl _isim_addItem:it];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
}
@implementation NSObject (NSThreadPerformAdditions)
- (void)performSelectorOnMainThread:(SEL)sel withObject:(id)arg waitUntilDone:(BOOL)wait modes:(NSArray<NSString *> *)modes {
    perform_on(NSRunLoop.mainRunLoop, pthread_main_np() != 0, self, sel, arg, wait, modes);
}
- (void)performSelectorOnMainThread:(SEL)sel withObject:(id)arg waitUntilDone:(BOOL)wait {
    perform_on(NSRunLoop.mainRunLoop, pthread_main_np() != 0, self, sel, arg, wait, nil);
}
- (void)performSelector:(SEL)sel onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait modes:(NSArray<NSString *> *)modes {
    perform_on([thr _isim_runLoop], thr == NSThread.currentThread, self, sel, arg, wait, modes);
}
- (void)performSelector:(SEL)sel onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait {
    [self performSelector:sel onThread:thr withObject:arg waitUntilDone:wait modes:nil];
}
- (void)performSelectorInBackground:(SEL)sel withObject:(id)arg { [NSThread detachNewThreadSelector:sel toTarget:self withObject:arg]; }
@end
