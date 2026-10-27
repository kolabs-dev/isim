/* isim MetalPerformanceShadersGraph: the operations (adapted: isim's own CPU evaluation in double precision) and their
   gradients */
#import "mg_internal.h"
#include <float.h>

typedef double (^mg_fn)(const double *v);

/* ---------------- index helpers ---------------- */
static void strides_of(const NSUInteger *dims, NSUInteger rank, NSUInteger *st) {
    NSUInteger s = 1;
    for (NSUInteger i = rank; i-- > 0;) { st[i] = s; s *= dims[i]; }
}
static BOOL next_index(NSUInteger *idx, const NSUInteger *dims, NSUInteger rank) {
    for (NSUInteger i = rank; i-- > 0;) { if (++idx[i] < dims[i]) return YES; idx[i] = 0; }
    return NO;
}
static BOOL known(MPSShape *s) { if (!s) return NO; for (NSNumber *d in s) if (d.integerValue < 0) return NO; return YES; }

/* element-wise over broadcast inputs */
static MGValue *ew(NSArray<MGValue *> *in, mg_fn f) {
    NSUInteger dims[MG_MAX_RANK] = { 0 }, rank = 0, n = in.count;
    for (NSUInteger k = 0; k < n; k++) {             /* the broadcast of all the inputs' dimensions */
        MGValue *v = in[k];
        NSUInteger r = MAX(rank, v->rank), d2[MG_MAX_RANK];
        for (NSUInteger i = 0; i < r; i++) {
            NSUInteger x = i < r - rank ? 1 : dims[i - (r - rank)], y = i < r - v->rank ? 1 : v->dims[i - (r - v->rank)];
            if (x != y && x != 1 && y != 1) { NSLog(@"isim MPSGraph: shapes do not broadcast"); return [MGValue scalar:NAN]; }
            d2[i] = x == 1 ? y : x;
        }
        rank = r; memcpy(dims, d2, sizeof(NSUInteger) * rank);
    }
    MGValue *out = [MGValue valueWithDims:dims rank:rank];
    NSUInteger idx[MG_MAX_RANK] = { 0 };
    double v[8];
    for (NSUInteger i = 0; i < out->n; i++) {
        for (NSUInteger k = 0; k < n && k < 8; k++) v[k] = in[k]->d[mg_bindex(in[k], idx, rank)];
        out->d[i] = f(v);
        next_index(idx, dims, rank);
    }
    return out;
}
static MPSShape *bshape_all(NSArray<MPSGraphTensor *> *ins) {
    MPSShape *s = ins.firstObject.shape;
    for (NSUInteger i = 1; i < ins.count; i++) s = mg_broadcast_shape(s, ins[i].shape);
    return s;
}
static MPSGraphTensor *ewop(MPSGraph *g, NSString *kind, NSArray<MPSGraphTensor *> *ins, MPSDataType t, NSString *name, mg_fn f, MGGrad grad) {
    return [g _isim_op1:kind inputs:ins type:t shape:bshape_all(ins) name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) { return @[ ew(in, f) ]; } grad:grad];
}
static MPSDataType float_type(MPSDataType t) { return mg_is_float(t) ? t : MPSDataTypeFloat32; }

/* ---------------- internal operations of the gradients ---------------- */
MPSGraphTensor *mg_ones_like(MPSGraph *g, MPSGraphTensor *t) {
    return ewop(g, @"onesLike", @[ t ], float_type(t.dataType), nil, ^double(const double *v) { return 1; }, nil);
}
MPSGraphTensor *mg_zeros_like(MPSGraph *g, MPSGraphTensor *t) {
    return ewop(g, @"zerosLike", @[ t ], float_type(t.dataType), nil, ^double(const double *v) { return 0; }, nil);
}
/* sums the gradient over the dimensions the reference broadcast */
MPSGraphTensor *mg_sum_to_shape_of(MPSGraph *g, MPSGraphTensor *grad, MPSGraphTensor *ref) {
    return [g _isim_op1:@"sumToShapeOf" inputs:@[ grad, ref ] type:grad.dataType shape:ref.shape name:nil eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *gv = in[0], *r = in[1], *out = [MGValue valueLike:r];
        if (gv->n == r->n) { memcpy(out->d, gv->d, gv->n * sizeof(double)); return @[ out ]; }
        NSUInteger idx[MG_MAX_RANK] = { 0 };
        for (NSUInteger i = 0; i < gv->n; i++) { out->d[mg_bindex(r, idx, gv->rank)] += gv->d[i]; next_index(idx, gv->dims, gv->rank); }
        return @[ out ];
    } grad:nil];
}
MPSGraphTensor *mg_broadcast_like(MPSGraph *g, MPSGraphTensor *t, MPSGraphTensor *ref) {
    return [g _isim_op1:@"broadcastLike" inputs:@[ t, ref ] type:t.dataType shape:ref.shape name:nil eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *v = in[0], *r = in[1], *out = [MGValue valueLike:r];
        NSUInteger idx[MG_MAX_RANK] = { 0 };
        for (NSUInteger i = 0; i < out->n; i++) { out->d[i] = v->d[mg_bindex(v, idx, r->rank)]; next_index(idx, r->dims, r->rank); }
        return @[ out ];
    } grad:^NSArray *(MPSGraph *gr, MPSGraphOperation *op, NSArray *og) {
        return @[ mg_sum_to_shape_of(gr, og[0], op.inputTensors[0]), [NSNull null] ];
    }];
}
MPSGraphTensor *mg_reshape_like(MPSGraph *g, MPSGraphTensor *t, MPSGraphTensor *ref) {
    return [g _isim_op1:@"reshapeLike" inputs:@[ t, ref ] type:t.dataType shape:ref.shape name:nil eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *out = [MGValue valueLike:in[1]];
        memcpy(out->d, in[0]->d, MIN(in[0]->n, out->n) * sizeof(double));
        return @[ out ];
    } grad:^NSArray *(MPSGraph *gr, MPSGraphOperation *op, NSArray *og) { return @[ mg_reshape_like(gr, og[0], op.inputTensors[0]), [NSNull null] ]; }];
}
static MPSGraphTensor *mul(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b) { return [g multiplicationWithPrimaryTensor:a secondaryTensor:b name:nil]; }

/* ---------------- element-wise math ---------------- */
typedef double (^mg_d1)(double x, double y);   /* derivative from the input and the result */
static MPSGraphTensor *unary(MPSGraph *g, NSString *kind, MPSGraphTensor *x, NSString *name, double (^f)(double), mg_d1 df, MPSDataType out) {
    MGGrad grad = df ? ^NSArray *(MPSGraph *gr, MPSGraphOperation *op, NSArray *og) {
        MPSGraphTensor *X = op.inputTensors[0], *Y = op.outputTensors[0];
        return @[ ewop(gr, [kind stringByAppendingString:@"Gradient"], @[ og[0], X, Y ], X.dataType, nil, ^double(const double *v) { return v[0] * df(v[1], v[2]); }, nil) ];
    } : nil;
    return ewop(g, kind, @[ x ], out, name, ^double(const double *v) { return f(v[0]); }, grad);
}
#define UNARY(SEL, KIND, F, DF) \
    - (MPSGraphTensor *)SEL##WithTensor:(MPSGraphTensor *)t name:(NSString *)name { \
        return unary(self, @KIND, t, name, ^double(double x) { return (F); }, DF, t.dataType); }
#define UNARY_TYPE(SEL, KIND, F, TYPE) \
    - (MPSGraphTensor *)SEL##WithTensor:(MPSGraphTensor *)t name:(NSString *)name { \
        return unary(self, @KIND, t, name, ^double(double x) { return (F); }, nil, TYPE); }
#define D(EXPR) ^double(double x, double y) { return (EXPR); }

@implementation MPSGraph (ArithmeticOps)
UNARY(identity, "identity", x, D(1))
UNARY(exponent, "exponent", exp(x), D(y))
UNARY(exponentBase2, "exponentBase2", exp2(x), D(y * M_LN2))
UNARY(exponentBase10, "exponentBase10", pow(10, x), D(y * M_LN10))
UNARY(logarithm, "logarithm", log(x), D(1 / x))
UNARY(logarithmBase2, "logarithmBase2", log2(x), D(1 / (x * M_LN2)))
UNARY(logarithmBase10, "logarithmBase10", log10(x), D(1 / (x * M_LN10)))
UNARY(square, "square", x * x, D(2 * x))
UNARY(squareRoot, "squareRoot", sqrt(x), D(0.5 / y))
UNARY(reciprocalSquareRoot, "reciprocalSquareRoot", 1 / sqrt(x), D(-0.5 * y * y * y))
UNARY(reverseSquareRoot, "reverseSquareRoot", 1 / sqrt(x), D(-0.5 * y * y * y))
UNARY(reciprocal, "reciprocal", 1 / x, D(-y * y))
UNARY(absolute, "absolute", fabs(x), D(x > 0 ? 1 : x < 0 ? -1 : 0))
UNARY(negative, "negative", -x, D(-1))
UNARY(sign, "sign", x > 0 ? 1 : x < 0 ? -1 : 0, nil)
UNARY(signbit, "signbit", signbit(x) ? 1 : 0, nil)
UNARY(ceil, "ceil", ceil(x), nil)
UNARY(floor, "floor", floor(x), nil)
UNARY(round, "round", round(x), nil)
UNARY(rint, "rint", rint(x), nil)
UNARY(truncate, "truncate", trunc(x), nil)
UNARY(sin, "sin", sin(x), D(cos(x)))
UNARY(cos, "cos", cos(x), D(-sin(x)))
UNARY(tan, "tan", tan(x), D(1 + y * y))
UNARY(sinh, "sinh", sinh(x), D(cosh(x)))
UNARY(cosh, "cosh", cosh(x), D(sinh(x)))
UNARY(tanh, "tanh", tanh(x), D(1 - y * y))
UNARY(asin, "asin", asin(x), D(1 / sqrt(1 - x * x)))
UNARY(acos, "acos", acos(x), D(-1 / sqrt(1 - x * x)))
UNARY(atan, "atan", atan(x), D(1 / (1 + x * x)))
UNARY(asinh, "asinh", asinh(x), D(1 / sqrt(x * x + 1)))
UNARY(acosh, "acosh", acosh(x), D(1 / sqrt(x * x - 1)))
UNARY(atanh, "atanh", atanh(x), D(1 / (1 - x * x)))
UNARY(erf, "erf", erf(x), D(2 / sqrt(M_PI) * exp(-x * x)))
UNARY_TYPE(not, "not", x == 0, MPSDataTypeBool)
UNARY_TYPE(isInfinite, "isInfinite", isinf(x) ? 1 : 0, MPSDataTypeBool)
UNARY_TYPE(isFinite, "isFinite", isfinite(x) ? 1 : 0, MPSDataTypeBool)
UNARY_TYPE(isNaN, "isNaN", isnan(x) ? 1 : 0, MPSDataTypeBool)

/* binary: f, and the derivatives along a and b (from a, b and the result) */
typedef double (^mg_d2)(double a, double b, double y);
static MPSGraphTensor *binary(MPSGraph *g, NSString *kind, MPSGraphTensor *a, MPSGraphTensor *b, NSString *name, double (^f)(double, double),
                              mg_d2 da, mg_d2 db, MPSDataType out) {
    MGGrad grad = (da || db) ? ^NSArray *(MPSGraph *gr, MPSGraphOperation *op, NSArray *og) {
        MPSGraphTensor *A = op.inputTensors[0], *B = op.inputTensors[1], *Y = op.outputTensors[0];
        NSArray *ins = @[ og[0], A, B, Y ];
        id ga = da ? mg_sum_to_shape_of(gr, ewop(gr, @"gradientA", ins, Y.dataType, nil, ^double(const double *v) { return v[0] * da(v[1], v[2], v[3]); }, nil), A)
                   : (id)[NSNull null];
        id gb = db ? mg_sum_to_shape_of(gr, ewop(gr, @"gradientB", ins, Y.dataType, nil, ^double(const double *v) { return v[0] * db(v[1], v[2], v[3]); }, nil), B)
                   : (id)[NSNull null];
        return @[ ga, gb ];
    } : nil;
    return ewop(g, kind, @[ a, b ], out, name, ^double(const double *v) { return f(v[0], v[1]); }, grad);
}
#define BINARY(SEL, KIND, F, DA, DB) \
    - (MPSGraphTensor *)SEL##WithPrimaryTensor:(MPSGraphTensor *)a secondaryTensor:(MPSGraphTensor *)b name:(NSString *)name { \
        return binary(self, @KIND, a, b, name, ^double(double x, double z) { return (F); }, DA, DB, a.dataType); }
#define BINARY_BOOL(SEL, KIND, F) \
    - (MPSGraphTensor *)SEL##WithPrimaryTensor:(MPSGraphTensor *)a secondaryTensor:(MPSGraphTensor *)b name:(NSString *)name { \
        return binary(self, @KIND, a, b, name, ^double(double x, double z) { return (F) ? 1 : 0; }, nil, nil, MPSDataTypeBool); }
#define D2(EXPR) ^double(double x, double z, double y) { return (EXPR); }

BINARY(addition, "addition", x + z, D2(1), D2(1))
BINARY(subtraction, "subtraction", x - z, D2(1), D2(-1))
BINARY(multiplication, "multiplication", x * z, D2(z), D2(x))
BINARY(division, "division", x / z, D2(1 / z), D2(-x / (z * z)))
BINARY(divisionNoNaN, "divisionNoNaN", z == 0 ? 0 : x / z, D2(z == 0 ? 0 : 1 / z), D2(z == 0 ? 0 : -x / (z * z)))
BINARY(modulo, "modulo", fmod(x, z), D2(1), D2(-trunc(x / z)))
BINARY(floorModulo, "floorModulo", x - floor(x / z) * z, D2(1), D2(-floor(x / z)))
BINARY(power, "power", pow(x, z), D2(z * pow(x, z - 1)), D2(x > 0 ? y * log(x) : 0))
BINARY(minimum, "minimum", fmin(x, z), D2(x <= z ? 1 : 0), D2(x <= z ? 0 : 1))
BINARY(maximum, "maximum", fmax(x, z), D2(x >= z ? 1 : 0), D2(x >= z ? 0 : 1))
BINARY(minimumWithNaNPropagation, "minimumWithNaNPropagation", isnan(x) || isnan(z) ? NAN : fmin(x, z), D2(x <= z ? 1 : 0), D2(x <= z ? 0 : 1))
BINARY(maximumWithNaNPropagation, "maximumWithNaNPropagation", isnan(x) || isnan(z) ? NAN : fmax(x, z), D2(x >= z ? 1 : 0), D2(x >= z ? 0 : 1))
BINARY(atan2, "atan2", atan2(x, z), D2(z / (x * x + z * z)), D2(-x / (x * x + z * z)))
BINARY_BOOL(equal, "equal", x == z)
BINARY_BOOL(notEqual, "notEqual", x != z)
BINARY_BOOL(lessThan, "lessThan", x < z)
BINARY_BOOL(lessThanOrEqualTo, "lessThanOrEqualTo", x <= z)
BINARY_BOOL(greaterThan, "greaterThan", x > z)
BINARY_BOOL(greaterThanOrEqualTo, "greaterThanOrEqualTo", x >= z)
BINARY_BOOL(logicalAND, "logicalAND", x != 0 && z != 0)
BINARY_BOOL(logicalOR, "logicalOR", x != 0 || z != 0)
BINARY_BOOL(logicalNAND, "logicalNAND", !(x != 0 && z != 0))
BINARY_BOOL(logicalNOR, "logicalNOR", !(x != 0 || z != 0))
BINARY_BOOL(logicalXOR, "logicalXOR", (x != 0) != (z != 0))
BINARY_BOOL(logicalXNOR, "logicalXNOR", (x != 0) == (z != 0))

- (MPSGraphTensor *)selectWithPredicateTensor:(MPSGraphTensor *)p truePredicateTensor:(MPSGraphTensor *)t falseSelectTensor:(MPSGraphTensor *)f name:(NSString *)name {
    return ewop(self, @"select", @[ p, t, f ], t.dataType, name, ^double(const double *v) { return v[0] != 0 ? v[1] : v[2]; },
                ^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) {
        MPSGraphTensor *P = op.inputTensors[0], *T = op.inputTensors[1], *F = op.inputTensors[2];
        MPSGraphTensor *gt = ewop(g, @"selectGradient", @[ og[0], P ], T.dataType, nil, ^double(const double *v) { return v[1] != 0 ? v[0] : 0; }, nil);
        MPSGraphTensor *gf = ewop(g, @"selectGradient", @[ og[0], P ], F.dataType, nil, ^double(const double *v) { return v[1] != 0 ? 0 : v[0]; }, nil);
        return @[ [NSNull null], mg_sum_to_shape_of(g, gt, T), mg_sum_to_shape_of(g, gf, F) ];
    });
}
- (MPSGraphTensor *)clampWithTensor:(MPSGraphTensor *)x minValueTensor:(MPSGraphTensor *)lo maxValueTensor:(MPSGraphTensor *)hi name:(NSString *)name {
    return ewop(self, @"clamp", @[ x, lo, hi ], x.dataType, name, ^double(const double *v) { return fmin(fmax(v[0], v[1]), v[2]); },
                ^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) {
        MPSGraphTensor *X = op.inputTensors[0];
        MPSGraphTensor *gx = ewop(g, @"clampGradient", @[ og[0], X, op.inputTensors[1], op.inputTensors[2] ], X.dataType, nil,
                                  ^double(const double *v) { return v[1] >= v[2] && v[1] <= v[3] ? v[0] : 0; }, nil);
        return @[ mg_sum_to_shape_of(g, gx, X), [NSNull null], [NSNull null] ];
    });
}
@end

/* ---------------- matrix multiplication ---------------- */
/* a (..., m, k) x b (..., k, n), the leading dimensions broadcast; ta / tb: the operand's last two dimensions swapped */
static MGValue *matmul(MGValue *a, MGValue *b, BOOL ta, BOOL tb) {
    MGValue *A = a, *B = b;
    NSUInteger one[2];
    if (a->rank < 2) { one[0] = 1; one[1] = a->rank ? a->dims[0] : 1; A = [MGValue valueWithDims:one rank:2]; memcpy(A->d, a->d, a->n * sizeof(double)); }
    if (b->rank < 2) { one[0] = b->rank ? b->dims[0] : 1; one[1] = 1; B = [MGValue valueWithDims:one rank:2]; memcpy(B->d, b->d, b->n * sizeof(double)); }
    NSUInteger ar = A->rank, br = B->rank;
    NSUInteger m = ta ? A->dims[ar - 1] : A->dims[ar - 2], k = ta ? A->dims[ar - 2] : A->dims[ar - 1];
    NSUInteger k2 = tb ? B->dims[br - 1] : B->dims[br - 2], n = tb ? B->dims[br - 2] : B->dims[br - 1];
    if (k != k2) { NSLog(@"isim MPSGraph: matrix multiplication of mismatched inner dimensions %lu and %lu", (unsigned long)k, (unsigned long)k2); return [MGValue scalar:NAN]; }
    /* the batch dimensions, broadcast */
    MGValue *ba = [MGValue valueWithDims:A->dims rank:ar - 2], *bb = [MGValue valueWithDims:B->dims rank:br - 2];
    NSUInteger bd[MG_MAX_RANK], brk = 0;
    if (!mg_broadcast_dims(ba, bb, bd, &brk)) { NSLog(@"isim MPSGraph: batch dimensions do not broadcast"); return [MGValue scalar:NAN]; }
    NSUInteger od[MG_MAX_RANK];
    memcpy(od, bd, brk * sizeof(NSUInteger)); od[brk] = m; od[brk + 1] = n;
    MGValue *out = [MGValue valueWithDims:od rank:brk + 2];
    NSUInteger batches = out->n / MAX(m * n, (NSUInteger)1), idx[MG_MAX_RANK] = { 0 };
    for (NSUInteger t = 0; t < batches; t++) {
        const double *pa = A->d + mg_bindex(ba, idx, brk) * A->dims[ar - 2] * A->dims[ar - 1];
        const double *pb = B->d + mg_bindex(bb, idx, brk) * B->dims[br - 2] * B->dims[br - 1];
        double *po = out->d + t * m * n;
        for (NSUInteger i = 0; i < m; i++)
            for (NSUInteger j = 0; j < n; j++) {
                double s = 0;
                for (NSUInteger q = 0; q < k; q++) s += (ta ? pa[q * m + i] : pa[i * k + q]) * (tb ? pb[j * k + q] : pb[q * n + j]);
                po[i * n + j] = s;
            }
        next_index(idx, bd, brk);
    }
    return out;
}
static MPSShape *matmul_shape(MPSShape *a, MPSShape *b) {
    if (!a || !b || a.count < 2 || b.count < 2) return nil;
    MPSShape *batch = mg_broadcast_shape([a subarrayWithRange:NSMakeRange(0, a.count - 2)], [b subarrayWithRange:NSMakeRange(0, b.count - 2)]);
    if (!batch) return nil;
    return [batch arrayByAddingObjectsFromArray:@[ a[a.count - 2], b[b.count - 1] ]];
}
static MPSGraphTensor *matmul_op(MPSGraph *g, MPSGraphTensor *a, MPSGraphTensor *b, BOOL ta, BOOL tb, NSString *name) {
    MPSShape *sa = a.shape, *sb = b.shape;
    if (ta && sa.count >= 2) { NSMutableArray *s = [sa mutableCopy]; [s exchangeObjectAtIndex:s.count - 1 withObjectAtIndex:s.count - 2]; sa = s; }
    if (tb && sb.count >= 2) { NSMutableArray *s = [sb mutableCopy]; [s exchangeObjectAtIndex:s.count - 1 withObjectAtIndex:s.count - 2]; sb = s; }
    return [g _isim_op1:@"matrixMultiplication" inputs:@[ a, b ] type:a.dataType shape:matmul_shape(sa, sb) name:name
                   eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) { return @[ matmul(in[0], in[1], ta, tb) ]; }
                   grad:^NSArray *(MPSGraph *gr, MPSGraphOperation *op, NSArray *og) {
        MPSGraphTensor *A = op.inputTensors[0], *B = op.inputTensors[1], *G = og[0];
        /* dA = G B^T (or its transpose), dB = A^T G */
        MPSGraphTensor *da = ta ? matmul_op(gr, B, G, tb, YES, nil) : matmul_op(gr, G, B, NO, !tb, nil);
        MPSGraphTensor *db = tb ? matmul_op(gr, G, A, YES, ta, nil) : matmul_op(gr, A, G, !ta, NO, nil);
        return @[ mg_sum_to_shape_of(gr, da, A), mg_sum_to_shape_of(gr, db, B) ];
    }];
}
@implementation MPSGraph (MatrixMultiplicationOps)
- (MPSGraphTensor *)matrixMultiplicationWithPrimaryTensor:(MPSGraphTensor *)a secondaryTensor:(MPSGraphTensor *)b name:(NSString *)name {
    return matmul_op(self, a, b, NO, NO, name);
}
@end

/* ---------------- reductions ---------------- */
typedef enum { R_SUM, R_MAX, R_MIN, R_PROD, R_ARGMAX, R_ARGMIN, R_AND, R_OR, R_MEAN } red;
/* reduces the axes (a mask), keeping them with length 1 */
static MGValue *reduce(MGValue *x, const BOOL *mask, red op) {
    NSUInteger od[MG_MAX_RANK], count = 1;
    for (NSUInteger i = 0; i < x->rank; i++) { od[i] = mask[i] ? 1 : x->dims[i]; if (mask[i]) count *= x->dims[i]; }
    MGValue *out = [MGValue valueWithDims:od rank:x->rank];
    double init = op == R_MAX || op == R_ARGMAX ? -INFINITY : op == R_MIN || op == R_ARGMIN ? INFINITY : op == R_PROD || op == R_AND ? 1 : 0;
    double *best = malloc(sizeof(double) * (out->n + 1));
    for (NSUInteger i = 0; i < out->n; i++) { out->d[i] = op == R_ARGMAX || op == R_ARGMIN ? 0 : init; best[i] = init; }
    NSUInteger idx[MG_MAX_RANK] = { 0 }, ost[MG_MAX_RANK];
    strides_of(od, x->rank, ost);
    NSInteger axis = -1;                                  /* the arg ops' axis */
    for (NSUInteger i = 0; i < x->rank; i++) if (mask[i]) axis = (NSInteger)i;
    for (NSUInteger e = 0; e < x->n; e++) {
        NSUInteger o = 0;
        for (NSUInteger i = 0; i < x->rank; i++) o += (mask[i] ? 0 : idx[i]) * ost[i];
        double v = x->d[e];
        switch (op) {
        case R_SUM: case R_MEAN: out->d[o] += v; break;
        case R_MAX: out->d[o] = isnan(out->d[o]) || v > out->d[o] ? v : out->d[o]; break;
        case R_MIN: out->d[o] = v < out->d[o] ? v : out->d[o]; break;
        case R_PROD: out->d[o] *= v; break;
        case R_AND: out->d[o] = out->d[o] != 0 && v != 0; break;
        case R_OR: out->d[o] = out->d[o] != 0 || v != 0; break;
        case R_ARGMAX: if (v > best[o]) { best[o] = v; out->d[o] = axis >= 0 ? (double)idx[axis] : 0; } break;
        case R_ARGMIN: if (v < best[o]) { best[o] = v; out->d[o] = axis >= 0 ? (double)idx[axis] : 0; } break;
        }
        next_index(idx, x->dims, x->rank);
    }
    if (op == R_MEAN && count) for (NSUInteger i = 0; i < out->n; i++) out->d[i] /= (double)count;
    free(best);
    return out;
}
static void axes_mask(NSArray<NSNumber *> *axes, NSUInteger rank, BOOL *mask) {
    for (NSUInteger i = 0; i < MG_MAX_RANK; i++) mask[i] = axes == nil;      /* nil: every axis */
    for (NSNumber *a in axes) { NSInteger k = mg_axis(a.integerValue, rank); if (k >= 0 && k < (NSInteger)rank) mask[k] = YES; }
}
static MPSShape *reduced_shape(MPSShape *s, NSArray<NSNumber *> *axes) {
    if (!s) return nil;
    NSMutableArray *o = [s mutableCopy];
    BOOL mask[MG_MAX_RANK];
    axes_mask(axes, s.count, mask);
    for (NSUInteger i = 0; i < s.count; i++) if (mask[i]) o[i] = @1;
    return o;
}
static MPSGraphTensor *reduction(MPSGraph *g, NSString *kind, MPSGraphTensor *x, NSArray<NSNumber *> *axes, red op, NSString *name) {
    MPSDataType t = op == R_ARGMAX || op == R_ARGMIN ? MPSDataTypeInt32 : op == R_AND || op == R_OR ? MPSDataTypeBool : x.dataType;
    MGGrad grad = nil;
    if (op == R_SUM || op == R_MEAN)
        grad = ^NSArray *(MPSGraph *gr, MPSGraphOperation *o, NSArray *og) {
            MPSGraphTensor *X = o.inputTensors[0], *G = mg_broadcast_like(gr, og[0], X);
            if (op == R_MEAN) G = [gr _isim_op1:@"meanGradient" inputs:@[ G, o.outputTensors[0] ] type:G.dataType shape:X.shape name:nil
                                          eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
                    MGValue *out = [MGValue valueLike:in[0]];
                    double scale = in[1]->n ? (double)in[1]->n / (double)in[0]->n : 0;
                    for (NSUInteger i = 0; i < out->n; i++) out->d[i] = in[0]->d[i] * scale;
                    return @[ out ];
                } grad:nil];
            return @[ G ];
        };
    else if (op == R_MAX || op == R_MIN || op == R_PROD)
        grad = ^NSArray *(MPSGraph *gr, MPSGraphOperation *o, NSArray *og) {
            MPSGraphTensor *X = o.inputTensors[0], *G = mg_broadcast_like(gr, og[0], X), *Y = mg_broadcast_like(gr, o.outputTensors[0], X);
            return @[ ewop(gr, @"reductionGradient", @[ G, X, Y ], X.dataType, nil, ^double(const double *v) {
                return op == R_PROD ? (v[1] != 0 ? v[0] * v[2] / v[1] : 0) : (v[1] == v[2] ? v[0] : 0);
            }, nil) ];
        };
    return [g _isim_op1:kind inputs:@[ x ] type:t shape:reduced_shape(x.shape, axes) name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        BOOL mask[MG_MAX_RANK];
        axes_mask(axes, in[0]->rank, mask);
        return @[ reduce(in[0], mask, op) ];
    } grad:grad];
}
@implementation MPSGraph (ReductionOps)
#define RED(SEL, KIND, OP) \
    - (MPSGraphTensor *)SEL##WithTensor:(MPSGraphTensor *)t axis:(NSInteger)axis name:(NSString *)name { return reduction(self, @KIND, t, @[ @(axis) ], OP, name); } \
    - (MPSGraphTensor *)SEL##WithTensor:(MPSGraphTensor *)t axes:(NSArray<NSNumber *> *)axes name:(NSString *)name { return reduction(self, @KIND, t, axes, OP, name); }
RED(reductionSum, "reductionSum", R_SUM)
RED(reductionMaximum, "reductionMaximum", R_MAX)
RED(reductionMinimum, "reductionMinimum", R_MIN)
RED(reductionProduct, "reductionProduct", R_PROD)
RED(reductionAnd, "reductionAnd", R_AND)
RED(reductionOr, "reductionOr", R_OR)
- (MPSGraphTensor *)reductionArgMaximumWithTensor:(MPSGraphTensor *)t axis:(NSInteger)axis name:(NSString *)name { return reduction(self, @"reductionArgMaximum", t, @[ @(axis) ], R_ARGMAX, name); }
- (MPSGraphTensor *)reductionArgMinimumWithTensor:(MPSGraphTensor *)t axis:(NSInteger)axis name:(NSString *)name { return reduction(self, @"reductionArgMinimum", t, @[ @(axis) ], R_ARGMIN, name); }
@end

@implementation MPSGraph (NormalizationOps)
- (MPSGraphTensor *)meanOfTensor:(MPSGraphTensor *)t axes:(NSArray<NSNumber *> *)axes name:(NSString *)name { return reduction(self, @"mean", t, axes, R_MEAN, name); }
- (MPSGraphTensor *)varianceOfTensor:(MPSGraphTensor *)t meanTensor:(MPSGraphTensor *)mean axes:(NSArray<NSNumber *> *)axes name:(NSString *)name {
    MPSGraphTensor *d = [self subtractionWithPrimaryTensor:t secondaryTensor:mean name:nil];
    return [self meanOfTensor:[self squareWithTensor:d name:nil] axes:axes name:name];
}
- (MPSGraphTensor *)varianceOfTensor:(MPSGraphTensor *)t axes:(NSArray<NSNumber *> *)axes name:(NSString *)name {
    return [self varianceOfTensor:t meanTensor:[self meanOfTensor:t axes:axes name:nil] axes:axes name:name];
}
- (MPSGraphTensor *)normalizationWithTensor:(MPSGraphTensor *)x meanTensor:(MPSGraphTensor *)mean varianceTensor:(MPSGraphTensor *)var
                                gammaTensor:(MPSGraphTensor *)gamma betaTensor:(MPSGraphTensor *)beta epsilon:(float)eps name:(NSString *)name {
    MPSGraphTensor *one = [self constantWithScalar:1 dataType:x.dataType], *zero = [self constantWithScalar:0 dataType:x.dataType];
    MPSGraphTensor *G = gamma ?: one, *B = beta ?: zero;
    return ewop(self, @"normalization", @[ x, mean, var, G, B ], x.dataType, name, ^double(const double *v) {
        return (v[0] - v[1]) / sqrt(v[2] + eps) * v[3] + v[4];
    }, ^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) {
        NSArray *in = @[ og[0], op.inputTensors[0], op.inputTensors[1], op.inputTensors[2], op.inputTensors[3] ];
        MPSDataType t = op.inputTensors[0].dataType;
        mg_fn fx = ^double(const double *v) { return v[0] * v[4] / sqrt(v[3] + eps); };
        mg_fn fm = ^double(const double *v) { return -v[0] * v[4] / sqrt(v[3] + eps); };
        mg_fn fv = ^double(const double *v) { return v[0] * v[4] * (v[1] - v[2]) * -0.5 * pow(v[3] + eps, -1.5); };
        mg_fn fg = ^double(const double *v) { return v[0] * (v[1] - v[2]) / sqrt(v[3] + eps); };
        return @[ mg_sum_to_shape_of(g, ewop(g, @"normalizationGradient", in, t, nil, fx, nil), op.inputTensors[0]),
                  mg_sum_to_shape_of(g, ewop(g, @"normalizationGradient", in, t, nil, fm, nil), op.inputTensors[1]),
                  mg_sum_to_shape_of(g, ewop(g, @"normalizationGradient", in, t, nil, fv, nil), op.inputTensors[2]),
                  mg_sum_to_shape_of(g, ewop(g, @"normalizationGradient", in, t, nil, fg, nil), op.inputTensors[3]),
                  mg_sum_to_shape_of(g, og[0], op.inputTensors[4]) ];
    });
}
@end

/* ---------------- activations ---------------- */
static MGValue *softmax(MGValue *x, NSInteger axis) {
    MGValue *out = [MGValue valueLike:x];
    NSInteger ax = mg_axis(axis, x->rank);
    if (ax < 0 || ax >= (NSInteger)x->rank) { memcpy(out->d, x->d, x->n * sizeof(double)); return out; }
    NSUInteger st[MG_MAX_RANK], len = x->dims[ax];
    strides_of(x->dims, x->rank, st);
    NSUInteger stride = st[ax], outer = x->n / MAX(len * stride, (NSUInteger)1);
    for (NSUInteger o = 0; o < outer; o++)
        for (NSUInteger in = 0; in < stride; in++) {
            NSUInteger base = o * len * stride + in;
            double mx = -INFINITY, sum = 0;
            for (NSUInteger k = 0; k < len; k++) mx = fmax(mx, x->d[base + k * stride]);
            for (NSUInteger k = 0; k < len; k++) sum += out->d[base + k * stride] = exp(x->d[base + k * stride] - mx);
            for (NSUInteger k = 0; k < len; k++) out->d[base + k * stride] /= sum;
        }
    return out;
}
/* y * (g - sum(g * y) along the axis) */
static MGValue *softmax_backward(MGValue *gv, MGValue *y, NSInteger axis) {
    MGValue *out = [MGValue valueLike:y];
    NSInteger ax = mg_axis(axis, y->rank);
    NSUInteger st[MG_MAX_RANK], len = y->dims[ax];
    strides_of(y->dims, y->rank, st);
    NSUInteger stride = st[ax], outer = y->n / MAX(len * stride, (NSUInteger)1);
    for (NSUInteger o = 0; o < outer; o++)
        for (NSUInteger in = 0; in < stride; in++) {
            NSUInteger base = o * len * stride + in;
            double dot = 0;
            for (NSUInteger k = 0; k < len; k++) dot += gv->d[(base + k * stride) % MAX(gv->n, (NSUInteger)1)] * y->d[base + k * stride];
            for (NSUInteger k = 0; k < len; k++) {
                NSUInteger e = base + k * stride;
                out->d[e] = y->d[e] * (gv->d[e % MAX(gv->n, (NSUInteger)1)] - dot);
            }
        }
    return out;
}
@implementation MPSGraph (ActivationOps)
- (MPSGraphTensor *)reLUWithTensor:(MPSGraphTensor *)t name:(NSString *)name { return unary(self, @"reLU", t, name, ^double(double x) { return x > 0 ? x : 0; }, D(x > 0 ? 1 : 0), t.dataType); }
- (MPSGraphTensor *)reLUGradientWithIncomingGradient:(MPSGraphTensor *)g sourceTensor:(MPSGraphTensor *)x name:(NSString *)name {
    return ewop(self, @"reLUGradient", @[ g, x ], g.dataType, name, ^double(const double *v) { return v[1] > 0 ? v[0] : 0; }, nil);
}
- (MPSGraphTensor *)sigmoidWithTensor:(MPSGraphTensor *)t name:(NSString *)name { return unary(self, @"sigmoid", t, name, ^double(double x) { return 1 / (1 + exp(-x)); }, D(y * (1 - y)), t.dataType); }
- (MPSGraphTensor *)sigmoidGradientWithIncomingGradient:(MPSGraphTensor *)g sourceTensor:(MPSGraphTensor *)x name:(NSString *)name {
    return ewop(self, @"sigmoidGradient", @[ g, x ], g.dataType, name, ^double(const double *v) { double s = 1 / (1 + exp(-v[1])); return v[0] * s * (1 - s); }, nil);
}
- (MPSGraphTensor *)leakyReLUWithTensor:(MPSGraphTensor *)t alpha:(double)alpha name:(NSString *)name {
    return unary(self, @"leakyReLU", t, name, ^double(double x) { return x > 0 ? x : alpha * x; }, D(x > 0 ? 1 : alpha), t.dataType);
}
- (MPSGraphTensor *)leakyReLUWithTensor:(MPSGraphTensor *)t alphaTensor:(MPSGraphTensor *)a name:(NSString *)name {
    return binary(self, @"leakyReLU", t, a, name, ^double(double x, double al) { return x > 0 ? x : al * x; }, D2(x > 0 ? 1 : z), D2(x > 0 ? 0 : x), t.dataType);
}
- (MPSGraphTensor *)leakyReLUGradientWithIncomingGradient:(MPSGraphTensor *)g sourceTensor:(MPSGraphTensor *)x alphaTensor:(MPSGraphTensor *)a name:(NSString *)name {
    return ewop(self, @"leakyReLUGradient", @[ g, x, a ], g.dataType, name, ^double(const double *v) { return v[1] > 0 ? v[0] : v[0] * v[2]; }, nil);
}
static MPSGraphTensor *softmax_grad_op(MPSGraph *g, MPSGraphTensor *grad, MPSGraphTensor *y, NSInteger axis, NSString *name) {
    return [g _isim_op1:@"softMaxGradient" inputs:@[ grad, y ] type:y.dataType shape:y.shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        return @[ softmax_backward(in[0], in[1], axis) ];
    } grad:nil];
}
- (MPSGraphTensor *)softMaxWithTensor:(MPSGraphTensor *)t axis:(NSInteger)axis name:(NSString *)name {
    return [self _isim_op1:@"softMax" inputs:@[ t ] type:t.dataType shape:t.shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        return @[ softmax(in[0], axis) ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) { return @[ softmax_grad_op(g, og[0], op.outputTensors[0], axis, nil) ]; }];
}
- (MPSGraphTensor *)softMaxGradientWithIncomingGradient:(MPSGraphTensor *)grad sourceTensor:(MPSGraphTensor *)source axis:(NSInteger)axis name:(NSString *)name {
    return softmax_grad_op(self, grad, [self softMaxWithTensor:source axis:axis name:nil], axis, name);
}
@end

/* ---------------- shapes ---------------- */
/* the dimensions of a shape with one -1 resolved for count elements */
static BOOL resolve_shape(const double *s, NSUInteger rank, NSUInteger count, NSUInteger *dims) {
    NSInteger unknown = -1; NSUInteger known_n = 1;
    for (NSUInteger i = 0; i < rank; i++) {
        if (s[i] < 0) { unknown = (NSInteger)i; dims[i] = 1; }
        else { dims[i] = (NSUInteger)s[i]; known_n *= dims[i]; }
    }
    if (unknown >= 0) dims[unknown] = known_n ? count / known_n : 0;
    NSUInteger n = 1;
    for (NSUInteger i = 0; i < rank; i++) n *= dims[i];
    return n == count;
}
static MGValue *permute(MGValue *x, const NSUInteger *perm) {
    NSUInteger od[MG_MAX_RANK], st[MG_MAX_RANK], idx[MG_MAX_RANK] = { 0 };
    for (NSUInteger i = 0; i < x->rank; i++) od[i] = x->dims[perm[i]];
    strides_of(x->dims, x->rank, st);
    MGValue *out = [MGValue valueWithDims:od rank:x->rank];
    for (NSUInteger e = 0; e < out->n; e++) {
        NSUInteger off = 0;
        for (NSUInteger i = 0; i < x->rank; i++) off += idx[i] * st[perm[i]];
        out->d[e] = x->d[off];
        next_index(idx, od, x->rank);
    }
    return out;
}
static MPSGraphTensor *permute_op(MPSGraph *g, MPSGraphTensor *t, NSArray<NSNumber *> *perm, NSString *name) {
    MPSShape *s = nil;
    if (t.shape && t.shape.count == perm.count) { NSMutableArray *m = [NSMutableArray array]; for (NSNumber *p in perm) [m addObject:t.shape[p.unsignedIntegerValue]]; s = m; }
    return [g _isim_op1:@"transpose" inputs:@[ t ] type:t.dataType shape:s name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        NSUInteger p[MG_MAX_RANK];
        for (NSUInteger i = 0; i < in[0]->rank; i++) p[i] = i < perm.count ? perm[i].unsignedIntegerValue : i;
        return @[ permute(in[0], p) ];
    } grad:^NSArray *(MPSGraph *gr, MPSGraphOperation *op, NSArray *og) {
        NSMutableArray *inv = [NSMutableArray arrayWithCapacity:perm.count];
        for (NSUInteger i = 0; i < perm.count; i++) [inv addObject:@0];
        for (NSUInteger i = 0; i < perm.count; i++) inv[perm[i].unsignedIntegerValue] = @(i);
        return @[ permute_op(gr, og[0], inv, nil) ];
    }];
}
/* a box of x: start, end (exclusive) and stride per dimension */
typedef struct { NSInteger start[MG_MAX_RANK], stride[MG_MAX_RANK]; NSUInteger len[MG_MAX_RANK]; } box;
static MGValue *slice_box(MGValue *x, const box *b) {
    MGValue *out = [MGValue valueWithDims:b->len rank:x->rank];
    NSUInteger st[MG_MAX_RANK], idx[MG_MAX_RANK] = { 0 };
    strides_of(x->dims, x->rank, st);
    for (NSUInteger e = 0; e < out->n; e++) {
        NSInteger off = 0;
        for (NSUInteger i = 0; i < x->rank; i++) off += (b->start[i] + (NSInteger)idx[i] * b->stride[i]) * (NSInteger)st[i];
        out->d[e] = x->d[off];
        next_index(idx, b->len, x->rank);
    }
    return out;
}
static void unslice_box(MGValue *dst, MGValue *g, const box *b) {   /* adds g into the box of dst */
    NSUInteger st[MG_MAX_RANK], idx[MG_MAX_RANK] = { 0 };
    strides_of(dst->dims, dst->rank, st);
    for (NSUInteger e = 0; e < g->n; e++) {
        NSInteger off = 0;
        for (NSUInteger i = 0; i < dst->rank; i++) off += (b->start[i] + (NSInteger)idx[i] * b->stride[i]) * (NSInteger)st[i];
        dst->d[off] += g->d[e];
        next_index(idx, b->len, dst->rank);
    }
}
/* the box of x for starts / ends / strides (Python-style negatives; clamped) */
typedef void (^box_fn)(MGValue *x, box *b);
static MPSGraphTensor *slice_op(MPSGraph *g, MPSGraphTensor *t, box_fn make, MPSShape *shape, NSString *name) {
    return [g _isim_op1:@"slice" inputs:@[ t ] type:t.dataType shape:shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        box b; make(in[0], &b);
        return @[ slice_box(in[0], &b) ];
    } grad:^NSArray *(MPSGraph *gr, MPSGraphOperation *op, NSArray *og) {
        return @[ [gr _isim_op1:@"sliceGradient" inputs:@[ og[0], op.inputTensors[0] ] type:t.dataType shape:t.shape name:nil
                           eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
            MGValue *out = [MGValue valueLike:in[1]];
            box b; make(in[1], &b);
            unslice_box(out, in[0], &b);
            return @[ out ];
        } grad:nil] ];
    }];
}
static MPSGraphTensor *reshape_dims(MPSGraph *g, NSString *kind, MPSGraphTensor *t, MPSShape *shape,
                                    void (^dims)(MGValue *x, NSUInteger *out, NSUInteger *rank), NSString *name);
/* nil axes: every axis */
static MPSGraphTensor *reverse_op(MPSGraph *self, MPSGraphTensor *t, NSArray<NSNumber *> *_Nullable axes, NSString *name) {
    return [self _isim_op1:@"reverse" inputs:@[ t ] type:t.dataType shape:t.shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *x = in[0];
        box b;
        BOOL mask[MG_MAX_RANK];
        axes_mask(axes, x->rank, mask);
        for (NSUInteger i = 0; i < x->rank; i++) { b.len[i] = x->dims[i]; b.start[i] = mask[i] ? (NSInteger)x->dims[i] - 1 : 0; b.stride[i] = mask[i] ? -1 : 1; }
        return @[ slice_box(x, &b) ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) { return @[ reverse_op(g, og[0], axes, nil) ]; }];
}
/* nil axes: every axis of length 1 */
static MPSGraphTensor *squeeze_op(MPSGraph *self, MPSGraphTensor *t, NSArray<NSNumber *> *_Nullable axes, NSString *name) {
    return reshape_dims(self, @"squeeze", t, nil, ^(MGValue *x, NSUInteger *d, NSUInteger *r) {
        BOOL drop[MG_MAX_RANK] = { 0 };
        if (axes) for (NSNumber *a in axes) { NSInteger ax = mg_axis(a.integerValue, x->rank); if (ax >= 0 && ax < (NSInteger)x->rank && x->dims[ax] == 1) drop[ax] = YES; }
        else for (NSUInteger i = 0; i < x->rank; i++) drop[i] = x->dims[i] == 1;
        *r = 0;
        for (NSUInteger i = 0; i < x->rank; i++) if (!drop[i]) d[(*r)++] = x->dims[i];
    }, name);
}
@implementation MPSGraph (TensorShapeOps)
- (MPSGraphTensor *)reshapeTensor:(MPSGraphTensor *)t withShape:(MPSShape *)shape name:(NSString *)name {
    NSUInteger rank = shape.count;
    double *s = malloc(sizeof(double) * (rank + 1));
    for (NSUInteger i = 0; i < rank; i++) s[i] = shape[i].doubleValue;
    NSData *sd = [NSData dataWithBytesNoCopy:s length:sizeof(double) * (rank + 1) freeWhenDone:YES];
    return [self _isim_op1:@"reshape" inputs:@[ t ] type:t.dataType shape:known(shape) ? shape : nil name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        NSUInteger dims[MG_MAX_RANK];
        if (!resolve_shape(sd.bytes, rank, in[0]->n, dims)) { NSLog(@"isim MPSGraph: cannot reshape %lu elements to %@", (unsigned long)in[0]->n, shape); return @[ [MGValue scalar:NAN] ]; }
        MGValue *out = [MGValue valueWithDims:dims rank:rank];
        memcpy(out->d, in[0]->d, in[0]->n * sizeof(double));
        return @[ out ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) { return @[ mg_reshape_like(g, og[0], op.inputTensors[0]) ]; }];
}
- (MPSGraphTensor *)reshapeTensor:(MPSGraphTensor *)t withShapeTensor:(MPSGraphTensor *)st name:(NSString *)name {
    return [self _isim_op1:@"reshape" inputs:@[ t, st ] type:t.dataType shape:nil name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        NSUInteger dims[MG_MAX_RANK], rank = MIN(in[1]->n, (NSUInteger)MG_MAX_RANK);
        if (!resolve_shape(in[1]->d, rank, in[0]->n, dims)) return @[ [MGValue scalar:NAN] ];
        MGValue *out = [MGValue valueWithDims:dims rank:rank];
        memcpy(out->d, in[0]->d, in[0]->n * sizeof(double));
        return @[ out ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) { return @[ mg_reshape_like(g, og[0], op.inputTensors[0]), [NSNull null] ]; }];
}
- (MPSGraphTensor *)transposeTensor:(MPSGraphTensor *)t dimension:(NSUInteger)a withDimension:(NSUInteger)b name:(NSString *)name {
    NSUInteger rank = t.shape ? t.shape.count : MAX(a, b) + 1;
    NSMutableArray *perm = [NSMutableArray array];
    for (NSUInteger i = 0; i < rank; i++) [perm addObject:@(i == a ? b : i == b ? a : i)];
    return permute_op(self, t, perm, name);
}
- (MPSGraphTensor *)transposeTensor:(MPSGraphTensor *)t permutation:(NSArray<NSNumber *> *)perm name:(NSString *)name { return permute_op(self, t, perm, name); }
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)t dimension:(NSUInteger)dim start:(NSInteger)start length:(NSInteger)length name:(NSString *)name {
    MPSShape *shape = nil;
    if (t.shape && dim < t.shape.count) { NSMutableArray *s = [t.shape mutableCopy]; s[dim] = @(length); shape = s; }
    return slice_op(self, t, ^(MGValue *x, box *b) {
        for (NSUInteger i = 0; i < x->rank; i++) { b->start[i] = 0; b->stride[i] = 1; b->len[i] = x->dims[i]; }
        if (dim < x->rank) {
            NSInteger s0 = start < 0 ? start + (NSInteger)x->dims[dim] : start;
            s0 = MAX(MIN(s0, (NSInteger)x->dims[dim]), 0);
            b->start[dim] = s0; b->len[dim] = (NSUInteger)MAX(MIN(length, (NSInteger)x->dims[dim] - s0), 0);
        }
    }, shape, name);
}
- (MPSGraphTensor *)sliceTensor:(MPSGraphTensor *)t starts:(NSArray<NSNumber *> *)starts ends:(NSArray<NSNumber *> *)ends strides:(NSArray<NSNumber *> *)strides
                           name:(NSString *)name {
    return slice_op(self, t, ^(MGValue *x, box *b) {
        for (NSUInteger i = 0; i < x->rank; i++) {
            NSInteger n = (NSInteger)x->dims[i], st = i < strides.count ? strides[i].integerValue : 1;
            NSInteger s0 = i < starts.count ? starts[i].integerValue : 0, e0 = i < ends.count ? ends[i].integerValue : n;
            if (s0 < 0) s0 += n; if (e0 < 0) e0 += n;
            if (st == 0) st = 1;
            if (st > 0) { s0 = MAX(MIN(s0, n), 0); e0 = MAX(MIN(e0, n), 0); b->len[i] = e0 > s0 ? (NSUInteger)((e0 - s0 + st - 1) / st) : 0; }
            else { s0 = MAX(MIN(s0, n - 1), -1); e0 = MAX(MIN(e0, n - 1), -1); b->len[i] = s0 > e0 ? (NSUInteger)((s0 - e0 - st - 1) / -st) : 0; }
            b->start[i] = s0; b->stride[i] = st;
        }
    }, nil, name);
}
- (MPSGraphTensor *)concatTensors:(NSArray<MPSGraphTensor *> *)tensors dimension:(NSInteger)dim name:(NSString *)name {
    MPSShape *shape = nil;
    MPSShape *first = tensors.firstObject.shape;
    if (first && known(first)) {
        NSInteger d = mg_axis(dim, first.count), total = 0;
        for (MPSGraphTensor *t in tensors) { if (!known(t.shape) || d < 0 || d >= (NSInteger)t.shape.count) { total = -1; break; } total += t.shape[d].integerValue; }
        if (total >= 0) { NSMutableArray *s = [first mutableCopy]; s[d] = @(total); shape = s; }
    }
    return [self _isim_op1:@"concat" inputs:tensors type:tensors.firstObject.dataType shape:shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *f = in[0];
        NSInteger d = mg_axis(dim, f->rank);
        NSUInteger dims[MG_MAX_RANK];
        memcpy(dims, f->dims, sizeof(NSUInteger) * f->rank);
        dims[d] = 0;
        for (MGValue *v in in) dims[d] += v->dims[d];
        MGValue *out = [MGValue valueWithDims:dims rank:f->rank];
        NSUInteger offset = 0;
        for (MGValue *v in in) {
            box b;
            for (NSUInteger i = 0; i < f->rank; i++) { b.start[i] = 0; b.stride[i] = 1; b.len[i] = v->dims[i]; }
            b.start[d] = (NSInteger)offset;
            unslice_box(out, v, &b);
            offset += v->dims[d];
        }
        return @[ out ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) {
        NSMutableArray *grads = [NSMutableArray array];
        for (NSUInteger k = 0; k < op.inputTensors.count; k++) {
            NSArray *ins = op.inputTensors;
            [grads addObject:[g _isim_op1:@"concatGradient" inputs:[@[ og[0] ] arrayByAddingObjectsFromArray:ins] type:((MPSGraphTensor *)ins[k]).dataType shape:((MPSGraphTensor *)ins[k]).shape name:nil
                                     eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
                MGValue *G = in[0];
                NSInteger d = mg_axis(dim, G->rank);
                NSUInteger offset = 0;
                for (NSUInteger j = 0; j < k; j++) offset += in[1 + j]->dims[d];
                box b;
                for (NSUInteger i = 0; i < G->rank; i++) { b.start[i] = 0; b.stride[i] = 1; b.len[i] = in[1 + k]->dims[i]; }
                b.start[d] = (NSInteger)offset;
                return @[ slice_box(G, &b) ];
            } grad:nil]];
        }
        return grads;
    }];
}
- (MPSGraphTensor *)concatTensor:(MPSGraphTensor *)a withTensor:(MPSGraphTensor *)b dimension:(NSInteger)dim name:(NSString *)name {
    return [self concatTensors:@[ a, b ] dimension:dim name:name];
}
- (MPSGraphTensor *)broadcastTensor:(MPSGraphTensor *)t toShape:(MPSShape *)shape name:(NSString *)name {
    return [self _isim_op1:@"broadcast" inputs:@[ t ] type:t.dataType shape:shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *r = mg_value_of_shape(shape), *v = in[0];
        NSUInteger idx[MG_MAX_RANK] = { 0 };
        for (NSUInteger i = 0; i < r->n; i++) { r->d[i] = v->d[mg_bindex(v, idx, r->rank)]; next_index(idx, r->dims, r->rank); }
        return @[ r ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) { return @[ mg_sum_to_shape_of(g, og[0], op.inputTensors[0]) ]; }];
}
- (MPSGraphTensor *)shapeOfTensor:(MPSGraphTensor *)t name:(NSString *)name {
    return [self _isim_op1:@"shapeOf" inputs:@[ t ] type:MPSDataTypeInt32 shape:t.shape ? @[ @(t.shape.count) ] : nil name:name
                      eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        NSUInteger r = in[0]->rank;
        MGValue *out = [MGValue valueWithDims:&r rank:1];
        for (NSUInteger i = 0; i < r; i++) out->d[i] = in[0]->dims[i];
        return @[ out ];
    } grad:nil];
}
- (MPSGraphTensor *)castTensor:(MPSGraphTensor *)t toType:(MPSDataType)type name:(NSString *)name {
    return [self _isim_op1:@"cast" inputs:@[ t ] type:type shape:t.shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *out = [MGValue valueLike:in[0]];
        memcpy(out->d, in[0]->d, in[0]->n * sizeof(double));
        return @[ out ];
    } grad:mg_is_float(type) && mg_is_float(t.dataType) ? ^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) { return @[ og[0] ]; } : nil];
}
static MPSGraphTensor *reshape_dims(MPSGraph *g, NSString *kind, MPSGraphTensor *t, MPSShape *shape, void (^dims)(MGValue *x, NSUInteger *out, NSUInteger *rank),
                                    NSString *name) {
    return [g _isim_op1:kind inputs:@[ t ] type:t.dataType shape:shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        NSUInteger d[MG_MAX_RANK], r = 0;
        dims(in[0], d, &r);
        MGValue *out = [MGValue valueWithDims:d rank:r];
        memcpy(out->d, in[0]->d, MIN(in[0]->n, out->n) * sizeof(double));
        return @[ out ];
    } grad:^NSArray *(MPSGraph *gr, MPSGraphOperation *op, NSArray *og) { return @[ mg_reshape_like(gr, og[0], op.inputTensors[0]) ]; }];
}
- (MPSGraphTensor *)expandDimsOfTensor:(MPSGraphTensor *)t axes:(NSArray<NSNumber *> *)axes name:(NSString *)name {
    return reshape_dims(self, @"expandDims", t, nil, ^(MGValue *x, NSUInteger *d, NSUInteger *r) {
        NSUInteger rank = x->rank + axes.count, k = 0;
        BOOL ins[MG_MAX_RANK] = { 0 };
        for (NSNumber *a in axes) { NSInteger ax = mg_axis(a.integerValue, rank); if (ax >= 0 && ax < MG_MAX_RANK) ins[ax] = YES; }
        for (NSUInteger i = 0; i < rank && i < MG_MAX_RANK; i++) d[i] = ins[i] ? 1 : x->dims[k++];
        *r = MIN(rank, (NSUInteger)MG_MAX_RANK);
    }, name);
}
- (MPSGraphTensor *)expandDimsOfTensor:(MPSGraphTensor *)t axis:(NSInteger)axis name:(NSString *)name { return [self expandDimsOfTensor:t axes:@[ @(axis) ] name:name]; }
- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)t axes:(NSArray<NSNumber *> *)axes name:(NSString *)name { return squeeze_op(self, t, axes, name); }
- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)t name:(NSString *)name { return squeeze_op(self, t, nil, name); }
- (MPSGraphTensor *)squeezeTensor:(MPSGraphTensor *)t axis:(NSInteger)axis name:(NSString *)name { return [self squeezeTensor:t axes:@[ @(axis) ] name:name]; }
- (MPSGraphTensor *)flatten2DTensor:(MPSGraphTensor *)t axis:(NSInteger)axis name:(NSString *)name {
    return reshape_dims(self, @"flatten2D", t, nil, ^(MGValue *x, NSUInteger *d, NSUInteger *r) {
        NSInteger ax = mg_axis(axis, x->rank);
        d[0] = 1; d[1] = 1;
        for (NSUInteger i = 0; i < x->rank; i++) d[(NSInteger)i < ax ? 0 : 1] *= x->dims[i];
        *r = 2;
    }, name);
}
- (MPSGraphTensor *)tileTensor:(MPSGraphTensor *)t withMultiplier:(MPSShape *)mult name:(NSString *)name {
    return [self _isim_op1:@"tile" inputs:@[ t ] type:t.dataType shape:nil name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *x = in[0];
        NSUInteger d[MG_MAX_RANK], idx[MG_MAX_RANK] = { 0 }, st[MG_MAX_RANK];
        for (NSUInteger i = 0; i < x->rank; i++) d[i] = x->dims[i] * (i < mult.count ? mult[i].unsignedIntegerValue : 1);
        strides_of(x->dims, x->rank, st);
        MGValue *out = [MGValue valueWithDims:d rank:x->rank];
        for (NSUInteger e = 0; e < out->n; e++) {
            NSUInteger off = 0;
            for (NSUInteger i = 0; i < x->rank; i++) off += (idx[i] % x->dims[i]) * st[i];
            out->d[e] = x->d[off];
            next_index(idx, d, x->rank);
        }
        return @[ out ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) {
        return @[ [g _isim_op1:@"tileGradient" inputs:@[ og[0], op.inputTensors[0] ] type:t.dataType shape:t.shape name:nil eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
            MGValue *G = in[0], *x = in[1], *out = [MGValue valueLike:x];
            NSUInteger idx[MG_MAX_RANK] = { 0 }, st[MG_MAX_RANK];
            strides_of(x->dims, x->rank, st);
            for (NSUInteger e = 0; e < G->n; e++) {
                NSUInteger off = 0;
                for (NSUInteger i = 0; i < x->rank; i++) off += (idx[i] % x->dims[i]) * st[i];
                out->d[off] += G->d[e];
                next_index(idx, G->dims, G->rank);
            }
            return @[ out ];
        } grad:nil] ];
    }];
}
- (MPSGraphTensor *)padTensor:(MPSGraphTensor *)t withPaddingMode:(MPSGraphPaddingMode)mode leftPadding:(MPSShape *)left rightPadding:(MPSShape *)right
                constantValue:(double)c name:(NSString *)name {
    return [self _isim_op1:@"pad" inputs:@[ t ] type:t.dataType shape:nil name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *x = in[0];
        NSUInteger d[MG_MAX_RANK], idx[MG_MAX_RANK] = { 0 }, st[MG_MAX_RANK];
        NSInteger L[MG_MAX_RANK];
        for (NSUInteger i = 0; i < x->rank; i++) {
            L[i] = i < left.count ? left[i].integerValue : 0;
            d[i] = (NSUInteger)((NSInteger)x->dims[i] + L[i] + (i < right.count ? right[i].integerValue : 0));
        }
        strides_of(x->dims, x->rank, st);
        MGValue *out = [MGValue valueWithDims:d rank:x->rank];
        for (NSUInteger e = 0; e < out->n; e++) {
            NSInteger off = 0; BOOL outside = NO;
            for (NSUInteger i = 0; i < x->rank && !outside; i++) {
                NSInteger k = (NSInteger)idx[i] - L[i], n = (NSInteger)x->dims[i];
                if (k < 0 || k >= n) {
                    switch (mode) {
                    case MPSGraphPaddingModeReflect: k = k < 0 ? -k : 2 * n - 2 - k; break;
                    case MPSGraphPaddingModeSymmetric: k = k < 0 ? -k - 1 : 2 * n - 1 - k; break;
                    case MPSGraphPaddingModeClampToEdge: k = k < 0 ? 0 : n - 1; break;
                    case MPSGraphPaddingModePeriodic: k = ((k % n) + n) % n; break;
                    default: outside = YES; break;
                    }
                    k = MAX(MIN(k, n - 1), 0);
                }
                off += k * (NSInteger)st[i];
            }
            out->d[e] = outside ? (mode == MPSGraphPaddingModeZero ? 0 : c) : x->d[off];
            next_index(idx, d, x->rank);
        }
        return @[ out ];
    } grad:mode == MPSGraphPaddingModeConstant || mode == MPSGraphPaddingModeZero ? ^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) {
        return @[ [g _isim_op1:@"padGradient" inputs:@[ og[0], op.inputTensors[0] ] type:t.dataType shape:t.shape name:nil eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
            box b;
            for (NSUInteger i = 0; i < in[1]->rank; i++) { b.start[i] = i < left.count ? left[i].integerValue : 0; b.stride[i] = 1; b.len[i] = in[1]->dims[i]; }
            return @[ slice_box(in[0], &b) ];
        } grad:nil] ];
    } : nil];
}
- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)t axes:(NSArray<NSNumber *> *)axes name:(NSString *)name { return reverse_op(self, t, axes, name); }
- (MPSGraphTensor *)reverseTensor:(MPSGraphTensor *)t name:(NSString *)name { return reverse_op(self, t, nil, name); }
- (MPSGraphTensor *)stackTensors:(NSArray<MPSGraphTensor *> *)tensors axis:(NSInteger)axis name:(NSString *)name {
    NSMutableArray *expanded = [NSMutableArray array];
    for (MPSGraphTensor *t in tensors) [expanded addObject:[self expandDimsOfTensor:t axis:axis name:nil]];
    return [self concatTensors:expanded dimension:axis name:name];
}
- (NSArray<MPSGraphTensor *> *)splitTensor:(MPSGraphTensor *)t splitSizes:(NSArray<NSNumber *> *)sizes axis:(NSInteger)axis name:(NSString *)name {
    NSMutableArray *out = [NSMutableArray array];
    NSInteger start = 0, ax = t.shape ? mg_axis(axis, t.shape.count) : axis;
    for (NSNumber *s in sizes) { [out addObject:[self sliceTensor:t dimension:(NSUInteger)MAX(ax, 0) start:start length:s.integerValue name:name]]; start += s.integerValue; }
    return out;
}
- (NSArray<MPSGraphTensor *> *)splitTensor:(MPSGraphTensor *)t numSplits:(NSUInteger)num axis:(NSInteger)axis name:(NSString *)name {
    NSInteger ax = t.shape ? mg_axis(axis, t.shape.count) : axis, len = t.shape && ax >= 0 && ax < (NSInteger)t.shape.count ? t.shape[ax].integerValue : -1;
    if (len < 0 || !num) { NSLog(@"isim MPSGraph: split needs a known length along the axis"); return @[ t ]; }
    NSMutableArray *sizes = [NSMutableArray array];
    for (NSUInteger i = 0; i < num; i++) [sizes addObject:@(len / (NSInteger)num)];
    return [self splitTensor:t splitSizes:sizes axis:axis name:name];
}
@end

/* ---------------- losses ---------------- */
@implementation MPSGraph (LossOps)
static MGValue *cross_entropy(MGValue *x, MGValue *labels, NSInteger axis, MPSGraphLossReductionType rt) {
    MGValue *p = softmax(x, axis);
    NSInteger ax = mg_axis(axis, x->rank);
    BOOL mask[MG_MAX_RANK] = { 0 };
    if (ax >= 0) mask[ax] = YES;
    MGValue *terms = [MGValue valueLike:x];
    for (NSUInteger i = 0; i < x->n; i++) terms->d[i] = -labels->d[i % MAX(labels->n, (NSUInteger)1)] * log(fmax(p->d[i], 1e-300));
    MGValue *per = reduce(terms, mask, R_SUM);           /* one loss per row, the axis kept */
    if (rt == MPSGraphLossReductionTypeNone) return per;
    BOOL all[MG_MAX_RANK];
    for (NSUInteger i = 0; i < MG_MAX_RANK; i++) all[i] = YES;
    return reduce(per, all, rt == MPSGraphLossReductionTypeMean ? R_MEAN : R_SUM);
}
static MGValue *cross_entropy_backward(MGValue *g, MGValue *x, MGValue *labels, NSInteger axis, MPSGraphLossReductionType rt) {
    MGValue *p = softmax(x, axis), *out = [MGValue valueLike:x];
    NSInteger ax = mg_axis(axis, x->rank);
    double rows = ax >= 0 && x->dims[ax] ? (double)x->n / (double)x->dims[ax] : 1, scale = rt == MPSGraphLossReductionTypeMean ? 1 / rows : 1;
    NSUInteger st[MG_MAX_RANK];
    strides_of(x->dims, x->rank, st);
    for (NSUInteger i = 0; i < x->n; i++) {
        double gi = g->d[0];
        if (rt == MPSGraphLossReductionTypeNone && ax >= 0) {        /* the gradient of the element's row: its index without the axis */
            NSUInteger row = 0, rem = i;
            for (NSUInteger k = 0; k < x->rank; k++) { NSUInteger c = rem / st[k]; rem %= st[k]; if ((NSInteger)k != ax) row = row * x->dims[k] + c; }
            gi = g->d[row % MAX(g->n, (NSUInteger)1)];
        }
        out->d[i] = gi * scale * (p->d[i] - labels->d[i % MAX(labels->n, (NSUInteger)1)]);
    }
    return out;
}
- (MPSGraphTensor *)softMaxCrossEntropyWithSourceTensor:(MPSGraphTensor *)source labelsTensor:(MPSGraphTensor *)labels axis:(NSInteger)axis
                                          reductionType:(MPSGraphLossReductionType)rt name:(NSString *)name {
    MPSShape *shape = rt == MPSGraphLossReductionTypeNone ? reduced_shape(source.shape, @[ @(axis) ]) : reduced_shape(source.shape, nil);
    return [self _isim_op1:@"softMaxCrossEntropy" inputs:@[ source, labels ] type:source.dataType shape:shape name:name
                      eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) { return @[ cross_entropy(in[0], in[1], axis, rt) ]; }
                      grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) {
        return @[ [g softMaxCrossEntropyGradientWithIncomingGradientTensor:og[0] sourceTensor:op.inputTensors[0] labelsTensor:op.inputTensors[1] axis:axis
                                                             reductionType:rt name:nil], [NSNull null] ];
    }];
}
- (MPSGraphTensor *)softMaxCrossEntropyGradientWithIncomingGradientTensor:(MPSGraphTensor *)grad sourceTensor:(MPSGraphTensor *)source
                                                             labelsTensor:(MPSGraphTensor *)labels axis:(NSInteger)axis
                                                            reductionType:(MPSGraphLossReductionType)rt name:(NSString *)name {
    return [self _isim_op1:@"softMaxCrossEntropyGradient" inputs:@[ grad, source, labels ] type:source.dataType shape:source.shape name:name
                      eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) { return @[ cross_entropy_backward(in[0], in[1], in[2], axis, rt) ]; } grad:nil];
}
@end

/* ---------------- optimizers ---------------- */
@implementation MPSGraph (OptimizerOps)
- (MPSGraphTensor *)stochasticGradientDescentWithLearningRateTensor:(MPSGraphTensor *)lr valuesTensor:(MPSGraphTensor *)values
                                                     gradientTensor:(MPSGraphTensor *)gradient name:(NSString *)name {
    return [self subtractionWithPrimaryTensor:values secondaryTensor:mul(self, lr, gradient) name:name];
}
- (MPSGraphOperation *)applyStochasticGradientDescentWithLearningRateTensor:(MPSGraphTensor *)lr variable:(MPSGraphTensor *)variable
                                                             gradientTensor:(MPSGraphTensor *)gradient name:(NSString *)name {
    MPSGraphTensor *updated = [self stochasticGradientDescentWithLearningRateTensor:lr valuesTensor:variable gradientTensor:gradient name:nil];
    return [self assignVariable:variable withValueOfTensor:updated name:name];
}
- (NSArray<MPSGraphTensor *> *)adamWithLearningRateTensor:(MPSGraphTensor *)lr beta1Tensor:(MPSGraphTensor *)b1 beta2Tensor:(MPSGraphTensor *)b2
                                            epsilonTensor:(MPSGraphTensor *)eps beta1PowerTensor:(MPSGraphTensor *)b1p beta2PowerTensor:(MPSGraphTensor *)b2p
                                             valuesTensor:(MPSGraphTensor *)values momentumTensor:(MPSGraphTensor *)m velocityTensor:(MPSGraphTensor *)v
                                           gradientTensor:(MPSGraphTensor *)g name:(NSString *)name {
    /* lr' = lr * sqrt(1 - beta2^t) / (1 - beta1^t); m' = b1 m + (1 - b1) g; v' = b2 v + (1 - b2) g^2; x' = x - lr' m' / (sqrt(v') + eps) */
    MPSGraphTensor *(^ew5)(NSArray *, mg_fn) = ^(NSArray *ins, mg_fn f) { return ewop(self, @"adam", ins, values.dataType, nil, f, nil); };
    MPSGraphTensor *mNew = ew5(@[ b1, m, g ], ^double(const double *x) { return x[0] * x[1] + (1 - x[0]) * x[2]; });
    MPSGraphTensor *vNew = ew5(@[ b2, v, g ], ^double(const double *x) { return x[0] * x[1] + (1 - x[0]) * x[2] * x[2]; });
    MPSGraphTensor *step = ew5(@[ lr, b1p, b2p ], ^double(const double *x) { return x[0] * sqrt(1 - x[2]) / (1 - x[1]); });
    MPSGraphTensor *xNew = ewop(self, @"adam", @[ values, step, mNew, vNew, eps ], values.dataType, name, ^double(const double *x) {
        return x[0] - x[1] * x[2] / (sqrt(x[3]) + x[4]);
    }, nil);
    return @[ xNew, mNew, vNew ];
}
@end
