#pragma once
/* isim AVFAudio: AVAudioUnitEQ and its bands (AVAudioEngine.swift; adapted: biquad filters). */
#import <AVFAudio/AVAudioUnitEffect.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, AVAudioUnitEQFilterType) {
    AVAudioUnitEQFilterTypeParametric = 0, AVAudioUnitEQFilterTypeLowPass = 1, AVAudioUnitEQFilterTypeHighPass = 2,
    AVAudioUnitEQFilterTypeResonantLowPass = 3, AVAudioUnitEQFilterTypeResonantHighPass = 4, AVAudioUnitEQFilterTypeBandPass = 5,
    AVAudioUnitEQFilterTypeBandStop = 6, AVAudioUnitEQFilterTypeLowShelf = 7, AVAudioUnitEQFilterTypeHighShelf = 8,
    AVAudioUnitEQFilterTypeResonantLowShelf = 9, AVAudioUnitEQFilterTypeResonantHighShelf = 10
};
@interface AVAudioUnitEQFilterParameters : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic) AVAudioUnitEQFilterType filterType;
@property (nonatomic) float frequency;
@property (nonatomic) float bandwidth;
@property (nonatomic) float gain;
@property (nonatomic) BOOL bypass;
@end
@interface AVAudioUnitEQ : AVAudioUnitEffect
- (instancetype)initWithNumberOfBands:(NSUInteger)numberOfBands;
@property (nonatomic, readonly) NSArray<AVAudioUnitEQFilterParameters *> *bands;
@property (nonatomic) float globalGain;
@end
NS_ASSUME_NONNULL_END
#endif
