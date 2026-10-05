#pragma once
#include <_isim_cdefs.h>
#include <stddef.h>
#include <stdarg.h>
__BEGIN_DECLS
typedef struct __sFILE FILE;            /* opaque; host provides the object */
typedef long long fpos_t;
extern FILE *__stdinp, *__stdoutp, *__stderrp;
#define stdin __stdinp
#define stdout __stdoutp
#define stderr __stderrp
#define EOF (-1)
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
#define BUFSIZ 1024
#define FILENAME_MAX 1024
#define FOPEN_MAX 20
#define L_tmpnam 1024
#define TMP_MAX 308915776
#define _IOFBF 0
#define _IOLBF 1
#define _IONBF 2
int printf(const char *, ...) __attribute__((format(printf, 1, 2)));
int fprintf(FILE *, const char *, ...) __attribute__((format(printf, 2, 3)));
int sprintf(char *, const char *, ...);
int snprintf(char *, size_t, const char *, ...) __attribute__((format(printf, 3, 4)));
int vprintf(const char *, va_list);
int vfprintf(FILE *, const char *, va_list);
int vsprintf(char *, const char *, va_list);
int vsnprintf(char *, size_t, const char *, va_list);
int scanf(const char *, ...);
int fscanf(FILE *, const char *, ...);
int sscanf(const char *, const char *, ...);
int vscanf(const char *, va_list);
int vfscanf(FILE *, const char *, va_list);
int vsscanf(const char *, const char *, va_list);
int puts(const char *);
int fputs(const char *, FILE *);
int fputc(int, FILE *);
int putc(int, FILE *);
int putchar(int);
int fgetc(FILE *);
int getc(FILE *);
int getchar(void);
int ungetc(int, FILE *);
char *fgets(char *, int, FILE *);
size_t fwrite(const void *, size_t, size_t, FILE *);
size_t fread(void *, size_t, size_t, FILE *);
int fflush(FILE *);
FILE *fopen(const char *, const char *);
FILE *freopen(const char *, const char *, FILE *);
FILE *fdopen(int, const char *);
int fclose(FILE *);
int fseek(FILE *, long, int);
long ftell(FILE *);
void rewind(FILE *);
int fgetpos(FILE *, fpos_t *);
int fsetpos(FILE *, const fpos_t *);
void clearerr(FILE *);
int feof(FILE *);
int ferror(FILE *);
int fileno(FILE *);
void setbuf(FILE *, char *);
int setvbuf(FILE *, char *, int, size_t);
void perror(const char *);
int remove(const char *);
int rename(const char *, const char *);
FILE *tmpfile(void);
char *tmpnam(char *);
__END_DECLS
