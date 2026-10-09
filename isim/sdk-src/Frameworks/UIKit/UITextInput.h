#pragma once
#import <UIKit/UIKitDefines.h>
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#import <UIKit/NSAttributedString.h>     /* NSWritingDirection */
NS_ASSUME_NONNULL_BEGIN
@class UIResponder, UIView;
typedef NS_ENUM(NSInteger, UITextAutocapitalizationType) { UITextAutocapitalizationTypeNone, UITextAutocapitalizationTypeWords, UITextAutocapitalizationTypeSentences, UITextAutocapitalizationTypeAllCharacters };
typedef NS_ENUM(NSInteger, UITextAutocorrectionType) { UITextAutocorrectionTypeDefault, UITextAutocorrectionTypeNo, UITextAutocorrectionTypeYes };
typedef NS_ENUM(NSInteger, UITextSpellCheckingType) { UITextSpellCheckingTypeDefault, UITextSpellCheckingTypeNo, UITextSpellCheckingTypeYes };
typedef NS_ENUM(NSInteger, UITextSmartQuotesType) { UITextSmartQuotesTypeDefault, UITextSmartQuotesTypeNo, UITextSmartQuotesTypeYes };
typedef NS_ENUM(NSInteger, UITextSmartDashesType) { UITextSmartDashesTypeDefault, UITextSmartDashesTypeNo, UITextSmartDashesTypeYes };
typedef NS_ENUM(NSInteger, UITextSmartInsertDeleteType) { UITextSmartInsertDeleteTypeDefault, UITextSmartInsertDeleteTypeNo, UITextSmartInsertDeleteTypeYes };
typedef NS_ENUM(NSInteger, UITextInlinePredictionType) { UITextInlinePredictionTypeDefault, UITextInlinePredictionTypeNo, UITextInlinePredictionTypeYes };
typedef NS_ENUM(NSInteger, UIKeyboardType) {
    UIKeyboardTypeDefault, UIKeyboardTypeASCIICapable, UIKeyboardTypeNumbersAndPunctuation, UIKeyboardTypeURL, UIKeyboardTypeNumberPad,
    UIKeyboardTypePhonePad, UIKeyboardTypeNamePhonePad, UIKeyboardTypeEmailAddress, UIKeyboardTypeDecimalPad, UIKeyboardTypeTwitter,
    UIKeyboardTypeWebSearch, UIKeyboardTypeASCIICapableNumberPad
};
typedef NS_ENUM(NSInteger, UIKeyboardAppearance) { UIKeyboardAppearanceDefault, UIKeyboardAppearanceDark, UIKeyboardAppearanceLight };
typedef NS_ENUM(NSInteger, UIReturnKeyType) { UIReturnKeyDefault, UIReturnKeyGo, UIReturnKeyGoogle, UIReturnKeyJoin, UIReturnKeyNext, UIReturnKeyRoute, UIReturnKeySearch, UIReturnKeySend, UIReturnKeyYahoo, UIReturnKeyDone, UIReturnKeyEmergencyCall, UIReturnKeyContinue };
typedef NSString *UITextContentType NS_TYPED_ENUM;
/* textContentType values. isim's AutoFill (UITextServices.m) acts on Username, EmailAddress, Password, NewPassword and
   OneTimeCode; the others are stored. */
UIKIT_EXTERN UITextContentType const UITextContentTypeName;
UIKIT_EXTERN UITextContentType const UITextContentTypeNamePrefix;
UIKIT_EXTERN UITextContentType const UITextContentTypeGivenName;
UIKIT_EXTERN UITextContentType const UITextContentTypeMiddleName;
UIKIT_EXTERN UITextContentType const UITextContentTypeFamilyName;
UIKIT_EXTERN UITextContentType const UITextContentTypeNameSuffix;
UIKIT_EXTERN UITextContentType const UITextContentTypeNickname;
UIKIT_EXTERN UITextContentType const UITextContentTypeJobTitle;
UIKIT_EXTERN UITextContentType const UITextContentTypeOrganizationName;
UIKIT_EXTERN UITextContentType const UITextContentTypeLocation;
UIKIT_EXTERN UITextContentType const UITextContentTypeFullStreetAddress;
UIKIT_EXTERN UITextContentType const UITextContentTypeStreetAddressLine1;
UIKIT_EXTERN UITextContentType const UITextContentTypeStreetAddressLine2;
UIKIT_EXTERN UITextContentType const UITextContentTypeAddressCity;
UIKIT_EXTERN UITextContentType const UITextContentTypeAddressState;
UIKIT_EXTERN UITextContentType const UITextContentTypeAddressCityAndState;
UIKIT_EXTERN UITextContentType const UITextContentTypeSublocality;
UIKIT_EXTERN UITextContentType const UITextContentTypeCountryName;
UIKIT_EXTERN UITextContentType const UITextContentTypePostalCode;
UIKIT_EXTERN UITextContentType const UITextContentTypeTelephoneNumber;
UIKIT_EXTERN UITextContentType const UITextContentTypeEmailAddress;
UIKIT_EXTERN UITextContentType const UITextContentTypeURL;
UIKIT_EXTERN UITextContentType const UITextContentTypeCreditCardNumber;
UIKIT_EXTERN UITextContentType const UITextContentTypeUsername;
UIKIT_EXTERN UITextContentType const UITextContentTypePassword;
UIKIT_EXTERN UITextContentType const UITextContentTypeNewPassword;
UIKIT_EXTERN UITextContentType const UITextContentTypeOneTimeCode;
UIKIT_EXTERN UITextContentType const UITextContentTypeShipmentTrackingNumber;
UIKIT_EXTERN UITextContentType const UITextContentTypeFlightNumber;
UIKIT_EXTERN UITextContentType const UITextContentTypeDateTime;
UIKIT_EXTERN UITextContentType const UITextContentTypeBirthdate;
UIKIT_EXTERN UITextContentType const UITextContentTypeBirthdateDay;
UIKIT_EXTERN UITextContentType const UITextContentTypeBirthdateMonth;
UIKIT_EXTERN UITextContentType const UITextContentTypeBirthdateYear;
UIKIT_EXTERN UITextContentType const UITextContentTypeCreditCardSecurityCode;
UIKIT_EXTERN UITextContentType const UITextContentTypeCreditCardName;
UIKIT_EXTERN UITextContentType const UITextContentTypeCreditCardGivenName;
UIKIT_EXTERN UITextContentType const UITextContentTypeCreditCardMiddleName;
UIKIT_EXTERN UITextContentType const UITextContentTypeCreditCardFamilyName;
UIKIT_EXTERN UITextContentType const UITextContentTypeCreditCardExpiration;
UIKIT_EXTERN UITextContentType const UITextContentTypeCreditCardExpirationMonth;
UIKIT_EXTERN UITextContentType const UITextContentTypeCreditCardExpirationYear;
UIKIT_EXTERN UITextContentType const UITextContentTypeCreditCardType;
UIKIT_EXTERN UITextContentType const UITextContentTypeCellularEID;
UIKIT_EXTERN UITextContentType const UITextContentTypeCellularIMEI;
/* Password rules for strong-password suggestions ("required: lower; required: digit; minlength: 20; ...") */
NS_SWIFT_UI_ACTOR
@interface UITextInputPasswordRules : NSObject <NSSecureCoding, NSCopying>
@property (nonatomic, readonly) NSString *passwordRulesDescriptor;
+ (instancetype)passwordRulesWithDescriptor:(NSString *)passwordRulesDescriptor;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_SWIFT_UI_ACTOR
@protocol UITextInputTraits <NSObject>
@optional
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property (nonatomic) UITextAutocorrectionType autocorrectionType;
@property (nonatomic) UITextSpellCheckingType spellCheckingType;
@property (nonatomic) UITextSmartQuotesType smartQuotesType;
@property (nonatomic) UITextSmartDashesType smartDashesType;
@property (nonatomic) UITextSmartInsertDeleteType smartInsertDeleteType;
@property (nonatomic) UITextInlinePredictionType inlinePredictionType;
@property (nonatomic) UIKeyboardType keyboardType;
@property (nonatomic) UIKeyboardAppearance keyboardAppearance;
@property (nonatomic) UIReturnKeyType returnKeyType;
@property (nonatomic) BOOL enablesReturnKeyAutomatically;
@property (nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@property (null_unspecified, nonatomic, copy) UITextContentType textContentType;
@property (nullable, nonatomic, copy) UITextInputPasswordRules *passwordRules;
@end
NS_SWIFT_UI_ACTOR
@protocol UIKeyInput <UITextInputTraits>
@property (nonatomic, readonly) BOOL hasText;
- (void)insertText:(NSString *)text;
- (void)deleteBackward;
@end

/* ---- positions and ranges (opaque; isim's text views use character offsets) ---- */
typedef NS_ENUM(NSInteger, UITextStorageDirection) { UITextStorageDirectionForward = 0, UITextStorageDirectionBackward };
typedef NS_ENUM(NSInteger, UITextLayoutDirection) { UITextLayoutDirectionRight = 2, UITextLayoutDirectionLeft, UITextLayoutDirectionUp, UITextLayoutDirectionDown };
typedef NSInteger UITextDirection NS_TYPED_ENUM;
typedef NS_ENUM(NSInteger, UITextGranularity) { UITextGranularityCharacter, UITextGranularityWord, UITextGranularitySentence, UITextGranularityParagraph, UITextGranularityLine, UITextGranularityDocument };
typedef NS_ENUM(NSInteger, UITextAlternativeStyle) { UITextAlternativeStyleNone, UITextAlternativeStyleLowConfidence };
NS_SWIFT_UI_ACTOR
@interface UITextPosition : NSObject
@end
NS_SWIFT_UI_ACTOR
@interface UITextRange : NSObject
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;
@property (nonatomic, readonly) UITextPosition *start;
@property (nonatomic, readonly) UITextPosition *end;
@end
NS_SWIFT_UI_ACTOR
@interface UITextSelectionRect : NSObject
@property (nonatomic, readonly) CGRect rect;
@property (nonatomic, readonly) NSWritingDirection writingDirection;
@property (nonatomic, readonly) BOOL containsStart;
@property (nonatomic, readonly) BOOL containsEnd;
@property (nonatomic, readonly) BOOL isVertical;
@end

@protocol UITextInput, UITextInputTokenizer;
/* Dictation (isim: the text comes from the script command `dictate TEXT`; there is no speech recognition) */
NS_SWIFT_UI_ACTOR
@interface UIDictationPhrase : NSObject
@property (nonatomic, readonly) NSString *text;
@property (nullable, nonatomic, readonly) NSArray<NSString *> *alternativeInterpretations;
@end
NS_SWIFT_UI_ACTOR
@protocol UITextInputDelegate <NSObject>
- (void)selectionWillChange:(nullable id <UITextInput>)textInput;
- (void)selectionDidChange:(nullable id <UITextInput>)textInput;
- (void)textWillChange:(nullable id <UITextInput>)textInput;
- (void)textDidChange:(nullable id <UITextInput>)textInput;
@end

/* isim: UITextField and UITextView implement UITextInput over character offsets; the host IME's composition
   becomes marked text (setMarkedText:selectedRange:), the script command `compose TEXT` too. */
NS_SWIFT_UI_ACTOR
@protocol UITextInput <UIKeyInput>
@required
- (nullable NSString *)textInRange:(UITextRange *)range;
- (void)replaceRange:(UITextRange *)range withText:(NSString *)text;
@property (nullable, readwrite, copy) UITextRange *selectedTextRange;
@property (nullable, nonatomic, readonly) UITextRange *markedTextRange;
@property (nullable, nonatomic, copy) NSDictionary<NSAttributedStringKey, id> *markedTextStyle;
- (void)setMarkedText:(nullable NSString *)markedText selectedRange:(NSRange)selectedRange;
- (void)unmarkText;
@property (nonatomic, readonly) UITextPosition *beginningOfDocument;
@property (nonatomic, readonly) UITextPosition *endOfDocument;
- (nullable UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition;
- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset;
- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction offset:(NSInteger)offset;
- (NSComparisonResult)comparePosition:(UITextPosition *)position toPosition:(UITextPosition *)other;
- (NSInteger)offsetFromPosition:(UITextPosition *)from toPosition:(UITextPosition *)toPosition;
@property (nullable, nonatomic, weak) id <UITextInputDelegate> inputDelegate;
@property (nonatomic, readonly) id <UITextInputTokenizer> tokenizer;
- (nullable UITextPosition *)positionWithinRange:(UITextRange *)range farthestInDirection:(UITextLayoutDirection)direction;
- (nullable UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction;
- (NSWritingDirection)baseWritingDirectionForPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction;
- (void)setBaseWritingDirection:(NSWritingDirection)writingDirection forRange:(UITextRange *)range;
- (CGRect)firstRectForRange:(UITextRange *)range;
- (CGRect)caretRectForPosition:(UITextPosition *)position;
- (NSArray<UITextSelectionRect *> *)selectionRectsForRange:(UITextRange *)range;
- (nullable UITextPosition *)closestPositionToPoint:(CGPoint)point;
- (nullable UITextPosition *)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange *)range;
- (nullable UITextRange *)characterRangeAtPoint:(CGPoint)point;
@optional
- (BOOL)shouldChangeTextInRange:(UITextRange *)range replacementText:(NSString *)text;
- (nullable NSDictionary<NSAttributedStringKey, id> *)textStylingAtPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction;
- (nullable UITextPosition *)positionWithinRange:(UITextRange *)range atCharacterOffset:(NSInteger)offset;
- (NSInteger)characterOffsetOfPosition:(UITextPosition *)position withinRange:(UITextRange *)range;
@property (nonatomic, readonly) __kindof UIView *textInputView;
- (void)insertText:(NSString *)text alternatives:(NSArray<NSString *> *)alternatives style:(UITextAlternativeStyle)style;
- (void)setAttributedMarkedText:(nullable NSAttributedString *)markedText selectedRange:(NSRange)selectedRange;
- (void)beginFloatingCursorAtPoint:(CGPoint)point;
- (void)updateFloatingCursorAtPoint:(CGPoint)point;
- (void)endFloatingCursor;
- (void)insertDictationResult:(NSArray<UIDictationPhrase *> *)dictationResult;
- (void)dictationRecordingDidEnd;
- (void)dictationRecognitionFailed;
@property (nonatomic, readonly) id insertDictationResultPlaceholder;
- (CGRect)frameForDictationResultPlaceholder:(id)placeholder;
- (void)removeDictationResultPlaceholder:(id)placeholder willInsertResult:(BOOL)willInsertResult;
@end

/* ---- tokenizers ---- */
NS_SWIFT_UI_ACTOR
@protocol UITextInputTokenizer <NSObject>
@required
- (nullable UITextRange *)rangeEnclosingPosition:(UITextPosition *)position withGranularity:(UITextGranularity)granularity inDirection:(UITextDirection)direction;
- (BOOL)isPosition:(UITextPosition *)position atBoundary:(UITextGranularity)granularity inDirection:(UITextDirection)direction;
- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position toBoundary:(UITextGranularity)granularity inDirection:(UITextDirection)direction;
- (BOOL)isPosition:(UITextPosition *)position withinTextUnit:(UITextGranularity)granularity inDirection:(UITextDirection)direction;
@end
NS_SWIFT_UI_ACTOR
@interface UITextInputStringTokenizer : NSObject <UITextInputTokenizer>
- (instancetype)initWithTextInput:(UIResponder <UITextInput> *)textInput;
@end

@class UITextInputMode;
NS_SWIFT_UI_ACTOR
@protocol UITextDocumentProxy <UIKeyInput>
@property (nullable, nonatomic, readonly) NSString *documentContextBeforeInput;
@property (nullable, nonatomic, readonly) NSString *documentContextAfterInput;
@property (nullable, nonatomic, readonly) NSString *selectedText;
@property (nullable, nonatomic, readonly) UITextInputMode *documentInputMode;
- (void)adjustTextPositionByCharacterOffset:(NSInteger)offset;
- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange;
- (void)unmarkText;
@end
/* isim: one input mode per keyboard enabled in Settings > General > Keyboard > Keyboards (en-US, pt-BR, es-ES,
   fr-FR, de-DE, emoji) */
NS_SWIFT_UI_ACTOR
@interface UITextInputMode : NSObject
@property (nullable, nonatomic, readonly, strong) NSString *primaryLanguage;
@property (class, nonatomic, readonly) NSArray<UITextInputMode *> *activeInputModes;
@end
UIKIT_EXTERN NSNotificationName const UITextInputCurrentInputModeDidChangeNotification;
NS_ASSUME_NONNULL_END
