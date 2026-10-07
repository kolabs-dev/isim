#pragma once
#import <XCTest/XCTestRun.h>

NS_ASSUME_NONNULL_BEGIN

/* A test case. The runner discovers subclasses through the Objective-C runtime and runs every instance
 * method whose name starts with "test" and takes no arguments (Swift: `func testX()`, `func testX() throws`,
 * `func testX() async throws`; members of XCTestCase subclasses are @objc, like on Apple platforms). */
__attribute__((swift_attr("@objcMembers")))
@interface XCTestCase : XCTest
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

/* performance: runs the block 10 times and reports the average wall-clock time */
- (void)measureBlock:(void (NS_NOESCAPE ^)(void))block NS_SWIFT_NAME(measure(_:));

/* expectations */
- (XCTestExpectation *)expectationWithDescription:(NSString *)description NS_SWIFT_NAME(expectation(description:));
- (XCTestExpectation *)expectationForNotification:(NSNotificationName)notificationName object:(nullable id)objectToObserve
                                          handler:(nullable XCNotificationExpectationHandler)handler NS_SWIFT_NAME(expectation(forNotification:object:handler:));
- (XCTestExpectation *)expectationForPredicate:(NSPredicate *)predicate evaluatedWithObject:(nullable id)object
                                       handler:(nullable XCPredicateExpectationHandler)handler NS_SWIFT_NAME(expectation(for:evaluatedWith:handler:));
- (void)waitForExpectationsWithTimeout:(NSTimeInterval)timeout handler:(nullable XCWaitCompletionHandler)handler
    NS_SWIFT_NAME(waitForExpectations(timeout:handler:)) NS_SWIFT_DISABLE_ASYNC;
- (void)waitForExpectations:(NSArray<XCTestExpectation *> *)expectations timeout:(NSTimeInterval)seconds
    NS_SWIFT_NAME(wait(for:timeout:)) NS_SWIFT_DISABLE_ASYNC;
- (void)waitForExpectations:(NSArray<XCTestExpectation *> *)expectations timeout:(NSTimeInterval)seconds enforceOrder:(BOOL)enforceOrderOfFulfillment
    NS_SWIFT_NAME(wait(for:timeout:enforceOrder:)) NS_SWIFT_DISABLE_ASYNC;
@end

NS_ASSUME_NONNULL_END
