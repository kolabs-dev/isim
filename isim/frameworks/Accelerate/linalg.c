/* isim Accelerate: vecLib's BLAS (cblas.h) and LAPACK (clapack.h), adapted: isim's own implementation (no host
   library), single and double precision from one template (linalg_t.h). */
#include <Accelerate/Accelerate.h>
/* complex products and quotients inline (no compiler-rt __mulsc3 / __divdc3): the BLAS reference formulas */
#pragma STDC CX_LIMITED_RANGE ON
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* the i-th element of a BLAS vector: negative increments walk it from the end */
static inline size_t vidx(int i, int inc, int n) { return inc >= 0 ? (size_t)i * inc : (size_t)(n - 1 - i) * (size_t)(-inc); }

#define T float
#define P s
#include "linalg_t.h"
#undef T
#undef P
#define T double
#define P d
#include "linalg_t.h"
#undef T
#undef P

/* the complex BLAS (linalg_z.h) uses EL from linalg_t.h */
#define T float _Complex
#define R float
#define P c
#define RP sc
#define RS cs
#define CONJ __builtin_conjf
#define CREAL __builtin_crealf
#define CIMAG __builtin_cimagf
#define CABS(z) hypotf(__builtin_crealf(z), __builtin_cimagf(z))
#include "linalg_z.h"
#undef T
#undef R
#undef P
#undef RP
#undef RS
#undef CONJ
#undef CREAL
#undef CIMAG
#undef CABS
#define T double _Complex
#define R double
#define P z
#define RP dz
#define RS zd
#define CONJ __builtin_conj
#define CREAL __builtin_creal
#define CIMAG __builtin_cimag
#define CABS(z) hypot(__builtin_creal(z), __builtin_cimag(z))
#include "linalg_z.h"
#undef T
#undef R
#undef P
#undef RP
#undef RS
#undef CONJ
#undef CREAL
#undef CIMAG
#undef CABS

float cblas_sdsdot(const int N, const float alpha, const float *X, const int incX, const float *Y, const int incY) {
    double s = alpha;
    for (int i = 0; i < N; i++) s += (double)X[vidx(i, incX, N)] * Y[vidx(i, incY, N)];
    return (float)s;
}
double cblas_dsdot(const int N, const float *X, const int incX, const float *Y, const int incY) {
    double s = 0;
    for (int i = 0; i < N; i++) s += (double)X[vidx(i, incX, N)] * Y[vidx(i, incY, N)];
    return s;
}
