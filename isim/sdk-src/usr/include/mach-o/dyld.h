#pragma once
/* isim: dyld image APIs answered by isim-runtime's loader. */
#include <_isim_cdefs.h>
#include <stdbool.h>
#include <stdint.h>
#include <mach-o/loader.h>
__BEGIN_DECLS
uint32_t _dyld_image_count(void);
const struct mach_header *_dyld_get_image_header(uint32_t image_index);
intptr_t _dyld_get_image_vmaddr_slide(uint32_t image_index);
const char *_dyld_get_image_name(uint32_t image_index);
void _dyld_register_func_for_add_image(void (*func)(const struct mach_header *mh, intptr_t vmaddr_slide));
void _dyld_register_func_for_remove_image(void (*func)(const struct mach_header *mh, intptr_t vmaddr_slide));
int _NSGetExecutablePath(char *buf, uint32_t *bufsize);
const char *dyld_image_path_containing_address(const void *addr);
bool _dyld_is_memory_immutable(const void *addr, size_t length);
__END_DECLS
