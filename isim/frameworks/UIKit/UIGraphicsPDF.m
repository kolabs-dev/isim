/* UIGraphicsPDFRenderer and the UIGraphicsBeginPDFContext functions: a host PDF target (cairo PDF surface) is
 * UIKit's drawing target while the actions run; UIKit's coordinate space (y down, points) is the page's. */
#import "UIKitPrivate.h"
#include <isim_host_cg.h>

@interface UIGraphicsRendererContext ()
@property (nonatomic, readwrite, strong) UIGraphicsRendererFormat *format;
@end

/* the PDF context stack (UIGraphicsBeginPDFContext* / renderers) */
struct pdfctx { void *target; CGRect bounds; NSMutableData *data; BOOL page; CGPoint pageOrigin; };
static struct pdfctx pdf_stack[8]; static int pdf_depth;
static struct pdfctx *cur_pdf(void) { return pdf_depth ? &pdf_stack[pdf_depth - 1] : NULL; }

static BOOL pdf_begin(const char *path, NSMutableData *data, CGRect b) {
    if (pdf_depth >= 8) return NO;
    if (b.size.width <= 0 || b.size.height <= 0) b = CGRectMake(0, 0, 612, 792);   /* US Letter, as on iOS */
    void *t = isim_cg_pdf_create(path, b.size.width, b.size.height);
    if (!t) return NO;
    pdf_stack[pdf_depth++] = (struct pdfctx){ t, b, data, NO, CGPointZero };
    isim_cg_target_bind(t);
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    return YES;
}
static void pdf_page(CGRect b) {
    struct pdfctx *p = cur_pdf(); if (!p) return;
    if (b.size.width <= 0 || b.size.height <= 0) b = p->bounds;
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
    isim_cg_pdf_begin_page(p->target, b.size.width, b.size.height);
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), -b.origin.x, -b.origin.y);
    p->page = YES;
    p->pageOrigin = b.origin;
}
static void pdf_end(void) {
    struct pdfctx *p = cur_pdf(); if (!p) return;
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
    isim_cg_target_unbind(p->target);
    unsigned char *bytes = NULL;
    long n = isim_cg_pdf_finish(p->target, &bytes);
    if (p->data && n > 0) [p->data appendBytes:bytes length:(NSUInteger)n];
    isim_image_bytes_free(bytes);
    isim_cg_target_free(p->target);
    p->data = nil;
    pdf_depth--;
}

BOOL UIGraphicsBeginPDFContextToFile(NSString *path, CGRect bounds, NSDictionary *info) { return pdf_begin(path.UTF8String, nil, bounds); }
void UIGraphicsBeginPDFContextToData(NSMutableData *data, CGRect bounds, NSDictionary *info) { pdf_begin(NULL, data, bounds); }
void UIGraphicsEndPDFContext(void) { pdf_end(); }
void UIGraphicsBeginPDFPage(void) { pdf_page(CGRectZero); }
void UIGraphicsBeginPDFPageWithInfo(CGRect bounds, NSDictionary *info) { pdf_page(bounds); }
CGRect UIGraphicsGetPDFContextBounds(void) { struct pdfctx *p = cur_pdf(); return p ? p->bounds : CGRectZero; }
/* links and destinations on the current page (cairo PDF tags): UIKit's rects are already the page's y-down units */
static NSString *pdf_quoted(NSString *s) {
    return [[s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
}
static void pdf_tag(int kind, NSString *attrs) {
    struct pdfctx *p = cur_pdf();
    if (p && p->page && attrs) isim_cg_pdf_tag(p->target, kind, attrs.UTF8String);
}
static NSString *pdf_rect(CGRect r) {
    struct pdfctx *p = cur_pdf();
    r = CGRectStandardize(r);
    CGPoint o = p ? p->pageOrigin : CGPointZero;
    return [NSString stringWithFormat:@"rect=[%g %g %g %g]", r.origin.x - o.x, r.origin.y - o.y, r.size.width, r.size.height];
}
void UIGraphicsSetPDFContextURLForRect(NSURL *url, CGRect rect) {
    if (url) pdf_tag(0, [NSString stringWithFormat:@"uri='%@' %@", pdf_quoted(url.absoluteString), pdf_rect(rect)]);
}
void UIGraphicsAddPDFContextDestinationAtPoint(NSString *name, CGPoint point) {
    struct pdfctx *p = cur_pdf();
    CGPoint o = p ? p->pageOrigin : CGPointZero;
    if (name) pdf_tag(1, [NSString stringWithFormat:@"name='%@' x=%g y=%g", pdf_quoted(name), point.x - o.x, point.y - o.y]);
}
void UIGraphicsSetPDFContextDestinationForRect(NSString *name, CGRect rect) {
    if (name) pdf_tag(0, [NSString stringWithFormat:@"dest='%@' %@", pdf_quoted(name), pdf_rect(rect)]);
}

@implementation UIGraphicsPDFRendererFormat
- (instancetype)init { if ((self = [super init])) _documentInfo = @{}; return self; }
- (id)copyWithZone:(NSZone *)z { UIGraphicsPDFRendererFormat *f = [super copyWithZone:z]; f.documentInfo = _documentInfo; return f; }
@end
@implementation UIGraphicsPDFRendererContext
- (CGRect)pdfContextBounds { return UIGraphicsGetPDFContextBounds(); }
- (void)beginPage { pdf_page(CGRectZero); }
- (void)beginPageWithBounds:(CGRect)b pageInfo:(NSDictionary *)info { pdf_page(b); }
- (void)setURL:(NSURL *)url forRect:(CGRect)rect { UIGraphicsSetPDFContextURLForRect(url, rect); }
- (void)addDestinationWithName:(NSString *)name atPoint:(CGPoint)point { UIGraphicsAddPDFContextDestinationAtPoint(name, point); }
- (void)setDestinationWithName:(NSString *)name forRect:(CGRect)rect { UIGraphicsSetPDFContextDestinationForRect(name, rect); }
@end
@implementation UIGraphicsPDFRenderer
+ (Class)rendererContextClass { return [UIGraphicsPDFRendererContext class]; }
- (instancetype)initWithBounds:(CGRect)b { return [self initWithBounds:b format:[UIGraphicsPDFRendererFormat defaultFormat]]; }
- (instancetype)initWithBounds:(CGRect)b format:(UIGraphicsPDFRendererFormat *)f { return [super initWithBounds:b format:f ?: [UIGraphicsPDFRendererFormat defaultFormat]]; }
- (BOOL)allowsImageOutput { return NO; }
- (BOOL)_run:(const char *)path data:(NSMutableData *)data actions:(UIGraphicsPDFDrawingActions)actions {
    if (!pdf_begin(path, data, self.format.bounds)) return NO;
    UIGraphicsPDFRendererContext *ctx = [UIGraphicsPDFRendererContext new]; ctx.format = self.format;
    if (actions) actions(ctx);
    pdf_end();
    return YES;
}
- (NSData *)PDFDataWithActions:(UIGraphicsPDFDrawingActions)actions {
    NSMutableData *d = [NSMutableData data];
    [self _run:NULL data:d actions:actions];
    return d;
}
- (BOOL)writePDFToURL:(NSURL *)url withActions:(UIGraphicsPDFDrawingActions)actions error:(NSError **)error {
    if ([self _run:url.path.UTF8String data:nil actions:actions]) return YES;
    if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:512 userInfo:@{ NSLocalizedDescriptionKey: @"The PDF could not be written." }];
    return NO;
}
@end
