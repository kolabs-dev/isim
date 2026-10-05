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
NS_ASSUME_NONNULL_END
