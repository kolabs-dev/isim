#pragma once
/* isim Core Media for C: time ranges and time mappings (CMTimeRange and its basic functions are in CMTime.h) */
#include <CoreMedia/CMTime.h>
#if !defined(__swift__)
__BEGIN_DECLS
#define CMTIMERANGE_IS_INVALID(range) (!CMTIMERANGE_IS_VALID(range))
#define CMTIMERANGE_IS_INDEFINITE(range) ((Boolean)(CMTIMERANGE_IS_VALID(range) && (CMTIME_IS_INDEFINITE(range.start) || CMTIME_IS_INDEFINITE(range.duration))))
CMTimeRange CMTimeRangeFromTimeToTime(CMTime start, CMTime end);
CMTimeRange CMTimeRangeGetUnion(CMTimeRange range, CMTimeRange otherRange);
CMTimeRange CMTimeRangeGetIntersection(CMTimeRange range, CMTimeRange otherRange);
Boolean CMTimeRangeContainsTimeRange(CMTimeRange range, CMTimeRange otherRange);
CMTime CMTimeClampToRange(CMTime time, CMTimeRange range);
CMTime CMTimeMapTimeFromRangeToRange(CMTime t, CMTimeRange fromRange, CMTimeRange toRange);
CMTime CMTimeMapDurationFromRangeToRange(CMTime dur, CMTimeRange fromRange, CMTimeRange toRange);
CMTime CMTimeFoldIntoRange(CMTime time, CMTimeRange foldRange);
extern const CFStringRef kCMTimeValueKey, kCMTimeScaleKey, kCMTimeEpochKey, kCMTimeFlagsKey;
extern const CFStringRef kCMTimeRangeStartKey, kCMTimeRangeDurationKey;
CFDictionaryRef CMTimeCopyAsDictionary(CMTime time, CFAllocatorRef allocator) CF_RETURNS_RETAINED;
CMTime CMTimeMakeFromDictionary(CFDictionaryRef dictionaryRepresentation);
CFStringRef CMTimeCopyDescription(CFAllocatorRef allocator, CMTime time) CF_RETURNS_RETAINED;
void CMTimeShow(CMTime time);
CFDictionaryRef CMTimeRangeCopyAsDictionary(CMTimeRange range, CFAllocatorRef allocator) CF_RETURNS_RETAINED;
CMTimeRange CMTimeRangeMakeFromDictionary(CFDictionaryRef dictionaryRepresentation);
CFStringRef CMTimeRangeCopyDescription(CFAllocatorRef allocator, CMTimeRange range) CF_RETURNS_RETAINED;
void CMTimeRangeShow(CMTimeRange range);

/* an edit: media of the source range plays during the target range (an empty edit has no source: source.start invalid) */
typedef struct { CMTimeRange source; CMTimeRange target; } CMTimeMapping;
extern const CMTimeMapping kCMTimeMappingInvalid;
#define CMTIMEMAPPING_IS_VALID(mapping) (CMTIMERANGE_IS_VALID(mapping.target))
#define CMTIMEMAPPING_IS_INVALID(mapping) (!CMTIMEMAPPING_IS_VALID(mapping))
#define CMTIMEMAPPING_IS_EMPTY(mapping) ((Boolean)(!CMTIME_IS_NUMERIC(mapping.source.start) && CMTIMERANGE_IS_VALID(mapping.target)))
CMTimeMapping CMTimeMappingMake(CMTimeRange source, CMTimeRange target);
CMTimeMapping CMTimeMappingMakeEmpty(CMTimeRange target);
extern const CFStringRef kCMTimeMappingSourceKey, kCMTimeMappingTargetKey;
CFDictionaryRef CMTimeMappingCopyAsDictionary(CMTimeMapping mapping, CFAllocatorRef allocator) CF_RETURNS_RETAINED;
CMTimeMapping CMTimeMappingMakeFromDictionary(CFDictionaryRef dictionaryRepresentation);
CFStringRef CMTimeMappingCopyDescription(CFAllocatorRef allocator, CMTimeMapping mapping) CF_RETURNS_RETAINED;
void CMTimeMappingShow(CMTimeMapping mapping);
__END_DECLS
#endif
