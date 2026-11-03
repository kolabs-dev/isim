#pragma once
/* LAPACK (vecLib's clapack.h): Fortran calling conventions (every argument by pointer, column-major matrices).
   isim implements the common drivers: LU (getrf, getrs, gesv, getri), Cholesky (potrf, potrs, posv), least squares
   (gels), the symmetric (syev) and nonsymmetric (geev) eigenproblems, the SVD (gesvd, gesdd), banded LU and Cholesky
   (gbtrf, gbtrs, gbsv, pbtrf, pbtrs, pbsv) and tridiagonal systems (gtsv), in single and double precision; and in
   complex (c, z): getrf, getrs, gesv, potrf, potrs, posv and heev. */
#include <Accelerate/vecLibTypes.h>

typedef int __CLPK_integer;
typedef int __CLPK_logical;
typedef float __CLPK_real;
typedef double __CLPK_doublereal;
typedef __CLPK_logical (*__CLPK_L_fp)(void);
typedef int __CLPK_ftnlen;
typedef struct { __CLPK_real r, i; } __CLPK_complex;
typedef struct { __CLPK_doublereal r, i; } __CLPK_doublecomplex;

#if !defined(ACCELERATE_NEW_LAPACK)   /* the new interface (lapack_new.h, through cblas.h) replaces these */
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
                               __CLPK_integer *info); \
    VECLIB_EXTERN int p##gesvd_(char *jobu, char *jobvt, __CLPK_integer *m, __CLPK_integer *n, T *a, __CLPK_integer *lda, T *s, T *u, \
                                __CLPK_integer *ldu, T *vt, __CLPK_integer *ldvt, T *work, __CLPK_integer *lwork, __CLPK_integer *info); \
    VECLIB_EXTERN int p##gesdd_(char *jobz, __CLPK_integer *m, __CLPK_integer *n, T *a, __CLPK_integer *lda, T *s, T *u, __CLPK_integer *ldu, \
                                T *vt, __CLPK_integer *ldvt, T *work, __CLPK_integer *lwork, __CLPK_integer *iwork, __CLPK_integer *info); \
    VECLIB_EXTERN int p##geev_(char *jobvl, char *jobvr, __CLPK_integer *n, T *a, __CLPK_integer *lda, T *wr, T *wi, T *vl, \
                               __CLPK_integer *ldvl, T *vr, __CLPK_integer *ldvr, T *work, __CLPK_integer *lwork, __CLPK_integer *info); \
    VECLIB_EXTERN int p##gbtrf_(__CLPK_integer *m, __CLPK_integer *n, __CLPK_integer *kl, __CLPK_integer *ku, T *ab, __CLPK_integer *ldab, \
                                __CLPK_integer *ipiv, __CLPK_integer *info); \
    VECLIB_EXTERN int p##gbtrs_(char *trans, __CLPK_integer *n, __CLPK_integer *kl, __CLPK_integer *ku, __CLPK_integer *nrhs, T *ab, \
                                __CLPK_integer *ldab, __CLPK_integer *ipiv, T *b, __CLPK_integer *ldb, __CLPK_integer *info); \
    VECLIB_EXTERN int p##gbsv_(__CLPK_integer *n, __CLPK_integer *kl, __CLPK_integer *ku, __CLPK_integer *nrhs, T *ab, __CLPK_integer *ldab, \
                               __CLPK_integer *ipiv, T *b, __CLPK_integer *ldb, __CLPK_integer *info); \
    VECLIB_EXTERN int p##pbtrf_(char *uplo, __CLPK_integer *n, __CLPK_integer *kd, T *ab, __CLPK_integer *ldab, __CLPK_integer *info); \
    VECLIB_EXTERN int p##pbtrs_(char *uplo, __CLPK_integer *n, __CLPK_integer *kd, __CLPK_integer *nrhs, T *ab, __CLPK_integer *ldab, T *b, \
                                __CLPK_integer *ldb, __CLPK_integer *info); \
    VECLIB_EXTERN int p##pbsv_(char *uplo, __CLPK_integer *n, __CLPK_integer *kd, __CLPK_integer *nrhs, T *ab, __CLPK_integer *ldab, T *b, \
                               __CLPK_integer *ldb, __CLPK_integer *info); \
    VECLIB_EXTERN int p##gtsv_(__CLPK_integer *n, __CLPK_integer *nrhs, T *dl, T *d, T *du, T *b, __CLPK_integer *ldb, __CLPK_integer *info);
CLAPACK_DECL(__CLPK_real, s)
CLAPACK_DECL(__CLPK_doublereal, d)
#undef CLAPACK_DECL
#define CLAPACK_COMPLEX(T, R, p) \
    VECLIB_EXTERN int p##getrf_(__CLPK_integer *m, __CLPK_integer *n, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, __CLPK_integer *info); \
    VECLIB_EXTERN int p##getrs_(char *trans, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, \
                                T *b, __CLPK_integer *ldb, __CLPK_integer *info); \
    VECLIB_EXTERN int p##gesv_(__CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, T *b, \
                               __CLPK_integer *ldb, __CLPK_integer *info); \
    VECLIB_EXTERN int p##potrf_(char *uplo, __CLPK_integer *n, T *a, __CLPK_integer *lda, __CLPK_integer *info); \
    VECLIB_EXTERN int p##potrs_(char *uplo, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, T *b, __CLPK_integer *ldb, \
                                __CLPK_integer *info); \
    VECLIB_EXTERN int p##posv_(char *uplo, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, T *b, __CLPK_integer *ldb, \
                               __CLPK_integer *info); \
    VECLIB_EXTERN int p##heev_(char *jobz, char *uplo, __CLPK_integer *n, T *a, __CLPK_integer *lda, R *w, T *work, __CLPK_integer *lwork, \
                               R *rwork, __CLPK_integer *info);
CLAPACK_COMPLEX(__CLPK_complex, __CLPK_real, c)
CLAPACK_COMPLEX(__CLPK_doublecomplex, __CLPK_doublereal, z)
#undef CLAPACK_COMPLEX
#endif
