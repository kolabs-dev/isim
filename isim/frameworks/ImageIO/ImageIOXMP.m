/* isim ImageIO: CGImageMetadata (issue #272), isim's own XMP model (adapted). Tags have a namespace, prefix, name,
 * type and value (a string, an array of tags, or a structure of field tags); packets are read with NSXMLParser and
 * written by isim. The EXIF / TIFF / GPS / IPTC properties of an image map to their XMP names (ImageIOMetadata.m):
 * rationals as "n/d", dates as ISO 8601, GPS coordinates as "DDD,MM.mmmmK". */
#import <Foundation/Foundation.h>
#include <ImageIO/ImageIO.h>
#include <math.h>
#import "ImageIOPrivate.h"

#define S(k) ((__bridge NSString *)(k))
#define K(name, value) const CFStringRef name = CFSTR(value);
K(kCGImageMetadataNamespaceExif, "http://ns.adobe.com/exif/1.0/") K(kCGImageMetadataNamespaceExifAux, "http://ns.adobe.com/exif/1.0/aux/")
K(kCGImageMetadataNamespaceExifEX, "http://cipa.jp/exif/1.0/") K(kCGImageMetadataNamespaceDublinCore, "http://purl.org/dc/elements/1.1/")
K(kCGImageMetadataNamespaceIPTCCore, "http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/")
K(kCGImageMetadataNamespaceIPTCExtension, "http://iptc.org/std/Iptc4xmpExt/2008-02-29/")
K(kCGImageMetadataNamespacePhotoshop, "http://ns.adobe.com/photoshop/1.0/") K(kCGImageMetadataNamespaceTIFF, "http://ns.adobe.com/tiff/1.0/")
K(kCGImageMetadataNamespaceXMPBasic, "http://ns.adobe.com/xap/1.0/") K(kCGImageMetadataNamespaceXMPRights, "http://ns.adobe.com/xap/1.0/rights/")
K(kCGImageMetadataPrefixExif, "exif") K(kCGImageMetadataPrefixExifAux, "aux") K(kCGImageMetadataPrefixExifEX, "exifEX")
K(kCGImageMetadataPrefixDublinCore, "dc") K(kCGImageMetadataPrefixIPTCCore, "Iptc4xmpCore") K(kCGImageMetadataPrefixIPTCExtension, "Iptc4xmpExt")
K(kCGImageMetadataPrefixPhotoshop, "photoshop") K(kCGImageMetadataPrefixTIFF, "tiff") K(kCGImageMetadataPrefixXMPBasic, "xmp")
K(kCGImageMetadataPrefixXMPRights, "xmpRights")
K(kCFErrorDomainCGImageMetadata, "kCFErrorDomainCGImageMetadata") K(kCGImageMetadataEnumerateRecursively, "kCGImageMetadataEnumerateRecursively")
K(kCGImageMetadataShouldExcludeXMP, "kCGImageMetadataShouldExcludeXMP") K(kCGImageMetadataShouldExcludeGPS, "kCGImageMetadataShouldExcludeGPS")
static NSString *const RDF = @"http://www.w3.org/1999/02/22-rdf-syntax-ns#";
static NSString *const XMLNS = @"http://www.w3.org/XML/1998/namespace";

static NSDictionary<NSString *, NSString *> *builtin_prefixes(void) {
    static NSDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = @{ S(kCGImageMetadataPrefixExif): S(kCGImageMetadataNamespaceExif), S(kCGImageMetadataPrefixExifAux): S(kCGImageMetadataNamespaceExifAux),
               S(kCGImageMetadataPrefixExifEX): S(kCGImageMetadataNamespaceExifEX), S(kCGImageMetadataPrefixDublinCore): S(kCGImageMetadataNamespaceDublinCore),
               S(kCGImageMetadataPrefixIPTCCore): S(kCGImageMetadataNamespaceIPTCCore),
               S(kCGImageMetadataPrefixIPTCExtension): S(kCGImageMetadataNamespaceIPTCExtension),
               S(kCGImageMetadataPrefixPhotoshop): S(kCGImageMetadataNamespacePhotoshop), S(kCGImageMetadataPrefixTIFF): S(kCGImageMetadataNamespaceTIFF),
               S(kCGImageMetadataPrefixXMPBasic): S(kCGImageMetadataNamespaceXMPBasic), S(kCGImageMetadataPrefixXMPRights): S(kCGImageMetadataNamespaceXMPRights),
               @"xml": XMLNS };
    });
    return d;
}

/* ---------------- tags and metadata ---------------- */
@interface __CGImageMetadataTag : NSObject {
@public NSString *_ns, *_prefix, *_name; CGImageMetadataType _type; id _value; NSArray *_qualifiers;
}
@end
@implementation __CGImageMetadataTag
- (NSString *)description {
    return [NSString stringWithFormat:@"%@:%@ = %@", _prefix ?: @"?", _name ?: @"", [_value isKindOfClass:[NSString class]] ? _value : [_value description]];
}
- (id)copyDeep {
    __CGImageMetadataTag *t = [__CGImageMetadataTag new];
    t->_ns = _ns; t->_prefix = _prefix; t->_name = _name; t->_type = _type; t->_qualifiers = _qualifiers;
    if ([_value isKindOfClass:[NSArray class]]) { NSMutableArray *a = [NSMutableArray array]; for (__CGImageMetadataTag *x in _value) [a addObject:[x copyDeep]]; t->_value = a; }
    else if ([_value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        [(NSDictionary *)_value enumerateKeysAndObjectsUsingBlock:^(id k, __CGImageMetadataTag *x, BOOL *stop) { d[k] = [x copyDeep]; }];
        t->_value = d;
    } else t->_value = _value;
    return t;
}
- (NSString *)path { return [NSString stringWithFormat:@"%@:%@", _prefix, _name]; }
@end
@interface __CGImageMetadata : NSObject {
@public NSMutableDictionary<NSString *, NSString *> *_prefixes; NSMutableArray<__CGImageMetadataTag *> *_tags;
}
@end
@implementation __CGImageMetadata
- (instancetype)init { if ((self = [super init])) { _prefixes = [builtin_prefixes() mutableCopy]; _tags = [NSMutableArray array]; } return self; }
- (NSString *)description { return [NSString stringWithFormat:@"<CGImageMetadata %p> %@", self, _tags]; }
@end
static __CGImageMetadata *MD(CGImageMetadataRef m) { return (__bridge __CGImageMetadata *)m; }
static __CGImageMetadataTag *TG(CGImageMetadataTagRef t) { return (__bridge __CGImageMetadataTag *)t; }

CFTypeID CGImageMetadataGetTypeID(void) { return 0x494D; }
CFTypeID CGImageMetadataTagGetTypeID(void) { return 0x494E; }
CGMutableImageMetadataRef CGImageMetadataCreateMutable(void) { return (CGMutableImageMetadataRef)CFBridgingRetain([__CGImageMetadata new]); }
CGMutableImageMetadataRef CGImageMetadataCreateMutableCopy(CGImageMetadataRef m) {
    if (!m) return NULL;
    __CGImageMetadata *o = MD(m), *c = [__CGImageMetadata new];
    [c->_prefixes addEntriesFromDictionary:o->_prefixes];
    for (__CGImageMetadataTag *t in o->_tags) [c->_tags addObject:[t copyDeep]];
    return (CGMutableImageMetadataRef)CFBridgingRetain(c);
}
static __CGImageMetadataTag *make_tag(NSString *ns, NSString *prefix, NSString *name, CGImageMetadataType type, id value);
/* a tag's value from a CF value: strings stay strings; numbers and booleans become strings; arrays and dictionaries
 * hold tags */
static id normalized(id v, NSString *ns, NSString *prefix, CGImageMetadataType *type) {
    if ([v isKindOfClass:[__CGImageMetadataTag class]]) return v;
    if ([v isKindOfClass:[NSString class]]) { if (*type == kCGImageMetadataTypeDefault) *type = kCGImageMetadataTypeString; return [v copy]; }
    if (v == (id)kCFBooleanTrue || v == (id)kCFBooleanFalse) { if (*type == kCGImageMetadataTypeDefault) *type = kCGImageMetadataTypeString; return v == (id)kCFBooleanTrue ? @"True" : @"False"; }
    if ([v isKindOfClass:[NSNumber class]]) { if (*type == kCGImageMetadataTypeDefault) *type = kCGImageMetadataTypeString; return [v stringValue]; }
    if ([v isKindOfClass:[NSArray class]]) {
        if (*type == kCGImageMetadataTypeDefault || *type == kCGImageMetadataTypeString) *type = kCGImageMetadataTypeArrayOrdered;
        NSMutableArray *a = [NSMutableArray array];
        for (id x in v) [a addObject:[x isKindOfClass:[__CGImageMetadataTag class]] ? x : make_tag(ns, prefix, nil, kCGImageMetadataTypeDefault, x)];
        return a;
    }
    if ([v isKindOfClass:[NSDictionary class]]) {
        *type = kCGImageMetadataTypeStructure;
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        [(NSDictionary *)v enumerateKeysAndObjectsUsingBlock:^(NSString *k, id x, BOOL *stop) {
            NSString *fp = prefix, *fn = k;
            NSRange c = [k rangeOfString:@":"];
            if (c.location != NSNotFound) { fp = [k substringToIndex:c.location]; fn = [k substringFromIndex:c.location + 1]; }
            __CGImageMetadataTag *t = [x isKindOfClass:[__CGImageMetadataTag class]] ? x : make_tag(ns, fp, fn, kCGImageMetadataTypeDefault, x);
            d[[NSString stringWithFormat:@"%@:%@", t->_prefix ?: fp, t->_name ?: fn]] = t;
        }];
        return d;
    }
    return nil;
}
static __CGImageMetadataTag *make_tag(NSString *ns, NSString *prefix, NSString *name, CGImageMetadataType type, id value) {
    __CGImageMetadataTag *t = [__CGImageMetadataTag new];
    t->_ns = ns; t->_prefix = prefix; t->_name = name;
    t->_value = normalized(value, ns, prefix, &type);
    t->_type = type;
    return t->_value ? t : nil;
}
CGImageMetadataTagRef CGImageMetadataTagCreate(CFStringRef ns, CFStringRef prefix, CFStringRef name, CGImageMetadataType type, CFTypeRef value) {
    if (!ns || !name || !value) return NULL;
    __block NSString *p = (__bridge NSString *)prefix;
    if (!p) [builtin_prefixes() enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) { if ([v isEqualToString:(__bridge NSString *)ns]) { p = k; *stop = YES; } }];
    __CGImageMetadataTag *t = make_tag((__bridge NSString *)ns, p, (__bridge NSString *)name, type, (__bridge id)value);
    return t ? (CGImageMetadataTagRef)CFBridgingRetain(t) : NULL;
}
CFStringRef CGImageMetadataTagCopyNamespace(CGImageMetadataTagRef t) { return t && TG(t)->_ns ? (CFStringRef)CFBridgingRetain(TG(t)->_ns) : NULL; }
CFStringRef CGImageMetadataTagCopyPrefix(CGImageMetadataTagRef t) { return t && TG(t)->_prefix ? (CFStringRef)CFBridgingRetain(TG(t)->_prefix) : NULL; }
CFStringRef CGImageMetadataTagCopyName(CGImageMetadataTagRef t) { return t && TG(t)->_name ? (CFStringRef)CFBridgingRetain(TG(t)->_name) : NULL; }
CFTypeRef CGImageMetadataTagCopyValue(CGImageMetadataTagRef t) { return t && TG(t)->_value ? CFBridgingRetain(TG(t)->_value) : NULL; }
CGImageMetadataType CGImageMetadataTagGetType(CGImageMetadataTagRef t) { return t ? TG(t)->_type : kCGImageMetadataTypeInvalid; }
CFArrayRef CGImageMetadataTagCopyQualifiers(CGImageMetadataTagRef t) { return t && TG(t)->_qualifiers.count ? (CFArrayRef)CFBridgingRetain(TG(t)->_qualifiers) : NULL; }
CFArrayRef CGImageMetadataCopyTags(CGImageMetadataRef m) { return m && MD(m)->_tags.count ? (CFArrayRef)CFBridgingRetain([MD(m)->_tags copy]) : NULL; }

/* ---------------- paths ---------------- */
/* "a:b.c:d[2]" -> ("a:b", ".c:d", "[2]") */
static NSArray<NSString *> *path_parts(NSString *path) {
    NSMutableArray *out = [NSMutableArray array];
    NSMutableString *cur = [NSMutableString string];
    for (NSUInteger i = 0; i < path.length; i++) {
        unichar c = [path characterAtIndex:i];
        if ((c == '.' || c == '[') && cur.length) { [out addObject:[cur copy]]; [cur setString:@""]; }
        if (c == '.') continue;
        [cur appendFormat:@"%C", c];
    }
    if (cur.length) [out addObject:cur];
    return out;
}
static id child_of(id container, NSString *part) {
    if ([part hasPrefix:@"["]) {
        if (![container isKindOfClass:[__CGImageMetadataTag class]]) return nil;
        NSArray *a = [((__CGImageMetadataTag *)container)->_value isKindOfClass:[NSArray class]] ? ((__CGImageMetadataTag *)container)->_value : nil;
        NSString *inner = [part substringWithRange:NSMakeRange(1, MAX(part.length, 2) - 2)];
        if ([inner hasPrefix:@"@xml:lang="]) {                         /* [@xml:lang=pt] */
            NSString *lang = [inner substringFromIndex:10];
            for (__CGImageMetadataTag *x in a) for (__CGImageMetadataTag *q in x->_qualifiers) if ([q->_name isEqual:@"lang"] && [q->_value isEqual:lang]) return x;
            return nil;
        }
        NSInteger i = inner.integerValue;
        return i >= 0 && i < (NSInteger)a.count ? a[(NSUInteger)i] : nil;
    }
    if ([container isKindOfClass:[__CGImageMetadata class]]) {
        for (__CGImageMetadataTag *t in ((__CGImageMetadata *)container)->_tags) if ([t.path isEqualToString:part]) return t;
        return nil;
    }
    __CGImageMetadataTag *t = container;
    return [t->_value isKindOfClass:[NSDictionary class]] ? t->_value[part] : nil;
}
static __CGImageMetadataTag *resolve(CGImageMetadataRef m, CGImageMetadataTagRef parent, NSString *path) {
    id at = parent ? (__bridge id)parent : MD(m);
    for (NSString *part in path_parts(path)) { at = child_of(at, part); if (!at) return nil; }
    return [at isKindOfClass:[__CGImageMetadataTag class]] ? at : nil;
}
CGImageMetadataTagRef CGImageMetadataCopyTagWithPath(CGImageMetadataRef m, CGImageMetadataTagRef parent, CFStringRef path) {
    __CGImageMetadataTag *t = m && path ? resolve(m, parent, (__bridge NSString *)path) : nil;
    return t ? (CGImageMetadataTagRef)CFBridgingRetain(t) : NULL;
}
static NSString *string_of(__CGImageMetadataTag *t) {
    if ([t->_value isKindOfClass:[NSString class]]) return t->_value;
    if (t->_type == kCGImageMetadataTypeAlternateText || t->_type == kCGImageMetadataTypeAlternateArray) {
        NSArray *a = t->_value;
        for (__CGImageMetadataTag *x in a) for (__CGImageMetadataTag *q in x->_qualifiers) if ([q->_name isEqual:@"lang"] && [q->_value isEqual:@"x-default"]) return string_of(x);
        return a.count ? string_of(a[0]) : nil;
    }
    return nil;
}
CFStringRef CGImageMetadataCopyStringValueWithPath(CGImageMetadataRef m, CGImageMetadataTagRef parent, CFStringRef path) {
    __CGImageMetadataTag *t = m && path ? resolve(m, parent, (__bridge NSString *)path) : nil;
    NSString *s = t ? string_of(t) : nil;
    return s ? (CFStringRef)CFBridgingRetain(s) : NULL;
}
bool CGImageMetadataRegisterNamespaceForPrefix(CGMutableImageMetadataRef m, CFStringRef ns, CFStringRef prefix, CFErrorRef *err) {
    NSString *p = (__bridge NSString *)prefix, *u = (__bridge NSString *)ns;
    NSString *have = m && p ? MD(m)->_prefixes[p] : nil;
    if (!m || !p.length || !u.length || (have && ![have isEqualToString:u])) {
        if (err) *err = (CFErrorRef)CFBridgingRetain([NSError errorWithDomain:S(kCFErrorDomainCGImageMetadata)
                                                                         code:have ? kCGImageMetadataErrorPrefixConflict : kCGImageMetadataErrorBadArgument userInfo:nil]);
        return false;
    }
    MD(m)->_prefixes[p] = u;
    return true;
}
/* places a tag at a path: the container of the last part, then the slot */
static BOOL place(CGImageMetadataRef m, CGImageMetadataTagRef parent, NSString *path, __CGImageMetadataTag *tag, BOOL remove) {
    NSArray *parts = path_parts(path);
    if (!m || !parts.count) return NO;
    id at = parent ? (__bridge id)parent : MD(m);
    for (NSUInteger i = 0; i + 1 < parts.count; i++) { at = child_of(at, parts[i]); if (!at) return NO; }
    NSString *last = parts.lastObject;
    if ([last hasPrefix:@"["]) {
        __CGImageMetadataTag *arr = at;
        if (![arr isKindOfClass:[__CGImageMetadataTag class]] || ![arr->_value isKindOfClass:[NSArray class]]) return NO;
        NSMutableArray *a = [arr->_value mutableCopy];
        NSInteger i = [[last substringWithRange:NSMakeRange(1, MAX(last.length, 2) - 2)] integerValue];
        if (remove) { if (i < 0 || i >= (NSInteger)a.count) return NO; [a removeObjectAtIndex:(NSUInteger)i]; }
        else if (i >= 0 && i < (NSInteger)a.count) a[(NSUInteger)i] = tag;
        else [a addObject:tag];
        arr->_value = a;
        return YES;
    }
    NSRange c = [last rangeOfString:@":"];
    if (c.location == NSNotFound) return NO;
    NSString *prefix = [last substringToIndex:c.location], *name = [last substringFromIndex:c.location + 1];
    if (tag) {                                                          /* the path names the tag */
        tag = [tag copyDeep];
        tag->_prefix = prefix; tag->_name = name;
        if (!tag->_ns) tag->_ns = MD(m)->_prefixes[prefix];
        if (!tag->_ns) return NO;
    }
    if ([at isKindOfClass:[__CGImageMetadata class]]) {
        NSMutableArray *tags = ((__CGImageMetadata *)at)->_tags;
        NSUInteger i = [tags indexOfObjectPassingTest:^BOOL(__CGImageMetadataTag *t, NSUInteger idx, BOOL *stop) { return [t.path isEqualToString:last]; }];
        if (remove) { if (i == NSNotFound) return NO; [tags removeObjectAtIndex:i]; return YES; }
        if (i == NSNotFound) [tags addObject:tag]; else tags[i] = tag;
        return YES;
    }
    __CGImageMetadataTag *st = at;
    if (![st->_value isKindOfClass:[NSDictionary class]]) { if (remove) return NO; st->_value = [NSMutableDictionary dictionary]; st->_type = kCGImageMetadataTypeStructure; }
    NSMutableDictionary *d = [st->_value mutableCopy];
    if (remove) { if (!d[last]) return NO; [d removeObjectForKey:last]; } else d[last] = tag;
    st->_value = d;
    return YES;
}
bool CGImageMetadataSetTagWithPath(CGMutableImageMetadataRef m, CGImageMetadataTagRef parent, CFStringRef path, CGImageMetadataTagRef tag) {
    return tag && path && place(m, parent, (__bridge NSString *)path, TG(tag), NO);
}
bool CGImageMetadataSetValueWithPath(CGMutableImageMetadataRef m, CGImageMetadataTagRef parent, CFStringRef path, CFTypeRef value) {
    NSString *p = (__bridge NSString *)path;
    NSString *last = path_parts(p ?: @"").lastObject;
    if (!m || !last || !value) return false;
    NSRange c = [last rangeOfString:@":"];
    NSString *prefix = c.location != NSNotFound && ![last hasPrefix:@"["] ? [last substringToIndex:c.location] : (parent ? TG(parent)->_prefix : nil);
    NSString *ns = prefix ? MD(m)->_prefixes[prefix] : nil;
    if (!ns) return false;
    __CGImageMetadataTag *t = make_tag(ns, prefix, nil, kCGImageMetadataTypeDefault, (__bridge id)value);
    return t && place(m, parent, p, t, NO);
}
bool CGImageMetadataRemoveTagWithPath(CGMutableImageMetadataRef m, CGImageMetadataTagRef parent, CFStringRef path) {
    return path && place(m, parent, (__bridge NSString *)path, nil, YES);
}
static BOOL enumerate(NSArray *children, NSString *base, BOOL recursive, CGImageMetadataTagBlock block) {
    for (id entry in children) {
        NSString *path; __CGImageMetadataTag *t;
        if ([entry isKindOfClass:[NSArray class]]) { path = entry[0]; t = entry[1]; } else { t = entry; path = base.length ? [base stringByAppendingFormat:@".%@", t.path] : t.path; }
        if (!block((__bridge CFStringRef)path, (__bridge CGImageMetadataTagRef)t)) return NO;
        if (!recursive) continue;
        NSMutableArray *kids = [NSMutableArray array];
        if ([t->_value isKindOfClass:[NSArray class]]) { NSUInteger i = 0; for (__CGImageMetadataTag *x in t->_value) [kids addObject:@[ [path stringByAppendingFormat:@"[%lu]", (unsigned long)i++], x ]]; }
        else if ([t->_value isKindOfClass:[NSDictionary class]])
            for (NSString *k in [[t->_value allKeys] sortedArrayUsingSelector:@selector(compare:)]) [kids addObject:@[ [path stringByAppendingFormat:@".%@", k], t->_value[k] ]];
        if (kids.count && !enumerate(kids, path, YES, block)) return NO;
    }
    return YES;
}
void CGImageMetadataEnumerateTagsUsingBlock(CGImageMetadataRef m, CFStringRef root, CFDictionaryRef options, CGImageMetadataTagBlock block) {
    if (!m || !block) return;
    BOOL recursive = [((__bridge NSDictionary *)options)[S(kCGImageMetadataEnumerateRecursively)] boolValue];
    if (!root) { enumerate(MD(m)->_tags, @"", recursive, block); return; }
    __CGImageMetadataTag *t = resolve(m, NULL, (__bridge NSString *)root);
    if (!t) return;
    NSMutableArray *kids = [NSMutableArray array];
    NSString *base = (__bridge NSString *)root;
    if ([t->_value isKindOfClass:[NSArray class]]) { NSUInteger i = 0; for (__CGImageMetadataTag *x in t->_value) [kids addObject:@[ [base stringByAppendingFormat:@"[%lu]", (unsigned long)i++], x ]]; }
    else if ([t->_value isKindOfClass:[NSDictionary class]])
        for (NSString *k in [[t->_value allKeys] sortedArrayUsingSelector:@selector(compare:)]) [kids addObject:@[ [base stringByAppendingFormat:@".%@", k], t->_value[k] ]];
    enumerate(kids, base, recursive, block);
}

/* ---------------- writing XMP ---------------- */
static NSString *esc(NSString *s) {
    return [[[[s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]
             stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"] stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
}
static void collect_ns(__CGImageMetadataTag *t, NSMutableDictionary *ns) {
    if (t->_prefix && t->_ns && ![t->_prefix isEqual:@"xml"]) ns[t->_prefix] = t->_ns;
    if ([t->_value isKindOfClass:[NSArray class]]) for (__CGImageMetadataTag *x in t->_value) collect_ns(x, ns);
    if ([t->_value isKindOfClass:[NSDictionary class]]) for (__CGImageMetadataTag *x in [t->_value allValues]) collect_ns(x, ns);
}
static NSString *lang_of(__CGImageMetadataTag *t) {
    for (__CGImageMetadataTag *q in t->_qualifiers) if ([q->_name isEqual:@"lang"]) return q->_value;
    return nil;
}
static void write_value(NSMutableString *x, __CGImageMetadataTag *t, NSString *open, NSString *close, NSString *indent);
static void write_fields(NSMutableString *x, NSDictionary *fields, NSString *indent) {
    for (NSString *k in [[fields allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        __CGImageMetadataTag *f = fields[k];
        write_value(x, f, [NSString stringWithFormat:@"<%@", k], [NSString stringWithFormat:@"</%@>", k], indent);
    }
}
/* an element (open: "<p:name" without its ">", or "<rdf:li"), its value and its close */
static void write_value(NSMutableString *x, __CGImageMetadataTag *t, NSString *open, NSString *close, NSString *indent) {
    NSString *lang = lang_of(t);
    NSString *attrs = lang ? [NSString stringWithFormat:@" xml:lang=\"%@\"", esc(lang)] : @"";
    if ([t->_value isKindOfClass:[NSString class]]) { [x appendFormat:@"%@%@%@>%@%@\n", indent, open, attrs, esc(t->_value), close]; return; }
    if ([t->_value isKindOfClass:[NSDictionary class]]) {
        [x appendFormat:@"%@%@%@ rdf:parseType=\"Resource\">\n", indent, open, attrs];
        write_fields(x, t->_value, [indent stringByAppendingString:@" "]);
        [x appendFormat:@"%@%@\n", indent, close];
        return;
    }
    NSString *kind = t->_type == kCGImageMetadataTypeArrayUnordered ? @"rdf:Bag"
                   : t->_type == kCGImageMetadataTypeAlternateArray || t->_type == kCGImageMetadataTypeAlternateText ? @"rdf:Alt" : @"rdf:Seq";
    [x appendFormat:@"%@%@%@>\n%@ <%@>\n", indent, open, attrs, indent, kind];
    for (__CGImageMetadataTag *__strong item in t->_value) {
        if (t->_type == kCGImageMetadataTypeAlternateText && !lang_of(item)) {
            __CGImageMetadataTag *c = [item copyDeep];
            c->_qualifiers = @[ make_tag(XMLNS, @"xml", @"lang", kCGImageMetadataTypeString, @"x-default") ];
            item = c;
        }
        write_value(x, item, @"<rdf:li", @"</rdf:li>", [indent stringByAppendingString:@"  "]);
    }
    [x appendFormat:@"%@ </%@>\n%@%@\n", indent, kind, indent, close];
}
NSString *isim_io_xmp_of_metadata(CGImageMetadataRef m) {
    if (!m || !MD(m)->_tags.count) return nil;
    NSMutableDictionary *ns = [NSMutableDictionary dictionary];
    for (__CGImageMetadataTag *t in MD(m)->_tags) collect_ns(t, ns);
    NSMutableString *x = [NSMutableString stringWithString:@"<?xpacket begin=\"\xEF\xBB\xBF\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>\n<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n"
                                                           " <rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n  <rdf:Description rdf:about=\"\""];
    for (NSString *p in [[ns allKeys] sortedArrayUsingSelector:@selector(compare:)]) [x appendFormat:@"\n    xmlns:%@=\"%@\"", p, esc(ns[p])];
    [x appendString:@">\n"];
    for (__CGImageMetadataTag *t in MD(m)->_tags)
        write_value(x, t, [NSString stringWithFormat:@"<%@", t.path], [NSString stringWithFormat:@"</%@>", t.path], @"   ");
    [x appendString:@"  </rdf:Description>\n </rdf:RDF>\n</x:xmpmeta>\n<?xpacket end=\"w\"?>"];
    return x;
}
CFDataRef CGImageMetadataCreateXMPData(CGImageMetadataRef m, CFDictionaryRef options) {
    NSString *x = isim_io_xmp_of_metadata(m);
    return x ? (CFDataRef)CFBridgingRetain([x dataUsingEncoding:NSUTF8StringEncoding]) : NULL;
}

/* ---------------- reading XMP ---------------- */
@interface __XMPReader : NSObject <NSXMLParserDelegate> {
@public __CGImageMetadata *_md; NSMutableArray<NSMutableDictionary *> *_stack; NSMutableDictionary *_uris; BOOL _bad;
}
@end
@implementation __XMPReader
- (void)parser:(NSXMLParser *)p didStartMappingPrefix:(NSString *)prefix toURI:(NSString *)uri { if (prefix.length) _uris[prefix] = uri; }
static NSString *prefix_of(NSString *qname) { NSRange c = [qname rangeOfString:@":"]; return c.location == NSNotFound ? @"" : [qname substringToIndex:c.location]; }
/* the attributes of a description or property element that are fields (not rdf:, xml: or xmlns) */
- (NSArray *)fieldsOfAttributes:(NSDictionary *)attrs {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *q in attrs) {
        NSString *p = prefix_of(q);
        if (!p.length || [p isEqual:@"rdf"] || [p isEqual:@"xml"] || [p isEqual:@"xmlns"] || [q hasPrefix:@"xmlns"]) continue;
        NSString *ns = _uris[p] ?: _md->_prefixes[p];
        if (!ns) continue;
        __CGImageMetadataTag *t = make_tag(ns, p, [q substringFromIndex:p.length + 1], kCGImageMetadataTypeString, attrs[q]);
        if (t) [out addObject:t];
    }
    return out;
}
- (void)parser:(NSXMLParser *)p didStartElement:(NSString *)local namespaceURI:(NSString *)uri qualifiedName:(NSString *)qname attributes:(NSDictionary *)attrs {
    NSMutableDictionary *top = _stack.lastObject;
    if ([uri isEqualToString:RDF]) {
        if ([local isEqualToString:@"RDF"]) return;
        if ([local isEqualToString:@"Description"]) {
            NSMutableDictionary *f = [@{ @"kind": @"desc", @"fields": [[self fieldsOfAttributes:attrs] mutableCopy] } mutableCopy];
            [_stack addObject:f];
            return;
        }
        if ([local isEqualToString:@"Bag"] || [local isEqualToString:@"Seq"] || [local isEqualToString:@"Alt"]) { if (top) top[@"array"] = local; return; }
        if ([local isEqualToString:@"li"]) {
            NSMutableDictionary *li = [@{ @"kind": @"li", @"text": [NSMutableString string], @"fields": [[self fieldsOfAttributes:attrs] mutableCopy] } mutableCopy];
            if (attrs[@"xml:lang"]) li[@"lang"] = attrs[@"xml:lang"];
            if ([attrs[@"rdf:parseType"] isEqual:@"Resource"]) li[@"struct"] = @YES;
            [_stack addObject:li];
            return;
        }
    }
    if (!top) return;                                                   /* x:xmpmeta and other wrappers */
    NSMutableDictionary *prop = [@{ @"kind": @"prop", @"ns": uri ?: @"", @"prefix": prefix_of(qname ?: local), @"name": local, @"text": [NSMutableString string],
                                    @"fields": [[self fieldsOfAttributes:attrs] mutableCopy] } mutableCopy];
    if ([attrs[@"rdf:parseType"] isEqual:@"Resource"] || [prop[@"fields"] count]) prop[@"struct"] = @YES;
    [_stack addObject:prop];
}
- (void)parser:(NSXMLParser *)p foundCharacters:(NSString *)s {
    NSMutableDictionary *top = _stack.lastObject;
    if (top[@"text"]) [top[@"text"] appendString:s];
}
- (void)add:(__CGImageMetadataTag *)t to:(NSMutableDictionary *)parent {
    if (!t) return;
    if (!parent) { [_md->_tags addObject:t]; return; }
    if ([parent[@"kind"] isEqual:@"desc"] || [parent[@"kind"] isEqual:@"li"] || [parent[@"kind"] isEqual:@"prop"]) {
        if ([parent[@"kind"] isEqual:@"prop"] && parent[@"array"]) { [parent[@"items"] ?: (parent[@"items"] = [NSMutableArray array]) addObject:t]; return; }
        [parent[@"fields"] addObject:t];
        if (![parent[@"kind"] isEqual:@"desc"]) parent[@"struct"] = @YES;
    }
}
static NSDictionary *fields_dict(NSArray *fields) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (__CGImageMetadataTag *f in fields) d[f.path] = f;
    return d;
}
- (void)parser:(NSXMLParser *)p didEndElement:(NSString *)local namespaceURI:(NSString *)uri qualifiedName:(NSString *)qname {
    if ([uri isEqualToString:RDF] && ([local isEqualToString:@"RDF"] || [local isEqualToString:@"Bag"] || [local isEqualToString:@"Seq"] || [local isEqualToString:@"Alt"])) return;
    NSMutableDictionary *top = _stack.lastObject;
    if (!top) return;
    [_stack removeLastObject];
    NSMutableDictionary *parent = _stack.lastObject;
    NSString *kind = top[@"kind"];
    if ([kind isEqual:@"desc"]) {
        if (!parent) for (__CGImageMetadataTag *t in top[@"fields"]) [_md->_tags addObject:t];
        else { [parent[@"fields"] addObjectsFromArray:top[@"fields"]]; parent[@"struct"] = @YES; }
        return;
    }
    __CGImageMetadataTag *t;
    NSString *ns = top[@"ns"], *prefix = top[@"prefix"], *name = top[@"name"];
    if ([kind isEqual:@"li"]) {
        NSMutableDictionary *owner = parent;                           /* the property holding the array */
        ns = owner[@"ns"]; prefix = owner[@"prefix"]; name = nil;
        if ([top[@"struct"] boolValue] || [top[@"fields"] count]) t = make_tag(ns, prefix, nil, kCGImageMetadataTypeStructure, fields_dict(top[@"fields"]));
        else t = make_tag(ns, prefix, nil, kCGImageMetadataTypeString, [top[@"text"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]);
        if (top[@"lang"]) t->_qualifiers = @[ make_tag(XMLNS, @"xml", @"lang", kCGImageMetadataTypeString, top[@"lang"]) ];
        [owner[@"items"] ?: (owner[@"items"] = [NSMutableArray array]) addObject:t];
        return;
    }
    if (top[@"array"]) {
        NSArray *items = top[@"items"] ?: @[];
        BOOL langs = items.count > 0;
        for (__CGImageMetadataTag *x in items) if (!lang_of(x)) langs = NO;
        CGImageMetadataType type = [top[@"array"] isEqual:@"Bag"] ? kCGImageMetadataTypeArrayUnordered
                                 : [top[@"array"] isEqual:@"Seq"] ? kCGImageMetadataTypeArrayOrdered
                                 : langs ? kCGImageMetadataTypeAlternateText : kCGImageMetadataTypeAlternateArray;
        t = make_tag(ns, prefix, name, type, items);
        if (!t) { t = [__CGImageMetadataTag new]; t->_ns = ns; t->_prefix = prefix; t->_name = name; t->_type = type; t->_value = @[]; }
    } else if ([top[@"struct"] boolValue]) t = make_tag(ns, prefix, name, kCGImageMetadataTypeStructure, fields_dict(top[@"fields"]));
    else t = make_tag(ns, prefix, name, kCGImageMetadataTypeString, [top[@"text"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]);
    if (t && top[@"lang"]) t->_qualifiers = @[ make_tag(XMLNS, @"xml", @"lang", kCGImageMetadataTypeString, top[@"lang"]) ];
    if (t) { t->_ns = ns; t->_prefix = prefix; t->_name = name; if (ns.length && prefix.length) _md->_prefixes[prefix] = ns; }
    [self add:t to:parent];
}
- (void)parser:(NSXMLParser *)p parseErrorOccurred:(NSError *)e { _bad = YES; }
@end
static __CGImageMetadata *parse_xmp(NSData *data, __CGImageMetadata *into) {
    if (!data.length) return nil;
    NSXMLParser *p = [[NSXMLParser alloc] initWithData:data];
    __XMPReader *r = [__XMPReader new];
    r->_md = into ?: [__CGImageMetadata new]; r->_stack = [NSMutableArray array]; r->_uris = [NSMutableDictionary dictionary];
    p.delegate = r;
    p.shouldProcessNamespaces = YES;
    p.shouldReportNamespacePrefixes = YES;
    BOOL ok = [p parse];
    return ok && !r->_bad ? r->_md : nil;
}
CGImageMetadataRef CGImageMetadataCreateFromXMPData(CFDataRef data) {
    __CGImageMetadata *m = parse_xmp((__bridge NSData *)data, nil);
    return m ? (CGImageMetadataRef)CFBridgingRetain(m) : NULL;
}

/* ---------------- properties <-> XMP ---------------- */
static NSString *rat_string(double v) {
    double a = fabs(v);
    if (a == floor(a)) return [NSString stringWithFormat:@"%.0f", v];
    if (a < 1 && fabs(1 / a - round(1 / a)) < 1e-6) return [NSString stringWithFormat:@"%s1/%.0f", v < 0 ? "-" : "", round(1 / a)];
    long d = 1;
    while (d < 10000 && fabs(a * d - round(a * d)) > 1e-6) d *= 10;
    return [NSString stringWithFormat:@"%.0f/%ld", round(v * d), d];
}
static double parse_number(NSString *s) {
    NSArray *f = [s componentsSeparatedByString:@"/"];
    if (f.count == 2 && [f[1] doubleValue] != 0) return [f[0] doubleValue] / [f[1] doubleValue];
    return s.doubleValue;
}
/* "2024:05:06 07:08:09" (+ "+01:00") <-> "2024-05-06T07:08:09+01:00" */
static NSString *xmp_date(NSString *exif, NSString *offset) {
    if (exif.length < 19) return exif;
    NSString *d = [[exif substringToIndex:10] stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    return [NSString stringWithFormat:@"%@T%@%@", d, [exif substringWithRange:NSMakeRange(11, 8)], offset ?: @""];
}
static NSString *exif_date(NSString *xmp) {
    if (xmp.length < 19 || [xmp characterAtIndex:10] != 'T') return xmp;
    return [NSString stringWithFormat:@"%@ %@", [[xmp substringToIndex:10] stringByReplacingOccurrencesOfString:@"-" withString:@":"], [xmp substringWithRange:NSMakeRange(11, 8)]];
}
static BOOL is_date_key(NSString *key) {
    return [key isEqual:S(kCGImagePropertyTIFFDateTime)] || [key isEqual:S(kCGImagePropertyExifDateTimeOriginal)] || [key isEqual:S(kCGImagePropertyExifDateTimeDigitized)];
}
/* "DDD,MM.mmmmK" from degrees and a reference letter */
static NSString *xmp_coordinate(double deg, NSString *ref, BOOL lat) {
    double a = fabs(deg), d = floor(a), mins = (a - d) * 60;
    NSString *r = ref.length ? ref : (deg < 0 ? (lat ? @"S" : @"W") : (lat ? @"N" : @"E"));
    NSString *m = [[NSString stringWithFormat:@"%.6f", mins] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0"]];
    if ([m hasPrefix:@"."]) m = [@"0" stringByAppendingString:m];
    if ([m hasSuffix:@"."]) m = [m substringToIndex:m.length - 1];
    if (!m.length) m = @"0";
    return [NSString stringWithFormat:@"%.0f,%@%@", d, m, r];
}
static BOOL parse_coordinate(NSString *s, double *deg, NSString **ref) {
    if (s.length < 3) return NO;
    unichar last = [s characterAtIndex:s.length - 1];
    if (!strchr("NSEW", (char)last)) return NO;
    NSArray *c = [[s substringToIndex:s.length - 1] componentsSeparatedByString:@","];
    double v = [c[0] doubleValue] + (c.count > 1 ? [c[1] doubleValue] / 60 : 0) + (c.count > 2 ? [c[2] doubleValue] / 3600 : 0);
    *deg = v; *ref = [NSString stringWithFormat:@"%C", last];
    return YES;
}
static __CGImageMetadataTag *lang_alt(NSString *ns, NSString *prefix, NSString *name, NSString *text) {
    __CGImageMetadataTag *item = make_tag(ns, prefix, nil, kCGImageMetadataTypeString, text);
    item->_qualifiers = @[ make_tag(XMLNS, @"xml", @"lang", kCGImageMetadataTypeString, @"x-default") ];
    return make_tag(ns, prefix, name, kCGImageMetadataTypeAlternateText, @[ item ]);
}
/* the XMP tag of a property value (dict: its dictionary, for references and offsets) */
static __CGImageMetadataTag *xmp_tag(NSString *xmp, int kind, BOOL iptc, NSString *key, id v, NSDictionary *dict, NSDictionary *prefixes) {
    NSRange c = [xmp rangeOfString:@":"];
    NSString *prefix = [xmp substringToIndex:c.location], *name = [xmp substringFromIndex:c.location + 1], *ns = prefixes[prefix];
    if (!ns || !v) return nil;
    if (iptc) {
        NSArray *a = [v isKindOfClass:[NSArray class]] ? v : @[ v ];
        if (kind == 'a') return lang_alt(ns, prefix, name, [a componentsJoinedByString:@", "]);
        if (kind == 'b' || kind == 'q') return make_tag(ns, prefix, name, kind == 'b' ? kCGImageMetadataTypeArrayUnordered : kCGImageMetadataTypeArrayOrdered, a);
        return make_tag(ns, prefix, name, kCGImageMetadataTypeString, [a componentsJoinedByString:@", "]);
    }
    switch (kind) {
    case T_ASCII:
        if (is_date_key(key)) {
            NSString *off = [key isEqual:S(kCGImagePropertyExifDateTimeOriginal)] ? dict[S(kCGImagePropertyExifOffsetTimeOriginal)]
                          : [key isEqual:S(kCGImagePropertyExifDateTimeDigitized)] ? dict[S(kCGImagePropertyExifOffsetTimeDigitized)] : nil;
            return make_tag(ns, prefix, name, kCGImageMetadataTypeString, xmp_date([v description], off));
        }
        return make_tag(ns, prefix, name, kCGImageMetadataTypeString, [v description]);
    case T_COMMENT: return lang_alt(ns, prefix, name, [v description]);
    case T_RAT: case T_SRAT: return make_tag(ns, prefix, name, kCGImageMetadataTypeString, rat_string([v doubleValue]));
    case T_SHORTS: case T_RATS: {
        NSMutableArray *a = [NSMutableArray array];
        for (NSNumber *x in ([v isKindOfClass:[NSArray class]] ? v : @[ v ])) [a addObject:kind == T_RATS ? rat_string(x.doubleValue) : x.stringValue];
        return make_tag(ns, prefix, name, kCGImageMetadataTypeArrayOrdered, a);
    }
    case T_VERSION: {
        NSMutableString *s = [NSMutableString string];
        for (NSNumber *x in ([v isKindOfClass:[NSArray class]] ? v : @[ v ])) [s appendFormat:@"%d", x.intValue];
        while (s.length < 4) [s insertString:@"0" atIndex:0];
        return make_tag(ns, prefix, name, kCGImageMetadataTypeString, s);
    }
    case T_BYTES: return make_tag(ns, prefix, name, kCGImageMetadataTypeString, [[v isKindOfClass:[NSArray class]] ? v : @[ v ] componentsJoinedByString:@"."]);
    case T_DEG: {
        BOOL lat = [key hasSuffix:@"Latitude"];
        NSString *ref = dict[[key stringByAppendingString:@"Ref"]];
        return make_tag(ns, prefix, name, kCGImageMetadataTypeString, xmp_coordinate([v doubleValue], ref, lat));
    }
    case T_HMS: {
        NSString *date = [dict[S(kCGImagePropertyGPSDateStamp)] stringByReplacingOccurrencesOfString:@":" withString:@"-"] ?: @"1970-01-01";
        NSString *t = [v description];
        if (t.length > 8) t = [t substringToIndex:8];
        return make_tag(ns, prefix, name, kCGImageMetadataTypeString, [NSString stringWithFormat:@"%@T%@Z", date, t]);
    }
    default: return make_tag(ns, prefix, name, kCGImageMetadataTypeString, [v isKindOfClass:[NSNumber class]] ? [v stringValue] : [v description]);
    }
}
/* the property value of an XMP tag, into its dictionary (with references and dates where they apply) */
static void property_of(__CGImageMetadataTag *t, NSString *key, int kind, BOOL iptc, NSMutableDictionary *dict) {
    NSString *s = string_of(t);
    NSArray *items = [t->_value isKindOfClass:[NSArray class]] ? t->_value : nil;
    if (iptc) {
        if ((kind == 'b' || kind == 'q') && items) { NSMutableArray *a = [NSMutableArray array]; for (__CGImageMetadataTag *x in items) if (string_of(x)) [a addObject:string_of(x)]; dict[key] = a; }
        else if (s) dict[key] = s;
        return;
    }
    switch (kind) {
    case T_ASCII: if (s) dict[key] = is_date_key(key) ? exif_date(s) : s; break;
    case T_COMMENT: if (s) dict[key] = s; break;
    case T_SHORTS: case T_RATS: {
        NSMutableArray *a = [NSMutableArray array];
        for (__CGImageMetadataTag *x in items ?: @[]) if (string_of(x)) [a addObject:@(parse_number(string_of(x)))];
        if (!items && s) [a addObject:@(parse_number(s))];
        dict[key] = a;
        break;
    }
    case T_VERSION: {
        NSMutableArray *a = [NSMutableArray array];
        for (NSUInteger i = 0; i < s.length; i++) { int c = [s characterAtIndex:i] - '0'; if (i == 0 && c == 0 && s.length > 2) continue; [a addObject:@(c)]; }
        if (s) dict[key] = a;
        break;
    }
    case T_BYTES: {
        NSMutableArray *a = [NSMutableArray array];
        for (NSString *x in [s componentsSeparatedByString:@"."]) [a addObject:@(x.intValue)];
        if (s) dict[key] = a;
        break;
    }
    case T_DEG: {
        double deg; NSString *ref;
        if (s && parse_coordinate(s, &deg, &ref)) { dict[key] = @(deg); dict[[key stringByAppendingString:@"Ref"]] = ref; }
        break;
    }
    case T_HMS:
        if (s.length >= 19) {
            dict[key] = [s substringWithRange:NSMakeRange(11, 8)];
            dict[S(kCGImagePropertyGPSDateStamp)] = [[s substringToIndex:10] stringByReplacingOccurrencesOfString:@"-" withString:@":"];
        }
        break;
    default: if (s) dict[key] = @(parse_number(s)); break;
    }
}
CGMutableImageMetadataRef isim_io_metadata_create(NSDictionary *props, NSString *xmp) {
    __CGImageMetadata *m = [__CGImageMetadata new];
    if (xmp.length) parse_xmp([xmp dataUsingEncoding:NSUTF8StringEncoding], m);
    NSMutableSet *have = [NSMutableSet set];
    for (__CGImageMetadataTag *t in m->_tags) [have addObject:t.path];
    isim_io_each_mapping(^(NSString *dictName, NSString *key, NSString *x, int kind, BOOL iptc) {
        NSDictionary *dict = props[dictName];
        id v = dict[key];
        if (!v || [have containsObject:x]) return;                     /* the packet's own tags win */
        __CGImageMetadataTag *t = xmp_tag(x, kind, iptc, key, v, dict, m->_prefixes);
        if (t) { [m->_tags addObject:t]; [have addObject:x]; }
    });
    return (CGMutableImageMetadataRef)CFBridgingRetain(m);
}
NSDictionary *isim_io_props_of_metadata(CGImageMetadataRef md) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    if (!md) return out;
    isim_io_each_mapping(^(NSString *dictName, NSString *key, NSString *x, int kind, BOOL iptc) {
        __CGImageMetadataTag *t = resolve(md, NULL, x);
        if (!t) return;
        NSMutableDictionary *d = out[dictName] ?: (out[dictName] = [NSMutableDictionary dictionary]);
        if (!d[key]) property_of(t, key, kind, iptc, d);
    });
    return out;
}
static BOOL mapping(NSString *dictName, NSString *prop, NSString **xmp, int *kind, BOOL *iptc) {
    __block BOOL found = NO;
    __block NSString *fx = nil;
    __block int fk = 0;
    __block BOOL fi = NO;
    NSString *want = prop;
    if ([prop hasSuffix:@"Ref"] && ([prop hasPrefix:@"Latitude"] || [prop hasPrefix:@"Longitude"] || [prop hasPrefix:@"DestLatitude"] || [prop hasPrefix:@"DestLongitude"]))
        want = [prop substringToIndex:prop.length - 3];                /* the reference lives in the coordinate */
    isim_io_each_mapping(^(NSString *d, NSString *key, NSString *x, int k, BOOL i) {
        if (!found && [d isEqualToString:dictName] && [key isEqualToString:want]) { fx = x; fk = k; fi = i; found = YES; }
    });
    *xmp = fx; *kind = fk; *iptc = fi;
    return found;
}
CGImageMetadataTagRef CGImageMetadataCopyTagMatchingImageProperty(CGImageMetadataRef m, CFStringRef dictName, CFStringRef prop) {
    NSString *x; int kind; BOOL iptc;
    if (!m || !mapping((__bridge NSString *)dictName, (__bridge NSString *)prop, &x, &kind, &iptc)) return NULL;
    __CGImageMetadataTag *t = resolve(m, NULL, x);
    return t ? (CGImageMetadataTagRef)CFBridgingRetain(t) : NULL;
}
bool CGImageMetadataSetValueMatchingImageProperty(CGMutableImageMetadataRef m, CFStringRef dictName, CFStringRef prop, CFTypeRef value) {
    NSString *x; int kind; BOOL iptc;
    if (!m || !value || !mapping((__bridge NSString *)dictName, (__bridge NSString *)prop, &x, &kind, &iptc)) return false;
    NSString *key = (__bridge NSString *)prop;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if ([key hasSuffix:@"Ref"] && kind == T_DEG) {                      /* a reference: the coordinate with its new letter */
        __CGImageMetadataTag *old = resolve(m, NULL, x);
        double deg = 0; NSString *ref;
        if (old && string_of(old)) parse_coordinate(string_of(old), &deg, &ref);
        dict[key] = (__bridge id)value;
        key = [key substringToIndex:key.length - 3];
        dict[key] = @(deg);
    } else dict[key] = (__bridge id)value;
    __CGImageMetadataTag *t = xmp_tag(x, kind, iptc, key, dict[key], dict, MD(m)->_prefixes);
    return t && place(m, NULL, x, t, NO);
}
