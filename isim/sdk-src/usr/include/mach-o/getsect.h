#pragma once
#include <_isim_cdefs.h>
#include <stdint.h>
#include <mach-o/loader.h>
__BEGIN_DECLS
uint8_t *getsectiondata(const struct mach_header_64 *mhp, const char *segname, const char *sectname, unsigned long *size);
__END_DECLS
