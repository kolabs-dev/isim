/* isim PDFKit (issue #269): PDFDocument, PDFPage, PDFOutline and PDFDestination over isim's CGPDF parser (the objects:
 * pages, boxes, outline, labels, info, encryption) and poppler (drawing, through CGContextDrawPDFPage, and text). A
 * document is an array of pages; each page draws from the CGPDFDocument it came from, an image, or nothing. Writing
 * redraws the pages into a CGPDFContext (adapted: vector content stays vector; a rotated page is written turned). */
#import "pdfkit_internal.h"
#include <float.h>
#pragma clang diagnostic ignored "-Wincomplete-implementation"      /* selections and find: PDFSelection.m */
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

/* CoreGraphics' private helpers for PDFKit (CGBitmap.c) */
extern char *isim_CGPDFPageCopyText(CGPDFPageRef page, CGRect **rects, size_t *count);
extern int isim_CGPDFDocumentGetUnlockLevel(CGPDFDocumentRef document);
extern void *isim_CGPDFDataCopyAddingAnnotations(const void *data, size_t len, int count, const char *const *sources,
                                                 const int *pageOf, size_t *outLen);

const CGFloat kPDFDestinationUnspecifiedValue = FLT_MAX;
NSNotificationName const PDFDocumentDidUnlockNotification = @"PDFDocumentDidUnlock";
NSNotificationName const PDFDocumentDidBeginWriteNotification = @"PDFDocumentDidBeginWrite";
NSNotificationName const PDFDocumentDidEndWriteNotification = @"PDFDocumentDidEndWrite";
PDFDocumentAttribute const PDFDocumentTitleAttribute = @"Title";
PDFDocumentAttribute const PDFDocumentAuthorAttribute = @"Author";
PDFDocumentAttribute const PDFDocumentSubjectAttribute = @"Subject";
PDFDocumentAttribute const PDFDocumentCreatorAttribute = @"Creator";
PDFDocumentAttribute const PDFDocumentProducerAttribute = @"Producer";
PDFDocumentAttribute const PDFDocumentCreationDateAttribute = @"CreationDate";
PDFDocumentAttribute const PDFDocumentModificationDateAttribute = @"ModDate";
PDFDocumentAttribute const PDFDocumentKeywordsAttribute = @"Keywords";
PDFDocumentWriteOption const PDFDocumentOwnerPasswordOption = @"OwnerPassword";
PDFDocumentWriteOption const PDFDocumentUserPasswordOption = @"UserPassword";
PDFDocumentWriteOption const PDFDocumentAccessPermissionsOption = @"AccessPermissions";
PDFDocumentWriteOption const PDFDocumentBurnInAnnotationsOption = @"BurnInAnnotations";
PDFDocumentWriteOption const PDFDocumentSaveTextFromOCROption = @"SaveTextFromOCR";
PDFDocumentWriteOption const PDFDocumentSaveImagesAsJPEGOption = @"SaveImagesAsJPEG";
PDFDocumentWriteOption const PDFDocumentOptimizeImagesForScreenOption = @"OptimizeImagesForScreen";
PDFPageImageInitializationOption const PDFPageImageInitializationOptionMediaBox = @"MediaBox";
PDFPageImageInitializationOption const PDFPageImageInitializationOptionRotation = @"Rotation";
PDFPageImageInitializationOption const PDFPageImageInitializationOptionUpscaleIfSmaller = @"UpscaleIfSmaller";
PDFPageImageInitializationOption const PDFPageImageInitializationOptionCompressionQuality = @"CompressionQuality";

@interface PDFOutline (Isim)
- (void)_setDocument:(PDFDocument *)doc;
@end

static BOOL is_low_surrogate(unichar c) { return c >= 0xDC00 && c <= 0xDFFF; }

static NSString *pdf_text(CGPDFDictionaryRef d, const char *key) {
    CGPDFStringRef s;
    return d && CGPDFDictionaryGetString(d, key, &s) ? CFBridgingRelease(CGPDFStringCopyTextString(s)) : nil;
}

/* ---------------- PDFDestination ---------------- */
@implementation PDFDestination
- (instancetype)initWithPage:(PDFPage *)page atPoint:(CGPoint)point {
    if (!(self = [super init])) return nil;
    _page = page; _point = point; _zoom = kPDFDestinationUnspecifiedValue;
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    PDFDestination *d = [[PDFDestination alloc] initWithPage:_page atPoint:_point];
    d.zoom = _zoom;
    return d;
}
- (NSComparisonResult)compare:(PDFDestination *)other {
    NSUInteger a = [_page.document indexForPage:_page], b = [other.page.document indexForPage:other.page];
    if (a != b) return a < b ? NSOrderedAscending : NSOrderedDescending;
    CGFloat ya = _point.y == kPDFDestinationUnspecifiedValue ? CGFLOAT_MAX : _point.y;
    CGFloat yb = other.point.y == kPDFDestinationUnspecifiedValue ? CGFLOAT_MAX : other.point.y;
    if (ya != yb) return ya > yb ? NSOrderedAscending : NSOrderedDescending;      /* higher on the page comes first */
    CGFloat xa = _point.x == kPDFDestinationUnspecifiedValue ? 0 : _point.x, xb = other.point.x == kPDFDestinationUnspecifiedValue ? 0 : other.point.x;
    return xa == xb ? NSOrderedSame : xa < xb ? NSOrderedAscending : NSOrderedDescending;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<PDFDestination page %lu point (%g, %g)>",
            (unsigned long)[_page.document indexForPage:_page], _point.x, _point.y];
}
@end

/* ---------------- PDFOutline ---------------- */
@interface PDFOutline ()
@property (nonatomic, weak, readwrite, nullable) PDFDocument *document;
@property (nonatomic, weak, readwrite, nullable) PDFOutline *parent;
@end
@implementation PDFOutline {
    NSMutableArray<PDFOutline *> *_children;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _children = [NSMutableArray array];
    return self;
}
- (NSUInteger)numberOfChildren { return _children.count; }
- (NSUInteger)index { return _parent ? [_parent->_children indexOfObjectIdenticalTo:self] : 0; }
- (PDFOutline *)childAtIndex:(NSUInteger)index { return index < _children.count ? _children[index] : nil; }
- (void)_setDocument:(PDFDocument *)doc {
    _document = doc;
    for (PDFOutline *c in _children) [c _setDocument:doc];
}
- (void)insertChild:(PDFOutline *)child atIndex:(NSUInteger)index {
    if (!child) return;
    [child removeFromParent];
    [_children insertObject:child atIndex:MIN(index, _children.count)];
    child.parent = self;
    [child _setDocument:_document];
}
- (void)removeFromParent {
    PDFOutline *p = _parent;
    if (!p) return;
    [p->_children removeObjectIdenticalTo:self];
    _parent = nil;
}
@end

/* ---------------- PDFPage ---------------- */
@interface PDFPage ()
@property (nonatomic, weak, readwrite, nullable) PDFDocument *document;
@end
@implementation PDFPage {
    CGPDFDocumentRef _source;       /* retained; the page is _index (from 1) of it */
    size_t _index;
    UIImage *_image;
    CGRect _imageRect, _boxes[5];
    BOOL _boxSet[5], _rotationSet;
    NSInteger _rotation;
    NSString *_text;
    CGRect *_rects;
    size_t _nrects;
    BOOL _textRead;
    CGRect *_units;                     /* a rectangle per UTF-16 unit of _text */
    NSMutableArray<PDFAnnotation *> *_annotations;   /* nil until read */
    NSMutableArray<PDFAnnotation *> *_removedWidgets;  /* source form fields removed (Core Graphics draws them) */
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _boxes[kPDFDisplayBoxMediaBox] = CGRectMake(0, 0, 612, 792);       /* a blank US Letter page */
    _boxSet[kPDFDisplayBoxMediaBox] = YES;
    _displaysAnnotations = YES;
    return self;
}
- (instancetype)_initWithDocument:(CGPDFDocumentRef)doc index:(size_t)index {
    if (!(self = [self init])) return nil;
    _boxSet[kPDFDisplayBoxMediaBox] = NO;
    _source = CGPDFDocumentRetain(doc);
    _index = index;
    return self;
}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
- (instancetype)initWithImage:(UIImage *)image { return [self initWithImage:image options:@{}]; }
#pragma clang diagnostic pop
- (instancetype)initWithImage:(UIImage *)image options:(NSDictionary<PDFPageImageInitializationOption, id> *)options {
    if (!image || !image.CGImage || !(self = [self init])) return nil;
    _image = image;
    CGSize sz = image.size;
    NSValue *mb = options[PDFPageImageInitializationOptionMediaBox];
    CGRect media = mb ? mb.CGRectValue : CGRectMake(0, 0, sz.width, sz.height);
    _boxes[kPDFDisplayBoxMediaBox] = media;
    CGFloat s = MIN(media.size.width / MAX(sz.width, 1), media.size.height / MAX(sz.height, 1));
    if (s > 1 && ![options[PDFPageImageInitializationOptionUpscaleIfSmaller] boolValue]) s = 1;
    CGSize fit = CGSizeMake(sz.width * s, sz.height * s);              /* aspect fit, centered */
    _imageRect = CGRectMake(CGRectGetMidX(media) - fit.width / 2, CGRectGetMidY(media) - fit.height / 2, fit.width, fit.height);
    if (options[PDFPageImageInitializationOptionRotation]) self.rotation = [options[PDFPageImageInitializationOptionRotation] integerValue];
    return self;
}
- (void)dealloc {
    CGPDFDocumentRelease(_source);
    free(_rects); free(_units);
}
- (id)copyWithZone:(NSZone *)zone {
    PDFPage *p = [[[self class] alloc] init];
    p->_source = CGPDFDocumentRetain(_source); p->_index = _index;
    p->_image = _image; p->_imageRect = _imageRect;
    memcpy(p->_boxes, _boxes, sizeof _boxes); memcpy(p->_boxSet, _boxSet, sizeof _boxSet);
    p->_rotation = _rotation; p->_rotationSet = _rotationSet;
    p->_displaysAnnotations = _displaysAnnotations;
    p->_annotations = [NSMutableArray array];
    for (PDFAnnotation *a in self._isim_annotations) { PDFAnnotation *c = [a copy]; c.page = p; [p->_annotations addObject:c]; }
    p->_removedWidgets = [_removedWidgets mutableCopy];
    return p;
}
- (CGPDFDocumentRef)_source { return _source; }
- (size_t)_sourceIndex { return _index; }
- (CGPDFPageRef)pageRef { return _source ? CGPDFDocumentGetPage(_source, _index) : NULL; }

/* ---- boxes and rotation ---- */
static const char *const box_names[] = { "MediaBox", "CropBox", "BleedBox", "TrimBox", "ArtBox" };
- (BOOL)_hasOwnBox:(PDFDisplayBox)box {
    CGPDFDictionaryRef d = CGPDFPageGetDictionary(self.pageRef);
    CGPDFArrayRef a;
    return d && CGPDFDictionaryGetArray(d, box_names[box], &a);
}
- (CGRect)boundsForBox:(PDFDisplayBox)box {
    if (box < kPDFDisplayBoxMediaBox || box > kPDFDisplayBoxArtBox) box = kPDFDisplayBoxCropBox;
    if (_boxSet[box]) return _boxes[box];
    CGRect media = _boxSet[kPDFDisplayBoxMediaBox] ? _boxes[kPDFDisplayBoxMediaBox]
                 : self.pageRef ? CGPDFPageGetBoxRect(self.pageRef, kCGPDFMediaBox) : CGRectMake(0, 0, 612, 792);
    if (box == kPDFDisplayBoxMediaBox) return media;
    CGRect crop = _boxSet[kPDFDisplayBoxCropBox] ? _boxes[kPDFDisplayBoxCropBox]
                : self.pageRef ? CGRectIntersection(CGPDFPageGetBoxRect(self.pageRef, kCGPDFCropBox), media) : media;
    if (CGRectIsNull(crop)) crop = media;
    if (box == kPDFDisplayBoxCropBox) return crop;
    if (self.pageRef && [self _hasOwnBox:box]) {
        CGRect r = CGRectIntersection(CGPDFPageGetBoxRect(self.pageRef, (CGPDFBox)box), media);
        if (!CGRectIsNull(r)) return r;
    }
    return crop;                                                       /* bleed, trim and art default to the crop box */
}
- (void)setBounds:(CGRect)bounds forBox:(PDFDisplayBox)box {
    if (box < kPDFDisplayBoxMediaBox || box > kPDFDisplayBoxArtBox) return;
    _boxes[box] = CGRectStandardize(bounds);
    _boxSet[box] = !CGRectIsEmpty(bounds) || box == kPDFDisplayBoxMediaBox;
}
- (NSInteger)rotation {
    if (_rotationSet) return _rotation;
    return self.pageRef ? CGPDFPageGetRotationAngle(self.pageRef) : 0;
}
- (void)setRotation:(NSInteger)rotation {
    NSInteger r = ((rotation % 360) + 360) % 360;
    _rotation = r - r % 90;
    _rotationSet = YES;
}
/* the page's box into (0, 0, its size as displayed): the box's origin to 0, turned clockwise by the rotation */
- (CGAffineTransform)transformForBox:(PDFDisplayBox)box {
    CGRect b = [self boundsForBox:box];
    CGFloat x = b.origin.x, y = b.origin.y, w = b.size.width, h = b.size.height;
    switch (self.rotation) {
        case 90: return CGAffineTransformMake(0, -1, 1, 0, -y, x + w);
        case 180: return CGAffineTransformMake(-1, 0, 0, -1, x + w, y + h);
        case 270: return CGAffineTransformMake(0, 1, -1, 0, y + h, -x);
        default: return CGAffineTransformMake(1, 0, 0, 1, -x, -y);
    }
}
- (void)transformContext:(CGContextRef)context forBox:(PDFDisplayBox)box {
    CGContextConcatCTM(context, [self transformForBox:box]);
}
- (void)_drawContentIn:(CGContextRef)ctx {
    if (self.pageRef) CGContextDrawPDFPage(ctx, self.pageRef);
    else if (_image) CGContextDrawImage(ctx, _imageRect, _image.CGImage);
}
- (void)drawWithBox:(PDFDisplayBox)box toContext:(CGContextRef)context {
    if (!context) return;
    CGContextSaveGState(context);
    [self transformContext:context forBox:box];
    CGContextClipToRect(context, [self boundsForBox:box]);
    [self _drawContentIn:context];
    if (_displaysAnnotations) [self _isim_drawAnnotationsIn:context box:box printing:NO];
    CGContextRestoreGState(context);
}
- (void)drawWithBox:(PDFDisplayBox)box { [self drawWithBox:box toContext:UIGraphicsGetCurrentContext()]; }
- (void)transformContextForBox:(PDFDisplayBox)box {
    CGContextRef c = UIGraphicsGetCurrentContext();
    if (c) [self transformContext:c forBox:box];
}
- (CGSize)_displaySize:(PDFDisplayBox)box {
    CGRect b = [self boundsForBox:box];
    return self.rotation % 180 ? CGSizeMake(b.size.height, b.size.width) : b.size;
}
- (UIImage *)thumbnailOfSize:(CGSize)size forBox:(PDFDisplayBox)box {
    CGSize d = [self _displaySize:box];
    CGFloat s = d.width > 0 && d.height > 0 ? MIN(size.width / d.width, size.height / d.height) : 0;
    CGSize out = CGSizeMake(MAX(1, floor(d.width * s)), MAX(1, floor(d.height * s)));
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:out];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *rc) {
        CGContextRef c = rc.CGContext;
        CGContextSetRGBFillColor(c, 1, 1, 1, 1);
        CGContextFillRect(c, CGRectMake(0, 0, out.width, out.height));
        CGContextTranslateCTM(c, 0, out.height);                       /* UIKit is y-down; pages are y-up */
        CGContextScaleCTM(c, s, -s);
        [self drawWithBox:box toContext:c];
    }];
}

/* ---- labels ---- */
static NSString *roman(NSInteger n) {
    static const struct { int v; const char *s; } t[] = { {1000, "m"}, {900, "cm"}, {500, "d"}, {400, "cd"}, {100, "c"}, {90, "xc"},
                                                          {50, "l"}, {40, "xl"}, {10, "x"}, {9, "ix"}, {5, "v"}, {4, "iv"}, {1, "i"} };
    NSMutableString *r = [NSMutableString string];
    for (int i = 0; i < 13 && n > 0; i++) while (n >= t[i].v) { [r appendString:@(t[i].s)]; n -= t[i].v; }
    return r;
}
/* the /PageLabels number tree's entry for page `index` (from 0): the greatest key at or below it */
static BOOL label_entry(CGPDFDictionaryRef node, NSInteger index, NSInteger *key, CGPDFDictionaryRef *value, int depth) {
    CGPDFArrayRef nums, kids;
    BOOL found = NO;
    if (!node || depth > 32) return NO;
    if (CGPDFDictionaryGetArray(node, "Nums", &nums))
        for (size_t i = 0; i + 1 < CGPDFArrayGetCount(nums); i += 2) {
            CGPDFInteger k; CGPDFDictionaryRef v;
            if (CGPDFArrayGetInteger(nums, i, &k) && k <= index && (!found || k >= *key) && CGPDFArrayGetDictionary(nums, i + 1, &v)) {
                *key = k; *value = v; found = YES;
            }
        }
    if (CGPDFDictionaryGetArray(node, "Kids", &kids))
        for (size_t i = 0; i < CGPDFArrayGetCount(kids); i++) {
            CGPDFDictionaryRef kid; NSInteger k = 0; CGPDFDictionaryRef v = NULL;
            if (CGPDFArrayGetDictionary(kids, i, &kid) && label_entry(kid, index, &k, &v, depth + 1) && (!found || k >= *key)) {
                *key = k; *value = v; found = YES;
            }
        }
    return found;
}
- (NSString *)label {
    if (_source) {
        CGPDFDictionaryRef labels, entry = NULL;
        NSInteger key = 0, i = (NSInteger)_index - 1;
        if (CGPDFDictionaryGetDictionary(CGPDFDocumentGetCatalog(_source), "PageLabels", &labels) && label_entry(labels, i, &key, &entry, 0)) {
            NSString *prefix = pdf_text(entry, "P") ?: @"";
            CGPDFInteger start = 1;
            CGPDFDictionaryGetInteger(entry, "St", &start);
            NSInteger n = start + (i - key);
            const char *style = NULL;
            if (!CGPDFDictionaryGetName(entry, "S", &style)) return prefix;
            NSString *num;
            if (!strcmp(style, "R")) num = roman(n).uppercaseString;
            else if (!strcmp(style, "r")) num = roman(n);
            else if (!strcmp(style, "A") || !strcmp(style, "a")) {     /* A..Z, AA..ZZ, ... */
                unichar c = (unichar)((style[0] == 'A' ? 'A' : 'a') + (n - 1) % 26);
                num = [@"" stringByPaddingToLength:(NSUInteger)((n - 1) / 26 + 1) withString:[NSString stringWithCharacters:&c length:1] startingAtIndex:0];
            } else num = [NSString stringWithFormat:@"%ld", (long)n];
            return [prefix stringByAppendingString:num];
        }
    }
    NSUInteger at = _document ? [_document indexForPage:self] : NSNotFound;
    return at == NSNotFound ? nil : [NSString stringWithFormat:@"%lu", (unsigned long)at + 1];
}

/* ---- text ---- */
- (void)_readText {
    if (_textRead) return;
    _textRead = YES;
    if (!self.pageRef) return;
    char *t = isim_CGPDFPageCopyText(self.pageRef, &_rects, &_nrects);
    _text = t ? @(t) : nil;
    free(t);
}
- (NSString *)string { [self _readText]; return _text ?: (self.pageRef ? @"" : nil); }
- (NSAttributedString *)attributedString {
    NSString *s = self.string;
    return s ? [[NSAttributedString alloc] initWithString:s] : nil;
}
- (NSUInteger)numberOfCharacters { return self.string.length; }
/* poppler gives a rectangle per Unicode character; NSString indexes UTF-16 */
- (CGRect)characterBoundsAtIndex:(NSInteger)index {
    NSString *s = self.string;
    if (index < 0 || (NSUInteger)index >= s.length) return CGRectZero;
    size_t cp = 0;
    for (NSInteger i = 0; i < index; i++) if (!is_low_surrogate([s characterAtIndex:(NSUInteger)i])) cp++;
    return cp < _nrects ? _rects[cp] : CGRectZero;
}
- (NSInteger)characterIndexAtPoint:(CGPoint)point {
    NSString *s = self.string;
    size_t cp = 0;
    for (NSUInteger i = 0; i < s.length; i++) {
        if (is_low_surrogate([s characterAtIndex:i])) continue;
        if (cp < _nrects && CGRectContainsPoint(_rects[cp], point) && [s characterAtIndex:i] != '\n') return (NSInteger)i;
        cp++;
    }
    return -1;
}
- (const CGRect *)_isim_unitRects {
    NSString *s = self.string;
    if (!_units && s.length) {
        _units = calloc(s.length, sizeof *_units);
        size_t cp = 0;
        for (NSUInteger i = 0; i < s.length; i++) {
            if (i > 0 && is_low_surrogate([s characterAtIndex:i])) { _units[i] = _units[i - 1]; continue; }
            _units[i] = cp < _nrects ? _rects[cp] : CGRectZero;
            cp++;
        }
    }
    return _units;
}
- (NSUInteger)_isim_characterNearPoint:(CGPoint)point {
    NSString *s = self.string;
    const CGRect *r = self._isim_unitRects;
    NSUInteger best = NSNotFound;
    CGFloat bestD = CGFLOAT_MAX;
    for (NSUInteger i = 0; i < s.length; i++) {
        if ([s characterAtIndex:i] == '\n' || CGRectIsEmpty(r[i])) continue;
        if (CGRectContainsPoint(r[i], point)) return i;
        CGFloat dx = MAX(0, MAX(CGRectGetMinX(r[i]) - point.x, point.x - CGRectGetMaxX(r[i])));
        CGFloat dy = MAX(0, MAX(CGRectGetMinY(r[i]) - point.y, point.y - CGRectGetMaxY(r[i])));
        CGFloat d = dx * dx + dy * dy * 4;                             /* the same line before the next one */
        if (d < bestD) { bestD = d; best = i; }
    }
    return best;
}
- (NSRange)_isim_lineRangeAt:(NSUInteger)index {
    NSString *s = self.string;
    if (index >= s.length) return NSMakeRange(s.length, 0);
    NSUInteger a = index, b = index;
    while (a > 0 && [s characterAtIndex:a - 1] != '\n') a--;
    while (b < s.length && [s characterAtIndex:b] != '\n') b++;
    return NSMakeRange(a, b - a);
}
- (NSRange)_isim_wordRangeAt:(NSUInteger)index {
    NSString *s = self.string;
    if (index >= s.length) return NSMakeRange(s.length, 0);
    NSCharacterSet *word = [NSCharacterSet alphanumericCharacterSet];
    BOOL (^isWord)(NSUInteger) = ^BOOL(NSUInteger i) {
        unichar c = [s characterAtIndex:i];
        return [word characterIsMember:c] || c == '\'' || c == 0x2019 || isim_high_surrogate(c) || isim_low_surrogate(c);
    };
    if (!isWord(index)) return NSMakeRange(index, 1);
    NSUInteger a = index, b = index;
    while (a > 0 && isWord(a - 1)) a--;
    while (b < s.length && isWord(b)) b++;
    return NSMakeRange(a, b - a);
}

/* ---- annotations ---- */
- (NSArray<PDFAnnotation *> *)_isim_annotations {
    if (_annotations) return _annotations;
    _annotations = [NSMutableArray array];
    CGPDFDictionaryRef d = CGPDFPageGetDictionary(self.pageRef);
    CGPDFArrayRef annots;
    if (!d || !CGPDFDictionaryGetArray(d, "Annots", &annots)) return _annotations;
    NSMutableDictionary<NSValue *, PDFAnnotation *> *bySource = [NSMutableDictionary dictionary];   /* by dictionary */
    id<PDFDocumentDelegate> delegate = self.document.delegate;
    for (size_t i = 0; i < CGPDFArrayGetCount(annots); i++) {
        CGPDFDictionaryRef a; const char *sub = "";
        if (!CGPDFArrayGetDictionary(annots, i, &a)) continue;
        CGPDFDictionaryGetName(a, "Subtype", &sub);
        Class cls = [PDFAnnotation class];
        if ([delegate respondsToSelector:@selector(classForAnnotationType:)]) {
            Class c = [delegate classForAnnotationType:@(sub)];
            if ([c isSubclassOfClass:[PDFAnnotation class]]) cls = c;
        }
        PDFAnnotation *annotation = [[cls alloc] _initWithIsimDictionary:a page:self];
        if (!annotation) continue;
        [_annotations addObject:annotation];
        bySource[[NSValue valueWithPointer:a]] = annotation;
    }
    for (PDFAnnotation *annotation in _annotations) {                 /* popups and their parents */
        CGPDFDictionaryRef popup;
        if (CGPDFDictionaryGetDictionary(annotation._isim_sourceDictionary, "Popup", &popup)) {
            PDFAnnotation *p = bySource[[NSValue valueWithPointer:popup]];
            if (p) annotation.popup = p;
        }
    }
    return _annotations;
}
- (NSArray<PDFAnnotation *> *)annotations { return [self._isim_annotations copy]; }
- (void)addAnnotation:(PDFAnnotation *)annotation {
    if (!annotation) return;
    PDFPage *old = annotation.page;
    if (old && old != self) [old removeAnnotation:annotation];
    if ([self._isim_annotations indexOfObjectIdenticalTo:annotation] == NSNotFound) [_annotations addObject:annotation];
    annotation.page = self;
    [_removedWidgets removeObjectIdenticalTo:annotation];
}
- (void)removeAnnotation:(PDFAnnotation *)annotation {
    if (!annotation || [self._isim_annotations indexOfObjectIdenticalTo:annotation] == NSNotFound) return;
    [_annotations removeObjectIdenticalTo:annotation];
    if (annotation._isim_sourceDictionary && [annotation.type isEqual:@"Widget"]) {
        if (!_removedWidgets) _removedWidgets = [NSMutableArray array];
        [_removedWidgets addObject:annotation];
    }
    if (annotation.page == self) annotation.page = nil;
}
- (PDFAnnotation *)annotationAtPoint:(CGPoint)point {
    for (PDFAnnotation *a in self._isim_annotations.reverseObjectEnumerator)
        if (a.shouldDisplay && ![a.type isEqual:@"Popup"] && CGRectContainsPoint(a.bounds, point)) return a;
    return nil;
}
/* poppler's print path (Core Graphics) may draw the page's own form fields: a source field is drawn here over a blank
 * of its bounds, and a removed one is blanked */
- (void)_isim_drawAnnotationsIn:(CGContextRef)ctx box:(PDFDisplayBox)box printing:(BOOL)printing {
    for (PDFAnnotation *a in _removedWidgets) {
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
        CGContextFillRect(ctx, a.bounds);
    }
    for (PDFAnnotation *a in self._isim_annotations) {
        if ([a.type isEqual:@"Popup"] || (printing && !a.shouldPrint)) continue;
        if (a._isim_sourceDictionary && [a.type isEqual:@"Widget"] && self.pageRef) {
            PDFAppearanceCharacteristics *mk = [a valueForAnnotationKey:PDFAnnotationKeyWidgetAppearanceDictionary];
            CGContextSetFillColorWithColor(ctx, (mk.backgroundColor ?: [UIColor whiteColor]).CGColor);
            CGContextFillRect(ctx, a.bounds);
        }
        [a drawWithBox:box inContext:ctx];
    }
}

- (NSData *)dataRepresentation {
    PDFDocument *d = [[PDFDocument alloc] init];
    [d insertPage:[self copy] atIndex:0];
    return d.dataRepresentation;
}
@end

/* ---------------- PDFDocument ---------------- */
@implementation PDFDocument {
    CGPDFDocumentRef _doc;
    NSMutableArray<PDFPage *> *_pages;    /* nil until first needed: then made with the page class of that moment */
    size_t _sourcePages;
    PDFOutline *_outline;
    BOOL _outlineRead, _attributesRead;
    NSDictionary *_attributes;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _pages = [NSMutableArray array];
    _outlineRead = _attributesRead = YES;
    return self;
}
- (instancetype)initWithData:(NSData *)data {
    if (!(self = [super init])) return nil;
    if (!data.length) return nil;
    CGDataProviderRef p = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    _doc = CGPDFDocumentCreateWithProvider(p);
    CGDataProviderRelease(p);
    if (!_doc) return nil;
    _sourcePages = CGPDFDocumentGetNumberOfPages(_doc);
    if (!_sourcePages && !CGPDFDocumentIsEncrypted(_doc)) return nil;
    return self;
}
- (instancetype)initWithURL:(NSURL *)url {
    NSData *data = url ? [NSData dataWithContentsOfURL:url] : nil;
    if (!(self = [self initWithData:data])) return nil;
    _documentURL = url;
    return self;
}
- (void)dealloc { CGPDFDocumentRelease(_doc); }
- (id)copyWithZone:(NSZone *)zone {
    NSData *d = self.dataRepresentation;
    return d ? [[PDFDocument alloc] initWithData:d] : [[PDFDocument alloc] init];
}
- (CGPDFDocumentRef)documentRef { return _doc; }
- (Class)pageClass { return [PDFPage class]; }
- (NSMutableArray<PDFPage *> *)_pages {
    if (!_pages) {
        _pages = [NSMutableArray arrayWithCapacity:_sourcePages];
        Class cls = [_delegate respondsToSelector:@selector(classForPage)] ? [_delegate classForPage] : self.pageClass;
        if (![cls isSubclassOfClass:[PDFPage class]]) cls = [PDFPage class];
        for (size_t i = 1; i <= _sourcePages; i++) {
            PDFPage *p = [[cls alloc] _initWithDocument:_doc index:i];
            p.document = self;
            [_pages addObject:p];
        }
    }
    return _pages;
}

/* ---- version, encryption ---- */
- (NSInteger)majorVersion { int ma = 1, mi = 7; if (_doc) CGPDFDocumentGetVersion(_doc, &ma, &mi); return ma; }
- (NSInteger)minorVersion { int ma = 1, mi = 7; if (_doc) CGPDFDocumentGetVersion(_doc, &ma, &mi); return mi; }
- (BOOL)isEncrypted { return _doc && CGPDFDocumentIsEncrypted(_doc); }
- (BOOL)isLocked { return _doc && !CGPDFDocumentIsUnlocked(_doc); }
- (BOOL)unlockWithPassword:(NSString *)password {
    if (!_doc) return YES;
    if (!CGPDFDocumentUnlockWithPassword(_doc, password.UTF8String ?: "")) return NO;
    _attributesRead = NO; _attributes = nil;                           /* strings read while locked were encrypted */
    if (!_outline) _outlineRead = NO;
    NSNotification *n = [NSNotification notificationWithName:PDFDocumentDidUnlockNotification object:self userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotification:n];
    if ([_delegate respondsToSelector:@selector(documentDidUnlock:)]) [_delegate documentDidUnlock:n];
    return YES;
}
- (PDFDocumentPermissions)permissionsStatus {
    if (!_doc) return kPDFDocumentPermissionsOwner;
    return (PDFDocumentPermissions)isim_CGPDFDocumentGetUnlockLevel(_doc);
}
- (PDFAccessPermissions)accessPermissions {
    if (!_doc) return 0xFF;
    return self.isLocked ? 0 : (PDFAccessPermissions)CGPDFDocumentGetAccessPermissions(_doc);   /* the same bits */
}
- (BOOL)allowsPrinting { return (self.accessPermissions & (PDFAllowsLowQualityPrinting | PDFAllowsHighQualityPrinting)) != 0; }
- (BOOL)allowsCopying { return (self.accessPermissions & PDFAllowsContentCopying) != 0; }
- (BOOL)allowsDocumentChanges { return (self.accessPermissions & PDFAllowsDocumentChanges) != 0; }
- (BOOL)allowsDocumentAssembly { return (self.accessPermissions & PDFAllowsDocumentAssembly) != 0; }
- (BOOL)allowsContentAccessibility { return (self.accessPermissions & PDFAllowsContentAccessibility) != 0; }
- (BOOL)allowsCommenting { return (self.accessPermissions & PDFAllowsCommenting) != 0; }
- (BOOL)allowsFormFieldEntry { return (self.accessPermissions & PDFAllowsFormFieldEntry) != 0; }

/* ---- attributes ---- */
- (NSDictionary *)documentAttributes {
    if (!_attributesRead) {
        _attributesRead = YES;
        NSMutableDictionary *a = [NSMutableDictionary dictionary];
        CGPDFDictionaryRef info = self.isLocked ? NULL : CGPDFDocumentGetInfo(_doc);
        const char *keys[] = { "Title", "Author", "Subject", "Creator", "Producer" };
        for (int i = 0; i < 5; i++) { NSString *v = pdf_text(info, keys[i]); if (v) a[@(keys[i])] = v; }
        NSString *kw = pdf_text(info, "Keywords");
        if (kw) {
            NSMutableArray *words = [NSMutableArray array];
            for (NSString *w in [kw componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",;"]]) {
                NSString *t = [w stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (t.length) [words addObject:t];
            }
            a[PDFDocumentKeywordsAttribute] = words;
        }
        const char *dates[] = { "CreationDate", "ModDate" };
        for (int i = 0; i < 2; i++) {
            CGPDFStringRef s;
            NSDate *d = info && CGPDFDictionaryGetString(info, dates[i], &s) ? CFBridgingRelease(CGPDFStringCopyDate(s)) : nil;
            if (d) a[@(dates[i])] = d;
        }
        _attributes = a;
    }
    return _attributes;
}
- (void)setDocumentAttributes:(NSDictionary *)attributes {
    _attributes = [attributes copy];
    _attributesRead = YES;
}

/* ---- pages ---- */
- (NSUInteger)pageCount { return _pages ? _pages.count : _sourcePages; }
- (PDFPage *)pageAtIndex:(NSUInteger)index { return index < self.pageCount ? self._pages[index] : nil; }
- (NSUInteger)indexForPage:(PDFPage *)page { return page ? [self._pages indexOfObjectIdenticalTo:page] : NSNotFound; }
- (void)insertPage:(PDFPage *)page atIndex:(NSUInteger)index {
    if (!page || index > self.pageCount) return;
    [self._pages insertObject:page atIndex:index];
    page.document = self;
}
- (void)removePageAtIndex:(NSUInteger)index {
    if (index >= self.pageCount) return;
    PDFPage *p = self._pages[index];
    [self._pages removeObjectAtIndex:index];
    if (p.document == self && [self indexForPage:p] == NSNotFound) p.document = nil;
}
- (void)exchangePageAtIndex:(NSUInteger)a withPageAtIndex:(NSUInteger)b {
    if (a >= self.pageCount || b >= self.pageCount) return;
    [self._pages exchangeObjectAtIndex:a withObjectAtIndex:b];
}
- (NSString *)string {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.pageCount; i++) [parts addObject:[self pageAtIndex:i].string ?: @""];
    return [parts componentsJoinedByString:@"\n"];
}

/* ---- the outline ---- */
static CGPDFObjectRef name_tree(CGPDFDictionaryRef node, CGPDFStringRef key, int depth) {
    CGPDFArrayRef names, kids;
    if (!node || depth > 32) return NULL;
    if (CGPDFDictionaryGetArray(node, "Names", &names))
        for (size_t i = 0; i + 1 < CGPDFArrayGetCount(names); i += 2) {
            CGPDFStringRef s; CGPDFObjectRef v;
            if (CGPDFArrayGetString(names, i, &s) && CGPDFStringGetLength(s) == CGPDFStringGetLength(key) &&
                !memcmp(CGPDFStringGetBytePtr(s), CGPDFStringGetBytePtr(key), CGPDFStringGetLength(key)) &&
                CGPDFArrayGetObject(names, i + 1, &v)) return v;
        }
    if (CGPDFDictionaryGetArray(node, "Kids", &kids))
        for (size_t i = 0; i < CGPDFArrayGetCount(kids); i++) {
            CGPDFDictionaryRef k;
            if (CGPDFArrayGetDictionary(kids, i, &k)) { CGPDFObjectRef v = name_tree(k, key, depth + 1); if (v) return v; }
        }
    return NULL;
}
/* an explicit destination (array) for a destination object: an array, a name (/Dests), a string (/Names /Dests), or a
 * dictionary with /D */
- (CGPDFArrayRef)_destArray:(CGPDFObjectRef)dest depth:(int)depth {
    CGPDFArrayRef a; const char *name; CGPDFStringRef str; CGPDFDictionaryRef dict, catalog = CGPDFDocumentGetCatalog(_doc);
    if (!dest || depth > 4) return NULL;
    if (CGPDFObjectGetValue(dest, kCGPDFObjectTypeArray, &a)) return a;
    if (CGPDFObjectGetValue(dest, kCGPDFObjectTypeDictionary, &dict)) {
        CGPDFObjectRef d;
        return CGPDFDictionaryGetObject(dict, "D", &d) ? [self _destArray:d depth:depth + 1] : NULL;
    }
    if (CGPDFObjectGetValue(dest, kCGPDFObjectTypeName, &name)) {
        CGPDFDictionaryRef dests; CGPDFObjectRef d;
        return CGPDFDictionaryGetDictionary(catalog, "Dests", &dests) && CGPDFDictionaryGetObject(dests, name, &d)
               ? [self _destArray:d depth:depth + 1] : NULL;
    }
    if (CGPDFObjectGetValue(dest, kCGPDFObjectTypeString, &str)) {
        CGPDFDictionaryRef names, tree;
        if (CGPDFDictionaryGetDictionary(catalog, "Names", &names) && CGPDFDictionaryGetDictionary(names, "Dests", &tree))
            return [self _destArray:name_tree(tree, str, 0) depth:depth + 1];
    }
    return NULL;
}
- (PDFDestination *)_destination:(CGPDFArrayRef)a {
    CGPDFDictionaryRef target; CGPDFInteger num;
    size_t page = 0;
    if (CGPDFArrayGetDictionary(a, 0, &target)) {
        for (size_t i = 1; i <= _sourcePages; i++) if (CGPDFPageGetDictionary(CGPDFDocumentGetPage(_doc, i)) == target) { page = i; break; }
    } else if (CGPDFArrayGetInteger(a, 0, &num)) page = (size_t)num + 1;
    PDFPage *p = nil;
    for (PDFPage *q in self._pages) if (q._source == _doc && q._sourceIndex == page) { p = q; break; }
    if (!p) return nil;
    CGFloat u = kPDFDestinationUnspecifiedValue, x = u, y = u, zoom = u, v[3];
    const char *fit = "";
    CGPDFArrayGetName(a, 1, &fit);
    BOOL h1 = CGPDFArrayGetNumber(a, 2, &v[0]), h2 = CGPDFArrayGetNumber(a, 3, &v[1]), h3 = CGPDFArrayGetNumber(a, 4, &v[2]);
    if (!strcmp(fit, "XYZ")) { if (h1) x = v[0]; if (h2) y = v[1]; if (h3 && v[2] > 0) zoom = v[2]; }
    else if (!strcmp(fit, "FitH") || !strcmp(fit, "FitBH")) { if (h1) y = v[0]; }
    else if (!strcmp(fit, "FitV") || !strcmp(fit, "FitBV")) { if (h1) x = v[0]; }
    else if (!strcmp(fit, "FitR")) {
        CGFloat top;
        if (h1) x = v[0];
        if (CGPDFArrayGetNumber(a, 5, &top)) y = top;
    }
    PDFDestination *d = [[PDFDestination alloc] initWithPage:p atPoint:CGPointMake(x, y)];
    d.zoom = zoom;
    return d;
}
/* for PDFView's link annotations */
- (PDFDestination *)_isim_destinationForObject:(CGPDFObjectRef)object {
    CGPDFArrayRef a = _doc && object ? [self _destArray:object depth:0] : NULL;
    return a ? [self _destination:a] : nil;
}
- (void)_readChildren:(CGPDFDictionaryRef)parent into:(PDFOutline *)node depth:(int)depth {
    CGPDFDictionaryRef item;
    if (depth > 32 || !CGPDFDictionaryGetDictionary(parent, "First", &item)) return;
    for (int guard = 0; item && guard < 100000; guard++) {
        PDFOutline *o = [[PDFOutline alloc] init];
        o.label = pdf_text(item, "Title") ?: @"";
        CGPDFInteger count;
        o.isOpen = CGPDFDictionaryGetInteger(item, "Count", &count) && count > 0;
        CGPDFObjectRef dest; CGPDFDictionaryRef action; const char *type;
        CGPDFArrayRef a = CGPDFDictionaryGetObject(item, "Dest", &dest) ? [self _destArray:dest depth:0] : NULL;
        if (!a && CGPDFDictionaryGetDictionary(item, "A", &action) && CGPDFDictionaryGetName(action, "S", &type) && !strcmp(type, "GoTo") &&
            CGPDFDictionaryGetObject(action, "D", &dest)) a = [self _destArray:dest depth:0];
        if (a) o.destination = [self _destination:a];
        if (CGPDFDictionaryGetDictionary(item, "A", &action)) o.action = [self _isim_actionForDictionary:action];
        [node insertChild:o atIndex:node.numberOfChildren];
        [self _readChildren:item into:o depth:depth + 1];
        CGPDFDictionaryRef next;
        item = CGPDFDictionaryGetDictionary(item, "Next", &next) && next != item ? next : NULL;
    }
}
- (PDFOutline *)outlineRoot {
    if (!_outlineRead) {
        _outlineRead = YES;
        CGPDFDictionaryRef outlines;
        if (_doc && !self.isLocked && CGPDFDictionaryGetDictionary(CGPDFDocumentGetCatalog(_doc), "Outlines", &outlines)) {
            PDFOutline *root = [[PDFOutline alloc] init];
            [root _setDocument:self];
            [self _readChildren:outlines into:root depth:0];
            _outline = root;
        }
    }
    return _outline;
}
- (void)setOutlineRoot:(PDFOutline *)root {
    _outline = root;
    _outlineRead = YES;
    [root _setDocument:self];
}

/* ---- writing ---- */
- (NSDictionary *)_outlineDict:(PDFOutline *)node pages:(NSArray *)pages {
    NSMutableArray *kids = [NSMutableArray array];
    for (NSUInteger i = 0; i < node.numberOfChildren; i++) {
        PDFOutline *c = [node childAtIndex:i];
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        d[(__bridge NSString *)kCGPDFOutlineTitle] = c.label ?: @"";
        NSUInteger at = c.destination.page ? [pages indexOfObjectIdenticalTo:c.destination.page] : NSNotFound;
        if (at != NSNotFound) d[(__bridge NSString *)kCGPDFOutlineDestination] = @(at + 1);
        NSDictionary *sub = [self _outlineDict:c pages:pages];
        if ([sub[(__bridge NSString *)kCGPDFOutlineChildren] count]) d[(__bridge NSString *)kCGPDFOutlineChildren] = sub[(__bridge NSString *)kCGPDFOutlineChildren];
        [kids addObject:d];
    }
    return @{ (__bridge NSString *)kCGPDFOutlineChildren: kids };
}
- (NSData *)dataRepresentationWithOptions:(NSDictionary *)options {
    NSMutableData *out = [NSMutableData data];
    CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)out);
    NSMutableDictionary *aux = [NSMutableDictionary dictionary];
    NSDictionary *a = self.documentAttributes;
    NSDictionary *keys = @{ PDFDocumentTitleAttribute: (__bridge NSString *)kCGPDFContextTitle,
                            PDFDocumentAuthorAttribute: (__bridge NSString *)kCGPDFContextAuthor,
                            PDFDocumentSubjectAttribute: (__bridge NSString *)kCGPDFContextSubject,
                            PDFDocumentCreatorAttribute: (__bridge NSString *)kCGPDFContextCreator,
                            PDFDocumentKeywordsAttribute: (__bridge NSString *)kCGPDFContextKeywords };
    for (NSString *k in keys) if (a[k]) aux[keys[k]] = a[k];
    CGRect first = CGRectMake(0, 0, 612, 792);
    CGContextRef ctx = CGPDFContextCreate(consumer, &first, (__bridge CFDictionaryRef)aux);
    CGDataConsumerRelease(consumer);
    if (!ctx) return nil;
    NSArray *pages = [self._pages copy];
    BOOL burnIn = [options[PDFDocumentBurnInAnnotationsOption] boolValue];
    for (PDFPage *p in pages) {
        CGSize sz = [p _displaySize:kPDFDisplayBoxCropBox];
        CGRect box = CGRectMake(0, 0, sz.width, sz.height);
        NSData *boxData = [NSData dataWithBytes:&box length:sizeof box];
        CGPDFContextBeginPage(ctx, (__bridge CFDictionaryRef)@{ (__bridge NSString *)kCGPDFContextMediaBox: boxData });
        BOOL shows = p.displaysAnnotations;
        p.displaysAnnotations = NO;                                    /* the annotations are written as annotations */
        [p drawWithBox:kPDFDisplayBoxCropBox toContext:ctx];
        p.displaysAnnotations = shows;
        if (burnIn) {
            CGContextSaveGState(ctx);
            [p transformContext:ctx forBox:kPDFDisplayBoxCropBox];
            [p _isim_drawAnnotationsIn:ctx box:kPDFDisplayBoxCropBox printing:YES];
            CGContextRestoreGState(ctx);
        }
        CGPDFContextEndPage(ctx);
    }
    if (self.outlineRoot) CGPDFContextSetOutline(ctx, (__bridge CFDictionaryRef)[self _outlineDict:self.outlineRoot pages:pages]);
    CGPDFContextClose(ctx);
    CGContextRelease(ctx);
    if (burnIn) return out;
    /* the annotations: their dictionaries added to the written pages (Core Graphics rewrites the file) */
    NSMutableArray<PDFAnnotation *> *all = [NSMutableArray array];
    NSMutableArray<NSNumber *> *pageOf = [NSMutableArray array];
    for (NSUInteger i = 0; i < pages.count; i++)
        for (PDFAnnotation *a in [pages[i] _isim_annotations]) { [all addObject:a]; [pageOf addObject:@(i)]; }
    if (!all.count) return out;
    NSMutableArray<NSString *> *sources = [NSMutableArray array];
    for (NSUInteger k = 0; k < all.count; k++) {
        PDFPage *p = pages[pageOf[k].unsignedIntegerValue];
        [sources addObject:[all[k] _isim_pdfSourceWithTransform:[p transformForBox:kPDFDisplayBoxCropBox] pages:pages all:all]];
    }
    const char **cs = calloc(sources.count, sizeof *cs);
    int *po = calloc(sources.count, sizeof *po);
    for (NSUInteger k = 0; k < sources.count; k++) { cs[k] = sources[k].UTF8String; po[k] = pageOf[k].intValue; }
    size_t len = 0;
    void *bytes = isim_CGPDFDataCopyAddingAnnotations(out.bytes, out.length, (int)sources.count, cs, po, &len);
    free(cs); free(po);
    return bytes ? [NSData dataWithBytesNoCopy:bytes length:len freeWhenDone:YES] : out;
}
- (NSData *)dataRepresentation { return [self dataRepresentationWithOptions:@{}]; }
- (BOOL)writeToURL:(NSURL *)url withOptions:(NSDictionary<PDFDocumentWriteOption, id> *)options {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:PDFDocumentDidBeginWriteNotification object:self];
    NSData *d = [self dataRepresentationWithOptions:options ?: @{}];
    BOOL ok = d && [d writeToURL:url atomically:YES];
    [nc postNotificationName:PDFDocumentDidEndWriteNotification object:self];
    return ok;
}
- (BOOL)writeToURL:(NSURL *)url { return [self writeToURL:url withOptions:nil]; }
- (BOOL)writeToFile:(NSString *)path withOptions:(NSDictionary<PDFDocumentWriteOption, id> *)options {
    return path && [self writeToURL:[NSURL fileURLWithPath:path] withOptions:options];
}
- (BOOL)writeToFile:(NSString *)path { return [self writeToFile:path withOptions:nil]; }
@end
