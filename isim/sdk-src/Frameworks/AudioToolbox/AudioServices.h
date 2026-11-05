#pragma once
/* isim AudioToolbox for C: System Sound Services (Apple's AudioServices.h), over isim's Swift implementation
 * (swift/overlays/AudioToolbox/AudioToolbox.swift): sounds from files play through the host mixer, Apple's built-in
 * sound IDs play synthesized stand-ins, vibration shows isim's haptic ring. Completions run on the main queue. */
#include <AudioToolbox/AudioToolboxBase.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef UInt32 SystemSoundID;
typedef void (*AudioServicesSystemSoundCompletionProc)(SystemSoundID ssID, void *_Nullable clientData);
enum {
    kSystemSoundID_Vibrate = 4095,
    kSystemSoundID_UserPreferredAlert = 0x1000,
    kSystemSoundID_FlashScreen = 0x0FFE,
    kAudioServicesNoError = 0,
    kAudioServicesUnsupportedPropertyError = 'pty?',
    kAudioServicesBadPropertySizeError = '!siz',
    kAudioServicesBadSpecifierError = 'spc?',
    kAudioServicesSystemSoundUnspecifiedError = -1500,
    kAudioServicesSystemSoundClientTimedOutError = -1501,
    kAudioServicesSystemSoundExceededMaximumDurationError = -1502,
};
AT_EXPORT OSStatus AudioServicesCreateSystemSoundID(CFURLRef inFileURL, SystemSoundID *outSystemSoundID);
AT_EXPORT OSStatus AudioServicesDisposeSystemSoundID(SystemSoundID inSystemSoundID);
AT_EXPORT void AudioServicesPlaySystemSound(SystemSoundID inSystemSoundID);
AT_EXPORT void AudioServicesPlayAlertSound(SystemSoundID inSystemSoundID);
AT_EXPORT void AudioServicesPlaySystemSoundWithCompletion(SystemSoundID inSystemSoundID, void (^_Nullable inCompletionBlock)(void));
AT_EXPORT void AudioServicesPlayAlertSoundWithCompletion(SystemSoundID inSystemSoundID, void (^_Nullable inCompletionBlock)(void));
AT_EXPORT OSStatus AudioServicesAddSystemSoundCompletion(SystemSoundID inSystemSoundID, CFRunLoopRef _Nullable inRunLoop,
                                                         CFStringRef _Nullable inRunLoopMode,
                                                         AudioServicesSystemSoundCompletionProc inCompletionRoutine,
                                                         void *_Nullable inClientData);
AT_EXPORT void AudioServicesRemoveSystemSoundCompletion(SystemSoundID inSystemSoundID);
/* issue #856 (AudioFunctions.swift) */
AT_EXPORT OSStatus AudioServicesGetProperty(AudioServicesPropertyID inPropertyID, UInt32 inSpecifierSize, const void * _Nullable inSpecifier, UInt32 * ioPropertyDataSize, void * _Nullable outPropertyData);
AT_EXPORT OSStatus AudioServicesGetPropertyInfo(AudioServicesPropertyID inPropertyID, UInt32 inSpecifierSize, const void * _Nullable inSpecifier, UInt32 * _Nullable outPropertyDataSize, Boolean * _Nullable outWritable);
AT_EXPORT OSStatus AudioServicesSetProperty(AudioServicesPropertyID inPropertyID, UInt32 inSpecifierSize, const void * _Nullable inSpecifier, UInt32 inPropertyDataSize, const void * inPropertyData);
#pragma clang assume_nonnull end
__END_DECLS
#endif
