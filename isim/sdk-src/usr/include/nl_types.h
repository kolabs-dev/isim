/* isim SDK (self-authored, not Apple's). <nl_types.h>: message catalogs (the host's catopen/catgets). */
#pragma once
#include <_isim_cdefs.h>
#define NL_SETD 1
#define NL_CAT_LOCALE 1
typedef struct __nl_cat_d *nl_catd;
typedef int nl_item;
__BEGIN_DECLS
nl_catd catopen(const char *, int);
char *catgets(nl_catd, int, int, const char *);
int catclose(nl_catd);
__END_DECLS
