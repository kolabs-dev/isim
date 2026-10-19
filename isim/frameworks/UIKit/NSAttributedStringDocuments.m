/* isim UIKit (ARC): NSAttributedString's document formats (issue #238). Reading:
 * - plain text: the encoding from the options, else UTF-8 (a BOM: UTF-16), else Windows-1252; the default attributes
 *   from the options, else Helvetica 12 (as iOS);
 * - RTF: isim's RTF reader (UIRTFReader.m);
 * - HTML (adapted): the host's libxml2 parses the document (entities, charset, implied and misnested elements) and
 *   UIHTMLReader.m maps its elements and CSS to attributes. iOS lays HTML out with WebKit; isim covers what text
 *   import uses: fonts, sizes, weights and styles, colours, backgrounds, underline / strikethrough, links, alignment,
 *   indents and paragraph spacing, lists, line breaks, superscript / subscript, preformatted text, tables as tabs and
 *   images from file and data URLs. Scripts don't run and remote resources aren't loaded.
 * The type comes from NSDocumentTypeDocumentOption, else the URL's extension, else the data ("{\rtf" is RTF, markup
 * is HTML, the rest is plain text). RTFD and writing (issue #239): an RTFD package is TXT.rtf with its attachments'
 * files (UIRTFReader.m reads its NeXTGraphic groups); UIDocumentWriters.m writes RTF, RTFD and HTML. */
#import <UIKit/UIKit.h>

NSAttributedStringDocumentType const NSPlainTextDocumentType = @"NSPlainText";
NSAttributedStringDocumentType const NSRTFTextDocumentType = @"NSRTF";
NSAttributedStringDocumentType const NSRTFDTextDocumentType = @"NSRTFD";
NSAttributedStringDocumentType const NSHTMLTextDocumentType = @"NSHTML";
NSTextLayoutSectionKey const NSTextLayoutSectionOrientation = @"NSTextLayoutSectionOrientation";
NSTextLayoutSectionKey const NSTextLayoutSectionRange = @"NSTextLayoutSectionRange";
NSAttributedStringDocumentAttributeKey const NSDocumentTypeDocumentAttribute = @"DocumentType";
NSAttributedStringDocumentAttributeKey const NSCharacterEncodingDocumentAttribute = @"CharacterEncoding";
NSAttributedStringDocumentAttributeKey const NSDefaultAttributesDocumentAttribute = @"DefaultAttributes";
NSAttributedStringDocumentAttributeKey const NSPaperSizeDocumentAttribute = @"PaperSize";
NSAttributedStringDocumentAttributeKey const NSPaperMarginDocumentAttribute = @"PaperMargin";
NSAttributedStringDocumentAttributeKey const NSViewSizeDocumentAttribute = @"ViewSize";
NSAttributedStringDocumentAttributeKey const NSViewZoomDocumentAttribute = @"ViewZoom";
NSAttributedStringDocumentAttributeKey const NSViewModeDocumentAttribute = @"ViewMode";
NSAttributedStringDocumentAttributeKey const NSReadOnlyDocumentAttribute = @"ReadOnly";
NSAttributedStringDocumentAttributeKey const NSBackgroundColorDocumentAttribute = @"BackgroundColor";
NSAttributedStringDocumentAttributeKey const NSHyphenationFactorDocumentAttribute = @"HyphenationFactor";
NSAttributedStringDocumentAttributeKey const NSDefaultTabIntervalDocumentAttribute = @"DefaultTabInterval";
NSAttributedStringDocumentAttributeKey const NSTextLayoutSectionsAttribute = @"NSTextLayoutSectionsAttribute";
NSAttributedStringDocumentAttributeKey const NSCocoaVersionDocumentAttribute = @"CocoaRTFVersion";
NSAttributedStringDocumentAttributeKey const NSSourceTextScalingDocumentAttribute = @"NSSourceTextScalingDocumentAttribute";
NSAttributedStringDocumentAttributeKey const NSTextScalingDocumentAttribute = @"NSTextScalingDocumentAttribute";
NSAttributedStringDocumentAttributeKey const NSDefaultFontExcludedDocumentAttribute = @"NSDefaultFontExcludedDocumentAttribute";
NSAttributedStringDocumentReadingOptionKey const NSDocumentTypeDocumentOption = @"DocumentType";
NSAttributedStringDocumentReadingOptionKey const NSDefaultAttributesDocumentOption = @"DefaultAttributes";
NSAttributedStringDocumentReadingOptionKey const NSCharacterEncodingDocumentOption = @"CharacterEncoding";
NSAttributedStringDocumentReadingOptionKey const NSReadAccessURLDocumentOption = @"ReadAccessURL";
NSAttributedStringDocumentReadingOptionKey const NSSourceTextScalingDocumentOption = @"NSSourceTextScalingDocumentOption";
NSAttributedStringDocumentReadingOptionKey const NSTargetTextScalingDocumentOption = @"NSTargetTextScalingDocumentOption";
NSAttributedStringDocumentReadingOptionKey const NSTextKit1ListMarkerFormatDocumentOption = @"NSTextKit1ListMarkerFormatDocumentOption";

@interface NSAttributedString (IsimRTF)
+ (nullable NSAttributedString *)_isim_attributedStringWithRTF:(NSData *)data;
+ (nullable NSAttributedString *)_isim_attributedStringWithRTF:(NSData *)data files:(nullable NSDictionary<NSString *, NSFileWrapper *> *)files
                                                         page:(NSDictionary *_Nullable *_Nullable)page;
@end
/* UIDocumentWriters.m */
NSData *isim_ui_rtf_data(NSAttributedString *str, NSDictionary *docAttrs, NSMutableDictionary<NSString *, NSFileWrapper *> *files);
NSData *isim_ui_html_data(NSAttributedString *str, NSDictionary *docAttrs);
/* UIHTMLReader.m */
NSAttributedString *isim_ui_attributed_from_html(NSData *data, NSDictionary *options, NSURL *baseURL, NSStringEncoding *encodingOut);

/* RTF's 8-bit text and plain text that isn't UTF-8: Windows-1252 (Latin-1 but for 0x80-0x9F) */
static NSString *latin_string(NSData *d) {
    static const unichar high[32] = { 0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F,
                                      0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178 };
    const unsigned char *p = d.bytes; NSUInteger n = d.length;
    unichar *buf = malloc((n ? n : 1) * sizeof(unichar));
    for (NSUInteger i = 0; i < n; i++) buf[i] = p[i] >= 0x80 && p[i] < 0xA0 ? high[p[i] - 0x80] : p[i];
    NSString *s = [NSString stringWithCharacters:buf length:n];
    free(buf);
    return s;
}
static BOOL valid_utf8(const unsigned char *p, NSUInteger n) {
    for (NSUInteger i = 0; i < n;) {
        unsigned char c = p[i];
        int k = c < 0x80 ? 0 : (c & 0xE0) == 0xC0 ? 1 : (c & 0xF0) == 0xE0 ? 2 : (c & 0xF8) == 0xF0 ? 3 : -1;
        if (k < 0 || i + k >= n) return NO;
        for (int j = 1; j <= k; j++) if ((p[i + j] & 0xC0) != 0x80) return NO;
        i += k + 1;
    }
    return YES;
}
/* text in an encoding: UTF-8, UTF-16 (with or without a BOM), ASCII, Latin-1 / Windows-1252; NULL when it doesn't decode */
static NSString *decode(NSData *d, NSStringEncoding enc, NSStringEncoding *used) {
    const unsigned char *p = d.bytes; NSUInteger n = d.length;
    if (!enc) {                                                     /* guess: a BOM, UTF-8, else Windows-1252 */
        if (n >= 2 && ((p[0] == 0xFF && p[1] == 0xFE) || (p[0] == 0xFE && p[1] == 0xFF))) enc = NSUTF16StringEncoding;
        else enc = valid_utf8(p, n) ? NSUTF8StringEncoding : NSWindowsCP1252StringEncoding;
    }
    if (used) *used = enc;
    switch (enc) {
    case NSUTF8StringEncoding:
        if (n >= 3 && p[0] == 0xEF && p[1] == 0xBB && p[2] == 0xBF) { p += 3; n -= 3; }
        return valid_utf8(p, n) ? [[NSString alloc] initWithBytes:p length:n encoding:NSUTF8StringEncoding] : nil;
    case NSASCIIStringEncoding:
        for (NSUInteger i = 0; i < n; i++) if (p[i] >= 0x80) return nil;
        return [[NSString alloc] initWithBytes:p length:n encoding:NSUTF8StringEncoding];
    case NSISOLatin1StringEncoding: case NSWindowsCP1252StringEncoding:
        return latin_string(d);
    case NSUTF16StringEncoding: case NSUTF16LittleEndianStringEncoding: case NSUTF16BigEndianStringEncoding: {
        BOOL big = enc == NSUTF16BigEndianStringEncoding;
        if (n >= 2 && p[0] == 0xFE && p[1] == 0xFF) { big = YES; p += 2; n -= 2; }
        else if (n >= 2 && p[0] == 0xFF && p[1] == 0xFE) { big = NO; p += 2; n -= 2; }
        NSUInteger count = n / 2;
        unichar *buf = malloc((count ? count : 1) * sizeof(unichar));
        for (NSUInteger i = 0; i < count; i++) buf[i] = big ? (unichar)(p[2 * i] << 8 | p[2 * i + 1]) : (unichar)(p[2 * i + 1] << 8 | p[2 * i]);
        NSString *s = [NSString stringWithCharacters:buf length:count];
        free(buf);
        return s; }
    default:
        return valid_utf8(p, n) ? [[NSString alloc] initWithBytes:p length:n encoding:NSUTF8StringEncoding] : nil;
    }
}

static NSAttributedStringDocumentType sniff(NSData *d) {
    const unsigned char *p = d.bytes; NSUInteger n = d.length, i = 0;
    if (n >= 3 && p[0] == 0xEF && p[1] == 0xBB && p[2] == 0xBF) i = 3;
    while (i < n && (p[i] == ' ' || p[i] == '\t' || p[i] == '\r' || p[i] == '\n')) i++;
    if (n - i >= 5 && !memcmp(p + i, "{\\rtf", 5)) return NSRTFTextDocumentType;
    if (i < n && p[i] == '<') {
        NSString *head = [[NSString alloc] initWithBytes:p + i length:MIN(n - i, 512) encoding:NSUTF8StringEncoding] ?: @"";
        head = head.lowercaseString;
        for (NSString *t in @[@"<!doctype html", @"<html", @"<head", @"<body", @"<meta", @"<title", @"<p", @"<div", @"<span", @"<b>", @"<i>",
                              @"<h1", @"<h2", @"<h3", @"<ul", @"<ol", @"<table", @"<br", @"<a ", @"<font", @"<!--"])
            if ([head hasPrefix:t]) return NSHTMLTextDocumentType;
    }
    return NSPlainTextDocumentType;
}
static NSDictionary *plain_defaults(void) {
    UIFont *f = [UIFont fontWithName:@"Helvetica" size:12] ?: [UIFont systemFontOfSize:12];
    return @{ NSFontAttributeName: f, NSParagraphStyleAttributeName: NSParagraphStyle.defaultParagraphStyle };
}
static NSError *read_error(NSInteger code, NSURL *url) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (url) info[NSURLErrorKey] = url;
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:info];
}

/* the shared reader: the attributed string, or nil with *error */
/* the page RTF describes (twips) as document attributes, Cocoa's defaults otherwise */
static void rtf_page(NSDictionary *page, NSMutableDictionary *docAttrs) {
    CGFloat w = page[@"paperw"] ? [page[@"paperw"] doubleValue] / 20 : 612, h = page[@"paperh"] ? [page[@"paperh"] doubleValue] / 20 : 792;
    CGFloat l = page[@"margl"] ? [page[@"margl"] doubleValue] / 20 : 90, r = page[@"margr"] ? [page[@"margr"] doubleValue] / 20 : 90;
    CGFloat t = page[@"margt"] ? [page[@"margt"] doubleValue] / 20 : 72, b = page[@"margb"] ? [page[@"margb"] doubleValue] / 20 : 72;
    docAttrs[NSPaperSizeDocumentAttribute] = [NSValue valueWithCGSize:CGSizeMake(w, h)];
    docAttrs[NSPaperMarginDocumentAttribute] = [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(t, l, b, r)];
    docAttrs[NSViewModeDocumentAttribute] = @([page[@"viewkind"] integerValue]);
    if (page[@"deftab"]) docAttrs[NSDefaultTabIntervalDocumentAttribute] = @([page[@"deftab"] doubleValue] / 20);
    docAttrs[NSCocoaVersionDocumentAttribute] = @2685;
}
/* wrapper: an RTFD package already read (a directory URL); data: anything else */
static NSAttributedString *read_document(NSData *data, NSFileWrapper *wrapper, NSURL *url, NSDictionary *options, NSDictionary **attrsOut, NSError **error) {
    NSAttributedStringDocumentType type = options[NSDocumentTypeDocumentOption];
    if (!type && url) {
        NSString *e = url.pathExtension.lowercaseString;
        if (wrapper.isDirectory) type = NSRTFDTextDocumentType;
        else if ([@[@"html", @"htm", @"xhtml"] containsObject:e]) type = NSHTMLTextDocumentType;
        else if ([e isEqualToString:@"rtf"]) type = NSRTFTextDocumentType;
        else if ([e isEqualToString:@"rtfd"]) type = NSRTFDTextDocumentType;
        else if ([e isEqualToString:@"txt"]) type = NSPlainTextDocumentType;
    }
    if (!type && data.length >= 8 && !memcmp(data.bytes, "rtfdisim", 8)) type = NSRTFDTextDocumentType;
    if (!type) type = sniff(data);
    NSStringEncoding requested = [options[NSCharacterEncodingDocumentOption] unsignedIntegerValue], used = 0;
    NSMutableDictionary *docAttrs = [NSMutableDictionary dictionaryWithObject:type forKey:NSDocumentTypeDocumentAttribute];
    docAttrs[NSDefaultTabIntervalDocumentAttribute] = @36;
    NSAttributedString *result = nil;
    if ([type isEqualToString:NSPlainTextDocumentType]) {
        NSString *s = decode(data, requested, &used);
        if (s) result = [[NSAttributedString alloc] initWithString:s attributes:options[NSDefaultAttributesDocumentOption] ?: plain_defaults()];
        docAttrs[NSCharacterEncodingDocumentAttribute] = @(used);
    } else if ([type isEqualToString:NSRTFTextDocumentType]) {
        NSDictionary *page = nil;
        result = [NSAttributedString _isim_attributedStringWithRTF:data files:nil page:&page];
        rtf_page(page, docAttrs);
    } else if ([type isEqualToString:NSHTMLTextDocumentType]) {
        NSURL *base = url ?: options[NSReadAccessURLDocumentOption];
        result = isim_ui_attributed_from_html(data, options, base, &used);
        if (result) {
            docAttrs[NSCharacterEncodingDocumentAttribute] = @(used);
            docAttrs[NSPaperSizeDocumentAttribute] = [NSValue valueWithCGSize:CGSizeMake(612, 792)];
            docAttrs[NSPaperMarginDocumentAttribute] = [NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(72, 72, 72, 72)];
            docAttrs[NSViewModeDocumentAttribute] = @0;
            docAttrs[NSReadOnlyDocumentAttribute] = @(-1);
        }
    } else if ([type isEqualToString:NSRTFDTextDocumentType]) {
        /* a package: TXT.rtf and the attachments' files (a directory, or its serialized form as data) */
        NSFileWrapper *w = wrapper ?: [[NSFileWrapper alloc] initWithSerializedRepresentation:data];
        NSDictionary<NSString *, NSFileWrapper *> *files = w.fileWrappers;
        NSData *rtf = files[@"TXT.rtf"].regularFileContents;
        if (!rtf && w.isRegularFile) rtf = w.regularFileContents;           /* an RTFD without attachments may be plain RTF */
        NSDictionary *page = nil;
        result = rtf ? [NSAttributedString _isim_attributedStringWithRTF:rtf files:files page:&page] : nil;
        rtf_page(page, docAttrs);
    } else {
        if (error) *error = read_error(NSFileReadUnknownError, url);
        return nil;
    }
    if (!result) { if (error) *error = read_error(NSFileReadCorruptFileError, url); return nil; }
    if (attrsOut) *attrsOut = docAttrs;
    return result;
}
static NSData *read_url(NSURL *url, NSFileWrapper **wrapper, NSError **error) {
    if (!url.isFileURL) { if (error) *error = read_error(NSFileReadUnsupportedSchemeError, url); return nil; }
    BOOL dir = NO;
    if ([NSFileManager.defaultManager fileExistsAtPath:url.path isDirectory:&dir] && dir) {     /* an RTFD package */
        *wrapper = [[NSFileWrapper alloc] initWithURL:url options:0 error:error];
        return *wrapper ? [NSData data] : nil;
    }
    NSData *d = [NSData dataWithContentsOfFile:url.path];
    if (!d) { if (error) *error = read_error(NSFileReadNoSuchFileError, url); return nil; }
    return d;
}

/* ---- writing (issue #239) ---- */
static NSError *write_error(NSInteger code) { return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:nil]; }
static NSFileWrapper *rtfd_wrapper(NSAttributedString *s, NSDictionary *dict) {
    NSMutableDictionary<NSString *, NSFileWrapper *> *files = [NSMutableDictionary dictionary];
    NSData *rtf = isim_ui_rtf_data(s, dict, files);
    files[@"TXT.rtf"] = [[NSFileWrapper alloc] initRegularFileWithContents:rtf];
    files[@"TXT.rtf"].preferredFilename = @"TXT.rtf";
    return [[NSFileWrapper alloc] initDirectoryWithFileWrappers:files];
}
static NSData *document_data(NSAttributedString *s, NSDictionary *dict, NSError **error) {
    NSAttributedStringDocumentType type = dict[NSDocumentTypeDocumentAttribute];
    if (!type) { if (error) *error = write_error(NSFileWriteUnknownError); return nil; }
    if ([type isEqualToString:NSPlainTextDocumentType]) {
        NSStringEncoding enc = [dict[NSCharacterEncodingDocumentAttribute] unsignedIntegerValue] ?: NSUTF8StringEncoding;
        NSString *t = [s.string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%C", (unichar)0xFFFC] withString:@""];
        NSData *d = [t dataUsingEncoding:enc];
        if (!d && error) *error = write_error(NSFileWriteInapplicableStringEncodingError);
        return d;
    }
    if ([type isEqualToString:NSRTFTextDocumentType]) return isim_ui_rtf_data(s, dict, nil);
    if ([type isEqualToString:NSRTFDTextDocumentType]) return rtfd_wrapper(s, dict).serializedRepresentation;
    if ([type isEqualToString:NSHTMLTextDocumentType]) return isim_ui_html_data(s, dict);
    if (error) *error = write_error(NSFileWriteUnknownError);
    return nil;
}

@implementation NSAttributedString (NSAttributedStringDocumentFormats)
- (instancetype)initWithData:(NSData *)data options:(NSDictionary *)options documentAttributes:(NSDictionary **)dict error:(NSError **)error {
    NSAttributedString *s = read_document(data ?: [NSData data], nil, nil, options, dict, error);
    return s ? [self initWithAttributedString:s] : nil;
}
- (instancetype)initWithURL:(NSURL *)url options:(NSDictionary *)options documentAttributes:(NSDictionary **)dict error:(NSError **)error {
    NSFileWrapper *w = nil;
    NSData *d = read_url(url, &w, error);
    NSAttributedString *s = d ? read_document(d, w, url, options, dict, error) : nil;
    return s ? [self initWithAttributedString:s] : nil;
}
- (NSData *)dataFromRange:(NSRange)range documentAttributes:(NSDictionary *)dict error:(NSError **)error {
    if (NSMaxRange(range) > self.length) [NSException raise:NSRangeException format:@"dataFromRange: %@ out of bounds (%lu)", NSStringFromRange(range), (unsigned long)self.length];
    return document_data([self attributedSubstringFromRange:range], dict ?: @{}, error);
}
- (NSFileWrapper *)fileWrapperFromRange:(NSRange)range documentAttributes:(NSDictionary *)dict error:(NSError **)error {
    if (NSMaxRange(range) > self.length) [NSException raise:NSRangeException format:@"fileWrapperFromRange: %@ out of bounds (%lu)", NSStringFromRange(range), (unsigned long)self.length];
    NSAttributedString *s = [self attributedSubstringFromRange:range];
    if ([dict[NSDocumentTypeDocumentAttribute] isEqualToString:NSRTFDTextDocumentType]) return rtfd_wrapper(s, dict);
    NSData *d = document_data(s, dict ?: @{}, error);
    return d ? [[NSFileWrapper alloc] initRegularFileWithContents:d] : nil;
}
@end

@implementation NSMutableAttributedString (NSMutableAttributedStringDocumentFormats)
- (BOOL)readFromData:(NSData *)data options:(NSDictionary *)opts documentAttributes:(NSDictionary **)dict error:(NSError **)error {
    NSAttributedString *s = read_document(data ?: [NSData data], nil, nil, opts, dict, error);
    if (s) [self setAttributedString:s];
    return s != nil;
}
- (BOOL)readFromURL:(NSURL *)url options:(NSDictionary *)opts documentAttributes:(NSDictionary **)dict error:(NSError **)error {
    NSFileWrapper *w = nil;
    NSData *d = read_url(url, &w, error);
    NSAttributedString *s = d ? read_document(d, w, url, opts, dict, error) : nil;
    if (s) [self setAttributedString:s];
    return s != nil;
}
@end
