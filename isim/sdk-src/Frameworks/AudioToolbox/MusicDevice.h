#pragma once
/* isim AudioToolbox for C: Music Device (Apple's MusicDevice.h): MIDI events and notes for the Sampler and MIDISynth units
 * (swift/overlays/AudioToolbox/Sampler.swift). */
#include <AudioToolbox/AudioUnit.h>
#include <CoreMIDI/MIDIServices.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
AT_EXPORT OSStatus MusicDeviceMIDIEvent(MusicDeviceComponent inUnit, UInt32 inStatus, UInt32 inData1, UInt32 inData2, UInt32 inOffsetSampleFrame);
AT_EXPORT OSStatus MusicDeviceSysEx(MusicDeviceComponent inUnit, const UInt8 *inData, UInt32 inLength);
AT_EXPORT OSStatus MusicDeviceMIDIEventList(MusicDeviceComponent inUnit, UInt32 inOffsetSampleFrame, const MIDIEventList *evtList);
AT_EXPORT OSStatus MusicDeviceStartNote(MusicDeviceComponent inUnit, MusicDeviceInstrumentID inInstrument, MusicDeviceGroupID inGroupID, NoteInstanceID *outNoteInstanceID, UInt32 inOffsetSampleFrame, const MusicDeviceNoteParams *inParams);
AT_EXPORT OSStatus MusicDeviceStopNote(MusicDeviceComponent inUnit, MusicDeviceGroupID inGroupID, NoteInstanceID inNoteInstanceID, UInt32 inOffsetSampleFrame);
#define kInstrumentInfoKey_Name "name"
#define kInstrumentInfoKey_MSB "MSB"
#define kInstrumentInfoKey_LSB "LSB"
#define kInstrumentInfoKey_Program "program"
AT_EXPORT OSStatus CopyNameFromSoundBank(CFURLRef inURL, CFStringRef _Nullable *_Nonnull outName);
AT_EXPORT OSStatus CopyInstrumentInfoFromSoundBank(CFURLRef inURL, CFArrayRef _Nullable *_Nonnull outInstrumentInfo);
#pragma clang assume_nonnull end
__END_DECLS
#endif
