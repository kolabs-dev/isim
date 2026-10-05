#pragma once
#import <UIKit/UIViewController.h>
#import <UIKit/UITextInput.h>
NS_ASSUME_NONNULL_BEGIN
@class UIEvent;
typedef NS_ENUM(NSInteger, UIInputViewStyle) { UIInputViewStyleDefault, UIInputViewStyleKeyboard };
@interface UIInputView : UIView
- (instancetype)initWithFrame:(CGRect)frame inputViewStyle:(UIInputViewStyle)inputViewStyle;
@property (nonatomic, readonly) UIInputViewStyle inputViewStyle;
@property (nonatomic) BOOL allowsSelfSizing;
@end
/* Custom keyboard extension principal class. On isim the host app's software keyboard
 * area loads the extension's executable in-process and embeds this controller's view. */
@interface UIInputViewController : UIViewController <UITextInputDelegate>
@property (nullable, nonatomic, strong) UIInputView *inputView;
@property (nonatomic, readonly) id <UITextDocumentProxy> textDocumentProxy;
@property (nullable, nonatomic, copy) NSString *primaryLanguage;
@property (nonatomic) BOOL hasDictationKey;
@property (nonatomic, readonly) BOOL hasFullAccess;
@property (nonatomic, readonly) BOOL needsInputModeSwitchKey;
- (void)dismissKeyboard;
- (void)advanceToNextInputMode;
- (void)handleInputModeListFromView:(UIView *)view withEvent:(UIEvent *)event;
@end
NS_ASSUME_NONNULL_END
