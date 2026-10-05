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
 * Not implemented: message forwarding (aborts with the selector), resolveInstanceMethod,
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

struct rt_class {
    Class cls, nonmeta;
    int realized, is_meta;
    int init_state;                            /* 0 none, 1 initializing, 2 done */
    struct method_list_t **cat_lists; int ncat, catcap;
    struct protocol_list_t **cat_protos; int ncatp;
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
static const char *cls_name(Class c) { return c ? ro_of(c)->name : "nil"; }
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
           s_class, s_isKindOfClass, s_respondsToSelector, s_copy, s_mutableCopy, s_cxx_destruct, s_description,
           s_retainCount;
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
IMP objc_rt_lookup(id self, Class cls, SEL sel) {
    if (cls->rt && cls->rt->nonmeta && cls->rt->nonmeta->rt->init_state != 2) ensure_initialized(cls->rt->nonmeta);
    IMP imp = lookup_nofail(cls, sel);
    if (!imp) {
        fflush(NULL);
        fprintf(stderr, "isim objc: FATAL: %c[%s %s]: unrecognized selector sent to %s %p (forwarding not implemented)\n",
                is_meta(cls) ? '+' : '-', cls_name(cls), sel, is_meta(cls) ? "class" : "instance", (void *)self);
        abort();
    }
    return imp;
}

#define SAVE_ARGS \
    "  push %rbp\n  mov %rsp, %rbp\n  sub $0xc0, %rsp\n" \
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
    "  mov %rbp, %rsp\n  pop %rbp\n  jmp *%r11\n"

__asm__(
    ".text\n"
    /* id objc_msgSend(id self, SEL op, ...) */
    ".globl rt_msgSend\n.type rt_msgSend,@function\nrt_msgSend:\n"
    "  test %rdi, %rdi\n  jz 1f\n" SAVE_ARGS
    "  mov %rsi, %rdx\n  mov (%rdi), %rsi\n  call objc_rt_lookup\n" RESTORE_AND_JUMP
    "1:\n  xor %eax, %eax\n  xor %edx, %edx\n  pxor %xmm0, %xmm0\n  pxor %xmm1, %xmm1\n  ret\n"
    /* objc_msgSendSuper2(struct objc_super *{receiver, current_class}, SEL, ...) */
    ".globl rt_msgSendSuper2\n.type rt_msgSendSuper2,@function\nrt_msgSendSuper2:\n" SAVE_ARGS
    "  mov (%rdi), %r10\n  mov %r10, 0x80(%rsp)\n"
    "  mov %rsi, %rdx\n  mov 8(%rdi), %rsi\n  mov 8(%rsi), %rsi\n  mov %r10, %rdi\n  call objc_rt_lookup\n" RESTORE_AND_JUMP
    /* objc_msgSendSuper(struct objc_super *{receiver, class}, SEL, ...) */
    ".globl rt_msgSendSuper\n.type rt_msgSendSuper,@function\nrt_msgSendSuper:\n" SAVE_ARGS
    "  mov (%rdi), %r10\n  mov %r10, 0x80(%rsp)\n"
    "  mov %rsi, %rdx\n  mov 8(%rdi), %rsi\n  mov %r10, %rdi\n  call objc_rt_lookup\n" RESTORE_AND_JUMP
    /* void objc_msgSend_stret(void *ret, id self, SEL op, ...) */
    ".globl rt_msgSend_stret\n.type rt_msgSend_stret,@function\nrt_msgSend_stret:\n"
    "  test %rsi, %rsi\n  jz 2f\n" SAVE_ARGS
    "  mov %rsi, %rdi\n  mov (%rsi), %rsi\n  call objc_rt_lookup\n" RESTORE_AND_JUMP
    "2:\n  mov %rdi, %rax\n  ret\n"
    /* void objc_msgSendSuper2_stret(void *ret, struct objc_super *, SEL, ...) */
    ".globl rt_msgSendSuper2_stret\n.type rt_msgSendSuper2_stret,@function\nrt_msgSendSuper2_stret:\n" SAVE_ARGS
    "  mov (%rsi), %r10\n  mov %r10, 0x88(%rsp)\n"
    "  mov 8(%rsi), %rsi\n  mov 8(%rsi), %rsi\n  mov %r10, %rdi\n  call objc_rt_lookup\n" RESTORE_AND_JUMP
);
void rt_msgSend(void); void rt_msgSendSuper2(void); void rt_msgSendSuper(void);
void rt_msgSend_stret(void); void rt_msgSendSuper2_stret(void);

static id send0(id self, SEL sel) { return self ? ((id (*)(id, SEL))objc_rt_lookup(self, self->isa, sel))(self, sel) : NULL; }
static id send1(id self, SEL sel, void *a) { return self ? ((id (*)(id, SEL, void *))objc_rt_lookup(self, self->isa, sel))(self, sel, a) : NULL; }

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
static void classify_block_storage(Class c) {
    const char *n = ro_of(c)->name; void **dst = NULL;
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
    *strmap_slot(&classes, ro_of(c)->name, 1) = c;
    classify_block_storage(c);
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
    s_description = sel_intern("description"); s_retainCount = sel_intern("retainCount");
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
Class objc_getClass(const char *name) { return name ? objc_lookUpClass(name) : NULL; }
Class objc_getMetaClass(const char *name) { Class c = objc_getClass(name); return c ? c->isa : NULL; }
const char *class_getName(Class c) { return c ? ro_of(c)->name : "nil"; }
Class class_getSuperclass(Class c) { return c ? c->superclass : NULL; }
int class_isMetaClass(Class c) { return c && is_meta(c); }
size_t class_getInstanceSize(Class c) { return c ? ro_of(c)->instance_size : 0; }
Class object_getClass(id o) { return o ? o->isa : NULL; }
Class object_setClass(id o, Class c) { Class old = o ? o->isa : NULL; if (o) o->isa = c; return old; }
const char *object_getClassName(id o) { return o ? ro_of(o->isa)->name : "nil"; }
int class_respondsToSelector(Class c, SEL sel) { return c && sel && lookup_nofail(c, sel) != NULL; }
IMP class_getMethodImplementation(Class c, SEL sel) { return c ? lookup_nofail(c, sel) : NULL; }
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
void objc_exception_throw(id e) {
    fflush(NULL);
    id desc = send0(e, s_description);
    const char *(*utf8)(id, SEL) = desc ? (void *)objc_rt_lookup(desc, desc->isa, sel_registerName("UTF8String")) : NULL;
    fprintf(stderr, "isim objc: FATAL: uncaught exception (exceptions are not implemented): %s\n",
            utf8 ? utf8(desc, sel_registerName("UTF8String")) : "?");
    abort();
}

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
    J("__objc_empty_cache", empty_cache), J("_OBJC_CLASS_$_Protocol", &protocol_class), J("_OBJC_METACLASS_$_Protocol", &protocol_meta),
    I(sel_registerName), J("_sel_getUid", sel_registerName), I(sel_getName), I(sel_isEqual),
    I(objc_getClass), I(objc_lookUpClass), I(objc_getMetaClass), I(class_getName), I(class_getSuperclass), I(class_isMetaClass),
    I(class_getInstanceSize), I(object_getClass), I(object_setClass), I(object_getClassName), I(class_respondsToSelector),
    I(class_getMethodImplementation), I(class_createInstance), I(object_dispose), I(objc_destructInstance),
    I(objc_getProtocol), I(protocol_getName), I(protocol_conformsToProtocol), I(class_conformsToProtocol),
    I(_objc_rootRetain), I(_objc_rootRelease), I(_objc_rootReleaseWasZero), I(_objc_rootRetainCount), I(_objc_rootAutorelease),
    I(_objc_rootIsDeallocating),
    I(objc_retain), I(objc_release), I(objc_autorelease), I(objc_retainAutorelease), I(objc_retainAutoreleaseReturnValue),
    I(objc_autoreleaseReturnValue), I(objc_retainAutoreleasedReturnValue), I(objc_claimAutoreleasedReturnValue),
    I(objc_unsafeClaimAutoreleasedReturnValue), I(objc_storeStrong), I(objc_retainBlock),
    I(objc_storeWeak), I(objc_initWeak), I(objc_destroyWeak), I(objc_loadWeakRetained), I(objc_loadWeak), I(objc_copyWeak), I(objc_moveWeak),
    I(objc_autoreleasePoolPush), I(objc_autoreleasePoolPop),
    I(objc_getProperty), I(objc_setProperty), I(objc_setProperty_atomic), I(objc_setProperty_nonatomic),
    I(objc_setProperty_atomic_copy), I(objc_setProperty_nonatomic_copy), I(objc_copyStruct),
    I(objc_sync_enter), I(objc_sync_exit), I(objc_enumerationMutation), I(objc_exception_throw),
    I(objc_alloc), I(objc_allocWithZone), I(objc_alloc_init), I(objc_opt_new), I(objc_opt_class), I(objc_opt_self),
    I(objc_opt_isKindOfClass), I(objc_opt_respondsToSelector),
    I(_Block_copy), I(_Block_release), I(_Block_object_assign), I(_Block_object_dispose),
    J("__NSConcreteStackBlock", _NSConcreteStackBlock), J("__NSConcreteMallocBlock", _NSConcreteMallocBlock),
    J("__NSConcreteGlobalBlock", _NSConcreteGlobalBlock),
};
const struct host_lib host_libobjc = { "/usr/lib/libobjc.A.dylib", objc_table, sizeof objc_table / sizeof *objc_table };
