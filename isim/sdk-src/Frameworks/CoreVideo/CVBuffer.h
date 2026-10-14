#pragma once
#include <CoreVideo/CVReturn.h>
#if !defined(__swift__)
__BEGIN_DECLS
typedef struct CV_BRIDGED_TYPE(id) __CVBuffer *CVBufferRef;
typedef CF_ENUM(uint32_t, CVAttachmentMode) {
    kCVAttachmentMode_ShouldNotPropagate = 0,
    kCVAttachmentMode_ShouldPropagate = 1,
};
CV_EXPORT const CFStringRef kCVBufferPropagatedAttachmentsKey;
CV_EXPORT const CFStringRef kCVBufferNonPropagatedAttachmentsKey;
CV_EXPORT const CFStringRef kCVBufferMovieTimeKey;
CV_EXPORT CVBufferRef CVBufferRetain(CVBufferRef buffer);
CV_EXPORT void CVBufferRelease(CVBufferRef buffer);
CV_EXPORT void CVBufferSetAttachment(CVBufferRef buffer, CFStringRef key, CFTypeRef value, CVAttachmentMode attachmentMode);
CV_EXPORT CFTypeRef CVBufferGetAttachment(CVBufferRef buffer, CFStringRef key, CVAttachmentMode *attachmentMode);
CV_EXPORT CFTypeRef CVBufferCopyAttachment(CVBufferRef buffer, CFStringRef key, CVAttachmentMode *attachmentMode) CF_RETURNS_RETAINED;
CV_EXPORT Boolean CVBufferHasAttachment(CVBufferRef buffer, CFStringRef key);
CV_EXPORT void CVBufferRemoveAttachment(CVBufferRef buffer, CFStringRef key);
CV_EXPORT void CVBufferRemoveAllAttachments(CVBufferRef buffer);
CV_EXPORT CFDictionaryRef CVBufferGetAttachments(CVBufferRef buffer, CVAttachmentMode attachmentMode);
CV_EXPORT CFDictionaryRef CVBufferCopyAttachments(CVBufferRef buffer, CVAttachmentMode attachmentMode) CF_RETURNS_RETAINED;
CV_EXPORT void CVBufferSetAttachments(CVBufferRef buffer, CFDictionaryRef theAttachments, CVAttachmentMode attachmentMode);
CV_EXPORT void CVBufferPropagateAttachments(CVBufferRef sourceBuffer, CVBufferRef destinationBuffer);
__END_DECLS
#endif
