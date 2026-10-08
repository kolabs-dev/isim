/* isim UIKit (ARC): UIFontDescriptor — an attribute dictionary with Apple's keys, and the UIFont it describes.
 * A font's descriptor carries its name, size, text style (Dynamic Type), traits (symbolic traits, weight, design)
 * and features (monospaced digits); UIFont(descriptor:size:) turns them back into a font: bold / weights, italic,
 * monospaced, tabular digits, the serif design (the host's serif face) are drawn; the rounded design and widths use
 * the default face (adapted). */
#import "UIKitPrivate.h"
#import <UIKit/UIFontDescriptor.h>

UIFontDescriptorAttributeName const UIFontDescriptorFamilyAttribute = @"NSFontFamilyAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorNameAttribute = @"NSFontNameAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorFaceAttribute = @"NSFontFaceAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorSizeAttribute = @"NSFontSizeAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorVisibleNameAttribute = @"NSFontVisibleNameAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorMatrixAttribute = @"NSFontMatrixAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorCharacterSetAttribute = @"NSCTFontCharacterSetAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorCascadeListAttribute = @"NSCTFontCascadeListAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorTraitsAttribute = @"NSCTFontTraitsAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorFixedAdvanceAttribute = @"NSCTFontFixedAdvanceAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorFeatureSettingsAttribute = @"NSCTFontFeatureSettingsAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorTextStyleAttribute = @"NSCTFontUIUsageAttribute";
UIFontDescriptorTraitKey const UIFontSymbolicTrait = @"NSCTFontSymbolicTrait";
UIFontDescriptorTraitKey const UIFontWeightTrait = @"NSCTFontWeightTrait";
UIFontDescriptorTraitKey const UIFontWidthTrait = @"NSCTFontProportionTrait";
UIFontDescriptorTraitKey const UIFontSlantTrait = @"NSCTFontSlantTrait";
UIFontDescriptorFeatureKey const UIFontFeatureTypeIdentifierKey = @"CTFeatureTypeIdentifier";
UIFontDescriptorFeatureKey const UIFontFeatureSelectorIdentifierKey = @"CTFeatureSelectorIdentifier";
UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignDefault = @"NSCTFontUIFontDesignDefault";
UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignRounded = @"NSCTFontUIFontDesignRounded";
UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignSerif = @"NSCTFontUIFontDesignSerif";
UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignMonospaced = @"NSCTFontUIFontDesignMonospaced";
const UIFontWidth UIFontWidthCondensed = -0.2, UIFontWidthStandard = 0, UIFontWidthExpanded = 0.2, UIFontWidthCompressed = -0.3;
static NSString *const kDesignTrait = @"NSCTFontUIFontDesignTrait";     /* the system design, inside the traits */

/* the monospaced-digits feature (kNumberSpacingType / kMonospacedNumbersSelector) */
static BOOL has_tabular_feature(NSArray *features) {
    for (NSDictionary *f in features)
        if ([f isKindOfClass:NSDictionary.class] && [f[UIFontFeatureTypeIdentifierKey] intValue] == 6 && [f[UIFontFeatureSelectorIdentifierKey] intValue] == 0) return YES;
    return NO;
}

@implementation UIFontDescriptor { NSDictionary *_attrs; }
- (instancetype)init { return [self initWithFontAttributes:@{}]; }
- (instancetype)initWithFontAttributes:(NSDictionary *)a { if ((self = [super init])) _attrs = [a copy] ?: @{}; return self; }
+ (UIFontDescriptor *)fontDescriptorWithFontAttributes:(NSDictionary *)a { return [[self alloc] initWithFontAttributes:a]; }
+ (UIFontDescriptor *)fontDescriptorWithName:(NSString *)name size:(CGFloat)size {
    return [[self alloc] initWithFontAttributes:@{UIFontDescriptorNameAttribute: name ?: @"", UIFontDescriptorSizeAttribute: @(size)}];
}
+ (UIFontDescriptor *)fontDescriptorWithName:(NSString *)name matrix:(CGAffineTransform)m {
    return [[self alloc] initWithFontAttributes:@{UIFontDescriptorNameAttribute: name ?: @"", UIFontDescriptorMatrixAttribute: [NSValue valueWithCGAffineTransform:m]}];
}
+ (UIFontDescriptor *)preferredFontDescriptorWithTextStyle:(UIFontTextStyle)style { return [UIFont preferredFontForTextStyle:style].fontDescriptor; }
+ (UIFontDescriptor *)preferredFontDescriptorWithTextStyle:(UIFontTextStyle)style compatibleWithTraitCollection:(UITraitCollection *)t {
    return [UIFont preferredFontForTextStyle:style compatibleWithTraitCollection:t].fontDescriptor;
}
- (UIFontDescriptor *)_with:(NSString *)k value:(id)v { NSMutableDictionary *d = [_attrs mutableCopy]; d[k] = v; return [[UIFontDescriptor alloc] initWithFontAttributes:d]; }
- (UIFontDescriptor *)fontDescriptorByAddingAttributes:(NSDictionary *)a {
    NSMutableDictionary *d = [_attrs mutableCopy]; [d addEntriesFromDictionary:a ?: @{}];
    return [[UIFontDescriptor alloc] initWithFontAttributes:d];
}
- (UIFontDescriptor *)fontDescriptorWithFamily:(NSString *)f {      /* a new family: the name no longer applies */
    NSMutableDictionary *d = [_attrs mutableCopy]; [d removeObjectForKey:UIFontDescriptorNameAttribute]; d[UIFontDescriptorFamilyAttribute] = f;
    return [[UIFontDescriptor alloc] initWithFontAttributes:d];
}
- (UIFontDescriptor *)fontDescriptorWithSize:(CGFloat)s { return [self _with:UIFontDescriptorSizeAttribute value:@(s)]; }
- (UIFontDescriptor *)fontDescriptorWithMatrix:(CGAffineTransform)m { return [self _with:UIFontDescriptorMatrixAttribute value:[NSValue valueWithCGAffineTransform:m]]; }
- (UIFontDescriptor *)fontDescriptorWithFace:(NSString *)face { return [self _with:UIFontDescriptorFaceAttribute value:face]; }
/* replaces the symbolic traits (weight follows the bold trait), like UIKit */
- (UIFontDescriptor *)fontDescriptorWithSymbolicTraits:(UIFontDescriptorSymbolicTraits)t {
    NSMutableDictionary *traits = [NSMutableDictionary dictionaryWithObject:@(t) forKey:UIFontSymbolicTrait];
    NSDictionary *old = _attrs[UIFontDescriptorTraitsAttribute];
    if ([old isKindOfClass:NSDictionary.class] && old[kDesignTrait]) traits[kDesignTrait] = old[kDesignTrait];
    return [self _with:UIFontDescriptorTraitsAttribute value:traits];
}
/* the system font's designs; nil for other fonts, like UIKit */
- (UIFontDescriptor *)fontDescriptorWithDesign:(UIFontDescriptorSystemDesign)design {
    if ([_attrs[UIFontDescriptorFamilyAttribute] length] || ([_attrs[UIFontDescriptorNameAttribute] length] && ![_attrs[UIFontDescriptorNameAttribute] hasPrefix:@"."])) return nil;
    if (![@[UIFontDescriptorSystemDesignDefault, UIFontDescriptorSystemDesignRounded, UIFontDescriptorSystemDesignSerif, UIFontDescriptorSystemDesignMonospaced] containsObject:design]) return nil;
    NSDictionary *old = _attrs[UIFontDescriptorTraitsAttribute];
    NSMutableDictionary *traits = [old isKindOfClass:NSDictionary.class] ? [old mutableCopy] : [NSMutableDictionary dictionary];
    traits[kDesignTrait] = design;
    NSMutableDictionary *d = [_attrs mutableCopy]; d[UIFontDescriptorTraitsAttribute] = traits;
    [d removeObjectForKey:UIFontDescriptorNameAttribute];          /* the design picks the face */
    if (!traits[UIFontWeightTrait] && !traits[UIFontSymbolicTrait] && [_attrs[UIFontDescriptorNameAttribute] length]) {
        UIFont *f = [UIFont fontWithDescriptor:self size:0]; traits[UIFontWeightTrait] = @(f._isim_weight);
        if (f._isim_italic) traits[UIFontSymbolicTrait] = @(UIFontDescriptorTraitItalic);
    }
    return [[UIFontDescriptor alloc] initWithFontAttributes:d];
}
- (id)objectForKey:(NSString *)k { return _attrs[k]; }
- (NSDictionary *)fontAttributes { return _attrs; }
- (CGFloat)pointSize {
    if (_attrs[UIFontDescriptorSizeAttribute]) return [_attrs[UIFontDescriptorSizeAttribute] doubleValue];
    return _attrs[UIFontDescriptorTextStyleAttribute] ? [UIFont preferredFontForTextStyle:_attrs[UIFontDescriptorTextStyleAttribute]].pointSize : 0;
}
- (CGAffineTransform)matrix {
    NSValue *v = _attrs[UIFontDescriptorMatrixAttribute];
    return [v isKindOfClass:NSValue.class] ? v.CGAffineTransformValue : CGAffineTransformIdentity;
}
- (UIFontDescriptorSymbolicTraits)symbolicTraits {
    NSDictionary *traits = _attrs[UIFontDescriptorTraitsAttribute];
    if ([traits isKindOfClass:NSDictionary.class] && traits[UIFontSymbolicTrait]) return [traits[UIFontSymbolicTrait] unsignedIntValue];
    UIFont *f = [UIFont fontWithDescriptor:self size:0];
    return (f._isim_weight >= UIFontWeightBold ? UIFontDescriptorTraitBold : 0) | (f._isim_italic ? UIFontDescriptorTraitItalic : 0) |
           (f._isim_mono ? UIFontDescriptorTraitMonoSpace : 0) | (f._isim_family && !f._isim_design ? 0 : UIFontDescriptorTraitUIOptimized);
}
- (NSString *)postscriptName {
    NSString *n = _attrs[UIFontDescriptorNameAttribute];
    if (n.length) return n;
    return [UIFont fontWithDescriptor:self size:0].fontName ?: @"";
}
- (NSArray<UIFontDescriptor *> *)matchingFontDescriptorsWithMandatoryKeys:(NSSet *)keys {
    NSString *name = _attrs[UIFontDescriptorNameAttribute], *family = _attrs[UIFontDescriptorFamilyAttribute];
    if (name.length && ![UIFont fontWithName:name size:12]) return @[];
    if (family.length && ![UIFont fontWithName:family size:12] && ![UIFont fontWithName:[family stringByReplacingOccurrencesOfString:@" " withString:@""] size:12]) return @[];
    return @[[UIFont fontWithDescriptor:self size:0].fontDescriptor];
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[UIFontDescriptor class]] && [((UIFontDescriptor *)o)->_attrs isEqual:_attrs]; }
- (NSUInteger)hash { return _attrs.hash; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_attrs forKey:@"UIFontDescriptorAttributes"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    NSDictionary *a = [c decodeObjectOfClasses:[NSSet setWithObjects:NSDictionary.class, NSArray.class, NSString.class, NSNumber.class, NSValue.class, nil]
                                        forKey:@"UIFontDescriptorAttributes"];
    return [self initWithFontAttributes:[a isKindOfClass:NSDictionary.class] ? a : @{}];
}
- (NSString *)description { return [NSString stringWithFormat:@"UICTFontDescriptor <%p> = %@", self, _attrs]; }
@end

static UIFont *font_for_family(NSString *family, CGFloat size) {
    return [UIFont fontWithName:family size:size] ?: [UIFont fontWithName:[family stringByReplacingOccurrencesOfString:@" " withString:@""] size:size];
}

@implementation UIFont (UIFontDescriptorSupport)
+ (UIFont *)fontWithDescriptor:(UIFontDescriptor *)d size:(CGFloat)size {
    NSDictionary *a = d.fontAttributes;
    NSString *name = a[UIFontDescriptorNameAttribute], *family = a[UIFontDescriptorFamilyAttribute], *style = a[UIFontDescriptorTextStyleAttribute];
    CGFloat s = size > 0 ? size : (d.pointSize > 0 ? d.pointSize : 17);
    UIFont *f = nil;
    if (style.length && (!name.length || [name hasPrefix:@"."])) f = [UIFont preferredFontForTextStyle:style];   /* Dynamic Type */
    if (f && f.pointSize != s) f = [f fontWithSize:s];
    if (!f && name.length) f = [UIFont fontWithName:name size:s];
    if (!f && family.length) f = font_for_family(family, s);
    if (!f) f = [UIFont systemFontOfSize:s];
    NSDictionary *traits = [a[UIFontDescriptorTraitsAttribute] isKindOfClass:NSDictionary.class] ? a[UIFontDescriptorTraitsAttribute] : nil;
    NSNumber *sym = traits[UIFontSymbolicTrait], *weight = traits[UIFontWeightTrait];
    NSString *design = traits[kDesignTrait];
    BOOL tabular = f._isim_tabular || has_tabular_feature(a[UIFontDescriptorFeatureSettingsAttribute]);
    if (!sym && !weight && !design && tabular == f._isim_tabular) return f;
    CGFloat w = weight ? weight.doubleValue : f._isim_weight;
    BOOL italic = f._isim_italic, mono = f._isim_mono;
    if (sym) {
        uint32_t t = sym.unsignedIntValue;
        if (t & UIFontDescriptorTraitBold) { if (w < UIFontWeightBold) w = UIFontWeightBold; }
        else if (!weight && w >= UIFontWeightBold) w = UIFontWeightRegular;
        italic = (t & UIFontDescriptorTraitItalic) != 0;
        if (!f._isim_family) mono = (t & UIFontDescriptorTraitMonoSpace) != 0;     /* the system font has a monospaced face */
    }
    if ([design isEqualToString:UIFontDescriptorSystemDesignMonospaced]) mono = YES;
    else if (design) mono = NO;
    if ([design isEqualToString:UIFontDescriptorSystemDesignDefault]) design = nil;
    return [f _isim_variantWeight:w italic:italic mono:mono tabular:tabular design:design];
}
- (UIFontDescriptor *)fontDescriptor {
    NSMutableDictionary *a = [NSMutableDictionary dictionary];
    if (self.fontName.length) a[UIFontDescriptorNameAttribute] = self.fontName;
    if (self._isim_family.length && !self._isim_design) a[UIFontDescriptorFamilyAttribute] = self.familyName;
    a[UIFontDescriptorSizeAttribute] = @(self.pointSize);
    extern NSString *isim_ui_font_text_style(UIFont *f);
    NSString *style = isim_ui_font_text_style(self);
    if (style) a[UIFontDescriptorTextStyleAttribute] = style;
    UIFontDescriptorSymbolicTraits t = (self._isim_weight >= UIFontWeightBold ? UIFontDescriptorTraitBold : 0) | (self._isim_italic ? UIFontDescriptorTraitItalic : 0) |
                                       (self._isim_mono ? UIFontDescriptorTraitMonoSpace : 0) | (self._isim_family && !self._isim_design ? 0 : UIFontDescriptorTraitUIOptimized);
    NSMutableDictionary *traits = [@{UIFontSymbolicTrait: @(t), UIFontWeightTrait: @(self._isim_weight)} mutableCopy];
    if (self._isim_design) traits[kDesignTrait] = self._isim_design;
    a[UIFontDescriptorTraitsAttribute] = traits;
    if (self._isim_tabular) a[UIFontDescriptorFeatureSettingsAttribute] = @[@{UIFontFeatureTypeIdentifierKey: @6, UIFontFeatureSelectorIdentifierKey: @0}];
    return [UIFontDescriptor fontDescriptorWithFontAttributes:a];
}
+ (NSArray<NSString *> *)fontNamesForFamilyName:(NSString *)family {
    NSString *base = [family stringByReplacingOccurrencesOfString:@" " withString:@""];
    return @[base, [base stringByAppendingString:@"-Bold"]];
}
/* widths: the default width (adapted; no condensed / expanded face) */
+ (UIFont *)systemFontOfSize:(CGFloat)s weight:(UIFontWeight)w width:(UIFontWidth)width { return [self systemFontOfSize:s weight:w]; }
@end
