/*
 * libisim_host Core Animation helpers: perspective (projective) image warps for CATransform3D layers and
 * blurred drop shadows (CALayer shadows, shadowPath).
 *
 *  - isim_image_draw_quad: maps a raster image onto a quadrilateral of the current user space with the
 *    homography that sends the image's corners to the quad's corners (a true perspective warp, bilinear
 *    sampling, computed per device pixel inside the quad's bounding box and the clip).
 *  - isim_gfx_pop_group_shadow: pops a group whose alpha is the shadow's shape and paints it blurred
 *    (3-pass box blur ~ a Gaussian), tinted and offset, under whatever is drawn next.
 */
#define _GNU_SOURCE
#include <cairo.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

cairo_t *isim_host_cairo(void);
cairo_surface_t *isim_image_surface(int handle);      /* host_image.c: raster surface of a handle (NULL otherwise) */

/* homography H (3x3, row-major) with H * (u, v, 1) ~ (x, y, 1) for the unit square corners (0,0) (1,0) (1,1) (0,1) */
static int square_to_quad(const double q[8], double H[9]) {
    double x0 = q[0], y0 = q[1], x1 = q[2], y1 = q[3], x2 = q[4], y2 = q[5], x3 = q[6], y3 = q[7];
    double dx1 = x1 - x2, dx2 = x3 - x2, dy1 = y1 - y2, dy2 = y3 - y2;
    double sx = x0 - x1 + x2 - x3, sy = y0 - y1 + y2 - y3;
    double g = 0, h = 0;
    if (fabs(sx) > 1e-9 || fabs(sy) > 1e-9) {
        double den = dx1 * dy2 - dx2 * dy1;
        if (fabs(den) < 1e-12) return 0;
        g = (sx * dy2 - dx2 * sy) / den;
        h = (dx1 * sy - sx * dy1) / den;
    }
    H[0] = x1 - x0 + g * x1; H[1] = x3 - x0 + h * x3; H[2] = x0;
    H[3] = y1 - y0 + g * y1; H[4] = y3 - y0 + h * y3; H[5] = y0;
    H[6] = g; H[7] = h; H[8] = 1;
    return 1;
}
static int invert3(const double m[9], double o[9]) {
    double det = m[0] * (m[4] * m[8] - m[5] * m[7]) - m[1] * (m[3] * m[8] - m[5] * m[6]) + m[2] * (m[3] * m[7] - m[4] * m[6]);
    if (fabs(det) < 1e-15) return 0;
    o[0] = (m[4] * m[8] - m[5] * m[7]) / det; o[1] = (m[2] * m[7] - m[1] * m[8]) / det; o[2] = (m[1] * m[5] - m[2] * m[4]) / det;
    o[3] = (m[5] * m[6] - m[3] * m[8]) / det; o[4] = (m[0] * m[8] - m[2] * m[6]) / det; o[5] = (m[2] * m[3] - m[0] * m[5]) / det;
    o[6] = (m[3] * m[7] - m[4] * m[6]) / det; o[7] = (m[1] * m[6] - m[0] * m[7]) / det; o[8] = (m[0] * m[4] - m[1] * m[3]) / det;
    return 1;
}

/* Draws raster image `handle` onto the quad (x0 y0 = image top-left, x1 y1 top-right, x2 y2 bottom-right, x3 y3
   bottom-left; current user space) with a perspective warp. */
void isim_image_draw_quad(int handle, const double *quad, double alpha) {
    cairo_t *cr = isim_host_cairo();
    cairo_surface_t *src = isim_image_surface(handle);
    if (!cr || !src || !quad || alpha <= 0) return;
    cairo_surface_flush(src);
    int sw = cairo_image_surface_get_width(src), sh = cairo_image_surface_get_height(src), sstride = cairo_image_surface_get_stride(src) / 4;
    if (sw <= 0 || sh <= 0) return;
    const uint32_t *spx = (const uint32_t *)cairo_image_surface_get_data(src);
    /* the quad in device space */
    double d[8];
    for (int i = 0; i < 4; i++) { d[2 * i] = quad[2 * i]; d[2 * i + 1] = quad[2 * i + 1]; cairo_user_to_device(cr, &d[2 * i], &d[2 * i + 1]); }
    double H[9], Hi[9];
    if (!square_to_quad(d, H) || !invert3(H, Hi)) return;
    double bx0 = d[0], by0 = d[1], bx1 = d[0], by1 = d[1];
    for (int i = 1; i < 4; i++) { bx0 = fmin(bx0, d[2 * i]); bx1 = fmax(bx1, d[2 * i]); by0 = fmin(by0, d[2 * i + 1]); by1 = fmax(by1, d[2 * i + 1]); }
    /* limit to the clip (device space) */
    double cx0, cy0, cx1, cy1;
    cairo_save(cr); cairo_identity_matrix(cr); cairo_clip_extents(cr, &cx0, &cy0, &cx1, &cy1); cairo_restore(cr);
    bx0 = fmax(bx0, cx0); by0 = fmax(by0, cy0); bx1 = fmin(bx1, cx1); by1 = fmin(by1, cy1);
    int X0 = (int)floor(bx0), Y0 = (int)floor(by0), X1 = (int)ceil(bx1), Y1 = (int)ceil(by1);
    if (X1 <= X0 || Y1 <= Y0 || (long)(X1 - X0) * (Y1 - Y0) > 40000000L) return;
    int W = X1 - X0, Hh = Y1 - Y0;
    cairo_surface_t *dst = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, W, Hh);
    uint32_t *dpx = (uint32_t *)cairo_image_surface_get_data(dst); int dstride = cairo_image_surface_get_stride(dst) / 4;
    for (int y = 0; y < Hh; y++) {
        double py = Y0 + y + 0.5;
        for (int x = 0; x < W; x++) {
            double px = X0 + x + 0.5;
            double w = Hi[6] * px + Hi[7] * py + Hi[8];
            if (fabs(w) < 1e-12) { dpx[y * dstride + x] = 0; continue; }
            double u = (Hi[0] * px + Hi[1] * py + Hi[2]) / w, v = (Hi[3] * px + Hi[4] * py + Hi[5]) / w;
            if (u < 0 || u > 1 || v < 0 || v > 1) { dpx[y * dstride + x] = 0; continue; }
            /* bilinear in source pixels (premultiplied ARGB) */
            double fx = u * sw - 0.5, fy = v * sh - 0.5;
            int ix = (int)floor(fx), iy = (int)floor(fy); double ax = fx - ix, ay = fy - iy;
            int x0 = ix < 0 ? 0 : ix >= sw ? sw - 1 : ix, x1 = ix + 1 < 0 ? 0 : ix + 1 >= sw ? sw - 1 : ix + 1;
            int y0 = iy < 0 ? 0 : iy >= sh ? sh - 1 : iy, y1 = iy + 1 < 0 ? 0 : iy + 1 >= sh ? sh - 1 : iy + 1;
            uint32_t p00 = spx[y0 * sstride + x0], p10 = spx[y0 * sstride + x1], p01 = spx[y1 * sstride + x0], p11 = spx[y1 * sstride + x1];
            uint32_t o = 0;
            for (int c = 0; c < 32; c += 8) {
                double v00 = (p00 >> c) & 255, v10 = (p10 >> c) & 255, v01 = (p01 >> c) & 255, v11 = (p11 >> c) & 255;
                double val = (v00 * (1 - ax) + v10 * ax) * (1 - ay) + (v01 * (1 - ax) + v11 * ax) * ay;
                o |= (uint32_t)lround(val) << c;
            }
            dpx[y * dstride + x] = o;
        }
    }
    cairo_surface_mark_dirty(dst);
    cairo_save(cr);
    cairo_identity_matrix(cr);
    cairo_set_source_surface(cr, dst, X0, Y0);
    if (alpha >= 0.999) cairo_paint(cr); else cairo_paint_with_alpha(cr, alpha);
    cairo_restore(cr);
    cairo_surface_destroy(dst);
}

/* separable box blur of an A8 buffer */
static void blur_a8(uint8_t *px, int w, int h, int stride, int r, int horizontal) {
    if (r < 1) return;
    int n = horizontal ? w : h, lines = horizontal ? h : w;
    uint8_t *tmp = malloc((size_t)n);
    long win = 2 * r + 1;
    for (int l = 0; l < lines; l++) {
        #define AT(i) (*(horizontal ? &px[(size_t)l * stride + (i)] : &px[(size_t)(i) * stride + l]))
        for (int i = 0; i < n; i++) tmp[i] = AT(i);
        long sum = 0;
        for (int k = -r; k <= r; k++) sum += (k < 0 || k >= n) ? 0 : tmp[k];
        for (int i = 0; i < n; i++) {
            AT(i) = (uint8_t)(sum / win);
            int add = i + r + 1, sub = i - r;
            sum += (add < n ? tmp[add] : 0) - (sub >= 0 ? tmp[sub] : 0);
        }
        #undef AT
    }
    free(tmp);
}

/* Pops the group pushed with isim_gfx_push_group (its alpha is the shadow shape) and paints a shadow of it:
   colour rgba, Gaussian-like blur of `radius` points (CALayer.shadowRadius), offset (dx, dy) in user space. */
void isim_gfx_pop_group_shadow(const double *rgba, double radius, double dx, double dy) {
    cairo_t *cr = isim_host_cairo();
    cairo_pattern_t *pat = cairo_pop_group(cr);
    cairo_surface_t *s = NULL;
    if (cairo_pattern_get_surface(pat, &s) != CAIRO_STATUS_SUCCESS || cairo_surface_get_type(s) != CAIRO_SURFACE_TYPE_IMAGE) { cairo_pattern_destroy(pat); return; }
    cairo_surface_flush(s);
    double ox, oy; cairo_surface_get_device_offset(s, &ox, &oy);
    int sw = cairo_image_surface_get_width(s), sh = cairo_image_surface_get_height(s), ss = cairo_image_surface_get_stride(s) / 4;
    const uint32_t *spx = (const uint32_t *)cairo_image_surface_get_data(s);
    cairo_matrix_t m; cairo_get_matrix(cr, &m);
    double scale = sqrt(fabs(m.xx * m.yy - m.xy * m.yx)); if (scale <= 0) scale = 1;
    double rad = radius * scale;
    int r = (int)lround((sqrt(rad * rad + 1) - 1) / 2);   /* three box passes of width 2r+1 ~ a Gaussian with sigma = radius / 2 */
    int pad = 3 * r + 2;
    /* only the non-empty part of the group */
    int minx = sw, miny = sh, maxx = -1, maxy = -1;
    for (int y = 0; y < sh; y++) for (int x = 0; x < sw; x++) if (spx[y * ss + x] >> 24) { if (x < minx) minx = x; if (x > maxx) maxx = x; if (y < miny) miny = y; if (y > maxy) maxy = y; }
    if (maxx < 0) { cairo_pattern_destroy(pat); return; }
    int W = maxx - minx + 1 + 2 * pad, H = maxy - miny + 1 + 2 * pad;
    cairo_surface_t *a8 = cairo_image_surface_create(CAIRO_FORMAT_A8, W, H);
    uint8_t *apx = cairo_image_surface_get_data(a8); int as = cairo_image_surface_get_stride(a8);
    memset(apx, 0, (size_t)as * H);
    for (int y = miny; y <= maxy; y++) for (int x = minx; x <= maxx; x++) apx[(y - miny + pad) * as + (x - minx + pad)] = spx[y * ss + x] >> 24;
    for (int pass = 0; pass < 3; pass++) { blur_a8(apx, W, H, as, r, 1); blur_a8(apx, W, H, as, r, 0); }
    cairo_surface_mark_dirty(a8);
    double ddx = dx, ddy = dy; cairo_user_to_device_distance(cr, &ddx, &ddy);
    cairo_save(cr);
    cairo_identity_matrix(cr);
    cairo_set_source_rgba(cr, rgba[0], rgba[1], rgba[2], rgba[3]);
    cairo_mask_surface(cr, a8, minx - pad - ox + ddx, miny - pad - oy + ddy);
    cairo_restore(cr);
    cairo_surface_destroy(a8);
    cairo_pattern_destroy(pat);
}

/* A copy of what is on the drawing target under the rect (user space; between frames: the last frame shown),
   as an image handle (CATransition's "before" picture). */
int isim_image_from_surface(cairo_surface_t *src);
int isim_gfx_screen_snapshot(double x, double y, double w, double h) {
    cairo_t *cr = isim_host_cairo();
    if (!cr || w <= 0 || h <= 0) return 0;
    cairo_surface_t *tgt = cairo_get_target(cr);
    if (cairo_surface_get_type(tgt) != CAIRO_SURFACE_TYPE_IMAGE) return 0;
    double x0 = x, y0 = y, x1 = x + w, y1 = y + h;
    cairo_user_to_device(cr, &x0, &y0); cairo_user_to_device(cr, &x1, &y1);
    int W = (int)ceil(fabs(x1 - x0)), H = (int)ceil(fabs(y1 - y0));
    if (W <= 0 || H <= 0 || (long)W * H > 40000000L) return 0;
    cairo_surface_flush(tgt);
    cairo_surface_t *s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, W, H);
    cairo_t *c = cairo_create(s);
    cairo_set_source_surface(c, tgt, -fmin(x0, x1), -fmin(y0, y1));
    cairo_set_operator(c, CAIRO_OPERATOR_SOURCE);
    cairo_paint(c);
    cairo_destroy(c);
    int hd = isim_image_from_surface(s);
    cairo_surface_destroy(s);
    return hd;
}

/* Pops a group and paints it with each pixel multiplied by rgba (CAReplicatorLayer instance colours) and alpha. */
void isim_gfx_pop_group_tinted(const double *rgba, double alpha) {
    cairo_t *cr = isim_host_cairo();
    cairo_pattern_t *pat = cairo_pop_group(cr);
    cairo_surface_t *s = NULL;
    if (cairo_pattern_get_surface(pat, &s) == CAIRO_STATUS_SUCCESS && cairo_surface_get_type(s) == CAIRO_SURFACE_TYPE_IMAGE) {
        cairo_surface_flush(s);
        int w = cairo_image_surface_get_width(s), h = cairo_image_surface_get_height(s), st = cairo_image_surface_get_stride(s) / 4;
        uint32_t *px = (uint32_t *)cairo_image_surface_get_data(s);
        double m[4] = { rgba[2] * rgba[3], rgba[1] * rgba[3], rgba[0] * rgba[3], rgba[3] };   /* B G R A in memory order */
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            uint32_t v = px[y * st + x], o = 0;
            if (!v) continue;
            for (int c = 0; c < 4; c++) { double k = fmin(1, fmax(0, m[c])); o |= (uint32_t)lround(((v >> (8 * c)) & 255) * k) << (8 * c); }
            px[y * st + x] = o;
        }
        cairo_surface_mark_dirty(s);
    }
    cairo_set_source(cr, pat);
    if (alpha >= 0.999) cairo_paint(cr); else cairo_paint_with_alpha(cr, alpha);
    cairo_pattern_destroy(pat);
}
