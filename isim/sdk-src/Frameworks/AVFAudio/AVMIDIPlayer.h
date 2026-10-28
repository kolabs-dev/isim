#pragma once
/* isim AVFAudio: AVMIDIPlayer (AVMIDI.swift; a Standard MIDI File through a MIDISynth, issue #389). */
#import <AVFAudio/AVAudioTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef void (^AVMIDIPlayerCompletionHandler)(void);
@interface AVMIDIPlayer : NSObject
- (nullable instancetype)initWithContentsOfURL:(NSURL *)inURL soundBankURL:(nullable NSURL *)bankURL error:(NSError **)outError;
- (nullable instancetype)initWithData:(NSData *)data soundBankURL:(nullable NSURL *)bankURL error:(NSError **)outError;
- (void)prepareToPlay;
- (void)play:(nullable AVMIDIPlayerCompletionHandler)completionHandler;
- (void)stop;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic) float rate;
@property (nonatomic) NSTimeInterval currentPosition;
@end
NS_ASSUME_NONNULL_END
#endif
