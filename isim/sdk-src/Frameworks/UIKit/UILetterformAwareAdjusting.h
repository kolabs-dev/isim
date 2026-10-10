#pragma once
/* isim: letterform-aware sizing (iOS 17). UILabel with the oversize rule adds the ink of tall scripts (Thai, Arabic,
   Devanagari stacked marks, Tibetan) that reaches outside the line boxes to its size and draws the text inside it
   (adapted: measured with Pango's ink extents). UITextField and UITextView keep the rule (stored). */
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UILetterformAwareSizingRule) {
    UILetterformAwareSizingRuleTypographic,     /* the font's line metrics */
    UILetterformAwareSizingRuleOversize,        /* also room for glyphs that reach outside them */
} API_AVAILABLE(ios(17.0));
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@protocol UILetterformAwareAdjusting <NSObject>
@property (nonatomic) UILetterformAwareSizingRule sizingRule;
@end
NS_ASSUME_NONNULL_END
