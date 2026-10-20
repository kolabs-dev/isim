#pragma once
#include <CoreGraphics/CGPDFDictionary.h>
#include <CoreFoundation/CFData.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef CF_ENUM(int32_t, CGPDFDataFormat) { CGPDFDataFormatRaw, CGPDFDataFormatJPEGEncoded, CGPDFDataFormatJPEG2000 };
CG_EXTERN CGPDFDictionaryRef _Nullable CGPDFStreamGetDictionary(CGPDFStreamRef _Nullable stream);
/* decoded (Flate, LZW, ASCIIHex, ASCII85, RunLength); JPEG and JPEG 2000 data comes as is, with its format */
CG_EXTERN CFDataRef _Nullable CGPDFStreamCopyData(CGPDFStreamRef _Nullable stream, CGPDFDataFormat *format) CF_RETURNS_RETAINED;
#pragma clang assume_nonnull end
__END_DECLS
