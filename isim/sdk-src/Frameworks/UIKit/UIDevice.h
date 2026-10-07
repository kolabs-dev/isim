#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UITraitCollection.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIDeviceOrientation) { UIDeviceOrientationUnknown, UIDeviceOrientationPortrait, UIDeviceOrientationPortraitUpsideDown, UIDeviceOrientationLandscapeLeft, UIDeviceOrientationLandscapeRight, UIDeviceOrientationFaceUp, UIDeviceOrientationFaceDown };
typedef NS_ENUM(NSInteger, UIInterfaceOrientation) {
    UIInterfaceOrientationUnknown = UIDeviceOrientationUnknown,
    UIInterfaceOrientationPortrait = UIDeviceOrientationPortrait,
    UIInterfaceOrientationPortraitUpsideDown = UIDeviceOrientationPortraitUpsideDown,
    UIInterfaceOrientationLandscapeLeft = UIDeviceOrientationLandscapeRight,
    UIInterfaceOrientationLandscapeRight = UIDeviceOrientationLandscapeLeft };
typedef NS_OPTIONS(NSUInteger, UIInterfaceOrientationMask) {
    UIInterfaceOrientationMaskPortrait = (1 << UIInterfaceOrientationPortrait),
    UIInterfaceOrientationMaskLandscapeLeft = (1 << UIInterfaceOrientationLandscapeLeft),
    UIInterfaceOrientationMaskLandscapeRight = (1 << UIInterfaceOrientationLandscapeRight),
    UIInterfaceOrientationMaskPortraitUpsideDown = (1 << UIInterfaceOrientationPortraitUpsideDown),
    UIInterfaceOrientationMaskLandscape = (UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight),
    UIInterfaceOrientationMaskAll = (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight | UIInterfaceOrientationMaskPortraitUpsideDown),
    UIInterfaceOrientationMaskAllButUpsideDown = (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight) };
static inline BOOL UIInterfaceOrientationIsPortrait(UIInterfaceOrientation o) { return o == UIInterfaceOrientationPortrait || o == UIInterfaceOrientationPortraitUpsideDown; }
static inline BOOL UIInterfaceOrientationIsLandscape(UIInterfaceOrientation o) { return o == UIInterfaceOrientationLandscapeLeft || o == UIInterfaceOrientationLandscapeRight; }
static inline BOOL UIDeviceOrientationIsPortrait(UIDeviceOrientation o) { return o == UIDeviceOrientationPortrait || o == UIDeviceOrientationPortraitUpsideDown; }
static inline BOOL UIDeviceOrientationIsLandscape(UIDeviceOrientation o) { return o == UIDeviceOrientationLandscapeLeft || o == UIDeviceOrientationLandscapeRight; }
static inline BOOL UIDeviceOrientationIsFlat(UIDeviceOrientation o) { return o == UIDeviceOrientationFaceUp || o == UIDeviceOrientationFaceDown; }
static inline BOOL UIDeviceOrientationIsValidInterfaceOrientation(UIDeviceOrientation o) { return o >= UIDeviceOrientationPortrait && o <= UIDeviceOrientationLandscapeRight; }

typedef NS_ENUM(NSInteger, UIDeviceBatteryState) { UIDeviceBatteryStateUnknown, UIDeviceBatteryStateUnplugged, UIDeviceBatteryStateCharging, UIDeviceBatteryStateFull };
UIKIT_EXTERN NSNotificationName const UIDeviceBatteryStateDidChangeNotification, UIDeviceBatteryLevelDidChangeNotification, UIDeviceProximityStateDidChangeNotification;
/* isim: systemVersion is the iOS API level isim emulates (ISIM_OS_VERSION, default 18.0), not a real iOS. */
NS_SWIFT_UI_ACTOR
@interface UIDevice : NSObject
@property (class, nonatomic, readonly) UIDevice *currentDevice;
@property (nonatomic, readonly, strong) NSString *name;
@property (nonatomic, readonly, strong) NSString *model;
@property (nonatomic, readonly, strong) NSString *localizedModel;
@property (nonatomic, readonly, strong) NSString *systemName;
@property (nonatomic, readonly, strong) NSString *systemVersion;
@property (nonatomic, readonly) UIDeviceOrientation orientation;
@property (nonatomic, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, readonly, getter=isMultitaskingSupported) BOOL multitaskingSupported;
/* isim: a simulated battery (ISIM_BATTERY="LEVEL [unplugged|charging|full]", default "1 full"), read while
   batteryMonitoringEnabled (else level -1, state unknown, like iOS) */
@property (nonatomic, getter=isBatteryMonitoringEnabled) BOOL batteryMonitoringEnabled;
@property (nonatomic, readonly) UIDeviceBatteryState batteryState;
@property (nonatomic, readonly) float batteryLevel;
/* isim: a UUID per vendor (the bundle identifier without its last component), kept in the device data */
@property (nullable, nonatomic, readonly, strong) NSUUID *identifierForVendor;
@property (nonatomic, getter=isProximityMonitoringEnabled) BOOL proximityMonitoringEnabled;   /* no proximity sensor: stays NO */
@property (nonatomic, readonly) BOOL proximityState;
- (void)playInputClick;
/* isim: the simulated device's marketing name ("iPhone 15") */
@property (nonatomic, readonly, strong) NSString *_isim_deviceName;
@end
NS_ASSUME_NONNULL_END
