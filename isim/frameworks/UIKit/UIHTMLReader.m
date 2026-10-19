/* isim UIKit (ARC): HTML to NSAttributedString (issue #238; NSAttributedStringDocuments.m calls it). Adapted: the
 * host's libxml2 parses the document (isim_html_flatten) and the elements and CSS map to attributes the way iOS's
 * import (WebKit's converter) produces them for text: Times New Roman 12 by default (CSS's 16px medium), headings,
 * bold / italic / underline / strikethrough, colours and backgrounds, links (blue, underlined, NSLinkAttributeName),
 * alignment, indents and paragraph spacing from margins, lists ("\tbullet\t" / "\t1.\t" markers with NSTextList), line
 * breaks, superscript / subscript, preformatted and monospaced text, tables as tab-separated rows and images from
 * file and data URLs. CSS: inline styles, presentational attributes and <style> rules with simple selectors (tag,
 * .class, #id, tag.class; no descendant or pseudo selectors). Scripts don't run; remote resources aren't loaded. */
#import <UIKit/UIKit.h>
#import <isim_host.h>

UIFont *isim_ui_styled_font(UIFont *base, BOOL bold, BOOL italic);     /* UIRTFReader.m */

@interface __IsimHTMLStyle : NSObject <NSCopying>
@property (nonatomic, copy) NSString *family;
@property (nonatomic) CGFloat size, kern, lineHeight, lineMultiple, marginTop, marginBottom, indent, rightIndent, firstIndent;
@property (nonatomic) BOOL bold, italic, underline, strike, mono, pre, hidden, block;
@property (nonatomic) int vertical;                       /* 1 superscript, -1 subscript */
@property (nonatomic, strong) UIColor *color, *background;
@property (nonatomic, strong) NSURL *link;
@property (nonatomic) NSTextAlignment align;
@end
@implementation __IsimHTMLStyle
- (id)copyWithZone:(NSZone *)z {
    __IsimHTMLStyle *s = [__IsimHTMLStyle new];
    s.family = _family; s.size = _size; s.kern = _kern; s.lineHeight = _lineHeight; s.lineMultiple = _lineMultiple;
    s.indent = _indent; s.rightIndent = _rightIndent; s.align = _align;
    s.bold = _bold; s.italic = _italic; s.underline = _underline; s.strike = _strike; s.mono = _mono; s.pre = _pre; s.hidden = _hidden;
    s.vertical = _vertical; s.color = _color; s.background = _background; s.link = _link;
    return s;                                             /* margins and the first-line indent are per element */
}
@end

/* ---- CSS values ---- */
static UIColor *css_color(NSString *v) {
    v = [v.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (!v.length) return nil;
    if ([v hasPrefix:@"#"]) {
        NSString *h = [v substringFromIndex:1];
        if (h.length == 3 || h.length == 4) {
            NSMutableString *x = [NSMutableString string];
            for (NSUInteger i = 0; i < h.length; i++) { unichar c = [h characterAtIndex:i]; [x appendFormat:@"%C%C", c, c]; }
            h = x;
        }
        if (h.length != 6 && h.length != 8) return nil;
        unsigned long n = strtoul(h.UTF8String, NULL, 16);
        if (h.length == 6) n = n << 8 | 0xFF;
        return [UIColor colorWithRed:((n >> 24) & 0xFF) / 255.0 green:((n >> 16) & 0xFF) / 255.0 blue:((n >> 8) & 0xFF) / 255.0 alpha:(n & 0xFF) / 255.0];
    }
    if ([v hasPrefix:@"rgb"]) {
        NSRange o = [v rangeOfString:@"("], c = [v rangeOfString:@")"];
        if (o.location == NSNotFound || c.location == NSNotFound || c.location < o.location) return nil;
        NSString *inner = [v substringWithRange:NSMakeRange(o.location + 1, c.location - o.location - 1)];
        NSArray *parts = [[inner stringByReplacingOccurrencesOfString:@"/" withString:@","] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]];
        NSMutableArray *nums = [NSMutableArray array];
        for (NSString *p in parts) if (p.length) [nums addObject:p];
        if (nums.count < 3) return nil;
        CGFloat ch[4] = { 0, 0, 0, 1 };
        for (NSUInteger i = 0; i < MIN(nums.count, 4); i++) {
            NSString *p = nums[i];
            double d = p.doubleValue;
            ch[i] = [p hasSuffix:@"%"] ? d / 100 : i < 3 ? d / 255 : d;
        }
        return [UIColor colorWithRed:ch[0] green:ch[1] blue:ch[2] alpha:ch[3]];
    }
    static NSDictionary *named;
    if (!named) named = @{ @"black": @0x000000, @"white": @0xFFFFFF, @"red": @0xFF0000, @"green": @0x008000, @"blue": @0x0000FF,
                           @"yellow": @0xFFFF00, @"orange": @0xFFA500, @"purple": @0x800080, @"gray": @0x808080, @"grey": @0x808080,
                           @"silver": @0xC0C0C0, @"maroon": @0x800000, @"olive": @0x808000, @"lime": @0x00FF00, @"aqua": @0x00FFFF,
                           @"cyan": @0x00FFFF, @"teal": @0x008080, @"navy": @0x000080, @"fuchsia": @0xFF00FF, @"magenta": @0xFF00FF,
                           @"pink": @0xFFC0CB, @"brown": @0xA52A2A, @"gold": @0xFFD700, @"indigo": @0x4B0082, @"violet": @0xEE82EE,
                           @"darkgray": @0xA9A9A9, @"darkgrey": @0xA9A9A9, @"lightgray": @0xD3D3D3, @"lightgrey": @0xD3D3D3,
                           @"darkred": @0x8B0000, @"darkgreen": @0x006400, @"darkblue": @0x00008B, @"lightblue": @0xADD8E6,
                           @"lightgreen": @0x90EE90, @"crimson": @0xDC143C, @"coral": @0xFF7F50, @"tomato": @0xFF6347,
                           @"salmon": @0xFA8072, @"khaki": @0xF0E68C, @"beige": @0xF5F5DC, @"tan": @0xD2B48C, @"chocolate": @0xD2691E,
                           @"steelblue": @0x4682B4, @"royalblue": @0x4169E1, @"skyblue": @0x87CEEB, @"turquoise": @0x40E0D0,
                           @"orchid": @0xDA70D6, @"plum": @0xDDA0DD, @"slategray": @0x708090, @"whitesmoke": @0xF5F5F5 };
    if ([v isEqualToString:@"transparent"]) return UIColor.clearColor;
    NSNumber *n = named[v];
    if (!n) return nil;
    unsigned long x = n.unsignedLongValue;
    return [UIColor colorWithRed:((x >> 16) & 0xFF) / 255.0 green:((x >> 8) & 0xFF) / 255.0 blue:(x & 0xFF) / 255.0 alpha:1];
}
/* a length in points (CSS px are 0.75 pt: 16px is 12pt); em and % of the parent's size; NAN when not a length */
static CGFloat css_length(NSString *v, CGFloat em) {
    v = [v.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (!v.length) return NAN;
    double d = v.doubleValue;
    if ([v hasSuffix:@"px"]) return d * 0.75;
    if ([v hasSuffix:@"pt"]) return d;
    if ([v hasSuffix:@"rem"]) return d * 12;
    if ([v hasSuffix:@"em"]) return d * em;
    if ([v hasSuffix:@"%"]) return d / 100 * em;
    if ([v hasSuffix:@"in"]) return d * 72;
    if ([v hasSuffix:@"cm"]) return d * 72 / 2.54;
    if ([v hasSuffix:@"mm"]) return d * 72 / 25.4;
    if ([v isEqualToString:@"0"]) return 0;
    unichar c = [v characterAtIndex:0];
    if ((c >= '0' && c <= '9') || c == '.') return d * 0.75;        /* unitless: px (quirks) */
    return NAN;
}
static CGFloat css_font_size(NSString *v, CGFloat parent) {
    static NSDictionary *k;
    if (!k) k = @{ @"xx-small": @6.75, @"x-small": @7.5, @"small": @9.75, @"medium": @12, @"large": @13.5, @"x-large": @18, @"xx-large": @24,
                   @"xxx-large": @36 };
    NSString *l = v.lowercaseString;
    if (k[l]) return [k[l] doubleValue];
    if ([l isEqualToString:@"smaller"]) return parent / 1.2;
    if ([l isEqualToString:@"larger"]) return parent * 1.2;
    return css_length(v, parent);
}

/* ---- CSS rules (simple selectors) ---- */
@interface __IsimCSSRule : NSObject
@property (nonatomic, copy) NSString *tag, *cls, *ident;
@property (nonatomic) int specificity, order;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *decls;
@end
@implementation __IsimCSSRule
@end

static NSDictionary *css_declarations(NSString *s) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSString *part in [s componentsSeparatedByString:@";"]) {
        NSRange c = [part rangeOfString:@":"];
        if (c.location == NSNotFound) continue;
        NSString *k = [[part substringToIndex:c.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
        NSString *v = [[part substringFromIndex:c.location + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        v = [[v stringByReplacingOccurrencesOfString:@"!important" withString:@""] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (k.length && v.length) d[k] = v;
    }
    return d;
}
static void css_parse(NSString *css, NSMutableArray<__IsimCSSRule *> *rules) {
    /* comments out, then "selectors { declarations }" */
    NSMutableString *s = [css mutableCopy];
    NSRange r;
    while ((r = [s rangeOfString:@"/*"]).location != NSNotFound) {
        NSRange e = [s rangeOfString:@"*/" options:0 range:NSMakeRange(r.location + 2, s.length - r.location - 2)];
        [s deleteCharactersInRange:NSMakeRange(r.location, e.location == NSNotFound ? s.length - r.location : NSMaxRange(e) - r.location)];
    }
    NSScanner *sc = [NSScanner scannerWithString:s];
    while (!sc.isAtEnd) {
        NSString *sel = nil, *body = nil;
        [sc scanUpToString:@"{" intoString:&sel];
        if (![sc scanString:@"{" intoString:NULL]) break;
        [sc scanUpToString:@"}" intoString:&body];
        [sc scanString:@"}" intoString:NULL];
        sel = [sel stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if ([sel hasPrefix:@"@"]) continue;                           /* @media, @font-face: skipped */
        NSDictionary *decls = css_declarations(body ?: @"");
        for (NSString *one in [sel componentsSeparatedByString:@","]) {
            NSString *t = [one stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
            if (!t.length || [t rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" >+~:[\n\t"]].location != NSNotFound) continue;
            __IsimCSSRule *rule = [__IsimCSSRule new];
            NSRange hash = [t rangeOfString:@"#"], dot = [t rangeOfString:@"."];
            NSUInteger tagEnd = MIN(hash.location, dot.location);
            NSString *tag = tagEnd == NSNotFound ? t : [t substringToIndex:tagEnd];
            rule.tag = [tag isEqualToString:@"*"] || !tag.length ? nil : tag;
            if (dot.location != NSNotFound) {
                NSString *c = [t substringFromIndex:dot.location + 1];
                NSRange h = [c rangeOfString:@"#"]; if (h.location != NSNotFound) c = [c substringToIndex:h.location];
                rule.cls = c;
            }
            if (hash.location != NSNotFound) {
                NSString *i = [t substringFromIndex:hash.location + 1];
                NSRange d = [i rangeOfString:@"."]; if (d.location != NSNotFound) i = [i substringToIndex:d.location];
                rule.ident = i;
            }
            rule.specificity = (rule.ident ? 100 : 0) + (rule.cls ? 10 : 0) + (rule.tag ? 1 : 0);
            rule.order = (int)rules.count;
            rule.decls = decls;
            [rules addObject:rule];
        }
    }
}

/* ---- the converter ---- */
@interface __IsimHTMLConverter : NSObject
@end
@implementation __IsimHTMLConverter {
    NSMutableAttributedString *_out;
    NSMutableArray<__IsimHTMLStyle *> *_styles;
    NSMutableArray<NSString *> *_tags;
    NSMutableArray<NSMutableDictionary *> *_lists;      /* @{ordered, counter, type} */
    NSMutableArray<__IsimCSSRule *> *_rules;
    NSMutableString *_styleText;
    NSURL *_base;
    BOOL _space, _pendingSpacing, _embedMarkers;
    NSInteger _cellCount;
}
static NSSet *blocks(void) {
    static NSSet *s;
    if (!s) s = [NSSet setWithArray:@[@"p", @"div", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6", @"ul", @"ol", @"li", @"blockquote", @"pre",
                                      @"table", @"tr", @"section", @"article", @"header", @"footer", @"nav", @"aside", @"main",
                                      @"figure", @"figcaption", @"address", @"dl", @"dt", @"dd", @"hr", @"center", @"form", @"fieldset",
                                      @"details", @"summary", @"caption", @"body", @"html", @"tbody", @"thead", @"tfoot"]];
    return s;
}
- (instancetype)initWithBase:(NSURL *)base options:(NSDictionary *)options {
    if ((self = [super init])) {
        /* list markers in the text before iOS 18 (TextKit 1); since iOS 18 TextKit 2 draws them from the text lists,
           unless the app asks for the TextKit 1 format */
        extern int isim_ui_os_major(void);
        _embedMarkers = isim_ui_os_major() < 18 || [options[@"NSTextKit1ListMarkerFormatDocumentOption"] boolValue];
        _out = [NSMutableAttributedString new];
        __IsimHTMLStyle *root = [__IsimHTMLStyle new];
        root.family = @"TimesNewRomanPSMT"; root.size = 12; root.align = NSTextAlignmentNatural;
        root.color = [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
        _styles = [NSMutableArray arrayWithObject:root];
        _tags = [NSMutableArray array]; _lists = [NSMutableArray array]; _rules = [NSMutableArray array];
        _base = base;
        _space = YES;
    }
    return self;
}
- (__IsimHTMLStyle *)_style { return _styles.lastObject; }

- (UIFont *)_font:(__IsimHTMLStyle *)s {
    CGFloat size = s.vertical ? s.size * 0.83 : s.size;
    NSString *fam = s.mono ? @"Courier" : s.family;
    UIFont *f = [fam isEqualToString:@"-apple-system"] ? [UIFont systemFontOfSize:size] : [UIFont fontWithName:fam size:size];
    if (!f) f = [UIFont fontWithName:@"TimesNewRomanPSMT" size:size] ?: [UIFont systemFontOfSize:size];
    return isim_ui_styled_font(f, s.bold, s.italic);
}
- (NSDictionary *)_attributes {
    __IsimHTMLStyle *s = self._style;
    NSMutableDictionary *a = [NSMutableDictionary dictionary];
    a[NSFontAttributeName] = [self _font:s];
    a[NSForegroundColorAttributeName] = s.color;
    if (s.background) a[NSBackgroundColorAttributeName] = s.background;
    if (s.underline) a[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
    if (s.strike) a[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
    if (s.link) a[NSLinkAttributeName] = s.link;
    if (s.kern) a[NSKernAttributeName] = @(s.kern);
    if (s.vertical) a[NSBaselineOffsetAttributeName] = @(s.vertical * s.size * 0.33);
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
    ps.alignment = s.align;
    ps.headIndent = s.indent; ps.firstLineHeadIndent = s.indent + s.firstIndent; ps.tailIndent = -s.rightIndent;
    if (s.lineMultiple > 0) ps.lineHeightMultiple = s.lineMultiple;
    if (s.lineHeight > 0) { ps.minimumLineHeight = s.lineHeight; ps.maximumLineHeight = s.lineHeight; }
    /* the paragraph's spacing: the innermost block element's margins (list items and rows have none) */
    for (NSInteger i = (NSInteger)_styles.count - 1; i >= 0; i--) {
        __IsimHTMLStyle *b = _styles[(NSUInteger)i];
        if (b.block) { ps.paragraphSpacingBefore = _out.length ? b.marginTop : 0; ps.paragraphSpacing = b.marginBottom; break; }
    }
    if (_lists.count) {
        NSMutableArray *lists = [NSMutableArray array];
        for (NSDictionary *l in _lists) [lists addObject:[[NSTextList alloc] initWithMarkerFormat:l[@"format"] options:0]];
        ps.textLists = lists;
        if (_embedMarkers) {                     /* TextKit 1 format: "\t1.\t" in the text, tab stops for it */
            CGFloat base = s.indent - 36;
            ps.tabStops = @[[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentNatural location:base + 11 options:@{}],
                            [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentNatural location:base + 36 options:@{}]];
            ps.firstLineHeadIndent = MAX(0, base);
        }
    }
    a[NSParagraphStyleAttributeName] = ps;
    return a;
}
- (void)_append:(NSString *)t {
    if (!t.length) return;
    [_out appendAttributedString:[[NSAttributedString alloc] initWithString:t attributes:[self _attributes]]];
}
/* a line break before a block: the previous paragraph ends */
- (void)_newline {
    if (!_out.length || [_out.string characterAtIndex:_out.length - 1] == '\n') { _space = YES; return; }
    NSDictionary *prev = [_out attributesAtIndex:_out.length - 1 effectiveRange:NULL];
    [_out appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:prev]];
    _space = YES;
}
- (void)_text:(NSString *)t {
    __IsimHTMLStyle *s = self._style;
    if (s.hidden) { if (_styleText) [_styleText appendString:t]; return; }
    if (s.pre) { [self _append:t]; _space = [t hasSuffix:@"\n"]; return; }
    NSMutableString *o = [NSMutableString string];
    NSCharacterSet *ws = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n\f"];
    for (NSUInteger i = 0; i < t.length; i++) {
        unichar c = [t characterAtIndex:i];
        if ([ws characterIsMember:c]) { if (!_space) { [o appendString:@" "]; _space = YES; } }
        else { [o appendFormat:@"%C", c]; _space = NO; }
    }
    [self _append:o];
}

- (void)_apply:(NSDictionary *)d to:(__IsimHTMLStyle *)s parent:(__IsimHTMLStyle *)p {
    [d enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
        NSString *l = v.lowercaseString;
        if ([k isEqualToString:@"color"]) { UIColor *c = css_color(v); if (c) s.color = c; }
        else if ([k isEqualToString:@"background-color"] || [k isEqualToString:@"background"]) { UIColor *c = css_color([v componentsSeparatedByString:@" "].firstObject); if (c) s.background = c; }
        else if ([k isEqualToString:@"font-size"]) { CGFloat z = css_font_size(v, p.size); if (!isnan(z) && z > 0) s.size = z; }
        else if ([k isEqualToString:@"font-weight"]) s.bold = [l isEqualToString:@"bold"] || [l isEqualToString:@"bolder"] || l.intValue >= 600;
        else if ([k isEqualToString:@"font-style"]) s.italic = [l isEqualToString:@"italic"] || [l isEqualToString:@"oblique"];
        else if ([k isEqualToString:@"font-family"]) {
            for (NSString *raw in [v componentsSeparatedByString:@","]) {
                NSString *f = [raw stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \"'"]];
                NSString *g = f.lowercaseString;
                if ([g isEqualToString:@"serif"]) { s.family = @"TimesNewRomanPSMT"; s.mono = NO; break; }
                if ([g isEqualToString:@"sans-serif"]) { s.family = @"Helvetica"; s.mono = NO; break; }
                if ([g isEqualToString:@"monospace"]) { s.mono = YES; break; }
                if ([g isEqualToString:@"system-ui"] || [g isEqualToString:@"-apple-system"]) { s.family = @"-apple-system"; s.mono = NO; break; }
                if ([UIFont fontWithName:f size:12]) { s.family = f; s.mono = NO; break; }
            }
        }
        else if ([k isEqualToString:@"text-decoration"] || [k isEqualToString:@"text-decoration-line"]) {
            if ([l containsString:@"none"]) { s.underline = NO; s.strike = NO; }
            if ([l containsString:@"underline"]) s.underline = YES;
            if ([l containsString:@"line-through"]) s.strike = YES;
        }
        else if ([k isEqualToString:@"text-align"]) {
            s.align = [l isEqualToString:@"center"] ? NSTextAlignmentCenter : [l isEqualToString:@"right"] || [l isEqualToString:@"end"] ? NSTextAlignmentRight
                    : [l isEqualToString:@"justify"] ? NSTextAlignmentJustified : [l isEqualToString:@"left"] || [l isEqualToString:@"start"] ? NSTextAlignmentLeft : s.align;
        }
        else if ([k isEqualToString:@"margin-left"] || [k isEqualToString:@"padding-left"]) { CGFloat x = css_length(v, s.size); if (!isnan(x)) s.indent += x; }
        else if ([k isEqualToString:@"margin-right"] || [k isEqualToString:@"padding-right"]) { CGFloat x = css_length(v, s.size); if (!isnan(x)) s.rightIndent += x; }
        else if ([k isEqualToString:@"margin-top"]) { CGFloat x = css_length(v, s.size); if (!isnan(x)) s.marginTop = x; }
        else if ([k isEqualToString:@"margin-bottom"]) { CGFloat x = css_length(v, s.size); if (!isnan(x)) s.marginBottom = x; }
        else if ([k isEqualToString:@"margin"]) {
            NSArray *m = [l componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            CGFloat top = m.count ? css_length(m[0], s.size) : NAN, bottom = m.count > 2 ? css_length(m[2], s.size) : top;
            if (!isnan(top)) s.marginTop = top;
            if (!isnan(bottom)) s.marginBottom = bottom;
        }
        else if ([k isEqualToString:@"text-indent"]) { CGFloat x = css_length(v, s.size); if (!isnan(x)) s.firstIndent = x; }
        else if ([k isEqualToString:@"vertical-align"]) s.vertical = [l isEqualToString:@"super"] ? 1 : [l isEqualToString:@"sub"] ? -1 : 0;
        else if ([k isEqualToString:@"letter-spacing"]) { CGFloat x = css_length(v, s.size); if (!isnan(x)) s.kern = x; }
        else if ([k isEqualToString:@"display"]) s.hidden = s.hidden || [l isEqualToString:@"none"];
        else if ([k isEqualToString:@"white-space"]) s.pre = [l hasPrefix:@"pre"];
        else if ([k isEqualToString:@"line-height"]) {
            if ([l isEqualToString:@"normal"]) { s.lineMultiple = 0; s.lineHeight = 0; }
            else if ([l rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location == NSNotFound && ![l hasSuffix:@"%"]) s.lineMultiple = l.doubleValue;
            else { CGFloat x = css_length(v, s.size); if (!isnan(x)) s.lineHeight = x; }
        }
    }];
}

- (void)_start:(NSString *)tag attributes:(NSDictionary<NSString *, NSString *> *)attrs {
    __IsimHTMLStyle *p = self._style, *s = [p copy];
    BOOL block = [blocks() containsObject:tag];
    /* the element's own defaults (the user agent style sheet) */
    static NSDictionary *heading;
    if (!heading) heading = @{ @"h1": @[@2, @0.67], @"h2": @[@1.5, @0.83], @"h3": @[@1.17, @1], @"h4": @[@1, @1.33], @"h5": @[@0.83, @1.67], @"h6": @[@0.67, @2.33] };
    if (heading[tag]) { s.size = p.size * [heading[tag][0] doubleValue]; s.bold = YES; s.marginTop = s.marginBottom = s.size * [heading[tag][1] doubleValue]; }
    else if ([tag isEqualToString:@"p"] || [tag isEqualToString:@"dl"]) s.marginTop = s.marginBottom = p.size;
    else if ([@[@"b", @"strong", @"th"] containsObject:tag]) s.bold = YES;
    else if ([@[@"i", @"em", @"cite", @"var", @"dfn", @"address"] containsObject:tag]) s.italic = YES;
    else if ([@[@"u", @"ins"] containsObject:tag]) s.underline = YES;
    else if ([@[@"s", @"strike", @"del"] containsObject:tag]) s.strike = YES;
    else if ([@[@"code", @"tt", @"kbd", @"samp"] containsObject:tag]) { s.mono = YES; s.size = p.size * 13 / 16; }
    else if ([tag isEqualToString:@"pre"]) { s.mono = YES; s.pre = YES; s.size = p.size * 13 / 16; s.marginTop = s.marginBottom = s.size; }
    else if ([tag isEqualToString:@"small"]) s.size = p.size / 1.2;
    else if ([tag isEqualToString:@"big"]) s.size = p.size * 1.2;
    else if ([tag isEqualToString:@"sup"]) s.vertical = 1;
    else if ([tag isEqualToString:@"sub"]) s.vertical = -1;
    else if ([tag isEqualToString:@"mark"]) s.background = [UIColor colorWithRed:1 green:1 blue:0 alpha:1];
    else if ([tag isEqualToString:@"center"]) s.align = NSTextAlignmentCenter;
    else if ([tag isEqualToString:@"blockquote"]) { s.indent += 30; s.rightIndent += 30; s.marginTop = s.marginBottom = p.size; }
    else if ([tag isEqualToString:@"dd"]) s.indent += 30;
    else if ([@[@"ul", @"ol"] containsObject:tag]) { s.indent += 36; if (!_lists.count) s.marginTop = s.marginBottom = p.size; }
    else if ([@[@"head", @"title", @"script", @"style", @"template", @"noscript", @"iframe", @"object", @"svg", @"select"] containsObject:tag]) s.hidden = YES;
    else if ([tag isEqualToString:@"a"] && attrs[@"href"]) {
        NSURL *u = [NSURL URLWithString:attrs[@"href"] relativeToURL:_base];
        if (u) { s.link = [NSURL URLWithString:u.absoluteString] ?: u; s.color = [UIColor colorWithRed:0 green:0 blue:0.933 alpha:1]; s.underline = YES; }
    }
    /* presentational attributes */
    if ([tag isEqualToString:@"font"]) {
        UIColor *c = css_color(attrs[@"color"] ?: @""); if (c) s.color = c;
        if (attrs[@"face"]) [self _apply:@{ @"font-family": attrs[@"face"] } to:s parent:p];
        if (attrs[@"size"]) {
            static const CGFloat sizes[] = { 7.5, 9.75, 12, 13.5, 18, 24, 36 };
            NSString *z = attrs[@"size"]; int n = z.intValue;
            if ([z hasPrefix:@"+"] || [z hasPrefix:@"-"]) n += 3;
            s.size = sizes[MAX(1, MIN(7, n)) - 1];
        }
    }
    if (attrs[@"align"] && block) [self _apply:@{ @"text-align": attrs[@"align"] } to:s parent:p];
    if (attrs[@"bgcolor"]) { UIColor *c = css_color(attrs[@"bgcolor"]); if (c) s.background = c; }
    /* style sheet rules by specificity, then the inline style */
    NSArray *classes = [attrs[@"class"] ?: @"" componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSString *ident = attrs[@"id"].lowercaseString;
    NSMutableArray<__IsimCSSRule *> *matched = [NSMutableArray array];
    for (__IsimCSSRule *r in _rules) {
        if (r.tag && ![r.tag isEqualToString:tag]) continue;
        if (r.ident && ![r.ident isEqualToString:ident]) continue;
        if (r.cls) { BOOL hit = NO; for (NSString *c in classes) if ([c.lowercaseString isEqualToString:r.cls]) hit = YES; if (!hit) continue; }
        [matched addObject:r];
    }
    [matched sortUsingComparator:^NSComparisonResult(__IsimCSSRule *a, __IsimCSSRule *b) {
        return a.specificity != b.specificity ? (a.specificity < b.specificity ? NSOrderedAscending : NSOrderedDescending) : (a.order < b.order ? NSOrderedAscending : NSOrderedDescending);
    }];
    for (__IsimCSSRule *r in matched) [self _apply:r.decls to:s parent:p];
    if (attrs[@"style"]) [self _apply:css_declarations(attrs[@"style"]) to:s parent:p];

    if ([tag isEqualToString:@"style"]) _styleText = [NSMutableString string];
    if (block && !p.hidden) [self _newline];
    s.block = block;
    [_styles addObject:s]; [_tags addObject:tag];
    if (s.hidden) return;

    if ([tag isEqualToString:@"ul"] || [tag isEqualToString:@"ol"]) {
        BOOL ordered = [tag isEqualToString:@"ol"];
        NSString *type = attrs[@"type"] ?: @"";
        NSString *format = !ordered ? (_lists.count == 0 ? NSTextListMarkerDisc : _lists.count == 1 ? NSTextListMarkerCircle : NSTextListMarkerSquare)
                         : [type isEqualToString:@"a"] ? NSTextListMarkerLowercaseAlpha : [type isEqualToString:@"A"] ? NSTextListMarkerUppercaseAlpha
                         : [type isEqualToString:@"i"] ? NSTextListMarkerLowercaseRoman : [type isEqualToString:@"I"] ? NSTextListMarkerUppercaseRoman : NSTextListMarkerDecimal;
        NSInteger start = attrs[@"start"] ? attrs[@"start"].integerValue : 1;
        [_lists addObject:[@{ @"format": format, @"counter": @(start), @"ordered": @(ordered) } mutableCopy]];
    } else if ([tag isEqualToString:@"li"] && _lists.count) {
        NSMutableDictionary *l = _lists.lastObject;
        NSInteger n = [l[@"counter"] integerValue];
        if (attrs[@"value"]) n = attrs[@"value"].integerValue;
        if (_embedMarkers) {
            NSTextList *list = [[NSTextList alloc] initWithMarkerFormat:l[@"format"] options:0];
            NSString *marker = [list markerForItemNumber:n];
            if ([l[@"ordered"] boolValue]) marker = [marker stringByAppendingString:@"."];   /* "1." as WebKit's converter writes */
            [self _append:[NSString stringWithFormat:@"\t%@\t", marker]];
        }
        l[@"counter"] = @(n + 1);
        _space = YES;
    } else if ([tag isEqualToString:@"br"]) {
        [self _append:@"\n"]; _space = YES;
    } else if ([tag isEqualToString:@"img"]) {
        [self _image:attrs];
    } else if ([tag isEqualToString:@"tr"]) {
        _cellCount = 0;
    } else if ([tag isEqualToString:@"td"] || [tag isEqualToString:@"th"]) {
        if (_cellCount++ > 0) { [self _append:@"\t"]; }
        _space = YES;
    }
}
- (void)_end:(NSString *)tag {
    NSUInteger i = NSNotFound;
    for (NSUInteger k = _tags.count; k > 0; k--) if ([_tags[k - 1] isEqualToString:tag]) { i = k - 1; break; }
    if (i == NSNotFound) return;
    while (_tags.count > i) {
        NSString *t = _tags.lastObject;
        __IsimHTMLStyle *s = self._style;
        if ([t isEqualToString:@"style"] && _styleText) { css_parse(_styleText, _rules); _styleText = nil; }
        if (([t isEqualToString:@"ul"] || [t isEqualToString:@"ol"]) && !s.hidden && _lists.count) [_lists removeLastObject];
        BOOL block = [blocks() containsObject:t] && !s.hidden;
        if (block) {
            /* the newline that ends the block carries its spacing */
            if (_out.length && [_out.string characterAtIndex:_out.length - 1] != '\n') [self _append:@"\n"];
            _space = YES;
        }
        [_tags removeLastObject]; [_styles removeLastObject];
    }
}
- (void)_image:(NSDictionary<NSString *, NSString *> *)attrs {
    NSString *src = attrs[@"src"];
    if (!src.length) return;
    NSData *d = nil;
    if ([src hasPrefix:@"data:"]) {
        NSRange comma = [src rangeOfString:@","];
        if (comma.location != NSNotFound && [[src substringToIndex:comma.location] hasSuffix:@";base64"])
            d = [[NSData alloc] initWithBase64EncodedString:[src substringFromIndex:comma.location + 1] options:NSDataBase64DecodingIgnoreUnknownCharacters];
    } else {
        NSURL *rel = [NSURL URLWithString:src relativeToURL:_base], *u = rel.absoluteString ? [NSURL URLWithString:rel.absoluteString] : nil;
        if (u.isFileURL) d = [NSData dataWithContentsOfFile:u.path];               /* remote images aren't loaded */
    }
    UIImage *img = d ? [UIImage imageWithData:d] : nil;
    if (!img) return;
    NSTextAttachment *a = [NSTextAttachment new];
    a.image = img;
    CGFloat w = attrs[@"width"].doubleValue * 0.75, h = attrs[@"height"].doubleValue * 0.75;
    CGSize sz = img.size;
    if (w > 0 && h <= 0 && sz.width > 0) h = w * sz.height / sz.width;
    if (h > 0 && w <= 0 && sz.height > 0) w = h * sz.width / sz.height;
    a.bounds = CGRectMake(0, 0, w > 0 ? w : sz.width * 0.75, h > 0 ? h : sz.height * 0.75);
    NSMutableAttributedString *s = [[NSAttributedString attributedStringWithAttachment:a] mutableCopy];
    [s addAttributes:[self _attributes] range:NSMakeRange(0, s.length)];
    [s addAttribute:NSAttachmentAttributeName value:a range:NSMakeRange(0, s.length)];
    [_out appendAttributedString:s];
    _space = NO;
}

- (NSAttributedString *)convert:(const char *)stream length:(long)n {
    const char *p = stream, *end = stream + n;
    while (p < end) {
        const char *rec = p;
        while (p < end && *p != '\x1e') p++;
        long len = p - rec;
        if (p < end) p++;
        if (len < 1) continue;
        char kind = rec[0];
        NSString *body = [[NSString alloc] initWithBytes:rec + 1 length:(NSUInteger)(len - 1) encoding:NSUTF8StringEncoding] ?: @"";
        if (kind == 'T') [self _text:body];
        else if (kind == 'E') [self _end:body];
        else if (kind == 'S') {
            NSArray *fields = [body componentsSeparatedByString:@"\x1f"];
            NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
            for (NSUInteger i = 1; i < fields.count; i++) {
                NSString *f = fields[i];
                NSRange eq = [f rangeOfString:@"="];
                if (eq.location != NSNotFound) attrs[[f substringToIndex:eq.location]] = [f substringFromIndex:eq.location + 1];
            }
            NSString *tag = fields.firstObject;
            [self _start:tag attributes:attrs];
            if ([@[@"br", @"img", @"hr", @"meta", @"link", @"input", @"wbr"] containsObject:tag]) [self _end:tag];
        }
    }
    return _out;
}
@end

static const char *charset_name(NSStringEncoding e) {
    switch (e) {
    case NSUTF8StringEncoding: return "UTF-8";
    case NSASCIIStringEncoding: return "US-ASCII";
    case NSISOLatin1StringEncoding: return "ISO-8859-1";
    case NSWindowsCP1252StringEncoding: return "windows-1252";
    case NSUTF16StringEncoding: return "UTF-16";
    case NSUTF16LittleEndianStringEncoding: return "UTF-16LE";
    case NSUTF16BigEndianStringEncoding: return "UTF-16BE";
    case NSMacOSRomanStringEncoding: return "macintosh";
    default: return NULL;
    }
}

NSAttributedString *isim_ui_attributed_from_html(NSData *data, NSDictionary *options, NSURL *baseURL, NSStringEncoding *encodingOut) {
    NSStringEncoding enc = [options[NSCharacterEncodingDocumentOption] unsignedIntegerValue];
    const char *charset = enc ? charset_name(enc) : NULL;
    if (!charset) {
        /* the document's <meta charset> (libxml2 reads it); without one HTML is Windows-1252, as in WebKit */
        NSString *head = [[[NSString alloc] initWithBytes:data.bytes length:MIN(data.length, 2048) encoding:NSASCIIStringEncoding] lowercaseString];
        if (!head) {
            NSMutableData *ascii = [NSMutableData dataWithLength:MIN(data.length, 2048)];
            const unsigned char *b = data.bytes; unsigned char *o = ascii.mutableBytes;
            for (NSUInteger i = 0; i < ascii.length; i++) o[i] = b[i] < 0x80 ? b[i] : '?';
            head = [[[NSString alloc] initWithData:ascii encoding:NSASCIIStringEncoding] lowercaseString];
        }
        BOOL declared = [head containsString:@"charset"];
        if (!declared) { charset = "windows-1252"; enc = NSWindowsCP1252StringEncoding; }
        else enc = [head containsString:@"utf-8"] || [head containsString:@"utf8"] ? NSUTF8StringEncoding : NSWindowsCP1252StringEncoding;
    }
    if (encodingOut) *encodingOut = enc;
    long cap = (long)data.length * 2 + 4096;
    char *buf = malloc((size_t)cap);
    long n = isim_html_flatten(data.bytes, (long)data.length, charset, buf, cap);
    if (n >= cap) { free(buf); cap = n + 1; buf = malloc((size_t)cap); n = isim_html_flatten(data.bytes, (long)data.length, charset, buf, cap); }
    if (n < 0) {                                                       /* no libxml2 on the host: the text without tags */
        free(buf);
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        NSMutableString *plain = [NSMutableString string];
        BOOL inTag = NO;
        for (NSUInteger i = 0; i < s.length; i++) { unichar c = [s characterAtIndex:i]; if (c == '<') inTag = YES; else if (c == '>') inTag = NO; else if (!inTag) [plain appendFormat:@"%C", c]; }
        UIFont *f = [UIFont fontWithName:@"TimesNewRomanPSMT" size:12] ?: [UIFont systemFontOfSize:12];
        return [[NSAttributedString alloc] initWithString:plain attributes:@{ NSFontAttributeName: f }];
    }
    NSAttributedString *r = [[[__IsimHTMLConverter alloc] initWithBase:baseURL options:options] convert:buf length:n];
    free(buf);
    return r;
}
