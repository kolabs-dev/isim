#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSNotification.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray<ObjectType>, NSNumber, NSMutableDictionary, NSDate;
/* a pthread with its own run loop (NSRunLoop.currentRunLoop on it) */
@interface NSThread : NSObject
@property (class, readonly, strong) NSThread *currentThread;
@property (class, readonly, strong) NSThread *mainThread;
@property (class, readonly) BOOL isMainThread;
@property (readonly) BOOL isMainThread;
+ (void)detachNewThreadWithBlock:(void (^)(void))block;
+ (void)detachNewThreadSelector:(SEL)selector toTarget:(id)target withObject:(nullable id)argument;
+ (BOOL)isMultiThreaded;
@property (readonly, retain) NSMutableDictionary *threadDictionary;
+ (void)sleepUntilDate:(NSDate *)date;
+ (void)sleepForTimeInterval:(NSTimeInterval)ti;
+ (void)exit;
+ (double)threadPriority;
+ (BOOL)setThreadPriority:(double)p;
@property double threadPriority;
@property NSQualityOfService qualityOfService;
@property (class, readonly, copy) NSArray<NSNumber *> *callStackReturnAddresses;
@property (class, readonly, copy) NSArray<NSString *> *callStackSymbols;
@property (nullable, copy) NSString *name;
@property NSUInteger stackSize;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithTarget:(id)target selector:(SEL)selector object:(nullable id)argument;
- (instancetype)initWithBlock:(void (^)(void))block;
@property (readonly, getter=isExecuting) BOOL executing;
@property (readonly, getter=isFinished) BOOL finished;
@property (readonly, getter=isCancelled) BOOL cancelled;
- (void)cancel;
- (void)start;
- (void)main;
@end
FOUNDATION_EXPORT NSNotificationName const NSWillBecomeMultiThreadedNotification;
FOUNDATION_EXPORT NSNotificationName const NSDidBecomeSingleThreadedNotification;
FOUNDATION_EXPORT NSNotificationName const NSThreadWillExitNotification;

@interface NSObject (NSThreadPerformAdditions)
- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(nullable id)arg waitUntilDone:(BOOL)wait;
- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(nullable id)arg waitUntilDone:(BOOL)wait modes:(nullable NSArray<NSString *> *)array;
- (void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(nullable id)arg waitUntilDone:(BOOL)wait modes:(nullable NSArray<NSString *> *)array;
- (void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(nullable id)arg waitUntilDone:(BOOL)wait;
- (void)performSelectorInBackground:(SEL)aSelector withObject:(nullable id)arg;
@end
NS_ASSUME_NONNULL_END
