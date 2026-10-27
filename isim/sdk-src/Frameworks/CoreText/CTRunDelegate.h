#pragma once
#include <CoreText/CTRun.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
/* isim: each character the kCTRunDelegateAttributeName attribute covers takes the delegate's width, ascent and
 * descent (a Pango shape) and draws nothing; lines and frames make room for it */
typedef const struct __attribute__((objc_bridge(id))) __CTRunDelegate *CTRunDelegateRef;
CT_EXPORT CFTypeID CTRunDelegateGetTypeID(void);
typedef void (*CTRunDelegateDeallocateCallback)(void *refCon);
typedef CGFloat (*CTRunDelegateGetAscentCallback)(void *refCon);
typedef CGFloat (*CTRunDelegateGetDescentCallback)(void *refCon);
typedef CGFloat (*CTRunDelegateGetWidthCallback)(void *refCon);
typedef struct {
    CFIndex version;
    CTRunDelegateDeallocateCallback dealloc;
    CTRunDelegateGetAscentCallback getAscent;
    CTRunDelegateGetDescentCallback getDescent;
    CTRunDelegateGetWidthCallback getWidth;
} CTRunDelegateCallbacks;
enum { kCTRunDelegateVersion1 = 1, kCTRunDelegateCurrentVersion = kCTRunDelegateVersion1 };
CT_EXPORT CTRunDelegateRef _Nullable CTRunDelegateCreate(const CTRunDelegateCallbacks *callbacks, void *_Nullable refCon) CF_RETURNS_RETAINED;
CT_EXPORT void *CTRunDelegateGetRefCon(CTRunDelegateRef runDelegate);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
