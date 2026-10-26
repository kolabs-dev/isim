#pragma once
#import <Metal/MTLResource.h>
NS_ASSUME_NONNULL_BEGIN
/* declared for MTLResource.heap; isim does not create heaps (resources are never sub-allocated from one) */
@protocol MTLHeap <MTLAllocation>
@property (nullable, copy, atomic) NSString *label;
@property (readonly) id<MTLDevice> device;
@property (readonly) MTLStorageMode storageMode;
@property (readonly) NSUInteger size;
@property (readonly) NSUInteger usedSize;
@end
NS_ASSUME_NONNULL_END
