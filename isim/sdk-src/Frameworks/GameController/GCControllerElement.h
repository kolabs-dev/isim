#pragma once
#import <GameController/GCExtern.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class GCControllerButtonInput, GCControllerAxisInput, GCControllerDirectionPad;
typedef NS_ENUM(NSInteger, GCSystemGestureState) { GCSystemGestureStateEnabled = 0, GCSystemGestureStateAlwaysReceive, GCSystemGestureStateDisabled };
API_AVAILABLE(ios(7.0))
@interface GCControllerElement : NSObject
@property (nonatomic, weak, readonly, nullable) GCControllerElement *collection;
@property (nonatomic, readonly, getter=isAnalog) BOOL analog;
@property (nonatomic, readonly, getter=isBoundToSystemGesture) BOOL boundToSystemGesture;
@property (nonatomic) GCSystemGestureState preferredSystemGestureState;
@property (nonatomic, copy, nullable) NSString *localizedName;
@property (nonatomic, copy, nullable) NSString *unmappedLocalizedName;
@property (nonatomic, copy, nullable) NSString *sfSymbolsName;
@property (nonatomic, copy, nullable) NSString *unmappedSfSymbolsName;
@property (nonatomic, readonly) NSSet<NSString *> *aliases;
@end
typedef void (^GCControllerButtonValueChangedHandler)(GCControllerButtonInput *button, float value, BOOL pressed);
typedef void (^GCControllerButtonTouchedChangedHandler)(GCControllerButtonInput *button, float value, BOOL pressed, BOOL touched);
API_AVAILABLE(ios(7.0))
@interface GCControllerButtonInput : GCControllerElement
@property (nonatomic, copy, nullable) GCControllerButtonValueChangedHandler valueChangedHandler;
@property (nonatomic, copy, nullable) GCControllerButtonValueChangedHandler pressedChangedHandler;
@property (nonatomic, copy, nullable) GCControllerButtonTouchedChangedHandler touchedChangedHandler;
@property (nonatomic, readonly) float value;
@property (nonatomic, readonly, getter=isPressed) BOOL pressed;
@property (nonatomic, readonly, getter=isTouched) BOOL touched;
- (void)setValue:(float)value;
@end
typedef void (^GCControllerAxisValueChangedHandler)(GCControllerAxisInput *axis, float value);
API_AVAILABLE(ios(7.0))
@interface GCControllerAxisInput : GCControllerElement
@property (nonatomic, copy, nullable) GCControllerAxisValueChangedHandler valueChangedHandler;
@property (nonatomic, readonly) float value;
- (void)setValue:(float)value;
@end
typedef void (^GCControllerDirectionPadValueChangedHandler)(GCControllerDirectionPad *dpad, float xValue, float yValue);
API_AVAILABLE(ios(7.0))
@interface GCControllerDirectionPad : GCControllerElement
@property (nonatomic, copy, nullable) GCControllerDirectionPadValueChangedHandler valueChangedHandler;
@property (nonatomic, readonly) GCControllerAxisInput *xAxis;
@property (nonatomic, readonly) GCControllerAxisInput *yAxis;
@property (nonatomic, readonly) GCControllerButtonInput *up;
@property (nonatomic, readonly) GCControllerButtonInput *down;
@property (nonatomic, readonly) GCControllerButtonInput *left;
@property (nonatomic, readonly) GCControllerButtonInput *right;
- (void)setValueForXAxis:(float)xAxis yAxis:(float)yAxis;
@end
typedef NS_ENUM(NSInteger, GCTouchState) { GCTouchStateUp, GCTouchStateDown, GCTouchStateMoving };
@class GCControllerTouchpad;
typedef void (^GCControllerTouchpadHandler)(GCControllerTouchpad *touchpad, float xValue, float yValue, float buttonValue, BOOL buttonPressed);
API_AVAILABLE(ios(14.0))
@interface GCControllerTouchpad : GCControllerElement
@property (nonatomic, readonly) GCControllerButtonInput *button;
@property (nonatomic, copy, nullable) GCControllerTouchpadHandler touchDown;
@property (nonatomic, copy, nullable) GCControllerTouchpadHandler touchMoved;
@property (nonatomic, copy, nullable) GCControllerTouchpadHandler touchUp;
@property (nonatomic, readonly) GCControllerDirectionPad *touchSurface;
@property (nonatomic, readonly) GCTouchState touchState;
@property (nonatomic) BOOL reportsAbsoluteTouchSurfaceValues;
- (void)setValueForXAxis:(float)xAxis yAxis:(float)yAxis touchDown:(BOOL)touchDown buttonValue:(float)buttonValue;
@end
API_AVAILABLE(ios(14.0))
@interface GCDeviceCursor : GCControllerDirectionPad
@end
NS_ASSUME_NONNULL_END
#endif
