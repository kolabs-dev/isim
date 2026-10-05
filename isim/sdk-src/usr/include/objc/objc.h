#pragma once
/* isim SDK: Objective-C base types (ABI-compatible with Apple's 64-bit iOS runtime). */
#include <_isim_cdefs.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
typedef struct objc_class *Class;
typedef struct objc_object { Class _Nonnull isa; } *id;
typedef struct objc_selector *SEL;
typedef void (*IMP)(void);
typedef bool BOOL;                 /* 64-bit iOS: BOOL is bool */
#define YES __objc_yes
#define NO __objc_no
#ifdef __cplusplus
#define Nil nullptr
#define nil nullptr
#else
#define Nil ((void *)0)
#define nil ((void *)0)
#endif
#ifndef OBJC_EXTERN
#ifdef __cplusplus
#define OBJC_EXTERN extern "C"
#else
#define OBJC_EXTERN extern
#endif
#endif
#ifndef OBJC_EXPORT
#define OBJC_EXPORT OBJC_EXTERN __attribute__((visibility("default")))
#endif
#define OBJC_ROOT_CLASS __attribute__((objc_root_class))
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
__BEGIN_DECLS
OBJC_EXPORT const char * _Nonnull sel_getName(SEL _Nonnull sel);
OBJC_EXPORT SEL _Nonnull sel_registerName(const char * _Nonnull str);
OBJC_EXPORT const char * _Nonnull object_getClassName(id _Nullable obj);
OBJC_EXPORT BOOL sel_isEqual(SEL _Nonnull a, SEL _Nonnull b);
__END_DECLS
