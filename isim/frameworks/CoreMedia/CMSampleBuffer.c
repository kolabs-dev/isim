// isim Core Media for C: the sample buffer functions that return a CMTime (issue #707). The buffer is Swift's
// CMSampleBuffer (swift/overlays/CoreMedia/SampleBuffer.swift), which exports the other C functions.
#include <CoreMedia/CMSampleBuffer.h>

extern void _isim_CMSampleBufferGetTime(CMSampleBufferRef sbuf, int32_t which, CMTime *out);
static CMTime get_time(CMSampleBufferRef b, int32_t which) { CMTime t = kCMTimeInvalid; _isim_CMSampleBufferGetTime(b, which, &t); return t; }
CMTime CMSampleBufferGetPresentationTimeStamp(CMSampleBufferRef sbuf) { return get_time(sbuf, 0); }
CMTime CMSampleBufferGetDecodeTimeStamp(CMSampleBufferRef sbuf) { return get_time(sbuf, 1); }
CMTime CMSampleBufferGetDuration(CMSampleBufferRef sbuf) { return get_time(sbuf, 2); }
CMTime CMSampleBufferGetOutputPresentationTimeStamp(CMSampleBufferRef sbuf) { return get_time(sbuf, 3); }
CMTime CMSampleBufferGetOutputDuration(CMSampleBufferRef sbuf) { return get_time(sbuf, 4); }
