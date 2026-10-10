/* isim Foundation (ARC): NSOperation, NSBlockOperation, NSInvocationOperation and NSOperationQueue.
 *
 * Operations are KVO-compliant for isReady / isExecuting / isFinished / isCancelled. NSOperation sees its own
 * notifications (-didChangeValueForKey:), including those a subclass posts by hand, so an asynchronous subclass that
 * sends "isFinished" finishes in its queue as on iOS. A queue runs its ready operations (dependencies finished, or
 * cancelled) by priority, then in the order they were added, up to maxConcurrentOperationCount at once, on the
 * global dispatch queue of the operation's quality of service (the main queue for NSOperationQueue.mainQueue, or the
 * underlyingQueue). */
#import <Foundation/Foundation.h>
#include <pthread.h>
#include <time.h>
#include "isim_foundation.h"

NSExceptionName const NSInvocationOperationVoidResultException = @"NSInvocationOperationVoidResultException";
NSExceptionName const NSInvocationOperationCancelledException = @"NSInvocationOperationCancelledException";

@interface NSOperationQueue ()
- (void)_isim_schedule;
- (void)_isim_operationFinished:(NSOperation *)op;
@end

static pthread_key_t current_queue_key;      /* the queue whose operation the thread is running */
static void make_key(void) { pthread_key_create(&current_queue_key, NULL); }
static pthread_once_t key_once = PTHREAD_ONCE_INIT;

static BOOL key_is(NSString *key, NSString *a, NSString *b) { return [key isEqualToString:a] || [key isEqualToString:b]; }

/* ================= NSOperation ================= */
@interface NSOperation () {
@public
    pthread_mutex_t _lock;
    pthread_cond_t _cond;
    BOOL _executing, _finished, _cancelled, _finishHandled, _claimed;
    NSMutableArray<NSOperation *> *_deps;
    NSMutableArray<NSOperation *> *_dependents;     /* operations waiting for this one (cleared when it finishes) */
    __weak NSOperationQueue *_queue;
}
@end

@implementation NSOperation
@synthesize queuePriority = _queuePriority, qualityOfService = _qualityOfService, threadPriority = _threadPriority, name = _name, completionBlock = _completionBlock;
- (instancetype)init {
    if ((self = [super init])) {
        pthread_mutex_init(&_lock, NULL);
        pthread_cond_init(&_cond, NULL);
        _deps = [NSMutableArray array];
        _dependents = [NSMutableArray array];
        _qualityOfService = NSQualityOfServiceDefault;
        _threadPriority = 0.5;
    }
    return self;
}
- (void)dealloc { pthread_mutex_destroy(&_lock); pthread_cond_destroy(&_cond); }
- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p isFinished=%@ isReady=%@ isCancelled=%@ isExecuting=%@>", self.class, self,
            self.isFinished ? @"YES" : @"NO", self.isReady ? @"YES" : @"NO", self.isCancelled ? @"YES" : @"NO", self.isExecuting ? @"YES" : @"NO"];
}
- (BOOL)isExecuting { return _executing; }
- (BOOL)isFinished { return _finished; }
- (BOOL)isCancelled { return _cancelled; }
- (BOOL)isConcurrent { return NO; }
- (BOOL)isAsynchronous { return [self isConcurrent]; }
/* ready when every dependency has finished; a cancelled operation no longer waits for them */
- (BOOL)isReady {
    if (_cancelled) return YES;
    pthread_mutex_lock(&_lock);
    NSArray *deps = [_deps copy];
    pthread_mutex_unlock(&_lock);
    for (NSOperation *d in deps) if (!d.isFinished) return NO;
    return YES;
}
- (void)_isim_readinessChanged { [self willChangeValueForKey:@"isReady"]; [self didChangeValueForKey:@"isReady"]; }
- (NSArray<NSOperation *> *)dependencies {
    pthread_mutex_lock(&_lock);
    NSArray *a = [_deps copy];
    pthread_mutex_unlock(&_lock);
    return a;
}
- (void)addDependency:(NSOperation *)op {
    if (!op) return;
    if (op == self) [NSException raise:NSInvalidArgumentException format:@"*** -[NSOperation addDependency:]: an operation cannot depend on itself"];
    [self willChangeValueForKey:@"dependencies"];
    pthread_mutex_lock(&_lock);
    BOOL added = ![_deps containsObject:op];
    if (added) [_deps addObject:op];
    pthread_mutex_unlock(&_lock);
    [self didChangeValueForKey:@"dependencies"];
    if (!added) return;
    pthread_mutex_lock(&op->_lock);
    BOOL pending = !op->_finishHandled;
    if (pending) [op->_dependents addObject:self];
    pthread_mutex_unlock(&op->_lock);
    if (pending) [self _isim_readinessChanged];
}
- (void)removeDependency:(NSOperation *)op {
    [self willChangeValueForKey:@"dependencies"];
    pthread_mutex_lock(&_lock);
    BOOL had = [_deps containsObject:op];
    [_deps removeObject:op];
    pthread_mutex_unlock(&_lock);
    [self didChangeValueForKey:@"dependencies"];
    if (!had) return;
    pthread_mutex_lock(&op->_lock);
    [op->_dependents removeObject:self];
    pthread_mutex_unlock(&op->_lock);
    [self _isim_readinessChanged];
}
- (void)cancel {
    if (_cancelled || _finished) return;
    [self willChangeValueForKey:@"isCancelled"];
    _cancelled = YES;
    [self didChangeValueForKey:@"isCancelled"];
    [self _isim_readinessChanged];
}
- (void)main {}
- (void)start {
    if (_finished) [NSException raise:NSInvalidArgumentException format:@"*** -[%@ start]: receiver is finished and cannot be started", self.class];
    if (_executing) [NSException raise:NSInvalidArgumentException format:@"*** -[%@ start]: receiver is already executing", self.class];
    if (!_cancelled && !self.isReady) [NSException raise:NSInvalidArgumentException format:@"*** -[%@ start]: receiver is not yet ready to execute", self.class];
    if (!_cancelled) {
        [self willChangeValueForKey:@"isExecuting"];
        _executing = YES;
        [self didChangeValueForKey:@"isExecuting"];
        @autoreleasepool { [self main]; }
        [self willChangeValueForKey:@"isExecuting"];
        _executing = NO;
        [self didChangeValueForKey:@"isExecuting"];
    }
    [self willChangeValueForKey:@"isFinished"];
    _finished = YES;
    [self didChangeValueForKey:@"isFinished"];
}
/* the operation's own KVO notifications (its own or a subclass's) drive the queue */
- (void)didChangeValueForKey:(NSString *)key {
    [super didChangeValueForKey:key];
    if (key_is(key, @"isFinished", @"finished")) { if (self.isFinished) [self _isim_didFinish]; }
    else if (key_is(key, @"isReady", @"ready") || key_is(key, @"isCancelled", @"cancelled")) [_queue _isim_schedule];
}
- (void)_isim_didFinish {
    pthread_mutex_lock(&_lock);
    if (_finishHandled) { pthread_mutex_unlock(&_lock); return; }
    _finishHandled = YES;
    NSArray *dependents = [_dependents copy];
    [_dependents removeAllObjects];
    pthread_cond_broadcast(&_cond);
    pthread_mutex_unlock(&_lock);
    void (^completion)(void) = self.completionBlock;
    if (completion) dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), completion);   /* on another thread, as on iOS */
    [_queue _isim_operationFinished:self];
    for (NSOperation *d in dependents) [d _isim_readinessChanged];
}
- (void)waitUntilFinished {
    pthread_mutex_lock(&_lock);
    while (!_finishHandled && !self.isFinished) {
        struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
        ts.tv_nsec += 100 * 1000000; if (ts.tv_nsec >= 1000000000) { ts.tv_sec++; ts.tv_nsec -= 1000000000; }
        pthread_cond_timedwait(&_cond, &_lock, &ts);
    }
    pthread_mutex_unlock(&_lock);
}
@end

/* ================= NSBlockOperation ================= */
@implementation NSBlockOperation { NSMutableArray *_blocks; }
- (instancetype)init { if ((self = [super init])) _blocks = [NSMutableArray array]; return self; }
+ (instancetype)blockOperationWithBlock:(void (^)(void))block {
    NSBlockOperation *op = [self new];
    [op addExecutionBlock:block];
    return op;
}
- (void)addExecutionBlock:(void (^)(void))block {
    if (self.isExecuting || self.isFinished)
        [NSException raise:NSInvalidArgumentException format:@"*** -[NSBlockOperation addExecutionBlock:]: blocks cannot be added after the operation has started executing or finished"];
    if (!block) return;
    @synchronized (self) { [_blocks addObject:[block copy]]; }
}
- (NSArray<void (^)(void)> *)executionBlocks { @synchronized (self) { return [_blocks copy]; } }
/* the first block on this thread, the others concurrently; finishes when all have returned */
- (void)main {
    NSArray *blocks = self.executionBlocks;
    if (!blocks.count) return;
    dispatch_group_t g = dispatch_group_create();
    dispatch_queue_t q = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
    for (NSUInteger i = 1; i < blocks.count; i++) {
        void (^b)(void) = blocks[i];
        dispatch_group_async(g, q, ^{ @autoreleasepool { b(); } });
    }
    ((void (^)(void))blocks[0])();
    dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
}
@end

/* ================= NSInvocationOperation ================= */
@implementation NSInvocationOperation { NSInvocation *_invocation; BOOL _void; }
- (instancetype)initWithInvocation:(NSInvocation *)inv {
    if ((self = [super init])) { _invocation = inv; _void = inv.methodSignature.methodReturnType[0] == 'v'; }
    return self;
}
- (instancetype)initWithTarget:(id)target selector:(SEL)sel object:(id)arg {
    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    if (!sig) return nil;
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = target; inv.selector = sel;
    if (sig.numberOfArguments > 2) [inv setArgument:&arg atIndex:2];
    [inv retainArguments];
    return [self initWithInvocation:inv];
}
- (instancetype)init { return [self initWithInvocation:[NSInvocation new]]; }
- (NSInvocation *)invocation { return _invocation; }
- (void)main { [_invocation invoke]; }
- (id)result {
    if (self.isCancelled) [NSException raise:NSInvocationOperationCancelledException format:@"*** -[NSInvocationOperation result]: operation was cancelled"];
    if (_void) [NSException raise:NSInvocationOperationVoidResultException format:@"*** -[NSInvocationOperation result]: void result"];
    if (!self.isFinished || _invocation.methodSignature.methodReturnType[0] != '@') return nil;
    __unsafe_unretained id r = nil;
    [_invocation getReturnValue:&r];
    return r;
}
@end

/* ================= NSOperationQueue ================= */
@implementation NSOperationQueue {
    pthread_mutex_t _lock;
    pthread_cond_t _idle;
    NSMutableArray<NSOperation *> *_ops;        /* added and not finished, in the order they were added */
    NSUInteger _running;
    NSUInteger _finishing;                      /* removed, KVO notifications not yet posted */
    NSOperation *_barrier;                      /* the last barrier still pending: later operations wait for it */
    BOOL _isMain;
    NSProgress *_progress;
}
@synthesize name = _name, qualityOfService = _qualityOfService, underlyingQueue = _underlyingQueue;
@synthesize maxConcurrentOperationCount = _maxConcurrentOperationCount, suspended = _suspended;
+ (NSOperationQueue *)mainQueue {
    static NSOperationQueue *m; static dispatch_once_t o;
    dispatch_once(&o, ^{
        m = [NSOperationQueue new];
        m->_isMain = YES; m->_maxConcurrentOperationCount = 1; m->_qualityOfService = NSQualityOfServiceUserInteractive;
        m.name = @"NSOperationQueue Main Queue";
    });
    return m;
}
/* the queue of the operation running on this thread; on the main thread, the main queue */
+ (NSOperationQueue *)currentQueue {
    pthread_once(&key_once, make_key);
    NSOperationQueue *q = (__bridge NSOperationQueue *)pthread_getspecific(current_queue_key);
    if (q) return q;
    return pthread_main_np() ? self.mainQueue : nil;
}
- (instancetype)init {
    if ((self = [super init])) {
        pthread_mutex_init(&_lock, NULL);
        pthread_cond_init(&_idle, NULL);
        _ops = [NSMutableArray array];
        _maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
        _qualityOfService = NSQualityOfServiceDefault;
        _name = [NSString stringWithFormat:@"NSOperationQueue %p", self];
    }
    return self;
}
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p>{name = '%@'}", self.class, self, _name]; }
- (NSInteger)maxConcurrentOperationCount { return _maxConcurrentOperationCount; }
- (BOOL)isSuspended { return _suspended; }
- (void)setMaxConcurrentOperationCount:(NSInteger)n {
    if (_isMain) return;                        /* the main queue is serial */
    [self willChangeValueForKey:@"maxConcurrentOperationCount"];
    _maxConcurrentOperationCount = n;
    [self didChangeValueForKey:@"maxConcurrentOperationCount"];
    [self _isim_schedule];
}
- (void)setSuspended:(BOOL)s {
    [self willChangeValueForKey:@"isSuspended"];
    pthread_mutex_lock(&_lock); _suspended = s; pthread_mutex_unlock(&_lock);
    [self didChangeValueForKey:@"isSuspended"];
    if (!s) [self _isim_schedule];
}
- (NSProgress *)progress {
    @synchronized (self) { if (!_progress) { _progress = [NSProgress discreteProgressWithTotalUnitCount:0]; } return _progress; }
}
- (NSArray<NSOperation *> *)operations {
    pthread_mutex_lock(&_lock);
    NSArray *a = [_ops copy];
    pthread_mutex_unlock(&_lock);
    return a;
}
- (NSUInteger)operationCount {
    pthread_mutex_lock(&_lock);
    NSUInteger n = _ops.count;
    pthread_mutex_unlock(&_lock);
    return n;
}

- (void)_isim_enqueue:(NSArray<NSOperation *> *)ops {
    for (NSOperation *op in ops) {
        if (op->_queue) [NSException raise:NSInvalidArgumentException format:@"*** -[NSOperationQueue addOperation:]: operation is already enqueued on a queue"];
        if (op.isExecuting || op.isFinished)
            [NSException raise:NSInvalidArgumentException format:@"*** -[NSOperationQueue addOperation:]: operation is %@ and cannot be enqueued", op.isFinished ? @"finished" : @"executing"];
    }
    if (!ops.count) return;
    [self willChangeValueForKey:@"operations"];
    [self willChangeValueForKey:@"operationCount"];
    NSOperation *barrier;
    pthread_mutex_lock(&_lock);
    barrier = _barrier;
    for (NSOperation *op in ops) { op->_queue = self; [_ops addObject:op]; }
    pthread_mutex_unlock(&_lock);
    [self didChangeValueForKey:@"operationCount"];
    [self didChangeValueForKey:@"operations"];
    if (barrier) for (NSOperation *op in ops) if (op != barrier) [op addDependency:barrier];
    [self _isim_schedule];
}
- (void)addOperation:(NSOperation *)op { if (op) [self _isim_enqueue:@[op]]; }
- (void)addOperations:(NSArray<NSOperation *> *)ops waitUntilFinished:(BOOL)wait {
    [self _isim_enqueue:ops];
    if (wait) for (NSOperation *op in ops) [op waitUntilFinished];
}
- (void)addOperationWithBlock:(void (^)(void))block { [self addOperation:[NSBlockOperation blockOperationWithBlock:block]]; }
/* runs after every operation added before it, and before every operation added after it */
- (void)addBarrierBlock:(void (^)(void))barrier {
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:barrier];
    for (NSOperation *prior in self.operations) [op addDependency:prior];
    pthread_mutex_lock(&_lock);
    _barrier = op;
    pthread_mutex_unlock(&_lock);
    [self _isim_enqueue:@[op]];
}
- (void)cancelAllOperations { for (NSOperation *op in self.operations) [op cancel]; }
- (void)waitUntilAllOperationsAreFinished {
    if (_isMain && pthread_main_np()) return;          /* would deadlock: the main queue runs on this thread */
    pthread_mutex_lock(&_lock);
    while (_ops.count || _finishing) {
        struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
        ts.tv_nsec += 100 * 1000000; if (ts.tv_nsec >= 1000000000) { ts.tv_sec++; ts.tv_nsec -= 1000000000; }
        pthread_cond_timedwait(&_idle, &_lock, &ts);
    }
    pthread_mutex_unlock(&_lock);
}

static dispatch_queue_t queue_for(NSOperationQueue *q, BOOL isMain, NSOperation *op) {
    if (isMain) return dispatch_get_main_queue();
    if (q.underlyingQueue) return q.underlyingQueue;
    NSQualityOfService qos = op.qualityOfService != NSQualityOfServiceDefault ? op.qualityOfService : q.qualityOfService;
    return dispatch_get_global_queue(qos == NSQualityOfServiceDefault ? QOS_CLASS_DEFAULT : (long)qos, 0);
}
/* starts ready operations while there is room: the highest priority first, then the earliest added */
- (void)_isim_schedule {
    for (;;) {
        pthread_mutex_lock(&_lock);
        NSInteger max = _maxConcurrentOperationCount < 0 ? 64 : _maxConcurrentOperationCount;
        if (_suspended || (NSInteger)_running >= max) { pthread_mutex_unlock(&_lock); return; }
        NSMutableArray *pending = [NSMutableArray array];
        for (NSOperation *op in _ops) if (!op->_claimed) [pending addObject:op];
        pthread_mutex_unlock(&_lock);
        NSOperation *best = nil;
        for (NSOperation *op in pending) if (op.isReady && (!best || op.queuePriority > best.queuePriority)) best = op;
        if (!best) return;
        pthread_mutex_lock(&_lock);
        BOOL go = !best->_claimed && !_suspended && (NSInteger)_running < max && [_ops containsObject:best];
        if (go) { best->_claimed = YES; _running++; }
        pthread_mutex_unlock(&_lock);
        if (!go) continue;
        NSOperationQueue *queue = self;
        NSOperation *op = best;
        dispatch_async(queue_for(self, _isMain, op), ^{
            pthread_once(&key_once, make_key);
            void *saved = pthread_getspecific(current_queue_key);
            pthread_setspecific(current_queue_key, (__bridge void *)queue);
            @autoreleasepool {
                @try { if (!op.isFinished) [op start]; }
                @catch (id e) { pthread_setspecific(current_queue_key, saved); @throw; }
            }
            pthread_setspecific(current_queue_key, saved);
        });
    }
}
- (void)_isim_operationFinished:(NSOperation *)op {
    pthread_mutex_lock(&_lock);
    BOOL present = [_ops containsObject:op];
    pthread_mutex_unlock(&_lock);
    if (!present) return;
    [self willChangeValueForKey:@"operations"];
    [self willChangeValueForKey:@"operationCount"];
    pthread_mutex_lock(&_lock);
    [_ops removeObject:op];
    if (op->_claimed && _running) _running--;
    if (_barrier == op) _barrier = nil;
    _finishing++;
    pthread_mutex_unlock(&_lock);
    [self didChangeValueForKey:@"operationCount"];
    [self didChangeValueForKey:@"operations"];
    pthread_mutex_lock(&_lock);
    _finishing--;
    if (!_ops.count && !_finishing) pthread_cond_broadcast(&_idle);
    pthread_mutex_unlock(&_lock);
    NSProgress *p = _progress;
    if (p && p.totalUnitCount > 0) p.completedUnitCount += 1;
    [self _isim_schedule];
}
@end
