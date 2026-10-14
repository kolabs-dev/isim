#pragma once
/* isim AudioUnit for C: the Audio Unit types and constants (component descriptions, unit types and subtypes, scopes,
 * property IDs, errors; the same values as Apple's AUComponent.h / AudioUnitProperties.h). Swift uses the AudioUnit
 * module, which re-exports AudioToolbox, where isim's audio units are implemented. Not yet in C: the AudioComponent /
 * AudioUnit functions (AudioComponentFindNext, AudioUnitSetProperty, AudioUnitRender, …), issue #286. */
#include <CoreAudio/CoreAudioTypes.h>
#if !defined(__swift__)
#include <_AudioToolboxTypes/AudioToolboxTypes.h>
__BEGIN_DECLS
typedef uint32_t AudioUnitPropertyID;
typedef uint32_t AudioUnitScope;
typedef uint32_t AudioUnitElement;
typedef uint32_t AudioUnitParameterID;
typedef float AudioUnitParameterValue;
enum { kAudioUnitManufacturer_Apple = 'appl' };
enum {
    kAudioUnitType_Output = 'auou',
    kAudioUnitType_MusicDevice = 'aumu',
    kAudioUnitType_MusicEffect = 'aumf',
    kAudioUnitType_FormatConverter = 'aufc',
    kAudioUnitType_Effect = 'aufx',
    kAudioUnitType_Mixer = 'aumx',
    kAudioUnitType_Panner = 'aupn',
    kAudioUnitType_Generator = 'augn',
    kAudioUnitType_OfflineEffect = 'auol',
};
enum {
    kAudioUnitSubType_RemoteIO = 'rioc',
    kAudioUnitSubType_VoiceProcessingIO = 'vpio',
    kAudioUnitSubType_GenericOutput = 'genr',
    kAudioUnitSubType_MultiChannelMixer = 'mcmx',
    kAudioUnitSubType_AUConverter = 'conv',
    kAudioUnitSubType_Varispeed = 'vari',
    kAudioUnitSubType_NewTimePitch = 'nutp',
    kAudioUnitSubType_Delay = 'dely',
    kAudioUnitSubType_Reverb2 = 'rvb2',
    kAudioUnitSubType_NBandEQ = 'nbeq',
    kAudioUnitSubType_LowPassFilter = 'lpas',
    kAudioUnitSubType_HighPassFilter = 'hpas',
    kAudioUnitSubType_BandPassFilter = 'bpas',
    kAudioUnitSubType_LowShelfFilter = 'lshf',
    kAudioUnitSubType_HighShelfFilter = 'hshf',
    kAudioUnitSubType_ParametricEQ = 'pmeq',
    kAudioUnitSubType_Distortion = 'dist',
    kAudioUnitSubType_PeakLimiter = 'lmtr',
};
enum {
    kAudioUnitScope_Global = 0,
    kAudioUnitScope_Input = 1,
    kAudioUnitScope_Output = 2,
    kAudioUnitScope_Group = 3,
    kAudioUnitScope_Part = 4,
};
enum {
    kAudioUnitProperty_ClassInfo = 0,
    kAudioUnitProperty_MakeConnection = 1,
    kAudioUnitProperty_SampleRate = 2,
    kAudioUnitProperty_ParameterList = 3,
    kAudioUnitProperty_ParameterInfo = 4,
    kAudioUnitProperty_StreamFormat = 8,
    kAudioUnitProperty_ElementCount = 11,
    kAudioUnitProperty_Latency = 12,
    kAudioUnitProperty_MaximumFramesPerSlice = 14,
    kAudioUnitProperty_TailTime = 20,
    kAudioUnitProperty_BypassEffect = 21,
    kAudioUnitProperty_LastRenderError = 22,
    kAudioUnitProperty_SetRenderCallback = 23,
    kAudioUnitProperty_ShouldAllocateBuffer = 51,
    kAudioUnitProperty_MeteringMode = 3007,
    kAudioOutputUnitProperty_EnableIO = 2003,
};
enum {
    kAudioUnitErr_InvalidProperty = -10879,
    kAudioUnitErr_InvalidParameter = -10878,
    kAudioUnitErr_InvalidElement = -10877,
    kAudioUnitErr_NoConnection = -10876,
    kAudioUnitErr_FailedInitialization = -10875,
    kAudioUnitErr_TooManyFramesToProcess = -10874,
    kAudioUnitErr_InvalidFile = -10871,
    kAudioUnitErr_FormatNotSupported = -10868,
    kAudioUnitErr_Uninitialized = -10867,
    kAudioUnitErr_InvalidScope = -10866,
    kAudioUnitErr_PropertyNotWritable = -10865,
    kAudioUnitErr_CannotDoInCurrentContext = -10863,
    kAudioUnitErr_InvalidPropertyValue = -10851,
    kAudioUnitErr_PropertyNotInUse = -10850,
    kAudioUnitErr_Initialized = -10849,
    kAudioUnitErr_InvalidOfflineRender = -10848,
    kAudioUnitErr_Unauthorized = -10847,
};
__END_DECLS
#endif
