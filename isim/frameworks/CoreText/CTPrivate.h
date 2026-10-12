// isim CoreText private: font/descriptor/paragraph-style classes and the attributed-string -> Pango markup conversion.
#pragma once
#import <Foundation/Foundation.h>
#include <CoreText/CoreText.h>
#include <isim_host_cg.h>

/* stretch: Pango's (0 ultra-condensed, 4 normal, 8 ultra-expanded) */
@interface __NSCTFont : NSObject
@property (copy) NSString *name, *family;
@property CGFloat size, weight;
@property BOOL bold, italic, mono;
@property int stretch;
@property (copy) NSArray *features;
/* the host font (a PangoFont), loaded on first use; info: its metrics and names */
- (void *)host;
- (const struct isim_ct_font_info *)info;
@end
@interface __NSCTFontDescriptor : NSObject
@property (copy) NSDictionary *attributes;
@end
/* a CTFont for a font object: a CTFont itself, or a UIFont (toll-free bridged on iOS) */
__NSCTFont *isim_ct_font(id f);
/* the Pango family list for a font: its family, monospace, or NULL for the system font */
NSString *isim_ct_family(__NSCTFont *f);
int isim_ct_pango_weight(CGFloat weight);
/* a CTFont for a host font (a run's fallback font) */
__NSCTFont *isim_ct_font_from_host(const char *family, int pango_weight, int italic, int stretch, double size);

/* the Pango font_features of feature settings (OpenType tags, AAT type/selector pairs) */
NSString *isim_ct_feature_tags(NSArray *features);

/* paragraph settings, from a CTParagraphStyle or a UIKit NSParagraphStyle */
typedef struct {
    CTTextAlignment align;
    CTLineBreakMode lineBreak;
    CTWritingDirection dir;
    CGFloat firstHead, head, tail, defaultTab, lineHeightMultiple, maxLineHeight, minLineHeight, lineSpacing,
            paraSpacing, paraBefore, maxLineSpacing, minLineSpacing, lineSpacingAdjust;
    CTLineBoundsOptions boundsOptions;
    BOOL hasLineSpacing;
    __unsafe_unretained NSArray *tabs;          /* CTTextTabs (kept alive by the style object) */
} isim_ct_pstyle;
void isim_ct_pstyle_of(id style, isim_ct_pstyle *out);

/* markup of an attributed string (default font: 12pt system); colorFromContext: kCTForegroundColorFromContextAttributeName was set */
NSString *isim_ct_markup(NSAttributedString *s, BOOL *colorFromContext);
