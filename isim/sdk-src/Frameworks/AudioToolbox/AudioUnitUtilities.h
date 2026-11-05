#pragma once
/* isim AudioToolbox for C: parameter and event listeners (Apple's AudioUnitUtilities.h), over isim's Swift implementation (swift/overlays/AudioToolbox/AudioFunctions.swift). */
#include <AudioToolbox/AudioToolboxBase.h>
#if !defined(__swift__)
#include <stdio.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
AT_EXPORT OSStatus AUEventListenerAddEventType(AUEventListenerRef inListener, void * _Nullable inObject, const AudioUnitEvent * inEvent);
AT_EXPORT OSStatus AUEventListenerCreate(AUEventListenerProc inProc, void * _Nullable inUserData, CFRunLoopRef _Nullable inRunLoop, CFStringRef _Nullable inRunLoopMode, Float32 inNotificationInterval, Float32 inValueChangeGranularity, AUEventListenerRef _Nullable * _Nonnull outListener);
AT_EXPORT OSStatus AUEventListenerCreateWithDispatchQueue(AUEventListenerRef _Nullable * _Nonnull outListener, Float32 inNotificationInterval, Float32 inValueChangeGranularity, dispatch_queue_t inDispatchQueue, AUEventListenerBlock inBlock);
AT_EXPORT OSStatus AUEventListenerNotify(AUEventListenerRef _Nullable inSendingListener, void * _Nullable inSendingObject, const AudioUnitEvent * inEvent);
AT_EXPORT OSStatus AUEventListenerRemoveEventType(AUEventListenerRef inListener, void * _Nullable inObject, const AudioUnitEvent * inEvent);
AT_EXPORT OSStatus AUListenerAddParameter(AUParameterListenerRef inListener, void * _Nullable inObject, const AudioUnitParameter * inParameter);
AT_EXPORT OSStatus AUListenerCreate(AUParameterListenerProc inProc, void * inUserData, CFRunLoopRef _Nullable inRunLoop, CFStringRef _Nullable inRunLoopMode, Float32 inNotificationInterval, AUParameterListenerRef _Nullable * _Nonnull outListener);
AT_EXPORT OSStatus AUListenerCreateWithDispatchQueue(AUParameterListenerRef _Nullable * _Nonnull outListener, Float32 inNotificationInterval, dispatch_queue_t inDispatchQueue, AUParameterListenerBlock inBlock);
AT_EXPORT OSStatus AUListenerDispose(AUParameterListenerRef inListener);
AT_EXPORT OSStatus AUListenerRemoveParameter(AUParameterListenerRef inListener, void * _Nullable inObject, const AudioUnitParameter * inParameter);
AT_EXPORT char * AUParameterFormatValue(Float64 inParameterValue, const AudioUnitParameter * inParameter, char * inTextBuffer, UInt32 inDigits);
AT_EXPORT OSStatus AUParameterListenerNotify(AUParameterListenerRef _Nullable inSendingListener, void * _Nullable inSendingObject, const AudioUnitParameter * inParameter);
AT_EXPORT OSStatus AUParameterSet(AUParameterListenerRef _Nullable inSendingListener, void * _Nullable inSendingObject, const AudioUnitParameter * inParameter, AudioUnitParameterValue inValue, UInt32 inBufferOffsetInFrames);
AT_EXPORT AudioUnitParameterValue AUParameterValueFromLinear(Float32 inLinearValue, const AudioUnitParameter * inParameter);
AT_EXPORT Float32 AUParameterValueToLinear(AudioUnitParameterValue inParameterValue, const AudioUnitParameter * inParameter);
#pragma clang assume_nonnull end
__END_DECLS
#endif
