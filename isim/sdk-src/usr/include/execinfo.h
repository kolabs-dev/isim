#pragma once
/* isim SDK (self-authored): backtraces of the calling thread (passthrough: the host's unwinder; backtrace_symbols
 * prints the host's format, not Darwin's). */
#include <_isim_cdefs.h>
__BEGIN_DECLS
int backtrace(void **, int);
char **backtrace_symbols(void *const *, int);
void backtrace_symbols_fd(void *const *, int, int);
__END_DECLS
