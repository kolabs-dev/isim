#pragma once
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class UITouch, UIView, UIWindow, UIGestureRecognizer;
typedef NS_OPTIONS(NSInteger, UIKeyModifierFlags) {
    UIKeyModifierAlphaShift = 1 << 16, UIKeyModifierShift = 1 << 17, UIKeyModifierControl = 1 << 18,
    UIKeyModifierAlternate = 1 << 19, UIKeyModifierCommand = 1 << 20, UIKeyModifierNumericPad = 1 << 21 };
typedef NS_ENUM(NSInteger, UIEventType) { UIEventTypeTouches, UIEventTypeMotion, UIEventTypeRemoteControl, UIEventTypePresses,
    UIEventTypeScroll API_AVAILABLE(ios(13.4)) = 10, UIEventTypeHover API_AVAILABLE(ios(13.4)) = 11, UIEventTypeTransform API_AVAILABLE(ios(13.4)) = 14 };
typedef NS_ENUM(NSInteger, UIEventSubtype) { UIEventSubtypeNone = 0, UIEventSubtypeMotionShake = 1, UIEventSubtypeRemoteControlPlay = 100,
    UIEventSubtypeRemoteControlPause = 101, UIEventSubtypeRemoteControlStop = 102, UIEventSubtypeRemoteControlTogglePlayPause = 103,
    UIEventSubtypeRemoteControlNextTrack = 104, UIEventSubtypeRemoteControlPreviousTrack = 105,
    UIEventSubtypeRemoteControlBeginSeekingBackward = 106, UIEventSubtypeRemoteControlEndSeekingBackward = 107,
    UIEventSubtypeRemoteControlBeginSeekingForward = 108, UIEventSubtypeRemoteControlEndSeekingForward = 109 };
/* the pointer buttons held for an event (iPad pointer: a click is the primary button) */
typedef NS_OPTIONS(NSInteger, UIEventButtonMask) { UIEventButtonMaskPrimary = 1 << 0, UIEventButtonMaskSecondary = 1 << 1 } NS_SWIFT_NAME(UIEvent.ButtonMask) API_AVAILABLE(ios(13.4));
static inline UIEventButtonMask UIEventButtonMaskForButtonNumber(NSInteger buttonNumber) API_AVAILABLE(ios(13.4)) NS_SWIFT_NAME(UIEventButtonMask.button(_:)) {
    return (UIEventButtonMask)(1 << (buttonNumber - 1));
}
NS_SWIFT_UI_ACTOR
@interface UIEvent : NSObject
@property (nonatomic, readonly) UIEventType type;
@property (nonatomic, readonly) UIEventSubtype subtype;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly, nullable) NSSet<UITouch *> *allTouches;
- (nullable NSSet<UITouch *> *)touchesForView:(UIView *)view;
- (nullable NSSet<UITouch *> *)touchesForWindow:(UIWindow *)window;
- (nullable NSSet<UITouch *> *)touchesForGestureRecognizer:(UIGestureRecognizer *)gesture;
- (nullable NSArray<UITouch *> *)coalescedTouchesForTouch:(UITouch *)touch;
- (nullable NSArray<UITouch *> *)predictedTouchesForTouch:(UITouch *)touch;
/* the hardware keyboard modifiers held when the event happened */
@property (nonatomic, readonly) UIKeyModifierFlags modifierFlags API_AVAILABLE(ios(13.4));
/* the pointer buttons of an iPad pointer (indirect pointer) event; 0 for finger touches */
@property (nonatomic, readonly) UIEventButtonMask buttonMask API_AVAILABLE(ios(13.4));
@end
NS_ASSUME_NONNULL_END
