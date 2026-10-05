#pragma once
#include <_isim_cdefs.h>
#include <stddef.h>
__BEGIN_DECLS
void *memcpy(void *, const void *, size_t);
void *memmove(void *, const void *, size_t);
void *memset(void *, int, size_t);
void memset_pattern4(void *b, const void *pattern4, size_t len);
void memset_pattern8(void *b, const void *pattern8, size_t len);
void memset_pattern16(void *b, const void *pattern16, size_t len);
/* C11 Annex K (Darwin provides memset_s unconditionally) */
#ifndef _ERRNO_T
#define _ERRNO_T
typedef int errno_t;
#endif
#ifndef _RSIZE_T
#define _RSIZE_T
typedef size_t rsize_t;
#endif
errno_t memset_s(void *dest, rsize_t destsz, int ch, rsize_t count);
int memcmp(const void *, const void *, size_t);
void *memchr(const void *, int, size_t);
size_t strlen(const char *);
size_t strnlen(const char *, size_t);
int strcmp(const char *, const char *);
int strncmp(const char *, const char *, size_t);
int strcoll(const char *, const char *);
size_t strxfrm(char *, const char *, size_t);
char *strcpy(char *, const char *);
char *strncpy(char *, const char *, size_t);
char *strcat(char *, const char *);
char *strncat(char *, const char *, size_t);
char *strchr(const char *, int);
char *strrchr(const char *, int);
char *strstr(const char *, const char *);
char *strpbrk(const char *, const char *);
size_t strspn(const char *, const char *);
size_t strcspn(const char *, const char *);
char *strtok(char *, const char *);
char *strtok_r(char *, const char *, char **);
char *strerror(int);
int strerror_r(int, char *, size_t);
char *strdup(const char *);
char *strndup(const char *, size_t);
size_t strlcpy(char *, const char *, size_t);
size_t strlcat(char *, const char *, size_t);
void bzero(void *, size_t);
int strcasecmp(const char *, const char *);
int strncasecmp(const char *, const char *, size_t);
__END_DECLS
