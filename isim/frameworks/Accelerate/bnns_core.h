// isim Accelerate BNNS (issue #808): what BNNS's engine files share (bnns.c, bnns_ops.c, bnns_layers.c, bnns_train.c).
// Every operation reads its tensors into dense float buffers (dimension 0 fastest, in the descriptor's size[] order),
// computes in float, and writes the result back in the destination's data type, layout and strides.
#pragma once
#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#define BN_MAXD BNNS_MAX_TENSOR_DIMENSION

typedef struct { int rank; size_t n[BN_MAXD]; size_t count; } bn_dims;

int bn_type_bits(BNNSDataType t);            /* bits per element, 0 for an unknown type */
int bn_type_is_float(BNNSDataType t);
int bn_layout_rank(BNNSDataLayout l);         /* -1 for an unknown layout */
int bn_layout_first_major(BNNSDataLayout l);
/* the dimensions, and the element stride of each logical dimension (defaults filled in) */
int bn_dims_of(const BNNSNDArrayDescriptor *d, bn_dims *out);
int bn_strides(const BNNSNDArrayDescriptor *d, size_t st[BN_MAXD]);
/* element access: idx is an element offset from data */
float bn_read(const BNNSNDArrayDescriptor *d, const void *data, size_t idx);
void bn_write(const BNNSNDArrayDescriptor *d, void *data, size_t idx, float v);
/* a dense float copy of the tensor (malloc'ed; NULL on error), from d->data or from data when not NULL */
float *bn_load(const BNNSNDArrayDescriptor *d, const void *data, bn_dims *dims);
/* write a dense buffer back (to d->data, or data when not NULL); accumulate adds to what is there */
int bn_store(const BNNSNDArrayDescriptor *d, void *data, const float *v, int accumulate);
/* integer indices (exactly, without going through float) as a dense int64 buffer */
long long *bn_load_index(const BNNSNDArrayDescriptor *d, const void *data, bn_dims *dims);
/* the number of bytes a tensor spans */
size_t bn_span_bytes(const BNNSNDArrayDescriptor *d);
/* broadcast helper: the element of a buffer with dims `a` at the canonical position `pos` of dims `out` */
size_t bn_bcast_index(const bn_dims *a, const bn_dims *out, const size_t *pos);
void bn_unravel(const bn_dims *d, size_t i, size_t *pos);

/* activations: in place over n values; channel (for the per-channel kinds) is given by chan(i) when not NULL */
void bn_activation(const BNNSActivation *a, float *v, size_t n, size_t inner, size_t channels, const float *prelu);
/* derivative: given x (input) and y (output), dy -> dx in place */
void bn_activation_backward(const BNNSActivation *a, const float *x, const float *y, float *dydx, size_t n,
                            size_t inner, size_t channels, const float *prelu, float *dalpha);
/* softmax-like activations over groups: `len` values `stride` apart */
int bn_activation_is_grouped(BNNSActivationFunction f);
void bn_softmax(float *v, size_t len, size_t stride, int logsoftmax);

/* allocation through BNNSFilterParameters */
void *bn_alloc(const BNNSFilterParameters *fp, size_t size);
void bn_free(const BNNSFilterParameters *fp, void *p);

/* the filter object every BNNSFilterCreate* returns (bnns_layers.c dispatches on kind) */
typedef struct bn_filter bn_filter;
struct bn_filter {
    int magic, kind;
    BNNSFilterParameters fp;
    void (*destroy)(bn_filter *f);
    void *state;
};
#define BN_FILTER_MAGIC 0x424e4e53
bn_filter *bn_filter_new(int kind, const BNNSFilterParameters *fp, size_t state_size);
bn_filter *bn_filter_of(BNNSFilter f);
/* a copy of a descriptor's data (so a filter keeps weights after the caller frees them) */
int bn_keep(BNNSNDArrayDescriptor *dst, const BNNSNDArrayDescriptor *src);
void bn_unkeep(BNNSNDArrayDescriptor *d);

/* bnns_ops.c, shared with the layers */
int bn_matmul(bool transA, bool transB, float alpha, const BNNSNDArrayDescriptor *A, const BNNSNDArrayDescriptor *B,
              const BNNSNDArrayDescriptor *C, float beta);
int bn_reduce(BNNSReduceFunction fn, const float *x, const float *w, const bn_dims *di, float *y, const bn_dims *dout, float eps);
int bn_quantize(const BNNSLayerParametersQuantization *p, const void *in, void *out);
/* a descriptor's byte offset for `n` elements (batch strides are in elements) */
static inline size_t bn_bytes(const BNNSNDArrayDescriptor *d, size_t n) { return n * (size_t)bn_type_bits(d->data_type) / 8; }
