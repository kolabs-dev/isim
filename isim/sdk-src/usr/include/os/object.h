#pragma once
#define OS_OBJECT_USE_OBJC 0
#define OS_OBJECT_RETURNS_RETAINED
#define OS_OBJECT_DECL(name) typedef struct name##_s *name##_t
#define OS_OBJECT_DECL_CLASS(name) typedef struct name##_s *name##_t
#include <_isim_cdefs.h>
__BEGIN_DECLS
void *os_retain(void *object);
void os_release(void *object);
__END_DECLS
