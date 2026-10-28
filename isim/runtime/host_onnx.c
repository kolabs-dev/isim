/*
 * isim host ONNX models for Vision (issue #375): pose, hand, person segmentation and image classification models that
 * an app's Vision requests run on the host with ONNX Runtime, loaded with dlopen only when a request needs one. The
 * library is ISIM_ONNXRUNTIME (a path) or the host's libonnxruntime; the models are named by the ISIM_*_MODEL
 * variables isim's Vision reads. One float or int32 image tensor goes in (the caller shapes it: NHWC or NCHW), and the
 * outputs come back as floats. ONNX Runtime's C API is used through its versioned function table (OrtApi, append-only),
 * as in host_sound.c: only the entries below are declared, at their indexes in onnxruntime_c_api.h.
 */
#include "guest_abi.h"
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* the host's ONNX Runtime library names (a port lists its own: onnxruntime.dll, libonnxruntime.dylib) */
static const char *const ORT_LIBRARIES[] = { "libonnxruntime.so.1", "libonnxruntime.so" };

typedef struct OrtStatus OrtStatus;
typedef void *OrtFn;
typedef struct { const void *(*GetApi)(uint32_t version); const char *(*GetVersionString)(void); } OrtApiBase;
enum { ORT_API_VERSION_USED = 14 };
enum {
    ORT_GetErrorMessage = 2, ORT_CreateEnv = 3, ORT_CreateSession = 7, ORT_Run = 9, ORT_CreateSessionOptions = 10,
    ORT_SetIntraOpNumThreads = 24, ORT_SessionGetInputCount = 30, ORT_SessionGetOutputCount = 31, ORT_SessionGetInputTypeInfo = 33,
    ORT_SessionGetInputName = 36, ORT_SessionGetOutputName = 37, ORT_CreateTensorWithDataAsOrtValue = 49,
    ORT_GetTensorMutableData = 51, ORT_CastTypeInfoToTensorInfo = 55, ORT_GetTensorElementType = 60, ORT_GetDimensionsCount = 61,
    ORT_GetDimensions = 62, ORT_GetTensorTypeAndShape = 65, ORT_CreateCpuMemoryInfo = 69, ORT_GetAllocatorWithDefaultOptions = 78,
    ORT_ReleaseStatus = 93, ORT_ReleaseMemoryInfo = 94, ORT_ReleaseValue = 96, ORT_ReleaseTypeInfo = 98,
    ORT_ReleaseTensorTypeAndShapeInfo = 99, ORT_ReleaseSessionOptions = 100,
};
enum { ORT_LOGGING_LEVEL_ERROR = 3, ORT_FLOAT = 1, ORT_UINT8 = 2, ORT_INT32 = 6, ORT_DEVICE_ALLOCATOR = 0, ORT_MEM_DEFAULT = 0 };
enum { MAX_MODELS = 8, MAX_OUTPUTS = 8 };

static const OrtFn *ort;
static void *ort_env;
static pthread_mutex_t onnx_mtx = PTHREAD_MUTEX_INITIALIZER;
static char onnx_err[512];

#define F(name, type) ((type)ort[ORT_##name])

static void fail(const char *what, OrtStatus *st) {
    const char *m = st ? F(GetErrorMessage, const char *(*)(const OrtStatus *))(st) : "";
    snprintf(onnx_err, sizeof onnx_err, "%s%s%s", what, *m ? ": " : "", m);
    if (st) F(ReleaseStatus, void (*)(OrtStatus *))(st);
}

static int ort_load(void) {
    if (ort) return 1;
    void *lib = NULL;
    const char *path = getenv("ISIM_ONNXRUNTIME");
    if (path && *path) lib = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    for (size_t i = 0; !lib && i < sizeof ORT_LIBRARIES / sizeof *ORT_LIBRARIES; i++) lib = dlopen(ORT_LIBRARIES[i], RTLD_NOW | RTLD_LOCAL);
    if (!lib) {
        snprintf(onnx_err, sizeof onnx_err, "this needs ONNX Runtime on the host (libonnxruntime, or ISIM_ONNXRUNTIME=path)");
        return 0;
    }
    const OrtApiBase *(*base)(void) = (const OrtApiBase *(*)(void))dlsym(lib, "OrtGetApiBase");
    const OrtFn *api = base ? (const OrtFn *)base()->GetApi(ORT_API_VERSION_USED) : NULL;
    if (!api) { snprintf(onnx_err, sizeof onnx_err, "this ONNX Runtime is too old (1.14 or later is needed)"); return 0; }
    ort = api;
    OrtStatus *st = F(CreateEnv, OrtStatus *(*)(int, const char *, void **))(ORT_LOGGING_LEVEL_ERROR, "isim-vision", &ort_env);
    if (st) { fail("ONNX Runtime could not start", st); ort = NULL; return 0; }
    return 1;
}

typedef struct {
    void *session;
    char *path, *input, *outputs[MAX_OUTPUTS];
    int noutputs, intype, rank;
    int64_t dims[8];
} Model;
static Model models[MAX_MODELS];

/* opens an ONNX model: a handle (1...), or 0 with the reason in isim_onnx_error() */
ISIM_GUEST_ABI int isim_onnx_open(const char *path) {
    pthread_mutex_lock(&onnx_mtx);
    int h = 0;
    if (!ort_load()) goto out;
    for (int i = 0; i < MAX_MODELS; i++) if (models[i].session && !strcmp(path, models[i].path)) { h = i + 1; goto out; }   /* opened before */
    int slot = -1;
    for (int i = 0; i < MAX_MODELS; i++) if (!models[i].session) { slot = i; break; }
    if (slot < 0) { snprintf(onnx_err, sizeof onnx_err, "too many ONNX models"); goto out; }
    void *opts = NULL, *session = NULL, *alloc = NULL;
    OrtStatus *st = F(CreateSessionOptions, OrtStatus *(*)(void **))(&opts);
    if (st) { fail("ONNX Runtime", st); goto out; }
    F(SetIntraOpNumThreads, OrtStatus *(*)(void *, int))(opts, 2);
    st = F(CreateSession, OrtStatus *(*)(void *, const char *, void *, void **))(ort_env, path, opts, &session);
    F(ReleaseSessionOptions, void (*)(void *))(opts);
    if (st) { fail("the model could not be loaded", st); goto out; }
    F(GetAllocatorWithDefaultOptions, OrtStatus *(*)(void **))(&alloc);
    Model m = { session, strdup(path), NULL, { NULL }, 0, ORT_FLOAT, 0, { 0 } };
    char *in = NULL;
    if ((st = F(SessionGetInputName, OrtStatus *(*)(void *, size_t, void *, char **))(session, 0, alloc, &in))) { fail("the model has no input", st); goto out; }
    m.input = strdup(in);
    size_t nout = 0;
    F(SessionGetOutputCount, OrtStatus *(*)(void *, size_t *))(session, &nout);
    for (size_t i = 0; i < nout && i < MAX_OUTPUTS; i++) {
        char *o = NULL;
        if (!F(SessionGetOutputName, OrtStatus *(*)(void *, size_t, void *, char **))(session, i, alloc, &o) && o) m.outputs[m.noutputs++] = strdup(o);
    }
    /* the input's element type and shape (-1 for dynamic dimensions) */
    void *type = NULL; const void *tensor = NULL;
    if (!F(SessionGetInputTypeInfo, OrtStatus *(*)(void *, size_t, void **))(session, 0, &type) && type) {
        if (!F(CastTypeInfoToTensorInfo, OrtStatus *(*)(const void *, const void **))(type, &tensor) && tensor) {
            size_t rank = 0;
            F(GetTensorElementType, OrtStatus *(*)(const void *, int *))(tensor, &m.intype);
            F(GetDimensionsCount, OrtStatus *(*)(const void *, size_t *))(tensor, &rank);
            if (rank > 8) rank = 8;
            F(GetDimensions, OrtStatus *(*)(const void *, int64_t *, size_t))(tensor, m.dims, rank);
            m.rank = (int)rank;
        }
        F(ReleaseTypeInfo, void (*)(void *))(type);
    }
    models[slot] = m;
    h = slot + 1;
out:
    pthread_mutex_unlock(&onnx_mtx);
    return h;
}

/* the model's input shape (rank, dims; dynamic dimensions are -1) and element type (1 float, 2 uint8, 6 int32) */
ISIM_GUEST_ABI int isim_onnx_input(int h, int64_t *dims, int *type) {
    if (h < 1 || h > MAX_MODELS || !models[h - 1].session) return -1;
    Model *m = &models[h - 1];
    memcpy(dims, m->dims, sizeof m->dims);
    *type = m->intype;
    return m->rank;
}

/* runs the model on a float tensor of the given shape (converted to the model's element type); fills out (cap floats)
   with the outputs one after another and, per output, its element count in counts (up to 8); the number of outputs,
   or -1 with the reason in isim_onnx_error() */
ISIM_GUEST_ABI int isim_onnx_run(int h, const float *in, const int64_t *dims, int rank, float *out, long cap, long *counts) {
    pthread_mutex_lock(&onnx_mtx);
    int n = -1;
    void *mem = NULL, *input = NULL, *outputs[MAX_OUTPUTS] = { NULL };
    void *converted = NULL;
    if (!ort || h < 1 || h > MAX_MODELS || !models[h - 1].session) { snprintf(onnx_err, sizeof onnx_err, "no ONNX model"); goto out; }
    Model *m = &models[h - 1];
    long count = 1;
    for (int i = 0; i < rank; i++) count *= dims[i];
    const void *data = in;
    size_t bytes = (size_t)count * sizeof(float);
    if (m->intype == ORT_INT32 || m->intype == ORT_UINT8) {      /* models that take pixel values as integers */
        size_t es = m->intype == ORT_INT32 ? 4 : 1;
        converted = malloc((size_t)count * es);
        if (!converted) { snprintf(onnx_err, sizeof onnx_err, "out of memory"); goto out; }
        for (long i = 0; i < count; i++) {
            float v = in[i] < 0 ? 0 : in[i];
            if (es == 4) ((int32_t *)converted)[i] = (int32_t)(v + 0.5f);
            else ((uint8_t *)converted)[i] = (uint8_t)(v > 255 ? 255 : v + 0.5f);
        }
        data = converted; bytes = (size_t)count * es;
    } else if (m->intype != ORT_FLOAT) { snprintf(onnx_err, sizeof onnx_err, "the model's input is not float, uint8 or int32"); goto out; }
    OrtStatus *st = F(CreateCpuMemoryInfo, OrtStatus *(*)(int, int, void **))(ORT_DEVICE_ALLOCATOR, ORT_MEM_DEFAULT, &mem);
    if (st) { fail("ONNX Runtime", st); goto out; }
    st = F(CreateTensorWithDataAsOrtValue, OrtStatus *(*)(const void *, void *, size_t, const int64_t *, size_t, int, void **))(
        mem, (void *)data, bytes, dims, (size_t)rank, m->intype, &input);
    F(ReleaseMemoryInfo, void (*)(void *))(mem);
    if (st) { fail("ONNX Runtime", st); goto out; }
    const char *in_names[1] = { m->input };
    st = F(Run, OrtStatus *(*)(void *, const void *, const char *const *, const void *const *, size_t, const char *const *, size_t, void **))(
        m->session, NULL, in_names, (const void *const *)&input, 1, (const char *const *)m->outputs, (size_t)m->noutputs, outputs);
    if (st) { fail("the model failed", st); goto out; }
    long used = 0;
    for (int o = 0; o < m->noutputs; o++) {
        void *shape = NULL; size_t nd = 0; int64_t od[8] = { 0 }; int et = 0; void *p = NULL;
        if ((st = F(GetTensorTypeAndShape, OrtStatus *(*)(const void *, void **))(outputs[o], &shape))) { fail("the model's output", st); goto out; }
        F(GetDimensionsCount, OrtStatus *(*)(const void *, size_t *))(shape, &nd);
        if (nd > 8) nd = 8;
        F(GetDimensions, OrtStatus *(*)(const void *, int64_t *, size_t))(shape, od, nd);
        F(GetTensorElementType, OrtStatus *(*)(const void *, int *))(shape, &et);
        F(ReleaseTensorTypeAndShapeInfo, void (*)(void *))(shape);
        long k = 1;
        for (size_t i = 0; i < nd; i++) k *= od[i] > 0 ? (long)od[i] : 1;
        F(GetTensorMutableData, OrtStatus *(*)(void *, void **))(outputs[o], &p);
        for (long i = 0; i < k && used + i < cap; i++)
            out[used + i] = et == ORT_FLOAT ? ((float *)p)[i] : et == ORT_INT32 ? (float)((int32_t *)p)[i] : et == ORT_UINT8 ? (float)((uint8_t *)p)[i] : 0;
        counts[o] = k;
        used += k;
    }
    n = m->noutputs;
out:
    if (input) F(ReleaseValue, void (*)(void *))(input);
    for (int o = 0; o < MAX_OUTPUTS; o++) if (outputs[o]) F(ReleaseValue, void (*)(void *))(outputs[o]);
    free(converted);
    pthread_mutex_unlock(&onnx_mtx);
    return n;
}

ISIM_GUEST_ABI const char *isim_onnx_error(void) { return onnx_err; }
