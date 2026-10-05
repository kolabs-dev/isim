#pragma once
#include <objc/objc.h>
struct objc_super { __unsafe_unretained id _Nonnull receiver; __unsafe_unretained Class _Nonnull super_class; };
__BEGIN_DECLS
OBJC_EXPORT void objc_msgSend(void);
OBJC_EXPORT void objc_msgSendSuper(void);
OBJC_EXPORT void objc_msgSend_stret(void);
__END_DECLS
