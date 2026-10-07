#pragma once
#include <CoreGraphics/CGBase.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
#pragma clang assume_nonnull begin
typedef struct CGDataProvider *CGDataProviderRef;
typedef struct CGDataConsumer *CGDataConsumerRef;
typedef void (*CGDataProviderReleaseDataCallback)(void *_Nullable info, const void *data, size_t size);
typedef size_t (*CGDataConsumerPutBytesCallback)(void *_Nullable info, const void *buffer, size_t count);
typedef void (*CGDataConsumerReleaseInfoCallback)(void *_Nullable info);
typedef struct CGDataConsumerCallbacks { CGDataConsumerPutBytesCallback _Nullable putBytes; CGDataConsumerReleaseInfoCallback _Nullable releaseConsumer; } CGDataConsumerCallbacks;
/* isim: providers are direct-access (bytes in memory); sequential/callback providers are not implemented */
CG_EXTERN CFTypeID CGDataProviderGetTypeID(void);
CG_EXTERN CGDataProviderRef _Nullable CGDataProviderCreateWithCFData(CFDataRef _Nullable data) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGDataProvider.init(data:));
CG_EXTERN CGDataProviderRef _Nullable CGDataProviderCreateWithData(void *_Nullable info, const void *_Nullable data, size_t size,
    CGDataProviderReleaseDataCallback _Nullable releaseData) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGDataProvider.init(dataInfo:data:size:releaseData:));
CG_EXTERN CGDataProviderRef _Nullable CGDataProviderCreateWithURL(CFURLRef _Nullable url) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGDataProvider.init(url:));
CG_EXTERN CGDataProviderRef _Nullable CGDataProviderCreateWithFilename(const char *_Nullable filename) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGDataProvider.init(filename:));
CG_EXTERN CGDataProviderRef _Nullable CGDataProviderRetain(CGDataProviderRef _Nullable provider);
CG_EXTERN void CGDataProviderRelease(CGDataProviderRef _Nullable provider);
CG_EXTERN CFDataRef _Nullable CGDataProviderCopyData(CGDataProviderRef _Nullable provider) CF_RETURNS_RETAINED CG_SWIFT_NAME(getter:CGDataProvider.data(self:));
CG_EXTERN void *_Nullable CGDataProviderGetInfo(CGDataProviderRef _Nullable provider) CG_SWIFT_NAME(getter:CGDataProvider.info(self:));
/* isim-private: the provider's bytes without copying */
CG_EXTERN const void *_Nullable isim_cg_provider_bytes(CGDataProviderRef _Nullable provider, size_t *_Nonnull size);

CG_EXTERN CFTypeID CGDataConsumerGetTypeID(void);
CG_EXTERN CGDataConsumerRef _Nullable CGDataConsumerCreateWithCFData(CFMutableDataRef _Nullable data) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGDataConsumer.init(data:));
CG_EXTERN CGDataConsumerRef _Nullable CGDataConsumerCreateWithURL(CFURLRef _Nullable url) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGDataConsumer.init(url:));
CG_EXTERN CGDataConsumerRef _Nullable CGDataConsumerCreate(void *_Nullable info, const CGDataConsumerCallbacks *_Nullable cbks) CF_RETURNS_RETAINED CG_SWIFT_NAME(CGDataConsumer.init(info:cbks:));
CG_EXTERN CGDataConsumerRef _Nullable CGDataConsumerRetain(CGDataConsumerRef _Nullable consumer);
CG_EXTERN void CGDataConsumerRelease(CGDataConsumerRef _Nullable consumer);
/* isim-private: writes bytes to the consumer; the file path of a URL consumer */
CG_EXTERN size_t isim_cg_consumer_put(CGDataConsumerRef consumer, const void *bytes, size_t n);
CG_EXTERN const char *_Nullable isim_cg_consumer_path(CGDataConsumerRef consumer);
#pragma clang assume_nonnull end
#pragma clang arc_cf_code_audited end
__END_DECLS
