#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSException.h>
#include <dispatch/dispatch.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray<ObjectType>, NSSet, NSProgress, NSInvocation, NSException;
typedef NS_ENUM(NSInteger, NSOperationQueuePriority) {
    NSOperationQueuePriorityVeryLow = -8L, NSOperationQueuePriorityLow = -4L, NSOperationQueuePriorityNormal = 0,
    NSOperationQueuePriorityHigh = 4, NSOperationQueuePriorityVeryHigh = 8
};
/* KVO-compliant: isReady, isExecuting, isFinished, isCancelled (a subclass's notifications drive its queue) */
@interface NSOperation : NSObject
- (void)start;
- (void)main;
@property (readonly, getter=isCancelled) BOOL cancelled;
- (void)cancel;
@property (readonly, getter=isExecuting) BOOL executing;
@property (readonly, getter=isFinished) BOOL finished;
@property (readonly, getter=isConcurrent) BOOL concurrent;
@property (readonly, getter=isAsynchronous) BOOL asynchronous;
@property (readonly, getter=isReady) BOOL ready;
- (void)addDependency:(NSOperation *)op;
- (void)removeDependency:(NSOperation *)op;
@property (readonly, copy) NSArray<NSOperation *> *dependencies;
@property NSOperationQueuePriority queuePriority;
@property (nullable, copy) void (^completionBlock)(void);
- (void)waitUntilFinished;
@property double threadPriority;
@property NSQualityOfService qualityOfService;
@property (nullable, copy) NSString *name;
@end

@interface NSBlockOperation : NSOperation
+ (instancetype)blockOperationWithBlock:(void (^)(void))block;
- (void)addExecutionBlock:(void (^)(void))block;
@property (readonly, copy) NSArray<void (^)(void)> *executionBlocks NS_REFINED_FOR_SWIFT;
@end

NS_SWIFT_UNAVAILABLE("NSInvocation and related APIs not available")
@interface NSInvocationOperation : NSOperation
- (nullable instancetype)initWithTarget:(id)target selector:(SEL)sel object:(nullable id)arg;
- (instancetype)initWithInvocation:(NSInvocation *)inv NS_DESIGNATED_INITIALIZER;
@property (readonly, retain) NSInvocation *invocation;
@property (nullable, readonly, retain) id result;
@end
FOUNDATION_EXPORT NSExceptionName const NSInvocationOperationVoidResultException;
FOUNDATION_EXPORT NSExceptionName const NSInvocationOperationCancelledException;

static const NSInteger NSOperationQueueDefaultMaxConcurrentOperationCount NS_SWIFT_NAME(OperationQueue.defaultMaxConcurrentOperationCount) = -1;

/* runs operations as they become ready (dependencies), by priority, up to maxConcurrentOperationCount at once */
@interface NSOperationQueue : NSObject
@property (class, readonly, strong) NSOperationQueue *mainQueue;
@property (class, readonly, strong, nullable) NSOperationQueue *currentQueue;
- (void)addOperation:(NSOperation *)op;
- (void)addOperations:(NSArray<NSOperation *> *)ops waitUntilFinished:(BOOL)wait;
- (void)addOperationWithBlock:(void (^)(void))block;
- (void)addBarrierBlock:(void (^)(void))barrier;
@property NSInteger maxConcurrentOperationCount;
@property (getter=isSuspended) BOOL suspended;
@property (nullable, copy) NSString *name;
@property NSQualityOfService qualityOfService;
@property (nullable, assign) dispatch_queue_t underlyingQueue;
@property (readonly, strong) NSProgress *progress;
- (void)cancelAllOperations;
- (void)waitUntilAllOperationsAreFinished;
@property (readonly, copy) NSArray<__kindof NSOperation *> *operations;
@property (readonly) NSUInteger operationCount;
@end
NS_ASSUME_NONNULL_END
