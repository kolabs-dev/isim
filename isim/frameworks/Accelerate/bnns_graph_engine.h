// isim Accelerate BNNSGraph (issue #824): the graph engine's data (bnns_graph.c, bnns_graph_ops.c, bnns_graph_api.c) and
// the _isim_bnns_graph_* entry points the Swift overlay builds graphs with.
#pragma once
#include <Accelerate/Accelerate.h>

#define GMAXR 8
#define GMAXIN 8
#define GMAXIA 40

typedef struct { int rank; long long d[GMAXR]; } gshape;

/* operations; the numbers are shared with swift/overlays/Accelerate/BNNSGraph.swift */
enum {
    GOP_ARG = 1, GOP_CONST, GOP_PICK,
    GOP_UNARY = 10,       /* ia[0] = unary function, f[0..1] = alpha / beta (or epsilon) */
    GOP_BINARY,           /* ia[0] = binary function */
    GOP_SELECT,           /* cond, a, b */
    GOP_FMA,              /* x * y + z */
    GOP_REDUCE,           /* ia[0] = reduction, ia[1] = keep, ia[2] = count, ia[3..] = axes */
    GOP_ARGREDUCE,        /* ia[0] = 0 min / 1 max, ia[1] = axis, ia[2] = keep */
    GOP_ARGSORT,          /* ia[0] = axis, ia[1] = descending */
    GOP_TOPK,             /* ia[0] = k, ia[1] = axis, ia[2] = largest; outputs values, indices */
    GOP_CUMSUM,           /* ia[0] = axis */
    GOP_SOFTMAX,          /* ia[0] = axis, ia[1] = log */
    GOP_MATMUL,           /* a, b[, bias]; ia[0] = transposeA, ia[1] = transposeB */
    GOP_LINEAR,           /* x, weight[, bias]: x · weightᵀ + bias */
    GOP_CONV,             /* x, w[, bias]; ia: 0 transposed, 1 groups, 2 padding kind, 3 spatial count, then strides, dilations,
                             custom padding (2 per spatial dimension), output padding */
    GOP_POOL,             /* x; ia: 0 function (0 max, 1 average, 2 average with padding, 3 l2), 1 ceil, 2 padding kind,
                             3 spatial count, then kernel, strides, custom padding */
    GOP_NORM,             /* x[, a, b, c, d]; ia[0] = kind, ia[1] = count, ia[2..] = axes; f[0] = epsilon */
    GOP_PRELU,            /* x; f... in constant input 1 */
    GOP_RESHAPE,          /* x; ia[0] = rank, ia[1..] = shape (-1 infers one dimension) */
    GOP_RESHAPE_DYN,      /* x, shape tensor (must be a constant) */
    GOP_TRANSPOSE,        /* x; ia = permutation */
    GOP_SHAPEOF,          /* x -> Int32 vector */
    GOP_SLICE,            /* x; ia: per dimension (start, end, step, squeeze) quads */
    GOP_SLICE_SET,        /* x, value; ia as GOP_SLICE */
    GOP_PAD,              /* x; ia[0] = mode (0 constant, 1 reflect, 2 replicate), ia[1] = count, then (before, after) pairs
                             for the last dimensions; f[0] = value */
    GOP_CONCAT,           /* inputs...; ia[0] = axis */
    GOP_GATHER,           /* x, indices; ia[0] = axis, ia[1] = batch dimensions */
    GOP_GATHER_AXIS,      /* x, indices; ia[0] = axis */
    GOP_GATHER_ND,        /* x, indices; ia[0] = batch dimensions */
    GOP_SCATTER,          /* x, updates, indices; ia[0] = axis, ia[1] = mode */
    GOP_SCATTER_AXIS,     /* x, updates, indices; ia[0] = axis, ia[1] = mode */
    GOP_SCATTER_ND,       /* x, updates, indices; ia[0] = mode */
    GOP_CAST,             /* x -> dtype */
    GOP_RNN,              /* x, h0, wih, whh, bias; ia: 0 reverse, 1 activation, 2 sequence */
    GOP_GRU,              /* x, h0, wih, whh, bias, input bias; ia: 0 reverse, 1 activation, 2 recurrent activation, 3 reset after,
                             4 sequence */
    GOP_LSTM,             /* x, h0, c0, wih, whh, bias[, wih back, whh back, bias back]; ia: 0 reverse, 1 activation, 2 recurrent,
                             3 cell, 4 sequence, 5 bidirectional */
};

typedef struct gnode {
    int op, nin, in[GMAXIN];
    float f[8]; int nf;
    long long ia[GMAXIA]; int nia;
    BNNSDataType dtype;
    gshape shape, shape2, shape3;   /* outputs (multi-output operations use 2 and 3) */
    char *name; int intent;         /* arguments */
    float *cdata;                   /* constants */
} gnode;

typedef struct bn_graph {
    unsigned magic; int refs;
    int n, cap; gnode *nodes;
    int n_in, *in_args;             /* the input arguments, in order */
    int n_out, *outs;               /* the returned nodes (the output arguments, first) */
    int n_out_names; char **out_names;
    gshape *dyn;                    /* per input argument: a shape set by BNNSGraphContextSetDynamicShapes, or rank 0 */
} bn_graph;

typedef struct bn_gctx {
    unsigned magic;
    bn_graph *g;
    BNNSGraphArgumentType argtype;
    int nan_checks;
    gshape *dyn;
    long long batch;
    size_t advance;
    bnns_graph_execute_message_fn_t log; bnns_user_message_data_t *log_data; uint32_t log_mask;
} bn_gctx;

typedef struct bn_gopts {
    unsigned magic;
    bool single_thread, debug_info;
    BNNSGraphOptimizationPreference pref;
    char *output_path; int output_fd;
    bnns_graph_compile_message_fn_t log; bnns_user_message_data_t *log_data; uint32_t log_mask;
} bn_gopts;

/* shape inference for every node; dyn: shapes for the input arguments (rank 0: the declared one), or NULL */
int graph_infer(bn_graph *g, const gshape *dyn);
/* run: in[k] = dense data of input argument k (shapes from inference); outputs allocated in out[k] (malloc) */
int graph_run(bn_graph *g, float **in, float **out, const gshape *dyn);

/* the Swift overlay's entry points */
bn_graph *_isim_bnns_graph_new(void);
int _isim_bnns_graph_argument(bn_graph *g, const char *name, BNNSDataType t, int rank, const long long *shape, int intent);
int _isim_bnns_graph_constant(bn_graph *g, BNNSDataType t, int rank, const long long *shape, const float *values);
int _isim_bnns_graph_op(bn_graph *g, int op, int nin, const int *inputs, int nf, const float *f, int ni, const long long *ia, BNNSDataType t);
int _isim_bnns_graph_pick(bn_graph *g, int node, int k, BNNSDataType t);
int _isim_bnns_graph_set_outputs(bn_graph *g, int count, const int *nodes);
int _isim_bnns_graph_node_shape(bn_graph *g, int node, int *rank, long long *shape);
bnns_graph_t _isim_bnns_graph_finish(bn_graph *g);
void _isim_bnns_graph_release(bn_graph *g);
