// Core Graphics' PDF object model from C (CGPDFTest.app, issue #274): documents read by isim's parser (classic and
// cross-reference-stream files, object streams, incremental updates, a damaged xref), the RC4 / AES-128 / AES-256
// standard security handler, permissions, page boxes and rotation, dictionaries, arrays, strings, streams, the
// content-stream scanner, and PDF contexts writing links, destinations, an outline and document info that the
// parser reads back. The fixtures come from make_fixtures.py and are checked by poppler there.
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <string.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[200]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

static CGPDFDocumentRef open_fixture(const char *name) {
    NSString *path = [[NSBundle mainBundle] pathForResource:@(name) ofType:nil];
    if (!path) return NULL;
    return CGPDFDocumentCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path]);
}

static NSString *text(CGPDFDictionaryRef d, const char *key) {
    CGPDFStringRef s;
    if (!CGPDFDictionaryGetString(d, key, &s)) return nil;
    return CFBridgingRelease(CGPDFStringCopyTextString(s));
}

static bool rect_eq(CGRect a, CGRect b) {
    return fabs(a.origin.x - b.origin.x) < 0.01 && fabs(a.origin.y - b.origin.y) < 0.01 &&
           fabs(a.size.width - b.size.width) < 0.01 && fabs(a.size.height - b.size.height) < 0.01;
}

/* the common document every fixture holds (make_fixtures.py, document()) */
static void common(const char *name, CGPDFDocumentRef doc, NSString *title) {
    CHECK(doc != NULL, "%s: opens", name);
    if (!doc) return;
    CHECK(CGPDFDocumentGetNumberOfPages(doc) == 2, "%s: 2 pages (%zu)", name, CGPDFDocumentGetNumberOfPages(doc));
    CGPDFDictionaryRef info = CGPDFDocumentGetInfo(doc), catalog = CGPDFDocumentGetCatalog(doc);
    CHECK([text(info, "Title") isEqual:title], "%s: info Title %s", name, text(info, "Title").UTF8String);
    const char *type = NULL, *mode = NULL;
    CHECK(CGPDFDictionaryGetName(catalog, "Type", &type) && !strcmp(type, "Catalog"), "%s: catalog /Type", name);
    CHECK(CGPDFDictionaryGetName(catalog, "PageMode", &mode) && !strcmp(mode, "UseOutlines"), "%s: catalog /PageMode", name);
    CGPDFArrayRef ident = CGPDFDocumentGetID(doc);
    CGPDFStringRef id0;
    CHECK(CGPDFArrayGetCount(ident) == 2 && CGPDFArrayGetString(ident, 0, &id0) && CGPDFStringGetLength(id0) == 16,
          "%s: file identifier", name);

    CGPDFPageRef p1 = CGPDFDocumentGetPage(doc, 1), p2 = CGPDFDocumentGetPage(doc, 2);
    CHECK(p1 && p2 && !CGPDFDocumentGetPage(doc, 3) && !CGPDFDocumentGetPage(doc, 0), "%s: pages 1 and 2, no 0 or 3", name);
    if (!p1 || !p2) return;
    CHECK(CGPDFPageGetPageNumber(p2) == 2 && CGPDFPageGetDocument(p2) == doc, "%s: page number and document", name);
    CHECK(rect_eq(CGPDFPageGetBoxRect(p1, kCGPDFMediaBox), CGRectMake(0, 0, 612, 792)), "%s: inherited media box", name);
    CHECK(rect_eq(CGPDFPageGetBoxRect(p1, kCGPDFArtBox), CGRectMake(0, 0, 612, 792)), "%s: art box defaults to the crop box", name);
    CHECK(rect_eq(CGPDFPageGetBoxRect(p2, kCGPDFCropBox), CGRectMake(10, 20, 280, 360)), "%s: crop box", name);
    CHECK(rect_eq(CGPDFPageGetBoxRect(p2, kCGPDFTrimBox), CGRectMake(10, 20, 280, 360)), "%s: trim box defaults to the crop box", name);
    CHECK(CGPDFPageGetRotationAngle(p1) == 0 && CGPDFPageGetRotationAngle(p2) == 90, "%s: rotation", name);

    CGPDFDictionaryRef pd = CGPDFPageGetDictionary(p1), res, fonts, f1;
    const char *base = NULL;
    CHECK(CGPDFDictionaryGetName(pd, "Type", &type) && !strcmp(type, "Page"), "%s: page dictionary", name);
    CHECK(!CGPDFDictionaryGetDictionary(pd, "Resources", &res), "%s: page 1's resources are inherited, not its own", name);
    CGPDFDictionaryRef parent;
    CHECK(CGPDFDictionaryGetDictionary(pd, "Parent", &parent) && CGPDFDictionaryGetDictionary(parent, "Resources", &res) &&
          CGPDFDictionaryGetDictionary(res, "Font", &fonts) && CGPDFDictionaryGetDictionary(fonts, "F1", &f1) &&
          CGPDFDictionaryGetName(f1, "BaseFont", &base) && !strcmp(base, "Helvetica"), "%s: resources through /Parent", name);

    CGPDFStreamRef contents;
    CGPDFDataFormat fmt = (CGPDFDataFormat)-1;
    CHECK(CGPDFDictionaryGetStream(pd, "Contents", &contents), "%s: /Contents stream", name);
    NSData *data = CFBridgingRelease(CGPDFStreamCopyData(contents, &fmt));
    NSString *s = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    CHECK(fmt == CGPDFDataFormatRaw && [s hasPrefix:@"BT /F1 24 Tf 72 700 Td (Hello CGPDF) Tj ET"], "%s: content decoded", name);
    CGPDFInteger length;
    CHECK(CGPDFDictionaryGetInteger(CGPDFStreamGetDictionary(contents), "Length", &length) && length > 0, "%s: stream dictionary", name);

    NSDictionary *outline = (__bridge NSDictionary *)CGPDFDocumentGetOutline(doc);
    NSArray *kids = outline[(__bridge NSString *)kCGPDFOutlineChildren];
    CHECK(kids.count == 2, "%s: outline has 2 items (%lu)", name, (unsigned long)kids.count);
    if (kids.count == 2) {
        NSDictionary *a = kids[0], *b = kids[1];
        NSDictionary *r = a[(__bridge NSString *)kCGPDFOutlineDestinationRect];
        CHECK([a[(__bridge NSString *)kCGPDFOutlineTitle] isEqual:@"Chapter 1"] &&
              [a[(__bridge NSString *)kCGPDFOutlineDestination] intValue] == 1 &&
              [r[@"X"] doubleValue] == 72 && [r[@"Y"] doubleValue] == 700, "%s: outline item 1 (XYZ on page 1)", name);
        CHECK([b[(__bridge NSString *)kCGPDFOutlineTitle] isEqual:@"Chapter 2"] &&
              [b[(__bridge NSString *)kCGPDFOutlineDestination] intValue] == 2, "%s: outline item 2 (named destination)", name);
    }
}

static void plain(void) {
    CGPDFDocumentRef doc = open_fixture("plain.pdf");
    common("plain", doc, @"Plain été");
    if (!doc) return;
    int major = 0, minor = 0;
    CGPDFDocumentGetVersion(doc, &major, &minor);
    CHECK(major == 1 && minor == 4, "plain: version %d.%d", major, minor);
    CHECK(!CGPDFDocumentIsEncrypted(doc) && CGPDFDocumentIsUnlocked(doc) && CGPDFDocumentAllowsPrinting(doc) &&
          CGPDFDocumentAllowsCopying(doc) && CGPDFDocumentGetAccessPermissions(doc) == 0xFF, "plain: not encrypted, all allowed");

    CGPDFDictionaryRef info = CGPDFDocumentGetInfo(doc);
    CHECK([text(info, "Author") isEqual:@"isim • tests"], "plain: PDFDocEncoding string (%s)", text(info, "Author").UTF8String);
    CGPDFStringRef date;
    NSDate *d = CGPDFDictionaryGetString(info, "CreationDate", &date) ? CFBridgingRelease(CGPDFStringCopyDate(date)) : nil;
    CHECK(fabs(d.timeIntervalSince1970 - 1709202896) < 1, "plain: CopyDate with a time zone (%f)", d.timeIntervalSince1970);
    CHECK(CGPDFDictionaryGetCount(info) == 4, "plain: dictionary count");
    __block int keys = 0;
    CGPDFDictionaryApplyBlock(info, ^bool(const char *key, CGPDFObjectRef value, void *ctx) {
        keys++;
        return CGPDFObjectGetType(value) == kCGPDFObjectTypeString && keys < 2;    /* stops after the second */
    }, NULL);
    CHECK(keys == 2, "plain: ApplyBlock stops when the block returns false");

    CGPDFDictionaryRef p2 = CGPDFPageGetDictionary(CGPDFDocumentGetPage(doc, 2));
    CGPDFArrayRef crop, contents;
    CGPDFInteger i0; CGPDFReal r2; CGPDFObjectRef o;
    CHECK(CGPDFDictionaryGetArray(p2, "CropBox", &crop) && CGPDFArrayGetCount(crop) == 4 && CGPDFArrayGetInteger(crop, 0, &i0) &&
          i0 == 10 && CGPDFArrayGetNumber(crop, 2, &r2) && r2 == 290 && !CGPDFArrayGetName(crop, 1, NULL), "plain: array values");
    CHECK(CGPDFArrayGetObject(crop, 3, &o) && CGPDFObjectGetType(o) == kCGPDFObjectTypeInteger &&
          CGPDFObjectGetValue(o, kCGPDFObjectTypeReal, &r2) && r2 == 380, "plain: an integer read as a real");
    CHECK(CGPDFDictionaryGetArray(p2, "Contents", &contents) && CGPDFArrayGetCount(contents) == 2 &&
          CGPDFArrayGetStream(contents, 1, NULL), "plain: references resolve to streams");
    __block size_t seen = 0;
    CGPDFArrayApplyBlock(crop, ^bool(size_t index, CGPDFObjectRef value, void *ctx) { seen += index; return true; }, NULL);
    CHECK(seen == 6, "plain: Array ApplyBlock");

    CGPDFDictionaryRef xobjs, im;
    CGPDFStreamRef image = NULL;
    CGPDFDictionaryRef pages;
    CGPDFDictionaryGetDictionary(CGPDFDocumentGetCatalog(doc), "Pages", &pages);
    CGPDFDictionaryRef res;
    CGPDFDictionaryGetDictionary(pages, "Resources", &res);
    CHECK(CGPDFDictionaryGetDictionary(res, "XObject", &xobjs) && CGPDFDictionaryGetStream(xobjs, "Im1", &image), "plain: image XObject");
    im = CGPDFStreamGetDictionary(image);
    CGPDFDataFormat fmt;
    NSData *pixels = CFBridgingRelease(CGPDFStreamCopyData(image, &fmt));
    CHECK(pixels.length == 12 && ((const uint8_t *)pixels.bytes)[0] == 255 && ((const uint8_t *)pixels.bytes)[4] == 255,
          "plain: image samples (%lu)", (unsigned long)pixels.length);
    CGPDFInteger w;
    CHECK(CGPDFDictionaryGetInteger(im, "Width", &w) && w == 2, "plain: image dictionary");

    CGPDFDocumentRetain(doc);
    CGPDFDocumentRelease(doc);
    CGPDFDocumentRelease(doc);
}

static void others(void) {
    CGPDFDocumentRef doc = open_fixture("objstm.pdf");
    common("objstm", doc, @"Plain été");
    int major, minor;
    CGPDFDocumentGetVersion(doc, &major, &minor);
    CHECK(major == 1 && minor == 5, "objstm: version");
    CGPDFDocumentRelease(doc);

    doc = open_fixture("incremental.pdf");
    common("incremental", doc, @"Updated title");
    CHECK([text(CGPDFDocumentGetInfo(doc), "Author") isEqual:@"second revision"], "incremental: the newer revision wins");
    CGPDFDocumentRelease(doc);

    doc = open_fixture("damaged.pdf");
    common("damaged", doc, @"Plain été");
    CGPDFDocumentRelease(doc);

    NSData *junk = [@"%PDF-1.4\nnot really a pdf" dataUsingEncoding:NSASCIIStringEncoding];
    CGDataProviderRef prov = CGDataProviderCreateWithCFData((__bridge CFDataRef)junk);
    doc = CGPDFDocumentCreateWithProvider(prov);
    CHECK(doc == NULL || CGPDFDocumentGetNumberOfPages(doc) == 0, "junk: no document");
    CGPDFDocumentRelease(doc);
    CGDataProviderRelease(prov);
}

static void encrypted(void) {
    const char *names[] = { "rc4.pdf", "aes256.pdf" };
    for (int k = 0; k < 2; k++) {
        CGPDFDocumentRef doc = open_fixture(names[k]);
        CHECK(doc && CGPDFDocumentIsEncrypted(doc) && !CGPDFDocumentIsUnlocked(doc), "%s: encrypted and locked", names[k]);
        if (!doc) continue;
        CHECK(!CGPDFDocumentUnlockWithPassword(doc, "wrong") && !CGPDFDocumentIsUnlocked(doc), "%s: a wrong password", names[k]);
        CHECK(CGPDFDocumentUnlockWithPassword(doc, "user") && CGPDFDocumentIsUnlocked(doc), "%s: the user password", names[k]);
        common(names[k], doc, @"Plain été");
        CHECK(CGPDFDocumentAllowsPrinting(doc) && !CGPDFDocumentAllowsCopying(doc), "%s: may print, not copy", names[k]);
        CGPDFAccessPermissions p = CGPDFDocumentGetAccessPermissions(doc);
        CHECK((p & kCGPDFAllowsLowQualityPrinting) && !(p & kCGPDFAllowsContentCopying) && !(p & kCGPDFAllowsDocumentChanges),
              "%s: access permissions 0x%x", names[k], p);
        CGContextRef ctx = CGBitmapContextCreate(NULL, 612, 792, 8, 0, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
        CGContextFillRect(ctx, CGRectMake(0, 0, 612, 792));
        CGContextDrawPDFPage(ctx, CGPDFDocumentGetPage(doc, 1));
        const uint8_t *px = CGBitmapContextGetData(ctx);
        const uint8_t *at = px + (792 - 1 - 50) * CGBitmapContextGetBytesPerRow(ctx) + 35 * 4;
        CHECK(at[2] > 200 && at[0] < 60, "%s: an unlocked page renders (%d %d %d)", names[k], at[0], at[1], at[2]);
        CGContextRelease(ctx);
        CGPDFDocumentRelease(doc);

        doc = open_fixture(names[k]);
        CHECK(CGPDFDocumentUnlockWithPassword(doc, "owner") && CGPDFDocumentAllowsCopying(doc) &&
              CGPDFDocumentGetAccessPermissions(doc) == 0xFF, "%s: the owner password allows everything", names[k]);
        CHECK([text(CGPDFDocumentGetInfo(doc), "Title") isEqual:@"Plain été"], "%s: owner-unlocked strings", names[k]);
        CGPDFDocumentRelease(doc);
    }
    CGPDFDocumentRef doc = open_fixture("aes128.pdf");
    CHECK(doc && CGPDFDocumentIsEncrypted(doc) && CGPDFDocumentIsUnlocked(doc), "aes128: an empty user password unlocks by itself");
    common("aes128", doc, @"Plain été");
    CHECK(!CGPDFDocumentAllowsCopying(doc) && CGPDFDocumentAllowsPrinting(doc), "aes128: permissions");
    CGPDFDocumentRelease(doc);
}

/* the scanner: operators and their operands */
static NSMutableString *trace;
static void op_Tf(CGPDFScannerRef s, void *info) {
    CGPDFReal size; const char *font;
    bool ok = CGPDFScannerPopNumber(s, &size) && CGPDFScannerPopName(s, &font);
    [trace appendFormat:@"Tf(%s %g) ", ok ? font : "?", size];
    CGPDFContentStreamRef cs = CGPDFScannerGetContentStream(s);
    CGPDFObjectRef f = ok ? CGPDFContentStreamGetResource(cs, "Font", font) : NULL;
    CGPDFDictionaryRef fd; const char *base = "";
    if (f && CGPDFObjectGetValue(f, kCGPDFObjectTypeDictionary, &fd)) CGPDFDictionaryGetName(fd, "BaseFont", &base);
    [trace appendFormat:@"font=%s ", base];
}
static void op_Tj(CGPDFScannerRef s, void *info) {
    CGPDFStringRef str;
    if (CGPDFScannerPopString(s, &str)) [trace appendFormat:@"Tj(%@) ", CFBridgingRelease(CGPDFStringCopyTextString(str))];
}
static void op_re(CGPDFScannerRef s, void *info) {
    CGPDFReal v[4];
    for (int i = 3; i >= 0; i--) if (!CGPDFScannerPopNumber(s, &v[i])) v[i] = -1;
    CGPDFInteger notint;
    [trace appendFormat:@"re(%g %g %g %g%s) ", v[0], v[1], v[2], v[3], CGPDFScannerPopInteger(s, &notint) ? " extra" : ""];
}
static void op_Do(CGPDFScannerRef s, void *info) {
    const char *n;
    if (CGPDFScannerPopName(s, &n)) [trace appendFormat:@"Do(%s) ", n];
}
static void op_d(CGPDFScannerRef s, void *info) {
    CGPDFReal phase; CGPDFArrayRef a;
    if (CGPDFScannerPopNumber(s, &phase) && CGPDFScannerPopArray(s, &a)) [trace appendFormat:@"d(%zu %g) ", CGPDFArrayGetCount(a), phase];
}
static void op_BI(CGPDFScannerRef s, void *info) {
    CGPDFStreamRef st; CGPDFDataFormat f;
    if (!CGPDFScannerPopStream(s, &st)) return;
    NSData *d = CFBridgingRelease(CGPDFStreamCopyData(st, &f));
    CGPDFInteger w = 0;
    CGPDFDictionaryGetInteger(CGPDFStreamGetDictionary(st), "W", &w);
    [trace appendFormat:@"BI(%ld %lu %d) ", w, (unsigned long)d.length, d.length ? ((const uint8_t *)d.bytes)[0] : -1];
}
static void op_S(CGPDFScannerRef s, void *info) {
    [trace appendString:@"S "];
    CGPDFScannerStop(s);
}
static void op_simple(CGPDFScannerRef s, void *info) { [trace appendString:@"op "]; }

static void scanner(void) {
    CGPDFDocumentRef doc = open_fixture("plain.pdf");
    if (!doc) { CHECK(0, "scanner: plain.pdf"); return; }
    CGPDFOperatorTableRef t = CGPDFOperatorTableCreate();
    CGPDFOperatorTableSetCallback(t, "Tf", op_Tf);
    CGPDFOperatorTableSetCallback(t, "Tj", op_Tj);
    CGPDFOperatorTableSetCallback(t, "re", op_re);
    CGPDFOperatorTableSetCallback(t, "Do", op_Do);
    CGPDFOperatorTableSetCallback(t, "d", op_d);
    CGPDFOperatorTableSetCallback(t, "BI", op_BI);
    CGPDFOperatorTableSetCallback(t, "q", op_simple);

    trace = [NSMutableString string];
    CGPDFContentStreamRef cs = CGPDFContentStreamCreateWithPage(CGPDFDocumentGetPage(doc, 1));
    CHECK(CFArrayGetCount(CGPDFContentStreamGetStreams(cs)) == 1, "scanner: page 1 has one content stream");
    CGPDFScannerRef sc = CGPDFScannerCreate(cs, t, NULL);
    CHECK(CGPDFScannerScan(sc), "scanner: page 1 scans to the end");
    CHECK([trace isEqual:@"Tf(F1 24) font=Helvetica Tj(Hello CGPDF) re(10 20 50 60) op Do(Im1) "], "scanner: page 1 operands: %s", trace.UTF8String);
    CGPDFScannerRelease(sc);
    CGPDFContentStreamRelease(cs);

    trace = [NSMutableString string];
    cs = CGPDFContentStreamCreateWithPage(CGPDFDocumentGetPage(doc, 2));
    CHECK(CFArrayGetCount(CGPDFContentStreamGetStreams(cs)) == 2, "scanner: page 2 has two content streams");
    CHECK(CGPDFContentStreamGetResource(cs, "Font", "F1") != NULL && CGPDFContentStreamGetResource(cs, "Font", "F9") == NULL,
          "scanner: page resources");
    sc = CGPDFScannerCreate(cs, t, NULL);
    CHECK(CGPDFScannerScan(sc), "scanner: page 2 scans");
    CHECK([trace isEqual:@"d(2 0) Tj(multi word) BI(1 1 128) "], "scanner: dash array, inline image: %s", trace.UTF8String);
    CGPDFScannerRelease(sc);

    CGPDFOperatorTableSetCallback(t, "S", op_S);
    trace = [NSMutableString string];
    sc = CGPDFScannerCreate(cs, t, NULL);
    CHECK(!CGPDFScannerScan(sc) && [trace isEqual:@"S "], "scanner: Stop ends the scan early: %s", trace.UTF8String);
    CGPDFScannerRelease(sc);
    CGPDFContentStreamRelease(cs);
    CGPDFOperatorTableRelease(t);
    CGPDFDocumentRelease(doc);
}

/* the rotated page drawn with CGPDFPageGetDrawingTransform shows the page turned 90 degrees clockwise */
static void drawing(void) {
    CGPDFDocumentRef doc = open_fixture("plain.pdf");
    CGPDFPageRef p2 = CGPDFDocumentGetPage(doc, 2);
    CGAffineTransform m = CGPDFPageGetDrawingTransform(p2, kCGPDFCropBox, CGRectMake(0, 0, 360, 280), 0, true);
    CGPoint a = CGPointApplyAffineTransform(CGPointMake(10, 20), m), b = CGPointApplyAffineTransform(CGPointMake(290, 380), m);
    CHECK(fabs(a.x - 0) < 0.01 && fabs(a.y - 280) < 0.01 && fabs(b.x - 360) < 0.01 && fabs(b.y - 0) < 0.01,
          "drawing: transform maps the crop box, rotated (%g,%g) (%g,%g)", a.x, a.y, b.x, b.y);
    CGContextRef ctx = CGBitmapContextCreate(NULL, 360, 280, 8, 0, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, 360, 280));
    CGContextConcatCTM(ctx, m);
    CGContextDrawPDFPage(ctx, p2);
    const uint8_t *px = CGBitmapContextGetData(ctx);
    size_t bpr = CGBitmapContextGetBytesPerRow(ctx);
    /* page point (t, t) on the red line: crop (t-10, t-20), then rotated: (t-20, 290-t) */
    for (int t = 120; t <= 180; t += 30) {
        int x = t - 20, y = 290 - t, red = 0;
        for (int dy = -2; dy <= 2; dy++)
            for (int dx = -2; dx <= 2; dx++) {
                const uint8_t *q = px + (279 - (y + dy)) * bpr + (x + dx) * 4;
                if (q[0] > 180 && q[1] < 90 && q[2] < 90) red = 1;
            }
        CHECK(red, "drawing: the red line at (%d,%d)", x, y);
    }
    CGContextRelease(ctx);
    CGPDFDocumentRelease(doc);
}

/* a PDF context's links, destinations, outline and info, read back */
static void writing(void) {
    CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
    CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData(data);
    CGRect media = CGRectMake(0, 0, 300, 400);
    NSDictionary *aux = @{ (__bridge NSString *)kCGPDFContextTitle: @"Written é",
                           (__bridge NSString *)kCGPDFContextAuthor: @"CGPDFTest",
                           (__bridge NSString *)kCGPDFContextKeywords: @[ @"one", @"two" ] };
    CGContextRef c = CGPDFContextCreate(consumer, &media, (__bridge CFDictionaryRef)aux);
    CHECK(c != NULL, "writing: PDF context");
    CGPDFContextBeginPage(c, NULL);
    CGContextSetRGBFillColor(c, 0, 0.5, 0, 1);
    CGContextFillRect(c, CGRectMake(20, 20, 100, 40));
    CGPDFContextSetURLForRect(c, (__bridge CFURLRef)[NSURL URLWithString:@"https://example.com/a"], CGRectMake(20, 20, 100, 40));
    CGPDFContextSetDestinationForRect(c, CFSTR("second"), CGRectMake(20, 300, 100, 40));
    CGPDFContextEndPage(c);
    CGPDFContextBeginPage(c, NULL);
    CGPDFContextAddDestinationAtPoint(c, CFSTR("second"), CGPointMake(50, 350));
    CGPDFContextEndPage(c);
    NSDictionary *outline = @{ (__bridge NSString *)kCGPDFOutlineChildren: @[
        @{ (__bridge NSString *)kCGPDFOutlineTitle: @"First page", (__bridge NSString *)kCGPDFOutlineDestination: @1 },
        @{ (__bridge NSString *)kCGPDFOutlineTitle: @"Second", (__bridge NSString *)kCGPDFOutlineDestination: @2,
           (__bridge NSString *)kCGPDFOutlineChildren: @[ @{ (__bridge NSString *)kCGPDFOutlineTitle: @"Nested",
                                                              (__bridge NSString *)kCGPDFOutlineDestination: @"second" } ] } ] };
    CGPDFContextSetOutline(c, (__bridge CFDictionaryRef)outline);
    CGPDFContextClose(c);
    CGContextRelease(c);
    CGDataConsumerRelease(consumer);

    CGDataProviderRef prov = CGDataProviderCreateWithCFData(data);
    CGPDFDocumentRef doc = CGPDFDocumentCreateWithProvider(prov);
    CHECK(doc && CGPDFDocumentGetNumberOfPages(doc) == 2, "writing: reads back with 2 pages");
    if (!doc) return;
    CGPDFDictionaryRef info = CGPDFDocumentGetInfo(doc);
    CHECK([text(info, "Title") isEqual:@"Written é"] && [text(info, "Author") isEqual:@"CGPDFTest"], "writing: info %s / %s",
          text(info, "Title").UTF8String, text(info, "Author").UTF8String);
    CHECK([text(info, "Keywords") containsString:@"one"] && [text(info, "Keywords") containsString:@"two"], "writing: keywords");
    CHECK(rect_eq(CGPDFPageGetBoxRect(CGPDFDocumentGetPage(doc, 1), kCGPDFMediaBox), media), "writing: media box");

    CGPDFArrayRef annots;
    CGPDFDictionaryRef link = NULL, action;
    CGPDFStringRef uri;
    bool found = false;
    if (CGPDFDictionaryGetArray(CGPDFPageGetDictionary(CGPDFDocumentGetPage(doc, 1)), "Annots", &annots))
        for (size_t i = 0; i < CGPDFArrayGetCount(annots); i++)
            if (CGPDFArrayGetDictionary(annots, i, &link) && CGPDFDictionaryGetDictionary(link, "A", &action) &&
                CGPDFDictionaryGetString(action, "URI", &uri) && CGPDFStringGetLength(uri) == 21 &&
                !memcmp(CGPDFStringGetBytePtr(uri), "https://example.com/a", 21)) {
                CGPDFArrayRef r; CGPDFReal x0, y0, x1, y1;
                found = CGPDFDictionaryGetArray(link, "Rect", &r) && CGPDFArrayGetNumber(r, 0, &x0) && CGPDFArrayGetNumber(r, 1, &y0) &&
                        CGPDFArrayGetNumber(r, 2, &x1) && CGPDFArrayGetNumber(r, 3, &y1) &&
                        fabs(x0 - 20) < 1 && fabs(y0 - 20) < 1 && fabs(x1 - 120) < 1 && fabs(y1 - 60) < 1;
            }
    CHECK(found, "writing: a URI link annotation over the rect");

    NSDictionary *back = (__bridge NSDictionary *)CGPDFDocumentGetOutline(doc);
    NSArray *kids = back[(__bridge NSString *)kCGPDFOutlineChildren];
    CHECK(kids.count == 2 && [kids[0][(__bridge NSString *)kCGPDFOutlineTitle] isEqual:@"First page"] &&
          [kids[0][(__bridge NSString *)kCGPDFOutlineDestination] intValue] == 1 &&
          [kids[1][(__bridge NSString *)kCGPDFOutlineDestination] intValue] == 2, "writing: outline reads back");
    NSArray *nested = kids.count == 2 ? kids[1][(__bridge NSString *)kCGPDFOutlineChildren] : nil;
    CHECK(nested.count == 1 && [nested[0][(__bridge NSString *)kCGPDFOutlineTitle] isEqual:@"Nested"] &&
          [nested[0][(__bridge NSString *)kCGPDFOutlineDestination] intValue] == 2, "writing: a nested item to a named destination");
    CGPDFDocumentRelease(doc);
    CGDataProviderRelease(prov);
    CFRelease(data);
}

int main(void) {
    @autoreleasepool {
        plain();
        others();
        encrypted();
        scanner();
        drawing();
        writing();
        printf("cgpdf: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
