#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UITextAutocapitalizationType) { UITextAutocapitalizationTypeNone, UITextAutocapitalizationTypeWords, UITextAutocapitalizationTypeSentences, UITextAutocapitalizationTypeAllCharacters };
typedef NS_ENUM(NSInteger, UITextAutocorrectionType) { UITextAutocorrectionTypeDefault, UITextAutocorrectionTypeNo, UITextAutocorrectionTypeYes };
typedef NS_ENUM(NSInteger, UITextSpellCheckingType) { UITextSpellCheckingTypeDefault, UITextSpellCheckingTypeNo, UITextSpellCheckingTypeYes };
typedef NS_ENUM(NSInteger, UIKeyboardType) {
    UIKeyboardTypeDefault, UIKeyboardTypeASCIICapable, UIKeyboardTypeNumbersAndPunctuation, UIKeyboardTypeURL, UIKeyboardTypeNumberPad,
    UIKeyboardTypePhonePad, UIKeyboardTypeNamePhonePad, UIKeyboardTypeEmailAddress, UIKeyboardTypeDecimalPad, UIKeyboardTypeTwitter,
    UIKeyboardTypeWebSearch, UIKeyboardTypeASCIICapableNumberPad
};
typedef NS_ENUM(NSInteger, UIKeyboardAppearance) { UIKeyboardAppearanceDefault, UIKeyboardAppearanceDark, UIKeyboardAppearanceLight };
typedef NS_ENUM(NSInteger, UIReturnKeyType) { UIReturnKeyDefault, UIReturnKeyGo, UIReturnKeyGoogle, UIReturnKeyJoin, UIReturnKeyNext, UIReturnKeyRoute, UIReturnKeySearch, UIReturnKeySend, UIReturnKeyYahoo, UIReturnKeyDone, UIReturnKeyEmergencyCall, UIReturnKeyContinue };
typedef NSString *UITextContentType NS_TYPED_ENUM;

@protocol UITextInputTraits <NSObject>
@optional
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property (nonatomic) UITextAutocorrectionType autocorrectionType;
@property (nonatomic) UITextSpellCheckingType spellCheckingType;
@property (nonatomic) UIKeyboardType keyboardType;
@property (nonatomic) UIKeyboardAppearance keyboardAppearance;
@property (nonatomic) UIReturnKeyType returnKeyType;
@property (nonatomic) BOOL enablesReturnKeyAutomatically;
@property (nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@property (null_unspecified, nonatomic, copy) UITextContentType textContentType;
@end
@protocol UIKeyInput <UITextInputTraits>
@property (nonatomic, readonly) BOOL hasText;
- (void)insertText:(NSString *)text;
- (void)deleteBackward;
@end
/* isim: the text-range/position half of UITextInput is not implemented. */
@protocol UITextInput <UIKeyInput>
@end
@class UITextInputMode;
@protocol UITextDocumentProxy <UIKeyInput>
@property (nullable, nonatomic, readonly) NSString *documentContextBeforeInput;
@property (nullable, nonatomic, readonly) NSString *documentContextAfterInput;
@property (nullable, nonatomic, readonly) NSString *selectedText;
@property (nullable, nonatomic, readonly) UITextInputMode *documentInputMode;
- (void)adjustTextPositionByCharacterOffset:(NSInteger)offset;
- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange;
- (void)unmarkText;
@end
@protocol UITextInputDelegate <NSObject>
- (void)selectionWillChange:(nullable id <UITextInput>)textInput;
- (void)selectionDidChange:(nullable id <UITextInput>)textInput;
- (void)textWillChange:(nullable id <UITextInput>)textInput;
- (void)textDidChange:(nullable id <UITextInput>)textInput;
@end
@interface UITextInputMode : NSObject
@property (nullable, nonatomic, readonly, strong) NSString *primaryLanguage;
@property (class, nonatomic, readonly) NSArray<UITextInputMode *> *activeInputModes;
@end
NS_ASSUME_NONNULL_END
