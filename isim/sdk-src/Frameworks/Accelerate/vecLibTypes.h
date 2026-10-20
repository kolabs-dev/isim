#pragma once
#include <stddef.h>
#include <stdbool.h>
#ifdef __cplusplus
#define VECLIB_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define VECLIB_EXTERN extern __attribute__((visibility("default")))
#endif
#ifndef __has_feature
#define __has_feature(x) 0
#endif
#if !defined(_Nullable) && !__has_feature(nullability)
#define _Nullable
#define _Nonnull
#endif
