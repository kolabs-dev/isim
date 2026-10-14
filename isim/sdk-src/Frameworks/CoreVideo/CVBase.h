#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CGGeometry.h>
#include <stdint.h>
#if !defined(__swift__)
#define CV_EXPORT extern __attribute__((visibility("default")))
#define CV_BRIDGED_TYPE(type) __attribute__((objc_bridge(type)))
typedef uint64_t CVOptionFlags;
#ifndef __MACTYPES__   /* MacTypes.h on Apple */
#define __MACTYPES__
typedef uint32_t FourCharCode;
typedef FourCharCode OSType;
#endif
#endif
