#pragma once
/* isim: libmalloc subset. No zones; size queries use the host allocator. */
#include <_isim_cdefs.h>
#include <stddef.h>
__BEGIN_DECLS
typedef struct _malloc_zone_t malloc_zone_t;
size_t malloc_size(const void *ptr);
size_t malloc_good_size(size_t size);
malloc_zone_t *malloc_default_zone(void);
void *malloc_zone_malloc(malloc_zone_t *zone, size_t size);
void *malloc_zone_calloc(malloc_zone_t *zone, size_t n, size_t size);
void *malloc_zone_memalign(malloc_zone_t *zone, size_t align, size_t size);
malloc_zone_t *malloc_zone_from_ptr(const void *ptr);
void malloc_zone_free(malloc_zone_t *zone, void *ptr);
__END_DECLS
