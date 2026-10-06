#pragma once
#import <XCTest/XCTestDefines.h>

NS_ASSUME_NONNULL_BEGIN

@interface XCTestExpectation : NSObject
- (instancetype)initWithDescription:(NSString *)expectationDescription;
@property (copy) NSString *expectationDescription;
@property (getter=isInverted) BOOL inverted;
@property NSUInteger expectedFulfillmentCount;
@property BOOL assertForOverFulfill;
- (void)fulfill;
/* isim: fulfillment state (used by the Swift overlay's fulfillment(of:)) */
- (BOOL)_isimIsFulfilled;
- (BOOL)_isimHasAnyFulfillment;
@end

@interface XCTNSNotificationExpectation : XCTestExpectation
- (instancetype)initWithName:(NSNotificationName)notificationName object:(nullable id)object;
- (instancetype)initWithName:(NSNotificationName)notificationName;
@property (readonly, copy) NSNotificationName notificationName;
@property (nullable, copy) XCNotificationExpectationHandler handler;
@end

@interface XCTNSPredicateExpectation : XCTestExpectation
- (instancetype)initWithPredicate:(NSPredicate *)predicate object:(nullable id)object;
@property (readonly, copy) NSPredicate *predicate;
@property (nullable, readonly, strong) id object;
@property (nullable, copy) XCPredicateExpectationHandler handler;
@end

typedef NS_ENUM(NSInteger, XCTWaiterResult) {
    XCTWaiterResultCompleted = 1,
    XCTWaiterResultTimedOut,
    XCTWaiterResultIncorrectOrder,
    XCTWaiterResultInvertedFulfillment,
    XCTWaiterResultInterrupted,
} NS_SWIFT_NAME(XCTWaiter.Result);

/* Waits for expectations while the main run loop keeps running (timers, main-queue work, MainActor tasks). */
@interface XCTWaiter : NSObject
+ (XCTWaiterResult)waitForExpectations:(NSArray<XCTestExpectation *> *)expectations timeout:(NSTimeInterval)seconds
    NS_SWIFT_NAME(wait(for:timeout:)) NS_SWIFT_DISABLE_ASYNC;
+ (XCTWaiterResult)waitForExpectations:(NSArray<XCTestExpectation *> *)expectations timeout:(NSTimeInterval)seconds enforceOrder:(BOOL)enforceOrder
    NS_SWIFT_NAME(wait(for:timeout:enforceOrder:)) NS_SWIFT_DISABLE_ASYNC;
- (XCTWaiterResult)waitForExpectations:(NSArray<XCTestExpectation *> *)expectations timeout:(NSTimeInterval)seconds
    NS_SWIFT_NAME(wait(for:timeout:)) NS_SWIFT_DISABLE_ASYNC;
- (XCTWaiterResult)waitForExpectations:(NSArray<XCTestExpectation *> *)expectations timeout:(NSTimeInterval)seconds enforceOrder:(BOOL)enforceOrder
    NS_SWIFT_NAME(wait(for:timeout:enforceOrder:)) NS_SWIFT_DISABLE_ASYNC;
@property (readonly, copy) NSArray<XCTestExpectation *> *fulfilledExpectations;
@end

NS_ASSUME_NONNULL_END
