#pragma once
#import <XCTest/XCTestDefines.h>
#import <UIKit/UIDevice.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, XCUIDeviceButton) {
    XCUIDeviceButtonHome = 1,
    XCUIDeviceButtonVolumeUp = 2,
    XCUIDeviceButtonVolumeDown = 3,
} NS_SWIFT_NAME(XCUIDevice.Button);

/* The simulated device. isim: orientation turns the device of the app most recently launched by the test. */
@interface XCUIDevice : NSObject
@property (class, readonly) XCUIDevice *sharedDevice NS_SWIFT_NAME(shared);
@property (nonatomic) UIDeviceOrientation orientation;
- (void)pressButton:(XCUIDeviceButton)button NS_SWIFT_NAME(press(_:));
@end

NS_ASSUME_NONNULL_END
