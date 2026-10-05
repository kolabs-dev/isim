#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString;
@interface NSThread : NSObject
@property (class, readonly) BOOL isMainThread;
@property (readonly) BOOL isMainThread;
@property (class, readonly, strong) NSThread *currentThread;
@property (class, readonly, strong) NSThread *mainThread;
@property (nullable, copy) NSString *name;
+ (void)sleepForTimeInterval:(NSTimeInterval)ti;
+ (void)detachNewThreadWithBlock:(void (^)(void))block;
@end
NS_ASSUME_NONNULL_END
