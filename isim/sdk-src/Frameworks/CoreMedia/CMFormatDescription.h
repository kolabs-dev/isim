#pragma once
/* isim Core Media for C: the video dimensions and persistent track ID types, so C and Objective-C interfaces
   (AVFoundation's capture and editing) can name them. isim has no C functions over format descriptions yet. */
#include <CoreFoundation/CoreFoundation.h>
#if !defined(__swift__)
typedef int32_t CMPersistentTrackID;
enum { kCMPersistentTrackID_Invalid = 0 };
typedef struct { int32_t width; int32_t height; } CMVideoDimensions;
#endif
