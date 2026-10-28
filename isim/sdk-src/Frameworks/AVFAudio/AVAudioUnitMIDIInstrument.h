#pragma once
/* isim AVFAudio: AVAudioUnitMIDIInstrument (AVMIDI.swift, issue #389). */
#import <AVFAudio/AVAudioUnit.h>
#import <AVFAudio/AVAudioMixing.h>
#import <CoreMIDI/CoreMIDI.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioUnitMIDIInstrument : AVAudioUnit <AVAudioMixing>
- (instancetype)initWithAudioComponentDescription:(AudioComponentDescription)description;
- (void)startNote:(uint8_t)note withVelocity:(uint8_t)velocity onChannel:(uint8_t)channel;
- (void)stopNote:(uint8_t)note onChannel:(uint8_t)channel;
- (void)sendController:(uint8_t)controller withValue:(uint8_t)value onChannel:(uint8_t)channel;
- (void)sendPitchBend:(uint16_t)pitchbend onChannel:(uint8_t)channel;
- (void)sendPressure:(uint8_t)pressure onChannel:(uint8_t)channel;
- (void)sendPressureForKey:(uint8_t)key withValue:(uint8_t)value onChannel:(uint8_t)channel;
- (void)sendProgramChange:(uint8_t)program onChannel:(uint8_t)channel;
- (void)sendProgramChange:(uint8_t)program bankMSB:(uint8_t)bankMSB bankLSB:(uint8_t)bankLSB onChannel:(uint8_t)channel;
- (void)sendMIDIEvent:(uint8_t)midiStatus data1:(uint8_t)data1 data2:(uint8_t)data2;
- (void)sendMIDIEvent:(uint8_t)midiStatus data1:(uint8_t)data1;
- (void)sendMIDISysExEvent:(NSData *)midiData;
- (void)sendMIDIEventList:(const struct MIDIEventList *)eventList;
@end
NS_ASSUME_NONNULL_END
#endif
