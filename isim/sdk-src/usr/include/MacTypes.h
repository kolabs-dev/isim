#pragma once
/* isim MacTypes (self-authored, Apple's names and sizes): the basic integer, floating-point and status types that
 * Apple's C frameworks (AudioToolbox, CoreAudio, CoreMedia) use in their prototypes. */
#include <stdint.h>
typedef uint8_t UInt8;
typedef int8_t SInt8;
typedef uint16_t UInt16;
typedef int16_t SInt16;
typedef uint32_t UInt32;
typedef int32_t SInt32;
typedef uint64_t UInt64;
typedef int64_t SInt64;
typedef float Float32;
typedef double Float64;
typedef unsigned char Boolean;
typedef int16_t OSErr;
typedef int32_t OSStatus;
typedef uint32_t FourCharCode;
typedef FourCharCode OSType;
typedef UInt32 UTF32Char;
typedef UInt16 UniChar;
enum { noErr = 0 };
