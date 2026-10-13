#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIImage.h>
#import <CoreImage/CIFeature.h>
NS_ASSUME_NONNULL_BEGIN
@class CIContext;
/* isim detectors (adapted): faces with Viola-Jones Haar cascades read from the host's OpenCV data files (the
 * opencv-data package: frontal face, eyes, smile); rectangles with isim's own edge / quadrilateral finder; QR codes
 * through the host's libzbar or zxing-cpp; text regions through the host's tesseract. Without the host part a
 * detector returns no features (logged once). */
extern NSString *const CIDetectorTypeFace, *const CIDetectorTypeRectangle, *const CIDetectorTypeQRCode, *const CIDetectorTypeText;
extern NSString *const CIDetectorAccuracy, *const CIDetectorAccuracyLow, *const CIDetectorAccuracyHigh, *const CIDetectorTracking,
    *const CIDetectorMinFeatureSize, *const CIDetectorMaxFeatureCount, *const CIDetectorNumberOfAngles, *const CIDetectorImageOrientation,
    *const CIDetectorEyeBlink, *const CIDetectorSmile, *const CIDetectorFocalLength, *const CIDetectorAspectRatio,
    *const CIDetectorReturnSubFeatures;
@interface CIDetector : NSObject
+ (nullable CIDetector *)detectorOfType:(NSString *)type context:(nullable CIContext *)context options:(nullable NSDictionary<NSString *, id> *)options;
- (NSArray<CIFeature *> *)featuresInImage:(CIImage *)image;
- (NSArray<CIFeature *> *)featuresInImage:(CIImage *)image options:(nullable NSDictionary<NSString *, id> *)options;
@end
NS_ASSUME_NONNULL_END
