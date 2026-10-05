#pragma once
/* isim: the NSObject protocol and root class interface (Apple declares these in libobjc).
 * The class itself is implemented by isim's Foundation. */
#include <objc/objc.h>
#include <objc/NSObjCRuntime.h>
#ifdef __OBJC__
#if __has_feature(objc_arc)
#define OBJC_ARC_UNAVAILABLE_ATTR __attribute__((unavailable("not available in automatic reference counting mode")))
#else
#define OBJC_ARC_UNAVAILABLE_ATTR
#endif
@class NSString, Protocol;
#pragma clang assume_nonnull begin
@protocol NSObject
- (BOOL)isEqual:(nullable id)object;
@property (readonly) NSUInteger hash;
@property (readonly, nullable) Class superclass;
- (Class)class;
- (instancetype)self;
- (id)performSelector:(SEL)aSelector;
- (id)performSelector:(SEL)aSelector withObject:(nullable id)object;
- (id)performSelector:(SEL)aSelector withObject:(nullable id)object1 withObject:(nullable id)object2;
- (BOOL)isProxy;
- (BOOL)isKindOfClass:(Class)aClass;
- (BOOL)isMemberOfClass:(Class)aClass;
- (BOOL)conformsToProtocol:(Protocol *)aProtocol;
- (BOOL)respondsToSelector:(SEL)aSelector;
- (instancetype)retain OBJC_ARC_UNAVAILABLE_ATTR;
- (oneway void)release OBJC_ARC_UNAVAILABLE_ATTR;
- (instancetype)autorelease OBJC_ARC_UNAVAILABLE_ATTR;
- (NSUInteger)retainCount OBJC_ARC_UNAVAILABLE_ATTR;
- (struct _NSZone *)zone OBJC_ARC_UNAVAILABLE_ATTR;
@property (readonly, copy) NSString *description;
@optional
@property (readonly, copy) NSString *debugDescription;
@end
__attribute__((objc_root_class))
@interface NSObject <NSObject> { Class isa; }
+ (void)load;
+ (void)initialize;
- (instancetype)init;
+ (instancetype)new;
+ (instancetype)allocWithZone:(nullable struct _NSZone *)zone;
+ (instancetype)alloc;
- (void)dealloc;
- (id)copy;
- (id)mutableCopy;
+ (BOOL)instancesRespondToSelector:(SEL)aSelector;
+ (BOOL)conformsToProtocol:(Protocol *)protocol;
- (IMP)methodForSelector:(SEL)aSelector;
+ (IMP)instanceMethodForSelector:(SEL)aSelector;
- (void)doesNotRecognizeSelector:(SEL)aSelector;
- (nullable id)forwardingTargetForSelector:(SEL)aSelector;
+ (BOOL)isSubclassOfClass:(Class)aClass;
+ (Class)superclass;
+ (Class)class;
+ (NSString *)description;
+ (NSString *)debugDescription;
@end
#pragma clang assume_nonnull end
#endif
