// isim Accelerate BNNS (issue #808): the layer filters' shared state (bnns_layers.c, bnns_layers2.c).
#pragma once
#include "bnns_core.h"

enum {
    BK_CONV = 1, BK_TCONV, BK_FC, BK_POOL, BK_ACT, BK_NORM, BK_ARITH, BK_PERMUTE, BK_DROPOUT, BK_PAD, BK_BMM,
    BK_CONTRACT, BK_GRAM, BK_RESIZE, BK_MHA, BK_REDUCE, BK_EMBED, BK_LOSS, BK_QUANT, BK_FUSED
};

typedef struct bn_layer {
    BNNSNDArrayDescriptor i, i2, o;      /* the shapes of the inputs and output (their data is unused) */
    BNNSNDArrayDescriptor w, b;          /* weights and bias: the filter's copies, or the caller's (BNNSFlagsUseClientPtr) */
    int owns_w, owns_b;
    BNNSActivation act;
    float *alpha; size_t nalpha;         /* trainable activation alpha (leaky / PReLU), for BNNSGetPointer */
    BNNSNDArrayDescriptor alpha_desc;
    union {
        BNNSLayerParametersConvolution conv;
        BNNSLayerParametersPooling pool;
        BNNSLayerParametersNormalization norm;
        BNNSLayerParametersPermute perm;
        BNNSLayerParametersDropout drop;
        BNNSLayerParametersPadding pad;
        BNNSLayerParametersResize resize;
        BNNSLayerParametersEmbedding embed;
        BNNSLayerParametersGram gram;
        BNNSLayerParametersReduction reduce;
        BNNSLayerParametersBroadcastMatMul bmm;
        BNNSLayerParametersTensorContraction contract;
        BNNSLayerParametersQuantization quant;
        BNNSLayerParametersActivation actp;
        BNNSLayerParametersLossHuber loss;   /* the largest loss variant except Yolo */
    } p;
    BNNSFilterType norm_type;
    uint32_t axis_flags;
    /* normalization: the moving statistics and gamma / beta (owned copies), and the last training pass's cache */
    BNNSNDArrayDescriptor gamma, beta, mmean, mvar;
    int kind_owns_moving;
    float *cache_xhat, *cache_istd; size_t cache_n, cache_batch;
    /* dropout: the last mask */
    unsigned char *mask; size_t mask_n; uint64_t rng;
    /* arithmetic */
    BNNSArithmeticFunction afn; int arity;
    BNNSNDArrayDescriptor ain[3], aout; BNNSDescriptorType atype[3]; int ain_owned[3];
    /* tensor contraction */
    char cspec[3][BN_MAXD + 1]; int cn[3], cstar, cself, cweights;
    /* fused filters */
    size_t nfused; struct bn_filter *fused[4]; BNNSFilterType ftype[4];
    /* multihead attention */
    BNNSLayerParametersMultiheadAttention mha;
} bn_layer;

bn_layer *bn_layer_of(bn_filter *f);
bn_filter *bn_layer_new(int kind, const BNNSFilterParameters *fp);
/* keep weights / bias according to the filter's flags */
int bn_layer_keep(bn_filter *f, BNNSNDArrayDescriptor *dst, const BNNSNDArrayDescriptor *src, int *owns);
/* per-sample forward (dense in, dense out), shared with the fused filters */
int bn_layer_forward(bn_filter *f, size_t batch, float **x, float **y, int training);
/* bnns_layers2.c */
int bn_arith_forward(bn_layer *L, const float *const *x, const bn_dims *xd, float *y, const bn_dims *yd);
int bn_contract_parse(bn_layer *L, const char *op);
int bn_contract_forward(bn_layer *L, const float *a, const float *b, float *y);
int bn_contract_backward(bn_layer *L, const float *a, const float *b, const float *dy, float *da, float *db);
