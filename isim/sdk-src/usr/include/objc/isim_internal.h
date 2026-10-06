#pragma once
/* isim runtime private entry points used by the isim Foundation implementation. */
#include <objc/runtime.h>
__BEGIN_DECLS
id _Nullable _objc_rootRetain(id _Nullable);
void _objc_rootRelease(id _Nullable);
BOOL _objc_rootReleaseWasZero(id _Nonnull);
unsigned long _objc_rootRetainCount(id _Nonnull);
id _Nullable _objc_rootAutorelease(id _Nullable);
BOOL _objc_rootIsDeallocating(id _Nonnull);
void * _Nonnull objc_autoreleasePoolPush(void);
void objc_autoreleasePoolPop(void * _Nonnull);
__attribute__((noreturn)) void objc_exception_throw(id _Nonnull);

/* message forwarding: _objc_msgForward(_stret) saves the argument registers of the unhandled send in
 * an isim_objc_frame and calls the handler (Foundation's NSInvocation-based forwarding). The handler
 * returns a new receiver to re-send the message to (forwardingTargetForSelector:), or nil after it
 * stored the return value in ret_gpr/ret_xmm (or in the stret buffer, gpr[0]). */
typedef struct isim_objc_frame {
    uint64_t gpr[6];             /* rdi rsi rdx rcx r8 r9 */
    uint64_t xmm[8][2];          /* xmm0-xmm7 */
    uint64_t * _Nonnull stack;   /* first stack-passed argument */
    uint64_t rax;                /* vector register count of variadic calls */
    uint64_t ret_gpr[2];         /* rax, rdx when returning */
    uint64_t ret_xmm[2][2];      /* xmm0, xmm1 when returning */
    uint64_t stret;              /* 1: entered through _objc_msgForward_stret (gpr[0] = result buffer) */
    uint64_t reserved;
} isim_objc_frame;
typedef id _Nullable (*isim_objc_forward_handler)(id _Nonnull self, SEL _Nonnull sel, isim_objc_frame * _Nonnull frame);
void isim_objc_set_forward_handler(isim_objc_forward_handler _Nullable handler);
/* calls fn with the given argument registers (x86_64 SysV) and nstack words of stack arguments */
typedef struct isim_objc_call {
    void * _Nonnull fn;
    uint64_t gpr[6];
    uint64_t xmm[8][2];
    const uint64_t * _Nullable stack;
    uint64_t nstack, nvec;
    uint64_t ret_gpr[2];
    uint64_t ret_xmm[2][2];
} isim_objc_call;
void isim_objc_call_frame(isim_objc_call * _Nonnull call);
__END_DECLS
