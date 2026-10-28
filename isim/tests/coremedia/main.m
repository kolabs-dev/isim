// Core Media from C (CoreMediaCTest.app, issue #383): time range and time mapping functions and their dictionaries,
// CMSimpleQueue, and CMBufferQueue with C callbacks and blocks (ordering, timestamps, end of data, triggers, validation).
#import <Foundation/Foundation.h>
#include <CoreMedia/CoreMedia.h>
#include <stdio.h>

static int checks, failures;
#define CHECK(cond, what) do { checks++; if (cond) printf("PASS  %s\n", what); else { failures++; printf("FAIL  %s  (line %d)\n", what, __LINE__); } } while (0)

static CMTime T(int64_t v) { return CMTimeMake(v, 1); }
static CMTimeRange R(int64_t s, int64_t d) { return CMTimeRangeMake(T(s), T(d)); }
static int teq(CMTime a, CMTime b) { return CMTimeCompare(a, b) == 0; }

static void time_ranges(void) {
    CHECK(CMTimeRangeContainsTimeRange(R(0, 10), R(2, 3)) && !CMTimeRangeContainsTimeRange(R(0, 10), R(8, 3)), "CMTimeRangeContainsTimeRange");
    CHECK(CMTIMERANGE_IS_INVALID(kCMTimeRangeInvalid) && CMTIMERANGE_IS_INDEFINITE(CMTimeRangeMake(kCMTimeIndefinite, T(1))), "CMTIMERANGE_IS_INVALID / INDEFINITE");
    CHECK(CMTimeRangeEqual(CMTimeRangeFromTimeToTime(T(2), T(7)), R(2, 5)), "CMTimeRangeFromTimeToTime");
    CHECK(CMTimeRangeEqual(CMTimeRangeGetIntersection(R(0, 10), R(5, 10)), R(5, 5)) && CMTimeRangeEqual(CMTimeRangeGetUnion(R(0, 10), R(5, 10)), R(0, 15)),
          "CMTimeRangeGetIntersection / GetUnion");
    CHECK(CMTIMERANGE_IS_EMPTY(CMTimeRangeGetIntersection(R(0, 2), R(5, 2))), "disjoint ranges intersect in an empty range");
    CHECK(teq(CMTimeClampToRange(T(30), R(0, 10)), T(10)) && teq(CMTimeClampToRange(T(-3), R(0, 10)), T(0)), "CMTimeClampToRange");
    CHECK(teq(CMTimeMapTimeFromRangeToRange(T(15), R(10, 10), R(100, 20)), T(110)), "CMTimeMapTimeFromRangeToRange");
    CMTime third = CMTimeMapDurationFromRangeToRange(T(1), R(0, 3), R(0, 1));
    CHECK(third.timescale == 1 && CMTIME_HAS_BEEN_ROUNDED(third), "CMTimeMapDurationFromRangeToRange rounds 1/3 at timescale 1");
    CHECK(teq(CMTimeFoldIntoRange(T(23), R(10, 5)), T(13)) && teq(CMTimeFoldIntoRange(T(7), R(10, 5)), T(12)), "CMTimeFoldIntoRange");

    CMTimeRange range = CMTimeRangeMake(CMTimeMake(1, 30), CMTimeMake(90, 30));
    CFDictionaryRef d = CMTimeRangeCopyAsDictionary(range, NULL);
    CHECK(d && CMTimeRangeEqual(CMTimeRangeMakeFromDictionary(d), range), "CMTimeRangeCopyAsDictionary / MakeFromDictionary");
    CFDictionaryRef start = CFDictionaryGetValue(d, kCMTimeRangeStartKey);
    int32_t scale = 0;
    CHECK(start && CFNumberGetValue(CFDictionaryGetValue(start, kCMTimeScaleKey), kCFNumberSInt32Type, &scale) && scale == 30, "the start's timescale in the dictionary");
    CFRelease(d);
    CFStringRef desc = CMTimeRangeCopyDescription(NULL, R(1, 2));
    CHECK(desc && [(__bridge NSString *)desc isEqualToString:@"{{1/1 = 1.000}, {2/1 = 2.000}}"], "CMTimeRangeCopyDescription");
    if (desc) CFRelease(desc);

    CMTimeMapping m = CMTimeMappingMake(R(0, 10), R(5, 10));
    CHECK(CMTIMEMAPPING_IS_VALID(m) && !CMTIMEMAPPING_IS_EMPTY(m), "CMTimeMappingMake");
    CHECK(CMTIMEMAPPING_IS_INVALID(CMTimeMappingMake(kCMTimeRangeInvalid, R(0, 1))), "an invalid source: kCMTimeMappingInvalid");
    CMTimeMapping e = CMTimeMappingMakeEmpty(R(3, 4));
    CHECK(CMTIMEMAPPING_IS_EMPTY(e) && teq(e.source.duration, T(4)), "CMTimeMappingMakeEmpty");
    CFDictionaryRef md = CMTimeMappingCopyAsDictionary(m, NULL);
    CMTimeMapping back = CMTimeMappingMakeFromDictionary(md);
    CHECK(CMTimeRangeEqual(back.source, m.source) && CMTimeRangeEqual(back.target, m.target), "CMTimeMapping dictionary round trip");
    CFRelease(md);
    CFStringRef mdesc = CMTimeMappingCopyDescription(NULL, m);
    CHECK(mdesc && [(__bridge NSString *)mdesc hasPrefix:@"{source = {{0/1"], "CMTimeMappingCopyDescription");
    if (mdesc) CFRelease(mdesc);
    CMTimeMappingShow(m);
}

static void simple_queues(void) {
    CMSimpleQueueRef q = NULL;
    CHECK(CMSimpleQueueCreate(NULL, 0, &q) == kCMSimpleQueueError_ParameterOutOfRange, "CMSimpleQueueCreate: capacity 0");
    CHECK(CMSimpleQueueCreate(NULL, 2, &q) == noErr && q, "CMSimpleQueueCreate");
    int a = 1, b = 2, c = 3;
    CHECK(CMSimpleQueueEnqueue(q, &a) == noErr && CMSimpleQueueEnqueue(q, &b) == noErr && CMSimpleQueueEnqueue(q, &c) == kCMSimpleQueueError_QueueIsFull,
          "CMSimpleQueueEnqueue up to the capacity");
    CHECK(CMSimpleQueueGetCount(q) == 2 && CMSimpleQueueGetCapacity(q) == 2 && CMSimpleQueueGetFullness(q) == 1.0f, "count, capacity, fullness");
    CHECK(CMSimpleQueueGetHead(q) == &a && CMSimpleQueueDequeue(q) == &a && CMSimpleQueueDequeue(q) == &b && CMSimpleQueueDequeue(q) == NULL, "FIFO order");
    CHECK(CMSimpleQueueEnqueue(q, NULL) == kCMSimpleQueueError_RequiredParameterMissing, "a NULL element");
    CMSimpleQueueEnqueue(q, &c);
    CHECK(CMSimpleQueueReset(q) == noErr && CMSimpleQueueGetCount(q) == 0, "CMSimpleQueueReset");
    CHECK(CFGetTypeID(q) == CMSimpleQueueGetTypeID(), "CFGetTypeID of a simple queue");
    CFRelease(q);
}

/* buffers: NSNumbers holding a presentation time in seconds */
static CMTime pts_of(CMBufferRef b, void *refcon) { return T([(__bridge NSNumber *)b longLongValue]); }
static CMTime one_second(CMBufferRef b, void *refcon) { return T(1); }
static CFComparisonResult by_pts(CMBufferRef a, CMBufferRef b, void *refcon) {
    long long x = [(__bridge NSNumber *)a longLongValue], y = [(__bridge NSNumber *)b longLongValue];
    return x < y ? kCFCompareLessThan : x > y ? kCFCompareGreaterThan : kCFCompareEqualTo;
}
static size_t four_bytes(CMBufferRef b, void *refcon) { return 4; }
static void count_fire(void *refcon, CMBufferQueueTriggerToken token) { (*(int *)refcon)++; }
static OSStatus sum_pts(CMBufferRef b, void *refcon) { *(long long *)refcon += [(__bridge NSNumber *)b longLongValue]; return noErr; }
static OSStatus no_negatives(CMBufferQueueRef q, CMBufferRef b, void *refcon) { return [(__bridge NSNumber *)b longLongValue] < 0 ? -1 : noErr; }

static void buffer_queues(void) {
    CMBufferCallbacks cb = { 1, NULL, NULL, pts_of, one_second, NULL, by_pts, NULL, four_bytes };
    CMBufferQueueRef q = NULL;
    CHECK(CMBufferQueueCreate(NULL, 0, &cb, &q) == noErr && q, "CMBufferQueueCreate");
    int fired = 0;
    CMBufferQueueTriggerToken token = NULL;
    CHECK(CMBufferQueueInstallTrigger(q, count_fire, &fired, kCMBufferQueueTrigger_WhenDurationBecomesGreaterThan, T(2), &token) == noErr && token,
          "CMBufferQueueInstallTrigger");
    __block int blockFired = 0;
    CMBufferQueueTriggerToken countToken = NULL;
    CHECK(CMBufferQueueInstallTriggerHandlerWithIntegerThreshold(q, kCMBufferQueueTrigger_WhenBufferCountBecomesGreaterThan, 1, &countToken,
                                                                 ^(CMBufferQueueTriggerToken t) { blockFired++; }) == noErr, "CMBufferQueueInstallTriggerHandlerWithIntegerThreshold");
    CHECK(CMBufferQueueInstallTriggerWithIntegerThreshold(q, count_fire, &fired, kCMBufferQueueTrigger_WhenDurationBecomesLessThan, 1, NULL) ==
          kCMBufferQueueError_InvalidTriggerCondition, "an integer threshold needs a buffer-count condition");
    CMBufferQueueSetValidationCallback(q, no_negatives, NULL);
    long long values[] = { 7, 3, 5 };
    for (int i = 0; i < 3; i++) CMBufferQueueEnqueue(q, (__bridge CMBufferRef)@(values[i]));
    CHECK(CMBufferQueueEnqueue(q, (__bridge CMBufferRef)@(-1)) == kCMBufferQueueError_InvalidBuffer, "the validation callback rejects a buffer");
    CHECK(CMBufferQueueGetBufferCount(q) == 3 && CMBufferQueueGetTotalSize(q) == 12, "CMBufferQueueGetBufferCount / GetTotalSize");
    CHECK(teq(CMBufferQueueGetDuration(q), T(3)), "CMBufferQueueGetDuration");
    CHECK(teq(CMBufferQueueGetMinPresentationTimeStamp(q), T(3)) && teq(CMBufferQueueGetMaxPresentationTimeStamp(q), T(7)) &&
          teq(CMBufferQueueGetEndPresentationTimeStamp(q), T(8)) && teq(CMBufferQueueGetFirstDecodeTimeStamp(q), T(3)), "the timestamps (DTS: the PTS)");
    CHECK(fired == 1 && blockFired == 1, "the duration and count triggers fired once each");
    CHECK(CMBufferQueueTestTrigger(q, token), "CMBufferQueueTestTrigger");
    long long sum = 0;
    CMBufferQueueCallForEachBuffer(q, sum_pts, &sum);
    CHECK(sum == 15, "CMBufferQueueCallForEachBuffer");
    CHECK([(__bridge NSNumber *)CMBufferQueueGetHead(q) longLongValue] == 3, "ordered by the compare callback");
    CMBufferRef head = CMBufferQueueDequeueAndRetain(q);
    CHECK(head && [(__bridge NSNumber *)head longLongValue] == 3 && CMBufferQueueGetBufferCount(q) == 2, "CMBufferQueueDequeueAndRetain");
    if (head) CFRelease(head);
    CHECK(CMBufferQueueMarkEndOfData(q) == noErr && CMBufferQueueContainsEndOfData(q) &&
          CMBufferQueueEnqueue(q, (__bridge CMBufferRef)@1) == kCMBufferQueueError_EnqueueAfterEndOfData, "end of data");
    CHECK(CMBufferQueueRemoveTrigger(q, token) == noErr && CMBufferQueueRemoveTrigger(q, token) == kCMBufferQueueError_InvalidTriggerToken, "CMBufferQueueRemoveTrigger");
    CHECK(CMBufferQueueReset(q) == noErr && CMBufferQueueIsEmpty(q) && !CMBufferQueueContainsEndOfData(q), "CMBufferQueueReset");
    CHECK(CFGetTypeID(q) == CMBufferQueueGetTypeID(), "CFGetTypeID of a buffer queue");
    CFRelease(q);

    /* blocks */
    CMBufferHandlers h = { 0, NULL, ^CMTime(CMBufferRef b) { return T([(__bridge NSNumber *)b longLongValue]); }, ^CMTime(CMBufferRef b) { return CMTimeMake(1, 2); },
                           ^Boolean(CMBufferRef b) { return [(__bridge NSNumber *)b longLongValue] != 0; }, NULL, NULL, NULL };
    CMBufferQueueRef hq = NULL;
    CHECK(CMBufferQueueCreateWithHandlers(NULL, 2, &h, &hq) == noErr && hq, "CMBufferQueueCreateWithHandlers");
    CMBufferQueueEnqueue(hq, (__bridge CMBufferRef)@0);
    CMBufferQueueEnqueue(hq, (__bridge CMBufferRef)@4);
    CHECK(CMBufferQueueEnqueue(hq, (__bridge CMBufferRef)@5) == kCMBufferQueueError_QueueIsFull, "a queue with capacity 2 is full");
    CHECK(teq(CMBufferQueueGetDuration(hq), T(1)) && teq(CMBufferQueueGetFirstPresentationTimeStamp(hq), T(0)), "the handlers' times");
    CHECK(CMBufferQueueDequeueIfDataReadyAndRetain(hq) == NULL, "the head (0) is not ready");
    __block int resets = 0;
    CMBufferQueueInstallTriggerHandler(hq, kCMBufferQueueTrigger_WhenReset, kCMTimeInvalid, NULL, ^(CMBufferQueueTriggerToken t) { resets++; });
    CMBufferQueueSetValidationHandler(hq, ^OSStatus(CMBufferQueueRef queue, CMBufferRef b) { return noErr; });
    CHECK(CMBufferQueueReset(hq) == noErr && resets == 1, "CMBufferQueueInstallTriggerHandler: whenReset");
    CFRelease(hq);
}

int main(void) {
    @autoreleasepool {
        time_ranges();
        simple_queues();
        buffer_queues();
    }
    printf("coremedia c: %d/%d passed\n", checks - failures, checks);
    return failures != 0;
}
