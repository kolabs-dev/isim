/* isim host: Metal on the CPU (issue #328), compiling Metal Shading Language for a guest at run time
 * (MTLDevice newLibraryWithSource:, frameworks/Metal). Runs isim's MSL compiler, bin/mslc.py next to the runtime,
 * which translates the source to C++ and builds a guest dylib with the toolchain's clang (isim cc). Without python3
 * or clang on the host the compile fails with the reason, as a compile error. */
#define _GNU_SOURCE
#include "guest_abi.h"
#include "platform.h"
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

ISIM_GUEST_ABI int isim_metal_compile(const char *source, const char *out, const char *const *flags, int nflags, char *err, long errlen);

/* source (a .metal file) -> out (a guest dylib); flags: mslc options (-I dir, -DNAME=VALUE, -O0); 0 on success, else -1
 * with the compiler's messages in err */
ISIM_GUEST_ABI int isim_metal_compile(const char *source, const char *out, const char *const *flags, int nflags, char *err, long errlen) {
    if (err && errlen > 0) err[0] = 0;
    char self[PATH_MAX], mslc[PATH_MAX + 16];
    int n = isim_self_path(self, sizeof self);
    char *slash = n > 0 ? strrchr(self, '/') : NULL;
    if (!slash) { if (err) snprintf(err, errlen, "isim's Metal compiler was not found"); return -1; }
    *slash = 0;
    snprintf(mslc, sizeof mslc, "%s/mslc.py", self);
    if (access(mslc, R_OK) != 0) { if (err) snprintf(err, errlen, "isim's Metal compiler (%s) is not installed", mslc); return -1; }
    char errpath[] = "/tmp/isim-mslc-XXXXXX";
    int efd = mkstemp(errpath);
    if (efd < 0) { if (err) snprintf(err, errlen, "cannot create a temporary file: %s", strerror(errno)); return -1; }
    unlink(errpath);
    char **argv = calloc((size_t)nflags + 8, sizeof *argv);
    int k = 0;
    argv[k++] = "python3"; argv[k++] = mslc; argv[k++] = "-o"; argv[k++] = (char *)out;
    for (int i = 0; i < nflags; i++) argv[k++] = (char *)flags[i];
    argv[k++] = (char *)source;
    argv[k] = NULL;
    struct isim_spawn s = { .path = "python3", .argv = argv, .null_stdin = 1, .null_stdout = 1, .remap_from = efd, .remap_to = 2 };
    pid_t pid = isim_spawn(&s);
    free(argv);
    if (pid < 0) {
        if (err) snprintf(err, errlen, "compiling Metal needs python3 on the host: %s", strerror(errno));
        close(efd);
        return -1;
    }
    int st = 0;
    while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
    if (err && errlen > 1) {
        ssize_t got = pread(efd, err, (size_t)errlen - 1, 0);
        err[got > 0 ? got : 0] = 0;
    }
    close(efd);
    return WIFEXITED(st) && WEXITSTATUS(st) == 0 ? 0 : -1;
}
