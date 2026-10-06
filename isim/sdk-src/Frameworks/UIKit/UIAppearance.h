#pragma once
/* isim: UIAppearance proxies. A proxy is a real (offscreen) instance of the class: setting properties on it
   records them, and views get the recorded values when they first enter a window, unless they set the
   property themselves. Works for the common appearance properties of UIKit views (colors, bar appearances,
   title attributes, fonts, translucency, large titles); see UIAppearance.m for the list. */
#import <UIKit/UIView.h>
#import <UIKit/UIViewController.h>
NS_ASSUME_NONNULL_BEGIN
@class UITraitCollection;

NS_SWIFT_UI_ACTOR
@protocol UIAppearanceContainer <NSObject>
@end

NS_SWIFT_UI_ACTOR
@protocol UIAppearance <NSObject>
+ (instancetype)appearance;
+ (instancetype)appearanceWhenContainedInInstancesOfClasses:(NSArray<Class<UIAppearanceContainer>> *)containerTypes
    NS_SWIFT_NAME(appearance(whenContainedInInstancesOf:));
+ (instancetype)appearanceForTraitCollection:(UITraitCollection *)trait NS_SWIFT_NAME(appearance(for:));
+ (instancetype)appearanceForTraitCollection:(UITraitCollection *)trait whenContainedInInstancesOfClasses:(NSArray<Class<UIAppearanceContainer>> *)containerTypes
    NS_SWIFT_NAME(appearance(for:whenContainedInInstancesOf:));
@end

@interface UIView (UIAppearance) <UIAppearance, UIAppearanceContainer>
@end
@interface UIViewController (UIAppearanceContainer) <UIAppearanceContainer>
@end
NS_ASSUME_NONNULL_END
