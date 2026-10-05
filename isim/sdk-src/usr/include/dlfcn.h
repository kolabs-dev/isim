#pragma once
/* isim: dlsym/dladdr operate on the images loaded by isim-runtime; dlopen of new images is not supported. */
#include <_isim_cdefs.h>
__BEGIN_DECLS
typedef struct dl_info { const char *dli_fname; void *dli_fbase; const char *dli_sname; void *dli_saddr; } Dl_info;
#define RTLD_LAZY 0x1
#define RTLD_NOW 0x2
#define RTLD_LOCAL 0x4
#define RTLD_GLOBAL 0x8
#define RTLD_NOLOAD 0x10
#define RTLD_FIRST 0x100
#define RTLD_NEXT ((void *)-1)
#define RTLD_DEFAULT ((void *)-2)
#define RTLD_SELF ((void *)-3)
#define RTLD_MAIN_ONLY ((void *)-5)
void *dlopen(const char *path, int mode);
int dlclose(void *handle);
void *dlsym(void *handle, const char *symbol);
int dladdr(const void *addr, Dl_info *info);
char *dlerror(void);
__END_DECLS
