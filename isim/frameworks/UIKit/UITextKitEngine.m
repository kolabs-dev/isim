/* isim's TextKit engine (UITextKitPrivate.h): a string laid out paragraph by paragraph with Pango. */
#import "UITextKitPrivate.h"
#include <math.h>

@implementation __IsimTextLine
@end
@implementation __IsimTextAttachmentSlot
@end
@implementation __IsimTextPara
- (void)dealloc { isim_tl_free(tl); }
/* the UTF-8 byte offset of a UTF-16 index of this paragraph's content */
- (int)_byteFor:(NSUInteger)i {
    const int *m = (const int *)u2b.bytes; NSUInteger n = u2b.length / sizeof(int);
    return m[MIN(i, n - 1)];
}
/* the UTF-16 index of a byte offset */
- (NSUInteger)_indexForByte:(int)b {
    const int *m = (const int *)u2b.bytes; NSUInteger n = u2b.length / sizeof(int), lo = 0, hi = n - 1;
    while (lo < hi) { NSUInteger mid = (lo + hi + 1) / 2; if (m[mid] <= b) lo = mid; else hi = mid - 1; }
    return lo;
}
@end

CGRect isim_ui_attachment_bounds(NSTextAttachment *a) {
    CGRect b = a.bounds;
    if (b.size.width > 0 || b.size.height > 0) return b;
    CGSize s = a.image.size;
    return CGRectMake(b.origin.x, b.origin.y, s.width, s.height);
}

static int pango_align_for(NSTextAlignment a) {
    if (a == NSTextAlignmentNatural) a = isim_ui_drawing_rtl ? NSTextAlignmentRight : NSTextAlignmentLeft;
    return a == NSTextAlignmentCenter ? 1 : a == NSTextAlignmentRight ? 2 : 0;
}
static BOOL is_separator(unichar c) { return c == '\n' || c == '\r' || c == 0x2029 || c == 0x2028 || c == 0x85; }

@implementation __IsimTextEngine {
    NSAttributedString *_string;
    NSMutableArray<__IsimTextPara *> *_paras;
    NSMutableArray<__IsimTextLine *> *_lines;
    NSMutableArray<__IsimTextAttachmentSlot *> *_slots;
    CGFloat _width, _padding, _height;
    CGRect _used, _extra, _extraUsed;
    NSUInteger _laid;
    UIFont *_font; UIColor *_color;
    BOOL _extraLineWanted;
}
- (instancetype)initWithString:(NSAttributedString *)string width:(CGFloat)width padding:(CGFloat)padding font:(UIFont *)font color:(UIColor *)color maxLines:(NSUInteger)maxLines {
    return [self initWithString:string width:width padding:padding font:font color:color maxLines:maxLines extraLine:YES];
}
- (instancetype)initWithString:(NSAttributedString *)string width:(CGFloat)width padding:(CGFloat)padding font:(UIFont *)font color:(UIColor *)color
                      maxLines:(NSUInteger)maxLines extraLine:(BOOL)extraLine {
    if ((self = [super init])) {
        _extraLineWanted = extraLine;
        _string = [string copy] ?: [NSAttributedString new];
        _width = width; _padding = padding;
        _font = font ?: [UIFont systemFontOfSize:12]; _color = color ?: UIColor.labelColor;
        _paras = [NSMutableArray array]; _lines = [NSMutableArray array]; _slots = [NSMutableArray array];
        _used = CGRectNull; _extra = CGRectZero; _extraUsed = CGRectZero;
        [self _layout:maxLines];
    }
    return self;
}
- (NSAttributedString *)string { return _string; }
- (NSArray<__IsimTextPara *> *)paragraphs { return _paras; }
- (NSArray<__IsimTextLine *> *)lines { return _lines; }
- (NSArray<__IsimTextAttachmentSlot *> *)attachments { return _slots; }
- (CGRect)usedRect { return CGRectIsNull(_used) ? CGRectZero : _used; }
- (CGFloat)height { return _height; }
- (CGRect)extraLineRect { return _extra; }
- (CGRect)extraLineUsedRect { return _extraUsed; }
- (NSUInteger)laidLength { return _laid; }
- (CGFloat)width { return _width; }
- (CGFloat)padding { return _padding; }
- (BOOL)_wraps { return _width > 0 && _width < 1e6; }

/* a paragraph's Pango layout: its text (or a zero-width space for an empty paragraph, in the attributes there) */
- (void)_layoutParagraph:(__IsimTextPara *)p style:(NSParagraphStyle *)ps attrs:(NSDictionary *)emptyAttrs {
    NSAttributedString *s = p.string;
    BOOL empty = s.length == 0;
    if (empty) s = [[NSAttributedString alloc] initWithString:@"​" attributes:emptyAttrs];
    /* UTF-16 -> UTF-8 offsets */
    NSString *str = s.string; NSUInteger n = str.length;
    NSMutableData *map = [NSMutableData dataWithLength:(n + 1) * sizeof(int)];
    int *m = (int *)map.mutableBytes, b = 0;
    for (NSUInteger i = 0; i < n; i++) {
        m[i] = b;
        unichar c = [str characterAtIndex:i];
        if (c < 0x80) b += 1; else if (c < 0x800) b += 2;
        else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < n) { m[++i] = b; b += 4; }
        else b += 3;
    }
    m[n] = b;
    p->u2b = empty ? [NSData dataWithBytes:(int[]){ 0, 0 } length:2 * sizeof(int)] : map;
    /* geometry: indents, wrapping width */
    CGFloat head = ps.headIndent, first = ps.firstLineHeadIndent, tail = ps.tailIndent;
    CGFloat avail = [self _wraps] ? _width - 2 * _padding : 0;
    CGFloat textW = 0;
    if (avail > 0) {
        CGFloat right = tail > 0 ? tail : avail + tail;            /* tail: from the leading edge, or (<= 0) from the trailing edge */
        textW = fmax(1, right - head);
    }
    NSTextAlignment al = ps ? ps.alignment : NSTextAlignmentNatural; CGFloat spacing = ps.lineSpacing;
    NSString *mk = isim_ui_markup(s, _font, _color, &al, &spacing);
    /* attachments: inline boxes at their characters */
    NSMutableArray *slots = [NSMutableArray array];
    NSMutableData *bytes = [NSMutableData data], *boxes = [NSMutableData data];
    if (!empty) [s enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, s.length) options:0 usingBlock:^(id a, NSRange r, BOOL *stop) {
        if (![a isKindOfClass:[NSTextAttachment class]]) return;
        for (NSUInteger i = r.location; i < NSMaxRange(r); i++) {
            if ([str characterAtIndex:i] != NSAttachmentCharacter) continue;
            CGRect bb = isim_ui_attachment_bounds(a);
            int off = m[i]; double box[4] = { 0, -(bb.origin.y + bb.size.height), bb.size.width, bb.size.height };
            [bytes appendBytes:&off length:sizeof off]; [boxes appendBytes:box length:sizeof box];
            __IsimTextAttachmentSlot *sl = [__IsimTextAttachmentSlot new]; sl->index = p->content.location + i; sl.attachment = a;
            [slots addObject:sl];
        }
    }];
    p->tl = isim_tl_create(mk.UTF8String, textW, pango_align_for(al), spacing, first - head, (int)slots.count, bytes.bytes, boxes.bytes);
    p->textX = _padding + head;
    p.attachments = slots;
}
- (void)_layout:(NSUInteger)maxLines {
    NSString *str = _string.string;
    NSUInteger len = str.length, start = 0, nlines = 0;
    CGFloat y = 0;
    NSDictionary *typing = @{ NSFontAttributeName: _font, NSForegroundColorAttributeName: _color };
    BOOL stopped = NO;
    while (start < len && !stopped) {
        NSUInteger end = start; while (end < len && !is_separator([str characterAtIndex:end])) end++;
        NSUInteger sepEnd = end < len ? end + 1 : end;
        if (end < len && [str characterAtIndex:end] == '\r' && sepEnd < len && [str characterAtIndex:sepEnd] == '\n') sepEnd++;
        __IsimTextPara *p = [__IsimTextPara new];
        p->range = NSMakeRange(start, sepEnd - start); p->content = NSMakeRange(start, end - start);
        p.string = [_string attributedSubstringFromRange:p->content];
        NSDictionary *at = [_string attributesAtIndex:start effectiveRange:NULL];
        NSParagraphStyle *ps = at[NSParagraphStyleAttributeName];
        NSMutableDictionary *emptyAttrs = [typing mutableCopy]; [emptyAttrs addEntriesFromDictionary:at];
        [self _layoutParagraph:p style:ps attrs:emptyAttrs];
        CGFloat before = _paras.count ? ps.paragraphSpacingBefore : 0;
        p->y = y; p->textY = y + before;
        NSMutableArray *lines = [NSMutableArray array];
        int count = isim_tl_line_count(p->tl);
        CGFloat bottom = p->textY;
        for (int i = 0; i < count; i++) {
            if (maxLines && nlines >= maxLines) { stopped = YES; break; }
            int bs, bl; double r[4], base;
            isim_tl_line(p->tl, i, &bs, &bl, r, &base);
            __IsimTextLine *l = [__IsimTextLine new];
            NSUInteger a = p->content.location + (p->content.length ? [p _indexForByte:bs] : 0);
            NSUInteger b = p->content.location + (p->content.length ? [p _indexForByte:bs + bl] : 0);
            if (i == count - 1) b = NSMaxRange(p->range);               /* the separator belongs to the last line */
            l->range = NSMakeRange(a, b - a);
            CGFloat ux = p->textX + r[0] - _padding;
            l->used = CGRectMake(ux, p->textY + r[1], r[2] + 2 * _padding, r[3]);
            l->rect = CGRectMake(0, p->textY + r[1], [self _wraps] ? _width : CGRectGetMaxX(l->used), r[3]);
            if (!p->content.length) l->used.size.width = 2 * _padding;
            l->baseline = base - r[1];
            [lines addObject:l]; nlines++;
            bottom = CGRectGetMaxY(l->rect);
            _used = CGRectUnion(_used, l->used);
            _laid = NSMaxRange(l->range);
        }
        p.lines = lines;
        CGFloat after = end < len ? ps.paragraphSpacing : 0;
        p->height = bottom + after - p->y;
        y = p->y + p->height;
        [_lines addObjectsFromArray:lines];
        for (__IsimTextAttachmentSlot *sl in p.attachments) {
            CGRect cr = [self _charRectIn:p index:sl->index];
            CGRect bb = isim_ui_attachment_bounds(sl.attachment);
            __IsimTextLine *ln = [self lineForIndex:sl->index];
            CGFloat baseY = ln ? ln->rect.origin.y + ln->baseline : cr.origin.y;
            sl->frame = CGRectMake(cr.origin.x, baseY - bb.origin.y - bb.size.height, bb.size.width, bb.size.height);
            if (ln) [_slots addObject:sl];
        }
        [_paras addObject:p];
        start = sepEnd;
    }
    /* the extra line fragment: an empty text, or one ending with a paragraph separator */
    if (_extraLineWanted && !stopped && (len == 0 || is_separator([str characterAtIndex:len - 1])) && !(maxLines && nlines >= maxLines)) {
        NSDictionary *at = len ? [_string attributesAtIndex:len - 1 effectiveRange:NULL] : @{};
        NSMutableDictionary *attrs = [typing mutableCopy]; [attrs addEntriesFromDictionary:at];
        __IsimTextPara *p = [__IsimTextPara new];
        p->range = NSMakeRange(len, 0); p->content = NSMakeRange(len, 0);
        p.string = [NSAttributedString new];
        NSParagraphStyle *ps = attrs[NSParagraphStyleAttributeName];
        [self _layoutParagraph:p style:ps attrs:attrs];
        int bs, bl; double r[4], base;
        isim_tl_line(p->tl, 0, &bs, &bl, r, &base);
        CGFloat before = _paras.count ? ps.paragraphSpacingBefore : 0;
        p->y = y; p->textY = y + before;
        _extra = CGRectMake(0, p->textY, [self _wraps] ? _width : 2 * _padding, r[3]);
        _extraUsed = CGRectMake(p->textX + r[0] - _padding, p->textY, 2 * _padding, r[3]);
        p->height = CGRectGetMaxY(_extra) - p->y;
        p.lines = @[];
        [_paras addObject:p];
        _used = CGRectUnion(_used, _extraUsed);
        y = CGRectGetMaxY(_extra);
    } else if (_paras.count) y = CGRectGetMaxY(_lines.lastObject ? _lines.lastObject->rect : CGRectZero);
    _height = y;
}

/* ---- queries ---- */
- (__IsimTextPara *)paragraphForIndex:(NSUInteger)i {
    for (__IsimTextPara *p in _paras) if (i < NSMaxRange(p->range) || (p->range.length == 0 && i == p->range.location)) return p;
    return _paras.lastObject;
}
- (__IsimTextLine *)lineForIndex:(NSUInteger)i {
    __IsimTextLine *last = nil;
    for (__IsimTextLine *l in _lines) { if (i >= l->range.location && i < NSMaxRange(l->range)) return l; last = l; }
    return i >= _string.length ? last : nil;
}
- (CGRect)_charRectIn:(__IsimTextPara *)p index:(NSUInteger)i {
    NSUInteger rel = i > p->content.location ? i - p->content.location : 0;
    rel = MIN(rel, p->content.length);
    double r[4]; isim_tl_index_rect(p->tl, p->content.length ? [p _byteFor:rel] : 0, r);
    return CGRectMake(p->textX + r[0], p->textY + r[1], r[2], r[3]);
}
- (CGRect)caretRectForIndex:(NSUInteger)i {
    NSUInteger len = _string.length;
    if (i > len) i = len;
    __IsimTextPara *p = [self paragraphForIndex:i];
    if (!p) return CGRectMake(_padding, 0, 0, ceil(_font.lineHeight));
    if (i == len && !CGRectIsEmpty(_extra) && p->range.length == 0) {      /* on the extra line */
        CGRect r = [self _charRectIn:p index:i];
        return CGRectMake(r.origin.x, _extra.origin.y, 0, _extra.size.height);
    }
    /* a wrapped line's end: the insertion point after its last character stays on that line */
    __IsimTextLine *l = [self lineForIndex:i];
    CGRect r = [self _charRectIn:p index:MIN(i, NSMaxRange(p->content))];
    if (l && i > l->range.location && i == NSMaxRange(l->range) && i < NSMaxRange(p->content)) {
        CGRect prev = [self _charRectIn:p index:i - 1];
        return CGRectMake(CGRectGetMaxX(prev), prev.origin.y, 0, prev.size.height);
    }
    if (l) { r.origin.y = l->rect.origin.y; r.size.height = l->rect.size.height; }
    return CGRectMake(r.origin.x, r.origin.y, 0, r.size.height);
}
- (CGRect)rectForCharacterAtIndex:(NSUInteger)i {
    __IsimTextPara *p = [self paragraphForIndex:i];
    if (!p) return CGRectZero;
    if (i >= NSMaxRange(p->content)) {                                        /* a separator: a zero-width box at the line end */
        CGRect c = [self caretRectForIndex:i];
        return CGRectMake(c.origin.x, c.origin.y, 0, c.size.height);
    }
    CGRect r = [self _charRectIn:p index:i];
    __IsimTextLine *l = [self lineForIndex:i];
    if (l) { r.origin.y = l->rect.origin.y; r.size.height = l->rect.size.height; }
    if (r.size.width < 0) { r.origin.x += r.size.width; r.size.width = -r.size.width; }
    return r;
}
- (NSUInteger)characterIndexForPoint:(CGPoint)pt fraction:(CGFloat *)fraction {
    if (fraction) *fraction = 0;
    if (!_lines.count) return 0;
    __IsimTextLine *line = _lines.firstObject;
    for (__IsimTextLine *l in _lines) { line = l; if (pt.y < CGRectGetMaxY(l->rect)) break; }
    __IsimTextPara *p = [self paragraphForIndex:line->range.location];
    double ly = line->rect.origin.y - p->textY + line->rect.size.height / 2;
    int tr = 0, b = isim_tl_index_at(p->tl, pt.x - p->textX, ly, &tr);
    NSUInteger i = p->content.length ? p->content.location + [p _indexForByte:b] : p->content.location;
    if (i >= NSMaxRange(line->range)) i = NSMaxRange(line->range) ? NSMaxRange(line->range) - 1 : 0;
    if (i < line->range.location) i = line->range.location;
    if (fraction && i < _string.length) {
        CGRect r = [self rectForCharacterAtIndex:i];
        *fraction = r.size.width > 0 ? fmax(0, fmin(1, (pt.x - r.origin.x) / r.size.width)) : 0;
    }
    return MIN(i, _string.length);
}
- (NSUInteger)insertionIndexForPoint:(CGPoint)pt {
    NSUInteger len = _string.length;
    if (!CGRectIsEmpty(_extra) && pt.y >= _extra.origin.y) return len;
    if (!_lines.count) return 0;
    CGFloat f; NSUInteger i = [self characterIndexForPoint:pt fraction:&f];
    __IsimTextLine *l = [self lineForIndex:i];
    __IsimTextPara *p = [self paragraphForIndex:i];
    if (i >= NSMaxRange(p->content)) return MIN(NSMaxRange(p->content), len);   /* past the line's text: before the separator */
    if (f > 0.5) {
        NSRange cs = [_string.string rangeOfComposedCharacterSequenceAtIndex:i];
        i = NSMaxRange(cs);
        if (l && i == NSMaxRange(l->range) && i < NSMaxRange(p->content) && l != _lines.lastObject) return i;   /* a wrapped line's end */
    }
    if (i < len) { NSRange cs = [_string.string rangeOfComposedCharacterSequenceAtIndex:i]; i = cs.location; }
    return MIN(i, len);
}
- (NSArray<NSValue *> *)rectsForRange:(NSRange)r {
    NSMutableArray *out = [NSMutableArray array];
    for (__IsimTextLine *l in _lines) {
        NSRange in = NSIntersectionRange(l->range, r);
        if (!in.length && !(r.length == 0 && r.location == l->range.location)) continue;
        __IsimTextPara *p = [self paragraphForIndex:l->range.location];
        NSUInteger textEnd = MIN(NSMaxRange(l->range), NSMaxRange(p->content));
        CGFloat x0 = [self caretRectForIndex:MAX(r.location, l->range.location)].origin.x;
        CGFloat x1 = NSMaxRange(r) >= NSMaxRange(l->range) && NSMaxRange(r) > textEnd ? CGRectGetMaxX(l->used)
                   : NSMaxRange(r) >= textEnd ? CGRectGetMaxX([self rectForCharacterAtIndex:textEnd > l->range.location ? textEnd - 1 : textEnd])
                   : [self caretRectForIndex:NSMaxRange(r)].origin.x;
        if (NSMaxRange(r) > NSMaxRange(l->range)) x1 = fmax(x1, [self _wraps] ? _width - _padding : CGRectGetMaxX(l->used));   /* continues on the next line */
        [out addObject:[NSValue valueWithCGRect:CGRectMake(fmin(x0, x1), l->rect.origin.y, fabs(x1 - x0), l->rect.size.height)]];
    }
    return out;
}
- (CGRect)boundingRectForRange:(NSRange)r {
    CGRect u = CGRectNull;
    for (NSValue *v in [self rectsForRange:r]) u = CGRectUnion(u, v.CGRectValue);
    return CGRectIsNull(u) ? CGRectZero : u;
}

/* ---- drawing ---- */
- (void)drawRange:(NSRange)range atPoint:(CGPoint)o skipAttachmentViews:(BOOL)skip {
    double black[4] = { 0, 0, 0, 1 };
    for (__IsimTextPara *p in _paras) {
        if (!p->content.length || !p.lines.count) continue;
        if (NSMaxRange(p->range) <= range.location || p->range.location >= NSMaxRange(range)) continue;
        __IsimTextLine *last = p.lines.lastObject;
        BOOL clip = NSMaxRange(last->range) < NSMaxRange(p->range) || (range.location > p->range.location || NSMaxRange(range) < NSMaxRange(p->range));
        if (clip) {                                     /* only its laid out lines (and those in the range) */
            isim_gfx_save();
            isim_path_begin();
            for (__IsimTextLine *l in p.lines)
                if (NSIntersectionRange(l->range, range).length) isim_path_rect(o.x - 10000, o.y + l->rect.origin.y, 20000 + l->rect.size.width, l->rect.size.height, 0);
            isim_gfx_clip_path();
        }
        isim_tl_draw(p->tl, o.x + p->textX, o.y + p->textY, black);
        for (__IsimTextAttachmentSlot *sl in p.attachments) {
            if (skip && sl.attachment.usesTextAttachmentView) continue;
            CGRect f = CGRectOffset(sl->frame, o.x, o.y);
            UIImage *img = [sl.attachment imageForBounds:CGRectMake(0, 0, f.size.width, f.size.height) textContainer:nil characterIndex:sl->index];
            [img drawInRect:f];
        }
        if (clip) isim_gfx_restore();
    }
}
@end
