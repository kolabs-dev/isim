#pragma once
/* isim AudioToolbox for C: Audio Component Services (Apple's AudioComponent.h). The components are isim's built-in
 * Apple audio units (swift/overlays/AudioToolbox/AudioUnits.swift); third-party Audio Unit extensions are not loaded. */
#include <AudioToolbox/AudioToolboxBase.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
typedef CF_OPTIONS(UInt32, AudioComponentFlags) {
    kAudioComponentFlag_Unsearchable = 1,
    kAudioComponentFlag_SandboxSafe = 2,
    kAudioComponentFlag_IsV3AudioUnit = 4,
    kAudioComponentFlag_RequiresAsyncInstantiation = 8,
    kAudioComponentFlag_CanLoadInProcess = 0x10,
};
typedef CF_OPTIONS(UInt32, AudioComponentInstantiationOptions) {
    kAudioComponentInstantiation_LoadOutOfProcess = 1,
    kAudioComponentInstantiation_LoadInProcess = 2,
    kAudioComponentInstantiation_LoadedRemotely = 1u << 31,
};
AT_EXPORT AudioComponent _Nullable AudioComponentFindNext(AudioComponent _Nullable inComponent, const AudioComponentDescription *inDesc);
AT_EXPORT UInt32 AudioComponentCount(const AudioComponentDescription *inDesc);
AT_EXPORT OSStatus AudioComponentCopyName(AudioComponent inComponent, CFStringRef _Nullable *_Nonnull outName);
AT_EXPORT OSStatus AudioComponentGetDescription(AudioComponent inComponent, AudioComponentDescription *outDesc);
AT_EXPORT OSStatus AudioComponentGetVersion(AudioComponent inComponent, UInt32 *outVersion);
AT_EXPORT OSStatus AudioComponentInstanceNew(AudioComponent inComponent, AudioComponentInstance _Nullable *_Nonnull outInstance);
AT_EXPORT void AudioComponentInstantiate(AudioComponent inComponent, AudioComponentInstantiationOptions inOptions,
                                         void (^inCompletionHandler)(AudioComponentInstance _Nullable, OSStatus));
AT_EXPORT OSStatus AudioComponentInstanceDispose(AudioComponentInstance inInstance);
AT_EXPORT AudioComponent AudioComponentInstanceGetComponent(AudioComponentInstance inInstance);
#pragma clang assume_nonnull end
__END_DECLS
#endif
