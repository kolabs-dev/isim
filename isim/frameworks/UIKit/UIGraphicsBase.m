/* isim UIKit: colors, fonts, layers, traits, text helpers, graphics, images (ARC). */
#import "UIKitPrivate.h"
#include <objc/runtime.h>
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

static struct isim_device ui_dev; static BOOL ui_dev_init;
const struct isim_device *isim_ui_device(void) {
    if (!ui_dev_init) { isim_device_metrics(&ui_dev); ui_dev_init = YES; }
    return &ui_dev;
}
void isim_ui_device_refresh(void) { isim_device_metrics(&ui_dev); ui_dev_init = YES; }   /* after a rotation */

static UIUserInterfaceStyle cached_style;
/* ISIM_APPEARANCE, else Settings > Display & Brightness (AppleInterfaceStyle = "Dark" in the global domain) */
UIUserInterfaceStyle isim_ui_base_style(void) {
    if (!cached_style) {
        const char *e = getenv("ISIM_APPEARANCE");
        extern NSDictionary *isim_global_preferences(void);
        if (e && *e) cached_style = !strcmp(e, "dark") ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
        else cached_style = [isim_global_preferences()[@"AppleInterfaceStyle"] isEqual:@"Dark"] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    }
    return cached_style;
}
void isim_ui_reload_settings(void) { cached_style = 0; isim_ui_traits_invalidate(nil); }
/* isim_ui_style / isim_ui_push_style / isim_ui_pop_style: the trait stack (UITraits.m) */

const UIEdgeInsets UIEdgeInsetsZero = { 0, 0, 0, 0 };
const NSDirectionalEdgeInsets NSDirectionalEdgeInsetsZero = { 0, 0, 0, 0 };
NSString *NSStringFromUIEdgeInsets(UIEdgeInsets i) { return [NSString stringWithFormat:@"{%g, %g, %g, %g}", i.top, i.left, i.bottom, i.right]; }

/* ================= UIColor ================= */
@implementation UIColor {
    double _c[4];
    UIColor * (^_provider)(UITraitCollection *);
    CGColorRef _cg;
    UIColor *_lastResolved;          /* keeps the CGColor of a dynamic color's last resolution alive */
}
- (instancetype)initWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a {
    if ((self = [super init])) { _c[0] = r; _c[1] = g; _c[2] = b; _c[3] = a; }
    return self;
}
- (instancetype)initWithWhite:(CGFloat)w alpha:(CGFloat)a { return [self initWithRed:w green:w blue:w alpha:a]; }
/* keyed coding with Apple's keys (UIColorComponentCount, UIRed, UIGreen, UIBlue, UIAlpha; UIWhite and NSRGB are read too);
   a dynamic color is archived as its color for the current traits (adapted) */
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {
    UIColor *r = [self _resolved];
    [c encodeInteger:4 forKey:@"UIColorComponentCount"];
    [c encodeDouble:r->_c[0] forKey:@"UIRed"]; [c encodeDouble:r->_c[1] forKey:@"UIGreen"];
    [c encodeDouble:r->_c[2] forKey:@"UIBlue"]; [c encodeDouble:r->_c[3] forKey:@"UIAlpha"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    /* components set directly, not through -initWithRed:... (a Swift subclass that does not override it traps) */
    if (!(self = [super init])) return nil;
    double a = [c containsValueForKey:@"UIAlpha"] ? [c decodeDoubleForKey:@"UIAlpha"] : 1;
    if ([c containsValueForKey:@"UIRed"]) {
        _c[0] = [c decodeDoubleForKey:@"UIRed"]; _c[1] = [c decodeDoubleForKey:@"UIGreen"]; _c[2] = [c decodeDoubleForKey:@"UIBlue"]; _c[3] = a;
    } else if ([c containsValueForKey:@"UIWhite"]) {
        _c[0] = _c[1] = _c[2] = [c decodeDoubleForKey:@"UIWhite"]; _c[3] = a;
    } else {                                                 /* NSRGB: "r g b [a]" (NSColor-style archives) */
        NSUInteger n = 0; const uint8_t *b = [c decodeBytesForKey:@"NSRGB" returnedLength:&n];
        _c[0] = _c[1] = _c[2] = 0; _c[3] = 1;
        if (b) { NSString *s = [[NSString alloc] initWithBytes:b length:n encoding:NSASCIIStringEncoding]; sscanf(s.UTF8String ?: "", "%lf %lf %lf %lf", &_c[0], &_c[1], &_c[2], &_c[3]); }
    }
    return self;
}
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
+ (UIColor *)colorWithCGColor:(CGColorRef)cg { if (!cg) return [self clearColor]; double c[4]; isim_cg_color_rgba(cg, c); return [self colorWithRed:c[0] green:c[1] blue:c[2] alpha:c[3]]; }
+ (UIColor *)colorWithDynamicProvider:(UIColor * (^)(UITraitCollection *))p { return [[self alloc] initWithDynamicProvider:p]; }

static UIColor *rgb255(int r, int g, int b, double a) { return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a]; }
static UIColor *dyn(UIColor *light, UIColor *dark) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light; }];
}
/* with Increase Contrast (accessibilityContrast high) variants, per Apple's Human Interface Guidelines */
static UIColor *dyn4(UIColor *light, UIColor *dark, UIColor *lightHC, UIColor *darkHC) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        BOOL d = t.userInterfaceStyle == UIUserInterfaceStyleDark, hc = t.accessibilityContrast == UIAccessibilityContrastHigh;
        return d ? (hc ? darkHC : dark) : (hc ? lightHC : light);
    }];
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
FIXED(systemRedColor, dyn4(rgb255(255, 59, 48, 1), rgb255(255, 69, 58, 1), rgb255(215, 0, 21, 1), rgb255(255, 105, 97, 1)))
FIXED(systemGreenColor, dyn4(rgb255(52, 199, 89, 1), rgb255(48, 209, 88, 1), rgb255(36, 138, 61, 1), rgb255(48, 219, 91, 1)))
FIXED(systemBlueColor, dyn4(rgb255(0, 122, 255, 1), rgb255(10, 132, 255, 1), rgb255(0, 64, 221, 1), rgb255(64, 156, 255, 1)))
FIXED(systemOrangeColor, dyn4(rgb255(255, 149, 0, 1), rgb255(255, 159, 10, 1), rgb255(201, 52, 0, 1), rgb255(255, 179, 64, 1)))
FIXED(systemYellowColor, dyn4(rgb255(255, 204, 0, 1), rgb255(255, 214, 10, 1), rgb255(178, 80, 0, 1), rgb255(255, 212, 38, 1)))
FIXED(systemPinkColor, dyn4(rgb255(255, 45, 85, 1), rgb255(255, 55, 95, 1), rgb255(211, 15, 69, 1), rgb255(255, 100, 130, 1)))
FIXED(systemPurpleColor, dyn4(rgb255(175, 82, 222, 1), rgb255(191, 90, 242, 1), rgb255(137, 68, 171, 1), rgb255(218, 143, 255, 1)))
FIXED(systemTealColor, dyn4(rgb255(48, 176, 199, 1), rgb255(64, 200, 224, 1), rgb255(0, 130, 153, 1), rgb255(93, 230, 255, 1)))
FIXED(systemIndigoColor, dyn4(rgb255(88, 86, 214, 1), rgb255(94, 92, 230, 1), rgb255(54, 52, 163, 1), rgb255(125, 122, 255, 1)))
FIXED(systemMintColor, dyn4(rgb255(0, 199, 190, 1), rgb255(99, 230, 226, 1), rgb255(12, 129, 123, 1), rgb255(102, 212, 207, 1)))
FIXED(systemCyanColor, dyn4(rgb255(50, 173, 230, 1), rgb255(100, 210, 255, 1), rgb255(0, 113, 164, 1), rgb255(112, 215, 255, 1)))
FIXED(systemBrownColor, dyn4(rgb255(162, 132, 94, 1), rgb255(172, 142, 104, 1), rgb255(127, 101, 69, 1), rgb255(181, 148, 105, 1)))
FIXED(systemGrayColor, dyn4(rgb255(142, 142, 147, 1), rgb255(142, 142, 147, 1), rgb255(108, 108, 112, 1), rgb255(174, 174, 178, 1)))
FIXED(systemGray2Color, dyn(rgb255(174, 174, 178, 1), rgb255(99, 99, 102, 1)))
FIXED(systemGray3Color, dyn(rgb255(199, 199, 204, 1), rgb255(72, 72, 74, 1)))
FIXED(systemGray4Color, dyn(rgb255(209, 209, 214, 1), rgb255(58, 58, 60, 1)))
FIXED(systemGray5Color, dyn(rgb255(229, 229, 234, 1), rgb255(44, 44, 46, 1)))
FIXED(systemGray6Color, dyn(rgb255(242, 242, 247, 1), rgb255(28, 28, 30, 1)))
+ (UIColor *)tintColor { extern UIColor *isim_ui_accent_color(void); return isim_ui_accent_color() ?: [self systemBlueColor]; }
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
- (UIColor *)_resolved { return _provider ? [self resolvedColorWithTraitCollection:isim_ui_current_traits()] : self; }
- (BOOL)_isim_isDynamic { return _provider != nil; }
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
    if (x != self) { _lastResolved = x; return [x CGColor]; }     /* dynamic: the resolved color's (for the current traits) */
    if (!_cg) _cg = CGColorCreateSRGB(_c[0], _c[1], _c[2], _c[3]);
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

/* App fonts (Info.plist UIAppFonts), registered once per process before the first font lookup. */
void isim_ui_register_app_fonts(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSBundle *b = NSBundle.mainBundle;
        for (NSString *file in [b objectForInfoDictionaryKey:@"UIAppFonts"] ?: @[]) {
            if (![file isKindOfClass:[NSString class]]) continue;
            NSString *path = [b.bundlePath stringByAppendingPathComponent:file];
            if (![NSFileManager.defaultManager fileExistsAtPath:path]) path = [b pathForResource:file.stringByDeletingPathExtension ofType:file.pathExtension];
            if (path && isim_font_register(path.UTF8String)) NSLog(@"isim: registered app font %@", file);
            else NSLog(@"isim: UIAppFonts entry %@ not found in the bundle", file);
        }
    });
}

@implementation UIFont { CGFloat _size, _weight; BOOL _mono, _italic, _tabular; NSString *_name, *_family, *_design; }
+ (UIFont *)_size:(CGFloat)s weight:(CGFloat)w mono:(BOOL)m name:(NSString *)n {
    UIFont *f = [UIFont new]; f->_size = s; f->_weight = w; f->_mono = m; f->_name = n; return f;
}
+ (UIFont *)systemFontOfSize:(CGFloat)s { return [self systemFontOfSize:s weight:UIFontWeightRegular]; }
+ (UIFont *)boldSystemFontOfSize:(CGFloat)s { return [self systemFontOfSize:s weight:UIFontWeightBold]; }
+ (UIFont *)italicSystemFontOfSize:(CGFloat)s { UIFont *f = [self systemFontOfSize:s weight:UIFontWeightRegular]; f->_italic = YES; f->_name = @".SFUI-RegularItalic"; return f; }
+ (UIFont *)systemFontOfSize:(CGFloat)s weight:(UIFontWeight)w {
    extern CGFloat isim_ui_bold_text_weight(CGFloat w);     /* Settings > Accessibility > Bold Text (UIAccessibilityRuntime.m) */
    w = isim_ui_bold_text_weight(w);
    NSString *n = w >= UIFontWeightBold ? @".SFUI-Bold" : w >= UIFontWeightSemibold ? @".SFUI-Semibold" : w >= UIFontWeightMedium ? @".SFUI-Medium" : @".SFUI-Regular";
    return [self _size:s weight:w mono:NO name:n];
}
+ (UIFont *)monospacedDigitSystemFontOfSize:(CGFloat)s weight:(UIFontWeight)w { UIFont *f = [self systemFontOfSize:s weight:w]; f->_tabular = YES; return f; }
+ (UIFont *)monospacedSystemFontOfSize:(CGFloat)s weight:(UIFontWeight)w { return [self _size:s weight:w mono:YES name:@".SFMono-Regular"]; }
/* Fonts that ship with iOS: available by name even when the host lacks them (drawn with a similar host font). */
/* the app's registered fonts (UIAppFonts): families and their faces */
NSArray<NSString *> *isim_ui_app_font_faces(NSString *family) {
    isim_ui_register_app_fonts();
    NSMutableArray *a = [NSMutableArray array];
    char fam[128], ps[128];
    for (int i = 0; isim_font_app_face(i, fam, sizeof fam, ps, sizeof ps); i++) if (!family || [@(fam) isEqualToString:family]) [a addObject:family ? @(ps) : @(fam)];
    return family ? a : [NSOrderedSet orderedSetWithArray:a].array;
}
NSArray<NSString *> *isim_ui_app_font_families(void) { return isim_ui_app_font_faces(nil); }
/* the font families iOS ships and their faces (PostScript names), as UIFont.familyNames / fontNames(forFamilyName:)
   list them; drawn with the host's closest font (adapted: isim cannot ship Apple's fonts) */
NSDictionary<NSString *, NSArray<NSString *> *> *isim_ui_ios_font_families(void) {
    static NSDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = @{
            @"American Typewriter": @[@"AmericanTypewriter-Light", @"AmericanTypewriter", @"AmericanTypewriter-Semibold", @"AmericanTypewriter-Bold",
                                      @"AmericanTypewriter-CondensedLight", @"AmericanTypewriter-Condensed", @"AmericanTypewriter-CondensedBold"],
            @"Arial": @[@"ArialMT", @"Arial-ItalicMT", @"Arial-BoldMT", @"Arial-BoldItalicMT"],
            @"Avenir": @[@"Avenir-Light", @"Avenir-LightOblique", @"Avenir-Book", @"Avenir-BookOblique", @"Avenir-Roman", @"Avenir-Oblique",
                         @"Avenir-Medium", @"Avenir-MediumOblique", @"Avenir-Heavy", @"Avenir-HeavyOblique", @"Avenir-Black", @"Avenir-BlackOblique"],
            @"Avenir Next": @[@"AvenirNext-UltraLight", @"AvenirNext-UltraLightItalic", @"AvenirNext-Regular", @"AvenirNext-Italic", @"AvenirNext-Medium",
                              @"AvenirNext-MediumItalic", @"AvenirNext-DemiBold", @"AvenirNext-DemiBoldItalic", @"AvenirNext-Bold", @"AvenirNext-BoldItalic",
                              @"AvenirNext-Heavy", @"AvenirNext-HeavyItalic"],
            @"Baskerville": @[@"Baskerville", @"Baskerville-Italic", @"Baskerville-SemiBold", @"Baskerville-SemiBoldItalic", @"Baskerville-Bold", @"Baskerville-BoldItalic"],
            @"Chalkboard SE": @[@"ChalkboardSE-Light", @"ChalkboardSE-Regular", @"ChalkboardSE-Bold"],
            @"Courier": @[@"Courier", @"Courier-Oblique", @"Courier-Bold", @"Courier-BoldOblique"],
            @"Courier New": @[@"CourierNewPSMT", @"CourierNewPS-ItalicMT", @"CourierNewPS-BoldMT", @"CourierNewPS-BoldItalicMT"],
            @"Didot": @[@"Didot", @"Didot-Italic", @"Didot-Bold"],
            @"Futura": @[@"Futura-Medium", @"Futura-MediumItalic", @"Futura-Bold", @"Futura-CondensedMedium", @"Futura-CondensedExtraBold"],
            @"Georgia": @[@"Georgia", @"Georgia-Italic", @"Georgia-Bold", @"Georgia-BoldItalic"],
            @"Gill Sans": @[@"GillSans-Light", @"GillSans-LightItalic", @"GillSans", @"GillSans-Italic", @"GillSans-SemiBold", @"GillSans-SemiBoldItalic",
                            @"GillSans-Bold", @"GillSans-BoldItalic", @"GillSans-UltraBold"],
            @"Helvetica": @[@"Helvetica-Light", @"Helvetica-LightOblique", @"Helvetica", @"Helvetica-Oblique", @"Helvetica-Bold", @"Helvetica-BoldOblique"],
            @"Helvetica Neue": @[@"HelveticaNeue-UltraLight", @"HelveticaNeue-UltraLightItalic", @"HelveticaNeue-Thin", @"HelveticaNeue-ThinItalic",
                                 @"HelveticaNeue-Light", @"HelveticaNeue-LightItalic", @"HelveticaNeue", @"HelveticaNeue-Italic", @"HelveticaNeue-Medium",
                                 @"HelveticaNeue-MediumItalic", @"HelveticaNeue-Bold", @"HelveticaNeue-BoldItalic", @"HelveticaNeue-CondensedBold",
                                 @"HelveticaNeue-CondensedBlack"],
            @"Marker Felt": @[@"MarkerFelt-Thin", @"MarkerFelt-Wide"],
            @"Menlo": @[@"Menlo-Regular", @"Menlo-Italic", @"Menlo-Bold", @"Menlo-BoldItalic"],
            @"Noteworthy": @[@"Noteworthy-Light", @"Noteworthy-Bold"],
            @"Optima": @[@"Optima-Regular", @"Optima-Italic", @"Optima-Bold", @"Optima-BoldItalic", @"Optima-ExtraBlack"],
            @"Palatino": @[@"Palatino-Roman", @"Palatino-Italic", @"Palatino-Bold", @"Palatino-BoldItalic"],
            @"Rockwell": @[@"Rockwell-Regular", @"Rockwell-Italic", @"Rockwell-Bold", @"Rockwell-BoldItalic"],
            @"Times New Roman": @[@"TimesNewRomanPSMT", @"TimesNewRomanPS-ItalicMT", @"TimesNewRomanPS-BoldMT", @"TimesNewRomanPS-BoldItalicMT"],
            @"Trebuchet MS": @[@"TrebuchetMS", @"TrebuchetMS-Italic", @"TrebuchetMS-Bold", @"Trebuchet-BoldItalic"],
            @"Verdana": @[@"Verdana", @"Verdana-Italic", @"Verdana-Bold", @"Verdana-BoldItalic"],
        };
    });
    return d;
}
static NSString *ios_family_of_face(NSString *name) {
    for (NSString *fam in isim_ui_ios_font_families()) if ([isim_ui_ios_font_families()[fam] containsObject:name]) return fam;
    return nil;
}
static BOOL ios_builtin_family(NSString *name, BOOL *mono) {
    NSString *listed = ios_family_of_face(name);
    if (listed) { *mono = [@[@"Courier", @"Courier New", @"Menlo"] containsObject:listed]; return YES; }
    static NSArray *mono_fams, *fams;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mono_fams = @[@"Menlo", @"Courier", @"CourierNewPS", @"Courier New", @"SFMono", @".SFMono"];
        fams = @[@"Helvetica", @"HelveticaNeue", @"Helvetica Neue", @"Arial", @"ArialMT", @"Avenir", @"AvenirNext", @"Avenir Next",
                 @"Georgia", @"TimesNewRomanPS", @"Times New Roman", @"Palatino", @"Futura", @"GillSans", @"Gill Sans", @"Verdana",
                 @"TrebuchetMS", @"AmericanTypewriter", @"Baskerville", @"ChalkboardSE", @"Didot", @"Optima", @"Rockwell",
                 @"Noteworthy", @"MarkerFelt", @"Kailasa", @"HiraginoSans", @"PingFangSC", @"AppleSDGothicNeo", @".SFUI", @".SFUIText", @"SFProText", @"SFProDisplay"];
    });
    NSString *base = [name componentsSeparatedByString:@"-"].firstObject;
    for (NSString *f in mono_fams) if ([base isEqualToString:f]) { *mono = YES; return YES; }
    for (NSString *f in fams) if ([base isEqualToString:f]) { *mono = NO; return YES; }
    return NO;
}
+ (UIFont *)fontWithName:(NSString *)name size:(CGFloat)s {
    if (!name.length) return nil;
    isim_ui_register_app_fonts();
    char fam[256]; double w = 0; int italic = 0;
    if (isim_font_lookup(name.UTF8String, fam, sizeof fam, &w, &italic)) {
        UIFont *f = [self _size:s weight:w mono:NO name:name];
        f->_family = [NSString stringWithUTF8String:fam]; f->_italic = italic != 0;
        return f;
    }
    BOOL mono = NO;
    if (ios_builtin_family(name, &mono)) {
        NSString *l = name.lowercaseString;
        CGFloat weight = [l containsString:@"black"] || [l containsString:@"heavy"] || [l containsString:@"ultrabold"] ? UIFontWeightHeavy
                       : [l containsString:@"semibold"] || [l containsString:@"demibold"] ? UIFontWeightSemibold : [l containsString:@"bold"] ? UIFontWeightBold
                       : [l containsString:@"medium"] ? UIFontWeightMedium : [l containsString:@"ultralight"] ? UIFontWeightUltraLight
                       : [l containsString:@"thin"] ? UIFontWeightThin : [l containsString:@"light"] ? UIFontWeightLight : UIFontWeightRegular;
        UIFont *f = [self _size:s weight:weight mono:mono name:name];
        f->_italic = [l containsString:@"italic"] || [l containsString:@"oblique"];
        return f;
    }
    return nil;                 /* like iOS: no font with that name is available */
}
/* the iOS families, then the app's own (UIAppFonts) */
+ (NSArray<NSString *> *)familyNames {
    isim_ui_register_app_fonts();
    NSMutableOrderedSet *s = [NSMutableOrderedSet orderedSetWithArray:isim_ui_ios_font_families().allKeys];
    for (NSString *f in isim_ui_app_font_families()) [s addObject:f];
    return [s.array sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}
+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style {
    NSDictionary *sizes = @{ UIFontTextStyleLargeTitle: @34, UIFontTextStyleTitle1: @28, UIFontTextStyleTitle2: @22, UIFontTextStyleTitle3: @20,
                             UIFontTextStyleHeadline: @17, UIFontTextStyleBody: @17, UIFontTextStyleCallout: @16, UIFontTextStyleSubheadline: @15,
                             UIFontTextStyleFootnote: @13, UIFontTextStyleCaption1: @12, UIFontTextStyleCaption2: @11 };
    extern CGFloat isim_ui_content_size_multiplier(void);    /* Dynamic Type (UIAccessibilityRuntime.m) */
    extern void isim_ui_font_set_text_style(UIFont *f, NSString *style);
    CGFloat s = round(([sizes[style] doubleValue] ?: 17) * isim_ui_content_size_multiplier());
    UIFont *f = [self systemFontOfSize:s weight:[style isEqualToString:UIFontTextStyleHeadline] ? UIFontWeightSemibold : UIFontWeightRegular];
    isim_ui_font_set_text_style(f, style);
    return f;
}
+ (CGFloat)labelFontSize { return 17; }
+ (CGFloat)buttonFontSize { return 18; }
+ (CGFloat)smallSystemFontSize { return 12; }
+ (CGFloat)systemFontSize { return 14; }
- (UIFont *)fontWithSize:(CGFloat)s { UIFont *f = [self _isim_copy]; f->_size = s; return f; }
- (UIFont *)_isim_copy {
    UIFont *f = [UIFont _size:_size weight:_weight mono:_mono name:_name];
    f->_family = _family; f->_italic = _italic; f->_tabular = _tabular; f->_design = _design;
    return f;
}
/* a variant of this font (UIFontDescriptor): weight, italic, monospaced, tabular digits, design */
- (UIFont *)_isim_variantWeight:(CGFloat)w italic:(BOOL)it mono:(BOOL)mono tabular:(BOOL)tab design:(NSString *)design {
    UIFont *f = [self _isim_copy];
    extern NSString *isim_ui_font_text_style(UIFont *f); extern void isim_ui_font_set_text_style(UIFont *f, NSString *style);
    NSString *ts = isim_ui_font_text_style(self); if (ts) isim_ui_font_set_text_style(f, ts);    /* keeps following Dynamic Type */
    f->_weight = w; f->_italic = it; f->_mono = mono; f->_tabular = tab; f->_design = design;
    if (!_family) f->_name = mono ? @".SFMono-Regular" : w >= UIFontWeightBold ? @".SFUI-Bold" : w >= UIFontWeightSemibold ? @".SFUI-Semibold" : w >= UIFontWeightMedium ? @".SFUI-Medium" : @".SFUI-Regular";
    if (!_family && it) f->_name = [f->_name stringByAppendingString:@"Italic"];
    return f;
}
- (NSString *)familyName {
    if (_family) return _family;
    NSString *ios = _name ? ios_family_of_face(_name) : nil;      /* an iOS face, drawn by the system font */
    if (ios) return ios;
    if ([_design isEqualToString:@"NSCTFontUIFontDesignSerif"]) return @".New York";
    if ([_design isEqualToString:@"NSCTFontUIFontDesignRounded"]) return @".SF UI Rounded";
    return _mono ? @".SF Mono" : @".SF UI Text";
}
/* the family text is drawn with (nil: the system font); the serif design uses a serif face of the host (adapted).
   Named, not the "serif" alias: fontconfig binds aliases weakly, so the system font after it would win */
- (NSString *)_isim_family {
    if (_family) return _family;
    return [_design isEqualToString:@"NSCTFontUIFontDesignSerif"] ? @"New York,Noto Serif,DejaVu Serif,Liberation Serif,Tinos,Times New Roman,serif" : nil;
}
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
- (int)_isim_style { return (_mono ? 1 : 0) | (_italic ? 2 : 0) | (_tabular ? 4 : 0); }
- (BOOL)_isim_italic { return _italic; }
- (BOOL)_isim_tabular { return _tabular; }
- (NSString *)_isim_design { return _design; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(UIFont *)o { return [o isKindOfClass:[UIFont class]] && o->_size == _size && o->_weight == _weight && o->_mono == _mono && o->_italic == _italic && o->_tabular == _tabular && (o->_family == _family || [o->_family isEqualToString:_family]); }
- (NSUInteger)hash { return (NSUInteger)(_size * 100) ^ (NSUInteger)(_weight * 1000); }
- (NSString *)description { return [NSString stringWithFormat:@"<UICTFont: %p> font-family: \"%@\"; font-weight: %g; font-size: %.2fpt", self, self.familyName, _weight, _size]; }
@end

/* ================= text helpers ================= */
CGSize isim_ui_measure(NSString *text, UIFont *font, CGFloat maxWidth, NSInteger lines) {
    if (!text.length) return CGSizeZero;
    if (!font) font = [UIFont systemFontOfSize:17];
    double w, h;
    isim_text_measure_f(text.UTF8String, font._isim_family.UTF8String, font.pointSize, font._isim_weight, font._isim_style, maxWidth, (int)lines, &w, &h);
    return CGSizeMake(w, h);
}
CGPoint isim_ui_text_end_point(NSString *text, UIFont *font, CGFloat maxWidth) {
    if (!font) font = [UIFont systemFontOfSize:17];
    double x = 0, y = 0;
    if (text.length) isim_text_end_point_f(text.UTF8String, font._isim_family.UTF8String, font.pointSize, font._isim_weight, font._isim_style, maxWidth, &x, &y);
    return CGPointMake(x, y);
}
void isim_ui_draw_text(NSString *text, UIFont *font, UIColor *color, CGRect r, NSTextAlignment align, NSInteger lines, CGFloat alpha) {
    if (!text.length) return;
    if (!font) font = [UIFont systemFontOfSize:17];
    double c[4]; isim_ui_rgba(color ?: UIColor.labelColor, c); c[3] *= alpha;
    CGSize sz = isim_ui_measure(text, font, lines == 1 ? 0 : r.size.width, lines);
    double y = r.origin.y + (r.size.height - MIN(sz.height, r.size.height)) / 2;
    if (align == NSTextAlignmentNatural) align = isim_ui_drawing_rtl ? NSTextAlignmentRight : NSTextAlignmentLeft;   /* natural follows the layout direction */
    int a = align == NSTextAlignmentCenter ? 1 : align == NSTextAlignmentRight ? 2 : 0;
    isim_text_draw_f(text.UTF8String, font._isim_family.UTF8String, r.origin.x, y, r.size.width, font.pointSize, font._isim_weight, font._isim_style, a, (int)(lines == 1 ? 1 : lines), c);
}

/* CALayer: CoreAnimation.m */

/* ================= UIGraphics / UIBezierPath ================= */
CGContextRef UIGraphicsGetCurrentContext(void) { return isim_cg_current_context(); }
void UIRectFill(CGRect r) { CGContextFillRect(isim_cg_current_context(), r); }
void UIRectFrame(CGRect r) { CGContextStrokeRect(isim_cg_current_context(), r); }

/* backed by a CGMutablePath, like UIKit's: drawing replays it into the current context with the path's line and fill
   settings (saved and restored around fill / stroke, as UIKit does) */
@implementation UIBezierPath { CGMutablePathRef _path; CGFloat *_dash; NSInteger _ndash; CGFloat _phase; }
- (instancetype)init {
    if ((self = [super init])) { _path = CGPathCreateMutable(); _lineWidth = 1; _miterLimit = 10; _flatness = 0.6; _lineCapStyle = kCGLineCapButt; _lineJoinStyle = kCGLineJoinMiter; }
    return self;
}
- (void)dealloc { CGPathRelease(_path); free(_dash); }
+ (instancetype)bezierPath { return [self new]; }
+ (instancetype)bezierPathWithRect:(CGRect)r { UIBezierPath *p = [self new]; CGPathAddRect(p->_path, NULL, r); return p; }
+ (instancetype)bezierPathWithRoundedRect:(CGRect)r cornerRadius:(CGFloat)cr { UIBezierPath *p = [self new]; CGPathAddRoundedRect(p->_path, NULL, r, cr, cr); return p; }
+ (instancetype)bezierPathWithRoundedRect:(CGRect)r byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)radii {
    UIBezierPath *p = [self new];
    r = CGRectStandardize(r);
    double rx = fmin(fmax(radii.width, 0), r.size.width / 2), ry = fmin(fmax(radii.height, 0), r.size.height / 2), k = 0.5522847498;
    double x0 = CGRectGetMinX(r), y0 = CGRectGetMinY(r), x1 = CGRectGetMaxX(r), y1 = CGRectGetMaxY(r);
    double tl = corners & UIRectCornerTopLeft ? 1 : 0, tr = corners & UIRectCornerTopRight ? 1 : 0;
    double br = corners & UIRectCornerBottomRight ? 1 : 0, bl = corners & UIRectCornerBottomLeft ? 1 : 0;
    CGMutablePathRef q = p->_path;
    CGPathMoveToPoint(q, NULL, x0 + rx * tl, y0);
    CGPathAddLineToPoint(q, NULL, x1 - rx * tr, y0);
    if (tr) CGPathAddCurveToPoint(q, NULL, x1 - rx + rx * k, y0, x1, y0 + ry - ry * k, x1, y0 + ry);
    CGPathAddLineToPoint(q, NULL, x1, y1 - ry * br);
    if (br) CGPathAddCurveToPoint(q, NULL, x1, y1 - ry + ry * k, x1 - rx + rx * k, y1, x1 - rx, y1);
    CGPathAddLineToPoint(q, NULL, x0 + rx * bl, y1);
    if (bl) CGPathAddCurveToPoint(q, NULL, x0 + rx - rx * k, y1, x0, y1 - ry + ry * k, x0, y1 - ry);
    CGPathAddLineToPoint(q, NULL, x0, y0 + ry * tl);
    if (tl) CGPathAddCurveToPoint(q, NULL, x0, y0 + ry - ry * k, x0 + rx - rx * k, y0, x0 + rx, y0);
    CGPathCloseSubpath(q);
    return p;
}
+ (instancetype)bezierPathWithOvalInRect:(CGRect)r { UIBezierPath *p = [self new]; CGPathAddEllipseInRect(p->_path, NULL, r); return p; }
+ (instancetype)bezierPathWithArcCenter:(CGPoint)c radius:(CGFloat)r startAngle:(CGFloat)a0 endAngle:(CGFloat)a1 clockwise:(BOOL)cw {
    UIBezierPath *p = [self new]; [p addArcWithCenter:c radius:r startAngle:a0 endAngle:a1 clockwise:cw]; return p;
}
+ (instancetype)bezierPathWithCGPath:(CGPathRef)path { UIBezierPath *b = [self new]; b.CGPath = path; return b; }
- (void)moveToPoint:(CGPoint)pt { CGPathMoveToPoint(_path, NULL, pt.x, pt.y); }
- (void)addLineToPoint:(CGPoint)pt { CGPathAddLineToPoint(_path, NULL, pt.x, pt.y); }
- (void)addCurveToPoint:(CGPoint)e controlPoint1:(CGPoint)c1 controlPoint2:(CGPoint)c2 { CGPathAddCurveToPoint(_path, NULL, c1.x, c1.y, c2.x, c2.y, e.x, e.y); }
- (void)addQuadCurveToPoint:(CGPoint)e controlPoint:(CGPoint)c { CGPathAddQuadCurveToPoint(_path, NULL, c.x, c.y, e.x, e.y); }
/* UIKit's clockwise is in its flipped (y-down) coordinates: Core Graphics' counterclockwise */
- (void)addArcWithCenter:(CGPoint)c radius:(CGFloat)r startAngle:(CGFloat)a0 endAngle:(CGFloat)a1 clockwise:(BOOL)cw { CGPathAddArc(_path, NULL, c.x, c.y, r, a0, a1, !cw); }
- (void)closePath { CGPathCloseSubpath(_path); }
- (void)removeAllPoints { CGPathRelease(_path); _path = CGPathCreateMutable(); }
- (void)appendPath:(UIBezierPath *)o { if (o) CGPathAddPath(_path, NULL, o->_path); }
- (void)applyTransform:(CGAffineTransform)t { CGMutablePathRef p = CGPathCreateMutable(); CGPathAddPath(p, &t, _path); CGPathRelease(_path); _path = p; }
static void bezier_collect(void *info, const CGPathElement *e) {
    NSMutableArray *a = (__bridge NSMutableArray *)info;
    int n = e->type == kCGPathElementAddCurveToPoint ? 3 : e->type == kCGPathElementAddQuadCurveToPoint ? 2 : e->type == kCGPathElementCloseSubpath ? 0 : 1;
    NSMutableArray *el = [NSMutableArray arrayWithObject:@(e->type)];
    for (int k = 0; k < n; k++) { [el addObject:@(e->points[k].x)]; [el addObject:@(e->points[k].y)]; }
    [a addObject:el];
}
- (NSArray *)_elements { NSMutableArray *a = [NSMutableArray array]; CGPathApply(_path, (__bridge void *)a, bezier_collect); return a; }
static CGPoint el_pt(NSArray *el, int k) { return CGPointMake([el[1 + 2 * k] doubleValue], [el[2 + 2 * k] doubleValue]); }
/* each subpath drawn from its end to its start (closed subpaths stay closed) */
- (UIBezierPath *)bezierPathByReversingPath {
    UIBezierPath *out = [UIBezierPath new];
    out.lineWidth = _lineWidth; out.lineCapStyle = _lineCapStyle; out.lineJoinStyle = _lineJoinStyle; out.miterLimit = _miterLimit;
    out.flatness = _flatness; out.usesEvenOddFillRule = _usesEvenOddFillRule; [out setLineDash:_dash count:_ndash phase:_phase];
    NSArray *els = [self _elements];
    NSUInteger i = 0;
    while (i < els.count) {
        NSUInteger j = i + 1;                                  /* [i, j): one subpath starting with a move */
        while (j < els.count && [els[j][0] intValue] != kCGPathElementMoveToPoint) j++;
        if ([els[i][0] intValue] != kCGPathElementMoveToPoint) { i = j; continue; }
        BOOL closed = [els[j - 1][0] intValue] == kCGPathElementCloseSubpath;
        NSUInteger last = closed ? j - 2 : j - 1;
        NSArray *le = els[last]; int lt = [le[0] intValue];
        CGPoint end = lt == kCGPathElementMoveToPoint || lt == kCGPathElementAddLineToPoint ? el_pt(le, 0) : el_pt(le, lt == kCGPathElementAddCurveToPoint ? 2 : 1);
        [out moveToPoint:end];
        for (NSUInteger k = last; k > i; k--) {
            NSArray *e = els[k], *pe = els[k - 1]; int t = [e[0] intValue], pt = [pe[0] intValue];
            CGPoint prev = pt == kCGPathElementAddCurveToPoint ? el_pt(pe, 2) : pt == kCGPathElementAddQuadCurveToPoint ? el_pt(pe, 1) : el_pt(pe, 0);
            if (t == kCGPathElementAddCurveToPoint) [out addCurveToPoint:prev controlPoint1:el_pt(e, 1) controlPoint2:el_pt(e, 0)];
            else if (t == kCGPathElementAddQuadCurveToPoint) [out addQuadCurveToPoint:prev controlPoint:el_pt(e, 0)];
            else [out addLineToPoint:prev];
        }
        if (closed) [out closePath];
        i = j;
    }
    return out;
}
- (BOOL)isEmpty { return CGPathIsEmpty(_path); }
- (CGRect)bounds { return CGPathGetBoundingBox(_path); }
- (CGPoint)currentPoint { return CGPathGetCurrentPoint(_path); }
- (BOOL)containsPoint:(CGPoint)pt { return CGPathContainsPoint(_path, NULL, pt, _usesEvenOddFillRule); }
- (CGPathRef)CGPath { CGPathRef p = CGPathCreateCopy(_path); CFAutorelease(p); return p; }
- (void)setCGPath:(CGPathRef)path { CGPathRelease(_path); _path = path ? CGPathCreateMutableCopy(path) : CGPathCreateMutable(); }
- (void)setLineDash:(const CGFloat *)pattern count:(NSInteger)count phase:(CGFloat)phase {
    free(_dash); _dash = NULL; _ndash = 0; _phase = phase;
    if (pattern && count > 0) { _dash = malloc(count * sizeof *_dash); memcpy(_dash, pattern, count * sizeof *_dash); _ndash = count; }
}
- (void)getLineDash:(CGFloat *)pattern count:(NSInteger *)count phase:(CGFloat *)phase {
    if (pattern && _dash) memcpy(pattern, _dash, _ndash * sizeof *_dash);
    if (count) *count = _ndash;
    if (phase) *phase = _phase;
}
- (id)copyWithZone:(NSZone *)z {
    UIBezierPath *p = [[self class] new];
    p.CGPath = _path; p.lineWidth = _lineWidth; p.lineCapStyle = _lineCapStyle; p.lineJoinStyle = _lineJoinStyle; p.miterLimit = _miterLimit;
    p.flatness = _flatness; p.usesEvenOddFillRule = _usesEvenOddFillRule; [p setLineDash:_dash count:_ndash phase:_phase];
    return p;
}
/* NSSecureCoding (adapted: isim's keys; the elements as numbers) */
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:[self _elements] forKey:@"UIBezierPathElements"];
    [c encodeDouble:_lineWidth forKey:@"UIBezierPathLineWidth"]; [c encodeInt:_lineCapStyle forKey:@"UIBezierPathLineCapStyle"];
    [c encodeInt:_lineJoinStyle forKey:@"UIBezierPathLineJoinStyle"]; [c encodeDouble:_miterLimit forKey:@"UIBezierPathMiterLimit"];
    [c encodeDouble:_flatness forKey:@"UIBezierPathFlatness"]; [c encodeBool:_usesEvenOddFillRule forKey:@"UIBezierPathUsesEvenOddFillRule"];
    NSMutableArray *d = [NSMutableArray array]; for (NSInteger i = 0; i < _ndash; i++) [d addObject:@(_dash[i])];
    [c encodeObject:d forKey:@"UIBezierPathLineDashPattern"]; [c encodeDouble:_phase forKey:@"UIBezierPathLineDashPhase"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if (!(self = [self init])) return nil;
    NSArray *els = [c decodeObjectOfClasses:[NSSet setWithObjects:NSArray.class, NSNumber.class, nil] forKey:@"UIBezierPathElements"];
    for (NSArray *e in els) {
        if (![e isKindOfClass:NSArray.class] || !e.count) continue;
        int t = [e[0] intValue]; NSUInteger need = t == kCGPathElementAddCurveToPoint ? 7 : t == kCGPathElementAddQuadCurveToPoint ? 5 : t == kCGPathElementCloseSubpath ? 1 : 3;
        if (e.count < need) continue;
        if (t == kCGPathElementMoveToPoint) [self moveToPoint:el_pt(e, 0)];
        else if (t == kCGPathElementAddLineToPoint) [self addLineToPoint:el_pt(e, 0)];
        else if (t == kCGPathElementAddQuadCurveToPoint) [self addQuadCurveToPoint:el_pt(e, 1) controlPoint:el_pt(e, 0)];
        else if (t == kCGPathElementAddCurveToPoint) [self addCurveToPoint:el_pt(e, 2) controlPoint1:el_pt(e, 0) controlPoint2:el_pt(e, 1)];
        else if (t == kCGPathElementCloseSubpath) [self closePath];
    }
    if ([c containsValueForKey:@"UIBezierPathLineWidth"]) _lineWidth = [c decodeDoubleForKey:@"UIBezierPathLineWidth"];
    _lineCapStyle = [c decodeIntForKey:@"UIBezierPathLineCapStyle"]; _lineJoinStyle = [c decodeIntForKey:@"UIBezierPathLineJoinStyle"];
    if ([c containsValueForKey:@"UIBezierPathMiterLimit"]) _miterLimit = [c decodeDoubleForKey:@"UIBezierPathMiterLimit"];
    if ([c containsValueForKey:@"UIBezierPathFlatness"]) _flatness = [c decodeDoubleForKey:@"UIBezierPathFlatness"];
    _usesEvenOddFillRule = [c decodeBoolForKey:@"UIBezierPathUsesEvenOddFillRule"];
    NSArray *d = [c decodeObjectOfClasses:[NSSet setWithObjects:NSArray.class, NSNumber.class, nil] forKey:@"UIBezierPathLineDashPattern"];
    if (d.count) { CGFloat v[d.count]; for (NSUInteger i = 0; i < d.count; i++) v[i] = [d[i] doubleValue]; [self setLineDash:v count:d.count phase:[c decodeDoubleForKey:@"UIBezierPathLineDashPhase"]]; }
    return self;
}
- (void)_applyLineStyle:(CGContextRef)c {
    CGContextSetLineWidth(c, _lineWidth); CGContextSetLineCap(c, _lineCapStyle); CGContextSetLineJoin(c, _lineJoinStyle);
    CGContextSetMiterLimit(c, _miterLimit); CGContextSetFlatness(c, _flatness); CGContextSetLineDash(c, _phase, _dash, _ndash);
}
- (void)fillWithBlendMode:(CGBlendMode)mode alpha:(CGFloat)alpha {
    CGContextRef c = isim_cg_current_context(); if (!c) return;
    CGContextSaveGState(c);
    CGContextSetBlendMode(c, mode); CGContextSetAlpha(c, alpha);
    CGContextBeginPath(c); CGContextAddPath(c, _path);
    if (_usesEvenOddFillRule) CGContextEOFillPath(c); else CGContextFillPath(c);
    CGContextRestoreGState(c);
}
- (void)strokeWithBlendMode:(CGBlendMode)mode alpha:(CGFloat)alpha {
    CGContextRef c = isim_cg_current_context(); if (!c) return;
    CGContextSaveGState(c);
    CGContextSetBlendMode(c, mode); CGContextSetAlpha(c, alpha); [self _applyLineStyle:c];
    CGContextBeginPath(c); CGContextAddPath(c, _path); CGContextStrokePath(c);
    CGContextRestoreGState(c);
}
- (void)fill { [self fillWithBlendMode:kCGBlendModeNormal alpha:1]; }
- (void)stroke { [self strokeWithBlendMode:kCGBlendModeNormal alpha:1]; }
/* intersects the context's clip with the path (not saved: like UIKit, callers save / restore the gstate) */
- (void)addClip {
    CGContextRef c = isim_cg_current_context(); if (!c) return;
    CGContextBeginPath(c); CGContextAddPath(c, _path);
    if (_usesEvenOddFillRule) CGContextEOClip(c); else CGContextClip(c);
}
- (NSString *)description { return [NSString stringWithFormat:@"<UIBezierPath: %p; %@>", self, CGPathIsEmpty(_path) ? @"empty" : NSStringFromCGRect(self.bounds)]; }
@end


