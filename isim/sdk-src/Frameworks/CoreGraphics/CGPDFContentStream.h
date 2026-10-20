#pragma once
#include <CoreGraphics/CGPDFStream.h>
#include <CoreFoundation/CFArray.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef struct CGPDFContentStream *CGPDFContentStreamRef;
typedef struct CGPDFPage *CGPDFPageRef;
CG_EXTERN CGPDFContentStreamRef CGPDFContentStreamCreateWithPage(CGPDFPageRef page);
CG_EXTERN CGPDFContentStreamRef CGPDFContentStreamCreateWithStream(CGPDFStreamRef stream, CGPDFDictionaryRef streamResources,
    CGPDFContentStreamRef _Nullable parent);
CG_EXTERN CGPDFContentStreamRef CGPDFContentStreamRetain(CGPDFContentStreamRef cs);
CG_EXTERN void CGPDFContentStreamRelease(CGPDFContentStreamRef cs);
/* the content streams (CGPDFStreamRef values, not retained) */
CG_EXTERN CFArrayRef _Nullable CGPDFContentStreamGetStreams(CGPDFContentStreamRef cs);
/* a resource of a category (Font, XObject, ExtGState...), looked up in the parent streams too */
CG_EXTERN CGPDFObjectRef _Nullable CGPDFContentStreamGetResource(CGPDFContentStreamRef cs, const char *category, const char *name);
#pragma clang assume_nonnull end
__END_DECLS
