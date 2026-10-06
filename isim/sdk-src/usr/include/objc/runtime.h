#pragma once
#include <objc/objc.h>
#include <objc/objc-api.h>
__BEGIN_DECLS
#ifdef __OBJC__
@class Protocol;
#else
typedef struct objc_object Protocol;
#endif
typedef struct objc_method *Method;
typedef struct objc_ivar *Ivar;
typedef struct objc_property *objc_property_t;
OBJC_EXPORT Method _Nullable class_getInstanceMethod(Class _Nullable cls, SEL _Nonnull name);
OBJC_EXPORT Method _Nullable class_getClassMethod(Class _Nullable cls, SEL _Nonnull name);
OBJC_EXPORT IMP _Nonnull method_getImplementation(Method _Nonnull m);
OBJC_EXPORT SEL _Nonnull method_getName(Method _Nonnull m);
OBJC_EXPORT const char * _Nullable method_getTypeEncoding(Method _Nonnull m);
OBJC_EXPORT BOOL class_addMethod(Class _Nullable cls, SEL _Nonnull name, IMP _Nonnull imp, const char * _Nullable types);
OBJC_EXPORT id _Nullable objc_getAssociatedObject(id _Nonnull object, const void * _Nonnull key);
typedef uintptr_t objc_AssociationPolicy;
enum { OBJC_ASSOCIATION_ASSIGN = 0, OBJC_ASSOCIATION_RETAIN_NONATOMIC = 1, OBJC_ASSOCIATION_COPY_NONATOMIC = 3,
       OBJC_ASSOCIATION_RETAIN = 01401, OBJC_ASSOCIATION_COPY = 01403 };
OBJC_EXPORT void objc_setAssociatedObject(id _Nonnull object, const void * _Nonnull key, id _Nullable value, objc_AssociationPolicy policy);
OBJC_EXPORT const char * _Nullable class_getImageName(Class _Nullable cls);
OBJC_EXPORT Class _Nullable objc_getRequiredClass(const char * _Nonnull name);
OBJC_EXPORT Class _Nonnull * _Nullable objc_copyClassList(unsigned int * _Nullable outCount);
/* introspection used by the Swift runtime */
OBJC_EXPORT Ivar _Nonnull * _Nullable class_copyIvarList(Class _Nullable cls, unsigned int * _Nullable outCount);
OBJC_EXPORT ptrdiff_t ivar_getOffset(Ivar _Nonnull v);
OBJC_EXPORT const char * _Nullable ivar_getName(Ivar _Nonnull v);
OBJC_EXPORT const char * _Nullable ivar_getTypeEncoding(Ivar _Nonnull v);
OBJC_EXPORT objc_property_t _Nullable class_getProperty(Class _Nullable cls, const char * _Nonnull name);
OBJC_EXPORT objc_property_t _Nonnull * _Nullable class_copyPropertyList(Class _Nullable cls, unsigned int * _Nullable outCount);
OBJC_EXPORT const char * _Nonnull property_getName(objc_property_t _Nonnull property);
OBJC_EXPORT const char * _Nullable property_getAttributes(objc_property_t _Nonnull property);
OBJC_EXPORT Class _Nonnull class_setSuperclass(Class _Nonnull cls, Class _Nonnull newSuper);
OBJC_EXPORT IMP _Nonnull method_setImplementation(Method _Nonnull m, IMP _Nonnull imp);
OBJC_EXPORT void method_exchangeImplementations(Method _Nonnull m1, Method _Nonnull m2);
OBJC_EXPORT id _Nullable objc_constructInstance(Class _Nullable cls, void * _Nullable bytes);
OBJC_EXPORT BOOL object_isClass(id _Nullable obj);
/* weak references & ARC entry points */
OBJC_EXPORT id _Nullable objc_storeWeak(id _Nullable * _Nonnull location, id _Nullable obj);
OBJC_EXPORT id _Nullable objc_initWeak(id _Nullable * _Nonnull location, id _Nullable val);
OBJC_EXPORT id _Nullable objc_loadWeakRetained(id _Nullable * _Nonnull location);
OBJC_EXPORT id _Nullable objc_loadWeak(id _Nullable * _Nonnull location);
OBJC_EXPORT void objc_destroyWeak(id _Nullable * _Nonnull location);
OBJC_EXPORT void objc_copyWeak(id _Nullable * _Nonnull to, id _Nullable * _Nonnull from);
OBJC_EXPORT void objc_moveWeak(id _Nullable * _Nonnull to, id _Nullable * _Nonnull from);
OBJC_EXPORT id _Nullable objc_retain(id _Nullable obj);
OBJC_EXPORT void objc_release(id _Nullable obj);
OBJC_EXPORT id _Nullable objc_autorelease(id _Nullable obj);
/* Swift-specific libobjc entry point; weak so clients can test for it. isim does not provide it yet,
 * so the Swift runtime takes its objc_readClassPair fallback path. */
OBJC_EXPORT Class _Nullable _objc_realizeClassFromSwift(Class _Nullable cls, void * _Nullable previously) __attribute__((weak_import));
/* runtime hooks (feature macros like OBJC_GETCLASSHOOK_DEFINED are intentionally NOT defined:
 * the Swift runtime then uses its fallback paths) */
typedef BOOL (*objc_hook_getImageName)(Class _Nonnull cls, const char * _Nullable * _Nonnull outImageName);
OBJC_EXPORT void objc_setHook_getImageName(objc_hook_getImageName _Nonnull newValue, objc_hook_getImageName _Nullable * _Nonnull outOldValue);
typedef BOOL (*objc_hook_getClass)(const char * _Nonnull name, Class _Nullable * _Nonnull outClass);
OBJC_EXPORT void objc_setHook_getClass(objc_hook_getClass _Nonnull newValue, objc_hook_getClass _Nullable * _Nonnull outOldValue);
struct mach_header;
typedef void (*objc_func_loadImage)(const struct mach_header * _Nonnull header);
OBJC_EXPORT void objc_addLoadImageFunc(objc_func_loadImage _Nonnull func);
typedef const char * _Nullable (*objc_hook_lazyClassNamer)(Class _Nonnull cls);
OBJC_EXPORT void objc_setHook_lazyClassNamer(objc_hook_lazyClassNamer _Nonnull newValue, objc_hook_lazyClassNamer _Nullable * _Nonnull oldOutValue);
OBJC_EXPORT Class _Nullable objc_getClass(const char * _Nonnull name);
OBJC_EXPORT Class _Nullable objc_lookUpClass(const char * _Nonnull name);
OBJC_EXPORT Class _Nullable objc_getMetaClass(const char * _Nonnull name);
OBJC_EXPORT const char * _Nonnull class_getName(Class _Nullable cls);
OBJC_EXPORT Class _Nullable class_getSuperclass(Class _Nullable cls);
OBJC_EXPORT BOOL class_isMetaClass(Class _Nullable cls);
OBJC_EXPORT size_t class_getInstanceSize(Class _Nullable cls);
OBJC_EXPORT Class _Nullable object_getClass(id _Nullable obj);
OBJC_EXPORT Class _Nullable object_setClass(id _Nullable obj, Class _Nonnull cls);
OBJC_EXPORT BOOL class_respondsToSelector(Class _Nullable cls, SEL _Nonnull sel);
OBJC_EXPORT IMP _Nullable class_getMethodImplementation(Class _Nullable cls, SEL _Nonnull name);
OBJC_EXPORT BOOL class_conformsToProtocol(Class _Nullable cls, Protocol * _Nullable protocol);
OBJC_EXPORT Protocol * _Nullable objc_getProtocol(const char * _Nonnull name);
OBJC_EXPORT const char * _Nonnull protocol_getName(Protocol * _Nonnull proto);
OBJC_EXPORT BOOL protocol_conformsToProtocol(Protocol * _Nullable proto, Protocol * _Nullable other);
OBJC_EXPORT id _Nullable class_createInstance(Class _Nullable cls, size_t extraBytes) NS_RETURNS_RETAINED;
OBJC_EXPORT id _Nullable object_dispose(id _Nullable obj);
OBJC_EXPORT void * _Nullable objc_destructInstance(id _Nullable obj);
__END_DECLS
