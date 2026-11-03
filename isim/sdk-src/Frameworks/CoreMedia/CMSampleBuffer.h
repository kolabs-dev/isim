#pragma once
/* isim Core Media for C: sample buffers. A CMSampleBufferRef is Swift's CMSampleBuffer (the one capture outputs and
   AVAssetReader deliver and AVAssetWriter takes); C has its image buffer, timing, sample count and readiness (issue
   #707). Not available from C yet: creating sample buffers, their block buffers, format descriptions and attachments. */
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CMTime.h>
#include <CoreMedia/CMBufferQueue.h>
#include <CoreVideo/CVImageBuffer.h>
#if !defined(__swift__)
CF_EXTERN_C_BEGIN
typedef struct opaqueCMSampleBuffer *CMSampleBufferRef;
CVImageBufferRef CMSampleBufferGetImageBuffer(CMSampleBufferRef sbuf);
CMTime CMSampleBufferGetPresentationTimeStamp(CMSampleBufferRef sbuf);
CMTime CMSampleBufferGetDecodeTimeStamp(CMSampleBufferRef sbuf);
CMTime CMSampleBufferGetDuration(CMSampleBufferRef sbuf);
CMTime CMSampleBufferGetOutputPresentationTimeStamp(CMSampleBufferRef sbuf);
CMTime CMSampleBufferGetOutputDuration(CMSampleBufferRef sbuf);
CMItemCount CMSampleBufferGetNumSamples(CMSampleBufferRef sbuf);
size_t CMSampleBufferGetTotalSampleSize(CMSampleBufferRef sbuf);
Boolean CMSampleBufferIsValid(CMSampleBufferRef sbuf);
Boolean CMSampleBufferDataIsReady(CMSampleBufferRef sbuf);
CF_EXTERN_C_END
#endif
