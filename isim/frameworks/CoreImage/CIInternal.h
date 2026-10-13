// isim Core Image internals shared by the framework's sources (not installed in the SDK).
//
// Images are recipes: a tree of CIImage nodes, rendered on the CPU when a CIContext asks for a rectangle. A node
// renders an integral rectangle of Core Image space (y up) into a buffer of premultiplied RGBA floats whose rows run
// top-down (row 0 is the top, max y, of the rectangle), like a CGImage. Pixels are in the context's working space:
// extended linear sRGB by default, as on iOS; kCIContextWorkingColorSpace may name another space, or NSNull for no
// color management (pixels then pass through unconverted). Leaf images convert their pixels from their own color
// space when rendered; contexts convert to the output space when they write pixels out.
#pragma once
#import <CoreImage/CoreImage.h>
#include <isim_host.h>
#include <isim_host_cg.h>
#include <math.h>
#include <pthread.h>

/* the framework implements every API whatever the emulated iOS version */
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#define CI_HIDDEN __attribute__((visibility("hidden")))

/* ---- color spaces ---- */
enum { CI_PRIM_SRGB, CI_PRIM_P3, CI_PRIM_2020 };
enum { CI_TRC_LINEAR, CI_TRC_SRGB, CI_TRC_GAMMA22, CI_TRC_709, CI_TRC_PQ, CI_TRC_HLG, CI_TRC_GAMMA18 };
typedef struct { int prim, trc, gray, extended; } ci_space;
CI_HIDDEN extern const ci_space ci_space_srgb, ci_space_linear;
CI_HIDDEN ci_space ci_space_of(CGColorSpaceRef _Nullable cs);
/* option values: NSNull (any instance) and CGColorSpace objects, checked by type */
CI_HIDDEN BOOL ci_is_null(id _Nullable o);
CI_HIDDEN BOOL ci_is_cgspace(id _Nullable o);           /* NULL: sRGB */
CI_HIDDEN CGColorSpaceRef _Nonnull ci_cgspace_named(CFStringRef _Nonnull name);  /* cached, not retained */
CI_HIDDEN int ci_space_eq(ci_space a, ci_space b);
CI_HIDDEN float ci_trc_decode(int trc, float v);                        /* encoded -> linear (sign-extended) */
CI_HIDDEN float ci_trc_encode(int trc, float v);
/* convert n premultiplied RGBA pixels in place */
CI_HIDDEN void ci_convert(float *_Nonnull px, size_t n, ci_space from, ci_space to);
/* one straight (unpremultiplied) RGB color */
/* linear sRGB white of a color temperature (K) and tint (CITemperatureAndTint's model) */
CI_HIDDEN void ci_white_rgb(double T, double tint, float rgb[_Nonnull 3]);
CI_HIDDEN void ci_convert_rgb(float *_Nonnull rgb, ci_space from, ci_space to);

/* ---- render context ---- */
typedef struct ci_cache ci_cache;
typedef struct ci_rctx {
    int managed;               /* color management on */
    ci_space ws;               /* working space (when managed) */
    int hq;                    /* high quality downsampling */
    ci_cache *_Nullable cache; /* per-render results of whole-image nodes (reductions) */
    __unsafe_unretained CIContext *_Nullable context;
} ci_rctx;
CI_HIDDEN ci_rctx ci_rctx_default(void);
/* a working-space color (premultiplied) from a CIColor */
CI_HIDDEN void ci_color_ws(CIColor *_Nullable c, const ci_rctx *_Nonnull rc, float out[_Nonnull 4]);
/* the cached result of `make` for `key` during one render (thread-safe; make runs once) */
CI_HIDDEN id _Nullable ci_cache_get(const ci_rctx *_Nonnull rc, id _Nonnull key, id _Nullable (^_Nonnull make)(void));
CI_HIDDEN ci_cache *_Nonnull ci_cache_new(void);
CI_HIDDEN void ci_cache_free(ci_cache *_Nullable c);

/* ---- pixel buffers ---- */
typedef struct { float *_Nullable px; CGRect r; int w, h; } ci_buf;
CI_HIDDEN BOOL ci_infinite(CGRect r);
CI_HIDDEN CGRect ci_integral(CGRect r);                                  /* CGRectIntegral, keeps infinite/null */
CI_HIDDEN float *_Nonnull ci_render_new(CIImage *_Nonnull im, CGRect r, const ci_rctx *_Nonnull rc);
/* renders `want` (made integral, clipped to the image's extent grown by `pad` unless infinite) */
CI_HIDDEN ci_buf ci_buf_render(CIImage *_Nonnull im, CGRect want, int pad, const ci_rctx *_Nonnull rc);
CI_HIDDEN void ci_buf_free(ci_buf *_Nonnull b);
CI_HIDDEN const float *_Nullable ci_buf_at(const ci_buf *_Nonnull b, int x, int y);   /* CI pixel (x, y); NULL outside */
/* sampling at CI coordinates (pixel centers at .5); outside the buffer: clear */
enum { CI_SAMPLE_LINEAR, CI_SAMPLE_NEAREST, CI_SAMPLE_CUBIC };
CI_HIDDEN void ci_sample(const ci_buf *_Nonnull b, double x, double y, int mode, float out[_Nonnull 4]);
CI_HIDDEN void ci_sample_clamped(const ci_buf *_Nonnull b, double x, double y, int mode, float out[_Nonnull 4]);
/* the CI coordinates of buffer pixel (i, j) of rect r (center) */
static inline double ci_px_x(CGRect r, int i) { return r.origin.x + i + 0.5; }
static inline double ci_px_y(CGRect r, int j) { return r.origin.y + r.size.height - 1 - j + 0.5; }
static inline float ci_clamp01(float v) { return v < 0 ? 0 : v > 1 ? 1 : v; }
static inline float ci_luma(const float *_Nonnull c) { return 0.2126f * c[0] + 0.7152f * c[1] + 0.0722f * c[2]; }
CI_HIDDEN void ci_unpremul(float *_Nonnull p);
CI_HIDDEN void ci_premul(float *_Nonnull p);

/* ---- nodes ---- */
typedef void (^ci_render_fn)(CGRect r, float *_Nonnull out, const ci_rctx *_Nonnull rc);
@interface CIImage ()
@property (nonatomic) CGRect isimExtent;
@property (nonatomic, copy, nullable) NSDictionary *isimProperties;
@property (nonatomic, strong, nullable) NSURL *isimURL;
@property (nonatomic) int isimSampling;                 /* how consumers sample this image (CI_SAMPLE_*) */
@property (nonatomic) BOOL isimOpaque;
@property (nonatomic, strong, nullable) id isimCGColorSpace;   /* CGColorSpaceRef of the source */
@property (nonatomic, strong, nullable) id isimCGImage;        /* CGImageRef of the source */
@property (nonatomic, strong, nullable) id isimPixelBuffer;    /* CVPixelBuffer of the source (Swift object) */
@property (nonatomic, copy, nullable) NSDictionary *isimAux;   /* auxiliary images (depth, mattes, gain map) */
@property (nonatomic) double isimHeadroom;
- (void)_render:(CGRect)r into:(float *_Nonnull)buf ctx:(const ci_rctx *_Nonnull)rc;
- (CIImage *_Nonnull)_copyNode;                          /* a shallow copy that renders the same */
@end
/* a node rendering with a block (inputs are captured by the block) */
CI_HIDDEN CIImage *_Nonnull ci_op(CGRect extent, ci_render_fn _Nonnull fn);
/* per-pixel function of one input (premultiplied RGBA in place) */
CI_HIDDEN CIImage *_Nonnull ci_map(CIImage *_Nonnull in, void (^_Nonnull fn)(float *_Nonnull p));
/* per-pixel function of straight (unpremultiplied) RGB; alpha kept */
CI_HIDDEN CIImage *_Nonnull ci_map_rgb(CIImage *_Nonnull in, void (^_Nonnull fn)(float *_Nonnull c));
/* per-pixel function that knows the position (CI coordinates of the pixel center) */
CI_HIDDEN CIImage *_Nonnull ci_map_xy(CIImage *_Nonnull in, CGRect extent, void (^_Nonnull fn)(double x, double y, float *_Nonnull p));
/* generator: color of each position (premultiplied, working space); colors are converted with ci_color_ws in prep */
CI_HIDDEN CIImage *_Nonnull ci_gen(CGRect extent, void (^_Nonnull fn)(double x, double y, float *_Nonnull out, const ci_rctx *_Nonnull rc));
/* warp: out(x, y) = in(src(x, y)); the region of interest is found by mapping a grid of the output rect */
CI_HIDDEN CIImage *_Nonnull ci_warp(CIImage *_Nonnull in, CGRect extent, void (^_Nonnull src)(double x, double y, double *_Nonnull sx, double *_Nonnull sy));
CI_HIDDEN CIImage *_Nonnull ci_warp_mode(CIImage *_Nonnull in, CGRect extent, int clampEdges,
                                         void (^_Nonnull src)(double x, double y, double *_Nonnull sx, double *_Nonnull sy));
/* two inputs, per pixel (both premultiplied) */
CI_HIDDEN CIImage *_Nonnull ci_combine(CIImage *_Nonnull a, CIImage *_Nonnull b, CGRect extent, void (^_Nonnull fn)(float *_Nonnull out, const float *_Nonnull pa, const float *_Nonnull pb));
/* a leaf holding premultiplied float pixels (top-down rows) in `space` (ignored when color management is off) */
CI_HIDDEN CIImage *_Nonnull ci_bitmap(float *_Nonnull px, int w, int h, CGRect extent, ci_space space, BOOL raw);   /* takes px */
CI_HIDDEN CIImage *_Nonnull ci_bitmap_rgba8(const unsigned char *_Nonnull px, int w, int h, size_t bpr, int premultiplied, ci_space space);
/* Gaussian blur of an image (sigma in pixels) */
CI_HIDDEN void ci_blur_buf(float *_Nonnull px, int w, int h, double sigma);
CI_HIDDEN void ci_box_blur_buf(float *_Nonnull px, int w, int h, int rx, int ry);

/* ---- formats ---- */
typedef struct { int ch; int bytes; int isfloat; int half; int order[4]; int gray; int alpha; int premul; } ci_fmt;
CI_HIDDEN BOOL ci_fmt_of(CIFormat f, ci_fmt *_Nonnull out);
/* write premultiplied working pixels (already converted to the output space) as format f */
CI_HIDDEN void ci_store(const float *_Nonnull src, int w, int h, void *_Nonnull dst, ptrdiff_t rowBytes, CIFormat f);
/* read pixels of format f into premultiplied floats (premultiplied: whether the source color is premultiplied) */
CI_HIDDEN float *_Nullable ci_load(const void *_Nonnull src, int w, int h, ptrdiff_t rowBytes, CIFormat f, int premultiplied);
CI_HIDDEN uint16_t ci_f2h(float f);
CI_HIDDEN float ci_h2f(uint16_t h);

/* ---- context rendering ---- */
/* renders r of an image into premultiplied floats in the output space (parallel bands) */
CI_HIDDEN float *_Nullable ci_context_render(CIContext *_Nonnull ctx, CIImage *_Nonnull im, CGRect r, CGColorSpaceRef _Nullable outSpace);
/* a blend kernel applied to one pixel (premultiplied source over destination) */
CI_HIDDEN void ci_blend_apply(CIBlendKernel *_Nonnull k, const float *_Nonnull src, const float *_Nonnull dst, float *_Nonnull out);
CI_HIDDEN CGImageRef _Nullable ci_cgimage_from(const float *_Nonnull px, int w, int h, CGColorSpaceRef _Nullable space) CF_RETURNS_RETAINED;

/* ---- filters ---- */
CI_HIDDEN double ci_num(id _Nullable v, double d);
CI_HIDDEN CGPoint ci_point(id _Nullable v, CGPoint d);
CI_HIDDEN CGRect ci_rect(id _Nullable v, CGRect d);
CI_HIDDEN CGAffineTransform ci_xform(id _Nullable v);
CI_HIDDEN CIColor *_Nonnull ci_colorv(id _Nullable v, CIColor *_Nonnull d);
/* builtin filter implementations: name -> block(inputs) -> output image (nil: no output) */
typedef CIImage *_Nullable (^ci_filter_impl)(NSDictionary *_Nonnull in);
CI_HIDDEN void ci_register_impl(NSString *_Nonnull name, ci_filter_impl _Nonnull impl);
CI_HIDDEN ci_filter_impl _Nullable ci_impl_for(NSString *_Nonnull name);
/* each filter source file registers its filters in one of these (called once from CIFilter) */
CI_HIDDEN void ci_register_color_filters(void);
CI_HIDDEN void ci_register_blur_filters(void);
CI_HIDDEN void ci_register_composite_filters(void);
CI_HIDDEN void ci_register_geometry_filters(void);
CI_HIDDEN void ci_register_distortion_filters(void);
CI_HIDDEN void ci_register_generator_filters(void);
CI_HIDDEN void ci_register_stylize_filters(void);
CI_HIDDEN void ci_register_reduction_filters(void);
CI_HIDDEN void ci_register_tile_filters(void);
CI_HIDDEN void ci_register_transition_filters(void);
CI_HIDDEN void ci_register_ml_filters(void);
CI_HIDDEN void ci_register_halftone_filters(void);
CI_HIDDEN CIImage *_Nonnull ci_empty(void);
