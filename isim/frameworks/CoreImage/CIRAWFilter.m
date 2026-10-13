// isim Core Image: CIRAWFilter (adapted). RAW files are decoded by the host's LibRaw tools (isim_raw_decode: dcraw_emu,
// linear 16-bit, sRGB primaries, the camera's as-shot white balance); everything after that is isim's own processing
// of the linear pixels, in this order: white balance relative to the as-shot neutral (CITemperatureAndTint's model),
// exposure, the linear space filter, noise and moire reduction, the boost tone curve (boost, shadow boost, contrast,
// shadow bias, gamut mapping, EDR headroom), local tone mapping, sharpness and detail, orientation and scale.
// The as-shot temperature and tint are estimated from LibRaw's as-shot and D65 multipliers. Lens correction is not
// supported and the semantic mattes are nil (stub).
#import "CIInternal.h"
#import <CoreImage/CIRAWFilter.h>
#import <CoreImage/CIFilterBuiltins.h>
#include <isim_host.h>

CIRAWDecoderVersion const CIRAWDecoderVersionNone = @"none", CIRAWDecoderVersion8 = @"8", CIRAWDecoderVersion8DNG = @"8.dng",
    CIRAWDecoderVersion7 = @"7", CIRAWDecoderVersion7DNG = @"7.dng", CIRAWDecoderVersion6 = @"6", CIRAWDecoderVersion6DNG = @"6.dng";
NSString *const kCIInputDecoderVersionKey = @"inputDecoderVersion", *const kCISupportedDecoderVersionsKey = @"supportedDecoderVersions",
    *const kCIInputBoostKey = @"inputBoost", *const kCIInputNeutralChromaticityXKey = @"inputNeutralChromaticityX",
    *const kCIInputNeutralChromaticityYKey = @"inputNeutralChromaticityY", *const kCIInputNeutralTemperatureKey = @"inputNeutralTemperature",
    *const kCIInputNeutralTintKey = @"inputNeutralTint", *const kCIInputNeutralLocationKey = @"inputNeutralLocation",
    *const kCIInputScaleFactorKey = @"inputScaleFactor", *const kCIInputAllowDraftModeKey = @"inputAllowDraftMode",
    *const kCIInputIgnoreImageOrientationKey = @"inputIgnoreImageOrientation", *const kCIInputImageOrientationKey = @"inputImageOrientation",
    *const kCIInputEnableSharpeningKey = @"inputEnableSharpening", *const kCIInputEnableChromaticNoiseTrackingKey = @"inputEnableChromaticNoiseTracking",
    *const kCIInputNoiseReductionAmountKey = @"inputNoiseReductionAmount", *const kCIInputMoireAmountKey = @"inputMoireAmount",
    *const kCIInputEnableVendorLensCorrectionKey = @"inputEnableVendorLensCorrection",
    *const kCIInputLuminanceNoiseReductionAmountKey = @"inputLuminanceNoiseReductionAmount",
    *const kCIInputColorNoiseReductionAmountKey = @"inputColorNoiseReductionAmount",
    *const kCIInputNoiseReductionSharpnessAmountKey = @"inputNoiseReductionSharpnessAmount",
    *const kCIInputNoiseReductionContrastAmountKey = @"inputNoiseReductionContrastAmount",
    *const kCIInputNoiseReductionDetailAmountKey = @"inputNoiseReductionDetailAmount", *const kCIInputEnableEDRModeKey = @"inputEnableEDRMode",
    *const kCIInputLocalToneMapAmountKey = @"inputLocalToneMapAmount", *const kCIInputLinearSpaceFilter = @"inputLinearSpaceFilter",
    *const kCIOutputNativeSizeKey = @"outputNativeSize", *const kCIActiveKeys = @"activeKeys",
    *const kCIInputBaselineExposureKey = @"inputBaselineExposure", *const kCIInputBoostShadowAmountKey = @"inputBoostShadowAmount";

/* ---- white points ---- */
static void norm3(float v[3]) { float s = v[0] + v[1] + v[2]; if (s > 0) for (int k = 0; k < 3; k++) v[k] /= s; }
static double wb_err(double T, double tint, const float want[3]) {
    float w[3]; ci_white_rgb(T, tint, w); norm3(w);
    double e = 0; for (int k = 0; k < 3; k++) e += (w[k] - want[k]) * (w[k] - want[k]);
    return e;
}
/* the temperature and tint whose white is closest (in chromaticity) to rgb, a linear sRGB illuminant color */
static void solve_wb(const float rgb[3], double *T, double *tint) {
    float want[3] = { fmaxf(rgb[0], 1e-6f), fmaxf(rgb[1], 1e-6f), fmaxf(rgb[2], 1e-6f) };
    norm3(want);
    double bl = log(6500), bt = 0, be = INFINITY;
    for (int i = 0; i <= 60; i++) for (int j = -15; j <= 15; j++) {
        double l = log(2000) + (log(25000) - log(2000)) * i / 60, t = j * 10, e = wb_err(exp(l), t, want);
        if (e < be) { be = e; bl = l; bt = t; }
    }
    double sl = (log(25000) - log(2000)) / 60, st = 10;
    for (int it = 0; it < 6; it++) {
        double l0 = bl, t0 = bt;
        for (int i = -4; i <= 4; i++) for (int j = -4; j <= 4; j++) {
            double l = l0 + sl * i / 4, t = fmax(-150, fmin(150, t0 + st * j / 4)), e = wb_err(exp(l), t, want);
            if (e < be) { be = e; bl = l; bt = t; }
        }
        sl /= 3; st /= 3;
    }
    *T = exp(bl); *tint = bt;
}
static void xy_of(double T, double tint, double *x, double *y) {
    float w[3]; ci_white_rgb(T, tint, w);
    double X = 0.4124564 * w[0] + 0.3575761 * w[1] + 0.1804375 * w[2], Y = 0.2126729 * w[0] + 0.7151522 * w[1] + 0.0721750 * w[2],
           Z = 0.0193339 * w[0] + 0.1191920 * w[1] + 0.9503041 * w[2], s = X + Y + Z;
    *x = s > 0 ? X / s : 0.3127; *y = s > 0 ? Y / s : 0.3290;
}
static CGImagePropertyOrientation orientation_of_flip(int flip) {
    return flip == 3 ? kCGImagePropertyOrientationDown : flip == 5 ? kCGImagePropertyOrientationLeft
         : flip == 6 ? kCGImagePropertyOrientationRight : kCGImagePropertyOrientationUp;
}
static NSString *line_value(NSString *text, NSString *key) {
    for (NSString *l in [text componentsSeparatedByString:@"\n"]) {
        NSString *t = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([t hasPrefix:key]) return [[t substringFromIndex:key.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    return nil;
}
static NSArray<NSNumber *> *numbers_in(NSString *s) {
    NSMutableArray *a = [NSMutableArray array];
    NSScanner *sc = [NSScanner scannerWithString:s ?: @""];
    double d;
    while (!sc.atEnd) { if ([sc scanDouble:&d]) [a addObject:@(d)]; else sc.scanLocation = sc.scanLocation + 1; }
    return a;
}

@interface CIRAWFilter ()
@property (copy) NSString *isimPath;
@property BOOL isimTempFile;
@property double isimShotT, isimShotTint;
@property int isimFlip;
@property CGSize isimRawSize;
@property (copy) NSString *isimInfo;
@property (strong) NSMutableDictionary *isimDecoded;
@property BOOL isimSharpeningOff;
@end

@implementation CIRAWFilter
@synthesize orientation = _orientation, draftModeEnabled = _draftModeEnabled, decoderVersion = _decoderVersion,
    scaleFactor = _scaleFactor, exposure = _exposure, baselineExposure = _baselineExposure, shadowBias = _shadowBias,
    boostAmount = _boostAmount, boostShadowAmount = _boostShadowAmount, highlightRecoveryEnabled = _highlightRecoveryEnabled,
    gamutMappingEnabled = _gamutMappingEnabled, lensCorrectionEnabled = _lensCorrectionEnabled,
    luminanceNoiseReductionAmount = _luminanceNoiseReductionAmount, colorNoiseReductionAmount = _colorNoiseReductionAmount,
    sharpnessAmount = _sharpnessAmount, contrastAmount = _contrastAmount, detailAmount = _detailAmount,
    moireReductionAmount = _moireReductionAmount, localToneMapAmount = _localToneMapAmount,
    extendedDynamicRangeAmount = _extendedDynamicRangeAmount, neutralTemperature = _neutralTemperature, neutralTint = _neutralTint,
    linearSpaceFilter = _linearSpaceFilter;

+ (NSArray<NSString *> *)supportedCameraModels {
    static NSArray *models;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        char *l = isim_raw_camera_list();
        NSMutableArray *a = [NSMutableArray array];
        if (l) {
            for (NSString *m in [@(l) componentsSeparatedByString:@"\n"]) if (m.length) [a addObject:m];
            isim_media_free(l);
        }
        models = a;
    });
    return models;
}
+ (instancetype)filterWithImageURL:(NSURL *)url {
    if (!url.isFileURL) return nil;
    return [[self alloc] initWithPath:url.path temporary:NO];
}
+ (instancetype)filterWithImageData:(NSData *)data identifierHint:(NSString *)hint {
    if (!data.length) return nil;
    NSString *ext = @"raw";
    if (hint.length) {
        NSString *h = hint.lowercaseString;
        NSDictionary *exts = @{ @"com.adobe.raw-image": @"dng", @"public.camera-raw-image": @"raw", @"com.canon.cr2-raw-image": @"cr2",
                                @"com.canon.cr3-raw-image": @"cr3", @"com.nikon.raw-image": @"nef", @"com.sony.arw-raw-image": @"arw",
                                @"com.fuji.raw-image": @"raf", @"com.olympus.raw-image": @"orf", @"com.panasonic.rw2-raw-image": @"rw2" };
        ext = exts[h] ?: ([h rangeOfString:@"."].location == NSNotFound ? h : ext);
    }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"isim-raw-%@.%@", NSUUID.UUID.UUIDString, ext]];
    if (![data writeToFile:path atomically:NO]) return nil;
    CIRAWFilter *f = [[self alloc] initWithPath:path temporary:YES];
    if (!f) [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    return f;
}
- (instancetype)initWithPath:(NSString *)path temporary:(BOOL)temp {
    if (!isim_raw_available()) {
        static BOOL told;
        if (!told) { told = YES; NSLog(@"isim: CIRAWFilter needs LibRaw's tools on the host (dcraw_emu and raw-identify, package libraw-bin)"); }
        return nil;
    }
    char *info = isim_raw_identify(path.fileSystemRepresentation);
    if (!info) return nil;
    if (!(self = [super init])) { isim_media_free(info); return nil; }
    self.name = @"CIRAWFilter";
    _isimPath = [path copy]; _isimTempFile = temp;
    _isimInfo = @(info);
    isim_media_free(info);
    _isimDecoded = [NSMutableDictionary dictionary];
    NSArray *size = numbers_in(line_value(_isimInfo, @"Output size:") ?: line_value(_isimInfo, @"Image size:"));
    _isimRawSize = size.count >= 2 ? CGSizeMake([size[0] doubleValue], [size[1] doubleValue]) : CGSizeZero;
    _isimFlip = [line_value(_isimInfo, @"Image flip:") intValue];
    /* the as-shot illuminant relative to D65, from LibRaw's multipliers (camera space taken as sRGB: adapted) */
    NSArray *shot = numbers_in(line_value(_isimInfo, @"As shot")), *d65 = numbers_in(line_value(_isimInfo, @"Derived D65 multipliers:"));
    _isimShotT = 6500; _isimShotTint = 0;
    if (shot.count >= 3 && d65.count >= 3 && [shot[0] doubleValue] > 0 && [shot[1] doubleValue] > 0 && [shot[2] doubleValue] > 0) {
        float base[3]; ci_white_rgb(6500, 0, base);
        float k[3];
        for (int c = 0; c < 3; c++) k[c] = (float)([d65[c] doubleValue] / [d65[1] doubleValue] / ([shot[c] doubleValue] / [shot[1] doubleValue])) * base[c];
        double T, t; solve_wb(k, &T, &t);
        _isimShotT = T; _isimShotTint = t;
    }
    [self setDefaults];
    return self;
}
- (void)dealloc { if (_isimTempFile && _isimPath) [[NSFileManager defaultManager] removeItemAtPath:_isimPath error:NULL]; }
- (void)setDefaults {
    _orientation = orientation_of_flip(_isimFlip);
    _draftModeEnabled = NO; _decoderVersion = CIRAWDecoderVersion8; _scaleFactor = 1;
    _exposure = 0; _baselineExposure = 0; _shadowBias = 0; _boostAmount = 1; _boostShadowAmount = 1;
    _highlightRecoveryEnabled = YES; _gamutMappingEnabled = YES; _lensCorrectionEnabled = NO;
    _luminanceNoiseReductionAmount = 0; _colorNoiseReductionAmount = 0; _sharpnessAmount = 0; _contrastAmount = 0; _detailAmount = 0;
    _moireReductionAmount = 0; _localToneMapAmount = 0; _extendedDynamicRangeAmount = 0;
    _neutralTemperature = (float)_isimShotT; _neutralTint = (float)_isimShotTint;
    _linearSpaceFilter = nil;
}
- (id)copyWithZone:(NSZone *)z {
    CIRAWFilter *f = [[[self class] alloc] initWithPath:_isimPath temporary:NO];
    if (!f) return nil;
    for (NSString *k in @[ @"orientation", @"draftModeEnabled", @"decoderVersion", @"scaleFactor", @"exposure", @"baselineExposure", @"shadowBias",
                           @"boostAmount", @"boostShadowAmount", @"highlightRecoveryEnabled", @"gamutMappingEnabled", @"lensCorrectionEnabled",
                           @"luminanceNoiseReductionAmount", @"colorNoiseReductionAmount", @"sharpnessAmount", @"contrastAmount", @"detailAmount",
                           @"moireReductionAmount", @"localToneMapAmount", @"extendedDynamicRangeAmount", @"neutralTemperature", @"neutralTint" ])
        [f setValue:[self valueForKey:k] forKey:k];
    f.linearSpaceFilter = [_linearSpaceFilter copy];
    f.isimSharpeningOff = _isimSharpeningOff;
    if (_isimTempFile) {     /* the copy needs its own file: the original removes its file when it goes away */
        NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"isim-raw-%@.%@", NSUUID.UUID.UUIDString, _isimPath.pathExtension]];
        if ([[NSFileManager defaultManager] copyItemAtPath:_isimPath toPath:p error:NULL]) { f.isimPath = p; f.isimTempFile = YES; }
    }
    return f;
}

/* ---- read-only facts ---- */
- (NSArray<CIRAWDecoderVersion> *)supportedDecoderVersions {
    BOOL dng = [_isimPath.pathExtension.lowercaseString isEqualToString:@"dng"];
    return dng ? @[ CIRAWDecoderVersion8DNG, CIRAWDecoderVersion7DNG, CIRAWDecoderVersion6DNG ] : @[ CIRAWDecoderVersion8, CIRAWDecoderVersion7, CIRAWDecoderVersion6 ];
}
- (CGSize)nativeSize {
    BOOL swap = _orientation >= kCGImagePropertyOrientationLeftMirrored;
    return swap ? CGSizeMake(_isimRawSize.height, _isimRawSize.width) : _isimRawSize;
}
- (BOOL)isHighlightRecoverySupported { return YES; }
- (BOOL)isLensCorrectionSupported { return NO; }
- (BOOL)isLuminanceNoiseReductionSupported { return YES; }
- (BOOL)isColorNoiseReductionSupported { return YES; }
- (BOOL)isSharpnessSupported { return YES; }
- (BOOL)isContrastSupported { return YES; }
- (BOOL)isDetailSupported { return YES; }
- (BOOL)isMoireReductionSupported { return YES; }
- (BOOL)isLocalToneMapSupported { return YES; }
- (CIImage *)portraitEffectsMatte { return nil; }
- (CIImage *)semanticSegmentationSkinMatte { return nil; }
- (CIImage *)semanticSegmentationHairMatte { return nil; }
- (CIImage *)semanticSegmentationGlassesMatte { return nil; }
- (CIImage *)semanticSegmentationSkyMatte { return nil; }
- (CIImage *)semanticSegmentationTeethMatte { return nil; }

/* CGImageSource-style properties: the size, orientation, {TIFF} make / model and {Exif} exposure */
- (NSDictionary *)properties {
    NSMutableDictionary *p = [NSMutableDictionary dictionary], *tiff = [NSMutableDictionary dictionary], *exif = [NSMutableDictionary dictionary];
    p[@"PixelWidth"] = @(_isimRawSize.width); p[@"PixelHeight"] = @(_isimRawSize.height);
    p[@"Orientation"] = @(orientation_of_flip(_isimFlip));
    NSString *cam = line_value(_isimInfo, @"Camera:");
    NSRange id_ = [cam rangeOfString:@" ID:"];
    if (id_.location != NSNotFound) cam = [cam substringToIndex:id_.location];
    if (cam.length) {
        NSRange sp = [cam rangeOfString:@" "];
        tiff[@"Make"] = sp.location == NSNotFound ? cam : [cam substringToIndex:sp.location];
        tiff[@"Model"] = sp.location == NSNotFound ? cam : [cam substringFromIndex:sp.location + 1];
    }
    tiff[@"Orientation"] = p[@"Orientation"];
    NSString *ts = line_value(_isimInfo, @"Timestamp:");
    if (ts.length && ![ts hasSuffix:@"1970"]) {
        NSDateFormatter *in = [NSDateFormatter new], *out = [NSDateFormatter new];
        in.locale = out.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        in.dateFormat = @"EEE MMM d HH:mm:ss yyyy"; out.dateFormat = @"yyyy:MM:dd HH:mm:ss";
        NSDate *d = [in dateFromString:[ts stringByReplacingOccurrencesOfString:@"  " withString:@" "]];
        if (d) { exif[@"DateTimeOriginal"] = [out stringFromDate:d]; tiff[@"DateTime"] = exif[@"DateTimeOriginal"]; }
    }
    double iso = [line_value(_isimInfo, @"ISO speed:") doubleValue];
    if (iso > 0) exif[@"ISOSpeedRatings"] = @[ @(iso) ];
    NSString *sh = line_value(_isimInfo, @"Shutter:");
    if (sh.length) {
        NSArray *n = numbers_in([sh stringByReplacingOccurrencesOfString:@"/" withString:@" "]);
        double t = [sh hasPrefix:@"1/"] && n.count >= 2 ? 1 / [n[1] doubleValue] : n.count ? [n[0] doubleValue] : 0;
        if (t > 0 && isfinite(t)) exif[@"ExposureTime"] = @(t);
    }
    double fn = [[line_value(_isimInfo, @"Aperture:") stringByReplacingOccurrencesOfString:@"f/" withString:@""] doubleValue];
    if (fn > 0) exif[@"FNumber"] = @(fn);
    double fl = [line_value(_isimInfo, @"Focal length:") doubleValue];
    if (fl > 0) exif[@"FocalLength"] = @(fl);
    exif[@"PixelXDimension"] = p[@"PixelWidth"]; exif[@"PixelYDimension"] = p[@"PixelHeight"];
    p[@"{TIFF}"] = tiff; p[@"{Exif}"] = exif;
    if ([_isimPath.pathExtension.lowercaseString isEqualToString:@"dng"]) p[@"{DNG}"] = @{};
    return p;
}

/* ---- white balance ---- */
- (CIVector *)neutralChromaticity { double x, y; xy_of(_neutralTemperature, _neutralTint, &x, &y); return [CIVector vectorWithX:x Y:y]; }
- (void)setNeutralChromaticity:(CIVector *)v {
    if (!v || v.Y <= 0) return;
    double x = v.X, y = v.Y, X = x / y, Z = (1 - x - y) / y;
    float rgb[3] = { (float)(3.2404542 * X - 1.5371385 - 0.4985314 * Z), (float)(-0.9692660 * X + 1.8760108 + 0.0415560 * Z),
                     (float)(0.0556434 * X - 0.2040259 + 1.0572252 * Z) };
    double T, t; solve_wb(rgb, &T, &t);
    _neutralTemperature = (float)T; _neutralTint = (float)t;
}
- (CGPoint)neutralLocation { return CGPointZero; }
/* makes the color at point (in the oriented, unscaled image) neutral */
- (void)setNeutralLocation:(CGPoint)pt {
    CIImage *base = [[self decodedHalf:NO] imageByApplyingCGOrientation:_orientation];
    base = [base imageByApplyingTransform:CGAffineTransformMakeTranslation(-base.extent.origin.x, -base.extent.origin.y)];
    if (!CGRectContainsPoint(base.extent, pt)) return;
    CIContext *ctx = [CIContext contextWithOptions:@{ kCIContextWorkingColorSpace: (__bridge id)ci_cgspace_named(kCGColorSpaceLinearSRGB) }];
    float px[4] = { 0 };
    CIImage *avg = [[base imageByCroppingToRect:CGRectMake(floor(pt.x) - 2, floor(pt.y) - 2, 5, 5)] imageByApplyingFilter:@"CIAreaAverage"
                                                                                                     withInputParameters:@{ kCIInputExtentKey: [CIVector vectorWithCGRect:CGRectIntersection(base.extent, CGRectMake(floor(pt.x) - 2, floor(pt.y) - 2, 5, 5))] }];
    [ctx render:avg toBitmap:px rowBytes:16 bounds:CGRectMake(0, 0, 1, 1) format:kCIFormatRGBAf colorSpace:ci_cgspace_named(kCGColorSpaceLinearSRGB)];
    if (px[3] <= 0) return;
    float shot[3]; ci_white_rgb(_isimShotT, _isimShotTint, shot);
    float want[3]; for (int k = 0; k < 3; k++) want[k] = px[k] / px[3] * shot[k];
    double T, t; solve_wb(want, &T, &t);
    _neutralTemperature = (float)T; _neutralTint = (float)t;
}

/* ---- decoding ---- */
- (CIImage *)decodedHalf:(BOOL)half {
    int hl = _highlightRecoveryEnabled ? 2 : 0;
    NSString *key = [NSString stringWithFormat:@"%d-%d", half, hl];
    @synchronized (self) {
        CIImage *im = _isimDecoded[key];
        if (im) return im;
        int w = 0, h = 0; unsigned short *rgb = NULL;
        if (!isim_raw_decode(_isimPath.fileSystemRepresentation, half, hl, &w, &h, &rgb)) return nil;
        float *px = malloc(sizeof(float) * 4 * (size_t)w * h);
        for (size_t i = 0; i < (size_t)w * h; i++) {
            for (int k = 0; k < 3; k++) px[i * 4 + k] = rgb[i * 3 + k] / 65535.0f;
            px[i * 4 + 3] = 1;
        }
        isim_media_free(rgb);
        im = ci_bitmap(px, w, h, CGRectMake(0, 0, w, h), ci_space_linear, NO);
        /* the half-size decode stands for the full image: scale it back to the native size */
        if (half && _isimRawSize.width > 0) im = [im imageByApplyingTransform:CGAffineTransformMakeScale(_isimRawSize.width / w, _isimRawSize.height / h)];
        _isimDecoded[key] = im;
        return im;
    }
}

/* ---- processing ---- */
static CIImage *filtered(CIImage *im, NSString *name, NSDictionary *params) {
    CIFilter *f = [CIFilter filterWithName:name withInputParameters:params];
    [f setValue:im forKey:kCIInputImageKey];
    return f.outputImage ?: im;
}
/* the boost tone curve, on luminance in a gamma 2.2 encoding: an S curve (boost, contrast) with a shadow lift */
static float boost_curve(float g, float a, float lift) {
    if (g <= 0) return g;
    if (g >= 1) return g;
    float s = g + a * g * (1 - g) * (2 * g - 1);
    s += lift * g * (1 - g) * (1 - g);
    return fmaxf(0, s);
}
- (CIImage *)toneMapped:(CIImage *)im {
    float a = 0.6f * _boostAmount + 0.5f * _contrastAmount, lift = (1 - _boostShadowAmount) * 0.5f * _boostAmount;
    float bias = fmaxf(0, fminf(0.5f, _shadowBias * 0.01f)), edr = fmaxf(0, _extendedDynamicRangeAmount);
    BOOL gamut = _gamutMappingEnabled;
    float headroom = 1 + edr * 3;
    return ci_op(im.extent, ^(CGRect r, float *out, const ci_rctx *rc) {
        [im _render:r into:out ctx:rc];
        size_t n = (size_t)r.size.width * (size_t)r.size.height;
        for (size_t i = 0; i < n; i++) {
            float *p = out + i * 4, al = p[3];
            if (al <= 0) continue;
            float c[3] = { p[0] / al, p[1] / al, p[2] / al };
            if (rc->managed) ci_convert_rgb(c, rc->ws, ci_space_linear);
            if (bias > 0) for (int k = 0; k < 3; k++) c[k] = fmaxf(0, c[k] - bias) / (1 - bias);
            float L = 0.2126f * c[0] + 0.7152f * c[1] + 0.0722f * c[2];
            if (L > 1e-6f) {
                float g = powf(L, 1 / 2.2f), s = boost_curve(g, a, lift), L2 = powf(s, 2.2f), k = L2 / L;
                for (int q = 0; q < 3; q++) c[q] *= k;
                L = L2;
            }
            if (gamut) {          /* bring negative (out of gamut) channels to 0 by desaturating toward luminance */
                float mn = fminf(c[0], fminf(c[1], c[2]));
                if (mn < 0 && L > 0) { float t = L / (L - mn); for (int q = 0; q < 3; q++) c[q] = L + (c[q] - L) * t; }
            }
            for (int q = 0; q < 3; q++) c[q] = fminf(c[q], headroom);
            if (rc->managed) ci_convert_rgb(c, ci_space_linear, rc->ws);
            p[0] = c[0] * al; p[1] = c[1] * al; p[2] = c[2] * al;
        }
    });
}
- (CIImage *)processedHalf:(BOOL)half {
    CIImage *im = [self decodedHalf:half];
    if (!im) return nil;
    CGRect e = im.extent;
    if (fabsf(_neutralTemperature - (float)_isimShotT) > 0.5f || fabsf(_neutralTint - (float)_isimShotTint) > 0.05f)
        im = filtered(im, @"CITemperatureAndTint", @{ @"inputNeutral": [CIVector vectorWithX:_neutralTemperature Y:_neutralTint],
                                                      @"inputTargetNeutral": [CIVector vectorWithX:_isimShotT Y:_isimShotTint] });
    float ev = _exposure + _baselineExposure;
    if (ev != 0) im = filtered(im, @"CIExposureAdjust", @{ kCIInputEVKey: @(ev) });
    if (_linearSpaceFilter) {
        [_linearSpaceFilter setValue:im forKey:kCIInputImageKey];
        im = _linearSpaceFilter.outputImage ?: im;
    }
    if (_luminanceNoiseReductionAmount > 0)
        im = filtered(im, @"CINoiseReduction", @{ @"inputNoiseLevel": @(0.06 * _luminanceNoiseReductionAmount), kCIInputSharpnessKey: @0 });
    float chroma = 6 * _colorNoiseReductionAmount + 3 * _moireReductionAmount;
    if (chroma > 0) {         /* color noise and moire: keep the luminance, blur the color */
        CIImage *blurred = [[[im imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:chroma] imageByCroppingToRect:e];
        CIFilter *lum = [CIFilter filterWithName:@"CILuminosityBlendMode"];
        [lum setValue:im forKey:kCIInputImageKey]; [lum setValue:blurred forKey:kCIInputBackgroundImageKey];
        im = [lum.outputImage imageByCroppingToRect:e] ?: im;
    }
    im = [self toneMapped:im];
    if (_localToneMapAmount > 0)
        im = filtered(im, @"CIHighlightShadowAdjust", @{ @"inputShadowAmount": @(0.6 * _localToneMapAmount), @"inputHighlightAmount": @(1 - 0.3 * _localToneMapAmount),
                                                         kCIInputRadiusKey: @(fmax(e.size.width, e.size.height) / 50) });
    if (_sharpnessAmount > 0 && !_isimSharpeningOff)
        im = [filtered([im imageByClampingToExtent], @"CIUnsharpMask", @{ kCIInputRadiusKey: @2.0, kCIInputIntensityKey: @(0.8 * _sharpnessAmount) }) imageByCroppingToRect:e];
    if (_detailAmount > 0)
        im = [filtered([im imageByClampingToExtent], @"CIUnsharpMask", @{ kCIInputRadiusKey: @0.8, kCIInputIntensityKey: @(0.6 * _detailAmount) }) imageByCroppingToRect:e];
    im = [im imageByApplyingCGOrientation:_orientation];
    im = [im imageByApplyingTransform:CGAffineTransformMakeTranslation(-im.extent.origin.x, -im.extent.origin.y)];
    return im;
}
- (CIImage *)outputImage {
    float s = _scaleFactor > 0 ? _scaleFactor : 1;
    BOOL half = _draftModeEnabled || s <= 0.5f;
    CIImage *im = [self processedHalf:half];
    if (!im) return nil;
    if (s != 1) {
        im = filtered(im, @"CILanczosScaleTransform", @{ kCIInputScaleKey: @(s), kCIInputAspectRatioKey: @1 });
        im = [im imageByApplyingTransform:CGAffineTransformMakeTranslation(-im.extent.origin.x, -im.extent.origin.y)];
    }
    return im;
}
/* the embedded preview is not extracted: a draft (half size) rendering at a quarter of the native size stands in */
- (CIImage *)previewImage {
    CIImage *im = [self processedHalf:YES];
    if (!im) return nil;
    return [im imageByApplyingTransform:CGAffineTransformMakeScale(0.25, 0.25)];
}

/* ---- the pre-iOS 15 key-value API ---- */
- (NSArray<NSString *> *)inputKeys {
    return @[ kCIInputEVKey, kCIInputBoostKey, kCIInputNeutralChromaticityXKey, kCIInputNeutralChromaticityYKey, kCIInputNeutralTemperatureKey,
              kCIInputNeutralTintKey, kCIInputNeutralLocationKey, kCIInputScaleFactorKey, kCIInputAllowDraftModeKey, kCIInputIgnoreImageOrientationKey,
              kCIInputImageOrientationKey, kCIInputEnableSharpeningKey, kCIInputEnableChromaticNoiseTrackingKey, kCIInputNoiseReductionAmountKey,
              kCIInputMoireAmountKey, kCIInputEnableVendorLensCorrectionKey, kCIInputLuminanceNoiseReductionAmountKey,
              kCIInputColorNoiseReductionAmountKey, kCIInputNoiseReductionSharpnessAmountKey, kCIInputNoiseReductionContrastAmountKey,
              kCIInputNoiseReductionDetailAmountKey, kCIInputEnableEDRModeKey, kCIInputLocalToneMapAmountKey, kCIInputLinearSpaceFilter,
              kCIInputBaselineExposureKey, kCIInputBoostShadowAmountKey, kCIInputDecoderVersionKey ];
}
- (NSArray<NSString *> *)outputKeys { return @[ kCIOutputImageKey, kCIOutputNativeSizeKey ]; }
- (NSDictionary *)attributes {
    NSMutableDictionary *a = [NSMutableDictionary dictionary];
    a[kCIAttributeFilterName] = @"CIRAWFilter"; a[kCIAttributeFilterDisplayName] = @"RAW";
    a[kCIAttributeFilterCategories] = @[ kCICategoryStillImage, kCICategoryBuiltIn ];
    for (NSString *k in self.inputKeys) {
        id v = [self valueForKey:k];
        a[k] = @{ kCIAttributeName: k, kCIAttributeClass: v ? NSStringFromClass([v class]) : @"NSObject" };
    }
    return a;
}
static NSDictionary *old_keys(void) {
    static NSDictionary *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        m = @{ kCIInputEVKey: @"exposure", kCIInputBoostKey: @"boostAmount", kCIInputNeutralTemperatureKey: @"neutralTemperature",
               kCIInputNeutralTintKey: @"neutralTint", kCIInputScaleFactorKey: @"scaleFactor", kCIInputAllowDraftModeKey: @"draftModeEnabled",
               kCIInputNoiseReductionAmountKey: @"luminanceNoiseReductionAmount", kCIInputMoireAmountKey: @"moireReductionAmount",
               kCIInputEnableVendorLensCorrectionKey: @"lensCorrectionEnabled", kCIInputLuminanceNoiseReductionAmountKey: @"luminanceNoiseReductionAmount",
               kCIInputColorNoiseReductionAmountKey: @"colorNoiseReductionAmount", kCIInputNoiseReductionSharpnessAmountKey: @"sharpnessAmount",
               kCIInputNoiseReductionContrastAmountKey: @"contrastAmount", kCIInputNoiseReductionDetailAmountKey: @"detailAmount",
               kCIInputLocalToneMapAmountKey: @"localToneMapAmount", kCIInputLinearSpaceFilter: @"linearSpaceFilter",
               kCIInputBaselineExposureKey: @"baselineExposure", kCIInputBoostShadowAmountKey: @"boostShadowAmount",
               kCIInputDecoderVersionKey: @"decoderVersion", kCIInputImageOrientationKey: @"orientation" };
    });
    return m;
}
- (void)setValue:(id)value forKey:(NSString *)key {
    NSString *prop = old_keys()[key];
    if (prop) { [super setValue:value forKey:prop]; return; }
    if ([key isEqualToString:kCIInputNeutralChromaticityXKey] || [key isEqualToString:kCIInputNeutralChromaticityYKey]) {
        CIVector *c = self.neutralChromaticity;
        double x = [key isEqualToString:kCIInputNeutralChromaticityXKey] ? [value doubleValue] : c.X, y = [key isEqualToString:kCIInputNeutralChromaticityYKey] ? [value doubleValue] : c.Y;
        self.neutralChromaticity = [CIVector vectorWithX:x Y:y];
    } else if ([key isEqualToString:kCIInputNeutralLocationKey]) {
        CIVector *v = value; if (v) self.neutralLocation = CGPointMake(v.X, v.Y);
    } else if ([key isEqualToString:kCIInputIgnoreImageOrientationKey]) {
        _orientation = [value boolValue] ? kCGImagePropertyOrientationUp : orientation_of_flip(_isimFlip);
    } else if ([key isEqualToString:kCIInputEnableSharpeningKey]) {
        _isimSharpeningOff = ![value boolValue];
    } else if ([key isEqualToString:kCIInputEnableEDRModeKey]) {
        _extendedDynamicRangeAmount = [value boolValue] ? 1 : 0;
    } else if ([key isEqualToString:kCIInputEnableChromaticNoiseTrackingKey]) {
        /* accepted; isim has no chromatic noise tracking */
    } else [super setValue:value forKey:key];
}
- (id)valueForKey:(NSString *)key {
    NSString *prop = old_keys()[key];
    if (prop) return [super valueForKey:prop];
    if ([key isEqualToString:kCIInputNeutralChromaticityXKey]) return @(self.neutralChromaticity.X);
    if ([key isEqualToString:kCIInputNeutralChromaticityYKey]) return @(self.neutralChromaticity.Y);
    if ([key isEqualToString:kCIInputNeutralLocationKey]) return [CIVector vectorWithX:0 Y:0];
    if ([key isEqualToString:kCIInputIgnoreImageOrientationKey]) return @(_orientation == kCGImagePropertyOrientationUp && _isimFlip != 0);
    if ([key isEqualToString:kCIInputEnableSharpeningKey]) return @(!_isimSharpeningOff);
    if ([key isEqualToString:kCIInputEnableEDRModeKey]) return @(_extendedDynamicRangeAmount > 0);
    if ([key isEqualToString:kCIInputEnableChromaticNoiseTrackingKey]) return @NO;
    if ([key isEqualToString:kCIOutputNativeSizeKey]) { CGSize s = self.nativeSize; return [CIVector vectorWithX:s.width Y:s.height]; }
    if ([key isEqualToString:kCISupportedDecoderVersionsKey]) return self.supportedDecoderVersions;
    if ([key isEqualToString:kCIActiveKeys]) {
        NSMutableArray *a = [self.inputKeys mutableCopy];
        [a removeObject:kCIInputEnableVendorLensCorrectionKey];
        return a;
    }
    if ([key isEqualToString:kCIOutputImageKey]) return self.outputImage;
    return [super valueForKey:key];
}
@end

@implementation CIFilter (CIRAWFilter)
static void apply_options(CIFilter *f, NSDictionary *o) {
    for (NSString *k in o) {
        if ([k isEqualToString:@"kCGImageSourceTypeIdentifierHint"]) continue;
        @try { [f setValue:o[k] forKey:k]; } @catch (NSException *e) {}
    }
}
+ (CIFilter *)filterWithImageURL:(NSURL *)url options:(NSDictionary *)options {
    CIRAWFilter *f = [CIRAWFilter filterWithImageURL:url];
    if (f) apply_options(f, options);
    return f;
}
+ (CIFilter *)filterWithImageData:(NSData *)data options:(NSDictionary *)options {
    CIRAWFilter *f = [CIRAWFilter filterWithImageData:data identifierHint:options[@"kCGImageSourceTypeIdentifierHint"]];
    if (f) apply_options(f, options);
    return f;
}
+ (NSArray<NSString *> *)supportedRawCameraModels { return CIRAWFilter.supportedCameraModels; }
@end
