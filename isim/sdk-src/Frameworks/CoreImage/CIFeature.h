#pragma once
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
@class CIQRCodeDescriptor;
extern NSString *const CIFeatureTypeFace, *const CIFeatureTypeRectangle, *const CIFeatureTypeQRCode, *const CIFeatureTypeText;
@interface CIFeature : NSObject
@property (readonly, retain) NSString *type;
@property (readonly, assign) CGRect bounds;
@end
@interface CIFaceFeature : CIFeature
@property (readonly, assign) CGRect bounds;
@property (readonly, assign) BOOL hasLeftEyePosition;
@property (readonly, assign) CGPoint leftEyePosition;
@property (readonly, assign) BOOL hasRightEyePosition;
@property (readonly, assign) CGPoint rightEyePosition;
@property (readonly, assign) BOOL hasMouthPosition;
@property (readonly, assign) CGPoint mouthPosition;
@property (readonly, assign) BOOL hasTrackingID;
@property (readonly, assign) int trackingID;
@property (readonly, assign) BOOL hasTrackingFrameCount;
@property (readonly, assign) int trackingFrameCount;
@property (readonly, assign) BOOL hasFaceAngle;
@property (readonly, assign) float faceAngle;
@property (readonly, assign) BOOL hasSmile;
@property (readonly, assign) BOOL leftEyeClosed;
@property (readonly, assign) BOOL rightEyeClosed;
@end
@interface CIRectangleFeature : CIFeature
@property (readonly) CGRect bounds;
@property (readonly) CGPoint topLeft, topRight, bottomLeft, bottomRight;
@end
@interface CIQRCodeFeature : CIFeature <NSSecureCoding, NSCopying>
@property (readonly) CGRect bounds;
@property (readonly) CGPoint topLeft, topRight, bottomLeft, bottomRight;
@property (nullable, readonly) NSString *messageString;
@property (nullable, readonly) CIQRCodeDescriptor *symbolDescriptor;
@end
@interface CITextFeature : CIFeature
@property (readonly) CGRect bounds;
@property (readonly) CGPoint topLeft, topRight, bottomLeft, bottomRight;
@property (nullable, readonly) NSArray *subFeatures;
@end
NS_ASSUME_NONNULL_END
