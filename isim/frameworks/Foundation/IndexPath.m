/* NSIndexPath: an immutable list of indexes (UIKit adds row/section/item). */
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

@implementation NSIndexPath { NSUInteger *_idx; NSUInteger _len; }
+ (instancetype)indexPathWithIndex:(NSUInteger)i { return [[self alloc] initWithIndex:i]; }
+ (instancetype)indexPathWithIndexes:(const NSUInteger *)ix length:(NSUInteger)n { return [[self alloc] initWithIndexes:ix length:n]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)init { return [self initWithIndexes:NULL length:0]; }
- (instancetype)initWithIndex:(NSUInteger)i { return [self initWithIndexes:&i length:1]; }
- (instancetype)initWithIndexes:(const NSUInteger *)ix length:(NSUInteger)n {
    if ((self = [super init])) {
        _len = ix ? n : 0;
        _idx = _len ? malloc(sizeof *_idx * _len) : NULL;
        if (_len) memcpy(_idx, ix, sizeof *_idx * _len);
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (void)dealloc { free(_idx); }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSUInteger)length { return _len; }
- (NSUInteger)indexAtPosition:(NSUInteger)p { return p < _len ? _idx[p] : NSNotFound; }
- (NSIndexPath *)indexPathByAddingIndex:(NSUInteger)i {
    NSUInteger *t = malloc(sizeof *t * (_len + 1)); if (_len) memcpy(t, _idx, sizeof *t * _len); t[_len] = i;
    NSIndexPath *r = [[NSIndexPath alloc] initWithIndexes:t length:_len + 1]; free(t); return r;
}
- (NSIndexPath *)indexPathByRemovingLastIndex { return [[NSIndexPath alloc] initWithIndexes:_idx length:_len ? _len - 1 : 0]; }
- (void)getIndexes:(NSUInteger *)out range:(NSRange)r { for (NSUInteger i = 0; i < r.length && r.location + i < _len; i++) out[i] = _idx[r.location + i]; }
- (void)getIndexes:(NSUInteger *)out { if (_len) memcpy(out, _idx, sizeof *out * _len); }
- (NSComparisonResult)compare:(NSIndexPath *)o {
    NSUInteger n = MIN(_len, o.length);
    for (NSUInteger i = 0; i < n; i++) {
        NSUInteger a = _idx[i], b = [o indexAtPosition:i];
        if (a != b) return a < b ? NSOrderedAscending : NSOrderedDescending;
    }
    return _len == o.length ? NSOrderedSame : _len < o.length ? NSOrderedAscending : NSOrderedDescending;
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSIndexPath class]] && [self compare:o] == NSOrderedSame; }
- (NSUInteger)hash { NSUInteger h = _len; for (NSUInteger i = 0; i < _len; i++) h = h * 31 + _idx[i]; return h; }
- (NSString *)description {
    NSMutableString *s = [NSMutableString stringWithFormat:@"<NSIndexPath: %p> {length = %lu, path = ", self, (unsigned long)_len];
    for (NSUInteger i = 0; i < _len; i++) [s appendFormat:i ? @" - %lu" : @"%lu", (unsigned long)_idx[i]];
    [s appendString:@"}"];
    return s;
}
@end
