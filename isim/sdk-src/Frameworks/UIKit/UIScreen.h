#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_UI_ACTOR
@interface UIScreen : NSObject <UITraitEnvironment>
@property (class, nonatomic, readonly) UIScreen *mainScreen;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) CGRect nativeBounds;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGFloat nativeScale;
@property (nonatomic) CGFloat brightness;
@property (nonatomic, readonly) NSInteger maximumFramesPerSecond;
@property (readonly) id<UICoordinateSpace> coordinateSpace;
@end
NS_ASSUME_NONNULL_END
