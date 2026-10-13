/* isim's Core Image kernel interpreter (CIKernelLang.c): the Core Image Kernel Language and Metal Core Image kernels. */
#pragma once
#include <stddef.h>

enum { CK_VOID, CK_FLOAT, CK_INT, CK_BOOL, CK_MAT, CK_SAMPLER, CK_SAMPLE, CK_COLOR, CK_DEST };
typedef struct ck_program ck_program;
typedef struct ck_func ck_func;
/* an argument: numbers (n values) or a sampler index */
typedef struct { int n; float v[16]; int sampler; } ck_arg;
/* the host: destination coordinate of the current pixel, and the samplers */
typedef struct ck_host ck_host;
struct ck_host {
    void (*dest)(ck_host *h, double *x, double *y);
    void (*sample)(ck_host *h, int s, double x, double y, float out[4]);
    void (*transform)(ck_host *h, int s, double x, double y, double *ox, double *oy);
    void (*extent)(ck_host *h, int s, double e[4]);
    void *ctx;
};
ck_program *ck_parse(const char *src, char *err, size_t errlen);
void ck_free(ck_program *p);
int ck_count(const ck_program *p);
ck_func *ck_func_at(const ck_program *p, int i);
ck_func *ck_find(const ck_program *p, const char *name);
const char *ck_name(const ck_func *f);
int ck_is_kernel(const ck_func *f);              /* declared with `kernel` (Core Image Kernel Language) */
int ck_ret(const ck_func *f, int *n);            /* kind and width of the return type */
int ck_nparams(const ck_func *f);
int ck_param(const ck_func *f, int i, int *n);
/* runs the function for one pixel; args line up with its parameters (destination parameters are skipped by the
   caller's numbering but still occupy their position). Returns the result's width (4: color, 2: warp position). */
int ck_run(const ck_program *p, const ck_func *f, const ck_arg *args, int nargs, ck_host *host, float out[4]);
