/* isim Accelerate: BLAS and LAPACK for one element type (included by linalg.c with T = float, P = s, then T = double,
   P = d). Straightforward loops: correct results and the reference algorithms' numerics, not a tuned library. */
#define FN2(p, n) cblas_##p##n
#define FN(p, n) FN2(p, n)
#define CB(n) FN(P, n)
#define LP2(p, n) p##n##_
#define LP1(p, n) LP2(p, n)
#define LA(n) LP1(P, n)
#define CBI2(p, n) cblas_i##p##n
#define CBI1(p, n) CBI2(p, n)
#define NM2(p, n) linalg_##p##_##n
#define NM1(p, n) NM2(p, n)
#define NM(n) NM1(P, n)

/* ---------------- level 1 ---------------- */
T CB(dot)(const int N, const T *X, const int incX, const T *Y, const int incY) {
    T s = 0;
    for (int i = 0; i < N; i++) s += X[vidx(i, incX, N)] * Y[vidx(i, incY, N)];
    return s;
}
T CB(nrm2)(const int N, const T *X, const int incX) {
    /* scaled, as LAPACK's nrm2: no overflow for large elements */
    T scale = 0, ssq = 1;
    for (int i = 0; i < N; i++) {
        T a = X[vidx(i, incX, N)] < 0 ? -X[vidx(i, incX, N)] : X[vidx(i, incX, N)];
        if (a == 0) continue;
        if (scale < a) { ssq = 1 + ssq * (scale / a) * (scale / a); scale = a; }
        else ssq += (a / scale) * (a / scale);
    }
    return scale * (T)sqrt((double)ssq);
}
T CB(asum)(const int N, const T *X, const int incX) {
    T s = 0;
    for (int i = 0; i < N; i++) { T v = X[vidx(i, incX, N)]; s += v < 0 ? -v : v; }
    return s;
}
int CBI1(P, amax)(const int N, const T *X, const int incX) {
    int best = 0; T m = -1;
    for (int i = 0; i < N; i++) { T v = X[vidx(i, incX, N)]; v = v < 0 ? -v : v; if (v > m) { m = v; best = i; } }
    return N > 0 ? best : 0;
}
void CB(swap)(const int N, T *X, const int incX, T *Y, const int incY) {
    for (int i = 0; i < N; i++) { T t = X[vidx(i, incX, N)]; X[vidx(i, incX, N)] = Y[vidx(i, incY, N)]; Y[vidx(i, incY, N)] = t; }
}
void CB(copy)(const int N, const T *X, const int incX, T *Y, const int incY) {
    for (int i = 0; i < N; i++) Y[vidx(i, incY, N)] = X[vidx(i, incX, N)];
}
void CB(axpy)(const int N, const T alpha, const T *X, const int incX, T *Y, const int incY) {
    for (int i = 0; i < N; i++) Y[vidx(i, incY, N)] += alpha * X[vidx(i, incX, N)];
}
void CB(scal)(const int N, const T alpha, T *X, const int incX) {
    if (incX <= 0) return;
    for (int i = 0; i < N; i++) X[(size_t)i * incX] *= alpha;
}
void CB(rot)(const int N, T *X, const int incX, T *Y, const int incY, const T c, const T s) {
    for (int i = 0; i < N; i++) {
        T x = X[vidx(i, incX, N)], y = Y[vidx(i, incY, N)];
        X[vidx(i, incX, N)] = c * x + s * y; Y[vidx(i, incY, N)] = c * y - s * x;
    }
}

/* ---------------- matrices ---------------- */
/* element (i, j) of a matrix in either layout */
#define EL(A, lda, row, i, j) (A)[(row) ? (size_t)(i) * (lda) + (j) : (size_t)(j) * (lda) + (i)]
/* element (i, j) of op(A) */
#define OP(A, lda, row, tr, i, j) ((tr) ? EL(A, lda, row, j, i) : EL(A, lda, row, i, j))

void CB(gemv)(const enum CBLAS_ORDER Order, const enum CBLAS_TRANSPOSE TransA, const int M, const int N, const T alpha, const T *A,
              const int lda, const T *X, const int incX, const T beta, T *Y, const int incY) {
    int row = Order == CblasRowMajor, tr = TransA != CblasNoTrans;
    int ny = tr ? N : M, nx = tr ? M : N;
    for (int i = 0; i < ny; i++) {
        T s = 0;
        for (int j = 0; j < nx; j++) s += OP(A, lda, row, tr, i, j) * X[vidx(j, incX, nx)];
        T *y = &Y[vidx(i, incY, ny)];
        *y = alpha * s + (beta == 0 ? 0 : beta * *y);
    }
}
void CB(ger)(const enum CBLAS_ORDER Order, const int M, const int N, const T alpha, const T *X, const int incX, const T *Y, const int incY,
             T *A, const int lda) {
    int row = Order == CblasRowMajor;
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) EL(A, lda, row, i, j) += alpha * X[vidx(i, incX, M)] * Y[vidx(j, incY, N)];
}
/* element (i, j) of a symmetric matrix stored in one triangle */
static T NM(sym)(const T *A, int lda, int row, int upper, int i, int j) {
    if ((upper && i > j) || (!upper && i < j)) { int t = i; i = j; j = t; }
    return EL(A, lda, row, i, j);
}
void CB(symv)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const int N, const T alpha, const T *A, const int lda, const T *X,
              const int incX, const T beta, T *Y, const int incY) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper;
    for (int i = 0; i < N; i++) {
        T s = 0;
        for (int j = 0; j < N; j++) s += NM(sym)(A, lda, row, up, i, j) * X[vidx(j, incX, N)];
        T *y = &Y[vidx(i, incY, N)];
        *y = alpha * s + (beta == 0 ? 0 : beta * *y);
    }
}
/* element (i, j) of op(A) for a triangular A (zero outside its triangle, one on a unit diagonal) */
static T NM(tri)(const T *A, int lda, int row, int upper, int tr, int unit, int i, int j) {
    if (tr) { int t = i; i = j; j = t; }
    if (i == j) return unit ? 1 : EL(A, lda, row, i, i);
    if ((upper && i > j) || (!upper && i < j)) return 0;
    return EL(A, lda, row, i, j);
}
void CB(trmv)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_DIAG Diag,
              const int N, const T *A, const int lda, T *X, const int incX) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper, tr = TransA != CblasNoTrans, unit = Diag == CblasUnit;
    T *t = malloc(sizeof(T) * (N > 0 ? N : 1));
    for (int i = 0; i < N; i++) {
        T s = 0;
        for (int j = 0; j < N; j++) s += NM(tri)(A, lda, row, up, tr, unit, i, j) * X[vidx(j, incX, N)];
        t[i] = s;
    }
    for (int i = 0; i < N; i++) X[vidx(i, incX, N)] = t[i];
    free(t);
}
/* solves op(A) x = b in place (b: n values, stride inc) */
static void NM(trsolve)(const T *A, int lda, int row, int upper, int tr, int unit, int n, T *x, int inc) {
    int lower = upper == tr;                                     /* op(A) is lower triangular */
    for (int s = 0; s < n; s++) {
        int i = lower ? s : n - 1 - s;
        T v = x[vidx(i, inc, n)];
        if (lower) for (int j = 0; j < i; j++) v -= NM(tri)(A, lda, row, upper, tr, unit, i, j) * x[vidx(j, inc, n)];
        else for (int j = i + 1; j < n; j++) v -= NM(tri)(A, lda, row, upper, tr, unit, i, j) * x[vidx(j, inc, n)];
        x[vidx(i, inc, n)] = unit ? v : v / NM(tri)(A, lda, row, upper, tr, unit, i, i);
    }
}
void CB(trsv)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_DIAG Diag,
              const int N, const T *A, const int lda, T *X, const int incX) {
    NM(trsolve)(A, lda, Order == CblasRowMajor, Uplo == CblasUpper, TransA != CblasNoTrans, Diag == CblasUnit, N, X, incX);
}
void CB(gemm)(const enum CBLAS_ORDER Order, const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_TRANSPOSE TransB, const int M, const int N,
              const int K, const T alpha, const T *A, const int lda, const T *B, const int ldb, const T beta, T *C, const int ldc) {
    int row = Order == CblasRowMajor, ta = TransA != CblasNoTrans, tb = TransB != CblasNoTrans;
    for (int i = 0; i < M; i++)
        for (int j = 0; j < N; j++) {
            T s = 0;
            for (int k = 0; k < K; k++) s += OP(A, lda, row, ta, i, k) * OP(B, ldb, row, tb, k, j);
            T *c = &EL(C, ldc, row, i, j);
            *c = alpha * s + (beta == 0 ? 0 : beta * *c);
        }
}
void CB(symm)(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, const int M, const int N, const T alpha,
              const T *A, const int lda, const T *B, const int ldb, const T beta, T *C, const int ldc) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper, left = Side == CblasLeft;
    T *t = malloc(sizeof(T) * ((size_t)M * N > 0 ? (size_t)M * N : 1));
    for (int i = 0; i < M; i++)
        for (int j = 0; j < N; j++) {
            T s = 0;
            if (left) for (int k = 0; k < M; k++) s += NM(sym)(A, lda, row, up, i, k) * EL(B, ldb, row, k, j);
            else for (int k = 0; k < N; k++) s += EL(B, ldb, row, i, k) * NM(sym)(A, lda, row, up, k, j);
            t[(size_t)i * N + j] = s;
        }
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) {
        T *c = &EL(C, ldc, row, i, j);
        *c = alpha * t[(size_t)i * N + j] + (beta == 0 ? 0 : beta * *c);
    }
    free(t);
}
void CB(syrk)(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE Trans, const int N, const int K,
              const T alpha, const T *A, const int lda, const T beta, T *C, const int ldc) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper, tr = Trans != CblasNoTrans;
    for (int i = 0; i < N; i++)
        for (int j = up ? i : 0; j < (up ? N : i + 1); j++) {
            T s = 0;
            for (int k = 0; k < K; k++) s += OP(A, lda, row, tr, i, k) * OP(A, lda, row, tr, j, k);
            T *c = &EL(C, ldc, row, i, j);
            *c = alpha * s + (beta == 0 ? 0 : beta * *c);
        }
}
void CB(trmm)(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA,
              const enum CBLAS_DIAG Diag, const int M, const int N, const T alpha, const T *A, const int lda, T *B, const int ldb) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper, tr = TransA != CblasNoTrans, unit = Diag == CblasUnit, left = Side == CblasLeft;
    T *t = malloc(sizeof(T) * ((size_t)M * N > 0 ? (size_t)M * N : 1));
    for (int i = 0; i < M; i++)
        for (int j = 0; j < N; j++) {
            T s = 0;
            if (left) for (int k = 0; k < M; k++) s += NM(tri)(A, lda, row, up, tr, unit, i, k) * EL(B, ldb, row, k, j);
            else for (int k = 0; k < N; k++) s += EL(B, ldb, row, i, k) * NM(tri)(A, lda, row, up, tr, unit, k, j);
            t[(size_t)i * N + j] = alpha * s;
        }
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) EL(B, ldb, row, i, j) = t[(size_t)i * N + j];
    free(t);
}
void CB(trsm)(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA,
              const enum CBLAS_DIAG Diag, const int M, const int N, const T alpha, const T *A, const int lda, T *B, const int ldb) {
    int row = Order == CblasRowMajor, up = Uplo == CblasUpper, tr = TransA != CblasNoTrans, unit = Diag == CblasUnit;
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) EL(B, ldb, row, i, j) *= alpha;
    if (Side == CblasLeft) {
        /* op(A) X = B: each column of B */
        T *col = malloc(sizeof(T) * (M > 0 ? M : 1));
        for (int j = 0; j < N; j++) {
            for (int i = 0; i < M; i++) col[i] = EL(B, ldb, row, i, j);
            NM(trsolve)(A, lda, row, up, tr, unit, M, col, 1);
            for (int i = 0; i < M; i++) EL(B, ldb, row, i, j) = col[i];
        }
        free(col);
    } else {
        /* X op(A) = B: each row of B solves op(A)^T x = b */
        T *r = malloc(sizeof(T) * (N > 0 ? N : 1));
        for (int i = 0; i < M; i++) {
            for (int j = 0; j < N; j++) r[j] = EL(B, ldb, row, i, j);
            NM(trsolve)(A, lda, row, up, !tr, unit, N, r, 1);
            for (int j = 0; j < N; j++) EL(B, ldb, row, i, j) = r[j];
        }
        free(r);
    }
}

/* ---------------- LAPACK (column-major) ---------------- */
#define CM(A, lda, i, j) (A)[(size_t)(j) * (lda) + (i)]

int LA(getrf)(__CLPK_integer *m, __CLPK_integer *n, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, __CLPK_integer *info) {
    int M = *m, N = *n, L = *lda, mn = M < N ? M : N;
    *info = 0;
    if (M < 0) { *info = -1; return 0; }
    if (N < 0) { *info = -2; return 0; }
    if (L < (M > 1 ? M : 1)) { *info = -4; return 0; }
    for (int k = 0; k < mn; k++) {
        int p = k; T best = 0;
        for (int i = k; i < M; i++) { T v = CM(a, L, i, k); v = v < 0 ? -v : v; if (v > best) { best = v; p = i; } }
        ipiv[k] = p + 1;
        if (best == 0) { if (!*info) *info = k + 1; continue; }
        if (p != k) for (int j = 0; j < N; j++) { T t = CM(a, L, k, j); CM(a, L, k, j) = CM(a, L, p, j); CM(a, L, p, j) = t; }
        T d = CM(a, L, k, k);
        for (int i = k + 1; i < M; i++) CM(a, L, i, k) /= d;
        for (int j = k + 1; j < N; j++) {
            T f = CM(a, L, k, j);
            if (f != 0) for (int i = k + 1; i < M; i++) CM(a, L, i, j) -= CM(a, L, i, k) * f;
        }
    }
    return 0;
}
int LA(getrs)(char *trans, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, T *b,
              __CLPK_integer *ldb, __CLPK_integer *info) {
    int N = *n, R = *nrhs, L = *lda, LB = *ldb, tr = (*trans == 'T' || *trans == 't' || *trans == 'C' || *trans == 'c');
    *info = 0;
    if (N < 0) { *info = -2; return 0; }
    for (int r = 0; r < R; r++) {
        T *x = &b[(size_t)r * LB];
        if (!tr) {
            for (int i = 0; i < N; i++) { int p = ipiv[i] - 1; if (p != i) { T t = x[i]; x[i] = x[p]; x[p] = t; } }
            for (int i = 0; i < N; i++) for (int j = 0; j < i; j++) x[i] -= CM(a, L, i, j) * x[j];          /* L, unit */
            for (int i = N - 1; i >= 0; i--) { for (int j = i + 1; j < N; j++) x[i] -= CM(a, L, i, j) * x[j]; x[i] /= CM(a, L, i, i); }
        } else {
            for (int i = 0; i < N; i++) { for (int j = 0; j < i; j++) x[i] -= CM(a, L, j, i) * x[j]; x[i] /= CM(a, L, i, i); }   /* U^T */
            for (int i = N - 1; i >= 0; i--) for (int j = i + 1; j < N; j++) x[i] -= CM(a, L, j, i) * x[j];                  /* L^T */
            for (int i = N - 1; i >= 0; i--) { int p = ipiv[i] - 1; if (p != i) { T t = x[i]; x[i] = x[p]; x[p] = t; } }
        }
    }
    return 0;
}
int LA(gesv)(__CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, T *b, __CLPK_integer *ldb,
             __CLPK_integer *info) {
    LA(getrf)(n, n, a, lda, ipiv, info);
    if (*info == 0) { char t = 'N'; LA(getrs)(&t, n, nrhs, a, lda, ipiv, b, ldb, info); }
    return 0;
}
int LA(getri)(__CLPK_integer *n, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, T *work, __CLPK_integer *lwork, __CLPK_integer *info) {
    int N = *n, L = *lda;
    *info = 0;
    if (*lwork == -1) { work[0] = (T)(N > 0 ? N : 1); return 0; }
    for (int i = 0; i < N; i++) if (CM(a, L, i, i) == 0) { *info = i + 1; return 0; }
    T *inv = calloc((size_t)N * N + 1, sizeof(T));
    for (int i = 0; i < N; i++) inv[(size_t)i * N + i] = 1;
    char t = 'N'; int ld = N > 0 ? N : 1, e;
    LA(getrs)(&t, n, n, a, lda, ipiv, inv, &ld, &e);
    for (int j = 0; j < N; j++) for (int i = 0; i < N; i++) CM(a, L, i, j) = inv[(size_t)j * N + i];
    free(inv);
    return 0;
}
int LA(potrf)(char *uplo, __CLPK_integer *n, T *a, __CLPK_integer *lda, __CLPK_integer *info) {
    int N = *n, L = *lda, up = (*uplo == 'U' || *uplo == 'u');
    *info = 0;
    for (int j = 0; j < N; j++) {
        /* lower: A = L L^T, L(j, j) = sqrt(A(j, j) - sum L(j, k)^2); upper: A = U^T U, U = L^T */
        double d = up ? CM(a, L, j, j) : CM(a, L, j, j);
        for (int k = 0; k < j; k++) { double v = up ? CM(a, L, k, j) : CM(a, L, j, k); d -= v * v; }
        if (d <= 0 || isnan(d)) { *info = j + 1; return 0; }
        d = sqrt(d);
        if (up) CM(a, L, j, j) = (T)d; else CM(a, L, j, j) = (T)d;
        for (int i = j + 1; i < N; i++) {
            double s = up ? CM(a, L, j, i) : CM(a, L, i, j);
            for (int k = 0; k < j; k++) s -= up ? (double)CM(a, L, k, i) * CM(a, L, k, j) : (double)CM(a, L, i, k) * CM(a, L, j, k);
            if (up) CM(a, L, j, i) = (T)(s / d); else CM(a, L, i, j) = (T)(s / d);
        }
    }
    return 0;
}
int LA(potrs)(char *uplo, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, T *b, __CLPK_integer *ldb, __CLPK_integer *info) {
    int N = *n, R = *nrhs, L = *lda, LB = *ldb, up = (*uplo == 'U' || *uplo == 'u');
    *info = 0;
    for (int r = 0; r < R; r++) {
        T *x = &b[(size_t)r * LB];
        /* solve L y = b (L = U^T when upper), then L^T x = y */
        for (int i = 0; i < N; i++) { for (int k = 0; k < i; k++) x[i] -= (up ? CM(a, L, k, i) : CM(a, L, i, k)) * x[k]; x[i] /= CM(a, L, i, i); }
        for (int i = N - 1; i >= 0; i--) { for (int k = i + 1; k < N; k++) x[i] -= (up ? CM(a, L, i, k) : CM(a, L, k, i)) * x[k]; x[i] /= CM(a, L, i, i); }
    }
    return 0;
}
int LA(posv)(char *uplo, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, T *b, __CLPK_integer *ldb, __CLPK_integer *info) {
    LA(potrf)(uplo, n, a, lda, info);
    if (*info == 0) LA(potrs)(uplo, n, nrhs, a, lda, b, ldb, info);
    return 0;
}
/* least squares (m >= n) or the minimum-norm solution (m < n) of op(A) X = B, by Householder QR in double */
int LA(gels)(char *trans, __CLPK_integer *m, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, T *b, __CLPK_integer *ldb,
             T *work, __CLPK_integer *lwork, __CLPK_integer *info) {
    int M = *m, N = *n, R = *nrhs, L = *lda, LB = *ldb, tr = (*trans == 'T' || *trans == 't');
    *info = 0;
    if (*lwork == -1) { int mn = M < N ? M : N; work[0] = (T)(mn + (mn > R ? mn : R)); return 0; }
    int rows = tr ? N : M, cols = tr ? M : N;                    /* op(A): rows x cols */
    /* least squares: QR of op(A) (qr x qc = rows x cols); minimum norm: QR of op(A)^T */
    int over = rows >= cols, qr = over ? rows : cols, qc = over ? cols : rows;
    size_t sz = (size_t)qr * qc + 1;
    double *q = malloc(sizeof(double) * sz), *v = calloc(sz, sizeof(double)), *tau = calloc((size_t)qc + 1, sizeof(double));
    double *y = malloc(sizeof(double) * ((size_t)qr + 1));
    for (int i = 0; i < qr; i++) for (int j = 0; j < qc; j++) {
        int oi = over ? i : j, oj = over ? j : i;               /* op(A) element (oi, oj) */
        q[(size_t)j * qr + i] = tr ? CM(a, L, oj, oi) : CM(a, L, oi, oj);
    }
    for (int k = 0; k < qc; k++) {                               /* H_k = I - tau v v^T zeroes column k below the diagonal */
        double *vk = &v[(size_t)k * qr], nrm = 0;
        for (int i = k; i < qr; i++) { vk[i] = q[(size_t)k * qr + i]; nrm += vk[i] * vk[i]; }
        nrm = sqrt(nrm);
        double alpha = vk[k] > 0 ? -nrm : nrm;
        vk[k] -= alpha;
        double vv = 0;
        for (int i = k; i < qr; i++) vv += vk[i] * vk[i];
        tau[k] = vv > 0 ? 2 / vv : 0;
        for (int j = k; j < qc; j++) {
            double s = 0;
            for (int i = k; i < qr; i++) s += vk[i] * q[(size_t)j * qr + i];
            s *= tau[k];
            for (int i = k; i < qr; i++) q[(size_t)j * qr + i] -= s * vk[i];
        }
    }
    int singular = 0;
    for (int i = 0; i < qc; i++) if (q[(size_t)i * qr + i] == 0) { *info = i + 1; singular = 1; break; }
    for (int r = 0; r < R && !singular; r++) {
        if (over) {
            for (int i = 0; i < qr; i++) y[i] = b[(size_t)r * LB + i];
            for (int k = 0; k < qc; k++) {                       /* Q^T b */
                double s = 0, *vk = &v[(size_t)k * qr];
                for (int i = k; i < qr; i++) s += vk[i] * y[i];
                s *= tau[k];
                for (int i = k; i < qr; i++) y[i] -= s * vk[i];
            }
            for (int i = qc - 1; i >= 0; i--) {                  /* R x = (Q^T b)[0, cols) */
                for (int j = i + 1; j < qc; j++) y[i] -= q[(size_t)j * qr + i] * y[j];
                y[i] /= q[(size_t)i * qr + i];
            }
        } else {
            /* op(A) = R^T Q^T: solve R^T z = b, then x = Q (z, 0) */
            for (int i = 0; i < qc; i++) {
                y[i] = b[(size_t)r * LB + i];
                for (int j = 0; j < i; j++) y[i] -= q[(size_t)i * qr + j] * y[j];
                y[i] /= q[(size_t)i * qr + i];
            }
            for (int i = qc; i < qr; i++) y[i] = 0;
            for (int k = qc - 1; k >= 0; k--) {
                double s = 0, *vk = &v[(size_t)k * qr];
                for (int i = k; i < qr; i++) s += vk[i] * y[i];
                s *= tau[k];
                for (int i = k; i < qr; i++) y[i] -= s * vk[i];
            }
        }
        for (int i = 0; i < cols; i++) b[(size_t)r * LB + i] = (T)y[i];
    }
    free(q); free(v); free(tau); free(y);
    return 0;
}
/* eigenvalues (ascending) and, with jobz 'V', eigenvectors (columns of a) of a symmetric matrix: cyclic Jacobi in double */
int LA(syev)(char *jobz, char *uplo, __CLPK_integer *n, T *a, __CLPK_integer *lda, T *w, T *work, __CLPK_integer *lwork, __CLPK_integer *info) {
    int N = *n, L = *lda, up = (*uplo == 'U' || *uplo == 'u'), vec = (*jobz == 'V' || *jobz == 'v');
    *info = 0;
    if (*lwork == -1) { work[0] = (T)(3 * N > 1 ? 3 * N - 1 : 1); return 0; }
    double *s = malloc(sizeof(double) * ((size_t)N * N + 1)), *v = malloc(sizeof(double) * ((size_t)N * N + 1));
    for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) {
        int ii = i, jj = j;
        if ((up && ii > jj) || (!up && ii < jj)) { ii = j; jj = i; }
        s[(size_t)j * N + i] = CM(a, L, ii, jj);
        v[(size_t)j * N + i] = i == j;
    }
    for (int sweep = 0; sweep < 100; sweep++) {
        double off = 0;
        for (int p = 0; p < N; p++) for (int q = p + 1; q < N; q++) off += s[(size_t)q * N + p] * s[(size_t)q * N + p];
        if (off < 1e-30) break;
        for (int p = 0; p < N; p++)
            for (int q = p + 1; q < N; q++) {
                double apq = s[(size_t)q * N + p];
                if (fabs(apq) < 1e-300) continue;
                double app = s[(size_t)p * N + p], aqq = s[(size_t)q * N + q];
                double theta = (aqq - app) / (2 * apq);
                double t = (theta >= 0 ? 1 : -1) / (fabs(theta) + sqrt(theta * theta + 1));
                double c = 1 / sqrt(t * t + 1), sn = t * c;
                for (int k = 0; k < N; k++) {                       /* S = J^T S J */
                    double skp = s[(size_t)p * N + k], skq = s[(size_t)q * N + k];
                    s[(size_t)p * N + k] = c * skp - sn * skq; s[(size_t)q * N + k] = sn * skp + c * skq;
                }
                for (int k = 0; k < N; k++) {
                    double spk = s[(size_t)k * N + p], sqk = s[(size_t)k * N + q];
                    s[(size_t)k * N + p] = c * spk - sn * sqk; s[(size_t)k * N + q] = sn * spk + c * sqk;
                }
                for (int k = 0; k < N; k++) {
                    double vkp = v[(size_t)p * N + k], vkq = v[(size_t)q * N + k];
                    v[(size_t)p * N + k] = c * vkp - sn * vkq; v[(size_t)q * N + k] = sn * vkp + c * vkq;
                }
            }
    }
    /* ascending order, each eigenvector's largest component positive is not required by LAPACK: keep Jacobi's */
    int *ord = malloc(sizeof(int) * (N + 1));
    for (int i = 0; i < N; i++) ord[i] = i;
    for (int i = 0; i < N; i++) for (int j = i + 1; j < N; j++)
        if (s[(size_t)ord[j] * N + ord[j]] < s[(size_t)ord[i] * N + ord[i]]) { int t = ord[i]; ord[i] = ord[j]; ord[j] = t; }
    for (int i = 0; i < N; i++) w[i] = (T)s[(size_t)ord[i] * N + ord[i]];
    if (vec) for (int j = 0; j < N; j++) for (int i = 0; i < N; i++) CM(a, L, i, j) = (T)v[(size_t)ord[j] * N + i];
    free(s); free(v); free(ord);
    return 0;
}

#undef FN2
#undef FN
#undef CB
#undef LP2
#undef LP1
#undef LA
#undef CBI2
#undef CBI1
#undef NM2
#undef NM1
#undef NM
#undef EL
#undef OP
#undef CM
