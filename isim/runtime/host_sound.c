/*
 * isim host sound classification (Sound Analysis): an ONNX audio classifier (YAMNet's ONNX export, or any model that
 * takes a 16 kHz mono waveform and gives class scores) run with ONNX Runtime, loaded with dlopen only when an app
 * classifies sounds. The library is ISIM_ONNXRUNTIME (a path) or the host's libonnxruntime; the model is the app's
 * request (isim's Sound Analysis passes ISIM_SOUND_MODEL). ONNX Runtime's C API is used through its versioned function
 * table (OrtApi, append-only): only the entries below are declared, at their indexes in onnxruntime_c_api.h.
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
typedef void *OrtFn;   /* a table entry: cast to its function type */
typedef struct { const void *(*GetApi)(uint32_t version); const char *(*GetVersionString)(void); } OrtApiBase;
enum { ORT_API_VERSION_USED = 14 };     /* ONNX Runtime 1.14 and later */
/* OrtApi indexes (onnxruntime_c_api.h) */
enum {
    ORT_GetErrorMessage = 2, ORT_CreateEnv = 3, ORT_CreateSession = 7, ORT_Run = 9, ORT_CreateSessionOptions = 10,
    ORT_SetIntraOpNumThreads = 24, ORT_SessionGetInputCount = 30, ORT_SessionGetOutputCount = 31, ORT_SessionGetInputTypeInfo = 33,
    ORT_SessionGetInputName = 36, ORT_SessionGetOutputName = 37, ORT_CreateTensorWithDataAsOrtValue = 49,
    ORT_GetTensorMutableData = 51, ORT_CastTypeInfoToTensorInfo = 55, ORT_GetDimensionsCount = 61, ORT_GetDimensions = 62,
    ORT_GetTensorTypeAndShape = 65, ORT_CreateCpuMemoryInfo = 69, ORT_GetAllocatorWithDefaultOptions = 78,
    ORT_ReleaseStatus = 93, ORT_ReleaseMemoryInfo = 94, ORT_ReleaseValue = 96, ORT_ReleaseTypeInfo = 98,
    ORT_ReleaseTensorTypeAndShapeInfo = 99, ORT_ReleaseSessionOptions = 100,
};
enum { ORT_LOGGING_LEVEL_ERROR = 3, ORT_FLOAT = 1, ORT_DEVICE_ALLOCATOR = 0, ORT_MEM_DEFAULT = 0 };

static const OrtFn *ort;            /* the function table */
static void *ort_env;
static pthread_mutex_t sound_mtx = PTHREAD_MUTEX_INITIALIZER;
static char sound_err[512];

#define F(name, type) ((type)ort[ORT_##name])

static int fail(const char *what, OrtStatus *st) {
    const char *m = st ? F(GetErrorMessage, const char *(*)(const OrtStatus *))(st) : "";
    snprintf(sound_err, sizeof sound_err, "%s%s%s", what, *m ? ": " : "", m);
    if (st) F(ReleaseStatus, void (*)(OrtStatus *))(st);
    return 0;
}

/* loads ONNX Runtime once; 0 when the host has none */
static int ort_load(void) {
    if (ort) return 1;
    void *lib = NULL;
    const char *path = getenv("ISIM_ONNXRUNTIME");
    if (path && *path) lib = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    for (size_t i = 0; !lib && i < sizeof ORT_LIBRARIES / sizeof *ORT_LIBRARIES; i++) lib = dlopen(ORT_LIBRARIES[i], RTLD_NOW | RTLD_LOCAL);
    if (!lib) {
        snprintf(sound_err, sizeof sound_err, "sound classification on isim needs ONNX Runtime (libonnxruntime, or ISIM_ONNXRUNTIME=path)");
        return 0;
    }
    const OrtApiBase *(*base)(void) = (const OrtApiBase *(*)(void))dlsym(lib, "OrtGetApiBase");
    const OrtFn *api = base ? (const OrtFn *)base()->GetApi(ORT_API_VERSION_USED) : NULL;
    if (!api) { snprintf(sound_err, sizeof sound_err, "this ONNX Runtime is too old (1.14 or later is needed)"); return 0; }
    ort = api;
    OrtStatus *st = F(CreateEnv, OrtStatus *(*)(int, const char *, void **))(ORT_LOGGING_LEVEL_ERROR, "isim", &ort_env);
    if (st) { fail("ONNX Runtime could not start", st); ort = NULL; return 0; }
    return 1;
}

typedef struct { void *session; char *input, *output; int rank; } SoundModel;
static SoundModel models[8];

/* opens an ONNX model: a handle (1...), or 0 with the reason in isim_sound_error() */
ISIM_GUEST_ABI int isim_sound_model_open(const char *path) {
    pthread_mutex_lock(&sound_mtx);
    int h = 0;
    if (!ort_load()) goto out;
    int slot = -1;
    for (int i = 0; i < 8; i++) if (!models[i].session) { slot = i; break; }
    if (slot < 0) { snprintf(sound_err, sizeof sound_err, "too many sound models"); goto out; }
    void *opts = NULL, *session = NULL, *alloc = NULL;
    OrtStatus *st = F(CreateSessionOptions, OrtStatus *(*)(void **))(&opts);
    if (st) { fail("ONNX Runtime", st); goto out; }
    F(SetIntraOpNumThreads, OrtStatus *(*)(void *, int))(opts, 1);
    st = F(CreateSession, OrtStatus *(*)(void *, const char *, void *, void **))(ort_env, path, opts, &session);
    F(ReleaseSessionOptions, void (*)(void *))(opts);
    if (st) { fail("the sound model could not be loaded", st); goto out; }
    F(GetAllocatorWithDefaultOptions, OrtStatus *(*)(void **))(&alloc);
    char *in = NULL, *outname = NULL;
    if ((st = F(SessionGetInputName, OrtStatus *(*)(void *, size_t, void *, char **))(session, 0, alloc, &in)) ||
        (st = F(SessionGetOutputName, OrtStatus *(*)(void *, size_t, void *, char **))(session, 0, alloc, &outname))) {
        fail("the sound model has no input or output", st); goto out;
    }
    /* the input's rank: [samples] (YAMNet) or [batch, samples] */
    void *type = NULL; const void *tensor = NULL; size_t rank = 1;
    if (!F(SessionGetInputTypeInfo, OrtStatus *(*)(void *, size_t, void **))(session, 0, &type) && type) {
        if (!F(CastTypeInfoToTensorInfo, OrtStatus *(*)(const void *, const void **))(type, &tensor) && tensor)
            F(GetDimensionsCount, OrtStatus *(*)(const void *, size_t *))(tensor, &rank);
        F(ReleaseTypeInfo, void (*)(void *))(type);
    }
    models[slot] = (SoundModel){ session, strdup(in), strdup(outname), rank == 2 ? 2 : 1 };
    h = slot + 1;
out:
    pthread_mutex_unlock(&sound_mtx);
    return h;
}

/* classifies a 16 kHz mono waveform: the class scores (averaged over the model's frames) in scores; the number of
   classes, or -1 with the reason in isim_sound_error() */
ISIM_GUEST_ABI int isim_sound_model_run(int h, const float *wave, int n, float *scores, int cap) {
    pthread_mutex_lock(&sound_mtx);
    int classes = -1;
    if (!ort || h < 1 || h > 8 || !models[h - 1].session || n <= 0) { snprintf(sound_err, sizeof sound_err, "no sound model"); goto out; }
    SoundModel *m = &models[h - 1];
    void *mem = NULL, *input = NULL, *output = NULL, *shape = NULL;
    OrtStatus *st = F(CreateCpuMemoryInfo, OrtStatus *(*)(int, int, void **))(ORT_DEVICE_ALLOCATOR, ORT_MEM_DEFAULT, &mem);
    if (st) { fail("ONNX Runtime", st); goto out; }
    int64_t dims[2] = { m->rank == 2 ? 1 : n, n };
    st = F(CreateTensorWithDataAsOrtValue, OrtStatus *(*)(const void *, void *, size_t, const int64_t *, size_t, int, void **))(
        mem, (void *)wave, (size_t)n * sizeof(float), m->rank == 2 ? dims : &dims[1], (size_t)m->rank, ORT_FLOAT, &input);
    F(ReleaseMemoryInfo, void (*)(void *))(mem);
    if (st) { fail("ONNX Runtime", st); goto out; }
    const char *in_names[1] = { m->input }, *out_names[1] = { m->output };
    st = F(Run, OrtStatus *(*)(void *, const void *, const char *const *, const void *const *, size_t, const char *const *, size_t, void **))(
        m->session, NULL, in_names, (const void *const *)&input, 1, out_names, 1, &output);
    F(ReleaseValue, void (*)(void *))(input);
    if (st) { fail("the sound model failed", st); goto out; }
    size_t nd = 0; int64_t od[4] = { 0 };
    float *data = NULL;
    if ((st = F(GetTensorTypeAndShape, OrtStatus *(*)(const void *, void **))(output, &shape)) ||
        (st = F(GetDimensionsCount, OrtStatus *(*)(const void *, size_t *))(shape, &nd)) || nd < 1 || nd > 4 ||
        (st = F(GetDimensions, OrtStatus *(*)(const void *, int64_t *, size_t))(shape, od, nd)) ||
        (st = F(GetTensorMutableData, OrtStatus *(*)(void *, void **))(output, (void **)&data))) {
        if (shape) F(ReleaseTensorTypeAndShapeInfo, void (*)(void *))(shape);
        F(ReleaseValue, void (*)(void *))(output);
        fail("the sound model's output is not a score tensor", st); goto out;
    }
    F(ReleaseTensorTypeAndShapeInfo, void (*)(void *))(shape);
    long k = (long)od[nd - 1], frames = 1;
    for (size_t i = 0; i + 1 < nd; i++) frames *= od[i] > 0 ? (long)od[i] : 1;
    classes = (int)k;
    for (long c = 0; c < k && c < cap; c++) {
        double sum = 0;
        for (long f = 0; f < frames; f++) sum += data[f * k + c];
        scores[c] = (float)(sum / (double)frames);
    }
    F(ReleaseValue, void (*)(void *))(output);
out:
    pthread_mutex_unlock(&sound_mtx);
    return classes;
}

ISIM_GUEST_ABI const char *isim_sound_error(void) { return sound_err; }
