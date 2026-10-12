#pragma once
/* isim: the focus system (iPad keyboard navigation, iOS 15): focus environments and items, the focus system, update
   contexts, focus guides, the halo effect, animation coordinators, movement hints and the focus debugger. UIFocus.m.
   Adapted: on iPad, with a hardware keyboard, Tab / Shift-Tab move between focus groups and the arrows within one;
   Return or Space presses the focused item (a cell is selected, a control sends its primary action). iPhone has no
   focus system (focusSystem(for:) is nil), as on iOS. */
#import <UIKit/UIView.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIScrollView.h>
#import <UIKit/UILayoutGuide.h>
#import <UIKit/UITableView.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UIViewExtras.h>
#import <UIKit/CALayer.h>
NS_ASSUME_NONNULL_BEGIN
@class UIFocusUpdateContext, UIFocusAnimationCoordinator, UIFocusMovementHint, UIFocusEffect, UIBezierPath;
@protocol UIFocusItemContainer, UICoordinateSpace;

typedef NS_OPTIONS(NSUInteger, UIFocusHeading) {
    UIFocusHeadingNone = 0, UIFocusHeadingUp = 1 << 0, UIFocusHeadingDown = 1 << 1, UIFocusHeadingLeft = 1 << 2, UIFocusHeadingRight = 1 << 3,
    UIFocusHeadingNext = 1 << 4, UIFocusHeadingPrevious = 1 << 5,
    UIFocusHeadingFirst API_AVAILABLE(ios(15.0)) = 1 << 8, UIFocusHeadingLast API_AVAILABLE(ios(15.0)) = 1 << 9,
} API_AVAILABLE(ios(9.0));
/* tvOS focus sounds (iOS plays none) */
typedef NSString *UIFocusSoundIdentifier NS_TYPED_EXTENSIBLE_ENUM;
/* whether focus waits for keyboard input before it shows (iOS 18) */
typedef NS_ENUM(NSInteger, UIFocusItemDeferralMode) {
    UIFocusItemDeferralModeAutomatic = 0, UIFocusItemDeferralModeAlways, UIFocusItemDeferralModeNever,
} API_AVAILABLE(ios(18.0));

/* ---- environments and items ---- */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(9.0))
@protocol UIFocusEnvironment <NSObject>
/* where focus goes inside this environment, best first */
@property (nonatomic, copy, readonly) NSArray<id<UIFocusEnvironment>> *preferredFocusEnvironments;
@property (nonatomic, weak, readonly, nullable) id<UIFocusEnvironment> parentFocusEnvironment NS_SWIFT_NAME(parentFocusEnvironment) API_AVAILABLE(ios(12.0));
@property (nonatomic, readonly, nullable) id<UIFocusItemContainer> focusItemContainer API_AVAILABLE(ios(12.0));
- (void)setNeedsFocusUpdate;
- (void)updateFocusIfNeeded;
- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context;
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator;
@optional
/* items with the same identifier form a focus group: Tab moves between groups, the arrows inside one */
@property (nonatomic, readonly, copy, nullable) NSString *focusGroupIdentifier API_AVAILABLE(ios(14.0));
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(10.0))
@protocol UIFocusItem <UIFocusEnvironment>
@property (nonatomic, readonly) BOOL canBecomeFocused;
@property (nonatomic, readonly) CGRect frame API_AVAILABLE(ios(12.0));
@optional
@property (nonatomic, readonly, copy, nullable) UIFocusEffect *focusEffect API_AVAILABLE(ios(15.0));
@property (nonatomic, readonly) UIFocusGroupPriority focusGroupPriority API_AVAILABLE(ios(15.0));
/* a transparent item passes focus movement on to the items under it */
@property (nonatomic, readonly, getter=isTransparentFocusItem) BOOL transparentFocusItem API_AVAILABLE(ios(15.0));
@property (nonatomic, readonly) UIFocusItemDeferralMode focusItemDeferralMode API_AVAILABLE(ios(18.0));
/* tvOS remote touches (never sent on iPad) */
- (void)didHintFocusMovement:(UIFocusMovementHint *)hint API_AVAILABLE(ios(12.0));
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(12.0))
@protocol UIFocusItemContainer <NSObject>
@property (nonatomic, readonly, strong) id<UICoordinateSpace> coordinateSpace;
- (NSArray<id<UIFocusItem>> *)focusItemsInRect:(CGRect)rect NS_SWIFT_NAME(focusItems(in:));
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(12.0))
@protocol UIFocusItemScrollableContainer <UIFocusItemContainer>
@property (nonatomic, readwrite) CGPoint contentOffset;
@property (nonatomic, readonly) CGSize contentSize;
@property (nonatomic, readonly) CGSize visibleSize;
@end

/* ---- effects ---- */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(15.0))
@interface UIFocusEffect : NSObject <NSCopying>
+ (instancetype)effect;
@end
typedef NS_ENUM(NSInteger, UIFocusHaloEffectPosition) {
    UIFocusHaloEffectPositionAutomatic = 0, UIFocusHaloEffectPositionOutside, UIFocusHaloEffectPositionInside,
} NS_SWIFT_NAME(UIFocusHaloEffect.Position) API_AVAILABLE(ios(15.0));
/* the focus ring: a 4 pt ring in the tint colour around the shape */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(15.0))
@interface UIFocusHaloEffect : UIFocusEffect
+ (instancetype)effectWithRect:(CGRect)rect NS_SWIFT_NAME(init(rect:));
+ (instancetype)effectWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius curve:(CALayerCornerCurve)curve NS_SWIFT_NAME(init(roundedRect:cornerRadius:curve:));
+ (instancetype)effectWithPath:(UIBezierPath *)bezierPath NS_SWIFT_NAME(init(path:));
/* the view the halo is drawn in (nil: the item's superview) and the view its shape is in (nil: the item) */
@property (nonatomic, weak, nullable) UIView *containerView;
@property (nonatomic, weak, nullable) UIView *referenceView;
@property (nonatomic) UIFocusHaloEffectPosition position;
@end

/* ---- views, view controllers, scroll views ---- */
@interface UIView (UIFocus) <UIFocusItem, UIFocusItemContainer>
@property (nonatomic, readonly, getter=isFocused) BOOL focused;
@property (nonatomic, readonly, copy) NSArray<id<UIFocusEnvironment>> *preferredFocusEnvironments;
@property (nonatomic, weak, readonly, nullable) id<UIFocusEnvironment> parentFocusEnvironment;
@property (nonatomic, readonly, nullable) id<UIFocusItemContainer> focusItemContainer;
@property (nonatomic, readonly, strong) id<UICoordinateSpace> coordinateSpace;
@property (nonatomic, copy, nullable) NSString *focusGroupIdentifier API_AVAILABLE(ios(15.0));
@property (nonatomic, copy, nullable) UIFocusEffect *focusEffect API_AVAILABLE(ios(15.0));
- (void)setNeedsFocusUpdate;
- (void)updateFocusIfNeeded;
- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context;
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator;
- (NSArray<id<UIFocusItem>> *)focusItemsInRect:(CGRect)rect;
@end
@interface UIViewController (UIFocus) <UIFocusEnvironment>
@property (nonatomic, readonly, copy) NSArray<id<UIFocusEnvironment>> *preferredFocusEnvironments;
@property (nonatomic, weak, readonly, nullable) id<UIFocusEnvironment> parentFocusEnvironment;
@property (nonatomic, readonly, nullable) id<UIFocusItemContainer> focusItemContainer;
- (void)setNeedsFocusUpdate;
- (void)updateFocusIfNeeded;
- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context;
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator;
@end
@interface UIScrollView (UIFocus) <UIFocusItemScrollableContainer>
@property (nonatomic, readonly) CGSize visibleSize;
@end
@interface UITableView (UIFocus)
/* focusing a row selects it */
@property (nonatomic) BOOL selectionFollowsFocus API_AVAILABLE(ios(14.0));
@end

/* ---- the focus system ---- */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(12.0))
@interface UIFocusSystem : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, weak, readonly, nullable) id<UIFocusItem> focusedItem API_AVAILABLE(ios(12.0));
/* the window's focus system (iPad); nil on iPhone, which has no keyboard focus */
+ (nullable UIFocusSystem *)focusSystemForEnvironment:(id<UIFocusEnvironment>)environment NS_SWIFT_NAME(focusSystem(for:)) API_AVAILABLE(ios(12.0));
/* the next update moves focus into this environment (its preferred focus environments) */
- (void)requestFocusUpdateToEnvironment:(id<UIFocusEnvironment>)environment NS_SWIFT_NAME(requestFocusUpdate(to:));
- (void)updateFocusIfNeeded;
+ (BOOL)environment:(id<UIFocusEnvironment>)environment containsEnvironment:(id<UIFocusEnvironment>)otherEnvironment;
@end
UIKIT_EXTERN NSNotificationName const UIFocusDidUpdateNotification NS_SWIFT_NAME(UIFocusSystem.didUpdateNotification) API_AVAILABLE(ios(11.0));
UIKIT_EXTERN NSNotificationName const UIFocusMovementDidFailNotification NS_SWIFT_NAME(UIFocusSystem.movementDidFailNotification) API_AVAILABLE(ios(11.0));
UIKIT_EXTERN NSString *const UIFocusUpdateContextKey NS_SWIFT_NAME(UIFocusSystem.focusUpdateContextUserInfoKey) API_AVAILABLE(ios(11.0));
UIKIT_EXTERN NSString *const UIFocusUpdateAnimationCoordinatorKey NS_SWIFT_NAME(UIFocusSystem.animationCoordinatorUserInfoKey) API_AVAILABLE(ios(11.0));

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(9.0))
@interface UIFocusUpdateContext : NSObject
@property (nonatomic, weak, readonly, nullable) id<UIFocusItem> previouslyFocusedItem API_AVAILABLE(ios(10.0));
@property (nonatomic, weak, readonly, nullable) id<UIFocusItem> nextFocusedItem API_AVAILABLE(ios(10.0));
@property (nonatomic, weak, readonly, nullable) UIView *previouslyFocusedView;
@property (nonatomic, weak, readonly, nullable) UIView *nextFocusedView;
@property (nonatomic, readonly) UIFocusHeading focusHeading;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(9.0))
@interface UITableViewFocusUpdateContext : UIFocusUpdateContext
@property (nonatomic, strong, readonly, nullable) NSIndexPath *previouslyFocusedIndexPath;
@property (nonatomic, strong, readonly, nullable) NSIndexPath *nextFocusedIndexPath;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(9.0))
@interface UICollectionViewFocusUpdateContext : UIFocusUpdateContext
@property (nonatomic, strong, readonly, nullable) NSIndexPath *previouslyFocusedIndexPath;
@property (nonatomic, strong, readonly, nullable) NSIndexPath *nextFocusedIndexPath;
@end

/* ---- animations ---- */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(11.0))
@protocol UIFocusAnimationContext <NSObject>
@property (nonatomic, readonly) NSTimeInterval duration;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(9.0))
@interface UIFocusAnimationCoordinator : NSObject
/* run with the focus change (in one animation) */
- (void)addCoordinatedAnimations:(nullable void (^)(void))animations completion:(nullable void (^)(void))completion;
/* for the item gaining focus / the item losing it */
- (void)addCoordinatedFocusingAnimations:(nullable void (^)(id<UIFocusAnimationContext> animationContext))animations completion:(nullable void (^)(void))completion API_AVAILABLE(ios(11.0));
- (void)addCoordinatedUnfocusingAnimations:(nullable void (^)(id<UIFocusAnimationContext> animationContext))animations completion:(nullable void (^)(void))completion API_AVAILABLE(ios(11.0));
@end

/* ---- guides: an empty area that sends focus on to its preferred environments ---- */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(9.0))
@interface UIFocusGuide : UILayoutGuide
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, copy, null_resettable) NSArray<id<UIFocusEnvironment>> *preferredFocusEnvironments API_AVAILABLE(ios(10.0));
@end

/* ---- movement hints (tvOS remote touches: never sent on iPad) ---- */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(12.0))
@interface UIFocusMovementHint : NSObject <NSCopying>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly) CGVector movementDirection;
@property (nonatomic, readonly) CATransform3D perspectiveTransform;
@property (nonatomic, readonly) CGVector rotation;
@property (nonatomic, readonly) CGVector translation;
@property (nonatomic, readonly) CATransform3D interactionTransform;
@end

/* ---- the debugger (text reports, as in the debugger's po) ---- */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(11.0))
@protocol UIFocusDebuggerOutput <NSObject>
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(11.0))
@interface UIFocusDebugger : NSObject
+ (id<UIFocusDebuggerOutput>)help;
+ (id<UIFocusDebuggerOutput>)status;
+ (id<UIFocusDebuggerOutput>)checkFocusabilityForItem:(id<UIFocusItem>)item NS_SWIFT_NAME(checkFocusability(for:));
+ (id<UIFocusDebuggerOutput>)simulateFocusUpdateRequestFromEnvironment:(id<UIFocusEnvironment>)environment NS_SWIFT_NAME(simulateFocusUpdateRequest(from:));
+ (id<UIFocusDebuggerOutput>)focusGroupsForEnvironment:(nullable id<UIFocusEnvironment>)environment NS_SWIFT_NAME(focusGroups(for:)) API_AVAILABLE(ios(15.0));
+ (id<UIFocusDebuggerOutput>)preferredFocusEnvironmentsForEnvironment:(id<UIFocusEnvironment>)environment NS_SWIFT_NAME(preferredFocusEnvironments(for:)) API_AVAILABLE(ios(15.0));
@end
NS_ASSUME_NONNULL_END
