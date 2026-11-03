#pragma once
/* isim Accelerate: Sparse BLAS (issue #819), Apple's Sparse/BLAS.h over isim's C implementation
   (frameworks/Accelerate/sparse_blas*.c): opaque sparse matrices built entry by entry, sparse vectors, and products
   and triangular solves with dense data. */
#include <stdbool.h>
#include <stdint.h>
#include <Accelerate/vecLibTypes.h>
#include <Accelerate/cblas.h>
#if __has_feature(nullability)
#pragma clang assume_nonnull begin
#endif
#ifdef __cplusplus
extern "C" {
#endif

typedef long sparse_index;
typedef unsigned long long sparse_dimension;
typedef long sparse_stride;
typedef enum : int {
    SPARSE_SUCCESS = 0, SPARSE_ILLEGAL_PARAMETER = -1000, SPARSE_CANNOT_SET_PROPERTY = -1001, SPARSE_SYSTEM_ERROR = -1002
} sparse_status;
typedef enum : unsigned int {
    SPARSE_UPPER_TRIANGULAR = 1, SPARSE_LOWER_TRIANGULAR = 2, SPARSE_UPPER_SYMMETRIC = 4, SPARSE_LOWER_SYMMETRIC = 8
} sparse_matrix_property;
typedef enum : unsigned int { SPARSE_NORM_ONE = 171, SPARSE_NORM_TWO = 173, SPARSE_NORM_INF = 175, SPARSE_NORM_R1 = 179 } sparse_norm;

typedef struct sparse_m_float *sparse_matrix_float;
typedef struct sparse_m_double *sparse_matrix_double;
typedef struct sparse_m_float_complex *sparse_matrix_float_complex;
typedef struct sparse_m_double_complex *sparse_matrix_double_complex;

/* any sparse matrix */
VECLIB_EXTERN sparse_status sparse_commit(void *_Null_unspecified A);
VECLIB_EXTERN sparse_status sparse_matrix_destroy(void *_Null_unspecified A);
VECLIB_EXTERN sparse_status sparse_set_matrix_property(void *_Null_unspecified A, sparse_matrix_property pname);
VECLIB_EXTERN long sparse_get_matrix_property(void *_Null_unspecified A, sparse_matrix_property pname);
VECLIB_EXTERN sparse_dimension sparse_get_matrix_number_of_rows(void *_Null_unspecified A);
VECLIB_EXTERN sparse_dimension sparse_get_matrix_number_of_columns(void *_Null_unspecified A);
VECLIB_EXTERN long sparse_get_matrix_nonzero_count(void *_Null_unspecified A);
VECLIB_EXTERN long sparse_get_matrix_nonzero_count_for_row(void *_Null_unspecified A, sparse_index i);
VECLIB_EXTERN long sparse_get_matrix_nonzero_count_for_column(void *_Null_unspecified A, sparse_index j);
VECLIB_EXTERN long sparse_get_block_dimension_for_row(void *_Null_unspecified A, sparse_index i);
VECLIB_EXTERN long sparse_get_block_dimension_for_col(void *_Null_unspecified A, sparse_index j);

#define _SPARSE_BLAS(P, T, M)                                                                                                 \
VECLIB_EXTERN M _Null_unspecified sparse_matrix_create_##P(sparse_dimension M_, sparse_dimension N);                          \
VECLIB_EXTERN M _Null_unspecified sparse_matrix_block_create_##P(sparse_dimension Mb, sparse_dimension Nb, sparse_dimension k, \
    sparse_dimension l);                                                                                                      \
VECLIB_EXTERN M _Null_unspecified sparse_matrix_variable_block_create_##P(sparse_dimension Mb, sparse_dimension Nb,           \
    const sparse_dimension *_Null_unspecified K, const sparse_dimension *_Null_unspecified L);                                 \
VECLIB_EXTERN sparse_status sparse_insert_entry_##P(M _Null_unspecified A, T val, sparse_index i, sparse_index j);            \
VECLIB_EXTERN sparse_status sparse_insert_entries_##P(M _Null_unspecified A, sparse_dimension N, const T *_Null_unspecified val, \
    const sparse_index *_Null_unspecified indx, const sparse_index *_Null_unspecified jndx);                                   \
VECLIB_EXTERN sparse_status sparse_insert_col_##P(M _Null_unspecified A, sparse_index j, sparse_dimension nz,                 \
    const T *_Null_unspecified val, const sparse_index *_Null_unspecified indx);                                              \
VECLIB_EXTERN sparse_status sparse_insert_row_##P(M _Null_unspecified A, sparse_index i, sparse_dimension nz,                 \
    const T *_Null_unspecified val, const sparse_index *_Null_unspecified jndx);                                              \
VECLIB_EXTERN sparse_status sparse_insert_block_##P(M _Null_unspecified A, const T *_Null_unspecified val,                    \
    sparse_dimension row_stride, sparse_dimension col_stride, sparse_index bi, sparse_index bj);                              \
VECLIB_EXTERN sparse_status sparse_extract_sparse_row_##P(M _Null_unspecified A, sparse_index row, sparse_index column_start, \
    sparse_index *_Null_unspecified column_end, sparse_dimension nz, T *_Null_unspecified val,                                \
    sparse_index *_Null_unspecified jndx);                                                                                    \
VECLIB_EXTERN sparse_status sparse_extract_sparse_column_##P(M _Null_unspecified A, sparse_index column, sparse_index row_start, \
    sparse_index *_Null_unspecified row_end, sparse_dimension nz, T *_Null_unspecified val,                                   \
    sparse_index *_Null_unspecified indx);                                                                                    \
VECLIB_EXTERN sparse_status sparse_extract_block_##P(M _Null_unspecified A, sparse_index bi, sparse_index bj,                \
    sparse_dimension row_stride, sparse_dimension col_stride, T *_Null_unspecified val);                                      \
VECLIB_EXTERN long sparse_get_vector_nonzero_count_##P(sparse_dimension N, const T *_Null_unspecified x, sparse_stride incx); \
VECLIB_EXTERN long sparse_pack_vector_##P(sparse_dimension N, sparse_dimension nz, const T *_Null_unspecified x,               \
    sparse_stride incx, T *_Null_unspecified y, sparse_index *_Null_unspecified indy);                                        \
VECLIB_EXTERN void sparse_unpack_vector_##P(sparse_dimension N, sparse_dimension nz, bool zero, const T *_Null_unspecified x,  \
    const sparse_index *_Null_unspecified indx, T *_Null_unspecified y, sparse_stride incy);                                  \
VECLIB_EXTERN T sparse_inner_product_dense_##P(sparse_dimension nz, const T *_Null_unspecified x,                              \
    const sparse_index *_Null_unspecified indx, const T *_Null_unspecified y, sparse_stride incy);                            \
VECLIB_EXTERN T sparse_inner_product_sparse_##P(sparse_dimension nzx, sparse_dimension nzy, const T *_Null_unspecified x,      \
    const sparse_index *_Null_unspecified indx, const T *_Null_unspecified y, const sparse_index *_Null_unspecified indy);    \
VECLIB_EXTERN void sparse_vector_add_with_scale_dense_##P(sparse_dimension nz, T alpha, const T *_Null_unspecified x,          \
    const sparse_index *_Null_unspecified indx, T *_Null_unspecified y, sparse_stride incy);                                  \
VECLIB_EXTERN double sparse_vector_norm_##P(sparse_dimension nz, const T *_Null_unspecified x,                                 \
    const sparse_index *_Null_unspecified indx, sparse_norm norm);                                                            \
VECLIB_EXTERN sparse_status sparse_vector_triangular_solve_dense_##P(enum CBLAS_TRANSPOSE transt, T alpha, M _Null_unspecified T_, \
    T *_Null_unspecified x, sparse_stride incx);                                                                              \
VECLIB_EXTERN sparse_status sparse_matrix_vector_product_dense_##P(enum CBLAS_TRANSPOSE transa, T alpha, M _Null_unspecified A, \
    const T *_Null_unspecified x, sparse_stride incx, T *_Null_unspecified y, sparse_stride incy);                            \
VECLIB_EXTERN sparse_status sparse_matrix_product_dense_##P(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa,               \
    sparse_dimension n, T alpha, M _Null_unspecified A, const T *_Null_unspecified B, sparse_dimension ldb,                   \
    T *_Null_unspecified C, sparse_dimension ldc);                                                                            \
VECLIB_EXTERN sparse_status sparse_matrix_product_sparse_##P(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transa, T alpha,     \
    M _Null_unspecified A, M _Null_unspecified B, T *_Null_unspecified C, sparse_dimension ldc);                              \
VECLIB_EXTERN sparse_status sparse_matrix_triangular_solve_dense_##P(enum CBLAS_ORDER order, enum CBLAS_TRANSPOSE transt,      \
    sparse_dimension nrhs, T alpha, M _Null_unspecified T_, T *_Null_unspecified B, sparse_dimension ldb);                    \
VECLIB_EXTERN sparse_status sparse_outer_product_dense_##P(sparse_dimension M_, sparse_dimension N, sparse_dimension nz,       \
    T alpha, const T *_Null_unspecified x, sparse_stride incx, const T *_Null_unspecified y,                                  \
    const sparse_index *_Null_unspecified indy, M _Nullable *_Null_unspecified C);                                            \
VECLIB_EXTERN sparse_status sparse_permute_rows_##P(M _Null_unspecified A, const sparse_index *_Null_unspecified perm);        \
VECLIB_EXTERN sparse_status sparse_permute_cols_##P(M _Null_unspecified A, const sparse_index *_Null_unspecified perm);        \
VECLIB_EXTERN double sparse_elementwise_norm_##P(M _Null_unspecified A, sparse_norm norm);                                     \
VECLIB_EXTERN double sparse_operator_norm_##P(M _Null_unspecified A, sparse_norm norm);                                        \
VECLIB_EXTERN T sparse_matrix_trace_##P(M _Null_unspecified A, sparse_index offset);

_SPARSE_BLAS(float, float, sparse_matrix_float)
_SPARSE_BLAS(double, double, sparse_matrix_double)
_SPARSE_BLAS(float_complex, _Complex float, sparse_matrix_float_complex)
_SPARSE_BLAS(double_complex, _Complex double, sparse_matrix_double_complex)
#undef _SPARSE_BLAS

#ifdef __cplusplus
}
#endif
#if __has_feature(nullability)
#pragma clang assume_nonnull end
#endif
