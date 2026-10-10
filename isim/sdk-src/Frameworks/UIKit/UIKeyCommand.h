#pragma once
/* isim: hardware keyboard input — UIKey, UIPress, UIPressesEvent, UIKeyCommand, key modifier flags. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIEvent.h>
#import <UIKit/UIResponder.h>
#import <UIKit/UIViewController.h>
@class UIImage;
NS_ASSUME_NONNULL_BEGIN
/* UIKeyModifierFlags: UIEvent.h */
typedef NS_ENUM(NSInteger, UIKeyboardHIDUsage) {
    UIKeyboardHIDUsageKeyboardA = 0x04, UIKeyboardHIDUsageKeyboardB, UIKeyboardHIDUsageKeyboardC, UIKeyboardHIDUsageKeyboardD,
    UIKeyboardHIDUsageKeyboardE, UIKeyboardHIDUsageKeyboardF, UIKeyboardHIDUsageKeyboardG, UIKeyboardHIDUsageKeyboardH,
    UIKeyboardHIDUsageKeyboardI, UIKeyboardHIDUsageKeyboardJ, UIKeyboardHIDUsageKeyboardK, UIKeyboardHIDUsageKeyboardL,
    UIKeyboardHIDUsageKeyboardM, UIKeyboardHIDUsageKeyboardN, UIKeyboardHIDUsageKeyboardO, UIKeyboardHIDUsageKeyboardP,
    UIKeyboardHIDUsageKeyboardQ, UIKeyboardHIDUsageKeyboardR, UIKeyboardHIDUsageKeyboardS, UIKeyboardHIDUsageKeyboardT,
    UIKeyboardHIDUsageKeyboardU, UIKeyboardHIDUsageKeyboardV, UIKeyboardHIDUsageKeyboardW, UIKeyboardHIDUsageKeyboardX,
    UIKeyboardHIDUsageKeyboardY, UIKeyboardHIDUsageKeyboardZ,
    UIKeyboardHIDUsageKeyboard1 = 0x1E, UIKeyboardHIDUsageKeyboard2, UIKeyboardHIDUsageKeyboard3, UIKeyboardHIDUsageKeyboard4,
    UIKeyboardHIDUsageKeyboard5, UIKeyboardHIDUsageKeyboard6, UIKeyboardHIDUsageKeyboard7, UIKeyboardHIDUsageKeyboard8,
    UIKeyboardHIDUsageKeyboard9, UIKeyboardHIDUsageKeyboard0,
    UIKeyboardHIDUsageKeyboardReturnOrEnter = 0x28, UIKeyboardHIDUsageKeyboardEscape = 0x29, UIKeyboardHIDUsageKeyboardDeleteOrBackspace = 0x2A,
    UIKeyboardHIDUsageKeyboardTab = 0x2B, UIKeyboardHIDUsageKeyboardSpacebar = 0x2C, UIKeyboardHIDUsageKeyboardHyphen = 0x2D,
    UIKeyboardHIDUsageKeyboardEqualSign = 0x2E, UIKeyboardHIDUsageKeyboardOpenBracket = 0x2F, UIKeyboardHIDUsageKeyboardCloseBracket = 0x30,
    UIKeyboardHIDUsageKeyboardBackslash = 0x31, UIKeyboardHIDUsageKeyboardSemicolon = 0x33, UIKeyboardHIDUsageKeyboardQuote = 0x34,
    UIKeyboardHIDUsageKeyboardGraveAccentAndTilde = 0x35, UIKeyboardHIDUsageKeyboardComma = 0x36, UIKeyboardHIDUsageKeyboardPeriod = 0x37,
    UIKeyboardHIDUsageKeyboardSlash = 0x38, UIKeyboardHIDUsageKeyboardCapsLock = 0x39,
    UIKeyboardHIDUsageKeyboardF1 = 0x3A, UIKeyboardHIDUsageKeyboardF2, UIKeyboardHIDUsageKeyboardF3, UIKeyboardHIDUsageKeyboardF4,
    UIKeyboardHIDUsageKeyboardF5, UIKeyboardHIDUsageKeyboardF6, UIKeyboardHIDUsageKeyboardF7, UIKeyboardHIDUsageKeyboardF8,
    UIKeyboardHIDUsageKeyboardF9, UIKeyboardHIDUsageKeyboardF10, UIKeyboardHIDUsageKeyboardF11, UIKeyboardHIDUsageKeyboardF12,
    UIKeyboardHIDUsageKeyboardHome = 0x4A, UIKeyboardHIDUsageKeyboardPageUp = 0x4B, UIKeyboardHIDUsageKeyboardDeleteForward = 0x4C,
    UIKeyboardHIDUsageKeyboardEnd = 0x4D, UIKeyboardHIDUsageKeyboardPageDown = 0x4E, UIKeyboardHIDUsageKeyboardRightArrow = 0x4F,
    UIKeyboardHIDUsageKeyboardLeftArrow = 0x50, UIKeyboardHIDUsageKeyboardDownArrow = 0x51, UIKeyboardHIDUsageKeyboardUpArrow = 0x52,
    UIKeyboardHIDUsageKeyboardLeftControl = 0xE0, UIKeyboardHIDUsageKeyboardLeftShift = 0xE1, UIKeyboardHIDUsageKeyboardLeftAlt = 0xE2,
    UIKeyboardHIDUsageKeyboardLeftGUI = 0xE3, UIKeyboardHIDUsageKeyboardRightControl = 0xE4, UIKeyboardHIDUsageKeyboardRightShift = 0xE5,
    UIKeyboardHIDUsageKeyboardRightAlt = 0xE6, UIKeyboardHIDUsageKeyboardRightGUI = 0xE7 };

NS_SWIFT_UI_ACTOR
@interface UIKey : NSObject <NSCopying>
@property (nonatomic, readonly) NSString *characters;
@property (nonatomic, readonly) NSString *charactersIgnoringModifiers;
@property (nonatomic, readonly) UIKeyModifierFlags modifierFlags;
@property (nonatomic, readonly) UIKeyboardHIDUsage keyCode;
@end
typedef NS_ENUM(NSInteger, UIPressPhase) { UIPressPhaseBegan, UIPressPhaseChanged, UIPressPhaseStationary, UIPressPhaseEnded, UIPressPhaseCancelled };
typedef NS_ENUM(NSInteger, UIPressType) { UIPressTypeUpArrow, UIPressTypeDownArrow, UIPressTypeLeftArrow, UIPressTypeRightArrow,
    UIPressTypeSelect, UIPressTypeMenu, UIPressTypePlayPause };
NS_SWIFT_UI_ACTOR
@interface UIPress : NSObject
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) UIPressPhase phase;
@property (nonatomic, readonly) UIPressType type;
@property (nonatomic, readonly) CGFloat force;
@property (nullable, nonatomic, readonly) UIKey *key;
@end
NS_SWIFT_UI_ACTOR
@interface UIPressesEvent : UIEvent
@property (nonatomic, readonly) NSSet<UIPress *> *allPresses;
/* the presses the recognizer receives (isim: recognizers get no presses, so an empty set) */
- (NSSet<UIPress *> *)pressesForGestureRecognizer:(UIGestureRecognizer *)gesture;
@end

UIKIT_EXTERN NSString *const UIKeyInputUpArrow;
UIKIT_EXTERN NSString *const UIKeyInputDownArrow;
UIKIT_EXTERN NSString *const UIKeyInputLeftArrow;
UIKIT_EXTERN NSString *const UIKeyInputRightArrow;
UIKIT_EXTERN NSString *const UIKeyInputEscape;
UIKIT_EXTERN NSString *const UIKeyInputPageUp;
UIKIT_EXTERN NSString *const UIKeyInputPageDown;
UIKIT_EXTERN NSString *const UIKeyInputHome;
UIKIT_EXTERN NSString *const UIKeyInputEnd;
UIKIT_EXTERN NSString *const UIKeyInputDelete;

NS_SWIFT_UI_ACTOR
@interface UIKeyCommand : NSObject <NSCopying>
+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action;
+ (instancetype)commandWithTitle:(NSString *)title image:(nullable UIImage *)image action:(SEL)action input:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags propertyList:(nullable id)propertyList;
@property (nullable, nonatomic, readonly) NSString *input;
@property (nonatomic, readonly) UIKeyModifierFlags modifierFlags;
@property (nullable, nonatomic, readonly) SEL action;
@property (nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *discoverabilityTitle;
@property (nonatomic) BOOL wantsPriorityOverSystemBehavior;
@property (nullable, nonatomic, readonly) id propertyList;
@end

@interface UIResponder (UIKeyboardAndMotion)
@property (nullable, nonatomic, readonly) NSArray<UIKeyCommand *> *keyCommands;
- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(nullable UIPressesEvent *)event;
- (void)pressesChanged:(NSSet<UIPress *> *)presses withEvent:(nullable UIPressesEvent *)event;
- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(nullable UIPressesEvent *)event;
- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(nullable UIPressesEvent *)event;
- (void)motionBegan:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event;
- (void)motionEnded:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event;
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event;
- (nullable id)targetForAction:(SEL)action withSender:(nullable id)sender;
@end
@interface UIViewController (UIKeyCommands)
- (void)addKeyCommand:(UIKeyCommand *)keyCommand;
- (void)removeKeyCommand:(UIKeyCommand *)keyCommand;
@end
NS_ASSUME_NONNULL_END
