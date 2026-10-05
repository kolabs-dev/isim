#pragma once
#include <time.h>
struct timeval { time_t tv_sec; int tv_usec; };
int gettimeofday(struct timeval *, void *);
