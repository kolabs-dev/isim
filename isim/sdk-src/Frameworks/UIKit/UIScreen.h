#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_UI_ACTOR
@interface UIScreen : NSObject <UITraitEnvironment>
@property (class, nonatomic, readonly) UIScreen *mainScreen;
/* the device's screen and, while one is connected (isim: script `display connect`), the external display */
@property (class, nonatomic, readonly) NSArray<UIScreen *> *screens;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) CGRect nativeBounds;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGFloat nativeScale;
/* isim (adapted): the device setting (kept in the device data, every app follows); below 1 the apps' frames are dimmed */
@property (nonatomic) CGFloat brightness;
@property (nonatomic, readonly) NSInteger maximumFramesPerSecond;
@property (readonly) id<UICoordinateSpace> coordinateSpace;
@end
UIKIT_EXTERN NSNotificationName const UIScreenBrightnessDidChangeNotification;
/* isim: never posted (no screen recording or mirroring, the device screen has one mode) */
UIKIT_EXTERN NSNotificationName const UIScreenModeDidChangeNotification;
UIKIT_EXTERN NSNotificationName const UIScreenCapturedDidChangeNotification API_AVAILABLE(ios(11.0));
UIKIT_EXTERN NSNotificationName const UIScreenReferenceDisplayModeStatusDidChangeNotification API_AVAILABLE(ios(17.0));
UIKIT_EXTERN NSNotificationName const UIScreenDidConnectNotification, UIScreenDidDisconnectNotification;
NS_ASSUME_NONNULL_END
