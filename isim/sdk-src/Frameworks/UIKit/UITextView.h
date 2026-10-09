#pragma once
/* isim: UITextView — editable, scrollable multi-line plain text. Not editable and selectable, it shows the
   dataDetectorTypes it finds (links, phone numbers, addresses, dates) as tappable links (UITextServices.m). */
#import <UIKit/UIScrollView.h>
#import <UIKit/UITextInput.h>
NS_ASSUME_NONNULL_BEGIN
@class UITextView, UIFont, UIColor, UIAction, UIMenu, UIMenuElement;

typedef NS_OPTIONS(NSUInteger, UIDataDetectorTypes) {
    UIDataDetectorTypePhoneNumber = 1 << 0, UIDataDetectorTypeLink = 1 << 1, UIDataDetectorTypeAddress = 1 << 2,
    UIDataDetectorTypeCalendarEvent = 1 << 3, UIDataDetectorTypeShipmentTrackingNumber = 1 << 4,
    UIDataDetectorTypeFlightNumber = 1 << 5, UIDataDetectorTypeLookupSuggestion = 1 << 6,
    UIDataDetectorTypeNone = 0, UIDataDetectorTypeAll = NSUIntegerMax
};

typedef NS_ENUM(NSInteger, UITextItemInteraction) {
    UITextItemInteractionInvokeDefaultAction = 0, UITextItemInteractionPresentActions = 1, UITextItemInteractionPreview = 2
};
typedef NS_ENUM(NSInteger, UITextItemContentType) { UITextItemContentTypeLink = 0, UITextItemContentTypeTextAttachment = 1, UITextItemContentTypeTag = 2 };
/* a detected item (or link) the user acted on (iOS 17) */
NS_SWIFT_UI_ACTOR
@interface UITextItem : NSObject
@property (nonatomic, readonly) UITextItemContentType contentType NS_REFINED_FOR_SWIFT;     /* Swift: content */
@property (nonatomic, readonly) NSRange range;
@property (nullable, nonatomic, readonly) NSURL *link NS_REFINED_FOR_SWIFT;
@property (nullable, nonatomic, readonly) NSString *tagIdentifier NS_REFINED_FOR_SWIFT;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(UITextItem.MenuConfiguration)
@interface UITextItemMenuConfiguration : NSObject
+ (instancetype)configurationWithMenu:(UIMenu *)menu;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_SWIFT_UI_ACTOR
@protocol UITextViewDelegate <NSObject, UIScrollViewDelegate>
@optional
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView;
- (BOOL)textViewShouldEndEditing:(UITextView *)textView;
- (void)textViewDidBeginEditing:(UITextView *)textView;
- (void)textViewDidEndEditing:(UITextView *)textView;
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
- (void)textViewDidChange:(UITextView *)textView;
- (void)textViewDidChangeSelection:(UITextView *)textView;
/* detected items: a tap runs the primary action, a long press shows the menu */
- (nullable UIAction *)textView:(UITextView *)textView primaryActionForTextItem:(UITextItem *)textItem defaultAction:(UIAction *)defaultAction;
- (nullable UITextItemMenuConfiguration *)textView:(UITextView *)textView menuConfigurationForTextItem:(UITextItem *)textItem defaultMenu:(UIMenu *)defaultMenu;
- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange interaction:(UITextItemInteraction)interaction;
- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange;
@end

NS_SWIFT_UI_ACTOR
@interface UITextView : UIScrollView <UITextInput>
- (instancetype)initWithFrame:(CGRect)frame;
@property (nullable, nonatomic, weak) id<UITextViewDelegate> delegate;
@property (null_resettable, nonatomic, copy) NSString *text;
@property (nullable, nonatomic, strong) UIFont *font;
@property (nullable, nonatomic, strong) UIColor *textColor;
@property (nonatomic) NSTextAlignment textAlignment;
@property (nonatomic) NSRange selectedRange;
@property (nonatomic, getter=isEditable) BOOL editable;
@property (nonatomic, getter=isSelectable) BOOL selectable;
@property (nonatomic) UIDataDetectorTypes dataDetectorTypes;
@property (nonatomic) BOOL allowsEditingTextAttributes;
@property (nonatomic) BOOL clearsOnInsertion;
@property (nonatomic) UIEdgeInsets textContainerInset;
@property (nonatomic) BOOL adjustsFontForContentSizeCategory;
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
- (void)scrollRangeToVisible:(NSRange)range;
@end

@interface UIView (UITextFieldEditing)
/* resigns the first responder if it is this view or one of its subviews */
- (BOOL)endEditing:(BOOL)force;
@end

UIKIT_EXTERN NSNotificationName const UITextViewTextDidBeginEditingNotification NS_SWIFT_NAME(UITextView.textDidBeginEditingNotification);
UIKIT_EXTERN NSNotificationName const UITextViewTextDidChangeNotification NS_SWIFT_NAME(UITextView.textDidChangeNotification);
UIKIT_EXTERN NSNotificationName const UITextViewTextDidEndEditingNotification NS_SWIFT_NAME(UITextView.textDidEndEditingNotification);
NS_ASSUME_NONNULL_END
