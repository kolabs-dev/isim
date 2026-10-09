#pragma once
/* isim: two-finger gestures, pointer hover and pencil.
 * The second finger comes from the host like the Simulator's: Option-drag pinches/rotates around the screen centre,
 * Option+Shift-drag moves two fingers together; scripts use `pinch`, `rotate2`, `twofinger`.
 * Hover: host mouse motion without a button (script `hover X Y`). Pointer effects are drawn on iPad only (iPhone has
 * no pointer). Apple Pencil is simulated (adapted): script `pencil tap` / `pencil squeeze` reach UIPencilInteraction,
 * `pencil X1 Y1 X2 Y2 SECS [FORCE] [ALTITUDE]` draws a stroke of Pencil touches (UITouchTypePencil with force and
 * angles) and `pencil hover X Y [Z]` hovers it (UIHoverGestureRecognizer.zOffset). */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIGestureRecognizer.h>
#import <UIKit/UIInteraction.h>
#import <UIKit/UIKeyCommand.h>
#import <UIKit/UITargetedPreview.h>
#import <UIKit/UIButton.h>
NS_ASSUME_NONNULL_BEGIN
@class UIBezierPath, UIColor;

NS_SWIFT_UI_ACTOR
@interface UIPinchGestureRecognizer : UIGestureRecognizer
@property (nonatomic) CGFloat scale;
@property (nonatomic, readonly) CGFloat velocity;
@end
NS_SWIFT_UI_ACTOR
@interface UIRotationGestureRecognizer : UIGestureRecognizer
@property (nonatomic) CGFloat rotation;          /* radians, clockwise > 0 */
@property (nonatomic, readonly) CGFloat velocity;
@end
NS_SWIFT_UI_ACTOR
@interface UIHoverGestureRecognizer : UIGestureRecognizer
@property (nonatomic, readonly) CGFloat zOffset;
@property (nonatomic, readonly) CGFloat altitudeAngle;
- (CGFloat)azimuthAngleInView:(nullable UIView *)view;
@end

/* ---- pointer ---- */
@class UIPointerInteraction, UIPointerRegion, UIPointerStyle, UIPointerRegionRequest, UITargetedPreview;
NS_SWIFT_UI_ACTOR
@protocol UIPointerInteractionAnimating <NSObject>
- (void)addAnimations:(void (^)(void))animations;
- (void)addCompletion:(void (^)(BOOL finished))completion;
@end
NS_SWIFT_UI_ACTOR
@protocol UIPointerInteractionDelegate <NSObject>
@optional
- (nullable UIPointerRegion *)pointerInteraction:(UIPointerInteraction *)interaction regionForRequest:(UIPointerRegionRequest *)request defaultRegion:(UIPointerRegion *)defaultRegion;
- (nullable UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region;
- (void)pointerInteraction:(UIPointerInteraction *)interaction willEnterRegion:(UIPointerRegion *)region animator:(id<UIPointerInteractionAnimating>)animator;
- (void)pointerInteraction:(UIPointerInteraction *)interaction willExitRegion:(UIPointerRegion *)region animator:(id<UIPointerInteractionAnimating>)animator;
@end
NS_SWIFT_UI_ACTOR
@interface UIPointerInteraction : NSObject <UIInteraction>
- (instancetype)initWithDelegate:(nullable id<UIPointerInteractionDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, weak, readonly, nullable) id<UIPointerInteractionDelegate> delegate;
@property (nonatomic, getter=isEnabled) BOOL enabled;
- (void)invalidate;
@end
NS_SWIFT_UI_ACTOR
@interface UIPointerRegionRequest : NSObject
@property (nonatomic, readonly) CGPoint location;
@property (nonatomic, readonly) UIKeyModifierFlags modifiers;
@end
NS_SWIFT_UI_ACTOR
@interface UIPointerRegion : NSObject <NSCopying>
+ (instancetype)regionWithRect:(CGRect)rect identifier:(nullable id<NSObject>)identifier;
@property (nonatomic, readonly) CGRect rect;
@property (nonatomic, readonly, nullable) id<NSObject> identifier;
@property (nonatomic) UIAxis latchingAxes;
@end
NS_SWIFT_UI_ACTOR
@interface UIPointerEffect : NSObject <NSCopying>
@property (nonatomic, readonly, copy) UITargetedPreview *preview;
+ (instancetype)effectWithPreview:(UITargetedPreview *)preview;
@end
@interface UIPointerHighlightEffect : UIPointerEffect @end
@interface UIPointerLiftEffect : UIPointerEffect @end
typedef NS_ENUM(NSInteger, UIPointerEffectTintMode) { UIPointerEffectTintModeNone, UIPointerEffectTintModeOverlay, UIPointerEffectTintModeUnderlay };
@interface UIPointerHoverEffect : UIPointerEffect
@property (nonatomic) UIPointerEffectTintMode preferredTintMode;
@property (nonatomic) BOOL prefersShadow;
@property (nonatomic) BOOL prefersScaledContent;
@end
NS_SWIFT_UI_ACTOR
@interface UIPointerShape : NSObject <NSCopying>
+ (instancetype)shapeWithPath:(UIBezierPath *)path;
+ (instancetype)shapeWithRoundedRect:(CGRect)rect;
+ (instancetype)shapeWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius;
+ (instancetype)beamWithPreferredLength:(CGFloat)length axis:(UIAxis)axis;
@end
NS_SWIFT_UI_ACTOR
/* small shapes around the pointer (iOS 15): arrows hinting at the directions it can move */
typedef struct UIPointerAccessoryPosition { CGFloat offset; CGFloat angle; } UIPointerAccessoryPosition;
UIKIT_EXTERN const UIPointerAccessoryPosition UIPointerAccessoryPositionTop, UIPointerAccessoryPositionTopRight, UIPointerAccessoryPositionRight,
    UIPointerAccessoryPositionBottomRight, UIPointerAccessoryPositionBottom, UIPointerAccessoryPositionBottomLeft, UIPointerAccessoryPositionLeft,
    UIPointerAccessoryPositionTopLeft;
NS_SWIFT_UI_ACTOR
@interface UIPointerAccessory : NSObject <NSCopying>
@property (nonatomic, readonly, copy) UIPointerShape *shape;
@property (nonatomic, readonly) UIPointerAccessoryPosition position;
@property (nonatomic, getter=isOrientationMatchingAngle) BOOL orientationMatchesAngle;
+ (instancetype)accessoryWithShape:(UIPointerShape *)shape position:(UIPointerAccessoryPosition)position;
+ (instancetype)arrowAccessoryWithPosition:(UIPointerAccessoryPosition)position;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_SWIFT_UI_ACTOR
@interface UIPointerStyle : NSObject <NSCopying>
+ (instancetype)styleWithEffect:(UIPointerEffect *)effect shape:(nullable UIPointerShape *)shape;
+ (instancetype)styleWithShape:(UIPointerShape *)shape constrainedAxes:(UIAxis)axes;
+ (instancetype)hiddenPointerStyle;
+ (instancetype)systemPointerStyle;
@property (nonatomic, copy) NSArray<UIPointerAccessory *> *accessories;
@end
@interface UIButton (UIPointer)
@property (nonatomic, getter=isPointerInteractionEnabled) BOOL pointerInteractionEnabled;
@end

/* ---- pencil (simulated: see the top of this header) ---- */
typedef NS_ENUM(NSInteger, UIPencilPreferredAction) { UIPencilPreferredActionIgnore = 0, UIPencilPreferredActionSwitchEraser, UIPencilPreferredActionSwitchPrevious, UIPencilPreferredActionShowColorPalette, UIPencilPreferredActionShowInkAttributes, UIPencilPreferredActionShowContextualPalette, UIPencilPreferredActionRunSystemShortcut };
@class UIPencilInteraction;
typedef NS_ENUM(NSInteger, UIPencilInteractionPhase) {
    UIPencilInteractionPhaseBegan, UIPencilInteractionPhaseChanged, UIPencilInteractionPhaseEnded, UIPencilInteractionPhaseCancelled
} NS_SWIFT_NAME(UIPencilInteraction.Phase);
/* where the Pencil hovers above the screen when it is tapped or squeezed (nil when not hovering) */
NS_SWIFT_UI_ACTOR
@interface UIPencilHoverPose : NSObject
@property (nonatomic, readonly) CGPoint location;
@property (nonatomic, readonly) CGFloat zOffset;
@property (nonatomic, readonly) CGFloat azimuthAngle;
@property (nonatomic, readonly) CGVector azimuthUnitVector;
@property (nonatomic, readonly) CGFloat altitudeAngle;
@property (nonatomic, readonly) CGFloat rollAngle;
@end
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(UIPencilInteraction.Tap)
@interface UIPencilInteractionTap : NSObject
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, nullable, readonly, strong) UIPencilHoverPose *hoverPose;
@end
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(UIPencilInteraction.Squeeze)
@interface UIPencilInteractionSqueeze : NSObject
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) UIPencilInteractionPhase phase;
@property (nonatomic, nullable, readonly, strong) UIPencilHoverPose *hoverPose;
@end
NS_SWIFT_UI_ACTOR
@protocol UIPencilInteractionDelegate <NSObject>
@optional
- (void)pencilInteractionDidTap:(UIPencilInteraction *)interaction;
- (void)pencilInteraction:(UIPencilInteraction *)interaction didReceiveTap:(UIPencilInteractionTap *)tap;
- (void)pencilInteraction:(UIPencilInteraction *)interaction didReceiveSqueeze:(UIPencilInteractionSqueeze *)squeeze;
@end
NS_SWIFT_UI_ACTOR
@interface UIPencilInteraction : NSObject <UIInteraction>
@property (class, nonatomic, readonly) UIPencilPreferredAction preferredTapAction;
@property (class, nonatomic, readonly) UIPencilPreferredAction preferredSqueezeAction;
@property (class, nonatomic, readonly) BOOL prefersPencilOnlyDrawing;
@property (class, nonatomic, readonly) BOOL prefersHoverToolPreview;
@property (nonatomic, weak, nullable) id<UIPencilInteractionDelegate> delegate;
@property (nonatomic, getter=isEnabled) BOOL enabled;
- (instancetype)initWithDelegate:(id<UIPencilInteractionDelegate>)delegate;
@end
NS_ASSUME_NONNULL_END
