// isim Accelerate Sparse Solvers (issue #807): what the type-independent core (sparse.c) shares with the per-type engine
// (sparse_t.h, instantiated by sparse_double.c, sparse_float.c, sparse_complex_double.c, sparse_complex_float.c).
#pragma once
#include <Accelerate/Accelerate.h>
#include <stdlib.h>
#include <string.h>

/* a compressed sparse column pattern (and, in the engine, values) */
typedef struct { int m, n; long *p; int *i; } sp_pattern;

/* the symbolic factorization: the fill-reducing column order and what the numeric factorization needs to know */
typedef struct sp_symbolic {
    int refs;
    SparseFactorization_t type;
    int m, n;            /* the operator's size as factored (QR of a wide matrix factors its transpose) */
    int transposedQR;    /* QR / CholeskyAtA work on the transpose (m < n) */
    int *order;          /* n: new position -> original column (a symmetric order for the symmetric and LU types) */
    int *ignore;         /* NULL, or n flags: rows / columns treated as the identity */
    int hermitian;
    void (*reportError)(const char *);
    void *(*user_malloc)(size_t);
    void (*user_free)(void *);
} sp_symbolic;

void sp_report(void (*reportError)(const char *), const char *fmt, ...) __attribute__((format(printf, 2, 3)));
int sp_is_symmetric_type(SparseFactorization_t t);
int sp_is_lu_type(SparseFactorization_t t);
int sp_is_qr_type(SparseFactorization_t t);   /* QR and CholeskyAtA */
/* the pattern of the operator a structure describes: blocks expanded, the transpose applied, a symmetric matrix's other
   triangle mirrored, a unit triangle's diagonal added; rows sorted, duplicates merged */
int sp_structure_pattern(SparseMatrixStructure s, sp_pattern *out);
void sp_pattern_free(sp_pattern *p);
/* a minimum-degree order of the symmetric graph of an n x n pattern (its diagonal ignored): order[k] = the k-th vertex */
void sp_min_degree(const sp_pattern *g, int *order);
/* the pattern of A + A' (square), and of A'A */
int sp_pattern_plus_transpose(const sp_pattern *a, sp_pattern *out);
int sp_pattern_ata(const sp_pattern *a, sp_pattern *out);
int sp_pattern_transpose(const sp_pattern *a, sp_pattern *out);
sp_symbolic *sp_symbolic_of(SparseOpaqueSymbolicFactorization f);
void sp_symbolic_release(sp_symbolic *s);

/* ---- Sparse BLAS (issue #819): an opaque matrix, entries staged as coordinates, compressed by columns on commit ---- */
typedef struct sp_bmat {
    int magic, type;            /* type: 0 float, 1 double, 2 float complex, 3 double complex */
    size_t tsize;
    long M, N;                  /* in scalars */
    int blockmode;              /* 0 point, 1 fixed blocks, 2 variable blocks */
    long Mb, Nb, *roff, *coff;  /* block counts and scalar offsets (Mb + 1, Nb + 1) */
    unsigned props;
    int inserted;
    long nnz, cap; long *ri, *ci; unsigned char *v;          /* staged coordinates */
    int committed; long cnnz; long *cp, *crow; unsigned char *cval;   /* compressed columns */
    void (*commit)(struct sp_bmat *);
} sp_bmat;
#define SP_BMAT_MAGIC 0x53424c41
sp_bmat *sp_bmat_new(int type, size_t tsize, long M, long N, void (*commit)(sp_bmat *));
sp_bmat *sp_bmat_of(void *A);
int sp_bmat_reserve(sp_bmat *m, long more);
void sp_bmat_uncommit(sp_bmat *m);   /* back to coordinates before more insertions */
