// isim Accelerate BNNSGraph (issue #824): bnns_graph.h's C API over isim's graph engine: compile options, graph queries,
// contexts and execution. BNNSGraphCompileFromFile cannot read Apple's compiled formats (undocumented): it fails cleanly.
#include "bnns_core.h"
#include "bnns_graph_engine.h"
#include <stdint.h>
#include <stdio.h>

#define GR_MAGIC 0x47524148u
#define CX_MAGIC 0x47435458u
#define OPT_MAGIC 0x474f5054u

static bn_graph *graph_of(bnns_graph_t g) { bn_graph *p = g.data; return p && p->magic == GR_MAGIC ? p : NULL; }
static bn_gctx *ctx_of(bnns_graph_context_t c) { bn_gctx *p = c.data; return p && p->magic == CX_MAGIC ? p : NULL; }
static bn_gopts *opts_of(bnns_graph_compile_options_t o) { bn_gopts *p = o.data; return p && p->magic == OPT_MAGIC ? p : NULL; }
static long long gcount(const gshape *s) { long long n = 1; for (int k = 0; k < s->rank; k++) n *= s->d[k]; return n; }
/* only one function ("main") per graph: NULL, "" or "main" name it */
static int function_ok(const char *f) { return !f || !*f || !strcmp(f, "main"); }

/* ---- compile options ---- */
bnns_graph_compile_options_t BNNSGraphCompileOptionsMakeDefault(void) {
    bnns_graph_compile_options_t o = { NULL, 0 };
    bn_gopts *p = calloc(1, sizeof *p);
    if (!p) return o;
    p->magic = OPT_MAGIC; p->output_fd = -1; p->log_mask = BNNSGraphMessageLevelError | BNNSGraphMessageLevelUnsupported;
    o.data = p; o.size = sizeof *p;
    return o;
}
void BNNSGraphCompileOptionsDestroy(bnns_graph_compile_options_t options) {
    bn_gopts *p = opts_of(options);
    if (!p) return;
    free(p->output_path); p->magic = 0; free(p);
}
void BNNSGraphCompileOptionsSetTargetSingleThread(bnns_graph_compile_options_t options, bool value) { bn_gopts *p = opts_of(options); if (p) p->single_thread = value; }
bool BNNSGraphCompileOptionsGetTargetSingleThread(const bnns_graph_compile_options_t options) { bn_gopts *p = opts_of(options); return p && p->single_thread; }
void BNNSGraphCompileOptionsSetGenerateDebugInfo(bnns_graph_compile_options_t options, bool value) { bn_gopts *p = opts_of(options); if (p) p->debug_info = value; }
bool BNNSGraphCompileOptionsGetGenerateDebugInfo(const bnns_graph_compile_options_t options) { bn_gopts *p = opts_of(options); return p && p->debug_info; }
void BNNSGraphCompileOptionsSetOptimizationPreference(bnns_graph_compile_options_t options, BNNSGraphOptimizationPreference preference) {
    bn_gopts *p = opts_of(options); if (p) p->pref = preference;
}
BNNSGraphOptimizationPreference BNNSGraphCompileOptionsGetOptimizationPreference(bnns_graph_compile_options_t options) {
    bn_gopts *p = opts_of(options); return p ? p->pref : BNNSGraphOptimizationPreferencePerformance;
}
void BNNSGraphCompileOptionsSetMessageLogCallback(bnns_graph_compile_options_t options, bnns_graph_compile_message_fn_t log_callback,
                                                  bnns_user_message_data_t *additional_logging_arguments) {
    bn_gopts *p = opts_of(options); if (p) { p->log = log_callback; p->log_data = additional_logging_arguments; }
}
void BNNSGraphCompileOptionsSetMessageLogMask(bnns_graph_compile_options_t options, uint32_t log_level_mask) {
    bn_gopts *p = opts_of(options); if (p) p->log_mask = log_level_mask;
}
void BNNSGraphCompileOptionsSetOutputPath(bnns_graph_compile_options_t options, char const *path) {
    bn_gopts *p = opts_of(options);
    if (!p) return;
    free(p->output_path); p->output_path = path ? strdup(path) : NULL;
}
char const *BNNSGraphCompileOptionsGetOutputPath(bnns_graph_compile_options_t options) { bn_gopts *p = opts_of(options); return p ? p->output_path : NULL; }
void BNNSGraphCompileOptionsSetOutputFD(bnns_graph_compile_options_t options, int fd) { bn_gopts *p = opts_of(options); if (p) p->output_fd = fd; }
int BNNSGraphCompileOptionsGetOutputFD(bnns_graph_compile_options_t options) { bn_gopts *p = opts_of(options); return p ? p->output_fd : -1; }

bnns_graph_t BNNSGraphCompileFromFile(const char *filename, const char *function, bnns_graph_compile_options_t options) {
    (void)function;
    bnns_graph_t none = { NULL, 0 };
    bn_gopts *p = opts_of(options);
    char msg[512];
    snprintf(msg, sizeof msg, "isim cannot compile '%s': the formats of Apple's compiled models (.mlmodelc, .mlpackage, .bnnsir) are not "
             "documented; build the graph in code with BNNSGraph.Builder", filename ? filename : "(null)");
    if (p && p->log && (p->log_mask & BNNSGraphMessageLevelError)) p->log(BNNSGraphMessageLevelError, msg, NULL, p->log_data);
    return none;
}

/* ---- graph queries ---- */
size_t BNNSGraphGetFunctionCount(bnns_graph_t graph) { return graph_of(graph) ? 1 : 0; }
int BNNSGraphGetFunctionNames(bnns_graph_t graph, size_t function_name_count, char const **function_names) {
    if (!graph_of(graph)) return -1;
    if (function_name_count) function_names[0] = "main";
    return 0;
}
size_t BNNSGraphGetInputCount(bnns_graph_t graph, const char *function) {
    bn_graph *g = graph_of(graph); return g && function_ok(function) ? (size_t)g->n_in : 0;
}
size_t BNNSGraphGetOutputCount(bnns_graph_t graph, const char *function) {
    bn_graph *g = graph_of(graph); return g && function_ok(function) ? (size_t)g->n_out : 0;
}
size_t BNNSGraphGetArgumentCount(bnns_graph_t graph, const char *function) {
    bn_graph *g = graph_of(graph); return g && function_ok(function) ? (size_t)(g->n_out + g->n_in) : 0;
}
int BNNSGraphGetInputNames(bnns_graph_t graph, const char *function, size_t input_names_count, char const **input_names) {
    bn_graph *g = graph_of(graph);
    if (!g || !function_ok(function)) return -1;
    for (size_t k = 0; k < input_names_count && (int)k < g->n_in; k++) input_names[k] = g->nodes[g->in_args[k]].name;
    return 0;
}
int BNNSGraphGetOutputNames(bnns_graph_t graph, const char *function, size_t output_names_count, char const **output_names) {
    bn_graph *g = graph_of(graph);
    if (!g || !function_ok(function)) return -1;
    for (size_t k = 0; k < output_names_count && (int)k < g->n_out; k++) output_names[k] = g->out_names[k];
    return 0;
}
static const char *arg_name(bn_graph *g, int k) { return k < g->n_out ? g->out_names[k] : g->nodes[g->in_args[k - g->n_out]].name; }
int BNNSGraphGetArgumentNames(bnns_graph_t graph, const char *function, size_t argument_names_count, char const **argument_names) {
    bn_graph *g = graph_of(graph);
    if (!g || !function_ok(function)) return -1;
    for (size_t k = 0; k < argument_names_count && (int)k < g->n_out + g->n_in; k++) argument_names[k] = arg_name(g, (int)k);
    return 0;
}
int BNNSGraphGetArgumentIntents(bnns_graph_t graph, const char *function, size_t argument_intents_count, BNNSGraphArgumentIntent *argument_intents) {
    bn_graph *g = graph_of(graph);
    if (!g || !function_ok(function)) return -1;
    for (size_t k = 0; k < argument_intents_count && (int)k < g->n_out + g->n_in; k++)
        argument_intents[k] = (int)k < g->n_out ? BNNSGraphArgumentIntentOut : (BNNSGraphArgumentIntent)g->nodes[g->in_args[k - g->n_out]].intent;
    return 0;
}
size_t BNNSGraphGetArgumentPosition(const bnns_graph_t graph, const char *function, const char *argument) {
    bn_graph *g = graph_of(graph);
    if (!g || !function_ok(function) || !argument) return SIZE_MAX;
    for (int k = 0; k < g->n_out + g->n_in; k++) if (!strcmp(arg_name(g, k), argument)) return (size_t)k;
    return SIZE_MAX;
}
int BNNSGraphGetArgumentInterleaveFactors(bnns_graph_t graph, const char *function, size_t argument_count,
                                          const uint16_t **argument_interleave, size_t *argument_interleave_counts) {
    bn_graph *g = graph_of(graph);
    if (!g || !function_ok(function)) return -1;
    for (size_t k = 0; k < argument_count; k++) { argument_interleave[k] = NULL; argument_interleave_counts[k] = 0; }   /* no interleaving */
    return 0;
}

/* the node of an argument position, and its shape (with the context's dynamic shapes) */
static gnode *arg_node(bn_graph *g, int k) { return &g->nodes[k < g->n_out ? g->outs[k] : g->in_args[k - g->n_out]]; }
static void fill_tensor(bn_graph *g, int k, BNNSTensor *t, int with_shape) {
    gnode *n = arg_node(g, k);
    t->data_type = n->dtype;
    t->rank = (uint8_t)n->shape.rank;
    long long s = 1;
    for (int d = n->shape.rank - 1; d >= 0; d--) {
        if (with_shape) t->shape[d] = (ssize_t)n->shape.d[d];
        t->stride[d] = (ssize_t)s;
        s *= t->shape[d] > 0 ? t->shape[d] : 1;
    }
    t->name = arg_name(g, k);
}
int BNNSGraphTensorFillStrides(bnns_graph_t graph, const char *function, const char *argument, BNNSTensor *tensor) {
    bn_graph *g = graph_of(graph);
    size_t k = BNNSGraphGetArgumentPosition(graph, function, argument);
    if (!g || k == SIZE_MAX || !tensor) return -1;
    long long s = 1;
    for (int d = tensor->rank - 1; d >= 0; d--) { tensor->stride[d] = (ssize_t)s; s *= tensor->shape[d] > 0 ? tensor->shape[d] : 1; }
    return 0;
}

/* ---- contexts ---- */
bnns_graph_context_t BNNSGraphContextMake(const bnns_graph_t graph) {
    bnns_graph_context_t c = { NULL, 0 };
    bn_graph *g = graph_of(graph);
    if (!g) return c;
    bn_gctx *x = calloc(1, sizeof *x);
    if (!x) return c;
    x->magic = CX_MAGIC; x->g = g; g->refs++;
    x->argtype = BNNSGraphArgumentTypePointer;
    x->dyn = calloc((size_t)(g->n_in ? g->n_in : 1), sizeof(gshape));
    x->log_mask = BNNSGraphMessageLevelError;
    c.data = x; c.size = sizeof *x;
    return c;
}
bnns_graph_context_t BNNSGraphContextMakeStreaming(bnns_graph_t graph, const char *function, size_t initial_states_count,
                                                   BNNSTensor const *initial_states) {
    (void)initial_states_count; (void)initial_states;
    if (!function_ok(function)) { bnns_graph_context_t c = { NULL, 0 }; return c; }
    return BNNSGraphContextMake(graph);   /* isim's graphs carry no streaming state */
}
void BNNSGraphContextDestroy(bnns_graph_context_t context) {
    bn_gctx *x = ctx_of(context);
    if (!x) return;
    _isim_bnns_graph_release(x->g);
    free(x->dyn); x->magic = 0; free(x);
}
int BNNSGraphContextSetDynamicShapes(bnns_graph_context_t context, char const *function, size_t shapes_count, bnns_graph_shape_t *shapes) {
    bn_gctx *x = ctx_of(context);
    if (!x || !function_ok(function) || !shapes) return -1;
    bn_graph *g = x->g;
    /* shapes are given for every argument position (outputs first): take the inputs' */
    for (size_t k = 0; k < shapes_count; k++) {
        int pos = (int)k - g->n_out;
        if (pos < 0 || pos >= g->n_in || !shapes[k].shape) continue;
        gshape s = { (int)shapes[k].rank, {0} };
        for (int d = 0; d < s.rank && d < GMAXR; d++) s.d[d] = (long long)shapes[k].shape[d];
        x->dyn[pos] = s;
    }
    if (graph_infer(g, x->dyn)) return -1;
    for (size_t k = 0; k < shapes_count && (int)k < g->n_out + g->n_in; k++) {   /* report the resolved shapes back */
        gnode *n = arg_node(g, (int)k);
        if (!shapes[k].shape) continue;
        for (int d = 0; d < n->shape.rank && (size_t)d < shapes[k].rank; d++) shapes[k].shape[d] = (uint64_t)n->shape.d[d];
    }
    return 0;
}
int BNNSGraphContextSetBatchSize(bnns_graph_context_t context, char const *function, uint64_t batch_size) {
    bn_gctx *x = ctx_of(context);
    if (!x || !function_ok(function)) return -1;
    x->batch = (long long)batch_size;
    /* a batch size replaces the first dimension of every input */
    for (int k = 0; k < x->g->n_in; k++) {
        gnode *n = &x->g->nodes[x->g->in_args[k]];
        x->dyn[k] = n->shape;
        if (x->dyn[k].rank) x->dyn[k].d[0] = (long long)batch_size;
    }
    return graph_infer(x->g, x->dyn) ? -1 : 0;
}
int BNNSGraphContextSetArgumentType(bnns_graph_context_t context, BNNSGraphArgumentType argument_type) {
    bn_gctx *x = ctx_of(context);
    if (!x || (argument_type != BNNSGraphArgumentTypePointer && argument_type != BNNSGraphArgumentTypeTensor)) return -1;
    x->argtype = argument_type;
    return 0;
}
void BNNSGraphContextEnableNanAndInfChecks(bnns_graph_context_t context, bool enable_check_for_nans_inf) {
    bn_gctx *x = ctx_of(context); if (x) x->nan_checks = enable_check_for_nans_inf;
}
int BNNSGraphContextSetStreamingAdvanceCount(const bnns_graph_context_t context, size_t advance_count) {
    bn_gctx *x = ctx_of(context); if (!x) return -1; x->advance = advance_count; return 0;
}
size_t BNNSGraphContextGetWorkspaceSize(bnns_graph_context_t context, const char *function) {
    (void)function; return ctx_of(context) ? 0 : SIZE_MAX;   /* isim allocates its own scratch */
}
int BNNSGraphContextSetWorkspaceAllocationCallback(bnns_graph_context_t context, bnns_graph_realloc_fn_t realloc_fn, bnns_graph_free_all_fn_t free_fn,
                                                   size_t user_memory_context_size, void *user_memory_context) {
    (void)realloc_fn; (void)free_fn; (void)user_memory_context_size; (void)user_memory_context;
    return ctx_of(context) ? 0 : -1;
}
int BNNSGraphContextSetOutputAllocationCallback(bnns_graph_context_t context, bnns_graph_realloc_fn_t realloc_fn, bnns_graph_free_all_fn_t free_fn,
                                                size_t user_memory_context_size, void *user_memory_context) {
    (void)realloc_fn; (void)free_fn; (void)user_memory_context_size; (void)user_memory_context;
    return ctx_of(context) ? 0 : -1;
}
int BNNSGraphContextSetMessageLogCallback(bnns_graph_context_t context, bnns_graph_execute_message_fn_t log_callback_fn,
                                          bnns_user_message_data_t *additional_logging_arguments) {
    bn_gctx *x = ctx_of(context);
    if (!x) return -1;
    x->log = log_callback_fn; x->log_data = additional_logging_arguments;
    return 0;
}
int BNNSGraphContextSetMessageLogMask(bnns_graph_context_t context, uint32_t log_level_mask) {
    bn_gctx *x = ctx_of(context); if (!x) return -1; x->log_mask = log_level_mask; return 0;
}
int BNNSGraphContextGetTensor(bnns_graph_context_t context, const char *function, const char *argument, bool fill_known_dynamic_shapes,
                              BNNSTensor *tensor) {
    bn_gctx *x = ctx_of(context);
    if (!x || !tensor) return -1;
    size_t k = BNNSGraphGetArgumentPosition((bnns_graph_t){ x->g, sizeof *x->g }, function, argument);
    if (k == SIZE_MAX) return -1;
    if (graph_infer(x->g, x->dyn)) return -1;
    memset(tensor, 0, sizeof *tensor);
    (void)fill_known_dynamic_shapes;
    fill_tensor(x->g, (int)k, tensor, 1);
    return 0;
}

/* ---- execution ---- */
static void ctx_log(bn_gctx *x, BNNSGraphMessageLevel lvl, const char *msg) {
    if (x->log && (x->log_mask & lvl)) x->log(lvl, msg, NULL, x->log_data);
}
/* read an argument into a dense float buffer (shape: the node's, or the tensor's) */
static float *read_arg(bn_gctx *x, bnns_graph_argument_t *a, gnode *n, gshape *got) {
    BNNSNDArrayDescriptor d = {0};
    d.data_type = n->dtype; d.data_scale = 1;
    if (x->argtype == BNNSGraphArgumentTypeTensor) {
        BNNSTensor *t = a->tensor;
        if (!t || !t->data) return NULL;
        got->rank = t->rank;
        for (int k = 0; k < t->rank; k++) got->d[k] = t->shape[k];
        long long c = gcount(got), pos[GMAXR];
        float *v = malloc((size_t)(c ? c : 1) * sizeof(float));
        if (!v) return NULL;
        d.data_type = t->data_type;
        for (long long i = 0; i < c; i++) {
            long long r = i, off = 0;
            for (int k = t->rank - 1; k >= 0; k--) { pos[k] = r % got->d[k]; r /= got->d[k]; off += pos[k] * t->stride[k]; }
            v[i] = bn_read(&d, t->data, (size_t)off);
        }
        return v;
    }
    if (!a->data_ptr) return NULL;
    *got = n->shape;
    long long c = gcount(got);
    if (a->data_ptr_size && a->data_ptr_size < (size_t)(c * bn_type_bits(n->dtype) / 8)) return NULL;
    float *v = malloc((size_t)(c ? c : 1) * sizeof(float));
    if (!v) return NULL;
    for (long long i = 0; i < c; i++) v[i] = bn_read(&d, a->data_ptr, (size_t)i);
    return v;
}
static int write_arg(bn_gctx *x, bnns_graph_argument_t *a, gnode *n, const float *v) {
    BNNSNDArrayDescriptor d = {0};
    d.data_type = n->dtype; d.data_scale = 1;
    long long c = gcount(&n->shape);
    if (x->argtype == BNNSGraphArgumentTypeTensor) {
        BNNSTensor *t = a->tensor;
        if (!t || !t->data) return -1;
        d.data_type = t->data_type ? t->data_type : n->dtype;
        long long pos[GMAXR];
        for (long long i = 0; i < c; i++) {
            long long r = i, off = 0;
            for (int k = n->shape.rank - 1; k >= 0; k--) {
                pos[k] = r % n->shape.d[k]; r /= n->shape.d[k];
                off += pos[k] * (k < t->rank && t->stride[k] > 0 ? t->stride[k] : 0);
            }
            bn_write(&d, t->data, (size_t)off, v[i]);
        }
        t->rank = (uint8_t)n->shape.rank;
        for (int k = 0; k < n->shape.rank; k++) t->shape[k] = (ssize_t)n->shape.d[k];
        return 0;
    }
    if (!a->data_ptr) return -1;
    if (a->data_ptr_size && a->data_ptr_size < (size_t)(c * bn_type_bits(n->dtype) / 8)) return -1;
    for (long long i = 0; i < c; i++) bn_write(&d, a->data_ptr, (size_t)i, v[i]);
    return 0;
}
int BNNSGraphContextExecute(bnns_graph_context_t context, const char *function, size_t argument_count, bnns_graph_argument_t *arguments,
                            size_t workspace_size, char *workspace) {
    (void)workspace_size; (void)workspace;
    bn_gctx *x = ctx_of(context);
    if (!x || !function_ok(function) || !arguments) return -1;
    bn_graph *g = x->g;
    if ((int)argument_count < g->n_out + g->n_in) { ctx_log(x, BNNSGraphMessageLevelError, "too few arguments"); return -1; }
    if (graph_infer(g, x->dyn)) { ctx_log(x, BNNSGraphMessageLevelError, "the graph's shapes do not resolve"); return -1; }
    float **in = calloc((size_t)(g->n_in ? g->n_in : 1), sizeof(float *)), **out = calloc((size_t)(g->n_out ? g->n_out : 1), sizeof(float *));
    gshape *shapes = calloc((size_t)(g->n_in ? g->n_in : 1), sizeof(gshape));
    int r = (in && out && shapes) ? 0 : -1;
    for (int k = 0; k < g->n_in && !r; k++) {
        gnode *n = &g->nodes[g->in_args[k]];
        in[k] = read_arg(x, &arguments[g->n_out + k], n, &shapes[k]);
        if (!in[k]) { ctx_log(x, BNNSGraphMessageLevelError, "an input argument has no data"); r = -1; }
    }
    /* tensor arguments may carry new shapes */
    if (!r && x->argtype == BNNSGraphArgumentTypeTensor) r = graph_infer(g, shapes);
    if (!r) r = graph_run(g, in, out, x->argtype == BNNSGraphArgumentTypeTensor ? shapes : x->dyn);
    if (!r && x->nan_checks)
        for (int k = 0; k < g->n_out; k++) {
            long long c = gcount(&g->nodes[g->outs[k]].shape);
            for (long long i = 0; i < c; i++) if (!isfinite(out[k][i])) { ctx_log(x, BNNSGraphMessageLevelError, "NaN or infinity in an output"); r = -1; break; }
        }
    for (int k = 0; k < g->n_out && !r; k++) r = write_arg(x, &arguments[k], &g->nodes[g->outs[k]], out[k]);
    /* in-out arguments: written back with their (unchanged) values; isim's graphs do not update them in place */
    for (int k = 0; k < g->n_in; k++) free(in[k]);
    for (int k = 0; k < g->n_out; k++) free(out[k]);
    free(in); free(out); free(shapes);
    return r;
}
