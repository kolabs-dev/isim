#pragma once
/* isim AudioUnit for C: on iOS the Audio Unit API is AudioToolbox's (AudioComponent, AUComponent,
 * AudioUnitProperties, AudioOutputUnit); this header includes AudioToolbox's and AudioUnit.framework re-exports
 * AudioToolbox.framework. Swift uses the AudioUnit module, which re-exports AudioToolbox. */
#if !defined(__swift__)
#include <AudioToolbox/AudioUnit.h>
#endif
