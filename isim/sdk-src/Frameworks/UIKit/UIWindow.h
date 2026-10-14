#pragma once
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIViewController, UIWindowScene, UIScreen;
typedef CGFloat UIWindowLevel NS_TYPED_EXTENSIBLE_ENUM;
UIKIT_EXTERN const UIWindowLevel UIWindowLevelNormal, UIWindowLevelAlert, UIWindowLevelStatusBar;
@interface UIWindow : UIView
- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene;
- (instancetype)initWithFrame:(CGRect)frame;
@property (nullable, nonatomic, weak) UIWindowScene *windowScene;
@property (nonatomic, strong) UIScreen *screen;
@property (nonatomic) UIWindowLevel windowLevel;
@property (nonatomic, readonly, getter=isKeyWindow) BOOL keyWindow;
@property (nonatomic, readonly) BOOL canBecomeKeyWindow;
- (void)becomeKeyWindow;
- (void)resignKeyWindow;
- (void)makeKeyWindow;
- (void)makeKeyAndVisible;
@property (nullable, nonatomic, strong) UIViewController *rootViewController;
- (void)sendEvent:(UIEvent *)event;
@end
@interface UIWindow (IsimWindowConversion)
- (CGPoint)convertPoint:(CGPoint)point toWindow:(nullable UIWindow *)window;
- (CGPoint)convertPoint:(CGPoint)point fromWindow:(nullable UIWindow *)window;
- (CGRect)convertRect:(CGRect)rect toWindow:(nullable UIWindow *)window;
- (CGRect)convertRect:(CGRect)rect fromWindow:(nullable UIWindow *)window;
@end
/* software keyboard (isim system keyboard window) */
UIKIT_EXTERN NSNotificationName const UIWindowDidBecomeVisibleNotification, UIWindowDidBecomeHiddenNotification,
    UIWindowDidBecomeKeyNotification, UIWindowDidResignKeyNotification;
UIKIT_EXTERN NSNotificationName const UIKeyboardWillShowNotification, UIKeyboardDidShowNotification, UIKeyboardWillHideNotification,
    UIKeyboardDidHideNotification, UIKeyboardWillChangeFrameNotification, UIKeyboardDidChangeFrameNotification;
UIKIT_EXTERN NSString *const UIKeyboardFrameBeginUserInfoKey, *const UIKeyboardFrameEndUserInfoKey,
    *const UIKeyboardAnimationDurationUserInfoKey, *const UIKeyboardAnimationCurveUserInfoKey, *const UIKeyboardIsLocalUserInfoKey;
NS_ASSUME_NONNULL_END
