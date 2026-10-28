#pragma once
/* isim AVFAudio for Objective-C: the classes are isim's AVFoundation Swift overlay's (on iOS, AVFoundation re-exports
 * AVFAudio; isim keeps them in one module), so AVFAudio.framework re-exports AVFoundation.framework. AVAudioSession is
 * declared in AVFoundation.h, which imports this header; the engine, nodes, formats, buffers, converter, file, player
 * and recorder (issue #553) are declared here. Swift uses the AVFAudio module, which re-exports AVFoundation. */
#if !defined(__swift__)
#import <AVFoundation/AVFoundation.h>
#import <AVFAudio/AVAudioTypes.h>
#import <AVFAudio/AVAudioSettings.h>
#import <AVFAudio/AVAudioChannelLayout.h>
#import <AVFAudio/AVAudioFormat.h>
#import <AVFAudio/AVAudioTime.h>
#import <AVFAudio/AVAudioBuffer.h>
#import <AVFAudio/AVAudioConverter.h>
#import <AVFAudio/AVAudioFile.h>
#import <AVFAudio/AVAudioMixing.h>
#import <AVFAudio/AVAudioConnectionPoint.h>
#import <AVFAudio/AVAudioNode.h>
#import <AVFAudio/AVAudioIONode.h>
#import <AVFAudio/AVAudioMixerNode.h>
#import <AVFAudio/AVAudioPlayerNode.h>
#import <AVFAudio/AVAudioSourceNode.h>
#import <AVFAudio/AVAudioSinkNode.h>
#import <AVFAudio/AVAudioUnit.h>
#import <AVFAudio/AVAudioUnitEffect.h>
#import <AVFAudio/AVAudioUnitReverb.h>
#import <AVFAudio/AVAudioUnitEQ.h>
#import <AVFAudio/AVAudioUnitDelay.h>
#import <AVFAudio/AVAudioUnitDistortion.h>
#import <AVFAudio/AVAudioUnitTimeEffect.h>
#import <AVFAudio/AVAudioUnitGenerator.h>
#import <AVFAudio/AVAudioUnitMIDIInstrument.h>
#import <AVFAudio/AVAudioUnitSampler.h>
#import <AVFAudio/AVMIDIPlayer.h>
#import <AVFAudio/AVMusicEvents.h>
#import <AVFAudio/AVAudioSequencer.h>
#import <AVFAudio/AVAudioEnvironmentNode.h>
#import <AVFAudio/AVAudioEngine.h>
#import <AVFAudio/AVAudioPlayer.h>
#import <AVFAudio/AVAudioRecorder.h>
#endif
