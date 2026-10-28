#pragma once
/* isim Core Media for C: buffer queues. A CMBufferQueueRef is the same object as Swift's CMBufferQueue
   (CoreMedia/Queues.swift); release it with CFRelease. Buffers are any CF objects the callbacks understand; the queue
   retains them while they are queued. Not available from C yet: the sample-buffer callbacks
   (CMBufferQueueGetCallbacksForUnsortedSampleBuffers ...), since isim's sample buffers have no C interface. */
#include <CoreMedia/CMTime.h>
#include <MacTypes.h>
#if !defined(__swift__)
__BEGIN_DECLS
enum {
    kCMBufferQueueError_AllocationFailed = -12760, kCMBufferQueueError_RequiredParameterMissing = -12761,
    kCMBufferQueueError_InvalidCMBufferCallbacksStruct = -12762, kCMBufferQueueError_EnqueueAfterEndOfData = -12763,
    kCMBufferQueueError_QueueIsFull = -12764, kCMBufferQueueError_BadTriggerDuration = -12765,
    kCMBufferQueueError_CannotModifyQueueFromTriggerCallback = -12766, kCMBufferQueueError_InvalidTriggerCondition = -12767,
    kCMBufferQueueError_InvalidTriggerToken = -12768, kCMBufferQueueError_InvalidBuffer = -12769,
};
typedef CFIndex CMItemCount;
typedef struct opaqueCMBufferQueue *CMBufferQueueRef;
typedef CFTypeRef CMBufferRef;
typedef CMTime (*CMBufferGetTimeCallback)(CMBufferRef buf, void *refcon);
typedef CMTime (^CMBufferGetTimeHandler)(CMBufferRef buf);
typedef Boolean (*CMBufferGetBooleanCallback)(CMBufferRef buf, void *refcon);
typedef Boolean (^CMBufferGetBooleanHandler)(CMBufferRef buf);
typedef CFComparisonResult (*CMBufferCompareCallback)(CMBufferRef buf1, CMBufferRef buf2, void *refcon);
typedef CFComparisonResult (^CMBufferCompareHandler)(CMBufferRef buf1, CMBufferRef buf2);
typedef size_t (*CMBufferGetSizeCallback)(CMBufferRef buf, void *refcon);
typedef size_t (^CMBufferGetSizeHandler)(CMBufferRef buf);

#pragma pack(push, 4)
typedef struct {
    uint32_t version;                                   /* 0, or 1 with getSize */
    void *refcon;
    CMBufferGetTimeCallback getDecodeTimeStamp;         /* NULL: decode time stamps are the presentation ones */
    CMBufferGetTimeCallback getPresentationTimeStamp;
    CMBufferGetTimeCallback getDuration;                /* required */
    CMBufferGetBooleanCallback isDataReady;             /* NULL: always ready */
    CMBufferCompareCallback compare;                    /* NULL: enqueue order */
    CFStringRef dataBecameReadyNotification;            /* posted by a buffer whose data becomes ready */
    CMBufferGetSizeCallback getSize;
} CMBufferCallbacks;
typedef struct {
    size_t version;                                     /* 0 */
    CMBufferGetTimeHandler getDecodeTimeStamp;
    CMBufferGetTimeHandler getPresentationTimeStamp;
    CMBufferGetTimeHandler getDuration;
    CMBufferGetBooleanHandler isDataReady;
    CMBufferCompareHandler compare;
    CFStringRef dataBecameReadyNotification;
    CMBufferGetSizeHandler getSize;
} CMBufferHandlers;
#pragma pack(pop)

CFTypeID CMBufferQueueGetTypeID(void);
OSStatus CMBufferQueueCreate(CFAllocatorRef allocator, CMItemCount capacity, const CMBufferCallbacks *callbacks, CMBufferQueueRef *queueOut);
OSStatus CMBufferQueueCreateWithHandlers(CFAllocatorRef allocator, CMItemCount capacity, const CMBufferHandlers *handlers, CMBufferQueueRef *queueOut);
OSStatus CMBufferQueueEnqueue(CMBufferQueueRef queue, CMBufferRef buf);
CMBufferRef CMBufferQueueDequeueAndRetain(CMBufferQueueRef queue) CF_RETURNS_RETAINED;
CMBufferRef CMBufferQueueDequeueIfDataReadyAndRetain(CMBufferQueueRef queue) CF_RETURNS_RETAINED;
CMBufferRef CMBufferQueueGetHead(CMBufferQueueRef queue);
CMBufferRef CMBufferQueueCopyHead(CMBufferQueueRef queue) CF_RETURNS_RETAINED;
Boolean CMBufferQueueIsEmpty(CMBufferQueueRef queue);
OSStatus CMBufferQueueMarkEndOfData(CMBufferQueueRef queue);
Boolean CMBufferQueueContainsEndOfData(CMBufferQueueRef queue);
Boolean CMBufferQueueIsAtEndOfData(CMBufferQueueRef queue);
OSStatus CMBufferQueueReset(CMBufferQueueRef queue);
OSStatus CMBufferQueueResetWithCallback(CMBufferQueueRef queue, void (*callback)(CMBufferRef buffer, void *refcon), void *refcon);
CMItemCount CMBufferQueueGetBufferCount(CMBufferQueueRef queue);
CMTime CMBufferQueueGetDuration(CMBufferQueueRef queue);
CMTime CMBufferQueueGetMinDecodeTimeStamp(CMBufferQueueRef queue);
CMTime CMBufferQueueGetFirstDecodeTimeStamp(CMBufferQueueRef queue);
CMTime CMBufferQueueGetMinPresentationTimeStamp(CMBufferQueueRef queue);
CMTime CMBufferQueueGetFirstPresentationTimeStamp(CMBufferQueueRef queue);
CMTime CMBufferQueueGetMaxPresentationTimeStamp(CMBufferQueueRef queue);
CMTime CMBufferQueueGetEndPresentationTimeStamp(CMBufferQueueRef queue);
size_t CMBufferQueueGetTotalSize(CMBufferQueueRef queue);

typedef struct opaqueCMBufferQueueTriggerToken *CMBufferQueueTriggerToken;
typedef void (*CMBufferQueueTriggerCallback)(void *triggerRefcon, CMBufferQueueTriggerToken triggerToken);
typedef void (^CMBufferQueueTriggerHandler)(CMBufferQueueTriggerToken triggerToken);
typedef int32_t CMBufferQueueTriggerCondition;
enum {
    kCMBufferQueueTrigger_WhenDurationBecomesLessThan = 1, kCMBufferQueueTrigger_WhenDurationBecomesLessThanOrEqualTo = 2,
    kCMBufferQueueTrigger_WhenDurationBecomesGreaterThan = 3, kCMBufferQueueTrigger_WhenDurationBecomesGreaterThanOrEqualTo = 4,
    kCMBufferQueueTrigger_WhenMinPresentationTimeStampChanges = 5, kCMBufferQueueTrigger_WhenMaxPresentationTimeStampChanges = 6,
    kCMBufferQueueTrigger_WhenDataBecomesReady = 7, kCMBufferQueueTrigger_WhenEndOfDataReached = 8, kCMBufferQueueTrigger_WhenReset = 9,
    kCMBufferQueueTrigger_WhenBufferCountBecomesLessThan = 10, kCMBufferQueueTrigger_WhenBufferCountBecomesGreaterThan = 11,
    kCMBufferQueueTrigger_WhenDurationBecomesGreaterThanOrEqualToAndBufferCountBecomesGreaterThan = 12,
};
OSStatus CMBufferQueueInstallTrigger(CMBufferQueueRef queue, CMBufferQueueTriggerCallback callback, void *refcon,
                                     CMBufferQueueTriggerCondition condition, CMTime time, CMBufferQueueTriggerToken *triggerTokenOut);
OSStatus CMBufferQueueInstallTriggerWithIntegerThreshold(CMBufferQueueRef queue, CMBufferQueueTriggerCallback callback, void *refcon,
                                                         CMBufferQueueTriggerCondition condition, CMItemCount threshold,
                                                         CMBufferQueueTriggerToken *triggerTokenOut);
OSStatus CMBufferQueueInstallTriggerHandler(CMBufferQueueRef queue, CMBufferQueueTriggerCondition condition, CMTime time,
                                            CMBufferQueueTriggerToken *triggerTokenOut, CMBufferQueueTriggerHandler handler);
OSStatus CMBufferQueueInstallTriggerHandlerWithIntegerThreshold(CMBufferQueueRef queue, CMBufferQueueTriggerCondition condition,
                                                                CMItemCount threshold, CMBufferQueueTriggerToken *triggerTokenOut,
                                                                CMBufferQueueTriggerHandler handler);
OSStatus CMBufferQueueRemoveTrigger(CMBufferQueueRef queue, CMBufferQueueTriggerToken triggerToken);
Boolean CMBufferQueueTestTrigger(CMBufferQueueRef queue, CMBufferQueueTriggerToken triggerToken);
OSStatus CMBufferQueueCallForEachBuffer(CMBufferQueueRef queue, OSStatus (*callback)(CMBufferRef buffer, void *refcon), void *refcon);
typedef OSStatus (*CMBufferValidationCallback)(CMBufferQueueRef queue, CMBufferRef buf, void *validationRefCon);
typedef OSStatus (^CMBufferValidationHandler)(CMBufferQueueRef queue, CMBufferRef buf);
OSStatus CMBufferQueueSetValidationCallback(CMBufferQueueRef queue, CMBufferValidationCallback callback, void *refcon);
OSStatus CMBufferQueueSetValidationHandler(CMBufferQueueRef queue, CMBufferValidationHandler handler);
__END_DECLS
#endif
