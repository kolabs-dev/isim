#pragma once
/* isim Core Media for C: times, time ranges and mappings, simple queues and buffer queues (CoreMedia.framework re-exports
   libswiftCoreMedia.dylib; Swift uses the overlay, and these headers are hidden from Swift). Not available from C yet:
   creating sample buffers (their image buffer and timing are: CMSampleBuffer.h), format descriptions (only the
   CMVideoDimensions and CMPersistentTrackID types), clocks and timebases. */
#include <CoreMedia/CMTime.h>
#include <CoreMedia/CMTimeRange.h>
#include <CoreMedia/CMSimpleQueue.h>
#include <CoreMedia/CMBufferQueue.h>
#include <CoreMedia/CMSampleBuffer.h>
#include <CoreMedia/CMFormatDescription.h>
