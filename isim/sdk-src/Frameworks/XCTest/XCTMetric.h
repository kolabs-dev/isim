#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* What measure(metrics:) measures. isim: XCTClockMetric and XCTApplicationLaunchMetric (the block's wall-clock time
 * per iteration, reported in Xcode's console format; no baselines). */
@protocol XCTMetric <NSObject, NSCopying>
@end

/* elapsed wall-clock time of each iteration (Xcode: "Clock Monotonic Time") */
@interface XCTClockMetric : NSObject <XCTMetric>
- (instancetype)init;
@end

/* how long the app takes to launch: the block launches it (XCUIApplication().launch()), and each iteration is timed
 * until the app shows its first window with content (isim's launch() waits for that, like XCUITest waits for the app
 * to idle); waitUntilResponsive is accepted and measures the same */
@interface XCTApplicationLaunchMetric : NSObject <XCTMetric>
- (instancetype)init;
- (instancetype)initWithWaitUntilResponsive:(BOOL)waitUntilResponsive;
@end

/* how many times measure runs the block (default 5) */
@interface XCTMeasureOptions : NSObject <NSCopying>
@property (class, readonly, copy) XCTMeasureOptions *defaultOptions;
@property NSUInteger iterationCount;
@end

NS_ASSUME_NONNULL_END
