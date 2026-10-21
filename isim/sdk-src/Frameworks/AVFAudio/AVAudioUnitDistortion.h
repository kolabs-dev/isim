#pragma once
/* isim AVFAudio: AVAudioUnitDistortion (AVAudioEngine.swift; adapted: soft-clipping overdrive). */
#import <AVFAudio/AVAudioUnitEffect.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, AVAudioUnitDistortionPreset) {
    AVAudioUnitDistortionPresetDrumsBitBrush = 0, AVAudioUnitDistortionPresetDrumsBufferBeats = 1, AVAudioUnitDistortionPresetDrumsLoFi = 2,
    AVAudioUnitDistortionPresetMultiBrokenSpeaker = 3, AVAudioUnitDistortionPresetMultiCellphoneConcert = 4,
    AVAudioUnitDistortionPresetMultiDecimated1 = 5, AVAudioUnitDistortionPresetMultiDecimated2 = 6, AVAudioUnitDistortionPresetMultiDecimated3 = 7,
    AVAudioUnitDistortionPresetMultiDecimated4 = 8, AVAudioUnitDistortionPresetMultiDistortedFunk = 9, AVAudioUnitDistortionPresetMultiDistortedCubed = 10,
    AVAudioUnitDistortionPresetMultiDistortedSquared = 11, AVAudioUnitDistortionPresetMultiEcho1 = 12, AVAudioUnitDistortionPresetMultiEcho2 = 13,
    AVAudioUnitDistortionPresetMultiEchoTight1 = 14, AVAudioUnitDistortionPresetMultiEchoTight2 = 15,
    AVAudioUnitDistortionPresetMultiEverythingIsBroken = 16, AVAudioUnitDistortionPresetSpeechAlienChatter = 17,
    AVAudioUnitDistortionPresetSpeechCosmicInterference = 18, AVAudioUnitDistortionPresetSpeechGoldenPi = 19,
    AVAudioUnitDistortionPresetSpeechRadioTower = 20, AVAudioUnitDistortionPresetSpeechWaves = 21
};
@interface AVAudioUnitDistortion : AVAudioUnitEffect
- (instancetype)init;
- (void)loadFactoryPreset:(AVAudioUnitDistortionPreset)preset;
@property (nonatomic) float preGain;
@property (nonatomic) float wetDryMix;
@end
NS_ASSUME_NONNULL_END
#endif
