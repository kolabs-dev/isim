#pragma once
/* isim SDK (self-authored, Apple's types): wide characters. Multibyte conversions use UTF-8 (adapted: as an app
 * under a UTF-8 locale); the rest is the host's C library. */
#include <_isim_cdefs.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>
#include <time.h>
__BEGIN_DECLS
#ifndef _WINT_T
#define _WINT_T
typedef int wint_t;
#endif
typedef union { char __mbstate8[128]; long long _mbstateL; } __mbstate_t;
typedef __mbstate_t mbstate_t;
#ifndef WEOF
#define WEOF ((wint_t)-1)
#endif
#ifndef WCHAR_MIN
#define WCHAR_MIN __WCHAR_MIN__
#define WCHAR_MAX __WCHAR_MAX__
#endif
struct tm;
wint_t btowc(int);
int wctob(wint_t);
size_t mbrlen(const char *, size_t, mbstate_t *);
size_t mbrtowc(wchar_t *, const char *, size_t, mbstate_t *);
int mbsinit(const mbstate_t *);
size_t mbsrtowcs(wchar_t *, const char **, size_t, mbstate_t *);
size_t mbsnrtowcs(wchar_t *, const char **, size_t, size_t, mbstate_t *);
size_t wcrtomb(char *, wchar_t, mbstate_t *);
size_t wcsrtombs(char *, const wchar_t **, size_t, mbstate_t *);
size_t wcsnrtombs(char *, const wchar_t **, size_t, size_t, mbstate_t *);
wchar_t *wcscat(wchar_t *, const wchar_t *);
wchar_t *wcschr(const wchar_t *, wchar_t);
int wcscmp(const wchar_t *, const wchar_t *);
int wcscoll(const wchar_t *, const wchar_t *);
wchar_t *wcscpy(wchar_t *, const wchar_t *);
size_t wcscspn(const wchar_t *, const wchar_t *);
size_t wcsftime(wchar_t *, size_t, const wchar_t *, const struct tm *);
size_t wcslen(const wchar_t *);
size_t wcsnlen(const wchar_t *, size_t);
wchar_t *wcsncat(wchar_t *, const wchar_t *, size_t);
int wcsncmp(const wchar_t *, const wchar_t *, size_t);
wchar_t *wcsncpy(wchar_t *, const wchar_t *, size_t);
wchar_t *wcspbrk(const wchar_t *, const wchar_t *);
wchar_t *wcsrchr(const wchar_t *, wchar_t);
size_t wcsspn(const wchar_t *, const wchar_t *);
wchar_t *wcsstr(const wchar_t *, const wchar_t *);
wchar_t *wcstok(wchar_t *, const wchar_t *, wchar_t **);
size_t wcsxfrm(wchar_t *, const wchar_t *, size_t);
wchar_t *wcsdup(const wchar_t *);
int wcscasecmp(const wchar_t *, const wchar_t *);
int wcsncasecmp(const wchar_t *, const wchar_t *, size_t);
size_t wcslcat(wchar_t *, const wchar_t *, size_t);
size_t wcslcpy(wchar_t *, const wchar_t *, size_t);
int wcswidth(const wchar_t *, size_t);
int wcwidth(wchar_t);
double wcstod(const wchar_t *, wchar_t **);
float wcstof(const wchar_t *, wchar_t **);
long double wcstold(const wchar_t *, wchar_t **);
long wcstol(const wchar_t *, wchar_t **, int);
long long wcstoll(const wchar_t *, wchar_t **, int);
unsigned long wcstoul(const wchar_t *, wchar_t **, int);
unsigned long long wcstoull(const wchar_t *, wchar_t **, int);
wchar_t *wmemchr(const wchar_t *, wchar_t, size_t);
int wmemcmp(const wchar_t *, const wchar_t *, size_t);
wchar_t *wmemcpy(wchar_t *, const wchar_t *, size_t);
wchar_t *wmemmove(wchar_t *, const wchar_t *, size_t);
wchar_t *wmemset(wchar_t *, wchar_t, size_t);
int swprintf(wchar_t *, size_t, const wchar_t *, ...);
int vswprintf(wchar_t *, size_t, const wchar_t *, va_list);
int swscanf(const wchar_t *, const wchar_t *, ...);
int fwide(FILE *, int);
wint_t fgetwc(FILE *);
wchar_t *fgetws(wchar_t *, int, FILE *);
wint_t fputwc(wchar_t, FILE *);
int fputws(const wchar_t *, FILE *);
wint_t getwc(FILE *);
wint_t getwchar(void);
wint_t putwc(wchar_t, FILE *);
wint_t putwchar(wchar_t);
wint_t ungetwc(wint_t, FILE *);
int fwprintf(FILE *, const wchar_t *, ...);
int wprintf(const wchar_t *, ...);
int vfwprintf(FILE *, const wchar_t *, va_list);
int vwprintf(const wchar_t *, va_list);
__END_DECLS
