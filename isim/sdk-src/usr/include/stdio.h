#pragma once
#include <_isim_cdefs.h>
#include <stddef.h>
#include <stdarg.h>
__BEGIN_DECLS
typedef struct __sFILE FILE;            /* opaque; host provides the object */
extern FILE *__stdinp, *__stdoutp, *__stderrp;
#define stdin __stdinp
#define stdout __stdoutp
#define stderr __stderrp
#define EOF (-1)
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
int printf(const char *, ...) __attribute__((format(printf, 1, 2)));
int fprintf(FILE *, const char *, ...) __attribute__((format(printf, 2, 3)));
int sprintf(char *, const char *, ...);
int snprintf(char *, size_t, const char *, ...) __attribute__((format(printf, 3, 4)));
int vprintf(const char *, va_list);
int vfprintf(FILE *, const char *, va_list);
int vsprintf(char *, const char *, va_list);
int vsnprintf(char *, size_t, const char *, va_list);
int sscanf(const char *, const char *, ...);
int puts(const char *);
int fputs(const char *, FILE *);
int fputc(int, FILE *);
int putchar(int);
size_t fwrite(const void *, size_t, size_t, FILE *);
size_t fread(void *, size_t, size_t, FILE *);
int fflush(FILE *);
FILE *fopen(const char *, const char *);
int fclose(FILE *);
char *fgets(char *, int, FILE *);
int fseek(FILE *, long, int);
long ftell(FILE *);
void perror(const char *);
__END_DECLS
