#pragma once
/* isim AVFAudio: AVAudioUnitSampler (AVMIDI.swift; SoundFont 2 presets, .aupreset and audio files, issue #389). */
#import <AVFAudio/AVAudioUnitMIDIInstrument.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioUnitSampler : AVAudioUnitMIDIInstrument
- (instancetype)init;
- (BOOL)loadSoundBankInstrumentAtURL:(NSURL *)bankURL program:(uint8_t)program bankMSB:(uint8_t)bankMSB bankLSB:(uint8_t)bankLSB
                               error:(NSError **)outError;
- (BOOL)loadInstrumentAtURL:(NSURL *)instrumentURL error:(NSError **)outError;
- (BOOL)loadAudioFilesAtURLs:(NSArray<NSURL *> *)audioFiles error:(NSError **)outError;
@property (nonatomic) float stereoPan;
@property (nonatomic) float overallGain;
@property (nonatomic) float masterGain __attribute__((deprecated("use overallGain")));
@property (nonatomic) float globalTuning;
@end
NS_ASSUME_NONNULL_END
#endif
