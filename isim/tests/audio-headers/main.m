// The audio framework headers from Objective-C and C (issue #223): <AVFAudio/AVFAudio.h>, <AudioUnit/AudioUnit.h>,
// <CoreAudio/CoreAudioTypes.h>, linked with -framework AVFAudio -framework AudioUnit -framework CoreAudio. Prints
// PASS/FAIL per check, then "audio headers test: N/M passed"; the exit code is the number of failures.
#import <AVFAudio/AVFAudio.h>
#import <AudioUnit/AudioUnit.h>
#import <CoreAudio/CoreAudio.h>
#include <stddef.h>
#include <stdio.h>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (line %d)\n", #cond, __LINE__); } } while (0)

int main(void) {
    @autoreleasepool {
        // AVFAudio: the session class (isim's AVFoundation, re-exported)
        AVAudioSession *session = [AVAudioSession sharedInstance];
        CHECK(session != nil && [session isKindOfClass:[AVAudioSession class]]);
        CHECK([session setCategory:AVAudioSessionCategoryPlayback error:NULL] && [session.category isEqualToString:AVAudioSessionCategoryPlayback]);

        // AVAudioSession's modes, options and policies (issue #224)
        CHECK([AVAudioSessionModeVideoChat isEqualToString:@"AVAudioSessionModeVideoChat"] && [AVAudioSessionModeVoicePrompt isEqualToString:@"AVAudioSessionModeVoicePrompt"]);
        CHECK([AVAudioSessionModeVideoRecording isEqualToString:@"AVAudioSessionModeVideoRecording"] && [AVAudioSessionModeMeasurement isEqualToString:@"AVAudioSessionModeMeasurement"]);
        NSError *err = nil;
        CHECK(![session setCategory:AVAudioSessionCategoryRecord mode:AVAudioSessionModeDefault routeSharingPolicy:AVAudioSessionRouteSharingPolicyLongFormAudio
                            options:0 error:&err] && err.code == -50);
        CHECK([session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVideoChat routeSharingPolicy:AVAudioSessionRouteSharingPolicyIndependent
                           options:AVAudioSessionCategoryOptionOverrideMutedMicrophoneInterruption error:NULL]);
        CHECK(session.routeSharingPolicy == AVAudioSessionRouteSharingPolicyIndependent && [session.mode isEqualToString:AVAudioSessionModeVideoChat]);
        CHECK(session.categoryOptions == AVAudioSessionCategoryOptionOverrideMutedMicrophoneInterruption && AVAudioSessionCategoryOptionOverrideMutedMicrophoneInterruption == 0x80);
        CHECK([session setPrefersNoInterruptionsFromSystemAlerts:YES error:NULL] && session.prefersNoInterruptionsFromSystemAlerts);
        if (@available(iOS 18.2, *)) {
            CHECK([session setPrefersEchoCancelledInput:YES error:NULL] && session.prefersEchoCancelledInput);
            CHECK(session.isEchoCancelledInputAvailable && session.isEchoCancelledInputEnabled);
        }

        // AudioUnit: the description of a RemoteIO unit, the constants' values (four-character codes as on iOS)
        AudioComponentDescription desc = {kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple, 0, 0};
        CHECK(desc.componentType == 0x61756f75 && desc.componentSubType == 0x72696f63 && desc.componentManufacturer == 0x6170706c);
        CHECK(kAudioUnitScope_Input == 1 && kAudioUnitProperty_StreamFormat == 8 && kAudioUnitProperty_SetRenderCallback == 23);
        CHECK(kAudioOutputUnitProperty_EnableIO == 2003 && kAudioUnitErr_InvalidProperty == -10879);
        AURenderCallbackStruct cb = {NULL, NULL};
        CHECK(sizeof cb == 16 && sizeof(AudioUnitPropertyID) == 4 && sizeof(AudioUnitParameterValue) == 4);

        // CoreAudio / CoreAudioTypes: layouts and the format constants
        AudioStreamBasicDescription asbd = {48000, kAudioFormatLinearPCM, kAudioFormatFlagsNativeFloatPacked, 8, 1, 8, 2, 32, 0};
        CHECK(sizeof asbd == 40 && asbd.mFormatID == 0x6c70636d && asbd.mFormatFlags == (kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked));
        CHECK(kAudioFormatMPEG4AAC == 0x61616320 && kAudioFormatFlagIsNonInterleaved == 32 && kLinearPCMFormatFlagIsSignedInteger == 4);
        CHECK(sizeof(AudioBufferList) == 24 && offsetof(AudioBufferList, mBuffers) == 8 && sizeof(AudioTimeStamp) == 64);
        OSStatus ok = 0;
        CHECK(ok == 0);
    }
    printf("audio headers test: %d/%d passed\n", checks - failures, checks);
    return failures;
}
