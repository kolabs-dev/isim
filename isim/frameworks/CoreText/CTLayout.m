// isim CoreText layout: CTLine, CTRun, CTFramesetter, CTFrame and CTParagraphStyle over Pango layouts of the
// attributed string's markup (host_cg.c). String indices are UTF-16 (NSString) indices, mapped from Pango's UTF-8.
#import <Foundation/Foundation.h>
#include <CoreText/CoreText.h>
#include <isim_host.h>
#include <isim_host_cg.h>
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

/* ---------------- paragraph styles ---------------- */
@interface __NSCTParagraphStyle : NSObject { @public CTTextAlignment _align; CGFloat _spacing, _lineHeightMultiple, _paraSpacing; }
@end
@implementation __NSCTParagraphStyle
@end
CFTypeID CTParagraphStyleGetTypeID(void) { return 0x4356; }
CTParagraphStyleRef CTParagraphStyleCreate(const CTParagraphStyleSetting *s, size_t n) {
    __NSCTParagraphStyle *p = [__NSCTParagraphStyle new];
    p->_align = kCTTextAlignmentNatural;
    for (size_t i = 0; s && i < n; i++) {
        if (!s[i].value) continue;
        switch (s[i].spec) {
        case kCTParagraphStyleSpecifierAlignment: p->_align = *(const CTTextAlignment *)s[i].value; break;
        case kCTParagraphStyleSpecifierLineSpacingAdjustment: p->_spacing = *(const CGFloat *)s[i].value; break;
        case kCTParagraphStyleSpecifierLineHeightMultiple: p->_lineHeightMultiple = *(const CGFloat *)s[i].value; break;
        case kCTParagraphStyleSpecifierParagraphSpacing: p->_paraSpacing = *(const CGFloat *)s[i].value; break;
        default: break;
        }
    }
    return (CTParagraphStyleRef)CFBridgingRetain(p);
}
bool CTParagraphStyleGetValueForSpecifier(CTParagraphStyleRef style, CTParagraphStyleSpecifier spec, size_t size, void *buf) {
    __NSCTParagraphStyle *p = (__bridge __NSCTParagraphStyle *)style;
    if (spec == kCTParagraphStyleSpecifierAlignment && size >= sizeof(CTTextAlignment)) { *(CTTextAlignment *)buf = p->_align; return true; }
    if (spec == kCTParagraphStyleSpecifierLineSpacingAdjustment && size >= sizeof(CGFloat)) { *(CGFloat *)buf = p->_spacing; return true; }
    return false;
}

/* ---------------- attributed string -> markup ---------------- */
@interface NSObject (IsimCTFontDuck)
- (NSString *)_isim_family; - (CGFloat)_isim_weight; - (BOOL)_isim_mono; - (CGFloat)pointSize; - (CGColorRef)CGColor; - (NSInteger)alignment; - (CGFloat)lineSpacing;
@end
static void escape_into(NSMutableString *m, NSString *s) {
    NSString *e = [[[s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]
                   stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    [m appendString:e];
}
static int css_weight(double w) {
    return w < -0.6 ? 100 : w < -0.3 ? 200 : w < -0.1 ? 300 : w < 0.1 ? 400 : w < 0.26 ? 500 : w < 0.35 ? 600 : w < 0.5 ? 700 : w < 0.6 ? 800 : 900;
}
static NSString *feature_tags(NSArray *features) {
    NSMutableArray *tags = [NSMutableArray array];
    for (NSDictionary *f in features) {
        NSString *tag = f[(__bridge NSString *)kCTFontOpenTypeFeatureTag];
        if (tag.length == 4) { [tags addObject:[NSString stringWithFormat:@"%@ %d", tag, f[(__bridge NSString *)kCTFontOpenTypeFeatureValue] ? [f[(__bridge NSString *)kCTFontOpenTypeFeatureValue] intValue] : 1]]; continue; }
        int type = [f[(__bridge NSString *)kCTFontFeatureTypeIdentifierKey] intValue], sel = [f[(__bridge NSString *)kCTFontFeatureSelectorIdentifierKey] intValue];
        if (type == 6) [tags addObject:sel == 0 ? @"tnum 1" : @"pnum 1"];                 /* number spacing: monospaced / proportional */
        else if (type == 37 && sel == 1) [tags addObject:@"smcp 1"];                      /* lower case: small caps */
        else if (type == 38 && sel == 1) [tags addObject:@"c2sc 1"];                      /* upper case: small caps */
        else if (type == 1 && sel == 3) [tags addObject:@"liga 0"];                       /* common ligatures off */
        else if (type == 1 && sel == 2) [tags addObject:@"liga 1"];
        else if (type == 21 && sel == 0) [tags addObject:@"lnum 1"];                      /* number case: lining */
        else if (type == 21 && sel == 1) [tags addObject:@"onum 1"];
    }
    return [tags componentsJoinedByString:@", "];
}
static void font_attrs(NSMutableString *m, id f) {
    if (!f) return;
    CGFloat size = 12, weight = 0; NSString *family = nil; BOOL mono = NO, italic = NO; NSArray *features = nil;
    if ([f isKindOfClass:[__NSCTFont class]]) {
        __NSCTFont *c = f; size = c.size; weight = c.weight; family = c.family; mono = c.mono; italic = c.italic; features = c.features;
        if (c.bold && weight < 0.3) weight = 0.4;
    } else if ([f respondsToSelector:@selector(pointSize)]) {                 /* UIFont */
        size = [f pointSize];
        if ([f respondsToSelector:@selector(_isim_weight)]) weight = [f _isim_weight];
        if ([f respondsToSelector:@selector(_isim_family)]) family = [f _isim_family];
        if ([f respondsToSelector:@selector(_isim_mono)]) mono = [f _isim_mono];
    } else return;
    [m appendFormat:@" size=\"%ld\" weight=\"%d\"", lround(size * 1024), css_weight(weight)];
    if (family.length) { [m appendString:@" font_family=\""]; escape_into(m, family); [m appendString:@"\""]; }
    else if (mono) [m appendString:@" font_family=\"monospace\""];
    if (italic) [m appendString:@" style=\"italic\""];
    NSString *ft = feature_tags(features);
    if (ft.length) [m appendFormat:@" font_features=\"%@\"", ft];
}
static BOOL color_rgba(id c, double v[4]) {
    if (!c) return NO;
    CGColorRef cg = NULL;
    if ([c respondsToSelector:@selector(CGColor)]) cg = [c CGColor];
    else if (CFGetTypeID((__bridge CFTypeRef)c) == CGColorGetTypeID() || [NSStringFromClass([c class]) isEqualToString:@"__NSCGColor"]) cg = (__bridge CGColorRef)c;
    if (!cg) return NO;
    isim_cg_color_rgba(cg, v);
    return YES;
}
static NSString *hex(const double v[4]) { return [NSString stringWithFormat:@"#%02x%02x%02x", (int)lround(v[0] * 255), (int)lround(v[1] * 255), (int)lround(v[2] * 255)]; }
NSString *isim_ct_markup(NSAttributedString *s, int *align, double *spacing, BOOL *fromContext) {
    NSMutableString *m = [NSMutableString stringWithString:@"<span size=\"12288\">"];
    __block BOOL first = YES;
    if (fromContext) *fromContext = NO;
    [s enumerateAttributesInRange:NSMakeRange(0, s.length) options:0 usingBlock:^(NSDictionary *attrs, NSRange r, BOOL *stop) {
        id ps = attrs[(__bridge NSString *)kCTParagraphStyleAttributeName];
        if (first && ps) {
            if ([ps isKindOfClass:[__NSCTParagraphStyle class]]) {
                __NSCTParagraphStyle *p = ps;
                if (align) *align = p->_align == kCTTextAlignmentCenter ? 1 : p->_align == kCTTextAlignmentRight ? 2 : p->_align == kCTTextAlignmentJustified ? 3 : 0;
                if (spacing) *spacing = p->_spacing;
            } else if ([ps respondsToSelector:@selector(alignment)]) {               /* NSParagraphStyle (iOS NSTextAlignment) */
                NSInteger a = [ps alignment];
                if (align) *align = a == 1 ? 1 : a == 2 ? 2 : a == 3 ? 3 : 0;
                if (spacing && [ps respondsToSelector:@selector(lineSpacing)]) *spacing = [ps lineSpacing];
            }
        }
        first = NO;
        if (fromContext && [attrs[(__bridge NSString *)kCTForegroundColorFromContextAttributeName] boolValue]) *fromContext = YES;
        NSMutableString *span = [NSMutableString stringWithString:@"<span"];
        font_attrs(span, attrs[(__bridge NSString *)kCTFontAttributeName]);
        double c[4];
        if (color_rgba(attrs[(__bridge NSString *)kCTForegroundColorAttributeName] ?: attrs[@"NSColor"], c))
            [span appendFormat:@" foreground=\"%@\" fgalpha=\"%d%%\"", hex(c), (int)fmax(1, lround(c[3] * 100))];
        if (color_rgba(attrs[@"NSBackgroundColor"], c)) [span appendFormat:@" background=\"%@\" bgalpha=\"%d%%\"", hex(c), (int)fmax(1, lround(c[3] * 100))];
        double kern = [attrs[(__bridge NSString *)kCTKernAttributeName] doubleValue];
        if (kern) [span appendFormat:@" letter_spacing=\"%ld\"", lround(kern * 1024)];
        NSInteger ul = [attrs[(__bridge NSString *)kCTUnderlineStyleAttributeName] integerValue];
        if (ul) [span appendFormat:@" underline=\"%@\"", (ul & 0xff) == 0x09 ? @"double" : @"single"];
        if ([attrs[@"NSStrikethrough"] integerValue]) [span appendString:@" strikethrough=\"true\""];
        double rise = [(attrs[(__bridge NSString *)kCTBaselineOffsetAttributeName] ?: attrs[@"NSBaselineOffset"]) doubleValue];
        if (rise) [span appendFormat:@" rise=\"%ld\"", lround(rise * 1024)];
        [span appendString:@">"];
        [m appendString:span];
        escape_into(m, [s.string substringWithRange:r]);
        [m appendString:@"</span>"];
    }];
    [m appendString:@"</span>"];
    return m;
}

/* ---------------- layouts ---------------- */
@interface __NSCTLayout : NSObject {
@public void *_l; NSAttributedString *_s; NSUInteger *_u16; long _nbytes; BOOL _fromContext;
}
@end
@implementation __NSCTLayout
- (instancetype)initWithString:(NSAttributedString *)s width:(double)w single:(int)single {
    if (!(self = [super init])) return nil;
    _s = [s copy];
    int align = 0; double spacing = 0;
    NSString *mk = isim_ct_markup(_s, &align, &spacing, &_fromContext);
    _l = isim_ct_layout_create(mk.UTF8String, w, align, spacing, single);
    /* UTF-8 byte offset -> UTF-16 index */
    NSString *str = _s.string;
    const char *u8 = str.UTF8String;
    _nbytes = (long)strlen(u8);
    _u16 = calloc((size_t)_nbytes + 1, sizeof *_u16);
    NSUInteger k = 0; long b = 0;
    while (b < _nbytes) {
        unsigned char c = (unsigned char)u8[b];
        int n = c < 0x80 ? 1 : c < 0xe0 ? 2 : c < 0xf0 ? 3 : 4;
        for (int i = 0; i < n && b + i <= _nbytes; i++) _u16[b + i] = k;
        b += n; k += n == 4 ? 2 : 1;
    }
    _u16[_nbytes] = k;
    return self;
}
- (void)dealloc { isim_ct_layout_free(_l); free(_u16); }
- (NSUInteger)u16:(long)byte { return _u16[byte < 0 ? 0 : byte > _nbytes ? _nbytes : byte]; }
- (long)byte:(NSUInteger)u16 { for (long b = 0; b <= _nbytes; b++) if (_u16[b] >= u16) return b; return _nbytes; }
@end

@interface __NSCTLine : NSObject {
@public __NSCTLayout *_layout; int _line; double _asc, _desc, _width, _x, _baseline, _trailing; CFRange _range; NSArray *_runs;
}
@end
@interface __NSCTRun : NSObject {
@public __NSCTLine *_line; int _index; struct isim_ct_run _info; CFIndex _n; CGGlyph *_glyphs; CGPoint *_pos; CGSize *_adv; CFIndex *_idx; CFRange _range;
}
@end
@implementation __NSCTRun
- (void)dealloc { free(_glyphs); free(_pos); free(_adv); free(_idx); }
- (NSString *)description { return [NSString stringWithFormat:@"<CTRun %p> %ld glyphs, range {%ld, %ld}, font %s %gpt", self, (long)_n, (long)_range.location, (long)_range.length, _info.family, _info.size]; }
@end
@implementation __NSCTLine
- (NSString *)description { return [NSString stringWithFormat:@"<CTLine %p> range {%ld, %ld}, width %g", self, (long)_range.location, (long)_range.length, _width]; }
- (NSArray *)runs {
    if (_runs) return _runs;
    int n = isim_ct_line_runs(_layout->_l, _line, NULL, 0);
    struct isim_ct_run *info = calloc((size_t)(n ? n : 1), sizeof *info);
    isim_ct_line_runs(_layout->_l, _line, info, n);
    NSMutableArray *a = [NSMutableArray array];
    for (int i = 0; i < n; i++) {
        __NSCTRun *r = [__NSCTRun new];
        r->_line = self; r->_index = i; r->_info = info[i]; r->_n = info[i].glyphs;
        size_t gn = (size_t)(r->_n ? r->_n : 1);
        unsigned short *g = calloc(gn, sizeof *g); double *pos = calloc(gn * 2, sizeof *pos), *adv = calloc(gn, sizeof *adv); int *idx = calloc(gn, sizeof *idx);
        isim_ct_run_glyphs(_layout->_l, _line, i, g, pos, adv, idx, (int)r->_n);
        r->_glyphs = calloc(gn, sizeof *r->_glyphs); r->_pos = calloc(gn, sizeof *r->_pos); r->_adv = calloc(gn, sizeof *r->_adv); r->_idx = calloc(gn, sizeof *r->_idx);
        for (CFIndex k = 0; k < r->_n; k++) {
            r->_glyphs[k] = g[k]; r->_pos[k] = CGPointMake(pos[2 * k], pos[2 * k + 1]); r->_adv[k] = CGSizeMake(adv[k], 0);
            r->_idx[k] = (CFIndex)[_layout u16:idx[k]];
        }
        free(g); free(pos); free(adv); free(idx);
        NSUInteger a0 = [_layout u16:info[i].start], a1 = [_layout u16:info[i].start + info[i].len];
        r->_range = CFRangeMake((CFIndex)a0, (CFIndex)(a1 - a0));
        [a addObject:r];
    }
    free(info);
    _runs = a;
    return a;
}
@end
static __NSCTLine *make_line(__NSCTLayout *lay, int i) {
    __NSCTLine *l = [__NSCTLine new];
    l->_layout = lay; l->_line = i;
    int start = 0, len = 0;
    isim_ct_line_info(lay->_l, i, &l->_asc, &l->_desc, &l->_width, &l->_x, &l->_baseline, &start, &len, &l->_trailing);
    NSUInteger a = [lay u16:start], b = [lay u16:start + len];
    l->_range = CFRangeMake((CFIndex)a, (CFIndex)(b - a));
    return l;
}
static __NSCTLine *L(CTLineRef l) { return (__bridge __NSCTLine *)l; }
static __NSCTRun *R(CTRunRef r) { return (__bridge __NSCTRun *)r; }

CFTypeID CTLineGetTypeID(void) { return 0x4357; }
CFTypeID CTRunGetTypeID(void) { return 0x4358; }
CFTypeID CTFramesetterGetTypeID(void) { return 0x4359; }
CFTypeID CTFrameGetTypeID(void) { return 0x435a; }

CTLineRef CTLineCreateWithAttributedString(CFAttributedStringRef s) {
    __NSCTLayout *lay = [[__NSCTLayout alloc] initWithString:(__bridge NSAttributedString *)s width:0 single:1];
    return (CTLineRef)CFBridgingRetain(make_line(lay, 0));
}
CTLineRef CTLineCreateTruncatedLine(CTLineRef line, double width, CTLineTruncationType type, CTLineRef token) {
    __NSCTLine *o = L(line);
    if (o->_width <= width) return CFBridgingRetain(o);
    __NSCTLayout *lay = [[__NSCTLayout alloc] initWithString:o->_layout->_s width:width single:type == kCTLineTruncationStart ? 2 : type == kCTLineTruncationMiddle ? 3 : 4];
    return (CTLineRef)CFBridgingRetain(make_line(lay, 0));
}
CTLineRef CTLineCreateJustifiedLine(CTLineRef line, CGFloat factor, double width) { return CFBridgingRetain(L(line)); }
CFIndex CTLineGetGlyphCount(CTLineRef line) { CFIndex n = 0; for (__NSCTRun *r in [L(line) runs]) n += r->_n; return n; }
CFArrayRef CTLineGetGlyphRuns(CTLineRef line) { return (__bridge CFArrayRef)[L(line) runs]; }
CFRange CTLineGetStringRange(CTLineRef line) { return L(line)->_range; }
double CTLineGetPenOffsetForFlush(CTLineRef line, CGFloat f, double w) { double d = w - (L(line)->_width - L(line)->_trailing); return d > 0 ? d * fmax(0, fmin(1, f)) : 0; }
double CTLineGetTypographicBounds(CTLineRef line, CGFloat *a, CGFloat *d, CGFloat *lead) {
    __NSCTLine *l = L(line);
    if (a) *a = l->_asc; if (d) *d = l->_desc; if (lead) *lead = 0;
    return l->_width;
}
CGRect CTLineGetBoundsWithOptions(CTLineRef line, CTLineBoundsOptions o) { __NSCTLine *l = L(line); return CGRectMake(0, -l->_desc, l->_width, l->_asc + l->_desc); }
double CTLineGetTrailingWhitespaceWidth(CTLineRef line) { return L(line)->_trailing; }
CGRect CTLineGetImageBounds(CTLineRef line, CGContextRef c) {
    __NSCTLine *l = L(line);
    CGPoint p = c ? CGContextGetTextPosition(c) : CGPointZero;
    return CGRectMake(p.x, p.y - l->_desc * 0.6, l->_width - l->_trailing, l->_asc * 0.75 + l->_desc * 0.6);
}
CFIndex CTLineGetStringIndexForPosition(CTLineRef line, CGPoint pos) {
    __NSCTLine *l = L(line);
    if (pos.x >= l->_width) return l->_range.location + l->_range.length;
    return (CFIndex)[l->_layout u16:isim_ct_line_index_at(l->_layout->_l, l->_line, pos.x)];
}
CGFloat CTLineGetOffsetForStringIndex(CTLineRef line, CFIndex idx, CGFloat *secondary) {
    __NSCTLine *l = L(line);
    CGFloat x = isim_ct_line_x_at(l->_layout->_l, l->_line, (int)[l->_layout byte:(NSUInteger)idx]);
    if (secondary) *secondary = x;
    return x;
}
static void draw_line(__NSCTLine *l, CGContextRef c, double dx, double dy) {
    double black[4] = { 0, 0, 0, 1 };
    isim_cg_context_draw_text_line(c, l->_layout->_l, l->_line, dx, dy, l->_layout->_fromContext ? NULL : black, 0);
}
void CTLineDraw(CTLineRef line, CGContextRef c) { if (line && c) draw_line(L(line), c, 0, 0); }

CFIndex CTRunGetGlyphCount(CTRunRef r) { return R(r)->_n; }
CFDictionaryRef CTRunGetAttributes(CTRunRef r) {
    __NSCTRun *run = R(r);
    NSAttributedString *s = run->_line->_layout->_s;
    NSDictionary *a = s.length && run->_range.location < (CFIndex)s.length ? [s attributesAtIndex:(NSUInteger)run->_range.location effectiveRange:NULL] : @{};
    return (__bridge CFDictionaryRef)a;
}
CTRunStatus CTRunGetStatus(CTRunRef r) { return kCTRunStatusNoStatus; }
static CFRange clamp_range(__NSCTRun *r, CFRange range) { if (range.length == 0) range = CFRangeMake(0, r->_n); if (range.location + range.length > r->_n) range.length = r->_n - range.location; return range; }
const CGGlyph *CTRunGetGlyphsPtr(CTRunRef r) { return R(r)->_glyphs; }
void CTRunGetGlyphs(CTRunRef r, CFRange range, CGGlyph *buf) { range = clamp_range(R(r), range); memcpy(buf, R(r)->_glyphs + range.location, sizeof *buf * (size_t)range.length); }
const CGPoint *CTRunGetPositionsPtr(CTRunRef r) { return R(r)->_pos; }
void CTRunGetPositions(CTRunRef r, CFRange range, CGPoint *buf) { range = clamp_range(R(r), range); memcpy(buf, R(r)->_pos + range.location, sizeof *buf * (size_t)range.length); }
const CGSize *CTRunGetAdvancesPtr(CTRunRef r) { return R(r)->_adv; }
void CTRunGetAdvances(CTRunRef r, CFRange range, CGSize *buf) { range = clamp_range(R(r), range); memcpy(buf, R(r)->_adv + range.location, sizeof *buf * (size_t)range.length); }
const CFIndex *CTRunGetStringIndicesPtr(CTRunRef r) { return R(r)->_idx; }
void CTRunGetStringIndices(CTRunRef r, CFRange range, CFIndex *buf) { range = clamp_range(R(r), range); memcpy(buf, R(r)->_idx + range.location, sizeof *buf * (size_t)range.length); }
CFRange CTRunGetStringRange(CTRunRef r) { return R(r)->_range; }
double CTRunGetTypographicBounds(CTRunRef r, CFRange range, CGFloat *a, CGFloat *d, CGFloat *lead) {
    __NSCTRun *run = R(r); range = clamp_range(run, range);
    if (a) *a = run->_info.size * 0.952; if (d) *d = run->_info.size * 0.241; if (lead) *lead = 0;
    double w = 0; for (CFIndex i = range.location; i < range.location + range.length; i++) w += run->_adv[i].width;
    return w;
}
CGRect CTRunGetImageBounds(CTRunRef r, CGContextRef c, CFRange range) {
    __NSCTRun *run = R(r); CGFloat a, d; double w = CTRunGetTypographicBounds(r, range, &a, &d, NULL);
    CGPoint p = c ? CGContextGetTextPosition(c) : CGPointZero;
    return CGRectMake(p.x + run->_info.x, p.y - d, w, a + d);
}
CGAffineTransform CTRunGetTextMatrix(CTRunRef r) { return CGAffineTransformIdentity; }
void CTRunDraw(CTRunRef r, CGContextRef c, CFRange range) {
    __NSCTRun *run = R(r);
    if (!c) return;
    /* the line is drawn clipped to the run's horizontal extent (in text space) */
    CGPoint p = CGContextGetTextPosition(c);
    CGAffineTransform tm = CGContextGetTextMatrix(c);
    CGContextSaveGState(c);
    CGContextConcatCTM(c, CGAffineTransformMake(tm.a, tm.b, tm.c, tm.d, p.x + tm.tx, p.y + tm.ty));
    CGContextClipToRect(c, CGRectMake(run->_info.x, -1e4, run->_info.width, 2e4));
    CGContextConcatCTM(c, CGAffineTransformInvert(CGAffineTransformMake(tm.a, tm.b, tm.c, tm.d, p.x + tm.tx, p.y + tm.ty)));
    draw_line(run->_line, c, 0, 0);
    CGContextRestoreGState(c);
}

/* ---------------- framesetters and frames ---------------- */
@interface __NSCTFramesetter : NSObject { @public NSAttributedString *_s; }
@end
@implementation __NSCTFramesetter
@end
@interface __NSCTFrame : NSObject { @public __NSCTLayout *_layout; NSArray *_lines; CGPoint *_origins; CGPathRef _path; CFRange _range, _visible; CGRect _rect; }
@end
@implementation __NSCTFrame
- (void)dealloc { free(_origins); if (_path) CGPathRelease(_path); }
@end
static NSAttributedString *sub(NSAttributedString *s, CFRange r) {
    if (r.length == 0) r.length = (CFIndex)s.length - r.location;
    if (r.location < 0 || r.location + r.length > (CFIndex)s.length) return s;
    return [s attributedSubstringFromRange:NSMakeRange((NSUInteger)r.location, (NSUInteger)r.length)];
}
CTFramesetterRef CTFramesetterCreateWithAttributedString(CFAttributedStringRef s) {
    __NSCTFramesetter *f = [__NSCTFramesetter new]; f->_s = [(__bridge NSAttributedString *)s copy];
    return (CTFramesetterRef)CFBridgingRetain(f);
}
CTFrameRef CTFramesetterCreateFrame(CTFramesetterRef fs, CFRange range, CGPathRef path, CFDictionaryRef attrs) {
    __NSCTFramesetter *f = (__bridge __NSCTFramesetter *)fs;
    CFIndex base = range.location > 0 ? range.location : 0;
    __NSCTFrame *fr = [__NSCTFrame new];
    fr->_rect = CGPathGetBoundingBox(path);
    fr->_path = CGPathRetain(path);
    fr->_layout = [[__NSCTLayout alloc] initWithString:sub(f->_s, range) width:fr->_rect.size.width single:0];
    int n = isim_ct_layout_lines(fr->_layout->_l);
    NSMutableArray *lines = [NSMutableArray array];
    fr->_origins = calloc((size_t)(n ? n : 1), sizeof(CGPoint));
    CFIndex end = 0;
    for (int i = 0; i < n; i++) {
        __NSCTLine *l = make_line(fr->_layout, i);
        if (l->_baseline + l->_desc > fr->_rect.size.height + 0.5) break;
        l->_range.location += base;
        fr->_origins[i] = CGPointMake(l->_x, fr->_rect.size.height - l->_baseline);
        [lines addObject:l];
        end = l->_range.location + l->_range.length;
    }
    fr->_lines = lines;
    CFIndex len = range.length ? range.length : (CFIndex)f->_s.length - base;
    fr->_range = CFRangeMake(base, len);
    fr->_visible = CFRangeMake(base, end - base);
    return (CTFrameRef)CFBridgingRetain(fr);
}
CGSize CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterRef fs, CFRange range, CFDictionaryRef attrs, CGSize cons, CFRange *fit) {
    __NSCTFramesetter *f = (__bridge __NSCTFramesetter *)fs;
    __NSCTLayout *lay = [[__NSCTLayout alloc] initWithString:sub(f->_s, range) width:cons.width < 1e7 ? cons.width : 0 single:0];
    int n = isim_ct_layout_lines(lay->_l);
    double w = 0, h = 0; CFIndex end = 0;
    for (int i = 0; i < n; i++) {
        __NSCTLine *l = make_line(lay, i);
        if (l->_baseline + l->_desc > cons.height + 0.5) break;
        w = fmax(w, l->_width - l->_trailing); h = l->_baseline + l->_desc; end = l->_range.location + l->_range.length;
    }
    if (fit) *fit = CFRangeMake(range.location, end);
    return CGSizeMake(ceil(w), ceil(h));
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
