// isim Core Media for C: time range and time mapping functions, and the dictionary and text forms of times, ranges and
// mappings (CMTimeRange.h), like Apple's. Swift has its own (CoreMedia.swift).
#include <CoreMedia/CMTimeRange.h>
#include <stdio.h>

const CMTimeMapping kCMTimeMappingInvalid = { { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }, { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } } };
const CFStringRef kCMTimeValueKey = CFSTR("value");
const CFStringRef kCMTimeScaleKey = CFSTR("timescale");
const CFStringRef kCMTimeEpochKey = CFSTR("epoch");
const CFStringRef kCMTimeFlagsKey = CFSTR("flags");
const CFStringRef kCMTimeRangeStartKey = CFSTR("start");
const CFStringRef kCMTimeRangeDurationKey = CFSTR("duration");
const CFStringRef kCMTimeMappingSourceKey = CFSTR("source");
const CFStringRef kCMTimeMappingTargetKey = CFSTR("target");

CMTimeRange CMTimeRangeFromTimeToTime(CMTime start, CMTime end) { return CMTimeRangeMake(start, CMTimeSubtract(end, start)); }
CMTimeRange CMTimeRangeGetUnion(CMTimeRange a, CMTimeRange b) {
    if (!CMTIMERANGE_IS_VALID(a) || !CMTIMERANGE_IS_VALID(b)) return kCMTimeRangeInvalid;
    return CMTimeRangeFromTimeToTime(CMTimeMinimum(a.start, b.start), CMTimeMaximum(CMTimeRangeGetEnd(a), CMTimeRangeGetEnd(b)));
}
/* ranges that do not overlap: an empty range at the later start */
CMTimeRange CMTimeRangeGetIntersection(CMTimeRange a, CMTimeRange b) {
    if (!CMTIMERANGE_IS_VALID(a) || !CMTIMERANGE_IS_VALID(b)) return kCMTimeRangeInvalid;
    CMTime s = CMTimeMaximum(a.start, b.start), e = CMTimeMinimum(CMTimeRangeGetEnd(a), CMTimeRangeGetEnd(b));
    if (CMTimeCompare(e, s) <= 0) return CMTimeRangeMake(s, kCMTimeZero);
    return CMTimeRangeFromTimeToTime(s, e);
}
Boolean CMTimeRangeContainsTimeRange(CMTimeRange a, CMTimeRange b) {
    if (!CMTIMERANGE_IS_VALID(a) || !CMTIMERANGE_IS_VALID(b)) return 0;
    return CMTimeCompare(b.start, a.start) >= 0 && CMTimeCompare(CMTimeRangeGetEnd(b), CMTimeRangeGetEnd(a)) <= 0;
}
CMTime CMTimeClampToRange(CMTime t, CMTimeRange r) {
    if (!CMTIMERANGE_IS_VALID(r) || !CMTIME_IS_VALID(t)) return kCMTimeInvalid;
    if (CMTimeCompare(t, r.start) < 0) return r.start;
    CMTime end = CMTimeRangeGetEnd(r);
    return CMTimeCompare(t, end) > 0 ? end : t;
}
/* dur * to.duration / from.duration, in 128-bit arithmetic at the larger of the two timescales */
CMTime CMTimeMapDurationFromRangeToRange(CMTime dur, CMTimeRange from, CMTimeRange to) {
    if (!CMTIME_IS_NUMERIC(dur) || !CMTIME_IS_NUMERIC(from.duration) || !CMTIME_IS_NUMERIC(to.duration) || from.duration.value == 0)
        return kCMTimeInvalid;
    if (CMTimeCompare(from.duration, to.duration) == 0) return dur;
    int32_t ts = dur.timescale > to.duration.timescale ? dur.timescale : to.duration.timescale;
    __int128 n = (__int128)dur.value * to.duration.value * from.duration.timescale * ts;
    __int128 d = (__int128)dur.timescale * to.duration.timescale * from.duration.value;
    __int128 q = n / d, r = n % d;
    if (r != 0 && 2 * (r < 0 ? -r : r) >= (d < 0 ? -d : d)) q += ((n < 0) != (d < 0)) ? -1 : 1;
    CMTime out = CMTimeMake((int64_t)q, ts);
    if (r != 0) out.flags |= kCMTimeFlags_HasBeenRounded;
    return out;
}
CMTime CMTimeMapTimeFromRangeToRange(CMTime t, CMTimeRange from, CMTimeRange to) {
    if (!CMTIME_IS_NUMERIC(t) || !CMTIMERANGE_IS_VALID(from) || !CMTIMERANGE_IS_VALID(to)) return kCMTimeInvalid;
    return CMTimeAdd(to.start, CMTimeMapDurationFromRangeToRange(CMTimeSubtract(t, from.start), from, to));
}
/* a time outside the range moves by whole range durations until it is inside */
CMTime CMTimeFoldIntoRange(CMTime t, CMTimeRange r) {
    if (!CMTIME_IS_NUMERIC(t)) return t;
    if (!CMTIMERANGE_IS_VALID(r) || !CMTIME_IS_NUMERIC(r.duration) || r.duration.value <= 0) return kCMTimeInvalid;
    if (CMTimeRangeContainsTime(r, t)) return t;
    CMTime off = CMTimeSubtract(t, r.start);
    int32_t ts = off.timescale;
    CMTime d = CMTimeConvertScale(r.duration, ts, kCMTimeRoundingMethod_Default);
    int64_t m = ((off.value % d.value) + d.value) % d.value;
    return CMTimeAdd(r.start, CMTimeMake(m, ts));
}

static CFNumberRef num64(int64_t v) { return CFNumberCreate(NULL, kCFNumberSInt64Type, &v); }
static CFNumberRef num32(int32_t v) { return CFNumberCreate(NULL, kCFNumberSInt32Type, &v); }
static CFDictionaryRef dict2(CFStringRef k1, CFTypeRef v1, CFStringRef k2, CFTypeRef v2) {
    const void *keys[] = { k1, k2 }, *values[] = { v1, v2 };
    CFDictionaryRef d = CFDictionaryCreate(NULL, keys, values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(v1); CFRelease(v2);
    return d;
}
CFDictionaryRef CMTimeCopyAsDictionary(CMTime t, CFAllocatorRef allocator) {
    const void *keys[] = { kCMTimeValueKey, kCMTimeScaleKey, kCMTimeFlagsKey, kCMTimeEpochKey };
    const void *values[] = { num64(t.value), num32(t.timescale), num32((int32_t)t.flags), num64(t.epoch) };
    CFDictionaryRef d = CFDictionaryCreate(allocator, keys, values, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    for (int i = 0; i < 4; i++) CFRelease(values[i]);
    return d;
}
static int get64(CFDictionaryRef d, CFStringRef k, int64_t *out) {
    CFNumberRef n = d ? (CFNumberRef)CFDictionaryGetValue(d, k) : NULL;
    return n && CFNumberGetValue(n, kCFNumberSInt64Type, out);
}
CMTime CMTimeMakeFromDictionary(CFDictionaryRef d) {
    int64_t v, s, f, e = 0;
    if (!get64(d, kCMTimeValueKey, &v) || !get64(d, kCMTimeScaleKey, &s) || !get64(d, kCMTimeFlagsKey, &f)) return kCMTimeInvalid;
    get64(d, kCMTimeEpochKey, &e);
    return (CMTime){ v, (int32_t)s, (CMTimeFlags)f, e };
}
CFDictionaryRef CMTimeRangeCopyAsDictionary(CMTimeRange r, CFAllocatorRef allocator) {
    return dict2(kCMTimeRangeStartKey, CMTimeCopyAsDictionary(r.start, allocator), kCMTimeRangeDurationKey, CMTimeCopyAsDictionary(r.duration, allocator));
}
CMTimeRange CMTimeRangeMakeFromDictionary(CFDictionaryRef d) {
    if (!d) return kCMTimeRangeInvalid;
    return (CMTimeRange){ CMTimeMakeFromDictionary(CFDictionaryGetValue(d, kCMTimeRangeStartKey)),
                          CMTimeMakeFromDictionary(CFDictionaryGetValue(d, kCMTimeRangeDurationKey)) };
}
CFDictionaryRef CMTimeMappingCopyAsDictionary(CMTimeMapping m, CFAllocatorRef allocator) {
    return dict2(kCMTimeMappingSourceKey, CMTimeRangeCopyAsDictionary(m.source, allocator), kCMTimeMappingTargetKey, CMTimeRangeCopyAsDictionary(m.target, allocator));
}
CMTimeMapping CMTimeMappingMakeFromDictionary(CFDictionaryRef d) {
    if (!d) return kCMTimeMappingInvalid;
    return (CMTimeMapping){ CMTimeRangeMakeFromDictionary(CFDictionaryGetValue(d, kCMTimeMappingSourceKey)),
                            CMTimeRangeMakeFromDictionary(CFDictionaryGetValue(d, kCMTimeMappingTargetKey)) };
}
CMTimeMapping CMTimeMappingMake(CMTimeRange source, CMTimeRange target) {
    if (!CMTIMERANGE_IS_VALID(source) || !CMTIMERANGE_IS_VALID(target)) return kCMTimeMappingInvalid;
    return (CMTimeMapping){ source, target };
}
CMTimeMapping CMTimeMappingMakeEmpty(CMTimeRange target) {
    if (!CMTIMERANGE_IS_VALID(target)) return kCMTimeMappingInvalid;
    return (CMTimeMapping){ { kCMTimeInvalid, target.duration }, target };
}

/* the text forms Swift's CMTimeRangeCopyDescription uses: {1/30 = 0.033}, INVALID, INDEFINITE, +INFINITY, -INFINITY */
static void time_text(CMTime t, char *buf, size_t n) {
    if (!CMTIME_IS_VALID(t)) snprintf(buf, n, "INVALID");
    else if (CMTIME_IS_INDEFINITE(t)) snprintf(buf, n, "INDEFINITE");
    else if (CMTIME_IS_POSITIVE_INFINITY(t)) snprintf(buf, n, "+INFINITY");
    else if (CMTIME_IS_NEGATIVE_INFINITY(t)) snprintf(buf, n, "-INFINITY");
    else snprintf(buf, n, "{%lld/%d = %.3f%s}", (long long)t.value, t.timescale, CMTimeGetSeconds(t),
                  (t.flags & kCMTimeFlags_HasBeenRounded) ? ", rounded" : "");
}
static void range_text(CMTimeRange r, char *buf, size_t n) {
    char a[96], b[96];
    time_text(r.start, a, sizeof a); time_text(r.duration, b, sizeof b);
    snprintf(buf, n, "{%s, %s}", a, b);
}
static void mapping_text(CMTimeMapping m, char *buf, size_t n) {
    char a[200], b[200];
    range_text(m.source, a, sizeof a); range_text(m.target, b, sizeof b);
    snprintf(buf, n, "{source = %s, target = %s}", a, b);
}
CFStringRef CMTimeCopyDescription(CFAllocatorRef allocator, CMTime t) {
    char buf[96]; time_text(t, buf, sizeof buf);
    return CFStringCreateWithCString(allocator, buf, kCFStringEncodingUTF8);
}
CFStringRef CMTimeRangeCopyDescription(CFAllocatorRef allocator, CMTimeRange r) {
    char buf[200]; range_text(r, buf, sizeof buf);
    return CFStringCreateWithCString(allocator, buf, kCFStringEncodingUTF8);
}
CFStringRef CMTimeMappingCopyDescription(CFAllocatorRef allocator, CMTimeMapping m) {
    char buf[420]; mapping_text(m, buf, sizeof buf);
    return CFStringCreateWithCString(allocator, buf, kCFStringEncodingUTF8);
}
void CMTimeShow(CMTime t) { char buf[96]; time_text(t, buf, sizeof buf); printf("%s\n", buf); fflush(stdout); }
void CMTimeRangeShow(CMTimeRange r) { char buf[200]; range_text(r, buf, sizeof buf); printf("%s\n", buf); fflush(stdout); }
void CMTimeMappingShow(CMTimeMapping m) { char buf[420]; mapping_text(m, buf, sizeof buf); printf("%s\n", buf); fflush(stdout); }
