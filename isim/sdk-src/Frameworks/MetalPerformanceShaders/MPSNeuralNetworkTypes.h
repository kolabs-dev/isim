// isim MetalPerformanceShaders: the neuron (activation) types the matrix kernels apply. isim: the CNN layers are not
// implemented yet.
#pragma once
#import <MetalPerformanceShaders/MPSCoreTypes.h>

typedef NS_ENUM(int32_t, MPSCNNNeuronType) {
    MPSCNNNeuronTypeNone = 0,
    MPSCNNNeuronTypeReLU,               /* x >= 0 ? x : a * x */
    MPSCNNNeuronTypeLinear,             /* a * x + b */
    MPSCNNNeuronTypeSigmoid,            /* 1 / (1 + e^-x) */
    MPSCNNNeuronTypeHardSigmoid,        /* clamp(a * x + b, 0, 1) */
    MPSCNNNeuronTypeTanH,               /* a * tanh(b * x) */
    MPSCNNNeuronTypeAbsolute,           /* |x| */
    MPSCNNNeuronTypeSoftPlus,           /* a * log(1 + e^(b * x)) */
    MPSCNNNeuronTypeSoftSign,           /* x / (1 + |x|) */
    MPSCNNNeuronTypeELU,                /* x >= 0 ? x : a * (e^x - 1) */
    MPSCNNNeuronTypePReLU,              /* per channel: x >= 0 ? x : a[i] * x */
    MPSCNNNeuronTypeReLUN,              /* min(x >= 0 ? x : a * x, b) */
    MPSCNNNeuronTypePower,              /* (a * x + b) ^ c */
    MPSCNNNeuronTypeExponential,        /* c ^ (a * x + b), c < 0 for e */
    MPSCNNNeuronTypeLogarithm,          /* log_c(a * x + b), c < 0 for e */
    MPSCNNNeuronTypeGeLU API_AVAILABLE(ios(14.0)),
    MPSCNNNeuronTypeCount,
} API_AVAILABLE(ios(11.3));
