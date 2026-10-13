// isim Core Image filters: compositing operators (Porter-Duff) and blend modes (the W3C / PDF blend mode formulas,
// composited source-over). Also the per-pixel functions behind CIBlendKernel's built-in kernels.
#import "CIFilterImpl.h"

typedef enum {
    B_CLEAR, B_SOURCE, B_DEST, B_SOURCE_OVER, B_DEST_OVER, B_SOURCE_IN, B_DEST_IN, B_SOURCE_OUT, B_DEST_OUT, B_SOURCE_ATOP, B_DEST_ATOP, B_XOR,
    B_ADD, B_COMP_MULTIPLY, B_COMP_MIN, B_COMP_MAX,
    /* blend modes (source over with B(Cb, Cs)) */
    B_MULTIPLY, B_SCREEN, B_OVERLAY, B_DARKEN, B_LIGHTEN, B_COLOR_DODGE, B_COLOR_BURN, B_HARD_LIGHT, B_SOFT_LIGHT, B_DIFFERENCE,
    B_EXCLUSION, B_HUE, B_SATURATION, B_COLOR, B_LUMINOSITY, B_SUBTRACT, B_DIVIDE, B_LINEAR_BURN, B_LINEAR_DODGE, B_VIVID_LIGHT,
    B_LINEAR_LIGHT, B_PIN_LIGHT, B_HARD_MIX, B_DARKER_COLOR, B_LIGHTER_COLOR,
} blend_t;

static float burn(float b, float s) { return b >= 1 ? 1 : s <= 0 ? 0 : 1 - fminf(1, (1 - b) / s); }
static float dodge(float b, float s) { return b <= 0 ? 0 : s >= 1 ? 1 : fminf(1, b / (1 - s)); }
static float sep(blend_t m, float b, float s) {
    switch (m) {
    case B_MULTIPLY: return b * s;
    case B_SCREEN: return b + s - b * s;
    case B_OVERLAY: return b <= 0.5f ? 2 * s * b : 1 - 2 * (1 - s) * (1 - b);
    case B_DARKEN: return fminf(b, s);
    case B_LIGHTEN: return fmaxf(b, s);
    case B_COLOR_DODGE: return dodge(b, s);
    case B_COLOR_BURN: return burn(b, s);
    case B_HARD_LIGHT: return s <= 0.5f ? b * 2 * s : 1 - (1 - b) * (1 - (2 * s - 1));
    case B_SOFT_LIGHT: {
        if (s <= 0.5f) return b - (1 - 2 * s) * b * (1 - b);
        float d = b <= 0.25f ? ((16 * b - 12) * b + 4) * b : sqrtf(fmaxf(b, 0));
        return b + (2 * s - 1) * (d - b);
    }
    case B_DIFFERENCE: return fabsf(b - s);
    case B_EXCLUSION: return b + s - 2 * b * s;
    case B_SUBTRACT: return fmaxf(b - s, 0);
    case B_DIVIDE: return s > 0 ? b / s : (b > 0 ? 1 : 0);
    case B_LINEAR_BURN: return fmaxf(b + s - 1, 0);
    case B_LINEAR_DODGE: return fminf(b + s, 1);
    case B_VIVID_LIGHT: return s <= 0.5f ? burn(b, 2 * s) : dodge(b, 2 * (s - 0.5f));
    case B_LINEAR_LIGHT: return ci_clamp01(b + 2 * s - 1);
    case B_PIN_LIGHT: return s <= 0.5f ? fminf(b, 2 * s) : fmaxf(b, 2 * s - 1);
    case B_HARD_MIX: return b + s >= 1 ? 1 : 0;
    default: return s;
    }
}
static float lum(const float *c) { return 0.3f * c[0] + 0.59f * c[1] + 0.11f * c[2]; }
static void clip_color(float *c) {
    float l = lum(c), n = fminf(c[0], fminf(c[1], c[2])), x = fmaxf(c[0], fmaxf(c[1], c[2]));
    if (n < 0) for (int k = 0; k < 3; k++) c[k] = l + (c[k] - l) * l / (l - n);
    if (x > 1) for (int k = 0; k < 3; k++) c[k] = l + (c[k] - l) * (1 - l) / (x - l);
}
static void set_lum(float *c, float l) { float d = l - lum(c); for (int k = 0; k < 3; k++) c[k] += d; clip_color(c); }
static float satf(const float *c) { return fmaxf(c[0], fmaxf(c[1], c[2])) - fminf(c[0], fminf(c[1], c[2])); }
static void set_sat(float *c, float s) {
    int imax = 0, imin = 0;
    for (int k = 1; k < 3; k++) { if (c[k] > c[imax]) imax = k; if (c[k] < c[imin]) imin = k; }
    if (imax == imin) { c[0] = c[1] = c[2] = 0; return; }
    int imid = 3 - imax - imin;
    c[imid] = (c[imid] - c[imin]) * s / (c[imax] - c[imin]);
    c[imax] = s; c[imin] = 0;
}
/* src over dst, premultiplied, -> out */
static void blend_px(blend_t m, const float *s, const float *d, float *o) {
    float as = s[3], ad = d[3];
    switch (m) {
    case B_CLEAR: o[0] = o[1] = o[2] = o[3] = 0; return;
    case B_SOURCE: memcpy(o, s, 16); return;
    case B_DEST: memcpy(o, d, 16); return;
    case B_SOURCE_OVER: for (int k = 0; k < 4; k++) o[k] = s[k] + d[k] * (1 - as); return;
    case B_DEST_OVER: for (int k = 0; k < 4; k++) o[k] = d[k] + s[k] * (1 - ad); return;
    case B_SOURCE_IN: for (int k = 0; k < 4; k++) o[k] = s[k] * ad; return;
    case B_DEST_IN: for (int k = 0; k < 4; k++) o[k] = d[k] * as; return;
    case B_SOURCE_OUT: for (int k = 0; k < 4; k++) o[k] = s[k] * (1 - ad); return;
    case B_DEST_OUT: for (int k = 0; k < 4; k++) o[k] = d[k] * (1 - as); return;
    case B_SOURCE_ATOP: for (int k = 0; k < 3; k++) o[k] = s[k] * ad + d[k] * (1 - as); o[3] = ad; return;
    case B_DEST_ATOP: for (int k = 0; k < 3; k++) o[k] = d[k] * as + s[k] * (1 - ad); o[3] = as; return;
    case B_XOR: for (int k = 0; k < 4; k++) o[k] = s[k] * (1 - ad) + d[k] * (1 - as); return;
    case B_ADD: for (int k = 0; k < 4; k++) o[k] = s[k] + d[k]; return;
    case B_COMP_MULTIPLY: for (int k = 0; k < 4; k++) o[k] = s[k] * d[k]; return;
    case B_COMP_MIN: for (int k = 0; k < 4; k++) o[k] = fminf(s[k], d[k]); return;
    case B_COMP_MAX: for (int k = 0; k < 4; k++) o[k] = fmaxf(s[k], d[k]); return;
    default: break;
    }
    float cs[3], cb[3], r[3];
    for (int k = 0; k < 3; k++) { cs[k] = as > 0 ? s[k] / as : 0; cb[k] = ad > 0 ? d[k] / ad : 0; }
    switch (m) {
    case B_HUE: memcpy(r, cs, sizeof r); set_sat(r, satf(cb)); set_lum(r, lum(cb)); break;
    case B_SATURATION: memcpy(r, cb, sizeof r); set_sat(r, satf(cs)); set_lum(r, lum(cb)); break;
    case B_COLOR: memcpy(r, cs, sizeof r); set_lum(r, lum(cb)); break;
    case B_LUMINOSITY: memcpy(r, cb, sizeof r); set_lum(r, lum(cs)); break;
    case B_DARKER_COLOR: memcpy(r, lum(cs) < lum(cb) ? cs : cb, sizeof r); break;
    case B_LIGHTER_COLOR: memcpy(r, lum(cs) > lum(cb) ? cs : cb, sizeof r); break;
    default: for (int k = 0; k < 3; k++) r[k] = sep(m, cb[k], cs[k]);
    }
    for (int k = 0; k < 3; k++) o[k] = s[k] * (1 - ad) + d[k] * (1 - as) + as * ad * r[k];
    o[3] = as + ad - as * ad;
}
/* blend kernels: named built-ins (CIKernel.m) */
CI_HIDDEN int ci_blend_mode_named(NSString *name);
CI_HIDDEN void ci_blend_mode_px(int mode, const float *s, const float *d, float *o);
int ci_blend_mode_named(NSString *n) {
    static NSDictionary *names;
    if (!names) names = @{ @"componentAdd": @(B_ADD), @"componentMultiply": @(B_COMP_MULTIPLY), @"componentMin": @(B_COMP_MIN),
        @"componentMax": @(B_COMP_MAX), @"clear": @(B_CLEAR), @"source": @(B_SOURCE), @"destination": @(B_DEST), @"sourceOver": @(B_SOURCE_OVER),
        @"destinationOver": @(B_DEST_OVER), @"sourceIn": @(B_SOURCE_IN), @"destinationIn": @(B_DEST_IN), @"sourceOut": @(B_SOURCE_OUT),
        @"destinationOut": @(B_DEST_OUT), @"sourceAtop": @(B_SOURCE_ATOP), @"destinationAtop": @(B_DEST_ATOP), @"exclusiveOr": @(B_XOR),
        @"multiply": @(B_MULTIPLY), @"screen": @(B_SCREEN), @"overlay": @(B_OVERLAY), @"darken": @(B_DARKEN), @"lighten": @(B_LIGHTEN),
        @"colorDodge": @(B_COLOR_DODGE), @"colorBurn": @(B_COLOR_BURN), @"hardLight": @(B_HARD_LIGHT), @"softLight": @(B_SOFT_LIGHT),
        @"difference": @(B_DIFFERENCE), @"exclusion": @(B_EXCLUSION), @"hue": @(B_HUE), @"saturation": @(B_SATURATION), @"color": @(B_COLOR),
        @"luminosity": @(B_LUMINOSITY), @"subtract": @(B_SUBTRACT), @"divide": @(B_DIVIDE), @"linearBurn": @(B_LINEAR_BURN),
        @"linearDodge": @(B_LINEAR_DODGE), @"vividLight": @(B_VIVID_LIGHT), @"linearLight": @(B_LINEAR_LIGHT), @"pinLight": @(B_PIN_LIGHT),
        @"hardMix": @(B_HARD_MIX), @"darkerColor": @(B_DARKER_COLOR), @"lighterColor": @(B_LIGHTER_COLOR) };
    NSNumber *v = names[n];
    return v ? v.intValue : -1;
}
void ci_blend_mode_px(int mode, const float *s, const float *d, float *o) { blend_px((blend_t)mode, s, d, o); }

/* blend modes on straight colors defined in sRGB-encoded terms (as in image editors): convert when the working
   space is linear */
static CIImage *blend(CIImage *fg, CIImage *bg, blend_t m) {
    CGRect e;
    if (m == B_SOURCE_IN || m == B_COMP_MULTIPLY || m == B_COMP_MIN) e = CGRectIntersection(fg.extent, bg.extent);
    else if (m == B_SOURCE_ATOP) e = bg.extent;
    else e = CGRectUnion(fg.extent, bg.extent);
    if (CGRectIsNull(e)) return [CIImage emptyImage];
    BOOL perceptual = m >= B_MULTIPLY;
    return ci_op(e, ^(CGRect r, float *out, const ci_rctx *rc) {
        float *s = ci_render_new(fg, r, rc);
        [bg _render:r into:out ctx:rc];
        BOOL conv = perceptual && rc->managed && rc->ws.trc == CI_TRC_LINEAR;
        size_t n = (size_t)r.size.width * r.size.height;
        for (size_t i = 0; i < n; i++) {
            float *d = out + i * 4, *sp = s + i * 4, o[4];
            if (conv) {
                float a[4], b[4];
                for (int k = 0; k < 3; k++) { a[k] = sp[3] > 0 ? ci_trc_encode(CI_TRC_SRGB, sp[k] / sp[3]) * sp[3] : 0; b[k] = d[3] > 0 ? ci_trc_encode(CI_TRC_SRGB, d[k] / d[3]) * d[3] : 0; }
                a[3] = sp[3]; b[3] = d[3];
                blend_px(m, a, b, o);
                for (int k = 0; k < 3; k++) o[k] = o[3] > 0 ? ci_trc_decode(CI_TRC_SRGB, o[k] / o[3]) * o[3] : 0;
            } else blend_px(m, sp, d, o);
            memcpy(d, o, sizeof o);
        }
        free(s);
    });
}

void ci_register_composite_filters(void) {
    struct { NSString *name; blend_t m; } modes[] = {
        { @"CIAdditionCompositing", B_ADD }, { @"CIColorBlendMode", B_COLOR }, { @"CIColorBurnBlendMode", B_COLOR_BURN },
        { @"CIColorDodgeBlendMode", B_COLOR_DODGE }, { @"CIDarkenBlendMode", B_DARKEN }, { @"CIDifferenceBlendMode", B_DIFFERENCE },
        { @"CIDivideBlendMode", B_DIVIDE }, { @"CIExclusionBlendMode", B_EXCLUSION }, { @"CIHardLightBlendMode", B_HARD_LIGHT },
        { @"CIHueBlendMode", B_HUE }, { @"CILightenBlendMode", B_LIGHTEN }, { @"CILinearBurnBlendMode", B_LINEAR_BURN },
        { @"CILinearDodgeBlendMode", B_LINEAR_DODGE }, { @"CILinearLightBlendMode", B_LINEAR_LIGHT }, { @"CILuminosityBlendMode", B_LUMINOSITY },
        { @"CIMaximumCompositing", B_COMP_MAX }, { @"CIMinimumCompositing", B_COMP_MIN }, { @"CIMultiplyBlendMode", B_MULTIPLY },
        { @"CIMultiplyCompositing", B_COMP_MULTIPLY }, { @"CIOverlayBlendMode", B_OVERLAY }, { @"CIPinLightBlendMode", B_PIN_LIGHT },
        { @"CISaturationBlendMode", B_SATURATION }, { @"CIScreenBlendMode", B_SCREEN }, { @"CISoftLightBlendMode", B_SOFT_LIGHT },
        { @"CISourceAtopCompositing", B_SOURCE_ATOP }, { @"CISourceInCompositing", B_SOURCE_IN }, { @"CISourceOutCompositing", B_SOURCE_OUT },
        { @"CISourceOverCompositing", B_SOURCE_OVER }, { @"CISubtractBlendMode", B_SUBTRACT }, { @"CIVividLightBlendMode", B_VIVID_LIGHT },
    };
    for (size_t i = 0; i < sizeof modes / sizeof *modes; i++) {
        blend_t m = modes[i].m;
        ci_register_impl(modes[i].name, ^CIImage *(NSDictionary *in) {
            CIImage *fg = IMG(kCIInputImageKey), *bg = IMG(kCIInputBackgroundImageKey);
            if (!fg) return nil;
            if (!bg) return m == B_SOURCE_OVER || m == B_ADD || m == B_COMP_MAX ? fg : [CIImage emptyImage];
            return blend(fg, bg, m);
        });
    }
}
