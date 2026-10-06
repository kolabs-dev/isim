#pragma once
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

typedef NSString *NSProgressKind NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *NSProgressUserInfoKey NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT NSProgressKind const NSProgressKindFile;
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressEstimatedTimeRemainingKey, NSProgressThroughputKey;
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
@end
NS_ASSUME_NONNULL_END
