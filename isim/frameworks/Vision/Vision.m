// isim Vision for Objective-C (issue #537): the C side of the Swift overlay's classes — the string constants, VNUtils.h's
// functions, Apple's class factories and the CMTimeRange of an observation (the overlay has it as a Swift struct).
#import <Vision/Vision.h>
// the factories and timeRange are declared in the classes' @interfaces (Apple's headers) and implemented here
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

NSString * const VNErrorDomain = @"com.apple.Vision";

#define SYMBOLOGY(n) VNBarcodeSymbology const VNBarcodeSymbology##n = @"VNBarcodeSymbology" #n;
SYMBOLOGY(Aztec) SYMBOLOGY(Code39) SYMBOLOGY(Code39Checksum) SYMBOLOGY(Code39FullASCII) SYMBOLOGY(Code39FullASCIIChecksum)
SYMBOLOGY(Code93) SYMBOLOGY(Code93i) SYMBOLOGY(Code128) SYMBOLOGY(DataMatrix) SYMBOLOGY(EAN8) SYMBOLOGY(EAN13) SYMBOLOGY(I2of5)
SYMBOLOGY(I2of5Checksum) SYMBOLOGY(ITF14) SYMBOLOGY(PDF417) SYMBOLOGY(QR) SYMBOLOGY(UPCE) SYMBOLOGY(Codabar) SYMBOLOGY(GS1DataBar)
SYMBOLOGY(GS1DataBarExpanded) SYMBOLOGY(GS1DataBarLimited) SYMBOLOGY(MicroPDF417) SYMBOLOGY(MicroQR) SYMBOLOGY(MSIPlessey)
#undef SYMBOLOGY

VNImageOption const VNImageOptionProperties = @"VNImageOptionProperties";
VNImageOption const VNImageOptionCameraIntrinsics = @"VNImageOptionCameraIntrinsics";
VNImageOption const VNImageOptionCIContext = @"VNImageOptionCIContext";

// MARK: - VNUtils.h (normalized coordinates: lower-left origin, relative to the image or to a region of interest)

const CGRect VNNormalizedIdentityRect = { { 0, 0 }, { 1, 1 } };
bool VNNormalizedRectIsIdentityRect(CGRect r) { return CGRectEqualToRect(r, VNNormalizedIdentityRect); }

CGPoint VNImagePointForNormalizedPoint(CGPoint p, size_t w, size_t h) { return CGPointMake(p.x * w, p.y * h); }
CGPoint VNNormalizedPointForImagePoint(CGPoint p, size_t w, size_t h) { return CGPointMake(w ? p.x / w : 0, h ? p.y / h : 0); }
CGPoint VNImagePointForNormalizedPointUsingRegionOfInterest(CGPoint p, size_t w, size_t h, CGRect roi) {
    return CGPointMake((roi.origin.x + p.x * roi.size.width) * w, (roi.origin.y + p.y * roi.size.height) * h);
}
CGPoint VNNormalizedPointForImagePointUsingRegionOfInterest(CGPoint p, size_t w, size_t h, CGRect roi) {
    CGPoint n = VNNormalizedPointForImagePoint(p, w, h);
    return CGPointMake(roi.size.width ? (n.x - roi.origin.x) / roi.size.width : 0, roi.size.height ? (n.y - roi.origin.y) / roi.size.height : 0);
}
CGRect VNImageRectForNormalizedRect(CGRect r, size_t w, size_t h) {
    return CGRectMake(r.origin.x * w, r.origin.y * h, r.size.width * w, r.size.height * h);
}
CGRect VNNormalizedRectForImageRect(CGRect r, size_t w, size_t h) {
    return CGRectMake(w ? r.origin.x / w : 0, h ? r.origin.y / h : 0, w ? r.size.width / w : 0, h ? r.size.height / h : 0);
}
CGRect VNImageRectForNormalizedRectUsingRegionOfInterest(CGRect r, size_t w, size_t h, CGRect roi) {
    CGRect inImage = CGRectMake(roi.origin.x + r.origin.x * roi.size.width, roi.origin.y + r.origin.y * roi.size.height,
                                r.size.width * roi.size.width, r.size.height * roi.size.height);
    return VNImageRectForNormalizedRect(inImage, w, h);
}
CGRect VNNormalizedRectForImageRectUsingRegionOfInterest(CGRect r, size_t w, size_t h, CGRect roi) {
    CGRect n = VNNormalizedRectForImageRect(r, w, h);
    if (roi.size.width == 0 || roi.size.height == 0) return CGRectZero;
    return CGRectMake((n.origin.x - roi.origin.x) / roi.size.width, (n.origin.y - roi.origin.y) / roi.size.height,
                      n.size.width / roi.size.width, n.size.height / roi.size.height);
}
CGPoint VNImagePointForFaceLandmarkPoint(vector_float2 p, CGRect box, size_t w, size_t h) {
    return CGPointMake((box.origin.x + p.x * box.size.width) * w, (box.origin.y + p.y * box.size.height) * h);
}
size_t VNElementTypeSize(VNElementType t) { return t == VNElementTypeFloat ? sizeof(float) : t == VNElementTypeDouble ? sizeof(double) : 0; }

// MARK: - class factories (Apple's; the overlay has the initializers)

@interface VNDetectedObjectObservation (ISIMInit)
- (instancetype)initWithBoundingBox:(CGRect)boundingBox;
@end
@implementation VNDetectedObjectObservation (ISIMFactories)
+ (instancetype)observationWithBoundingBox:(CGRect)boundingBox { return [[self alloc] initWithBoundingBox:boundingBox]; }
+ (instancetype)observationWithRequestRevision:(NSUInteger)requestRevision boundingBox:(CGRect)boundingBox {
    return [[self alloc] initWithBoundingBox:boundingBox];
}
@end

@interface VNFaceObservation (ISIMInit)
- (instancetype)initWithRequestRevision:(NSInteger)requestRevision boundingBox:(CGRect)boundingBox roll:(NSNumber *)roll yaw:(NSNumber *)yaw pitch:(NSNumber *)pitch;
@end
@implementation VNFaceObservation (ISIMFactories)
+ (instancetype)faceObservationWithRequestRevision:(NSUInteger)requestRevision boundingBox:(CGRect)boundingBox roll:(NSNumber *)roll yaw:(NSNumber *)yaw {
    return [[self alloc] initWithRequestRevision:(NSInteger)requestRevision boundingBox:boundingBox roll:roll yaw:yaw pitch:nil];
}
+ (instancetype)faceObservationWithRequestRevision:(NSUInteger)requestRevision boundingBox:(CGRect)boundingBox roll:(NSNumber *)roll
                                               yaw:(NSNumber *)yaw pitch:(NSNumber *)pitch {
    return [[self alloc] initWithRequestRevision:(NSInteger)requestRevision boundingBox:boundingBox roll:roll yaw:yaw pitch:pitch];
}
@end

// MARK: - CMTimeRange

@interface VNObservation (ISIMTime)
- (NSArray<NSNumber *> *)_isim_timeRange;
@end
@implementation VNObservation (ISIMStructs)
- (CMTimeRange)timeRange {
    NSArray<NSNumber *> *v = [self _isim_timeRange];
    if (v.count < 8) return (CMTimeRange){ { 0, 0, 0, 0 }, { 0, 0, 0, 0 } };
    return (CMTimeRange){ { v[0].longLongValue, v[1].intValue, v[2].unsignedIntValue, v[3].longLongValue },
                          { v[4].longLongValue, v[5].intValue, v[6].unsignedIntValue, v[7].longLongValue } };
}
@end

// MARK: - CMTime and matrix_float3x3 of the tracking and registration classes (issue #373)

@interface VNStatefulRequest (ISIMSpacing)
- (instancetype)_isim_initWithSpacing:(NSArray<NSNumber *> *)spacing completionHandler:(VNRequestCompletionHandler)completionHandler;
- (NSArray<NSNumber *> *)_isim_frameAnalysisSpacing;
@end
@implementation VNStatefulRequest (ISIMStructs)
- (instancetype)initWithFrameAnalysisSpacing:(CMTime)t completionHandler:(VNRequestCompletionHandler)completionHandler {
    return [self _isim_initWithSpacing:@[ @(t.value), @(t.timescale), @(t.flags), @(t.epoch) ] completionHandler:completionHandler];
}
- (CMTime)frameAnalysisSpacing {
    NSArray<NSNumber *> *v = [self _isim_frameAnalysisSpacing];
    if (v.count < 4) return (CMTime){ 0, 0, 0, 0 };
    return (CMTime){ v[0].longLongValue, v[1].intValue, v[2].unsignedIntValue, v[3].longLongValue };
}
@end

@interface VNImageHomographicAlignmentObservation (ISIMWarp)
- (NSArray<NSNumber *> *)_isim_warpTransform;
@end
@implementation VNImageHomographicAlignmentObservation (ISIMStructs)
- (matrix_float3x3)warpTransform {
    NSArray<NSNumber *> *v = [self _isim_warpTransform];
    matrix_float3x3 m;
    for (int c = 0; c < 3; c++)
        for (int r = 0; r < 3; r++) m.columns[c][r] = v.count == 9 ? v[c * 3 + r].floatValue : (c == r);
    return m;
}
@end
