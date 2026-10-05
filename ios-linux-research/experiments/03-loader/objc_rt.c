/*
 * objc_rt: minimal Objective-C runtime for machoload (experiment 05).
 *
 * Reads Apple's ObjC2 (x86_64, non-fragile) metadata emitted by clang for the
 * iOS-simulator target. Implemented: selector interning (__objc_selrefs and
 * method-list names), method lookup through class_ro_t base method lists
 * (pointer and relative/"small" lists) walking superclasses, objc_msgSend,
 * objc_msgSendSuper2, objc_alloc / objc_alloc_init, objc_opt_new.
 *
 * NOT implemented (traps or ignored): categories, +load, +initialize, protocols,
 * properties, objc_getClass, ivar offset sliding across images, retain/release
 * (ARC), autorelease pools, tagged pointers, non-pointer isa, stret/fpret
 * variants, forwarding, associated objects, exceptions, weak references.
 */
#define _GNU_SOURCE
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "shims.h"

typedef struct objc_class *Class;
typedef const char *SEL;               /* canonical interned C string */
typedef void *IMP;

struct method_t { SEL name; const char *types; IMP imp; };
struct method_list_t { uint32_t entsize_flags, count; /* entries follow */ };
struct class_ro_t {
    uint32_t flags, instance_start, instance_size, reserved;
    const uint8_t *ivar_layout; const char *name;
    struct method_list_t *base_methods;
    void *base_protocols, *ivars; const uint8_t *weak_ivar_layout; void *base_properties;
};
struct objc_class { Class isa, superclass; void *cache, *vtable; uintptr_t data; };

#define FAST_DATA_MASK 0x00007ffffffffff8ull
#define RO_META 0x1
#define SMALL_METHOD_LIST 0x80000000u
#define ENTSIZE_MASK 0x0000fffcu

static int verbose;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

static struct class_ro_t *ro_of(Class c) { return (struct class_ro_t *)(c->data & FAST_DATA_MASK); }

/* ---- selector interning: open-addressing string set ---- */
static const char **sel_tab; static size_t sel_cap, sel_n;
static uint64_t hash_str(const char *s) { uint64_t h = 1469598103934665603ull; while (*s) h = (h ^ (uint8_t)*s++) * 1099511628211ull; return h; }
static SEL sel_intern(const char *s) {
    if (sel_n * 2 >= sel_cap) {
        size_t ncap = sel_cap ? sel_cap * 2 : 256; const char **n = calloc(ncap, sizeof *n);
        for (size_t i = 0; i < sel_cap; i++) if (sel_tab[i]) {
            size_t j = hash_str(sel_tab[i]) & (ncap - 1); while (n[j]) j = (j + 1) & (ncap - 1); n[j] = sel_tab[i]; }
        free(sel_tab); sel_tab = n; sel_cap = ncap;
    }
    size_t j = hash_str(s) & (sel_cap - 1);
    while (sel_tab[j]) { if (!strcmp(sel_tab[j], s)) return sel_tab[j]; j = (j + 1) & (sel_cap - 1); }
    sel_n++; return sel_tab[j] = s;
}

/* ---- method cache: (class, sel) -> imp ---- */
struct centry { Class cls; SEL sel; IMP imp; };
static struct centry *cache; static size_t cache_cap, cache_n;
static size_t chash(Class c, SEL s) { return (((uintptr_t)c >> 3) * 31 + ((uintptr_t)s >> 3)) & (cache_cap - 1); }
static void cache_put(Class c, SEL s, IMP imp) {
    if (cache_n * 2 >= cache_cap) {
        size_t ocap = cache_cap; struct centry *old = cache;
        cache_cap = ocap ? ocap * 2 : 1024; cache = calloc(cache_cap, sizeof *cache); cache_n = 0;
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

/* ---- method lists ---- */
static int32_t rel32(const void *field) { int32_t v; memcpy(&v, field, 4); return v; }
static SEL m_name(const struct method_list_t *ml, uint32_t i) {
    uint32_t es = ml->entsize_flags & ENTSIZE_MASK; const uint8_t *e = (const uint8_t *)(ml + 1) + i * es;
    if (ml->entsize_flags & SMALL_METHOD_LIST) return *(SEL *)(e + rel32(e));      /* offset -> selref */
    return ((const struct method_t *)e)->name;
}
static IMP m_imp(const struct method_list_t *ml, uint32_t i) {
    uint32_t es = ml->entsize_flags & ENTSIZE_MASK; const uint8_t *e = (const uint8_t *)(ml + 1) + i * es;
    if (ml->entsize_flags & SMALL_METHOD_LIST) return (IMP)(e + 8 + rel32(e + 8));
    return ((const struct method_t *)e)->imp;
}

static IMP lookup_uncached(Class cls, SEL sel) {
    for (Class c = cls; c; c = c->superclass) {
        const struct method_list_t *ml = ro_of(c)->base_methods;
        if (!ml) continue;
        for (uint32_t i = 0; i < ml->count; i++) if (m_name(ml, i) == sel) return m_imp(ml, i);
    }
    return NULL;
}

/* called from the assembly trampolines; must not clobber guest state beyond the ABI */
IMP objc_rt_lookup(Class cls, SEL sel) {
    pthread_mutex_lock(&lock);
    IMP imp = cache_get(cls, sel);
    if (!imp && (imp = lookup_uncached(cls, sel))) cache_put(cls, sel, imp);
    pthread_mutex_unlock(&lock);
    if (!imp) {
        struct class_ro_t *ro = ro_of(cls);
        fflush(NULL);
        fprintf(stderr, "objc_rt: FATAL: %c[%s %s]: unrecognized selector (forwarding not implemented)\n",
                ro->flags & RO_META ? '+' : '-', ro->name, sel);
        abort();
    }
    return imp;
}

/* objc_msgSend(id self, SEL op, ...): save all argument registers, look up, tail-jump. */
__asm__(
    ".text\n.globl objc_rt_msgSend\n.type objc_rt_msgSend,@function\nobjc_rt_msgSend:\n"
    "  test %rdi, %rdi\n  jz 1f\n"
    "  push %rbp\n  mov %rsp, %rbp\n  sub $0xc0, %rsp\n"
    "  movdqa %xmm0, 0x00(%rsp)\n  movdqa %xmm1, 0x10(%rsp)\n  movdqa %xmm2, 0x20(%rsp)\n  movdqa %xmm3, 0x30(%rsp)\n"
    "  movdqa %xmm4, 0x40(%rsp)\n  movdqa %xmm5, 0x50(%rsp)\n  movdqa %xmm6, 0x60(%rsp)\n  movdqa %xmm7, 0x70(%rsp)\n"
    "  mov %rdi, 0x80(%rsp)\n  mov %rsi, 0x88(%rsp)\n  mov %rdx, 0x90(%rsp)\n  mov %rcx, 0x98(%rsp)\n"
    "  mov %r8, 0xa0(%rsp)\n  mov %r9, 0xa8(%rsp)\n  mov %rax, 0xb0(%rsp)\n"
    "  mov (%rdi), %rdi\n"                                  /* isa (plain pointer isa only) */
    "  call objc_rt_lookup\n  mov %rax, %r11\n"
    "2:\n"
    "  movdqa 0x00(%rsp), %xmm0\n  movdqa 0x10(%rsp), %xmm1\n  movdqa 0x20(%rsp), %xmm2\n  movdqa 0x30(%rsp), %xmm3\n"
    "  movdqa 0x40(%rsp), %xmm4\n  movdqa 0x50(%rsp), %xmm5\n  movdqa 0x60(%rsp), %xmm6\n  movdqa 0x70(%rsp), %xmm7\n"
    "  mov 0x80(%rsp), %rdi\n  mov 0x88(%rsp), %rsi\n  mov 0x90(%rsp), %rdx\n  mov 0x98(%rsp), %rcx\n"
    "  mov 0xa0(%rsp), %r8\n  mov 0xa8(%rsp), %r9\n  mov 0xb0(%rsp), %rax\n"
    "  mov %rbp, %rsp\n  pop %rbp\n  jmp *%r11\n"
    "1:\n  xor %eax, %eax\n  xor %edx, %edx\n  pxor %xmm0, %xmm0\n  pxor %xmm1, %xmm1\n  ret\n"   /* message to nil */
    /* objc_msgSendSuper2(struct objc_super *{receiver, current_class}, SEL, ...) */
    ".globl objc_rt_msgSendSuper2\n.type objc_rt_msgSendSuper2,@function\nobjc_rt_msgSendSuper2:\n"
    "  push %rbp\n  mov %rsp, %rbp\n  sub $0xc0, %rsp\n"
    "  movdqa %xmm0, 0x00(%rsp)\n  movdqa %xmm1, 0x10(%rsp)\n  movdqa %xmm2, 0x20(%rsp)\n  movdqa %xmm3, 0x30(%rsp)\n"
    "  movdqa %xmm4, 0x40(%rsp)\n  movdqa %xmm5, 0x50(%rsp)\n  movdqa %xmm6, 0x60(%rsp)\n  movdqa %xmm7, 0x70(%rsp)\n"
    "  mov (%rdi), %r10\n  mov %r10, 0x80(%rsp)\n"           /* self := super->receiver */
    "  mov %rsi, 0x88(%rsp)\n  mov %rdx, 0x90(%rsp)\n  mov %rcx, 0x98(%rsp)\n"
    "  mov %r8, 0xa0(%rsp)\n  mov %r9, 0xa8(%rsp)\n  mov %rax, 0xb0(%rsp)\n"
    "  mov 8(%rdi), %rdi\n  mov 8(%rdi), %rdi\n"            /* current_class->superclass */
    "  call objc_rt_lookup\n  mov %rax, %r11\n  jmp 2b\n"
);
void objc_rt_msgSend(void);
void objc_rt_msgSendSuper2(void);

typedef void *id;
static id send0(id self, SEL sel) { return self ? ((id (*)(id, SEL))objc_rt_lookup(*(Class *)self, sel))(self, sel) : NULL; }
static SEL s_alloc, s_init, s_new;
static id d_objc_alloc(Class cls) { return send0(cls, s_alloc); }
static id d_objc_alloc_init(Class cls) { return send0(send0(cls, s_alloc), s_init); }
static id d_objc_opt_new(Class cls) { return send0(cls, s_new); }
static void *empty_cache[2];

static const struct shim table[] = {
    { "_objc_msgSend",       (void *)objc_rt_msgSend,       "adapted" },
    { "_objc_msgSendSuper2", (void *)objc_rt_msgSendSuper2, "adapted" },
    { "_objc_alloc",         (void *)d_objc_alloc,          "adapted" },
    { "_objc_alloc_init",    (void *)d_objc_alloc_init,     "adapted" },
    { "_objc_opt_new",       (void *)d_objc_opt_new,        "adapted" },
    { "__objc_empty_cache",  (void *)empty_cache,           "stub" },   /* runtime never reads class->cache */
};
const struct shim *objc_rt_shim_lookup(const char *name) {
    for (size_t i = 0; i < sizeof table / sizeof *table; i++) if (!strcmp(table[i].name, name)) return &table[i];
    return NULL;
}

static void intern_methods(struct method_list_t *ml) {
    if (!ml || (ml->entsize_flags & SMALL_METHOD_LIST)) return; /* small lists name selrefs, already interned */
    uint32_t es = ml->entsize_flags & ENTSIZE_MASK;
    for (uint32_t i = 0; i < ml->count; i++) {
        struct method_t *m = (struct method_t *)((uint8_t *)(ml + 1) + i * es);
        m->name = sel_intern(m->name);
    }
}

void objc_rt_register_image(section_finder find, int v) {
    verbose = v;
    s_alloc = sel_intern("alloc"); s_init = sel_intern("init"); s_new = sel_intern("new");
    uint64_t n;
    SEL *selrefs = find("__objc_selrefs", &n);
    for (uint64_t i = 0; i < n / 8; i++) selrefs[i] = sel_intern(selrefs[i]);
    Class *classes = find("__objc_classlist", &n);
    for (uint64_t i = 0; i < n / 8; i++) {
        Class c = classes[i];
        intern_methods(ro_of(c)->base_methods);
        intern_methods(ro_of(c->isa)->base_methods);
        if (verbose) fprintf(stderr, "  objc class %s (instance size %u)\n", ro_of(c)->name, ro_of(c)->instance_size);
    }
    uint64_t cn; find("__objc_catlist", &cn);
    if (cn) fprintf(stderr, "objc_rt: warning: %lu categories ignored (not implemented)\n", (unsigned long)(cn / 8));
    find("__objc_nlclslist", &cn);
    if (cn) fprintf(stderr, "objc_rt: warning: +load on %lu classes not run (not implemented)\n", (unsigned long)(cn / 8));
}
