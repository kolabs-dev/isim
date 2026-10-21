#pragma once
/* isim AVFAudio: the mixing protocols and AVAudioMixingDestination (AVAudioEngine.swift). */
#import <AVFAudio/AVAudioTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class AVAudioNode, AVAudioConnectionPoint, AVAudioMixingDestination;
typedef NS_ENUM(NSInteger, AVAudio3DMixingRenderingAlgorithm) {
    AVAudio3DMixingRenderingAlgorithmEqualPowerPanning = 0, AVAudio3DMixingRenderingAlgorithmSphericalHead = 1,
    AVAudio3DMixingRenderingAlgorithmHRTF = 2, AVAudio3DMixingRenderingAlgorithmSoundField = 3, AVAudio3DMixingRenderingAlgorithmStereoPassThrough = 5,
    AVAudio3DMixingRenderingAlgorithmHRTFHQ = 6, AVAudio3DMixingRenderingAlgorithmAuto = 7
};
typedef NS_ENUM(NSInteger, AVAudio3DMixingSourceMode) {
    AVAudio3DMixingSourceModeSpatializeIfMono = 0, AVAudio3DMixingSourceModeBypass = 1, AVAudio3DMixingSourceModePointSource = 2,
    AVAudio3DMixingSourceModeAmbienceBed = 3
};
typedef NS_ENUM(NSInteger, AVAudio3DMixingPointSourceInHeadMode) {
    AVAudio3DMixingPointSourceInHeadModeMono = 0, AVAudio3DMixingPointSourceInHeadModeBypass = 1
};
@protocol AVAudioStereoMixing <NSObject>
@property (nonatomic) float pan;
@end
@protocol AVAudio3DMixing <NSObject>
@property (nonatomic) AVAudio3DMixingRenderingAlgorithm renderingAlgorithm;
@property (nonatomic) AVAudio3DMixingSourceMode sourceMode;
@property (nonatomic) AVAudio3DMixingPointSourceInHeadMode pointSourceInHeadMode;
@property (nonatomic) float rate;
@property (nonatomic) float reverbBlend;
@property (nonatomic) float obstruction;
@property (nonatomic) float occlusion;
@property (nonatomic) AVAudio3DPoint position;
@end
@protocol AVAudioMixing <AVAudioStereoMixing, AVAudio3DMixing>
- (nullable AVAudioMixingDestination *)destinationForMixer:(AVAudioNode *)mixer bus:(AVAudioNodeBus)bus;
@property (nonatomic) float volume;
@end
@interface AVAudioMixingDestination : NSObject <AVAudioMixing>
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) AVAudioConnectionPoint *connectionPoint;
@end
NS_ASSUME_NONNULL_END
#endif
