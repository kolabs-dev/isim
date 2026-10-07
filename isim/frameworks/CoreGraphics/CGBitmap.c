/* isim CoreGraphics: bitmap contexts (cairo surfaces over app memory, y-up like Core Graphics), PDF contexts
 * (cairo PDF surfaces) and PDF documents (host poppler-glib when installed). */
#include "cg_context.h"
#include <stdio.h>

const char *isim_cg_url_path(CFURLRef url);

/* ---------------- bitmap contexts ---------------- */
static CGContextRef bitmap_create(void *data, size_t w, size_t h, size_t bpc, size_t bpr, CGColorSpaceRef space, uint32_t info,
                                  CGBitmapContextReleaseDataCallback cb, void *cbinfo) {
    size_t ncomp = space ? space->ncomp : 0;
    int alpha = info & kCGBitmapAlphaInfoMask;
    if (!space && alpha != kCGImageAlphaOnly) { fprintf(stderr, "isim: CGBitmapContextCreate: a color space is required\n"); return NULL; }
    if (alpha == kCGImageAlphaOnly) ncomp = 0;
    /* the combinations iOS supports for 8 bits per component */
    size_t bpp = alpha == kCGImageAlphaOnly ? 8 : ncomp == 1 ? 8 : ncomp == 3 ? 32 : 0;
    int ok = bpc == 8 && bpp && w && h &&
             (alpha == kCGImageAlphaOnly || (ncomp == 1 && alpha == kCGImageAlphaNone) ||
              (ncomp == 3 && (alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaPremultipliedLast ||
                              alpha == kCGImageAlphaNoneSkipFirst || alpha == kCGImageAlphaNoneSkipLast)));
    int fmt = 0, B = 0;
    if (ok) ok = isim_cg_pixfmt(info, bpc, bpp, ncomp ? ncomp : 1, 0, &fmt, &B);
    if (!ok) {
        fprintf(stderr, "isim: CGBitmapContextCreate: unsupported parameter combination: %zu bits/component; %zu components; info 0x%x"
                        " (isim supports 8-bit RGB with premultiplied or skipped alpha, 8-bit gray and alpha-only)\n", bpc, ncomp, info);
        return NULL;
    }
    if (!bpr) bpr = w * (size_t)B;
    if (bpr < w * (size_t)B) { fprintf(stderr, "isim: CGBitmapContextCreate: invalid data bytes/row: should be at least %zu\n", w * (size_t)B); return NULL; }
    struct CGContext *x = isim_cg_ctx_new(CTX_BITMAP);
    if (!data) { data = calloc(bpr, h); x->owns = 1; }
    x->target = isim_cg_bitmap_create(data, (int)w, (int)h, (int)bpr, fmt, B);
    if (!x->target) { if (x->owns) free(data); x->owns = 0; objc_release(x); return NULL; }
    x->data = data; x->w = w; x->h = h; x->bpc = bpc; x->bpp = bpp; x->bpr = bpr; x->info = info;
    x->cs = space ? objc_retain(space) : NULL; x->releaseCb = cb; x->releaseInfo = cbinfo;
    /* Core Graphics' bitmap space is y-up with the origin at the bottom left */
    isim_cg_target_bind(x->target);
    isim_gfx_translate(0, (double)h); isim_gfx_scale(1, -1);
    isim_cg_target_unbind(x->target);
    return x;
}
CGContextRef CGBitmapContextCreate(void *data, size_t w, size_t h, size_t bpc, size_t bpr, CGColorSpaceRef space, uint32_t info) {
    return bitmap_create(data, w, h, bpc, bpr, space, info, NULL, NULL);
}
CGContextRef CGBitmapContextCreateWithData(void *data, size_t w, size_t h, size_t bpc, size_t bpr, CGColorSpaceRef space, uint32_t info,
                                           CGBitmapContextReleaseDataCallback cb, void *cbinfo) {
    return bitmap_create(data, w, h, bpc, bpr, space, info, cb, cbinfo);
}
static struct CGContext *bm(CGContextRef c) { return c && c->kind == CTX_BITMAP ? c : NULL; }
void *CGBitmapContextGetData(CGContextRef c) { return bm(c) ? c->data : NULL; }
size_t CGBitmapContextGetWidth(CGContextRef c) { return bm(c) ? c->w : 0; }
size_t CGBitmapContextGetHeight(CGContextRef c) { return bm(c) ? c->h : 0; }
size_t CGBitmapContextGetBitsPerComponent(CGContextRef c) { return bm(c) ? c->bpc : 0; }
size_t CGBitmapContextGetBitsPerPixel(CGContextRef c) { return bm(c) ? c->bpp : 0; }
size_t CGBitmapContextGetBytesPerRow(CGContextRef c) { return bm(c) ? c->bpr : 0; }
CGColorSpaceRef CGBitmapContextGetColorSpace(CGContextRef c) { return bm(c) ? c->cs : NULL; }
CGImageAlphaInfo CGBitmapContextGetAlphaInfo(CGContextRef c) { return bm(c) ? (CGImageAlphaInfo)(c->info & kCGBitmapAlphaInfoMask) : kCGImageAlphaNone; }
CGBitmapInfo CGBitmapContextGetBitmapInfo(CGContextRef c) { return bm(c) ? c->info : 0; }
CGImageRef CGBitmapContextCreateImage(CGContextRef c) {
    if (!bm(c)) return NULL;
    int hd = isim_cg_target_image(c->target);
    CGImageRef im = isim_cg_image_adopt(hd);
    if (!im) return NULL;
    /* report the context's layout; the provider's bytes are made from the copy on demand */
    struct imgext *e = isim_cg_image_ext(im);
    e->bpc = c->bpc; e->bpp = c->bpp; e->bpr = c->bpr; e->info = c->info; e->interp = true;
    if (e->cs) objc_release(e->cs);
    e->cs = c->cs ? objc_retain(c->cs) : NULL;
    return im;
}

/* ---------------- PDF contexts ---------------- */
const CFStringRef kCGPDFContextMediaBox = CFSTR("MediaBox");
const CFStringRef kCGPDFContextTitle = CFSTR("kCGPDFContextTitle");
const CFStringRef kCGPDFContextAuthor = CFSTR("kCGPDFContextAuthor");
const CFStringRef kCGPDFContextCreator = CFSTR("kCGPDFContextCreator");
static CGContextRef pdf_create(CGDataConsumerRef consumer, const char *path, const CGRect *box) {
    CGRect mb = box ? *box : CGRectMake(0, 0, 612, 792);
    struct CGContext *x = isim_cg_ctx_new(CTX_PDF);
    x->target = isim_cg_pdf_create(path, mb.size.width, mb.size.height);
    if (!x->target) { objc_release(x); return NULL; }
    x->consumer = consumer ? objc_retain(consumer) : NULL; x->mediaBox = mb;
    return x;
}
CGContextRef CGPDFContextCreate(CGDataConsumerRef consumer, const CGRect *box, CFDictionaryRef aux) {
    if (!consumer) return NULL;
    return pdf_create(consumer, isim_cg_consumer_path(consumer), box);
}
CGContextRef CGPDFContextCreateWithURL(CFURLRef url, const CGRect *box, CFDictionaryRef aux) {
    const char *p = isim_cg_url_path(url);
    return p ? pdf_create(NULL, p, box) : NULL;
}
static void begin_page(struct CGContext *x, CGRect mb) {
    if (x->pageOpen) CGPDFContextEndPage(x);
    isim_cg_pdf_begin_page(x->target, mb.size.width, mb.size.height);
    while (x->depth > 0) CGContextRestoreGState(x);       /* a new page starts from a fresh graphics state */
    isim_cg_gstate_reset(&x->gs[0]);
    isim_cg_target_bind(x->target);
    isim_gfx_translate(-mb.origin.x, mb.size.height + mb.origin.y); isim_gfx_scale(1, -1);       /* PDF space is y-up */
    isim_cg_target_unbind(x->target);
    x->pageOpen = 1;
}
void CGPDFContextBeginPage(CGContextRef c, CFDictionaryRef info) {
    if (!c || c->kind != CTX_PDF) return;
    CGRect mb = c->mediaBox;
    if (info) {
        CFDataRef d = (CFDataRef)CFDictionaryGetValue(info, kCGPDFContextMediaBox);
        if (d && (size_t)CFDataGetLength(d) >= sizeof(CGRect)) memcpy(&mb, CFDataGetBytePtr(d), sizeof mb);
    }
    begin_page(c, mb);
}
void CGContextBeginPage(CGContextRef c, const CGRect *box) { if (c && c->kind == CTX_PDF) begin_page(c, box ? *box : c->mediaBox); }
void CGPDFContextEndPage(CGContextRef c) {
    if (!c || c->kind != CTX_PDF || !c->pageOpen) return;
    isim_cg_pdf_end_page(c->target); c->pageOpen = 0;
}
void CGContextEndPage(CGContextRef c) { CGPDFContextEndPage(c); }
void CGPDFContextClose(CGContextRef c) {
    if (!c || c->kind != CTX_PDF || !c->target) return;
    unsigned char *bytes = NULL;
    long n = isim_cg_pdf_finish(c->target, &bytes);
    if (n > 0 && c->consumer && !isim_cg_consumer_path(c->consumer)) isim_cg_consumer_put(c->consumer, bytes, (size_t)n);
    isim_image_bytes_free(bytes);
    isim_cg_target_free(c->target); c->target = NULL;
}

/* ---------------- PDF documents ---------------- */
CFTypeID CGPDFDocumentGetTypeID(void) { return 0x4370; }
CFTypeID CGPDFPageGetTypeID(void) { return 0x4371; }
static void doc_fin(void *o) {
    struct CGPDFDocument *d = o;
    if (d->cache) { for (int i = 0; i < d->pages; i++) if (d->cache[i]) objc_release(d->cache[i]); free(d->cache); }
    isim_pdf_close(d->doc);
    if (d->data) CFRelease(d->data);
}
CGPDFDocumentRef CGPDFDocumentCreateWithProvider(CGDataProviderRef p) {
    CFDataRef data = CGDataProviderCopyData(p);
    if (!data) return NULL;
    int pages = 0;
    void *doc = isim_pdf_open(CFDataGetBytePtr(data), CFDataGetLength(data), &pages);
    if (!doc) {
        if (!isim_pdf_available()) fprintf(stderr, "isim: CGPDFDocument: reading PDFs needs the host's poppler-glib (libpoppler-glib.so.8)\n");
        CFRelease(data); return NULL;
    }
    struct CGPDFDocument *d = isim_cg_obj_new("CGPDFDocument", sizeof *d, doc_fin);
    d->doc = doc; d->pages = pages; d->data = data; d->cache = calloc((size_t)(pages > 0 ? pages : 1), sizeof *d->cache);
    return d;
}
CGPDFDocumentRef CGPDFDocumentCreateWithURL(CFURLRef url) {
    CGDataProviderRef p = CGDataProviderCreateWithURL(url);
    if (!p) return NULL;
    CGPDFDocumentRef d = CGPDFDocumentCreateWithProvider(p);
    objc_release(p);
    return d;
}
CGPDFDocumentRef CGPDFDocumentRetain(CGPDFDocumentRef d) { return d ? objc_retain(d) : NULL; }
void CGPDFDocumentRelease(CGPDFDocumentRef d) { if (d) objc_release(d); }
size_t CGPDFDocumentGetNumberOfPages(CGPDFDocumentRef d) { return d ? (size_t)d->pages : 0; }
bool CGPDFDocumentIsEncrypted(CGPDFDocumentRef d) { return false; }
bool CGPDFDocumentIsUnlocked(CGPDFDocumentRef d) { return true; }
CGPDFPageRef CGPDFDocumentGetPage(CGPDFDocumentRef d, size_t n) {
    if (!d || n < 1 || n > (size_t)d->pages) return NULL;
    if (!d->cache[n - 1]) {
        struct CGPDFPage *p = isim_cg_obj_new("CGPDFPage", sizeof *p, NULL);
        p->doc = d; p->index = (int)n - 1;
        isim_pdf_page_size(d->doc, p->index, &p->w, &p->h);
        d->cache[n - 1] = p;
    }
    return d->cache[n - 1];
}
CGPDFPageRef CGPDFPageRetain(CGPDFPageRef p) { return p ? objc_retain(p) : NULL; }
void CGPDFPageRelease(CGPDFPageRef p) { if (p) objc_release(p); }
CGPDFDocumentRef CGPDFPageGetDocument(CGPDFPageRef p) { return p ? p->doc : NULL; }
size_t CGPDFPageGetPageNumber(CGPDFPageRef p) { return p ? (size_t)p->index + 1 : 0; }
CGRect CGPDFPageGetBoxRect(CGPDFPageRef p, CGPDFBox box) { return p ? CGRectMake(0, 0, p->w, p->h) : CGRectZero; }
int CGPDFPageGetRotationAngle(CGPDFPageRef p) { return 0; }
CGAffineTransform CGPDFPageGetDrawingTransform(CGPDFPageRef p, CGPDFBox box, CGRect rect, int rotate, bool keep) {
    if (!p || p->w <= 0 || p->h <= 0) return CGAffineTransformIdentity;
    double sx = rect.size.width / p->w, sy = rect.size.height / p->h;
    if (keep) sx = sy = fmin(fmin(sx, sy), 1);      /* Core Graphics only scales PDF pages down */
    double tx = rect.origin.x + (rect.size.width - p->w * sx) / 2, ty = rect.origin.y + (rect.size.height - p->h * sy) / 2;
    return CGAffineTransformMake(sx, 0, 0, sy, tx, ty);
}
void CGContextDrawPDFPage(CGContextRef c, CGPDFPageRef p) {
    if (!p) return;
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    if (x->target) isim_cg_target_bind(x->target);
    isim_gfx_save();
    isim_gfx_translate(0, p->h); isim_gfx_scale(1, -1);       /* poppler renders y-down from the page's top */
    isim_pdf_page_render(p->doc->doc, p->index);
    isim_gfx_restore();
    if (x->target) isim_cg_target_unbind(x->target);
}
