/* isim /usr/lib/libsqlite3.dylib: the SQLite C API, forwarded to the host's libsqlite3.so.0.
 *
 * SQLite's API only passes pointers, integers, doubles and C callbacks, so the x86-64 SysV calling
 * convention is shared and every function maps directly to the host's (no wrappers). The host library
 * is dlopen'ed on the first symbol lookup, so isim runs without it; then (or for functions the host's
 * older SQLite lacks) calls stop the app with a message naming the function.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include "runtime.h"

static void sqlite_missing(void);
#define F(n) { "_" #n, (void *)sqlite_missing, "passthrough" },
#define D(n) { "_" #n, NULL, "passthrough" },
static struct shim sqlite_table[] = {
#include "host_sqlite_names.h"
};
#undef F
#undef D

static int loaded;
static void sqlite_missing(void) {
    fflush(NULL);
    fprintf(stderr, "isim: FATAL: the app called a SQLite function that the host's libsqlite3.so.0 does not provide%s\n",
            loaded > 0 ? " (older SQLite version)" : " (libsqlite3.so.0 not found: install SQLite)");
    abort();
}
void host_sqlite_load(void) {
    if (loaded) return;
    loaded = -1;
    void *h = dlopen("libsqlite3.so.0", RTLD_NOW | RTLD_GLOBAL);
    if (!h) h = dlopen("libsqlite3.so", RTLD_NOW | RTLD_GLOBAL);
    if (!h) return;
    loaded = 1;
    for (size_t i = 0; i < sizeof sqlite_table / sizeof *sqlite_table; i++) {
        void *p = dlsym(h, sqlite_table[i].name + 1);
        if (p) sqlite_table[i].addr = p;
    }
}
const struct host_lib host_sqlite = { "/usr/lib/libsqlite3.dylib", sqlite_table, sizeof sqlite_table / sizeof *sqlite_table };
