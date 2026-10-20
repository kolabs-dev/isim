#pragma once
/* XMP metadata (issue #272): isim's own model, XMP packets read and written by isim (NSXMLParser), and the EXIF, TIFF,
 * GPS and IPTC properties of an image expressed in their XMP namespaces. */
#include <ImageIO/CGImageProperties.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
typedef const struct __attribute__((objc_bridge(id))) CGImageMetadata *CGImageMetadataRef;
typedef struct __attribute__((objc_bridge_mutable(id))) CGImageMetadata *CGMutableImageMetadataRef;
typedef struct __attribute__((objc_bridge(id))) CGImageMetadataTag *CGImageMetadataTagRef;

IMAGEIO_EXTERN const CFStringRef kCGImageMetadataNamespaceExif;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataNamespaceExifAux;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataNamespaceExifEX;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataNamespaceDublinCore;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataNamespaceIPTCCore;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataNamespaceIPTCExtension;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataNamespacePhotoshop;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataNamespaceTIFF;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataNamespaceXMPBasic;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataNamespaceXMPRights;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataPrefixExif;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataPrefixExifAux;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataPrefixExifEX;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataPrefixDublinCore;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataPrefixIPTCCore;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataPrefixIPTCExtension;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataPrefixPhotoshop;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataPrefixTIFF;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataPrefixXMPBasic;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataPrefixXMPRights;

typedef CF_ENUM(int32_t, CGImageMetadataType) {
    kCGImageMetadataTypeInvalid = -1, kCGImageMetadataTypeDefault = 0, kCGImageMetadataTypeString = 1,
    kCGImageMetadataTypeArrayUnordered = 2, kCGImageMetadataTypeArrayOrdered = 3, kCGImageMetadataTypeAlternateArray = 4,
    kCGImageMetadataTypeAlternateText = 5, kCGImageMetadataTypeStructure = 6
};
IMAGEIO_EXTERN const CFStringRef kCFErrorDomainCGImageMetadata;
typedef CF_ENUM(int32_t, CGImageMetadataErrors) {
    kCGImageMetadataErrorUnknown = 0, kCGImageMetadataErrorUnsupportedFormat = 1, kCGImageMetadataErrorBadArgument = 2,
    kCGImageMetadataErrorConflictingArguments = 3, kCGImageMetadataErrorPrefixConflict = 4
};
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataEnumerateRecursively;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataShouldExcludeXMP;
IMAGEIO_EXTERN const CFStringRef kCGImageMetadataShouldExcludeGPS;

IMAGEIO_EXTERN CFTypeID CGImageMetadataGetTypeID(void);
IMAGEIO_EXTERN CGMutableImageMetadataRef CGImageMetadataCreateMutable(void) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGMutableImageMetadataRef _Nullable CGImageMetadataCreateMutableCopy(CGImageMetadataRef metadata) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CFTypeID CGImageMetadataTagGetTypeID(void);
/* value: a CFString, CFNumber or CFBoolean (stored as a string), a CFArray (of values or tags) or a CFDictionary (of
 * fields to values or tags) */
IMAGEIO_EXTERN CGImageMetadataTagRef _Nullable CGImageMetadataTagCreate(CFStringRef xmlns, CFStringRef _Nullable prefix, CFStringRef name,
                                                                        CGImageMetadataType type, CFTypeRef value) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CFStringRef _Nullable CGImageMetadataTagCopyNamespace(CGImageMetadataTagRef tag) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CFStringRef _Nullable CGImageMetadataTagCopyPrefix(CGImageMetadataTagRef tag) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CFStringRef _Nullable CGImageMetadataTagCopyName(CGImageMetadataTagRef tag) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CFTypeRef _Nullable CGImageMetadataTagCopyValue(CGImageMetadataTagRef tag) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageMetadataType CGImageMetadataTagGetType(CGImageMetadataTagRef tag);
IMAGEIO_EXTERN CFArrayRef _Nullable CGImageMetadataTagCopyQualifiers(CGImageMetadataTagRef tag) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CFArrayRef _Nullable CGImageMetadataCopyTags(CGImageMetadataRef metadata) CF_RETURNS_RETAINED;
/* paths: "prefix:name", a structure's field "prefix:name.prefix:field", an array's item "prefix:name[0]" */
IMAGEIO_EXTERN CGImageMetadataTagRef _Nullable CGImageMetadataCopyTagWithPath(CGImageMetadataRef metadata, CGImageMetadataTagRef _Nullable parent,
                                                                             CFStringRef path) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CFStringRef _Nullable CGImageMetadataCopyStringValueWithPath(CGImageMetadataRef metadata, CGImageMetadataTagRef _Nullable parent,
                                                                           CFStringRef path) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN bool CGImageMetadataRegisterNamespaceForPrefix(CGMutableImageMetadataRef metadata, CFStringRef xmlns, CFStringRef prefix,
                                                             CFErrorRef _Nullable *_Nullable err);
IMAGEIO_EXTERN bool CGImageMetadataSetTagWithPath(CGMutableImageMetadataRef metadata, CGImageMetadataTagRef _Nullable parent, CFStringRef path,
                                                  CGImageMetadataTagRef tag);
IMAGEIO_EXTERN bool CGImageMetadataSetValueWithPath(CGMutableImageMetadataRef metadata, CGImageMetadataTagRef _Nullable parent, CFStringRef path,
                                                    CFTypeRef value);
IMAGEIO_EXTERN bool CGImageMetadataRemoveTagWithPath(CGMutableImageMetadataRef metadata, CGImageMetadataTagRef _Nullable parent, CFStringRef path);
typedef bool (^CGImageMetadataTagBlock)(CFStringRef path, CGImageMetadataTagRef tag);
IMAGEIO_EXTERN void CGImageMetadataEnumerateTagsUsingBlock(CGImageMetadataRef metadata, CFStringRef _Nullable rootPath,
                                                          CFDictionaryRef _Nullable options, CGImageMetadataTagBlock block);
IMAGEIO_EXTERN CGImageMetadataTagRef _Nullable CGImageMetadataCopyTagMatchingImageProperty(CGImageMetadataRef metadata, CFStringRef dictionaryName,
                                                                                          CFStringRef propertyName) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN bool CGImageMetadataSetValueMatchingImageProperty(CGMutableImageMetadataRef metadata, CFStringRef dictionaryName,
                                                                 CFStringRef propertyName, CFTypeRef value);
IMAGEIO_EXTERN CFDataRef _Nullable CGImageMetadataCreateXMPData(CGImageMetadataRef metadata, CFDictionaryRef _Nullable options) CF_RETURNS_RETAINED;
IMAGEIO_EXTERN CGImageMetadataRef _Nullable CGImageMetadataCreateFromXMPData(CFDataRef data) CF_RETURNS_RETAINED;
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
