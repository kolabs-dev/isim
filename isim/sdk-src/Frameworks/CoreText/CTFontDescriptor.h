#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
#ifndef CT_EXPORT
#define CT_EXPORT extern __attribute__((visibility("default")))
#endif
/* isim: a descriptor is a dictionary of attributes (name, family, style, size, traits, feature settings); matching
 * resolves it through the host's fontconfig */
typedef const struct __attribute__((objc_bridge(id))) __CTFontDescriptor *CTFontDescriptorRef;
typedef CF_OPTIONS(uint32_t, CTFontSymbolicTraits) {
    kCTFontTraitItalic = (1 << 0), kCTFontTraitBold = (1 << 1), kCTFontTraitExpanded = (1 << 5), kCTFontTraitCondensed = (1 << 6),
    kCTFontTraitMonoSpace = (1 << 10), kCTFontTraitVertical = (1 << 11), kCTFontTraitUIOptimized = (1 << 12),
    kCTFontTraitColorGlyphs = (1 << 13), kCTFontTraitComposite = (1 << 14), kCTFontTraitClassMask = (15U << 28),
    /* the older names */
    kCTFontItalicTrait = kCTFontTraitItalic, kCTFontBoldTrait = kCTFontTraitBold, kCTFontExpandedTrait = kCTFontTraitExpanded,
    kCTFontCondensedTrait = kCTFontTraitCondensed, kCTFontMonoSpaceTrait = kCTFontTraitMonoSpace, kCTFontVerticalTrait = kCTFontTraitVertical,
    kCTFontUIOptimizedTrait = kCTFontTraitUIOptimized, kCTFontColorGlyphsTrait = kCTFontTraitColorGlyphs, kCTFontCompositeTrait = kCTFontTraitComposite,
    kCTFontClassMaskTrait = kCTFontTraitClassMask
};
typedef CF_OPTIONS(uint32_t, CTFontStylisticClass) {
    kCTFontClassUnknown = (0 << 28), kCTFontClassOldStyleSerifs = (1 << 28), kCTFontClassTransitionalSerifs = (2 << 28),
    kCTFontClassModernSerifs = (3 << 28), kCTFontClassClarendonSerifs = (4 << 28), kCTFontClassSlabSerifs = (5 << 28),
    kCTFontClassFreeformSerifs = (7 << 28), kCTFontClassSansSerif = (8U << 28), kCTFontClassOrnamentals = (9U << 28),
    kCTFontClassScripts = (10U << 28), kCTFontClassSymbolic = (12U << 28)
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
CT_EXPORT const CFStringRef kCTFontURLAttribute;               /* the font file (a CFURL) */
/* features: OpenType tags (kCTFontOpenTypeFeatureTag/Value) go to the shaper (HarfBuzz); AAT type/selector pairs are
 * mapped to their OpenType features (ligatures, number spacing and case, fractions, vertical position, slashed zero,
 * case-sensitive forms, small and petite caps, contextual and swash alternates, stylistic sets) */
CT_EXPORT const CFStringRef kCTFontFeatureSettingsAttribute;
CT_EXPORT const CFStringRef kCTFontFeaturesAttribute;
CT_EXPORT const CFStringRef kCTFontFeatureTypeIdentifierKey;
CT_EXPORT const CFStringRef kCTFontFeatureTypeNameKey;
CT_EXPORT const CFStringRef kCTFontFeatureTypeExclusiveKey;
CT_EXPORT const CFStringRef kCTFontFeatureTypeSelectorsKey;
CT_EXPORT const CFStringRef kCTFontFeatureSelectorIdentifierKey;
CT_EXPORT const CFStringRef kCTFontFeatureSelectorNameKey;
CT_EXPORT const CFStringRef kCTFontFeatureSelectorDefaultKey;
CT_EXPORT const CFStringRef kCTFontFeatureSelectorSettingKey;
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
CT_EXPORT CFTypeRef _Nullable CTFontDescriptorCopyLocalizedAttribute(CTFontDescriptorRef descriptor, CFStringRef attribute, CFStringRef _Nullable *_Nullable language);
/* the installed faces that match: the family's faces filtered by the descriptor's name, style and traits (the
 * mandatory attributes are matched exactly); NULL when none does */
CT_EXPORT CFArrayRef _Nullable CTFontDescriptorCreateMatchingFontDescriptors(CTFontDescriptorRef descriptor, CFSetRef _Nullable mandatoryAttributes);
/* the closest installed face: the descriptor of the font CTFontCreateWithFontDescriptor makes */
CT_EXPORT CTFontDescriptorRef _Nullable CTFontDescriptorCreateMatchingFontDescriptor(CTFontDescriptorRef descriptor, CFSetRef _Nullable mandatoryAttributes);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
