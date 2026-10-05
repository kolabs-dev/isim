#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSTimer, NSDate, NSString;
typedef NSString *NSRunLoopMode NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT NSRunLoopMode const NSDefaultRunLoopMode;
FOUNDATION_EXPORT NSRunLoopMode const NSRunLoopCommonModes;
@interface NSRunLoop : NSObject
@property (class, readonly, strong) NSRunLoop *currentRunLoop;
@property (class, readonly, strong) NSRunLoop *mainRunLoop;
- (void)addTimer:(NSTimer *)timer forMode:(NSRunLoopMode)mode;
- (void)run;
- (void)runUntilDate:(NSDate *)limitDate;
/* isim: fires due timers/performs; returns seconds until the next one (or a large value). */
- (NSTimeInterval)_isim_fireDue;
@end
NS_ASSUME_NONNULL_END
