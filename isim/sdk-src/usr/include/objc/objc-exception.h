#pragma once
/* isim: Objective-C exception runtime entry points (implemented in isim's libobjc, runtime/objc_exc.c) */
#include <objc/objc.h>
__BEGIN_DECLS
OBJC_EXPORT void objc_exception_throw(id _Nonnull exception) __attribute__((noreturn));
OBJC_EXPORT void objc_exception_rethrow(void) __attribute__((noreturn));
OBJC_EXPORT id _Nonnull objc_begin_catch(void * _Nonnull exc_buf);
OBJC_EXPORT void objc_end_catch(void);
OBJC_EXPORT void objc_terminate(void) __attribute__((noreturn));
typedef id _Nonnull (*objc_exception_preprocessor)(id _Nonnull exception);
typedef void (*objc_uncaught_exception_handler)(id _Null_unspecified exception);
OBJC_EXPORT objc_exception_preprocessor _Nonnull objc_setExceptionPreprocessor(objc_exception_preprocessor _Nonnull fn);
OBJC_EXPORT objc_uncaught_exception_handler _Nonnull objc_setUncaughtExceptionHandler(objc_uncaught_exception_handler _Nonnull fn);
__END_DECLS
