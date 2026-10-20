/* isim ImageIO metadata (issue #272), read and written by isim itself (adapted; the host has no EXIF library):
 * - EXIF / TIFF / GPS: TIFF IFDs (IFD0, the Exif IFD, the GPS IFD) in a JPEG's APP1 "Exif", a PNG's eXIf chunk, a WebP's
 *   EXIF chunk or a TIFF file; written big-endian.
 * - IPTC: IPTC-IIM record 2 in a Photoshop image resource 0x0404 (a JPEG's APP13); written as UTF-8.
 * - XMP: the packet of a JPEG's APP1 (http://ns.adobe.com/xap/1.0/), a PNG's iTXt / tEXt XML:com.adobe.xmp or a WebP's
 *   "XMP " chunk; the CGImageMetadata model (ImageIOXMP.m) reads and writes it.
 * Values follow ImageIO: rationals as numbers, GPS coordinates in degrees with their references, versions and ISO
 * ratings as arrays, dates as EXIF strings. */
#import <Foundation/Foundation.h>
#include <ImageIO/ImageIO.h>
#include <math.h>
#import "ImageIOPrivate.h"

#define S(k) ((__bridge NSString *)(k))

/* ---------------- the tags ---------------- */
enum { IFD0, IFDX, IFDG };
typedef struct { int ifd; uint16_t tag; int kind; const CFStringRef *key; const char *xmp; } tagdef;
#define T(ifd, tag, kind, key, xmp) { ifd, tag, kind, &key, xmp }
static const tagdef TAGS[] = {
    T(IFD0, 0x010D, T_ASCII, kCGImagePropertyTIFFDocumentName, "tiff:DocumentName"),
    T(IFD0, 0x010E, T_ASCII, kCGImagePropertyTIFFImageDescription, "tiff:ImageDescription"),
    T(IFD0, 0x010F, T_ASCII, kCGImagePropertyTIFFMake, "tiff:Make"),
    T(IFD0, 0x0110, T_ASCII, kCGImagePropertyTIFFModel, "tiff:Model"),
    T(IFD0, 0x0112, T_SHORT, kCGImagePropertyTIFFOrientation, "tiff:Orientation"),
    T(IFD0, 0x011A, T_RAT, kCGImagePropertyTIFFXResolution, "tiff:XResolution"),
    T(IFD0, 0x011B, T_RAT, kCGImagePropertyTIFFYResolution, "tiff:YResolution"),
    T(IFD0, 0x0128, T_SHORT, kCGImagePropertyTIFFResolutionUnit, "tiff:ResolutionUnit"),
    T(IFD0, 0x0131, T_ASCII, kCGImagePropertyTIFFSoftware, "tiff:Software"),
    T(IFD0, 0x0132, T_ASCII, kCGImagePropertyTIFFDateTime, "tiff:DateTime"),
    T(IFD0, 0x013B, T_ASCII, kCGImagePropertyTIFFArtist, "tiff:Artist"),
    T(IFD0, 0x013C, T_ASCII, kCGImagePropertyTIFFHostComputer, "tiff:HostComputer"),
    T(IFD0, 0x8298, T_ASCII, kCGImagePropertyTIFFCopyright, "tiff:Copyright"),
    T(IFDX, 0x829A, T_RAT, kCGImagePropertyExifExposureTime, "exif:ExposureTime"),
    T(IFDX, 0x829D, T_RAT, kCGImagePropertyExifFNumber, "exif:FNumber"),
    T(IFDX, 0x8822, T_SHORT, kCGImagePropertyExifExposureProgram, "exif:ExposureProgram"),
    T(IFDX, 0x8824, T_ASCII, kCGImagePropertyExifSpectralSensitivity, "exif:SpectralSensitivity"),
    T(IFDX, 0x8827, T_SHORTS, kCGImagePropertyExifISOSpeedRatings, "exif:ISOSpeedRatings"),
    T(IFDX, 0x8830, T_SHORT, kCGImagePropertyExifSensitivityType, "exifEX:SensitivityType"),
    T(IFDX, 0x9000, T_VERSION, kCGImagePropertyExifVersion, "exif:ExifVersion"),
    T(IFDX, 0x9003, T_ASCII, kCGImagePropertyExifDateTimeOriginal, "exif:DateTimeOriginal"),
    T(IFDX, 0x9004, T_ASCII, kCGImagePropertyExifDateTimeDigitized, "exif:DateTimeDigitized"),
    T(IFDX, 0x9010, T_ASCII, kCGImagePropertyExifOffsetTime, "exifEX:OffsetTime"),
    T(IFDX, 0x9011, T_ASCII, kCGImagePropertyExifOffsetTimeOriginal, "exifEX:OffsetTimeOriginal"),
    T(IFDX, 0x9012, T_ASCII, kCGImagePropertyExifOffsetTimeDigitized, "exifEX:OffsetTimeDigitized"),
    T(IFDX, 0x9201, T_SRAT, kCGImagePropertyExifShutterSpeedValue, "exif:ShutterSpeedValue"),
    T(IFDX, 0x9202, T_RAT, kCGImagePropertyExifApertureValue, "exif:ApertureValue"),
    T(IFDX, 0x9203, T_SRAT, kCGImagePropertyExifBrightnessValue, "exif:BrightnessValue"),
    T(IFDX, 0x9204, T_SRAT, kCGImagePropertyExifExposureBiasValue, "exif:ExposureBiasValue"),
    T(IFDX, 0x9205, T_RAT, kCGImagePropertyExifMaxApertureValue, "exif:MaxApertureValue"),
    T(IFDX, 0x9206, T_RAT, kCGImagePropertyExifSubjectDistance, "exif:SubjectDistance"),
    T(IFDX, 0x9207, T_SHORT, kCGImagePropertyExifMeteringMode, "exif:MeteringMode"),
    T(IFDX, 0x9208, T_SHORT, kCGImagePropertyExifLightSource, "exif:LightSource"),
    T(IFDX, 0x9209, T_SHORT, kCGImagePropertyExifFlash, "exif:Flash"),
    T(IFDX, 0x920A, T_RAT, kCGImagePropertyExifFocalLength, "exif:FocalLength"),
    T(IFDX, 0x9214, T_SHORTS, kCGImagePropertyExifSubjectArea, "exif:SubjectArea"),
    T(IFDX, 0x9286, T_COMMENT, kCGImagePropertyExifUserComment, "exif:UserComment"),
    T(IFDX, 0x9290, T_ASCII, kCGImagePropertyExifSubsecTime, NULL),
    T(IFDX, 0x9291, T_ASCII, kCGImagePropertyExifSubsecTimeOrginal, NULL),
    T(IFDX, 0x9292, T_ASCII, kCGImagePropertyExifSubsecTimeDigitized, NULL),
    T(IFDX, 0xA000, T_VERSION, kCGImagePropertyExifFlashPixVersion, "exif:FlashpixVersion"),
    T(IFDX, 0xA001, T_SHORT, kCGImagePropertyExifColorSpace, "exif:ColorSpace"),
    T(IFDX, 0xA002, T_LONG, kCGImagePropertyExifPixelXDimension, "exif:PixelXDimension"),
    T(IFDX, 0xA003, T_LONG, kCGImagePropertyExifPixelYDimension, "exif:PixelYDimension"),
    T(IFDX, 0xA20E, T_RAT, kCGImagePropertyExifFocalPlaneXResolution, "exif:FocalPlaneXResolution"),
    T(IFDX, 0xA20F, T_RAT, kCGImagePropertyExifFocalPlaneYResolution, "exif:FocalPlaneYResolution"),
    T(IFDX, 0xA210, T_SHORT, kCGImagePropertyExifFocalPlaneResolutionUnit, "exif:FocalPlaneResolutionUnit"),
    T(IFDX, 0xA215, T_RAT, kCGImagePropertyExifExposureIndex, "exif:ExposureIndex"),
    T(IFDX, 0xA217, T_SHORT, kCGImagePropertyExifSensingMethod, "exif:SensingMethod"),
    T(IFDX, 0xA300, T_UBYTE, kCGImagePropertyExifFileSource, "exif:FileSource"),
    T(IFDX, 0xA301, T_UBYTE, kCGImagePropertyExifSceneType, "exif:SceneType"),
    T(IFDX, 0xA401, T_SHORT, kCGImagePropertyExifCustomRendered, "exif:CustomRendered"),
    T(IFDX, 0xA402, T_SHORT, kCGImagePropertyExifExposureMode, "exif:ExposureMode"),
    T(IFDX, 0xA403, T_SHORT, kCGImagePropertyExifWhiteBalance, "exif:WhiteBalance"),
    T(IFDX, 0xA404, T_RAT, kCGImagePropertyExifDigitalZoomRatio, "exif:DigitalZoomRatio"),
    T(IFDX, 0xA405, T_SHORT, kCGImagePropertyExifFocalLenIn35mmFilm, "exif:FocalLengthIn35mmFilm"),
    T(IFDX, 0xA406, T_SHORT, kCGImagePropertyExifSceneCaptureType, "exif:SceneCaptureType"),
    T(IFDX, 0xA407, T_SHORT, kCGImagePropertyExifGainControl, "exif:GainControl"),
    T(IFDX, 0xA408, T_SHORT, kCGImagePropertyExifContrast, "exif:Contrast"),
    T(IFDX, 0xA409, T_SHORT, kCGImagePropertyExifSaturation, "exif:Saturation"),
    T(IFDX, 0xA40A, T_SHORT, kCGImagePropertyExifSharpness, "exif:Sharpness"),
    T(IFDX, 0xA40C, T_SHORT, kCGImagePropertyExifSubjectDistRange, "exif:SubjectDistanceRange"),
    T(IFDX, 0xA420, T_ASCII, kCGImagePropertyExifImageUniqueID, "exif:ImageUniqueID"),
    T(IFDX, 0xA430, T_ASCII, kCGImagePropertyExifCameraOwnerName, "exifEX:CameraOwnerName"),
    T(IFDX, 0xA431, T_ASCII, kCGImagePropertyExifBodySerialNumber, "exifEX:BodySerialNumber"),
    T(IFDX, 0xA432, T_RATS, kCGImagePropertyExifLensSpecification, "exifEX:LensSpecification"),
    T(IFDX, 0xA433, T_ASCII, kCGImagePropertyExifLensMake, "exifEX:LensMake"),
    T(IFDX, 0xA434, T_ASCII, kCGImagePropertyExifLensModel, "exifEX:LensModel"),
    T(IFDX, 0xA435, T_ASCII, kCGImagePropertyExifLensSerialNumber, "exifEX:LensSerialNumber"),
    T(IFDX, 0xA460, T_SHORT, kCGImagePropertyExifCompositeImage, "exifEX:CompositeImage"),
    T(IFDX, 0xA500, T_RAT, kCGImagePropertyExifGamma, "exifEX:Gamma"),
    T(IFDG, 0, T_BYTES, kCGImagePropertyGPSVersion, "exif:GPSVersionID"),
    T(IFDG, 1, T_ASCII, kCGImagePropertyGPSLatitudeRef, NULL),
    T(IFDG, 2, T_DEG, kCGImagePropertyGPSLatitude, "exif:GPSLatitude"),
    T(IFDG, 3, T_ASCII, kCGImagePropertyGPSLongitudeRef, NULL),
    T(IFDG, 4, T_DEG, kCGImagePropertyGPSLongitude, "exif:GPSLongitude"),
    T(IFDG, 5, T_BYTE, kCGImagePropertyGPSAltitudeRef, "exif:GPSAltitudeRef"),
    T(IFDG, 6, T_RAT, kCGImagePropertyGPSAltitude, "exif:GPSAltitude"),
    T(IFDG, 7, T_HMS, kCGImagePropertyGPSTimeStamp, "exif:GPSTimeStamp"),
    T(IFDG, 8, T_ASCII, kCGImagePropertyGPSSatellites, "exif:GPSSatellites"),
    T(IFDG, 9, T_ASCII, kCGImagePropertyGPSStatus, "exif:GPSStatus"),
    T(IFDG, 10, T_ASCII, kCGImagePropertyGPSMeasureMode, "exif:GPSMeasureMode"),
    T(IFDG, 11, T_RAT, kCGImagePropertyGPSDOP, "exif:GPSDOP"),
    T(IFDG, 12, T_ASCII, kCGImagePropertyGPSSpeedRef, "exif:GPSSpeedRef"),
    T(IFDG, 13, T_RAT, kCGImagePropertyGPSSpeed, "exif:GPSSpeed"),
    T(IFDG, 14, T_ASCII, kCGImagePropertyGPSTrackRef, "exif:GPSTrackRef"),
    T(IFDG, 15, T_RAT, kCGImagePropertyGPSTrack, "exif:GPSTrack"),
    T(IFDG, 16, T_ASCII, kCGImagePropertyGPSImgDirectionRef, "exif:GPSImgDirectionRef"),
    T(IFDG, 17, T_RAT, kCGImagePropertyGPSImgDirection, "exif:GPSImgDirection"),
    T(IFDG, 18, T_ASCII, kCGImagePropertyGPSMapDatum, "exif:GPSMapDatum"),
    T(IFDG, 19, T_ASCII, kCGImagePropertyGPSDestLatitudeRef, NULL),
    T(IFDG, 20, T_DEG, kCGImagePropertyGPSDestLatitude, "exif:GPSDestLatitude"),
    T(IFDG, 21, T_ASCII, kCGImagePropertyGPSDestLongitudeRef, NULL),
    T(IFDG, 22, T_DEG, kCGImagePropertyGPSDestLongitude, "exif:GPSDestLongitude"),
    T(IFDG, 23, T_ASCII, kCGImagePropertyGPSDestBearingRef, "exif:GPSDestBearingRef"),
    T(IFDG, 24, T_RAT, kCGImagePropertyGPSDestBearing, "exif:GPSDestBearing"),
    T(IFDG, 25, T_ASCII, kCGImagePropertyGPSDestDistanceRef, "exif:GPSDestDistanceRef"),
    T(IFDG, 26, T_RAT, kCGImagePropertyGPSDestDistance, "exif:GPSDestDistance"),
    T(IFDG, 27, T_COMMENT, kCGImagePropertyGPSProcessingMethod, "exif:GPSProcessingMethod"),
    T(IFDG, 28, T_COMMENT, kCGImagePropertyGPSAreaInformation, "exif:GPSAreaInformation"),
    T(IFDG, 29, T_ASCII, kCGImagePropertyGPSDateStamp, NULL),
    T(IFDG, 30, T_SHORT, kCGImagePropertyGPSDifferental, "exif:GPSDifferential"),
    T(IFDG, 31, T_RAT, kCGImagePropertyGPSHPositioningError, "exifEX:GPSHPositioningError"),
};
#define NTAGS (sizeof TAGS / sizeof *TAGS)
static NSString *const DICTS[] = { @"{TIFF}", @"{Exif}", @"{GPS}" };

/* IPTC record 2 datasets; xmp: where XMP keeps the same value (kind: 's' string, 'b' bag, 'q' seq, 'a' alternate text) */
typedef struct { uint8_t ds; BOOL repeat; const CFStringRef *key; const char *xmp; char kind; } iptcdef;
#define I(ds, rep, key, xmp, kind) { ds, rep, &key, xmp, kind }
static const iptcdef IPTC[] = {
    I(4, YES, kCGImagePropertyIPTCObjectAttributeReference, NULL, 0), I(5, NO, kCGImagePropertyIPTCObjectName, "dc:title", 'a'),
    I(7, NO, kCGImagePropertyIPTCEditStatus, NULL, 0), I(10, NO, kCGImagePropertyIPTCUrgency, "photoshop:Urgency", 's'),
    I(12, YES, kCGImagePropertyIPTCSubjectReference, "Iptc4xmpCore:SubjectCode", 'b'), I(15, NO, kCGImagePropertyIPTCCategory, "photoshop:Category", 's'),
    I(20, YES, kCGImagePropertyIPTCSupplementalCategory, "photoshop:SupplementalCategories", 'b'),
    I(22, NO, kCGImagePropertyIPTCFixtureIdentifier, NULL, 0), I(25, YES, kCGImagePropertyIPTCKeywords, "dc:subject", 'b'),
    I(26, YES, kCGImagePropertyIPTCContentLocationCode, NULL, 0), I(27, YES, kCGImagePropertyIPTCContentLocationName, NULL, 0),
    I(30, NO, kCGImagePropertyIPTCReleaseDate, NULL, 0), I(35, NO, kCGImagePropertyIPTCReleaseTime, NULL, 0),
    I(37, NO, kCGImagePropertyIPTCExpirationDate, NULL, 0), I(38, NO, kCGImagePropertyIPTCExpirationTime, NULL, 0),
    I(40, NO, kCGImagePropertyIPTCSpecialInstructions, "photoshop:Instructions", 's'), I(42, NO, kCGImagePropertyIPTCActionAdvised, NULL, 0),
    I(45, YES, kCGImagePropertyIPTCReferenceService, NULL, 0), I(47, YES, kCGImagePropertyIPTCReferenceDate, NULL, 0),
    I(50, YES, kCGImagePropertyIPTCReferenceNumber, NULL, 0), I(55, NO, kCGImagePropertyIPTCDateCreated, "photoshop:DateCreated", 's'),
    I(60, NO, kCGImagePropertyIPTCTimeCreated, NULL, 0), I(62, NO, kCGImagePropertyIPTCDigitalCreationDate, NULL, 0),
    I(63, NO, kCGImagePropertyIPTCDigitalCreationTime, NULL, 0), I(65, NO, kCGImagePropertyIPTCOriginatingProgram, NULL, 0),
    I(70, NO, kCGImagePropertyIPTCProgramVersion, NULL, 0), I(75, NO, kCGImagePropertyIPTCObjectCycle, NULL, 0),
    I(80, YES, kCGImagePropertyIPTCByline, "dc:creator", 'q'), I(85, YES, kCGImagePropertyIPTCBylineTitle, "photoshop:AuthorsPosition", 's'),
    I(90, NO, kCGImagePropertyIPTCCity, "photoshop:City", 's'), I(92, NO, kCGImagePropertyIPTCSubLocation, "Iptc4xmpCore:Location", 's'),
    I(95, NO, kCGImagePropertyIPTCProvinceState, "photoshop:State", 's'),
    I(100, NO, kCGImagePropertyIPTCCountryPrimaryLocationCode, "Iptc4xmpCore:CountryCode", 's'),
    I(101, NO, kCGImagePropertyIPTCCountryPrimaryLocationName, "photoshop:Country", 's'),
    I(103, NO, kCGImagePropertyIPTCOriginalTransmissionReference, "photoshop:TransmissionReference", 's'),
    I(105, NO, kCGImagePropertyIPTCHeadline, "photoshop:Headline", 's'), I(110, NO, kCGImagePropertyIPTCCredit, "photoshop:Credit", 's'),
    I(115, NO, kCGImagePropertyIPTCSource, "photoshop:Source", 's'), I(116, NO, kCGImagePropertyIPTCCopyrightNotice, "dc:rights", 'a'),
    I(118, YES, kCGImagePropertyIPTCContact, NULL, 0), I(120, NO, kCGImagePropertyIPTCCaptionAbstract, "dc:description", 'a'),
    I(122, YES, kCGImagePropertyIPTCWriterEditor, "photoshop:CaptionWriter", 's'), I(130, NO, kCGImagePropertyIPTCImageType, NULL, 0),
    I(131, NO, kCGImagePropertyIPTCImageOrientation, NULL, 0), I(135, NO, kCGImagePropertyIPTCLanguageIdentifier, NULL, 0),
};
#define NIPTC (sizeof IPTC / sizeof *IPTC)

void isim_io_each_mapping(void (^block)(NSString *dict, NSString *key, NSString *xmp, int kind, BOOL iptc)) {
    for (size_t i = 0; i < NTAGS; i++) if (TAGS[i].xmp) block(DICTS[TAGS[i].ifd], S(*TAGS[i].key), @(TAGS[i].xmp), TAGS[i].kind, NO);
    for (size_t i = 0; i < NIPTC; i++) if (IPTC[i].xmp) block(S(kCGImagePropertyIPTCDictionary), S(*IPTC[i].key), @(IPTC[i].xmp), IPTC[i].kind, YES);
}

/* ---------------- reading TIFF IFDs ---------------- */
typedef struct { const uint8_t *p; size_t n; BOOL be; } tiffbuf;
static uint16_t rd16(const tiffbuf *t, size_t o) { if (o + 2 > t->n) return 0; const uint8_t *q = t->p + o; return t->be ? q[0] << 8 | q[1] : q[1] << 8 | q[0]; }
static uint32_t rd32(const tiffbuf *t, size_t o) {
    if (o + 4 > t->n) return 0;
    const uint8_t *q = t->p + o;
    return t->be ? (uint32_t)q[0] << 24 | q[1] << 16 | q[2] << 8 | q[3] : (uint32_t)q[3] << 24 | q[2] << 16 | q[1] << 8 | q[0];
}
static const int TSIZE[] = { 0, 1, 1, 2, 4, 8, 1, 1, 2, 4, 8, 4, 8 };
static const tagdef *find_tag(int ifd, uint16_t tag) { for (size_t i = 0; i < NTAGS; i++) if (TAGS[i].ifd == ifd && TAGS[i].tag == tag) return &TAGS[i]; return NULL; }
static double rational(const tiffbuf *t, size_t o, BOOL sign) {
    uint32_t a = rd32(t, o), b = rd32(t, o + 4);
    if (!b) return 0;
    return sign ? (double)(int32_t)a / (double)(int32_t)b : (double)a / (double)b;
}
static NSString *ascii(const uint8_t *p, size_t n) {
    while (n && (p[n - 1] == 0 || p[n - 1] == ' ')) n--;
    NSString *s = [[NSString alloc] initWithBytes:p length:n encoding:NSUTF8StringEncoding];
    return s ?: [[NSString alloc] initWithBytes:p length:n encoding:NSISOLatin1StringEncoding];
}
static id tag_value(const tiffbuf *t, const tagdef *d, uint16_t type, uint32_t count, size_t vo) {
    size_t unit = type < 13 ? (size_t)TSIZE[type] : 0;
    if (!unit || count > 1 << 20 || vo + unit * count > t->n) return nil;
    const uint8_t *v = t->p + vo;
    double (^num)(uint32_t) = ^double(uint32_t i) {
        switch (type) {
        case 1: case 7: return v[i];
        case 3: return rd16(t, vo + 2 * i);
        case 4: return rd32(t, vo + 4 * i);
        case 8: return (int16_t)rd16(t, vo + 2 * i);
        case 9: return (int32_t)rd32(t, vo + 4 * i);
        case 5: return rational(t, vo + 8 * i, NO);
        case 10: return rational(t, vo + 8 * i, YES);
        default: return 0;
        }
    };
    switch (d->kind) {
    case T_ASCII: return type == 2 || type == 7 ? ascii(v, count) : @(num(0));
    case T_COMMENT: {                                                   /* an 8-byte character code, then the text */
        if (count < 8) return ascii(v, count);
        if (!memcmp(v, "UNICODE\0", 8)) {
            NSString *s = [[NSString alloc] initWithBytes:v + 8 length:(count - 8) & ~1u encoding:t->be ? NSUTF16BigEndianStringEncoding : NSUTF16LittleEndianStringEncoding];
            return [s stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\0 "]];
        }
        return ascii(v + 8, count - 8);
    }
    case T_VERSION: {                                                   /* "0232" -> [2, 3, 2] */
        NSMutableArray *a = [NSMutableArray array];
        for (uint32_t i = 0; i < count; i++) {
            int c = v[i] - '0';
            if (i == 0 && c == 0 && count > 2) continue;
            [a addObject:@(c >= 0 && c <= 9 ? c : v[i])];
        }
        return a;
    }
    case T_BYTES: case T_SHORTS: case T_RATS: {
        NSMutableArray *a = [NSMutableArray array];
        for (uint32_t i = 0; i < count; i++) [a addObject:@(num(i))];
        return a;
    }
    case T_DEG: return count >= 3 ? @(num(0) + num(1) / 60 + num(2) / 3600) : @(num(0));
    case T_HMS: {
        if (count < 3) return nil;
        double s = num(2);
        return s == floor(s) ? [NSString stringWithFormat:@"%02d:%02d:%02d", (int)num(0), (int)num(1), (int)s]
                             : [NSString stringWithFormat:@"%02d:%02d:%05.2f", (int)num(0), (int)num(1), s];
    }
    default: return @(num(0));
    }
}
static void read_ifd(const tiffbuf *t, uint32_t off, int ifd, NSArray<NSMutableDictionary *> *dicts, int depth) {
    if (!off || off + 2 > t->n || depth > 2) return;
    uint16_t n = rd16(t, off);
    for (uint16_t i = 0; i < n; i++) {
        size_t e = off + 2 + 12 * (size_t)i;
        if (e + 12 > t->n) break;
        uint16_t tag = rd16(t, e), type = rd16(t, e + 2);
        uint32_t count = rd32(t, e + 4);
        if (ifd == IFD0 && tag == 0x8769) { read_ifd(t, rd32(t, e + 8), IFDX, dicts, depth + 1); continue; }
        if (ifd == IFD0 && tag == 0x8825) { read_ifd(t, rd32(t, e + 8), IFDG, dicts, depth + 1); continue; }
        const tagdef *d = find_tag(ifd, tag);
        if (!d || type >= 13) continue;
        size_t size = (size_t)TSIZE[type] * count;
        size_t vo = size <= 4 ? e + 8 : rd32(t, e + 8);
        id v = tag_value(t, d, type, count, vo);
        if (v) dicts[ifd][S(*d->key)] = v;
    }
}
/* the {TIFF}, {Exif} and {GPS} dictionaries of a TIFF structure ("II*\0" / "MM\0*") */
static void read_tiff(const uint8_t *p, size_t n, NSMutableDictionary *out) {
    if (n < 8) return;
    tiffbuf t = { p, n, p[0] == 'M' };
    if (!((p[0] == 'I' && p[1] == 'I') || (p[0] == 'M' && p[1] == 'M')) || rd16(&t, 2) != 42) return;
    NSArray<NSMutableDictionary *> *dicts = @[ [NSMutableDictionary dictionary], [NSMutableDictionary dictionary], [NSMutableDictionary dictionary] ];
    read_ifd(&t, rd32(&t, 4), IFD0, dicts, 0);
    for (int i = 0; i < 3; i++) if (dicts[i].count) {
        NSMutableDictionary *have = out[DICTS[i]] ? [out[DICTS[i]] mutableCopy] : [NSMutableDictionary dictionary];
        [have addEntriesFromDictionary:dicts[i]];
        out[DICTS[i]] = have;
    }
}

/* ---------------- reading IPTC ---------------- */
static void read_iim(const uint8_t *p, size_t n, NSMutableDictionary *out) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    BOOL utf8 = NO;
    for (size_t o = 0; o + 5 <= n && p[o] == 0x1C;) {
        uint8_t rec = p[o + 1], ds = p[o + 2];
        size_t len = (size_t)p[o + 3] << 8 | p[o + 4];
        o += 5;
        if (len & 0x8000) break;                                       /* extended lengths: not in IPTC metadata */
        if (o + len > n) break;
        if (rec == 1 && ds == 90 && len >= 3 && !memcmp(p + o, "\x1b%G", 3)) utf8 = YES;
        if (rec == 2) {
            for (size_t i = 0; i < NIPTC; i++) if (IPTC[i].ds == ds) {
                NSString *v = [[NSString alloc] initWithBytes:p + o length:len encoding:NSUTF8StringEncoding];
                if (!v && !utf8) v = [[NSString alloc] initWithBytes:p + o length:len encoding:NSISOLatin1StringEncoding];
                NSString *k = S(*IPTC[i].key);
                if (IPTC[i].repeat) d[k] = [(d[k] ?: @[]) arrayByAddingObject:v ?: @""];
                else d[k] = v ?: @"";
                break;
            }
        }
        o += len;
    }
    if (d.count) out[S(kCGImagePropertyIPTCDictionary)] = d;
}
/* Photoshop image resources ("8BIM"): IPTC is resource 0x0404 */
static void read_8bim(const uint8_t *p, size_t n, NSMutableDictionary *out) {
    for (size_t o = 0; o + 12 <= n && !memcmp(p + o, "8BIM", 4);) {
        uint16_t rid = (uint16_t)(p[o + 4] << 8 | p[o + 5]);
        size_t nl = p[o + 6], name = 1 + nl; name += name & 1;
        size_t so = o + 6 + name;
        if (so + 4 > n) break;
        size_t size = (size_t)p[so] << 24 | (size_t)p[so + 1] << 16 | (size_t)p[so + 2] << 8 | p[so + 3];
        if (so + 4 + size > n) break;
        if (rid == 0x0404) read_iim(p + so + 4, size, out);
        o = so + 4 + size + (size & 1);
    }
}

/* ---------------- containers ---------------- */
static uint32_t be32(const uint8_t *p) { return (uint32_t)p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]; }
static const char XMP_SIG[] = "http://ns.adobe.com/xap/1.0/";
static NSString *xmp_string(const uint8_t *p, size_t n) {
    NSString *s = [[NSString alloc] initWithBytes:p length:n encoding:NSUTF8StringEncoding];
    return s;
}
static NSData *inflate_data(NSData *d) {
    if (@available(iOS 13.0, *)) return [d decompressedDataUsingAlgorithm:NSDataCompressionAlgorithmZlib error:nil];
    return nil;
}
NSDictionary *isim_io_read_metadata(NSData *data, NSString *type, NSString **xmp) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    const uint8_t *p = data.bytes;
    size_t n = data.length;
    if (xmp) *xmp = nil;
    if (n >= 4 && p[0] == 0xFF && p[1] == 0xD8) {                       /* JPEG: the segments before the image data */
        for (size_t o = 2; o + 4 <= n && p[o] == 0xFF;) {
            uint8_t m = p[o + 1];
            if (m == 0xD9 || m == 0xDA) break;
            if (m == 0xFF) { o++; continue; }
            if (m == 0x01 || (m >= 0xD0 && m <= 0xD7)) { o += 2; continue; }
            size_t len = (size_t)p[o + 2] << 8 | p[o + 3];
            if (len < 2 || o + 2 + len > n) break;
            const uint8_t *seg = p + o + 4;
            size_t sl = len - 2;
            if (m == 0xE1 && sl > 6 && !memcmp(seg, "Exif\0\0", 6)) read_tiff(seg + 6, sl - 6, out);
            else if (m == 0xE1 && sl > sizeof XMP_SIG && !memcmp(seg, XMP_SIG, sizeof XMP_SIG) && xmp && !*xmp)
                *xmp = xmp_string(seg + sizeof XMP_SIG, sl - sizeof XMP_SIG);
            else if (m == 0xED && sl > 14 && !memcmp(seg, "Photoshop 3.0\0", 14)) read_8bim(seg + 14, sl - 14, out);
            o += 2 + len;
        }
    } else if (n >= 8 && !memcmp(p, "\x89PNG\r\n\x1a\n", 8)) {          /* PNG: eXIf, iTXt / tEXt XMP */
        for (size_t o = 8; o + 12 <= n;) {
            uint32_t len = be32(p + o);
            const uint8_t *ty = p + o + 4, *c = p + o + 8;
            if (o + 12 + len > n) break;
            if (!memcmp(ty, "eXIf", 4)) read_tiff(c, len, out);
            else if ((!memcmp(ty, "iTXt", 4) || !memcmp(ty, "tEXt", 4)) && len > 18 && !memcmp(c, "XML:com.adobe.xmp", 18) && xmp && !*xmp) {
                if (ty[0] == 't') *xmp = xmp_string(c + 18, len - 18);
                else if (len > 20) {                                    /* keyword\0 flag method lang\0 translated\0 text */
                    BOOL z = c[18];
                    size_t q = 20;
                    while (q < len && c[q]) q++;
                    q++;
                    while (q < len && c[q]) q++;
                    q++;
                    if (q <= len) {
                        NSData *text = [NSData dataWithBytes:c + q length:len - q];
                        if (z) text = inflate_data(text);
                        if (text) *xmp = [[NSString alloc] initWithData:text encoding:NSUTF8StringEncoding];
                    }
                }
            } else if (!memcmp(ty, "IEND", 4)) break;
            o += 12 + len;
        }
    } else if (n >= 12 && !memcmp(p, "RIFF", 4) && !memcmp(p + 8, "WEBP", 4)) {   /* WebP: EXIF, "XMP " */
        for (size_t o = 12; o + 8 <= n;) {
            uint32_t len = p[o + 4] | p[o + 5] << 8 | p[o + 6] << 16 | (uint32_t)p[o + 7] << 24;
            if (o + 8 + len > n) break;
            const uint8_t *c = p + o + 8;
            if (!memcmp(p + o, "EXIF", 4)) { if (len > 6 && !memcmp(c, "Exif\0\0", 6)) read_tiff(c + 6, len - 6, out); else read_tiff(c, len, out); }
            else if (!memcmp(p + o, "XMP ", 4) && xmp && !*xmp) *xmp = xmp_string(c, len);
            o += 8 + len + (len & 1);
        }
    } else if (n >= 8 && ((p[0] == 'I' && p[1] == 'I') || (p[0] == 'M' && p[1] == 'M'))) {
        read_tiff(p, n, out);                                           /* a TIFF file: its IFD0 */
    }
    return out;
}

/* ---------------- writing TIFF IFDs ---------------- */
typedef struct { uint16_t tag, type; uint32_t count; NSData *bytes; } entry;
static void put16(NSMutableData *d, uint16_t v) { uint8_t b[2] = { v >> 8, v & 0xff }; [d appendBytes:b length:2]; }
static void put32(NSMutableData *d, uint32_t v) { uint8_t b[4] = { v >> 24, v >> 16 & 0xff, v >> 8 & 0xff, v & 0xff }; [d appendBytes:b length:4]; }
/* a rational close to v: exact for 1/N and decimals up to four places */
static void ratio(double v, BOOL sign, uint32_t *num, uint32_t *den) {
    double a = fabs(v);
    if (a > 0 && a < 1 && fabs(1 / a - round(1 / a)) < 1e-6) { *num = 1; *den = (uint32_t)round(1 / a); }
    else {
        uint32_t d = 1;
        while (d < 10000 && fabs(a * d - round(a * d)) > 1e-6) d *= 10;
        *num = (uint32_t)fmin(round(a * d), 4294967295.0); *den = d;
    }
    if (sign && v < 0) *num = (uint32_t)(-(int32_t)*num);
}
static NSData *rationals(NSArray *values, BOOL sign) {
    NSMutableData *d = [NSMutableData data];
    for (NSNumber *v in values) { uint32_t a, b; ratio(v.doubleValue, sign, &a, &b); put32(d, a); put32(d, b); }
    return d;
}
static NSArray *as_array(id v) { return [v isKindOfClass:[NSArray class]] ? v : v ? @[ v ] : @[]; }
/* the IFD entry of a property value; NO when it cannot be written */
static BOOL make_entry(const tagdef *d, id v, NSDictionary *dict, entry *e) {
    e->tag = d->tag;
    switch (d->kind) {
    case T_ASCII: {
        NSString *s = [v description];
        NSMutableData *b = [[s dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
        [b appendBytes:"" length:1];
        *e = (entry){ d->tag, 2, (uint32_t)b.length, b };
        return YES;
    }
    case T_COMMENT: {
        NSMutableData *b = [NSMutableData dataWithBytes:"ASCII\0\0\0" length:8];
        [b appendData:[[v description] dataUsingEncoding:NSUTF8StringEncoding]];
        *e = (entry){ d->tag, 7, (uint32_t)b.length, b };
        return YES;
    }
    case T_SHORT: case T_SHORTS: {
        NSArray *a = as_array(v);
        NSMutableData *b = [NSMutableData data];
        for (NSNumber *x in a) put16(b, (uint16_t)x.intValue);
        *e = (entry){ d->tag, 3, (uint32_t)a.count, b };
        return a.count > 0;
    }
    case T_LONG: { NSMutableData *b = [NSMutableData data]; put32(b, (uint32_t)[v unsignedIntValue]); *e = (entry){ d->tag, 4, 1, b }; return YES; }
    case T_RAT: case T_RATS: { NSArray *a = as_array(v); *e = (entry){ d->tag, 5, (uint32_t)a.count, rationals(a, NO) }; return a.count > 0; }
    case T_SRAT: { *e = (entry){ d->tag, 10, 1, rationals(@[ v ], YES) }; return YES; }
    case T_BYTE: case T_UBYTE: { uint8_t b = (uint8_t)[v intValue]; *e = (entry){ d->tag, (uint16_t)(d->kind == T_BYTE ? 1 : 7), 1, [NSData dataWithBytes:&b length:1] }; return YES; }
    case T_BYTES: {
        NSArray *a = as_array(v);
        NSMutableData *b = [NSMutableData data];
        for (NSNumber *x in a) { uint8_t c = (uint8_t)x.intValue; [b appendBytes:&c length:1]; }
        *e = (entry){ d->tag, 1, (uint32_t)a.count, b };
        return a.count > 0;
    }
    case T_VERSION: {                                                   /* [2, 3, 2] -> "0232" */
        NSArray *a = as_array(v);
        NSMutableString *s = [NSMutableString string];
        for (NSNumber *x in a) [s appendFormat:@"%d", x.intValue];
        while (s.length < 4) [s insertString:@"0" atIndex:0];
        NSData *b = [[s substringToIndex:4] dataUsingEncoding:NSASCIIStringEncoding];
        *e = (entry){ d->tag, 7, 4, b };
        return YES;
    }
    case T_DEG: {
        double deg = fabs([v doubleValue]), dd = floor(deg), mm = floor((deg - dd) * 60), ss = ((deg - dd) * 60 - mm) * 60;
        *e = (entry){ d->tag, 5, 3, rationals(@[ @(dd), @(mm), @(round(ss * 10000) / 10000) ], NO) };
        return YES;
    }
    case T_HMS: {
        NSArray *c = [[v description] componentsSeparatedByString:@":"];
        if (c.count < 3) return NO;
        *e = (entry){ d->tag, 5, 3, rationals(@[ @([c[0] doubleValue]), @([c[1] doubleValue]), @([c[2] doubleValue]) ], NO) };
        return YES;
    }
    }
    return NO;
}
static NSInteger cmp_entry(const void *a, const void *b) { return (NSInteger)((const entry *)a)->tag - (NSInteger)((const entry *)b)->tag; }
/* an IFD at `base` (an offset in the TIFF structure): entries sorted by tag, then the values longer than 4 bytes */
static NSData *ifd_bytes(entry *es, size_t n, uint32_t base) {
    qsort(es, n, sizeof *es, (int (*)(const void *, const void *))cmp_entry);
    NSMutableData *ifd = [NSMutableData data], *extra = [NSMutableData data];
    uint32_t data_at = base + 2 + 12 * (uint32_t)n + 4;
    put16(ifd, (uint16_t)n);
    for (size_t i = 0; i < n; i++) {
        put16(ifd, es[i].tag); put16(ifd, es[i].type); put32(ifd, es[i].count);
        if (es[i].bytes.length <= 4) {
            NSMutableData *v = [es[i].bytes mutableCopy];
            [v setLength:4];
            [ifd appendData:v];
        } else {
            put32(ifd, data_at + (uint32_t)extra.length);
            [extra appendData:es[i].bytes];
            if (extra.length & 1) [extra appendBytes:"" length:1];
        }
    }
    put32(ifd, 0);
    [ifd appendData:extra];
    return ifd;
}
static size_t entries_of(NSDictionary *dict, int ifd, entry *out, size_t max) {
    size_t n = 0;
    for (size_t i = 0; i < NTAGS && n < max; i++) {
        if (TAGS[i].ifd != ifd) continue;
        id v = dict[S(*TAGS[i].key)];
        if (v && make_entry(&TAGS[i], v, dict, &out[n])) n++;
    }
    return n;
}
/* the TIFF structure of {TIFF}, {Exif} and {GPS} (big-endian); nil when they are empty */
NSData *isim_io_exif_bytes(NSDictionary *props) {
    NSDictionary *tiff = props[S(kCGImagePropertyTIFFDictionary)], *exif = props[S(kCGImagePropertyExifDictionary)], *gps = props[S(kCGImagePropertyGPSDictionary)];
    NSMutableDictionary *t = [tiff mutableCopy] ?: [NSMutableDictionary dictionary];
    if (props[S(kCGImagePropertyOrientation)]) t[S(kCGImagePropertyTIFFOrientation)] = props[S(kCGImagePropertyOrientation)];
    entry e0[64], ex[128], eg[64];
    size_t n0 = entries_of(t, IFD0, e0, 62), nx = entries_of(exif, IFDX, ex, 128), ng = entries_of(gps, IFDG, eg, 64);
    if (!n0 && !nx && !ng) return nil;
    /* the IFD0 pointers to the Exif and GPS IFDs (their offsets are known once IFD0 is laid out) */
    size_t i_ex = nx ? n0++ : SIZE_MAX, i_gps = ng ? n0++ : SIZE_MAX;
    if (i_ex != SIZE_MAX) e0[i_ex] = (entry){ 0x8769, 4, 1, [NSMutableData dataWithLength:4] };
    if (i_gps != SIZE_MAX) e0[i_gps] = (entry){ 0x8825, 4, 1, [NSMutableData dataWithLength:4] };
    NSData *ifd0 = ifd_bytes(e0, n0, 8);
    uint32_t at_ex = 8 + (uint32_t)ifd0.length;
    NSData *ifdx = nx ? ifd_bytes(ex, nx, at_ex) : [NSData data];
    uint32_t at_gps = at_ex + (uint32_t)ifdx.length;
    NSData *ifdg = ng ? ifd_bytes(eg, ng, at_gps) : [NSData data];
    /* now the pointers */
    for (size_t i = 0; i < n0; i++) {
        NSMutableData *b = [NSMutableData data];
        if (e0[i].tag == 0x8769) { put32(b, at_ex); e0[i].bytes = b; }
        if (e0[i].tag == 0x8825) { put32(b, at_gps); e0[i].bytes = b; }
    }
    ifd0 = ifd_bytes(e0, n0, 8);
    NSMutableData *out = [NSMutableData dataWithBytes:"MM\0*\0\0\0\x08" length:8];
    [out appendData:ifd0]; [out appendData:ifdx]; [out appendData:ifdg];
    return out;
}
/* the Photoshop resource block with the IPTC record of {IPTC}; nil when it is empty */
NSData *isim_io_iptc_bytes(NSDictionary *props) {
    NSDictionary *d = props[S(kCGImagePropertyIPTCDictionary)];
    if (!d.count) return nil;
    NSMutableData *iim = [NSMutableData dataWithBytes:"\x1c\x01\x5a\x00\x03\x1b%G\x1c\x02\x00\x00\x02\x00\x04" length:15];
    for (size_t i = 0; i < NIPTC; i++) {
        id v = d[S(*IPTC[i].key)];
        for (id x in as_array(v)) {
            NSData *b = [[x description] dataUsingEncoding:NSUTF8StringEncoding];
            if (b.length > 32767) continue;
            uint8_t h[5] = { 0x1c, 2, IPTC[i].ds, (uint8_t)(b.length >> 8), (uint8_t)b.length };
            [iim appendBytes:h length:5];
            [iim appendData:b];
            if (!IPTC[i].repeat) break;
        }
    }
    NSMutableData *out = [NSMutableData dataWithBytes:"8BIM\x04\x04\0\0" length:8];
    put32(out, (uint32_t)iim.length);
    [out appendData:iim];
    if (iim.length & 1) [out appendBytes:"" length:1];
    return out;
}

/* ---------------- writing containers ---------------- */
static void put_segment(NSMutableData *out, uint8_t marker, const void *sig, size_t siglen, NSData *body) {
    size_t len = 2 + siglen + body.length;
    if (len > 65535) return;                                            /* too big for one segment: left out */
    uint8_t h[4] = { 0xFF, marker, (uint8_t)(len >> 8), (uint8_t)len };
    [out appendBytes:h length:4];
    if (siglen) [out appendBytes:sig length:siglen];
    [out appendData:body];
}
static uint32_t crc32_of(const uint8_t *p, size_t n, uint32_t c) {
    static uint32_t table[256];
    if (!table[1]) for (uint32_t i = 0; i < 256; i++) { uint32_t k = i; for (int j = 0; j < 8; j++) k = k & 1 ? 0xEDB88320u ^ (k >> 1) : k >> 1; table[i] = k; }
    c ^= 0xFFFFFFFFu;
    for (size_t i = 0; i < n; i++) c = table[(c ^ p[i]) & 0xff] ^ (c >> 8);
    return c ^ 0xFFFFFFFFu;
}
static void put_chunk(NSMutableData *out, const char *type, NSData *body) {
    put32(out, (uint32_t)body.length);
    NSMutableData *tb = [NSMutableData dataWithBytes:type length:4];
    [tb appendData:body];
    [out appendData:tb];
    put32(out, crc32_of(tb.bytes, tb.length, 0));
}
/* encoded JPEG or PNG bytes with their metadata replaced: EXIF / TIFF / GPS and IPTC of props, the XMP packet */
NSData *isim_io_embed_metadata(NSData *encoded, NSDictionary *props, NSString *xmp) {
    const uint8_t *p = encoded.bytes;
    size_t n = encoded.length;
    NSData *exif = isim_io_exif_bytes(props), *iptc = isim_io_iptc_bytes(props), *x = [xmp dataUsingEncoding:NSUTF8StringEncoding];
    if (n >= 4 && p[0] == 0xFF && p[1] == 0xD8) {
        NSMutableData *out = [NSMutableData dataWithBytes:p length:2];
        size_t o = 2;
        BOOL inserted = NO;
        while (o + 4 <= n && p[o] == 0xFF) {
            uint8_t m = p[o + 1];
            if (m == 0xDA || m == 0xD9) break;
            size_t len = (size_t)p[o + 2] << 8 | p[o + 3];
            if (len < 2 || o + 2 + len > n) break;
            if (m != 0xE0 && !inserted) {                               /* after JFIF's APP0 */
                if (exif) put_segment(out, 0xE1, "Exif\0\0", 6, exif);
                if (x.length) put_segment(out, 0xE1, XMP_SIG, sizeof XMP_SIG, x);
                if (iptc) put_segment(out, 0xED, "Photoshop 3.0\0", 14, iptc);
                inserted = YES;
            }
            BOOL old = (m == 0xE1 && len > 8 && (!memcmp(p + o + 4, "Exif\0\0", 6) || (len - 2 > sizeof XMP_SIG && !memcmp(p + o + 4, XMP_SIG, sizeof XMP_SIG)))) ||
                       (m == 0xED && len > 16 && !memcmp(p + o + 4, "Photoshop 3.0\0", 14));
            if (!old) [out appendBytes:p + o length:2 + len];
            o += 2 + len;
        }
        if (!inserted) {
            if (exif) put_segment(out, 0xE1, "Exif\0\0", 6, exif);
            if (x.length) put_segment(out, 0xE1, XMP_SIG, sizeof XMP_SIG, x);
            if (iptc) put_segment(out, 0xED, "Photoshop 3.0\0", 14, iptc);
        }
        [out appendBytes:p + o length:n - o];
        return out;
    }
    if (n >= 8 && !memcmp(p, "\x89PNG\r\n\x1a\n", 8)) {
        NSMutableData *out = [NSMutableData dataWithBytes:p length:8];
        for (size_t o = 8; o + 12 <= n;) {
            uint32_t len = be32(p + o);
            if (o + 12 + len > n) break;
            const uint8_t *ty = p + o + 4;
            BOOL old = !memcmp(ty, "eXIf", 4) || ((!memcmp(ty, "iTXt", 4) || !memcmp(ty, "tEXt", 4)) && len > 18 && !memcmp(p + o + 8, "XML:com.adobe.xmp", 18));
            if (!old) [out appendBytes:p + o length:12 + len];
            if (!memcmp(ty, "IHDR", 4)) {                               /* metadata before the image data */
                if (exif) put_chunk(out, "eXIf", exif);
                if (x.length) {
                    NSMutableData *it = [NSMutableData dataWithBytes:"XML:com.adobe.xmp\0\0\0\0\0" length:22];
                    [it appendData:x];
                    put_chunk(out, "iTXt", it);
                }
            }
            o += 12 + len;
        }
        return out;
    }
    return encoded;
}
