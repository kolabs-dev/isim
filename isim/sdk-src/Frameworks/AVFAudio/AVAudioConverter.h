#pragma once
/* isim AVFAudio: AVAudioConverter, over the overlay's class (AVAudioConverter.swift; adapted: AudioToolbox's converter). */
#import <AVFAudio/AVAudioBuffer.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, AVAudioConverterPrimeMethod) {
    AVAudioConverterPrimeMethod_Pre = 0, AVAudioConverterPrimeMethod_Normal = 1, AVAudioConverterPrimeMethod_None = 2
};
typedef struct AVAudioConverterPrimeInfo { AVAudioFrameCount leadingFrames, trailingFrames; } AVAudioConverterPrimeInfo;
typedef NS_ENUM(NSInteger, AVAudioConverterInputStatus) {
    AVAudioConverterInputStatus_HaveData = 0, AVAudioConverterInputStatus_NoDataNow = 1, AVAudioConverterInputStatus_EndOfStream = 2
};
typedef NS_ENUM(NSInteger, AVAudioConverterOutputStatus) {
    AVAudioConverterOutputStatus_HaveData = 0, AVAudioConverterOutputStatus_InputRanDry = 1, AVAudioConverterOutputStatus_EndOfStream = 2,
    AVAudioConverterOutputStatus_Error = 3
};
typedef AVAudioBuffer * _Nullable (^AVAudioConverterInputBlock)(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus *outStatus);
@interface AVAudioConverter : NSObject
- (nullable instancetype)initFromFormat:(AVAudioFormat *)fromFormat toFormat:(AVAudioFormat *)toFormat;
- (void)reset;
@property (nonatomic, readonly) AVAudioFormat *inputFormat;
@property (nonatomic, readonly) AVAudioFormat *outputFormat;
@property (nonatomic, retain, nullable) NSArray<NSNumber *> *channelMap;
@property (nonatomic, retain, nullable) NSData *magicCookie;
@property (nonatomic, readonly) NSInteger maximumOutputPacketSize;
@property (nonatomic) BOOL downmix;
@property (nonatomic) BOOL dither;
@property (nonatomic) NSInteger sampleRateConverterQuality;
@property (nonatomic, retain, nullable) NSString *sampleRateConverterAlgorithm;
@property (nonatomic) AVAudioConverterPrimeMethod primeMethod;
@property (nonatomic) AVAudioConverterPrimeInfo primeInfo;
@property (nonatomic) NSInteger bitRate;
@property (nonatomic, retain, nullable) NSString *bitRateStrategy;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *availableEncodeBitRates;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *applicableEncodeBitRates;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *availableEncodeSampleRates;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *applicableEncodeSampleRates;
@property (nonatomic, readonly, nullable) NSArray<NSNumber *> *availableEncodeChannelLayoutTags;
- (BOOL)convertToBuffer:(AVAudioPCMBuffer *)outputBuffer fromBuffer:(const AVAudioPCMBuffer *)inputBuffer error:(NSError **)outError;
- (AVAudioConverterOutputStatus)convertToBuffer:(AVAudioBuffer *)outputBuffer error:(NSError **)outError
                             withInputFromBlock:(AVAudioConverterInputBlock)inputBlock;
@end
NS_ASSUME_NONNULL_END
#endif
