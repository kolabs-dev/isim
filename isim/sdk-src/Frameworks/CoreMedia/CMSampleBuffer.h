#pragma once
/* isim Core Media for C: the sample buffer type, so C and Objective-C interfaces (ReplayKit's capture handler) can name
   it. A CMSampleBufferRef is Swift's CMSampleBuffer; isim has no C functions over it yet. */
#include <CoreFoundation/CoreFoundation.h>
#if !defined(__swift__)
typedef struct opaqueCMSampleBuffer *CMSampleBufferRef;
#endif
