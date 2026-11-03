// isim Accelerate BNNSGraph (issue #824): isim's own graph engine. A graph is a list of nodes (arguments, constants and
// operations, each after its inputs) that the Swift BNNSGraph.Builder fills through the _isim_bnns_graph_* entry points;
// a context runs it over dense float tensors (row-major, the last dimension fastest, like BNNSTensor) and converts
// at the arguments. Apple's compiled model formats (.mlmodelc, .mlpackage, .bnnsir) are undocumented, so
// BNNSGraphCompileFromFile fails cleanly with a message.
#include "bnns_core.h"
#include "bnns_graph_engine.h"
#include <stdint.h>
#include <stdio.h>

#define GR_MAGIC 0x47524148u

/* ---- shapes ---- */
static long long gcount(const gshape *s) { long long n = 1; for (int k = 0; k < s->rank; k++) n *= s->d[k]; return n; }
/* ---- graph objects ---- */

bn_graph *_isim_bnns_graph_new(void) {
    bn_graph *g = calloc(1, sizeof *g);
    if (!g) return NULL;
    g->magic = GR_MAGIC; g->refs = 1;
    return g;
}
static gnode *add_node(bn_graph *g) {
    if (g->n == g->cap) {
        int nc = g->cap ? 2 * g->cap : 32;
        gnode *nn = realloc(g->nodes, (size_t)nc * sizeof(gnode));
        if (!nn) return NULL;
        g->nodes = nn; g->cap = nc;
    }
    gnode *n = &g->nodes[g->n++];
    memset(n, 0, sizeof *n);
    n->dtype = BNNSDataTypeFloat32;
    return n;
}
int _isim_bnns_graph_argument(bn_graph *g, const char *name, BNNSDataType t, int rank, const long long *shape, int intent) {
    gnode *n = add_node(g);
    if (!n || rank > GMAXR) return -1;
    n->op = GOP_ARG; n->dtype = t; n->shape.rank = rank;
    for (int k = 0; k < rank; k++) n->shape.d[k] = shape[k];
    char buf[32];
    if (!name) { snprintf(buf, sizeof buf, "arg_%d", g->n_in); name = buf; }
    n->name = strdup(name); n->intent = intent ? intent : BNNSGraphArgumentIntentIn;
    int *na = realloc(g->in_args, (size_t)(g->n_in + 1) * sizeof(int));
    if (!na) return -1;
    g->in_args = na; g->in_args[g->n_in++] = g->n - 1;
    return g->n - 1;
}
int _isim_bnns_graph_constant(bn_graph *g, BNNSDataType t, int rank, const long long *shape, const float *values) {
    gnode *n = add_node(g);
    if (!n || rank > GMAXR) return -1;
    n->op = GOP_CONST; n->dtype = t; n->shape.rank = rank;
    for (int k = 0; k < rank; k++) n->shape.d[k] = shape[k];
    long long c = gcount(&n->shape);
    n->cdata = malloc((size_t)(c ? c : 1) * sizeof(float));
    if (!n->cdata) return -1;
    memcpy(n->cdata, values, (size_t)c * sizeof(float));
    return g->n - 1;
}
int _isim_bnns_graph_op(bn_graph *g, int op, int nin, const int *inputs, int nf, const float *f, int ni, const long long *ia,
                        BNNSDataType t) {
    gnode *n = add_node(g);
    if (!n || nin > GMAXIN || nf > 8 || ni > GMAXIA) return -1;
    n->op = op; n->nin = nin; n->dtype = t;
    for (int k = 0; k < nin; k++) { if (inputs[k] < 0 || inputs[k] >= g->n - 1) return -1; n->in[k] = inputs[k]; }
    for (int k = 0; k < nf; k++) n->f[k] = f[k];
    for (int k = 0; k < ni; k++) n->ia[k] = ia[k];
    n->nf = nf; n->nia = ni;
    return g->n - 1;
}
/* output k of a multi-output node */
int _isim_bnns_graph_pick(bn_graph *g, int node, int k, BNNSDataType t) {
    long long kk = k;
    return _isim_bnns_graph_op(g, GOP_PICK, 1, &node, 0, NULL, 1, &kk, t);
}
int _isim_bnns_graph_set_outputs(bn_graph *g, int count, const int *nodes) {
    free(g->outs);
    g->outs = malloc((size_t)(count ? count : 1) * sizeof(int));
    if (!g->outs) return -1;
    g->n_out = count;
    for (int k = 0; k < count; k++) g->outs[k] = nodes[k];
    for (int k = 0; k < g->n_out_names; k++) free(g->out_names[k]);
    free(g->out_names);
    g->out_names = calloc((size_t)(count ? count : 1), sizeof(char *));
    g->n_out_names = count;
    for (int k = 0; k < count; k++) {
        char buf[32]; snprintf(buf, sizeof buf, "output_%d", k);
        g->out_names[k] = strdup(buf);
    }
    return 0;
}
/* the shape a node has once the graph's argument shapes are known (dyn: shapes for the input arguments, or NULL) */
int _isim_bnns_graph_node_shape(bn_graph *g, int node, int *rank, long long *shape) {
    if (!g || node < 0 || node >= g->n) return -1;
    if (graph_infer(g, NULL) != 0) return -1;
    *rank = g->nodes[node].shape.rank;
    for (int k = 0; k < *rank; k++) shape[k] = g->nodes[node].shape.d[k];
    return 0;
}
bnns_graph_t _isim_bnns_graph_finish(bn_graph *g) {
    bnns_graph_t r = { NULL, 0 };
    if (!g || graph_infer(g, NULL) != 0) return r;
    r.data = g; r.size = sizeof *g;
    return r;
}
void _isim_bnns_graph_release(bn_graph *g) {
    if (!g || --g->refs > 0) return;
    for (int k = 0; k < g->n; k++) { free(g->nodes[k].name); free(g->nodes[k].cdata); }
    for (int k = 0; k < g->n_out_names; k++) free(g->out_names[k]);
    free(g->nodes); free(g->in_args); free(g->outs); free(g->out_names);
    g->magic = 0;
    free(g);
}
