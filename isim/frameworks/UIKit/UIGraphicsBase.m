/* isim UIKit: colors, fonts, layers, traits, text helpers, graphics, images (ARC). */
#import "UIKitPrivate.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* ================= frame scheduling & device ================= */
static BOOL needs_display = YES, needs_layout = YES;
BOOL isim_ui_in_layout;
void isim_ui_set_needs_display(void) { needs_display = YES; }
void isim_ui_set_needs_layout(void) { needs_layout = YES; needs_display = YES; }
BOOL isim_ui_take_display(void) { BOOL d = needs_display; needs_display = NO; return d; }
BOOL isim_ui_take_layout(void) { BOOL d = needs_layout; needs_layout = NO; return d; }

const struct isim_device *isim_ui_device(void) {
    static struct isim_device dev; static BOOL init;
    if (!init) { isim_device_metrics(&dev); init = YES; }
    return &dev;
}

static UIUserInterfaceStyle style_stack[64]; static int style_depth = -1;
static UIUserInterfaceStyle cached_style;
/* ISIM_APPEARANCE, else Settings > Display & Brightness (AppleInterfaceStyle = "Dark" in the global domain) */
static UIUserInterfaceStyle base_style(void) {
    if (!cached_style) {
        const char *e = getenv("ISIM_APPEARANCE");
        extern NSDictionary *isim_global_preferences(void);
        if (e && *e) cached_style = !strcmp(e, "dark") ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
        else cached_style = [isim_global_preferences()[@"AppleInterfaceStyle"] isEqual:@"Dark"] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    }
    return cached_style;
}
void isim_ui_reload_settings(void) { cached_style = 0; }
UIUserInterfaceStyle isim_ui_style(void) { return style_depth >= 0 ? style_stack[style_depth] : base_style(); }
void isim_ui_push_style(UIUserInterfaceStyle s) { if (style_depth < 63) style_stack[++style_depth] = s == UIUserInterfaceStyleUnspecified ? isim_ui_style() : s; }
void isim_ui_pop_style(void) { if (style_depth >= 0) style_depth--; }

const UIEdgeInsets UIEdgeInsetsZero = { 0, 0, 0, 0 };
const NSDirectionalEdgeInsets NSDirectionalEdgeInsetsZero = { 0, 0, 0, 0 };
NSString *NSStringFromUIEdgeInsets(UIEdgeInsets i) { return [NSString stringWithFormat:@"{%g, %g, %g, %g}", i.top, i.left, i.bottom, i.right]; }

/* ================= UITraitCollection ================= */
@implementation UITraitCollection
+ (UITraitCollection *)currentTraitCollection { return [self traitCollectionWithUserInterfaceStyle:isim_ui_style()]; }
+ (UITraitCollection *)traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)style {
    UITraitCollection *t = [UITraitCollection new];
    t->_userInterfaceStyle = style;
    t->_userInterfaceIdiom = isim_ui_device()->width >= 700 ? UIUserInterfaceIdiomPad : UIUserInterfaceIdiomPhone;
    t->_horizontalSizeClass = t->_userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIUserInterfaceSizeClassRegular : UIUserInterfaceSizeClassCompact;
    t->_verticalSizeClass = UIUserInterfaceSizeClassRegular;
    t->_displayScale = isim_ui_device()->scale;
    return t;
}
- (id)copyWithZone:(NSZone *)z { return self; }
@end

/* ================= UIColor ================= */
@implementation UIColor {
    double _c[4];
    UIColor * (^_provider)(UITraitCollection *);
    CGColorRef _cg;
}
- (instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a {
    if ((self = [super init])) { _c[0] = r; _c[1] = g; _c[2] = b; _c[3] = a; }
    return self;
}
- (instancetype)initWithWhite:(CGFloat)w alpha:(CGFloat)a { return [self initWithRed:w green:w blue:w alpha:a]; }
- (instancetype)initWithHue:(CGFloat)h saturation:(CGFloat)s brightness:(CGFloat)v alpha:(CGFloat)a {
    h = fmod(h, 1.0) * 6; int i = (int)floor(h); double f = h - i, p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f));
    double rgb[6][3] = { { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } };
    i = ((i % 6) + 6) % 6;
    return [self initWithRed:rgb[i][0] green:rgb[i][1] blue:rgb[i][2] alpha:a];
}
- (instancetype)initWithDynamicProvider:(UIColor * (^)(UITraitCollection *))p { if ((self = [super init])) _provider = [p copy]; return self; }
- (void)dealloc { if (_cg) CGColorRelease(_cg); }
+ (UIColor *)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a { return [[self alloc] initWithRed:r green:g blue:b alpha:a]; }
+ (UIColor *)colorWithDisplayP3Red:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a { return [self colorWithRed:r green:g blue:b alpha:a]; }
+ (UIColor *)colorWithWhite:(CGFloat)w alpha:(CGFloat)a { return [[self alloc] initWithWhite:w alpha:a]; }
+ (UIColor *)colorWithHue:(CGFloat)h saturation:(CGFloat)s brightness:(CGFloat)b alpha:(CGFloat)a { return [[self alloc] initWithHue:h saturation:s brightness:b alpha:a]; }
+ (UIColor *)colorWithCGColor:(CGColorRef)cg { const CGFloat *c = CGColorGetComponents(cg); return c ? [self colorWithRed:c[0] green:c[1] blue:c[2] alpha:c[3]] : [self clearColor]; }
+ (UIColor *)colorWithDynamicProvider:(UIColor * (^)(UITraitCollection *))p { return [[self alloc] initWithDynamicProvider:p]; }

static UIColor *rgb255(int r, int g, int b, double a) { return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a]; }
static UIColor *dyn(UIColor *light, UIColor *dark) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light; }];
}
#define FIXED(name, expr) + (UIColor *)name { static UIColor *c; if (!c) c = (expr); return c; }
FIXED(blackColor, [UIColor colorWithWhite:0 alpha:1]) FIXED(darkGrayColor, [UIColor colorWithWhite:1.0 / 3 alpha:1])
FIXED(lightGrayColor, [UIColor colorWithWhite:2.0 / 3 alpha:1]) FIXED(whiteColor, [UIColor colorWithWhite:1 alpha:1])
FIXED(grayColor, [UIColor colorWithWhite:0.5 alpha:1]) FIXED(redColor, [UIColor colorWithRed:1 green:0 blue:0 alpha:1])
FIXED(greenColor, [UIColor colorWithRed:0 green:1 blue:0 alpha:1]) FIXED(blueColor, [UIColor colorWithRed:0 green:0 blue:1 alpha:1])
FIXED(cyanColor, [UIColor colorWithRed:0 green:1 blue:1 alpha:1]) FIXED(yellowColor, [UIColor colorWithRed:1 green:1 blue:0 alpha:1])
FIXED(magentaColor, [UIColor colorWithRed:1 green:0 blue:1 alpha:1]) FIXED(orangeColor, [UIColor colorWithRed:1 green:0.5 blue:0 alpha:1])
FIXED(purpleColor, [UIColor colorWithRed:0.5 green:0 blue:0.5 alpha:1]) FIXED(brownColor, [UIColor colorWithRed:0.6 green:0.4 blue:0.2 alpha:1])
FIXED(clearColor, [UIColor colorWithWhite:0 alpha:0])
/* system palette (light / dark), per Apple's Human Interface Guidelines color values */
FIXED(systemRedColor, dyn(rgb255(255, 59, 48, 1), rgb255(255, 69, 58, 1)))
FIXED(systemGreenColor, dyn(rgb255(52, 199, 89, 1), rgb255(48, 209, 88, 1)))
FIXED(systemBlueColor, dyn(rgb255(0, 122, 255, 1), rgb255(10, 132, 255, 1)))
FIXED(systemOrangeColor, dyn(rgb255(255, 149, 0, 1), rgb255(255, 159, 10, 1)))
FIXED(systemYellowColor, dyn(rgb255(255, 204, 0, 1), rgb255(255, 214, 10, 1)))
FIXED(systemPinkColor, dyn(rgb255(255, 45, 85, 1), rgb255(255, 55, 95, 1)))
FIXED(systemPurpleColor, dyn(rgb255(175, 82, 222, 1), rgb255(191, 90, 242, 1)))
FIXED(systemTealColor, dyn(rgb255(48, 176, 199, 1), rgb255(64, 200, 224, 1)))
FIXED(systemIndigoColor, dyn(rgb255(88, 86, 214, 1), rgb255(94, 92, 230, 1)))
FIXED(systemMintColor, dyn(rgb255(0, 199, 190, 1), rgb255(99, 230, 226, 1)))
FIXED(systemCyanColor, dyn(rgb255(50, 173, 230, 1), rgb255(100, 210, 255, 1)))
FIXED(systemBrownColor, dyn(rgb255(162, 132, 94, 1), rgb255(172, 142, 104, 1)))
FIXED(systemGrayColor, dyn(rgb255(142, 142, 147, 1), rgb255(142, 142, 147, 1)))
FIXED(systemGray2Color, dyn(rgb255(174, 174, 178, 1), rgb255(99, 99, 102, 1)))
FIXED(systemGray3Color, dyn(rgb255(199, 199, 204, 1), rgb255(72, 72, 74, 1)))
FIXED(systemGray4Color, dyn(rgb255(209, 209, 214, 1), rgb255(58, 58, 60, 1)))
FIXED(systemGray5Color, dyn(rgb255(229, 229, 234, 1), rgb255(44, 44, 46, 1)))
FIXED(systemGray6Color, dyn(rgb255(242, 242, 247, 1), rgb255(28, 28, 30, 1)))
+ (UIColor *)tintColor { return [self systemBlueColor]; }
FIXED(labelColor, dyn(rgb255(0, 0, 0, 1), rgb255(255, 255, 255, 1)))
FIXED(secondaryLabelColor, dyn(rgb255(60, 60, 67, 0.6), rgb255(235, 235, 245, 0.6)))
FIXED(tertiaryLabelColor, dyn(rgb255(60, 60, 67, 0.3), rgb255(235, 235, 245, 0.3)))
FIXED(quaternaryLabelColor, dyn(rgb255(60, 60, 67, 0.18), rgb255(235, 235, 245, 0.16)))
+ (UIColor *)linkColor { return [self systemBlueColor]; }
FIXED(placeholderTextColor, dyn(rgb255(60, 60, 67, 0.3), rgb255(235, 235, 245, 0.3)))
FIXED(separatorColor, dyn(rgb255(60, 60, 67, 0.29), rgb255(84, 84, 88, 0.6)))
FIXED(opaqueSeparatorColor, dyn(rgb255(198, 198, 200, 1), rgb255(56, 56, 58, 1)))
FIXED(systemBackgroundColor, dyn(rgb255(255, 255, 255, 1), rgb255(0, 0, 0, 1)))
FIXED(secondarySystemBackgroundColor, dyn(rgb255(242, 242, 247, 1), rgb255(28, 28, 30, 1)))
FIXED(tertiarySystemBackgroundColor, dyn(rgb255(255, 255, 255, 1), rgb255(44, 44, 46, 1)))
FIXED(systemGroupedBackgroundColor, dyn(rgb255(242, 242, 247, 1), rgb255(0, 0, 0, 1)))
FIXED(secondarySystemGroupedBackgroundColor, dyn(rgb255(255, 255, 255, 1), rgb255(28, 28, 30, 1)))
FIXED(tertiarySystemGroupedBackgroundColor, dyn(rgb255(242, 242, 247, 1), rgb255(44, 44, 46, 1)))
FIXED(systemFillColor, dyn(rgb255(120, 120, 128, 0.2), rgb255(120, 120, 128, 0.36)))
FIXED(secondarySystemFillColor, dyn(rgb255(120, 120, 128, 0.16), rgb255(120, 120, 128, 0.32)))
FIXED(tertiarySystemFillColor, dyn(rgb255(118, 118, 128, 0.12), rgb255(118, 118, 128, 0.24)))
FIXED(quaternarySystemFillColor, dyn(rgb255(116, 116, 128, 0.08), rgb255(118, 118, 128, 0.18)))
FIXED(lightTextColor, [UIColor colorWithWhite:1 alpha:0.6]) FIXED(darkTextColor, [UIColor colorWithWhite:0 alpha:1])

- (UIColor *)resolvedColorWithTraitCollection:(UITraitCollection *)t {
    UIColor *c = self;
    for (int i = 0; i < 4 && c->_provider; i++) c = c->_provider(t);
    return c;
}
- (UIColor *)_resolved { return _provider ? [self resolvedColorWithTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:isim_ui_style()]] : self; }
void isim_ui_rgba(UIColor *c, double out[4]) {
    if (!c) { out[0] = out[1] = out[2] = out[3] = 0; return; }
    UIColor *r = [c _resolved];
    memcpy(out, r->_c, sizeof r->_c);
}
- (UIColor *)colorWithAlphaComponent:(CGFloat)alpha {
    if (_provider) { UIColor *base = self; return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return [[base resolvedColorWithTraitCollection:t] colorWithAlphaComponent:alpha]; }]; }
    return [UIColor colorWithRed:_c[0] green:_c[1] blue:_c[2] alpha:alpha];
}
- (BOOL)getRed:(CGFloat *)r green:(CGFloat *)g blue:(CGFloat *)b alpha:(CGFloat *)a {
    UIColor *x = [self _resolved];
    if (r) *r = x->_c[0]; if (g) *g = x->_c[1]; if (b) *b = x->_c[2]; if (a) *a = x->_c[3];
    return YES;
}
- (BOOL)getWhite:(CGFloat *)w alpha:(CGFloat *)a { UIColor *x = [self _resolved]; if (w) *w = (x->_c[0] + x->_c[1] + x->_c[2]) / 3; if (a) *a = x->_c[3]; return YES; }
- (CGColorRef)CGColor {
    UIColor *x = [self _resolved];
    if (!_cg) _cg = CGColorCreateSRGB(x->_c[0], x->_c[1], x->_c[2], x->_c[3]);
    return _cg;
}
- (void)set { [self setFill]; [self setStroke]; }
- (void)setFill { UIColor *x = [self _resolved]; CGContextSetRGBFillColor(isim_cg_current_context(), x->_c[0], x->_c[1], x->_c[2], x->_c[3]); }
- (void)setStroke { UIColor *x = [self _resolved]; CGContextSetRGBStrokeColor(isim_cg_current_context(), x->_c[0], x->_c[1], x->_c[2], x->_c[3]); }
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[UIColor class]]) return NO;
    UIColor *a = [self _resolved], *b = [o _resolved];
    return !memcmp(a->_c, b->_c, sizeof a->_c);
}
- (NSUInteger)hash { UIColor *a = [self _resolved]; return (NSUInteger)(a->_c[0] * 255) << 24 | (NSUInteger)(a->_c[1] * 255) << 16 | (NSUInteger)(a->_c[2] * 255) << 8 | (NSUInteger)(a->_c[3] * 255); }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description { UIColor *a = [self _resolved]; return [NSString stringWithFormat:@"UIExtendedSRGBColorSpace %g %g %g %g", a->_c[0], a->_c[1], a->_c[2], a->_c[3]]; }
@end

/* ================= UIFont ================= */
const UIFontWeight UIFontWeightUltraLight = -0.8, UIFontWeightThin = -0.6, UIFontWeightLight = -0.4, UIFontWeightRegular = 0,
    UIFontWeightMedium = 0.23, UIFontWeightSemibold = 0.3, UIFontWeightBold = 0.4, UIFontWeightHeavy = 0.56, UIFontWeightBlack = 0.62;
const UIFontTextStyle UIFontTextStyleLargeTitle = @"UICTFontTextStyleTitle0", UIFontTextStyleTitle1 = @"UICTFontTextStyleTitle1",
    UIFontTextStyleTitle2 = @"UICTFontTextStyleTitle2", UIFontTextStyleTitle3 = @"UICTFontTextStyleTitle3",
    UIFontTextStyleHeadline = @"UICTFontTextStyleHeadline", UIFontTextStyleSubheadline = @"UICTFontTextStyleSubhead",
    UIFontTextStyleBody = @"UICTFontTextStyleBody", UIFontTextStyleCallout = @"UICTFontTextStyleCallout",
    UIFontTextStyleFootnote = @"UICTFontTextStyleFootnote", UIFontTextStyleCaption1 = @"UICTFontTextStyleCaption1",
    UIFontTextStyleCaption2 = @"UICTFontTextStyleCaption2";

@implementation UIFont { CGFloat _size, _weight; BOOL _mono; NSString *_name; }
+ (UIFont *)_size:(CGFloat)s weight:(CGFloat)w mono:(BOOL)m name:(NSString *)n {
    UIFont *f = [UIFont new]; f->_size = s; f->_weight = w; f->_mono = m; f->_name = n; return f;
}
+ (UIFont *)systemFontOfSize:(CGFloat)s { return [self systemFontOfSize:s weight:UIFontWeightRegular]; }
+ (UIFont *)boldSystemFontOfSize:(CGFloat)s { return [self systemFontOfSize:s weight:UIFontWeightBold]; }
+ (UIFont *)italicSystemFontOfSize:(CGFloat)s { return [self systemFontOfSize:s weight:UIFontWeightRegular]; }
+ (UIFont *)systemFontOfSize:(CGFloat)s weight:(UIFontWeight)w {
    NSString *n = w >= UIFontWeightBold ? @".SFUI-Bold" : w >= UIFontWeightSemibold ? @".SFUI-Semibold" : w >= UIFontWeightMedium ? @".SFUI-Medium" : @".SFUI-Regular";
    return [self _size:s weight:w mono:NO name:n];
}
+ (UIFont *)monospacedDigitSystemFontOfSize:(CGFloat)s weight:(UIFontWeight)w { return [self systemFontOfSize:s weight:w]; }
+ (UIFont *)monospacedSystemFontOfSize:(CGFloat)s weight:(UIFontWeight)w { return [self _size:s weight:w mono:YES name:@".SFMono-Regular"]; }
+ (UIFont *)fontWithName:(NSString *)name size:(CGFloat)s {
    BOOL bold = [name.lowercaseString containsString:@"bold"];
    BOOL mono = [name.lowercaseString containsString:@"mono"] || [name.lowercaseString containsString:@"courier"] || [name.lowercaseString containsString:@"menlo"];
    return [self _size:s weight:bold ? UIFontWeightBold : UIFontWeightRegular mono:mono name:name];
}
+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style {
    NSDictionary *sizes = @{ UIFontTextStyleLargeTitle: @34, UIFontTextStyleTitle1: @28, UIFontTextStyleTitle2: @22, UIFontTextStyleTitle3: @20,
                             UIFontTextStyleHeadline: @17, UIFontTextStyleBody: @17, UIFontTextStyleCallout: @16, UIFontTextStyleSubheadline: @15,
                             UIFontTextStyleFootnote: @13, UIFontTextStyleCaption1: @12, UIFontTextStyleCaption2: @11 };
    CGFloat s = [sizes[style] doubleValue] ?: 17;
    return [self systemFontOfSize:s weight:[style isEqualToString:UIFontTextStyleHeadline] ? UIFontWeightSemibold : UIFontWeightRegular];
}
+ (CGFloat)labelFontSize { return 17; }
+ (CGFloat)buttonFontSize { return 18; }
+ (CGFloat)smallSystemFontSize { return 12; }
+ (CGFloat)systemFontSize { return 14; }
- (UIFont *)fontWithSize:(CGFloat)s { return [UIFont _size:s weight:_weight mono:_mono name:_name]; }
- (NSString *)familyName { return _mono ? @".SF Mono" : @".SF UI Text"; }
- (NSString *)fontName { return _name; }
- (CGFloat)pointSize { return _size; }
- (CGFloat)ascender { return _size * 0.952; }
- (CGFloat)descender { return -_size * 0.241; }
- (CGFloat)capHeight { return _size * 0.705; }
- (CGFloat)xHeight { return _size * 0.528; }
- (CGFloat)lineHeight { return ceil(_size * 1.193 * 2) / 2; }
- (CGFloat)leading { return 0; }
- (CGFloat)_isim_weight { return _weight; }
- (BOOL)_isim_mono { return _mono; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(UIFont *)o { return [o isKindOfClass:[UIFont class]] && o->_size == _size && o->_weight == _weight && o->_mono == _mono; }
- (NSUInteger)hash { return (NSUInteger)(_size * 100) ^ (NSUInteger)(_weight * 1000); }
- (NSString *)description { return [NSString stringWithFormat:@"<UICTFont: %p> font-family: \"%@\"; font-weight: %g; font-size: %.2fpt", self, self.familyName, _weight, _size]; }
@end

/* ================= text helpers ================= */
CGSize isim_ui_measure(NSString *text, UIFont *font, CGFloat maxWidth, NSInteger lines) {
    if (!text.length) return CGSizeZero;
    if (!font) font = [UIFont systemFontOfSize:17];
    double w, h;
    isim_text_measure(text.UTF8String, font.pointSize, font._isim_weight, font._isim_mono, maxWidth, (int)lines, &w, &h);
    return CGSizeMake(w, h);
}
CGPoint isim_ui_text_end_point(NSString *text, UIFont *font, CGFloat maxWidth) {
    if (!font) font = [UIFont systemFontOfSize:17];
    double x = 0, y = 0;
    if (text.length) isim_text_end_point(text.UTF8String, font.pointSize, font._isim_weight, font._isim_mono, maxWidth, &x, &y);
    return CGPointMake(x, y);
}
void isim_ui_draw_text(NSString *text, UIFont *font, UIColor *color, CGRect r, NSTextAlignment align, NSInteger lines, CGFloat alpha) {
    if (!text.length) return;
    if (!font) font = [UIFont systemFontOfSize:17];
    double c[4]; isim_ui_rgba(color ?: UIColor.labelColor, c); c[3] *= alpha;
    CGSize sz = isim_ui_measure(text, font, lines == 1 ? 0 : r.size.width, lines);
    double y = r.origin.y + (r.size.height - MIN(sz.height, r.size.height)) / 2;
    int a = align == NSTextAlignmentCenter ? 1 : align == NSTextAlignmentRight ? 2 : 0;
    isim_text_draw(text.UTF8String, r.origin.x, y, r.size.width, font.pointSize, font._isim_weight, font._isim_mono, a, (int)(lines == 1 ? 1 : lines), c);
}

/* ================= CALayer ================= */
CALayerCornerCurve const kCACornerCurveCircular = @"circular", kCACornerCurveContinuous = @"continuous";
@implementation CALayer
+ (instancetype)layer { return [self new]; }
- (instancetype)init { if ((self = [super init])) { _opacity = 1; _cornerCurve = kCACornerCurveCircular; _shadowOffset = CGSizeMake(0, -3); } return self; }
- (void)dealloc { if (_borderColor) CGColorRelease(_borderColor); if (_backgroundColor) CGColorRelease(_backgroundColor); if (_shadowColor) CGColorRelease(_shadowColor); }
- (void)setBorderColor:(CGColorRef)c { CGColorRetain(c); if (_borderColor) CGColorRelease(_borderColor); _borderColor = c; isim_ui_set_needs_display(); }
- (void)setBackgroundColor:(CGColorRef)c { CGColorRetain(c); if (_backgroundColor) CGColorRelease(_backgroundColor); _backgroundColor = c; isim_ui_set_needs_display(); }
- (void)setShadowColor:(CGColorRef)c { CGColorRetain(c); if (_shadowColor) CGColorRelease(_shadowColor); _shadowColor = c; }
- (void)setCornerRadius:(CGFloat)r { _cornerRadius = r; isim_ui_set_needs_display(); }
- (void)setBorderWidth:(CGFloat)w { _borderWidth = w; isim_ui_set_needs_display(); }
- (void)setMasksToBounds:(BOOL)m { _masksToBounds = m; isim_ui_set_needs_display(); }
- (void)setOpacity:(float)o { _opacity = o; isim_ui_set_needs_display(); }
- (void)setHidden:(BOOL)h { _hidden = h; isim_ui_set_needs_display(); }
- (void)setNeedsDisplay { isim_ui_set_needs_display(); }
- (void)setNeedsLayout { isim_ui_set_needs_layout(); }
@end

/* ================= UIGraphics / UIBezierPath ================= */
CGContextRef UIGraphicsGetCurrentContext(void) { return isim_cg_current_context(); }
void UIRectFill(CGRect r) { CGContextFillRect(isim_cg_current_context(), r); }
void UIRectFrame(CGRect r) { CGContextStrokeRect(isim_cg_current_context(), r); }

enum { P_MOVE, P_LINE, P_CURVE, P_CLOSE, P_ARC, P_RECT };
typedef struct { int op; double v[6]; } path_el;
@implementation UIBezierPath { path_el *_e; NSUInteger _n, _cap; CGRect _bounds; BOOL _hasBounds; }
- (instancetype)init { if ((self = [super init])) _lineWidth = 1; return self; }
- (void)dealloc { free(_e); }
+ (instancetype)bezierPath { return [self new]; }
- (void)_add:(int)op :(double)a :(double)b :(double)c :(double)d :(double)e :(double)f {
    if (_n == _cap) { _cap = _cap ? _cap * 2 : 16; _e = realloc(_e, _cap * sizeof *_e); }
    _e[_n++] = (path_el){ op, { a, b, c, d, e, f } };
}
- (void)_grow:(CGPoint)p { CGRect r = CGRectMake(p.x, p.y, 0, 0); _bounds = _hasBounds ? CGRectUnion(_bounds, r) : r; _hasBounds = YES; }
+ (instancetype)bezierPathWithRect:(CGRect)r { UIBezierPath *p = [self new]; [p _add:P_RECT :r.origin.x :r.origin.y :r.size.width :r.size.height :0 :0]; p->_bounds = r; p->_hasBounds = YES; return p; }
+ (instancetype)bezierPathWithRoundedRect:(CGRect)r cornerRadius:(CGFloat)cr { UIBezierPath *p = [self new]; [p _add:P_RECT :r.origin.x :r.origin.y :r.size.width :r.size.height :cr :0]; p->_bounds = r; p->_hasBounds = YES; return p; }
+ (instancetype)bezierPathWithOvalInRect:(CGRect)r {
    UIBezierPath *p = [self new];
    double k = 0.5522847498, cx = CGRectGetMidX(r), cy = CGRectGetMidY(r), rx = r.size.width / 2, ry = r.size.height / 2;
    [p moveToPoint:CGPointMake(cx + rx, cy)];
    [p addCurveToPoint:CGPointMake(cx, cy + ry) controlPoint1:CGPointMake(cx + rx, cy + k * ry) controlPoint2:CGPointMake(cx + k * rx, cy + ry)];
    [p addCurveToPoint:CGPointMake(cx - rx, cy) controlPoint1:CGPointMake(cx - k * rx, cy + ry) controlPoint2:CGPointMake(cx - rx, cy + k * ry)];
    [p addCurveToPoint:CGPointMake(cx, cy - ry) controlPoint1:CGPointMake(cx - rx, cy - k * ry) controlPoint2:CGPointMake(cx - k * rx, cy - ry)];
    [p addCurveToPoint:CGPointMake(cx + rx, cy) controlPoint1:CGPointMake(cx + k * rx, cy - ry) controlPoint2:CGPointMake(cx + rx, cy - k * ry)];
    [p closePath];
    return p;
}
+ (instancetype)bezierPathWithArcCenter:(CGPoint)c radius:(CGFloat)r startAngle:(CGFloat)a0 endAngle:(CGFloat)a1 clockwise:(BOOL)cw {
    UIBezierPath *p = [self new]; [p addArcWithCenter:c radius:r startAngle:a0 endAngle:a1 clockwise:cw]; return p;
}
- (void)moveToPoint:(CGPoint)pt { [self _add:P_MOVE :pt.x :pt.y :0 :0 :0 :0]; [self _grow:pt]; }
- (void)addLineToPoint:(CGPoint)pt { [self _add:P_LINE :pt.x :pt.y :0 :0 :0 :0]; [self _grow:pt]; }
- (void)addCurveToPoint:(CGPoint)e controlPoint1:(CGPoint)c1 controlPoint2:(CGPoint)c2 { [self _add:P_CURVE :c1.x :c1.y :c2.x :c2.y :e.x :e.y]; [self _grow:e]; }
- (void)addQuadCurveToPoint:(CGPoint)e controlPoint:(CGPoint)c {
    path_el *last = _n ? &_e[_n - 1] : NULL;
    CGPoint s = last ? CGPointMake(last->v[last->op == P_CURVE ? 4 : 0], last->v[last->op == P_CURVE ? 5 : 1]) : e;
    [self addCurveToPoint:e controlPoint1:CGPointMake(s.x + 2.0 / 3 * (c.x - s.x), s.y + 2.0 / 3 * (c.y - s.y))
                           controlPoint2:CGPointMake(e.x + 2.0 / 3 * (c.x - e.x), e.y + 2.0 / 3 * (c.y - e.y))];
}
- (void)addArcWithCenter:(CGPoint)c radius:(CGFloat)r startAngle:(CGFloat)a0 endAngle:(CGFloat)a1 clockwise:(BOOL)cw {
    [self _add:P_ARC :c.x :c.y :r :a0 :a1 :cw];
    [self _grow:CGPointMake(c.x - r, c.y - r)]; [self _grow:CGPointMake(c.x + r, c.y + r)];
}
- (void)closePath { [self _add:P_CLOSE :0 :0 :0 :0 :0 :0]; }
- (void)removeAllPoints { _n = 0; _hasBounds = NO; }
- (void)appendPath:(UIBezierPath *)o { for (NSUInteger i = 0; i < o->_n; i++) { path_el *x = &o->_e[i]; [self _add:x->op :x->v[0] :x->v[1] :x->v[2] :x->v[3] :x->v[4] :x->v[5]]; } if (o->_hasBounds) { [self _grow:o->_bounds.origin]; [self _grow:CGPointMake(CGRectGetMaxX(o->_bounds), CGRectGetMaxY(o->_bounds))]; } }
- (BOOL)isEmpty { return _n == 0; }
- (CGRect)bounds { return _hasBounds ? _bounds : CGRectNull; }
- (id)copyWithZone:(NSZone *)z { UIBezierPath *p = [UIBezierPath new]; [p appendPath:self]; p.lineWidth = _lineWidth; return p; }
- (void)_replay {
    isim_path_begin();
    const path_el *e = _e; NSUInteger n = _n;
    for (NSUInteger i = 0; i < n; i++) {
        switch (e[i].op) {
        case P_MOVE: isim_path_move(e[i].v[0], e[i].v[1]); break;
        case P_LINE: isim_path_line(e[i].v[0], e[i].v[1]); break;
        case P_CURVE: isim_path_curve(e[i].v[0], e[i].v[1], e[i].v[2], e[i].v[3], e[i].v[4], e[i].v[5]); break;
        case P_CLOSE: isim_path_close(); break;
        case P_ARC: isim_path_arc(e[i].v[0], e[i].v[1], e[i].v[2], e[i].v[3], e[i].v[4], e[i].v[5] != 0); break;
        case P_RECT: isim_path_rect(e[i].v[0], e[i].v[1], e[i].v[2], e[i].v[3], e[i].v[4]); break;
        }
    }
}
- (void)fill { [self _replay]; CGContextFillPath(isim_cg_current_context()); }
- (void)stroke { [self _replay]; CGContextSetLineWidth(isim_cg_current_context(), _lineWidth); CGContextStrokePath(isim_cg_current_context()); }
@end


