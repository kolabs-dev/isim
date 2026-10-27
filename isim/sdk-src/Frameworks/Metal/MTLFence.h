#pragma once
/* isim Metal: fences. isim runs a queue's command buffers in order on the CPU, so a fence orders nothing more; it exists
 * for the APIs that take one (MetalFX's scalers, issue #365). */
#import <Metal/MTLDefines.h>

NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice;
API_AVAILABLE(ios(10.0))
@protocol MTLFence <NSObject>
@property (readonly) id<MTLDevice> device;
@property (nullable, copy, atomic) NSString *label;
@end
NS_ASSUME_NONNULL_END
