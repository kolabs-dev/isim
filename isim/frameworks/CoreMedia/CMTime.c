// isim Core Media for C: CMTime and CMTimeRange arithmetic, like Apple's: times with different timescales are combined
// at their least common multiple (capped at kCMTimeMaxTimescale, then rounded: kCMTimeFlags_HasBeenRounded); invalid,
// indefinite and infinite times follow Apple's rules.
#include <CoreMedia/CMTime.h>
#include <math.h>
#include <stdlib.h>

const CMTime kCMTimeInvalid = { 0, 0, 0, 0 };
const CMTime kCMTimeIndefinite = { 0, 0, kCMTimeFlags_Valid | kCMTimeFlags_Indefinite, 0 };
const CMTime kCMTimePositiveInfinity = { 0, 0, kCMTimeFlags_Valid | kCMTimeFlags_PositiveInfinity, 0 };
const CMTime kCMTimeNegativeInfinity = { 0, 0, kCMTimeFlags_Valid | kCMTimeFlags_NegativeInfinity, 0 };
const CMTime kCMTimeZero = { 0, 1, kCMTimeFlags_Valid, 0 };
const CMTimeRange kCMTimeRangeZero = { { 0, 1, kCMTimeFlags_Valid, 0 }, { 0, 1, kCMTimeFlags_Valid, 0 } };
const CMTimeRange kCMTimeRangeInvalid = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } };

CMTime CMTimeMake(int64_t value, int32_t timescale) {
    if (timescale <= 0) return kCMTimeInvalid;
    return (CMTime){ value, timescale, kCMTimeFlags_Valid, 0 };
}
CMTime CMTimeMakeWithEpoch(int64_t value, int32_t timescale, int64_t epoch) { CMTime t = CMTimeMake(value, timescale); t.epoch = epoch; return t; }
CMTime CMTimeMakeWithSeconds(double seconds, int32_t ts) {
    if (isnan(seconds) || ts <= 0) return kCMTimeInvalid;
    if (isinf(seconds)) return seconds > 0 ? kCMTimePositiveInfinity : kCMTimeNegativeInfinity;
    double v = round(seconds * ts);
    while (fabs(v) > 9.2e18 && ts > 1) { ts /= 2; v = round(seconds * ts); }
    CMTime t = CMTimeMake((int64_t)v, ts);
    if (v / ts != seconds) t.flags |= kCMTimeFlags_HasBeenRounded;
    return t;
}
double CMTimeGetSeconds(CMTime t) {
    if (!CMTIME_IS_VALID(t) || CMTIME_IS_INDEFINITE(t)) return NAN;
    if (CMTIME_IS_POSITIVE_INFINITY(t)) return INFINITY;
    if (CMTIME_IS_NEGATIVE_INFINITY(t)) return -INFINITY;
    return (double)t.value / t.timescale;
}
static int64_t rounded_div(__int128 n, __int128 d, CMTimeRoundingMethod m) {
    __int128 q = n / d, r = n % d;
    if (r == 0) return (int64_t)q;
    int neg = (n < 0) != (d < 0);
    switch (m) {
    case kCMTimeRoundingMethod_RoundTowardZero: return (int64_t)q;
    case kCMTimeRoundingMethod_RoundAwayFromZero: return (int64_t)(neg ? q - 1 : q + 1);
    case kCMTimeRoundingMethod_RoundTowardPositiveInfinity: return (int64_t)(neg ? q : q + 1);
    case kCMTimeRoundingMethod_RoundTowardNegativeInfinity: return (int64_t)(neg ? q - 1 : q);
    default: {
        __int128 ar = r < 0 ? -r : r, ad = d < 0 ? -d : d;
        return (int64_t)(2 * ar >= ad ? (neg ? q - 1 : q + 1) : q);
    }
    }
}
CMTime CMTimeConvertScale(CMTime t, int32_t ts, CMTimeRoundingMethod m) {
    if (!CMTIME_IS_NUMERIC(t)) return t;
    if (ts <= 0) return kCMTimeInvalid;
    __int128 n = (__int128)t.value * ts;
    CMTime r = { rounded_div(n, t.timescale, m), ts, t.flags, t.epoch };
    if (n % t.timescale) r.flags |= kCMTimeFlags_HasBeenRounded;
    return r;
}
static int64_t gcd64(int64_t a, int64_t b) { while (b) { int64_t t = a % b; a = b; b = t; } return a; }
/* the common timescale of two numeric times: their least common multiple, or the larger one when that is too big */
static int32_t common_scale(int32_t a, int32_t b) {
    int64_t l = (int64_t)a / gcd64(a, b) * b;
    return l <= kCMTimeMaxTimescale ? (int32_t)l : (a > b ? a : b);
}
static CMTime non_numeric_sum(CMTime a, CMTime b, int subtract) {
    if (!CMTIME_IS_VALID(a) || !CMTIME_IS_VALID(b)) return kCMTimeInvalid;
    if (CMTIME_IS_INDEFINITE(a) || CMTIME_IS_INDEFINITE(b)) return kCMTimeIndefinite;
    int sa = CMTIME_IS_POSITIVE_INFINITY(a) ? 1 : CMTIME_IS_NEGATIVE_INFINITY(a) ? -1 : 0;
    int sb = CMTIME_IS_POSITIVE_INFINITY(b) ? 1 : CMTIME_IS_NEGATIVE_INFINITY(b) ? -1 : 0;
    if (subtract) sb = -sb;
    if (sa && sb && sa != sb) return kCMTimeInvalid;             /* +inf - +inf */
    return (sa ? sa : sb) > 0 ? kCMTimePositiveInfinity : kCMTimeNegativeInfinity;
}
static CMTime sum(CMTime a, CMTime b, int subtract) {
    if (!CMTIME_IS_NUMERIC(a) || !CMTIME_IS_NUMERIC(b)) return non_numeric_sum(a, b, subtract);
    if (a.epoch != b.epoch) return kCMTimeInvalid;
    int32_t ts = common_scale(a.timescale, b.timescale);
    CMTime ca = CMTimeConvertScale(a, ts, kCMTimeRoundingMethod_Default), cb = CMTimeConvertScale(b, ts, kCMTimeRoundingMethod_Default);
    CMTime r = { subtract ? ca.value - cb.value : ca.value + cb.value, ts, kCMTimeFlags_Valid | ((ca.flags | cb.flags) & kCMTimeFlags_HasBeenRounded), a.epoch };
    return r;
}
CMTime CMTimeAdd(CMTime a, CMTime b) { return sum(a, b, 0); }
CMTime CMTimeSubtract(CMTime a, CMTime b) { return sum(a, b, 1); }
CMTime CMTimeMultiplyByRatio(CMTime t, int32_t mul, int32_t div) {
    if (!CMTIME_IS_VALID(t) || div == 0) return kCMTimeInvalid;
    if (!CMTIME_IS_NUMERIC(t)) {
        if (CMTIME_IS_INDEFINITE(t)) return t;
        int neg = ((mul < 0) != (div < 0));
        if (mul == 0) return kCMTimeInvalid;
        return (CMTIME_IS_POSITIVE_INFINITY(t) != neg) ? kCMTimePositiveInfinity : kCMTimeNegativeInfinity;
    }
    __int128 n = (__int128)t.value * mul;
    CMTime r = { rounded_div(n, div, kCMTimeRoundingMethod_Default), t.timescale, t.flags, t.epoch };
    if (n % div) r.flags |= kCMTimeFlags_HasBeenRounded;
    return r;
}
CMTime CMTimeMultiply(CMTime t, int32_t mul) { return CMTimeMultiplyByRatio(t, mul, 1); }
CMTime CMTimeMultiplyByFloat64(CMTime t, double mul) {
    if (!CMTIME_IS_NUMERIC(t)) return CMTimeMultiplyByRatio(t, mul < 0 ? -1 : mul > 0 ? 1 : 0, 1);
    double v = round((double)t.value * mul);
    CMTime r = { (int64_t)v, t.timescale, t.flags, t.epoch };
    if (v != (double)t.value * mul) r.flags |= kCMTimeFlags_HasBeenRounded;
    return r;
}
/* Apple's order: invalid times compare equal to each other and greater than valid ones; -inf < numeric < +inf < indefinite */
static int rank(CMTime t) {
    if (!CMTIME_IS_VALID(t)) return 4;
    if (CMTIME_IS_INDEFINITE(t)) return 3;
    if (CMTIME_IS_POSITIVE_INFINITY(t)) return 2;
    if (CMTIME_IS_NEGATIVE_INFINITY(t)) return 0;
    return 1;
}
int32_t CMTimeCompare(CMTime a, CMTime b) {
    int ra = rank(a), rb = rank(b);
    if (ra != rb) return ra < rb ? -1 : 1;
    if (ra != 1) return 0;
    if (a.epoch != b.epoch) return a.epoch < b.epoch ? -1 : 1;
    __int128 l = (__int128)a.value * b.timescale, r = (__int128)b.value * a.timescale;
    return l < r ? -1 : l > r ? 1 : 0;
}
CMTime CMTimeMinimum(CMTime a, CMTime b) {
    if (!CMTIME_IS_VALID(a)) return b;
    if (!CMTIME_IS_VALID(b)) return a;
    return CMTimeCompare(a, b) <= 0 ? a : b;
}
CMTime CMTimeMaximum(CMTime a, CMTime b) {
    if (!CMTIME_IS_VALID(a)) return b;
    if (!CMTIME_IS_VALID(b)) return a;
    return CMTimeCompare(a, b) >= 0 ? a : b;
}
CMTime CMTimeAbsoluteValue(CMTime t) {
    if (CMTIME_IS_NEGATIVE_INFINITY(t)) return kCMTimePositiveInfinity;
    if (CMTIME_IS_NUMERIC(t) && t.value < 0) t.value = -t.value;
    return t;
}
CMTimeRange CMTimeRangeMake(CMTime start, CMTime duration) {
    if (!CMTIME_IS_VALID(start) || !CMTIME_IS_VALID(duration) || duration.epoch != 0 || (CMTIME_IS_NUMERIC(duration) && duration.value < 0))
        return kCMTimeRangeInvalid;
    return (CMTimeRange){ start, duration };
}
CMTime CMTimeRangeGetEnd(CMTimeRange r) {
    if (!CMTIME_IS_VALID(r.start) || !CMTIME_IS_VALID(r.duration)) return kCMTimeInvalid;
    return CMTimeAdd(r.start, r.duration);
}
Boolean CMTimeRangeContainsTime(CMTimeRange r, CMTime t) {
    return CMTimeCompare(t, r.start) >= 0 && CMTimeCompare(t, CMTimeRangeGetEnd(r)) < 0;
}
Boolean CMTimeRangeEqual(CMTimeRange a, CMTimeRange b) { return CMTimeCompare(a.start, b.start) == 0 && CMTimeCompare(a.duration, b.duration) == 0; }
