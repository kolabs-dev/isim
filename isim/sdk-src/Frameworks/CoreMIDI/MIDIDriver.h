#pragma once
/* isim CoreMIDI: the driver interface. iOS apps cannot load MIDI drivers (Apple's are macOS plug-ins); isim declares
   the interface so code that mentions it compiles, and implements the device and device-list functions over its own
   MIDI server. */
#include <CoreMIDI/MIDIServices.h>
#include <CoreMIDI/MIDISetup.h>

CF_EXTERN_C_BEGIN
CF_ASSUME_NONNULL_BEGIN

typedef MIDIObjectRef MIDIDeviceListRef;
typedef struct MIDIDriverInterface MIDIDriverInterface;
typedef MIDIDriverInterface * _Nonnull * _Nullable MIDIDriverRef;

/* COM types, as CFPlugInCOM.h declares them */
#ifndef __ISIM_COM_TYPES
#define __ISIM_COM_TYPES 1
typedef SInt32 HRESULT;
typedef UInt32 ULONG;
typedef void *LPVOID;
typedef struct REFIID { UInt8 byte0, byte1, byte2, byte3, byte4, byte5, byte6, byte7, byte8, byte9, byte10, byte11, byte12, byte13, byte14, byte15; } REFIID;
#endif

struct MIDIDriverInterface {
    void * _Nullable _reserved;
    HRESULT (*QueryInterface)(void *thisPointer, REFIID iid, LPVOID _Nullable * _Nullable ppv);
    ULONG (*AddRef)(void *thisPointer);
    ULONG (*Release)(void *thisPointer);
    OSStatus (*FindDevices)(MIDIDriverRef self, MIDIDeviceListRef devList);
    OSStatus (*Start)(MIDIDriverRef self, MIDIDeviceListRef devList);
    OSStatus (*Stop)(MIDIDriverRef self);
    OSStatus (*Configure)(MIDIDriverRef self, MIDIDeviceRef device);
    OSStatus (*Send)(MIDIDriverRef self, const MIDIPacketList *pktlist, void *destRefCon1, void *destRefCon2);
    OSStatus (*EnableSource)(MIDIDriverRef self, MIDIEndpointRef src, Boolean enabled);
    OSStatus (*Flush)(MIDIDriverRef self, MIDIEndpointRef dest, void * _Nullable destRefCon1, void * _Nullable destRefCon2);
    OSStatus (*Monitor)(MIDIDriverRef self, MIDIEndpointRef dest, const MIDIPacketList *pktlist);
    OSStatus (*SendPackets)(MIDIDriverRef self, const MIDIEventList *pktlist, void *destRefCon1, void *destRefCon2);
    OSStatus (*MonitorEvents)(MIDIDriverRef self, MIDIEndpointRef dest, const MIDIEventList *pktlist);
};

extern const CFStringRef kMIDIDriverPropertyUsesSerial;

OSStatus MIDIDeviceCreate(MIDIDriverRef _Nullable owner, CFStringRef name, CFStringRef manufacturer, CFStringRef model, MIDIDeviceRef *outDevice);
OSStatus MIDIDeviceDispose(MIDIDeviceRef device);
ItemCount MIDIDeviceListGetNumberOfDevices(MIDIDeviceListRef devList);
MIDIDeviceRef MIDIDeviceListGetDevice(MIDIDeviceListRef devList, ItemCount index0);
OSStatus MIDIDeviceListAddDevice(MIDIDeviceListRef devList, MIDIDeviceRef dev);
OSStatus MIDIDeviceListDispose(MIDIDeviceListRef devList);
OSStatus MIDIEndpointSetRefCons(MIDIEndpointRef endpt, void * _Nullable ref1, void * _Nullable ref2);
OSStatus MIDIEndpointGetRefCons(MIDIEndpointRef endpt, void * _Nonnull * _Nullable ref1, void * _Nonnull * _Nullable ref2);
CFRunLoopRef MIDIGetDriverIORunLoop(void);
MIDIDeviceListRef MIDIGetDriverDeviceList(MIDIDriverRef driver);
OSStatus MIDIDriverEnableMonitoring(MIDIDriverRef driver, Boolean enabled);

CF_ASSUME_NONNULL_END
CF_EXTERN_C_END
