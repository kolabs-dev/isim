#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#ifndef CT_EXPORT
#define CT_EXPORT extern __attribute__((visibility("default")))
#endif
/* isim: a descriptor is a dictionary of attributes (name, family, size, traits, feature settings) */
typedef const struct __attribute__((objc_bridge(id))) __CTFontDescriptor *CTFontDescriptorRef;
typedef CF_OPTIONS(uint32_t, CTFontSymbolicTraits) {
    kCTFontTraitItalic = (1 << 0), kCTFontTraitBold = (1 << 1), kCTFontTraitExpanded = (1 << 5), kCTFontTraitCondensed = (1 << 6),
    kCTFontTraitMonoSpace = (1 << 10), kCTFontTraitVertical = (1 << 11), kCTFontTraitUIOptimized = (1 << 12),
    kCTFontTraitColorGlyphs = (1 << 13), kCTFontTraitComposite = (1 << 14), kCTFontTraitClassMask = (15U << 28)
};
typedef CF_ENUM(uint32_t, CTFontOrientation) { kCTFontOrientationDefault = 0, kCTFontOrientationHorizontal = 1, kCTFontOrientationVertical = 2 };
CT_EXPORT const CFStringRef kCTFontNameAttribute;
CT_EXPORT const CFStringRef kCTFontDisplayNameAttribute;
CT_EXPORT const CFStringRef kCTFontFamilyNameAttribute;
CT_EXPORT const CFStringRef kCTFontStyleNameAttribute;
CT_EXPORT const CFStringRef kCTFontSizeAttribute;
CT_EXPORT const CFStringRef kCTFontTraitsAttribute;
CT_EXPORT const CFStringRef kCTFontSymbolicTrait;
CT_EXPORT const CFStringRef kCTFontWeightTrait;
CT_EXPORT const CFStringRef kCTFontWidthTrait;
CT_EXPORT const CFStringRef kCTFontSlantTrait;
/* features: OpenType tags (kCTFontOpenTypeFeatureTag/Value) go to the shaper; a few AAT type/selector pairs are
 * mapped (number spacing, lower-case small caps, common ligatures) */
CT_EXPORT const CFStringRef kCTFontFeatureSettingsAttribute;
CT_EXPORT const CFStringRef kCTFontFeatureTypeIdentifierKey;
CT_EXPORT const CFStringRef kCTFontFeatureSelectorIdentifierKey;
CT_EXPORT const CFStringRef kCTFontOpenTypeFeatureTag;
CT_EXPORT const CFStringRef kCTFontOpenTypeFeatureValue;
CT_EXPORT CFTypeID CTFontDescriptorGetTypeID(void);
CT_EXPORT CTFontDescriptorRef CTFontDescriptorCreateWithNameAndSize(CFStringRef name, CGFloat size);
CT_EXPORT CTFontDescriptorRef CTFontDescriptorCreateWithAttributes(CFDictionaryRef attributes);
CT_EXPORT CTFontDescriptorRef CTFontDescriptorCreateCopyWithAttributes(CTFontDescriptorRef original, CFDictionaryRef attributes);
CT_EXPORT CTFontDescriptorRef _Nullable CTFontDescriptorCreateCopyWithSymbolicTraits(CTFontDescriptorRef original, CTFontSymbolicTraits symTraitValue, CTFontSymbolicTraits symTraitMask);
CT_EXPORT CTFontDescriptorRef CTFontDescriptorCreateCopyWithFamily(CTFontDescriptorRef original, CFStringRef family);
CT_EXPORT CTFontDescriptorRef CTFontDescriptorCreateCopyWithFeature(CTFontDescriptorRef original, CFNumberRef featureTypeIdentifier, CFNumberRef featureSelectorIdentifier);
CT_EXPORT CFDictionaryRef CTFontDescriptorCopyAttributes(CTFontDescriptorRef descriptor);
CT_EXPORT CFTypeRef _Nullable CTFontDescriptorCopyAttribute(CTFontDescriptorRef descriptor, CFStringRef attribute);
#pragma clang arc_cf_code_audited end
__END_DECLS
