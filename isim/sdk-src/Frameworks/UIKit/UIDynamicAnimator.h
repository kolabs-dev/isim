#pragma once
/* isim: UIKit Dynamics (self-authored). A 2D physics step runs each frame (fixed 1/240 s substeps) on the items'
 * centers: gravity (magnitude 1 = 1000 pt/s^2), pushes (1 UIKit newton accelerates a 100x100 pt, density-1
 * item at 100 pt/s^2), snaps (damped springs), attachments (springs or rigid lengths), item properties
 * (elasticity, friction, density, resistance, anchored, velocities) and collisions of the items' axis-aligned
 * frames with boundaries (reference bounds, segments, path outlines) and with each other. Collisions do not
 * spin items (no rotational response). The animator pauses once every item rests. */
#import <UIKit/UIView.h>
#import <UIKit/UIBezierPath.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, UIDynamicItemCollisionBoundsType) {
    UIDynamicItemCollisionBoundsTypeRectangle, UIDynamicItemCollisionBoundsTypeEllipse, UIDynamicItemCollisionBoundsTypePath,
};
@protocol UIDynamicItem <NSObject>
@property (nonatomic, readwrite) CGPoint center;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readwrite) CGAffineTransform transform;
@optional
@property (nonatomic, readonly) UIDynamicItemCollisionBoundsType collisionBoundsType;
@property (nonatomic, readonly) UIBezierPath *collisionBoundingPath;
@end
@interface UIView (IsimDynamicItem) <UIDynamicItem>
@end

NS_SWIFT_UI_ACTOR
@interface UIDynamicItemGroup : NSObject <UIDynamicItem>
- (instancetype)initWithItems:(NSArray<id<UIDynamicItem>> *)items;
@property (nonatomic, readonly, copy) NSArray<id<UIDynamicItem>> *items;
@property (nonatomic, readwrite) CGPoint center;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readwrite) CGAffineTransform transform;
@end

@class UIDynamicAnimator;
NS_SWIFT_UI_ACTOR
@interface UIDynamicBehavior : NSObject
- (void)addChildBehavior:(UIDynamicBehavior *)behavior;
- (void)removeChildBehavior:(UIDynamicBehavior *)behavior;
@property (nonatomic, readonly, copy) NSArray<__kindof UIDynamicBehavior *> *childBehaviors;
@property (nullable, nonatomic, copy) void (^action)(void);
- (void)willMoveToAnimator:(nullable UIDynamicAnimator *)dynamicAnimator;
@property (nullable, nonatomic, readonly, weak) UIDynamicAnimator *dynamicAnimator;
@end

NS_SWIFT_UI_ACTOR
@interface UIGravityBehavior : UIDynamicBehavior
- (instancetype)initWithItems:(NSArray<id<UIDynamicItem>> *)items NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (void)addItem:(id<UIDynamicItem>)item;
- (void)removeItem:(id<UIDynamicItem>)item;
@property (nonatomic, readonly, copy) NSArray<id<UIDynamicItem>> *items;
@property (nonatomic, readwrite) CGVector gravityDirection;
@property (nonatomic, readwrite) CGFloat angle, magnitude;
- (void)setAngle:(CGFloat)angle magnitude:(CGFloat)magnitude;
@end

typedef NS_OPTIONS(NSUInteger, UICollisionBehaviorMode) {
    UICollisionBehaviorModeItems = 1 << 0, UICollisionBehaviorModeBoundaries = 1 << 1, UICollisionBehaviorModeEverything = NSUIntegerMax,
};
@class UICollisionBehavior;
@protocol UICollisionBehaviorDelegate <NSObject>
@optional
- (void)collisionBehavior:(UICollisionBehavior *)behavior beganContactForItem:(id<UIDynamicItem>)item1 withItem:(id<UIDynamicItem>)item2 atPoint:(CGPoint)p;
- (void)collisionBehavior:(UICollisionBehavior *)behavior endedContactForItem:(id<UIDynamicItem>)item1 withItem:(id<UIDynamicItem>)item2;
- (void)collisionBehavior:(UICollisionBehavior *)behavior beganContactForItem:(id<UIDynamicItem>)item withBoundaryIdentifier:(nullable id<NSCopying>)identifier atPoint:(CGPoint)p;
- (void)collisionBehavior:(UICollisionBehavior *)behavior endedContactForItem:(id<UIDynamicItem>)item withBoundaryIdentifier:(nullable id<NSCopying>)identifier;
@end
NS_SWIFT_UI_ACTOR
@interface UICollisionBehavior : UIDynamicBehavior
- (instancetype)initWithItems:(NSArray<id<UIDynamicItem>> *)items NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (void)addItem:(id<UIDynamicItem>)item;
- (void)removeItem:(id<UIDynamicItem>)item;
@property (nonatomic, readonly, copy) NSArray<id<UIDynamicItem>> *items;
@property (nonatomic, readwrite) UICollisionBehaviorMode collisionMode;
@property (nonatomic, readwrite) BOOL translatesReferenceBoundsIntoBoundary;
- (void)setTranslatesReferenceBoundsIntoBoundaryWithInsets:(UIEdgeInsets)insets;
- (void)addBoundaryWithIdentifier:(id<NSCopying>)identifier forPath:(UIBezierPath *)bezierPath;
- (void)addBoundaryWithIdentifier:(id<NSCopying>)identifier fromPoint:(CGPoint)p1 toPoint:(CGPoint)p2;
- (nullable UIBezierPath *)boundaryWithIdentifier:(id<NSCopying>)identifier;
- (void)removeBoundaryWithIdentifier:(id<NSCopying>)identifier;
@property (nullable, nonatomic, readonly, copy) NSArray<id<NSCopying>> *boundaryIdentifiers;
- (void)removeAllBoundaries;
@property (nullable, nonatomic, weak) id<UICollisionBehaviorDelegate> collisionDelegate;
@end

NS_SWIFT_UI_ACTOR
@interface UISnapBehavior : UIDynamicBehavior
- (instancetype)initWithItem:(id<UIDynamicItem>)item snapToPoint:(CGPoint)point;
@property (nonatomic, assign) CGPoint snapPoint;
@property (nonatomic, assign) CGFloat damping;
@end

typedef NS_ENUM(NSInteger, UIPushBehaviorMode) { UIPushBehaviorModeContinuous, UIPushBehaviorModeInstantaneous };
NS_SWIFT_UI_ACTOR
@interface UIPushBehavior : UIDynamicBehavior
- (instancetype)initWithItems:(NSArray<id<UIDynamicItem>> *)items mode:(UIPushBehaviorMode)mode;
- (void)addItem:(id<UIDynamicItem>)item;
- (void)removeItem:(id<UIDynamicItem>)item;
@property (nonatomic, readonly, copy) NSArray<id<UIDynamicItem>> *items;
- (UIOffset)targetOffsetFromCenterForItem:(id<UIDynamicItem>)item;
- (void)setTargetOffsetFromCenter:(UIOffset)o forItem:(id<UIDynamicItem>)item;
@property (nonatomic, readonly) UIPushBehaviorMode mode;
@property (nonatomic, readwrite) BOOL active;
@property (readwrite, nonatomic) CGFloat angle, magnitude;
@property (readwrite, nonatomic) CGVector pushDirection;
- (void)setAngle:(CGFloat)angle magnitude:(CGFloat)magnitude;
@end

typedef NS_ENUM(NSInteger, UIAttachmentBehaviorType) { UIAttachmentBehaviorTypeItems, UIAttachmentBehaviorTypeAnchor };
typedef struct { CGFloat minimum, maximum; } UIFloatRange;
UIKIT_EXTERN const UIFloatRange UIFloatRangeZero, UIFloatRangeInfinite;
UIKIT_EXTERN BOOL UIFloatRangeIsInfinite(UIFloatRange range);
NS_SWIFT_UI_ACTOR
@interface UIAttachmentBehavior : UIDynamicBehavior
- (instancetype)initWithItem:(id<UIDynamicItem>)item attachedToAnchor:(CGPoint)point;
- (instancetype)initWithItem:(id<UIDynamicItem>)item offsetFromCenter:(UIOffset)offset attachedToAnchor:(CGPoint)point;
- (instancetype)initWithItem:(id<UIDynamicItem>)item1 attachedToItem:(id<UIDynamicItem>)item2;
- (instancetype)initWithItem:(id<UIDynamicItem>)item1 offsetFromCenter:(UIOffset)offset1 attachedToItem:(id<UIDynamicItem>)item2 offsetFromCenter:(UIOffset)offset2;
@property (nonatomic, readonly, copy) NSArray<id<UIDynamicItem>> *items;
@property (readonly, nonatomic) UIAttachmentBehaviorType attachedBehaviorType;
@property (readwrite, nonatomic) CGPoint anchorPoint;
@property (readwrite, nonatomic) CGFloat length, damping, frequency, frictionTorque;
@property (readwrite, nonatomic) UIFloatRange attachmentRange;
@end

NS_SWIFT_UI_ACTOR
@interface UIDynamicItemBehavior : UIDynamicBehavior
- (instancetype)initWithItems:(NSArray<id<UIDynamicItem>> *)items NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (void)addItem:(id<UIDynamicItem>)item;
- (void)removeItem:(id<UIDynamicItem>)item;
@property (nonatomic, readonly, copy) NSArray<id<UIDynamicItem>> *items;
@property (readwrite, nonatomic) CGFloat elasticity, friction, density, resistance, angularResistance, charge;
@property (nonatomic, getter=isAnchored) BOOL anchored;
@property (readwrite, nonatomic) BOOL allowsRotation;
- (void)addLinearVelocity:(CGPoint)velocity forItem:(id<UIDynamicItem>)item;
- (CGPoint)linearVelocityForItem:(id<UIDynamicItem>)item;
- (void)addAngularVelocity:(CGFloat)velocity forItem:(id<UIDynamicItem>)item;
- (CGFloat)angularVelocityForItem:(id<UIDynamicItem>)item;
@end

@protocol UIDynamicAnimatorDelegate <NSObject>
@optional
- (void)dynamicAnimatorWillResume:(UIDynamicAnimator *)animator;
- (void)dynamicAnimatorDidPause:(UIDynamicAnimator *)animator;
@end
NS_SWIFT_UI_ACTOR
@interface UIDynamicAnimator : NSObject
- (instancetype)initWithReferenceView:(UIView *)view NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (void)addBehavior:(UIDynamicBehavior *)behavior;
- (void)removeBehavior:(UIDynamicBehavior *)behavior;
- (void)removeAllBehaviors;
@property (nullable, nonatomic, readonly) UIView *referenceView;
@property (nonatomic, readonly, copy) NSArray<__kindof UIDynamicBehavior *> *behaviors;
- (NSArray<id<UIDynamicItem>> *)itemsInRect:(CGRect)rect;
- (void)updateItemUsingCurrentState:(id<UIDynamicItem>)item;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly) NSTimeInterval elapsedTime;
@property (nullable, nonatomic, weak) id<UIDynamicAnimatorDelegate> delegate;
@end
NS_ASSUME_NONNULL_END
