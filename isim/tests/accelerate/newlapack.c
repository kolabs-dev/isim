// The new BLAS / LAPACK interface (issue #543): this file is compiled with ACCELERATE_NEW_LAPACK, so its calls bind to
// the <name>$NEWLAPACK symbols, with __LAPACK_int, const-correct pointers and native complex types.
#define ACCELERATE_NEW_LAPACK
#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdio.h>

#define CHECK(cond, what) do { (*checks)++; if (cond) printf("PASS  %s\n", what); else { (*failures)++; printf("FAIL  %s  (line %d)\n", what, __LINE__); } } while (0)

void newlapack(int *checks, int *failures) {
    const __LAPACK_int n = 2, nrhs = 1, lda = 2;
    double a[] = {2, 1, 1, 3}, b[] = {3, 5};
    __LAPACK_int ipiv[2], info = -1;
    dgesv_(&n, &nrhs, a, &lda, ipiv, b, &lda, &info);       /* void, const inputs */
    CHECK(info == 0 && fabs(b[0] - 0.8) < 1e-12 && fabs(b[1] - 1.4) < 1e-12, "new LAPACK: dgesv_ through dgesv$NEWLAPACK");
    const double x[] = {1, 2, 3}, y[] = {4, 5, 6};
    CHECK(cblas_ddot(3, x, 1, y, 1) == 32, "new BLAS: cblas_ddot with __LAPACK_int");
    const _Complex double zx[] = {1 + 2i, 3 - 1i}, zy[] = {1i, 2 + 2i};
    _Complex double dot;
    cblas_zdotc_sub(2, zx, 1, zy, 1, &dot);
    CHECK(__builtin_creal(dot) == 6 && __builtin_cimag(dot) == 9, "new BLAS: cblas_zdotc_sub with _Complex double");
    const char jobz = 'V', uplo = 'U';
    double s[] = {2, 1, 1, 2}, w[2], work[16];
    const __LAPACK_int lw = 16;
    dsyev_(&jobz, &uplo, &n, s, &lda, w, work, &lw, &info);
    CHECK(info == 0 && fabs(w[0] - 1) < 1e-12 && fabs(w[1] - 3) < 1e-12, "new LAPACK: dsyev_");
}
