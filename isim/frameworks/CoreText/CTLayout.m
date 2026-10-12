// isim CoreText layout: CTLine, CTRun, CTFramesetter, CTFrame, CTParagraphStyle and CTTextTab over Pango layouts of
// the attributed string's markup (host_cg.c). A framesetter lays out each paragraph on its own with its paragraph
// style and places the lines itself: alignment, indents, line heights and spacing, paragraph spacing. String indices
// are UTF-16 (NSString) indices, mapped from Pango's UTF-8.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <CoreText/CoreText.h>
#include <isim_host.h>
#include <isim_host_cg.h>
#include <float.h>
#include <math.h>
#import "CTPrivate.h"

const CFStringRef kCTFontAttributeName = CFSTR("NSFont");
const CFStringRef kCTForegroundColorAttributeName = CFSTR("CTForegroundColor");
const CFStringRef kCTForegroundColorFromContextAttributeName = CFSTR("CTForegroundColorFromContext");
const CFStringRef kCTKernAttributeName = CFSTR("NSKern");
const CFStringRef kCTParagraphStyleAttributeName = CFSTR("NSParagraphStyle");
const CFStringRef kCTUnderlineStyleAttributeName = CFSTR("NSUnderline");
const CFStringRef kCTStrokeWidthAttributeName = CFSTR("NSStrokeWidth");
const CFStringRef kCTBaselineOffsetAttributeName = CFSTR("CTBaselineOffset");
const CFStringRef kCTTabColumnTerminatorsAttributeName = CFSTR("NSTabColumnTerminatorsAttributeName");
#define K(x) ((__bridge NSString *)(x))

/* ---------------- text tabs ---------------- */
@interface __NSCTTextTab : NSObject { @public CTTextAlignment _align; double _loc; NSDictionary *_opts; }
@end
@implementation __NSCTTextTab
- (NSString *)description { return [NSString stringWithFormat:@"<CTTextTab %p> alignment %d location %g", self, _align, _loc]; }
- (BOOL)isEqual:(__NSCTTextTab *)o { return [o isKindOfClass:[__NSCTTextTab class]] && o->_align == _align && o->_loc == _loc; }
- (NSUInteger)hash { return (NSUInteger)(_loc * 16) + _align; }
@end
CFTypeID CTTextTabGetTypeID(void) { return 0x435b; }
CTTextTabRef CTTextTabCreate(CTTextAlignment a, double loc, CFDictionaryRef opts) {
    __NSCTTextTab *t = [__NSCTTextTab new];
    t->_align = a; t->_loc = loc; t->_opts = [(__bridge NSDictionary *)opts copy];
    return (CTTextTabRef)CFBridgingRetain(t);
}
CTTextAlignment CTTextTabGetAlignment(CTTextTabRef t) { return ((__bridge __NSCTTextTab *)t)->_align; }
double CTTextTabGetLocation(CTTextTabRef t) { return ((__bridge __NSCTTextTab *)t)->_loc; }
CFDictionaryRef CTTextTabGetOptions(CTTextTabRef t) { return (__bridge CFDictionaryRef)((__bridge __NSCTTextTab *)t)->_opts; }

/* ---------------- paragraph styles ---------------- */
@interface __NSCTParagraphStyle : NSObject { @public isim_ct_pstyle _s; NSArray *_tabs; }
@end
@implementation __NSCTParagraphStyle
- (NSString *)description { return [NSString stringWithFormat:@"<CTParagraphStyle %p> alignment %d", self, _s.align]; }
@end
/* Core Text's defaults: natural alignment, word wrapping, natural direction, 12 left tabs 28 points apart */
static NSArray *default_tabs(void) {
    static NSArray *tabs;
    if (!tabs) {
        NSMutableArray *a = [NSMutableArray array];
        for (int i = 1; i <= 12; i++) [a addObject:CFBridgingRelease(CTTextTabCreate(kCTTextAlignmentLeft, 28.0 * i, NULL))];
        tabs = a;
    }
    return tabs;
}
static void pstyle_defaults(isim_ct_pstyle *s) {
    memset(s, 0, sizeof *s);
    s->align = kCTTextAlignmentNatural; s->lineBreak = kCTLineBreakByWordWrapping; s->dir = kCTWritingDirectionNatural;
    s->maxLineSpacing = FLT_MAX;
}
CFTypeID CTParagraphStyleGetTypeID(void) { return 0x4356; }
CTParagraphStyleRef CTParagraphStyleCreate(const CTParagraphStyleSetting *set, size_t n) {
    __NSCTParagraphStyle *p = [__NSCTParagraphStyle new];
    isim_ct_pstyle *s = &p->_s;
    pstyle_defaults(s);
    for (size_t i = 0; set && i < n; i++) {
        const void *v = set[i].value;
        if (!v) continue;
        #define FLOAT(field) if (set[i].valueSize >= sizeof(CGFloat)) s->field = *(const CGFloat *)v
        switch (set[i].spec) {
        case kCTParagraphStyleSpecifierAlignment: s->align = *(const CTTextAlignment *)v; break;
        case kCTParagraphStyleSpecifierFirstLineHeadIndent: FLOAT(firstHead); break;
        case kCTParagraphStyleSpecifierHeadIndent: FLOAT(head); break;
        case kCTParagraphStyleSpecifierTailIndent: FLOAT(tail); break;
        case kCTParagraphStyleSpecifierTabStops: {
            NSMutableArray *tabs = [NSMutableArray array];
            for (id t in (__bridge NSArray *)*(const CFArrayRef *)v) if ([t isKindOfClass:[__NSCTTextTab class]]) [tabs addObject:t];
            [tabs sortUsingComparator:^NSComparisonResult(__NSCTTextTab *a, __NSCTTextTab *b) { return a->_loc < b->_loc ? NSOrderedAscending : a->_loc > b->_loc ? NSOrderedDescending : NSOrderedSame; }];
            p->_tabs = tabs;
            break;
        }
        case kCTParagraphStyleSpecifierDefaultTabInterval: FLOAT(defaultTab); break;
        case kCTParagraphStyleSpecifierLineBreakMode: s->lineBreak = *(const CTLineBreakMode *)v; break;
        case kCTParagraphStyleSpecifierLineHeightMultiple: FLOAT(lineHeightMultiple); break;
        case kCTParagraphStyleSpecifierMaximumLineHeight: FLOAT(maxLineHeight); break;
        case kCTParagraphStyleSpecifierMinimumLineHeight: FLOAT(minLineHeight); break;
        case kCTParagraphStyleSpecifierLineSpacing: FLOAT(lineSpacing); s->hasLineSpacing = YES; break;
        case kCTParagraphStyleSpecifierParagraphSpacing: FLOAT(paraSpacing); break;
        case kCTParagraphStyleSpecifierParagraphSpacingBefore: FLOAT(paraBefore); break;
        case kCTParagraphStyleSpecifierBaseWritingDirection: s->dir = *(const CTWritingDirection *)v; break;
        case kCTParagraphStyleSpecifierMaximumLineSpacing: FLOAT(maxLineSpacing); break;
        case kCTParagraphStyleSpecifierMinimumLineSpacing: FLOAT(minLineSpacing); break;
        case kCTParagraphStyleSpecifierLineSpacingAdjustment: FLOAT(lineSpacingAdjust); break;
        case kCTParagraphStyleSpecifierLineBoundsOptions: if (set[i].valueSize >= sizeof(CTLineBoundsOptions)) s->boundsOptions = *(const CTLineBoundsOptions *)v; break;
        default: break;
        }
        #undef FLOAT
    }
    if (!p->_tabs) p->_tabs = default_tabs();
    s->tabs = p->_tabs;
    return (CTParagraphStyleRef)CFBridgingRetain(p);
}
CTParagraphStyleRef CTParagraphStyleCreateCopy(CTParagraphStyleRef style) {
    __NSCTParagraphStyle *o = (__bridge __NSCTParagraphStyle *)style, *p = [__NSCTParagraphStyle new];
    p->_s = o->_s; p->_tabs = o->_tabs; p->_s.tabs = p->_tabs;
    return (CTParagraphStyleRef)CFBridgingRetain(p);
}
bool CTParagraphStyleGetValueForSpecifier(CTParagraphStyleRef style, CTParagraphStyleSpecifier spec, size_t size, void *buf) {
    if (!style || !buf) return false;
    __NSCTParagraphStyle *p = (__bridge __NSCTParagraphStyle *)style;
    const isim_ct_pstyle *s = &p->_s;
    #define PUT(type, value) do { if (size < sizeof(type)) return false; *(type *)buf = (value); return true; } while (0)
    switch (spec) {
    case kCTParagraphStyleSpecifierAlignment: PUT(CTTextAlignment, s->align);
    case kCTParagraphStyleSpecifierFirstLineHeadIndent: PUT(CGFloat, s->firstHead);
    case kCTParagraphStyleSpecifierHeadIndent: PUT(CGFloat, s->head);
    case kCTParagraphStyleSpecifierTailIndent: PUT(CGFloat, s->tail);
    case kCTParagraphStyleSpecifierTabStops: PUT(CFArrayRef, (__bridge CFArrayRef)p->_tabs);
    case kCTParagraphStyleSpecifierDefaultTabInterval: PUT(CGFloat, s->defaultTab);
    case kCTParagraphStyleSpecifierLineBreakMode: PUT(CTLineBreakMode, s->lineBreak);
    case kCTParagraphStyleSpecifierLineHeightMultiple: PUT(CGFloat, s->lineHeightMultiple);
    case kCTParagraphStyleSpecifierMaximumLineHeight: PUT(CGFloat, s->maxLineHeight);
    case kCTParagraphStyleSpecifierMinimumLineHeight: PUT(CGFloat, s->minLineHeight);
    case kCTParagraphStyleSpecifierLineSpacing: PUT(CGFloat, s->lineSpacing);
    case kCTParagraphStyleSpecifierParagraphSpacing: PUT(CGFloat, s->paraSpacing);
    case kCTParagraphStyleSpecifierParagraphSpacingBefore: PUT(CGFloat, s->paraBefore);
    case kCTParagraphStyleSpecifierBaseWritingDirection: PUT(CTWritingDirection, s->dir);
    case kCTParagraphStyleSpecifierMaximumLineSpacing: PUT(CGFloat, s->hasLineSpacing ? s->lineSpacing : s->maxLineSpacing);
    case kCTParagraphStyleSpecifierMinimumLineSpacing: PUT(CGFloat, s->hasLineSpacing ? s->lineSpacing : s->minLineSpacing);
    case kCTParagraphStyleSpecifierLineSpacingAdjustment: PUT(CGFloat, s->lineSpacingAdjust);
    case kCTParagraphStyleSpecifierLineBoundsOptions: PUT(CTLineBoundsOptions, s->boundsOptions);
    default: return false;
    }
    #undef PUT
}
@interface NSObject (IsimParagraphStyleDuck)
- (NSInteger)alignment; - (CGFloat)lineSpacing; - (CGFloat)firstLineHeadIndent; - (CGFloat)headIndent; - (CGFloat)tailIndent;
- (NSInteger)lineBreakMode; - (CGFloat)lineHeightMultiple; - (CGFloat)maximumLineHeight; - (CGFloat)minimumLineHeight;
- (CGFloat)paragraphSpacing; - (CGFloat)paragraphSpacingBefore; - (NSInteger)baseWritingDirection; - (NSArray *)tabStops;
- (CGFloat)defaultTabInterval; - (CGFloat)location;
@end
void isim_ct_pstyle_of(id ps, isim_ct_pstyle *s) {
    pstyle_defaults(s);
    s->tabs = default_tabs();
    if (!ps) return;
    if ([ps isKindOfClass:[__NSCTParagraphStyle class]]) { *s = ((__NSCTParagraphStyle *)ps)->_s; return; }
    if (![ps respondsToSelector:@selector(alignment)]) return;
    /* UIKit's NSParagraphStyle: NSTextAlignment is left 0, center 1, right 2, justified 3, natural 4 */
    NSInteger a = [ps alignment];
    s->align = a == 1 ? kCTTextAlignmentCenter : a == 2 ? kCTTextAlignmentRight : a == 3 ? kCTTextAlignmentJustified : a == 0 ? kCTTextAlignmentLeft : kCTTextAlignmentNatural;
    #define GET(sel, field) if ([ps respondsToSelector:@selector(sel)]) s->field = [ps sel]
    GET(lineSpacing, lineSpacingAdjust); GET(firstLineHeadIndent, firstHead); GET(headIndent, head); GET(tailIndent, tail);
    GET(lineHeightMultiple, lineHeightMultiple); GET(maximumLineHeight, maxLineHeight); GET(minimumLineHeight, minLineHeight);
    GET(paragraphSpacing, paraSpacing); GET(paragraphSpacingBefore, paraBefore); GET(defaultTabInterval, defaultTab);
    #undef GET
    if ([ps respondsToSelector:@selector(lineBreakMode)]) s->lineBreak = (CTLineBreakMode)[ps lineBreakMode];
    if ([ps respondsToSelector:@selector(baseWritingDirection)]) s->dir = (CTWritingDirection)[ps baseWritingDirection];
    if ([ps respondsToSelector:@selector(tabStops)]) {
        NSMutableArray *tabs = [NSMutableArray array];
        for (id t in [ps tabStops]) {
            if (![t respondsToSelector:@selector(location)]) continue;
            NSInteger ta = [t respondsToSelector:@selector(alignment)] ? [t alignment] : 0;
            [tabs addObject:CFBridgingRelease(CTTextTabCreate(ta == 1 ? kCTTextAlignmentCenter : ta == 2 ? kCTTextAlignmentRight : kCTTextAlignmentLeft, [t location], NULL))];
        }
        static char key;            /* kept alive with the style object */
        objc_setAssociatedObject(ps, &key, tabs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        s->tabs = tabs;
    }
}

/* ---------------- attributed string -> markup ---------------- */
static void escape_into(NSMutableString *m, NSString *s) {
    NSString *e = [[[s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]
                   stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    [m appendString:e];
}
static NSString *const STRETCH[] = { @"ultracondensed", @"extracondensed", @"condensed", @"semicondensed", @"normal",
                                     @"semiexpanded", @"expanded", @"extraexpanded", @"ultraexpanded" };
static void font_attrs(NSMutableString *m, id font) {
    __NSCTFont *c = isim_ct_font(font);
    if (!c) return;
    [m appendFormat:@" size=\"%ld\" weight=\"%d\"", lround(c.size * 1024), isim_ct_pango_weight(c.bold && c.weight < 0.3 ? 0.4 : c.weight)];
    NSString *family = isim_ct_family(c);
    if (family.length) { [m appendString:@" font_family=\""]; escape_into(m, family); [m appendString:@"\""]; }
    if (c.italic) [m appendString:@" style=\"italic\""];
    if (c.stretch != 4 && c.stretch >= 0 && c.stretch <= 8) [m appendFormat:@" stretch=\"%@\"", STRETCH[c.stretch]];
    NSString *ft = isim_ct_feature_tags(c.features);
    if (ft.length) [m appendFormat:@" font_features=\"%@\"", ft];
}
@interface NSObject (IsimCTColorDuck)
- (CGColorRef)CGColor;
@end
static BOOL color_rgba(id c, double v[4]) {
    if (!c) return NO;
    CGColorRef cg = NULL;
    if ([c respondsToSelector:@selector(CGColor)]) cg = [c CGColor];
    else if ([NSStringFromClass([c class]) isEqualToString:@"__NSCGColor"]) cg = (__bridge CGColorRef)c;
    if (!cg) return NO;
    isim_cg_color_rgba(cg, v);
    return YES;
}
static NSString *hex(const double v[4]) { return [NSString stringWithFormat:@"#%02x%02x%02x", (int)lround(v[0] * 255), (int)lround(v[1] * 255), (int)lround(v[2] * 255)]; }
NSString *isim_ct_markup(NSAttributedString *s, BOOL *fromContext) {
    NSMutableString *m = [NSMutableString stringWithString:@"<span size=\"12288\">"];
    if (fromContext) *fromContext = NO;
    [s enumerateAttributesInRange:NSMakeRange(0, s.length) options:0 usingBlock:^(NSDictionary *attrs, NSRange r, BOOL *stop) {
        if (fromContext && [attrs[K(kCTForegroundColorFromContextAttributeName)] boolValue]) *fromContext = YES;
        NSMutableString *span = [NSMutableString stringWithString:@"<span"];
        font_attrs(span, attrs[K(kCTFontAttributeName)]);
        double c[4];
        if (color_rgba(attrs[K(kCTForegroundColorAttributeName)] ?: attrs[@"NSColor"], c))
            [span appendFormat:@" foreground=\"%@\" fgalpha=\"%d%%\"", hex(c), (int)fmax(1, lround(c[3] * 100))];
        if (color_rgba(attrs[@"NSBackgroundColor"], c)) [span appendFormat:@" background=\"%@\" bgalpha=\"%d%%\"", hex(c), (int)fmax(1, lround(c[3] * 100))];
        double kern = [attrs[K(kCTKernAttributeName)] doubleValue];
        if (kern) [span appendFormat:@" letter_spacing=\"%ld\"", lround(kern * 1024)];
        NSInteger ul = [attrs[K(kCTUnderlineStyleAttributeName)] integerValue];
        if (ul) [span appendFormat:@" underline=\"%@\"", (ul & 0xff) == 0x09 ? @"double" : @"single"];
        if ([attrs[@"NSStrikethrough"] integerValue]) [span appendString:@" strikethrough=\"true\""];
        double rise = [(attrs[K(kCTBaselineOffsetAttributeName)] ?: attrs[@"NSBaselineOffset"]) doubleValue];
        if (rise) [span appendFormat:@" rise=\"%ld\"", lround(rise * 1024)];
        [span appendString:@">"];
        [m appendString:span];
        escape_into(m, [s.string substringWithRange:r]);
        [m appendString:@"</span>"];
    }];
    [m appendString:@"</span>"];
    return m;
}

/* ---------------- paragraph layouts ---------------- */
/* One Pango layout: a paragraph of a frame, or a line's whole string. _loc/_len: its text in _s (UTF-16), _term: the
 * paragraph separator after it (counted in the last line's range, not laid out). */
@interface __NSCTPara : NSObject {
@public void *_l; NSAttributedString *_s; NSUInteger _loc, _len, _term; NSUInteger *_u16; long _nbytes; BOOL _fromContext;
        isim_ct_pstyle _ps; NSArray *_tabs; double _base, _end;
}
@end
@implementation __NSCTPara
- (void)dealloc { isim_ct_layout_free(_l); free(_u16); }
- (NSUInteger)u16:(long)byte { return _loc + _u16[byte < 0 ? 0 : byte > _nbytes ? _nbytes : byte]; }
- (long)byte:(NSUInteger)u16 {
    NSUInteger rel = u16 > _loc ? u16 - _loc : 0;
    for (long b = 0; b <= _nbytes; b++) if (_u16[b] >= rel) return b;
    return _nbytes;
}
@end
static int wrap_of(CTLineBreakMode m) { return m == kCTLineBreakByCharWrapping ? 1 : m == kCTLineBreakByClipping ? 2 : m == kCTLineBreakByTruncatingHead ? 3 : m == kCTLineBreakByTruncatingTail ? 4 : m == kCTLineBreakByTruncatingMiddle ? 5 : 0; }
/* width: the frame's width (0: unwrapped); single: a CTLine (1, or 2/3/4 truncated at the start / middle / end) */
static __NSCTPara *make_para(NSAttributedString *s, NSRange r, NSUInteger term, double width, int single) {
    __NSCTPara *p = [__NSCTPara new];
    p->_s = s; p->_loc = r.location; p->_len = r.length; p->_term = term;
    NSUInteger at = r.length || term ? r.location : (r.location ? r.location - 1 : 0);
    NSDictionary *attrs = s.length && at < s.length ? [s attributesAtIndex:at effectiveRange:NULL] : @{};
    isim_ct_pstyle_of(attrs[K(kCTParagraphStyleAttributeName)], &p->_ps);
    p->_tabs = p->_ps.tabs; p->_ps.tabs = p->_tabs;
    const isim_ct_pstyle *ps = &p->_ps;
    NSAttributedString *text = [s attributedSubstringFromRange:r];
    NSString *mk = isim_ct_markup(text, &p->_fromContext);
    struct isim_ct_para hp; memset(&hp, 0, sizeof hp);
    hp.dir = ps->dir < 0 ? -1 : ps->dir;
    hp.align = ps->align;
    if (single) {
        hp.single = 1;
        if (single >= 2 && width > 0) { hp.width = width; hp.wrap = single == 2 ? 3 : single == 3 ? 5 : 4; }
        p->_base = 0; p->_end = width;
    } else {
        /* Pango wraps from the nearer indent; the first line's offset from it is Pango's indent (negative: hanging) */
        p->_base = fmin(ps->firstHead, ps->head);
        p->_end = width <= 0 ? 0 : ps->tail > 0 ? ps->tail : width + ps->tail;
        hp.width = width > 0 ? fmax(1, p->_end - p->_base) : 0;
        hp.indent = ps->firstHead - ps->head;
        hp.wrap = wrap_of(ps->lineBreak);
    }
    /* tab stops from the paragraph's leading edge, then every default tab interval */
    NSArray *tabs = p->_tabs;
    int nt = 0;
    double last = 0;
    for (__NSCTTextTab *t in tabs) {
        if (![t isKindOfClass:[__NSCTTextTab class]] || nt >= 64) continue;
        hp.tab_pos[nt] = t->_loc - p->_base;
        hp.tab_align[nt] = t->_opts[K(kCTTabColumnTerminatorsAttributeName)] ? 5 : t->_align == kCTTextAlignmentNatural ? 0 : t->_align;
        last = t->_loc; nt++;
    }
    for (int k = 1; ps->defaultTab > 0 && nt < 64; k++) {
        double loc = ceil((last + 0.01) / ps->defaultTab) * ps->defaultTab + (k - 1) * ps->defaultTab;
        hp.tab_pos[nt] = loc - p->_base; hp.tab_align[nt] = 0; nt++;
    }
    hp.tabs = nt;
    /* an empty paragraph is as tall as its separator's font */
    __NSCTFont *f = isim_ct_font(attrs[K(kCTFontAttributeName)]);
    if (f) {
        NSString *fam = isim_ct_family(f);
        if (fam.length) snprintf(hp.family, sizeof hp.family, "%s", fam.UTF8String);
        hp.weight = isim_ct_pango_weight(f.bold && f.weight < 0.3 ? 0.4 : f.weight); hp.italic = f.italic; hp.size = f.size;
    }
    p->_l = isim_ct_layout_create_para(mk.UTF8String, &hp);
    /* UTF-8 byte offset -> UTF-16 index (relative to _loc) */
    const char *u8 = text.string.UTF8String;
    p->_nbytes = (long)strlen(u8);
    p->_u16 = calloc((size_t)p->_nbytes + 1, sizeof *p->_u16);
    NSUInteger k = 0; long b = 0;
    while (b < p->_nbytes) {
        unsigned char c = (unsigned char)u8[b];
        int n = c < 0x80 ? 1 : c < 0xe0 ? 2 : c < 0xf0 ? 3 : 4;
        for (int i = 0; i < n && b + i <= p->_nbytes; i++) p->_u16[b + i] = k;
        b += n; k += n == 4 ? 2 : 1;
    }
    p->_u16[p->_nbytes] = k;
    return p;
}
/* paragraphs of s within r: split after \n, \r, \r\n and U+2029 */
static NSArray<__NSCTPara *> *make_paras(NSAttributedString *s, NSRange r, double width) {
    NSMutableArray *a = [NSMutableArray array];
    NSString *str = s.string;
    NSUInteger i = r.location, end = NSMaxRange(r);
    while (i < end || (i == end && !a.count)) {
        NSUInteger j = i;
        while (j < end) { unichar c = [str characterAtIndex:j]; if (c == '\n' || c == '\r' || c == 0x2029) break; j++; }
        NSUInteger term = 0;
        if (j < end) { term = [str characterAtIndex:j] == '\r' && j + 1 < end && [str characterAtIndex:j + 1] == '\n' ? 2 : 1; }
        [a addObject:make_para(s, NSMakeRange(i, j - i), term, width, 0)];
        i = j + term;
        if (!term) break;
    }
    return a;
}

/* ---------------- lines and runs ---------------- */
@interface __NSCTLine : NSObject {
@public __NSCTPara *_para; int _line; struct isim_ct_line _m; double _x, _baseline; CFRange _range; NSArray *_runs;
}
@end
@interface __NSCTRun : NSObject {
@public __NSCTPara *_para; int _lineIndex, _index; struct isim_ct_run _info; CFIndex _n; CGGlyph *_glyphs; CGPoint *_pos, *_origins; CGSize *_adv;
        CFIndex *_idx; CFRange _range; NSDictionary *_attrs; CTRunStatus _status;
}
@end
@implementation __NSCTRun
- (void)dealloc { free(_glyphs); free(_pos); free(_origins); free(_adv); free(_idx); }
- (NSString *)description { return [NSString stringWithFormat:@"<CTRun %p> %ld glyphs, range {%ld, %ld}, font %s %gpt%s", self, (long)_n, (long)_range.location, (long)_range.length, _info.family, _info.size, _status & kCTRunStatusRightToLeft ? ", right-to-left" : ""]; }
@end
/* the system font Pango falls back to for unset fonts (12 pt, as CTFont's default) */
static __NSCTFont *default_font(void) {
    static __NSCTFont *f;
    if (!f) f = CFBridgingRelease(CTFontCreateWithName(CFSTR(".SFUI-Regular"), 12, NULL));
    return f;
}
/* the run's attributes, with the font that drew it (the requested one, or the fallback that had the characters) */
static NSDictionary *run_attributes(__NSCTRun *r) {
    NSAttributedString *s = r->_para->_s;
    NSUInteger at = (NSUInteger)r->_range.location;
    NSMutableDictionary *a = [(s.length && at < s.length ? [s attributesAtIndex:at effectiveRange:NULL] : @{}) mutableCopy];
    id font = a[K(kCTFontAttributeName)];
    __NSCTFont *want = isim_ct_font(font) ?: default_font();
    const char *used = want.info->family;
    if (r->_info.family[0] && strcmp(used, r->_info.family) != 0)
        a[K(kCTFontAttributeName)] = isim_ct_font_from_host(r->_info.family, r->_info.weight, r->_info.italic, r->_info.stretch, r->_info.size);
    else if (!font) a[K(kCTFontAttributeName)] = want;
    return a;
}
@implementation __NSCTLine
- (NSString *)description { return [NSString stringWithFormat:@"<CTLine %p> range {%ld, %ld}, width %g", self, (long)_range.location, (long)_range.length, _m.width]; }
- (NSArray *)runs {
    if (_runs) return _runs;
    void *l = _para->_l;
    int n = isim_ct_line_runs(l, _line, NULL, 0);
    struct isim_ct_run *info = calloc((size_t)(n ? n : 1), sizeof *info);
    isim_ct_line_runs(l, _line, info, n);
    NSMutableArray *a = [NSMutableArray array];
    for (int i = 0; i < n; i++) {
        __NSCTRun *r = [__NSCTRun new];
        r->_para = _para; r->_lineIndex = _line; r->_index = i; r->_info = info[i]; r->_n = info[i].glyphs;
        size_t gn = (size_t)(r->_n ? r->_n : 1);
        unsigned short *g = calloc(gn, sizeof *g); double *pos = calloc(gn * 2, sizeof *pos), *adv = calloc(gn, sizeof *adv); int *idx = calloc(gn, sizeof *idx);
        isim_ct_run_glyphs(l, _line, i, g, pos, adv, idx, (int)r->_n);
        r->_glyphs = calloc(gn, sizeof *r->_glyphs); r->_pos = calloc(gn, sizeof *r->_pos); r->_origins = calloc(gn, sizeof *r->_origins);
        r->_adv = calloc(gn, sizeof *r->_adv); r->_idx = calloc(gn, sizeof *r->_idx);
        double pen = info[i].x;
        BOOL mono = YES;
        for (CFIndex k = 0; k < r->_n; k++) {
            r->_glyphs[k] = g[k]; r->_pos[k] = CGPointMake(pos[2 * k], pos[2 * k + 1]); r->_adv[k] = CGSizeMake(adv[k], 0);
            r->_origins[k] = CGPointMake(pos[2 * k] - pen, pos[2 * k + 1]);
            pen += adv[k];
            r->_idx[k] = (CFIndex)[_para u16:idx[k]];
            if (k && (info[i].rtl ? r->_idx[k] > r->_idx[k - 1] : r->_idx[k] < r->_idx[k - 1])) mono = NO;
        }
        free(g); free(pos); free(adv); free(idx);
        NSUInteger a0 = [_para u16:info[i].start], a1 = [_para u16:info[i].start + info[i].len];
        r->_range = CFRangeMake((CFIndex)a0, (CFIndex)(a1 - a0));
        r->_status = (info[i].rtl ? kCTRunStatusRightToLeft : 0) | (mono ? 0 : kCTRunStatusNonMonotonic);
        [a addObject:r];
    }
    free(info);
    /* Pango keeps runs in visual order; Core Text's are in string order */
    [a sortUsingComparator:^NSComparisonResult(__NSCTRun *x, __NSCTRun *y) {
        return x->_range.location < y->_range.location ? NSOrderedAscending : x->_range.location > y->_range.location ? NSOrderedDescending : NSOrderedSame;
    }];
    _runs = a;
    return a;
}
@end
static __NSCTLine *make_line(__NSCTPara *p, int i, int count) {
    __NSCTLine *l = [__NSCTLine new];
    l->_para = p; l->_line = i;
    isim_ct_line_metrics(p->_l, i, &l->_m);
    NSUInteger a = [p u16:l->_m.start], b = [p u16:l->_m.start + l->_m.len];
    if (i == count - 1) b = p->_loc + p->_len + p->_term;           /* the last line holds the paragraph separator */
    l->_range = CFRangeMake((CFIndex)a, (CFIndex)(b - a));
    l->_baseline = l->_m.ascent;
    return l;
}
static __NSCTLine *L(CTLineRef l) { return (__bridge __NSCTLine *)l; }
static __NSCTRun *R(CTRunRef r) { return (__bridge __NSCTRun *)r; }

CFTypeID CTLineGetTypeID(void) { return 0x4357; }
CFTypeID CTRunGetTypeID(void) { return 0x4358; }
CFTypeID CTFramesetterGetTypeID(void) { return 0x4359; }
CFTypeID CTFrameGetTypeID(void) { return 0x435a; }

static __NSCTLine *single_line(NSAttributedString *s, NSRange r, double width, int single) {
    __NSCTPara *p = make_para(s, r, 0, width, single);
    return make_line(p, 0, 1);
}
CTLineRef CTLineCreateWithAttributedString(CFAttributedStringRef s) {
    NSAttributedString *a = [(__bridge NSAttributedString *)s copy];
    return (CTLineRef)CFBridgingRetain(single_line(a, NSMakeRange(0, a.length), 0, 1));
}
CTLineRef CTLineCreateTruncatedLine(CTLineRef line, double width, CTLineTruncationType type, CTLineRef token) {
    __NSCTLine *o = L(line);
    if (o->_m.width <= width) return CFBridgingRetain(o);
    NSRange r = NSMakeRange((NSUInteger)o->_range.location, (NSUInteger)o->_range.length);
    return (CTLineRef)CFBridgingRetain(single_line(o->_para->_s, r, width, type == kCTLineTruncationStart ? 2 : type == kCTLineTruncationMiddle ? 3 : 4));
}
CTLineRef CTLineCreateJustifiedLine(CTLineRef line, CGFloat factor, double width) { return CFBridgingRetain(L(line)); }
CFIndex CTLineGetGlyphCount(CTLineRef line) { CFIndex n = 0; for (__NSCTRun *r in [L(line) runs]) n += r->_n; return n; }
CFArrayRef CTLineGetGlyphRuns(CTLineRef line) { return (__bridge CFArrayRef)[L(line) runs]; }
CFRange CTLineGetStringRange(CTLineRef line) { return L(line)->_range; }
double CTLineGetPenOffsetForFlush(CTLineRef line, CGFloat f, double w) { double d = w - (L(line)->_m.width - L(line)->_m.trailing); return d > 0 ? d * fmax(0, fmin(1, f)) : 0; }
double CTLineGetTypographicBounds(CTLineRef line, CGFloat *a, CGFloat *d, CGFloat *lead) {
    __NSCTLine *l = L(line);
    if (a) *a = l->_m.ascent; if (d) *d = l->_m.descent; if (lead) *lead = l->_m.leading;
    return l->_m.width;
}
CGRect CTLineGetBoundsWithOptions(CTLineRef line, CTLineBoundsOptions o) {
    __NSCTLine *l = L(line);
    if (o & kCTLineBoundsUseGlyphPathBounds) return CGRectMake(l->_m.ink[0], l->_m.ink[1], l->_m.ink[2], l->_m.ink[3]);
    double lead = o & kCTLineBoundsExcludeTypographicLeading ? 0 : l->_m.leading;
    return CGRectMake(0, -l->_m.descent - lead, l->_m.width, l->_m.ascent + l->_m.descent + lead);
}
double CTLineGetTrailingWhitespaceWidth(CTLineRef line) { return L(line)->_m.trailing; }
CGRect CTLineGetImageBounds(CTLineRef line, CGContextRef c) {
    __NSCTLine *l = L(line);
    CGPoint p = c ? CGContextGetTextPosition(c) : CGPointZero;
    if (l->_m.ink[2] <= 0) return CGRectMake(p.x, p.y, 0, 0);
    return CGRectMake(p.x + l->_m.ink[0], p.y + l->_m.ink[1], l->_m.ink[2], l->_m.ink[3]);
}
CFIndex CTLineGetStringIndexForPosition(CTLineRef line, CGPoint pos) {
    __NSCTLine *l = L(line);
    if (pos.x >= l->_m.width) return l->_range.location + l->_range.length;
    return (CFIndex)[l->_para u16:isim_ct_line_index_at(l->_para->_l, l->_line, pos.x)];
}
CGFloat CTLineGetOffsetForStringIndex(CTLineRef line, CFIndex idx, CGFloat *secondary) {
    __NSCTLine *l = L(line);
    CGFloat x = isim_ct_line_x_at(l->_para->_l, l->_line, (int)[l->_para byte:(NSUInteger)idx]);
    if (secondary) *secondary = x;
    return x;
}
static void draw_line(__NSCTLine *l, CGContextRef c, double dx, double dy) {
    double black[4] = { 0, 0, 0, 1 };
    isim_cg_context_draw_text_line(c, l->_para->_l, l->_line, dx, dy, l->_para->_fromContext ? NULL : black, 0);
}
void CTLineDraw(CTLineRef line, CGContextRef c) { if (line && c) draw_line(L(line), c, 0, 0); }

CFIndex CTRunGetGlyphCount(CTRunRef r) { return R(r)->_n; }
CFDictionaryRef CTRunGetAttributes(CTRunRef r) {
    __NSCTRun *run = R(r);
    if (!run->_attrs) run->_attrs = run_attributes(run);
    return (__bridge CFDictionaryRef)run->_attrs;
}
CTRunStatus CTRunGetStatus(CTRunRef r) { return R(r)->_status; }
static CFRange clamp_range(__NSCTRun *r, CFRange range) {
    if (range.location < 0 || range.location > r->_n) range.location = r->_n;
    if (range.length == 0) range.length = r->_n - range.location;
    if (range.location + range.length > r->_n) range.length = r->_n - range.location;
    return range;
}
const CGGlyph *CTRunGetGlyphsPtr(CTRunRef r) { return R(r)->_glyphs; }
void CTRunGetGlyphs(CTRunRef r, CFRange range, CGGlyph *buf) { range = clamp_range(R(r), range); memcpy(buf, R(r)->_glyphs + range.location, sizeof *buf * (size_t)range.length); }
const CGPoint *CTRunGetPositionsPtr(CTRunRef r) { return R(r)->_pos; }
void CTRunGetPositions(CTRunRef r, CFRange range, CGPoint *buf) { range = clamp_range(R(r), range); memcpy(buf, R(r)->_pos + range.location, sizeof *buf * (size_t)range.length); }
const CGSize *CTRunGetAdvancesPtr(CTRunRef r) { return R(r)->_adv; }
void CTRunGetAdvances(CTRunRef r, CFRange range, CGSize *buf) { range = clamp_range(R(r), range); memcpy(buf, R(r)->_adv + range.location, sizeof *buf * (size_t)range.length); }
const CFIndex *CTRunGetStringIndicesPtr(CTRunRef r) { return R(r)->_idx; }
void CTRunGetStringIndices(CTRunRef r, CFRange range, CFIndex *buf) { range = clamp_range(R(r), range); memcpy(buf, R(r)->_idx + range.location, sizeof *buf * (size_t)range.length); }
CFRange CTRunGetStringRange(CTRunRef r) { return R(r)->_range; }
void CTRunGetBaseAdvancesAndOrigins(CTRunRef r, CFRange range, CGSize *adv, CGPoint *origins) {
    range = clamp_range(R(r), range);
    if (adv) memcpy(adv, R(r)->_adv + range.location, sizeof *adv * (size_t)range.length);
    if (origins) memcpy(origins, R(r)->_origins + range.location, sizeof *origins * (size_t)range.length);
}
double CTRunGetTypographicBounds(CTRunRef r, CFRange range, CGFloat *a, CGFloat *d, CGFloat *lead) {
    __NSCTRun *run = R(r); range = clamp_range(run, range);
    if (a) *a = run->_info.ascent; if (d) *d = run->_info.descent; if (lead) *lead = run->_info.leading;
    double w = 0; for (CFIndex i = range.location; i < range.location + range.length; i++) w += run->_adv[i].width;
    return w;
}
CGRect CTRunGetImageBounds(CTRunRef r, CGContextRef c, CFRange range) {
    __NSCTRun *run = R(r); range = clamp_range(run, range);
    double ink[4];
    isim_ct_run_ink(run->_para->_l, run->_lineIndex, run->_index, (int)range.location, (int)range.length, ink);
    CGPoint p = c ? CGContextGetTextPosition(c) : CGPointZero;
    return CGRectMake(p.x + ink[0], p.y + ink[1], ink[2], ink[3]);
}
CGAffineTransform CTRunGetTextMatrix(CTRunRef r) { return CGAffineTransformIdentity; }
void CTRunDraw(CTRunRef r, CGContextRef c, CFRange range) {
    __NSCTRun *run = R(r);
    if (!c) return;
    range = clamp_range(run, range);
    if (!range.length) return;
    /* the run's line, clipped to the pen extent of the glyphs in the range (in text space) */
    double x0 = run->_pos[range.location].x - run->_origins[range.location].x, w = 0;
    for (CFIndex i = range.location; i < range.location + range.length; i++) w += run->_adv[i].width;
    CGPoint p = CGContextGetTextPosition(c);
    CGAffineTransform tm = CGContextGetTextMatrix(c), t = CGAffineTransformMake(tm.a, tm.b, tm.c, tm.d, p.x + tm.tx, p.y + tm.ty);
    CGContextSaveGState(c);
    CGContextConcatCTM(c, t);
    CGContextClipToRect(c, CGRectMake(x0, -1e4, w, 2e4));
    CGContextConcatCTM(c, CGAffineTransformInvert(t));
    isim_cg_context_draw_text_line(c, run->_para->_l, run->_lineIndex, 0, 0, run->_para->_fromContext ? NULL : (double[]){ 0, 0, 0, 1 }, 0);
    CGContextRestoreGState(c);
}

/* ---------------- framesetters and frames ---------------- */
@interface __NSCTFramesetter : NSObject { @public NSAttributedString *_s; }
@end
@implementation __NSCTFramesetter
@end
@interface __NSCTFrame : NSObject { @public NSArray *_paras, *_lines; CGPoint *_origins; CGPathRef _path; CFRange _range, _visible; CGRect _rect; }
@end
@implementation __NSCTFrame
- (void)dealloc { free(_origins); if (_path) CGPathRelease(_path); }
@end
/* Places the paragraphs' lines in a box of width w (0: unwrapped) and height h: line heights (natural, times the
 * multiple, within the minimum and maximum), the spacing between lines (the leading plus the adjustment, within the
 * minimum and maximum line spacing), paragraph spacing before and after, and each line's x for the alignment and
 * indents. Lines that do not fit in h are left out. Returns the lines; *usedWidth: the widest line with its indent. */
static NSArray<__NSCTLine *> *place(NSArray<__NSCTPara *> *paras, double w, double h, double *usedWidth, double *usedHeight) {
    NSMutableArray *out = [NSMutableArray array];
    double y = 0, used = 0, prevLeading = 0, prevAfter = 0;
    BOOL first = YES, full = NO;
    for (__NSCTPara *p in paras) {
        const isim_ct_pstyle *s = &p->_ps;
        int n = isim_ct_layout_lines(p->_l);
        for (int i = 0; i < n && !full; i++) {
            __NSCTLine *l = make_line(p, i, n);
            double lh = l->_m.ascent + l->_m.descent;
            if (s->lineHeightMultiple > 0) lh *= s->lineHeightMultiple;
            if (s->minLineHeight > 0) lh = fmax(lh, s->minLineHeight);
            if (s->maxLineHeight > 0) lh = fmin(lh, s->maxLineHeight);
            double gap = 0;
            if (!first) {
                gap = prevLeading + s->lineSpacingAdjust;
                double lo = s->hasLineSpacing ? s->lineSpacing : s->minLineSpacing, hi = s->hasLineSpacing ? s->lineSpacing : s->maxLineSpacing;
                gap = fmin(fmax(gap, lo), hi);
                if (i == 0) gap += prevAfter;
            }
            if (i == 0) gap += s->paraBefore;
            double baseline = y + gap + lh - l->_m.descent;
            if (h > 0 && baseline + l->_m.descent > h + 0.5) { full = YES; break; }
            l->_baseline = baseline;
            y = baseline + l->_m.descent;
            prevLeading = l->_m.leading;
            first = NO;
            /* x: the region between the indents, mirrored for right-to-left paragraphs; the line's content (without
             * trailing whitespace) aligned in it */
            BOOL rtl = s->dir == kCTWritingDirectionRightToLeft || (s->dir == kCTWritingDirectionNatural && l->_m.rtl);
            double start = l->_m.para_start ? s->firstHead : s->head;
            double region = w > 0 ? p->_end - start : l->_m.width - l->_m.trailing;
            double cw = l->_m.width - l->_m.trailing, cl = rtl ? l->_m.trailing : 0;
            double left = w > 0 && rtl ? w - (start + region) : start;
            CTTextAlignment a = s->align;
            if (a == kCTTextAlignmentNatural || a == kCTTextAlignmentJustified) a = rtl ? kCTTextAlignmentRight : kCTTextAlignmentLeft;
            double target = a == kCTTextAlignmentRight ? left + region - cw : a == kCTTextAlignmentCenter ? left + (region - cw) / 2 : left;
            l->_x = target - cl;
            used = fmax(used, start + cw);
            [out addObject:l];
        }
        if (full) break;
        prevAfter = s->paraSpacing;
    }
    if (usedWidth) *usedWidth = used;
    if (usedHeight) *usedHeight = y;
    return out;
}
static NSRange frame_range(NSAttributedString *s, CFRange r) {
    NSUInteger loc = r.location > 0 ? (NSUInteger)r.location : 0;
    if (loc > s.length) loc = s.length;
    NSUInteger len = r.length > 0 ? (NSUInteger)r.length : s.length - loc;
    if (loc + len > s.length) len = s.length - loc;
    return NSMakeRange(loc, len);
}
CTFramesetterRef CTFramesetterCreateWithAttributedString(CFAttributedStringRef s) {
    __NSCTFramesetter *f = [__NSCTFramesetter new]; f->_s = [(__bridge NSAttributedString *)s copy];
    return (CTFramesetterRef)CFBridgingRetain(f);
}
CTFrameRef CTFramesetterCreateFrame(CTFramesetterRef fs, CFRange range, CGPathRef path, CFDictionaryRef attrs) {
    __NSCTFramesetter *f = (__bridge __NSCTFramesetter *)fs;
    NSRange r = frame_range(f->_s, range);
    __NSCTFrame *fr = [__NSCTFrame new];
    fr->_rect = CGPathGetBoundingBox(path);
    fr->_path = CGPathRetain(path);
    fr->_paras = make_paras(f->_s, r, fr->_rect.size.width);
    fr->_lines = place(fr->_paras, fr->_rect.size.width, fr->_rect.size.height, NULL, NULL);
    NSUInteger n = fr->_lines.count;
    fr->_origins = calloc(n ? n : 1, sizeof(CGPoint));
    CFIndex end = (CFIndex)r.location;
    for (NSUInteger i = 0; i < n; i++) {
        __NSCTLine *l = fr->_lines[i];
        fr->_origins[i] = CGPointMake(l->_x, fr->_rect.size.height - l->_baseline);
        end = l->_range.location + l->_range.length;
    }
    fr->_range = CFRangeMake((CFIndex)r.location, (CFIndex)r.length);
    fr->_visible = CFRangeMake((CFIndex)r.location, end - (CFIndex)r.location);
    return (CTFrameRef)CFBridgingRetain(fr);
}
CGSize CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterRef fs, CFRange range, CFDictionaryRef attrs, CGSize cons, CFRange *fit) {
    __NSCTFramesetter *f = (__bridge __NSCTFramesetter *)fs;
    NSRange r = frame_range(f->_s, range);
    double w = cons.width > 0 && cons.width < 1e7 ? cons.width : 0, h = cons.height > 0 && cons.height < 1e7 ? cons.height : 0;
    double uw = 0, uh = 0;
    NSArray<__NSCTLine *> *lines = place(make_paras(f->_s, r, w), w, h, &uw, &uh);
    CFIndex end = (CFIndex)r.location;
    for (__NSCTLine *l in lines) end = l->_range.location + l->_range.length;
    if (fit) *fit = CFRangeMake((CFIndex)r.location, end - (CFIndex)r.location);
    return CGSizeMake(w > 0 ? fmin(uw, w) : uw, uh);
}
static __NSCTFrame *FR(CTFrameRef f) { return (__bridge __NSCTFrame *)f; }
CFRange CTFrameGetStringRange(CTFrameRef f) { return FR(f)->_range; }
CFRange CTFrameGetVisibleStringRange(CTFrameRef f) { return FR(f)->_visible; }
CGPathRef CTFrameGetPath(CTFrameRef f) { return FR(f)->_path; }
CFArrayRef CTFrameGetLines(CTFrameRef f) { return (__bridge CFArrayRef)FR(f)->_lines; }
void CTFrameGetLineOrigins(CTFrameRef f, CFRange range, CGPoint *origins) {
    __NSCTFrame *fr = FR(f);
    CFIndex n = (CFIndex)fr->_lines.count;
    if (range.length == 0) range.length = n - range.location;
    for (CFIndex i = 0; i < range.length && range.location + i < n; i++) origins[i] = fr->_origins[range.location + i];
}
void CTFrameDraw(CTFrameRef f, CGContextRef c) {
    __NSCTFrame *fr = FR(f);
    if (!c) return;
    CGPoint saved = CGContextGetTextPosition(c);
    for (NSUInteger i = 0; i < fr->_lines.count; i++) {
        CGContextSetTextPosition(c, fr->_rect.origin.x + fr->_origins[i].x, fr->_rect.origin.y + fr->_origins[i].y);
        draw_line(fr->_lines[i], c, 0, 0);
    }
    CGContextSetTextPosition(c, saved.x, saved.y);
}
