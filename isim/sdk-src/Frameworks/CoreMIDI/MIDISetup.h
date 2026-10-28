#pragma once
/* isim CoreMIDI: the MIDI setup. Drivers add devices and apps add external devices (MIDI gear connected to a device's
   ports); isim keeps them for the app's process. */
#include <CoreMIDI/MIDIServices.h>

CF_EXTERN_C_BEGIN
CF_ASSUME_NONNULL_BEGIN

typedef MIDIObjectRef MIDISetupRef;

OSStatus MIDIDeviceNewEntity(MIDIDeviceRef device, CFStringRef name, MIDIProtocolID protocol, Boolean embedded,
                             ItemCount numSourceEndpoints, ItemCount numDestinationEndpoints, MIDIEntityRef *newEntity);
OSStatus MIDIDeviceAddEntity(MIDIDeviceRef device, CFStringRef name, Boolean embedded, ItemCount numSourceEndpoints,
                             ItemCount numDestinationEndpoints, MIDIEntityRef *newEntity);
OSStatus MIDIDeviceRemoveEntity(MIDIDeviceRef device, MIDIEntityRef entity);
OSStatus MIDIEntityAddOrRemoveEndpoints(MIDIEntityRef entity, ItemCount numSourceEndpoints, ItemCount numDestinationEndpoints);
OSStatus MIDISetupAddDevice(MIDIDeviceRef device);
OSStatus MIDISetupRemoveDevice(MIDIDeviceRef device);
OSStatus MIDISetupAddExternalDevice(MIDIDeviceRef device);
OSStatus MIDISetupRemoveExternalDevice(MIDIDeviceRef device);
OSStatus MIDIExternalDeviceCreate(CFStringRef name, CFStringRef manufacturer, CFStringRef model, MIDIDeviceRef *outDevice);

CF_ASSUME_NONNULL_END
CF_EXTERN_C_END
