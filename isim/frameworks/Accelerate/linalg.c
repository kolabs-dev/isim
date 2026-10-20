/* isim Accelerate: vecLib's BLAS (cblas.h) and LAPACK (clapack.h), adapted: isim's own implementation (no host
   library), single and double precision from one template (linalg_t.h). */
#include <Accelerate/Accelerate.h>
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
