#pragma once
/* isim Core Media for C: times, time ranges and mappings, simple queues and buffer queues (CoreMedia.framework re-exports
   libswiftCoreMedia.dylib; Swift uses the overlay, and these headers are hidden from Swift). Not available from C yet:
   sample buffers, format descriptions, clocks and timebases. */
#include <CoreMedia/CMTime.h>
#include <CoreMedia/CMTimeRange.h>
#include <CoreMedia/CMSimpleQueue.h>
#include <CoreMedia/CMBufferQueue.h>
