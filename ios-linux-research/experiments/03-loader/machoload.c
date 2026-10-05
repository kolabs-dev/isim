/*
 * machoload: minimal Linux loader for x86_64 iOS-Simulator Mach-O executables.
 *
 * Research prototype (experiment 03). It is NOT dyld and NOT a full runtime:
 *   - accepts only MH_EXECUTE, CPU x86_64, LC_BUILD_VERSION platform IOSSIMULATOR
 *   - maps segments, applies rebases/binds (LC_DYLD_INFO[_ONLY]) or chained
 *     fixups (DYLD_CHAINED_PTR_64 / _64_OFFSET), binds imports to an explicit
 *     shim table (shims.c), and calls LC_MAIN's entry point
 *   - unknown imports are bound to per-symbol traps that name the symbol and abort
 *   - no dylib loading, no TLV, no initializers (mod_init_func), no ObjC, no
 *     code signature checks, no weak/flat lookup semantics
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include "shims.h"

#define MH_MAGIC_64 0xfeedfacfu
#define MH_EXECUTE 2
#define CPU_TYPE_X86_64 0x01000007
#define LC_REQ_DYLD 0x80000000u
#define LC_SEGMENT_64 0x19
#define LC_LOAD_DYLIB 0x0c
#define LC_LOAD_WEAK_DYLIB (0x18 | LC_REQ_DYLD)
#define LC_REEXPORT_DYLIB (0x1f | LC_REQ_DYLD)
#define LC_DYLD_INFO 0x22
#define LC_DYLD_INFO_ONLY (0x22 | LC_REQ_DYLD)
#define LC_MAIN (0x28 | LC_REQ_DYLD)
#define LC_BUILD_VERSION 0x32
#define LC_DYLD_CHAINED_FIXUPS (0x34 | LC_REQ_DYLD)
#define PLATFORM_IOSSIMULATOR 7

struct mach_header_64 { uint32_t magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved; };
struct load_command { uint32_t cmd, cmdsize; };
struct segment_command_64 {
    uint32_t cmd, cmdsize; char segname[16];
    uint64_t vmaddr, vmsize, fileoff, filesize;
    uint32_t maxprot, initprot, nsects, flags;
};
struct dylib_command { uint32_t cmd, cmdsize, name_off, timestamp, cur, compat; };
struct dyld_info_command {
    uint32_t cmd, cmdsize, rebase_off, rebase_size, bind_off, bind_size,
             weak_bind_off, weak_bind_size, lazy_bind_off, lazy_bind_size, export_off, export_size;
};
struct entry_point_command { uint32_t cmd, cmdsize; uint64_t entryoff, stacksize; };
struct build_version_command { uint32_t cmd, cmdsize, platform, minos, sdk, ntools; };
struct linkedit_data_command { uint32_t cmd, cmdsize, dataoff, datasize; };

#define MAX_SEGS 32
#define MAX_DYLIBS 64

static struct {
    uint8_t *file; size_t file_size;
    struct segment_command_64 *segs[MAX_SEGS]; int nsegs;
    const char *dylibs[MAX_DYLIBS]; int ndylibs;
    uint64_t slide;          /* runtime address - link-time vmaddr */
    uint8_t *image_base;     /* runtime address of __TEXT (mach header) */
    int verbose;
    int unresolved;
} L;

__attribute__((noreturn)) static void die(const char *fmt, const char *a) { fprintf(stderr, "machoload: "); fprintf(stderr, fmt, a); fputc('\n', stderr); exit(127); }

/* ---- per-symbol traps for unimplemented imports ---- */
static void unresolved_called(const char *name) {
    fflush(NULL); /* keep guest output emitted before the trap */
    fprintf(stderr, "machoload: FATAL: guest called unimplemented import %s\n", name);
    fflush(stderr);
    abort();
}
static void *make_trap(const char *name) {
    static uint8_t *page; static size_t used, cap;
    if (!page || used + 32 > cap) {
        cap = 4096;
        page = mmap(NULL, cap, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (page == MAP_FAILED) die("%s", "trap mmap failed");
        used = 0;
    }
    uint8_t *p = page + used; used += 32;
    /* movabs rdi, name ; movabs rax, unresolved_called ; jmp rax */
    p[0] = 0x48; p[1] = 0xBF; memcpy(p + 2, &name, 8);
    void *fn = (void *)unresolved_called;
    p[10] = 0x48; p[11] = 0xB8; memcpy(p + 12, &fn, 8);
    p[20] = 0xFF; p[21] = 0xE0;
    return p;
}

static uint64_t resolve(int ordinal, const char *sym, int weak) {
    const char *lib = ordinal > 0 && ordinal <= L.ndylibs ? L.dylibs[ordinal - 1] : "(special)";
    const struct shim *s = shim_lookup(sym);
    if (s) {
        if (L.verbose) fprintf(stderr, "  bind %-28s <- %s [%s]\n", sym, lib, s->status);
        return (uint64_t)(uintptr_t)s->addr;
    }
    if (weak) return 0;
    L.unresolved++;
    fprintf(stderr, "machoload: warning: unresolved import %s (from %s) -> trap\n", sym, lib);
    return (uint64_t)(uintptr_t)make_trap(strdup(sym));
}

static uint64_t uleb(const uint8_t **p, const uint8_t *end) {
    uint64_t r = 0; int shift = 0;
    while (*p < end) { uint8_t b = *(*p)++; r |= (uint64_t)(b & 0x7f) << shift; shift += 7; if (!(b & 0x80)) break; }
    return r;
}
static int64_t sleb(const uint8_t **p, const uint8_t *end) {
    int64_t r = 0; int shift = 0; uint8_t b = 0;
    while (*p < end) { b = *(*p)++; r |= (int64_t)(b & 0x7f) << shift; shift += 7; if (!(b & 0x80)) break; }
    if (shift < 64 && (b & 0x40)) r |= -((int64_t)1 << shift);
    return r;
}

static uint64_t *seg_ptr(int seg, uint64_t off) {
    if (seg < 0 || seg >= L.nsegs || off + 8 > L.segs[seg]->vmsize) die("%s", "fixup outside segment");
    return (uint64_t *)(uintptr_t)(L.segs[seg]->vmaddr + L.slide + off);
}

/* ---- legacy rebase / bind opcodes ---- */
static void do_rebase(const uint8_t *p, const uint8_t *end) {
    int seg = 0; uint64_t off = 0;
    while (p < end) {
        uint8_t b = *p++, op = b & 0xF0, imm = b & 0x0F;
        switch (op) {
        case 0x00: return;                                    /* DONE */
        case 0x10: break;                                     /* SET_TYPE_IMM (pointer only) */
        case 0x20: seg = imm; off = uleb(&p, end); break;     /* SET_SEGMENT_AND_OFFSET_ULEB */
        case 0x30: off += uleb(&p, end); break;               /* ADD_ADDR_ULEB */
        case 0x40: off += imm * 8; break;                     /* ADD_ADDR_IMM_SCALED */
        case 0x50: for (int i = 0; i < imm; i++) { *seg_ptr(seg, off) += L.slide; off += 8; } break;
        case 0x60: { uint64_t n = uleb(&p, end); for (uint64_t i = 0; i < n; i++) { *seg_ptr(seg, off) += L.slide; off += 8; } break; }
        case 0x70: *seg_ptr(seg, off) += L.slide; off += 8 + uleb(&p, end); break;
        case 0x80: { uint64_t n = uleb(&p, end), skip = uleb(&p, end);
                     for (uint64_t i = 0; i < n; i++) { *seg_ptr(seg, off) += L.slide; off += 8 + skip; } break; }
        default: die("bad rebase opcode %s", "");
        }
    }
}

static void do_bind(const uint8_t *p, const uint8_t *end, int lazy) {
    int seg = 0, ordinal = 0, weak = 0; uint64_t off = 0; int64_t addend = 0; const char *sym = NULL;
    while (p < end) {
        uint8_t b = *p++, op = b & 0xF0, imm = b & 0x0F;
        switch (op) {
        case 0x00: if (!lazy) return; break;                  /* DONE (lazy stream: entry separator) */
        case 0x10: ordinal = imm; break;
        case 0x20: ordinal = (int)uleb(&p, end); break;
        case 0x30: ordinal = imm ? (int8_t)(0xF0 | imm) : 0; break;
        case 0x40: sym = (const char *)p; weak = imm & 1; p += strlen(sym) + 1; break;
        case 0x50: if (imm != 1) die("%s", "non-pointer bind type unsupported"); break;
        case 0x60: addend = sleb(&p, end); break;
        case 0x70: seg = imm; off = uleb(&p, end); break;
        case 0x80: off += uleb(&p, end); break;
        case 0x90: *seg_ptr(seg, off) = resolve(ordinal, sym, weak) + addend; off += 8; break;
        case 0xA0: *seg_ptr(seg, off) = resolve(ordinal, sym, weak) + addend; off += 8 + uleb(&p, end); break;
        case 0xB0: *seg_ptr(seg, off) = resolve(ordinal, sym, weak) + addend; off += 8 + imm * 8; break;
        case 0xC0: { uint64_t n = uleb(&p, end), skip = uleb(&p, end);
                     for (uint64_t i = 0; i < n; i++) { *seg_ptr(seg, off) = resolve(ordinal, sym, weak) + addend; off += 8 + skip; } break; }
        default: die("%s", "unsupported bind opcode (threaded binds not implemented)");
        }
    }
}

/* ---- chained fixups ---- */
struct cf_header { uint32_t version, starts_offset, imports_offset, symbols_offset, imports_count, imports_format, symbols_format; };
struct cf_starts_seg { uint32_t size; uint16_t page_size, pointer_format; uint64_t segment_offset; uint32_t max_valid_pointer; uint16_t page_count, page_start[]; };

static void do_chained(const uint8_t *blob, uint32_t size) {
    const struct cf_header *h = (const void *)blob;
    if (h->version != 0 || h->symbols_format != 0) die("%s", "unsupported chained fixups header");
    uint64_t *targets = calloc(h->imports_count ? h->imports_count : 1, sizeof *targets);
    const char *names = (const char *)blob + h->symbols_offset;
    const uint8_t *imp = blob + h->imports_offset;
    for (uint32_t i = 0; i < h->imports_count; i++) {
        int ord, weak; uint32_t name_off; int64_t addend = 0;
        if (h->imports_format == 1 || h->imports_format == 2) {
            uint32_t v; memcpy(&v, imp, 4);
            ord = (int8_t)(v & 0xff); weak = (v >> 8) & 1; name_off = v >> 9;
            if (h->imports_format == 2) { int32_t a; memcpy(&a, imp + 4, 4); addend = a; imp += 8; } else imp += 4;
        } else if (h->imports_format == 3) {
            uint64_t v; memcpy(&v, imp, 8);
            ord = (int16_t)(v & 0xffff); weak = (v >> 16) & 1; name_off = (uint32_t)(v >> 32);
            memcpy(&addend, imp + 8, 8); imp += 16;
        } else die("%s", "unknown chained imports format");
        targets[i] = resolve(ord, names + name_off, weak) + addend;
    }
    const uint8_t *starts = blob + h->starts_offset;
    uint32_t seg_count; memcpy(&seg_count, starts, 4);
    for (uint32_t s = 0; s < seg_count; s++) {
        uint32_t info_off; memcpy(&info_off, starts + 4 + 4 * s, 4);
        if (!info_off) continue;
        const struct cf_starts_seg *ss = (const void *)(starts + info_off);
        if (ss->pointer_format != 2 && ss->pointer_format != 6)
            die("%s", "unsupported chained pointer format (only PTR_64 / PTR_64_OFFSET)");
        for (uint16_t pg = 0; pg < ss->page_count; pg++) {
            uint16_t start = ss->page_start[pg];
            if (start == 0xFFFF) continue;
            if (start & 0x8000) die("%s", "DYLD_CHAINED_PTR_START_MULTI unsupported");
            uint8_t *loc = L.image_base + ss->segment_offset + (uint64_t)pg * ss->page_size + start;
            for (;;) {
                uint64_t raw; memcpy(&raw, loc, 8);
                uint64_t next = (raw >> 51) & 0xFFF, val;
                if (raw >> 63) {                               /* bind */
                    uint32_t ord = raw & 0xFFFFFF; int64_t add = (raw >> 24) & 0xFF;
                    if (ord >= h->imports_count) die("%s", "bind ordinal out of range");
                    val = targets[ord] + add;
                } else {                                       /* rebase */
                    uint64_t target = raw & 0xFFFFFFFFFull, high8 = (raw >> 36) & 0xFF;
                    val = (ss->pointer_format == 2 ? target + L.slide : (uint64_t)(uintptr_t)L.image_base + target) | (high8 << 56);
                }
                memcpy(loc, &val, 8);
                if (!next) break;
                loc += next * 4;
            }
        }
    }
    (void)size;
    free(targets);
}

struct section_64 {
    char sectname[16], segname[16]; uint64_t addr, size;
    uint32_t offset, align, reloff, nreloc, flags, reserved1, reserved2, reserved3;
};

/* runtime address of a section by name (any segment: ObjC sections move between __DATA and __DATA_CONST) */
static void *find_section(const char *sectname, uint64_t *size) {
    for (int i = 0; i < L.nsegs; i++) {
        const struct section_64 *sec = (const void *)(L.segs[i] + 1);
        for (uint32_t j = 0; j < L.segs[i]->nsects; j++)
            if (!strncmp(sec[j].sectname, sectname, 16)) { *size = sec[j].size; return (void *)(uintptr_t)(sec[j].addr + L.slide); }
    }
    *size = 0;
    return NULL;
}

static int prot_of(uint32_t vmprot) { return (vmprot & 1 ? PROT_READ : 0) | (vmprot & 2 ? PROT_WRITE : 0) | (vmprot & 4 ? PROT_EXEC : 0); }

int main(int argc, char **argv, char **envp) {
    int ai = 1;
    if (ai < argc && !strcmp(argv[ai], "-v")) { L.verbose = 1; ai++; }
    if (ai >= argc) { fprintf(stderr, "usage: machoload [-v] <ios-simulator-executable> [args...]\n"); return 2; }
    const char *path = argv[ai];

    int fd = open(path, O_RDONLY);
    if (fd < 0) die("cannot open %s", path);
    struct stat st; fstat(fd, &st);
    L.file_size = st.st_size;
    L.file = mmap(NULL, L.file_size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (L.file == MAP_FAILED) die("%s", "mmap file failed");

    const struct mach_header_64 *mh = (const void *)L.file;
    if (L.file_size < sizeof *mh || mh->magic != MH_MAGIC_64) die("%s: not a 64-bit Mach-O (fat/universal not supported)", path);
    if (mh->cputype != CPU_TYPE_X86_64) die("%s: not x86_64 (arm64 device binaries need emulation; out of scope)", path);
    if (mh->filetype != MH_EXECUTE) die("%s: not MH_EXECUTE", path);

    const struct dyld_info_command *dyld_info = NULL;
    const struct linkedit_data_command *chained = NULL;
    const struct entry_point_command *entry = NULL;
    int platform = -1;
    const uint8_t *lc = L.file + sizeof *mh;
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        const struct load_command *c = (const void *)lc;
        switch (c->cmd) {
        case LC_SEGMENT_64: if (L.nsegs < MAX_SEGS) L.segs[L.nsegs++] = (void *)c; break;
        case LC_LOAD_DYLIB: case LC_LOAD_WEAK_DYLIB: case LC_REEXPORT_DYLIB:
            if (L.ndylibs < MAX_DYLIBS) L.dylibs[L.ndylibs++] = (const char *)c + ((const struct dylib_command *)c)->name_off; break;
        case LC_DYLD_INFO: case LC_DYLD_INFO_ONLY: dyld_info = (const void *)c; break;
        case LC_DYLD_CHAINED_FIXUPS: chained = (const void *)c; break;
        case LC_MAIN: entry = (const void *)c; break;
        case LC_BUILD_VERSION: platform = ((const struct build_version_command *)c)->platform; break;
        }
        lc += c->cmdsize;
    }
    if (platform != PLATFORM_IOSSIMULATOR)
        die("%s: LC_BUILD_VERSION platform is not IOSSIMULATOR (refusing; this loader does not run macOS/other binaries)", path);
    if (!entry) die("%s: no LC_MAIN (LC_UNIXTHREAD not supported)", path);

    /* reserve and map segments */
    uint64_t lo = UINT64_MAX, hi = 0;
    for (int i = 0; i < L.nsegs; i++) {
        if (L.segs[i]->vmsize == 0 || (L.segs[i]->initprot == 0 && L.segs[i]->maxprot == 0)) continue; /* __PAGEZERO */
        if (L.segs[i]->vmaddr < lo) lo = L.segs[i]->vmaddr;
        if (L.segs[i]->vmaddr + L.segs[i]->vmsize > hi) hi = L.segs[i]->vmaddr + L.segs[i]->vmsize;
    }
    uint8_t *base = mmap(NULL, hi - lo, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (base == MAP_FAILED) die("%s", "reserve failed");
    L.slide = (uint64_t)(uintptr_t)base - lo;
    for (int i = 0; i < L.nsegs; i++) {
        struct segment_command_64 *s = L.segs[i];
        if (s->vmsize == 0 || (s->initprot == 0 && s->maxprot == 0)) continue;
        void *at = (void *)(uintptr_t)(s->vmaddr + L.slide);
        if (mmap(at, s->vmsize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0) == MAP_FAILED) die("%s", "segment map failed");
        if (s->filesize) memcpy(at, L.file + s->fileoff, s->filesize);
        if (s->fileoff == 0 && s->filesize) L.image_base = at;
        if (L.verbose) fprintf(stderr, "  map %-16.16s %p size 0x%lx prot %d\n", s->segname, at, (unsigned long)s->vmsize, s->initprot);
    }
    if (!L.image_base) die("%s", "no segment maps the mach header");

    shims_init(path);
    if (chained) do_chained(L.file + chained->dataoff, chained->datasize);
    if (dyld_info) {
        do_rebase(L.file + dyld_info->rebase_off, L.file + dyld_info->rebase_off + dyld_info->rebase_size);
        do_bind(L.file + dyld_info->bind_off, L.file + dyld_info->bind_off + dyld_info->bind_size, 0);
        do_bind(L.file + dyld_info->lazy_bind_off, L.file + dyld_info->lazy_bind_off + dyld_info->lazy_bind_size, 1); /* bound eagerly */
        if (dyld_info->weak_bind_size && L.verbose) fprintf(stderr, "  note: weak binds ignored\n");
    }
    objc_rt_register_image(find_section, L.verbose); /* before mprotect: selrefs/method lists are rewritten */
    for (int i = 0; i < L.nsegs; i++) {
        struct segment_command_64 *s = L.segs[i];
        if (s->vmsize == 0 || (s->initprot == 0 && s->maxprot == 0)) continue;
        mprotect((void *)(uintptr_t)(s->vmaddr + L.slide), s->vmsize, prot_of(s->initprot));
    }
    if (L.unresolved) fprintf(stderr, "machoload: %d import(s) unresolved; calling them aborts\n", L.unresolved);

    /* guest argv: argv[ai..]; Darwin's 4th main argument is the "apple" vector */
    char exec_path[4200]; snprintf(exec_path, sizeof exec_path, "executable_path=%s", path);
    char *apple[] = { exec_path, NULL };
    int (*guest_main)(int, char **, char **, char **) = (void *)(L.image_base + entry->entryoff);
    if (L.verbose) fprintf(stderr, "  entry %p (slide 0x%lx)\n", (void *)guest_main, (unsigned long)L.slide);
    int rc = guest_main(argc - ai, argv + ai, envp, apple);
    exit(rc);  /* flushes stdio like Darwin's libdyld start → exit() */
}
