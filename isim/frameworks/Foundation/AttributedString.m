/* isim Foundation (ARC): NSAttributedString / NSMutableAttributedString. Characters live in an NSString and
 * attributes in a list of runs (length in UTF-16 units + attribute dictionary); adjacent runs with equal
 * attributes are always coalesced, so a run is also the longest effective range. */
#import <Foundation/Foundation.h>
#include "isim_foundation.h"

NSAttributedStringKey const NSInlinePresentationIntentAttributeName = @"NSInlinePresentationIntent";
NSAttributedStringKey const NSAlternateDescriptionAttributeName = @"NSAlternateDescription";
NSAttributedStringKey const NSImageURLAttributeName = @"NSImageURL";
NSAttributedStringKey const NSLanguageIdentifierAttributeName = @"NSLanguage";
NSAttributedStringKey const NSPresentationIntentAttributeName = @"NSPresentationIntent";

@interface _IsimAttrRun : NSObject { @public NSUInteger len; NSDictionary *attrs; }
@end
@implementation _IsimAttrRun
+ (instancetype)run:(NSUInteger)len attrs:(NSDictionary *)attrs { _IsimAttrRun *r = [self new]; r->len = len; r->attrs = attrs ? [attrs copy] : @{}; return r; }
@end

@implementation NSAttributedString {
@protected
    NSMutableString *_str;
    NSMutableArray<_IsimAttrRun *> *_runs;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)init { return [self initWithString:@"" attributes:nil]; }
- (instancetype)initWithString:(NSString *)str { return [self initWithString:str attributes:nil]; }
- (instancetype)initWithString:(NSString *)str attributes:(NSDictionary *)attrs {
    if ((self = [super init])) {
        _str = [str mutableCopy] ?: [NSMutableString string];
        _runs = [NSMutableArray array];
        if (_str.length) [_runs addObject:[_IsimAttrRun run:_str.length attrs:attrs]];
    }
    return self;
}
- (instancetype)initWithAttributedString:(NSAttributedString *)other {
    if ((self = [super init])) {
        _str = [other.string mutableCopy];
        _runs = [NSMutableArray array];
        [other enumerateAttributesInRange:NSMakeRange(0, other.length) options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) {
            [self->_runs addObject:[_IsimAttrRun run:r.length attrs:a]];
        }];
    }
    return self;
}
- (NSString *)string { return [_str copy]; }
- (NSUInteger)length { return _str.length; }
- (id)copyWithZone:(NSZone *)zone { return [[NSAttributedString alloc] initWithAttributedString:self]; }
- (id)mutableCopyWithZone:(NSZone *)zone { return [[NSMutableAttributedString alloc] initWithAttributedString:self]; }

static void check_index(NSAttributedString *s, NSUInteger loc, NSUInteger len) {
    if (loc > len) [NSException raise:NSRangeException format:@"NSAttributedString index %lu out of bounds; length %lu", (unsigned long)loc, (unsigned long)len];
}
/* run containing `loc` (loc < length), with its start offset */
- (NSUInteger)_runAt:(NSUInteger)loc start:(NSUInteger *)start {
    NSUInteger pos = 0, i = 0;
    for (_IsimAttrRun *r in _runs) {
        if (loc < pos + r->len) { if (start) *start = pos; return i; }
        pos += r->len; i++;
    }
    if (start) *start = pos;
    return NSNotFound;
}
- (NSDictionary *)attributesAtIndex:(NSUInteger)loc effectiveRange:(NSRangePointer)range {
    if (loc >= _str.length) check_index(self, loc + 1, _str.length);
    NSUInteger start = 0, i = [self _runAt:loc start:&start];
    if (range) *range = NSMakeRange(start, _runs[i]->len);
    return _runs[i]->attrs;
}
- (NSDictionary *)attributesAtIndex:(NSUInteger)loc longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)limit {
    NSRange r;
    NSDictionary *a = [self attributesAtIndex:loc effectiveRange:&r];
    if (range) *range = NSIntersectionRange(r, limit);
    return a;
}
- (id)attribute:(NSAttributedStringKey)name atIndex:(NSUInteger)loc effectiveRange:(NSRangePointer)range {
    NSRange r;
    id v = [self attributesAtIndex:loc effectiveRange:&r][name];
    if (range) {   /* extend across neighbouring runs with the same value for this key */
        NSUInteger lo = r.location, hi = NSMaxRange(r);
        while (lo > 0) { NSRange p; id pv = [self attributesAtIndex:lo - 1 effectiveRange:&p][name]; if (pv != v && ![pv isEqual:v]) break; lo = p.location; }
        while (hi < _str.length) { NSRange n; id nv = [self attributesAtIndex:hi effectiveRange:&n][name]; if (nv != v && ![nv isEqual:v]) break; hi = NSMaxRange(n); }
        *range = NSMakeRange(lo, hi - lo);
    }
    return v;
}
- (id)attribute:(NSAttributedStringKey)name atIndex:(NSUInteger)loc longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)limit {
    NSRange r;
    id v = [self attribute:name atIndex:loc effectiveRange:&r];
    if (range) *range = NSIntersectionRange(r, limit);
    return v;
}
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range {
    check_index(self, NSMaxRange(range), _str.length);
    NSMutableAttributedString *out = [[NSMutableAttributedString alloc] initWithString:[_str substringWithRange:range]];
    [self enumerateAttributesInRange:range options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) {
        [out setAttributes:a range:NSMakeRange(r.location - range.location, r.length)];
    }];
    return [self isKindOfClass:[NSMutableAttributedString class]] ? [out copy] : [[NSAttributedString alloc] initWithAttributedString:out];
}
- (void)enumerateAttributesInRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(NSDictionary *, NSRange, BOOL *))block {
    check_index(self, NSMaxRange(range), _str.length);
    NSMutableArray *pieces = [NSMutableArray array];
    NSUInteger pos = 0;
    for (_IsimAttrRun *r in [_runs copy]) {
        NSRange clip = NSIntersectionRange(NSMakeRange(pos, r->len), range);
        if (clip.length) [pieces addObject:@[r->attrs, [NSValue valueWithRange:clip]]];
        pos += r->len;
    }
    NSEnumerator *e = (opts & NSAttributedStringEnumerationReverse) ? pieces.reverseObjectEnumerator : pieces.objectEnumerator;
    BOOL stop = NO;
    for (NSArray *p in e) { block(p[0], [p[1] rangeValue], &stop); if (stop) break; }
}
- (void)enumerateAttribute:(NSAttributedStringKey)name inRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(id, NSRange, BOOL *))block {
    NSMutableArray *values = [NSMutableArray array], *ranges = [NSMutableArray array];
    [self enumerateAttributesInRange:range options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) {
        id v = a[name] ?: [NSNull null];
        if (values.count && [values.lastObject isEqual:v] && !(opts & NSAttributedStringEnumerationLongestEffectiveRangeNotRequired)) {
            NSRange last = [ranges.lastObject rangeValue];
            ranges[ranges.count - 1] = [NSValue valueWithRange:NSMakeRange(last.location, NSMaxRange(r) - last.location)];
        } else { [values addObject:v]; [ranges addObject:[NSValue valueWithRange:r]]; }
    }];
    BOOL stop = NO, rev = (opts & NSAttributedStringEnumerationReverse) != 0;
    for (NSUInteger k = 0; k < values.count; k++) {
        NSUInteger i = rev ? values.count - 1 - k : k;
        id v = values[i] == [NSNull null] ? nil : values[i];
        block(v, [ranges[i] rangeValue], &stop);
        if (stop) break;
    }
}
- (BOOL)isEqualToAttributedString:(NSAttributedString *)other {
    if (![_str isEqualToString:other.string]) return NO;
    __block BOOL same = YES;
    NSMutableArray *mine = [NSMutableArray array];
    [self enumerateAttributesInRange:NSMakeRange(0, self.length) options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) { [mine addObject:@[a, [NSValue valueWithRange:r]]]; }];
    __block NSUInteger i = 0;
    [other enumerateAttributesInRange:NSMakeRange(0, other.length) options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) {
        if (i >= mine.count || ![mine[i][0] isEqual:a] || !NSEqualRanges([mine[i][1] rangeValue], r)) { same = NO; *stop = YES; }
        i++;
    }];
    return same && i == mine.count;
}
- (BOOL)isEqual:(id)object { return object == self || ([object isKindOfClass:[NSAttributedString class]] && [self isEqualToAttributedString:object]); }
- (NSUInteger)hash { return _str.hash; }
- (NSString *)description {
    NSMutableString *d = [NSMutableString string];
    [self enumerateAttributesInRange:NSMakeRange(0, self.length) options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) {
        [d appendFormat:@"%@{\n", [self->_str substringWithRange:r]];
        for (NSString *k in [a.allKeys sortedArrayUsingSelector:@selector(compare:)]) [d appendFormat:@"    %@ = %@;\n", k, a[k]];
        [d appendString:@"}"];
    }];
    return d;
}
/* keyed archive: NSString + NSAttributes (one dictionary, or an array plus NSAttributeInfo run table) */
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[_str copy] forKey:@"NSString"];
    if (_runs.count <= 1) { [coder encodeObject:_runs.firstObject ? _runs.firstObject->attrs : @{} forKey:@"NSAttributes"]; return; }
    NSMutableArray *dicts = [NSMutableArray array];
    NSMutableData *info = [NSMutableData data];
    for (_IsimAttrRun *r in _runs) {
        NSUInteger idx = [dicts indexOfObject:r->attrs];
        if (idx == NSNotFound) { idx = dicts.count; [dicts addObject:r->attrs]; }
        for (NSUInteger v = r->len, w = idx, pass = 0; pass < 2; pass++, v = w) {   /* LEB128 varints */
            do { uint8_t b = v & 0x7F; v >>= 7; if (v) b |= 0x80; [info appendBytes:&b length:1]; } while (v);
        }
    }
    [coder encodeObject:dicts forKey:@"NSAttributes"];
    [coder encodeObject:info forKey:@"NSAttributeInfo"];
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    NSString *s = [coder decodeObjectOfClass:[NSString class] forKey:@"NSString"] ?: @"";
    if (!(self = [self initWithString:s attributes:nil])) return nil;
    NSSet *plist = [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSData class], [NSDate class], [NSURL class], nil];
    id attrs = [coder decodeObjectOfClasses:plist forKey:@"NSAttributes"];
    NSData *info = [coder decodeObjectOfClass:[NSData class] forKey:@"NSAttributeInfo"];
    [_runs removeAllObjects];
    if ([attrs isKindOfClass:[NSDictionary class]] || !info) {
        if (s.length) [_runs addObject:[_IsimAttrRun run:s.length attrs:[attrs isKindOfClass:[NSDictionary class]] ? attrs : nil]];
        return self;
    }
    const uint8_t *p = info.bytes, *end = p + info.length;
    while (p < end) {
        NSUInteger vals[2] = {0, 0};
        for (int k = 0; k < 2; k++) { unsigned shift = 0; while (p < end) { uint8_t b = *p++; vals[k] |= (NSUInteger)(b & 0x7F) << shift; shift += 7; if (!(b & 0x80)) break; } }
        [_runs addObject:[_IsimAttrRun run:vals[0] attrs:vals[1] < [attrs count] ? attrs[vals[1]] : nil]];
    }
    return self;
}
@end

@implementation NSMutableAttributedString
- (id)copyWithZone:(NSZone *)zone { return [[NSAttributedString alloc] initWithAttributedString:self]; }
- (NSMutableString *)mutableString { return [_str mutableCopy]; }
/* ensure a run boundary at `loc`; returns the index of the run starting there (or _runs.count at the end) */
- (NSUInteger)_splitAt:(NSUInteger)loc {
    NSUInteger pos = 0;
    for (NSUInteger i = 0; i < _runs.count; i++) {
        _IsimAttrRun *r = _runs[i];
        if (pos == loc) return i;
        if (loc < pos + r->len) {
            NSUInteger left = loc - pos;
            [_runs insertObject:[_IsimAttrRun run:r->len - left attrs:r->attrs] atIndex:i + 1];
            r->len = left;
            return i + 1;
        }
        pos += r->len;
    }
    return _runs.count;
}
- (void)_coalesce {
    for (NSUInteger i = 0; i < _runs.count;) {
        if (_runs[i]->len == 0) { [_runs removeObjectAtIndex:i]; continue; }
        if (i > 0 && [_runs[i - 1]->attrs isEqualToDictionary:_runs[i]->attrs]) { _runs[i - 1]->len += _runs[i]->len; [_runs removeObjectAtIndex:i]; continue; }
        i++;
    }
}
- (void)_replaceRunsInRange:(NSRange)range with:(NSArray<_IsimAttrRun *> *)runs {
    NSUInteger a = [self _splitAt:range.location], b = [self _splitAt:NSMaxRange(range)];
    [_runs removeObjectsInRange:NSMakeRange(a, b - a)];
    [_runs insertObjects:runs atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(a, runs.count)]];
    [self _coalesce];
}
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
    check_index(self, NSMaxRange(range), _str.length);
    NSDictionary *attrs = @{};
    if (_str.length) {
        NSUInteger at = range.length ? range.location : range.location > 0 ? range.location - 1 : 0;
        attrs = [self attributesAtIndex:MIN(at, _str.length - 1) effectiveRange:NULL];
    }
    [self _replaceRunsInRange:range with:str.length ? @[[_IsimAttrRun run:str.length attrs:attrs]] : @[]];
    [_str replaceCharactersInRange:range withString:str];
}
- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range {
    check_index(self, NSMaxRange(range), _str.length);
    if (range.length) [self _replaceRunsInRange:range with:@[[_IsimAttrRun run:range.length attrs:attrs]]];
}
- (void)_editAttributesInRange:(NSRange)range with:(void (^)(NSMutableDictionary *))edit {
    check_index(self, NSMaxRange(range), _str.length);
    if (!range.length) return;
    NSMutableArray *runs = [NSMutableArray array];
    [self enumerateAttributesInRange:range options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) {
        NSMutableDictionary *m = [a mutableCopy]; edit(m);
        [runs addObject:[_IsimAttrRun run:r.length attrs:m]];
    }];
    [self _replaceRunsInRange:range with:runs];
}
- (void)addAttribute:(NSAttributedStringKey)name value:(id)value range:(NSRange)range {
    if (!value) [NSException raise:NSInvalidArgumentException format:@"NSMutableAttributedString addAttribute:value:range: nil value"];
    [self _editAttributesInRange:range with:^(NSMutableDictionary *m) { m[name] = value; }];
}
- (void)addAttributes:(NSDictionary *)attrs range:(NSRange)range { [self _editAttributesInRange:range with:^(NSMutableDictionary *m) { [m addEntriesFromDictionary:attrs]; }]; }
- (void)removeAttribute:(NSAttributedStringKey)name range:(NSRange)range { [self _editAttributesInRange:range with:^(NSMutableDictionary *m) { [m removeObjectForKey:name]; }]; }
- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)other {
    check_index(self, NSMaxRange(range), _str.length);
    NSMutableArray *runs = [NSMutableArray array];
    [other enumerateAttributesInRange:NSMakeRange(0, other.length) options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) { [runs addObject:[_IsimAttrRun run:r.length attrs:a]]; }];
    NSString *s = other.string;
    [self _replaceRunsInRange:range with:runs];
    [_str replaceCharactersInRange:range withString:s];
}
- (void)insertAttributedString:(NSAttributedString *)s atIndex:(NSUInteger)loc { [self replaceCharactersInRange:NSMakeRange(loc, 0) withAttributedString:s]; }
- (void)appendAttributedString:(NSAttributedString *)s { [self replaceCharactersInRange:NSMakeRange(_str.length, 0) withAttributedString:s]; }
- (void)deleteCharactersInRange:(NSRange)range { [self replaceCharactersInRange:range withString:@""]; }
- (void)setAttributedString:(NSAttributedString *)s { [self replaceCharactersInRange:NSMakeRange(0, _str.length) withAttributedString:s]; }
- (void)beginEditing {}
- (void)endEditing {}
@end
