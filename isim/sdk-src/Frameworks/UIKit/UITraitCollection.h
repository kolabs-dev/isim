#pragma once
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIUserInterfaceStyle) { UIUserInterfaceStyleUnspecified, UIUserInterfaceStyleLight, UIUserInterfaceStyleDark };
typedef NS_ENUM(NSInteger, UIUserInterfaceIdiom) { UIUserInterfaceIdiomUnspecified = -1, UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPad };
typedef NS_ENUM(NSInteger, UIUserInterfaceSizeClass) { UIUserInterfaceSizeClassUnspecified, UIUserInterfaceSizeClassCompact, UIUserInterfaceSizeClassRegular };
@interface UITraitCollection : NSObject <NSCopying>
@property (class, nonatomic, readonly) UITraitCollection *currentTraitCollection;
@property (nonatomic, readonly) UIUserInterfaceStyle userInterfaceStyle;
@property (nonatomic, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, readonly) UIUserInterfaceSizeClass horizontalSizeClass, verticalSizeClass;
@property (nonatomic, readonly) CGFloat displayScale;
+ (UITraitCollection *)traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)style;
@end
NS_SWIFT_UI_ACTOR
@protocol UITraitEnvironment <NSObject>
@property (nonatomic, readonly) UITraitCollection *traitCollection;
- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection;
@end
NS_ASSUME_NONNULL_END
