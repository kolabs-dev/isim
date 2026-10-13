/* isim JavaScriptCore C API (/usr/lib/libisim_jsc.dylib, re-exported by JavaScriptCore.framework): forwarded to the
 * host's JavaScriptCore, the same engine and C API as Apple's (WebKitGTK's libjavascriptcoregtk-6.0 or -4.1).
 *
 * The C API passes pointers, integers, doubles and C callbacks, and its structures (JSClassDefinition,
 * JSStaticValue, JSStaticFunction) have the same layout, so every function maps to the host's (passthrough). The
 * library is dlopen'ed on the first symbol lookup, so isim runs without it; then a call stops the app with a message.
 * JavaScriptCore.framework builds the Objective-C API (JSContext, JSValue...) on top (frameworks/JavaScriptCore). */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include "runtime.h"

static void jsc_missing(void);
#define F(n) { "_" #n, (void *)jsc_missing, "passthrough" },
#define D(n) { "_" #n, NULL, "passthrough" },
static struct shim jsc_table[] = {
#include "host_jsc_names.h"
};
#undef F
#undef D

static int loaded;
static void jsc_missing(void) {
    fflush(NULL);
    fprintf(stderr, "isim: FATAL: the app called a JavaScriptCore function that %s\n",
            loaded > 0 ? "the host's JavaScriptCore does not provide (older WebKitGTK)"
                       : "needs the host's JavaScriptCore (libjavascriptcoregtk-6.0 or -4.1: install WebKitGTK)");
    abort();
}
static void jsc_load(void) {
    if (loaded) return;
    loaded = -1;
    void *h = dlopen("libjavascriptcoregtk-6.0.so.1", RTLD_NOW | RTLD_GLOBAL);
    if (!h) h = dlopen("libjavascriptcoregtk-4.1.so.0", RTLD_NOW | RTLD_GLOBAL);
    if (!h) return;
    loaded = 1;
    for (size_t i = 0; i < sizeof jsc_table / sizeof *jsc_table; i++) {
        void *p = dlsym(h, jsc_table[i].name + 1);
        if (p) jsc_table[i].addr = p;
    }
}
const struct host_lib host_jsc = { "/usr/lib/libisim_jsc.dylib", jsc_table, sizeof jsc_table / sizeof *jsc_table, jsc_load };
