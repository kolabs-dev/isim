// isim Accelerate Sparse Solvers (issue #807): the engine (sparse_t.h, sparse_iter_t.h) for float.
#include "sparse_core.h"   /* the headers first: the macros below would rename their identifiers */
#include <float.h>
#include <math.h>
#include <stdio.h>
#define X Float
#define T float
#define R float
#define CPLX 0
#define ATTR SparseAttributes_t
#define STRUCT SparseMatrixStructure
#define ABSV(x) fabsf(x)
#define SQRTR(x) sqrtf(x)
#define CONJ(x) (x)
#define REALV(x) (x)
#define EPS FLT_EPSILON
#include "sparse_t.h"
#include "sparse_iter_t.h"
#define BP float
#define BM sparse_matrix_float
#define BTYPE 0
#include "sparse_blas_t.h"
