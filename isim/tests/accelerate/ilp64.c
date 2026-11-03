// The ILP64 new BLAS / LAPACK interface (issue #809): compiled with ACCELERATE_NEW_LAPACK and ACCELERATE_LAPACK_ILP64,
// so __LAPACK_int is long and the calls bind to <name>$NEWLAPACK$ILP64.
#define ACCELERATE_NEW_LAPACK
#define ACCELERATE_LAPACK_ILP64
#include <Accelerate/Accelerate.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>

#define CHECK(cond, what) do { (*checks)++; if (cond) printf("PASS  %s\n", what); else { (*failures)++; printf("FAIL  %s  (line %d)\n", what, __LINE__); } } while (0)

void ilp64(int *checks, int *failures) {
    CHECK(sizeof(__LAPACK_int) == 8, "ILP64: __LAPACK_int is 64 bits");
    const __LAPACK_int n = 3, nrhs = 1, lda = 3;
    double a[] = {4, 2, 1, 2, 5, 3, 1, 3, 6}, b[] = {7, 10, 10};     /* column-major, x = (1, 1, 1) */
    __LAPACK_int ipiv[3] = {-1, -1, -1}, info = -99;
    dgesv_(&n, &nrhs, a, &lda, ipiv, b, &lda, &info);
    CHECK(info == 0 && fabs(b[0] - 1) < 1e-12 && fabs(b[1] - 1) < 1e-12 && fabs(b[2] - 1) < 1e-12, "ILP64: dgesv_ solves a 3x3 system");
    CHECK(ipiv[0] >= 1 && ipiv[0] <= 3 && ipiv[2] == 3, "ILP64: dgesv_ returns 64-bit pivots");
    /* getrf, then getrs with the pivots it gave (const input array) */
    double f[] = {0, 1, 2, 3}, rhs[] = {3, 2};                        /* [[0, 2], [1, 3]]: needs a row swap */
    __LAPACK_int two = 2, one = 1, piv[2];
    dgetrf_(&two, &two, f, &two, piv, &info);
    CHECK(info == 0 && piv[0] == 2, "ILP64: dgetrf_ pivots the zero diagonal");
    const char tr = 'N';
    dgetrs_(&tr, &two, &one, f, &two, piv, rhs, &two, &info);
    CHECK(info == 0 && fabs(rhs[0] - (-2.5)) < 1e-12 && fabs(rhs[1] - 1.5) < 1e-12, "ILP64: dgetrs_ with the 64-bit pivots");
    /* gesdd: the integer workspace array */
    double m[] = {3, 0, 0, 4}, s[2], u[4], vt[4], work[64];
    __LAPACK_int lw = 64, iwork[16];
    const char jobz = 'A';
    dgesdd_(&jobz, &two, &two, m, &two, s, u, &two, vt, &two, work, &lw, iwork, &info);
    CHECK(info == 0 && fabs(s[0] - 4) < 1e-12 && fabs(s[1] - 3) < 1e-12, "ILP64: dgesdd_ with a 64-bit iwork");
    /* a value that does not fit 32 bits: info = -argument */
    const __LAPACK_int huge = (__LAPACK_int)INT_MAX + 1;
    dgesv_(&huge, &nrhs, a, &lda, ipiv, b, &lda, &info);
    CHECK(info == -1, "ILP64: an N beyond 32 bits is argument -1");
    /* BLAS */
    const double x[] = {1, 2, 3}, y[] = {4, 5, 6};
    CHECK(cblas_ddot(3, x, 1, y, 1) == 32, "ILP64: cblas_ddot with a long N");
    const float v[] = {1, -7, 3};
    __LAPACK_int imax = cblas_isamax(3, v, 1);
    CHECK(imax == 1, "ILP64: cblas_isamax returns a long index");
    const _Complex double zx[] = {1 + 2i, 3 - 1i}, zy[] = {1i, 2 + 2i};
    _Complex double dot;
    cblas_zdotc_sub(2, zx, 1, zy, 1, &dot);
    CHECK(__builtin_creal(dot) == 6 && __builtin_cimag(dot) == 9, "ILP64: cblas_zdotc_sub");
    double c[4] = {0};
    const double ga[] = {1, 2, 3, 4}, gb[] = {1, 0, 0, 1};
    cblas_dgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2, 1, ga, 2, gb, 2, 0, c, 2);
    CHECK(c[0] == 1 && c[3] == 4, "ILP64: cblas_dgemm");
}
