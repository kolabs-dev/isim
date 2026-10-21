// isim GameController for Objective-C (issue #548): the constants (the Swift overlay's strings), GCMotion's C structs,
// +[GCVirtualController virtualControllerWithConfiguration:], and the start of controller discovery once the app runs (Swift
// starts it when it first reads a notification name; Objective-C apps only observe the strings).
#import <GameController/GameController.h>
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"   // categories implement what the header declares

NSString * const GCInputButtonA = @"Button A";
NSString * const GCInputButtonB = @"Button B";
NSString * const GCInputButtonX = @"Button X";
NSString * const GCInputButtonY = @"Button Y";
NSString * const GCInputDirectionPad = @"Direction Pad";
NSString * const GCInputLeftThumbstick = @"Left Thumbstick";
NSString * const GCInputRightThumbstick = @"Right Thumbstick";
NSString * const GCInputLeftShoulder = @"Left Shoulder";
NSString * const GCInputRightShoulder = @"Right Shoulder";
NSString * const GCInputLeftTrigger = @"Left Trigger";
NSString * const GCInputRightTrigger = @"Right Trigger";
NSString * const GCInputLeftThumbstickButton = @"Left Thumbstick Button";
NSString * const GCInputRightThumbstickButton = @"Right Thumbstick Button";
NSString * const GCInputButtonHome = @"Button Home";
NSString * const GCInputButtonMenu = @"Button Menu";
NSString * const GCInputButtonOptions = @"Button Options";
NSString * const GCInputButtonShare = @"Button Share";
NSString * const GCInputXboxPaddleOne = @"Paddle 1";
NSString * const GCInputXboxPaddleTwo = @"Paddle 2";
NSString * const GCInputXboxPaddleThree = @"Paddle 3";
NSString * const GCInputXboxPaddleFour = @"Paddle 4";
NSString * const GCInputDualShockTouchpadOne = @"Touchpad 1";
NSString * const GCInputDualShockTouchpadTwo = @"Touchpad 2";
NSString * const GCInputDualShockTouchpadButton = @"Touchpad Button";
NSString * const GCProductCategoryDualSense = @"DualSense";
NSString * const GCProductCategoryDualShock4 = @"DualShock 4";
NSString * const GCProductCategoryMFi = @"MFi";
NSString * const GCProductCategoryXboxOne = @"Xbox One";
NSString * const GCProductCategorySwitchPro = @"Switch Pro Controller";
NSString * const GCProductCategorySwitchJoyConPair = @"Nintendo Switch Joy-Con (L/R)";
NSString * const GCProductCategoryHID = @"HID";
NSString * const GCProductCategoryKeyboard = @"Keyboard";
NSString * const GCProductCategoryMouse = @"Mouse";
NSNotificationName const GCControllerDidConnectNotification = @"GCControllerDidConnectNotification";
NSNotificationName const GCControllerDidDisconnectNotification = @"GCControllerDidDisconnectNotification";
NSNotificationName const GCControllerDidBecomeCurrentNotification = @"GCControllerDidBecomeCurrentNotification";
NSNotificationName const GCControllerDidStopBeingCurrentNotification = @"GCControllerDidStopBeingCurrentNotification";
NSNotificationName const GCKeyboardDidConnectNotification = @"GCKeyboardDidConnectNotification";
NSNotificationName const GCKeyboardDidDisconnectNotification = @"GCKeyboardDidDisconnectNotification";
NSNotificationName const GCMouseDidConnectNotification = @"GCMouseDidConnectNotification";
NSNotificationName const GCMouseDidDisconnectNotification = @"GCMouseDidDisconnectNotification";
NSNotificationName const GCMouseDidBecomeCurrentNotification = @"GCMouseDidBecomeCurrentNotification";
NSNotificationName const GCMouseDidStopBeingCurrentNotification = @"GCMouseDidStopBeingCurrentNotification";
GCHapticsLocality const GCHapticsLocalityDefault = @"Default";
GCHapticsLocality const GCHapticsLocalityAll = @"All";
GCHapticsLocality const GCHapticsLocalityHandles = @"Handles";
GCHapticsLocality const GCHapticsLocalityLeftHandle = @"LeftHandle";
GCHapticsLocality const GCHapticsLocalityRightHandle = @"RightHandle";
GCHapticsLocality const GCHapticsLocalityTriggers = @"Triggers";
GCHapticsLocality const GCHapticsLocalityLeftTrigger = @"LeftTrigger";
GCHapticsLocality const GCHapticsLocalityRightTrigger = @"RightTrigger";
const float GCHapticDurationInfinite = __FLT_MAX__;

@interface GCMotion (ISIMValues)
- (NSArray<NSNumber *> *)_isim_values;
@end
static double at(NSArray<NSNumber *> *a, NSUInteger i) { return i < a.count ? a[i].doubleValue : 0; }
@implementation GCMotion (ISIMStructs)
- (GCAcceleration)gravity { NSArray *v = [self _isim_values]; return (GCAcceleration){ at(v, 0), at(v, 1), at(v, 2) }; }
- (GCAcceleration)userAcceleration { NSArray *v = [self _isim_values]; return (GCAcceleration){ at(v, 3), at(v, 4), at(v, 5) }; }
- (GCAcceleration)acceleration { NSArray *v = [self _isim_values]; return (GCAcceleration){ at(v, 6), at(v, 7), at(v, 8) }; }
- (GCRotationRate)rotationRate { NSArray *v = [self _isim_values]; return (GCRotationRate){ at(v, 9), at(v, 10), at(v, 11) }; }
- (GCQuaternion)attitude { NSArray *v = [self _isim_values]; return (GCQuaternion){ at(v, 12), at(v, 13), at(v, 14), at(v, 15) }; }
@end

@implementation GCVirtualController (ISIMFactory)
+ (instancetype)virtualControllerWithConfiguration:(GCVirtualControllerConfiguration *)configuration {
    return [[self alloc] initWithConfiguration:configuration];
}
@end

__attribute__((constructor)) static void isim_gc_start(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ [GCController controllers]; });
}
