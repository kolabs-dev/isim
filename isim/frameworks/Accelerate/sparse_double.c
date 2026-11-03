// isim Accelerate Sparse Solvers (issue #807): the engine (sparse_t.h, sparse_iter_t.h) for double.
#include "sparse_core.h"   /* the headers first: the macros below would rename their identifiers */
#include <float.h>
#include <math.h>
#include <stdio.h>
#define X Double
#define T double
#define R double
#define CPLX 0
#define ATTR SparseAttributes_t
#define STRUCT SparseMatrixStructure
#define ABSV(x) fabs(x)
#define SQRTR(x) sqrt(x)
#define CONJ(x) (x)
#define REALV(x) (x)
#define EPS DBL_EPSILON
#include "sparse_t.h"
#include "sparse_iter_t.h"
#define BP double
#define BM sparse_matrix_double
#define BTYPE 1
#include "sparse_blas_t.h"
