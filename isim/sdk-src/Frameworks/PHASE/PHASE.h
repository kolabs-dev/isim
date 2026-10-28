#pragma once
/* isim PHASE for Objective-C: the classes are the PHASE Swift overlay's (PHASE.framework re-exports libswiftPHASE.dylib):
   isim's renderer mixes the sound events to stereo (distance models, directivity, equal-power panning; no HRTF, reverb
   or occlusion). Shapes and occluders need ModelIO, which isim does not have. Swift uses the overlay; these
   declarations are hidden from Swift. The classes are not subclassable from Objective-C. */
#import <AVFAudio/AVFAudio.h>
#if !defined(__swift__)
/* the simd types from <simd/simd.h> when the SDK has it, else Apple's layout (shared with SceneKit's fallbacks) */
#if __has_include(<simd/simd.h>)
#include <simd/simd.h>
#else
typedef float simd_float3 __attribute__((__ext_vector_type__(3)));
typedef float simd_float4 __attribute__((__ext_vector_type__(4)));
typedef double simd_double2 __attribute__((__ext_vector_type__(2)));
#ifndef ISIM_SIMD_MATRIX_TYPES
#define ISIM_SIMD_MATRIX_TYPES 1
typedef struct { simd_float3 columns[3]; } simd_float3x3;
typedef struct { simd_float4 columns[4]; } simd_float4x4;
#endif
#ifndef ISIM_SIMD_QUATF
#define ISIM_SIMD_QUATF 1
typedef struct { simd_float4 vector; } simd_quatf;
#endif
#endif
NS_ASSUME_NONNULL_BEGIN
@class PHASEEngine, PHASEObject, PHASESource, PHASEListener, PHASEMixer, PHASEGroup, PHASEMetaParameter, PHASENumberMetaParameter;

FOUNDATION_EXPORT NSErrorDomain const PHASEErrorDomain;
typedef NS_ERROR_ENUM(PHASEErrorDomain, PHASEError) { PHASEErrorInitializeFailed = 'PHEa', PHASEErrorInvalidObject = 'PHEb' };
FOUNDATION_EXPORT NSErrorDomain const PHASESoundEventErrorDomain;
typedef NS_ERROR_ENUM(PHASESoundEventErrorDomain, PHASESoundEventError) {
    PHASESoundEventErrorNotFound = 'PHEa', PHASESoundEventErrorBadData = 'PHEb', PHASESoundEventErrorInvalidInstance = 'PHEc',
    PHASESoundEventErrorAPIMisuse = 'PHEd', PHASESoundEventErrorSystemNotInitialized = 'PHEe', PHASESoundEventErrorOutOfMemory = 'PHEf',
};
FOUNDATION_EXPORT NSErrorDomain const PHASEAssetErrorDomain;
typedef NS_ERROR_ENUM(PHASEAssetErrorDomain, PHASEAssetError) {
    PHASEAssetErrorFailedToLoad = 'PHEa', PHASEAssetErrorInvalidEngineInstance = 'PHEb', PHASEAssetErrorBadParameters = 'PHEc',
    PHASEAssetErrorAlreadyExists = 'PHEd', PHASEAssetErrorGeneralError = 'PHEe', PHASEAssetErrorMemoryAllocation = 'PHEf',
};

typedef NS_ENUM(NSInteger, PHASEUpdateMode) { PHASEUpdateModeAutomatic = 0, PHASEUpdateModeManual = 1 };
typedef NS_ENUM(NSInteger, PHASERenderingMode) { PHASERenderingModeLocal = 0, PHASERenderingModeClient = 1 };
typedef NS_ENUM(NSInteger, PHASERenderingState) { PHASERenderingStateStopped = 0, PHASERenderingStateStarted = 1, PHASERenderingStatePaused = 2 };
typedef NS_ENUM(NSInteger, PHASENormalizationMode) { PHASENormalizationModeNone = 0, PHASENormalizationModeDynamic = 1 };
typedef NS_ENUM(NSInteger, PHASESpatializationMode) {
    PHASESpatializationModeAutomatic = 0, PHASESpatializationModeAlwaysUseBinaural = 1, PHASESpatializationModeAlwaysUseChannelBased = 2,
};
/* isim's raw values for Apple's four-character codes */
typedef NS_ENUM(NSInteger, PHASEReverbPreset) {
    PHASEReverbPresetNone = 0, PHASEReverbPresetSmallRoom, PHASEReverbPresetMediumRoom, PHASEReverbPresetLargeRoom, PHASEReverbPresetLargeRoom2,
    PHASEReverbPresetMediumChamber, PHASEReverbPresetLargeChamber, PHASEReverbPresetMediumHall, PHASEReverbPresetMediumHall2,
    PHASEReverbPresetMediumHall3, PHASEReverbPresetLargeHall, PHASEReverbPresetLargeHall2, PHASEReverbPresetCathedral,
};
typedef NS_ENUM(NSInteger, PHASEMediumPreset) { PHASEMediumPresetAir = 0 };
typedef NS_ENUM(NSInteger, PHASEMaterialPreset) {
    PHASEMaterialPresetCardboard = 0, PHASEMaterialPresetGlass, PHASEMaterialPresetBrick, PHASEMaterialPresetConcrete, PHASEMaterialPresetDrywall,
    PHASEMaterialPresetWood,
};
typedef NS_ENUM(NSInteger, PHASEAssetType) { PHASEAssetTypeResident = 0, PHASEAssetTypeStreamed = 1 };
typedef NS_ENUM(NSInteger, PHASECullOption) {
    PHASECullOptionTerminate = 0, PHASECullOptionSleepWakeAtZero = 1, PHASECullOptionSleepWakeAtRandomOffset = 2,
    PHASECullOptionSleepWakeAtRealtimeOffset = 3, PHASECullOptionDoNotCull = 4,
};
typedef NS_ENUM(NSInteger, PHASEPlaybackMode) { PHASEPlaybackModeOneShot = 0, PHASEPlaybackModeLooping = 1 };
typedef NS_ENUM(NSInteger, PHASECalibrationMode) { PHASECalibrationModeNone = 0, PHASECalibrationModeRelativeSpl = 1, PHASECalibrationModeAbsoluteSpl = 2 };
typedef NS_ENUM(NSInteger, PHASECurveType) {
    PHASECurveTypeLinear = 0, PHASECurveTypeSquared, PHASECurveTypeInverseSquared, PHASECurveTypeCubed, PHASECurveTypeInverseCubed,
    PHASECurveTypeSine, PHASECurveTypeInverseSine, PHASECurveTypeSigmoid, PHASECurveTypeInverseSigmoid, PHASECurveTypeHoldStartValue,
    PHASECurveTypeJumpToEndValue,
};
typedef NS_ENUM(NSInteger, PHASESoundEventPrepareHandlerReason) {
    PHASESoundEventPrepareHandlerReasonFailure = 0, PHASESoundEventPrepareHandlerReasonPrepared = 1, PHASESoundEventPrepareHandlerReasonTerminated = 2,
};
typedef NS_ENUM(NSInteger, PHASESoundEventPrepareState) {
    PHASESoundEventPrepareStatePrepareNotStarted = 0, PHASESoundEventPrepareStatePrepareInProgress = 1, PHASESoundEventPrepareStatePrepared = 2,
};
typedef NS_ENUM(NSInteger, PHASESoundEventStartHandlerReason) {
    PHASESoundEventStartHandlerReasonFailure = 0, PHASESoundEventStartHandlerReasonFinishedPlaying = 1, PHASESoundEventStartHandlerReasonTerminated = 2,
};
typedef NS_ENUM(NSInteger, PHASESoundEventSeekHandlerReason) {
    PHASESoundEventSeekHandlerReasonFailure = 0, PHASESoundEventSeekHandlerReasonFailureSeekAlreadyInProgress = 1,
    PHASESoundEventSeekHandlerReasonSeekSuccessful = 2,
};
typedef NS_ENUM(NSInteger, PHASEPushStreamCompletionCallbackCondition) { PHASEPushStreamCompletionDataRendered = 0 };
typedef NS_OPTIONS(NSUInteger, PHASEPushStreamBufferOptions) {
    PHASEPushStreamBufferDefault = 1UL << 0, PHASEPushStreamBufferLoops = 1UL << 1, PHASEPushStreamBufferInterrupts = 1UL << 2,
    PHASEPushStreamBufferInterruptsAtLoop = 1UL << 3,
};
typedef NS_OPTIONS(NSUInteger, PHASESpatialPipelineFlags) {
    PHASESpatialPipelineFlagDirectPathTransmission = 1UL << 0, PHASESpatialPipelineFlagEarlyReflections = 1UL << 1,
    PHASESpatialPipelineFlagLateReverb = 1UL << 2,
};
typedef NS_OPTIONS(NSUInteger, PHASEAutomaticHeadTrackingFlags) { PHASEAutomaticHeadTrackingFlagOrientation = 1UL << 0, PHASEAutomaticHeadTrackingFlagPosition = 1UL << 1 };
typedef NSString *PHASESpatialCategory NS_TYPED_ENUM;
FOUNDATION_EXPORT PHASESpatialCategory const PHASESpatialCategoryDirectPathTransmission;
FOUNDATION_EXPORT PHASESpatialCategory const PHASESpatialCategoryEarlyReflections;
FOUNDATION_EXPORT PHASESpatialCategory const PHASESpatialCategoryLateReverb;

@interface PHASENumericPair : NSObject
- (instancetype)initWithFirstValue:(double)first secondValue:(double)second;
@property (nonatomic) double first;
@property (nonatomic) double second;
@end
@interface PHASEEnvelopeSegment : NSObject
- (instancetype)initWithEndPoint:(simd_double2)endPoint curveType:(PHASECurveType)curveType;
@property (nonatomic) simd_double2 endPoint;
@property (nonatomic) PHASECurveType curveType;
@end
@interface PHASEEnvelope : NSObject
- (nullable instancetype)initWithStartPoint:(simd_double2)startPoint segments:(NSArray<PHASEEnvelopeSegment *> *)segments;
- (double)evaluateForValue:(double)x;
@property (nonatomic, readonly) simd_double2 startPoint;
@property (nonatomic, readonly, copy) NSArray<PHASEEnvelopeSegment *> *segments;
@property (nonatomic, readonly, strong) PHASENumericPair *domain;
@property (nonatomic, readonly, strong) PHASENumericPair *range;
@end

@interface PHASEDefinition : NSObject
@property (nonatomic, readonly) NSString *identifier;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface PHASEMetaParameterDefinition : PHASEDefinition
@property (nonatomic, readonly, strong) id value;
@end
@interface PHASENumberMetaParameterDefinition : PHASEMetaParameterDefinition
- (instancetype)initWithValue:(double)value;
- (instancetype)initWithValue:(double)value identifier:(NSString *)identifier;
- (instancetype)initWithValue:(double)value minimum:(double)minimum maximum:(double)maximum;
- (instancetype)initWithValue:(double)value minimum:(double)minimum maximum:(double)maximum identifier:(NSString *)identifier;
@property (nonatomic, readonly) double minimum;
@property (nonatomic, readonly) double maximum;
@end
@interface PHASEStringMetaParameterDefinition : PHASEMetaParameterDefinition
- (instancetype)initWithValue:(NSString *)value;
- (instancetype)initWithValue:(NSString *)value identifier:(NSString *)identifier;
@end
@interface PHASEMappedMetaParameterDefinition : PHASENumberMetaParameterDefinition
- (instancetype)initWithInputMetaParameterDefinition:(PHASENumberMetaParameterDefinition *)inputMetaParameterDefinition envelope:(PHASEEnvelope *)envelope;
- (instancetype)initWithInputMetaParameterDefinition:(PHASENumberMetaParameterDefinition *)inputMetaParameterDefinition envelope:(PHASEEnvelope *)envelope
                                          identifier:(NSString *)identifier;
@property (nonatomic, readonly, strong) PHASENumberMetaParameterDefinition *inputMetaParameterDefinition;
@property (nonatomic, readonly, strong) PHASEEnvelope *envelope;
@end
@interface PHASEMetaParameter : NSObject
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, strong) id value;
@end
@interface PHASENumberMetaParameter : PHASEMetaParameter
@property (nonatomic, readonly) double minimum;
@property (nonatomic, readonly) double maximum;
- (void)fadeToValue:(double)value duration:(NSTimeInterval)duration;
@end
@interface PHASEStringMetaParameter : PHASEMetaParameter
@end

@interface PHASEDistanceModelFadeOutParameters : NSObject
- (instancetype)initWithCullDistance:(double)cullDistance;
@property (nonatomic, readonly) double cullDistance;
@end
@interface PHASEDistanceModelParameters : NSObject
@property (nonatomic, strong, nullable) PHASEDistanceModelFadeOutParameters *fadeOutParameters;
@end
@interface PHASEGeometricSpreadingDistanceModelParameters : PHASEDistanceModelParameters
@property (nonatomic) double rolloffFactor;
@end
@interface PHASEEnvelopeDistanceModelParameters : PHASEDistanceModelParameters
- (instancetype)initWithEnvelope:(PHASEEnvelope *)envelope;
@property (nonatomic, readonly, strong) PHASEEnvelope *envelope;
@end
@interface PHASEDirectivityModelParameters : NSObject
@end
@interface PHASECardioidDirectivityModelSubbandParameters : NSObject
@property (nonatomic) double frequency;
@property (nonatomic) double pattern;
@property (nonatomic) double sharpness;
@end
@interface PHASECardioidDirectivityModelParameters : PHASEDirectivityModelParameters
- (instancetype)initWithSubbandParameters:(NSArray<PHASECardioidDirectivityModelSubbandParameters *> *)subbandParameters;
@property (nonatomic, readonly, copy) NSArray<PHASECardioidDirectivityModelSubbandParameters *> *subbandParameters;
@end
@interface PHASEConeDirectivityModelSubbandParameters : NSObject
@property (nonatomic) double frequency;
@property (nonatomic, readonly) double innerAngle;
@property (nonatomic, readonly) double outerAngle;
@property (nonatomic) double outerGain;
- (void)setInnerAngle:(double)innerAngle outerAngle:(double)outerAngle;
@end
@interface PHASEConeDirectivityModelParameters : PHASEDirectivityModelParameters
- (instancetype)initWithSubbandParameters:(NSArray<PHASEConeDirectivityModelSubbandParameters *> *)subbandParameters;
@property (nonatomic, readonly, copy) NSArray<PHASEConeDirectivityModelSubbandParameters *> *subbandParameters;
@end

@interface PHASEObject : NSObject
- (instancetype)initWithEngine:(PHASEEngine *)engine;
- (BOOL)addChild:(PHASEObject *)child error:(NSError **)error;
- (void)removeChild:(PHASEObject *)child;
- (void)removeChildren;
@property (nonatomic, readonly, weak, nullable) PHASEObject *parent;
@property (nonatomic, readonly, copy) NSArray<PHASEObject *> *children;
@property (class, nonatomic, readonly) simd_float3 right;
@property (class, nonatomic, readonly) simd_float3 up;
@property (class, nonatomic, readonly) simd_float3 forward;
@property (nonatomic) simd_float4x4 transform;
@property (nonatomic) simd_float4x4 worldTransform;
@end
@interface PHASESource : PHASEObject
@property (nonatomic) double gain;
@end
@interface PHASEListener : PHASEObject
@property (nonatomic) double gain;
@property (nonatomic) PHASEAutomaticHeadTrackingFlags automaticHeadTrackingFlags;
@end
@interface PHASEMedium : NSObject
- (instancetype)initWithEngine:(PHASEEngine *)engine preset:(PHASEMediumPreset)preset;
@end
@interface PHASEMaterial : NSObject
- (instancetype)initWithEngine:(PHASEEngine *)engine preset:(PHASEMaterialPreset)preset;
@end

@interface PHASEMixerDefinition : PHASEDefinition
@property (nonatomic) double gain;
@property (nonatomic, strong, nullable) PHASENumberMetaParameterDefinition *gainMetaParameterDefinition;
@end
@interface PHASESpatialPipelineEntry : NSObject
@property (nonatomic) double sendLevel;
@property (nonatomic, strong, nullable) PHASENumberMetaParameterDefinition *sendLevelMetaParameterDefinition;
@end
@interface PHASESpatialPipeline : NSObject
- (nullable instancetype)initWithFlags:(PHASESpatialPipelineFlags)flags;
@property (nonatomic, readonly) PHASESpatialPipelineFlags flags;
@property (nonatomic, readonly, copy) NSDictionary<PHASESpatialCategory, PHASESpatialPipelineEntry *> *entries;
@end
@interface PHASESpatialMixerDefinition : PHASEMixerDefinition
- (instancetype)initWithSpatialPipeline:(PHASESpatialPipeline *)spatialPipeline;
- (instancetype)initWithSpatialPipeline:(PHASESpatialPipeline *)spatialPipeline identifier:(NSString *)identifier;
@property (nonatomic, readonly, strong) PHASESpatialPipeline *spatialPipeline;
@property (nonatomic, strong, nullable) PHASEDistanceModelParameters *distanceModelParameters;
@property (nonatomic, strong, nullable) PHASEDirectivityModelParameters *listenerDirectivityModelParameters;
@property (nonatomic, strong, nullable) PHASEDirectivityModelParameters *sourceDirectivityModelParameters;
@end
@interface PHASEChannelMixerDefinition : PHASEMixerDefinition
- (instancetype)initWithChannelLayout:(AVAudioChannelLayout *)layout;
- (instancetype)initWithChannelLayout:(AVAudioChannelLayout *)layout identifier:(NSString *)identifier;
@property (nonatomic, readonly, strong) AVAudioChannelLayout *inputChannelLayout;
@end
@interface PHASEAmbientMixerDefinition : PHASEMixerDefinition
- (instancetype)initWithChannelLayout:(AVAudioChannelLayout *)layout orientation:(simd_quatf)orientation;
- (instancetype)initWithChannelLayout:(AVAudioChannelLayout *)layout orientation:(simd_quatf)orientation identifier:(NSString *)identifier;
@property (nonatomic, readonly, strong) AVAudioChannelLayout *inputChannelLayout;
@property (nonatomic, readonly) simd_quatf orientation;
@end
@interface PHASEMixer : NSObject
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic) double gain;
@property (nonatomic, readonly, strong, nullable) PHASEMetaParameter *gainMetaParameter;
@end
@interface PHASEMixerParameters : NSObject
- (void)addSpatialMixerParametersWithIdentifier:(NSString *)identifier source:(PHASESource *)source listener:(PHASEListener *)listener;
- (void)addAmbientMixerParametersWithIdentifier:(NSString *)identifier listener:(PHASEListener *)listener;
@end

@interface PHASESoundEventNodeDefinition : PHASEDefinition
@property (nonatomic, readonly, copy) NSArray<PHASESoundEventNodeDefinition *> *children;
@end
@interface PHASEGeneratorNodeDefinition : PHASESoundEventNodeDefinition
- (void)setCalibrationMode:(PHASECalibrationMode)calibrationMode level:(double)level;
@property (nonatomic, readonly) PHASECalibrationMode calibrationMode;
@property (nonatomic, readonly) double level;
@property (nonatomic) double rate;
@property (nonatomic, weak, nullable) PHASEGroup *group;
@property (nonatomic, strong, nullable) PHASENumberMetaParameterDefinition *gainMetaParameterDefinition;
@property (nonatomic, strong, nullable) PHASENumberMetaParameterDefinition *rateMetaParameterDefinition;
@property (nonatomic, readonly, strong) PHASEMixerDefinition *mixerDefinition;
@end
@interface PHASESamplerNodeDefinition : PHASEGeneratorNodeDefinition
- (instancetype)initWithSoundAssetIdentifier:(NSString *)soundAssetIdentifier mixerDefinition:(PHASEMixerDefinition *)mixerDefinition;
- (instancetype)initWithSoundAssetIdentifier:(NSString *)soundAssetIdentifier mixerDefinition:(PHASEMixerDefinition *)mixerDefinition
                                  identifier:(NSString *)identifier;
@property (nonatomic, readonly) NSString *assetIdentifier;
@property (nonatomic) PHASEPlaybackMode playbackMode;
@property (nonatomic) PHASECullOption cullOption;
@end
@interface PHASEPushStreamNodeDefinition : PHASEGeneratorNodeDefinition
- (instancetype)initWithMixerDefinition:(PHASEMixerDefinition *)mixerDefinition format:(AVAudioFormat *)format;
- (instancetype)initWithMixerDefinition:(PHASEMixerDefinition *)mixerDefinition format:(AVAudioFormat *)format identifier:(NSString *)identifier;
@property (nonatomic, readonly, strong) AVAudioFormat *format;
@property (nonatomic) BOOL normalize;
@end
@interface PHASEPullStreamNodeDefinition : PHASEGeneratorNodeDefinition
- (instancetype)initWithMixerDefinition:(PHASEMixerDefinition *)mixerDefinition format:(AVAudioFormat *)format;
- (instancetype)initWithMixerDefinition:(PHASEMixerDefinition *)mixerDefinition format:(AVAudioFormat *)format identifier:(NSString *)identifier;
@property (nonatomic, readonly, strong) AVAudioFormat *format;
@property (nonatomic) BOOL normalize;
@end
@interface PHASESwitchNodeDefinition : PHASESoundEventNodeDefinition
- (instancetype)initWithSwitchMetaParameterDefinition:(PHASEStringMetaParameterDefinition *)switchMetaParameterDefinition;
- (instancetype)initWithSwitchMetaParameterDefinition:(PHASEStringMetaParameterDefinition *)switchMetaParameterDefinition identifier:(NSString *)identifier;
- (void)addSubtree:(PHASESoundEventNodeDefinition *)subtree switchValue:(NSString *)switchValue;
@property (nonatomic, readonly, strong) PHASEStringMetaParameterDefinition *switchMetaParameterDefinition;
@end
@interface PHASERandomNodeDefinition : PHASESoundEventNodeDefinition
- (instancetype)init;
- (instancetype)initWithIdentifier:(NSString *)identifier;
- (void)addSubtree:(PHASESoundEventNodeDefinition *)subtree weight:(NSNumber *)weight;
@property (nonatomic) NSInteger uniqueSelectionQueueLength;
@end
@interface PHASEBlendNodeDefinition : PHASESoundEventNodeDefinition
- (instancetype)initWithBlendMetaParameterDefinition:(PHASENumberMetaParameterDefinition *)blendMetaParameterDefinition;
- (instancetype)initWithBlendMetaParameterDefinition:(PHASENumberMetaParameterDefinition *)blendMetaParameterDefinition identifier:(NSString *)identifier;
- (instancetype)initDistanceBlendWithSpatialMixerDefinition:(PHASESpatialMixerDefinition *)spatialMixerDefinition;
- (instancetype)initDistanceBlendWithSpatialMixerDefinition:(PHASESpatialMixerDefinition *)spatialMixerDefinition identifier:(NSString *)identifier;
- (void)addRangeWithEnvelope:(PHASEEnvelope *)envelope subtree:(PHASESoundEventNodeDefinition *)subtree;
- (void)addRangeForInputValuesAbove:(double)value fullGainAtValue:(double)fullGainAtValue fadeCurveType:(PHASECurveType)fadeCurveType
                            subtree:(PHASESoundEventNodeDefinition *)subtree;
- (void)addRangeForInputValuesBelow:(double)value fullGainAtValue:(double)fullGainAtValue fadeCurveType:(PHASECurveType)fadeCurveType
                            subtree:(PHASESoundEventNodeDefinition *)subtree;
- (void)addRangeForInputValuesBetween:(double)lowValue highValue:(double)highValue fullGainAtLowValue:(double)fullGainAtLowValue
                  fullGainAtHighValue:(double)fullGainAtHighValue lowFadeCurveType:(PHASECurveType)lowFadeCurveType
                     highFadeCurveType:(PHASECurveType)highFadeCurveType subtree:(PHASESoundEventNodeDefinition *)subtree;
@property (nonatomic, readonly, strong, nullable) PHASENumberMetaParameterDefinition *blendParameterDefinition;
@property (nonatomic, readonly, strong, nullable) PHASESpatialMixerDefinition *spatialMixerDefinitionForDistance;
@end
@interface PHASEContainerNodeDefinition : PHASESoundEventNodeDefinition
- (instancetype)init;
- (instancetype)initWithIdentifier:(NSString *)identifier;
- (void)addSubtree:(PHASESoundEventNodeDefinition *)subtree;
@end

@interface PHASEAsset : NSObject
@property (nonatomic, readonly) NSString *identifier;
@end
@interface PHASESoundAsset : PHASEAsset
@property (nonatomic, readonly, nullable) NSURL *url;
@property (nonatomic, readonly, nullable) NSData *data;
@property (nonatomic, readonly) PHASEAssetType type;
@end
@interface PHASESoundEventNodeAsset : PHASEAsset
@end
@interface PHASEGlobalMetaParameterAsset : PHASEAsset
@end
@interface PHASEAssetRegistry : NSObject
- (nullable PHASESoundAsset *)registerSoundAssetAtURL:(NSURL *)url identifier:(nullable NSString *)identifier assetType:(PHASEAssetType)assetType
                                        channelLayout:(nullable AVAudioChannelLayout *)channelLayout
                                    normalizationMode:(PHASENormalizationMode)normalizationMode error:(NSError **)error;
- (nullable PHASESoundAsset *)registerSoundAssetWithData:(NSData *)data identifier:(nullable NSString *)identifier format:(AVAudioFormat *)format
                                       normalizationMode:(PHASENormalizationMode)normalizationMode error:(NSError **)error;
- (nullable PHASESoundEventNodeAsset *)registerSoundEventAssetWithRootNode:(PHASESoundEventNodeDefinition *)rootNode
                                                                identifier:(nullable NSString *)identifier error:(NSError **)error;
- (nullable PHASEGlobalMetaParameterAsset *)registerGlobalMetaParameter:(PHASEMetaParameterDefinition *)metaParameterDefinition error:(NSError **)error;
- (void)unregisterAssetWithIdentifier:(NSString *)identifier completion:(nullable void (^)(bool success))handler;
- (nullable PHASEAsset *)assetForIdentifier:(NSString *)identifier;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, PHASEMetaParameter *> *globalMetaParameters;
@end

typedef OSStatus (^PHASEPullStreamRenderHandler)(BOOL *isSilence, const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, AudioBufferList *outputData);
@interface PHASEStreamNode : NSObject
@property (nonatomic, readonly, strong, nullable) PHASENumberMetaParameter *gainMetaParameter;
@property (nonatomic, readonly, strong, nullable) PHASENumberMetaParameter *rateMetaParameter;
@property (nonatomic, readonly, strong) PHASEMixer *mixer;
@property (nonatomic, readonly, strong) AVAudioFormat *format;
@end
@interface PHASEPushStreamNode : PHASEStreamNode
- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer;
- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer completionCallbackType:(PHASEPushStreamCompletionCallbackCondition)completionCallbackType
     completionHandler:(void (^)(PHASEPushStreamCompletionCallbackCondition callbackType))completionHandler;
- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer atTime:(nullable AVAudioTime *)when options:(PHASEPushStreamBufferOptions)options;
- (void)scheduleBuffer:(AVAudioPCMBuffer *)buffer atTime:(nullable AVAudioTime *)when options:(PHASEPushStreamBufferOptions)options
 completionCallbackType:(PHASEPushStreamCompletionCallbackCondition)completionCallbackType
      completionHandler:(void (^)(PHASEPushStreamCompletionCallbackCondition callbackType))completionHandler;
@end
@interface PHASEPullStreamNode : PHASEStreamNode
@property (nonatomic, copy) PHASEPullStreamRenderHandler renderHandler;
@end

@interface PHASESoundEvent : NSObject
- (nullable instancetype)initWithEngine:(PHASEEngine *)engine assetIdentifier:(NSString *)assetIdentifier
                        mixerParameters:(nullable PHASEMixerParameters *)mixerParameters error:(NSError **)error;
- (nullable instancetype)initWithEngine:(PHASEEngine *)engine assetIdentifier:(NSString *)assetIdentifier error:(NSError **)error;
- (void)prepareWithCompletion:(nullable void (^)(PHASESoundEventPrepareHandlerReason reason))handler;
- (void)startWithCompletion:(nullable void (^)(PHASESoundEventStartHandlerReason reason))handler;
- (void)startAtTime:(nullable AVAudioTime *)when completion:(nullable void (^)(PHASESoundEventStartHandlerReason reason))handler;
- (void)seekToTime:(double)time completion:(nullable void (^)(PHASESoundEventSeekHandlerReason reason))handler;
- (void)seekToTime:(double)time resumeAtEngineTime:(AVAudioTime *)engineTime completion:(nullable void (^)(PHASESoundEventSeekHandlerReason reason))handler;
- (void)pause;
- (void)resume;
- (void)resumeAtTime:(nullable AVAudioTime *)time;
- (void)stopAndInvalidate;
@property (nonatomic, readonly) PHASERenderingState renderingState;
@property (nonatomic, readonly) PHASESoundEventPrepareState prepareState;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, PHASEMetaParameter *> *metaParameters;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, PHASEMixer *> *mixers;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, PHASEPushStreamNode *> *pushStreamNodes;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, PHASEPullStreamNode *> *pullStreamNodes;
@property (nonatomic, readonly, getter=isIndefinite) BOOL indefinite;
@end

@interface PHASEGroup : NSObject
- (instancetype)initWithIdentifier:(NSString *)identifier;
- (void)registerWithEngine:(PHASEEngine *)engine;
- (void)unregisterFromEngine;
- (void)fadeGain:(double)gain duration:(double)duration curveType:(PHASECurveType)curveType;
- (void)fadeRate:(double)rate duration:(double)duration curveType:(PHASECurveType)curveType;
- (void)mute;
- (void)unmute;
- (void)solo;
- (void)unsolo;
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic) double gain;
@property (nonatomic) double rate;
@property (nonatomic, readonly, getter=isMuted) BOOL muted;
@property (nonatomic, readonly, getter=isSoloed) BOOL soloed;
@end
@interface PHASEGroupPresetSetting : NSObject
- (instancetype)initWithGain:(double)gain rate:(double)rate gainCurveType:(PHASECurveType)gainCurveType rateCurveType:(PHASECurveType)rateCurveType;
@property (nonatomic, readonly) double gain;
@property (nonatomic, readonly) double rate;
@property (nonatomic, readonly) PHASECurveType gainCurveType;
@property (nonatomic, readonly) PHASECurveType rateCurveType;
@end
@interface PHASEGroupPreset : NSObject
- (instancetype)initWithEngine:(PHASEEngine *)engine settings:(NSDictionary<NSString *, PHASEGroupPresetSetting *> *)settings
                  timeToTarget:(double)timeToTarget timeToReset:(double)timeToReset;
- (void)activate;
- (void)activateWithTimeToTargetOverride:(double)timeToTargetOverride;
- (void)deactivate;
- (void)deactivateWithTimeToResetOverride:(double)timeToResetOverride;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, PHASEGroupPresetSetting *> *settings;
@property (nonatomic, readonly) double timeToTarget;
@property (nonatomic, readonly) double timeToReset;
@end
@interface PHASEDucker : NSObject
- (instancetype)initWithEngine:(PHASEEngine *)engine sourceGroups:(NSSet<PHASEGroup *> *)sourceGroups targetGroups:(NSSet<PHASEGroup *> *)targetGroups
                          gain:(double)gain attackTime:(double)attackTime releaseTime:(double)releaseTime attackCurve:(PHASECurveType)attackCurve
                  releaseCurve:(PHASECurveType)releaseCurve;
- (void)activate;
- (void)deactivate;
@property (nonatomic, readonly, copy) NSSet<PHASEGroup *> *sourceGroups;
@property (nonatomic, readonly, copy) NSSet<PHASEGroup *> *targetGroups;
@property (nonatomic, readonly) double gain;
@property (nonatomic, readonly) double attackTime;
@property (nonatomic, readonly) double releaseTime;
@property (nonatomic, readonly) PHASECurveType attackCurve;
@property (nonatomic, readonly) PHASECurveType releaseCurve;
@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly, getter=isActive) BOOL active;
@end

@interface PHASEEngine : NSObject
- (instancetype)initWithUpdateMode:(PHASEUpdateMode)updateMode;
- (instancetype)initWithUpdateMode:(PHASEUpdateMode)updateMode renderingMode:(PHASERenderingMode)renderingMode;
- (BOOL)startAndReturnError:(NSError **)error;
- (void)pause;
- (void)stop;
- (void)update;
@property (nonatomic, readonly, strong) PHASEAssetRegistry *assetRegistry;
@property (nonatomic, readonly, strong) PHASEObject *rootObject;
@property (nonatomic) PHASEReverbPreset defaultReverbPreset;
@property (nonatomic, strong) PHASEMedium *defaultMedium;
@property (nonatomic) PHASESpatializationMode outputSpatializationMode;
@property (nonatomic) double unitsPerMeter;
@property (nonatomic) double unitsPerSecond;
@property (nonatomic, readonly) PHASERenderingState renderingState;
@property (nonatomic, readonly, strong, nullable) AVAudioTime *lastRenderTime;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, PHASEGroup *> *groups;
@property (nonatomic, readonly, copy) NSArray<PHASEDucker *> *duckers;
@property (nonatomic, readonly, copy) NSArray<PHASESoundEvent *> *soundEvents;
@property (nonatomic, readonly, strong, nullable) PHASEGroupPreset *activeGroupPreset;
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
#endif
