// isim support code linked into libswiftTesting.dylib (self-authored).
//
// swift-testing's Darwin test discovery (_TestDiscovery/SectionBounds.swift) registers for loaded Mach-O images with
// objc_addLoadImageFunc() (Swift on Apple platforms has ObjC interop). isim's ObjC runtime declares it in its SDK
// header but does not export it, so it is provided here, privately (hidden: it doesn't leak out of the dylib), on top
// of dyld's add-image callback, which isim's loader implements: the callback runs for every image already loaded and
// for every image loaded later with dlopen() (e.g. an .xctest bundle), like objc_addLoadImageFunc does on Darwin.
#include <stddef.h>   /* before <mach-o/dyld.h>, which uses size_t */
#include <mach-o/dyld.h>
#include <stdint.h>

typedef void (*isim_objc_func_loadImage)(const struct mach_header *header);

#define MAX_FUNCS 8
static isim_objc_func_loadImage funcs[MAX_FUNCS];
static int nfuncs;

static void trampoline(int i, const struct mach_header *mh) { if (i < nfuncs && funcs[i]) funcs[i](mh); }
#define T(i) static void cb##i(const struct mach_header *mh, intptr_t slide) { (void)slide; trampoline(i, mh); }
T(0) T(1) T(2) T(3) T(4) T(5) T(6) T(7)
static void (*const cbs[MAX_FUNCS])(const struct mach_header *, intptr_t) = { cb0, cb1, cb2, cb3, cb4, cb5, cb6, cb7 };

__attribute__((visibility("hidden"))) void objc_addLoadImageFunc(isim_objc_func_loadImage func) {
    if (!func || nfuncs >= MAX_FUNCS) return;
    int i = nfuncs;
    funcs[i] = func;
    nfuncs = i + 1;
    _dyld_register_func_for_add_image(cbs[i]);
}

// <execinfo.h> backtrace()/backtrace_async(), used by Testing.Backtrace (where an issue/error was recorded). isim's
// libSystem has neither; Darwin x86_64 code always keeps frame pointers, so walk the frame-pointer chain (as isim's
// crash reporter does). Swift async frames mark their frame pointer with bit 60; the walk stops there.
static size_t walk_frames(void **array, size_t length) {
    uintptr_t fp = (uintptr_t)__builtin_frame_address(0);
    size_t n = 0;
    while (n < length && fp && !(fp & 7) && fp < ((uintptr_t)1 << 47)) {
        uintptr_t next = ((uintptr_t *)fp)[0], ret = ((uintptr_t *)fp)[1];
        if (!ret) break;
        array[n++] = (void *)ret;
        if (next <= fp || next - fp > ((uintptr_t)64 << 20)) break;
        fp = next;
    }
    return n;
}
__attribute__((visibility("hidden"), noinline)) int backtrace(void **array, int size) {
    return size > 0 ? (int)walk_frames(array, (size_t)size) : 0;
}
__attribute__((visibility("hidden"), noinline)) size_t backtrace_async(void **array, size_t length, uint32_t *task_id) {
    if (task_id) *task_id = 0;
    return walk_frames(array, length);
}
