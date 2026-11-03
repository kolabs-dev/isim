// isim Accelerate Sparse Solvers (issue #807): the engine for one scalar type (X, T, R, CPLX set by the including
// file): matrices from coordinates, products, the direct factorizations and their solves and subfactors. Adapted:
//  - matrices are expanded to the full operator (blocks, transposes, the mirrored triangle of a symmetric or Hermitian
//    matrix, a unit diagonal) before factoring;
//  - Cholesky and unpivoted LDL^T are up-looking sparse factorizations of P S A S P' (S: the equilibration or user
//    scaling, P: the symbolic order); the pivoted LDL^T variants (LDLT, LDLTSBK, LDLTTPP) keep that factorization
//    while its multipliers stay below 1 / pivotTolerance, otherwise they factor the ordered matrix densely with
//    Bunch-Kaufman pivoting (1x1 and 2x2 blocks) and store L sparse (up to 3000 columns);
//  - the LU variants are left-looking (Gilbert-Peierls) on the ordered columns with threshold partial pivoting
//    (unpivoted: the diagonal);
//  - QR is Householder, V and R stored sparse, of A (or of A^H when A is wide); CholeskyAtA factors A^H A;
//  - workspace and factor storage passed in are not used: isim allocates its own.
#define SP_CAT_(a, b) a##_##b
#define SP_CAT(a, b) SP_CAT_(a, b)
#define FN(name) SP_CAT(name, X)
#define DM SP_CAT(DenseMatrix, X)
#define DV SP_CAT(DenseVector, X)
#define SM SP_CAT(SparseMatrix, X)
#define OF SP_CAT(SparseOpaqueFactorization, X)
#define OS SP_CAT(SparseOpaqueSubfactor, X)
#define OP SP_CAT(SparseOpaquePreconditioner, X)

/* ---- dense matrices ---- */
static inline T *dm_at(DM d, int i, int j) { return d.attributes.transpose ? d.data + (long)i * d.columnStride + j : d.data + (long)j * d.columnStride + i; }
static inline int is_zero(T v) { return v == (T)0; }

/* ---- the entries of a sparse matrix's operator ---- */
typedef void (*entry_fn)(void *ctx, int r, int c, T v);
static int sm_kind(SM A) { return (int)A.structure.attributes.kind; }
static int sm_trans(SM A) {
#if CPLX
    return A.structure.attributes.transpose || A.structure.attributes.conjugate_transpose;
#else
    return A.structure.attributes.transpose;
#endif
}
static int sm_conj(SM A) {
#if CPLX
    return A.structure.attributes.conjugate_transpose && !A.structure.attributes.transpose;
#else
    (void)A; return 0;
#endif
}
static void sm_dims(SM A, int *m, int *n) {
    int b = A.structure.blockSize ? A.structure.blockSize : 1;
    int M = A.structure.rowCount * b, N = A.structure.columnCount * b;
    if (sm_trans(A)) { *m = N; *n = M; } else { *m = M; *n = N; }
}
/* calls fn for every entry of op(A) (duplicates possible) */
static void sm_entries(SM A, entry_fn fn, void *ctx) {
    SparseMatrixStructure s0 = { A.structure.rowCount, A.structure.columnCount, A.structure.columnStarts, A.structure.rowIndices, { 0 }, A.structure.blockSize };
    (void)s0;
    int b = A.structure.blockSize ? A.structure.blockSize : 1, kind = sm_kind(A), tr = sm_trans(A), cj = sm_conj(A);
    int sym = kind == SparseSymmetric, herm = kind == 4, unit = kind == SparseUnitTriangular, tri = kind == SparseTriangular || unit;
    int lower = A.structure.attributes.triangle == SparseLowerTriangle;
    for (int J = 0; J < A.structure.columnCount; J++)
        for (long p = A.structure.columnStarts[J]; p < A.structure.columnStarts[J + 1]; p++)
            for (int bj = 0; bj < b; bj++) for (int bi = 0; bi < b; bi++) {
                int i = A.structure.rowIndices[p] * b + bi, j = J * b + bj;
                if ((sym || herm || tri) && (lower ? i < j : i > j)) continue;
                if (unit && i == j) continue;
                T v = A.data[p * b * b + (long)bj * b + bi];
                if (tr) fn(ctx, j, i, cj ? CONJ(v) : v); else fn(ctx, i, j, v);
                if ((sym || herm) && i != j) {
                    T w = herm ? CONJ(v) : v;
                    if (tr) fn(ctx, i, j, cj ? CONJ(w) : w); else fn(ctx, j, i, w);
                }
            }
    if (unit) { int M = A.structure.rowCount * b, N = A.structure.columnCount * b; for (int d = 0; d < (M < N ? M : N); d++) fn(ctx, d, d, (T)1); }
}

/* ---- compressed columns with values ---- */
typedef struct { int m, n; long *p; int *i; T *x; } csc;
static void csc_free(csc *a) { free(a->p); free(a->i); free(a->x); a->p = NULL; a->i = NULL; a->x = NULL; }
typedef struct { long k, cap; int *r, *c; T *v; int ok; } coo;
static void coo_add(void *ctx, int r, int c, T v) {
    coo *q = ctx;
    if (!q->ok) return;
    if (q->k == q->cap) {
        long nc = q->cap ? q->cap * 2 : 64;
        int *nr = realloc(q->r, sizeof(int) * (size_t)nc), *ncc = nr ? realloc(q->c, sizeof(int) * (size_t)nc) : NULL;
        T *nv = ncc ? realloc(q->v, sizeof(T) * (size_t)nc) : NULL;
        if (nr) q->r = nr;
        if (ncc) q->c = ncc;
        if (!nv) { q->ok = 0; return; }
        q->v = nv; q->cap = nc;
    }
    q->r[q->k] = r; q->c[q->k] = c; q->v[q->k] = v; q->k++;
}
/* coordinates to compressed columns, summing duplicates */
static int coo_to_csc(coo *q, int m, int n, csc *out) {
    out->m = m; out->n = n;
    out->p = calloc((size_t)n + 1, sizeof(long)); out->i = malloc(sizeof(int) * (size_t)(q->k ? q->k : 1)); out->x = malloc(sizeof(T) * (size_t)(q->k ? q->k : 1));
    long *pos = malloc(sizeof(long) * (size_t)(n + 1)); int *mark = malloc(sizeof(int) * (size_t)(m ? m : 1));
    if (!out->p || !out->i || !out->x || !pos || !mark) { free(pos); free(mark); csc_free(out); return 0; }
    for (long x = 0; x < q->k; x++) out->p[q->c[x] + 1]++;
    for (int j = 0; j < n; j++) out->p[j + 1] += out->p[j];
    memcpy(pos, out->p, sizeof(long) * (size_t)(n + 1));
    int *ti = malloc(sizeof(int) * (size_t)(q->k ? q->k : 1)); T *tx = malloc(sizeof(T) * (size_t)(q->k ? q->k : 1));
    if (!ti || !tx) { free(ti); free(tx); free(pos); free(mark); csc_free(out); return 0; }
    for (long x = 0; x < q->k; x++) { long d = pos[q->c[x]]++; ti[d] = q->r[x]; tx[d] = q->v[x]; }
    for (int i = 0; i < m; i++) mark[i] = -1;
    long w = 0;
    for (int j = 0; j < n; j++) {   /* merge duplicates, then sort the column's rows */
        long s = w;
        for (long x = out->p[j]; x < out->p[j + 1]; x++) {
            int r = ti[x];
            if (mark[r] >= s) out->x[mark[r]] += tx[x];
            else { mark[r] = (int)w; out->i[w] = r; out->x[w] = tx[x]; w++; }
        }
        for (long x = s + 1; x < w; x++) {
            int r = out->i[x]; T v = out->x[x]; long y = x - 1;
            while (y >= s && out->i[y] > r) { out->i[y + 1] = out->i[y]; out->x[y + 1] = out->x[y]; y--; }
            out->i[y + 1] = r; out->x[y + 1] = v;
        }
        out->p[j] = s;
        for (long x = s; x < w; x++) mark[out->i[x]] = (int)(long)-1;
    }
    out->p[n] = w;
    free(ti); free(tx); free(pos); free(mark);
    return 1;
}
static int sm_expand(SM A, csc *out) {
    int m, n; sm_dims(A, &m, &n);
    coo q = { 0, 0, NULL, NULL, NULL, 1 };
    sm_entries(A, coo_add, &q);
    int ok = q.ok && coo_to_csc(&q, m, n, out);
    free(q.r); free(q.c); free(q.v);
    return ok;
}

/* ---- creation ---- */
SM FN(_SparseConvertFromCoordinate)(int rowCount, int columnCount, long blockCount, uint8_t blockSize, ATTR attributes,
                                    const int *row, const int *column, const T *data, void *storage, void *workspace) {
    SM A; memset(&A, 0, sizeof A);
    int b = blockSize ? blockSize : 1;
    A.structure.rowCount = rowCount; A.structure.columnCount = columnCount; A.structure.attributes = attributes;
    A.structure.blockSize = (uint8_t)b;
    long bb = (long)b * b;
    /* count the blocks per column, merging duplicate coordinates (their values summed) */
    long *starts; int *rows; T *vals;
    long nnzcap = blockCount ? blockCount : 1;
    if (storage) {   /* Apple's layout of the storage argument: column starts, row indices, then values */
        starts = storage; rows = (int *)(starts + columnCount + 1);
        vals = (T *)(((uintptr_t)(rows + nnzcap) + sizeof(T) - 1) / sizeof(T) * sizeof(T));
    } else {
        starts = calloc((size_t)columnCount + 1, sizeof(long)); rows = malloc(sizeof(int) * (size_t)nnzcap); vals = malloc(sizeof(T) * (size_t)(nnzcap * bb));
        if (!starts || !rows || !vals) { free(starts); free(rows); free(vals); return A; }
    }
    (void)workspace;
    memset(starts, 0, sizeof(long) * (size_t)(columnCount + 1));
    for (long k = 0; k < blockCount; k++) if (column[k] >= 0 && column[k] < columnCount && row[k] >= 0 && row[k] < rowCount) starts[column[k] + 1]++;
    for (int j = 0; j < columnCount; j++) starts[j + 1] += starts[j];
    long *pos = malloc(sizeof(long) * (size_t)(columnCount + 1));
    long *src = malloc(sizeof(long) * (size_t)nnzcap);
    if (!pos || !src) { free(pos); free(src); if (!storage) { free(starts); free(rows); free(vals); } return A; }
    memcpy(pos, starts, sizeof(long) * (size_t)(columnCount + 1));
    for (long k = 0; k < blockCount; k++) if (column[k] >= 0 && column[k] < columnCount && row[k] >= 0 && row[k] < rowCount) { long d = pos[column[k]]++; rows[d] = row[k]; src[d] = k; }
    long w = 0;
    for (int j = 0; j < columnCount; j++) {
        long s = starts[j], e = starts[j + 1];
        for (long x = s + 1; x < e; x++) {   /* sort by row */
            int r = rows[x]; long sk = src[x], y = x - 1;
            while (y >= s && rows[y] > r) { rows[y + 1] = rows[y]; src[y + 1] = src[y]; y--; }
            rows[y + 1] = r; src[y + 1] = sk;
        }
        starts[j] = w;
        for (long x = s; x < e; x++) {
            if (x > s && rows[x] == rows[x - 1]) { for (long t = 0; t < bb; t++) vals[(w - 1) * bb + t] += data[src[x] * bb + t]; continue; }
            rows[w] = rows[x];
            for (long t = 0; t < bb; t++) vals[w * bb + t] = data[src[x] * bb + t];
            w++;
        }
    }
    starts[columnCount] = w;
    free(pos); free(src);
    A.structure.columnStarts = starts; A.structure.rowIndices = rows; A.data = vals;
    A.structure.attributes._allocatedBySparse = storage == NULL;
    return A;
}
void FN(_SparseCleanupMatrix)(SM A) {
    if (!A.structure.attributes._allocatedBySparse) return;
    free(A.structure.columnStarts); free(A.structure.rowIndices); free(A.data);
}

/* ---- products: y = alpha op(A) x (+ y) ---- */
typedef struct { DM x, y; T alpha; } mul_ctx;
static void mul_entry(void *ctx, int r, int c, T v) {
    mul_ctx *m = ctx;
    for (int k = 0; k < m->x.columnCount; k++) *dm_at(m->y, r, k) += m->alpha * v * *dm_at(m->x, c, k);
}
void FN(_SparseMultiply)(T alpha, SM A, DM x, DM y, bool accumulate) {
    int m, n; sm_dims(A, &m, &n);
    if (x.rowCount < n || y.rowCount < m || x.columnCount != y.columnCount) { sp_report(NULL, "SparseMultiply: the dimensions don't match"); return; }
    if (!accumulate) for (int k = 0; k < y.columnCount; k++) for (int i = 0; i < m; i++) *dm_at(y, i, k) = 0;
    mul_ctx c = { x, y, alpha };
    sm_entries(A, mul_entry, &c);
}

/* op(A) with an operator's transpose argument: CblasConjTrans conjugates complex matrices */
void FN(_SparseMultiplyOp)(SM A, enum CBLAS_TRANSPOSE trans, DM x, DM y, bool accumulate) {
#if CPLX
    if (trans == CblasConjTrans) A.structure.attributes.conjugate_transpose = !A.structure.attributes.conjugate_transpose;
    else if (trans == CblasTrans) A.structure.attributes.transpose = !A.structure.attributes.transpose;
#else
    if (trans != CblasNoTrans) A.structure.attributes.transpose = !A.structure.attributes.transpose;
#endif
    FN(_SparseMultiply)((T)1, A, x, y, accumulate);
}

/* ---- the numeric factorization ---- */
typedef struct num {
    int refs;
    sp_symbolic *sym;
    SparseFactorization_t type;
    int m, n;
    int herm;             /* conjugate in L D L^H (real symmetric and Hermitian); 0: complex symmetric L D L^T */
    int *perm, *iperm;    /* position -> original index, and back (symmetric / LU columns / QR columns) */
    R *scale;             /* symmetric scaling S, or NULL */
    long *Lp; int *Li; T *Lx;   /* symmetric: unit L strictly below the diagonal; LU: unit L incl. its diagonal */
    T *D, *Doff; char *blk;     /* D's diagonal; 2x2 blocks: Doff[k] = D(k+1,k), blk[k] = 1 at the block's first column */
    long *Up; int *Ui; T *Ux;   /* LU: U; QR / CholeskyAtA: R */
    int *pinv;                  /* LU: original row -> pivot position */
    long *Vp; int *Vi; T *Vx; T *beta;   /* QR: Householder vectors and their coefficients */
    int transposedQR;
    csc A;                      /* CholeskyAtA: the matrix, for A^H b */
} num;

static num *num_of(OF f) { return (num *)f.numericFactorization; }
static void num_release(num *f) {
    if (!f || --f->refs > 0) return;
    sp_symbolic_release(f->sym);
    free(f->perm); free(f->iperm); free(f->scale); free(f->Lp); free(f->Li); free(f->Lx); free(f->D); free(f->Doff); free(f->blk);
    free(f->Up); free(f->Ui); free(f->Ux); free(f->pinv); free(f->Vp); free(f->Vi); free(f->Vx); free(f->beta);
    csc_free(&f->A);
    free(f);
}
void FN(_SparseRetainFactor)(OF *f) { if (f && f->numericFactorization) num_of(*f)->refs++; if (f && f->symbolicFactorization.factorization) _SparseRetainSymbolic(&f->symbolicFactorization); }
void FN(_SparseCleanupFactor)(OF f) {
    num_release(num_of(f));
    _SparseCleanupSymbolic(f.symbolicFactorization);
}

/* growable arrays for the factors */
typedef struct { long len, cap; int *i; T *x; int ok; } vec_buf;
static void vb_push(vec_buf *b, int i, T x) {
    if (!b->ok) return;
    if (b->len == b->cap) {
        long nc = b->cap ? b->cap * 2 : 256;
        int *ni = realloc(b->i, sizeof(int) * (size_t)nc); if (ni) b->i = ni;
        T *nx = ni ? realloc(b->x, sizeof(T) * (size_t)nc) : NULL;
        if (!nx) { b->ok = 0; return; }
        b->x = nx; b->cap = nc;
    }
    b->i[b->len] = i; b->x[b->len] = x; b->len++;
}

/* equilibration: s_i = 1 / sqrt(max_j |a_ij|) of the full symmetric matrix */
static R *equilibrate(const csc *a) {
    R *s = malloc(sizeof(R) * (size_t)(a->n ? a->n : 1));
    if (!s) return NULL;
    for (int j = 0; j < a->n; j++) s[j] = 0;
    for (int j = 0; j < a->n; j++) for (long p = a->p[j]; p < a->p[j + 1]; p++) { R v = ABSV(a->x[p]); if (v > s[a->i[p]]) s[a->i[p]] = v; }
    for (int j = 0; j < a->n; j++) s[j] = s[j] > 0 ? (R)1 / SQRTR(s[j]) : (R)1;
    return s;
}

/* ---- symmetric: up-looking L D L^T / L D L^H of C = P S A S P' ---- */
enum { F_OK = 0, F_SINGULAR = 1, F_UNSTABLE = 2, F_NOMEM = 3, F_NOTPD = 4 };
static int ldl_sparse(num *f, const csc *a, R pivtol, int check) {
    int n = f->n;
    /* the upper triangle of C by columns */
    coo q = { 0, 0, NULL, NULL, NULL, 1 };
    for (int j = 0; j < n; j++) for (long p = a->p[j]; p < a->p[j + 1]; p++) {
        int i = a->i[p], ni = f->iperm[i], nj = f->iperm[j];
        if (ni > nj) continue;
        if (f->sym->ignore && (f->sym->ignore[i] || f->sym->ignore[j])) continue;
        T v = a->x[p];
        if (f->scale) v *= f->scale[i] * f->scale[j];
        coo_add(&q, ni, nj, v);
    }
    if (f->sym->ignore) for (int i = 0; i < n; i++) if (f->sym->ignore[i]) coo_add(&q, f->iperm[i], f->iperm[i], (T)1);
    csc c;
    int ok = q.ok && coo_to_csc(&q, n, n, &c);
    free(q.r); free(q.c); free(q.v);
    if (!ok) return F_NOMEM;
    int *parent = malloc(sizeof(int) * (size_t)(n ? n : 1)), *flag = malloc(sizeof(int) * (size_t)(n ? n : 1));
    int *lnz = calloc((size_t)(n ? n : 1), sizeof(int)), *pattern = malloc(sizeof(int) * (size_t)(n ? n : 1));
    T *y = calloc((size_t)(n ? n : 1), sizeof(T));
    int rc = F_OK;
    if (!parent || !flag || !lnz || !pattern || !y) { rc = F_NOMEM; goto out; }
    /* elimination tree and column counts */
    for (int k = 0; k < n; k++) {
        parent[k] = -1; flag[k] = k;
        for (long p = c.p[k]; p < c.p[k + 1]; p++) {
            int i = c.i[p];
            for (; i < k && flag[i] != k; i = parent[i]) {
                if (parent[i] == -1) parent[i] = k;
                lnz[i]++; flag[i] = k;
            }
        }
    }
    f->Lp = malloc(sizeof(long) * (size_t)(n + 1));
    if (!f->Lp) { rc = F_NOMEM; goto out; }
    f->Lp[0] = 0;
    for (int k = 0; k < n; k++) f->Lp[k + 1] = f->Lp[k] + lnz[k];
    long lsize = f->Lp[n];
    f->Li = malloc(sizeof(int) * (size_t)(lsize ? lsize : 1)); f->Lx = malloc(sizeof(T) * (size_t)(lsize ? lsize : 1));
    f->D = malloc(sizeof(T) * (size_t)(n ? n : 1));
    if (!f->Li || !f->Lx || !f->D) { rc = F_NOMEM; goto out; }
    R limit = pivtol > 0 ? (R)1 / pivtol : (R)0;
    for (int k = 0; k < n; k++) {
        int top = n;
        flag[k] = k; lnz[k] = 0;
        for (long p = c.p[k]; p < c.p[k + 1]; p++) {
            int i = c.i[p];
            y[i] += c.x[p];
            int len = 0;
            for (; i < k && flag[i] != k; i = parent[i]) { pattern[len++] = i; flag[i] = k; }
            while (len > 0) pattern[--top] = pattern[--len];
        }
        T d = y[k]; y[k] = 0;
        for (; top < n; top++) {
            int i = pattern[top];
            T yi = y[i]; y[i] = 0;
            long p2 = f->Lp[i] + lnz[i];
            for (long p = f->Lp[i]; p < p2; p++) y[f->Li[p]] -= f->Lx[p] * yi;
            T l = yi / f->D[i];
            if (f->herm) l = CONJ(l);
            if (check && limit > 0 && ABSV(l) > limit) rc = F_UNSTABLE;
            d -= l * yi;
            f->Li[p2] = k; f->Lx[p2] = l; lnz[i]++;
        }
        f->D[k] = d;
        if (is_zero(d) || d != d) { rc = check ? F_UNSTABLE : F_SINGULAR; if (!check) goto out; }
        if (rc == F_UNSTABLE) goto out;
    }
out:
    free(parent); free(flag); free(lnz); free(pattern); free(y); csc_free(&c);
    return rc;
}

/* dense Bunch-Kaufman L D L^T (D with 1x1 and 2x2 blocks) of C = P S A S P', stored back as sparse L */
#define BK_MAX 3000
static int ldl_dense_bk(num *f, const csc *a) {
    int n = f->n;
    if (n > BK_MAX) return F_UNSTABLE;
    T *A = calloc((size_t)n * (size_t)(n ? n : 1), sizeof(T));
    int *bp = malloc(sizeof(int) * (size_t)(n ? n : 1));
    if (!A || !bp) { free(A); free(bp); return F_NOMEM; }
    #define AA(i, j) A[(long)(j) * n + (i)]
    for (int j = 0; j < n; j++) for (long p = a->p[j]; p < a->p[j + 1]; p++) {
        int i = a->i[p];
        if (f->sym->ignore && (f->sym->ignore[i] || f->sym->ignore[j])) continue;
        T v = a->x[p];
        if (f->scale) v *= f->scale[i] * f->scale[j];
        AA(f->iperm[i], f->iperm[j]) += v;
    }
    if (f->sym->ignore) for (int i = 0; i < n; i++) if (f->sym->ignore[i]) AA(f->iperm[i], f->iperm[i]) = 1;
    for (int k = 0; k < n; k++) bp[k] = k;
    free(f->D); free(f->Doff); free(f->blk);
    f->D = calloc((size_t)(n ? n : 1), sizeof(T)); f->Doff = calloc((size_t)(n ? n : 1), sizeof(T)); f->blk = calloc((size_t)(n ? n : 1), 1);
    if (!f->D || !f->Doff || !f->blk) { free(A); free(bp); return F_NOMEM; }
    const R alpha = (R)((1 + 4.123105625617661) / 8);   /* (1 + sqrt(17)) / 8 */
    #define SWAP_RC(p, q) do { int p_ = (p), q_ = (q); if (p_ != q_) {                                                   \
        for (int t = 0; t < n; t++) { T s_ = AA(p_, t); AA(p_, t) = AA(q_, t); AA(q_, t) = s_; }                          \
        for (int t = 0; t < n; t++) { T s_ = AA(t, p_); AA(t, p_) = AA(t, q_); AA(t, q_) = s_; }                          \
        int b_ = bp[p_]; bp[p_] = bp[q_]; bp[q_] = b_; } } while (0)
    int k = 0;
    while (k < n) {
        R absakk = ABSV(AA(k, k)), colmax = 0; int r = k;
        for (int i = k + 1; i < n; i++) { R v = ABSV(AA(i, k)); if (v > colmax) { colmax = v; r = i; } }
        int size = 1;
        if (absakk >= alpha * colmax || colmax == 0) {
            /* a 1x1 pivot at k */
        } else {
            R rowmax = 0;
            for (int j = k; j < n; j++) if (j != r) { R v = ABSV(AA(r, j)); if (v > rowmax) rowmax = v; }
            if (absakk * rowmax >= alpha * colmax * colmax) { /* 1x1 at k */ }
            else if (ABSV(AA(r, r)) >= alpha * rowmax) SWAP_RC(k, r);
            else { SWAP_RC(k + 1, r); size = 2; }
        }
        if (size == 1) {
            T d = AA(k, k);
            f->D[k] = d;
            if (!is_zero(d)) {
                for (int i = k + 1; i < n; i++) AA(i, k) /= d;   /* L(i,k) */
                for (int j = k + 1; j < n; j++) {
                    T ljk = f->herm ? CONJ(AA(j, k)) : AA(j, k);
                    T s = d * ljk;
                    if (is_zero(s)) continue;
                    for (int i = k + 1; i < n; i++) AA(i, j) -= AA(i, k) * s;
                }
            }
            k += 1;
        } else {
            T a00 = AA(k, k), a10 = AA(k + 1, k), a01 = AA(k, k + 1), a11 = AA(k + 1, k + 1);
            T det = a00 * a11 - a10 * a01;
            f->D[k] = a00; f->D[k + 1] = a11; f->Doff[k] = a10; f->blk[k] = 1; f->blk[k + 1] = 2;
            /* W = [A(i,k) A(i,k+1)] for the rows below; L = W E^-1 */
            for (int i = k + 2; i < n; i++) {
                T w0 = AA(i, k), w1 = AA(i, k + 1);
                AA(i, k) = (w0 * a11 - w1 * a10) / det;
                AA(i, k + 1) = (w1 * a00 - w0 * a01) / det;
                AA(k, i) = w0; AA(k + 1, i) = w1;   /* keep W in the (unused) upper part */
            }
            for (int j = k + 2; j < n; j++) {
                T l0 = f->herm ? CONJ(AA(j, k)) : AA(j, k), l1 = f->herm ? CONJ(AA(j, k + 1)) : AA(j, k + 1);
                for (int i = k + 2; i < n; i++) AA(i, j) -= AA(k, i) * l0 + AA(k + 1, i) * l1;
            }
            k += 2;
        }
    }
    #undef SWAP_RC
    /* the combined order, and L to compressed columns */
    int *np = malloc(sizeof(int) * (size_t)(n ? n : 1));
    vec_buf lb = { 0, 0, NULL, NULL, 1 };
    long *Lp = malloc(sizeof(long) * (size_t)(n + 1));
    if (!np || !Lp) { free(np); free(Lp); free(A); free(bp); return F_NOMEM; }
    for (int t = 0; t < n; t++) np[t] = f->perm[bp[t]];
    for (int j = 0; j < n; j++) {
        Lp[j] = lb.len;
        int start = f->blk[j] == 1 ? j + 2 : j + 1;
        if (f->blk[j] == 1) { /* L(j+1, j) is 0 inside a 2x2 block */ }
        for (int i = start; i < n; i++) if (!is_zero(AA(i, j))) vb_push(&lb, i, AA(i, j));
    }
    Lp[n] = lb.len;
    #undef AA
    free(A); free(bp);
    if (!lb.ok) { free(np); free(Lp); free(lb.i); free(lb.x); return F_NOMEM; }
    free(f->perm); f->perm = np;
    for (int t = 0; t < n; t++) f->iperm[f->perm[t]] = t;
    free(f->Lp); free(f->Li); free(f->Lx);
    f->Lp = Lp; f->Li = lb.i; f->Lx = lb.x;
    return F_OK;
}

/* ---- LU: left-looking with threshold partial pivoting ---- */
static int lu_factor(num *f, const csc *a, R tol, int unpivoted) {
    int n = f->n;
    vec_buf lb = { 0, 0, NULL, NULL, 1 }, ub = { 0, 0, NULL, NULL, 1 };
    long *Lp = malloc(sizeof(long) * (size_t)(n + 1)), *Up = malloc(sizeof(long) * (size_t)(n + 1));
    int *pinv = malloc(sizeof(int) * (size_t)(n ? n : 1)), *xi = malloc(sizeof(int) * (size_t)(2 * n + 1));
    int *mark = malloc(sizeof(int) * (size_t)(n ? n : 1)), *stackp = malloc(sizeof(int) * (size_t)(n ? n : 1));
    T *x = calloc((size_t)(n ? n : 1), sizeof(T));
    int rc = F_OK;
    if (!Lp || !Up || !pinv || !xi || !mark || !stackp || !x) { rc = F_NOMEM; goto out; }
    for (int i = 0; i < n; i++) { pinv[i] = -1; mark[i] = -1; }
    for (int k = 0; k < n; k++) {
        Lp[k] = lb.len; Up[k] = ub.len;
        int col = f->perm[k];
        int ign = f->sym->ignore && f->sym->ignore[col];
        /* the reach of A(:,col) in the graph of L: a depth-first search, in topological order at xi[top..n) */
        int top = n;
        for (long p = a->p[col]; p < a->p[col + 1] && !ign; p++) {
            int r = a->i[p];
            if ((f->sym->ignore && f->sym->ignore[r]) || mark[r] == k) continue;
            int *snode = xi + n, sp = 0;   /* the node stack lives above the output */
            snode[0] = r; stackp[0] = -1; mark[r] = k;
            while (sp >= 0) {
                int j = snode[sp], s = pinv[j], pushed = 0;
                if (s >= 0) {   /* j's children: the rows of L's column s below its pivot */
                    long q = stackp[sp] < 0 ? Lp[s] + 1 : stackp[sp];
                    for (; q < Lp[s + 1]; q++) {
                        int c = lb.i[q];
                        if (mark[c] == k) continue;
                        stackp[sp] = (int)(q + 1);
                        mark[c] = k; sp++; snode[sp] = c; stackp[sp] = -1; pushed = 1;
                        break;
                    }
                }
                if (!pushed) { sp--; xi[--top] = j; }
            }
        }
        /* x = L \ A(:,col) */
        if (ign) { x[col] = 1; xi[--top] = col; mark[col] = k; }
        else for (long p = a->p[col]; p < a->p[col + 1]; p++) if (!(f->sym->ignore && f->sym->ignore[a->i[p]])) x[a->i[p]] = a->x[p];
        for (int t = top; t < n; t++) {
            int j = xi[t], s = pinv[j];
            if (s < 0) continue;
            T xj = x[j];
            for (long q = Lp[s] + 1; q < Lp[s + 1]; q++) x[lb.i[q]] -= lb.x[q] * xj;
        }
        /* the pivot */
        int ipiv = -1; R amax = -1;
        for (int t = top; t < n; t++) {
            int i = xi[t];
            if (pinv[i] < 0) { R v = ABSV(x[i]); if (v > amax) { amax = v; ipiv = i; } }
            else vb_push(&ub, pinv[i], x[i]);
        }
        if (unpivoted || (pinv[col] < 0 && mark[col] == k && ABSV(x[col]) >= tol * amax)) ipiv = col;
        if (ipiv < 0 || pinv[ipiv] >= 0 || amax <= 0 || is_zero(x[ipiv])) {
            for (int t = top; t < n; t++) x[xi[t]] = 0;
            rc = F_SINGULAR; goto out;
        }
        T piv = x[ipiv];
        vb_push(&ub, k, piv);
        pinv[ipiv] = k;
        vb_push(&lb, ipiv, (T)1);
        for (int t = top; t < n; t++) {
            int i = xi[t];
            if (pinv[i] < 0 && !is_zero(x[i])) vb_push(&lb, i, x[i] / piv);
            x[i] = 0;
        }
        if (!lb.ok || !ub.ok) { rc = F_NOMEM; goto out; }
    }
    Lp[n] = lb.len; Up[n] = ub.len;
    for (long q = 0; q < lb.len; q++) lb.i[q] = pinv[lb.i[q]];
    f->Lp = Lp; f->Li = lb.i; f->Lx = lb.x; f->Up = Up; f->Ui = ub.i; f->Ux = ub.x; f->pinv = pinv;
    Lp = NULL; Up = NULL; pinv = NULL; lb.i = NULL; lb.x = NULL; ub.i = NULL; ub.x = NULL;
out:
    free(Lp); free(Up); free(pinv); free(xi); free(mark); free(stackp); free(x);
    free(lb.i); free(lb.x); free(ub.i); free(ub.x);
    return rc;
}

/* ---- QR: Householder, column by column ---- */
static int qr_factor(num *f, const csc *a) {
    int m = a->m, n = a->n;
    vec_buf vb = { 0, 0, NULL, NULL, 1 }, rb = { 0, 0, NULL, NULL, 1 };
    long *Vp = malloc(sizeof(long) * (size_t)(n + 1)), *Rp = malloc(sizeof(long) * (size_t)(n + 1));
    T *beta = malloc(sizeof(T) * (size_t)(n ? n : 1)), *x = calloc((size_t)(m ? m : 1), sizeof(T));
    int *touched = malloc(sizeof(int) * (size_t)(m ? m : 1)), *mark = malloc(sizeof(int) * (size_t)(m ? m : 1));
    int rc = F_OK;
    if (!Vp || !Rp || !beta || !x || !touched || !mark) { rc = F_NOMEM; goto out; }
    for (int i = 0; i < m; i++) mark[i] = -1;
    for (int k = 0; k < n; k++) {
        Vp[k] = vb.len; Rp[k] = rb.len;
        int col = f->perm[k], nt = 0;
        for (long p = a->p[col]; p < a->p[col + 1]; p++) { int r = a->i[p]; x[r] = a->x[p]; if (mark[r] != k) { mark[r] = k; touched[nt++] = r; } }
        for (int j = 0; j < k; j++) {   /* apply H_j = I - beta_j v_j v_j^H */
            if (is_zero(beta[j])) continue;
            T dot = 0;
            for (long p = Vp[j]; p < Vp[j + 1]; p++) dot += CONJ(vb.x[p]) * x[vb.i[p]];
            if (is_zero(dot)) continue;
            dot *= beta[j];
            for (long p = Vp[j]; p < Vp[j + 1]; p++) { int r = vb.i[p]; x[r] -= dot * vb.x[p]; if (mark[r] != k) { mark[r] = k; touched[nt++] = r; } }
        }
        /* rows above k go to R; the Householder vector zeroes rows below k */
        for (int t = 0; t < nt; t++) { int r = touched[t]; if (r < k && !is_zero(x[r])) vb_push(&rb, r, x[r]); }
        R sigma = 0;
        for (int t = 0; t < nt; t++) { int r = touched[t]; if (r > k) { R v = ABSV(x[r]); sigma += v * v; } }
        T alpha = k < m ? x[k] : (T)0;
        R anorm = ABSV(alpha), norm = SQRTR(anorm * anorm + sigma);
        if (norm == 0 || k >= m) {
            beta[k] = 0;
            vb_push(&vb, k < m ? k : m - 1, (T)1);
            vb_push(&rb, k, (T)0);
        } else {
            T phase = anorm > 0 ? alpha / anorm : (T)1;
            T rkk = -phase * norm;
            T v0 = alpha - rkk;   /* v = x - rkk e_k, normalized so that v_k = 1 */
            R v0a = ABSV(v0);
            beta[k] = (T)(v0a * v0a / (norm * norm + norm * anorm));   /* 2 |v0|^2 / (v^H v) */
            vb_push(&vb, k, (T)1);
            for (int t = 0; t < nt; t++) { int r = touched[t]; if (r > k && !is_zero(x[r])) vb_push(&vb, r, x[r] / v0); }
            vb_push(&rb, k, rkk);
        }
        for (int t = 0; t < nt; t++) x[touched[t]] = 0;
        if (!vb.ok || !rb.ok) { rc = F_NOMEM; goto out; }
    }
    Vp[n] = vb.len; Rp[n] = rb.len;
    /* sort each column of R by row, so the diagonal comes last */
    for (int j = 0; j < n; j++)
        for (long q = Rp[j] + 1; q < Rp[j + 1]; q++) {
            int r = rb.i[q]; T v = rb.x[q]; long y = q - 1;
            while (y >= Rp[j] && rb.i[y] > r) { rb.i[y + 1] = rb.i[y]; rb.x[y + 1] = rb.x[y]; y--; }
            rb.i[y + 1] = r; rb.x[y + 1] = v;
        }
    f->Vp = Vp; f->Vi = vb.i; f->Vx = vb.x; f->beta = beta; f->Up = Rp; f->Ui = rb.i; f->Ux = rb.x;
    Vp = NULL; Rp = NULL; beta = NULL; vb.i = NULL; vb.x = NULL; rb.i = NULL; rb.x = NULL;
out:
    free(Vp); free(Rp); free(beta); free(x); free(touched); free(mark); free(vb.i); free(vb.x); free(rb.i); free(rb.x);
    return rc;
}

/* A^H A, Hermitian */
static int form_ata(const csc *a, csc *out) {
    int m = a->m, n = a->n;
    coo q = { 0, 0, NULL, NULL, NULL, 1 };
    /* rows of A */
    long *rp = calloc((size_t)m + 1, sizeof(long)); int *rc_ = malloc(sizeof(int) * (size_t)(a->p[n] ? a->p[n] : 1));
    T *rx = malloc(sizeof(T) * (size_t)(a->p[n] ? a->p[n] : 1)); long *pos = malloc(sizeof(long) * (size_t)(m + 1));
    T *acc = calloc((size_t)(n ? n : 1), sizeof(T)); int *mark = malloc(sizeof(int) * (size_t)(n ? n : 1)), *list = malloc(sizeof(int) * (size_t)(n ? n : 1));
    int ok = rp && rc_ && rx && pos && acc && mark && list;
    if (ok) {
        for (long p = 0; p < a->p[n]; p++) rp[a->i[p] + 1]++;
        for (int i = 0; i < m; i++) rp[i + 1] += rp[i];
        memcpy(pos, rp, sizeof(long) * (size_t)(m + 1));
        for (int j = 0; j < n; j++) for (long p = a->p[j]; p < a->p[j + 1]; p++) { long d = pos[a->i[p]]++; rc_[d] = j; rx[d] = a->x[p]; }
        for (int j = 0; j < n; j++) mark[j] = -1;
        for (int j = 0; j < n; j++) {
            int nl = 0;
            for (long p = a->p[j]; p < a->p[j + 1]; p++) {
                int r = a->i[p]; T arj = a->x[p];
                for (long y = rp[r]; y < rp[r + 1]; y++) {
                    int i = rc_[y];
                    if (mark[i] != j) { mark[i] = j; acc[i] = 0; list[nl++] = i; }
                    acc[i] += CONJ(rx[y]) * arj;
                }
            }
            for (int t = 0; t < nl; t++) coo_add(&q, list[t], j, acc[list[t]]);
        }
        ok = q.ok && coo_to_csc(&q, n, n, out);
    }
    free(rp); free(rc_); free(rx); free(pos); free(acc); free(mark); free(list); free(q.r); free(q.c); free(q.v);
    return ok;
}

static OF factor_fail(OF r, SparseStatus_t s) { r.status = s; return r; }

/* the numeric factorization of A with a symbolic factorization */
static OF numeric_factor(sp_symbolic *sym, SparseOpaqueSymbolicFactorization symf, SM A, const SparseNumericFactorOptions *opts) {
    OF r; memset(&r, 0, sizeof r);
    r.attributes = A.structure.attributes;
    r.attributes.transpose = 0;
#if CPLX
    r.attributes.conjugate_transpose = 0;
#endif
    r.symbolicFactorization = symf;
    void (*report)(const char *) = sym->reportError;
    csc a;
    if (!sm_expand(A, &a)) return factor_fail(r, SparseInternalError);
    if (sym->transposedQR) {   /* QR of a wide matrix: factor A^H */
        coo q = { 0, 0, NULL, NULL, NULL, 1 };
        for (int j = 0; j < a.n; j++) for (long p = a.p[j]; p < a.p[j + 1]; p++) coo_add(&q, j, a.i[p], CONJ(a.x[p]));
        csc t; int ok = q.ok && coo_to_csc(&q, a.n, a.m, &t);
        free(q.r); free(q.c); free(q.v); csc_free(&a);
        if (!ok) return factor_fail(r, SparseInternalError);
        a = t;
    }
    if (a.m != sym->m || a.n != sym->n) { csc_free(&a); sp_report(report, "SparseFactor: the matrix doesn't match its symbolic factorization"); return factor_fail(r, SparseParameterError); }
    num *f = calloc(1, sizeof *f);
    if (!f) { csc_free(&a); return factor_fail(r, SparseInternalError); }
    f->refs = 1; f->sym = sym; sym->refs++; f->type = sym->type; f->m = a.m; f->n = a.n; f->transposedQR = sym->transposedQR;
#if CPLX
    f->herm = A.structure.attributes.kind == 4 || sym->hermitian || sp_is_qr_type(sym->type);
#else
    f->herm = 1;
#endif
    int n = a.n;
    f->perm = malloc(sizeof(int) * (size_t)(n ? n : 1)); f->iperm = malloc(sizeof(int) * (size_t)(n ? n : 1));
    if (!f->perm || !f->iperm) { csc_free(&a); num_release(f); return factor_fail(r, SparseInternalError); }
    memcpy(f->perm, sym->order, sizeof(int) * (size_t)n);
    for (int k = 0; k < n; k++) f->iperm[f->perm[k]] = k;
    R pivtol = opts && opts->pivotTolerance > 0 ? (R)opts->pivotTolerance : (R)0.01;
    int rc = F_OK;
    SparseFactorization_t t = sym->type;
    if (sp_is_symmetric_type(t)) {
        int sm_ = opts ? opts->scalingMethod : SparseScalingDefault;
        if (sm_ == SparseScalingUser && opts->scaling) {
            f->scale = malloc(sizeof(R) * (size_t)(n ? n : 1));
            if (f->scale) for (int i = 0; i < n; i++) f->scale[i] = ((const R *)opts->scaling)[i];
        } else if (sm_ == SparseScalingEquilibriationInf || sm_ == SparseScalingHungarianScalingOnly || sm_ == SparseScalingHungarianScalingAndOrdering
                   || (sm_ == SparseScalingDefault && t != SparseFactorizationCholesky && t != SparseFactorizationLDLTUnpivoted)) {
            f->scale = equilibrate(&a);
        }
        int pivoted = t == SparseFactorizationLDLT || t == SparseFactorizationLDLTSBK || t == SparseFactorizationLDLTTPP;
        rc = ldl_sparse(f, &a, pivtol, pivoted);
        if (rc == F_UNSTABLE && pivoted) {
            free(f->Lp); free(f->Li); free(f->Lx); f->Lp = NULL; f->Li = NULL; f->Lx = NULL;
            rc = ldl_dense_bk(f, &a);
            if (rc == F_UNSTABLE) sp_report(report, "SparseFactor: the matrix needs pivoting, and has more than %d columns", BK_MAX);
        }
        if (rc == F_OK && t == SparseFactorizationCholesky)
            for (int k = 0; k < n; k++) if (!(REALV(f->D[k]) > 0) || ABSV(f->D[k] - REALV(f->D[k])) > 1e3 * EPS * ABSV(f->D[k])) { rc = F_NOTPD; break; }
    } else if (sp_is_lu_type(t)) {
        R tol = opts && opts->pivotTolerance > 0 ? (R)opts->pivotTolerance : (R)0.1;
        rc = lu_factor(f, &a, t == SparseFactorizationLU || t == SparseFactorizationLUTPP || t == SparseFactorizationLUSPP ? tol : (R)1,
                       t == SparseFactorizationLUUnpivoted);
    } else if (t == SparseFactorizationQR) {
        rc = qr_factor(f, &a);
    } else {   /* CholeskyAtA: L D L^H of A^H A, kept with A */
        csc ata;
        if (!form_ata(&a, &ata)) rc = F_NOMEM;
        else {
            rc = ldl_sparse(f, &ata, 0, 0);
            csc_free(&ata);
            if (rc == F_OK) for (int k = 0; k < n; k++) if (!(REALV(f->D[k]) > 0)) { rc = F_NOTPD; break; }
            if (rc == F_SINGULAR) rc = F_NOTPD;
            f->A = a; a.p = NULL; a.i = NULL; a.x = NULL;
        }
    }
    csc_free(&a);
    if (rc != F_OK) {
        num_release(f);
        if (rc == F_SINGULAR || rc == F_UNSTABLE) { sp_report(report, "SparseFactor: the matrix is singular"); return factor_fail(r, SparseMatrixIsSingular); }
        if (rc == F_NOTPD) { sp_report(report, "SparseFactor: the matrix is not positive definite"); return factor_fail(r, SparseFactorizationFailed); }
        return factor_fail(r, SparseInternalError);
    }
    r.status = SparseStatusOK;
    r.numericFactorization = f;
    r.solveWorkspaceRequiredStatic = 0;
    r.solveWorkspaceRequiredPerRHS = (size_t)(f->m > f->n ? f->m : f->n) * sizeof(T);
    return r;
}

OF FN(_SparseNumericFactor)(SparseOpaqueSymbolicFactorization symbolic, SM A, const SparseNumericFactorOptions *nfoptions,
                            void *factorStorage, void *workspace) {
    (void)factorStorage; (void)workspace;
    sp_symbolic *sym = sp_symbolic_of(symbolic);
    if (!sym || symbolic.status != SparseStatusOK) { OF r; memset(&r, 0, sizeof r); r.status = SparseParameterError; return r; }
    _SparseRetainSymbolic(&symbolic);
    OF r = numeric_factor(sym, symbolic, A, nfoptions);
    if (r.status != SparseStatusOK) { _SparseCleanupSymbolic(symbolic); memset(&r.symbolicFactorization, 0, sizeof r.symbolicFactorization); }
    return r;
}

OF FN(_SparseFactor)(SparseFactorization_t type, SM A, const SparseSymbolicFactorOptions *sfoptions, const SparseNumericFactorOptions *nfoptions) {
#if CPLX
    SparseMatrixStructure s = _SparseRealStructure(A.structure);
    bool herm = A.structure.attributes.kind == SparseHermitian;
#else
    SparseMatrixStructure s = A.structure;
    bool herm = false;
#endif
    SparseOpaqueSymbolicFactorization symf = _SparseSymbolicFactor(type, s, sfoptions, herm);
    if (symf.status != SparseStatusOK) { OF r; memset(&r, 0, sizeof r); r.status = symf.status; return r; }
    OF r = numeric_factor(sp_symbolic_of(symf), symf, A, nfoptions);
    if (r.status != SparseStatusOK) { _SparseCleanupSymbolic(symf); memset(&r.symbolicFactorization, 0, sizeof r.symbolicFactorization); }
    return r;
}

void FN(_SparseRefactor)(SM A, OF *factor, const SparseNumericFactorOptions *nfoptions, void *workspace) {
    (void)workspace;
    if (!factor) return;
    sp_symbolic *sym = sp_symbolic_of(factor->symbolicFactorization);
    if (!sym) { factor->status = SparseParameterError; return; }
    OF r = numeric_factor(sym, factor->symbolicFactorization, A, nfoptions);
    if (r.status != SparseStatusOK) { factor->status = r.status; return; }
    num_release(num_of(*factor));
    factor->numericFactorization = r.numericFactorization;
    factor->status = SparseStatusOK;
}
void FN(_SparseUpdateFactor)(SparseUpdate_t update, OF *factor, int count, const int *indices, SM A) {
    (void)update; (void)count; (void)indices;   /* a partial refactorization is a full one here */
    FN(_SparseRefactor)(A, factor, NULL, NULL);
}

/* ---- solves ---- */
/* the solve with L D L^T / L D L^H in the permuted space, in place */
static void ldl_solve(const num *f, T *z, int conj_all) {
    int n = f->n;
    /* conj_all: solve with conj(C) (for A^T of a Hermitian matrix): conjugate in, solve, conjugate out */
    if (conj_all) for (int k = 0; k < n; k++) z[k] = CONJ(z[k]);
    for (int j = 0; j < n; j++) { T zj = z[j]; if (!is_zero(zj)) for (long p = f->Lp[j]; p < f->Lp[j + 1]; p++) z[f->Li[p]] -= f->Lx[p] * zj; }
    for (int k = 0; k < n; k++) {
        if (f->blk && f->blk[k] == 1) {
            T a00 = f->D[k], a10 = f->Doff[k], a11 = f->D[k + 1], a01 = f->herm ? CONJ(a10) : a10;
            T det = a00 * a11 - a10 * a01, b0 = z[k], b1 = z[k + 1];
            z[k] = (a11 * b0 - a01 * b1) / det; z[k + 1] = (a00 * b1 - a10 * b0) / det;
            k++;
        } else z[k] /= f->D[k];
    }
    for (int j = n - 1; j >= 0; j--) {
        T s = 0;
        for (long p = f->Lp[j]; p < f->Lp[j + 1]; p++) s += (f->herm ? CONJ(f->Lx[p]) : f->Lx[p]) * z[f->Li[p]];
        z[j] -= s;
    }
    if (conj_all) for (int k = 0; k < n; k++) z[k] = CONJ(z[k]);
}
/* x = A^-1 b for the symmetric family (b, x of length n, original order) */
static void sym_solve(const num *f, const T *b, T *x, int conj_all, T *w) {
    int n = f->n;
    for (int k = 0; k < n; k++) { int o = f->perm[k]; w[k] = f->scale ? b[o] * f->scale[o] : b[o]; }
    ldl_solve(f, w, conj_all);
    for (int k = 0; k < n; k++) { int o = f->perm[k]; x[o] = f->scale ? w[k] * f->scale[o] : w[k]; }
}
/* LU: A x = b (trans 0), A^T x = b (1), A^H x = b (2) */
static void lu_solve(const num *f, const T *b, T *x, int trans, T *w) {
    int n = f->n;
    if (trans == 0) {
        for (int r = 0; r < n; r++) w[f->pinv[r]] = b[r];
        for (int j = 0; j < n; j++) { T wj = w[j]; for (long p = f->Lp[j] + 1; p < f->Lp[j + 1]; p++) w[f->Li[p]] -= f->Lx[p] * wj; }
        for (int j = n - 1; j >= 0; j--) {
            long last = f->Up[j + 1] - 1;   /* the diagonal is the column's last entry */
            w[j] /= f->Ux[last];
            T wj = w[j];
            for (long p = f->Up[j]; p < last; p++) w[f->Ui[p]] -= f->Ux[p] * wj;
        }
        for (int k = 0; k < n; k++) x[f->perm[k]] = w[k];
    } else {
        for (int k = 0; k < n; k++) w[k] = b[f->perm[k]];
        for (int j = 0; j < n; j++) {   /* U^T z = y, forward */
            long last = f->Up[j + 1] - 1;
            T s = w[j];
            for (long p = f->Up[j]; p < last; p++) s -= (trans == 2 ? CONJ(f->Ux[p]) : f->Ux[p]) * w[f->Ui[p]];
            w[j] = s / (trans == 2 ? CONJ(f->Ux[last]) : f->Ux[last]);
        }
        for (int j = n - 1; j >= 0; j--) {   /* L^T w = z, backward */
            T s = w[j];
            for (long p = f->Lp[j] + 1; p < f->Lp[j + 1]; p++) s -= (trans == 2 ? CONJ(f->Lx[p]) : f->Lx[p]) * w[f->Li[p]];
            w[j] = s;
        }
        for (int r = 0; r < n; r++) x[r] = w[f->pinv[r]];
    }
}
/* Q^H y (forward) or Q y (backward) on a vector of length m */
static void qr_apply_q(const num *f, T *y, int adjoint) {
    int n = f->n;
    for (int t = 0; t < n; t++) {
        int j = adjoint ? t : n - 1 - t;
        if (is_zero(f->beta[j])) continue;
        T dot = 0;
        for (long p = f->Vp[j]; p < f->Vp[j + 1]; p++) dot += CONJ(f->Vx[p]) * y[f->Vi[p]];
        dot *= f->beta[j];
        for (long p = f->Vp[j]; p < f->Vp[j + 1]; p++) y[f->Vi[p]] -= dot * f->Vx[p];
    }
}
/* R z = y (adjoint 0) or R^H z = y (1), in place, n */
static void r_solve(const num *f, T *z, int adjoint) {
    int n = f->n;
    if (!adjoint) {
        for (int j = n - 1; j >= 0; j--) {
            long last = f->Up[j + 1] - 1;
            z[j] /= f->Ux[last];
            T zj = z[j];
            for (long p = f->Up[j]; p < last; p++) z[f->Ui[p]] -= f->Ux[p] * zj;
        }
    } else {
        for (int j = 0; j < n; j++) {
            long last = f->Up[j + 1] - 1;
            T s = z[j];
            for (long p = f->Up[j]; p < last; p++) s -= CONJ(f->Ux[p]) * z[f->Ui[p]];
            z[j] = s / CONJ(f->Ux[last]);
        }
    }
}
/* QR, with B the factored matrix (A, or A^H when transposedQR): mode 0 least squares min |B x - b| (b: m, x: n),
   mode 1 minimum norm B^H x = b (b: n, x: m) */
static void qr_solve(const num *f, const T *b, T *x, int mode, T *w) {
    int m = f->m, n = f->n;
    if (mode == 0) {
        for (int i = 0; i < m; i++) w[i] = b[i];
        qr_apply_q(f, w, 1);
        r_solve(f, w, 0);
        for (int k = 0; k < n; k++) x[f->perm[k]] = w[k];
    } else {
        for (int i = 0; i < m; i++) w[i] = 0;
        for (int k = 0; k < n; k++) w[k] = b[f->perm[k]];
        r_solve(f, w, 1);
        qr_apply_q(f, w, 0);
        for (int i = 0; i < m; i++) x[i] = w[i];
    }
}
/* CholeskyAtA: mode 0 least squares x = (A^H A)^-1 A^H b, mode 1 minimum norm A^H x = b: x = A (A^H A)^-1 b */
static void ata_solve(const num *f, const T *b, T *x, int mode, T *w, T *w2) {
    const csc *a = &f->A;
    if (mode == 0) {
        for (int j = 0; j < a->n; j++) { T s = 0; for (long p = a->p[j]; p < a->p[j + 1]; p++) s += CONJ(a->x[p]) * b[a->i[p]]; w2[j] = s; }
        sym_solve(f, w2, x, 0, w);
    } else {
        sym_solve(f, b, w2, 0, w);
        for (int i = 0; i < a->m; i++) x[i] = 0;
        for (int j = 0; j < a->n; j++) for (long p = a->p[j]; p < a->p[j + 1]; p++) x[a->i[p]] += a->x[p] * w2[j];
    }
}

/* the factorization's operator: trans 0 A, 1 A^T, 2 A^H */
static int of_trans(OF f) {
#if CPLX
    if (f.attributes.conjugate_transpose && !f.attributes.transpose) return 2;
    return f.attributes.transpose ? 1 : 0;
#else
    return f.attributes.transpose ? 1 : 0;
#endif
}
/* one right-hand side: x = op(A)^-1 b (least squares or minimum norm for QR and CholeskyAtA) */
static void factor_solve1(const num *f, int trans, const T *b, T *x, T *w, T *w2, int bn, int xn) {
    if (sp_is_symmetric_type(f->type)) {
        /* real symmetric: A^T = A^H = A; Hermitian: A^H = A, A^T = conj(A); complex symmetric: A^T = A, A^H = conj(A) */
        int conj_all = CPLX && ((f->herm && trans == 1) || (!f->herm && trans == 2));
        sym_solve(f, b, x, conj_all, w);
    } else if (sp_is_lu_type(f->type)) {
        lu_solve(f, b, x, trans, w);
    } else {
        /* the factored matrix B is A (or A^H when transposedQR); op(A) = A: mode 0 on B, or mode 1 when B = A^H */
        int adjoint = trans != 0;   /* A^T is solved as conj(A^H conj(x) = conj(b)) */
        int conj_io = CPLX && trans == 1;
        int mode = f->transposedQR ? !adjoint : adjoint;
        const T *bb = b;
        if (conj_io) { for (int i = 0; i < bn; i++) w2[i] = CONJ(b[i]); bb = w2; }
        if (f->type == SparseFactorizationQR) qr_solve(f, bb, x, mode, w);
        else {
            T *w3 = malloc(sizeof(T) * (size_t)(f->m > f->n ? f->m : f->n) + sizeof(T));
            if (conj_io) { T *t = malloc(sizeof(T) * (size_t)(bn ? bn : 1)); if (t && w3) { memcpy(t, bb, sizeof(T) * (size_t)bn); ata_solve(f, t, x, mode, w, w3); } free(t); }
            else if (w3) ata_solve(f, bb, x, mode, w, w3);
            free(w3);
        }
        if (conj_io) for (int i = 0; i < xn; i++) x[i] = CONJ(x[i]);
    }
}
void FN(_SparseSolveFactor)(OF factor, DM B, DM Xm, void *workspace) {
    (void)workspace;
    num *f = num_of(factor);
    if (!f || factor.status != SparseStatusOK) { sp_report(NULL, "SparseSolve: the factorization is not valid"); return; }
    int trans = of_trans(factor);
    /* op(A) is rows x cols: the original matrix's shape */
    int rows = f->m, cols = f->n;
    if (f->transposedQR) { rows = f->n; cols = f->m; }
    if (trans) { int t = rows; rows = cols; cols = t; }
    int inplace = B.data == Xm.data;
    int need_b = rows, need_x = cols;
    if (inplace) need_b = need_x = rows > cols ? rows : cols;
    if (B.rowCount < (inplace ? (rows > cols ? rows : cols) : need_b) && !inplace) { sp_report(NULL, "SparseSolve: B has %d rows, %d needed", B.rowCount, need_b); return; }
    if (!inplace && Xm.rowCount < need_x) { sp_report(NULL, "SparseSolve: X has %d rows, %d needed", Xm.rowCount, need_x); return; }
    int big = (f->m > f->n ? f->m : f->n) + 1;
    T *b = malloc(sizeof(T) * (size_t)big), *x = malloc(sizeof(T) * (size_t)big), *w = malloc(sizeof(T) * (size_t)big), *w2 = malloc(sizeof(T) * (size_t)big);
    if (!b || !x || !w || !w2) { free(b); free(x); free(w); free(w2); return; }
    for (int c = 0; c < B.columnCount; c++) {
        for (int i = 0; i < rows; i++) b[i] = *dm_at(B, i, c);
        factor_solve1(f, trans, b, x, w, w2, rows, cols);
        for (int i = 0; i < cols; i++) *dm_at(Xm, i, c) = x[i];
    }
    free(b); free(x); free(w); free(w2);
}

/* ---- subfactors ---- */
OS FN(_SparseCreateSubfactor)(SparseSubfactor_t which, OF factor) {
    OS s; memset(&s, 0, sizeof s);
    num *f = num_of(factor);
    s.contents = SparseSubfactorInvalid;
    if (!f || factor.status != SparseStatusOK) return s;
    int ok;
    if (sp_is_symmetric_type(f->type)) ok = which == SparseSubfactorP || which == SparseSubfactorS || which == SparseSubfactorL
                                           || which == SparseSubfactorPLPS || (which == SparseSubfactorD && f->type != SparseFactorizationCholesky);
    else if (sp_is_lu_type(f->type)) ok = which == SparseSubfactorL || which == SparseSubfactorR;
    else ok = which == SparseSubfactorQ || which == SparseSubfactorR || which == SparseSubfactorRP || which == SparseSubfactorP;
    if (!ok) { sp_report(f->sym->reportError, "SparseCreateSubfactor: that subfactor isn't available for this factorization"); return s; }
    s.contents = which;
    s.factor = factor;
    FN(_SparseRetainFactor)(&s.factor);
    s.attributes = factor.attributes;
    s.workspaceRequiredStatic = 0;
    s.workspaceRequiredPerRHS = (size_t)(f->m > f->n ? f->m : f->n) * sizeof(T);
    return s;
}

static int os_trans(OS s) {
#if CPLX
    if (s.attributes.conjugate_transpose && !s.attributes.transpose) return 2;
    return s.attributes.transpose ? 1 : 0;
#else
    return s.attributes.transpose ? 1 : 0;
#endif
}
static T cj_if(T v, int c) { return c ? CONJ(v) : v; }
/* y = op(L) x / op(L)^-1 x in place; L unit (symmetric, LU) or L sqrt(D) (Cholesky) */
static void l_apply(const num *f, T *z, int trans, int solve) {
    int n = f->n, chol = f->type == SparseFactorizationCholesky || f->type == SparseFactorizationCholeskyAtA;
    int lu = sp_is_lu_type(f->type);
    long skip = lu ? 1 : 0;   /* LU stores its unit diagonal first */
    int c = trans == 2;
    if (chol && !solve && trans == 0) for (int k = 0; k < n; k++) z[k] *= SQRTR(REALV(f->D[k]));
    if (chol && solve && trans != 0) for (int k = 0; k < n; k++) z[k] /= SQRTR(REALV(f->D[k]));
    if (trans == 0) {
        if (solve) for (int j = 0; j < n; j++) { T zj = z[j]; for (long p = f->Lp[j] + skip; p < f->Lp[j + 1]; p++) z[f->Li[p]] -= f->Lx[p] * zj; }
        else for (int j = n - 1; j >= 0; j--) { T zj = z[j]; for (long p = f->Lp[j] + skip; p < f->Lp[j + 1]; p++) z[f->Li[p]] += f->Lx[p] * zj; }
    } else {
        if (solve) for (int j = n - 1; j >= 0; j--) { T s = 0; for (long p = f->Lp[j] + skip; p < f->Lp[j + 1]; p++) s += cj_if(f->Lx[p], c) * z[f->Li[p]]; z[j] -= s; }
        else for (int j = 0; j < n; j++) { T s = 0; for (long p = f->Lp[j] + skip; p < f->Lp[j + 1]; p++) s += cj_if(f->Lx[p], c) * z[f->Li[p]]; z[j] += s; }
    }
    if (chol && solve && trans == 0) for (int k = 0; k < n; k++) z[k] /= SQRTR(REALV(f->D[k]));
    if (chol && !solve && trans != 0) for (int k = 0; k < n; k++) z[k] *= SQRTR(REALV(f->D[k]));
}
static void d_apply(const num *f, T *z, int trans, int solve) {
    int n = f->n;
    for (int k = 0; k < n; k++) {
        if (f->blk && f->blk[k] == 1) {
            T a00 = f->D[k], a10 = f->Doff[k], a11 = f->D[k + 1], a01 = f->herm ? CONJ(a10) : a10;
            if (trans == 1) { T t = a01; a01 = a10; a10 = t; }
            if (trans == 2) { a00 = CONJ(a00); a11 = CONJ(a11); T t = CONJ(a01); a01 = CONJ(a10); a10 = t; }
            T b0 = z[k], b1 = z[k + 1];
            if (solve) { T det = a00 * a11 - a10 * a01; z[k] = (a11 * b0 - a01 * b1) / det; z[k + 1] = (a00 * b1 - a10 * b0) / det; }
            else { z[k] = a00 * b0 + a01 * b1; z[k + 1] = a10 * b0 + a11 * b1; }
            k++;
        } else {
            T d = trans == 2 ? CONJ(f->D[k]) : f->D[k];
            z[k] = solve ? z[k] / d : z[k] * d;
        }
    }
}
/* R (upper, n x n) of QR, U of LU, or sqrt(D) L^H of CholeskyAtA */
static void r_apply(const num *f, T *z, int trans, int solve, T *w) {
    int n = f->n;
    if (f->type == SparseFactorizationCholeskyAtA) {   /* R = sqrt(D) L^H: op(R) = L-type ops */
        int lt = trans == 0 ? 2 : (trans == 2 ? 0 : 3);
        if (lt == 3) {   /* R^T = conj(L) sqrt(D) */
            for (int k = 0; k < n; k++) z[k] = CONJ(z[k]);
            l_apply(f, z, 0, solve);
            for (int k = 0; k < n; k++) z[k] = CONJ(z[k]);
        } else l_apply(f, z, lt, solve);
        return;
    }
    (void)w;
    int c = trans == 2;
    if (trans == 0) {
        if (solve) r_solve(f, z, 0);
        else for (int j = 0; j < n; j++) {
            T zj = z[j]; long last = f->Up[j + 1] - 1;
            for (long p = f->Up[j]; p < last; p++) z[f->Ui[p]] += f->Ux[p] * zj;
            z[j] = f->Ux[last] * zj;
        }
    } else {
        if (solve) {
            for (int j = 0; j < n; j++) {
                long last = f->Up[j + 1] - 1; T s = z[j];
                for (long p = f->Up[j]; p < last; p++) s -= cj_if(f->Ux[p], c) * z[f->Ui[p]];
                z[j] = s / cj_if(f->Ux[last], c);
            }
        } else {
            for (int j = n - 1; j >= 0; j--) {
                long last = f->Up[j + 1] - 1; T s = cj_if(f->Ux[last], c) * z[j];
                for (long p = f->Up[j]; p < last; p++) s += cj_if(f->Ux[p], c) * z[f->Ui[p]];
                z[j] = s;
            }
        }
    }
}
void FN(_SparseSubfactorApply)(OS s, bool solve, DM X0, DM Y0, void *workspace) {
    (void)workspace;
    num *f = num_of(s.factor);
    if (!f || s.contents == SparseSubfactorInvalid) { sp_report(NULL, "SparseMultiply / SparseSolve: the subfactor is not valid"); return; }
    int trans = os_trans(s), n = f->n, m = f->m;
    int big = (m > n ? m : n) + 1;
    T *z = malloc(sizeof(T) * (size_t)big), *w = malloc(sizeof(T) * (size_t)big);
    if (!z || !w) { free(z); free(w); return; }
    /* sizes in and out (Q is m x n; everything else n x n) */
    int in = n, out = n;
    if (s.contents == SparseSubfactorQ) {
        int fwd = (trans == 0) != (int)solve;   /* Q x (n -> m) */
        in = fwd ? n : m; out = fwd ? m : n;
    }
    int inplace = X0.data == Y0.data;
    DM Xin = X0, Yout = inplace ? X0 : Y0;
    /* op^T x = conj(op^H conj(x)): only no transpose (0) and the conjugate transpose (2) below */
    int conj_io = trans == 1 && CPLX;
    if (trans == 1) trans = 2;
    for (int c = 0; c < Xin.columnCount; c++) {
        for (int i = 0; i < in; i++) z[i] = conj_io ? CONJ(*dm_at(Xin, i, c)) : *dm_at(Xin, i, c);
        switch (s.contents) {
        case SparseSubfactorP: {
            /* P x: y[k] = x[perm[k]]; the transpose / inverse scatters back */
            int inverse = (trans != 0) != (int)solve;
            for (int k = 0; k < n; k++) w[k] = z[k];
            for (int k = 0; k < n; k++) { if (inverse) z[f->perm[k]] = w[k]; else z[k] = w[f->perm[k]]; }
            break;
        }
        case SparseSubfactorS:
            for (int k = 0; k < n; k++) { R sc = f->scale ? f->scale[k] : (R)1; z[k] = solve ? z[k] / sc : z[k] * sc; }
            break;
        case SparseSubfactorL: l_apply(f, z, trans, solve); break;
        case SparseSubfactorD: d_apply(f, z, trans, solve); break;
        case SparseSubfactorPLPS: {
            /* PLPS = S^-1 P' L, from the permuted space to the original order; A = PLPS D PLPS^H */
            #define SC(o) (f->scale ? f->scale[o] : (R)1)
            if (trans == 0 && !solve) { l_apply(f, z, 0, 0); for (int k = 0; k < n; k++) w[f->perm[k]] = z[k]; for (int o = 0; o < n; o++) z[o] = w[o] / SC(o); }
            else if (trans == 0) { for (int k = 0; k < n; k++) w[k] = z[f->perm[k]] * SC(f->perm[k]); for (int k = 0; k < n; k++) z[k] = w[k]; l_apply(f, z, 0, 1); }
            else if (!solve) { for (int k = 0; k < n; k++) w[k] = z[f->perm[k]] / SC(f->perm[k]); for (int k = 0; k < n; k++) z[k] = w[k]; l_apply(f, z, 2, 0); }
            else { l_apply(f, z, 2, 1); for (int k = 0; k < n; k++) w[f->perm[k]] = z[k]; for (int o = 0; o < n; o++) z[o] = w[o] * SC(o); }
            #undef SC
            break;
        }
        case SparseSubfactorQ: {
            int fwd = (trans == 0) != (int)solve;
            if (f->type == SparseFactorizationQR) {
                if (fwd) { for (int i = n; i < m; i++) z[i] = 0; qr_apply_q(f, z, 0); }
                else qr_apply_q(f, z, 1);   /* Q^H x, first n rows */
            } else {   /* CholeskyAtA: Q = A (R P)^-1 */
                if (fwd) {
                    for (int k = 0; k < n; k++) w[k] = z[k];
                    r_apply(f, w, 0, 1, NULL);
                    for (int k = 0; k < n; k++) z[k] = 0;
                    T *u = calloc((size_t)n + 1, sizeof(T));
                    if (u) { for (int k = 0; k < n; k++) u[f->perm[k]] = w[k]; for (int i = 0; i < m; i++) z[i] = 0;
                             for (int j = 0; j < n; j++) for (long p = f->A.p[j]; p < f->A.p[j + 1]; p++) z[f->A.i[p]] += f->A.x[p] * u[j]; free(u); }
                } else {
                    for (int j = 0; j < n; j++) { T sum = 0; for (long p = f->A.p[j]; p < f->A.p[j + 1]; p++) sum += CONJ(f->A.x[p]) * z[f->A.i[p]]; w[j] = sum; }
                    for (int k = 0; k < n; k++) z[k] = w[f->perm[k]];
                    r_apply(f, z, 2, 1, NULL);
                }
            }
            break;
        }
        case SparseSubfactorR: r_apply(f, z, trans, solve, w); break;
        case SparseSubfactorRP: {
            /* RP = R P': multiply y = R (P' x) with (P' x)[k] = x[perm[k]] */
            int fwd = (trans == 0) != (int)solve;
            if (trans == 0) {
                if (fwd) { for (int k = 0; k < n; k++) w[k] = z[f->perm[k]]; for (int k = 0; k < n; k++) z[k] = w[k]; r_apply(f, z, 0, 0, NULL); }
                else { r_apply(f, z, 0, 1, NULL); for (int k = 0; k < n; k++) w[k] = z[k]; for (int k = 0; k < n; k++) z[f->perm[k]] = w[k]; }
            } else {
                if (!solve) { r_apply(f, z, trans, 0, NULL); for (int k = 0; k < n; k++) w[k] = z[k]; for (int k = 0; k < n; k++) z[f->perm[k]] = w[k]; }
                else { for (int k = 0; k < n; k++) w[k] = z[f->perm[k]]; for (int k = 0; k < n; k++) z[k] = w[k]; r_apply(f, z, trans, 1, NULL); }
            }
            break;
        }
        default: break;
        }
        for (int i = 0; i < out; i++) *dm_at(Yout, i, c) = conj_io ? CONJ(z[i]) : z[i];
    }
    free(z); free(w);
}

int FN(_SparseGetInertia)(OF factor, int *zero, int *negative, int *positive) {
    num *f = num_of(factor);
    if (!f || !sp_is_symmetric_type(f->type)) { sp_report(NULL, "SparseGetInertia: needs a Cholesky or LDLT factorization"); return SparseParameterError; }
    int z = 0, ng = 0, ps = 0;
    for (int k = 0; k < f->n; k++) {
        if (f->blk && f->blk[k] == 1) {
            R a = REALV(f->D[k]), c = REALV(f->D[k + 1]), b = ABSV(f->Doff[k]);
            R det = a * c - b * b, tr = a + c;
            if (det < 0) { ng++; ps++; } else if (det > 0) { if (tr > 0) ps += 2; else ng += 2; } else { z++; if (tr > 0) ps++; else if (tr < 0) ng++; else z++; }
            k++;
        } else {
            R d = REALV(f->D[k]);
            if (d > 0) ps++; else if (d < 0) ng++; else z++;
        }
    }
    if (zero) *zero = z;
    if (negative) *negative = ng;
    if (positive) *positive = ps;
    return SparseStatusOK;
}
