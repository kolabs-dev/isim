/* Keyboard members from the documentation sweep (#9): input clicks, the supplementary lexicon, grammar checking. */
#import "UIKitPrivate.h"
#import <UIKit/UIKeyboardExtras.h>
#import <objc/runtime.h>

@interface UILexiconEntry ()
@property (nonatomic, copy) NSString *documentText, *userInput;
@end
@implementation UILexiconEntry
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@interface UILexicon ()
@property (nonatomic, copy) NSArray<UILexiconEntry *> *entries;
@end
@implementation UILexicon
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation UIInputViewController (UILexicon)
- (void)requestSupplementaryLexiconWithCompletion:(void (^)(UILexicon *))completion {
    UILexiconEntry *omw = [UILexiconEntry new]; omw.userInput = @"omw"; omw.documentText = @"On my way!";
    UILexicon *l = [UILexicon new]; l.entries = @[ omw ];
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(l); });
}
@end

/* UIDevice.playInputClick(): a click when the first responder's input view (or accessory) asks for them */
BOOL isim_ui_input_clicks_enabled(void) {
    UIResponder *r = isim_ui_first_responder();
    for (NSString *k in @[ @"inputView", @"inputAccessoryView" ]) {
        id v = [r respondsToSelector:NSSelectorFromString(k)] ? [r valueForKey:k] : nil;
        if ([v conformsToProtocol:@protocol(UIInputViewAudioFeedback)] && [v respondsToSelector:@selector(enableInputClicksWhenVisible)] && [v enableInputClicksWhenVisible] && [v window]) return YES;
    }
    return NO;
}

/* ---- grammar ---- */
static char kIgnored;
static NSDictionary *detail(NSRange r, NSString *desc, NSArray *fix) { return @{ NSGrammarRange: [NSValue valueWithRange:r], NSGrammarUserDescription: desc, NSGrammarCorrections: fix }; }
@implementation UITextChecker (IsimGrammar)
- (void)ignoreGrammarRange:(NSRange)r inSentence:(NSString *)sentence {
    NSMutableSet *s = objc_getAssociatedObject(self, &kIgnored) ?: [NSMutableSet set];
    if (NSMaxRange(r) <= sentence.length) [s addObject:[sentence substringWithRange:r].lowercaseString];
    objc_setAssociatedObject(self, &kIgnored, s, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)requestGrammarCheckingOfString:(NSString *)str range:(NSRange)range waitForAllResults:(BOOL)wait completionHandler:(void (^)(NSArray *))done {
    NSMutableArray *out = [NSMutableArray array];
    NSSet *ignored = objc_getAssociatedObject(self, &kIgnored);
    if (NSMaxRange(range) > str.length) range = NSMakeRange(0, str.length);
    struct { NSString *pattern, *desc; int kind; } rules[] = {
        { @"\\b(\\w+)\\s+\\1\\b", @"This word is repeated.", 0 },
        { @"\\b[Aa]\\s+(?=[aeiouAEIOU]\\w)", @"Use “an” before a vowel sound.", 1 },
        { @"(?<![\\w'])i(?![\\w'])", @"“I” is capitalized.", 2 },
        { @"(?:^|[.!?]\\s+)([a-z])", @"A sentence starts with a capital letter.", 3 } };
    for (size_t i = 0; i < sizeof rules / sizeof *rules; i++) {
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:rules[i].pattern options:0 error:NULL];
        for (NSTextCheckingResult *m in [re matchesInString:str options:0 range:range]) {
            NSRange r = rules[i].kind == 3 ? [m rangeAtIndex:1] : rules[i].kind == 1 ? NSMakeRange(m.range.location, 1) : m.range;
            NSString *text = [str substringWithRange:r];
            if ([ignored containsObject:text.lowercaseString]) continue;
            BOOL overlaps = NO;                         /* one problem per place: the first rule's */
            for (NSTextCheckingResult *o in out) if (NSIntersectionRange(o.range, r).length) overlaps = YES;
            if (overlaps) continue;
            NSArray *fix = rules[i].kind == 0 ? @[ [str substringWithRange:[m rangeAtIndex:1]] ] : rules[i].kind == 1 ? @[ [text isEqualToString:@"A"] ? @"An" : @"an" ]
                         : @[ text.uppercaseString ];
            [out addObject:[NSTextCheckingResult grammarCheckingResultWithRange:r details:@[ detail(NSMakeRange(0, r.length), rules[i].desc, fix) ]]];
        }
    }
    [out sortUsingComparator:^NSComparisonResult(NSTextCheckingResult *a, NSTextCheckingResult *b) { return a.range.location < b.range.location ? NSOrderedAscending : a.range.location > b.range.location ? NSOrderedDescending : NSOrderedSame; }];
    if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(out); });
}
@end
