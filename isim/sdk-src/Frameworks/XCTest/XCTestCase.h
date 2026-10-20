#pragma once
#import <XCTest/XCTestRun.h>
#import <XCTest/XCTMetric.h>

NS_ASSUME_NONNULL_BEGIN

@class XCUIElement, XCTAttachment, XCTIssue;

/* Something attachments are added to: a test case. */
@protocol XCTActivity <NSObject>
@property (readonly, copy) NSString *name;
- (void)addAttachment:(XCTAttachment *)attachment NS_SWIFT_NAME(add(_:));
@end

/* A test case. The runner discovers subclasses through the Objective-C runtime and runs every instance
 * method whose name starts with "test" and takes no arguments (Swift: `func testX()`, `func testX() throws`,
 * `func testX() async throws`; members of XCTestCase subclasses are @objc, like on Apple platforms). */
__attribute__((swift_attr("@objcMembers")))
@interface XCTestCase : XCTest <XCTActivity>
+ (instancetype)testCaseWithSelector:(SEL)selector;
- (instancetype)initWithSelector:(SEL)selector;
@property (nullable, readonly) SEL selector NS_REFINED_FOR_SWIFT;
@property BOOL continueAfterFailure;
@property NSTimeInterval executionTimeAllowance;

+ (XCTestSuite *)defaultTestSuite;
+ (NSArray<NSString *> *)testSelectorNames NS_SWIFT_UNAVAILABLE("isim runner internal");
+ (void)setUp;
+ (void)tearDown;

- (void)setUpWithCompletionHandler:(void (^)(NSError *_Nullable error))completion NS_SWIFT_ASYNC_NAME(setUp());
- (void)tearDownWithCompletionHandler:(void (^)(NSError *_Nullable error))completion NS_SWIFT_ASYNC_NAME(tearDown());

- (void)addTeardownBlock:(void (^)(void))block;

- (void)recordFailureWithDescription:(NSString *)description inFile:(NSString *)filePath atLine:(NSUInteger)lineNumber expected:(BOOL)expected
    NS_SWIFT_NAME(recordFailure(withDescription:inFile:atLine:expected:));
/* every issue of the test goes through here (assertions, thrown errors, exceptions): an XCTExpectFailure scope that
 * matches it makes it an expected failure; otherwise the test fails. Overrides can change it before calling super. */
- (void)recordIssue:(XCTIssue *)issue NS_SWIFT_NAME(record(_:)) NS_REQUIRES_SUPER;

/* performance: runs the block 10 times and reports the average wall-clock time */
- (void)measureBlock:(void (NS_NOESCAPE ^)(void))block NS_SWIFT_NAME(measure(_:));
/* performance with metrics (XCTClockMetric, XCTApplicationLaunchMetric): the block runs options.iterationCount
 * times (default 5), each metric reported in Xcode's console format; defaultMetrics: the clock */
@property (class, readonly, copy) NSArray<id<XCTMetric>> *defaultMetrics;
@property (class, readonly, copy) XCTMeasureOptions *defaultMeasureOptions;
- (void)measureWithMetrics:(NSArray<id<XCTMetric>> *)metrics block:(void (NS_NOESCAPE ^)(void))block
    NS_SWIFT_NAME(measure(metrics:block:));
- (void)measureWithOptions:(XCTMeasureOptions *)options block:(void (NS_NOESCAPE ^)(void))block
    NS_SWIFT_NAME(measure(options:block:));
- (void)measureWithMetrics:(NSArray<id<XCTMetric>> *)metrics options:(XCTMeasureOptions *)options
                     block:(void (NS_NOESCAPE ^)(void))block NS_SWIFT_NAME(measure(metrics:options:block:));

/* attachments: kept with the test's results (XCTAttachment's lifetime) */
- (void)addAttachment:(XCTAttachment *)attachment NS_SWIFT_NAME(add(_:));

/* UI tests: whether the test runs once per UI configuration of the app (appearance, orientation). isim (adapted): the
 * test runs once, in the device's current configuration. Default NO. */
@property (class, readonly) BOOL runsForEachTargetApplicationUIConfiguration;

/* expectations */
- (XCTestExpectation *)expectationWithDescription:(NSString *)description NS_SWIFT_NAME(expectation(description:));
- (XCTestExpectation *)expectationForNotification:(NSNotificationName)notificationName object:(nullable id)objectToObserve
                                          handler:(nullable XCNotificationExpectationHandler)handler NS_SWIFT_NAME(expectation(forNotification:object:handler:));
- (XCTestExpectation *)expectationForPredicate:(NSPredicate *)predicate evaluatedWithObject:(nullable id)object
                                       handler:(nullable XCPredicateExpectationHandler)handler NS_SWIFT_NAME(expectation(for:evaluatedWith:handler:));
- (XCTestExpectation *)keyValueObservingExpectationForObject:(id)objectToObserve keyPath:(NSString *)keyPath expectedValue:(nullable id)expectedValue
    NS_SWIFT_NAME(keyValueObservingExpectation(for:keyPath:expectedValue:));
- (XCTestExpectation *)keyValueObservingExpectationForObject:(id)objectToObserve keyPath:(NSString *)keyPath
                                                     handler:(nullable XCKeyValueObservingExpectationHandler)handler
    NS_SWIFT_NAME(keyValueObservingExpectation(for:keyPath:handler:));
- (void)waitForExpectationsWithTimeout:(NSTimeInterval)timeout handler:(nullable XCWaitCompletionHandler)handler
    NS_SWIFT_NAME(waitForExpectations(timeout:handler:)) NS_SWIFT_DISABLE_ASYNC;
- (void)waitForExpectations:(NSArray<XCTestExpectation *> *)expectations timeout:(NSTimeInterval)seconds
    NS_SWIFT_NAME(wait(for:timeout:)) NS_SWIFT_DISABLE_ASYNC;
- (void)waitForExpectations:(NSArray<XCTestExpectation *> *)expectations timeout:(NSTimeInterval)seconds enforceOrder:(BOOL)enforceOrderOfFulfillment
    NS_SWIFT_NAME(wait(for:timeout:enforceOrder:)) NS_SWIFT_DISABLE_ASYNC;
@end

@interface XCTestCase (XCUIInterruptionMonitor)
/* UI interruption monitors (UI tests): when a system alert (isim: a permission prompt, listed under the
 * "com.apple.springboard" application) is up before an action on the app, the monitors are called with it, the most
 * recently added first, until one returns YES (it handled the alert). Removed at the end of the test. */
- (id<NSObject>)addUIInterruptionMonitorWithDescription:(NSString *)handlerDescription handler:(BOOL (^)(XCUIElement *interruptingElement))handler;
- (void)removeUIInterruptionMonitor:(id<NSObject>)monitor;
@end

NS_ASSUME_NONNULL_END
