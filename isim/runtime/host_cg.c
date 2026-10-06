/*
 * libisim_host graphics part 2: Core Graphics bitmap and PDF contexts (cairo targets bound as the current
 * drawing target), pixel formats, shadows / clip masks / blend modes / pattern fills, Core Text line layout
 * (Pango), ImageIO container parsing, decoding (gdk-pixbuf, ffmpeg for HEIC) and GIF encoding, and PDF reading
 * through the host's poppler-glib when it is installed (dlopen'd).
 */
#define _GNU_SOURCE
#include <cairo.h>
#include <cairo-pdf.h>
#include <dlfcn.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <math.h>
#include <pango/pangocairo.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "host_cg_exports.h"
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"   /* GdkPixbufAnimation / GTimeVal: still how gdk-pixbuf exposes frames */

cairo_t *isim_host_cairo(void);
cairo_t *isim_host_swap_cairo(cairo_t *n);
cairo_surface_t *isim_image_get_surface(int hd, int *owned);
int isim_image_adopt_surface(cairo_surface_t *s);
int isim_image_load_data(const void *data, unsigned long len, double *w, double *h);
void isim_image_pixel_size(int hd, double *w, double *h);

/* layouts shared with sdk-src/usr/include/isim_host_cg.h */
struct isim_cg_fx {
    double alpha;
    int shadow, flip; double sdx, sdy, sblur, srgba[4];
    int mask_handle; double msx, msy, msw, msh;
    double mm[6], mx, my, mw, mh;
    int mask_luminance;
};
struct isim_ct_run { int start, len, glyphs, weight, italic, has_color; double x, width, size, rgba[4]; char family[96]; };

/* ---------------- pixel formats ---------------- */
#define PX_PREMUL 0x1000
#define PX_GRAY 0x2000
#define PX_ALPHAONLY 0x4000
#define PX_SKIPALPHA 0x8000
#define PX_INVERT 0x10000
struct pf { int bpp, r, g, b, a, premul, gray, aonly, skip, invert; };
static struct pf pf_of(int fmt, int bpp) {
    struct pf f = { bpp, fmt & 7, fmt >> 3 & 7, fmt >> 6 & 7, fmt >> 9 & 7, !!(fmt & PX_PREMUL), !!(fmt & PX_GRAY), !!(fmt & PX_ALPHAONLY),
                    !!(fmt & PX_SKIPALPHA), !!(fmt & PX_INVERT) };
    if (f.a >= bpp) f.a = 7;
    return f;
}
static inline unsigned clamp8(int v) { return v < 0 ? 0 : v > 255 ? 255 : (unsigned)v; }
/* one pixel of the app's format -> premultiplied ARGB32 */
static inline uint32_t px_in(const unsigned char *p, const struct pf *f) {
    unsigned a = f->a != 7 && !f->skip ? p[f->a] : 255, r, g, b;
    if (f->aonly) { a = f->a != 7 ? p[f->a] : p[0]; if (f->invert) a = 255 - a; return a << 24; }
    if (f->gray) {
        unsigned v = p[f->r];
        if (f->invert) return (255 - v) << 24;              /* image mask: black where it paints */
        r = g = b = v;
    } else { r = p[f->r]; g = p[f->g]; b = p[f->b]; }
    if (!f->premul) { r = r * a / 255; g = g * a / 255; b = b * a / 255; }
    else { if (r > a) r = a; if (g > a) g = a; if (b > a) b = a; }
    return a << 24 | r << 16 | g << 8 | b;
}
/* premultiplied ARGB32 -> one pixel of the app's format */
static inline void px_out(unsigned char *p, uint32_t v, const struct pf *f) {
    unsigned a = v >> 24, r = v >> 16 & 255, g = v >> 8 & 255, b = v & 255;
    if (f->aonly) { p[f->a != 7 ? f->a : 0] = (unsigned char)a; return; }
    int keep_alpha = f->a != 7 && !f->skip;
    if (!keep_alpha || !f->premul) {                       /* unpremultiply (or composite over black for opaque formats) */
        if (keep_alpha && a && a < 255) { r = r * 255 / a; g = g * 255 / a; b = b * 255 / a; }
        if (!keep_alpha) { /* premultiplied values are the color over black */ }
    }
    if (f->gray) p[f->r] = (unsigned char)clamp8((int)lround(0.299 * r + 0.587 * g + 0.114 * b));
    else { p[f->r] = (unsigned char)r; p[f->g] = (unsigned char)g; p[f->b] = (unsigned char)b; }
    if (f->a != 7) p[f->a] = f->skip ? 255 : (unsigned char)a;
}
static void import_pixels(cairo_surface_t *s, const unsigned char *src, int w, int h, int bpr, const struct pf *f) {
    cairo_surface_flush(s);
    unsigned char *dst = cairo_image_surface_get_data(s); int ds = cairo_image_surface_get_stride(s);
    for (int y = 0; y < h; y++) {
        const unsigned char *sp = src + (size_t)y * bpr; uint32_t *dp = (uint32_t *)(dst + (size_t)y * ds);
        for (int x = 0; x < w; x++) dp[x] = px_in(sp + (size_t)x * f->bpp, f);
    }
    cairo_surface_mark_dirty(s);
}
static void export_pixels(cairo_surface_t *s, unsigned char *dst, int w, int h, int bpr, const struct pf *f) {
    cairo_surface_flush(s);
    const unsigned char *src = cairo_image_surface_get_data(s); int ss = cairo_image_surface_get_stride(s);
    cairo_format_t cf = cairo_image_surface_get_format(s);
    for (int y = 0; y < h; y++) {
        unsigned char *dp = dst + (size_t)y * bpr;
        for (int x = 0; x < w; x++) {
            uint32_t v = cf == CAIRO_FORMAT_A8 ? (uint32_t)src[(size_t)y * ss + x] << 24 : ((const uint32_t *)(src + (size_t)y * ss))[x];
            if (cf == CAIRO_FORMAT_RGB24) v |= 0xff000000u;
            px_out(dp + (size_t)x * f->bpp, v, f);
        }
    }
}

int isim_image_from_pixels(const void *data, int w, int h, int bpr, int fmt, int bpp) {
    if (!data || w <= 0 || h <= 0 || bpp < 1 || bpp > 8) return 0;
    struct pf f = pf_of(fmt, bpp);
    cairo_surface_t *s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
    import_pixels(s, data, w, h, bpr, &f);
    return isim_image_adopt_surface(s);
}
int isim_image_read_pixels(int hd, int x0, int y0, int w, int h, void *out, int bpr, int fmt, int bpp) {
    int owned; cairo_surface_t *s = isim_image_get_surface(hd, &owned);
    if (!s || w <= 0 || h <= 0) return 0;
    struct pf f = pf_of(fmt, bpp);
    int sw = cairo_image_surface_get_width(s), sh = cairo_image_surface_get_height(s), ss = cairo_image_surface_get_stride(s);
    const unsigned char *src = cairo_image_surface_get_data(s);
    cairo_format_t cf = cairo_image_surface_get_format(s);
    for (int y = 0; y < h; y++) {
        unsigned char *dp = (unsigned char *)out + (size_t)y * bpr;
        for (int x = 0; x < w; x++) {
            int sx = x0 + x, sy = y0 + y; uint32_t v = 0;
            if (sx >= 0 && sy >= 0 && sx < sw && sy < sh) {
                if (cf == CAIRO_FORMAT_A8) v = (uint32_t)src[(size_t)sy * ss + sx] << 24;
                else { v = ((const uint32_t *)(src + (size_t)sy * ss))[sx]; if (cf == CAIRO_FORMAT_RGB24) v |= 0xff000000u; }
            }
            px_out(dp + (size_t)x * f.bpp, v, &f);
        }
    }
    if (owned) cairo_surface_destroy(s);
    return 1;
}

/* ---------------- targets: bitmap and PDF contexts ---------------- */
struct cgt {
    int kind;                    /* 1 bitmap, 2 PDF */
    cairo_surface_t *s; cairo_t *cr;
    unsigned char *app, *shadow; int w, h, bpr, zero; struct pf f;
    int depth; cairo_t *saved; struct cgt *prev;
    GByteArray *buf; double pw, ph; int pages, page_open;
};
static struct cgt *cur_target;

void *isim_cg_bitmap_create(void *data, int w, int h, int bpr, int fmt, int bpp) {
    if (!data || w <= 0 || h <= 0 || bpr < w * bpp) return NULL;
    struct cgt *t = calloc(1, sizeof *t);
    t->kind = 1; t->app = data; t->w = w; t->h = h; t->bpr = bpr; t->f = pf_of(fmt, bpp);
    struct pf *f = &t->f;
    if (bpp == 4 && !f->gray && !f->aonly && f->r == 2 && f->g == 1 && f->b == 0 && f->a == 3 && (f->premul || f->skip) && bpr % 4 == 0) {
        t->zero = 1; t->s = cairo_image_surface_create_for_data(data, f->skip ? CAIRO_FORMAT_RGB24 : CAIRO_FORMAT_ARGB32, w, h, bpr);
    } else if (bpp == 1 && f->aonly && bpr % 4 == 0) {
        t->zero = 1; t->s = cairo_image_surface_create_for_data(data, CAIRO_FORMAT_A8, w, h, bpr);
    } else {
        t->s = cairo_image_surface_create(f->aonly ? CAIRO_FORMAT_A8 : CAIRO_FORMAT_ARGB32, w, h);
        t->shadow = malloc((size_t)bpr * h);
        if (f->aonly) {               /* A8 surface: copy the alpha samples */
            unsigned char *d = cairo_image_surface_get_data(t->s); int ds = cairo_image_surface_get_stride(t->s);
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) d[y * ds + x] = t->app[(size_t)y * bpr + (size_t)x * bpp + (f->a != 7 ? f->a : 0)];
            cairo_surface_mark_dirty(t->s);
        } else import_pixels(t->s, t->app, w, h, bpr, f);
        memcpy(t->shadow, t->app, (size_t)bpr * h);
    }
    if (cairo_surface_status(t->s) != CAIRO_STATUS_SUCCESS) { cairo_surface_destroy(t->s); free(t->shadow); free(t); return NULL; }
    t->cr = cairo_create(t->s);
    return t;
}
static void target_import(struct cgt *t) {
    if (t->kind != 1 || t->zero || !memcmp(t->shadow, t->app, (size_t)t->bpr * t->h)) return;
    if (t->f.aonly) {
        cairo_surface_flush(t->s);
        unsigned char *d = cairo_image_surface_get_data(t->s); int ds = cairo_image_surface_get_stride(t->s);
        for (int y = 0; y < t->h; y++) for (int x = 0; x < t->w; x++) d[y * ds + x] = t->app[(size_t)y * t->bpr + (size_t)x * t->f.bpp + (t->f.a != 7 ? t->f.a : 0)];
        cairo_surface_mark_dirty(t->s);
    } else import_pixels(t->s, t->app, t->w, t->h, t->bpr, &t->f);
    memcpy(t->shadow, t->app, (size_t)t->bpr * t->h);
}
static void target_export(struct cgt *t) {
    cairo_surface_flush(t->s);
    if (t->kind != 1 || t->zero) return;
    export_pixels(t->s, t->app, t->w, t->h, t->bpr, &t->f);
    memcpy(t->shadow, t->app, (size_t)t->bpr * t->h);
}
void isim_cg_target_sync(void *tp) { struct cgt *t = tp; if (t && !t->depth) target_import(t); }
void isim_cg_target_bind(void *tp) {
    struct cgt *t = tp; if (!t) return;
    if (t->depth++ == 0) { target_import(t); t->saved = isim_host_swap_cairo(t->cr); t->prev = cur_target; cur_target = t; }
}
void isim_cg_target_unbind(void *tp) {
    struct cgt *t = tp; if (!t || t->depth <= 0) return;
    if (--t->depth == 0) { target_export(t); isim_host_swap_cairo(t->saved); cur_target = t->prev; }
}
void isim_cg_target_free(void *tp) {
    struct cgt *t = tp; if (!t) return;
    while (t->depth > 0) isim_cg_target_unbind(t);
    if (t->kind == 2 && t->s) cairo_surface_finish(t->s);
    if (t->cr) cairo_destroy(t->cr);
    if (t->s) cairo_surface_destroy(t->s);
    if (t->buf) g_byte_array_free(t->buf, TRUE);
    free(t->shadow); free(t);
}
int isim_cg_target_image(void *tp) {
    struct cgt *t = tp; if (!t || t->kind != 1) return 0;
    if (!t->depth) target_import(t);
    cairo_surface_flush(t->s);
    cairo_surface_t *c = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, t->w, t->h);
    cairo_t *cc = cairo_create(c);
    if (cairo_image_surface_get_format(t->s) == CAIRO_FORMAT_A8) { cairo_set_source_rgb(cc, 0, 0, 0); cairo_mask_surface(cc, t->s, 0, 0); }
    else { cairo_set_source_surface(cc, t->s, 0, 0); cairo_set_operator(cc, CAIRO_OPERATOR_SOURCE); cairo_paint(cc); }
    cairo_destroy(cc);
    return isim_image_adopt_surface(c);
}

static cairo_status_t pdf_write(void *closure, const unsigned char *data, unsigned int n) {
    g_byte_array_append(closure, data, n); return CAIRO_STATUS_SUCCESS;
}
void *isim_cg_pdf_create(const char *path, double w, double h) {
    struct cgt *t = calloc(1, sizeof *t);
    t->kind = 2; t->pw = w > 0 ? w : 612; t->ph = h > 0 ? h : 792;
    if (path) t->s = cairo_pdf_surface_create(path, t->pw, t->ph);
    else { t->buf = g_byte_array_new(); t->s = cairo_pdf_surface_create_for_stream(pdf_write, t->buf, t->pw, t->ph); }
    if (cairo_surface_status(t->s) != CAIRO_STATUS_SUCCESS) { cairo_surface_destroy(t->s); if (t->buf) g_byte_array_free(t->buf, TRUE); free(t); return NULL; }
    cairo_pdf_surface_set_metadata(t->s, CAIRO_PDF_METADATA_CREATOR, "isim");
    t->cr = cairo_create(t->s);
    return t;
}
void isim_cg_pdf_begin_page(void *tp, double w, double h) {
    struct cgt *t = tp; if (!t || t->kind != 2) return;
    if (t->page_open) isim_cg_pdf_end_page(t);
    if (w > 0 && h > 0) { t->pw = w; t->ph = h; }
    cairo_pdf_surface_set_size(t->s, t->pw, t->ph);
    cairo_identity_matrix(t->cr); cairo_reset_clip(t->cr); cairo_new_path(t->cr);
    t->page_open = 1;
}
void isim_cg_pdf_end_page(void *tp) {
    struct cgt *t = tp; if (!t || t->kind != 2 || !t->page_open) return;
    cairo_show_page(t->cr); t->page_open = 0; t->pages++;
}
long isim_cg_pdf_finish(void *tp, unsigned char **out) {
    struct cgt *t = tp; *out = NULL;
    if (!t || t->kind != 2) return 0;
    if (t->page_open) isim_cg_pdf_end_page(t);
    cairo_destroy(t->cr); t->cr = NULL;
    cairo_surface_finish(t->s);
    long n = 0;
    if (t->buf) { n = t->buf->len; *out = malloc(n ? n : 1); memcpy(*out, t->buf->data, n); }
    cairo_surface_destroy(t->s); t->s = NULL;
    return n;
}

/* ---------------- compositing ---------------- */
void isim_cg_set_blend(int m) {
    static const cairo_operator_t ops[] = {
        CAIRO_OPERATOR_OVER, CAIRO_OPERATOR_MULTIPLY, CAIRO_OPERATOR_SCREEN, CAIRO_OPERATOR_OVERLAY, CAIRO_OPERATOR_DARKEN,
        CAIRO_OPERATOR_LIGHTEN, CAIRO_OPERATOR_COLOR_DODGE, CAIRO_OPERATOR_COLOR_BURN, CAIRO_OPERATOR_SOFT_LIGHT, CAIRO_OPERATOR_HARD_LIGHT,
        CAIRO_OPERATOR_DIFFERENCE, CAIRO_OPERATOR_EXCLUSION, CAIRO_OPERATOR_HSL_HUE, CAIRO_OPERATOR_HSL_SATURATION, CAIRO_OPERATOR_HSL_COLOR,
        CAIRO_OPERATOR_HSL_LUMINOSITY, CAIRO_OPERATOR_CLEAR, CAIRO_OPERATOR_SOURCE, CAIRO_OPERATOR_IN, CAIRO_OPERATOR_OUT,
        CAIRO_OPERATOR_ATOP, CAIRO_OPERATOR_DEST_OVER, CAIRO_OPERATOR_DEST_IN, CAIRO_OPERATOR_DEST_OUT, CAIRO_OPERATOR_DEST_ATOP,
        CAIRO_OPERATOR_XOR, CAIRO_OPERATOR_SATURATE /* plusDarker: approximated */, CAIRO_OPERATOR_ADD /* plusLighter */ };
    cairo_set_operator(isim_host_cairo(), m >= 0 && m < (int)(sizeof ops / sizeof *ops) ? ops[m] : CAIRO_OPERATOR_OVER);
}
void isim_cg_clear_rect(double x, double y, double w, double h) {
    cairo_t *cr = isim_host_cairo();
    cairo_save(cr); cairo_new_path(cr); cairo_rectangle(cr, x, y, w, h); cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR); cairo_fill(cr); cairo_restore(cr);
}
/* m[0..5]: cairo CTM (user -> device, y down); m[6]: device height in pixels (to express it y-up) */
void isim_cg_get_ctm(double *m) {
    cairo_t *cr = isim_host_cairo();
    cairo_matrix_t c; cairo_get_matrix(cr, &c); m[0] = c.xx; m[1] = c.yx; m[2] = c.xy; m[3] = c.yy; m[4] = c.x0; m[5] = c.y0;
    cairo_surface_t *t = cairo_get_target(cr);
    m[6] = cur_target && cur_target->kind == 2 ? cur_target->ph : cairo_surface_get_type(t) == CAIRO_SURFACE_TYPE_IMAGE ? cairo_image_surface_get_height(t) : 0;
}
/* what: 0 path extents (x0 y0 x1 y1; returns 1 if there is a path), 1 current point, 2 clip extents, 3 point (x, y) in fill,
   4 point in stroke, 5 antialias on/off (x) */
int isim_cg_query(int what, double x, double y, double *out) {
    cairo_t *cr = isim_host_cairo();
    switch (what) {
    case 0: { cairo_path_extents(cr, &out[0], &out[1], &out[2], &out[3]); return cairo_has_current_point(cr); }
    case 1: { if (!cairo_has_current_point(cr)) { out[0] = out[1] = 0; return 0; } cairo_get_current_point(cr, &out[0], &out[1]); return 1; }
    case 2: cairo_clip_extents(cr, &out[0], &out[1], &out[2], &out[3]); return 1;
    case 3: return cairo_in_fill(cr, x, y);
    case 4: return cairo_in_stroke(cr, x, y);
    case 5: cairo_set_antialias(cr, x != 0 ? CAIRO_ANTIALIAS_DEFAULT : CAIRO_ANTIALIAS_NONE); return 1;
    }
    return 0;
}
/* the current path flattened to elements of 7 doubles: type (0 move, 1 line, 3 curve, 4 close), 3 points */
int isim_cg_copy_path(double *out, int max) {
    cairo_path_t *p = cairo_copy_path(isim_host_cairo());
    int n = 0;
    for (int i = 0; i < p->num_data; i += p->data[i].header.length) {
        cairo_path_data_t *d = &p->data[i];
        if (out && n < max) {
            double *e = &out[7 * n]; memset(e, 0, 7 * sizeof *e);
            switch (d->header.type) {
            case CAIRO_PATH_MOVE_TO: e[0] = 0; e[1] = d[1].point.x; e[2] = d[1].point.y; break;
            case CAIRO_PATH_LINE_TO: e[0] = 1; e[1] = d[1].point.x; e[2] = d[1].point.y; break;
            case CAIRO_PATH_CURVE_TO: e[0] = 3; for (int k = 0; k < 3; k++) { e[1 + 2 * k] = d[1 + k].point.x; e[2 + 2 * k] = d[1 + k].point.y; } break;
            case CAIRO_PATH_CLOSE_PATH: e[0] = 4; break;
            }
        }
        n++;
    }
    cairo_path_destroy(p);
    return n;
}
void isim_cg_set_ctm(const double *m) { cairo_matrix_t c; cairo_matrix_init(&c, m[0], m[1], m[2], m[3], m[4], m[5]); cairo_set_matrix(isim_host_cairo(), &c); }
void isim_cg_group_begin(void) { cairo_t *cr = isim_host_cairo(); cairo_push_group(cr); cairo_set_operator(cr, CAIRO_OPERATOR_OVER); }

/* 3 box-blur passes on an 8-bit alpha plane (~ Gaussian with sigma ~ r) */
static void blur_a8(unsigned char *px, int w, int h, int stride, int r) {
    if (r < 1) return;
    int n = w > h ? w : h; unsigned char *tmp = malloc((size_t)n);
    for (int pass = 0; pass < 3; pass++)
        for (int dir = 0; dir < 2; dir++) {
            int len = dir ? h : w, lines = dir ? w : h;
            for (int l = 0; l < lines; l++) {
                #define AT(i) px[dir ? (size_t)(i) * stride + l : (size_t)l * stride + (i)]
                for (int i = 0; i < len; i++) tmp[i] = AT(i);
                long sum = 0, win = 2 * r + 1;
                for (int k = -r; k <= r; k++) sum += k < 0 || k >= len ? 0 : tmp[k];
                for (int i = 0; i < len; i++) {
                    AT(i) = (unsigned char)(sum / win);
                    int add = i + r + 1, sub = i - r;
                    sum += (add < len ? tmp[add] : 0) - (sub >= 0 ? tmp[sub] : 0);
                }
                #undef AT
            }
        }
    free(tmp);
}
static double base_scale(cairo_t *cr) {
    if (cur_target) return 1;
    cairo_matrix_t m; cairo_get_matrix(cr, &m);
    double s = sqrt(fabs(m.xx * m.yy - m.xy * m.yx));
    return s > 0 ? s : 1;
}
static void draw_shadow(cairo_t *cr, cairo_pattern_t *p, const struct isim_cg_fx *fx) {
    double scale = base_scale(cr);
    double dx = fx->sdx * scale, dy = fx->sdy * scale * (fx->flip ? -1 : 1), rad = fx->sblur * scale / 2;
    double rgba[4] = { fx->srgba[0], fx->srgba[1], fx->srgba[2], fx->srgba[3] * fx->alpha };
    cairo_surface_t *gs = NULL;
    if (cairo_pattern_get_surface(p, &gs) != CAIRO_STATUS_SUCCESS || cairo_surface_get_type(gs) != CAIRO_SURFACE_TYPE_IMAGE) {
        cairo_save(cr);                                   /* vector targets (PDF): a sharp offset shadow */
        cairo_matrix_t m; cairo_get_matrix(cr, &m); cairo_identity_matrix(cr); cairo_translate(cr, dx, dy); cairo_transform(cr, &m);
        cairo_set_source_rgba(cr, rgba[0], rgba[1], rgba[2], rgba[3]); cairo_mask(cr, p);
        cairo_restore(cr);
        return;
    }
    cairo_surface_flush(gs);
    int gw = cairo_image_surface_get_width(gs), gh = cairo_image_surface_get_height(gs), gst = cairo_image_surface_get_stride(gs);
    double ox, oy; cairo_surface_get_device_offset(gs, &ox, &oy);
    int r = (int)lround(rad), m = 3 * r + 1;
    cairo_surface_t *a8 = cairo_image_surface_create(CAIRO_FORMAT_A8, gw + 2 * m, gh + 2 * m);
    unsigned char *ad = cairo_image_surface_get_data(a8); int as = cairo_image_surface_get_stride(a8);
    const unsigned char *src = cairo_image_surface_get_data(gs);
    memset(ad, 0, (size_t)as * (gh + 2 * m));
    for (int y = 0; y < gh; y++) for (int x = 0; x < gw; x++) ad[(size_t)(y + m) * as + x + m] = ((const uint32_t *)(src + (size_t)y * gst))[x] >> 24;
    blur_a8(ad, gw + 2 * m, gh + 2 * m, as, r);
    cairo_surface_mark_dirty(a8);
    cairo_save(cr);
    cairo_identity_matrix(cr);
    cairo_set_source_rgba(cr, rgba[0], rgba[1], rgba[2], rgba[3]);
    cairo_mask_surface(cr, a8, -ox - m + dx, -oy - m + dy);
    cairo_restore(cr);
    cairo_surface_destroy(a8);
}
/* an A8 coverage surface from the mask image's pixel rect (alpha, or luminance for opaque masks), scaled by alpha */
static cairo_surface_t *mask_surface(const struct isim_cg_fx *fx) {
    int owned; cairo_surface_t *s = isim_image_get_surface(fx->mask_handle, &owned);
    if (!s) return NULL;
    int w = (int)fx->msw, h = (int)fx->msh, x0 = (int)fx->msx, y0 = (int)fx->msy;
    int sw = cairo_image_surface_get_width(s), sh = cairo_image_surface_get_height(s), ss = cairo_image_surface_get_stride(s);
    cairo_format_t cf = cairo_image_surface_get_format(s);
    const unsigned char *src = cairo_image_surface_get_data(s);
    int lum = fx->mask_luminance == 1;
    if (fx->mask_luminance == 2 && cf != CAIRO_FORMAT_A8) {           /* auto: opaque images mask by luminance */
        lum = 1;
        for (int y = 0; y < h && lum; y++) for (int x = 0; x < w; x++) {
            int sx = x0 + x, sy = y0 + y;
            if (sx >= 0 && sy >= 0 && sx < sw && sy < sh && (((const uint32_t *)(src + (size_t)sy * ss))[sx] >> 24) != 255) { lum = 0; break; }
        }
    }
    cairo_surface_t *a8 = cairo_image_surface_create(CAIRO_FORMAT_A8, w > 0 ? w : 1, h > 0 ? h : 1);
    unsigned char *d = cairo_image_surface_get_data(a8); int ds = cairo_image_surface_get_stride(a8);
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
        int sx = x0 + x, sy = y0 + y; unsigned v = 0;
        if (sx >= 0 && sy >= 0 && sx < sw && sy < sh) {
            if (cf == CAIRO_FORMAT_A8) v = src[(size_t)sy * ss + sx];
            else {
                uint32_t p = ((const uint32_t *)(src + (size_t)sy * ss))[sx];
                v = lum ? (unsigned)lround(0.299 * (p >> 16 & 255) + 0.587 * (p >> 8 & 255) + 0.114 * (p & 255)) : p >> 24;
            }
        }
        d[(size_t)y * ds + x] = (unsigned char)lround(v * (fx->alpha < 1 ? fx->alpha : 1));
    }
    cairo_surface_mark_dirty(a8);
    if (owned) cairo_surface_destroy(s);
    return a8;
}
void isim_cg_group_end(const struct isim_cg_fx *fx) {
    cairo_t *cr = isim_host_cairo();
    cairo_pattern_t *p = cairo_pop_group(cr);
    if (fx->shadow && fx->srgba[3] > 0) draw_shadow(cr, p, fx);
    cairo_save(cr);
    cairo_set_source(cr, p);
    cairo_surface_t *ms = fx->mask_handle ? mask_surface(fx) : NULL;
    if (ms) {
        cairo_matrix_t m; cairo_matrix_init(&m, fx->mm[0], fx->mm[1], fx->mm[2], fx->mm[3], fx->mm[4], fx->mm[5]);
        cairo_set_matrix(cr, &m);
        cairo_translate(cr, 0, fx->my * 2 + fx->mh); cairo_scale(cr, 1, -1);      /* images are drawn y-up within the rect */
        cairo_translate(cr, fx->mx, fx->my);
        cairo_scale(cr, fx->mw / cairo_image_surface_get_width(ms), fx->mh / cairo_image_surface_get_height(ms));
        cairo_pattern_t *mp = cairo_pattern_create_for_surface(ms);
        cairo_pattern_set_filter(mp, CAIRO_FILTER_GOOD);
        cairo_mask(cr, mp);
        cairo_pattern_destroy(mp);
        cairo_surface_destroy(ms);
    } else if (fx->alpha >= 0.999) cairo_paint(cr);
    else cairo_paint_with_alpha(cr, fx->alpha);
    cairo_restore(cr);
    cairo_pattern_destroy(p);
}

void isim_cg_fill_pattern(int hd, double cw, double ch, const double *mx, int mode, double lw, double alpha) {
    cairo_t *cr = isim_host_cairo();
    int owned; cairo_surface_t *s = isim_image_get_surface(hd, &owned);
    if (!s || cw <= 0 || ch <= 0) return;
    cairo_pattern_t *p = cairo_pattern_create_for_surface(s);
    cairo_pattern_set_extend(p, CAIRO_EXTEND_REPEAT);
    cairo_matrix_t m; cairo_matrix_init(&m, mx[0], mx[1], mx[2], mx[3], mx[4], mx[5]);   /* pattern -> user */
    cairo_matrix_t sc; cairo_matrix_init_scale(&sc, cw / cairo_image_surface_get_width(s), ch / cairo_image_surface_get_height(s));
    cairo_matrix_t full; cairo_matrix_multiply(&full, &sc, &m);                          /* pixels -> user */
    if (cairo_matrix_invert(&full) == CAIRO_STATUS_SUCCESS) cairo_pattern_set_matrix(p, &full);
    cairo_save(cr);
    cairo_set_source(cr, p);
    if (mode == 0) { if (alpha >= 0.999) cairo_fill_preserve(cr); else { cairo_clip_preserve(cr); cairo_paint_with_alpha(cr, alpha); } }
    else if (mode == 1) { cairo_set_line_width(cr, lw); cairo_stroke_preserve(cr); }
    else cairo_paint_with_alpha(cr, alpha);
    cairo_restore(cr);
    cairo_pattern_destroy(p);
    if (owned) cairo_surface_destroy(s);
}
void isim_cg_draw_image_tiled(int hd, double sx, double sy, double sw, double sh, double x, double y, double w, double h, double tw, double th) {
    cairo_t *cr = isim_host_cairo();
    int owned; cairo_surface_t *s = isim_image_get_surface(hd, &owned);
    if (!s || sw <= 0 || sh <= 0 || tw <= 0 || th <= 0) return;
    cairo_surface_t *sub = cairo_surface_create_for_rectangle(s, sx, sy, sw, sh);
    cairo_pattern_t *p = cairo_pattern_create_for_surface(sub);
    /* one tile covering the rect = a stretch: pad the edges so neighbouring source pixels do not bleed in */
    cairo_pattern_set_extend(p, tw >= w - 1e-9 && th >= h - 1e-9 ? CAIRO_EXTEND_PAD : CAIRO_EXTEND_REPEAT);
    cairo_matrix_t m; cairo_matrix_init_scale(&m, sw / tw, sh / th); cairo_matrix_translate(&m, -x, -y);
    cairo_pattern_set_matrix(p, &m);
    cairo_save(cr); cairo_new_path(cr); cairo_rectangle(cr, x, y, w, h); cairo_set_source(cr, p); cairo_fill(cr); cairo_restore(cr);
    cairo_pattern_destroy(p); cairo_surface_destroy(sub);
    if (owned) cairo_surface_destroy(s);
}

/* ---------------- Core Text: Pango layouts ---------------- */
static PangoContext *ct_context(void) {
    static PangoContext *ctx;
    if (!ctx) {
        ctx = pango_font_map_create_context(pango_cairo_font_map_get_default());
        pango_cairo_context_set_resolution(ctx, 72);
        cairo_font_options_t *fo = cairo_font_options_create();
        cairo_font_options_set_antialias(fo, CAIRO_ANTIALIAS_GRAY);
        cairo_font_options_set_hint_style(fo, CAIRO_HINT_STYLE_SLIGHT);
        cairo_font_options_set_hint_metrics(fo, CAIRO_HINT_METRICS_OFF);
        pango_cairo_context_set_font_options(ctx, fo);
        cairo_font_options_destroy(fo);
    }
    return ctx;
}
void *isim_ct_layout_create(const char *markup, double width, int align, double spacing, int single) {
    PangoLayout *l = pango_layout_new(ct_context());
    PangoFontDescription *fd = pango_font_description_new();
    pango_font_description_set_family(fd, "Adwaita Sans,Inter,Noto Sans,sans-serif");   /* the system font, as UIKit text */
    pango_font_description_set_absolute_size(fd, 12 * PANGO_SCALE);    /* CTFont's default size */
    pango_layout_set_font_description(l, fd); pango_font_description_free(fd);
    pango_layout_set_markup(l, markup ? markup : "", -1);
    if (single) pango_layout_set_single_paragraph_mode(l, TRUE);
    if (width > 0) { pango_layout_set_width(l, (int)(width * PANGO_SCALE)); pango_layout_set_wrap(l, PANGO_WRAP_WORD_CHAR); }
    /* single 2/3/4: one line truncated at the start / middle / end (CTLineCreateTruncatedLine) */
    if (single >= 2 && width > 0) pango_layout_set_ellipsize(l, single == 2 ? PANGO_ELLIPSIZE_START : single == 3 ? PANGO_ELLIPSIZE_MIDDLE : PANGO_ELLIPSIZE_END);
    pango_layout_set_alignment(l, align == 1 ? PANGO_ALIGN_CENTER : align == 2 ? PANGO_ALIGN_RIGHT : PANGO_ALIGN_LEFT);
    if (align == 3) pango_layout_set_justify(l, TRUE);
    if (spacing > 0) pango_layout_set_spacing(l, (int)(spacing * PANGO_SCALE));
    return l;
}
void isim_ct_layout_free(void *l) { if (l) g_object_unref(l); }
int isim_ct_layout_lines(void *l) { return pango_layout_get_line_count(l); }
void isim_ct_line_info(void *lp, int line, double *asc, double *desc, double *width, double *x, double *baseline, int *start, int *len, double *trailing) {
    PangoLayout *l = lp;
    PangoLayoutIter *it = pango_layout_get_iter(l);
    for (int i = 0; i < line && pango_layout_iter_next_line(it); i++) {}
    PangoLayoutLine *ln = pango_layout_iter_get_line_readonly(it);
    PangoRectangle ink, log; pango_layout_iter_get_line_extents(it, &ink, &log);
    int base = pango_layout_iter_get_baseline(it);
    *asc = (double)(base - log.y) / PANGO_SCALE; *desc = (double)(log.y + log.height - base) / PANGO_SCALE;
    *x = (double)log.x / PANGO_SCALE; *baseline = (double)base / PANGO_SCALE;
    PangoRectangle lr; pango_layout_line_get_extents(ln, NULL, &lr); *width = (double)lr.width / PANGO_SCALE;
    *start = ln->start_index; *len = ln->length;
    /* trailing whitespace width */
    const char *text = pango_layout_get_text(l); double tw = 0;
    int end = ln->start_index + ln->length, k = end;
    while (k > ln->start_index && (text[k - 1] == ' ' || text[k - 1] == '\t' || text[k - 1] == '\n')) k--;
    if (k < end) { int xa, xb; pango_layout_line_index_to_x(ln, k, 0, &xa); pango_layout_line_index_to_x(ln, end, 0, &xb); tw = fabs((double)(xb - xa)) / PANGO_SCALE; }
    *trailing = tw;
    pango_layout_iter_free(it);
}
static PangoLayoutLine *line_at(void *l, int line) { return pango_layout_get_line_readonly(l, line); }
int isim_ct_line_runs(void *l, int line, struct isim_ct_run *out, int max) {
    PangoLayoutLine *ln = line_at(l, line); if (!ln) return 0;
    int n = 0; double x = 0;
    for (GSList *r = ln->runs; r; r = r->next) {
        PangoGlyphItem *gi = r->data;
        double w = (double)pango_glyph_string_get_width(gi->glyphs) / PANGO_SCALE;
        if (out && n < max) {
            struct isim_ct_run *o = &out[n]; memset(o, 0, sizeof *o);
            o->start = gi->item->offset; o->len = gi->item->length; o->glyphs = gi->glyphs->num_glyphs; o->x = x; o->width = w;
            PangoFontDescription *fd = pango_font_describe(gi->item->analysis.font);
            snprintf(o->family, sizeof o->family, "%s", pango_font_description_get_family(fd) ? pango_font_description_get_family(fd) : "");
            o->size = (double)pango_font_description_get_size(fd) / PANGO_SCALE;
            o->weight = pango_font_description_get_weight(fd); o->italic = pango_font_description_get_style(fd) != PANGO_STYLE_NORMAL;
            pango_font_description_free(fd);
            for (GSList *a = gi->item->analysis.extra_attrs; a; a = a->next) {
                PangoAttribute *at = a->data;
                if (at->klass->type == PANGO_ATTR_FOREGROUND) {
                    PangoColor c = ((PangoAttrColor *)at)->color;
                    o->rgba[0] = c.red / 65535.0; o->rgba[1] = c.green / 65535.0; o->rgba[2] = c.blue / 65535.0; o->rgba[3] = 1; o->has_color = 1;
                }
            }
        }
        x += w; n++;
    }
    return n;
}
int isim_ct_run_glyphs(void *l, int line, int run, unsigned short *glyphs, double *pos, double *adv, int *idx, int max) {
    PangoLayoutLine *ln = line_at(l, line); if (!ln) return 0;
    double x = 0; int k = 0;
    for (GSList *r = ln->runs; r; r = r->next, k++) {
        PangoGlyphItem *gi = r->data;
        if (k != run) { x += (double)pango_glyph_string_get_width(gi->glyphs) / PANGO_SCALE; continue; }
        int n = gi->glyphs->num_glyphs;
        for (int i = 0; i < n && i < max; i++) {
            PangoGlyphInfo *g = &gi->glyphs->glyphs[i];
            if (glyphs) glyphs[i] = (unsigned short)(g->glyph & 0xffff);
            if (pos) { pos[2 * i] = x + (double)g->geometry.x_offset / PANGO_SCALE; pos[2 * i + 1] = -(double)g->geometry.y_offset / PANGO_SCALE; }
            if (adv) adv[i] = (double)g->geometry.width / PANGO_SCALE;
            if (idx) idx[i] = gi->item->offset + gi->glyphs->log_clusters[i];
            x += (double)g->geometry.width / PANGO_SCALE;
        }
        return n;
    }
    return 0;
}
int isim_ct_line_index_at(void *l, int line, double x) {
    PangoLayoutLine *ln = line_at(l, line); if (!ln) return 0;
    int idx = 0, trailing = 0;
    pango_layout_line_x_to_index(ln, (int)(x * PANGO_SCALE), &idx, &trailing);
    const char *t = pango_layout_get_text(l);
    while (trailing-- > 0 && t[idx]) idx = (int)(g_utf8_next_char(t + idx) - t);
    return idx;
}
double isim_ct_line_x_at(void *l, int line, int byte_index) {
    PangoLayoutLine *ln = line_at(l, line); if (!ln) return 0;
    int x = 0; pango_layout_line_index_to_x(ln, byte_index, 0, &x);
    return (double)x / PANGO_SCALE;
}
void isim_ct_line_draw(void *l, int line, double x, double y, const double *tm, const double *rgba) {
    PangoLayoutLine *ln = line_at(l, line); if (!ln) return;
    cairo_t *cr = isim_host_cairo();
    pango_cairo_update_context(cr, ct_context());
    pango_layout_context_changed(l);
    ln = line_at(l, line);
    cairo_save(cr);
    cairo_translate(cr, x, y);
    if (tm) { cairo_matrix_t m; cairo_matrix_init(&m, tm[0], tm[1], tm[2], tm[3], tm[4], tm[5]); cairo_transform(cr, &m); }
    cairo_scale(cr, 1, -1);                         /* Core Graphics text space is y-up */
    cairo_new_path(cr); cairo_move_to(cr, 0, 0);
    cairo_set_source_rgba(cr, rgba[0], rgba[1], rgba[2], rgba[3]);
    pango_cairo_show_layout_line(cr, ln);
    cairo_restore(cr);
}

/* ---------------- ImageIO ---------------- */
static int has_bytes(const unsigned char *d, long len, long off, const char *s, long n) { return len >= off + n && !memcmp(d + off, s, n); }
static int has_prefix(const unsigned char *d, long len, long off, const char *s) { return has_bytes(d, len, off, s, (long)strlen(s)); }
static const char *sniff(const unsigned char *d, long len) {
    if (has_prefix(d, len, 0, "\x89PNG\r\n\x1a\n")) return "public.png";
    if (len > 3 && d[0] == 0xff && d[1] == 0xd8 && d[2] == 0xff) return "public.jpeg";
    if (has_prefix(d, len, 0, "GIF8")) return "com.compuserve.gif";
    if (has_prefix(d, len, 0, "RIFF") && has_prefix(d, len, 8, "WEBP")) return "org.webmproject.webp";
    if (has_prefix(d, len, 4, "ftypheic") || has_prefix(d, len, 4, "ftypheix") || has_prefix(d, len, 4, "ftypmif1") || has_prefix(d, len, 4, "ftypheis")) return "public.heic";
    if (has_prefix(d, len, 4, "ftypavif")) return "public.avif";
    if (has_prefix(d, len, 0, "BM")) return "com.microsoft.bmp";
    if (has_bytes(d, len, 0, "II*\0", 4) || has_bytes(d, len, 0, "MM\0*", 4)) return "public.tiff";
    if (has_bytes(d, len, 0, "\0\0\1\0", 4) && len > 6 && d[4]) return "com.microsoft.ico";
    if (has_prefix(d, len, 0, "<?xml") || has_prefix(d, len, 0, "<svg")) return "public.svg-image";
    return NULL;
}
/* GIF: number of frames, netscape loop count, delays (centiseconds) without decoding */
static int gif_scan(const unsigned char *d, long len, int *loops, int *delays, int maxd) {
    if (len < 13) return 0;
    long p = 13; int frames = 0, delay = 0; *loops = 1;
    if (d[10] & 0x80) p += 3L * (1 << ((d[10] & 7) + 1));
    while (p < len) {
        unsigned char b = d[p++];
        if (b == 0x3b) break;
        if (b == 0x21 && p < len) {
            unsigned char label = d[p++];
            if (label == 0xf9 && p + 5 < len) delay = d[p + 2] | d[p + 3] << 8;
            if (label == 0xff && p + 16 < len && !memcmp(d + p + 1, "NETSCAPE2.0", 11)) *loops = d[p + 14] | d[p + 15] << 8;
            while (p < len && d[p]) p += d[p] + 1;
            p++;
        } else if (b == 0x2c && p + 9 <= len) {
            unsigned char fl = d[p + 8]; p += 9;
            if (fl & 0x80) p += 3L * (1 << ((fl & 7) + 1));
            p++;                                            /* LZW minimum code size */
            while (p < len && d[p]) p += d[p] + 1;
            p++;
            if (delays && frames < maxd) delays[frames] = delay;
            frames++; delay = 0;
        } else break;
    }
    return frames;
}
static int webp_frames(const unsigned char *d, long len) {
    int n = 0;
    for (long p = 12; p + 8 <= len;) {
        uint32_t sz = d[p + 4] | d[p + 5] << 8 | d[p + 6] << 16 | (uint32_t)d[p + 7] << 24;
        if (!memcmp(d + p, "ANMF", 4)) n++;
        p += 8 + sz + (sz & 1);
    }
    return n ? n : 1;
}
/* HEIC/AVIF through ffmpeg (if installed): first image as PNG bytes */
static unsigned char *ffmpeg_to_png(const void *data, long len, long *outlen) {
    char in[] = "/tmp/isim-imgsrc-XXXXXX"; int fd = mkstemp(in); if (fd < 0) return NULL;
    long w = write(fd, data, (size_t)len); close(fd);
    unsigned char *res = NULL; *outlen = 0;
    if (w == len) {
        char cmd[512]; snprintf(cmd, sizeof cmd, "ffmpeg -nostdin -loglevel error -i '%s' -frames:v 1 -f image2pipe -c:v png - 2>/dev/null", in);
        FILE *p = popen(cmd, "r");
        if (p) {
            GByteArray *a = g_byte_array_new(); unsigned char buf[65536]; size_t n;
            while ((n = fread(buf, 1, sizeof buf, p)) > 0) g_byte_array_append(a, buf, (guint)n);
            if (pclose(p) == 0 && a->len > 8) { *outlen = a->len; res = malloc(a->len); memcpy(res, a->data, a->len); }
            g_byte_array_free(a, TRUE);
        }
    }
    unlink(in);
    return res;
}
static GdkPixbufAnimation *load_animation(const void *data, long len) {
    GdkPixbufLoader *l = gdk_pixbuf_loader_new();
    int ok = gdk_pixbuf_loader_write(l, data, (gsize)len, NULL);
    ok = gdk_pixbuf_loader_close(l, NULL) && ok;
    GdkPixbufAnimation *a = ok ? gdk_pixbuf_loader_get_animation(l) : NULL;
    if (a) g_object_ref(a);
    g_object_unref(l);
    return a;
}
int isim_imgsrc_info(const void *data, long len, int *frames, int *w, int *h, char *type, int typelen, int *orientation, int *alpha, int *loops) {
    const unsigned char *d = data;
    const char *t = sniff(d, len);
    *frames = 0; *w = *h = 0; *orientation = 1; *alpha = 0; *loops = 1;
    if (type && typelen > 0) snprintf(type, typelen, "%s", t ? t : "");
    if (!t) return 0;
    if (!strcmp(t, "public.heic") || !strcmp(t, "public.avif")) {
        double fw, fh; long n; unsigned char *png = NULL;
        int hd = isim_image_load_data(data, (unsigned long)len, &fw, &fh);
        if (!hd && (png = ffmpeg_to_png(data, len, &n))) hd = isim_image_load_data(png, (unsigned long)n, &fw, &fh);
        free(png);
        if (!hd) return 0;
        extern void isim_image_free(int hd);
        isim_image_free(hd);
        *frames = 1; *w = (int)fw; *h = (int)fh; *alpha = 1;
        return 1;
    }
    if (!strcmp(t, "public.svg-image")) { double fw, fh; int hd = isim_image_load_data(data, (unsigned long)len, &fw, &fh); if (!hd) return 0; extern void isim_image_free(int); isim_image_free(hd); *frames = 1; *w = (int)fw; *h = (int)fh; *alpha = 1; return 1; }
    GdkPixbufAnimation *a = load_animation(data, len);
    if (!a) return 0;
    *w = gdk_pixbuf_animation_get_width(a); *h = gdk_pixbuf_animation_get_height(a);
    GdkPixbuf *st = gdk_pixbuf_animation_get_static_image(a);
    if (st) {
        *alpha = gdk_pixbuf_get_has_alpha(st);
        const char *o = gdk_pixbuf_get_option(st, "orientation");
        if (o) *orientation = atoi(o) > 0 ? atoi(o) : 1;
    }
    if (!strcmp(t, "com.compuserve.gif")) *frames = gif_scan(d, len, loops, NULL, 0);
    else if (!strcmp(t, "org.webmproject.webp")) { *frames = webp_frames(d, len); if (*frames > 1) *loops = 0; }
    else *frames = 1;
    if (*frames < 1) *frames = 1;
    g_object_unref(a);
    return 1;
}
static int adopt_pixbuf(GdkPixbuf *pb) {
    int w = gdk_pixbuf_get_width(pb), h = gdk_pixbuf_get_height(pb), nc = gdk_pixbuf_get_n_channels(pb), rs = gdk_pixbuf_get_rowstride(pb);
    return isim_image_from_pixels(gdk_pixbuf_get_pixels(pb), w, h, rs, nc == 4 ? (0 | 1 << 3 | 2 << 6 | 3 << 9) : (0 | 1 << 3 | 2 << 6 | 7 << 9), nc);
}
int isim_imgsrc_frame(const void *data, long len, int index, double *delay) {
    const unsigned char *d = data;
    const char *t = sniff(d, len);
    *delay = 0;
    if (!t) return 0;
    int heif = !strcmp(t, "public.heic") || !strcmp(t, "public.avif");
    if (heif || !strcmp(t, "public.svg-image") || !strcmp(t, "public.png")) {
        double fw, fh; long n; unsigned char *png = NULL;
        int hd = isim_image_load_data(data, (unsigned long)len, &fw, &fh);
        if (!hd && heif && (png = ffmpeg_to_png(data, len, &n))) hd = isim_image_load_data(png, (unsigned long)n, &fw, &fh);
        free(png);
        if (hd || heif || strcmp(t, "public.png")) return hd;
    }
    GdkPixbufAnimation *a = load_animation(data, len);
    if (!a) return 0;
    int hd = 0;
    if (gdk_pixbuf_animation_is_static_image(a) || index == 0) {
        GdkPixbuf *pb = gdk_pixbuf_animation_get_static_image(a);
        if (!gdk_pixbuf_animation_is_static_image(a)) {
            GTimeVal tv = { 0, 0 };
            G_GNUC_BEGIN_IGNORE_DEPRECATIONS
            GdkPixbufAnimationIter *it = gdk_pixbuf_animation_get_iter(a, &tv);
            pb = gdk_pixbuf_animation_iter_get_pixbuf(it);
            *delay = gdk_pixbuf_animation_iter_get_delay_time(it) / 1000.0;
            hd = pb ? adopt_pixbuf(pb) : 0;
            g_object_unref(it);
            G_GNUC_END_IGNORE_DEPRECATIONS
        } else hd = pb ? adopt_pixbuf(pb) : 0;
    } else {
        G_GNUC_BEGIN_IGNORE_DEPRECATIONS
        GTimeVal tv = { 1000, 0 };
        GdkPixbufAnimationIter *it = gdk_pixbuf_animation_get_iter(a, &tv);
        for (int i = 0; i < index; i++) {
            int dms = gdk_pixbuf_animation_iter_get_delay_time(it);
            if (dms < 0) break;
            g_time_val_add(&tv, (glong)dms * 1000 + 1);
            gdk_pixbuf_animation_iter_advance(it, &tv);
        }
        GdkPixbuf *pb = gdk_pixbuf_animation_iter_get_pixbuf(it);
        *delay = gdk_pixbuf_animation_iter_get_delay_time(it) / 1000.0;
        hd = pb ? adopt_pixbuf(pb) : 0;
        g_object_unref(it);
        G_GNUC_END_IGNORE_DEPRECATIONS
    }
    g_object_unref(a);
    return hd;
}

/* GIF89a writer: exact palette when a frame has <= 255 colors, else a 6x7x6 color cube; index 255 is transparent.
   LZW with a clear code every 254 codes (9-bit codes, valid but uncompressed-sized). */
struct bits { GByteArray *a; unsigned char blk[255]; int nblk; uint32_t acc; int nacc; };
static void bits_flush_block(struct bits *b) { if (!b->nblk) return; unsigned char n = (unsigned char)b->nblk; g_byte_array_append(b->a, &n, 1); g_byte_array_append(b->a, b->blk, b->nblk); b->nblk = 0; }
static void bits_put(struct bits *b, unsigned code, int width) {
    b->acc |= code << b->nacc; b->nacc += width;
    while (b->nacc >= 8) { b->blk[b->nblk++] = b->acc & 255; b->acc >>= 8; b->nacc -= 8; if (b->nblk == 255) bits_flush_block(b); }
}
static void put16(GByteArray *a, int v) { unsigned char b[2] = { (unsigned char)(v & 255), (unsigned char)(v >> 8 & 255) }; g_byte_array_append(a, b, 2); }
long isim_image_encode_gif(const int *handles, int n, const double *delays, int loops, unsigned char **out) {
    *out = NULL;
    if (n <= 0) return 0;
    double fw, fh; isim_image_pixel_size(handles[0], &fw, &fh);
    int W = (int)fw, H = (int)fh;
    if (W <= 0 || H <= 0) return 0;
    GByteArray *a = g_byte_array_new();
    g_byte_array_append(a, (const guint8 *)"GIF89a", 6); put16(a, W); put16(a, H);
    unsigned char lsd[3] = { 0, 0, 0 }; g_byte_array_append(a, lsd, 3);           /* no global color table */
    if (n > 1) {
        const unsigned char ext[] = { 0x21, 0xff, 11, 'N', 'E', 'T', 'S', 'C', 'A', 'P', 'E', '2', '.', '0', 3, 1 };
        g_byte_array_append(a, ext, sizeof ext); put16(a, loops < 0 ? 0 : loops); unsigned char z = 0; g_byte_array_append(a, &z, 1);
    }
    unsigned char *rgba = malloc((size_t)W * H * 4), *idx = malloc((size_t)W * H);
    for (int f = 0; f < n; f++) {
        memset(rgba, 0, (size_t)W * H * 4);
        isim_image_read_pixels(handles[f], 0, 0, W, H, rgba, W * 4, 0 | 1 << 3 | 2 << 6 | 3 << 9, 4);
        /* palette */
        uint32_t pal[256]; int np = 0, exact = 1, transparent = 0;
        for (long i = 0; i < (long)W * H && exact; i++) {
            if (rgba[4 * i + 3] < 128) { transparent = 1; continue; }
            uint32_t c = (uint32_t)rgba[4 * i] << 16 | rgba[4 * i + 1] << 8 | rgba[4 * i + 2]; int k;
            for (k = 0; k < np && pal[k] != c; k++) {}
            if (k == np) { if (np == 255) exact = 0; else pal[np++] = c; }
        }
        if (!exact) { np = 0; for (int r = 0; r < 6; r++) for (int g = 0; g < 7; g++) for (int b = 0; b < 6; b++) pal[np++] = (uint32_t)(r * 51) << 16 | (uint32_t)(g * 255 / 6) << 8 | (uint32_t)(b * 51); }
        for (long i = 0; i < (long)W * H; i++) {
            if (rgba[4 * i + 3] < 128) { idx[i] = 255; continue; }
            int r = rgba[4 * i], g = rgba[4 * i + 1], b = rgba[4 * i + 2];
            if (exact) { uint32_t c = (uint32_t)r << 16 | g << 8 | b; int k = 0; while (pal[k] != c) k++; idx[i] = (unsigned char)k; }
            else idx[i] = (unsigned char)((r * 5 + 127) / 255 * 42 + (g * 6 + 127) / 255 * 6 + (b * 5 + 127) / 255);
        }
        int cs = (int)lround((delays ? delays[f] : 0) * 100);
        unsigned char gce[8] = { 0x21, 0xf9, 4, (unsigned char)((transparent ? 1 : 0) | (n > 1 ? 2 << 2 : 0)), (unsigned char)(cs & 255), (unsigned char)(cs >> 8 & 255), 255, 0 };
        g_byte_array_append(a, gce, 8);
        unsigned char id = 0x2c; g_byte_array_append(a, &id, 1); put16(a, 0); put16(a, 0); put16(a, W); put16(a, H);
        unsigned char fl = 0x80 | 7; g_byte_array_append(a, &fl, 1);                 /* local table, 256 entries */
        for (int k = 0; k < 256; k++) { uint32_t c = k < np ? pal[k] : 0; unsigned char rgb[3] = { (unsigned char)(c >> 16), (unsigned char)(c >> 8), (unsigned char)c }; g_byte_array_append(a, rgb, 3); }
        unsigned char mcs = 8; g_byte_array_append(a, &mcs, 1);
        struct bits b = { a, { 0 }, 0, 0, 0 };
        int since = 0;
        bits_put(&b, 256, 9);
        for (long i = 0; i < (long)W * H; i++) {
            bits_put(&b, idx[i], 9);
            if (++since == 254) { bits_put(&b, 256, 9); since = 0; }
        }
        bits_put(&b, 257, 9);
        if (b.nacc) { b.blk[b.nblk++] = b.acc & 255; b.acc = 0; b.nacc = 0; }
        bits_flush_block(&b);
        unsigned char z = 0; g_byte_array_append(a, &z, 1);
    }
    unsigned char trailer = 0x3b; g_byte_array_append(a, &trailer, 1);
    free(rgba); free(idx);
    long len = a->len; *out = malloc(len); memcpy(*out, a->data, len);
    g_byte_array_free(a, TRUE);
    return len;
}

/* ---------------- PDF reading (poppler-glib, optional) ---------------- */
static struct {
    int tried, ok;
    void *(*doc_new_from_bytes)(GBytes *, const char *, GError **);
    int (*n_pages)(void *);
    void *(*get_page)(void *, int);
    void (*page_size)(void *, double *, double *);
    void (*render)(void *, cairo_t *);
} pp;
int isim_pdf_available(void) {
    if (!pp.tried) {
        pp.tried = 1;
        void *h = dlopen("libpoppler-glib.so.8", RTLD_NOW | RTLD_LOCAL);
        if (!h) h = dlopen("libpoppler-glib.so", RTLD_NOW | RTLD_LOCAL);
        if (h) {
            pp.doc_new_from_bytes = dlsym(h, "poppler_document_new_from_bytes");
            pp.n_pages = dlsym(h, "poppler_document_get_n_pages");
            pp.get_page = dlsym(h, "poppler_document_get_page");
            pp.page_size = dlsym(h, "poppler_page_get_size");
            pp.render = dlsym(h, "poppler_page_render");
            pp.ok = pp.doc_new_from_bytes && pp.n_pages && pp.get_page && pp.page_size && pp.render;
        }
    }
    return pp.ok;
}
void *isim_pdf_open(const void *data, long len, int *pages) {
    *pages = 0;
    if (!isim_pdf_available() || !data || len <= 0) return NULL;
    GBytes *b = g_bytes_new(data, (gsize)len);
    void *doc = pp.doc_new_from_bytes(b, NULL, NULL);
    g_bytes_unref(b);
    if (doc) *pages = pp.n_pages(doc);
    return doc;
}
void isim_pdf_page_size(void *doc, int page, double *w, double *h) {
    *w = *h = 0;
    void *p = doc && pp.ok ? pp.get_page(doc, page) : NULL;
    if (p) { pp.page_size(p, w, h); g_object_unref(p); }
}
void isim_pdf_page_render(void *doc, int page) {
    void *p = doc && pp.ok ? pp.get_page(doc, page) : NULL;
    if (!p) return;
    cairo_t *cr = isim_host_cairo();
    cairo_save(cr); cairo_new_path(cr);
    pp.render(p, cr);
    cairo_restore(cr);
    g_object_unref(p);
}
void isim_pdf_close(void *doc) { if (doc) g_object_unref(doc); }
