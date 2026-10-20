#pragma once
/* isim AudioToolbox for C: Audio Unit component types, scopes, errors and functions (Apple's AUComponent.h), over
 * isim's Swift audio units (swift/overlays/AudioToolbox/AudioUnits.swift). */
#include <AudioToolbox/AudioComponent.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef UInt32 AudioUnitPropertyID;
typedef UInt32 AudioUnitScope;
typedef UInt32 AudioUnitElement;
typedef UInt32 AudioUnitParameterID;
typedef Float32 AudioUnitParameterValue;
enum {
    kAudioUnitManufacturer_Apple = 'appl',
    kAudioUnitType_Output = 'auou',
    kAudioUnitType_MusicDevice = 'aumu',
    kAudioUnitType_MusicEffect = 'aumf',
    kAudioUnitType_FormatConverter = 'aufc',
    kAudioUnitType_Effect = 'aufx',
    kAudioUnitType_Mixer = 'aumx',
    kAudioUnitType_Panner = 'aupn',
    kAudioUnitType_Generator = 'augn',
    kAudioUnitType_OfflineEffect = 'auol',
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
    kAudioUnitScope_Global = 0,
    kAudioUnitScope_Input = 1,
    kAudioUnitScope_Output = 2,
    kAudioUnitScope_Group = 3,
    kAudioUnitScope_Part = 4,
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
    kAudioComponentErr_InstanceInvalidated = -66749,
};
AT_EXPORT OSStatus AudioUnitInitialize(AudioUnit inUnit);
AT_EXPORT OSStatus AudioUnitUninitialize(AudioUnit inUnit);
AT_EXPORT OSStatus AudioUnitGetPropertyInfo(AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement,
                                            UInt32 *_Nullable outDataSize, Boolean *_Nullable outWritable);
AT_EXPORT OSStatus AudioUnitGetProperty(AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement,
                                        void *outData, UInt32 *ioDataSize);
AT_EXPORT OSStatus AudioUnitSetProperty(AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement,
                                        const void *_Nullable inData, UInt32 inDataSize);
AT_EXPORT OSStatus AudioUnitAddPropertyListener(AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitPropertyListenerProc inProc,
                                                void *_Nullable inProcUserData);
AT_EXPORT OSStatus AudioUnitRemovePropertyListenerWithUserData(AudioUnit inUnit, AudioUnitPropertyID inID,
                                                               AudioUnitPropertyListenerProc inProc, void *_Nullable inProcUserData);
AT_EXPORT OSStatus AudioUnitAddRenderNotify(AudioUnit inUnit, AURenderCallback inProc, void *_Nullable inProcUserData);
AT_EXPORT OSStatus AudioUnitRemoveRenderNotify(AudioUnit inUnit, AURenderCallback inProc, void *_Nullable inProcUserData);
AT_EXPORT OSStatus AudioUnitGetParameter(AudioUnit inUnit, AudioUnitParameterID inID, AudioUnitScope inScope, AudioUnitElement inElement,
                                         AudioUnitParameterValue *outValue);
AT_EXPORT OSStatus AudioUnitSetParameter(AudioUnit inUnit, AudioUnitParameterID inID, AudioUnitScope inScope, AudioUnitElement inElement,
                                         AudioUnitParameterValue inValue, UInt32 inBufferOffsetInFrames);
AT_EXPORT OSStatus AudioUnitRender(AudioUnit inUnit, AudioUnitRenderActionFlags *_Nullable ioActionFlags, const AudioTimeStamp *inTimeStamp,
                                   UInt32 inOutputBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
AT_EXPORT OSStatus AudioUnitProcess(AudioUnit inUnit, AudioUnitRenderActionFlags *_Nullable ioActionFlags, const AudioTimeStamp *inTimeStamp,
                                    UInt32 inNumberFrames, AudioBufferList *ioData);
AT_EXPORT OSStatus AudioUnitReset(AudioUnit inUnit, AudioUnitScope inScope, AudioUnitElement inElement);
#pragma clang assume_nonnull end
__END_DECLS
#endif
