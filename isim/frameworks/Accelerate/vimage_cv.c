// isim vImage (issue #693): Core Video interoperation. A vImageCVImageFormat describes a CVPixelBuffer's pixel format
// (its code, Y'CbCr matrix, chroma siting, colour space, alpha hint and per-channel ranges); converters between it and
// a vImage_CGImageFormat run through an ARGB8888 or ARGB16U intermediate: the Y'CbCr formats with vImage's own
// Y'CbCr conversions, the RGB and grey formats as Core Graphics formats. Adapted: chroma siting is kept but chroma is
// not resampled by position; the Y'CbCr and packed RGB formats are those listed in cvfmts below (no indexed formats).
#include "vimage_t.h"
#include <CoreVideo/CoreVideo.h>
#include <dlfcn.h>

/* Core Video is looked up when first used: Accelerate can load before it (a Swift app gets Core Video through the
   Accelerate overlay), so its symbols are not bound at load time */
static struct {
    int loaded;
    OSType (*format)(CVPixelBufferRef); size_t (*width)(CVPixelBufferRef), (*height)(CVPixelBufferRef), (*planes)(CVPixelBufferRef);
    void *(*plane_base)(CVPixelBufferRef, size_t); size_t (*plane_rb)(CVPixelBufferRef, size_t), (*plane_w)(CVPixelBufferRef, size_t), (*plane_h)(CVPixelBufferRef, size_t);
    void *(*base)(CVPixelBufferRef); size_t (*rb)(CVPixelBufferRef);
    CVReturn (*lock)(CVPixelBufferRef, CVPixelBufferLockFlags), (*unlock)(CVPixelBufferRef, CVPixelBufferLockFlags);
    CFTypeRef (*attachment)(CVBufferRef, CFStringRef, CVAttachmentMode *);
    const CFStringRef *matrix_key, *matrix_709, *space_key, *siting_key;
} cvl;
static int cv_load(void) {
    if (cvl.loaded) return cvl.loaded > 0;
    #define L(field, name) *(void **)&cvl.field = dlsym(RTLD_DEFAULT, name)
    L(format, "CVPixelBufferGetPixelFormatType"); L(width, "CVPixelBufferGetWidth"); L(height, "CVPixelBufferGetHeight");
    L(planes, "CVPixelBufferGetPlaneCount"); L(plane_base, "CVPixelBufferGetBaseAddressOfPlane"); L(plane_rb, "CVPixelBufferGetBytesPerRowOfPlane");
    L(plane_w, "CVPixelBufferGetWidthOfPlane"); L(plane_h, "CVPixelBufferGetHeightOfPlane"); L(base, "CVPixelBufferGetBaseAddress");
    L(rb, "CVPixelBufferGetBytesPerRow"); L(lock, "CVPixelBufferLockBaseAddress"); L(unlock, "CVPixelBufferUnlockBaseAddress");
    L(attachment, "CVBufferGetAttachment"); L(matrix_key, "kCVImageBufferYCbCrMatrixKey"); L(matrix_709, "kCVImageBufferYCbCrMatrix_ITU_R_709_2");
    L(space_key, "kCVImageBufferCGColorSpaceKey"); L(siting_key, "kCVImageBufferChromaLocationTopFieldKey");
    #undef L
    cvl.loaded = cvl.format && cvl.width && cvl.height && cvl.planes && cvl.plane_base && cvl.plane_rb && cvl.plane_w && cvl.plane_h && cvl.base && cvl.rb
                 && cvl.lock && cvl.unlock && cvl.attachment ? 1 : -1;
    return cvl.loaded > 0;
}
#define CVPixelBufferGetPixelFormatType cvl.format
#define CVPixelBufferGetWidth cvl.width
#define CVPixelBufferGetHeight cvl.height
#define CVPixelBufferGetPlaneCount cvl.planes
#define CVPixelBufferGetBaseAddressOfPlane cvl.plane_base
#define CVPixelBufferGetBytesPerRowOfPlane cvl.plane_rb
#define CVPixelBufferGetWidthOfPlane cvl.plane_w
#define CVPixelBufferGetHeightOfPlane cvl.plane_h
#define CVPixelBufferGetBaseAddress cvl.base
#define CVPixelBufferGetBytesPerRow cvl.rb
#define CVPixelBufferLockBaseAddress cvl.lock
#define CVPixelBufferUnlockBaseAddress cvl.unlock
#define CVBufferGetAttachment(b, k, m) ((k) ? cvl.attachment(b, k, m) : NULL)
#define kCVImageBufferYCbCrMatrixKey (cvl.matrix_key ? *cvl.matrix_key : NULL)
#define kCVImageBufferYCbCrMatrix_ITU_R_709_2 (cvl.matrix_709 ? *cvl.matrix_709 : NULL)
#define kCVImageBufferCGColorSpaceKey (cvl.space_key ? *cvl.space_key : NULL)
#define kCVImageBufferChromaLocationTopFieldKey (cvl.siting_key ? *cvl.siting_key : NULL)

void *isim_cg_obj_new(const char *kind, size_t size, void (*fin)(void *));
vImageConverterRef vimage_cv_converter(void *cv, vImage_Error (*run)(void *, const vImage_Buffer *, const vImage_Buffer *, vImage_Flags),
                                       void (*cv_free)(void *), const vImageBufferTypeCode *src_order, const vImageBufferTypeCode *dst_order);
void *vimage_converter_cv(vImageConverterRef c);

#define FCC(a, b, c, d) ((uint32_t)(a) << 24 | (uint32_t)(b) << 16 | (uint32_t)(c) << 8 | (uint32_t)(d))
enum { K_RGB, K_YCC, K_PACK };   /* K_PACK: packed RGB words (555, 565, 2101010), through the intermediate like Y'CbCr */
enum { L_420BI, L_420TRI, L_422CBY, L_422YCB, L_444CRYCB, L_444AYCBCR, L_444CBYCRA, L_V216, L_Y416, L_V410, L_V210, L_A2VY,
       L_X420, L_X422, L_X444,                                                  /* 10-bit bi-planar, issue #814 */
       L_B555, L_L555, L_5551, L_B565, L_L565, L_R10K, L_W30R, L_L10R };        /* packed RGB, issue #814 */
typedef struct {
    uint32_t code;
    int kind;
    /* RGB: the equivalent Core Graphics format */
    uint32_t bpc, bpp; CGBitmapInfo info; int gray;
    /* Y'CbCr: the layout, code bits, video range, alpha */
    int layout, bits, video, alpha;
    int nbuf; vImageBufferTypeCode order[4];
} cvfmt;
#define RGB(code, bpc, bpp, info, gray, alpha) { code, K_RGB, bpc, bpp, (CGBitmapInfo)(info), gray, 0, 0, 0, alpha, 1, { kvImageBufferTypeCode_CGFormat } }
#define YCC(code, layout, bits, video, alpha, n, ...) { code, K_YCC, 0, 0, 0, 0, layout, bits, video, alpha, n, { __VA_ARGS__ } }
#define LUM kvImageBufferTypeCode_Luminance
#define CHR kvImageBufferTypeCode_Chroma
#define CHK kvImageBufferTypeCode_Chunky
#define PACK(code, layout, bits, alpha) { code, K_PACK, 0, 0, 0, 0, layout, bits, 0, alpha, 1, { kvImageBufferTypeCode_Chunky } }
static const cvfmt cvfmts[] = {
    RGB(0x00000020, 8, 32, kCGImageAlphaFirst, 0, 1),                                     /* 32ARGB */
    RGB(FCC('B', 'G', 'R', 'A'), 8, 32, kCGImageAlphaFirst | kCGBitmapByteOrder32Little, 0, 1),
    RGB(FCC('R', 'G', 'B', 'A'), 8, 32, kCGImageAlphaLast, 0, 1),
    RGB(FCC('A', 'B', 'G', 'R'), 8, 32, kCGImageAlphaLast | kCGBitmapByteOrder32Little, 0, 1),
    RGB(0x00000018, 8, 24, kCGImageAlphaNone, 0, 0),                                      /* 24RGB */
    RGB(FCC('b', '6', '4', 'a'), 16, 64, kCGImageAlphaFirst, 0, 1),                       /* 64ARGB, big-endian */
    RGB(FCC('R', 'G', 'h', 'A'), 16, 64, kCGImageAlphaLast | kCGBitmapFloatComponents | kCGBitmapByteOrder16Little, 0, 1),
    RGB(FCC('L', '0', '0', '8'), 8, 8, kCGImageAlphaNone, 1, 0),
    RGB(FCC('L', '0', '1', '6'), 16, 16, kCGImageAlphaNone | kCGBitmapByteOrder16Little, 1, 0),
    RGB(FCC('L', '0', '0', 'h'), 16, 16, kCGImageAlphaNone | kCGBitmapFloatComponents | kCGBitmapByteOrder16Little, 1, 0),
    RGB(FCC('L', '0', '0', 'f'), 32, 32, kCGImageAlphaNone | kCGBitmapFloatComponents | kCGBitmapByteOrder32Little, 1, 0),
    YCC(FCC('4', '2', '0', 'v'), L_420BI, 8, 1, 0, 2, LUM, CHR),
    YCC(FCC('4', '2', '0', 'f'), L_420BI, 8, 0, 0, 2, LUM, CHR),
    YCC(FCC('y', '4', '2', '0'), L_420TRI, 8, 1, 0, 3, LUM, kvImageBufferTypeCode_Cb, kvImageBufferTypeCode_Cr),
    YCC(FCC('f', '4', '2', '0'), L_420TRI, 8, 0, 0, 3, LUM, kvImageBufferTypeCode_Cb, kvImageBufferTypeCode_Cr),
    YCC(FCC('2', 'v', 'u', 'y'), L_422CBY, 8, 1, 0, 1, CHK),
    YCC(FCC('y', 'u', 'v', 's'), L_422YCB, 8, 1, 0, 1, CHK),
    YCC(FCC('y', 'u', 'v', 'f'), L_422YCB, 8, 0, 0, 1, CHK),
    YCC(FCC('v', '3', '0', '8'), L_444CRYCB, 8, 1, 0, 1, CHK),
    YCC(FCC('y', '4', '0', '8'), L_444AYCBCR, 8, 1, 1, 1, CHK),
    YCC(FCC('v', '4', '0', '8'), L_444CBYCRA, 8, 1, 1, 1, CHK),
    YCC(FCC('v', '2', '1', '6'), L_V216, 16, 1, 0, 1, CHK),
    YCC(FCC('y', '4', '1', '6'), L_Y416, 16, 1, 1, 1, CHK),
    YCC(FCC('v', '4', '1', '0'), L_V410, 10, 1, 0, 1, CHK),
    YCC(FCC('v', '2', '1', '0'), L_V210, 10, 1, 0, 1, CHK),
    YCC(FCC('a', '2', 'v', 'y'), L_A2VY, 8, 1, 1, 2, CHK, kvImageBufferTypeCode_Alpha),
    YCC(FCC('x', '4', '2', '0'), L_X420, 10, 1, 0, 2, LUM, CHR),
    YCC(FCC('x', 'f', '2', '0'), L_X420, 10, 0, 0, 2, LUM, CHR),
    YCC(FCC('x', '4', '2', '2'), L_X422, 10, 1, 0, 2, LUM, CHR),
    YCC(FCC('x', 'f', '2', '2'), L_X422, 10, 0, 0, 2, LUM, CHR),
    YCC(FCC('x', '4', '4', '4'), L_X444, 10, 1, 0, 2, LUM, CHR),
    YCC(FCC('x', 'f', '4', '4'), L_X444, 10, 0, 0, 2, LUM, CHR),
    PACK(0x00000010, L_B555, 5, 0),                     /* 16BE555 */
    PACK(FCC('L', '5', '5', '5'), L_L555, 5, 0),
    PACK(FCC('5', '5', '5', '1'), L_5551, 5, 1),
    PACK(FCC('B', '5', '6', '5'), L_B565, 5, 0),
    PACK(FCC('L', '5', '6', '5'), L_L565, 5, 0),
    PACK(FCC('R', '1', '0', 'k'), L_R10K, 10, 0),       /* 30RGB: big-endian R10 G10 B10 X2 */
    PACK(FCC('w', '3', '0', 'r'), L_W30R, 10, 0),       /* 30RGBLEPackedWideGamut: X2 R10 G10 B10, 384...894 is 0...1 */
    PACK(FCC('l', '1', '0', 'r'), L_L10R, 10, 1),       /* ARGB2101010LEPacked */
};
static const cvfmt *cvfmt_of(uint32_t code) {
    for (size_t i = 0; i < sizeof cvfmts / sizeof *cvfmts; i++) if (cvfmts[i].code == code) return &cvfmts[i];
    return NULL;
}

/* ---- vImageCVImageFormat ---- */
struct vImageCVImageFormat {
    struct { void *isa; void (*fin)(void *); const char *kind; } hdr;
    const cvfmt *f;
    uint32_t code;
    int has_matrix; vImage_ARGBToYpCbCrMatrix matrix;
    CFStringRef siting;
    CGColorSpaceRef space;
    int alpha_hint;
    vImageBufferTypeCode names[6];
    uint32_t nchannels;
    vImageChannelDescription desc[24];   /* by buffer type code */
    void *user; void (*user_free)(vImageCVImageFormatRef, void *);
};
static void cvf_free(void *p) {
    struct vImageCVImageFormat *f = p;
    if (f->user_free) f->user_free(f, f->user);
    if (f->siting) CFRelease(f->siting);
    if (f->space) CGColorSpaceRelease(f->space);
}
static void default_ranges(struct vImageCVImageFormat *v) {
    const cvfmt *f = v->f;
    for (int i = 0; i < 24; i++) v->desc[i] = (vImageChannelDescription){ 0, 0, 255, 255 };
    if (!f) return;
    if (f->kind == K_PACK) {
        double full = f->bits == 10 ? 1023 : 255;
        for (int i = 0; i < 24; i++) v->desc[i] = (vImageChannelDescription){ 0, 0, full, full };
        return;
    }
    if (f->kind == K_RGB) {
        double full = f->bpc == 16 && !(f->info & kCGBitmapFloatComponents) ? 65535 : f->info & kCGBitmapFloatComponents ? 1 : 255;
        for (int i = 0; i < 24; i++) v->desc[i] = (vImageChannelDescription){ 0, 0, full, full };
        return;
    }
    double k = f->bits == 16 ? 256 : f->bits == 10 ? 4 : 1, top = f->bits == 16 ? 65535 : f->bits == 10 ? 1023 : 255;
    vImageChannelDescription y = f->video ? (vImageChannelDescription){ 16 * k, 16 * k, 235 * k, 235 * k } : (vImageChannelDescription){ 0, 0, top, top };
    vImageChannelDescription c = f->video ? (vImageChannelDescription){ 16 * k, 128 * k, 240 * k, 240 * k } : (vImageChannelDescription){ 0, 128 * k, top, top };
    v->desc[LUM] = y; v->desc[kvImageBufferTypeCode_Cb] = c; v->desc[kvImageBufferTypeCode_Cr] = c; v->desc[CHR] = c;
    v->desc[kvImageBufferTypeCode_Alpha] = (vImageChannelDescription){ 0, 0, top, top };
}
static void names_of(struct vImageCVImageFormat *v) {
    const cvfmt *f = v->f; int n = 0;
    if (!f) { v->names[0] = 0; v->nchannels = 0; return; }
    if (f->kind != K_YCC) {
        if (f->kind == K_RGB && f->gray) v->names[n++] = kvImageBufferTypeCode_Monochrome;
        else { v->names[n++] = kvImageBufferTypeCode_RGB_Red; v->names[n++] = kvImageBufferTypeCode_RGB_Green; v->names[n++] = kvImageBufferTypeCode_RGB_Blue; }
    } else { v->names[n++] = LUM; v->names[n++] = kvImageBufferTypeCode_Cb; v->names[n++] = kvImageBufferTypeCode_Cr; }
    if (f->alpha) v->names[n++] = kvImageBufferTypeCode_Alpha;
    v->names[n] = kvImageBufferTypeCode_EndOfList;
    v->nchannels = (uint32_t)n;
}
vImageCVImageFormatRef vImageCVImageFormat_Create(uint32_t imageFormatType, const vImage_ARGBToYpCbCrMatrix *matrix, CFStringRef cvImageBufferChromaLocation,
                                                  CGColorSpaceRef baseColorspace, int alphaIsOneHint) {
    struct vImageCVImageFormat *v = isim_cg_obj_new("vImageCVImageFormat", sizeof *v, cvf_free);
    if (!v) return NULL;
    v->code = imageFormatType; v->f = cvfmt_of(imageFormatType);
    if (matrix) { v->has_matrix = 1; v->matrix = *matrix; }
    if (cvImageBufferChromaLocation) v->siting = CFRetain(cvImageBufferChromaLocation);
    if (baseColorspace) v->space = CGColorSpaceRetain(baseColorspace);
    v->alpha_hint = alphaIsOneHint;
    default_ranges(v); names_of(v);
    return v;
}
vImageCVImageFormatRef vImageCVImageFormat_CreateWithCVPixelBuffer(CVPixelBufferRef buffer) {
    if (!buffer || !cv_load()) return NULL;
    uint32_t code = CVPixelBufferGetPixelFormatType(buffer);
    const cvfmt *f = cvfmt_of(code);
    const vImage_ARGBToYpCbCrMatrix *m = NULL;
    if (f && f->kind == K_YCC) {
        CFTypeRef mk = CVBufferGetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, NULL);
        m = mk && kCVImageBufferYCbCrMatrix_ITU_R_709_2 && CFEqual(mk, kCVImageBufferYCbCrMatrix_ITU_R_709_2) ? kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2 : kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4;
    }
    CFTypeRef cs = CVBufferGetAttachment(buffer, kCVImageBufferCGColorSpaceKey, NULL);
    CGColorSpaceRef space = cs ? (CGColorSpaceRef)cs : NULL, made = NULL;
    if (!space) space = made = f && f->kind == K_RGB && f->gray ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
    CFTypeRef siting = CVBufferGetAttachment(buffer, kCVImageBufferChromaLocationTopFieldKey, NULL);
    vImageCVImageFormatRef v = vImageCVImageFormat_Create(code, m, siting, space, 0);
    if (made) CGColorSpaceRelease(made);
    return v;
}
vImageCVImageFormatRef vImageCVImageFormat_Copy(vImageConstCVImageFormatRef format) {
    if (!format) return NULL;
    vImageCVImageFormatRef c = vImageCVImageFormat_Create(format->code, format->has_matrix ? &format->matrix : NULL, format->siting, format->space, format->alpha_hint);
    if (c) memcpy(c->desc, format->desc, sizeof c->desc);
    return c;
}
vImageCVImageFormatRef vImageCVImageFormat_Retain(vImageCVImageFormatRef f) { return f ? (vImageCVImageFormatRef)CFRetain(f) : NULL; }
void vImageCVImageFormat_Release(vImageCVImageFormatRef f) { if (f) CFRelease(f); }
uint32_t vImageCVImageFormat_GetFormatCode(vImageConstCVImageFormatRef f) { return f ? f->code : 0; }
uint32_t vImageCVImageFormat_GetChannelCount(vImageConstCVImageFormatRef f) { return f ? f->nchannels : 0; }
const vImageBufferTypeCode *vImageCVImageFormat_GetChannelNames(vImageConstCVImageFormatRef f) { return f ? f->names : NULL; }
const vImageChannelDescription *vImageCVImageFormat_GetChannelDescription(vImageConstCVImageFormatRef f, vImageBufferTypeCode type) {
    if (!f || type >= 24) return NULL;
    for (uint32_t i = 0; i < f->nchannels; i++) if (f->names[i] == type) return &f->desc[type];
    return type == CHR && f->f && f->f->kind == K_YCC ? &f->desc[CHR] : NULL;
}
vImage_Error vImageCVImageFormat_CopyChannelDescription(vImageCVImageFormatRef f, const vImageChannelDescription *desc, vImageBufferTypeCode type) {
    if (!f || !desc) return kvImageNullPointerArgument;
    if (type >= 24) return kvImageInvalidParameter;
    f->desc[type] = *desc;
    if (type == kvImageBufferTypeCode_Cb || type == kvImageBufferTypeCode_Cr) f->desc[CHR] = *desc;
    if (type == CHR) f->desc[kvImageBufferTypeCode_Cb] = f->desc[kvImageBufferTypeCode_Cr] = *desc;
    return kvImageNoError;
}
CFStringRef vImageCVImageFormat_GetChromaSiting(vImageConstCVImageFormatRef f) { return f ? f->siting : NULL; }
vImage_Error vImageCVImageFormat_SetChromaSiting(vImageCVImageFormatRef f, CFStringRef siting) {
    if (!f) return kvImageNullPointerArgument;
    if (siting) CFRetain(siting);
    if (f->siting) CFRelease(f->siting);
    f->siting = siting;
    return kvImageNoError;
}
CGColorSpaceRef vImageCVImageFormat_GetColorSpace(vImageConstCVImageFormatRef f) { return f ? f->space : NULL; }
vImage_Error vImageCVImageFormat_SetColorSpace(vImageCVImageFormatRef f, CGColorSpaceRef space) {
    if (!f) return kvImageNullPointerArgument;
    if (space) CGColorSpaceRetain(space);
    if (f->space) CGColorSpaceRelease(f->space);
    f->space = space;
    return kvImageNoError;
}
int vImageCVImageFormat_GetAlphaHint(vImageConstCVImageFormatRef f) { return f ? f->alpha_hint : 0; }
vImage_Error vImageCVImageFormat_SetAlphaHint(vImageCVImageFormatRef f, int alphaIsOne) {
    if (!f) return kvImageNullPointerArgument;
    f->alpha_hint = alphaIsOne;
    return kvImageNoError;
}
const void *vImageCVImageFormat_GetConversionMatrix(vImageConstCVImageFormatRef f, vImageMatrixType *outType) {
    if (outType) *outType = f && f->has_matrix ? kvImageMatrixType_ARGBToYpCbCrMatrix : kvImageMatrixType_None;
    return f && f->has_matrix ? &f->matrix : NULL;
}
vImage_Error vImageCVImageFormat_CopyConversionMatrix(vImageCVImageFormatRef f, const void *matrix, vImageMatrixType inType) {
    if (!f || !matrix) return kvImageNullPointerArgument;
    if (inType != kvImageMatrixType_ARGBToYpCbCrMatrix) return kvImageInvalidParameter;
    f->matrix = *(const vImage_ARGBToYpCbCrMatrix *)matrix; f->has_matrix = 1;
    return kvImageNoError;
}
void *vImageCVImageFormat_GetUserData(vImageConstCVImageFormatRef f) { return f ? f->user : NULL; }
vImage_Error vImageCVImageFormat_SetUserData(vImageCVImageFormatRef f, void *userData, void (*userDataReleaseCallback)(vImageCVImageFormatRef, void *)) {
    if (!f) return kvImageNullPointerArgument;
    if (f->user_free) f->user_free(f, f->user);
    f->user = userData; f->user_free = userDataReleaseCallback;
    return kvImageNoError;
}

/* ---- converters ---- */
typedef struct {
    int to_cv;
    const cvfmt *f;
    vImage_YpCbCrToARGB y2a; vImage_ARGBToYpCbCr a2y;
    vImageConverterRef inner;            /* CG <-> the intermediate (or the CV format's CG equivalent) */
    vt_t mid;                            /* VT_U8 or VT_U16 */
    float kr, kb, kg, y0, ys, c0, cs;    /* the 10-bit bi-planar formats: the matrix and the code ranges */
} cvconv;
static void cvconv_free(void *p) { cvconv *c = p; if (c->inner) vImageConverter_Release(c->inner); free(c); }

static vImage_Error ycc_info(const struct vImageCVImageFormat *v, cvconv *c) {
    if (!v->has_matrix) return kvImageCVImageFormat_ConversionMatrix;
    const vImage_ARGBToYpCbCrMatrix *a = &v->matrix;
    float kr = a->R_Yp, kb = a->B_Yp, kg = a->G_Yp;
    if (kg <= 0) return kvImageCVImageFormat_ConversionMatrix;
    vImage_YpCbCrToARGBMatrix m = { 1, 2 * (1 - kr), -2 * (1 - kr) * kr / kg, -2 * (1 - kb) * kb / kg, 2 * (1 - kb) };
    vImageChannelDescription y = v->desc[LUM], cb = v->desc[kvImageBufferTypeCode_Cb];
    vImage_YpCbCrPixelRange r = { (int32_t)lrint(y.zero), (int32_t)lrint(cb.zero), (int32_t)lrint(y.full), (int32_t)lrint(cb.full),
                                  (int32_t)lrint(y.max), (int32_t)lrint(y.min), (int32_t)lrint(cb.max), (int32_t)lrint(cb.min) };
    c->kr = kr; c->kb = kb; c->kg = kg;
    c->y0 = (float)y.zero; c->ys = (float)(y.full - y.zero); c->c0 = (float)cb.zero; c->cs = (float)(cb.full - cb.zero);
    if (c->ys <= 0 || c->cs <= 0) return kvImageCVImageFormat_VideoChannelDescription;
    vImage_Error e = vImageConvert_YpCbCrToARGB_GenerateConversion(&m, &r, &c->y2a, kvImage420Yp8_CbCr8, kvImageARGB8888, 0);
    if (!e) e = vImageConvert_ARGBToYpCbCr_GenerateConversion(a, &r, &c->a2y, kvImageARGB8888, kvImage420Yp8_CbCr8, 0);
    return e ? kvImageCVImageFormat_VideoChannelDescription : kvImageNoError;
}
static vImage_CGImageFormat mid_format(vt_t mid, CGColorSpaceRef space) {
    return mid == VT_U8 ? (vImage_CGImageFormat){ 8, 32, space, (CGBitmapInfo)kCGImageAlphaFirst, 0, NULL, kCGRenderingIntentDefault }
                        : (vImage_CGImageFormat){ 16, 64, space, (CGBitmapInfo)(kCGImageAlphaFirst | kCGBitmapByteOrder16Little), 0, NULL, kCGRenderingIntentDefault };
}
static vImage_CGImageFormat rgb_format(const cvfmt *f, CGColorSpaceRef space) {
    return (vImage_CGImageFormat){ f->bpc, f->bpp, space, f->info, 0, NULL, kCGRenderingIntentDefault };
}
/* Q12 <-> 16U for the 10-bit formats */
static void q12_to_16u(vImage_Buffer *b) {
    for (vImagePixelCount y = 0; y < b->height; y++) { int16_t *r = (int16_t *)vrowm(b, (long)y);
        for (vImagePixelCount i = 0; i < b->width * 4; i++) ((uint16_t *)r)[i] = (uint16_t)lrintf(vclampf(r[i] * 65535.f / 4096.f, 0, 65535)); }
}
static void u16_to_q12(vImage_Buffer *b) {
    for (vImagePixelCount y = 0; y < b->height; y++) { uint16_t *r = (uint16_t *)vrowm(b, (long)y);
        for (vImagePixelCount i = 0; i < b->width * 4; i++) ((int16_t *)r)[i] = (int16_t)lrintf(r[i] * 4096.f / 65535.f); }
}
/* ---- the 10-bit bi-planar Y'CbCr formats (issue #814): 16-bit samples with the code in the high 10 bits, the chroma
   plane interleaved Cb Cr, subsampled 2 x 2 (420), 2 x 1 (422) or not (444); decoded to and encoded from ARGB16U ---- */
static void x4xx_sub(int layout, int *sx, int *sy) { *sx = layout == L_X444 ? 1 : 2; *sy = layout == L_X420 ? 2 : 1; }
static vImage_Error x4xx_decode(const cvconv *c, const vImage_Buffer *s, const vImage_Buffer *argb) {
    int sx, sy; x4xx_sub(c->f->layout, &sx, &sy);
    for (vImagePixelCount y = 0; y < argb->height; y++) {
        const uint16_t *yr = (const uint16_t *)vrow(&s[0], (long)y), *cr = (const uint16_t *)vrow(&s[1], (long)(y / (vImagePixelCount)sy));
        uint16_t *o = (uint16_t *)vrowm(argb, (long)y);
        for (vImagePixelCount x = 0; x < argb->width; x++) {
            const uint16_t *cc = cr + (x / (vImagePixelCount)sx) * 2;
            float l = ((yr[x] >> 6) - c->y0) / c->ys, u = ((cc[0] >> 6) - c->c0) / c->cs * .5f, v = ((cc[1] >> 6) - c->c0) / c->cs * .5f;
            float r = l + 2 * (1 - c->kr) * v, b = l + 2 * (1 - c->kb) * u, g = (l - c->kr * r - c->kb * b) / c->kg;
            o[4 * x] = 65535; o[4 * x + 1] = (uint16_t)lrintf(vclampf(r, 0, 1) * 65535);
            o[4 * x + 2] = (uint16_t)lrintf(vclampf(g, 0, 1) * 65535); o[4 * x + 3] = (uint16_t)lrintf(vclampf(b, 0, 1) * 65535);
        }
    }
    return kvImageNoError;
}
static uint16_t x4xx_code(float v) { return (uint16_t)((uint16_t)lrintf(vclampf(v, 0, 1023)) << 6); }
static vImage_Error x4xx_encode(const cvconv *c, const vImage_Buffer *argb, const vImage_Buffer *d) {
    int sx, sy; x4xx_sub(c->f->layout, &sx, &sy);
    vImagePixelCount w = argb->width, h = argb->height;
    for (vImagePixelCount y = 0; y < h; y++) {
        const uint16_t *i = (const uint16_t *)vrow(argb, (long)y); uint16_t *yr = (uint16_t *)vrowm(&d[0], (long)y);
        for (vImagePixelCount x = 0; x < w; x++) {
            float l = (c->kr * i[4 * x + 1] + c->kg * i[4 * x + 2] + c->kb * i[4 * x + 3]) / 65535.f;
            yr[x] = x4xx_code(c->y0 + l * c->ys);
        }
    }
    for (vImagePixelCount cy = 0; cy * (vImagePixelCount)sy < h; cy++) {
        uint16_t *cr = (uint16_t *)vrowm(&d[1], (long)cy);
        for (vImagePixelCount cx = 0; cx * (vImagePixelCount)sx < w; cx++) {
            float su = 0, sv = 0; int n = 0;
            for (int dy = 0; dy < sy; dy++) for (int dx = 0; dx < sx; dx++) {
                vImagePixelCount x = cx * (vImagePixelCount)sx + (vImagePixelCount)dx, y = cy * (vImagePixelCount)sy + (vImagePixelCount)dy;
                if (x >= w || y >= h) continue;
                const uint16_t *p = (const uint16_t *)vrow(argb, (long)y) + 4 * x;
                float r = p[1] / 65535.f, g = p[2] / 65535.f, b = p[3] / 65535.f, l = c->kr * r + c->kg * g + c->kb * b;
                su += (b - l) / (2 * (1 - c->kb)); sv += (r - l) / (2 * (1 - c->kr)); n++;
            }
            cr[2 * cx] = x4xx_code(c->c0 + su / (float)n * 2 * c->cs); cr[2 * cx + 1] = x4xx_code(c->c0 + sv / (float)n * 2 * c->cs);
        }
    }
    return kvImageNoError;
}

/* ---- packed RGB words (issue #814): 555 / 565 / 5551 to and from ARGB8888, 2101010 to and from ARGB16U ---- */
static uint8_t x5to8(unsigned v) { return (uint8_t)(v << 3 | v >> 2); }
static uint8_t x6to8(unsigned v) { return (uint8_t)(v << 2 | v >> 4); }
static float w30_in(unsigned v) { return vclampf(((float)v - 384.f) / 510.f, 0, 1); }   /* extended range -0.75...1.25, clamped */
static unsigned w30_out(float v) { return (unsigned)lrintf(vclampf(v * 510.f + 384.f, 0, 1023)); }
static vImage_Error packed_decode(int layout, const vImage_Buffer *s, const vImage_Buffer *argb) {
    for (vImagePixelCount y = 0; y < argb->height; y++) {
        const uint8_t *r = vrow(s, (long)y);
        if (layout <= L_L565) {
            uint8_t *o = vrowm(argb, (long)y);
            for (vImagePixelCount x = 0; x < argb->width; x++) {
                const uint8_t *p = r + 2 * x;
                unsigned w = layout == L_B555 || layout == L_B565 ? (unsigned)(p[0] << 8 | p[1]) : (unsigned)(p[0] | p[1] << 8);
                uint8_t *q = o + 4 * x;
                switch (layout) {
                case L_B555: case L_L555: q[0] = 255; q[1] = x5to8(w >> 10 & 31); q[2] = x5to8(w >> 5 & 31); q[3] = x5to8(w & 31); break;
                case L_5551: q[0] = (w & 1) ? 255 : 0; q[1] = x5to8(w >> 11 & 31); q[2] = x5to8(w >> 6 & 31); q[3] = x5to8(w >> 1 & 31); break;
                default: q[0] = 255; q[1] = x5to8(w >> 11 & 31); q[2] = x6to8(w >> 5 & 63); q[3] = x5to8(w & 31); break;
                }
            }
        } else {
            uint16_t *o = (uint16_t *)vrowm(argb, (long)y);
            for (vImagePixelCount x = 0; x < argb->width; x++) {
                const uint8_t *p = r + 4 * x;
                uint32_t w = layout == L_R10K ? (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]
                                              : (uint32_t)p[3] << 24 | (uint32_t)p[2] << 16 | (uint32_t)p[1] << 8 | p[0];
                uint16_t *q = o + 4 * x;
                unsigned rr, gg, bb; int sh = layout == L_R10K ? 2 : 0;
                rr = w >> (20 + sh) & 1023; gg = w >> (10 + sh) & 1023; bb = w >> sh & 1023;
                if (layout == L_W30R) { q[1] = (uint16_t)lrintf(w30_in(rr) * 65535); q[2] = (uint16_t)lrintf(w30_in(gg) * 65535); q[3] = (uint16_t)lrintf(w30_in(bb) * 65535); }
                else { q[1] = (uint16_t)(rr * 65535u / 1023u); q[2] = (uint16_t)(gg * 65535u / 1023u); q[3] = (uint16_t)(bb * 65535u / 1023u); }
                q[0] = layout == L_L10R ? (uint16_t)((w >> 30) * 65535u / 3u) : 65535;
            }
        }
    }
    return kvImageNoError;
}
static vImage_Error packed_encode(int layout, const vImage_Buffer *argb, const vImage_Buffer *d) {
    for (vImagePixelCount y = 0; y < argb->height; y++) {
        uint8_t *r = vrowm(d, (long)y);
        if (layout <= L_L565) {
            const uint8_t *i = vrow(argb, (long)y);
            for (vImagePixelCount x = 0; x < argb->width; x++) {
                const uint8_t *q = i + 4 * x; unsigned w;
                switch (layout) {
                case L_B555: case L_L555: w = 0x8000u | (unsigned)(q[1] >> 3) << 10 | (unsigned)(q[2] >> 3) << 5 | (unsigned)(q[3] >> 3); break;
                case L_5551: w = (unsigned)(q[1] >> 3) << 11 | (unsigned)(q[2] >> 3) << 6 | (unsigned)(q[3] >> 3) << 1 | (q[0] >= 128); break;
                default: w = (unsigned)(q[1] >> 3) << 11 | (unsigned)(q[2] >> 2) << 5 | (unsigned)(q[3] >> 3); break;
                }
                uint8_t *p = r + 2 * x;
                if (layout == L_B555 || layout == L_B565) { p[0] = (uint8_t)(w >> 8); p[1] = (uint8_t)w; } else { p[0] = (uint8_t)w; p[1] = (uint8_t)(w >> 8); }
            }
        } else {
            const uint16_t *i = (const uint16_t *)vrow(argb, (long)y);
            for (vImagePixelCount x = 0; x < argb->width; x++) {
                const uint16_t *q = i + 4 * x; uint32_t w; unsigned rr, gg, bb;
                if (layout == L_W30R) { rr = w30_out(q[1] / 65535.f); gg = w30_out(q[2] / 65535.f); bb = w30_out(q[3] / 65535.f); }
                else { rr = (q[1] * 1023u + 32767u) / 65535u; gg = (q[2] * 1023u + 32767u) / 65535u; bb = (q[3] * 1023u + 32767u) / 65535u; }
                if (layout == L_R10K) w = rr << 22 | gg << 12 | bb << 2;
                else w = (layout == L_L10R ? (uint32_t)((q[0] * 3u + 32767u) / 65535u) << 30 : 0) | rr << 20 | gg << 10 | bb;
                uint8_t *p = r + 4 * x;
                if (layout == L_R10K) { p[0] = (uint8_t)(w >> 24); p[1] = (uint8_t)(w >> 16); p[2] = (uint8_t)(w >> 8); p[3] = (uint8_t)w; }
                else { p[0] = (uint8_t)w; p[1] = (uint8_t)(w >> 8); p[2] = (uint8_t)(w >> 16); p[3] = (uint8_t)(w >> 24); }
            }
        }
    }
    return kvImageNoError;
}
static vImage_Error decode(const cvconv *c, const vImage_Buffer *s, vImage_Buffer *argb) {
    const uint8_t alpha = 255;
    switch (c->f->layout) {
    case L_420BI: return vImageConvert_420Yp8_CbCr8ToARGB8888(&s[0], &s[1], argb, &c->y2a, NULL, alpha, 0);
    case L_420TRI: return vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(&s[0], &s[1], &s[2], argb, &c->y2a, NULL, alpha, 0);
    case L_422CBY: return vImageConvert_422CbYpCrYp8ToARGB8888(&s[0], argb, &c->y2a, NULL, alpha, 0);
    case L_422YCB: return vImageConvert_422YpCbYpCr8ToARGB8888(&s[0], argb, &c->y2a, NULL, alpha, 0);
    case L_444CRYCB: return vImageConvert_444CrYpCb8ToARGB8888(&s[0], argb, &c->y2a, NULL, alpha, 0);
    case L_444AYCBCR: return vImageConvert_444AYpCbCr8ToARGB8888(&s[0], argb, &c->y2a, NULL, 0);
    case L_444CBYCRA: return vImageConvert_444CbYpCrA8ToARGB8888(&s[0], argb, &c->y2a, NULL, 0);
    case L_V216: return vImageConvert_422CbYpCrYp16ToARGB16U(&s[0], argb, &c->y2a, NULL, 65535, 0);
    case L_Y416: return vImageConvert_444AYpCbCr16ToARGB16U(&s[0], argb, &c->y2a, NULL, 0);
    case L_V410: { vImage_Error e = vImageConvert_444CrYpCb10ToARGB16Q12(&s[0], argb, &c->y2a, NULL, 4096, 0); if (!e) q12_to_16u(argb); return e; }
    case L_V210: { vImage_Error e = vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12(&s[0], argb, &c->y2a, NULL, 4096, 0); if (!e) q12_to_16u(argb); return e; }
    case L_A2VY: return vImageConvert_422CbYpCrYp8_AA8ToARGB8888(&s[0], &s[1], argb, &c->y2a, NULL, 0);
    case L_X420: case L_X422: case L_X444: return x4xx_decode(c, s, argb);
    default: return packed_decode(c->f->layout, &s[0], argb);
    }
    return kvImageUnsupportedConversion;
}
static vImage_Error encode(const cvconv *c, vImage_Buffer *argb, const vImage_Buffer *d) {
    switch (c->f->layout) {
    case L_420BI: return vImageConvert_ARGB8888To420Yp8_CbCr8(argb, &d[0], &d[1], &c->a2y, NULL, 0);
    case L_420TRI: return vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(argb, &d[0], &d[1], &d[2], &c->a2y, NULL, 0);
    case L_422CBY: return vImageConvert_ARGB8888To422CbYpCrYp8(argb, &d[0], &c->a2y, NULL, 0);
    case L_422YCB: return vImageConvert_ARGB8888To422YpCbYpCr8(argb, &d[0], &c->a2y, NULL, 0);
    case L_444CRYCB: return vImageConvert_ARGB8888To444CrYpCb8(argb, &d[0], &c->a2y, NULL, 0);
    case L_444AYCBCR: return vImageConvert_ARGB8888To444AYpCbCr8(argb, &d[0], &c->a2y, NULL, 0);
    case L_444CBYCRA: return vImageConvert_ARGB8888To444CbYpCrA8(argb, &d[0], &c->a2y, NULL, 0);
    case L_V216: return vImageConvert_ARGB16UTo422CbYpCrYp16(argb, &d[0], &c->a2y, NULL, 0);
    case L_Y416: return vImageConvert_ARGB16UTo444AYpCbCr16(argb, &d[0], &c->a2y, NULL, 0);
    case L_V410: u16_to_q12(argb); return vImageConvert_ARGB16Q12To444CrYpCb10(argb, &d[0], &c->a2y, NULL, 0);
    case L_V210: u16_to_q12(argb); return vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(argb, &d[0], &c->a2y, NULL, 0);
    case L_A2VY: return vImageConvert_ARGB8888To422CbYpCrYp8_AA8(argb, &d[0], &d[1], &c->a2y, NULL, 0);
    case L_X420: case L_X422: case L_X444: return x4xx_encode(c, argb, d);
    default: return packed_encode(c->f->layout, argb, &d[0]);
    }
    return kvImageUnsupportedConversion;
}
static vImage_Error cv_run(void *p, const vImage_Buffer *srcs, const vImage_Buffer *dests, vImage_Flags flags) {
    cvconv *c = p;
    if (c->f->kind == K_RGB) return vImageConvert_AnyToAny(c->inner, srcs, dests, NULL, flags);
    const vImage_Buffer *img = c->to_cv ? &srcs[0] : &dests[0];   /* the CG side has the image's size */
    vImage_Buffer mid;
    vImage_Error e = vImageBuffer_Init(&mid, img->height, img->width, c->mid == VT_U8 ? 32 : 64, kvImageNoFlags);
    if (e) return e;
    if (c->to_cv) {
        e = vImageConvert_AnyToAny(c->inner, srcs, &mid, NULL, flags);
        if (!e) e = encode(c, &mid, dests);
    } else {
        e = decode(c, srcs, &mid);
        if (!e) e = vImageConvert_AnyToAny(c->inner, &mid, dests, NULL, flags);
    }
    free(mid.data);
    return e;
}
static vImageConverterRef make_converter(int to_cv, vImageConstCVImageFormatRef cv, const vImage_CGImageFormat *cg, const CGFloat *bg, vImage_Flags flags,
                                         vImage_Error *error) {
    vImage_Error dummy; if (!error) error = &dummy;
    if (!cv || !cg) { *error = kvImageNullPointerArgument; return NULL; }
    const cvfmt *f = cv->f;
    if (!f) { *error = kvImageInvalidImageFormat; return NULL; }
    cvconv *c = calloc(1, sizeof *c);
    if (!c) { *error = kvImageMemoryAllocationError; return NULL; }
    c->to_cv = to_cv; c->f = f; c->mid = f->kind != K_RGB && f->bits > 8 ? VT_U16 : VT_U8;
    vImage_Error e = kvImageNoError;
    vImage_CGImageFormat side = f->kind == K_RGB ? rgb_format(f, cv->space) : mid_format(c->mid, cv->space);
    if (f->kind == K_YCC) e = ycc_info(cv, c);
    if (!e) c->inner = to_cv ? vImageConverter_CreateWithCGImageFormat(cg, &side, bg, flags, &e) : vImageConverter_CreateWithCGImageFormat(&side, cg, bg, flags, &e);
    if (e || !c->inner) { cvconv_free(c); *error = e ? e : kvImageInternalError; return NULL; }
    static const vImageBufferTypeCode cgorder[2] = { kvImageBufferTypeCode_CGFormat, 0 };
    vImageBufferTypeCode cvorder[5] = { 0 };
    for (int i = 0; i < f->nbuf; i++) cvorder[i] = f->order[i];
    vImageConverterRef r = vimage_cv_converter(c, cv_run, cvconv_free, to_cv ? cgorder : cvorder, to_cv ? cvorder : cgorder);
    if (!r) { cvconv_free(c); *error = kvImageMemoryAllocationError; return NULL; }
    *error = kvImageNoError;
    return r;
}
vImageConverterRef vImageConverter_CreateForCGToCVImageFormat(const vImage_CGImageFormat *srcFormat, vImageCVImageFormatRef destFormat,
                                                              const CGFloat *backgroundColor, vImage_Flags flags, vImage_Error *error) {
    return make_converter(1, destFormat, srcFormat, backgroundColor, flags, error);
}
vImageConverterRef vImageConverter_CreateForCVToCGImageFormat(vImageCVImageFormatRef srcFormat, const vImage_CGImageFormat *destFormat,
                                                              const CGFloat *backgroundColor, vImage_Flags flags, vImage_Error *error) {
    return make_converter(0, srcFormat, destFormat, backgroundColor, flags, error);
}

/* ---- buffers over a CVPixelBuffer's planes ---- */
static vImage_Error plane_buffers(vImage_Buffer *buffers, vImageConverterRef converter, CVPixelBufferRef pb, vImage_Flags flags, int from) {
    if (!buffers || !converter || !pb) return kvImageNullPointerArgument;
    if (!cv_load()) return kvImageCoreVideoIsAbsent;
    cvconv *c = vimage_converter_cv(converter);
    if (!c || c->to_cv == from) return kvImageInvalidParameter;
    const cvfmt *f = c->f;
    if (CVPixelBufferGetPixelFormatType(pb) != f->code) return kvImageInvalidImageFormat;
    size_t planes = CVPixelBufferGetPlaneCount(pb);
    if ((int)(planes ? planes : 1) < f->nbuf) return kvImageInvalidImageFormat;
    for (int i = 0; i < f->nbuf; i++) {
        vImage_Buffer b;
        if (planes) {
            b = (vImage_Buffer){ CVPixelBufferGetBaseAddressOfPlane(pb, (size_t)i), CVPixelBufferGetHeightOfPlane(pb, (size_t)i),
                                 CVPixelBufferGetWidthOfPlane(pb, (size_t)i), CVPixelBufferGetBytesPerRowOfPlane(pb, (size_t)i) };
        } else b = (vImage_Buffer){ CVPixelBufferGetBaseAddress(pb), CVPixelBufferGetHeight(pb), CVPixelBufferGetWidth(pb), CVPixelBufferGetBytesPerRow(pb) };
        if (!(flags & kvImageNoAllocate)) {     /* a copy of its own, the same size */
            void *data = malloc(b.rowBytes * b.height);
            if (!data) { while (i-- > 0) free(buffers[i].data); return kvImageMemoryAllocationError; }
            if (from && b.data) memcpy(data, b.data, b.rowBytes * b.height);
            b.data = data;
        }
        buffers[i] = b;
    }
    return kvImageNoError;
}
vImage_Error vImageBuffer_InitForCopyFromCVPixelBuffer(vImage_Buffer *buffers, const vImageConverterRef converter, const CVPixelBufferRef pixelBuffer,
                                                       vImage_Flags flags) {
    return plane_buffers(buffers, converter, pixelBuffer, flags, 1);
}
vImage_Error vImageBuffer_InitForCopyToCVPixelBuffer(vImage_Buffer *buffers, const vImageConverterRef converter, const CVPixelBufferRef pixelBuffer,
                                                     vImage_Flags flags) {
    return plane_buffers(buffers, converter, pixelBuffer, flags, 0);
}
vImage_Error vImageBuffer_InitWithCVPixelBuffer(vImage_Buffer *buffer, vImage_CGImageFormat *desiredFormat, CVPixelBufferRef cvPixelBuffer,
                                                vImageCVImageFormatRef cvImageFormat, const CGFloat *backgroundColor, vImage_Flags flags) {
    if (!buffer || !desiredFormat || !cvPixelBuffer) return kvImageNullPointerArgument;
    if (!cv_load()) return kvImageCoreVideoIsAbsent;
    vImageCVImageFormatRef own = NULL;
    if (!cvImageFormat) { cvImageFormat = own = vImageCVImageFormat_CreateWithCVPixelBuffer(cvPixelBuffer); if (!own) return kvImageInvalidImageFormat; }
    if (!desiredFormat->bitsPerComponent) {    /* an empty format: ARGB, 8 or 16 bits as deep as the pixel buffer, in its colour space */
        const cvfmt *f = cvImageFormat->f;
        int deep = f && ((f->kind == K_YCC && f->bits > 8) || (f->kind == K_RGB && f->bpc > 8));
        *desiredFormat = mid_format(deep ? VT_U16 : VT_U8, cvImageFormat->space);
        if (desiredFormat->colorSpace) CGColorSpaceRetain(desiredFormat->colorSpace);
    }
    vImage_Error e;
    vImageConverterRef conv = vImageConverter_CreateForCVToCGImageFormat(cvImageFormat, desiredFormat, backgroundColor, flags & ~kvImageNoAllocate, &e);
    if (!conv) { if (own) vImageCVImageFormat_Release(own); return e; }
    size_t w = CVPixelBufferGetWidth(cvPixelBuffer), h = CVPixelBufferGetHeight(cvPixelBuffer);
    if (!(flags & kvImageNoAllocate)) {
        e = vImageBuffer_Init(buffer, h, w, desiredFormat->bitsPerPixel, kvImageNoFlags);
        if (e) { vImageConverter_Release(conv); if (own) vImageCVImageFormat_Release(own); return e; }
    } else if (!buffer->data) { vImageConverter_Release(conv); if (own) vImageCVImageFormat_Release(own); return kvImageNullPointerArgument; }
    CVPixelBufferLockBaseAddress(cvPixelBuffer, kCVPixelBufferLock_ReadOnly);
    vImage_Buffer planes[4];
    e = vImageBuffer_InitForCopyFromCVPixelBuffer(planes, conv, cvPixelBuffer, kvImageNoAllocate);
    vImage_Buffer dst = *buffer; dst.width = w; dst.height = h;
    if (!e) e = vImageConvert_AnyToAny(conv, planes, &dst, NULL, flags & ~kvImageNoAllocate);
    CVPixelBufferUnlockBaseAddress(cvPixelBuffer, kCVPixelBufferLock_ReadOnly);
    vImageConverter_Release(conv);
    if (own) vImageCVImageFormat_Release(own);
    return e;
}
vImage_Error vImageBuffer_CopyToCVPixelBuffer(const vImage_Buffer *buffer, const vImage_CGImageFormat *bufferFormat, CVPixelBufferRef cvPixelBuffer,
                                              vImageCVImageFormatRef cvImageFormat, const CGFloat *backgroundColor, vImage_Flags flags) {
    if (!buffer || !bufferFormat || !cvPixelBuffer) return kvImageNullPointerArgument;
    if (!cv_load()) return kvImageCoreVideoIsAbsent;
    vImageCVImageFormatRef own = NULL;
    if (!cvImageFormat) { cvImageFormat = own = vImageCVImageFormat_CreateWithCVPixelBuffer(cvPixelBuffer); if (!own) return kvImageInvalidImageFormat; }
    vImage_Error e;
    vImageConverterRef conv = vImageConverter_CreateForCGToCVImageFormat(bufferFormat, cvImageFormat, backgroundColor, flags, &e);
    if (!conv) { if (own) vImageCVImageFormat_Release(own); return e; }
    CVPixelBufferLockBaseAddress(cvPixelBuffer, 0);
    vImage_Buffer planes[4];
    e = vImageBuffer_InitForCopyToCVPixelBuffer(planes, conv, cvPixelBuffer, kvImageNoAllocate);
    vImage_Buffer src = *buffer;
    src.width = CVPixelBufferGetWidth(cvPixelBuffer); src.height = CVPixelBufferGetHeight(cvPixelBuffer);
    if (!e && (buffer->width < src.width || buffer->height < src.height)) e = kvImageRoiLargerThanInputBuffer;
    if (!e) e = vImageConvert_AnyToAny(conv, &src, planes, NULL, flags);
    CVPixelBufferUnlockBaseAddress(cvPixelBuffer, 0);
    vImageConverter_Release(conv);
    if (own) vImageCVImageFormat_Release(own);
    return e;
}
