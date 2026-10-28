#pragma once
/* isim CoreMIDI: the MIDI server, clients, ports, devices, entities, endpoints, properties, notifications and packets.
   Adapted: isim's own MIDI server in the app process (frameworks/CoreMIDI/MIDIServices.m). A simulated "isim MIDI"
   device has a source and a destination the `midi` script command drives; the host's ALSA sequencer ports appear as
   devices when the host has one. */
#include <CoreFoundation/CoreFoundation.h>
#include <MacTypes.h>
#include <stddef.h>
#include <stdint.h>

CF_EXTERN_C_BEGIN
CF_ASSUME_NONNULL_BEGIN

/* errors */
enum : OSStatus {
    kMIDIInvalidClient = -10830, kMIDIInvalidPort = -10831, kMIDIWrongEndpointType = -10832, kMIDINoConnection = -10833,
    kMIDIUnknownEndpoint = -10834, kMIDIUnknownProperty = -10835, kMIDIWrongPropertyType = -10836,
    kMIDINoCurrentSetup = -10837, kMIDIMessageSendErr = -10838, kMIDIServerStartErr = -10839,
    kMIDISetupFormatErr = -10840, kMIDIWrongThread = -10841, kMIDIObjectNotFound = -10842, kMIDIIDNotUnique = -10843,
    kMIDINotPermitted = -10844, kMIDIUnknownError = -10845,
};

/* objects */
typedef UInt32 MIDIObjectRef;
typedef MIDIObjectRef MIDIClientRef;
typedef MIDIObjectRef MIDIPortRef;
typedef MIDIObjectRef MIDIDeviceRef;
typedef MIDIObjectRef MIDIEntityRef;
typedef MIDIObjectRef MIDIEndpointRef;
typedef UInt64 MIDITimeStamp;

typedef CF_ENUM(SInt32, MIDIObjectType) {
    kMIDIObjectType_Other = -1,
    kMIDIObjectType_Device = 0,
    kMIDIObjectType_Entity = 1,
    kMIDIObjectType_Source = 2,
    kMIDIObjectType_Destination = 3,
    kMIDIObjectType_ExternalDevice = 0x10 | kMIDIObjectType_Device,
    kMIDIObjectType_ExternalEntity = 0x10 | kMIDIObjectType_Entity,
    kMIDIObjectType_ExternalSource = 0x10 | kMIDIObjectType_Source,
    kMIDIObjectType_ExternalDestination = 0x10 | kMIDIObjectType_Destination,
};
static const MIDIObjectType kMIDIObjectType_ExternalMask = (MIDIObjectType)0x10;

typedef SInt32 MIDIUniqueID;
enum : MIDIUniqueID { kMIDIInvalidUniqueID = 0 };

typedef CF_ENUM(SInt32, MIDIProtocolID) {
    kMIDIProtocol_1_0 = 1,
    kMIDIProtocol_2_0 = 2,
};

/* packets: MIDI 1.0 bytes */
#pragma pack(push, 4)
typedef struct MIDIPacket {
    MIDITimeStamp timeStamp;
    UInt16 length;
    Byte data[256];
} MIDIPacket;
typedef struct MIDIPacketList {
    UInt32 numPackets;
    MIDIPacket packet[1];
} MIDIPacketList;
/* packets: Universal MIDI Packets (32-bit words) */
typedef struct MIDIEventPacket {
    MIDITimeStamp timeStamp;
    UInt32 wordCount;
    UInt32 words[64];
} MIDIEventPacket;
typedef struct MIDIEventList {
    MIDIProtocolID protocol;
    UInt32 numPackets;
    MIDIEventPacket packet[1];
} MIDIEventList;
#pragma pack(pop)

/* notifications */
typedef CF_ENUM(SInt32, MIDINotificationMessageID) {
    kMIDIMsgSetupChanged = 1,
    kMIDIMsgObjectAdded = 2,
    kMIDIMsgObjectRemoved = 3,
    kMIDIMsgPropertyChanged = 4,
    kMIDIMsgThruConnectionsChanged = 5,
    kMIDIMsgSerialPortOwnerChanged = 6,
    kMIDIMsgIOError = 7,
    kMIDIMsgInternalStart = 0x1000,
};
typedef struct MIDINotification {
    MIDINotificationMessageID messageID;
    UInt32 messageSize;
} MIDINotification;
typedef struct MIDIObjectAddRemoveNotification {
    MIDINotificationMessageID messageID;
    UInt32 messageSize;
    MIDIObjectRef parent;
    MIDIObjectType parentType;
    MIDIObjectRef child;
    MIDIObjectType childType;
} MIDIObjectAddRemoveNotification;
typedef struct MIDIObjectPropertyChangeNotification {
    MIDINotificationMessageID messageID;
    UInt32 messageSize;
    MIDIObjectRef object;
    MIDIObjectType objectType;
    CFStringRef propertyName;
} MIDIObjectPropertyChangeNotification;
typedef struct MIDIIOErrorNotification {
    MIDINotificationMessageID messageID;
    UInt32 messageSize;
    MIDIDeviceRef driverDevice;
    OSStatus errorCode;
} MIDIIOErrorNotification;

typedef void (*MIDINotifyProc)(const MIDINotification *message, void * _Nullable refCon);
typedef void (^MIDINotifyBlock)(const MIDINotification *message);
typedef void (*MIDIReadProc)(const MIDIPacketList *pktlist, void * _Nullable readProcRefCon, void * _Nullable srcConnRefCon);
typedef void (^MIDIReadBlock)(const MIDIPacketList *pktlist, void * _Nullable srcConnRefCon);
typedef void (^MIDIReceiveBlock)(const MIDIEventList *evtlist, void * _Nullable srcConnRefCon);

/* system-exclusive messages sent in the background */
typedef struct MIDISysexSendRequest MIDISysexSendRequest;
typedef void (*MIDICompletionProc)(MIDISysexSendRequest *request);
struct MIDISysexSendRequest {
    MIDIEndpointRef destination;
    const Byte *data;
    UInt32 bytesToSend;
    Boolean complete;
    Byte reserved[3];
    MIDICompletionProc completionProc;
    void * _Nullable completionRefCon;
};
typedef struct MIDISysexSendRequestUMP MIDISysexSendRequestUMP;
typedef void (*MIDICompletionProcUMP)(MIDISysexSendRequestUMP *request);
struct MIDISysexSendRequestUMP {
    MIDIEndpointRef destination;
    UInt32 *words;
    UInt32 wordsToSend;
    Boolean complete;
    MIDICompletionProcUMP completionProc;
    void * _Nullable completionRefCon;
};

/* properties */
extern const CFStringRef kMIDIPropertyName;
extern const CFStringRef kMIDIPropertyManufacturer;
extern const CFStringRef kMIDIPropertyModel;
extern const CFStringRef kMIDIPropertyUniqueID;
extern const CFStringRef kMIDIPropertyDeviceID;
extern const CFStringRef kMIDIPropertyReceiveChannels;
extern const CFStringRef kMIDIPropertyTransmitChannels;
extern const CFStringRef kMIDIPropertyMaxSysExSpeed;
extern const CFStringRef kMIDIPropertyAdvanceScheduleTimeMuSec;
extern const CFStringRef kMIDIPropertyIsEmbeddedEntity;
extern const CFStringRef kMIDIPropertyIsBroadcast;
extern const CFStringRef kMIDIPropertySingleRealtimeEntity;
extern const CFStringRef kMIDIPropertyConnectionUniqueID;
extern const CFStringRef kMIDIPropertyOffline;
extern const CFStringRef kMIDIPropertyPrivate;
extern const CFStringRef kMIDIPropertyDriverOwner;
extern const CFStringRef kMIDIPropertyFactoryPatchNameFile;
extern const CFStringRef kMIDIPropertyUserPatchNameFile;
extern const CFStringRef kMIDIPropertyNameConfiguration;
extern const CFStringRef kMIDIPropertyNameConfigurationDictionary;
extern const CFStringRef kMIDIPropertyImage;
extern const CFStringRef kMIDIPropertyDriverVersion;
extern const CFStringRef kMIDIPropertySupportsGeneralMIDI;
extern const CFStringRef kMIDIPropertySupportsMMC;
extern const CFStringRef kMIDIPropertyCanRoute;
extern const CFStringRef kMIDIPropertyReceivesClock;
extern const CFStringRef kMIDIPropertyReceivesMTC;
extern const CFStringRef kMIDIPropertyReceivesNotes;
extern const CFStringRef kMIDIPropertyReceivesProgramChanges;
extern const CFStringRef kMIDIPropertyReceivesBankSelectMSB;
extern const CFStringRef kMIDIPropertyReceivesBankSelectLSB;
extern const CFStringRef kMIDIPropertyTransmitsClock;
extern const CFStringRef kMIDIPropertyTransmitsMTC;
extern const CFStringRef kMIDIPropertyTransmitsNotes;
extern const CFStringRef kMIDIPropertyTransmitsProgramChanges;
extern const CFStringRef kMIDIPropertyTransmitsBankSelectMSB;
extern const CFStringRef kMIDIPropertyTransmitsBankSelectLSB;
extern const CFStringRef kMIDIPropertyPanDisruptsStereo;
extern const CFStringRef kMIDIPropertyIsSampler;
extern const CFStringRef kMIDIPropertyIsDrumMachine;
extern const CFStringRef kMIDIPropertyIsMixer;
extern const CFStringRef kMIDIPropertyIsEffectUnit;
extern const CFStringRef kMIDIPropertyMaxReceiveChannels;
extern const CFStringRef kMIDIPropertyMaxTransmitChannels;
extern const CFStringRef kMIDIPropertyDriverDeviceEditorApp;
extern const CFStringRef kMIDIPropertySupportsShowControl;
extern const CFStringRef kMIDIPropertyDisplayName;
extern const CFStringRef kMIDIPropertyProtocolID;
extern const CFStringRef kMIDIPropertyUMPActiveGroupBitmap;
extern const CFStringRef kMIDIPropertyUMPCanTransmitGroupless;
extern const CFStringRef kMIDIPropertyAssociatedEndpoint;

/* clients */
OSStatus MIDIClientCreate(CFStringRef name, MIDINotifyProc _Nullable notifyProc, void * _Nullable notifyRefCon, MIDIClientRef *outClient);
OSStatus MIDIClientCreateWithBlock(CFStringRef name, MIDIClientRef *outClient, MIDINotifyBlock _Nullable notifyBlock);
OSStatus MIDIClientDispose(MIDIClientRef client);

/* ports */
OSStatus MIDIInputPortCreateWithProtocol(MIDIClientRef client, CFStringRef portName, MIDIProtocolID protocol, MIDIPortRef *outPort, MIDIReceiveBlock receiveBlock);
OSStatus MIDIInputPortCreate(MIDIClientRef client, CFStringRef portName, MIDIReadProc readProc, void * _Nullable refCon, MIDIPortRef *outPort);
OSStatus MIDIInputPortCreateWithBlock(MIDIClientRef client, CFStringRef portName, MIDIPortRef *outPort, MIDIReadBlock readBlock);
OSStatus MIDIOutputPortCreate(MIDIClientRef client, CFStringRef portName, MIDIPortRef *outPort);
OSStatus MIDIPortDispose(MIDIPortRef port);
OSStatus MIDIPortConnectSource(MIDIPortRef port, MIDIEndpointRef source, void * _Nullable connRefCon);
OSStatus MIDIPortDisconnectSource(MIDIPortRef port, MIDIEndpointRef source);

/* devices, entities and endpoints */
ItemCount MIDIGetNumberOfDevices(void);
MIDIDeviceRef MIDIGetDevice(ItemCount deviceIndex0);
ItemCount MIDIDeviceGetNumberOfEntities(MIDIDeviceRef device);
MIDIEntityRef MIDIDeviceGetEntity(MIDIDeviceRef device, ItemCount entityIndex0);
ItemCount MIDIEntityGetNumberOfSources(MIDIEntityRef entity);
MIDIEndpointRef MIDIEntityGetSource(MIDIEntityRef entity, ItemCount sourceIndex0);
ItemCount MIDIEntityGetNumberOfDestinations(MIDIEntityRef entity);
MIDIEndpointRef MIDIEntityGetDestination(MIDIEntityRef entity, ItemCount destIndex0);
OSStatus MIDIEntityGetDevice(MIDIEntityRef inEntity, MIDIDeviceRef * _Nullable outDevice);
ItemCount MIDIGetNumberOfSources(void);
MIDIEndpointRef MIDIGetSource(ItemCount sourceIndex0);
ItemCount MIDIGetNumberOfDestinations(void);
MIDIEndpointRef MIDIGetDestination(ItemCount destIndex0);
OSStatus MIDIEndpointGetEntity(MIDIEndpointRef inEndpoint, MIDIEntityRef * _Nullable outEntity);
OSStatus MIDIDestinationCreateWithProtocol(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outDest, MIDIReceiveBlock readBlock);
OSStatus MIDIDestinationCreate(MIDIClientRef client, CFStringRef name, MIDIReadProc readProc, void * _Nullable refCon, MIDIEndpointRef *outDest);
OSStatus MIDIDestinationCreateWithBlock(MIDIClientRef client, CFStringRef name, MIDIEndpointRef *outDest, MIDIReadBlock readBlock);
OSStatus MIDISourceCreateWithProtocol(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outSrc);
OSStatus MIDISourceCreate(MIDIClientRef client, CFStringRef name, MIDIEndpointRef *outSrc);
OSStatus MIDIEndpointDispose(MIDIEndpointRef endpt);
ItemCount MIDIGetNumberOfExternalDevices(void);
MIDIDeviceRef MIDIGetExternalDevice(ItemCount deviceIndex0);

/* properties */
OSStatus MIDIObjectGetIntegerProperty(MIDIObjectRef obj, CFStringRef propertyID, SInt32 *outValue);
OSStatus MIDIObjectSetIntegerProperty(MIDIObjectRef obj, CFStringRef propertyID, SInt32 value);
OSStatus MIDIObjectGetStringProperty(MIDIObjectRef obj, CFStringRef propertyID, CFStringRef _Nullable * _Nonnull str);
OSStatus MIDIObjectSetStringProperty(MIDIObjectRef obj, CFStringRef propertyID, CFStringRef str);
OSStatus MIDIObjectGetDataProperty(MIDIObjectRef obj, CFStringRef propertyID, CFDataRef _Nullable * _Nonnull outData);
OSStatus MIDIObjectSetDataProperty(MIDIObjectRef obj, CFStringRef propertyID, CFDataRef data);
OSStatus MIDIObjectGetDictionaryProperty(MIDIObjectRef obj, CFStringRef propertyID, CFDictionaryRef _Nullable * _Nonnull outDict);
OSStatus MIDIObjectSetDictionaryProperty(MIDIObjectRef obj, CFStringRef propertyID, CFDictionaryRef dict);
OSStatus MIDIObjectGetProperties(MIDIObjectRef obj, CFPropertyListRef _Nullable * _Nonnull outProperties, Boolean deep);
OSStatus MIDIObjectRemoveProperty(MIDIObjectRef obj, CFStringRef propertyID);
OSStatus MIDIObjectFindByUniqueID(MIDIUniqueID inUniqueID, MIDIObjectRef * _Nullable outObject, MIDIObjectType * _Nullable outObjectType);

/* sending and receiving */
OSStatus MIDISendEventList(MIDIPortRef port, MIDIEndpointRef dest, const MIDIEventList *evtlist);
OSStatus MIDISend(MIDIPortRef port, MIDIEndpointRef dest, const MIDIPacketList *pktlist);
OSStatus MIDISendSysex(MIDISysexSendRequest *request);
OSStatus MIDISendUMPSysex(MIDISysexSendRequestUMP *umpRequest);
OSStatus MIDISendUMPSysex8(MIDISysexSendRequestUMP *umpRequest);
OSStatus MIDIEventPacketSysexBytesForGroup(const MIDIEventPacket *pkt, UInt8 groupIndex, CFDataRef _Nullable * _Nonnull outData);
OSStatus MIDIReceivedEventList(MIDIEndpointRef src, const MIDIEventList *evtlist);
OSStatus MIDIReceived(MIDIEndpointRef src, const MIDIPacketList *pktlist);
OSStatus MIDIFlushOutput(MIDIEndpointRef dest);
OSStatus MIDIRestart(void);

/* building packet lists */
MIDIEventPacket *MIDIEventListInit(MIDIEventList *evtlist, MIDIProtocolID protocol);
MIDIEventPacket * _Nullable MIDIEventListAdd(MIDIEventList *evtlist, ByteCount listSize, MIDIEventPacket *curPacket, MIDITimeStamp time, ByteCount wordCount, const UInt32 *words);
MIDIPacket *MIDIPacketListInit(MIDIPacketList *pktlist);
MIDIPacket * _Nullable MIDIPacketListAdd(MIDIPacketList *pktlist, ByteCount listSize, MIDIPacket *curPacket, MIDITimeStamp time, ByteCount nData, const Byte *data);

/* the next packet of a list (inline, like Apple's) */
#if defined(__arm64__) || defined(__aarch64__)
#define __ISIM_MIDI_ALIGN(p) (((uintptr_t)(p) + 3) & ~(uintptr_t)3)
#else
#define __ISIM_MIDI_ALIGN(p) ((uintptr_t)(p))
#endif
static __inline__ MIDIPacket *MIDIPacketNext(const MIDIPacket *pkt) {
    return (MIDIPacket *)__ISIM_MIDI_ALIGN(&pkt->data[pkt->length]);
}
static __inline__ MIDIEventPacket *MIDIEventPacketNext(const MIDIEventPacket *pkt) {
    return (MIDIEventPacket *)&pkt->words[pkt->wordCount];
}

CF_ASSUME_NONNULL_END
CF_EXTERN_C_END
