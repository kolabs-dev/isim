/* UIColor extras (UIColor.h): pattern colours (views tile their image as a background; fills in a context use a CG
 * pattern), Core Image colours, hue / saturation / brightness, accessibility names, prominence, and the iOS 26 HDR
 * members (adapted: isim draws standard dynamic range). UIColorEffect (UIVisualEffectView.h). */
#import "UIKitPrivate.h"
#import <objc/runtime.h>
#import <objc/message.h>

/* ================= pattern colours ================= */
@interface __IsimPatternColor : UIColor
@property (nonatomic, strong) UIImage *patternImage;
@end
static void draw_pattern(void *info, CGContextRef c) {
    UIImage *img = (__bridge UIImage *)info;
    UIGraphicsPushContext(c);
    [img drawInRect:CGRectMake(0, 0, img.size.width, img.size.height)];
    UIGraphicsPopContext();
}
static void release_pattern(void *info) { CFRelease(info); }
@implementation __IsimPatternColor {
    CGPatternRef _pattern;
    CGColorRef _cgPattern;
}
- (void)dealloc { if (_pattern) CGPatternRelease(_pattern); if (_cgPattern) CGColorRelease(_cgPattern); }
- (CGPatternRef)_pattern {
    if (!_pattern) {
        CGSize s = _patternImage.size;
        static const CGPatternCallbacks cb = { 0, draw_pattern, release_pattern };
        _pattern = CGPatternCreate((void *)CFBridgingRetain(_patternImage), CGRectMake(0, 0, s.width, s.height), CGAffineTransformIdentity,
                                   s.width, s.height, kCGPatternTilingConstantSpacing, true, &cb);
    }
    return _pattern;
}
- (CGColorRef)CGColor {
    if (!_cgPattern && [self _pattern]) {
        CGColorSpaceRef sp = CGColorSpaceCreatePattern(NULL); CGFloat a = 1;
        _cgPattern = CGColorCreateWithPattern(sp, _pattern, &a);
        CGColorSpaceRelease(sp);
    }
    return _cgPattern;
}
- (void)setFill {
    CGContextRef c = UIGraphicsGetCurrentContext(); if (!c || ![self _pattern]) return;
    CGColorSpaceRef sp = CGColorSpaceCreatePattern(NULL); CGFloat a = 1;
    CGContextSetFillColorSpace(c, sp); CGContextSetFillPattern(c, _pattern, &a); CGColorSpaceRelease(sp);
}
- (void)setStroke {
    CGContextRef c = UIGraphicsGetCurrentContext(); if (!c || ![self _pattern]) return;
    CGColorSpaceRef sp = CGColorSpaceCreatePattern(NULL); CGFloat a = 1;
    CGContextSetStrokeColorSpace(c, sp); CGContextSetStrokePattern(c, _pattern, &a); CGColorSpaceRelease(sp);
}
/* no RGB components, as on iOS */
- (BOOL)getRed:(CGFloat *)r green:(CGFloat *)g blue:(CGFloat *)b alpha:(CGFloat *)a { return NO; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[__IsimPatternColor class]] && ((__IsimPatternColor *)o).patternImage == _patternImage; }
- (NSUInteger)hash { return (NSUInteger)(__bridge void *)_patternImage; }
- (NSString *)description { return [NSString stringWithFormat:@"UIPatternColor %gx%g", _patternImage.size.width, _patternImage.size.height]; }
@end
UIImage *isim_ui_pattern_image(UIColor *c) { return [c isKindOfClass:[__IsimPatternColor class]] ? ((__IsimPatternColor *)c).patternImage : nil; }

static char kProminence, kExposure;
static UIColor *with_exposure(UIColor *c, CGFloat linear) { objc_setAssociatedObject(c, &kExposure, @(linear), OBJC_ASSOCIATION_RETAIN_NONATOMIC); return c; }

@implementation UIColor (UIColorExtras)
- (instancetype)initWithCGColor:(CGColorRef)cg { return [UIColor colorWithCGColor:cg]; }
- (instancetype)initWithDisplayP3Red:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a { return [self initWithRed:r green:g blue:b alpha:a]; }
+ (UIColor *)colorWithPatternImage:(UIImage *)image {
    __IsimPatternColor *c = [[__IsimPatternColor alloc] initWithRed:0 green:0 blue:0 alpha:0];   /* plain fills draw nothing */
    c.patternImage = image;
    return c;
}
- (instancetype)initWithPatternImage:(UIImage *)image { return (id)[UIColor colorWithPatternImage:image]; }
+ (UIColor *)colorWithCIColor:(CIColor *)ci {
    CGFloat (^comp)(SEL) = ^CGFloat(SEL s) { return ((CGFloat (*)(id, SEL))objc_msgSend)(ci, s); };
    return [UIColor colorWithRed:comp(@selector(red)) green:comp(@selector(green)) blue:comp(@selector(blue)) alpha:comp(@selector(alpha))];
}
- (instancetype)initWithCIColor:(CIColor *)ci { return [UIColor colorWithCIColor:ci]; }
- (CIColor *)CIColor {
    Class k = NSClassFromString(@"CIColor");
    CGFloat r = 0, g = 0, b = 0, a = 0; [self getRed:&r green:&g blue:&b alpha:&a];
    return k ? ((id (*)(id, SEL, CGFloat, CGFloat, CGFloat, CGFloat))objc_msgSend)(k, NSSelectorFromString(@"colorWithRed:green:blue:alpha:"), r, g, b, a) : nil;
}
- (BOOL)getHue:(CGFloat *)hue saturation:(CGFloat *)sat brightness:(CGFloat *)bri alpha:(CGFloat *)alpha {
    CGFloat r, g, b, a;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) return NO;
    CGFloat mx = MAX(r, MAX(g, b)), mn = MIN(r, MIN(g, b)), d = mx - mn, h = 0;
    if (d > 0) {
        if (mx == r) h = fmod((g - b) / d, 6); else if (mx == g) h = (b - r) / d + 2; else h = (r - g) / d + 4;
        h /= 6; if (h < 0) h += 1;
    }
    if (hue) *hue = h; if (sat) *sat = mx > 0 ? d / mx : 0; if (bri) *bri = mx; if (alpha) *alpha = a;
    return YES;
}
- (NSString *)accessibilityName {
    CGFloat h, s, v, a;
    if (![self getHue:&h saturation:&s brightness:&v alpha:&a]) return @"pattern";
    if (s < 0.15 || v < 0.08) {
        return v < 0.08 ? @"black" : v < 0.35 ? @"dark gray" : v < 0.65 ? @"gray" : v < 0.92 ? @"light gray" : @"white";
    }
    NSArray *names = @[ @"red", @"orange", @"yellow", @"green", @"green", @"cyan", @"blue", @"blue", @"purple", @"pink", @"red" ];
    static const double edges[] = { 0.04, 0.11, 0.19, 0.30, 0.45, 0.53, 0.63, 0.72, 0.80, 0.93, 1.01 };
    NSUInteger i = 0; while (i < 10 && h >= edges[i]) i++;
    NSString *n = names[i];
    return v < 0.45 ? [@"dark " stringByAppendingString:n] : (s < 0.4 && v > 0.8) ? [@"light " stringByAppendingString:n] : n;
}
- (UIColorProminence)prominence { return [objc_getAssociatedObject(self, &kProminence) integerValue]; }
- (UIColor *)colorWithProminence:(UIColorProminence)p {
    static const double k[] = { 1, 0.6, 0.3, 0.18 };      /* the label colours' opacities */
    UIColor *base = self; double m = k[MAX(0, MIN(3, p))];
    UIColor *c = p == UIColorProminencePrimary ? [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return [base resolvedColorWithTraitCollection:t]; }]
        : [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
            UIColor *r = [base resolvedColorWithTraitCollection:t]; CGFloat a = 1; [r getRed:NULL green:NULL blue:NULL alpha:&a];
            return [r colorWithAlphaComponent:a * m]; }];
    objc_setAssociatedObject(c, &kProminence, @(p), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return c;
}
+ (UIColor *)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a linearExposure:(CGFloat)e {
    e = MAX(1, e);
    return with_exposure([UIColor colorWithRed:r * e green:g * e blue:b * e alpha:a], e);
}
+ (UIColor *)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a exposure:(CGFloat)e {
    return [self colorWithRed:r green:g blue:b alpha:a linearExposure:pow(2, MAX(0, e))];
}
- (CGFloat)linearExposure { NSNumber *n = objc_getAssociatedObject(self, &kExposure); return n ? n.doubleValue : 1; }
/* the same components measured against another peak white (isim keeps them; drawing is standard dynamic range) */
- (UIColor *)colorByApplyingContentHeadroom:(CGFloat)h {
    CGFloat r, g, b, a; if (![self getRed:&r green:&g blue:&b alpha:&a]) return self;
    return with_exposure([UIColor colorWithRed:r green:g blue:b alpha:a], MAX(1, h));
}
/* tone mapped into standard range: components divided by the exposure, then clamped */
- (UIColor *)standardDynamicRangeColor {
    CGFloat r, g, b, a, e = self.linearExposure; if (![self getRed:&r green:&g blue:&b alpha:&a]) return self;
    if (e <= 1 && r <= 1 && g <= 1 && b <= 1 && r >= 0 && g >= 0 && b >= 0) return self;
    CGFloat (^c)(CGFloat) = ^CGFloat(CGFloat x) { return MAX(0, MIN(1, x / e)); };
    return [UIColor colorWithRed:c(r) green:c(g) blue:c(b) alpha:a];
}
@end

/* ================= colour effect ================= */
@implementation UIColorEffect { UIColor *_color; }
+ (instancetype)colorEffectWithColor:(UIColor *)color { UIColorEffect *e = [self new]; e->_color = color; return e; }
- (UIColor *)_isimColor { return _color; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end

/* ================= PDF destinations (stub) ================= */
void UIGraphicsAddPDFContextDestinationAtPoint(NSString *name, CGPoint point) {}
void UIGraphicsSetPDFContextDestinationForRect(NSString *name, CGRect rect) {}
