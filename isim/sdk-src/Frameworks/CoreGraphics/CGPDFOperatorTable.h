#pragma once
#include <CoreGraphics/CGPDFObject.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef struct CGPDFScanner *CGPDFScannerRef;
typedef struct CGPDFOperatorTable *CGPDFOperatorTableRef;
typedef void (*CGPDFOperatorCallback)(CGPDFScannerRef scanner, void *_Nullable info);
CG_EXTERN CGPDFOperatorTableRef _Nullable CGPDFOperatorTableCreate(void);
CG_EXTERN CGPDFOperatorTableRef _Nullable CGPDFOperatorTableRetain(CGPDFOperatorTableRef _Nullable table);
CG_EXTERN void CGPDFOperatorTableRelease(CGPDFOperatorTableRef _Nullable table);
CG_EXTERN void CGPDFOperatorTableSetCallback(CGPDFOperatorTableRef _Nullable table, const char *name, CGPDFOperatorCallback _Nullable callback);
#pragma clang assume_nonnull end
__END_DECLS
