#pragma once
#include <CoreGraphics/CGPDFArray.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
CG_EXTERN size_t CGPDFDictionaryGetCount(CGPDFDictionaryRef _Nullable dict);
CG_EXTERN bool CGPDFDictionaryGetObject(CGPDFDictionaryRef _Nullable dict, const char *key, CGPDFObjectRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFDictionaryGetBoolean(CGPDFDictionaryRef _Nullable dict, const char *key, CGPDFBoolean *_Nullable value);
CG_EXTERN bool CGPDFDictionaryGetInteger(CGPDFDictionaryRef _Nullable dict, const char *key, CGPDFInteger *_Nullable value);
CG_EXTERN bool CGPDFDictionaryGetNumber(CGPDFDictionaryRef _Nullable dict, const char *key, CGPDFReal *_Nullable value);
CG_EXTERN bool CGPDFDictionaryGetName(CGPDFDictionaryRef _Nullable dict, const char *key, const char *_Nullable *_Nullable value);
CG_EXTERN bool CGPDFDictionaryGetString(CGPDFDictionaryRef _Nullable dict, const char *key, CGPDFStringRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFDictionaryGetArray(CGPDFDictionaryRef _Nullable dict, const char *key, CGPDFArrayRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFDictionaryGetDictionary(CGPDFDictionaryRef _Nullable dict, const char *key, CGPDFDictionaryRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFDictionaryGetStream(CGPDFDictionaryRef _Nullable dict, const char *key, CGPDFStreamRef _Nullable *_Nullable value);
typedef void (*CGPDFDictionaryApplierFunction)(const char *key, CGPDFObjectRef value, void *_Nullable info);
CG_EXTERN void CGPDFDictionaryApplyFunction(CGPDFDictionaryRef _Nullable dict, CGPDFDictionaryApplierFunction _Nullable function, void *_Nullable info);
typedef bool (^CGPDFDictionaryApplierBlock)(const char *key, CGPDFObjectRef value, void *_Nullable info);
CG_EXTERN void CGPDFDictionaryApplyBlock(CGPDFDictionaryRef _Nullable dict, CGPDFDictionaryApplierBlock _Nullable block, void *_Nullable info);
#pragma clang assume_nonnull end
__END_DECLS
