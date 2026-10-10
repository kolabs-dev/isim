// Foundation self-test for the isim runtime. Prints PASS/FAIL per check; exit code = failures.
#import <Foundation/Foundation.h>
#include <errno.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <pthread.h>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (%s:%d)\n", #cond, __FILE__, __LINE__); } } while (0)

static int deallocs;
@interface Tracked : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, weak) Tracked *peer;
@property (nonatomic, strong) NSMutableArray *items;
@end
@implementation Tracked
- (void)dealloc { deallocs++; }
@end

/* an NSError subclass with its own state, archived through super (issue #39) */
@interface TaggedError : NSError
@property (nonatomic, copy) NSString *tag;
@end
@implementation TaggedError
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [super encodeWithCoder:c]; [c encodeObject:self.tag forKey:@"tag"]; }
- (instancetype)initWithCoder:(NSCoder *)c { if ((self = [super initWithCoder:c])) _tag = [c decodeObjectOfClass:[NSString class] forKey:@"tag"]; return self; }
@end

/* NSDecimalNumber, NSPredicate / NSExpression additions, Progress file properties (#12) */
@interface Shelf : NSObject
@property (copy) NSString *name;
@property (strong) NSArray *books;
@property (strong) NSDictionary *tags;
@end
@implementation Shelf
- (NSNumber *)doubled:(NSNumber *)n { return @(n.integerValue * 2); }
- (BOOL)isNamed:(NSString *)n { return [self.name isEqualToString:n]; }
@end
static void collection_checks(void) {
    // NSDecimalNumber: exact arithmetic, rounding behaviors, exceptions, NSDecimal C API
    NSDecimalNumber *a = [NSDecimalNumber decimalNumberWithString:@"0.1"], *b = [NSDecimalNumber decimalNumberWithString:@"0.2"];
    CHECK([[[a decimalNumberByAdding:b] stringValue] isEqualToString:@"0.3"]);
    CHECK([[[NSDecimalNumber decimalNumberWithString:@"1"] decimalNumberByDividingBy:[NSDecimalNumber decimalNumberWithString:@"3"]].stringValue isEqualToString:@"0.33333333333333333333333333333333333333"]);
    CHECK([[[NSDecimalNumber decimalNumberWithString:@"123.456"] decimalNumberByMultiplyingBy:[NSDecimalNumber decimalNumberWithString:@"-2"]].stringValue isEqualToString:@"-246.912"]);
    CHECK([[[NSDecimalNumber decimalNumberWithString:@"1.5"] decimalNumberByRaisingToPower:3].stringValue isEqualToString:@"3.375"]);
    CHECK([[[NSDecimalNumber decimalNumberWithMantissa:12345 exponent:-2 isNegative:YES] stringValue] isEqualToString:@"-123.45"]);
    NSDecimalNumberHandler *cents = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundBankers scale:2 raiseOnExactness:NO raiseOnOverflow:NO raiseOnUnderflow:NO raiseOnDivideByZero:NO];
    CHECK([[[NSDecimalNumber decimalNumberWithString:@"2.345"] decimalNumberByRoundingAccordingToBehavior:cents].stringValue isEqualToString:@"2.34"] &&
          [[[NSDecimalNumber decimalNumberWithString:@"2.355"] decimalNumberByRoundingAccordingToBehavior:cents].stringValue isEqualToString:@"2.36"]);
    NSDecimalNumberHandler *down = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundDown scale:0 raiseOnExactness:NO raiseOnOverflow:NO raiseOnUnderflow:NO raiseOnDivideByZero:NO];
    CHECK([[[NSDecimalNumber decimalNumberWithString:@"-1.2"] decimalNumberByRoundingAccordingToBehavior:down].stringValue isEqualToString:@"-2"]);
    CHECK([[NSDecimalNumber.one decimalNumberByDividingBy:NSDecimalNumber.zero withBehavior:cents] isEqual:NSDecimalNumber.notANumber]);
    BOOL raised = NO;
    @try { [NSDecimalNumber.one decimalNumberByDividingBy:NSDecimalNumber.zero]; } @catch (NSException *e) { raised = [e.name isEqualToString:NSDecimalNumberDivideByZeroException]; }
    CHECK(raised);
    CHECK([[NSDecimalNumber decimalNumberWithString:@"10"] compare:@9.5] == NSOrderedDescending && [[NSDecimalNumber decimalNumberWithString:@"2.50"] isEqual:@2.5] &&
          [NSDecimalNumber decimalNumberWithString:@"abc"] == NSDecimalNumber.notANumber || [[NSDecimalNumber decimalNumberWithString:@"abc"] isEqual:NSDecimalNumber.notANumber]);
    CHECK([[NSDecimalNumber decimalNumberWithString:@"3,25" locale:@{ NSLocaleDecimalSeparator: @"," }].stringValue isEqualToString:@"3.25"] &&
          [[[NSDecimalNumber decimalNumberWithString:@"3.25"] descriptionWithLocale:[NSLocale localeWithLocaleIdentifier:@"de_DE"]] isEqualToString:@"3,25"]);
    CHECK(fabs([NSDecimalNumber decimalNumberWithString:@"1e3"].doubleValue - 1000) < 1e-9 && strcmp([a objCType], "d") == 0 && [a isKindOfClass:[NSNumber class]]);
    NSDecimal x = [NSDecimalNumber decimalNumberWithString:@"7.125"].decimalValue, y = [@2 decimalValue], r;
    CHECK(NSDecimalMultiply(&r, &x, &y, NSRoundPlain) == NSCalculationNoError && [NSDecimalString(&r, nil) isEqualToString:@"14.25"]);
    NSDecimalRound(&r, &x, 2, NSRoundPlain);
    CHECK([NSDecimalString(&r, nil) isEqualToString:@"7.13"] && NSDecimalCompare(&x, &y) == NSOrderedDescending);
    NSDecimal d1 = [@0.1 decimalValue];
    CHECK([NSDecimalString(&d1, nil) isEqualToString:@"0.1"]);
    NSDecimalNumber *archived = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSDecimalNumber class] fromData:[NSKeyedArchiver archivedDataWithRootObject:a requiringSecureCoding:YES error:NULL] error:NULL];
    CHECK([archived isEqual:a]);

    // NSPredicate / NSExpression: subqueries, functions, index access, set expressions, TERNARY, custom selectors
    Shelf *s1 = [Shelf new]; s1.name = @"fiction"; s1.books = @[@{ @"title": @"Dune", @"pages": @412 }, @{ @"title": @"Emma", @"pages": @474 }, @{ @"title": @"Ubik", @"pages": @202 }];
    s1.tags = @{ @"color": @"red" };
    Shelf *s2 = [Shelf new]; s2.name = @"poems"; s2.books = @[@{ @"title": @"Odes", @"pages": @80 }];
    NSArray *shelves = @[s1, s2];
    NSPredicate *sub = [NSPredicate predicateWithFormat:@"SUBQUERY(books, $b, $b.pages > 400).@count >= 2"];
    CHECK([[shelves filteredArrayUsingPredicate:sub] isEqual:@[s1]] && [sub.predicateFormat containsString:@"SUBQUERY(books, $b, $b.pages > 400)"]);
    CHECK([[[NSExpression expressionWithFormat:@"sum:(books.pages)"] expressionValueWithObject:s1 context:nil] isEqual:@1088]);
    CHECK([[[NSExpression expressionWithFormat:@"average:({1, 2, 3, 4})"] expressionValueWithObject:nil context:nil] isEqual:@2.5]);
    CHECK([[[NSExpression expressionWithFormat:@"median:({5, 1, 3})"] expressionValueWithObject:nil context:nil] isEqual:@3]);
    CHECK([[[NSExpression expressionWithFormat:@"modulus:by:(17, 5)"] expressionValueWithObject:nil context:nil] isEqual:@2]);
    CHECK([[[NSExpression expressionWithFormat:@"2 ** 10"] expressionValueWithObject:nil context:nil] isEqual:@1024]);
    CHECK([[[NSExpression expressionWithFormat:@"sqrt:(16) + abs:(-2)"] expressionValueWithObject:nil context:nil] doubleValue] == 6);
    CHECK([[[NSExpression expressionWithFormat:@"uppercase:(name)"] expressionValueWithObject:s1 context:nil] isEqual:@"FICTION"]);
    CHECK([[[NSExpression expressionWithFormat:@"books[FIRST].title"] expressionValueWithObject:s1 context:nil] isEqual:@"Dune"] &&
          [[[NSExpression expressionWithFormat:@"books[LAST]"] expressionValueWithObject:s1 context:nil][@"title"] isEqual:@"Ubik"] &&
          [[[NSExpression expressionWithFormat:@"books[SIZE]"] expressionValueWithObject:s1 context:nil] isEqual:@3] &&
          [[[NSExpression expressionWithFormat:@"books[1]"] expressionValueWithObject:s1 context:nil][@"title"] isEqual:@"Emma"] &&
          [[[NSExpression expressionWithFormat:@"tags['color']"] expressionValueWithObject:s1 context:nil] isEqual:@"red"]);
    CHECK([[NSPredicate predicateWithFormat:@"FUNCTION(SELF, 'doubled:', 21) == 42"] evaluateWithObject:s1]);
    CHECK([[NSPredicate predicateWithFormat:@"TERNARY(name == 'poems', 1, 0) == 1"] evaluateWithObject:s2]);
    NSSet *u = [[NSExpression expressionWithFormat:@"{1, 2} UNION {2, 3}"] expressionValueWithObject:nil context:nil];
    NSSet *i = [[NSExpression expressionWithFormat:@"{1, 2} INTERSECT {2, 3}"] expressionValueWithObject:nil context:nil];
    NSSet *m = [[NSExpression expressionWithFormat:@"{1, 2} MINUS {2, 3}"] expressionValueWithObject:nil context:nil];
    CHECK(u.count == 3 && [i isEqual:[NSSet setWithObject:@2]] && [m isEqual:[NSSet setWithObject:@1]]);
    NSPredicate *custom = [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForEvaluatedObject] rightExpression:[NSExpression expressionForConstantValue:@"poems"] customSelector:@selector(isNamed:)];
    CHECK([[shelves filteredArrayUsingPredicate:custom] isEqual:@[s2]] && ((NSComparisonPredicate *)custom).customSelector == @selector(isNamed:));
    CHECK(([[NSPredicate predicateWithFormat:@"%@ UTI-CONFORMS-TO 'public.image'", @"public.png"] evaluateWithObject:nil] &&
           ![[NSPredicate predicateWithFormat:@"%@ UTI-CONFORMS-TO 'public.image'", @"public.plain-text"] evaluateWithObject:nil]));
    CHECK(([[NSPredicate predicateWithFormat:@"CAST(0, 'NSDate') < %@", [NSDate date]] evaluateWithObject:nil]));
    NSPredicate *withVar = [[NSPredicate predicateWithFormat:@"SUBQUERY(books, $b, $b.pages > $min).@count == 1"] predicateWithSubstitutionVariables:@{ @"min": @450 }];
    CHECK([withVar evaluateWithObject:s1]);
    NSPredicate *roundTrip = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSPredicate class] fromData:[NSKeyedArchiver archivedDataWithRootObject:sub requiringSecureCoding:YES error:NULL] error:NULL];
    CHECK([roundTrip evaluateWithObject:s1] && ![roundTrip evaluateWithObject:s2]);

    // Progress: file properties, time remaining, throughput, performAsCurrent
    NSProgress *file = [NSProgress progressWithTotalUnitCount:40 * 1000 * 1000];
    file.kind = NSProgressKindFile;
    file.fileOperationKind = NSProgressFileOperationKindDownloading;
    file.fileURL = [NSURL fileURLWithPath:@"/tmp/movie.mov"];
    file.completedUnitCount = 12 * 1000 * 1000;
    file.throughput = @(1200 * 1000);
    file.estimatedTimeRemaining = @(130);
    CHECK([file.localizedDescription isEqualToString:@"Downloading “movie.mov”…"]);
    CHECK([file.localizedAdditionalDescription containsString:@" of "] && [file.localizedAdditionalDescription containsString:@"/sec)"] &&
          [file.localizedAdditionalDescription hasSuffix:@"About 2 minutes remaining"]);
    CHECK([file.userInfo[NSProgressThroughputKey] isEqual:@(1200 * 1000)] && [file.userInfo[NSProgressFileOperationKindKey] isEqual:NSProgressFileOperationKindDownloading]);
    file.fileTotalCount = @5; file.fileCompletedCount = @2;
    CHECK([file.localizedDescription isEqualToString:@"Downloading 5 files…"] && [file.localizedAdditionalDescription hasPrefix:@"2 of 5 files"]);
    NSProgress *parent = [NSProgress progressWithTotalUnitCount:10];
    [parent performAsCurrentWithPendingUnitCount:4 usingBlock:^{
        NSProgress *child = [NSProgress progressWithTotalUnitCount:2];
        child.completedUnitCount = 2;
    }];
    CHECK(parent.completedUnitCount == 4 && NSProgress.currentProgress == nil);
}

/* operations, threads and run loops (#12) */
@interface AsyncOp : NSOperation
@property (atomic) BOOL running, done;
@property (atomic, strong) NSMutableArray *log;
@end
@implementation AsyncOp
- (BOOL)isAsynchronous { return YES; }
- (BOOL)isExecuting { return self.running; }
- (BOOL)isFinished { return self.done; }
- (void)start {
    [self willChangeValueForKey:@"isExecuting"]; self.running = YES; [self didChangeValueForKey:@"isExecuting"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_global_queue(0, 0), ^{
        @synchronized (self.log) { [self.log addObject:@"async"]; }
        [self willChangeValueForKey:@"isFinished"]; [self willChangeValueForKey:@"isExecuting"];
        self.running = NO; self.done = YES;
        [self didChangeValueForKey:@"isExecuting"]; [self didChangeValueForKey:@"isFinished"];
    });
}
@end
@interface CountObserver : NSObject
@property (atomic) int changes;
@end
@implementation CountObserver
- (void)observeValueForKeyPath:(NSString *)k ofObject:(id)o change:(NSDictionary *)c context:(void *)ctx { self.changes++; }
@end
@interface ThreadHelper : NSObject
@property (atomic, strong) NSThread *ranOn;
@property (atomic, strong) NSMutableArray *log;
@end
@implementation ThreadHelper
- (void)note:(NSString *)s { self.ranOn = NSThread.currentThread; @synchronized (self.log) { [self.log addObject:s]; } }
- (NSString *)echo:(NSString *)s { return [s stringByAppendingString:@"!"]; }
@end
static BOOL spin_until(BOOL (^cond)(void), double seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!cond() && end.timeIntervalSinceNow > 0) [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    return cond();
}
static void thread_checks(void) {
    // dependencies, priorities, a serial queue
    NSOperationQueue *q = [NSOperationQueue new];
    q.maxConcurrentOperationCount = 1;
    q.suspended = YES;
    NSMutableArray *order = [NSMutableArray array];
    NSBlockOperation *a = [NSBlockOperation blockOperationWithBlock:^{ @synchronized (order) { [order addObject:@"a"]; } }];
    NSBlockOperation *b = [NSBlockOperation blockOperationWithBlock:^{ @synchronized (order) { [order addObject:@"b"]; } }];
    NSBlockOperation *c = [NSBlockOperation blockOperationWithBlock:^{ @synchronized (order) { [order addObject:@"c"]; } }];
    NSBlockOperation *hi = [NSBlockOperation blockOperationWithBlock:^{ @synchronized (order) { [order addObject:@"hi"]; } }];
    hi.queuePriority = NSOperationQueuePriorityVeryHigh;
    [a addDependency:b];                                // b before a, though a was added first
    __block BOOL completed = NO;
    c.completionBlock = ^{ completed = YES; };
    CHECK(!a.isReady && b.isReady && [a.dependencies isEqual:@[b]]);
    CountObserver *obs = [CountObserver new];
    [q addObserver:obs forKeyPath:@"operationCount" options:0 context:NULL];
    [q addOperations:@[a, b, c, hi] waitUntilFinished:NO];
    CHECK(q.operationCount == 4 && q.operations.count == 4 && obs.changes == 1);
    q.suspended = NO;
    [q waitUntilAllOperationsAreFinished];
    CHECK([order isEqual:(@[@"hi", @"b", @"a", @"c"])]);
    if (![order isEqual:(@[@"hi", @"b", @"a", @"c"])]) NSLog(@"operation order: %@", order);
    CHECK(a.isFinished && !a.isExecuting && q.operationCount == 0 && obs.changes == 5 && spin_until(^{ return completed; }, 2));
    [q removeObserver:obs forKeyPath:@"operationCount"];
    // cancelling: a cancelled operation does not run, finishes, ignores its dependencies
    NSOperationQueue *q2 = [NSOperationQueue new];
    __block BOOL ran = NO;
    NSBlockOperation *never = [NSBlockOperation blockOperationWithBlock:^{ ran = YES; }];
    NSBlockOperation *gate = [NSBlockOperation blockOperationWithBlock:^{}];
    [never addDependency:gate];
    [q2 addOperation:never];
    CHECK(!never.isReady);
    [never cancel];
    CHECK(never.isCancelled && never.isReady);
    [never waitUntilFinished];
    CHECK(never.isFinished && !ran);
    // an asynchronous subclass finishes through its own KVO notifications; its dependents wait for it
    AsyncOp *async = [AsyncOp new]; async.log = [NSMutableArray array];
    NSBlockOperation *after = [NSBlockOperation blockOperationWithBlock:^{ @synchronized (async.log) { [async.log addObject:@"after"]; } }];
    [after addDependency:async];
    [q2 addOperations:@[after, async] waitUntilFinished:YES];
    CHECK([async.log isEqual:(@[@"async", @"after"])] && async.isFinished && q2.operationCount == 0);
    // concurrency limit, currentQueue, multiple execution blocks
    NSOperationQueue *q3 = [NSOperationQueue new];
    q3.maxConcurrentOperationCount = 2; q3.name = @"limited";
    __block int now = 0, peak = 0;
    __block NSOperationQueue *seen = nil;
    for (int i = 0; i < 6; i++)
        [q3 addOperationWithBlock:^{
            @synchronized (q3) { now++; if (now > peak) peak = now; }
            seen = NSOperationQueue.currentQueue;
            [NSThread sleepForTimeInterval:0.03];
            @synchronized (q3) { now--; }
        }];
    [q3 waitUntilAllOperationsAreFinished];
    CHECK(peak == 2 && seen == q3 && NSOperationQueue.currentQueue == NSOperationQueue.mainQueue);
    NSBlockOperation *multi = [NSBlockOperation new];
    __block int blocks = 0;
    for (int i = 0; i < 3; i++) [multi addExecutionBlock:^{ @synchronized (q3) { blocks++; } }];
    [q3 addOperations:@[multi] waitUntilFinished:YES];
    CHECK(blocks == 3 && multi.executionBlocks.count == 3);
    // a barrier waits for earlier operations; later ones wait for it
    NSMutableArray *bar = [NSMutableArray array];
    NSOperationQueue *q4 = [NSOperationQueue new];
    [q4 addOperationWithBlock:^{ [NSThread sleepForTimeInterval:0.05]; @synchronized (bar) { [bar addObject:@"slow"]; } }];
    [q4 addBarrierBlock:^{ @synchronized (bar) { [bar addObject:@"barrier"]; } }];
    [q4 addOperationWithBlock:^{ @synchronized (bar) { [bar addObject:@"later"]; } }];
    [q4 waitUntilAllOperationsAreFinished];
    CHECK([bar isEqual:(@[@"slow", @"barrier", @"later"])]);
    // main queue operations run on the main thread; NSInvocationOperation
    __block BOOL onMain = NO;
    [NSOperationQueue.mainQueue addOperationWithBlock:^{ onMain = NSThread.isMainThread; }];
    CHECK(spin_until(^{ return onMain; }, 2));
    ThreadHelper *h = [ThreadHelper new]; h.log = [NSMutableArray array];
    NSInvocationOperation *inv = [[NSInvocationOperation alloc] initWithTarget:h selector:@selector(echo:) object:@"hey"];
    [q3 addOperations:@[inv] waitUntilFinished:YES];
    CHECK([inv.result isEqualToString:@"hey!"]);
    BOOL threw = NO;
    @try { [inv start]; } @catch (NSException *e) { threw = [e.name isEqualToString:NSInvalidArgumentException]; }
    CHECK(threw);                                       // finished operations cannot start again

    // NSThread with its own run loop: a timer, performs from other threads, a port keeping it alive
    __block NSRunLoop *threadLoop = nil;
    __block int ticks = 0;
    __block BOOL loopExited = NO;
    NSThread *worker = [[NSThread alloc] initWithBlock:^{
        threadLoop = NSRunLoop.currentRunLoop;
        [NSTimer scheduledTimerWithTimeInterval:0.01 repeats:YES block:^(NSTimer *t) { if (++ticks == 3) [t invalidate]; }];
        [NSRunLoop.currentRunLoop addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
        while (!NSThread.currentThread.isCancelled) [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        loopExited = YES;
    }];
    worker.name = @"isim-worker";
    [worker start];
    CHECK(spin_until(^{ return (BOOL)(ticks == 3 && threadLoop != nil); }, 3));
    CHECK(threadLoop != NSRunLoop.mainRunLoop && worker.isExecuting && [worker.name isEqualToString:@"isim-worker"] && NSThread.isMultiThreaded);
    [h performSelector:@selector(note:) onThread:worker withObject:@"waited" waitUntilDone:YES];
    CHECK(h.ranOn == worker && [h.log isEqual:@[@"waited"]]);
    [h performSelector:@selector(note:) onThread:worker withObject:@"later" waitUntilDone:NO];
    CHECK(spin_until(^{ return (BOOL)(h.log.count == 2); }, 2));
    [worker cancel];
    CHECK(spin_until(^{ return (BOOL)(loopExited && worker.isFinished); }, 2));
    [h performSelectorInBackground:@selector(note:) withObject:@"background"];
    CHECK(spin_until(^{ return (BOOL)(h.log.count == 3 && h.ranOn != NSThread.mainThread); }, 2));
    [h performSelectorOnMainThread:@selector(note:) withObject:@"main" waitUntilDone:YES];
    CHECK(h.ranOn == NSThread.mainThread);
    __block BOOL fromBackground = NO;
    [NSThread detachNewThreadWithBlock:^{
        [h performSelectorOnMainThread:@selector(note:) withObject:@"to main" waitUntilDone:YES];   // waits for the main loop
        fromBackground = h.ranOn == NSThread.mainThread;
    }];
    CHECK(spin_until(^{ return fromBackground; }, 2));
    // a run loop with nothing to wait for returns at once; ports and timers are per mode
    __block BOOL returned = NO, customFired = NO, defaultFiredInCustom = NO, commonFired = NO;
    [NSThread detachNewThreadWithBlock:^{
        NSRunLoop *rl = NSRunLoop.currentRunLoop;
        BOOL r1 = [rl runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        [rl run];                                       // returns: no input sources
        returned = !r1 && rl.currentMode == nil && [rl limitDateForMode:NSDefaultRunLoopMode] == nil;
        NSTimer *custom = [NSTimer timerWithTimeInterval:0.01 repeats:NO block:^(NSTimer *t) { customFired = [rl.currentMode isEqualToString:@"isim.custom"]; }];
        NSTimer *plain = [NSTimer timerWithTimeInterval:0.01 repeats:NO block:^(NSTimer *t) { defaultFiredInCustom = YES; }];
        NSTimer *common = [NSTimer timerWithTimeInterval:0.01 repeats:NO block:^(NSTimer *t) { commonFired = YES; }];
        [rl addTimer:custom forMode:@"isim.custom"];
        [rl addTimer:plain forMode:NSDefaultRunLoopMode];
        [rl addTimer:common forMode:NSRunLoopCommonModes];
        [rl runMode:@"isim.custom" beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        [rl runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }];
    CHECK(spin_until(^{ return returned; }, 2) && spin_until(^{ return customFired; }, 2));
    CHECK(!defaultFiredInCustom || commonFired);        // the default timer only fires once the loop runs in the default mode
    CHECK(spin_until(^{ return commonFired; }, 2));
    // delayed performs in modes, cancelling them; ordered performs
    NSMutableArray *performed = [NSMutableArray array];
    ThreadHelper *ph = [ThreadHelper new]; ph.log = performed;
    [ph performSelector:@selector(note:) withObject:@"x" afterDelay:0.01 inModes:@[NSDefaultRunLoopMode]];
    [ph performSelector:@selector(note:) withObject:@"cancelled" afterDelay:0.01];
    [NSObject cancelPreviousPerformRequestsWithTarget:ph selector:@selector(note:) object:@"cancelled"];
    [NSRunLoop.mainRunLoop performSelector:@selector(note:) target:ph argument:@"second" order:2 modes:@[NSDefaultRunLoopMode]];
    [NSRunLoop.mainRunLoop performSelector:@selector(note:) target:ph argument:@"first" order:1 modes:@[NSDefaultRunLoopMode]];
    [NSRunLoop.mainRunLoop performBlock:^{ @synchronized (performed) { [performed addObject:@"block"]; } }];
    CHECK(spin_until(^{ return (BOOL)(performed.count == 4); }, 2));
    CHECK(performed.count == 4 && [performed[0] isEqual:@"first"] && [performed[1] isEqual:@"second"] && [performed containsObject:@"x"] &&
          ![performed containsObject:@"cancelled"]);
    if (performed.count != 4 || ![performed[0] isEqual:@"first"]) NSLog(@"performs: %@", performed);
    // timers: fire date, tolerance, validity
    NSTimer *later = [NSTimer timerWithTimeInterval:10 repeats:NO block:^(NSTimer *t) {}];
    later.tolerance = 0.5;
    CHECK(later.isValid && later.tolerance == 0.5 && fabs(later.fireDate.timeIntervalSinceNow - 10) < 1);
    [later invalidate];
    CHECK(!later.isValid);
    CHECK(NSThread.callStackSymbols.count > 1 && NSThread.callStackReturnAddresses.count > 1 && NSThread.mainThread.isMainThread &&
          [NSThread.currentThread.threadDictionary isKindOfClass:[NSMutableDictionary class]]);
}

static int initialized;
@interface Lazy : NSObject @end
@implementation Lazy
+ (void)initialize { if (self == [Lazy class]) initialized++; }
+ (int)value { return 7; }
@end

@interface NSString (Shout)
- (NSString *)shout;
@end
@implementation NSString (Shout)
- (NSString *)shout { return [[self uppercaseString] stringByAppendingString:@"!"]; }
@end

@interface Base : NSObject
- (NSString *)who;
@end
@implementation Base { int _baseIvar; }
- (instancetype)init { if ((self = [super init])) _baseIvar = 11; return self; }
- (NSString *)who { return [NSString stringWithFormat:@"base%d", _baseIvar]; }
@end
@interface Derived : Base { @public int _mine; }
@end
@implementation Derived
- (instancetype)init { if ((self = [super init])) _mine = 22; return self; }
- (NSString *)who { return [[super who] stringByAppendingFormat:@"+derived%d", _mine]; }
@end

@interface Person : NSObject { NSString *_hidden; }
@property (nonatomic, copy) NSString *name;
@property (nonatomic) NSInteger age;
@property (nonatomic) double score;
@property (nonatomic, strong) Person *friend;
@end
@implementation Person
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_name forKey:@"name"]; [c encodeInteger:_age forKey:@"age"]; [c encodeObject:_friend forKey:@"friend"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) { _name = [c decodeObjectForKey:@"name"]; _age = [c decodeIntegerForKey:@"age"]; _friend = [c decodeObjectForKey:@"friend"]; }
    return self;
}
@end
@interface AgeWatcher : NSObject
@property (nonatomic, strong) NSMutableArray<NSString *> *changes;
@end
@implementation AgeWatcher
- (instancetype)init { if ((self = [super init])) _changes = [NSMutableArray array]; return self; }
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [_changes addObject:[NSString stringWithFormat:@"%@->%@", change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]]];
}
@end


/* locale data from the host's ICU: collation, case rules, locales and calendars the built-in tables lack (#12) */
#define CHECK_STR(expr, want) do { NSString *got_ = (expr); checks++; if ([got_ isEqualToString:(want)]) printf("PASS  %s == %s\n", #expr, [(want) UTF8String]); \
    else { failures++; printf("FAIL  %s == %s  (got \"%s\") (%s:%d)\n", #expr, [(want) UTF8String], got_ ? got_.UTF8String : "nil", __FILE__, __LINE__); } } while (0)
static void locale_checks(void) {
    NSLocale *fr = [NSLocale localeWithLocaleIdentifier:@"fr_FR"], *sv = [NSLocale localeWithLocaleIdentifier:@"sv_SE"], *de = [NSLocale localeWithLocaleIdentifier:@"de_DE"];
    NSLocale *ru = [NSLocale localeWithLocaleIdentifier:@"ru_RU"], *tr = [NSLocale localeWithLocaleIdentifier:@"tr_TR"];
    /* collation */
    CHECK([@"é" compare:@"f" options:0 range:NSMakeRange(0, 1) locale:fr] == NSOrderedAscending && [@"é" compare:@"f"] == NSOrderedDescending);
    CHECK([@"ä" compare:@"z" options:0 range:NSMakeRange(0, 1) locale:sv] == NSOrderedDescending && [@"ä" compare:@"z" options:0 range:NSMakeRange(0, 1) locale:de] == NSOrderedAscending);
    CHECK([@"file10" localizedStandardCompare:@"file9"] == NSOrderedDescending && [@"apple" localizedCaseInsensitiveCompare:@"Banana"] == NSOrderedAscending);
    CHECK([@"cote" compare:@"Côte" options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch range:NSMakeRange(0, 4) locale:fr] == NSOrderedSame);
    NSArray *sorted = [@[@"Zoë", @"zebra", @"Émile", @"eagle"] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    CHECK_STR([sorted componentsJoinedByString:@","], @"eagle,Émile,zebra,Zoë");
    /* case rules */
    CHECK_STR([@"istanbul" uppercaseStringWithLocale:tr], @"İSTANBUL");
    CHECK_STR([@"TITLE" lowercaseStringWithLocale:tr], @"tıtle");
    /* a locale without a built-in table: Russian */
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:1792065600];        /* 2026-10-15 12:00 UTC */
    NSDateFormatter *df = [NSDateFormatter new]; df.locale = ru; df.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    df.dateStyle = NSDateFormatterLongStyle;
    CHECK_STR([df stringFromDate:d], @"15 октября 2026\u202Fг.");
    df.dateFormat = @"EEEE, d MMMM y";
    CHECK_STR([df stringFromDate:d], @"четверг, 15 октября 2026");
    CHECK([[df dateFromString:@"четверг, 15 октября 2026"] isEqualToDate:[NSDate dateWithTimeIntervalSince1970:1792022400]]);
    CHECK_STR(df.standaloneMonthSymbols[9], @"октябрь");
    CHECK_STR([NSDateFormatter dateFormatFromTemplate:@"yMMMd" options:0 locale:ru], @"d MMM y\u202F'г'.");
    NSNumberFormatter *nf = [NSNumberFormatter new]; nf.locale = ru; nf.numberStyle = NSNumberFormatterDecimalStyle;
    CHECK_STR([nf stringFromNumber:@1234567.5], @"1\u00A0234\u00A0567,5");
    nf.numberStyle = NSNumberFormatterCurrencyStyle;
    CHECK_STR([nf stringFromNumber:@1234.5], @"1\u00A0234,50\u00A0₽");
    nf.numberStyle = NSNumberFormatterSpellOutStyle;
    CHECK_STR([nf stringFromNumber:@42], @"сорок два");
    nf.locale = de; CHECK_STR([nf stringFromNumber:@42], @"zwei\u00ADund\u00ADvierzig");
    nf.locale = [NSLocale localeWithLocaleIdentifier:@"de_CH"]; nf.numberStyle = NSNumberFormatterDecimalStyle;
    CHECK_STR([nf stringFromNumber:@1234.5], @"1’234.5");
    nf.locale = fr; nf.numberStyle = NSNumberFormatterCurrencyPluralStyle; nf.currencyCode = @"USD";
    CHECK_STR([nf stringFromNumber:@2], @"2,00 dollars des États-Unis");
    NSRelativeDateTimeFormatter *rel = [NSRelativeDateTimeFormatter new]; rel.locale = ru;
    CHECK_STR([rel localizedStringFromTimeInterval:3 * 86400], @"через 3 дня");
    rel.dateTimeStyle = NSRelativeDateTimeFormatterStyleNamed;
    CHECK_STR([rel localizedStringFromTimeInterval:-86400], @"вчера");
    NSListFormatter *lf = [NSListFormatter new]; lf.locale = ru;
    CHECK_STR(([lf stringFromItems:@[@"чай", @"кофе", @"сок"]]), @"чай, кофе и сок");
    NSMeasurementFormatter *mf = [NSMeasurementFormatter new]; mf.locale = ru; mf.unitStyle = NSFormattingUnitStyleLong;
    mf.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
    CHECK_STR([mf stringFromMeasurement:[[NSMeasurement alloc] initWithDoubleValue:5 unit:NSUnitLength.kilometers]], @"5 километров");
    NSDateComponentsFormatter *dcf = [NSDateComponentsFormatter new]; dcf.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    dcf.calendar.locale = ru;
    CHECK_STR([dcf stringFromTimeInterval:3700], @"1 час 1 минута 40 секунд");
    NSDateIntervalFormatter *itv = [NSDateIntervalFormatter new]; itv.locale = ru; itv.timeZone = df.timeZone;
    itv.dateStyle = NSDateIntervalFormatterMediumStyle; itv.timeStyle = NSDateIntervalFormatterNoStyle;
    CHECK_STR([itv stringFromDate:d toDate:[d dateByAddingTimeInterval:3 * 86400]], @"15–18 окт. 2026\u202Fг.");
    CHECK_STR([fr localizedStringForLanguageCode:@"en"], @"anglais");
    CHECK_STR([ru localizedStringForCountryCode:@"DE"], @"Германия");
    CHECK_STR([[NSLocale localeWithLocaleIdentifier:@"en_US"] localizedStringForCurrencyCode:@"EUR"], @"Euro");
    /* calendars */
    NSLocale *hebrew = [NSLocale localeWithLocaleIdentifier:@"en_US@calendar=hebrew"];
    CHECK([hebrew.calendarIdentifier isEqualToString:NSCalendarIdentifierHebrew] && [hebrew.countryCode isEqualToString:@"US"]);
    NSDateFormatter *hf = [NSDateFormatter new]; hf.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"]; hf.timeZone = df.timeZone;
    hf.calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierHebrew]; hf.dateFormat = @"d MMMM y";
    CHECK_STR([hf stringFromDate:d], @"4 Heshvan 5787");
    hf.calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierJapanese]; hf.dateFormat = @"GGGG y";
    CHECK_STR([hf stringFromDate:d], @"Reiwa 8");
    hf.calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierBuddhist]; hf.dateFormat = @"y G";
    CHECK_STR([hf stringFromDate:d], @"2569 BE");
    CHECK_STR(hf.quarterSymbols.firstObject, @"1st quarter");
}


/* files: resource values, socket / bound streams, FileHandle background notifications, iCloud documents (#12) */
static int listen_local(int *port) {
    int s = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in a = { .sin_family = AF_INET, .sin_port = 0 };
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(s, (struct sockaddr *)&a, sizeof a) || listen(s, 4)) { close(s); return -1; }
    socklen_t len = sizeof a; getsockname(s, (struct sockaddr *)&a, &len);
    *port = ntohs(a.sin_port);
    return s;
}
static void *echo_server(void *arg) {
    int s = (int)(intptr_t)arg, c = accept(s, NULL, NULL);
    char buf[256]; ssize_t n;
    while ((n = read(c, buf, sizeof buf)) > 0) write(c, buf, (size_t)n);
    close(c); close(s);
    return NULL;
}
@interface StreamEvents : NSObject <NSStreamDelegate>
@property NSUInteger events;
@end
@implementation StreamEvents
- (void)stream:(NSStream *)s handleEvent:(NSStreamEvent)e { self.events |= e; }
@end
@interface TestPresenter : NSObject <NSFilePresenter>
@property (copy) NSURL *presentedItemURL;
@property (retain) NSOperationQueue *presentedItemOperationQueue;
@property (atomic) int changes, saves;
@end
@implementation TestPresenter
- (void)presentedItemDidChange { self.changes++; }
- (void)savePresentedItemChangesWithCompletionHandler:(void (^)(NSError *))done { self.saves++; done(nil); }
@end

static void file_checks(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSURL *note = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"note.txt"]];
    [@"hello" writeToURL:note atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    /* resource values: content types, the data volume, stored values, temporary values */
    NSDictionary *rv = [note resourceValuesForKeys:@[NSURLTypeIdentifierKey, NSURLLocalizedTypeDescriptionKey, NSURLVolumeTotalCapacityKey,
                                                     NSURLVolumeAvailableCapacityForImportantUsageKey, NSURLVolumeNameKey, NSURLVolumeSupportsCaseSensitiveNamesKey,
                                                     NSURLIsUbiquitousItemKey, NSURLFileProtectionKey] error:NULL];
    CHECK([rv[NSURLTypeIdentifierKey] isEqualToString:@"public.plain-text"] && [rv[NSURLLocalizedTypeDescriptionKey] length] > 0);
    CHECK([rv[NSURLVolumeTotalCapacityKey] longLongValue] > 0 && [rv[NSURLVolumeAvailableCapacityForImportantUsageKey] longLongValue] > 0 &&
          [rv[NSURLVolumeNameKey] isEqualToString:@"Data"] && [rv[NSURLVolumeSupportsCaseSensitiveNamesKey] boolValue]);
    CHECK(![rv[NSURLIsUbiquitousItemKey] boolValue] && [rv[NSURLFileProtectionKey] isEqualToString:NSURLFileProtectionCompleteUntilFirstUserAuthentication]);
    id folderType = nil; [[NSURL fileURLWithPath:dir] getResourceValue:&folderType forKey:NSURLTypeIdentifierKey error:NULL];
    CHECK([folderType isEqualToString:@"public.folder"]);
    NSDate *born = [NSDate dateWithTimeIntervalSince1970:1000000000];
    CHECK(([note setResourceValues:@{ NSURLIsExcludedFromBackupKey: @YES, NSURLCreationDateKey: born, NSURLIsHiddenKey: @YES } error:NULL]));
    NSDictionary *back = [[NSURL fileURLWithPath:note.path] resourceValuesForKeys:@[NSURLIsExcludedFromBackupKey, NSURLCreationDateKey, NSURLIsHiddenKey] error:NULL];
    CHECK([back[NSURLIsExcludedFromBackupKey] boolValue] && [back[NSURLCreationDateKey] isEqualToDate:born] && [back[NSURLIsHiddenKey] boolValue]);
    [note setTemporaryResourceValue:@"temp" forKey:NSURLLocalizedNameKey];
    id tempName = nil; [note getResourceValue:&tempName forKey:NSURLLocalizedNameKey error:NULL];
    [note removeCachedResourceValueForKey:NSURLLocalizedNameKey];
    id realName = nil; [note getResourceValue:&realName forKey:NSURLLocalizedNameKey error:NULL];
    CHECK([tempName isEqualToString:@"temp"] && [realName isEqualToString:@"note.txt"]);
    /* bound stream pair */
    NSInputStream *bin = nil; NSOutputStream *bout = nil;
    [NSStream getBoundStreamsWithBufferSize:4 inputStream:&bin outputStream:&bout];
    [bin open]; [bout open];
    NSInteger w1 = [bout write:(const uint8_t *)"abcdef" maxLength:6];
    uint8_t rb[8] = {0};
    NSInteger r1 = [bin read:rb maxLength:sizeof rb];
    NSInteger w2 = [bout write:(const uint8_t *)"ef" maxLength:2];
    [bout close];
    NSInteger r2 = [bin read:rb + r1 maxLength:sizeof rb - (NSUInteger)r1];
    CHECK(w1 == 4 && r1 == 4 && w2 == 2 && r2 == 2 && !memcmp(rb, "abcdef", 6) && bin.streamStatus == NSStreamStatusAtEnd);
    /* socket streams: an echo server on the loopback interface; delegate events on this run loop */
    int port = 0, ls = listen_local(&port);
    pthread_t server; pthread_create(&server, NULL, echo_server, (void *)(intptr_t)ls);
    NSInputStream *sin = nil; NSOutputStream *sout = nil;
    [NSStream getStreamsToHostWithName:@"127.0.0.1" port:port inputStream:&sin outputStream:&sout];
    StreamEvents *ev = [StreamEvents new];
    sin.delegate = ev; sout.delegate = ev;
    [sin scheduleInRunLoop:NSRunLoop.currentRunLoop forMode:NSDefaultRunLoopMode];
    [sout scheduleInRunLoop:NSRunLoop.currentRunLoop forMode:NSDefaultRunLoopMode];
    [sin open]; [sout open];
    CHECK(spin_until(^BOOL { return (ev.events & NSStreamEventOpenCompleted) && (ev.events & NSStreamEventHasSpaceAvailable); }, 5));
    CHECK([sout write:(const uint8_t *)"ping" maxLength:4] == 4);
    CHECK(spin_until(^BOOL { return (ev.events & NSStreamEventHasBytesAvailable) != 0; }, 5));
    uint8_t sb[8] = {0};
    CHECK([sin read:sb maxLength:sizeof sb] == 4 && !memcmp(sb, "ping", 4));
    [sout close];
    CHECK(spin_until(^BOOL { return (ev.events & NSStreamEventEndEncountered) != 0; }, 5) && sin.streamStatus == NSStreamStatusAtEnd);
    [sin close];
    pthread_join(server, NULL);
    NSInputStream *refused = nil; NSOutputStream *refusedOut = nil;
    [NSStream getStreamsToHostWithName:@"127.0.0.1" port:port inputStream:&refused outputStream:&refusedOut];
    [refused open];
    CHECK(spin_until(^BOOL { return refused.streamStatus == NSStreamStatusError; }, 5) && [refused.streamError.domain isEqualToString:NSPOSIXErrorDomain]);
    /* FileHandle: accept a connection, then read from it, in the background */
    int lport = 0, lfd = listen_local(&lport);
    NSFileHandle *listener = [[NSFileHandle alloc] initWithFileDescriptor:lfd closeOnDealloc:YES];
    __block NSFileHandle *accepted = nil; __block NSData *readData = nil;
    id o1 = [NSNotificationCenter.defaultCenter addObserverForName:NSFileHandleConnectionAcceptedNotification object:listener queue:nil usingBlock:^(NSNotification *n) {
        accepted = n.userInfo[NSFileHandleNotificationFileHandleItem];
    }];
    [listener acceptConnectionInBackgroundAndNotify];
    int client = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in ca = { .sin_family = AF_INET, .sin_port = htons((uint16_t)lport) };
    ca.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    connect(client, (struct sockaddr *)&ca, sizeof ca);
    CHECK(spin_until(^BOOL { return accepted != nil; }, 5));
    id o2 = [NSNotificationCenter.defaultCenter addObserverForName:NSFileHandleReadCompletionNotification object:accepted queue:nil usingBlock:^(NSNotification *n) {
        readData = n.userInfo[NSFileHandleNotificationDataItem];
    }];
    [accepted readInBackgroundAndNotify];
    write(client, "abc", 3);
    CHECK(spin_until(^BOOL { return readData != nil; }, 5) && [readData isEqualToData:[NSData dataWithBytes:"abc" length:3]]);
    close(client);
    [NSNotificationCenter.defaultCenter removeObserver:o1]; [NSNotificationCenter.defaultCenter removeObserver:o2];
    /* iCloud documents (local): a metadata query, eviction and download, coordination */
    NSURL *container = [fm URLForUbiquityContainerIdentifier:nil];
    NSURL *docs = [container URLByAppendingPathComponent:@"Documents"];
    NSURL *doc = [docs URLByAppendingPathComponent:@"report.txt"];
    [@"quarterly numbers" writeToURL:doc atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [@"x" writeToURL:[docs URLByAppendingPathComponent:@"image.png"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    CHECK(container && [fm isUbiquitousItemAtURL:doc]);
    NSMetadataQuery *q = [NSMetadataQuery new];
    q.searchScopes = @[NSMetadataQueryUbiquitousDocumentsScope];
    q.predicate = [NSPredicate predicateWithFormat:@"%K LIKE '*.txt'", NSMetadataItemFSNameKey];
    q.notificationBatchingInterval = 0.2;
    __block BOOL gathered = NO; __block NSDictionary *update = nil;
    id o3 = [NSNotificationCenter.defaultCenter addObserverForName:NSMetadataQueryDidFinishGatheringNotification object:q queue:nil usingBlock:^(NSNotification *n) { gathered = YES; }];
    id o4 = [NSNotificationCenter.defaultCenter addObserverForName:NSMetadataQueryDidUpdateNotification object:q queue:nil usingBlock:^(NSNotification *n) { update = n.userInfo; }];
    CHECK([q startQuery]);
    CHECK(spin_until(^BOOL { return gathered; }, 5) && q.resultCount == 1 &&
          [[[q resultAtIndex:0] valueForAttribute:NSMetadataItemFSNameKey] isEqualToString:@"report.txt"] &&
          [[[q resultAtIndex:0] valueForAttribute:NSMetadataUbiquitousItemDownloadingStatusKey] isEqualToString:NSMetadataUbiquitousItemDownloadingStatusCurrent]);
    CHECK([fm evictUbiquitousItemAtURL:doc error:NULL]);
    id status = nil; [doc getResourceValue:&status forKey:NSURLUbiquitousItemDownloadingStatusKey error:NULL];
    CHECK([status isEqualToString:NSURLUbiquitousItemDownloadingStatusNotDownloaded] && [[fm attributesOfItemAtPath:doc.path error:NULL] fileSize] == 0);
    CHECK(spin_until(^BOOL { return update != nil && [update[NSMetadataQueryUpdateChangedItemsKey] count] == 1; }, 5) &&
          [[[q resultAtIndex:0] valueForAttribute:NSMetadataUbiquitousItemDownloadingStatusKey] isEqualToString:NSMetadataUbiquitousItemDownloadingStatusNotDownloaded]);
    CHECK([fm startDownloadingUbiquitousItemAtURL:doc error:NULL]);
    CHECK(spin_until(^BOOL {
        id st = nil; NSURL *fresh = [NSURL fileURLWithPath:doc.path]; [fresh getResourceValue:&st forKey:NSURLUbiquitousItemDownloadingStatusKey error:NULL];
        return [st isEqualToString:NSURLUbiquitousItemDownloadingStatusCurrent];
    }, 5) && [[NSString stringWithContentsOfURL:doc encoding:NSUTF8StringEncoding error:NULL] isEqualToString:@"quarterly numbers"]);
    [q stopQuery];
    [NSNotificationCenter.defaultCenter removeObserver:o3]; [NSNotificationCenter.defaultCenter removeObserver:o4];
    [fm evictUbiquitousItemAtURL:doc error:NULL];
    TestPresenter *presenter = [TestPresenter new];
    presenter.presentedItemURL = doc; presenter.presentedItemOperationQueue = [NSOperationQueue new];
    [NSFileCoordinator addFilePresenter:presenter];
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    __block NSString *coordinatedText = nil;
    [coordinator coordinateReadingItemAtURL:doc options:0 error:NULL byAccessor:^(NSURL *u) { coordinatedText = [NSString stringWithContentsOfURL:u encoding:NSUTF8StringEncoding error:NULL]; }];
    CHECK([coordinatedText isEqualToString:@"quarterly numbers"]);          /* a coordinated read downloads an evicted item */
    [coordinator coordinateWritingItemAtURL:doc options:0 error:NULL byAccessor:^(NSURL *u) { [@"revised" writeToURL:u atomically:YES encoding:NSUTF8StringEncoding error:NULL]; }];
    CHECK(spin_until(^BOOL { return presenter.changes == 1; }, 5) && presenter.saves >= 1);
    [NSFileCoordinator removeFilePresenter:presenter];
    CHECK(NSFileCoordinator.filePresenters.count == 0);
    [fm removeItemAtPath:dir error:NULL];
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // strings & formatting
        NSString *s = [NSString stringWithFormat:@"%@ %d %.2f %s %ld %05x %@", @"hi", 42, 3.14159, "c", (long)-7, 255, @[@1, @2]];
        CHECK([s hasPrefix:@"hi 42 3.14 c -7 000ff ("]);
        CHECK([@"héllo wörld" length] == 11);
        CHECK([[@"héllo" uppercaseString] isEqualToString:@"HÉLLO"] && [[@"ÇA VA" lowercaseString] isEqualToString:@"ça va"]);
        CHECK([@"a,b,,c" componentsSeparatedByString:@","].count == 4);
        CHECK([[@"/a/b/c.txt" lastPathComponent] isEqualToString:@"c.txt"]);
        CHECK([[@"/a/b/c.txt" pathExtension] isEqualToString:@"txt"]);
        CHECK([[@"Hello World" substringWithRange:NSMakeRange(6, 5)] isEqualToString:@"World"]);
        CHECK([@"emoji 😀!" length] == 9);
        NSMutableString *m = [NSMutableString stringWithString:@"abc"];
        [m appendFormat:@"-%d", 5]; [m insertString:@">" atIndex:0];
        CHECK([m isEqualToString:@">abc-5"]);
        CHECK([@"42" integerValue] == 42 && [@"2.5" doubleValue] == 2.5);
        CHECK([[@"shout" shout] isEqualToString:@"SHOUT!"]);               // category on a framework class
        CHECK([[@"straße" uppercaseString] isEqualToString:@"STRASSE"] && [[@"hello wide world" capitalizedString] isEqualToString:@"Hello Wide World"]);
        CHECK([@"Crème Brûlée" localizedStandardContainsString:@"creme brulee"] && [@"ABC" localizedCaseInsensitiveContainsString:@"b"]);
        CHECK([@"a-b-c" rangeOfString:@"-" options:NSBackwardsSearch range:NSMakeRange(0, 5)].location == 3);
        CHECK([[@"a.b.c" stringByReplacingOccurrencesOfString:@"." withString:@"/" options:0 range:NSMakeRange(2, 3)] isEqualToString:@"a.b/c"]);
        __block NSMutableArray *lines = [NSMutableArray array];
        [@"one\ntwo\r\nthree" enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) { [lines addObject:line]; }];
        CHECK([lines isEqualToArray:(@[@"one", @"two", @"three"])]);
        __block NSMutableArray *words = [NSMutableArray array];
        [@"Hi, it's a test." enumerateSubstringsInRange:NSMakeRange(0, 16) options:NSStringEnumerationByWords usingBlock:^(NSString *w, NSRange r, NSRange e, BOOL *stop) { [words addObject:w]; }];
        CHECK([words isEqualToArray:(@[@"Hi", @"it's", @"a", @"test"])]);

        // regular expressions (NSRegularExpression on the host's PCRE2)
        NSError *rerr = nil;
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"(\\w+)@(?<host>\\w+)\\.com" options:NSRegularExpressionCaseInsensitive error:&rerr];
        NSString *mail = @"Mail ANA@Example.com or bob@test.com — é@x.com";
        CHECK(re && !rerr && re.numberOfCaptureGroups == 2);
        NSArray<NSTextCheckingResult *> *ms = [re matchesInString:mail options:0 range:NSMakeRange(0, mail.length)];
        CHECK(ms.count == 3 && [[mail substringWithRange:[ms[0] rangeAtIndex:1]] isEqualToString:@"ANA"]);
        CHECK([[mail substringWithRange:[ms[1] rangeWithName:@"host"]] isEqualToString:@"test"]);
        CHECK(ms[2].range.location == 39 && ms[2].range.length == 7);             // UTF-16 indices after a non-ASCII dash
        CHECK([[re stringByReplacingMatchesInString:mail options:0 range:NSMakeRange(0, mail.length) withTemplate:@"<$2:$1>"] isEqualToString:@"Mail <Example:ANA> or <test:bob> — <x:é>"]);
        CHECK([re numberOfMatchesInString:mail options:0 range:NSMakeRange(5, 10)] == 0);
        CHECK([NSRegularExpression regularExpressionWithPattern:@"(unclosed" options:0 error:&rerr] == nil && rerr.code == 2048);
        NSRegularExpression *empty = [NSRegularExpression regularExpressionWithPattern:@"x*" options:0 error:NULL];
        CHECK([empty numberOfMatchesInString:@"axxb" options:0 range:NSMakeRange(0, 4)] == 4);
        NSMutableString *mm = [@"2024-10-05" mutableCopy];
        [[NSRegularExpression regularExpressionWithPattern:@"(\\d+)-(\\d+)-(\\d+)" options:0 error:NULL] replaceMatchesInString:mm options:0 range:NSMakeRange(0, mm.length) withTemplate:@"$3/$2/$1 \\$1"];
        CHECK([mm isEqualToString:@"05/10/2024 $1"]);
        CHECK([@"Version 12.3" rangeOfString:@"\\d+\\.\\d+" options:NSRegularExpressionSearch].location == 8);
        CHECK([[NSRegularExpression escapedPatternForString:@"a.b*c"] isEqualToString:@"a\\.b\\*c"]);
        NSRegularExpression *ml = [NSRegularExpression regularExpressionWithPattern:@"^\\w+$" options:NSRegularExpressionAnchorsMatchLines error:NULL];
        CHECK([ml numberOfMatchesInString:@"ab\ncd\nef" options:0 range:NSMakeRange(0, 8)] == 3);
        NSDataDetector *dd = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber | NSTextCheckingTypeDate error:NULL];
        NSString *note = @"See https://isim.dev/docs, write to me@kolabs.dev or call +1 (555) 123-4567 on 2026-10-05.";
        NSArray<NSTextCheckingResult *> *found = [dd matchesInString:note options:0 range:NSMakeRange(0, note.length)];
        CHECK(found.count == 4 && found[0].resultType == NSTextCheckingTypeLink && [found[0].URL.absoluteString isEqualToString:@"https://isim.dev/docs"]);
        CHECK(found.count == 4 && [found[1].URL.absoluteString isEqualToString:@"mailto:me@kolabs.dev"] && [found[2].phoneNumber isEqualToString:@"+1 (555) 123-4567"]);
        CHECK(found.count == 4 && found[3].resultType == NSTextCheckingTypeDate && found[3].date != nil);
        NSDataDetector *places = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeAddress | NSTextCheckingTypeTransitInformation error:NULL];
        NSString *trip = @"Meet at 1 Infinite Loop, Cupertino, CA 95014 then fly BA 2490 home.";
        NSArray<NSTextCheckingResult *> *stops = [places matchesInString:trip options:0 range:NSMakeRange(0, trip.length)];
        CHECK(stops.count == 2 && stops[0].resultType == NSTextCheckingTypeAddress && [[trip substringWithRange:stops[0].range] isEqualToString:@"1 Infinite Loop, Cupertino, CA 95014"]);
        CHECK(stops.count == 2 && [stops[0].addressComponents[NSTextCheckingStreetKey] isEqualToString:@"1 Infinite Loop"] &&
              [stops[0].addressComponents[NSTextCheckingCityKey] isEqualToString:@"Cupertino"] && [stops[0].addressComponents[NSTextCheckingZIPKey] isEqualToString:@"95014"]);
        CHECK(stops.count == 2 && stops[1].resultType == NSTextCheckingTypeTransitInformation &&
              [stops[1].components[NSTextCheckingAirlineKey] isEqualToString:@"British Airways"] && [stops[1].components[NSTextCheckingFlightKey] isEqualToString:@"2490"]);

        // formatters (explicit locales; the device region drives the defaults)
        NSLocale *enUS = [NSLocale localeWithLocaleIdentifier:@"en_US"], *ptBR = [NSLocale localeWithLocaleIdentifier:@"pt_BR"];
        NSDate *when = [NSDate dateWithTimeIntervalSince1970:1791212645];       // 2026-10-05 15:04:05 UTC
        NSDateFormatter *dfm = [NSDateFormatter new]; dfm.locale = enUS; dfm.timeZone = [NSTimeZone timeZoneWithName:@"America/Los_Angeles"];
        dfm.dateStyle = NSDateFormatterMediumStyle; dfm.timeStyle = NSDateFormatterShortStyle;
        CHECK([[dfm stringFromDate:when] isEqualToString:@"Oct 5, 2026, 8:04 AM"]);
        dfm.locale = ptBR; dfm.dateStyle = NSDateFormatterLongStyle; dfm.timeStyle = NSDateFormatterNoStyle;
        CHECK([[dfm stringFromDate:when] isEqualToString:@"5 de outubro de 2026"]);
        [dfm setLocalizedDateFormatFromTemplate:@"MMMMd"];
        CHECK([dfm.dateFormat isEqualToString:@"d 'de' MMMM"]);
        NSNumberFormatter *nfm = [NSNumberFormatter new]; nfm.locale = ptBR; nfm.numberStyle = NSNumberFormatterCurrencyStyle;
        CHECK([[nfm stringFromNumber:@1234.5] isEqualToString:@"R$ 1.234,50"] && [[nfm numberFromString:@"R$ 10,25"] doubleValue] == 10.25);
        nfm.locale = enUS; nfm.numberStyle = NSNumberFormatterSpellOutStyle;
        CHECK([[nfm stringFromNumber:@42] isEqualToString:@"forty-two"]);
        nfm.numberStyle = NSNumberFormatterOrdinalStyle;
        CHECK([[nfm stringFromNumber:@23] isEqualToString:@"23rd"]);
        CHECK([[[NSISO8601DateFormatter new] stringFromDate:when] isEqualToString:@"2026-10-05T15:04:05Z"]);
        NSByteCountFormatter *bcf = [NSByteCountFormatter new];
        CHECK([[bcf stringFromByteCount:999] isEqualToString:@"999 bytes"] && [[bcf stringFromByteCount:2500000000] isEqualToString:@"2.5 GB"]);
        NSListFormatter *lfm = [NSListFormatter new]; lfm.locale = ptBR;
        CHECK([[lfm stringFromItems:(@[@"a", @"b", @"c"])] isEqualToString:@"a, b e c"]);

        // key-value coding & observing
        Person *ada = [Person new]; ada.name = @"Ada"; ada.age = 36;
        Person *bob = [Person new]; bob.name = @"Bob"; bob.age = 25;
        CHECK([[ada valueForKey:@"name"] isEqualToString:@"Ada"] && [[ada valueForKey:@"age"] integerValue] == 36);
        [ada setValue:@37 forKey:@"age"]; [ada setValue:@"Ada L." forKey:@"name"]; [ada setValue:@2.5 forKey:@"score"];
        CHECK(ada.age == 37 && [ada.name isEqualToString:@"Ada L."] && ada.score == 2.5);
        [ada setValue:@"secret" forKey:@"hidden"];                                   // ivar access (_hidden)
        CHECK([[ada valueForKey:@"hidden"] isEqualToString:@"secret"]);
        ada.friend = bob;
        CHECK([[ada valueForKeyPath:@"friend.name"] isEqualToString:@"Bob"]);
        NSArray *people = @[ada, bob];
        CHECK([[people valueForKey:@"name"] isEqualToArray:(@[@"Ada L.", @"Bob"])] && [[people valueForKeyPath:@"@sum.age"] integerValue] == 62 && [[people valueForKeyPath:@"@max.age"] integerValue] == 37);
        CHECK([[@{@"k": @1} valueForKey:@"k"] intValue] == 1);
        AgeWatcher *watcher = [AgeWatcher new];
        [bob addObserver:watcher forKeyPath:@"age" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
        bob.age = 26; [bob setValue:@27 forKey:@"age"];
        CHECK(watcher.changes.count == 2 && [watcher.changes[0] isEqualToString:@"25->26"] && [watcher.changes[1] isEqualToString:@"26->27"]);
        [bob removeObserver:watcher forKeyPath:@"age"];
        bob.age = 30;
        CHECK(watcher.changes.count == 2);

        // more collections, sorting, predicates
        NSMutableIndexSet *is = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(2, 3)];
        [is addIndex:9]; [is addIndex:5]; [is removeIndex:3];
        CHECK(is.count == 4 && is.firstIndex == 2 && is.lastIndex == 9 && [is containsIndex:5] && ![is containsIndex:3] && [is indexGreaterThanIndex:5] == 9);
        CHECK(([[@[@"a", @"b", @"c", @"d"] objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)]] isEqualToArray:(@[@"b", @"c"])]));
        NSMutableOrderedSet *os = [NSMutableOrderedSet orderedSetWithArray:@[@"x", @"y", @"x", @"z"]];
        [os insertObject:@"w" atIndex:0]; [os addObject:@"y"];
        CHECK(os.count == 4 && [os.array isEqualToArray:(@[@"w", @"x", @"y", @"z"])] && [os indexOfObject:@"y"] == 2);
        NSCountedSet *cs = [[NSCountedSet alloc] initWithArray:@[@"a", @"b", @"a"]];
        CHECK(cs.count == 2 && [cs countForObject:@"a"] == 2);
        NSCache *cache = [NSCache new]; cache.countLimit = 2;
        [cache setObject:@1 forKey:@"one"]; [cache setObject:@2 forKey:@"two"]; [cache setObject:@3 forKey:@"three"];
        CHECK([cache objectForKey:@"one"] == nil && [[cache objectForKey:@"three"] intValue] == 3);
        NSHashTable *weakTable = [NSHashTable weakObjectsHashTable];
        @autoreleasepool { NSObject *tmp = [NSObject new]; [weakTable addObject:tmp]; [weakTable addObject:ada]; CHECK(weakTable.count == 2); }
        CHECK(weakTable.count == 1);
        NSArray *byAge = [people sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"age" ascending:YES]]];
        CHECK(byAge.firstObject == bob);
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"age > %d AND name BEGINSWITH[c] %@", 28, @"b"];
        CHECK([pred evaluateWithObject:bob] && ![pred evaluateWithObject:ada]);
        CHECK([[people filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name CONTAINS 'L.' OR age IN {1, 2, 30}"]] count] == 2);
        CHECK(([[@[@"apple", @"Banana", @"cherry"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF LIKE[c] '*an*'"]] isEqualToArray:(@[@"Banana"])]));
        CHECK(([[NSPredicate predicateWithFormat:@"SELF MATCHES '[0-9]{3}'"] evaluateWithObject:@"123"] && [[NSPredicate predicateWithFormat:@"%K BETWEEN {20, 40}", @"age"] evaluateWithObject:ada]));
        CHECK([[NSPredicate predicateWithFormat:@"friend.name == 'Bob' && NOT (age < 30)"] evaluateWithObject:ada]);
        CHECK([[NSPredicate predicateWithFormat:@"age == $AGE"] evaluateWithObject:bob substitutionVariables:@{@"AGE": @30}]);

        // data, property lists, keyed archives, UUID, undo
        NSData *bytes = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
        CHECK(bytes.length == 5 && [[bytes base64EncodedStringWithOptions:0] isEqualToString:@"aGVsbG8="] && [[[NSData alloc] initWithBase64EncodedString:@"aGVsbG8=" options:0] isEqualToData:bytes]);
        CHECK([[[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] isEqualToString:@"hello"]);
        NSDictionary *plist = @{ @"name": @"isim", @"n": @42, @"pi": @3.5, @"yes": @YES, @"blob": bytes, @"list": @[@1, @"two"], @"when": [NSDate dateWithTimeIntervalSince1970:0] };
        for (NSNumber *fmtNum in @[@(NSPropertyListBinaryFormat_v1_0), @(NSPropertyListXMLFormat_v1_0)]) {
            NSError *perr = nil; NSPropertyListFormat got = 0;
            NSData *pd = [NSPropertyListSerialization dataWithPropertyList:plist format:fmtNum.unsignedIntegerValue options:0 error:&perr];
            NSDictionary *pback = [NSPropertyListSerialization propertyListWithData:pd options:NSPropertyListImmutable format:&got error:&perr];
            CHECK(pd && got == fmtNum.unsignedIntegerValue && [pback isEqualToDictionary:plist]);
        }
        CHECK([[NSPropertyListSerialization propertyListWithData:[@"{ a = 1; b = (x, \"y z\"); }" dataUsingEncoding:NSUTF8StringEncoding] options:0 format:NULL error:NULL][@"b"] count] == 2);
        NSDictionary *graph = @{ @"people": people, @"tags": [NSSet setWithObjects:@"a", @"b", nil], @"uuid": [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"] };
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:graph requiringSecureCoding:NO error:NULL];
        NSDictionary *unarchived = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
        CHECK([[unarchived[@"people"] valueForKey:@"name"] isEqualToArray:(@[@"Ada L.", @"Bob"])] && [unarchived[@"tags"] count] == 2 && [[unarchived[@"uuid"] UUIDString] isEqualToString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"]);
        CHECK([[unarchived[@"people"][0] valueForKeyPath:@"friend.name"] isEqualToString:@"Bob"] && [unarchived[@"people"][0] friend] == [unarchived[@"people"] lastObject]);   // shared references survive
        NSUndoManager *um = [NSUndoManager new]; um.groupsByEvent = NO;
        NSMutableArray *stack = [NSMutableArray arrayWithObject:@"a"];
        [um registerUndoWithTarget:stack selector:@selector(removeObject:) object:@"b"]; [stack addObject:@"b"];
        [um undo];
        CHECK(stack.count == 1 && !um.canUndo);

        // numbers & collections
        NSArray *arr = @[@3, @1, @2];
        NSArray *sorted = [arr sortedArrayUsingSelector:@selector(compare:)];
        CHECK([sorted isEqualToArray:(@[@1, @2, @3])]);
        NSDictionary *d = @{@"a": @1, @"b": @"two", @"c": @[@3]};
        CHECK([d[@"b"] isEqualToString:@"two"] && [d[@"a"] intValue] == 1 && d.count == 3);
        NSMutableDictionary *md = [d mutableCopy];
        md[@"a"] = nil; md[@"z"] = @26;
        CHECK(md.count == 3 && md[@"a"] == nil && [md[@"z"] intValue] == 26);
        int sum = 0; for (NSNumber *n in arr) sum += n.intValue;
        CHECK(sum == 6);
        NSUInteger keys = 0; for (NSString *k in d) keys += k.length;
        CHECK(keys == 3);
        CHECK(@[].count == 0 && @{}.count == 0);
        NSSet *set = [NSSet setWithArray:@[@1, @1, @2]];
        CHECK(set.count == 2 && [set containsObject:@2]);

        // large hashed collections (issue #86): building them is linear, removal leaves order intact
        {
            enum { N = 100000 };
            clock_t t0 = clock();
            NSMutableSet *big = [NSMutableSet set];
            NSMutableDictionary *bigd = [NSMutableDictionary dictionary];
            NSCountedSet *bigc = [NSCountedSet new];
            for (int i = 0; i < N; i++) {
                NSString *w = [NSString stringWithFormat:@"w%d", i];
                [big addObject:w]; [big addObject:[w mutableCopy]];   // the equal copy is not added again
                bigd[w] = @(i);
                [bigc addObject:w]; if (i % 2) [bigc addObject:w];
            }
            BOOL allIn = YES;
            for (int i = 0; i < N; i++) {
                NSString *w = [NSString stringWithFormat:@"w%d", i];
                allIn = allIn && [big containsObject:w] && [bigd[w] intValue] == i && [bigc countForObject:w] == (NSUInteger)(1 + i % 2);
            }
            CHECK(big.count == N && bigd.count == N && bigc.count == N && allIn && ![big containsObject:@"w-1"] && bigd[@"w-1"] == nil);
            for (int i = 0; i < N; i += 2) {
                NSString *w = [NSString stringWithFormat:@"w%d", i];
                [big removeObject:w]; [bigd removeObjectForKey:w]; [bigc removeObject:w];
            }
            CHECK(big.count == N / 2 && bigd.count == N / 2 && bigc.count == N / 2 && ![big containsObject:@"w0"] && [big containsObject:@"w1"] &&
                  bigd[@"w2"] == nil && [bigd[@"w3"] intValue] == 3 && [bigc countForObject:@"w0"] == 0 && [bigc countForObject:@"w3"] == 2);
            int expect = 1; BOOL ordered = YES;
            for (NSString *k in bigd) { ordered = ordered && [k isEqualToString:[NSString stringWithFormat:@"w%d", expect]]; expect += 2; }
            CHECK(ordered && expect == N + 1 && [[bigd.allKeys firstObject] isEqualToString:@"w1"]);
            for (int i = 0; i < N; i += 2) { bigd[[NSString stringWithFormat:@"w%d", i]] = @(-i); [big addObject:[NSString stringWithFormat:@"w%d", i]]; }
            CHECK(bigd.count == N && big.count == N && [bigd[@"w4"] intValue] == -4 && [[bigd.allKeys lastObject] isEqualToString:([NSString stringWithFormat:@"w%d", N - 2])]);
            NSSet *frozen = [big copy];
            CHECK([frozen isEqual:big] && [frozen member:@"w7"] != nil && [[bigc copy] countForObject:@"w3"] == 2);
            [big removeAllObjects]; [bigd removeAllObjects];
            [big addObject:@"again"]; bigd[@"again"] = @1;
            CHECK(big.count == 1 && bigd.count == 1 && [big containsObject:@"again"] && [bigd[@"again"] intValue] == 1 && ![big containsObject:@"w1"]);
            double secs = (double)(clock() - t0) / CLOCKS_PER_SEC;
            printf("hashed collections: %d entries in %.2f s\n", N, secs);
            CHECK(secs < 20);   // linear; the array-backed set took minutes
        }

        // large NSHashTable / NSMapTable (issues #92, #93): hashed like NSSet / NSDictionary, weak entries swept
        {
            enum { N = 50000 };
            clock_t t0 = clock();
            NSHashTable *ht = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory];
            NSMapTable *mt = [NSMapTable strongToStrongObjectsMapTable];
            for (int i = 0; i < N; i++) @autoreleasepool {
                NSString *w = [NSString stringWithFormat:@"w%d", i];
                [ht addObject:w]; [ht addObject:[w mutableCopy]];   // equal: not added again
                [mt setObject:@(i) forKey:w]; [mt setObject:@(i + 1) forKey:[w mutableCopy]];   // equal key: value replaced
            }
            BOOL allIn = YES;
            for (int i = 0; i < N; i++) @autoreleasepool {
                NSString *w = [NSString stringWithFormat:@"w%d", i];
                allIn = allIn && [ht containsObject:w] && [[mt objectForKey:w] intValue] == i + 1;
            }
            CHECK(ht.count == N && mt.count == N && allIn && ![ht containsObject:@"w-1"] && [mt objectForKey:@"w-1"] == nil);
            for (int i = 0; i < N; i += 2) @autoreleasepool { NSString *w = [NSString stringWithFormat:@"w%d", i]; [ht removeObject:w]; [mt removeObjectForKey:w]; }
            CHECK(ht.count == N / 2 && mt.count == N / 2 && ![ht containsObject:@"w0"] && [ht member:@"w1"] != nil && [mt objectForKey:@"w2"] == nil &&
                  [[mt objectForKey:@"w3"] intValue] == 4 && [[[mt keyEnumerator] nextObject] isEqualToString:@"w1"]);

            NSHashTable *wht = [NSHashTable weakObjectsHashTable];
            NSMapTable *wmt = [NSMapTable weakToStrongObjectsMapTable], *swm = [NSMapTable strongToWeakObjectsMapTable];
            NSMutableArray *keep = [NSMutableArray array];
            for (int i = 0; i < N; i++) @autoreleasepool {   // only every tenth object outlives its iteration
                NSObject *o = [NSObject new];
                if (i % 10 == 0) [keep addObject:o];
                [wht addObject:o]; [wmt setObject:@(i) forKey:o]; [swm setObject:o forKey:@(i)];
            }
            @autoreleasepool {   // reading a weak reference autoreleases the object: drain before the objects go
                BOOL kept = YES;
                for (NSUInteger i = 0; i < keep.count; i++)
                    kept = kept && [wht containsObject:keep[i]] && [[wmt objectForKey:keep[i]] intValue] == (int)i * 10 && [swm objectForKey:@(i * 10)] == keep[i];
                CHECK(kept && wht.count == N / 10 && wmt.count == N / 10 && swm.count == N / 10 && [swm objectForKey:@1] == nil);
            }
            [keep removeAllObjects];
            CHECK(wht.count == 0 && wmt.count == 0 && wht.allObjects.count == 0 && [[wmt dictionaryRepresentation] count] == 0);

            NSString *a = [NSString stringWithFormat:@"same"], *b = [a mutableCopy];
            NSHashTable *pt = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
            NSMapTable *pm = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                                                   valueOptions:NSPointerFunctionsStrongMemory];
            [pt addObject:a]; [pt addObject:b]; [pm setObject:@1 forKey:a]; [pm setObject:@2 forKey:b];
            CHECK(pt.count == 2 && [pt member:b] == b && [pt member:@"same"] == nil && [[pm objectForKey:a] intValue] == 1 && [[pm objectForKey:b] intValue] == 2);
            double secs = (double)(clock() - t0) / CLOCKS_PER_SEC;
            printf("hash/map tables: %d entries in %.2f s\n", N, secs);
            CHECK(secs < 20);   // linear; the array-backed tables took minutes
        }
        CHECK([@(3.5) doubleValue] == 3.5 && [@YES boolValue]);

        // ARC lifetimes, weak references, dealloc
        __weak Tracked *weakRef;
        @autoreleasepool {
            Tracked *a = [Tracked new], *b = [Tracked new];
            a.name = @"a"; a.peer = b; b.peer = a; a.items = [NSMutableArray arrayWithObject:b];
            weakRef = a;
            CHECK(weakRef != nil && a.peer == b);
        }
        CHECK(weakRef == nil);
        CHECK(deallocs == 2);

        // blocks
        __block int counter = 0;
        void (^inc)(int) = ^(int by) { counter += by; };
        NSMutableArray *blocks = [NSMutableArray array];
        for (int i = 1; i <= 3; i++) [blocks addObject:[^{ inc(i); } copy]];
        for (void (^b)(void) in blocks) b();
        CHECK(counter == 6);
        [arr enumerateObjectsUsingBlock:^(NSNumber *obj, NSUInteger idx, BOOL *stop) { counter += obj.intValue; }];
        CHECK(counter == 12);

        // +initialize, inheritance with ivar sliding, super calls
        CHECK(initialized == 0 && [Lazy value] == 7 && initialized == 1);
        Derived *dv = [Derived new];
        CHECK([[dv who] isEqualToString:@"base11+derived22"]);
        CHECK([dv isKindOfClass:[Base class]] && ![dv isMemberOfClass:[Base class]] && [dv respondsToSelector:@selector(who)]);
        CHECK(NSClassFromString(@"Derived") == [Derived class] && [NSStringFromClass([dv class]) isEqualToString:@"Derived"]);

        // run loop: timers, delayed performs, dispatch_after + main queue
        __block int fired = 0;
        [NSTimer scheduledTimerWithTimeInterval:0.01 repeats:YES block:^(NSTimer *t) { if (++fired == 3) [t invalidate]; }];
        __block BOOL afterRan = NO, asyncRan = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ afterRan = YES; });
        dispatch_async(dispatch_get_global_queue(0, 0), ^{ dispatch_async(dispatch_get_main_queue(), ^{ asyncRan = YES; }); });
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        CHECK(fired == 3 && afterRan && asyncRan);

        // bundle + Info.plist
        NSBundle *mb = NSBundle.mainBundle;
        CHECK([mb.bundleIdentifier isEqualToString:@"dev.kolabs.isim.foundation-test"]);
        CHECK([[mb objectForInfoDictionaryKey:@"UIRequiredDeviceCapabilities"] containsObject:@"arm64"]);
        CHECK([[mb.infoDictionary[@"Nested"][@"Flag"] description] isEqualToString:@"1"]);

        // NSFileHandle, streams, NSScanner, NSProcessInfo device facts
        NSString *fhPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"fh-test.txt"];
        [[NSData data] writeToFile:fhPath atomically:NO];
        NSFileHandle *wh = [NSFileHandle fileHandleForWritingAtPath:fhPath];
        [wh writeData:[@"hello world" dataUsingEncoding:NSUTF8StringEncoding]];
        CHECK(wh.offsetInFile == 11);
        [wh truncateFileAtOffset:5]; [wh closeFile];
        NSFileHandle *rh = [NSFileHandle fileHandleForReadingAtPath:fhPath];
        CHECK([[[NSString alloc] initWithData:[rh readDataToEndOfFile] encoding:NSUTF8StringEncoding] isEqualToString:@"hello"]);
        [rh seekToFileOffset:1];
        CHECK([[rh readDataOfLength:2] isEqualToData:[@"el" dataUsingEncoding:NSUTF8StringEncoding]]);
        CHECK([NSFileHandle fileHandleForReadingAtPath:@"/no/such/file"] == nil);
        NSOutputStream *ostr = [NSOutputStream outputStreamToMemory]; [ostr open];
        CHECK([ostr write:(const uint8_t *)"abc" maxLength:3] == 3);
        NSData *written = [ostr propertyForKey:NSStreamDataWrittenToMemoryStreamKey]; [ostr close];
        NSInputStream *istr = [NSInputStream inputStreamWithData:written]; [istr open];
        uint8_t ibuf[8]; NSInteger n1 = [istr read:ibuf maxLength:2], n2 = [istr read:ibuf + 2 maxLength:8], n3 = [istr read:ibuf maxLength:8];
        CHECK(n1 == 2 && n2 == 1 && n3 == 0 && memcmp(ibuf, "abc", 3) == 0 && istr.streamStatus == NSStreamStatusAtEnd);
        NSScanner *sc = [NSScanner scannerWithString:@"  width = 42, ratio 0x1F 3.5e2 rest"];
        NSString *word = nil; NSInteger ival = 0; unsigned hex = 0; double dval = 0;
        CHECK([sc scanUpToString:@" =" intoString:&word] && [word isEqualToString:@"width"]);
        CHECK([sc scanString:@"=" intoString:NULL] && [sc scanInteger:&ival] && ival == 42);
        CHECK([sc scanString:@"," intoString:NULL] && [sc scanCharactersFromSet:NSCharacterSet.letterCharacterSet intoString:&word] && [word isEqualToString:@"ratio"]);
        CHECK([sc scanHexInt:&hex] && hex == 31 && [sc scanDouble:&dval] && dval == 350 && !sc.atEnd);
        CHECK(![sc scanInteger:&ival] && [sc scanUpToCharactersFromSet:NSCharacterSet.newlineCharacterSet intoString:&word] && [word isEqualToString:@"rest"] && sc.atEnd);
        NSProcessInfo *pi = NSProcessInfo.processInfo;
        CHECK(pi.thermalState == NSProcessInfoThermalStateNominal && !pi.lowPowerModeEnabled && pi.physicalMemory >= (1ULL << 30));
        CHECK(pi.processorCount > 0 && pi.activeProcessorCount == pi.processorCount && pi.operatingSystemVersion.majorVersion >= 15);
        NSOperatingSystemVersion v15 = {15, 0, 0}, v99 = {99, 0, 0};
        CHECK([pi isOperatingSystemAtLeastVersion:v15] && ![pi isOperatingSystemAtLeastVersion:v99]);
        CHECK([pi.operatingSystemVersionString hasPrefix:@"Version "] && pi.globallyUniqueString.length > 30 && pi.environment[@"HOME"] != nil);

        // NSAttributedString / NSMutableAttributedString
        NSMutableAttributedString *mas = [[NSMutableAttributedString alloc] initWithString:@"Hello world" attributes:@{@"k": @1}];
        [mas addAttribute:@"b" value:@YES range:NSMakeRange(6, 5)];
        NSRange er; NSDictionary *at = [mas attributesAtIndex:7 effectiveRange:&er];
        CHECK(er.location == 6 && er.length == 5 && [at[@"k"] isEqual:@1] && [at[@"b"] isEqual:@YES]);
        CHECK([[mas attribute:@"k" atIndex:7 effectiveRange:&er] isEqual:@1] && er.location == 0 && er.length == 11);
        [mas replaceCharactersInRange:NSMakeRange(0, 5) withString:@"Goodbye"];
        CHECK([mas.string isEqualToString:@"Goodbye world"] && [mas attribute:@"b" atIndex:8 effectiveRange:&er] && er.location == 8);
        [mas appendAttributedString:[[NSAttributedString alloc] initWithString:@"!" attributes:@{@"k": @1}]];
        __block int runCount = 0;
        [mas enumerateAttributesInRange:NSMakeRange(0, mas.length) options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) { runCount++; }];
        CHECK(runCount == 3 && mas.length == 14);
        [mas removeAttribute:@"b" range:NSMakeRange(0, mas.length)];
        runCount = 0;
        [mas enumerateAttributesInRange:NSMakeRange(0, mas.length) options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) { runCount++; }];
        CHECK(runCount == 1);
        NSAttributedString *sub = [mas attributedSubstringFromRange:NSMakeRange(8, 5)];
        CHECK([sub.string isEqualToString:@"world"] && [sub isEqual:[[NSAttributedString alloc] initWithString:@"world" attributes:@{@"k": @1}]]);
        NSData *asArchive = [NSKeyedArchiver archivedDataWithRootObject:mas requiringSecureCoding:YES error:NULL];
        [mas addAttribute:@"c" value:@"x" range:NSMakeRange(0, 3)];
        NSAttributedString *back = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSAttributedString class] fromData:[NSKeyedArchiver archivedDataWithRootObject:mas requiringSecureCoding:YES error:NULL] error:NULL];
        if (![back isEqualToAttributedString:mas]) NSLog(@"archived %@ -> %@", mas, back);
        CHECK(asArchive.length > 0 && [back isEqualToAttributedString:mas]);

        // NSError accessors over the userInfo keys, the default description and per-domain value providers
        NSError *under = [NSError errorWithDomain:NSPOSIXErrorDomain code:2 userInfo:nil];
        NSError *full = [NSError errorWithDomain:@"test.errors" code:12 userInfo:@{ NSLocalizedFailureReasonErrorKey: @"The disk is full.",
            NSLocalizedRecoverySuggestionErrorKey: @"Free some space.", NSLocalizedRecoveryOptionsErrorKey: @[@"OK"],
            NSHelpAnchorErrorKey: @"disk", NSUnderlyingErrorKey: under }];
        CHECK([full.localizedDescription isEqualToString:@"The operation couldn’t be completed. The disk is full."]);
        CHECK([full.localizedRecoverySuggestion isEqualToString:@"Free some space."] && [full.localizedRecoveryOptions isEqualToArray:@[@"OK"]]);
        CHECK([full.helpAnchor isEqualToString:@"disk"] && full.underlyingErrors.count == 1 && full.underlyingErrors[0] == under);
        CHECK([[NSError errorWithDomain:@"d" code:3 userInfo:nil].localizedDescription isEqualToString:@"The operation couldn’t be completed. (d error 3.)"]);
        CHECK([[NSError errorWithDomain:@"d" code:3 userInfo:@{@"k": @1}] isEqual:[NSError errorWithDomain:@"d" code:3 userInfo:@{@"k": @1}]]);
        [NSError setUserInfoValueProviderForDomain:@"test.provided" provider:^id(NSError *e, NSErrorUserInfoKey key) {
            return [key isEqualToString:NSLocalizedDescriptionKey] ? [NSString stringWithFormat:@"provided %ld", (long)e.code] : nil;
        }];
        CHECK([[NSError errorWithDomain:@"test.provided" code:7 userInfo:nil].localizedDescription isEqualToString:@"provided 7"]);
        CHECK([NSError userInfoValueProviderForDomain:@"test.provided"] != nil && [NSError userInfoValueProviderForDomain:@"other"] == nil);

        // NSCoding / NSSecureCoding of Foundation's own classes (issue #39)
        CHECK([NSArray supportsSecureCoding] && [NSDictionary supportsSecureCoding] && [NSSet supportsSecureCoding] && [NSNull supportsSecureCoding] &&
              [NSValue supportsSecureCoding] && [NSString supportsSecureCoding] && [NSLocale supportsSecureCoding] && [NSTimeZone supportsSecureCoding] &&
              [NSURL supportsSecureCoding] && [NSDate supportsSecureCoding] && [NSError supportsSecureCoding]);
        CHECK([@[] respondsToSelector:@selector(encodeWithCoder:)] && [NSError instancesRespondToSelector:@selector(initWithCoder:)] &&
              [NSURL instancesRespondToSelector:@selector(encodeWithCoder:)] && [NSDate instancesRespondToSelector:@selector(initWithCoder:)]);
        NSError *posix = [NSError errorWithDomain:NSPOSIXErrorDomain code:2 userInfo:nil];
        NSError *err = [NSError errorWithDomain:@"isim.test" code:42 userInfo:@{ NSLocalizedDescriptionKey: @"boom", NSUnderlyingErrorKey: posix,
                                                                                @"url": [NSURL URLWithString:@"https://example.com/a"], @"block": ^{} }];
        NSData *errData = [NSKeyedArchiver archivedDataWithRootObject:err requiringSecureCoding:YES error:NULL];
        NSError *err2 = errData ? [NSKeyedUnarchiver unarchivedObjectOfClass:[NSError class] fromData:errData error:NULL] : nil;
        CHECK([err2.domain isEqualToString:@"isim.test"] && err2.code == 42 && [err2.localizedDescription isEqualToString:@"boom"]);
        CHECK([err2.userInfo[NSUnderlyingErrorKey] code] == 2 && [[err2.userInfo[@"url"] absoluteString] isEqualToString:@"https://example.com/a"] &&
              err2.userInfo[@"block"] == nil);                  // values that cannot be archived are left out
        TaggedError *tagged = [TaggedError errorWithDomain:@"isim.tag" code:7 userInfo:nil]; tagged.tag = @"t1";
        id tagged2 = [NSKeyedUnarchiver unarchivedObjectOfClass:[TaggedError class]
                                                       fromData:[NSKeyedArchiver archivedDataWithRootObject:tagged requiringSecureCoding:YES error:NULL] error:NULL];
        CHECK([tagged2 isKindOfClass:[TaggedError class]] && [[tagged2 tag] isEqualToString:@"t1"] && [tagged2 code] == 7);   // subclass + super
        // encodeWithCoder: / initWithCoder: called directly (what a subclass's super call reaches)
        NSKeyedArchiver *direct = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
        [@[@"a", @2] encodeWithCoder:direct];
        [[NSDate dateWithTimeIntervalSinceReferenceDate:123.5] encodeWithCoder:direct];
        [direct finishEncoding];
        NSKeyedUnarchiver *rd = [[NSKeyedUnarchiver alloc] initForReadingFromData:direct.encodedData error:NULL];
        NSArray *arr2 = [[NSArray alloc] initWithCoder:rd];
        NSDate *date2 = [[NSDate alloc] initWithCoder:rd];
        CHECK([arr2 isEqual:(@[@"a", @2])] && date2.timeIntervalSinceReferenceDate == 123.5);
        NSValue *pt = [NSValue valueWithCGPoint:CGPointMake(1.5, -2)];
        NSValue *pt2 = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSValue class] fromData:[NSKeyedArchiver archivedDataWithRootObject:pt requiringSecureCoding:YES error:NULL] error:NULL];
        CHECK(pt2.CGPointValue.x == 1.5 && pt2.CGPointValue.y == -2);
        NSDictionary *mixed = @{ @"locale": [NSLocale localeWithLocaleIdentifier:@"pt_BR"], @"tz": [NSTimeZone timeZoneWithName:@"America/Sao_Paulo"],
                                 @"null": [NSNull null], @"set": [NSSet setWithObject:@"x"] };
        NSDictionary *mixed2 = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSLocale class], [NSTimeZone class], [NSNull class], [NSSet class], nil]
                                                                  fromData:[NSKeyedArchiver archivedDataWithRootObject:mixed requiringSecureCoding:YES error:NULL] error:NULL];
        CHECK([[mixed2[@"locale"] localeIdentifier] isEqualToString:@"pt_BR"] && [[mixed2[@"tz"] name] isEqualToString:@"America/Sao_Paulo"] &&
              mixed2[@"null"] == [NSNull null] && [mixed2[@"set"] containsObject:@"x"]);

        // NSFileManager attributes (#102)
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *attrDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"attrs"];
        [fm removeItemAtPath:attrDir error:NULL];
        CHECK([fm createDirectoryAtPath:attrDir withIntermediateDirectories:YES attributes:@{ NSFilePosixPermissions: @0700 } error:NULL]);
        NSString *attrFile = [attrDir stringByAppendingPathComponent:@"f.txt"];
        [@"twelve bytes" writeToFile:attrFile atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        NSError *attrErr = nil;
        NSDictionary *fa = [fm attributesOfItemAtPath:attrFile error:&attrErr];
        CHECK(fa && !attrErr && [fa[NSFileSize] unsignedLongLongValue] == 12 && fa.fileSize == 12 && [fa.fileType isEqualToString:NSFileTypeRegular]);
        CHECK(fabs(fa.fileModificationDate.timeIntervalSinceNow) < 60 && fa.fileCreationDate &&
              [fa.fileCreationDate compare:fa.fileModificationDate] != NSOrderedDescending);
        CHECK([fa[NSFileReferenceCount] integerValue] == 1 && fa.fileSystemFileNumber > 0 && fa.fileOwnerAccountID && fa.fileGroupOwnerAccountID &&
              fa.fileOwnerAccountName.length > 0 && [fa[NSFileExtensionHidden] isEqual:@NO]);
        NSDictionary *da = [fm attributesOfItemAtPath:attrDir error:NULL];
        CHECK([da.fileType isEqualToString:NSFileTypeDirectory] && da.filePosixPermissions == 0700 && da.fileSystemNumber == fa.fileSystemNumber);
        NSDate *past = [NSDate dateWithTimeIntervalSince1970:1000000000.5];
        NSDate *created = fa.fileCreationDate;
        NSDictionary *newAttrs = @{ NSFilePosixPermissions: @0640, NSFileModificationDate: past, NSFileProtectionKey: NSFileProtectionComplete };
        CHECK([fm setAttributes:newAttrs ofItemAtPath:attrFile error:NULL]);
        fa = [fm attributesOfItemAtPath:attrFile error:NULL];
        CHECK(fa.filePosixPermissions == 0640 && fabs(fa.fileModificationDate.timeIntervalSince1970 - 1000000000.5) < 1e-3);
        CHECK([fa.fileCreationDate isEqual:created]);       // chmod / utimes leave the creation date alone
        NSDictionary *owner = @{ NSFileOwnerAccountID: fa.fileOwnerAccountID, NSFileGroupOwnerAccountName: fa.fileGroupOwnerAccountName };
        CHECK([fm setAttributes:owner ofItemAtPath:attrFile error:NULL]);   // to the same owner: allowed without privileges
        NSString *missing = [attrDir stringByAppendingPathComponent:@"missing"];
        attrErr = nil;
        CHECK([fm attributesOfItemAtPath:missing error:&attrErr] == nil && [attrErr.domain isEqualToString:NSCocoaErrorDomain] && attrErr.code == 260 &&
              [attrErr.userInfo[NSUnderlyingErrorKey] code] == ENOENT);
        attrErr = nil;
        CHECK(![fm setAttributes:@{ NSFilePosixPermissions: @0600 } ofItemAtPath:missing error:&attrErr] && attrErr.code == 4);
        NSDictionary *fsa = [fm attributesOfFileSystemForPath:attrDir error:NULL];
        CHECK([fsa[NSFileSystemSize] unsignedLongLongValue] > 0 && [fsa[NSFileSystemFreeSize] unsignedLongLongValue] <= [fsa[NSFileSystemSize] unsignedLongLongValue] &&
              fsa[NSFileSystemNodes] && fsa[NSFileSystemFreeNodes] && [fsa[NSFileSystemNumber] isEqual:fa[NSFileSystemNumber]]);
        CHECK([fm removeItemAtPath:attrDir error:NULL]);

        // NSFileManager: copy / move / links / enumerators / replace (#12)
        NSString *fmDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"fm"];
        [fm removeItemAtPath:fmDir error:NULL];
        NSString *tree = [fmDir stringByAppendingPathComponent:@"tree"];
        CHECK([fm createDirectoryAtPath:[tree stringByAppendingPathComponent:@"sub/deep"] withIntermediateDirectories:YES attributes:nil error:NULL]);
        NSError *fmErr = nil;
        CHECK(![fm createDirectoryAtPath:tree withIntermediateDirectories:NO attributes:nil error:&fmErr] && fmErr.code == NSFileWriteFileExistsError);
        CHECK([fm createDirectoryAtPath:tree withIntermediateDirectories:YES attributes:nil error:NULL]);   // already there: fine
        CHECK([fm createFileAtPath:[tree stringByAppendingPathComponent:@"a.txt"] contents:[@"alpha" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil]);
        CHECK([fm createFileAtPath:[tree stringByAppendingPathComponent:@"sub/b.txt"] contents:[@"beta" dataUsingEncoding:NSUTF8StringEncoding] attributes:@{ NSFilePosixPermissions: @0640 }]);
        CHECK([fm createFileAtPath:[tree stringByAppendingPathComponent:@"sub/deep/c.txt"] contents:nil attributes:nil]);
        CHECK([fm createFileAtPath:[tree stringByAppendingPathComponent:@".hidden"] contents:nil attributes:nil]);
        CHECK([[[NSString alloc] initWithData:[fm contentsAtPath:[tree stringByAppendingPathComponent:@"a.txt"]] encoding:NSUTF8StringEncoding] isEqualToString:@"alpha"]);
        // symbolic and hard links
        NSString *link = [tree stringByAppendingPathComponent:@"link"];
        CHECK([fm createSymbolicLinkAtPath:link withDestinationPath:@"sub" error:NULL]);
        CHECK([[fm destinationOfSymbolicLinkAtPath:link error:NULL] isEqualToString:@"sub"]);
        CHECK([[fm attributesOfItemAtPath:link error:NULL].fileType isEqualToString:NSFileTypeSymbolicLink]);
        BOOL linkIsDir = NO;
        CHECK([fm fileExistsAtPath:link isDirectory:&linkIsDir] && linkIsDir);       // follows the link
        fmErr = nil;
        CHECK(![fm createSymbolicLinkAtPath:link withDestinationPath:@"x" error:&fmErr] && fmErr.code == NSFileWriteFileExistsError);
        fmErr = nil;
        CHECK(![fm destinationOfSymbolicLinkAtPath:[tree stringByAppendingPathComponent:@"a.txt"] error:&fmErr] && fmErr.code == NSFileReadUnknownError);
        CHECK([fm linkItemAtPath:[tree stringByAppendingPathComponent:@"a.txt"] toPath:[fmDir stringByAppendingPathComponent:@"hard.txt"] error:NULL]);
        CHECK([[fm attributesOfItemAtPath:[fmDir stringByAppendingPathComponent:@"hard.txt"] error:NULL][NSFileReferenceCount] integerValue] == 2);
        CHECK([fm contentsEqualAtPath:[tree stringByAppendingPathComponent:@"a.txt"] andPath:[fmDir stringByAppendingPathComponent:@"hard.txt"]]);
        CHECK([[@"~/x/../y" stringByResolvingSymlinksInPath] isEqualToString:[NSHomeDirectory() stringByAppendingPathComponent:@"y"]]);
        CHECK([[[link stringByAppendingPathComponent:@"b.txt"] stringByResolvingSymlinksInPath] hasSuffix:@"/tree/sub/b.txt"]);
        // the path enumerator: pre-order, sorted, links not followed, skipDescendants, level, attributes
        NSDirectoryEnumerator *en = [fm enumeratorAtPath:tree];
        NSMutableArray *seen = [NSMutableArray array];
        for (NSString *rel; (rel = [en nextObject]);) {
            [seen addObject:[NSString stringWithFormat:@"%@:%lu", rel, (unsigned long)en.level]];
            if ([rel isEqualToString:@"a.txt"]) CHECK(en.fileAttributes.fileSize == 5 && [en.directoryAttributes.fileType isEqualToString:NSFileTypeDirectory]);
        }
        CHECK([seen isEqual:(@[@".hidden:1", @"a.txt:1", @"link:1", @"sub:1", @"sub/b.txt:2", @"sub/deep:2", @"sub/deep/c.txt:3"])]);
        if (![seen isEqual:(@[@".hidden:1", @"a.txt:1", @"link:1", @"sub:1", @"sub/b.txt:2", @"sub/deep:2", @"sub/deep/c.txt:3"])]) NSLog(@"enumerator: %@", seen);
        en = [fm enumeratorAtPath:tree]; [seen removeAllObjects];
        for (NSString *rel in en) { [seen addObject:rel]; if ([rel isEqualToString:@"sub"]) [en skipDescendants]; }   // fast enumeration
        CHECK([seen isEqual:(@[@".hidden", @"a.txt", @"link", @"sub"])]);
        CHECK([[fm subpathsOfDirectoryAtPath:tree error:NULL] count] == 7 && [fm subpathsAtPath:[fmDir stringByAppendingPathComponent:@"missing"]] == nil);
        // the URL enumerator: options, post-order, error handler
        NSURL *treeURL = [NSURL fileURLWithPath:tree isDirectory:YES];
        en = [fm enumeratorAtURL:treeURL includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationIncludesDirectoriesPostOrder errorHandler:nil];
        [seen removeAllObjects];
        for (NSURL *u in en) [seen addObject:[NSString stringWithFormat:@"%@%@", [u.path substringFromIndex:tree.length + 1], en.isEnumeratingDirectoryPostOrder ? @"/post" : ([u.absoluteString hasSuffix:@"/"] ? @"/" : @"")]];
        CHECK([seen isEqual:(@[@"a.txt", @"link", @"sub/", @"sub/b.txt", @"sub/deep/", @"sub/deep/c.txt", @"sub/deep/post", @"sub/post"])]);
        if (![seen isEqual:(@[@"a.txt", @"link", @"sub/", @"sub/b.txt", @"sub/deep/", @"sub/deep/c.txt", @"sub/deep/post", @"sub/post"])]) NSLog(@"URL enumerator: %@", seen);
        CHECK([[fm enumeratorAtURL:treeURL includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil] allObjects].count == 4);
        __block NSInteger handled = 0;
        NSArray *none = [[fm enumeratorAtURL:[NSURL fileURLWithPath:[fmDir stringByAppendingPathComponent:@"missing"]] includingPropertiesForKeys:nil options:0
                                errorHandler:^BOOL(NSURL *u, NSError *e) { handled = e.code; return YES; }] allObjects];
        CHECK(none.count == 0 && handled == NSFileReadNoSuchFileError);
        NSArray<NSURL *> *shallow = [fm contentsOfDirectoryAtURL:treeURL includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
        CHECK(shallow.count == 3 && [shallow[2].absoluteString hasSuffix:@"/sub/"]);
        // resource values
        NSDictionary *rv = [[NSURL fileURLWithPath:link] resourceValuesForKeys:@[NSURLIsSymbolicLinkKey, NSURLIsDirectoryKey, NSURLNameKey, NSURLFileResourceTypeKey] error:NULL];
        CHECK([rv[NSURLIsSymbolicLinkKey] boolValue] && ![rv[NSURLIsDirectoryKey] boolValue] && [rv[NSURLNameKey] isEqualToString:@"link"] &&
              [rv[NSURLFileResourceTypeKey] isEqualToString:NSURLFileResourceTypeSymbolicLink]);
        id sizeValue = nil;
        CHECK([[NSURL fileURLWithPath:[tree stringByAppendingPathComponent:@"a.txt"]] getResourceValue:&sizeValue forKey:NSURLFileSizeKey error:NULL] && [sizeValue integerValue] == 5);
        fmErr = nil;
        CHECK(![[NSURL fileURLWithPath:@"/no/such/file"] resourceValuesForKeys:@[NSURLNameKey] error:&fmErr] && fmErr.code == NSFileReadNoSuchFileError);
        // copy (a whole tree, links kept as links, permissions kept), move, remove by URL
        NSString *copy = [fmDir stringByAppendingPathComponent:@"copy"];
        CHECK([fm copyItemAtPath:tree toPath:copy error:NULL]);
        CHECK([[fm destinationOfSymbolicLinkAtPath:[copy stringByAppendingPathComponent:@"link"] error:NULL] isEqualToString:@"sub"] &&
              [fm attributesOfItemAtPath:[copy stringByAppendingPathComponent:@"sub/b.txt"] error:NULL].filePosixPermissions == 0640 &&
              [fm contentsEqualAtPath:tree andPath:copy]);
        fmErr = nil;
        CHECK(![fm copyItemAtPath:tree toPath:copy error:&fmErr] && fmErr.code == NSFileWriteFileExistsError);
        fmErr = nil;
        CHECK(![fm copyItemAtPath:tree toPath:[tree stringByAppendingPathComponent:@"sub/inside"] error:&fmErr] && fmErr.code == NSFileWriteUnknownError &&
              ![fm fileExistsAtPath:[tree stringByAppendingPathComponent:@"sub/inside"]]);     // not into itself
        fmErr = nil;
        CHECK(![fm copyItemAtPath:[fmDir stringByAppendingPathComponent:@"missing"] toPath:[fmDir stringByAppendingPathComponent:@"x"] error:&fmErr] && fmErr.code == NSFileReadNoSuchFileError);
        NSURL *moved = [NSURL fileURLWithPath:[fmDir stringByAppendingPathComponent:@"moved"]];
        CHECK([fm moveItemAtURL:[NSURL fileURLWithPath:copy] toURL:moved error:NULL] && ![fm fileExistsAtPath:copy] && [fm fileExistsAtPath:[moved.path stringByAppendingPathComponent:@"sub/deep/c.txt"]]);
        fmErr = nil;
        CHECK(![fm moveItemAtPath:copy toPath:moved.path error:&fmErr] && fmErr.code == NSFileNoSuchFileError);
        CHECK([fm removeItemAtURL:moved error:NULL] && ![fm fileExistsAtPath:moved.path]);
        // replace, with and without a backup
        NSString *orig = [fmDir stringByAppendingPathComponent:@"doc.txt"], *repl = [fmDir stringByAppendingPathComponent:@"doc.new"];
        [@"old" writeToFile:orig atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        [fm setAttributes:@{ NSFilePosixPermissions: @0604 } ofItemAtPath:orig error:NULL];
        [@"new" writeToFile:repl atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        NSURL *resulting = nil;
        CHECK([fm replaceItemAtURL:[NSURL fileURLWithPath:orig] withItemAtURL:[NSURL fileURLWithPath:repl] backupItemName:@"doc.bak"
                           options:NSFileManagerItemReplacementWithoutDeletingBackupItem resultingItemURL:&resulting error:NULL]);
        CHECK([[NSString stringWithContentsOfFile:orig encoding:NSUTF8StringEncoding error:NULL] isEqualToString:@"new"] && ![fm fileExistsAtPath:repl] &&
              [[NSString stringWithContentsOfFile:[fmDir stringByAppendingPathComponent:@"doc.bak"] encoding:NSUTF8StringEncoding error:NULL] isEqualToString:@"old"] &&
              [resulting.path isEqualToString:orig] && [fm attributesOfItemAtPath:orig error:NULL].filePosixPermissions == 0604);
        [@"newer" writeToFile:repl atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        CHECK([fm replaceItemAtURL:[NSURL fileURLWithPath:orig] withItemAtURL:[NSURL fileURLWithPath:repl] backupItemName:@"doc.bak2" options:0 resultingItemURL:NULL error:NULL] &&
              ![fm fileExistsAtPath:[fmDir stringByAppendingPathComponent:@"doc.bak2"]]);
        // access checks, working directory, file system representation, error codes
        CHECK([fm isReadableFileAtPath:orig] && [fm isWritableFileAtPath:orig] && ![fm isExecutableFileAtPath:orig] && [fm isDeletableFileAtPath:orig] &&
              ![fm isDeletableFileAtPath:[fmDir stringByAppendingPathComponent:@"missing"]]);
        NSString *cwd = fm.currentDirectoryPath;
        CHECK([fm changeCurrentDirectoryPath:fmDir] && [fm.currentDirectoryPath.stringByResolvingSymlinksInPath isEqualToString:fmDir.stringByResolvingSymlinksInPath] &&
              [fm changeCurrentDirectoryPath:cwd] && ![fm changeCurrentDirectoryPath:@"/no/such/dir"]);
        CHECK(strcmp(orig.fileSystemRepresentation, [fm fileSystemRepresentationWithPath:orig]) == 0 &&
              [[fm stringWithFileSystemRepresentation:"caf\xc3\xa9/x" length:7] isEqualToString:@"café/x"] && [[fm displayNameAtPath:orig] isEqualToString:@"doc.txt"]);
        char fsbuf[8];
        CHECK([@"short" getFileSystemRepresentation:fsbuf maxLength:sizeof fsbuf] && !strcmp(fsbuf, "short") && ![@"much too long" getFileSystemRepresentation:fsbuf maxLength:sizeof fsbuf]);
        CHECK(NSFileNoSuchFileError == 4 && NSFileReadNoSuchFileError == 260 && NSFileWriteFileExistsError == 516 && NSPropertyListReadCorruptError == 3840);
        CHECK([fm removeItemAtPath:fmDir error:NULL]);
        thread_checks();
        file_checks();
        locale_checks();

        collection_checks();

        NSLog(@"foundation test: %d/%d passed", checks - failures, checks);
    }
    return failures;
}
