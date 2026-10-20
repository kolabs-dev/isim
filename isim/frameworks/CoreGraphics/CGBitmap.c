/* isim CoreGraphics: bitmap contexts (cairo surfaces over app memory, y-up like Core Graphics), PDF contexts
 * (cairo PDF surfaces: links, destinations, outline and information through cairo's tags) and PDF documents (isim's
 * parser for the objects, the host's poppler-glib for drawing pages). */
#include "cg_context.h"
#include "cg_pdf.h"
#include <CoreFoundation/CoreFoundation.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
const CFStringRef kCGPDFContextCropBox = CFSTR("CropBox");
const CFStringRef kCGPDFContextBleedBox = CFSTR("BleedBox");
const CFStringRef kCGPDFContextTrimBox = CFSTR("TrimBox");
const CFStringRef kCGPDFContextArtBox = CFSTR("ArtBox");
const CFStringRef kCGPDFContextTitle = CFSTR("kCGPDFContextTitle");
const CFStringRef kCGPDFContextAuthor = CFSTR("kCGPDFContextAuthor");
const CFStringRef kCGPDFContextCreator = CFSTR("kCGPDFContextCreator");
const CFStringRef kCGPDFContextSubject = CFSTR("kCGPDFContextSubject");
const CFStringRef kCGPDFContextKeywords = CFSTR("kCGPDFContextKeywords");
const CFStringRef kCGPDFContextOwnerPassword = CFSTR("kCGPDFContextOwnerPassword");
const CFStringRef kCGPDFContextUserPassword = CFSTR("kCGPDFContextUserPassword");
const CFStringRef kCGPDFContextEncryptionKeyLength = CFSTR("kCGPDFContextEncryptionKeyLength");
const CFStringRef kCGPDFContextAllowsPrinting = CFSTR("kCGPDFContextAllowsPrinting");
const CFStringRef kCGPDFContextAllowsCopying = CFSTR("kCGPDFContextAllowsCopying");
const CFStringRef kCGPDFContextAccessPermissions = CFSTR("kCGPDFContextAccessPermissions");
const CFStringRef kCGPDFContextOutputIntent = CFSTR("kCGPDFContextOutputIntent");
const CFStringRef kCGPDFContextOutputIntents = CFSTR("kCGPDFContextOutputIntents");
const CFStringRef kCGPDFContextCreateLinearizedPDF = CFSTR("kCGPDFContextCreateLinearizedPDF");
const CFStringRef kCGPDFContextCreatePDFA = CFSTR("kCGPDFContextCreatePDFA");
const CFStringRef kCGPDFXOutputIntentSubtype = CFSTR("GTS_PDFX");
const CFStringRef kCGPDFXOutputConditionIdentifier = CFSTR("OutputConditionIdentifier");
const CFStringRef kCGPDFXOutputCondition = CFSTR("OutputCondition");
const CFStringRef kCGPDFXRegistryName = CFSTR("RegistryName");
const CFStringRef kCGPDFXInfo = CFSTR("Info");
const CFStringRef kCGPDFXDestinationOutputProfile = CFSTR("DestOutputProfile");
const CFStringRef kCGPDFOutlineTitle = CFSTR("Title");
const CFStringRef kCGPDFOutlineChildren = CFSTR("Children");
const CFStringRef kCGPDFOutlineDestination = CFSTR("Destination");
const CFStringRef kCGPDFOutlineDestinationRect = CFSTR("DestinationRect");

/* a CFString as UTF-8 (malloc'd); NULL for anything else */
static char *utf8(CFTypeRef v) {
    if (!v || CFGetTypeID(v) != CFStringGetTypeID()) return NULL;
    CFIndex n = CFStringGetMaximumSizeForEncoding(CFStringGetLength((CFStringRef)v), kCFStringEncodingUTF8) + 1;
    char *s = malloc((size_t)n);
    if (!CFStringGetCString((CFStringRef)v, s, n, kCFStringEncodingUTF8)) { free(s); return NULL; }
    return s;
}
/* a cairo attribute string value: quotes and backslashes escaped */
static char *quoted(const char *v) {
    size_t n = strlen(v);
    char *q = malloc(2 * n + 1), *o = q;
    for (; *v; v++) { if (*v == '\'' || *v == '\\') *o++ = '\\'; *o++ = *v; }
    *o = 0;
    return q;
}
static CGContextRef pdf_create(CGDataConsumerRef consumer, const char *path, const CGRect *box, CFDictionaryRef aux) {
    CGRect mb = box ? *box : CGRectMake(0, 0, 612, 792);
    struct CGContext *x = isim_cg_ctx_new(CTX_PDF);
    x->target = isim_cg_pdf_create(path, mb.size.width, mb.size.height);
    if (!x->target) { objc_release(x); return NULL; }
    x->consumer = consumer ? objc_retain(consumer) : NULL; x->mediaBox = mb; x->pageBox = mb;
    const CFStringRef keys[] = { kCGPDFContextTitle, kCGPDFContextAuthor, kCGPDFContextSubject, kCGPDFContextKeywords, kCGPDFContextCreator };
    for (int k = 0; aux && k < 5; k++) {
        CFTypeRef v = CFDictionaryGetValue(aux, keys[k]);
        if (k == 3 && v && CFGetTypeID(v) == CFArrayGetTypeID()) {       /* keywords may be an array of strings */
            size_t cap = 1; char *all = calloc(1, 1);
            for (CFIndex i = 0; i < CFArrayGetCount(v); i++) {
                char *w = utf8(CFArrayGetValueAtIndex(v, i));
                if (!w) continue;
                cap += strlen(w) + 2; all = realloc(all, cap);
                if (*all) strcat(all, ", ");
                strcat(all, w); free(w);
            }
            isim_cg_pdf_metadata(x->target, k, all); free(all);
            continue;
        }
        char *s = utf8(v);
        if (s) { isim_cg_pdf_metadata(x->target, k, s); free(s); }
    }
    return x;
}
CGContextRef CGPDFContextCreate(CGDataConsumerRef consumer, const CGRect *box, CFDictionaryRef aux) {
    if (!consumer) return NULL;
    return pdf_create(consumer, isim_cg_consumer_path(consumer), box, aux);
}
CGContextRef CGPDFContextCreateWithURL(CFURLRef url, const CGRect *box, CFDictionaryRef aux) {
    const char *p = isim_cg_url_path(url);
    return p ? pdf_create(NULL, p, box, aux) : NULL;
}
static void begin_page(struct CGContext *x, CGRect mb) {
    if (x->pageOpen) CGPDFContextEndPage(x);
    isim_cg_pdf_begin_page(x->target, mb.size.width, mb.size.height);
    while (x->depth > 0) CGContextRestoreGState(x);       /* a new page starts from a fresh graphics state */
    isim_cg_gstate_reset(&x->gs[0]);
    isim_cg_target_bind(x->target);
    isim_gfx_translate(-mb.origin.x, mb.size.height + mb.origin.y); isim_gfx_scale(1, -1);       /* PDF space is y-up */
    isim_cg_target_unbind(x->target);
    x->pageOpen = 1; x->pageBox = mb; x->pageNumber++;
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
/* a rect of the current page's default user space (y-up) in cairo's page units (y-down from the top-left) */
static CGRect page_units(struct CGContext *x, CGRect r) {
    CGRect pb = x->pageBox;
    r = CGRectStandardize(r);
    return CGRectMake(r.origin.x - pb.origin.x, pb.origin.y + pb.size.height - (r.origin.y + r.size.height), r.size.width, r.size.height);
}
void CGPDFContextSetURLForRect(CGContextRef c, CFURLRef url, CGRect rect) {
    if (!c || c->kind != CTX_PDF || !c->target || !url) return;
    char *u = utf8(CFURLGetString(url));
    if (!u) return;
    char *q = quoted(u);
    CGRect r = page_units(c, rect);
    char *attrs = malloc(strlen(q) + 128);
    sprintf(attrs, "uri='%s' rect=[%g %g %g %g]", q, r.origin.x, r.origin.y, r.size.width, r.size.height);
    isim_cg_pdf_tag(c->target, 0, attrs);
    free(attrs); free(q); free(u);
}
void CGPDFContextAddDestinationAtPoint(CGContextRef c, CFStringRef name, CGPoint point) {
    if (!c || c->kind != CTX_PDF || !c->target) return;
    char *n = utf8(name);
    if (!n) return;
    char *q = quoted(n);
    CGRect r = page_units(c, CGRectMake(point.x, point.y, 0, 0));
    char *attrs = malloc(strlen(q) + 96);
    sprintf(attrs, "name='%s' x=%g y=%g", q, r.origin.x, r.origin.y);
    isim_cg_pdf_tag(c->target, 1, attrs);
    free(attrs); free(q); free(n);
}
void CGPDFContextSetDestinationForRect(CGContextRef c, CFStringRef name, CGRect rect) {
    if (!c || c->kind != CTX_PDF || !c->target) return;
    char *n = utf8(name);
    if (!n) return;
    char *q = quoted(n);
    CGRect r = page_units(c, rect);
    char *attrs = malloc(strlen(q) + 128);
    sprintf(attrs, "dest='%s' rect=[%g %g %g %g]", q, r.origin.x, r.origin.y, r.size.width, r.size.height);
    isim_cg_pdf_tag(c->target, 0, attrs);
    free(attrs); free(q); free(n);
}
void CGPDFContextAddDocumentMetadata(CGContextRef c, CFDataRef metadata) {}
static void add_outline(struct CGContext *c, CFDictionaryRef node, int parent, int depth) {
    CFArrayRef kids = node ? CFDictionaryGetValue(node, kCGPDFOutlineChildren) : NULL;
    if (!kids || CFGetTypeID(kids) != CFArrayGetTypeID() || depth > 32) return;
    for (CFIndex i = 0; i < CFArrayGetCount(kids); i++) {
        CFDictionaryRef k = CFArrayGetValueAtIndex(kids, i);
        if (!k || CFGetTypeID(k) != CFDictionaryGetTypeID()) continue;
        char *title = utf8(CFDictionaryGetValue(k, kCGPDFOutlineTitle));
        CFTypeRef dest = CFDictionaryGetValue(k, kCGPDFOutlineDestination);
        char link[512] = "";
        if (dest && CFGetTypeID(dest) == CFNumberGetTypeID()) {
            int page = 1;
            CFNumberGetValue(dest, kCFNumberIntType, &page);
            snprintf(link, sizeof link, "page=%d", page);
        } else if (dest && CFGetTypeID(dest) == CFStringGetTypeID()) {
            char *n = utf8(dest), *q = n ? quoted(n) : NULL;
            if (q) snprintf(link, sizeof link, "dest='%s'", q);
            free(n); free(q);
        }
        int id = isim_cg_pdf_outline(c->target, parent, title ? title : "", link, 0);
        free(title);
        add_outline(c, k, id, depth + 1);
    }
}
void CGPDFContextSetOutline(CGContextRef c, CFDictionaryRef outline) {
    if (!c || c->kind != CTX_PDF || !c->target) return;
    add_outline(c, outline, 0, 0);
}

/* ---------------- PDF documents ----------------
 * The objects are read by isim's parser (CGPDFParser.c); poppler renders the pages. */
CFTypeID CGPDFDocumentGetTypeID(void) { return 0x4370; }
CFTypeID CGPDFPageGetTypeID(void) { return 0x4371; }
static void doc_fin(void *o) {
    struct CGPDFDocument *d = o;
    if (d->cache) { for (int i = 0; i < d->pages; i++) if (d->cache[i]) objc_release(d->cache[i]); free(d->cache); }
    isim_pdf_close(d->doc);
    if (d->outline) CFRelease(d->outline);
    isim_pdf_doc_free(d->pd);
    if (d->data) CFRelease(d->data);
}
CGPDFDocumentRef CGPDFDocumentCreateWithProvider(CGDataProviderRef p) {
    CFDataRef data = CGDataProviderCopyData(p);
    if (!data) return NULL;
    const unsigned char *bytes = CFDataGetBytePtr(data);
    long len = CFDataGetLength(data);
    struct pdoc *pd = isim_pdf_doc_open(bytes, (size_t)len);
    int npages = 0, ppages = 0;
    if (pd) isim_pdf_doc_pages(pd, &npages);
    void *doc = !pd || isim_pdf_doc_unlocked(pd) ? isim_pdf_open_password(bytes, len, isim_pdf_doc_password(pd), &ppages) : NULL;
    if (!pd && !doc) {
        if (!isim_pdf_available()) fprintf(stderr, "isim: CGPDFDocument: reading PDFs needs the host's poppler-glib (libpoppler-glib.so.8)\n");
        CFRelease(data); return NULL;
    }
    struct CGPDFDocument *d = isim_cg_obj_new("CGPDFDocument", sizeof *d, doc_fin);
    d->doc = doc; d->pd = pd; d->data = data;
    d->pages = npages > 0 ? npages : ppages;
    d->cache = calloc((size_t)(d->pages > 0 ? d->pages : 1), sizeof *d->cache);
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
bool CGPDFDocumentIsEncrypted(CGPDFDocumentRef d) { return d && isim_pdf_doc_encrypted(d->pd); }
bool CGPDFDocumentIsUnlocked(CGPDFDocumentRef d) { return d && (!d->pd || isim_pdf_doc_unlocked(d->pd)); }
bool CGPDFDocumentUnlockWithPassword(CGPDFDocumentRef d, const char *password) {
    if (!d) return false;
    if (!d->pd || !isim_pdf_doc_encrypted(d->pd)) return true;
    int was = isim_pdf_doc_unlocked(d->pd);
    if (!isim_pdf_doc_unlock(d->pd, password)) return false;
    if (!was || !d->doc) {                                             /* poppler needs the password too */
        int pages = 0;
        if (d->doc) isim_pdf_close(d->doc);
        d->doc = isim_pdf_open_password(CFDataGetBytePtr(d->data), CFDataGetLength(d->data), password, &pages);
    }
    return true;
}
/* the /P bits (PDF 32000-1, table 22) */
enum { P_PRINT = 1 << 2, P_MODIFY = 1 << 3, P_COPY = 1 << 4, P_ANNOT = 1 << 5, P_FORMS = 1 << 8, P_EXTRACT = 1 << 9,
       P_ASSEMBLE = 1 << 10, P_PRINT_HQ = 1 << 11 };
bool CGPDFDocumentAllowsPrinting(CGPDFDocumentRef d) { return d && CGPDFDocumentIsUnlocked(d) && (isim_pdf_doc_permissions(d->pd) & P_PRINT); }
bool CGPDFDocumentAllowsCopying(CGPDFDocumentRef d) { return d && CGPDFDocumentIsUnlocked(d) && (isim_pdf_doc_permissions(d->pd) & P_COPY); }
CGPDFAccessPermissions CGPDFDocumentGetAccessPermissions(CGPDFDocumentRef d) {
    if (!d || !CGPDFDocumentIsUnlocked(d)) return 0;
    uint32_t p = isim_pdf_doc_permissions(d->pd);
    CGPDFAccessPermissions r = 0;
    if (p & P_PRINT) r |= kCGPDFAllowsLowQualityPrinting;
    if ((p & P_PRINT) && (p & P_PRINT_HQ)) r |= kCGPDFAllowsHighQualityPrinting;
    if (p & P_MODIFY) r |= kCGPDFAllowsDocumentChanges;
    if (p & P_ASSEMBLE) r |= kCGPDFAllowsDocumentAssembly;
    if (p & P_COPY) r |= kCGPDFAllowsContentCopying;
    if (p & (P_EXTRACT | P_COPY)) r |= kCGPDFAllowsContentAccessibility;
    if (p & P_ANNOT) r |= kCGPDFAllowsCommenting;
    if (p & (P_FORMS | P_ANNOT)) r |= kCGPDFAllowsFormFieldEntry;
    return r;
}
void CGPDFDocumentGetVersion(CGPDFDocumentRef d, int *major, int *minor) {
    if (major) *major = 0;
    if (minor) *minor = 0;
    if (d && d->pd) isim_pdf_doc_version(d->pd, major, minor);
}
CGPDFDictionaryRef CGPDFDocumentGetCatalog(CGPDFDocumentRef d) { return d ? isim_pdf_doc_catalog(d->pd) : NULL; }
CGPDFDictionaryRef CGPDFDocumentGetInfo(CGPDFDocumentRef d) {
    CGPDFDictionaryRef info = NULL;
    return d && CGPDFDictionaryGetDictionary(isim_pdf_doc_trailer(d->pd), "Info", &info) ? info : NULL;
}
CGPDFArrayRef CGPDFDocumentGetID(CGPDFDocumentRef d) {
    CGPDFArrayRef id = NULL;
    return d && CGPDFDictionaryGetArray(isim_pdf_doc_trailer(d->pd), "ID", &id) ? id : NULL;
}
CGPDFPageRef CGPDFDocumentGetPage(CGPDFDocumentRef d, size_t n) {
    if (!d || n < 1 || n > (size_t)d->pages) return NULL;
    if (!d->cache[n - 1]) {
        struct CGPDFPage *p = isim_cg_obj_new("CGPDFPage", sizeof *p, NULL);
        p->doc = d; p->index = (int)n - 1;
        d->cache[n - 1] = p;
    }
    return d->cache[n - 1];
}
CGPDFPageRef CGPDFPageRetain(CGPDFPageRef p) { return p ? objc_retain(p) : NULL; }
void CGPDFPageRelease(CGPDFPageRef p) { if (p) objc_release(p); }
CGPDFDocumentRef CGPDFPageGetDocument(CGPDFPageRef p) { return p ? p->doc : NULL; }
size_t CGPDFPageGetPageNumber(CGPDFPageRef p) { return p ? (size_t)p->index + 1 : 0; }
CGPDFDictionaryRef CGPDFPageGetDictionary(CGPDFPageRef p) {
    if (!p || !p->doc->pd) return NULL;
    int n = 0;
    CGPDFDictionaryRef *pages = (CGPDFDictionaryRef *)isim_pdf_doc_pages(p->doc->pd, &n);
    return p->index < n ? pages[p->index] : NULL;
}
static bool box_of(struct CGPDFDictionary *page, const char *key, CGRect *r) {
    struct CGPDFObject *o = page ? isim_pdf_inherited(page, key) : NULL;
    CGPDFReal v[4];
    if (!o || o->type != kCGPDFObjectTypeArray || CGPDFArrayGetCount(o->v.arr) < 4) return false;
    for (size_t i = 0; i < 4; i++) if (!CGPDFArrayGetNumber(o->v.arr, i, &v[i])) return false;
    *r = CGRectStandardize(CGRectMake(v[0], v[1], v[2] - v[0], v[3] - v[1]));
    return true;
}
/* a page's boxes: the media box (US Letter when missing), the crop box (the media box), the bleed, trim and art boxes
   (the crop box), each clipped to the media box */
CGRect CGPDFPageGetBoxRect(CGPDFPageRef p, CGPDFBox box) {
    if (!p) return CGRectZero;
    struct CGPDFDictionary *page = (struct CGPDFDictionary *)CGPDFPageGetDictionary(p);
    CGRect media, crop, r;
    if (!box_of(page, "MediaBox", &media)) {
        double w = 0, h = 0;
        if (p->doc->doc) isim_pdf_page_size(p->doc->doc, p->index, &w, &h);
        media = w > 0 && h > 0 && !page ? CGRectMake(0, 0, w, h) : CGRectMake(0, 0, 612, 792);
    }
    if (!box_of(page, "CropBox", &crop)) crop = media;
    crop = CGRectIntersection(crop, media);
    if (CGRectIsNull(crop)) crop = media;
    static const char *const names[] = { "MediaBox", "CropBox", "BleedBox", "TrimBox", "ArtBox" };
    if (box == kCGPDFMediaBox) return media;
    if (box == kCGPDFCropBox) return crop;
    if ((int)box < 0 || (int)box > 4 || !box_of(page, names[box], &r)) return crop;
    r = CGRectIntersection(r, media);
    return CGRectIsNull(r) ? crop : r;
}
int CGPDFPageGetRotationAngle(CGPDFPageRef p) {
    struct CGPDFObject *o = p ? isim_pdf_inherited((struct CGPDFDictionary *)CGPDFPageGetDictionary(p), "Rotate") : NULL;
    if (!o) return 0;
    long r = o->type == kCGPDFObjectTypeInteger ? o->v.i : o->type == kCGPDFObjectTypeReal ? (long)o->v.r : 0;
    r = ((r % 360) + 360) % 360;
    return (int)(r - r % 90);
}
/* maps the box into rect: centered, rotated by the page's rotation plus `rotate` (clockwise, multiples of 90), scaled
   to fit (uniformly and never up with preserveAspectRatio) */
CGAffineTransform CGPDFPageGetDrawingTransform(CGPDFPageRef p, CGPDFBox box, CGRect rect, int rotate, bool keep) {
    if (!p) return CGAffineTransformIdentity;
    CGRect b = CGPDFPageGetBoxRect(p, box);
    if (b.size.width <= 0 || b.size.height <= 0) return CGAffineTransformIdentity;
    int angle = ((CGPDFPageGetRotationAngle(p) + rotate) % 360 + 360) % 360;
    angle -= angle % 90;
    double w = b.size.width, h = b.size.height;
    if (angle == 90 || angle == 270) { double t = w; w = h; h = t; }
    double sx = rect.size.width / w, sy = rect.size.height / h;
    if (keep) sx = sy = fmin(fmin(sx, sy), 1);      /* Core Graphics only scales PDF pages down */
    CGAffineTransform t = CGAffineTransformMakeTranslation(CGRectGetMidX(rect), CGRectGetMidY(rect));
    t = CGAffineTransformScale(t, sx, sy);
    t = CGAffineTransformRotate(t, -angle * M_PI / 180);
    t = CGAffineTransformTranslate(t, -CGRectGetMidX(b), -CGRectGetMidY(b));
    return t;
}
/* draws the page in its default user space: poppler renders the crop box y-down and rotated as displayed, so the
   drawing is placed at the crop box and turned back */
void CGContextDrawPDFPage(CGContextRef c, CGPDFPageRef p) {
    if (!p || !p->doc->doc) return;
    struct CGContext *x = c ? c : (struct CGContext *)isim_cg_current_context();
    CGRect crop = CGPDFPageGetBoxRect(p, kCGPDFCropBox);
    double w = crop.size.width, h = crop.size.height;
    int r = CGPDFPageGetRotationAngle(p);                                /* poppler renders the page rotated by it */
    if (x->target) isim_cg_target_bind(x->target);
    isim_gfx_save();
    isim_gfx_translate(crop.origin.x, crop.origin.y + h); isim_gfx_scale(1, -1);       /* the crop box, y-down */
    if (r == 90) isim_gfx_concat(0, -1, 1, 0, 0, h);                   /* display coordinates back to the page's */
    else if (r == 180) isim_gfx_concat(-1, 0, 0, -1, w, h);
    else if (r == 270) isim_gfx_concat(0, 1, -1, 0, w, 0);
    isim_pdf_page_render(p->doc->doc, p->index);
    isim_gfx_restore();
    if (x->target) isim_cg_target_unbind(x->target);
}

/* ---------------- outlines ---------------- */
static void set_num(CFMutableDictionaryRef d, CFStringRef k, double v) {
    CFNumberRef n = CFNumberCreate(NULL, kCFNumberDoubleType, &v);
    CFDictionarySetValue(d, k, n); CFRelease(n);
}
/* a name in a name tree (/Names /Dests) */
static CGPDFObjectRef name_tree(CGPDFDictionaryRef node, const unsigned char *key, size_t keylen, int depth) {
    CGPDFArrayRef names, kids;
    if (!node || depth > 32) return NULL;
    if (CGPDFDictionaryGetArray(node, "Names", &names))
        for (size_t i = 0; i + 1 < CGPDFArrayGetCount(names); i += 2) {
            CGPDFStringRef s; CGPDFObjectRef v;
            if (CGPDFArrayGetString(names, i, &s) && CGPDFStringGetLength(s) == keylen && !memcmp(CGPDFStringGetBytePtr(s), key, keylen) &&
                CGPDFArrayGetObject(names, i + 1, &v)) return v;
        }
    if (CGPDFDictionaryGetArray(node, "Kids", &kids))
        for (size_t i = 0; i < CGPDFArrayGetCount(kids); i++) {
            CGPDFDictionaryRef k;
            if (CGPDFArrayGetDictionary(kids, i, &k)) { CGPDFObjectRef v = name_tree(k, key, keylen, depth + 1); if (v) return v; }
        }
    return NULL;
}
/* an explicit destination array for a destination (array, name or string, or a dictionary with /D) */
static CGPDFArrayRef dest_array(struct CGPDFDocument *doc, CGPDFObjectRef dest, int depth) {
    CGPDFArrayRef a; const char *name; CGPDFStringRef str; CGPDFDictionaryRef dict;
    if (!dest || depth > 8) return NULL;
    if (CGPDFObjectGetValue(dest, kCGPDFObjectTypeArray, &a)) return a;
    if (CGPDFObjectGetValue(dest, kCGPDFObjectTypeDictionary, &dict)) {
        CGPDFObjectRef d;
        return CGPDFDictionaryGetObject(dict, "D", &d) ? dest_array(doc, d, depth + 1) : NULL;
    }
    CGPDFDictionaryRef cat = CGPDFDocumentGetCatalog(doc), dests, names, tree;
    if (CGPDFObjectGetValue(dest, kCGPDFObjectTypeName, &name)) {
        CGPDFObjectRef d;
        if (CGPDFDictionaryGetDictionary(cat, "Dests", &dests) && CGPDFDictionaryGetObject(dests, name, &d)) return dest_array(doc, d, depth + 1);
        return NULL;
    }
    if (CGPDFObjectGetValue(dest, kCGPDFObjectTypeString, &str) && CGPDFDictionaryGetDictionary(cat, "Names", &names) &&
        CGPDFDictionaryGetDictionary(names, "Dests", &tree))
        return dest_array(doc, name_tree(tree, CGPDFStringGetBytePtr(str), CGPDFStringGetLength(str), 0), depth + 1);
    return NULL;
}
static void add_destination(struct CGPDFDocument *doc, CFMutableDictionaryRef item, CGPDFArrayRef a) {
    CGPDFDictionaryRef target; CGPDFInteger index;
    int page = 0, n = 0;
    CGPDFDictionaryRef *pages = (CGPDFDictionaryRef *)isim_pdf_doc_pages(doc->pd, &n);
    if (CGPDFArrayGetDictionary(a, 0, &target)) { for (int i = 0; i < n; i++) if (pages[i] == target) { page = i + 1; break; } }
    else if (CGPDFArrayGetInteger(a, 0, &index)) page = (int)index + 1;
    if (!page) return;
    CFNumberRef num = CFNumberCreate(NULL, kCFNumberIntType, &page);
    CFDictionarySetValue(item, kCGPDFOutlineDestination, num); CFRelease(num);
    const char *fit; CGPDFReal v[4];
    if (!CGPDFArrayGetName(a, 1, &fit)) return;
    CGRect r = CGRectNull;
    if (!strcmp(fit, "XYZ") && CGPDFArrayGetNumber(a, 2, &v[0]) && CGPDFArrayGetNumber(a, 3, &v[1])) r = CGRectMake(v[0], v[1], 0, 0);
    else if (!strcmp(fit, "FitR") && CGPDFArrayGetNumber(a, 2, &v[0]) && CGPDFArrayGetNumber(a, 3, &v[1]) && CGPDFArrayGetNumber(a, 4, &v[2]) &&
             CGPDFArrayGetNumber(a, 5, &v[3])) r = CGRectStandardize(CGRectMake(v[0], v[1], v[2] - v[0], v[3] - v[1]));
    if (CGRectIsNull(r)) return;
    CFMutableDictionaryRef rd = CFDictionaryCreateMutable(NULL, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    set_num(rd, CFSTR("X"), r.origin.x); set_num(rd, CFSTR("Y"), r.origin.y);
    set_num(rd, CFSTR("Width"), r.size.width); set_num(rd, CFSTR("Height"), r.size.height);
    CFDictionarySetValue(item, kCGPDFOutlineDestinationRect, rd); CFRelease(rd);
}
static CFArrayRef outline_children(struct CGPDFDocument *doc, CGPDFDictionaryRef parent, int depth) {
    CGPDFDictionaryRef item;
    if (depth > 32 || !CGPDFDictionaryGetDictionary(parent, "First", &item)) return NULL;
    CFMutableArrayRef kids = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    for (int guard = 0; item && guard < 100000; guard++) {
        CFMutableDictionaryRef d = CFDictionaryCreateMutable(NULL, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CGPDFStringRef title;
        CFStringRef t = CGPDFDictionaryGetString(item, "Title", &title) ? CGPDFStringCopyTextString(title) : NULL;
        CFDictionarySetValue(d, kCGPDFOutlineTitle, t ? t : CFSTR(""));
        if (t) CFRelease(t);
        CGPDFObjectRef dest; CGPDFDictionaryRef action;
        CGPDFArrayRef a = CGPDFDictionaryGetObject(item, "Dest", &dest) ? dest_array(doc, dest, 0) : NULL;
        if (!a && CGPDFDictionaryGetDictionary(item, "A", &action) && CGPDFDictionaryGetObject(action, "D", &dest)) a = dest_array(doc, dest, 0);
        if (a) add_destination(doc, d, a);
        CFArrayRef sub = outline_children(doc, item, depth + 1);
        if (sub) { CFDictionarySetValue(d, kCGPDFOutlineChildren, sub); CFRelease(sub); }
        CFArrayAppendValue(kids, d); CFRelease(d);
        CGPDFDictionaryRef next;
        item = CGPDFDictionaryGetDictionary(item, "Next", &next) && next != item ? next : NULL;
    }
    return kids;
}
CFDictionaryRef CGPDFDocumentGetOutline(CGPDFDocumentRef d) {
    if (!d || !d->pd) return NULL;
    if (!d->outline) {
        CGPDFDictionaryRef outlines;
        if (!CGPDFDictionaryGetDictionary(CGPDFDocumentGetCatalog(d), "Outlines", &outlines)) return NULL;
        CFMutableDictionaryRef root = CFDictionaryCreateMutable(NULL, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFArrayRef kids = outline_children(d, outlines, 0);
        if (kids) { CFDictionarySetValue(root, kCGPDFOutlineChildren, kids); CFRelease(kids); }
        d->outline = root;
    }
    return d->outline;
}
