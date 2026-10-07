/* isim CoreGraphics: CGContext drawing. Every context draws through the host's cairo: UIKit's current context
 * (the screen or an offscreen image; one shared object), bitmap contexts over app memory and PDF contexts (their
 * host targets are bound for the duration of each call). Shadows and clip masks composite each drawing operation
 * as a group; blend modes map to cairo operators; transparency layers are groups. */
#include "cg_context.h"
#include <stdio.h>

void isim_cg_gstate_reset(struct gstate *g) {
    memset(g, 0, sizeof *g);
    g->fill[3] = g->stroke[3] = 1; g->lw = 1; g->alpha = 1; g->miter = 10; g->fontSize = 12;
    g->fillSpace = g->strokeSpace = isim_cg_space(CS_SRGB);
}
static void ctx_fin(void *o);
struct CGContext *isim_cg_ctx_new(int kind) {
    static Class k; static size_t base;
    if (!k) { k = objc_getClass("__NSCGContext"); base = k ? class_getInstanceSize(k) : 0; }
    struct CGContext *x = k ? class_createInstance(k, sizeof *x > base ? sizeof *x - base : 0) : calloc(1, sizeof *x);
    memset((char *)x + sizeof(void *), 0, sizeof *x - sizeof(void *));
    x->kind = kind; x->fin = kind == CTX_UIKIT ? NULL : ctx_fin;
    isim_cg_gstate_reset(&x->gs[0]);
    x->textMatrix = CGAffineTransformIdentity;
    return x;
}
static void gstate_retain(struct gstate *g) {
    if (g->mask) objc_retain(g->mask);
    if (g->fillPat) objc_retain(g->fillPat);
    if (g->strokePat) objc_retain(g->strokePat);
    if (g->font) objc_retain(g->font);
}
static void gstate_release(struct gstate *g) {
    if (g->mask) objc_release(g->mask);
    if (g->fillPat) objc_release(g->fillPat);
    if (g->strokePat) objc_release(g->strokePat);
    if (g->font) objc_release(g->font);
    g->mask = NULL; g->fillPat = g->strokePat = NULL; g->font = NULL;
}
static void ctx_fin(void *o) {
    struct CGContext *x = o;
    for (int i = x->depth; i >= 0; i--) gstate_release(&x->gs[i]);
    if (x->kind == CTX_PDF && x->target) { unsigned char *b = NULL; isim_cg_pdf_finish(x->target, &b); free(b); }
    isim_cg_target_free(x->target);
    if (x->owns) free(x->data);
    if (x->releaseCb) x->releaseCb(x->releaseInfo, x->data);
    if (x->cs) objc_release(x->cs);
    if (x->consumer) objc_release(x->consumer);
}

/* ---- UIKit's current context (the screen / offscreen images) and UIGraphicsPushContext ---- */
static struct CGContext *screen_ctx(void) {
    static struct CGContext *s;
    if (!s) s = isim_cg_ctx_new(CTX_UIKIT);
    return s;
}
static struct CGContext *pushed[32]; static int npushed;
CGContextRef isim_cg_current_context(void) { return npushed ? pushed[npushed - 1] : screen_ctx(); }
void isim_cg_push_current(CGContextRef c) {
    if (!c || npushed >= 32) return;
    pushed[npushed++] = objc_retain(c);
    if (c->target) isim_cg_target_bind(c->target);
}
void isim_cg_pop_current(void) {
    if (!npushed) return;
    struct CGContext *c = pushed[--npushed];
    if (c->target) isim_cg_target_unbind(c->target);
    objc_release(c);
}

/* ---- per-call binding of the context's host target ---- */
static inline struct CGContext *enter(CGContextRef c) {
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    if (x->target) isim_cg_target_bind(x->target);
    return x;
}
static inline void leave(struct CGContext *x) { if (x->target) isim_cg_target_unbind(x->target); }
#define G(x) (&(x)->gs[(x)->depth])
static const double *with_alpha(struct CGContext *x, const CGFloat *c, double out[4]) {
    out[0] = c[0]; out[1] = c[1]; out[2] = c[2]; out[3] = c[3] * G(x)->alpha; return out;
}
/* shadows and clip masks: the operation is drawn into a group, then composited */
static int fx_begin(struct CGContext *x) {
    struct gstate *g = G(x);
    if ((g->shadow && g->scolor[3] > 0) || g->mask) { isim_cg_group_begin(); return 1; }
    return 0;
}
static void fx_fill(struct CGContext *x, struct isim_cg_fx *fx) {
    struct gstate *g = G(x);
    memset(fx, 0, sizeof *fx); fx->alpha = 1;
    if (g->shadow && g->scolor[3] > 0) {
        fx->shadow = 1; fx->flip = x->kind != CTX_UIKIT; fx->sdx = g->soff.width; fx->sdy = g->soff.height; fx->sblur = g->sblur;
        for (int i = 0; i < 4; i++) fx->srgba[i] = g->scolor[i];
        fx->srgba[3] *= g->alpha;
    }
    if (g->mask) {
        CGRect pr; fx->mask_handle = isim_cg_image_handle(g->mask, &pr);
        fx->msx = pr.origin.x; fx->msy = pr.origin.y; fx->msw = pr.size.width; fx->msh = pr.size.height;
        memcpy(fx->mm, g->mm, sizeof fx->mm);
        fx->mx = g->mrect.origin.x; fx->my = g->mrect.origin.y; fx->mw = g->mrect.size.width; fx->mh = g->mrect.size.height;
        struct imgext *e = g->mask->ext;
        fx->mask_luminance = e && e->mask ? 0 : e && (e->info & kCGBitmapAlphaInfoMask) != kCGImageAlphaOnly
                             && ((e->info & kCGBitmapAlphaInfoMask) == kCGImageAlphaNone || (e->info & kCGBitmapAlphaInfoMask) >= kCGImageAlphaNoneSkipLast) ? 1 : 2;
    }
}
static void fx_end(struct CGContext *x, int on) {
    if (!on) return;
    struct isim_cg_fx fx; fx_fill(x, &fx);
    isim_cg_group_end(&fx);
}

CFTypeID CGContextGetTypeID(void) { return 0x4378; }
CGContextRef CGContextRetain(CGContextRef c) { return c ? objc_retain(c) : NULL; }
void CGContextRelease(CGContextRef c) { if (c) objc_release(c); }
void CGContextFlush(CGContextRef c) { struct CGContext *x = enter(c); leave(x); }
void CGContextSynchronize(CGContextRef c) { CGContextFlush(c); }

void CGContextSaveGState(CGContextRef c) {
    struct CGContext *x = enter(c);
    if (x->depth < 31) { x->gs[x->depth + 1] = x->gs[x->depth]; x->depth++; G(x)->layer = 0; gstate_retain(G(x)); }
    isim_gfx_save();
    leave(x);
}
void CGContextRestoreGState(CGContextRef c) {
    struct CGContext *x = enter(c);
    if (x->depth > 0) { gstate_release(G(x)); x->depth--; }
    isim_gfx_restore();
    leave(x);
}
void CGContextTranslateCTM(CGContextRef c, CGFloat tx, CGFloat ty) { struct CGContext *x = enter(c); isim_gfx_translate(tx, ty); leave(x); }
void CGContextScaleCTM(CGContextRef c, CGFloat sx, CGFloat sy) { struct CGContext *x = enter(c); isim_gfx_scale(sx, sy); leave(x); }
void CGContextRotateCTM(CGContextRef c, CGFloat a) { struct CGContext *x = enter(c); isim_gfx_rotate(a); leave(x); }
void CGContextConcatCTM(CGContextRef c, CGAffineTransform t) { struct CGContext *x = enter(c); isim_gfx_concat(t.a, t.b, t.c, t.d, t.tx, t.ty); leave(x); }
CGAffineTransform CGContextGetCTM(CGContextRef c) {
    struct CGContext *x = enter(c);
    double m[7]; isim_cg_get_ctm(m);
    leave(x);
    return CGAffineTransformMake(m[0], -m[1], m[2], -m[3], m[4], m[6] - m[5]);
}
CGAffineTransform CGContextGetUserSpaceToDeviceSpaceTransform(CGContextRef c) { return CGContextGetCTM(c); }
CGPoint CGContextConvertPointToDeviceSpace(CGContextRef c, CGPoint p) { return CGPointApplyAffineTransform(p, CGContextGetCTM(c)); }
CGPoint CGContextConvertPointToUserSpace(CGContextRef c, CGPoint p) { return CGPointApplyAffineTransform(p, CGAffineTransformInvert(CGContextGetCTM(c))); }
CGRect CGContextConvertRectToDeviceSpace(CGContextRef c, CGRect r) { return CGRectApplyAffineTransform(r, CGContextGetCTM(c)); }
CGRect CGContextConvertRectToUserSpace(CGContextRef c, CGRect r) { return CGRectApplyAffineTransform(r, CGAffineTransformInvert(CGContextGetCTM(c))); }

/* ---- colors ---- */
static void set_rgba(CGFloat dst[4], CGFloat r, CGFloat g, CGFloat b, CGFloat a) { dst[0] = r; dst[1] = g; dst[2] = b; dst[3] = a; }
static void clear_pat(CGPatternRef *p) { if (*p) objc_release(*p); *p = NULL; }
void CGContextSetRGBFillColor(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); set_rgba(G(x)->fill, r, g, b, a); clear_pat(&G(x)->fillPat); }
void CGContextSetRGBStrokeColor(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); set_rgba(G(x)->stroke, r, g, b, a); clear_pat(&G(x)->strokePat); }
void CGContextSetGrayFillColor(CGContextRef c, CGFloat w, CGFloat a) { CGContextSetRGBFillColor(c, w, w, w, a); }
void CGContextSetGrayStrokeColor(CGContextRef c, CGFloat w, CGFloat a) { CGContextSetRGBStrokeColor(c, w, w, w, a); }
void CGContextSetCMYKFillColor(CGContextRef c, CGFloat cy, CGFloat m, CGFloat y, CGFloat k, CGFloat a) { CGFloat v[5] = { cy, m, y, k, a }, o[4]; isim_cg_to_rgba(isim_cg_space(CS_CMYK), v, o); CGContextSetRGBFillColor(c, o[0], o[1], o[2], o[3]); }
void CGContextSetCMYKStrokeColor(CGContextRef c, CGFloat cy, CGFloat m, CGFloat y, CGFloat k, CGFloat a) { CGFloat v[5] = { cy, m, y, k, a }, o[4]; isim_cg_to_rgba(isim_cg_space(CS_CMYK), v, o); CGContextSetRGBStrokeColor(c, o[0], o[1], o[2], o[3]); }
static void set_color(CGContextRef c, CGColorRef col, int stroke) {
    if (!col) return;
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    struct gstate *g = G(x);
    if (col->pattern) {
        CGPatternRef *p = stroke ? &g->strokePat : &g->fillPat;
        clear_pat(p); *p = objc_retain(col->pattern);
        memcpy(stroke ? g->strokePatComps : g->fillPatComps, col->comp, sizeof col->comp);
        memcpy(stroke ? g->stroke : g->fill, col->c, sizeof col->c);
        return;
    }
    memcpy(stroke ? g->stroke : g->fill, col->c, sizeof col->c);
    clear_pat(stroke ? &g->strokePat : &g->fillPat);
}
void CGContextSetFillColorWithColor(CGContextRef c, CGColorRef col) { set_color(c, col, 0); }
void CGContextSetStrokeColorWithColor(CGContextRef c, CGColorRef col) { set_color(c, col, 1); }
void CGContextSetFillColorSpace(CGContextRef c, CGColorSpaceRef s) {
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    G(x)->fillSpace = s ? s : isim_cg_space(CS_SRGB);
    CGFloat z[5] = { 0, 0, 0, 0, 1 }; if (s && s->ncomp < 4) z[s->ncomp] = 1;
    if (s && s->model != kCGColorSpaceModelPattern) { CGFloat o[4]; isim_cg_to_rgba(s, z, o); memcpy(G(x)->fill, o, sizeof o); }
}
void CGContextSetStrokeColorSpace(CGContextRef c, CGColorSpaceRef s) {
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    G(x)->strokeSpace = s ? s : isim_cg_space(CS_SRGB);
    CGFloat z[5] = { 0, 0, 0, 0, 1 }; if (s && s->ncomp < 4) z[s->ncomp] = 1;
    if (s && s->model != kCGColorSpaceModelPattern) { CGFloat o[4]; isim_cg_to_rgba(s, z, o); memcpy(G(x)->stroke, o, sizeof o); }
}
void CGContextSetFillColor(CGContextRef c, const CGFloat *comps) {
    if (!comps) return;
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    CGFloat o[4]; isim_cg_to_rgba(G(x)->fillSpace, comps, o); memcpy(G(x)->fill, o, sizeof o); clear_pat(&G(x)->fillPat);
}
void CGContextSetStrokeColor(CGContextRef c, const CGFloat *comps) {
    if (!comps) return;
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    CGFloat o[4]; isim_cg_to_rgba(G(x)->strokeSpace, comps, o); memcpy(G(x)->stroke, o, sizeof o); clear_pat(&G(x)->strokePat);
}
void CGContextSetFillPattern(CGContextRef c, CGPatternRef p, const CGFloat *comps) {
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    clear_pat(&G(x)->fillPat); if (p) G(x)->fillPat = objc_retain(p);
    memset(G(x)->fillPatComps, 0, sizeof G(x)->fillPatComps);
    if (comps) for (int i = 0; i < 4; i++) G(x)->fillPatComps[i] = comps[i];
}
void CGContextSetStrokePattern(CGContextRef c, CGPatternRef p, const CGFloat *comps) {
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    clear_pat(&G(x)->strokePat); if (p) G(x)->strokePat = objc_retain(p);
    memset(G(x)->strokePatComps, 0, sizeof G(x)->strokePatComps);
    if (comps) for (int i = 0; i < 4; i++) G(x)->strokePatComps[i] = comps[i];
}
void CGContextSetPatternPhase(CGContextRef c, CGSize phase) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); x->patternPhase = phase; }
void isim_cg_context_fill_rgba(CGContextRef c, double *rgba) {
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    with_alpha(x, G(x)->fill, rgba);
}

/* ---- state ---- */
void CGContextSetLineWidth(CGContextRef c, CGFloat w) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); G(x)->lw = w; }
void CGContextSetAlpha(CGContextRef c, CGFloat alpha) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); G(x)->alpha = alpha < 0 ? 0 : alpha > 1 ? 1 : alpha; }
void CGContextSetInterpolationQuality(CGContextRef c, CGInterpolationQuality q) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); G(x)->interp = q; }
CGInterpolationQuality CGContextGetInterpolationQuality(CGContextRef c) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); return G(x)->interp; }
/* line caps, joins, miter limit and dashes live in the host's graphics state (saved/restored with it) */
static void line_style(struct CGContext *x) { struct gstate *g = G(x); isim_path_set_line_style(g->cap, g->join, g->miter, g->ndash ? g->dash : NULL, g->ndash, g->phase); }
void CGContextSetLineCap(CGContextRef c, CGLineCap cap) { struct CGContext *x = enter(c); G(x)->cap = cap; line_style(x); leave(x); }
void CGContextSetLineJoin(CGContextRef c, CGLineJoin join) { struct CGContext *x = enter(c); G(x)->join = join; line_style(x); leave(x); }
void CGContextSetMiterLimit(CGContextRef c, CGFloat limit) { struct CGContext *x = enter(c); G(x)->miter = limit; line_style(x); leave(x); }
void CGContextSetLineDash(CGContextRef c, CGFloat phase, const CGFloat *lengths, size_t count) {
    struct CGContext *x = enter(c);
    struct gstate *g = G(x);
    g->ndash = lengths ? (int)(count < 16 ? count : 16) : 0;
    for (int i = 0; i < g->ndash; i++) g->dash[i] = lengths[i];
    g->phase = phase;
    line_style(x);
    leave(x);
}
void CGContextSetFlatness(CGContextRef c, CGFloat f) {}
void CGContextSetRenderingIntent(CGContextRef c, CGColorRenderingIntent i) {}
void CGContextSetShouldAntialias(CGContextRef c, bool on) { struct CGContext *x = enter(c); double o[1]; isim_cg_query(5, on ? 1 : 0, 0, o); leave(x); }
void CGContextSetAllowsAntialiasing(CGContextRef c, bool on) { if (!on) CGContextSetShouldAntialias(c, false); }
void CGContextSetShadowWithColor(CGContextRef c, CGSize off, CGFloat blur, CGColorRef col) {
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    struct gstate *g = G(x);
    g->shadow = col != NULL && col->c[3] > 0; g->soff = off; g->sblur = blur < 0 ? 0 : blur;
    if (col) memcpy(g->scolor, col->c, sizeof g->scolor);
}
void CGContextSetShadow(CGContextRef c, CGSize off, CGFloat blur) {
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    struct gstate *g = G(x);
    g->shadow = 1; g->soff = off; g->sblur = blur < 0 ? 0 : blur; set_rgba(g->scolor, 0, 0, 0, 1.0 / 3);   /* Core Graphics' default shadow color */
}
void CGContextSetBlendMode(CGContextRef c, CGBlendMode mode) { struct CGContext *x = enter(c); G(x)->blend = mode; isim_cg_set_blend(mode); leave(x); }
void CGContextBeginTransparencyLayer(CGContextRef c, CFDictionaryRef aux) {
    struct CGContext *x = enter(c);
    CGContextSaveGState(x);
    G(x)->layer = 1;
    isim_cg_group_begin();
    /* inside the layer: opaque, no shadow, no mask, normal blending; they apply when the layer is composited */
    struct gstate *g = G(x);
    g->alpha = 1; g->shadow = 0; if (g->mask) { objc_release(g->mask); g->mask = NULL; }
    leave(x);
}
void CGContextBeginTransparencyLayerWithRect(CGContextRef c, CGRect r, CFDictionaryRef aux) { CGContextBeginTransparencyLayer(c, aux); }
void CGContextEndTransparencyLayer(CGContextRef c) {
    struct CGContext *x = enter(c);
    if (x->depth > 0 && G(x)->layer) {
        x->depth--;                                   /* the outer state's alpha / shadow / mask composite the layer */
        struct isim_cg_fx fx; fx_fill(x, &fx); fx.alpha = G(x)->alpha;
        x->depth++;
        isim_cg_group_end(&fx);
        CGContextRestoreGState(x);
    }
    leave(x);
}

/* ---- paths ---- */
void CGContextBeginPath(CGContextRef c) { struct CGContext *x = enter(c); isim_path_begin(); leave(x); }
void CGContextMoveToPoint(CGContextRef c, CGFloat px, CGFloat py) { struct CGContext *x = enter(c); isim_path_move(px, py); leave(x); }
void CGContextAddLineToPoint(CGContextRef c, CGFloat px, CGFloat py) { struct CGContext *x = enter(c); isim_path_line(px, py); leave(x); }
void CGContextAddRect(CGContextRef c, CGRect r) { struct CGContext *x = enter(c); isim_path_rect(r.origin.x, r.origin.y, r.size.width, r.size.height, 0); leave(x); }
void CGContextAddRects(CGContextRef c, const CGRect *r, size_t n) { for (size_t i = 0; r && i < n; i++) CGContextAddRect(c, r[i]); }
/* CG uses a flipped-y "clockwise" flag; in UIKit's top-left coordinates clockwise=1 draws counter-clockwise visually */
void CGContextAddArc(CGContextRef c, CGFloat cx, CGFloat cy, CGFloat r, CGFloat a0, CGFloat a1, int clockwise) { struct CGContext *x = enter(c); isim_path_arc(cx, cy, r, a0, a1, !clockwise); leave(x); }
static CGPoint current_point(void) { double o[2]; isim_cg_query(1, 0, 0, o); return CGPointMake(o[0], o[1]); }
void CGContextAddArcToPoint(CGContextRef c, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat r) {
    struct CGContext *x = enter(c);
    CGPoint p0 = current_point();
    double v1x = p0.x - x1, v1y = p0.y - y1, v2x = x2 - x1, v2y = y2 - y1;
    double l1 = hypot(v1x, v1y), l2 = hypot(v2x, v2y);
    if (l1 < 1e-9 || l2 < 1e-9 || r <= 0) { isim_path_line(x1, y1); leave(x); return; }
    v1x /= l1; v1y /= l1; v2x /= l2; v2y /= l2;
    double cosang = v1x * v2x + v1y * v2y, ang = acos(fmax(-1, fmin(1, cosang)));
    if (fabs(sin(ang)) < 1e-9) { isim_path_line(x1, y1); leave(x); return; }
    double t = r / tan(ang / 2);
    double sx = x1 + v1x * t, sy = y1 + v1y * t, ex = x1 + v2x * t, ey = y1 + v2y * t;
    double bx = v1x + v2x, by = v1y + v2y, bl = hypot(bx, by), d = r / sin(ang / 2);
    double cx = x1 + bx / bl * d, cy = y1 + by / bl * d;
    double a0 = atan2(sy - cy, sx - cx), a1 = atan2(ey - cy, ex - cx);
    double cross = v1x * v2y - v1y * v2x;
    isim_path_line(sx, sy);
    isim_path_arc(cx, cy, r, a0, a1, cross < 0);
    leave(x);
}
void CGContextClosePath(CGContextRef c) { struct CGContext *x = enter(c); isim_path_close(); leave(x); }
void CGContextAddLines(CGContextRef c, const CGPoint *p, size_t n) {
    struct CGContext *x = enter(c);
    for (size_t i = 0; i < n; i++) { if (i == 0) isim_path_move(p[i].x, p[i].y); else isim_path_line(p[i].x, p[i].y); }
    leave(x);
}
void CGContextAddEllipseInRect(CGContextRef c, CGRect r) {
    struct CGContext *x = enter(c);
    double k = 0.5522847498, cx = CGRectGetMidX(r), cy = CGRectGetMidY(r), rx = r.size.width / 2, ry = r.size.height / 2;
    isim_path_move(cx + rx, cy);
    isim_path_curve(cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry);
    isim_path_curve(cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy);
    isim_path_curve(cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry);
    isim_path_curve(cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy);
    isim_path_close();
    leave(x);
}
void CGContextAddCurveToPoint(CGContextRef c, CGFloat a, CGFloat b, CGFloat d, CGFloat e, CGFloat px, CGFloat py) { struct CGContext *x = enter(c); isim_path_curve(a, b, d, e, px, py); leave(x); }
void CGContextAddQuadCurveToPoint(CGContextRef c, CGFloat cpx, CGFloat cpy, CGFloat px, CGFloat py) {
    struct CGContext *x = enter(c);
    CGPoint p0 = current_point();
    isim_path_curve(p0.x + 2.0 / 3 * (cpx - p0.x), p0.y + 2.0 / 3 * (cpy - p0.y), px + 2.0 / 3 * (cpx - px), py + 2.0 / 3 * (cpy - py), px, py);
    leave(x);
}
void CGContextAddPath(CGContextRef c, CGPathRef p) {
    if (!p) return;
    struct CGContext *x = enter(c);
    CGPoint start = CGPointZero, last = CGPointZero;
    for (long i = 0; i < p->count; i++) {
        struct pel e = p->els[i];
        switch (e.type) {
        case kCGPathElementMoveToPoint: isim_path_move(e.p[0].x, e.p[0].y); start = last = e.p[0]; break;
        case kCGPathElementAddLineToPoint: isim_path_line(e.p[0].x, e.p[0].y); last = e.p[0]; break;
        case kCGPathElementAddQuadCurveToPoint:
            isim_path_curve(last.x + 2.0 / 3 * (e.p[0].x - last.x), last.y + 2.0 / 3 * (e.p[0].y - last.y),
                            e.p[1].x + 2.0 / 3 * (e.p[0].x - e.p[1].x), e.p[1].y + 2.0 / 3 * (e.p[0].y - e.p[1].y), e.p[1].x, e.p[1].y);
            last = e.p[1]; break;
        case kCGPathElementAddCurveToPoint: isim_path_curve(e.p[0].x, e.p[0].y, e.p[1].x, e.p[1].y, e.p[2].x, e.p[2].y); last = e.p[2]; break;
        case kCGPathElementCloseSubpath: isim_path_close(); last = start; break;
        }
    }
    leave(x);
}
CGPathRef CGContextCopyPath(CGContextRef c) {
    struct CGContext *x = enter(c);
    int n = isim_cg_copy_path(NULL, 0);
    double *els = malloc(sizeof(double) * 7 * (size_t)(n ? n : 1));
    isim_cg_copy_path(els, n);
    leave(x);
    CGMutablePathRef p = CGPathCreateMutable();
    for (int i = 0; i < n; i++) {
        double *e = &els[7 * i];
        switch ((int)e[0]) {
        case 0: CGPathMoveToPoint(p, NULL, e[1], e[2]); break;
        case 1: CGPathAddLineToPoint(p, NULL, e[1], e[2]); break;
        case 3: CGPathAddCurveToPoint(p, NULL, e[1], e[2], e[3], e[4], e[5], e[6]); break;
        case 4: CGPathCloseSubpath(p); break;
        }
    }
    free(els);
    return p;
}
void CGContextReplacePathWithStrokedPath(CGContextRef c) {}
bool CGContextIsPathEmpty(CGContextRef c) { struct CGContext *x = enter(c); int n = isim_cg_copy_path(NULL, 0); leave(x); return n == 0; }
CGPoint CGContextGetPathCurrentPoint(CGContextRef c) { struct CGContext *x = enter(c); CGPoint p = current_point(); leave(x); return p; }
CGRect CGContextGetPathBoundingBox(CGContextRef c) {
    struct CGContext *x = enter(c); double o[4]; int has = isim_cg_copy_path(NULL, 0) > 0; isim_cg_query(0, 0, 0, o); leave(x);
    return has ? CGRectMake(o[0], o[1], o[2] - o[0], o[3] - o[1]) : CGRectNull;
}
bool CGContextPathContainsPoint(CGContextRef c, CGPoint p, CGPathDrawingMode mode) {
    struct CGContext *x = enter(c); double o[1]; int r = 0;
    int eo = mode == kCGPathEOFill || mode == kCGPathEOFillStroke;
    if (mode != kCGPathStroke) { if (eo) isim_path_set_fill_rule(1); r = isim_cg_query(3, p.x, p.y, o); if (eo) isim_path_set_fill_rule(0); }
    if (!r && (mode == kCGPathStroke || mode == kCGPathFillStroke || mode == kCGPathEOFillStroke)) {
        double rgba[4] = { 0 }; (void)rgba;
        r = isim_cg_query(4, p.x, p.y, o);
    }
    leave(x);
    return r;
}

/* ---- painting ---- */
static void paint_pattern(struct CGContext *x, int stroke, int mode) {
    struct gstate *g = G(x);
    CGPatternRef pat = stroke ? g->strokePat : g->fillPat;
    double cw, ch; int hd = isim_cg_pattern_cell(pat, stroke ? g->strokePatComps : g->fillPatComps, &cw, &ch);
    if (!hd) return;
    double iw, ih; isim_image_pixel_size(hd, &iw, &ih);
    /* pixels -> pattern space (the cell is drawn y-up) -> user space (pattern matrix + phase) */
    CGAffineTransform px = CGAffineTransformMake(cw / iw, 0, 0, -ch / ih, pat->bounds.origin.x, pat->bounds.origin.y + ch);
    CGAffineTransform m = CGAffineTransformConcat(CGAffineTransformConcat(px, pat->matrix), CGAffineTransformMakeTranslation(x->patternPhase.width, x->patternPhase.height));
    double mm[6] = { m.a, m.b, m.c, m.d, m.tx, m.ty };
    isim_cg_fill_pattern(hd, iw, ih, mm, mode, g->lw, g->alpha);
}
static void do_fill(struct CGContext *x) {
    double a[4];
    if (G(x)->fillPat) paint_pattern(x, 0, 0); else isim_path_fill(with_alpha(x, G(x)->fill, a));
}
static void do_stroke(struct CGContext *x) {
    double a[4];
    if (G(x)->strokePat) paint_pattern(x, 1, 1); else isim_path_stroke(G(x)->lw, with_alpha(x, G(x)->stroke, a));
}
void CGContextFillRect(CGContextRef c, CGRect r) {
    struct CGContext *x = enter(c); int fx = fx_begin(x);
    isim_path_begin(); isim_path_rect(r.origin.x, r.origin.y, r.size.width, r.size.height, 0); do_fill(x); isim_path_begin();
    fx_end(x, fx); leave(x);
}
void CGContextFillRects(CGContextRef c, const CGRect *r, size_t n) {
    struct CGContext *x = enter(c); int fx = fx_begin(x);
    isim_path_begin();
    for (size_t i = 0; r && i < n; i++) isim_path_rect(r[i].origin.x, r[i].origin.y, r[i].size.width, r[i].size.height, 0);
    do_fill(x); isim_path_begin();
    fx_end(x, fx); leave(x);
}
void CGContextStrokeRect(CGContextRef c, CGRect r) {
    struct CGContext *x = enter(c); int fx = fx_begin(x);
    isim_path_begin(); isim_path_rect(r.origin.x, r.origin.y, r.size.width, r.size.height, 0); do_stroke(x); isim_path_begin();
    fx_end(x, fx); leave(x);
}
void CGContextStrokeRectWithWidth(CGContextRef c, CGRect r, CGFloat w) {
    struct CGContext *x = enter(c); CGFloat old = G(x)->lw; G(x)->lw = w; CGContextStrokeRect(x, r); G(x)->lw = old; leave(x);
}
void CGContextFillEllipseInRect(CGContextRef c, CGRect r) {
    struct CGContext *x = enter(c); int fx = fx_begin(x);
    isim_path_begin(); CGContextAddEllipseInRect(x, r); do_fill(x); isim_path_begin();
    fx_end(x, fx); leave(x);
}
void CGContextStrokeEllipseInRect(CGContextRef c, CGRect r) {
    struct CGContext *x = enter(c); int fx = fx_begin(x);
    isim_path_begin(); CGContextAddEllipseInRect(x, r); do_stroke(x); isim_path_begin();
    fx_end(x, fx); leave(x);
}
void CGContextFillPath(CGContextRef c) { struct CGContext *x = enter(c); int fx = fx_begin(x); do_fill(x); isim_path_begin(); fx_end(x, fx); leave(x); }
void CGContextEOFillPath(CGContextRef c) { struct CGContext *x = enter(c); int fx = fx_begin(x); isim_path_set_fill_rule(1); do_fill(x); isim_path_set_fill_rule(0); isim_path_begin(); fx_end(x, fx); leave(x); }
void CGContextStrokePath(CGContextRef c) { struct CGContext *x = enter(c); int fx = fx_begin(x); do_stroke(x); isim_path_begin(); fx_end(x, fx); leave(x); }
void CGContextDrawPath(CGContextRef c, CGPathDrawingMode mode) {
    struct CGContext *x = enter(c); int fx = fx_begin(x);
    int eo = mode == kCGPathEOFill || mode == kCGPathEOFillStroke;
    if (eo) isim_path_set_fill_rule(1);
    if (mode == kCGPathFill || mode == kCGPathEOFill || mode == kCGPathFillStroke || mode == kCGPathEOFillStroke) do_fill(x);
    if (eo) isim_path_set_fill_rule(0);
    if (mode == kCGPathStroke || mode == kCGPathFillStroke || mode == kCGPathEOFillStroke) do_stroke(x);
    isim_path_begin();
    fx_end(x, fx); leave(x);
}
void CGContextStrokeLineSegments(CGContextRef c, const CGPoint *p, size_t n) {
    struct CGContext *x = enter(c); int fx = fx_begin(x);
    isim_path_begin();
    for (size_t i = 0; i + 1 < n; i += 2) { isim_path_move(p[i].x, p[i].y); isim_path_line(p[i + 1].x, p[i + 1].y); }
    do_stroke(x); isim_path_begin();
    fx_end(x, fx); leave(x);
}
void CGContextClearRect(CGContextRef c, CGRect r) { struct CGContext *x = enter(c); isim_cg_clear_rect(r.origin.x, r.origin.y, r.size.width, r.size.height); leave(x); }

/* ---- clipping ---- */
void CGContextClip(CGContextRef c) { struct CGContext *x = enter(c); isim_gfx_clip_path(); leave(x); }
void CGContextEOClip(CGContextRef c) { struct CGContext *x = enter(c); isim_path_set_fill_rule(1); isim_gfx_clip_path(); isim_path_set_fill_rule(0); leave(x); }
void CGContextClipToRect(CGContextRef c, CGRect r) { struct CGContext *x = enter(c); isim_gfx_clip_rounded(r.origin.x, r.origin.y, r.size.width, r.size.height, 0); leave(x); }
void CGContextClipToRects(CGContextRef c, const CGRect *r, size_t n) {
    struct CGContext *x = enter(c);
    isim_path_begin();
    for (size_t i = 0; r && i < n; i++) isim_path_rect(r[i].origin.x, r[i].origin.y, r[i].size.width, r[i].size.height, 0);
    isim_gfx_clip_path();
    leave(x);
}
void CGContextClipToMask(CGContextRef c, CGRect rect, CGImageRef mask) {
    if (!mask) return;
    struct CGContext *x = enter(c);
    struct gstate *g = G(x);
    if (g->mask) objc_release(g->mask);
    g->mask = objc_retain(mask); g->mrect = rect;
    double m[7]; isim_cg_get_ctm(m); memcpy(g->mm, m, sizeof g->mm);
    isim_gfx_clip_rounded(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height, 0);   /* nothing outside the mask rect */
    leave(x);
}
CGRect CGContextGetClipBoundingBox(CGContextRef c) {
    struct CGContext *x = enter(c); double o[4]; isim_cg_query(2, 0, 0, o); leave(x);
    return CGRectMake(o[0], o[1], o[2] - o[0], o[3] - o[1]);
}

/* ---- images ---- */
void CGContextDrawImage(CGContextRef c, CGRect r, CGImageRef im) {
    if (!im) return;
    struct CGContext *x = enter(c); int fx = fx_begin(x);
    /* Core Graphics draws images y-up: flip within the rect */
    isim_gfx_save();
    isim_gfx_translate(0, r.origin.y * 2 + r.size.height);
    isim_gfx_scale(1, -1);
    double a[4];
    if (im->ext && im->ext->mask)                    /* an image mask paints the fill color where it is opaque */
        isim_image_draw_part(im->handle, im->x, im->y, im->w, im->h, r.origin.x, r.origin.y, r.size.width, r.size.height,
                             G(x)->interp == kCGInterpolationNone, with_alpha(x, G(x)->fill, a), 1, a[3]);
    else
        isim_image_draw_part(im->handle, im->x, im->y, im->w, im->h, r.origin.x, r.origin.y, r.size.width, r.size.height,
                             G(x)->interp == kCGInterpolationNone, NULL, 0, G(x)->alpha);
    isim_gfx_restore();
    fx_end(x, fx); leave(x);
}
void CGContextDrawTiledImage(CGContextRef c, CGRect r, CGImageRef im) {
    if (!im || r.size.width <= 0 || r.size.height <= 0) return;
    struct CGContext *x = enter(c); int fx = fx_begin(x);
    double o[4]; isim_cg_query(2, 0, 0, o);                         /* tile the clip area */
    isim_gfx_save();
    isim_gfx_translate(0, r.origin.y * 2 + r.size.height);
    isim_gfx_scale(1, -1);
    double y0 = r.origin.y * 2 + r.size.height - o[3], y1 = r.origin.y * 2 + r.size.height - o[1];
    isim_cg_draw_image_tiled(im->handle, im->x, im->y, im->w, im->h, o[0], fmin(y0, y1), o[2] - o[0], fabs(y1 - y0), r.size.width, r.size.height);
    isim_gfx_restore();
    fx_end(x, fx); leave(x);
}

/* ---- gradients and shadings ---- */
static void gradient_paint(struct CGContext *x, int kind, const double *geom, int n, const double *locs, const double *rgba, int before, int after) {
    double *col = malloc(sizeof(double) * 4 * (size_t)n);
    for (int i = 0; i < n; i++) { memcpy(&col[4 * i], &rgba[4 * i], 4 * sizeof(double)); col[4 * i + 3] *= G(x)->alpha; }
    int fx = fx_begin(x);
    isim_gfx_save();
    if (kind == 0 && before != after) {             /* one side extended: clip to the half plane that is painted */
        double dx = geom[2] - geom[0], dy = geom[3] - geom[1], L = hypot(dx, dy);
        if (L > 1e-9) {
            dx /= L; dy /= L;
            double px = -dy * 1e6, py = dx * 1e6;
            double ax = before ? geom[2] : geom[0], ay = before ? geom[3] : geom[1], s = before ? -1e6 : 1e6;
            isim_path_begin();
            isim_path_move(ax + px, ay + py); isim_path_line(ax - px, ay - py);
            isim_path_line(ax - px + dx * s, ay - py + dy * s); isim_path_line(ax + px + dx * s, ay + py + dy * s); isim_path_close();
            isim_gfx_clip_path();
        }
    }
    isim_path_gradient(2, kind, geom, n, locs, col, before || after ? 1 : 0, 0, NULL);
    isim_gfx_restore();
    fx_end(x, fx);
    free(col);
}
void CGContextDrawLinearGradient(CGContextRef c, CGGradientRef gr, CGPoint s, CGPoint e, CGGradientDrawingOptions o) {
    if (!gr || gr->n < 1) return;
    struct CGContext *x = enter(c);
    double geom[4] = { s.x, s.y, e.x, e.y };
    gradient_paint(x, 0, geom, gr->n, gr->locs, gr->rgba, !!(o & kCGGradientDrawsBeforeStartLocation), !!(o & kCGGradientDrawsAfterEndLocation));
    leave(x);
}
void CGContextDrawRadialGradient(CGContextRef c, CGGradientRef gr, CGPoint s, CGFloat r0, CGPoint e, CGFloat r1, CGGradientDrawingOptions o) {
    if (!gr || gr->n < 1) return;
    struct CGContext *x = enter(c);
    double geom[6] = { s.x, s.y, r0, e.x, e.y, r1 };
    gradient_paint(x, 1, geom, gr->n, gr->locs, gr->rgba, !!(o & kCGGradientDrawsBeforeStartLocation), !!(o & kCGGradientDrawsAfterEndLocation));
    leave(x);
}
void CGContextDrawShading(CGContextRef c, CGShadingRef sh) {
    if (!sh || !sh->fn || !sh->fn->cb.evaluate) return;
    enum { N = 64 };
    double locs[N], rgba[4 * N];
    for (int i = 0; i < N; i++) {
        CGFloat t = sh->fn->domain[0] + (sh->fn->domain[1] - sh->fn->domain[0]) * i / (N - 1), out[16] = { 0 }, o[4];
        sh->fn->cb.evaluate(sh->fn->info, &t, out);
        if (sh->cs && sh->cs->ncomp + 1 > sh->fn->dout) out[sh->fn->dout] = 1;    /* functions without an alpha output are opaque */
        isim_cg_to_rgba(sh->cs, out, o);
        locs[i] = (double)i / (N - 1); for (int k = 0; k < 4; k++) rgba[4 * i + k] = o[k];
    }
    struct CGContext *x = enter(c);
    if (sh->radial) { double geom[6] = { sh->p0.x, sh->p0.y, sh->r0, sh->p1.x, sh->p1.y, sh->r1 }; gradient_paint(x, 1, geom, N, locs, rgba, sh->e0, sh->e1); }
    else { double geom[4] = { sh->p0.x, sh->p0.y, sh->p1.x, sh->p1.y }; gradient_paint(x, 0, geom, N, locs, rgba, sh->e0, sh->e1); }
    leave(x);
}

/* ---- text ---- */
void CGContextSetTextMatrix(CGContextRef c, CGAffineTransform t) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); x->textMatrix = t; }
CGAffineTransform CGContextGetTextMatrix(CGContextRef c) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); return x->textMatrix; }
void CGContextSetTextPosition(CGContextRef c, CGFloat px, CGFloat py) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); x->textPos = CGPointMake(px, py); }
CGPoint CGContextGetTextPosition(CGContextRef c) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); return x->textPos; }
void CGContextSetTextDrawingMode(CGContextRef c, CGTextDrawingMode m) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); G(x)->textMode = m; }
void CGContextSetCharacterSpacing(CGContextRef c, CGFloat s) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); G(x)->charSpacing = s; }
void CGContextSetFont(CGContextRef c, CGFontRef f) {
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    if (G(x)->font) objc_release(G(x)->font);
    G(x)->font = f ? objc_retain(f) : NULL;
}
void CGContextSetFontSize(CGContextRef c, CGFloat s) { struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context(); G(x)->fontSize = s; }
void isim_cg_context_draw_text_line(CGContextRef c, void *layout, int line, double dx, double dy, const double *def, double advance) {
    struct CGContext *x = enter(c);
    if (G(x)->textMode != kCGTextInvisible && G(x)->textMode != kCGTextClip) {
        int fx = fx_begin(x);
        double rgba[4];
        if (def) { memcpy(rgba, def, sizeof rgba); rgba[3] *= G(x)->alpha; } else with_alpha(x, G(x)->fill, rgba);
        CGAffineTransform t = x->textMatrix;
        double tm[6] = { t.a, t.b, t.c, t.d, t.tx, t.ty };
        isim_ct_line_draw(layout, line, x->textPos.x + dx, x->textPos.y + dy, tm, rgba);
        fx_end(x, fx);
    }
    x->textPos.x += advance;
    leave(x);
}
static char cg_font_name[256] = "Helvetica";
void CGContextSelectFont(CGContextRef c, const char *name, CGFloat size, int32_t enc) {
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    if (name) snprintf(cg_font_name, sizeof cg_font_name, "%s", name);
    G(x)->fontSize = size;
}
void CGContextShowText(CGContextRef c, const char *s, size_t len) {
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    if (!s || !len) return;
    char fam[256] = ""; double w = 0; int it = 0;
    isim_font_lookup(cg_font_name, fam, sizeof fam, &w, &it);
    size_t cap = len * 6 + 512; char *m = malloc(cap), *p = m;
    p += snprintf(p, cap, "<span size=\"%ld\"%s%s%s>", lround(G(x)->fontSize * 1024), fam[0] ? " font_family=\"" : "", fam, fam[0] ? "\"" : "");
    for (size_t i = 0; i < len; i++) {
        if (s[i] == '<') p += sprintf(p, "&lt;"); else if (s[i] == '>') p += sprintf(p, "&gt;"); else if (s[i] == '&') p += sprintf(p, "&amp;"); else *p++ = s[i];
    }
    sprintf(p, "</span>");
    void *l = isim_ct_layout_create(m, 0, 0, 0, 1);
    free(m);
    if (!l) return;
    double asc, desc, wd, lx, base, tw; int st, ln;
    isim_ct_line_info(l, 0, &asc, &desc, &wd, &lx, &base, &st, &ln, &tw);
    isim_cg_context_draw_text_line(x, l, 0, 0, 0, NULL, wd);
    isim_ct_layout_free(l);
}
void CGContextShowTextAtPoint(CGContextRef c, CGFloat px, CGFloat py, const char *s, size_t len) { CGContextSetTextPosition(c, px, py); CGContextShowText(c, s, len); }
