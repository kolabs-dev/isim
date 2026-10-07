/* isim CoreGraphics: CF-style objects (__NSCGObject), color spaces, colors (converted to sRGB for drawing),
 * data providers / consumers and CGFont names. */
#include "cg_internal.h"
#include <stdio.h>

typedef struct objc_selector *SEL;
extern SEL sel_registerName(const char *name);
extern void objc_msgSend(void);

void *isim_cg_obj_new(const char *kind, size_t size, void (*fin)(void *)) {
    static Class k; static size_t base;
    if (!k) { k = objc_getClass("__NSCGObject"); base = k ? class_getInstanceSize(k) : sizeof(struct cgobj); }
    struct cgobj *o = k ? class_createInstance(k, size > base ? size - base : 0) : calloc(1, size);
    if (!o) return NULL;
    memset((char *)o + sizeof(void *), 0, size - sizeof(void *));
    o->fin = fin; o->kind = kind;
    return o;
}
/* NSURL path (C string valid while the URL lives) */
const char *isim_cg_url_path(CFURLRef url) {
    if (!url) return NULL;
    void *path = ((void *(*)(const void *, SEL))objc_msgSend)(url, sel_registerName("path"));
    return path ? ((const char *(*)(void *, SEL))objc_msgSend)(path, sel_registerName("UTF8String")) : NULL;
}

/* ---------------- color spaces ---------------- */
const CFStringRef kCGColorSpaceSRGB = CFSTR("kCGColorSpaceSRGB");
const CFStringRef kCGColorSpaceDisplayP3 = CFSTR("kCGColorSpaceDisplayP3");
const CFStringRef kCGColorSpaceLinearSRGB = CFSTR("kCGColorSpaceLinearSRGB");
const CFStringRef kCGColorSpaceExtendedSRGB = CFSTR("kCGColorSpaceExtendedSRGB");
const CFStringRef kCGColorSpaceExtendedLinearSRGB = CFSTR("kCGColorSpaceExtendedLinearSRGB");
const CFStringRef kCGColorSpaceGenericRGBLinear = CFSTR("kCGColorSpaceGenericRGBLinear");
const CFStringRef kCGColorSpaceGenericGrayGamma2_2 = CFSTR("kCGColorSpaceGenericGrayGamma2_2");
const CFStringRef kCGColorSpaceLinearGray = CFSTR("kCGColorSpaceLinearGray");
const CFStringRef kCGColorSpaceExtendedGray = CFSTR("kCGColorSpaceExtendedGray");
const CFStringRef kCGColorSpaceGenericCMYK = CFSTR("kCGColorSpaceGenericCMYK");
const CFStringRef kCGColorSpaceITUR_709 = CFSTR("kCGColorSpaceITUR_709");
const CFStringRef kCGColorWhite = CFSTR("kCGColorWhite");
const CFStringRef kCGColorBlack = CFSTR("kCGColorBlack");
const CFStringRef kCGColorClear = CFSTR("kCGColorClear");

CFTypeID CGColorSpaceGetTypeID(void) { return 0x4373; }
CGColorSpaceRef isim_cg_space(int kind) {
    static CGColorSpaceRef spaces[CS_COUNT];
    if (kind < 0 || kind >= CS_COUNT) kind = CS_SRGB;
    if (!spaces[kind]) {
        struct CGColorSpace *s = isim_cg_obj_new("CGColorSpace", sizeof *s, NULL);
        s->kind = kind;
        switch (kind) {
        case CS_GRAY: case CS_LINEAR_GRAY: case CS_DEVICE_GRAY: s->model = kCGColorSpaceModelMonochrome; s->ncomp = 1; break;
        case CS_PATTERN: s->model = kCGColorSpaceModelPattern; s->ncomp = 0; break;
        case CS_CMYK: s->model = kCGColorSpaceModelCMYK; s->ncomp = 4; break;
        default: s->model = kCGColorSpaceModelRGB; s->ncomp = 3;
        }
        s->name = kind == CS_SRGB ? kCGColorSpaceSRGB : kind == CS_P3 ? kCGColorSpaceDisplayP3 : kind == CS_LINEAR_SRGB ? kCGColorSpaceLinearSRGB
                : kind == CS_EXT_SRGB ? kCGColorSpaceExtendedSRGB : kind == CS_GRAY ? kCGColorSpaceGenericGrayGamma2_2
                : kind == CS_LINEAR_GRAY ? kCGColorSpaceLinearGray : kind == CS_CMYK ? kCGColorSpaceGenericCMYK : NULL;
        spaces[kind] = s;
    }
    return spaces[kind];
}
static CGColorSpaceRef retained(CGColorSpaceRef s) { return s ? objc_retain(s) : NULL; }
CGColorSpaceRef CGColorSpaceCreateDeviceRGB(void) { return retained(isim_cg_space(CS_DEVICE_RGB)); }
CGColorSpaceRef CGColorSpaceCreateDeviceGray(void) { return retained(isim_cg_space(CS_DEVICE_GRAY)); }
CGColorSpaceRef CGColorSpaceCreateDeviceCMYK(void) { return retained(isim_cg_space(CS_CMYK)); }
static int eq(CFStringRef a, CFStringRef b) {
    if (a == b) return 1;
    if (!a || !b) return 0;
    return ((signed char (*)(const void *, SEL, const void *))objc_msgSend)(a, sel_registerName("isEqualToString:"), b) != 0;
}
CGColorSpaceRef CGColorSpaceCreateWithName(CFStringRef n) {
    if (!n) return NULL;
    int k = eq(n, kCGColorSpaceSRGB) || eq(n, kCGColorSpaceITUR_709) ? CS_SRGB : eq(n, kCGColorSpaceDisplayP3) ? CS_P3
          : eq(n, kCGColorSpaceLinearSRGB) || eq(n, kCGColorSpaceGenericRGBLinear) || eq(n, kCGColorSpaceExtendedLinearSRGB) ? CS_LINEAR_SRGB
          : eq(n, kCGColorSpaceExtendedSRGB) ? CS_EXT_SRGB : eq(n, kCGColorSpaceGenericGrayGamma2_2) || eq(n, kCGColorSpaceExtendedGray) ? CS_GRAY
          : eq(n, kCGColorSpaceLinearGray) ? CS_LINEAR_GRAY : eq(n, kCGColorSpaceGenericCMYK) ? CS_CMYK : -1;
    return k < 0 ? NULL : retained(isim_cg_space(k));
}
CGColorSpaceRef CGColorSpaceCreatePattern(CGColorSpaceRef base) {
    struct CGColorSpace *s = isim_cg_obj_new("CGColorSpace", sizeof *s, NULL);
    s->kind = CS_PATTERN; s->model = kCGColorSpaceModelPattern; s->base = base ? objc_retain(base) : NULL;
    return s;
}
CGColorSpaceRef CGColorSpaceRetain(CGColorSpaceRef s) { return retained(s); }
void CGColorSpaceRelease(CGColorSpaceRef s) { if (s) objc_release(s); }
CGColorSpaceModel CGColorSpaceGetModel(CGColorSpaceRef s) { return s ? s->model : kCGColorSpaceModelUnknown; }
size_t CGColorSpaceGetNumberOfComponents(CGColorSpaceRef s) { return s ? s->ncomp : 0; }
CFStringRef CGColorSpaceCopyName(CGColorSpaceRef s) { return s && s->name ? (CFStringRef)objc_retain((void *)s->name) : NULL; }
CFStringRef CGColorSpaceGetName(CGColorSpaceRef s) { return s ? s->name : NULL; }
CGColorSpaceRef CGColorSpaceGetBaseColorSpace(CGColorSpaceRef s) { return s ? s->base : NULL; }
bool CGColorSpaceIsWideGamutRGB(CGColorSpaceRef s) { return s && (s->kind == CS_P3 || s->kind == CS_EXT_SRGB); }
bool CGColorSpaceSupportsOutput(CGColorSpaceRef s) { return s && s->model != kCGColorSpaceModelPattern; }
bool CGColorSpaceUsesExtendedRange(CGColorSpaceRef s) { return s && s->kind == CS_EXT_SRGB; }

/* ---------------- conversions to sRGB ---------------- */
static double lin(double v) { double a = fabs(v); double r = a <= 0.04045 ? a / 12.92 : pow((a + 0.055) / 1.055, 2.4); return v < 0 ? -r : r; }
static double enc(double v) { double a = fabs(v); double r = a <= 0.0031308 ? a * 12.92 : 1.055 * pow(a, 1 / 2.4) - 0.055; return v < 0 ? -r : r; }
static double clamp01(double v) { return v < 0 ? 0 : v > 1 ? 1 : v; }
void isim_cg_to_rgba(CGColorSpaceRef space, const CGFloat *c, CGFloat out[4]) {
    int kind = space ? space->kind : CS_SRGB;
    switch (kind) {
    case CS_GRAY: case CS_DEVICE_GRAY: out[0] = out[1] = out[2] = clamp01(c[0]); out[3] = c[1]; break;
    case CS_LINEAR_GRAY: out[0] = out[1] = out[2] = clamp01(enc(c[0])); out[3] = c[1]; break;
    case CS_LINEAR_SRGB: for (int i = 0; i < 3; i++) out[i] = clamp01(enc(c[i])); out[3] = c[3]; break;
    case CS_P3: {           /* Display P3 (D65, sRGB transfer) -> linear -> sRGB primaries */
        double r = lin(c[0]), g = lin(c[1]), b = lin(c[2]);
        double R = 1.2249401 * r - 0.2249404 * g + 0.0000000 * b;
        double G = -0.0420569 * r + 1.0420571 * g + 0.0000000 * b;
        double B = -0.0196376 * r - 0.0786361 * g + 1.0982735 * b;
        out[0] = clamp01(enc(R)); out[1] = clamp01(enc(G)); out[2] = clamp01(enc(B)); out[3] = c[3];
        break; }
    case CS_CMYK: { double k = c[3]; out[0] = (1 - c[0]) * (1 - k); out[1] = (1 - c[1]) * (1 - k); out[2] = (1 - c[2]) * (1 - k); out[3] = c[4]; break; }
    case CS_PATTERN: out[0] = out[1] = out[2] = 0; out[3] = 1; break;
    default: for (int i = 0; i < 3; i++) out[i] = clamp01(c[i]); out[3] = c[3];
    }
    out[3] = clamp01(out[3]);
}

/* ---------------- CGColor ---------------- */
CFTypeID CGColorGetTypeID(void) { return 0x4363; }
static struct CGColor *color_new(int space) {
    static Class k; static int looked;
    if (!looked) { k = objc_getClass("__NSCGColor"); looked = k != NULL; }
    struct CGColor *col = k ? class_createInstance(k, 0) : calloc(1, sizeof *col);
    col->refs = 1; col->space = space; col->pattern = NULL;
    return col;
}
static CGColorRef make(int space, const CGFloat *comps, int n) {
    struct CGColor *col = color_new(space);
    for (int i = 0; i < n && i < 5; i++) col->comp[i] = comps[i];
    isim_cg_to_rgba(isim_cg_space(space), col->comp, col->c);
    return col;
}
CGColorRef CGColorCreateSRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a) { CGFloat v[4] = { r, g, b, a }; return make(CS_SRGB, v, 4); }
CGColorRef CGColorCreateGenericRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a) { return CGColorCreateSRGB(r, g, b, a); }
CGColorRef CGColorCreateGenericGray(CGFloat w, CGFloat a) { CGFloat v[2] = { w, a }; return make(CS_GRAY, v, 2); }
CGColorRef CGColorCreateGenericGrayGamma2_2(CGFloat w, CGFloat a) { return CGColorCreateGenericGray(w, a); }
CGColorRef CGColorCreate(CGColorSpaceRef space, const CGFloat *comps) {
    CGFloat zero[5] = { 0, 0, 0, 0, 1 };
    if (!comps) comps = zero;
    int kind = space ? space->kind : CS_SRGB;
    if (kind == CS_DEVICE_RGB) kind = CS_SRGB;
    if (kind == CS_DEVICE_GRAY) kind = CS_GRAY;
    if (kind == CS_PATTERN) return make(kind, comps, 0);
    size_t n = (space ? space->ncomp : 3) + 1;
    return make(kind, comps, (int)n);
}
CGColorRef CGColorCreateWithPattern(CGColorSpaceRef space, CGPatternRef pattern, const CGFloat *comps) {
    if (!pattern) return NULL;
    struct CGColor *col = color_new(CS_PATTERN);
    col->pattern = objc_retain(pattern);
    size_t n = space && space->base ? space->base->ncomp + 1 : 0;
    for (size_t i = 0; i < n && comps; i++) col->comp[i] = comps[i];
    if (n && comps) isim_cg_to_rgba(space->base, col->comp, col->c); else { col->c[3] = 1; }
    return col;
}
CGColorRef CGColorGetConstantColor(CFStringRef name) {
    static CGColorRef w, b, c;
    if (!w) { w = CGColorCreateGenericGray(1, 1); b = CGColorCreateGenericGray(0, 1); c = CGColorCreateGenericGray(0, 0); }
    return eq(name, kCGColorWhite) ? w : eq(name, kCGColorBlack) ? b : eq(name, kCGColorClear) ? c : NULL;
}
CGColorRef CGColorRetain(CGColorRef c) {
    if (c && c->isa) objc_retain(c); else if (c) __atomic_add_fetch(&c->refs, 1, __ATOMIC_RELAXED);
    return c;
}
void CGColorRelease(CGColorRef c) {
    if (c && c->isa) objc_release(c);
    else if (c && __atomic_sub_fetch(&c->refs, 1, __ATOMIC_ACQ_REL) == 0) free(c);
}
const CGFloat *CGColorGetComponents(CGColorRef c) { return c ? c->comp : NULL; }
size_t CGColorGetNumberOfComponents(CGColorRef c) {
    if (!c) return 0;
    CGColorSpaceRef s = isim_cg_space(c->space);
    return c->space == CS_PATTERN ? 1 : s->ncomp + 1;
}
CGColorSpaceRef CGColorGetColorSpace(CGColorRef c) { return c ? isim_cg_space(c->space) : NULL; }
CGPatternRef CGColorGetPattern(CGColorRef c) { return c ? c->pattern : NULL; }
bool CGColorEqualToColor(CGColorRef a, CGColorRef b) {
    return a == b || (a && b && a->space == b->space && a->pattern == b->pattern && !memcmp(a->comp, b->comp, sizeof a->comp));
}
CGColorRef CGColorCreateCopy(CGColorRef c) {
    if (!c) return NULL;
    struct CGColor *n = color_new(c->space);
    memcpy(n->c, c->c, sizeof c->c); memcpy(n->comp, c->comp, sizeof c->comp);
    n->pattern = c->pattern ? objc_retain(c->pattern) : NULL;
    return n;
}
CGColorRef CGColorCreateCopyWithAlpha(CGColorRef c, CGFloat alpha) {
    struct CGColor *n = CGColorCreateCopy(c);
    if (!n) return NULL;
    size_t k = CGColorGetNumberOfComponents(c);
    if (k) n->comp[k - 1] = alpha;
    n->c[3] = clamp01(alpha);
    return n;
}
CGFloat CGColorGetAlpha(CGColorRef c) { return c ? c->c[3] : 0; }
CGColorRef CGColorCreateCopyByMatchingToColorSpace(CGColorSpaceRef space, CGColorRenderingIntent intent, CGColorRef c, CFDictionaryRef opts) {
    if (!c || !space || space->kind == CS_PATTERN || c->space == CS_PATTERN) return NULL;
    int k = space->kind;
    if (k == CS_GRAY || k == CS_DEVICE_GRAY || k == CS_LINEAR_GRAY) {
        double y = 0.2126 * lin(c->c[0]) + 0.7152 * lin(c->c[1]) + 0.0722 * lin(c->c[2]);
        CGFloat v[2] = { k == CS_LINEAR_GRAY ? y : enc(y), c->c[3] };
        return make(k == CS_DEVICE_GRAY ? CS_GRAY : k, v, 2);
    }
    if (k == CS_P3) {
        double r = lin(c->c[0]), g = lin(c->c[1]), b = lin(c->c[2]);
        CGFloat v[4] = { enc(0.8224621 * r + 0.1775380 * g), enc(0.0331941 * r + 0.9668058 * g), enc(0.0170827 * r + 0.0723974 * g + 0.9105199 * b), c->c[3] };
        return make(CS_P3, v, 4);
    }
    if (k == CS_LINEAR_SRGB) { CGFloat v[4] = { lin(c->c[0]), lin(c->c[1]), lin(c->c[2]), c->c[3] }; return make(CS_LINEAR_SRGB, v, 4); }
    if (k == CS_CMYK) {
        double K = 1 - fmax(c->c[0], fmax(c->c[1], c->c[2]));
        CGFloat v[5] = { K < 1 ? (1 - c->c[0] - K) / (1 - K) : 0, K < 1 ? (1 - c->c[1] - K) / (1 - K) : 0, K < 1 ? (1 - c->c[2] - K) / (1 - K) : 0, K, c->c[3] };
        return make(CS_CMYK, v, 5);
    }
    CGFloat v[4] = { c->c[0], c->c[1], c->c[2], c->c[3] };
    return make(k == CS_DEVICE_RGB ? CS_SRGB : k, v, 4);
}
void isim_cg_color_rgba(CGColorRef c, double *rgba) {
    if (!c) { rgba[0] = rgba[1] = rgba[2] = rgba[3] = 0; return; }
    for (int i = 0; i < 4; i++) rgba[i] = c->c[i];
}

/* ---------------- data providers and consumers ---------------- */
CFTypeID CGDataProviderGetTypeID(void) { return 0x4364; }
static void provider_fin(void *o) {
    struct CGDataProvider *p = o;
    if (p->data) CFRelease(p->data);
    if (p->release) p->release(p->info, p->bytes, p->size);
}
CGDataProviderRef CGDataProviderCreateWithCFData(CFDataRef data) {
    if (!data) return NULL;
    struct CGDataProvider *p = isim_cg_obj_new("CGDataProvider", sizeof *p, provider_fin);
    p->data = CFRetain(data); p->bytes = CFDataGetBytePtr(data); p->size = (size_t)CFDataGetLength(data);
    return p;
}
CGDataProviderRef CGDataProviderCreateWithData(void *info, const void *data, size_t size, CGDataProviderReleaseDataCallback rel) {
    struct CGDataProvider *p = isim_cg_obj_new("CGDataProvider", sizeof *p, provider_fin);
    p->info = info; p->bytes = data; p->size = size; p->release = rel;
    return p;
}
static void free_cb(void *info, const void *data, size_t size) { free((void *)data); }
CGDataProviderRef CGDataProviderCreateWithFilename(const char *path) {
    FILE *f = path ? fopen(path, "rb") : NULL;
    if (!f) return NULL;
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    unsigned char *buf = malloc(n > 0 ? (size_t)n : 1);
    size_t got = n > 0 ? fread(buf, 1, (size_t)n, f) : 0;
    fclose(f);
    return CGDataProviderCreateWithData(NULL, buf, got, free_cb);
}
CGDataProviderRef CGDataProviderCreateWithURL(CFURLRef url) { return CGDataProviderCreateWithFilename(isim_cg_url_path(url)); }
CGDataProviderRef CGDataProviderRetain(CGDataProviderRef p) { return p ? objc_retain(p) : NULL; }
void CGDataProviderRelease(CGDataProviderRef p) { if (p) objc_release(p); }
CFDataRef CGDataProviderCopyData(CGDataProviderRef p) {
    if (!p) return NULL;
    if (p->data) return CFRetain(p->data);
    return CFDataCreate(NULL, p->bytes, (CFIndex)p->size);
}
void *CGDataProviderGetInfo(CGDataProviderRef p) { return p ? p->info : NULL; }
const void *isim_cg_provider_bytes(CGDataProviderRef p, size_t *size) { *size = p ? p->size : 0; return p ? p->bytes : NULL; }

CFTypeID CGDataConsumerGetTypeID(void) { return 0x4365; }
static void consumer_fin(void *o) {
    struct CGDataConsumer *c = o;
    if (c->data) CFRelease(c->data);
    free(c->path);
    if (c->cb.releaseConsumer) c->cb.releaseConsumer(c->info);
}
CGDataConsumerRef CGDataConsumerCreateWithCFData(CFMutableDataRef data) {
    if (!data) return NULL;
    struct CGDataConsumer *c = isim_cg_obj_new("CGDataConsumer", sizeof *c, consumer_fin);
    c->data = (CFMutableDataRef)CFRetain(data);
    return c;
}
CGDataConsumerRef CGDataConsumerCreateWithURL(CFURLRef url) {
    const char *p = isim_cg_url_path(url);
    if (!p) return NULL;
    struct CGDataConsumer *c = isim_cg_obj_new("CGDataConsumer", sizeof *c, consumer_fin);
    c->path = strdup(p);
    return c;
}
CGDataConsumerRef CGDataConsumerCreate(void *info, const CGDataConsumerCallbacks *cb) {
    if (!cb || !cb->putBytes) return NULL;
    struct CGDataConsumer *c = isim_cg_obj_new("CGDataConsumer", sizeof *c, consumer_fin);
    c->info = info; c->cb = *cb;
    return c;
}
CGDataConsumerRef CGDataConsumerRetain(CGDataConsumerRef c) { return c ? objc_retain(c) : NULL; }
void CGDataConsumerRelease(CGDataConsumerRef c) { if (c) objc_release(c); }
size_t isim_cg_consumer_put(CGDataConsumerRef c, const void *bytes, size_t n) {
    if (!c) return 0;
    if (c->data) { CFDataAppendBytes(c->data, bytes, (CFIndex)n); return n; }
    if (c->cb.putBytes) return c->cb.putBytes(c->info, bytes, n);
    if (c->path) { FILE *f = fopen(c->path, "wb"); if (!f) return 0; size_t w = fwrite(bytes, 1, n, f); fclose(f); return w; }
    return 0;
}
const char *isim_cg_consumer_path(CGDataConsumerRef c) { return c ? c->path : NULL; }

/* ---------------- CGFont (a name) ---------------- */
CFTypeID CGFontGetTypeID(void) { return 0x4366; }
static void font_fin(void *o) { struct CGFont *f = o; if (f->name) CFRelease(f->name); }
CGFontRef CGFontCreateWithFontName(CFStringRef name) {
    if (!name) return NULL;
    struct CGFont *f = isim_cg_obj_new("CGFont", sizeof *f, font_fin);
    f->name = CFRetain(name);
    return f;
}
CGFontRef CGFontCreateWithDataProvider(CGDataProviderRef p) { return NULL; }
CGFontRef CGFontRetain(CGFontRef f) { return f ? objc_retain(f) : NULL; }
void CGFontRelease(CGFontRef f) { if (f) objc_release(f); }
CFStringRef CGFontCopyPostScriptName(CGFontRef f) { return f && f->name ? CFRetain(f->name) : NULL; }
CFStringRef CGFontCopyFullName(CGFontRef f) { return f && f->name ? CFRetain(f->name) : NULL; }
int CGFontGetUnitsPerEm(CGFontRef f) { return 2048; }
