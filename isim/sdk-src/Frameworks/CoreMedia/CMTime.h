#pragma once
#include <CoreFoundation/CoreFoundation.h>
#if !defined(__swift__)
__BEGIN_DECLS
typedef int64_t CMTimeValue;
typedef int32_t CMTimeScale;
typedef int64_t CMTimeEpoch;
typedef CF_OPTIONS(uint32_t, CMTimeFlags) {
    kCMTimeFlags_Valid = 1UL << 0, kCMTimeFlags_HasBeenRounded = 1UL << 1, kCMTimeFlags_PositiveInfinity = 1UL << 2,
    kCMTimeFlags_NegativeInfinity = 1UL << 3, kCMTimeFlags_Indefinite = 1UL << 4,
    kCMTimeFlags_ImpliedValueFlagsMask = kCMTimeFlags_PositiveInfinity | kCMTimeFlags_NegativeInfinity | kCMTimeFlags_Indefinite,
};
#define kCMTimeMaxTimescale 0x7fffffffL
typedef struct { CMTimeValue value; CMTimeScale timescale; CMTimeFlags flags; CMTimeEpoch epoch; } CMTime;
typedef CF_ENUM(uint32_t, CMTimeRoundingMethod) {
    kCMTimeRoundingMethod_RoundHalfAwayFromZero = 1, kCMTimeRoundingMethod_RoundTowardZero = 2, kCMTimeRoundingMethod_RoundAwayFromZero = 3,
    kCMTimeRoundingMethod_QuickTime = 4, kCMTimeRoundingMethod_RoundTowardPositiveInfinity = 5, kCMTimeRoundingMethod_RoundTowardNegativeInfinity = 6,
    kCMTimeRoundingMethod_Default = kCMTimeRoundingMethod_RoundHalfAwayFromZero,
};
#define CMTIME_IS_VALID(time) ((Boolean)(((time).flags & kCMTimeFlags_Valid) != 0))
#define CMTIME_IS_INVALID(time) (!CMTIME_IS_VALID(time))
#define CMTIME_IS_POSITIVE_INFINITY(time) ((Boolean)(CMTIME_IS_VALID(time) && (((time).flags & kCMTimeFlags_PositiveInfinity) != 0)))
#define CMTIME_IS_NEGATIVE_INFINITY(time) ((Boolean)(CMTIME_IS_VALID(time) && (((time).flags & kCMTimeFlags_NegativeInfinity) != 0)))
#define CMTIME_IS_INDEFINITE(time) ((Boolean)(CMTIME_IS_VALID(time) && (((time).flags & kCMTimeFlags_Indefinite) != 0)))
#define CMTIME_IS_NUMERIC(time) ((Boolean)(((time).flags & (kCMTimeFlags_Valid | kCMTimeFlags_ImpliedValueFlagsMask)) == kCMTimeFlags_Valid))
#define CMTIME_HAS_BEEN_ROUNDED(time) ((Boolean)(CMTIME_IS_NUMERIC(time) && (((time).flags & kCMTimeFlags_HasBeenRounded) != 0)))
extern const CMTime kCMTimeInvalid, kCMTimeIndefinite, kCMTimePositiveInfinity, kCMTimeNegativeInfinity, kCMTimeZero;
CMTime CMTimeMake(int64_t value, int32_t timescale);
CMTime CMTimeMakeWithEpoch(int64_t value, int32_t timescale, int64_t epoch);
CMTime CMTimeMakeWithSeconds(double seconds, int32_t preferredTimescale);
double CMTimeGetSeconds(CMTime time);
CMTime CMTimeConvertScale(CMTime time, int32_t newTimescale, CMTimeRoundingMethod method);
CMTime CMTimeAdd(CMTime lhs, CMTime rhs);
CMTime CMTimeSubtract(CMTime lhs, CMTime rhs);
CMTime CMTimeMultiply(CMTime time, int32_t multiplier);
CMTime CMTimeMultiplyByFloat64(CMTime time, double multiplier);
CMTime CMTimeMultiplyByRatio(CMTime time, int32_t multiplier, int32_t divisor);
int32_t CMTimeCompare(CMTime time1, CMTime time2);
#define CMTIME_COMPARE_INLINE(time1, comparator, time2) ((Boolean)(CMTimeCompare(time1, time2) comparator 0))
CMTime CMTimeMinimum(CMTime time1, CMTime time2);
CMTime CMTimeMaximum(CMTime time1, CMTime time2);
CMTime CMTimeAbsoluteValue(CMTime time);
typedef struct { CMTime start; CMTime duration; } CMTimeRange;
extern const CMTimeRange kCMTimeRangeZero, kCMTimeRangeInvalid;
CMTimeRange CMTimeRangeMake(CMTime start, CMTime duration);
CMTime CMTimeRangeGetEnd(CMTimeRange range);
Boolean CMTimeRangeContainsTime(CMTimeRange range, CMTime time);
Boolean CMTimeRangeEqual(CMTimeRange range1, CMTimeRange range2);
#define CMTIMERANGE_IS_VALID(range) ((Boolean)(CMTIME_IS_VALID(range.start) && CMTIME_IS_VALID(range.duration) && (range.duration.epoch == 0) && (range.duration.value >= 0)))
#define CMTIMERANGE_IS_EMPTY(range) ((Boolean)(CMTIMERANGE_IS_VALID(range) && (CMTIME_COMPARE_INLINE(range.duration, ==, kCMTimeZero))))
__END_DECLS
#endif
