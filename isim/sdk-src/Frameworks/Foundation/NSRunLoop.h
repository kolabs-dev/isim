#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSPort.h>
NS_ASSUME_NONNULL_BEGIN
@class NSTimer, NSDate, NSString, NSArray<ObjectType>;
FOUNDATION_EXPORT NSRunLoopMode const NSDefaultRunLoopMode;
FOUNDATION_EXPORT NSRunLoopMode const NSRunLoopCommonModes;
/* one per thread: timers, delayed and ordered performs, blocks and ports, each in a set of modes */
@interface NSRunLoop : NSObject
@property (class, readonly, strong) NSRunLoop *currentRunLoop;
@property (class, readonly, strong) NSRunLoop *mainRunLoop;
@property (nullable, readonly, copy) NSRunLoopMode currentMode;
- (void)addTimer:(NSTimer *)timer forMode:(NSRunLoopMode)mode NS_SWIFT_NAME(add(_:forMode:));
- (void)addPort:(NSPort *)aPort forMode:(NSRunLoopMode)mode NS_SWIFT_NAME(add(_:forMode:));
- (void)removePort:(NSPort *)aPort forMode:(NSRunLoopMode)mode NS_SWIFT_NAME(remove(_:forMode:));
- (nullable NSDate *)limitDateForMode:(NSRunLoopMode)mode NS_SWIFT_NAME(limitDate(forMode:));
- (void)acceptInputForMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate NS_SWIFT_NAME(acceptInput(forMode:before:));
- (void)run;
- (void)runUntilDate:(NSDate *)limitDate NS_SWIFT_NAME(run(until:));
- (BOOL)runMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate NS_SWIFT_NAME(run(mode:before:));
- (void)performInModes:(NSArray<NSRunLoopMode> *)modes block:(void (^)(void))block NS_SWIFT_NAME(perform(inModes:block:));
- (void)performBlock:(void (^)(void))block NS_SWIFT_NAME(perform(_:));
- (void)performSelector:(SEL)aSelector target:(id)target argument:(nullable id)arg order:(NSUInteger)order modes:(NSArray<NSRunLoopMode> *)modes NS_SWIFT_NAME(perform(_:target:argument:order:modes:));
- (void)cancelPerformSelector:(SEL)aSelector target:(id)target argument:(nullable id)arg NS_SWIFT_NAME(cancelPerform(_:target:argument:));
- (void)cancelPerformSelectorsWithTarget:(id)target NS_SWIFT_NAME(cancelPerformSelectors(withTarget:));
/* isim: fires the main run loop's due items in the mode UIKit runs it in; returns seconds until the next one */
- (NSTimeInterval)_isim_fireDue;
@end
@interface NSObject (NSDelayedPerforming)
- (void)performSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay inModes:(NSArray<NSRunLoopMode> *)modes;
+ (void)cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector object:(nullable id)anArgument;
@end
/* isim: UIKit runs the main run loop in this mode while the user tracks a control or scroll view (nil: default) */
FOUNDATION_EXPORT void isim_runloop_set_main_mode(NSRunLoopMode _Nullable mode);
FOUNDATION_EXPORT void isim_runloop_add_common_mode(NSRunLoop *loop, NSRunLoopMode mode);
/* isim: a block timer on the current run loop in its common modes: system frameworks' timers keep running while the
 * user scrolls, as on iOS (an app's scheduledTimer uses the default mode) */
FOUNDATION_EXPORT NSTimer *isim_scheduled_common_timer(NSTimeInterval interval, BOOL repeats, void (^block)(NSTimer *timer));
NS_ASSUME_NONNULL_END
