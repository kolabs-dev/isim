#pragma once
#include <_isim_cdefs.h>
#include <stdint.h>
/* Darwin's character classes (<_ctype.h>) and its C locale's rune table (<runetype.h>): libc++'s ctype<char> reads
   _DefaultRuneLocale.__runetype with these masks */
#define _CTYPE_A 0x00000100L
#define _CTYPE_C 0x00000200L
#define _CTYPE_D 0x00000400L
#define _CTYPE_G 0x00000800L
#define _CTYPE_L 0x00001000L
#define _CTYPE_P 0x00002000L
#define _CTYPE_S 0x00004000L
#define _CTYPE_U 0x00008000L
#define _CTYPE_X 0x00010000L
#define _CTYPE_B 0x00020000L
#define _CTYPE_R 0x00040000L
#define _CTYPE_I 0x00080000L
#define _CTYPE_T 0x00100000L
#define _CTYPE_Q 0x00200000L
#define _CTYPE_SW0 0x20000000L
#define _CTYPE_SW1 0x40000000L
#define _CTYPE_SW2 0x80000000L
#define _CTYPE_SW3 0xc0000000L
#define _CTYPE_SWM 0xe0000000L
#define _CTYPE_SWS 30
#define _CACHED_RUNES (1 << 8)
typedef struct { int32_t __min, __max, __map; uint32_t *__types; } _RuneEntry;
typedef struct { int __nranges; _RuneEntry *__ranges; } _RuneRange;
typedef struct { char __name[14]; uint32_t __mask; } _RuneCharClass;
typedef struct {
    char __magic[8], __encoding[32];
    void *__sgetrune, *__sputrune;
    int32_t __invalid_rune;
    uint32_t __runetype[_CACHED_RUNES];
    int32_t __maplower[_CACHED_RUNES], __mapupper[_CACHED_RUNES];
    _RuneRange __runetype_ext, __maplower_ext, __mapupper_ext;
    void *__variable;
    int __variable_len, __ncharclasses;
    _RuneCharClass *__charclasses;
} _RuneLocale;
__BEGIN_DECLS
extern _RuneLocale _DefaultRuneLocale;
int isalpha(int); int isdigit(int); int isalnum(int); int isspace(int); int isupper(int);
int islower(int); int isxdigit(int); int ispunct(int); int isprint(int); int iscntrl(int); int isgraph(int);
int isblank(int); int isascii(int); int toascii(int);
int tolower(int); int toupper(int);
__END_DECLS
