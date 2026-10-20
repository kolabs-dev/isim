#pragma once
/* LAPACK (vecLib's clapack.h): Fortran calling conventions (every argument by pointer, column-major matrices).
   isim implements the common drivers: LU (getrf, getrs, gesv, getri), Cholesky (potrf, potrs, posv), least squares
   (gels) and the symmetric eigenproblem (syev), in single and double precision. */
#include <Accelerate/vecLibTypes.h>

typedef int __CLPK_integer;
typedef int __CLPK_logical;
typedef float __CLPK_real;
typedef double __CLPK_doublereal;
typedef __CLPK_logical (*__CLPK_L_fp)(void);
typedef int __CLPK_ftnlen;

#define CLAPACK_DECL(T, p) \
    VECLIB_EXTERN int p##getrf_(__CLPK_integer *m, __CLPK_integer *n, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, __CLPK_integer *info); \
    VECLIB_EXTERN int p##getrs_(char *trans, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, \
                                T *b, __CLPK_integer *ldb, __CLPK_integer *info); \
    VECLIB_EXTERN int p##gesv_(__CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, T *b, \
                               __CLPK_integer *ldb, __CLPK_integer *info); \
    VECLIB_EXTERN int p##getri_(__CLPK_integer *n, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, T *work, __CLPK_integer *lwork, \
                                __CLPK_integer *info); \
    VECLIB_EXTERN int p##potrf_(char *uplo, __CLPK_integer *n, T *a, __CLPK_integer *lda, __CLPK_integer *info); \
    VECLIB_EXTERN int p##potrs_(char *uplo, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, T *b, __CLPK_integer *ldb, \
                                __CLPK_integer *info); \
    VECLIB_EXTERN int p##posv_(char *uplo, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, T *b, __CLPK_integer *ldb, \
                               __CLPK_integer *info); \
    VECLIB_EXTERN int p##gels_(char *trans, __CLPK_integer *m, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, T *b, \
                               __CLPK_integer *ldb, T *work, __CLPK_integer *lwork, __CLPK_integer *info); \
    VECLIB_EXTERN int p##syev_(char *jobz, char *uplo, __CLPK_integer *n, T *a, __CLPK_integer *lda, T *w, T *work, __CLPK_integer *lwork, \
                               __CLPK_integer *info);
CLAPACK_DECL(__CLPK_real, s)
CLAPACK_DECL(__CLPK_doublereal, d)
#undef CLAPACK_DECL
