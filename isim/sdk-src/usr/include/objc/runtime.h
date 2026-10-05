#pragma once
#include <objc/objc.h>
__BEGIN_DECLS
#ifdef __OBJC__
@class Protocol;
#else
typedef struct objc_object Protocol;
#endif
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
