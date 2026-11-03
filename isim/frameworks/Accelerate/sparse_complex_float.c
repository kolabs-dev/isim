// isim Accelerate Sparse Solvers (issue #807): the engine (sparse_t.h, sparse_iter_t.h) for _Complex float.
#include "sparse_core.h"   /* the headers first: the macros below would rename their identifiers */
/* complex products and quotients inline (no compiler-rt __muldc3 / __divdc3) */
#pragma STDC CX_LIMITED_RANGE ON
#include <float.h>
#include <math.h>
#include <stdio.h>
#define X Complex_Float
#define T _Complex float
#define R float
#define CPLX 1
#define ATTR SparseAttributesComplex_t
#define STRUCT SparseMatrixStructureComplex
#define ABSV(x) hypotf(__builtin_crealf(x), __builtin_cimagf(x))
#define SQRTR(x) sqrtf(x)
#define CONJ(x) __builtin_conjf(x)
#define REALV(x) __builtin_crealf(x)
#define EPS FLT_EPSILON
#include "sparse_t.h"
#include "sparse_iter_t.h"
#define BP float_complex
#define BM sparse_matrix_float_complex
#define BTYPE 2
#include "sparse_blas_t.h"
