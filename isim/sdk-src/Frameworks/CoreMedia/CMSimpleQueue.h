#pragma once
/* isim Core Media for C: a fixed-capacity FIFO of pointers. A CMSimpleQueueRef is the same object as Swift's CMSimpleQueue
   (CoreMedia/Queues.swift); release it with CFRelease. */
#include <CoreFoundation/CoreFoundation.h>
#include <MacTypes.h>
#if !defined(__swift__)
__BEGIN_DECLS
enum {
    kCMSimpleQueueError_AllocationFailed = -12770, kCMSimpleQueueError_RequiredParameterMissing = -12771,
    kCMSimpleQueueError_ParameterOutOfRange = -12772, kCMSimpleQueueError_QueueIsFull = -12773,
};
typedef struct opaqueCMSimpleQueue *CMSimpleQueueRef;
CFTypeID CMSimpleQueueGetTypeID(void);
OSStatus CMSimpleQueueCreate(CFAllocatorRef allocator, int32_t capacity, CMSimpleQueueRef *queueOut);
OSStatus CMSimpleQueueEnqueue(CMSimpleQueueRef queue, const void *element);
const void *CMSimpleQueueDequeue(CMSimpleQueueRef queue);
const void *CMSimpleQueueGetHead(CMSimpleQueueRef queue);
OSStatus CMSimpleQueueReset(CMSimpleQueueRef queue);
int32_t CMSimpleQueueGetCapacity(CMSimpleQueueRef queue);
int32_t CMSimpleQueueGetCount(CMSimpleQueueRef queue);
#define CMSimpleQueueGetFullness(queue) \
    ((CMSimpleQueueGetCapacity(queue) > 0) ? (((Float32)CMSimpleQueueGetCount(queue)) / CMSimpleQueueGetCapacity(queue)) : 0.0f)
__END_DECLS
#endif
