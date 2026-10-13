/* isim SDK (self-authored, not Apple's). <xlocale.h>: the _l variants that take a locale (NULL is the C locale). */
#pragma once
#include <locale.h>
#include <stddef.h>
#include <stdarg.h>
struct lconv;
struct tm;
typedef struct __sFILE FILE;
__BEGIN_DECLS
struct lconv *localeconv_l(locale_t);
int ___mb_cur_max_l(locale_t);
#define MB_CUR_MAX_L(x) ((size_t)___mb_cur_max_l(x))
float strtof_l(const char *, char **, locale_t);
double strtod_l(const char *, char **, locale_t);
long double strtold_l(const char *, char **, locale_t);
long strtol_l(const char *, char **, int, locale_t);
long long strtoll_l(const char *, char **, int, locale_t);
unsigned long strtoul_l(const char *, char **, int, locale_t);
unsigned long long strtoull_l(const char *, char **, int, locale_t);
double atof_l(const char *, locale_t);
int toupper_l(int, locale_t);
int tolower_l(int, locale_t);
int isalnum_l(int, locale_t);
int isalpha_l(int, locale_t);
int isblank_l(int, locale_t);
int iscntrl_l(int, locale_t);
int isdigit_l(int, locale_t);
int isgraph_l(int, locale_t);
int islower_l(int, locale_t);
int isprint_l(int, locale_t);
int ispunct_l(int, locale_t);
int isspace_l(int, locale_t);
int isupper_l(int, locale_t);
int isxdigit_l(int, locale_t);
int strcoll_l(const char *, const char *, locale_t);
size_t strxfrm_l(char *, const char *, size_t, locale_t);
int strcasecmp_l(const char *, const char *, locale_t);
int strncasecmp_l(const char *, const char *, size_t, locale_t);
size_t strftime_l(char *, size_t, const char *, const struct tm *, locale_t) __attribute__((format(strftime, 3, 0)));
char *strptime_l(const char *, const char *, struct tm *, locale_t);
int printf_l(locale_t, const char *, ...) __attribute__((format(printf, 2, 3)));
int fprintf_l(FILE *, locale_t, const char *, ...) __attribute__((format(printf, 3, 4)));
int sprintf_l(char *, locale_t, const char *, ...) __attribute__((format(printf, 3, 4)));
int snprintf_l(char *, size_t, locale_t, const char *, ...) __attribute__((format(printf, 4, 5)));
int asprintf_l(char **, locale_t, const char *, ...) __attribute__((format(printf, 3, 4)));
int vsnprintf_l(char *, size_t, locale_t, const char *, va_list) __attribute__((format(printf, 4, 0)));
int vasprintf_l(char **, locale_t, const char *, va_list) __attribute__((format(printf, 3, 0)));
int sscanf_l(const char *, locale_t, const char *, ...) __attribute__((format(scanf, 3, 4)));
int vsscanf_l(const char *, locale_t, const char *, va_list) __attribute__((format(scanf, 3, 0)));
__END_DECLS
