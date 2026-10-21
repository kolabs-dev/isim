#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNDefines.h>
#import <Vision/VNObservation.h>
#import <CoreGraphics/CoreGraphics.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(14.0))
@interface VNContour : NSObject <NSCopying>
@property (readonly, nonatomic, strong) NSIndexPath *indexPath;
@property (readonly, nonatomic) NSInteger childContourCount;
@property (readonly, nonatomic, copy) NSArray<VNContour *> *childContours;
- (nullable VNContour *)childContourAtIndex:(NSUInteger)childContourIndex error:(NSError **)error;
@property (readonly, nonatomic) NSInteger pointCount;
/* normalized, lower-left origin; valid as long as the contour */
@property (readonly, nonatomic) const simd_float2 *normalizedPoints NS_RETURNS_INNER_POINTER;
@property (readonly, nonatomic) CGPathRef normalizedPath;
@property (readonly, nonatomic) float aspectRatio;
@property (readonly, nonatomic) NSUInteger requestRevision;
- (nullable VNContour *)polygonApproximationWithEpsilon:(float)epsilon error:(NSError **)error;
@end
API_AVAILABLE(ios(14.0))
@interface VNContoursObservation : VNObservation
@property (readonly, nonatomic) NSInteger contourCount;
- (nullable VNContour *)contourAtIndex:(NSInteger)contourIndex error:(NSError **)error;
@property (readonly, nonatomic) NSInteger topLevelContourCount;
@property (readonly, nonatomic, copy) NSArray<VNContour *> *topLevelContours;
- (nullable VNContour *)contourAtIndexPath:(NSIndexPath *)indexPath error:(NSError **)error;
@property (readonly, nonatomic) CGPathRef normalizedPath;
@end
/* isim's CPU detector: the borders of the image's dark (or light) regions */
API_AVAILABLE(ios(14.0))
@interface VNDetectContoursRequest : VNImageBasedRequest
@property (readwrite, nonatomic, assign) float contrastAdjustment;
@property (readwrite, nonatomic, strong, nullable) NSNumber *contrastPivot API_AVAILABLE(ios(15.0));
@property (readwrite, nonatomic, assign) BOOL detectsDarkOnLight API_AVAILABLE(ios(15.0));
@property (readwrite, nonatomic, assign) BOOL detectDarkOnLight API_DEPRECATED_WITH_REPLACEMENT("detectsDarkOnLight", ios(14.0, 15.0));
@property (readwrite, nonatomic, assign) NSUInteger maximumImageDimension;
@property (readonly, nonatomic, copy, nullable) NSArray<VNContoursObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
