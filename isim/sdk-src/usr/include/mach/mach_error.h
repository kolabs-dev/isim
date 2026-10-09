#pragma once
/* isim SDK (self-authored): Mach error strings. */
#include <mach/error.h>
#include <_isim_cdefs.h>
__BEGIN_DECLS
char *mach_error_string(mach_error_t error_value);
void mach_error(const char *str, mach_error_t error_value);
char *mach_error_type(mach_error_t error_value);
__END_DECLS
