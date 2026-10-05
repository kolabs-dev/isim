#pragma once
#include <_isim_cdefs.h>
__BEGIN_DECLS
void *_Block_copy(const void *);
void _Block_release(const void *);
#define Block_copy(b) ((__typeof__(b))_Block_copy((const void *)(b)))
#define Block_release(b) _Block_release((const void *)(b))
__END_DECLS
