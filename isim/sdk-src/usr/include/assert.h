#pragma once
#include <stdio.h>
#include <stdlib.h>
#ifdef NDEBUG
#define assert(e) ((void)0)
#else
#define assert(e) ((e) ? (void)0 : (fprintf(stderr, "Assertion failed: (%s), function %s, file %s, line %d.\n", #e, __func__, __FILE__, __LINE__), abort()))
#endif
