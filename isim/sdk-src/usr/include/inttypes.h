#pragma once
#include <stdint.h>
#include <_isim_cdefs.h>
__BEGIN_DECLS
#define PRId8 "hhd"
#define PRId16 "hd"
#define PRId32 "d"
#define PRId64 "lld"
#define PRIi64 "lli"
#define PRIu8 "hhu"
#define PRIu16 "hu"
#define PRIu32 "u"
#define PRIu64 "llu"
#define PRIx32 "x"
#define PRIx64 "llx"
#define PRIX64 "llX"
#define PRIdPTR "ld"
#define PRIuPTR "lu"
#define PRIxPTR "lx"
#define PRIdMAX "jd"
#define PRIuMAX "ju"
#define SCNd64 "lld"
#define SCNu64 "llu"
#define PRIi8 "hhi"
#define PRIi16 "hi"
#define PRIi32 "i"
#define PRIo32 "o"
#define PRIo64 "llo"
#define PRIX32 "X"
#define PRIx8 "hhx"
#define PRIx16 "hx"
#define PRIiPTR "li"
#define PRIoPTR "lo"
#define PRIXPTR "lX"
#define PRIiMAX "ji"
#define PRIxMAX "jx"
#define SCNd32 "d"
#define SCNu32 "u"
#define SCNx64 "llx"
typedef struct { intmax_t quot, rem; } imaxdiv_t;
intmax_t imaxabs(intmax_t);
imaxdiv_t imaxdiv(intmax_t, intmax_t);
intmax_t strtoimax(const char *, char **, int);
uintmax_t strtoumax(const char *, char **, int);
__END_DECLS
