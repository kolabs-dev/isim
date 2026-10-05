/*
 * isim loader: loads an x86_64 iOS-Simulator Mach-O executable and its dylib
 * dependencies on Linux, applies fixups, registers Objective-C metadata, runs
 * initializers and calls main().
 *
 * Supported: MH_EXECUTE/MH_DYLIB, LC_BUILD_VERSION platform IOSSIMULATOR only,
 * legacy rebase/bind opcodes (lazy binds resolved eagerly), chained fixups
 * (DYLD_CHAINED_PTR_64 / _64_OFFSET), export tries (LC_DYLD_EXPORTS_TRIE or
 * dyld_info), two-level namespace + flat lookup, re-exports of symbols,
 * @rpath/@executable_path/@loader_path, __mod_init_func and __init_offsets.
 * Host pseudo-libraries (libSystem, libobjc, libisim_host) are tables of
 * Linux-native functions (runtime.h).
 *
 * Not supported: fat files, thread-local variables, weak-def coalescing,
 * dlopen, code signature validation, dyld interposing, DYLD_* env vars.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <signal.h>
#include <ucontext.h>
#include <libgen.h>
#include <limits.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include "macho.h"
#include "runtime.h"

#define MAX_SEGS 32
#define MAX_DEPS 64
#define MAX_IMAGES 128

struct image {
    char *path;
    const char *install_name;
    uint8_t *file; size_t file_size;
    const struct mach_header_64 *mh;
    struct segment_command_64 *segs[MAX_SEGS]; int nsegs;
    uint64_t slide; uint8_t *base; uint64_t span;
    int ndeps;
    const char *dep_names[MAX_DEPS];
    struct image *deps[MAX_DEPS];        /* NULL when the dependency is a host library */
    const struct host_lib *host_deps[MAX_DEPS];
    int dep_reexport[MAX_DEPS];
    const char *rpaths[16]; int nrpaths;
    const struct dyld_info_command *dyld_info;
    const struct linkedit_data_command *chained, *exports;
    const struct entry_point_command *entry;
    int objc_mapped, initialized;
};

static struct image *images[MAX_IMAGES];
static int nimages;
static struct image *main_image;
static const char *sysroot;
static int unresolved_count;
int isim_verbose;

static const struct host_lib *const host_libs[] = { &host_libsystem, &host_libobjc, &host_isim };

void isim_fatal(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    fflush(NULL);
    fputs("isim: ", stderr); vfprintf(stderr, fmt, ap); fputc('\n', stderr);
    va_end(ap);
    exit(127);
}

const char *isim_main_executable_path(void) { return main_image ? main_image->path : NULL; }

static const struct shim dyld_table[];
static const size_t dyld_table_count;
const struct shim *host_lib_lookup(const struct host_lib *lib, const char *name) {
    for (size_t i = 0; i < lib->count; i++) if (!strcmp(lib->table[i].name, name)) return &lib->table[i];
    if (lib == &host_libsystem)            /* libdyld lives inside the libSystem umbrella on Darwin */
        for (size_t i = 0; i < dyld_table_count; i++) if (!strcmp(dyld_table[i].name, name)) return &dyld_table[i];
    return NULL;
}

static const struct host_lib *host_lib_for(const char *install_name) {
    for (size_t i = 0; i < sizeof host_libs / sizeof *host_libs; i++)
        if (!strcmp(host_libs[i]->install_name, install_name)) return host_libs[i];
    if (!strncmp(install_name, "/usr/lib/system/", 16)) return &host_libsystem; /* libSystem sub-libraries */
    return NULL;
}

/* ---------------- traps for unresolved imports ---------------- */
static void unresolved_called(const char *name) {
    fflush(NULL);
    fprintf(stderr, "isim: FATAL: guest called unimplemented function %s\n", name);
    abort();
}
static void *make_trap(const char *name) {
    static uint8_t *page; static size_t used;
    if (!page || used + 32 > 4096) {
        page = mmap(NULL, 4096, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (page == MAP_FAILED) isim_fatal("trap mmap failed");
        used = 0;
    }
    uint8_t *p = page + used; used += 32;
    p[0] = 0x48; p[1] = 0xBF; memcpy(p + 2, &name, 8);                 /* movabs rdi, name */
    void *fn = (void *)unresolved_called;
    p[10] = 0x48; p[11] = 0xB8; memcpy(p + 12, &fn, 8);                /* movabs rax, fn */
    p[20] = 0xFF; p[21] = 0xE0;                                        /* jmp rax */
    return p;
}

/* ---------------- LEB128 ---------------- */
static uint64_t uleb(const uint8_t **p, const uint8_t *end) {
    uint64_t r = 0; int shift = 0;
    while (*p < end) { uint8_t b = *(*p)++; if (shift < 64) r |= (uint64_t)(b & 0x7f) << shift; shift += 7; if (!(b & 0x80)) break; }
    return r;
}
static int64_t sleb(const uint8_t **p, const uint8_t *end) {
    int64_t r = 0; int shift = 0; uint8_t b = 0;
    while (*p < end) { b = *(*p)++; r |= (int64_t)(b & 0x7f) << shift; shift += 7; if (!(b & 0x80)) break; }
    if (shift < 64 && (b & 0x40)) r |= -((int64_t)1 << shift);
    return r;
}

/* ---------------- export trie ---------------- */
static int image_export(struct image *im, const char *sym, uint64_t *addr, int depth);

static int trie_lookup(struct image *im, const uint8_t *trie, uint32_t size, const char *sym, uint64_t *addr, int depth) {
    const uint8_t *end = trie + size, *p = trie;
    const char *s = sym;
    for (int guard = 0; guard < 4096; guard++) {
        if (p >= end) return 0;
        const uint8_t *node = p;
        uint64_t term = uleb(&p, end);
        if (*s == 0 && term) {
            uint64_t flags = uleb(&p, end);
            if (flags & 0x08) {                                    /* EXPORT_SYMBOL_FLAGS_REEXPORT */
                uint64_t ord = uleb(&p, end);
                const char *imported = (const char *)p;
                if (!*imported) imported = sym;
                if (ord < 1 || ord > (uint64_t)im->ndeps) return 0;
                struct image *dep = im->deps[ord - 1];
                if (dep) return image_export(dep, imported, addr, depth + 1);
                const struct shim *sh = host_lib_lookup(im->host_deps[ord - 1], imported);
                if (sh) { *addr = (uint64_t)(uintptr_t)sh->addr; return 1; }
                return 0;
            }
            if (flags & 0x10) isim_fatal("%s: stub-and-resolver export %s unsupported", im->path, sym);
            uint64_t off = uleb(&p, end);
            if ((flags & 3) == 2) *addr = off;                     /* absolute */
            else if ((flags & 3) == 1) isim_fatal("%s: thread-local export %s unsupported", im->path, sym);
            else *addr = (uint64_t)(uintptr_t)im->base + off;
            return 1;
        }
        p = node; uleb(&p, end); p = node + (p - node) + term;     /* skip terminal info */
        if (p >= end) return 0;
        uint8_t nchild = *p++;
        const uint8_t *next = NULL;
        for (uint8_t c = 0; c < nchild; c++) {
            const char *edge = (const char *)p;
            size_t elen = strnlen(edge, end - p);
            p += elen + 1;
            uint64_t child = uleb(&p, end);
            if (!next && !strncmp(s, edge, elen)) { next = trie + child; s += elen; }
        }
        if (!next) return 0;
        p = next;
    }
    return 0;
}

static int image_export(struct image *im, const char *sym, uint64_t *addr, int depth) {
    if (depth > 8) return 0;
    if (im->exports && trie_lookup(im, im->file + im->exports->dataoff, im->exports->datasize, sym, addr, depth)) return 1;
    if (im->dyld_info && im->dyld_info->export_size &&
        trie_lookup(im, im->file + im->dyld_info->export_off, im->dyld_info->export_size, sym, addr, depth)) return 1;
    for (int i = 0; i < im->ndeps; i++) {                          /* LC_REEXPORT_DYLIB */
        if (!im->dep_reexport[i]) continue;
        if (im->deps[i] && image_export(im->deps[i], sym, addr, depth + 1)) return 1;
        if (!im->deps[i]) { const struct shim *sh = host_lib_lookup(im->host_deps[i], sym); if (sh) { *addr = (uint64_t)(uintptr_t)sh->addr; return 1; } }
    }
    return 0;
}

/* Symbols that alias another symbol (Apple ships these as aliases/"class-ified" data). */
static const char *const aliases[][2] = {
    { "___CFConstantStringClassReference", "_OBJC_CLASS_$___NSCFConstantString" },
};

void *isim_lookup_symbol(const char *sym) {
    for (size_t i = 0; i < sizeof aliases / sizeof *aliases; i++)
        if (!strcmp(sym, aliases[i][0])) sym = aliases[i][1];
    uint64_t a;
    for (int i = 0; i < nimages; i++) if (image_export(images[i], sym, &a, 0)) return (void *)(uintptr_t)a;
    for (size_t i = 0; i < sizeof host_libs / sizeof *host_libs; i++) {
        const struct shim *s = host_lib_lookup(host_libs[i], sym);
        if (s) return s->addr;
    }
    return NULL;
}

static uint64_t resolve(struct image *im, int ordinal, const char *sym, int weak) {
    for (size_t i = 0; i < sizeof aliases / sizeof *aliases; i++)
        if (!strcmp(sym, aliases[i][0])) { void *p = isim_lookup_symbol(sym); if (p) return (uint64_t)(uintptr_t)p; }
    uint64_t a = 0; int found = 0; const char *from = "flat namespace";
    if (ordinal > 0 && ordinal <= im->ndeps) {
        from = im->dep_names[ordinal - 1];
        if (im->deps[ordinal - 1]) found = image_export(im->deps[ordinal - 1], sym, &a, 0);
        else if (im->host_deps[ordinal - 1]) {
            const struct shim *s = host_lib_lookup(im->host_deps[ordinal - 1], sym);
            if (s) { a = (uint64_t)(uintptr_t)s->addr; found = 1; }
            else if (im->host_deps[ordinal - 1] != &host_libobjc) {
                /* libSystem umbrella: Apple re-exports libobjc-adjacent symbols; accept host tables */
                void *p = isim_lookup_symbol(sym); if (p) { a = (uint64_t)(uintptr_t)p; found = 1; }
            }
        }
    } else if (ordinal == 0) {
        found = image_export(im, sym, &a, 0); from = "self";
    } else if (ordinal == -1) {
        found = image_export(main_image, sym, &a, 0); from = "main executable";
    } else {                                                        /* -2 flat, -3 weak lookup */
        void *p = isim_lookup_symbol(sym); if (p) { a = (uint64_t)(uintptr_t)p; found = 1; }
    }
    if (found) return a;
    if (weak) return 0;
    unresolved_count++;
    fprintf(stderr, "isim: warning: unresolved symbol %s (expected in %s, referenced from %s)\n", sym, from, im->path);
    return (uint64_t)(uintptr_t)make_trap(strdup(sym));
}

/* ---------------- fixups ---------------- */
static uint64_t *seg_ptr(struct image *im, int seg, uint64_t off) {
    if (seg < 0 || seg >= im->nsegs || off + 8 > im->segs[seg]->vmsize) isim_fatal("%s: fixup outside segment", im->path);
    return (uint64_t *)(uintptr_t)(im->segs[seg]->vmaddr + im->slide + off);
}

static void do_rebase(struct image *im, const uint8_t *p, const uint8_t *end) {
    int seg = 0; uint64_t off = 0;
    while (p < end) {
        uint8_t b = *p++, op = b & 0xF0, imm = b & 0x0F;
        switch (op) {
        case 0x00: return;
        case 0x10: break;
        case 0x20: seg = imm; off = uleb(&p, end); break;
        case 0x30: off += uleb(&p, end); break;
        case 0x40: off += imm * 8; break;
        case 0x50: for (int i = 0; i < imm; i++) { *seg_ptr(im, seg, off) += im->slide; off += 8; } break;
        case 0x60: { uint64_t n = uleb(&p, end); for (uint64_t i = 0; i < n; i++) { *seg_ptr(im, seg, off) += im->slide; off += 8; } break; }
        case 0x70: *seg_ptr(im, seg, off) += im->slide; off += 8 + uleb(&p, end); break;
        case 0x80: { uint64_t n = uleb(&p, end), skip = uleb(&p, end);
                     for (uint64_t i = 0; i < n; i++) { *seg_ptr(im, seg, off) += im->slide; off += 8 + skip; } break; }
        default: isim_fatal("%s: bad rebase opcode 0x%x", im->path, b);
        }
    }
}

static void do_bind(struct image *im, const uint8_t *p, const uint8_t *end, int lazy) {
    int seg = 0, ordinal = 0, weak = 0; uint64_t off = 0; int64_t addend = 0; const char *sym = NULL;
    while (p < end) {
        uint8_t b = *p++, op = b & 0xF0, imm = b & 0x0F;
        switch (op) {
        case 0x00: if (!lazy) return; break;
        case 0x10: ordinal = imm; break;
        case 0x20: ordinal = (int)uleb(&p, end); break;
        case 0x30: ordinal = imm ? (int8_t)(0xF0 | imm) : 0; break;
        case 0x40: sym = (const char *)p; weak = imm & 1; p += strlen(sym) + 1; break;
        case 0x50: if (imm != 1) isim_fatal("%s: non-pointer bind", im->path); break;
        case 0x60: addend = sleb(&p, end); break;
        case 0x70: seg = imm; off = uleb(&p, end); break;
        case 0x80: off += uleb(&p, end); break;
        case 0x90: *seg_ptr(im, seg, off) = resolve(im, ordinal, sym, weak) + addend; off += 8; break;
        case 0xA0: *seg_ptr(im, seg, off) = resolve(im, ordinal, sym, weak) + addend; off += 8 + uleb(&p, end); break;
        case 0xB0: *seg_ptr(im, seg, off) = resolve(im, ordinal, sym, weak) + addend; off += 8 + imm * 8; break;
        case 0xC0: { uint64_t n = uleb(&p, end), skip = uleb(&p, end); uint64_t v = resolve(im, ordinal, sym, weak) + addend;
                     for (uint64_t i = 0; i < n; i++) { *seg_ptr(im, seg, off) = v; off += 8 + skip; } break; }
        default: isim_fatal("%s: unsupported bind opcode 0x%x", im->path, b);
        }
    }
}

struct cf_header { uint32_t version, starts_offset, imports_offset, symbols_offset, imports_count, imports_format, symbols_format; };
struct cf_starts_seg { uint32_t size; uint16_t page_size, pointer_format; uint64_t segment_offset; uint32_t max_valid_pointer; uint16_t page_count, page_start[]; };

static void do_chained(struct image *im) {
    const uint8_t *blob = im->file + im->chained->dataoff;
    const struct cf_header *h = (const void *)blob;
    if (h->version != 0 || h->symbols_format != 0) isim_fatal("%s: unsupported chained fixups header", im->path);
    uint64_t *targets = calloc(h->imports_count + 1, sizeof *targets);
    const char *names = (const char *)blob + h->symbols_offset;
    const uint8_t *imp = blob + h->imports_offset;
    for (uint32_t i = 0; i < h->imports_count; i++) {
        int ord = 0, weak = 0; uint32_t name_off = 0; int64_t addend = 0;
        if (h->imports_format == 1 || h->imports_format == 2) {
            uint32_t v; memcpy(&v, imp, 4);
            ord = (int8_t)(v & 0xff); weak = (v >> 8) & 1; name_off = v >> 9;
            if (h->imports_format == 2) { int32_t a; memcpy(&a, imp + 4, 4); addend = a; imp += 8; } else imp += 4;
        } else if (h->imports_format == 3) {
            uint64_t v; memcpy(&v, imp, 8);
            ord = (int16_t)(v & 0xffff); weak = (v >> 16) & 1; name_off = (uint32_t)(v >> 32);
            memcpy(&addend, imp + 8, 8); imp += 16;
        } else isim_fatal("%s: unknown chained imports format", im->path);
        targets[i] = resolve(im, ord, names + name_off, weak) + addend;
    }
    const uint8_t *starts = blob + h->starts_offset;
    uint32_t seg_count; memcpy(&seg_count, starts, 4);
    for (uint32_t s = 0; s < seg_count; s++) {
        uint32_t info_off; memcpy(&info_off, starts + 4 + 4 * s, 4);
        if (!info_off) continue;
        const struct cf_starts_seg *ss = (const void *)(starts + info_off);
        if (ss->pointer_format != 2 && ss->pointer_format != 6)
            isim_fatal("%s: chained pointer format %u unsupported", im->path, ss->pointer_format);
        for (uint16_t pg = 0; pg < ss->page_count; pg++) {
            uint16_t start = ss->page_start[pg];
            if (start == 0xFFFF) continue;
            if (start & 0x8000) isim_fatal("%s: DYLD_CHAINED_PTR_START_MULTI unsupported", im->path);
            uint8_t *loc = im->base + ss->segment_offset + (uint64_t)pg * ss->page_size + start;
            for (;;) {
                uint64_t raw; memcpy(&raw, loc, 8);
                uint64_t next = (raw >> 51) & 0xFFF, val;
                if (raw >> 63) {
                    uint32_t ord = raw & 0xFFFFFF; int64_t add = (raw >> 24) & 0xFF;
                    if (ord >= h->imports_count) isim_fatal("%s: bind ordinal out of range", im->path);
                    val = targets[ord] + add;
                } else {
                    uint64_t target = raw & 0xFFFFFFFFFull, high8 = (raw >> 36) & 0xFF;
                    val = (ss->pointer_format == 2 ? target + im->slide : (uint64_t)(uintptr_t)im->base + target) | (high8 << 56);
                }
                memcpy(loc, &val, 8);
                if (!next) break;
                loc += next * 4;
            }
        }
    }
    free(targets);
}

/* ---------------- loading ---------------- */
static int is_mapped_seg(const struct segment_command_64 *s) { return s->vmsize && (s->initprot || s->maxprot); }
static int prot_of(uint32_t v) { return (v & 1 ? PROT_READ : 0) | (v & 2 ? PROT_WRITE : 0) | (v & 4 ? PROT_EXEC : 0); }

static char *expand_path(struct image *loader, const char *name) {
    char buf[PATH_MAX];
    if (!strncmp(name, "@executable_path/", 17)) {
        char *d = strdup(main_image ? main_image->path : loader->path);
        snprintf(buf, sizeof buf, "%s/%s", dirname(d), name + 17); free(d);
        return strdup(buf);
    }
    if (!strncmp(name, "@loader_path/", 13)) {
        char *d = strdup(loader->path);
        snprintf(buf, sizeof buf, "%s/%s", dirname(d), name + 13); free(d);
        return strdup(buf);
    }
    if (!strncmp(name, "@rpath/", 7)) {
        struct image *chain[2] = { loader, main_image };
        for (int c = 0; c < 2; c++) {
            if (!chain[c]) continue;
            for (int i = 0; i < chain[c]->nrpaths; i++) {
                char rp[PATH_MAX]; snprintf(rp, sizeof rp, "%s/%s", chain[c]->rpaths[i], name + 7);
                char *full = expand_path(chain[c], rp);
                if (access(full, R_OK) == 0) return full;
                free(full);
            }
        }
        return NULL;
    }
    if (name[0] == '/') { snprintf(buf, sizeof buf, "%s%s", sysroot, name); return strdup(buf); }
    return strdup(name);
}

static struct image *find_loaded(const char *install_name, const char *path) {
    for (int i = 0; i < nimages; i++) {
        if (install_name && images[i]->install_name && !strcmp(images[i]->install_name, install_name)) return images[i];
        if (path && !strcmp(images[i]->path, path)) return images[i];
    }
    return NULL;
}

static struct image *load_image(const char *path, int want_type);

static struct image *map_image(const char *path, int want_type) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return NULL;
    struct stat st; fstat(fd, &st);
    struct image *im = calloc(1, sizeof *im);
    im->path = realpath(path, NULL); if (!im->path) im->path = strdup(path);
    im->file_size = st.st_size;
    im->file = mmap(NULL, im->file_size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (im->file == MAP_FAILED) isim_fatal("%s: mmap failed", path);
    im->mh = (const void *)im->file;
    if (im->file_size < sizeof *im->mh || im->mh->magic != MH_MAGIC_64)
        isim_fatal("%s: not a thin 64-bit Mach-O (fat files unsupported)", path);
    if (im->mh->cputype != CPU_TYPE_X86_64)
        isim_fatal("%s: not x86_64 (arm64 device binaries are not runnable here)", path);
    if (want_type == 0 && (im->mh->filetype == MH_EXECUTE || im->mh->filetype == MH_DYLIB || im->mh->filetype == 8 /* MH_BUNDLE */)) { /* dlopen */ }
    else if (im->mh->filetype != (uint32_t)want_type)
        isim_fatal("%s: unexpected Mach-O filetype %u", path, im->mh->filetype);

    int platform = -1;
    const uint8_t *lc = im->file + sizeof *im->mh;
    for (uint32_t i = 0; i < im->mh->ncmds; i++) {
        const struct load_command *c = (const void *)lc;
        switch (c->cmd) {
        case LC_SEGMENT_64: if (im->nsegs < MAX_SEGS) im->segs[im->nsegs++] = (void *)c; break;
        case LC_ID_DYLIB: im->install_name = (const char *)c + ((const struct dylib_command *)c)->name_off; break;
        case LC_LOAD_DYLIB: case LC_LOAD_WEAK_DYLIB: case LC_REEXPORT_DYLIB: case LC_LOAD_UPWARD_DYLIB:
            if (im->ndeps < MAX_DEPS) {
                im->dep_reexport[im->ndeps] = c->cmd == LC_REEXPORT_DYLIB;
                im->dep_names[im->ndeps++] = (const char *)c + ((const struct dylib_command *)c)->name_off;
            }
            break;
        case LC_RPATH: if (im->nrpaths < 16) im->rpaths[im->nrpaths++] = (const char *)c + ((const struct rpath_command *)c)->path_off; break;
        case LC_DYLD_INFO: case LC_DYLD_INFO_ONLY: im->dyld_info = (const void *)c; break;
        case LC_DYLD_CHAINED_FIXUPS: im->chained = (const void *)c; break;
        case LC_DYLD_EXPORTS_TRIE: im->exports = (const void *)c; break;
        case LC_MAIN: im->entry = (const void *)c; break;
        case LC_BUILD_VERSION: platform = ((const struct build_version_command *)c)->platform; break;
        }
        lc += c->cmdsize;
    }
    if (platform != PLATFORM_IOSSIMULATOR)
        isim_fatal("%s: LC_BUILD_VERSION platform %d is not IOSSIMULATOR (7); refusing to load", path, platform);

    uint64_t lo = UINT64_MAX, hi = 0;
    for (int i = 0; i < im->nsegs; i++) {
        if (!is_mapped_seg(im->segs[i])) continue;
        if (im->segs[i]->vmaddr < lo) lo = im->segs[i]->vmaddr;
        if (im->segs[i]->vmaddr + im->segs[i]->vmsize > hi) hi = im->segs[i]->vmaddr + im->segs[i]->vmsize;
    }
    uint8_t *base = mmap(NULL, hi - lo, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (base == MAP_FAILED) isim_fatal("%s: address reservation failed", path);
    im->slide = (uint64_t)(uintptr_t)base - lo;
    im->span = hi - lo;
    for (int i = 0; i < im->nsegs; i++) {
        struct segment_command_64 *s = im->segs[i];
        if (!is_mapped_seg(s)) continue;
        void *at = (void *)(uintptr_t)(s->vmaddr + im->slide);
        if (mmap(at, s->vmsize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0) == MAP_FAILED)
            isim_fatal("%s: segment map failed", path);
        if (s->filesize) memcpy(at, im->file + s->fileoff, s->filesize);
        if (s->fileoff == 0 && s->filesize) im->base = at;
    }
    if (!im->base) isim_fatal("%s: no segment maps the Mach-O header", path);
    if (isim_verbose) fprintf(stderr, "isim: mapped %s at %p\n", im->path, im->base);
    if (nimages >= MAX_IMAGES) isim_fatal("too many images");
    images[nimages++] = im;
    return im;
}

static struct image *load_image(const char *path, int want_type) {
    struct image *im = map_image(path, want_type);
    if (!im) return NULL;
    if (want_type == MH_EXECUTE) main_image = im;
    for (int i = 0; i < im->ndeps; i++) {
        const char *name = im->dep_names[i];
        const struct host_lib *h = host_lib_for(name);
        if (h) { im->host_deps[i] = h; continue; }
        struct image *dep = find_loaded(name, NULL);
        if (!dep) {
            char *full = expand_path(im, name);
            if (full) dep = find_loaded(NULL, full);
            if (!dep && full) dep = load_image(full, MH_DYLIB);
            if (!dep) isim_fatal("Library not loaded: %s\n  referenced from: %s\n  looked at: %s", name, im->path, full ? full : "(no rpath match)");
            free(full);
        }
        im->deps[i] = dep;
    }
    return im;
}

/* ---------------- thread-local variables (Mach-O TLV) ----------------
 * Each __thread_vars descriptor is { thunk, key, offset }. Compiled code calls desc->thunk(desc) with the
 * descriptor in %rdi and expects the variable's address in %rax with every other register preserved.
 * isim gives each image a pthread key; a thread's block is a copy of the image's TLV template
 * (__thread_data contents followed by zeroed __thread_bss), allocated on first access. */
struct tlv_image { pthread_key_t key; const uint8_t *init; size_t init_size, size; };
static struct tlv_image tlv_images[MAX_IMAGES]; static int ntlv_images;
struct tlv_desc { void *thunk; unsigned long key; unsigned long offset; };

void *isim_tlv_addr(struct tlv_desc *d) {
    struct tlv_image *t = &tlv_images[d->key];
    uint8_t *block = pthread_getspecific(t->key);
    if (!block) {
        block = calloc(1, t->size ? t->size : 1);
        if (t->init_size) memcpy(block, t->init, t->init_size);
        pthread_setspecific(t->key, block);
    }
    return block + d->offset;
}
__asm__(
    ".text\n.globl isim_tlv_get_addr\n.type isim_tlv_get_addr,@function\nisim_tlv_get_addr:\n"
    "  push %rbp\n  mov %rsp, %rbp\n  sub $0x150, %rsp\n  and $-16, %rsp\n"
    "  mov %rcx, 0x00(%rsp)\n  mov %rdx, 0x08(%rsp)\n  mov %rsi, 0x10(%rsp)\n  mov %rdi, 0x18(%rsp)\n"
    "  mov %r8, 0x20(%rsp)\n  mov %r9, 0x28(%rsp)\n  mov %r10, 0x30(%rsp)\n  mov %r11, 0x38(%rsp)\n"
    "  movdqa %xmm0, 0x40(%rsp)\n  movdqa %xmm1, 0x50(%rsp)\n  movdqa %xmm2, 0x60(%rsp)\n  movdqa %xmm3, 0x70(%rsp)\n"
    "  movdqa %xmm4, 0x80(%rsp)\n  movdqa %xmm5, 0x90(%rsp)\n  movdqa %xmm6, 0xa0(%rsp)\n  movdqa %xmm7, 0xb0(%rsp)\n"
    "  movdqa %xmm8, 0xc0(%rsp)\n  movdqa %xmm9, 0xd0(%rsp)\n  movdqa %xmm10, 0xe0(%rsp)\n  movdqa %xmm11, 0xf0(%rsp)\n"
    "  movdqa %xmm12, 0x100(%rsp)\n  movdqa %xmm13, 0x110(%rsp)\n  movdqa %xmm14, 0x120(%rsp)\n  movdqa %xmm15, 0x130(%rsp)\n"
    "  call isim_tlv_addr\n"
    "  mov 0x00(%rsp), %rcx\n  mov 0x08(%rsp), %rdx\n  mov 0x10(%rsp), %rsi\n  mov 0x18(%rsp), %rdi\n"
    "  mov 0x20(%rsp), %r8\n  mov 0x28(%rsp), %r9\n  mov 0x30(%rsp), %r10\n  mov 0x38(%rsp), %r11\n"
    "  movdqa 0x40(%rsp), %xmm0\n  movdqa 0x50(%rsp), %xmm1\n  movdqa 0x60(%rsp), %xmm2\n  movdqa 0x70(%rsp), %xmm3\n"
    "  movdqa 0x80(%rsp), %xmm4\n  movdqa 0x90(%rsp), %xmm5\n  movdqa 0xa0(%rsp), %xmm6\n  movdqa 0xb0(%rsp), %xmm7\n"
    "  movdqa 0xc0(%rsp), %xmm8\n  movdqa 0xd0(%rsp), %xmm9\n  movdqa 0xe0(%rsp), %xmm10\n  movdqa 0xf0(%rsp), %xmm11\n"
    "  movdqa 0x100(%rsp), %xmm12\n  movdqa 0x110(%rsp), %xmm13\n  movdqa 0x120(%rsp), %xmm14\n  movdqa 0x130(%rsp), %xmm15\n"
    "  mov %rbp, %rsp\n  pop %rbp\n  ret\n");
void isim_tlv_get_addr(void);

static void setup_tlv(struct image *im) {
    uint64_t lo = UINT64_MAX, hi = 0, init_hi = 0;
    struct tlv_desc *descs = NULL; uint64_t ndescs = 0;
    for (int i = 0; i < im->nsegs; i++) {
        const struct section_64 *sec = (const void *)(im->segs[i] + 1);
        for (uint32_t j = 0; j < im->segs[i]->nsects; j++) {
            uint32_t type = sec[j].flags & SECTION_TYPE;
            if (type == S_THREAD_LOCAL_VARIABLES) { descs = (void *)(uintptr_t)(sec[j].addr + im->slide); ndescs = sec[j].size / sizeof *descs; }
            if (type == S_THREAD_LOCAL_REGULAR || type == S_THREAD_LOCAL_ZEROFILL) {
                if (sec[j].addr < lo) lo = sec[j].addr;
                if (sec[j].addr + sec[j].size > hi) hi = sec[j].addr + sec[j].size;
                if (type == S_THREAD_LOCAL_REGULAR && sec[j].addr + sec[j].size > init_hi) init_hi = sec[j].addr + sec[j].size;
            }
        }
    }
    if (!descs) return;
    if (ntlv_images >= MAX_IMAGES) isim_fatal("too many TLV images");
    struct tlv_image *t = &tlv_images[ntlv_images];
    pthread_key_create(&t->key, free);
    if (hi > lo) {
        t->size = hi - lo;
        t->init = (const uint8_t *)(uintptr_t)(lo + im->slide);
        t->init_size = init_hi > lo ? init_hi - lo : 0;
    }
    for (uint64_t k = 0; k < ndescs; k++) { descs[k].thunk = (void *)isim_tlv_get_addr; descs[k].key = (unsigned long)ntlv_images; }
    if (isim_verbose) fprintf(stderr, "isim: %s: %lu thread-local variables, template %zu bytes\n", im->path, (unsigned long)ndescs, t->size);
    ntlv_images++;
}

/* ---------------- ObjC + initializers ---------------- */
static void *img_find_section(const struct objc_image *oi, const char *sectname, uint64_t *size) {
    struct image *im = oi->ctx;
    for (int i = 0; i < im->nsegs; i++) {
        const struct section_64 *sec = (const void *)(im->segs[i] + 1);
        for (uint32_t j = 0; j < im->segs[i]->nsects; j++)
            if (!strncmp(sec[j].sectname, sectname, 16)) { *size = sec[j].size; return (void *)(uintptr_t)(sec[j].addr + im->slide); }
    }
    *size = 0;
    return NULL;
}

/* dependency order: dependencies before dependents */
static void order_images(struct image *im, struct image **out, int *n, int *visiting) {
    for (int i = 0; i < *n; i++) if (out[i] == im) return;
    int idx = 0; while (images[idx] != im) idx++;
    if (visiting[idx]) return;                      /* cycle (upward deps) */
    visiting[idx] = 1;
    for (int i = 0; i < im->ndeps; i++) if (im->deps[i]) order_images(im->deps[i], out, n, visiting);
    out[(*n)++] = im;
}

typedef void (*initializer_fn)(int, char **, char **, char **);

static void run_initializers(struct image *im, int argc, char **argv, char **envp, char **apple) {
    for (int i = 0; i < im->nsegs; i++) {
        const struct section_64 *sec = (const void *)(im->segs[i] + 1);
        for (uint32_t j = 0; j < im->segs[i]->nsects; j++) {
            uint32_t type = sec[j].flags & SECTION_TYPE;
            uint8_t *at = (uint8_t *)(uintptr_t)(sec[j].addr + im->slide);
            if (type == S_MOD_INIT_FUNC_POINTERS)
                for (uint64_t k = 0; k < sec[j].size / 8; k++) ((initializer_fn *)at)[k](argc, argv, envp, apple);
            else if (type == S_INIT_FUNC_OFFSETS)
                for (uint64_t k = 0; k < sec[j].size / 4; k++) ((initializer_fn)(im->base + ((uint32_t *)at)[k]))(argc, argv, envp, apple);
        }
    }
}

static void print_exports(const char *lib) {
    for (size_t i = 0; i < sizeof host_libs / sizeof *host_libs; i++) {
        if (strcmp(host_libs[i]->install_name, lib)) continue;
        for (size_t j = 0; j < host_libs[i]->count; j++) printf("%s %s\n", host_libs[i]->table[j].name, host_libs[i]->table[j].status);
        if (host_libs[i] == &host_libsystem)
            for (size_t j = 0; j < dyld_table_count; j++) printf("%s %s\n", dyld_table[j].name, dyld_table[j].status);
        return;
    }
    fprintf(stderr, "unknown host library %s\n", lib);
    exit(2);
}

static const char *default_root(void) {
    static char buf[PATH_MAX];
    char self[PATH_MAX]; ssize_t n = readlink("/proc/self/exe", self, sizeof self - 1);
    if (n <= 0) return ".";
    self[n] = 0;
    snprintf(buf, sizeof buf, "%s/../sdk", dirname(self));
    return buf;
}

/* ================= libdyld / dlfcn subset (answered from the loader's image list) ================= */
static struct image *image_for_header(const void *mh) { for (int i = 0; i < nimages; i++) if (images[i]->base == mh) return images[i]; return NULL; }
static struct image *image_for_address(const void *addr) {
    for (int i = 0; i < nimages; i++)
        if ((const uint8_t *)addr >= images[i]->base && (const uint8_t *)addr < images[i]->base + images[i]->span) return images[i];
    return NULL;
}
const char *isim_image_path_for_address(const void *addr) { struct image *im = image_for_address(addr); return im ? im->path : NULL; }

static uint32_t d_dyld_image_count(void) { return (uint32_t)nimages; }
static const void *d_dyld_get_image_header(uint32_t i) { return i < (uint32_t)nimages ? images[i]->base : NULL; }
static intptr_t d_dyld_get_image_vmaddr_slide(uint32_t i) { return i < (uint32_t)nimages ? (intptr_t)images[i]->slide : 0; }
static const char *d_dyld_get_image_name(uint32_t i) { return i < (uint32_t)nimages ? images[i]->path : NULL; }
typedef void (*add_image_cb)(const void *mh, intptr_t slide);
static add_image_cb add_cbs[32]; static int nadd_cbs;
static void d_dyld_register_func_for_add_image(add_image_cb f) {
    if (nadd_cbs < 32) add_cbs[nadd_cbs++] = f;
    for (int i = 0; i < nimages; i++) f(images[i]->base, (intptr_t)images[i]->slide);   /* dyld calls back for existing images */
}
static void d_dyld_register_func_for_remove_image(add_image_cb f) { (void)f; }      /* images are never unloaded */
static int d_dyld_is_objc_constant(int kind, const void *addr) { return 0; }
static const char *d_dyld_image_path_containing_address(const void *addr) { return isim_image_path_for_address(addr); }
static int d_dyld_is_memory_immutable(const void *addr, size_t n) { return 0; }

static uint8_t *d_getsectiondata(const void *mh, const char *segname, const char *sectname, unsigned long *size) {
    struct image *im = image_for_header(mh);
    *size = 0;
    if (!im) return NULL;
    for (int i = 0; i < im->nsegs; i++) {
        const struct section_64 *sec = (const void *)(im->segs[i] + 1);
        for (uint32_t j = 0; j < im->segs[i]->nsects; j++)
            if (!strncmp(sec[j].segname, segname, 16) && !strncmp(sec[j].sectname, sectname, 16)) {
                *size = sec[j].size;
                return (uint8_t *)(uintptr_t)(sec[j].addr + im->slide);
            }
    }
    return NULL;
}

static __thread const char *dl_error;
static __thread char dl_error_buf[512];
static void *d_dlsym(void *handle, const char *name) {
    char mangled[512]; snprintf(mangled, sizeof mangled, "_%s", name);
    void *p = NULL;
    intptr_t h = (intptr_t)handle;
    if (h == -2 || h == -1 || h == -3 || h == -5 || !handle) p = isim_lookup_symbol(mangled);
    else { uint64_t a; if (image_export(handle, mangled, &a, 0)) p = (void *)(uintptr_t)a; }
    if (!p) { snprintf(dl_error_buf, sizeof dl_error_buf, "dlsym(%p, %s): symbol not found", handle, name); dl_error = dl_error_buf; }
    return p;
}
/* Runtime loading (dlopen of a dylib, bundle or another executable such as an app extension's):
 * maps the image and new dependencies, then fixups, TLV, ObjC registration, dyld add-image
 * callbacks (Swift metadata) and initializers, dependencies first. Images are never unloaded. */
static void link_new_images(int first, int gargc, char **gargv);
static pthread_mutex_t dlopen_lock = PTHREAD_MUTEX_INITIALIZER;
static void *d_dlopen(const char *path, int mode) {
    if (!path) return main_image;
    for (int i = 0; i < nimages; i++) {
        const char *n = images[i]->install_name;
        if (!strcmp(images[i]->path, path) || (n && !strcmp(n, path))) return images[i];
    }
    for (size_t i = 0; i < sizeof host_libs / sizeof *host_libs; i++)
        if (!strcmp(host_libs[i]->install_name, path)) return (void *)-2;      /* host libraries: global lookup */
    if (access(path, R_OK) != 0) {
        snprintf(dl_error_buf, sizeof dl_error_buf, "dlopen(%s): image not found", path);
        dl_error = dl_error_buf;
        return NULL;
    }
    pthread_mutex_lock(&dlopen_lock);
    int first = nimages;
    struct image *saved_main = main_image;
    struct image *im = load_image(path, 0);
    main_image = saved_main;
    if (im) link_new_images(first, 0, NULL);
    pthread_mutex_unlock(&dlopen_lock);
    if (!im) { snprintf(dl_error_buf, sizeof dl_error_buf, "dlopen(%s): cannot load", path); dl_error = dl_error_buf; }
    return im;
}
static int d_dlclose(void *h) { return 0; }
static char *d_dlerror(void) { const char *e = dl_error; dl_error = NULL; return (char *)e; }

struct nlist_64 { uint32_t n_strx; uint8_t n_type, n_sect; uint16_t n_desc; uint64_t n_value; };
struct symtab_command { uint32_t cmd, cmdsize, symoff, nsyms, stroff, strsize; };
typedef struct { const char *dli_fname; void *dli_fbase; const char *dli_sname; void *dli_saddr; } d_dl_info;
static int d_dladdr(const void *addr, d_dl_info *info) {
    struct image *im = image_for_address(addr);
    if (!im) return 0;
    info->dli_fname = im->path; info->dli_fbase = im->base; info->dli_sname = NULL; info->dli_saddr = NULL;
    const uint8_t *lc = im->file + sizeof *im->mh;
    for (uint32_t i = 0; i < im->mh->ncmds; i++, lc += ((const struct load_command *)lc)->cmdsize) {
        if (((const struct load_command *)lc)->cmd != 0x2) continue;              /* LC_SYMTAB */
        const struct symtab_command *st = (const void *)lc;
        const struct nlist_64 *nl = (const void *)(im->file + st->symoff);
        const char *strs = (const char *)im->file + st->stroff;
        uint64_t best = 0;
        for (uint32_t k = 0; k < st->nsyms; k++) {
            if ((nl[k].n_type & 0xe0) || (nl[k].n_type & 0x0e) != 0x0e) continue;   /* defined, non-stab, N_SECT */
            uint64_t a = nl[k].n_value + im->slide;
            if (a <= (uint64_t)(uintptr_t)addr && a >= best) { best = a; info->dli_sname = strs + nl[k].n_strx; }
        }
        if (info->dli_sname) { if (*info->dli_sname == '_') info->dli_sname++; info->dli_saddr = (void *)(uintptr_t)best; }
    }
    return 1;
}

/* ---- crash reports: signal, faulting address, and a frame-pointer backtrace symbolized
 * against the loaded Mach-O images (Darwin code always keeps frame pointers). ---- */
static void print_frame(int i, uintptr_t pc) {
    d_dl_info di;
    if (d_dladdr((void *)pc, &di)) {
        const char *base = strrchr(di.dli_fname, '/');
        fprintf(stderr, "  #%-2d 0x%012lx %s`%s + %lu\n", i, (unsigned long)pc, base ? base + 1 : di.dli_fname,
                di.dli_sname ? di.dli_sname : "?", di.dli_saddr ? (unsigned long)(pc - (uintptr_t)di.dli_saddr) : 0UL);
    } else {
        Dl_info hi;
        if (dladdr((void *)pc, &hi) && hi.dli_sname) fprintf(stderr, "  #%-2d 0x%012lx [host] %s + %lu\n", i, (unsigned long)pc, hi.dli_sname, (unsigned long)(pc - (uintptr_t)hi.dli_saddr));
        else fprintf(stderr, "  #%-2d 0x%012lx [host]%s%s\n", i, (unsigned long)pc, hi.dli_fname ? " " : "", hi.dli_fname ? hi.dli_fname : "");
    }
}
static void crash_handler(int sig, siginfo_t *si, void *ctx) {
    ucontext_t *uc = ctx;
    uintptr_t pc = uc->uc_mcontext.gregs[REG_RIP], fp = uc->uc_mcontext.gregs[REG_RBP], sp = uc->uc_mcontext.gregs[REG_RSP];
    fprintf(stderr, "\nisim: guest crashed: %s at address %p\n", strsignal(sig), si->si_addr);
    print_frame(0, pc);
    /* the return address is at [rsp] if the crash happened before the frame was set up (e.g. in a leaf) */
    uintptr_t ret0 = 0; if (sp && !(sp & 7)) ret0 = *(uintptr_t *)sp;
    if (ret0 && image_for_address((void *)ret0)) print_frame(1, ret0);
    for (int i = 2; i < 64 && fp && !(fp & 7); i++) {
        uintptr_t next = ((uintptr_t *)fp)[0], ret = ((uintptr_t *)fp)[1];
        if (!ret) break;
        print_frame(i, ret);
        if (next <= fp) break;
        fp = next;
    }
    signal(sig, SIG_DFL);
    raise(sig);
}
static void install_crash_handler(void) {
    if (getenv("ISIM_NO_CRASH_HANDLER")) return;
    static char altstack[64 * 1024];
    stack_t ss = { .ss_sp = altstack, .ss_size = sizeof altstack };
    sigaltstack(&ss, NULL);
    struct sigaction sa = { .sa_sigaction = crash_handler, .sa_flags = SA_SIGINFO | SA_ONSTACK };
    sigemptyset(&sa.sa_mask);
    sigaction(SIGSEGV, &sa, NULL); sigaction(SIGBUS, &sa, NULL); sigaction(SIGILL, &sa, NULL);
    sigaction(SIGFPE, &sa, NULL); sigaction(SIGTRAP, &sa, NULL); sigaction(SIGABRT, &sa, NULL);
}

#define D(n, f) { n, (void *)f, "isim" }
static const struct shim dyld_table[] = {
    D("__dyld_image_count", d_dyld_image_count), D("__dyld_get_image_header", d_dyld_get_image_header),
    D("__dyld_get_image_vmaddr_slide", d_dyld_get_image_vmaddr_slide), D("__dyld_get_image_name", d_dyld_get_image_name),
    D("__dyld_register_func_for_add_image", d_dyld_register_func_for_add_image),
    D("__dyld_register_func_for_remove_image", d_dyld_register_func_for_remove_image),
    D("__dyld_is_objc_constant", d_dyld_is_objc_constant), D("_dyld_image_path_containing_address", d_dyld_image_path_containing_address),
    D("__dyld_is_memory_immutable", d_dyld_is_memory_immutable), D("_getsectiondata", d_getsectiondata),
    D("_dlsym", d_dlsym), D("_dlopen", d_dlopen), D("_dlclose", d_dlclose), D("_dlerror", d_dlerror), D("_dladdr", d_dladdr),
};
static const size_t dyld_table_count = sizeof dyld_table / sizeof *dyld_table;

static void link_new_images(int first, int gargc, char **gargv) {
    for (int i = first; i < nimages; i++) {
        struct image *im = images[i];
        if (im->chained) do_chained(im);
        if (im->dyld_info) {
            const struct dyld_info_command *d = im->dyld_info;
            do_rebase(im, im->file + d->rebase_off, im->file + d->rebase_off + d->rebase_size);
            do_bind(im, im->file + d->bind_off, im->file + d->bind_off + d->bind_size, 0);
            do_bind(im, im->file + d->lazy_bind_off, im->file + d->lazy_bind_off + d->lazy_bind_size, 1);
        }
    }
    for (int i = first; i < nimages; i++) setup_tlv(images[i]);
    /* dependencies are mapped after the image that needs them: reverse order = dependencies first */
    int n = nimages - first;
    struct image *order[MAX_IMAGES]; struct objc_image *oimgs = calloc(n ? n : 1, sizeof *oimgs);
    for (int i = 0; i < n; i++) order[i] = images[nimages - 1 - i];
    for (int i = 0; i < n; i++) { oimgs[i] = (struct objc_image){ order[i]->path, img_find_section, order[i] }; objc_rt_map_image(&oimgs[i]); }
    for (int i = 0; i < n; i++)
        for (int s = 0; s < order[i]->nsegs; s++) {
            struct segment_command_64 *sg = order[i]->segs[s];
            if (is_mapped_seg(sg)) mprotect((void *)(uintptr_t)(sg->vmaddr + order[i]->slide), sg->vmsize, prot_of(sg->initprot));
        }
    for (int i = 0; i < n; i++) for (int c = 0; c < nadd_cbs; c++) add_cbs[c](order[i]->base, (intptr_t)order[i]->slide);
    char *apple[] = { NULL };
    char *noargv[] = { NULL };
    for (int i = 0; i < n; i++) objc_rt_load_image(&oimgs[i]);
    for (int i = 0; i < n; i++) run_initializers(order[i], gargc, gargv ? gargv : noargv, environ, apple);
    /* the objc image records must outlive the call (the runtime keeps pointers) */
}

int main(int argc, char **argv, char **envp) {
    int ai = 1;
    sysroot = getenv("ISIM_ROOT");
    while (ai < argc && argv[ai][0] == '-') {
        if (!strcmp(argv[ai], "-v")) { isim_verbose = 1; ai++; }
        else if (!strcmp(argv[ai], "--root") && ai + 1 < argc) { sysroot = argv[ai + 1]; ai += 2; }
        else if (!strcmp(argv[ai], "--print-exports") && ai + 1 < argc) { print_exports(argv[ai + 1]); return 0; }
        else if (!strcmp(argv[ai], "--shell") && ai + 2 < argc) {
            /* --shell <home screen .app> <its executable>: run the isim shell (each app is a child process) */
            extern int isim_shell_main(const char *self, const char *root, const char *bundle, const char *exe);
            if (!sysroot) sysroot = default_root();
            char *rr = realpath(sysroot, NULL); if (rr) sysroot = rr;
            char self[PATH_MAX]; ssize_t n = readlink("/proc/self/exe", self, sizeof self - 1); if (n > 0) self[n] = 0;
            return isim_shell_main(self, sysroot, argv[ai + 1], argv[ai + 2]);
        }
        else break;
    }
    if (ai >= argc) {
        fprintf(stderr, "usage: isim-runtime [-v] [--root SDKROOT] <ios-simulator-executable> [args...]\n"
                        "       isim-runtime --print-exports <host-install-name>\n");
        return 2;
    }
    if (!sysroot) sysroot = default_root();
    char *rr = realpath(sysroot, NULL); if (rr) sysroot = rr;

    if (!load_image(argv[ai], MH_EXECUTE)) isim_fatal("cannot open %s", argv[ai]);
    if (!main_image->entry) isim_fatal("%s: no LC_MAIN", main_image->path);

    install_crash_handler();
    libsystem_init(argc - ai, argv + ai);
    for (int i = 0; i < nimages; i++) {
        struct image *im = images[i];
        if (im->chained) do_chained(im);
        if (im->dyld_info) {
            const struct dyld_info_command *d = im->dyld_info;
            do_rebase(im, im->file + d->rebase_off, im->file + d->rebase_off + d->rebase_size);
            do_bind(im, im->file + d->bind_off, im->file + d->bind_off + d->bind_size, 0);
            do_bind(im, im->file + d->lazy_bind_off, im->file + d->lazy_bind_off + d->lazy_bind_size, 1);
        }
    }

    for (int i = 0; i < nimages; i++) setup_tlv(images[i]);   /* after fixups (descriptors' offsets are final) */

    struct image *order[MAX_IMAGES]; int n = 0; int visiting[MAX_IMAGES] = {0};
    order_images(main_image, order, &n, visiting);
    struct objc_image oimgs[MAX_IMAGES];
    for (int i = 0; i < n; i++) {
        oimgs[i] = (struct objc_image){ order[i]->path, img_find_section, order[i] };
        objc_rt_map_image(&oimgs[i]);
    }
    for (int i = 0; i < n; i++)
        for (int s = 0; s < order[i]->nsegs; s++) {
            struct segment_command_64 *sg = order[i]->segs[s];
            if (is_mapped_seg(sg)) mprotect((void *)(uintptr_t)(sg->vmaddr + order[i]->slide), sg->vmsize, prot_of(sg->initprot));
        }
    if (unresolved_count) fprintf(stderr, "isim: %d unresolved symbol(s); calling them aborts\n", unresolved_count);

    char exec_path[PATH_MAX + 32]; snprintf(exec_path, sizeof exec_path, "executable_path=%s", main_image->path);
    char *apple[] = { exec_path, NULL };
    char **gargv = argv + ai; int gargc = argc - ai;
    for (int i = 0; i < n; i++) objc_rt_load_image(&oimgs[i]);
    for (int i = 0; i < n; i++) run_initializers(order[i], gargc, gargv, envp, apple);

    int (*guest_main)(int, char **, char **, char **) = (void *)(main_image->base + main_image->entry->entryoff);
    exit(guest_main(gargc, gargv, envp, apple));
}
