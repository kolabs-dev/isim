/* UIKit attributed-string keys, NSParagraphStyle, NSShadow, string drawing (NSString / NSAttributedString),
 * offscreen image contexts (UIGraphicsBeginImageContext, UIGraphicsImageRenderer) and PNG/JPEG export.
 * Attributed text is turned into Pango markup and drawn by the host. */
#import "UIKitPrivate.h"
#include <math.h>

NSAttributedStringKey const NSFontAttributeName = @"NSFont";
NSAttributedStringKey const NSParagraphStyleAttributeName = @"NSParagraphStyle";
NSAttributedStringKey const NSForegroundColorAttributeName = @"NSColor";
NSAttributedStringKey const NSBackgroundColorAttributeName = @"NSBackgroundColor";
NSAttributedStringKey const NSLigatureAttributeName = @"NSLigature";
NSAttributedStringKey const NSKernAttributeName = @"NSKern";
NSAttributedStringKey const NSTrackingAttributeName = @"NSTracking";
NSAttributedStringKey const NSStrikethroughStyleAttributeName = @"NSStrikethrough";
NSAttributedStringKey const NSUnderlineStyleAttributeName = @"NSUnderline";
NSAttributedStringKey const NSStrokeColorAttributeName = @"NSStrokeColor";
NSAttributedStringKey const NSStrokeWidthAttributeName = @"NSStrokeWidth";
NSAttributedStringKey const NSShadowAttributeName = @"NSShadow";
NSAttributedStringKey const NSAttachmentAttributeName = @"NSAttachment";
NSAttributedStringKey const NSLinkAttributeName = @"NSLink";
NSAttributedStringKey const NSBaselineOffsetAttributeName = @"NSBaselineOffset";
NSAttributedStringKey const NSUnderlineColorAttributeName = @"NSUnderlineColor";
NSAttributedStringKey const NSStrikethroughColorAttributeName = @"NSStrikethroughColor";
NSAttributedStringKey const NSObliquenessAttributeName = @"NSObliqueness";
NSAttributedStringKey const NSExpansionAttributeName = @"NSExpansion";

/* ================= paragraph style, shadow ================= */
@interface NSParagraphStyle () {
@public
    CGFloat _ls, _ps, _hi, _ti, _fhi, _minLH, _maxLH, _lhm, _psb; NSTextAlignment _al; NSLineBreakMode _lbm; NSWritingDirection _wd; float _hy;
}
@end
@implementation NSParagraphStyle
+ (NSParagraphStyle *)defaultParagraphStyle { static NSParagraphStyle *d; if (!d) d = [NSParagraphStyle new]; return d; }
- (instancetype)init { if ((self = [super init])) { _al = NSTextAlignmentNatural; _lbm = NSLineBreakByWordWrapping; _wd = NSWritingDirectionNatural; } return self; }
- (CGFloat)lineSpacing { return _ls; }
- (CGFloat)paragraphSpacing { return _ps; }
- (NSTextAlignment)alignment { return _al; }
- (CGFloat)headIndent { return _hi; }
- (CGFloat)tailIndent { return _ti; }
- (CGFloat)firstLineHeadIndent { return _fhi; }
- (CGFloat)minimumLineHeight { return _minLH; }
- (CGFloat)maximumLineHeight { return _maxLH; }
- (NSLineBreakMode)lineBreakMode { return _lbm; }
- (NSWritingDirection)baseWritingDirection { return _wd; }
- (CGFloat)lineHeightMultiple { return _lhm; }
- (CGFloat)paragraphSpacingBefore { return _psb; }
- (float)hyphenationFactor { return _hy; }
- (id)_isim_copyAs:(Class)c {
    NSParagraphStyle *p = [c new];
    p->_ls = _ls; p->_ps = _ps; p->_hi = _hi; p->_ti = _ti; p->_fhi = _fhi; p->_minLH = _minLH; p->_maxLH = _maxLH; p->_lhm = _lhm; p->_psb = _psb;
    p->_al = _al; p->_lbm = _lbm; p->_wd = _wd; p->_hy = _hy;
    return p;
}
- (id)copyWithZone:(NSZone *)z { return [self _isim_copyAs:[NSParagraphStyle class]]; }
- (id)mutableCopyWithZone:(NSZone *)z { return [self _isim_copyAs:[NSMutableParagraphStyle class]]; }
- (BOOL)isEqual:(NSParagraphStyle *)o {
    return [o isKindOfClass:[NSParagraphStyle class]] && o->_ls == _ls && o->_ps == _ps && o->_al == _al && o->_lbm == _lbm && o->_hi == _hi && o->_fhi == _fhi && o->_ti == _ti;
}
- (NSUInteger)hash { return (NSUInteger)_al * 31 + (NSUInteger)_lbm + (NSUInteger)(_ls * 7); }
@end
@implementation NSMutableParagraphStyle
@dynamic lineSpacing, paragraphSpacing, alignment, firstLineHeadIndent, headIndent, tailIndent, lineBreakMode, minimumLineHeight, maximumLineHeight,
         baseWritingDirection, lineHeightMultiple, paragraphSpacingBefore, hyphenationFactor;
- (void)setLineSpacing:(CGFloat)v { _ls = v; }
- (void)setParagraphSpacing:(CGFloat)v { _ps = v; }
- (void)setAlignment:(NSTextAlignment)v { _al = v; }
- (void)setFirstLineHeadIndent:(CGFloat)v { _fhi = v; }
- (void)setHeadIndent:(CGFloat)v { _hi = v; }
- (void)setTailIndent:(CGFloat)v { _ti = v; }
- (void)setLineBreakMode:(NSLineBreakMode)v { _lbm = v; }
- (void)setMinimumLineHeight:(CGFloat)v { _minLH = v; }
- (void)setMaximumLineHeight:(CGFloat)v { _maxLH = v; }
- (void)setBaseWritingDirection:(NSWritingDirection)v { _wd = v; }
- (void)setLineHeightMultiple:(CGFloat)v { _lhm = v; }
- (void)setParagraphSpacingBefore:(CGFloat)v { _psb = v; }
- (void)setHyphenationFactor:(float)v { _hy = v; }
@end
@implementation NSShadow
- (instancetype)init { if ((self = [super init])) { _shadowOffset = CGSizeMake(0, -3); } return self; }
- (id)copyWithZone:(NSZone *)z { NSShadow *s = [NSShadow new]; s.shadowOffset = _shadowOffset; s.shadowBlurRadius = _shadowBlurRadius; s.shadowColor = _shadowColor; return s; }
@end
@implementation NSStringDrawingContext
- (CGFloat)actualScaleFactor { return 1; }
@end

/* ================= attributed text -> Pango markup ================= */
static void escape_into(NSMutableString *m, NSString *s) {
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (c == '&') [m appendString:@"&amp;"]; else if (c == '<') [m appendString:@"&lt;"]; else if (c == '>') [m appendString:@"&gt;"];
        else [m appendString:[NSString stringWithCharacters:&c length:1]];
    }
}
static NSString *hex_of(UIColor *c, double *alpha) {
    double v[4]; isim_ui_rgba(c, v); if (alpha) *alpha = v[3];
    return [NSString stringWithFormat:@"#%02x%02x%02x", (int)lround(v[0] * 255), (int)lround(v[1] * 255), (int)lround(v[2] * 255)];
}
/* UIFont.Weight (-1...1) to CSS weights, the same steps the host uses for plain text */
static int css_weight(double w) {
    return w < -0.6 ? 100 : w < -0.3 ? 200 : w < -0.1 ? 300 : w < 0.1 ? 400 : w < 0.26 ? 500 : w < 0.35 ? 600 : w < 0.5 ? 700 : w < 0.6 ? 800 : 900;
}
static void font_attrs(NSMutableString *m, UIFont *f) {
    if (!f) return;
    [m appendFormat:@" size=\"%ld\" weight=\"%d\"", lround(f.pointSize * 1024), css_weight(f._isim_weight)];   /* 1024ths of a point; the host lays out at 72 dpi (1 pt = 1 px) */
    if (f._isim_family.length) { [m appendString:@" font_family=\""]; escape_into(m, f._isim_family); [m appendString:@"\""]; }
    else if (f._isim_mono) [m appendString:@" font_family=\"monospace\""];
}
/* markup for the whole string; default font/colour apply where the string has none. Reports the first paragraph's
   alignment and line spacing (Pango lays out a paragraph style per layout) */
NSString *isim_ui_markup(NSAttributedString *s, UIFont *defFont, UIColor *defColor, NSTextAlignment *align, CGFloat *spacing) {
    NSMutableString *m = [NSMutableString stringWithString:@"<span"];
    font_attrs(m, defFont ?: [UIFont systemFontOfSize:17]);
    double a; NSString *hx = hex_of(defColor ?: UIColor.labelColor, &a);
    [m appendFormat:@" foreground=\"%@\" fgalpha=\"%d%%\">", hx, (int)lround(a * 100)];
    __block BOOL first = YES;
    [s enumerateAttributesInRange:NSMakeRange(0, s.length) options:0 usingBlock:^(NSDictionary *attrs, NSRange r, BOOL *stop) {
        NSParagraphStyle *ps = attrs[NSParagraphStyleAttributeName];
        if (first) { first = NO; if (ps && align) *align = ps.alignment; if (ps && spacing) *spacing = ps.lineSpacing; }
        NSMutableString *span = [NSMutableString stringWithString:@"<span"];
        font_attrs(span, attrs[NSFontAttributeName]);
        UIColor *fg = attrs[NSForegroundColorAttributeName] ?: (attrs[NSLinkAttributeName] ? UIColor.linkColor : nil);
        if (fg) { double al; NSString *h = hex_of(fg, &al); [span appendFormat:@" foreground=\"%@\" fgalpha=\"%d%%\"", h, (int)lround(al * 100)]; }
        UIColor *bg = attrs[NSBackgroundColorAttributeName];
        if (bg) { double al; NSString *h = hex_of(bg, &al); [span appendFormat:@" background=\"%@\" bgalpha=\"%d%%\"", h, (int)fmax(1, lround(al * 100))]; }
        NSNumber *kern = attrs[NSKernAttributeName] ?: attrs[NSTrackingAttributeName];
        if (kern.doubleValue) [span appendFormat:@" letter_spacing=\"%ld\"", lround(kern.doubleValue * 1024)];
        NSInteger ul = [attrs[NSUnderlineStyleAttributeName] integerValue];
        if (ul) [span appendFormat:@" underline=\"%@\"", (ul & 0xff) == NSUnderlineStyleDouble ? @"double" : @"single"];
        if (ul && attrs[NSUnderlineColorAttributeName]) [span appendFormat:@" underline_color=\"%@\"", hex_of(attrs[NSUnderlineColorAttributeName], NULL)];
        if ([attrs[NSStrikethroughStyleAttributeName] integerValue]) {
            [span appendString:@" strikethrough=\"true\""];
            if (attrs[NSStrikethroughColorAttributeName]) [span appendFormat:@" strikethrough_color=\"%@\"", hex_of(attrs[NSStrikethroughColorAttributeName], NULL)];
        }
        NSNumber *rise = attrs[NSBaselineOffsetAttributeName];
        if (rise.doubleValue) [span appendFormat:@" rise=\"%ld\"", lround(rise.doubleValue * 1024)];
        if ([attrs[NSObliquenessAttributeName] doubleValue] > 0) [span appendString:@" style=\"italic\""];
        [span appendString:@">"];
        [m appendString:span];
        escape_into(m, [s.string substringWithRange:r]);
        [m appendString:@"</span>"];
    }];
    [m appendString:@"</span>"];
    return m;
}
static int pango_align(NSTextAlignment a) { return a == NSTextAlignmentCenter ? 1 : a == NSTextAlignmentRight ? 2 : 0; }
CGSize isim_ui_measure_attributed(NSAttributedString *s, UIFont *f, UIColor *c, CGFloat maxw, NSInteger lines) {
    if (!s.length) return CGSizeZero;
    NSTextAlignment al = NSTextAlignmentNatural; CGFloat sp = 0;
    NSString *mk = isim_ui_markup(s, f, c, &al, &sp);
    double w, h; isim_text_measure_markup(mk.UTF8String, maxw, (int)lines, pango_align(al), sp, &w, &h);
    return CGSizeMake(w, h);
}
void isim_ui_draw_attributed(NSAttributedString *s, UIFont *f, UIColor *c, CGRect r, NSTextAlignment align, NSInteger lines, CGFloat alpha) {
    if (!s.length) return;
    NSTextAlignment al = align; CGFloat sp = 0;
    NSString *mk = isim_ui_markup(s, f, c, &al, &sp);
    double rgba[4] = { 0, 0, 0, alpha };
    double w, h; isim_text_measure_markup(mk.UTF8String, r.size.width, (int)lines, pango_align(al), sp, &w, &h);
    double y = r.origin.y + fmax(0, (r.size.height - h) / 2);          /* vertically centred like UILabel */
    isim_gfx_save();
    if (alpha < 1) isim_gfx_push_group();
    isim_text_draw_markup(mk.UTF8String, r.origin.x, y, r.size.width, (int)lines, pango_align(al), sp, rgba);
    if (alpha < 1) isim_gfx_pop_group(alpha);
    isim_gfx_restore();
}

/* ================= string drawing ================= */
static NSAttributedString *attributed(NSString *s, NSDictionary *attrs) { return [[NSAttributedString alloc] initWithString:s ?: @"" attributes:attrs]; }
@implementation NSString (NSStringDrawing)
- (CGSize)sizeWithAttributes:(NSDictionary *)attrs { return attributed(self, attrs).size; }
- (void)drawAtPoint:(CGPoint)p withAttributes:(NSDictionary *)attrs { [attributed(self, attrs) drawAtPoint:p]; }
- (void)drawInRect:(CGRect)r withAttributes:(NSDictionary *)attrs { [attributed(self, attrs) drawInRect:r]; }
- (void)drawWithRect:(CGRect)r options:(NSStringDrawingOptions)o attributes:(NSDictionary *)attrs context:(NSStringDrawingContext *)c { [attributed(self, attrs) drawWithRect:r options:o context:c]; }
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)o attributes:(NSDictionary *)attrs context:(NSStringDrawingContext *)c {
    return [attributed(self, attrs) boundingRectWithSize:size options:o context:c];
}
@end
@implementation NSAttributedString (NSStringDrawing)
- (CGSize)size { return isim_ui_measure_attributed(self, nil, nil, 0, 0); }
- (void)_isim_drawTop:(CGRect)r lines:(NSInteger)lines {
    if (!self.length) return;
    NSTextAlignment al = NSTextAlignmentNatural; CGFloat sp = 0;
    NSString *mk = isim_ui_markup(self, nil, nil, &al, &sp);
    double rgba[4] = { 0, 0, 0, 1 };
    isim_gfx_save();
    if (r.size.width > 0 && r.size.height > 0) isim_gfx_clip_rounded(r.origin.x, r.origin.y, r.size.width, r.size.height, 0);
    isim_text_draw_markup(mk.UTF8String, r.origin.x, r.origin.y, r.size.width, (int)lines, pango_align(al), sp, rgba);
    isim_gfx_restore();
}
- (void)drawAtPoint:(CGPoint)p { [self _isim_drawTop:CGRectMake(p.x, p.y, 0, 0) lines:0]; }
- (void)drawInRect:(CGRect)r { [self _isim_drawTop:r lines:0]; }
- (void)drawWithRect:(CGRect)r options:(NSStringDrawingOptions)o context:(NSStringDrawingContext *)c {
    if (o & NSStringDrawingUsesLineFragmentOrigin) [self _isim_drawTop:r lines:0];
    else [self _isim_drawTop:CGRectMake(r.origin.x, r.origin.y, 0, 0) lines:1];      /* single line at the baseline origin */
}
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)o context:(NSStringDrawingContext *)c {
    CGFloat w = (o & NSStringDrawingUsesLineFragmentOrigin) && size.width > 0 && size.width < 1e7 ? size.width : 0;
    CGSize s = isim_ui_measure_attributed(self, nil, nil, w, 0);
    return CGRectMake(0, 0, s.width, fmin(s.height, size.height > 0 ? size.height : s.height));
}
@end

/* ================= offscreen image contexts ================= */
@interface UIImage (IsimHandle)
+ (UIImage *)_isim_imageWithHandle:(int)h scale:(CGFloat)scale;
@end
static NSMutableArray<NSNumber *> *ctx_scales;
void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale) {
    if (scale <= 0) scale = isim_ui_device()->scale;
    if (!ctx_scales) ctx_scales = [NSMutableArray array];
    if (!isim_gfx_offscreen_begin(size.width, size.height, scale, opaque)) { NSLog(@"isim: UIGraphicsBeginImageContext: invalid size %@", NSStringFromCGSize(size)); return; }
    [ctx_scales addObject:@(scale)];
    CGContextSaveGState(UIGraphicsGetCurrentContext());
}
void UIGraphicsBeginImageContext(CGSize size) { UIGraphicsBeginImageContextWithOptions(size, NO, 1); }
UIImage *UIGraphicsGetImageFromCurrentImageContext(void) {
    if (!ctx_scales.count) return nil;
    int h = isim_gfx_offscreen_snapshot();
    return h ? [UIImage _isim_imageWithHandle:h scale:ctx_scales.lastObject.doubleValue] : nil;
}
void UIGraphicsEndImageContext(void) {
    if (!ctx_scales.count) return;
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
    [ctx_scales removeLastObject];
    isim_gfx_offscreen_end();
}
void UIGraphicsPushContext(CGContextRef c) { CGContextSaveGState(c); }
void UIGraphicsPopContext(void) { CGContextRestoreGState(UIGraphicsGetCurrentContext()); }

NSData *UIImagePNGRepresentation(UIImage *img) {
    if (!img) return nil;
    CGSize s = img.size; CGFloat sc = img.scale > 0 ? img.scale : 1;
    if (s.width <= 0 || s.height <= 0) return nil;
    UIGraphicsBeginImageContextWithOptions(s, NO, sc);
    [img drawInRect:CGRectMake(0, 0, s.width, s.height)];
    int h = isim_gfx_offscreen_snapshot();
    UIGraphicsEndImageContext();
    unsigned char *bytes = NULL; long n = h ? isim_image_encode(h, 0, 1, &bytes) : 0;
    if (h) isim_image_free(h);
    NSData *d = n > 0 ? [NSData dataWithBytes:bytes length:(NSUInteger)n] : nil;
    isim_image_bytes_free(bytes);
    return d;
}
NSData *UIImageJPEGRepresentation(UIImage *img, CGFloat q) {
    if (!img) return nil;
    CGSize s = img.size; CGFloat sc = img.scale > 0 ? img.scale : 1;
    if (s.width <= 0 || s.height <= 0) return nil;
    UIGraphicsBeginImageContextWithOptions(s, YES, sc);
    [img drawInRect:CGRectMake(0, 0, s.width, s.height)];
    int h = isim_gfx_offscreen_snapshot();
    UIGraphicsEndImageContext();
    unsigned char *bytes = NULL; long n = h ? isim_image_encode(h, 1, q, &bytes) : 0;
    if (h) isim_image_free(h);
    NSData *d = n > 0 ? [NSData dataWithBytes:bytes length:(NSUInteger)n] : nil;
    isim_image_bytes_free(bytes);
    return d;
}

/* ================= UIGraphicsImageRenderer ================= */
@interface UIGraphicsRendererFormat ()
@property (nonatomic, readwrite) CGRect bounds;
@end
@implementation UIGraphicsRendererFormat
+ (instancetype)defaultFormat { return [self new]; }
+ (instancetype)preferredFormat { return [self new]; }
- (id)copyWithZone:(NSZone *)z { UIGraphicsRendererFormat *f = [[self class] new]; f.bounds = _bounds; return f; }
@end
@implementation UIGraphicsImageRendererFormat
- (instancetype)init { if ((self = [super init])) { _scale = isim_ui_device()->scale; _preferredRange = UIGraphicsImageRendererFormatRangeAutomatic; } return self; }
- (id)copyWithZone:(NSZone *)z { UIGraphicsImageRendererFormat *f = [super copyWithZone:z]; f.scale = _scale; f.opaque = _opaque; f.preferredRange = _preferredRange; return f; }
@end
@interface UIGraphicsRendererContext ()
@property (nonatomic, readwrite, strong) UIGraphicsRendererFormat *format;
@end
@implementation UIGraphicsRendererContext
- (CGContextRef)CGContext { return UIGraphicsGetCurrentContext(); }
- (void)fillRect:(CGRect)r { CGContextFillRect(self.CGContext, r); }
- (void)strokeRect:(CGRect)r { CGContextStrokeRect(self.CGContext, r); }
- (void)clipToRect:(CGRect)r { CGContextClipToRect(self.CGContext, r); }
@end
@implementation UIGraphicsImageRendererContext
- (UIImage *)currentImage { return UIGraphicsGetImageFromCurrentImageContext(); }
@end
@interface UIGraphicsRenderer ()
@property (nonatomic, readwrite, strong) UIGraphicsRendererFormat *format;
@property (nonatomic) CGRect isimBounds;
@end
@implementation UIGraphicsRenderer
- (instancetype)initWithBounds:(CGRect)b { return [self initWithBounds:b format:[UIGraphicsImageRendererFormat defaultFormat]]; }
- (instancetype)initWithBounds:(CGRect)b format:(UIGraphicsRendererFormat *)f {
    if ((self = [super init])) { _isimBounds = b; _format = [f copy]; _format.bounds = b; }
    return self;
}
- (BOOL)allowsImageOutput { return YES; }
@end
@implementation UIGraphicsImageRenderer
- (instancetype)initWithSize:(CGSize)s { return [self initWithBounds:CGRectMake(0, 0, s.width, s.height) format:[UIGraphicsImageRendererFormat defaultFormat]]; }
- (instancetype)initWithSize:(CGSize)s format:(UIGraphicsImageRendererFormat *)f { return [self initWithBounds:CGRectMake(0, 0, s.width, s.height) format:f]; }
- (instancetype)initWithBounds:(CGRect)b format:(UIGraphicsImageRendererFormat *)f { return [super initWithBounds:b format:f]; }
- (int)_render:(UIGraphicsImageDrawingActions)actions scale:(CGFloat *)scaleOut {
    UIGraphicsImageRendererFormat *f = (UIGraphicsImageRendererFormat *)self.format;
    CGRect b = self.isimBounds; CGFloat scale = [f isKindOfClass:[UIGraphicsImageRendererFormat class]] && f.scale > 0 ? f.scale : isim_ui_device()->scale;
    BOOL opaque = [f isKindOfClass:[UIGraphicsImageRendererFormat class]] && f.opaque;
    UIGraphicsBeginImageContextWithOptions(b.size, opaque, scale);
    if (!ctx_scales.count) return 0;
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), -b.origin.x, -b.origin.y);
    UIGraphicsImageRendererContext *ctx = [UIGraphicsImageRendererContext new]; ctx.format = f;
    if (actions) actions(ctx);
    int h = isim_gfx_offscreen_snapshot();
    UIGraphicsEndImageContext();
    *scaleOut = scale;
    return h;
}
- (UIImage *)imageWithActions:(UIGraphicsImageDrawingActions)actions {
    CGFloat scale = 1; int h = [self _render:actions scale:&scale];
    return h ? [UIImage _isim_imageWithHandle:h scale:scale] : [UIImage new];
}
- (NSData *)_encode:(int)fmt quality:(CGFloat)q actions:(UIGraphicsImageDrawingActions)actions {
    CGFloat scale = 1; int h = [self _render:actions scale:&scale];
    unsigned char *bytes = NULL; long n = h ? isim_image_encode(h, fmt, q, &bytes) : 0;
    if (h) isim_image_free(h);
    NSData *d = [NSData dataWithBytes:bytes length:(NSUInteger)MAX(n, 0)];
    isim_image_bytes_free(bytes);
    return d;
}
- (NSData *)PNGDataWithActions:(UIGraphicsImageDrawingActions)actions { return [self _encode:0 quality:1 actions:actions]; }
- (NSData *)JPEGDataWithCompressionQuality:(CGFloat)q actions:(UIGraphicsImageDrawingActions)actions { return [self _encode:1 quality:q actions:actions]; }
@end
