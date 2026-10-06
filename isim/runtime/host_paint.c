/*
 * libisim_host paint: stroke styles (caps, joins, miter limit, dashes), fill rules and gradients
 * (linear, radial, conic) for the current cairo path. Used by isim's SwiftUI shapes, gradients and
 * Canvas, and by Core Graphics (line dashes/caps/joins, even-odd fill and clip).
 */
#define _GNU_SOURCE
#include <cairo.h>
#include <math.h>
#include <stdlib.h>

cairo_t *isim_host_cairo(void);

/* stroke style of the current graphics state: cap 0 butt, 1 round, 2 square; join 0 miter, 1 round, 2 bevel
   (Core Graphics' enum values); dash lengths in points (ndash 0 = solid) */
void isim_path_set_line_style(int cap, int join, double miter, const double *dash, int ndash, double phase) {
    cairo_t *cr = isim_host_cairo();
    cairo_set_line_cap(cr, cap == 1 ? CAIRO_LINE_CAP_ROUND : cap == 2 ? CAIRO_LINE_CAP_SQUARE : CAIRO_LINE_CAP_BUTT);
    cairo_set_line_join(cr, join == 1 ? CAIRO_LINE_JOIN_ROUND : join == 2 ? CAIRO_LINE_JOIN_BEVEL : CAIRO_LINE_JOIN_MITER);
    cairo_set_miter_limit(cr, miter > 0 ? miter : 10);
    int ok = ndash > 0 && dash;
    for (int i = 0; ok && i < ndash; i++) if (dash[i] < 0) ok = 0;
    double sum = 0; for (int i = 0; ok && i < ndash; i++) sum += dash[i];
    if (ok && sum > 0) cairo_set_dash(cr, dash, ndash, phase); else cairo_set_dash(cr, NULL, 0, 0);
}

/* fill rule for fills and clips of the current graphics state: 0 nonzero winding, 1 even-odd */
void isim_path_set_fill_rule(int even_odd) {
    cairo_set_fill_rule(isim_host_cairo(), even_odd ? CAIRO_FILL_RULE_EVEN_ODD : CAIRO_FILL_RULE_WINDING);
}

static void color_at(int n, const double *locs, const double *rgba, double t, double out[4]) {
    if (n <= 0) { out[0] = out[1] = out[2] = out[3] = 0; return; }
    if (t <= locs[0]) { for (int k = 0; k < 4; k++) out[k] = rgba[k]; return; }
    for (int i = 1; i < n; i++) {
        if (t <= locs[i]) {
            double span = locs[i] - locs[i - 1], f = span > 1e-12 ? (t - locs[i - 1]) / span : 1;
            for (int k = 0; k < 4; k++) out[k] = rgba[4 * (i - 1) + k] + (rgba[4 * i + k] - rgba[4 * (i - 1) + k]) * f;
            return;
        }
    }
    for (int k = 0; k < 4; k++) out[k] = rgba[4 * (n - 1) + k];
}

static int cmp_double(const void *a, const void *b) { double x = *(const double *)a, y = *(const double *)b; return x < y ? -1 : x > y; }

/* a conic sweep as a mesh of thin triangles around the center, reaching `radius` */
static void conic_patch(cairo_pattern_t *mesh, double cx, double cy, double radius, double a0, double a1, const double c0[4], const double c1[4]) {
    cairo_mesh_pattern_begin_patch(mesh);
    cairo_mesh_pattern_move_to(mesh, cx, cy);
    cairo_mesh_pattern_line_to(mesh, cx + radius * cos(a0), cy + radius * sin(a0));
    cairo_mesh_pattern_line_to(mesh, cx + radius * cos(a1), cy + radius * sin(a1));
    cairo_mesh_pattern_set_corner_color_rgba(mesh, 0, c0[0], c0[1], c0[2], c0[3]);
    cairo_mesh_pattern_set_corner_color_rgba(mesh, 1, c0[0], c0[1], c0[2], c0[3]);
    cairo_mesh_pattern_set_corner_color_rgba(mesh, 2, c1[0], c1[1], c1[2], c1[3]);
    cairo_mesh_pattern_set_corner_color_rgba(mesh, 3, c1[0], c1[1], c1[2], c1[3]);
    cairo_mesh_pattern_end_patch(mesh);
}

static cairo_pattern_t *make_conic(cairo_t *cr, const double *geom, int n, const double *locs, const double *rgba, int extend, const cairo_matrix_t *toUser) {
    double cx = geom[0], cy = geom[1], a0 = geom[2], a1 = geom[3];
    if (a1 <= a0) a1 = a0 + 2 * M_PI;
    if (a1 - a0 > 2 * M_PI) a0 = a1 - 2 * M_PI;           /* only the last complete turn is drawn */
    /* radius: reach every corner of what can be drawn (clip and path extents), in pattern space */
    double x0, y0, x1, y1, px0, py0, px1, py1;
    cairo_clip_extents(cr, &x0, &y0, &x1, &y1);
    cairo_path_extents(cr, &px0, &py0, &px1, &py1);
    if (px1 > px0 && py1 > py0) { x0 = fmax(x0, px0 - 64); y0 = fmax(y0, py0 - 64); x1 = fmin(x1, px1 + 64); y1 = fmin(y1, py1 + 64); }
    double xs[4] = { x0, x1, x0, x1 }, ys[4] = { y0, y0, y1, y1 }, radius = 1;
    cairo_matrix_t inv = *toUser;
    if (cairo_matrix_invert(&inv) != CAIRO_STATUS_SUCCESS) cairo_matrix_init_identity(&inv);
    for (int i = 0; i < 4; i++) {
        double x = xs[i], y = ys[i];
        cairo_matrix_transform_point(&inv, &x, &y);
        radius = fmax(radius, hypot(x - cx, y - cy));
    }
    radius = radius * 1.02 + 2;
    cairo_pattern_t *mesh = cairo_pattern_create_mesh();
    /* breakpoints: about one per degree plus every stop location */
    int steps = (int)ceil((a1 - a0) / (M_PI / 180)); if (steps < 4) steps = 4;
    double *ts = malloc(sizeof *ts * (size_t)(steps + 1 + n));
    int m = 0;
    for (int i = 0; i <= steps; i++) ts[m++] = (double)i / steps;
    for (int i = 0; i < n; i++) if (locs[i] > 0 && locs[i] < 1) ts[m++] = locs[i];
    qsort(ts, (size_t)m, sizeof *ts, cmp_double);
    for (int i = 0; i + 1 < m; i++) {
        double t0 = ts[i], t1 = ts[i + 1];
        if (t1 - t0 < 1e-9) continue;
        double c0[4], c1[4];
        color_at(n, locs, rgba, t0 + 1e-9, c0); color_at(n, locs, rgba, t1 - 1e-9, c1);
        conic_patch(mesh, cx, cy, radius, a0 + (a1 - a0) * t0, a0 + (a1 - a0) * t1, c0, c1);
    }
    free(ts);
    double gap = a0 + 2 * M_PI - a1;
    if (extend && gap > 1e-6) {                            /* the missing sector: last color, then first color halfway */
        double cl[4], cf[4];
        color_at(n, locs, rgba, 1, cl); color_at(n, locs, rgba, 0, cf);
        int k = (int)ceil(gap / (M_PI / 8));
        for (int i = 0; i < k; i++) {
            double s0 = a1 + gap * i / k, s1 = a1 + gap * (i + 1) / k, mid = a1 + gap / 2;
            if (s1 <= mid) conic_patch(mesh, cx, cy, radius, s0, s1, cl, cl);
            else if (s0 >= mid) conic_patch(mesh, cx, cy, radius, s0, s1, cf, cf);
            else { conic_patch(mesh, cx, cy, radius, s0, mid, cl, cl); conic_patch(mesh, cx, cy, radius, mid, s1, cf, cf); }
        }
    }
    return mesh;
}

/* Paints the current path (kept) with a gradient: mode 0 fill, 1 stroke (line width lw), 2 paint the clip area.
   kind 0 linear (geom x0 y0 x1 y1), 1 radial (cx0 cy0 r0 cx1 cy1 r1), 2 conic (cx cy startAngle endAngle; radians,
   y-down, so increasing angles turn clockwise on screen). n stops: locations locs[n] (ascending, 0...1) and
   rgba[4n] (straight alpha). extend: 0 none, 1 pad, 2 repeat, 3 reflect. matrix: optional [a b c d tx ty] mapping
   gradient space to user space (elliptical gradients). */
void isim_path_gradient(int mode, int kind, const double *geom, int n, const double *locs, const double *rgba, int extend, double lw, const double *matrix) {
    cairo_t *cr = isim_host_cairo();
    if (n <= 0 || !geom || !locs || !rgba) return;
    cairo_matrix_t toUser;
    if (matrix) cairo_matrix_init(&toUser, matrix[0], matrix[1], matrix[2], matrix[3], matrix[4], matrix[5]);
    else cairo_matrix_init_identity(&toUser);
    cairo_pattern_t *p;
    if (kind == 2) p = make_conic(cr, geom, n, locs, rgba, extend, &toUser);
    else {
        p = kind == 1 ? cairo_pattern_create_radial(geom[0], geom[1], fmax(0, geom[2]), geom[3], geom[4], fmax(0, geom[5]))
                      : cairo_pattern_create_linear(geom[0], geom[1], geom[2], geom[3]);
        for (int i = 0; i < n; i++)
            cairo_pattern_add_color_stop_rgba(p, fmin(1, fmax(0, locs[i])), rgba[4 * i], rgba[4 * i + 1], rgba[4 * i + 2], rgba[4 * i + 3]);
        cairo_pattern_set_extend(p, extend == 1 ? CAIRO_EXTEND_PAD : extend == 2 ? CAIRO_EXTEND_REPEAT : extend == 3 ? CAIRO_EXTEND_REFLECT : CAIRO_EXTEND_NONE);
    }
    if (matrix) {
        cairo_matrix_t inv = toUser;
        if (cairo_matrix_invert(&inv) == CAIRO_STATUS_SUCCESS) cairo_pattern_set_matrix(p, &inv);
    }
    cairo_save(cr);
    cairo_set_source(cr, p);
    if (mode == 1) { cairo_set_line_width(cr, lw); cairo_stroke_preserve(cr); }
    else if (mode == 2) cairo_paint(cr);
    else cairo_fill_preserve(cr);
    cairo_restore(cr);
    cairo_pattern_destroy(p);
}
