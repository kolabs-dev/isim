/* UIImage (host-decoded bitmaps/SVG + SF Symbol substitutes), UIImageView, asset catalogs
 * (isim-assets.plist written by `isim build`), and UIColor colorNamed:. */
#import "UIKitPrivate.h"
#include <math.h>

/* ---------------- asset catalog index ---------------- */
static NSDictionary *asset_index(NSBundle *bundle) {
    static NSMutableDictionary *cache;
    if (!cache) cache = [NSMutableDictionary dictionary];
    NSString *path = [bundle.bundlePath stringByAppendingPathComponent:@"isim-assets.plist"];
    id v = cache[path];
    if (!v) { v = [NSDictionary dictionaryWithContentsOfFile:path] ?: (id)[NSNull null]; cache[path] = v; }
    return v == [NSNull null] ? nil : v;
}

/* ---------------- host image handle (shared between derived images) ---------------- */
@interface __IsimImageData : NSObject
@property (nonatomic) int handle;
@property (nonatomic, strong) id owner;            /* set when the handle belongs to someone else (a CGImage) */
@end
@implementation __IsimImageData
- (void)dealloc { if (_handle && !_owner) isim_image_free(_handle); }
@end

/* ---------------- symbol configuration ---------------- */
@implementation UIImageConfiguration
- (id)copyWithZone:(NSZone *)z { return self; }
- (UITraitCollection *)traitCollection { return nil; }
@end

@implementation UIImageSymbolConfiguration { CGFloat _pointSize; UIImageSymbolWeight _weight; UIImageSymbolScale _scale; }
+ (UIImageSymbolConfiguration *)unspecifiedConfiguration { return [self new]; }
+ (instancetype)configurationWithPointSize:(CGFloat)p weight:(UIImageSymbolWeight)w scale:(UIImageSymbolScale)s {
    UIImageSymbolConfiguration *c = [self new]; c->_pointSize = p; c->_weight = w; c->_scale = s; return c;
}
+ (instancetype)configurationWithPointSize:(CGFloat)p { return [self configurationWithPointSize:p weight:UIImageSymbolWeightUnspecified scale:UIImageSymbolScaleUnspecified]; }
+ (instancetype)configurationWithPointSize:(CGFloat)p weight:(UIImageSymbolWeight)w { return [self configurationWithPointSize:p weight:w scale:UIImageSymbolScaleUnspecified]; }
+ (instancetype)configurationWithScale:(UIImageSymbolScale)s { return [self configurationWithPointSize:0 weight:UIImageSymbolWeightUnspecified scale:s]; }
+ (instancetype)configurationWithWeight:(UIImageSymbolWeight)w { return [self configurationWithPointSize:0 weight:w scale:UIImageSymbolScaleUnspecified]; }
+ (instancetype)configurationWithTextStyle:(UIFontTextStyle)style { return [self configurationWithFont:[UIFont preferredFontForTextStyle:style]]; }
+ (instancetype)configurationWithFont:(UIFont *)font { return [self configurationWithPointSize:font.pointSize]; }
- (instancetype)configurationByApplyingConfiguration:(UIImageSymbolConfiguration *)o {
    if (!o) return self;
    return [UIImageSymbolConfiguration configurationWithPointSize:o->_pointSize ?: _pointSize weight:o->_weight ?: _weight scale:o->_scale ?: _scale];
}
- (CGFloat)_isim_pointSize { return _pointSize; }
- (UIImageSymbolWeight)_isim_weight { return _weight; }
- (UIImageSymbolScale)_isim_scale { return _scale; }
@end

/* ---------------- UIImage ---------------- */
@implementation UIImage {
    __IsimImageData *_data;
    CGSize _size; CGFloat _scale;
    UIImageRenderingMode _mode;
    BOOL _symbol;
    double _unitW, _unitH;              /* symbols: size per 1pt */
    UIImageSymbolConfiguration *_config;
    UIColor *_tint;
    NSString *_name;
    CGRect _crop;                       /* pixel rectangle of the host image; CGRectNull = all */
}
- (id)copyWithZone:(NSZone *)z { return self; }          /* images are immutable */

- (UIImage *)_copy {
    UIImage *i = [UIImage new];
    i->_data = _data; i->_size = _size; i->_scale = _scale; i->_mode = _mode; i->_symbol = _symbol;
    i->_unitW = _unitW; i->_unitH = _unitH; i->_config = _config; i->_tint = _tint; i->_name = _name; i->_crop = _crop;
    return i;
}

static UIImage *image_from_handle(int h, double w, double hgt, CGFloat scale) {
    if (!h) return nil;
    UIImage *i = [UIImage new];
    i->_data = [__IsimImageData new]; i->_data.handle = h;
    i->_scale = scale; i->_size = CGSizeMake(w / scale, hgt / scale); i->_crop = CGRectNull;
    return i;
}
- (instancetype)init { if ((self = [super init])) _crop = CGRectNull; return self; }
+ (UIImage *)_isim_imageWithHandle:(int)h scale:(CGFloat)scale { double w, hh; isim_image_pixel_size(h, &w, &hh); return image_from_handle(h, w, hh, scale > 0 ? scale : 1); }
- (instancetype)initWithContentsOfFile:(NSString *)p { return [UIImage imageWithContentsOfFile:p]; }
+ (UIImage *)imageWithData:(NSData *)d { return [self imageWithData:d scale:1]; }
+ (UIImage *)imageWithData:(NSData *)d scale:(CGFloat)s {
    if (!d.length) return nil;
    double w, h; int hd = isim_image_load_data(d.bytes, d.length, &w, &h);
    return image_from_handle(hd, w, h, s > 0 ? s : 1);
}
- (instancetype)initWithData:(NSData *)d { return [UIImage imageWithData:d scale:1]; }
- (instancetype)initWithData:(NSData *)d scale:(CGFloat)s { return [UIImage imageWithData:d scale:s]; }

/* ---- CGImage ---- */
+ (UIImage *)imageWithCGImage:(CGImageRef)cg { return [[self alloc] initWithCGImage:cg scale:1 orientation:UIImageOrientationUp]; }
+ (UIImage *)imageWithCGImage:(CGImageRef)cg scale:(CGFloat)scale orientation:(UIImageOrientation)o { return [[self alloc] initWithCGImage:cg scale:scale orientation:o]; }
- (instancetype)initWithCGImage:(CGImageRef)cg { return [self initWithCGImage:cg scale:1 orientation:UIImageOrientationUp]; }
- (instancetype)initWithCGImage:(CGImageRef)cg scale:(CGFloat)scale orientation:(UIImageOrientation)o {
    CGRect r; int h = isim_cg_image_handle(cg, &r);
    if (!h || !(self = [super init])) return nil;
    _data = [__IsimImageData new]; _data.handle = h; _data.owner = (__bridge id)cg;
    _scale = scale > 0 ? scale : 1; _crop = r;
    _size = CGSizeMake(r.size.width / _scale, r.size.height / _scale);
    return self;
}
- (CGImageRef)CGImage {
    if (_symbol || !_data.handle) return NULL;
    CGRect r = _crop;
    if (CGRectIsNull(r)) { double w, h; isim_image_pixel_size(_data.handle, &w, &h); r = CGRectMake(0, 0, w, h); }
    CGImageRef cg = isim_cg_image_create(_data.handle, r, (__bridge void *)(_data.owner ?: _data));
    return (CGImageRef)CFAutorelease(cg);
}
- (UIImageOrientation)imageOrientation { return UIImageOrientationUp; }

static CGFloat scale_from_name(NSString *path) {
    NSString *base = path.lastPathComponent.stringByDeletingPathExtension;
    if ([base hasSuffix:@"@3x"]) return 3;
    if ([base hasSuffix:@"@2x"]) return 2;
    return 1;
}

+ (UIImage *)imageWithContentsOfFile:(NSString *)path {
    double w, h;
    int hd = isim_image_load(path.UTF8String, &w, &h);
    UIImage *i = image_from_handle(hd, w, h, scale_from_name(path));
    if ([path.pathExtension.lowercaseString isEqualToString:@"svg"]) i->_scale = 1, i->_size = CGSizeMake(w, h);
    return i;
}

+ (UIImage *)imageNamed:(NSString *)name { return [self imageNamed:name inBundle:nil withConfiguration:nil]; }
+ (UIImage *)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle withConfiguration:(UIImageConfiguration *)config {
    if (!name.length) return nil;
    bundle = bundle ?: NSBundle.mainBundle;
    CGFloat devScale = isim_ui_device()->scale;
    /* 1) asset catalog: pick the variant for the current appearance closest to the screen scale */
    NSArray *variants = asset_index(bundle)[@"images"][name];
    if (variants.count) {
        NSString *want = isim_ui_style() == UIUserInterfaceStyleDark ? @"dark" : @"any";
        NSDictionary *best = nil; double bestScore = 1e9;
        for (NSDictionary *v in variants) {
            double s = [v[@"scale"] doubleValue] ?: 1;
            double score = fabs(s - devScale) + ([v[@"appearance"] isEqualToString:want] ? 0 : [v[@"appearance"] isEqualToString:@"any"] ? 10 : 100);
            if (score < bestScore) { bestScore = score; best = v; }
        }
        NSString *path = [bundle.bundlePath stringByAppendingPathComponent:best[@"file"]];
        double w, h; int hd = isim_image_load(path.UTF8String, &w, &h);
        CGFloat s = [best[@"scale"] doubleValue] ?: 1;
        UIImage *i = image_from_handle(hd, w, h, [path.pathExtension isEqualToString:@"svg"] || [path.pathExtension isEqualToString:@"pdf"] ? 1 : s);
        if (i) {
            i->_name = name;
            if ([best[@"templateRendering"] boolValue]) i->_mode = UIImageRenderingModeAlwaysTemplate;
            return i;
        }
    }
    /* 2) loose files in the bundle: name@3x.png, name@2x.png, name.png, name.jpg, name.svg */
    NSString *ext = name.pathExtension, *stem = ext.length ? name.stringByDeletingPathExtension : name;
    NSArray *exts = ext.length ? @[ext] : @[@"png", @"jpg", @"jpeg", @"svg"];
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *suffix in devScale >= 3 ? @[@"@3x", @"@2x", @""] : @[@"@2x", @"@3x", @""])
        for (NSString *e in exts) {
            NSString *path = [bundle.bundlePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@.%@", stem, suffix, e]];
            if ([fm fileExistsAtPath:path]) { UIImage *i = [self imageWithContentsOfFile:path]; i->_name = name; return i; }
        }
    return nil;
}

+ (UIImage *)systemImageNamed:(NSString *)name { return [self systemImageNamed:name withConfiguration:nil]; }
+ (UIImage *)systemImageNamed:(NSString *)name withConfiguration:(UIImageConfiguration *)config {
    double w, h;
    int hd = isim_image_symbol(name.UTF8String, &w, &h);
    if (!hd) return nil;
    UIImage *i = [UIImage new];
    i->_data = [__IsimImageData new]; i->_data.handle = hd;
    i->_symbol = YES; i->_unitW = w; i->_unitH = h; i->_scale = isim_ui_device()->scale; i->_name = name;
    i->_mode = UIImageRenderingModeAlwaysTemplate;
    i->_config = [config isKindOfClass:[UIImageSymbolConfiguration class]] ? (UIImageSymbolConfiguration *)config : nil;
    [i _isim_updateSymbolSize];
    return i;
}
- (void)_isim_updateSymbolSize {
    CGFloat pt = _config._isim_pointSize > 0 ? _config._isim_pointSize : 17;
    CGFloat k = _config._isim_scale == UIImageSymbolScaleSmall ? 0.8 : _config._isim_scale == UIImageSymbolScaleLarge ? 1.3 : 1;
    _size = CGSizeMake(round(_unitW * pt * k), round(_unitH * pt * k));
}

- (CGFloat)scale { return _scale ?: 1; }
- (CGSize)size { return _size; }
- (UIImageRenderingMode)renderingMode { return _mode; }
- (BOOL)isSymbolImage { return _symbol; }
- (UIImageSymbolConfiguration *)symbolConfiguration { return _config; }
- (BOOL)_isim_isTemplate { return _mode == UIImageRenderingModeAlwaysTemplate; }
- (UIImage *)imageWithRenderingMode:(UIImageRenderingMode)m { UIImage *i = [self _copy]; i->_mode = m; return i; }
- (UIImage *)imageWithTintColor:(UIColor *)c { return [self imageWithTintColor:c renderingMode:UIImageRenderingModeAlwaysOriginal]; }
- (UIImage *)imageWithTintColor:(UIColor *)c renderingMode:(UIImageRenderingMode)m { UIImage *i = [self _copy]; i->_tint = c; i->_mode = m; return i; }
- (UIImage *)imageByApplyingSymbolConfiguration:(UIImageSymbolConfiguration *)c {
    if (!_symbol) return self;
    UIImage *i = [self _copy]; i->_config = _config ? [_config configurationByApplyingConfiguration:c] : c; [i _isim_updateSymbolSize]; return i;
}
- (UIImage *)imageWithConfiguration:(UIImageConfiguration *)c {
    return [c isKindOfClass:[UIImageSymbolConfiguration class]] ? [self imageByApplyingSymbolConfiguration:(UIImageSymbolConfiguration *)c] : self;
}
- (NSString *)description { return [NSString stringWithFormat:@"<UIImage:%p %@%@ {%g, %g}>", self, _symbol ? @"symbol(substitute) " : @"", _name ?: @"", _size.width, _size.height]; }

- (void)_isim_drawInRect:(CGRect)r tint:(UIColor *)tint alpha:(CGFloat)alpha { [self _isim_drawInRect:r tint:tint alpha:alpha nearest:NO]; }
- (void)_isim_drawInRect:(CGRect)r tint:(UIColor *)tint alpha:(CGFloat)alpha nearest:(BOOL)nearest {
    double rgba[4]; const double *t = NULL;
    UIColor *c = _tint ?: (_mode == UIImageRenderingModeAlwaysTemplate ? (tint ?: UIColor.labelColor) : nil);
    if (c) { isim_ui_rgba(c, rgba); t = rgba; }
    if (!t && (nearest || !CGRectIsNull(_crop)) && !_symbol) {
        CGRect src = _crop;
        if (CGRectIsNull(src)) { double w, h; isim_image_pixel_size(_data.handle, &w, &h); src = CGRectMake(0, 0, w, h); }
        isim_image_draw_part(_data.handle, src.origin.x, src.origin.y, src.size.width, src.size.height,
                             r.origin.x, r.origin.y, r.size.width, r.size.height, nearest, NULL, 0, alpha);
        return;
    }
    isim_image_draw(_data.handle, r.origin.x, r.origin.y, r.size.width, r.size.height, t, alpha);
}
- (void)drawInRect:(CGRect)r { [self _isim_drawInRect:r tint:nil alpha:1]; }
- (void)drawAtPoint:(CGPoint)p { [self drawInRect:(CGRect){ p, _size }]; }
@end

/* ---------------- UIImageView ---------------- */
@implementation UIImageView
- (instancetype)initWithImage:(UIImage *)image {
    if ((self = [self initWithFrame:CGRectMake(0, 0, image.size.width, image.size.height)])) _image = image;
    return self;
}
- (void)setImage:(UIImage *)image { _image = image; [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
- (void)setPreferredSymbolConfiguration:(UIImageSymbolConfiguration *)c { _preferredSymbolConfiguration = c; [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
- (UIImage *)_shown { return _preferredSymbolConfiguration && _image.symbolImage ? [_image imageByApplyingSymbolConfiguration:_preferredSymbolConfiguration] : _image; }
- (CGSize)intrinsicContentSize { UIImage *i = [self _shown]; return i ? i.size : CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric); }
- (void)tintColorDidChange { isim_ui_set_needs_display(); }
- (void)_isim_drawContent {
    UIImage *img = [self _shown];
    if (!img) return;
    CGRect b = self.bounds; CGSize s = img.size;
    CGRect r = b;
    switch (self.contentMode) {
    case UIViewContentModeScaleAspectFit: case UIViewContentModeScaleAspectFill: {
        double k = self.contentMode == UIViewContentModeScaleAspectFit ? fmin(b.size.width / s.width, b.size.height / s.height) : fmax(b.size.width / s.width, b.size.height / s.height);
        if (!isfinite(k)) return;
        r = CGRectMake((b.size.width - s.width * k) / 2, (b.size.height - s.height * k) / 2, s.width * k, s.height * k);
        break; }
    case UIViewContentModeScaleToFill: case UIViewContentModeRedraw: break;
    default: {
        CGFloat x = (b.size.width - s.width) / 2, y = (b.size.height - s.height) / 2;
        UIViewContentMode m = self.contentMode;
        if (m == UIViewContentModeTop || m == UIViewContentModeTopLeft || m == UIViewContentModeTopRight) y = 0;
        if (m == UIViewContentModeBottom || m == UIViewContentModeBottomLeft || m == UIViewContentModeBottomRight) y = b.size.height - s.height;
        if (m == UIViewContentModeLeft || m == UIViewContentModeTopLeft || m == UIViewContentModeBottomLeft) x = 0;
        if (m == UIViewContentModeRight || m == UIViewContentModeTopRight || m == UIViewContentModeBottomRight) x = b.size.width - s.width;
        r = CGRectMake(x, y, s.width, s.height);
    } }
    /* symbols keep their aspect even with scaleToFill (as on iOS) */
    if (img.symbolImage && self.contentMode == UIViewContentModeScaleToFill) {
        double k = fmin(b.size.width / s.width, b.size.height / s.height);
        r = CGRectMake((b.size.width - s.width * k) / 2, (b.size.height - s.height * k) / 2, s.width * k, s.height * k);
    }
    [img _isim_drawInRect:r tint:self.tintColor alpha:1 nearest:[self.layer.magnificationFilter isEqualToString:kCAFilterNearest]];
}
@end

/* ---------------- named colors from the asset catalog ---------------- */
@implementation UIColor (IsimNamed)
+ (UIColor *)colorNamed:(NSString *)name { return [self colorNamed:name inBundle:nil compatibleWithTraitCollection:nil]; }
+ (UIColor *)colorNamed:(NSString *)name inBundle:(NSBundle *)bundle compatibleWithTraitCollection:(UITraitCollection *)traits {
    NSDictionary *variants = asset_index(bundle ?: NSBundle.mainBundle)[@"colors"][name];
    if (!variants.count) return nil;
    NSArray *any = variants[@"any"] ?: variants.allValues.firstObject, *dark = variants[@"dark"] ?: any;
    UIColor *light = [UIColor colorWithRed:[any[0] doubleValue] green:[any[1] doubleValue] blue:[any[2] doubleValue] alpha:[any[3] doubleValue]];
    UIColor *darkC = [UIColor colorWithRed:[dark[0] doubleValue] green:[dark[1] doubleValue] blue:[dark[2] doubleValue] alpha:[dark[3] doubleValue]];
    UIColor *c = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? darkC : light; }];
    if (traits) return [c resolvedColorWithTraitCollection:traits];
    return c;
}
@end
