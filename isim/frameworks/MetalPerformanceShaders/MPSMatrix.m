/* isim MetalPerformanceShaders: matrices, vectors and the matrix kernels (adapted: on the CPU; products through isim's
   Accelerate BLAS, the decompositions and solvers in double precision) */
#import "mps_internal.h"
#include <Accelerate/Accelerate.h>
#include <float.h>

/* ---------------- descriptors, matrices, vectors ---------------- */
@implementation MPSMatrixDescriptor {
    NSUInteger _matrices, _matrixBytes;
}
+ (instancetype)matrixDescriptorWithDimensions:(NSUInteger)rows columns:(NSUInteger)columns rowBytes:(NSUInteger)rowBytes dataType:(MPSDataType)t {
    return [self matrixDescriptorWithRows:rows columns:columns rowBytes:rowBytes dataType:t];
}
+ (instancetype)matrixDescriptorWithRows:(NSUInteger)rows columns:(NSUInteger)columns rowBytes:(NSUInteger)rowBytes dataType:(MPSDataType)t {
    return [self matrixDescriptorWithRows:rows columns:columns matrices:1 rowBytes:rowBytes matrixBytes:rows * rowBytes dataType:t];
}
+ (instancetype)matrixDescriptorWithRows:(NSUInteger)rows columns:(NSUInteger)columns matrices:(NSUInteger)matrices rowBytes:(NSUInteger)rowBytes
                             matrixBytes:(NSUInteger)matrixBytes dataType:(MPSDataType)t {
    MPSMatrixDescriptor *d = [[self alloc] init];
    d.rows = rows; d.columns = columns; d.rowBytes = rowBytes; d.dataType = t;
    d->_matrices = MAX(matrices, (NSUInteger)1); d->_matrixBytes = matrixBytes;
    return d;
}
+ (size_t)rowBytesFromColumns:(NSUInteger)columns dataType:(MPSDataType)t { return [self rowBytesForColumns:columns dataType:t]; }
+ (size_t)rowBytesForColumns:(NSUInteger)columns dataType:(MPSDataType)t { return columns * mps_type_size(t); }
- (NSUInteger)matrices { return _matrices ?: 1; }
- (NSUInteger)matrixBytes { return _matrixBytes ?: self.rows * self.rowBytes; }
@end

@implementation MPSVectorDescriptor {
    NSUInteger _vectors, _vectorBytes;
}
+ (instancetype)vectorDescriptorWithLength:(NSUInteger)length dataType:(MPSDataType)t {
    return [self vectorDescriptorWithLength:length vectors:1 vectorBytes:length * mps_type_size(t) dataType:t];
}
+ (instancetype)vectorDescriptorWithLength:(NSUInteger)length vectors:(NSUInteger)vectors vectorBytes:(NSUInteger)vectorBytes dataType:(MPSDataType)t {
    MPSVectorDescriptor *d = [[self alloc] init];
    d.length = length; d.dataType = t; d->_vectors = MAX(vectors, (NSUInteger)1); d->_vectorBytes = vectorBytes;
    return d;
}
+ (size_t)vectorBytesForLength:(NSUInteger)length dataType:(MPSDataType)t { return length * mps_type_size(t); }
- (NSUInteger)vectors { return _vectors ?: 1; }
- (NSUInteger)vectorBytes { return _vectorBytes ?: self.length * mps_type_size(self.dataType); }
@end

@implementation MPSMatrix {
    MPSMatrixDescriptor *_d;
}
@synthesize data = _data, offset = _offset;
- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer descriptor:(MPSMatrixDescriptor *)d { return [self initWithBuffer:buffer offset:0 descriptor:d]; }
- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset descriptor:(MPSMatrixDescriptor *)d {
    if ((self = [super init])) {
        _data = buffer; _offset = offset;
        _d = [MPSMatrixDescriptor matrixDescriptorWithRows:d.rows columns:d.columns matrices:d.matrices rowBytes:d.rowBytes matrixBytes:d.matrixBytes dataType:d.dataType];
    }
    return self;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device descriptor:(MPSMatrixDescriptor *)d {
    return [self initWithBuffer:[device newBufferWithLength:MAX(d.matrixBytes * d.matrices, (NSUInteger)1) options:MTLResourceStorageModeShared] offset:0 descriptor:d];
}
- (id<MTLDevice>)device { return _data.device; }
- (NSUInteger)rows { return _d.rows; }
- (NSUInteger)columns { return _d.columns; }
- (NSUInteger)matrices { return _d.matrices; }
- (MPSDataType)dataType { return _d.dataType; }
- (NSUInteger)rowBytes { return _d.rowBytes; }
- (NSUInteger)matrixBytes { return _d.matrixBytes; }
- (void)synchronizeOnCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {}
- (NSUInteger)resourceSize { return _d.matrixBytes * _d.matrices; }
@end

@implementation MPSVector {
    MPSVectorDescriptor *_d;
}
@synthesize data = _data, offset = _offset;
- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer descriptor:(MPSVectorDescriptor *)d { return [self initWithBuffer:buffer offset:0 descriptor:d]; }
- (instancetype)initWithBuffer:(id<MTLBuffer>)buffer offset:(NSUInteger)offset descriptor:(MPSVectorDescriptor *)d {
    if ((self = [super init])) { _data = buffer; _offset = offset; _d = [MPSVectorDescriptor vectorDescriptorWithLength:d.length vectors:d.vectors vectorBytes:d.vectorBytes dataType:d.dataType]; }
    return self;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device descriptor:(MPSVectorDescriptor *)d {
    return [self initWithBuffer:[device newBufferWithLength:MAX(d.vectorBytes * d.vectors, (NSUInteger)1) options:MTLResourceStorageModeShared] offset:0 descriptor:d];
}
- (id<MTLDevice>)device { return _data.device; }
- (NSUInteger)length { return _d.length; }
- (NSUInteger)vectors { return _d.vectors; }
- (MPSDataType)dataType { return _d.dataType; }
- (NSUInteger)vectorBytes { return _d.vectorBytes; }
- (void)synchronizeOnCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {}
- (NSUInteger)resourceSize { return _d.vectorBytes * _d.vectors; }
@end

@implementation MPSTemporaryMatrix
+ (instancetype)temporaryMatrixWithCommandBuffer:(id<MTLCommandBuffer>)cb matrixDescriptor:(MPSMatrixDescriptor *)d {
    MPSTemporaryMatrix *m = [[self alloc] initWithDevice:cb.device descriptor:d];
    m.readCount = 1;
    return m;
}
+ (void)prefetchStorageWithCommandBuffer:(id<MTLCommandBuffer>)cb matrixDescriptorList:(NSArray<MPSMatrixDescriptor *> *)list {}
@end
@implementation MPSTemporaryVector
+ (instancetype)temporaryVectorWithCommandBuffer:(id<MTLCommandBuffer>)cb descriptor:(MPSVectorDescriptor *)d {
    MPSTemporaryVector *v = [[self alloc] initWithDevice:cb.device descriptor:d];
    v.readCount = 1;
    return v;
}
+ (void)prefetchStorageWithCommandBuffer:(id<MTLCommandBuffer>)cb descriptorList:(NSArray<MPSVectorDescriptor *> *)list {}
@end

/* ---------------- elements ---------------- */
static uint8_t *mat_row(MPSMatrix *m, NSUInteger b, NSUInteger r) { return (uint8_t *)m.data.contents + m.offset + b * m.matrixBytes + r * m.rowBytes; }
static double mget(MPSMatrix *m, NSUInteger b, NSUInteger r, NSUInteger c) { return mps_load(m.dataType, mat_row(m, b, r), c); }
static void mset(MPSMatrix *m, NSUInteger b, NSUInteger r, NSUInteger c, double v) { mps_store(m.dataType, mat_row(m, b, r), c, v); }
static uint8_t *vec_base(MPSVector *v, NSUInteger i) { return (uint8_t *)v.data.contents + v.offset + i * v.vectorBytes; }
static double vget(MPSVector *v, NSUInteger b, NSUInteger i) { return mps_load(v.dataType, vec_base(v, b), i); }
static void vset(MPSVector *v, NSUInteger b, NSUInteger i, double x) { mps_store(v.dataType, vec_base(v, b), i, x); }
static NSUInteger batch_count(NSUInteger start, NSUInteger size, NSUInteger available) {
    if (start >= available) return 0;
    return MIN(size ? size : available - start, available - start);
}

/* ---------------- neurons ---------------- */
static double neuron(MPSCNNNeuronType t, double a, double b, double c, double x, const float *prelu, NSUInteger ch, NSUInteger np) {
    switch (t) {
    case MPSCNNNeuronTypeReLU: return x >= 0 ? x : a * x;
    case MPSCNNNeuronTypeLinear: return a * x + b;
    case MPSCNNNeuronTypeSigmoid: return 1 / (1 + exp(-x));
    case MPSCNNNeuronTypeHardSigmoid: return fmin(fmax(a * x + b, 0), 1);
    case MPSCNNNeuronTypeTanH: return a * tanh(b * x);
    case MPSCNNNeuronTypeAbsolute: return fabs(x);
    case MPSCNNNeuronTypeSoftPlus: return a * log1p(exp(b * x));
    case MPSCNNNeuronTypeSoftSign: return x / (1 + fabs(x));
    case MPSCNNNeuronTypeELU: return x >= 0 ? x : a * (exp(x) - 1);
    case MPSCNNNeuronTypePReLU: return x >= 0 ? x : (np ? prelu[ch % np] : a) * x;
    case MPSCNNNeuronTypeReLUN: return fmin(x >= 0 ? x : a * x, b);
    case MPSCNNNeuronTypePower: return pow(a * x + b, c);
    case MPSCNNNeuronTypeExponential: return c < 0 ? exp(a * x + b) : pow(c, a * x + b);
    case MPSCNNNeuronTypeLogarithm: return c < 0 ? log(a * x + b) : log(a * x + b) / log(c);
    case MPSCNNNeuronTypeGeLU: return 0.5 * x * (1 + erf(x / sqrt(2)));
    default: return x;
    }
}

/* ---------------- kernel bases ---------------- */
@implementation MPSMatrixUnaryKernel
@end
@implementation MPSMatrixBinaryKernel
@end

/* ---------------- products ---------------- */
@implementation MPSMatrixMultiplication {
    BOOL _tl, _tr; NSUInteger _m, _n, _k; double _alpha, _beta;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device transposeLeft:(BOOL)tl transposeRight:(BOOL)tr resultRows:(NSUInteger)m resultColumns:(NSUInteger)n
               interiorColumns:(NSUInteger)k alpha:(double)alpha beta:(double)beta {
    if ((self = [super initWithDevice:device])) { _tl = tl; _tr = tr; _m = m; _n = n; _k = k; _alpha = alpha; _beta = beta; }
    return self;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device resultRows:(NSUInteger)m resultColumns:(NSUInteger)n interiorColumns:(NSUInteger)k {
    return [self initWithDevice:device transposeLeft:NO transposeRight:NO resultRows:m resultColumns:n interiorColumns:k alpha:1 beta:0];
}
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb leftMatrix:(MPSMatrix *)A rightMatrix:(MPSMatrix *)B resultMatrix:(MPSMatrix *)C {
    MTLOrigin oa = _leftMatrixOrigin, ob = _rightMatrixOrigin, oc = _resultMatrixOrigin;
    NSUInteger bs = _batchStart, bn = _batchSize;
    mps_enqueue(cb, ^{
        NSUInteger M = MIN(self->_m, C.rows - MIN(oc.y, C.rows)), N = MIN(self->_n, C.columns - MIN(oc.x, C.columns)), K = self->_k;
        NSUInteger batches = batch_count(bs, bn, MIN(MIN(A.matrices, B.matrices), C.matrices));
        if (!M || !N) return;
        float *a = malloc(sizeof(float) * M * MAX(K, (NSUInteger)1)), *b = malloc(sizeof(float) * MAX(K, (NSUInteger)1) * N), *c = malloc(sizeof(float) * M * N);
        for (NSUInteger t = bs; t < bs + batches; t++) {
            for (NSUInteger i = 0; i < M; i++)
                for (NSUInteger k = 0; k < K; k++)
                    a[i * K + k] = (float)(self->_tl ? mget(A, t + oa.z, oa.y + k, oa.x + i) : mget(A, t + oa.z, oa.y + i, oa.x + k));
            for (NSUInteger k = 0; k < K; k++)
                for (NSUInteger j = 0; j < N; j++)
                    b[k * N + j] = (float)(self->_tr ? mget(B, t + ob.z, ob.y + j, ob.x + k) : mget(B, t + ob.z, ob.y + k, ob.x + j));
            for (NSUInteger i = 0; i < M; i++)
                for (NSUInteger j = 0; j < N; j++) c[i * N + j] = self->_beta != 0 ? (float)mget(C, t + oc.z, oc.y + i, oc.x + j) : 0;
            cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, (int)M, (int)N, (int)K, (float)self->_alpha, a, (int)MAX(K, (NSUInteger)1), b, (int)N,
                        (float)self->_beta, c, (int)N);
            for (NSUInteger i = 0; i < M; i++)
                for (NSUInteger j = 0; j < N; j++) mset(C, t + oc.z, oc.y + i, oc.x + j, c[i * N + j]);
        }
        free(a); free(b); free(c);
    });
}
@end

@implementation MPSMatrixVectorMultiplication {
    BOOL _t; NSUInteger _rows, _cols; double _alpha, _beta;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device transpose:(BOOL)t rows:(NSUInteger)rows columns:(NSUInteger)cols alpha:(double)alpha beta:(double)beta {
    if ((self = [super initWithDevice:device])) { _t = t; _rows = rows; _cols = cols; _alpha = alpha; _beta = beta; }
    return self;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device rows:(NSUInteger)rows columns:(NSUInteger)cols {
    return [self initWithDevice:device transpose:NO rows:rows columns:cols alpha:1 beta:0];
}
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb inputMatrix:(MPSMatrix *)A inputVector:(MPSVector *)x resultVector:(MPSVector *)y {
    MTLOrigin oa = self.primarySourceMatrixOrigin;
    NSUInteger bs = self.batchStart, bn = self.batchSize;
    mps_enqueue(cb, ^{
        NSUInteger batches = batch_count(bs, bn, MIN(MIN(A.matrices, x.vectors), y.vectors));
        NSUInteger outN = self->_rows, inN = self->_cols;   /* rows / columns of op(A) */
        for (NSUInteger t = bs; t < bs + batches; t++)
            for (NSUInteger i = 0; i < outN; i++) {
                double s = 0;
                for (NSUInteger k = 0; k < inN; k++)
                    s += (self->_t ? mget(A, t + oa.z, oa.y + k, oa.x + i) : mget(A, t + oa.z, oa.y + i, oa.x + k)) * vget(x, t, k);
                vset(y, t, i, self->_alpha * s + (self->_beta != 0 ? self->_beta * vget(y, t, i) : 0));
            }
    });
}
@end

@implementation MPSMatrixSum {
    MPSCNNNeuronType _nt; float _na, _nb, _nc;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device count:(NSUInteger)count rows:(NSUInteger)rows columns:(NSUInteger)columns transpose:(BOOL)transpose {
    if ((self = [super initWithDevice:device])) { _count = count; _rows = rows; _columns = columns; _transpose = transpose; _na = 1; }
    return self;
}
- (void)setNeuronType:(MPSCNNNeuronType)t parameterA:(float)a parameterB:(float)b parameterC:(float)c { _nt = t; _na = a; _nb = b; _nc = c; }
- (MPSCNNNeuronType)neuronType { return _nt; }
- (float)neuronParameterA { return _na; }
- (float)neuronParameterB { return _nb; }
- (float)neuronParameterC { return _nc; }
/* result = neuron(sum_i scale[i] * source_i + bias[column]); the offset vector (uint32) shifts each source's batch */
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb sourceMatrices:(NSArray<MPSMatrix *> *)sources resultMatrix:(MPSMatrix *)R
                  scaleVector:(MPSVector *)scale offsetVector:(MPSVector *)offsets biasVector:(MPSVector *)bias startIndex:(NSUInteger)start {
    MTLOrigin oc = _resultMatrixOrigin;
    mps_enqueue(cb, ^{
        NSUInteger n = MIN(self->_count, sources.count);
        for (NSUInteger i = 0; i < self->_rows; i++)
            for (NSUInteger j = 0; j < self->_columns; j++) {
                double s = 0;
                for (NSUInteger k = 0; k < n; k++) {
                    NSUInteger b = start + (offsets ? (NSUInteger)vget(offsets, 0, k) : 0);
                    double v = self->_transpose ? mget(sources[k], b, j, i) : mget(sources[k], b, i, j);
                    s += (scale ? vget(scale, 0, k) : 1) * v;
                }
                if (bias) s += vget(bias, 0, j);
                mset(R, oc.z, oc.y + i, oc.x + j, neuron(self->_nt, self->_na, self->_nb, self->_nc, s, NULL, 0, 0));
            }
    });
}
@end

/* ---------------- row kernels ---------------- */
@implementation MPSMatrixSoftMax
- (instancetype)initWithDevice:(id<MTLDevice>)device {
    if ((self = [super initWithDevice:device])) { _sourceRows = NSUIntegerMax; _sourceColumns = NSUIntegerMax; }
    return self;
}
- (BOOL)_isim_log { return NO; }
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb inputMatrix:(MPSMatrix *)A resultMatrix:(MPSMatrix *)R {
    MTLOrigin oa = self.sourceMatrixOrigin, oc = self.resultMatrixOrigin;
    NSUInteger bs = self.batchStart, bn = self.batchSize, sr = _sourceRows, sc = _sourceColumns;
    BOOL lg = [self _isim_log];
    mps_enqueue(cb, ^{
        NSUInteger rows = MIN(sr, A.rows - MIN(oa.y, A.rows)), cols = MIN(sc, A.columns - MIN(oa.x, A.columns));
        NSUInteger batches = batch_count(bs, bn, MIN(A.matrices, R.matrices));
        for (NSUInteger t = bs; t < bs + batches; t++)
            for (NSUInteger i = 0; i < rows; i++) {
                double mx = -DBL_MAX, sum = 0;
                for (NSUInteger j = 0; j < cols; j++) mx = fmax(mx, mget(A, t + oa.z, oa.y + i, oa.x + j));
                for (NSUInteger j = 0; j < cols; j++) sum += exp(mget(A, t + oa.z, oa.y + i, oa.x + j) - mx);
                for (NSUInteger j = 0; j < cols; j++) {
                    double x = mget(A, t + oa.z, oa.y + i, oa.x + j) - mx;
                    mset(R, t + oc.z, oc.y + i, oc.x + j, lg ? x - log(sum) : exp(x) / sum);
                }
            }
    });
}
@end
@implementation MPSMatrixLogSoftMax
- (BOOL)_isim_log { return YES; }
@end

@implementation MPSMatrixFindTopK
- (instancetype)initWithDevice:(id<MTLDevice>)device numberOfTopKValues:(NSUInteger)k {
    if ((self = [super initWithDevice:device])) { _numberOfTopKValues = MIN(k, (NSUInteger)16); _sourceRows = NSUIntegerMax; _sourceColumns = NSUIntegerMax; }
    return self;
}
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb inputMatrix:(MPSMatrix *)A resultIndexMatrix:(MPSMatrix *)I resultValueMatrix:(MPSMatrix *)V {
    MTLOrigin oa = self.sourceMatrixOrigin, oc = self.resultMatrixOrigin;
    NSUInteger bs = self.batchStart, bn = self.batchSize, sr = _sourceRows, sc = _sourceColumns, K = _numberOfTopKValues, io = _indexOffset;
    mps_enqueue(cb, ^{
        NSUInteger rows = MIN(sr, A.rows - MIN(oa.y, A.rows)), cols = MIN(sc, A.columns - MIN(oa.x, A.columns));
        NSUInteger batches = batch_count(bs, bn, MIN(MIN(A.matrices, I.matrices), V.matrices)), k = MIN(K, cols);
        double val[16]; NSUInteger idx[16];
        for (NSUInteger t = bs; t < bs + batches; t++)
            for (NSUInteger i = 0; i < rows; i++) {
                NSUInteger n = 0;
                for (NSUInteger j = 0; j < cols; j++) {             /* insertion into the sorted top k */
                    double v = mget(A, t + oa.z, oa.y + i, oa.x + j);
                    if (n == k && v <= val[k - 1]) continue;
                    NSUInteger p = n < k ? n++ : k - 1;
                    while (p > 0 && val[p - 1] < v) { val[p] = val[p - 1]; idx[p] = idx[p - 1]; p--; }
                    val[p] = v; idx[p] = j;
                }
                for (NSUInteger j = 0; j < n; j++) {
                    mset(V, t + oc.z, oc.y + i, oc.x + j, val[j]);
                    mps_store(MPSDataTypeUInt32, mat_row(I, t + oc.z, oc.y + i), oc.x + j, (double)(idx[j] + io));
                }
            }
    });
}
@end

@implementation MPSMatrixNeuron {
    MPSCNNNeuronType _nt; float _na, _nb, _nc; NSData *_prelu;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device {
    if ((self = [super initWithDevice:device])) { _alpha = 1; _na = 1; _sourceNumberOfFeatureVectors = NSUIntegerMax; _sourceInputFeatureChannels = NSUIntegerMax; }
    return self;
}
- (void)setNeuronType:(MPSCNNNeuronType)t parameterA:(float)a parameterB:(float)b parameterC:(float)c { _nt = t; _na = a; _nb = b; _nc = c; }
- (MPSCNNNeuronType)neuronType { return _nt; }
- (float)neuronParameterA { return _na; }
- (float)neuronParameterB { return _nb; }
- (float)neuronParameterC { return _nc; }
- (void)setNeuronToPReLUWithParametersA:(NSData *)A { _nt = MPSCNNNeuronTypePReLU; _prelu = [A copy]; }
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb inputMatrix:(MPSMatrix *)A biasVector:(MPSVector *)bias resultMatrix:(MPSMatrix *)R {
    MTLOrigin oa = self.sourceMatrixOrigin, oc = self.resultMatrixOrigin;
    NSUInteger bs = self.batchStart, bn = self.batchSize, rowsMax = _sourceNumberOfFeatureVectors, colsMax = _sourceInputFeatureChannels;
    mps_enqueue(cb, ^{
        NSUInteger rows = MIN(rowsMax, A.rows - MIN(oa.y, A.rows)), cols = MIN(colsMax, A.columns - MIN(oa.x, A.columns));
        NSUInteger batches = batch_count(bs, bn, MIN(A.matrices, R.matrices)), np = self->_prelu.length / sizeof(float);
        for (NSUInteger t = bs; t < bs + batches; t++)
            for (NSUInteger i = 0; i < rows; i++)
                for (NSUInteger j = 0; j < cols; j++) {
                    double x = self->_alpha * mget(A, t + oa.z, oa.y + i, oa.x + j) + (bias ? vget(bias, 0, j) : 0);
                    mset(R, t + oc.z, oc.y + i, oc.x + j, neuron(self->_nt, self->_na, self->_nb, self->_nc, x, self->_prelu.bytes, j, np));
                }
    });
}
@end

/* ---------------- decompositions and solvers ---------------- */
static void put_status(id<MTLBuffer> status, MPSMatrixDecompositionStatus s) { if (status) *(int32_t *)status.contents = s; }
/* a dense double copy of rows x cols of a matrix from an origin */
static double *dense(MPSMatrix *m, NSUInteger b, MTLOrigin o, NSUInteger rows, NSUInteger cols) {
    double *a = malloc(sizeof(double) * MAX(rows * cols, (NSUInteger)1));
    for (NSUInteger i = 0; i < rows; i++) for (NSUInteger j = 0; j < cols; j++) a[i * cols + j] = mget(m, b + o.z, o.y + i, o.x + j);
    return a;
}
static void store_dense(MPSMatrix *m, NSUInteger b, MTLOrigin o, const double *a, NSUInteger rows, NSUInteger cols) {
    for (NSUInteger i = 0; i < rows; i++) for (NSUInteger j = 0; j < cols; j++) mset(m, b + o.z, o.y + i, o.x + j, a[i * cols + j]);
}

@implementation MPSMatrixDecompositionLU {
    NSUInteger _rows, _cols;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device rows:(NSUInteger)rows columns:(NSUInteger)cols {
    if ((self = [super initWithDevice:device])) { _rows = rows; _cols = cols; }
    return self;
}
/* P * A = L * U, Doolittle with partial pivoting: L (unit, below the diagonal) and U share the result; pivot i is the
   row exchanged with row i */
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb sourceMatrix:(MPSMatrix *)A resultMatrix:(MPSMatrix *)R pivotIndices:(MPSMatrix *)P
                       status:(id<MTLBuffer>)status {
    MTLOrigin oa = self.sourceMatrixOrigin, oc = self.resultMatrixOrigin;
    NSUInteger bs = self.batchStart;
    mps_enqueue(cb, ^{
        NSUInteger m = self->_rows, n = self->_cols, k = MIN(m, n);
        double *a = dense(A, bs, oa, m, n);
        MPSMatrixDecompositionStatus st = MPSMatrixDecompositionStatusSuccess;
        for (NSUInteger j = 0; j < k; j++) {
            NSUInteger p = j;
            for (NSUInteger i = j + 1; i < m; i++) if (fabs(a[i * n + j]) > fabs(a[p * n + j])) p = i;
            mps_store(MPSDataTypeUInt32, mat_row(P, bs, 0), j, (double)p);
            if (p != j) for (NSUInteger c = 0; c < n; c++) { double t = a[j * n + c]; a[j * n + c] = a[p * n + c]; a[p * n + c] = t; }
            if (a[j * n + j] == 0) { st = MPSMatrixDecompositionStatusSingular; continue; }
            for (NSUInteger i = j + 1; i < m; i++) {
                double f = a[i * n + j] /= a[j * n + j];
                for (NSUInteger c = j + 1; c < n; c++) a[i * n + c] -= f * a[j * n + c];
            }
        }
        store_dense(R, bs, oc, a, m, n);
        put_status(status, st);
        free(a);
    });
}
@end

@implementation MPSMatrixDecompositionCholesky {
    BOOL _lower; NSUInteger _order;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device lower:(BOOL)lower order:(NSUInteger)order {
    if ((self = [super initWithDevice:device])) { _lower = lower; _order = order; }
    return self;
}
/* A = L * L^T (the lower triangle written) or U^T * U (the upper) */
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb sourceMatrix:(MPSMatrix *)A resultMatrix:(MPSMatrix *)R status:(id<MTLBuffer>)status {
    MTLOrigin oa = self.sourceMatrixOrigin, oc = self.resultMatrixOrigin;
    NSUInteger bs = self.batchStart;
    mps_enqueue(cb, ^{
        NSUInteger n = self->_order;
        double *a = dense(A, bs, oa, n, n), *l = calloc(n * n + 1, sizeof(double));
        MPSMatrixDecompositionStatus st = MPSMatrixDecompositionStatusSuccess;
        for (NSUInteger j = 0; j < n && st == MPSMatrixDecompositionStatusSuccess; j++) {
            double d = a[j * n + j];
            for (NSUInteger k = 0; k < j; k++) d -= l[j * n + k] * l[j * n + k];
            if (d <= 0) { st = MPSMatrixDecompositionStatusNonPositiveDefinite; break; }
            l[j * n + j] = sqrt(d);
            for (NSUInteger i = j + 1; i < n; i++) {
                double s = a[i * n + j];
                for (NSUInteger k = 0; k < j; k++) s -= l[i * n + k] * l[j * n + k];
                l[i * n + j] = s / l[j * n + j];
            }
        }
        for (NSUInteger i = 0; i < n; i++)
            for (NSUInteger j = 0; j <= i; j++) {
                if (self->_lower) mset(R, bs + oc.z, oc.y + i, oc.x + j, l[i * n + j]);
                else mset(R, bs + oc.z, oc.y + j, oc.x + i, l[i * n + j]);
            }
        put_status(status, st);
        free(a); free(l);
    });
}
@end

/* solves T * X = B in place (T n x n triangular, B n x r) */
static void tri_solve(const double *t, BOOL upper, BOOL unit, double *b, NSUInteger n, NSUInteger r) {
    for (NSUInteger c = 0; c < r; c++) {
        if (!upper)
            for (NSUInteger i = 0; i < n; i++) {
                double s = b[i * r + c];
                for (NSUInteger k = 0; k < i; k++) s -= t[i * n + k] * b[k * r + c];
                b[i * r + c] = unit ? s : s / t[i * n + i];
            }
        else
            for (NSUInteger i = n; i-- > 0;) {
                double s = b[i * r + c];
                for (NSUInteger k = i + 1; k < n; k++) s -= t[i * n + k] * b[k * r + c];
                b[i * r + c] = unit ? s : s / t[i * n + i];
            }
    }
}
static double *transposed(const double *a, NSUInteger rows, NSUInteger cols) {
    double *t = malloc(sizeof(double) * MAX(rows * cols, (NSUInteger)1));
    for (NSUInteger i = 0; i < rows; i++) for (NSUInteger j = 0; j < cols; j++) t[j * rows + i] = a[i * cols + j];
    return t;
}

@implementation MPSMatrixSolveTriangular {
    BOOL _right, _upper, _transpose, _unit; NSUInteger _order, _nrhs; double _alpha;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device right:(BOOL)right upper:(BOOL)upper transpose:(BOOL)transpose unit:(BOOL)unit order:(NSUInteger)order
        numberOfRightHandSides:(NSUInteger)nrhs alpha:(double)alpha {
    if ((self = [super initWithDevice:device])) { _right = right; _upper = upper; _transpose = transpose; _unit = unit; _order = order; _nrhs = nrhs; _alpha = alpha; }
    return self;
}
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb sourceMatrix:(MPSMatrix *)A rightHandSideMatrix:(MPSMatrix *)B solutionMatrix:(MPSMatrix *)X {
    MTLOrigin oa = self.primarySourceMatrixOrigin, ob = self.secondarySourceMatrixOrigin, ox = self.resultMatrixOrigin;
    NSUInteger bs = self.batchStart;
    mps_enqueue(cb, ^{
        NSUInteger n = self->_order, r = self->_nrhs;
        double *a = dense(A, bs, oa, n, n);
        /* the triangle in use: op(A), upper or lower */
        double *t = calloc(n * n + 1, sizeof(double));
        for (NSUInteger i = 0; i < n; i++)
            for (NSUInteger j = 0; j < n; j++) if (self->_upper ? j >= i : j <= i) t[i * n + j] = a[i * n + j];
        BOOL upper = self->_upper;
        if (self->_transpose) { double *tt = transposed(t, n, n); free(t); t = tt; upper = !upper; }
        if (!self->_right) {                       /* op(A) X = alpha B */
            double *b = dense(B, bs, ob, n, r);
            for (NSUInteger i = 0; i < n * r; i++) b[i] *= self->_alpha;
            tri_solve(t, upper, self->_unit, b, n, r);
            store_dense(X, bs, ox, b, n, r);
            free(b);
        } else {                                    /* X op(A) = alpha B  <=>  op(A)^T X^T = alpha B^T */
            double *b = dense(B, bs, ob, r, n), *bt = transposed(b, r, n), *tt = transposed(t, n, n);
            for (NSUInteger i = 0; i < n * r; i++) bt[i] *= self->_alpha;
            tri_solve(tt, !upper, self->_unit, bt, n, r);
            double *x = transposed(bt, n, r);
            store_dense(X, bs, ox, x, r, n);
            free(b); free(bt); free(tt); free(x);
        }
        free(a); free(t);
    });
}
@end

@implementation MPSMatrixSolveLU {
    BOOL _transpose; NSUInteger _order, _nrhs;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device transpose:(BOOL)transpose order:(NSUInteger)order numberOfRightHandSides:(NSUInteger)nrhs {
    if ((self = [super initWithDevice:device])) { _transpose = transpose; _order = order; _nrhs = nrhs; }
    return self;
}
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb sourceMatrix:(MPSMatrix *)A rightHandSideMatrix:(MPSMatrix *)B pivotIndices:(MPSMatrix *)P
               solutionMatrix:(MPSMatrix *)X {
    MTLOrigin oa = self.primarySourceMatrixOrigin, ob = self.secondarySourceMatrixOrigin, ox = self.resultMatrixOrigin;
    NSUInteger bs = self.batchStart;
    mps_enqueue(cb, ^{
        NSUInteger n = self->_order, r = self->_nrhs;
        double *lu = dense(A, bs, oa, n, n), *b = dense(B, bs, ob, n, r);
        double *l = calloc(n * n + 1, sizeof(double)), *u = calloc(n * n + 1, sizeof(double));
        for (NSUInteger i = 0; i < n; i++)
            for (NSUInteger j = 0; j < n; j++) { if (j < i) l[i * n + j] = lu[i * n + j]; else u[i * n + j] = lu[i * n + j]; }
        NSUInteger *piv = malloc(sizeof(NSUInteger) * MAX(n, (NSUInteger)1));
        for (NSUInteger i = 0; i < n; i++) piv[i] = (NSUInteger)mps_load(MPSDataTypeUInt32, mat_row(P, bs, 0), i);
        if (!self->_transpose) {                  /* P A = L U: x = U^-1 L^-1 P b */
            for (NSUInteger i = 0; i < n; i++) if (piv[i] != i && piv[i] < n)
                for (NSUInteger c = 0; c < r; c++) { double t = b[i * r + c]; b[i * r + c] = b[piv[i] * r + c]; b[piv[i] * r + c] = t; }
            tri_solve(l, NO, YES, b, n, r);
            tri_solve(u, YES, NO, b, n, r);
        } else {                                   /* A^T x = b: U^T L^T P x = b */
            double *ut = transposed(u, n, n), *lt = transposed(l, n, n);
            tri_solve(ut, NO, NO, b, n, r);
            tri_solve(lt, YES, YES, b, n, r);
            for (NSUInteger i = n; i-- > 0;) if (piv[i] != i && piv[i] < n)
                for (NSUInteger c = 0; c < r; c++) { double t = b[i * r + c]; b[i * r + c] = b[piv[i] * r + c]; b[piv[i] * r + c] = t; }
            free(ut); free(lt);
        }
        store_dense(X, bs, ox, b, n, r);
        free(lu); free(b); free(l); free(u); free(piv);
    });
}
@end

@implementation MPSMatrixSolveCholesky {
    BOOL _upper; NSUInteger _order, _nrhs;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device upper:(BOOL)upper order:(NSUInteger)order numberOfRightHandSides:(NSUInteger)nrhs {
    if ((self = [super initWithDevice:device])) { _upper = upper; _order = order; _nrhs = nrhs; }
    return self;
}
- (void)encodeToCommandBuffer:(id<MTLCommandBuffer>)cb sourceMatrix:(MPSMatrix *)A rightHandSideMatrix:(MPSMatrix *)B solutionMatrix:(MPSMatrix *)X {
    MTLOrigin oa = self.primarySourceMatrixOrigin, ob = self.secondarySourceMatrixOrigin, ox = self.resultMatrixOrigin;
    NSUInteger bs = self.batchStart;
    mps_enqueue(cb, ^{
        NSUInteger n = self->_order, r = self->_nrhs;
        double *f = dense(A, bs, oa, n, n), *b = dense(B, bs, ob, n, r), *l = calloc(n * n + 1, sizeof(double));
        for (NSUInteger i = 0; i < n; i++)            /* the lower factor L (from U: L = U^T) */
            for (NSUInteger j = 0; j <= i; j++) l[i * n + j] = self->_upper ? f[j * n + i] : f[i * n + j];
        double *lt = transposed(l, n, n);
        tri_solve(l, NO, NO, b, n, r);
        tri_solve(lt, YES, NO, b, n, r);
        store_dense(X, bs, ox, b, n, r);
        free(f); free(b); free(l); free(lt);
    });
}
@end
