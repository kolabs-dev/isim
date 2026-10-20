#pragma once
#import <XCTest/XCTestDefines.h>
#import <UIKit/UIDevice.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, XCUIDeviceButton) {
    XCUIDeviceButtonHome = 1,
    XCUIDeviceButtonVolumeUp = 2,
    XCUIDeviceButtonVolumeDown = 3,
    XCUIDeviceButtonAction API_AVAILABLE(ios(16.0)) = 4,
    XCUIDeviceButtonCamera API_AVAILABLE(ios(18.0)) = 5,
} NS_SWIFT_NAME(XCUIDevice.Button);

typedef NS_ENUM(NSInteger, XCUIDeviceAppearance) {
    XCUIDeviceAppearanceUnspecified = 0,
    XCUIDeviceAppearanceLight = 1,
    XCUIDeviceAppearanceDark = 2,
} NS_SWIFT_NAME(XCUIDevice.Appearance);

/* The simulated device. isim: orientation turns the device of the app most recently launched by the test and reads
 * back the orientation that app reports (UIDevice.orientation); pressButton(.home) sends it to the background.
 * volumeUp / volumeDown exist only on devices (Apple's Simulator has no volume buttons): isim ignores them, like the
 * Camera Control; .action presses the Action button (script command actionbutton). */
@interface XCUIDevice : NSObject
@property (class, readonly) XCUIDevice *sharedDevice NS_SWIFT_NAME(shared);
@property (nonatomic) UIDeviceOrientation orientation;
- (void)pressButton:(XCUIDeviceButton)button NS_SWIFT_NAME(press(_:));
/* the device's light or dark appearance (isim: the `appearance` script command, like Settings › Display) */
@property (nonatomic) XCUIDeviceAppearance appearance;
@end

NS_ASSUME_NONNULL_END
