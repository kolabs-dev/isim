#pragma once
/* isim AVFAudio: AVAudioUnitReverb (AVAudioEngine.swift; adapted: Freeverb-style). */
#import <AVFAudio/AVAudioUnitEffect.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, AVAudioUnitReverbPreset) {
    AVAudioUnitReverbPresetSmallRoom = 0, AVAudioUnitReverbPresetMediumRoom = 1, AVAudioUnitReverbPresetLargeRoom = 2,
    AVAudioUnitReverbPresetMediumHall = 3, AVAudioUnitReverbPresetLargeHall = 4, AVAudioUnitReverbPresetPlate = 5,
    AVAudioUnitReverbPresetMediumChamber = 6, AVAudioUnitReverbPresetLargeChamber = 7, AVAudioUnitReverbPresetCathedral = 8,
    AVAudioUnitReverbPresetLargeRoom2 = 9, AVAudioUnitReverbPresetMediumHall2 = 10, AVAudioUnitReverbPresetMediumHall3 = 11,
    AVAudioUnitReverbPresetLargeHall2 = 12
};
@interface AVAudioUnitReverb : AVAudioUnitEffect
- (instancetype)init;
- (void)loadFactoryPreset:(AVAudioUnitReverbPreset)preset;
@property (nonatomic) float wetDryMix;
@end
NS_ASSUME_NONNULL_END
#endif
