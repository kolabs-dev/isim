#pragma once
/* isim CoreMIDI: Bluetooth LE MIDI. Like Apple's Simulator, isim has no Bluetooth MIDI peripherals: activating
   connections does nothing and disconnecting one fails with kMIDIObjectNotFound. */
#include <CoreMIDI/MIDIServices.h>

CF_EXTERN_C_BEGIN
OSStatus MIDIBluetoothDriverActivateAllConnections(void);
OSStatus MIDIBluetoothDriverDisconnect(CFStringRef uuid);
CF_EXTERN_C_END
