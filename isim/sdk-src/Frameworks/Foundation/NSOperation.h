#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString;
/* isim: block-based operation queues on top of the dispatch subset (no NSOperation dependencies). */
@interface NSOperationQueue : NSObject
@property (class, readonly, strong) NSOperationQueue *mainQueue;
@property (class, readonly, strong, nullable) NSOperationQueue *currentQueue;
@property (nullable, copy) NSString *name;
@property NSInteger maxConcurrentOperationCount;
@property (getter=isSuspended) BOOL suspended;
- (void)addOperationWithBlock:(void (^)(void))block;
- (void)addBarrierBlock:(void (^)(void))barrier;
- (void)waitUntilAllOperationsAreFinished;
- (void)cancelAllOperations;
@end
NS_ASSUME_NONNULL_END
