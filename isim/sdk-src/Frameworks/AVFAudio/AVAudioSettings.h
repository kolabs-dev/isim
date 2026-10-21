#pragma once
/* isim AVFAudio: the settings dictionary keys of formats, files, converters and recorders (Apple's AVAudioSettings.h). */
#import <AVFAudio/AVAudioTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString * const AVFormatIDKey, * const AVSampleRateKey, * const AVNumberOfChannelsKey, * const AVChannelLayoutKey;
FOUNDATION_EXPORT NSString * const AVLinearPCMBitDepthKey, * const AVLinearPCMIsBigEndianKey, * const AVLinearPCMIsFloatKey,
    * const AVLinearPCMIsNonInterleaved;
FOUNDATION_EXPORT NSString * const AVEncoderAudioQualityKey, * const AVEncoderBitRateKey, * const AVEncoderBitRatePerChannelKey,
    * const AVEncoderBitRateStrategyKey, * const AVEncoderBitDepthHintKey;
FOUNDATION_EXPORT NSString * const AVSampleRateConverterAlgorithmKey, * const AVSampleRateConverterAudioQualityKey;
FOUNDATION_EXPORT NSString * const AVSampleRateConverterAlgorithm_Normal, * const AVSampleRateConverterAlgorithm_Mastering,
    * const AVSampleRateConverterAlgorithm_MinimumPhase;
FOUNDATION_EXPORT NSString * const AVAudioBitRateStrategy_Constant, * const AVAudioBitRateStrategy_LongTermAverage,
    * const AVAudioBitRateStrategy_VariableConstrained, * const AVAudioBitRateStrategy_Variable;
typedef NS_ENUM(NSInteger, AVAudioQuality) {
    AVAudioQualityMin = 0, AVAudioQualityLow = 0x20, AVAudioQualityMedium = 0x40, AVAudioQualityHigh = 0x60, AVAudioQualityMax = 0x7F
};
NS_ASSUME_NONNULL_END
#endif
