#pragma once
#include <CoreGraphics/CGPDFContentStream.h>
#include <CoreGraphics/CGPDFOperatorTable.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
CG_EXTERN CGPDFScannerRef CGPDFScannerCreate(CGPDFContentStreamRef cs, CGPDFOperatorTableRef _Nullable table, void *_Nullable info);
CG_EXTERN CGPDFScannerRef _Nullable CGPDFScannerRetain(CGPDFScannerRef _Nullable scanner);
CG_EXTERN void CGPDFScannerRelease(CGPDFScannerRef _Nullable scanner);
/* runs the operators' callbacks; false if the content could not be parsed */
CG_EXTERN bool CGPDFScannerScan(CGPDFScannerRef _Nullable scanner);
CG_EXTERN CGPDFContentStreamRef CGPDFScannerGetContentStream(CGPDFScannerRef scanner);
CG_EXTERN bool CGPDFScannerPopObject(CGPDFScannerRef scanner, CGPDFObjectRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFScannerPopBoolean(CGPDFScannerRef scanner, CGPDFBoolean *_Nullable value);
CG_EXTERN bool CGPDFScannerPopInteger(CGPDFScannerRef scanner, CGPDFInteger *_Nullable value);
CG_EXTERN bool CGPDFScannerPopNumber(CGPDFScannerRef scanner, CGPDFReal *_Nullable value);
CG_EXTERN bool CGPDFScannerPopName(CGPDFScannerRef scanner, const char *_Nullable *_Nullable value);
CG_EXTERN bool CGPDFScannerPopString(CGPDFScannerRef scanner, CGPDFStringRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFScannerPopArray(CGPDFScannerRef scanner, CGPDFArrayRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFScannerPopDictionary(CGPDFScannerRef scanner, CGPDFDictionaryRef _Nullable *_Nullable value);
CG_EXTERN bool CGPDFScannerPopStream(CGPDFScannerRef scanner, CGPDFStreamRef _Nullable *_Nullable value);
/* iOS 16: stops the scan after the current callback */
CG_EXTERN void CGPDFScannerStop(CGPDFScannerRef s);
#pragma clang assume_nonnull end
__END_DECLS
