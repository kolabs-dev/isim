#pragma once
/* isim AVFAudio: the basic types (AVAudioFramePosition, …) and the 3D structs, as Apple's AVAudioTypes.h. */
#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <AudioToolbox/AudioToolbox.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef int64_t AVAudioFramePosition;
typedef uint32_t AVAudioFrameCount;
typedef uint32_t AVAudioPacketCount;
typedef uint32_t AVAudioChannelCount;
typedef void (^AVAudioNodeCompletionHandler)(void);
typedef NSInteger AVAudioNodeBus;
typedef struct AVAudio3DPoint { float x, y, z; } AVAudio3DPoint;
typedef AVAudio3DPoint AVAudio3DVector;
typedef struct AVAudio3DVectorOrientation { AVAudio3DVector forward, up; } AVAudio3DVectorOrientation;
typedef struct AVAudio3DAngularOrientation { float yaw, pitch, roll; } AVAudio3DAngularOrientation;
static inline AVAudio3DPoint AVAudioMake3DPoint(float x, float y, float z) { AVAudio3DPoint p = {x, y, z}; return p; }
static inline AVAudio3DVector AVAudioMake3DVector(float x, float y, float z) { AVAudio3DVector v = {x, y, z}; return v; }
static inline AVAudio3DVectorOrientation AVAudioMake3DVectorOrientation(AVAudio3DVector forward, AVAudio3DVector up) {
    AVAudio3DVectorOrientation o = {forward, up}; return o;
}
static inline AVAudio3DAngularOrientation AVAudioMake3DAngularOrientation(float yaw, float pitch, float roll) {
    AVAudio3DAngularOrientation o = {yaw, pitch, roll}; return o;
}
NS_ASSUME_NONNULL_END
#endif
