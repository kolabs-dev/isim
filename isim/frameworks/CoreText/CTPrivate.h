// isim CoreText private: font/descriptor classes and the attributed-string -> Pango markup conversion.
#pragma once
#import <Foundation/Foundation.h>
#include <CoreText/CoreText.h>

@interface __NSCTFont : NSObject
@property (copy) NSString *name, *family;
@property CGFloat size, weight;
@property BOOL bold, italic, mono;
@property (copy) NSArray *features;
@end
@interface __NSCTFontDescriptor : NSObject
@property (copy) NSDictionary *attributes;
@end
/* markup of an attributed string (default font: 12pt system). align: CTTextAlignment of the first paragraph style
 * (pango: 0 left 1 center 2 right 3 justify); colorFromContext: kCTForegroundColorFromContextAttributeName was set */
NSString *isim_ct_markup(NSAttributedString *s, int *align, double *spacing, BOOL *colorFromContext);
