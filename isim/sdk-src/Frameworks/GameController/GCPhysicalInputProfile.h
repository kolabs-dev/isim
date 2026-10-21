#pragma once
#import <GameController/GCControllerElement.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@protocol GCDevice;
@class GCController, GCDualSenseAdaptiveTrigger;
API_AVAILABLE(ios(14.0))
@interface GCPhysicalInputProfile : NSObject
@property (nonatomic, readonly, weak, nullable) id<GCDevice> device;
@property (atomic, readonly) NSTimeInterval lastEventTimestamp;
@property (atomic, readonly) BOOL hasRemappedElements;
@property (nonatomic, copy, nullable) void (^valueDidChangeHandler)(GCPhysicalInputProfile *profile, GCControllerElement *element);
@property (nonatomic, readonly) NSDictionary<NSString *, GCControllerElement *> *elements;
@property (nonatomic, readonly) NSDictionary<NSString *, GCControllerButtonInput *> *buttons;
@property (nonatomic, readonly) NSDictionary<NSString *, GCControllerAxisInput *> *axes;
@property (nonatomic, readonly) NSDictionary<NSString *, GCControllerDirectionPad *> *dpads;
@property (nonatomic, readonly) NSDictionary<NSString *, GCControllerTouchpad *> *touchpads;
@property (nonatomic, readonly) NSSet<GCControllerElement *> *allElements;
@property (nonatomic, readonly) NSSet<GCControllerButtonInput *> *allButtons;
@property (nonatomic, readonly) NSSet<GCControllerAxisInput *> *allAxes;
@property (nonatomic, readonly) NSSet<GCControllerDirectionPad *> *allDpads;
@property (nonatomic, readonly) NSSet<GCControllerTouchpad *> *allTouchpads;
- (nullable __kindof GCControllerElement *)objectForKeyedSubscript:(NSString *)key;
- (instancetype)capture;
- (NSString *)mappedElementAliasForPhysicalInputName:(NSString *)inputName;
- (NSSet<NSString *> *)mappedPhysicalInputNamesForElementAlias:(NSString *)elementAlias;
@end
@class GCExtendedGamepad, GCMicroGamepad;
typedef void (^GCExtendedGamepadValueChangedHandler)(GCExtendedGamepad *gamepad, GCControllerElement *element);
API_AVAILABLE(ios(7.0))
@interface GCExtendedGamepad : GCPhysicalInputProfile
@property (nonatomic, readonly, weak, nullable) GCController *controller;
@property (nonatomic, copy, nullable) GCExtendedGamepadValueChangedHandler valueChangedHandler;
@property (nonatomic, readonly) GCControllerDirectionPad *dpad;
@property (nonatomic, readonly) GCControllerButtonInput *buttonA;
@property (nonatomic, readonly) GCControllerButtonInput *buttonB;
@property (nonatomic, readonly) GCControllerButtonInput *buttonX;
@property (nonatomic, readonly) GCControllerButtonInput *buttonY;
@property (nonatomic, readonly) GCControllerButtonInput *buttonMenu;
@property (nonatomic, readonly, nullable) GCControllerButtonInput *buttonOptions;
@property (nonatomic, readonly, nullable) GCControllerButtonInput *buttonHome;
@property (nonatomic, readonly) GCControllerDirectionPad *leftThumbstick;
@property (nonatomic, readonly) GCControllerDirectionPad *rightThumbstick;
@property (nonatomic, readonly) GCControllerButtonInput *leftShoulder;
@property (nonatomic, readonly) GCControllerButtonInput *rightShoulder;
@property (nonatomic, readonly) GCControllerButtonInput *leftTrigger;
@property (nonatomic, readonly) GCControllerButtonInput *rightTrigger;
@property (nonatomic, readonly, nullable) GCControllerButtonInput *leftThumbstickButton;
@property (nonatomic, readonly, nullable) GCControllerButtonInput *rightThumbstickButton;
- (void)setStateFromExtendedGamepad:(GCExtendedGamepad *)extendedGamepad;
@end
typedef void (^GCMicroGamepadValueChangedHandler)(GCMicroGamepad *gamepad, GCControllerElement *element);
API_AVAILABLE(ios(7.0))
@interface GCMicroGamepad : GCPhysicalInputProfile
@property (nonatomic, readonly, weak, nullable) GCController *controller;
@property (nonatomic, copy, nullable) GCMicroGamepadValueChangedHandler valueChangedHandler;
@property (nonatomic, readonly) GCControllerDirectionPad *dpad;
@property (nonatomic, readonly) GCControllerButtonInput *buttonA;
@property (nonatomic, readonly) GCControllerButtonInput *buttonX;
@property (nonatomic, readonly) GCControllerButtonInput *buttonMenu;
@property (nonatomic) BOOL reportsAbsoluteDpadValues;
@property (nonatomic) BOOL allowsRotation;
@end
API_AVAILABLE(ios(14.5))
@interface GCDirectionalGamepad : GCMicroGamepad
@end
API_AVAILABLE(ios(14.0))
@interface GCXboxGamepad : GCExtendedGamepad
@property (nonatomic, readonly, nullable) GCControllerButtonInput *paddleButton1;
@property (nonatomic, readonly, nullable) GCControllerButtonInput *paddleButton2;
@property (nonatomic, readonly, nullable) GCControllerButtonInput *paddleButton3;
@property (nonatomic, readonly, nullable) GCControllerButtonInput *paddleButton4;
@property (nonatomic, readonly, nullable) GCControllerButtonInput *buttonShare;
@end
API_AVAILABLE(ios(14.0))
@interface GCDualShockGamepad : GCExtendedGamepad
@property (nonatomic, readonly) GCControllerButtonInput *touchpadButton;
@property (nonatomic, readonly) GCControllerDirectionPad *touchpadPrimary;
@property (nonatomic, readonly) GCControllerDirectionPad *touchpadSecondary;
@end
typedef NS_ENUM(NSInteger, GCDualSenseAdaptiveTriggerMode) {
    GCDualSenseAdaptiveTriggerModeOff = 0, GCDualSenseAdaptiveTriggerModeFeedback = 1, GCDualSenseAdaptiveTriggerModeWeapon = 2,
    GCDualSenseAdaptiveTriggerModeVibration = 3, GCDualSenseAdaptiveTriggerModeSlopeFeedback = 4,
};
/* isim: the modes are sent to a host DualSense; positional strengths and amplitudes are Swift-only */
API_AVAILABLE(ios(14.5))
@interface GCDualSenseAdaptiveTrigger : GCControllerButtonInput
@property (nonatomic, readonly) GCDualSenseAdaptiveTriggerMode mode;
@property (nonatomic, readonly) float armPosition;
- (void)setModeOff;
- (void)setModeFeedbackWithStartPosition:(float)startPosition resistiveStrength:(float)resistiveStrength;
- (void)setModeWeaponWithStartPosition:(float)startPosition endPosition:(float)endPosition resistiveStrength:(float)resistiveStrength;
- (void)setModeVibrationWithStartPosition:(float)startPosition amplitude:(float)amplitude frequency:(float)frequency;
@end
API_AVAILABLE(ios(14.5))
@interface GCDualSenseGamepad : GCExtendedGamepad
@property (nonatomic, readonly) GCControllerButtonInput *touchpadButton;
@property (nonatomic, readonly) GCControllerDirectionPad *touchpadPrimary;
@property (nonatomic, readonly) GCControllerDirectionPad *touchpadSecondary;
@property (nonatomic, readonly) GCDualSenseAdaptiveTrigger *leftTrigger;
@property (nonatomic, readonly) GCDualSenseAdaptiveTrigger *rightTrigger;
@end
NS_ASSUME_NONNULL_END
#endif
