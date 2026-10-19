/* isim RTF reader (ARC): RTF data to an NSAttributedString with UIKit attributes (issue #237, for Quick Look; the
 * NSAttributedString document API builds on it). Adapted: the character formatting (bold, italic, underline,
 * strikethrough, size, font, colour, superscript / subscript), paragraphs (alignment, indents, spacing), tabs and line
 * breaks, Unicode and code-page escapes; tables, pictures, fields' instructions, headers / footers and the document's
 * styles are skipped (fields keep their result text). */
#import <UIKit/UIKit.h>
#include <ctype.h>

typedef struct {
    BOOL bold, italic, under, strike;
    int size2;                   /* half-points */
    int font, color, super_;     /* super_: 1 superscript, -1 subscript */
    int uc;                      /* bytes skipped after a \uN */
    NSTextAlignment align;
    double li, ri, fi, sb, sa;   /* points */
    BOOL skip;                   /* a destination that is not text */
} RTFState;

/* RTF's 8-bit text is Windows-1252 (\ansicpg1252, the default): Latin-1 but for 0x80-0x9F */
static unichar cp1252(unsigned char b) {
    static const unichar high[32] = { 0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F,
                                      0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178 };
    return b >= 0x80 && b < 0xA0 ? high[b - 0x80] : b;
}
static NSString *cp1252_string(const unsigned char *p, NSUInteger n) {
    unichar buf[n ? n : 1];
    for (NSUInteger i = 0; i < n; i++) buf[i] = cp1252(p[i]);
    return [NSString stringWithCharacters:buf length:n];
}

@interface __IsimRTFReader : NSObject
@end
@implementation __IsimRTFReader {
    const unsigned char *_p, *_end;
    NSMutableAttributedString *_out;
    NSMutableString *_run;
    RTFState _st;
    NSMutableDictionary<NSNumber *, NSString *> *_fonts;
    NSMutableArray *_colors;     /* UIColor or NSNull (the default colour) */
    int _skipBytes;
}
- (instancetype)initWithData:(NSData *)d {
    if ((self = [super init])) {
        _p = d.bytes; _end = _p + d.length;
        _out = [NSMutableAttributedString new]; _run = [NSMutableString string];
        _fonts = [NSMutableDictionary dictionary]; _colors = [NSMutableArray array];
        _st = (RTFState){ .size2 = 24, .uc = 1, .align = NSTextAlignmentNatural };
    }
    return self;
}
- (NSDictionary *)_attributes {
    CGFloat size = _st.size2 / 2.0;
    if (_st.super_) size *= 0.66;
    NSString *name = _fonts[@(_st.font)];
    UIFont *f = name ? [UIFont fontWithName:name size:size] : nil;
    if (!f) f = [UIFont systemFontOfSize:size];
    UIFontDescriptorSymbolicTraits t = (_st.bold ? UIFontDescriptorTraitBold : 0) | (_st.italic ? UIFontDescriptorTraitItalic : 0);
    if (t) { UIFontDescriptor *fd = [f.fontDescriptor fontDescriptorWithSymbolicTraits:t]; UIFont *styled = fd ? [UIFont fontWithDescriptor:fd size:size] : nil; if (styled) f = styled; }
    NSMutableDictionary *a = [NSMutableDictionary dictionaryWithObject:f forKey:NSFontAttributeName];
    id c = _st.color > 0 && _st.color < (int)_colors.count ? _colors[_st.color] : nil;
    if ([c isKindOfClass:UIColor.class]) a[NSForegroundColorAttributeName] = c;
    if (_st.under) a[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
    if (_st.strike) a[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
    if (_st.super_) a[NSBaselineOffsetAttributeName] = @(_st.super_ * _st.size2 / 2.0 * 0.33);
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
    ps.alignment = _st.align;
    ps.headIndent = _st.li; ps.firstLineHeadIndent = _st.li + _st.fi; ps.tailIndent = -_st.ri;
    ps.paragraphSpacingBefore = _st.sb; ps.paragraphSpacing = _st.sa;
    a[NSParagraphStyleAttributeName] = ps;
    return a;
}
- (void)_flush {
    if (!_run.length) return;
    [_out appendAttributedString:[[NSAttributedString alloc] initWithString:_run attributes:[self _attributes]]];
    [_run setString:@""];
}
- (void)_text:(NSString *)s {
    if (_st.skip || !s.length) return;
    [_run appendString:s];
}
/* the font table: {\f0\fswiss Helvetica;} entries */
- (void)_fontTableEntry:(int)n name:(NSString *)name { if (n >= 0 && name.length) _fonts[@(n)] = name; }
- (NSAttributedString *)read {
    NSMutableData *stack = [NSMutableData data];
    int depth = 0, fontNo = -1, red = 0, green = 0, blue = 0;
    BOOL colorSet = NO;
    enum { DNone, DFontTable, DColorTable } dest = DNone;
    int destDepth = -1;
    NSMutableString *fontName = [NSMutableString string];
    while (_p < _end) {
        unsigned char ch = *_p++;
        if (ch == '{') {
            [stack appendBytes:&_st length:sizeof _st]; depth++;
            if (_p + 1 < _end && _p[0] == '\\' && _p[1] == '*') { _st.skip = YES; _p += 2; }
            continue;
        }
        if (ch == '}') {
            if (dest == DFontTable && fontName.length) {
                [self _fontTableEntry:fontNo name:[fontName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
                [fontName setString:@""];
            }
            if (depth == destDepth) { dest = DNone; destDepth = -1; }
            if (depth > 0) {
                [self _flushIfChanging:(RTFState *)((char *)stack.mutableBytes + stack.length - sizeof _st)];
                memcpy(&_st, (char *)stack.bytes + stack.length - sizeof _st, sizeof _st);
                stack.length -= sizeof _st; depth--;
            }
            continue;
        }
        if (ch == '\r' || ch == '\n') continue;
        if (ch != '\\') {
            if (_skipBytes > 0) { _skipBytes--; continue; }
            if (dest == DFontTable) {                                   /* "Helvetica;" ends an entry */
                if (_st.skip) continue;                                 /* {\*\panose ...} */
                if (ch == ';') { [self _fontTableEntry:fontNo name:[fontName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]]; [fontName setString:@""]; }
                else [fontName appendFormat:@"%c", ch];
                continue;
            }
            if (dest == DColorTable) {
                if (ch == ';') {
                    [_colors addObject:colorSet ? [UIColor colorWithRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:1] : (id)NSNull.null];
                    red = green = blue = 0; colorSet = NO;
                }
                continue;
            }
            /* plain text: up to the next control character, in Windows-1252 */
            const unsigned char *s = _p - 1;
            while (_p < _end && *_p != '\\' && *_p != '{' && *_p != '}' && *_p != '\r' && *_p != '\n') _p++;
            NSString *t = cp1252_string(s, (NSUInteger)(_p - s));
            [self _text:t];
            continue;
        }
        if (_p >= _end) break;
        unsigned char c = *_p;
        if (c == '\\' || c == '{' || c == '}') { _p++; if (_skipBytes > 0) { _skipBytes--; continue; } [self _text:[NSString stringWithFormat:@"%c", c]]; continue; }
        if (c == '\'') {
            _p++;
            if (_p + 2 > _end) break;
            char hex[3] = { (char)_p[0], (char)_p[1], 0 }; _p += 2;
            if (_skipBytes > 0) { _skipBytes--; continue; }
            unsigned char b = (unsigned char)strtol(hex, NULL, 16);
            unichar u = cp1252(b);
            if (dest == DFontTable) { if (!_st.skip) [fontName appendString:[NSString stringWithCharacters:&u length:1]]; continue; }
            [self _text:[NSString stringWithCharacters:&u length:1]];
            continue;
        }
        if (c == '~') { _p++; [self _text:@"\u00a0"]; continue; }
        if (c == '-') { _p++; continue; }                                  /* optional hyphen */
        if (c == '_') { _p++; [self _text:@"\u2011"]; continue; }
        if (c == '\r' || c == '\n') { _p++; [self _text:@"\n"]; continue; }  /* \<newline> is \par */
        if (c == '*') { _p++; _st.skip = YES; continue; }
        if (!isalpha(c)) { _p++; continue; }
        /* a control word: letters, an optional signed number, an optional space */
        const unsigned char *w = _p;
        while (_p < _end && isalpha(*_p)) _p++;
        NSString *word = [[NSString alloc] initWithBytes:w length:_p - w encoding:NSASCIIStringEncoding];
        BOOL hasArg = NO; int arg = 0, sign = 1;
        if (_p < _end && *_p == '-') { sign = -1; _p++; }
        while (_p < _end && isdigit(*_p)) { hasArg = YES; arg = arg * 10 + (*_p++ - '0'); }
        arg *= sign;
        if (_p < _end && *_p == ' ') _p++;
        [self _word:word arg:arg has:hasArg dest:(int *)&dest destDepth:&destDepth depth:depth fontNo:&fontNo
                red:&red green:&green blue:&blue colorSet:&colorSet];
    }
    [self _flush];
    /* a final paragraph mark ends the document, it does not add an empty line */
    if ([_out.string hasSuffix:@"\n"]) [_out deleteCharactersInRange:NSMakeRange(_out.length - 1, 1)];
    return _out;
}
- (void)_flushIfChanging:(RTFState *)next { if (memcmp(next, &_st, sizeof _st)) [self _flush]; }
- (void)_word:(NSString *)w arg:(int)n has:(BOOL)has dest:(int *)dest destDepth:(int *)destDepth depth:(int)depth fontNo:(int *)fontNo
          red:(int *)r green:(int *)g blue:(int *)b colorSet:(BOOL *)set {
    RTFState before = _st;
    BOOL on = !has || n != 0;
    if ([w isEqualToString:@"fonttbl"]) { *dest = 1; *destDepth = depth; return; }
    if ([w isEqualToString:@"colortbl"]) { *dest = 2; *destDepth = depth; return; }
    if (*dest == 1) { if ([w isEqualToString:@"f"]) *fontNo = n; return; }
    if (*dest == 2) {
        if ([w isEqualToString:@"red"]) { *r = n; *set = YES; } else if ([w isEqualToString:@"green"]) { *g = n; *set = YES; }
        else if ([w isEqualToString:@"blue"]) { *b = n; *set = YES; }
        return;
    }
    static NSSet *skipped;
    if (!skipped) skipped = [NSSet setWithArray:@[@"stylesheet", @"info", @"pict", @"header", @"footer", @"headerl", @"headerr", @"headerf",
                                                  @"footerl", @"footerr", @"footerf", @"fldinst", @"listtable", @"listoverridetable",
                                                  @"generator", @"themedata", @"colorschememapping", @"latentstyles", @"rsidtbl",
                                                  @"datastore", @"xmlnstbl", @"mmathPr", @"object", @"footnote", @"bkmkstart", @"bkmkend",
                                                  @"expandedcolortbl", @"listtext", @"pntext"]];
    if ([skipped containsObject:w]) { _st.skip = YES; return; }
    if (_st.skip) return;
    if ([w isEqualToString:@"u"]) {
        unichar u = (unichar)(n < 0 ? n + 65536 : n);
        [self _text:[NSString stringWithCharacters:&u length:1]];
        _skipBytes = _st.uc;
        return;
    }
    if ([w isEqualToString:@"par"] || [w isEqualToString:@"sect"] || [w isEqualToString:@"page"]) { [self _text:@"\n"]; return; }
    if ([w isEqualToString:@"line"]) { [self _text:@"\u2028"]; return; }
    if ([w isEqualToString:@"tab"]) { [self _text:@"\t"]; return; }
    if ([w isEqualToString:@"emdash"]) { [self _text:@"\u2014"]; return; }
    if ([w isEqualToString:@"endash"]) { [self _text:@"\u2013"]; return; }
    if ([w isEqualToString:@"bullet"]) { [self _text:@"\u2022"]; return; }
    if ([w isEqualToString:@"lquote"]) { [self _text:@"\u2018"]; return; }
    if ([w isEqualToString:@"rquote"]) { [self _text:@"\u2019"]; return; }
    if ([w isEqualToString:@"ldblquote"]) { [self _text:@"\u201c"]; return; }
    if ([w isEqualToString:@"rdblquote"]) { [self _text:@"\u201d"]; return; }
    RTFState s = _st;
    if ([w isEqualToString:@"b"]) s.bold = on;
    else if ([w isEqualToString:@"i"]) s.italic = on;
    else if ([w isEqualToString:@"ul"]) s.under = on;
    else if ([w isEqualToString:@"ulnone"]) s.under = NO;
    else if ([w isEqualToString:@"strike"]) s.strike = on;
    else if ([w isEqualToString:@"fs"] && n > 0) s.size2 = n;
    else if ([w isEqualToString:@"f"]) s.font = n;
    else if ([w isEqualToString:@"cf"]) s.color = n;
    else if ([w isEqualToString:@"super"]) s.super_ = 1;
    else if ([w isEqualToString:@"sub"]) s.super_ = -1;
    else if ([w isEqualToString:@"nosupersub"]) s.super_ = 0;
    else if ([w isEqualToString:@"uc"]) s.uc = n;
    else if ([w isEqualToString:@"plain"]) { s.bold = s.italic = s.under = s.strike = NO; s.size2 = 24; s.font = 0; s.color = 0; s.super_ = 0; }
    else if ([w isEqualToString:@"pard"]) { s.align = NSTextAlignmentNatural; s.li = s.ri = s.fi = s.sb = s.sa = 0; }
    else if ([w isEqualToString:@"ql"]) s.align = NSTextAlignmentLeft;
    else if ([w isEqualToString:@"qr"]) s.align = NSTextAlignmentRight;
    else if ([w isEqualToString:@"qc"]) s.align = NSTextAlignmentCenter;
    else if ([w isEqualToString:@"qj"]) s.align = NSTextAlignmentJustified;
    else if ([w isEqualToString:@"li"]) s.li = n / 20.0;
    else if ([w isEqualToString:@"ri"]) s.ri = n / 20.0;
    else if ([w isEqualToString:@"fi"]) s.fi = n / 20.0;
    else if ([w isEqualToString:@"sb"]) s.sb = n / 20.0;
    else if ([w isEqualToString:@"sa"]) s.sa = n / 20.0;
    else return;
    if (memcmp(&s, &before, sizeof s)) { [self _flush]; _st = s; }
}
@end

@implementation NSAttributedString (IsimRTF)
+ (NSAttributedString *)_isim_attributedStringWithRTF:(NSData *)data {
    if (data.length < 5 || memcmp(data.bytes, "{\\rtf", 5)) return nil;
    return [[[__IsimRTFReader alloc] initWithData:data] read];
}
@end
