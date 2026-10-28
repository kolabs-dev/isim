#pragma once
/* isim CoreMIDI: thru connections. Messages from up to eight sources go to up to eight destinations, filtered and
   transformed on the way (channel maps, note and velocity ranges, value transforms, control maps). */
#include <CoreMIDI/MIDIServices.h>

CF_EXTERN_C_BEGIN
CF_ASSUME_NONNULL_BEGIN

typedef MIDIObjectRef MIDIThruConnectionRef;

typedef struct MIDIValueMap { UInt8 value[128]; } MIDIValueMap;

typedef CF_ENUM(UInt16, MIDITransformType) {
    kMIDITransform_None = 0,
    kMIDITransform_FilterOut = 1,
    kMIDITransform_MapControl = 2,
    kMIDITransform_Add = 8,
    kMIDITransform_Scale = 9,
    kMIDITransform_MinValue = 10,
    kMIDITransform_MaxValue = 11,
    kMIDITransform_MapValue = 12,
};

enum : UInt32 { kMIDIThruConnection_MaxEndpoints = 8 };

typedef CF_ENUM(UInt8, MIDITransformControlType) {
    kMIDIControlType_7Bit = 0,
    kMIDIControlType_14Bit = 1,
    kMIDIControlType_7BitRPN = 2,
    kMIDIControlType_14BitRPN = 3,
    kMIDIControlType_7BitNRPN = 4,
    kMIDIControlType_14BitNRPN = 5,
};

#pragma pack(push, 4)
typedef struct MIDITransform {
    MIDITransformType transform;
    SInt16 param;
} MIDITransform;

typedef struct MIDIControlTransform {
    MIDITransformControlType controlType;
    MIDITransformControlType remappedControlType;
    UInt16 controlNumber;
    MIDITransformType transform;
    SInt16 param;
} MIDIControlTransform;

typedef struct MIDIThruConnectionEndpoint {
    MIDIEndpointRef endpointRef;
    MIDIUniqueID uniqueID;
} MIDIThruConnectionEndpoint;

/* followed in the CFData by numControlTransforms MIDIControlTransforms and numMaps MIDIValueMaps */
typedef struct MIDIThruConnectionParams {
    UInt32 version;
    UInt32 numSources;
    MIDIThruConnectionEndpoint sources[kMIDIThruConnection_MaxEndpoints];
    UInt32 numDestinations;
    MIDIThruConnectionEndpoint destinations[kMIDIThruConnection_MaxEndpoints];
    UInt8 channelMap[16];
    UInt8 lowVelocity, highVelocity;
    UInt8 lowNote, highNote;
    MIDITransform noteNumber;
    MIDITransform velocity;
    MIDITransform keyPressure;
    MIDITransform channelPressure;
    MIDITransform programChange;
    MIDITransform pitchBend;
    UInt8 filterOutSysEx;
    UInt8 filterOutMTC;
    UInt8 filterOutBeatClock;
    UInt8 filterOutTuneRequest;
    UInt8 reserved2[3];
    UInt8 filterOutAllControls;
    UInt16 numControlTransforms;
    UInt16 numMaps;
    UInt16 reserved3[4];
} MIDIThruConnectionParams;
#pragma pack(pop)

void MIDIThruConnectionParamsInitialize(MIDIThruConnectionParams *inConnectionParams);
CF_INLINE size_t MIDIThruConnectionParamsSize(const MIDIThruConnectionParams *ptr) {
    return sizeof(MIDIThruConnectionParams) + ptr->numControlTransforms * sizeof(MIDIControlTransform) + ptr->numMaps * sizeof(MIDIValueMap);
}
OSStatus MIDIThruConnectionCreate(CFStringRef _Nullable inPersistentOwnerID, CFDataRef inConnectionParams, MIDIThruConnectionRef *outConnection);
OSStatus MIDIThruConnectionDispose(MIDIThruConnectionRef connection);
OSStatus MIDIThruConnectionGetParams(MIDIThruConnectionRef connection, CFDataRef _Nonnull * _Nonnull outConnectionParams);
OSStatus MIDIThruConnectionSetParams(MIDIThruConnectionRef connection, CFDataRef inConnectionParams);
OSStatus MIDIThruConnectionFind(CFStringRef inPersistentOwnerID, CFDataRef _Nonnull * _Nonnull outConnectionList);

CF_ASSUME_NONNULL_END
CF_EXTERN_C_END
