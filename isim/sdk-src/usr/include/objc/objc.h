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
#define Nil ((Class)0)
#define nil ((id)0)
#define OBJC_EXPORT extern __attribute__((visibility("default")))
#define OBJC_ROOT_CLASS __attribute__((objc_root_class))
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
__BEGIN_DECLS
OBJC_EXPORT const char * _Nonnull sel_getName(SEL _Nonnull sel);
OBJC_EXPORT SEL _Nonnull sel_registerName(const char * _Nonnull str);
OBJC_EXPORT const char * _Nonnull object_getClassName(id _Nullable obj);
OBJC_EXPORT BOOL sel_isEqual(SEL _Nonnull a, SEL _Nonnull b);
__END_DECLS
