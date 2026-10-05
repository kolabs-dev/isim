#pragma once
/* Apple declares NSInteger/NSUInteger in libobjc's NSObjCRuntime.h */
typedef long NSInteger;
typedef unsigned long NSUInteger;
#define NSIntegerMax __LONG_MAX__
#define NSIntegerMin (-__LONG_MAX__ - 1L)
#define NSUIntegerMax (__LONG_MAX__ * 2UL + 1UL)
