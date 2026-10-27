/* isim PDFKit: PDFSelection and the document's text search (issue #358). Adapted: a selection is a set of character
 * indexes per page, over the page's text and character rectangles (poppler's, PDFPage.string); lines are the text
 * between line breaks. Drawing fills the selected characters' rectangles. */
#import "pdfkit_internal.h"
#import <objc/runtime.h>
#import <objc/message.h>
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"   /* PDFPage's and PDFDocument's, in categories */

NSNotificationName const PDFDocumentDidBeginFindNotification = @"PDFDidBeginDocumentFind";
NSNotificationName const PDFDocumentDidEndFindNotification = @"PDFDidEndDocumentFind";
NSNotificationName const PDFDocumentDidBeginPageFindNotification = @"PDFDidBeginPageFind";
NSNotificationName const PDFDocumentDidEndPageFindNotification = @"PDFDidEndPageFind";
NSNotificationName const PDFDocumentDidFindMatchNotification = @"PDFDidFindMatch";
NSString *const PDFDocumentFoundSelectionKey = @"PDFDocumentFoundSelection";
NSString *const PDFDocumentPageIndexKey = @"PDFDocumentPageIndex";

@implementation PDFSelection {
    __weak PDFDocument *_document;
    NSMutableArray<PDFPage *> *_added;                         /* pages in the order they were added */
    NSMapTable<PDFPage *, NSMutableIndexSet *> *_sets;         /* each page's selected characters (UTF-16 indexes) */
}
- (instancetype)initWithDocument:(PDFDocument *)document {
    if (!(self = [super init])) return nil;
    _document = document;
    _added = [NSMutableArray array];
    _sets = [NSMapTable strongToStrongObjectsMapTable];
    return self;
}
- (instancetype)init { PDFDocument *none = nil; return [self initWithDocument:none]; }
- (id)copyWithZone:(NSZone *)zone {
    PDFSelection *s = [[PDFSelection alloc] initWithDocument:_document];
    for (PDFPage *p in _added) { [s->_added addObject:p]; [s->_sets setObject:[[_sets objectForKey:p] mutableCopy] forKey:p]; }
    s.color = _color;
    return s;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<PDFSelection %p: %lu page(s), \"%@\">", self, (unsigned long)_added.count, self.string ?: @""];
}

/* ---- the model ---- */
- (PDFDocument *)_doc { return _document ?: _added.firstObject.document; }
- (void)_isim_addRange:(NSRange)range onPage:(PDFPage *)page {
    if (!page || !range.length) return;
    NSUInteger len = page.string.length;
    if (range.location >= len) return;
    if (NSMaxRange(range) > len) range.length = len - range.location;
    NSMutableIndexSet *set = [_sets objectForKey:page];
    if (!set) { set = [NSMutableIndexSet indexSet]; [_sets setObject:set forKey:page]; [_added addObject:page]; }
    [set addIndexesInRange:range];
}
- (BOOL)_isim_isEmpty {
    for (PDFPage *p in _added) if ([_sets objectForKey:p].count) return NO;
    return YES;
}
- (NSArray<PDFPage *> *)pages {
    PDFDocument *doc = self._doc;
    NSMutableArray *pages = [NSMutableArray array];
    for (PDFPage *p in _added) if ([_sets objectForKey:p].count) [pages addObject:p];
    if (!doc) return pages;
    return [pages sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(PDFPage *a, PDFPage *b) {
        NSUInteger ia = [doc indexForPage:a], ib = [doc indexForPage:b];
        return ia == ib ? NSOrderedSame : ia < ib ? NSOrderedAscending : NSOrderedDescending;
    }];
}
- (void)_isim_enumerate:(void (^)(PDFPage *, NSRange, BOOL *))block {
    __block BOOL stop = NO;
    for (PDFPage *p in self.pages) {
        [[_sets objectForKey:p] enumerateRangesUsingBlock:^(NSRange r, BOOL *s) { block(p, r, &stop); *s = stop; }];
        if (stop) return;
    }
}

/* ---- text ---- */
- (NSString *)string {
    NSMutableString *out = [NSMutableString string];
    __block BOOL first = YES;
    [self _isim_enumerate:^(PDFPage *p, NSRange r, BOOL *stop) {
        if (!first && ![out hasSuffix:@"\n"]) [out appendString:@"\n"];
        first = NO;
        [out appendString:[p.string substringWithRange:r]];
    }];
    return first ? nil : out;
}
- (NSAttributedString *)attributedString {
    NSString *s = self.string;
    return s ? [[NSAttributedString alloc] initWithString:s] : nil;
}
- (NSArray<NSValue *> *)_isim_rectsForPage:(PDFPage *)page {
    NSMutableArray *rects = [NSMutableArray array];
    NSIndexSet *set = [_sets objectForKey:page];
    if (!set.count) return rects;
    NSString *s = page.string;
    const CGRect *r = page._isim_unitRects;
    [set enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) {
        if (i >= s.length || [s characterAtIndex:i] == '\n' || CGRectIsEmpty(r[i])) return;
        if (i > 0 && isim_low_surrogate([s characterAtIndex:i])) return;   /* the pair's first unit has it */
        [rects addObject:[NSValue valueWithCGRect:r[i]]];
    }];
    return rects;
}
- (CGRect)boundsForPage:(PDFPage *)page {
    CGRect u = CGRectNull;
    for (NSValue *v in [self _isim_rectsForPage:page]) u = CGRectUnion(u, v.CGRectValue);
    return CGRectIsNull(u) ? CGRectZero : u;
}
- (NSUInteger)numberOfTextRangesOnPage:(PDFPage *)page {
    __block NSUInteger n = 0;
    [[_sets objectForKey:page] enumerateRangesUsingBlock:^(NSRange r, BOOL *stop) { n++; }];
    return n;
}
- (NSRange)rangeAtIndex:(NSUInteger)index onPage:(PDFPage *)page {
    __block NSUInteger n = 0;
    __block NSRange found = NSMakeRange(NSNotFound, 0);
    [[_sets objectForKey:page] enumerateRangesUsingBlock:^(NSRange r, BOOL *stop) {
        if (n++ == index) { found = r; *stop = YES; }
    }];
    return found;
}
- (NSArray<PDFSelection *> *)selectionsByLine {
    NSMutableArray *lines = [NSMutableArray array];
    [self _isim_enumerate:^(PDFPage *p, NSRange r, BOOL *stop) {
        NSString *s = p.string;
        NSUInteger start = r.location;
        for (NSUInteger i = r.location; i <= NSMaxRange(r); i++) {
            if (i < NSMaxRange(r) && [s characterAtIndex:i] != '\n') continue;
            if (i > start) {
                PDFSelection *line = [[PDFSelection alloc] initWithDocument:self._doc];
                [line _isim_addRange:NSMakeRange(start, i - start) onPage:p];
                line.color = self.color;
                [lines addObject:line];
            }
            start = i + 1;
        }
    }];
    return lines;
}

/* ---- changing it ---- */
- (void)addSelection:(PDFSelection *)selection {
    if (!selection || selection == self) return;
    if (!_document) _document = selection->_document;
    [selection _isim_enumerate:^(PDFPage *p, NSRange r, BOOL *stop) { [self _isim_addRange:r onPage:p]; }];
}
- (void)addSelections:(NSArray<PDFSelection *> *)selections {
    for (PDFSelection *s in selections) [self addSelection:s];
}
- (void)extendSelectionAtEnd:(NSInteger)succeed {
    PDFPage *p = self.pages.lastObject;
    NSMutableIndexSet *set = p ? [_sets objectForKey:p] : nil;
    if (!set.count || !succeed) return;
    NSUInteger last = set.lastIndex, len = p.string.length;
    if (succeed > 0) [set addIndexesInRange:NSMakeRange(last + 1, MIN((NSUInteger)succeed, len - MIN(len, last + 1)))];
    else for (NSInteger i = 0; i < -succeed && set.count > 1; i++) [set removeIndex:set.lastIndex];
}
- (void)extendSelectionAtStart:(NSInteger)precede {
    PDFPage *p = self.pages.firstObject;
    NSMutableIndexSet *set = p ? [_sets objectForKey:p] : nil;
    if (!set.count || !precede) return;
    NSUInteger first = set.firstIndex;
    if (precede > 0) { NSUInteger n = MIN((NSUInteger)precede, first); [set addIndexesInRange:NSMakeRange(first - n, n)]; }
    else for (NSInteger i = 0; i < -precede && set.count > 1; i++) [set removeIndex:set.firstIndex];
}
- (void)extendSelectionForLineBoundaries {
    for (PDFPage *p in self.pages) {
        NSMutableIndexSet *set = [_sets objectForKey:p];
        NSMutableIndexSet *grown = [set mutableCopy];
        [set enumerateRangesUsingBlock:^(NSRange r, BOOL *stop) {
            NSRange a = [p _isim_lineRangeAt:r.location], b = [p _isim_lineRangeAt:NSMaxRange(r) - 1];
            [grown addIndexesInRange:NSMakeRange(a.location, NSMaxRange(b) - a.location)];
        }];
        [set addIndexes:grown];
    }
}

/* ---- drawing ---- */
static UIColor *active_color(void) { return [UIColor colorWithRed:0.42 green:0.62 blue:1.0 alpha:0.42]; }
- (void)drawForPage:(PDFPage *)page active:(BOOL)active { [self drawForPage:page withBox:kPDFDisplayBoxCropBox active:active]; }
- (void)drawForPage:(PDFPage *)page withBox:(PDFDisplayBox)box active:(BOOL)active {
    CGContextRef c = UIGraphicsGetCurrentContext();
    if (!c || !page) return;
    UIColor *color = _color ?: active ? active_color() : [UIColor colorWithWhite:0.6 alpha:0.35];
    CGContextSaveGState(c);
    CGContextSetFillColorWithColor(c, color.CGColor);
    for (NSValue *v in [self _isim_rectsForPage:page]) CGContextFillRect(c, CGRectInset(v.CGRectValue, -0.5, -0.5));
    CGContextRestoreGState(c);
}
@end

/* ---------------- pages: selections ---------------- */
@implementation PDFPage (Selections)
- (PDFSelection *)_selection:(NSRange)range {
    PDFSelection *s = [[PDFSelection alloc] initWithDocument:self.document];
    [s _isim_addRange:range onPage:self];
    return s._isim_isEmpty ? nil : s;
}
- (PDFSelection *)selectionForRange:(NSRange)range {
    NSUInteger len = self.string.length;
    if (range.location >= len) return nil;
    return [self _selection:NSMakeRange(range.location, MIN(range.length, len - range.location))];
}
- (PDFSelection *)selectionForRect:(CGRect)rect {
    NSString *s = self.string;
    const CGRect *r = self._isim_unitRects;
    NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
    rect = CGRectStandardize(rect);
    for (NSUInteger i = 0; i < s.length; i++)
        if ([s characterAtIndex:i] != '\n' && !CGRectIsEmpty(r[i]) && CGRectContainsPoint(rect, CGPointMake(CGRectGetMidX(r[i]), CGRectGetMidY(r[i]))))
            [set addIndex:i];
    for (NSUInteger i = 1; i + 1 < s.length; i++)                      /* the breaks between selected lines */
        if ([s characterAtIndex:i] == '\n' && [set containsIndex:i - 1] && [set containsIndex:i + 1]) [set addIndex:i];
    if (!set.count) return nil;
    PDFSelection *sel = [[PDFSelection alloc] initWithDocument:self.document];
    [set enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) { [sel _isim_addRange:range onPage:self]; }];
    return sel;
}
- (PDFSelection *)selectionFromPoint:(CGPoint)start toPoint:(CGPoint)end {
    NSUInteger a = [self _isim_characterNearPoint:start], b = [self _isim_characterNearPoint:end];
    if (a == NSNotFound || b == NSNotFound) return nil;
    if (a > b) { NSUInteger t = a; a = b; b = t; }
    return [self _selection:NSMakeRange(a, b - a + 1)];
}
- (PDFSelection *)selectionForWordAtPoint:(CGPoint)point {
    NSInteger i = [self characterIndexAtPoint:point];
    return i < 0 ? nil : [self _selection:[self _isim_wordRangeAt:(NSUInteger)i]];
}
- (PDFSelection *)selectionForLineAtPoint:(CGPoint)point {
    NSInteger i = [self characterIndexAtPoint:point];
    return i < 0 ? nil : [self _selection:[self _isim_lineRangeAt:(NSUInteger)i]];
}
@end

/* ---------------- documents: selections and find ---------------- */
@implementation PDFDocument (Find)
static char kFinding, kStep;
- (NSNumber *)_findGeneration { return objc_getAssociatedObject(self, &kFinding); }
- (BOOL)isFinding { return [objc_getAssociatedObject(self, &kFinding) integerValue] > 0; }

- (PDFSelection *)selectionForEntireDocument {
    PDFSelection *s = [[PDFSelection alloc] initWithDocument:self];
    for (NSUInteger i = 0; i < self.pageCount; i++) {
        PDFPage *p = [self pageAtIndex:i];
        [s _isim_addRange:NSMakeRange(0, p.string.length) onPage:p];
    }
    return s._isim_isEmpty ? nil : s;
}
- (PDFSelection *)selectionFromPage:(PDFPage *)startPage atCharacterIndex:(NSUInteger)startChar toPage:(PDFPage *)endPage atCharacterIndex:(NSUInteger)endChar {
    NSUInteger a = [self indexForPage:startPage], b = [self indexForPage:endPage];
    if (a == NSNotFound || b == NSNotFound) return nil;
    if (a > b || (a == b && startChar > endChar)) {
        NSUInteger t = a; a = b; b = t; t = startChar; startChar = endChar; endChar = t;
    }
    PDFSelection *s = [[PDFSelection alloc] initWithDocument:self];
    for (NSUInteger i = a; i <= b; i++) {
        PDFPage *p = [self pageAtIndex:i];
        NSUInteger len = p.string.length;
        NSUInteger from = i == a ? startChar : 0, to = i == b ? MIN(endChar + 1, len) : len;
        if (to > from) [s _isim_addRange:NSMakeRange(from, to - from) onPage:p];
    }
    return s._isim_isEmpty ? nil : s;
}
- (PDFSelection *)selectionFromPage:(PDFPage *)startPage atPoint:(CGPoint)startPoint toPage:(PDFPage *)endPage atPoint:(CGPoint)endPoint {
    NSUInteger a = [startPage _isim_characterNearPoint:startPoint], b = [endPage _isim_characterNearPoint:endPoint];
    if (a == NSNotFound || b == NSNotFound) return nil;
    return [self selectionFromPage:startPage atCharacterIndex:a toPage:endPage atCharacterIndex:b];
}
- (PDFSelection *)selectionFromPage:(PDFPage *)startPage atPoint:(CGPoint)startPoint toPage:(PDFPage *)endPage atPoint:(CGPoint)endPoint
                    withGranularity:(PDFSelectionGranularity)granularity {
    NSUInteger a = [startPage _isim_characterNearPoint:startPoint], b = [endPage _isim_characterNearPoint:endPoint];
    if (a == NSNotFound || b == NSNotFound) return nil;
    NSUInteger ia = [self indexForPage:startPage], ib = [self indexForPage:endPage];
    if (ia > ib || (ia == ib && a > b)) { PDFPage *t = startPage; startPage = endPage; endPage = t; NSUInteger u = a; a = b; b = u; }
    if (granularity != PDFSelectionGranularityCharacter) {
        NSRange ra = granularity == PDFSelectionGranularityWord ? [startPage _isim_wordRangeAt:a] : [startPage _isim_lineRangeAt:a];
        NSRange rb = granularity == PDFSelectionGranularityWord ? [endPage _isim_wordRangeAt:b] : [endPage _isim_lineRangeAt:b];
        a = ra.location; b = NSMaxRange(rb) > 0 ? NSMaxRange(rb) - 1 : 0;
    }
    return [self selectionFromPage:startPage atCharacterIndex:a toPage:endPage atCharacterIndex:b];
}

/* the outline item a selection is under: the last item (in document order) whose destination is at or before the
 * selection's start */
- (void)_outlineItems:(PDFOutline *)node into:(NSMutableArray *)out {
    for (NSUInteger i = 0; i < node.numberOfChildren; i++) {
        PDFOutline *c = [node childAtIndex:i];
        [out addObject:c];
        [self _outlineItems:c into:out];
    }
}
- (PDFOutline *)outlineItemForSelection:(PDFSelection *)selection {
    PDFPage *first = selection.pages.firstObject;
    if (!first || !self.outlineRoot) return nil;
    NSUInteger page = [self indexForPage:first];
    CGFloat top = CGRectGetMaxY([selection boundsForPage:first]);
    NSMutableArray<PDFOutline *> *items = [NSMutableArray array];
    [self _outlineItems:self.outlineRoot into:items];
    PDFOutline *best = nil;
    NSUInteger bestPage = 0; CGFloat bestY = 0;
    for (PDFOutline *o in items) {
        PDFDestination *d = o.destination ?: ([o.action isKindOfClass:[PDFActionGoTo class]] ? ((PDFActionGoTo *)o.action).destination : nil);
        NSUInteger p = d.page ? [self indexForPage:d.page] : NSNotFound;
        if (p == NSNotFound || p > page) continue;
        CGFloat y = d.point.y == kPDFDestinationUnspecifiedValue ? CGFLOAT_MAX : d.point.y;
        if (p == page && y < top - 1 && y != CGFLOAT_MAX) continue;           /* below the selection */
        if (!best || p > bestPage || (p == bestPage && y <= bestY)) { best = o; bestPage = p; bestY = y; }
    }
    return best;
}

/* ---- find ---- */
- (NSArray<PDFSelection *> *)_find:(NSString *)string onPage:(PDFPage *)page options:(NSStringCompareOptions)options {
    NSMutableArray *found = [NSMutableArray array];
    NSString *s = page.string;
    if (!string.length || !s.length) return found;
    options &= ~(NSStringCompareOptions)(NSBackwardsSearch | NSAnchoredSearch);
    NSRange search = NSMakeRange(0, s.length);
    while (search.length) {
        NSRange r = [s rangeOfString:string options:options range:search];
        if (r.location == NSNotFound || !r.length) break;
        PDFSelection *sel = [[PDFSelection alloc] initWithDocument:self];
        [sel _isim_addRange:r onPage:page];
        [found addObject:sel];
        search = NSMakeRange(NSMaxRange(r), s.length - NSMaxRange(r));
    }
    return found;
}
- (NSArray<PDFSelection *> *)findString:(NSString *)string withOptions:(NSStringCompareOptions)options {
    NSMutableArray *all = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.pageCount; i++) [all addObjectsFromArray:[self _find:string onPage:[self pageAtIndex:i] options:options]];
    return all;
}
- (PDFSelection *)findString:(NSString *)string fromSelection:(PDFSelection *)selection withOptions:(NSStringCompareOptions)options {
    if (!string.length || !self.pageCount) return nil;
    BOOL back = (options & NSBackwardsSearch) != 0;
    NSStringCompareOptions o = options & ~(NSStringCompareOptions)NSAnchoredSearch;
    NSUInteger page; NSUInteger at;                                   /* where to start, on that page */
    if (selection && !selection._isim_isEmpty) {
        __block PDFPage *firstPage = nil, *lastPage = nil; __block NSUInteger firstChar = 0, lastEnd = 0;
        [selection _isim_enumerate:^(PDFPage *p, NSRange r, BOOL *stop) {
            if (!firstPage) { firstPage = p; firstChar = r.location; }
            lastPage = p; lastEnd = NSMaxRange(r);
        }];
        page = [self indexForPage:back ? firstPage : lastPage];
        at = back ? firstChar : lastEnd;
        if (page == NSNotFound) return nil;
    } else {
        page = back ? self.pageCount - 1 : 0;
        at = back ? [self pageAtIndex:page].string.length : 0;
    }
    for (NSUInteger n = 0; n < self.pageCount; n++) {
        PDFPage *p = [self pageAtIndex:page];
        NSString *s = p.string ?: @"";
        NSRange range = back ? NSMakeRange(0, MIN(at, s.length)) : NSMakeRange(MIN(at, s.length), s.length - MIN(at, s.length));
        NSRange r = range.length ? [s rangeOfString:string options:o range:range] : NSMakeRange(NSNotFound, 0);
        if (r.location != NSNotFound && r.length) {
            PDFSelection *sel = [[PDFSelection alloc] initWithDocument:self];
            [sel _isim_addRange:r onPage:p];
            return sel;
        }
        if (back) { if (page == 0) return nil; page--; at = [self pageAtIndex:page].string.length; }
        else { if (page + 1 >= self.pageCount) return nil; page++; at = 0; }
    }
    return nil;
}
- (void)_post:(NSNotificationName)name userInfo:(NSDictionary *)info selector:(SEL)sel {
    NSNotification *n = [NSNotification notificationWithName:name object:self userInfo:info];
    [[NSNotificationCenter defaultCenter] postNotification:n];
    id<PDFDocumentDelegate> d = self.delegate;
    if ([d respondsToSelector:sel]) ((void (*)(id, SEL, NSNotification *))objc_msgSend)(d, sel, n);
}
/* asynchronous: one page per turn of the main queue, so the app stays responsive and can cancel */
- (void)beginFindStrings:(NSArray<NSString *> *)strings withOptions:(NSStringCompareOptions)options {
    [self cancelFindString];
    static NSInteger generations;
    NSNumber *gen = @(++generations);
    objc_setAssociatedObject(self, &kFinding, gen, OBJC_ASSOCIATION_RETAIN);
    NSArray *query = [strings copy];
    __weak PDFDocument *weakSelf = self;
    void (^step)(NSUInteger) = ^(NSUInteger page) {
        PDFDocument *me = weakSelf;
        if (!me || ![[me _findGeneration] isEqual:gen]) return;
        if (page >= me.pageCount) {
            objc_setAssociatedObject(me, &kFinding, nil, OBJC_ASSOCIATION_RETAIN);
            objc_setAssociatedObject(me, &kStep, nil, OBJC_ASSOCIATION_COPY);
            [me _post:PDFDocumentDidEndFindNotification userInfo:nil selector:@selector(documentDidEndDocumentFind:)];
            return;
        }
        NSDictionary *info = @{ PDFDocumentPageIndexKey: @(page) };
        [me _post:PDFDocumentDidBeginPageFindNotification userInfo:info selector:@selector(documentDidBeginPageFind:)];
        NSMutableArray *found = [NSMutableArray array];
        for (NSString *q in query) [found addObjectsFromArray:[me _find:q onPage:[me pageAtIndex:page] options:options]];
        for (PDFSelection *sel in found) {
            if (![[me _findGeneration] isEqual:gen]) return;
            [me _post:PDFDocumentDidFindMatchNotification userInfo:@{ PDFDocumentFoundSelectionKey: sel } selector:@selector(documentDidFindMatch:)];
            if ([me.delegate respondsToSelector:@selector(didMatchString:)]) [me.delegate didMatchString:sel];
        }
        [me _post:PDFDocumentDidEndPageFindNotification userInfo:info selector:@selector(documentDidEndPageFind:)];
        dispatch_async(dispatch_get_main_queue(), ^{
            PDFDocument *again = weakSelf;
            void (^next)(NSUInteger) = again ? objc_getAssociatedObject(again, &kStep) : nil;
            if (next) next(page + 1);
        });
    };
    objc_setAssociatedObject(self, &kStep, step, OBJC_ASSOCIATION_COPY);
    [self _post:PDFDocumentDidBeginFindNotification userInfo:nil selector:@selector(documentDidBeginDocumentFind:)];
    dispatch_async(dispatch_get_main_queue(), ^{
        PDFDocument *me = weakSelf;
        void (^first)(NSUInteger) = me ? objc_getAssociatedObject(me, &kStep) : nil;
        if (first) first(0);
    });
}
- (void)beginFindString:(NSString *)string withOptions:(NSStringCompareOptions)options {
    [self beginFindStrings:string ? @[ string ] : @[] withOptions:options];
}
- (void)cancelFindString {
    if (!self.isFinding) return;
    objc_setAssociatedObject(self, &kFinding, nil, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(self, &kStep, nil, OBJC_ASSOCIATION_COPY);
    [self _post:PDFDocumentDidEndFindNotification userInfo:nil selector:@selector(documentDidEndDocumentFind:)];
}
@end
