#pragma once
/* isim AudioToolbox for C: Audio Format Services (Apple's AudioFormat.h), over isim's Swift implementation (swift/overlays/AudioToolbox/AudioFunctions.swift). */
#include <AudioToolbox/AudioToolboxBase.h>
#if !defined(__swift__)
#include <stdio.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
AT_EXPORT OSStatus AudioFormatGetProperty(AudioFormatPropertyID inPropertyID, UInt32 inSpecifierSize, const void * _Nullable inSpecifier, UInt32 * _Nullable ioPropertyDataSize, void * _Nullable outPropertyData);
AT_EXPORT OSStatus AudioFormatGetPropertyInfo(AudioFormatPropertyID inPropertyID, UInt32 inSpecifierSize, const void * _Nullable inSpecifier, UInt32 * outPropertyDataSize);
#pragma clang assume_nonnull end
__END_DECLS
#endif
