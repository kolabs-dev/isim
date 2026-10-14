#pragma once
/* isim AVFAudio for Objective-C: AVAudioSession and the other audio classes are isim's AVFoundation (on iOS,
 * AVFoundation re-exports AVFAudio; isim keeps them in one module), so this header imports AVFoundation's and
 * AVFAudio.framework re-exports AVFoundation.framework. Swift uses the AVFAudio module, which re-exports AVFoundation. */
#if !defined(__swift__)
#import <AVFoundation/AVFoundation.h>
#endif
