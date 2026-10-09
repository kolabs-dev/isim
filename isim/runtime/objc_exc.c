/*
 * isim Objective-C exceptions (host side): @throw / @try / @catch / @finally / @synchronized cleanup,
 * objc_exception_throw/rethrow, objc_begin_catch/objc_end_catch, __objc_personality_v0, uncaught
 * exception reporting.
 *
 * Guest code is x86_64 Mach-O running natively in this process, so the host's two-phase DWARF
 * unwinder (libgcc_s: _Unwind_RaiseException) can walk guest frames as long as it finds FDEs for them.
 * Mach-O images mostly carry no __eh_frame FDEs: ld64/lld keep only __unwind_info (compact unwind)
 * and drop the FDEs that compact encodings can express. On the first throw we therefore translate
 * every loaded image's __unwind_info into a synthetic .eh_frame (one CIE per personality, one FDE
 * per compact entry, absolute pointer encodings; DWARF-mode entries are re-encoded from the image's
 * own __eh_frame) and hand it to libgcc with __register_frame. Images loaded later are added on the
 * next throw. The personality routine below parses the guest's LSDA (__gcc_except_tab, the
 * Itanium format) and matches @catch clauses through the OBJC_EHTYPE_$_Class records clang emits.
 *
 * C++ exceptions are libc++abi's (in the guest's libc++.1.dylib, over these same _Unwind_* entry
 * points). As on iOS, __objc_personality_v0 (which clang uses for every Objective-C++ function)
 * defers to __gxx_personality_v0 for them, and @catch (...) catches them through __cxa_begin_catch.
 * Objective-C exceptions are foreign to libc++abi: C++ frames run their cleanups for them and
 * catch (...) catches them. Apps' __cxa_begin_catch / __cxa_end_catch / __cxa_rethrow come here (the
 * loader interposes them), so a C++ catch of an Objective-C pointer type gets the object, as on iOS.
 *
 * Limits: compact encodings describe the frame at call sites only (enough for synchronous
 * exceptions); Swift async frames (extended frame pointer bit) are not unwound.
 */
#define _GNU_SOURCE
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unwind.h>
#include "runtime.h"

typedef struct objc_class *Class;
typedef struct objc_object { Class isa; } *id;
typedef const char *SEL;
typedef void *IMP;
struct objc_class { Class isa, superclass; void *cache, *rt; uintptr_t data; };

SEL sel_registerName(const char *s);
IMP objc_rt_lookup(id self, Class cls, SEL sel);
int class_respondsToSelector(Class c, SEL sel);
const char *class_getName(Class c);
id objc_retain(id o);
void objc_release(id o);
void isim_print_backtrace(void *frame);
int isim_image_count(void);
void *isim_image_section(int i, const char *sectname, uint64_t *size, uint8_t **base);
extern void __register_frame(void *begin);

/* ================= compact unwind -> synthetic .eh_frame ================= */
struct buf { uint8_t *p; size_t n, cap; };
static void put(struct buf *b, const void *d, size_t n) {
    if (b->n + n > b->cap) { b->cap = (b->cap ? b->cap * 2 : 4096) + n; b->p = realloc(b->p, b->cap); }
    memcpy(b->p + b->n, d, n); b->n += n;
}
static void put8(struct buf *b, uint8_t v) { put(b, &v, 1); }
static void put32(struct buf *b, uint32_t v) { put(b, &v, 4); }
static void put64(struct buf *b, uint64_t v) { put(b, &v, 8); }
static void putuleb(struct buf *b, uint64_t v) { do { uint8_t c = v & 0x7f; v >>= 7; if (v) c |= 0x80; put8(b, c); } while (v); }
static void putsleb(struct buf *b, int64_t v) {
    for (;;) { uint8_t c = v & 0x7f; v >>= 7; int done = (v == 0 && !(c & 0x40)) || (v == -1 && (c & 0x40)); if (!done) c |= 0x80; put8(b, c); if (done) break; }
}
static void pad8(struct buf *b, size_t start) { while ((b->n - start) % 8) put8(b, 0); /* DW_CFA_nop */ }

static uint64_t uleb(const uint8_t **p) { uint64_t r = 0; int s = 0; uint8_t c; do { c = *(*p)++; r |= (uint64_t)(c & 0x7f) << s; s += 7; } while (c & 0x80); return r; }
static int64_t sleb(const uint8_t **p) {
    int64_t r = 0; int s = 0; uint8_t c;
    do { c = *(*p)++; r |= (int64_t)(c & 0x7f) << s; s += 7; } while (c & 0x80);
    if (s < 64 && (c & 0x40)) r |= -((int64_t)1 << s);
    return r;
}
/* DW_EH_PE_* encoded pointer, at its original location (pcrel is relative to the field) */
static uint64_t read_enc(uint8_t enc, const uint8_t **p) {
    if (enc == 0xff) return 0;
    const uint8_t *field = *p; uint64_t v = 0;
    switch (enc & 0x0f) {
    case 0x00: case 0x04: memcpy(&v, *p, 8); *p += 8; break;
    case 0x01: v = uleb(p); break;
    case 0x02: { uint16_t x; memcpy(&x, *p, 2); *p += 2; v = x; break; }
    case 0x03: { uint32_t x; memcpy(&x, *p, 4); *p += 4; v = x; break; }
    case 0x09: v = (uint64_t)sleb(p); break;
    case 0x0a: { int16_t x; memcpy(&x, *p, 2); *p += 2; v = (uint64_t)(int64_t)x; break; }
    case 0x0b: { int32_t x; memcpy(&x, *p, 4); *p += 4; v = (uint64_t)(int64_t)x; break; }
    case 0x0c: { int64_t x; memcpy(&x, *p, 8); *p += 8; v = (uint64_t)x; break; }
    }
    if (v && (enc & 0x70) == 0x10) v += (uint64_t)(uintptr_t)field;
    if (v && (enc & 0x80)) v = *(uint64_t *)(uintptr_t)v;
    return v;
}

/* CIE: "zPLR", every pointer absolute (DW_EH_PE_absptr) */
static size_t emit_cie(struct buf *b, uint64_t personality, uint64_t code_align, int64_t data_align, uint64_t ra,
                       const uint8_t *init, size_t ninit) {
    size_t start = b->n;
    put32(b, 0); put32(b, 0); put8(b, 1); put(b, "zPLR", 5);
    putuleb(b, code_align); putsleb(b, data_align); put8(b, (uint8_t)ra);
    putuleb(b, 1 + 8 + 1 + 1); put8(b, 0x00); put64(b, personality); put8(b, 0x00); put8(b, 0x00);
    put(b, init, ninit);
    pad8(b, start + 4);
    uint32_t len = (uint32_t)(b->n - start - 4); memcpy(b->p + start, &len, 4);
    return start;
}
static void emit_fde(struct buf *b, size_t cie, uint64_t pc, uint64_t len, uint64_t lsda, const uint8_t *ins, size_t nins) {
    size_t start = b->n;
    put32(b, 0); put32(b, (uint32_t)(start + 4 - cie));
    put64(b, pc); put64(b, len); putuleb(b, 8); put64(b, lsda);
    put(b, ins, nins);
    pad8(b, start + 4);
    uint32_t l = (uint32_t)(b->n - start - 4); memcpy(b->p + start, &l, 4);
}

/* DWARF register numbers for compact unwind's register codes (1 rbx, 2 r12, 3 r13, 4 r14, 5 r15, 6 rbp) */
static const uint8_t dwreg[7] = { 0, 3, 12, 13, 14, 15, 6 };
static int ins_uleb(uint8_t *o, uint64_t v) { int n = 0; do { uint8_t c = v & 0x7f; v >>= 7; if (v) c |= 0x80; o[n++] = c; } while (v); return n; }

/* CFA instructions equivalent to an x86_64 compact unwind encoding (frame state at call sites) */
static int compact_to_cfa(uint32_t enc, uint64_t func, uint8_t *o) {
    int n = 0;
    switch ((enc >> 24) & 0xf) {
    case 1: {   /* UNWIND_X86_64_MODE_RBP_FRAME: push rbp; mov rsp, rbp; regs saved below rbp */
        uint32_t off = (enc >> 16) & 0xff, regs = enc & 0x7fff;
        o[n++] = 0x0c; o[n++] = 6; o[n++] = 16;          /* DW_CFA_def_cfa rbp+16 */
        o[n++] = 0x80 | 6; o[n++] = 2;                    /* rbp at cfa-16 */
        for (int i = 0; i < 5; i++) {
            uint32_t r = (regs >> (3 * i)) & 7;
            if (!r) continue;
            if (r > 5) return -1;
            o[n++] = 0x80 | dwreg[r]; n += ins_uleb(o + n, 2 + off - i);
        }
        return n;
    }
    case 2: case 3: {   /* FRAMELESS (immediate / indirect stack size) */
        uint64_t size = (enc >> 16) & 0xff;
        if (((enc >> 24) & 0xf) == 3) { uint32_t sub; memcpy(&sub, (const void *)(uintptr_t)(func + size), 4); size = sub + ((enc >> 13) & 7) * 8; }
        else size *= 8;
        uint32_t count = (enc >> 10) & 7, perm = enc & 0x3ff, pu[6] = {0};
        switch (count) {
        case 6: case 5: pu[0] = perm / 120; perm -= pu[0] * 120; pu[1] = perm / 24; perm -= pu[1] * 24;
                pu[2] = perm / 6; perm -= pu[2] * 6; pu[3] = perm / 2; perm -= pu[3] * 2; pu[4] = perm; break;
        case 4: pu[0] = perm / 60; perm -= pu[0] * 60; pu[1] = perm / 12; perm -= pu[1] * 12; pu[2] = perm / 3; perm -= pu[2] * 3; pu[3] = perm; break;
        case 3: pu[0] = perm / 20; perm -= pu[0] * 20; pu[1] = perm / 4; perm -= pu[1] * 4; pu[2] = perm; break;
        case 2: pu[0] = perm / 5; perm -= pu[0] * 5; pu[1] = perm; break;
        case 1: pu[0] = perm; break;
        }
        int saved[6], used[7] = {0};
        for (uint32_t i = 0; i < count; i++) {
            int renum = 0;
            for (int u = 1; u < 7; u++) if (!used[u]) { if (renum == (int)pu[i]) { saved[i] = u; used[u] = 1; break; } renum++; }
        }
        o[n++] = 0x0e; n += ins_uleb(o + n, size);       /* DW_CFA_def_cfa_offset (rsp-based, from the CIE) */
        for (uint32_t i = 0; i < count; i++) { o[n++] = 0x80 | dwreg[saved[i]]; n += ins_uleb(o + n, 1 + count - i); }
        return n;
    }
    default: return -1;
    }
}

/* re-encode one FDE (and its CIE) of the image's own __eh_frame with absolute pointers */
static void convert_dwarf_fde(struct buf *b, const uint8_t *fde, const uint8_t *eh, uint64_t ehsize) {
    if (fde < eh || fde + 8 > eh + ehsize) return;
    uint32_t len, cieoff; memcpy(&len, fde, 4); memcpy(&cieoff, fde + 4, 4);
    if (len == 0 || len == 0xffffffffu || !cieoff) return;
    const uint8_t *cie = fde + 4 - cieoff, *p = cie + 8;
    uint32_t clen; memcpy(&clen, cie, 4);
    uint8_t version = *p++;
    const char *aug = (const char *)p; p += strlen(aug) + 1;
    uint64_t code_align = uleb(&p); int64_t data_align = sleb(&p);
    uint64_t ra = version == 1 ? *p++ : uleb(&p);
    uint8_t fenc = 0, lenc = 0xff; uint64_t personality = 0;
    const uint8_t *init = p;
    if (aug[0] == 'z') {
        uint64_t alen = uleb(&p); const uint8_t *q = p; init = p + alen;
        for (const char *a = aug + 1; *a; a++) {
            if (*a == 'P') { uint8_t e = *q++; personality = read_enc(e, &q); }
            else if (*a == 'L') lenc = *q++;
            else if (*a == 'R') fenc = *q++;
        }
    }
    const uint8_t *cend = cie + 4 + clen, *fend = fde + 4 + len;
    p = fde + 8;
    uint64_t pc = read_enc(fenc, &p), range = read_enc(fenc & 0x0f, &p), lsda = 0;
    if (aug[0] == 'z') { uint64_t alen = uleb(&p); const uint8_t *q = p; if (lenc != 0xff) { const uint8_t *qq = q; lsda = read_enc(lenc, &qq); } p = q + alen; }
    size_t c = emit_cie(b, personality, code_align, data_align, ra, init, cend - init);
    emit_fde(b, c, pc, range, lsda, p, fend - p);
}

struct lsda_ent { uint32_t func, lsda; };
static void register_image(int idx) {
    uint64_t usize, ehsize; uint8_t *base;
    const uint8_t *ui = isim_image_section(idx, "__unwind_info", &usize, &base);
    if (!ui || usize < 28) return;
    uint8_t *eh = isim_image_section(idx, "__eh_frame", &ehsize, &base);
    const uint32_t *hdr = (const uint32_t *)ui;
    if (hdr[0] != 1) return;
    const uint32_t *common = (const uint32_t *)(ui + hdr[1]); uint32_t ncommon = hdr[2];
    const uint32_t *pers = (const uint32_t *)(ui + hdr[3]); uint32_t npers = hdr[4];
    const uint32_t *index = (const uint32_t *)(ui + hdr[5]); uint32_t nindex = hdr[6];
    if (nindex < 2) return;
    const struct lsda_ent *lsdas = (const void *)(ui + index[2]);
    size_t nlsda = (index[3 * (nindex - 1) + 2] - index[2]) / sizeof *lsdas;

    struct buf b = {0};
    size_t cies[4];
    static const uint8_t cie_init[] = { 0x0c, 7, 8, 0x80 | 16, 1 };   /* cfa = rsp+8, return address at cfa-8 */
    for (uint32_t k = 0; k < 4; k++) {
        uint64_t pf = k && k <= npers ? *(uint64_t *)(base + pers[k - 1]) : 0;
        cies[k] = emit_cie(&b, pf, 1, -8, 16, cie_init, sizeof cie_init);
    }
    size_t nfde = 0;
    for (uint32_t t = 0; t + 1 < nindex; t++) {
        const uint32_t *ie = index + 3 * t;
        uint32_t fbase = ie[0], next_top = index[3 * (t + 1)];
        if (!ie[1]) continue;
        const uint8_t *page = ui + ie[1];
        uint32_t kind; memcpy(&kind, page, 4);
        uint16_t eoff, ecount; memcpy(&eoff, page + 4, 2); memcpy(&ecount, page + 6, 2);
        for (uint32_t e = 0; e < ecount; e++) {
            uint32_t foff, enc, fend;
            if (kind == 3) {        /* compressed page */
                uint16_t encoff, enccount; memcpy(&encoff, page + 8, 2); memcpy(&enccount, page + 10, 2);
                const uint32_t *ents = (const uint32_t *)(page + eoff);
                uint32_t ix = ents[e] >> 24;
                foff = fbase + (ents[e] & 0xffffff);
                enc = ix < ncommon ? common[ix] : ((const uint32_t *)(page + encoff))[ix - ncommon];
                fend = e + 1 < ecount ? fbase + (ents[e + 1] & 0xffffff) : next_top;
            } else if (kind == 2) { /* regular page */
                const uint32_t *ents = (const uint32_t *)(page + eoff);
                foff = ents[2 * e]; enc = ents[2 * e + 1];
                fend = e + 1 < ecount ? ents[2 * e + 2] : next_top;
            } else break;
            if (!enc || fend <= foff) continue;
            uint64_t func = (uint64_t)(uintptr_t)(base + foff);
            if (((enc >> 24) & 0xf) == 4) {        /* UNWIND_X86_64_MODE_DWARF: FDE in __eh_frame */
                if (eh) { convert_dwarf_fde(&b, eh + (enc & 0xffffff), eh, ehsize); nfde++; }
                continue;
            }
            uint64_t lsda = 0;
            if (enc & 0x40000000u) {               /* UNWIND_HAS_LSDA */
                size_t lo = 0, hi = nlsda;
                while (lo < hi) { size_t m = (lo + hi) / 2; if (lsdas[m].func < foff) lo = m + 1; else hi = m; }
                if (lo < nlsda && lsdas[lo].func == foff) lsda = (uint64_t)(uintptr_t)(base + lsdas[lo].lsda);
            }
            uint8_t ins[64]; int n = compact_to_cfa(enc, func, ins);
            if (n < 0) continue;
            emit_fde(&b, cies[(enc >> 28) & 3], func, fend - foff, lsda, ins, n);
            nfde++;
        }
    }
    put32(&b, 0);                                  /* terminator */
    if (nfde) __register_frame(b.p);               /* libgcc keeps the pointer; never freed (images stay loaded) */
    else free(b.p);
    if (isim_verbose) fprintf(stderr, "isim objc: registered %zu unwind entries for image %d\n", nfde, idx);
}

static pthread_mutex_t reg_lock = PTHREAD_MUTEX_INITIALIZER;
static int nregistered;
void isim_unwind_register_images(void) {
    pthread_mutex_lock(&reg_lock);
    for (int n = isim_image_count(); nregistered < n; nregistered++) register_image(nregistered);
    pthread_mutex_unlock(&reg_lock);
}

/* ================= Objective-C exception objects ================= */
#define OBJC_EXC_CLASS 0x4953494d4f424a43ull       /* "ISIMOBJC" */
struct objc_exc { id obj; struct _Unwind_Exception ue; };
#define EXC_OF(u) ((struct objc_exc *)((char *)(u) - offsetof(struct objc_exc, ue)))

/* typeinfo records for @catch clauses: OBJC_EHTYPE_$_Class = { objc_ehtype_vtable+2, name, class } */
struct objc_typeinfo { const void *vtable; const char *name; Class cls; };
static void ehtype_noop(void) {}
static int ehtype_false(void) { return 0; }
void *objc_ehtype_vtable[10] = { NULL, NULL, (void *)ehtype_noop, (void *)ehtype_noop, (void *)ehtype_false,
                                 (void *)ehtype_false, (void *)ehtype_false, (void *)ehtype_false, (void *)ehtype_false, (void *)ehtype_false };
struct objc_typeinfo OBJC_EHTYPE_id = { &objc_ehtype_vtable[2], "id", NULL };

typedef void (*objc_uncaught_exception_handler)(id);
typedef id (*objc_exception_preprocessor)(id);
static objc_uncaught_exception_handler uncaught_handler;
static objc_exception_preprocessor preprocessor;
objc_uncaught_exception_handler objc_setUncaughtExceptionHandler(objc_uncaught_exception_handler h) { objc_uncaught_exception_handler o = uncaught_handler; uncaught_handler = h; return o; }
objc_exception_preprocessor objc_setExceptionPreprocessor(objc_exception_preprocessor p) { objc_exception_preprocessor o = preprocessor; preprocessor = p; return o; }

static int is_objc(const struct _Unwind_Exception *ue) { return ue->exception_class == OBJC_EXC_CLASS; }
static int matches(struct _Unwind_Exception *ue, const struct objc_typeinfo *ti) {
    if (!ti) return 1;                                         /* catch-all (@catch (...), C++ catch (...)) */
    if (!is_objc(ue) || ti->vtable != &objc_ehtype_vtable[2]) return 0;
    if (ti == &OBJC_EHTYPE_id || !ti->cls) return 1;           /* @catch (id e) */
    id o = EXC_OF(ue)->obj;
    for (Class c = o ? o->isa : NULL; c; c = c->superclass) if (c == ti->cls) return 1;
    return 0;
}

enum { SCAN_NONE, SCAN_CLEANUP, SCAN_HANDLER };
static int scan_lsda(struct _Unwind_Context *ctx, struct _Unwind_Exception *ue, uintptr_t *lp, int64_t *sel) {
    const uint8_t *p = _Unwind_GetLanguageSpecificData(ctx);
    if (!p) return SCAN_NONE;
    int before = 0;
    uintptr_t ip = _Unwind_GetIPInfo(ctx, &before);
    if (!before) ip--;
    uintptr_t func = _Unwind_GetRegionStart(ctx);
    uint8_t lpenc = *p++;
    uintptr_t lpstart = lpenc == 0xff ? func : read_enc(lpenc, &p);
    uint8_t ttenc = *p++;
    const uint8_t *ttbase = NULL;
    if (ttenc != 0xff) { uint64_t off = uleb(&p); ttbase = p + off; }
    uint8_t csenc = *p++;
    uint64_t cslen = uleb(&p);
    const uint8_t *cs = p, *actions = p + cslen;
    while (cs < actions) {
        uint64_t start = read_enc(csenc, &cs), len = read_enc(csenc, &cs), land = read_enc(csenc, &cs), act = uleb(&cs);
        if (ip < func + start) break;
        if (ip >= func + start + len) continue;
        if (!land) return SCAN_NONE;
        *lp = lpstart + land; *sel = 0;
        if (!act) return SCAN_CLEANUP;
        const uint8_t *ap = actions + act - 1;
        int cleanup = 0;
        for (;;) {
            int64_t filter = sleb(&ap);
            const uint8_t *np = ap;
            int64_t disp = sleb(&ap);
            if (filter == 0) cleanup = 1;
            else if (filter > 0 && ttbase) {
                size_t sz = (ttenc & 7) == 2 ? 2 : (ttenc & 7) == 3 ? 4 : 8;
                const uint8_t *e = ttbase - filter * sz;
                const struct objc_typeinfo *ti = (const void *)(uintptr_t)read_enc(ttenc, &e);
                if (matches(ue, ti)) { *sel = filter; return SCAN_HANDLER; }
            } else if (filter < 0 && is_objc(ue)) {          /* C++ exception specification: never lists ObjC types */
                *sel = filter; return SCAN_HANDLER;
            }
            if (!disp) break;
            ap = np + disp;
        }
        return cleanup ? SCAN_CLEANUP : SCAN_NONE;
    }
    return SCAN_NONE;
}

/* libc++abi's entry points in the guest's libc++.1.dylib (NULL while it is not loaded) */
typedef _Unwind_Reason_Code (*personality_fn)(int, _Unwind_Action, uint64_t, struct _Unwind_Exception *, struct _Unwind_Context *);
void *isim_lookup_image_symbol(const char *sym);
static void *cxxabi(const char *sym, void **cache) {
    void *f = __atomic_load_n(cache, __ATOMIC_ACQUIRE);
    if (!f && (f = isim_lookup_image_symbol(sym))) __atomic_store_n(cache, f, __ATOMIC_RELEASE);
    return f;
}
static void *__gxx_personality_v0_p, *__cxa_begin_catch_p, *__cxa_end_catch_p, *__cxa_rethrow_p;
#define CXXABI(name) cxxabi("_" #name, &name##_p)

_Unwind_Reason_Code isim_objc_personality(int version, _Unwind_Action actions, uint64_t cls,
                                          struct _Unwind_Exception *ue, struct _Unwind_Context *ctx);
/* libSystem's __gxx_personality_v0 (apps built before isim had libc++abi bound it there): libc++abi's */
_Unwind_Reason_Code isim_gxx_personality(int version, _Unwind_Action actions, uint64_t cls,
                                         struct _Unwind_Exception *ue, struct _Unwind_Context *ctx) {
    personality_fn gxx = CXXABI(__gxx_personality_v0);
    return gxx ? gxx(version, actions, cls, ue, ctx) : isim_objc_personality(version, actions, cls, ue, ctx);
}

/* __objc_personality_v0: Objective-C exceptions here; C++ exceptions go to libc++abi's personality, which
   skips @catch clauses (their typeinfo's can_catch slot answers false) */
_Unwind_Reason_Code isim_objc_personality(int version, _Unwind_Action actions, uint64_t cls,
                                          struct _Unwind_Exception *ue, struct _Unwind_Context *ctx) {
    if (version != 1 || !ue || !ctx) return _URC_FATAL_PHASE1_ERROR;
    if (!is_objc(ue)) {
        personality_fn gxx = CXXABI(__gxx_personality_v0);
        if (gxx) return gxx(version, actions, cls, ue, ctx);
    }
    uintptr_t lp = 0; int64_t sel = 0;
    int r = scan_lsda(ctx, ue, &lp, &sel);
    if (actions & _UA_SEARCH_PHASE) return r == SCAN_HANDLER ? _URC_HANDLER_FOUND : _URC_CONTINUE_UNWIND;
    if (actions & _UA_HANDLER_FRAME) { if (r != SCAN_HANDLER) return _URC_FATAL_PHASE2_ERROR; }
    else if (r == SCAN_NONE) return _URC_CONTINUE_UNWIND;
    else sel = 0;                                             /* cleanup (or forced unwind): run the pad, it resumes */
    _Unwind_SetGR(ctx, __builtin_eh_return_data_regno(0), (uintptr_t)ue);
    _Unwind_SetGR(ctx, __builtin_eh_return_data_regno(1), (uintptr_t)sel);
    _Unwind_SetIP(ctx, lp);
    return _URC_INSTALL_CONTEXT;
}

static id msg0(id o, const char *s) { SEL sel = sel_registerName(s); return ((id (*)(id, SEL))objc_rt_lookup(o, o->isa, sel))(o, sel); }
static const char *utf8_of(id str) { return str ? (const char *)msg0(str, "UTF8String") : NULL; }
static int responds(id o, const char *s) { return o && class_respondsToSelector(o->isa, sel_registerName(s)); }

__attribute__((noreturn)) static void terminate_uncaught(id obj) {
    fflush(NULL);
    const char *cname = obj ? class_getName(obj->isa) : "nil";
    int isNS = 0;
    if (obj && responds(obj, "name") && responds(obj, "reason")) {
        const char *n = utf8_of(msg0(obj, "name")), *r = utf8_of(msg0(obj, "reason"));
        fprintf(stderr, "*** Terminating app due to uncaught exception '%s', reason: '%s'\n", n ? n : "(null)", r ? r : "(null)");
        isNS = 1;
    } else fprintf(stderr, "*** Terminating app due to uncaught exception of class '%s'\n", cname);
    fprintf(stderr, "*** First throw call stack:\n");
    isim_print_backtrace(__builtin_frame_address(0));
    fflush(stderr);
    if (uncaught_handler) uncaught_handler(obj);
    fflush(NULL);
    fprintf(stderr, "libc++abi: terminating due to uncaught exception of type %s\n", isNS ? "NSException" : cname);
    signal(SIGABRT, SIG_DFL);
    abort();
}

static void exc_cleanup(_Unwind_Reason_Code rc, struct _Unwind_Exception *ue) {
    struct objc_exc *e = EXC_OF(ue);
    objc_release(e->obj);
    free(e);
}

void objc_exception_throw(id obj) {
    if (preprocessor) obj = preprocessor(obj);
    isim_unwind_register_images();
    struct objc_exc *e = calloc(1, sizeof *e);
    e->obj = objc_retain(obj);
    e->ue.exception_class = OBJC_EXC_CLASS;
    e->ue.exception_cleanup = exc_cleanup;
    if (getenv("ISIM_OBJC_EXCEPTION_LOG"))
        fprintf(stderr, "isim objc: throwing %s %p\n", obj ? class_getName(obj->isa) : "nil", (void *)obj);
    _Unwind_RaiseException(&e->ue);
    terminate_uncaught(obj);                                  /* no handler: the stack is intact (phase 1 failed) */
}

/* currently caught exceptions of this thread (innermost first); a C++ exception caught by @catch (...) is libc++abi's
   to track (__cxa_begin_catch / __cxa_end_catch / __cxa_rethrow), as on iOS */
struct caught { struct _Unwind_Exception *ue; int count, rethrown, cxx; struct caught *next; };
static __thread struct caught *caught_stack;

/* a handler begins: C++ exceptions are libc++abi's (its adjusted pointer), Objective-C ones are tracked here (their object) */
static void *begin_catch(void *exc) {
    struct _Unwind_Exception *ue = exc;
    void *(*begin)(void *) = is_objc(ue) ? NULL : CXXABI(__cxa_begin_catch);
    if (begin) {
        void *adjusted = begin(ue);
        struct caught *c = calloc(1, sizeof *c);
        c->ue = ue; c->count = 1; c->cxx = 1; c->next = caught_stack; caught_stack = c;
        return adjusted;
    }
    if (caught_stack && caught_stack->ue == ue && !caught_stack->cxx) { caught_stack->count++; caught_stack->rethrown = 0; }
    else {
        struct caught *c = calloc(1, sizeof *c);
        c->ue = ue; c->count = 1; c->next = caught_stack; caught_stack = c;
    }
    return is_objc(ue) ? EXC_OF(ue)->obj : NULL;
}
id objc_begin_catch(void *exc) { return is_objc(exc) ? begin_catch(exc) : (begin_catch(exc), NULL); }
void objc_end_catch(void) {
    struct caught *c = caught_stack;
    if (!c || --c->count > 0) return;
    caught_stack = c->next;
    if (c->cxx) ((void (*)(void))CXXABI(__cxa_end_catch))();
    else if (!c->rethrown) _Unwind_DeleteException(c->ue);
    free(c);
}
void objc_exception_rethrow(void) {
    struct caught *c = caught_stack;
    if (!c) { fflush(NULL); fputs("isim objc: objc_exception_rethrow with no exception being handled\n", stderr); signal(SIGABRT, SIG_DFL); abort(); }
    if (c->cxx) ((void (*)(void))CXXABI(__cxa_rethrow))();  /* does not return; the landing pad ends the catch */
    c->rethrown = 1;
    _Unwind_RaiseException(c->ue);
    terminate_uncaught(is_objc(c->ue) ? EXC_OF(c->ue)->obj : NULL);
}
void objc_terminate(void) {
    if (caught_stack && is_objc(caught_stack->ue)) terminate_uncaught(EXC_OF(caught_stack->ue)->obj);
    fflush(NULL); fputs("isim objc: objc_terminate\n", stderr);
    signal(SIGABRT, SIG_DFL);
    abort();
}

/* _Unwind_* entry points for guest code that raise directly: register the guest images first */
/* C++ handlers in guest code (the loader binds their __cxa_begin_catch / __cxa_end_catch / __cxa_rethrow here, not to
   libc++abi): an Objective-C exception caught by a C++ catch (catch (NSException *e), catch (...)) gets its object and
   is ended or rethrown here, as on iOS, where Objective-C exceptions are C++ ones; C++ exceptions go to libc++abi */
void *isim_cxa_begin_catch(void *exc) { return begin_catch(exc); }
void isim_cxa_end_catch(void) { objc_end_catch(); }
void isim_cxa_rethrow(void) {
    if (caught_stack) objc_exception_rethrow();
    ((void (*)(void))CXXABI(__cxa_rethrow))();                  /* nothing caught: libc++abi terminates */
}

_Unwind_Reason_Code isim_unwind_raise(struct _Unwind_Exception *ue) { isim_unwind_register_images(); return _Unwind_RaiseException(ue); }
_Unwind_Reason_Code isim_unwind_backtrace(_Unwind_Trace_Fn fn, void *arg) { isim_unwind_register_images(); return _Unwind_Backtrace(fn, arg); }
