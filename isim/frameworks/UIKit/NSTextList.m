/* Text tabs, text lists, list elements, adaptive image glyphs and Core Text alignment conversions (NSTextList.h,
 * NSAdaptiveImageGlyph.h, NSAttributedString.h). Tab stops are laid out by the TextKit engine (Pango tab arrays);
 * list markers are strings (markerForItemNumber:), drawn when a list element's string carries them. */
#import "UIKitPrivate.h"
#import <UIKit/NSTextList.h>
#import <UIKit/NSAdaptiveImageGlyph.h>
#import <UIKit/NSTextLayoutManager.h>

CTTextAlignment NSTextAlignmentToCTTextAlignment(NSTextAlignment a) {
    switch (a) {
    case NSTextAlignmentLeft: return kCTTextAlignmentLeft;
    case NSTextAlignmentRight: return kCTTextAlignmentRight;
    case NSTextAlignmentCenter: return kCTTextAlignmentCenter;
    case NSTextAlignmentJustified: return kCTTextAlignmentJustified;
    default: return kCTTextAlignmentNatural;
    }
}
NSTextAlignment NSTextAlignmentFromCTTextAlignment(CTTextAlignment a) {
    switch (a) {
    case kCTTextAlignmentLeft: return NSTextAlignmentLeft;
    case kCTTextAlignmentRight: return NSTextAlignmentRight;
    case kCTTextAlignmentCenter: return NSTextAlignmentCenter;
    case kCTTextAlignmentJustified: return NSTextAlignmentJustified;
    default: return NSTextAlignmentNatural;
    }
}

/* ================= tabs ================= */
NSTextTabOptionKey const NSTabColumnTerminatorsAttributeName = @"NSTabColumnTerminatorsAttributeName";
@implementation NSTextTab
+ (BOOL)supportsSecureCoding { return YES; }
+ (NSCharacterSet *)columnTerminatorsForLocale:(NSLocale *)locale {
    NSString *sep = [(locale ?: [NSLocale currentLocale]) objectForKey:NSLocaleDecimalSeparator] ?: @".";
    return [NSCharacterSet characterSetWithCharactersInString:sep];
}
- (instancetype)initWithTextAlignment:(NSTextAlignment)a location:(CGFloat)loc options:(NSDictionary *)options {
    if ((self = [super init])) { _alignment = a; _location = loc; _options = [options copy] ?: @{}; }
    return self;
}
- (instancetype)init { return [self initWithTextAlignment:NSTextAlignmentNatural location:0 options:@{}]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithTextAlignment:[c decodeIntegerForKey:@"alignment"] location:[c decodeDoubleForKey:@"location"]
                               options:[c decodeObjectForKey:@"options"] ?: @{}];
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeInteger:_alignment forKey:@"alignment"]; [c encodeDouble:_location forKey:@"location"]; [c encodeObject:_options forKey:@"options"];
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(NSTextTab *)o {
    return [o isKindOfClass:[NSTextTab class]] && o.alignment == _alignment && o.location == _location && [o.options isEqualToDictionary:_options];
}
- (NSUInteger)hash { return (NSUInteger)(_location * 31) + (NSUInteger)_alignment; }
- (NSString *)description { return [NSString stringWithFormat:@"<NSTextTab %g %ld>", _location, (long)_alignment]; }
@end

/* ================= lists ================= */
NSTextListMarkerFormat const NSTextListMarkerBox = @"{box}", NSTextListMarkerCheck = @"{check}", NSTextListMarkerCircle = @"{circle}",
    NSTextListMarkerDiamond = @"{diamond}", NSTextListMarkerDisc = @"{disc}", NSTextListMarkerHyphen = @"{hyphen}",
    NSTextListMarkerSquare = @"{square}", NSTextListMarkerLowercaseHexadecimal = @"{lower-hexadecimal}",
    NSTextListMarkerUppercaseHexadecimal = @"{upper-hexadecimal}", NSTextListMarkerOctal = @"{octal}",
    NSTextListMarkerLowercaseAlpha = @"{lower-alpha}", NSTextListMarkerUppercaseAlpha = @"{upper-alpha}",
    NSTextListMarkerLowercaseLatin = @"{lower-latin}", NSTextListMarkerUppercaseLatin = @"{upper-latin}",
    NSTextListMarkerLowercaseRoman = @"{lower-roman}", NSTextListMarkerUppercaseRoman = @"{upper-roman}",
    NSTextListMarkerDecimal = @"{decimal}";

static NSString *alpha(NSInteger n) {          /* 1 a ... 26 z, 27 aa */
    NSMutableString *s = [NSMutableString string];
    for (; n > 0; n = (n - 1) / 26) [s insertString:[NSString stringWithFormat:@"%c", (char)('a' + (n - 1) % 26)] atIndex:0];
    return s;
}
static NSString *roman(NSInteger n) {
    if (n <= 0 || n >= 4000) return [NSString stringWithFormat:@"%ld", (long)n];
    static const int v[] = { 1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1 };
    static const char *d[] = { "m", "cm", "d", "cd", "c", "xc", "l", "xl", "x", "ix", "v", "iv", "i" };
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < 13; i++) while (n >= v[i]) { [s appendFormat:@"%s", d[i]]; n -= v[i]; }
    return s;
}
/* the text a placeholder stands for (nil: not a placeholder) */
static NSString *marker_text(NSString *name, NSInteger n) {
    NSDictionary *bullets = @{ @"box": @"◻︎", @"check": @"✓", @"circle": @"◦", @"diamond": @"◆", @"disc": @"•", @"hyphen": @"⁃", @"square": @"▪︎" };
    if (bullets[name]) return bullets[name];
    if ([name isEqualToString:@"decimal"]) return [NSString stringWithFormat:@"%ld", (long)n];
    if ([name isEqualToString:@"octal"]) return [NSString stringWithFormat:@"%lo", (long)n];
    if ([name isEqualToString:@"lower-hexadecimal"]) return [NSString stringWithFormat:@"%lx", (long)n];
    if ([name isEqualToString:@"upper-hexadecimal"]) return [NSString stringWithFormat:@"%lX", (long)n];
    if ([name isEqualToString:@"lower-alpha"] || [name isEqualToString:@"lower-latin"]) return alpha(n);
    if ([name isEqualToString:@"upper-alpha"] || [name isEqualToString:@"upper-latin"]) return alpha(n).uppercaseString;
    if ([name isEqualToString:@"lower-roman"]) return roman(n);
    if ([name isEqualToString:@"upper-roman"]) return roman(n).uppercaseString;
    return nil;
}
static BOOL is_bullet(NSString *format) {
    for (NSString *b in @[ @"{box}", @"{check}", @"{circle}", @"{diamond}", @"{disc}", @"{hyphen}", @"{square}" ])
        if ([format containsString:b]) return YES;
    return NO;
}

@implementation NSTextList
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithMarkerFormat:(NSTextListMarkerFormat)f options:(NSTextListOptions)o startingItemNumber:(NSInteger)n {
    if ((self = [super init])) { _markerFormat = [f copy]; _listOptions = o; _startingItemNumber = n; }
    return self;
}
- (instancetype)initWithMarkerFormat:(NSTextListMarkerFormat)f options:(NSUInteger)o { return [self initWithMarkerFormat:f options:o startingItemNumber:1]; }
- (instancetype)init { return [self initWithMarkerFormat:NSTextListMarkerDisc options:0 startingItemNumber:1]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithMarkerFormat:[c decodeObjectForKey:@"format"] ?: NSTextListMarkerDisc options:(NSUInteger)[c decodeIntegerForKey:@"options"]
                   startingItemNumber:[c containsValueForKey:@"start"] ? [c decodeIntegerForKey:@"start"] : 1];
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_markerFormat forKey:@"format"]; [c encodeInteger:(NSInteger)_listOptions forKey:@"options"]; [c encodeInteger:_startingItemNumber forKey:@"start"];
}
- (id)copyWithZone:(NSZone *)z { return [[NSTextList alloc] initWithMarkerFormat:_markerFormat options:_listOptions startingItemNumber:_startingItemNumber]; }
- (BOOL)isOrdered { return !is_bullet(_markerFormat); }
/* every {placeholder} replaced; the rest of the format kept ("({lower-roman})" -> "(iv)") */
- (NSString *)markerForItemNumber:(NSInteger)n {
    NSMutableString *out = [NSMutableString string];
    NSString *f = _markerFormat; NSUInteger i = 0;
    while (i < f.length) {
        NSRange open = [f rangeOfString:@"{" options:0 range:NSMakeRange(i, f.length - i)];
        if (open.location == NSNotFound) { [out appendString:[f substringFromIndex:i]]; break; }
        NSRange close = [f rangeOfString:@"}" options:0 range:NSMakeRange(open.location, f.length - open.location)];
        if (close.location == NSNotFound) { [out appendString:[f substringFromIndex:i]]; break; }
        [out appendString:[f substringWithRange:NSMakeRange(i, open.location - i)]];
        NSString *name = [f substringWithRange:NSMakeRange(open.location + 1, close.location - open.location - 1)];
        [out appendString:marker_text(name, n) ?: [f substringWithRange:NSMakeRange(open.location, close.location + 1 - open.location)]];
        i = close.location + 1;
    }
    return out;
}
- (NSString *)description { return [NSString stringWithFormat:@"<NSTextList %@ start %ld>", _markerFormat, (long)_startingItemNumber]; }
@end

/* ================= list elements (TextKit 2) ================= */
@implementation NSTextListElement {
    NSArray<NSTextListElement *> *_children;
    __weak NSTextListElement *_parent;
}
- (instancetype)initWithParentElement:(NSTextListElement *)parent textList:(NSTextList *)list contents:(NSAttributedString *)contents
                     markerAttributes:(NSDictionary *)markerAttributes childElements:(NSArray<NSTextListElement *> *)children {
    if ((self = [super initWithAttributedString:nil])) {
        _textList = list; _contents = [contents copy]; _markerAttributes = [markerAttributes copy]; _parent = parent;
        _children = [children copy] ?: @[];
        for (NSTextListElement *c in _children) c->_parent = self;
    }
    return self;
}
+ (instancetype)textListElementWithContents:(NSAttributedString *)contents markerAttributes:(NSDictionary *)markerAttributes
                                   textList:(NSTextList *)list childElements:(NSArray<NSTextListElement *> *)children {
    return [[self alloc] initWithParentElement:nil textList:list contents:contents markerAttributes:markerAttributes childElements:children];
}
/* an element that only groups nested items (no contents of its own) */
+ (instancetype)textListElementWithChildElements:(NSArray<NSTextListElement *> *)children textList:(NSTextList *)list nestingLevel:(NSInteger)level {
    return [[self alloc] initWithParentElement:nil textList:list contents:nil markerAttributes:nil childElements:children];
}
- (NSArray<NSTextListElement *> *)childElements { return _children; }
- (NSTextListElement *)parentElement { return _parent; }
/* its item number: its place among its parent's items that have contents */
- (NSInteger)_isimItemNumber {
    NSInteger n = _textList.startingItemNumber;
    for (NSTextListElement *e in _parent.childElements) { if (e == self) break; if (e.contents) n++; }
    return n;
}
- (NSString *)_isimMarker {
    NSString *m = [_textList markerForItemNumber:[self _isimItemNumber]];
    if ((_textList.listOptions & NSTextListPrependEnclosingMarker) && _parent.contents) {
        NSString *outer = [_parent _isimMarker];
        if ([outer hasSuffix:@"."]) outer = [outer substringToIndex:outer.length - 1];
        m = [outer stringByAppendingString:m];
    }
    return m;
}
/* "\t<marker>\t<contents>", as attributed strings carry list items */
- (NSAttributedString *)attributedString {
    if (!_contents) return [NSAttributedString new];
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"\t%@\t", [self _isimMarker]]
                                                                         attributes:_markerAttributes ?: @{}];
    [s appendAttributedString:_contents];
    return s;
}
@end

/* ================= adaptive image glyphs ================= */
NSAttributedStringKey const NSAdaptiveImageGlyphAttributeName = @"CTAdaptiveImageProvider";
@implementation NSAdaptiveImageGlyph
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithImageContent:(NSData *)data {
    if ((self = [super init])) {
        _imageContent = [data copy];
        uint64_t h = 1469598103934665603ULL; const uint8_t *b = data.bytes;      /* FNV-1a of the content */
        for (NSUInteger i = 0; i < data.length; i++) { h ^= b[i]; h *= 1099511628211ULL; }
        _contentIdentifier = [NSString stringWithFormat:@"%016llx", (unsigned long long)h];
        _contentDescription = @"";
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithImageContent:[c decodeObjectForKey:@"content"] ?: [NSData data]]; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_imageContent forKey:@"content"]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(NSAdaptiveImageGlyph *)o { return [o isKindOfClass:[NSAdaptiveImageGlyph class]] && [o.contentIdentifier isEqualToString:_contentIdentifier]; }
- (NSUInteger)hash { return _contentIdentifier.hash; }
@end

@implementation NSTextContainer (NSTextLayoutOrientationProvider)
- (NSTextLayoutOrientation)layoutOrientation { return NSTextLayoutOrientationHorizontal; }
@end
