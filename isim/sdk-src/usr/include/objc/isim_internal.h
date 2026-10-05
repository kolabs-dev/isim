#pragma once
/* isim runtime private entry points used by the isim Foundation implementation. */
#include <objc/runtime.h>
__BEGIN_DECLS
id _Nullable _objc_rootRetain(id _Nullable);
void _objc_rootRelease(id _Nullable);
BOOL _objc_rootReleaseWasZero(id _Nonnull);
unsigned long _objc_rootRetainCount(id _Nonnull);
id _Nullable _objc_rootAutorelease(id _Nullable);
BOOL _objc_rootIsDeallocating(id _Nonnull);
void * _Nonnull objc_autoreleasePoolPush(void);
void objc_autoreleasePoolPop(void * _Nonnull);
__attribute__((noreturn)) void objc_exception_throw(id _Nonnull);
__END_DECLS
