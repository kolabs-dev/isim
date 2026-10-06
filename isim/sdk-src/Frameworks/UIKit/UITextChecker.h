#pragma once
/* isim: UITextChecker over small built-in word lists (en, pt, es, fr, de). A word counts as misspelled when it is not
   in the list (nor learned) and is one edit (insertion, deletion, substitution, transposition) away from a listed
   word: unknown words with no close match are left alone. Guesses are those close matches; completions are listed
   words with the given prefix. Learned and ignored words persist in the device data like on iOS (per app). */
#import <UIKit/UIKitDefines.h>
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_UI_ACTOR
@interface UITextChecker : NSObject
- (NSRange)rangeOfMisspelledWordInString:(NSString *)stringToCheck range:(NSRange)range startingAt:(NSInteger)startingOffset wrap:(BOOL)wrapFlag language:(NSString *)language;
- (nullable NSArray<NSString *> *)guessesForWordRange:(NSRange)range inString:(NSString *)string language:(NSString *)language;
- (nullable NSArray<NSString *> *)completionsForPartialWordRange:(NSRange)range inString:(nullable NSString *)string language:(NSString *)language;
- (void)ignoreWord:(NSString *)wordToIgnore;
@property (nullable, nonatomic, copy) NSArray<NSString *> *ignoredWords;
+ (void)learnWord:(NSString *)word;
+ (BOOL)hasLearnedWord:(NSString *)word;
+ (void)unlearnWord:(NSString *)word;
@property (class, nonatomic, readonly) NSArray<NSString *> *availableLanguages;
@end
NS_ASSUME_NONNULL_END
