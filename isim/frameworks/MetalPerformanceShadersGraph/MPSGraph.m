/* isim MetalPerformanceShadersGraph: graphs, tensors, tensor data, running (adapted: evaluated on the CPU in double
   precision), compiled executables, variables and gradients */
#import "mg_internal.h"

/* ---------------- values ---------------- */
@implementation MGValue
+ (instancetype)valueWithDims:(const NSUInteger *)dims rank:(NSUInteger)rank {
    MGValue *v = [self new];
    v->rank = MIN(rank, (NSUInteger)MG_MAX_RANK);
    v->n = 1;
    for (NSUInteger i = 0; i < v->rank; i++) { v->dims[i] = dims[i]; v->n *= dims[i]; }
    v->d = calloc(v->n + 1, sizeof(double));
    return v;
}
+ (instancetype)valueLike:(MGValue *)o { return [self valueWithDims:o->dims rank:o->rank]; }
+ (instancetype)scalar:(double)x { MGValue *v = [self valueWithDims:NULL rank:0]; v->d[0] = x; return v; }
- (void)dealloc { free(d); }
- (MPSShape *)shape {
    NSMutableArray *s = [NSMutableArray array];
    for (NSUInteger i = 0; i < rank; i++) [s addObject:@(dims[i])];
    return s;
}
@end
MGValue *mg_value_of_shape(MPSShape *shape) {
    NSUInteger dims[MG_MAX_RANK], r = MIN(shape.count, (NSUInteger)MG_MAX_RANK);
    for (NSUInteger i = 0; i < r; i++) dims[i] = (NSUInteger)MAX(shape[i].integerValue, 0);
    return [MGValue valueWithDims:dims rank:r];
}

@implementation MGRun
@end
double mg_random(MGRun *run) {
    uint64_t x = run.rng ?: 0x9e3779b97f4a7c15ULL;
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;
    run.rng = x;
    return (double)(x >> 11) / 9007199254740992.0;
}

/* ---------------- data types and shapes ---------------- */
BOOL mg_is_float(MPSDataType t) { return (t & MPSDataTypeFloatBit) != 0 || t == MPSDataTypeBFloat16; }
size_t mg_type_size(MPSDataType t) { return t == MPSDataTypeBool ? 1 : MAX((size_t)((t & 0xffff) / 8), (size_t)1); }
double mg_norm(MPSDataType t, double v) {
    if (t == MPSDataTypeBool) return v != 0;
    if (mg_is_float(t)) return t == MPSDataTypeFloat32 ? (double)(float)v : t == MPSDataTypeFloat16 ? (double)(_Float16)v : v;
    return isfinite(v) ? trunc(v) : 0;
}
double mg_load(MPSDataType t, const void *p, NSUInteger i) {
    switch ((uint32_t)t) {
    case MPSDataTypeFloat32: return ((const float *)p)[i];
    case MPSDataTypeFloat16: return (double)((const _Float16 *)p)[i];
    case MPSDataTypeBFloat16: { uint32_t b = (uint32_t)((const uint16_t *)p)[i] << 16; float f; memcpy(&f, &b, 4); return f; }
    case MPSDataTypeInt8: return ((const int8_t *)p)[i];
    case MPSDataTypeInt16: return ((const int16_t *)p)[i];
    case MPSDataTypeInt32: return ((const int32_t *)p)[i];
    case MPSDataTypeInt64: return (double)((const int64_t *)p)[i];
    case MPSDataTypeUInt8: return ((const uint8_t *)p)[i];
    case MPSDataTypeUInt16: return ((const uint16_t *)p)[i];
    case MPSDataTypeUInt32: return ((const uint32_t *)p)[i];
    case MPSDataTypeUInt64: return (double)((const uint64_t *)p)[i];
    case MPSDataTypeBool: return ((const uint8_t *)p)[i] != 0;
    default: return 0;
    }
}
void mg_store(MPSDataType t, void *p, NSUInteger i, double v) {
    switch ((uint32_t)t) {
    case MPSDataTypeFloat32: ((float *)p)[i] = (float)v; break;
    case MPSDataTypeFloat16: ((_Float16 *)p)[i] = (_Float16)v; break;
    case MPSDataTypeBFloat16: { float f = (float)v; uint32_t b; memcpy(&b, &f, 4); ((uint16_t *)p)[i] = (uint16_t)((b + 0x7fff + ((b >> 16) & 1)) >> 16); break; }
    case MPSDataTypeInt8: ((int8_t *)p)[i] = (int8_t)v; break;
    case MPSDataTypeInt16: ((int16_t *)p)[i] = (int16_t)v; break;
    case MPSDataTypeInt32: ((int32_t *)p)[i] = (int32_t)v; break;
    case MPSDataTypeInt64: ((int64_t *)p)[i] = (int64_t)v; break;
    case MPSDataTypeUInt8: ((uint8_t *)p)[i] = (uint8_t)v; break;
    case MPSDataTypeUInt16: ((uint16_t *)p)[i] = (uint16_t)v; break;
    case MPSDataTypeUInt32: ((uint32_t *)p)[i] = (uint32_t)v; break;
    case MPSDataTypeUInt64: ((uint64_t *)p)[i] = (uint64_t)fmax(v, 0); break;
    case MPSDataTypeBool: ((uint8_t *)p)[i] = v != 0; break;
    default: break;
    }
}
MPSShape *mg_broadcast_shape(MPSShape *a, MPSShape *b) {
    if (!a || !b) return nil;
    NSUInteger r = MAX(a.count, b.count);
    NSMutableArray *s = [NSMutableArray arrayWithCapacity:r];
    for (NSUInteger i = 0; i < r; i++) {
        NSInteger x = i < r - a.count ? 1 : a[i - (r - a.count)].integerValue, y = i < r - b.count ? 1 : b[i - (r - b.count)].integerValue;
        if (x < 0 || y < 0) [s addObject:@(-1)];
        else if (x == y || y == 1) [s addObject:@(x)];
        else if (x == 1) [s addObject:@(y)];
        else return nil;
    }
    return s;
}
BOOL mg_broadcast_dims(const MGValue *a, const MGValue *b, NSUInteger *dims, NSUInteger *rank) {
    NSUInteger r = MAX(a->rank, b->rank);
    for (NSUInteger i = 0; i < r; i++) {
        NSUInteger x = i < r - a->rank ? 1 : a->dims[i - (r - a->rank)], y = i < r - b->rank ? 1 : b->dims[i - (r - b->rank)];
        if (x != y && x != 1 && y != 1) return NO;
        dims[i] = x == 1 ? y : x;
    }
    *rank = r;
    return YES;
}
NSUInteger mg_bindex(const MGValue *v, const NSUInteger *idx, NSUInteger rank) {
    NSUInteger off = 0;
    for (NSUInteger i = 0; i < v->rank; i++) {
        NSUInteger k = idx[rank - v->rank + i];
        off = off * v->dims[i] + (v->dims[i] == 1 ? 0 : k);
    }
    return off;
}
NSInteger mg_axis(NSInteger axis, NSUInteger rank) { return axis < 0 ? axis + (NSInteger)rank : axis; }

/* ---------------- objects ---------------- */
#define MG_INIT __attribute__((objc_method_family(init)))
@interface MPSGraphTensor ()
- (instancetype)_isim_initWithOperation:(MPSGraphOperation *)op shape:(MPSShape *)shape dataType:(MPSDataType)t MG_INIT;
@end
@interface MPSGraphOperation ()
- (instancetype)_isim_initWithGraph:(MPSGraph *)g kind:(NSString *)kind inputs:(NSArray *)inputs name:(NSString *)name MG_INIT;
- (void)_isim_setOutputs:(NSArray *)outputs;
@end
@interface MPSGraphTensorData ()
- (instancetype)_isim_initWithShape:(MPSShape *)shape dataType:(MPSDataType)t MG_INIT;
- (instancetype)_isim_initWithValue:(MGValue *)v dataType:(MPSDataType)t MG_INIT;
- (MGValue *)_isim_value;
- (void)_isim_setValue:(MGValue *)v;
@end
@interface MPSGraphExecutable ()
- (instancetype)_isim_initWithGraph:(MPSGraph *)g feeds:(NSArray *)feeds targets:(NSArray *)targets operations:(NSArray *)operations MG_INIT;
@end
@implementation MPSGraphObject
@end
@implementation MPSGraphType
- (id)copyWithZone:(NSZone *)zone { return self; }
@end
@implementation MPSGraphShapedType
- (instancetype)initWithShape:(MPSShape *)shape dataType:(MPSDataType)dataType {
    if ((self = [super init])) { _shape = [shape copy]; _dataType = dataType; }
    return self;
}
- (id)copyWithZone:(NSZone *)zone { return [[MPSGraphShapedType alloc] initWithShape:_shape dataType:_dataType]; }
- (BOOL)isEqualTo:(MPSGraphShapedType *)o { return o && o.dataType == _dataType && ((!o.shape && !_shape) || [o.shape isEqualToArray:_shape]); }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[MPSGraphShapedType class]] && [self isEqualTo:o]; }
- (NSUInteger)hash { return _shape.hash ^ _dataType; }
@end

@implementation MPSGraphDevice {
    id<MTLDevice> _metal;
}
+ (instancetype)deviceWithMTLDevice:(id<MTLDevice>)metalDevice { MPSGraphDevice *d = [self new]; d->_metal = metalDevice; return d; }
- (MPSGraphDeviceType)type { return MPSGraphDeviceTypeMetal; }
- (id<MTLDevice>)metalDevice { return _metal ?: MTLCreateSystemDefaultDevice(); }
@end

@implementation MPSGraphTensor {
    __weak MPSGraphOperation *_weakOp;     /* the graph keeps its operations */
}
- (instancetype)_isim_initWithOperation:(MPSGraphOperation *)op shape:(MPSShape *)shape dataType:(MPSDataType)t {
    if ((self = [super init])) { _weakOp = op; _shape = [shape copy]; _dataType = t; }
    return self;
}
- (MPSGraphOperation *)operation { return _weakOp; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"<MPSGraphTensor %@ %@ 0x%x>", self.operation.kind, _shape, (unsigned)_dataType]; }
@end

@implementation MPSGraphOperation {
    __weak MPSGraph *_graph;
    NSArray<MPSGraphTensor *> *_inputs, *_outputs;
    NSString *_name;
}
- (instancetype)_isim_initWithGraph:(MPSGraph *)g kind:(NSString *)kind inputs:(NSArray *)inputs name:(NSString *)name {
    if ((self = [super init])) { _graph = g; _kind = [kind copy]; _inputs = [inputs copy]; _name = [name copy] ?: kind; }
    return self;
}
- (void)_isim_setOutputs:(NSArray *)outputs { _outputs = [outputs copy]; }
- (NSArray<MPSGraphTensor *> *)inputTensors { return _inputs; }
- (NSArray<MPSGraphTensor *> *)outputTensors { return _outputs ?: @[]; }
- (NSArray<MPSGraphOperation *> *)controlDependencies { return @[]; }
- (MPSGraph *)graph { return _graph; }
- (NSString *)name { return _name; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"<MPSGraphOperation %@ %@>", _kind, _name]; }
@end

/* ---------------- tensor data ---------------- */
@implementation MPSGraphTensorData {
    NSMutableData *_bytes;
    id<MTLBuffer> _buffer;
    MPSGraphDevice *_device;
}
- (instancetype)_isim_initWithShape:(MPSShape *)shape dataType:(MPSDataType)t {
    if ((self = [super init])) {
        _shape = [shape copy]; _dataType = t; _device = [MPSGraphDevice deviceWithMTLDevice:MTLCreateSystemDefaultDevice()];
        _bytes = [NSMutableData dataWithLength:MAX([self _isim_count] * mg_type_size(t), (NSUInteger)1)];
    }
    return self;
}
- (NSUInteger)_isim_count { NSUInteger n = 1; for (NSNumber *d in _shape) n *= (NSUInteger)MAX(d.integerValue, 0); return n; }
- (void *)_isim_bytes { return _buffer ? _buffer.contents : _bytes.mutableBytes; }
- (MPSGraphDevice *)device { return _device; }
- (instancetype)initWithDevice:(MPSGraphDevice *)device data:(NSData *)data shape:(MPSShape *)shape dataType:(MPSDataType)t {
    if ((self = [self _isim_initWithShape:shape dataType:t])) {
        _device = device ?: _device;
        memcpy(_bytes.mutableBytes, data.bytes, MIN(data.length, _bytes.length));
    }
    return self;
}
- (instancetype)initWithMTLBuffer:(id<MTLBuffer>)buffer shape:(MPSShape *)shape dataType:(MPSDataType)t {
    if ((self = [self _isim_initWithShape:shape dataType:t])) { _buffer = buffer; _bytes = nil; }
    return self;
}
- (instancetype)initWithMTLBuffer:(id<MTLBuffer>)buffer shape:(MPSShape *)shape dataType:(MPSDataType)t rowBytes:(NSUInteger)rowBytes {
    /* rows of rowBytes: packed into the tensor's own storage */
    if ((self = [self _isim_initWithShape:shape dataType:t])) {
        NSUInteger cols = shape.count ? (NSUInteger)MAX(shape.lastObject.integerValue, 0) : 1, es = mg_type_size(t), rows = cols ? [self _isim_count] / cols : 0;
        for (NSUInteger r = 0; r < rows; r++) memcpy((uint8_t *)_bytes.mutableBytes + r * cols * es, (const uint8_t *)buffer.contents + r * rowBytes, cols * es);
    }
    return self;
}
- (instancetype)initWithMPSMatrix:(MPSMatrix *)m { return [self initWithMPSMatrix:m rank:m.matrices > 1 ? 3 : 2]; }
- (instancetype)initWithMPSMatrix:(MPSMatrix *)m rank:(NSUInteger)rank {
    NSMutableArray *shape = [NSMutableArray array];
    for (NSUInteger i = 2; i < rank; i++) [shape addObject:@(i == 2 ? m.matrices : 1)];
    [shape addObjectsFromArray:@[ @(m.rows), @(m.columns) ]];
    if ((self = [self _isim_initWithShape:shape dataType:m.dataType])) {
        NSUInteger es = mg_type_size(m.dataType), k = 0;
        for (NSUInteger b = 0; b < m.matrices; b++)
            for (NSUInteger r = 0; r < m.rows; r++, k++)
                memcpy((uint8_t *)_bytes.mutableBytes + k * m.columns * es, (const uint8_t *)m.data.contents + m.offset + b * m.matrixBytes + r * m.rowBytes, m.columns * es);
    }
    return self;
}
- (instancetype)initWithMPSVector:(MPSVector *)v { return [self initWithMPSVector:v rank:1]; }
- (instancetype)initWithMPSVector:(MPSVector *)v rank:(NSUInteger)rank {
    NSMutableArray *shape = [NSMutableArray array];
    for (NSUInteger i = 1; i < rank; i++) [shape addObject:@(i == 1 ? v.vectors : 1)];
    [shape addObject:@(v.length)];
    if ((self = [self _isim_initWithShape:shape dataType:v.dataType])) {
        NSUInteger es = mg_type_size(v.dataType);
        for (NSUInteger b = 0; b < v.vectors; b++)
            memcpy((uint8_t *)_bytes.mutableBytes + b * v.length * es, (const uint8_t *)v.data.contents + v.offset + b * v.vectorBytes, v.length * es);
    }
    return self;
}
- (instancetype)initWithMPSNDArray:(MPSNDArray *)a {
    NSMutableArray *shape = [NSMutableArray array];
    for (NSUInteger i = a.numberOfDimensions; i-- > 0;) [shape addObject:@([a lengthOfDimension:i])];
    if ((self = [self _isim_initWithShape:shape dataType:a.dataType])) [a readBytes:_bytes.mutableBytes strideBytes:NULL];
    return self;
}
/* an image batch as N x H x W x C (float32) */
- (instancetype)initWithMPSImageBatch:(NSArray<MPSImage *> *)batch {
    MPSImage *first = batch.firstObject;
    MPSShape *shape = @[ @(batch.count), @(first.height), @(first.width), @(first.featureChannels) ];
    if ((self = [self _isim_initWithShape:shape dataType:MPSDataTypeFloat32])) {
        NSUInteger per = first.height * first.width * first.featureChannels;
        for (NSUInteger i = 0; i < batch.count; i++) {
            MPSImage *img = batch[i];
            MPSImageFeatureChannelFormat f = img.featureChannelFormat;
            size_t es = f == MPSImageFeatureChannelFormatUnorm8 ? 1 : f == MPSImageFeatureChannelFormatFloat32 ? 4 : 2;
            NSMutableData *raw = [NSMutableData dataWithLength:per * es];
            [img readBytes:raw.mutableBytes dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels imageIndex:0];
            float *out = (float *)_bytes.mutableBytes + i * per;
            for (NSUInteger k = 0; k < per; k++) {
                const uint8_t *p = (const uint8_t *)raw.bytes + k * es;
                out[k] = f == MPSImageFeatureChannelFormatUnorm8 ? *p / 255.0f : f == MPSImageFeatureChannelFormatUnorm16 ? *(const uint16_t *)p / 65535.0f
                       : f == MPSImageFeatureChannelFormatFloat16 ? (float)*(const _Float16 *)p : *(const float *)p;
            }
        }
    }
    return self;
}
- (MPSNDArray *)mpsndarray {
    MPSNDArrayDescriptor *d = [MPSNDArrayDescriptor descriptorWithDataType:_dataType shape:_shape.count ? _shape : @[ @1 ]];
    MPSNDArray *a = [[MPSNDArray alloc] initWithDevice:_device.metalDevice descriptor:d];
    [a writeBytes:[self _isim_bytes] strideBytes:NULL];
    return a;
}
- (MGValue *)_isim_value {
    MGValue *v = mg_value_of_shape(_shape);
    const void *p = [self _isim_bytes];
    for (NSUInteger i = 0; i < v->n; i++) v->d[i] = mg_load(_dataType, p, i);
    return v;
}
- (instancetype)_isim_initWithValue:(MGValue *)v dataType:(MPSDataType)t {
    if ((self = [self _isim_initWithShape:[v shape] dataType:t])) [self _isim_setValue:v];
    return self;
}
- (void)_isim_setValue:(MGValue *)v {
    void *p = [self _isim_bytes];
    NSUInteger n = MIN(v->n, [self _isim_count]);
    for (NSUInteger i = 0; i < n; i++) mg_store(_dataType, p, i, v->d[i]);
}
@end

/* ---------------- descriptors ---------------- */
@implementation MPSGraphCompilationDescriptor
- (void)disableTypeInference {}
- (id)copyWithZone:(NSZone *)zone {
    MPSGraphCompilationDescriptor *d = [MPSGraphCompilationDescriptor new];
    d.optimizationLevel = self.optimizationLevel; d.waitForCompilationCompletion = self.waitForCompilationCompletion;
    d.compilationCompletionHandler = self.compilationCompletionHandler; d.dispatchQueue = self.dispatchQueue;
    d.optimizationProfile = self.optimizationProfile; d.callables = self.callables;
    return d;
}
@end
@implementation MPSGraphExecutionDescriptor
@end
@implementation MPSGraphExecutableExecutionDescriptor
@end

/* ---------------- graphs ---------------- */
@implementation MPSGraph {
    NSMutableArray<MPSGraphOperation *> *_ops;
    NSMutableArray<MPSGraphTensor *> *_placeholders;
    uint64_t _runs;
}
+ (instancetype)new { return [[self alloc] init]; }
- (instancetype)init {
    if ((self = [super init])) { _ops = [NSMutableArray array]; _placeholders = [NSMutableArray array]; _options = MPSGraphOptionsDefault; }
    return self;
}
- (NSArray<MPSGraphTensor *> *)placeholderTensors { return [_placeholders copy]; }
- (void)_isim_addPlaceholder:(MPSGraphTensor *)t { [_placeholders addObject:t]; }
- (NSArray<MPSGraphTensor *> *)_isim_op:(NSString *)kind inputs:(NSArray<MPSGraphTensor *> *)inputs types:(NSArray<NSNumber *> *)types
                                 shapes:(NSArray *)shapes name:(NSString *)name eval:(MGEval)eval grad:(MGGrad)grad {
    MPSGraphOperation *op = [[MPSGraphOperation alloc] _isim_initWithGraph:self kind:kind inputs:inputs ?: @[] name:name];
    op.eval = eval; op.grad = grad;
    NSMutableArray *outs = [NSMutableArray array];
    for (NSUInteger i = 0; i < types.count; i++) {
        id s = i < shapes.count ? shapes[i] : nil;
        [outs addObject:[[MPSGraphTensor alloc] _isim_initWithOperation:op shape:s == [NSNull null] ? nil : s dataType:(MPSDataType)types[i].unsignedIntValue]];
    }
    [op _isim_setOutputs:outs];
    [_ops addObject:op];
    return outs;
}
- (MPSGraphTensor *)_isim_op1:(NSString *)kind inputs:(NSArray<MPSGraphTensor *> *)inputs type:(MPSDataType)type shape:(MPSShape *)shape
                         name:(NSString *)name eval:(MGEval)eval grad:(MGGrad)grad {
    return [self _isim_op:kind inputs:inputs types:@[ @(type) ] shapes:@[ shape ?: (id)[NSNull null] ] name:name eval:eval grad:grad][0];
}
- (MPSGraphOperation *)_isim_assignmentOf:(MPSGraphTensor *)variable value:(MPSGraphTensor *)value name:(NSString *)name {
    MPSGraphOperation *op = [[MPSGraphOperation alloc] _isim_initWithGraph:self kind:@"assign" inputs:@[ value ] name:name];
    op.eval = ^NSArray *(NSArray *in, MGRun *run) { return @[]; };
    op.assignTarget = variable;
    [op _isim_setOutputs:@[]];
    [_ops addObject:op];
    return op;
}

/* evaluates the targets: each operation once, inputs first; variables keep their values until the run's assignments,
   applied at its end */
- (NSMapTable *)_isim_evaluate:(NSDictionary<MPSGraphTensor *, MGValue *> *)feeds targets:(NSArray<MPSGraphTensor *> *)targets
                    operations:(NSArray<MPSGraphOperation *> *)operations {
    NSMapTable *memo = [NSMapTable strongToStrongObjectsMapTable];
    for (MPSGraphTensor *t in feeds) [memo setObject:feeds[t] forKey:t];
    MGRun *run = [MGRun new];
    run.rng = 0x9e3779b97f4a7c15ULL ^ (++_runs * 0xbf58476d1ce4e5b9ULL);
    __block void (^eval_op)(MPSGraphOperation *);
    __weak __block void (^weak_eval)(MPSGraphOperation *);
    eval_op = ^(MPSGraphOperation *op) {
        if (op.outputTensors.count && [memo objectForKey:op.outputTensors[0]]) return;
        NSMutableArray *ins = [NSMutableArray array];
        for (MPSGraphTensor *t in op.inputTensors) {
            if (![memo objectForKey:t]) weak_eval(t.operation);
            MGValue *v = [memo objectForKey:t];
            [ins addObject:v ?: [MGValue scalar:0]];
        }
        NSArray<MGValue *> *outs = op.eval(ins, run);
        for (NSUInteger i = 0; i < op.outputTensors.count && i < outs.count; i++) {
            MPSGraphTensor *t = op.outputTensors[i];
            MGValue *v = outs[i];
            if (!mg_is_float(t.dataType) || t.dataType != MPSDataTypeFloat32)
                for (NSUInteger k = 0; k < v->n; k++) v->d[k] = mg_norm(t.dataType, v->d[k]);
            [memo setObject:v forKey:t];
        }
    };
    weak_eval = eval_op;
    for (MPSGraphTensor *t in targets) if (![memo objectForKey:t]) eval_op(t.operation);
    NSMutableArray *assignments = [NSMutableArray array];
    for (MPSGraphOperation *op in operations) {
        eval_op(op);
        if (op.assignTarget) {
            MPSGraphTensor *value = op.inputTensors[0];
            if (![memo objectForKey:value]) eval_op(value.operation);
            [assignments addObject:@[ op.assignTarget.operation, [memo objectForKey:value] ?: [MGValue scalar:0] ]];
        }
    }
    for (NSArray *a in assignments) {                 /* the new values, in the variable's data type */
        MPSGraphOperation *var = a[0];
        MGValue *v = a[1], *copy = [MGValue valueLike:v];
        MPSDataType t = var.outputTensors[0].dataType;
        for (NSUInteger k = 0; k < v->n; k++) copy->d[k] = mg_norm(t, v->d[k]);
        var.variableValue = copy;
    }
    return memo;
}
- (NSDictionary *)_isim_feedValues:(MPSGraphTensorDataDictionary *)feeds {
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (MPSGraphTensor *t in feeds) values[t] = [feeds[t] _isim_value];
    return values;
}
- (MPSGraphTensorDataDictionary *)runWithFeeds:(MPSGraphTensorDataDictionary *)feeds targetTensors:(NSArray<MPSGraphTensor *> *)targets
                              targetOperations:(NSArray<MPSGraphOperation *> *)operations {
    NSMapTable *memo = [self _isim_evaluate:[self _isim_feedValues:feeds] targets:targets operations:operations ?: @[]];
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    for (MPSGraphTensor *t in targets) {
        MGValue *v = [memo objectForKey:t];
        if (v) results[t] = [[MPSGraphTensorData alloc] _isim_initWithValue:v dataType:t.dataType];
    }
    return results;
}
- (MPSGraphTensorDataDictionary *)runWithMTLCommandQueue:(id<MTLCommandQueue>)queue feeds:(MPSGraphTensorDataDictionary *)feeds
                                           targetTensors:(NSArray<MPSGraphTensor *> *)targets targetOperations:(NSArray<MPSGraphOperation *> *)operations {
    return [self runWithFeeds:feeds targetTensors:targets targetOperations:operations];
}
- (void)runWithMTLCommandQueue:(id<MTLCommandQueue>)queue feeds:(MPSGraphTensorDataDictionary *)feeds targetOperations:(NSArray<MPSGraphOperation *> *)operations
             resultsDictionary:(MPSGraphTensorDataDictionary *)results {
    NSMapTable *memo = [self _isim_evaluate:[self _isim_feedValues:feeds] targets:results.allKeys operations:operations ?: @[]];
    for (MPSGraphTensor *t in results) { MGValue *v = [memo objectForKey:t]; if (v) [results[t] _isim_setValue:v]; }
}
/* isim runs at once, then calls the handlers (on a background queue unless waitUntilCompleted) */
- (MPSGraphTensorDataDictionary *)runAsyncWithFeeds:(MPSGraphTensorDataDictionary *)feeds targetTensors:(NSArray<MPSGraphTensor *> *)targets
                                   targetOperations:(NSArray<MPSGraphOperation *> *)operations executionDescriptor:(MPSGraphExecutionDescriptor *)d {
    MPSGraphTensorDataDictionary *results = [self runWithFeeds:feeds targetTensors:targets targetOperations:operations];
    MPSGraphScheduledHandler scheduled = d.scheduledHandler;
    MPSGraphCompletionHandler completed = d.completionHandler;
    void (^handlers)(void) = ^{ if (scheduled) scheduled(results, nil); if (completed) completed(results, nil); };
    if (d.waitUntilCompleted) handlers(); else dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), handlers);
    return results;
}
- (MPSGraphTensorDataDictionary *)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)queue feeds:(MPSGraphTensorDataDictionary *)feeds
                                                targetTensors:(NSArray<MPSGraphTensor *> *)targets targetOperations:(NSArray<MPSGraphOperation *> *)operations
                                          executionDescriptor:(MPSGraphExecutionDescriptor *)d {
    return [self runAsyncWithFeeds:feeds targetTensors:targets targetOperations:operations executionDescriptor:d];
}
- (void)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)queue feeds:(MPSGraphTensorDataDictionary *)feeds targetOperations:(NSArray<MPSGraphOperation *> *)operations
                  resultsDictionary:(MPSGraphTensorDataDictionary *)results executionDescriptor:(MPSGraphExecutionDescriptor *)d {
    [self runWithMTLCommandQueue:queue feeds:feeds targetOperations:operations resultsDictionary:results];
    MPSGraphScheduledHandler scheduled = d.scheduledHandler;
    MPSGraphCompletionHandler completed = d.completionHandler;
    void (^handlers)(void) = ^{ if (scheduled) scheduled(results, nil); if (completed) completed(results, nil); };
    if (d.waitUntilCompleted) handlers(); else dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), handlers);
}
- (MPSGraphExecutable *)compileWithDevice:(MPSGraphDevice *)device feeds:(MPSGraphTensorShapedTypeDictionary *)feeds targetTensors:(NSArray<MPSGraphTensor *> *)targets
                         targetOperations:(NSArray<MPSGraphOperation *> *)operations compilationDescriptor:(MPSGraphCompilationDescriptor *)cd {
    /* the feeds in the order the placeholders were made, then any others */
    NSMutableArray *order = [NSMutableArray array];
    for (MPSGraphTensor *p in _placeholders) if (feeds[p]) [order addObject:p];
    for (MPSGraphTensor *t in feeds) if (![order containsObject:t]) [order addObject:t];
    MPSGraphExecutable *e = [[MPSGraphExecutable alloc] _isim_initWithGraph:self feeds:order targets:targets operations:operations ?: @[]];
    if (cd.compilationCompletionHandler) {
        MPSGraphCompilationCompletionHandler h = cd.compilationCompletionHandler;
        if (cd.waitForCompilationCompletion) h(e, nil);
        else dispatch_async(cd.dispatchQueue ?: dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ h(e, nil); });
    }
    return e;
}
@end

@implementation MPSGraphExecutable {
    MPSGraph *_graph;
    NSArray *_feeds, *_targets, *_operations;
}
- (instancetype)_isim_initWithGraph:(MPSGraph *)g feeds:(NSArray *)feeds targets:(NSArray *)targets operations:(NSArray *)operations {
    if ((self = [super init])) { _graph = g; _feeds = [feeds copy]; _targets = [targets copy]; _operations = [operations copy]; _options = g.options; }
    return self;
}
- (NSArray<MPSGraphTensor *> *)feedTensors { return _feeds; }
- (NSArray<MPSGraphTensor *> *)targetTensors { return _targets; }
- (void)specializeWithDevice:(MPSGraphDevice *)device inputTypes:(NSArray<MPSGraphType *> *)inputTypes compilationDescriptor:(MPSGraphCompilationDescriptor *)cd {}
- (NSArray<MPSGraphTensorData *> *)runWithMTLCommandQueue:(id<MTLCommandQueue>)queue inputsArray:(NSArray<MPSGraphTensorData *> *)inputs
                                             resultsArray:(NSArray<MPSGraphTensorData *> *)resultsArray
                                      executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)d {
    NSMutableDictionary *feeds = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < _feeds.count && i < inputs.count; i++) feeds[_feeds[i]] = inputs[i];
    MPSGraphTensorDataDictionary *r = [_graph runWithFeeds:feeds targetTensors:_targets targetOperations:_operations];
    NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger i = 0; i < _targets.count; i++) {
        MPSGraphTensorData *v = r[_targets[i]];
        if (i < resultsArray.count && v) { [resultsArray[i] _isim_setValue:[v _isim_value]]; [out addObject:resultsArray[i]]; }
        else if (v) [out addObject:v];
    }
    if (d.scheduledHandler) d.scheduledHandler(out, nil);
    if (d.completionHandler) d.completionHandler(out, nil);
    return out;
}
- (NSArray<MPSGraphTensorData *> *)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)queue inputsArray:(NSArray<MPSGraphTensorData *> *)inputs
                                                  resultsArray:(NSArray<MPSGraphTensorData *> *)resultsArray
                                           executionDescriptor:(MPSGraphExecutableExecutionDescriptor *)d {
    MPSGraphExecutableExecutionDescriptor *sync = [MPSGraphExecutableExecutionDescriptor new];
    NSArray *out = [self runWithMTLCommandQueue:queue inputsArray:inputs resultsArray:resultsArray executionDescriptor:sync];
    MPSGraphExecutableScheduledHandler scheduled = d.scheduledHandler;
    MPSGraphExecutableCompletionHandler completed = d.completionHandler;
    void (^handlers)(void) = ^{ if (scheduled) scheduled(out, nil); if (completed) completed(out, nil); };
    if (d.waitUntilCompleted) handlers(); else dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), handlers);
    return out;
}
@end

/* ---------------- gradients ---------------- */
@implementation MPSGraph (GradientOps)
- (MPSGraphTensorDictionary *)gradientForPrimaryTensor:(MPSGraphTensor *)primary withTensors:(NSArray<MPSGraphTensor *> *)tensors name:(NSString *)name {
    /* the operations between the tensors and the primary tensor, in topological order */
    NSMutableArray<MPSGraphOperation *> *order = [NSMutableArray array];
    NSMutableSet *visited = [NSMutableSet set];
    NSMapTable *reaches = [NSMapTable strongToStrongObjectsMapTable];   /* op -> @YES if it depends on a requested tensor */
    NSSet *wanted = [NSSet setWithArray:tensors];
    __block BOOL (^visit)(MPSGraphOperation *);
    __weak __block BOOL (^weak_visit)(MPSGraphOperation *);
    visit = ^BOOL(MPSGraphOperation *op) {
        NSValue *key = [NSValue valueWithNonretainedObject:op];
        if ([visited containsObject:key]) return [[reaches objectForKey:op] boolValue];
        [visited addObject:key];
        BOOL r = NO;
        for (MPSGraphTensor *o in op.outputTensors) if ([wanted containsObject:o]) r = YES;
        for (MPSGraphTensor *t in op.inputTensors) r |= weak_visit(t.operation);
        [reaches setObject:@(r) forKey:op];
        [order addObject:op];
        return r;
    };
    weak_visit = visit;
    visit(primary.operation);
    NSMapTable *grads = [NSMapTable strongToStrongObjectsMapTable];
    [grads setObject:mg_ones_like(self, primary) forKey:primary];
    for (MPSGraphOperation *op in order.reverseObjectEnumerator) {
        if (![[reaches objectForKey:op] boolValue] || !op.grad) continue;
        NSMutableArray *outGrads = [NSMutableArray array];
        BOOL any = NO;
        for (MPSGraphTensor *o in op.outputTensors) { id g = [grads objectForKey:o]; any |= g != nil; [outGrads addObject:g ?: [NSNull null]]; }
        if (!any) continue;
        if ([wanted containsObject:op.outputTensors.firstObject] && !op.inputTensors.count) continue;
        NSArray *inGrads = op.grad(self, op, outGrads);
        for (NSUInteger i = 0; i < op.inputTensors.count && i < inGrads.count; i++) {
            if (inGrads[i] == [NSNull null]) continue;
            MPSGraphTensor *t = op.inputTensors[i], *prev = [grads objectForKey:t];
            [grads setObject:prev ? [self additionWithPrimaryTensor:prev secondaryTensor:inGrads[i] name:nil] : inGrads[i] forKey:t];
        }
    }
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (MPSGraphTensor *t in tensors) out[t] = [grads objectForKey:t] ?: mg_zeros_like(self, t);
    return out;
}
@end

/* ---------------- placeholders, constants, variables ---------------- */
@implementation MPSGraph (MemoryOps)
- (MPSGraphTensor *)placeholderWithShape:(MPSShape *)shape dataType:(MPSDataType)t name:(NSString *)name {
    MPSGraphTensor *p = [self _isim_op1:@"placeholder" inputs:@[] type:t shape:shape name:name eval:^NSArray *(NSArray *in, MGRun *run) {
        return @[ [MGValue scalar:0] ];             /* not fed: zero */
    } grad:nil];
    [self _isim_addPlaceholder:p];
    return p;
}
- (MPSGraphTensor *)placeholderWithShape:(MPSShape *)shape name:(NSString *)name { return [self placeholderWithShape:shape dataType:MPSDataTypeFloat32 name:name]; }
- (MPSGraphTensor *)constantWithData:(NSData *)data shape:(MPSShape *)shape dataType:(MPSDataType)t {
    MGValue *v = mg_value_of_shape(shape);
    for (NSUInteger i = 0; i < v->n && (i + 1) * mg_type_size(t) <= data.length; i++) v->d[i] = mg_load(t, data.bytes, i);
    return [self _isim_op1:@"constant" inputs:@[] type:t shape:shape name:nil eval:^NSArray *(NSArray *in, MGRun *run) {
        MGValue *c = [MGValue valueLike:v]; memcpy(c->d, v->d, v->n * sizeof(double)); return @[ c ];
    } grad:nil];
}
- (MPSGraphTensor *)constantWithScalar:(double)x dataType:(MPSDataType)t { return [self constantWithScalar:x shape:@[ @1 ] dataType:t]; }
- (MPSGraphTensor *)constantWithScalar:(double)x shape:(MPSShape *)shape dataType:(MPSDataType)t {
    return [self _isim_op1:@"constant" inputs:@[] type:t shape:shape name:nil eval:^NSArray *(NSArray *in, MGRun *run) {
        MGValue *c = mg_value_of_shape(shape);
        for (NSUInteger i = 0; i < c->n; i++) c->d[i] = x;
        return @[ c ];
    } grad:nil];
}
- (MPSGraphTensor *)variableWithData:(NSData *)data shape:(MPSShape *)shape dataType:(MPSDataType)t name:(NSString *)name {
    MGValue *v = mg_value_of_shape(shape);
    for (NSUInteger i = 0; i < v->n && (i + 1) * mg_type_size(t) <= data.length; i++) v->d[i] = mg_load(t, data.bytes, i);
    __block __weak MPSGraphOperation *weakOp;
    MPSGraphTensor *var = [self _isim_op1:@"variable" inputs:@[] type:t shape:shape name:name eval:^NSArray *(NSArray *in, MGRun *run) {
        MGValue *cur = weakOp.variableValue, *c = [MGValue valueLike:cur];
        memcpy(c->d, cur->d, cur->n * sizeof(double));
        return @[ c ];
    } grad:nil];
    weakOp = var.operation;
    var.operation.variableValue = v;
    return var;
}
- (MPSGraphTensor *)variableFromTensorWithTensor:(MPSGraphTensor *)tensor name:(NSString *)name {
    /* the variable starts with the tensor's value (computed now) */
    MGValue *v = [[self _isim_evaluate:@{} targets:@[ tensor ] operations:@[]] objectForKey:tensor];
    NSMutableData *d = [NSMutableData dataWithLength:v->n * mg_type_size(tensor.dataType)];
    for (NSUInteger i = 0; i < v->n; i++) mg_store(tensor.dataType, d.mutableBytes, i, v->d[i]);
    return [self variableWithData:d shape:[v shape] dataType:tensor.dataType name:name];
}
- (MPSGraphTensor *)readVariable:(MPSGraphTensor *)variable name:(NSString *)name {
    return [self _isim_op1:@"read" inputs:@[ variable ] type:variable.dataType shape:variable.shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        return @[ in[0] ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) { return @[ og[0] ]; }];
}
- (MPSGraphOperation *)assignVariable:(MPSGraphTensor *)variable withValueOfTensor:(MPSGraphTensor *)tensor name:(NSString *)name {
    return [self _isim_assignmentOf:variable value:tensor name:name];
}
@end
