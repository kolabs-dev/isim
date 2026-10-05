/* isim runtime: internal interfaces between loader, host libraries and ObjC runtime. */
#pragma once
#include <stddef.h>
#include <stdint.h>

/* Status labels for every host-provided symbol (see docs/compatibility-matrix.md):
 *   "passthrough" host glibc function; ABI-identical for its signature on x86_64
 *   "adapted"     wrapper translating Darwin layout/semantics/constants
 *   "isim"        isim-specific implementation (ObjC runtime, host graphics bridge)
 *   "stub"        placeholder that does NOT implement Darwin behaviour */
struct shim { const char *name; void *addr; const char *status; };

/* host pseudo-libraries: install name -> symbol table */
struct host_lib { const char *install_name; const struct shim *table; size_t count; };
extern const struct host_lib host_libsystem, host_libobjc, host_isim;
const struct shim *host_lib_lookup(const struct host_lib *lib, const char *name);

/* loader services */
void *isim_lookup_symbol(const char *mangled_name); /* flat lookup over images + host libs */
const char *isim_main_executable_path(void);
void isim_fatal(const char *fmt, ...) __attribute__((noreturn, format(printf, 1, 2)));
extern int isim_verbose;

/* ObjC runtime hooks (objc_rt.c) */
struct objc_image {
    const char *name;
    void *(*find_section)(const struct objc_image *img, const char *sectname, uint64_t *size);
    void *ctx;
};
void objc_rt_map_image(const struct objc_image *img);   /* after fixups, before mprotect */
void objc_rt_load_image(const struct objc_image *img);  /* +load methods, after all images mapped */

void libsystem_init(int argc, char **argv);
