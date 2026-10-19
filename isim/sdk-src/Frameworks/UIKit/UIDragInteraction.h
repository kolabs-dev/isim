#pragma once
/* isim: drag interactions for Objective-C. The classes are the UIKit Swift overlay's (objc_runtime_visible: Objective-C finds
   them through the runtime, so it cannot subclass them or add categories to them; UIKit loads the overlay on first use);
   Swift code uses the overlay's own declarations, so this header is hidden from Swift. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIInteraction.h>
#import <UIKit/UIViewPropertyAnimator.h>
#import <UIKit/UIDragSession.h>
#import <UIKit/UIDragItem.h>
#import <UIKit/UITargetedDragPreview.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class UIDragItem, UITargetedDragPreview, UIDragInteraction;
@protocol UIDragSession, UIDragInteractionDelegate;
typedef NS_ENUM(NSUInteger, UIDropOperation) {
    UIDropOperationCancel = 0, UIDropOperationForbidden = 1, UIDropOperationCopy = 2, UIDropOperationMove = 3,
} API_AVAILABLE(ios(11.0));
NS_SWIFT_UI_ACTOR
@protocol UIDragAnimating <NSObject>
- (void)addAnimations:(void (^)(void))animations;
- (void)addCompletion:(void (^)(UIViewAnimatingPosition finalPosition))completion;
@end
ISIM_RUNTIME_VISIBLE NS_SWIFT_UI_ACTOR
@interface UIDragInteraction : NSObject <UIInteraction>
- (instancetype)initWithDelegate:(id<UIDragInteractionDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nullable, nonatomic, readonly, weak) id<UIDragInteractionDelegate> delegate;
@property (nonatomic) BOOL allowsSimultaneousRecognitionDuringLift;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (class, nonatomic, readonly, getter=isEnabledByDefault) BOOL enabledByDefault;
@end
NS_SWIFT_UI_ACTOR
@protocol UIDragInteractionDelegate <NSObject>
@required
- (NSArray<UIDragItem *> *)dragInteraction:(UIDragInteraction *)interaction itemsForBeginningSession:(id<UIDragSession>)session;
@optional
- (nullable UITargetedDragPreview *)dragInteraction:(UIDragInteraction *)interaction previewForLiftingItem:(UIDragItem *)item session:(id<UIDragSession>)session;
- (void)dragInteraction:(UIDragInteraction *)interaction willAnimateLiftWithAnimator:(id<UIDragAnimating>)animator session:(id<UIDragSession>)session;
- (void)dragInteraction:(UIDragInteraction *)interaction sessionWillBegin:(id<UIDragSession>)session;
- (BOOL)dragInteraction:(UIDragInteraction *)interaction sessionAllowsMoveOperation:(id<UIDragSession>)session;
- (void)dragInteraction:(UIDragInteraction *)interaction sessionDidMove:(id<UIDragSession>)session;
- (void)dragInteraction:(UIDragInteraction *)interaction session:(id<UIDragSession>)session willEndWithOperation:(UIDropOperation)operation;
- (void)dragInteraction:(UIDragInteraction *)interaction session:(id<UIDragSession>)session didEndWithOperation:(UIDropOperation)operation;
@end
NS_ASSUME_NONNULL_END
#endif
