// ImageIO metadata from C / Objective-C (ImageIOTest.app, issue #272): the EXIF / TIFF / GPS tags Pillow wrote into
// the fixtures (make_fixtures.py), their IPTC and XMP; CGImageMetadata (paths, values, structures, arrays, namespaces,
// enumeration, XMP data both ways, image property matching); destinations writing properties, metadata, a source's
// metadata, and CGImageDestinationCopyImageSource. The JPEG written is printed (base64) for Pillow to check. Issue #362:
// CGAnimateImage*WithBlock, incremental sources, the cache, allowable types, and auxiliary data (disparity and a
// portrait matte written into a JPEG and read back; Pillow reads its Multi-Picture Format images).
#import <Foundation/Foundation.h>
#include <ImageIO/ImageIO.h>
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdio.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[220]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)
#define S(k) ((__bridge NSString *)(k))

static NSData *fixture(NSString *name) { return [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:nil]]; }
static NSDictionary *props_of(NSData *d) {
    CGImageSourceRef s = CGImageSourceCreateWithData((__bridge CFDataRef)d, NULL);
    NSDictionary *p = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(s, 0, NULL));
    CFRelease(s);
    return p;
}
static CGImageMetadataRef metadata_of(NSData *d) {
    CGImageSourceRef s = CGImageSourceCreateWithData((__bridge CFDataRef)d, NULL);
    CGImageMetadataRef m = CGImageSourceCopyMetadataAtIndex(s, 0, NULL);
    CFRelease(s);
    return m;
}
static NSString *str(CGImageMetadataRef m, NSString *path) { return CFBridgingRelease(CGImageMetadataCopyStringValueWithPath(m, NULL, (__bridge CFStringRef)path)); }
static BOOL near(id v, double want) { return [v isKindOfClass:[NSNumber class]] && fabs([v doubleValue] - want) < 1e-3; }
static CGImageRef solid(int w, int h) {
    CGContextRef c = CGBitmapContextCreate(NULL, (size_t)w, (size_t)h, 8, 0, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(c, 0.1, 0.4, 0.9, 1);
    CGContextFillRect(c, CGRectMake(0, 0, w, h));
    CGImageRef im = CGBitmapContextCreateImage(c);
    CGContextRelease(c);
    return im;
}

static void reading(NSString *name) {
    NSData *data = fixture(name);
    NSDictionary *p = props_of(data);
    NSDictionary *tiff = p[S(kCGImagePropertyTIFFDictionary)], *exif = p[S(kCGImagePropertyExifDictionary)], *gps = p[S(kCGImagePropertyGPSDictionary)];
    const char *n = name.UTF8String;
    CHECK([tiff[S(kCGImagePropertyTIFFMake)] isEqual:@"isim"] && [tiff[S(kCGImagePropertyTIFFModel)] isEqual:@"Test Camera"] &&
          [tiff[S(kCGImagePropertyTIFFArtist)] isEqual:@"Ana"] && [tiff[S(kCGImagePropertyTIFFDateTime)] isEqual:@"2024:05:06 07:08:09"], "%s: TIFF strings", n);
    CHECK(near(tiff[S(kCGImagePropertyTIFFXResolution)], 300) && [tiff[S(kCGImagePropertyTIFFResolutionUnit)] intValue] == 2 &&
          near(p[S(kCGImagePropertyDPIWidth)], 300), "%s: resolution and DPI", n);
    CHECK(near(exif[S(kCGImagePropertyExifExposureTime)], 0.008) && near(exif[S(kCGImagePropertyExifFNumber)], 2.8) &&
          near(exif[S(kCGImagePropertyExifExposureBiasValue)], -1.0 / 3) && near(exif[S(kCGImagePropertyExifFocalLength)], 4.2), "%s: Exif rationals", n);
    CHECK([exif[S(kCGImagePropertyExifISOSpeedRatings)] isEqual:@[ @100 ]] && [exif[S(kCGImagePropertyExifVersion)] isEqual:(@[ @2, @3, @2 ])] &&
          [exif[S(kCGImagePropertyExifFlash)] intValue] == 16 && [exif[S(kCGImagePropertyExifFocalLenIn35mmFilm)] intValue] == 26, "%s: Exif arrays and numbers", n);
    CHECK([exif[S(kCGImagePropertyExifDateTimeOriginal)] isEqual:@"2024:05:06 07:08:09"] && [exif[S(kCGImagePropertyExifOffsetTime)] isEqual:@"+01:00"] &&
          [exif[S(kCGImagePropertyExifLensModel)] isEqual:@"Wide Lens"], "%s: Exif strings", n);
    CHECK(near(gps[S(kCGImagePropertyGPSLatitude)], 37.7734) && [gps[S(kCGImagePropertyGPSLatitudeRef)] isEqual:@"N"] &&
          near(gps[S(kCGImagePropertyGPSLongitude)], 122.41965) && [gps[S(kCGImagePropertyGPSLongitudeRef)] isEqual:@"W"], "%s: GPS coordinates", n);
    CHECK(near(gps[S(kCGImagePropertyGPSAltitude)], 52.5) && [gps[S(kCGImagePropertyGPSAltitudeRef)] intValue] == 0 &&
          [gps[S(kCGImagePropertyGPSTimeStamp)] isEqual:@"12:34:56"] && [gps[S(kCGImagePropertyGPSDateStamp)] isEqual:@"2024:05:06"] &&
          [gps[S(kCGImagePropertyGPSVersion)] isEqual:(@[ @2, @2, @0, @0 ])], "%s: GPS altitude, time, version", n);

    CGImageMetadataRef m = metadata_of(data);
    CHECK(m != NULL, "%s: metadata", n);
    CHECK([str(m, @"dc:title") isEqual:@"A test image"] && [str(m, @"dc:title[@xml:lang=pt]") isEqual:@"Uma imagem"], "%s: XMP alternate text", n);
    CGImageMetadataTagRef subject = CGImageMetadataCopyTagWithPath(m, NULL, CFSTR("dc:subject"));
    NSArray *items = CFBridgingRelease(CGImageMetadataTagCopyValue(subject));
    CHECK(CGImageMetadataTagGetType(subject) == kCGImageMetadataTypeArrayUnordered && items.count == 2 && [str(m, @"dc:subject[1]") isEqual:@"green"],
          "%s: XMP bag", n);
    if (subject) CFRelease(subject);
    CGImageMetadataTagRef creator = CGImageMetadataCopyTagWithPath(m, NULL, CFSTR("dc:creator"));
    CHECK(CGImageMetadataTagGetType(creator) == kCGImageMetadataTypeArrayOrdered && [str(m, @"dc:creator[0]") isEqual:@"Ana"], "%s: XMP seq", n);
    if (creator) CFRelease(creator);
    CHECK([str(m, @"xmp:Rating") isEqual:@"4"] && [str(m, @"photoshop:City") isEqual:@"Lisbon"], "%s: XMP attributes as simple properties", n);
    CHECK([str(m, @"Iptc4xmpCore:CreatorContactInfo.Iptc4xmpCore:CiEmailWork") isEqual:@"ana@example.com"], "%s: XMP structure", n);
    CHECK([str(m, @"tiff:Make") isEqual:@"isim"] && [str(m, @"exif:FNumber") isEqual:@"28/10"] && [str(m, @"exif:GPSLatitude") isEqual:@"37,46.404N"] &&
          [str(m, @"exif:DateTimeOriginal") isEqual:@"2024-05-06T07:08:09"], "%s: EXIF in XMP (%s, %s, %s)", n, str(m, @"exif:FNumber").UTF8String,
          str(m, @"exif:GPSLatitude").UTF8String, str(m, @"exif:DateTimeOriginal").UTF8String);
    CGImageMetadataTagRef lat = CGImageMetadataCopyTagMatchingImageProperty(m, kCGImagePropertyGPSDictionary, kCGImagePropertyGPSLatitude);
    CHECK(lat && [CFBridgingRelease(CGImageMetadataTagCopyName(lat)) isEqual:@"GPSLatitude"] &&
          [CFBridgingRelease(CGImageMetadataTagCopyNamespace(lat)) isEqual:S(kCGImageMetadataNamespaceExif)], "%s: tag matching a GPS property", n);
    if (lat) CFRelease(lat);
    if (m) CFRelease(m);
}

static void iptc(void) {
    NSDictionary *i = props_of(fixture(@"meta.jpg"))[S(kCGImagePropertyIPTCDictionary)];
    CHECK([i[S(kCGImagePropertyIPTCObjectName)] isEqual:@"Fixture"] && [i[S(kCGImagePropertyIPTCKeywords)] isEqual:(@[ @"red", @"green" ])] &&
          [i[S(kCGImagePropertyIPTCByline)] isEqual:@[ @"Ana" ]] && [i[S(kCGImagePropertyIPTCCity)] isEqual:@"Lisbon"] &&
          [i[S(kCGImagePropertyIPTCCountryPrimaryLocationName)] isEqual:@"Portugal"] && [i[S(kCGImagePropertyIPTCCaptionAbstract)] isEqual:@"A small test image"] &&
          [i[S(kCGImagePropertyIPTCDateCreated)] isEqual:@"20240506"], "jpeg: IPTC");
}

static void model(void) {
    CGMutableImageMetadataRef m = CGImageMetadataCreateMutable();
    CFErrorRef err = NULL;
    CHECK(CGImageMetadataRegisterNamespaceForPrefix(m, CFSTR("http://isim.dev/ns/1.0/"), CFSTR("isim"), &err), "model: a namespace");
    CHECK(!CGImageMetadataRegisterNamespaceForPrefix(m, CFSTR("http://other/"), CFSTR("isim"), &err) && err &&
          CFErrorGetCode(err) == kCGImageMetadataErrorPrefixConflict, "model: a prefix conflict");
    if (err) CFRelease(err);
    CHECK(CGImageMetadataSetValueWithPath(m, NULL, CFSTR("isim:Answer"), (__bridge CFTypeRef)@42) && [str(m, @"isim:Answer") isEqual:@"42"],
          "model: a number becomes a string");
    CHECK(CGImageMetadataSetValueWithPath(m, NULL, CFSTR("isim:Flag"), kCFBooleanTrue) && [str(m, @"isim:Flag") isEqual:@"True"], "model: a boolean");
    CHECK(!CGImageMetadataSetValueWithPath(m, NULL, CFSTR("nope:X"), CFSTR("x")), "model: an unknown prefix fails");
    CGImageMetadataSetValueWithPath(m, NULL, CFSTR("dc:subject"), (__bridge CFTypeRef)@[ @"one", @"two" ]);
    CGImageMetadataSetValueWithPath(m, NULL, CFSTR("isim:Info"), (__bridge CFTypeRef)@{ @"isim:a": @"1" });
    CHECK(CGImageMetadataSetValueWithPath(m, NULL, CFSTR("isim:Info.isim:b"), CFSTR("2")) && [str(m, @"isim:Info.isim:b") isEqual:@"2"] &&
          [str(m, @"isim:Info.isim:a") isEqual:@"1"], "model: a structure's fields");
    CGImageMetadataTagRef info = CGImageMetadataCopyTagWithPath(m, NULL, CFSTR("isim:Info"));
    CHECK(CGImageMetadataTagGetType(info) == kCGImageMetadataTypeStructure && [CFBridgingRelease(CGImageMetadataCopyStringValueWithPath(m, info, CFSTR("isim:a"))) isEqual:@"1"],
          "model: a path from a parent tag");
    if (info) CFRelease(info);
    CGImageMetadataTagRef item = CGImageMetadataTagCreate(kCGImageMetadataNamespaceDublinCore, kCGImageMetadataPrefixDublinCore, CFSTR("x"), kCGImageMetadataTypeString, CFSTR("three"));
    CHECK(CGImageMetadataSetTagWithPath(m, NULL, CFSTR("dc:subject[2]"), item) && [str(m, @"dc:subject[2]") isEqual:@"three"], "model: an array item set");
    CFRelease(item);
    CGImageMetadataTagRef alt = CGImageMetadataTagCreate(kCGImageMetadataNamespaceDublinCore, NULL, CFSTR("title"), kCGImageMetadataTypeAlternateText, (__bridge CFTypeRef)@[ @"Hello" ]);
    CHECK([CFBridgingRelease(CGImageMetadataTagCopyPrefix(alt)) isEqual:@"dc"], "model: the prefix of a known namespace");
    CGImageMetadataSetTagWithPath(m, NULL, CFSTR("dc:title"), alt);
    CFRelease(alt);
    __block NSMutableArray *paths = [NSMutableArray array];
    CGImageMetadataEnumerateTagsUsingBlock(m, NULL, (__bridge CFDictionaryRef)@{ S(kCGImageMetadataEnumerateRecursively): @YES }, ^bool(CFStringRef path, CGImageMetadataTagRef tag) {
        [paths addObject:(__bridge NSString *)path];
        return true;
    });
    CHECK([paths containsObject:@"isim:Info.isim:b"] && [paths containsObject:@"dc:subject[2]"] && [paths containsObject:@"isim:Answer"], "model: enumerate recursively (%lu)",
          (unsigned long)paths.count);
    __block int top = 0;
    CGImageMetadataEnumerateTagsUsingBlock(m, NULL, NULL, ^bool(CFStringRef path, CGImageMetadataTagRef tag) { top++; return top < 2; });
    CHECK(top == 2, "model: enumeration stops when the block says so");
    CHECK(CGImageMetadataRemoveTagWithPath(m, NULL, CFSTR("isim:Flag")) && !str(m, @"isim:Flag") && !CGImageMetadataRemoveTagWithPath(m, NULL, CFSTR("isim:Flag")),
          "model: remove");

    NSData *xmp = CFBridgingRelease(CGImageMetadataCreateXMPData(m, NULL));
    CGImageMetadataRef back = CGImageMetadataCreateFromXMPData((__bridge CFDataRef)xmp);
    CHECK(back && [str(back, @"isim:Answer") isEqual:@"42"] && [str(back, @"isim:Info.isim:b") isEqual:@"2"] && [str(back, @"dc:subject[2]") isEqual:@"three"] &&
          [str(back, @"dc:title") isEqual:@"Hello"], "model: XMP data both ways");
    CGImageMetadataTagRef t = CGImageMetadataCopyTagWithPath(back, NULL, CFSTR("dc:title"));
    CHECK(CGImageMetadataTagGetType(t) == kCGImageMetadataTypeAlternateText, "model: alternate text kept");
    if (t) CFRelease(t);
    CGMutableImageMetadataRef copy = CGImageMetadataCreateMutableCopy(back);
    CHECK(CGImageMetadataSetValueMatchingImageProperty(copy, kCGImagePropertyExifDictionary, kCGImagePropertyExifFNumber, (__bridge CFTypeRef)@1.8) &&
          [str(copy, @"exif:FNumber") isEqual:@"18/10"] && !str(back, @"exif:FNumber"), "model: a value matching a property; copies are independent");
    CHECK(!CGImageMetadataCreateFromXMPData((__bridge CFDataRef)[@"<not xml" dataUsingEncoding:NSUTF8StringEncoding]), "model: bad XMP");
    CFRelease(copy); if (back) CFRelease(back); CFRelease(m);
}

static NSData *write_jpeg(CGImageRef im, NSDictionary *props, CGImageMetadataRef md) {
    NSMutableData *out = [NSMutableData data];
    CGImageDestinationRef d = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)out, CFSTR("public.jpeg"), 1, NULL);
    if (md) CGImageDestinationAddImageAndMetadata(d, im, md, (__bridge CFDictionaryRef)props);
    else CGImageDestinationAddImage(d, im, (__bridge CFDictionaryRef)props);
    bool ok = CGImageDestinationFinalize(d);
    CFRelease(d);
    return ok ? out : nil;
}
static NSData *jpeg_scan(NSData *d) {                                    /* the bytes from the image data on */
    const uint8_t *p = d.bytes;
    for (size_t o = 2; o + 4 <= d.length && p[o] == 0xFF;) {
        if (p[o + 1] == 0xDA) return [d subdataWithRange:NSMakeRange(o, d.length - o)];
        o += 2 + ((size_t)p[o + 2] << 8 | p[o + 3]);
    }
    return nil;
}

static void writing(void) {
    CGImageRef im = solid(24, 16);
    NSDictionary *props = @{
        S(kCGImagePropertyOrientation): @6,
        S(kCGImagePropertyTIFFDictionary): @{ S(kCGImagePropertyTIFFMake): @"Written", S(kCGImagePropertyTIFFModel): @"By isim" },
        S(kCGImagePropertyExifDictionary): @{ S(kCGImagePropertyExifDateTimeOriginal): @"2025:01:02 03:04:05", S(kCGImagePropertyExifFNumber): @1.8,
                                              S(kCGImagePropertyExifISOSpeedRatings): @[ @200 ], S(kCGImagePropertyExifExposureTime): @0.01,
                                              S(kCGImagePropertyExifVersion): @[ @2, @3, @2 ], S(kCGImagePropertyExifUserComment): @"hello" },
        S(kCGImagePropertyGPSDictionary): @{ S(kCGImagePropertyGPSLatitude): @48.8584, S(kCGImagePropertyGPSLatitudeRef): @"N",
                                             S(kCGImagePropertyGPSLongitude): @2.2945, S(kCGImagePropertyGPSLongitudeRef): @"E",
                                             S(kCGImagePropertyGPSAltitude): @35, S(kCGImagePropertyGPSAltitudeRef): @0 },
        S(kCGImagePropertyIPTCDictionary): @{ S(kCGImagePropertyIPTCKeywords): @[ @"a", @"b" ], S(kCGImagePropertyIPTCCity): @"Paris" } };
    NSData *jpg = write_jpeg(im, props, NULL);
    NSDictionary *p = props_of(jpg);
    NSDictionary *tiff = p[S(kCGImagePropertyTIFFDictionary)], *exif = p[S(kCGImagePropertyExifDictionary)], *gps = p[S(kCGImagePropertyGPSDictionary)];
    CHECK([tiff[S(kCGImagePropertyTIFFMake)] isEqual:@"Written"] && [p[S(kCGImagePropertyOrientation)] intValue] == 6, "write: TIFF and orientation");
    CHECK(near(exif[S(kCGImagePropertyExifFNumber)], 1.8) && near(exif[S(kCGImagePropertyExifExposureTime)], 0.01) &&
          [exif[S(kCGImagePropertyExifISOSpeedRatings)] isEqual:@[ @200 ]] && [exif[S(kCGImagePropertyExifUserComment)] isEqual:@"hello"] &&
          [exif[S(kCGImagePropertyExifVersion)] isEqual:(@[ @2, @3, @2 ])], "write: Exif read back");
    CHECK(near(gps[S(kCGImagePropertyGPSLatitude)], 48.8584) && [gps[S(kCGImagePropertyGPSLongitudeRef)] isEqual:@"E"] && near(gps[S(kCGImagePropertyGPSAltitude)], 35),
          "write: GPS read back");
    CHECK([p[S(kCGImagePropertyIPTCDictionary)][S(kCGImagePropertyIPTCKeywords)] isEqual:(@[ @"a", @"b" ])], "write: IPTC read back");
    printf("WROTE-JPEG %s\n", [jpg base64EncodedStringWithOptions:0].UTF8String);

    /* XMP metadata: written as XMP, and as EXIF where it maps */
    CGMutableImageMetadataRef md = CGImageMetadataCreateMutable();
    CGImageMetadataSetValueWithPath(md, NULL, CFSTR("tiff:Make"), CFSTR("MetaMake"));
    CGImageMetadataSetValueWithPath(md, NULL, CFSTR("exif:GPSLatitude"), CFSTR("10,30N"));
    CGImageMetadataSetValueWithPath(md, NULL, CFSTR("xmp:Rating"), CFSTR("5"));
    NSData *mj = write_jpeg(im, nil, md);
    NSDictionary *mp = props_of(mj);
    CGImageMetadataRef mback = metadata_of(mj);
    CHECK([mp[S(kCGImagePropertyTIFFDictionary)][S(kCGImagePropertyTIFFMake)] isEqual:@"MetaMake"] &&
          near(mp[S(kCGImagePropertyGPSDictionary)][S(kCGImagePropertyGPSLatitude)], 10.5) && [str(mback, @"xmp:Rating") isEqual:@"5"],
          "write: AddImageAndMetadata (EXIF from XMP, XMP kept)");
    CFRelease(mback);

    /* a source's metadata carried over, the properties given override it */
    NSMutableData *carried = [NSMutableData data];
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)fixture(@"meta.jpg"), NULL);
    CGImageDestinationRef cd = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)carried, CFSTR("public.jpeg"), 1, NULL);
    CGImageDestinationAddImageFromSource(cd, src, 0, (__bridge CFDictionaryRef)@{ S(kCGImagePropertyTIFFDictionary): @{ S(kCGImagePropertyTIFFModel): @"Changed" } });
    CGImageDestinationFinalize(cd);
    CFRelease(cd);
    NSDictionary *cp = props_of(carried);
    CGImageMetadataRef cm = metadata_of(carried);
    CHECK([cp[S(kCGImagePropertyTIFFDictionary)][S(kCGImagePropertyTIFFMake)] isEqual:@"isim"] && [cp[S(kCGImagePropertyTIFFDictionary)][S(kCGImagePropertyTIFFModel)] isEqual:@"Changed"] &&
          near(cp[S(kCGImagePropertyGPSDictionary)][S(kCGImagePropertyGPSLatitude)], 37.7734) && [cp[S(kCGImagePropertyIPTCDictionary)][S(kCGImagePropertyIPTCCity)] isEqual:@"Lisbon"] &&
          [str(cm, @"xmp:Rating") isEqual:@"4"], "write: AddImageFromSource keeps the source's metadata");
    CFRelease(cm);

    /* lossless: new metadata, the image data as it is */
    NSMutableData *lossless = [NSMutableData data];
    CGImageDestinationRef ld = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)lossless, CFSTR("public.jpeg"), 1, NULL);
    CGMutableImageMetadataRef add = CGImageMetadataCreateMutable();
    CGImageMetadataSetValueWithPath(add, NULL, CFSTR("xmp:Rating"), CFSTR("5"));
    CFErrorRef err = NULL;
    bool ok = CGImageDestinationCopyImageSource(ld, src, (__bridge CFDictionaryRef)@{ S(kCGImageDestinationMetadata): (__bridge id)add, S(kCGImageDestinationMergeMetadata): @YES,
                                                                                     S(kCGImageMetadataShouldExcludeGPS): @YES, S(kCGImageDestinationOrientation): @3 }, &err);
    CFRelease(ld); CFRelease(add);
    NSDictionary *lp = props_of(lossless);
    CGImageMetadataRef lm = metadata_of(lossless);
    CHECK(ok && [jpeg_scan(lossless) isEqual:jpeg_scan(fixture(@"meta.jpg"))], "copy image source: the image data unchanged");
    CHECK([lp[S(kCGImagePropertyTIFFDictionary)][S(kCGImagePropertyTIFFMake)] isEqual:@"isim"] && !lp[S(kCGImagePropertyGPSDictionary)] &&
          [str(lm, @"xmp:Rating") isEqual:@"5"] && !str(lm, @"exif:GPSLatitude") && [lp[S(kCGImagePropertyOrientation)] intValue] == 3,
          "copy image source: merged, GPS excluded, orientation set");
    CFRelease(lm);
    NSMutableData *wrong = [NSMutableData data];
    CGImageDestinationRef wd = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)wrong, CFSTR("public.png"), 1, NULL);
    CHECK(!CGImageDestinationCopyImageSource(wd, src, NULL, &err) && err && CFErrorGetCode(err) == kCGImageMetadataErrorUnsupportedFormat, "copy image source: another type fails");
    if (err) CFRelease(err);
    CFRelease(wd); CFRelease(src);

    /* PNG: eXIf and the XMP iTXt */
    NSMutableData *png = [NSMutableData data];
    CGImageDestinationRef pd = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)png, CFSTR("public.png"), 1, NULL);
    CGImageDestinationAddImageAndMetadata(pd, im, md, (__bridge CFDictionaryRef)@{ S(kCGImagePropertyExifDictionary): @{ S(kCGImagePropertyExifLensModel): @"PNG lens" } });
    CGImageDestinationFinalize(pd);
    CFRelease(pd);
    NSDictionary *pp = props_of(png);
    CGImageMetadataRef pm = metadata_of(png);
    CHECK([pp[S(kCGImagePropertyExifDictionary)][S(kCGImagePropertyExifLensModel)] isEqual:@"PNG lens"] && [str(pm, @"xmp:Rating") isEqual:@"5"] &&
          [pp[S(kCGImagePropertyTIFFDictionary)][S(kCGImagePropertyTIFFMake)] isEqual:@"MetaMake"], "write: PNG metadata read back");
    CGImageSourceRef ps = CGImageSourceCreateWithData((__bridge CFDataRef)png, NULL);
    CHECK(CGImageSourceGetCount(ps) == 1 && CGImageSourceCreateImageAtIndex(ps, 0, NULL), "write: the PNG still decodes");
    CFRelease(ps); CFRelease(pm); CFRelease(md);
    CGImageRelease(im);
}

/* ---------------- animation (issue #362) ---------------- */
static CGImageRef colored(int w, int h, double r, double g, double b) {
    CGContextRef c = CGBitmapContextCreate(NULL, (size_t)w, (size_t)h, 8, 0, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(c, r, g, b, 1);
    CGContextFillRect(c, CGRectMake(0, 0, w, h));
    CGImageRef im = CGBitmapContextCreateImage(c);
    CGContextRelease(c);
    return im;
}
static NSData *three_frame_gif(int loops) {
    NSMutableData *gif = [NSMutableData data];
    CGImageDestinationRef d = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)gif, CFSTR("com.compuserve.gif"), 3, NULL);
    CGImageDestinationSetProperties(d, (__bridge CFDictionaryRef)@{ S(kCGImagePropertyGIFDictionary): @{ S(kCGImagePropertyGIFLoopCount): @(loops) } });
    double rgb[3][3] = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } };
    for (int i = 0; i < 3; i++) {
        CGImageRef im = colored(8, 6, rgb[i][0], rgb[i][1], rgb[i][2]);
        CGImageDestinationAddImage(d, im, (__bridge CFDictionaryRef)@{ S(kCGImagePropertyGIFDictionary): @{ S(kCGImagePropertyGIFDelayTime): @(0.02 * (i + 1)) } });
        CGImageRelease(im);
    }
    CGImageDestinationFinalize(d);
    CFRelease(d);
    return gif;
}
static void spin(BOOL (^done)(void), double seconds) {
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [until timeIntervalSinceNow] > 0) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, false);
}
static int red_of(CGImageRef im) {
    uint8_t px[4] = { 0 };
    CGContextRef c = CGBitmapContextCreate(px, 1, 1, 8, 4, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(c, CGRectMake(0, 0, 1, 1), im);
    CGContextRelease(c);
    return px[0] > 128 ? 0 : px[1] > 128 ? 1 : px[2] > 128 ? 2 : -1;   /* which of the three colors */
}
static void animation(void) {
    NSData *gif = three_frame_gif(2);
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)gif, NULL);
    NSDictionary *file = CFBridgingRelease(CGImageSourceCopyProperties(src, NULL));
    NSDictionary *g = file[S(kCGImagePropertyGIFDictionary)];
    NSArray *frames = g[S(kCGImagePropertyGIFFrameInfoArray)];
    CHECK([g[S(kCGImagePropertyGIFLoopCount)] intValue] == 2 && [g[S(kCGImagePropertyGIFCanvasPixelWidth)] intValue] == 8 &&
          [g[S(kCGImagePropertyGIFCanvasPixelHeight)] intValue] == 6 && frames.count == 3 &&
          near(frames[2][S(kCGImagePropertyGIFDelayTime)], 0.06), "animation: the GIF's loop count, canvas and frame info");
    CFRelease(src);

    /* the file's loop count: 3 frames, twice, in order, each the right color */
    NSMutableArray *seen = [NSMutableArray array];
    __block BOOL colors = YES;
    OSStatus st = CGAnimateImageDataWithBlock((__bridge CFDataRef)gif, NULL, ^(size_t index, CGImageRef image, bool *stop) {
        [seen addObject:@(index)];
        if (red_of(image) != (int)index) colors = NO;
    });
    CHECK(st == noErr && seen.count == 0, "animation: starts on the main queue, after returning");
    spin(^BOOL { return seen.count >= 6; }, 10);
    spin(^BOOL { return NO; }, 0.4);   /* and no more frames after the last loop */
    CHECK([seen isEqual:(@[ @0, @1, @2, @0, @1, @2 ])] && colors, "animation: the frames of two loops (%s)", seen.description.UTF8String);

    /* options: a start index, one loop, a fixed delay; the block stops it */
    NSMutableArray *started = [NSMutableArray array];
    NSDate *t0 = [NSDate date];
    __block double last = 0;
    CGAnimateImageDataWithBlock((__bridge CFDataRef)gif, (__bridge CFDictionaryRef)@{ S(kCGImageAnimationStartIndex): @1, S(kCGImageAnimationLoopCount): @0,
                                                                                     S(kCGImageAnimationDelayTime): @0.25 }, ^(size_t index, CGImageRef image, bool *stop) {
        [started addObject:@(index)];
        last = -[t0 timeIntervalSinceNow];
        if (started.count == 4) *stop = true;
    });
    spin(^BOOL { return started.count >= 4; }, 10);
    spin(^BOOL { return NO; }, 0.6);
    CHECK([started isEqual:(@[ @1, @2, @0, @1 ])] && last >= 0.7, "animation: start index, delay time, stopped by the block (%s, %.2fs)",
          started.description.UTF8String, last);

    /* a still image is one frame; bad input fails */
    __block int stills = 0;
    NSData *png = nil;
    { NSMutableData *m = [NSMutableData data]; CGImageDestinationRef d = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)m, CFSTR("public.png"), 1, NULL);
      CGImageRef im = colored(4, 4, 1, 0, 0); CGImageDestinationAddImage(d, im, NULL); CGImageDestinationFinalize(d); CFRelease(d); CGImageRelease(im); png = m; }
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"still.png"]];
    [png writeToURL:url atomically:YES];
    CHECK(CGAnimateImageAtURLWithBlock((__bridge CFURLRef)url, NULL, ^(size_t index, CGImageRef image, bool *stop) { stills++; }) == noErr,
          "animation: from a URL");
    spin(^BOOL { return stills > 0; }, 10);
    spin(^BOOL { return NO; }, 0.3);
    CHECK(stills == 1, "animation: a still image is shown once (%d)", stills);
    CHECK(CGAnimateImageDataWithBlock((__bridge CFDataRef)[@"not an image" dataUsingEncoding:NSUTF8StringEncoding], NULL,
                                      ^(size_t index, CGImageRef image, bool *stop) {}) == kCGImageAnimationStatus_UnsupportedFormat,
          "animation: unknown data is an unsupported format");
    CHECK(CGAnimateImageDataWithBlock((__bridge CFDataRef)gif, (__bridge CFDictionaryRef)@{ S(kCGImageAnimationStartIndex): @3 },
                                      ^(size_t index, CGImageRef image, bool *stop) {}) == kCGImageAnimationStatus_ParameterError,
          "animation: a start index past the frames");
}

/* ---------------- sources: incremental data, the cache, allowable types ---------------- */
static void sources(void) {
    NSData *gif = three_frame_gif(0);
    CGImageSourceRef inc = CGImageSourceCreateIncremental(NULL);
    CHECK(CGImageSourceGetStatus(inc) == kCGImageStatusReadingHeader && CGImageSourceGetCount(inc) == 0, "incremental: no data yet");
    CGImageSourceUpdateData(inc, (__bridge CFDataRef)[gif subdataWithRange:NSMakeRange(0, 20)], false);
    CHECK(CGImageSourceGetStatus(inc) == kCGImageStatusIncomplete, "incremental: part of the data");
    CGDataProviderRef prov = CGDataProviderCreateWithCFData((__bridge CFDataRef)gif);
    CGImageSourceUpdateDataProvider(inc, prov, true);
    CGDataProviderRelease(prov);
    CGImageRef im = CGImageSourceCreateImageAtIndex(inc, 2, NULL);
    CHECK(CGImageSourceGetStatus(inc) == kCGImageStatusComplete && CGImageSourceGetCount(inc) == 3 && im && red_of(im) == 2,
          "incremental: all of it, through a data provider");
    CGImageRelease(im);
    CGImageSourceRemoveCacheAtIndex(inc, 2);
    im = CGImageSourceCreateImageAtIndex(inc, 2, NULL);
    CHECK(im && red_of(im) == 2, "remove cache: the frame decodes again");
    CGImageRelease(im);
    CFRelease(inc);
    CHECK(CGImageSourceSetAllowableTypes((__bridge CFArrayRef)@[ @"public.png" ]) == noErr, "allowable types: set");
    CGImageSourceRef no = CGImageSourceCreateWithData((__bridge CFDataRef)gif, NULL);
    CHECK(CGImageSourceGetCount(no) == 0 && CGImageSourceGetStatus(no) == kCGImageStatusUnknownType, "allowable types: a GIF is not read");
    CFRelease(no);
    CGImageSourceSetAllowableTypes((__bridge CFArrayRef)@[ @"public.png", @"com.compuserve.gif", @"public.jpeg" ]);
    CGImageSourceRef yes = CGImageSourceCreateWithData((__bridge CFDataRef)gif, NULL);
    CHECK(CGImageSourceGetCount(yes) == 3, "allowable types: allowed again");
    CFRelease(yes);
}

/* ---------------- auxiliary data (issue #362) ---------------- */
static uint16_t half_of(float f) { __fp16 h = (__fp16)f; uint16_t u; memcpy(&u, &h, 2); return u; }
static float float_of_half(uint16_t u) { __fp16 h; memcpy(&h, &u, 2); return (float)h; }
static void auxiliary(void) {
    /* disparity (half floats, 1.0 to 3.0, a ramp) and a portrait matte (8 bits) */
    const int W = 16, H = 12;
    NSMutableData *disp = [NSMutableData dataWithLength:(size_t)W * H * 2];
    uint16_t *dv = disp.mutableBytes;
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) dv[y * W + x] = half_of(1.0f + 2.0f * (float)x / (W - 1));
    NSMutableData *matte = [NSMutableData dataWithLength:(size_t)W * H];
    uint8_t *mv = matte.mutableBytes;
    for (int i = 0; i < W * H; i++) mv[i] = i % W < W / 2 ? 255 : 0;
    CGMutableImageMetadataRef md = CGImageMetadataCreateMutable();
    CGImageMetadataRegisterNamespaceForPrefix(md, CFSTR("http://isim.dev/ns/1.0/"), CFSTR("isim"), NULL);
    CGImageMetadataSetValueWithPath(md, NULL, CFSTR("isim:Camera"), CFSTR("rear"));
    NSDictionary *dispInfo = @{ S(kCGImageAuxiliaryDataInfoData): disp, S(kCGImageAuxiliaryDataInfoMetadata): (__bridge id)md,
                                S(kCGImageAuxiliaryDataInfoDataDescription): @{ S(kCGImagePropertyWidth): @(W), S(kCGImagePropertyHeight): @(H),
                                                                                S(kCGImagePropertyBytesPerRow): @(W * 2), S(kCGImagePropertyPixelFormat): @((uint32_t)'hdis') } };
    NSDictionary *matteInfo = @{ S(kCGImageAuxiliaryDataInfoData): matte,
                                 S(kCGImageAuxiliaryDataInfoDataDescription): @{ S(kCGImagePropertyWidth): @(W), S(kCGImagePropertyHeight): @(H),
                                                                                 S(kCGImagePropertyBytesPerRow): @(W), S(kCGImagePropertyPixelFormat): @((uint32_t)'L008') } };
    NSMutableData *jpg = [NSMutableData data];
    CGImageDestinationRef d = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)jpg, CFSTR("public.jpeg"), 1, NULL);
    CGImageRef im = colored(32, 24, 0.2, 0.5, 0.8);
    CGImageDestinationAddImage(d, im, (__bridge CFDictionaryRef)@{ S(kCGImagePropertyTIFFDictionary): @{ S(kCGImagePropertyTIFFMake): @"Aux" } });
    CGImageDestinationAddAuxiliaryDataInfo(d, kCGImageAuxiliaryDataTypeDisparity, (__bridge CFDictionaryRef)dispInfo);
    CGImageDestinationAddAuxiliaryDataInfo(d, kCGImageAuxiliaryDataTypePortraitEffectsMatte, (__bridge CFDictionaryRef)matteInfo);
    CHECK(CGImageDestinationFinalize(d), "aux: a JPEG with disparity and a matte");
    CFRelease(d); CGImageRelease(im); CFRelease(md);

    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)jpg, NULL);
    NSDictionary *p = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(src, 0, NULL));
    NSArray *list = p[S(kCGImagePropertyAuxiliaryData)];
    CHECK(CGImageSourceGetCount(src) == 1 && [p[S(kCGImagePropertyPixelWidth)] intValue] == 32 &&
          [p[S(kCGImagePropertyTIFFDictionary)][S(kCGImagePropertyTIFFMake)] isEqual:@"Aux"], "aux: the primary image and its metadata");
    CHECK(list.count == 2 && [list[0][S(kCGImagePropertyAuxiliaryDataType)] isEqual:S(kCGImageAuxiliaryDataTypeDisparity)] &&
          [list[1][S(kCGImagePropertyAuxiliaryDataType)] isEqual:S(kCGImageAuxiliaryDataTypePortraitEffectsMatte)] && [list[0][S(kCGImagePropertyWidth)] intValue] == W,
          "aux: listed in the image's properties");
    NSDictionary *back = CFBridgingRelease(CGImageSourceCopyAuxiliaryDataInfoAtIndex(src, 0, kCGImageAuxiliaryDataTypeDisparity));
    NSDictionary *desc = back[S(kCGImageAuxiliaryDataInfoDataDescription)];
    NSData *bd = back[S(kCGImageAuxiliaryDataInfoData)];
    CHECK([desc[S(kCGImagePropertyWidth)] intValue] == W && [desc[S(kCGImagePropertyHeight)] intValue] == H && [desc[S(kCGImagePropertyBytesPerRow)] intValue] == W * 2 &&
          [desc[S(kCGImagePropertyPixelFormat)] unsignedIntValue] == 'hdis' && bd.length == (NSUInteger)(W * H * 2), "aux: the disparity's description");
    double worst = 0;
    const uint16_t *bv = bd.bytes;
    for (int i = 0; i < W * H && bv; i++) worst = fmax(worst, fabs(float_of_half(bv[i]) - float_of_half(dv[i])));
    CHECK(bv && worst < 0.05, "aux: the disparity's values, within 8-bit precision (off by %.4f)", worst);
    CGImageMetadataRef bm = (__bridge CGImageMetadataRef)back[S(kCGImageAuxiliaryDataInfoMetadata)];
    CHECK(bm && [str(bm, @"isim:Camera") isEqual:@"rear"], "aux: its metadata");
    NSDictionary *mback = CFBridgingRelease(CGImageSourceCopyAuxiliaryDataInfoAtIndex(src, 0, kCGImageAuxiliaryDataTypePortraitEffectsMatte));
    NSData *mm = mback[S(kCGImageAuxiliaryDataInfoData)];
    const uint8_t *mb = mm.bytes;
    int wrong = 0;
    for (int i = 0; i < W * H && mb; i++) wrong += abs((int)mb[i] - (int)mv[i]) > 24;
    CHECK(mm.length == (NSUInteger)(W * H) && !wrong, "aux: the matte's pixels (%d wrong)", wrong);
    CHECK(!CGImageSourceCopyAuxiliaryDataInfoAtIndex(src, 0, kCGImageAuxiliaryDataTypeDepth), "aux: a type the image lacks");
    CGImageRef prim = CGImageSourceCreateImageAtIndex(src, 0, NULL);
    CHECK(prim && CGImageGetWidth(prim) == 32, "aux: the primary image still decodes");
    CGImageRelease(prim);
    CFRelease(src);
    printf("WROTE-AUX %s\n", [jpg base64EncodedStringWithOptions:0].UTF8String);
}

int main(void) {
    @autoreleasepool {
        reading(@"meta.jpg");
        reading(@"meta.png");
        iptc();
        model();
        writing();
        animation();
        sources();
        auxiliary();
        printf("imageio: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
