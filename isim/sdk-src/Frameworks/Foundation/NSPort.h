#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSNotification.h>
NS_ASSUME_NONNULL_BEGIN
@class NSRunLoop;
typedef NSString *NSRunLoopMode NS_TYPED_EXTENSIBLE_ENUM;
/* a run loop input source: adding one keeps -[NSRunLoop run] running on that thread (isim: no messages are sent
 * through ports; NSMachPort is a port with a nominal mach port number) */
@interface NSPort : NSObject <NSCopying>
+ (NSPort *)port;
- (void)invalidate;
@property (readonly, getter=isValid) BOOL valid;
- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode;
- (void)removeFromRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode;
@property (nullable, assign) id delegate;
@end
FOUNDATION_EXPORT NSNotificationName const NSPortDidBecomeInvalidNotification;
@interface NSMachPort : NSPort
+ (NSPort *)portWithMachPort:(uint32_t)machPort;
@property (readonly) uint32_t machPort;
@end
NS_ASSUME_NONNULL_END
