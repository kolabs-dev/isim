#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UITraitCollection.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIDeviceOrientation) { UIDeviceOrientationUnknown, UIDeviceOrientationPortrait, UIDeviceOrientationPortraitUpsideDown, UIDeviceOrientationLandscapeLeft, UIDeviceOrientationLandscapeRight, UIDeviceOrientationFaceUp, UIDeviceOrientationFaceDown };
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
/* isim: the simulated device's marketing name ("iPhone 15") */
@property (nonatomic, readonly, strong) NSString *_isim_deviceName;
@end
NS_ASSUME_NONNULL_END
