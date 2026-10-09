#pragma once
/* isim SDK (self-authored): CPU types. */
#include <mach/mach_types.h>
#define CPU_ARCH_ABI64 0x01000000
#define CPU_TYPE_ANY ((cpu_type_t)-1)
#define CPU_TYPE_X86 ((cpu_type_t)7)
#define CPU_TYPE_I386 CPU_TYPE_X86
#define CPU_TYPE_X86_64 (CPU_TYPE_X86 | CPU_ARCH_ABI64)
#define CPU_TYPE_ARM ((cpu_type_t)12)
#define CPU_TYPE_ARM64 (CPU_TYPE_ARM | CPU_ARCH_ABI64)
#define CPU_SUBTYPE_X86_64_ALL ((cpu_subtype_t)3)
#define CPU_SUBTYPE_X86_64_H ((cpu_subtype_t)8)
#define CPU_SUBTYPE_ARM64_ALL ((cpu_subtype_t)0)
#define CPU_STATE_USER 0
#define CPU_STATE_SYSTEM 1
#define CPU_STATE_IDLE 2
#define CPU_STATE_NICE 3
#define CPU_STATE_MAX 4
