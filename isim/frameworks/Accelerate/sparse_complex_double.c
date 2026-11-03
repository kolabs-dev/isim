// isim Accelerate Sparse Solvers (issue #807): the engine (sparse_t.h, sparse_iter_t.h) for _Complex double.
#include "sparse_core.h"   /* the headers first: the macros below would rename their identifiers */
/* complex products and quotients inline (no compiler-rt __muldc3 / __divdc3) */
#pragma STDC CX_LIMITED_RANGE ON
#include <float.h>
#include <math.h>
#include <stdio.h>
#define X Complex_Double
#define T _Complex double
#define R double
#define CPLX 1
#define ATTR SparseAttributesComplex_t
#define STRUCT SparseMatrixStructureComplex
#define ABSV(x) hypot(__builtin_creal(x), __builtin_cimag(x))
#define SQRTR(x) sqrt(x)
#define CONJ(x) __builtin_conj(x)
#define REALV(x) __builtin_creal(x)
#define EPS DBL_EPSILON
#include "sparse_t.h"
#include "sparse_iter_t.h"
