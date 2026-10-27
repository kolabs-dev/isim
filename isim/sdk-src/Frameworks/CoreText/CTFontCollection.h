#pragma once
#include <CoreText/CTFontDescriptor.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: the faces fontconfig lists (and fonts the app registered), matched as CTFontDescriptorCreateMatchingFontDescriptors does */
typedef const struct __attribute__((objc_bridge(id))) __CTFontCollection *CTFontCollectionRef;
typedef struct __attribute__((objc_bridge_mutable(id))) __CTFontCollection *CTMutableFontCollectionRef;
CT_EXPORT CFTypeID CTFontCollectionGetTypeID(void);
typedef CFComparisonResult (*CTFontCollectionSortDescriptorsCallback)(CTFontDescriptorRef first, CTFontDescriptorRef second, void *refCon);
CT_EXPORT const CFStringRef kCTFontCollectionRemoveDuplicatesOption;
CT_EXPORT const CFStringRef kCTFontCollectionIncludeDisabledFontsOption;
CT_EXPORT const CFStringRef kCTFontCollectionDisallowAutoActivationOption;
typedef CF_OPTIONS(uint32_t, CTFontCollectionCopyOptions) {
    kCTFontCollectionCopyDefaultOptions = 0, kCTFontCollectionCopyUnique = (1 << 0), kCTFontCollectionCopyStandardSort = (1 << 1)
};
CT_EXPORT CTFontCollectionRef CTFontCollectionCreateFromAvailableFonts(CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
CT_EXPORT CTFontCollectionRef CTFontCollectionCreateWithFontDescriptors(CFArrayRef _Nullable queryDescriptors, CFDictionaryRef _Nullable options)
    CF_RETURNS_RETAINED;
CT_EXPORT CTFontCollectionRef CTFontCollectionCreateCopyWithFontDescriptors(CTFontCollectionRef original, CFArrayRef _Nullable queryDescriptors,
                                                                            CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
CT_EXPORT CFArrayRef _Nullable CTFontCollectionCreateMatchingFontDescriptors(CTFontCollectionRef collection) CF_RETURNS_RETAINED;
CT_EXPORT CFArrayRef _Nullable CTFontCollectionCreateMatchingFontDescriptorsSortedWithCallback(CTFontCollectionRef collection,
                                                                                                CTFontCollectionSortDescriptorsCallback _Nullable sortCallback,
                                                                                                void *_Nullable refCon) CF_RETURNS_RETAINED;
CT_EXPORT CFArrayRef _Nullable CTFontCollectionCreateMatchingFontDescriptorsWithOptions(CTFontCollectionRef collection, CFDictionaryRef _Nullable options)
    CF_RETURNS_RETAINED;
CT_EXPORT CFArrayRef CTFontCollectionCopyFontAttribute(CTFontCollectionRef collection, CFStringRef attributeName, CTFontCollectionCopyOptions options)
    CF_RETURNS_RETAINED;
CT_EXPORT CFArrayRef CTFontCollectionCopyFontAttributes(CTFontCollectionRef collection, CFSetRef attributeNames, CTFontCollectionCopyOptions options)
    CF_RETURNS_RETAINED;
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
