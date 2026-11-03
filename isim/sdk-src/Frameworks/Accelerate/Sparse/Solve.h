#pragma once
/* isim Accelerate: Sparse Solvers (issue #807), Apple's Sparse/Solve.h interface over isim's C implementation
   (frameworks/Accelerate/sparse*.c). The overloadable functions are inline wrappers over exported per-type
   functions (_Sparse..._Double, _Float, _Complex_Double, _Complex_Float), so Swift sees them as overloads. */
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <Accelerate/vecLibTypes.h>
#include <Accelerate/cblas.h>
#include <Accelerate/Sparse/BLAS.h>

#ifndef SPARSE_INLINE
#define SPARSE_INLINE static inline __attribute__((overloadable, always_inline, unused))
#endif
#if __has_feature(nullability)
#pragma clang assume_nonnull begin
#endif
#ifdef __cplusplus
extern "C" {
#endif

/* ---- enumerations ---- */
typedef enum : uint8_t { SparseUpperTriangle = 0, SparseLowerTriangle = 1 } SparseTriangle_t;
typedef enum : unsigned int {
    SparseOrdinary = 0, SparseTriangular = 1, SparseUnitTriangular = 2, SparseSymmetric = 3, SparseHermitian = 4
} SparseKind_t;
typedef enum : int {
    SparseStatusOK = 0, SparseFactorizationFailed = -1, SparseMatrixIsSingular = -2, SparseInternalError = -3,
    SparseParameterError = -4, SparseStatusReleased = -2147483647
} SparseStatus_t;
typedef enum : uint8_t {
    SparseFactorizationCholesky = 0, SparseFactorizationLDLT = 1, SparseFactorizationLDLTUnpivoted = 2,
    SparseFactorizationLDLTSBK = 3, SparseFactorizationLDLTTPP = 4, SparseFactorizationQR = 40,
    SparseFactorizationCholeskyAtA = 41, SparseFactorizationLU = 80, SparseFactorizationLUUnpivoted = 81,
    SparseFactorizationLUSPP = 82, SparseFactorizationLUTPP = 83
} SparseFactorization_t;
typedef enum : unsigned int { SparseDefaultControl = 0 } SparseControl_t;
typedef enum : uint8_t {
    SparseOrderDefault = 0, SparseOrderUser = 1, SparseOrderAMD = 2, SparseOrderMetis = 3, SparseOrderCOLAMD = 4,
    SparseOrderMTMetis = 5
} SparseOrder_t;
typedef enum : uint8_t {
    SparseScalingDefault = 0, SparseScalingUser = 1, SparseScalingEquilibriationInf = 2,
    SparseScalingHungarianScalingOnly = 3, SparseScalingHungarianScalingAndOrdering = 4
} SparseScaling_t;
typedef enum : uint8_t {
    SparseSubfactorInvalid = 0, SparseSubfactorP = 1, SparseSubfactorS = 2, SparseSubfactorL = 3, SparseSubfactorD = 4,
    SparseSubfactorPLPS = 5, SparseSubfactorQ = 6, SparseSubfactorR = 7, SparseSubfactorRP = 8, SparseSubfactorSr = 9,
    SparseSubfactorSc = 10
} SparseSubfactor_t;
typedef enum : uint8_t { SparseUpdatePartialRefactor = 0 } SparseUpdate_t;
typedef enum : int {
    SparsePreconditionerNone = 0, SparsePreconditionerUser = 1, SparsePreconditionerDiagonal = 2,
    SparsePreconditionerDiagScaling = 3
} SparsePreconditioner_t;
typedef enum : int {
    SparseIterativeConverged = 0, SparseIterativeMaxIterations = 1, SparseIterativeParameterError = -1,
    SparseIterativeIllConditioned = -2, SparseIterativeInternalError = -99
} SparseIterativeStatus_t;
typedef enum : uint8_t { SparseVariantDQGMRES = 0, SparseVariantGMRES = 1, SparseVariantFGMRES = 2 } SparseGMRESVariant_t;
typedef enum : int { SparseLSMRCTDefault = 0, SparseLSMRCTFongSaunders = 1 } SparseLSMRConvergenceTest_t;

/* ---- matrices and vectors (column-major; sparse matrices in compressed sparse column form) ---- */
typedef struct {
    bool transpose : 1;
    SparseTriangle_t triangle : 1;
    SparseKind_t kind : 2;
    unsigned int _reserved : 11;
    bool _allocatedBySparse : 1;
} SparseAttributes_t;
typedef struct {
    bool transpose : 1;
    SparseTriangle_t triangle : 1;
    SparseKind_t kind : 3;
    bool conjugate_transpose : 1;
    unsigned int _reserved : 9;
    bool _allocatedBySparse : 1;
} SparseAttributesComplex_t;
typedef struct {
    int rowCount;
    int columnCount;
    long *columnStarts;
    int *rowIndices;
    SparseAttributes_t attributes;
    uint8_t blockSize;
} SparseMatrixStructure;
typedef struct {
    int rowCount;
    int columnCount;
    long *columnStarts;
    int *rowIndices;
    SparseAttributesComplex_t attributes;
    uint8_t blockSize;
} SparseMatrixStructureComplex;

/* ---- factorization options ---- */
typedef struct {
    SparseControl_t control;
    SparseOrder_t orderMethod;
    int *_Nullable order;
    int *_Nullable ignoreRowsAndColumns;
    void *_Nullable (*malloc)(size_t size);
    void (*free)(void *_Nullable pointer);
    void (*_Nullable reportError)(const char *message);
} SparseSymbolicFactorOptions;
typedef struct {
    SparseControl_t control;
    SparseScaling_t scalingMethod;
    void *_Nullable scaling;
    double pivotTolerance;
    double zeroTolerance;
} SparseNumericFactorOptions;
typedef struct {
    SparseStatus_t status;
    int rowCount;
    int columnCount;
    SparseAttributes_t attributes;
    uint8_t blockSize;
    SparseFactorization_t type;
    void *_Nullable factorization;
    size_t workspaceSize_Float;
    size_t workspaceSize_Double;
    size_t factorSize_Float;
    size_t factorSize_Double;
} SparseOpaqueSymbolicFactorization;

/* ---- iterative methods ---- */
typedef struct {
    void (*_Nullable reportError)(const char *message);
    int maxIterations;
    double atol;
    double rtol;
    void (*_Nullable reportStatus)(const char *message);
} SparseCGOptions;
typedef struct {
    void (*_Nullable reportError)(const char *message);
    SparseGMRESVariant_t variant;
    int nvec;
    int maxIterations;
    double atol;
    double rtol;
    void (*_Nullable reportStatus)(const char *message);
} SparseGMRESOptions;
typedef struct {
    void (*_Nullable reportError)(const char *message);
    double lambda;
    int nvec;
    SparseLSMRConvergenceTest_t convergenceTest;
    double atol;
    double rtol;
    double btol;
    double conditionLimit;
    int maxIterations;
    void (*_Nullable reportStatus)(const char *message);
} SparseLSMROptions;
typedef struct {
    int method;   /* 0 CG, 1 GMRES, 2 LSMR */
    union {
        SparseCGOptions cg;
        SparseGMRESOptions gmres;
        SparseLSMROptions lsmr;
        char padding[2048];
    } options;
} SparseIterativeMethod;

SPARSE_INLINE SparseIterativeMethod SparseConjugateGradient(SparseCGOptions options) {
    SparseIterativeMethod m = { 0 }; m.method = 0; m.options.cg = options; return m;
}
SPARSE_INLINE SparseIterativeMethod SparseConjugateGradient(void) { SparseCGOptions o = { 0 }; return SparseConjugateGradient(o); }
SPARSE_INLINE SparseIterativeMethod SparseGMRES(SparseGMRESOptions options) {
    SparseIterativeMethod m = { 0 }; m.method = 1; m.options.gmres = options; return m;
}
SPARSE_INLINE SparseIterativeMethod SparseGMRES(void) { SparseGMRESOptions o = { 0 }; return SparseGMRES(o); }
SPARSE_INLINE SparseIterativeMethod SparseLSMR(SparseLSMROptions options) {
    SparseIterativeMethod m = { 0 }; m.method = 2; m.options.lsmr = options; return m;
}
SPARSE_INLINE SparseIterativeMethod SparseLSMR(void) { SparseLSMROptions o = { 0 }; return SparseLSMR(o); }

/* ---- the symbolic factorization (shared by every scalar type) ---- */
VECLIB_EXTERN SparseOpaqueSymbolicFactorization _SparseSymbolicFactor(SparseFactorization_t type, SparseMatrixStructure structure,
                                                                      const SparseSymbolicFactorOptions *_Nullable options, bool hermitian);
VECLIB_EXTERN void _SparseRetainSymbolic(SparseOpaqueSymbolicFactorization *factor);
VECLIB_EXTERN void _SparseCleanupSymbolic(SparseOpaqueSymbolicFactorization factor);
SPARSE_INLINE SparseOpaqueSymbolicFactorization SparseFactor(SparseFactorization_t type, SparseMatrixStructure Matrix,
                                                             SparseSymbolicFactorOptions sfoptions) {
    return _SparseSymbolicFactor(type, Matrix, &sfoptions, false);
}
SPARSE_INLINE SparseOpaqueSymbolicFactorization SparseFactor(SparseFactorization_t type, SparseMatrixStructure Matrix) {
    return _SparseSymbolicFactor(type, Matrix, NULL, false);
}
SPARSE_INLINE SparseMatrixStructure _SparseRealStructure(SparseMatrixStructureComplex m) {
    SparseMatrixStructure s = { m.rowCount, m.columnCount, m.columnStarts, m.rowIndices, { 0 }, m.blockSize };
    s.attributes.transpose = m.attributes.transpose || m.attributes.conjugate_transpose;
    s.attributes.triangle = m.attributes.triangle;
    s.attributes.kind = m.attributes.kind == SparseHermitian ? SparseSymmetric : (SparseKind_t)(m.attributes.kind & 3);
    return s;
}
SPARSE_INLINE SparseOpaqueSymbolicFactorization SparseFactor(SparseFactorization_t type, SparseMatrixStructureComplex Matrix,
                                                             SparseSymbolicFactorOptions sfoptions) {
    return _SparseSymbolicFactor(type, _SparseRealStructure(Matrix), &sfoptions, Matrix.attributes.kind == SparseHermitian);
}
SPARSE_INLINE SparseOpaqueSymbolicFactorization SparseFactor(SparseFactorization_t type, SparseMatrixStructureComplex Matrix) {
    return _SparseSymbolicFactor(type, _SparseRealStructure(Matrix), NULL, Matrix.attributes.kind == SparseHermitian);
}
SPARSE_INLINE SparseOpaqueSymbolicFactorization SparseRetain(SparseOpaqueSymbolicFactorization SymbolicFactor) {
    _SparseRetainSymbolic(&SymbolicFactor); return SymbolicFactor;
}
SPARSE_INLINE void SparseCleanup(SparseOpaqueSymbolicFactorization SymbolicFactor) { _SparseCleanupSymbolic(SymbolicFactor); }

/* ---- per scalar type ---- */
#define _SPARSE_TYPES(X, T, ATTR, STRUCT)                                                                                       \
typedef struct { int count; T *data; } DenseVector_##X;                                                                        \
typedef struct { int rowCount; int columnCount; int columnStride; ATTR attributes; T *data; } DenseMatrix_##X;                 \
typedef struct { STRUCT structure; T *data; } SparseMatrix_##X;                                                                \
typedef struct {                                                                                                               \
    SparseStatus_t status;                                                                                                     \
    ATTR attributes;                                                                                                           \
    SparseOpaqueSymbolicFactorization symbolicFactorization;                                                                   \
    bool userFactorStorage;                                                                                                    \
    void *_Nullable numericFactorization;                                                                                      \
    size_t solveWorkspaceRequiredStatic;                                                                                       \
    size_t solveWorkspaceRequiredPerRHS;                                                                                       \
} SparseOpaqueFactorization_##X;                                                                                               \
typedef struct {                                                                                                               \
    ATTR attributes;                                                                                                           \
    SparseSubfactor_t contents;                                                                                                \
    SparseOpaqueFactorization_##X factor;                                                                                      \
    size_t workspaceRequiredStatic;                                                                                            \
    size_t workspaceRequiredPerRHS;                                                                                            \
} SparseOpaqueSubfactor_##X;                                                                                                   \
typedef struct {                                                                                                               \
    SparsePreconditioner_t type;                                                                                               \
    void *mem;                                                                                                                 \
    void (*apply)(void *mem, enum CBLAS_TRANSPOSE trans, DenseMatrix_##X X, DenseMatrix_##X Y);                                \
} SparseOpaquePreconditioner_##X;

#define _SPARSE_EXPORTS(X, T, ATTR, STRUCT)                                                                                     \
VECLIB_EXTERN SparseMatrix_##X _SparseConvertFromCoordinate_##X(int rowCount, int columnCount, long blockCount, uint8_t blockSize, \
    ATTR attributes, const int *row, const int *column, const T *data, void *_Nullable storage, void *_Nullable workspace);    \
VECLIB_EXTERN void _SparseCleanupMatrix_##X(SparseMatrix_##X A);                                                               \
VECLIB_EXTERN void _SparseMultiply_##X(T alpha, SparseMatrix_##X A, DenseMatrix_##X x, DenseMatrix_##X y, bool accumulate);    \
VECLIB_EXTERN void _SparseMultiplyOp_##X(SparseMatrix_##X A, enum CBLAS_TRANSPOSE trans, DenseMatrix_##X x, DenseMatrix_##X y,  \
    bool accumulate);                                                                                                          \
VECLIB_EXTERN SparseOpaqueFactorization_##X _SparseFactor_##X(SparseFactorization_t type, SparseMatrix_##X A,                  \
    const SparseSymbolicFactorOptions *_Nullable sfoptions, const SparseNumericFactorOptions *_Nullable nfoptions);             \
VECLIB_EXTERN SparseOpaqueFactorization_##X _SparseNumericFactor_##X(SparseOpaqueSymbolicFactorization symbolic,               \
    SparseMatrix_##X A, const SparseNumericFactorOptions *_Nullable nfoptions, void *_Nullable factorStorage,                  \
    void *_Nullable workspace);                                                                                                \
VECLIB_EXTERN void _SparseRefactor_##X(SparseMatrix_##X A, SparseOpaqueFactorization_##X *factor,                              \
    const SparseNumericFactorOptions *_Nullable nfoptions, void *_Nullable workspace);                                         \
VECLIB_EXTERN void _SparseUpdateFactor_##X(SparseUpdate_t update, SparseOpaqueFactorization_##X *factor, int count,            \
    const int *indices, SparseMatrix_##X A);                                                                                   \
VECLIB_EXTERN void _SparseRetainFactor_##X(SparseOpaqueFactorization_##X *factor);                                             \
VECLIB_EXTERN void _SparseCleanupFactor_##X(SparseOpaqueFactorization_##X factor);                                             \
VECLIB_EXTERN void _SparseSolveFactor_##X(SparseOpaqueFactorization_##X factor, DenseMatrix_##X B, DenseMatrix_##X X,          \
    void *_Nullable workspace);                                                                                                \
VECLIB_EXTERN SparseOpaqueSubfactor_##X _SparseCreateSubfactor_##X(SparseSubfactor_t subfactor, SparseOpaqueFactorization_##X factor); \
VECLIB_EXTERN void _SparseSubfactorApply_##X(SparseOpaqueSubfactor_##X subfactor, bool solve, DenseMatrix_##X x,              \
    DenseMatrix_##X y, void *_Nullable workspace);                                                                             \
VECLIB_EXTERN int _SparseGetInertia_##X(SparseOpaqueFactorization_##X factor, int *zero, int *negative, int *positive);       \
VECLIB_EXTERN SparseOpaquePreconditioner_##X _SparseCreatePreconditioner_##X(SparsePreconditioner_t type, SparseMatrix_##X A); \
VECLIB_EXTERN void _SparseCleanupPreconditioner_##X(SparseOpaquePreconditioner_##X P);                                        \
VECLIB_EXTERN SparseIterativeStatus_t _SparseSolveIterative_##X(SparseIterativeMethod method,                                 \
    void (^ApplyOperator)(bool accumulate, enum CBLAS_TRANSPOSE trans, DenseMatrix_##X x, DenseMatrix_##X y),                  \
    DenseMatrix_##X B, DenseMatrix_##X X, const SparseOpaquePreconditioner_##X *_Nullable P);                                  \
VECLIB_EXTERN void _SparseIterate_##X(SparseIterativeMethod method, int iteration, const bool *converged, void *state,        \
    void (^ApplyOperator)(bool accumulate, enum CBLAS_TRANSPOSE trans, DenseMatrix_##X x, DenseMatrix_##X y),                  \
    DenseMatrix_##X B, DenseMatrix_##X R, DenseMatrix_##X X, const SparseOpaquePreconditioner_##X *_Nullable P);               \
VECLIB_EXTERN size_t SparseGetStateSize_##X(SparseIterativeMethod method, bool preconditioner, int m, int n, int nrhs);

#define _SPARSE_INLINES(X, T, ATTR, STRUCT)                                                                                     \
SPARSE_INLINE DenseMatrix_##X _SparseVecAsMat(DenseVector_##X v) {                                                             \
    DenseMatrix_##X m = { v.count, 1, v.count, { 0 }, v.data }; return m;                                                      \
}                                                                                                                              \
SPARSE_INLINE SparseMatrix_##X SparseConvertFromCoordinate(int rowCount, int columnCount, long blockCount, uint8_t blockSize, \
    ATTR attributes, const int *row, const int *column, const T *data) {                                                       \
    return _SparseConvertFromCoordinate_##X(rowCount, columnCount, blockCount, blockSize, attributes, row, column, data, NULL, NULL); \
}                                                                                                                              \
SPARSE_INLINE SparseMatrix_##X SparseConvertFromCoordinate(int rowCount, int columnCount, long blockCount, uint8_t blockSize, \
    ATTR attributes, const int *row, const int *column, const T *data, void *storage, void *workspace) {                       \
    return _SparseConvertFromCoordinate_##X(rowCount, columnCount, blockCount, blockSize, attributes, row, column, data, storage, workspace); \
}                                                                                                                              \
SPARSE_INLINE void SparseCleanup(SparseMatrix_##X Matrix) { _SparseCleanupMatrix_##X(Matrix); }                                \
SPARSE_INLINE SparseMatrix_##X SparseGetTranspose(SparseMatrix_##X Matrix) {                                                   \
    Matrix.structure.attributes.transpose = !Matrix.structure.attributes.transpose; return Matrix;                             \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiply(SparseMatrix_##X A, DenseMatrix_##X X, DenseMatrix_##X Y) { _SparseMultiply_##X(1, A, X, Y, false); } \
SPARSE_INLINE void SparseMultiply(SparseMatrix_##X A, DenseVector_##X x, DenseVector_##X y) {                                  \
    _SparseMultiply_##X(1, A, _SparseVecAsMat(x), _SparseVecAsMat(y), false);                                                  \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiply(T alpha, SparseMatrix_##X A, DenseMatrix_##X X, DenseMatrix_##X Y) {                        \
    _SparseMultiply_##X(alpha, A, X, Y, false);                                                                                \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiply(T alpha, SparseMatrix_##X A, DenseVector_##X x, DenseVector_##X y) {                        \
    _SparseMultiply_##X(alpha, A, _SparseVecAsMat(x), _SparseVecAsMat(y), false);                                              \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiplyAdd(SparseMatrix_##X A, DenseMatrix_##X X, DenseMatrix_##X Y) { _SparseMultiply_##X(1, A, X, Y, true); } \
SPARSE_INLINE void SparseMultiplyAdd(SparseMatrix_##X A, DenseVector_##X x, DenseVector_##X y) {                               \
    _SparseMultiply_##X(1, A, _SparseVecAsMat(x), _SparseVecAsMat(y), true);                                                   \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiplyAdd(T alpha, SparseMatrix_##X A, DenseMatrix_##X X, DenseMatrix_##X Y) {                     \
    _SparseMultiply_##X(alpha, A, X, Y, true);                                                                                 \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiplyAdd(T alpha, SparseMatrix_##X A, DenseVector_##X x, DenseVector_##X y) {                     \
    _SparseMultiply_##X(alpha, A, _SparseVecAsMat(x), _SparseVecAsMat(y), true);                                               \
}                                                                                                                              \
SPARSE_INLINE SparseOpaqueFactorization_##X SparseFactor(SparseFactorization_t type, SparseMatrix_##X Matrix) {               \
    return _SparseFactor_##X(type, Matrix, NULL, NULL);                                                                        \
}                                                                                                                              \
SPARSE_INLINE SparseOpaqueFactorization_##X SparseFactor(SparseFactorization_t type, SparseMatrix_##X Matrix,                 \
    SparseSymbolicFactorOptions sfoptions, SparseNumericFactorOptions nfoptions) {                                             \
    return _SparseFactor_##X(type, Matrix, &sfoptions, &nfoptions);                                                            \
}                                                                                                                              \
SPARSE_INLINE SparseOpaqueFactorization_##X SparseFactor(SparseOpaqueSymbolicFactorization SymbolicFactor, SparseMatrix_##X Matrix) { \
    return _SparseNumericFactor_##X(SymbolicFactor, Matrix, NULL, NULL, NULL);                                                 \
}                                                                                                                              \
SPARSE_INLINE SparseOpaqueFactorization_##X SparseFactor(SparseOpaqueSymbolicFactorization SymbolicFactor, SparseMatrix_##X Matrix, \
    SparseNumericFactorOptions nfoptions) {                                                                                    \
    return _SparseNumericFactor_##X(SymbolicFactor, Matrix, &nfoptions, NULL, NULL);                                           \
}                                                                                                                              \
SPARSE_INLINE SparseOpaqueFactorization_##X SparseFactor(SparseOpaqueSymbolicFactorization SymbolicFactor, SparseMatrix_##X Matrix, \
    SparseNumericFactorOptions nfoptions, void *_Nullable factorStorage, void *_Nullable workspace) {                          \
    return _SparseNumericFactor_##X(SymbolicFactor, Matrix, &nfoptions, factorStorage, workspace);                             \
}                                                                                                                              \
SPARSE_INLINE void SparseRefactor(SparseMatrix_##X Matrix, SparseOpaqueFactorization_##X *Factorization) {                    \
    _SparseRefactor_##X(Matrix, Factorization, NULL, NULL);                                                                    \
}                                                                                                                              \
SPARSE_INLINE void SparseRefactor(SparseMatrix_##X Matrix, SparseOpaqueFactorization_##X *Factorization,                      \
    SparseNumericFactorOptions nfoptions) { _SparseRefactor_##X(Matrix, Factorization, &nfoptions, NULL); }                    \
SPARSE_INLINE void SparseRefactor(SparseMatrix_##X Matrix, SparseOpaqueFactorization_##X *Factorization, void *workspace) {   \
    _SparseRefactor_##X(Matrix, Factorization, NULL, workspace);                                                               \
}                                                                                                                              \
SPARSE_INLINE void SparseRefactor(SparseMatrix_##X Matrix, SparseOpaqueFactorization_##X *Factorization,                      \
    SparseNumericFactorOptions nfoptions, void *workspace) { _SparseRefactor_##X(Matrix, Factorization, &nfoptions, workspace); } \
SPARSE_INLINE void SparseUpdateFactor(SparseUpdate_t updateType, SparseOpaqueFactorization_##X *Factorization,                \
    int updateCount, const int *updatedIndices, SparseMatrix_##X newMatrix) {                                                  \
    _SparseUpdateFactor_##X(updateType, Factorization, updateCount, updatedIndices, newMatrix);                               \
}                                                                                                                              \
SPARSE_INLINE SparseOpaqueFactorization_##X SparseRetain(SparseOpaqueFactorization_##X NumericFactor) {                       \
    _SparseRetainFactor_##X(&NumericFactor); return NumericFactor;                                                             \
}                                                                                                                              \
SPARSE_INLINE void SparseCleanup(SparseOpaqueFactorization_##X Opaque) { _SparseCleanupFactor_##X(Opaque); }                   \
SPARSE_INLINE SparseOpaqueFactorization_##X SparseGetTranspose(SparseOpaqueFactorization_##X Factor) {                        \
    Factor.attributes.transpose = !Factor.attributes.transpose; return Factor;                                                 \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueFactorization_##X Factored, DenseMatrix_##X XB) {                                   \
    _SparseSolveFactor_##X(Factored, XB, XB, NULL);                                                                            \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueFactorization_##X Factored, DenseMatrix_##X B, DenseMatrix_##X X) {               \
    _SparseSolveFactor_##X(Factored, B, X, NULL);                                                                              \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueFactorization_##X Factored, DenseMatrix_##X XB, void *workspace) {                 \
    _SparseSolveFactor_##X(Factored, XB, XB, workspace);                                                                       \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueFactorization_##X Factored, DenseMatrix_##X B, DenseMatrix_##X X, void *workspace) { \
    _SparseSolveFactor_##X(Factored, B, X, workspace);                                                                         \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueFactorization_##X Factored, DenseVector_##X xb) {                                   \
    _SparseSolveFactor_##X(Factored, _SparseVecAsMat(xb), _SparseVecAsMat(xb), NULL);                                          \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueFactorization_##X Factored, DenseVector_##X b, DenseVector_##X x) {               \
    _SparseSolveFactor_##X(Factored, _SparseVecAsMat(b), _SparseVecAsMat(x), NULL);                                            \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueFactorization_##X Factored, DenseVector_##X xb, void *workspace) {                 \
    _SparseSolveFactor_##X(Factored, _SparseVecAsMat(xb), _SparseVecAsMat(xb), workspace);                                     \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueFactorization_##X Factored, DenseVector_##X b, DenseVector_##X x, void *workspace) { \
    _SparseSolveFactor_##X(Factored, _SparseVecAsMat(b), _SparseVecAsMat(x), workspace);                                       \
}                                                                                                                              \
SPARSE_INLINE SparseOpaqueSubfactor_##X SparseCreateSubfactor(SparseSubfactor_t subfactor, SparseOpaqueFactorization_##X Factor) { \
    return _SparseCreateSubfactor_##X(subfactor, Factor);                                                                      \
}                                                                                                                              \
SPARSE_INLINE SparseOpaqueSubfactor_##X SparseRetain(SparseOpaqueSubfactor_##X NumericFactor) {                               \
    _SparseRetainFactor_##X(&NumericFactor.factor); return NumericFactor;                                                      \
}                                                                                                                              \
SPARSE_INLINE void SparseCleanup(SparseOpaqueSubfactor_##X Opaque) { _SparseCleanupFactor_##X(Opaque.factor); }                \
SPARSE_INLINE SparseOpaqueSubfactor_##X SparseGetTranspose(SparseOpaqueSubfactor_##X Subfactor) {                             \
    Subfactor.attributes.transpose = !Subfactor.attributes.transpose; return Subfactor;                                        \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiply(SparseOpaqueSubfactor_##X Subfactor, DenseMatrix_##X XY) {                                   \
    _SparseSubfactorApply_##X(Subfactor, false, XY, XY, NULL);                                                                 \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiply(SparseOpaqueSubfactor_##X Subfactor, DenseMatrix_##X X, DenseMatrix_##X Y) {               \
    _SparseSubfactorApply_##X(Subfactor, false, X, Y, NULL);                                                                   \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiply(SparseOpaqueSubfactor_##X Subfactor, DenseMatrix_##X XY, void *workspace) {                 \
    _SparseSubfactorApply_##X(Subfactor, false, XY, XY, workspace);                                                            \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiply(SparseOpaqueSubfactor_##X Subfactor, DenseMatrix_##X X, DenseMatrix_##X Y, void *workspace) { \
    _SparseSubfactorApply_##X(Subfactor, false, X, Y, workspace);                                                              \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiply(SparseOpaqueSubfactor_##X Subfactor, DenseVector_##X xy) {                                   \
    _SparseSubfactorApply_##X(Subfactor, false, _SparseVecAsMat(xy), _SparseVecAsMat(xy), NULL);                               \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiply(SparseOpaqueSubfactor_##X Subfactor, DenseVector_##X x, DenseVector_##X y) {               \
    _SparseSubfactorApply_##X(Subfactor, false, _SparseVecAsMat(x), _SparseVecAsMat(y), NULL);                                 \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiply(SparseOpaqueSubfactor_##X Subfactor, DenseVector_##X xy, void *workspace) {                 \
    _SparseSubfactorApply_##X(Subfactor, false, _SparseVecAsMat(xy), _SparseVecAsMat(xy), workspace);                          \
}                                                                                                                              \
SPARSE_INLINE void SparseMultiply(SparseOpaqueSubfactor_##X Subfactor, DenseVector_##X x, DenseVector_##X y, void *workspace) { \
    _SparseSubfactorApply_##X(Subfactor, false, _SparseVecAsMat(x), _SparseVecAsMat(y), workspace);                            \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueSubfactor_##X Subfactor, DenseMatrix_##X XB) {                                      \
    _SparseSubfactorApply_##X(Subfactor, true, XB, XB, NULL);                                                                  \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueSubfactor_##X Subfactor, DenseMatrix_##X B, DenseMatrix_##X X) {                  \
    _SparseSubfactorApply_##X(Subfactor, true, B, X, NULL);                                                                    \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueSubfactor_##X Subfactor, DenseMatrix_##X XB, void *workspace) {                    \
    _SparseSubfactorApply_##X(Subfactor, true, XB, XB, workspace);                                                             \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueSubfactor_##X Subfactor, DenseMatrix_##X B, DenseMatrix_##X X, void *workspace) {  \
    _SparseSubfactorApply_##X(Subfactor, true, B, X, workspace);                                                               \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueSubfactor_##X Subfactor, DenseVector_##X xb) {                                      \
    _SparseSubfactorApply_##X(Subfactor, true, _SparseVecAsMat(xb), _SparseVecAsMat(xb), NULL);                                \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueSubfactor_##X Subfactor, DenseVector_##X b, DenseVector_##X x) {                  \
    _SparseSubfactorApply_##X(Subfactor, true, _SparseVecAsMat(b), _SparseVecAsMat(x), NULL);                                  \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueSubfactor_##X Subfactor, DenseVector_##X xb, void *workspace) {                    \
    _SparseSubfactorApply_##X(Subfactor, true, _SparseVecAsMat(xb), _SparseVecAsMat(xb), workspace);                           \
}                                                                                                                              \
SPARSE_INLINE void SparseSolve(SparseOpaqueSubfactor_##X Subfactor, DenseVector_##X b, DenseVector_##X x, void *workspace) {  \
    _SparseSubfactorApply_##X(Subfactor, true, _SparseVecAsMat(b), _SparseVecAsMat(x), workspace);                             \
}                                                                                                                              \
SPARSE_INLINE int SparseGetInertia(SparseOpaqueFactorization_##X Factored, int *zeroEigenvalues, int *negativeEigenvalues,   \
    int *positiveEigenvalues) {                                                                                                \
    return _SparseGetInertia_##X(Factored, zeroEigenvalues, negativeEigenvalues, positiveEigenvalues);                         \
}                                                                                                                              \
SPARSE_INLINE SparseOpaquePreconditioner_##X SparseCreatePreconditioner(SparsePreconditioner_t type, SparseMatrix_##X A) {    \
    return _SparseCreatePreconditioner_##X(type, A);                                                                           \
}                                                                                                                              \
SPARSE_INLINE void SparseCleanup(SparseOpaquePreconditioner_##X Opaque) { _SparseCleanupPreconditioner_##X(Opaque); }         \
SPARSE_INLINE SparseIterativeStatus_t SparseSolve(SparseIterativeMethod method,                                                \
    void (^ApplyOperator)(bool accumulate, enum CBLAS_TRANSPOSE trans, DenseMatrix_##X X, DenseMatrix_##X Y),                  \
    DenseMatrix_##X B, DenseMatrix_##X X) {                                                                                    \
    return _SparseSolveIterative_##X(method, ApplyOperator, B, X, NULL);                                                       \
}                                                                                                                              \
SPARSE_INLINE SparseIterativeStatus_t SparseSolve(SparseIterativeMethod method,                                                \
    void (^ApplyOperator)(bool accumulate, enum CBLAS_TRANSPOSE trans, DenseMatrix_##X X, DenseMatrix_##X Y),                  \
    DenseMatrix_##X B, DenseMatrix_##X X, SparseOpaquePreconditioner_##X Preconditioner) {                                     \
    return _SparseSolveIterative_##X(method, ApplyOperator, B, X, &Preconditioner);                                            \
}                                                                                                                              \
SPARSE_INLINE SparseIterativeStatus_t SparseSolve(SparseIterativeMethod method,                                                \
    void (^ApplyOperator)(bool accumulate, enum CBLAS_TRANSPOSE trans, DenseVector_##X x, DenseVector_##X y),                  \
    DenseVector_##X b, DenseVector_##X x) {                                                                                    \
    return _SparseSolveIterative_##X(method, ^(bool a, enum CBLAS_TRANSPOSE t, DenseMatrix_##X u, DenseMatrix_##X v) {          \
        DenseVector_##X uu = { u.rowCount, u.data }, vv = { v.rowCount, v.data }; ApplyOperator(a, t, uu, vv);                 \
    }, _SparseVecAsMat(b), _SparseVecAsMat(x), NULL);                                                                          \
}                                                                                                                              \
SPARSE_INLINE SparseIterativeStatus_t SparseSolve(SparseIterativeMethod method,                                                \
    void (^ApplyOperator)(bool accumulate, enum CBLAS_TRANSPOSE trans, DenseVector_##X x, DenseVector_##X y),                  \
    DenseVector_##X b, DenseVector_##X x, SparseOpaquePreconditioner_##X Preconditioner) {                                     \
    return _SparseSolveIterative_##X(method, ^(bool a, enum CBLAS_TRANSPOSE t, DenseMatrix_##X u, DenseMatrix_##X v) {          \
        DenseVector_##X uu = { u.rowCount, u.data }, vv = { v.rowCount, v.data }; ApplyOperator(a, t, uu, vv);                 \
    }, _SparseVecAsMat(b), _SparseVecAsMat(x), &Preconditioner);                                                               \
}                                                                                                                              \
SPARSE_INLINE SparseIterativeStatus_t SparseSolve(SparseIterativeMethod method, SparseMatrix_##X A, DenseMatrix_##X B,       \
    DenseMatrix_##X X) {                                                                                                       \
    return _SparseSolveIterative_##X(method, ^(bool a, enum CBLAS_TRANSPOSE t, DenseMatrix_##X u, DenseMatrix_##X v) {          \
        _SparseMultiplyOp_##X(A, t, u, v, a); }, B, X, NULL);                                                                  \
}                                                                                                                              \
SPARSE_INLINE SparseIterativeStatus_t SparseSolve(SparseIterativeMethod method, SparseMatrix_##X A, DenseMatrix_##X B,       \
    DenseMatrix_##X X, SparseOpaquePreconditioner_##X Preconditioner) {                                                        \
    return _SparseSolveIterative_##X(method, ^(bool a, enum CBLAS_TRANSPOSE t, DenseMatrix_##X u, DenseMatrix_##X v) {          \
        _SparseMultiplyOp_##X(A, t, u, v, a); }, B, X, &Preconditioner);                                                       \
}                                                                                                                              \
SPARSE_INLINE SparseIterativeStatus_t SparseSolve(SparseIterativeMethod method, SparseMatrix_##X A, DenseMatrix_##X B,       \
    DenseMatrix_##X X, SparsePreconditioner_t PreconditionerType) {                                                            \
    SparseOpaquePreconditioner_##X P = _SparseCreatePreconditioner_##X(PreconditionerType, A);                                 \
    SparseIterativeStatus_t s = SparseSolve(method, A, B, X, P);                                                               \
    _SparseCleanupPreconditioner_##X(P);                                                                                       \
    return s;                                                                                                                  \
}                                                                                                                              \
SPARSE_INLINE SparseIterativeStatus_t SparseSolve(SparseIterativeMethod method, SparseMatrix_##X A, DenseVector_##X b,       \
    DenseVector_##X x) { return SparseSolve(method, A, _SparseVecAsMat(b), _SparseVecAsMat(x)); }                              \
SPARSE_INLINE SparseIterativeStatus_t SparseSolve(SparseIterativeMethod method, SparseMatrix_##X A, DenseVector_##X b,       \
    DenseVector_##X x, SparseOpaquePreconditioner_##X Preconditioner) {                                                        \
    return SparseSolve(method, A, _SparseVecAsMat(b), _SparseVecAsMat(x), Preconditioner);                                     \
}                                                                                                                              \
SPARSE_INLINE SparseIterativeStatus_t SparseSolve(SparseIterativeMethod method, SparseMatrix_##X A, DenseVector_##X b,       \
    DenseVector_##X x, SparsePreconditioner_t PreconditionerType) {                                                            \
    return SparseSolve(method, A, _SparseVecAsMat(b), _SparseVecAsMat(x), PreconditionerType);                                 \
}                                                                                                                              \
SPARSE_INLINE void SparseIterate(SparseIterativeMethod method, int iteration, const bool *converged, void *state,             \
    void (^ApplyOperator)(bool accumulate, enum CBLAS_TRANSPOSE trans, DenseMatrix_##X X, DenseMatrix_##X Y),                  \
    DenseMatrix_##X B, DenseMatrix_##X R, DenseMatrix_##X X) {                                                                 \
    _SparseIterate_##X(method, iteration, converged, state, ApplyOperator, B, R, X, NULL);                                     \
}                                                                                                                              \
SPARSE_INLINE void SparseIterate(SparseIterativeMethod method, int iteration, const bool *converged, void *state,             \
    void (^ApplyOperator)(bool accumulate, enum CBLAS_TRANSPOSE trans, DenseMatrix_##X X, DenseMatrix_##X Y),                  \
    DenseMatrix_##X B, DenseMatrix_##X R, DenseMatrix_##X X, SparseOpaquePreconditioner_##X Preconditioner) {                  \
    _SparseIterate_##X(method, iteration, converged, state, ApplyOperator, B, R, X, &Preconditioner);                          \
}

#define _SPARSE_ALL(X, T, ATTR, STRUCT) _SPARSE_TYPES(X, T, ATTR, STRUCT) _SPARSE_EXPORTS(X, T, ATTR, STRUCT) _SPARSE_INLINES(X, T, ATTR, STRUCT)
_SPARSE_ALL(Double, double, SparseAttributes_t, SparseMatrixStructure)
_SPARSE_ALL(Float, float, SparseAttributes_t, SparseMatrixStructure)
_SPARSE_ALL(Complex_Double, _Complex double, SparseAttributesComplex_t, SparseMatrixStructureComplex)
_SPARSE_ALL(Complex_Float, _Complex float, SparseAttributesComplex_t, SparseMatrixStructureComplex)


/* a committed Sparse BLAS matrix as a SparseMatrix (issue #819); SparseCleanup frees the copy */
VECLIB_EXTERN SparseMatrix_Double _SparseConvertFromOpaque_Double(sparse_matrix_double A);
VECLIB_EXTERN SparseMatrix_Float _SparseConvertFromOpaque_Float(sparse_matrix_float A);
VECLIB_EXTERN SparseMatrix_Complex_Double _SparseConvertFromOpaque_Complex_Double(sparse_matrix_double_complex A);
VECLIB_EXTERN SparseMatrix_Complex_Float _SparseConvertFromOpaque_Complex_Float(sparse_matrix_float_complex A);
SPARSE_INLINE SparseMatrix_Double SparseConvertFromOpaque(sparse_matrix_double A) { return _SparseConvertFromOpaque_Double(A); }
SPARSE_INLINE SparseMatrix_Float SparseConvertFromOpaque(sparse_matrix_float A) { return _SparseConvertFromOpaque_Float(A); }
SPARSE_INLINE SparseMatrix_Complex_Double SparseConvertFromOpaque(sparse_matrix_double_complex A) { return _SparseConvertFromOpaque_Complex_Double(A); }
SPARSE_INLINE SparseMatrix_Complex_Float SparseConvertFromOpaque(sparse_matrix_float_complex A) { return _SparseConvertFromOpaque_Complex_Float(A); }

/* complex only: conjugate transposes */
#define _SPARSE_CONJ(X)                                                                                                         \
SPARSE_INLINE SparseMatrix_##X SparseGetConjugateTranspose(SparseMatrix_##X Matrix) {                                          \
    Matrix.structure.attributes.conjugate_transpose = !Matrix.structure.attributes.conjugate_transpose; return Matrix;         \
}                                                                                                                              \
SPARSE_INLINE SparseOpaqueFactorization_##X SparseGetConjugateTranspose(SparseOpaqueFactorization_##X Factor) {               \
    Factor.attributes.conjugate_transpose = !Factor.attributes.conjugate_transpose; return Factor;                             \
}                                                                                                                              \
SPARSE_INLINE SparseOpaqueSubfactor_##X SparseGetConjugateTranspose(SparseOpaqueSubfactor_##X Subfactor) {                    \
    Subfactor.attributes.conjugate_transpose = !Subfactor.attributes.conjugate_transpose; return Subfactor;                    \
}
_SPARSE_CONJ(Complex_Double)
_SPARSE_CONJ(Complex_Float)

#undef _SPARSE_ALL
#undef _SPARSE_TYPES
#undef _SPARSE_EXPORTS
#undef _SPARSE_INLINES
#undef _SPARSE_CONJ
#ifdef __cplusplus
}
#endif
#if __has_feature(nullability)
#pragma clang assume_nonnull end
#endif
