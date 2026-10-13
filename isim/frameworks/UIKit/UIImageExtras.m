/* UIImage extras (UIImage.h): alignment insets and baselines, preparing for display and thumbnails (isim decodes
 * when it loads, so preparing is drawing at the target size), animated resizable images, the standard images, HDR
 * members (standard dynamic range only), renderer formats, pattern drawing, configuration locales, NSDataAsset
 * (asset catalog data sets) and UIImageReader. */
#import "UIKitPrivate.h"
#import <objc/runtime.h>

@interface UIImage (IsimCopy)
- (UIImage *)_copy;
@end

static char kInsets, kBaseline;
/* derived images keep the alignment insets and baseline */
void isim_ui_image_copy_extras(UIImage *from, UIImage *to) {
    id i = objc_getAssociatedObject(from, &kInsets), b = objc_getAssociatedObject(from, &kBaseline);
    if (i) objc_setAssociatedObject(to, &kInsets, i, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (b) objc_setAssociatedObject(to, &kBaseline, b, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UIImage (UIImageExtras)
- (UIImage *)imageByPreparingForDisplay { return self; }
- (void)prepareForDisplayWithCompletionHandler:(void (^)(UIImage *))done {
    UIImage *i = [self imageByPreparingForDisplay];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ done(i); });
}
/* scaled down (aspect fit) to the size, never up */
- (UIImage *)imageByPreparingThumbnailOfSize:(CGSize)size {
    CGSize s = self.size;
    if (s.width <= 0 || s.height <= 0 || size.width <= 0 || size.height <= 0) return nil;
    CGFloat k = MIN(1, MIN(size.width / s.width, size.height / s.height));
    CGSize t = CGSizeMake(MAX(1, round(s.width * k)), MAX(1, round(s.height * k)));
    UIGraphicsImageRendererFormat *f = [UIGraphicsImageRendererFormat preferredFormat]; f.scale = self.scale;
    return [[[UIGraphicsImageRenderer alloc] initWithSize:t format:f] imageWithActions:^(UIGraphicsImageRendererContext *c) {
        [self drawInRect:CGRectMake(0, 0, t.width, t.height)];
    }];
}
- (void)prepareThumbnailOfSize:(CGSize)size completionHandler:(void (^)(UIImage *))done {
    dispatch_async(dispatch_get_main_queue(), ^{ UIImage *t = [self imageByPreparingThumbnailOfSize:size]; dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ done(t); }); });
}
+ (UIImage *)animatedResizableImageNamed:(NSString *)name capInsets:(UIEdgeInsets)caps duration:(NSTimeInterval)d {
    return [self animatedResizableImageNamed:name capInsets:caps resizingMode:UIImageResizingModeTile duration:d];
}
+ (UIImage *)animatedResizableImageNamed:(NSString *)name capInsets:(UIEdgeInsets)caps resizingMode:(UIImageResizingMode)m duration:(NSTimeInterval)d {
    UIImage *a = [UIImage animatedImageNamed:name duration:d];
    if (!a.images.count) return nil;
    NSMutableArray *frames = [NSMutableArray array];
    for (UIImage *f in a.images) [frames addObject:[f resizableImageWithCapInsets:caps resizingMode:m]];
    return [UIImage animatedImageWithImages:frames duration:d];
}
- (UIEdgeInsets)alignmentRectInsets { NSValue *v = objc_getAssociatedObject(self, &kInsets); return v ? v.UIEdgeInsetsValue : UIEdgeInsetsZero; }
- (UIImage *)imageWithAlignmentRectInsets:(UIEdgeInsets)insets {
    UIImage *i = [self _copy];
    objc_setAssociatedObject(i, &kInsets, [NSValue valueWithUIEdgeInsets:insets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return i;
}
/* symbols have their font's baseline (the descent at their point size); other images none until given one */
- (NSNumber *)_isimBaseline {
    NSNumber *b = objc_getAssociatedObject(self, &kBaseline);
    if (b) return [b isKindOfClass:[NSNull class]] ? nil : b;
    if (self.isSymbolImage) {
        CGFloat pt = self.size.height > 0 ? self.size.height : 17;
        return @(round(-[UIFont systemFontOfSize:pt].descender * 0.5 * 2) / 2);
    }
    return nil;
}
- (BOOL)hasBaseline { return [self _isimBaseline] != nil; }
- (CGFloat)baselineOffsetFromBottom { return [self _isimBaseline].doubleValue; }
- (UIImage *)imageWithBaselineOffsetFromBottom:(CGFloat)offset {
    UIImage *i = [self _copy]; objc_setAssociatedObject(i, &kBaseline, @(offset), OBJC_ASSOCIATION_RETAIN_NONATOMIC); return i;
}
- (UIImage *)imageWithoutBaseline {
    UIImage *i = [self _copy]; objc_setAssociatedObject(i, &kBaseline, [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC); return i;
}
+ (UIImage *)addImage { return [UIImage systemImageNamed:@"plus"]; }
+ (UIImage *)removeImage { return [UIImage systemImageNamed:@"minus"]; }
+ (UIImage *)actionsImage { return [UIImage systemImageNamed:@"ellipsis.circle"]; }
+ (UIImage *)checkmarkImage { return [UIImage systemImageNamed:@"checkmark"]; }
+ (UIImage *)strokedCheckmarkImage { return [UIImage systemImageNamed:@"checkmark"]; }
- (BOOL)isHighDynamicRange { return NO; }
- (UIImage *)imageRestrictedToStandardDynamicRange { return self; }
- (UIGraphicsImageRendererFormat *)imageRendererFormat {
    UIGraphicsImageRendererFormat *f = [UIGraphicsImageRendererFormat preferredFormat];
    f.scale = self.scale; f.preferredRange = UIGraphicsImageRendererFormatRangeStandard;
    return f;
}
/* tiles from the context's origin (so neighbouring rects line up), clipped to the rect */
- (void)drawAsPatternInRect:(CGRect)rect {
    CGSize s = self.size;
    if (s.width <= 0 || s.height <= 0 || CGRectIsEmpty(rect)) return;
    CGContextRef c = UIGraphicsGetCurrentContext();
    if (c) { CGContextSaveGState(c); CGContextClipToRect(c, rect); } else { isim_gfx_save(); isim_gfx_clip_rounded(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height, 0); }
    for (CGFloat y = floor(CGRectGetMinY(rect) / s.height) * s.height; y < CGRectGetMaxY(rect); y += s.height)
        for (CGFloat x = floor(CGRectGetMinX(rect) / s.width) * s.width; x < CGRectGetMaxX(rect); x += s.width)
            [self drawInRect:CGRectMake(x, y, s.width, s.height)];
    if (c) CGContextRestoreGState(c); else isim_gfx_restore();
}
@end

static char kLocale;
@implementation UIImageConfiguration (UIImageConfigurationExtras)
- (NSLocale *)locale { return objc_getAssociatedObject(self, &kLocale); }
+ (instancetype)configurationWithLocale:(NSLocale *)locale { return [[self new] configurationWithLocale:locale]; }
- (instancetype)configurationWithLocale:(NSLocale *)locale {
    UIImageConfiguration *c = [self configurationWithTraitCollection:self.traitCollection];
    objc_setAssociatedObject(c, &kLocale, locale, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return c;
}
@end

/* ================= data assets ================= */
@implementation NSDataAsset
- (instancetype)initWithName:(NSDataAssetName)name { return [self initWithName:name bundle:[NSBundle mainBundle]]; }
- (instancetype)initWithName:(NSDataAssetName)name bundle:(NSBundle *)bundle {
    bundle = bundle ?: [NSBundle mainBundle];
    NSDictionary *index = [NSDictionary dictionaryWithContentsOfFile:[bundle.bundlePath stringByAppendingPathComponent:@"isim-assets.plist"]];
    NSDictionary *e = index[@"data"][name];
    NSData *d = e ? [NSData dataWithContentsOfFile:[bundle.bundlePath stringByAppendingPathComponent:e[@"file"]]] : nil;
    if (!d || !(self = [super init])) return nil;
    _name = [name copy]; _data = d; _typeIdentifier = [e[@"uti"] copy] ?: @"public.data";
    return self;
}
- (id)copyWithZone:(NSZone *)z { return self; }
@end

/* ================= image reader ================= */
@implementation UIImageReaderConfiguration
- (instancetype)init { if ((self = [super init])) { _preparesImagesForDisplay = YES; } return self; }
- (id)copyWithZone:(NSZone *)z {
    UIImageReaderConfiguration *c = [UIImageReaderConfiguration new];
    c.prefersHighDynamicRange = _prefersHighDynamicRange; c.preparesImagesForDisplay = _preparesImagesForDisplay;
    c.preferredThumbnailSize = _preferredThumbnailSize; c.pixelsPerInch = _pixelsPerInch;
    return c;
}
@end
@implementation UIImageReader
+ (UIImageReader *)defaultReader { static UIImageReader *r; if (!r) r = [self readerWithConfiguration:[UIImageReaderConfiguration new]]; return r; }
+ (instancetype)readerWithConfiguration:(UIImageReaderConfiguration *)c { UIImageReader *r = [self new]; r->_configuration = [c copy]; return r; }
/* pixelsPerInch sets the scale (72 per point); a preferred thumbnail size scales the image down to fit */
- (UIImage *)imageWithData:(NSData *)data {
    CGFloat ppi = _configuration.pixelsPerInch;
    UIImage *i = [UIImage imageWithData:data scale:ppi > 0 ? ppi / 72.0 : 1];
    CGSize t = _configuration.preferredThumbnailSize;
    if (i && t.width > 0 && t.height > 0) i = [i imageByPreparingThumbnailOfSize:t];
    return i;
}
- (UIImage *)imageWithContentsOfFileURL:(NSURL *)url { NSData *d = [NSData dataWithContentsOfURL:url]; return d ? [self imageWithData:d] : nil; }
- (void)imageWithData:(NSData *)data completionHandler:(void (^)(UIImage *))done {
    dispatch_async(dispatch_get_main_queue(), ^{ UIImage *i = [self imageWithData:data]; dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ done(i); }); });
}
- (void)imageWithContentsOfFileURL:(NSURL *)url completion:(void (^)(UIImage *))done {
    dispatch_async(dispatch_get_main_queue(), ^{ UIImage *i = [self imageWithContentsOfFileURL:url]; dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ done(i); }); });
}
@end
