// isim CIFilter: the registry of built-in filters (generated from gen_filters.py into CIFilterSpec.inc), their typed
// CIFilterBuiltins accessors, filters registered by apps, CIFilter subclasses, coding and XMP serialization.
#import "CIInternal.h"
#include <objc/runtime.h>

typedef struct {
    const char *key, *cls, *atype, *prop, *ptype;
    int nvals; const double *vals; const char *str;
    double mn, mx, smin, smax;
    int identity_xform;
} ci_input_spec;
typedef struct { const char *name, *display; int ios; const char *cats; int ninputs; const ci_input_spec *inputs; const char *factory; } ci_filter_spec;
#include "CIFilterSpec.inc"

NSString *const kCIAttributeFilterName = @"CIAttributeFilterName", *const kCIAttributeFilterDisplayName = @"CIAttributeFilterDisplayName",
    *const kCIAttributeDescription = @"CIAttributeDescription", *const kCIAttributeFilterAvailable_Mac = @"CIAttributeFilterAvailable_Mac",
    *const kCIAttributeFilterAvailable_iOS = @"CIAttributeFilterAvailable_iOS", *const kCIAttributeReferenceDocumentation = @"CIAttributeReferenceDocumentation",
    *const kCIAttributeFilterCategories = @"CIAttributeFilterCategories", *const kCIAttributeClass = @"CIAttributeClass",
    *const kCIAttributeType = @"CIAttributeType", *const kCIAttributeMin = @"CIAttributeMin", *const kCIAttributeMax = @"CIAttributeMax",
    *const kCIAttributeSliderMin = @"CIAttributeSliderMin", *const kCIAttributeSliderMax = @"CIAttributeSliderMax",
    *const kCIAttributeDefault = @"CIAttributeDefault", *const kCIAttributeIdentity = @"CIAttributeIdentity",
    *const kCIAttributeName = @"CIAttributeName", *const kCIAttributeDisplayName = @"CIAttributeDisplayName";
NSString *const kCIUIParameterSet = @"CIUIParameterSet", *const kCIUISetBasic = @"CIUISetBasic", *const kCIUISetIntermediate = @"CIUISetIntermediate",
    *const kCIUISetAdvanced = @"CIUISetAdvanced", *const kCIUISetDevelopment = @"CIUISetDevelopment";
NSString *const kCIAttributeTypeTime = @"CIAttributeTypeTime", *const kCIAttributeTypeScalar = @"CIAttributeTypeScalar",
    *const kCIAttributeTypeDistance = @"CIAttributeTypeDistance", *const kCIAttributeTypeAngle = @"CIAttributeTypeAngle",
    *const kCIAttributeTypeBoolean = @"CIAttributeTypeBoolean", *const kCIAttributeTypeInteger = @"CIAttributeTypeInteger",
    *const kCIAttributeTypeCount = @"CIAttributeTypeCount", *const kCIAttributeTypePosition = @"CIAttributeTypePosition",
    *const kCIAttributeTypeOffset = @"CIAttributeTypeOffset", *const kCIAttributeTypePosition3 = @"CIAttributeTypePosition3",
    *const kCIAttributeTypeRectangle = @"CIAttributeTypeRectangle", *const kCIAttributeTypeOpaqueColor = @"CIAttributeTypeOpaqueColor",
    *const kCIAttributeTypeColor = @"CIAttributeTypeColor", *const kCIAttributeTypeGradient = @"CIAttributeTypeGradient",
    *const kCIAttributeTypeImage = @"CIAttributeTypeImage", *const kCIAttributeTypeTransform = @"CIAttributeTypeTransform";
NSString *const kCICategoryDistortionEffect = @"CICategoryDistortionEffect", *const kCICategoryGeometryAdjustment = @"CICategoryGeometryAdjustment",
    *const kCICategoryCompositeOperation = @"CICategoryCompositeOperation", *const kCICategoryHalftoneEffect = @"CICategoryHalftoneEffect",
    *const kCICategoryColorAdjustment = @"CICategoryColorAdjustment", *const kCICategoryColorEffect = @"CICategoryColorEffect",
    *const kCICategoryTransition = @"CICategoryTransition", *const kCICategoryTileEffect = @"CICategoryTileEffect",
    *const kCICategoryGenerator = @"CICategoryGenerator", *const kCICategoryReduction = @"CICategoryReduction",
    *const kCICategoryGradient = @"CICategoryGradient", *const kCICategoryStylize = @"CICategoryStylize", *const kCICategorySharpen = @"CICategorySharpen",
    *const kCICategoryBlur = @"CICategoryBlur", *const kCICategoryVideo = @"CICategoryVideo", *const kCICategoryStillImage = @"CICategoryStillImage",
    *const kCICategoryInterlaced = @"CICategoryInterlaced", *const kCICategoryNonSquarePixels = @"CICategoryNonSquarePixels",
    *const kCICategoryHighDynamicRange = @"CICategoryHighDynamicRange", *const kCICategoryBuiltIn = @"CICategoryBuiltIn",
    *const kCICategoryFilterGenerator = @"CICategoryFilterGenerator";
NSString *const kCIOutputImageKey = @"outputImage", *const kCIInputBackgroundImageKey = @"inputBackgroundImage", *const kCIInputImageKey = @"inputImage",
    *const kCIInputDepthImageKey = @"inputDepthImage", *const kCIInputDisparityImageKey = @"inputDisparityImage", *const kCIInputAmountKey = @"inputAmount",
    *const kCIInputTimeKey = @"inputTime", *const kCIInputTransformKey = @"inputTransform", *const kCIInputScaleKey = @"inputScale",
    *const kCIInputAspectRatioKey = @"inputAspectRatio", *const kCIInputCenterKey = @"inputCenter", *const kCIInputRadiusKey = @"inputRadius",
    *const kCIInputAngleKey = @"inputAngle", *const kCIInputRefractionKey = @"inputRefraction", *const kCIInputWidthKey = @"inputWidth",
    *const kCIInputSharpnessKey = @"inputSharpness", *const kCIInputIntensityKey = @"inputIntensity", *const kCIInputEVKey = @"inputEV",
    *const kCIInputSaturationKey = @"inputSaturation", *const kCIInputColorKey = @"inputColor", *const kCIInputBrightnessKey = @"inputBrightness",
    *const kCIInputContrastKey = @"inputContrast", *const kCIInputBiasKey = @"inputBias", *const kCIInputWeightsKey = @"inputWeights",
    *const kCIInputGradientImageKey = @"inputGradientImage", *const kCIInputMaskImageKey = @"inputMaskImage", *const kCIInputMatteImageKey = @"inputMatteImage",
    *const kCIInputShadingImageKey = @"inputShadingImage", *const kCIInputTargetImageKey = @"inputTargetImage", *const kCIInputExtentKey = @"inputExtent",
    *const kCIInputVersionKey = @"inputVersion";
NSString *const kCIApplyOptionExtent = @"extent", *const kCIApplyOptionDefinition = @"definition", *const kCIApplyOptionUserInfo = @"user_info",
    *const kCIApplyOptionColorSpace = @"color_space";

/* ================= helpers for filter implementations ================= */
double ci_num(id v, double d) { return [v respondsToSelector:@selector(doubleValue)] ? [v doubleValue] : d; }
CGPoint ci_point(id v, CGPoint d) {
    if ([v isKindOfClass:[CIVector class]]) return [(CIVector *)v CGPointValue];
    if ([v isKindOfClass:[NSValue class]] && !strcmp([v objCType], @encode(CGPoint))) return [v CGPointValue];
    return d;
}
CGRect ci_rect(id v, CGRect d) {
    if ([v isKindOfClass:[CIVector class]]) return [(CIVector *)v CGRectValue];
    if ([v isKindOfClass:[NSValue class]] && !strcmp([v objCType], @encode(CGRect))) return [v CGRectValue];
    return d;
}
CGAffineTransform ci_xform(id v) {
    if ([v isKindOfClass:[CIVector class]]) return [(CIVector *)v CGAffineTransformValue];
    if ([v isKindOfClass:[NSValue class]] && !strcmp([v objCType], @encode(CGAffineTransform))) return [v CGAffineTransformValue];
    return CGAffineTransformIdentity;
}
CIColor *ci_colorv(id v, CIColor *d) {
    if ([v isKindOfClass:[CIColor class]]) return v;
    if (ci_is_cgcolor(v)) return [CIColor colorWithCGColor:(__bridge CGColorRef)v];
    if ([v respondsToSelector:@selector(CGColor)]) return [CIColor colorWithCGColor:[v CGColor]];
    return d;
}

static NSMutableDictionary<NSString *, ci_filter_impl> *impls;
static pthread_mutex_t reg_m = PTHREAD_MUTEX_INITIALIZER;
void ci_register_impl(NSString *name, ci_filter_impl impl) { impls[name] = [impl copy]; }
static void register_once(void) {
    impls = [NSMutableDictionary dictionary];
    ci_register_color_filters(); ci_register_blur_filters(); ci_register_composite_filters(); ci_register_geometry_filters();
    ci_register_distortion_filters(); ci_register_generator_filters(); ci_register_stylize_filters(); ci_register_reduction_filters();
    ci_register_tile_filters(); ci_register_transition_filters(); ci_register_ml_filters(); ci_register_halftone_filters();
}
ci_filter_impl ci_impl_for(NSString *name) {
    static pthread_once_t once = PTHREAD_ONCE_INIT;
    pthread_once(&once, register_once);
    return impls[name];
}

/* ================= spec lookups ================= */
static int os_hundreds(void) { int v = isim_os_version(); return v > 0 ? v / 100 : 1800; }
static NSDictionary *spec_index;
static void build_index(void) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (int i = 0; i < CI_FILTER_COUNT; i++) d[@(ci_filter_specs[i].name)] = @(i);
    spec_index = d;
}
static const ci_filter_spec *spec_named(NSString *name) {
    static pthread_once_t once = PTHREAD_ONCE_INIT;
    pthread_once(&once, build_index);
    NSDictionary *index = spec_index;
    NSNumber *i = index[name];
    if (!i) return NULL;
    const ci_filter_spec *s = &ci_filter_specs[i.intValue];
    return s->ios <= os_hundreds() ? s : NULL;
}
static id default_value(const ci_input_spec *in) {
    NSString *cls = @(in->cls);
    if (in->identity_xform) return [NSValue valueWithCGAffineTransform:CGAffineTransformIdentity];
    if (in->str) {
        if ([cls isEqualToString:@"CGColorSpace"]) return (__bridge id)ci_cgspace_named(kCGColorSpaceSRGB);
        return @(in->str);
    }
    if (in->nvals == 0) {
        if ([cls isEqualToString:@"NSData"] && !strncmp(in->key, "inputCube", 9)) {   /* identity 2x2x2 color cube */
            static const float cube[32] = { 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1 };
            return [NSData dataWithBytes:cube length:sizeof cube];
        }
        return nil;
    }
    if ([cls isEqualToString:@"NSNumber"]) return isnan(in->vals[0]) ? nil : @(in->vals[0]);
    if ([cls isEqualToString:@"CIVector"]) {
        CGFloat v[64]; for (int i = 0; i < in->nvals && i < 64; i++) v[i] = in->vals[i];
        return [CIVector vectorWithValues:v count:(size_t)in->nvals];
    }
    if ([cls isEqualToString:@"CIColor"]) return [CIColor colorWithRed:in->vals[0] green:in->vals[1] blue:in->vals[2] alpha:in->nvals > 3 ? in->vals[3] : 1];
    return nil;
}
static NSDictionary *input_attributes(const ci_input_spec *in) {
    NSMutableDictionary *a = [NSMutableDictionary dictionary];
    NSString *cls = @(in->cls);
    a[kCIAttributeClass] = [cls isEqualToString:@"CGColorSpace"] ? @"NSObject" : cls;
    if (in->atype[0]) a[kCIAttributeType] = [@"CIAttributeType" stringByAppendingString:@(in->atype)];
    id d = default_value(in);
    if (d) a[kCIAttributeDefault] = d;
    if (!isnan(in->mn)) a[kCIAttributeMin] = @(in->mn);
    if (!isnan(in->mx)) a[kCIAttributeMax] = @(in->mx);
    if (!isnan(in->smin)) a[kCIAttributeSliderMin] = @(in->smin);
    if (!isnan(in->smax)) a[kCIAttributeSliderMax] = @(in->smax);
    if (d && ([cls isEqualToString:@"NSNumber"] || [cls isEqualToString:@"CIVector"] || in->identity_xform)) a[kCIAttributeIdentity] = d;
    NSString *k = @(in->key);
    a[kCIAttributeName] = k;
    NSString *dn = [k hasPrefix:@"input"] ? [k substringFromIndex:5] : k;
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < dn.length; i++) {
        unichar c = [dn characterAtIndex:i];
        if (i > 0 && isupper(c) && !isupper([dn characterAtIndex:i - 1])) [s appendString:@" "];
        [s appendFormat:@"%C", c];
    }
    a[kCIAttributeDisplayName] = s;
    return a;
}

/* ================= built-in filter classes and their typed accessors ================= */
CI_HIDDEN @interface __CIBuiltinFilter : CIFilter { @public NSMutableDictionary *_in; const ci_filter_spec *_spec; }
@end
CI_HIDDEN @interface __CIBuiltinFilter2 : __CIBuiltinFilter
@end
CI_HIDDEN @interface __CIBuiltinFilter3 : __CIBuiltinFilter
@end

static const ci_input_spec *input_for_prop(const ci_filter_spec *s, const char *prop) {
    for (int i = 0; i < s->ninputs; i++) if (!strcmp(s->inputs[i].prop, prop)) return &s->inputs[i];
    return NULL;
}
static const ci_input_spec *input_for_sel(__CIBuiltinFilter *f, SEL sel, BOOL *setter) {
    const char *n = sel_getName(sel);
    char buf[128];
    *setter = !strncmp(n, "set", 3) && n[strlen(n) - 1] == ':';
    if (*setter) {
        size_t l = strlen(n) - 4; if (l >= sizeof buf) return NULL;
        memcpy(buf, n + 3, l); buf[l] = 0;
        const ci_input_spec *in = input_for_prop(f->_spec, buf);
        if (in) return in;
        buf[0] = (char)tolower(buf[0]);
        return input_for_prop(f->_spec, buf);
    }
    return input_for_prop(f->_spec, n);
}
#define KEY(self, sel) ({ BOOL st_; const ci_input_spec *in_ = input_for_sel(self, sel, &st_); in_ ? @(in_->key) : nil; })
static float get_float(__CIBuiltinFilter *self, SEL _cmd) { return (float)ci_num(self->_in[KEY(self, _cmd)], 0); }
static void set_float(__CIBuiltinFilter *self, SEL _cmd, float v) { [self setValue:@(v) forKey:KEY(self, _cmd)]; }
static BOOL get_bool(__CIBuiltinFilter *self, SEL _cmd) { return ci_num(self->_in[KEY(self, _cmd)], 0) != 0; }
static void set_bool(__CIBuiltinFilter *self, SEL _cmd, BOOL v) { [self setValue:@(v) forKey:KEY(self, _cmd)]; }
static NSInteger get_int(__CIBuiltinFilter *self, SEL _cmd) { return (NSInteger)llround(ci_num(self->_in[KEY(self, _cmd)], 0)); }
static void set_int(__CIBuiltinFilter *self, SEL _cmd, NSInteger v) { [self setValue:@(v) forKey:KEY(self, _cmd)]; }
static CGPoint get_point(__CIBuiltinFilter *self, SEL _cmd) { return ci_point(self->_in[KEY(self, _cmd)], CGPointZero); }
static void set_point(__CIBuiltinFilter *self, SEL _cmd, CGPoint p) { [self setValue:[CIVector vectorWithCGPoint:p] forKey:KEY(self, _cmd)]; }
static CGRect get_rect(__CIBuiltinFilter *self, SEL _cmd) { return ci_rect(self->_in[KEY(self, _cmd)], CGRectZero); }
static void set_rect(__CIBuiltinFilter *self, SEL _cmd, CGRect r) { [self setValue:[CIVector vectorWithCGRect:r] forKey:KEY(self, _cmd)]; }
static CGAffineTransform get_xform(__CIBuiltinFilter *self, SEL _cmd) { return ci_xform(self->_in[KEY(self, _cmd)]); }
static void set_xform(__CIBuiltinFilter *self, SEL _cmd, CGAffineTransform t) { [self setValue:[NSValue valueWithCGAffineTransform:t] forKey:KEY(self, _cmd)]; }
static id get_obj(__CIBuiltinFilter *self, SEL _cmd) { return self->_in[KEY(self, _cmd)]; }
static void set_obj(__CIBuiltinFilter *self, SEL _cmd, id v) { [self setValue:v forKey:KEY(self, _cmd)]; }

/* class for a filter: the accessors of one class must agree on each selector's type; the few filters whose
   accessor types clash with another filter's (size, correctionLevel) use the second and third classes */
static Class class_for_spec(const ci_filter_spec *s) {
    if (!strcmp(s->name, "CITriangleKaleidoscope")) return [__CIBuiltinFilter2 class];
    if (!strcmp(s->name, "CIAztecCodeGenerator") || !strcmp(s->name, "CIPDF417BarcodeGenerator")) return [__CIBuiltinFilter3 class];
    return [__CIBuiltinFilter class];
}

@implementation __CIBuiltinFilter
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    /* find the selector's type in any filter served by this class */
    const char *n = sel_getName(sel);
    BOOL setter = !strncmp(n, "set", 3) && n[strlen(n) - 1] == ':';
    char prop[128];
    if (setter) { size_t l = strlen(n) - 4; if (l >= sizeof prop) return NO; memcpy(prop, n + 3, l); prop[l] = 0; }
    else { if (strlen(n) >= sizeof prop || strchr(n, ':')) return [super resolveInstanceMethod:sel]; strcpy(prop, n); }
    const char *ptype = NULL;
    for (int i = 0; i < CI_FILTER_COUNT && !ptype; i++) {
        if (class_for_spec(&ci_filter_specs[i]) != self) continue;
        const ci_input_spec *in = input_for_prop(&ci_filter_specs[i], prop);
        if (!in && setter) { char lp[128]; strcpy(lp, prop); lp[0] = (char)tolower(lp[0]); in = input_for_prop(&ci_filter_specs[i], lp); }
        if (in) ptype = in->ptype;
    }
    if (!ptype) return [super resolveInstanceMethod:sel];
    IMP imp; const char *types;
    if (!strcmp(ptype, "float")) { imp = setter ? (IMP)set_float : (IMP)get_float; types = setter ? "v@:f" : "f@:"; }
    else if (!strcmp(ptype, "BOOL")) { imp = setter ? (IMP)set_bool : (IMP)get_bool; types = setter ? "v@:c" : "c@:"; }
    else if (!strcmp(ptype, "NSInteger") || !strcmp(ptype, "NSUInteger")) { imp = setter ? (IMP)set_int : (IMP)get_int; types = setter ? "v@:q" : "q@:"; }
    else if (!strcmp(ptype, "CGPoint")) { imp = setter ? (IMP)set_point : (IMP)get_point; types = setter ? "v@:{CGPoint=dd}" : "{CGPoint=dd}@:"; }
    else if (!strcmp(ptype, "CGRect")) { imp = setter ? (IMP)set_rect : (IMP)get_rect; types = setter ? "v@:{CGRect={CGPoint=dd}{CGSize=dd}}" : "{CGRect={CGPoint=dd}{CGSize=dd}}@:"; }
    else if (!strcmp(ptype, "CGAffineTransform")) { imp = setter ? (IMP)set_xform : (IMP)get_xform; types = setter ? "v@:{CGAffineTransform=dddddd}" : "{CGAffineTransform=dddddd}@:"; }
    else { imp = setter ? (IMP)set_obj : (IMP)get_obj; types = setter ? "v@:@" : "@@:"; }
    class_addMethod(self, sel, imp, types);
    return YES;
}
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p> %@", @(_spec->name), self, _in]; }
- (NSArray<NSString *> *)inputKeys {
    NSMutableArray *k = [NSMutableArray array];
    for (int i = 0; i < _spec->ninputs; i++) [k addObject:@(_spec->inputs[i].key)];
    return k;
}
- (NSArray<NSString *> *)outputKeys { return @[ kCIOutputImageKey ]; }
- (NSDictionary *)attributes {
    NSMutableDictionary *a = [NSMutableDictionary dictionary];
    a[kCIAttributeFilterName] = @(_spec->name);
    a[kCIAttributeFilterDisplayName] = @(_spec->display);
    NSMutableArray *cats = [NSMutableArray array];
    for (NSString *c in [@(_spec->cats) componentsSeparatedByString:@","]) [cats addObject:[@"CICategory" stringByAppendingString:c]];
    a[kCIAttributeFilterCategories] = cats;
    a[kCIAttributeFilterAvailable_iOS] = [NSString stringWithFormat:@"%d", _spec->ios / 100];
    a[kCIAttributeFilterAvailable_Mac] = [NSString stringWithFormat:@"10.%d", _spec->ios / 100 + 3];
    a[kCIAttributeReferenceDocumentation] = [CIFilter localizedReferenceDocumentationForFilterName:@(_spec->name)];
    for (int i = 0; i < _spec->ninputs; i++) a[@(_spec->inputs[i].key)] = input_attributes(&_spec->inputs[i]);
    a[kCIOutputImageKey] = @{ kCIAttributeClass: @"CIImage", kCIAttributeType: kCIAttributeTypeImage };
    return a;
}
- (void)setDefaults {
    for (int i = 0; i < _spec->ninputs; i++) {
        id d = default_value(&_spec->inputs[i]);
        if (d) _in[@(_spec->inputs[i].key)] = d;
        else if (strcmp(_spec->inputs[i].cls, "CIImage")) [_in removeObjectForKey:@(_spec->inputs[i].key)];
    }
}
- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key hasPrefix:@"input"]) {
        if (value && value != [NSNull null]) _in[key] = value; else [_in removeObjectForKey:key];
        return;
    }
    [super setValue:value forKey:key];
}
- (id)valueForKey:(NSString *)key {
    if ([key isEqualToString:kCIOutputImageKey]) return self.outputImage;
    if ([key hasPrefix:@"input"]) return _in[key];
    return [super valueForKey:key];
}
- (CIImage *)outputImage {
    ci_filter_impl impl = ci_impl_for(@(_spec->name));
    if (!impl) { NSLog(@"isim: Core Image: %s has no implementation", _spec->name); return nil; }
    @try { return impl(_in); }
    @catch (NSException *e) { NSLog(@"isim: Core Image: %s: %@", _spec->name, e.reason); return nil; }
}
- (id)copyWithZone:(NSZone *)z {
    __CIBuiltinFilter *f = [[self class] new];
    f->_spec = _spec; f->_in = [_in mutableCopy]; f.name = self.name;
    return f;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:@(_spec->name) forKey:@"CIFilterClassName"];
    [c encodeObject:self.name forKey:@"name"];
    for (NSString *k in _in) {
        id v = _in[k];
        if (ci_is_cgspace(v)) {
            CFStringRef n = CGColorSpaceGetName((__bridge CGColorSpaceRef)v);
            if (n) [c encodeObject:@{ @"colorSpace": (__bridge NSString *)n } forKey:k];
            continue;
        }
        if ([v conformsToProtocol:@protocol(NSCoding)]) [c encodeObject:v forKey:k];
    }
}
@end
@implementation __CIBuiltinFilter2
@end
@implementation __CIBuiltinFilter3
@end

static __CIBuiltinFilter *make_builtin(const ci_filter_spec *s) {
    __CIBuiltinFilter *f = [class_for_spec(s) new];
    f->_spec = s; f->_in = [NSMutableDictionary dictionary]; f.name = @(s->name);
    [f setDefaults];
    return f;
}

/* ================= registered (app) filters ================= */
static NSMutableDictionary<NSString *, NSArray *> *registered;     /* name -> [constructor, attributes] */

/* ================= CIFilter ================= */
static id factory_call(id cls, SEL sel);
@implementation CIFilter { NSString *_name; }
+ (BOOL)supportsSecureCoding { return YES; }
+ (BOOL)resolveClassMethod:(SEL)sel {
    const char *n = sel_getName(sel);
    if (!strchr(n, ':')) {
        BOOL known = !strcmp(n, "affineTransformFilter");
        for (int i = 0; i < CI_FILTER_COUNT && !known; i++) if (ci_filter_specs[i].factory && !strcmp(ci_filter_specs[i].factory, n)) known = YES;
        if (known) { class_addMethod(object_getClass(self), sel, (IMP)factory_call, "@@:"); return YES; }
    }
    return [super resolveClassMethod:sel];
}
- (NSString *)name { return _name ?: NSStringFromClass([self class]); }
- (void)setName:(NSString *)n { _name = [n copy]; }
- (CIImage *)outputImage { return nil; }
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p>", self.name, self]; }

/* app subclasses: inputs are the properties named input..., outputs output...; attributes from customAttributes */
static NSArray *props_with_prefix(Class c, NSString *prefix) {
    NSMutableOrderedSet *s = [NSMutableOrderedSet orderedSet];
    for (Class k = c; k && k != [CIFilter class]; k = class_getSuperclass(k)) {
        unsigned n = 0; objc_property_t *p = class_copyPropertyList(k, &n);
        for (unsigned i = 0; i < n; i++) { NSString *nm = @(property_getName(p[i])); if ([nm hasPrefix:prefix]) [s addObject:nm]; }
        free(p);
    }
    return s.array;
}
- (NSArray<NSString *> *)inputKeys {
    NSMutableOrderedSet *s = [NSMutableOrderedSet orderedSetWithArray:props_with_prefix([self class], @"input")];
    NSDictionary *ca = [[self class] respondsToSelector:@selector(customAttributes)] ? [(id)[self class] customAttributes] : nil;
    for (NSString *k in ca) if ([k hasPrefix:@"input"]) [s addObject:k];
    return s.array;
}
- (NSArray<NSString *> *)outputKeys {
    NSMutableOrderedSet *s = [NSMutableOrderedSet orderedSetWithObject:kCIOutputImageKey];
    [s addObjectsFromArray:props_with_prefix([self class], @"output")];
    return s.array;
}
- (NSDictionary *)attributes {
    NSMutableDictionary *a = [NSMutableDictionary dictionary];
    NSDictionary *ca = [[self class] respondsToSelector:@selector(customAttributes)] ? [(id)[self class] customAttributes] : nil;
    if (ca) [a addEntriesFromDictionary:ca];
    NSArray *reg = registered[self.name];
    if (reg) [a addEntriesFromDictionary:reg[1]];
    a[kCIAttributeFilterName] = a[kCIAttributeFilterName] ?: self.name;
    a[kCIAttributeFilterDisplayName] = a[kCIAttributeFilterDisplayName] ?: self.name;
    if (!a[kCIAttributeFilterCategories]) a[kCIAttributeFilterCategories] = @[];
    for (NSString *k in self.inputKeys) {
        if (a[k]) continue;
        objc_property_t p = class_getProperty([self class], k.UTF8String);
        NSString *cls = @"NSObject";
        if (p) {
            const char *at = property_getAttributes(p);
            if (at[1] == '@' && at[2] == '"') { const char *e = strchr(at + 3, '"'); if (e) cls = [[NSString alloc] initWithBytes:at + 3 length:(NSUInteger)(e - at - 3) encoding:NSUTF8StringEncoding]; }
            else if (at[1] != '@') cls = @"NSNumber";
        }
        a[k] = @{ kCIAttributeClass: cls, kCIAttributeName: k };
    }
    return a;
}
- (void)setDefaults {
    NSDictionary *a = self.attributes;
    for (NSString *k in self.inputKeys) {
        id d = [a[k] isKindOfClass:[NSDictionary class]] ? a[k][kCIAttributeDefault] : nil;
        if (d) @try { [self setValue:d forKey:k]; } @catch (NSException *e) {}
    }
}
- (id)copyWithZone:(NSZone *)z {
    CIFilter *f = [[self class] new];
    f.name = _name;
    for (NSString *k in self.inputKeys) @try { [f setValue:[self valueForKey:k] forKey:k]; } @catch (NSException *e) {}
    return f;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:self.name forKey:@"name"];
    for (NSString *k in self.inputKeys) {
        id v = nil; @try { v = [self valueForKey:k]; } @catch (NSException *e) {}
        if ([v conformsToProtocol:@protocol(NSCoding)]) [c encodeObject:v forKey:k];
    }
}
- (instancetype)initWithCoder:(NSCoder *)c {
    NSString *builtin = [c decodeObjectOfClass:[NSString class] forKey:@"CIFilterClassName"];
    NSSet *classes = [NSSet setWithObjects:[CIImage class], [CIVector class], [CIColor class], [NSNumber class], [NSString class], [NSData class],
                      [NSValue class], [NSArray class], [NSDictionary class], [NSAttributedString class], nil];
    if (builtin) {
        const ci_filter_spec *s = spec_named(builtin);
        if (!s) return nil;
        __CIBuiltinFilter *f = make_builtin(s);
        NSString *nm = [c decodeObjectOfClass:[NSString class] forKey:@"name"];
        if (nm) f.name = nm;
        for (int i = 0; i < s->ninputs; i++) {
            NSString *k = @(s->inputs[i].key);
            id v = [c decodeObjectOfClasses:classes forKey:k];
            if ([v isKindOfClass:[NSDictionary class]] && v[@"colorSpace"]) v = (__bridge id)ci_cgspace_named((__bridge CFStringRef)v[@"colorSpace"]);
            if (v) [f setValue:v forKey:k];
        }
        return (id)f;
    }
    if (!(self = [self init])) return nil;
    _name = [c decodeObjectOfClass:[NSString class] forKey:@"name"];
    for (NSString *k in self.inputKeys) { id v = [c decodeObjectOfClasses:classes forKey:k]; if (v) @try { [self setValue:v forKey:k]; } @catch (NSException *e) {} }
    return self;
}
- (CIImage *)apply:(CIKernel *)k arguments:(NSArray *)args options:(NSDictionary *)o {
    CGRect extent = CGRectInfinite;
    id e = o[kCIApplyOptionExtent];
    if ([e isKindOfClass:[NSArray class]] && [e count] == 4) extent = CGRectMake([e[0] doubleValue], [e[1] doubleValue], [e[2] doubleValue], [e[3] doubleValue]);
    else if ([e isKindOfClass:[CIVector class]]) extent = [e CGRectValue];
    else if (!e) {                     /* default: the union of the sampler / image arguments' extents */
        extent = CGRectNull;
        for (id a in args) if ([a respondsToSelector:@selector(extent)]) extent = CGRectUnion(extent, [a extent]);
        if (CGRectIsNull(extent)) extent = CGRectInfinite;
    }
    return [k applyWithExtent:extent roiCallback:^CGRect(int i, CGRect r) { return CGRectInfinite; } arguments:args];
}
- (CIImage *)apply:(CIKernel *)k, ... {
    NSMutableArray *args = [NSMutableArray array]; NSDictionary *opts = nil;
    va_list ap; va_start(ap, k);
    for (id a = va_arg(ap, id); a; a = va_arg(ap, id)) {
        if ([a isKindOfClass:[NSString class]] && [a isEqualToString:@"options"]) { opts = va_arg(ap, id); break; }
        [args addObject:a];
    }
    va_end(ap);
    return [self apply:k arguments:args options:opts];
}
@end

static id factory_call(id cls, SEL sel) {
    const char *n = sel_getName(sel);
    if (!strcmp(n, "affineTransformFilter")) return [CIFilter filterWithName:@"CIAffineTransform"];
    for (int i = 0; i < CI_FILTER_COUNT; i++)
        if (ci_filter_specs[i].factory && !strcmp(ci_filter_specs[i].factory, n)) return [CIFilter filterWithName:@(ci_filter_specs[i].name)];
    return nil;
}

@implementation CIFilter (CIFilterRegistry)
+ (CIFilter *)filterWithName:(NSString *)name {
    if (!name) return nil;
    pthread_mutex_lock(&reg_m);
    NSArray *reg = registered[name];
    pthread_mutex_unlock(&reg_m);
    if (reg) {
        CIFilter *f = [reg[0] filterWithName:name];
        if (f && ![f.name isEqualToString:name]) f.name = name;
        [f setDefaults];
        return f;
    }
    const ci_filter_spec *s = spec_named(name);
    if (!s) return nil;
    return make_builtin(s);
}
+ (CIFilter *)filterWithName:(NSString *)name withInputParameters:(NSDictionary *)params {
    CIFilter *f = [self filterWithName:name];
    for (NSString *k in params) [f setValue:params[k] forKey:k];
    return f;
}
+ (CIFilter *)filterWithName:(NSString *)name keysAndValues:(id)key0, ... {
    CIFilter *f = [self filterWithName:name];
    va_list ap; va_start(ap, key0);
    for (id k = key0; k; k = va_arg(ap, id)) { id v = va_arg(ap, id); [f setValue:v forKey:k]; }
    va_end(ap);
    return f;
}
+ (NSArray<NSString *> *)filterNamesInCategory:(NSString *)cat { return [self filterNamesInCategories:cat ? @[ cat ] : nil]; }
+ (NSArray<NSString *> *)filterNamesInCategories:(NSArray<NSString *> *)cats {
    NSMutableArray *out = [NSMutableArray array];
    int os = os_hundreds();
    for (int i = 0; i < CI_FILTER_COUNT; i++) {
        const ci_filter_spec *s = &ci_filter_specs[i];
        if (s->ios > os) continue;
        NSArray *have = [@(s->cats) componentsSeparatedByString:@","];
        BOOL ok = YES;
        for (NSString *c in cats) if (![have containsObject:[c hasPrefix:@"CICategory"] ? [c substringFromIndex:10] : c]) ok = NO;
        if (ok) [out addObject:@(s->name)];
    }
    pthread_mutex_lock(&reg_m);
    for (NSString *n in registered) {
        NSArray *have = registered[n][1][kCIAttributeFilterCategories] ?: @[];
        BOOL ok = YES;
        for (NSString *c in cats) if (![have containsObject:c]) ok = NO;
        if (ok) [out addObject:n];
    }
    pthread_mutex_unlock(&reg_m);
    return [out sortedArrayUsingSelector:@selector(compare:)];
}
+ (void)registerFilterName:(NSString *)name constructor:(id<CIFilterConstructor>)c classAttributes:(NSDictionary *)attrs {
    if (!name || !c) return;
    pthread_mutex_lock(&reg_m);
    if (!registered) registered = [NSMutableDictionary dictionary];
    registered[name] = @[ c, attrs ?: @{} ];
    pthread_mutex_unlock(&reg_m);
}
+ (NSString *)localizedNameForFilterName:(NSString *)n {
    const ci_filter_spec *s = spec_named(n);
    if (s) return @(s->display);
    NSArray *reg = registered[n];
    return reg ? reg[1][kCIAttributeFilterDisplayName] ?: n : nil;
}
+ (NSString *)localizedNameForCategory:(NSString *)c {
    NSString *s = [c hasPrefix:@"CICategory"] ? [c substringFromIndex:10] : c;
    NSDictionary *names = @{ @"DistortionEffect": @"Distortion", @"GeometryAdjustment": @"Geometry Adjustment", @"CompositeOperation": @"Composite",
                             @"HalftoneEffect": @"Halftone", @"ColorAdjustment": @"Color Adjustment", @"ColorEffect": @"Color Effect",
                             @"TileEffect": @"Tile", @"HighDynamicRange": @"High Dynamic Range", @"StillImage": @"Still Image",
                             @"NonSquarePixels": @"Non-Square Pixels", @"BuiltIn": @"Built-In", @"FilterGenerator": @"Filter Generator" };
    return names[s] ?: s;
}
+ (NSString *)localizedDescriptionForFilterName:(NSString *)n {
    const ci_filter_spec *s = spec_named(n);
    if (!s) { NSArray *reg = registered[n]; return reg[1][kCIAttributeDescription]; }
    NSString *cat = [[@(s->cats) componentsSeparatedByString:@","] firstObject];
    return [NSString stringWithFormat:@"%s (Core Image %@ filter).", s->display, [[self localizedNameForCategory:cat] lowercaseString]];
}
+ (NSURL *)localizedReferenceDocumentationForFilterName:(NSString *)n {
    if (!spec_named(n)) return nil;
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html#//apple_ref/doc/filter/ci/%@", n]];
}
@end

/* ================= XMP ================= */
static NSString *xml_escape(NSString *s) {
    return [[[[s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]
             stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"] stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
}
static NSString *xml_unescape(NSString *s) {
    return [[[[s stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""] stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"]
             stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
}
@implementation CIFilter (CIFilterXMPSerialization)
+ (NSData *)serializedXMPFromFilters:(NSArray<CIFilter *> *)filters inputImageExtent:(CGRect)extent {
    NSMutableString *x = [NSMutableString stringWithString:@"<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n <rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n"
                          "  <rdf:Description rdf:about=\"\" xmlns:isimci=\"http://isim.dev/ns/coreimage/1.0/\">\n"];
    [x appendFormat:@"   <isimci:extent>%g %g %g %g</isimci:extent>\n   <isimci:filters>\n    <rdf:Seq>\n",
     extent.origin.x, extent.origin.y, extent.size.width, extent.size.height];
    for (CIFilter *f in filters) {
        [x appendFormat:@"     <rdf:li isimci:name=\"%@\"", xml_escape(f.name)];
        for (NSString *k in f.inputKeys) {
            if ([k isEqualToString:kCIInputImageKey]) continue;
            id v = [f valueForKey:k]; NSString *s = nil;
            if ([v isKindOfClass:[NSNumber class]]) s = [NSString stringWithFormat:@"n:%@", v];
            else if ([v isKindOfClass:[CIVector class]]) s = [@"v:" stringByAppendingString:[v stringRepresentation]];
            else if ([v isKindOfClass:[CIColor class]]) s = [@"c:" stringByAppendingString:[v stringRepresentation]];
            else if ([v isKindOfClass:[NSValue class]] && !strcmp([v objCType], @encode(CGAffineTransform))) s = [@"t:" stringByAppendingString:[[CIVector vectorWithCGAffineTransform:[v CGAffineTransformValue]] stringRepresentation]];
            else if ([v isKindOfClass:[NSString class]]) s = [@"s:" stringByAppendingString:v];
            if (s) [x appendFormat:@" isimci:%@=\"%@\"", k, xml_escape(s)];
        }
        [x appendString:@"/>\n"];
    }
    [x appendString:@"    </rdf:Seq>\n   </isimci:filters>\n  </rdf:Description>\n </rdf:RDF>\n</x:xmpmeta>\n"];
    return [x dataUsingEncoding:NSUTF8StringEncoding];
}
+ (NSArray<CIFilter *> *)filterArrayFromSerializedXMP:(NSData *)xmp inputImageExtent:(CGRect)extent error:(NSError **)err {
    NSString *s = [[NSString alloc] initWithData:xmp encoding:NSUTF8StringEncoding];
    NSMutableArray *out = [NSMutableArray array];
    if (![s containsString:@"http://isim.dev/ns/coreimage/1.0/"]) {
        if (err) *err = [NSError errorWithDomain:@"CIFilterXMPErrorDomain" code:1
                                        userInfo:@{ NSLocalizedDescriptionKey: @"isim reads only XMP written by isim's Core Image" }];
        return out;
    }
    NSRegularExpression *li = [NSRegularExpression regularExpressionWithPattern:@"<rdf:li([^>]*)/>" options:0 error:nil];
    NSRegularExpression *attr = [NSRegularExpression regularExpressionWithPattern:@"isimci:([A-Za-z0-9_]+)=\"([^\"]*)\"" options:0 error:nil];
    for (NSTextCheckingResult *m in [li matchesInString:s options:0 range:NSMakeRange(0, s.length)]) {
        NSString *body = [s substringWithRange:[m rangeAtIndex:1]];
        CIFilter *f = nil; NSMutableDictionary *vals = [NSMutableDictionary dictionary];
        for (NSTextCheckingResult *a in [attr matchesInString:body options:0 range:NSMakeRange(0, body.length)]) {
            NSString *k = [body substringWithRange:[a rangeAtIndex:1]], *v = xml_unescape([body substringWithRange:[a rangeAtIndex:2]]);
            if ([k isEqualToString:@"name"]) { f = [CIFilter filterWithName:v]; continue; }
            if (v.length < 2) continue;
            NSString *t = [v substringToIndex:2], *p = [v substringFromIndex:2];
            if ([t isEqualToString:@"n:"]) vals[k] = @(p.doubleValue);
            else if ([t isEqualToString:@"v:"]) vals[k] = [CIVector vectorWithString:p];
            else if ([t isEqualToString:@"c:"]) vals[k] = [CIColor colorWithString:p];
            else if ([t isEqualToString:@"t:"]) vals[k] = [NSValue valueWithCGAffineTransform:[[CIVector vectorWithString:p] CGAffineTransformValue]];
            else if ([t isEqualToString:@"s:"]) vals[k] = p;
        }
        if (!f) continue;
        for (NSString *k in vals) [f setValue:vals[k] forKey:k];
        [out addObject:f];
    }
    return out;
}
@end
