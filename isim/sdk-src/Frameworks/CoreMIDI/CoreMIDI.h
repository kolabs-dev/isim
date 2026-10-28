#pragma once
/* isim CoreMIDI (self-authored, Apple's names): MIDI services in the app's process, a simulated "isim MIDI" device
   driven by the `midi` script command, and the host's ALSA sequencer ports when the host has one. */
#include <CoreMIDI/MIDIServices.h>
#include <CoreMIDI/MIDISetup.h>
#include <CoreMIDI/MIDIThruConnection.h>
#include <CoreMIDI/MIDIDriver.h>
#include <CoreMIDI/MIDIMessages.h>
#include <CoreMIDI/MIDIBluetoothConnection.h>
#if defined(__OBJC__)
#import <CoreMIDI/MIDINetworkSession.h>
#import <CoreMIDI/MIDICapabilityInquiry.h>
#import <CoreMIDI/MIDIUMPEndpoint.h>
#endif
