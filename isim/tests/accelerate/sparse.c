// Sparse Solvers from C (issue #807): the checks of sparse_t.h for double, float, complex double and complex float.
#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#pragma STDC CX_LIMITED_RANGE ON

#define CHECK(cond, what) do { (*checks)++; if (cond) printf("PASS  %s\n", what); else { (*failures)++; printf("FAIL  %s  (line %d)\n", what, __LINE__); } } while (0)

/* the subfactor transposes used by the PLPS check: conjugate for complex */
#define SparseGetConjugateTranspose_or_transpose_Double SparseGetTranspose
#define SparseGetConjugateTranspose_or_transpose_Float SparseGetTranspose
#define SparseGetConjugateTranspose_or_transpose_Complex_Double SparseGetConjugateTranspose
#define SparseGetConjugateTranspose_or_transpose_Complex_Float SparseGetConjugateTranspose

#define X Double
#define T double
#define R double
#define CPLX 0
#define ATTRT Attributes_t
#define ABSV(x) fabs(x)
#define CONJ(x) (x)
#define MK(re, im) ((double)(re))
#include "sparse_t.h"
#undef X
#undef T
#undef R
#undef CPLX
#undef ABSV
#undef MK
#define X Float
#define T float
#define R float
#define CPLX 0
#define ABSV(x) fabsf(x)
#define MK(re, im) ((float)(re))
#include "sparse_t.h"
#undef X
#undef T
#undef R
#undef CPLX
#undef ATTRT
#undef ABSV
#undef CONJ
#undef MK
#define X Complex_Double
#define T _Complex double
#define R double
#define CPLX 1
#define ATTRT AttributesComplex_t
#define ABSV(x) hypot(__builtin_creal(x), __builtin_cimag(x))
#define CONJ(x) __builtin_conj(x)
#define MK(re, im) __builtin_complex((double)(re), (double)(im))
#include "sparse_t.h"
#undef X
#undef T
#undef R
#undef CPLX
#undef ABSV
#undef CONJ
#undef MK
#define X Complex_Float
#define T _Complex float
#define R float
#define CPLX 1
#define ABSV(x) hypotf(__builtin_crealf(x), __builtin_cimagf(x))
#define CONJ(x) __builtin_conjf(x)
#define MK(re, im) __builtin_complex((float)(re), (float)(im))
#include "sparse_t.h"

/* a 30 x 30 grid Laplacian (900 unknowns): real fill and ordering, user orders, ignored rows, retains, updates */
static void sparse_large(int *checks, int *failures) {
    enum { G = 30, N = G * G };
    int *rows = malloc(sizeof(int) * 5 * N), *cols = malloc(sizeof(int) * 5 * N);
    double *vals = malloc(sizeof(double) * 5 * N), *xt = malloc(sizeof(double) * N), *b = malloc(sizeof(double) * N), *x = malloc(sizeof(double) * N);
    long k = 0;
    for (int j = 0; j < G; j++) for (int i = 0; i < G; i++) {
        int c = j * G + i;
        rows[k] = c; cols[k] = c; vals[k] = 4.01; k++;
        if (i + 1 < G) { rows[k] = c + 1; cols[k] = c; vals[k] = -1; k++; }
        if (j + 1 < G) { rows[k] = c + G; cols[k] = c; vals[k] = -1; k++; }
    }
    SparseAttributes_t at = { 0 }; at.kind = SparseSymmetric; at.triangle = SparseLowerTriangle;
    SparseMatrix_Double A = SparseConvertFromCoordinate(N, N, k, 1, at, rows, cols, vals);
    for (int i = 0; i < N; i++) xt[i] = sin(i * 0.37) + 1;
    SparseMultiply(A, (DenseVector_Double){ N, xt }, (DenseVector_Double){ N, b });
    double err;
    #define ERR() (err = 0, ({ for (int i_ = 0; i_ < N; i_++) if (fabs(x[i_] - xt[i_]) > err) err = fabs(x[i_] - xt[i_]); }), err)
    const SparseFactorization_t ts[] = { SparseFactorizationCholesky, SparseFactorizationLDLT, SparseFactorizationLU, SparseFactorizationQR, SparseFactorizationCholeskyAtA };
    const char *tn[] = { "Cholesky", "LDLT", "LU", "QR", "CholeskyAtA" };
    char what[128];
    for (int t = 0; t < 5; t++) {
        SparseOpaqueFactorization_Double F = SparseFactor(ts[t], A);
        if (F.status == SparseStatusOK) SparseSolve(F, (DenseVector_Double){ N, b }, (DenseVector_Double){ N, x });
        snprintf(what, sizeof what, "Sparse: %s of a 900-unknown grid Laplacian (error %.1e)", tn[t], F.status == SparseStatusOK ? ERR() : -1.0);
        CHECK(F.status == SparseStatusOK && ERR() < 1e-8, what);
        if (t == 0) {
            SparseOpaqueFactorization_Double R2 = SparseRetain(F);
            SparseCleanup(F);
            SparseSolve(R2, (DenseVector_Double){ N, b }, (DenseVector_Double){ N, x });
            CHECK(ERR() < 1e-8, "Sparse: SparseRetain keeps a factorization after SparseCleanup");
            int idx[1] = { 0 };
            SparseUpdateFactor(SparseUpdatePartialRefactor, &R2, 1, idx, A);
            SparseSolve(R2, (DenseVector_Double){ N, b }, (DenseVector_Double){ N, x });
            CHECK(R2.status == SparseStatusOK && ERR() < 1e-8, "Sparse: SparseUpdateFactor(SparseUpdatePartialRefactor)");
            SparseCleanup(R2);
        } else SparseCleanup(F);
    }
    /* a user order (the reverse), and an ignored row and column */
    int *order = malloc(sizeof(int) * N);
    for (int i = 0; i < N; i++) order[i] = N - 1 - i;
    SparseSymbolicFactorOptions so = { 0 }; so.orderMethod = SparseOrderUser; so.order = order; so.malloc = malloc; so.free = free;
    SparseNumericFactorOptions no = { 0 };
    SparseOpaqueFactorization_Double F = SparseFactor(SparseFactorizationCholesky, A, so, no);
    if (F.status == SparseStatusOK) SparseSolve(F, (DenseVector_Double){ N, b }, (DenseVector_Double){ N, x });
    CHECK(F.status == SparseStatusOK && ERR() < 1e-8, "Sparse: SparseOrderUser");
    SparseCleanup(F);
    free(order);
    /* CG and DQGMRES with a diagonal preconditioner; SparseIterate with GMRES */
    SparseCGOptions co = { 0 }; co.rtol = 1e-12; co.maxIterations = 1000;
    for (int i = 0; i < N; i++) x[i] = 0;
    SparseOpaquePreconditioner_Double P = SparseCreatePreconditioner(SparsePreconditionerDiagonal, A);
    SparseIterativeStatus_t st = SparseSolve(SparseConjugateGradient(co), A, (DenseVector_Double){ N, b }, (DenseVector_Double){ N, x }, P);
    CHECK(st == SparseIterativeConverged && ERR() < 1e-8, "Sparse: CG on the grid Laplacian with an opaque preconditioner");
    SparseGMRESOptions go = { 0 }; go.rtol = 1e-12; go.maxIterations = 2000; go.nvec = 20;
    for (int i = 0; i < N; i++) x[i] = 0;
    st = SparseSolve(SparseGMRES(go), A, (DenseVector_Double){ N, b }, (DenseVector_Double){ N, x }, P);
    CHECK(st == SparseIterativeConverged && ERR() < 1e-7, "Sparse: DQGMRES on the grid Laplacian");
    SparseCleanup(P);
    go.variant = SparseVariantGMRES;
    SparseIterativeMethod gm = SparseGMRES(go);
    void *state = malloc(SparseGetStateSize_Double(gm, false, N, N, 1));
    double *r = malloc(sizeof(double) * N);
    bool conv = false;
    for (int i = 0; i < N; i++) x[i] = 0;
    DenseMatrix_Double Bm = { N, 1, N, { 0 }, b }, Rm = { N, 1, N, { 0 }, r }, Xm = { N, 1, N, { 0 }, x };
    void (^op)(bool, enum CBLAS_TRANSPOSE, DenseMatrix_Double, DenseMatrix_Double) = ^(bool acc, enum CBLAS_TRANSPOSE tr, DenseMatrix_Double u, DenseMatrix_Double v) {
        if (acc) SparseMultiplyAdd(A, u, v); else SparseMultiply(A, u, v);
    };
    for (int it = 0; it < 400 && !conv; it++) {
        SparseIterate(gm, it, &conv, state, op, Bm, Rm, Xm);
        double nr = 0; for (int i = 0; i < N; i++) nr += r[i] * r[i];
        if (it > 0 && sqrt(nr) < 1e-10) conv = true;
    }
    SparseIterate(gm, -1, &conv, state, op, Bm, Rm, Xm);
    CHECK(conv && ERR() < 1e-8, "Sparse: SparseIterate(GMRES) with finalization");
    free(state); free(r);
    #undef ERR
    SparseCleanup(A);
    free(rows); free(cols); free(vals); free(xt); free(b); free(x);
}

void sparse_solvers(int *checks, int *failures) {
    sparse_large(checks, failures);
    sparse_tests_Double(checks, failures, "double", 1e-12);
    sparse_tests_Float(checks, failures, "float", 1e-4f);
    sparse_tests_Complex_Double(checks, failures, "complex double", 1e-12);
    sparse_tests_Complex_Float(checks, failures, "complex float", 1e-4f);
}
