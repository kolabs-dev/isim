#pragma once
/* BLAS, the C interface (vecLib's cblas.h): levels 1-3 in single and double precision, real and complex (complex
   arguments are pointers to interleaved real / imaginary pairs), row- and column-major */
#include <Accelerate/vecLibTypes.h>

enum CBLAS_ORDER { CblasRowMajor = 101, CblasColMajor = 102 };
enum CBLAS_TRANSPOSE { CblasNoTrans = 111, CblasTrans = 112, CblasConjTrans = 113, AtlasConj = 114 };
enum CBLAS_UPLO { CblasUpper = 121, CblasLower = 122 };
enum CBLAS_DIAG { CblasNonUnit = 131, CblasUnit = 132 };
enum CBLAS_SIDE { CblasLeft = 141, CblasRight = 142 };
typedef enum CBLAS_ORDER CBLAS_ORDER;
typedef enum CBLAS_TRANSPOSE CBLAS_TRANSPOSE;
typedef enum CBLAS_UPLO CBLAS_UPLO;
typedef enum CBLAS_DIAG CBLAS_DIAG;
typedef enum CBLAS_SIDE CBLAS_SIDE;
typedef CBLAS_ORDER CBLAS_LAYOUT;

#if defined(ACCELERATE_NEW_LAPACK)
#include <Accelerate/lapack_new.h>
#else

#define CBLAS_LEVEL1(T, p) \
    VECLIB_EXTERN T cblas_##p##dot(const int N, const T *X, const int incX, const T *Y, const int incY); \
    VECLIB_EXTERN T cblas_##p##nrm2(const int N, const T *X, const int incX); \
    VECLIB_EXTERN T cblas_##p##asum(const int N, const T *X, const int incX); \
    VECLIB_EXTERN int cblas_i##p##amax(const int N, const T *X, const int incX); \
    VECLIB_EXTERN void cblas_##p##swap(const int N, T *X, const int incX, T *Y, const int incY); \
    VECLIB_EXTERN void cblas_##p##copy(const int N, const T *X, const int incX, T *Y, const int incY); \
    VECLIB_EXTERN void cblas_##p##axpy(const int N, const T alpha, const T *X, const int incX, T *Y, const int incY); \
    VECLIB_EXTERN void cblas_##p##scal(const int N, const T alpha, T *X, const int incX); \
    VECLIB_EXTERN void cblas_##p##rot(const int N, T *X, const int incX, T *Y, const int incY, const T c, const T s); \
    VECLIB_EXTERN void cblas_##p##gemv(const enum CBLAS_ORDER Order, const enum CBLAS_TRANSPOSE TransA, const int M, const int N, \
                                       const T alpha, const T *A, const int lda, const T *X, const int incX, const T beta, T *Y, const int incY); \
    VECLIB_EXTERN void cblas_##p##ger(const enum CBLAS_ORDER Order, const int M, const int N, const T alpha, const T *X, const int incX, \
                                      const T *Y, const int incY, T *A, const int lda); \
    VECLIB_EXTERN void cblas_##p##symv(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const int N, const T alpha, const T *A, \
                                       const int lda, const T *X, const int incX, const T beta, T *Y, const int incY); \
    VECLIB_EXTERN void cblas_##p##trmv(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA, \
                                       const enum CBLAS_DIAG Diag, const int N, const T *A, const int lda, T *X, const int incX); \
    VECLIB_EXTERN void cblas_##p##trsv(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA, \
                                       const enum CBLAS_DIAG Diag, const int N, const T *A, const int lda, T *X, const int incX); \
    VECLIB_EXTERN void cblas_##p##gemm(const enum CBLAS_ORDER Order, const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_TRANSPOSE TransB, \
                                       const int M, const int N, const int K, const T alpha, const T *A, const int lda, const T *B, \
                                       const int ldb, const T beta, T *C, const int ldc); \
    VECLIB_EXTERN void cblas_##p##symm(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, const int M, \
                                       const int N, const T alpha, const T *A, const int lda, const T *B, const int ldb, const T beta, \
                                       T *C, const int ldc); \
    VECLIB_EXTERN void cblas_##p##syrk(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE Trans, \
                                       const int N, const int K, const T alpha, const T *A, const int lda, const T beta, T *C, const int ldc); \
    VECLIB_EXTERN void cblas_##p##trmm(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, \
                                       const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_DIAG Diag, const int M, const int N, \
                                       const T alpha, const T *A, const int lda, T *B, const int ldb); \
    VECLIB_EXTERN void cblas_##p##trsm(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, \
                                       const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_DIAG Diag, const int M, const int N, \
                                       const T alpha, const T *A, const int lda, T *B, const int ldb);
CBLAS_LEVEL1(float, s)
CBLAS_LEVEL1(double, d)
#undef CBLAS_LEVEL1
/* mixed precision */
VECLIB_EXTERN float cblas_sdsdot(const int N, const float alpha, const float *X, const int incX, const float *Y, const int incY);
VECLIB_EXTERN double cblas_dsdot(const int N, const float *X, const int incX, const float *Y, const int incY);

/* complex: c (float) and z (double); R is the real type, rp the real-result prefix (sc / dz), rs the real-scalar one (cs / zd) */
#define CBLAS_COMPLEX(R, p, rp, rs) \
    VECLIB_EXTERN void cblas_##p##dotu_sub(const int N, const void *X, const int incX, const void *Y, const int incY, void *dotu); \
    VECLIB_EXTERN void cblas_##p##dotc_sub(const int N, const void *X, const int incX, const void *Y, const int incY, void *dotc); \
    VECLIB_EXTERN R cblas_##rp##nrm2(const int N, const void *X, const int incX); \
    VECLIB_EXTERN R cblas_##rp##asum(const int N, const void *X, const int incX); \
    VECLIB_EXTERN int cblas_i##p##amax(const int N, const void *X, const int incX); \
    VECLIB_EXTERN void cblas_##p##swap(const int N, void *X, const int incX, void *Y, const int incY); \
    VECLIB_EXTERN void cblas_##p##copy(const int N, const void *X, const int incX, void *Y, const int incY); \
    VECLIB_EXTERN void cblas_##p##axpy(const int N, const void *alpha, const void *X, const int incX, void *Y, const int incY); \
    VECLIB_EXTERN void cblas_##p##scal(const int N, const void *alpha, void *X, const int incX); \
    VECLIB_EXTERN void cblas_##rs##scal(const int N, const R alpha, void *X, const int incX); \
    VECLIB_EXTERN void cblas_##rs##rot(const int N, void *X, const int incX, void *Y, const int incY, const R c, const R s); \
    VECLIB_EXTERN void cblas_##p##rotg(void *a, void *b, R *c, void *s); \
    VECLIB_EXTERN void cblas_##p##gemv(const enum CBLAS_ORDER Order, const enum CBLAS_TRANSPOSE TransA, const int M, const int N, \
                                       const void *alpha, const void *A, const int lda, const void *X, const int incX, const void *beta, \
                                       void *Y, const int incY); \
    VECLIB_EXTERN void cblas_##p##geru(const enum CBLAS_ORDER Order, const int M, const int N, const void *alpha, const void *X, \
                                       const int incX, const void *Y, const int incY, void *A, const int lda); \
    VECLIB_EXTERN void cblas_##p##gerc(const enum CBLAS_ORDER Order, const int M, const int N, const void *alpha, const void *X, \
                                       const int incX, const void *Y, const int incY, void *A, const int lda); \
    VECLIB_EXTERN void cblas_##p##hemv(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const int N, const void *alpha, \
                                       const void *A, const int lda, const void *X, const int incX, const void *beta, void *Y, const int incY); \
    VECLIB_EXTERN void cblas_##p##her(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const int N, const R alpha, const void *X, \
                                      const int incX, void *A, const int lda); \
    VECLIB_EXTERN void cblas_##p##her2(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const int N, const void *alpha, \
                                       const void *X, const int incX, const void *Y, const int incY, void *A, const int lda); \
    VECLIB_EXTERN void cblas_##p##trmv(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA, \
                                       const enum CBLAS_DIAG Diag, const int N, const void *A, const int lda, void *X, const int incX); \
    VECLIB_EXTERN void cblas_##p##trsv(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA, \
                                       const enum CBLAS_DIAG Diag, const int N, const void *A, const int lda, void *X, const int incX); \
    VECLIB_EXTERN void cblas_##p##gemm(const enum CBLAS_ORDER Order, const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_TRANSPOSE TransB, \
                                       const int M, const int N, const int K, const void *alpha, const void *A, const int lda, \
                                       const void *B, const int ldb, const void *beta, void *C, const int ldc); \
    VECLIB_EXTERN void cblas_##p##symm(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, const int M, \
                                       const int N, const void *alpha, const void *A, const int lda, const void *B, const int ldb, \
                                       const void *beta, void *C, const int ldc); \
    VECLIB_EXTERN void cblas_##p##hemm(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, const int M, \
                                       const int N, const void *alpha, const void *A, const int lda, const void *B, const int ldb, \
                                       const void *beta, void *C, const int ldc); \
    VECLIB_EXTERN void cblas_##p##syrk(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE Trans, \
                                       const int N, const int K, const void *alpha, const void *A, const int lda, const void *beta, \
                                       void *C, const int ldc); \
    VECLIB_EXTERN void cblas_##p##herk(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE Trans, \
                                       const int N, const int K, const R alpha, const void *A, const int lda, const R beta, void *C, \
                                       const int ldc); \
    VECLIB_EXTERN void cblas_##p##syr2k(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE Trans, \
                                        const int N, const int K, const void *alpha, const void *A, const int lda, const void *B, \
                                        const int ldb, const void *beta, void *C, const int ldc); \
    VECLIB_EXTERN void cblas_##p##her2k(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE Trans, \
                                        const int N, const int K, const void *alpha, const void *A, const int lda, const void *B, \
                                        const int ldb, const R beta, void *C, const int ldc); \
    VECLIB_EXTERN void cblas_##p##trmm(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, \
                                       const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_DIAG Diag, const int M, const int N, \
                                       const void *alpha, const void *A, const int lda, void *B, const int ldb); \
    VECLIB_EXTERN void cblas_##p##trsm(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side, const enum CBLAS_UPLO Uplo, \
                                       const enum CBLAS_TRANSPOSE TransA, const enum CBLAS_DIAG Diag, const int M, const int N, \
                                       const void *alpha, const void *A, const int lda, void *B, const int ldb);
CBLAS_COMPLEX(float, c, sc, cs)
CBLAS_COMPLEX(double, z, dz, zd)
#undef CBLAS_COMPLEX
#endif /* ACCELERATE_NEW_LAPACK */
