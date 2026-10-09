#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIControl.h>
#import <UIKit/UITextInput.h>
NS_ASSUME_NONNULL_BEGIN
@class UITextField, UIFont, UIColor;
typedef NS_ENUM(NSInteger, UITextBorderStyle) { UITextBorderStyleNone, UITextBorderStyleLine, UITextBorderStyleBezel, UITextBorderStyleRoundedRect };
typedef NS_ENUM(NSInteger, UITextFieldViewMode) { UITextFieldViewModeNever, UITextFieldViewModeWhileEditing, UITextFieldViewModeUnlessEditing, UITextFieldViewModeAlways };
typedef NS_ENUM(NSInteger, UITextFieldDidEndEditingReason) { UITextFieldDidEndEditingReasonCommitted };
NS_SWIFT_UI_ACTOR
@protocol UITextFieldDelegate <NSObject>
@optional
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField;
- (void)textFieldDidBeginEditing:(UITextField *)textField;
- (BOOL)textFieldShouldEndEditing:(UITextField *)textField;
- (void)textFieldDidEndEditing:(UITextField *)textField;
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string;
- (void)textFieldDidChangeSelection:(UITextField *)textField;
- (BOOL)textFieldShouldClear:(UITextField *)textField;
- (BOOL)textFieldShouldReturn:(UITextField *)textField;
@end
/* isim: the caret is always at the end of the text (no selection or cursor movement yet). */
@interface UITextField : UIControl <UITextInput>
@property (nullable, nonatomic, copy) NSString *text;
@property (nullable, nonatomic, copy) NSString *placeholder;
@property (nullable, nonatomic, strong) UIFont *font;
@property (nullable, nonatomic, strong) UIColor *textColor;
@property (nonatomic) NSTextAlignment textAlignment;
@property (nonatomic) UITextBorderStyle borderStyle;
@property (nonatomic) UITextFieldViewMode clearButtonMode;
@property (nonatomic) BOOL clearsOnBeginEditing;
@property (nonatomic) BOOL adjustsFontSizeToFitWidth;
@property (nonatomic) CGFloat minimumFontSize;
@property (nullable, nonatomic, weak) id <UITextFieldDelegate> delegate;
@property (nonatomic, readonly, getter=isEditing) BOOL editing;
@property (nullable, nonatomic, strong) UIView *leftView, *rightView;
@property (nonatomic) UITextFieldViewMode leftViewMode, rightViewMode;
@property (nullable, readwrite, strong) UIView *inputView;
@property (nullable, readwrite, strong) UIView *inputAccessoryView;
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property (nonatomic) UITextAutocorrectionType autocorrectionType;
@property (nonatomic) UITextSpellCheckingType spellCheckingType;
@property (nonatomic) UIKeyboardType keyboardType;
@property (nonatomic) UIKeyboardAppearance keyboardAppearance;
@property (nonatomic) UIReturnKeyType returnKeyType;
@property (nonatomic) BOOL enablesReturnKeyAutomatically;
@property (nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@property (null_unspecified, nonatomic, copy) UITextContentType textContentType;
@property (nullable, nonatomic, copy) UITextInputPasswordRules *passwordRules;
@property (nonatomic) UITextInlinePredictionType inlinePredictionType;
/* isim private: multi-line editing (wraps; height between min and max lines, max 0 = unlimited); used by SwiftUI */
- (void)_isim_setLineLimitMin:(NSInteger)minLines max:(NSInteger)maxLines;
@end
UIKIT_EXTERN NSNotificationName const UITextFieldTextDidBeginEditingNotification, UITextFieldTextDidEndEditingNotification, UITextFieldTextDidChangeNotification;
NS_ASSUME_NONNULL_END
