// Sparse BLAS from C (issue #819): the checks of sparse_blas_t.h for the four scalar types.
#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#pragma STDC CX_LIMITED_RANGE ON
#define CHECK(cond, what) do { (*checks)++; if (cond) printf("PASS  %s\n", what); else { (*failures)++; printf("FAIL  %s  (line %d)\n", what, __LINE__); } } while (0)
#define P double
#define M sparse_matrix_double
#define X Double
#define T double
#define R double
#define ABSV(x) fabs(x)
#define MK(re, im) ((double)(re))
#include "sparse_blas_t.h"
#undef P
#undef M
#undef X
#undef T
#undef R
#undef ABSV
#undef MK
#define P float
#define M sparse_matrix_float
#define X Float
#define T float
#define R float
#define ABSV(x) fabsf(x)
#define MK(re, im) ((float)(re))
#include "sparse_blas_t.h"
#undef P
#undef M
#undef X
#undef T
#undef R
#undef ABSV
#undef MK
#define P double_complex
#define M sparse_matrix_double_complex
#define X Complex_Double
#define T _Complex double
#define R double
#define ABSV(x) hypot(__builtin_creal(x), __builtin_cimag(x))
#define MK(re, im) __builtin_complex((double)(re), (double)(im))
#include "sparse_blas_t.h"
#undef P
#undef M
#undef X
#undef T
#undef R
#undef ABSV
#undef MK
#define P float_complex
#define M sparse_matrix_float_complex
#define X Complex_Float
#define T _Complex float
#define R float
#define ABSV(x) hypotf(__builtin_crealf(x), __builtin_cimagf(x))
#define MK(re, im) __builtin_complex((float)(re), (float)(im))
#include "sparse_blas_t.h"

void sparse_blas(int *checks, int *failures) {
    blas_tests_double(checks, failures, "double", 1e-9);
    blas_tests_float(checks, failures, "float", 1e-3f);
    blas_tests_double_complex(checks, failures, "complex double", 1e-9);
    blas_tests_float_complex(checks, failures, "complex float", 1e-3f);
}
