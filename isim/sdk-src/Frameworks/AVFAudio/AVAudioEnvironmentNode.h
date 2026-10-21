#pragma once
/* isim AVFAudio: AVAudioEnvironmentNode and its parameters (AVAudioEngine.swift; adapted: isim's spatial mixer). */
#import <AVFAudio/AVAudioNode.h>
#import <AVFAudio/AVAudioMixing.h>
#import <AVFAudio/AVAudioUnitReverb.h>
#import <AVFAudio/AVAudioUnitEQ.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, AVAudioEnvironmentDistanceAttenuationModel) {
    AVAudioEnvironmentDistanceAttenuationModelExponential = 1, AVAudioEnvironmentDistanceAttenuationModelInverse = 2,
    AVAudioEnvironmentDistanceAttenuationModelLinear = 3
};
typedef NS_ENUM(NSInteger, AVAudioEnvironmentOutputType) {
    AVAudioEnvironmentOutputTypeAuto = 0, AVAudioEnvironmentOutputTypeHeadphones = 1, AVAudioEnvironmentOutputTypeBuiltInSpeakers = 2,
    AVAudioEnvironmentOutputTypeExternalSpeakers = 3
};
@interface AVAudioEnvironmentDistanceAttenuationParameters : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic) AVAudioEnvironmentDistanceAttenuationModel distanceAttenuationModel;
@property (nonatomic) float referenceDistance;
@property (nonatomic) float maximumDistance;
@property (nonatomic) float rolloffFactor;
@end
@interface AVAudioEnvironmentReverbParameters : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic) BOOL enable;
@property (nonatomic) float level;
@property (nonatomic, readonly) AVAudioUnitEQFilterParameters *filterParameters;
- (void)loadFactoryReverbPreset:(AVAudioUnitReverbPreset)preset;
@end
@interface AVAudioEnvironmentNode : AVAudioNode <AVAudioMixing>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
@property (nonatomic) AVAudioEnvironmentOutputType outputType;
@property (nonatomic) float outputVolume;
@property (nonatomic, readonly) AVAudioNodeBus nextAvailableInputBus;
@property (nonatomic) AVAudio3DPoint listenerPosition;
@property (nonatomic) AVAudio3DVectorOrientation listenerVectorOrientation;
@property (nonatomic) AVAudio3DAngularOrientation listenerAngularOrientation;
@property (nonatomic, readonly) AVAudioEnvironmentDistanceAttenuationParameters *distanceAttenuationParameters;
@property (nonatomic, readonly) AVAudioEnvironmentReverbParameters *reverbParameters;
@property (nonatomic, readonly) NSArray<NSNumber *> *applicableRenderingAlgorithms;
@property (nonatomic, getter=isListenerHeadTrackingEnabled) BOOL listenerHeadTrackingEnabled;
@end
NS_ASSUME_NONNULL_END
#endif
