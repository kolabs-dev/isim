#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSMethodSignature, NSInvocation;
/* isim: a root class like Apple's. Unimplemented messages go through -methodSignatureForSelector: and
 * -forwardInvocation:; -isKindOfClass:, -isMemberOfClass:, -respondsToSelector: and -conformsToProtocol:
 * are forwarded as invocations too. */
NS_ROOT_CLASS
@interface NSProxy <NSObject> {
    Class isa;
}
+ (id)alloc;
+ (id)allocWithZone:(nullable NSZone *)zone NS_AUTOMATED_REFCOUNT_UNAVAILABLE;
+ (Class)class;
- (void)forwardInvocation:(NSInvocation *)invocation;
- (nullable NSMethodSignature *)methodSignatureForSelector:(SEL)sel NS_SWIFT_UNAVAILABLE("NSInvocation and related APIs not available");
- (void)dealloc;
- (void)finalize;
@property (readonly, copy) NSString *description;
@property (readonly, copy) NSString *debugDescription;
+ (BOOL)respondsToSelector:(SEL)aSelector;
- (BOOL)allowsWeakReference;
- (BOOL)retainWeakReference;
@end
NS_ASSUME_NONNULL_END
