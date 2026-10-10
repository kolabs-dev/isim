/* UIImage (host-decoded bitmaps/SVG + SF Symbol substitutes), UIImageView, asset catalogs
 * (isim-assets.plist written by `isim build`), and UIColor colorNamed:. */
#import "UIKitPrivate.h"
#include <math.h>
#include <isim_host_cg.h>
#include <objc/runtime.h>
@interface UIImageSymbolConfiguration (IsimClone)
- (instancetype)_isim_clone;
@end
@interface UIImageAsset (IsimCatalog)
+ (instancetype)_isim_assetNamed:(NSString *)name bundle:(NSBundle *)bundle variants:(NSArray *)variants;
@end

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
static char k_config_traits;
@implementation UIImageConfiguration
- (id)copyWithZone:(NSZone *)z { return self; }
- (UITraitCollection *)traitCollection { return objc_getAssociatedObject(self, &k_config_traits); }
+ (instancetype)configurationWithTraitCollection:(UITraitCollection *)t { return [[self new] configurationWithTraitCollection:t]; }
- (instancetype)configurationWithTraitCollection:(UITraitCollection *)t {
    UIImageConfiguration *c = [self isKindOfClass:[UIImageSymbolConfiguration class]] ? [(UIImageSymbolConfiguration *)self _isim_clone] : [[self class] new];
    objc_setAssociatedObject(c, &k_config_traits, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return c;
}
@end

/* ---------------- appearance variants: asset catalog keys ("any", "light", "dark", "+-high") ---------------- */
/* how well a variant's appearance key suits the traits (lower is better; >= 1000: unusable) */
static int appearance_score(NSString *key, UITraitCollection *t) {
    BOOL dark = (t.userInterfaceStyle == UIUserInterfaceStyleUnspecified ? isim_ui_style() : t.userInterfaceStyle) == UIUserInterfaceStyleDark;
    BOOL hc = t.accessibilityContrast == UIAccessibilityContrastUnspecified ? UIAccessibilityIsDarkerSystemColorsEnabled() : t.accessibilityContrast == UIAccessibilityContrastHigh;
    BOOL keyHigh = [key hasSuffix:@"-high"];
    NSString *lum = keyHigh ? [key substringToIndex:key.length - 5] : key;
    int s = 0;
    if ([lum isEqualToString:@"dark"]) s += dark ? 0 : 1000;
    else if ([lum isEqualToString:@"light"]) s += dark ? 1000 : 0;
    else if ([lum isEqualToString:@"any"]) s += dark ? 10 : 1;
    else return 5000;                                   /* tinted and other appearances: not for drawing */
    if (keyHigh) s += hc ? 0 : 1000; else s += hc ? 5 : 0;
    return s;
}

/* rendering modes */
enum { SYM_MODE_UNSPECIFIED, SYM_MODE_MONOCHROME, SYM_MODE_HIERARCHICAL, SYM_MODE_PALETTE, SYM_MODE_MULTICOLOR };
@implementation UIImageSymbolConfiguration { CGFloat _pointSize; UIImageSymbolWeight _weight; UIImageSymbolScale _scale; int _symMode; NSArray<UIColor *> *_symColors; }
+ (UIImageSymbolConfiguration *)unspecifiedConfiguration { return [self new]; }
+ (instancetype)configurationWithPointSize:(CGFloat)p weight:(UIImageSymbolWeight)w scale:(UIImageSymbolScale)s {
    UIImageSymbolConfiguration *c = [self new]; c->_pointSize = p; c->_weight = w; c->_scale = s; return c;
}
+ (instancetype)configurationWithPointSize:(CGFloat)p { return [self configurationWithPointSize:p weight:UIImageSymbolWeightUnspecified scale:UIImageSymbolScaleUnspecified]; }
+ (instancetype)configurationWithPointSize:(CGFloat)p weight:(UIImageSymbolWeight)w { return [self configurationWithPointSize:p weight:w scale:UIImageSymbolScaleUnspecified]; }
+ (instancetype)configurationWithScale:(UIImageSymbolScale)s { return [self configurationWithPointSize:0 weight:UIImageSymbolWeightUnspecified scale:s]; }
+ (instancetype)configurationWithWeight:(UIImageSymbolWeight)w { return [self configurationWithPointSize:0 weight:w scale:UIImageSymbolScaleUnspecified]; }
+ (instancetype)configurationWithTextStyle:(UIFontTextStyle)style { return [self configurationWithFont:[UIFont preferredFontForTextStyle:style]]; }
/* the font's weight carries over (Image(systemName:).fontWeight(.bold), .font(.system(size:weight:))) */
+ (instancetype)configurationWithFont:(UIFont *)font {
    CGFloat fw = font._isim_weight;
    UIImageSymbolWeight w = fw <= -0.7 ? UIImageSymbolWeightUltraLight : fw <= -0.5 ? UIImageSymbolWeightThin : fw <= -0.2 ? UIImageSymbolWeightLight
        : fw < 0.1 ? UIImageSymbolWeightUnspecified : fw < 0.27 ? UIImageSymbolWeightMedium : fw < 0.35 ? UIImageSymbolWeightSemibold
        : fw < 0.5 ? UIImageSymbolWeightBold : fw < 0.6 ? UIImageSymbolWeightHeavy : UIImageSymbolWeightBlack;
    return [self configurationWithPointSize:font.pointSize weight:w];
}
+ (instancetype)_isimMode:(int)mode colors:(NSArray<UIColor *> *)colors { UIImageSymbolConfiguration *c = [self new]; c->_symMode = mode; c->_symColors = [colors copy]; return c; }
+ (instancetype)configurationWithHierarchicalColor:(UIColor *)color { return [self _isimMode:SYM_MODE_HIERARCHICAL colors:color ? @[color] : @[]]; }
+ (instancetype)configurationWithPaletteColors:(NSArray<UIColor *> *)colors { return [self _isimMode:SYM_MODE_PALETTE colors:colors ?: @[]]; }
+ (instancetype)configurationPreferringMulticolor { return [self _isimMode:SYM_MODE_MULTICOLOR colors:nil]; }
+ (instancetype)configurationPreferringMonochrome { return [self _isimMode:SYM_MODE_MONOCHROME colors:nil]; }
- (instancetype)_isim_clone {
    UIImageSymbolConfiguration *c = [UIImageSymbolConfiguration new];
    c->_pointSize = _pointSize; c->_weight = _weight; c->_scale = _scale; c->_symMode = _symMode; c->_symColors = _symColors;
    return c;
}
/* the other configuration's values win where it has them (size, weight, scale, rendering mode and colours) */
- (instancetype)configurationByApplyingConfiguration:(UIImageSymbolConfiguration *)o {
    if (!o) return self;
    UIImageSymbolConfiguration *c = [UIImageSymbolConfiguration configurationWithPointSize:o->_pointSize ?: _pointSize weight:o->_weight ?: _weight scale:o->_scale ?: _scale];
    c->_symMode = o->_symMode ?: _symMode; c->_symColors = o->_symMode ? o->_symColors : _symColors;
    return c;
}
- (int)_isim_renderingMode { return _symMode; }
- (NSArray<UIColor *> *)_isim_renderingColors { return _symColors; }
- (CGFloat)_isim_pointSize { return _pointSize; }
- (UIImageSymbolWeight)_isim_weight { return _weight; }
- (UIImageSymbolScale)_isim_scale { return _scale; }
@end

/* ---------------- UIImage ---------------- */
@implementation UIImage {
    BOOL _flipsRTL;                     /* imageFlippedForRightToLeftLayoutDirection */
    __IsimImageData *_data;
    CGSize _size; CGFloat _scale;
    UIImageRenderingMode _mode;
    BOOL _symbol;
    double _unitW, _unitH;              /* symbols: size per 1pt */
    UIImageSymbolConfiguration *_config;
    UIColor *_tint;
    NSString *_name;
    CGRect _crop;                       /* pixel rectangle of the host image; CGRectNull = all */
    UIImageOrientation _orient;         /* how the stored pixels are shown (Left/Right swap the size) */
    UIEdgeInsets _caps; UIImageResizingMode _rmode; BOOL _resizable;
    NSArray<UIImage *> *_frames; NSTimeInterval _duration;      /* animated images */
    UIImageAsset *_asset;               /* appearance variants (asset catalog light/dark/high contrast, registered images) */
}
/* NSItemProviderReading / Writing: PNG, JPEG and HEIC data read; PNG written (like iOS, which also offers JPEG) */
+ (NSArray<NSString *> *)readableTypeIdentifiersForItemProvider { return @[@"public.png", @"public.jpeg", @"public.heic", @"public.image"]; }
+ (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider { return @[@"public.png", @"public.jpeg"]; }
- (CGSize)preferredPresentationSizeForItemProvider { return self.size; }
+ (instancetype)objectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)t error:(NSError **)e {
    UIImage *img = [[self alloc] initWithData:data];
    if (!img && e) *e = [NSError errorWithDomain:NSItemProviderErrorDomain code:NSItemProviderUnavailableCoercionError userInfo:nil];
    return img;
}
- (NSProgress *)loadDataWithTypeIdentifier:(NSString *)t forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))done {
    NSData *d = [t isEqualToString:@"public.jpeg"] ? UIImageJPEGRepresentation(self, 0.9) : UIImagePNGRepresentation(self);
    done(d, d ? nil : [NSError errorWithDomain:NSItemProviderErrorDomain code:NSItemProviderItemUnavailableError userInfo:nil]);
    return nil;
}
/* NSSecureCoding: the image as PNG data and its scale (symbol and template details are not kept) */
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {
    NSData *png = UIImagePNGRepresentation(self);
    if (png) [c encodeObject:png forKey:@"UIImagePNG"];
    [c encodeDouble:self.scale forKey:@"UIImageScale"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    NSData *png = [c decodeObjectOfClass:[NSData class] forKey:@"UIImagePNG"];
    double scale = [c decodeDoubleForKey:@"UIImageScale"];
    return png ? [UIImage imageWithData:png scale:scale > 0 ? scale : 1] : nil;
}
- (id)copyWithZone:(NSZone *)z { return self; }          /* images are immutable */

- (UIImage *)_copy {
    UIImage *i = [UIImage new];
    i->_data = _data; i->_size = _size; i->_scale = _scale; i->_mode = _mode; i->_symbol = _symbol;
    i->_unitW = _unitW; i->_unitH = _unitH; i->_config = _config; i->_tint = _tint; i->_name = _name; i->_crop = _crop;
    i->_flipsRTL = _flipsRTL;
    i->_orient = _orient; i->_caps = _caps; i->_rmode = _rmode; i->_resizable = _resizable; i->_frames = _frames; i->_duration = _duration;
    i->_asset = _asset;
    return i;
}
- (UIImageAsset *)imageAsset { return _asset; }
- (void)_isim_setAsset:(UIImageAsset *)a { _asset = a; }
/* the variant of this image's asset for the traits, keeping this image's rendering mode and tint */
- (UIImage *)_isim_resolvedForTraits:(UITraitCollection *)t {
    if (!_asset) return self;
    UIImage *v = [_asset imageWithTraitCollection:t];
    if (!v || v == self || v->_data == _data) return self;
    if (v->_mode == _mode && v->_tint == _tint && !_resizable) return v;
    UIImage *c = [v _copy]; c->_mode = _mode; c->_tint = _tint; c->_caps = _caps; c->_rmode = _rmode; c->_resizable = _resizable;
    return c;
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
    _orient = o;
    if (o == UIImageOrientationLeft || o == UIImageOrientationRight || o == UIImageOrientationLeftMirrored || o == UIImageOrientationRightMirrored)
        _size = CGSizeMake(_size.height, _size.width);
    return self;
}
- (CGImageRef)CGImage {
    if (_symbol || !_data.handle) return NULL;
    CGRect r = _crop;
    if (CGRectIsNull(r)) { double w, h; isim_image_pixel_size(_data.handle, &w, &h); r = CGRectMake(0, 0, w, h); }
    CGImageRef cg = isim_cg_image_create(_data.handle, r, (__bridge void *)(_data.owner ?: _data));
    return (CGImageRef)CFAutorelease(cg);
}
- (UIImageOrientation)imageOrientation { return _orient; }
static BOOL swaps(UIImageOrientation o) { return o == UIImageOrientationLeft || o == UIImageOrientationRight || o == UIImageOrientationLeftMirrored || o == UIImageOrientationRightMirrored; }
- (UIImage *)imageWithHorizontallyFlippedOrientation {
    static const UIImageOrientation flip[] = { UIImageOrientationUpMirrored, UIImageOrientationDownMirrored, UIImageOrientationLeftMirrored, UIImageOrientationRightMirrored,
                                              UIImageOrientationUp, UIImageOrientationDown, UIImageOrientationLeft, UIImageOrientationRight };
    UIImage *i = [self _copy]; i->_orient = flip[_orient & 7]; return i;
}
/* drawn mirrored where the layout is right to left */
- (UIImage *)imageFlippedForRightToLeftLayoutDirection { UIImage *i = [self _copy]; i->_flipsRTL = YES; return i; }
- (BOOL)flipsForRightToLeftLayoutDirection { return _flipsRTL; }
- (UIImage *)resizableImageWithCapInsets:(UIEdgeInsets)c { return [self resizableImageWithCapInsets:c resizingMode:UIImageResizingModeTile]; }
- (UIImage *)resizableImageWithCapInsets:(UIEdgeInsets)c resizingMode:(UIImageResizingMode)m { UIImage *i = [self _copy]; i->_caps = c; i->_rmode = m; i->_resizable = YES; return i; }
- (UIImage *)stretchableImageWithLeftCapWidth:(NSInteger)l topCapHeight:(NSInteger)t {
    UIEdgeInsets c = UIEdgeInsetsMake(t, l, t ? _size.height - t - 1 : 0, l ? _size.width - l - 1 : 0);
    return [self resizableImageWithCapInsets:c resizingMode:UIImageResizingModeStretch];
}
- (UIEdgeInsets)capInsets { return _caps; }
- (UIImageResizingMode)resizingMode { return _rmode; }
+ (UIImage *)animatedImageWithImages:(NSArray<UIImage *> *)images duration:(NSTimeInterval)d {
    if (!images.count) return nil;
    UIImage *i = [images.firstObject _copy];
    i->_frames = [images copy]; i->_duration = d > 0 ? d : images.count / 30.0;
    return i;
}
+ (UIImage *)animatedImageNamed:(NSString *)name duration:(NSTimeInterval)d {
    NSMutableArray *a = [NSMutableArray array];
    for (int k = 0; k < 1024; k++) {
        UIImage *f = [UIImage imageNamed:[NSString stringWithFormat:@"%@%d", name, k]];
        if (!f) { if (k == 0) continue; break; }
        [a addObject:f];
    }
    return [self animatedImageWithImages:a duration:d];
}
- (NSArray<UIImage *> *)images { return _frames; }
- (NSTimeInterval)duration { return _duration; }

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
        UITraitCollection *t = config.traitCollection ?: isim_ui_current_traits();
        NSMutableSet *appearances = [NSMutableSet set];
        for (NSDictionary *v in variants) [appearances addObject:v[@"appearance"] ?: @"any"];
        if (appearances.count > 1) {               /* light/dark/high-contrast variants: an image asset picks per traits */
            UIImageAsset *a = [UIImageAsset _isim_assetNamed:name bundle:bundle variants:variants];
            UIImage *i = [a imageWithTraitCollection:t];
            if (i) return i;
        }
        UIImage *i = [self _isim_catalogImage:name bundle:bundle variants:variants traits:t];
        if (i) return i;
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

/* the asset-catalog variant for the traits, closest to the screen scale */
+ (UIImage *)_isim_catalogImage:(NSString *)name bundle:(NSBundle *)bundle variants:(NSArray *)variants traits:(UITraitCollection *)t {
    CGFloat devScale = isim_ui_device()->scale;
    NSDictionary *best = nil; double bestScore = 1e9;
    for (NSDictionary *v in variants) {
        double s = [v[@"scale"] doubleValue] ?: 1;
        double score = fabs(s - devScale) + appearance_score(v[@"appearance"] ?: @"any", t) * 10;
        if (score < bestScore) { bestScore = score; best = v; }
    }
    if (!best) return nil;
    NSString *path = [bundle.bundlePath stringByAppendingPathComponent:best[@"file"]];
    double w, h; int hd = isim_image_load(path.UTF8String, &w, &h);
    CGFloat s = [best[@"scale"] doubleValue] ?: 1;
    UIImage *i = image_from_handle(hd, w, h, [path.pathExtension isEqualToString:@"svg"] || [path.pathExtension isEqualToString:@"pdf"] ? 1 : s);
    if (!i) return nil;
    i->_name = name;
    if ([best[@"templateRendering"] boolValue]) i->_mode = UIImageRenderingModeAlwaysTemplate;
    return i;
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
- (NSString *)_isim_symbolName { return _symbol ? _name : nil; }
- (UIImage *)imageWithRenderingMode:(UIImageRenderingMode)m { UIImage *i = [self _copy]; i->_mode = m; return i; }
- (UIImage *)imageWithTintColor:(UIColor *)c { return [self imageWithTintColor:c renderingMode:UIImageRenderingModeAlwaysOriginal]; }
- (UIImage *)imageWithTintColor:(UIColor *)c renderingMode:(UIImageRenderingMode)m { UIImage *i = [self _copy]; i->_tint = c; i->_mode = m; return i; }
- (UIImage *)imageByApplyingSymbolConfiguration:(UIImageSymbolConfiguration *)c {
    if (!_symbol) return self;
    UIImage *i = [self _copy]; i->_config = _config ? [_config configurationByApplyingConfiguration:c] : c; [i _isim_updateSymbolSize]; return i;
}
- (UIImage *)imageWithConfiguration:(UIImageConfiguration *)c {
    UIImage *i = [c isKindOfClass:[UIImageSymbolConfiguration class]] ? [self imageByApplyingSymbolConfiguration:(UIImageSymbolConfiguration *)c] : self;
    if (c.traitCollection && i->_asset) i = [i _isim_resolvedForTraits:c.traitCollection];   /* the asset's variant for those traits */
    return i;
}
- (NSString *)description { return [NSString stringWithFormat:@"<UIImage:%p %@%@ {%g, %g}>", self, _symbol ? @"symbol(substitute) " : @"", _name ?: @"", _size.width, _size.height]; }

- (void)_isim_drawInRect:(CGRect)r tint:(UIColor *)tint alpha:(CGFloat)alpha { [self _isim_drawInRect:r tint:tint alpha:alpha nearest:NO]; }
/* multicolor: isim's colours for some common symbols, modelled on iOS's multicolor variants (primary, secondary);
   other symbols draw in monochrome, as iOS draws symbols without a multicolor variant (adapted) */
static NSDictionary<NSString *, NSArray<UIColor *> *> *multicolor_table(void) {
    static NSDictionary *t;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIColor *w = UIColor.whiteColor;
        t = @{ @"heart.fill": @[UIColor.systemRedColor], @"heart": @[UIColor.systemRedColor], @"star.fill": @[UIColor.systemYellowColor],
               @"bolt.fill": @[UIColor.systemYellowColor], @"flame.fill": @[UIColor.systemOrangeColor], @"flame": @[UIColor.systemOrangeColor],
               @"leaf.fill": @[UIColor.systemGreenColor], @"leaf": @[UIColor.systemGreenColor], @"drop.fill": @[UIColor.systemCyanColor],
               @"checkmark.circle.fill": @[w, UIColor.systemGreenColor], @"plus.circle.fill": @[w, UIColor.systemGreenColor],
               @"minus.circle.fill": @[w, UIColor.systemRedColor], @"xmark.circle.fill": @[w, UIColor.systemGrayColor],
               @"exclamationmark.triangle.fill": @[UIColor.blackColor, UIColor.systemYellowColor],
               @"exclamationmark.circle.fill": @[w, UIColor.systemRedColor], @"info.circle.fill": @[w, UIColor.systemBlueColor] };
    });
    return t;
}
/* the colours of a symbol's layers (primary, secondary) in its configuration's rendering mode; nil: monochrome */
- (NSArray<UIColor *> *)_isim_layerColors:(UIColor *)tint {
    int mode = [_config _isim_renderingMode];
    NSArray<UIColor *> *colors = [_config _isim_renderingColors];
    switch (mode) {
    case SYM_MODE_HIERARCHICAL: {                       /* adapted: the secondary layer at half opacity */
        UIColor *base = colors.firstObject ?: tint;
        return @[base, [base colorWithAlphaComponent:CGColorGetAlpha(base.CGColor) * 0.5]];
    }
    case SYM_MODE_PALETTE:
        if (!colors.count) return nil;
        return colors.count > 1 ? @[colors[0], colors[1]] : @[colors[0], colors[0]];
    case SYM_MODE_MULTICOLOR:
        return multicolor_table()[_name ?: @""];
    default: return nil;
    }
}
- (void)_isim_drawInRect:(CGRect)r tint:(UIColor *)tint alpha:(CGFloat)alpha nearest:(BOOL)nearest {
    if (_flipsRTL && isim_ui_drawing_rtl) {
        UIImage *m = [self imageWithHorizontallyFlippedOrientation]; m->_flipsRTL = NO;
        [m _isim_drawInRect:r tint:tint alpha:alpha nearest:nearest];
        return;
    }
    if (_asset) {                                       /* dynamic image: the variant for the traits it is drawn with */
        UIImage *v = [self _isim_resolvedForTraits:isim_ui_current_traits()];
        if (v != self) { [v _isim_drawInRect:r tint:tint alpha:alpha nearest:nearest]; return; }
    }
    if (_frames.count) { [_frames.firstObject _isim_drawInRect:r tint:tint alpha:alpha nearest:nearest]; return; }
    if (_resizable && !_symbol && _data.handle && [self _isim_drawSlices:r alpha:alpha nearest:nearest]) return;
    if (_orient != UIImageOrientationUp) {
        /* the stored pixels go into the rect turned / mirrored */
        BOOL mirrored = _orient >= UIImageOrientationUpMirrored;
        UIImageOrientation base = mirrored ? _orient - UIImageOrientationUpMirrored : _orient;
        isim_gfx_save();
        if (mirrored) { isim_gfx_translate(r.origin.x * 2 + r.size.width, 0); isim_gfx_scale(-1, 1); }
        CGRect d = CGRectMake(0, 0, r.size.width, r.size.height);
        switch (base) {
        case UIImageOrientationDown: isim_gfx_translate(r.origin.x + r.size.width, r.origin.y + r.size.height); isim_gfx_rotate(M_PI); break;
        case UIImageOrientationLeft: isim_gfx_translate(r.origin.x, r.origin.y + r.size.height); isim_gfx_rotate(-M_PI / 2); d.size = CGSizeMake(r.size.height, r.size.width); break;
        case UIImageOrientationRight: isim_gfx_translate(r.origin.x + r.size.width, r.origin.y); isim_gfx_rotate(M_PI / 2); d.size = CGSizeMake(r.size.height, r.size.width); break;
        default: isim_gfx_translate(r.origin.x, r.origin.y); break;
        }
        UIImageOrientation saved = _orient; _orient = UIImageOrientationUp;
        [self _isim_drawInRect:d tint:tint alpha:alpha nearest:nearest];
        _orient = saved;
        isim_gfx_restore();
        return;
    }
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
    if (_symbol) {
        NSArray<UIColor *> *layers = [self _isim_layerColors:c ?: tint ?: UIColor.labelColor];
        if (layers) {                                   /* hierarchical, palette, multicolor: a colour per layer */
            double two[8];
            isim_ui_rgba(layers[0], two); isim_ui_rgba(layers.count > 1 ? layers[1] : layers[0], two + 4);
            isim_image_draw_symbol_layered(_data.handle, r.origin.x, r.origin.y, r.size.width, r.size.height, two, alpha, (int)_config._isim_weight);
        } else isim_image_draw_symbol(_data.handle, r.origin.x, r.origin.y, r.size.width, r.size.height, t, alpha, (int)_config._isim_weight);
    }
    else isim_image_draw(_data.handle, r.origin.x, r.origin.y, r.size.width, r.size.height, t, alpha);
}
/* nine slices: corners at their size, edges and center stretched or tiled (in points of the image) */
- (BOOL)_isim_drawSlices:(CGRect)r alpha:(CGFloat)alpha nearest:(BOOL)nearest {
    UIEdgeInsets c = _caps; CGSize s = _size; CGFloat k = _scale ?: 1;
    if (swaps(_orient)) return NO;
    CGRect px = _crop;
    if (CGRectIsNull(px)) { double w, h; isim_image_pixel_size(_data.handle, &w, &h); px = CGRectMake(0, 0, w, h); }
    double sx[4] = { 0, c.left, s.width - c.right, s.width }, sy[4] = { 0, c.top, s.height - c.bottom, s.height };
    double dx[4] = { r.origin.x, r.origin.x + c.left, r.origin.x + r.size.width - c.right, r.origin.x + r.size.width };
    double dy[4] = { r.origin.y, r.origin.y + c.top, r.origin.y + r.size.height - c.bottom, r.origin.y + r.size.height };
    if (sx[2] < sx[1] || sy[2] < sy[1]) return NO;
    BOOL group = alpha < 0.999;
    if (group) isim_gfx_push_group();
    for (int j = 0; j < 3; j++) for (int i = 0; i < 3; i++) {
        double sw = sx[i + 1] - sx[i], sh = sy[j + 1] - sy[j], w = dx[i + 1] - dx[i], h = dy[j + 1] - dy[j];
        if (sw <= 0 || sh <= 0 || w <= 0 || h <= 0) continue;
        double psx = px.origin.x + sx[i] * k, psy = px.origin.y + sy[j] * k;
        BOOL stretch = _rmode == UIImageResizingModeStretch || (i != 1 && j != 1);
        isim_cg_draw_image_tiled(_data.handle, psx, psy, sw * k, sh * k, dx[i], dy[j], w, h, stretch || i != 1 ? w : sw, stretch || j != 1 ? h : sh);
    }
    if (group) isim_gfx_pop_group(alpha);
    return YES;
}
- (void)drawInRect:(CGRect)r { [self _isim_drawInRect:r tint:nil alpha:1]; }
- (void)drawInRect:(CGRect)r blendMode:(CGBlendMode)m alpha:(CGFloat)a {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx); CGContextSetBlendMode(ctx, m);
    [self _isim_drawInRect:r tint:nil alpha:a];
    CGContextRestoreGState(ctx);
}
- (void)drawAtPoint:(CGPoint)p { [self drawInRect:(CGRect){ p, _size }]; }
@end

/* ---------------- UIImageView ---------------- */
@implementation UIImageView { CADisplayLink *_animLink; double _animStart; NSInteger _isimPrefRange; }
@dynamic adjustsImageSizeForAccessibilityContentSizeCategory;      /* UIAccessibilityExtras.m */
/* stored + 2 so that 0 (a new view) reads as unspecified */
- (UIImageDynamicRange)preferredImageDynamicRange { return _isimPrefRange ? (UIImageDynamicRange)(_isimPrefRange - 2) : UIImageDynamicRangeUnspecified; }
- (void)setPreferredImageDynamicRange:(UIImageDynamicRange)r { _isimPrefRange = r + 2; }
- (UIImageDynamicRange)imageDynamicRange { return UIImageDynamicRangeStandard; }      /* isim renders SDR */
- (instancetype)initWithImage:(UIImage *)image {
    if ((self = [self initWithFrame:CGRectMake(0, 0, image.size.width, image.size.height)])) { _image = image; if (image.images.count) [self startAnimating]; }
    return self;
}
- (instancetype)initWithImage:(UIImage *)image highlightedImage:(UIImage *)hi {
    if ((self = [self initWithImage:image])) _highlightedImage = hi;
    return self;
}
- (void)setImage:(UIImage *)image {
    BOOL wasAnimated = _image.images.count > 0;
    _image = image; [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display();
    if (image.images.count) [self startAnimating];            /* an animated image plays by itself, as on iOS */
    else if (wasAnimated && !_animationImages.count) [self stopAnimating];
}
- (void)setHighlightedImage:(UIImage *)i { _highlightedImage = i; isim_ui_set_needs_display(); }
- (void)setHighlighted:(BOOL)h { _highlighted = h; isim_ui_set_needs_display(); }
- (NSArray<UIImage *> *)_isim_frames {
    if (_highlighted && _highlightedAnimationImages.count) return _highlightedAnimationImages;
    return _animationImages.count ? _animationImages : _image.images;
}
- (NSTimeInterval)_isim_frameDuration {
    NSArray *f = [self _isim_frames];
    if (_animationImages.count) return _animationDuration > 0 ? _animationDuration : f.count / 30.0;
    return _image.duration > 0 ? _image.duration : f.count / 30.0;
}
- (void)startAnimating {
    if (![self _isim_frames].count) return;
    _animStart = isim_time();
    if (!_animating) {
        _animating = YES;
        _animLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_isim_animTick:)];
        [_animLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    isim_ui_set_needs_display();
}
- (void)stopAnimating { if (!_animating) return; _animating = NO; [_animLink invalidate]; _animLink = nil; isim_ui_set_needs_display(); }
- (void)_isim_animTick:(CADisplayLink *)l {
    NSInteger reps = _animationImages.count ? _animationRepeatCount : 0;
    if (reps > 0 && isim_time() - _animStart >= [self _isim_frameDuration] * reps) { [self stopAnimating]; return; }
    if (self.window) isim_ui_set_needs_display();
}
- (UIImage *)_isim_currentFrame {
    NSArray<UIImage *> *f = [self _isim_frames];
    if (!_animating || !f.count) return nil;
    double d = [self _isim_frameDuration], t = isim_time() - _animStart;
    NSUInteger i = d > 0 ? (NSUInteger)floor(fmod(t, d) / d * f.count) : 0;
    return f[MIN(i, f.count - 1)];
}
- (void)setPreferredSymbolConfiguration:(UIImageSymbolConfiguration *)c { _preferredSymbolConfiguration = c; [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
- (UIImage *)_shown {
    UIImage *frame = [self _isim_currentFrame];
    if (frame) return frame;
    UIImage *i = _highlighted && _highlightedImage ? _highlightedImage : _image;
    return _preferredSymbolConfiguration && i.symbolImage ? [i imageByApplyingSymbolConfiguration:_preferredSymbolConfiguration] : i;
}
/* adjustsImageSizeForAccessibilityContentSizeCategory: larger at the accessibility text sizes (UIAccessibilityExtras.m) */
- (CGSize)intrinsicContentSize {
    extern CGFloat isim_ui_accessibility_image_scale(UIView *);
    UIImage *i = [self _shown];
    if (!i) return CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric);
    CGFloat k = isim_ui_accessibility_image_scale(self);
    return CGSizeMake(i.size.width * k, i.size.height * k);
}
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
@implementation UIColor (UIColorNamedColors)
+ (UIColor *)colorNamed:(NSString *)name { return [self colorNamed:name inBundle:nil compatibleWithTraitCollection:nil]; }
+ (UIColor *)colorNamed:(NSString *)name inBundle:(NSBundle *)bundle compatibleWithTraitCollection:(UITraitCollection *)traits {
    NSDictionary *variants = asset_index(bundle ?: NSBundle.mainBundle)[@"colors"][name];
    if (!variants.count) return nil;
    /* light/dark and high-contrast variants (Any, Light, Dark appearances x High Contrast), resolved per traits */
    NSMutableDictionary<NSString *, UIColor *> *colors = [NSMutableDictionary dictionary];
    for (NSString *k in variants) {
        NSArray *v = variants[k];
        if ([v isKindOfClass:[NSArray class]] && v.count >= 4) colors[k] = [UIColor colorWithRed:[v[0] doubleValue] green:[v[1] doubleValue] blue:[v[2] doubleValue] alpha:[v[3] doubleValue]];
    }
    UIColor *fallback = colors[@"any"] ?: colors[@"light"] ?: colors.allValues.firstObject;
    UIColor *c = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        NSString *best = nil; int bestScore = 1000;
        for (NSString *k in colors) { int s = appearance_score(k, t); if (s < bestScore) { bestScore = s; best = k; } }
        return best ? colors[best] : fallback;
    }];
    if (traits) return [c resolvedColorWithTraitCollection:traits];
    return c;
}
@end



/* ---------------- UIImageAsset ---------------- */
@implementation UIImageAsset { NSMutableArray<NSArray *> *_registered; NSString *_name; NSBundle *_bundle; NSArray *_variants; NSMutableDictionary *_cache; }
- (instancetype)init { if ((self = [super init])) { _registered = [NSMutableArray array]; _cache = [NSMutableDictionary dictionary]; } return self; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
+ (instancetype)_isim_assetNamed:(NSString *)name bundle:(NSBundle *)bundle variants:(NSArray *)variants {
    static NSMutableDictionary *assets;
    if (!assets) assets = [NSMutableDictionary dictionary];
    NSString *key = [NSString stringWithFormat:@"%@|%@", bundle.bundlePath, name];
    UIImageAsset *a = assets[key];
    if (!a) { a = [self new]; a->_name = name; a->_bundle = bundle; a->_variants = variants; assets[key] = a; }
    return a;
}
/* the image for the traits: an asset-catalog variant (cached per appearance), or the registered image whose traits the
   collection contains (the most specific one) */
- (UIImage *)imageWithTraitCollection:(UITraitCollection *)t {
    if (!t) t = isim_ui_current_traits();
    if (_variants) {
        NSString *bestKey = @"any"; int bestScore = 100000;
        for (NSDictionary *v in _variants) { NSString *k = v[@"appearance"] ?: @"any"; int s = appearance_score(k, t); if (s < bestScore) { bestScore = s; bestKey = k; } }
        UIImage *i = _cache[bestKey];
        if (!i) {
            NSMutableArray *same = [NSMutableArray array];
            for (NSDictionary *v in _variants) if ([(v[@"appearance"] ?: @"any") isEqualToString:bestKey]) [same addObject:v];
            i = [UIImage _isim_catalogImage:_name bundle:_bundle variants:same traits:t];
            if (i) { [i _isim_setAsset:self]; _cache[bestKey] = i; }
        }
        if (i) return i;
    }
    UIImage *best = nil; NSUInteger bestN = 0;
    for (NSArray *e in _registered) {
        UITraitCollection *et = e[0];
        if (![t containsTraitsInCollection:et]) continue;
        NSUInteger n = [et _isim_traitCount];
        if (!best || n > bestN) { best = e[1]; bestN = n; }
    }
    return best ?: _registered.firstObject[1];
}
- (UIImage *)imageWithConfiguration:(UIImageConfiguration *)c { return [self imageWithTraitCollection:c.traitCollection]; }
- (void)registerImage:(UIImage *)image withTraitCollection:(UITraitCollection *)t {
    if (!image) return;
    t = t ?: [UITraitCollection new];
    [self unregisterImageWithTraitCollection:t];
    UIImage *i = [image _copy]; [i _isim_setAsset:self];
    [_registered addObject:@[t, i]];
}
- (void)registerImage:(UIImage *)image withConfiguration:(UIImageConfiguration *)c { [self registerImage:image withTraitCollection:c.traitCollection]; }
- (void)unregisterImageWithTraitCollection:(UITraitCollection *)t {
    for (NSArray *e in [_registered copy]) if ([e[0] isEqual:t]) [_registered removeObjectIdenticalTo:e];
}
- (void)unregisterImageWithConfiguration:(UIImageConfiguration *)c { [self unregisterImageWithTraitCollection:c.traitCollection ?: [UITraitCollection new]]; }
@end

/* the app's accent color (asset catalog: ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME, else "AccentColor"): the
   default tint of views and UIColor.tintColor */
UIColor *isim_ui_accent_color(void) {
    static UIColor *accent; static BOOL looked;
    if (!looked) {
        looked = YES;
        NSString *name = NSBundle.mainBundle.infoDictionary[@"ISIMGlobalAccentColorName"];
        if ([name isKindOfClass:[NSString class]]) accent = [UIColor colorNamed:name];
        if (!accent) accent = [UIColor colorNamed:@"AccentColor"];
    }
    return accent;
}
