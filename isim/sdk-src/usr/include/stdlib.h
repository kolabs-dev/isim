#pragma once
#include <_isim_cdefs.h>
#include <stddef.h>
__BEGIN_DECLS
#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1
#define RAND_MAX 0x7fffffff
typedef struct { int quot, rem; } div_t;
typedef struct { long quot, rem; } ldiv_t;
typedef struct { long long quot, rem; } lldiv_t;
extern int __mb_cur_max;
#define MB_CUR_MAX ((size_t)__mb_cur_max)
void *malloc(size_t);
void *calloc(size_t, size_t);
void *realloc(void *, size_t);
void free(void *);
void *aligned_alloc(size_t, size_t);
int posix_memalign(void **, size_t, size_t);
void exit(int) __attribute__((noreturn));
void _Exit(int) __attribute__((noreturn));
void _exit(int) __attribute__((noreturn));
void abort(void) __attribute__((noreturn));
int atexit(void (*)(void));
int at_quick_exit(void (*)(void));
void quick_exit(int) __attribute__((noreturn));
char *getenv(const char *);
int setenv(const char *, const char *, int);
int unsetenv(const char *);
int system(const char *);
long strtol(const char *, char **, int);
long long strtoll(const char *, char **, int);
unsigned long strtoul(const char *, char **, int);
unsigned long long strtoull(const char *, char **, int);
double strtod(const char *, char **);
float strtof(const char *, char **);
long double strtold(const char *, char **);
int atoi(const char *);
long atol(const char *);
long long atoll(const char *);
double atof(const char *);
int abs(int);
long labs(long);
long long llabs(long long);
div_t div(int, int);
ldiv_t ldiv(long, long);
lldiv_t lldiv(long long, long long);
int rand(void);
void srand(unsigned);
long random(void);
void srandom(unsigned);
void qsort(void *, size_t, size_t, int (*)(const void *, const void *));
void *bsearch(const void *, const void *, size_t, size_t, int (*)(const void *, const void *));
int mblen(const char *, size_t);
unsigned int arc4random(void);
unsigned int arc4random_uniform(unsigned int);
void arc4random_buf(void *, size_t);
char *realpath(const char *, char *);
__END_DECLS
