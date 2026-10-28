// isim Core Media for C: the buffer queue functions that take or return a CMTime, or take blocks. The queue itself is
// Swift's CMBufferQueue (swift/overlays/CoreMedia/Queues.swift), which also exports the other C functions; this file
// turns C callbacks and blocks into the plain function pointers it calls, and CMTime results into out-parameters.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <CoreMedia/CMBufferQueue.h>

typedef void (*isim_call_time)(const void *fn, CMBufferRef buf, void *refcon, CMTime *out);
extern OSStatus _isim_CMBufferQueueCreate(CMItemCount capacity, uint32_t version, void *refcon, isim_call_time callTime,
                                          const void *dts, const void *pts, const void *duration, CMBufferGetBooleanCallback ready,
                                          CMBufferCompareCallback compare, CFStringRef notification, CMBufferGetSizeCallback size,
                                          CMBufferQueueRef *queueOut);
extern void _isim_CMBufferQueueGetTime(CMBufferQueueRef queue, int32_t which, CMTime *out);
extern OSStatus _isim_CMBufferQueueInstallTrigger(CMBufferQueueRef queue, CMBufferQueueTriggerCallback callback, void *refcon,
                                                  CMBufferQueueTriggerCondition condition, const CMTime *time, CMItemCount threshold,
                                                  CMBufferQueueTriggerToken *tokenOut);

static void call_time(const void *fn, CMBufferRef buf, void *refcon, CMTime *out) { *out = ((CMBufferGetTimeCallback)fn)(buf, refcon); }

OSStatus CMBufferQueueCreate(CFAllocatorRef allocator, CMItemCount capacity, const CMBufferCallbacks *c, CMBufferQueueRef *queueOut) {
    if (!c || !queueOut) return kCMBufferQueueError_RequiredParameterMissing;
    return _isim_CMBufferQueueCreate(capacity, c->version, c->refcon, call_time, (const void *)c->getDecodeTimeStamp,
                                     (const void *)c->getPresentationTimeStamp, (const void *)c->getDuration, c->isDataReady, c->compare,
                                     c->dataBecameReadyNotification, c->version >= 1 ? c->getSize : NULL, queueOut);
}

/* blocks: the queue keeps them (an associated object), and the callbacks get them through refcon */
@interface _ISIMBufferHandlers : NSObject
@property (copy) CMBufferGetTimeHandler dts, pts, duration;
@property (copy) CMBufferGetBooleanHandler ready;
@property (copy) CMBufferCompareHandler compare;
@property (copy) CMBufferGetSizeHandler size;
@property (copy) CMBufferValidationHandler validate;
@property (strong) NSMutableArray *triggers;
@end
@implementation _ISIMBufferHandlers
@end
static const char kHandlersKey = 0;
static _ISIMBufferHandlers *handlers_of(CMBufferQueueRef q) {
    @synchronized ((__bridge id)q) {
        _ISIMBufferHandlers *h = objc_getAssociatedObject((__bridge id)q, &kHandlersKey);
        if (!h) {
            h = [_ISIMBufferHandlers new];
            h.triggers = [NSMutableArray array];
            objc_setAssociatedObject((__bridge id)q, &kHandlersKey, h, OBJC_ASSOCIATION_RETAIN);
        }
        return h;
    }
}
static void call_time_block(const void *fn, CMBufferRef buf, void *refcon, CMTime *out) { *out = ((__bridge CMBufferGetTimeHandler)fn)(buf); }
static Boolean ready_block(CMBufferRef b, void *refcon) { return ((__bridge _ISIMBufferHandlers *)refcon).ready(b); }
static CFComparisonResult compare_block(CMBufferRef a, CMBufferRef b, void *refcon) { return ((__bridge _ISIMBufferHandlers *)refcon).compare(a, b); }
static size_t size_block(CMBufferRef b, void *refcon) { return ((__bridge _ISIMBufferHandlers *)refcon).size(b); }

OSStatus CMBufferQueueCreateWithHandlers(CFAllocatorRef allocator, CMItemCount capacity, const CMBufferHandlers *c, CMBufferQueueRef *queueOut) {
    if (!c || !queueOut) return kCMBufferQueueError_RequiredParameterMissing;
    if (!c->getDuration) return kCMBufferQueueError_InvalidCMBufferCallbacksStruct;
    _ISIMBufferHandlers *h = [_ISIMBufferHandlers new];
    h.dts = c->getDecodeTimeStamp; h.pts = c->getPresentationTimeStamp; h.duration = c->getDuration;
    h.ready = c->isDataReady; h.compare = c->compare; h.size = c->getSize; h.triggers = [NSMutableArray array];
    OSStatus s = _isim_CMBufferQueueCreate(capacity, 1, (__bridge void *)h, call_time_block, (__bridge const void *)h.dts,
                                           (__bridge const void *)h.pts, (__bridge const void *)h.duration, h.ready ? ready_block : NULL,
                                           h.compare ? compare_block : NULL, c->dataBecameReadyNotification, h.size ? size_block : NULL, queueOut);
    if (s == noErr) objc_setAssociatedObject((__bridge id)*queueOut, &kHandlersKey, h, OBJC_ASSOCIATION_RETAIN);
    return s;
}

static CMTime get_time(CMBufferQueueRef q, int32_t which) { CMTime t = kCMTimeInvalid; _isim_CMBufferQueueGetTime(q, which, &t); return t; }
CMTime CMBufferQueueGetDuration(CMBufferQueueRef q) { return get_time(q, 0); }
CMTime CMBufferQueueGetMinDecodeTimeStamp(CMBufferQueueRef q) { return get_time(q, 1); }
CMTime CMBufferQueueGetFirstDecodeTimeStamp(CMBufferQueueRef q) { return get_time(q, 2); }
CMTime CMBufferQueueGetMinPresentationTimeStamp(CMBufferQueueRef q) { return get_time(q, 3); }
CMTime CMBufferQueueGetFirstPresentationTimeStamp(CMBufferQueueRef q) { return get_time(q, 4); }
CMTime CMBufferQueueGetMaxPresentationTimeStamp(CMBufferQueueRef q) { return get_time(q, 5); }
CMTime CMBufferQueueGetEndPresentationTimeStamp(CMBufferQueueRef q) { return get_time(q, 6); }

OSStatus CMBufferQueueInstallTrigger(CMBufferQueueRef q, CMBufferQueueTriggerCallback cb, void *refcon, CMBufferQueueTriggerCondition condition,
                                     CMTime time, CMBufferQueueTriggerToken *tokenOut) {
    return _isim_CMBufferQueueInstallTrigger(q, cb, refcon, condition, &time, 0, tokenOut);
}
OSStatus CMBufferQueueInstallTriggerWithIntegerThreshold(CMBufferQueueRef q, CMBufferQueueTriggerCallback cb, void *refcon,
                                                         CMBufferQueueTriggerCondition condition, CMItemCount threshold,
                                                         CMBufferQueueTriggerToken *tokenOut) {
    if (condition != kCMBufferQueueTrigger_WhenBufferCountBecomesLessThan && condition != kCMBufferQueueTrigger_WhenBufferCountBecomesGreaterThan)
        return kCMBufferQueueError_InvalidTriggerCondition;
    return _isim_CMBufferQueueInstallTrigger(q, cb, refcon, condition, NULL, threshold, tokenOut);
}
static void trigger_block(void *refcon, CMBufferQueueTriggerToken token) { ((__bridge CMBufferQueueTriggerHandler)refcon)(token); }
static OSStatus install_handler(CMBufferQueueRef q, CMBufferQueueTriggerCondition condition, const CMTime *time, CMItemCount threshold,
                                CMBufferQueueTriggerToken *tokenOut, CMBufferQueueTriggerHandler handler) {
    if (!q) return kCMBufferQueueError_RequiredParameterMissing;
    CMBufferQueueTriggerHandler h = [handler copy];
    if (h) [handlers_of(q).triggers addObject:h];               /* kept as long as the queue */
    return _isim_CMBufferQueueInstallTrigger(q, h ? trigger_block : NULL, (__bridge void *)h, condition, time, threshold, tokenOut);
}
OSStatus CMBufferQueueInstallTriggerHandler(CMBufferQueueRef q, CMBufferQueueTriggerCondition condition, CMTime time,
                                            CMBufferQueueTriggerToken *tokenOut, CMBufferQueueTriggerHandler handler) {
    return install_handler(q, condition, &time, 0, tokenOut, handler);
}
OSStatus CMBufferQueueInstallTriggerHandlerWithIntegerThreshold(CMBufferQueueRef q, CMBufferQueueTriggerCondition condition, CMItemCount threshold,
                                                                CMBufferQueueTriggerToken *tokenOut, CMBufferQueueTriggerHandler handler) {
    if (condition != kCMBufferQueueTrigger_WhenBufferCountBecomesLessThan && condition != kCMBufferQueueTrigger_WhenBufferCountBecomesGreaterThan)
        return kCMBufferQueueError_InvalidTriggerCondition;
    return install_handler(q, condition, NULL, threshold, tokenOut, handler);
}
static OSStatus validate_block(CMBufferQueueRef q, CMBufferRef b, void *refcon) { return ((__bridge _ISIMBufferHandlers *)refcon).validate(q, b); }
OSStatus CMBufferQueueSetValidationHandler(CMBufferQueueRef q, CMBufferValidationHandler handler) {
    if (!q || !handler) return kCMBufferQueueError_RequiredParameterMissing;
    _ISIMBufferHandlers *h = handlers_of(q);
    h.validate = handler;
    return CMBufferQueueSetValidationCallback(q, validate_block, (__bridge void *)h);
}
