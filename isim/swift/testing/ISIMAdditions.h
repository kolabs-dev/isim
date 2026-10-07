// isim additions to swift-testing's _TestingInternals C module (self-authored).
// build-testing.sh copies this header into the build copy of _TestingInternals/include; the module map there is an
// umbrella directory, so Swift sees these macros/declarations next to upstream's own headers.
// It supplies the few Darwin SDK definitions swift-testing uses that isim's self-authored SDK does not have.
#if !defined(SWT_ISIM_ADDITIONS_H)
#define SWT_ISIM_ADDITIONS_H

#include "Defines.h"
#include "Includes.h"

#if defined(__APPLE__) && !SWT_NO_DYNAMIC_LINKING
#include <mach-o/getsect.h>         /* getsectiondata(): Darwin's <mach-o/dyld.h> gets it from here too */
#endif

SWT_ASSUME_NONNULL_BEGIN

#if !defined(MH_DYLIB_IN_CACHE)
#define MH_DYLIB_IN_CACHE 0x80000000   /* <mach-o/loader.h>: image is in the dyld shared cache (never on isim) */
#endif
#if !defined(EX_UNAVAILABLE)
#define EX_UNAVAILABLE 69              /* <sysexits.h>: exit code swift-testing uses for "no tests found" */
#endif
#if !defined(PATH_MAX)
#define PATH_MAX 1024                  /* <sys/syslimits.h> */
#endif

/* <crt_externs.h> (exported by isim's libSystem) */
#if !__has_include(<crt_externs.h>)
SWT_EXTERN char *_Nullable *_Nullable *_Null_unspecified _NSGetEnviron(void);
#endif

/* <sys/stat.h>: Stubs.h only defines swt_S_ISFIFO when S_ISFIFO exists, which isim's header lacks */
#if !defined(S_ISFIFO) && defined(S_IFIFO)
static inline bool swt_S_ISFIFO(mode_t mode) { return (mode & S_IFMT) == S_IFIFO; }
#endif

/* <execinfo.h>: frame-pointer backtraces, implemented in isim-testing-support.c */
#if !__has_include(<execinfo.h>)
SWT_EXTERN int backtrace(void *_Nullable *_Nonnull array, int size);
SWT_EXTERN size_t backtrace_async(void *_Nullable *_Nonnull array, size_t length, uint32_t *_Nullable task_id);
#endif

SWT_ASSUME_NONNULL_END

#endif
