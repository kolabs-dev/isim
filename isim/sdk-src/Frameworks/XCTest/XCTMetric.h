#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class XCUIApplication;

/* A moment of a measurement: mach absolute time and the date. */
@interface XCTPerformanceMeasurementTimestamp : NSObject <NSCopying>
- (instancetype)initWithAbsoluteTime:(uint64_t)absoluteTime date:(NSDate *)date NS_DESIGNATED_INITIALIZER;
/* now */
- (instancetype)init;
@property (readonly) uint64_t absoluteTime;
@property (readonly) uint64_t absoluteTimeNanoSeconds;
@property (readonly, copy) NSDate *date;
@end

typedef NS_ENUM(NSInteger, XCTPerformanceMeasurementPolarity) {
    XCTPerformanceMeasurementPolarityUnspecified = 0,
    XCTPerformanceMeasurementPolarityPrefersLarger = 1,
    XCTPerformanceMeasurementPolarityPrefersSmaller = -1,
} NS_SWIFT_NAME(XCTPerformanceMeasurement.Polarity);

/* One value a metric reports for one iteration. */
@interface XCTPerformanceMeasurement : NSObject
- (instancetype)initWithIdentifier:(NSString *)identifier displayName:(NSString *)displayName doubleValue:(double)doubleValue
                        unitSymbol:(NSString *)unitSymbol;
- (instancetype)initWithIdentifier:(NSString *)identifier displayName:(NSString *)displayName doubleValue:(double)doubleValue
                        unitSymbol:(NSString *)unitSymbol polarity:(XCTPerformanceMeasurementPolarity)polarity;
- (instancetype)initWithIdentifier:(NSString *)identifier displayName:(NSString *)displayName value:(NSMeasurement<NSUnit *> *)value;
- (instancetype)initWithIdentifier:(NSString *)identifier displayName:(NSString *)displayName value:(NSMeasurement<NSUnit *> *)value
                          polarity:(XCTPerformanceMeasurementPolarity)polarity;
- (instancetype)init NS_UNAVAILABLE;
@property (readonly, copy) NSString *identifier;
@property (readonly, copy) NSString *displayName;
@property (readonly, copy) NSMeasurement<NSUnit *> *value;
@property (readonly) double doubleValue;
@property (readonly, copy) NSString *unitSymbol;
@property (readonly) XCTPerformanceMeasurementPolarity polarity;
@end

/* What measure(metrics:) measures: each iteration the metric is told it begins (willBeginMeasuring), the block runs
 * between the start and end timestamps, the metric is told it stopped (didStopMeasuring) and reports its values
 * (reportMeasurements). Custom metrics conform too. isim (adapted): no baselines; the values are printed in Xcode's
 * console format, one line per value name. */
@protocol XCTMetric <NSCopying, NSObject>
- (nullable NSArray<XCTPerformanceMeasurement *> *)reportMeasurementsFromStartTime:(XCTPerformanceMeasurementTimestamp *)startTime
                                                                         toEndTime:(XCTPerformanceMeasurementTimestamp *)endTime
                                                                             error:(NSError **)error
    NS_SWIFT_NAME(reportMeasurements(from:to:));
@optional
- (void)willBeginMeasuring;
- (void)didStopMeasuring;
@end

/* elapsed wall-clock time of each iteration (Xcode: "Clock Monotonic Time") */
@interface XCTClockMetric : NSObject <XCTMetric>
- (instancetype)init;
@end

/* CPU time of the test process (or of the measuring thread). isim (adapted): CPU Time only; the cycle and
 * instruction counts Xcode also reports need the processor's counters. An app's CPU (application:) is not measured
 * (the app runs in its own process): it reports nothing, with a warning. */
@interface XCTCPUMetric : NSObject <XCTMetric>
- (instancetype)init;
- (instancetype)initLimitingToCurrentThread:(BOOL)limitToCurrentThread;
- (instancetype)initWithApplication:(XCUIApplication *)application;
@end

/* memory of the test process: the change in its physical footprint over each iteration and its peak footprint
 * (task_info TASK_VM_INFO). An app's memory (application:) is not measured (a warning). */
@interface XCTMemoryMetric : NSObject <XCTMetric>
- (instancetype)init;
- (instancetype)initWithApplication:(XCUIApplication *)application;
@end

/* bytes the test process writes (files, pipes): "Disk Logical Writes". An app's writes (application:) are not
 * measured (a warning). */
@interface XCTStorageMetric : NSObject <XCTMetric>
- (instancetype)init;
- (instancetype)initWithApplication:(XCUIApplication *)application;
@end

/* the duration of os_signpost intervals (begin/end with the same name) logged during each iteration by the test
 * process; the class metrics are the intervals isim's UIKit logs (subsystem com.apple.isim.UIKit, category Performance:
 * NavigationTransition, CustomNavigationTransition, ScrollDragging, ScrollDeceleration). applicationLaunch measures
 * the launch like XCTApplicationLaunchMetric. */
@interface XCTOSSignpostMetric : NSObject <XCTMetric>
- (instancetype)initWithSubsystem:(NSString *)subsystem category:(NSString *)category name:(NSString *)name;
- (instancetype)init NS_UNAVAILABLE;
@property (class, readonly, nonatomic) id<XCTMetric> navigationTransitionMetric;
@property (class, readonly, nonatomic) id<XCTMetric> customNavigationTransitionMetric;
@property (class, readonly, nonatomic) id<XCTMetric> scrollDecelerationMetric;
@property (class, readonly, nonatomic) id<XCTMetric> scrollDraggingMetric;
@property (class, readonly, nonatomic) id<XCTMetric> scrollingAndDecelerationMetric;
@property (class, readonly, nonatomic) XCTOSSignpostMetric *applicationLaunchMetric NS_SWIFT_NAME(applicationLaunch);
@end

/* how long the app takes to launch: the block launches it (XCUIApplication().launch()), and each iteration is timed
 * until the app shows its first window with content (isim's launch() waits for that, like XCUITest waits for the app
 * to idle); waitUntilResponsive is accepted and measures the same */
@interface XCTApplicationLaunchMetric : NSObject <XCTMetric>
- (instancetype)init;
- (instancetype)initWithWaitUntilResponsive:(BOOL)waitUntilResponsive;
@end

/* when measuring starts and stops within the block: by default around the whole block; manuallyStart: from the
 * block's startMeasuring(); manuallyStop: until its stopMeasuring() */
typedef NS_OPTIONS(NSUInteger, XCTMeasurementInvocationOptions) {
    XCTMeasurementInvocationNone = 0,
    XCTMeasurementInvocationManuallyStart = 1 << 0,
    XCTMeasurementInvocationManuallyStop = 1 << 1,
} NS_SWIFT_NAME(XCTMeasureOptions.InvocationOptions);

/* how many times measure runs the block (default 5) and when it measures */
@interface XCTMeasureOptions : NSObject <NSCopying>
@property (class, readonly, copy) XCTMeasureOptions *defaultOptions;
@property NSUInteger iterationCount;
@property XCTMeasurementInvocationOptions invocationOptions;
@end

/* the older measureMetrics API's metrics */
typedef NSString *XCTPerformanceMetric NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT XCTPerformanceMetric const XCTPerformanceMetric_WallClockTime NS_SWIFT_NAME(wallClockTime);

NS_ASSUME_NONNULL_END
