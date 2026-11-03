// isim Accelerate Sparse Solvers (issue #807): the type-independent core. Patterns of the operator a
// SparseMatrixStructure describes, the minimum-degree ordering and the symbolic factorization object. Adapted: every
// fill-reducing order Apple names (Default, AMD, Metis, MTMetis, COLAMD) is isim's exact minimum degree on the
// elimination graph (of A, A + A' for LU, A'A for QR); a user order is used as given.
#include "sparse_core.h"
#include <stdarg.h>
#include <stdio.h>

void sp_report(void (*reportError)(const char *), const char *fmt, ...) {
    char msg[256];
    va_list ap; va_start(ap, fmt); vsnprintf(msg, sizeof msg, fmt, ap); va_end(ap);
    if (reportError) reportError(msg); else fprintf(stderr, "Accelerate Sparse: %s\n", msg);
}
int sp_is_symmetric_type(SparseFactorization_t t) { return t <= SparseFactorizationLDLTTPP; }
int sp_is_lu_type(SparseFactorization_t t) { return t >= SparseFactorizationLU && t <= SparseFactorizationLUTPP; }
int sp_is_qr_type(SparseFactorization_t t) { return t == SparseFactorizationQR || t == SparseFactorizationCholeskyAtA; }

void sp_pattern_free(sp_pattern *p) { free(p->p); free(p->i); p->p = NULL; p->i = NULL; }

/* sorts each column's rows and merges duplicates in place */
static void sort_merge(sp_pattern *a) {
    long w = 0;
    for (int j = 0; j < a->n; j++) {
        long s = a->p[j], e = a->p[j + 1];
        for (long x = s + 1; x < e; x++) {   /* insertion sort: columns are short */
            int v = a->i[x]; long y = x - 1;
            while (y >= s && a->i[y] > v) { a->i[y + 1] = a->i[y]; y--; }
            a->i[y + 1] = v;
        }
        a->p[j] = w;
        for (long x = s; x < e; x++) if (x == s || a->i[x] != a->i[x - 1]) a->i[w++] = a->i[x];
    }
    a->p[a->n] = w;
}

int sp_structure_pattern(SparseMatrixStructure s, sp_pattern *out) {
    int b = s.blockSize ? s.blockSize : 1;
    int M = s.rowCount * b, N = s.columnCount * b, tr = s.attributes.transpose;
    int sym = s.attributes.kind == SparseSymmetric || s.attributes.kind == (SparseKind_t)4;
    int unit = s.attributes.kind == SparseUnitTriangular, lower = s.attributes.triangle == SparseLowerTriangle;
    out->m = tr ? N : M; out->n = tr ? M : N;
    long nnz = s.columnStarts[s.columnCount] * b * b * (sym ? 2 : 1) + (unit ? (M < N ? M : N) : 0);
    long *cnt = calloc((size_t)out->n + 1, sizeof(long));
    int *ri = malloc(sizeof(int) * (size_t)(nnz ? nnz : 1)), *ci = malloc(sizeof(int) * (size_t)(nnz ? nnz : 1));
    if (!cnt || !ri || !ci) { free(cnt); free(ri); free(ci); return 0; }
    long k = 0;
    for (int J = 0; J < s.columnCount; J++)
        for (long p = s.columnStarts[J]; p < s.columnStarts[J + 1]; p++)
            for (int bj = 0; bj < b; bj++) for (int bi = 0; bi < b; bi++) {
                int i = s.rowIndices[p] * b + bi, j = J * b + bj;
                if ((sym || s.attributes.kind == SparseTriangular || unit) && (lower ? i < j : i > j)) continue;
                if (unit && i == j) continue;
                int r = tr ? j : i, c = tr ? i : j;
                ri[k] = r; ci[k] = c; k++;
                if (sym && i != j) { ri[k] = c; ci[k] = r; k++; }
            }
    if (unit) for (int d = 0; d < (M < N ? M : N); d++) { ri[k] = d; ci[k] = d; k++; }
    for (long x = 0; x < k; x++) cnt[ci[x] + 1]++;
    for (int j = 0; j < out->n; j++) cnt[j + 1] += cnt[j];
    out->p = cnt; out->i = malloc(sizeof(int) * (size_t)(k ? k : 1));
    long *pos = malloc(sizeof(long) * (size_t)(out->n ? out->n : 1));
    if (!out->i || !pos) { free(pos); free(ri); free(ci); sp_pattern_free(out); return 0; }
    memcpy(pos, cnt, sizeof(long) * (size_t)out->n);
    for (long x = 0; x < k; x++) out->i[pos[ci[x]]++] = ri[x];
    free(pos); free(ri); free(ci);
    sort_merge(out);
    return 1;
}

int sp_pattern_transpose(const sp_pattern *a, sp_pattern *out) {
    out->m = a->n; out->n = a->m;
    long nnz = a->p[a->n];
    out->p = calloc((size_t)out->n + 1, sizeof(long)); out->i = malloc(sizeof(int) * (size_t)(nnz ? nnz : 1));
    long *pos = malloc(sizeof(long) * (size_t)(out->n + 1));
    if (!out->p || !out->i || !pos) { free(pos); sp_pattern_free(out); return 0; }
    for (long x = 0; x < nnz; x++) out->p[a->i[x] + 1]++;
    for (int j = 0; j < out->n; j++) out->p[j + 1] += out->p[j];
    memcpy(pos, out->p, sizeof(long) * (size_t)(out->n + 1));
    for (int j = 0; j < a->n; j++) for (long x = a->p[j]; x < a->p[j + 1]; x++) out->i[pos[a->i[x]]++] = j;
    free(pos);
    return 1;
}

int sp_pattern_plus_transpose(const sp_pattern *a, sp_pattern *out) {
    sp_pattern t;
    if (!sp_pattern_transpose(a, &t)) return 0;
    out->m = a->m; out->n = a->n;
    long nnz = a->p[a->n] + t.p[t.n];
    out->p = malloc(sizeof(long) * (size_t)(a->n + 1)); out->i = malloc(sizeof(int) * (size_t)(nnz ? nnz : 1));
    if (!out->p || !out->i) { sp_pattern_free(&t); sp_pattern_free(out); return 0; }
    long w = 0;
    for (int j = 0; j < a->n; j++) {
        out->p[j] = w;
        for (long x = a->p[j]; x < a->p[j + 1]; x++) out->i[w++] = a->i[x];
        for (long x = t.p[j]; x < t.p[j + 1]; x++) out->i[w++] = t.i[x];
    }
    out->p[a->n] = w;
    sp_pattern_free(&t);
    sort_merge(out);
    return 1;
}

int sp_pattern_ata(const sp_pattern *a, sp_pattern *out) {
    sp_pattern t;   /* rows of A */
    if (!sp_pattern_transpose(a, &t)) return 0;
    int n = a->n;
    int *mark = malloc(sizeof(int) * (size_t)(n ? n : 1));
    long cap = a->p[n] * 4 + n + 1, w = 0;
    out->m = n; out->n = n; out->p = malloc(sizeof(long) * (size_t)(n + 1)); out->i = malloc(sizeof(int) * (size_t)cap);
    if (!mark || !out->p || !out->i) { free(mark); sp_pattern_free(&t); sp_pattern_free(out); return 0; }
    for (int j = 0; j < n; j++) mark[j] = -1;
    for (int j = 0; j < n; j++) {
        out->p[j] = w;
        for (long x = a->p[j]; x < a->p[j + 1]; x++) {
            int r = a->i[x];
            for (long y = t.p[r]; y < t.p[r + 1]; y++) {
                int c = t.i[y];
                if (mark[c] == j) continue;
                mark[c] = j;
                if (w == cap) { cap *= 2; int *ni = realloc(out->i, sizeof(int) * (size_t)cap); if (!ni) { free(mark); sp_pattern_free(&t); sp_pattern_free(out); return 0; } out->i = ni; }
                out->i[w++] = c;
            }
        }
    }
    out->p[n] = w;
    free(mark); sp_pattern_free(&t);
    sort_merge(out);
    return 1;
}

/* ---- minimum degree on the explicit elimination graph, with degree buckets ---- */
typedef struct { int *a; int len, cap; } adjl;
static int adj_push(adjl *l, int v) {
    if (l->len == l->cap) {
        int nc = l->cap ? l->cap * 2 : 4; int *na = realloc(l->a, sizeof(int) * (size_t)nc);
        if (!na) return 0;
        l->a = na; l->cap = nc;
    }
    l->a[l->len++] = v;
    return 1;
}
void sp_min_degree(const sp_pattern *g, int *order) {
    int n = g->n;
    adjl *adj = calloc((size_t)n, sizeof(adjl));
    int *deg = malloc(sizeof(int) * (size_t)(n ? n : 1)), *head = malloc(sizeof(int) * (size_t)(n + 1));
    int *next = malloc(sizeof(int) * (size_t)(n ? n : 1)), *prev = malloc(sizeof(int) * (size_t)(n ? n : 1));
    int *mark = malloc(sizeof(int) * (size_t)(n ? n : 1)), *gone = calloc((size_t)(n ? n : 1), sizeof(int));
    int *nb = malloc(sizeof(int) * (size_t)(n ? n : 1));
    int ok = adj && deg && head && next && prev && mark && gone && nb;
    for (int j = 0; ok && j < n; j++)
        for (long x = g->p[j]; x < g->p[j + 1]; x++) if (g->i[x] != j && g->i[x] < n) ok &= adj_push(&adj[j], g->i[x]);
    if (!ok) {   /* out of memory: the natural order */
        for (int k = 0; k < n; k++) order[k] = k;
        goto done;
    }
    for (int v = 0; v <= n; v++) head[v] = -1;
    #define BUCKET_IN(v) do { int d_ = deg[v]; prev[v] = -1; next[v] = head[d_]; if (head[d_] >= 0) prev[head[d_]] = (v); head[d_] = (v); } while (0)
    #define BUCKET_OUT(v) do { if (prev[v] >= 0) next[prev[v]] = next[v]; else head[deg[v]] = next[v]; if (next[v] >= 0) prev[next[v]] = prev[v]; } while (0)
    for (int v = n - 1; v >= 0; v--) { deg[v] = adj[v].len; mark[v] = -1; BUCKET_IN(v); }
    int mindeg = 0, stamp = 0;
    for (int k = 0; k < n; k++) {
        while (mindeg < n && head[mindeg] < 0) mindeg++;
        int v = head[mindeg];
        BUCKET_OUT(v);
        gone[v] = 1; order[k] = v;
        int nn = 0;
        for (int x = 0; x < adj[v].len; x++) { int u = adj[v].a[x]; if (!gone[u]) nb[nn++] = u; }
        for (int x = 0; x < nn; x++) {
            int u = nb[x];
            BUCKET_OUT(u);
            stamp++;
            int w = 0;
            for (int y = 0; y < adj[u].len; y++) {   /* keep the live neighbours */
                int t = adj[u].a[y];
                if (gone[t] || mark[t] == stamp) continue;
                mark[t] = stamp; adj[u].a[w++] = t;
            }
            adj[u].len = w;
            for (int y = 0; y < nn; y++) { int t = nb[y]; if (t != u && mark[t] != stamp) { mark[t] = stamp; adj_push(&adj[u], t); } }
            deg[u] = adj[u].len < n ? adj[u].len : n;
            BUCKET_IN(u);
            if (deg[u] < mindeg) mindeg = deg[u];
        }
        free(adj[v].a); adj[v].a = NULL; adj[v].len = adj[v].cap = 0;
    }
    #undef BUCKET_IN
    #undef BUCKET_OUT
done:
    if (adj) for (int v = 0; v < n; v++) free(adj[v].a);
    free(adj); free(deg); free(head); free(next); free(prev); free(mark); free(gone); free(nb);
}

/* ---- the symbolic factorization ---- */
sp_symbolic *sp_symbolic_of(SparseOpaqueSymbolicFactorization f) { return (sp_symbolic *)f.factorization; }
void sp_symbolic_release(sp_symbolic *s) {
    if (!s || --s->refs > 0) return;
    free(s->order); free(s->ignore); free(s);
}
void _SparseRetainSymbolic(SparseOpaqueSymbolicFactorization *f) { if (f && f->factorization) ((sp_symbolic *)f->factorization)->refs++; }
void _SparseCleanupSymbolic(SparseOpaqueSymbolicFactorization f) { sp_symbolic_release(sp_symbolic_of(f)); }

SparseOpaqueSymbolicFactorization _SparseSymbolicFactor(SparseFactorization_t type, SparseMatrixStructure s,
                                                        const SparseSymbolicFactorOptions *options, bool hermitian) {
    SparseOpaqueSymbolicFactorization r = { 0 };
    r.rowCount = s.rowCount; r.columnCount = s.columnCount; r.attributes = s.attributes; r.blockSize = s.blockSize; r.type = type;
    void (*report)(const char *) = options ? options->reportError : NULL;
    int b = s.blockSize ? s.blockSize : 1;
    int valid = sp_is_symmetric_type(type) || sp_is_lu_type(type) || sp_is_qr_type(type);
    if (!valid || s.rowCount < 0 || s.columnCount < 0 || (!s.columnStarts && s.columnCount) || b < 1) {
        sp_report(report, "SparseFactor: invalid factorization type or matrix");
        r.status = SparseParameterError; return r;
    }
    if (sp_is_symmetric_type(type) && (s.rowCount != s.columnCount || s.attributes.kind != SparseSymmetric)) {
        sp_report(report, "SparseFactor: Cholesky and LDLT factorizations need a square symmetric matrix");
        r.status = SparseParameterError; return r;
    }
    if (sp_is_lu_type(type) && s.rowCount != s.columnCount) {
        sp_report(report, "SparseFactor: LU factorizations need a square matrix");
        r.status = SparseParameterError; return r;
    }
    sp_pattern a, g;
    if (!sp_structure_pattern(s, &a)) { r.status = SparseInternalError; return r; }
    sp_symbolic *sym = calloc(1, sizeof *sym);
    if (!sym) { sp_pattern_free(&a); r.status = SparseInternalError; return r; }
    sym->refs = 1; sym->type = type; sym->hermitian = hermitian; sym->reportError = report;
    if (options) { sym->user_malloc = options->malloc; sym->user_free = options->free; }
    int ok;
    if (sp_is_qr_type(type)) {
        sym->transposedQR = type == SparseFactorizationQR && a.m < a.n;
        if (sym->transposedQR) { sp_pattern t; ok = sp_pattern_transpose(&a, &t); sp_pattern_free(&a); a = t; if (!ok) goto fail; }
        sym->m = a.m; sym->n = a.n;
        ok = sp_pattern_ata(&a, &g);
    } else {
        sym->m = a.m; sym->n = a.n;
        ok = sp_is_lu_type(type) ? sp_pattern_plus_transpose(&a, &g) : (g = a, a.p = NULL, a.i = NULL, 1);
    }
    sp_pattern_free(&a);
    if (!ok) goto fail;
    int n = sym->n;
    sym->order = malloc(sizeof(int) * (size_t)(n ? n : 1));
    if (!sym->order) { sp_pattern_free(&g); goto fail; }
    if (options && options->orderMethod == SparseOrderUser && options->order) {
        int *seen = calloc((size_t)(n ? n : 1), sizeof(int));
        int good = seen != NULL;
        for (int k = 0; good && k < s.columnCount; k++) {   /* the user's order is of block columns */
            int c = options->order[k];
            if (c < 0 || c >= s.columnCount) { good = 0; break; }
            for (int d = 0; d < b; d++) { int v = c * b + d; if (v >= n || seen[v]) { good = 0; break; } seen[v] = 1; sym->order[k * b + d] = v; }
        }
        free(seen);
        if (!good) { sp_report(report, "SparseFactor: the user order is not a permutation"); sp_pattern_free(&g); free(sym->order); free(sym); r.status = SparseParameterError; return r; }
    } else {
        sp_min_degree(&g, sym->order);
    }
    long fill = g.p[g.n];
    sp_pattern_free(&g);
    if (options && options->ignoreRowsAndColumns) {   /* a list ending with a negative index */
        sym->ignore = calloc((size_t)(n ? n : 1), sizeof(int));
        if (!sym->ignore) goto fail;
        for (const int *q = options->ignoreRowsAndColumns; *q >= 0; q++)
            for (int d = 0; d < b; d++) if (*q * b + d < n) sym->ignore[*q * b + d] = 1;
    }
    r.status = SparseStatusOK;
    r.factorization = sym;
    r.factorSize_Double = (size_t)(fill + n) * 3 * sizeof(double);
    r.factorSize_Float = (size_t)(fill + n) * 3 * sizeof(float);
    r.workspaceSize_Double = (size_t)(sym->m + n) * 4 * sizeof(double);
    r.workspaceSize_Float = (size_t)(sym->m + n) * 4 * sizeof(float);
    return r;
fail:
    free(sym->order); free(sym);
    r.status = SparseInternalError;
    return r;
}

/* ---- Sparse BLAS: the type-independent part (issue #819) ---- */
sp_bmat *sp_bmat_new(int type, size_t tsize, long M, long N, void (*commit)(sp_bmat *)) {
    sp_bmat *m = calloc(1, sizeof *m);
    if (!m) return NULL;
    m->magic = SP_BMAT_MAGIC; m->type = type; m->tsize = tsize; m->M = M; m->N = N; m->commit = commit;
    return m;
}
sp_bmat *sp_bmat_of(void *A) { sp_bmat *m = A; return m && m->magic == SP_BMAT_MAGIC ? m : NULL; }
int sp_bmat_reserve(sp_bmat *m, long more) {
    if (m->nnz + more <= m->cap) return 1;
    long nc = m->cap ? m->cap : 64;
    while (nc < m->nnz + more) nc *= 2;
    long *ri = realloc(m->ri, sizeof(long) * (size_t)nc); if (ri) m->ri = ri;
    long *ci = ri ? realloc(m->ci, sizeof(long) * (size_t)nc) : NULL; if (ci) m->ci = ci;
    unsigned char *v = ci ? realloc(m->v, m->tsize * (size_t)nc) : NULL;
    if (!v) return 0;
    m->v = v; m->cap = nc;
    return 1;
}
void sp_bmat_uncommit(sp_bmat *m) {
    if (!m->committed) return;
    m->nnz = 0;
    if (sp_bmat_reserve(m, m->cnnz))
        for (long j = 0; j < m->N; j++) for (long p = m->cp[j]; p < m->cp[j + 1]; p++) {
            m->ri[m->nnz] = m->crow[p]; m->ci[m->nnz] = j; memcpy(m->v + m->tsize * (size_t)m->nnz, m->cval + m->tsize * (size_t)p, m->tsize); m->nnz++;
        }
    free(m->cp); free(m->crow); free(m->cval); m->cp = NULL; m->crow = NULL; m->cval = NULL; m->cnnz = 0; m->committed = 0;
}
sparse_status sparse_commit(void *A) {
    sp_bmat *m = sp_bmat_of(A);
    if (!m) return SPARSE_ILLEGAL_PARAMETER;
    if (!m->committed) m->commit(m);
    return m->committed ? SPARSE_SUCCESS : SPARSE_SYSTEM_ERROR;
}
sparse_status sparse_matrix_destroy(void *A) {
    sp_bmat *m = sp_bmat_of(A);
    if (!m) return SPARSE_ILLEGAL_PARAMETER;
    m->magic = 0;
    free(m->ri); free(m->ci); free(m->v); free(m->cp); free(m->crow); free(m->cval); free(m->roff); free(m->coff); free(m);
    return SPARSE_SUCCESS;
}
sparse_status sparse_set_matrix_property(void *A, sparse_matrix_property p) {
    sp_bmat *m = sp_bmat_of(A);
    if (!m) return SPARSE_ILLEGAL_PARAMETER;
    if (m->inserted) return SPARSE_CANNOT_SET_PROPERTY;
    unsigned tri = SPARSE_UPPER_TRIANGULAR | SPARSE_LOWER_TRIANGULAR, sym = SPARSE_UPPER_SYMMETRIC | SPARSE_LOWER_SYMMETRIC;
    if (p != SPARSE_UPPER_TRIANGULAR && p != SPARSE_LOWER_TRIANGULAR && p != SPARSE_UPPER_SYMMETRIC && p != SPARSE_LOWER_SYMMETRIC) return SPARSE_ILLEGAL_PARAMETER;
    if (m->M != m->N) return SPARSE_CANNOT_SET_PROPERTY;
    if (((p & tri) && (m->props & (tri | sym))) || ((p & sym) && (m->props & (tri | sym)))) return SPARSE_CANNOT_SET_PROPERTY;
    m->props |= p;
    return SPARSE_SUCCESS;
}
long sparse_get_matrix_property(void *A, sparse_matrix_property p) { sp_bmat *m = sp_bmat_of(A); return m && (m->props & p) ? 1 : 0; }
sparse_dimension sparse_get_matrix_number_of_rows(void *A) { sp_bmat *m = sp_bmat_of(A); return m ? (sparse_dimension)m->M : 0; }
sparse_dimension sparse_get_matrix_number_of_columns(void *A) { sp_bmat *m = sp_bmat_of(A); return m ? (sparse_dimension)m->N : 0; }
long sparse_get_matrix_nonzero_count(void *A) {
    sp_bmat *m = sp_bmat_of(A);
    if (!m || sparse_commit(A) != SPARSE_SUCCESS) return 0;
    return m->cnnz;
}
long sparse_get_matrix_nonzero_count_for_row(void *A, sparse_index i) {
    sp_bmat *m = sp_bmat_of(A);
    if (!m || i < 0 || i >= m->M || sparse_commit(A) != SPARSE_SUCCESS) return 0;
    long c = 0;
    for (long p = 0; p < m->cnnz; p++) if (m->crow[p] == i) c++;
    return c;
}
long sparse_get_matrix_nonzero_count_for_column(void *A, sparse_index j) {
    sp_bmat *m = sp_bmat_of(A);
    if (!m || j < 0 || j >= m->N || sparse_commit(A) != SPARSE_SUCCESS) return 0;
    return m->cp[j + 1] - m->cp[j];
}
long sparse_get_block_dimension_for_row(void *A, sparse_index i) {
    sp_bmat *m = sp_bmat_of(A);
    if (!m) return 0;
    if (!m->blockmode) return i >= 0 && i < m->M ? 1 : 0;
    return i >= 0 && i < m->Mb ? m->roff[i + 1] - m->roff[i] : 0;
}
long sparse_get_block_dimension_for_col(void *A, sparse_index j) {
    sp_bmat *m = sp_bmat_of(A);
    if (!m) return 0;
    if (!m->blockmode) return j >= 0 && j < m->N ? 1 : 0;
    return j >= 0 && j < m->Nb ? m->coff[j + 1] - m->coff[j] : 0;
}
