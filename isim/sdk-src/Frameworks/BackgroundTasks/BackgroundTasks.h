#pragma once
/* isim BackgroundTasks for Objective-C: the classes are the BackgroundTasks Swift overlay's (BackgroundTasks.framework
   re-exports libswiftBackgroundTasks.dylib), on the same scheduler as Swift: submitted requests are kept in the app's
   container and run with the `bgtask` script command or `isim bgtask`. Swift uses the overlay; these declarations are
   hidden from Swift. The classes are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const BGTaskSchedulerErrorDomain;
typedef NS_ERROR_ENUM(BGTaskSchedulerErrorDomain, BGTaskSchedulerErrorCode) {
    BGTaskSchedulerErrorCodeUnavailable = 1,
    BGTaskSchedulerErrorCodeTooManyPendingTaskRequests = 2,
    BGTaskSchedulerErrorCodeNotPermitted = 3,
    BGTaskSchedulerErrorCodeImmediateRunIneligible API_AVAILABLE(ios(26.0)) = 4,
};

@interface BGTaskRequest : NSObject <NSCopying>
@property (readonly, copy) NSString *identifier;
@property (copy, nullable) NSDate *earliestBeginDate;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@interface BGAppRefreshTaskRequest : BGTaskRequest
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end

@interface BGProcessingTaskRequest : BGTaskRequest
- (instancetype)initWithIdentifier:(NSString *)identifier;
@property (assign) BOOL requiresNetworkConnectivity;
@property (assign) BOOL requiresExternalPower;
@end

/* iOS 26: work that starts in the foreground and goes on when the app is in the background, shown in a Live Activity
   (isim: the shell's, with a cancel button) until it completes; the identifier matches a BUNDLE-ID.CONTEXT.* entry in
   BGTaskSchedulerPermittedIdentifiers. Two run at a time. */
typedef NS_ENUM(NSInteger, BGContinuedProcessingTaskRequestSubmissionStrategy) {
    BGContinuedProcessingTaskRequestSubmissionStrategyFail = 0,
    BGContinuedProcessingTaskRequestSubmissionStrategyQueue = 1,
} API_AVAILABLE(ios(26.0));
typedef NS_OPTIONS(NSInteger, BGContinuedProcessingTaskRequestResources) {
    BGContinuedProcessingTaskRequestResourcesDefault = 0,
    BGContinuedProcessingTaskRequestResourcesGPU = 1 << 0,
} API_AVAILABLE(ios(26.0));

API_AVAILABLE(ios(26.0))
@interface BGContinuedProcessingTaskRequest : BGTaskRequest
- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title subtitle:(NSString *)subtitle;
@property (copy) NSString *title;
@property (copy) NSString *subtitle;
@property (assign) BGContinuedProcessingTaskRequestSubmissionStrategy strategy;
@property (assign) BGContinuedProcessingTaskRequestResources requiredResources;
@end

@interface BGTask : NSObject
@property (readonly, copy) NSString *identifier;
@property (nullable, strong) void (^expirationHandler)(void);
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (void)setTaskCompletedWithSuccess:(BOOL)success;
@end
@interface BGAppRefreshTask : BGTask
@end
@interface BGProcessingTask : BGTask
@end
API_AVAILABLE(ios(26.0))
@interface BGContinuedProcessingTask : BGTask <NSProgressReporting>
@property (readonly, copy) NSString *title;
@property (readonly, copy) NSString *subtitle;
- (void)updateTitle:(NSString *)title subtitle:(NSString *)subtitle;
@end

@interface BGTaskScheduler : NSObject
@property (class, readonly, strong) BGTaskScheduler *sharedScheduler;
@property (class, readonly) BGContinuedProcessingTaskRequestResources supportedResources API_AVAILABLE(ios(26.0));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
/* the handler runs on the queue (NULL: a background queue); NO when the identifier is not in Info.plist
   BGTaskSchedulerPermittedIdentifiers or already has a handler */
- (BOOL)registerForTaskWithIdentifier:(NSString *)identifier usingQueue:(nullable dispatch_queue_t)queue
                        launchHandler:(void (^)(__kindof BGTask *task))launchHandler;
- (BOOL)submitTaskRequest:(BGTaskRequest *)taskRequest error:(NSError **)error;
- (void)cancelTaskRequestWithIdentifier:(NSString *)identifier;
- (void)cancelAllTaskRequests;
- (void)getPendingTaskRequestsWithCompletionHandler:(void (^)(NSArray<BGTaskRequest *> *taskRequests))completionHandler;
@end

NS_ASSUME_NONNULL_END
#endif
