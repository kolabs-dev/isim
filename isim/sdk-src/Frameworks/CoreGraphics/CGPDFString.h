#pragma once
#include <CoreGraphics/CGPDFObject.h>
#include <CoreFoundation/CFDate.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef struct CGPDFString *CGPDFStringRef;
CG_EXTERN size_t CGPDFStringGetLength(CGPDFStringRef _Nullable string);
CG_EXTERN const unsigned char *_Nullable CGPDFStringGetBytePtr(CGPDFStringRef _Nullable string);
/* text strings: UTF-16BE (with its byte order mark), UTF-8 (PDF 2.0) or PDFDocEncoding */
CG_EXTERN CFStringRef _Nullable CGPDFStringCopyTextString(CGPDFStringRef _Nullable string) CF_RETURNS_RETAINED;
/* dates: "D:YYYYMMDDHHmmSSOHH'mm'" */
CG_EXTERN CFDateRef _Nullable CGPDFStringCopyDate(CGPDFStringRef _Nullable string) CF_RETURNS_RETAINED;
#pragma clang assume_nonnull end
__END_DECLS
