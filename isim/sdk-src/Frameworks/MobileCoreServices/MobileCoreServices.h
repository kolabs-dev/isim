#pragma once
/* isim MobileCoreServices: the deprecated UTType C functions and tag classes, over UniformTypeIdentifiers (the framework
   re-exports libswiftUniformTypeIdentifiers.dylib). Swift uses UniformTypeIdentifiers; these declarations are hidden
   from Swift. */
#include <CoreFoundation/CoreFoundation.h>
#if !defined(__swift__)
__BEGIN_DECLS
extern const CFStringRef kUTTagClassFilenameExtension, kUTTagClassMIMEType;
/* the system types (UTCoreTypes.h) */
extern const CFStringRef kUTTypeItem, kUTTypeContent, kUTTypeData, kUTTypeCompositeContent, kUTTypeText,
    kUTTypePlainText, kUTTypeUTF8PlainText, kUTTypeRTF, kUTTypeHTML, kUTTypeXML, kUTTypeJSON, kUTTypeSourceCode,
    kUTTypeURL, kUTTypeFileURL, kUTTypeImage, kUTTypePNG, kUTTypeJPEG, kUTTypeGIF, kUTTypeTIFF, kUTTypeBMP,
    kUTTypeScalableVectorGraphics, kUTTypeLivePhoto, kUTTypeAudiovisualContent, kUTTypeMovie, kUTTypeVideo,
    kUTTypeAudio, kUTTypeQuickTimeMovie, kUTTypeMPEG4, kUTTypeMPEG4Audio, kUTTypeMP3, kUTTypePDF, kUTTypeZipArchive,
    kUTTypeArchive, kUTTypeFolder, kUTTypeDirectory, kUTTypePackage, kUTTypeBundle, kUTTypeApplication,
    kUTTypeExecutable, kUTTypeVCard, kUTTypeContact, kUTTypeSpreadsheet, kUTTypePresentation, kUTTypeFont;
CFStringRef UTTypeCreatePreferredIdentifierForTag(CFStringRef inTagClass, CFStringRef inTag, CFStringRef inConformingToUTI) CF_RETURNS_RETAINED;
CFStringRef UTTypeCopyPreferredTagWithClass(CFStringRef inUTI, CFStringRef inTagClass) CF_RETURNS_RETAINED;
Boolean UTTypeConformsTo(CFStringRef inUTI, CFStringRef inConformsToUTI);
Boolean UTTypeEqual(CFStringRef inUTI1, CFStringRef inUTI2);
__END_DECLS
#endif
