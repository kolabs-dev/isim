#pragma once
#include <CoreText/CTFont.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
typedef const struct __attribute__((objc_bridge(id))) __CTTextTab *CTTextTabRef;
typedef CF_ENUM(uint8_t, CTTextAlignment) { kCTTextAlignmentLeft = 0, kCTTextAlignmentRight = 1, kCTTextAlignmentCenter = 2, kCTTextAlignmentJustified = 3, kCTTextAlignmentNatural = 4 };
/* the character set (a CFCharacterSet) a decimal tab aligns on; a tab with it aligns its column on '.' */
CT_EXPORT const CFStringRef kCTTabColumnTerminatorsAttributeName;
CT_EXPORT CFTypeID CTTextTabGetTypeID(void);
CT_EXPORT CTTextTabRef CTTextTabCreate(CTTextAlignment alignment, double location, CFDictionaryRef _Nullable options);
CT_EXPORT CTTextAlignment CTTextTabGetAlignment(CTTextTabRef tab);
CT_EXPORT double CTTextTabGetLocation(CTTextTabRef tab);
CT_EXPORT CFDictionaryRef _Nullable CTTextTabGetOptions(CTTextTabRef tab);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
