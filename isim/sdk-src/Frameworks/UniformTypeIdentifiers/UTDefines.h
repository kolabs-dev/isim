#pragma once
#if !defined(__swift__)
#import <Foundation/Foundation.h>
#ifdef __cplusplus
#define UT_EXPORT extern "C" __attribute__((visibility("default")))
#else
#define UT_EXPORT extern __attribute__((visibility("default")))
#endif
#endif
