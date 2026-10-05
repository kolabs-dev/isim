#pragma once
/* isim: wide-character classification (Unicode-aware, independent of setlocale) */
#include <_isim_cdefs.h>
__BEGIN_DECLS
#ifndef _WINT_T
#define _WINT_T
typedef int wint_t;
#endif
#define WEOF ((wint_t)-1)
int iswalpha(wint_t); int iswdigit(wint_t); int iswalnum(wint_t); int iswspace(wint_t); int iswpunct(wint_t);
int iswupper(wint_t); int iswlower(wint_t); int iswcntrl(wint_t); int iswprint(wint_t); int iswxdigit(wint_t); int iswgraph(wint_t);
wint_t towupper(wint_t); wint_t towlower(wint_t);
__END_DECLS
