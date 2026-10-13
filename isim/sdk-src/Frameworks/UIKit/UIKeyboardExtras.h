#pragma once
/* isim: keyboard members from the documentation sweep (#9): input view click sounds, the supplementary lexicon of
   custom keyboards, grammar checking. UIKeyboardExtras.m. */
#import <UIKit/UIInputViewController.h>
#import <UIKit/UITextChecker.h>
NS_ASSUME_NONNULL_BEGIN

/* an input view (or accessory) that plays clicks: UIDevice.playInputClick() clicks while it is shown (isim logs
   "isim: input click"; there is no keyboard sound) */
NS_SWIFT_UI_ACTOR
@protocol UIInputViewAudioFeedback <NSObject>
@optional
@property (nonatomic, readonly) BOOL enableInputClicksWhenVisible;
@end

/* words a custom keyboard may suggest: text replacements (adapted: iOS's default "omw" → "On my way!") */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(8.0))
@interface UILexiconEntry : NSObject <NSCopying>
@property (nonatomic, readonly) NSString *documentText;
@property (nonatomic, readonly) NSString *userInput;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(8.0))
@interface UILexicon : NSObject <NSCopying>
@property (nonatomic, readonly) NSArray<UILexiconEntry *> *entries;
@end
@interface UIInputViewController (UILexicon)
- (void)requestSupplementaryLexiconWithCompletion:(void (^)(UILexicon *lexicon))completionHandler NS_SWIFT_NAME(requestSupplementaryLexicon(completion:));
@end

/* grammar checking (adapted: a repeated word, "a" before a vowel sound, a lowercase "i", a sentence starting in
   lowercase) */
@interface UITextChecker (IsimGrammar)
- (void)requestGrammarCheckingOfString:(NSString *)stringToCheck range:(NSRange)range waitForAllResults:(BOOL)waitForAllResults
                     completionHandler:(nullable void (^)(NSArray<NSTextCheckingResult *> *results))completionHandler
    NS_SWIFT_NAME(requestGrammarChecking(of:range:waitForAllResults:completionHandler:)) API_AVAILABLE(ios(26.0));
- (void)ignoreGrammarRange:(NSRange)grammarRange inSentence:(NSString *)sentence NS_SWIFT_NAME(ignoreGrammarRange(_:inSentence:)) API_AVAILABLE(ios(26.0));
@end
NS_ASSUME_NONNULL_END
