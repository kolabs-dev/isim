#pragma once
#import <Vision/VNTypes.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CMTime.h>
#import <CoreVideo/CoreVideo.h>
#import <Vision/VNDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class VNFaceLandmarks2D, MLFeatureValue;
API_AVAILABLE(ios(11.0))
@interface VNObservation : NSObject
@property (readonly, nonatomic, strong) NSUUID *uuid;
@property (readonly, nonatomic, assign) VNConfidence confidence;
@property (readonly, nonatomic, assign) CMTimeRange timeRange API_AVAILABLE(ios(14.0));
@property (readonly, nonatomic) NSUInteger requestRevision;
@end
API_AVAILABLE(ios(11.0))
@interface VNDetectedObjectObservation : VNObservation
+ (instancetype)observationWithBoundingBox:(CGRect)boundingBox;
+ (instancetype)observationWithRequestRevision:(NSUInteger)requestRevision boundingBox:(CGRect)boundingBox API_AVAILABLE(ios(12.0));
@property (readonly, nonatomic, assign) CGRect boundingBox;
@end
API_AVAILABLE(ios(11.0))
@interface VNFaceObservation : VNDetectedObjectObservation
+ (instancetype)faceObservationWithRequestRevision:(NSUInteger)requestRevision boundingBox:(CGRect)boundingBox roll:(nullable NSNumber *)roll yaw:(nullable NSNumber *)yaw API_AVAILABLE(ios(12.0));
+ (instancetype)faceObservationWithRequestRevision:(NSUInteger)requestRevision boundingBox:(CGRect)boundingBox roll:(nullable NSNumber *)roll yaw:(nullable NSNumber *)yaw pitch:(nullable NSNumber *)pitch API_AVAILABLE(ios(15.0));
@property (readonly, nonatomic, strong, nullable) VNFaceLandmarks2D *landmarks;
@property (readonly, nonatomic, strong, nullable) NSNumber *faceCaptureQuality API_AVAILABLE(ios(13.0));
@property (readonly, nonatomic, strong, nullable) NSNumber *roll API_AVAILABLE(ios(12.0));
@property (readonly, nonatomic, strong, nullable) NSNumber *yaw API_AVAILABLE(ios(12.0));
@property (readonly, nonatomic, strong, nullable) NSNumber *pitch API_AVAILABLE(ios(15.0));
@end
API_AVAILABLE(ios(11.0))
@interface VNClassificationObservation : VNObservation
@property (readonly, nonatomic, copy) NSString *identifier;
@property (readonly, nonatomic, assign) BOOL hasPrecisionRecallCurve API_AVAILABLE(ios(14.0));
- (BOOL)hasMinimumRecall:(float)minimumRecall forPrecision:(float)precision API_AVAILABLE(ios(14.0));
- (BOOL)hasMinimumPrecision:(float)minimumPrecision forRecall:(float)recall API_AVAILABLE(ios(14.0));
@end
API_AVAILABLE(ios(11.0))
@interface VNCoreMLFeatureValueObservation : VNObservation
@property (readonly, nonatomic, copy) MLFeatureValue *featureValue;
@property (readonly, nonatomic, copy) NSString *featureName API_AVAILABLE(ios(14.0));
@end
API_AVAILABLE(ios(11.0))
@interface VNPixelBufferObservation : VNObservation
@property (readonly, nonatomic) CVPixelBufferRef pixelBuffer;
@property (readonly, nonatomic, copy, nullable) NSString *featureName API_AVAILABLE(ios(12.0));
@end
API_AVAILABLE(ios(11.0))
@interface VNRectangleObservation : VNDetectedObjectObservation
@property (readonly, nonatomic, assign) CGPoint topLeft;
@property (readonly, nonatomic, assign) CGPoint topRight;
@property (readonly, nonatomic, assign) CGPoint bottomLeft;
@property (readonly, nonatomic, assign) CGPoint bottomRight;
@end
API_AVAILABLE(ios(11.0))
@interface VNTextObservation : VNRectangleObservation
@property (readonly, nonatomic, copy, nullable) NSArray<VNRectangleObservation *> *characterBoxes;
@end
API_AVAILABLE(ios(13.0))
@interface VNRecognizedText : NSObject
@property (readonly, nonatomic, copy) NSString *string;
@property (readonly, nonatomic, assign) VNConfidence confidence;
/* range: UTF-16 offsets in string */
- (nullable VNRectangleObservation *)boundingBoxForRange:(NSRange)range error:(NSError **)error;
@end
API_AVAILABLE(ios(13.0))
@interface VNRecognizedTextObservation : VNTextObservation
/* isim: one candidate per line */
- (NSArray<VNRecognizedText *> *)topCandidates:(NSUInteger)maxCandidateCount;
@end
API_AVAILABLE(ios(11.0))
@interface VNBarcodeObservation : VNRectangleObservation
@property (readonly, nonatomic, copy) VNBarcodeSymbology symbology;
@property (readonly, nonatomic, copy, nullable) NSString *payloadStringValue;
@property (readonly, nonatomic, copy, nullable) NSData *payloadData API_AVAILABLE(ios(17.0));
@property (readonly, nonatomic, getter=isGS1DataCarrier) BOOL GS1DataCarrier API_AVAILABLE(ios(17.0));
@property (readonly, nonatomic, getter=isColorInverted) BOOL colorInverted API_AVAILABLE(ios(17.0));
@property (readonly, nonatomic, copy, nullable) NSString *supplementalPayloadString API_AVAILABLE(ios(17.0));
@end
API_AVAILABLE(ios(14.0))
@interface VNHorizonObservation : VNObservation
@property (readonly, nonatomic, assign) CGAffineTransform transform;
@property (readonly, nonatomic, assign) CGFloat angle;
- (CGAffineTransform)transformForImageWidth:(size_t)width height:(size_t)height API_AVAILABLE(ios(16.0));
@end
API_AVAILABLE(ios(13.0))
@interface VNSaliencyImageObservation : VNPixelBufferObservation
@property (readonly, nonatomic, copy, nullable) NSArray<VNRectangleObservation *> *salientObjects;
@end
API_AVAILABLE(ios(15.0))
@interface VNHumanObservation : VNDetectedObjectObservation
@end
/* isim: the Euclidean distance between feature prints */
API_AVAILABLE(ios(13.0))
@interface VNFeaturePrintObservation : VNObservation <NSSecureCoding>
@property (readonly, atomic, assign) VNElementType elementType;
@property (readonly, atomic, assign) NSUInteger elementCount;
@property (readonly, atomic, strong) NSData *data;
- (BOOL)computeDistance:(float *)outDistance toFeaturePrintObservation:(VNFeaturePrintObservation *)featurePrint error:(NSError **)error;
@end
API_AVAILABLE(ios(11.0))
@interface VNImageAlignmentObservation : VNObservation
@end
/* the translation (pixels, lower-left origin) that moves the floating image onto the reference image */
API_AVAILABLE(ios(11.0))
@interface VNImageTranslationAlignmentObservation : VNImageAlignmentObservation
@property (readonly, nonatomic, assign) CGAffineTransform alignmentTransform;
@end
/* the homography (pixels, lower-left origin, applied to (x, y, 1)) that warps the floating image onto the reference */
API_AVAILABLE(ios(11.0))
@interface VNImageHomographicAlignmentObservation : VNImageAlignmentObservation
@property (readonly, nonatomic, assign) matrix_float3x3 warpTransform;
@end
NS_ASSUME_NONNULL_END
#endif
