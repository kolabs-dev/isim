#pragma once
/* isim AudioToolbox for C: starting and stopping I/O units (Apple's AudioOutputUnit.h); RemoteIO plays through the
 * host mixer and records from the simulated microphone. */
#include <AudioToolbox/AUComponent.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
AT_EXPORT OSStatus AudioOutputUnitStart(AudioUnit ci);
AT_EXPORT OSStatus AudioOutputUnitStop(AudioUnit ci);
#pragma clang assume_nonnull end
__END_DECLS
#endif
