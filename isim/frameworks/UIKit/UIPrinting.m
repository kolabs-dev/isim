/* Printing: UIPrintInteractionController, its formatters and page renderer, UIPrinter and UIPrinterPickerController.
 *
 * Adapted, like the iOS Simulator's Printer Simulator: one simulated printer, "isim Printer"
 * (ipp://isim.local/printers/isim), always available. A job is rendered into a PDF (cairo) and written to
 * $ISIM_DATA/Printer/<job name>[ n].pdf, its pages repeated for the copies (collated); the log names the file. The
 * paper is US Letter in the US, Canada and Mexico, else A4, with 1/4" margins. The options sheet has the printer,
 * copies, orientation (when asked for) and a preview of the first page; no page range, paper or duplex choice (the
 * job keeps printInfo's). Grayscale output types are recorded but the PDF keeps its colours. */
#import "UIKitPrivate.h"
#import <UIKit/UIPrinting.h>
#include <objc/runtime.h>

NSErrorDomain const UIPrintErrorDomain = @"UIPrintErrorDomain";
extern NSString *isim_data_dir(void);

/* ---------------- print info, paper ---------------- */
@implementation UIPrintInfo
+ (UIPrintInfo *)printInfo { UIPrintInfo *i = [self new]; i.jobName = NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: @"Document"; return i; }
+ (UIPrintInfo *)printInfoWithDictionary:(NSDictionary *)d {
    UIPrintInfo *i = [self printInfo];
    if (d[@"UIPrintInfoJobNameKey"]) i.jobName = d[@"UIPrintInfoJobNameKey"];
    i.printerID = d[@"UIPrintInfoPrinterIDKey"];
    i.outputType = [d[@"UIPrintInfoOutputTypeKey"] integerValue];
    i.orientation = [d[@"UIPrintInfoOrientationKey"] integerValue];
    i.duplex = [d[@"UIPrintInfoDuplexKey"] integerValue];
    return i;
}
- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *d = [@{ @"UIPrintInfoJobNameKey": _jobName ?: @"", @"UIPrintInfoOutputTypeKey": @(_outputType),
                                 @"UIPrintInfoOrientationKey": @(_orientation), @"UIPrintInfoDuplexKey": @(_duplex) } mutableCopy];
    if (_printerID) d[@"UIPrintInfoPrinterIDKey"] = _printerID;
    return d;
}
- (id)copyWithZone:(NSZone *)z { return [UIPrintInfo printInfoWithDictionary:self.dictionaryRepresentation]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:self.dictionaryRepresentation forKey:@"UIPrintInfoDictionary"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    NSDictionary *d = [c decodeObjectOfClasses:[NSSet setWithObjects:NSDictionary.class, NSString.class, NSNumber.class, nil] forKey:@"UIPrintInfoDictionary"];
    return [UIPrintInfo printInfoWithDictionary:d];
}
@end

@implementation UIPrintPaper { CGSize _size; CGRect _printable; }
- (instancetype)_isimSize:(CGSize)s { _size = s; _printable = CGRectInset(CGRectMake(0, 0, s.width, s.height), 18, 18); return self; }
+ (UIPrintPaper *)_isimDefault {
    NSString *cc = [NSLocale.currentLocale objectForKey:NSLocaleCountryCode] ?: @"US";
    BOOL letter = [@[@"US", @"CA", @"MX"] containsObject:cc];
    return [[self new] _isimSize:letter ? CGSizeMake(612, 792) : CGSizeMake(595.2, 841.8)];
}
- (CGSize)paperSize { return _size; }
- (CGRect)printableRect { return _printable; }
+ (UIPrintPaper *)bestPaperForPageSize:(CGSize)s withPapersFromArray:(NSArray<UIPrintPaper *> *)list {
    UIPrintPaper *best = nil; CGFloat waste = CGFLOAT_MAX;
    for (UIPrintPaper *p in list) {
        CGSize ps = p.printableRect.size;
        if (ps.width + 0.5 < s.width || ps.height + 0.5 < s.height) continue;
        CGFloat w = ps.width * ps.height - s.width * s.height;
        if (w < waste) { waste = w; best = p; }
    }
    return best ?: list.firstObject ?: [UIPrintPaper _isimDefault];
}
@end

/* ---------------- formatters ---------------- */
@interface UIPrintFormatter ()
@property (nullable, nonatomic, weak) UIPrintPageRenderer *printPageRenderer;
- (NSInteger)_isimPagesForSize:(CGSize)size;      /* pages needed in a content area of that size */
@end
@interface UIPrintPageRenderer ()
- (void)_isimSetPaper:(CGRect)paper printable:(CGRect)printable;
- (CGRect)_isimContentRect;
@end

@implementation UIPrintFormatter
- (id)copyWithZone:(NSZone *)z {
    UIPrintFormatter *f = [[self class] new];
    f.maximumContentHeight = _maximumContentHeight; f.maximumContentWidth = _maximumContentWidth; f.perPageContentInsets = _perPageContentInsets;
    return f;
}
- (void)removeFromPrintPageRenderer {
    UIPrintPageRenderer *r = self.printPageRenderer;
    NSMutableArray *a = [r.printFormatters mutableCopy];
    [a removeObjectIdenticalTo:self];
    r.printFormatters = a;
    self.printPageRenderer = nil;
}
- (UIEdgeInsets)contentInsets { return _perPageContentInsets; }
- (void)setContentInsets:(UIEdgeInsets)i { _perPageContentInsets = i; }
/* the formatter's area on a page: the renderer's content area, inset, limited to the maximum width / height */
- (CGRect)rectForPageAtIndex:(NSInteger)page {
    CGRect r = self.printPageRenderer ? [self.printPageRenderer _isimContentRect] : CGRectMake(18, 18, 576, 756);
    r = UIEdgeInsetsInsetRect(r, _perPageContentInsets);
    if (_maximumContentWidth > 0 && r.size.width > _maximumContentWidth) r.size.width = _maximumContentWidth;
    if (_maximumContentHeight > 0 && r.size.height > _maximumContentHeight) r.size.height = _maximumContentHeight;
    return r;
}
- (NSInteger)pageCount { return [self _isimPagesForSize:[self rectForPageAtIndex:_startPage].size]; }
- (NSInteger)_isimPagesForSize:(CGSize)size { return 1; }
- (void)drawInRect:(CGRect)rect forPageAtIndex:(NSInteger)page {}
@end

/* lines of text broken to a width (greedy word wrap, long words split) */
static NSArray<NSString *> *wrap_lines(NSString *text, NSDictionary *attrs, CGFloat width) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *para in [text componentsSeparatedByString:@"\n"]) {
        if (!para.length) { [out addObject:@""]; continue; }
        NSMutableString *line = [NSMutableString string];
        for (NSString *w in [para componentsSeparatedByString:@" "]) {
            NSString *word = w;
            NSString *cand = line.length ? [line stringByAppendingFormat:@" %@", word] : word;
            if ([cand sizeWithAttributes:attrs].width <= width) { [line setString:cand]; continue; }
            if (line.length) { [out addObject:[line copy]]; [line setString:@""]; }
            while ([word sizeWithAttributes:attrs].width > width && word.length > 1) {   /* a word wider than the line */
                NSUInteger n = word.length;
                while (n > 1 && [[word substringToIndex:n] sizeWithAttributes:attrs].width > width) n--;
                [out addObject:[word substringToIndex:n]];
                word = [word substringFromIndex:n];
            }
            [line setString:word];
        }
        [out addObject:[line copy]];
    }
    return out;
}

@implementation UISimpleTextPrintFormatter { NSArray<NSString *> *_lines; CGFloat _lineWidth; }
- (instancetype)initWithText:(NSString *)t { if ((self = [super init])) _text = [t copy]; return self; }
- (instancetype)initWithAttributedText:(NSAttributedString *)a { if ((self = [super init])) { _attributedText = [a copy]; _text = a.string; } return self; }
- (UIFont *)_font {
    if (_font) return _font;
    if (_attributedText.length) { UIFont *f = [_attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL]; if (f) return f; }
    return [UIFont systemFontOfSize:12];
}
- (NSDictionary *)_attrs {
    UIColor *c = _color;
    if (!c && _attributedText.length) c = [_attributedText attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL];
    return @{ NSFontAttributeName: [self _font], NSForegroundColorAttributeName: c ?: UIColor.blackColor };
}
- (NSArray<NSString *> *)_linesFor:(CGFloat)width {
    if (!_lines || _lineWidth != width) { _lines = wrap_lines(_text ?: @"", [self _attrs], width); _lineWidth = width; }
    return _lines;
}
- (void)setText:(NSString *)t { _text = [t copy]; _attributedText = nil; _lines = nil; }
- (void)setAttributedText:(NSAttributedString *)a { _attributedText = [a copy]; _text = a.string; _lines = nil; }
- (void)setFont:(UIFont *)f { _font = f; _lines = nil; }
- (NSInteger)_linesPerPage:(CGFloat)height { return MAX(1, (NSInteger)floor(height / ceil([self _font].lineHeight))); }
- (NSInteger)_isimPagesForSize:(CGSize)size {
    NSInteger n = (NSInteger)[self _linesFor:size.width].count;
    return MAX(1, (n + [self _linesPerPage:size.height] - 1) / [self _linesPerPage:size.height]);
}
- (void)drawInRect:(CGRect)rect forPageAtIndex:(NSInteger)page {
    NSArray *lines = [self _linesFor:rect.size.width];
    NSInteger per = [self _linesPerPage:rect.size.height], first = (page - self.startPage) * per;
    CGFloat lh = ceil([self _font].lineHeight), y = rect.origin.y;
    NSDictionary *attrs = [self _attrs];
    for (NSInteger i = first; i < first + per && i < (NSInteger)lines.count; i++, y += lh) {
        if (i < 0) continue;
        NSString *l = lines[i];
        CGFloat w = [l sizeWithAttributes:attrs].width;
        CGFloat x = _textAlignment == NSTextAlignmentCenter ? rect.origin.x + (rect.size.width - w) / 2 : _textAlignment == NSTextAlignmentRight ? CGRectGetMaxX(rect) - w : rect.origin.x;
        [l drawAtPoint:CGPointMake(x, y) withAttributes:attrs];
    }
}
- (id)copyWithZone:(NSZone *)z {
    UISimpleTextPrintFormatter *f = [super copyWithZone:z];
    if (_attributedText) f.attributedText = _attributedText; else f.text = _text;
    f.font = _font; f.color = _color; f.textAlignment = _textAlignment;
    return f;
}
@end

/* HTML to text: block ends become line breaks, list items bullets, tags dropped, entities decoded */
static NSString *markup_text(NSString *html) {
    NSMutableString *s = [html mutableCopy] ?: [NSMutableString string];
    NSArray *rules = @[@[@"(?i)<br\\s*/?>", @"\n"], @[@"(?i)</(p|div|h[1-6]|li|tr|ul|ol|table|blockquote)>", @"\n"], @[@"(?i)<li[^>]*>", @"• "],
                       @[@"(?is)<(script|style)[^>]*>.*?</\\1>", @""], @[@"<[^>]+>", @""], @[@"[ \\t]+", @" "], @[@"\n[ ]+", @"\n"], @[@"\n{3,}", @"\n\n"]];
    for (NSArray *r in rules) {
        NSRegularExpression *rx = [NSRegularExpression regularExpressionWithPattern:r[0] options:0 error:NULL];
        [rx replaceMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:r[1]];
    }
    for (NSArray *e in @[@[@"&nbsp;", @" "], @[@"&lt;", @"<"], @[@"&gt;", @">"], @[@"&quot;", @"\""], @[@"&#39;", @"'"], @[@"&apos;", @"'"], @[@"&amp;", @"&"]])
        [s setString:[s stringByReplacingOccurrencesOfString:e[0] withString:e[1]]];
    return [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}
@implementation UIMarkupTextPrintFormatter { UISimpleTextPrintFormatter *_text; }
- (instancetype)initWithMarkupText:(NSString *)m { if ((self = [super init])) self.markupText = m; return self; }
- (void)setMarkupText:(NSString *)m { _markupText = [m copy]; _text = [[UISimpleTextPrintFormatter alloc] initWithText:markup_text(m ?: @"")]; }
- (NSInteger)_isimPagesForSize:(CGSize)size { return [_text _isimPagesForSize:size]; }
- (void)drawInRect:(CGRect)rect forPageAtIndex:(NSInteger)page { _text.startPage = self.startPage; [_text drawInRect:rect forPageAtIndex:page]; }
- (id)copyWithZone:(NSZone *)z { UIMarkupTextPrintFormatter *f = [super copyWithZone:z]; f.markupText = _markupText; return f; }
@end

@interface UIViewPrintFormatter ()
- (instancetype)initIsimWithView:(UIView *)v;
@end
@implementation UIViewPrintFormatter { UIView *_view; UIImage *_image; }
- (instancetype)initIsimWithView:(UIView *)v { if ((self = [super init])) _view = v; return self; }
- (UIView *)view { return _view; }
/* the view drawn once at its size (drawRect:forViewPrintFormatter:, else its hierarchy as on screen) */
- (UIImage *)_image {
    if (_image) return _image;
    CGSize s = _view.bounds.size;
    if (s.width <= 0 || s.height <= 0) return nil;
    UIGraphicsImageRendererFormat *f = [UIGraphicsImageRendererFormat defaultFormat]; f.scale = 2;
    _image = [[[UIGraphicsImageRenderer alloc] initWithSize:s format:f] imageWithActions:^(UIGraphicsImageRendererContext *c) {
        if ([self->_view methodForSelector:@selector(drawRect:forViewPrintFormatter:)] != [UIView instanceMethodForSelector:@selector(drawRect:forViewPrintFormatter:)])
            [self->_view drawRect:self->_view.bounds forViewPrintFormatter:self];
        else [self->_view drawViewHierarchyInRect:self->_view.bounds afterScreenUpdates:YES];
    }];
    return _image;
}
- (NSInteger)_isimPagesForSize:(CGSize)size {
    UIImage *img = [self _image];
    if (!img || size.height <= 0) return 1;
    CGFloat h = img.size.height * size.width / img.size.width;
    return MAX(1, (NSInteger)ceil(h / size.height - 0.001));
}
- (void)drawInRect:(CGRect)rect forPageAtIndex:(NSInteger)page {
    UIImage *img = [self _image];
    if (!img) return;
    CGFloat k = rect.size.width / img.size.width, h = img.size.height * k;
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSaveGState(c);
    CGContextClipToRect(c, rect);
    [img drawInRect:CGRectMake(rect.origin.x, rect.origin.y - (page - self.startPage) * rect.size.height, rect.size.width, h)];
    CGContextRestoreGState(c);
}
@end

@implementation UIView (UIPrintFormatter)
- (UIViewPrintFormatter *)viewPrintFormatter { return [[UIViewPrintFormatter alloc] initIsimWithView:self]; }
- (void)drawRect:(CGRect)rect forViewPrintFormatter:(UIViewPrintFormatter *)formatter { [self drawRect:rect]; }
@end

/* ---------------- page renderer ---------------- */
@implementation UIPrintPageRenderer { CGRect _paper, _printable; }
@synthesize printFormatters = _printFormatters;
- (instancetype)init {
    if ((self = [super init])) { UIPrintPaper *p = [UIPrintPaper _isimDefault]; _paper = CGRectMake(0, 0, p.paperSize.width, p.paperSize.height); _printable = p.printableRect; }
    return self;
}
- (void)_isimSetPaper:(CGRect)paper printable:(CGRect)printable { _paper = paper; _printable = printable; }
- (CGRect)paperRect { return _paper; }
- (CGRect)printableRect { return _printable; }
- (CGRect)_isimContentRect {
    CGRect r = _printable;
    r.origin.y += _headerHeight; r.size.height -= _headerHeight + _footerHeight;
    return r;
}
- (void)addPrintFormatter:(UIPrintFormatter *)f startingAtPageAtIndex:(NSInteger)page {
    [f removeFromPrintPageRenderer];
    f.startPage = page; f.printPageRenderer = self;
    self.printFormatters = [(self.printFormatters ?: @[]) arrayByAddingObject:f];
}
- (void)setPrintFormatters:(NSArray<UIPrintFormatter *> *)a {
    @synchronized (self) { _printFormatters = [a copy]; }
    for (UIPrintFormatter *f in a) f.printPageRenderer = self;
}
- (NSArray<UIPrintFormatter *> *)printFormatters { @synchronized (self) { return _printFormatters; } }
- (NSInteger)numberOfPages {
    NSInteger n = 0;
    for (UIPrintFormatter *f in self.printFormatters) n = MAX(n, f.startPage + f.pageCount);
    return n;
}
- (NSArray<UIPrintFormatter *> *)printFormattersForPageAtIndex:(NSInteger)page {
    NSMutableArray *a = [NSMutableArray array];
    for (UIPrintFormatter *f in self.printFormatters) if (page >= f.startPage && page < f.startPage + f.pageCount) [a addObject:f];
    return a.count ? a : nil;
}
- (void)prepareForDrawingPages:(NSRange)range {}
- (void)drawPageAtIndex:(NSInteger)page inRect:(CGRect)printableRect {
    CGRect p = _printable;
    if (_headerHeight > 0) [self drawHeaderForPageAtIndex:page inRect:CGRectMake(p.origin.x, p.origin.y, p.size.width, _headerHeight)];
    [self drawContentForPageAtIndex:page inRect:[self _isimContentRect]];
    for (UIPrintFormatter *f in [self printFormattersForPageAtIndex:page]) [self drawPrintFormatter:f forPageAtIndex:page];
    if (_footerHeight > 0) [self drawFooterForPageAtIndex:page inRect:CGRectMake(p.origin.x, CGRectGetMaxY(p) - _footerHeight, p.size.width, _footerHeight)];
}
- (void)drawPrintFormatter:(UIPrintFormatter *)f forPageAtIndex:(NSInteger)page { [f drawInRect:[f rectForPageAtIndex:page] forPageAtIndex:page]; }
- (void)drawHeaderForPageAtIndex:(NSInteger)page inRect:(CGRect)r {}
- (void)drawContentForPageAtIndex:(NSInteger)page inRect:(CGRect)r {}
- (void)drawFooterForPageAtIndex:(NSInteger)page inRect:(CGRect)r {}
@end

/* ---------------- the printer ---------------- */
@implementation UIPrinter { NSURL *_url; }
+ (UIPrinter *)printerWithURL:(NSURL *)url { UIPrinter *p = [self new]; p->_url = [url copy]; return p; }
+ (UIPrinter *)_isimPrinter { return [self printerWithURL:[NSURL URLWithString:@"ipp://isim.local/printers/isim"]]; }
- (NSURL *)URL { return _url; }
- (BOOL)_isimIsSimulated { return [_url.absoluteString isEqualToString:@"ipp://isim.local/printers/isim"]; }
- (NSString *)displayName { return self._isimIsSimulated ? @"isim Printer" : (_url.host ?: _url.absoluteString); }
- (NSString *)displayLocation { return self._isimIsSimulated ? @"This device" : nil; }
- (UIPrinterJobTypes)supportedJobTypes { return self._isimIsSimulated ? UIPrinterJobTypeDocument | UIPrinterJobTypePhoto : UIPrinterJobTypeUnknown; }
- (NSString *)makeAndModel { return self._isimIsSimulated ? @"isim PDF Printer" : nil; }
- (BOOL)supportsColor { return self._isimIsSimulated; }
- (BOOL)supportsDuplex { return self._isimIsSimulated; }
/* only the simulated printer answers (isim does not reach network printers) */
- (void)contactPrinter:(void (^)(BOOL))done {
    BOOL ok = self._isimIsSimulated;
    dispatch_async(dispatch_get_main_queue(), ^{ if (done) done(ok); });
}
@end

/* ---------------- rendering a job ---------------- */
static BOOL is_pdf(NSData *d) { return d.length > 4 && !memcmp(d.bytes, "%PDF", 4); }
static NSData *item_data(id item) {
    if ([item isKindOfClass:NSData.class]) return item;
    if ([item isKindOfClass:NSURL.class] && [item isFileURL]) return [NSData dataWithContentsOfFile:[item path]];
    return nil;
}
/* draws an item's pages (a PDF's pages, or one image page); returns how many it drew (0: not printable) */
static NSInteger draw_item(id item, CGRect paper, CGRect printable, BOOL draw) {
    NSData *d = item_data(item);
    if (d && is_pdf(d)) {
        CGDataProviderRef pr = CGDataProviderCreateWithCFData((__bridge CFDataRef)d);
        CGPDFDocumentRef doc = CGPDFDocumentCreateWithProvider(pr);
        CGDataProviderRelease(pr);
        size_t n = CGPDFDocumentGetNumberOfPages(doc);
        for (size_t i = 1; draw && i <= n; i++) {
            CGPDFPageRef page = CGPDFDocumentGetPage(doc, i);
            CGRect box = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
            UIGraphicsBeginPDFPageWithInfo(paper, nil);
            CGContextRef c = UIGraphicsGetCurrentContext();
            CGFloat k = MIN(printable.size.width / box.size.width, printable.size.height / box.size.height);
            CGContextSaveGState(c);
            CGContextTranslateCTM(c, printable.origin.x + (printable.size.width - box.size.width * k) / 2, printable.origin.y + (printable.size.height + box.size.height * k) / 2);
            CGContextScaleCTM(c, k, -k);
            CGContextTranslateCTM(c, -box.origin.x, -box.origin.y);
            CGContextDrawPDFPage(c, page);
            CGContextRestoreGState(c);
        }
        if (doc) CGPDFDocumentRelease(doc);
        return (NSInteger)n;
    }
    UIImage *img = [item isKindOfClass:UIImage.class] ? item : d ? [UIImage imageWithData:d] : nil;
    if (!img || img.size.width <= 0) return 0;
    if (draw) {
        UIGraphicsBeginPDFPageWithInfo(paper, nil);
        CGSize s = img.size;
        CGFloat k = MIN(printable.size.width / s.width, printable.size.height / s.height);     /* fitted to the printable area */
        CGRect r = CGRectMake(printable.origin.x + (printable.size.width - s.width * k) / 2, printable.origin.y + (printable.size.height - s.height * k) / 2, s.width * k, s.height * k);
        [img drawInRect:r];
    }
    return 1;
}

@implementation UIPrintInteractionController {
    UIPrintInteractionCompletionHandler _completion;
    UIViewController *_sheet;
    NSInteger _copies;
    UIPrintPaper *_paper;
    BOOL _presenting;
}
+ (BOOL)isPrintingAvailable { return YES; }
+ (NSSet<NSString *> *)printableUTIs { return [NSSet setWithArray:@[@"com.adobe.pdf", @"public.png", @"public.jpeg", @"com.compuserve.gif", @"public.tiff", @"com.microsoft.bmp", @"public.image"]]; }
+ (BOOL)canPrintData:(NSData *)d { return d && (is_pdf(d) || [UIImage imageWithData:d] != nil); }
+ (BOOL)canPrintURL:(NSURL *)u { return u.isFileURL && [self canPrintData:[NSData dataWithContentsOfFile:u.path]]; }
+ (UIPrintInteractionController *)sharedPrintController { static UIPrintInteractionController *c; if (!c) c = [self new]; return c; }
- (instancetype)init { if ((self = [super init])) { _showsNumberOfCopies = YES; _copies = 1; } return self; }
- (UIPrintPaper *)printPaper { return _paper; }
- (void)setPrintingItem:(id)i { _printingItem = i; if (i) { _printingItems = nil; _printFormatter = nil; _printPageRenderer = nil; } }
- (void)setPrintingItems:(NSArray *)a { _printingItems = [a copy]; if (a) { _printingItem = nil; _printFormatter = nil; _printPageRenderer = nil; } }
- (void)setPrintFormatter:(UIPrintFormatter *)f { _printFormatter = f; if (f) { _printingItem = nil; _printingItems = nil; _printPageRenderer = nil; } }
- (void)setPrintPageRenderer:(UIPrintPageRenderer *)r { _printPageRenderer = r; if (r) { _printingItem = nil; _printingItems = nil; _printFormatter = nil; } }
- (UIPrintInfo *)_info { if (!_printInfo) _printInfo = [UIPrintInfo printInfo]; return _printInfo; }
/* the paper for this job: the delegate's choice from the printer's papers, turned for landscape */
- (void)_choosePaper {
    UIPrintPaper *letter = [[UIPrintPaper new] _isimSize:CGSizeMake(612, 792)], *a4 = [[UIPrintPaper new] _isimSize:CGSizeMake(595.2, 841.8)];
    id<UIPrintInteractionControllerDelegate> d = self.delegate;
    _paper = [d respondsToSelector:@selector(printInteractionController:choosePaper:)] ? [d printInteractionController:self choosePaper:@[letter, a4]] : [UIPrintPaper _isimDefault];
}
- (void)_rects:(CGRect *)paper printable:(CGRect *)printable {
    if (!_paper) [self _choosePaper];
    CGSize s = _paper.paperSize; CGRect p = _paper.printableRect;
    if ([self _info].orientation == UIPrintInfoOrientationLandscape) { s = CGSizeMake(s.height, s.width); p = CGRectMake(p.origin.y, p.origin.x, p.size.height, p.size.width); }
    *paper = CGRectMake(0, 0, s.width, s.height); *printable = p;
}
- (UIPrintPageRenderer *)_renderer {
    if (_printPageRenderer) return _printPageRenderer;
    if (!_printFormatter) return nil;
    UIPrintPageRenderer *r = [UIPrintPageRenderer new];
    [r addPrintFormatter:_printFormatter startingAtPageAtIndex:0];
    return r;
}
- (NSArray *)_items { return _printingItems ?: _printingItem ? @[_printingItem] : nil; }
/* the job as PDF data (pages × copies, collated); nil if there is nothing printable. pages: pages of one copy */
- (NSData *)_renderCopies:(NSInteger)copies pages:(NSInteger *)pagesOut firstPageOnly:(BOOL)first {
    CGRect paper, printable;
    [self _rects:&paper printable:&printable];
    UIPrintPageRenderer *r = [self _renderer];
    NSArray *items = [self _items];
    NSInteger pages = 0;
    if (r) { [r _isimSetPaper:paper printable:printable]; pages = r.numberOfPages; }
    else for (id it in items) pages += draw_item(it, paper, printable, NO);
    if (pagesOut) *pagesOut = pages;
    if (pages <= 0) return nil;
    NSMutableData *data = [NSMutableData data];
    UIGraphicsBeginPDFContextToData(data, paper, @{ @"Title": [self _info].jobName ?: @"", @"Creator": @"isim Printer" });
    for (NSInteger c = 0; c < (first ? 1 : copies); c++) {
        if (r) {
            NSInteger n = first ? 1 : pages;
            [r prepareForDrawingPages:NSMakeRange(0, (NSUInteger)n)];
            for (NSInteger i = 0; i < n; i++) { UIGraphicsBeginPDFPageWithInfo(paper, nil); [r drawPageAtIndex:i inRect:printable]; }
        } else for (id it in (first ? @[items.firstObject] : items)) draw_item(it, paper, printable, YES);
    }
    UIGraphicsEndPDFContext();
    return data;
}
- (NSString *)_outputPath {
    NSString *dir = [isim_data_dir() stringByAppendingPathComponent:@"Printer"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *name = [[[self _info].jobName ?: @"Document" stringByReplacingOccurrencesOfString:@"/" withString:@"-"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (!name.length) name = @"Document";
    NSString *p = [dir stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"pdf"]];
    for (int n = 2; [NSFileManager.defaultManager fileExistsAtPath:p]; n++) p = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ %d.pdf", name, n]];
    return p;
}
- (void)_finish:(BOOL)completed error:(NSError *)err {
    UIPrintInteractionCompletionHandler done = _completion;
    _completion = nil; _presenting = NO; _paper = nil;
    if (done) done(self, completed, err);
}
/* prints now: renders, writes the PDF, tells the delegate */
- (void)_runJob {
    id<UIPrintInteractionControllerDelegate> d = self.delegate;
    NSInteger pages = 0;
    NSData *pdf = [self _renderCopies:MAX(_copies, 1) pages:&pages firstPageOnly:NO];
    if (!pdf) {
        NSLog(@"isim UIKit: nothing to print");
        [self _finish:NO error:[NSError errorWithDomain:UIPrintErrorDomain code:UIPrintNoContentError userInfo:@{ NSLocalizedDescriptionKey: @"No content to print." }]];
        return;
    }
    if ([d respondsToSelector:@selector(printInteractionControllerWillStartJob:)]) [d printInteractionControllerWillStartJob:self];
    NSString *path = [self _outputPath];
    BOOL ok = [pdf writeToFile:path atomically:YES];
    static const char *types[] = { "general", "photo", "grayscale", "photo grayscale" };
    UIPrintInfo *info = [self _info];
    NSLog(@"isim UIKit: printed “%@”: %ld page(s) × %ld copies, %s, %@, %.0fx%.0f pt, on isim Printer → %@", info.jobName, (long)pages, (long)MAX(_copies, 1),
          types[MIN(MAX(info.outputType, 0), 3)], info.orientation == UIPrintInfoOrientationLandscape ? @"landscape" : @"portrait",
          _paper.paperSize.width, _paper.paperSize.height, path);
    if ([d respondsToSelector:@selector(printInteractionControllerDidFinishJob:)]) [d printInteractionControllerDidFinishJob:self];
    [self _finish:ok error:ok ? nil : [NSError errorWithDomain:UIPrintErrorDomain code:UIPrintJobFailedError userInfo:nil]];
}
- (BOOL)printToPrinter:(UIPrinter *)printer completionHandler:(UIPrintInteractionCompletionHandler)completion {
    if (![printer _isimIsSimulated]) { if (completion) completion(self, NO, [NSError errorWithDomain:UIPrintErrorDomain code:UIPrintingNotAvailableError userInfo:nil]); return NO; }
    _completion = [completion copy];
    _copies = 1;
    [self _choosePaper];
    [self _runJob];
    return YES;
}
- (UIViewController *)_parent {
    id<UIPrintInteractionControllerDelegate> d = self.delegate;
    UIViewController *p = [d respondsToSelector:@selector(printInteractionControllerParentViewController:)] ? [d printInteractionControllerParentViewController:self] : nil;
    if (!p) { p = UIApplication.sharedApplication.keyWindow.rootViewController; while (p.presentedViewController) p = p.presentedViewController; }
    return p;
}
- (BOOL)presentAnimated:(BOOL)animated completionHandler:(UIPrintInteractionCompletionHandler)completion {
    if (_presenting) return NO;
    NSInteger pages = 0;
    [self _choosePaper];
    if (![self _renderCopies:1 pages:&pages firstPageOnly:YES]) {
        NSLog(@"isim UIKit: printing: nothing to print");
        if (completion) completion(self, NO, [NSError errorWithDomain:UIPrintErrorDomain code:UIPrintNoContentError userInfo:nil]);
        return NO;
    }
    _completion = [completion copy]; _copies = 1; _presenting = YES;
    id<UIPrintInteractionControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(printInteractionControllerWillPresentPrinterOptions:)]) [d printInteractionControllerWillPresentPrinterOptions:self];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[self _optionsController:pages]];
    _sheet = nav;
    [[self _parent] presentViewController:nav animated:animated completion:^{
        if ([d respondsToSelector:@selector(printInteractionControllerDidPresentPrinterOptions:)]) [d printInteractionControllerDidPresentPrinterOptions:self];
    }];
    NSLog(@"isim UIKit: print options for “%@” (%ld page(s))", [self _info].jobName, (long)pages);
    return YES;
}
- (BOOL)presentFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated completionHandler:(UIPrintInteractionCompletionHandler)completion {
    return [self presentAnimated:animated completionHandler:completion];      /* iPhone-style sheet on every device (adapted) */
}
- (BOOL)presentFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated completionHandler:(UIPrintInteractionCompletionHandler)completion {
    return [self presentAnimated:animated completionHandler:completion];
}
- (void)_dismissSheet:(BOOL)animated then:(void (^)(void))after {
    id<UIPrintInteractionControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(printInteractionControllerWillDismissPrinterOptions:)]) [d printInteractionControllerWillDismissPrinterOptions:self];
    UIViewController *sheet = _sheet; _sheet = nil;
    [sheet.presentingViewController dismissViewControllerAnimated:animated completion:^{
        if ([d respondsToSelector:@selector(printInteractionControllerDidDismissPrinterOptions:)]) [d printInteractionControllerDidDismissPrinterOptions:self];
        if (after) after();
    }];
}
- (void)dismissAnimated:(BOOL)animated { if (_sheet) [self _dismissSheet:animated then:^{ [self _finish:NO error:nil]; }]; }
- (void)isimPrintCancel { NSLog(@"isim UIKit: printing cancelled"); [self _dismissSheet:YES then:^{ [self _finish:NO error:nil]; }]; }
- (void)isimPrintNow { [self _dismissSheet:YES then:^{ [self _runJob]; }]; }

/* the Options sheet: printer, copies, orientation, preview */
- (UIViewController *)_optionsController:(NSInteger)pages {
    UIViewController *vc = [UIViewController new];
    vc.title = @"Options";
    vc.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(isimPrintCancel)];
    UIBarButtonItem *print = [[UIBarButtonItem alloc] initWithTitle:@"Print" style:UIBarButtonItemStyleDone target:self action:@selector(isimPrintNow)];
    cancel.accessibilityIdentifier = @"print-cancel"; print.accessibilityIdentifier = @"print-print";
    vc.navigationItem.leftBarButtonItem = cancel; vc.navigationItem.rightBarButtonItem = print;
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:stack];
    UILabel *printer = [UILabel new];
    printer.text = @"Printer: isim Printer"; printer.accessibilityIdentifier = @"print-printer";
    [stack addArrangedSubview:printer];
    if (_showsNumberOfCopies) {
        UILabel *copies = [UILabel new]; copies.text = @"1 Copy"; copies.accessibilityIdentifier = @"print-copies-label";
        UIStepper *st = [UIStepper new]; st.minimumValue = 1; st.maximumValue = 99; st.value = 1; st.accessibilityIdentifier = @"print-copies";
        __weak UIPrintInteractionController *w = self;
        [st addAction:[UIAction actionWithHandler:^(UIAction *a) {
            UIPrintInteractionController *s = w; if (!s) return;
            s->_copies = (NSInteger)((UIStepper *)a.sender).value;
            copies.text = s->_copies == 1 ? @"1 Copy" : [NSString stringWithFormat:@"%ld Copies", (long)s->_copies];
        }] forControlEvents:UIControlEventValueChanged];
        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[copies, st]];
        row.spacing = 12;
        [stack addArrangedSubview:row];
    }
    if (_showsPaperOrientation) {
        UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"Portrait", @"Landscape"]];
        seg.selectedSegmentIndex = [self _info].orientation == UIPrintInfoOrientationLandscape ? 1 : 0;
        seg.accessibilityIdentifier = @"print-orientation";
        __weak UIPrintInteractionController *w = self;
        [seg addAction:[UIAction actionWithHandler:^(UIAction *a) {
            UIPrintInteractionController *s = w; if (!s) return;
            [s _info].orientation = ((UISegmentedControl *)a.sender).selectedSegmentIndex == 1 ? UIPrintInfoOrientationLandscape : UIPrintInfoOrientationPortrait;
            [s _updatePreview:vc];
        }] forControlEvents:UIControlEventValueChanged];
        [stack addArrangedSubview:seg];
    }
    UILabel *count = [UILabel new];
    count.text = pages == 1 ? @"1 page" : [NSString stringWithFormat:@"%ld pages", (long)pages];
    count.textColor = UIColor.secondaryLabelColor; count.accessibilityIdentifier = @"print-pages";
    [stack addArrangedSubview:count];
    UIImageView *preview = [UIImageView new];
    preview.contentMode = UIViewContentModeScaleAspectFit; preview.tag = 77; preview.accessibilityIdentifier = @"print-preview";
    preview.layer.shadowOpacity = 0.2; preview.layer.shadowRadius = 6;
    [stack addArrangedSubview:preview];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-20],
        [preview.heightAnchor constraintEqualToConstant:360]]];
    [self _updatePreview:vc];
    return vc;
}
/* the first page, rendered as it will print */
- (void)_updatePreview:(UIViewController *)vc {
    UIImageView *iv = (UIImageView *)[vc.view viewWithTag:77];
    NSData *pdf = [self _renderCopies:1 pages:NULL firstPageOnly:YES];
    if (!pdf) { iv.image = nil; return; }
    CGDataProviderRef pr = CGDataProviderCreateWithCFData((__bridge CFDataRef)pdf);
    CGPDFDocumentRef doc = CGPDFDocumentCreateWithProvider(pr);
    CGDataProviderRelease(pr);
    CGPDFPageRef page = CGPDFDocumentGetPage(doc, 1);
    if (page) {
        CGRect box = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
        iv.image = [[[UIGraphicsImageRenderer alloc] initWithSize:box.size] imageWithActions:^(UIGraphicsImageRendererContext *c) {
            [UIColor.whiteColor setFill]; UIRectFill(CGRectMake(0, 0, box.size.width, box.size.height));
            CGContextTranslateCTM(c.CGContext, 0, box.size.height); CGContextScaleCTM(c.CGContext, 1, -1);
            CGContextDrawPDFPage(c.CGContext, page);
        }];
    }
    if (doc) CGPDFDocumentRelease(doc);
}
@end

/* ---------------- printer picker ---------------- */
@implementation UIPrinterPickerController { UIPrinter *_selected; UIPrinterPickerCompletionHandler _completion; UIViewController *_sheet; }
+ (UIPrinterPickerController *)printerPickerControllerWithInitiallySelectedPrinter:(UIPrinter *)p { UIPrinterPickerController *c = [self new]; c->_selected = p; return c; }
- (UIPrinter *)selectedPrinter { return _selected; }
- (BOOL)presentAnimated:(BOOL)animated completionHandler:(UIPrinterPickerCompletionHandler)completion {
    if (_sheet) return NO;
    _completion = [completion copy];
    id<UIPrinterPickerControllerDelegate> d = self.delegate;
    UIPrinter *isim = [UIPrinter _isimPrinter];
    BOOL show = ![d respondsToSelector:@selector(printerPickerController:shouldShowPrinter:)] || [d printerPickerController:self shouldShowPrinter:isim];
    UIViewController *list = [UIViewController new];
    list.title = @"Printer";
    list.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(isimPickerCancel)];
    cancel.accessibilityIdentifier = @"printer-cancel";
    list.navigationItem.leftBarButtonItem = cancel;
    UIButton *row = [UIButton buttonWithType:UIButtonTypeSystem];
    [row setTitle:show ? @"isim Printer" : @"No AirPrint Printers Found" forState:UIControlStateNormal];
    row.enabled = show; row.accessibilityIdentifier = @"printer-isim";
    row.frame = CGRectMake(20, 100, 300, 44);
    row.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; row.layer.cornerRadius = 10;
    row.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
    row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [row addTarget:self action:@selector(isimPickerChoose) forControlEvents:UIControlEventTouchUpInside];
    [list.view addSubview:row];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:list];
    _sheet = nav;
    static char k_picker;
    objc_setAssociatedObject(nav, &k_picker, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);   /* alive while shown, like iOS's */
    UIViewController *p = [d respondsToSelector:@selector(printerPickerControllerParentViewController:)] ? [d printerPickerControllerParentViewController:self] : nil;
    if (!p) { p = UIApplication.sharedApplication.keyWindow.rootViewController; while (p.presentedViewController) p = p.presentedViewController; }
    if ([d respondsToSelector:@selector(printerPickerControllerWillPresent:)]) [d printerPickerControllerWillPresent:self];
    [p presentViewController:nav animated:animated completion:^{ if ([d respondsToSelector:@selector(printerPickerControllerDidPresent:)]) [d printerPickerControllerDidPresent:self]; }];
    return YES;
}
- (BOOL)presentFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated completionHandler:(UIPrinterPickerCompletionHandler)completion { return [self presentAnimated:animated completionHandler:completion]; }
- (BOOL)presentFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated completionHandler:(UIPrinterPickerCompletionHandler)completion { return [self presentAnimated:animated completionHandler:completion]; }
- (void)_close:(BOOL)selected {
    id<UIPrinterPickerControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(printerPickerControllerWillDismiss:)]) [d printerPickerControllerWillDismiss:self];
    UIViewController *s = _sheet; _sheet = nil;
    UIPrinterPickerCompletionHandler done = _completion; _completion = nil;
    [s.presentingViewController dismissViewControllerAnimated:YES completion:^{
        if ([d respondsToSelector:@selector(printerPickerControllerDidDismiss:)]) [d printerPickerControllerDidDismiss:self];
        if (done) done(self, selected, nil);
    }];
}
- (void)isimPickerChoose {
    _selected = [UIPrinter _isimPrinter];
    NSLog(@"isim UIKit: printer picker selected isim Printer");
    id<UIPrinterPickerControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(printerPickerControllerDidSelectPrinter:)]) [d printerPickerControllerDidSelectPrinter:self];
    [self _close:YES];
}
- (void)isimPickerCancel { [self _close:NO]; }
- (void)dismissAnimated:(BOOL)animated { if (_sheet) [self _close:NO]; }
@end
