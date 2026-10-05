#pragma once
/* status: "passthrough" = host glibc function, ABI-identical for the used signature
 *         "adapted"     = wrapper translating Darwin layout/semantics to Linux
 *         "stub"        = placeholder; does NOT implement Darwin behaviour */
struct shim { const char *name; void *addr; const char *status; };
const struct shim *shim_lookup(const char *mangled_name);
void shims_init(const char *guest_path);

/* objc_rt.c: minimal Objective-C runtime reading Apple ObjC2 ABI metadata */
#include <stdint.h>
typedef void *(*section_finder)(const char *sectname, uint64_t *size);
void objc_rt_register_image(section_finder find, int verbose);
const struct shim *objc_rt_shim_lookup(const char *mangled_name);
