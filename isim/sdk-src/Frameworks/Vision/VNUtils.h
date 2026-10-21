#pragma once
#import <CoreGraphics/CoreGraphics.h>
#import <Vision/VNDefines.h>
#import <Vision/VNTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
VN_EXPORT const CGRect VNNormalizedIdentityRect API_AVAILABLE(ios(11.0));
VN_EXPORT bool VNNormalizedRectIsIdentityRect(CGRect normalizedRect) API_AVAILABLE(ios(11.0));
VN_EXPORT CGPoint VNImagePointForNormalizedPoint(CGPoint normalizedPoint, size_t imageWidth, size_t imageHeight) API_AVAILABLE(ios(11.0));
VN_EXPORT CGPoint VNImagePointForNormalizedPointUsingRegionOfInterest(CGPoint normalizedPoint, size_t imageWidth, size_t imageHeight, CGRect roi) API_AVAILABLE(ios(17.0));
VN_EXPORT CGPoint VNNormalizedPointForImagePoint(CGPoint imagePoint, size_t imageWidth, size_t imageHeight) API_AVAILABLE(ios(17.0));
VN_EXPORT CGPoint VNNormalizedPointForImagePointUsingRegionOfInterest(CGPoint imagePoint, size_t imageWidth, size_t imageHeight, CGRect roi) API_AVAILABLE(ios(17.0));
VN_EXPORT CGRect VNImageRectForNormalizedRect(CGRect normalizedRect, size_t imageWidth, size_t imageHeight) API_AVAILABLE(ios(11.0));
VN_EXPORT CGRect VNImageRectForNormalizedRectUsingRegionOfInterest(CGRect normalizedRect, size_t imageWidth, size_t imageHeight, CGRect roi) API_AVAILABLE(ios(17.0));
VN_EXPORT CGRect VNNormalizedRectForImageRect(CGRect imageRect, size_t imageWidth, size_t imageHeight) API_AVAILABLE(ios(11.0));
VN_EXPORT CGRect VNNormalizedRectForImageRectUsingRegionOfInterest(CGRect imageRect, size_t imageWidth, size_t imageHeight, CGRect roi) API_AVAILABLE(ios(17.0));
/* a face landmark point (normalized to the face's bounding box, itself normalized to the image) in image coordinates */
VN_EXPORT CGPoint VNImagePointForFaceLandmarkPoint(vector_float2 faceLandmarkPoint, CGRect faceBoundingBox, size_t imageWidth, size_t imageHeight) API_AVAILABLE(ios(11.0));
VN_EXPORT size_t VNElementTypeSize(VNElementType elementType) API_AVAILABLE(ios(13.0));
NS_ASSUME_NONNULL_END
#endif
