/* isim PDFKit views (issue #270): PDFView and PDFThumbnailView in isim's UIKit (adapted). PDFView is a UIScrollView of
 * page views that isim lays out itself at the scale factor (each page view redraws at its size, so pages stay sharp
 * at every zoom): continuous or single pages, one or two up, vertical or horizontal, as a book or right to left, with
 * page breaks and shadows. Pinch zooms, a double tap zooms in or back to fit, a tap on a link annotation follows it
 * (a URL through the delegate or UIApplication, a destination inside the document). */
#import <PDFKit/PDFKit.h>

NSNotificationName const PDFViewDocumentChangedNotification = @"PDFViewDocumentChanged";
NSNotificationName const PDFViewChangedHistoryNotification = @"PDFViewChangedHistory";
NSNotificationName const PDFViewPageChangedNotification = @"PDFViewChangedPage";
NSNotificationName const PDFViewScaleChangedNotification = @"PDFViewScaleChanged";
NSNotificationName const PDFViewAnnotationHitNotification = @"PDFViewAnnotationHit";
NSNotificationName const PDFViewCopyPermissionNotification = @"PDFViewCopyPermission";
NSNotificationName const PDFViewPrintPermissionNotification = @"PDFViewPrintPermission";
NSNotificationName const PDFViewAnnotationWillHitNotification = @"PDFViewAnnotationWillHit";
NSNotificationName const PDFViewSelectionChangedNotification = @"PDFViewSelectionChanged";
NSNotificationName const PDFViewDisplayModeChangedNotification = @"PDFViewDisplayModeChanged";
NSNotificationName const PDFViewDisplayBoxChangedNotification = @"PDFViewDisplayBoxChanged";
NSNotificationName const PDFViewVisiblePagesChangedNotification = @"PDFViewVisiblePagesChanged";
NSNotificationName const PDFThumbnailViewDocumentEditedNotification = @"PDFThumbnailViewDocumentEdited";

/* PDFKit.m: a document's destination for a destination object (an array, a name, a string, a GoTo dictionary) */
@interface PDFDocument (IsimDestinations)
- (nullable PDFDestination *)_isim_destinationForObject:(CGPDFObjectRef)object;
@end

@class PDFView;
@interface PDFView (IsimPages)
- (void)_drawPage:(PDFPage *)page inPageView:(UIView *)view;
@end

/* ---------------- a page's view ---------------- */
@interface _PDFPageView : UIView
@property (nonatomic, strong) PDFPage *page;
@property (nonatomic, weak) PDFView *pdfView;
@property (nonatomic, strong) UIView *overlay;
@end
@implementation _PDFPageView
- (void)drawRect:(CGRect)rect { [_pdfView _drawPage:_page inPageView:self]; }
@end

/* ---------------- PDFView ---------------- */
@interface PDFView () <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@end
@implementation PDFView {
    UIScrollView *_scroll;
    UIView *_docView;
    NSMutableArray<_PDFPageView *> *_pageViews;
    PDFPage *_current;
    NSArray<PDFPage *> *_visible;
    NSMutableArray<PDFDestination *> *_back, *_forward;
    BOOL _usingPageVC, _layingOut;
    CGFloat _pinchStart;
    UIColor *_background;
}
@synthesize scaleFactor = _scaleFactor;

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    [self _setUp];
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if (!(self = [super initWithCoder:coder])) return nil;
    [self _setUp];
    return self;
}
- (void)_setUp {
    _displayMode = kPDFDisplaySinglePageContinuous;
    _displayBox = kPDFDisplayBoxCropBox;
    _displaysPageBreaks = YES;
    _pageBreakMargins = UIEdgeInsetsMake(4.75, 4, 4.75, 4);
    _pageShadowsEnabled = YES;
    _shouldAntiAlias = YES;
    _interpolationQuality = kPDFInterpolationQualityLow;
    _scaleFactor = 1;
    _minScaleFactor = 0.25;
    _maxScaleFactor = 5;
    _back = [NSMutableArray array]; _forward = [NSMutableArray array];
    _pageViews = [NSMutableArray array];
    _background = [UIColor secondarySystemBackgroundColor];          /* the gray behind the pages */
    [super setBackgroundColor:_background];
    self.clipsToBounds = YES;
    _scroll = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.delegate = self;
    _scroll.backgroundColor = UIColor.clearColor;
    _scroll.accessibilityIdentifier = @"pdfview-scroll";
    [self addSubview:_scroll];
    _docView = [[UIView alloc] initWithFrame:CGRectZero];
    [_scroll addSubview:_docView];
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(_pinch:)];
    UITapGestureRecognizer *dbl = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_doubleTap:)];
    dbl.numberOfTapsRequired = 2;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tap:)];
    [tap requireGestureRecognizerToFail:dbl];
    for (UIGestureRecognizer *g in @[ pinch, dbl, tap ]) { g.delegate = self; [_scroll addGestureRecognizer:g]; }
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g { return !_inMarkupMode; }

/* ---- properties that lay the pages out again ---- */
- (void)setDocument:(PDFDocument *)document {
    if (document == _document) return;
    _document = document;
    _current = document.pageCount ? [document pageAtIndex:0] : nil;
    [_back removeAllObjects]; [_forward removeAllObjects];
    [self _rebuild];
    [_scroll setContentOffset:CGPointZero animated:NO];
    [self _post:PDFViewDocumentChangedNotification];
    [self _post:PDFViewPageChangedNotification];
}
- (void)setDisplayMode:(PDFDisplayMode)mode {
    if (mode == _displayMode) return;
    _displayMode = mode;
    [self _rebuild];
    [self _post:PDFViewDisplayModeChangedNotification];
}
- (void)setDisplayBox:(PDFDisplayBox)box {
    if (box == _displayBox) return;
    _displayBox = box;
    [self _rebuild];
    [self _post:PDFViewDisplayBoxChangedNotification];
}
- (void)setDisplayDirection:(PDFDisplayDirection)d { _displayDirection = d; [self _rebuild]; }
- (void)setDisplaysPageBreaks:(BOOL)b { _displaysPageBreaks = b; [self _rebuild]; }
- (void)setPageBreakMargins:(UIEdgeInsets)m { _pageBreakMargins = m; [self _rebuild]; }
- (void)setDisplaysAsBook:(BOOL)b { _displaysAsBook = b; [self _rebuild]; }
- (void)setDisplaysRTL:(BOOL)b { _displaysRTL = b; [self _rebuild]; }
- (void)setPageShadowsEnabled:(BOOL)b { _pageShadowsEnabled = b; [self _rebuild]; }
- (void)setInterpolationQuality:(PDFInterpolationQuality)q { _interpolationQuality = q; [self _redraw]; }
- (void)setBackgroundColor:(UIColor *)c { _background = c ?: [UIColor secondarySystemBackgroundColor]; [super setBackgroundColor:_background]; }
- (UIColor *)backgroundColor { return _background; }
- (void)setPageOverlayViewProvider:(id<PDFPageOverlayViewProvider>)p { _pageOverlayViewProvider = p; [self _rebuild]; }
- (UIView *)documentView { return _document ? _docView : nil; }
- (void)layoutDocumentView { [self _layout]; }
- (void)annotationsChangedOnPage:(PDFPage *)page { for (_PDFPageView *v in _pageViews) if (v.page == page) [v setNeedsDisplay]; }
- (void)_redraw { for (_PDFPageView *v in _pageViews) [v setNeedsDisplay]; }
- (void)_post:(NSNotificationName)name { [[NSNotificationCenter defaultCenter] postNotificationName:name object:self]; }

/* ---- drawing a page ---- */
- (void)_drawPage:(PDFPage *)page inPageView:(UIView *)view {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = view.bounds;
    CGContextSetRGBFillColor(c, 1, 1, 1, 1);
    CGContextFillRect(c, b);
    CGContextSaveGState(c);
    CGSize d = [self _pageSize:page];
    CGContextTranslateCTM(c, 0, b.size.height);                        /* UIKit is y-down; pages are y-up */
    CGContextScaleCTM(c, b.size.width / d.width, -b.size.height / d.height);
    CGContextSetShouldAntialias(c, _shouldAntiAlias);
    CGContextSetInterpolationQuality(c, _interpolationQuality == kPDFInterpolationQualityNone ? kCGInterpolationNone
                                        : _interpolationQuality == kPDFInterpolationQualityHigh ? kCGInterpolationHigh : kCGInterpolationLow);
    [self drawPage:page toContext:c];
    CGContextRestoreGState(c);
}
- (void)drawPage:(PDFPage *)page toContext:(CGContextRef)context {
    [page drawWithBox:_displayBox toContext:context];
    [self drawPagePost:page toContext:context];
}
- (void)drawPagePost:(PDFPage *)page toContext:(CGContextRef)context {}

/* ---- layout ---- */
- (CGSize)_pageSize:(PDFPage *)page {
    CGRect b = [page boundsForBox:_displayBox];
    CGSize s = page.rotation % 180 ? CGSizeMake(b.size.height, b.size.width) : b.size;
    return CGSizeMake(MAX(s.width, 1), MAX(s.height, 1));
}
- (BOOL)_continuous { return !_usingPageVC && (_displayMode == kPDFDisplaySinglePageContinuous || _displayMode == kPDFDisplayTwoUpContinuous); }
- (BOOL)_twoUp { return !_usingPageVC && (_displayMode == kPDFDisplayTwoUp || _displayMode == kPDFDisplayTwoUpContinuous); }
- (BOOL)_horizontal { return _usingPageVC || (_displayDirection == kPDFDisplayDirectionHorizontal && _displayMode == kPDFDisplaySinglePageContinuous); }
- (UIEdgeInsets)_margins { return _displaysPageBreaks ? _pageBreakMargins : UIEdgeInsetsZero; }
/* the rows of pages (two up: pairs; as a book the first page alone), each in display order (right to left reversed) */
- (NSArray<NSArray<PDFPage *> *> *)_rows {
    NSMutableArray *rows = [NSMutableArray array];
    NSUInteger n = _document.pageCount, i = 0;
    if (self._twoUp && _displaysAsBook && n) { [rows addObject:@[ [_document pageAtIndex:0] ]]; i = 1; }
    while (i < n) {
        NSMutableArray *row = [NSMutableArray arrayWithObject:[_document pageAtIndex:i++]];
        if (self._twoUp && i < n) [row addObject:[_document pageAtIndex:i++]];
        if (_displaysRTL) row = [[[row reverseObjectEnumerator] allObjects] mutableCopy];
        [rows addObject:row];
    }
    if (_displaysRTL && self._horizontal) return [[rows reverseObjectEnumerator] allObjects];
    return rows;
}
- (NSArray<PDFPage *> *)_rowOf:(PDFPage *)page {
    for (NSArray *row in self._rows) if ([row indexOfObjectIdenticalTo:page] != NSNotFound) return row;
    return nil;
}
- (CGSize)rowSizeForPage:(PDFPage *)page {
    UIEdgeInsets m = self._margins;
    CGSize s = CGSizeZero;
    for (PDFPage *p in [self _rowOf:page]) {
        CGSize d = [self _pageSize:p];
        s.width += (d.width + m.left + m.right) * _scaleFactor;
        s.height = MAX(s.height, (d.height + m.top + m.bottom) * _scaleFactor);
    }
    return s;
}
/* the rows laid out now: all of them when continuous, else the current page's */
- (NSArray<NSArray<PDFPage *> *> *)_shownRows {
    if (self._continuous) return self._rows;
    NSArray *row = _current ? [self _rowOf:_current] : nil;
    return row ? @[ row ] : @[];
}
- (CGFloat)scaleFactorForSizeToFit {
    CGSize b = self.bounds.size;
    if (!_document.pageCount || b.width <= 0 || b.height <= 0) return 1;
    UIEdgeInsets m = self._margins;
    CGFloat w = 0, h = 0;
    for (NSArray *row in (self._continuous ? self._rows : self._shownRows)) {
        CGFloat rw = 0, rh = 0;
        for (PDFPage *p in row) { CGSize d = [self _pageSize:p]; rw += d.width + m.left + m.right; rh = MAX(rh, d.height + m.top + m.bottom); }
        w = MAX(w, rw); h = MAX(h, rh);
    }
    if (_usingPageVC || !self._continuous) return MIN(b.width / w, b.height / h);
    return self._horizontal ? b.height / h : b.width / w;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    [self _layout];
}
- (void)_rebuild {
    for (_PDFPageView *v in _pageViews) {
        if (v.overlay && [_pageOverlayViewProvider respondsToSelector:@selector(pdfView:willEndDisplayingOverlayView:forPage:)])
            [_pageOverlayViewProvider pdfView:self willEndDisplayingOverlayView:v.overlay forPage:v.page];
        [v removeFromSuperview];
    }
    [_pageViews removeAllObjects];
    [self _layout];
}
- (void)_layout {
    if (_layingOut) return;
    _layingOut = YES;
    _scroll.frame = self.bounds;
    if (_autoScales) _scaleFactor = [self _clampScale:self.scaleFactorForSizeToFit];
    CGFloat s = _scaleFactor;
    UIEdgeInsets m = self._margins;
    CGSize bounds = self.bounds.size;
    NSArray *rows = self._shownRows;
    BOOL horizontal = self._horizontal;
    /* the rows' sizes, then the document's */
    CGFloat along = 0, across = 0;
    NSMutableArray *sizes = [NSMutableArray array];
    for (NSArray *row in rows) {
        CGFloat rw = 0, rh = 0;
        for (PDFPage *p in row) { CGSize d = [self _pageSize:p]; rw += (d.width + m.left + m.right) * s; rh = MAX(rh, (d.height + m.top + m.bottom) * s); }
        if (_usingPageVC) { rw = MAX(rw, bounds.width); rh = MAX(rh, bounds.height); }   /* a page per screen */
        [sizes addObject:[NSValue valueWithCGSize:CGSizeMake(rw, rh)]];
        if (horizontal) { along += rw; across = MAX(across, rh); } else { along += rh; across = MAX(across, rw); }
    }
    CGSize content = horizontal ? CGSizeMake(along, MAX(across, bounds.height)) : CGSizeMake(MAX(across, bounds.width), along);
    if (!self._continuous) content = CGSizeMake(MAX(content.width, bounds.width), MAX(content.height, bounds.height));
    _docView.frame = CGRectMake(0, 0, content.width, content.height);
    _scroll.contentSize = content;
    _scroll.pagingEnabled = _usingPageVC;
    /* the page views, made once and placed */
    NSMutableDictionary<NSValue *, _PDFPageView *> *old = [NSMutableDictionary dictionary];
    for (_PDFPageView *v in _pageViews) old[[NSValue valueWithNonretainedObject:v.page]] = v;
    NSMutableArray *views = [NSMutableArray array];
    CGFloat pos = 0;
    for (NSUInteger r = 0; r < rows.count; r++) {
        CGSize rs = [sizes[r] CGSizeValue];
        CGRect rowFrame = horizontal ? CGRectMake(pos, (content.height - rs.height) / 2, rs.width, rs.height)
                                     : CGRectMake((content.width - rs.width) / 2, pos, rs.width, rs.height);
        if (!self._continuous && !horizontal) rowFrame.origin.y = MAX(0, (content.height - rs.height) / 2);
        pos += horizontal ? rs.width : rs.height;
        CGFloat used = 0;
        for (PDFPage *p in rows[r]) { CGSize d = [self _pageSize:p]; used += (d.width + m.left + m.right) * s; }
        CGFloat x = rowFrame.origin.x + (rowFrame.size.width - used) / 2;
        for (PDFPage *p in rows[r]) {
            CGSize d = [self _pageSize:p];
            CGRect f = CGRectMake(x + m.left * s, rowFrame.origin.y + (rowFrame.size.height - d.height * s) / 2, d.width * s, d.height * s);
            x += (d.width + m.left + m.right) * s;
            NSValue *key = [NSValue valueWithNonretainedObject:p];
            _PDFPageView *v = old[key];
            if (v) [old removeObjectForKey:key];
            else {
                v = [[_PDFPageView alloc] initWithFrame:f];
                v.page = p; v.pdfView = self;
                v.accessibilityIdentifier = [NSString stringWithFormat:@"pdfpage-%lu", (unsigned long)[_document indexForPage:p]];
                [_docView addSubview:v];
                UIView *overlay = [_pageOverlayViewProvider pdfView:self overlayViewForPage:p];
                if (overlay) {
                    if ([_pageOverlayViewProvider respondsToSelector:@selector(pdfView:willDisplayOverlayView:forPage:)])
                        [_pageOverlayViewProvider pdfView:self willDisplayOverlayView:overlay forPage:p];
                    overlay.frame = v.bounds;
                    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                    [v addSubview:overlay];
                    v.overlay = overlay;
                }
            }
            if (!CGRectEqualToRect(v.frame, f)) { v.frame = f; [v setNeedsDisplay]; }
            BOOL shadow = _pageShadowsEnabled && _displaysPageBreaks;
            v.layer.shadowOpacity = shadow ? 0.25 : 0;
            v.layer.shadowRadius = shadow ? 3 : 0;
            v.layer.shadowOffset = CGSizeMake(0, shadow ? 1 : 0);
            [views addObject:v];
        }
    }
    for (_PDFPageView *v in old.allValues) {
        if (v.overlay && [_pageOverlayViewProvider respondsToSelector:@selector(pdfView:willEndDisplayingOverlayView:forPage:)])
            [_pageOverlayViewProvider pdfView:self willEndDisplayingOverlayView:v.overlay forPage:v.page];
        [v removeFromSuperview];
    }
    _pageViews = views;
    _layingOut = NO;
    [self _updateVisible];
}
- (_PDFPageView *)_viewOf:(PDFPage *)page {
    for (_PDFPageView *v in _pageViews) if (v.page == page) return v;
    return nil;
}

/* ---- the current page and the visible pages ---- */
- (CGRect)_visibleRect { return (CGRect){ _scroll.contentOffset, _scroll.bounds.size }; }
- (void)_updateVisible {
    CGRect vis = self._visibleRect;
    NSMutableArray *visible = [NSMutableArray array];
    PDFPage *best = nil;
    CGFloat bestArea = 0;
    for (_PDFPageView *v in _pageViews) {
        CGRect i = CGRectIntersection(v.frame, vis);
        if (CGRectIsNull(i) || CGRectIsEmpty(i)) continue;
        [visible addObject:v.page];
        CGFloat a = i.size.width * i.size.height;
        if (a > bestArea + 0.5) { bestArea = a; best = v.page; }
    }
    [visible sortUsingComparator:^NSComparisonResult(PDFPage *a, PDFPage *b) {
        NSUInteger x = [self->_document indexForPage:a], y = [self->_document indexForPage:b];
        return x < y ? NSOrderedAscending : x > y ? NSOrderedDescending : NSOrderedSame;
    }];
    if (![visible isEqualToArray:_visible ?: @[]]) {
        _visible = visible;
        [self _post:PDFViewVisiblePagesChangedNotification];
    }
    if (self._continuous && best && best != _current) {
        _current = best;
        [self _post:PDFViewPageChangedNotification];
    }
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView { if (!_layingOut) [self _updateVisible]; }
- (NSArray<PDFPage *> *)visiblePages { return _visible ?: @[]; }
- (PDFPage *)currentPage { return _current; }
- (PDFDestination *)currentDestination {
    if (!_current) return nil;
    _PDFPageView *v = [self _viewOf:_current];
    CGPoint top = CGPointMake(_scroll.contentOffset.x, _scroll.contentOffset.y);
    CGPoint p = v ? [self _toPage:_current point:[_docView convertPoint:top toView:v] view:v] : CGPointZero;
    CGRect box = [_current boundsForBox:_displayBox];
    p.x = MAX(CGRectGetMinX(box), MIN(p.x, CGRectGetMaxX(box)));
    p.y = MAX(CGRectGetMinY(box), MIN(p.y, CGRectGetMaxY(box)));
    PDFDestination *d = [[PDFDestination alloc] initWithPage:_current atPoint:p];
    d.zoom = _scaleFactor;
    return d;
}

/* ---- navigation ---- */
- (void)_remember {
    PDFDestination *d = self.currentDestination;
    if (!d) return;
    [_back addObject:d];
    [_forward removeAllObjects];
    [self _post:PDFViewChangedHistoryNotification];
}
- (void)_show:(PDFPage *)page at:(CGPoint)pagePoint {
    if (!page || [_document indexForPage:page] == NSNotFound) return;
    BOOL changed = page != _current;
    _current = page;
    if (!self._continuous) [self _layout];
    _PDFPageView *v = [self _viewOf:page];
    if (!v) return;
    CGPoint off;
    if (_usingPageVC) off = CGPointMake(CGRectGetMidX(v.frame) - _scroll.bounds.size.width / 2, 0);
    else {
        CGPoint inView = pagePoint.x == kPDFDestinationUnspecifiedValue && pagePoint.y == kPDFDestinationUnspecifiedValue
                         ? CGPointZero : [self _fromPage:page point:pagePoint view:v];
        if (pagePoint.x == kPDFDestinationUnspecifiedValue) inView.x = 0;
        if (pagePoint.y == kPDFDestinationUnspecifiedValue) inView.y = 0;
        CGPoint inDoc = [v convertPoint:inView toView:_docView];
        UIEdgeInsets m = self._margins;
        off = self._horizontal ? CGPointMake(inDoc.x - m.left * _scaleFactor, _scroll.contentOffset.y)
                               : CGPointMake(_scroll.contentOffset.x, inDoc.y - m.top * _scaleFactor);
    }
    CGSize cs = _scroll.contentSize, bs = _scroll.bounds.size;
    off.x = MAX(0, MIN(off.x, cs.width - bs.width));
    off.y = MAX(0, MIN(off.y, cs.height - bs.height));
    _layingOut = YES;
    [_scroll setContentOffset:off animated:NO];
    _layingOut = NO;
    _current = page;
    [self _updateVisible];
    _current = page;                                                   /* the page gone to stays current */
    if (changed) [self _post:PDFViewPageChangedNotification];
}
- (void)goToPage:(PDFPage *)page {
    if (!page) return;
    [self _remember];
    [self _show:page at:CGPointMake(kPDFDestinationUnspecifiedValue, kPDFDestinationUnspecifiedValue)];
}
- (void)goToDestination:(PDFDestination *)d {
    if (!d.page) return;
    [self _remember];
    if (d.zoom != kPDFDestinationUnspecifiedValue && d.zoom > 0) self.scaleFactor = d.zoom;
    [self _show:d.page at:d.point];
}
- (void)goToRect:(CGRect)rect onPage:(PDFPage *)page {
    [self _remember];
    [self _show:page at:CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect))];
}
- (NSUInteger)_index { return _current ? [_document indexForPage:_current] : NSNotFound; }
- (NSUInteger)_step { return self._twoUp ? 2 : 1; }
- (BOOL)canGoToFirstPage { return _document.pageCount && self._index != 0; }
- (BOOL)canGoToLastPage { return _document.pageCount && self._index != _document.pageCount - 1; }
- (BOOL)canGoToNextPage { return _document.pageCount && self._index != NSNotFound && self._index + 1 < _document.pageCount; }
- (BOOL)canGoToPreviousPage { return _document.pageCount && self._index != NSNotFound && self._index > 0; }
- (void)goToFirstPage:(id)sender { if (self.canGoToFirstPage) [self goToPage:[_document pageAtIndex:0]]; }
- (void)goToLastPage:(id)sender { if (self.canGoToLastPage) [self goToPage:[_document pageAtIndex:_document.pageCount - 1]]; }
- (void)goToNextPage:(id)sender {
    if (!self.canGoToNextPage) return;
    NSArray *row = [self _rowOf:_current];
    NSUInteger last = 0;
    for (PDFPage *p in row) last = MAX(last, [_document indexForPage:p]);
    [self goToPage:[_document pageAtIndex:MIN(last + 1, _document.pageCount - 1)]];
}
- (void)goToPreviousPage:(id)sender {
    if (!self.canGoToPreviousPage) return;
    NSArray *row = [self _rowOf:_current];
    NSUInteger first = NSNotFound;
    for (PDFPage *p in row) first = MIN(first, [_document indexForPage:p]);
    NSUInteger prev = first == 0 || first == NSNotFound ? 0 : first - 1;
    NSArray *prevRow = [self _rowOf:[_document pageAtIndex:prev]];
    for (PDFPage *p in prevRow) prev = MIN(prev, [_document indexForPage:p]);
    [self goToPage:[_document pageAtIndex:prev]];
}
- (BOOL)canGoBack { return _back.count > 0; }
- (BOOL)canGoForward { return _forward.count > 0; }
- (void)goBack:(id)sender {
    if (!_back.count) return;
    PDFDestination *here = self.currentDestination, *d = _back.lastObject;
    [_back removeLastObject];
    if (here) [_forward addObject:here];
    [self _show:d.page at:d.point];
    [self _post:PDFViewChangedHistoryNotification];
}
- (void)goForward:(id)sender {
    if (!_forward.count) return;
    PDFDestination *here = self.currentDestination, *d = _forward.lastObject;
    [_forward removeLastObject];
    if (here) [_back addObject:here];
    [self _show:d.page at:d.point];
    [self _post:PDFViewChangedHistoryNotification];
}

/* ---- scale ---- */
- (CGFloat)_clampScale:(CGFloat)s { return MAX(_minScaleFactor, MIN(s, _maxScaleFactor)); }
- (CGFloat)scaleFactor { return _scaleFactor; }
- (void)setScaleFactor:(CGFloat)scale {
    _autoScales = NO;
    [self _setScale:scale anchor:CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds))];
}
/* rescales keeping the document point under `anchor` (in the view) where it is */
- (void)_setScale:(CGFloat)scale anchor:(CGPoint)anchor {
    if ([_delegate respondsToSelector:@selector(PDFViewWillChangeScaleFactor:toScale:)])
        scale = [_delegate PDFViewWillChangeScaleFactor:self toScale:scale];
    scale = [self _clampScale:scale];
    if (fabs(scale - _scaleFactor) < 1e-6) return;
    CGPoint inDoc = [self convertPoint:anchor toView:_docView];
    CGFloat ratio = scale / _scaleFactor;
    _scaleFactor = scale;
    [self _layout];
    CGPoint off = CGPointMake(inDoc.x * ratio - anchor.x, inDoc.y * ratio - anchor.y);
    CGSize cs = _scroll.contentSize, bs = _scroll.bounds.size;
    off.x = MAX(0, MIN(off.x, cs.width - bs.width));
    off.y = MAX(0, MIN(off.y, cs.height - bs.height));
    [_scroll setContentOffset:off animated:NO];
    [self _post:PDFViewScaleChangedNotification];
}
- (void)setMinScaleFactor:(CGFloat)v { _minScaleFactor = v; if (_scaleFactor < v) self.scaleFactor = v; }
- (void)setMaxScaleFactor:(CGFloat)v { _maxScaleFactor = v; if (_scaleFactor > v) self.scaleFactor = v; }
- (void)setAutoScales:(BOOL)a {
    _autoScales = a;
    if (a) {
        CGFloat before = _scaleFactor;
        [self _layout];
        if (fabs(before - _scaleFactor) > 1e-6) [self _post:PDFViewScaleChangedNotification];
    }
}
- (BOOL)canZoomIn { return _scaleFactor < _maxScaleFactor - 1e-6; }
- (BOOL)canZoomOut { return _scaleFactor > _minScaleFactor + 1e-6; }
- (void)zoomIn:(id)sender { if (self.canZoomIn) self.scaleFactor = _scaleFactor * M_SQRT2; }
- (void)zoomOut:(id)sender { if (self.canZoomOut) self.scaleFactor = _scaleFactor / M_SQRT2; }
- (void)_pinch:(UIPinchGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) _pinchStart = _scaleFactor;
    if (g.state == UIGestureRecognizerStateBegan || g.state == UIGestureRecognizerStateChanged) {
        _autoScales = NO;
        [self _setScale:_pinchStart * g.scale anchor:[g locationInView:self]];
    }
}
- (void)_doubleTap:(UITapGestureRecognizer *)g {
    CGFloat fit = [self _clampScale:self.scaleFactorForSizeToFit];
    CGPoint at = [g locationInView:self];
    if (_scaleFactor < fit * 1.5) { _autoScales = NO; [self _setScale:fit * 2 anchor:at]; }
    else { [self _setScale:fit anchor:at]; _autoScales = YES; }
}

/* ---- points and pages ---- */
/* a point in a page view (y-down, at the scale) to page space, and back */
- (CGPoint)_toPage:(PDFPage *)page point:(CGPoint)p view:(UIView *)v {
    CGSize d = [self _pageSize:page];
    CGPoint disp = CGPointMake(p.x * d.width / MAX(v.bounds.size.width, 1), d.height - p.y * d.height / MAX(v.bounds.size.height, 1));
    return CGPointApplyAffineTransform(disp, CGAffineTransformInvert([page transformForBox:_displayBox]));
}
- (CGPoint)_fromPage:(PDFPage *)page point:(CGPoint)p view:(UIView *)v {
    CGSize d = [self _pageSize:page];
    CGPoint disp = CGPointApplyAffineTransform(p, [page transformForBox:_displayBox]);
    return CGPointMake(disp.x * v.bounds.size.width / d.width, (d.height - disp.y) * v.bounds.size.height / d.height);
}
- (CGPoint)convertPoint:(CGPoint)point toPage:(PDFPage *)page {
    _PDFPageView *v = [self _viewOf:page];
    return v ? [self _toPage:page point:[self convertPoint:point toView:v] view:v] : CGPointZero;
}
- (CGPoint)convertPoint:(CGPoint)point fromPage:(PDFPage *)page {
    _PDFPageView *v = [self _viewOf:page];
    return v ? [v convertPoint:[self _fromPage:page point:point view:v] toView:self] : CGPointZero;
}
- (CGRect)convertRect:(CGRect)rect toPage:(PDFPage *)page {
    CGPoint a = [self convertPoint:rect.origin toPage:page], b = [self convertPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)) toPage:page];
    return CGRectStandardize(CGRectMake(a.x, a.y, b.x - a.x, b.y - a.y));
}
- (CGRect)convertRect:(CGRect)rect fromPage:(PDFPage *)page {
    CGPoint a = [self convertPoint:rect.origin fromPage:page], b = [self convertPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)) fromPage:page];
    return CGRectStandardize(CGRectMake(a.x, a.y, b.x - a.x, b.y - a.y));
}
- (PDFPage *)pageForPoint:(CGPoint)point nearest:(BOOL)nearest {
    PDFPage *best = nil;
    CGFloat bestD = CGFLOAT_MAX;
    for (_PDFPageView *v in _pageViews) {
        CGRect f = [v convertRect:v.bounds toView:self];
        if (CGRectContainsPoint(f, point)) return v.page;
        CGFloat dx = MAX(0, MAX(CGRectGetMinX(f) - point.x, point.x - CGRectGetMaxX(f)));
        CGFloat dy = MAX(0, MAX(CGRectGetMinY(f) - point.y, point.y - CGRectGetMaxY(f)));
        if (dx * dx + dy * dy < bestD) { bestD = dx * dx + dy * dy; best = v.page; }
    }
    return nearest ? best : nil;
}

/* ---- links ---- */
/* the link annotation under a page point: its URL (a URI action) or its destination */
- (BOOL)_link:(PDFPage *)page at:(CGPoint)pt url:(NSURL **)url destination:(PDFDestination **)dest {
    CGPDFArrayRef annots;
    CGPDFDictionaryRef d = CGPDFPageGetDictionary(page.pageRef);
    if (!d || !CGPDFDictionaryGetArray(d, "Annots", &annots)) return NO;
    for (size_t i = 0; i < CGPDFArrayGetCount(annots); i++) {
        CGPDFDictionaryRef a, action; CGPDFArrayRef r; const char *sub, *type;
        CGPDFReal x0, y0, x1, y1;
        if (!CGPDFArrayGetDictionary(annots, i, &a) || !CGPDFDictionaryGetName(a, "Subtype", &sub) || strcmp(sub, "Link") ||
            !CGPDFDictionaryGetArray(a, "Rect", &r) || !CGPDFArrayGetNumber(r, 0, &x0) || !CGPDFArrayGetNumber(r, 1, &y0) ||
            !CGPDFArrayGetNumber(r, 2, &x1) || !CGPDFArrayGetNumber(r, 3, &y1)) continue;
        if (!CGRectContainsPoint(CGRectStandardize(CGRectMake(x0, y0, x1 - x0, y1 - y0)), pt)) continue;
        CGPDFObjectRef o;
        CGPDFStringRef s;
        if (CGPDFDictionaryGetDictionary(a, "A", &action) && CGPDFDictionaryGetName(action, "S", &type)) {
            if (!strcmp(type, "URI") && CGPDFDictionaryGetString(action, "URI", &s)) {
                NSString *u = [[NSString alloc] initWithBytes:CGPDFStringGetBytePtr(s) length:CGPDFStringGetLength(s) encoding:NSUTF8StringEncoding];
                *url = u ? [NSURL URLWithString:u] : nil;
                return *url != nil;
            }
            if (!strcmp(type, "GoTo") && CGPDFDictionaryGetObject(action, "D", &o)) { *dest = [_document _isim_destinationForObject:o]; return *dest != nil; }
        }
        if (CGPDFDictionaryGetObject(a, "Dest", &o)) { *dest = [_document _isim_destinationForObject:o]; return *dest != nil; }
    }
    return NO;
}
- (void)_tap:(UITapGestureRecognizer *)g {
    CGPoint at = [g locationInView:self];
    PDFPage *page = [self pageForPoint:at nearest:NO];
    NSURL *url = nil; PDFDestination *dest = nil;
    if (!page || ![self _link:page at:[self convertPoint:at toPage:page] url:&url destination:&dest]) return;
    if (dest) { [self goToDestination:dest]; return; }
    if ([_delegate respondsToSelector:@selector(PDFViewWillClickOnLink:withURL:)]) [_delegate PDFViewWillClickOnLink:self withURL:url];
    else [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}
- (PDFAreaOfInterest)areaOfInterestForPoint:(CGPoint)point {
    PDFPage *page = [self pageForPoint:point nearest:NO];
    if (!page) return kPDFNoArea;
    CGPoint pt = [self convertPoint:point toPage:page];
    PDFAreaOfInterest a = kPDFPageArea;
    if ([page characterIndexAtPoint:pt] >= 0) a |= kPDFTextArea;
    NSURL *url = nil; PDFDestination *dest = nil;
    if ([self _link:page at:pt url:&url destination:&dest]) a |= kPDFLinkArea | kPDFAnnotationArea;
    return a;
}
- (PDFAreaOfInterest)areaOfInterestForMouse:(UIEvent *)event {
    UITouch *t = event.allTouches.anyObject;
    return t ? [self areaOfInterestForPoint:[t locationInView:self]] : kPDFNoArea;
}
- (void)setCursorForAreaOfInterest:(PDFAreaOfInterest)area {}

/* ---- paging like a UIPageViewController: one page per screen, swiped sideways ---- */
- (void)usePageViewController:(BOOL)enable withViewOptions:(NSDictionary *)viewOptions {
    if (enable == _usingPageVC) return;
    _usingPageVC = enable;
    _autoScales = enable ? YES : _autoScales;
    [self _rebuild];
    if (_current) [self _show:_current at:CGPointMake(kPDFDestinationUnspecifiedValue, kPDFDestinationUnspecifiedValue)];
}
- (BOOL)isUsingPageViewController { return _usingPageVC; }
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView { [self _updateVisible]; }
@end

/* ---------------- PDFThumbnailView ---------------- */
@implementation PDFThumbnailView {
    UIScrollView *_scroll;
    NSMutableArray<UIImageView *> *_cells;
    PDFDocument *_shown;
    UIColor *_background;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    [self _setUp];
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if (!(self = [super initWithCoder:coder])) return nil;
    [self _setUp];
    return self;
}
- (void)_setUp {
    _thumbnailSize = CGSizeMake(36, 48);
    _layoutMode = PDFThumbnailLayoutModeVertical;
    _maximumNumberOfColumns = 1;
    _cells = [NSMutableArray array];
    _background = [UIColor secondarySystemBackgroundColor];
    [super setBackgroundColor:_background];
    _scroll = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.accessibilityIdentifier = @"pdfthumbnails-scroll";
    [self addSubview:_scroll];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(_changed:) name:PDFViewPageChangedNotification object:nil];
    [nc addObserver:self selector:@selector(_changed:) name:PDFViewDocumentChangedNotification object:nil];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)_changed:(NSNotification *)n { if (n.object == _PDFView) [self setNeedsLayout]; }
- (void)setPDFView:(PDFView *)v { _PDFView = v; [self setNeedsLayout]; }
- (void)setBackgroundColor:(UIColor *)c { _background = c; [super setBackgroundColor:c]; }
- (UIColor *)backgroundColor { return _background; }
- (void)setThumbnailSize:(CGSize)s { _thumbnailSize = s; _shown = nil; [self setNeedsLayout]; }
- (void)setLayoutMode:(PDFThumbnailLayoutMode)m { _layoutMode = m; [self setNeedsLayout]; }
- (void)setContentInset:(UIEdgeInsets)i { _contentInset = i; [self setNeedsLayout]; }
- (NSArray<PDFPage *> *)selectedPages { PDFPage *p = _PDFView.currentPage; return p ? @[ p ] : nil; }
- (void)layoutSubviews {
    [super layoutSubviews];
    PDFDocument *doc = _PDFView.document;
    if (doc != _shown || _cells.count != doc.pageCount) {             /* the thumbnails, made again */
        for (UIView *c in _cells) [c removeFromSuperview];
        [_cells removeAllObjects];
        for (NSUInteger i = 0; i < doc.pageCount; i++) {
            PDFPage *p = [doc pageAtIndex:i];
            UIImageView *iv = [[UIImageView alloc] initWithImage:[p thumbnailOfSize:_thumbnailSize forBox:_PDFView.displayBox]];
            iv.userInteractionEnabled = YES;
            iv.tag = (NSInteger)i;
            iv.accessibilityIdentifier = [NSString stringWithFormat:@"pdfthumbnail-%lu", (unsigned long)i];
            [iv addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tap:)]];
            [_scroll addSubview:iv];
            [_cells addObject:iv];
        }
        _shown = doc;
    }
    BOOL horizontal = _layoutMode == PDFThumbnailLayoutModeHorizontal;
    UIEdgeInsets in = _contentInset;
    CGFloat gap = 8, pos = horizontal ? in.left + gap : in.top + gap;
    CGSize b = self.bounds.size;
    PDFPage *current = _PDFView.currentPage;
    for (UIImageView *iv in _cells) {
        CGSize s = iv.image.size;
        CGRect f = horizontal ? CGRectMake(pos, in.top + (b.height - in.top - in.bottom - s.height) / 2, s.width, s.height)
                              : CGRectMake(in.left + (b.width - in.left - in.right - s.width) / 2, pos, s.width, s.height);
        iv.frame = f;
        pos += (horizontal ? s.width : s.height) + gap;
        BOOL selected = [doc pageAtIndex:(NSUInteger)iv.tag] == current;
        iv.layer.borderWidth = selected ? 2 : 0.5;
        iv.layer.borderColor = (selected ? self.tintColor : [UIColor colorWithWhite:0 alpha:0.2]).CGColor;
    }
    _scroll.contentSize = horizontal ? CGSizeMake(MAX(pos + in.right, b.width), b.height) : CGSizeMake(b.width, MAX(pos + in.bottom, b.height));
}
- (void)_tap:(UITapGestureRecognizer *)g {
    PDFPage *p = [_PDFView.document pageAtIndex:(NSUInteger)g.view.tag];
    if (p) [_PDFView goToPage:p];
    [self setNeedsLayout];
}
@end
