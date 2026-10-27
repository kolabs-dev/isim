// isim CoreText: run delegates, ruby annotations, glyph infos, font collections, and glyphs by name. Laying them out
// (run delegates as Pango shapes, ruby drawn over its base text) is in CTLayout.m.
#import "CTPrivate.h"

#define K(k) ((__bridge NSString *)(k))
const CFStringRef kCTRunDelegateAttributeName = CFSTR("CTRunDelegate");
const CFStringRef kCTRubyAnnotationAttributeName = CFSTR("CTRubyAnnotation");
const CFStringRef kCTGlyphInfoAttributeName = CFSTR("NSGlyphInfo");
const CFStringRef kCTRubyAnnotationSizeFactorAttributeName = CFSTR("CTRubyAnnotationSizeFactor");
const CFStringRef kCTRubyAnnotationScaleToFitAttributeName = CFSTR("CTRubyAnnotationScaleToFit");
const CFStringRef kCTFontCollectionRemoveDuplicatesOption = CFSTR("RemoveDuplicates");
const CFStringRef kCTFontCollectionIncludeDisabledFontsOption = CFSTR("NSFontCollectionIncludeDisabledFontsOption");
const CFStringRef kCTFontCollectionDisallowAutoActivationOption = CFSTR("NSFontCollectionDisallowAutoActivationOption");

/* ---------------- run delegates ---------------- */
@implementation __NSCTRunDelegate
- (void)dealloc { if (_callbacks.dealloc) _callbacks.dealloc(_refCon); }
- (CGFloat)ascent { return _callbacks.getAscent ? _callbacks.getAscent(_refCon) : 0; }
- (CGFloat)descent { return _callbacks.getDescent ? _callbacks.getDescent(_refCon) : 0; }
- (CGFloat)width { return _callbacks.getWidth ? _callbacks.getWidth(_refCon) : 0; }
@end
CFTypeID CTRunDelegateGetTypeID(void) { return 0x435c; }
CTRunDelegateRef CTRunDelegateCreate(const CTRunDelegateCallbacks *callbacks, void *refCon) {
    if (!callbacks || callbacks->version != kCTRunDelegateVersion1) return NULL;
    __NSCTRunDelegate *d = [__NSCTRunDelegate new];
    d->_callbacks = *callbacks; d->_refCon = refCon;
    return (CTRunDelegateRef)CFBridgingRetain(d);
}
void *CTRunDelegateGetRefCon(CTRunDelegateRef d) { return ((__bridge __NSCTRunDelegate *)d)->_refCon; }

/* ---------------- ruby annotations ---------------- */
@implementation __NSCTRubyAnnotation
@end
CFTypeID CTRubyAnnotationGetTypeID(void) { return 0x435d; }
static __NSCTRubyAnnotation *RA(CTRubyAnnotationRef r) { return (__bridge __NSCTRubyAnnotation *)r; }
CTRubyAnnotationRef CTRubyAnnotationCreate(CTRubyAlignment alignment, CTRubyOverhang overhang, CGFloat sizeFactor, CFStringRef text[kCTRubyPositionCount]) {
    __NSCTRubyAnnotation *r = [__NSCTRubyAnnotation new];
    r->_alignment = alignment; r->_overhang = overhang; r->_sizeFactor = sizeFactor > 0 ? sizeFactor : 0.5;
    for (int i = 0; i < kCTRubyPositionCount; i++) r->_text[i] = text && text[i] ? [(__bridge NSString *)text[i] copy] : nil;
    return (CTRubyAnnotationRef)CFBridgingRetain(r);
}
CTRubyAnnotationRef CTRubyAnnotationCreateWithAttributes(CTRubyAlignment alignment, CTRubyOverhang overhang, CTRubyPosition position, CFStringRef string,
                                                         CFDictionaryRef attributes) {
    __NSCTRubyAnnotation *r = [__NSCTRubyAnnotation new];
    NSDictionary *a = (__bridge NSDictionary *)attributes;
    r->_alignment = alignment; r->_overhang = overhang;
    r->_sizeFactor = [a[K(kCTRubyAnnotationSizeFactorAttributeName)] doubleValue] > 0 ? [a[K(kCTRubyAnnotationSizeFactorAttributeName)] doubleValue] : 0.5;
    if (position < kCTRubyPositionCount) r->_text[position] = [(__bridge NSString *)string copy];
    r->_attributes = [a copy];
    return (CTRubyAnnotationRef)CFBridgingRetain(r);
}
CTRubyAnnotationRef CTRubyAnnotationCreateCopy(CTRubyAnnotationRef o) {
    __NSCTRubyAnnotation *r = [__NSCTRubyAnnotation new], *s = RA(o);
    r->_alignment = s->_alignment; r->_overhang = s->_overhang; r->_sizeFactor = s->_sizeFactor; r->_attributes = s->_attributes;
    for (int i = 0; i < kCTRubyPositionCount; i++) r->_text[i] = s->_text[i];
    return (CTRubyAnnotationRef)CFBridgingRetain(r);
}
CTRubyAlignment CTRubyAnnotationGetAlignment(CTRubyAnnotationRef r) { return RA(r)->_alignment; }
CTRubyOverhang CTRubyAnnotationGetOverhang(CTRubyAnnotationRef r) { return RA(r)->_overhang; }
CGFloat CTRubyAnnotationGetSizeFactor(CTRubyAnnotationRef r) { return RA(r)->_sizeFactor; }
CFStringRef CTRubyAnnotationGetTextForPosition(CTRubyAnnotationRef r, CTRubyPosition p) {
    return p < kCTRubyPositionCount ? (__bridge CFStringRef)RA(r)->_text[p] : NULL;
}

/* ---------------- glyph infos ---------------- */
@interface __NSCTGlyphInfo : NSObject {
@public NSString *_name, *_base; CGGlyph _glyph; CGFontIndex _cid; CTCharacterCollection _collection;
}
@end
@implementation __NSCTGlyphInfo
@end
CFTypeID CTGlyphInfoGetTypeID(void) { return 0x435e; }
static __NSCTGlyphInfo *GI(CTGlyphInfoRef g) { return (__bridge __NSCTGlyphInfo *)g; }
CTGlyphInfoRef CTGlyphInfoCreateWithGlyphName(CFStringRef name, CTFontRef font, CFStringRef base) {
    if (!name || !font || !base) return NULL;
    CGGlyph g = CTFontGetGlyphWithName(font, name);
    if (!g) return NULL;
    __NSCTGlyphInfo *i = [__NSCTGlyphInfo new];
    i->_name = [(__bridge NSString *)name copy]; i->_glyph = g; i->_base = [(__bridge NSString *)base copy];
    return (CTGlyphInfoRef)CFBridgingRetain(i);
}
CTGlyphInfoRef CTGlyphInfoCreateWithGlyph(CGGlyph glyph, CTFontRef font, CFStringRef base) {
    if (!font || !base) return NULL;
    __NSCTGlyphInfo *i = [__NSCTGlyphInfo new];
    i->_glyph = glyph; i->_base = [(__bridge NSString *)base copy];
    i->_name = CFBridgingRelease(CTFontCopyNameForGlyph(font, glyph));
    return (CTGlyphInfoRef)CFBridgingRetain(i);
}
CTGlyphInfoRef CTGlyphInfoCreateWithCharacterIdentifier(CGFontIndex cid, CTCharacterCollection collection, CFStringRef base) {
    if (!base || cid == kCGFontIndexInvalid) return NULL;
    __NSCTGlyphInfo *i = [__NSCTGlyphInfo new];
    i->_cid = cid; i->_collection = collection; i->_base = [(__bridge NSString *)base copy];
    if (collection == kCTCharacterCollectionIdentityMapping) i->_glyph = cid;   /* identity: the CID is the glyph */
    return (CTGlyphInfoRef)CFBridgingRetain(i);
}
CFStringRef CTGlyphInfoGetGlyphName(CTGlyphInfoRef g) { return (__bridge CFStringRef)GI(g)->_name; }
CGGlyph CTGlyphInfoGetGlyph(CTGlyphInfoRef g) { return GI(g)->_glyph; }
CGFontIndex CTGlyphInfoGetCharacterIdentifier(CTGlyphInfoRef g) { return GI(g)->_cid; }
CTCharacterCollection CTGlyphInfoGetCharacterCollection(CTGlyphInfoRef g) { return GI(g)->_collection; }

/* ---------------- glyphs by name ---------------- */
CGGlyph CTFontGetGlyphWithName(CTFontRef font, CFStringRef name) {
    __NSCTFont *f = isim_ct_font((__bridge id)font);
    if (!f || !name) return 0;
    return (CGGlyph)isim_ct_font_glyph_from_name([f host], [(__bridge NSString *)name UTF8String]);
}
CFStringRef CTFontCopyNameForGlyph(CTFontRef font, CGGlyph glyph) {
    __NSCTFont *f = isim_ct_font((__bridge id)font);
    char buf[128];
    if (!f || !isim_ct_font_glyph_name([f host], glyph, buf, (int)sizeof buf)) return NULL;
    return (CFStringRef)CFBridgingRetain([NSString stringWithUTF8String:buf]);
}

/* ---------------- font collections ---------------- */
@interface __NSCTFontCollection : NSObject {
@public NSArray *_queries;   /* descriptors; nil: every available font */
    NSDictionary *_options;
}
@end
@implementation __NSCTFontCollection
@end
CFTypeID CTFontCollectionGetTypeID(void) { return 0x435f; }
static __NSCTFontCollection *FC(CTFontCollectionRef c) { return (__bridge __NSCTFontCollection *)c; }
CTFontCollectionRef CTFontCollectionCreateFromAvailableFonts(CFDictionaryRef options) {
    __NSCTFontCollection *c = [__NSCTFontCollection new];
    c->_options = [(__bridge NSDictionary *)options copy];
    return (CTFontCollectionRef)CFBridgingRetain(c);
}
CTFontCollectionRef CTFontCollectionCreateWithFontDescriptors(CFArrayRef queries, CFDictionaryRef options) {
    __NSCTFontCollection *c = [__NSCTFontCollection new];
    c->_queries = [(__bridge NSArray *)queries copy] ?: @[];
    c->_options = [(__bridge NSDictionary *)options copy];
    return (CTFontCollectionRef)CFBridgingRetain(c);
}
CTFontCollectionRef CTFontCollectionCreateCopyWithFontDescriptors(CTFontCollectionRef original, CFArrayRef queries, CFDictionaryRef options) {
    __NSCTFontCollection *c = [__NSCTFontCollection new], *o = FC(original);
    c->_queries = queries ? [(__bridge NSArray *)queries copy] : o->_queries;
    c->_options = options ? [(__bridge NSDictionary *)options copy] : o->_options;
    return (CTFontCollectionRef)CFBridgingRetain(c);
}
/* every face fontconfig lists, as descriptors (family, then PostScript name) */
static NSArray *all_faces(void) {
    int len = 1 << 20; char *buf = malloc((size_t)len);
    isim_ct_font_faces(NULL, buf, len);
    NSString *list = [NSString stringWithUTF8String:buf];
    free(buf);
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSString *line in [list componentsSeparatedByString:@"\n"]) {
        NSArray *c = [line componentsSeparatedByString:@"\t"];
        if (c.count < 6 || [seen containsObject:c[0]]) continue;
        [seen addObject:c[0]];
        int w = [c[3] intValue], it = [c[4] intValue];
        NSDictionary *traits = @{ K(kCTFontSymbolicTrait): @((w >= 600 ? kCTFontTraitBold : 0) | (it ? kCTFontTraitItalic : 0)) };
        [out addObject:CFBridgingRelease(CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)@{
            K(kCTFontNameAttribute): c[0], K(kCTFontStyleNameAttribute): c[1], K(kCTFontFamilyNameAttribute): c[2], K(kCTFontTraitsAttribute): traits }))];
    }
    [out sortUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *fa = CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)a, kCTFontFamilyNameAttribute));
        NSString *fb = CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)b, kCTFontFamilyNameAttribute));
        NSComparisonResult r = [fa localizedStandardCompare:fb];
        if (r != NSOrderedSame) return r;
        NSString *na = CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)a, kCTFontNameAttribute));
        NSString *nb = CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)b, kCTFontNameAttribute));
        return [na compare:nb];
    }];
    return out;
}
static NSString *ps_name(id d) { return CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)d, kCTFontNameAttribute)); }
/* the faces that match a query: the attributes it gives are mandatory */
static NSArray *matching(id query) {
    NSDictionary *a = CFBridgingRelease(CTFontDescriptorCopyAttributes((__bridge CTFontDescriptorRef)query));
    NSMutableSet *must = [NSMutableSet set];
    for (NSString *k in @[ K(kCTFontNameAttribute), K(kCTFontStyleNameAttribute), K(kCTFontTraitsAttribute) ]) if (a[k]) [must addObject:k];
    if (!a[K(kCTFontNameAttribute)] && !a[K(kCTFontFamilyNameAttribute)]) {   /* traits alone: filter every face */
        NSDictionary *t = a[K(kCTFontTraitsAttribute)];
        uint32_t want = [t[K(kCTFontSymbolicTrait)] unsignedIntValue] & (kCTFontTraitBold | kCTFontTraitItalic);
        NSMutableArray *out = [NSMutableArray array];
        for (id d in all_faces()) {
            NSDictionary *dt = CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)d, kCTFontTraitsAttribute));
            if (([dt[K(kCTFontSymbolicTrait)] unsignedIntValue] & want) == want) [out addObject:d];
        }
        return out;
    }
    return CFBridgingRelease(CTFontDescriptorCreateMatchingFontDescriptors((__bridge CTFontDescriptorRef)query, (__bridge CFSetRef)must)) ?: @[];
}
static NSArray *collection_faces(__NSCTFontCollection *c, NSDictionary *options) {
    if (!c->_queries) return all_faces();
    BOOL unique = [(options ?: c->_options)[K(kCTFontCollectionRemoveDuplicatesOption)] boolValue];
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (id q in c->_queries)
        for (id d in matching(q)) {
            NSString *ps = ps_name(d);
            if (unique && ps && [seen containsObject:ps]) continue;
            if (ps) [seen addObject:ps];
            [out addObject:d];
        }
    return out;
}
CFArrayRef CTFontCollectionCreateMatchingFontDescriptors(CTFontCollectionRef c) {
    NSArray *a = collection_faces(FC(c), nil);
    return a.count ? (CFArrayRef)CFBridgingRetain(a) : NULL;
}
CFArrayRef CTFontCollectionCreateMatchingFontDescriptorsWithOptions(CTFontCollectionRef c, CFDictionaryRef options) {
    NSArray *a = collection_faces(FC(c), (__bridge NSDictionary *)options);
    return a.count ? (CFArrayRef)CFBridgingRetain(a) : NULL;
}
CFArrayRef CTFontCollectionCreateMatchingFontDescriptorsSortedWithCallback(CTFontCollectionRef c, CTFontCollectionSortDescriptorsCallback cb, void *refCon) {
    NSArray *a = collection_faces(FC(c), nil);
    if (!a.count) return NULL;
    if (cb) a = [a sortedArrayUsingComparator:^NSComparisonResult(id x, id y) {
        return (NSComparisonResult)cb((__bridge CTFontDescriptorRef)x, (__bridge CTFontDescriptorRef)y, refCon);
    }];
    return (CFArrayRef)CFBridgingRetain(a);
}
/* each face's value of one attribute, or (dicts) a dictionary of the attributes it has */
static id attribute_values(NSArray *faces, NSArray<NSString *> *names, BOOL dicts, CTFontCollectionCopyOptions options) {
    NSMutableArray *out = [NSMutableArray array];
    for (id d in faces) {
        if (!dicts) {
            id v = CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)d, (__bridge CFStringRef)names[0]));
            [out addObject:v ?: [NSNull null]];
        } else {
            NSMutableDictionary *m = [NSMutableDictionary dictionary];
            for (NSString *n in names) { id v = CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)d, (__bridge CFStringRef)n)); if (v) m[n] = v; }
            [out addObject:m];
        }
    }
    if (options & kCTFontCollectionCopyUnique) {
        NSMutableArray *u = [NSMutableArray array];
        for (id v in out) if (![u containsObject:v]) [u addObject:v];
        out = u;
    }
    if (options & kCTFontCollectionCopyStandardSort)
        [out sortUsingComparator:^NSComparisonResult(id x, id y) {
            return [x isKindOfClass:[NSString class]] && [y isKindOfClass:[NSString class]] ? [x localizedStandardCompare:y]
                                                                                          : [[x description] compare:[y description]];
        }];
    return out;
}
CFArrayRef CTFontCollectionCopyFontAttribute(CTFontCollectionRef c, CFStringRef name, CTFontCollectionCopyOptions options) {
    return (CFArrayRef)CFBridgingRetain(attribute_values(collection_faces(FC(c), nil), @[ (__bridge NSString *)name ], NO, options));
}
CFArrayRef CTFontCollectionCopyFontAttributes(CTFontCollectionRef c, CFSetRef names, CTFontCollectionCopyOptions options) {
    NSArray *n = [(__bridge NSSet *)names allObjects];
    return (CFArrayRef)CFBridgingRetain(attribute_values(collection_faces(FC(c), nil), n, YES, options));
}
