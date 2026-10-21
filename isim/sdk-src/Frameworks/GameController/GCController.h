#pragma once
#import <GameController/GCPhysicalInputProfile.h>
#import <CoreHaptics/CoreHaptics.h>
#import <dispatch/dispatch.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class GCController, GCMotion;
API_AVAILABLE(ios(14.0))
@protocol GCDevice <NSObject>
@property (nonatomic, strong) dispatch_queue_t handlerQueue;
@property (nonatomic, readonly, nullable) NSString *vendorName;
@property (nonatomic, readonly) NSString *productCategory;
@property (nonatomic, readonly) GCPhysicalInputProfile *physicalInputProfile;
@end
typedef NS_ENUM(NSInteger, GCDeviceBatteryState) {
    GCDeviceBatteryStateUnknown = -1, GCDeviceBatteryStateDischarging, GCDeviceBatteryStateCharging, GCDeviceBatteryStateFull,
};
API_AVAILABLE(ios(14.0))
@interface GCDeviceBattery : NSObject
@property (nonatomic, readonly) float batteryLevel;
@property (nonatomic, readonly) GCDeviceBatteryState batteryState;
@end
API_AVAILABLE(ios(14.0))
@interface GCColor : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithRed:(float)red green:(float)green blue:(float)blue;
@property (nonatomic, readonly) float red;
@property (nonatomic, readonly) float green;
@property (nonatomic, readonly) float blue;
@end
API_AVAILABLE(ios(14.0))
@interface GCDeviceLight : NSObject
@property (nonatomic, copy) GCColor *color;
@end
API_AVAILABLE(ios(14.0))
@interface GCDeviceHaptics : NSObject
@property (nonatomic, readonly) NSSet<GCHapticsLocality> *supportedLocalities;
/* isim: an engine that rumbles the host gamepad */
- (nullable CHHapticEngine *)createEngineWithLocality:(GCHapticsLocality)locality;
@end
typedef struct { double x, y, z; } GCAcceleration;
typedef struct { double x, y, z; } GCRotationRate;
typedef struct { double x, y, z, w; } GCQuaternion;
typedef void (^GCMotionValueChangedHandler)(GCMotion *motion);
/* isim: a host gamepad's accelerometer and gyroscope, where it has them */
API_AVAILABLE(ios(8.0))
@interface GCMotion : NSObject
@property (nonatomic, readonly, weak, nullable) GCController *controller;
@property (nonatomic, copy, nullable) GCMotionValueChangedHandler valueChangedHandler;
@property (nonatomic, readonly) BOOL sensorsRequireManualActivation;
@property (nonatomic, getter=areSensorsActive) BOOL sensorsActive;
@property (nonatomic, readonly) BOOL hasGravityAndUserAcceleration;
@property (nonatomic, readonly) BOOL hasAttitude;
@property (nonatomic, readonly) BOOL hasRotationRate;
@property (nonatomic, readonly) GCAcceleration gravity;
@property (nonatomic, readonly) GCAcceleration userAcceleration;
@property (nonatomic, readonly) GCAcceleration acceleration;
@property (nonatomic, readonly) GCQuaternion attitude;
@property (nonatomic, readonly) GCRotationRate rotationRate;
@end
typedef NS_ENUM(NSInteger, GCControllerPlayerIndex) {
    GCControllerPlayerIndexUnset = -1, GCControllerPlayerIndex1 = 0, GCControllerPlayerIndex2, GCControllerPlayerIndex3, GCControllerPlayerIndex4,
};
/* isim: the host's gamepads (SDL-style evdev), and GCVirtualController's on-screen controller */
API_AVAILABLE(ios(7.0))
@interface GCController : NSObject <GCDevice>
@property (nonatomic, copy, nullable) void (^controllerPausedHandler)(GCController *controller);
@property (nonatomic, strong) dispatch_queue_t handlerQueue;
@property (nonatomic, readonly, copy, nullable) NSString *vendorName;
@property (nonatomic, readonly) NSString *productCategory;
@property (nonatomic, readonly, getter=isAttachedToDevice) BOOL attachedToDevice;
@property (atomic, readonly, getter=isSnapshot) BOOL snapshot;
@property (nonatomic) GCControllerPlayerIndex playerIndex;
@property (nonatomic, readonly, nullable) GCExtendedGamepad *extendedGamepad;
@property (nonatomic, readonly, nullable) GCMicroGamepad *microGamepad;
@property (nonatomic, readonly) GCPhysicalInputProfile *physicalInputProfile;
@property (nonatomic, readonly, nullable) GCDeviceBattery *battery;
@property (nonatomic, readonly, nullable) GCDeviceLight *light;
@property (nonatomic, readonly, nullable) GCDeviceHaptics *haptics;
@property (nonatomic, readonly, nullable) GCMotion *motion;
@property (class, atomic, readonly, nullable) GCController *current;
+ (NSArray<GCController *> *)controllers;
+ (void)startWirelessControllerDiscoveryWithCompletionHandler:(nullable void (^)(void))completionHandler;
+ (void)stopWirelessControllerDiscovery;
+ (GCController *)controllerWithExtendedGamepad;
+ (GCController *)controllerWithMicroGamepad;
- (GCController *)capture;
@end
NS_ASSUME_NONNULL_END
#endif
