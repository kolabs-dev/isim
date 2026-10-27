/* isim PDFKit: PDFAnnotation, PDFBorder, PDFAppearanceCharacteristics and the PDFAction classes (issue #358).
 * Adapted:
 *   - an annotation's properties are its dictionary's values (annotationKeyValues), read from the page's /Annots
 *     (widget fields inherit /FT, /T, /V, /Ff... from their parent fields) or set;
 *   - isim draws an annotation from its properties (markup over the quadrilaterals, ink paths, shapes, lines with
 *     their endings, notes, free text, stamps, form fields with their values); appearance streams are not drawn;
 *   - writing gives each annotation a dictionary of its properties (PDFAnnotation+Writing, PDFKit.m puts them in the
 *     written pages' /Annots).
 * Points of quadrilaterals, lines and ink paths are relative to the annotation's bounds origin, as on Apple's. */
#import "pdfkit_internal.h"
#include <math.h>

PDFAnnotationKey PDFAnnotationKeyAppearanceDictionary = @"/AP";
PDFAnnotationKey PDFAnnotationKeyAppearanceState = @"/AS";
PDFAnnotationKey PDFAnnotationKeyBorder = @"/Border";
PDFAnnotationKey PDFAnnotationKeyColor = @"/C";
PDFAnnotationKey PDFAnnotationKeyContents = @"/Contents";
PDFAnnotationKey PDFAnnotationKeyFlags = @"/F";
PDFAnnotationKey PDFAnnotationKeyDate = @"/M";
PDFAnnotationKey PDFAnnotationKeyName = @"/NM";
PDFAnnotationKey PDFAnnotationKeyPage = @"/P";
PDFAnnotationKey PDFAnnotationKeyRect = @"/Rect";
PDFAnnotationKey PDFAnnotationKeySubtype = @"/Subtype";
PDFAnnotationKey PDFAnnotationKeyAction = @"/A";
PDFAnnotationKey PDFAnnotationKeyAdditionalActions = @"/AA";
PDFAnnotationKey PDFAnnotationKeyBorderStyle = @"/BS";
PDFAnnotationKey PDFAnnotationKeyDefaultAppearance = @"/DA";
PDFAnnotationKey PDFAnnotationKeyDestination = @"/Dest";
PDFAnnotationKey PDFAnnotationKeyHighlightingMode = @"/H";
PDFAnnotationKey PDFAnnotationKeyInklist = @"/InkList";
PDFAnnotationKey PDFAnnotationKeyInteriorColor = @"/IC";
PDFAnnotationKey PDFAnnotationKeyLinePoints = @"/L";
PDFAnnotationKey PDFAnnotationKeyLineEndingStyles = @"/LE";
PDFAnnotationKey PDFAnnotationKeyIconName = @"/Name";
PDFAnnotationKey PDFAnnotationKeyOpen = @"/Open";
PDFAnnotationKey PDFAnnotationKeyParent = @"/Parent";
PDFAnnotationKey PDFAnnotationKeyPopup = @"/Popup";
PDFAnnotationKey PDFAnnotationKeyQuadding = @"/Q";
PDFAnnotationKey PDFAnnotationKeyQuadPoints = @"/QuadPoints";
PDFAnnotationKey PDFAnnotationKeyTextLabel = @"/T";
PDFAnnotationKey PDFAnnotationKeyWidgetDownCaption = @"/AC";
PDFAnnotationKey PDFAnnotationKeyWidgetBorderColor = @"/BC";
PDFAnnotationKey PDFAnnotationKeyWidgetBackgroundColor = @"/BG";
PDFAnnotationKey PDFAnnotationKeyWidgetCaption = @"/CA";
PDFAnnotationKey PDFAnnotationKeyWidgetDefaultValue = @"/DV";
PDFAnnotationKey PDFAnnotationKeyWidgetFieldFlags = @"/Ff";
PDFAnnotationKey PDFAnnotationKeyWidgetFieldType = @"/FT";
PDFAnnotationKey PDFAnnotationKeyWidgetAppearanceDictionary = @"/MK";
PDFAnnotationKey PDFAnnotationKeyWidgetMaxLen = @"/MaxLen";
PDFAnnotationKey PDFAnnotationKeyWidgetOptions = @"/Opt";
PDFAnnotationKey PDFAnnotationKeyWidgetRotation = @"/R";
PDFAnnotationKey PDFAnnotationKeyWidgetRolloverCaption = @"/RC";
PDFAnnotationKey PDFAnnotationKeyWidgetTextLabelUI = @"/TU";
PDFAnnotationKey PDFAnnotationKeyWidgetValue = @"/V";

PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleNone = @"/None";
PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleSquare = @"/Square";
PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleCircle = @"/Circle";
PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleDiamond = @"/Diamond";
PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleOpenArrow = @"/OpenArrow";
PDFAnnotationLineEndingStyle PDFAnnotationLineEndingStyleClosedArrow = @"/ClosedArrow";
PDFAnnotationTextIconType PDFAnnotationTextIconTypeComment = @"/Comment";
PDFAnnotationTextIconType PDFAnnotationTextIconTypeKey = @"/Key";
PDFAnnotationTextIconType PDFAnnotationTextIconTypeNote = @"/Note";
PDFAnnotationTextIconType PDFAnnotationTextIconTypeHelp = @"/Help";
PDFAnnotationTextIconType PDFAnnotationTextIconTypeNewParagraph = @"/NewParagraph";
PDFAnnotationTextIconType PDFAnnotationTextIconTypeParagraph = @"/Paragraph";
PDFAnnotationTextIconType PDFAnnotationTextIconTypeInsert = @"/Insert";
PDFAnnotationHighlightingMode PDFAnnotationHighlightingModeNone = @"/N";
PDFAnnotationHighlightingMode PDFAnnotationHighlightingModeInvert = @"/I";
PDFAnnotationHighlightingMode PDFAnnotationHighlightingModeOutline = @"/O";
PDFAnnotationHighlightingMode PDFAnnotationHighlightingModePush = @"/P";
PDFAnnotationWidgetSubtype PDFAnnotationWidgetSubtypeButton = @"/Btn";
PDFAnnotationWidgetSubtype PDFAnnotationWidgetSubtypeChoice = @"/Ch";
PDFAnnotationWidgetSubtype PDFAnnotationWidgetSubtypeSignature = @"/Sig";
PDFAnnotationWidgetSubtype PDFAnnotationWidgetSubtypeText = @"/Tx";
PDFAnnotationSubtype PDFAnnotationSubtypeText = @"/Text";
PDFAnnotationSubtype PDFAnnotationSubtypeLink = @"/Link";
PDFAnnotationSubtype PDFAnnotationSubtypeFreeText = @"/FreeText";
PDFAnnotationSubtype PDFAnnotationSubtypeLine = @"/Line";
PDFAnnotationSubtype PDFAnnotationSubtypeSquare = @"/Square";
PDFAnnotationSubtype PDFAnnotationSubtypeCircle = @"/Circle";
PDFAnnotationSubtype PDFAnnotationSubtypeHighlight = @"/Highlight";
PDFAnnotationSubtype PDFAnnotationSubtypeUnderline = @"/Underline";
PDFAnnotationSubtype PDFAnnotationSubtypeStrikeOut = @"/StrikeOut";
PDFAnnotationSubtype PDFAnnotationSubtypeInk = @"/Ink";
PDFAnnotationSubtype PDFAnnotationSubtypeStamp = @"/Stamp";
PDFAnnotationSubtype PDFAnnotationSubtypePopup = @"/Popup";
PDFAnnotationSubtype PDFAnnotationSubtypeWidget = @"/Widget";
PDFBorderKey PDFBorderKeyLineWidth = @"/W";
PDFBorderKey PDFBorderKeyStyle = @"/S";
PDFBorderKey PDFBorderKeyDashPattern = @"/D";
PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyBackgroundColor = @"/BG";
PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyBorderColor = @"/BC";
PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyRotation = @"/R";
PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyCaption = @"/CA";
PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyRolloverCaption = @"/RC";
PDFAppearanceCharacteristicsKey PDFAppearanceCharacteristicsKeyDownCaption = @"/AC";

/* ================= PDF syntax ================= */
NSString *isim_pdf_number(CGFloat v) {
    if (!isfinite(v)) v = 0;
    if (v == floor(v) && fabs(v) < 1e9) return [NSString stringWithFormat:@"%ld", (long)v];
    NSString *s = [NSString stringWithFormat:@"%.4f", v];
    while ([s hasSuffix:@"0"]) s = [s substringToIndex:s.length - 1];
    return [s hasSuffix:@"."] ? [s substringToIndex:s.length - 1] : s;
}
NSString *isim_pdf_name(NSString *s) {
    if ([s hasPrefix:@"/"]) s = [s substringFromIndex:1];
    NSMutableString *out = [NSMutableString stringWithString:@"/"];
    for (const unsigned char *p = (const unsigned char *)s.UTF8String; p && *p; p++) {
        if (*p > 32 && *p < 127 && !strchr("#()<>[]{}/%", *p)) [out appendFormat:@"%c", *p];
        else [out appendFormat:@"#%02X", *p];
    }
    return out;
}
/* a text string: PDFDocEncoding's ASCII part as a literal, anything else as UTF-16BE with a BOM (hex) */
NSString *isim_pdf_string_literal(NSString *s) {
    BOOL ascii = YES;
    for (NSUInteger i = 0; i < s.length && ascii; i++) { unichar c = [s characterAtIndex:i]; ascii = c >= 32 && c < 127; }
    if (ascii) {
        NSMutableString *out = [NSMutableString stringWithString:@"("];
        for (NSUInteger i = 0; i < s.length; i++) {
            unichar c = [s characterAtIndex:i];
            if (c == '(' || c == ')' || c == '\\') [out appendString:@"\\"];
            [out appendFormat:@"%C", c];
        }
        [out appendString:@")"];
        return out;
    }
    NSMutableString *out = [NSMutableString stringWithString:@"<FEFF"];
    for (NSUInteger i = 0; i < s.length; i++) [out appendFormat:@"%04X", [s characterAtIndex:i]];
    [out appendString:@">"];
    return out;
}
UIColor *isim_pdf_color(CGPDFArrayRef a) {
    CGPDFReal v[4] = {0};
    size_t n = a ? CGPDFArrayGetCount(a) : 0;
    for (size_t i = 0; i < n && i < 4; i++) CGPDFArrayGetNumber(a, i, &v[i]);
    if (n == 1) return [UIColor colorWithWhite:v[0] alpha:1];
    if (n == 3) return [UIColor colorWithRed:v[0] green:v[1] blue:v[2] alpha:1];
    if (n == 4) return [UIColor colorWithRed:(1 - v[0]) * (1 - v[3]) green:(1 - v[1]) * (1 - v[3]) blue:(1 - v[2]) * (1 - v[3]) alpha:1];
    return nil;                                                       /* [] : transparent */
}
NSString *isim_pdf_color_array(UIColor *c) {
    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (!c || ![c getRed:&r green:&g blue:&b alpha:&a]) { CGFloat w = 0; if (c && [c getWhite:&w alpha:&a]) r = g = b = w; }
    if (a <= 0) return @"[]";
    return [NSString stringWithFormat:@"[%@ %@ %@]", isim_pdf_number(r), isim_pdf_number(g), isim_pdf_number(b)];
}
static NSString *pdf_date(NSDate *d) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    f.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    f.dateFormat = @"yyyyMMddHHmmss";
    return [NSString stringWithFormat:@"(D:%@Z)", [f stringFromDate:d]];
}
static CGRect transform_rect(CGRect r, CGAffineTransform t) { return CGRectStandardize(CGRectApplyAffineTransform(r, t)); }
static NSString *rect_array(CGRect r) {
    return [NSString stringWithFormat:@"[%@ %@ %@ %@]", isim_pdf_number(CGRectGetMinX(r)), isim_pdf_number(CGRectGetMinY(r)),
            isim_pdf_number(CGRectGetMaxX(r)), isim_pdf_number(CGRectGetMaxY(r))];
}

/* ================= PDFBorder ================= */
@implementation PDFBorder
- (instancetype)init { if ((self = [super init])) _lineWidth = 1; return self; }
- (id)copyWithZone:(NSZone *)zone {
    PDFBorder *b = [[PDFBorder alloc] init];
    b.style = _style; b.lineWidth = _lineWidth; b.dashPattern = _dashPattern;
    return b;
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if (!(self = [self init])) return nil;
    _style = [c decodeIntegerForKey:@"style"];
    _lineWidth = [c decodeDoubleForKey:@"lineWidth"];
    _dashPattern = [c decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSNumber class], nil] forKey:@"dashPattern"];
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeInteger:_style forKey:@"style"];
    [c encodeDouble:_lineWidth forKey:@"lineWidth"];
    if (_dashPattern) [c encodeObject:_dashPattern forKey:@"dashPattern"];
}
static NSString *const style_names[] = { @"/S", @"/D", @"/B", @"/I", @"/U" };
- (NSDictionary *)borderKeyValues {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[PDFBorderKeyLineWidth] = @(_lineWidth);
    d[PDFBorderKeyStyle] = style_names[_style >= 0 && _style <= 4 ? _style : 0];
    if (_dashPattern.count) d[PDFBorderKeyDashPattern] = _dashPattern;
    return d;
}
- (void)_isim_stroke:(CGContextRef)c rect:(CGRect)rect {
    if (!c || _lineWidth <= 0) return;
    CGContextSaveGState(c);
    CGContextSetLineWidth(c, _lineWidth);
    if (_style == kPDFBorderStyleDashed) {
        CGFloat dash[8]; size_t n = 0;
        for (NSNumber *v in _dashPattern) if (n < 8) dash[n++] = v.doubleValue;
        if (!n) { dash[0] = 3; n = 1; }
        CGContextSetLineDash(c, 0, dash, n);
    }
    CGRect r = CGRectInset(rect, _lineWidth / 2, _lineWidth / 2);
    if (_style == kPDFBorderStyleUnderline) {
        CGContextMoveToPoint(c, CGRectGetMinX(r), CGRectGetMinY(r));
        CGContextAddLineToPoint(c, CGRectGetMaxX(r), CGRectGetMinY(r));
        CGContextStrokePath(c);
    } else CGContextStrokeRect(c, r);
    CGContextRestoreGState(c);
}
- (void)drawInRect:(CGRect)rect { [self _isim_stroke:UIGraphicsGetCurrentContext() rect:rect]; }
- (NSString *)_isim_pdfSource {
    NSMutableString *s = [NSMutableString stringWithFormat:@"<< /Type /Border /W %@ /S %@", isim_pdf_number(_lineWidth),
                          style_names[_style >= 0 && _style <= 4 ? _style : 0]];
    if (_dashPattern.count) {
        [s appendString:@" /D ["];
        for (NSNumber *v in _dashPattern) [s appendFormat:@" %@", isim_pdf_number(v.doubleValue)];
        [s appendString:@" ]"];
    }
    [s appendString:@" >>"];
    return s;
}
@end

/* ================= PDFAppearanceCharacteristics ================= */
@implementation PDFAppearanceCharacteristics
- (instancetype)init { if ((self = [super init])) _controlType = kPDFWidgetUnknownControl; return self; }
- (id)copyWithZone:(NSZone *)zone {
    PDFAppearanceCharacteristics *a = [[PDFAppearanceCharacteristics alloc] init];
    a.controlType = _controlType; a.backgroundColor = _backgroundColor; a.borderColor = _borderColor; a.rotation = _rotation;
    a.caption = _caption; a.rolloverCaption = _rolloverCaption; a.downCaption = _downCaption;
    return a;
}
- (NSDictionary *)appearanceCharacteristicsKeyValues {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (_backgroundColor) d[PDFAppearanceCharacteristicsKeyBackgroundColor] = _backgroundColor;
    if (_borderColor) d[PDFAppearanceCharacteristicsKeyBorderColor] = _borderColor;
    if (_rotation) d[PDFAppearanceCharacteristicsKeyRotation] = @(_rotation);
    if (_caption) d[PDFAppearanceCharacteristicsKeyCaption] = _caption;
    if (_rolloverCaption) d[PDFAppearanceCharacteristicsKeyRolloverCaption] = _rolloverCaption;
    if (_downCaption) d[PDFAppearanceCharacteristicsKeyDownCaption] = _downCaption;
    return d;
}
- (NSString *)_isim_pdfSource {
    NSMutableString *s = [NSMutableString stringWithString:@"<<"];
    if (_backgroundColor) [s appendFormat:@" /BG %@", isim_pdf_color_array(_backgroundColor)];
    if (_borderColor) [s appendFormat:@" /BC %@", isim_pdf_color_array(_borderColor)];
    if (_rotation) [s appendFormat:@" /R %ld", (long)_rotation];
    if (_caption) [s appendFormat:@" /CA %@", isim_pdf_string_literal(_caption)];
    if (_rolloverCaption) [s appendFormat:@" /RC %@", isim_pdf_string_literal(_rolloverCaption)];
    if (_downCaption) [s appendFormat:@" /AC %@", isim_pdf_string_literal(_downCaption)];
    [s appendString:@" >>"];
    return s;
}
@end

/* ================= actions ================= */
@implementation PDFAction
- (NSString *)type { return @""; }
- (id)copyWithZone:(NSZone *)zone { return [[[self class] alloc] init]; }
- (NSString *)_isim_pdfSourceWithPages:(NSArray<PDFPage *> *)pages transform:(CGAffineTransform (^)(PDFPage *))transform { return nil; }
@end

static NSString *dest_source(PDFDestination *d, NSArray<PDFPage *> *pages, CGAffineTransform (^transform)(PDFPage *)) {
    NSUInteger at = d.page ? [pages indexOfObjectIdenticalTo:d.page] : NSNotFound;
    if (at == NSNotFound) return nil;
    CGPoint p = d.point;
    BOOL hasX = p.x != kPDFDestinationUnspecifiedValue, hasY = p.y != kPDFDestinationUnspecifiedValue;
    CGPoint q = CGPointApplyAffineTransform(CGPointMake(hasX ? p.x : 0, hasY ? p.y : 0), transform(d.page));
    return [NSString stringWithFormat:@"[@P%lu@ /XYZ %@ %@ %@]", (unsigned long)at, hasX ? isim_pdf_number(q.x) : @"null",
            hasY ? isim_pdf_number(q.y) : @"null", d.zoom != kPDFDestinationUnspecifiedValue ? isim_pdf_number(d.zoom) : @"null"];
}

@implementation PDFActionGoTo
- (instancetype)initWithDestination:(PDFDestination *)destination {
    if ((self = [super init])) _destination = destination;
    return self;
}
- (NSString *)type { return @"GoTo"; }
- (id)copyWithZone:(NSZone *)zone { return [[PDFActionGoTo alloc] initWithDestination:_destination]; }
- (NSString *)_isim_pdfSourceWithPages:(NSArray<PDFPage *> *)pages transform:(CGAffineTransform (^)(PDFPage *))transform {
    NSString *d = dest_source(_destination, pages, transform);
    return d ? [NSString stringWithFormat:@"<< /S /GoTo /D %@ >>", d] : nil;
}
@end

@implementation PDFActionURL
- (instancetype)initWithURL:(NSURL *)url {
    if ((self = [super init])) _URL = [url copy];
    return self;
}
- (NSString *)type { return @"URL"; }
- (id)copyWithZone:(NSZone *)zone { return [[PDFActionURL alloc] initWithURL:_URL]; }
- (NSString *)_isim_pdfSourceWithPages:(NSArray<PDFPage *> *)pages transform:(CGAffineTransform (^)(PDFPage *))transform {
    return _URL ? [NSString stringWithFormat:@"<< /S /URI /URI %@ >>", isim_pdf_string_literal(_URL.absoluteString)] : nil;
}
@end

static NSString *const named_names[] = { @"", @"NextPage", @"PrevPage", @"FirstPage", @"LastPage", @"GoBack", @"GoForward",
                                         @"GoToPage", @"Find", @"Print", @"ZoomIn", @"ZoomOut" };
@implementation PDFActionNamed
- (instancetype)initWithName:(PDFActionNamedName)name {
    if ((self = [super init])) _name = name;
    return self;
}
- (NSString *)type { return @"Named"; }
- (id)copyWithZone:(NSZone *)zone { return [[PDFActionNamed alloc] initWithName:_name]; }
- (NSString *)_isim_pdfSourceWithPages:(NSArray<PDFPage *> *)pages transform:(CGAffineTransform (^)(PDFPage *))transform {
    if (_name <= kPDFActionNamedNone || _name > kPDFActionNamedZoomOut) return nil;
    return [NSString stringWithFormat:@"<< /S /Named /N %@ >>", isim_pdf_name(named_names[_name])];
}
@end

@implementation PDFActionRemoteGoTo
- (instancetype)initWithPageIndex:(NSUInteger)pageIndex atPoint:(CGPoint)point fileURL:(NSURL *)url {
    if ((self = [super init])) { _pageIndex = pageIndex; _point = point; _URL = [url copy]; }
    return self;
}
- (NSString *)type { return @"RemoteGoTo"; }
- (id)copyWithZone:(NSZone *)zone { return [[PDFActionRemoteGoTo alloc] initWithPageIndex:_pageIndex atPoint:_point fileURL:_URL]; }
- (NSString *)_isim_pdfSourceWithPages:(NSArray<PDFPage *> *)pages transform:(CGAffineTransform (^)(PDFPage *))transform {
    NSString *file = _URL.isFileURL ? _URL.path : _URL.absoluteString;
    BOOL hasX = _point.x != kPDFDestinationUnspecifiedValue, hasY = _point.y != kPDFDestinationUnspecifiedValue;
    return [NSString stringWithFormat:@"<< /S /GoToR /F %@ /D [%lu /XYZ %@ %@ null] >>", isim_pdf_string_literal(file ?: @""),
            (unsigned long)_pageIndex, hasX ? isim_pdf_number(_point.x) : @"null", hasY ? isim_pdf_number(_point.y) : @"null"];
}
@end

@implementation PDFActionResetForm
- (instancetype)init { if ((self = [super init])) _fieldsIncludedAreCleared = YES; return self; }
- (NSString *)type { return @"ResetForm"; }
- (id)copyWithZone:(NSZone *)zone {
    PDFActionResetForm *a = [[PDFActionResetForm alloc] init];
    a.fields = _fields; a.fieldsIncludedAreCleared = _fieldsIncludedAreCleared;
    return a;
}
- (NSString *)_isim_pdfSourceWithPages:(NSArray<PDFPage *> *)pages transform:(CGAffineTransform (^)(PDFPage *))transform {
    NSMutableString *s = [NSMutableString stringWithString:@"<< /S /ResetForm"];
    if (_fields.count) {
        [s appendString:@" /Fields ["];
        for (NSString *f in _fields) [s appendFormat:@" %@", isim_pdf_string_literal(f)];
        [s appendString:@" ]"];
    }
    [s appendFormat:@" /Flags %d >>", _fieldsIncludedAreCleared ? 0 : 1];
    return s;
}
@end

/* an action dictionary (/A of a link or an outline item) */
@implementation PDFDocument (Actions)
- (PDFAction *)_isim_actionForDictionary:(CGPDFDictionaryRef)a {
    const char *s = NULL;
    if (!a || !CGPDFDictionaryGetName(a, "S", &s)) return nil;
    CGPDFObjectRef o; CGPDFStringRef str; const char *name;
    if (!strcmp(s, "GoTo")) {
        PDFDestination *d = CGPDFDictionaryGetObject(a, "D", &o) ? [self _isim_destinationForObject:o] : nil;
        return d ? [[PDFActionGoTo alloc] initWithDestination:d] : nil;
    }
    if (!strcmp(s, "URI")) {
        if (!CGPDFDictionaryGetString(a, "URI", &str)) return nil;
        NSString *u = [[NSString alloc] initWithBytes:CGPDFStringGetBytePtr(str) length:CGPDFStringGetLength(str) encoding:NSISOLatin1StringEncoding];
        NSURL *url = [NSURL URLWithString:u] ?: [NSURL URLWithString:[u stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]];
        return url ? [[PDFActionURL alloc] initWithURL:url] : nil;
    }
    if (!strcmp(s, "Named")) {
        if (!CGPDFDictionaryGetName(a, "N", &name)) return nil;
        for (int i = 1; i <= kPDFActionNamedZoomOut; i++) if (!strcmp(name, named_names[i].UTF8String)) return [[PDFActionNamed alloc] initWithName:i];
        return [[PDFActionNamed alloc] initWithName:kPDFActionNamedNone];
    }
    if (!strcmp(s, "GoToR")) {
        NSString *file = nil;
        CGPDFDictionaryRef spec;
        if (CGPDFDictionaryGetString(a, "F", &str)) file = CFBridgingRelease(CGPDFStringCopyTextString(str));
        else if (CGPDFDictionaryGetDictionary(a, "F", &spec) && (CGPDFDictionaryGetString(spec, "UF", &str) || CGPDFDictionaryGetString(spec, "F", &str)))
            file = CFBridgingRelease(CGPDFStringCopyTextString(str));
        CGPDFArrayRef d; CGPDFInteger page = 0; CGPDFReal x = kPDFDestinationUnspecifiedValue, y = kPDFDestinationUnspecifiedValue;
        if (CGPDFDictionaryGetArray(a, "D", &d)) { CGPDFArrayGetInteger(d, 0, &page); CGPDFArrayGetNumber(d, 2, &x); CGPDFArrayGetNumber(d, 3, &y); }
        NSURL *url = file ? ([file containsString:@"://"] ? [NSURL URLWithString:file] : [NSURL fileURLWithPath:file]) : nil;
        return [[PDFActionRemoteGoTo alloc] initWithPageIndex:(NSUInteger)MAX(page, 0) atPoint:CGPointMake(x, y) fileURL:url ?: [NSURL fileURLWithPath:@"/"]];
    }
    if (!strcmp(s, "ResetForm")) {
        PDFActionResetForm *r = [[PDFActionResetForm alloc] init];
        CGPDFArrayRef fields; CGPDFInteger flags = 0;
        if (CGPDFDictionaryGetArray(a, "Fields", &fields)) {
            NSMutableArray *names = [NSMutableArray array];
            for (size_t i = 0; i < CGPDFArrayGetCount(fields); i++) {
                CGPDFDictionaryRef f;
                if (CGPDFArrayGetString(fields, i, &str)) [names addObject:CFBridgingRelease(CGPDFStringCopyTextString(str))];
                else if (CGPDFArrayGetDictionary(fields, i, &f) && CGPDFDictionaryGetString(f, "T", &str)) [names addObject:CFBridgingRelease(CGPDFStringCopyTextString(str))];
            }
            r.fields = names;
        }
        CGPDFDictionaryGetInteger(a, "Flags", &flags);
        r.fieldsIncludedAreCleared = !(flags & 1);
        return r;
    }
    return nil;
}
@end

/* ================= PDFAnnotation ================= */
enum { F_HIDDEN = 2, F_PRINT = 4 };
enum { FF_READONLY = 1 << 0, FF_MULTILINE = 1 << 12, FF_PASSWORD = 1 << 13, FF_NOTOGGLEOFF = 1 << 14, FF_RADIO = 1 << 15,
       FF_PUSHBUTTON = 1 << 16, FF_COMBO = 1 << 17, FF_COMB = 1 << 24, FF_UNISON = 1 << 25 };

@implementation PDFAnnotation {
    NSMutableDictionary *_values;
    NSMutableArray<UIBezierPath *> *_paths;
    CGPDFDictionaryRef _source;
    NSString *_onState;
    NSDictionary *_pristine;            /* the values as read (a source annotation changed when they differ) */
    NSUInteger _pristinePaths;
}
- (instancetype)initWithBounds:(CGRect)bounds forType:(PDFAnnotationSubtype)type withProperties:(NSDictionary *)properties {
    if (!(self = [super init])) return nil;
    _values = [NSMutableDictionary dictionary];
    _values[PDFAnnotationKeySubtype] = [type hasPrefix:@"/"] ? type : [@"/" stringByAppendingString:type ?: @"Text"];
    _values[PDFAnnotationKeyRect] = [NSValue valueWithCGRect:CGRectStandardize(bounds)];
    _values[PDFAnnotationKeyFlags] = @(F_PRINT);
    for (id k in properties) if ([k isKindOfClass:[NSString class]]) [self setValue:properties[k] forAnnotationKey:k];
    return self;
}
- (instancetype)init { return [self initWithBounds:CGRectZero forType:PDFAnnotationSubtypeText withProperties:nil]; }
- (id)copyWithZone:(NSZone *)zone {
    PDFAnnotation *a = [[[self class] alloc] initWithBounds:self.bounds forType:_values[PDFAnnotationKeySubtype] withProperties:nil];
    a->_values = [_values mutableCopy];
    a->_paths = _paths ? [NSMutableArray array] : nil;
    for (UIBezierPath *p in _paths) [a->_paths addObject:[p copy]];
    a->_source = _source; a->_onState = _onState;
    return a;
}
- (instancetype)initWithCoder:(NSCoder *)c {
    NSString *type = [c decodeObjectOfClass:[NSString class] forKey:@"type"] ?: PDFAnnotationSubtypeText;
    NSString *rect = [c decodeObjectOfClass:[NSString class] forKey:@"bounds"];
    if (!(self = [self initWithBounds:rect ? CGRectFromString(rect) : CGRectZero forType:type withProperties:nil])) return nil;
    for (NSString *k in @[ PDFAnnotationKeyContents, PDFAnnotationKeyTextLabel, PDFAnnotationKeyName, PDFAnnotationKeyIconName ]) {
        NSString *v = [c decodeObjectOfClass:[NSString class] forKey:k];
        if (v) _values[k] = v;
    }
    NSNumber *flags = [c decodeObjectOfClass:[NSNumber class] forKey:PDFAnnotationKeyFlags];
    if (flags) _values[PDFAnnotationKeyFlags] = flags;
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_values[PDFAnnotationKeySubtype] forKey:@"type"];
    [c encodeObject:NSStringFromCGRect(self.bounds) forKey:@"bounds"];
    for (NSString *k in @[ PDFAnnotationKeyContents, PDFAnnotationKeyTextLabel, PDFAnnotationKeyName, PDFAnnotationKeyIconName, PDFAnnotationKeyFlags ])
        if (_values[k]) [c encodeObject:_values[k] forKey:k];
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<PDFAnnotation %p: %@ %@%@>", self, self.type, NSStringFromCGRect(self.bounds),
            self.contents.length ? [NSString stringWithFormat:@" \"%@\"", self.contents] : @""];
}

/* ---- the dictionary ---- */
- (NSDictionary *)annotationKeyValues {
    NSMutableDictionary *d = [_values mutableCopy];
    if (_paths.count) d[PDFAnnotationKeyInklist] = [_paths copy];
    return d;
}
- (id)valueForAnnotationKey:(PDFAnnotationKey)key {
    if ([key isEqualToString:PDFAnnotationKeyInklist]) return _paths.count ? [_paths copy] : nil;
    if ([key isEqualToString:PDFAnnotationKeyPage]) return self.page;
    return key ? _values[key] : nil;
}
- (BOOL)setValue:(id)value forAnnotationKey:(PDFAnnotationKey)annotationKey {
    NSString *key = annotationKey;
    if (!key) return NO;
    if (!value) { [self removeValueForAnnotationKey:key]; return YES; }
    if (![key hasPrefix:@"/"]) key = [@"/" stringByAppendingString:key];
    if ([key isEqualToString:PDFAnnotationKeyInklist]) {
        if (![value isKindOfClass:[NSArray class]]) return NO;
        _paths = [NSMutableArray array];
        for (id p in value) if ([p isKindOfClass:[UIBezierPath class]]) [_paths addObject:[p copy]];
        return YES;
    }
    if ([key isEqualToString:PDFAnnotationKeyRect] && [value isKindOfClass:[NSValue class]]) value = [NSValue valueWithCGRect:CGRectStandardize([value CGRectValue])];
    if ([key isEqualToString:PDFAnnotationKeySubtype] && [value isKindOfClass:[NSString class]] && ![value hasPrefix:@"/"]) value = [@"/" stringByAppendingString:value];
    if ([key isEqualToString:PDFAnnotationKeyBorderStyle] && [value isKindOfClass:[PDFBorder class]]) key = PDFAnnotationKeyBorder;
    if ([value isKindOfClass:[PDFAnnotation class]] || [value isKindOfClass:[PDFAction class]] || [value isKindOfClass:[PDFBorder class]] ||
        [value isKindOfClass:[PDFDestination class]] || [value isKindOfClass:[UIColor class]] || [value isKindOfClass:[PDFAppearanceCharacteristics class]])
        _values[key] = value;
    else if ([value conformsToProtocol:@protocol(NSCopying)]) _values[key] = [value copy];
    else _values[key] = value;
    if ([key isEqualToString:PDFAnnotationKeyPopup] && [value isKindOfClass:[PDFAnnotation class]])
        ((PDFAnnotation *)value)->_values[PDFAnnotationKeyParent] = [NSValue valueWithNonretainedObject:self];
    [self _changed];
    return YES;
}
- (BOOL)setBoolean:(BOOL)value forAnnotationKey:(PDFAnnotationKey)key { return [self setValue:@(value) forAnnotationKey:key]; }
- (BOOL)setRect:(CGRect)value forAnnotationKey:(PDFAnnotationKey)key { return [self setValue:[NSValue valueWithCGRect:value] forAnnotationKey:key]; }
- (void)removeValueForAnnotationKey:(PDFAnnotationKey)key {
    if ([key isEqualToString:PDFAnnotationKeyInklist]) _paths = nil;
    else if (key) [_values removeObjectForKey:key];
    [self _changed];
}
- (void)_changed {}
- (CGPDFDictionaryRef)_isim_sourceDictionary { return _source; }
- (BOOL)_isim_isModified { return _pristine && (![_values isEqualToDictionary:_pristine] || _paths.count != _pristinePaths); }

/* ---- the common properties ---- */
- (NSString *)type {
    NSString *t = _values[PDFAnnotationKeySubtype];
    return [t hasPrefix:@"/"] ? [t substringFromIndex:1] : t;
}
- (CGRect)bounds { return [_values[PDFAnnotationKeyRect] CGRectValue]; }
- (void)setBounds:(CGRect)bounds { [self setRect:bounds forAnnotationKey:PDFAnnotationKeyRect]; }
- (NSInteger)_flags { return [_values[PDFAnnotationKeyFlags] integerValue]; }
- (void)_setFlag:(NSInteger)f on:(BOOL)on { _values[PDFAnnotationKeyFlags] = @(on ? (self._flags | f) : (self._flags & ~f)); }
- (BOOL)shouldDisplay { return !(self._flags & F_HIDDEN); }
- (void)setShouldDisplay:(BOOL)v { [self _setFlag:F_HIDDEN on:!v]; }
- (BOOL)shouldPrint { return (self._flags & F_PRINT) != 0; }
- (void)setShouldPrint:(BOOL)v { [self _setFlag:F_PRINT on:v]; }
- (NSString *)userName { id v = _values[PDFAnnotationKeyTextLabel]; return [v isKindOfClass:[NSString class]] ? v : nil; }
- (void)setUserName:(NSString *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyTextLabel]; }
- (NSDate *)modificationDate { id v = _values[PDFAnnotationKeyDate]; return [v isKindOfClass:[NSDate class]] ? v : nil; }
- (void)setModificationDate:(NSDate *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyDate]; }
- (UIColor *)color { id v = _values[PDFAnnotationKeyColor]; return [v isKindOfClass:[UIColor class]] ? v : [UIColor clearColor]; }
- (void)setColor:(UIColor *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyColor]; }
- (NSString *)contents { id v = _values[PDFAnnotationKeyContents]; return [v isKindOfClass:[NSString class]] ? v : nil; }
- (void)setContents:(NSString *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyContents]; }
- (PDFAnnotation *)popup { id v = _values[PDFAnnotationKeyPopup]; return [v isKindOfClass:[PDFAnnotation class]] ? v : nil; }
- (void)setPopup:(PDFAnnotation *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyPopup]; }
- (PDFBorder *)border { id v = _values[PDFAnnotationKeyBorder]; return [v isKindOfClass:[PDFBorder class]] ? v : nil; }
- (void)setBorder:(PDFBorder *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyBorder]; }
- (PDFAction *)action { id v = _values[PDFAnnotationKeyAction]; return [v isKindOfClass:[PDFAction class]] ? v : nil; }
- (void)setAction:(PDFAction *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyAction]; }
- (BOOL)hasAppearanceStream {
    CGPDFDictionaryRef ap;
    return _values[PDFAnnotationKeyAppearanceDictionary] != nil || (_source && CGPDFDictionaryGetDictionary(_source, "AP", &ap));
}
- (PDFAnnotation *)_parentAnnotation { id v = _values[PDFAnnotationKeyParent]; return [v isKindOfClass:[NSValue class]] ? [v nonretainedObjectValue] : [v isKindOfClass:[PDFAnnotation class]] ? v : nil; }

/* ---- utilities: text ---- */
/* the default appearance: "/Helv 12 Tf 0 0 1 rg" */
- (NSString *)_da { id v = _values[PDFAnnotationKeyDefaultAppearance]; return [v isKindOfClass:[NSString class]] ? v : nil; }
- (UIFont *)font {
    NSArray *t = [self._da componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSUInteger tf = [t indexOfObject:@"Tf"];
    if (tf == NSNotFound || tf < 2) return self._da ? [UIFont systemFontOfSize:12] : nil;
    NSString *name = [t[tf - 2] hasPrefix:@"/"] ? [t[tf - 2] substringFromIndex:1] : t[tf - 2];
    CGFloat size = [t[tf - 1] doubleValue] ?: 12;
    if ([name isEqualToString:@"Helv"] || [name isEqualToString:@"Helvetica"]) name = @"Helvetica";
    else if ([name isEqualToString:@"TiRo"]) name = @"Times-Roman";
    else if ([name isEqualToString:@"Cour"]) name = @"Courier";
    return [UIFont fontWithName:name size:size] ?: [UIFont systemFontOfSize:size];
}
- (void)_setDA:(UIFont *)font color:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (color) [color getRed:&r green:&g blue:&b alpha:&a];
    NSString *name = [font.fontName stringByReplacingOccurrencesOfString:@" " withString:@""] ?: @"Helvetica";
    _values[PDFAnnotationKeyDefaultAppearance] = [NSString stringWithFormat:@"/%@ %@ Tf %@ %@ %@ rg", name, isim_pdf_number(font ? font.pointSize : 12),
                                                  isim_pdf_number(r), isim_pdf_number(g), isim_pdf_number(b)];
}
- (void)setFont:(UIFont *)font { [self _setDA:font ?: self.font color:self.fontColor]; }
- (UIColor *)fontColor {
    NSArray *t = [self._da componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSUInteger rg = [t indexOfObject:@"rg"], g = [t indexOfObject:@"g"];
    if (rg != NSNotFound && rg >= 3) return [UIColor colorWithRed:[t[rg - 3] doubleValue] green:[t[rg - 2] doubleValue] blue:[t[rg - 1] doubleValue] alpha:1];
    if (g != NSNotFound && g >= 1) return [UIColor colorWithWhite:[t[g - 1] doubleValue] alpha:1];
    return self._da ? [UIColor blackColor] : nil;
}
- (void)setFontColor:(UIColor *)color { [self _setDA:self.font color:color]; }
- (UIColor *)interiorColor { id v = _values[PDFAnnotationKeyInteriorColor]; return [v isKindOfClass:[UIColor class]] ? v : nil; }
- (void)setInteriorColor:(UIColor *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyInteriorColor]; }
- (NSTextAlignment)alignment {
    NSInteger q = [_values[PDFAnnotationKeyQuadding] integerValue];
    return q == 1 ? NSTextAlignmentCenter : q == 2 ? NSTextAlignmentRight : NSTextAlignmentLeft;
}
- (void)setAlignment:(NSTextAlignment)a {
    _values[PDFAnnotationKeyQuadding] = @(a == NSTextAlignmentCenter ? 1 : a == NSTextAlignmentRight ? 2 : 0);
}

/* ---- utilities: lines ---- */
- (NSArray<NSValue *> *)_linePoints {
    NSArray *l = _values[PDFAnnotationKeyLinePoints];
    return [l isKindOfClass:[NSArray class]] && l.count == 2 && [l[0] isKindOfClass:[NSValue class]] ? l : nil;
}
- (CGPoint)startPoint { return self._linePoints ? [self._linePoints[0] CGPointValue] : CGPointZero; }
- (CGPoint)endPoint { return self._linePoints ? [self._linePoints[1] CGPointValue] : CGPointZero; }
- (void)setStartPoint:(CGPoint)p { _values[PDFAnnotationKeyLinePoints] = @[ [NSValue valueWithCGPoint:p], [NSValue valueWithCGPoint:self.endPoint] ]; }
- (void)setEndPoint:(CGPoint)p { _values[PDFAnnotationKeyLinePoints] = @[ [NSValue valueWithCGPoint:self.startPoint], [NSValue valueWithCGPoint:p] ]; }
static NSString *const line_names[] = { @"/None", @"/Square", @"/Circle", @"/Diamond", @"/OpenArrow", @"/ClosedArrow" };
+ (PDFLineStyle)lineStyleFromName:(NSString *)name {
    if (![name hasPrefix:@"/"]) name = [@"/" stringByAppendingString:name ?: @""];
    for (int i = 0; i < 6; i++) if ([name isEqualToString:line_names[i]]) return i;
    return kPDFLineStyleNone;
}
+ (NSString *)nameForLineStyle:(PDFLineStyle)style { return [line_names[style >= 0 && style <= 5 ? style : 0] substringFromIndex:1]; }
- (NSArray *)_endings { NSArray *le = _values[PDFAnnotationKeyLineEndingStyles]; return [le isKindOfClass:[NSArray class]] && le.count == 2 ? le : @[ @"/None", @"/None" ]; }
- (PDFLineStyle)startLineStyle { return [PDFAnnotation lineStyleFromName:self._endings[0]]; }
- (PDFLineStyle)endLineStyle { return [PDFAnnotation lineStyleFromName:self._endings[1]]; }
- (void)setStartLineStyle:(PDFLineStyle)s { _values[PDFAnnotationKeyLineEndingStyles] = @[ line_names[s >= 0 && s <= 5 ? s : 0], self._endings[1] ]; }
- (void)setEndLineStyle:(PDFLineStyle)s { _values[PDFAnnotationKeyLineEndingStyles] = @[ self._endings[0], line_names[s >= 0 && s <= 5 ? s : 0] ]; }

/* ---- utilities: notes, markup, ink ---- */
static NSString *const icon_names[] = { @"/Comment", @"/Key", @"/Note", @"/Help", @"/NewParagraph", @"/Paragraph", @"/Insert" };
- (PDFTextAnnotationIconType)iconType {
    NSString *n = _values[PDFAnnotationKeyIconName];
    for (int i = 0; i < 7; i++) if ([n isEqual:icon_names[i]]) return i;
    return kPDFTextAnnotationIconNote;
}
- (void)setIconType:(PDFTextAnnotationIconType)t { _values[PDFAnnotationKeyIconName] = icon_names[t >= 0 && t <= 6 ? t : 2]; }
- (NSArray<NSValue *> *)quadrilateralPoints { id v = _values[PDFAnnotationKeyQuadPoints]; return [v isKindOfClass:[NSArray class]] ? v : nil; }
- (void)setQuadrilateralPoints:(NSArray<NSValue *> *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyQuadPoints]; }
- (PDFMarkupType)markupType {
    NSString *t = self.type;
    return [t isEqual:@"StrikeOut"] ? kPDFMarkupTypeStrikeOut : [t isEqual:@"Underline"] ? kPDFMarkupTypeUnderline
         : [t isEqual:@"Redact"] ? kPDFMarkupTypeRedact : kPDFMarkupTypeHighlight;
}
- (void)setMarkupType:(PDFMarkupType)m {
    NSString *const names[] = { PDFAnnotationSubtypeHighlight, PDFAnnotationSubtypeStrikeOut, PDFAnnotationSubtypeUnderline, @"/Redact" };
    _values[PDFAnnotationKeySubtype] = names[m >= 0 && m <= 3 ? m : 0];
}
- (NSArray<UIBezierPath *> *)paths { return _paths.count ? [_paths copy] : nil; }
- (void)addBezierPath:(UIBezierPath *)path {
    if (!path) return;
    if (!_paths) _paths = [NSMutableArray array];
    [_paths addObject:path];
}
- (void)removeBezierPath:(UIBezierPath *)path { [_paths removeObject:path]; }
- (BOOL)isOpen { return [_values[PDFAnnotationKeyOpen] boolValue]; }
- (void)setOpen:(BOOL)v { [self setBoolean:v forAnnotationKey:PDFAnnotationKeyOpen]; }
- (BOOL)isHighlighted { return _highlighted; }
- (NSString *)stampName {
    NSString *n = _values[PDFAnnotationKeyIconName];
    return [n isKindOfClass:[NSString class]] ? ([n hasPrefix:@"/"] ? [n substringFromIndex:1] : n) : nil;
}
- (void)setStampName:(NSString *)n { [self setValue:n ? [@"/" stringByAppendingString:n] : nil forAnnotationKey:PDFAnnotationKeyIconName]; }

/* ---- utilities: links ---- */
- (PDFDestination *)destination {
    id v = _values[PDFAnnotationKeyDestination];
    if ([v isKindOfClass:[PDFDestination class]]) return v;
    return [self.action isKindOfClass:[PDFActionGoTo class]] ? ((PDFActionGoTo *)self.action).destination : nil;
}
- (void)setDestination:(PDFDestination *)d { [self setValue:d forAnnotationKey:PDFAnnotationKeyDestination]; }
- (NSURL *)URL { return [self.action isKindOfClass:[PDFActionURL class]] ? ((PDFActionURL *)self.action).URL : nil; }
- (void)setURL:(NSURL *)url { self.action = url ? [[PDFActionURL alloc] initWithURL:url] : nil; }

/* ---- utilities: widgets ---- */
- (NSInteger)_ff { return [_values[PDFAnnotationKeyWidgetFieldFlags] integerValue]; }
- (void)_setFF:(NSInteger)f on:(BOOL)on { _values[PDFAnnotationKeyWidgetFieldFlags] = @(on ? (self._ff | f) : (self._ff & ~f)); }
- (PDFAnnotationWidgetSubtype)widgetFieldType { id v = _values[PDFAnnotationKeyWidgetFieldType]; return [v isKindOfClass:[NSString class]] ? v : PDFAnnotationWidgetSubtypeText; }
- (void)setWidgetFieldType:(PDFAnnotationWidgetSubtype)t { [self setValue:t forAnnotationKey:PDFAnnotationKeyWidgetFieldType]; }
- (PDFWidgetControlType)widgetControlType {
    if (![self.widgetFieldType isEqual:PDFAnnotationWidgetSubtypeButton]) return kPDFWidgetUnknownControl;
    NSInteger f = self._ff;
    return f & FF_PUSHBUTTON ? kPDFWidgetPushButtonControl : f & FF_RADIO ? kPDFWidgetRadioButtonControl : kPDFWidgetCheckBoxControl;
}
- (void)setWidgetControlType:(PDFWidgetControlType)t {
    [self _setFF:FF_PUSHBUTTON on:t == kPDFWidgetPushButtonControl];
    [self _setFF:FF_RADIO on:t == kPDFWidgetRadioButtonControl];
}
- (BOOL)isMultiline { return (self._ff & FF_MULTILINE) != 0; }
- (void)setMultiline:(BOOL)v { [self _setFF:FF_MULTILINE on:v]; }
- (BOOL)isPasswordField { return (self._ff & FF_PASSWORD) != 0; }
- (BOOL)hasComb { return (self._ff & FF_COMB) != 0; }
- (void)setComb:(BOOL)v { [self _setFF:FF_COMB on:v]; }
- (BOOL)isReadOnly { return (self._ff & FF_READONLY) != 0; }
- (void)setReadOnly:(BOOL)v { [self _setFF:FF_READONLY on:v]; }
- (BOOL)isListChoice { return [self.widgetFieldType isEqual:PDFAnnotationWidgetSubtypeChoice] && !(self._ff & FF_COMBO); }
- (void)setListChoice:(BOOL)v { [self _setFF:FF_COMBO on:!v]; }
- (BOOL)allowsToggleToOff { return !(self._ff & FF_NOTOGGLEOFF); }
- (void)setAllowsToggleToOff:(BOOL)v { [self _setFF:FF_NOTOGGLEOFF on:!v]; }
- (BOOL)radiosInUnison { return (self._ff & FF_UNISON) != 0; }
- (void)setRadiosInUnison:(BOOL)v { [self _setFF:FF_UNISON on:v]; }
- (BOOL)isActivatableTextField { return [self.type isEqual:@"Widget"] && [self.widgetFieldType isEqual:PDFAnnotationWidgetSubtypeText] && !self.isReadOnly; }
- (NSInteger)maximumLength { return [_values[PDFAnnotationKeyWidgetMaxLen] integerValue]; }
- (void)setMaximumLength:(NSInteger)n { _values[PDFAnnotationKeyWidgetMaxLen] = @(n); }
static NSString *plain(id v) {
    if ([v isKindOfClass:[NSArray class]]) v = [v firstObject];
    return [v isKindOfClass:[NSString class]] ? ([v hasPrefix:@"/"] ? [v substringFromIndex:1] : v) : nil;
}
- (NSString *)widgetStringValue { return plain(_values[PDFAnnotationKeyWidgetValue]); }
- (void)setWidgetStringValue:(NSString *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyWidgetValue]; }
- (NSString *)widgetDefaultStringValue { return plain(_values[PDFAnnotationKeyWidgetDefaultValue]); }
- (void)setWidgetDefaultStringValue:(NSString *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyWidgetDefaultValue]; }
- (NSArray<NSString *> *)choices { id v = _values[PDFAnnotationKeyWidgetOptions]; return [v isKindOfClass:[NSArray class]] ? v : nil; }
- (void)setChoices:(NSArray<NSString *> *)v { [self setValue:v forAnnotationKey:PDFAnnotationKeyWidgetOptions]; }
- (NSArray<NSString *> *)values {
    id v = _values[PDFAnnotationKeyWidgetValue];
    if ([v isKindOfClass:[NSArray class]]) return v;
    return plain(v) ? @[ plain(v) ] : nil;
}
- (void)setValues:(NSArray<NSString *> *)v { [self setValue:v.count == 1 ? v[0] : v forAnnotationKey:PDFAnnotationKeyWidgetValue]; }
- (NSString *)buttonWidgetStateString { return _onState ?: @"Yes"; }
- (void)setButtonWidgetStateString:(NSString *)s { _onState = [s hasPrefix:@"/"] ? [s substringFromIndex:1] : [s copy]; }
- (PDFWidgetCellState)buttonWidgetState {
    NSString *as = plain(_values[PDFAnnotationKeyAppearanceState]) ?: plain(_values[PDFAnnotationKeyWidgetValue]);
    return !as || [as isEqual:@"Off"] ? kPDFWidgetOffState : kPDFWidgetOnState;
}
- (void)setButtonWidgetState:(PDFWidgetCellState)s {
    NSString *name = [@"/" stringByAppendingString:s == kPDFWidgetOffState ? @"Off" : self.buttonWidgetStateString];
    _values[PDFAnnotationKeyAppearanceState] = name;
    _values[PDFAnnotationKeyWidgetValue] = name;
}
- (NSString *)fieldName { return self.userName; }
- (void)setFieldName:(NSString *)v { self.userName = v; }
- (PDFAppearanceCharacteristics *)_mk {
    id v = _values[PDFAnnotationKeyWidgetAppearanceDictionary];
    if ([v isKindOfClass:[PDFAppearanceCharacteristics class]]) return v;
    PDFAppearanceCharacteristics *mk = [[PDFAppearanceCharacteristics alloc] init];
    _values[PDFAnnotationKeyWidgetAppearanceDictionary] = mk;
    return mk;
}
- (NSString *)caption {
    id mk = _values[PDFAnnotationKeyWidgetAppearanceDictionary];
    return [mk isKindOfClass:[PDFAppearanceCharacteristics class]] ? ((PDFAppearanceCharacteristics *)mk).caption : nil;
}
- (void)setCaption:(NSString *)v { self._mk.caption = v; }
- (UIColor *)backgroundColor {
    id mk = _values[PDFAnnotationKeyWidgetAppearanceDictionary];
    return [mk isKindOfClass:[PDFAppearanceCharacteristics class]] ? ((PDFAppearanceCharacteristics *)mk).backgroundColor : nil;
}
- (void)setBackgroundColor:(UIColor *)v { self._mk.backgroundColor = v; }

/* ================= reading ================= */
static id pdf_value(CGPDFObjectRef o, int depth) {
    CGPDFBoolean b; CGPDFInteger i; CGPDFReal r; const char *name; CGPDFStringRef s; CGPDFArrayRef a;
    switch (CGPDFObjectGetType(o)) {
        case kCGPDFObjectTypeBoolean: return CGPDFObjectGetValue(o, kCGPDFObjectTypeBoolean, &b) ? @(b != 0) : nil;
        case kCGPDFObjectTypeInteger: return CGPDFObjectGetValue(o, kCGPDFObjectTypeInteger, &i) ? @(i) : nil;
        case kCGPDFObjectTypeReal: return CGPDFObjectGetValue(o, kCGPDFObjectTypeReal, &r) ? @(r) : nil;
        case kCGPDFObjectTypeName: return CGPDFObjectGetValue(o, kCGPDFObjectTypeName, &name) ? [@"/" stringByAppendingString:@(name)] : nil;
        case kCGPDFObjectTypeString: return CGPDFObjectGetValue(o, kCGPDFObjectTypeString, &s) ? CFBridgingRelease(CGPDFStringCopyTextString(s)) : nil;
        case kCGPDFObjectTypeArray: {
            if (!CGPDFObjectGetValue(o, kCGPDFObjectTypeArray, &a) || depth > 4) return nil;
            NSMutableArray *out = [NSMutableArray array];
            for (size_t k = 0; k < CGPDFArrayGetCount(a); k++) {
                CGPDFObjectRef e; id v = CGPDFArrayGetObject(a, k, &e) ? pdf_value(e, depth + 1) : nil;
                if (v) [out addObject:v];
            }
            return out;
        }
        default: return nil;
    }
}
static CGRect pdf_rect(CGPDFArrayRef a) {
    CGPDFReal v[4] = {0};
    for (size_t i = 0; i < 4; i++) CGPDFArrayGetNumber(a, i, &v[i]);
    return CGRectStandardize(CGRectMake(v[0], v[1], v[2] - v[0], v[3] - v[1]));
}
static PDFBorder *read_border(CGPDFDictionaryRef d) {
    CGPDFDictionaryRef bs; CGPDFArrayRef arr;
    PDFBorder *b = nil;
    if (CGPDFDictionaryGetDictionary(d, "BS", &bs)) {
        b = [[PDFBorder alloc] init];
        CGPDFReal w; const char *s; CGPDFArrayRef dash;
        if (CGPDFDictionaryGetNumber(bs, "W", &w)) b.lineWidth = w;
        if (CGPDFDictionaryGetName(bs, "S", &s))
            b.style = *s == 'D' ? kPDFBorderStyleDashed : *s == 'B' ? kPDFBorderStyleBeveled : *s == 'I' ? kPDFBorderStyleInset
                    : *s == 'U' ? kPDFBorderStyleUnderline : kPDFBorderStyleSolid;
        if (CGPDFDictionaryGetArray(bs, "D", &dash)) {
            NSMutableArray *p = [NSMutableArray array];
            for (size_t i = 0; i < CGPDFArrayGetCount(dash); i++) { CGPDFReal v; if (CGPDFArrayGetNumber(dash, i, &v)) [p addObject:@(v)]; }
            b.dashPattern = p;
        }
    } else if (CGPDFDictionaryGetArray(d, "Border", &arr)) {
        b = [[PDFBorder alloc] init];
        CGPDFReal w = 1; CGPDFArrayRef dash;
        CGPDFArrayGetNumber(arr, 2, &w);
        b.lineWidth = w;
        if (CGPDFArrayGetArray(arr, 3, &dash)) {
            NSMutableArray *p = [NSMutableArray array];
            for (size_t i = 0; i < CGPDFArrayGetCount(dash); i++) { CGPDFReal v; if (CGPDFArrayGetNumber(dash, i, &v)) [p addObject:@(v)]; }
            b.dashPattern = p; b.style = kPDFBorderStyleDashed;
        }
    }
    return b;
}
/* a widget's field attribute: its own or its parent field's */
static CGPDFObjectRef field_attr(CGPDFDictionaryRef d, const char *key) {
    for (int depth = 0; d && depth < 16; depth++) {
        CGPDFObjectRef o;
        if (CGPDFDictionaryGetObject(d, key, &o)) return o;
        if (!CGPDFDictionaryGetDictionary(d, "Parent", &d)) break;
    }
    return NULL;
}
static NSString *field_name(CGPDFDictionaryRef d) {
    NSMutableArray *parts = [NSMutableArray array];
    for (int depth = 0; d && depth < 16; depth++) {
        CGPDFStringRef t;
        if (CGPDFDictionaryGetString(d, "T", &t)) [parts insertObject:CFBridgingRelease(CGPDFStringCopyTextString(t)) atIndex:0];
        if (!CGPDFDictionaryGetDictionary(d, "Parent", &d)) break;
    }
    return parts.count ? [parts componentsJoinedByString:@"."] : nil;
}
- (instancetype)_initWithIsimDictionary:(CGPDFDictionaryRef)d page:(PDFPage *)page {
    const char *sub = "Text";
    CGPDFDictionaryGetName(d, "Subtype", &sub);
    CGPDFArrayRef rect;
    CGRect bounds = CGPDFDictionaryGetArray(d, "Rect", &rect) ? pdf_rect(rect) : CGRectZero;
    if (!(self = [self initWithBounds:bounds forType:[@"/" stringByAppendingString:@(sub)] withProperties:nil])) return nil;
    _source = d;
    _page = page;
    [_values removeObjectForKey:PDFAnnotationKeyFlags];
    CGPDFInteger flags; if (CGPDFDictionaryGetInteger(d, "F", &flags)) _values[PDFAnnotationKeyFlags] = @(flags);
    const char *simple[] = { "Contents", "NM", "T", "DA", "Q", "Name", "Open", "H", "AS", "TU", "MaxLen", "RC", "IT", "Subj", "CA" };
    for (size_t i = 0; i < sizeof simple / sizeof *simple; i++) {
        CGPDFObjectRef o; id v = CGPDFDictionaryGetObject(d, simple[i], &o) ? pdf_value(o, 0) : nil;
        if (v) _values[[@"/" stringByAppendingString:@(simple[i])]] = v;
    }
    CGPDFStringRef ms;
    if (CGPDFDictionaryGetString(d, "M", &ms)) { NSDate *m = CFBridgingRelease(CGPDFStringCopyDate(ms)); if (m) _values[PDFAnnotationKeyDate] = m; }
    CGPDFArrayRef a;
    if (CGPDFDictionaryGetArray(d, "C", &a)) { UIColor *c = isim_pdf_color(a); if (c) _values[PDFAnnotationKeyColor] = c; }
    if (CGPDFDictionaryGetArray(d, "IC", &a)) { UIColor *c = isim_pdf_color(a); if (c) _values[PDFAnnotationKeyInteriorColor] = c; }
    PDFBorder *b = read_border(d);
    if (b) _values[PDFAnnotationKeyBorder] = b;
    CGPDFDictionaryRef action; CGPDFObjectRef dest;
    if (CGPDFDictionaryGetDictionary(d, "A", &action)) { PDFAction *act = [page.document _isim_actionForDictionary:action]; if (act) _values[PDFAnnotationKeyAction] = act; }
    if (CGPDFDictionaryGetObject(d, "Dest", &dest)) { PDFDestination *ds = [page.document _isim_destinationForObject:dest]; if (ds) _values[PDFAnnotationKeyDestination] = ds; }
    CGPoint o = bounds.origin;
    if (CGPDFDictionaryGetArray(d, "QuadPoints", &a)) {
        NSMutableArray *pts = [NSMutableArray array];
        for (size_t i = 0; i + 1 < CGPDFArrayGetCount(a); i += 2) {
            CGPDFReal x = 0, y = 0; CGPDFArrayGetNumber(a, i, &x); CGPDFArrayGetNumber(a, i + 1, &y);
            [pts addObject:[NSValue valueWithCGPoint:CGPointMake(x - o.x, y - o.y)]];
        }
        _values[PDFAnnotationKeyQuadPoints] = pts;
    }
    if (CGPDFDictionaryGetArray(d, "L", &a) && CGPDFArrayGetCount(a) >= 4) {
        CGPDFReal v[4] = {0};
        for (size_t i = 0; i < 4; i++) CGPDFArrayGetNumber(a, i, &v[i]);
        _values[PDFAnnotationKeyLinePoints] = @[ [NSValue valueWithCGPoint:CGPointMake(v[0] - o.x, v[1] - o.y)],
                                                 [NSValue valueWithCGPoint:CGPointMake(v[2] - o.x, v[3] - o.y)] ];
    }
    CGPDFObjectRef leo;
    if (CGPDFDictionaryGetObject(d, "LE", &leo)) {
        NSArray *le = pdf_value(leo, 0);
        if ([le isKindOfClass:[NSArray class]] && le.count == 2) _values[PDFAnnotationKeyLineEndingStyles] = le;
    }
    if (CGPDFDictionaryGetArray(d, "InkList", &a)) {
        _paths = [NSMutableArray array];
        for (size_t i = 0; i < CGPDFArrayGetCount(a); i++) {
            CGPDFArrayRef stroke;
            if (!CGPDFArrayGetArray(a, i, &stroke)) continue;
            UIBezierPath *p = [UIBezierPath bezierPath];
            for (size_t k = 0; k + 1 < CGPDFArrayGetCount(stroke); k += 2) {
                CGPDFReal x = 0, y = 0; CGPDFArrayGetNumber(stroke, k, &x); CGPDFArrayGetNumber(stroke, k + 1, &y);
                CGPoint pt = CGPointMake(x - o.x, y - o.y);
                if (k == 0) [p moveToPoint:pt]; else [p addLineToPoint:pt];
            }
            [_paths addObject:p];
        }
    }
    if (!strcmp(sub, "Widget")) {
        const char *inherited[] = { "FT", "V", "DV", "Ff", "Opt", "DA", "Q", "MaxLen" };
        for (size_t i = 0; i < sizeof inherited / sizeof *inherited; i++) {
            CGPDFObjectRef fo = field_attr(d, inherited[i]);
            id v = fo ? pdf_value(fo, 0) : nil;
            if ([v isKindOfClass:[NSArray class]] && !strcmp(inherited[i], "Opt")) {            /* [export display] pairs */
                NSMutableArray *names = [NSMutableArray array];
                for (id e in v) [names addObject:[e isKindOfClass:[NSArray class]] ? ([e lastObject] ?: @"") : e];
                v = names;
            }
            if (v) _values[[@"/" stringByAppendingString:@(inherited[i])]] = v;
        }
        NSString *name = field_name(d);
        if (name) _values[PDFAnnotationKeyTextLabel] = name;
        CGPDFDictionaryRef mk;
        if (CGPDFDictionaryGetDictionary(d, "MK", &mk)) {
            PDFAppearanceCharacteristics *m = [[PDFAppearanceCharacteristics alloc] init];
            if (CGPDFDictionaryGetArray(mk, "BG", &a)) m.backgroundColor = isim_pdf_color(a);
            if (CGPDFDictionaryGetArray(mk, "BC", &a)) m.borderColor = isim_pdf_color(a);
            CGPDFInteger r; if (CGPDFDictionaryGetInteger(mk, "R", &r)) m.rotation = r;
            CGPDFStringRef s;
            if (CGPDFDictionaryGetString(mk, "CA", &s)) m.caption = CFBridgingRelease(CGPDFStringCopyTextString(s));
            if (CGPDFDictionaryGetString(mk, "RC", &s)) m.rolloverCaption = CFBridgingRelease(CGPDFStringCopyTextString(s));
            if (CGPDFDictionaryGetString(mk, "AC", &s)) m.downCaption = CFBridgingRelease(CGPDFStringCopyTextString(s));
            m.controlType = self.widgetControlType;
            _values[PDFAnnotationKeyWidgetAppearanceDictionary] = m;
        }
        CGPDFDictionaryRef ap, normal;                           /* a button's on state: the normal appearance not named Off */
        if (CGPDFDictionaryGetDictionary(d, "AP", &ap) && CGPDFDictionaryGetDictionary(ap, "N", &normal)) {
            __block NSString *on = nil;
            CGPDFDictionaryApplyBlock(normal, ^bool(const char *key, CGPDFObjectRef value, void *info) {
                if (strcmp(key, "Off")) { on = @(key); return false; }
                return true;
            }, NULL);
            if (on) _onState = on;
        }
    }
    _pristine = [_values copy];
    _pristinePaths = _paths.count;
    return self;
}

/* ================= drawing ================= */
static UIColor *or_default(UIColor *c, UIColor *def) {
    CGFloat a = 1;
    if (!c) return def;
    [c getRed:NULL green:NULL blue:NULL alpha:&a];
    return a > 0 ? c : def;
}
static void draw_text(CGContextRef c, NSString *text, CGRect box, UIFont *font, UIColor *color, NSTextAlignment align, BOOL top) {
    if (!text.length) return;
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = align;
    NSDictionary *attrs = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: ps };
    CGRect r = [text boundingRectWithSize:CGSizeMake(box.size.width, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:attrs context:nil];
    CGFloat h = MIN(ceil(r.size.height), box.size.height);
    CGFloat y = top ? 0 : (box.size.height - h) / 2;                  /* from the top of the box */
    CGContextSaveGState(c);
    CGContextClipToRect(c, box);
    CGContextTranslateCTM(c, box.origin.x, CGRectGetMaxY(box));       /* UIKit's text draws y-down */
    CGContextScaleCTM(c, 1, -1);
    UIGraphicsPushContext(c);
    [text drawWithRect:CGRectMake(0, y, box.size.width, box.size.height - y) options:NSStringDrawingUsesLineFragmentOrigin attributes:attrs context:nil];
    UIGraphicsPopContext();
    CGContextRestoreGState(c);
}
static void line_ending(CGContextRef c, CGPoint at, CGPoint from, PDFLineStyle style, CGFloat w, UIColor *fill) {
    if (style == kPDFLineStyleNone) return;
    CGFloat ang = atan2(at.y - from.y, at.x - from.x), s = MAX(3 * w, 6);
    CGContextSaveGState(c);
    CGContextTranslateCTM(c, at.x, at.y);
    CGContextRotateCTM(c, ang);
    CGMutablePathRef p = CGPathCreateMutable();
    switch (style) {
        case kPDFLineStyleSquare: CGPathAddRect(p, NULL, CGRectMake(-s / 2, -s / 2, s, s)); break;
        case kPDFLineStyleCircle: CGPathAddEllipseInRect(p, NULL, CGRectMake(-s / 2, -s / 2, s, s)); break;
        case kPDFLineStyleDiamond:
            CGPathMoveToPoint(p, NULL, s / 2, 0); CGPathAddLineToPoint(p, NULL, 0, s / 2);
            CGPathAddLineToPoint(p, NULL, -s / 2, 0); CGPathAddLineToPoint(p, NULL, 0, -s / 2); CGPathCloseSubpath(p); break;
        case kPDFLineStyleOpenArrow: case kPDFLineStyleClosedArrow:
            CGPathMoveToPoint(p, NULL, -s, s / 2); CGPathAddLineToPoint(p, NULL, 0, 0); CGPathAddLineToPoint(p, NULL, -s, -s / 2);
            if (style == kPDFLineStyleClosedArrow) CGPathCloseSubpath(p);
            break;
        default: break;
    }
    CGContextAddPath(c, p);
    if (style != kPDFLineStyleOpenArrow && fill) { CGContextSetFillColorWithColor(c, fill.CGColor); CGContextDrawPath(c, kCGPathFillStroke); }
    else CGContextStrokePath(c);
    CGPathRelease(p);
    CGContextRestoreGState(c);
}
- (void)drawWithBox:(PDFDisplayBox)box inContext:(CGContextRef)c {
    if (!c || !self.shouldDisplay) return;
    NSString *t = self.type;
    CGRect b = self.bounds;
    UIColor *color = _values[PDFAnnotationKeyColor];
    CGFloat width = self.border ? self.border.lineWidth : 1;
    CGContextSaveGState(c);
    if ([t isEqual:@"Highlight"] || [t isEqual:@"Underline"] || [t isEqual:@"StrikeOut"] || [t isEqual:@"Redact"]) {
        NSArray<NSValue *> *q = self.quadrilateralPoints;
        if (!q.count) q = @[ [NSValue valueWithCGPoint:CGPointMake(0, b.size.height)], [NSValue valueWithCGPoint:CGPointMake(b.size.width, b.size.height)],
                             [NSValue valueWithCGPoint:CGPointZero], [NSValue valueWithCGPoint:CGPointMake(b.size.width, 0)] ];
        for (NSUInteger i = 0; i + 3 < q.count; i += 4) {
            CGPoint p[4];                                             /* upper left, upper right, lower left, lower right */
            for (int k = 0; k < 4; k++) { CGPoint r = [q[i + k] CGPointValue]; p[k] = CGPointMake(r.x + b.origin.x, r.y + b.origin.y); }
            CGFloat h = hypot(p[0].x - p[2].x, p[0].y - p[2].y);
            if ([t isEqual:@"Highlight"]) {
                CGContextSetBlendMode(c, kCGBlendModeMultiply);
                CGContextSetFillColorWithColor(c, or_default(color, [UIColor colorWithRed:1 green:0.9 blue:0.25 alpha:1]).CGColor);
                CGContextMoveToPoint(c, p[0].x, p[0].y); CGContextAddLineToPoint(c, p[1].x, p[1].y);
                CGContextAddLineToPoint(c, p[3].x, p[3].y); CGContextAddLineToPoint(c, p[2].x, p[2].y);
                CGContextFillPath(c);
            } else if ([t isEqual:@"Redact"]) {
                CGContextSetStrokeColorWithColor(c, or_default(color, [UIColor redColor]).CGColor);
                CGContextMoveToPoint(c, p[0].x, p[0].y); CGContextAddLineToPoint(c, p[1].x, p[1].y);
                CGContextAddLineToPoint(c, p[3].x, p[3].y); CGContextAddLineToPoint(c, p[2].x, p[2].y);
                CGContextClosePath(c); CGContextStrokePath(c);
            } else {
                CGFloat f = [t isEqual:@"Underline"] ? 0.08 : 0.5;    /* along the bottom, or through the middle */
                CGContextSetStrokeColorWithColor(c, or_default(color, [t isEqual:@"Underline"] ? [UIColor blueColor] : [UIColor redColor]).CGColor);
                CGContextSetLineWidth(c, MAX(1, h / 14));
                CGContextMoveToPoint(c, p[2].x + (p[0].x - p[2].x) * f, p[2].y + (p[0].y - p[2].y) * f);
                CGContextAddLineToPoint(c, p[3].x + (p[1].x - p[3].x) * f, p[3].y + (p[1].y - p[3].y) * f);
                CGContextStrokePath(c);
            }
        }
    } else if ([t isEqual:@"Ink"]) {
        CGContextSetStrokeColorWithColor(c, or_default(color, [UIColor blackColor]).CGColor);
        CGContextSetLineWidth(c, width);
        CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
        CGContextTranslateCTM(c, b.origin.x, b.origin.y);
        for (UIBezierPath *p in _paths) { CGContextAddPath(c, p.CGPath); CGContextStrokePath(c); }
    } else if ([t isEqual:@"Square"] || [t isEqual:@"Circle"]) {
        CGRect r = CGRectInset(b, width / 2, width / 2);
        if (self.interiorColor) {
            CGContextSetFillColorWithColor(c, self.interiorColor.CGColor);
            if ([t isEqual:@"Square"]) CGContextFillRect(c, r); else CGContextFillEllipseInRect(c, r);
        }
        if (width > 0 && or_default(color, nil)) {
            CGContextSetStrokeColorWithColor(c, color.CGColor);
            CGContextSetLineWidth(c, width);
            if (self.border.style == kPDFBorderStyleDashed) { CGFloat d[] = { 3 }; CGContextSetLineDash(c, 0, d, 1); }
            if ([t isEqual:@"Square"]) CGContextStrokeRect(c, r); else CGContextStrokeEllipseInRect(c, r);
        }
    } else if ([t isEqual:@"Line"]) {
        CGPoint s = self.startPoint, e = self.endPoint;
        s.x += b.origin.x; s.y += b.origin.y; e.x += b.origin.x; e.y += b.origin.y;
        CGContextSetStrokeColorWithColor(c, or_default(color, [UIColor blackColor]).CGColor);
        CGContextSetLineWidth(c, width);
        CGContextMoveToPoint(c, s.x, s.y); CGContextAddLineToPoint(c, e.x, e.y); CGContextStrokePath(c);
        line_ending(c, s, e, self.startLineStyle, width, self.interiorColor ?: color);
        line_ending(c, e, s, self.endLineStyle, width, self.interiorColor ?: color);
    } else if ([t isEqual:@"Text"]) {
        CGRect r = CGRectMake(b.origin.x, CGRectGetMaxY(b) - MIN(20, b.size.height), MIN(20, b.size.width), MIN(20, b.size.height));
        UIBezierPath *bubble = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(r, 1, 1) cornerRadius:3];
        CGContextSetFillColorWithColor(c, or_default(color, [UIColor colorWithRed:1 green:0.85 blue:0.2 alpha:1]).CGColor);
        CGContextAddPath(c, bubble.CGPath); CGContextFillPath(c);
        CGContextSetStrokeColorWithColor(c, [UIColor colorWithWhite:0 alpha:0.55].CGColor);
        CGContextSetLineWidth(c, 1);
        CGContextAddPath(c, bubble.CGPath); CGContextStrokePath(c);
        for (int i = 0; i < 3; i++) {                                     /* the note's lines */
            CGFloat y = CGRectGetMaxY(r) - 6 - i * 4;
            CGContextMoveToPoint(c, r.origin.x + 5, y); CGContextAddLineToPoint(c, CGRectGetMaxX(r) - 5, y);
        }
        CGContextStrokePath(c);
    } else if ([t isEqual:@"FreeText"]) {
        if (self.interiorColor) { CGContextSetFillColorWithColor(c, self.interiorColor.CGColor); CGContextFillRect(c, b); }
        if (self.border && self.border.lineWidth > 0) {
            CGContextSetStrokeColorWithColor(c, or_default(color, [UIColor blackColor]).CGColor);
            [self.border _isim_stroke:c rect:b];
        }
        draw_text(c, self.contents, CGRectInset(b, 2, 2), self.font ?: [UIFont fontWithName:@"Helvetica" size:12] ?: [UIFont systemFontOfSize:12],
                  self.fontColor ?: [UIColor blackColor], self.alignment, YES);
    } else if ([t isEqual:@"Stamp"]) {
        UIColor *sc = or_default(color, [UIColor colorWithRed:0.8 green:0.1 blue:0.1 alpha:1]);
        UIBezierPath *frame = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(b, 2, 2) cornerRadius:6];
        CGContextSetStrokeColorWithColor(c, sc.CGColor);
        CGContextSetLineWidth(c, 3);
        CGContextAddPath(c, frame.CGPath); CGContextStrokePath(c);
        NSString *name = self.stampName ?: @"Draft";
        CGFloat size = MAX(6, MIN(b.size.height * 0.5, b.size.width / MAX(name.length, 1) * 1.4));
        draw_text(c, name.uppercaseString, CGRectInset(b, 4, 2), [UIFont boldSystemFontOfSize:size], sc, NSTextAlignmentCenter, NO);
    } else if ([t isEqual:@"Link"]) {
        if (self.border && self.border.lineWidth > 0 && or_default(color, nil)) {
            CGContextSetStrokeColorWithColor(c, color.CGColor);
            [self.border _isim_stroke:c rect:b];
        }
    } else if ([t isEqual:@"Widget"]) {
        [self _drawWidget:c];
    }
    if (_highlighted) {
        CGContextSetFillColorWithColor(c, [UIColor colorWithRed:0.2 green:0.45 blue:1 alpha:0.18].CGColor);
        CGContextFillRect(c, b);
    }
    CGContextRestoreGState(c);
}
- (void)_drawWidget:(CGContextRef)c {
    CGRect b = self.bounds;
    PDFAppearanceCharacteristics *mk = _values[PDFAnnotationKeyWidgetAppearanceDictionary];
    if (mk.backgroundColor) { CGContextSetFillColorWithColor(c, mk.backgroundColor.CGColor); CGContextFillRect(c, b); }
    CGFloat bw = self.border ? self.border.lineWidth : 1;
    if (mk.borderColor && bw > 0) {
        CGContextSetStrokeColorWithColor(c, mk.borderColor.CGColor);
        [self.border ?: [[PDFBorder alloc] init] _isim_stroke:c rect:b];
    }
    UIFont *font = self.font;
    CGFloat size = font.pointSize > 0 ? font.pointSize : 0;
    UIColor *fc = self.fontColor ?: [UIColor blackColor];
    PDFAnnotationWidgetSubtype ft = self.widgetFieldType;
    CGRect inner = CGRectInset(b, MAX(bw, 1) + 1, MAX(bw, 1));
    if ([ft isEqual:PDFAnnotationWidgetSubtypeButton]) {
        PDFWidgetControlType ct = self.widgetControlType;
        if (ct == kPDFWidgetPushButtonControl) {
            draw_text(c, mk.caption, inner, [UIFont systemFontOfSize:size ?: MIN(12, b.size.height * 0.6)], fc, NSTextAlignmentCenter, NO);
        } else if (self.buttonWidgetState == kPDFWidgetOnState) {
            CGFloat s = MIN(b.size.width, b.size.height) * 0.7;
            CGRect r = CGRectMake(CGRectGetMidX(b) - s / 2, CGRectGetMidY(b) - s / 2, s, s);
            CGContextSetFillColorWithColor(c, fc.CGColor); CGContextSetStrokeColorWithColor(c, fc.CGColor);
            if (ct == kPDFWidgetRadioButtonControl) CGContextFillEllipseInRect(c, CGRectInset(r, s * 0.18, s * 0.18));
            else {                                                    /* a check mark */
                CGContextSetLineWidth(c, MAX(1.2, s * 0.14));
                CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
                CGContextMoveToPoint(c, r.origin.x + s * 0.1, r.origin.y + s * 0.5);
                CGContextAddLineToPoint(c, r.origin.x + s * 0.4, r.origin.y + s * 0.15);
                CGContextAddLineToPoint(c, r.origin.x + s * 0.92, r.origin.y + s * 0.88);
                CGContextStrokePath(c);
            }
        }
        return;
    }
    NSString *text = [ft isEqual:PDFAnnotationWidgetSubtypeChoice] && self.isListChoice ? nil : self.widgetStringValue;
    if (!size) size = self.isMultiline ? 12 : MAX(6, MIN(12, inner.size.height * 0.75));
    UIFont *f = font && font.pointSize > 0 ? font : [UIFont fontWithName:font.fontName ?: @"Helvetica" size:size] ?: [UIFont systemFontOfSize:size];
    if (self.isPasswordField && text) text = [@"" stringByPaddingToLength:text.length withString:@"•" startingAtIndex:0];
    if ([ft isEqual:PDFAnnotationWidgetSubtypeChoice] && self.isListChoice) {            /* the options, the chosen ones marked */
        CGFloat lh = f.lineHeight, y = CGRectGetMaxY(inner);
        NSArray *chosen = self.values;
        for (NSString *opt in self.choices) {
            CGRect line = CGRectMake(inner.origin.x, y - lh, inner.size.width, lh);
            if (line.origin.y < b.origin.y) break;
            if ([chosen containsObject:opt]) { CGContextSetFillColorWithColor(c, [UIColor colorWithRed:0.6 green:0.75 blue:1 alpha:1].CGColor); CGContextFillRect(c, line); }
            draw_text(c, opt, line, f, fc, NSTextAlignmentLeft, YES);
            y -= lh;
        }
        return;
    }
    if (self.hasComb && self.maximumLength > 0 && text.length) {
        CGFloat cell = b.size.width / self.maximumLength;
        for (NSUInteger i = 0; i < text.length && i < (NSUInteger)self.maximumLength; i++)
            draw_text(c, [text substringWithRange:NSMakeRange(i, 1)], CGRectMake(b.origin.x + i * cell, inner.origin.y, cell, inner.size.height), f, fc, NSTextAlignmentCenter, NO);
        return;
    }
    draw_text(c, text, inner, f, fc, self.alignment, self.isMultiline);
}

/* ================= writing ================= */
static NSString *value_source(id v, PDFAnnotation *me, NSArray<PDFAnnotation *> *all) {
    if ([v isKindOfClass:[NSString class]]) return [v hasPrefix:@"/"] ? isim_pdf_name(v) : isim_pdf_string_literal(v);
    if ([v isKindOfClass:[NSNumber class]]) {
        if (CFGetTypeID((__bridge CFTypeRef)v) == CFBooleanGetTypeID()) return [v boolValue] ? @"true" : @"false";
        return isim_pdf_number([v doubleValue]);
    }
    if ([v isKindOfClass:[NSDate class]]) return pdf_date(v);
    if ([v isKindOfClass:[UIColor class]]) return isim_pdf_color_array(v);
    if ([v isKindOfClass:[PDFAnnotation class]]) {
        NSUInteger i = [all indexOfObjectIdenticalTo:v];
        return i == NSNotFound ? nil : [NSString stringWithFormat:@"@A%lu@", (unsigned long)i];
    }
    if ([v isKindOfClass:[NSArray class]]) {
        NSMutableString *s = [NSMutableString stringWithString:@"["];
        for (id e in v) { NSString *es = value_source(e, me, all); if (es) [s appendFormat:@" %@", es]; }
        [s appendString:@" ]"];
        return s;
    }
    return nil;
}
struct ink_points { __unsafe_unretained NSMutableString *out; CGAffineTransform t; };
static void ink_point(void *info, const CGPathElement *e) {               /* the end point of each segment */
    struct ink_points *ctx = info;
    int n = e->type == kCGPathElementAddQuadCurveToPoint ? 2 : e->type == kCGPathElementAddCurveToPoint ? 3
          : e->type == kCGPathElementCloseSubpath ? 0 : 1;
    if (!n) return;
    CGPoint p = CGPointApplyAffineTransform(e->points[n - 1], ctx->t);
    [ctx->out appendFormat:@" %@ %@", isim_pdf_number(p.x), isim_pdf_number(p.y)];
}
- (NSString *)_isim_pdfSourceWithTransform:(CGAffineTransform)t pages:(NSArray<PDFPage *> *)pages all:(NSArray<PDFAnnotation *> *)all {
    NSMutableString *s = [NSMutableString stringWithString:@"<< /Type /Annot"];
    CGRect b = self.bounds;
    CGPoint o = b.origin;
    CGAffineTransform (^pageTransform)(PDFPage *) = ^CGAffineTransform(PDFPage *p) { return [p transformForBox:kPDFDisplayBoxCropBox]; };
    NSArray *skip = @[ PDFAnnotationKeyRect, PDFAnnotationKeyQuadPoints, PDFAnnotationKeyLinePoints, PDFAnnotationKeyBorder,
                       PDFAnnotationKeyAction, PDFAnnotationKeyDestination, PDFAnnotationKeyParent, PDFAnnotationKeyPage,
                       PDFAnnotationKeyAppearanceDictionary, PDFAnnotationKeyWidgetAppearanceDictionary, PDFAnnotationKeyBorderStyle,
                       PDFAnnotationKeyAdditionalActions, PDFAnnotationKeyInklist, PDFAnnotationKeyDate ];
    [s appendFormat:@" /Rect %@", rect_array(transform_rect(b, t))];
    for (NSString *k in [_values.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if ([skip containsObject:k]) continue;
        NSString *v = value_source(_values[k], self, all);
        if (v) [s appendFormat:@" %@ %@", isim_pdf_name(k), v];
    }
    if (self.modificationDate) [s appendFormat:@" /M %@", pdf_date(self.modificationDate)];
    NSUInteger page = self.page ? [pages indexOfObjectIdenticalTo:self.page] : NSNotFound;
    if (page != NSNotFound) [s appendFormat:@" /P @P%lu@", (unsigned long)page];
    PDFAnnotation *parent = self._parentAnnotation;
    NSUInteger pi = parent ? [all indexOfObjectIdenticalTo:parent] : NSNotFound;
    if (pi != NSNotFound) [s appendFormat:@" /Parent @A%lu@", (unsigned long)pi];
    NSArray<NSValue *> *q = self.quadrilateralPoints;
    if (q.count) {
        [s appendString:@" /QuadPoints ["];
        for (NSValue *v in q) {
            CGPoint p = CGPointApplyAffineTransform(CGPointMake(v.CGPointValue.x + o.x, v.CGPointValue.y + o.y), t);
            [s appendFormat:@" %@ %@", isim_pdf_number(p.x), isim_pdf_number(p.y)];
        }
        [s appendString:@" ]"];
    }
    if (self._linePoints) {
        CGPoint a = CGPointApplyAffineTransform(CGPointMake(self.startPoint.x + o.x, self.startPoint.y + o.y), t);
        CGPoint e = CGPointApplyAffineTransform(CGPointMake(self.endPoint.x + o.x, self.endPoint.y + o.y), t);
        [s appendFormat:@" /L [%@ %@ %@ %@]", isim_pdf_number(a.x), isim_pdf_number(a.y), isim_pdf_number(e.x), isim_pdf_number(e.y)];
    }
    if (_paths.count) {
        [s appendString:@" /InkList ["];
        CGAffineTransform pt = CGAffineTransformConcat(CGAffineTransformMakeTranslation(o.x, o.y), t);
        for (UIBezierPath *path in _paths) {
            NSMutableString *stroke = [NSMutableString stringWithString:@" ["];
            struct ink_points ctx = { stroke, pt };
            CGPathApply(path.CGPath, &ctx, ink_point);
            [stroke appendString:@" ]"];
            [s appendString:stroke];
        }
        [s appendString:@" ]"];
    }
    PDFBorder *border = self.border;
    if (border) [s appendFormat:@" /BS %@ /Border [0 0 %@]", border._isim_pdfSource, isim_pdf_number(border.lineWidth)];
    else if ([self.type isEqual:@"Link"]) [s appendString:@" /Border [0 0 0]"];
    PDFAction *action = self.action;
    NSString *as = [action _isim_pdfSourceWithPages:pages transform:pageTransform];
    if (as) [s appendFormat:@" /A %@", as];
    id dest = _values[PDFAnnotationKeyDestination];
    NSString *ds = [dest isKindOfClass:[PDFDestination class]] ? dest_source(dest, pages, pageTransform) : nil;
    if (ds && !as) [s appendFormat:@" /Dest %@", ds];
    PDFAppearanceCharacteristics *mk = _values[PDFAnnotationKeyWidgetAppearanceDictionary];
    if ([mk isKindOfClass:[PDFAppearanceCharacteristics class]]) [s appendFormat:@" /MK %@", mk._isim_pdfSource];
    if ([self.type isEqual:@"Widget"] && [self.widgetFieldType isEqual:PDFAnnotationWidgetSubtypeButton] && self.widgetControlType != kPDFWidgetPushButtonControl &&
        !_values[PDFAnnotationKeyAppearanceState])
        [s appendFormat:@" /AS %@", isim_pdf_name(self.buttonWidgetState == kPDFWidgetOnState ? self.buttonWidgetStateString : @"Off")];
    [s appendString:@" >>"];
    return s;
}
@end
