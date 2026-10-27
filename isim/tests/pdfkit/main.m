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

/* PDFView off screen: layout, scale, navigation and history, conversions, display modes, notifications, links */
static void view(void) {
    PDFDocument *doc = fixture(@"plain.pdf");
    PDFView *v = [[PDFView alloc] initWithFrame:CGRectMake(0, 0, 400, 600)];
    __block NSMutableArray *names = [NSMutableArray array];
    id obs = [[NSNotificationCenter defaultCenter] addObserverForName:nil object:v queue:nil usingBlock:^(NSNotification *n) { [names addObject:n.name]; }];
    CHECK(v.displayMode == kPDFDisplaySinglePageContinuous && v.displayBox == kPDFDisplayBoxCropBox && v.displaysPageBreaks &&
          !v.autoScales && v.scaleFactor == 1 && !v.document && !v.documentView, "view: defaults");
    v.document = doc;
    CHECK([names containsObject:PDFViewDocumentChangedNotification] && v.currentPage == [doc pageAtIndex:0] && v.documentView,
          "view: document set, first page current");
    v.autoScales = YES;
    [v layoutIfNeeded];
    CGFloat fit = 400.0 / (612 + 8);
    CHECK(fabs(v.scaleFactor - fit) < 0.01 && fabs(v.scaleFactorForSizeToFit - fit) < 0.01, "view: autoScales fits the width (%g)", v.scaleFactor);
    CHECK(v.visiblePages.count >= 1 && v.visiblePages[0] == [doc pageAtIndex:0], "view: visible pages");
    CHECK(v.canGoToNextPage && !v.canGoToPreviousPage && !v.canGoToFirstPage && v.canGoToLastPage && !v.canGoBack, "view: can go");
    [names removeAllObjects];
    [v goToNextPage:nil];
    CHECK(v.currentPage == [doc pageAtIndex:1] && v.canGoBack && [names containsObject:PDFViewPageChangedNotification] &&
          [names containsObject:PDFViewChangedHistoryNotification], "view: next page, history");
    [v goBack:nil];
    CHECK(v.currentPage == [doc pageAtIndex:0] && v.canGoForward && !v.canGoBack, "view: back");
    [v goForward:nil];
    CHECK(v.currentPage == [doc pageAtIndex:1], "view: forward");
    PDFPage *p1 = [doc pageAtIndex:0];
    [v goToPage:p1];
    CGPoint inView = [v convertPoint:CGPointMake(72, 700) fromPage:p1];
    CGPoint back = [v convertPoint:inView toPage:p1];
    CHECK(fabs(back.x - 72) < 0.5 && fabs(back.y - 700) < 0.5 && [v pageForPoint:inView nearest:NO] == p1, "view: points to and from a page");
    CGRect r = [v convertRect:[v convertRect:CGRectMake(100, 100, 50, 20) fromPage:p1] toPage:p1];
    CHECK(fabs(r.origin.x - 100) < 0.5 && fabs(r.size.width - 50) < 0.5 && fabs(r.size.height - 20) < 0.5, "view: rects to and from a page");
    CHECK(([v areaOfInterestForPoint:[v convertPoint:CGPointMake(100, 708) fromPage:p1]] & kPDFTextArea) &&
          [v areaOfInterestForPoint:[v convertPoint:CGPointMake(400, 300) fromPage:p1]] == kPDFPageArea, "view: area of interest");
    PDFDestination *d = [[PDFDestination alloc] initWithPage:[doc pageAtIndex:1] atPoint:CGPointMake(10, 380)];
    [v goToDestination:d];
    CHECK(v.currentPage == [doc pageAtIndex:1] && v.currentDestination.page == [doc pageAtIndex:1], "view: go to a destination");

    [names removeAllObjects];
    CGFloat before = v.scaleFactor;
    [v zoomIn:nil];
    CHECK(fabs(v.scaleFactor - before * M_SQRT2) < 0.01 && !v.autoScales && [names containsObject:PDFViewScaleChangedNotification], "view: zoom in");
    v.scaleFactor = 100;
    CHECK(v.scaleFactor == v.maxScaleFactor && !v.canZoomIn && v.canZoomOut, "view: scale clamped to the maximum");
    v.minScaleFactor = 0.5;
    v.scaleFactor = 0.1;
    CHECK(v.scaleFactor == 0.5 && !v.canZoomOut, "view: and to the minimum");
    v.scaleFactor = 1;
    CGSize rs = [v rowSizeForPage:p1];
    CHECK(fabs(rs.width - 620) < 0.5 && fabs(rs.height - 801.5) < 0.5, "view: row size (%g x %g)", rs.width, rs.height);

    [names removeAllObjects];
    v.displayMode = kPDFDisplayTwoUp;
    [v layoutIfNeeded];
    CHECK([names containsObject:PDFViewDisplayModeChangedNotification] && v.documentView.subviews.count == 2, "view: two up shows a pair");
    rs = [v rowSizeForPage:p1];
    CHECK(fabs(rs.width - (620 + 368)) < 0.5, "view: a two-up row, the turned page landscape (%g)", rs.width);
    v.displaysAsBook = YES;
    [v goToPage:p1];
    [v layoutIfNeeded];
    CHECK(v.documentView.subviews.count == 1, "view: as a book the first page is alone");
    v.displayMode = kPDFDisplaySinglePage;
    v.displaysAsBook = NO;
    [v goToLastPage:nil];
    [v layoutIfNeeded];
    CHECK(v.documentView.subviews.count == 1 && v.currentPage == [doc pageAtIndex:1] && !v.canGoToLastPage, "view: single page");
    v.displayBox = kPDFDisplayBoxMediaBox;
    CHECK([names containsObject:PDFViewDisplayBoxChangedNotification], "view: display box");
    v.displayMode = kPDFDisplaySinglePageContinuous;
    v.displayDirection = kPDFDisplayDirectionHorizontal;
    v.autoScales = YES;
    [v layoutIfNeeded];
    CHECK(fabs(v.scaleFactor - 600.0 / 801.5) < 0.01, "view: horizontal fits the height (%g)", v.scaleFactor);
    [v usePageViewController:YES withViewOptions:nil];
    CHECK(v.isUsingPageViewController, "view: page view controller paging");
    [[NSNotificationCenter defaultCenter] removeObserver:obs];

    /* links: a PDF with a URL link and a link to page 2 */
    NSMutableData *data = [NSMutableData data];
    UIGraphicsBeginPDFContextToData(data, CGRectMake(0, 0, 200, 200), nil);
    UIGraphicsBeginPDFPage();
    UIGraphicsSetPDFContextURLForRect([NSURL URLWithString:@"https://example.com/l"], CGRectMake(10, 10, 50, 20));
    UIGraphicsSetPDFContextDestinationForRect(@"two", CGRectMake(10, 100, 50, 20));
    UIGraphicsBeginPDFPage();
    UIGraphicsAddPDFContextDestinationAtPoint(@"two", CGPointMake(0, 50));
    UIGraphicsEndPDFContext();
    PDFDocument *linked = [[PDFDocument alloc] initWithData:data];
    PDFView *lv = [[PDFView alloc] initWithFrame:CGRectMake(0, 0, 208, 500)];
    lv.document = linked;
    [lv layoutIfNeeded];
    PDFPage *l1 = [linked pageAtIndex:0];
    CGPoint urlAt = [lv convertPoint:CGPointMake(30, 175) fromPage:l1], destAt = [lv convertPoint:CGPointMake(30, 85) fromPage:l1];
    CHECK(([lv areaOfInterestForPoint:urlAt] & kPDFLinkArea) && ([lv areaOfInterestForPoint:destAt] & kPDFLinkArea) &&
          !([lv areaOfInterestForPoint:[lv convertPoint:CGPointMake(150, 100) fromPage:l1]] & kPDFLinkArea),
          "view: UIKit's PDF links are link areas");
}

/* ---- issue #358: selections, find, annotations, actions ---- */
@interface FindDelegate : NSObject <PDFDocumentDelegate>
@property (strong) NSMutableArray<NSString *> *events;
@end
@implementation FindDelegate
- (void)documentDidBeginDocumentFind:(NSNotification *)n { [self.events addObject:@"begin"]; }
- (void)documentDidBeginPageFind:(NSNotification *)n { [self.events addObject:[NSString stringWithFormat:@"page%@", n.userInfo[PDFDocumentPageIndexKey]]]; }
- (void)didMatchString:(PDFSelection *)s { [self.events addObject:[NSString stringWithFormat:@"match:%@", s.string]]; }
- (void)documentDidEndDocumentFind:(NSNotification *)n { [self.events addObject:@"end"]; }
@end

static void spin(BOOL (^until)(void)) {
    for (int i = 0; i < 200 && !until(); i++) [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

static void selections(void) {
    PDFDocument *doc = fixture(@"annots.pdf");
    PDFPage *p1 = [doc pageAtIndex:0], *p2 = [doc pageAtIndex:1];
    CHECK([p1.string hasPrefix:@"The quick brown fox\njumps over the lazy dog"], "selection: the fixture's text (%s)", p1.string.UTF8String);
    PDFSelection *r = [p1 selectionForRange:NSMakeRange(4, 5)];
    CHECK([r.string isEqual:@"quick"] && r.pages.count == 1 && r.pages[0] == p1 && [r numberOfTextRangesOnPage:p1] == 1 &&
          NSEqualRanges([r rangeAtIndex:0 onPage:p1], NSMakeRange(4, 5)), "selection: a range (%s)", r.string.UTF8String);
    CGRect b = [r boundsForPage:p1];
    CHECK(b.origin.x > 72 && b.size.width > 30 && b.origin.y > 690 && CGRectGetMaxY(b) < 725, "selection: bounds (%g %g %g %g)",
          b.origin.x, b.origin.y, b.size.width, b.size.height);
    CGPoint mid = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));
    CHECK([[p1 selectionForWordAtPoint:mid].string isEqual:@"quick"], "selection: the word at a point");
    CHECK([[p1 selectionForLineAtPoint:mid].string isEqual:@"The quick brown fox"], "selection: the line at a point");
    CGRect fox = [[p1 selectionForRange:NSMakeRange(16, 3)] boundsForPage:p1];
    PDFSelection *span = [p1 selectionFromPoint:CGPointMake(b.origin.x + 2, mid.y) toPoint:CGPointMake(CGRectGetMaxX(fox) - 2, CGRectGetMidY(fox))];
    CHECK([span.string isEqual:@"quick brown fox"], "selection: from a point to a point (%s)", span.string.UTF8String);
    PDFSelection *rect = [p1 selectionForRect:CGRectMake(60, 660, 400, 70)];
    CHECK([rect.string isEqual:@"The quick brown fox\njumps over the lazy dog"], "selection: a rect's text (%s)", rect.string.UTF8String);
    NSArray *lines = rect.selectionsByLine;
    CHECK(lines.count == 2 && [[lines[1] string] isEqual:@"jumps over the lazy dog"], "selection: by line");
    PDFSelection *e = [p1 selectionForRange:NSMakeRange(4, 5)];
    [e extendSelectionAtEnd:6]; [e extendSelectionAtStart:4];
    CHECK([e.string isEqual:@"The quick brown"], "selection: extended (%s)", e.string.UTF8String);
    [e extendSelectionAtEnd:-6];
    CHECK([e.string isEqual:@"The quick"], "selection: shrunk at the end");
    PDFSelection *l = [p1 selectionForRange:NSMakeRange(26, 3)];
    [l extendSelectionForLineBoundaries];
    CHECK([l.string isEqual:@"jumps over the lazy dog"], "selection: line boundaries (%s)", l.string.UTF8String);
    PDFSelection *both = [r copy];
    [both addSelection:[p2 selectionForRange:NSMakeRange(0, 6)]];
    CHECK(both.pages.count == 2 && [both.string isEqual:@"quick\nSecond"] && [r.string isEqual:@"quick"], "selection: add (copies stay)");
    PDFSelection *all = doc.selectionForEntireDocument;
    CHECK([all.string isEqual:doc.string], "selection: the entire document");
    PDFSelection *across = [doc selectionFromPage:p1 atCharacterIndex:44 toPage:p2 atCharacterIndex:5];
    CHECK([across.string isEqual:@"The end\nSecond"], "selection: across pages by character (%s)", across.string.UTF8String);
    if (@available(iOS 18.0, *)) {
        PDFSelection *words = [doc selectionFromPage:p1 atPoint:CGPointMake(mid.x + 3, mid.y) toPage:p1 atPoint:CGPointMake(CGRectGetMidX(fox), CGRectGetMidY(fox))
                                     withGranularity:PDFSelectionGranularityWord];
        CHECK([words.string isEqual:@"quick brown fox"], "selection: by word granularity (%s)", words.string.UTF8String);
    }

    /* find */
    NSArray *found = [doc findString:@"FOX" withOptions:NSCaseInsensitiveSearch];
    CHECK(found.count == 2 && [found[0] pages][0] == p1 && [found[1] pages][0] == p2 && [[found[1] string] isEqual:@"fox"], "find: all matches");
    CHECK([doc findString:@"FOX" withOptions:0].count == 0, "find: case sensitive");
    PDFSelection *next = [doc findString:@"the" fromSelection:nil withOptions:NSCaseInsensitiveSearch];
    PDFSelection *after = [doc findString:@"the" fromSelection:next withOptions:NSCaseInsensitiveSearch];
    PDFSelection *back = [doc findString:@"the" fromSelection:after withOptions:NSCaseInsensitiveSearch | NSBackwardsSearch];
    CHECK(NSEqualRanges([next rangeAtIndex:0 onPage:p1], NSMakeRange(0, 3)) && NSEqualRanges([after rangeAtIndex:0 onPage:p1], NSMakeRange(31, 3)) &&
          NSEqualRanges([back rangeAtIndex:0 onPage:p1], NSMakeRange(0, 3)), "find: from a selection, forward and back");
    FindDelegate *fd = [FindDelegate new];
    fd.events = [NSMutableArray array];
    doc.delegate = fd;
    __block int notes = 0;
    id obs = [[NSNotificationCenter defaultCenter] addObserverForName:PDFDocumentDidFindMatchNotification object:doc queue:nil
                                                           usingBlock:^(NSNotification *n) { if (n.userInfo[PDFDocumentFoundSelectionKey]) notes++; }];
    [doc beginFindString:@"fox" withOptions:0];
    CHECK(doc.isFinding, "find: begun (asynchronous)");
    spin(^BOOL { return !doc.isFinding; });
    CHECK([fd.events isEqual:(@[ @"begin", @"page0", @"match:fox", @"page1", @"match:fox", @"end" ])] && notes == 2,
          "find: notifications and delegate (%s)", [fd.events componentsJoinedByString:@","].UTF8String);
    [doc beginFindStrings:@[ @"dog", @"end" ] withOptions:0];
    [doc cancelFindString];
    CHECK(!doc.isFinding, "find: cancel");
    [[NSNotificationCenter defaultCenter] removeObserver:obs];
    doc.delegate = nil;

    PDFOutline *web = [doc.outlineRoot childAtIndex:0], *nextItem = [doc.outlineRoot childAtIndex:1];
    CHECK([web.action isKindOfClass:[PDFActionURL class]] && [((PDFActionURL *)web.action).URL.absoluteString isEqual:@"https://example.com/out"] &&
          [web.action.type isEqual:@"URL"], "action: an outline item's URL action");
    CHECK([nextItem.action isKindOfClass:[PDFActionNamed class]] && ((PDFActionNamed *)nextItem.action).name == kPDFActionNamedNextPage,
          "action: a named action");
}

static PDFAnnotation *first_of(PDFPage *page, NSString *type) {
    for (PDFAnnotation *a in page.annotations) if ([a.type isEqual:type]) return a;
    return nil;
}

static void annotations(void) {
    PDFDocument *doc = fixture(@"annots.pdf");
    PDFPage *p1 = [doc pageAtIndex:0], *p2 = [doc pageAtIndex:1];
    CHECK(p1.annotations.count == 11 && p2.annotations.count == 0, "annotations: read from /Annots (%lu)", (unsigned long)p1.annotations.count);
    PDFAnnotation *hl = first_of(p1, @"Highlight");
    CGFloat r = 0, g = 0, bl = 0, al = 0;
    [hl.color getRed:&r green:&g blue:&bl alpha:&al];
    CHECK(hl && rect_eq(hl.bounds, CGRectMake(70, 695, 210, 27)) && [hl.contents isEqual:@"Important"] && [hl.userName isEqual:@"Kev"] &&
          r == 1 && g == 1 && bl == 0 && hl.markupType == kPDFMarkupTypeHighlight && hl.shouldPrint && hl.shouldDisplay && hl.page == p1,
          "annotations: a highlight's properties");
    CHECK(hl.quadrilateralPoints.count == 4 && CGPointEqualToPoint([hl.quadrilateralPoints[0] CGPointValue], CGPointMake(2, 25)),
          "annotations: quadrilateral points relative to the bounds");
    CHECK([[hl valueForAnnotationKey:PDFAnnotationKeySubtype] isEqual:PDFAnnotationSubtypeHighlight] &&
          [hl.annotationKeyValues[PDFAnnotationKeyContents] isEqual:@"Important"], "annotations: the dictionary's values");
    PDFAnnotation *note = first_of(p1, @"Text");
    CHECK(note.iconType == kPDFTextAnnotationIconComment && [note.popup.type isEqual:@"Popup"] && note.popup.isOpen, "annotations: a note and its popup");
    PDFAnnotation *url = nil, *go = nil;
    for (PDFAnnotation *a in p1.annotations) if ([a.type isEqual:@"Link"]) { if (a.URL) url = a; else go = a; }
    CHECK([url.URL.absoluteString isEqual:@"https://example.com/fox"] && [url.action isKindOfClass:[PDFActionURL class]], "annotations: a URL link");
    CHECK(go.destination.page == p2 && near(go.destination.point.y, 720), "annotations: a link to a page");
    PDFAnnotation *ink = first_of(p1, @"Ink");
    CHECK(ink.paths.count == 1 && ink.border.lineWidth == 3 && CGRectContainsRect(CGRectMake(0, 0, 100, 100), CGPathGetBoundingBox(ink.paths[0].CGPath)),
          "annotations: ink paths relative to the bounds, the border width");
    PDFAnnotation *sq = first_of(p1, @"Square");
    CHECK(sq.interiorColor && sq.border.style == kPDFBorderStyleDashed && [sq.border.dashPattern isEqual:(@[ @3, @2 ])] &&
          [sq.border.borderKeyValues[PDFBorderKeyLineWidth] isEqual:@2], "annotations: a square's interior color and dashed border");
    PDFAnnotation *line = first_of(p1, @"Line");
    CHECK(CGPointEqualToPoint(line.startPoint, CGPointMake(10, 20)) && CGPointEqualToPoint(line.endPoint, CGPointMake(190, 20)) &&
          line.startLineStyle == kPDFLineStyleNone && line.endLineStyle == kPDFLineStyleClosedArrow &&
          [PDFAnnotation lineStyleFromName:@"Diamond"] == kPDFLineStyleDiamond && [[PDFAnnotation nameForLineStyle:kPDFLineStyleOpenArrow] isEqual:@"OpenArrow"],
          "annotations: a line's points and endings");
    PDFAnnotation *ft = first_of(p1, @"FreeText");
    CHECK(near(ft.font.pointSize, 14) && ft.alignment == NSTextAlignmentCenter && [ft.contents isEqual:@"Free text"], "annotations: free text's font and alignment");
    PDFAnnotation *field = nil, *box = nil;
    for (PDFAnnotation *a in p1.annotations) if ([a.type isEqual:@"Widget"]) { if ([a.widgetFieldType isEqual:PDFAnnotationWidgetSubtypeText]) field = a; else box = a; }
    CHECK([field.fieldName isEqual:@"name"] && [field.widgetStringValue isEqual:@"Ann"] && field.isActivatableTextField && !field.isMultiline,
          "annotations: a text field inherits its field's name and value");
    CHECK(box.widgetControlType == kPDFWidgetCheckBoxControl && box.buttonWidgetState == kPDFWidgetOnState &&
          [box.buttonWidgetStateString isEqual:@"Yes"] && box.hasAppearanceStream, "annotations: a check box");
    CHECK([p1 annotationAtPoint:CGPointMake(310, 410)] == box && [p1 annotationAtPoint:CGPointMake(10, 10)] == nil, "annotations: the one at a point");

    /* drawing: the page, then the annotations (displaysAnnotations) */
    UIImage *with = [p1 thumbnailOfSize:CGSizeMake(612, 792) forBox:kPDFDisplayBoxMediaBox];
    p1.displaysAnnotations = NO;
    UIImage *without = [p1 thumbnailOfSize:CGSizeMake(612, 792) forBox:kPDFDisplayBoxMediaBox];
    p1.displaysAnnotations = YES;
    uint8_t px[4], px2[4];
    pixel(with, 350, 792 - 150, px); pixel(without, 350, 792 - 150, px2);   /* the square's green inside */
    CHECK(px[1] > 200 && px[0] < 80 && px2[0] > 240 && px2[1] > 240, "annotations: drawn with the page (%d %d %d / %d %d %d)", px[0], px[1], px[2], px2[0], px2[1], px2[2]);
    pixel(with, 265, 792 - 708, px);                                  /* the highlight, after the line's text */
    CHECK(px[0] > 200 && px[1] > 200 && px[2] < 80, "annotations: the highlight is yellow (%d %d %d)", px[0], px[1], px[2]);

    /* made, changed, removed */
    PDFAnnotation *made = [[PDFAnnotation alloc] initWithBounds:CGRectMake(72, 500, 200, 40) forType:PDFAnnotationSubtypeSquare
                                                withProperties:@{ PDFAnnotationKeyColor: [UIColor blueColor], PDFAnnotationKeyContents: @"made" }];
    PDFBorder *border = [PDFBorder new]; border.lineWidth = 4;
    made.border = border;
    made.interiorColor = [UIColor colorWithRed:1 green:0 blue:1 alpha:1];
    [p2 addAnnotation:made];
    CHECK(made.page == p2 && p2.annotations.count == 1 && [made.type isEqual:@"Square"] && [made.contents isEqual:@"made"], "annotations: made and added");
    PDFAnnotation *stamp = [[PDFAnnotation alloc] initWithBounds:CGRectMake(300, 500, 150, 50) forType:PDFAnnotationSubtypeStamp withProperties:nil];
    stamp.stampName = @"Approved";
    [p2 addAnnotation:stamp];
    PDFAnnotation *mark = [[PDFAnnotation alloc] initWithBounds:CGRectMake(70, 695, 100, 27) forType:PDFAnnotationSubtypeHighlight withProperties:nil];
    mark.markupType = kPDFMarkupTypeUnderline;
    UIBezierPath *path = [UIBezierPath bezierPath]; [path moveToPoint:CGPointMake(0, 0)]; [path addLineToPoint:CGPointMake(50, 50)];
    PDFAnnotation *drawn = [[PDFAnnotation alloc] initWithBounds:CGRectMake(400, 100, 100, 100) forType:PDFAnnotationSubtypeInk withProperties:nil];
    [drawn addBezierPath:path];
    [p2 addAnnotation:mark]; [p2 addAnnotation:drawn];
    CHECK([mark.type isEqual:@"Underline"] && drawn.paths.count == 1, "annotations: markup type, ink paths");
    [p1 removeAnnotation:url];
    field.widgetStringValue = @"Bea";
    box.buttonWidgetState = kPDFWidgetOffState;
    CHECK(p1.annotations.count == 10 && url.page == nil && [field.widgetStringValue isEqual:@"Bea"] && box.buttonWidgetState == kPDFWidgetOffState,
          "annotations: removed, a field and a check box changed");

    /* written and read back */
    NSData *data = doc.dataRepresentation;
    PDFDocument *back = [[PDFDocument alloc] initWithData:data];
    PDFPage *b1 = [back pageAtIndex:0], *b2 = [back pageAtIndex:1];
    CHECK(back && b1.annotations.count == 10 && b2.annotations.count == 4, "write: the annotations written (%lu, %lu)",
          (unsigned long)b1.annotations.count, (unsigned long)b2.annotations.count);
    PDFAnnotation *m2 = first_of(b2, @"Square");
    CHECK(m2 && rect_eq(m2.bounds, CGRectMake(72, 500, 200, 40)) && [m2.contents isEqual:@"made"] && m2.border.lineWidth == 4 && m2.interiorColor,
          "write: a made annotation's properties");
    PDFAnnotation *bf = nil, *bb = nil;
    for (PDFAnnotation *a in b1.annotations) if ([a.type isEqual:@"Widget"]) { if ([a.widgetFieldType isEqual:PDFAnnotationWidgetSubtypeText]) bf = a; else bb = a; }
    CHECK([bf.widgetStringValue isEqual:@"Bea"] && [bf.fieldName isEqual:@"name"] && bb.buttonWidgetState == kPDFWidgetOffState, "write: changed field values");
    PDFAnnotation *bgo = nil;
    for (PDFAnnotation *a in b1.annotations) if ([a.type isEqual:@"Link"]) bgo = a;
    CHECK(bgo.destination.page == b2 && [first_of(b1, @"Text").popup.type isEqual:@"Popup"] && first_of(b1, @"Ink").paths.count == 1,
          "write: a link's destination page, the popup, ink");
    CHECK([first_of(b2, @"Stamp").stampName isEqual:@"Approved"] && first_of(b2, @"Underline") != nil, "write: a stamp and an underline");
    NSData *burnt = [doc dataRepresentationWithOptions:@{ PDFDocumentBurnInAnnotationsOption: @YES }];
    PDFDocument *flat = [[PDFDocument alloc] initWithData:burnt];
    UIImage *flatImage = [[flat pageAtIndex:1] thumbnailOfSize:CGSizeMake(612, 792) forBox:kPDFDisplayBoxMediaBox];
    pixel(flatImage, 170, 792 - 520, px);                              /* the made square's magenta inside, now page content */
    CHECK([flat pageAtIndex:1].annotations.count == 0 && px[0] > 200 && px[1] < 80 && px[2] > 200, "write: burnt in (%d %d %d)", px[0], px[1], px[2]);

    /* actions */
    PDFActionRemoteGoTo *remote = [[PDFActionRemoteGoTo alloc] initWithPageIndex:2 atPoint:CGPointMake(10, 20) fileURL:[NSURL fileURLWithPath:@"/tmp/x.pdf"]];
    PDFActionResetForm *reset = [PDFActionResetForm new];
    reset.fields = @[ @"name" ];
    CHECK([remote.type isEqual:@"RemoteGoTo"] && remote.pageIndex == 2 && [[remote copy] pageIndex] == 2 && [reset.type isEqual:@"ResetForm"] &&
          reset.fieldsIncludedAreCleared && [[[PDFActionNamed alloc] initWithName:kPDFActionNamedPrint].type isEqual:@"Named"],
          "actions: remote go-to, reset form, named");

    /* the view: selection, highlights, actions */
    PDFView *v = [[PDFView alloc] initWithFrame:CGRectMake(0, 0, 400, 600)];
    v.document = doc;
    v.autoScales = YES;
    [v layoutIfNeeded];
    __block int changed = 0;
    id obs = [[NSNotificationCenter defaultCenter] addObserverForName:PDFViewSelectionChangedNotification object:v queue:nil
                                                           usingBlock:^(NSNotification *n) { changed++; }];
    PDFSelection *sel = [p1 selectionForRange:NSMakeRange(4, 5)];
    v.currentSelection = sel;
    CHECK(v.currentSelection == sel && changed == 1, "view: the current selection");
    [v selectAll:nil];
    CHECK([v.currentSelection.string isEqual:doc.string] && changed == 2, "view: select all");
    [v clearSelection];
    CHECK(!v.currentSelection && changed == 3, "view: clear");
    v.highlightedSelections = [doc findString:@"fox" withOptions:0];
    CHECK(v.highlightedSelections.count == 2, "view: highlighted selections");
    [v performAction:[[PDFActionNamed alloc] initWithName:kPDFActionNamedLastPage]];
    CHECK(v.currentPage == p2, "view: a named action");
    [v performAction:[[PDFActionGoTo alloc] initWithDestination:[[PDFDestination alloc] initWithPage:p1 atPoint:CGPointMake(0, 700)]]];
    CHECK(v.currentPage == p1, "view: a go-to action");
    v.findInteractionEnabled = YES;
    CHECK(v.isFindInteractionEnabled && v.findInteraction != nil, "view: the find interaction");
    CHECK(([v areaOfInterestForPoint:[v convertPoint:CGPointMake(310, 410) fromPage:p1]] & kPDFControlArea) &&
          ([v areaOfInterestForPoint:[v convertPoint:CGPointMake(200, 650) fromPage:p1]] & kPDFLinkArea), "view: annotation areas");
    [[NSNotificationCenter defaultCenter] removeObserver:obs];
}

int main(void) {
    @autoreleasepool {
        reading();
        text();
        encrypted();
        writing();
        view();
        selections();
        annotations();
        printf("pdfkit: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
