#pragma once
/* isim AVFAudio: the AVMusicEvent classes (AVMIDI.swift, iOS 16 track editing, issue #389). */
#import <AVFAudio/AVAudioTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef double AVMusicTimeStamp;
@interface AVMusicEvent : NSObject
@end
@interface AVMIDINoteEvent : AVMusicEvent
- (instancetype)initWithChannel:(UInt32)channel key:(UInt32)keyNum velocity:(UInt32)velocity duration:(AVMusicTimeStamp)duration;
@property (nonatomic) UInt32 channel;
@property (nonatomic) UInt32 key;
@property (nonatomic) UInt32 velocity;
@property (nonatomic) AVMusicTimeStamp duration;
@end
@interface AVMIDIChannelEvent : AVMusicEvent
@property (nonatomic) UInt32 channel;
@end
typedef NS_ENUM(NSInteger, AVMIDIControlChangeMessageType) {
    AVMIDIControlChangeMessageTypeBankSelect = 0, AVMIDIControlChangeMessageTypeModWheel = 1, AVMIDIControlChangeMessageTypeBreath = 2,
    AVMIDIControlChangeMessageTypeFoot = 4, AVMIDIControlChangeMessageTypePortamentoTime = 5, AVMIDIControlChangeMessageTypeDataEntry = 6,
    AVMIDIControlChangeMessageTypeVolume = 7, AVMIDIControlChangeMessageTypeBalance = 8, AVMIDIControlChangeMessageTypePan = 10,
    AVMIDIControlChangeMessageTypeExpression = 11, AVMIDIControlChangeMessageTypeSustain = 64, AVMIDIControlChangeMessageTypePortamento = 65,
    AVMIDIControlChangeMessageTypeSostenuto = 66, AVMIDIControlChangeMessageTypeSoft = 67, AVMIDIControlChangeMessageTypeLegatoPedal = 68,
    AVMIDIControlChangeMessageTypeHold2Pedal = 69, AVMIDIControlChangeMessageTypeFilterResonance = 71, AVMIDIControlChangeMessageTypeReleaseTime = 72,
    AVMIDIControlChangeMessageTypeAttackTime = 73, AVMIDIControlChangeMessageTypeBrightness = 74, AVMIDIControlChangeMessageTypeDecayTime = 75,
    AVMIDIControlChangeMessageTypeVibratoRate = 76, AVMIDIControlChangeMessageTypeVibratoDepth = 77, AVMIDIControlChangeMessageTypeVibratoDelay = 78,
    AVMIDIControlChangeMessageTypeReverbLevel = 91, AVMIDIControlChangeMessageTypeChorusLevel = 93, AVMIDIControlChangeMessageTypeRPN_LSB = 100,
    AVMIDIControlChangeMessageTypeRPN_MSB = 101, AVMIDIControlChangeMessageTypeAllSoundOff = 120, AVMIDIControlChangeMessageTypeResetAllControllers = 121,
    AVMIDIControlChangeMessageTypeAllNotesOff = 123, AVMIDIControlChangeMessageTypeOmniModeOff = 124, AVMIDIControlChangeMessageTypeOmniModeOn = 125,
    AVMIDIControlChangeMessageTypeMonoModeOn = 126, AVMIDIControlChangeMessageTypeMonoModeOff = 127,
};
@interface AVMIDIControlChangeEvent : AVMIDIChannelEvent
- (instancetype)initWithChannel:(UInt32)channel messageType:(AVMIDIControlChangeMessageType)messageType value:(UInt32)value;
@property (nonatomic, readonly) AVMIDIControlChangeMessageType messageType;
@property (nonatomic, readonly) UInt32 value;
@end
@interface AVMIDIPolyPressureEvent : AVMIDIChannelEvent
- (instancetype)initWithChannel:(UInt32)channel key:(UInt32)key pressure:(UInt32)pressure;
@property (nonatomic) UInt32 key;
@property (nonatomic) UInt32 pressure;
@end
@interface AVMIDIProgramChangeEvent : AVMIDIChannelEvent
- (instancetype)initWithChannel:(UInt32)channel programNumber:(UInt32)programNumber;
@property (nonatomic) UInt32 programNumber;
@end
@interface AVMIDIChannelPressureEvent : AVMIDIChannelEvent
- (instancetype)initWithChannel:(UInt32)channel pressure:(UInt32)pressure;
@property (nonatomic) UInt32 pressure;
@end
@interface AVMIDIPitchBendEvent : AVMIDIChannelEvent
- (instancetype)initWithChannel:(UInt32)channel value:(UInt32)value;
@property (nonatomic) UInt32 value;
@end
@interface AVMIDISysexEvent : AVMusicEvent
- (instancetype)initWithData:(NSData *)data;
@property (nonatomic, readonly) UInt32 sizeInBytes;
@end
typedef NS_ENUM(NSInteger, AVMIDIMetaEventType) {
    AVMIDIMetaEventTypeSequenceNumber = 0x00, AVMIDIMetaEventTypeText = 0x01, AVMIDIMetaEventTypeCopyright = 0x02,
    AVMIDIMetaEventTypeTrackName = 0x03, AVMIDIMetaEventTypeInstrument = 0x04, AVMIDIMetaEventTypeLyric = 0x05,
    AVMIDIMetaEventTypeMarker = 0x06, AVMIDIMetaEventTypeCuePoint = 0x07, AVMIDIMetaEventTypeMidiChannel = 0x20,
    AVMIDIMetaEventTypeMidiPort = 0x21, AVMIDIMetaEventTypeEndOfTrack = 0x2F, AVMIDIMetaEventTypeTempo = 0x51,
    AVMIDIMetaEventTypeSmpteOffset = 0x54, AVMIDIMetaEventTypeTimeSignature = 0x58, AVMIDIMetaEventTypeKeySignature = 0x59,
    AVMIDIMetaEventTypeProprietaryEvent = 0x7F,
};
@interface AVMIDIMetaEvent : AVMusicEvent
- (instancetype)initWithType:(AVMIDIMetaEventType)type data:(NSData *)data;
@property (nonatomic, readonly) AVMIDIMetaEventType type;
@end
@interface AVMusicUserEvent : AVMusicEvent
- (instancetype)initWithData:(NSData *)data;
@property (nonatomic, readonly) UInt32 sizeInBytes;
@end
extern const MusicDeviceInstrumentID AVExtendedNoteOnEventDefaultInstrument;
@interface AVExtendedNoteOnEvent : AVMusicEvent
- (instancetype)initWithMIDINote:(float)midiNote velocity:(float)velocity groupID:(UInt32)groupID duration:(AVMusicTimeStamp)duration;
- (instancetype)initWithMIDINote:(float)midiNote velocity:(float)velocity instrumentID:(UInt32)instrumentID groupID:(UInt32)groupID
                        duration:(AVMusicTimeStamp)duration;
@property (nonatomic) float midiNote;
@property (nonatomic) float velocity;
@property (nonatomic) UInt32 instrumentID;
@property (nonatomic) UInt32 groupID;
@property (nonatomic) AVMusicTimeStamp duration;
@end
@interface AVParameterEvent : AVMusicEvent
- (instancetype)initWithParameterID:(UInt32)parameterID scope:(UInt32)scope element:(UInt32)element value:(float)value;
@property (nonatomic) UInt32 parameterID;
@property (nonatomic) UInt32 scope;
@property (nonatomic) UInt32 element;
@property (nonatomic) float value;
@end
@interface AVAUPresetEvent : AVMusicEvent
- (instancetype)initWithScope:(UInt32)scope element:(UInt32)element dictionary:(NSDictionary *)presetDictionary;
@property (nonatomic) UInt32 scope;
@property (nonatomic) UInt32 element;
@property (nonatomic, readonly, copy) NSDictionary *presetDictionary;
@end
@interface AVExtendedTempoEvent : AVMusicEvent
- (instancetype)initWithTempo:(double)tempo;
@property (nonatomic) double tempo;
@end
NS_ASSUME_NONNULL_END
#endif
