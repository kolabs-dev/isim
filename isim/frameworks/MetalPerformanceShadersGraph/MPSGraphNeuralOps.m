/* isim MetalPerformanceShadersGraph: convolution, pooling, gather, one-hot, top-K, sorting, cumulative operations,
   random tensors and dropout (adapted: on the CPU) */
#import "mg_internal.h"
#include <float.h>

static BOOL nxt(NSUInteger *idx, const NSUInteger *dims, NSUInteger rank) {
    for (NSUInteger i = rank; i-- > 0;) { if (++idx[i] < dims[i]) return YES; idx[i] = 0; }
    return NO;
}
static void strides(const NSUInteger *dims, NSUInteger rank, NSUInteger *st) {
    NSUInteger s = 1;
    for (NSUInteger i = rank; i-- > 0;) { st[i] = s; s *= dims[i]; }
}

/* ---------------- descriptors ---------------- */
@implementation MPSGraphConvolution2DOpDescriptor
- (instancetype)init {
    if ((self = [super init])) { _strideInX = _strideInY = _dilationRateInX = _dilationRateInY = _groups = 1; _weightsLayout = MPSGraphTensorNamedDataLayoutOIHW; }
    return self;
}
+ (instancetype)descriptorWithStrideInX:(NSUInteger)sx strideInY:(NSUInteger)sy dilationRateInX:(NSUInteger)dx dilationRateInY:(NSUInteger)dy groups:(NSUInteger)groups
                            paddingLeft:(NSUInteger)l paddingRight:(NSUInteger)r paddingTop:(NSUInteger)t paddingBottom:(NSUInteger)b
                           paddingStyle:(MPSGraphPaddingStyle)style dataLayout:(MPSGraphTensorNamedDataLayout)dl weightsLayout:(MPSGraphTensorNamedDataLayout)wl {
    MPSGraphConvolution2DOpDescriptor *d = [self new];
    d.strideInX = sx; d.strideInY = sy; d.dilationRateInX = dx; d.dilationRateInY = dy; d.groups = MAX(groups, (NSUInteger)1);
    d.paddingLeft = l; d.paddingRight = r; d.paddingTop = t; d.paddingBottom = b; d.paddingStyle = style; d.dataLayout = dl; d.weightsLayout = wl;
    return d;
}
+ (instancetype)descriptorWithStrideInX:(NSUInteger)sx strideInY:(NSUInteger)sy dilationRateInX:(NSUInteger)dx dilationRateInY:(NSUInteger)dy groups:(NSUInteger)groups
                           paddingStyle:(MPSGraphPaddingStyle)style dataLayout:(MPSGraphTensorNamedDataLayout)dl weightsLayout:(MPSGraphTensorNamedDataLayout)wl {
    return [self descriptorWithStrideInX:sx strideInY:sy dilationRateInX:dx dilationRateInY:dy groups:groups paddingLeft:0 paddingRight:0 paddingTop:0 paddingBottom:0
                            paddingStyle:style dataLayout:dl weightsLayout:wl];
}
- (void)setExplicitPaddingWithPaddingLeft:(NSUInteger)l paddingRight:(NSUInteger)r paddingTop:(NSUInteger)t paddingBottom:(NSUInteger)b {
    _paddingLeft = l; _paddingRight = r; _paddingTop = t; _paddingBottom = b; _paddingStyle = MPSGraphPaddingStyleExplicit;
}
- (id)copyWithZone:(NSZone *)zone {
    return [MPSGraphConvolution2DOpDescriptor descriptorWithStrideInX:_strideInX strideInY:_strideInY dilationRateInX:_dilationRateInX dilationRateInY:_dilationRateInY
                                                               groups:_groups paddingLeft:_paddingLeft paddingRight:_paddingRight paddingTop:_paddingTop
                                                        paddingBottom:_paddingBottom paddingStyle:_paddingStyle dataLayout:_dataLayout weightsLayout:_weightsLayout];
}
@end

@implementation MPSGraphPooling2DOpDescriptor
+ (instancetype)descriptorWithKernelWidth:(NSUInteger)kw kernelHeight:(NSUInteger)kh strideInX:(NSUInteger)sx strideInY:(NSUInteger)sy
                             paddingStyle:(MPSGraphPaddingStyle)style dataLayout:(MPSGraphTensorNamedDataLayout)dl {
    return [self descriptorWithKernelWidth:kw kernelHeight:kh strideInX:sx strideInY:sy dilationRateInX:1 dilationRateInY:1 paddingLeft:0 paddingRight:0
                                paddingTop:0 paddingBottom:0 paddingStyle:style dataLayout:dl];
}
+ (instancetype)descriptorWithKernelWidth:(NSUInteger)kw kernelHeight:(NSUInteger)kh strideInX:(NSUInteger)sx strideInY:(NSUInteger)sy
                          dilationRateInX:(NSUInteger)dx dilationRateInY:(NSUInteger)dy paddingLeft:(NSUInteger)l paddingRight:(NSUInteger)r
                               paddingTop:(NSUInteger)t paddingBottom:(NSUInteger)b paddingStyle:(MPSGraphPaddingStyle)style
                               dataLayout:(MPSGraphTensorNamedDataLayout)dl {
    MPSGraphPooling2DOpDescriptor *d = [self new];
    d.kernelWidth = kw; d.kernelHeight = kh; d.strideInX = MAX(sx, (NSUInteger)1); d.strideInY = MAX(sy, (NSUInteger)1);
    d.dilationRateInX = MAX(dx, (NSUInteger)1); d.dilationRateInY = MAX(dy, (NSUInteger)1);
    d.paddingLeft = l; d.paddingRight = r; d.paddingTop = t; d.paddingBottom = b; d.paddingStyle = style; d.dataLayout = dl;
    return d;
}
- (void)setExplicitPaddingWithPaddingLeft:(NSUInteger)l paddingRight:(NSUInteger)r paddingTop:(NSUInteger)t paddingBottom:(NSUInteger)b {
    _paddingLeft = l; _paddingRight = r; _paddingTop = t; _paddingBottom = b; _paddingStyle = MPSGraphPaddingStyleExplicit;
}
- (id)copyWithZone:(NSZone *)zone {
    MPSGraphPooling2DOpDescriptor *d = [MPSGraphPooling2DOpDescriptor descriptorWithKernelWidth:_kernelWidth kernelHeight:_kernelHeight strideInX:_strideInX
        strideInY:_strideInY dilationRateInX:_dilationRateInX dilationRateInY:_dilationRateInY paddingLeft:_paddingLeft paddingRight:_paddingRight
        paddingTop:_paddingTop paddingBottom:_paddingBottom paddingStyle:_paddingStyle dataLayout:_dataLayout];
    d.ceilMode = _ceilMode; d.includeZeroPadToAverage = _includeZeroPadToAverage;
    return d;
}
@end

/* ---------------- windows: geometry shared by convolution and pooling ---------------- */
typedef struct {
    NSUInteger n, c, h, w;          /* source */
    NSUInteger oh, ow;              /* result */
    NSUInteger kh, kw, sy, sx, dy, dx;
    NSInteger pt, pl;               /* padding before */
    BOOL nhwc;
} win;
static void out_size(NSUInteger in, NSUInteger k, NSUInteger s, NSUInteger d, NSUInteger p0, NSUInteger p1, MPSGraphPaddingStyle style, BOOL ceilMode,
                     NSUInteger *out, NSInteger *before) {
    NSUInteger ek = (k - 1) * d + 1;
    if (style == MPSGraphPaddingStyleTF_SAME || style == MPSGraphPaddingStyleONNX_SAME_LOWER) {
        *out = (in + s - 1) / s;
        NSInteger total = MAX((NSInteger)((*out - 1) * s + ek) - (NSInteger)in, 0);
        *before = style == MPSGraphPaddingStyleTF_SAME ? total / 2 : (total + 1) / 2;
        return;
    }
    if (style == MPSGraphPaddingStyleTF_VALID) { p0 = p1 = 0; }
    NSInteger span = (NSInteger)(in + p0 + p1) - (NSInteger)ek;
    *out = span < 0 ? 0 : (ceilMode ? (NSUInteger)((span + (NSInteger)s - 1) / (NSInteger)s) : (NSUInteger)(span / (NSInteger)s)) + 1;
    *before = (NSInteger)p0;
}
static win window_of(MGValue *x, NSUInteger kh, NSUInteger kw, NSUInteger sy, NSUInteger sx, NSUInteger dy, NSUInteger dx, NSUInteger pt, NSUInteger pb,
                     NSUInteger pl, NSUInteger pr, MPSGraphPaddingStyle style, MPSGraphTensorNamedDataLayout layout, BOOL ceilMode) {
    win v = { 0 };
    BOOL batched = x->rank == 4;
    v.nhwc = layout == MPSGraphTensorNamedDataLayoutNHWC || layout == MPSGraphTensorNamedDataLayoutHWC;
    NSUInteger o = batched ? 1 : 0;
    v.n = batched ? x->dims[0] : 1;
    if (v.nhwc) { v.h = x->dims[o]; v.w = x->dims[o + 1]; v.c = x->dims[o + 2]; } else { v.c = x->dims[o]; v.h = x->dims[o + 1]; v.w = x->dims[o + 2]; }
    v.kh = kh; v.kw = kw; v.sy = MAX(sy, (NSUInteger)1); v.sx = MAX(sx, (NSUInteger)1); v.dy = MAX(dy, (NSUInteger)1); v.dx = MAX(dx, (NSUInteger)1);
    out_size(v.h, kh, v.sy, v.dy, pt, pb, style, ceilMode, &v.oh, &v.pt);
    out_size(v.w, kw, v.sx, v.dx, pl, pr, style, ceilMode, &v.ow, &v.pl);
    return v;
}
static inline NSUInteger at4(const win *v, NSUInteger n, NSUInteger c, NSUInteger y, NSUInteger x, NSUInteger C, NSUInteger H, NSUInteger W) {
    return v->nhwc ? ((n * H + y) * W + x) * C + c : ((n * C + c) * H + y) * W + x;
}
static MGValue *result_of(MGValue *x, const win *v, NSUInteger channels) {
    NSUInteger d[4];
    BOOL batched = x->rank == 4;
    NSUInteger r = 0;
    if (batched) d[r++] = v->n;
    if (v->nhwc) { d[r++] = v->oh; d[r++] = v->ow; d[r++] = channels; } else { d[r++] = channels; d[r++] = v->oh; d[r++] = v->ow; }
    return [MGValue valueWithDims:d rank:r];
}

/* ---------------- convolution ---------------- */
typedef struct { NSUInteger o, i, kh, kw; BOOL hwio; } wshape;
static wshape weights_of(MGValue *w, MPSGraphTensorNamedDataLayout layout) {
    wshape s;
    s.hwio = layout == MPSGraphTensorNamedDataLayoutHWIO;
    if (s.hwio) { s.kh = w->dims[0]; s.kw = w->dims[1]; s.i = w->dims[2]; s.o = w->dims[3]; }
    else { s.o = w->dims[0]; s.i = w->dims[1]; s.kh = w->dims[2]; s.kw = w->dims[3]; }
    return s;
}
static inline NSUInteger widx(const wshape *s, NSUInteger o, NSUInteger i, NSUInteger y, NSUInteger x) {
    return s->hwio ? ((y * s->kw + x) * s->i + i) * s->o + o : ((o * s->i + i) * s->kh + y) * s->kw + x;
}
/* mode 0: the result; 1: the source's gradient (into dx) from g; 2: the weights' gradient (into dw) from g */
static void conv(MGValue *x, MGValue *w, MPSGraphConvolution2DOpDescriptor *d, MGValue *out, MGValue *g, int mode, MGValue *dst) {
    wshape s = weights_of(w, d.weightsLayout);
    win v = window_of(x, s.kh, s.kw, d.strideInY, d.strideInX, d.dilationRateInY, d.dilationRateInX, d.paddingTop, d.paddingBottom, d.paddingLeft,
                      d.paddingRight, d.paddingStyle, d.dataLayout, NO);
    NSUInteger groups = MAX(d.groups, (NSUInteger)1), ipg = s.i, opg = s.o / groups;
    for (NSUInteger n = 0; n < v.n; n++)
        for (NSUInteger o = 0; o < s.o; o++) {
            NSUInteger grp = opg ? o / opg : 0;
            for (NSUInteger oy = 0; oy < v.oh; oy++)
                for (NSUInteger ox = 0; ox < v.ow; ox++) {
                    NSUInteger oi = at4(&v, n, o, oy, ox, s.o, v.oh, v.ow);
                    double acc = 0, gv = mode ? g->d[oi] : 0;
                    for (NSUInteger i = 0; i < ipg; i++) {
                        NSUInteger ci = grp * ipg + i;
                        for (NSUInteger ky = 0; ky < s.kh; ky++) {
                            NSInteger iy = (NSInteger)(oy * v.sy + ky * v.dy) - v.pt;
                            if (iy < 0 || iy >= (NSInteger)v.h) continue;
                            for (NSUInteger kx = 0; kx < s.kw; kx++) {
                                NSInteger ix = (NSInteger)(ox * v.sx + kx * v.dx) - v.pl;
                                if (ix < 0 || ix >= (NSInteger)v.w) continue;
                                NSUInteger xi = at4(&v, n, ci, (NSUInteger)iy, (NSUInteger)ix, v.c, v.h, v.w), wi = widx(&s, o, i, ky, kx);
                                if (mode == 0) acc += x->d[xi] * w->d[wi];
                                else if (mode == 1) dst->d[xi] += gv * w->d[wi];
                                else dst->d[wi] += gv * x->d[xi];
                            }
                        }
                    }
                    if (mode == 0) out->d[oi] = acc;
                }
        }
}
@implementation MPSGraph (ConvolutionOps)
- (MPSGraphTensor *)convolution2DWithSourceTensor:(MPSGraphTensor *)source weightsTensor:(MPSGraphTensor *)weights
                                       descriptor:(MPSGraphConvolution2DOpDescriptor *)desc name:(NSString *)name {
    MPSGraphConvolution2DOpDescriptor *d = [desc copy];
    return [self _isim_op1:@"convolution2D" inputs:@[ source, weights ] type:source.dataType shape:nil name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *x = in[0], *w = in[1];
        wshape s = weights_of(w, d.weightsLayout);
        win v = window_of(x, s.kh, s.kw, d.strideInY, d.strideInX, d.dilationRateInY, d.dilationRateInX, d.paddingTop, d.paddingBottom, d.paddingLeft,
                          d.paddingRight, d.paddingStyle, d.dataLayout, NO);
        MGValue *out = result_of(x, &v, s.o);
        conv(x, w, d, out, nil, 0, nil);
        return @[ out ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) {
        MPSGraphTensor *X = op.inputTensors[0], *W = op.inputTensors[1];
        MPSGraphTensor *dx = [g _isim_op1:@"convolution2DDataGradient" inputs:@[ og[0], X, W ] type:X.dataType shape:X.shape name:nil
                                     eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
            MGValue *out = [MGValue valueLike:in[1]];
            conv(in[1], in[2], d, nil, in[0], 1, out);
            return @[ out ];
        } grad:nil];
        MPSGraphTensor *dw = [g _isim_op1:@"convolution2DWeightsGradient" inputs:@[ og[0], X, W ] type:W.dataType shape:W.shape name:nil
                                     eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
            MGValue *out = [MGValue valueLike:in[2]];
            conv(in[1], in[2], d, nil, in[0], 2, out);
            return @[ out ];
        } grad:nil];
        return @[ dx, dw ];
    }];
}
@end

/* ---------------- pooling ---------------- */
/* mode 0: the result; 1: the source's gradient from g */
static void pool(MGValue *x, MPSGraphPooling2DOpDescriptor *d, BOOL maxPool, MGValue *out, MGValue *g, MGValue *dst) {
    win v = window_of(x, d.kernelHeight, d.kernelWidth, d.strideInY, d.strideInX, d.dilationRateInY, d.dilationRateInX, d.paddingTop, d.paddingBottom,
                      d.paddingLeft, d.paddingRight, d.paddingStyle, d.dataLayout, d.ceilMode);
    for (NSUInteger n = 0; n < v.n; n++)
        for (NSUInteger c = 0; c < v.c; c++)
            for (NSUInteger oy = 0; oy < v.oh; oy++)
                for (NSUInteger ox = 0; ox < v.ow; ox++) {
                    double acc = maxPool ? -INFINITY : 0; NSUInteger count = 0, arg = NSUIntegerMax;
                    for (NSUInteger ky = 0; ky < v.kh; ky++)
                        for (NSUInteger kx = 0; kx < v.kw; kx++) {
                            NSInteger iy = (NSInteger)(oy * v.sy + ky * v.dy) - v.pt, ix = (NSInteger)(ox * v.sx + kx * v.dx) - v.pl;
                            if (iy < 0 || iy >= (NSInteger)v.h || ix < 0 || ix >= (NSInteger)v.w) { if (d.includeZeroPadToAverage) count++; continue; }
                            NSUInteger xi = at4(&v, n, c, (NSUInteger)iy, (NSUInteger)ix, v.c, v.h, v.w);
                            if (maxPool) { if (x->d[xi] > acc) { acc = x->d[xi]; arg = xi; } }
                            else acc += x->d[xi];
                            count++;
                        }
                    NSUInteger oi = at4(&v, n, c, oy, ox, v.c, v.oh, v.ow);
                    if (!g) { out->d[oi] = maxPool ? acc : (count ? acc / (double)count : 0); continue; }
                    if (maxPool) { if (arg != NSUIntegerMax) dst->d[arg] += g->d[oi]; continue; }
                    for (NSUInteger ky = 0; ky < v.kh; ky++)
                        for (NSUInteger kx = 0; kx < v.kw; kx++) {
                            NSInteger iy = (NSInteger)(oy * v.sy + ky * v.dy) - v.pt, ix = (NSInteger)(ox * v.sx + kx * v.dx) - v.pl;
                            if (iy < 0 || iy >= (NSInteger)v.h || ix < 0 || ix >= (NSInteger)v.w || !count) continue;
                            dst->d[at4(&v, n, c, (NSUInteger)iy, (NSUInteger)ix, v.c, v.h, v.w)] += g->d[oi] / (double)count;
                        }
                }
}
static MPSGraphTensor *pool_op(MPSGraph *g, MPSGraphTensor *source, MPSGraphPooling2DOpDescriptor *desc, BOOL maxPool, NSString *name) {
    MPSGraphPooling2DOpDescriptor *d = [desc copy];
    return [g _isim_op1:maxPool ? @"maxPooling2D" : @"avgPooling2D" inputs:@[ source ] type:source.dataType shape:nil name:name
                   eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *x = in[0];
        win v = window_of(x, d.kernelHeight, d.kernelWidth, d.strideInY, d.strideInX, d.dilationRateInY, d.dilationRateInX, d.paddingTop, d.paddingBottom,
                          d.paddingLeft, d.paddingRight, d.paddingStyle, d.dataLayout, d.ceilMode);
        MGValue *out = result_of(x, &v, v.c);
        pool(x, d, maxPool, out, nil, nil);
        return @[ out ];
    } grad:^NSArray *(MPSGraph *gr, MPSGraphOperation *op, NSArray *og) {
        MPSGraphTensor *X = op.inputTensors[0];
        return @[ [gr _isim_op1:@"pooling2DGradient" inputs:@[ og[0], X ] type:X.dataType shape:X.shape name:nil eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
            MGValue *out = [MGValue valueLike:in[1]];
            pool(in[1], d, maxPool, nil, in[0], out);
            return @[ out ];
        } grad:nil] ];
    }];
}
@implementation MPSGraph (PoolingOps)
- (MPSGraphTensor *)maxPooling2DWithSourceTensor:(MPSGraphTensor *)source descriptor:(MPSGraphPooling2DOpDescriptor *)d name:(NSString *)name {
    return pool_op(self, source, d, YES, name);
}
- (MPSGraphTensor *)avgPooling2DWithSourceTensor:(MPSGraphTensor *)source descriptor:(MPSGraphPooling2DOpDescriptor *)d name:(NSString *)name {
    return pool_op(self, source, d, NO, name);
}
@end

/* ---------------- gather ---------------- */
/* out = updates[..., indices, ...] along the axis; scatter: the reverse, adding */
static void gather(MGValue *u, MGValue *ix, NSInteger axis, MGValue *out, MGValue *g, MGValue *dst) {
    NSUInteger outer = 1, inner = 1, len = u->dims[axis];
    for (NSInteger i = 0; i < axis; i++) outer *= u->dims[i];
    for (NSUInteger i = (NSUInteger)axis + 1; i < u->rank; i++) inner *= u->dims[i];
    for (NSUInteger o = 0; o < outer; o++)
        for (NSUInteger k = 0; k < ix->n; k++) {
            NSInteger j = (NSInteger)ix->d[k];
            if (j < 0) j += (NSInteger)len;
            if (j < 0 || j >= (NSInteger)len) continue;
            for (NSUInteger i = 0; i < inner; i++) {
                NSUInteger from = (o * len + (NSUInteger)j) * inner + i, to = (o * ix->n + k) * inner + i;
                if (g) dst->d[from] += g->d[to]; else out->d[to] = u->d[from];
            }
        }
}
/* out[i] = updates[i with the axis index replaced by indices[i]] */
static void gather_along(MGValue *u, MGValue *ix, NSInteger axis, MGValue *out, MGValue *g, MGValue *dst) {
    NSUInteger st[MG_MAX_RANK], idx[MG_MAX_RANK] = { 0 };
    strides(u->dims, u->rank, st);
    for (NSUInteger e = 0; e < ix->n; e++) {
        NSInteger j = (NSInteger)ix->d[e];
        if (j < 0) j += (NSInteger)u->dims[axis];
        if (j >= 0 && j < (NSInteger)u->dims[axis]) {
            NSUInteger off = 0;
            for (NSUInteger i = 0; i < u->rank; i++) off += (i == (NSUInteger)axis ? (NSUInteger)j : MIN(idx[i], u->dims[i] - 1)) * st[i];
            if (g) dst->d[off] += g->d[e]; else out->d[e] = u->d[off];
        }
        nxt(idx, ix->dims, ix->rank);
    }
}
@implementation MPSGraph (GatherOps)
- (MPSGraphTensor *)gatherWithUpdatesTensor:(MPSGraphTensor *)updates indicesTensor:(MPSGraphTensor *)indices axis:(NSUInteger)axis
                            batchDimensions:(NSUInteger)batchDimensions name:(NSString *)name {
    if (batchDimensions) NSLog(@"isim MPSGraph: gather with batch dimensions is not implemented; gathering without them");
    return [self _isim_op1:@"gather" inputs:@[ updates, indices ] type:updates.dataType shape:nil name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *u = in[0], *ix = in[1];
        NSUInteger d[MG_MAX_RANK], r = 0;
        for (NSUInteger i = 0; i < axis && r < MG_MAX_RANK; i++) d[r++] = u->dims[i];
        for (NSUInteger i = 0; i < ix->rank && r < MG_MAX_RANK; i++) d[r++] = ix->dims[i];
        for (NSUInteger i = axis + 1; i < u->rank && r < MG_MAX_RANK; i++) d[r++] = u->dims[i];
        MGValue *out = [MGValue valueWithDims:d rank:r];
        gather(u, ix, (NSInteger)axis, out, nil, nil);
        return @[ out ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) {
        MPSGraphTensor *U = op.inputTensors[0];
        return @[ [g _isim_op1:@"gatherGradient" inputs:@[ og[0], U, op.inputTensors[1] ] type:U.dataType shape:U.shape name:nil
                          eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
            MGValue *out = [MGValue valueLike:in[1]];
            gather(in[1], in[2], (NSInteger)axis, nil, in[0], out);
            return @[ out ];
        } grad:nil], [NSNull null] ];
    }];
}
- (MPSGraphTensor *)gatherAlongAxis:(NSInteger)axis withUpdatesTensor:(MPSGraphTensor *)updates indicesTensor:(MPSGraphTensor *)indices name:(NSString *)name {
    return [self _isim_op1:@"gatherAlongAxis" inputs:@[ updates, indices ] type:updates.dataType shape:indices.shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *out = [MGValue valueLike:in[1]];
        gather_along(in[0], in[1], mg_axis(axis, in[0]->rank), out, nil, nil);
        return @[ out ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) {
        MPSGraphTensor *U = op.inputTensors[0];
        return @[ [g _isim_op1:@"gatherAlongAxisGradient" inputs:@[ og[0], U, op.inputTensors[1] ] type:U.dataType shape:U.shape name:nil
                          eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
            MGValue *out = [MGValue valueLike:in[1]];
            gather_along(in[1], in[2], mg_axis(axis, in[1]->rank), nil, in[0], out);
            return @[ out ];
        } grad:nil], [NSNull null] ];
    }];
}
@end

/* ---------------- one-hot ---------------- */
@implementation MPSGraph (OneHotOps)
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)indices depth:(NSUInteger)depth axis:(NSUInteger)axis dataType:(MPSDataType)t
                                    onValue:(double)on offValue:(double)off name:(NSString *)name {
    MPSShape *shape = nil;
    if (indices.shape) { NSMutableArray *s = [indices.shape mutableCopy]; [s insertObject:@(depth) atIndex:MIN(axis, s.count)]; shape = s; }
    return [self _isim_op1:@"oneHot" inputs:@[ indices ] type:t shape:shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *ix = in[0];
        NSUInteger ax = MIN(axis, ix->rank), d[MG_MAX_RANK], r = 0, outer = 1, inner = 1;
        for (NSUInteger i = 0; i < ix->rank + 1 && r < MG_MAX_RANK; i++) d[r++] = i == ax ? depth : ix->dims[i < ax ? i : i - 1];
        for (NSUInteger i = 0; i < ax; i++) outer *= ix->dims[i];
        for (NSUInteger i = ax; i < ix->rank; i++) inner *= ix->dims[i];
        MGValue *out = [MGValue valueWithDims:d rank:r];
        for (NSUInteger o = 0; o < outer; o++)
            for (NSUInteger k = 0; k < depth; k++)
                for (NSUInteger i = 0; i < inner; i++)
                    out->d[(o * depth + k) * inner + i] = (NSUInteger)ix->d[o * inner + i] == k && ix->d[o * inner + i] >= 0 ? on : off;
        return @[ out ];
    } grad:nil];
}
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)i depth:(NSUInteger)depth dataType:(MPSDataType)t onValue:(double)on offValue:(double)off name:(NSString *)name {
    return [self oneHotWithIndicesTensor:i depth:depth axis:i.shape ? i.shape.count : 1 dataType:t onValue:on offValue:off name:name];
}
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)i depth:(NSUInteger)depth axis:(NSUInteger)axis dataType:(MPSDataType)t name:(NSString *)name {
    return [self oneHotWithIndicesTensor:i depth:depth axis:axis dataType:t onValue:1 offValue:0 name:name];
}
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)i depth:(NSUInteger)depth dataType:(MPSDataType)t name:(NSString *)name {
    return [self oneHotWithIndicesTensor:i depth:depth dataType:t onValue:1 offValue:0 name:name];
}
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)i depth:(NSUInteger)depth axis:(NSUInteger)axis name:(NSString *)name {
    return [self oneHotWithIndicesTensor:i depth:depth axis:axis dataType:MPSDataTypeFloat32 onValue:1 offValue:0 name:name];
}
- (MPSGraphTensor *)oneHotWithIndicesTensor:(MPSGraphTensor *)i depth:(NSUInteger)depth name:(NSString *)name {
    return [self oneHotWithIndicesTensor:i depth:depth dataType:MPSDataTypeFloat32 onValue:1 offValue:0 name:name];
}
@end

/* ---------------- along an axis: top-K, sorting, cumulative operations ---------------- */
/* calls f(base, stride, len) for every line of x along the axis */
static void lines(MGValue *x, NSInteger axis, void (^f)(NSUInteger base, NSUInteger stride, NSUInteger len)) {
    NSUInteger st[MG_MAX_RANK];
    strides(x->dims, x->rank, st);
    NSUInteger len = x->dims[axis], stride = st[axis], outer = x->n / MAX(len * stride, (NSUInteger)1);
    for (NSUInteger o = 0; o < outer; o++)
        for (NSUInteger in = 0; in < stride; in++) f(o * len * stride + in, stride, len);
}
static NSUInteger *order_of(const double *v, NSUInteger base, NSUInteger stride, NSUInteger len, BOOL descending) {
    NSUInteger *ord = malloc(sizeof(NSUInteger) * (len + 1));
    for (NSUInteger i = 0; i < len; i++) ord[i] = i;
    for (NSUInteger i = 1; i < len; i++) {                 /* stable insertion sort */
        NSUInteger k = ord[i]; NSInteger j = (NSInteger)i - 1;
        double kv = v[base + k * stride];
        while (j >= 0 && (descending ? v[base + ord[j] * stride] < kv : v[base + ord[j] * stride] > kv)) { ord[j + 1] = ord[j]; j--; }
        ord[j + 1] = k;
    }
    return ord;
}
static NSArray<MPSGraphTensor *> *topk(MPSGraph *g, MPSGraphTensor *source, NSInteger axis, NSUInteger k, NSString *name) {
    MPSShape *shape = nil;
    if (source.shape) { NSMutableArray *s = [source.shape mutableCopy]; NSInteger ax = mg_axis(axis, s.count); if (ax >= 0 && ax < (NSInteger)s.count) s[ax] = @(k); shape = s; }
    NSArray *outs = [g _isim_op:@"topK" inputs:@[ source ] types:@[ @(source.dataType), @(MPSDataTypeInt32) ] shapes:@[ shape ?: (id)[NSNull null], shape ?: (id)[NSNull null] ]
                           name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *x = in[0];
        NSInteger ax = mg_axis(axis, x->rank);
        NSUInteger d[MG_MAX_RANK];
        memcpy(d, x->dims, sizeof(NSUInteger) * x->rank);
        NSUInteger kk = MIN(k, d[ax]);
        d[ax] = kk;
        MGValue *vals = [MGValue valueWithDims:d rank:x->rank], *idx = [MGValue valueWithDims:d rank:x->rank];
        __block NSUInteger line = 0;
        NSUInteger ost[MG_MAX_RANK];
        strides(d, x->rank, ost);
        NSUInteger axStride = ost[ax];
        lines(x, ax, ^(NSUInteger base, NSUInteger stride, NSUInteger len) {
            NSUInteger *ord = order_of(x->d, base, stride, len, YES);
            /* the same line in the result: its base from the line number */
            NSUInteger inner = stride, o = line / inner, i = line % inner, obase = o * kk * inner + i;
            for (NSUInteger j = 0; j < kk; j++) { vals->d[obase + j * axStride] = x->d[base + ord[j] * stride]; idx->d[obase + j * axStride] = (double)ord[j]; }
            free(ord);
            line++;
        });
        return @[ vals, idx ];
    } grad:^NSArray *(MPSGraph *gr, MPSGraphOperation *op, NSArray *og) {
        if (og[0] == [NSNull null]) return @[ [NSNull null] ];
        MPSGraphTensor *X = op.inputTensors[0];
        return @[ [gr _isim_op1:@"topKGradient" inputs:@[ og[0], X, op.outputTensors[1] ] type:X.dataType shape:X.shape name:nil
                           eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
            MGValue *out = [MGValue valueLike:in[1]];
            gather_along(in[1], in[2], mg_axis(axis, in[1]->rank), nil, in[0], out);
            return @[ out ];
        } grad:nil] ];
    }];
    return outs;
}
@implementation MPSGraph (TopKOps)
- (NSArray<MPSGraphTensor *> *)topKWithSourceTensor:(MPSGraphTensor *)source k:(NSUInteger)k name:(NSString *)name { return topk(self, source, -1, k, name); }
- (NSArray<MPSGraphTensor *> *)topKWithSourceTensor:(MPSGraphTensor *)source axis:(NSInteger)axis k:(NSUInteger)k name:(NSString *)name {
    return topk(self, source, axis, k, name);
}
@end

static MPSGraphTensor *sort_op(MPSGraph *g, MPSGraphTensor *t, NSInteger axis, BOOL descending, BOOL arg, NSString *name) {
    return [g _isim_op1:arg ? @"argSort" : @"sort" inputs:@[ t ] type:arg ? MPSDataTypeInt32 : t.dataType shape:t.shape name:name
                   eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *x = in[0], *out = [MGValue valueLike:x];
        lines(x, mg_axis(axis, x->rank), ^(NSUInteger base, NSUInteger stride, NSUInteger len) {
            NSUInteger *ord = order_of(x->d, base, stride, len, descending);
            for (NSUInteger j = 0; j < len; j++) out->d[base + j * stride] = arg ? (double)ord[j] : x->d[base + ord[j] * stride];
            free(ord);
        });
        return @[ out ];
    } grad:nil];
}
@implementation MPSGraph (SortOps)
- (MPSGraphTensor *)sortWithTensor:(MPSGraphTensor *)t axis:(NSInteger)axis descending:(BOOL)d name:(NSString *)name { return sort_op(self, t, axis, d, NO, name); }
- (MPSGraphTensor *)sortWithTensor:(MPSGraphTensor *)t axis:(NSInteger)axis name:(NSString *)name { return sort_op(self, t, axis, NO, NO, name); }
- (MPSGraphTensor *)argSortWithTensor:(MPSGraphTensor *)t axis:(NSInteger)axis descending:(BOOL)d name:(NSString *)name { return sort_op(self, t, axis, d, YES, name); }
- (MPSGraphTensor *)argSortWithTensor:(MPSGraphTensor *)t axis:(NSInteger)axis name:(NSString *)name { return sort_op(self, t, axis, NO, YES, name); }
@end

typedef enum { C_SUM, C_PROD, C_MIN, C_MAX } cum;
static MPSGraphTensor *cumulative(MPSGraph *g, NSString *kind, MPSGraphTensor *t, NSInteger axis, BOOL exclusive, BOOL reverse, cum op, NSString *name) {
    return [g _isim_op1:kind inputs:@[ t ] type:t.dataType shape:t.shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *x = in[0], *out = [MGValue valueLike:x];
        lines(x, mg_axis(axis, x->rank), ^(NSUInteger base, NSUInteger stride, NSUInteger len) {
            double acc = op == C_SUM ? 0 : op == C_PROD ? 1 : op == C_MIN ? INFINITY : -INFINITY;
            for (NSUInteger j = 0; j < len; j++) {
                NSUInteger e = base + (reverse ? len - 1 - j : j) * stride;
                double v = x->d[e];
                if (exclusive) out->d[e] = acc;
                acc = op == C_SUM ? acc + v : op == C_PROD ? acc * v : op == C_MIN ? fmin(acc, v) : fmax(acc, v);
                if (!exclusive) out->d[e] = acc;
            }
        });
        return @[ out ];
    } grad:op == C_SUM ? ^NSArray *(MPSGraph *gr, MPSGraphOperation *o, NSArray *og) {
        return @[ cumulative(gr, kind, og[0], axis, exclusive, !reverse, C_SUM, nil) ];   /* the sum of the later gradients */
    } : nil];
}
@implementation MPSGraph (CumulativeOps)
#define CUM(SEL, KIND, OP) \
    - (MPSGraphTensor *)SEL##WithTensor:(MPSGraphTensor *)t axis:(NSInteger)axis exclusive:(BOOL)e reverse:(BOOL)r name:(NSString *)name { \
        return cumulative(self, @KIND, t, axis, e, r, OP, name); } \
    - (MPSGraphTensor *)SEL##WithTensor:(MPSGraphTensor *)t axis:(NSInteger)axis name:(NSString *)name { return cumulative(self, @KIND, t, axis, NO, NO, OP, name); }
CUM(cumulativeSum, "cumulativeSum", C_SUM)
CUM(cumulativeProduct, "cumulativeProduct", C_PROD)
CUM(cumulativeMinimum, "cumulativeMinimum", C_MIN)
CUM(cumulativeMaximum, "cumulativeMaximum", C_MAX)
@end

/* ---------------- random tensors and dropout ---------------- */
@implementation MPSGraph (RandomOps)
- (MPSGraphTensor *)randomUniformTensorWithShape:(MPSShape *)shape seed:(NSUInteger)seed name:(NSString *)name {
    return [self _isim_op1:@"randomUniform" inputs:@[] type:MPSDataTypeFloat32 shape:shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *out = mg_value_of_shape(shape);
        MGRun *own = [MGRun new];
        own.rng = (uint64_t)seed * 0x9e3779b97f4a7c15ULL + 1;   /* a seed gives the same values every run */
        for (NSUInteger i = 0; i < out->n; i++) out->d[i] = mg_random(own);
        return @[ out ];
    } grad:nil];
}
- (MPSGraphTensor *)randomUniformTensorWithShape:(MPSShape *)shape name:(NSString *)name {
    return [self _isim_op1:@"randomUniform" inputs:@[] type:MPSDataTypeFloat32 shape:shape name:name eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *out = mg_value_of_shape(shape);
        for (NSUInteger i = 0; i < out->n; i++) out->d[i] = mg_random(run);
        return @[ out ];
    } grad:nil];
}
@end

@implementation MPSGraph (DropoutOps)
- (MPSGraphTensor *)dropoutTensor:(MPSGraphTensor *)t rate:(double)rate name:(NSString *)name {
    /* a mask drawn once per run from a uniform tensor shaped like the source; the gradient follows from the product */
    MPSGraphTensor *u = [self _isim_op1:@"randomLike" inputs:@[ t ] type:MPSDataTypeFloat32 shape:t.shape name:nil eval:^NSArray *(NSArray<MGValue *> *in, MGRun *run) {
        MGValue *out = [MGValue valueLike:in[0]];
        for (NSUInteger i = 0; i < out->n; i++) out->d[i] = mg_random(run) >= rate ? 1 / (1 - rate) : 0;
        return @[ out ];
    } grad:^NSArray *(MPSGraph *g, MPSGraphOperation *op, NSArray *og) { return @[ [NSNull null] ]; }];
    return [self multiplicationWithPrimaryTensor:t secondaryTensor:u name:name];
}
@end
