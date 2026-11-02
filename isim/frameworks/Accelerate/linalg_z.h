/* isim Accelerate: complex BLAS for one element type (included by linalg.c with T = float complex, R = float, P = c,
   RP = sc, RS = cs, then T = double complex, R = double, P = z, RP = dz, RS = zd). Complex arguments are `const void *`
   as in vecLib's cblas.h. Straightforward loops, as linalg_t.h. */
#define EL(A, lda, row, i, j) (A)[(row) ? (size_t)(i) * (lda) + (j) : (size_t)(j) * (lda) + (i)]
#define ZJ2(a, b) a##b
#define ZJ(a, b) ZJ2(a, b)
#define ZB(n) ZJ(cblas_, ZJ(P, n))
#define ZR(n) ZJ(cblas_, ZJ(RP, n))
#define ZS(n) ZJ(cblas_, ZJ(RS, n))
#define ZN(n) ZJ(linalgz_, ZJ(P, n))

/* element (i, j) of op(A): transposed, or conjugate-transposed */
static inline T ZN(op)(const T *A, int lda, int row, int tr, int cj, int i, int j) {
    T v = tr ? EL(A, lda, row, j, i) : EL(A, lda, row, i, j);
    return cj ? CONJ(v) : v;
}
#define ZOP(A, lda, row, t, i, j) ZN(op)(A, lda, row, (t) != CblasNoTrans, (t) == CblasConjTrans, i, j)

/* ---------------- level 1 ---------------- */
void ZB(dotu_sub)(const int N, const void *X, const int incX, const void *Y, const int incY, void *dotu) {
    const T *x = X, *y = Y; T s = 0;
    for (int i = 0; i < N; i++) s += x[vidx(i, incX, N)] * y[vidx(i, incY, N)];
    *(T *)dotu = s;
}
void ZB(dotc_sub)(const int N, const void *X, const int incX, const void *Y, const int incY, void *dotc) {
    const T *x = X, *y = Y; T s = 0;
    for (int i = 0; i < N; i++) s += CONJ(x[vidx(i, incX, N)]) * y[vidx(i, incY, N)];
    *(T *)dotc = s;
}
R ZR(nrm2)(const int N, const void *X, const int incX) {
    const T *x = X; R scale = 0, ssq = 1;
    for (int i = 0; i < N; i++) {
        R parts[2] = { CREAL(x[vidx(i, incX, N)]), CIMAG(x[vidx(i, incX, N)]) };
        for (int k = 0; k < 2; k++) {
            R a = parts[k] < 0 ? -parts[k] : parts[k];
            if (a == 0) continue;
            if (scale < a) { ssq = 1 + ssq * (scale / a) * (scale / a); scale = a; }
            else ssq += (a / scale) * (a / scale);
        }
    }
    return scale * (R)sqrt((double)ssq);
}
R ZR(asum)(const int N, const void *X, const int incX) {
    const T *x = X; R s = 0;
    for (int i = 0; i < N; i++) { T v = x[vidx(i, incX, N)]; R a = CREAL(v), b = CIMAG(v); s += (a < 0 ? -a : a) + (b < 0 ? -b : b); }
    return s;
}
int ZJ(cblas_i, ZJ(P, amax))(const int N, const void *X, const int incX) {
    const T *x = X; int best = 0; R m = -1;
    for (int i = 0; i < N; i++) {
        T v = x[vidx(i, incX, N)]; R a = CREAL(v), b = CIMAG(v);
        R s = (a < 0 ? -a : a) + (b < 0 ? -b : b);
        if (s > m) { m = s; best = i; }
    }
    return best;
}
void ZB(swap)(const int N, void *X, const int incX, void *Y, const int incY) {
    T *x = X, *y = Y;
    for (int i = 0; i < N; i++) { T t = x[vidx(i, incX, N)]; x[vidx(i, incX, N)] = y[vidx(i, incY, N)]; y[vidx(i, incY, N)] = t; }
}
void ZB(copy)(const int N, const void *X, const int incX, void *Y, const int incY) {
    const T *x = X; T *y = Y;
    for (int i = 0; i < N; i++) y[vidx(i, incY, N)] = x[vidx(i, incX, N)];
}
void ZB(axpy)(const int N, const void *alpha, const void *X, const int incX, void *Y, const int incY) {
    const T *x = X; T *y = Y, a = *(const T *)alpha;
    for (int i = 0; i < N; i++) y[vidx(i, incY, N)] += a * x[vidx(i, incX, N)];
}
void ZB(scal)(const int N, const void *alpha, void *X, const int incX) {
    T *x = X, a = *(const T *)alpha;
    if (incX <= 0) return;
    for (int i = 0; i < N; i++) x[(size_t)i * incX] *= a;
}
void ZS(scal)(const int N, const R alpha, void *X, const int incX) {
    T *x = X;
    if (incX <= 0) return;
    for (int i = 0; i < N; i++) x[(size_t)i * incX] *= alpha;
}
void ZS(rot)(const int N, void *X, const int incX, void *Y, const int incY, const R c, const R s) {
    T *x = X, *y = Y;
    for (int i = 0; i < N; i++) {
        T a = x[vidx(i, incX, N)], b = y[vidx(i, incY, N)];
        x[vidx(i, incX, N)] = c * a + s * b; y[vidx(i, incY, N)] = c * b - s * a;
    }
}
/* the complex Givens rotation that zeroes b (LAPACK's ?rotg): a becomes r */
void ZB(rotg)(void *a, void *b, R *c, void *s) {
    T *pa = a, *pb = b, *ps = s;
    R aa = CABS(*pa), bb = CABS(*pb);
    if (aa == 0) { *c = 0; *ps = 1; *pa = *pb; return; }
    R scale = aa + bb, norm = scale * (R)sqrt((double)((aa / scale) * (aa / scale) + (bb / scale) * (bb / scale)));
    T alpha = *pa / aa;
    *c = aa / norm;
    *ps = alpha * CONJ(*pb) / norm;
    *pa = alpha * norm;
}

/* ---------------- level 2 ---------------- */
void ZB(gemv)(const enum CBLAS_ORDER Order, const enum CBLAS_TRANSPOSE TransA, const int M, const int N, const void *alpha, const void *A,
              const int lda, const void *X, const int incX, const void *beta, void *Y, const int incY) {
    int row = Order == CblasRowMajor, tr = TransA != CblasNoTrans;
    int ny = tr ? N : M, nx = tr ? M : N;
    const T *a = A, *x = X; T *y = Y, al = *(const T *)alpha, be = *(const T *)beta;
    for (int i = 0; i < ny; i++) {
        T s = 0;
        for (int j = 0; j < nx; j++) s += ZOP(a, lda, row, TransA, i, j) * x[vidx(j, incX, nx)];
        T *py = &y[vidx(i, incY, ny)];
        *py = al * s + (be == 0 ? 0 : be * *py);
    }
}
static void ZN(ger)(int row, int M, int N, T al, const T *x, int incX, const T *y, int incY, T *a, int lda, int cj) {
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) {
        T yj = y[vidx(j, incY, N)];
        EL(a, lda, row, i, j) += al * x[vidx(i, incX, M)] * (cj ? CONJ(yj) : yj);
    }
}
void ZB(geru)(const enum CBLAS_ORDER Order, const int M, const int N, const void *alpha, const void *X, const int incX, const void *Y,
              const int incY, void *A, const int lda) {
    ZN(ger)(Order == CblasRowMajor, M, N, *(const T *)alpha, X, incX, Y, incY, A, lda, 0);
}
void ZB(gerc)(const enum CBLAS_ORDER Order, const int M, const int N, const void *alpha, const void *X, const int incX, const void *Y,
              const int incY, void *A, const int lda) {
    ZN(ger)(Order == CblasRowMajor, M, N, *(const T *)alpha, X, incX, Y, incY, A, lda, 1);
}
/* element (i, j) of a Hermitian (herm) or complex symmetric matrix stored in one triangle */
static T ZN(her)(const T *A, int lda, int row, int upper, int herm, int i, int j) {
    if (i == j) return herm ? CREAL(EL(A, lda, row, i, i)) : EL(A, lda, row, i, i);
    if ((upper && i > j) || (!upper && i < j)) { T v = EL(A, lda, row, j, i); return herm ? CONJ(v) : v; }
    return EL(A, lda, row, i, j);
}
void ZB(hemv)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const int N, const void *alpha, const void *A, const int lda,
              const void *X, const int incX, const void *beta, void *Y, const int incY) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper;
    const T *a = A, *x = X; T *y = Y, al = *(const T *)alpha, be = *(const T *)beta;
    for (int i = 0; i < N; i++) {
        T s = 0;
        for (int j = 0; j < N; j++) s += ZN(her)(a, lda, row, up, 1, i, j) * x[vidx(j, incX, N)];
        T *py = &y[vidx(i, incY, N)];
        *py = al * s + (be == 0 ? 0 : be * *py);
    }
}
void ZB(her)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const int N, const R alpha, const void *X, const int incX, void *A,
             const int lda) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper;
    const T *x = X; T *a = A;
    for (int i = 0; i < N; i++)
        for (int j = up ? i : 0; j < (up ? N : i + 1); j++) {
            T *p = &EL(a, lda, row, i, j);
            *p += alpha * x[vidx(i, incX, N)] * CONJ(x[vidx(j, incX, N)]);
            if (i == j) *p = CREAL(*p);
        }
}
void ZB(her2)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const int N, const void *alpha, const void *X, const int incX,
              const void *Y, const int incY, void *A, const int lda) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper;
    const T *x = X, *y = Y; T *a = A, al = *(const T *)alpha;
    for (int i = 0; i < N; i++)
        for (int j = up ? i : 0; j < (up ? N : i + 1); j++) {
            T xi = x[vidx(i, incX, N)], xj = x[vidx(j, incX, N)], yi = y[vidx(i, incY, N)], yj = y[vidx(j, incY, N)];
            T *p = &EL(a, lda, row, i, j);
            *p += al * xi * CONJ(yj) + CONJ(al) * yi * CONJ(xj);
            if (i == j) *p = CREAL(*p);
        }
}
/* element (i, j) of op(A) for a triangular A */
static T ZN(tri)(const T *A, int lda, int row, int upper, enum CBLAS_TRANSPOSE t, int unit, int i, int j) {
    int tr = t != CblasNoTrans;
    int si = tr ? j : i, sj = tr ? i : j;                        /* the stored element */
    T v;
    if (si == sj) v = unit ? 1 : EL(A, lda, row, si, si);
    else if ((upper && si > sj) || (!upper && si < sj)) return 0;
    else v = EL(A, lda, row, si, sj);
    return t == CblasConjTrans ? CONJ(v) : v;
}
void ZB(trmv)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_DIAG Diag,
              const int N, const void *A, const int lda, void *X, const int incX) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper, unit = Diag == CblasUnit;
    const T *a = A; T *x = X, *t = malloc(sizeof(T) * (N > 0 ? N : 1));
    for (int i = 0; i < N; i++) {
        T s = 0;
        for (int j = 0; j < N; j++) s += ZN(tri)(a, lda, row, up, TransA, unit, i, j) * x[vidx(j, incX, N)];
        t[i] = s;
    }
    for (int i = 0; i < N; i++) x[vidx(i, incX, N)] = t[i];
    free(t);
}
static void ZN(trsolve)(const T *A, int lda, int row, int upper, enum CBLAS_TRANSPOSE t, int unit, int n, T *x, int inc) {
    int lower = upper == (t != CblasNoTrans);
    for (int s = 0; s < n; s++) {
        int i = lower ? s : n - 1 - s;
        T v = x[vidx(i, inc, n)];
        if (lower) for (int j = 0; j < i; j++) v -= ZN(tri)(A, lda, row, upper, t, unit, i, j) * x[vidx(j, inc, n)];
        else for (int j = i + 1; j < n; j++) v -= ZN(tri)(A, lda, row, upper, t, unit, i, j) * x[vidx(j, inc, n)];
        x[vidx(i, inc, n)] = unit ? v : v / ZN(tri)(A, lda, row, upper, t, unit, i, i);
    }
}
void ZB(trsv)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_DIAG Diag,
              const int N, const void *A, const int lda, void *X, const int incX) {
    ZN(trsolve)(A, lda, Order == CblasRowMajor, Uplo == CblasUpper, TransA, Diag == CblasUnit, N, X, incX);
}

/* ---------------- level 3 ---------------- */
void ZB(gemm)(const enum CBLAS_ORDER Order, const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_TRANSPOSE TransB, const int M, const int N,
              const int K, const void *alpha, const void *A, const int lda, const void *B, const int ldb, const void *beta, void *C, const int ldc) {
    int row = Order == CblasRowMajor;
    const T *a = A, *b = B; T *c = C, al = *(const T *)alpha, be = *(const T *)beta;
    for (int i = 0; i < M; i++)
        for (int j = 0; j < N; j++) {
            T s = 0;
            for (int k = 0; k < K; k++) s += ZOP(a, lda, row, TransA, i, k) * ZOP(b, ldb, row, TransB, k, j);
            T *pc = &EL(c, ldc, row, i, j);
            *pc = al * s + (be == 0 ? 0 : be * *pc);
        }
}
static void ZN(symm)(int row, int left, int up, int herm, int M, int N, T al, const T *a, int lda, const T *b, int ldb, T be, T *c, int ldc) {
    T *t = malloc(sizeof(T) * ((size_t)M * N > 0 ? (size_t)M * N : 1));
    for (int i = 0; i < M; i++)
        for (int j = 0; j < N; j++) {
            T s = 0;
            if (left) for (int k = 0; k < M; k++) s += ZN(her)(a, lda, row, up, herm, i, k) * EL(b, ldb, row, k, j);
            else for (int k = 0; k < N; k++) s += EL(b, ldb, row, i, k) * ZN(her)(a, lda, row, up, herm, k, j);
            t[(size_t)i * N + j] = s;
        }
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) {
        T *pc = &EL(c, ldc, row, i, j);
        *pc = al * t[(size_t)i * N + j] + (be == 0 ? 0 : be * *pc);
    }
    free(t);
}
void ZB(symm)(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, const int M, const int N,
              const void *alpha, const void *A, const int lda, const void *B, const int ldb, const void *beta, void *C, const int ldc) {
    ZN(symm)(Order == CblasRowMajor, Side == CblasLeft, Uplo == CblasUpper, 0, M, N, *(const T *)alpha, A, lda, B, ldb, *(const T *)beta, C, ldc);
}
void ZB(hemm)(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, const int M, const int N,
              const void *alpha, const void *A, const int lda, const void *B, const int ldb, const void *beta, void *C, const int ldc) {
    ZN(symm)(Order == CblasRowMajor, Side == CblasLeft, Uplo == CblasUpper, 1, M, N, *(const T *)alpha, A, lda, B, ldb, *(const T *)beta, C, ldc);
}
/* C = al op(A) op(B)^T-ish rank-k updates: herm conjugates (herk / her2k), else plain transposes (syrk / syr2k) */
static void ZN(rk)(int row, int up, enum CBLAS_TRANSPOSE t, int herm, int N, int K, T al, const T *a, int lda, const T *b, int ldb, T be,
                   T *c, int ldc, int two) {
    int tr = t != CblasNoTrans;
    for (int i = 0; i < N; i++)
        for (int j = up ? i : 0; j < (up ? N : i + 1); j++) {
            T s = 0;
            for (int k = 0; k < K; k++) {
                T ai = tr ? EL(a, lda, row, k, i) : EL(a, lda, row, i, k), aj = tr ? EL(a, lda, row, k, j) : EL(a, lda, row, j, k);
                if (!two) { s += herm ? (tr ? CONJ(ai) * aj : ai * CONJ(aj)) : ai * aj; continue; }
                T bi = tr ? EL(b, ldb, row, k, i) : EL(b, ldb, row, i, k), bj = tr ? EL(b, ldb, row, k, j) : EL(b, ldb, row, j, k);
                if (herm) s += tr ? al * CONJ(ai) * bj + CONJ(al) * CONJ(bi) * aj
                                  : al * ai * CONJ(bj) + CONJ(al) * bi * CONJ(aj);
                else s += al * (ai * bj + bi * aj);
            }
            if (!two) s *= al;
            T *pc = &EL(c, ldc, row, i, j);
            *pc = s + (be == 0 ? 0 : be * *pc);
            if (herm && i == j) *pc = CREAL(*pc);
        }
}
void ZB(syrk)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE Trans, const int N, const int K,
              const void *alpha, const void *A, const int lda, const void *beta, void *C, const int ldc) {
    ZN(rk)(Order == CblasRowMajor, Uplo == CblasUpper, Trans, 0, N, K, *(const T *)alpha, A, lda, NULL, 0, *(const T *)beta, C, ldc, 0);
}
void ZB(herk)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE Trans, const int N, const int K,
              const R alpha, const void *A, const int lda, const R beta, void *C, const int ldc) {
    ZN(rk)(Order == CblasRowMajor, Uplo == CblasUpper, Trans, 1, N, K, alpha, A, lda, NULL, 0, beta, C, ldc, 0);
}
void ZB(syr2k)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE Trans, const int N, const int K,
               const void *alpha, const void *A, const int lda, const void *B, const int ldb, const void *beta, void *C, const int ldc) {
    ZN(rk)(Order == CblasRowMajor, Uplo == CblasUpper, Trans, 0, N, K, *(const T *)alpha, A, lda, B, ldb, *(const T *)beta, C, ldc, 1);
}
void ZB(her2k)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE Trans, const int N, const int K,
               const void *alpha, const void *A, const int lda, const void *B, const int ldb, const R beta, void *C, const int ldc) {
    ZN(rk)(Order == CblasRowMajor, Uplo == CblasUpper, Trans, 1, N, K, *(const T *)alpha, A, lda, B, ldb, beta, C, ldc, 1);
}
void ZB(trmm)(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA,
              const enum CBLAS_DIAG Diag, const int M, const int N, const void *alpha, const void *A, const int lda, void *B, const int ldb) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper, unit = Diag == CblasUnit, left = Side == CblasLeft;
    const T *a = A; T *b = B, al = *(const T *)alpha, *t = malloc(sizeof(T) * ((size_t)M * N > 0 ? (size_t)M * N : 1));
    for (int i = 0; i < M; i++)
        for (int j = 0; j < N; j++) {
            T s = 0;
            if (left) for (int k = 0; k < M; k++) s += ZN(tri)(a, lda, row, up, TransA, unit, i, k) * EL(b, ldb, row, k, j);
            else for (int k = 0; k < N; k++) s += EL(b, ldb, row, i, k) * ZN(tri)(a, lda, row, up, TransA, unit, k, j);
            t[(size_t)i * N + j] = al * s;
        }
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) EL(b, ldb, row, i, j) = t[(size_t)i * N + j];
    free(t);
}
void ZB(trsm)(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA,
              const enum CBLAS_DIAG Diag, const int M, const int N, const void *alpha, const void *A, const int lda, void *B, const int ldb) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper, unit = Diag == CblasUnit;
    const T *a = A; T *b = B, al = *(const T *)alpha;
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) EL(b, ldb, row, i, j) *= al;
    if (Side == CblasLeft) {
        T *col = malloc(sizeof(T) * (M > 0 ? M : 1));
        for (int j = 0; j < N; j++) {
            for (int i = 0; i < M; i++) col[i] = EL(b, ldb, row, i, j);
            ZN(trsolve)(a, lda, row, up, TransA, unit, M, col, 1);
            for (int i = 0; i < M; i++) EL(b, ldb, row, i, j) = col[i];
        }
        free(col);
    } else {
        /* X op(A) = B: each row x solves op(A)^T x = b, op(A)^T being A, A^T or conj(A) */
        T *r = malloc(sizeof(T) * (N > 0 ? N : 1));
        for (int i = 0; i < M; i++) {
            for (int j = 0; j < N; j++) r[j] = EL(b, ldb, row, i, j);
            if (TransA == CblasConjTrans) {                          /* conj(A) x = b  <=>  A conj(x) = conj(b) */
                for (int j = 0; j < N; j++) r[j] = CONJ(r[j]);
                ZN(trsolve)(a, lda, row, up, CblasNoTrans, unit, N, r, 1);
                for (int j = 0; j < N; j++) r[j] = CONJ(r[j]);
            } else ZN(trsolve)(a, lda, row, up, TransA == CblasNoTrans ? CblasTrans : CblasNoTrans, unit, N, r, 1);
            for (int j = 0; j < N; j++) EL(b, ldb, row, i, j) = r[j];
        }
        free(r);
    }
}
#undef ZOP
#undef EL
#undef ZJ2
#undef ZJ
#undef ZB
#undef ZR
#undef ZS
#undef ZN
