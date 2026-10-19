/* isim UIKit (ARC): writing NSAttributedString as RTF, RTFD and HTML (issue #239; NSAttributedStringDocuments.m's
 * dataFromRange: / fileWrapperFromRange: call these). The output follows Cocoa's writers so other RTF / HTML readers
 * (and isim's own) read it back:
 * - RTF: \rtf1\ansi\ansicpg1252\cocoartf, a font table of PostScript names, a colour table, then per paragraph \pard
 *   with alignment, indents, spacing and tab stops, per run the font and size, bold / italic, underline,
 *   strikethrough, colours (\cf, \cb), baseline offset (\up, \dn) and links (HYPERLINK fields); text other than
 *   ASCII as \uc0\uN; the page from the document attributes (\paperw, \margl ...). Attachments are dropped;
 * - RTFD: the same RTF as TXT.rtf, each attachment as {{\NeXTGraphic name \width \height}\'ac} and its file
 *   beside it in the package;
 * - HTML: Cocoa's HTML writer's shape: a <style> with p.pN / span.sN classes, fonts in px (as Cocoa writes them:
 *   1pt = 1px), links as <a href>, attachments dropped. */
#import <UIKit/UIKit.h>

static NSString *hex2(CGFloat c) { return [NSString stringWithFormat:@"%02x", (int)lround(fmax(0, fmin(1, c)) * 255)]; }
static BOOL rgb(UIColor *c, CGFloat out[4]) {
    if (!c) return NO;
    return [c getRed:&out[0] green:&out[1] blue:&out[2] alpha:&out[3]];
}
static BOOL font_bold(UIFont *f) { return (f.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0; }
static BOOL font_italic(UIFont *f) { return (f.fontDescriptor.symbolicTraits & UIFontDescriptorTraitItalic) != 0; }
static UIFont *font_of(NSDictionary *a) { return a[NSFontAttributeName] ?: [UIFont fontWithName:@"Helvetica" size:12] ?: [UIFont systemFontOfSize:12]; }
static NSURL *link_of(NSDictionary *a) {
    id l = a[NSLinkAttributeName];
    return [l isKindOfClass:NSURL.class] ? l : [l isKindOfClass:NSString.class] ? [NSURL URLWithString:l] : nil;
}

/* ---------------- RTF ---------------- */
static void rtf_escape(NSMutableString *o, NSString *t) {
    for (NSUInteger i = 0; i < t.length; i++) {
        unichar c = [t characterAtIndex:i];
        if (c == '\\' || c == '{' || c == '}') [o appendFormat:@"\\%C", c];
        else if (c == '\n' || c == 0x2029) [o appendString:@"\\\n"];
        else if (c == 0x2028) [o appendString:@"\\line "];
        else if (c == '\t') [o appendString:@"\\tab "];
        else if (c < 0x80) [o appendFormat:@"%C", c];
        else [o appendFormat:@"\\uc0\\u%d ", (short)c];
    }
}
static NSString *rtf_paragraph(NSParagraphStyle *ps) {
    NSMutableString *o = [NSMutableString stringWithString:@"\\pard"];
    for (NSTextTab *t in ps.tabStops) [o appendFormat:@"\\tx%ld", lround(t.location * 20)];
    if (ps.headIndent) [o appendFormat:@"\\li%ld", lround(ps.headIndent * 20)];
    if (ps.firstLineHeadIndent != ps.headIndent) [o appendFormat:@"\\fi%ld", lround((ps.firstLineHeadIndent - ps.headIndent) * 20)];
    if (ps.tailIndent < 0) [o appendFormat:@"\\ri%ld", lround(-ps.tailIndent * 20)];
    if (ps.paragraphSpacingBefore) [o appendFormat:@"\\sb%ld", lround(ps.paragraphSpacingBefore * 20)];
    if (ps.paragraphSpacing) [o appendFormat:@"\\sa%ld", lround(ps.paragraphSpacing * 20)];
    [o appendString:@"\\pardirnatural"];
    switch (ps.alignment) {
    case NSTextAlignmentCenter: [o appendString:@"\\qc"]; break;
    case NSTextAlignmentRight: [o appendString:@"\\qr"]; break;
    case NSTextAlignmentJustified: [o appendString:@"\\qj"]; break;
    case NSTextAlignmentLeft: [o appendString:@"\\ql"]; break;
    default: break;
    }
    [o appendString:@"\\partightenfactor0\n"];
    return o;
}

NSData *isim_ui_rtf_data(NSAttributedString *str, NSDictionary *docAttrs, NSMutableDictionary<NSString *, NSFileWrapper *> *files) {
    NSString *text = str.string;
    NSMutableArray<NSString *> *fonts = [NSMutableArray array];
    /* "\red..\green..\blue.." entries; Cocoa's table starts with white, so run colours count from 2 */
    NSMutableArray<NSString *> *colors = [NSMutableArray arrayWithObject:@"\\red255\\green255\\blue255"];
    NSInteger (^fontIndex)(UIFont *) = ^NSInteger(UIFont *f) {
        NSString *n = f.fontName ?: @"Helvetica";
        NSUInteger i = [fonts indexOfObject:n];
        if (i == NSNotFound) { [fonts addObject:n]; i = fonts.count - 1; }
        return (NSInteger)i;
    };
    NSInteger (^colorIndex)(UIColor *) = ^NSInteger(UIColor *c) {
        CGFloat v[4];
        if (!rgb(c, v)) return 0;
        NSString *k = [NSString stringWithFormat:@"\\red%ld\\green%ld\\blue%ld", lround(v[0] * 255), lround(v[1] * 255), lround(v[2] * 255)];
        NSUInteger i = [colors indexOfObject:k];
        if (i == NSNotFound) { [colors addObject:k]; i = colors.count - 1; }
        return (NSInteger)i + 1;                                           /* 0 is the default colour */
    };
    NSMutableString *body = [NSMutableString string];
    __block NSParagraphStyle *lastPS = nil;
    __block NSString *lastRun = nil;
    __block BOOL atParagraphStart = YES;
    __block NSUInteger attachmentCount = 0;
    [str enumerateAttributesInRange:NSMakeRange(0, str.length) options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) {
        NSParagraphStyle *ps = a[NSParagraphStyleAttributeName] ?: NSParagraphStyle.defaultParagraphStyle;
        if (atParagraphStart && (!lastPS || ![ps isEqual:lastPS])) { [body appendString:rtf_paragraph(ps)]; lastPS = ps; lastRun = nil; }
        UIFont *f = font_of(a);
        NSMutableString *run = [NSMutableString string];
        [run appendFormat:@"\\f%ld\\fs%ld", (long)fontIndex(f), lround(f.pointSize * 2)];
        [run appendString:font_bold(f) ? @"\\b" : @"\\b0"];
        [run appendString:font_italic(f) ? @"\\i" : @"\\i0"];
        [run appendString:[a[NSUnderlineStyleAttributeName] integerValue] ? @"\\ul\\ulc0" : @"\\ulnone"];
        [run appendString:[a[NSStrikethroughStyleAttributeName] integerValue] ? @"\\strike\\strikec0" : @"\\strike0\\striked0"];
        [run appendFormat:@"\\cf%ld", (long)colorIndex(a[NSForegroundColorAttributeName])];
        NSInteger bg = colorIndex(a[NSBackgroundColorAttributeName]);
        [run appendFormat:@"\\cb%ld", (long)bg];
        CGFloat base = [a[NSBaselineOffsetAttributeName] doubleValue];
        [run appendString:base > 0 ? [NSString stringWithFormat:@"\\up%ld", lround(base * 2)] : base < 0 ? [NSString stringWithFormat:@"\\dn%ld", lround(-base * 2)] : @"\\up0"];
        if (![run isEqualToString:lastRun]) { [body appendString:run]; [body appendString:@" "]; lastRun = run; }
        NSString *t = [text substringWithRange:r];
        NSTextAttachment *att = a[NSAttachmentAttributeName];
        NSURL *link = link_of(a);
        if (att) {
            /* RTFD: the attachment's file in the package; plain RTF drops it (as Cocoa does) */
            if (files) {
                NSFileWrapper *fw = att.fileWrapper;
                NSData *data = fw.regularFileContents ?: att.contents ?: (att.image ? UIImagePNGRepresentation(att.image) : nil);
                NSString *name = fw.preferredFilename ?: fw.filename;
                if (!name.length) name = att.contents || fw ? @"Attachment" : @"Attachment.png";
                if (!name.pathExtension.length && !fw && att.image) name = [name stringByAppendingPathExtension:@"png"];
                NSString *unique = name;
                for (int i = 2; files[unique]; i++) unique = [NSString stringWithFormat:@"%@ %d.%@", name.stringByDeletingPathExtension, i, name.pathExtension];
                NSFileWrapper *copy = [[NSFileWrapper alloc] initRegularFileWithContents:data ?: [NSData data]];
                copy.preferredFilename = unique;
                files[unique] = copy;
                CGSize sz = att.bounds.size;
                if (sz.width <= 0 || sz.height <= 0) sz = att.image.size;
                for (NSUInteger k = 0; k < r.length; k++) {
                    NSMutableString *esc = [NSMutableString string];
                    rtf_escape(esc, unique);
                    [body appendFormat:@"{{\\NeXTGraphic %@ \\width%ld \\height%ld\n}\\'ac}", esc, lround(sz.width * 20), lround(sz.height * 20)];
                }
                attachmentCount++;
            }
        } else if (link) {
            NSMutableString *esc = [NSMutableString string];
            rtf_escape(esc, t);
            [body appendFormat:@"{\\field{\\*\\fldinst{HYPERLINK \"%@\"}}{\\fldrslt %@}}", link.absoluteString, esc];
        } else {
            rtf_escape(body, t);
        }
        atParagraphStart = [t hasSuffix:@"\n"] || [t hasSuffix:@"\u2029"];
    }];
    (void)attachmentCount;
    NSMutableString *o = [NSMutableString stringWithString:@"{\\rtf1\\ansi\\ansicpg1252\\cocoartf2822\n\\cocoatextscaling0\\cocoaplatform1"];
    [o appendString:@"{\\fonttbl"];
    for (NSUInteger i = 0; i < fonts.count; i++) {
        NSMutableString *esc = [NSMutableString string];
        rtf_escape(esc, fonts[i]);
        [o appendFormat:@"\\f%lu\\fnil\\fcharset0 %@;", (unsigned long)i, esc];
    }
    [o appendString:@"}\n{\\colortbl;"];
    for (NSString *c in colors) [o appendFormat:@"%@;", c];
    [o appendString:@"}\n"];
    NSValue *paper = docAttrs[NSPaperSizeDocumentAttribute], *margin = docAttrs[NSPaperMarginDocumentAttribute];
    if (paper) { CGSize p = paper.CGSizeValue; [o appendFormat:@"\\paperw%ld\\paperh%ld", lround(p.width * 20), lround(p.height * 20)]; }
    if (margin) { UIEdgeInsets m = margin.UIEdgeInsetsValue; [o appendFormat:@"\\margl%ld\\margr%ld\\margt%ld\\margb%ld", lround(m.left * 20), lround(m.right * 20), lround(m.top * 20), lround(m.bottom * 20)]; }
    if (docAttrs[NSViewModeDocumentAttribute]) [o appendFormat:@"\\vieww%ld\\viewh%ld\\viewkind%ld", 12000L, 15840L, (long)[docAttrs[NSViewModeDocumentAttribute] integerValue]];
    [o appendFormat:@"\\deftab%ld\n", lround(([docAttrs[NSDefaultTabIntervalDocumentAttribute] doubleValue] ?: 36) * 20)];
    [o appendString:body];
    [o appendString:@"}"];
    return [o dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
}

/* ---------------- HTML ---------------- */
static NSString *html_escape(NSString *t) {
    NSMutableString *o = [NSMutableString string];
    for (NSUInteger i = 0; i < t.length; i++) {
        unichar c = [t characterAtIndex:i];
        switch (c) {
        case '<': [o appendString:@"&lt;"]; break;
        case '>': [o appendString:@"&gt;"]; break;
        case '&': [o appendString:@"&amp;"]; break;
        case '"': [o appendString:@"&quot;"]; break;
        case 0x2028: [o appendString:@"<br>\n"]; break;
        case 0xFFFC: break;
        default: [o appendFormat:@"%C", c];
        }
    }
    return o;
}
static NSString *css_color(UIColor *c) {
    CGFloat v[4];
    if (!rgb(c, v)) return nil;
    return v[3] < 1 ? [NSString stringWithFormat:@"rgba(%ld, %ld, %ld, %.2f)", lround(v[0] * 255), lround(v[1] * 255), lround(v[2] * 255), v[3]]
                    : [NSString stringWithFormat:@"#%@%@%@", hex2(v[0]), hex2(v[1]), hex2(v[2])];
}
static NSString *css_font(UIFont *f) {
    NSString *family = f.familyName ?: @"Helvetica";
    if ([family hasPrefix:@"."]) family = @"-apple-system";
    else if ([family containsString:@" "]) family = [NSString stringWithFormat:@"'%@'", family];
    return [NSString stringWithFormat:@"%@%@%.1fpx %@", font_italic(f) ? @"italic " : @"", font_bold(f) ? @"bold " : @"", f.pointSize, family];
}

NSData *isim_ui_html_data(NSAttributedString *str, NSDictionary *docAttrs) {
    NSString *text = str.string;
    NSMutableArray<NSString *> *pClasses = [NSMutableArray array], *sClasses = [NSMutableArray array];
    NSMutableString *body = [NSMutableString string];
    NSUInteger start = 0;
    while (start < text.length) {
        NSRange nl = [text rangeOfString:@"\n" options:0 range:NSMakeRange(start, text.length - start)];
        NSUInteger end = nl.location == NSNotFound ? text.length : nl.location;
        NSRange para = NSMakeRange(start, end - start);
        NSDictionary *first = [str attributesAtIndex:start < text.length ? start : 0 effectiveRange:NULL];
        NSParagraphStyle *ps = first[NSParagraphStyleAttributeName] ?: NSParagraphStyle.defaultParagraphStyle;
        UIFont *pf = font_of(first);
        NSMutableString *pcss = [NSMutableString stringWithFormat:@"margin: %.1fpx %.1fpx %.1fpx %.1fpx; ", ps.paragraphSpacingBefore,
                                 ps.tailIndent < 0 ? -ps.tailIndent : 0.0, ps.paragraphSpacing, ps.headIndent];
        static const char *aligns[] = { "left", "center", "right", "justify", NULL };
        if (ps.alignment <= NSTextAlignmentJustified && aligns[ps.alignment] && ps.alignment != NSTextAlignmentLeft) [pcss appendFormat:@"text-align: %s; ", aligns[ps.alignment]];
        if (ps.firstLineHeadIndent != ps.headIndent) [pcss appendFormat:@"text-indent: %.1fpx; ", ps.firstLineHeadIndent - ps.headIndent];
        [pcss appendFormat:@"font: %@", css_font(pf)];
        NSUInteger pi = [pClasses indexOfObject:pcss];
        if (pi == NSNotFound) { [pClasses addObject:pcss]; pi = pClasses.count - 1; }
        [body appendFormat:@"<p class=\"p%lu\">", (unsigned long)pi + 1];
        if (!para.length) [body appendString:@"<br>"];
        [str enumerateAttributesInRange:para options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) {
            NSMutableString *scss = [NSMutableString string];
            UIFont *f = font_of(a);
            if (![f isEqual:pf]) [scss appendFormat:@"font: %@; ", css_font(f)];
            NSString *fg = css_color(a[NSForegroundColorAttributeName]);
            if (fg) [scss appendFormat:@"color: %@; ", fg];
            NSString *bg = css_color(a[NSBackgroundColorAttributeName]);
            if (bg) [scss appendFormat:@"background-color: %@; ", bg];
            BOOL u = [a[NSUnderlineStyleAttributeName] integerValue] != 0, s = [a[NSStrikethroughStyleAttributeName] integerValue] != 0;
            if (u || s) [scss appendFormat:@"text-decoration: %@%@%@; ", u ? @"underline" : @"", u && s ? @" " : @"", s ? @"line-through" : @""];
            CGFloat base = [a[NSBaselineOffsetAttributeName] doubleValue];
            if (base) [scss appendFormat:@"vertical-align: %@; ", base > 0 ? @"super" : @"sub"];
            NSString *t = html_escape([text substringWithRange:r]);
            NSURL *link = link_of(a);
            if (link) t = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", html_escape(link.absoluteString), t];
            if (scss.length) {
                NSString *k = [scss stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
                NSUInteger si = [sClasses indexOfObject:k];
                if (si == NSNotFound) { [sClasses addObject:k]; si = sClasses.count - 1; }
                [body appendFormat:@"<span class=\"s%lu\">%@</span>", (unsigned long)si + 1, t];
            } else [body appendString:t];
        }];
        [body appendString:@"</p>\n"];
        if (nl.location == NSNotFound) break;
        start = nl.location + 1;
    }
    NSMutableString *o = [NSMutableString stringWithString:
        @"<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">\n<html>\n<head>\n"
        @"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">\n<meta http-equiv=\"Content-Style-Type\" content=\"text/css\">\n"
        @"<title></title>\n<meta name=\"Generator\" content=\"Cocoa HTML Writer\">\n<style type=\"text/css\">\n"];
    for (NSUInteger i = 0; i < pClasses.count; i++) [o appendFormat:@"p.p%lu {%@}\n", (unsigned long)i + 1, pClasses[i]];
    for (NSUInteger i = 0; i < sClasses.count; i++) [o appendFormat:@"span.s%lu {%@}\n", (unsigned long)i + 1, sClasses[i]];
    [o appendString:@"</style>\n</head>\n<body>\n"];
    [o appendString:body];
    [o appendString:@"</body>\n</html>\n"];
    return [o dataUsingEncoding:NSUTF8StringEncoding];
}
