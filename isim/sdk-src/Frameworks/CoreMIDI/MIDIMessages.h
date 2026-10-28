#pragma once
/* isim CoreMIDI: Universal MIDI Packet messages. The constructors are inline, like Apple's, and build the words the
   MIDI 2.0 specification (M2-104-UM) defines. */
#include <CoreMIDI/MIDIServices.h>

CF_EXTERN_C_BEGIN
CF_ASSUME_NONNULL_BEGIN

typedef CF_ENUM(unsigned int, MIDIMessageType) {
    kMIDIMessageTypeUtility = 0x0,
    kMIDIMessageTypeSystem = 0x1,
    kMIDIMessageTypeChannelVoice1 = 0x2,
    kMIDIMessageTypeSysEx = 0x3,
    kMIDIMessageTypeChannelVoice2 = 0x4,
    kMIDIMessageTypeData128 = 0x5,
    kMIDIMessageTypeFlexData = 0xD,
    kMIDIMessageTypeStream = 0xF,
    kMIDIMessageTypeUnknownF = kMIDIMessageTypeStream,
};

typedef CF_ENUM(unsigned int, MIDICVStatus) {
    kMIDICVStatusNoteOff = 0x8,
    kMIDICVStatusNoteOn = 0x9,
    kMIDICVStatusPolyPressure = 0xA,
    kMIDICVStatusControlChange = 0xB,
    kMIDICVStatusProgramChange = 0xC,
    kMIDICVStatusChannelPressure = 0xD,
    kMIDICVStatusPitchBend = 0xE,
    kMIDICVStatusRegisteredPNC = 0x0,
    kMIDICVStatusAssignablePNC = 0x1,
    kMIDICVStatusRegisteredControl = 0x2,
    kMIDICVStatusAssignableControl = 0x3,
    kMIDICVStatusRelRegisteredControl = 0x4,
    kMIDICVStatusRelAssignableControl = 0x5,
    kMIDICVStatusPerNotePitchBend = 0x6,
    kMIDICVStatusPerNoteMgmt = 0xF,
};

typedef CF_ENUM(unsigned int, MIDISystemStatus) {
    kMIDIStatusStartOfExclusive = 0xF0,
    kMIDIStatusEndOfExclusive = 0xF7,
    kMIDIStatusMTC = 0xF1,
    kMIDIStatusSongPosPointer = 0xF2,
    kMIDIStatusSongSelect = 0xF3,
    kMIDIStatusTuneRequest = 0xF6,
    kMIDIStatusTimingClock = 0xF8,
    kMIDIStatusStart = 0xFA,
    kMIDIStatusContinue = 0xFB,
    kMIDIStatusStop = 0xFC,
    kMIDIStatusActiveSending = 0xFE,
    kMIDIStatusActiveSensing = kMIDIStatusActiveSending,
    kMIDIStatusSystemReset = 0xFF,
};

typedef CF_ENUM(unsigned int, MIDISysExStatus) {
    kMIDISysExStatusComplete = 0x0,
    kMIDISysExStatusStart = 0x1,
    kMIDISysExStatusContinue = 0x2,
    kMIDISysExStatusEnd = 0x3,
    kMIDISysExStatusMixedDataSetHeader = 0x8,
    kMIDISysExStatusMixedDataSetPayload = 0x9,
};

typedef CF_ENUM(unsigned int, MIDIUtilityStatus) {
    kMIDIUtilityStatusNOOP = 0x0,
    kMIDIUtilityStatusJitterReductionClock = 0x1,
    kMIDIUtilityStatusJitterReductionTimestamp = 0x2,
    kMIDIUtilityStatusDeltaClockstampTicksPerQuarterNote = 0x3,
    kMIDIUtilityStatusTicksSinceLastEvent = 0x4,
};

typedef CF_ENUM(UInt8, UMPStreamMessageFormat) {
    kUMPStreamMessageFormatComplete = 0x00,
    kUMPStreamMessageFormatStart = 0x01,
    kUMPStreamMessageFormatContinuing = 0x02,
    kUMPStreamMessageFormatEnd = 0x03,
};

typedef CF_ENUM(unsigned int, UMPStreamMessageStatus) {
    kUMPStreamMessageStatusEndpointDiscovery = 0x00,
    kUMPStreamMessageStatusEndpointInfoNotification = 0x01,
    kUMPStreamMessageStatusDeviceIdentityNotification = 0x02,
    kUMPStreamMessageStatusEndpointNameNotification = 0x03,
    kUMPStreamMessageStatusProductInstanceIDNotification = 0x04,
    kUMPStreamMessageStatusStreamConfigurationRequest = 0x05,
    kUMPStreamMessageStatusStreamConfigurationNotification = 0x06,
    kUMPStreamMessageStatusFunctionBlockDiscovery = 0x10,
    kUMPStreamMessageStatusFunctionBlockInfoNotification = 0x11,
    kUMPStreamMessageStatusFunctionBlockNameNotification = 0x12,
    kUMPStreamMessageStatusStartOfClip = 0x20,
    kUMPStreamMessageStatusEndOfClip = 0x21,
};

typedef CF_ENUM(UInt8, MIDINoteAttribute) {
    kMIDINoteAttributeNone = 0x0,
    kMIDINoteAttributeManufacturerSpecific = 0x1,
    kMIDINoteAttributeProfileSpecific = 0x2,
    kMIDINoteAttributePitch = 0x3,
};

typedef CF_OPTIONS(UInt8, MIDIProgramChangeOptions) {
    kMIDIProgramChangeBankValid = 0x1,
};

typedef CF_OPTIONS(UInt8, MIDIPerNoteManagementOptions) {
    kMIDIPerNoteManagementReset = 0x1,
    kMIDIPerNoteManagementDetach = 0x2,
};

/* the unsigned integer widths of the specification's fields */
typedef UInt8 MIDIUInteger2;
typedef UInt8 MIDIUInteger4;
typedef UInt8 MIDIUInteger7;
typedef UInt16 MIDIUInteger14;
typedef UInt32 MIDIUInteger28;
static const MIDIUInteger2 kMIDIUInteger2Max = 0x3;
static const MIDIUInteger4 kMIDIUInteger4Max = 0xF;
static const MIDIUInteger7 kMIDIUInteger7Max = 0x7F;
static const MIDIUInteger14 kMIDIUInteger14Max = 0x3FFF;
static const MIDIUInteger28 kMIDIUInteger28Max = 0xFFFFFFF;
typedef UInt8 MIDIUMPGroupNumber;
typedef UInt8 MIDIUMPFunctionBlockID;
typedef UInt8 MIDIChannelNumber;
static const UInt8 kMIDI1UPMaxSysexSize = 6;

typedef CF_ENUM(UInt8, MIDIUMPFunctionBlockMIDI1Info) {
    kMIDIUMPFunctionBlockMIDI1InfoNotMIDI1 = 0,
    kMIDIUMPFunctionBlockMIDI1InfoUnrestrictedBandwidth = 1,
    kMIDIUMPFunctionBlockMIDI1InfoRestrictedBandwidth = 2,
};
typedef CF_ENUM(UInt8, MIDIUMPFunctionBlockUIHint) {
    kMIDIUMPFunctionBlockUIHintUnknown = 0,
    kMIDIUMPFunctionBlockUIHintReceiver = 1,
    kMIDIUMPFunctionBlockUIHintSender = 2,
    kMIDIUMPFunctionBlockUIHintSenderReceiver = 3,
};
typedef CF_ENUM(UInt8, MIDIUMPFunctionBlockDirection) {
    kMIDIUMPFunctionBlockDirectionUnknown = 0,
    kMIDIUMPFunctionBlockDirectionInput = 1,
    kMIDIUMPFunctionBlockDirectionOutput = 2,
    kMIDIUMPFunctionBlockDirectionBidirectional = 3,
};

typedef UInt32 MIDIMessage_32;
typedef struct MIDIMessage_64 { UInt32 word0; UInt32 word1; } MIDIMessage_64;
typedef struct MIDIMessage_96 { UInt32 word0; UInt32 word1; UInt32 word2; } MIDIMessage_96;
typedef struct MIDIMessage_128 { UInt32 word0; UInt32 word1; UInt32 word2; UInt32 word3; } MIDIMessage_128;

/* a decoded message (MIDIEventListForEachEvent) */
typedef struct MIDIUniversalMessage {
    MIDIMessageType type;
    UInt8 group;
    UInt8 reserved[3];
    union {
        struct {
            MIDIUtilityStatus status;
            union {
                UInt16 jitterReductionClock;
                UInt16 jitterReductionTimestamp;
                UInt16 deltaClockstampTicksPerQuarterNote;
                UInt32 ticksSinceLastEvent;
            };
        } utility;
        struct {
            MIDISystemStatus status;
            union {
                UInt8 timeCode;
                UInt16 songPositionPointer;
                UInt8 songSelect;
            };
        } system;
        struct {
            MIDICVStatus status;
            UInt8 channel;
            UInt8 reserved[3];
            union {
                struct { UInt8 number; UInt8 velocity; } note;
                struct { UInt8 noteNumber; UInt8 pressure; } polyPressure;
                struct { UInt8 index; UInt8 data; } controlChange;
                UInt8 program;
                UInt8 channelPressure;
                UInt16 pitchBend;
            };
        } channelVoice1;
        struct {
            MIDISysExStatus status;
            UInt8 channel;
            UInt8 data[6];
            UInt8 reserved;
        } sysEx;
        struct {
            MIDICVStatus status;
            UInt8 channel;
            UInt8 reserved[3];
            union {
                struct { UInt8 number; MIDINoteAttribute attributeType; UInt16 velocity; UInt16 attributeData; } note;
                struct { UInt8 noteNumber; UInt32 pressure; } polyPressure;
                struct { UInt8 index; UInt32 data; } controlChange;
                struct { MIDIProgramChangeOptions options; UInt8 program; UInt8 reserved[2]; UInt16 bank; } programChange;
                UInt32 channelPressure;
                UInt32 pitchBend;
                struct { UInt8 noteNumber; UInt8 reserved; UInt16 index; UInt32 data; } perNoteController;
                struct { UInt8 noteNumber; MIDIPerNoteManagementOptions options; } perNoteManagement;
                struct { UInt8 noteNumber; UInt32 bend; } perNotePitchBend;
                struct { UInt8 bank; UInt8 index; UInt32 data; } controller;
            };
        } channelVoice2;
        struct {
            MIDISysExStatus status;
            UInt8 byteCount;
            UInt8 streamID;
            UInt8 data[13];
            UInt8 reserved;
        } data128;
        struct {
            UInt32 words[4];
        } unknown;
    };
} MIDIUniversalMessage;

typedef void (*MIDIEventVisitor)(void *context, MIDITimeStamp timeStamp, MIDIUniversalMessage message);
void MIDIEventListForEachEvent(const MIDIEventList * _Null_unspecified evtlist, MIDIEventVisitor _Null_unspecified visitor, void * _Null_unspecified visitorContext);

/* message type of a packet's first word */
CF_INLINE MIDIMessageType MIDIMessageTypeForUPWord(const UInt32 word) { return (MIDIMessageType)(word >> 28 & 0x0F); }

/* MIDI 1.0 messages in Universal MIDI Packets (one word) */
CF_INLINE MIDIMessage_32 MIDI1UPChannelVoiceMessage(UInt8 group, UInt8 status, UInt8 channel, UInt8 data1, UInt8 data2) {
    return (MIDIMessage_32)((UInt32)kMIDIMessageTypeChannelVoice1 << 28 | (UInt32)(group & 0xF) << 24
                            | (UInt32)((status & 0xF) << 4 | (channel & 0xF)) << 16 | (UInt32)(data1 & 0x7F) << 8 | (data2 & 0x7F));
}
CF_INLINE MIDIMessage_32 MIDI1UPNoteOff(UInt8 group, UInt8 channel, UInt8 noteNumber, UInt8 velocity) {
    return MIDI1UPChannelVoiceMessage(group, kMIDICVStatusNoteOff, channel, noteNumber, velocity);
}
CF_INLINE MIDIMessage_32 MIDI1UPNoteOn(UInt8 group, UInt8 channel, UInt8 noteNumber, UInt8 velocity) {
    return MIDI1UPChannelVoiceMessage(group, kMIDICVStatusNoteOn, channel, noteNumber, velocity);
}
CF_INLINE MIDIMessage_32 MIDI1UPPolyPressure(UInt8 group, UInt8 channel, UInt8 noteNumber, UInt8 value) {
    return MIDI1UPChannelVoiceMessage(group, kMIDICVStatusPolyPressure, channel, noteNumber, value);
}
CF_INLINE MIDIMessage_32 MIDI1UPControlChange(UInt8 group, UInt8 channel, UInt8 index, UInt8 data) {
    return MIDI1UPChannelVoiceMessage(group, kMIDICVStatusControlChange, channel, index, data);
}
CF_INLINE MIDIMessage_32 MIDI1UPProgramChange(UInt8 group, UInt8 channel, UInt8 program) {
    return MIDI1UPChannelVoiceMessage(group, kMIDICVStatusProgramChange, channel, program, 0);
}
CF_INLINE MIDIMessage_32 MIDI1UPChannelPressure(UInt8 group, UInt8 channel, UInt8 value) {
    return MIDI1UPChannelVoiceMessage(group, kMIDICVStatusChannelPressure, channel, value, 0);
}
CF_INLINE MIDIMessage_32 MIDI1UPPitchBend(UInt8 group, UInt8 channel, UInt8 lsb, UInt8 msb) {
    return MIDI1UPChannelVoiceMessage(group, kMIDICVStatusPitchBend, channel, lsb, msb);
}
CF_INLINE MIDIMessage_32 MIDI1UPSystemCommon(UInt8 group, UInt8 status, UInt8 byte1, UInt8 byte2) {
    return (MIDIMessage_32)((UInt32)kMIDIMessageTypeSystem << 28 | (UInt32)(group & 0xF) << 24 | (UInt32)status << 16
                            | (UInt32)(byte1 & 0x7F) << 8 | (byte2 & 0x7F));
}
/* up to six bytes of a system-exclusive message (two words) */
CF_INLINE MIDIMessage_64 MIDI1UPSysEx(UInt8 group, UInt8 status, UInt8 bytesUsed, UInt8 byte1, UInt8 byte2, UInt8 byte3,
                                      UInt8 byte4, UInt8 byte5, UInt8 byte6) {
    MIDIMessage_64 m = {
        (UInt32)kMIDIMessageTypeSysEx << 28 | (UInt32)(group & 0xF) << 24 | (UInt32)(status & 0xF) << 20
            | (UInt32)(bytesUsed & 0xF) << 16 | (UInt32)(byte1 & 0x7F) << 8 | (byte2 & 0x7F),
        (UInt32)(byte3 & 0x7F) << 24 | (UInt32)(byte4 & 0x7F) << 16 | (UInt32)(byte5 & 0x7F) << 8 | (byte6 & 0x7F) };
    return m;
}
CF_INLINE MIDIMessage_64 MIDI1UPSysExArray(UInt8 group, UInt8 status, const Byte * _Null_unspecified begin, const Byte * _Null_unspecified end) {
    Byte b[6] = { 0, 0, 0, 0, 0, 0 };
    UInt8 n = 0;
    for (const Byte *p = begin; p < end && n < 6; p++) b[n++] = *p;
    return MIDI1UPSysEx(group, status, n, b[0], b[1], b[2], b[3], b[4], b[5]);
}

/* MIDI 2.0 channel voice messages (two words) */
CF_INLINE MIDIMessage_64 MIDI2ChannelVoiceMessage(UInt8 group, UInt8 status, UInt8 channel, UInt16 index, UInt32 value) {
    MIDIMessage_64 m = { (UInt32)kMIDIMessageTypeChannelVoice2 << 28 | (UInt32)(group & 0xF) << 24
                             | (UInt32)((status & 0xF) << 4 | (channel & 0xF)) << 16 | index, value };
    return m;
}
CF_INLINE MIDIMessage_64 MIDI2NoteOn(UInt8 group, UInt8 channel, UInt8 noteNumber, UInt8 attributeType, UInt16 velocity, UInt16 attributeData) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusNoteOn, channel, (UInt16)((noteNumber & 0x7F) << 8 | attributeType),
                                    (UInt32)velocity << 16 | attributeData);
}
CF_INLINE MIDIMessage_64 MIDI2NoteOff(UInt8 group, UInt8 channel, UInt8 noteNumber, UInt8 attributeType, UInt16 velocity, UInt16 attributeData) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusNoteOff, channel, (UInt16)((noteNumber & 0x7F) << 8 | attributeType),
                                    (UInt32)velocity << 16 | attributeData);
}
CF_INLINE MIDIMessage_64 MIDI2PolyPressure(UInt8 group, UInt8 channel, UInt8 noteNumber, UInt32 value) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusPolyPressure, channel, (UInt16)((noteNumber & 0x7F) << 8), value);
}
CF_INLINE MIDIMessage_64 MIDI2RegisteredPNC(UInt8 group, UInt8 channel, UInt8 noteNumber, UInt8 index, UInt32 value) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusRegisteredPNC, channel, (UInt16)((noteNumber & 0x7F) << 8 | index), value);
}
CF_INLINE MIDIMessage_64 MIDI2AssignablePNC(UInt8 group, UInt8 channel, UInt8 noteNumber, UInt8 index, UInt32 value) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusAssignablePNC, channel, (UInt16)((noteNumber & 0x7F) << 8 | index), value);
}
CF_INLINE MIDIMessage_64 MIDI2PerNoteManagment(UInt8 group, UInt8 channel, UInt8 noteNumber, bool detachPNCs, bool resetPNCsToDefault) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusPerNoteMgmt, channel,
                                    (UInt16)((noteNumber & 0x7F) << 8 | (detachPNCs ? 0x2 : 0) | (resetPNCsToDefault ? 0x1 : 0)), 0);
}
CF_INLINE MIDIMessage_64 MIDI2ControlChange(UInt8 group, UInt8 channel, UInt8 index, UInt32 value) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusControlChange, channel, (UInt16)((index & 0x7F) << 8), value);
}
CF_INLINE MIDIMessage_64 MIDI2RegisteredControl(UInt8 group, UInt8 channel, UInt8 bank, UInt8 index, UInt32 value) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusRegisteredControl, channel, (UInt16)((bank & 0x7F) << 8 | (index & 0x7F)), value);
}
CF_INLINE MIDIMessage_64 MIDI2AssignableControl(UInt8 group, UInt8 channel, UInt8 bank, UInt8 index, UInt32 value) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusAssignableControl, channel, (UInt16)((bank & 0x7F) << 8 | (index & 0x7F)), value);
}
CF_INLINE MIDIMessage_64 MIDI2RelRegisteredControl(UInt8 group, UInt8 channel, UInt8 bank, UInt8 index, UInt32 value) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusRelRegisteredControl, channel, (UInt16)((bank & 0x7F) << 8 | (index & 0x7F)), value);
}
CF_INLINE MIDIMessage_64 MIDI2RelAssignableControl(UInt8 group, UInt8 channel, UInt8 bank, UInt8 index, UInt32 value) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusRelAssignableControl, channel, (UInt16)((bank & 0x7F) << 8 | (index & 0x7F)), value);
}
CF_INLINE MIDIMessage_64 MIDI2ProgramChange(UInt8 group, UInt8 channel, bool bankIsValid, UInt8 program, UInt8 bank_msb, UInt8 bank_lsb) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusProgramChange, channel, bankIsValid ? 0x1 : 0,
                                    (UInt32)(program & 0x7F) << 24 | (bankIsValid ? ((UInt32)(bank_msb & 0x7F) << 8 | (bank_lsb & 0x7F)) : 0));
}
CF_INLINE MIDIMessage_64 MIDI2ChannelPressure(UInt8 group, UInt8 channel, UInt32 value) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusChannelPressure, channel, 0, value);
}
CF_INLINE MIDIMessage_64 MIDI2PitchBend(UInt8 group, UInt8 channel, UInt32 value) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusPitchBend, channel, 0, value);
}
CF_INLINE MIDIMessage_64 MIDI2PerNotePitchBend(UInt8 group, UInt8 channel, UInt8 noteNumber, UInt32 value) {
    return MIDI2ChannelVoiceMessage(group, kMIDICVStatusPerNotePitchBend, channel, (UInt16)((noteNumber & 0x7F) << 8), value);
}

/* utility messages (one word, no group) */
CF_INLINE MIDIMessage_32 MIDINoOpMessage(void) { return 0; }
CF_INLINE MIDIMessage_32 MIDIJitterReductionClockMessage(UInt16 senderClockTime) {
    return (UInt32)kMIDIUtilityStatusJitterReductionClock << 20 | senderClockTime;
}
CF_INLINE MIDIMessage_32 MIDIJitterReductionTimestampMessage(UInt16 senderClockTimestamp) {
    return (UInt32)kMIDIUtilityStatusJitterReductionTimestamp << 20 | senderClockTimestamp;
}
CF_INLINE MIDIMessage_32 MIDIDeltaClockstampTicksPerQuarterNoteMessage(UInt16 ticksPerQuarterNote) {
    return (UInt32)kMIDIUtilityStatusDeltaClockstampTicksPerQuarterNote << 20 | ticksPerQuarterNote;
}
CF_INLINE MIDIMessage_32 MIDITicksSinceLastEventMessage(UInt32 ticksSinceLastEvent) {
    return (UInt32)kMIDIUtilityStatusTicksSinceLastEvent << 20 | (ticksSinceLastEvent & 0xFFFFF);
}

/* flex data and UMP stream messages (four words) */
CF_INLINE MIDIMessage_128 MIDI2FlexDataMessage(MIDIUInteger4 group, MIDIUInteger2 form, MIDIUInteger2 addrs, MIDIUInteger4 channel,
                                               UInt8 statusBank, UInt8 status, UInt32 word1, UInt32 word2, UInt32 word3) {
    MIDIMessage_128 m = { (UInt32)kMIDIMessageTypeFlexData << 28 | (UInt32)(group & 0xF) << 24 | (UInt32)(form & 0x3) << 22
                              | (UInt32)(addrs & 0x3) << 20 | (UInt32)(channel & 0xF) << 16 | (UInt32)statusBank << 8 | status,
                          word1, word2, word3 };
    return m;
}
CF_INLINE MIDIMessage_128 MIDI2StreamMessage(UMPStreamMessageFormat format, UMPStreamMessageStatus status, UInt16 data16,
                                             UInt32 word1, UInt32 word2, UInt32 word3) {
    MIDIMessage_128 m = { (UInt32)kMIDIMessageTypeStream << 28 | (UInt32)(format & 0x3) << 26 | (UInt32)(status & 0x3FF) << 16 | data16,
                          word1, word2, word3 };
    return m;
}
/* up to 14 bytes of text or data after the status */
CF_INLINE MIDIMessage_128 MIDI2StreamMessageFromData(UMPStreamMessageFormat format, UMPStreamMessageStatus status,
                                                     const Byte * _Null_unspecified data, size_t length) {
    Byte b[14] = { 0 };
    for (size_t i = 0; i < length && i < 14; i++) b[i] = data[i];
    return MIDI2StreamMessage(format, status, (UInt16)(b[0] << 8 | b[1]), (UInt32)b[2] << 24 | (UInt32)b[3] << 16 | (UInt32)b[4] << 8 | b[5],
                              (UInt32)b[6] << 24 | (UInt32)b[7] << 16 | (UInt32)b[8] << 8 | b[9],
                              (UInt32)b[10] << 24 | (UInt32)b[11] << 16 | (UInt32)b[12] << 8 | b[13]);
}
CF_INLINE MIDIMessage_128 MIDI2EndpointDiscoveryMessage(UInt8 UMPVersionMajor, UInt8 UMPVersionMinor, bool requestEndpointInfo,
                                                        bool requestDeviceIdentity, bool requestEndpointName,
                                                        bool requestProductInstanceID, bool requestStreamConfiguration) {
    UInt32 filter = (requestEndpointInfo ? 0x01 : 0) | (requestDeviceIdentity ? 0x02 : 0) | (requestEndpointName ? 0x04 : 0)
                  | (requestProductInstanceID ? 0x08 : 0) | (requestStreamConfiguration ? 0x10 : 0);
    return MIDI2StreamMessage(kUMPStreamMessageFormatComplete, kUMPStreamMessageStatusEndpointDiscovery,
                              (UInt16)(UMPVersionMajor << 8 | UMPVersionMinor), filter, 0, 0);
}
CF_INLINE MIDIMessage_128 MIDI2EndpointInfoNotificationMessage(UInt8 UMPVersionMajor, UInt8 UMPVersionMinor, bool staticFunctionBlocks,
                                                               UInt8 numberOfFunctionBlocks, bool supportsMIDI2_0Protocol,
                                                               bool supportsMIDI1_0Protocol, bool supportsReceivingJRTimestamps,
                                                               bool supportsSendingJRTimestamps) {
    UInt32 w1 = (UInt32)(staticFunctionBlocks ? 1 : 0) << 31 | (UInt32)(numberOfFunctionBlocks & 0x7F) << 24
              | (UInt32)(supportsMIDI2_0Protocol ? 1 : 0) << 9 | (UInt32)(supportsMIDI1_0Protocol ? 1 : 0) << 8
              | (UInt32)(supportsReceivingJRTimestamps ? 1 : 0) << 1 | (UInt32)(supportsSendingJRTimestamps ? 1 : 0);
    return MIDI2StreamMessage(kUMPStreamMessageFormatComplete, kUMPStreamMessageStatusEndpointInfoNotification,
                              (UInt16)(UMPVersionMajor << 8 | UMPVersionMinor), w1, 0, 0);
}
CF_INLINE MIDIMessage_128 MIDI2EndpointDeviceIdentityNotificationMessage(MIDIUInteger7 deviceManufacturerSysExIdByte1,
                                                                         MIDIUInteger7 deviceManufacturerSysExIdByte2,
                                                                         MIDIUInteger7 deviceManufacturerSysExIdByte3,
                                                                         MIDIUInteger14 deviceFamily, MIDIUInteger14 deviceFamilyModelNumber,
                                                                         MIDIUInteger28 softwareRevisionLevel) {
    return MIDI2StreamMessage(kUMPStreamMessageFormatComplete, kUMPStreamMessageStatusDeviceIdentityNotification, 0,
                              (UInt32)(deviceManufacturerSysExIdByte1 & 0x7F) << 16 | (UInt32)(deviceManufacturerSysExIdByte2 & 0x7F) << 8
                                  | (deviceManufacturerSysExIdByte3 & 0x7F),
                              (UInt32)(deviceFamily & 0x7F) << 24 | (UInt32)(deviceFamily >> 7 & 0x7F) << 16
                                  | (UInt32)(deviceFamilyModelNumber & 0x7F) << 8 | (deviceFamilyModelNumber >> 7 & 0x7F),
                              (UInt32)(softwareRevisionLevel & 0x7F) << 24 | (UInt32)(softwareRevisionLevel >> 7 & 0x7F) << 16
                                  | (UInt32)(softwareRevisionLevel >> 14 & 0x7F) << 8 | (softwareRevisionLevel >> 21 & 0x7F));
}
CF_INLINE MIDIMessage_128 MIDI2EndpointNameNotificationMessage(UMPStreamMessageFormat format, const char * _Null_unspecified data, size_t length) {
    return MIDI2StreamMessageFromData(format, kUMPStreamMessageStatusEndpointNameNotification, (const Byte *)data, length);
}
CF_INLINE MIDIMessage_128 MIDI2EndpointProductInstanceIDNotificationMessage(UMPStreamMessageFormat format, const char * _Null_unspecified data, size_t length) {
    return MIDI2StreamMessageFromData(format, kUMPStreamMessageStatusProductInstanceIDNotification, (const Byte *)data, length);
}
CF_INLINE MIDIMessage_128 MIDI2StreamConfigurationRequestMessage(UInt8 protocol, bool endpointShouldReceiveJRTimestamps,
                                                                 bool endpointShouldSendJRTimestamps) {
    return MIDI2StreamMessage(kUMPStreamMessageFormatComplete, kUMPStreamMessageStatusStreamConfigurationRequest,
                              (UInt16)(protocol << 8 | (endpointShouldReceiveJRTimestamps ? 0x2 : 0) | (endpointShouldSendJRTimestamps ? 0x1 : 0)), 0, 0, 0);
}
CF_INLINE MIDIMessage_128 MIDI2StreamConfigurationNotificationMessage(UInt8 protocol, bool endpointWillReceiveJRTimestamps,
                                                                      bool endpointWillSendJRTimestamps) {
    return MIDI2StreamMessage(kUMPStreamMessageFormatComplete, kUMPStreamMessageStatusStreamConfigurationNotification,
                              (UInt16)(protocol << 8 | (endpointWillReceiveJRTimestamps ? 0x2 : 0) | (endpointWillSendJRTimestamps ? 0x1 : 0)), 0, 0, 0);
}
CF_INLINE MIDIMessage_128 MIDI2FunctionBlockDiscoveryMessage(UInt8 functionBlockNumber, bool requestFunctionBlockInfo, bool requestFunctionBlockName) {
    return MIDI2StreamMessage(kUMPStreamMessageFormatComplete, kUMPStreamMessageStatusFunctionBlockDiscovery,
                              (UInt16)(functionBlockNumber << 8 | (requestFunctionBlockName ? 0x2 : 0) | (requestFunctionBlockInfo ? 0x1 : 0)), 0, 0, 0);
}
CF_INLINE MIDIMessage_128 MIDI2FunctionBlockInfoNotificationMessage(bool functionBlockActive, MIDIUInteger7 functionBlockNumber,
                                                                    MIDIUMPFunctionBlockUIHint UIHint, MIDIUMPFunctionBlockMIDI1Info midi1,
                                                                    MIDIUMPFunctionBlockDirection direction, UInt8 firstGroup,
                                                                    UInt8 numberOfGroupsSpanned, UInt8 MIDICIVersionFormat,
                                                                    UInt8 maxSysEx8Streams) {
    return MIDI2StreamMessage(kUMPStreamMessageFormatComplete, kUMPStreamMessageStatusFunctionBlockInfoNotification,
                              (UInt16)((functionBlockActive ? 1 : 0) << 15 | (functionBlockNumber & 0x7F) << 8 | (UIHint & 0x3) << 4
                                       | (midi1 & 0x3) << 2 | (direction & 0x3)),
                              (UInt32)firstGroup << 24 | (UInt32)numberOfGroupsSpanned << 16 | (UInt32)MIDICIVersionFormat << 8 | maxSysEx8Streams,
                              0, 0);
}
CF_INLINE MIDIMessage_128 MIDI2FunctionBlockNameNotificationMessage(UMPStreamMessageFormat format, UInt8 functionBlockNumber,
                                                                    const char * _Null_unspecified data, size_t length) {
    Byte b[14] = { functionBlockNumber };
    for (size_t i = 0; i < length && i < 13; i++) b[i + 1] = (Byte)data[i];
    return MIDI2StreamMessageFromData(format, kUMPStreamMessageStatusFunctionBlockNameNotification, b, length < 13 ? length + 1 : 14);
}
CF_INLINE MIDIMessage_128 MIDI2StartOfClipMessage(void) {
    return MIDI2StreamMessage(kUMPStreamMessageFormatComplete, kUMPStreamMessageStatusStartOfClip, 0, 0, 0, 0);
}
CF_INLINE MIDIMessage_128 MIDI2EndOfClipMessage(void) {
    return MIDI2StreamMessage(kUMPStreamMessageFormatComplete, kUMPStreamMessageStatusEndOfClip, 0, 0, 0, 0);
}

CF_ASSUME_NONNULL_END
CF_EXTERN_C_END
