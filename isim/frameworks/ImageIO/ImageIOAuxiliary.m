// isim ImageIO: auxiliary data (depth, disparity, mattes, gain maps) in JPEG images. As the iPhone camera does, each
// is a Multi-Picture Format image (CIPA DC-007) after the primary one: an 8-bit JPEG whose XMP (the
// http://ns.apple.com/pixeldatainfo/1.0/ namespace) names its type, its native pixel format and the range of its values.
#import "ImageIOPrivate.h"
#include <isim_host.h>
#include <isim_host_cg.h>
#include <math.h>

#define S(k) ((__bridge NSString *)(k))
static NSString *const kNamespace = @"http://ns.apple.com/pixeldatainfo/1.0/";

/* the URN the XMP records for each type */
static NSDictionary<NSString *, NSString *> *urns(void) {
    static NSDictionary *d;
    if (!d) d = @{ S(kCGImageAuxiliaryDataTypeDepth): @"urn:com:apple:photo:2017:aux:depth",
                   S(kCGImageAuxiliaryDataTypeDisparity): @"urn:com:apple:photo:2017:aux:disparity",
                   S(kCGImageAuxiliaryDataTypePortraitEffectsMatte): @"urn:com:apple:photo:2018:aux:portraiteffectsmatte",
                   S(kCGImageAuxiliaryDataTypeSemanticSegmentationSkinMatte): @"urn:com:apple:photo:2019:aux:semanticskinmatte",
                   S(kCGImageAuxiliaryDataTypeSemanticSegmentationHairMatte): @"urn:com:apple:photo:2019:aux:semantichairmatte",
                   S(kCGImageAuxiliaryDataTypeSemanticSegmentationTeethMatte): @"urn:com:apple:photo:2019:aux:semanticteethmatte",
                   S(kCGImageAuxiliaryDataTypeSemanticSegmentationGlassesMatte): @"urn:com:apple:photo:2020:aux:semanticglassesmatte",
                   S(kCGImageAuxiliaryDataTypeSemanticSegmentationSkyMatte): @"urn:com:apple:photo:2023:aux:semanticskymatte",
                   S(kCGImageAuxiliaryDataTypeHDRGainMap): @"urn:com:apple:photo:2020:aux:hdrgainmap",
                   S(kCGImageAuxiliaryDataTypeISOGainMap): @"urn:iso:std:iso:ts:21496:-1" };
    return d;
}

/* ---------------- pixel formats ---------------- */
enum { F_U8, F_U16, F_HALF, F_FLOAT, F_RGBA8 };
static int kind_of(uint32_t f, int *bpp) {
    switch (f) {
    case 'L008': *bpp = 1; return F_U8;
    case 'L016': *bpp = 2; return F_U16;
    case 'L00h': case 'hdis': case 'hdep': *bpp = 2; return F_HALF;
    case 'L00f': case 'fdis': case 'fdep': *bpp = 4; return F_FLOAT;
    case 'BGRA': case 'RGBA': *bpp = 4; return F_RGBA8;
    default: return -1;
    }
}
static float half_to_float(uint16_t h) {
    int e = h >> 10 & 31, m = h & 1023; float v;
    if (!e) v = ldexpf((float)m, -24);
    else if (e == 31) v = m ? NAN : INFINITY;
    else v = ldexpf((float)(m | 1024), e - 25);
    return h & 0x8000 ? -v : v;
}
static uint16_t float_to_half(float f) {
    uint16_t sign = signbit(f) ? 0x8000 : 0; f = fabsf(f);
    if (isnan(f)) return sign | 0x7e00;
    if (f >= 65520.f) return sign | 0x7c00;
    if (f < ldexpf(1, -14)) return sign | (uint16_t)lrintf(f * ldexpf(1, 24));   /* subnormal */
    int e; float m = frexpf(f, &e);                                              /* f = m * 2^e, m in [0.5, 1) */
    long bits = lrintf((m * 2 - 1) * 1024);
    if (bits == 1024) { bits = 0; e++; }
    return sign | (uint16_t)((e + 14) << 10 | bits);
}
static float sample(const uint8_t *p, int kind) {
    switch (kind) {
    case F_U8: return p[0] / 255.f;
    case F_U16: { uint16_t v; memcpy(&v, p, 2); return v / 65535.f; }
    case F_HALF: { uint16_t v; memcpy(&v, p, 2); return half_to_float(v); }
    default: { float v; memcpy(&v, p, 4); return v; }
    }
}
static void store(uint8_t *p, int kind, float v) {
    switch (kind) {
    case F_U8: p[0] = (uint8_t)lrintf(fminf(fmaxf(v, 0), 1) * 255); break;
    case F_U16: { uint16_t u = (uint16_t)lrintf(fminf(fmaxf(v, 0), 1) * 65535); memcpy(p, &u, 2); break; }
    case F_HALF: { uint16_t u = float_to_half(v); memcpy(p, &u, 2); break; }
    default: memcpy(p, &v, 4); break;
    }
}

/* ---------------- Multi-Picture Format ---------------- */
static uint32_t rd(const uint8_t *p, int n, BOOL le) {
    uint32_t v = 0;
    for (int i = 0; i < n; i++) v |= (uint32_t)p[i] << (le ? 8 * i : 8 * (n - 1 - i));
    return v;
}
/* the images after the primary one, from the MP Entry of its APP2 "MPF" segment */
static NSArray<NSData *> *mpf_images(NSData *jpeg) {
    const uint8_t *d = jpeg.bytes; size_t len = jpeg.length;
    NSMutableArray *out = [NSMutableArray array];
    if (len < 4 || d[0] != 0xFF || d[1] != 0xD8) return out;
    for (size_t o = 2; o + 4 <= len && d[o] == 0xFF;) {
        uint8_t m = d[o + 1];
        if (m == 0xDA || m == 0xD9) break;
        size_t seg = (size_t)d[o + 2] << 8 | d[o + 3];
        if (m == 0xE2 && seg >= 14 && o + 2 + seg <= len && !memcmp(d + o + 4, "MPF\0", 4)) {
            const uint8_t *t = d + o + 8; size_t tl = seg - 6, base = o + 8;
            BOOL le = t[0] == 'I';
            uint32_t ifd = rd(t + 4, 4, le);
            if (ifd + 2 > tl) break;
            unsigned n = rd(t + ifd, 2, le);
            for (unsigned i = 0; i < n && ifd + 2 + 12 * (i + 1) <= tl; i++) {
                const uint8_t *e = t + ifd + 2 + 12 * i;
                if (rd(e, 2, le) != 0xB002) continue;
                uint32_t count = rd(e + 4, 4, le), at = rd(e + 8, 4, le);
                for (uint32_t k = 1; k < count / 16 && at + 16 * (k + 1) <= tl; k++) {   /* entry 0 is this image */
                    const uint8_t *en = t + at + 16 * k;
                    uint32_t size = rd(en + 4, 4, le), off = rd(en + 8, 4, le);
                    if (base + off + size <= len && size > 4 && d[base + off] == 0xFF && d[base + off + 1] == 0xD8)
                        [out addObject:[jpeg subdataWithRange:NSMakeRange(base + off, size)]];
                }
            }
            break;
        }
        o += 2 + seg;
    }
    return out;
}
static void put(NSMutableData *d, uint32_t v, int n) { for (int i = n - 1; i >= 0; i--) { uint8_t b = (uint8_t)(v >> 8 * i); [d appendBytes:&b length:1]; } }
/* the primary JPEG with an APP2 "MPF" segment listing `images`, which follow it */
static NSData *with_mpf(NSData *primary, NSArray<NSData *> *images) {
    const uint8_t *d = primary.bytes; size_t len = primary.length, at = 2;
    while (at + 4 <= len && d[at] == 0xFF && d[at + 1] >= 0xE0 && d[at + 1] <= 0xEF) at += 2 + ((size_t)d[at + 2] << 8 | d[at + 3]);   /* after APP0...APP15 */
    uint32_t n = (uint32_t)images.count + 1, seglen = 2 + 4 + 50 + 16 * n;
    NSMutableData *seg = [NSMutableData data];
    put(seg, 0xFFE2, 2); put(seg, seglen, 2); [seg appendBytes:"MPF\0MM\0*" length:8]; put(seg, 8, 4);
    put(seg, 3, 2);                                                     /* MP Index IFD */
    put(seg, 0xB000, 2); put(seg, 7, 2); put(seg, 4, 4); [seg appendBytes:"0100" length:4];
    put(seg, 0xB001, 2); put(seg, 4, 2); put(seg, 1, 4); put(seg, n, 4);
    put(seg, 0xB002, 2); put(seg, 7, 2); put(seg, 16 * n, 4); put(seg, 50, 4);
    put(seg, 0, 4);
    size_t tiff = at + 8;   /* offsets count from the MP header */
    put(seg, 0x20030000, 4); put(seg, (uint32_t)(len + 2 + seglen), 4); put(seg, 0, 4); put(seg, 0, 4);   /* the primary image */
    size_t pos = len + 2 + seglen;
    for (NSData *im in images) {
        put(seg, 0, 4); put(seg, (uint32_t)im.length, 4); put(seg, (uint32_t)(pos - tiff), 4); put(seg, 0, 4);
        pos += im.length;
    }
    NSMutableData *out = [NSMutableData dataWithBytes:d length:at];
    [out appendData:seg];
    [out appendBytes:d + at length:len - at];
    for (NSData *im in images) [out appendData:im];
    return out;
}

/* ---------------- reading ---------------- */
typedef struct { NSString *type; uint32_t format; double min, max; BOOL ranged; } aux_desc;
static BOOL describe(NSData *image, aux_desc *out, CGImageMetadataRef _Nullable *_Nullable metadata) {
    NSString *xmp = nil;
    isim_io_read_metadata(image, @"public.jpeg", &xmp);
    if (!xmp) return NO;
    CGMutableImageMetadataRef m = isim_io_metadata_create(@{}, xmp);
    if (!m) return NO;
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    CGImageMetadataEnumerateTagsUsingBlock(m, NULL, NULL, ^bool(CFStringRef path, CGImageMetadataTagRef tag) {
        if (![CFBridgingRelease(CGImageMetadataTagCopyNamespace(tag)) isEqual:kNamespace]) return true;
        NSString *name = CFBridgingRelease(CGImageMetadataTagCopyName(tag));
        id v = CFBridgingRelease(CGImageMetadataTagCopyValue(tag));
        if (name && [v isKindOfClass:[NSString class]]) values[name] = v;
        return true;
    });
    NSString *urn = values[@"AuxiliaryImageType"];
    NSString *type = urn ? [urns() allKeysForObject:urn].firstObject : nil;
    if (!type) { CFRelease(m); return NO; }
    out->type = type;
    out->format = (uint32_t)[values[@"NativeFormat"] longLongValue];
    out->ranged = values[@"FloatMinValue"] && values[@"FloatMaxValue"];
    out->min = [values[@"FloatMinValue"] doubleValue]; out->max = [values[@"FloatMaxValue"] doubleValue];
    if (metadata) *metadata = m; else CFRelease(m);
    return YES;
}
NSArray<NSDictionary *> *isim_io_auxiliary_list(NSData *jpeg) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSData *im in mpf_images(jpeg)) {
        aux_desc a;
        if (!describe(im, &a, NULL)) continue;
        double w = 0, h = 0; int hd = isim_image_load_data(im.bytes, im.length, &w, &h);
        if (hd) isim_image_free(hd);
        [out addObject:@{ S(kCGImagePropertyAuxiliaryDataType): a.type, S(kCGImagePropertyWidth): @((int)w), S(kCGImagePropertyHeight): @((int)h),
                          S(kCGImagePropertyPixelFormat): @(a.format) }];
    }
    return out;
}
NSDictionary *isim_io_auxiliary_info(NSData *jpeg, NSString *type) {
    for (NSData *im in mpf_images(jpeg)) {
        aux_desc a; CGImageMetadataRef md = NULL;
        if (!describe(im, &a, &md)) continue;
        if (![a.type isEqual:type]) { CFRelease(md); continue; }
        int bpp = 0, kind = kind_of(a.format, &bpp);
        double fw = 0, fh = 0; int hd = isim_image_load_data(im.bytes, im.length, &fw, &fh);
        if (kind < 0 || !hd) { if (hd) isim_image_free(hd); CFRelease(md); return nil; }
        int w = (int)fw, h = (int)fh;
        uint8_t *px = malloc((size_t)w * (size_t)h * 4);
        isim_image_read_pixels(hd, 0, 0, w, h, px, w * 4, ISIM_PX(0, 1, 2, 3), 4);
        isim_image_free(hd);
        size_t bpr = (size_t)w * (size_t)bpp;
        NSMutableData *data = [NSMutableData dataWithLength:bpr * (size_t)h];
        uint8_t *dst = data.mutableBytes;
        for (size_t i = 0; i < (size_t)w * (size_t)h; i++) {
            const uint8_t *s = px + 4 * i;
            if (kind == F_RGBA8) {
                BOOL bgra = a.format == 'BGRA';
                dst[4 * i] = s[bgra ? 2 : 0]; dst[4 * i + 1] = s[1]; dst[4 * i + 2] = s[bgra ? 0 : 2]; dst[4 * i + 3] = 255;
                continue;
            }
            float v = s[0] / 255.f;
            if (a.ranged) v = (float)(a.min + v * (a.max - a.min));
            store(dst + (size_t)bpp * i, kind, v);
        }
        free(px);
        NSDictionary *desc = @{ S(kCGImagePropertyWidth): @(w), S(kCGImagePropertyHeight): @(h), S(kCGImagePropertyBytesPerRow): @(bpr),
                                S(kCGImagePropertyPixelFormat): @(a.format) };
        return @{ S(kCGImageAuxiliaryDataInfoData): data, S(kCGImageAuxiliaryDataInfoDataDescription): desc,
                  S(kCGImageAuxiliaryDataInfoMetadata): (__bridge_transfer id)md };
    }
    return nil;
}

/* ---------------- writing ---------------- */
static NSData *_Nullable encode(NSString *type, NSDictionary *info) {
    NSData *data = info[S(kCGImageAuxiliaryDataInfoData)];
    NSDictionary *desc = info[S(kCGImageAuxiliaryDataInfoDataDescription)];
    NSString *urn = urns()[type];
    int w = [desc[S(kCGImagePropertyWidth)] intValue], h = [desc[S(kCGImagePropertyHeight)] intValue];
    uint32_t format = (uint32_t)[desc[S(kCGImagePropertyPixelFormat)] unsignedIntValue];
    int bpp = 0, kind = kind_of(format, &bpp);
    size_t bpr = desc[S(kCGImagePropertyBytesPerRow)] ? [desc[S(kCGImagePropertyBytesPerRow)] unsignedLongValue] : (size_t)w * (size_t)bpp;
    if (!urn || ![data isKindOfClass:[NSData class]] || kind < 0 || w <= 0 || h <= 0 || bpr < (size_t)w * (size_t)bpp || data.length < bpr * (size_t)(h - 1) + (size_t)w * (size_t)bpp)
        return nil;
    const uint8_t *src = data.bytes;
    /* the range of the values, stored in 8 bits */
    float lo = INFINITY, hi = -INFINITY;
    BOOL ranged = kind == F_HALF || kind == F_FLOAT;
    if (ranged)
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            float v = sample(src + (size_t)y * bpr + (size_t)x * (size_t)bpp, kind);
            if (isfinite(v)) { lo = fminf(lo, v); hi = fmaxf(hi, v); }
        }
    if (ranged && !(lo <= hi)) lo = hi = 0;
    uint8_t *px = malloc((size_t)w * (size_t)h * 4);
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
        const uint8_t *s = src + (size_t)y * bpr + (size_t)x * (size_t)bpp;
        uint8_t *p = px + 4 * ((size_t)y * (size_t)w + (size_t)x);
        if (kind == F_RGBA8) { BOOL bgra = format == 'BGRA'; p[0] = s[bgra ? 2 : 0]; p[1] = s[1]; p[2] = s[bgra ? 0 : 2]; p[3] = 255; continue; }
        float v = sample(s, kind);
        if (ranged) v = hi > lo && isfinite(v) ? (v - lo) / (hi - lo) : 0;
        p[0] = p[1] = p[2] = (uint8_t)lrintf(fminf(fmaxf(v, 0), 1) * 255); p[3] = 255;
    }
    int hd = isim_image_from_pixels(px, w, h, w * 4, ISIM_PX(0, 1, 2, 3), 4);
    free(px);
    unsigned char *bytes = NULL;
    long n = hd ? isim_image_encode(hd, 1, 1.0, &bytes) : 0;
    if (hd) isim_image_free(hd);
    if (n <= 0) { isim_image_bytes_free(bytes); return nil; }
    NSData *jpeg = [NSData dataWithBytes:bytes length:(NSUInteger)n];
    isim_image_bytes_free(bytes);
    /* its XMP: the metadata given, then what it is */
    CGImageMetadataRef given = (__bridge CGImageMetadataRef)info[S(kCGImageAuxiliaryDataInfoMetadata)];
    CGMutableImageMetadataRef m = given ? CGImageMetadataCreateMutableCopy(given) : CGImageMetadataCreateMutable();
    CGImageMetadataRegisterNamespaceForPrefix(m, (__bridge CFStringRef)kNamespace, CFSTR("apdi"), NULL);
    CGImageMetadataSetValueWithPath(m, NULL, CFSTR("apdi:AuxiliaryImageType"), (__bridge CFStringRef)urn);
    CGImageMetadataSetValueWithPath(m, NULL, CFSTR("apdi:NativeFormat"), (__bridge CFStringRef)[NSString stringWithFormat:@"%u", format]);
    if (ranged) {
        CGImageMetadataSetValueWithPath(m, NULL, CFSTR("apdi:FloatMinValue"), (__bridge CFStringRef)[NSString stringWithFormat:@"%.9g", lo]);
        CGImageMetadataSetValueWithPath(m, NULL, CFSTR("apdi:FloatMaxValue"), (__bridge CFStringRef)[NSString stringWithFormat:@"%.9g", hi]);
    }
    NSString *xmp = isim_io_xmp_of_metadata(m);
    CFRelease(m);
    return isim_io_embed_metadata(jpeg, @{}, xmp);
}
NSData *isim_io_jpeg_with_auxiliary(NSData *jpeg, NSArray<NSArray *> *aux) {
    NSMutableArray *images = [NSMutableArray array];
    for (NSArray *a in aux) {
        NSData *im = encode(a[0], a[1]);
        if (im) [images addObject:im];
    }
    return images.count ? with_mpf(jpeg, images) : jpeg;
}
