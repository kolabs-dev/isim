/* isim CoreGraphics: gradients (stops in sRGB), functions, shadings (sampled into gradients) and patterns (the cell
 * is drawn once into a bitmap context and tiled by the host). */
#include "cg_context.h"

CFTypeID CGGradientGetTypeID(void) { return 0x4367; }
static void gradient_fin(void *o) { struct CGGradient *g = o; free(g->locs); free(g->rgba); }
static struct CGGradient *gradient_new(size_t n) {
    struct CGGradient *g = isim_cg_obj_new("CGGradient", sizeof *g, gradient_fin);
    g->n = (int)n; g->locs = calloc(n ? n : 1, sizeof(double)); g->rgba = calloc(n ? 4 * n : 4, sizeof(double));
    return g;
}
static void sort_stops(struct CGGradient *g) {
    for (int i = 1; i < g->n; i++)
        for (int j = i; j > 0 && g->locs[j] < g->locs[j - 1]; j--) {
            double t = g->locs[j]; g->locs[j] = g->locs[j - 1]; g->locs[j - 1] = t;
            for (int k = 0; k < 4; k++) { t = g->rgba[4 * j + k]; g->rgba[4 * j + k] = g->rgba[4 * (j - 1) + k]; g->rgba[4 * (j - 1) + k] = t; }
        }
}
CGGradientRef CGGradientCreateWithColorComponents(CGColorSpaceRef space, const CGFloat *comps, const CGFloat *locs, size_t n) {
    if (!comps || !n) return NULL;
    size_t nc = (space ? space->ncomp : 3) + 1;
    struct CGGradient *g = gradient_new(n);
    for (size_t i = 0; i < n; i++) {
        CGFloat o[4]; isim_cg_to_rgba(space, comps + i * nc, o);
        for (int k = 0; k < 4; k++) g->rgba[4 * i + k] = o[k];
        g->locs[i] = locs ? locs[i] : n > 1 ? (double)i / (double)(n - 1) : 0;
    }
    sort_stops(g);
    return g;
}
CGGradientRef CGGradientCreateWithColors(CGColorSpaceRef space, CFArrayRef colors, const CGFloat *locs) {
    CFIndex n = colors ? CFArrayGetCount(colors) : 0;
    if (n < 1) return NULL;
    struct CGGradient *g = gradient_new((size_t)n);
    for (CFIndex i = 0; i < n; i++) {
        CGColorRef c = (CGColorRef)CFArrayGetValueAtIndex(colors, i);
        double v[4]; isim_cg_color_rgba(c, v);
        for (int k = 0; k < 4; k++) g->rgba[4 * i + k] = v[k];
        g->locs[i] = locs ? locs[i] : n > 1 ? (double)i / (double)(n - 1) : 0;
    }
    sort_stops(g);
    return g;
}
CGGradientRef CGGradientRetain(CGGradientRef g) { return g ? objc_retain(g) : NULL; }
void CGGradientRelease(CGGradientRef g) { if (g) objc_release(g); }

CFTypeID CGFunctionGetTypeID(void) { return 0x4368; }
static void function_fin(void *o) { struct CGFunction *f = o; if (f->cb.releaseInfo) f->cb.releaseInfo(f->info); }
CGFunctionRef CGFunctionCreate(void *info, size_t din, const CGFloat *domain, size_t dout, const CGFloat *range, const CGFunctionCallbacks *cb) {
    if (!cb || din != 1) return NULL;
    struct CGFunction *f = isim_cg_obj_new("CGFunction", sizeof *f, function_fin);
    f->info = info; f->din = din; f->dout = dout > 8 ? 8 : dout; f->cb = *cb;
    f->domain[0] = domain ? domain[0] : 0; f->domain[1] = domain ? domain[1] : 1;
    for (size_t i = 0; range && i < 2 * f->dout && i < 16; i++) f->range[i] = range[i];
    return f;
}
CGFunctionRef CGFunctionRetain(CGFunctionRef f) { return f ? objc_retain(f) : NULL; }
void CGFunctionRelease(CGFunctionRef f) { if (f) objc_release(f); }

CFTypeID CGShadingGetTypeID(void) { return 0x436a; }
static void shading_fin(void *o) { struct CGShading *s = o; if (s->fn) objc_release(s->fn); if (s->cs) objc_release(s->cs); }
static CGShadingRef shading(CGColorSpaceRef cs, int radial, CGPoint p0, CGFloat r0, CGPoint p1, CGFloat r1, CGFunctionRef fn, bool e0, bool e1) {
    if (!fn) return NULL;
    struct CGShading *s = isim_cg_obj_new("CGShading", sizeof *s, shading_fin);
    s->radial = radial; s->p0 = p0; s->p1 = p1; s->r0 = r0; s->r1 = r1; s->fn = objc_retain(fn); s->e0 = e0; s->e1 = e1;
    s->cs = cs ? objc_retain(cs) : objc_retain(isim_cg_space(CS_SRGB));
    return s;
}
CGShadingRef CGShadingCreateAxial(CGColorSpaceRef cs, CGPoint s, CGPoint e, CGFunctionRef fn, bool e0, bool e1) { return shading(cs, 0, s, 0, e, 0, fn, e0, e1); }
CGShadingRef CGShadingCreateRadial(CGColorSpaceRef cs, CGPoint s, CGFloat r0, CGPoint e, CGFloat r1, CGFunctionRef fn, bool e0, bool e1) { return shading(cs, 1, s, r0, e, r1, fn, e0, e1); }
CGShadingRef CGShadingRetain(CGShadingRef s) { return s ? objc_retain(s) : NULL; }
void CGShadingRelease(CGShadingRef s) { if (s) objc_release(s); }

CFTypeID CGPatternGetTypeID(void) { return 0x436b; }
static void pattern_fin(void *o) {
    struct CGPattern *p = o;
    if (p->cell) isim_image_free(p->cell);
    if (p->cb.releaseInfo) p->cb.releaseInfo(p->info);
}
CGPatternRef CGPatternCreate(void *info, CGRect bounds, CGAffineTransform m, CGFloat xs, CGFloat ys, CGPatternTiling t, bool colored, const CGPatternCallbacks *cb) {
    if (!cb || !cb->drawPattern) return NULL;
    struct CGPattern *p = isim_cg_obj_new("CGPattern", sizeof *p, pattern_fin);
    p->info = info; p->bounds = bounds; p->matrix = m; p->xstep = xs; p->ystep = ys; p->tiling = t; p->colored = colored; p->cb = *cb;
    return p;
}
CGPatternRef CGPatternRetain(CGPatternRef p) { return p ? objc_retain(p) : NULL; }
void CGPatternRelease(CGPatternRef p) { if (p) objc_release(p); }
/* renders the cell (xStep x yStep, 2x resolution) once; uncolored patterns are rendered per color */
int isim_cg_pattern_cell(CGPatternRef p, const CGFloat *comps, double *cw, double *ch) {
    if (!p) return 0;
    double w = fabs(p->xstep), h = fabs(p->ystep);
    if (w <= 0) w = p->bounds.size.width;
    if (h <= 0) h = p->bounds.size.height;
    if (w <= 0 || h <= 0) return 0;
    *cw = w; *ch = h;
    if (p->cell && p->colored) return p->cell;
    if (p->cell) { isim_image_free(p->cell); p->cell = 0; }
    int k = 2, pw = (int)ceil(w * k), ph = (int)ceil(h * k);
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(NULL, (size_t)pw, (size_t)ph, 8, 0, rgb, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(rgb);
    if (!c) return 0;
    CGContextScaleCTM(c, k, k);
    CGContextTranslateCTM(c, -p->bounds.origin.x, -p->bounds.origin.y);
    if (!p->colored && comps) { CGContextSetRGBFillColor(c, comps[0], comps[1], comps[2], comps[3] ? comps[3] : 1); CGContextSetRGBStrokeColor(c, comps[0], comps[1], comps[2], comps[3] ? comps[3] : 1); }
    p->cb.drawPattern(p->info, c);
    struct CGContext *x = c;
    p->cell = isim_cg_target_image(x->target);
    objc_release(c);
    return p->cell;
}
