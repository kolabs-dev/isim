/* isim CoreGraphics: ICC, Lab and indexed color spaces and the extended / linearized variants of color spaces;
 * direct and sequential data providers; CGFont tables; layers; conic gradients.
 * ICC profiles are read by isim itself (no lcms2): the header, the primaries (rXYZ / gXYZ / bXYZ) and the tone
 * curves (curv, para) of matrix / TRC profiles, which convert exactly; other profiles draw as their device space. */
#include "cg_context.h"
#include <stdio.h>

/* ---------------- color spaces ---------------- */
struct trc { int type, n; double g, a, b, c, d, e, f; double *table; };   /* type: 0 identity, 1 gamma, 2 table, 3 parametric */
struct csx {
    CFDataRef icc; int matrix; double m[9]; struct trc trc[3];   /* ICC: linear values -> linear sRGB */
    double white[3], black[3], range[4];                         /* Lab */
    unsigned char *table; size_t last;                           /* indexed: (last + 1) * base components */
};
static void csx_free(struct csx *x) {
    if (!x) return;
    if (x->icc) CFRelease(x->icc);
    for (int i = 0; i < 3; i++) free(x->trc[i].table);
    free(x->table);
    free(x);
}
static struct csx *csx_copy(const struct csx *o) {
    if (!o) return NULL;
    struct csx *x = malloc(sizeof *x);
    *x = *o;
    if (x->icc) CFRetain(x->icc);
    for (int i = 0; i < 3; i++)
        if (o->trc[i].table) { x->trc[i].table = malloc(sizeof(double) * (size_t)o->trc[i].n); memcpy(x->trc[i].table, o->trc[i].table, sizeof(double) * (size_t)o->trc[i].n); }
    if (o->table) { size_t n = (o->last + 1) * 4; x->table = malloc(n); memcpy(x->table, o->table, n); }
    return x;
}
static void xspace_fin(void *o) { struct CGColorSpace *s = o; if (s->base) objc_release(s->base); csx_free(s->x); }
static struct CGColorSpace *xspace_new(int kind, CGColorSpaceModel model, size_t ncomp) {
    struct CGColorSpace *s = isim_cg_obj_new("CGColorSpace", sizeof *s, xspace_fin);
    s->kind = kind; s->model = model; s->ncomp = ncomp; s->x = calloc(1, sizeof *s->x);
    return s;
}

static uint32_t be32(const unsigned char *p) { return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]; }
static double s15(const unsigned char *p) { return (double)(int32_t)be32(p) / 65536.0; }
/* a tag's bytes in the profile */
static const unsigned char *icc_tag(const unsigned char *d, size_t n, const char *sig, size_t *len) {
    uint32_t count = be32(d + 128);
    for (uint32_t i = 0; i < count && 132 + 12 * (size_t)(i + 1) <= n; i++) {
        const unsigned char *e = d + 132 + 12 * i;
        uint32_t off = be32(e + 4), size = be32(e + 8);
        if (!memcmp(e, sig, 4) && off + (size_t)size <= n && size >= 8) { *len = size; return d + off; }
    }
    return NULL;
}
static int read_trc(const unsigned char *t, size_t len, struct trc *out) {
    memset(out, 0, sizeof *out);
    if (len >= 12 && !memcmp(t, "curv", 4)) {
        uint32_t n = be32(t + 8);
        if (n == 0) { out->type = 0; return 1; }
        if (n == 1 && len >= 14) { out->type = 1; out->g = (t[12] << 8 | t[13]) / 256.0; return 1; }
        if (len < 12 + 2 * (size_t)n) return 0;
        out->type = 2; out->n = (int)n; out->table = malloc(sizeof(double) * n);
        for (uint32_t i = 0; i < n; i++) out->table[i] = (t[12 + 2 * i] << 8 | t[13 + 2 * i]) / 65535.0;
        return 1;
    }
    if (len >= 16 && !memcmp(t, "para", 4)) {
        static const int params[] = { 1, 3, 4, 5, 7 };
        int f = t[8] << 8 | t[9];
        if (f > 4 || len < 12 + 4 * (size_t)params[f]) return 0;
        double v[7] = { 0 };
        for (int i = 0; i < params[f]; i++) v[i] = s15(t + 12 + 4 * i);
        out->type = 3; out->n = f; out->g = v[0]; out->a = v[1]; out->b = v[2]; out->c = v[3]; out->d = v[4]; out->e = v[5]; out->f = v[6];
        if (f == 0) { out->a = 1; out->b = 0; }
        return 1;
    }
    return 0;
}
static double apply_trc(const struct trc *t, double x) {
    x = x < 0 ? 0 : x > 1 ? 1 : x;
    switch (t->type) {
    case 1: return pow(x, t->g);
    case 2: { double p = x * (t->n - 1); int i = (int)p; if (i >= t->n - 1) return t->table[t->n - 1]; return t->table[i] + (t->table[i + 1] - t->table[i]) * (p - i); }
    case 3:
        switch (t->n) {
        case 0: return pow(x, t->g);
        case 1: return x >= -t->b / t->a ? pow(t->a * x + t->b, t->g) : 0;
        case 2: return x >= -t->b / t->a ? pow(t->a * x + t->b, t->g) + t->c : t->c;
        case 3: return x >= t->d ? pow(t->a * x + t->b, t->g) : t->c * x;
        default: return x >= t->d ? pow(t->a * x + t->b, t->g) + t->e : t->c * x + t->f;
        }
    default: return x;
    }
}
/* XYZ (D50, the ICC connection space) -> linear sRGB (Bradford-adapted to D65) */
static const double D50_TO_SRGB[9] = { 3.1338561, -1.6168667, -0.4906146, -0.9787684, 1.9161415, 0.0334540, 0.0719453, -0.2289914, 1.4052427 };
/* XYZ (D65) -> linear sRGB */
static const double D65_TO_SRGB[9] = { 3.2404542, -1.5371385, -0.4985314, -0.9692660, 1.8760108, 0.0415560, 0.0556434, -0.2040259, 1.0572252 };
static void mul3(const double *m, const double *v, double *out) {
    for (int r = 0; r < 3; r++) out[r] = m[3 * r] * v[0] + m[3 * r + 1] * v[1] + m[3 * r + 2] * v[2];
}

CGColorSpaceRef CGColorSpaceCreateWithICCData(CFTypeRef data) {
    if (!data) return NULL;
    CFDataRef d = NULL;
    if (CFGetTypeID(data) == CGDataProviderGetTypeID()) d = CGDataProviderCopyData((CGDataProviderRef)data);
    else if (CFGetTypeID(data) == CFDataGetTypeID()) d = CFRetain(data);
    if (!d) return NULL;
    const unsigned char *p = CFDataGetBytePtr(d); size_t n = (size_t)CFDataGetLength(d);
    if (n < 132 || memcmp(p + 36, "acsp", 4) || be32(p) > n) { CFRelease(d); return NULL; }
    struct CGColorSpace *s;
    if (!memcmp(p + 16, "RGB ", 4)) s = xspace_new(CS_ICC, kCGColorSpaceModelRGB, 3);
    else if (!memcmp(p + 16, "GRAY", 4)) s = xspace_new(CS_ICC, kCGColorSpaceModelMonochrome, 1);
    else if (!memcmp(p + 16, "CMYK", 4)) s = xspace_new(CS_ICC, kCGColorSpaceModelCMYK, 4);
    else if (!memcmp(p + 16, "Lab ", 4)) s = xspace_new(CS_ICC, kCGColorSpaceModelLab, 3);
    else { CFRelease(d); return NULL; }
    struct csx *x = s->x;
    x->icc = d;
    size_t l[3];
    const unsigned char *rx = icc_tag(p, n, "rXYZ", &l[0]), *gx = icc_tag(p, n, "gXYZ", &l[1]), *bx = icc_tag(p, n, "bXYZ", &l[2]);
    if (s->model == kCGColorSpaceModelRGB && rx && gx && bx && l[0] >= 20 && l[1] >= 20 && l[2] >= 20) {
        double prim[9];                                  /* columns: the red, green and blue colorants */
        const unsigned char *c[3] = { rx, gx, bx };
        for (int k = 0; k < 3; k++) for (int r = 0; r < 3; r++) prim[3 * r + k] = s15(c[k] + 8 + 4 * r);
        for (int r = 0; r < 3; r++) for (int k = 0; k < 3; k++)
            x->m[3 * r + k] = D50_TO_SRGB[3 * r] * prim[k] + D50_TO_SRGB[3 * r + 1] * prim[3 + k] + D50_TO_SRGB[3 * r + 2] * prim[6 + k];
        const char *trcs[3] = { "rTRC", "gTRC", "bTRC" };
        x->matrix = 1;
        for (int k = 0; k < 3; k++) { size_t tl; const unsigned char *t = icc_tag(p, n, trcs[k], &tl); if (!t || !read_trc(t, tl, &x->trc[k])) x->matrix = 0; }
    } else if (s->model == kCGColorSpaceModelMonochrome) {
        size_t tl; const unsigned char *t = icc_tag(p, n, "kTRC", &tl);
        x->matrix = t && read_trc(t, tl, &x->trc[0]);
    }
    return s;
}
CFDataRef CGColorSpaceCopyICCData(CGColorSpaceRef s) { return s && s->x && s->x->icc ? CFRetain(s->x->icc) : NULL; }

CGColorSpaceRef CGColorSpaceCreateLab(const CGFloat *white, const CGFloat *black, const CGFloat *range) {
    if (!white || white[0] <= 0 || white[2] <= 0 || fabs(white[1] - 1) > 1e-6) return NULL;
    struct CGColorSpace *s = xspace_new(CS_LAB, kCGColorSpaceModelLab, 3);
    for (int i = 0; i < 3; i++) { s->x->white[i] = white[i]; s->x->black[i] = black ? black[i] : 0; }
    double def[4] = { -100, 100, -100, 100 };
    for (int i = 0; i < 4; i++) s->x->range[i] = range ? range[i] : def[i];
    return s;
}
CGColorSpaceRef CGColorSpaceCreateIndexed(CGColorSpaceRef base, size_t last, const unsigned char *table) {
    if (!base || !table || last > 255 || base->model == kCGColorSpaceModelPattern || base->kind == CS_INDEXED) return NULL;
    struct CGColorSpace *s = xspace_new(CS_INDEXED, kCGColorSpaceModelIndexed, 1);
    s->base = objc_retain(base);
    size_t n = (last + 1) * base->ncomp;
    s->x->table = calloc((last + 1) * 4, 1);           /* room for any base (copies use 4 per entry) */
    memcpy(s->x->table, table, n);
    s->x->last = last;
    return s;
}
size_t CGColorSpaceGetColorTableCount(CGColorSpaceRef s) { return s && s->kind == CS_INDEXED ? s->x->last + 1 : 0; }
void CGColorSpaceGetColorTable(CGColorSpaceRef s, uint8_t *table) {
    if (s && s->kind == CS_INDEXED && table) memcpy(table, s->x->table, (s->x->last + 1) * s->base->ncomp);
}

void isim_cg_to_rgba_x(CGColorSpaceRef s, const CGFloat *c, CGFloat out[4]) {
    struct csx *x = s->x;
    double lin[3];
    switch (s->kind) {
    case CS_INDEXED: {
        long i = lround(c[0]); if (i < 0) i = 0; if ((size_t)i > x->last) i = (long)x->last;
        CGFloat comps[6] = { 0 };
        size_t n = s->base->ncomp;
        for (size_t k = 0; k < n; k++) comps[k] = x->table[(size_t)i * n + k] / 255.0;
        comps[n] = c[1];
        isim_cg_to_rgba(s->base, comps, out);
        return;
    }
    case CS_LAB: {
        double L = c[0], a = c[1], b = c[2];
        a = a < x->range[0] ? x->range[0] : a > x->range[1] ? x->range[1] : a;
        b = b < x->range[2] ? x->range[2] : b > x->range[3] ? x->range[3] : b;
        double fy = (L + 16) / 116, fx = fy + a / 500, fz = fy - b / 200, e = 6.0 / 29;
        double f[3] = { fx, fy, fz }, xyz[3];
        for (int k = 0; k < 3; k++) xyz[k] = (f[k] > e ? f[k] * f[k] * f[k] : 3 * e * e * (f[k] - 4.0 / 29)) * x->white[k];
        /* von Kries: the space's white point to D65 */
        xyz[0] *= 0.95047 / x->white[0]; xyz[2] *= 1.08883 / x->white[2];
        mul3(D65_TO_SRGB, xyz, lin);
        break;
    }
    default:   /* CS_ICC */
        if (s->model == kCGColorSpaceModelMonochrome) {
            double v = x->matrix ? apply_trc(&x->trc[0], c[0]) : c[0];
            lin[0] = lin[1] = lin[2] = x->matrix ? v : -1;
            if (!x->matrix) { out[0] = out[1] = out[2] = c[0] < 0 ? 0 : c[0] > 1 ? 1 : c[0]; out[3] = c[1]; return; }
        } else if (s->model == kCGColorSpaceModelRGB && x->matrix) {
            double v[3] = { apply_trc(&x->trc[0], c[0]), apply_trc(&x->trc[1], c[1]), apply_trc(&x->trc[2], c[2]) };
            mul3(x->m, v, lin);
        } else {   /* other profiles: as their device space */
            int kind = s->model == kCGColorSpaceModelCMYK ? CS_CMYK : s->model == kCGColorSpaceModelLab ? -1 : CS_SRGB;
            if (kind < 0) { CGFloat white[3] = { 0.9642, 1, 0.8249 }, range[4] = { -128, 127, -128, 127 };
                            CGColorSpaceRef lab = CGColorSpaceCreateLab(white, NULL, range); isim_cg_to_rgba(lab, c, out); CGColorSpaceRelease(lab); return; }
            isim_cg_to_rgba(isim_cg_space(kind), c, out);
            return;
        }
    }
    for (int k = 0; k < 3; k++) {
        double v = lin[k], a = fabs(v), r = a <= 0.0031308 ? a * 12.92 : 1.055 * pow(a, 1 / 2.4) - 0.055;
        r = v < 0 ? -r : r;
        out[k] = r < 0 ? 0 : r > 1 ? 1 : r;
    }
    out[3] = c[s->ncomp];
}
/* 8-bit images in ICC, Lab and indexed spaces: each pixel converted to sRGB */
int isim_cg_image_in_space(CGColorSpaceRef s, const unsigned char *bytes, size_t w, size_t h, size_t bpr, size_t bpp, CGBitmapInfo info) {
    size_t n = s->ncomp, B = bpp / 8;
    int alpha = info & kCGBitmapAlphaInfoMask;
    int first = alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaFirst || alpha == kCGImageAlphaNoneSkipFirst;
    int has_a = alpha != kCGImageAlphaNone, real_a = has_a && alpha != kCGImageAlphaNoneSkipFirst && alpha != kCGImageAlphaNoneSkipLast;
    int premul = alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaPremultipliedLast;
    if (bpp % 8 || B != n + (has_a ? 1 : 0) || (info & kCGBitmapFloatComponents)) return 0;
    unsigned char *px = malloc(w * h * 4);
    /* indexed: the table's colors, converted once */
    unsigned char lut[256][3];
    if (s->kind == CS_INDEXED)
        for (size_t i = 0; i <= s->x->last; i++) { CGFloat c[2] = { (CGFloat)i, 1 }, o[4]; isim_cg_to_rgba(s, c, o); for (int k = 0; k < 3; k++) lut[i][k] = (unsigned char)lround(o[k] * 255); }
    for (size_t y = 0; y < h; y++) for (size_t xx = 0; xx < w; xx++) {
        const unsigned char *p = bytes + y * bpr + xx * B;
        const unsigned char *v = p + (first && has_a ? 1 : 0);
        double a = real_a ? p[first ? 0 : n] / 255.0 : 1;
        unsigned char *o = px + 4 * (y * w + xx);
        if (s->kind == CS_INDEXED) {
            size_t i = v[0] > s->x->last ? s->x->last : v[0];
            o[0] = lut[i][0]; o[1] = lut[i][1]; o[2] = lut[i][2];
        } else {
            CGFloat c[5] = { 0 }, out[4];
            for (size_t k = 0; k < n; k++) {
                double val = v[k] / 255.0;
                if (premul && a > 0) val /= a;
                c[k] = val;
            }
            if (s->kind == CS_LAB || s->model == kCGColorSpaceModelLab) {   /* 8-bit Lab: L 0...100, a and b over the range */
                double *r = s->kind == CS_LAB ? s->x->range : (double[]){ -128, 127, -128, 127 };
                c[0] *= 100; c[1] = r[0] + c[1] * (r[1] - r[0]); c[2] = r[2] + c[2] * (r[3] - r[2]);
            }
            c[n] = 1;
            isim_cg_to_rgba(s, c, out);
            for (int k = 0; k < 3; k++) o[k] = (unsigned char)lround(out[k] * 255);
        }
        o[3] = (unsigned char)lround(a * 255);
    }
    int hd = isim_image_from_pixels(px, (int)w, (int)h, (int)w * 4, ISIM_PX(0, 1, 2, 3), 4);
    free(px);
    return hd;
}

/* variants: extended range, linear transfer, standard range */
static CGColorSpaceRef variant(CGColorSpaceRef s, int ext) {
    struct CGColorSpace *c = isim_cg_obj_new("CGColorSpace", sizeof *c, xspace_fin);
    c->kind = s->kind; c->model = s->model; c->ncomp = s->ncomp; c->name = s->name; c->ext = ext;
    c->base = s->base ? objc_retain(s->base) : NULL; c->x = csx_copy(s->x);
    return c;
}
static CGColorSpaceRef shared(int kind) { return objc_retain(isim_cg_space(kind)); }
CGColorSpaceRef CGColorSpaceCreateExtended(CGColorSpaceRef s) {
    if (!s || s->model == kCGColorSpaceModelPattern || s->model == kCGColorSpaceModelIndexed) return NULL;
    if (CGColorSpaceUsesExtendedRange(s)) return objc_retain(s);
    switch (s->kind) {
    case CS_SRGB: case CS_DEVICE_RGB: return shared(CS_EXT_SRGB);
    case CS_LINEAR_SRGB: case CS_GENERIC_RGB_LINEAR: return shared(CS_EXT_LINEAR_SRGB);
    case CS_GRAY: case CS_DEVICE_GRAY: return shared(CS_EXT_GRAY);
    case CS_P3: return shared(CS_EXT_P3);
    default: return variant(s, 1);
    }
}
CGColorSpaceRef CGColorSpaceCreateLinearized(CGColorSpaceRef s) {
    if (!s) return NULL;
    switch (s->kind) {
    case CS_SRGB: case CS_DEVICE_RGB: case CS_ITUR_709: return shared(CS_LINEAR_SRGB);
    case CS_EXT_SRGB: return shared(CS_EXT_LINEAR_SRGB);
    case CS_GRAY: case CS_DEVICE_GRAY: return shared(CS_LINEAR_GRAY);
    case CS_P3: case CS_EXT_P3: return shared(CS_LINEAR_P3);
    case CS_LINEAR_SRGB: case CS_EXT_LINEAR_SRGB: case CS_GENERIC_RGB_LINEAR: case CS_LINEAR_GRAY: case CS_LINEAR_P3: return objc_retain(s);
    default: return NULL;   /* ICC, Lab, indexed, CMYK: no linear form */
    }
}
CGColorSpaceRef CGColorSpaceCreateExtendedLinearized(CGColorSpaceRef s) {
    CGColorSpaceRef l = CGColorSpaceCreateLinearized(s);
    if (!l) return NULL;
    CGColorSpaceRef e = CGColorSpaceCreateExtended(l);
    CGColorSpaceRelease(l);
    return e;
}
CGColorSpaceRef CGColorSpaceCreateCopyWithStandardRange(CGColorSpaceRef s) {
    switch (s->kind) {
    case CS_EXT_SRGB: return shared(CS_SRGB);
    case CS_EXT_LINEAR_SRGB: return shared(CS_LINEAR_SRGB);
    case CS_EXT_GRAY: return shared(CS_GRAY);
    case CS_EXT_P3: return shared(CS_P3);
    default: return s->ext ? variant(s, 0) : objc_retain(s);
    }
}
/* an indexed or pattern space's base; any other space is its own */
CGColorSpaceRef CGColorSpaceCopyBaseColorSpace(CGColorSpaceRef s) { return objc_retain(s->base ? s->base : s); }
const CFStringRef kCGColorSpaceGenericLab = CFSTR("kCGColorSpaceGenericLab");
const CFStringRef kCGColorSpaceExtendedRange = CFSTR("kCGColorSpaceExtendedRange");

/* ---------------- direct and sequential data providers ---------------- */
static CGDataProviderRef provider_of(void *info, unsigned char *buf, size_t n, CGDataProviderReleaseInfoCallback rel) {
    CFDataRef d = CFDataCreate(NULL, buf, (CFIndex)n);
    free(buf);
    CGDataProviderRef p = CGDataProviderCreateWithCFData(d);
    CFRelease(d);
    if (p) { p->info = info; p->releaseInfo = rel; }
    else if (rel) rel(info);
    return p;
}
CGDataProviderRef CGDataProviderCreateDirect(void *info, off_t size, const CGDataProviderDirectCallbacks *cb) {
    if (!cb || size < 0 || (!cb->getBytePointer && !cb->getBytesAtPosition)) return NULL;
    size_t n = (size_t)size;
    unsigned char *buf = malloc(n ? n : 1);
    const void *ptr = cb->getBytePointer ? cb->getBytePointer(info) : NULL;
    if (ptr) {
        memcpy(buf, ptr, n);
        if (cb->releaseBytePointer) cb->releaseBytePointer(info, ptr);
    } else if (cb->getBytesAtPosition) {
        size_t got = 0;
        while (got < n) { size_t k = cb->getBytesAtPosition(info, buf + got, (off_t)got, n - got); if (!k) break; got += k; }
        n = got;
    } else { free(buf); return NULL; }
    return provider_of(info, buf, n, cb->releaseInfo);
}
CGDataProviderRef CGDataProviderCreateSequential(void *info, const CGDataProviderSequentialCallbacks *cb) {
    if (!cb || !cb->getBytes) return NULL;
    if (cb->rewind) cb->rewind(info);
    size_t cap = 4096, n = 0;
    unsigned char *buf = malloc(cap);
    for (;;) {
        if (n == cap) { cap *= 2; buf = realloc(buf, cap); }
        size_t k = cb->getBytes(info, buf + n, cap - n);
        if (!k) break;
        n += k;
    }
    return provider_of(info, buf, n, cb->releaseInfo);
}

/* ---------------- CGFont tables ---------------- */
/* a CGFont's host font (by its PostScript or family name); free with isim_ct_font_free */
static void *host_font(CGFontRef f) {
    char *name = NULL; char family[256] = ""; double weight = 0; int italic = 0;
    CFIndex len = CFStringGetMaximumSizeForEncoding(CFStringGetLength(f->name), kCFStringEncodingUTF8) + 1;
    name = malloc((size_t)len);
    if (!CFStringGetCString(f->name, name, len, kCFStringEncodingUTF8)) { free(name); return NULL; }
    void *font = NULL;
    if (isim_font_lookup(name, family, sizeof family, &weight, &italic)) {
        int w = weight < -0.6 ? 100 : weight < -0.3 ? 200 : weight < -0.1 ? 300 : weight < 0.1 ? 400 : weight < 0.26 ? 500 : weight < 0.35 ? 600
              : weight < 0.5 ? 700 : weight < 0.6 ? 800 : 900;
        font = isim_ct_font_load(family, w, italic, 4, 12);
    }
    free(name);
    return font;
}
/* a table of sfnt data (TrueType / OpenType, the first font of a collection) */
static const unsigned char *sfnt_table(const unsigned char *d, size_t n, uint32_t tag, size_t *len, uint32_t *tags, int *ntags) {
    size_t base = 0;
    if (n >= 16 && !memcmp(d, "ttcf", 4)) base = be32(d + 12);
    if (base + 12 > n) return NULL;
    unsigned count = (unsigned)(d[base + 4] << 8 | d[base + 5]);
    if (ntags) *ntags = 0;
    for (unsigned i = 0; i < count && base + 12 + 16 * (size_t)(i + 1) <= n; i++) {
        const unsigned char *e = d + base + 12 + 16 * i;
        uint32_t t = be32(e), off = be32(e + 8), l = be32(e + 12);
        if (tags) tags[(*ntags)++] = t;
        if (!tags && t == tag && off + (size_t)l <= n) { *len = l; return d + off; }
    }
    return NULL;
}
CFArrayRef CGFontCopyTableTags(CGFontRef f) {
    if (!f) return NULL;
    uint32_t tags[256]; int nt = 0;
    if (f->data) sfnt_table(CFDataGetBytePtr(f->data), (size_t)CFDataGetLength(f->data), 0, NULL, tags, &nt);
    else {
        void *font = host_font(f);
        if (!font) return NULL;
        unsigned t[256];
        nt = isim_ct_font_table_tags(font, t, 256);
        if (nt > 256) nt = 256;
        for (int i = 0; i < nt; i++) tags[i] = t[i];
        isim_ct_font_free(font);
    }
    const void *vals[256];
    for (int i = 0; i < nt; i++) vals[i] = (const void *)(uintptr_t)tags[i];
    return CFArrayCreate(NULL, vals, nt, NULL);
}
CFDataRef CGFontCopyTableForTag(CGFontRef f, uint32_t tag) {
    if (!f) return NULL;
    if (f->data) {
        size_t len = 0;
        const unsigned char *t = sfnt_table(CFDataGetBytePtr(f->data), (size_t)CFDataGetLength(f->data), tag, &len, NULL, NULL);
        return t ? CFDataCreate(NULL, t, (CFIndex)len) : NULL;
    }
    void *font = host_font(f);
    if (!font) return NULL;
    int n = isim_ct_font_table(font, tag, NULL, 0);
    CFDataRef d = NULL;
    if (n > 0) {
        unsigned char *buf = malloc((size_t)n);
        isim_ct_font_table(font, tag, buf, n);
        d = CFDataCreate(NULL, buf, n);
        free(buf);
    }
    isim_ct_font_free(font);
    return d;
}

/* ---------------- layers ---------------- */
struct CGLayer { struct cgobj hdr; CGSize size; CGContextRef ctx; };
static void layer_fin(void *o) { struct CGLayer *l = o; if (l->ctx) CGContextRelease(l->ctx); }
CFTypeID CGLayerGetTypeID(void) { return 0x4379; }
CGLayerRef CGLayerCreateWithContext(CGContextRef c, CGSize size, CFDictionaryRef aux) {
    if (!c || size.width <= 0 || size.height <= 0) return NULL;
    /* the context's device scale, so the layer draws back sharp */
    CGAffineTransform t = CGContextGetCTM(c);
    double scale = sqrt(fabs(t.a * t.d - t.b * t.c));
    if (!(scale >= 1)) scale = 1;
    if (scale > 8) scale = 8;
    size_t w = (size_t)ceil(size.width * scale), h = (size_t)ceil(size.height * scale);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef bc = CGBitmapContextCreate(NULL, w, h, 8, 0, cs, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if (!bc) return NULL;
    CGContextScaleCTM(bc, w / size.width, h / size.height);
    struct CGLayer *l = isim_cg_obj_new("CGLayer", sizeof *l, layer_fin);
    l->size = size; l->ctx = bc;
    return l;
}
CGLayerRef CGLayerRetain(CGLayerRef l) { return l ? objc_retain(l) : NULL; }
void CGLayerRelease(CGLayerRef l) { if (l) objc_release(l); }
CGSize CGLayerGetSize(CGLayerRef l) { return l ? l->size : CGSizeZero; }
CGContextRef CGLayerGetContext(CGLayerRef l) { return l ? l->ctx : NULL; }
void CGContextDrawLayerInRect(CGContextRef c, CGRect r, CGLayerRef l) {
    if (!c || !l) return;
    CGImageRef im = CGBitmapContextCreateImage(l->ctx);
    if (im) { CGContextDrawImage(c, r, im); CGImageRelease(im); }
}
void CGContextDrawLayerAtPoint(CGContextRef c, CGPoint p, CGLayerRef l) {
    if (l) CGContextDrawLayerInRect(c, CGRectMake(p.x, p.y, l->size.width, l->size.height), l);
}

/* ---------------- conic gradients ---------------- */
/* the gradient's color at t (0...1) */
static void gradient_at(CGGradientRef g, double t, double rgba[4]) {
    int n = g->n;
    if (t <= g->locs[0] || n == 1) { memcpy(rgba, g->rgba, 4 * sizeof(double)); return; }
    if (t >= g->locs[n - 1]) { memcpy(rgba, g->rgba + 4 * (n - 1), 4 * sizeof(double)); return; }
    int i = 0;
    while (i < n - 2 && t > g->locs[i + 1]) i++;
    double span = g->locs[i + 1] - g->locs[i], f = span > 0 ? (t - g->locs[i]) / span : 0;
    for (int k = 0; k < 4; k++) rgba[k] = g->rgba[4 * i + k] + (g->rgba[4 * (i + 1) + k] - g->rgba[4 * i + k]) * f;
}
/* wedges around the center, each in its color, out past the clip; the gradient runs counterclockwise from angle */
void CGContextDrawConicGradient(CGContextRef c, CGGradientRef g, CGPoint center, CGFloat angle) {
    if (!c || !g || g->n < 1) return;
    CGRect clip = CGContextGetClipBoundingBox(c);
    double r = 0;
    CGPoint corners[4] = { { CGRectGetMinX(clip), CGRectGetMinY(clip) }, { CGRectGetMaxX(clip), CGRectGetMinY(clip) },
                           { CGRectGetMinX(clip), CGRectGetMaxY(clip) }, { CGRectGetMaxX(clip), CGRectGetMaxY(clip) } };
    for (int i = 0; i < 4; i++) r = fmax(r, hypot(corners[i].x - center.x, corners[i].y - center.y));
    if (!isfinite(r) || r > 1e5) r = 1e5;
    r += 2;
    const int N = 720;
    CGContextSaveGState(c);
    CGContextSetShouldAntialias(c, false);   /* wedges thinner than a pixel: coverage would leave them translucent */
    for (int i = 0; i < N; i++) {
        double a0 = angle + 2 * M_PI * i / N, a1 = angle + 2 * M_PI * (i + 1) / N + 0.004;   /* a hair of overlap: no seams */
        double rgba[4];
        gradient_at(g, (i + 0.5) / N, rgba);
        CGContextSetRGBFillColor(c, rgba[0], rgba[1], rgba[2], rgba[3]);
        CGContextBeginPath(c);
        CGContextMoveToPoint(c, center.x, center.y);
        CGContextAddLineToPoint(c, center.x + r * cos(a0), center.y + r * sin(a0));
        CGContextAddLineToPoint(c, center.x + r * cos(a1), center.y + r * sin(a1));
        CGContextClosePath(c);
        CGContextFillPath(c);
    }
    CGContextSetShouldAntialias(c, true);
    CGContextRestoreGState(c);
}
