#pragma once
@class NSURL, NSNumber;
#import <Foundation/NSObject.h>
#import <Foundation/NSNotification.h>
NS_ASSUME_NONNULL_BEGIN
@class NSArray<ObjectType>, NSString, NSDictionary<KeyType, ObjectType>;
FOUNDATION_EXPORT NSNotificationName const NSUndoManagerCheckpointNotification, NSUndoManagerWillUndoChangeNotification,
    NSUndoManagerWillRedoChangeNotification, NSUndoManagerDidUndoChangeNotification, NSUndoManagerDidRedoChangeNotification,
    NSUndoManagerDidOpenUndoGroupNotification, NSUndoManagerWillCloseUndoGroupNotification, NSUndoManagerDidCloseUndoGroupNotification;
/* isim: prepareWithInvocationTarget: (NSInvocation forwarding) is not available; use the target/selector or
 * handler registrations. */
@interface NSUndoManager : NSObject
- (void)beginUndoGrouping;
- (void)endUndoGrouping;
@property (readonly) NSInteger groupingLevel;
- (void)disableUndoRegistration;
- (void)enableUndoRegistration;
@property (readonly, getter=isUndoRegistrationEnabled) BOOL undoRegistrationEnabled;
@property BOOL groupsByEvent;
@property NSUInteger levelsOfUndo;
@property (copy) NSArray *runLoopModes;
- (void)undo;
- (void)redo;
- (void)undoNestedGroup;
@property (readonly) BOOL canUndo;
@property (readonly) BOOL canRedo;
@property (readonly, getter=isUndoing) BOOL undoing;
@property (readonly, getter=isRedoing) BOOL redoing;
- (void)removeAllActions;
- (void)removeAllActionsWithTarget:(id)target;
- (void)registerUndoWithTarget:(id)target selector:(SEL)selector object:(nullable id)anObject;
- (void)registerUndoWithTarget:(id)target handler:(void (^)(id target))undoHandler NS_SWIFT_NAME(_isimRegisterUndo(withTarget:handler:));
- (void)setActionName:(NSString *)actionName;
@property (readonly, copy) NSString *undoActionName;
@property (readonly, copy) NSString *redoActionName;
@property (readonly, copy) NSString *undoMenuItemTitle;
@property (readonly, copy) NSString *redoMenuItemTitle;
- (NSString *)undoMenuTitleForUndoActionName:(NSString *)actionName;
- (NSString *)redoMenuTitleForUndoActionName:(NSString *)actionName;
@end

typedef NSString *NSProgressKind NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(ProgressKind);
typedef NSString *NSProgressUserInfoKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(ProgressUserInfoKey);
typedef NSString *NSProgressFileOperationKind NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(Progress.FileOperationKind);
FOUNDATION_EXPORT NSProgressKind const NSProgressKindFile NS_SWIFT_NAME(file);
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressEstimatedTimeRemainingKey NS_SWIFT_NAME(estimatedTimeRemainingKey);
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressThroughputKey NS_SWIFT_NAME(throughputKey);
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressFileOperationKindKey NS_SWIFT_NAME(fileOperationKindKey);
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressFileURLKey NS_SWIFT_NAME(fileURLKey);
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressFileTotalCountKey NS_SWIFT_NAME(fileTotalCountKey);
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressFileCompletedCountKey NS_SWIFT_NAME(fileCompletedCountKey);
FOUNDATION_EXPORT NSProgressFileOperationKind const NSProgressFileOperationKindDownloading NS_SWIFT_NAME(downloading);
FOUNDATION_EXPORT NSProgressFileOperationKind const NSProgressFileOperationKindDecompressingAfterDownloading NS_SWIFT_NAME(decompressingAfterDownloading);
FOUNDATION_EXPORT NSProgressFileOperationKind const NSProgressFileOperationKindReceiving NS_SWIFT_NAME(receiving);
FOUNDATION_EXPORT NSProgressFileOperationKind const NSProgressFileOperationKindCopying NS_SWIFT_NAME(copying);
FOUNDATION_EXPORT NSProgressFileOperationKind const NSProgressFileOperationKindUploading NS_SWIFT_NAME(uploading);
FOUNDATION_EXPORT NSProgressFileOperationKind const NSProgressFileOperationKindDuplicating NS_SWIFT_NAME(duplicating);
@class NSProgress;
/* an object that reports its work with a progress */
NS_SWIFT_NAME(ProgressReporting)
@protocol NSProgressReporting <NSObject>
@property (readonly) NSProgress *progress;
@end
@interface NSProgress : NSObject
@property (class, nullable, readonly) NSProgress *currentProgress;
+ (NSProgress *)progressWithTotalUnitCount:(int64_t)unitCount;
+ (NSProgress *)discreteProgressWithTotalUnitCount:(int64_t)unitCount;
+ (NSProgress *)progressWithTotalUnitCount:(int64_t)unitCount parent:(NSProgress *)parent pendingUnitCount:(int64_t)portionOfParentTotalUnitCount;
- (instancetype)initWithParent:(nullable NSProgress *)parentProgressOrNil userInfo:(nullable NSDictionary<NSProgressUserInfoKey, id> *)userInfoOrNil NS_DESIGNATED_INITIALIZER;
- (void)becomeCurrentWithPendingUnitCount:(int64_t)unitCount;
- (void)resignCurrent;
- (void)addChild:(NSProgress *)child withPendingUnitCount:(int64_t)inUnitCount;
@property int64_t totalUnitCount;
@property int64_t completedUnitCount;
@property (null_resettable, copy) NSString *localizedDescription;
@property (null_resettable, copy) NSString *localizedAdditionalDescription;
@property (getter=isCancellable) BOOL cancellable;
@property (getter=isPausable) BOOL pausable;
@property (readonly, getter=isCancelled) BOOL cancelled;
@property (readonly, getter=isPaused) BOOL paused;
@property (nullable, copy) void (^cancellationHandler)(void);
@property (nullable, copy) void (^pausingHandler)(void);
@property (nullable, copy) void (^resumingHandler)(void);
- (void)setUserInfoObject:(nullable id)objectOrNil forKey:(NSProgressUserInfoKey)key;
@property (readonly, getter=isIndeterminate) BOOL indeterminate;
@property (readonly) double fractionCompleted;
@property (readonly, getter=isFinished) BOOL finished;
- (void)cancel;
- (void)pause;
- (void)resume;
@property (readonly, copy) NSDictionary<NSProgressUserInfoKey, id> *userInfo;
@property (nullable, copy) NSProgressKind kind;
/* time remaining (seconds) and throughput (bytes per second), shown in the localized descriptions; userInfo entries */
@property (nullable, copy) NSNumber *estimatedTimeRemaining NS_REFINED_FOR_SWIFT;
@property (nullable, copy) NSNumber *throughput NS_REFINED_FOR_SWIFT;
/* file progress (kind NSProgressKindFile): userInfo entries */
@property (nullable, copy) NSProgressFileOperationKind fileOperationKind;
@property (nullable, copy) NSURL *fileURL;
@property (nullable, copy) NSNumber *fileTotalCount NS_REFINED_FOR_SWIFT;
@property (nullable, copy) NSNumber *fileCompletedCount NS_REFINED_FOR_SWIFT;
/* becomes current with the pending units for the block, then resigns */
- (void)performAsCurrentWithPendingUnitCount:(int64_t)unitCount usingBlock:(void (NS_NOESCAPE ^)(void))work NS_REFINED_FOR_SWIFT;
@end
NS_ASSUME_NONNULL_END
