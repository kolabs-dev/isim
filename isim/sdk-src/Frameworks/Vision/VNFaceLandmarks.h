#pragma once
#import <Vision/VNTypes.h>
#import <CoreGraphics/CoreGraphics.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, VNPointsClassification) {
    VNPointsClassificationDisconnected = 0, VNPointsClassificationOpenPath, VNPointsClassificationClosedPath,
} API_AVAILABLE(ios(16.0));
API_AVAILABLE(ios(11.0))
@interface VNFaceLandmarkRegion : NSObject
@property (readonly) NSUInteger pointCount;
@property (readonly) NSUInteger requestRevision;
@end
API_AVAILABLE(ios(11.0))
@interface VNFaceLandmarkRegion2D : VNFaceLandmarkRegion
/* normalized to the face's bounding box, lower-left origin; valid as long as the region */
@property (readonly, assign, nullable) const CGPoint *normalizedPoints NS_RETURNS_INNER_POINTER;
/* valid until the next call */
- (const CGPoint *)pointsInImageOfSize:(CGSize)imageSize NS_RETURNS_INNER_POINTER;
@property (readonly, nullable) NSArray<NSNumber *> *precisionEstimatesPerPoint API_AVAILABLE(ios(13.0));
@property (readonly) VNPointsClassification pointsClassification API_AVAILABLE(ios(16.0));
@end
API_AVAILABLE(ios(11.0))
@interface VNFaceLandmarks : NSObject
@property (readonly) VNConfidence confidence;
@property (readonly) NSUInteger requestRevision;
@end
API_AVAILABLE(ios(11.0))
@interface VNFaceLandmarks2D : VNFaceLandmarks
@property (readonly, nullable) VNFaceLandmarkRegion2D *allPoints;
@property (readonly, nullable) VNFaceLandmarkRegion2D *faceContour;
@property (readonly, nullable) VNFaceLandmarkRegion2D *leftEye;
@property (readonly, nullable) VNFaceLandmarkRegion2D *rightEye;
@property (readonly, nullable) VNFaceLandmarkRegion2D *leftEyebrow;
@property (readonly, nullable) VNFaceLandmarkRegion2D *rightEyebrow;
@property (readonly, nullable) VNFaceLandmarkRegion2D *nose;
@property (readonly, nullable) VNFaceLandmarkRegion2D *noseCrest;
@property (readonly, nullable) VNFaceLandmarkRegion2D *medianLine;
@property (readonly, nullable) VNFaceLandmarkRegion2D *outerLips;
@property (readonly, nullable) VNFaceLandmarkRegion2D *innerLips;
@property (readonly, nullable) VNFaceLandmarkRegion2D *leftPupil;
@property (readonly, nullable) VNFaceLandmarkRegion2D *rightPupil;
@end
NS_ASSUME_NONNULL_END
#endif
