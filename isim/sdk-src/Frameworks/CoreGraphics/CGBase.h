#pragma once
#include <_isim_cdefs.h>
#include <Availability.h>
#include <TargetConditionals.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
typedef double CGFloat;
#define CGFLOAT_IS_DOUBLE 1
#define CGFLOAT_MIN 2.2250738585072014e-308
#define CGFLOAT_MAX 1.7976931348623157e+308
#define CG_EXTERN extern __attribute__((visibility("default")))
#define CG_INLINE static inline
#ifndef CF_ENUM
#define CF_ENUM(_type, _name) enum __attribute__((enum_extensibility(open))) _name : _type _name; enum _name : _type
#define CF_OPTIONS(_type, _name) enum __attribute__((flag_enum, enum_extensibility(open))) _name : _type _name; enum _name : _type
#endif
