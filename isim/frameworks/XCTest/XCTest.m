/* isim XCTest: test cases, suites, runs, assertions back end, expectations/waiters, observation, and the
 * runner (XCTIsimRunTestBundle) that `isim test` uses for hosted (in the app) and standalone test bundles.
 * Self-authored for isim; output follows Xcode's console format so existing tooling can read it. */
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <pthread.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

/* ---------------- non-local exit for fatal failures (continueAfterFailure = NO, ObjC XCTSkip) ----------------
 * isim has no exception unwinding, so the runner jumps back to the test invocation like XCTest's interruption
 * exception does (skipping the frames in between; their cleanups do not run, as with an exception in ObjC). */
typedef long xct_jmp_buf[8];
__attribute__((naked, returns_twice)) static int xct_setjmp(__attribute__((unused)) xct_jmp_buf b) {
    __asm__ volatile(
        "movq %rbx, 0(%rdi)\n\t movq %rbp, 8(%rdi)\n\t movq %r12, 16(%rdi)\n\t movq %r13, 24(%rdi)\n\t"
        "movq %r14, 32(%rdi)\n\t movq %r15, 40(%rdi)\n\t leaq 8(%rsp), %rdx\n\t movq %rdx, 48(%rdi)\n\t"
        "movq (%rsp), %rdx\n\t movq %rdx, 56(%rdi)\n\t xorl %eax, %eax\n\t ret\n\t");
}
__attribute__((naked, noreturn)) static void xct_longjmp(__attribute__((unused)) xct_jmp_buf b, __attribute__((unused)) int v) {
    __asm__ volatile(
        "movq 0(%rdi), %rbx\n\t movq 8(%rdi), %rbp\n\t movq 16(%rdi), %r12\n\t movq 24(%rdi), %r13\n\t"
        "movq 32(%rdi), %r14\n\t movq 40(%rdi), %r15\n\t movq 48(%rdi), %rsp\n\t movl %esi, %eax\n\t"
        "testl %eax, %eax\n\t jnz 1f\n\t incl %eax\n1:\n\t jmpq *56(%rdi)\n\t");
}

static XCTestCase *current_case;
static pthread_t runner_thread;
static xct_jmp_buf *interrupt_buf;        /* set while a test's synchronous code runs on the runner thread */
static int waiting_depth;                 /* > 0 while the runner spins the run loop (async work in progress) */
static NSMutableArray *observers;
static FILE *out_fp;

static void say(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void say(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    FILE *f = out_fp ?: stdout;
    fputs(s.UTF8String, f); fputc('\n', f); fflush(f);
}
static double now_s(void) { struct timeval tv; gettimeofday(&tv, NULL); return tv.tv_sec + tv.tv_usec / 1e6; }
static NSString *stamp(void) {
    struct timeval tv; gettimeofday(&tv, NULL);
    struct tm tm; time_t t = tv.tv_sec; localtime_r(&t, &tm);
    char buf[64]; strftime(buf, sizeof buf, "%Y-%m-%d %H:%M:%S", &tm);
    return [NSString stringWithFormat:@"%s.%03d", buf, (int)(tv.tv_usec / 1000)];
}

/* Swift class names: _TtC<len><module><len><name> (and nested _TtCC...) -> Module.Name */
static NSString *readable_class_name(Class c) {
    const char *n = class_getName(c);
    if (strncmp(n, "_TtC", 4) != 0) return @(n);
    const char *p = n + 4;
    while (*p == 'C') p++;
    NSMutableArray *parts = [NSMutableArray array];
    while (*p >= '0' && *p <= '9') {
        long len = strtol(p, (char **)&p, 10);
        if (len <= 0 || (long)strlen(p) < len) break;
        [parts addObject:[[NSString alloc] initWithBytes:p length:len encoding:NSUTF8StringEncoding]];
        p += len;
    }
    return parts.count >= 2 ? [parts componentsJoinedByString:@"."] : @(n);
}
static NSString *short_class_name(Class c) {
    NSString *n = readable_class_name(c);
    NSRange r = [n rangeOfString:@"." options:NSBackwardsSearch];
    return r.location == NSNotFound ? n : [n substringFromIndex:r.location + 1];
}
static NSString *test_method_name(SEL sel) {
    NSString *s = NSStringFromSelector(sel);
    for (NSString *suffix in @[@"AndReturnError:", @"WithCompletionHandler:", @":"])
        if ([s hasSuffix:suffix]) return [s substringToIndex:s.length - suffix.length];
    return s;
}

/* ================= XCTest / XCTestRun ================= */
@implementation XCTest
- (NSUInteger)testCaseCount { return 0; }
- (NSString *)name { return @""; }
- (Class)testRunClass { return [XCTestRun class]; }
- (XCTestRun *)testRun { return nil; }
- (void)performTest:(XCTestRun *)run {}
- (void)runTest { XCTestRun *r = [self.testRunClass testRunWithTest:self]; [self performTest:r]; }
- (BOOL)setUpWithError:(NSError **)error { return YES; }
- (void)setUp {}
- (void)tearDown {}
- (BOOL)tearDownWithError:(NSError **)error { return YES; }
@end

@interface XCTestRun ()
@property (readwrite, strong) XCTest *test;
@property NSUInteger ownFailures, ownUnexpected, ownSkips, ownExecutions;
@property double t0, t1;
@end
@implementation XCTestRun
+ (instancetype)testRunWithTest:(XCTest *)test { return [[self alloc] initWithTest:test]; }
- (instancetype)initWithTest:(XCTest *)test { if ((self = [super init])) _test = test; return self; }
- (void)start { _t0 = now_s(); }
- (void)stop { _t1 = now_s(); }
- (NSDate *)startDate { return _t0 ? [NSDate dateWithTimeIntervalSince1970:_t0] : nil; }
- (NSDate *)stopDate { return _t1 ? [NSDate dateWithTimeIntervalSince1970:_t1] : nil; }
- (NSTimeInterval)totalDuration { return _t1 > _t0 ? _t1 - _t0 : 0; }
- (NSTimeInterval)testDuration { return self.totalDuration; }
- (NSUInteger)testCaseCount { return _test.testCaseCount; }
- (NSUInteger)executionCount { return _ownExecutions; }
- (NSUInteger)skipCount { return _ownSkips; }
- (NSUInteger)failureCount { return _ownFailures; }
- (NSUInteger)unexpectedExceptionCount { return _ownUnexpected; }
- (NSUInteger)totalFailureCount { return self.failureCount + self.unexpectedExceptionCount; }
- (BOOL)hasSucceeded { return self.totalFailureCount == 0; }
- (BOOL)hasBeenSkipped { return self.skipCount > 0 && self.executionCount == self.skipCount; }
@end

@implementation XCTestCaseRun
- (void)recordFailureWithDescription:(NSString *)description inFile:(NSString *)filePath atLine:(NSUInteger)lineNumber expected:(BOOL)expected {
    if (expected) self.ownFailures++; else self.ownUnexpected++;
}
@end

@implementation XCTestSuiteRun { NSMutableArray *_runs; }
- (NSArray *)testRuns { return _runs ?: @[]; }
- (void)addTestRun:(XCTestRun *)r { if (!_runs) _runs = [NSMutableArray array]; [_runs addObject:r]; }
- (NSUInteger)executionCount { NSUInteger n = 0; for (XCTestRun *r in _runs) n += r.executionCount; return n; }
- (NSUInteger)skipCount { NSUInteger n = 0; for (XCTestRun *r in _runs) n += r.skipCount; return n; }
- (NSUInteger)failureCount { NSUInteger n = 0; for (XCTestRun *r in _runs) n += r.failureCount; return n; }
- (NSUInteger)unexpectedExceptionCount { NSUInteger n = 0; for (XCTestRun *r in _runs) n += r.unexpectedExceptionCount; return n; }
- (NSTimeInterval)testDuration { double t = 0; for (XCTestRun *r in _runs) t += r.testDuration; return t; }
@end

/* ================= observation ================= */
@implementation XCTestObservationCenter
+ (XCTestObservationCenter *)sharedTestObservationCenter { static XCTestObservationCenter *c; static dispatch_once_t o; dispatch_once(&o, ^{ c = [XCTestObservationCenter new]; }); return c; }
- (void)addTestObserver:(id<XCTestObservation>)o { if (!observers) observers = [NSMutableArray array]; if (o && ![observers containsObject:o]) [observers addObject:o]; }
- (void)removeTestObserver:(id<XCTestObservation>)o { [observers removeObject:o]; }
@end
#define NOTIFY(sel, ...) do { for (id<XCTestObservation> _o in [observers copy]) if ([_o respondsToSelector:@selector(sel)]) [_o __VA_ARGS__]; } while (0)

/* ================= expectations ================= */
@implementation XCTestExpectation { NSUInteger _count; NSInteger _order; }
static NSInteger fulfill_order;
- (instancetype)init { return [self initWithDescription:@"expectation"]; }
- (instancetype)initWithDescription:(NSString *)d {
    if ((self = [super init])) { _expectationDescription = [d copy]; _expectedFulfillmentCount = 1; _assertForOverFulfill = YES; }
    return self;
}
- (void)fulfill {
    BOOL over = NO;
    @synchronized (self) {
        _count++;
        if (_count == _expectedFulfillmentCount) _order = ++fulfill_order;
        if (_count > _expectedFulfillmentCount && _assertForOverFulfill && !_inverted) over = YES;
    }
    if (over) _XCTIsimRecordFailure([NSString stringWithFormat:@"API violation - multiple calls made to -[XCTestExpectation fulfill] for %@.", _expectationDescription], nil, 0, YES);
}
- (BOOL)_isimIsFulfilled { @synchronized (self) { return _count >= _expectedFulfillmentCount; } }
- (BOOL)_isimHasAnyFulfillment { @synchronized (self) { return _count > 0; } }
- (NSInteger)_isim_order { @synchronized (self) { return _order; } }
- (void)_isim_poll {}
- (NSString *)description { return [NSString stringWithFormat:@"Expectation \"%@\"", _expectationDescription]; }
@end

@implementation XCTNSNotificationExpectation { id _token; }
- (instancetype)initWithName:(NSNotificationName)name { return [self initWithName:name object:nil]; }
- (instancetype)initWithName:(NSNotificationName)name object:(id)object {
    if ((self = [super initWithDescription:[NSString stringWithFormat:@"Expect notification '%@'", name]])) {
        _notificationName = [name copy];
        __weak XCTNSNotificationExpectation *weakSelf = self;
        _token = [NSNotificationCenter.defaultCenter addObserverForName:name object:object queue:nil usingBlock:^(NSNotification *n) {
            XCTNSNotificationExpectation *s = weakSelf;
            if (!s) return;
            if (!s.handler || s.handler(n)) [s fulfill];
        }];
    }
    return self;
}
- (void)dealloc { if (_token) [NSNotificationCenter.defaultCenter removeObserver:_token]; }
@end

@implementation XCTNSPredicateExpectation { BOOL _done; }
- (instancetype)initWithPredicate:(NSPredicate *)predicate object:(id)object {
    if ((self = [super initWithDescription:[NSString stringWithFormat:@"Expect predicate `%@` for object %@", predicate, object]])) {
        _predicate = [predicate copy]; _object = object;
    }
    return self;
}
- (void)_isim_poll {
    if (_done) return;
    if ([_predicate evaluateWithObject:_object] && (!_handler || _handler())) { _done = YES; [self fulfill]; }
}
@end

/* spins the main run loop (timers, main-queue blocks, MainActor jobs) until done() or the deadline */
static BOOL spin_until(double deadline, BOOL (^done)(void)) {
    waiting_depth++;
    BOOL ok = NO;
    for (;;) {
        if (done()) { ok = YES; break; }
        if (now_s() >= deadline) break;
        if (pthread_equal(pthread_self(), runner_thread)) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
        else usleep(5000);
    }
    waiting_depth--;
    return ok;
}

@implementation XCTWaiter { NSMutableArray *_fulfilled; }
- (NSArray *)fulfilledExpectations { return _fulfilled ?: @[]; }
+ (XCTWaiterResult)waitForExpectations:(NSArray *)e timeout:(NSTimeInterval)t { return [[self new] waitForExpectations:e timeout:t enforceOrder:NO]; }
+ (XCTWaiterResult)waitForExpectations:(NSArray *)e timeout:(NSTimeInterval)t enforceOrder:(BOOL)o { return [[self new] waitForExpectations:e timeout:t enforceOrder:o]; }
- (XCTWaiterResult)waitForExpectations:(NSArray *)e timeout:(NSTimeInterval)t { return [self waitForExpectations:e timeout:t enforceOrder:NO]; }
- (XCTWaiterResult)waitForExpectations:(NSArray<XCTestExpectation *> *)exps timeout:(NSTimeInterval)t enforceOrder:(BOOL)enforce {
    __block BOOL invertedHit = NO;
    spin_until(now_s() + t, ^BOOL{
        BOOL all = YES;
        for (XCTestExpectation *x in exps) {
            [x _isim_poll];
            if (x.inverted) { if ([x _isimHasAnyFulfillment]) invertedHit = YES; }
            else if (![x _isimIsFulfilled]) all = NO;
        }
        BOOL anyInverted = NO; for (XCTestExpectation *x in exps) if (x.inverted) anyInverted = YES;
        return invertedHit || (all && !anyInverted);       /* inverted expectations wait out the timeout */
    });
    _fulfilled = [NSMutableArray array];
    for (XCTestExpectation *x in exps) if (!x.inverted && [x _isimIsFulfilled]) [_fulfilled addObject:x];
    if (invertedHit) return XCTWaiterResultInvertedFulfillment;
    for (XCTestExpectation *x in exps) if (!x.inverted && ![x _isimIsFulfilled]) return XCTWaiterResultTimedOut;
    if (enforce) {
        NSInteger last = 0;
        for (XCTestExpectation *x in exps) { if (x.inverted) continue; if ([x _isim_order] < last) return XCTWaiterResultIncorrectOrder; last = [x _isim_order]; }
    }
    return XCTWaiterResultCompleted;
}
@end

/* ================= XCTestCase ================= */
@interface XCTestCase ()
@property (strong) XCTestCaseRun *isimRun;
@property (strong) NSMutableArray *teardownBlocks;
@property (strong) NSMutableArray<XCTestExpectation *> *unwaited;
@property BOOL isimSkipped;
@property (copy) NSString *isimSkipMessage;
@property (strong) NSMutableArray *isimFailures;       /* for JUnit: {message, file, line} */
@end

@implementation XCTestCase { SEL _sel; }
+ (instancetype)testCaseWithSelector:(SEL)selector { return [[self alloc] initWithSelector:selector]; }
- (instancetype)init { return [self initWithSelector:NULL]; }
- (instancetype)initWithSelector:(SEL)selector {
    if ((self = [super init])) { _sel = selector; _continueAfterFailure = YES; _executionTimeAllowance = 600; }
    return self;
}
- (SEL)selector { return _sel; }
- (NSUInteger)testCaseCount { return 1; }
- (Class)testRunClass { return [XCTestCaseRun class]; }
- (XCTestRun *)testRun { return _isimRun; }
- (NSString *)name { return [NSString stringWithFormat:@"-[%@ %@]", readable_class_name(self.class), _sel ? test_method_name(_sel) : @"(none)"]; }
- (NSString *)description { return self.name; }
+ (void)setUp {}
+ (void)tearDown {}
- (void)setUpWithCompletionHandler:(void (^)(NSError *))completion { completion(nil); }
- (void)tearDownWithCompletionHandler:(void (^)(NSError *))completion { completion(nil); }
- (void)addTeardownBlock:(void (^)(void))block { if (!_teardownBlocks) _teardownBlocks = [NSMutableArray array]; [_teardownBlocks addObject:[block copy]]; }

+ (NSArray<NSString *> *)testSelectorNames {
    NSMutableOrderedSet *names = [NSMutableOrderedSet orderedSet];
    for (Class c = self; c && c != [XCTestCase class]; c = class_getSuperclass(c)) {
        unsigned n = 0;
        Method *ms = class_copyMethodList(c, &n);
        for (unsigned i = 0; i < n; i++) {
            NSString *s = NSStringFromSelector(method_getName(ms[i]));
            if (![s hasPrefix:@"test"] || s.length <= 4) continue;
            NSUInteger colons = [s componentsSeparatedByString:@":"].count - 1;
            if (colons == 0 || (colons == 1 && ([s hasSuffix:@"AndReturnError:"] || [s hasSuffix:@"WithCompletionHandler:"])))
                [names addObject:s];
        }
        free(ms);
    }
    return [names.array sortedArrayUsingSelector:@selector(compare:)];
}
+ (XCTestSuite *)defaultTestSuite { return [XCTestSuite testSuiteForTestCaseClass:self]; }

- (void)recordFailureWithDescription:(NSString *)d inFile:(NSString *)f atLine:(NSUInteger)l expected:(BOOL)e {
    [_isimRun recordFailureWithDescription:d inFile:f atLine:l expected:e];
    if (!_isimFailures) _isimFailures = [NSMutableArray array];
    [_isimFailures addObject:@{ @"message": d ?: @"", @"file": f ?: @"", @"line": @(l) }];
    say(@"%@:%lu: error: %@ : %@", f.length ? f : @"<unknown>", (unsigned long)l, self.name, d);
    NOTIFY(testCase:didFailWithDescription:inFile:atLine:, testCase:self didFailWithDescription:d inFile:f atLine:l);
}

- (void)measureBlock:(void (^)(void))block {
    NSMutableArray *values = [NSMutableArray array];
    for (int i = 0; i < 10; i++) { double t = now_s(); block(); [values addObject:@(now_s() - t)]; }
    _XCTIsimRecordMeasurement(values, nil, 0);
}

- (XCTestExpectation *)_isim_track:(XCTestExpectation *)e { if (!_unwaited) _unwaited = [NSMutableArray array]; [_unwaited addObject:e]; return e; }
- (XCTestExpectation *)expectationWithDescription:(NSString *)d { return [self _isim_track:[[XCTestExpectation alloc] initWithDescription:d]]; }
- (XCTestExpectation *)expectationForNotification:(NSNotificationName)n object:(id)o handler:(XCNotificationExpectationHandler)h {
    XCTNSNotificationExpectation *e = [[XCTNSNotificationExpectation alloc] initWithName:n object:o]; e.handler = h;
    return [self _isim_track:e];
}
- (XCTestExpectation *)expectationForPredicate:(NSPredicate *)p evaluatedWithObject:(id)o handler:(XCPredicateExpectationHandler)h {
    XCTNSPredicateExpectation *e = [[XCTNSPredicateExpectation alloc] initWithPredicate:p object:o]; e.handler = h;
    return [self _isim_track:e];
}
static NSString *quoted_list(NSArray<XCTestExpectation *> *xs) {
    NSMutableArray *a = [NSMutableArray array];
    for (XCTestExpectation *x in xs) [a addObject:[NSString stringWithFormat:@"\"%@\"", x.expectationDescription]];
    return [a componentsJoinedByString:@", "];
}
- (void)_isim_wait:(NSArray<XCTestExpectation *> *)exps timeout:(NSTimeInterval)t enforceOrder:(BOOL)order handler:(XCWaitCompletionHandler)handler {
    [_unwaited removeObjectsInArray:exps];
    XCTWaiter *w = [XCTWaiter new];
    XCTWaiterResult r = [w waitForExpectations:exps timeout:t enforceOrder:order];
    NSString *msg = nil;
    if (r == XCTWaiterResultTimedOut) {
        NSMutableArray *un = [NSMutableArray array];
        for (XCTestExpectation *x in exps) if (!x.inverted && ![w.fulfilledExpectations containsObject:x]) [un addObject:x];
        msg = [NSString stringWithFormat:@"Asynchronous wait failed: Exceeded timeout of %g seconds, with unfulfilled expectations: %@.", t, quoted_list(un)];
    } else if (r == XCTWaiterResultInvertedFulfillment) {
        NSMutableArray *inv = [NSMutableArray array];
        for (XCTestExpectation *x in exps) if (x.inverted && [x _isimHasAnyFulfillment]) [inv addObject:x];
        msg = [NSString stringWithFormat:@"Asynchronous wait failed: Fulfilled inverted expectation %@.", quoted_list(inv)];
    } else if (r == XCTWaiterResultIncorrectOrder) {
        msg = [NSString stringWithFormat:@"Failed due to expectation fulfilled in incorrect order: requires %@.", quoted_list(exps)];
    }
    if (handler) handler(msg ? [NSError errorWithDomain:@"XCTestErrorDomain" code:r userInfo:@{ NSLocalizedDescriptionKey: msg }] : nil);
    if (msg) _XCTIsimRecordFailure(msg, nil, 0, YES);
}
- (void)waitForExpectationsWithTimeout:(NSTimeInterval)t handler:(XCWaitCompletionHandler)h {
    NSArray *all = [_unwaited copy] ?: @[];
    if (!all.count) { _XCTIsimRecordFailure(@"API violation - call made to wait without any expectations having been set.", nil, 0, YES); return; }
    [self _isim_wait:all timeout:t enforceOrder:NO handler:h];
}
- (void)waitForExpectations:(NSArray *)e timeout:(NSTimeInterval)t { [self _isim_wait:e timeout:t enforceOrder:NO handler:nil]; }
- (void)waitForExpectations:(NSArray *)e timeout:(NSTimeInterval)t enforceOrder:(BOOL)o { [self _isim_wait:e timeout:t enforceOrder:o handler:nil]; }

/* runs one test: setUp variants, the test method, tearDown variants, teardown blocks */
static BOOL handle_error(XCTestCase *tc, NSError *err, NSString *where) {
    if (!err) return YES;
    if ([err.domain isEqualToString:@"XCTSkip"]) {
        tc.isimSkipped = YES;
        tc.isimSkipMessage = err.userInfo[@"message"] ?: @"";
        return NO;
    }
    if ([err.domain isEqualToString:@"XCTIsimRecordedFailure"]) return NO;          /* XCTUnwrap & co. already recorded it */
    NSString *what = err.userInfo[@"description"] ?: err.localizedDescription;
    _XCTIsimRecordFailure([NSString stringWithFormat:@"%@caught error: \"%@\"", where, what], err.userInfo[@"file"], [err.userInfo[@"line"] unsignedIntegerValue], NO);
    return NO;
}
static BOOL call_async(XCTestCase *tc, SEL sel, NSString *where) {
    __block volatile int done = 0;
    __block NSError *error = nil;
    void (^completion)(NSError *) = ^(NSError *e) { error = e; __atomic_store_n(&done, 1, __ATOMIC_RELEASE); };
    ((void (*)(id, SEL, id))objc_msgSend)(tc, sel, completion);
    BOOL finished = spin_until(now_s() + tc.executionTimeAllowance, ^BOOL{ return __atomic_load_n(&done, __ATOMIC_ACQUIRE) != 0; });
    if (!finished) {
        _XCTIsimRecordFailure([NSString stringWithFormat:@"Test exceeded execution time allowance of %g seconds", tc.executionTimeAllowance], nil, 0, NO);
        return NO;
    }
    return handle_error(tc, error, where);
}
static BOOL overrides(XCTestCase *tc, SEL sel) {
    return class_getMethodImplementation(object_getClass(tc), sel) != class_getMethodImplementation([XCTestCase class], sel);
}
- (void)invokeTest {
    SEL sel = _sel;
    NSString *s = NSStringFromSelector(sel);
    BOOL ok = YES;
    if (overrides(self, @selector(setUpWithCompletionHandler:))) ok = call_async(self, @selector(setUpWithCompletionHandler:), @"setUp() ");
    if (ok && !_isimSkipped) { NSError *e = nil; if (![self setUpWithError:&e]) ok = handle_error(self, e ?: [NSError errorWithDomain:@"XCTest" code:0 userInfo:nil], @"setUpWithError() "); }
    if (ok && !_isimSkipped) [self setUp];
    if (ok && !_isimSkipped) {
        if ([s hasSuffix:@"WithCompletionHandler:"]) call_async(self, sel, @"");
        else if ([s hasSuffix:@"AndReturnError:"]) {
            NSError *e = nil;
            BOOL r = ((BOOL (*)(id, SEL, NSError **))objc_msgSend)(self, sel, &e);
            if (!r) handle_error(self, e ?: [NSError errorWithDomain:@"XCTest" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"unknown error" }], @"");
        } else ((void (*)(id, SEL))objc_msgSend)(self, sel);
    }
}
- (void)_isim_tearDown {
    for (void (^b)(void) in [_teardownBlocks reverseObjectEnumerator]) b();
    _teardownBlocks = nil;
    [self tearDown];
    NSError *e = nil;
    if (![self tearDownWithError:&e] && e) handle_error(self, e, @"tearDownWithError() ");
    if (overrides(self, @selector(tearDownWithCompletionHandler:))) call_async(self, @selector(tearDownWithCompletionHandler:), @"tearDown() ");
}
- (void)performTest:(XCTestRun *)run {
    _isimRun = (XCTestCaseRun *)run;
    current_case = self;
    NOTIFY(testCaseWillStart:, testCaseWillStart:self);
    say(@"Test Case '%@' started.", self.name);
    [run start];
    @autoreleasepool {
        xct_jmp_buf buf;
        if (xct_setjmp(buf) == 0) {
            interrupt_buf = &buf;
            [self invokeTest];
        }
        interrupt_buf = NULL;
        if (xct_setjmp(buf) == 0) {
            interrupt_buf = &buf;
            [self _isim_tearDown];
        }
        interrupt_buf = NULL;
        if (_unwaited.count && !_isimSkipped) {
            NSArray *u = _unwaited; _unwaited = nil;
            _XCTIsimRecordFailure([NSString stringWithFormat:@"Failed due to unwaited expectation%@ %@.", u.count > 1 ? @"s" : @"", quoted_list(u)], nil, 0, YES);
        }
    }
    [run stop];
    XCTestRun *r = run;
    r.ownExecutions = 1;
    if (_isimSkipped && r.totalFailureCount == 0) r.ownSkips = 1;
    NSString *result = r.totalFailureCount ? @"failed" : _isimSkipped ? @"skipped" : @"passed";
    say(@"Test Case '%@' %@ (%.3f seconds).", self.name, result, r.totalDuration);
    NOTIFY(testCaseDidFinish:, testCaseDidFinish:self);
    current_case = nil;
}
@end

/* ================= assertion back end ================= */
XCTestCase *_XCTCurrentTestCase(void) { return current_case; }

static void maybe_interrupt(void) {
    if (interrupt_buf && !waiting_depth && pthread_equal(pthread_self(), runner_thread)) {
        xct_jmp_buf *b = interrupt_buf; interrupt_buf = NULL;
        xct_longjmp(*b, 1);
    }
}
void _XCTIsimRecordFailure(NSString *description, NSString *filePath, NSUInteger line, BOOL expected) {
    XCTestCase *tc = current_case;
    if (!tc) { say(@"%@:%lu: error: %@ (outside of a test)", filePath ?: @"<unknown>", (unsigned long)line, description); return; }
    @synchronized (tc) { [tc recordFailureWithDescription:description inFile:filePath ?: @"" atLine:line expected:expected]; }
    if (!tc.continueAfterFailure) maybe_interrupt();
}
void _XCTIsimRecordSkip(NSString *message, NSString *filePath, NSUInteger line) {
    XCTestCase *tc = current_case;
    if (!tc) return;
    tc.isimSkipped = YES;
    tc.isimSkipMessage = message ?: @"";
    say(@"%@:%lu: %@ : Test skipped%@%@", filePath ?: @"<unknown>", (unsigned long)line, tc.name, message.length ? @" - " : @"", message ?: @"");
    maybe_interrupt();
}
void _XCTIsimRecordMeasurement(NSArray<NSNumber *> *values, NSString *filePath, NSUInteger line) {
    double sum = 0, sq = 0;
    for (NSNumber *v in values) sum += v.doubleValue;
    double avg = values.count ? sum / values.count : 0;
    for (NSNumber *v in values) sq += (v.doubleValue - avg) * (v.doubleValue - avg);
    double sd = values.count > 1 ? sqrt(sq / (values.count - 1)) : 0;
    NSMutableArray *vs = [NSMutableArray array];
    for (NSNumber *v in values) [vs addObject:[NSString stringWithFormat:@"%.6f", v.doubleValue]];
    say(@"%@:%lu: Test Case '%@' measured [Time, seconds] average: %.6f, relative standard deviation: %.3f%%, values: [%@]",
        filePath ?: @"<unknown>", (unsigned long)line, current_case.name, avg, avg > 0 ? sd / avg * 100 : 0, [vs componentsJoinedByString:@", "]);
}
NSString *_XCTIsimFormat(NSString *format, ...) {
    if (!format.length) return @"";
    va_list ap; va_start(ap, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    return [@" - " stringByAppendingString:s];
}
NSString *_XCTIsimDescribe(const char *t, const void *v) {
    switch (*t) {
    case 'c': return [NSString stringWithFormat:@"%d", *(const signed char *)v];
    case 'C': return [NSString stringWithFormat:@"%u", *(const unsigned char *)v];
    case 'B': return *(const _Bool *)v ? @"1" : @"0";
    case 's': return [NSString stringWithFormat:@"%d", *(const short *)v];
    case 'S': return [NSString stringWithFormat:@"%u", *(const unsigned short *)v];
    case 'i': return [NSString stringWithFormat:@"%d", *(const int *)v];
    case 'I': return [NSString stringWithFormat:@"%u", *(const unsigned *)v];
    case 'l': return [NSString stringWithFormat:@"%ld", *(const long *)v];
    case 'L': return [NSString stringWithFormat:@"%lu", *(const unsigned long *)v];
    case 'q': return [NSString stringWithFormat:@"%lld", *(const long long *)v];
    case 'Q': return [NSString stringWithFormat:@"%llu", *(const unsigned long long *)v];
    case 'f': return [NSString stringWithFormat:@"%g", *(const float *)v];
    case 'd': return [NSString stringWithFormat:@"%g", *(const double *)v];
    case '@': return [NSString stringWithFormat:@"%@", *(const id *)v];
    case '*': return *(const char *const *)v ? @(*(const char *const *)v) : @"(null)";
    case '^': return [NSString stringWithFormat:@"%p", *(const void *const *)v];
    case ':': return NSStringFromSelector(*(const SEL *)v);
    case '#': return NSStringFromClass(*(const Class *)v);
    default: return [NSString stringWithFormat:@"<%s>", t];
    }
}

/* ================= XCTestSuite ================= */
@implementation XCTestSuite { NSString *_name; NSMutableArray *_tests; }
+ (instancetype)defaultTestSuite { return [self testSuiteWithName:@"All tests"]; }
+ (instancetype)testSuiteWithName:(NSString *)name { return [[self alloc] initWithName:name]; }
- (instancetype)initWithName:(NSString *)name { if ((self = [super init])) { _name = [name copy]; _tests = [NSMutableArray array]; } return self; }
+ (instancetype)testSuiteForTestCaseClass:(Class)c {
    XCTestSuite *s = [self testSuiteWithName:short_class_name(c)];
    for (NSString *sel in [c testSelectorNames]) [s addTest:[c testCaseWithSelector:NSSelectorFromString(sel)]];
    objc_setAssociatedObject(s, "isimClass", c, OBJC_ASSOCIATION_ASSIGN);
    return s;
}
- (NSString *)name { return _name; }
- (NSArray *)tests { return _tests; }
- (void)addTest:(XCTest *)t { [_tests addObject:t]; }
- (NSUInteger)testCaseCount { NSUInteger n = 0; for (XCTest *t in _tests) n += t.testCaseCount; return n; }
- (Class)testRunClass { return [XCTestSuiteRun class]; }
- (void)performTest:(XCTestRun *)run {
    XCTestSuiteRun *sr = (XCTestSuiteRun *)run;
    Class cls = objc_getAssociatedObject(self, "isimClass");
    NOTIFY(testSuiteWillStart:, testSuiteWillStart:self);
    say(@"Test Suite '%@' started at %@", _name, stamp());
    [run start];
    if (cls) [cls setUp];
    for (XCTest *t in _tests) {
        XCTestRun *r = [t.testRunClass testRunWithTest:t];
        [sr addTestRun:r];
        [t performTest:r];
    }
    if (cls) [cls tearDown];
    [run stop];
    NSUInteger n = run.executionCount, f = run.totalFailureCount, u = run.unexpectedExceptionCount, sk = run.skipCount;
    say(@"Test Suite '%@' %@ at %@.", _name, f ? @"failed" : @"passed", stamp());
    say(@"\t Executed %lu test%@, with %@%lu failure%@ (%lu unexpected) in %.3f (%.3f) seconds", (unsigned long)n, n == 1 ? @"" : @"s",
        sk ? [NSString stringWithFormat:@"%lu test%@ skipped and ", (unsigned long)sk, sk == 1 ? @"" : @"s"] : @"",
        (unsigned long)f, f == 1 ? @"" : @"s", (unsigned long)u, run.testDuration, run.totalDuration);
    NOTIFY(testSuiteDidFinish:, testSuiteDidFinish:self);
}
@end

/* ================= runner ================= */
static NSArray<NSString *> *env_list(const char *name) {
    const char *v = getenv(name);
    if (!v || !*v) return @[];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *s in [@(v) componentsSeparatedByString:@","]) {
        NSString *t = [[s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] stringByReplacingOccurrencesOfString:@"()" withString:@""];
        if (t.length) [out addObject:t];
    }
    return out;
}
/* identifiers: Bundle, Bundle/Class, Bundle/Class/test, Class, Class/test (Swift class names with or without module) */
static BOOL id_matches(NSString *ident, NSString *bundle, Class c, NSString *method) {
    NSArray *p = [ident componentsSeparatedByString:@"/"];
    NSString *cls = short_class_name(c), *full = readable_class_name(c);
    BOOL (^clsMatch)(NSString *) = ^BOOL(NSString *x) { return [x isEqualToString:cls] || [x isEqualToString:full]; };
    if (p.count == 1) return [p[0] isEqualToString:bundle] || clsMatch(p[0]);
    if (p.count == 2)                    /* Class/test, or Bundle/Class (a class may be named like its bundle) */
        return (clsMatch(p[0]) && (!method || [p[1] isEqualToString:method])) || ([p[0] isEqualToString:bundle] && clsMatch(p[1]));
    return [p[0] isEqualToString:bundle] && clsMatch(p[1]) && (!method || [p[2] isEqualToString:method]);
}
static NSString *xml_escape(NSString *s) {
    s = [s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    s = [s stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    return [s stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
}
static void write_junit(const char *path, NSString *bundleName, XCTestSuite *all, XCTestSuiteRun *run) {
    NSMutableString *x = [NSMutableString stringWithString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
    [x appendFormat:@"<testsuites name=\"%@\" tests=\"%lu\" failures=\"%lu\" skipped=\"%lu\" time=\"%.3f\">\n", xml_escape(bundleName),
        (unsigned long)run.executionCount, (unsigned long)run.totalFailureCount, (unsigned long)run.skipCount, run.totalDuration];
    for (XCTestSuiteRun *bundleRun in run.testRuns) for (XCTestSuiteRun *cr in bundleRun.testRuns) {
        XCTestSuite *cs = (XCTestSuite *)cr.test;
        [x appendFormat:@"  <testsuite name=\"%@\" tests=\"%lu\" failures=\"%lu\" skipped=\"%lu\" time=\"%.3f\">\n", xml_escape(cs.name),
            (unsigned long)cr.executionCount, (unsigned long)cr.totalFailureCount, (unsigned long)cr.skipCount, cr.totalDuration];
        for (XCTestRun *tr in cr.testRuns) {
            XCTestCase *tc = (XCTestCase *)tr.test;
            Class c = tc.class;
            [x appendFormat:@"    <testcase classname=\"%@\" name=\"%@\" time=\"%.3f\"", xml_escape(readable_class_name(c)), xml_escape(test_method_name(tc.selector)), tr.totalDuration];
            if (!tc.isimFailures.count && !tc.isimSkipped) { [x appendString:@"/>\n"]; continue; }
            [x appendString:@">\n"];
            for (NSDictionary *f in tc.isimFailures)
                [x appendFormat:@"      <failure message=\"%@\">%@:%@</failure>\n", xml_escape(f[@"message"]), xml_escape(f[@"file"]), f[@"line"]];
            if (tc.isimSkipped && !tc.isimFailures.count) [x appendFormat:@"      <skipped message=\"%@\"/>\n", xml_escape(tc.isimSkipMessage ?: @"")];
            [x appendString:@"    </testcase>\n"];
        }
        [x appendString:@"  </testsuite>\n"];
    }
    [x appendString:@"</testsuites>\n"];
    [x writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

/* Swift Testing (isim's build of swift-testing, libswiftTesting.dylib): runs @Test functions of every loaded image */
typedef void (*swift_testing_done)(int exitCode, void *context);
typedef void (*swift_testing_entry)(int argc, const char *const *argv, swift_testing_done done, void *context);
static volatile int st_finished, st_code;
static void st_done(int code, void *ctx) { st_code = code; __atomic_store_n(&st_finished, 1, __ATOMIC_RELEASE); }
static NSString *regex_escape(NSString *s) {
    NSMutableString *o = [NSMutableString string];
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (strchr("\\^$.|?*+()[]{}", c) && c < 128) [o appendString:@"\\"];
        [o appendFormat:@"%C", c];
    }
    return o;
}
static int run_swift_testing(swift_testing_entry entry, NSArray<NSString *> *only, NSArray<NSString *> *skip, NSString *bundleBase) {
    NSMutableArray *args = [NSMutableArray arrayWithObject:@"xctest"];
    for (NSString *o in only) {          /* [Bundle/]Suite/test -> a filter on the test ID */
        NSArray *p = [o componentsSeparatedByString:@"/"];
        if ([p.firstObject isEqualToString:bundleBase]) p = [p subarrayWithRange:NSMakeRange(1, p.count - 1)];
        if (!p.count) continue;                                       /* the whole bundle: no filter */
        [args addObjectsFromArray:@[@"--filter", regex_escape([p componentsJoinedByString:@"/"])]];
    }
    if (only.count && args.count == 1) { /* only other bundles/classes selected */ }
    for (NSString *s in skip) [args addObjectsFromArray:@[@"--skip", regex_escape(s)]];
    const char *xunit = getenv("ISIM_SWIFT_TESTING_XUNIT");
    if (xunit && *xunit) [args addObjectsFromArray:@[@"--xunit-output", @(xunit)]];
    const char **argv = calloc(args.count + 1, sizeof *argv);
    for (NSUInteger i = 0; i < args.count; i++) argv[i] = [args[i] UTF8String];
    st_finished = 0;
    entry((int)args.count, argv, st_done, NULL);
    spin_until(now_s() + 3600, ^BOOL{ return __atomic_load_n(&st_finished, __ATOMIC_ACQUIRE) != 0; });
    free(argv);
    return st_code;
}

int XCTIsimRunTestBundle(const char *bundlePath) {
    runner_thread = pthread_self();
    NSString *bundle = [@(bundlePath) stringByStandardizingPath];
    NSString *bundleName = bundle.lastPathComponent;
    NSString *bundleBase = [bundleName stringByDeletingPathExtension];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[bundle stringByAppendingPathComponent:@"Info.plist"]];
    NSString *exe = [bundle stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: bundleBase];
    void *h = dlopen(exe.UTF8String, RTLD_NOW);
    if (!h) { fprintf(stderr, "xctest: cannot load %s: %s\n", exe.UTF8String, dlerror() ?: "?"); return 70; }
    const char *outPath = getenv("ISIM_XCTEST_OUTPUT");
    if (outPath && *outPath) out_fp = fopen(outPath, "a");
    NSArray *only = env_list("ISIM_XCTEST_ONLY"), *skip = env_list("ISIM_XCTEST_SKIP");

    /* discovery: XCTestCase subclasses whose code is in the bundle's executable */
    char *real = realpath(exe.UTF8String, NULL);
    unsigned n = 0;
    Class *classes = objc_copyClassList(&n);
    NSMutableArray *testClasses = [NSMutableArray array];
    for (unsigned i = 0; i < n; i++) {
        Class c = classes[i];
        BOOL isCase = NO;
        for (Class s = class_getSuperclass(c); s; s = class_getSuperclass(s)) if (s == [XCTestCase class]) { isCase = YES; break; }
        if (!isCase) continue;
        Dl_info di;
        if (!dladdr((__bridge void *)c, &di) || !di.dli_fname) continue;
        char *cr = realpath(di.dli_fname, NULL);
        BOOL mine = cr && real && !strcmp(cr, real);
        free(cr);
        if (mine) [testClasses addObject:c];
    }
    free(classes); free(real);
    [testClasses sortUsingComparator:^NSComparisonResult(Class a, Class b) { return [short_class_name(a) compare:short_class_name(b)]; }];

    XCTestSuite *all = [XCTestSuite testSuiteWithName:@"All tests"];
    XCTestSuite *bsuite = [XCTestSuite testSuiteWithName:bundleName];
    [all addTest:bsuite];
    for (Class c in testClasses) {
        XCTestSuite *cs = [XCTestSuite testSuiteWithName:short_class_name(c)];
        objc_setAssociatedObject(cs, "isimClass", c, OBJC_ASSOCIATION_ASSIGN);
        for (NSString *selName in [c testSelectorNames]) {
            NSString *m = test_method_name(NSSelectorFromString(selName));
            BOOL want = only.count == 0;
            for (NSString *o in only) if (id_matches(o, bundleBase, c, m)) want = YES;
            for (NSString *s in skip) if (id_matches(s, bundleBase, c, m)) want = NO;
            if (want) [cs addTest:[c testCaseWithSelector:NSSelectorFromString(selName)]];
        }
        if (cs.tests.count) [bsuite addTest:cs];
    }

    NOTIFY(testBundleWillStart:, testBundleWillStart:[NSBundle bundleWithPath:bundle]);
    XCTestSuiteRun *run = (XCTestSuiteRun *)[XCTestSuiteRun testRunWithTest:all];
    [all performTest:run];
    NOTIFY(testBundleDidFinish:, testBundleDidFinish:[NSBundle bundleWithPath:bundle]);
    const char *junit = getenv("ISIM_XCTEST_JUNIT");
    if (junit && *junit) write_junit(junit, bundleName, all, run);
    int rc = run.totalFailureCount ? 1 : 0;

    /* Swift Testing (@Test functions) in the same bundle, when isim's Testing library is present */
    swift_testing_entry st = (swift_testing_entry)dlsym(RTLD_DEFAULT, "isim_swift_testing_run");
    if (st && !getenv("ISIM_XCTEST_NO_SWIFT_TESTING")) {
        int src = run_swift_testing(st, only, skip, bundleBase);
        if (src == 1) rc = 1;                   /* 69: no @Test functions matched (e.g. none in this bundle) */
    }
    if (out_fp) { fclose(out_fp); out_fp = NULL; }
    return rc;
}
