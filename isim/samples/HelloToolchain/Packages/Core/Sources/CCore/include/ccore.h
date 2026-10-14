#ifndef CCORE_H
#define CCORE_H
/* C target of the Core package: Swift imports it as module CCore */
int ccore_scaled(int value);
const char *ccore_name(void);
/* POSIX regular expressions and platform facts through the Darwin C headers (posix.c) */
int ccore_matches(const char *pattern, const char *text);
int ccore_platform_ok(void);
#endif
