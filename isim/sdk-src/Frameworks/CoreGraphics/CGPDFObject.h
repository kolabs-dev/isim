#pragma once
#include <CoreGraphics/CGBase.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
/* isim: the PDF object model is isim's own parser (adapted); objects live as long as their document */
typedef bool CGPDFBoolean;
typedef long CGPDFInteger;
typedef CGFloat CGPDFReal;
typedef struct CGPDFObject *CGPDFObjectRef;
typedef CF_ENUM(int32_t, CGPDFObjectType) {
    kCGPDFObjectTypeNull = 1, kCGPDFObjectTypeBoolean, kCGPDFObjectTypeInteger, kCGPDFObjectTypeReal, kCGPDFObjectTypeName,
    kCGPDFObjectTypeString, kCGPDFObjectTypeArray, kCGPDFObjectTypeDictionary, kCGPDFObjectTypeStream
};
CG_EXTERN CGPDFObjectType CGPDFObjectGetType(CGPDFObjectRef object);
/* integers are also returned as reals */
CG_EXTERN bool CGPDFObjectGetValue(CGPDFObjectRef object, CGPDFObjectType type, void *_Nullable value);
#pragma clang assume_nonnull end
__END_DECLS
