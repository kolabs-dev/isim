#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, VNRequestTextRecognitionLevel) {
    VNRequestTextRecognitionLevelAccurate = 0, VNRequestTextRecognitionLevelFast,
} API_AVAILABLE(ios(13.0));
/* the host's tesseract command; both levels run the same engine */
API_AVAILABLE(ios(13.0))
@interface VNRecognizeTextRequest : VNImageBasedRequest
+ (nullable NSArray<NSString *> *)supportedRecognitionLanguagesForTextRecognitionLevel:(VNRequestTextRecognitionLevel)recognitionLevel revision:(NSUInteger)requestRevision error:(NSError **)error API_DEPRECATED("use -supportedRecognitionLanguagesAndReturnError:", ios(13.0, 15.0));
- (nullable NSArray<NSString *> *)supportedRecognitionLanguagesAndReturnError:(NSError **)error API_AVAILABLE(ios(15.0));
@property (readwrite, nonatomic, copy) NSArray<NSString *> *recognitionLanguages;
@property (readwrite, nonatomic, copy) NSArray<NSString *> *customWords;
@property (readwrite, nonatomic, assign) VNRequestTextRecognitionLevel recognitionLevel;
@property (readwrite, nonatomic, assign) BOOL usesLanguageCorrection;
@property (readwrite, nonatomic, assign) BOOL automaticallyDetectsLanguage API_AVAILABLE(ios(16.0));
@property (readwrite, nonatomic, assign) float minimumTextHeight;
@property (readonly, nonatomic, copy, nullable) NSArray<VNRecognizedTextObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
