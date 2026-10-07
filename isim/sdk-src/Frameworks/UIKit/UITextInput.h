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
