// Sample: Vision from Objective-C (issue #537) — #import <Vision/Vision.h>, -framework Vision. The requests isim runs, on
// the pictures HelloVision uses (QR codes, text, NASA's astronaut portrait, made by the build) and on shapes, a horizon
// and a red disk drawn here: barcodes (region of interest, orientation, symbologies), text recognition, faces and
// landmarks, rectangles, text rectangles, contours, the horizon, saliency, VNSequenceRequestHandler, an unsupported
// request's error, Apple's class factories and VNUtils.h; VisionKit's document camera from Objective-C (issue #379). Each
// result is logged ("HelloVisionObjC: ...").
#import <UIKit/UIKit.h>
#import <Vision/Vision.h>
#import <VisionKit/VisionKit.h>
#import <CoreVideo/CoreVideo.h>

static void say(NSString *s) { NSLog(@"HelloVisionObjC: %@", s); }
static NSString *f2(double x) { return [NSString stringWithFormat:@"%.2f", x]; }
static NSString *rect(CGRect r) { return [NSString stringWithFormat:@"%@,%@,%@,%@", f2(r.origin.x), f2(r.origin.y), f2(r.size.width), f2(r.size.height)]; }
static NSString *message(NSError *e) { return e.userInfo[NSLocalizedDescriptionKey] ?: e.description; }
static NSURL *resource(NSString *name) { return [NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:name]; }

/// a picture drawn with UIKit (top-left origin, 1 pixel per point)
static CGImageRef render(CGFloat w, CGFloat h, void (^draw)(CGContextRef c)) {
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = 1;
    UIImage *img = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(w, h) format:fmt] imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        draw(ctx.CGContext);
    }];
    return CGImageRetain(img.CGImage);
}

@interface VisionViewController : UIViewController
@end

@implementation VisionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 64, 340, 41)];
    title.text = @"Vision ObjC";
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [self.view addSubview:title];
}

/* VisionKit's document camera (issue #379): supported only with a camera (ISIM_CAMERA) */
- (void)documentCamera {
    VNDocumentCameraViewController *c = [[VNDocumentCameraViewController alloc] init];
    c.delegate = (id<VNDocumentCameraViewControllerDelegate>)self;
    say([NSString stringWithFormat:@"documentcamera supported=%d delegate=%d", VNDocumentCameraViewController.isSupported, c.delegate == (id)self]);
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self barcodes];
    [self text];
    [self faces];
    [self detectors];
    [self others];
    [self tracking];
    [self models];
    [self documentCamera];
    say(@"done");
}

- (void)barcodes {
    UIImage *img = [UIImage imageWithContentsOfFile:resource(@"codes.png").path];
    if (!img.CGImage) { say(@"barcodes: no test picture (needs qrencode at build time)"); return; }
    say([NSString stringWithFormat:@"barcode symbologies qr=%d", [[[[VNDetectBarcodesRequest alloc] init] supportedSymbologiesAndReturnError:nil] containsObject:VNBarcodeSymbologyQR]]);
    VNDetectBarcodesRequest *all = [[VNDetectBarcodesRequest alloc] initWithCompletionHandler:^(VNRequest *req, NSError *err) {
        NSArray<VNBarcodeObservation *> *found = [(NSArray<VNBarcodeObservation *> *)req.results sortedArrayUsingComparator:^NSComparisonResult(VNBarcodeObservation *a, VNBarcodeObservation *b) {
            return a.boundingBox.origin.x < b.boundingBox.origin.x ? NSOrderedAscending : NSOrderedDescending;
        }];
        NSMutableArray *parts = [NSMutableArray array];
        for (VNBarcodeObservation *o in found)
            [parts addObject:[NSString stringWithFormat:@"%@ '%@' box=%@", [o.symbology isEqualToString:VNBarcodeSymbologyQR] ? @"qr" : o.symbology,
                              o.payloadStringValue ?: @"", rect(o.boundingBox)]];
        say([NSString stringWithFormat:@"barcodes %lu: %@", (unsigned long)found.count, [parts componentsJoinedByString:@"; "]]);
    }];
    NSError *err = nil;
    if (![[[VNImageRequestHandler alloc] initWithCGImage:img.CGImage options:@{}] performRequests:@[all] error:&err])
        say([NSString stringWithFormat:@"barcodes error %@", message(err)]);
    // region of interest: the right half only; then the picture rotated (orientation); then EAN-13 only
    VNDetectBarcodesRequest *right = [[VNDetectBarcodesRequest alloc] init];
    right.regionOfInterest = CGRectMake(0.5, 0, 0.5, 1);
    right.symbologies = @[VNBarcodeSymbologyQR];
    [[[VNImageRequestHandler alloc] initWithCGImage:img.CGImage options:@{}] performRequests:@[right] error:nil];
    NSMutableArray *payloads = [NSMutableArray array];
    for (VNBarcodeObservation *o in right.results) [payloads addObject:o.payloadStringValue ?: @""];
    say([NSString stringWithFormat:@"roi barcodes [%@]", [payloads componentsJoinedByString:@","]]);
    VNDetectBarcodesRequest *rotated = [[VNDetectBarcodesRequest alloc] init];
    [[[VNImageRequestHandler alloc] initWithCGImage:img.CGImage orientation:kCGImagePropertyOrientationRight options:@{}] performRequests:@[rotated] error:nil];
    say([NSString stringWithFormat:@"rotated barcodes %lu", (unsigned long)rotated.results.count]);
    VNDetectBarcodesRequest *ean = [[VNDetectBarcodesRequest alloc] init];
    ean.symbologies = @[VNBarcodeSymbologyEAN13];
    [[[VNImageRequestHandler alloc] initWithCGImage:img.CGImage options:@{}] performRequests:@[ean] error:nil];
    say([NSString stringWithFormat:@"ean13 only %lu symbologies %@", (unsigned long)ean.results.count, ean.symbologies.firstObject]);
}

- (void)text {
    NSData *data = [NSData dataWithContentsOfURL:resource(@"text.png")];
    if (!data) { say(@"text: no test picture"); return; }
    VNRecognizeTextRequest *req = [[VNRecognizeTextRequest alloc] init];
    req.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
    req.recognitionLanguages = @[@"en-US"];
    NSError *err = nil;
    if ([[[VNImageRequestHandler alloc] initWithData:data options:@{}] performRequests:@[req] error:&err]) {
        NSMutableArray *lines = [NSMutableArray array];
        VNRectangleObservation *firstWord = nil;
        for (VNRecognizedTextObservation *o in req.results) {
            VNRecognizedText *t = [o topCandidates:1].firstObject;
            if (!t) continue;
            [lines addObject:t.string];
            if (!firstWord) firstWord = [t boundingBoxForRange:NSMakeRange(0, 5) error:nil];
        }
        say([NSString stringWithFormat:@"text recognized [%@] first word box %@", [lines componentsJoinedByString:@","],
             firstWord ? @"yes" : @"no"]);
    } else {
        say([NSString stringWithFormat:@"text unavailable: %@ (code %ld)", message(err), (long)err.code]);
    }
}

/// faces and landmarks in NASA's astronaut portrait (face.jpg, also HelloVision's)
- (void)faces {
    UIImage *img = [UIImage imageWithContentsOfFile:resource(@"face.jpg").path];
    if (!img.CGImage) { say(@"faces: no test picture"); return; }
    VNDetectFaceRectanglesRequest *req = [[VNDetectFaceRectanglesRequest alloc] initWithCompletionHandler:^(VNRequest *r, NSError *e) {
        say([NSString stringWithFormat:@"face completion error=%@", e ? message(e) : @"none"]);
    }];
    VNDetectFaceLandmarksRequest *marks = [[VNDetectFaceLandmarksRequest alloc] init];
    NSError *err = nil;
    if (![[[VNImageRequestHandler alloc] initWithCGImage:img.CGImage options:@{}] performRequests:@[req, marks] error:&err]) {
        say([NSString stringWithFormat:@"faces error %@ %ld", err.domain, (long)err.code]);
        return;
    }
    VNFaceObservation *face = req.results.firstObject;
    say([NSString stringWithFormat:@"faces %lu box=%@ roll=%@", (unsigned long)req.results.count, face ? rect(face.boundingBox) : @"-",
         face.roll ? f2(face.roll.doubleValue) : @"nil"]);
    VNFaceLandmarks2D *lm = marks.results.firstObject.landmarks;
    if (lm.leftPupil.pointCount && lm.rightPupil.pointCount && lm.outerLips.pointCount) {
        const CGPoint *le = lm.leftPupil.normalizedPoints, *re = lm.rightPupil.normalizedPoints, *lips = lm.outerLips.normalizedPoints;
        CGFloat mouthY = 0;
        for (NSUInteger i = 0; i < lm.outerLips.pointCount; i++) mouthY += lips[i].y;
        mouthY /= lm.outerLips.pointCount;
        CGSize size = CGSizeMake(CGImageGetWidth(img.CGImage), CGImageGetHeight(img.CGImage));
        const CGPoint *inImage = [lm.leftPupil pointsInImageOfSize:size];
        CGRect box = marks.results.firstObject.boundingBox;
        BOOL inside = inImage[0].x >= box.origin.x * size.width && inImage[0].x <= CGRectGetMaxX(box) * size.width;
        say([NSString stringWithFormat:@"landmarks pupils %@,%@ %@,%@ mouth below eyes %@ contour %lu closed %@ in image %@",
             f2(le[0].x), f2(le[0].y), f2(re[0].x), f2(re[0].y), mouthY < MIN(le[0].y, re[0].y) ? @"true" : @"false",
             (unsigned long)lm.faceContour.pointCount, lm.leftEye.pointsClassification == VNPointsClassificationClosedPath ? @"true" : @"false",
             inside ? @"true" : @"false"]);
    }
}

- (void)detectors {
    /* shapes: a 160x100 rectangle, an 80 pt square turned 20 degrees, and a ring around a dot (HelloVision's) */
    CGImageRef shapes = render(400, 300, ^(CGContextRef c) {
        CGContextSetFillColorWithColor(c, UIColor.whiteColor.CGColor); CGContextFillRect(c, CGRectMake(0, 0, 400, 300));
        CGContextSetFillColorWithColor(c, UIColor.blackColor.CGColor); CGContextFillRect(c, CGRectMake(40, 40, 160, 100));
        CGContextSaveGState(c); CGContextTranslateCTM(c, 300, 200); CGContextRotateCTM(c, 20 * M_PI / 180);
        CGContextFillRect(c, CGRectMake(-40, -40, 80, 80)); CGContextRestoreGState(c);
        CGContextFillEllipseInRect(c, CGRectMake(55, 185, 90, 90));
        CGContextSetFillColorWithColor(c, UIColor.whiteColor.CGColor); CGContextFillEllipseInRect(c, CGRectMake(75, 205, 50, 50));
        CGContextSetFillColorWithColor(c, UIColor.blackColor.CGColor); CGContextFillEllipseInRect(c, CGRectMake(92, 222, 16, 16));
    });
    VNDetectRectanglesRequest *rects = [[VNDetectRectanglesRequest alloc] init];
    rects.maximumObservations = 0; rects.minimumAspectRatio = 0.3; rects.minimumSize = 0.1;
    VNDetectContoursRequest *contours = [[VNDetectContoursRequest alloc] init];
    NSError *err = nil;
    if ([[[VNImageRequestHandler alloc] initWithCGImage:shapes options:@{}] performRequests:@[rects, contours] error:&err]) {
        NSMutableArray *boxes = [NSMutableArray array];
        for (VNRectangleObservation *r in rects.results) [boxes addObject:rect(r.boundingBox)];
        VNRectangleObservation *first = rects.results.firstObject;
        say([NSString stringWithFormat:@"rectangles %lu: %@ first topLeft %@,%@ bottomRight %@,%@", (unsigned long)rects.results.count,
             [boxes componentsJoinedByString:@"; "], f2(first.topLeft.x), f2(first.topLeft.y), f2(first.bottomRight.x), f2(first.bottomRight.y)]);
        VNContoursObservation *obs = contours.results.firstObject;
        NSUInteger ringPath[] = { 2 }, dotPath[] = { 2, 0, 0 };
        VNContour *ring = [obs contourAtIndexPath:[NSIndexPath indexPathWithIndexes:ringPath length:1] error:nil];
        VNContour *dot = [obs contourAtIndexPath:[NSIndexPath indexPathWithIndexes:dotPath length:3] error:nil];
        VNContour *box = [[obs contourAtIndex:0 error:nil] polygonApproximationWithEpsilon:0.01 error:nil];
        NSMutableArray *dotIndexes = [NSMutableArray array];
        for (NSUInteger i = 0; i < dot.indexPath.length; i++) [dotIndexes addObject:@([dot.indexPath indexAtPosition:i])];
        const simd_float2 *pts = box.normalizedPoints;
        float minX = 1, maxX = 0;
        for (NSInteger i = 0; i < box.pointCount; i++) { minX = MIN(minX, pts[i].x); maxX = MAX(maxX, pts[i].x); }
        VNContour *missing = [obs contourAtIndex:99 error:&err];
        say([NSString stringWithFormat:@"contours %ld top %ld ring children %ld dot path %@ box corners %ld aspect %@ box x %@-%@ missing %@ %ld",
             (long)obs.contourCount, (long)obs.topLevelContourCount, (long)ring.childContourCount, [dotIndexes componentsJoinedByString:@"."],
             (long)box.pointCount, f2(box.aspectRatio), f2(minX), f2(maxX), missing ? @"found" : err.domain, (long)err.code]);
        say([NSString stringWithFormat:@"contour path empty %d", CGPathIsEmpty(obs.normalizedPath)]);
    } else say([NSString stringWithFormat:@"shapes error %@", message(err)]);

    /* text rectangles: two words, without OCR */
    CGImageRef words = render(480, 120, ^(CGContextRef c) {
        CGContextSetFillColorWithColor(c, UIColor.whiteColor.CGColor); CGContextFillRect(c, CGRectMake(0, 0, 480, 120));
        [@"HELLO ISIM" drawAtPoint:CGPointMake(40, 30) withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:48 weight:UIFontWeightBold],
                                                                        NSForegroundColorAttributeName: UIColor.blackColor}];
    });
    VNDetectTextRectanglesRequest *textRects = [[VNDetectTextRectanglesRequest alloc] init];
    textRects.reportCharacterBoxes = YES;
    [[[VNImageRequestHandler alloc] initWithCGImage:words options:@{}] performRequests:@[textRects] error:nil];
    NSMutableArray *chars = [NSMutableArray array];
    for (VNTextObservation *t in textRects.results) [chars addObject:[NSString stringWithFormat:@"%lu", (unsigned long)t.characterBoxes.count]];
    say([NSString stringWithFormat:@"text rectangles %lu chars [%@]", (unsigned long)textRects.results.count, [chars componentsJoinedByString:@", "]]);

    /* the horizon: sky over ground, the line turned 10 degrees counterclockwise; through a VNSequenceRequestHandler */
    CGImageRef tilted = render(320, 240, ^(CGContextRef c) {
        CGContextSetFillColorWithColor(c, [UIColor colorWithRed:0.6 green:0.8 blue:1 alpha:1].CGColor); CGContextFillRect(c, CGRectMake(0, 0, 320, 240));
        double t = tan(10 * M_PI / 180);
        CGContextSetFillColorWithColor(c, [UIColor colorWithRed:0.1 green:0.35 blue:0.1 alpha:1].CGColor);
        CGPoint pts[] = { { 0, 120 + 160 * t }, { 320, 120 - 160 * t }, { 320, 240 }, { 0, 240 } };
        CGContextAddLines(c, pts, 4); CGContextFillPath(c);
    });
    VNDetectHorizonRequest *horizon = [[VNDetectHorizonRequest alloc] init];
    VNSequenceRequestHandler *sequence = [[VNSequenceRequestHandler alloc] init];
    [sequence performRequests:@[horizon] onCGImage:tilted error:nil];
    VNHorizonObservation *h = horizon.results.firstObject;
    if (h) say([NSString stringWithFormat:@"horizon %.1f levels %@", h.angle * 180 / M_PI, f2(atan2(h.transform.b, h.transform.a) * 180 / M_PI)]);
    else say(@"horizon none");

    /* saliency: a red disk off-centre on grey */
    CGImageRef disk = render(300, 300, ^(CGContextRef c) {
        CGContextSetFillColorWithColor(c, [UIColor colorWithWhite:0.5 alpha:1].CGColor); CGContextFillRect(c, CGRectMake(0, 0, 300, 300));
        CGContextSetFillColorWithColor(c, UIColor.redColor.CGColor); CGContextFillEllipseInRect(c, CGRectMake(175, 55, 70, 70));
    });
    VNGenerateAttentionBasedSaliencyImageRequest *saliency = [[VNGenerateAttentionBasedSaliencyImageRequest alloc] init];
    [[[VNImageRequestHandler alloc] initWithCGImage:disk options:@{}] performRequests:@[saliency] error:nil];
    VNSaliencyImageObservation *s = saliency.results.firstObject;
    VNRectangleObservation *o = s.salientObjects.firstObject;
    if (s && o) {
        CVPixelBufferRef pb = s.pixelBuffer;
        say([NSString stringWithFormat:@"saliency %zux%zu float %@ objects %lu first center %@,%@", CVPixelBufferGetWidth(pb), CVPixelBufferGetHeight(pb),
             CVPixelBufferGetPixelFormatType(pb) == kCVPixelFormatType_OneComponent32Float ? @"true" : @"false",
             (unsigned long)s.salientObjects.count, f2(CGRectGetMidX(o.boundingBox)), f2(CGRectGetMidY(o.boundingBox))]);
    } else say(@"saliency none");
    CGImageRelease(shapes); CGImageRelease(words); CGImageRelease(tilted); CGImageRelease(disk);
}

/// an unsupported request's error, the class factories, the time range, VNUtils.h
- (void)others {
    CGImageRef blank = render(64, 64, ^(CGContextRef c) {
        CGContextSetFillColorWithColor(c, UIColor.whiteColor.CGColor); CGContextFillRect(c, CGRectMake(0, 0, 64, 64));
    });
    VNClassifyImageRequest *classify = [[VNClassifyImageRequest alloc] init];
    NSError *err = nil;
    BOOL ok = [[[VNImageRequestHandler alloc] initWithCGImage:blank options:@{}] performRequests:@[classify] error:&err];
    say([NSString stringWithFormat:@"classify ok=%d domain=%@ unsupported=%d results=%@", ok, err.domain,
         [err.domain isEqualToString:VNErrorDomain] && err.code == VNErrorUnsupportedRequest, classify.results ? @"some" : @"nil"]);
    CGImageRelease(blank);

    VNRectangleObservation *made = [VNRectangleObservation observationWithBoundingBox:CGRectMake(0.25, 0.5, 0.5, 0.25)];
    VNFaceObservation *face = [VNFaceObservation faceObservationWithRequestRevision:3 boundingBox:CGRectMake(0.1, 0.1, 0.2, 0.2) roll:@0.5 yaw:nil];
    CMTimeRange tr = made.timeRange;
    say([NSString stringWithFormat:@"factories %@ %@ topLeft %@,%@ face roll %@ yaw %@ timeRange valid %d revision %lu", NSStringFromClass(made.class),
         rect(made.boundingBox), f2(made.topLeft.x), f2(made.topLeft.y), face.roll, face.yaw ?: @"nil", (int)(tr.start.flags & kCMTimeFlags_Valid),
         (unsigned long)VNDetectFaceRectanglesRequest.currentRevision]);

    CGRect imageRect = VNImageRectForNormalizedRect(CGRectMake(0.25, 0.5, 0.5, 0.25), 400, 200);
    CGRect back = VNNormalizedRectForImageRect(imageRect, 400, 200);
    CGPoint p = VNImagePointForNormalizedPointUsingRegionOfInterest(CGPointMake(0.5, 0.5), 400, 200, CGRectMake(0.5, 0, 0.5, 1));
    simd_float2 lp = { 0.5f, 0.5f };
    CGPoint fp = VNImagePointForFaceLandmarkPoint(lp, CGRectMake(0.25, 0.25, 0.5, 0.5), 100, 100);
    say([NSString stringWithFormat:@"utils image %@ back %@ identity %d roi point %@,%@ landmark %@,%@ float size %zu",
         rect(imageRect), rect(back), VNNormalizedRectIsIdentityRect(VNNormalizedIdentityRect), f2(p.x), f2(p.y), f2(fp.x), f2(fp.y),
         VNElementTypeSize(VNElementTypeFloat)]);
}


/// tracking and registration (issue #373): a black square with a white corner over white, moved 12 right and 6 down
- (void)tracking {
    CGImageRef (^frame)(CGFloat, CGFloat) = ^CGImageRef(CGFloat x, CGFloat y) {
        return render(200, 150, ^(CGContextRef c) {
            CGContextSetFillColorWithColor(c, UIColor.whiteColor.CGColor); CGContextFillRect(c, CGRectMake(0, 0, 200, 150));
            CGContextSetFillColorWithColor(c, UIColor.blackColor.CGColor); CGContextFillRect(c, CGRectMake(x, y, 30, 30));
            CGContextSetFillColorWithColor(c, UIColor.whiteColor.CGColor); CGContextFillRect(c, CGRectMake(x + 4, y + 4, 10, 10));
        });
    };
    CGImageRef a = frame(40, 50), b = frame(52, 56);
    VNDetectedObjectObservation *start = [VNDetectedObjectObservation observationWithBoundingBox:CGRectMake(0.2, 1 - 80.0 / 150, 0.15, 0.2)];
    VNTrackObjectRequest *track = [[VNTrackObjectRequest alloc] initWithDetectedObjectObservation:start];
    track.trackingLevel = VNRequestTrackingLevelAccurate;
    VNSequenceRequestHandler *sequence = [[VNSequenceRequestHandler alloc] init];
    NSError *error = nil;
    BOOL ok = [sequence performRequests:@[ track ] onCGImage:a error:&error];
    track.inputObservation = track.results.firstObject;
    track.lastFrame = YES;
    ok = ok && [sequence performRequests:@[ track ] onCGImage:b error:&error];
    VNDetectedObjectObservation *moved = track.results.firstObject;
    VNTranslationalImageRegistrationRequest *shift = [[VNTranslationalImageRegistrationRequest alloc] initWithTargetedCGImage:b options:@{}];
    VNHomographicImageRegistrationRequest *warp = [[VNHomographicImageRegistrationRequest alloc] initWithTargetedCGImage:b options:@{}];
    ok = ok && [[[VNImageRequestHandler alloc] initWithCGImage:a options:@{}] performRequests:@[ shift, warp ] error:&error];
    CGAffineTransform t = shift.results.firstObject.alignmentTransform;
    matrix_float3x3 m = warp.results.firstObject.warpTransform;
    VNTrackOpticalFlowRequest *flow = [[VNTrackOpticalFlowRequest alloc] init];
    flow.computationAccuracy = VNTrackOpticalFlowRequestComputationAccuracyLow;
    VNSequenceRequestHandler *sequence2 = [[VNSequenceRequestHandler alloc] init];
    ok = ok && [sequence2 performRequests:@[ flow ] onCGImage:a error:&error];
    NSUInteger firstFlow = flow.results.count;
    ok = ok && [sequence2 performRequests:@[ flow ] onCGImage:b error:&error];
    CVPixelBufferRef pb = flow.results.firstObject.pixelBuffer;
    say([NSString stringWithFormat:@"tracking ok %d box %@ last %d registration %.1f %.1f warp tx %.0f ty %.0f flow first %lu then %zux%zu format %d trackers %lu",
         ok, rect(moved.boundingBox), track.isLastFrame, t.tx, t.ty, m.columns[2][0], m.columns[2][1], (unsigned long)firstFlow,
         pb ? CVPixelBufferGetWidth(pb) : 0, pb ? CVPixelBufferGetHeight(pb) : 0, pb && CVPixelBufferGetPixelFormatType(pb) == kCVPixelFormatType_TwoComponent32Float,
         (unsigned long)[track supportedNumberOfTrackersAndReturnError:nil]]);
    CGImageRelease(a); CGImageRelease(b);
}


/// pose, classification and feature prints (issue #375): isim's own feature print; the model requests' errors
- (void)models {
    CGImageRef a = render(120, 90, ^(CGContextRef c) {
        CGContextSetFillColorWithColor(c, UIColor.whiteColor.CGColor); CGContextFillRect(c, CGRectMake(0, 0, 120, 90));
        CGContextSetFillColorWithColor(c, UIColor.redColor.CGColor); CGContextFillEllipseInRect(c, CGRectMake(30, 15, 60, 60));
    });
    CGImageRef b = render(120, 90, ^(CGContextRef c) {
        CGContextSetFillColorWithColor(c, UIColor.whiteColor.CGColor); CGContextFillRect(c, CGRectMake(0, 0, 120, 90));
        CGContextSetFillColorWithColor(c, UIColor.blueColor.CGColor); CGContextFillRect(c, CGRectMake(20, 10, 80, 70));
    });
    VNGenerateImageFeaturePrintRequest *pa = [[VNGenerateImageFeaturePrintRequest alloc] init], *pb = [[VNGenerateImageFeaturePrintRequest alloc] init];
    pa.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
    NSError *error = nil;
    [[[VNImageRequestHandler alloc] initWithCGImage:a options:@{}] performRequests:@[ pa ] error:&error];
    [[[VNImageRequestHandler alloc] initWithCGImage:b options:@{}] performRequests:@[ pb ] error:&error];
    float d = -1, self0 = -1;
    BOOL ok = [pa.results.firstObject computeDistance:&d toFeaturePrintObservation:pb.results.firstObject error:&error];
    [pa.results.firstObject computeDistance:&self0 toFeaturePrintObservation:pa.results.firstObject error:nil];
    VNDetectHumanBodyPoseRequest *body = [[VNDetectHumanBodyPoseRequest alloc] init];
    NSError *bodyError = nil;
    BOOL ran = [[[VNImageRequestHandler alloc] initWithCGImage:a options:@{}] performRequests:@[ body ] error:&bodyError];
    NSArray<VNHumanBodyPoseObservationJointName> *joints = [body supportedJointNamesAndReturnError:nil];
    VNVector *v = [[VNVector alloc] initWithVectorHead:[[VNPoint alloc] initWithX:1 y:1] tail:VNPoint.zeroPoint];
    say([NSString stringWithFormat:@"models print %lu ok %d self %.2f other %.2f body ran %d code %ld joints %lu nose %@ all %@ vector %.2f",
         (unsigned long)pa.results.firstObject.elementCount, ok, self0, d, ran, (long)bodyError.code, (unsigned long)joints.count,
         VNHumanBodyPoseObservationJointNameNose, VNRecognizedPointGroupKeyAll, v.length]);
    CGImageRelease(a); CGImageRelease(b);
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[VisionViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
