/* isim Foundation (ARC): NSRunLoop (one per thread, with modes), NSTimer, NSPort, delayed / ordered performs, the main
 * run loop's services for dispatch and UIKit, and NSThread (pthreads).
 *
 * A run loop holds items: timers, delayed performs, ordered performs and blocks, each registered in a set of modes
 * (NSRunLoopCommonModes stands for the loop's common modes: the default mode, plus UITrackingRunLoopMode on the main
 * loop once UIKit adds it). Running in a mode fires the due items of that mode; ports keep a loop with nothing else to
 * do running. The main run loop is driven by UIKit's event loop (-_isim_fireDue in the mode UIKit runs it in) or
 * dispatch_main(); main-queue blocks run in its common modes, as on iOS.
 *
 * CFRunLoop (the end of this file) is the same loop: CFRunLoopRef is the NSRunLoop, CFRunLoopTimerRef the NSTimer;
 * observers are told each activity (entry, before timers / sources, before / after waiting, exit) by -runMode:, the
 * CFRunLoopRun* functions and UIKit's event loop (isim_main_runloop_activity); version 0 sources run when signalled. */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CFRunLoop.h>
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
@property CFRunLoopTimerContext isimContext;   /* CFRunLoopTimerCreate: its info, released with the timer */
@property CFIndex isimOrder;
@property (copy) void (^timerBlock)(NSTimer *);
- (instancetype)initWithIsimFireDate:(NSDate *)date interval:(NSTimeInterval)i target:(id)t selector:(SEL)s userInfo:(id)ui repeats:(BOOL)rep;
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
    NSMutableArray *_observers;               /* __IsimCFRunLoopObserver, in the modes they were added for */
    NSMutableArray *_sources;                 /* __IsimCFRunLoopSource */
    BOOL _stopped, _waiting;
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
        _observers = [NSMutableArray array];
        _sources = [NSMutableArray array];
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
- (CFRunLoopRef)getCFRunLoop { return (__bridge CFRunLoopRef)self; }    /* CFRunLoop (end of this file) is the same loop */
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
    extern BOOL isim_runloop_has_source(NSRunLoop *, NSString *, BOOL signalled);
    return isim_runloop_has_source(self, mode, NO);
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
static void notify_observers(NSRunLoop *rl, NSString *mode, CFRunLoopActivity activity);
static BOOL perform_sources(NSRunLoop *rl, NSString *mode);
/* one pass of UIKit's main loop (or dispatch_main): observers, due timers and blocks, signalled sources */
- (NSTimeInterval)_isim_fireDue {
    NSString *mode = main_mode ?: NSDefaultRunLoopMode;
    notify_observers(self, mode, kCFRunLoopBeforeTimers);
    notify_observers(self, mode, kCFRunLoopBeforeSources);
    double next = [self _isim_fireDueInMode:mode handled:NULL];
    if (perform_sources(self, mode)) next = 0;
    extern BOOL isim_runloop_has_source(NSRunLoop *, NSString *, BOOL signalled);
    return isim_runloop_has_source(self, mode, YES) ? 0 : next;
}

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
static CFRunLoopRunResult run_in_mode(NSRunLoop *rl, NSString *mode, double seconds, BOOL returnAfterSource);
- (BOOL)runMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate {
    if (!mode) return NO;
    return run_in_mode(self, mode, limitDate ? limitDate.timeIntervalSinceNow : 0, YES) != kCFRunLoopRunFinished;
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
    extern BOOL isim_runloop_has_source(NSRunLoop *, NSString *, BOOL signalled);
    if (isim_runloop_has_source(rl, mode, YES)) return 0;
    return next < 0 ? 0 : next;
}
/* UIKit's event loop tells the main run loop's observers what it does: kCFRunLoopEntry when it starts, before and
 * after it waits for events */
void isim_main_runloop_activity(unsigned long activity) {
    NSRunLoop *rl = NSRunLoop.mainRunLoop;
    if (activity == kCFRunLoopBeforeWaiting) { notify_observers(rl, main_mode ?: NSDefaultRunLoopMode, activity); rl->_waiting = YES; }
    else { if (activity == kCFRunLoopAfterWaiting) rl->_waiting = NO; notify_observers(rl, main_mode ?: NSDefaultRunLoopMode, activity); }
}
void isim_main_wait(double seconds) {
    if (seconds <= 0) return;
    NSRunLoop *rl = NSRunLoop.mainRunLoop;
    if (isim_main_next_due() <= 0) return;
    isim_main_runloop_activity(kCFRunLoopBeforeWaiting);
    [rl _isim_waitUntil:mono_now() + seconds next:seconds];
    isim_main_runloop_activity(kCFRunLoopAfterWaiting);
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
- (CFTypeID)_isimCFTypeID { return CFRunLoopTimerGetTypeID(); }
- (void)dealloc { if (_isimContext.release && _isimContext.info) _isimContext.release(_isimContext.info); }
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

/* ================= CFRunLoop ================= */
CFRunLoopMode const kCFRunLoopDefaultMode = CFSTR("kCFRunLoopDefaultMode");
CFRunLoopMode const kCFRunLoopCommonModes = CFSTR("kCFRunLoopCommonModes");
enum { ISIM_CF_RUNLOOP = 0x5e20, ISIM_CF_RUNLOOP_SOURCE, ISIM_CF_RUNLOOP_OBSERVER, ISIM_CF_RUNLOOP_TIMER };

/* an observer: told the activities it asked for, in the modes of the loops it was added to */
@interface __IsimCFRunLoopObserver : NSObject {
@public
    CFOptionFlags activities;
    BOOL repeats, valid;
    CFIndex order;
    CFRunLoopObserverCallBack callout;
    CFRunLoopObserverContext context;
    void (^block)(CFRunLoopObserverRef, CFRunLoopActivity);
    NSMutableSet<NSString *> *modes;
    __weak NSRunLoop *loop;
}
@end
@implementation __IsimCFRunLoopObserver
- (CFTypeID)_isimCFTypeID { return ISIM_CF_RUNLOOP_OBSERVER; }
- (void)dealloc { if (context.release && context.info) context.release(context.info); }
@end

/* a version 0 source: performed once signalled, when its loop runs in one of its modes */
@interface __IsimCFRunLoopSource : NSObject {
@public
    CFIndex order;
    BOOL valid, signalled, mach;
    CFRunLoopSourceContext context;
    NSMutableDictionary<NSValue *, NSMutableSet<NSString *> *> *loops;   /* run loop (unretained) -> modes */
}
@end
@implementation __IsimCFRunLoopSource
- (CFTypeID)_isimCFTypeID { return ISIM_CF_RUNLOOP_SOURCE; }
- (void)dealloc { if (context.release && context.info) context.release(context.info); }
@end

@implementation NSRunLoop (IsimCFRunLoop)
- (CFTypeID)_isimCFTypeID { return ISIM_CF_RUNLOOP; }
@end

static BOOL mode_matches(NSRunLoop *rl, NSSet<NSString *> *modes, NSString *mode) {
    if ([modes containsObject:mode]) return YES;
    if (![modes containsObject:NSRunLoopCommonModes]) return NO;
    pthread_mutex_lock(&rl->_lock);
    BOOL common = [rl->_commonModes containsObject:mode];
    pthread_mutex_unlock(&rl->_lock);
    return common;
}
static void notify_observers(NSRunLoop *rl, NSString *mode, CFRunLoopActivity activity) {
    NSArray *list;
    @synchronized (rl->_observers) { list = [rl->_observers copy]; }
    if (!list.count) return;
    NSMutableArray<__IsimCFRunLoopObserver *> *due = [NSMutableArray array];
    for (__IsimCFRunLoopObserver *o in list) if (o->valid && (o->activities & activity) && mode_matches(rl, o->modes, mode)) [due addObject:o];
    [due sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(__IsimCFRunLoopObserver *a, __IsimCFRunLoopObserver *b) {
        return a->order < b->order ? NSOrderedAscending : a->order > b->order ? NSOrderedDescending : NSOrderedSame;
    }];
    NSString *saved = rl->_currentMode;
    rl->_currentMode = mode;
    for (__IsimCFRunLoopObserver *o in due) {
        if (!o->valid) continue;
        if (!o->repeats) CFRunLoopObserverInvalidate((__bridge CFRunLoopObserverRef)o);
        @autoreleasepool {
            if (o->block) o->block((__bridge CFRunLoopObserverRef)o, activity);
            else if (o->callout) o->callout((__bridge CFRunLoopObserverRef)o, activity, o->context.info);
        }
    }
    rl->_currentMode = saved;
}
BOOL isim_runloop_has_source(NSRunLoop *rl, NSString *mode, BOOL signalled) {
    NSArray *list;
    @synchronized (rl->_sources) { list = [rl->_sources copy]; }
    for (__IsimCFRunLoopSource *s in list) {
        if (!s->valid || (signalled && !s->signalled)) continue;
        NSSet *modes;
        @synchronized (s) { modes = [s->loops[[NSValue valueWithNonretainedObject:rl]] copy]; }
        if (!modes) continue;
        /* the common modes of this loop (no lock: the caller may hold the loop's lock) */
        if ([modes containsObject:mode] || ([modes containsObject:NSRunLoopCommonModes] && [rl->_commonModes containsObject:mode])) return YES;
    }
    return NO;
}
/* the signalled sources of the mode, by order; YES if one ran */
static BOOL perform_sources(NSRunLoop *rl, NSString *mode) {
    NSArray *list;
    @synchronized (rl->_sources) { list = [rl->_sources copy]; }
    if (!list.count) return NO;
    NSMutableArray<__IsimCFRunLoopSource *> *due = [NSMutableArray array];
    for (__IsimCFRunLoopSource *s in list) {
        NSSet *modes;
        @synchronized (s) { modes = [s->loops[[NSValue valueWithNonretainedObject:rl]] copy]; }
        if (s->valid && s->signalled && !s->mach && modes && mode_matches(rl, modes, mode)) [due addObject:s];
    }
    [due sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(__IsimCFRunLoopSource *a, __IsimCFRunLoopSource *b) {
        return a->order < b->order ? NSOrderedAscending : a->order > b->order ? NSOrderedDescending : NSOrderedSame;
    }];
    NSString *saved = rl->_currentMode;
    rl->_currentMode = mode;
    for (__IsimCFRunLoopSource *s in due) {
        @synchronized (s) { if (!s->signalled) continue; s->signalled = NO; }
        @autoreleasepool { if (s->context.perform) s->context.perform(s->context.info); }
    }
    rl->_currentMode = saved;
    return due.count > 0;
}

static CFRunLoopRunResult run_in_mode(NSRunLoop *rl, NSString *mode, double seconds, BOOL returnAfterSource) {
    double limit = mono_now() + (seconds > 0 ? seconds : 0);
    pthread_mutex_lock(&rl->_lock);
    BOOL input = [rl _isim_hasInputInMode:mode] || (rl->_isMain && [rl->_commonModes containsObject:mode]);
    pthread_mutex_unlock(&rl->_lock);
    if (!input) return kCFRunLoopRunFinished;
    NSString *saved = rl->_currentMode;
    rl->_currentMode = mode;
    notify_observers(rl, mode, kCFRunLoopEntry);
    CFRunLoopRunResult result;
    for (;;) {
        if (rl->_stopped) { rl->_stopped = NO; result = kCFRunLoopRunStopped; break; }
        notify_observers(rl, mode, kCFRunLoopBeforeTimers);
        notify_observers(rl, mode, kCFRunLoopBeforeSources);
        BOOL handled = NO;
        double next = [rl _isim_fireDueInMode:mode handled:&handled];
        rl->_currentMode = mode;
        if (perform_sources(rl, mode)) handled = YES;
        if (handled && returnAfterSource) { result = kCFRunLoopRunHandledSource; break; }
        if (rl->_stopped) { rl->_stopped = NO; result = kCFRunLoopRunStopped; break; }
        if (mono_now() >= limit) { result = kCFRunLoopRunTimedOut; break; }
        pthread_mutex_lock(&rl->_lock);
        BOOL more = [rl _isim_hasInputInMode:mode] || (rl->_isMain && [rl->_commonModes containsObject:mode]);
        pthread_mutex_unlock(&rl->_lock);
        if (!more) { result = kCFRunLoopRunFinished; break; }
        if (isim_runloop_has_source(rl, mode, YES)) continue;
        notify_observers(rl, mode, kCFRunLoopBeforeWaiting);
        rl->_waiting = YES;
        [rl _isim_waitUntil:limit next:next];
        rl->_waiting = NO;
        notify_observers(rl, mode, kCFRunLoopAfterWaiting);
    }
    notify_observers(rl, mode, kCFRunLoopExit);
    rl->_currentMode = saved;
    return result;
}

#define RL(r) ((__bridge NSRunLoop *)(r))
#define MODE(m) ((__bridge NSString *)(m))
CFTypeID CFRunLoopGetTypeID(void) { return ISIM_CF_RUNLOOP; }
CFRunLoopRef CFRunLoopGetCurrent(void) { return (__bridge CFRunLoopRef)NSRunLoop.currentRunLoop; }
CFRunLoopRef CFRunLoopGetMain(void) { return (__bridge CFRunLoopRef)NSRunLoop.mainRunLoop; }
CFRunLoopMode CFRunLoopCopyCurrentMode(CFRunLoopRef rl) {
    NSString *m = RL(rl).currentMode;
    return m ? (__bridge_retained CFStringRef)[m copy] : NULL;
}
CFArrayRef CFRunLoopCopyAllModes(CFRunLoopRef r) {
    NSRunLoop *rl = RL(r);
    NSMutableSet *modes = [NSMutableSet setWithObject:NSDefaultRunLoopMode];
    pthread_mutex_lock(&rl->_lock);
    [modes unionSet:rl->_commonModes];
    for (__IsimRunLoopItem *it in rl->_items) [modes unionSet:it.modes];
    [modes addObjectsFromArray:rl->_ports.allKeys];
    pthread_mutex_unlock(&rl->_lock);
    @synchronized (rl->_observers) { for (__IsimCFRunLoopObserver *o in rl->_observers) [modes unionSet:o->modes]; }
    [modes removeObject:NSRunLoopCommonModes];
    return (__bridge_retained CFArrayRef)[modes.allObjects sortedArrayUsingSelector:@selector(compare:)];
}
void CFRunLoopAddCommonMode(CFRunLoopRef rl, CFRunLoopMode mode) { isim_runloop_add_common_mode(RL(rl), MODE(mode)); }
CFAbsoluteTime CFRunLoopGetNextTimerFireDate(CFRunLoopRef r, CFRunLoopMode mode) {
    NSRunLoop *rl = RL(r);
    double next = INFINITY;
    pthread_mutex_lock(&rl->_lock);
    for (__IsimRunLoopItem *it in rl->_items) if (it.timer && it.valid && item_in_mode(rl, it, MODE(mode)) && it.fireAt < next) next = it.fireAt;
    pthread_mutex_unlock(&rl->_lock);
    return isinf(next) ? 0 : CFAbsoluteTimeGetCurrent() + (next - mono_now());
}
/* runs the current thread's loop in the default mode until it is stopped or has nothing to wait for */
void CFRunLoopRun(void) {
    NSRunLoop *rl = NSRunLoop.currentRunLoop;
    CFRunLoopRunResult r;
    do r = run_in_mode(rl, NSDefaultRunLoopMode, 1e10, NO);
    while (r != kCFRunLoopRunStopped && r != kCFRunLoopRunFinished);
}
CFRunLoopRunResult CFRunLoopRunInMode(CFRunLoopMode mode, CFTimeInterval seconds, bool returnAfterSourceHandled) {
    if (!mode) return kCFRunLoopRunFinished;
    return run_in_mode(NSRunLoop.currentRunLoop, MODE(mode), seconds, returnAfterSourceHandled);
}
bool CFRunLoopIsWaiting(CFRunLoopRef rl) { return RL(rl)->_waiting; }
void CFRunLoopWakeUp(CFRunLoopRef rl) { [RL(rl) _isim_wake]; }
/* the innermost run of the loop returns (kCFRunLoopRunStopped); UIKit's main event loop itself is not stopped */
void CFRunLoopStop(CFRunLoopRef rl) {
    if (!rl) return;
    RL(rl)->_stopped = YES;
    [RL(rl) _isim_wake];
}
void CFRunLoopPerformBlock(CFRunLoopRef rl, CFTypeRef mode, void (^block)(void)) {
    if (!rl || !mode || !block) return;
    id m = (__bridge id)mode;
    [RL(rl) performInModes:[m isKindOfClass:[NSArray class]] ? m : @[m] block:block];
}

/* ---- observers ---- */
static __IsimCFRunLoopObserver *new_observer(CFOptionFlags activities, bool repeats, CFIndex order) {
    __IsimCFRunLoopObserver *o = [__IsimCFRunLoopObserver new];
    o->activities = activities; o->repeats = repeats; o->order = order; o->valid = YES;
    o->modes = [NSMutableSet set];
    return o;
}
CFTypeID CFRunLoopObserverGetTypeID(void) { return ISIM_CF_RUNLOOP_OBSERVER; }
CFRunLoopObserverRef CFRunLoopObserverCreate(CFAllocatorRef allocator, CFOptionFlags activities, bool repeats, CFIndex order,
                                             CFRunLoopObserverCallBack callout, CFRunLoopObserverContext *context) {
    __IsimCFRunLoopObserver *o = new_observer(activities, repeats, order);
    o->callout = callout;
    if (context) {
        o->context = *context;
        if (context->retain && context->info) o->context.info = (void *)context->retain(context->info);
    }
    return (__bridge_retained CFRunLoopObserverRef)o;
}
CFRunLoopObserverRef CFRunLoopObserverCreateWithHandler(CFAllocatorRef allocator, CFOptionFlags activities, bool repeats, CFIndex order,
                                                        void (^block)(CFRunLoopObserverRef, CFRunLoopActivity)) {
    __IsimCFRunLoopObserver *o = new_observer(activities, repeats, order);
    o->block = [block copy];
    return (__bridge_retained CFRunLoopObserverRef)o;
}
#define OBS(x) ((__bridge __IsimCFRunLoopObserver *)(x))
CFOptionFlags CFRunLoopObserverGetActivities(CFRunLoopObserverRef o) { return OBS(o)->activities; }
bool CFRunLoopObserverDoesRepeat(CFRunLoopObserverRef o) { return OBS(o)->repeats; }
CFIndex CFRunLoopObserverGetOrder(CFRunLoopObserverRef o) { return OBS(o)->order; }
bool CFRunLoopObserverIsValid(CFRunLoopObserverRef o) { return OBS(o)->valid; }
void CFRunLoopObserverGetContext(CFRunLoopObserverRef o, CFRunLoopObserverContext *context) { if (context) *context = OBS(o)->context; }
/* removed from its loop; the callout is not called again */
void CFRunLoopObserverInvalidate(CFRunLoopObserverRef ref) {
    __IsimCFRunLoopObserver *o = OBS(ref);
    o->valid = NO;
    NSRunLoop *rl = o->loop;
    if (rl) @synchronized (rl->_observers) { [rl->_observers removeObjectIdenticalTo:o]; }
}
/* an observer is in one run loop (like CF); adding it again adds the mode */
void CFRunLoopAddObserver(CFRunLoopRef r, CFRunLoopObserverRef ref, CFRunLoopMode mode) {
    __IsimCFRunLoopObserver *o = OBS(ref);
    NSRunLoop *rl = RL(r);
    if (!o || !rl || !mode || !o->valid || (o->loop && o->loop != rl)) return;
    o->loop = rl;
    @synchronized (rl->_observers) {
        [o->modes addObject:MODE(mode)];
        if ([rl->_observers indexOfObjectIdenticalTo:o] == NSNotFound) [rl->_observers addObject:o];
    }
}
void CFRunLoopRemoveObserver(CFRunLoopRef r, CFRunLoopObserverRef ref, CFRunLoopMode mode) {
    __IsimCFRunLoopObserver *o = OBS(ref);
    NSRunLoop *rl = RL(r);
    if (!o || o->loop != rl) return;
    @synchronized (rl->_observers) {
        [o->modes removeObject:MODE(mode)];
        if (!o->modes.count) [rl->_observers removeObjectIdenticalTo:o];
    }
}
bool CFRunLoopContainsObserver(CFRunLoopRef r, CFRunLoopObserverRef ref, CFRunLoopMode mode) {
    __IsimCFRunLoopObserver *o = OBS(ref);
    NSRunLoop *rl = RL(r);
    if (!o || o->loop != rl || !o->valid) return NO;
    @synchronized (rl->_observers) { if ([rl->_observers indexOfObjectIdenticalTo:o] == NSNotFound) return NO; }
    return mode_matches(rl, o->modes, MODE(mode));
}

/* ---- sources ---- */
#define SRC(x) ((__bridge __IsimCFRunLoopSource *)(x))
CFTypeID CFRunLoopSourceGetTypeID(void) { return ISIM_CF_RUNLOOP_SOURCE; }
CFRunLoopSourceRef CFRunLoopSourceCreate(CFAllocatorRef allocator, CFIndex order, CFRunLoopSourceContext *context) {
    if (!context) return NULL;
    __IsimCFRunLoopSource *s = [__IsimCFRunLoopSource new];
    s->order = order; s->valid = YES; s->loops = [NSMutableDictionary dictionary];
    if (context->version == 1) {                  /* Mach port sources: kept (and valid) but never fire */
        CFRunLoopSourceContext1 *c1 = (CFRunLoopSourceContext1 *)context;
        s->mach = YES;
        s->context = (CFRunLoopSourceContext){ .version = 1, .info = c1->info, .retain = c1->retain, .release = c1->release,
                                               .copyDescription = c1->copyDescription, .equal = c1->equal, .hash = c1->hash };
    } else s->context = *context;
    if (s->context.retain && s->context.info) s->context.info = (void *)s->context.retain(s->context.info);
    return (__bridge_retained CFRunLoopSourceRef)s;
}
CFIndex CFRunLoopSourceGetOrder(CFRunLoopSourceRef s) { return SRC(s)->order; }
bool CFRunLoopSourceIsValid(CFRunLoopSourceRef s) { return SRC(s)->valid; }
void CFRunLoopSourceGetContext(CFRunLoopSourceRef s, CFRunLoopSourceContext *context) { if (context) *context = SRC(s)->context; }
/* marks it ready: it is performed the next time one of its loops runs in one of its modes (CFRunLoopWakeUp wakes a
   waiting loop, as on Apple platforms) */
void CFRunLoopSourceSignal(CFRunLoopSourceRef s) { if (SRC(s)->valid) @synchronized (SRC(s)) { SRC(s)->signalled = YES; } }
static void source_cancel(__IsimCFRunLoopSource *s, NSRunLoop *rl, NSString *mode) {
    if (s->context.cancel && !s->mach) s->context.cancel(s->context.info, (__bridge CFRunLoopRef)rl, (__bridge CFRunLoopMode)mode);
}
void CFRunLoopSourceInvalidate(CFRunLoopSourceRef ref) {
    __IsimCFRunLoopSource *s = SRC(ref);
    if (!s->valid) return;
    s->valid = NO;
    NSDictionary *loops;
    @synchronized (s) { loops = [s->loops copy]; [s->loops removeAllObjects]; }
    for (NSValue *v in loops) {
        NSRunLoop *rl = v.nonretainedObjectValue;
        @synchronized (rl->_sources) { [rl->_sources removeObjectIdenticalTo:s]; }
        for (NSString *m in loops[v]) source_cancel(s, rl, m);
    }
}
void CFRunLoopAddSource(CFRunLoopRef r, CFRunLoopSourceRef ref, CFRunLoopMode mode) {
    __IsimCFRunLoopSource *s = SRC(ref);
    NSRunLoop *rl = RL(r);
    if (!s || !rl || !mode || !s->valid) return;
    NSValue *key = [NSValue valueWithNonretainedObject:rl];
    BOOL added = NO;
    @synchronized (s) {
        NSMutableSet *modes = s->loops[key] ?: (s->loops[key] = [NSMutableSet set]);
        if (![modes containsObject:MODE(mode)]) { [modes addObject:MODE(mode)]; added = YES; }
    }
    @synchronized (rl->_sources) { if ([rl->_sources indexOfObjectIdenticalTo:s] == NSNotFound) [rl->_sources addObject:s]; }
    if (added && s->context.schedule && !s->mach) s->context.schedule(s->context.info, r, mode);
    [rl _isim_wake];
}
void CFRunLoopRemoveSource(CFRunLoopRef r, CFRunLoopSourceRef ref, CFRunLoopMode mode) {
    __IsimCFRunLoopSource *s = SRC(ref);
    NSRunLoop *rl = RL(r);
    if (!s || !rl || !mode) return;
    NSValue *key = [NSValue valueWithNonretainedObject:rl];
    BOOL removed = NO, empty = NO;
    @synchronized (s) {
        NSMutableSet *modes = s->loops[key];
        if ([modes containsObject:MODE(mode)]) { [modes removeObject:MODE(mode)]; removed = YES; }
        if (modes && !modes.count) { [s->loops removeObjectForKey:key]; empty = YES; }
    }
    if (empty) @synchronized (rl->_sources) { [rl->_sources removeObjectIdenticalTo:s]; }
    if (removed) source_cancel(s, rl, MODE(mode));
}
bool CFRunLoopContainsSource(CFRunLoopRef r, CFRunLoopSourceRef ref, CFRunLoopMode mode) {
    __IsimCFRunLoopSource *s = SRC(ref);
    NSRunLoop *rl = RL(r);
    if (!s || !rl || !s->valid) return NO;
    NSSet *modes;
    @synchronized (s) { modes = [s->loops[[NSValue valueWithNonretainedObject:rl]] copy]; }
    return modes && mode_matches(rl, modes, MODE(mode));
}

/* ---- timers (toll-free bridged with NSTimer) ---- */
#define TMR(x) ((__bridge NSTimer *)(x))
CFTypeID CFRunLoopTimerGetTypeID(void) { return ISIM_CF_RUNLOOP_TIMER; }
static NSTimer *new_cf_timer(CFAbsoluteTime fireDate, CFTimeInterval interval, CFIndex order) {
    NSDate *at = [NSDate dateWithTimeIntervalSinceReferenceDate:fireDate];
    NSTimer *t = [[NSTimer alloc] initWithIsimFireDate:at interval:interval target:nil selector:NULL userInfo:nil repeats:interval > 0];
    t.isimOrder = order;
    return t;
}
CFRunLoopTimerRef CFRunLoopTimerCreate(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval, CFOptionFlags flags,
                                       CFIndex order, CFRunLoopTimerCallBack callout, CFRunLoopTimerContext *context) {
    NSTimer *t = new_cf_timer(fireDate, interval, order);
    CFRunLoopTimerContext c = context ? *context : (CFRunLoopTimerContext){ 0 };
    if (c.retain && c.info) c.info = (void *)c.retain(c.info);
    t.isimContext = c;
    void *info = c.info;
    __unsafe_unretained NSTimer *weak = t;                 /* the timer owns the block */
    t.timerBlock = ^(NSTimer *fired) { if (callout) callout((__bridge CFRunLoopTimerRef)weak, info); };
    return (__bridge_retained CFRunLoopTimerRef)t;
}
CFRunLoopTimerRef CFRunLoopTimerCreateWithHandler(CFAllocatorRef allocator, CFAbsoluteTime fireDate, CFTimeInterval interval,
                                                  CFOptionFlags flags, CFIndex order, void (^block)(CFRunLoopTimerRef)) {
    NSTimer *t = new_cf_timer(fireDate, interval, order);
    void (^b)(CFRunLoopTimerRef) = [block copy];
    t.timerBlock = ^(NSTimer *fired) { if (b) b((__bridge CFRunLoopTimerRef)fired); };
    return (__bridge_retained CFRunLoopTimerRef)t;
}
CFAbsoluteTime CFRunLoopTimerGetNextFireDate(CFRunLoopTimerRef t) { return TMR(t).fireDate.timeIntervalSinceReferenceDate; }
void CFRunLoopTimerSetNextFireDate(CFRunLoopTimerRef t, CFAbsoluteTime fireDate) {
    TMR(t).fireDate = [NSDate dateWithTimeIntervalSinceReferenceDate:fireDate];
}
CFTimeInterval CFRunLoopTimerGetInterval(CFRunLoopTimerRef t) { return TMR(t).item.repeats ? TMR(t).timeInterval : 0; }
bool CFRunLoopTimerDoesRepeat(CFRunLoopTimerRef t) { return TMR(t).item.repeats; }
CFIndex CFRunLoopTimerGetOrder(CFRunLoopTimerRef t) { return TMR(t).isimOrder; }
void CFRunLoopTimerInvalidate(CFRunLoopTimerRef t) { [TMR(t) invalidate]; }
bool CFRunLoopTimerIsValid(CFRunLoopTimerRef t) { return TMR(t).isValid; }
void CFRunLoopTimerGetContext(CFRunLoopTimerRef t, CFRunLoopTimerContext *context) { if (context) *context = TMR(t).isimContext; }
CFTimeInterval CFRunLoopTimerGetTolerance(CFRunLoopTimerRef t) { return TMR(t).tolerance; }
void CFRunLoopTimerSetTolerance(CFRunLoopTimerRef t, CFTimeInterval tolerance) { TMR(t).tolerance = tolerance; }
void CFRunLoopAddTimer(CFRunLoopRef rl, CFRunLoopTimerRef t, CFRunLoopMode mode) { [RL(rl) addTimer:TMR(t) forMode:MODE(mode)]; }
void CFRunLoopRemoveTimer(CFRunLoopRef r, CFRunLoopTimerRef t, CFRunLoopMode mode) {
    NSRunLoop *rl = RL(r);
    __IsimRunLoopItem *it = TMR(t).item;
    if (!it || it.loop != rl) return;
    pthread_mutex_lock(&rl->_lock);
    [it.modes removeObject:MODE(mode)];
    BOOL empty = it.modes.count == 0;
    if (empty) [rl->_items removeObject:it];
    pthread_mutex_unlock(&rl->_lock);
    if (empty) { it.loop = nil; it.scheduled = nil; }
}
bool CFRunLoopContainsTimer(CFRunLoopRef r, CFRunLoopTimerRef t, CFRunLoopMode mode) {
    NSRunLoop *rl = RL(r);
    __IsimRunLoopItem *it = TMR(t).item;
    if (!it || it.loop != rl || !it.valid) return NO;
    pthread_mutex_lock(&rl->_lock);
    BOOL in = [rl->_items containsObject:it] && item_in_mode(rl, it, MODE(mode));
    pthread_mutex_unlock(&rl->_lock);
    return in;
}
