#pragma once
#include <_isim_cdefs.h>
#include <stddef.h>
__BEGIN_DECLS
#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1
void *malloc(size_t);
void *calloc(size_t, size_t);
void *realloc(void *, size_t);
void free(void *);
int posix_memalign(void **, size_t, size_t);
void exit(int) __attribute__((noreturn));
void _exit(int) __attribute__((noreturn));
void abort(void) __attribute__((noreturn));
int atexit(void (*)(void));
char *getenv(const char *);
int setenv(const char *, const char *, int);
long strtol(const char *, char **, int);
long long strtoll(const char *, char **, int);
unsigned long strtoul(const char *, char **, int);
unsigned long long strtoull(const char *, char **, int);
double strtod(const char *, char **);
float strtof(const char *, char **);
int atoi(const char *);
long atol(const char *);
double atof(const char *);
int abs(int);
long labs(long);
long long llabs(long long);
void qsort(void *, size_t, size_t, int (*)(const void *, const void *));
void *bsearch(const void *, const void *, size_t, size_t, int (*)(const void *, const void *));
unsigned int arc4random(void);
unsigned int arc4random_uniform(unsigned int);
void arc4random_buf(void *, size_t);
__END_DECLS
