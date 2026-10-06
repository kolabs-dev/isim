/* isim CoreGraphics: CGImage. An image is a host image handle + a pixel rect (crops share the handle); images made
 * from bytes also keep their layout (bits per component/pixel, bitmap info, color space, provider). Decoded images
 * report 8-bit premultiplied RGBA and synthesize their provider's bytes from the host pixels on demand. */
#include "cg_internal.h"
#include <stdio.h>

CFTypeID CGImageGetTypeID(void) { return 0x4369; }
struct handle_owner { struct cgobj hdr; int handle; };
static void handle_fin(void *o) { struct handle_owner *h = o; if (h->handle) isim_image_free(h->handle); }
CGImageRef isim_cg_image_create(int handle, CGRect r, void *owner) {
    static Class k; if (!k) k = objc_getClass("__NSCGImage");
    if (!k || !handle) return NULL;
    struct CGImage *im = class_createInstance(k, 0);
    im->handle = handle; im->x = r.origin.x; im->y = r.origin.y; im->w = r.size.width; im->h = r.size.height;
    im->owner = owner ? objc_retain(owner) : NULL;
    im->ext = NULL;
    return im;
}
CGImageRef isim_cg_image_adopt(int handle) {
    if (!handle) return NULL;
    struct handle_owner *o = isim_cg_obj_new("CGImageStorage", sizeof *o, handle_fin);
    o->handle = handle;
    double w, h; isim_image_pixel_size(handle, &w, &h);
    CGImageRef im = isim_cg_image_create(handle, CGRectMake(0, 0, w, h), o);
    objc_release(o);
    return im;
}
CGImageRef isim_cg_image_with_handle(int handle) { return isim_cg_image_adopt(handle); }
int isim_cg_image_handle(CGImageRef im, CGRect *r) {
    if (!im) return 0;
    if (r) *r = CGRectMake(im->x, im->y, im->w, im->h);
    return im->handle;
}
static void ext_fin(void *o) {
    struct imgext *e = o;
    if (e->cs) objc_release(e->cs);
    if (e->prov) objc_release(e->prov);
    if (e->ut) CFRelease(e->ut);
}
static struct imgext *ext_of(CGImageRef im) {
    if (!im->ext) {
        struct imgext *e = isim_cg_obj_new("CGImageInfo", sizeof *e, ext_fin);
        e->bpc = 8; e->bpp = 32; e->bpr = (size_t)im->w * 4; e->info = kCGImageAlphaPremultipliedLast; e->interp = true;
        e->cs = objc_retain(isim_cg_space(CS_SRGB));
        im->ext = e;
    }
    return im->ext;
}
struct imgext *isim_cg_image_ext(CGImageRef im) { return ext_of(im); }
void isim_cg_image_set_uttype(CGImageRef im, CFStringRef t) {
    if (!im) return;
    struct imgext *e = ext_of(im);
    if (e->ut) CFRelease(e->ut);
    e->ut = t ? CFRetain(t) : NULL;
}
size_t CGImageGetWidth(CGImageRef im) { return im ? (size_t)im->w : 0; }
size_t CGImageGetHeight(CGImageRef im) { return im ? (size_t)im->h : 0; }
CGImageRef CGImageRetain(CGImageRef im) { if (im) objc_retain(im); return im; }
void CGImageRelease(CGImageRef im) { if (im) objc_release(im); }

/* Core Graphics layouts -> host pixel formats (8 bits per component) */
int isim_cg_pixfmt(CGBitmapInfo info, size_t bpc, size_t bpp, size_t ncomp, int mask, int *fmt, int *bytes) {
    if (bpc != 8 || bpp % 8) return 0;
    int B = (int)(bpp / 8), alpha = info & kCGBitmapAlphaInfoMask, order = info & kCGBitmapByteOrderMask;
    if (info & kCGBitmapFloatComponents) return 0;
    *bytes = B;
    if (mask) { if (B != 1) return 0; *fmt = ISIM_PX(0, 7, 7, 7) | ISIM_PX_GRAY | ISIM_PX_INVERT; return 1; }
    if (alpha == kCGImageAlphaOnly) { if (B != 1) return 0; *fmt = ISIM_PX(7, 7, 7, 0) | ISIM_PX_ALPHAONLY; return 1; }
    int premul = alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaPremultipliedLast ? ISIM_PX_PREMUL : 0;
    int skip = alpha == kCGImageAlphaNoneSkipFirst || alpha == kCGImageAlphaNoneSkipLast ? ISIM_PX_SKIPALPHA : 0;
    int first = alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaFirst || alpha == kCGImageAlphaNoneSkipFirst;
    int has_a = alpha != kCGImageAlphaNone;
    if (ncomp == 1) {
        if (B == 1 && !has_a) { *fmt = ISIM_PX(0, 7, 7, 7) | ISIM_PX_GRAY; return 1; }
        if (B == 2 && has_a) { int g = first ? 1 : 0, a = first ? 0 : 1; if (order == kCGBitmapByteOrder16Little) { g = 1 - g; a = 1 - a; }
                               *fmt = ISIM_PX(g, 7, 7, a) | ISIM_PX_GRAY | premul | skip; return 1; }
        return 0;
    }
    if (ncomp != 3) return 0;
    if (B == 3 && !has_a) { *fmt = ISIM_PX(0, 1, 2, 7); return 1; }
    if (B != 4 || !has_a) return 0;
    int r = first ? 1 : 0, a = first ? 0 : 3;
    int pos[4] = { r, r + 1, r + 2, a };
    if (order == kCGBitmapByteOrder32Little) for (int i = 0; i < 4; i++) pos[i] = 3 - pos[i];
    *fmt = ISIM_PX(pos[0], pos[1], pos[2], pos[3]) | premul | skip;
    return 1;
}

static CGImageRef create(size_t w, size_t h, size_t bpc, size_t bpp, size_t bpr, CGColorSpaceRef space, CGBitmapInfo info,
                         CGDataProviderRef prov, const CGFloat *decode, bool interp, CGColorRenderingIntent intent, int mask) {
    if (!prov || !w || !h) return NULL;
    size_t ncomp = mask ? 1 : space ? space->ncomp : 3;
    int fmt, B;
    if (!isim_cg_pixfmt(info, bpc, bpp, ncomp, mask, &fmt, &B)) {
        fprintf(stderr, "isim: CGImageCreate: unsupported layout (%zu bpc, %zu bpp, info 0x%x); isim supports 8 bits per component\n", bpc, bpp, info);
        return NULL;
    }
    size_t size; const unsigned char *bytes = isim_cg_provider_bytes(prov, &size);
    if (!bytes || size < bpr * (h - 1) + w * (size_t)B) return NULL;
    const unsigned char *src = bytes; unsigned char *tmp = NULL;
    if (decode && !mask) {                         /* decode arrays remap each component range */
        tmp = malloc(bpr * h); memcpy(tmp, bytes, bpr * h); src = tmp;
        int offs[4] = { fmt & 7, fmt >> 3 & 7, fmt >> 6 & 7, fmt >> 9 & 7 };
        for (size_t y = 0; y < h; y++) for (size_t x = 0; x < w; x++) for (size_t k = 0; k < ncomp; k++) {
            int o = offs[(fmt & ISIM_PX_GRAY) ? 0 : k]; if (o == 7) continue;
            unsigned char *p = tmp + y * bpr + x * (size_t)B + o;
            double v = decode[2 * k] + (decode[2 * k + 1] - decode[2 * k]) * (*p / 255.0);
            *p = (unsigned char)lround(fmax(0, fmin(1, v)) * 255);
        }
    }
    if (mask && decode && decode[0] > decode[1]) fmt &= ~ISIM_PX_INVERT;
    int hd = isim_image_from_pixels(src, (int)w, (int)h, (int)bpr, fmt, B);
    free(tmp);
    CGImageRef im = isim_cg_image_adopt(hd);
    if (!im) return NULL;
    struct imgext *e = ext_of(im);
    e->bpc = bpc; e->bpp = bpp; e->bpr = bpr; e->info = info; e->mask = mask; e->interp = interp; e->intent = intent;
    objc_release(e->cs); e->cs = mask ? NULL : space ? objc_retain(space) : objc_retain(isim_cg_space(CS_SRGB));
    e->prov = objc_retain(prov);
    if (decode) { e->ndecode = (int)(2 * ncomp > 8 ? 8 : 2 * ncomp); memcpy(e->decode, decode, sizeof(CGFloat) * e->ndecode); }
    return im;
}
CGImageRef CGImageCreate(size_t w, size_t h, size_t bpc, size_t bpp, size_t bpr, CGColorSpaceRef space, CGBitmapInfo info,
                         CGDataProviderRef prov, const CGFloat *decode, bool interp, CGColorRenderingIntent intent) {
    return create(w, h, bpc, bpp, bpr, space, info, prov, decode, interp, intent, 0);
}
CGImageRef CGImageMaskCreate(size_t w, size_t h, size_t bpc, size_t bpp, size_t bpr, CGDataProviderRef prov, const CGFloat *decode, bool interp) {
    return create(w, h, bpc, bpp, bpr, NULL, (CGBitmapInfo)kCGImageAlphaNone, prov, decode, interp, kCGRenderingIntentDefault, 1);
}
static CGImageRef from_encoded(CGDataProviderRef src, CFStringRef ut) {
    size_t n; const void *b = isim_cg_provider_bytes(src, &n);
    if (!b || !n) return NULL;
    double w, h; int hd = isim_image_load_data(b, n, &w, &h);
    CGImageRef im = isim_cg_image_adopt(hd);
    if (im) isim_cg_image_set_uttype(im, ut);
    return im;
}
CGImageRef CGImageCreateWithPNGDataProvider(CGDataProviderRef s, const CGFloat *d, bool i, CGColorRenderingIntent n) { return from_encoded(s, CFSTR("public.png")); }
CGImageRef CGImageCreateWithJPEGDataProvider(CGDataProviderRef s, const CGFloat *d, bool i, CGColorRenderingIntent n) { return from_encoded(s, CFSTR("public.jpeg")); }
CGImageRef CGImageCreateCopy(CGImageRef im) { return im ? objc_retain(im) : NULL; }   /* images are immutable */
CGImageRef CGImageCreateCopyWithColorSpace(CGImageRef im, CGColorSpaceRef space) {
    if (!im || !space || space->ncomp != (im->ext && im->ext->cs ? im->ext->cs->ncomp : 3)) return NULL;
    CGImageRef c = isim_cg_image_create(im->handle, CGRectMake(im->x, im->y, im->w, im->h), im->owner ? im->owner : (void *)im);
    struct imgext *e = ext_of(c), *o = im->ext;
    if (o) { e->bpc = o->bpc; e->bpp = o->bpp; e->bpr = o->bpr; e->info = o->info; e->prov = o->prov ? objc_retain(o->prov) : NULL; }
    objc_release(e->cs); e->cs = objc_retain(space);
    return c;
}
CGImageRef CGImageCreateWithImageInRect(CGImageRef im, CGRect r) {
    if (!im) return NULL;
    r = CGRectIntegral(CGRectIntersection(CGRectStandardize(r), CGRectMake(0, 0, im->w, im->h)));
    if (CGRectIsNull(r) || CGRectIsEmpty(r)) return NULL;
    r.origin.x += im->x; r.origin.y += im->y;
    CGImageRef c = isim_cg_image_create(im->handle, r, im->owner ? im->owner : (void *)im);
    if (im->ext) {                                   /* same layout, rows of the crop's width; bytes made on demand */
        struct imgext *e = ext_of(c), *o = im->ext;
        e->bpc = o->bpc; e->bpp = o->bpp; e->bpr = (size_t)r.size.width * (o->bpp / 8); e->info = o->info; e->mask = o->mask; e->interp = o->interp;
        objc_release(e->cs); e->cs = o->cs ? objc_retain(o->cs) : NULL;
    }
    return c;
}
unsigned char *isim_cg_image_rgba(CGImageRef im, size_t *w, size_t *h) {
    *w = im ? (size_t)im->w : 0; *h = im ? (size_t)im->h : 0;
    if (!im || !*w || !*h) return NULL;
    unsigned char *px = malloc(*w * *h * 4);
    isim_image_read_pixels(im->handle, (int)im->x, (int)im->y, (int)*w, (int)*h, px, (int)*w * 4, ISIM_PX_RGBA_PREMUL, 4);
    return px;
}
CGImageRef CGImageCreateWithMask(CGImageRef im, CGImageRef mask) {
    if (!im || !mask) return NULL;
    size_t w, h, mw, mh;
    unsigned char *px = isim_cg_image_rgba(im, &w, &h), *mp = isim_cg_image_rgba(mask, &mw, &mh);
    if (!px || !mp) { free(px); free(mp); return NULL; }
    int alpha_mask = mask->ext && mask->ext->mask;
    for (size_t y = 0; y < h; y++) for (size_t x = 0; x < w; x++) {
        size_t mx = x * mw / w, my = y * mh / h; const unsigned char *m = mp + (my * mw + mx) * 4;
        /* image masks: their alpha; other masks: the sample (luminance) is the amount painted */
        unsigned cov = alpha_mask ? m[3] : (unsigned)lround(0.299 * m[0] + 0.587 * m[1] + 0.114 * m[2]);
        unsigned char *p = px + (y * w + x) * 4;
        for (int k = 0; k < 4; k++) p[k] = (unsigned char)(p[k] * cov / 255);
    }
    int hd = isim_image_from_pixels(px, (int)w, (int)h, (int)w * 4, ISIM_PX_RGBA_PREMUL, 4);
    free(px); free(mp);
    return isim_cg_image_adopt(hd);
}
bool CGImageIsMask(CGImageRef im) { return im && im->ext && im->ext->mask; }
size_t CGImageGetBitsPerComponent(CGImageRef im) { return im ? ext_of(im)->bpc : 0; }
size_t CGImageGetBitsPerPixel(CGImageRef im) { return im ? ext_of(im)->bpp : 0; }
size_t CGImageGetBytesPerRow(CGImageRef im) { return im ? ext_of(im)->bpr : 0; }
CGColorSpaceRef CGImageGetColorSpace(CGImageRef im) { return im ? ext_of(im)->cs : NULL; }
CGImageAlphaInfo CGImageGetAlphaInfo(CGImageRef im) { return im ? (CGImageAlphaInfo)(ext_of(im)->info & kCGBitmapAlphaInfoMask) : kCGImageAlphaNone; }
CGBitmapInfo CGImageGetBitmapInfo(CGImageRef im) { return im ? ext_of(im)->info : 0; }
CGImageByteOrderInfo CGImageGetByteOrderInfo(CGImageRef im) { return im ? (CGImageByteOrderInfo)(ext_of(im)->info & kCGBitmapByteOrderMask) : 0; }
CGImagePixelFormatInfo CGImageGetPixelFormatInfo(CGImageRef im) { return kCGImagePixelFormatPacked; }
const CGFloat *CGImageGetDecode(CGImageRef im) { return im && im->ext && im->ext->ndecode ? im->ext->decode : NULL; }
bool CGImageGetShouldInterpolate(CGImageRef im) { return im ? ext_of(im)->interp : false; }
CGColorRenderingIntent CGImageGetRenderingIntent(CGImageRef im) { return im ? ext_of(im)->intent : 0; }
CFStringRef CGImageGetUTType(CGImageRef im) { return im && im->ext ? im->ext->ut : NULL; }
CGDataProviderRef CGImageGetDataProvider(CGImageRef im) {
    if (!im) return NULL;
    struct imgext *e = ext_of(im);
    if (e->prov) return e->prov;
    /* bytes in the image's layout from the host pixels */
    int fmt, B;
    size_t ncomp = e->mask ? 1 : e->cs ? e->cs->ncomp : 3;
    if (!isim_cg_pixfmt(e->info, e->bpc, e->bpp, ncomp, e->mask, &fmt, &B)) { fmt = ISIM_PX_RGBA_PREMUL; B = 4; }
    size_t w = (size_t)im->w, h = (size_t)im->h, bpr = e->bpr ? e->bpr : w * (size_t)B;
    unsigned char *buf = calloc(bpr * h, 1);
    if (e->mask) fmt = ISIM_PX(7, 7, 7, 0) | ISIM_PX_ALPHAONLY;      /* masks: sample = 255 - coverage */
    isim_image_read_pixels(im->handle, (int)im->x, (int)im->y, (int)w, (int)h, buf, (int)bpr, fmt, B);
    if (e->mask) for (size_t i = 0; i < bpr * h; i++) buf[i] = 255 - buf[i];
    CFDataRef d = CFDataCreate(NULL, buf, (CFIndex)(bpr * h));
    free(buf);
    e->prov = CGDataProviderCreateWithCFData(d);
    CFRelease(d);
    return e->prov;
}
