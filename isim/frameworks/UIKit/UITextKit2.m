/* TextKit 2: locations and ranges, elements and paragraphs, content managers and the content storage, the text
 * layout manager with layout and line fragments, the viewport layout controller, and selections.
 *
 * Adapted: a location is an offset into the content storage's attributed string (__IsimTextLocation); the content
 * storage's elements are its paragraphs (NSTextParagraph, or what its delegate makes), and the layout manager lays
 * each out as one layout fragment with isim's TextKit engine (Pango), stacking them down the text container. The
 * whole document is laid out when a fragment is needed (no estimated layout); rendering attributes and link
 * rendering attributes are applied when fragments are laid out. Selection navigation moves, extends and deletes
 * selections in logical order (one container, left to right lines), through its data source. */
#import "UITextKitPrivate.h"

/* ================= locations and ranges ================= */
@implementation __IsimTextLocation
+ (instancetype)at:(NSInteger)offset { __IsimTextLocation *l = [self new]; l->_offset = offset; return l; }
- (NSComparisonResult)compare:(id<NSTextLocation>)o {
    NSInteger b = isim_tk_offset(o);
    return _offset < b ? NSOrderedAscending : _offset > b ? NSOrderedDescending : NSOrderedSame;
}
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass:[__IsimTextLocation class]] && ((__IsimTextLocation *)o)->_offset == _offset); }
- (NSUInteger)hash { return (NSUInteger)_offset; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"%ld", (long)_offset]; }
@end
NSInteger isim_tk_offset(id<NSTextLocation> l) {
    if (!l) return 0;
    if ([(id)l isKindOfClass:[__IsimTextLocation class]]) return ((__IsimTextLocation *)l).offset;
    return 0;
}
NSTextRange *isim_tk_range(NSRange r) {
    return [[NSTextRange alloc] initWithLocation:[__IsimTextLocation at:(NSInteger)r.location] endLocation:[__IsimTextLocation at:(NSInteger)NSMaxRange(r)]];
}
NSRange isim_tk_nsrange(NSTextRange *r) {
    if (!r) return NSMakeRange(NSNotFound, 0);
    NSInteger a = isim_tk_offset(r.location), b = isim_tk_offset(r.endLocation);
    return NSMakeRange((NSUInteger)MAX(0, a), (NSUInteger)MAX(0, b - a));
}

@implementation NSTextRange
- (instancetype)initWithLocation:(id<NSTextLocation>)location endLocation:(id<NSTextLocation>)end {
    if (!location) return nil;
    if (end && [location compare:end] == NSOrderedDescending) return nil;
    if ((self = [super init])) { _location = location; _endLocation = end ?: location; }
    return self;
}
- (instancetype)initWithLocation:(id<NSTextLocation>)location { return [self initWithLocation:location endLocation:location]; }
- (BOOL)isEmpty { return [_location compare:_endLocation] == NSOrderedSame; }
- (BOOL)isEqualToTextRange:(NSTextRange *)r { return r && [_location compare:r.location] == NSOrderedSame && [_endLocation compare:r.endLocation] == NSOrderedSame; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSTextRange class]] && [self isEqualToTextRange:o]; }
- (NSUInteger)hash { return [(NSObject *)_location hash] * 31 + [(NSObject *)_endLocation hash]; }
- (BOOL)containsLocation:(id<NSTextLocation>)l { return [_location compare:l] != NSOrderedDescending && [l compare:_endLocation] == NSOrderedAscending; }
- (BOOL)containsRange:(NSTextRange *)r { return [_location compare:r.location] != NSOrderedDescending && [r.endLocation compare:_endLocation] != NSOrderedDescending; }
- (BOOL)intersectsWithTextRange:(NSTextRange *)r { return [_location compare:r.endLocation] == NSOrderedAscending && [r.location compare:_endLocation] == NSOrderedAscending; }
- (NSTextRange *)textRangeByIntersectingWithTextRange:(NSTextRange *)r {
    id<NSTextLocation> a = [_location compare:r.location] == NSOrderedDescending ? _location : r.location;
    id<NSTextLocation> b = [_endLocation compare:r.endLocation] == NSOrderedAscending ? _endLocation : r.endLocation;
    return [a compare:b] == NSOrderedDescending ? nil : [[NSTextRange alloc] initWithLocation:a endLocation:b];
}
- (NSTextRange *)textRangeByFormingUnionWithTextRange:(NSTextRange *)r {
    id<NSTextLocation> a = [_location compare:r.location] == NSOrderedAscending ? _location : r.location;
    id<NSTextLocation> b = [_endLocation compare:r.endLocation] == NSOrderedDescending ? _endLocation : r.endLocation;
    return [[NSTextRange alloc] initWithLocation:a endLocation:b];
}
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p %@...%@>", self.class, self, _location, _endLocation]; }
@end

/* ================= elements ================= */
@implementation NSTextElement
- (instancetype)initWithTextContentManager:(NSTextContentManager *)m { if ((self = [super init])) _textContentManager = m; return self; }
- (NSArray *)childElements { return @[]; }
- (NSTextElement *)parentElement { return nil; }
- (BOOL)isRepresentedElement { return YES; }
@end
@implementation NSTextParagraph {
    NSAttributedString *_attributedString;
}
- (instancetype)initWithAttributedString:(NSAttributedString *)s {
    if ((self = [super initWithTextContentManager:nil])) _attributedString = [s copy] ?: [NSAttributedString new];
    return self;
}
- (NSAttributedString *)attributedString { return _attributedString; }
/* the content (and separator) within the element range */
- (NSUInteger)_isimContentLength {
    NSString *s = self.attributedString.string; NSUInteger n = s.length;
    while (n > 0) { unichar c = [s characterAtIndex:n - 1]; if (c == '\n' || c == '\r' || c == 0x2029 || c == 0x2028) n--; else break; }
    return n;
}
- (NSTextRange *)paragraphContentRange {
    if (!self.elementRange) return nil;
    NSInteger a = isim_tk_offset(self.elementRange.location);
    return isim_tk_range(NSMakeRange((NSUInteger)a, [self _isimContentLength]));
}
- (NSTextRange *)paragraphSeparatorRange {
    if (!self.elementRange) return nil;
    NSUInteger n = [self _isimContentLength], len = _attributedString.length;
    if (n == len) return nil;
    NSInteger a = isim_tk_offset(self.elementRange.location);
    return isim_tk_range(NSMakeRange((NSUInteger)a + n, len - n));
}
@end

/* ================= content managers ================= */
@interface NSTextLayoutManager (IsimContent)
- (void)_isimContentChanged:(NSRange)range;
- (void)_isimSetContentManager:(NSTextContentManager *)m;
@end
@implementation NSTextContentManager {
    NSMutableArray<NSTextLayoutManager *> *_layoutManagers;
    NSInteger _transaction;
    BOOL _changedInTransaction;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)init {
    if ((self = [super init])) { _layoutManagers = [NSMutableArray array]; _automaticallySynchronizesTextLayoutManagers = YES; _automaticallySynchronizesToBackingStore = YES; }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (NSArray<NSTextLayoutManager *> *)textLayoutManagers { return [_layoutManagers copy]; }
- (void)addTextLayoutManager:(NSTextLayoutManager *)m {
    if (!m || [_layoutManagers containsObject:m]) return;
    [_layoutManagers addObject:m];
    if (!_primaryTextLayoutManager) _primaryTextLayoutManager = m;
    [m _isimSetContentManager:self];
}
- (void)removeTextLayoutManager:(NSTextLayoutManager *)m {
    if (![_layoutManagers containsObject:m]) return;
    [_layoutManagers removeObject:m];
    if (_primaryTextLayoutManager == m) _primaryTextLayoutManager = _layoutManagers.firstObject;
    [m _isimSetContentManager:nil];
}
- (void)synchronizeTextLayoutManagers:(void (^)(NSError *))done {
    for (NSTextLayoutManager *m in _layoutManagers) [m _isimContentChanged:NSMakeRange(0, NSUIntegerMax)];
    if (done) done(nil);
}
- (BOOL)hasEditingTransaction { return _transaction > 0; }
- (void)performEditingTransactionUsingBlock:(void (NS_NOESCAPE ^)(void))transaction {
    _transaction++;
    if (transaction) transaction();
    _transaction--;
    if (!_transaction && _changedInTransaction) { _changedInTransaction = NO; if (_automaticallySynchronizesTextLayoutManagers) [self synchronizeTextLayoutManagers:nil]; }
}
- (void)recordEditActionInRange:(NSTextRange *)original newTextRange:(NSTextRange *)newRange { [self _isimChanged:isim_tk_nsrange(newRange)]; }
- (void)_isimChanged:(NSRange)r {
    if (_transaction) { _changedInTransaction = YES; return; }
    if (_automaticallySynchronizesTextLayoutManagers) for (NSTextLayoutManager *m in [_layoutManagers copy]) [m _isimContentChanged:r];
}
- (NSArray<NSTextElement *> *)textElementsForRange:(NSTextRange *)range {
    NSMutableArray *out = [NSMutableArray array];
    [self enumerateTextElementsFromLocation:range.location options:0 usingBlock:^BOOL(NSTextElement *e) {
        if (e.elementRange && [e.elementRange.location compare:range.endLocation] != NSOrderedAscending && !range.isEmpty) return NO;
        [out addObject:e];
        return !range.isEmpty;
    }];
    return out;
}
/* NSTextElementProvider: subclasses provide content */
- (NSTextRange *)documentRange { return isim_tk_range(NSMakeRange(0, 0)); }
- (id<NSTextLocation>)enumerateTextElementsFromLocation:(id<NSTextLocation>)l options:(NSTextContentManagerEnumerationOptions)o usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextElement *))block { return nil; }
- (void)replaceContentsInRange:(NSTextRange *)range withTextElements:(NSArray<NSTextElement *> *)elements {}
- (void)synchronizeToBackingStore:(void (^)(NSError *))done { if (done) done(nil); }
- (id<NSTextLocation>)locationFromLocation:(id<NSTextLocation>)l withOffset:(NSInteger)offset { return [__IsimTextLocation at:isim_tk_offset(l) + offset]; }
- (NSInteger)offsetFromLocation:(id<NSTextLocation>)from toLocation:(id<NSTextLocation>)to { return isim_tk_offset(to) - isim_tk_offset(from); }
- (NSTextRange *)adjustedRangeFromRange:(NSTextRange *)r forEditingTextSelection:(BOOL)f { return r; }
@end

@implementation NSTextContentStorage {
    NSTextStorage *_storage;
    NSArray<NSTextParagraph *> *_paragraphs;
}
@synthesize textStorage = _weakStorage;
- (instancetype)init {
    if ((self = [super init])) { _storage = [NSTextStorage new]; _storage.textStorageObserver = self; _weakStorage = _storage; }
    return self;
}
- (NSTextStorage *)textStorage { return _weakStorage; }
- (void)setTextStorage:(NSTextStorage *)s {
    if (_storage.textStorageObserver == self) _storage.textStorageObserver = nil;
    _storage = s; _weakStorage = s;
    s.textStorageObserver = self;
    [self _isimInvalidateParagraphs:NSMakeRange(0, NSUIntegerMax)];
}
- (NSAttributedString *)attributedString { return _storage ? [_storage attributedSubstringFromRange:NSMakeRange(0, _storage.length)] : nil; }
- (void)setAttributedString:(NSAttributedString *)s { [_storage setAttributedString:s ?: [NSAttributedString new]]; }
- (void)_isimInvalidateParagraphs:(NSRange)r { _paragraphs = nil; [self _isimChanged:r]; }
/* the paragraphs (made by the delegate when it wants to) */
- (NSArray<NSTextParagraph *> *)_isimParagraphs {
    if (_paragraphs) return _paragraphs;
    NSMutableArray *out = [NSMutableArray array];
    NSString *s = _storage.string; NSUInteger len = s.length, start = 0;
    id<NSTextContentStorageDelegate> d = (id<NSTextContentStorageDelegate>)self.delegate;
    while (start < len) {
        NSUInteger end = start;
        while (end < len) { unichar c = [s characterAtIndex:end]; end++; if (c == '\n' || c == 0x2029 || c == 0x2028 || (c == '\r' && !(end < len && [s characterAtIndex:end] == '\n'))) break; }
        NSRange r = NSMakeRange(start, end - start);
        NSTextParagraph *p = [d respondsToSelector:@selector(textContentStorage:textParagraphWithRange:)] ? [d textContentStorage:self textParagraphWithRange:r] : nil;
        if (!p) p = [[NSTextParagraph alloc] initWithAttributedString:[_storage attributedSubstringFromRange:r]];
        p.textContentManager = self;
        p.elementRange = isim_tk_range(r);
        [out addObject:p];
        start = end;
    }
    _paragraphs = out;
    return out;
}
- (NSTextRange *)documentRange { return isim_tk_range(NSMakeRange(0, _storage.length)); }
- (id<NSTextLocation>)enumerateTextElementsFromLocation:(id<NSTextLocation>)l options:(NSTextContentManagerEnumerationOptions)o usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextElement *))block {
    NSArray<NSTextParagraph *> *ps = [self _isimParagraphs];
    if (!ps.count) return nil;
    BOOL reverse = o & NSTextContentManagerEnumerationOptionsReverse;
    NSInteger start = reverse ? (NSInteger)ps.count - 1 : 0;
    if (l) {
        NSInteger off = isim_tk_offset(l);
        for (NSUInteger i = 0; i < ps.count; i++) { NSRange r = isim_tk_nsrange(ps[i].elementRange); if ((NSInteger)r.location <= off && off < (NSInteger)NSMaxRange(r)) { start = (NSInteger)i; break; } if (i == ps.count - 1 && off >= (NSInteger)NSMaxRange(r)) start = reverse ? (NSInteger)i : (NSInteger)ps.count; }
    }
    id<NSTextContentManagerDelegate> d = self.delegate;
    id<NSTextLocation> last = nil;
    for (NSInteger i = start; i >= 0 && i < (NSInteger)ps.count; i += reverse ? -1 : 1) {
        NSTextParagraph *p = ps[(NSUInteger)i];
        if ([d respondsToSelector:@selector(textContentManager:shouldEnumerateTextElement:options:)] && ![d textContentManager:self shouldEnumerateTextElement:p options:o]) continue;
        last = reverse ? p.elementRange.location : p.elementRange.endLocation;
        if (!block(p)) break;
    }
    return last;
}
- (void)replaceContentsInRange:(NSTextRange *)range withTextElements:(NSArray<NSTextElement *> *)elements {
    NSMutableAttributedString *m = [NSMutableAttributedString new];
    for (NSTextElement *e in elements) { NSAttributedString *a = [self attributedStringForTextElement:e]; if (a) [m appendAttributedString:a]; }
    [_storage replaceCharactersInRange:isim_tk_nsrange(range) withAttributedString:m];
}
- (NSAttributedString *)attributedStringForTextElement:(NSTextElement *)e { return [e isKindOfClass:[NSTextParagraph class]] ? ((NSTextParagraph *)e).attributedString : nil; }
- (NSTextElement *)textElementForAttributedString:(NSAttributedString *)s { return [[NSTextParagraph alloc] initWithAttributedString:s]; }
- (id<NSTextLocation>)locationFromLocation:(id<NSTextLocation>)l withOffset:(NSInteger)offset {
    NSInteger o = isim_tk_offset(l) + offset;
    if (o < 0 || o > (NSInteger)_storage.length) return nil;
    return [__IsimTextLocation at:o];
}
- (NSInteger)offsetFromLocation:(id<NSTextLocation>)from toLocation:(id<NSTextLocation>)to { return isim_tk_offset(to) - isim_tk_offset(from); }
- (NSTextRange *)adjustedRangeFromRange:(NSTextRange *)r forEditingTextSelection:(BOOL)f {
    NSRange n = isim_tk_nsrange(r);                         /* whole composed characters */
    if (n.location >= _storage.length) return r;
    NSString *str = _storage.string; NSRange in = NSIntersectionRange(n, NSMakeRange(0, _storage.length));
    NSUInteger a0 = [str rangeOfComposedCharacterSequenceAtIndex:in.location].location;
    NSUInteger a1 = in.length ? NSMaxRange([str rangeOfComposedCharacterSequenceAtIndex:NSMaxRange(in) - 1]) : a0;
    NSRange a = NSMakeRange(a0, a1 - a0);
    return NSEqualRanges(a, n) ? r : isim_tk_range(a);
}
/* NSTextStorageObserving */
- (void)processEditingForTextStorage:(NSTextStorage *)ts edited:(NSTextStorageEditActions)mask range:(NSRange)r changeInLength:(NSInteger)delta invalidatedRange:(NSRange)inv {
    [self _isimInvalidateParagraphs:r];
}
- (void)performEditingTransactionForTextStorage:(NSTextStorage *)ts usingBlock:(void (NS_NOESCAPE ^)(void))transaction { [self performEditingTransactionUsingBlock:transaction]; }
@end

/* ================= line fragments ================= */
@implementation NSTextLineFragment {
    __IsimTextEngine *_engine;     /* the paragraph's layout (or the fragment's own) */
    CGPoint _origin;               /* the line's origin in the engine */
    NSRange _engineRange;          /* its characters in the engine */
    CGFloat _top;                  /* its layout fragment's top in the engine */
    BOOL _inFragment;              /* a line of a layout fragment (points relative to the fragment) */
}
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithAttributedString:(NSAttributedString *)s range:(NSRange)range {
    if ((self = [super init])) {
        _attributedString = [s copy] ?: [NSAttributedString new];
        _characterRange = range;
        _engine = [[__IsimTextEngine alloc] initWithString:[_attributedString attributedSubstringFromRange:range] width:0 padding:0 font:nil color:nil maxLines:1];
        __IsimTextLine *l = _engine.lines.firstObject;
        _typographicBounds = l ? CGRectMake(0, 0, l->used.size.width, l->rect.size.height) : CGRectZero;
        _glyphOrigin = CGPointMake(0, l ? l->baseline : 0);
        _engineRange = NSMakeRange(0, range.length);
    }
    return self;
}
- (instancetype)initWithString:(NSString *)s attributes:(NSDictionary *)a range:(NSRange)r {
    return [self initWithAttributedString:[[NSAttributedString alloc] initWithString:s ?: @"" attributes:a] range:r];
}
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithAttributedString:[NSAttributedString new] range:NSMakeRange(0, 0)]; }
- (void)encodeWithCoder:(NSCoder *)coder {}
/* a line of a laid out paragraph */
- (instancetype)initIsimWithEngine:(__IsimTextEngine *)e line:(__IsimTextLine *)l paragraph:(NSAttributedString *)s start:(NSUInteger)start top:(CGFloat)top {
    if ((self = [super init])) {
        _attributedString = s; _engine = e; _engineRange = l->range;
        _characterRange = NSMakeRange(l->range.location - start, l->range.length);
        _origin = l->rect.origin; _top = top; _inFragment = YES;
        _typographicBounds = CGRectMake(l->used.origin.x, l->rect.origin.y - top, l->used.size.width, l->rect.size.height);
        _glyphOrigin = CGPointMake(l->used.origin.x + e.padding, l->baseline);
    }
    return self;
}
- (CGPoint)locationForCharacterAtIndex:(NSInteger)i {
    NSUInteger k = (NSUInteger)MAX(0, i) - _characterRange.location + _engineRange.location;
    CGRect c = [_engine caretRectForIndex:k];
    return CGPointMake(c.origin.x, _glyphOrigin.y);
}
- (NSInteger)characterIndexForPoint:(CGPoint)p {
    NSUInteger i = [_engine insertionIndexForPoint:CGPointMake(p.x, p.y + (_inFragment ? _top : _origin.y))];
    i = MAX(i, _engineRange.location); i = MIN(i, NSMaxRange(_engineRange));
    return (NSInteger)(i - _engineRange.location + _characterRange.location);
}
- (CGFloat)fractionOfDistanceThroughGlyphForPoint:(CGPoint)p {
    CGFloat f = 0; [_engine characterIndexForPoint:CGPointMake(p.x, p.y + (_inFragment ? _top : _origin.y)) fraction:&f]; return f;
}
- (void)drawAtPoint:(CGPoint)p inContext:(CGContextRef)ctx {
    /* the line's top-left at p */
    [_engine drawRange:_engineRange atPoint:CGPointMake(p.x, p.y - _origin.y) skipAttachmentViews:YES];
}
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p range %@ bounds %@>", self.class, self, NSStringFromRange(_characterRange), NSStringFromCGRect(_typographicBounds)]; }
@end

/* ================= layout fragments ================= */
@interface NSTextLayoutFragment ()
@property (nonatomic, readwrite, weak) NSTextLayoutManager *textLayoutManager;
@end
@implementation NSTextLayoutFragment {
@public
    __IsimTextEngine *_engine;       /* the whole document's layout, shared by the fragments */
    NSRange _engineRange;            /* this fragment's characters in it */
    CGFloat _y, _height;
    BOOL _last;
    NSArray<NSTextLineFragment *> *_lineFragments;
    NSMutableArray<NSTextAttachmentViewProvider *> *_providers;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithTextElement:(NSTextElement *)e range:(NSTextRange *)r {
    if ((self = [super init])) { _textElement = e; _rangeInElement = r ?: e.elementRange; _providers = [NSMutableArray array]; }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder { return nil; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (NSRange)_isimRange { return isim_tk_nsrange(_rangeInElement); }
- (NSTextLayoutFragmentState)state { return _engine ? NSTextLayoutFragmentStateLayoutAvailable : NSTextLayoutFragmentStateNone; }
- (void)invalidateLayout { _engine = nil; _lineFragments = nil; }
- (CGRect)layoutFragmentFrame {
    if (!_engine) return CGRectMake(0, _y, 0, 0);
    CGFloat w = self.textLayoutManager.textContainer.size.width;
    if (!(w > 0 && w < 1e6)) w = CGRectGetMaxX(_engine.usedRect);
    return CGRectMake(0, _y, w, _height);
}
- (CGRect)renderingSurfaceBounds {
    CGRect f = self.layoutFragmentFrame;
    return CGRectMake(0, 0, fmax(f.size.width, CGRectGetMaxX(_engine.usedRect)), f.size.height);
}
/* the engine's lines of this fragment */
- (NSArray<__IsimTextLine *> *)_isimLines {
    NSMutableArray *out = [NSMutableArray array];
    for (__IsimTextLine *l in _engine.lines) if (l->range.location >= _engineRange.location && (l->range.location < NSMaxRange(_engineRange) || (!_engineRange.length && l->range.location == _engineRange.location))) [out addObject:l];
    return out;
}
- (CGFloat)leadingPadding { return _engine.padding; }
- (CGFloat)trailingPadding { return _engine.padding; }
- (CGFloat)topMargin { return 0; }
- (CGFloat)bottomMargin { return 0; }
- (NSArray<NSTextLineFragment *> *)textLineFragments {
    if (!_lineFragments && _engine) {
        NSMutableArray *out = [NSMutableArray array];
        NSAttributedString *para = [_engine.string attributedSubstringFromRange:_engineRange];
        for (__IsimTextLine *l in [self _isimLines]) [out addObject:[[NSTextLineFragment alloc] initIsimWithEngine:_engine line:l paragraph:para start:_engineRange.location top:_y]];
        _lineFragments = out;
    }
    return _lineFragments ?: @[];
}
- (NSTextLineFragment *)textLineFragmentForVerticalOffset:(CGFloat)y requiresExactMatch:(BOOL)exact {
    NSTextLineFragment *best = nil;
    for (NSTextLineFragment *l in self.textLineFragments) {
        CGRect b = l.typographicBounds;
        if (y >= b.origin.y && y < CGRectGetMaxY(b)) return l;
        if (!exact && (!best || y >= b.origin.y)) best = l;
    }
    return exact ? nil : best;
}
- (NSTextLineFragment *)textLineFragmentForTextLocation:(id<NSTextLocation>)loc isUpstreamAffinity:(BOOL)up {
    NSInteger off = isim_tk_offset(loc) - (NSInteger)[self _isimRange].location;
    NSTextLineFragment *prev = nil;
    for (NSTextLineFragment *l in self.textLineFragments) {
        NSRange r = l.characterRange;
        if (up && off == (NSInteger)r.location && prev) return prev;
        if (off >= (NSInteger)r.location && off < (NSInteger)NSMaxRange(r)) return l;
        prev = l;
    }
    return prev;
}
- (void)drawAtPoint:(CGPoint)p inContext:(CGContextRef)ctx {
    [_engine drawRange:_engineRange atPoint:CGPointMake(p.x, p.y - _y) skipAttachmentViews:YES];
}
- (NSArray<NSTextAttachmentViewProvider *> *)textAttachmentViewProviders { return [_providers copy]; }
- (CGRect)frameForTextAttachmentAtLocation:(id<NSTextLocation>)loc {
    NSInteger off = isim_tk_offset(loc) - (NSInteger)[self _isimRange].location + (NSInteger)_engineRange.location;
    for (__IsimTextAttachmentSlot *s in _engine.attachments) if ((NSInteger)s->index == off) return CGRectOffset(s->frame, 0, -_y);
    return CGRectZero;
}
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p range %@ frame %@>", self.class, self, NSStringFromRange([self _isimRange]), NSStringFromCGRect(self.layoutFragmentFrame)]; }
@end
@implementation NSTextLayoutFragment (NSTextViewportRenderingSurfaceKey)
@end
@implementation NSString (NSTextViewportRenderingSurfaceKey)
@end

/* ================= the layout manager ================= */
@interface __IsimRenderingRun : NSObject
@property (nonatomic) NSRange range;
@property (nonatomic, copy) NSDictionary *attributes;
@end
@implementation __IsimRenderingRun
@end

static NSDictionary *link_rendering;
/* the layout manager as the navigation's data source: its laid-out string and lines */
static NSString *tlm_string(NSTextLayoutManager *m) { return [m _isim_engine].string.string ?: @""; }
static NSRange granularity_range(NSString *str, NSTextSelectionGranularity g, NSUInteger i, __IsimTextEngine *engine) {
    NSUInteger n = str.length;
    if (!n) return NSMakeRange(0, 0);
    NSUInteger at = MIN(i, n - 1);
    switch (g) {
    case NSTextSelectionGranularityCharacter: return [str rangeOfComposedCharacterSequenceAtIndex:at];
    case NSTextSelectionGranularityParagraph: return [str paragraphRangeForRange:NSMakeRange(at, 0)];
    case NSTextSelectionGranularityLine: {
        __IsimTextLine *l = [engine lineForIndex:at];
        return l ? l->range : [str lineRangeForRange:NSMakeRange(at, 0)];
    }
    case NSTextSelectionGranularityWord: case NSTextSelectionGranularitySentence: {
        NSRange para = [str paragraphRangeForRange:NSMakeRange(at, 0)];
        __block NSRange found = NSMakeRange(NSNotFound, 0);
        NSStringEnumerationOptions o = g == NSTextSelectionGranularityWord ? NSStringEnumerationByWords : NSStringEnumerationBySentences;
        [str enumerateSubstringsInRange:para options:o | NSStringEnumerationSubstringNotRequired usingBlock:^(NSString *sub, NSRange r, NSRange enc, BOOL *stop) {
            if (at >= r.location && at < NSMaxRange(r)) { found = g == NSTextSelectionGranularitySentence ? enc : r; *stop = YES; }
        }];
        return found.location != NSNotFound ? found : [str rangeOfComposedCharacterSequenceAtIndex:at];   /* between words: the character */
    }
    }
    return NSMakeRange(at, 1);
}
@implementation NSTextLayoutManager {
    NSArray<NSTextLayoutFragment *> *_fragments;
    NSMutableArray<__IsimRenderingRun *> *_rendering;
    NSTextViewportLayoutController *_viewport;
    NSTextSelectionNavigation *_navigation;
    NSMutableDictionary *_providerCache;              /* attachment -> provider kept across fragment rebuilds */
    __IsimTextEngine *_engine;
}
@synthesize textContainer = _textContainer;
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)init {
    if ((self = [super init])) {
        _usesFontLeading = YES; _rendering = [NSMutableArray array]; _textSelections = @[];
        _viewport = [[NSTextViewportLayoutController alloc] initWithTextLayoutManager:self];
        _providerCache = [NSMutableDictionary dictionary];
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (NSTextViewportLayoutController *)textViewportLayoutController { return _viewport; }
- (void)_isimSetContentManager:(NSTextContentManager *)m { _textContentManager = m; [self _isimContentChanged:NSMakeRange(0, NSUIntegerMax)]; }
- (void)replaceTextContentManager:(NSTextContentManager *)m {
    NSTextContentManager *old = _textContentManager;
    [old removeTextLayoutManager:self];
    [m addTextLayoutManager:self];
}
- (NSTextContainer *)textContainer { return _textContainer; }
- (void)setTextContainer:(NSTextContainer *)c {
    if (_textContainer.textLayoutManager == self) _textContainer.textLayoutManager = nil;
    _textContainer = c; c.textLayoutManager = self;
    [self _isimContainerChanged];
}
- (void)_isimContainerChanged { [self _isimInvalidate]; }
- (void)_isimContentChanged:(NSRange)r { [self _isimInvalidate]; }
- (void)_isimInvalidate {
    for (NSTextLayoutFragment *f in _fragments) [self _isimRetireProviders:f];
    _fragments = nil; _engine = nil;
    id<NSTextViewportLayoutControllerDelegate> d = _viewport.delegate;
    if ([d respondsToSelector:@selector(textViewportLayoutControllerReceivedSetNeedsLayout:)]) [d textViewportLayoutControllerReceivedSetNeedsLayout:_viewport];
    isim_ui_set_needs_display();
}
- (NSTextRange *)documentRange { return _textContentManager.documentRange ?: isim_tk_range(NSMakeRange(0, 0)); }

/* the string a paragraph is laid out with: its attributes, then links' and the rendering attributes */
- (NSAttributedString *)_isimRenderedString:(NSAttributedString *)s at:(NSUInteger)start {
    NSMutableAttributedString *m = [s mutableCopy];
    NSRange whole = NSMakeRange(start, s.length);
    [s enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, s.length) options:0 usingBlock:^(id link, NSRange r, BOOL *stop) {
        if (link) [m addAttributes:[self renderingAttributesForLink:link atLocation:[__IsimTextLocation at:(NSInteger)(start + r.location)]] range:r];
    }];
    for (__IsimRenderingRun *run in _rendering) {
        NSRange in = NSIntersectionRange(run.range, whole);
        if (in.length) [m addAttributes:run.attributes range:NSMakeRange(in.location - start, in.length)];
    }
    return m;
}
/* lays out the document (its elements' strings, one after the other) once, and makes a fragment per element */
- (NSArray<NSTextLayoutFragment *> *)_isimFragments {
    if (_fragments) return _fragments;
    NSMutableArray *out = [NSMutableArray array];
    NSTextContentManager *cm = _textContentManager;
    CGFloat w = _textContainer ? _textContainer.size.width : 0, pad = _textContainer ? _textContainer.lineFragmentPadding : 0;
    id<NSTextLayoutManagerDelegate> d = _delegate;
    NSTextContentStorage *cs = [cm isKindOfClass:[NSTextContentStorage class]] ? (NSTextContentStorage *)cm : nil;
    NSMutableAttributedString *doc = [NSMutableAttributedString new];
    [cm enumerateTextElementsFromLocation:nil options:0 usingBlock:^BOOL(NSTextElement *e) {
        NSTextLayoutFragment *f = [d respondsToSelector:@selector(textLayoutManager:textLayoutFragmentForLocation:inTextElement:)]
            ? [d textLayoutManager:self textLayoutFragmentForLocation:e.elementRange.location inTextElement:e] : nil;
        if (!f) f = [[NSTextLayoutFragment alloc] initWithTextElement:e range:e.elementRange];
        f.textLayoutManager = self;
        NSAttributedString *s = cs ? [cs attributedStringForTextElement:e] : [e isKindOfClass:[NSTextParagraph class]] ? ((NSTextParagraph *)e).attributedString : nil;
        s = s ?: [NSAttributedString new];
        f->_engineRange = NSMakeRange(doc.length, s.length);
        [doc appendAttributedString:[self _isimRenderedString:s at:isim_tk_nsrange(e.elementRange).location]];
        [out addObject:f];
        return YES;
    }];
    __IsimTextEngine *engine = [[__IsimTextEngine alloc] initWithString:doc width:w padding:pad font:nil color:nil maxLines:0
                                                               extraLine:YES exclusionPaths:_textContainer.exclusionPaths];
    _engine = engine;
    for (NSTextLayoutFragment *f in out) {
        f->_engine = engine;
        __IsimTextPara *first = [engine paragraphForIndex:f->_engineRange.location];
        f->_y = first ? first->y : 0;
        CGFloat bottom = f->_y;
        for (__IsimTextPara *p in engine.paragraphs)
            if (p->range.location >= f->_engineRange.location && (p->range.location < NSMaxRange(f->_engineRange) || (f == out.lastObject && p->range.length == 0))) bottom = p->y + p->height;
        f->_height = bottom - f->_y;
    }
    _fragments = out;
    for (NSTextLayoutFragment *f in out) if (_renderingAttributesValidator) _renderingAttributesValidator(self, f);
    return out;
}
- (__IsimTextEngine *)_isim_engine { [self _isimFragments]; return _engine; }
- (CGRect)usageBoundsForTextContainer {
    CGRect u = CGRectZero;
    for (NSTextLayoutFragment *f in [self _isimFragments]) u = CGRectUnion(u, f.layoutFragmentFrame);
    return u;
}
- (void)ensureLayoutForRange:(NSTextRange *)r { [self _isimFragments]; }
- (void)ensureLayoutForBounds:(CGRect)b { [self _isimFragments]; }
- (void)invalidateLayoutForRange:(NSTextRange *)r { [self _isimInvalidate]; }
- (NSTextLayoutFragment *)textLayoutFragmentForPosition:(CGPoint)p {
    for (NSTextLayoutFragment *f in [self _isimFragments]) { CGRect fr = f.layoutFragmentFrame; if (p.y >= fr.origin.y && p.y < CGRectGetMaxY(fr)) return f; }
    return nil;
}
- (NSTextLayoutFragment *)textLayoutFragmentForLocation:(id<NSTextLocation>)l {
    NSInteger off = isim_tk_offset(l);
    NSArray *fs = [self _isimFragments];
    for (NSTextLayoutFragment *f in fs) { NSRange r = [f _isimRange]; if (off >= (NSInteger)r.location && off < (NSInteger)NSMaxRange(r)) return f; }
    return off >= (NSInteger)NSMaxRange([fs.lastObject _isimRange]) ? fs.lastObject : nil;
}
- (id<NSTextLocation>)enumerateTextLayoutFragmentsFromLocation:(id<NSTextLocation>)l options:(NSTextLayoutFragmentEnumerationOptions)o usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextLayoutFragment *))block {
    NSArray<NSTextLayoutFragment *> *fs = [self _isimFragments];
    if (!fs.count) return nil;
    BOOL reverse = o & NSTextLayoutFragmentEnumerationOptionsReverse;
    NSInteger start = reverse ? (NSInteger)fs.count - 1 : 0;
    if (l) { NSTextLayoutFragment *f = [self textLayoutFragmentForLocation:l]; if (f) start = (NSInteger)[fs indexOfObjectIdenticalTo:f]; }
    id<NSTextLocation> last = nil;
    for (NSInteger i = start; i >= 0 && i < (NSInteger)fs.count; i += reverse ? -1 : 1) {
        NSTextLayoutFragment *f = fs[(NSUInteger)i];
        last = reverse ? f.rangeInElement.location : f.rangeInElement.endLocation;
        if (!block(f)) break;
    }
    return last;
}
- (NSTextSelectionNavigation *)textSelectionNavigation {
    if (!_navigation) _navigation = [[NSTextSelectionNavigation alloc] initWithDataSource:self];
    return _navigation;
}
- (void)setTextSelectionNavigation:(NSTextSelectionNavigation *)n { _navigation = n; }

/* ---- rendering attributes ---- */
- (void)enumerateRenderingAttributesFromLocation:(id<NSTextLocation>)l reverse:(BOOL)reverse usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextLayoutManager *, NSDictionary *, NSTextRange *))block {
    NSInteger off = isim_tk_offset(l);
    NSArray *runs = [_rendering sortedArrayUsingComparator:^NSComparisonResult(__IsimRenderingRun *a, __IsimRenderingRun *b) {
        return a.range.location < b.range.location ? NSOrderedAscending : a.range.location > b.range.location ? NSOrderedDescending : NSOrderedSame; }];
    for (__IsimRenderingRun *r in reverse ? runs.reverseObjectEnumerator.allObjects : runs) {
        if (reverse ? (NSInteger)r.range.location > off : (NSInteger)NSMaxRange(r.range) <= off) continue;
        if (!block(self, r.attributes, isim_tk_range(r.range))) break;
    }
}
- (void)_isimRemoveRendering:(NSRange)range keys:(NSArray *)keys {
    NSMutableArray *next = [NSMutableArray array];
    for (__IsimRenderingRun *r in _rendering) {
        NSRange in = NSIntersectionRange(r.range, range);
        if (!in.length) { [next addObject:r]; continue; }
        void (^keep)(NSRange, NSDictionary *) = ^(NSRange part, NSDictionary *a) { if (!part.length || !a.count) return; __IsimRenderingRun *n = [__IsimRenderingRun new]; n.range = part; n.attributes = a; [next addObject:n]; };
        keep(NSMakeRange(r.range.location, in.location - r.range.location), r.attributes);
        NSMutableDictionary *mid = [r.attributes mutableCopy]; if (keys) [mid removeObjectsForKeys:keys]; else [mid removeAllObjects];
        keep(in, mid);
        keep(NSMakeRange(NSMaxRange(in), NSMaxRange(r.range) - NSMaxRange(in)), r.attributes);
    }
    _rendering = next;
}
- (void)setRenderingAttributes:(NSDictionary *)a forTextRange:(NSTextRange *)tr {
    NSRange r = isim_tk_nsrange(tr);
    [self _isimRemoveRendering:r keys:nil];
    if (a.count) { __IsimRenderingRun *n = [__IsimRenderingRun new]; n.range = r; n.attributes = a; [_rendering addObject:n]; }
    [self _isimInvalidate];
}
- (void)addRenderingAttribute:(NSAttributedStringKey)k value:(id)v forTextRange:(NSTextRange *)tr {
    if (!v) { [self removeRenderingAttribute:k forTextRange:tr]; return; }
    NSRange r = isim_tk_nsrange(tr);
    [self _isimRemoveRendering:r keys:@[k]];
    __IsimRenderingRun *n = [__IsimRenderingRun new]; n.range = r; n.attributes = @{ k: v }; [_rendering addObject:n];
    [self _isimInvalidate];
}
- (void)removeRenderingAttribute:(NSAttributedStringKey)k forTextRange:(NSTextRange *)tr { [self _isimRemoveRendering:isim_tk_nsrange(tr) keys:@[k]]; [self _isimInvalidate]; }
- (void)invalidateRenderingAttributesForTextRange:(NSTextRange *)tr { [self _isimInvalidate]; }
+ (NSDictionary *)linkRenderingAttributes { return link_rendering ?: @{ NSForegroundColorAttributeName: UIColor.linkColor }; }
+ (void)setLinkRenderingAttributes:(NSDictionary *)a { link_rendering = [a copy]; }
- (NSDictionary *)renderingAttributesForLink:(id)link atLocation:(id<NSTextLocation>)l {
    NSDictionary *def = NSTextLayoutManager.linkRenderingAttributes;
    id<NSTextLayoutManagerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(textLayoutManager:renderingAttributesForLink:atLocation:defaultAttributes:)]) return [d textLayoutManager:self renderingAttributesForLink:link atLocation:l defaultAttributes:def] ?: @{};
    return def;
}

/* ---- segments ---- */
- (void)enumerateTextSegmentsInRange:(NSTextRange *)tr type:(NSTextLayoutManagerSegmentType)type options:(NSTextLayoutManagerSegmentOptions)o
                          usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextRange *, CGRect, CGFloat, NSTextContainer *))block {
    NSRange r = isim_tk_nsrange(tr);
    __IsimTextEngine *e = [self _isim_engine];
    NSTextContainer *c = _textContainer;
    BOOL noRange = (o & NSTextLayoutManagerSegmentOptionsRangeNotRequired) != 0;
    if (r.length == 0) {                                        /* an insertion point */
        CGRect cr = [e caretRectForIndex:r.location];
        __IsimTextLine *l = [e lineForIndex:r.location];
        block(noRange ? nil : tr, cr, l ? l->baseline : 0, c);
        return;
    }
    for (__IsimTextLine *l in e.lines) {
        NSRange in = NSIntersectionRange(l->range, r);
        if (!in.length) continue;
        CGRect rect = [e boundingRectForRange:in];
        if (!block(noRange ? nil : isim_tk_range(in), rect, l->baseline, c)) return;
    }
}

/* ---- editing through the content manager ---- */
- (void)replaceContentsInRange:(NSTextRange *)range withTextElements:(NSArray<NSTextElement *> *)elements { [_textContentManager replaceContentsInRange:range withTextElements:elements]; }
- (void)replaceContentsInRange:(NSTextRange *)range withAttributedString:(NSAttributedString *)s {
    NSTextContentManager *cm = _textContentManager;
    if ([cm isKindOfClass:[NSTextContentStorage class]]) [((NSTextContentStorage *)cm).textStorage replaceCharactersInRange:isim_tk_nsrange(range) withAttributedString:s];
}

/* ---- attachment view providers (TextKit 2 text views) ---- */
/* the providers of a fragment: kept ones (reuse policy / delegate cache) first, else new */
- (NSArray<NSTextAttachmentViewProvider *> *)_isimProvidersFor:(NSTextLayoutFragment *)f parentView:(UIView *)parent reuse:(BOOL (^)(NSTextAttachment *))reuse {
    if (f->_providers.count) return f->_providers;
    NSUInteger start = [f _isimRange].location;
    for (__IsimTextAttachmentSlot *s in f->_engine.attachments) {
        if (!NSLocationInRange(s->index, f->_engineRange)) continue;
        NSTextAttachment *a = s.attachment;
        if (!a.usesTextAttachmentView) continue;
        id key = [NSValue valueWithNonretainedObject:a];
        NSTextAttachmentViewProvider *p = reuse && reuse(a) ? _providerCache[key] : nil;
        if (!p && [_delegate respondsToSelector:@selector(textLayoutManager:retrieveCachedTextAttachmentViewProviderForTextAttachment:)])
            p = [_delegate textLayoutManager:self retrieveCachedTextAttachmentViewProviderForTextAttachment:a];
        if (!p) {
            p = [a viewProviderForParentView:parent location:[__IsimTextLocation at:(NSInteger)(start + s->index - f->_engineRange.location)] textContainer:_textContainer];
            if (p && !p.view) [p loadView];
        }
        if (p) { [_providerCache removeObjectForKey:key]; [f->_providers addObject:p]; }
    }
    return f->_providers;
}
/* a fragment going away: its providers are offered to the delegate (iOS 27) and kept for reuse */
- (void)_isimRetireProviders:(NSTextLayoutFragment *)f {
    for (NSTextAttachmentViewProvider *p in f->_providers) {
        NSTextAttachment *a = p.textAttachment;
        if (!a) continue;
        if ([_delegate respondsToSelector:@selector(textLayoutManager:cacheTextAttachmentViewProvider:forTextAttachment:)])
            [_delegate textLayoutManager:self cacheTextAttachmentViewProvider:p forTextAttachment:a];
        _providerCache[[NSValue valueWithNonretainedObject:a]] = p;
    }
    [f->_providers removeAllObjects];
}
- (void)_isimDropProviderCache { _providerCache = [NSMutableDictionary dictionary]; }
/* NSTextSelectionDataSource */
- (void)enumerateSubstringsFromLocation:(id<NSTextLocation>)l options:(NSStringEnumerationOptions)o
                             usingBlock:(void (NS_NOESCAPE ^)(NSString *, NSTextRange *, NSTextRange *, BOOL *))block {
    NSString *str = tlm_string(self); NSUInteger at = (NSUInteger)MIN(MAX(0, isim_tk_offset(l)), (NSInteger)str.length);
    NSRange r = (o & NSStringEnumerationReverse) ? NSMakeRange(0, at) : NSMakeRange(at, str.length - at);
    [str enumerateSubstringsInRange:r options:o usingBlock:^(NSString *sub, NSRange sr, NSRange enc, BOOL *stop) {
        block(sub, isim_tk_range(sr), isim_tk_range(enc), stop);
    }];
}
- (NSTextRange *)textRangeForSelectionGranularity:(NSTextSelectionGranularity)g enclosingLocation:(id<NSTextLocation>)l {
    NSString *str = tlm_string(self);
    if (!str.length) return isim_tk_range(NSMakeRange(0, 0));
    return isim_tk_range(granularity_range(str, g, (NSUInteger)MAX(0, isim_tk_offset(l)), [self _isim_engine]));
}
- (id<NSTextLocation>)locationFromLocation:(id<NSTextLocation>)l withOffset:(NSInteger)offset {
    NSInteger o = isim_tk_offset(l) + offset;
    return o < 0 || o > (NSInteger)tlm_string(self).length ? nil : [__IsimTextLocation at:o];
}
- (NSInteger)offsetFromLocation:(id<NSTextLocation>)from toLocation:(id<NSTextLocation>)to { return isim_tk_offset(to) - isim_tk_offset(from); }
/* the paragraph style's direction, else the paragraph's first strong character's (Hebrew, Arabic and the like: right to left) */
- (NSTextSelectionNavigationWritingDirection)baseWritingDirectionAtLocation:(id<NSTextLocation>)l {
    NSAttributedString *as = [self _isim_engine].string; NSString *str = as.string;
    if (!str.length) return NSTextSelectionNavigationWritingDirectionLeftToRight;
    NSUInteger at = (NSUInteger)MIN(MAX(0, isim_tk_offset(l)), (NSInteger)str.length - 1);
    NSParagraphStyle *ps = [as attribute:NSParagraphStyleAttributeName atIndex:at effectiveRange:NULL];
    if (ps.baseWritingDirection != NSWritingDirectionNatural)
        return ps.baseWritingDirection == NSWritingDirectionRightToLeft ? NSTextSelectionNavigationWritingDirectionRightToLeft : NSTextSelectionNavigationWritingDirectionLeftToRight;
    NSRange para = [str paragraphRangeForRange:NSMakeRange(at, 0)];
    for (NSUInteger i = para.location; i < NSMaxRange(para); i++) {
        unichar c = [str characterAtIndex:i];
        if ((c >= 0x0590 && c <= 0x08FF) || (c >= 0xFB1D && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF)) return NSTextSelectionNavigationWritingDirectionRightToLeft;
        if ([[NSCharacterSet letterCharacterSet] characterIsMember:c]) break;
    }
    return NSTextSelectionNavigationWritingDirectionLeftToRight;
}
/* every insertion point of the line, left to right, at its caret's x */
- (void)enumerateCaretOffsetsInLineFragmentAtLocation:(id<NSTextLocation>)l usingBlock:(void (NS_NOESCAPE ^)(CGFloat, id<NSTextLocation>, BOOL, BOOL *))block {
    __IsimTextEngine *e = [self _isim_engine]; NSString *str = e.string.string;
    NSUInteger at = (NSUInteger)MIN(MAX(0, isim_tk_offset(l)), (NSInteger)str.length);
    __IsimTextLine *line = [e lineForIndex:at];
    NSRange r = line ? line->range : NSMakeRange(at, 0);
    NSUInteger end = NSMaxRange(r);
    while (end > r.location && end <= str.length && (([str characterAtIndex:end - 1] == '\n') || [str characterAtIndex:end - 1] == '\r')) end--;
    BOOL stop = NO;
    for (NSUInteger i = r.location; i <= end && !stop; i = i < end ? NSMaxRange([str rangeOfComposedCharacterSequenceAtIndex:i]) : end + 1)
        block([e caretRectForIndex:i].origin.x, [__IsimTextLocation at:(NSInteger)i], YES, &stop);
}
- (NSTextRange *)lineFragmentRangeForPoint:(CGPoint)p inContainerAtLocation:(id<NSTextLocation>)l {
    __IsimTextEngine *e = [self _isim_engine];
    __IsimTextLine *line = [e lineForIndex:[e insertionIndexForPoint:p]];
    return line ? isim_tk_range(line->range) : isim_tk_range(NSMakeRange(0, 0));
}
- (void)enumerateContainerBoundariesFromLocation:(id<NSTextLocation>)l reverse:(BOOL)reverse usingBlock:(void (NS_NOESCAPE ^)(id<NSTextLocation>, BOOL *))block {
    BOOL stop = NO;     /* one container: the document's ends */
    block([__IsimTextLocation at:reverse ? 0 : (NSInteger)tlm_string(self).length], &stop);
}
- (NSTextSelectionNavigationLayoutOrientation)textLayoutOrientationAtLocation:(id<NSTextLocation>)l { return NSTextSelectionNavigationLayoutOrientationHorizontal; }
@end

/* ================= the viewport ================= */
@implementation NSTextViewportLayoutController {
    NSMapTable<id, id> *_surfaces;            /* rendering surfaces of the fragments in the viewport, by key (iOS 27) */
}
- (instancetype)initWithTextLayoutManager:(NSTextLayoutManager *)m { if ((self = [super init])) _textLayoutManager = m; return self; }
/* iOS 27 rendering surfaces (isim's order; Apple documents none): a fragment entering the viewport gets the surface
   cached for it (retrieveCachedRenderingSurfaceForKey:), else a new one (renderingSurfaceForTextLayoutFragment:), right
   before configureRenderingSurfaceForTextLayoutFragment:; renderingSurfaceForKey: maps it while the fragment stays; a
   fragment leaving the viewport hands its surface back (cacheRenderingSurface:forKey:). Keys are the fragments. */
- (id<NSTextViewportRenderingSurface>)renderingSurfaceForKey:(id<NSTextViewportRenderingSurfaceKey>)key { return key ? [_surfaces objectForKey:key] : nil; }
- (void)layoutViewport {
    id<NSTextViewportLayoutControllerDelegate> d = _delegate;
    NSTextLayoutManager *m = _textLayoutManager;
    if (!d || !m) return;
    if (!_surfaces) _surfaces = [NSMapTable strongToStrongObjectsMapTable];
    _viewportBounds = [d viewportBoundsForTextViewportLayoutController:self];
    if ([d respondsToSelector:@selector(textViewportLayoutControllerWillLayout:)]) [d textViewportLayoutControllerWillLayout:self];
    __block NSTextRange *range = nil;
    CGRect vb = _viewportBounds;
    NSMutableSet *seen = [NSMutableSet set];
    BOOL ios27 = isim_ui_os_major() >= 27;                    /* (earlier versions have no rendering surfaces) */
    BOOL retrieve = ios27 && [d respondsToSelector:@selector(textViewportLayoutController:retrieveCachedRenderingSurfaceForKey:)];
    BOOL make = ios27 && [d respondsToSelector:@selector(textViewportLayoutController:renderingSurfaceForTextLayoutFragment:)];
    NSMapTable *surfaces = _surfaces;
    [m enumerateTextLayoutFragmentsFromLocation:nil options:NSTextLayoutFragmentEnumerationOptionsEnsuresLayout usingBlock:^BOOL(NSTextLayoutFragment *f) {
        CGRect fr = f.layoutFragmentFrame;
        if (CGRectGetMaxY(fr) < CGRectGetMinY(vb)) return YES;
        if (fr.origin.y > CGRectGetMaxY(vb)) return NO;
        range = range ? [range textRangeByFormingUnionWithTextRange:f.rangeInElement] : f.rangeInElement;
        [seen addObject:f];
        if (![surfaces objectForKey:f]) {
            id surface = retrieve ? [d textViewportLayoutController:self retrieveCachedRenderingSurfaceForKey:f] : nil;
            if (!surface && make) surface = [d textViewportLayoutController:self renderingSurfaceForTextLayoutFragment:f];
            if (surface) [surfaces setObject:surface forKey:f];
        }
        [d textViewportLayoutController:self configureRenderingSurfaceForTextLayoutFragment:f];
        return YES;
    }];
    for (id key in [[surfaces keyEnumerator] allObjects]) {              /* left the viewport: back to the delegate's cache */
        if ([seen containsObject:key]) continue;
        id surface = [surfaces objectForKey:key];
        [surfaces removeObjectForKey:key];
        if (ios27 && [d respondsToSelector:@selector(textViewportLayoutController:cacheRenderingSurface:forKey:)])
            [d textViewportLayoutController:self cacheRenderingSurface:surface forKey:key];
    }
    _viewportRange = range;
    if ([d respondsToSelector:@selector(textViewportLayoutControllerDidLayout:)]) [d textViewportLayoutControllerDidLayout:self];
}
- (CGFloat)relocateViewportToTextLocation:(id<NSTextLocation>)l {
    NSTextLayoutFragment *f = [_textLayoutManager textLayoutFragmentForLocation:l];
    return f ? f.layoutFragmentFrame.origin.y : 0;
}
- (void)adjustViewportByVerticalOffset:(CGFloat)dy { _viewportBounds = CGRectOffset(_viewportBounds, 0, dy); }
@end

/* ================= selections ================= */
@implementation NSTextSelection
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithRanges:(NSArray<NSTextRange *> *)ranges affinity:(NSTextSelectionAffinity)a granularity:(NSTextSelectionGranularity)g {
    if ((self = [super init])) { _textRanges = [ranges copy] ?: @[]; _affinity = a; _granularity = g; _typingAttributes = @{}; }
    return self;
}
- (instancetype)initWithRange:(NSTextRange *)r affinity:(NSTextSelectionAffinity)a granularity:(NSTextSelectionGranularity)g { return [self initWithRanges:r ? @[r] : @[] affinity:a granularity:g]; }
- (instancetype)initWithLocation:(id<NSTextLocation>)l affinity:(NSTextSelectionAffinity)a {
    return [self initWithRanges:@[[[NSTextRange alloc] initWithLocation:l]] affinity:a granularity:NSTextSelectionGranularityCharacter];
}
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithRanges:@[] affinity:NSTextSelectionAffinityDownstream granularity:NSTextSelectionGranularityCharacter]; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (BOOL)isTransient { return NO; }
- (id<NSTextLocation>)secondarySelectionLocation { return nil; }
- (NSTextSelection *)textSelectionWithTextRanges:(NSArray<NSTextRange *> *)ranges {
    NSTextSelection *s = [[NSTextSelection alloc] initWithRanges:ranges affinity:_affinity granularity:_granularity];
    s.typingAttributes = _typingAttributes; s.anchorPositionOffset = _anchorPositionOffset; s.logical = _logical;
    return s;
}
@end
/* ================= selection navigation ================= */

@implementation NSTextSelectionNavigation
- (instancetype)initWithDataSource:(id<NSTextSelectionDataSource>)ds { if ((self = [super init])) _textSelectionDataSource = ds; return self; }
- (void)flushLayoutCache {}
- (NSInteger)_length { return [_textSelectionDataSource offsetFromLocation:_textSelectionDataSource.documentRange.location toLocation:_textSelectionDataSource.documentRange.endLocation]; }
- (NSInteger)_offset:(id<NSTextLocation>)l { return [_textSelectionDataSource offsetFromLocation:_textSelectionDataSource.documentRange.location toLocation:l]; }
- (id<NSTextLocation>)_at:(NSInteger)o {
    NSInteger n = [self _length]; o = MAX(0, MIN(n, o));
    return [_textSelectionDataSource locationFromLocation:_textSelectionDataSource.documentRange.location withOffset:o];
}
- (NSRange)_unit:(NSTextSelectionGranularity)g at:(NSInteger)o {
    NSTextRange *r = [_textSelectionDataSource textRangeForSelectionGranularity:g enclosingLocation:[self _at:o]];
    if (!r) return NSMakeRange((NSUInteger)o, 0);
    NSInteger a = [self _offset:r.location], b = [self _offset:r.endLocation];
    return NSMakeRange((NSUInteger)a, (NSUInteger)(b - a));
}
/* the next (forward) or previous boundary of a unit (word, sentence ...) from an offset: word ends going forward, word
   starts going backward, skipping the spaces between */
- (NSInteger)_boundaryFrom:(NSInteger)o forward:(BOOL)fwd options:(NSStringEnumerationOptions)opt {
    __block NSInteger found = fwd ? [self _length] : 0;
    [_textSelectionDataSource enumerateSubstringsFromLocation:[self _at:o] options:opt | (fwd ? 0 : NSStringEnumerationReverse)
                                                   usingBlock:^(NSString *sub, NSTextRange *r, NSTextRange *enc, BOOL *stop) {
        NSInteger a = [self _offset:r.location], b = [self _offset:r.endLocation];
        if (fwd && b > o) { found = b; *stop = YES; }
        if (!fwd && a < o) { found = a; *stop = YES; }
    }];
    return found;
}
- (NSInteger)_lineEdge:(NSInteger)o forward:(BOOL)fwd {
    NSRange line = [self _unit:NSTextSelectionGranularityLine at:fwd || o == 0 ? o : o];
    if (!fwd) return (NSInteger)line.location;
    __block NSInteger last = (NSInteger)NSMaxRange(line);           /* before the line's separator / trailing space */
    [_textSelectionDataSource enumerateCaretOffsetsInLineFragmentAtLocation:[self _at:o] usingBlock:^(CGFloat x, id<NSTextLocation> l, BOOL lead, BOOL *stop) {
        last = [self _offset:l];
    }];
    return last;
}
/* the insertion point one line up or down at about the same x (nil: none) */
- (NSInteger)_vertical:(NSInteger)o down:(BOOL)down x:(CGFloat *)x {
    id<NSTextSelectionDataSource> ds = _textSelectionDataSource;
    if ([(id)ds isKindOfClass:[NSTextLayoutManager class]]) {
        __IsimTextEngine *e = [(NSTextLayoutManager *)ds _isim_engine];
        CGRect c = [e caretRectForIndex:(NSUInteger)o];
        if (isnan(*x)) *x = c.origin.x;
        __IsimTextLine *line = [e lineForIndex:(NSUInteger)o];
        CGRect lr = line ? line->rect : c;
        CGFloat y = down ? CGRectGetMaxY(lr) + 1 : CGRectGetMinY(lr) - 1;
        if (y < 0) return 0;
        if (y > e.height) return [self _length];
        return (NSInteger)[e insertionIndexForPoint:CGPointMake(*x, y)];
    }
    return down ? [self _lineEdge:MIN([self _length], [self _lineEdge:o forward:YES] + 1) forward:YES] : [self _lineEdge:MAX(0, [self _lineEdge:o forward:NO] - 1) forward:NO];
}
- (NSInteger)_move:(NSInteger)o direction:(NSTextSelectionNavigationDirection)dir destination:(NSTextSelectionNavigationDestination)dest x:(CGFloat *)x {
    BOOL rtl = [_textSelectionDataSource baseWritingDirectionAtLocation:[self _at:o]] == NSTextSelectionNavigationWritingDirectionRightToLeft;
    BOOL up = dir == NSTextSelectionNavigationDirectionUp, down = dir == NSTextSelectionNavigationDirectionDown;
    BOOL fwd = dir == NSTextSelectionNavigationDirectionForward || down || (dir == NSTextSelectionNavigationDirectionRight) != rtl;
    if (dir == NSTextSelectionNavigationDirectionLeft) fwd = rtl;
    NSInteger n = [self _length];
    if ((up || down) && (dest == NSTextSelectionNavigationDestinationCharacter || dest == NSTextSelectionNavigationDestinationLine)) return [self _vertical:o down:down x:x];
    switch (dest) {
    case NSTextSelectionNavigationDestinationCharacter: {
        if (fwd) return o >= n ? n : (NSInteger)NSMaxRange([self _unit:NSTextSelectionGranularityCharacter at:o]);
        return o <= 0 ? 0 : (NSInteger)[self _unit:NSTextSelectionGranularityCharacter at:o - 1].location;
    }
    case NSTextSelectionNavigationDestinationWord: return [self _boundaryFrom:o forward:fwd options:NSStringEnumerationByWords | NSStringEnumerationSubstringNotRequired];
    case NSTextSelectionNavigationDestinationSentence: return [self _boundaryFrom:o forward:fwd options:NSStringEnumerationBySentences | NSStringEnumerationSubstringNotRequired];
    case NSTextSelectionNavigationDestinationLine: return [self _lineEdge:o forward:fwd];
    case NSTextSelectionNavigationDestinationParagraph: {
        if (fwd) {      /* the paragraph's end (before its separator), else the next one's */
            NSInteger end = [self _paragraphEnd:o];
            if (end > o) return end;
            NSInteger next = (NSInteger)NSMaxRange([self _unit:NSTextSelectionGranularityParagraph at:o]);
            return next >= n ? n : [self _paragraphEnd:next];
        }
        return o <= 0 ? 0 : (NSInteger)[self _unit:NSTextSelectionGranularityParagraph at:o - 1].location;
    }
    case NSTextSelectionNavigationDestinationContainer: case NSTextSelectionNavigationDestinationDocument: return fwd ? n : 0;
    }
    return o;
}
/* the last composed character before an offset ("" at the start) */
- (NSString *)_characterBefore:(NSInteger)o {
    __block NSString *c = @"";
    if (o > 0) [_textSelectionDataSource enumerateSubstringsFromLocation:[self _at:o] options:NSStringEnumerationByComposedCharacterSequences | NSStringEnumerationReverse
                                                             usingBlock:^(NSString *sub, NSTextRange *r, NSTextRange *enc, BOOL *stop) { c = sub ?: @""; *stop = YES; }];
    return c;
}
/* a paragraph's end before its separator */
- (NSInteger)_paragraphEnd:(NSInteger)o {
    NSInteger end = (NSInteger)NSMaxRange([self _unit:NSTextSelectionGranularityParagraph at:o]);
    NSString *last = [self _characterBefore:end];
    return [last isEqualToString:@"\n"] || [last isEqualToString:@"\r"] || [last isEqualToString:@"\r\n"] || [last isEqualToString:@"\u2029"] ? end - (NSInteger)last.length : end;
}
- (NSTextSelection *)_selectionFrom:(NSInteger)a to:(NSInteger)b affinity:(NSTextSelectionAffinity)aff granularity:(NSTextSelectionGranularity)g {
    NSTextRange *r = [[NSTextRange alloc] initWithLocation:[self _at:MIN(a, b)] endLocation:[self _at:MAX(a, b)]];
    return [[NSTextSelection alloc] initWithRange:r affinity:aff granularity:g];
}
- (NSTextSelection *)destinationSelectionForTextSelection:(NSTextSelection *)sel direction:(NSTextSelectionNavigationDirection)dir
                                              destination:(NSTextSelectionNavigationDestination)dest extending:(BOOL)extending confined:(BOOL)confined {
    NSTextRange *r = sel.textRanges.firstObject;
    if (!r) return nil;
    NSInteger a = [self _offset:r.location], b = [self _offset:sel.textRanges.lastObject.endLocation];
    BOOL vertical = dir == NSTextSelectionNavigationDirectionUp || dir == NSTextSelectionNavigationDirectionDown;
    CGFloat x = vertical && sel.anchorPositionOffset > 0 ? sel.anchorPositionOffset : NAN;
    BOOL movingStart = sel.affinity == NSTextSelectionAffinityUpstream && a != b;
    NSTextSelection *out;
    if (extending) {
        NSInteger anchor = movingStart ? b : a, moving = movingStart ? a : b;
        if (a == b) {
            BOOL back = dir == NSTextSelectionNavigationDirectionBackward || dir == NSTextSelectionNavigationDirectionUp
                     || dir == NSTextSelectionNavigationDirectionLeft;
            movingStart = back;
        }
        NSInteger to = [self _move:moving direction:dir destination:dest x:&x];
        if (to == moving) return nil;
        out = [self _selectionFrom:anchor to:to affinity:to < anchor ? NSTextSelectionAffinityUpstream : NSTextSelectionAffinityDownstream granularity:NSTextSelectionGranularityCharacter];
    } else {
        NSInteger to;
        if (a != b && dest == NSTextSelectionNavigationDestinationCharacter && !vertical) {      /* collapses to the side it moves to */
            CGFloat ignored = NAN;
            BOOL fwd = [self _move:a direction:dir destination:dest x:&ignored] > a || (a == 0 && dir != NSTextSelectionNavigationDirectionBackward
                       && dir != NSTextSelectionNavigationDirectionLeft);
            to = fwd ? b : a;
        } else {
            NSInteger from = vertical ? (dir == NSTextSelectionNavigationDirectionDown ? b : a) : a == b ? a : [self _move:a direction:dir destination:dest x:&x] > a ? b : a;
            to = [self _move:from direction:dir destination:dest x:&x];
            if (to == a && a == b) return nil;
        }
        out = [self _selectionFrom:to to:to affinity:NSTextSelectionAffinityDownstream granularity:NSTextSelectionGranularityCharacter];
    }
    if (vertical && !isnan(x)) out.anchorPositionOffset = x;
    out.typingAttributes = sel.typingAttributes;
    return out;
}
- (NSArray<NSTextSelection *> *)textSelectionsInteractingAtPoint:(CGPoint)p inContainerAtLocation:(id<NSTextLocation>)container anchors:(NSArray<NSTextSelection *> *)anchors
                                                       modifiers:(NSTextSelectionNavigationModifier)mods selecting:(BOOL)selecting bounds:(CGRect)bounds {
    NSTextRange *line = [_textSelectionDataSource lineFragmentRangeForPoint:p inContainerAtLocation:container];
    __block NSInteger best = line ? [self _offset:line.location] : 0; __block CGFloat dist = INFINITY;
    if (line) [_textSelectionDataSource enumerateCaretOffsetsInLineFragmentAtLocation:line.location usingBlock:^(CGFloat x, id<NSTextLocation> l, BOOL lead, BOOL *stop) {
        if (fabs(x - p.x) < dist) { dist = fabs(x - p.x); best = [self _offset:l]; }
    }];
    NSTextRange *anchor = anchors.firstObject.textRanges.firstObject;
    if (anchor && (selecting || (mods & NSTextSelectionNavigationModifierExtend))) {
        NSInteger a = [self _offset:anchor.location], b = [self _offset:anchor.endLocation];
        NSTextSelection *s = best >= a ? [self _selectionFrom:a to:best affinity:NSTextSelectionAffinityDownstream granularity:anchors.firstObject.granularity]
                                       : [self _selectionFrom:best to:b affinity:NSTextSelectionAffinityUpstream granularity:anchors.firstObject.granularity];
        return @[ s ];
    }
    return @[ [self _selectionFrom:best to:best affinity:NSTextSelectionAffinityDownstream granularity:NSTextSelectionGranularityCharacter] ];
}
- (NSTextSelection *)textSelectionForSelectionGranularity:(NSTextSelectionGranularity)g enclosingTextSelection:(NSTextSelection *)sel {
    NSTextRange *r = sel.textRanges.firstObject;
    if (!r) return nil;
    NSInteger a = [self _offset:r.location], b = [self _offset:sel.textRanges.lastObject.endLocation];
    NSRange first = [self _unit:g at:a], last = b > a ? [self _unit:g at:b - 1] : first;
    return [self _selectionFrom:(NSInteger)first.location to:(NSInteger)MAX(NSMaxRange(first), NSMaxRange(last)) affinity:sel.affinity granularity:g];
}
- (NSTextSelection *)textSelectionForSelectionGranularity:(NSTextSelectionGranularity)g enclosingPoint:(CGPoint)p inContainerAtLocation:(id<NSTextLocation>)l {
    NSArray *at = [self textSelectionsInteractingAtPoint:p inContainerAtLocation:l anchors:@[] modifiers:0 selecting:NO bounds:CGRectNull];
    return [self textSelectionForSelectionGranularity:g enclosingTextSelection:at.firstObject];
}
- (id<NSTextLocation>)resolvedInsertionLocationForTextSelection:(NSTextSelection *)sel writingDirection:(NSTextSelectionNavigationWritingDirection)dir {
    NSTextRange *r = sel.textRanges.firstObject;
    return r.isEmpty ? r.location : nil;       /* a range is replaced, not inserted into */
}
- (NSArray<NSTextRange *> *)deletionRangesForTextSelection:(NSTextSelection *)sel direction:(NSTextSelectionNavigationDirection)dir
                                               destination:(NSTextSelectionNavigationDestination)dest allowsDecomposition:(BOOL)decompose {
    NSMutableArray *out = [NSMutableArray array];
    for (NSTextRange *r in sel.textRanges) if (!r.isEmpty) [out addObject:r];
    if (out.count) return out;
    NSTextRange *r = sel.textRanges.firstObject;
    if (!r) return @[];
    NSInteger o = [self _offset:r.location]; CGFloat x = NAN;
    BOOL back = dir == NSTextSelectionNavigationDirectionBackward || dir == NSTextSelectionNavigationDirectionLeft || dir == NSTextSelectionNavigationDirectionUp;
    NSInteger to = [self _move:o direction:back ? NSTextSelectionNavigationDirectionBackward : NSTextSelectionNavigationDirectionForward destination:dest x:&x];
    if (decompose && back && dest == NSTextSelectionNavigationDestinationCharacter && o > 0) {     /* the character's last scalar */
        NSString *c = [self _characterBefore:o];
        unichar u = c.length ? [c characterAtIndex:c.length - 1] : 0;
        to = o - (u >= 0xDC00 && u <= 0xDFFF && c.length >= 2 ? 2 : 1);
    }
    if (to == o) return @[];
    return @[ [[NSTextRange alloc] initWithLocation:[self _at:MIN(o, to)] endLocation:[self _at:MAX(o, to)]] ];
}
@end
