/* TextKit 1: NSTextStorage, NSTextContainer, NSLayoutManager, and NSTextAttachment.
 *
 * Adapted: NSLayoutManager lays its text storage out with isim's TextKit engine (UITextKitEngine.m: Pango, a layout
 * per paragraph) in its first text container; a glyph is a UTF-16 unit of the string, so glyph and character
 * indexes are the same. The engine is rebuilt when the storage is edited or the container changes geometry; layout
 * results set by a typesetter (setLineFragmentRect:... etc.) are accepted and ignored. CGGlyph values come from
 * Core Text when the app links it (0 otherwise). NSTextStorage keeps its characters in a backing attributed string
 * and implements the derived NSMutableAttributedString methods with the four primitives, so subclasses that
 * override the primitives (with their own backing store) work like on iOS. */
#import "UITextKitPrivate.h"
#include <dlfcn.h>

NSNotificationName const NSTextStorageWillProcessEditingNotification = @"NSTextStorageWillProcessEditingNotification";
NSNotificationName const NSTextStorageDidProcessEditingNotification = @"NSTextStorageDidProcessEditingNotification";

/* ================= NSTextStorage ================= */
@interface NSLayoutManager (IsimStorage)
- (void)_isimSetTextStorage:(NSTextStorage *)s;
@end
@implementation NSTextStorage {
    NSMutableAttributedString *_backing;
    NSMutableArray<NSLayoutManager *> *_layoutManagers;
    NSInteger _editing;
    BOOL _pending, _processing;
    NSTextStorageEditActions _mask;
    NSRange _edited;
    NSInteger _delta;
}
- (instancetype)init {
    if ((self = [super initWithString:@"" attributes:nil])) { _backing = [NSMutableAttributedString new]; _layoutManagers = [NSMutableArray array]; }
    return self;
}
- (instancetype)initWithString:(NSString *)str { return [self initWithString:str attributes:nil]; }
- (instancetype)initWithString:(NSString *)str attributes:(NSDictionary *)attrs {
    if ((self = [self init])) _backing = [[NSMutableAttributedString alloc] initWithString:str ?: @"" attributes:attrs];
    return self;
}
- (instancetype)initWithAttributedString:(NSAttributedString *)s {
    if ((self = [self init])) _backing = [[NSMutableAttributedString alloc] initWithAttributedString:s ?: [NSAttributedString new]];
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    NSAttributedString *s = [[NSAttributedString alloc] initWithCoder:coder];
    return [self initWithAttributedString:s];
}

/* ---- the four primitives ---- */
- (NSString *)string { return _backing.string; }
- (NSDictionary *)attributesAtIndex:(NSUInteger)loc effectiveRange:(NSRangePointer)range { return [_backing attributesAtIndex:loc effectiveRange:range]; }
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
    [_backing replaceCharactersInRange:range withString:str ?: @""];
    [self edited:NSTextStorageEditedCharacters | NSTextStorageEditedAttributes range:range changeInLength:(NSInteger)str.length - (NSInteger)range.length];
}
- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range {
    [_backing setAttributes:attrs range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
}

/* ---- derived reading (through the primitives) ---- */
- (NSUInteger)length { return self.string.length; }
- (id)attribute:(NSAttributedStringKey)name atIndex:(NSUInteger)loc effectiveRange:(NSRangePointer)range {
    NSRange r; id v = [self attributesAtIndex:loc effectiveRange:&r][name];
    if (range) {                                                /* the run of this value */
        NSUInteger a = r.location, b = NSMaxRange(r), len = self.length;
        while (a > 0) { NSRange p; id pv = [self attributesAtIndex:a - 1 effectiveRange:&p][name]; if (!(pv == v || [pv isEqual:v])) break; a = p.location; }
        while (b < len) { NSRange n; id nv = [self attributesAtIndex:b effectiveRange:&n][name]; if (!(nv == v || [nv isEqual:v])) break; b = NSMaxRange(n); }
        *range = NSMakeRange(a, b - a);
    }
    return v;
}
- (NSDictionary *)attributesAtIndex:(NSUInteger)loc longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)limit {
    NSRange r; NSDictionary *d = [self attributesAtIndex:loc effectiveRange:&r];
    if (range) {
        NSUInteger a = r.location, b = NSMaxRange(r);
        while (a > limit.location) { NSRange p; NSDictionary *pd = [self attributesAtIndex:a - 1 effectiveRange:&p]; if (![pd isEqualToDictionary:d]) break; a = p.location; }
        while (b < NSMaxRange(limit)) { NSRange n; NSDictionary *nd = [self attributesAtIndex:b effectiveRange:&n]; if (![nd isEqualToDictionary:d]) break; b = NSMaxRange(n); }
        *range = NSIntersectionRange(NSMakeRange(a, b - a), limit);
    }
    return d;
}
- (id)attribute:(NSAttributedStringKey)name atIndex:(NSUInteger)loc longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)limit {
    NSRange r; id v = [self attribute:name atIndex:loc effectiveRange:&r];
    if (range) *range = NSIntersectionRange(r, limit);
    return v;
}
- (void)enumerateAttributesInRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(NSDictionary *, NSRange, BOOL *))block {
    NSMutableArray *runs = [NSMutableArray array];
    for (NSUInteger i = range.location; i < NSMaxRange(range);) {
        NSRange r; NSDictionary *d = [self attributesAtIndex:i effectiveRange:&r];
        r = NSIntersectionRange(r, range);
        [runs addObject:@[d, [NSValue valueWithRange:r]]];
        i = NSMaxRange(r);
    }
    BOOL stop = NO;
    for (NSArray *run in (opts & NSAttributedStringEnumerationReverse) ? runs.reverseObjectEnumerator.allObjects : runs) {
        block(run[0], [run[1] rangeValue], &stop);
        if (stop) break;
    }
}
- (void)enumerateAttribute:(NSAttributedStringKey)name inRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(id, NSRange, BOOL *))block {
    NSMutableArray *runs = [NSMutableArray array];
    for (NSUInteger i = range.location; i < NSMaxRange(range);) {
        NSRange r; id v = [self attribute:name atIndex:i effectiveRange:&r];
        r = NSIntersectionRange(r, range);
        [runs addObject:@[v ?: NSNull.null, [NSValue valueWithRange:r]]];
        i = NSMaxRange(r);
    }
    BOOL stop = NO;
    for (NSArray *run in (opts & NSAttributedStringEnumerationReverse) ? runs.reverseObjectEnumerator.allObjects : runs) {
        id v = run[0] == NSNull.null ? nil : run[0];
        block(v, [run[1] rangeValue], &stop);
        if (stop) break;
    }
}
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range {
    NSMutableAttributedString *m = [[NSMutableAttributedString alloc] initWithString:[self.string substringWithRange:range]];
    [self enumerateAttributesInRange:range options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) {
        [m setAttributes:a range:NSMakeRange(r.location - range.location, r.length)];
    }];
    return m;
}
- (BOOL)isEqualToAttributedString:(NSAttributedString *)other {
    if (![self.string isEqualToString:other.string]) return NO;
    __block BOOL same = YES;
    [self enumerateAttributesInRange:NSMakeRange(0, self.length) options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) {
        NSRange o; NSDictionary *b = [other attributesAtIndex:r.location effectiveRange:&o];
        if (![a isEqualToDictionary:b] || NSMaxRange(o) < NSMaxRange(r)) { same = NO; *stop = YES; }
    }];
    return same;
}
- (BOOL)isEqual:(id)object { return object == self || ([object isKindOfClass:[NSAttributedString class]] && [self isEqualToAttributedString:object]); }
- (NSUInteger)hash { return self.string.hash; }
- (id)copyWithZone:(NSZone *)zone { return [[NSAttributedString alloc] initWithAttributedString:[self attributedSubstringFromRange:NSMakeRange(0, self.length)]]; }
- (id)mutableCopyWithZone:(NSZone *)zone { return [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedSubstringFromRange:NSMakeRange(0, self.length)]]; }
- (NSString *)description { return [[self attributedSubstringFromRange:NSMakeRange(0, self.length)] description]; }
- (NSMutableString *)mutableString { return [self.string mutableCopy]; }

/* ---- derived editing (through the primitives) ---- */
- (void)_isimEditAttributes:(NSRange)range with:(void (^)(NSMutableDictionary *))edit {
    if (!range.length) return;
    [self beginEditing];
    NSMutableArray *runs = [NSMutableArray array];
    [self enumerateAttributesInRange:range options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) { [runs addObject:@[a, [NSValue valueWithRange:r]]]; }];
    for (NSArray *run in runs) { NSMutableDictionary *m = [run[0] mutableCopy]; edit(m); [self setAttributes:m range:[run[1] rangeValue]]; }
    [self endEditing];
}
- (void)addAttribute:(NSAttributedStringKey)name value:(id)value range:(NSRange)range {
    if (!value) [NSException raise:NSInvalidArgumentException format:@"NSTextStorage addAttribute:value:range: nil value"];
    [self _isimEditAttributes:range with:^(NSMutableDictionary *m) { m[name] = value; }];
}
- (void)addAttributes:(NSDictionary *)attrs range:(NSRange)range { [self _isimEditAttributes:range with:^(NSMutableDictionary *m) { [m addEntriesFromDictionary:attrs]; }]; }
- (void)removeAttribute:(NSAttributedStringKey)name range:(NSRange)range { [self _isimEditAttributes:range with:^(NSMutableDictionary *m) { [m removeObjectForKey:name]; }]; }
- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)other {
    [self beginEditing];
    [self replaceCharactersInRange:range withString:other.string];
    [other enumerateAttributesInRange:NSMakeRange(0, other.length) options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) {
        [self setAttributes:a range:NSMakeRange(range.location + r.location, r.length)];
    }];
    [self endEditing];
}
- (void)insertAttributedString:(NSAttributedString *)s atIndex:(NSUInteger)loc { [self replaceCharactersInRange:NSMakeRange(loc, 0) withAttributedString:s]; }
- (void)appendAttributedString:(NSAttributedString *)s { [self replaceCharactersInRange:NSMakeRange(self.length, 0) withAttributedString:s]; }
- (void)deleteCharactersInRange:(NSRange)range { [self replaceCharactersInRange:range withString:@""]; }
- (void)setAttributedString:(NSAttributedString *)s { [self replaceCharactersInRange:NSMakeRange(0, self.length) withAttributedString:s]; }

/* ---- editing transactions ---- */
- (void)beginEditing { _editing++; }
- (void)endEditing {
    if (_editing > 0) _editing--;
    if (!_editing && _pending && !_processing) [self _isimProcess];
}
/* processEditing (a subclass's override may call edited:... again: that joins this round) */
- (void)_isimProcess {
    _processing = YES;
    [self processEditing];
    _processing = NO;
}
- (void)edited:(NSTextStorageEditActions)mask range:(NSRange)range changeInLength:(NSInteger)delta {
    if (!_pending) { _mask = mask; _edited = NSMakeRange(range.location, (NSUInteger)MAX(0, (NSInteger)range.length + delta)); _delta = delta; _pending = YES; }
    else {
        _mask |= mask;
        NSRange now = NSMakeRange(range.location, (NSUInteger)MAX(0, (NSInteger)range.length + delta));
        if (range.location <= _edited.location) _edited.location = (NSUInteger)MAX(0, (NSInteger)_edited.location + delta);   /* an earlier edit shifts it */
        _edited = NSUnionRange(_edited, now);
        _delta += delta;
    }
    if (_edited.location > self.length) _edited.location = self.length;
    if (NSMaxRange(_edited) > self.length) _edited.length = self.length - _edited.location;
    if (!_editing && !_processing) [self _isimProcess];
}
- (NSTextStorageEditActions)editedMask { return _pending ? _mask : 0; }
- (NSRange)editedRange { return _pending ? _edited : NSMakeRange(NSNotFound, 0); }
- (NSInteger)changeInLength { return _pending ? _delta : 0; }
- (void)processEditing {
    if (!_pending) return;
    id<NSTextStorageDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(textStorage:willProcessEditing:range:changeInLength:)]) [d textStorage:self willProcessEditing:_mask range:_edited changeInLength:_delta];
    [NSNotificationCenter.defaultCenter postNotificationName:NSTextStorageWillProcessEditingNotification object:self];
    if ([d respondsToSelector:@selector(textStorage:didProcessEditing:range:changeInLength:)]) [d textStorage:self didProcessEditing:_mask range:_edited changeInLength:_delta];
    [NSNotificationCenter.defaultCenter postNotificationName:NSTextStorageDidProcessEditingNotification object:self];
    NSTextStorageEditActions mask = _mask; NSRange r = _edited; NSInteger delta = _delta;
    _pending = NO;
    for (NSLayoutManager *lm in [_layoutManagers copy]) [lm processEditingForTextStorage:self edited:mask range:r changeInLength:delta invalidatedRange:r];
    [_textStorageObserver processEditingForTextStorage:self edited:mask range:r changeInLength:delta invalidatedRange:r];
}
- (BOOL)fixesAttributesLazily { return NO; }
- (void)invalidateAttributesInRange:(NSRange)range {}
- (void)ensureAttributesAreFixedInRange:(NSRange)range {}

/* ---- layout managers ---- */
- (NSArray<NSLayoutManager *> *)layoutManagers { return [_layoutManagers copy]; }
- (void)addLayoutManager:(NSLayoutManager *)lm {
    if (!lm || [_layoutManagers containsObject:lm]) return;
    [lm.textStorage removeLayoutManager:lm];
    [_layoutManagers addObject:lm];
    [lm _isimSetTextStorage:self];
}
- (void)removeLayoutManager:(NSLayoutManager *)lm {
    if (![_layoutManagers containsObject:lm]) return;
    [lm _isimSetTextStorage:nil];
    [_layoutManagers removeObject:lm];
}
@end

/* ================= NSTextContainer ================= */
@interface NSTextLayoutManager (IsimContainer)
- (void)_isimContainerChanged;
@end
@implementation NSTextContainer
@synthesize size = _size, lineFragmentPadding = _lineFragmentPadding, maximumNumberOfLines = _maximumNumberOfLines, lineBreakMode = _lineBreakMode,
    exclusionPaths = _exclusionPaths;
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithSize:(CGSize)size {
    if ((self = [super init])) { _size = size; _lineFragmentPadding = 5; _lineBreakMode = NSLineBreakByWordWrapping; _exclusionPaths = @[]; }
    return self;
}
- (instancetype)init { return [self initWithSize:CGSizeZero]; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithSize:CGSizeZero]; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (void)_isimChanged:(CGSize)old {
    [_layoutManager textContainerChangedGeometry:self];
    id<NSLayoutManagerDelegate> d = _layoutManager.delegate;
    if (!CGSizeEqualToSize(old, _size) && [d respondsToSelector:@selector(layoutManager:textContainer:didChangeGeometryFromSize:)])
        [d layoutManager:_layoutManager textContainer:self didChangeGeometryFromSize:old];
    [_textLayoutManager _isimContainerChanged];
}
- (CGSize)size { return _size; }
- (CGFloat)lineFragmentPadding { return _lineFragmentPadding; }
- (NSUInteger)maximumNumberOfLines { return _maximumNumberOfLines; }
- (NSLineBreakMode)lineBreakMode { return _lineBreakMode; }
- (NSArray<UIBezierPath *> *)exclusionPaths { return _exclusionPaths; }
- (void)setSize:(CGSize)s { CGSize old = _size; if (CGSizeEqualToSize(old, s)) return; _size = s; [self _isimChanged:old]; }
- (void)setLineFragmentPadding:(CGFloat)p { if (p == _lineFragmentPadding) return; _lineFragmentPadding = p; [self _isimChanged:_size]; }
- (void)setMaximumNumberOfLines:(NSUInteger)n { if (n == _maximumNumberOfLines) return; _maximumNumberOfLines = n; [self _isimChanged:_size]; }
- (void)setLineBreakMode:(NSLineBreakMode)m { _lineBreakMode = m; [self _isimChanged:_size]; }
- (void)setExclusionPaths:(NSArray<UIBezierPath *> *)p { _exclusionPaths = [p copy] ?: @[]; [self _isimChanged:_size]; }
- (void)replaceLayoutManager:(NSLayoutManager *)newLM {
    NSLayoutManager *old = _layoutManager;
    if (old == newLM) return;
    NSUInteger i = [old.textContainers indexOfObjectIdenticalTo:self];
    if (i != NSNotFound) [old removeTextContainerAtIndex:i];
    [newLM addTextContainer:self];
}
- (BOOL)isSimpleRectangularTextContainer { return _exclusionPaths.count == 0; }
- (CGRect)lineFragmentRectForProposedRect:(CGRect)r atIndex:(NSUInteger)i writingDirection:(NSWritingDirection)dir remainingRect:(CGRect *)remaining {
    if (remaining) *remaining = CGRectZero;
    CGFloat w = _size.width > 0 ? _size.width : CGFLOAT_MAX;
    CGRect box = CGRectMake(0, 0, w, _size.height > 0 ? _size.height : CGFLOAT_MAX);
    return CGRectIntersection(r, box);                        /* (exclusion paths are not applied) */
}
@end

/* ================= NSLayoutManager ================= */
@implementation NSLayoutManager {
    NSMutableArray<NSTextContainer *> *_containers;
    __IsimTextEngine *_engine;
    BOOL _notifiedDone;
}
@synthesize textStorage = _textStorage;
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)init {
    if ((self = [super init])) { _containers = [NSMutableArray array]; _allowsNonContiguousLayout = NO; _usesFontLeading = YES; }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (void)_isimSetTextStorage:(NSTextStorage *)s { _textStorage = s; [self _isimInvalidate]; }
- (NSTextStorage *)textStorage { return _textStorage; }
- (void)setTextStorage:(NSTextStorage *)s { if (s != _textStorage) [s addLayoutManager:self]; }
- (NSArray<NSTextContainer *> *)textContainers { return [_containers copy]; }
- (void)addTextContainer:(NSTextContainer *)c { [self insertTextContainer:c atIndex:_containers.count]; }
- (void)insertTextContainer:(NSTextContainer *)c atIndex:(NSUInteger)i {
    if (!c) return;
    [_containers insertObject:c atIndex:MIN(i, _containers.count)];
    c.layoutManager = self;
    [self _isimInvalidate];
}
- (void)removeTextContainerAtIndex:(NSUInteger)i {
    if (i >= _containers.count) return;
    if (_containers[i].layoutManager == self) _containers[i].layoutManager = nil;
    [_containers removeObjectAtIndex:i];
    [self _isimInvalidate];
}
- (void)textContainerChangedGeometry:(NSTextContainer *)c { [self _isimInvalidate]; }
- (BOOL)hasNonContiguousLayout { return NO; }
- (void)_isimInvalidate {
    _engine = nil; _notifiedDone = NO;
    id<NSLayoutManagerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(layoutManagerDidInvalidateLayout:)]) [d layoutManagerDidInvalidateLayout:self];
}
/* the layout of the storage in the first container (built on demand) */
- (__IsimTextEngine *)_isimEngine {
    if (_engine) return _engine;
    NSTextContainer *c = _containers.firstObject;
    CGFloat w = c ? c.size.width : 0;
    _engine = [[__IsimTextEngine alloc] initWithString:_textStorage ? [_textStorage attributedSubstringFromRange:NSMakeRange(0, _textStorage.length)] : [NSAttributedString new]
                                                 width:w padding:c ? c.lineFragmentPadding : 0 font:nil color:nil maxLines:c.maximumNumberOfLines];
    if (!_notifiedDone) {
        _notifiedDone = YES;
        id<NSLayoutManagerDelegate> d = _delegate;
        if (c && [d respondsToSelector:@selector(layoutManager:didCompleteLayoutForTextContainer:atEnd:)])
            dispatch_async(dispatch_get_main_queue(), ^{ [d layoutManager:self didCompleteLayoutForTextContainer:c atEnd:YES]; });
    }
    return _engine;
}
- (NSTextContainer *)_isimFirst { return _containers.firstObject; }

/* ---- invalidation ---- */
- (void)invalidateGlyphsForCharacterRange:(NSRange)r changeInLength:(NSInteger)delta actualCharacterRange:(NSRangePointer)actual { if (actual) *actual = r; [self _isimInvalidate]; }
- (void)invalidateLayoutForCharacterRange:(NSRange)r actualCharacterRange:(NSRangePointer)actual { if (actual) *actual = r; [self _isimInvalidate]; }
- (void)invalidateDisplayForCharacterRange:(NSRange)r { isim_ui_set_needs_display(); }
- (void)invalidateDisplayForGlyphRange:(NSRange)r { isim_ui_set_needs_display(); }
- (void)processEditingForTextStorage:(NSTextStorage *)ts edited:(NSTextStorageEditActions)mask range:(NSRange)r changeInLength:(NSInteger)delta invalidatedRange:(NSRange)inv {
    [self _isimInvalidate];
    isim_ui_set_needs_display();
}
- (void)ensureGlyphsForCharacterRange:(NSRange)r { [self _isimEngine]; }
- (void)ensureGlyphsForGlyphRange:(NSRange)r { [self _isimEngine]; }
- (void)ensureLayoutForCharacterRange:(NSRange)r { [self _isimEngine]; }
- (void)ensureLayoutForGlyphRange:(NSRange)r { [self _isimEngine]; }
- (void)ensureLayoutForTextContainer:(NSTextContainer *)c { [self _isimEngine]; }
- (void)ensureLayoutForBoundingRect:(CGRect)b inTextContainer:(NSTextContainer *)c { [self _isimEngine]; }

/* ---- glyphs ---- */
- (NSUInteger)numberOfGlyphs { return _textStorage.length; }
- (BOOL)isValidGlyphIndex:(NSUInteger)i { return i < self.numberOfGlyphs; }
- (CGGlyph)CGGlyphAtIndex:(NSUInteger)i { return [self CGGlyphAtIndex:i isValidIndex:NULL]; }
- (CGGlyph)CGGlyphAtIndex:(NSUInteger)i isValidIndex:(BOOL *)valid {
    if (valid) *valid = i < self.numberOfGlyphs;
    if (i >= self.numberOfGlyphs) return 0;
    static void *(*create)(CFStringRef, CGFloat, const CGAffineTransform *);
    static bool (*glyphs)(void *, const UniChar *, CGGlyph *, CFIndex);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        create = (void *(*)(CFStringRef, CGFloat, const CGAffineTransform *))dlsym(RTLD_DEFAULT, "CTFontCreateWithName");
        glyphs = (bool (*)(void *, const UniChar *, CGGlyph *, CFIndex))dlsym(RTLD_DEFAULT, "CTFontGetGlyphsForCharacters");
    });
    if (!create || !glyphs) return 0;
    UIFont *f = [_textStorage attribute:NSFontAttributeName atIndex:i effectiveRange:NULL] ?: [UIFont systemFontOfSize:12];
    void *ct = create((__bridge CFStringRef)f.fontName, f.pointSize, NULL);
    if (!ct) return 0;
    UniChar c = [_textStorage.string characterAtIndex:i]; CGGlyph g = 0;
    glyphs(ct, &c, &g, 1);
    CFRelease(ct);
    return g;
}
- (NSGlyphProperty)propertyForGlyphAtIndex:(NSUInteger)i {
    if (i >= self.numberOfGlyphs) return 0;
    unichar c = [_textStorage.string characterAtIndex:i];
    if (c == '\n' || c == '\r' || c == '\t' || c == 0x2028 || c == 0x2029) return NSGlyphPropertyControlCharacter;
    if (c >= 0xDC00 && c <= 0xDFFF) return NSGlyphPropertyNull;
    if (c == ' ') return NSGlyphPropertyElastic;
    return 0;
}
- (NSUInteger)getGlyphsInRange:(NSRange)r glyphs:(CGGlyph *)g properties:(NSGlyphProperty *)props characterIndexes:(NSUInteger *)ci bidiLevels:(unsigned char *)bidi {
    NSRange in = NSIntersectionRange(r, NSMakeRange(0, self.numberOfGlyphs));
    for (NSUInteger k = 0; k < in.length; k++) {
        NSUInteger i = in.location + k;
        if (g) g[k] = [self CGGlyphAtIndex:i];
        if (props) props[k] = [self propertyForGlyphAtIndex:i];
        if (ci) ci[k] = i;
        if (bidi) bidi[k] = 0;
    }
    return in.length;
}
- (void)setGlyphs:(const CGGlyph *)glyphs properties:(const NSGlyphProperty *)props characterIndexes:(const NSUInteger *)ci font:(UIFont *)f forGlyphRange:(NSRange)r {}
- (NSUInteger)characterIndexForGlyphAtIndex:(NSUInteger)i { return MIN(i, self.numberOfGlyphs); }
- (NSUInteger)glyphIndexForCharacterAtIndex:(NSUInteger)i { return MIN(i, self.numberOfGlyphs); }
- (NSRange)glyphRangeForCharacterRange:(NSRange)r actualCharacterRange:(NSRangePointer)actual {
    NSRange g = NSIntersectionRange(r, NSMakeRange(0, self.numberOfGlyphs));
    if (r.length == 0) g = NSMakeRange(MIN(r.location, self.numberOfGlyphs), 0);
    if (actual) *actual = g;
    return g;
}
- (NSRange)characterRangeForGlyphRange:(NSRange)r actualGlyphRange:(NSRangePointer)actual { return [self glyphRangeForCharacterRange:r actualCharacterRange:actual]; }

/* ---- layout results ---- */
- (void)setTextContainer:(NSTextContainer *)c forGlyphRange:(NSRange)r {}
- (void)setLineFragmentRect:(CGRect)f forGlyphRange:(NSRange)r usedRect:(CGRect)u {}
- (void)setExtraLineFragmentRect:(CGRect)f usedRect:(CGRect)u textContainer:(NSTextContainer *)c {}
- (void)setLocation:(CGPoint)l forStartOfGlyphRange:(NSRange)r {}
- (void)setNotShownAttribute:(BOOL)f forGlyphAtIndex:(NSUInteger)i {}
- (void)setDrawsOutsideLineFragment:(BOOL)f forGlyphAtIndex:(NSUInteger)i {}
- (void)setAttachmentSize:(CGSize)s forGlyphRange:(NSRange)r {}
- (NSUInteger)firstUnlaidCharacterIndex { return [self _isimEngine].laidLength; }
- (NSUInteger)firstUnlaidGlyphIndex { return [self firstUnlaidCharacterIndex]; }
- (void)getFirstUnlaidCharacterIndex:(NSUInteger *)ci glyphIndex:(NSUInteger *)gi { if (ci) *ci = self.firstUnlaidCharacterIndex; if (gi) *gi = self.firstUnlaidGlyphIndex; }
- (NSTextContainer *)textContainerForGlyphAtIndex:(NSUInteger)i effectiveRange:(NSRangePointer)r {
    __IsimTextEngine *e = [self _isimEngine];
    if (r) *r = NSMakeRange(0, e.laidLength);
    return i < e.laidLength || (i == 0 && self.numberOfGlyphs == 0) ? self._isimFirst : nil;
}
- (NSTextContainer *)textContainerForGlyphAtIndex:(NSUInteger)i effectiveRange:(NSRangePointer)r withoutAdditionalLayout:(BOOL)f { return [self textContainerForGlyphAtIndex:i effectiveRange:r]; }
- (CGRect)usedRectForTextContainer:(NSTextContainer *)c { return c == self._isimFirst ? [self _isimEngine].usedRect : CGRectZero; }
- (CGRect)lineFragmentRectForGlyphAtIndex:(NSUInteger)i effectiveRange:(NSRangePointer)r {
    __IsimTextLine *l = [[self _isimEngine] lineForIndex:i];
    if (r) *r = l ? l->range : NSMakeRange(0, 0);
    return l ? l->rect : CGRectZero;
}
- (CGRect)lineFragmentRectForGlyphAtIndex:(NSUInteger)i effectiveRange:(NSRangePointer)r withoutAdditionalLayout:(BOOL)f { return [self lineFragmentRectForGlyphAtIndex:i effectiveRange:r]; }
- (CGRect)lineFragmentUsedRectForGlyphAtIndex:(NSUInteger)i effectiveRange:(NSRangePointer)r {
    __IsimTextLine *l = [[self _isimEngine] lineForIndex:i];
    if (r) *r = l ? l->range : NSMakeRange(0, 0);
    return l ? l->used : CGRectZero;
}
- (CGRect)lineFragmentUsedRectForGlyphAtIndex:(NSUInteger)i effectiveRange:(NSRangePointer)r withoutAdditionalLayout:(BOOL)f { return [self lineFragmentUsedRectForGlyphAtIndex:i effectiveRange:r]; }
- (CGRect)extraLineFragmentRect { return [self _isimEngine].extraLineRect; }
- (CGRect)extraLineFragmentUsedRect { return [self _isimEngine].extraLineUsedRect; }
- (NSTextContainer *)extraLineFragmentTextContainer { return CGRectIsEmpty([self _isimEngine].extraLineRect) ? nil : self._isimFirst; }
/* the glyph's origin relative to its line fragment: x along the line, y the baseline */
- (CGPoint)locationForGlyphAtIndex:(NSUInteger)i {
    __IsimTextEngine *e = [self _isimEngine];
    __IsimTextLine *l = [e lineForIndex:i];
    CGRect c = [e rectForCharacterAtIndex:i];
    return CGPointMake(c.origin.x - (l ? l->rect.origin.x : 0), l ? l->baseline : 0);
}
- (BOOL)notShownAttributeForGlyphAtIndex:(NSUInteger)i { return [self propertyForGlyphAtIndex:i] & NSGlyphPropertyControlCharacter ? YES : NO; }
- (BOOL)drawsOutsideLineFragmentForGlyphAtIndex:(NSUInteger)i { return NO; }
- (CGSize)attachmentSizeForGlyphAtIndex:(NSUInteger)i {
    for (__IsimTextAttachmentSlot *s in [self _isimEngine].attachments) if (s->index == i) return s->frame.size;
    return CGSizeMake(-1, -1);
}
- (NSRange)truncatedGlyphRangeInLineFragmentForGlyphAtIndex:(NSUInteger)i { return NSMakeRange(NSNotFound, 0); }

/* ---- queries ---- */
- (NSRange)glyphRangeForTextContainer:(NSTextContainer *)c { return c == self._isimFirst ? NSMakeRange(0, [self _isimEngine].laidLength) : NSMakeRange(self.numberOfGlyphs, 0); }
- (NSRange)rangeOfNominallySpacedGlyphsContainingIndex:(NSUInteger)i {
    __IsimTextLine *l = [[self _isimEngine] lineForIndex:i];
    return l ? l->range : NSMakeRange(i, 0);
}
- (CGRect)boundingRectForGlyphRange:(NSRange)r inTextContainer:(NSTextContainer *)c {
    if (c != self._isimFirst) return CGRectZero;
    __IsimTextEngine *e = [self _isimEngine];
    if (r.length == 0) return [e caretRectForIndex:r.location];
    CGRect u = CGRectNull;
    for (NSUInteger i = r.location; i < NSMaxRange(r) && i < self.numberOfGlyphs; i++) u = CGRectUnion(u, [e rectForCharacterAtIndex:i]);
    return CGRectIsNull(u) ? CGRectZero : u;
}
- (NSRange)glyphRangeForBoundingRect:(CGRect)b inTextContainer:(NSTextContainer *)c {
    if (c != self._isimFirst) return NSMakeRange(0, 0);
    NSUInteger a = NSNotFound, z = 0;
    for (__IsimTextLine *l in [self _isimEngine].lines) {
        if (!CGRectIntersectsRect(l->rect, b)) continue;
        if (a == NSNotFound) a = l->range.location;
        z = NSMaxRange(l->range);
    }
    return a == NSNotFound ? NSMakeRange(0, 0) : NSMakeRange(a, z - a);
}
- (NSRange)glyphRangeForBoundingRectWithoutAdditionalLayout:(CGRect)b inTextContainer:(NSTextContainer *)c { return [self glyphRangeForBoundingRect:b inTextContainer:c]; }
- (NSUInteger)glyphIndexForPoint:(CGPoint)p inTextContainer:(NSTextContainer *)c fractionOfDistanceThroughGlyph:(CGFloat *)f {
    return [[self _isimEngine] characterIndexForPoint:p fraction:f];
}
- (NSUInteger)glyphIndexForPoint:(CGPoint)p inTextContainer:(NSTextContainer *)c { return [self glyphIndexForPoint:p inTextContainer:c fractionOfDistanceThroughGlyph:NULL]; }
- (CGFloat)fractionOfDistanceThroughGlyphForPoint:(CGPoint)p inTextContainer:(NSTextContainer *)c {
    CGFloat f = 0; [self glyphIndexForPoint:p inTextContainer:c fractionOfDistanceThroughGlyph:&f]; return f;
}
- (NSUInteger)characterIndexForPoint:(CGPoint)p inTextContainer:(NSTextContainer *)c fractionOfDistanceBetweenInsertionPoints:(CGFloat *)f {
    return [[self _isimEngine] characterIndexForPoint:p fraction:f];
}
- (NSUInteger)getLineFragmentInsertionPointsForCharacterAtIndex:(NSUInteger)ci alternatePositions:(BOOL)alt inDisplayOrder:(BOOL)order
                                                      positions:(CGFloat *)positions characterIndexes:(NSUInteger *)indexes {
    __IsimTextEngine *e = [self _isimEngine];
    __IsimTextLine *l = [e lineForIndex:ci];
    if (!l) return 0;
    NSUInteger end = l->range.length && NSMaxRange(l->range) <= self.numberOfGlyphs && [self propertyForGlyphAtIndex:NSMaxRange(l->range) - 1] & NSGlyphPropertyControlCharacter
                     ? NSMaxRange(l->range) - 1 : NSMaxRange(l->range);
    NSUInteger n = 0;
    for (NSUInteger i = l->range.location; i <= end; i++, n++) {
        if (positions) positions[n] = [e caretRectForIndex:i].origin.x - l->rect.origin.x;
        if (indexes) indexes[n] = i;
    }
    return n;
}
- (void)enumerateLineFragmentsForGlyphRange:(NSRange)r usingBlock:(void (NS_NOESCAPE ^)(CGRect, CGRect, NSTextContainer *, NSRange, BOOL *))block {
    NSTextContainer *c = self._isimFirst; if (!c) return;
    BOOL stop = NO;
    for (__IsimTextLine *l in [self _isimEngine].lines) {
        if (NSMaxRange(l->range) <= r.location || l->range.location >= NSMaxRange(r)) { if (!(r.length == 0 && r.location == l->range.location)) continue; }
        block(l->rect, l->used, c, l->range, &stop);
        if (stop) break;
    }
}
- (void)enumerateEnclosingRectsForGlyphRange:(NSRange)r withinSelectedGlyphRange:(NSRange)sel inTextContainer:(NSTextContainer *)c usingBlock:(void (NS_NOESCAPE ^)(CGRect, BOOL *))block {
    if (c != self._isimFirst) return;
    BOOL stop = NO;
    for (NSValue *v in [[self _isimEngine] rectsForRange:r]) { block(v.CGRectValue, &stop); if (stop) break; }
}

/* ---- drawing ---- */
- (void)drawBackgroundForGlyphRange:(NSRange)r atPoint:(CGPoint)o {
    /* NSBackgroundColorAttributeName is drawn with the glyphs (Pango backgrounds) */
}
- (void)drawGlyphsForGlyphRange:(NSRange)r atPoint:(CGPoint)o { [[self _isimEngine] drawRange:r atPoint:o skipAttachmentViews:NO]; }
- (void)showCGGlyphs:(const CGGlyph *)glyphs positions:(const CGPoint *)positions count:(NSInteger)n font:(UIFont *)font
          textMatrix:(CGAffineTransform)m attributes:(NSDictionary *)attrs inContext:(CGContextRef)ctx {
    /* isim draws whole runs with Pango (drawGlyphsForGlyphRange:atPoint:); single glyphs are not drawn */
}
- (void)fillBackgroundRectArray:(const CGRect *)rects count:(NSUInteger)n forCharacterRange:(NSRange)r color:(UIColor *)color {
    double c[4]; isim_ui_rgba(color, c);
    for (NSUInteger i = 0; i < n; i++) isim_gfx_fill_rounded(rects[i].origin.x, rects[i].origin.y, rects[i].size.width, rects[i].size.height, 0, c);
}
- (void)drawUnderlineForGlyphRange:(NSRange)r underlineType:(NSUnderlineStyle)u baselineOffset:(CGFloat)b lineFragmentRect:(CGRect)lr lineFragmentGlyphRange:(NSRange)lg containerOrigin:(CGPoint)o {}
- (void)underlineGlyphRange:(NSRange)r underlineType:(NSUnderlineStyle)u lineFragmentRect:(CGRect)lr lineFragmentGlyphRange:(NSRange)lg containerOrigin:(CGPoint)o {}
- (void)drawStrikethroughForGlyphRange:(NSRange)r strikethroughType:(NSUnderlineStyle)s baselineOffset:(CGFloat)b lineFragmentRect:(CGRect)lr lineFragmentGlyphRange:(NSRange)lg containerOrigin:(CGPoint)o {}
- (void)strikethroughGlyphRange:(NSRange)r strikethroughType:(NSUnderlineStyle)s lineFragmentRect:(CGRect)lr lineFragmentGlyphRange:(NSRange)lg containerOrigin:(CGPoint)o {}
- (__IsimTextEngine *)_isim_engine { return [self _isimEngine]; }
@end

/* ================= NSTextAttachment ================= */
static NSMutableDictionary<NSString *, Class> *view_provider_classes;
@implementation NSTextAttachment
@synthesize image = _image;
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithData:(NSData *)data ofType:(NSString *)uti {
    if ((self = [super init])) { _contents = [data copy]; _fileType = [uti copy]; _allowsTextAttachmentView = YES; }
    return self;
}
- (instancetype)init { return [self initWithData:nil ofType:nil]; }
- (instancetype)initWithImage:(UIImage *)image { if ((self = [self initWithData:nil ofType:nil])) _image = image; return self; }
+ (NSTextAttachment *)textAttachmentWithImage:(UIImage *)image { return [[self alloc] initWithImage:image]; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithData:nil ofType:nil]; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (void)setImage:(UIImage *)i { _image = i; }
- (UIImage *)image {
    if (!_image && _contents) _image = [UIImage imageWithData:_contents];
    return _image;
}
+ (Class)textAttachmentViewProviderClassForFileType:(NSString *)type { return type ? view_provider_classes[type] : nil; }
+ (void)registerTextAttachmentViewProviderClass:(Class)cls forFileType:(NSString *)type {
    if (!type) return;
    if (!view_provider_classes) view_provider_classes = [NSMutableDictionary dictionary];
    view_provider_classes[type] = cls;
}
/* a view provider class registered for its file type (and views allowed) */
- (BOOL)usesTextAttachmentView { return _allowsTextAttachmentView && _fileType && [NSTextAttachment textAttachmentViewProviderClassForFileType:_fileType] != nil; }
/* NSTextAttachmentContainer */
- (UIImage *)imageForBounds:(CGRect)b textContainer:(NSTextContainer *)c characterIndex:(NSUInteger)i { return self.image; }
- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)c proposedLineFragment:(CGRect)lf glyphPosition:(CGPoint)p characterIndex:(NSUInteger)i {
    return isim_ui_attachment_bounds(self);
}
/* NSTextAttachmentLayout (TextKit 2) */
- (UIImage *)imageForBounds:(CGRect)b attributes:(NSDictionary *)a location:(id<NSTextLocation>)l textContainer:(NSTextContainer *)c { return self.image; }
- (CGRect)attachmentBoundsForAttributes:(NSDictionary *)a location:(id<NSTextLocation>)l textContainer:(NSTextContainer *)c proposedLineFragment:(CGRect)lf position:(CGPoint)p {
    return isim_ui_attachment_bounds(self);
}
- (NSTextAttachmentViewProvider *)viewProviderForParentView:(UIView *)parent location:(id<NSTextLocation>)location textContainer:(NSTextContainer *)c {
    if (!self.usesTextAttachmentView) return nil;
    Class cls = [NSTextAttachment textAttachmentViewProviderClassForFileType:_fileType];
    return [[cls alloc] initWithTextAttachment:self parentView:parent textLayoutManager:c.textLayoutManager location:location];
}
@end

@implementation NSAttributedString (NSAttributedStringAttachmentConveniences)
+ (instancetype)attributedStringWithAttachment:(NSTextAttachment *)a {
    unichar c = NSAttachmentCharacter;
    return [[self alloc] initWithString:[NSString stringWithCharacters:&c length:1] attributes:@{ NSAttachmentAttributeName: a }];
}
+ (instancetype)attributedStringWithAttachment:(NSTextAttachment *)a attributes:(NSDictionary *)attrs {
    unichar c = NSAttachmentCharacter;
    NSMutableDictionary *m = [attrs mutableCopy] ?: [NSMutableDictionary dictionary];
    m[NSAttachmentAttributeName] = a;
    return [[self alloc] initWithString:[NSString stringWithCharacters:&c length:1] attributes:m];
}
@end

@implementation NSTextAttachmentViewProvider
@synthesize view = _view;
- (instancetype)initWithTextAttachment:(NSTextAttachment *)a parentView:(UIView *)parent textLayoutManager:(NSTextLayoutManager *)tlm location:(id<NSTextLocation>)location {
    if ((self = [super init])) { _textAttachment = a; _textLayoutManager = tlm; _location = location; }
    return self;
}
/* the default: an image view of the attachment's image */
- (void)loadView {
    UIImageView *v = [[UIImageView alloc] initWithImage:_textAttachment.image];
    v.contentMode = UIViewContentModeScaleAspectFit;
    _view = v;
}
- (UIView *)view { return _view; }
- (void)setView:(UIView *)v { _view = v; }
- (CGRect)attachmentBoundsForAttributes:(NSDictionary *)a location:(id<NSTextLocation>)l textContainer:(NSTextContainer *)c proposedLineFragment:(CGRect)lf position:(CGPoint)p {
    if (_tracksTextAttachmentViewBounds && _view) return CGRectMake(0, 0, _view.bounds.size.width, _view.bounds.size.height);
    return isim_ui_attachment_bounds(_textAttachment);
}
@end
