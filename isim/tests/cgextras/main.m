// Core Graphics from C (CGExtrasTest.app, issue #363): ICC color spaces (profiles built here: sRGB's primaries with
// its parametric curve, and a linear one), Lab and indexed spaces (colors and images), the extended / linearized /
// standard-range variants, direct and sequential data providers, CGFont tables (by name and from a font file),
// layers, and conic gradients. Colors are checked on pixels drawn into bitmap contexts.
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>
#include <math.h>
#include <stdio.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[220]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

/* ---------------- helpers ---------------- */
typedef struct { CGContextRef c; unsigned char *px; size_t w, h; } bitmap;
static bitmap make_bitmap(size_t w, size_t h) {
    bitmap b = { NULL, calloc(w * h * 4, 1), w, h };
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    b.c = CGBitmapContextCreate(b.px, w, h, 8, w * 4, cs, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    return b;
}
static void free_bitmap(bitmap b) { CGContextRelease(b.c); free(b.px); }
/* the pixel at (x, y) in Core Graphics coordinates (y up) */
static const unsigned char *at(bitmap b, size_t x, size_t y) { return b.px + ((b.h - 1 - y) * b.w + x) * 4; }
static bool rgb_near(const unsigned char *p, int r, int g, int b, int tol) { return abs(p[0] - r) <= tol && abs(p[1] - g) <= tol && abs(p[2] - b) <= tol; }
/* a color drawn as a 4x4 square: its sRGB pixel */
static void drawn(CGColorRef color, unsigned char out[4]) {
    bitmap b = make_bitmap(4, 4);
    CGContextSetFillColorWithColor(b.c, color);
    CGContextFillRect(b.c, CGRectMake(0, 0, 4, 4));
    memcpy(out, at(b, 1, 1), 4);
    free_bitmap(b);
}

/* ---------------- ICC profiles ---------------- */
static void put32(unsigned char *p, uint32_t v) { p[0] = v >> 24; p[1] = v >> 16; p[2] = v >> 8; p[3] = v; }
static void puts15(unsigned char *p, double v) { put32(p, (uint32_t)(int32_t)lround(v * 65536)); }
/* an RGB matrix / TRC profile with sRGB's primaries (D50); linear: a curve of count 0, else sRGB's parametric curve */
static NSData *rgb_profile(bool linear) {
    NSMutableData *d = [NSMutableData dataWithLength:128 + 4 + 6 * 12];
    unsigned char *h = d.mutableBytes;
    memcpy(h + 12, "mntr", 4); memcpy(h + 16, "RGB ", 4); memcpy(h + 20, "XYZ ", 4); memcpy(h + 36, "acsp", 4);
    h[8] = 2; h[9] = 0x40;                                              /* version 2.4 */
    put32(h + 128, 6);
    double prim[3][3] = { { 0.4360747, 0.2225045, 0.0139322 }, { 0.3850649, 0.7168786, 0.0971045 }, { 0.1430804, 0.0606169, 0.7141733 } };
    const char *xyz[3] = { "rXYZ", "gXYZ", "bXYZ" }, *trc[3] = { "rTRC", "gTRC", "bTRC" };
    for (int k = 0; k < 3; k++) {
        unsigned char tag[20] = { 0 };
        memcpy(tag, "XYZ ", 4);
        for (int i = 0; i < 3; i++) puts15(tag + 8 + 4 * i, prim[k][i]);
        unsigned char *e = (unsigned char *)d.mutableBytes + 132 + 12 * k;
        memcpy(e, xyz[k], 4); put32(e + 4, (uint32_t)d.length); put32(e + 8, 20);
        [d appendBytes:tag length:20];
    }
    unsigned char curve[32] = { 0 };
    size_t clen;
    if (linear) { memcpy(curve, "curv", 4); clen = 12; }
    else {      /* para function 3: Y = (aX + b)^g for X >= d, else cX */
        memcpy(curve, "para", 4); curve[9] = 3;
        puts15(curve + 12, 2.4); puts15(curve + 16, 1 / 1.055); puts15(curve + 20, 0.055 / 1.055); puts15(curve + 24, 1 / 12.92); puts15(curve + 28, 0.04045);
        clen = 32;
    }
    uint32_t off = (uint32_t)d.length;
    [d appendBytes:curve length:clen];
    for (int k = 0; k < 3; k++) { unsigned char *e = (unsigned char *)d.mutableBytes + 132 + 12 * (3 + k); memcpy(e, trc[k], 4); put32(e + 4, off); put32(e + 8, (uint32_t)clen); }
    put32(d.mutableBytes, (uint32_t)d.length);
    return d;
}
static void icc(void) {
    NSData *p = rgb_profile(false), *lin = rgb_profile(true);
    CGColorSpaceRef s = CGColorSpaceCreateWithICCData((__bridge CFDataRef)p);
    CHECK(s && CGColorSpaceGetModel(s) == kCGColorSpaceModelRGB && CGColorSpaceGetNumberOfComponents(s) == 3, "icc: an RGB profile");
    NSData *back = CFBridgingRelease(CGColorSpaceCopyICCData(s));
    CHECK([back isEqual:p], "icc: CGColorSpaceCopyICCData returns the profile");
    CGFloat comps[4] = { 0.2, 0.5, 0.8, 1 };
    CGColorRef c = CGColorCreate(s, comps);
    unsigned char px[4]; drawn(c, px);
    CHECK(rgb_near(px, 51, 128, 204, 2), "icc: sRGB primaries and curve draw the same color (%d %d %d)", px[0], px[1], px[2]);
    CGColorRelease(c);
    CGDataProviderRef prov = CGDataProviderCreateWithCFData((__bridge CFDataRef)lin);
    CGColorSpaceRef ls = CGColorSpaceCreateWithICCData(prov);
    CGFloat half[4] = { 0.5, 0.5, 0.5, 1 };
    c = CGColorCreate(ls, half); drawn(c, px); CGColorRelease(c);
    CHECK(ls && rgb_near(px, 188, 188, 188, 2), "icc: a linear profile, from a data provider: 0.5 is sRGB 188 (%d)", px[0]);
    CHECK(!CGColorSpaceCreateWithICCData((__bridge CFDataRef)[@"not a profile" dataUsingEncoding:NSUTF8StringEncoding]), "icc: other data gives no space");
    /* an image in the space */
    unsigned char rgb[6] = { 51, 128, 204, 255, 0, 0 };
    CGDataProviderRef ip = CGDataProviderCreateWithData(NULL, rgb, 6, NULL);
    CGImageRef im = CGImageCreate(2, 1, 8, 24, 6, ls, (CGBitmapInfo)kCGImageAlphaNone, ip, NULL, false, kCGRenderingIntentDefault);
    bitmap b = make_bitmap(2, 1);
    if (im) CGContextDrawImage(b.c, CGRectMake(0, 0, 2, 1), im);
    CHECK(im && rgb_near(at(b, 0, 0), 125, 187, 231, 3) && rgb_near(at(b, 1, 0), 255, 0, 0, 2), "icc: an image's pixels converted (%d %d %d)", at(b, 0, 0)[0], at(b, 0, 0)[1], at(b, 0, 0)[2]);
    CHECK(im && CGImageGetColorSpace(im) == ls, "icc: the image keeps its space");
    free_bitmap(b); CGImageRelease(im); CGDataProviderRelease(ip); CGDataProviderRelease(prov);
    /* variants */
    CGColorSpaceRef ext = CGColorSpaceCreateExtended(s);
    CHECK(ext && CGColorSpaceUsesExtendedRange(ext) && !CGColorSpaceUsesExtendedRange(s) && CFBridgingRelease(CGColorSpaceCopyICCData(ext)), "icc: an extended copy");
    CGColorSpaceRef std = CGColorSpaceCreateCopyWithStandardRange(ext);
    CHECK(std && !CGColorSpaceUsesExtendedRange(std), "icc: back to the standard range");
    CHECK(!CGColorSpaceCreateLinearized(s), "icc: no linear form");
    CGColorSpaceRelease(std); CGColorSpaceRelease(ext); CGColorSpaceRelease(ls); CGColorSpaceRelease(s);
}

/* ---------------- Lab and indexed ---------------- */
static void lab_and_indexed(void) {
    CGFloat d65[3] = { 0.95047, 1, 1.08883 }, range[4] = { -128, 127, -128, 127 };
    CGColorSpaceRef lab = CGColorSpaceCreateLab(d65, NULL, range);
    CHECK(lab && CGColorSpaceGetModel(lab) == kCGColorSpaceModelLab && CGColorSpaceGetNumberOfComponents(lab) == 3, "lab: a space");
    CGFloat red[4] = { 53.24, 80.09, 67.20, 1 }, gray[4] = { 50, 0, 0, 1 };
    unsigned char px[4];
    CGColorRef c = CGColorCreate(lab, red); drawn(c, px); CGColorRelease(c);
    CHECK(rgb_near(px, 255, 0, 0, 3), "lab: sRGB red's Lab (%d %d %d)", px[0], px[1], px[2]);
    c = CGColorCreate(lab, gray); drawn(c, px); CGColorRelease(c);
    CHECK(rgb_near(px, 119, 119, 119, 2), "lab: L 50 is a middle gray (%d)", px[0]);
    CGFloat bad[3] = { 0.9, 0.5, 1 };
    CHECK(!CGColorSpaceCreateLab(bad, NULL, NULL), "lab: a white point with Y other than 1 fails");
    CGColorSpaceRef generic = CGColorSpaceCreateWithName(kCGColorSpaceGenericLab);
    CHECK(generic && CGColorSpaceGetModel(generic) == kCGColorSpaceModelLab, "lab: kCGColorSpaceGenericLab");
    CHECK(!CGColorSpaceCreateLinearized(lab), "lab: no linear form");
    CGColorSpaceRelease(generic); CGColorSpaceRelease(lab);

    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    const unsigned char table[9] = { 255, 0, 0, 0, 255, 0, 0, 0, 255 };
    CGColorSpaceRef idx = CGColorSpaceCreateIndexed(rgb, 2, table);
    unsigned char got[9] = { 0 };
    CGColorSpaceGetColorTable(idx, got);
    CGColorSpaceRef base = CGColorSpaceCopyBaseColorSpace(idx);
    CHECK(idx && CGColorSpaceGetModel(idx) == kCGColorSpaceModelIndexed && CGColorSpaceGetNumberOfComponents(idx) == 1 &&
          CGColorSpaceGetColorTableCount(idx) == 3 && !memcmp(got, table, 9) && base == rgb && CGColorSpaceGetBaseColorSpace(idx) == rgb,
          "indexed: model, table, base");
    CGFloat one[2] = { 1, 1 };
    c = CGColorCreate(idx, one); drawn(c, px); CGColorRelease(c);
    CHECK(rgb_near(px, 0, 255, 0, 1), "indexed: index 1 is green");
    unsigned char indices[3] = { 2, 0, 9 };
    CGDataProviderRef ip = CGDataProviderCreateWithData(NULL, indices, 3, NULL);
    CGImageRef im = CGImageCreate(3, 1, 8, 8, 3, idx, (CGBitmapInfo)kCGImageAlphaNone, ip, NULL, false, kCGRenderingIntentDefault);
    bitmap b = make_bitmap(3, 1);
    if (im) CGContextDrawImage(b.c, CGRectMake(0, 0, 3, 1), im);
    CHECK(im && rgb_near(at(b, 0, 0), 0, 0, 255, 1) && rgb_near(at(b, 1, 0), 255, 0, 0, 1) && rgb_near(at(b, 2, 0), 0, 0, 255, 1),
          "indexed: an image's indices (past the end: the last color)");
    CHECK(!CGColorSpaceCreateIndexed(rgb, 300, table), "indexed: more than 256 colors fail");
    free_bitmap(b); CGImageRelease(im); CGDataProviderRelease(ip);
    CGColorSpaceRelease(base); CGColorSpaceRelease(idx); CGColorSpaceRelease(rgb);
}

/* ---------------- extended, linearized, standard range ---------------- */
static bool named(CGColorSpaceRef s, CFStringRef name) { return s && CGColorSpaceGetName(s) && CFEqual(CGColorSpaceGetName(s), name); }
static void variants(void) {
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB), p3 = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
    CGColorSpaceRef e = CGColorSpaceCreateExtended(srgb), l = CGColorSpaceCreateLinearized(srgb), el = CGColorSpaceCreateExtendedLinearized(srgb);
    CGColorSpaceRef s2 = CGColorSpaceCreateCopyWithStandardRange(e), lp3 = CGColorSpaceCreateLinearized(p3), ep3 = CGColorSpaceCreateExtended(p3);
    CHECK(named(e, kCGColorSpaceExtendedSRGB) && CGColorSpaceUsesExtendedRange(e), "variants: extended sRGB");
    CHECK(named(l, kCGColorSpaceLinearSRGB) && named(el, kCGColorSpaceExtendedLinearSRGB) && named(s2, kCGColorSpaceSRGB), "variants: linear, extended linear, standard range");
    CHECK(named(lp3, kCGColorSpaceLinearDisplayP3) && named(ep3, kCGColorSpaceExtendedDisplayP3) && CGColorSpaceIsWideGamutRGB(lp3), "variants: Display P3's");
    CGFloat half[4] = { 0.5, 0.5, 0.5, 1 };
    unsigned char px[4];
    CGColorRef c = CGColorCreate(lp3, half); drawn(c, px); CGColorRelease(c);
    CHECK(rgb_near(px, 188, 188, 188, 2), "variants: linear Display P3 gray 0.5 is sRGB 188 (%d)", px[0]);
    CGColorSpaceRef byName = CGColorSpaceCreateWithName(kCGColorSpaceLinearDisplayP3);
    CHECK(byName == lp3, "variants: kCGColorSpaceLinearDisplayP3 by name");
    CGColorSpaceRelease(byName);
    CGColorSpaceRelease(e); CGColorSpaceRelease(l); CGColorSpaceRelease(el); CGColorSpaceRelease(s2); CGColorSpaceRelease(lp3); CGColorSpaceRelease(ep3);
    CGColorSpaceRelease(srgb); CGColorSpaceRelease(p3);
}

/* ---------------- data providers ---------------- */
static const char *DATA = "The quick brown fox jumps over the lazy dog";
static int released, rewound, pointers;
static const void *get_pointer(void *info) { pointers++; return DATA; }
static void release_pointer(void *info, const void *p) { pointers--; }
static size_t get_at(void *info, void *buf, off_t pos, size_t n) {
    size_t len = strlen(DATA);
    if ((size_t)pos >= len) return 0;
    size_t k = n < 5 ? n : 5;                       /* five bytes at a time */
    if ((size_t)pos + k > len) k = len - (size_t)pos;
    memcpy(buf, DATA + pos, k);
    return k;
}
static void release_info(void *info) { released += (int)(intptr_t)info; }
static size_t seq_pos;
static size_t get_bytes(void *info, void *buf, size_t n) {
    size_t len = strlen(DATA), k = n < 7 ? n : 7;
    if (seq_pos >= len) return 0;
    if (seq_pos + k > len) k = len - seq_pos;
    memcpy(buf, DATA + seq_pos, k); seq_pos += k;
    return k;
}
static void rewind_cb(void *info) { rewound++; seq_pos = 0; }
static void providers(void) {
    NSData *want = [NSData dataWithBytes:DATA length:strlen(DATA)];
    CGDataProviderDirectCallbacks direct = { 0, get_pointer, release_pointer, NULL, release_info };
    CGDataProviderRef p = CGDataProviderCreateDirect((void *)1, (off_t)strlen(DATA), &direct);
    NSData *d = CFBridgingRelease(CGDataProviderCopyData(p));
    CHECK([d isEqual:want] && pointers == 0 && CGDataProviderGetInfo(p) == (void *)1, "direct provider: the bytes through the pointer callbacks");
    CGDataProviderRelease(p);
    CHECK(released == 1, "direct provider: releaseInfo when freed");
    CGDataProviderDirectCallbacks positioned = { 0, NULL, NULL, get_at, release_info };
    p = CGDataProviderCreateDirect((void *)10, (off_t)strlen(DATA), &positioned);
    d = CFBridgingRelease(CGDataProviderCopyData(p));
    CHECK([d isEqual:want], "direct provider: bytes at positions, five at a time");
    CGDataProviderRelease(p);
    CGDataProviderSequentialCallbacks seq = { 0, get_bytes, NULL, rewind_cb, release_info };
    seq_pos = 20;
    p = CGDataProviderCreateSequential((void *)100, &seq);
    d = CFBridgingRelease(CGDataProviderCopyData(p));
    CHECK([d isEqual:want] && rewound == 1, "sequential provider: rewound, then read seven bytes at a time");
    CGDataProviderRelease(p);
    CHECK(released == 111, "providers: every releaseInfo ran (%d)", released);
    CHECK(!CGDataProviderCreateSequential(NULL, NULL), "sequential provider: no callbacks fail");
}

/* ---------------- font tables ---------------- */
static uint32_t be32(const unsigned char *p) { return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]; }
static bool has_tag(CFArrayRef tags, uint32_t tag) {
    for (CFIndex i = 0; tags && i < CFArrayGetCount(tags); i++) if ((uint32_t)(uintptr_t)CFArrayGetValueAtIndex(tags, i) == tag) return true;
    return false;
}
static void fonts(void) {
    CGFontRef byName = CGFontCreateWithFontName(CFSTR("DejaVuSans"));
    CFArrayRef tags = CGFontCopyTableTags(byName);
    NSData *head = CFBridgingRelease(CGFontCopyTableForTag(byName, 'head'));
    CHECK(has_tag(tags, 'head') && has_tag(tags, 'cmap') && has_tag(tags, 'glyf'), "font tables: the tags of a font by name");
    CHECK(head.length == 54 && be32((const unsigned char *)head.bytes + 12) == 0x5F0F3CF5, "font tables: head (54 bytes, its magic number)");
    CHECK(!CGFontCopyTableForTag(byName, 'zzzz'), "font tables: a missing table");
    if (tags) CFRelease(tags);
    /* from the font's file */
    CTFontRef ct = CTFontCreateWithName(CFSTR("DejaVuSans"), 12, NULL);
    NSURL *url = CFBridgingRelease(CTFontCopyAttribute(ct, kCTFontURLAttribute));
    CGDataProviderRef p = url ? CGDataProviderCreateWithURL((__bridge CFURLRef)url) : NULL;
    CGFontRef fromData = p ? CGFontCreateWithDataProvider(p) : NULL;
    NSData *head2 = CFBridgingRelease(CGFontCopyTableForTag(fromData, 'head'));
    CFArrayRef tags2 = CGFontCopyTableTags(fromData);
    CHECK(fromData && [head2 isEqual:head] && has_tag(tags2, 'cmap'), "font tables: from the font file's data (%s)", url.lastPathComponent.UTF8String ?: "-");
    if (tags2) CFRelease(tags2);
    CGFontRelease(fromData); CGDataProviderRelease(p); CFRelease(ct); CGFontRelease(byName);
}

/* ---------------- layers ---------------- */
static void layers(void) {
    bitmap b = make_bitmap(40, 20);
    CGLayerRef l = CGLayerCreateWithContext(b.c, CGSizeMake(20, 10), NULL);
    CGContextRef lc = CGLayerGetContext(l);
    CHECK(l && CGSizeEqualToSize(CGLayerGetSize(l), CGSizeMake(20, 10)) && lc && CGBitmapContextGetWidth(lc) == 20, "layer: size and context");
    CGContextSetRGBFillColor(lc, 1, 0, 0, 1);
    CGContextFillRect(lc, CGRectMake(0, 0, 10, 10));                 /* the left half red */
    CGContextDrawLayerAtPoint(b.c, CGPointMake(5, 5), l);
    CHECK(rgb_near(at(b, 8, 8), 255, 0, 0, 1) && at(b, 20, 8)[3] == 0 && at(b, 2, 2)[3] == 0, "layer: drawn at a point");
    CGContextDrawLayerInRect(b.c, CGRectMake(0, 0, 40, 20), l);      /* stretched: the left half of the bitmap */
    CHECK(rgb_near(at(b, 15, 15), 255, 0, 0, 1) && rgb_near(at(b, 2, 2), 255, 0, 0, 1), "layer: drawn in a rect");
    CGLayerRelease(l);
    CGContextScaleCTM(b.c, 2, 2);                                     /* a 2x context: the layer's bitmap is twice as wide */
    l = CGLayerCreateWithContext(b.c, CGSizeMake(10, 5), NULL);
    CHECK(l && CGBitmapContextGetWidth(CGLayerGetContext(l)) == 20 && CGBitmapContextGetHeight(CGLayerGetContext(l)) == 10, "layer: at the context's scale");
    CFTypeID tid = CGLayerGetTypeID();
    CHECK(CFGetTypeID(l) == tid, "layer: CFGetTypeID");
    CGLayerRelease(l);
    CHECK(!CGLayerCreateWithContext(b.c, CGSizeMake(0, 5), NULL), "layer: an empty size fails");
    free_bitmap(b);
}

/* ---------------- conic gradients ---------------- */
static void conic(void) {
    bitmap b = make_bitmap(100, 100);
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[8] = { 1, 0, 0, 1, 0, 0, 1, 1 }, locs[2] = { 0, 1 };
    CGGradientRef g = CGGradientCreateWithColorComponents(rgb, comps, locs, 2);
    CGContextDrawConicGradient(b.c, g, CGPointMake(50, 50), 0);
    const unsigned char *start = at(b, 90, 53), *end = at(b, 90, 47), *half = at(b, 10, 50), *quarter = at(b, 50, 90);
    CHECK(start[0] > 230 && start[2] < 30, "conic: red just counterclockwise of the start (%d %d %d)", start[0], start[1], start[2]);
    CHECK(end[2] > 230 && end[0] < 30, "conic: blue just before coming round (%d %d %d)", end[0], end[1], end[2]);
    CHECK(abs(half[0] - 128) < 12 && abs(half[2] - 128) < 12, "conic: halfway round, half and half (%d %d)", half[0], half[2]);
    CHECK(quarter[0] > quarter[2] + 80, "conic: a quarter round, mostly red (%d %d)", quarter[0], quarter[2]);
    /* the clip bounds it */
    bitmap c = make_bitmap(40, 40);
    CGContextClipToRect(c.c, CGRectMake(0, 0, 20, 40));
    CGContextDrawConicGradient(c.c, g, CGPointMake(20, 20), M_PI / 2);
    CHECK(at(c, 5, 20)[3] == 255 && at(c, 30, 20)[3] == 0, "conic: inside the clip only");
    free_bitmap(c);
    CGGradientRelease(g); CGColorSpaceRelease(rgb);
    free_bitmap(b);
}

int main(void) {
    @autoreleasepool {
        icc();
        lab_and_indexed();
        variants();
        providers();
        fonts();
        layers();
        conic();
        printf("cgextras: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
