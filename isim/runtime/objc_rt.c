#include <signal.h>
/*
 * isim Objective-C runtime (host side) for Apple's ObjC2 x86_64 ABI as emitted by
 * clang for the iOS simulator. Classes, categories, selectors and protocols are
 * read from guest images; retain counts, weak references, autorelease pools and
 * per-class runtime state live in host memory.
 *
 * Implemented: multi-image registration, selector uniquing, class realization with
 * non-fragile ivar sliding, categories, protocols (conformance by name), +load,
 * +initialize, objc_msgSend/Super2/_stret variants, ARC entry points, weak refs,
 * autorelease pools, property accessors, @synchronized, fast-enumeration mutation
 * hook, class/object introspection subset.
 *
 * +resolveInstanceMethod:/+resolveClassMethod:, property introspection (class_getProperty & co.).
 * Not implemented: message forwarding (aborts with the selector),
 * tagged pointers, non-pointer isa, associated objects, exceptions (throw aborts),
 * method swizzling APIs, class_addMethod, ivar/property introspection, fpret variants.
 */
#define _GNU_SOURCE
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "runtime.h"

typedef struct objc_class *Class;
typedef struct objc_object { Class isa; } *id;
typedef const char *SEL;
typedef void *IMP;

struct method_t { SEL name; const char *types; IMP imp; };
struct method_list_t { uint32_t entsize_flags, count; };
struct ivar_t { int32_t *offset; const char *name, *type; uint32_t alignment_raw, size; };
struct ivar_list_t { uint32_t entsize_flags, count; };
struct protocol_t;
struct protocol_list_t { uintptr_t count; struct protocol_t *list[]; };
struct protocol_t {
    Class isa; const char *name; struct protocol_list_t *protocols;
    struct method_list_t *inst, *cls, *opt_inst, *opt_cls; void *props;
    uint32_t size, flags;
};
struct class_ro_t {
    uint32_t flags, instance_start, instance_size, reserved;
    const uint8_t *ivar_layout; const char *name;
    struct method_list_t *base_methods;
    struct protocol_list_t *base_protocols;
    struct ivar_list_t *ivars; const uint8_t *weak_ivar_layout; void *base_properties;
};
struct category_t {
    const char *name; Class cls;
    struct method_list_t *inst, *cls_methods; struct protocol_list_t *protocols;
    void *inst_props, *cls_props; uint32_t size;
};
/* class->vtable (unused by modern compiled code) points at our per-class state */
struct objc_class { Class isa, superclass; void *cache; struct rt_class *rt; uintptr_t data; };

struct rt_method { SEL name; const char *types; IMP imp; Class cls; struct rt_method *next; };
struct rt_class {
    struct rt_method *methods;                 /* runtime-added or retargeted methods (class_addMethod, method_setImplementation) */
    Class cls, nonmeta;
    int realized, is_meta;
    int init_state;                            /* 0 none, 1 initializing, 2 done */
    struct method_list_t **cat_lists; int ncat, catcap;
    struct protocol_list_t **cat_protos; int ncatp;
    void **cat_props; int ncatprops;           /* categories' instance property lists (class_getProperty) */
    IMP cxx_destruct;
};

#define FAST_DATA_MASK 0x00007ffffffffff8ull
#define RO_META 0x1
#define SMALL_METHOD_LIST 0x80000000u
#define ENTSIZE_MASK 0x0000fffcu

static pthread_mutex_t rt_lock = PTHREAD_MUTEX_INITIALIZER;   /* metadata, caches */
static pthread_mutex_t rr_lock = PTHREAD_MUTEX_INITIALIZER;   /* refcounts, weak table */
static pthread_mutex_t init_lock;                              /* recursive, +initialize */

static struct class_ro_t *ro_of(Class c) { return (struct class_ro_t *)(c->data & FAST_DATA_MASK); }
static const char *class_name_of(Class c);
static const char *cls_name(Class c) { const char *n = c ? class_name_of(c) : "nil"; return n ? n : "<unnamed>"; }
static int is_meta(Class c) { return ro_of(c)->flags & RO_META; }

/* ================= generic string/pointer hash maps ================= */
static uint64_t hash_str(const char *s) { uint64_t h = 1469598103934665603ull; while (*s) h = (h ^ (uint8_t)*s++) * 1099511628211ull; return h; }
static uint64_t hash_ptr(const void *p) { uint64_t x = (uintptr_t)p; x ^= x >> 33; x *= 0xff51afd7ed558ccdull; x ^= x >> 33; return x; }

struct strmap { const char **k; void **v; size_t cap, n; };
static void **strmap_slot(struct strmap *m, const char *key, int create) {
    if (create && m->n * 2 >= m->cap) {
        struct strmap o = *m; m->cap = o.cap ? o.cap * 2 : 256; m->n = 0;
        m->k = calloc(m->cap, sizeof *m->k); m->v = calloc(m->cap, sizeof *m->v);
        for (size_t i = 0; i < o.cap; i++) if (o.k[i]) *strmap_slot(m, o.k[i], 1) = o.v[i];
        free(o.k); free(o.v);
    }
    if (!m->cap) return NULL;
    size_t j = hash_str(key) & (m->cap - 1);
    while (m->k[j]) { if (!strcmp(m->k[j], key)) return &m->v[j]; j = (j + 1) & (m->cap - 1); }
    if (!create) return NULL;
    m->k[j] = key; m->n++; return &m->v[j];
}

/* ================= selectors ================= */
static struct strmap selectors;
static SEL sel_intern(const char *s) {
    void **slot = strmap_slot(&selectors, s, 1);
    if (!*slot) *slot = (void *)s;
    return *slot;
}
SEL sel_registerName(const char *s) {
    pthread_mutex_lock(&rt_lock);
    void **slot = strmap_slot(&selectors, s, 0);
    SEL r = slot ? *slot : sel_intern(strdup(s));
    pthread_mutex_unlock(&rt_lock);
    return r;
}
const char *sel_getName(SEL s) { return s ? s : "<null selector>"; }
int sel_isEqual(SEL a, SEL b) { return a == b; }

/* ================= class registry ================= */
static struct strmap classes, protocols;
static struct rt_class *R(Class c) { return c->rt; }

static struct rt_class *rt_attach(Class c, Class nonmeta) {
    if (!c->rt) { c->rt = calloc(1, sizeof *c->rt); c->rt->cls = c; }
    c->rt->nonmeta = nonmeta; c->rt->is_meta = is_meta(c);
    return c->rt;
}

/* ================= method lists ================= */
static int32_t rel32(const void *f) { int32_t v; memcpy(&v, f, 4); return v; }
static uint8_t *m_entry(const struct method_list_t *ml, uint32_t i) { return (uint8_t *)(ml + 1) + i * (ml->entsize_flags & ENTSIZE_MASK); }
static SEL m_name(const struct method_list_t *ml, uint32_t i) {
    const uint8_t *e = m_entry(ml, i);
    if (ml->entsize_flags & SMALL_METHOD_LIST) return *(SEL *)(e + rel32(e));
    return ((const struct method_t *)e)->name;
}
static IMP m_imp(const struct method_list_t *ml, uint32_t i) {
    const uint8_t *e = m_entry(ml, i);
    if (ml->entsize_flags & SMALL_METHOD_LIST) return (IMP)(e + 8 + rel32(e + 8));
    return ((const struct method_t *)e)->imp;
}
static void intern_method_list(struct method_list_t *ml) {
    if (!ml || (ml->entsize_flags & SMALL_METHOD_LIST)) return;    /* small lists reference selrefs */
    for (uint32_t i = 0; i < ml->count; i++) { struct method_t *m = (void *)m_entry(ml, i); m->name = sel_intern(m->name); }
}
static IMP find_in_list(const struct method_list_t *ml, SEL sel) {
    if (!ml) return NULL;
    for (uint32_t i = 0; i < ml->count; i++) if (m_name(ml, i) == sel) return m_imp(ml, i);
    return NULL;
}
static IMP find_own(Class c, SEL sel) {
    struct rt_class *r = R(c);
    if (r) for (struct rt_method *m = r->methods; m; m = m->next) if (m->name == sel) return m->imp;
    if (r) for (int i = r->ncat - 1; i >= 0; i--) { IMP p = find_in_list(r->cat_lists[i], sel); if (p) return p; }
    return find_in_list(ro_of(c)->base_methods, sel);
}

/* ================= method cache ================= */
struct centry { Class cls; SEL sel; IMP imp; };
static struct centry *cache; static size_t cache_cap, cache_n;
static size_t chash(Class c, SEL s) { return (hash_ptr(c) ^ hash_ptr(s)) & (cache_cap - 1); }
static void cache_put(Class c, SEL s, IMP imp) {
    if (cache_n * 2 >= cache_cap) {
        size_t ocap = cache_cap; struct centry *old = cache;
        cache_cap = ocap ? ocap * 2 : 4096; cache = calloc(cache_cap, sizeof *cache); cache_n = 0;
        for (size_t i = 0; i < ocap; i++) if (old[i].cls) cache_put(old[i].cls, old[i].sel, old[i].imp);
        free(old);
    }
    size_t j = chash(c, s); while (cache[j].cls) j = (j + 1) & (cache_cap - 1);
    cache[j] = (struct centry){ c, s, imp }; cache_n++;
}
static IMP cache_get(Class c, SEL s) {
    if (!cache_cap) return NULL;
    for (size_t j = chash(c, s); cache[j].cls; j = (j + 1) & (cache_cap - 1))
        if (cache[j].cls == c && cache[j].sel == s) return cache[j].imp;
    return NULL;
}
static void cache_flush(void) { if (cache) memset(cache, 0, cache_cap * sizeof *cache); cache_n = 0; }

static IMP lookup_nofail(Class cls, SEL sel) {
    pthread_mutex_lock(&rt_lock);
    IMP imp = cache_get(cls, sel);
    if (!imp) {
        for (Class c = cls; c && !imp; c = c->superclass) imp = find_own(c, sel);
        if (imp) cache_put(cls, sel, imp);
    }
    pthread_mutex_unlock(&rt_lock);
    return imp;
}

/* ================= +initialize ================= */
static SEL s_initialize, s_load, s_alloc, s_init, s_new, s_retain, s_release, s_autorelease, s_dealloc,
           s_class, s_isKindOfClass, s_respondsToSelector, s_copy, s_mutableCopy, s_cxx_destruct;
static void ensure_initialized(Class c) {
    if (!c || !c->rt || __atomic_load_n(&c->rt->init_state, __ATOMIC_ACQUIRE) == 2) return;
    pthread_mutex_lock(&init_lock);
    if (c->rt->init_state == 0) {
        c->rt->init_state = 1;
        ensure_initialized(c->superclass);
        IMP imp = lookup_nofail(c->isa, s_initialize);
        if (imp) ((void (*)(Class, SEL))imp)(c, s_initialize);
        __atomic_store_n(&c->rt->init_state, 2, __ATOMIC_RELEASE);
    }
    pthread_mutex_unlock(&init_lock);           /* state 1 here = re-entrant call on this thread */
}

/* called from assembly trampolines */
/* +resolveInstanceMethod: / +resolveClassMethod: (dynamic method resolution, e.g. Core Data's @NSManaged
 * accessors): asked once when a lookup misses; the class may class_addMethod the selector and return YES. */
static __thread int resolve_depth;
static int try_resolve(Class cls, SEL sel) {
    static SEL s_rim, s_rcm;
    if (!s_rim) { s_rim = sel_registerName("resolveInstanceMethod:"); s_rcm = sel_registerName("resolveClassMethod:"); }
    if (!cls || !cls->rt || !cls->rt->nonmeta || resolve_depth > 4) return 0;
    int meta = is_meta(cls);
    SEL rs = meta ? s_rcm : s_rim;
    if (sel == rs || sel == s_initialize) return 0;
    Class target = meta ? cls->rt->nonmeta : cls;
    IMP r = lookup_nofail(target->isa, rs);
    if (!r) return 0;
    resolve_depth++;
    int ok = ((unsigned char (*)(Class, SEL, SEL))r)(target, rs, sel) & 1;
    resolve_depth--;
    return ok && lookup_nofail(cls, sel) != NULL;
}

/* message forwarding: a lookup miss returns _objc_msgForward(_stret), which captures the argument
 * registers in a frame and calls the handler Foundation installs (forwardingTargetForSelector:,
 * methodSignatureForSelector:/forwardInvocation:, doesNotRecognizeSelector:). */
void rt_msgForward(void); void rt_msgForward_stret(void);
static IMP lookup_or_forward(id self, Class cls, SEL sel, int stret) {
    if (cls->rt && cls->rt->nonmeta && cls->rt->nonmeta->rt->init_state != 2) ensure_initialized(cls->rt->nonmeta);
    IMP imp = lookup_nofail(cls, sel);
    if (!imp && try_resolve(cls, sel)) imp = lookup_nofail(cls, sel);
    if (!imp) imp = stret ? (IMP)rt_msgForward_stret : (IMP)rt_msgForward;
    return imp;
}
IMP objc_rt_lookup(id self, Class cls, SEL sel) { return lookup_or_forward(self, cls, sel, 0); }
IMP objc_rt_lookup_stret(id self, Class cls, SEL sel) { return lookup_or_forward(self, cls, sel, 1); }

/* frame layout shared with Foundation (isim_objc_frame in <objc/isim_internal.h>) */
enum { FWD_STRET_SLOT = 0xf0 / 8 };
typedef id (*fwd_handler_fn)(id self, SEL sel, uint64_t *frame);
static fwd_handler_fn fwd_handler;
void isim_objc_set_forward_handler(fwd_handler_fn h) { fwd_handler = h; }
id objc_forward_dispatch(uint64_t *frame) {
    int stret = frame[FWD_STRET_SLOT] != 0;
    id self = (id)frame[stret ? 1 : 0]; SEL sel = (SEL)frame[stret ? 2 : 1];
    if (fwd_handler && self) return fwd_handler(self, sel, frame);
    if (!self) return NULL;
    Class cls = self->isa;
    fflush(NULL);
    fprintf(stderr, "isim objc: FATAL: %c[%s %s]: unrecognized selector sent to %s %p\n",
            is_meta(cls) ? '+' : '-', cls_name(cls), sel, is_meta(cls) ? "class" : "instance", (void *)self);
    extern void isim_print_backtrace(void *frame);
    isim_print_backtrace(__builtin_frame_address(0));
    signal(SIGABRT, SIG_DFL);
    abort();
}

#define SAVE_ARGS \
    "  push %rbp\n  .cfi_def_cfa_offset 16\n  .cfi_offset %rbp, -16\n  mov %rsp, %rbp\n  .cfi_def_cfa_register %rbp\n  sub $0xc0, %rsp\n" \
    "  movdqa %xmm0, 0x00(%rsp)\n  movdqa %xmm1, 0x10(%rsp)\n  movdqa %xmm2, 0x20(%rsp)\n  movdqa %xmm3, 0x30(%rsp)\n" \
    "  movdqa %xmm4, 0x40(%rsp)\n  movdqa %xmm5, 0x50(%rsp)\n  movdqa %xmm6, 0x60(%rsp)\n  movdqa %xmm7, 0x70(%rsp)\n" \
    "  mov %rdi, 0x80(%rsp)\n  mov %rsi, 0x88(%rsp)\n  mov %rdx, 0x90(%rsp)\n  mov %rcx, 0x98(%rsp)\n" \
    "  mov %r8, 0xa0(%rsp)\n  mov %r9, 0xa8(%rsp)\n  mov %rax, 0xb0(%rsp)\n"
#define RESTORE_AND_JUMP \
    "  mov %rax, %r11\n" \
    "  movdqa 0x00(%rsp), %xmm0\n  movdqa 0x10(%rsp), %xmm1\n  movdqa 0x20(%rsp), %xmm2\n  movdqa 0x30(%rsp), %xmm3\n" \
    "  movdqa 0x40(%rsp), %xmm4\n  movdqa 0x50(%rsp), %xmm5\n  movdqa 0x60(%rsp), %xmm6\n  movdqa 0x70(%rsp), %xmm7\n" \
    "  mov 0x80(%rsp), %rdi\n  mov 0x88(%rsp), %rsi\n  mov 0x90(%rsp), %rdx\n  mov 0x98(%rsp), %rcx\n" \
    "  mov 0xa0(%rsp), %r8\n  mov 0xa8(%rsp), %r9\n  mov 0xb0(%rsp), %rax\n" \
    "  mov %rbp, %rsp\n  pop %rbp\n  .cfi_def_cfa %rsp, 8\n  jmp *%r11\n"

/* _objc_msgForward(_stret): save the argument registers into an isim_objc_frame (0x100 bytes on the
 * stack), call objc_forward_dispatch; a non-nil result is a new receiver (forwardingTargetForSelector:)
 * to which the original message is re-sent with the untouched stack arguments, else the frame's
 * return registers are loaded and we return to the caller. */
#define FORWARD(name, selfslot, resend, stret) \
    ".globl " name "\n.type " name ",@function\n" name ":\n  .cfi_startproc\n" \
    "  push %rbp\n  .cfi_def_cfa_offset 16\n  .cfi_offset %rbp, -16\n  mov %rsp, %rbp\n  .cfi_def_cfa_register %rbp\n  sub $0x100, %rsp\n" \
    "  mov %rdi, 0x00(%rsp)\n  mov %rsi, 0x08(%rsp)\n  mov %rdx, 0x10(%rsp)\n  mov %rcx, 0x18(%rsp)\n  mov %r8, 0x20(%rsp)\n  mov %r9, 0x28(%rsp)\n" \
    "  movdqu %xmm0, 0x30(%rsp)\n  movdqu %xmm1, 0x40(%rsp)\n  movdqu %xmm2, 0x50(%rsp)\n  movdqu %xmm3, 0x60(%rsp)\n" \
    "  movdqu %xmm4, 0x70(%rsp)\n  movdqu %xmm5, 0x80(%rsp)\n  movdqu %xmm6, 0x90(%rsp)\n  movdqu %xmm7, 0xa0(%rsp)\n" \
    "  lea 16(%rbp), %r10\n  mov %r10, 0xb0(%rsp)\n  mov %rax, 0xb8(%rsp)\n  xor %r10d, %r10d\n" \
    "  mov %r10, 0xc0(%rsp)\n  mov %r10, 0xc8(%rsp)\n  mov %r10, 0xd0(%rsp)\n  mov %r10, 0xd8(%rsp)\n  mov %r10, 0xe0(%rsp)\n  mov %r10, 0xe8(%rsp)\n" \
    "  movq " stret ", 0xf0(%rsp)\n  mov %r10, 0xf8(%rsp)\n" \
    "  mov %rsp, %rdi\n  call objc_forward_dispatch\n  test %rax, %rax\n  jnz 7f\n" \
    "  mov 0xc0(%rsp), %rax\n  mov 0xc8(%rsp), %rdx\n  movdqu 0xd0(%rsp), %xmm0\n  movdqu 0xe0(%rsp), %xmm1\n" \
    "  leave\n  .cfi_remember_state\n  .cfi_def_cfa %rsp, 8\n  ret\n  .cfi_restore_state\n" \
    "7:\n  mov %rax, " selfslot "(%rsp)\n" \
    "  movdqu 0x30(%rsp), %xmm0\n  movdqu 0x40(%rsp), %xmm1\n  movdqu 0x50(%rsp), %xmm2\n  movdqu 0x60(%rsp), %xmm3\n" \
    "  movdqu 0x70(%rsp), %xmm4\n  movdqu 0x80(%rsp), %xmm5\n  movdqu 0x90(%rsp), %xmm6\n  movdqu 0xa0(%rsp), %xmm7\n" \
    "  mov 0x00(%rsp), %rdi\n  mov 0x08(%rsp), %rsi\n  mov 0x10(%rsp), %rdx\n  mov 0x18(%rsp), %rcx\n  mov 0x20(%rsp), %r8\n  mov 0x28(%rsp), %r9\n" \
    "  mov 0xb8(%rsp), %rax\n  leave\n  .cfi_def_cfa %rsp, 8\n  jmp " resend "\n  .cfi_endproc\n"

__asm__(
    ".text\n"
    /* id objc_msgSend(id self, SEL op, ...) */
    ".globl rt_msgSend\n.type rt_msgSend,@function\nrt_msgSend:\n  .cfi_startproc\n"
    "  test %rdi, %rdi\n  jz 1f\n" SAVE_ARGS
    "  mov %rsi, %rdx\n  mov (%rdi), %rsi\n  call objc_rt_lookup\n" RESTORE_AND_JUMP
    "1:\n  xor %eax, %eax\n  xor %edx, %edx\n  pxor %xmm0, %xmm0\n  pxor %xmm1, %xmm1\n  ret\n  .cfi_endproc\n"
    /* objc_msgSendSuper2(struct objc_super *{receiver, current_class}, SEL, ...) */
    ".globl rt_msgSendSuper2\n.type rt_msgSendSuper2,@function\nrt_msgSendSuper2:\n  .cfi_startproc\n" SAVE_ARGS
    "  mov (%rdi), %r10\n  mov %r10, 0x80(%rsp)\n"
    "  mov %rsi, %rdx\n  mov 8(%rdi), %rsi\n  mov 8(%rsi), %rsi\n  mov %r10, %rdi\n  call objc_rt_lookup\n" RESTORE_AND_JUMP "  .cfi_endproc\n"
    /* objc_msgSendSuper(struct objc_super *{receiver, class}, SEL, ...) */
    ".globl rt_msgSendSuper\n.type rt_msgSendSuper,@function\nrt_msgSendSuper:\n  .cfi_startproc\n" SAVE_ARGS
    "  mov (%rdi), %r10\n  mov %r10, 0x80(%rsp)\n"
    "  mov %rsi, %rdx\n  mov 8(%rdi), %rsi\n  mov %r10, %rdi\n  call objc_rt_lookup\n" RESTORE_AND_JUMP "  .cfi_endproc\n"
    /* void objc_msgSend_stret(void *ret, id self, SEL op, ...) */
    ".globl rt_msgSend_stret\n.type rt_msgSend_stret,@function\nrt_msgSend_stret:\n  .cfi_startproc\n"
    "  test %rsi, %rsi\n  jz 2f\n" SAVE_ARGS
    "  mov %rsi, %rdi\n  mov (%rsi), %rsi\n  call objc_rt_lookup_stret\n" RESTORE_AND_JUMP
    "2:\n  mov %rdi, %rax\n  ret\n  .cfi_endproc\n"
    /* void objc_msgSendSuper2_stret(void *ret, struct objc_super *, SEL, ...) */
    ".globl rt_msgSendSuper2_stret\n.type rt_msgSendSuper2_stret,@function\nrt_msgSendSuper2_stret:\n  .cfi_startproc\n" SAVE_ARGS
    "  mov (%rsi), %r10\n  mov %r10, 0x88(%rsp)\n"
    "  mov 8(%rsi), %rsi\n  mov 8(%rsi), %rsi\n  mov %r10, %rdi\n  call objc_rt_lookup_stret\n" RESTORE_AND_JUMP "  .cfi_endproc\n"
    FORWARD("rt_msgForward", "0x00", "rt_msgSend", "$0") FORWARD("rt_msgForward_stret", "0x08", "rt_msgSend_stret", "$1")
    /* void isim_objc_call_frame(isim_objc_call *c): call c->fn with the given argument registers and stack words */
    ".globl isim_objc_call_frame\n.type isim_objc_call_frame,@function\nisim_objc_call_frame:\n  .cfi_startproc\n"
    "  push %rbp\n  .cfi_def_cfa_offset 16\n  .cfi_offset %rbp, -16\n  mov %rsp, %rbp\n  .cfi_def_cfa_register %rbp\n"
    "  push %rbx\n  .cfi_offset %rbx, -24\n  push %r12\n  .cfi_offset %r12, -32\n  mov %rdi, %rbx\n"
    "  mov 0xc0(%rbx), %rcx\n  lea 15(,%rcx,8), %rax\n  and $-16, %rax\n  sub %rax, %rsp\n"
    "  mov 0xb8(%rbx), %rsi\n  xor %edx, %edx\n"
    "5:\n  cmp %rcx, %rdx\n  jae 6f\n  mov (%rsi,%rdx,8), %r8\n  mov %r8, (%rsp,%rdx,8)\n  inc %rdx\n  jmp 5b\n"
    "6:\n  movdqu 0x38(%rbx), %xmm0\n  movdqu 0x48(%rbx), %xmm1\n  movdqu 0x58(%rbx), %xmm2\n  movdqu 0x68(%rbx), %xmm3\n"
    "  movdqu 0x78(%rbx), %xmm4\n  movdqu 0x88(%rbx), %xmm5\n  movdqu 0x98(%rbx), %xmm6\n  movdqu 0xa8(%rbx), %xmm7\n"
    "  mov 0x10(%rbx), %rsi\n  mov 0x18(%rbx), %rdx\n  mov 0x20(%rbx), %rcx\n  mov 0x28(%rbx), %r8\n  mov 0x30(%rbx), %r9\n"
    "  mov 0x08(%rbx), %rdi\n  mov 0xc8(%rbx), %rax\n  call *0x00(%rbx)\n"
    "  mov %rax, 0xd0(%rbx)\n  mov %rdx, 0xd8(%rbx)\n  movdqu %xmm0, 0xe0(%rbx)\n  movdqu %xmm1, 0xf0(%rbx)\n"
    "  lea -16(%rbp), %rsp\n  pop %r12\n  pop %rbx\n  pop %rbp\n  .cfi_def_cfa %rsp, 8\n  ret\n  .cfi_endproc\n"
);
void rt_msgSend(void); void rt_msgSendSuper2(void); void rt_msgSendSuper(void);
void rt_msgSend_stret(void); void rt_msgSendSuper2_stret(void); void isim_objc_call_frame(void *c);

static id send0(id self, SEL sel) { return self ? ((id (*)(id, SEL))objc_rt_lookup(self, self->isa, sel))(self, sel) : NULL; }
static id send1(id self, SEL sel, void *a) { return self ? ((id (*)(id, SEL, void *))objc_rt_lookup(self, self->isa, sel))(self, sel, a) : NULL; }

/* hooks installed by the Swift runtime */
typedef int (*hook_getClass)(const char *name, Class *out);
typedef int (*hook_getImageName)(Class cls, const char **out);
typedef const char *(*hook_lazyNamer)(Class cls);
/* Like libobjc, hooks start out as default implementations so chained hooks can always call "old". */
Class objc_lookUpClass(const char *name);
const char *isim_image_path_for_address(const void *addr);
static int default_getclass(const char *name, Class *out) { *out = objc_lookUpClass(name); return *out != NULL; }
static int default_imagename(Class cls, const char **out) { *out = cls ? isim_image_path_for_address(cls) : NULL; return *out != NULL; }
static const char *default_lazynamer(Class cls) { return NULL; }
static hook_getClass getclass_hook = default_getclass;
static hook_getImageName imagename_hook = default_imagename;
static hook_lazyNamer lazynamer_hook = default_lazynamer;

/* Swift may emit class_ro_t with a NULL name and supply it lazily through a hook. */
static const char *class_name_of(Class c) {
    const char *n = ro_of(c)->name;
    if (!n) n = lazynamer_hook(c);
    return n;
}

/* ================= realization / registration ================= */
static void realize(Class c);

static void slide_ivars(Class c) {
    Class sup = c->superclass;
    if (!sup) return;
    struct class_ro_t *ro = ro_of(c), *sro = ro_of(sup);
    uint32_t start = (sro->instance_size + 7) & ~7u;
    if (start <= ro->instance_start) return;
    uint32_t diff = start - ro->instance_start;
    if (ro->ivars) {
        uint32_t es = ro->ivars->entsize_flags & ~3u;
        for (uint32_t i = 0; i < ro->ivars->count; i++) {
            struct ivar_t *iv = (void *)((uint8_t *)(ro->ivars + 1) + i * es);
            if (iv->offset) *iv->offset += diff;           /* 32-bit write; upper half (x86_64) stays 0 */
        }
    }
    if (isim_verbose) fprintf(stderr, "isim objc: slid ivars of %s by %u (super %s size %u)\n", ro->name, diff, sro->name, sro->instance_size);
    ro->instance_start += diff;
    ro->instance_size += diff;
}

void *_NSConcreteStackBlock[32], *_NSConcreteMallocBlock[32], *_NSConcreteGlobalBlock[32];
/* Like CoreFoundation: turn libclosure's isa storage into real class objects once Foundation defines them. */
static void classify_block_storage(Class c, const char *n) {
    void **dst = NULL;
    if (!strcmp(n, "__NSStackBlock__")) dst = _NSConcreteStackBlock;
    else if (!strcmp(n, "__NSMallocBlock__")) dst = _NSConcreteMallocBlock;
    else if (!strcmp(n, "__NSGlobalBlock__")) dst = _NSConcreteGlobalBlock;
    if (dst) memcpy(dst, c, sizeof(struct objc_class));
}

static void realize(Class c) {
    if (!c || (c->rt && c->rt->realized)) return;
    rt_attach(c, c); rt_attach(c->isa, c);
    realize(c->superclass);
    slide_ivars(c);
    intern_method_list(ro_of(c)->base_methods);
    intern_method_list(ro_of(c->isa)->base_methods);
    if (c->isa->superclass && !c->isa->superclass->rt) rt_attach(c->isa->superclass, c->isa->superclass); /* root meta -> root class */
    c->rt->cxx_destruct = find_in_list(ro_of(c)->base_methods, s_cxx_destruct);
    c->rt->realized = c->isa->rt->realized = 1;
    const char *name = class_name_of(c);
    if (name) { *strmap_slot(&classes, name, 1) = c; classify_block_storage(c, name); }
}

/* Swift classes whose layout is computed at run time (e.g. stored properties of resilient types):
 * the Swift runtime fills in the instance size and ivar offsets, then hands the class to ObjC. */
Class _objc_realizeClassFromSwift(Class cls, void *previously) {
    (void)previously;
    realize(cls);
    return cls;
}

static void attach_category(struct category_t *cat) {
    Class c = cat->cls;
    if (!c) { fprintf(stderr, "isim objc: warning: category %s on missing class ignored\n", cat->name); return; }
    realize(c);
    struct { Class k; struct method_list_t *ml; } targets[2] = { { c, cat->inst }, { c->isa, cat->cls_methods } };
    for (int t = 0; t < 2; t++) {
        if (!targets[t].ml) continue;
        intern_method_list(targets[t].ml);
        struct rt_class *r = R(targets[t].k);
        if (r->ncat == r->catcap) { r->catcap = r->catcap ? r->catcap * 2 : 4; r->cat_lists = realloc(r->cat_lists, r->catcap * sizeof *r->cat_lists); }
        r->cat_lists[r->ncat++] = targets[t].ml;
    }
    if (cat->protocols) {
        struct rt_class *r = R(c);
        r->cat_protos = realloc(r->cat_protos, (r->ncatp + 1) * sizeof *r->cat_protos);
        r->cat_protos[r->ncatp++] = cat->protocols;
    }
    if (cat->inst_props) {
        struct rt_class *r = R(c);
        r->cat_props = realloc(r->cat_props, (r->ncatprops + 1) * sizeof *r->cat_props);
        r->cat_props[r->ncatprops++] = cat->inst_props;
    }
}

/* Host-defined class for Protocol objects (Apple's lives in libobjc). Messages to it abort. */
static struct class_ro_t protocol_meta_ro = { RO_META, 40, 40, 0, NULL, "Protocol", NULL, NULL, NULL, NULL, NULL };
static struct class_ro_t protocol_ro = { 0, 8, 8, 0, NULL, "Protocol", NULL, NULL, NULL, NULL, NULL };
static struct objc_class protocol_meta, protocol_class;

static void protocol_class_init(void) {
    protocol_meta = (struct objc_class){ &protocol_meta, NULL, NULL, NULL, (uintptr_t)&protocol_meta_ro };
    protocol_class = (struct objc_class){ &protocol_meta, NULL, NULL, NULL, (uintptr_t)&protocol_ro };
    rt_attach(&protocol_class, &protocol_class)->realized = 1;
    rt_attach(&protocol_meta, &protocol_class)->realized = 1;
    protocol_class.rt->init_state = protocol_meta.rt->init_state = 2;
}

static void rt_init_once(void) {
    pthread_mutexattr_t a; pthread_mutexattr_init(&a); pthread_mutexattr_settype(&a, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&init_lock, &a);
    s_initialize = sel_intern("initialize"); s_load = sel_intern("load"); s_alloc = sel_intern("alloc");
    s_init = sel_intern("init"); s_new = sel_intern("new"); s_retain = sel_intern("retain");
    s_release = sel_intern("release"); s_autorelease = sel_intern("autorelease"); s_dealloc = sel_intern("dealloc");
    s_class = sel_intern("class"); s_isKindOfClass = sel_intern("isKindOfClass:");
    s_respondsToSelector = sel_intern("respondsToSelector:"); s_copy = sel_intern("copy");
    s_mutableCopy = sel_intern("mutableCopy"); s_cxx_destruct = sel_intern(".cxx_destruct");
    protocol_class_init();
}

void objc_rt_map_image(const struct objc_image *img) {
    static pthread_once_t once = PTHREAD_ONCE_INIT;
    pthread_once(&once, rt_init_once);
    pthread_mutex_lock(&rt_lock);
    uint64_t n;
    SEL *selrefs = img->find_section(img, "__objc_selrefs", &n);
    for (uint64_t i = 0; i < n / 8; i++) selrefs[i] = sel_intern(selrefs[i]);

    struct protocol_t **protos = img->find_section(img, "__objc_protolist", &n);
    for (uint64_t i = 0; i < n / 8; i++) {
        struct protocol_t *p = protos[i];
        void **slot = strmap_slot(&protocols, p->name, 1);
        if (!*slot) *slot = p;
        p->isa = &protocol_class;
        intern_method_list(p->inst); intern_method_list(p->cls); intern_method_list(p->opt_inst); intern_method_list(p->opt_cls);
    }
    struct protocol_t **prefs = img->find_section(img, "__objc_protorefs", &n);
    for (uint64_t i = 0; i < n / 8; i++) { void **slot = strmap_slot(&protocols, prefs[i]->name, 0); if (slot) prefs[i] = *slot; }

    Class *cl = img->find_section(img, "__objc_classlist", &n);
    for (uint64_t i = 0; i < n / 8; i++) realize(cl[i]);
    struct category_t **cats = img->find_section(img, "__objc_catlist", &n);
    for (uint64_t i = 0; i < n / 8; i++) attach_category(cats[i]);
    if (n) cache_flush();
    if (isim_verbose) fprintf(stderr, "isim objc: %s: %lu classes, %lu categories\n", img->name,
                              (unsigned long)(img->find_section(img, "__objc_classlist", &n), n / 8),
                              (unsigned long)(img->find_section(img, "__objc_catlist", &n), n / 8));
    pthread_mutex_unlock(&rt_lock);
}

void objc_rt_load_image(const struct objc_image *img) {
    uint64_t n;
    Class *nl = img->find_section(img, "__objc_nlclslist", &n);
    for (uint64_t i = 0; i < n / 8; i++) {
        IMP load = find_in_list(ro_of(nl[i]->isa)->base_methods, s_load);
        if (load) { ensure_initialized(nl[i]->superclass); ((void (*)(Class, SEL))load)(nl[i], s_load); }
    }
    struct category_t **nc = img->find_section(img, "__objc_nlcatlist", &n);
    for (uint64_t i = 0; i < n / 8; i++) {
        IMP load = find_in_list(nc[i]->cls_methods, s_load);
        if (load) ((void (*)(Class, SEL))load)(nc[i]->cls, s_load);
    }
}

/* ================= public introspection API ================= */
Class objc_lookUpClass(const char *name) {
    pthread_mutex_lock(&rt_lock);
    void **slot = strmap_slot(&classes, name, 0);
    pthread_mutex_unlock(&rt_lock);
    return slot ? *slot : NULL;
}
Class objc_getClass(const char *name) {
    if (!name) return NULL;
    Class c = objc_lookUpClass(name);
    if (!c) getclass_hook(name, &c);      /* e.g. Swift mangled names, resolved by the Swift runtime */
    return c;
}
Class objc_getMetaClass(const char *name) { Class c = objc_getClass(name); return c ? c->isa : NULL; }
const char *class_getName(Class c) { return cls_name(c); }
Class class_getSuperclass(Class c) { return c ? c->superclass : NULL; }
int class_isMetaClass(Class c) { return c && is_meta(c); }
size_t class_getInstanceSize(Class c) { return c ? ro_of(c)->instance_size : 0; }
Class object_getClass(id o) { return o ? o->isa : NULL; }
Class object_setClass(id o, Class c) { Class old = o ? o->isa : NULL; if (o) o->isa = c; return old; }
const char *object_getClassName(id o) { return o ? cls_name(o->isa) : "nil"; }
int class_respondsToSelector(Class c, SEL sel) { return c && sel && (lookup_nofail(c, sel) != NULL || try_resolve(c, sel)); }
IMP class_getMethodImplementation(Class c, SEL sel) {
    if (!c || !sel) return NULL;
    IMP imp = lookup_nofail(c, sel);
    if (!imp && try_resolve(c, sel)) imp = lookup_nofail(c, sel);
    return imp ? imp : (IMP)rt_msgForward;             /* like libobjc: unknown selectors map to _objc_msgForward */
}
IMP class_getMethodImplementation_stret(Class c, SEL sel) {
    IMP imp = class_getMethodImplementation(c, sel);
    return imp == (IMP)rt_msgForward ? (IMP)rt_msgForward_stret : imp;
}

/* ================= properties (declared @property / Swift @objc metadata, incl. categories) ================= */
struct property_t { const char *name, *attributes; };
struct property_list_t { uint32_t entsize, count; };
static struct property_t *prop_in_list(void *list, const char *name) {
    struct property_list_t *pl = list;
    if (!pl) return NULL;
    for (uint32_t i = 0; i < pl->count; i++) {
        struct property_t *p = (struct property_t *)((uint8_t *)(pl + 1) + i * pl->entsize);
        if (p->name && !strcmp(p->name, name)) return p;
    }
    return NULL;
}
struct property_t *class_getProperty(Class cls, const char *name) {
    if (!name) return NULL;
    for (Class c = cls; c; c = c->superclass) {
        struct rt_class *r = R(c);
        for (int i = r ? r->ncatprops - 1 : -1; i >= 0; i--) { struct property_t *p = prop_in_list(r->cat_props[i], name); if (p) return p; }
        struct property_t *p = prop_in_list(ro_of(c)->base_properties, name);
        if (p) return p;
    }
    return NULL;
}
struct property_t **class_copyPropertyList(Class c, unsigned int *outCount) {
    unsigned n = 0, cap = 0; struct property_t **out = NULL;
    struct rt_class *r = c ? R(c) : NULL;
    for (int k = -1; c && k < (r ? r->ncatprops : 0); k++) {
        struct property_list_t *pl = k < 0 ? ro_of(c)->base_properties : r->cat_props[k];
        for (uint32_t i = 0; pl && i < pl->count; i++) {
            if (n + 2 > cap) { cap = cap ? cap * 2 : 16; out = realloc(out, cap * sizeof *out); }
            out[n++] = (struct property_t *)((uint8_t *)(pl + 1) + i * pl->entsize);
        }
    }
    if (out) out[n] = NULL;
    if (outCount) *outCount = n;
    return out;
}
const char *property_getName(struct property_t *p) { return p ? p->name : NULL; }
const char *property_getAttributes(struct property_t *p) { return p ? p->attributes : NULL; }
IMP class_lookupMethod_own(Class c, SEL sel) { return find_own(c, sel); }

struct protocol_t *objc_getProtocol(const char *name) {
    pthread_mutex_lock(&rt_lock); void **s = strmap_slot(&protocols, name, 0); pthread_mutex_unlock(&rt_lock);
    return s ? *s : NULL;
}
const char *protocol_getName(struct protocol_t *p) { return p ? p->name : NULL; }
static int proto_list_conforms(struct protocol_list_t *pl, const char *name, int depth);
int protocol_conformsToProtocol(struct protocol_t *p, struct protocol_t *other) {
    if (!p || !other) return 0;
    if (!strcmp(p->name, other->name)) return 1;
    return proto_list_conforms(p->protocols, other->name, 1);
}
static int proto_list_conforms(struct protocol_list_t *pl, const char *name, int depth) {
    if (!pl || depth > 16) return 0;
    for (uintptr_t i = 0; i < pl->count; i++) {
        if (!strcmp(pl->list[i]->name, name)) return 1;
        if (proto_list_conforms(pl->list[i]->protocols, name, depth + 1)) return 1;
    }
    return 0;
}
int class_conformsToProtocol(Class c, struct protocol_t *p) {
    if (!c || !p) return 0;
    if (proto_list_conforms(ro_of(c)->base_protocols, p->name, 0)) return 1;
    struct rt_class *r = R(c);
    for (int i = 0; r && i < r->ncatp; i++) if (proto_list_conforms(r->cat_protos[i], p->name, 0)) return 1;
    return 0;
}

/* ================= methods, ivars, hooks (APIs used by the Swift runtime) ================= */
static const char *types_in_list(const struct method_list_t *ml, SEL sel) {
    if (!ml) return NULL;
    for (uint32_t i = 0; i < ml->count; i++) {
        if (m_name(ml, i) != sel) continue;
        const uint8_t *e = m_entry(ml, i);
        if (ml->entsize_flags & SMALL_METHOD_LIST) return (const char *)(e + 4 + rel32(e + 4));
        return ((const struct method_t *)e)->types;
    }
    return NULL;
}
struct objc_method_description { SEL name; const char *types; };
static const char *proto_method_types(struct protocol_t *p, SEL sel, int req, int inst, int depth) {
    if (!p || depth > 16) return NULL;
    const char *t = types_in_list(req ? (inst ? p->inst : p->cls) : (inst ? p->opt_inst : p->opt_cls), sel);
    for (uintptr_t i = 0; !t && p->protocols && i < p->protocols->count; i++) t = proto_method_types(p->protocols->list[i], sel, req, inst, depth + 1);
    return t;
}
struct objc_method_description protocol_getMethodDescription(struct protocol_t *p, SEL sel, int req, int inst) {
    const char *t = sel ? proto_method_types(p, sel, req & 1, inst & 1, 0) : NULL;
    return (struct objc_method_description){ t ? sel : NULL, t };
}
static struct rt_method *method_for(Class cls, SEL sel, int create_on_owner) {
    for (Class c = cls; c; c = c->superclass) {
        struct rt_class *r = R(c);
        if (!r) continue;
        for (struct rt_method *m = r->methods; m; m = m->next) if (m->name == sel) return m;
        IMP imp = find_own(c, sel);
        if (!imp) continue;
        /* materialize a Method object on the owning class; it now takes precedence over the metadata entry */
        struct rt_method *m = calloc(1, sizeof *m);
        m->name = sel; m->imp = imp; m->cls = c; m->next = r->methods; r->methods = m;
        m->types = types_in_list(ro_of(c)->base_methods, sel);
        for (int i = 0; !m->types && i < r->ncat; i++) m->types = types_in_list(r->cat_lists[i], sel);
        return m;
    }
    return NULL;
}
struct rt_method *class_getInstanceMethod(Class c, SEL sel) {
    if (!c || !sel) return NULL;
    pthread_mutex_lock(&rt_lock); struct rt_method *m = method_for(c, sel, 0); pthread_mutex_unlock(&rt_lock);
    return m;
}
struct rt_method *class_getClassMethod(Class c, SEL sel) { return c ? class_getInstanceMethod(c->isa, sel) : NULL; }
IMP method_getImplementation(struct rt_method *m) { return m ? m->imp : NULL; }
SEL method_getName(struct rt_method *m) { return m ? m->name : NULL; }
const char *method_getTypeEncoding(struct rt_method *m) { return m ? m->types : NULL; }
IMP method_setImplementation(struct rt_method *m, IMP imp) {
    if (!m) return NULL;
    pthread_mutex_lock(&rt_lock); IMP old = m->imp; m->imp = imp; cache_flush(); pthread_mutex_unlock(&rt_lock);
    return old;
}
void method_exchangeImplementations(struct rt_method *a, struct rt_method *b) {
    if (!a || !b) return;
    pthread_mutex_lock(&rt_lock); IMP t = a->imp; a->imp = b->imp; b->imp = t; cache_flush(); pthread_mutex_unlock(&rt_lock);
}
int class_addMethod(Class c, SEL sel, IMP imp, const char *types) {
    if (!c || !sel) return 0;
    pthread_mutex_lock(&rt_lock);
    if (!c->rt) rt_attach(c, is_meta(c) ? NULL : c);
    int exists = find_own(c, sel) != NULL;
    if (!exists) {
        struct rt_method *m = calloc(1, sizeof *m);
        m->name = sel; m->imp = imp; m->types = types ? strdup(types) : NULL; m->cls = c;
        m->next = c->rt->methods; c->rt->methods = m;
        cache_flush();
    }
    pthread_mutex_unlock(&rt_lock);
    return !exists;
}
Class class_setSuperclass(Class c, Class newSuper) {
    pthread_mutex_lock(&rt_lock);
    Class old = c->superclass;
    c->superclass = newSuper;
    if (newSuper) c->isa->superclass = newSuper->isa;
    cache_flush();
    pthread_mutex_unlock(&rt_lock);
    return old;
}
struct ivar_t **class_copyIvarList(Class c, unsigned int *outCount) {
    struct ivar_list_t *il = c ? ro_of(c)->ivars : NULL;
    unsigned n = il ? il->count : 0;
    if (outCount) *outCount = n;
    if (!n) return NULL;
    struct ivar_t **out = calloc(n + 1, sizeof *out);
    uint32_t es = il->entsize_flags & ~3u;
    for (unsigned i = 0; i < n; i++) out[i] = (struct ivar_t *)((uint8_t *)(il + 1) + i * es);
    return out;
}
/* every registered (realized) class; NULL-terminated, free() it */
Class *objc_copyClassList(unsigned int *outCount) {
    pthread_mutex_lock(&rt_lock);
    Class *out = calloc(classes.n + 1, sizeof *out);
    unsigned k = 0;
    for (size_t i = 0; i < classes.cap && k < classes.n; i++) if (classes.k[i] && classes.v[i]) out[k++] = classes.v[i];
    pthread_mutex_unlock(&rt_lock);
    if (outCount) *outCount = k;
    return out;
}
/* the class's own methods (metadata, categories, runtime-added); not its superclasses' (XCTest test discovery) */
struct rt_method **class_copyMethodList(Class c, unsigned int *outCount) {
    if (outCount) *outCount = 0;
    if (!c) return NULL;
    pthread_mutex_lock(&rt_lock);
    realize(c);
    struct rt_class *r = R(c);
    size_t cap = 16, n = 0;
    SEL *sels = malloc(cap * sizeof *sels);
    #define ADD_SEL(s) do { SEL _s = (s); int _dup = 0; for (size_t _i = 0; _i < n; _i++) if (sels[_i] == _s) { _dup = 1; break; } \
        if (!_dup) { if (n == cap) sels = realloc(sels, (cap *= 2) * sizeof *sels); sels[n++] = _s; } } while (0)
    if (r) for (struct rt_method *m = r->methods; m; m = m->next) if (m->cls == c) ADD_SEL(m->name);
    if (r) for (int i = 0; i < r->ncat; i++) for (uint32_t j = 0; r->cat_lists[i] && j < r->cat_lists[i]->count; j++) ADD_SEL(m_name(r->cat_lists[i], j));
    struct method_list_t *ml = ro_of(c)->base_methods;
    for (uint32_t j = 0; ml && j < ml->count; j++) ADD_SEL(m_name(ml, j));
    #undef ADD_SEL
    struct rt_method **out = n ? calloc(n + 1, sizeof *out) : NULL;
    unsigned k = 0;
    for (size_t i = 0; i < n; i++) { struct rt_method *m = method_for(c, sels[i], 0); if (m) out[k++] = m; }
    pthread_mutex_unlock(&rt_lock);
    free(sels);
    if (outCount) *outCount = k;
    return out;
}
ptrdiff_t ivar_getOffset(struct ivar_t *v) { return v && v->offset ? *v->offset : 0; }
const char *ivar_getName(struct ivar_t *v) { return v ? v->name : NULL; }
const char *ivar_getTypeEncoding(struct ivar_t *v) { return v ? v->type : NULL; }
id objc_constructInstance(Class c, void *bytes) { if (!c || !bytes) return NULL; id o = bytes; o->isa = c; return o; }
int object_isClass(id o) { return o && o->isa && is_meta(o->isa); }

/* Swift registers runtime-instantiated classes (generic/resilient class metadata) through this. */
Class objc_readClassPair(Class cls, const void *imageinfo) {
    pthread_mutex_lock(&rt_lock);
    realize(cls);
    pthread_mutex_unlock(&rt_lock);
    return cls;
}

void objc_setHook_getClass(hook_getClass h, hook_getClass *old) { *old = getclass_hook; getclass_hook = h; }
void objc_setHook_getImageName(hook_getImageName h, hook_getImageName *old) { *old = imagename_hook; imagename_hook = h; }
void objc_setHook_lazyClassNamer(hook_lazyNamer h, hook_lazyNamer *old) { *old = lazynamer_hook; lazynamer_hook = h; }
const char *class_getImageName(Class c) {
    const char *name = NULL;
    imagename_hook(c, &name);
    return name;
}

/* associated objects */
#define ASSOC_RETAIN_NONATOMIC 1
#define ASSOC_COPY_NONATOMIC 3
#define ASSOC_RETAIN 01401
#define ASSOC_COPY 01403
struct assoc { id obj; const void *key; id value; uintptr_t policy; struct assoc *next; };
static struct assoc *assoc_buckets[256];
static pthread_mutex_t assoc_lock = PTHREAD_MUTEX_INITIALIZER;
static int assoc_any;
id objc_retain(id o);
void objc_release(id o);
id objc_getAssociatedObject(id o, const void *key) {
    pthread_mutex_lock(&assoc_lock);
    id v = NULL;
    for (struct assoc *a = assoc_buckets[hash_ptr(o) & 255]; a; a = a->next) if (a->obj == o && a->key == key) { v = a->value; break; }
    pthread_mutex_unlock(&assoc_lock);
    return v;
}
void objc_setAssociatedObject(id o, const void *key, id value, uintptr_t policy) {
    int copy = (policy & 0xff) == ASSOC_COPY_NONATOMIC || policy == ASSOC_COPY, retain = (policy & 0xff) == ASSOC_RETAIN_NONATOMIC || policy == ASSOC_RETAIN;
    id nv = copy ? send0(value, s_copy) : retain ? objc_retain(value) : value;
    id old = NULL; int oldOwned = 0;
    pthread_mutex_lock(&assoc_lock);
    assoc_any = 1;
    struct assoc **pp = &assoc_buckets[hash_ptr(o) & 255];
    for (; *pp; pp = &(*pp)->next) if ((*pp)->obj == o && (*pp)->key == key) break;
    if (*pp) {
        old = (*pp)->value; oldOwned = (*pp)->policy != 0;
        if (value) { (*pp)->value = nv; (*pp)->policy = policy; }
        else { struct assoc *dead = *pp; *pp = dead->next; free(dead); }
    } else if (value) {
        struct assoc *a = calloc(1, sizeof *a); a->obj = o; a->key = key; a->value = nv; a->policy = policy;
        a->next = assoc_buckets[hash_ptr(o) & 255]; assoc_buckets[hash_ptr(o) & 255] = a;
    }
    pthread_mutex_unlock(&assoc_lock);
    if (oldOwned) objc_release(old);
}
void objc_removeAssociatedObjects(id o) {
    if (!assoc_any) return;
    struct assoc *dead = NULL;
    pthread_mutex_lock(&assoc_lock);
    for (struct assoc **pp = &assoc_buckets[hash_ptr(o) & 255]; *pp;) {
        if ((*pp)->obj == o) { struct assoc *a = *pp; *pp = a->next; a->next = dead; dead = a; } else pp = &(*pp)->next;
    }
    pthread_mutex_unlock(&assoc_lock);
    while (dead) { struct assoc *n = dead->next; if (dead->policy) objc_release(dead->value); free(dead); dead = n; }
}

/* ================= reference counting & weak references ================= */
struct rcent { id obj; long extra; int deallocating; void ***weak; int nweak, weakcap; };
static struct rcent *rc; static size_t rc_cap, rc_n;  /* open addressing with tombstones */
#define TOMB ((id)1)
static struct rcent *rc_find(id o, int create) {
    if (create && (rc_n + 1) * 2 >= rc_cap) {
        size_t ocap = rc_cap; struct rcent *old = rc;
        rc_cap = ocap ? ocap * 2 : 1024; rc = calloc(rc_cap, sizeof *rc); rc_n = 0;
        for (size_t i = 0; i < ocap; i++) if (old[i].obj && old[i].obj != TOMB) { struct rcent *e = rc_find(old[i].obj, 1); *e = old[i]; }
        free(old);
    }
    if (!rc_cap) return NULL;
    size_t j = hash_ptr(o) & (rc_cap - 1); struct rcent *tomb = NULL;
    while (rc[j].obj) {
        if (rc[j].obj == o) return &rc[j];
        if (rc[j].obj == TOMB && !tomb) tomb = &rc[j];
        j = (j + 1) & (rc_cap - 1);
    }
    if (!create) return NULL;
    struct rcent *e = tomb ? tomb : &rc[j];
    if (!tomb) rc_n++;
    memset(e, 0, sizeof *e); e->obj = o;
    return e;
}
static void rc_erase(struct rcent *e) { free(e->weak); memset(e, 0, sizeof *e); e->obj = TOMB; }

static int is_class_object(id o) { return o->isa && o->isa->data && is_meta(o->isa); }

id _objc_rootRetain(id o) {
    if (!o) return o;
    pthread_mutex_lock(&rr_lock); rc_find(o, 1)->extra++; pthread_mutex_unlock(&rr_lock);
    return o;
}
int _objc_rootReleaseWasZero(id o) {
    pthread_mutex_lock(&rr_lock);
    struct rcent *e = rc_find(o, 1);
    int dealloc = 0;
    if (e->deallocating) { pthread_mutex_unlock(&rr_lock); return 0; }
    if (e->extra > 0) e->extra--; else { e->deallocating = 1; dealloc = 1; }
    pthread_mutex_unlock(&rr_lock);
    return dealloc;
}
void _objc_rootRelease(id o) { if (o && _objc_rootReleaseWasZero(o)) send0(o, s_dealloc); }
unsigned long _objc_rootRetainCount(id o) {
    pthread_mutex_lock(&rr_lock); struct rcent *e = rc_find(o, 0); long n = e ? e->extra : 0; pthread_mutex_unlock(&rr_lock);
    return n + 1;
}
int _objc_rootIsDeallocating(id o) {
    pthread_mutex_lock(&rr_lock); struct rcent *e = rc_find(o, 0); int d = e && e->deallocating; pthread_mutex_unlock(&rr_lock);
    return d;
}

static void weak_register(id o, id *loc) {
    struct rcent *e = rc_find(o, 1);
    if (e->nweak == e->weakcap) { e->weakcap = e->weakcap ? e->weakcap * 2 : 4; e->weak = realloc(e->weak, e->weakcap * sizeof *e->weak); }
    e->weak[e->nweak++] = (void **)loc;
}
static void weak_unregister(id o, id *loc) {
    struct rcent *e = rc_find(o, 0);
    if (!e) return;
    for (int i = 0; i < e->nweak; i++) if (e->weak[i] == (void **)loc) { e->weak[i] = e->weak[--e->nweak]; return; }
}
id objc_storeWeak(id *loc, id val) {
    pthread_mutex_lock(&rr_lock);
    if (*loc) weak_unregister(*loc, loc);
    if (val) { struct rcent *e = rc_find(val, 0); if (e && e->deallocating) val = NULL; }
    if (val && !is_class_object(val)) weak_register(val, loc);
    *loc = val;
    pthread_mutex_unlock(&rr_lock);
    return val;
}
id objc_initWeak(id *loc, id val) { *loc = NULL; return objc_storeWeak(loc, val); }
void objc_destroyWeak(id *loc) { objc_storeWeak(loc, NULL); }
id objc_retain(id o);
id objc_autorelease(id o);
id objc_loadWeakRetained(id *loc) {
    pthread_mutex_lock(&rr_lock);
    id o = *loc;
    if (o) {
        struct rcent *e = rc_find(o, 0);
        if (e && e->deallocating) o = NULL;
        else if (!is_class_object(o)) rc_find(o, 1)->extra++;   /* inline root retain under the lock */
    }
    pthread_mutex_unlock(&rr_lock);
    return o;
}
id objc_loadWeak(id *loc) { return objc_autorelease(objc_loadWeakRetained(loc)); }
void objc_copyWeak(id *dst, id *src) { id o = objc_loadWeakRetained(src); objc_initWeak(dst, o); if (o) _objc_rootRelease(o); }
void objc_moveWeak(id *dst, id *src) { objc_copyWeak(dst, src); objc_destroyWeak(src); }

void *objc_destructInstance(id o) {
    if (!o) return o;
    objc_removeAssociatedObjects(o);
    for (Class c = o->isa; c; c = c->superclass)
        if (c->rt && c->rt->cxx_destruct) ((void (*)(id, SEL))c->rt->cxx_destruct)(o, s_cxx_destruct);
    pthread_mutex_lock(&rr_lock);
    struct rcent *e = rc_find(o, 0);
    if (e) { for (int i = 0; i < e->nweak; i++) *e->weak[i] = NULL; rc_erase(e); }
    pthread_mutex_unlock(&rr_lock);
    return o;
}
id object_dispose(id o) { if (o) { objc_destructInstance(o); free(o); } return NULL; }
id class_createInstance(Class c, size_t extra) {
    if (!c) return NULL;
    id o = calloc(1, ro_of(c)->instance_size + extra);
    o->isa = c;
    return o;
}

/* ARC entry points: always dispatch through -retain/-release so classes may override them */
id objc_retain(id o) { return o ? send0(o, s_retain) : o; }
void objc_release(id o) { if (o) send0(o, s_release); }
id objc_autorelease(id o) { return o ? send0(o, s_autorelease) : o; }
id objc_retainAutorelease(id o) { return objc_autorelease(objc_retain(o)); }
id objc_retainAutoreleaseReturnValue(id o) { return objc_retainAutorelease(o); }
id objc_autoreleaseReturnValue(id o) { return objc_autorelease(o); }
id objc_retainAutoreleasedReturnValue(id o) { return objc_retain(o); }
id objc_claimAutoreleasedReturnValue(id o) { return objc_retain(o); }
id objc_unsafeClaimAutoreleasedReturnValue(id o) { return o; }
void objc_storeStrong(id *loc, id val) { id old = *loc; if (old == val) return; objc_retain(val); *loc = val; objc_release(old); }
id objc_retainBlock(id b);

/* ================= autorelease pools (per thread, host TLS) ================= */
static __thread id *pool; static __thread size_t pool_n, pool_cap;
id _objc_rootAutorelease(id o) {
    if (!o) return o;
    if (pool_n == pool_cap) { pool_cap = pool_cap ? pool_cap * 2 : 256; pool = realloc(pool, pool_cap * sizeof *pool); }
    pool[pool_n++] = o;
    return o;
}
#define POOL_BOUNDARY ((id)0)
void *objc_autoreleasePoolPush(void) {
    _objc_rootAutorelease((id)1);                      /* reserve a slot ... */
    pool[pool_n - 1] = POOL_BOUNDARY;                  /* ... and mark it as this pool's boundary */
    return (void *)(uintptr_t)pool_n;                  /* token = index after the boundary */
}
void objc_autoreleasePoolPop(void *token) {
    size_t boundary = (size_t)(uintptr_t)token - 1;
    while (pool_n > boundary) {                        /* releases may autorelease more; pop from the top */
        id o = pool[--pool_n];
        if (pool_n == boundary) break;                 /* our boundary */
        if (o != POOL_BOUNDARY) objc_release(o);       /* inner pools left unpopped are drained too */
    }
}

/* ================= properties, sync, misc ================= */
static pthread_mutex_t prop_locks[16];   /* zero-initialised == PTHREAD_MUTEX_INITIALIZER on glibc */
static pthread_mutex_t *prop_lock(void *p) { return &prop_locks[hash_ptr(p) & 15]; }
id objc_getProperty(id self, SEL _cmd, ptrdiff_t off, int atomic) {
    id *slot = (id *)((char *)self + off);
    if (!atomic) return *slot;
    pthread_mutex_lock(prop_lock(slot)); id v = objc_retain(*slot); pthread_mutex_unlock(prop_lock(slot));
    return objc_autorelease(v);
}
static void set_prop(id self, ptrdiff_t off, id val, int atomic, int copy) {
    id *slot = (id *)((char *)self + off);
    id nv = copy == 2 ? send0(val, s_mutableCopy) : copy ? send0(val, s_copy) : objc_retain(val);
    id old;
    if (atomic) { pthread_mutex_lock(prop_lock(slot)); old = *slot; *slot = nv; pthread_mutex_unlock(prop_lock(slot)); }
    else { old = *slot; *slot = nv; }
    objc_release(old);
}
void objc_setProperty(id self, SEL _cmd, ptrdiff_t off, id val, int atomic, signed char copy) { set_prop(self, off, val, atomic, copy); }
void objc_setProperty_atomic(id s, SEL c, id v, ptrdiff_t off) { set_prop(s, off, v, 1, 0); }
void objc_setProperty_nonatomic(id s, SEL c, id v, ptrdiff_t off) { set_prop(s, off, v, 0, 0); }
void objc_setProperty_atomic_copy(id s, SEL c, id v, ptrdiff_t off) { set_prop(s, off, v, 1, 1); }
void objc_setProperty_nonatomic_copy(id s, SEL c, id v, ptrdiff_t off) { set_prop(s, off, v, 0, 1); }
void objc_copyStruct(void *dst, const void *src, ptrdiff_t size, int atomic, int strong) {
    if (atomic) { pthread_mutex_lock(prop_lock((void *)src)); memcpy(dst, src, size); pthread_mutex_unlock(prop_lock((void *)src)); }
    else memcpy(dst, src, size);
}

static pthread_mutex_t sync_locks[64];
static void sync_init(void) {
    pthread_mutexattr_t a; pthread_mutexattr_init(&a); pthread_mutexattr_settype(&a, PTHREAD_MUTEX_RECURSIVE);
    for (int i = 0; i < 64; i++) pthread_mutex_init(&sync_locks[i], &a);
}
int objc_sync_enter(id o) { static pthread_once_t once = PTHREAD_ONCE_INIT; pthread_once(&once, sync_init); if (o) pthread_mutex_lock(&sync_locks[hash_ptr(o) & 63]); return 0; }
int objc_sync_exit(id o) { if (o) pthread_mutex_unlock(&sync_locks[hash_ptr(o) & 63]); return 0; }

void objc_enumerationMutation(id o) { fflush(NULL); fprintf(stderr, "isim objc: FATAL: collection %p mutated while being enumerated\n", (void *)o); abort(); }
/* exceptions: objc_exc.c */
void objc_exception_throw(id e);
id objc_begin_catch(void *exc);
void objc_end_catch(void);
void objc_exception_rethrow(void);
void objc_terminate(void);
void *objc_setUncaughtExceptionHandler(void *h);
void *objc_setExceptionPreprocessor(void *p);
extern void *objc_ehtype_vtable[];
extern char OBJC_EHTYPE_id[];

/* objc_alloc & friends: semantically [cls alloc] etc. */
id objc_alloc(Class c) { return send0((id)c, s_alloc); }
id objc_allocWithZone(Class c) { return send1((id)c, sel_registerName("allocWithZone:"), NULL); }
id objc_alloc_init(Class c) { return send0(send0((id)c, s_alloc), s_init); }
id objc_opt_new(Class c) { return send0((id)c, s_new); }
Class objc_opt_class(id o) { return o ? (Class)send0(o, s_class) : NULL; }
id objc_opt_self(id o) { return o; }
int objc_opt_isKindOfClass(id o, Class c) { return o ? (int)(intptr_t)(((int8_t (*)(id, SEL, Class))objc_rt_lookup(o, o->isa, s_isKindOfClass))(o, s_isKindOfClass, c)) : 0; }
int objc_opt_respondsToSelector(id o, SEL s) { return o ? (int)(((int8_t (*)(id, SEL, SEL))objc_rt_lookup(o, o->isa, s_respondsToSelector))(o, s_respondsToSelector, s)) : 0; }

/* ================= blocks runtime (libclosure ABI subset) ================= */
struct block_desc { unsigned long reserved, size; void (*copy)(void *, const void *); void (*dispose)(const void *); };
struct block_layout { void *isa; volatile int32_t flags; int32_t reserved; void (*invoke)(void *, ...); struct block_desc *desc; };
#define BLOCK_DEALLOCATING 0x0001
#define BLOCK_REFCOUNT_MASK 0xfffe
#define BLOCK_NEEDS_FREE (1 << 24)
#define BLOCK_HAS_COPY_DISPOSE (1 << 25)
#define BLOCK_IS_GLOBAL (1 << 28)
void *_NSConcreteAutoBlock[32], *_NSConcreteFinalizingBlock[32], *_NSConcreteWeakBlockVariable[32];

void *_Block_copy(const void *arg) {
    struct block_layout *b = (void *)arg;
    if (!b) return NULL;
    if (b->flags & BLOCK_NEEDS_FREE) { __atomic_add_fetch(&b->flags, 2, __ATOMIC_RELAXED); return b; }
    if (b->flags & BLOCK_IS_GLOBAL) return b;
    struct block_layout *n = malloc(b->desc->size);
    memcpy(n, b, b->desc->size);
    n->flags &= ~(BLOCK_REFCOUNT_MASK | BLOCK_DEALLOCATING);
    n->flags |= BLOCK_NEEDS_FREE | 2;
    n->isa = _NSConcreteMallocBlock;
    if (b->flags & BLOCK_HAS_COPY_DISPOSE) b->desc->copy(n, b);
    return n;
}
void _Block_release(const void *arg) {
    struct block_layout *b = (void *)arg;
    if (!b || !(b->flags & BLOCK_NEEDS_FREE)) return;
    if ((__atomic_sub_fetch(&b->flags, 2, __ATOMIC_ACQ_REL) & BLOCK_REFCOUNT_MASK) == 0) {
        if (b->flags & BLOCK_HAS_COPY_DISPOSE) b->desc->dispose(b);
        free(b);
    }
}
id objc_retainBlock(id b) { return _Block_copy(b); }

struct byref { void *isa; struct byref *forwarding; volatile int32_t flags; uint32_t size;
               void (*keep)(struct byref *, struct byref *); void (*destroy)(struct byref *); };
#define BLOCK_FIELD_IS_OBJECT 3
#define BLOCK_FIELD_IS_BLOCK 7
#define BLOCK_FIELD_IS_BYREF 8
#define BLOCK_FIELD_IS_WEAK 16
#define BLOCK_BYREF_CALLER 128
#define BLOCK_BYREF_HAS_COPY_DISPOSE (1 << 25)
static struct byref *byref_copy(struct byref *src) {
    if (!(src->forwarding->flags & BLOCK_REFCOUNT_MASK)) {
        struct byref *c = malloc(src->size);
        memcpy(c, src, src->size);
        c->flags = (src->flags & ~BLOCK_REFCOUNT_MASK) | BLOCK_NEEDS_FREE | 4;
        c->forwarding = c; src->forwarding = c;
        if (src->flags & BLOCK_BYREF_HAS_COPY_DISPOSE) c->keep(c, src);
        return c;
    }
    struct byref *f = src->forwarding;
    if (f->flags & BLOCK_NEEDS_FREE) __atomic_add_fetch(&f->flags, 2, __ATOMIC_RELAXED);
    return f;
}
void _Block_object_assign(void *dst, const void *obj, int flags) {
    switch (flags & (BLOCK_FIELD_IS_OBJECT | BLOCK_FIELD_IS_BLOCK | BLOCK_FIELD_IS_BYREF | BLOCK_FIELD_IS_WEAK | BLOCK_BYREF_CALLER)) {
    case BLOCK_FIELD_IS_OBJECT: objc_retain((id)obj); *(const void **)dst = obj; break;
    case BLOCK_FIELD_IS_BLOCK: *(void **)dst = _Block_copy(obj); break;
    case BLOCK_FIELD_IS_BYREF: case BLOCK_FIELD_IS_BYREF | BLOCK_FIELD_IS_WEAK: *(void **)dst = byref_copy((struct byref *)obj); break;
    default: *(const void **)dst = obj; break;            /* __block captured objects / weak: no retain */
    }
}
void _Block_object_dispose(const void *obj, int flags) {
    switch (flags & (BLOCK_FIELD_IS_OBJECT | BLOCK_FIELD_IS_BLOCK | BLOCK_FIELD_IS_BYREF | BLOCK_FIELD_IS_WEAK | BLOCK_BYREF_CALLER)) {
    case BLOCK_FIELD_IS_OBJECT: objc_release((id)obj); break;
    case BLOCK_FIELD_IS_BLOCK: _Block_release(obj); break;
    case BLOCK_FIELD_IS_BYREF: case BLOCK_FIELD_IS_BYREF | BLOCK_FIELD_IS_WEAK: {
        struct byref *b = ((struct byref *)obj)->forwarding;
        if ((b->flags & BLOCK_NEEDS_FREE) && (__atomic_sub_fetch(&b->flags, 2, __ATOMIC_ACQ_REL) & BLOCK_REFCOUNT_MASK) == 0) {
            if (b->flags & BLOCK_BYREF_HAS_COPY_DISPOSE) b->destroy(b);
            free(b);
        }
        break; }
    default: break;
    }
}

static void *empty_cache[2];

#define I(n) { "_" #n, (void *)n, "isim" }
#define J(name, fn) { name, (void *)fn, "isim" }
static const struct shim objc_table[] = {
    J("_objc_msgSend", rt_msgSend), J("_objc_msgSendSuper", rt_msgSendSuper), J("_objc_msgSendSuper2", rt_msgSendSuper2),
    J("_objc_msgSend_stret", rt_msgSend_stret), J("_objc_msgSendSuper2_stret", rt_msgSendSuper2_stret),
    J("__objc_msgForward", rt_msgForward), J("__objc_msgForward_stret", rt_msgForward_stret),
    I(isim_objc_set_forward_handler), I(isim_objc_call_frame),
    J("__objc_empty_cache", empty_cache), J("_OBJC_CLASS_$_Protocol", &protocol_class), J("_OBJC_METACLASS_$_Protocol", &protocol_meta),
    I(sel_registerName), J("_sel_getUid", sel_registerName), I(sel_getName), I(sel_isEqual),
    I(objc_getClass), I(objc_lookUpClass), I(objc_getMetaClass), I(class_getName), I(class_getSuperclass), I(class_isMetaClass),
    I(class_getInstanceSize), I(object_getClass), I(object_setClass), I(object_getClassName), I(class_respondsToSelector),
    I(class_getMethodImplementation), I(class_getMethodImplementation_stret), I(class_createInstance), I(object_dispose), I(objc_destructInstance),
    I(objc_getProtocol), I(protocol_getMethodDescription), I(protocol_getName), I(protocol_conformsToProtocol), I(class_conformsToProtocol),
    I(_objc_rootRetain), I(_objc_rootRelease), I(_objc_rootReleaseWasZero), I(_objc_rootRetainCount), I(_objc_rootAutorelease),
    I(_objc_rootIsDeallocating), I(_objc_realizeClassFromSwift),
    I(objc_retain), I(objc_release), I(objc_autorelease), I(objc_retainAutorelease), I(objc_retainAutoreleaseReturnValue),
    I(objc_autoreleaseReturnValue), I(objc_retainAutoreleasedReturnValue), I(objc_claimAutoreleasedReturnValue),
    I(objc_unsafeClaimAutoreleasedReturnValue), I(objc_storeStrong), I(objc_retainBlock),
    I(objc_storeWeak), I(objc_initWeak), I(objc_destroyWeak), I(objc_loadWeakRetained), I(objc_loadWeak), I(objc_copyWeak), I(objc_moveWeak),
    I(objc_autoreleasePoolPush), I(objc_autoreleasePoolPop),
    I(objc_getProperty), I(objc_setProperty), I(objc_setProperty_atomic), I(objc_setProperty_nonatomic),
    I(objc_setProperty_atomic_copy), I(objc_setProperty_nonatomic_copy), I(objc_copyStruct),
    I(objc_sync_enter), I(objc_sync_exit), I(objc_enumerationMutation), I(objc_exception_throw),
    I(objc_begin_catch), I(objc_end_catch), I(objc_exception_rethrow), I(objc_terminate), I(objc_setUncaughtExceptionHandler),
    I(objc_setExceptionPreprocessor), J("_objc_ehtype_vtable", objc_ehtype_vtable), J("_OBJC_EHTYPE_id", OBJC_EHTYPE_id),
    I(objc_alloc), I(objc_allocWithZone), I(objc_alloc_init), I(objc_opt_new), I(objc_opt_class), I(objc_opt_self),
    I(objc_opt_isKindOfClass), I(objc_opt_respondsToSelector),
    I(class_getInstanceMethod), I(class_getClassMethod), I(method_getImplementation), I(method_getName),
    I(method_getTypeEncoding), I(method_setImplementation), I(method_exchangeImplementations), I(class_addMethod),
    I(class_setSuperclass), I(class_copyIvarList), I(class_copyMethodList), I(objc_copyClassList), I(ivar_getOffset), I(ivar_getName), I(ivar_getTypeEncoding),
    I(objc_constructInstance), I(object_isClass), I(objc_readClassPair), I(objc_setHook_getClass),
    I(objc_setHook_getImageName), I(objc_setHook_lazyClassNamer), I(class_getImageName),
    I(objc_getAssociatedObject), I(objc_setAssociatedObject), I(objc_removeAssociatedObjects),
    I(class_getProperty), I(class_copyPropertyList), I(property_getName), I(property_getAttributes),
    I(_Block_copy), I(_Block_release), I(_Block_object_assign), I(_Block_object_dispose),
    J("__NSConcreteStackBlock", _NSConcreteStackBlock), J("__NSConcreteMallocBlock", _NSConcreteMallocBlock),
    J("__NSConcreteGlobalBlock", _NSConcreteGlobalBlock),
};
const struct host_lib host_libobjc = { "/usr/lib/libobjc.A.dylib", objc_table, sizeof objc_table / sizeof *objc_table };
