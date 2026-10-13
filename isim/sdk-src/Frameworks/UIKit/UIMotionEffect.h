#pragma once
/* isim: motion effects (parallax). A view's motion effects get the viewer's offset (the device tilt: -1..1 on each
   axis, 0 at rest) and give values that are added to the view's presentation (its model values don't change).
   Adapted: isim's device rests flat unless the script command `tilt H V` tilts it; Reduce Motion turns the effects
   off, like iOS. The views apply center, center.x, center.y, layer.shadowOffset (and .width / .height) and alpha. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(7.0))
@interface UIMotionEffect : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
/* subclasses: key paths and the values to add for this viewer offset */
- (nullable NSDictionary<NSString *, id> *)keyPathsAndRelativeValuesForViewerOffset:(UIOffset)viewerOffset;
@end
typedef NS_ENUM(NSInteger, UIInterpolatingMotionEffectType) {
    UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis, UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis
} NS_SWIFT_NAME(UIInterpolatingMotionEffect.EffectType);
/* from minimumRelativeValue (tilted fully one way) to maximumRelativeValue (the other); NSNumber or NSValue
   (CGPoint, CGSize, UIOffset) values */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(7.0))
@interface UIInterpolatingMotionEffect : UIMotionEffect
- (instancetype)initWithKeyPath:(NSString *)keyPath type:(UIInterpolatingMotionEffectType)type NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (readonly, nonatomic) NSString *keyPath;
@property (readonly, nonatomic) UIInterpolatingMotionEffectType type;
@property (nullable, strong, nonatomic) id minimumRelativeValue;
@property (nullable, strong, nonatomic) id maximumRelativeValue;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(7.0))
@interface UIMotionEffectGroup : UIMotionEffect
@property (nullable, copy, nonatomic) NSArray<__kindof UIMotionEffect *> *motionEffects;
@end
@interface UIView (UIMotionEffects)
- (void)addMotionEffect:(UIMotionEffect *)effect;
- (void)removeMotionEffect:(UIMotionEffect *)effect;
@property (copy, nonatomic) NSArray<__kindof UIMotionEffect *> *motionEffects;
@end
NS_ASSUME_NONNULL_END
