#pragma once
/* isim AudioToolbox for C: Audio Queue Services (Apple's AudioQueue.h), over isim's Swift implementation
 * (swift/overlays/AudioToolbox/AudioServices.swift): output plays through the host mixer, input reads the simulated
 * microphone. Run loop callbacks run on the main queue (the run loop mode is ignored). */
#include <AudioToolbox/AudioToolboxBase.h>
#include <dispatch/dispatch.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef UInt32 AudioQueueParameterID;
typedef Float32 AudioQueueParameterValue;
enum {
    kAudioQueueParam_Volume = 1,
    kAudioQueueParam_PlayRate = 2,
    kAudioQueueParam_Pitch = 3,
    kAudioQueueParam_VolumeRampTime = 4,
    kAudioQueueParam_Pan = 13,
    kAudioQueueProperty_IsRunning = 'aqrn',
    kAudioQueueProperty_StreamDescription = 'aqft',
    kAudioQueueProperty_CurrentLevelMeter = 'aqmv',
    kAudioQueueProperty_EnableLevelMetering = 'aqme',
    kAudioQueueProperty_EnableTimePitch = 'q_tp',
    kAudioQueueProperty_TimePitchAlgorithm = 'qtpa',
    kAudioQueueProperty_TimePitchBypass = 'qtpb',
    kAudioQueueTimePitchAlgorithm_Spectral = 'spec',
    kAudioQueueTimePitchAlgorithm_TimeDomain = 'tido',
    kAudioQueueTimePitchAlgorithm_Varispeed = 'vspd',
    kAudioQueueErr_InvalidBuffer = -66687,
    kAudioQueueErr_BufferEmpty = -66686,
    kAudioQueueErr_InvalidParameter = -66678,
    kAudioQueueErr_InvalidPropertySize = -66683,
    kAudioQueueErr_InvalidProperty = -66682,
    kAudioQueueErr_EnqueueDuringReset = -66632,
    kAudioQueueErr_InvalidRunState = -66681,
    kAudioQueueErr_InvalidPropertyValue = -66684,
    kAudioQueueErr_InvalidTapContext = -66630,
    kAudioQueueErr_InvalidTapType = -66629,
};
typedef void (^AudioQueueOutputCallbackBlock)(AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);
typedef void (^AudioQueueInputCallbackBlock)(AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime,
                                             UInt32 inNumberPacketDescriptions, const AudioStreamPacketDescription *_Nullable inPacketDescs);

AT_EXPORT OSStatus AudioQueueNewOutput(const AudioStreamBasicDescription *inFormat, AudioQueueOutputCallback inCallbackProc,
                                       void *_Nullable inUserData, CFRunLoopRef _Nullable inCallbackRunLoop,
                                       CFStringRef _Nullable inCallbackRunLoopMode, UInt32 inFlags, AudioQueueRef _Nullable *_Nonnull outAQ);
AT_EXPORT OSStatus AudioQueueNewInput(const AudioStreamBasicDescription *inFormat, AudioQueueInputCallback inCallbackProc,
                                      void *_Nullable inUserData, CFRunLoopRef _Nullable inCallbackRunLoop,
                                      CFStringRef _Nullable inCallbackRunLoopMode, UInt32 inFlags, AudioQueueRef _Nullable *_Nonnull outAQ);
AT_EXPORT OSStatus AudioQueueNewOutputWithDispatchQueue(AudioQueueRef _Nullable *_Nonnull outAQ, const AudioStreamBasicDescription *inFormat,
                                                        UInt32 inFlags, dispatch_queue_t inCallbackDispatchQueue,
                                                        AudioQueueOutputCallbackBlock inCallbackBlock);
AT_EXPORT OSStatus AudioQueueNewInputWithDispatchQueue(AudioQueueRef _Nullable *_Nonnull outAQ, const AudioStreamBasicDescription *inFormat,
                                                       UInt32 inFlags, dispatch_queue_t inCallbackDispatchQueue,
                                                       AudioQueueInputCallbackBlock inCallbackBlock);
AT_EXPORT OSStatus AudioQueueDispose(AudioQueueRef inAQ, Boolean inImmediate);
AT_EXPORT OSStatus AudioQueueAllocateBuffer(AudioQueueRef inAQ, UInt32 inBufferByteSize, AudioQueueBufferRef _Nullable *_Nonnull outBuffer);
AT_EXPORT OSStatus AudioQueueAllocateBufferWithPacketDescriptions(AudioQueueRef inAQ, UInt32 inBufferByteSize, UInt32 inNumberPacketDescriptions,
                                                                  AudioQueueBufferRef _Nullable *_Nonnull outBuffer);
AT_EXPORT OSStatus AudioQueueFreeBuffer(AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);
AT_EXPORT OSStatus AudioQueueEnqueueBuffer(AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, UInt32 inNumPacketDescs,
                                           const AudioStreamPacketDescription *_Nullable inPacketDescs);
AT_EXPORT OSStatus AudioQueueStart(AudioQueueRef inAQ, const AudioTimeStamp *_Nullable inStartTime);
AT_EXPORT OSStatus AudioQueuePrime(AudioQueueRef inAQ, UInt32 inNumberOfFramesToPrepare, UInt32 *_Nullable outNumberOfFramesPrepared);
AT_EXPORT OSStatus AudioQueueStop(AudioQueueRef inAQ, Boolean inImmediate);
AT_EXPORT OSStatus AudioQueuePause(AudioQueueRef inAQ);
AT_EXPORT OSStatus AudioQueueFlush(AudioQueueRef inAQ);
AT_EXPORT OSStatus AudioQueueReset(AudioQueueRef inAQ);
AT_EXPORT OSStatus AudioQueueGetCurrentTime(AudioQueueRef inAQ, AudioQueueTimelineRef _Nullable inTimeline,
                                            AudioTimeStamp *_Nullable outTimeStamp, Boolean *_Nullable outTimelineDiscontinuity);
AT_EXPORT OSStatus AudioQueueGetParameter(AudioQueueRef inAQ, AudioQueueParameterID inParamID, AudioQueueParameterValue *outValue);
AT_EXPORT OSStatus AudioQueueSetParameter(AudioQueueRef inAQ, AudioQueueParameterID inParamID, AudioQueueParameterValue inValue);
AT_EXPORT OSStatus AudioQueueGetProperty(AudioQueueRef inAQ, AudioQueuePropertyID inID, void *outData, UInt32 *ioDataSize);
AT_EXPORT OSStatus AudioQueueSetProperty(AudioQueueRef inAQ, AudioQueuePropertyID inID, const void *inData, UInt32 inDataSize);
AT_EXPORT OSStatus AudioQueueGetPropertySize(AudioQueueRef inAQ, AudioQueuePropertyID inID, UInt32 *outDataSize);
AT_EXPORT OSStatus AudioQueueAddPropertyListener(AudioQueueRef inAQ, AudioQueuePropertyID inID, AudioQueuePropertyListenerProc inProc,
                                                 void *_Nullable inUserData);
AT_EXPORT OSStatus AudioQueueRemovePropertyListener(AudioQueueRef inAQ, AudioQueuePropertyID inID, AudioQueuePropertyListenerProc inProc,
                                                    void *_Nullable inUserData);
AT_EXPORT OSStatus AudioQueueProcessingTapNew(AudioQueueRef inAQ, AudioQueueProcessingTapCallback inCallback, void *_Nullable inClientData,
                                              AudioQueueProcessingTapFlags inFlags, UInt32 *outMaxFrames,
                                              AudioStreamBasicDescription *outProcessingFormat,
                                              AudioQueueProcessingTapRef _Nullable *_Nonnull outAQTap);
AT_EXPORT OSStatus AudioQueueProcessingTapDispose(AudioQueueProcessingTapRef inAQTap);
AT_EXPORT OSStatus AudioQueueProcessingTapGetSourceAudio(AudioQueueProcessingTapRef inAQTap, UInt32 inNumberFrames, AudioTimeStamp *ioTimeStamp,
                                                         AudioQueueProcessingTapFlags *outFlags, UInt32 *outNumberFrames,
                                                         AudioBufferList *ioData);
AT_EXPORT OSStatus AudioQueueProcessingTapGetQueueTime(AudioQueueProcessingTapRef inAQTap, Float64 *outQueueSampleTime,
                                                       UInt32 *outQueueFrameCount);
#pragma clang assume_nonnull end
__END_DECLS
#endif
