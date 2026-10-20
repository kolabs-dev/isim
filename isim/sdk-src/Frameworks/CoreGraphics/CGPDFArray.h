#pragma once
#include <CoreGraphics/CGPDFObject.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef struct CGPDFArray *CGPDFArrayRef;
typedef struct CGPDFDictionary *CGPDFDictionaryRef;
typedef struct CGPDFStream *CGPDFStreamRef;
typedef struct CGPDFString *CGPDFStringRef;
CG_EXTERN size_t CGPDFArrayGetCount(CGPDFArrayRef _Nullable array);
CG_EXTERN bool CGPDFArrayGetObject(CGPDFArrayRef _Nullable array, size_t index, CGPDFObjectRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFArrayGetNull(CGPDFArrayRef _Nullable array, size_t index);
CG_EXTERN bool CGPDFArrayGetBoolean(CGPDFArrayRef _Nullable array, size_t index, CGPDFBoolean *_Nullable value);
CG_EXTERN bool CGPDFArrayGetInteger(CGPDFArrayRef _Nullable array, size_t index, CGPDFInteger *_Nullable value);
CG_EXTERN bool CGPDFArrayGetNumber(CGPDFArrayRef _Nullable array, size_t index, CGPDFReal *_Nullable value);
CG_EXTERN bool CGPDFArrayGetName(CGPDFArrayRef _Nullable array, size_t index, const char *_Nullable *_Nullable value);
CG_EXTERN bool CGPDFArrayGetString(CGPDFArrayRef _Nullable array, size_t index, CGPDFStringRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFArrayGetArray(CGPDFArrayRef _Nullable array, size_t index, CGPDFArrayRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFArrayGetDictionary(CGPDFArrayRef _Nullable array, size_t index, CGPDFDictionaryRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFArrayGetStream(CGPDFArrayRef _Nullable array, size_t index, CGPDFStreamRef _Nullable *_Nullable value);
typedef bool (^CGPDFArrayApplierBlock)(size_t index, CGPDFObjectRef value, void *_Nullable info);
CG_EXTERN void CGPDFArrayApplyBlock(CGPDFArrayRef _Nullable array, CGPDFArrayApplierBlock _Nullable block, void *_Nullable info);
#pragma clang assume_nonnull end
__END_DECLS
