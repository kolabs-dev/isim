// isim Accelerate Sparse BLAS (issue #819) for one scalar type (T, R, CPLX, BP = the name suffix, BM = the matrix type,
// BTYPE = the type code; set by the including sparse_<type>.c). Adapted: matrices are coordinates until committed
// (sparse_commit, or the first operation that reads them), then compressed columns of scalars; duplicate entries are
// summed; a symmetric matrix uses its stated triangle (mirrored, not conjugated), a triangular one only its triangle.
// Permutations: row i of the result is row perm[i] (column likewise). Norms: ONE, TWO, INF as usual; R1 sums
// |re| + |im| (the 1-norm for real values).
#define BF__(a, b) a##_##b
#define BF_(a, b) BF__(a, b)
#define BF(name) BF_(name, BP)

static inline long bidx(long i, sparse_stride inc, long n) { return inc >= 0 ? i * inc : (n - 1 - i) * (-inc); }
static inline R r1abs(T v) {
#if CPLX
    return (R)(fabs((double)__real__ v) + fabs((double)__imag__ v));
#else
    return ABSV(v);
#endif
}
static inline T bget(const sp_bmat *m, long p) { return ((const T *)m->cval)[p]; }

static void blas_commit(sp_bmat *m) {
    long n = m->N, k = m->nnz;
    long *cp = calloc((size_t)n + 1, sizeof(long)), *rows = malloc(sizeof(long) * (size_t)(k ? k : 1)), *pos = malloc(sizeof(long) * (size_t)(n + 1));
    T *vals = malloc(sizeof(T) * (size_t)(k ? k : 1));
    if (!cp || !rows || !pos || !vals) { free(cp); free(rows); free(pos); free(vals); return; }
    for (long x = 0; x < k; x++) cp[m->ci[x] + 1]++;
    for (long j = 0; j < n; j++) cp[j + 1] += cp[j];
    memcpy(pos, cp, sizeof(long) * (size_t)(n + 1));
    const T *v = (const T *)m->v;
    for (long x = 0; x < k; x++) { long d = pos[m->ci[x]]++; rows[d] = m->ri[x]; vals[d] = v[x]; }
    long w = 0;
    for (long j = 0; j < n; j++) {   /* sort each column's rows, summing duplicates */
        long s = cp[j], e = cp[j + 1], start = w;
        for (long x = s + 1; x < e; x++) {
            long r = rows[x]; T t = vals[x]; long y = x - 1;
            while (y >= s && rows[y] > r) { rows[y + 1] = rows[y]; vals[y + 1] = vals[y]; y--; }
            rows[y + 1] = r; vals[y + 1] = t;
        }
        for (long x = s; x < e; x++) {
            if (w > start && rows[w - 1] == rows[x]) vals[w - 1] += vals[x];
            else { rows[w] = rows[x]; vals[w] = vals[x]; w++; }
        }
        cp[j] = start;
    }
    cp[n] = w;
    free(pos);
    m->cp = cp; m->crow = rows; m->cval = (unsigned char *)vals; m->cnnz = w; m->committed = 1;
    m->nnz = 0;
}
static sp_bmat *bm_of(BM A) { sp_bmat *m = sp_bmat_of(A); return m && m->type == BTYPE ? m : NULL; }
static int bm_ready(sp_bmat *m) { if (!m->committed) m->commit(m); return m->committed; }

BM BF(sparse_matrix_create)(sparse_dimension M, sparse_dimension N) {
    return (BM)sp_bmat_new(BTYPE, sizeof(T), (long)M, (long)N, blas_commit);
}
BM BF(sparse_matrix_block_create)(sparse_dimension Mb, sparse_dimension Nb, sparse_dimension k, sparse_dimension l) {
    if (!k || !l) return NULL;
    sp_bmat *m = sp_bmat_new(BTYPE, sizeof(T), (long)(Mb * k), (long)(Nb * l), blas_commit);
    if (!m) return NULL;
    m->blockmode = 1; m->Mb = (long)Mb; m->Nb = (long)Nb;
    m->roff = malloc(sizeof(long) * (size_t)(Mb + 1)); m->coff = malloc(sizeof(long) * (size_t)(Nb + 1));
    if (!m->roff || !m->coff) { sparse_matrix_destroy(m); return NULL; }
    for (long i = 0; i <= (long)Mb; i++) m->roff[i] = i * (long)k;
    for (long j = 0; j <= (long)Nb; j++) m->coff[j] = j * (long)l;
    return (BM)m;
}
BM BF(sparse_matrix_variable_block_create)(sparse_dimension Mb, sparse_dimension Nb, const sparse_dimension *K, const sparse_dimension *L) {
    if (!K || !L) return NULL;
    long M = 0, N = 0;
    for (long i = 0; i < (long)Mb; i++) M += (long)K[i];
    for (long j = 0; j < (long)Nb; j++) N += (long)L[j];
    sp_bmat *m = sp_bmat_new(BTYPE, sizeof(T), M, N, blas_commit);
    if (!m) return NULL;
    m->blockmode = 2; m->Mb = (long)Mb; m->Nb = (long)Nb;
    m->roff = malloc(sizeof(long) * (size_t)(Mb + 1)); m->coff = malloc(sizeof(long) * (size_t)(Nb + 1));
    if (!m->roff || !m->coff) { sparse_matrix_destroy(m); return NULL; }
    m->roff[0] = 0; m->coff[0] = 0;
    for (long i = 0; i < (long)Mb; i++) m->roff[i + 1] = m->roff[i] + (long)K[i];
    for (long j = 0; j < (long)Nb; j++) m->coff[j + 1] = m->coff[j] + (long)L[j];
    return (BM)m;
}

static sparse_status bm_push(sp_bmat *m, T val, long i, long j) {
    if (i < 0 || j < 0 || i >= m->M || j >= m->N) return SPARSE_ILLEGAL_PARAMETER;
    if (m->committed) sp_bmat_uncommit(m);
    if (!sp_bmat_reserve(m, 1)) return SPARSE_SYSTEM_ERROR;
    m->ri[m->nnz] = i; m->ci[m->nnz] = j; ((T *)m->v)[m->nnz] = val; m->nnz++;
    m->inserted = 1;
    return SPARSE_SUCCESS;
}
sparse_status BF(sparse_insert_entry)(BM A, T val, sparse_index i, sparse_index j) {
    sp_bmat *m = bm_of(A);
    return m ? bm_push(m, val, i, j) : SPARSE_ILLEGAL_PARAMETER;
}
sparse_status BF(sparse_insert_entries)(BM A, sparse_dimension N, const T *val, const sparse_index *indx, const sparse_index *jndx) {
    sp_bmat *m = bm_of(A);
    if (!m || (N && (!val || !indx || !jndx))) return SPARSE_ILLEGAL_PARAMETER;
    for (sparse_dimension k = 0; k < N; k++) { sparse_status s = bm_push(m, val[k], indx[k], jndx[k]); if (s) return s; }
    return SPARSE_SUCCESS;
}
sparse_status BF(sparse_insert_col)(BM A, sparse_index j, sparse_dimension nz, const T *val, const sparse_index *indx) {
    sp_bmat *m = bm_of(A);
    if (!m || (nz && (!val || !indx))) return SPARSE_ILLEGAL_PARAMETER;
    for (sparse_dimension k = 0; k < nz; k++) { sparse_status s = bm_push(m, val[k], indx[k], j); if (s) return s; }
    return SPARSE_SUCCESS;
}
sparse_status BF(sparse_insert_row)(BM A, sparse_index i, sparse_dimension nz, const T *val, const sparse_index *jndx) {
    sp_bmat *m = bm_of(A);
    if (!m || (nz && (!val || !jndx))) return SPARSE_ILLEGAL_PARAMETER;
    for (sparse_dimension k = 0; k < nz; k++) { sparse_status s = bm_push(m, val[k], i, jndx[k]); if (s) return s; }
    return SPARSE_SUCCESS;
}
sparse_status BF(sparse_insert_block)(BM A, const T *val, sparse_dimension row_stride, sparse_dimension col_stride, sparse_index bi, sparse_index bj) {
    sp_bmat *m = bm_of(A);
    if (!m || !m->blockmode || !val || bi < 0 || bj < 0 || bi >= m->Mb || bj >= m->Nb) return SPARSE_ILLEGAL_PARAMETER;
    for (long r = m->roff[bi]; r < m->roff[bi + 1]; r++)
        for (long c = m->coff[bj]; c < m->coff[bj + 1]; c++) {
            sparse_status s = bm_push(m, val[(r - m->roff[bi]) * (long)row_stride + (c - m->coff[bj]) * (long)col_stride], r, c);
            if (s) return s;
        }
    return SPARSE_SUCCESS;
}
sparse_status BF(sparse_extract_block)(BM A, sparse_index bi, sparse_index bj, sparse_dimension row_stride, sparse_dimension col_stride, T *val) {
    sp_bmat *m = bm_of(A);
    if (!m || !m->blockmode || !val || bi < 0 || bj < 0 || bi >= m->Mb || bj >= m->Nb || !bm_ready(m)) return SPARSE_ILLEGAL_PARAMETER;
    for (long r = m->roff[bi]; r < m->roff[bi + 1]; r++) for (long c = m->coff[bj]; c < m->coff[bj + 1]; c++)
        val[(r - m->roff[bi]) * (long)row_stride + (c - m->coff[bj]) * (long)col_stride] = 0;
    for (long c = m->coff[bj]; c < m->coff[bj + 1]; c++)
        for (long p = m->cp[c]; p < m->cp[c + 1]; p++) {
            long r = m->crow[p];
            if (r >= m->roff[bi] && r < m->roff[bi + 1]) val[(r - m->roff[bi]) * (long)row_stride + (c - m->coff[bj]) * (long)col_stride] = bget(m, p);
        }
    return SPARSE_SUCCESS;
}

/* the entries of the matrix's operator (a symmetric matrix's triangle mirrored, a triangular one's triangle only) */
typedef void (*bentry_fn)(void *ctx, long r, long c, T v);
static void bm_each(const sp_bmat *m, int trans, int conj, bentry_fn fn, void *ctx) {
    int sym = m->props & (SPARSE_UPPER_SYMMETRIC | SPARSE_LOWER_SYMMETRIC), tri = m->props & (SPARSE_UPPER_TRIANGULAR | SPARSE_LOWER_TRIANGULAR);
    int lower = m->props & (SPARSE_LOWER_SYMMETRIC | SPARSE_LOWER_TRIANGULAR);
    for (long c = 0; c < m->N; c++)
        for (long p = m->cp[c]; p < m->cp[c + 1]; p++) {
            long r = m->crow[p]; T v = bget(m, p);
            if ((sym || tri) && (lower ? r < c : r > c)) continue;
            if (conj) v = CONJ(v);
            if (trans) fn(ctx, c, r, v); else fn(ctx, r, c, v);
            if (sym && r != c) { if (trans) fn(ctx, r, c, v); else fn(ctx, c, r, v); }
        }
}

/* ---- extraction ---- */
typedef struct { long fixed; int by_row; long start; long n; long *idx; T *val; } line_ctx;
static void line_entry(void *ctx, long r, long c, T v) {
    line_ctx *l = ctx;
    long a = l->by_row ? r : c, b = l->by_row ? c : r;
    if (a != l->fixed || b < l->start) return;
    l->idx[l->n] = b; l->val[l->n] = v; l->n++;
}
static sparse_status extract_line(sp_bmat *m, int by_row, long fixed, long start, sparse_index *end, sparse_dimension nz, T *val, sparse_index *idx) {
    if (!m || !end || (nz && (!val || !idx)) || !bm_ready(m) || fixed < 0 || fixed >= (by_row ? m->M : m->N)) return SPARSE_ILLEGAL_PARAMETER;
    long cap = by_row ? m->N : m->M;
    line_ctx l = { fixed, by_row, start, 0, malloc(sizeof(long) * (size_t)(2 * cap + 1)), malloc(sizeof(T) * (size_t)(2 * cap + 1)) };
    if (!l.idx || !l.val) { free(l.idx); free(l.val); return SPARSE_SYSTEM_ERROR; }
    bm_each(m, 0, 0, line_entry, &l);
    for (long x = 1; x < l.n; x++) {   /* by index */
        long k = l.idx[x]; T v = l.val[x]; long y = x - 1;
        while (y >= 0 && l.idx[y] > k) { l.idx[y + 1] = l.idx[y]; l.val[y + 1] = l.val[y]; y--; }
        l.idx[y + 1] = k; l.val[y + 1] = v;
    }
    long n = l.n < (long)nz ? l.n : (long)nz;
    for (long x = 0; x < n; x++) { idx[x] = l.idx[x]; val[x] = l.val[x]; }
    *end = n < l.n ? l.idx[n] : cap;
    free(l.idx); free(l.val);
    return SPARSE_SUCCESS;
}
sparse_status BF(sparse_extract_sparse_row)(BM A, sparse_index row, sparse_index column_start, sparse_index *column_end, sparse_dimension nz, T *val, sparse_index *jndx) {
    return extract_line(bm_of(A), 1, row, column_start, column_end, nz, val, jndx);
}
sparse_status BF(sparse_extract_sparse_column)(BM A, sparse_index column, sparse_index row_start, sparse_index *row_end, sparse_dimension nz, T *val, sparse_index *indx) {
    return extract_line(bm_of(A), 0, column, row_start, row_end, nz, val, indx);
}

/* ---- sparse vectors ---- */
long BF(sparse_get_vector_nonzero_count)(sparse_dimension N, const T *x, sparse_stride incx) {
    long c = 0;
    for (long i = 0; i < (long)N; i++) if (x[bidx(i, incx, (long)N)] != (T)0) c++;
    return c;
}
long BF(sparse_pack_vector)(sparse_dimension N, sparse_dimension nz, const T *x, sparse_stride incx, T *y, sparse_index *indy) {
    long c = 0;
    for (long i = 0; i < (long)N && c < (long)nz; i++) { T v = x[bidx(i, incx, (long)N)]; if (v != (T)0) { y[c] = v; indy[c] = i; c++; } }
    return c;
}
void BF(sparse_unpack_vector)(sparse_dimension N, sparse_dimension nz, bool zero, const T *x, const sparse_index *indx, T *y, sparse_stride incy) {
    if (zero) for (long i = 0; i < (long)N; i++) y[bidx(i, incy, (long)N)] = 0;
    for (long k = 0; k < (long)nz; k++) if (indx[k] >= 0 && indx[k] < (long)N) y[bidx(indx[k], incy, (long)N)] = x[k];
}
T BF(sparse_inner_product_dense)(sparse_dimension nz, const T *x, const sparse_index *indx, const T *y, sparse_stride incy) {
    T s = 0;
    long n = 0; for (long k = 0; k < (long)nz; k++) if (indx[k] + 1 > n) n = indx[k] + 1;
    for (long k = 0; k < (long)nz; k++) s += x[k] * y[bidx(indx[k], incy, n)];
    return s;
}
T BF(sparse_inner_product_sparse)(sparse_dimension nzx, sparse_dimension nzy, const T *x, const sparse_index *indx, const T *y, const sparse_index *indy) {
    T s = 0;
    long a = 0, b = 0;   /* both index lists ascending */
    while (a < (long)nzx && b < (long)nzy) {
        if (indx[a] == indy[b]) { s += x[a] * y[b]; a++; b++; }
        else if (indx[a] < indy[b]) a++; else b++;
    }
    return s;
}
void BF(sparse_vector_add_with_scale_dense)(sparse_dimension nz, T alpha, const T *x, const sparse_index *indx, T *y, sparse_stride incy) {
    long n = 0; for (long k = 0; k < (long)nz; k++) if (indx[k] + 1 > n) n = indx[k] + 1;
    for (long k = 0; k < (long)nz; k++) y[bidx(indx[k], incy, n)] += alpha * x[k];
}
double BF(sparse_vector_norm)(sparse_dimension nz, const T *x, const sparse_index *indx, sparse_norm norm) {
    (void)indx;
    double s = 0;
    for (long k = 0; k < (long)nz; k++) {
        double a = (double)ABSV(x[k]);
        switch (norm) {
        case SPARSE_NORM_ONE: s += a; break;
        case SPARSE_NORM_TWO: s += a * a; break;
        case SPARSE_NORM_INF: if (a > s) s = a; break;
        default: s += (double)r1abs(x[k]); break;
        }
    }
    return norm == SPARSE_NORM_TWO ? sqrt(s) : s;
}

/* ---- products ---- */
static int op_flags(enum CBLAS_TRANSPOSE t, int *trans, int *conj) {
    *trans = t != CblasNoTrans; *conj = CPLX && t == CblasConjTrans;
    return t == CblasNoTrans || t == CblasTrans || t == CblasConjTrans;
}
typedef struct { T alpha; const T *x; sparse_stride incx; long nx; T *y; sparse_stride incy; long ny; } mv_ctx;
static void mv_entry(void *ctx, long r, long c, T v) { mv_ctx *q = ctx; q->y[bidx(r, q->incy, q->ny)] += q->alpha * v * q->x[bidx(c, q->incx, q->nx)]; }
sparse_status BF(sparse_matrix_vector_product_dense)(enum CBLAS_TRANSPOSE transa, T alpha, BM A, const T *x, sparse_stride incx, T *y, sparse_stride incy) {
    sp_bmat *m = bm_of(A); int tr, cj;
    if (!m || !x || !y || !op_flags(transa, &tr, &cj) || !bm_ready(m)) return SPARSE_ILLEGAL_PARAMETER;
    mv_ctx q = { alpha, x, incx, tr ? m->M : m->N, y, incy, tr ? m->N : m->M };
    bm_each(m, tr, cj, mv_entry, &q);
    return SPARSE_SUCCESS;
}
typedef struct { T alpha; const T *B; long ldb; T *C; long ldc; long n; int row; } mm_ctx;
static void mm_entry(void *ctx, long r, long c, T v) {
    mm_ctx *q = ctx;
    for (long j = 0; j < q->n; j++) {
        T b = q->row ? q->B[c * q->ldb + j] : q->B[j * q->ldb + c];
        if (q->row) q->C[r * q->ldc + j] += q->alpha * v * b; else q->C[j * q->ldc + r] += q->alpha * v * b;
    }
}
sparse_status BF(sparse_matrix_product_dense)(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa, sparse_dimension n, T alpha, BM A,
                                              const T *B, sparse_dimension ldb, T *C, sparse_dimension ldc) {
    sp_bmat *m = bm_of(A); int tr, cj;
    if (!m || !B || !C || !op_flags(transa, &tr, &cj) || !bm_ready(m) || (order != CblasColMajor && order != CblasRowMajor)) return SPARSE_ILLEGAL_PARAMETER;
    mm_ctx q = { alpha, B, (long)ldb, C, (long)ldc, (long)n, order == CblasRowMajor };
    bm_each(m, tr, cj, mm_entry, &q);
    return SPARSE_SUCCESS;
}
/* C += alpha op(A) B, B sparse */
typedef struct { long n; long *cp; long *k; long *r; T *v; long cnt; } list_ctx;
static void list_count(void *ctx, long r, long c, T v) { (void)r; (void)v; list_ctx *l = ctx; l->cp[c + 1]++; l->cnt++; }
static void list_fill(void *ctx, long r, long c, T v) { list_ctx *l = ctx; long d = l->k[c]++; l->r[d] = r; l->v[d] = v; }
static int bm_columns(const sp_bmat *m, int tr, int cj, list_ctx *l) {
    long n = tr ? m->M : m->N;
    l->n = n; l->cnt = 0;
    l->cp = calloc((size_t)n + 1, sizeof(long)); l->k = malloc(sizeof(long) * (size_t)(n + 1));
    if (!l->cp || !l->k) return 0;
    bm_each(m, tr, cj, list_count, l);
    for (long j = 0; j < n; j++) l->cp[j + 1] += l->cp[j];
    memcpy(l->k, l->cp, sizeof(long) * (size_t)(n + 1));
    l->r = malloc(sizeof(long) * (size_t)(l->cnt ? l->cnt : 1)); l->v = malloc(sizeof(T) * (size_t)(l->cnt ? l->cnt : 1));
    if (!l->r || !l->v) return 0;
    bm_each(m, tr, cj, list_fill, l);
    return 1;
}
static void list_free(list_ctx *l) { free(l->cp); free(l->k); free(l->r); free(l->v); }
typedef struct { list_ctx *a; T alpha; T *C; long ldc; int row; } ms_ctx;
static void ms_entry(void *ctx, long k, long j, T b) {
    ms_ctx *q = ctx;
    for (long p = q->a->cp[k]; p < q->a->cp[k + 1]; p++) {
        long r = q->a->r[p];
        T *c = q->row ? &q->C[r * q->ldc + j] : &q->C[j * q->ldc + r];
        *c += q->alpha * q->a->v[p] * b;
    }
}
sparse_status BF(sparse_matrix_product_sparse)(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa, T alpha, BM A, BM B, T *C, sparse_dimension ldc) {
    sp_bmat *a = bm_of(A), *b = bm_of(B); int tr, cj;
    if (!a || !b || !C || !op_flags(transa, &tr, &cj) || !bm_ready(a) || !bm_ready(b)) return SPARSE_ILLEGAL_PARAMETER;
    if ((tr ? a->M : a->N) != b->M) return SPARSE_ILLEGAL_PARAMETER;
    list_ctx l = { 0 };
    if (!bm_columns(a, tr, cj, &l)) { list_free(&l); return SPARSE_SYSTEM_ERROR; }
    ms_ctx q = { &l, alpha, C, (long)ldc, order == CblasRowMajor };
    bm_each(b, 0, 0, ms_entry, &q);
    list_free(&l);
    return SPARSE_SUCCESS;
}

/* ---- triangular solves: x = alpha op(T)^-1 x ---- */
static sparse_status tri_solve(sp_bmat *m, enum CBLAS_TRANSPOSE t, T alpha, T *x, long stride_i, long stride_j, long nrhs) {
    int tr, cj;
    if (!m || !x || !op_flags(t, &tr, &cj) || !bm_ready(m)) return SPARSE_ILLEGAL_PARAMETER;
    if (!(m->props & (SPARSE_UPPER_TRIANGULAR | SPARSE_LOWER_TRIANGULAR)) || m->M != m->N) return SPARSE_ILLEGAL_PARAMETER;
    int lower = (m->props & SPARSE_LOWER_TRIANGULAR) != 0;
    if (tr) lower = !lower;
    list_ctx l = { 0 };
    if (!bm_columns(m, tr, cj, &l)) { list_free(&l); return SPARSE_SYSTEM_ERROR; }
    long n = m->N;
    T *d = calloc((size_t)(n ? n : 1), sizeof(T));
    if (!d) { list_free(&l); return SPARSE_SYSTEM_ERROR; }
    for (long j = 0; j < n; j++) for (long p = l.cp[j]; p < l.cp[j + 1]; p++) if (l.r[p] == j) d[j] += l.v[p];
    sparse_status st = SPARSE_SUCCESS;
    for (long j = 0; j < n; j++) if (d[j] == (T)0) st = SPARSE_ILLEGAL_PARAMETER;
    if (!st) for (long c = 0; c < nrhs; c++) {
        #define XX(i) x[(i) * stride_i + c * stride_j]
        for (long i = 0; i < n; i++) XX(i) *= alpha;
        for (long t2 = 0; t2 < n; t2++) {   /* column-oriented substitution */
            long j = lower ? t2 : n - 1 - t2;
            XX(j) /= d[j];
            T xj = XX(j);
            for (long p = l.cp[j]; p < l.cp[j + 1]; p++) if (l.r[p] != j) XX(l.r[p]) -= l.v[p] * xj;
        }
        #undef XX
    }
    free(d); list_free(&l);
    return st;
}
sparse_status BF(sparse_vector_triangular_solve_dense)(enum CBLAS_TRANSPOSE transt, T alpha, BM Tm, T *x, sparse_stride incx) {
    sp_bmat *m = bm_of(Tm);
    if (!m) return SPARSE_ILLEGAL_PARAMETER;
    if (incx < 0) {   /* walk the vector from its end */
        long n = m->N;
        T *t = malloc(sizeof(T) * (size_t)(n ? n : 1));
        if (!t) return SPARSE_SYSTEM_ERROR;
        for (long i = 0; i < n; i++) t[i] = x[bidx(i, incx, n)];
        sparse_status s = tri_solve(m, transt, alpha, t, 1, 0, 1);
        for (long i = 0; i < n; i++) x[bidx(i, incx, n)] = t[i];
        free(t);
        return s;
    }
    return tri_solve(m, transt, alpha, x, incx, 0, 1);
}
sparse_status BF(sparse_matrix_triangular_solve_dense)(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transt, sparse_dimension nrhs, T alpha, BM Tm,
                                                       T *B, sparse_dimension ldb) {
    if (order != CblasColMajor && order != CblasRowMajor) return SPARSE_ILLEGAL_PARAMETER;
    return order == CblasColMajor ? tri_solve(bm_of(Tm), transt, alpha, B, 1, (long)ldb, (long)nrhs)
                                  : tri_solve(bm_of(Tm), transt, alpha, B, (long)ldb, 1, (long)nrhs);
}

sparse_status BF(sparse_outer_product_dense)(sparse_dimension M, sparse_dimension N, sparse_dimension nz, T alpha, const T *x, sparse_stride incx,
                                             const T *y, const sparse_index *indy, BM *C) {
    if (!C || !x || (nz && (!y || !indy))) return SPARSE_ILLEGAL_PARAMETER;
    if (!*C) *C = BF(sparse_matrix_create)(M, N);
    sp_bmat *m = bm_of(*C);
    if (!m || m->M != (long)M || m->N != (long)N) return SPARSE_ILLEGAL_PARAMETER;
    for (long i = 0; i < (long)M; i++) {
        T xi = x[bidx(i, incx, (long)M)];
        if (xi == (T)0) continue;
        for (long k = 0; k < (long)nz; k++) { sparse_status s = bm_push(m, alpha * xi * y[k], i, indy[k]); if (s) return s; }
    }
    return sparse_commit(m);
}

static sparse_status permute(sp_bmat *m, const sparse_index *perm, int rows) {
    if (!m || !perm || !bm_ready(m)) return SPARSE_ILLEGAL_PARAMETER;
    long n = rows ? m->M : m->N;
    long *inv = malloc(sizeof(long) * (size_t)(n ? n : 1));
    if (!inv) return SPARSE_SYSTEM_ERROR;
    for (long i = 0; i < n; i++) inv[i] = -1;
    for (long i = 0; i < n; i++) { if (perm[i] < 0 || perm[i] >= n || inv[perm[i]] >= 0) { free(inv); return SPARSE_ILLEGAL_PARAMETER; } inv[perm[i]] = i; }
    sp_bmat_uncommit(m);
    for (long x = 0; x < m->nnz; x++) { if (rows) m->ri[x] = inv[m->ri[x]]; else m->ci[x] = inv[m->ci[x]]; }
    free(inv);
    return sparse_commit(m);
}
sparse_status BF(sparse_permute_rows)(BM A, const sparse_index *perm) { return permute(bm_of(A), perm, 1); }
sparse_status BF(sparse_permute_cols)(BM A, const sparse_index *perm) { return permute(bm_of(A), perm, 0); }

/* ---- norms and trace ---- */
typedef struct { sparse_norm norm; double s; double *acc; int rows; } norm_ctx;
static void enorm_entry(void *ctx, long r, long c, T v) {
    (void)r; (void)c; norm_ctx *q = ctx; double a = (double)ABSV(v);
    switch (q->norm) {
    case SPARSE_NORM_ONE: q->s += a; break;
    case SPARSE_NORM_TWO: q->s += a * a; break;
    case SPARSE_NORM_INF: if (a > q->s) q->s = a; break;
    default: q->s += (double)r1abs(v); break;
    }
}
double BF(sparse_elementwise_norm)(BM A, sparse_norm norm) {
    sp_bmat *m = bm_of(A);
    if (!m || !bm_ready(m)) return NAN;
    norm_ctx q = { norm, 0, NULL, 0 };
    bm_each(m, 0, 0, enorm_entry, &q);
    return norm == SPARSE_NORM_TWO ? sqrt(q.s) : q.s;
}
static void onorm_entry(void *ctx, long r, long c, T v) {
    norm_ctx *q = ctx;
    q->acc[q->rows ? r : c] += q->norm == SPARSE_NORM_R1 ? (double)r1abs(v) : (double)ABSV(v);
}
typedef struct { const T *x; T *y; } pw_ctx;
static void pw_entry(void *ctx, long r, long c, T v) { pw_ctx *q = ctx; q->y[r] += v * q->x[c]; }
double BF(sparse_operator_norm)(BM A, sparse_norm norm) {
    sp_bmat *m = bm_of(A);
    if (!m || !bm_ready(m)) return NAN;
    if (norm == SPARSE_NORM_TWO) {   /* the largest singular value: power iteration on A^H A */
        long n = m->N, mm = m->M;
        T *x = malloc(sizeof(T) * (size_t)(n ? n : 1)), *y = malloc(sizeof(T) * (size_t)(mm ? mm : 1)), *z = malloc(sizeof(T) * (size_t)(n ? n : 1));
        double sigma = 0;
        if (x && y && z && n) {
            for (long i = 0; i < n; i++) x[i] = (T)(1.0 / sqrt((double)n)) * (T)(1 + 0.01 * (double)(i % 7));
            for (int it = 0; it < 500; it++) {
                for (long i = 0; i < mm; i++) y[i] = 0;
                pw_ctx a = { x, y }; bm_each(m, 0, 0, pw_entry, &a);
                for (long i = 0; i < n; i++) z[i] = 0;
                pw_ctx b = { y, z }; bm_each(m, 1, 1, pw_entry, &b);
                double nz = 0; for (long i = 0; i < n; i++) { double t = (double)ABSV(z[i]); nz += t * t; }
                nz = sqrt(nz);
                double s = sqrt(nz);
                if (nz == 0) { sigma = 0; break; }
                for (long i = 0; i < n; i++) x[i] = z[i] / (T)nz;
                if (fabs(s - sigma) <= 1e-12 * s) { sigma = s; break; }
                sigma = s;
            }
        }
        free(x); free(y); free(z);
        return sigma;
    }
    int rows = norm == SPARSE_NORM_INF;
    long n = rows ? m->M : m->N;
    norm_ctx q = { norm, 0, calloc((size_t)(n ? n : 1), sizeof(double)), rows };
    if (!q.acc) return NAN;
    bm_each(m, 0, 0, onorm_entry, &q);
    double mx = 0; for (long i = 0; i < n; i++) if (q.acc[i] > mx) mx = q.acc[i];
    free(q.acc);
    return mx;
}
typedef struct { long off; T s; } trace_ctx;
static void trace_entry(void *ctx, long r, long c, T v) { trace_ctx *q = ctx; if (c - r == q->off) q->s += v; }
T BF(sparse_matrix_trace)(BM A, sparse_index offset) {
    sp_bmat *m = bm_of(A);
    if (!m || !bm_ready(m)) return 0;
    trace_ctx q = { offset, 0 };
    bm_each(m, 0, 0, trace_entry, &q);
    return q.s;
}

/* ---- SparseConvertFromOpaque ---- */
SM FN(_SparseConvertFromOpaque)(BM A) {
    SM r; memset(&r, 0, sizeof r);
    sp_bmat *m = bm_of(A);
    if (!m || !bm_ready(m) || m->M > 2147483647 || m->N > 2147483647) return r;
    long *cs = malloc(sizeof(long) * (size_t)(m->N + 1));
    int *ri = malloc(sizeof(int) * (size_t)(m->cnnz ? m->cnnz : 1));
    T *v = malloc(sizeof(T) * (size_t)(m->cnnz ? m->cnnz : 1));
    if (!cs || !ri || !v) { free(cs); free(ri); free(v); return r; }
    memcpy(cs, m->cp, sizeof(long) * (size_t)(m->N + 1));
    for (long p = 0; p < m->cnnz; p++) { ri[p] = (int)m->crow[p]; v[p] = bget(m, p); }
    r.structure.rowCount = (int)m->M; r.structure.columnCount = (int)m->N;
    r.structure.columnStarts = cs; r.structure.rowIndices = ri; r.structure.blockSize = 1;
    if (m->props & (SPARSE_UPPER_SYMMETRIC | SPARSE_LOWER_SYMMETRIC)) r.structure.attributes.kind = SparseSymmetric;
    else if (m->props & (SPARSE_UPPER_TRIANGULAR | SPARSE_LOWER_TRIANGULAR)) r.structure.attributes.kind = SparseTriangular;
    r.structure.attributes.triangle = (m->props & (SPARSE_LOWER_SYMMETRIC | SPARSE_LOWER_TRIANGULAR)) ? SparseLowerTriangle : SparseUpperTriangle;
    r.structure.attributes._allocatedBySparse = 1;
    r.data = v;
    return r;
}
