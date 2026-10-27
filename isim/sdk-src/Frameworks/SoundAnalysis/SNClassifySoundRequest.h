#pragma once
#import <SoundAnalysis/SNDefines.h>
#import <SoundAnalysis/SNRequest.h>
#import <SoundAnalysis/SNTypes.h>
#import <SoundAnalysis/SNTimeDurationConstraint.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class MLModel;
/* classifies the sounds in each window of the audio */
API_AVAILABLE(ios(13.0))
@interface SNClassifySoundRequest : NSObject <SNRequest>
/* how much consecutive windows overlap, 0 ..< 1 (default 0.5) */
@property (readwrite, assign) double overlapFactor;
/* default 0.975 s (YAMNet's patch) */
@property (readwrite, assign) CMTime windowDuration API_AVAILABLE(ios(15.0));
@property (readonly, strong) SNTimeDurationConstraint *windowDurationConstraint API_AVAILABLE(ios(15.0));
@property (readonly, copy) NSArray<NSString *> *knownClassifications API_AVAILABLE(ios(15.0));
/* isim: fails with SNErrorCodeInvalidModel (isim's Core ML runs no sound classifier models) */
- (nullable instancetype)initWithMLModel:(MLModel *)mlModel error:(NSError **)error;
/* the host's ONNX classifier (ISIM_SOUND_MODEL); SNErrorCodeOperationFailed when the host has none */
- (nullable instancetype)initWithClassifierIdentifier:(SNClassifierIdentifier)classifierIdentifier error:(NSError **)error API_AVAILABLE(ios(15.0));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
#endif
