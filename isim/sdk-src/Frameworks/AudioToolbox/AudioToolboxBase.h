#pragma once
/* isim AudioToolbox for C: what every AudioToolbox header shares: MacTypes, Core Foundation, the Core Audio types and
 * the C types of <_AudioToolboxTypes/AudioToolboxTypes.h> (opaque handles, callback types), which the Swift overlay
 * uses too, so the same objects cross between C and Swift. */
#include <CoreAudio/CoreAudioTypes.h>
#if !defined(__swift__)
#include <MacTypes.h>
#include <CoreFoundation/CoreFoundation.h>
#include <_AudioToolboxTypes/AudioToolboxTypes.h>
#if defined(__cplusplus)
#define AT_EXPORT extern "C" __attribute__((visibility("default")))
#else
#define AT_EXPORT extern __attribute__((visibility("default")))
#endif
#endif
