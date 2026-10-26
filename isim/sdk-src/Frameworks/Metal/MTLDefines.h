#pragma once
/* isim Metal (self-authored, iOS API names): Metal on the CPU (issue #328). Kernels written in the Metal Shading
 * Language are translated to C++ and compiled for the CPU by isim's toolchain (tools/mslc.py); compute dispatches run
 * on a pool of threads. Adapted: there is no GPU, and render pipelines are not available yet (issue #329). */
#import <Foundation/Foundation.h>
#ifdef __cplusplus
#define MTL_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define MTL_EXTERN extern __attribute__((visibility("default")))
#endif
#define MTL_EXPORT __attribute__((visibility("default")))
#define MTL_INLINE static inline
#define MTL_ERROR_ENUM(_type, _name, _domain) \
    enum __attribute__((ns_error_domain(_domain))) _name : _type _name; enum __attribute__((ns_error_domain(_domain))) _name : _type
