#pragma once
#import <Foundation/Foundation.h>
#ifdef __cplusplus
#define MTK_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define MTK_EXTERN extern __attribute__((visibility("default")))
#endif
