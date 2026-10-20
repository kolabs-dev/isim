// PDFKit from Objective-C (PDFKitTest.app, issue #269): PDFDocument over the CGPDF fixtures (tests/cgpdf/fixtures):
// attributes, pages, boxes, rotation, labels, text, the outline and destinations, encryption with notifications and
// the delegate; then a document built from pages (an image, a blank page, a rotated page of another document), edited,
// written with its outline and attributes, and read back.
#import <PDFKit/PDFKit.h>
#include <stdio.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[200]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

static PDFDocument *fixture(NSString *name) {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:nil];
    return path ? [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]] : nil;
}
static BOOL near(CGFloat a, CGFloat b) { return fabs(a - b) < 0.6; }
static BOOL rect_eq(CGRect a, CGRect b) {
    return near(a.origin.x, b.origin.x) && near(a.origin.y, b.origin.y) && near(a.size.width, b.size.width) && near(a.size.height, b.size.height);
}

/* RGBA of a pixel of a UIImage (y-down, in points of a scale-1 rendering) */
static void pixel(UIImage *image, int x, int y, uint8_t out[4]) {
    CGImageRef cg = image.CGImage;
    size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);
    uint8_t *buf = calloc(w * h, 4);
    CGContextRef c = CGBitmapContextCreate(buf, w, h, 8, w * 4, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(c, CGRectMake(0, 0, w, h), cg);
    CGFloat s = image.scale;
    size_t px = (size_t)(x * s), py = (size_t)(y * s);
    memcpy(out, buf + (py < h ? py : h - 1) * w * 4 + (px < w ? px : w - 1) * 4, 4);
    CGContextRelease(c);
    free(buf);
}

@interface MyPage : PDFPage @end
@implementation MyPage @end

@interface Delegate : NSObject <PDFDocumentDelegate>
@property int unlocked;
@end
@implementation Delegate
- (void)documentDidUnlock:(NSNotification *)n { self.unlocked++; }
- (Class)classForPage { return [MyPage class]; }
@end

static void reading(void) {
    PDFDocument *doc = fixture(@"plain.pdf");
    CHECK(doc && doc.pageCount == 2 && doc.majorVersion == 1 && doc.minorVersion == 4, "plain: 2 pages, version 1.4");
    if (!doc) return;
    NSDictionary *a = doc.documentAttributes;
    CHECK([a[PDFDocumentTitleAttribute] isEqual:@"Plain été"] && [a[PDFDocumentAuthorAttribute] isEqual:@"isim • tests"],
          "plain: title and author");
    CHECK([a[PDFDocumentKeywordsAttribute] isEqual:(@[ @"pdf", @"cgpdf" ])], "plain: keywords as an array");
    CHECK(fabs([a[PDFDocumentCreationDateAttribute] timeIntervalSince1970] - 1709202896) < 1, "plain: creation date");
    CHECK(!doc.isEncrypted && !doc.isLocked && doc.permissionsStatus == kPDFDocumentPermissionsOwner && doc.allowsCopying &&
          doc.allowsPrinting && doc.accessPermissions == 0xFF, "plain: not encrypted, owner, everything allowed");
    CHECK(doc.documentRef != NULL && [doc.documentURL.lastPathComponent isEqual:@"plain.pdf"], "plain: documentRef and documentURL");

    PDFPage *p1 = [doc pageAtIndex:0], *p2 = [doc pageAtIndex:1];
    CHECK(p1 && p2 && ![doc pageAtIndex:2] && [doc indexForPage:p2] == 1 && p2.document == doc && p1.pageRef, "plain: pages");
    CHECK(rect_eq([p1 boundsForBox:kPDFDisplayBoxMediaBox], CGRectMake(0, 0, 612, 792)) &&
          rect_eq([p2 boundsForBox:kPDFDisplayBoxCropBox], CGRectMake(10, 20, 280, 360)) &&
          rect_eq([p2 boundsForBox:kPDFDisplayBoxTrimBox], CGRectMake(10, 20, 280, 360)), "plain: boxes");
    CHECK(p1.rotation == 0 && p2.rotation == 90, "plain: rotation");
    CHECK([p1.label isEqual:@"1"] && [p2.label isEqual:@"2"], "plain: labels without /PageLabels");

    CGAffineTransform t = [p2 transformForBox:kPDFDisplayBoxCropBox];
    CGPoint lo = CGPointApplyAffineTransform(CGPointMake(10, 20), t), hi = CGPointApplyAffineTransform(CGPointMake(290, 380), t);
    CHECK(near(lo.x, 0) && near(lo.y, 280) && near(hi.x, 360) && near(hi.y, 0), "plain: transform(for:) turns the crop box");
    /* the rotated page drawn by draw(with:to:): its red line from (100,100) to (200,200) lands at (t-20, 290-t) */
    CGContextRef c = CGBitmapContextCreate(NULL, 360, 280, 8, 0, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(c, 1, 1, 1, 1);
    CGContextFillRect(c, CGRectMake(0, 0, 360, 280));
    [p2 drawWithBox:kPDFDisplayBoxCropBox toContext:c];
    const uint8_t *px = CGBitmapContextGetData(c);
    int red = 0;
    for (int tt = 120; tt <= 180; tt += 30)
        for (int dy = -2; dy <= 2; dy++) for (int dx = -2; dx <= 2; dx++) {
            const uint8_t *q = px + (279 - (290 - tt + dy)) * CGBitmapContextGetBytesPerRow(c) + (tt - 20 + dx) * 4;
            if (q[0] > 180 && q[1] < 90 && q[2] < 90) { red++; dy = dx = 3; }
        }
    CHECK(red == 3, "plain: draw(with:to:) draws the rotated page turned (%d of 3)", red);
    CGContextRelease(c);

    UIImage *thumb = [p1 thumbnailOfSize:CGSizeMake(100, 100) forBox:kPDFDisplayBoxMediaBox];
    CHECK(near(thumb.size.width, 77) && near(thumb.size.height, 100), "plain: thumbnail fits the size (%gx%g)", thumb.size.width, thumb.size.height);
    UIImage *full = [p1 thumbnailOfSize:CGSizeMake(612, 792) forBox:kPDFDisplayBoxMediaBox];
    uint8_t q[4], w[4];
    pixel(full, 35, 792 - 50, q); pixel(full, 300, 400, w);
    CHECK(q[2] > 200 && q[0] < 60 && w[0] > 240 && w[1] > 240 && w[2] > 240, "plain: thumbnail draws the page on white (%d %d %d)", q[0], q[1], q[2]);
    UIImage *turned = [p2 thumbnailOfSize:CGSizeMake(360, 360) forBox:kPDFDisplayBoxCropBox];
    CHECK(near(turned.size.width, 360) && near(turned.size.height, 280), "plain: a rotated page's thumbnail is landscape");

    PDFOutline *root = doc.outlineRoot;
    CHECK(root.numberOfChildren == 2 && root.document == doc, "plain: outline with 2 items");
    PDFOutline *o1 = [root childAtIndex:0], *o2 = [root childAtIndex:1];
    CHECK([o1.label isEqual:@"Chapter 1"] && o1.destination.page == p1 && near(o1.destination.point.x, 72) && near(o1.destination.point.y, 700) &&
          o1.destination.zoom == kPDFDestinationUnspecifiedValue && !o1.isOpen && o1.parent == root && o1.index == 0, "plain: outline item 1");
    CHECK([o2.label isEqual:@"Chapter 2"] && o2.destination.page == p2 && o2.destination.point.x == kPDFDestinationUnspecifiedValue &&
          o2.index == 1, "plain: a named destination (Fit)");
    CHECK([o1.destination compare:o2.destination] == NSOrderedAscending && [o2.destination compare:o1.destination] == NSOrderedDescending,
          "plain: destinations compare in reading order");
    PDFDestination *hi1 = [[PDFDestination alloc] initWithPage:p1 atPoint:CGPointMake(0, 700)];
    PDFDestination *lo1 = [[PDFDestination alloc] initWithPage:p1 atPoint:CGPointMake(0, 100)];
    CHECK([hi1 compare:lo1] == NSOrderedAscending && [[hi1 copy] compare:hi1] == NSOrderedSame, "destination: higher first, copies equal");

    PDFDocument *other = fixture(@"plain.pdf");
    Delegate *del = [Delegate new];
    other.delegate = del;
    CHECK([[other pageAtIndex:0] isKindOfClass:[MyPage class]] && other.pageClass == [PDFPage class], "delegate: classForPage");
}

static void text(void) {
    PDFDocument *doc = fixture(@"text.pdf");
    PDFPage *p1 = [doc pageAtIndex:0], *p2 = [doc pageAtIndex:1];
    CHECK([p1.string isEqual:@"First line\nSecond"] && p1.numberOfCharacters == 17, "text: page string");
    CHECK([p1.attributedString.string isEqual:p1.string], "text: attributed string");
    CGRect f = [p1 characterBoundsAtIndex:0];
    CHECK(near(f.origin.x, 72) && f.origin.y > 690 && CGRectGetMaxY(f) < 720 && f.size.width > 8, "text: character bounds in page space (%g %g %g %g)",
          f.origin.x, f.origin.y, f.size.width, f.size.height);
    CHECK([p1 characterIndexAtPoint:CGPointMake(CGRectGetMidX(f), CGRectGetMidY(f))] == 0 && [p1 characterIndexAtPoint:CGPointMake(500, 100)] == -1,
          "text: character index at a point");
    CHECK(CGRectIsEmpty([p1 characterBoundsAtIndex:99]), "text: bounds past the end are empty");
    CGRect t0 = [p2 characterBoundsAtIndex:0];
    CHECK([p2.string isEqual:@"Turned"] && CGRectContainsPoint(t0, CGPointMake(55, 305)), "text: a rotated page's bounds in page space (%g %g %g %g)",
          t0.origin.x, t0.origin.y, t0.size.width, t0.size.height);
    CHECK([doc.string isEqual:@"First line\nSecond\nTurned"], "text: document string");
    CHECK([p1.label isEqual:@"i"] && [p2.label isEqual:@"A-5"], "text: page labels (%s, %s)", p1.label.UTF8String, p2.label.UTF8String);
}

static void encrypted(void) {
    PDFDocument *doc = fixture(@"rc4.pdf");
    Delegate *del = [Delegate new];
    doc.delegate = del;
    __block int posted = 0;
    id obs = [[NSNotificationCenter defaultCenter] addObserverForName:PDFDocumentDidUnlockNotification object:doc queue:nil
                                                           usingBlock:^(NSNotification *n) { posted++; }];
    CHECK(doc && doc.isEncrypted && doc.isLocked && doc.permissionsStatus == kPDFDocumentPermissionsNone && !doc.allowsPrinting,
          "rc4: locked, no permissions");
    CHECK(![doc unlockWithPassword:@"nope"] && doc.isLocked && posted == 0, "rc4: a wrong password");
    CHECK([doc unlockWithPassword:@"user"] && !doc.isLocked && doc.permissionsStatus == kPDFDocumentPermissionsUser, "rc4: the user password");
    CHECK(posted == 1 && del.unlocked == 1, "rc4: the unlock notification and the delegate");
    CHECK(doc.allowsPrinting && !doc.allowsCopying && !doc.allowsDocumentChanges && (doc.accessPermissions & PDFAllowsLowQualityPrinting),
          "rc4: the user's permissions");
    CHECK([doc.documentAttributes[PDFDocumentTitleAttribute] isEqual:@"Plain été"] && doc.outlineRoot.numberOfChildren == 2,
          "rc4: attributes and outline once unlocked");
    CHECK([doc unlockWithPassword:@"owner"] && doc.permissionsStatus == kPDFDocumentPermissionsOwner && doc.allowsCopying, "rc4: the owner password");
    [[NSNotificationCenter defaultCenter] removeObserver:obs];

    PDFDocument *aes = fixture(@"aes128.pdf");
    CHECK(aes.isEncrypted && !aes.isLocked && aes.permissionsStatus == kPDFDocumentPermissionsUser && !aes.allowsCopying,
          "aes128: an empty user password opens it");
    PDFDocument *aes256 = fixture(@"aes256.pdf");
    CHECK(aes256.isLocked && [aes256 unlockWithPassword:@"user"] && [[aes256 pageAtIndex:0].string length] > 0, "aes256: unlocked text");
}

static void writing(void) {
    PDFDocument *doc = [[PDFDocument alloc] init];
    CHECK(doc.pageCount == 0 && !doc.isEncrypted && doc.permissionsStatus == kPDFDocumentPermissionsOwner && !doc.documentRef, "new: empty");
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(200, 100)];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext *c) { [[UIColor redColor] setFill]; UIRectFill(CGRectMake(0, 0, 200, 100)); }];
    PDFPage *imagePage = [[PDFPage alloc] initWithImage:img];
    CHECK(imagePage && rect_eq([imagePage boundsForBox:kPDFDisplayBoxMediaBox], CGRectMake(0, 0, 200, 100)) && !imagePage.pageRef,
          "image page: media box from the image");
    PDFPage *boxed = [[PDFPage alloc] initWithImage:img options:@{ PDFPageImageInitializationOptionMediaBox: [NSValue valueWithCGRect:CGRectMake(0, 0, 300, 300)],
                                                                  PDFPageImageInitializationOptionRotation: @90 }];
    CHECK(rect_eq([boxed boundsForBox:kPDFDisplayBoxMediaBox], CGRectMake(0, 0, 300, 300)) && boxed.rotation == 90, "image page: options");
    PDFPage *blank = [[PDFPage alloc] init];
    CHECK(rect_eq([blank boundsForBox:kPDFDisplayBoxMediaBox], CGRectMake(0, 0, 612, 792)) && !blank.document, "blank page: US Letter");
    [blank setBounds:CGRectMake(0, 0, 200, 200) forBox:kPDFDisplayBoxMediaBox];
    [blank setBounds:CGRectMake(10, 10, 100, 100) forBox:kPDFDisplayBoxCropBox];
    CHECK(rect_eq([blank boundsForBox:kPDFDisplayBoxCropBox], CGRectMake(10, 10, 100, 100)) &&
          rect_eq([blank boundsForBox:kPDFDisplayBoxArtBox], CGRectMake(10, 10, 100, 100)), "blank page: setBounds, art defaults to crop");
    PDFPage *turned = [[fixture(@"plain.pdf") pageAtIndex:1] copy];

    [doc insertPage:imagePage atIndex:0];
    [doc insertPage:blank atIndex:1];
    [doc insertPage:turned atIndex:2];
    [doc exchangePageAtIndex:0 withPageAtIndex:2];          /* turned, blank, image */
    CHECK(doc.pageCount == 3 && [doc pageAtIndex:0] == turned && [doc indexForPage:imagePage] == 2 && turned.document == doc, "new: insert, exchange");
    [doc removePageAtIndex:1];                               /* turned, image */
    CHECK(doc.pageCount == 2 && blank.document == nil && [doc indexForPage:blank] == NSNotFound, "new: remove");

    doc.documentAttributes = @{ PDFDocumentTitleAttribute: @"Built", PDFDocumentAuthorAttribute: @"PDFKitTest",
                                PDFDocumentKeywordsAttribute: @[ @"one", @"two" ] };
    PDFOutline *root = [[PDFOutline alloc] init];
    PDFOutline *first = [[PDFOutline alloc] init], *second = [[PDFOutline alloc] init], *nested = [[PDFOutline alloc] init];
    first.label = @"Turned page"; first.destination = [[PDFDestination alloc] initWithPage:turned atPoint:CGPointMake(0, 380)];
    second.label = @"Image"; second.destination = [[PDFDestination alloc] initWithPage:imagePage atPoint:CGPointZero];
    nested.label = @"Nested"; nested.destination = second.destination;
    [root insertChild:second atIndex:0];
    [root insertChild:first atIndex:0];
    [second insertChild:nested atIndex:0];
    CHECK(root.numberOfChildren == 2 && second.index == 1 && nested.parent == second && [root childAtIndex:5] == nil, "outline: insertChild");
    PDFOutline *gone = [[PDFOutline alloc] init];
    [root insertChild:gone atIndex:1];
    [gone removeFromParent];
    CHECK(root.numberOfChildren == 2 && gone.parent == nil, "outline: removeFromParent");
    doc.outlineRoot = root;
    CHECK(first.document == doc && nested.document == doc, "outline: the document reaches every item");

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"pdfkit-test.pdf"];
    __block int began = 0, ended = 0;
    id o1 = [[NSNotificationCenter defaultCenter] addObserverForName:PDFDocumentDidBeginWriteNotification object:doc queue:nil usingBlock:^(NSNotification *n) { began++; }];
    id o2 = [[NSNotificationCenter defaultCenter] addObserverForName:PDFDocumentDidEndWriteNotification object:doc queue:nil usingBlock:^(NSNotification *n) { ended++; }];
    CHECK([doc writeToFile:path] && began == 1 && ended == 1, "write: to a file, with notifications");
    [[NSNotificationCenter defaultCenter] removeObserver:o1];
    [[NSNotificationCenter defaultCenter] removeObserver:o2];

    PDFDocument *back = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
    CHECK(back.pageCount == 2, "read back: 2 pages");
    CHECK(rect_eq([[back pageAtIndex:0] boundsForBox:kPDFDisplayBoxMediaBox], CGRectMake(0, 0, 360, 280)) && [back pageAtIndex:0].rotation == 0,
          "read back: the rotated page written turned");
    CHECK(rect_eq([[back pageAtIndex:1] boundsForBox:kPDFDisplayBoxMediaBox], CGRectMake(0, 0, 200, 100)), "read back: the image page");
    CHECK([back.documentAttributes[PDFDocumentTitleAttribute] isEqual:@"Built"] && [back.documentAttributes[PDFDocumentAuthorAttribute] isEqual:@"PDFKitTest"] &&
          [back.documentAttributes[PDFDocumentKeywordsAttribute] isEqual:(@[ @"one", @"two" ])], "read back: attributes");
    PDFOutline *broot = back.outlineRoot;
    CHECK(broot.numberOfChildren == 2 && [[broot childAtIndex:0].label isEqual:@"Turned page"] &&
          [broot childAtIndex:0].destination.page == [back pageAtIndex:0] && [broot childAtIndex:1].destination.page == [back pageAtIndex:1] &&
          [[broot childAtIndex:1] childAtIndex:0].destination.page == [back pageAtIndex:1], "read back: the outline");
    UIImage *t = [[back pageAtIndex:1] thumbnailOfSize:CGSizeMake(200, 100) forBox:kPDFDisplayBoxMediaBox];
    uint8_t q[4];
    pixel(t, 100, 50, q);
    CHECK(q[0] > 200 && q[1] < 60 && q[2] < 60, "read back: the image page draws red (%d %d %d)", q[0], q[1], q[2]);
    uint8_t px2[4];
    UIImage *t2 = [[back pageAtIndex:0] thumbnailOfSize:CGSizeMake(360, 280) forBox:kPDFDisplayBoxMediaBox];
    int found = 0;
    for (int dy = -2; dy <= 2 && !found; dy++) for (int dx = -2; dx <= 2 && !found; dx++) {
        pixel(t2, 130 + dx, 280 - 140 + dy, px2);
        if (px2[0] > 180 && px2[1] < 90 && px2[2] < 90) found = 1;
    }
    CHECK(found, "read back: the turned page's content kept");

    NSData *one = [[back pageAtIndex:1] dataRepresentation];
    PDFDocument *single = [[PDFDocument alloc] initWithData:one];
    CHECK(single.pageCount == 1 && rect_eq([[single pageAtIndex:0] boundsForBox:kPDFDisplayBoxMediaBox], CGRectMake(0, 0, 200, 100)),
          "page dataRepresentation: a one-page PDF");
    PDFDocument *copy = [back copy];
    CHECK(copy != back && copy.pageCount == 2, "document copy");
    CHECK(![[PDFDocument alloc] initWithData:[@"not a pdf" dataUsingEncoding:NSUTF8StringEncoding]], "junk data: nil");
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

int main(void) {
    @autoreleasepool {
        reading();
        text();
        encrypted();
        writing();
        printf("pdfkit: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
