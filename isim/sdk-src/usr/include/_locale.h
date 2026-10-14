/* isim SDK (self-authored, not Apple's). locale_t and the POSIX 2008 locale functions (Darwin's <_locale.h>). */
#pragma once
#include <_isim_cdefs.h>
typedef struct _xlocale *locale_t;
#define LC_COLLATE_MASK (1 << 0)
#define LC_CTYPE_MASK (1 << 1)
#define LC_MESSAGES_MASK (1 << 2)
#define LC_MONETARY_MASK (1 << 3)
#define LC_NUMERIC_MASK (1 << 4)
#define LC_TIME_MASK (1 << 5)
#define LC_ALL_MASK (LC_COLLATE_MASK | LC_CTYPE_MASK | LC_MESSAGES_MASK | LC_MONETARY_MASK | LC_NUMERIC_MASK | LC_TIME_MASK)
#define LC_GLOBAL_LOCALE ((locale_t)-1)
__BEGIN_DECLS
locale_t duplocale(locale_t);
int freelocale(locale_t);
locale_t newlocale(int, const char *, locale_t);
locale_t uselocale(locale_t);
const char *querylocale(int, locale_t);
__END_DECLS
