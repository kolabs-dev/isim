/* Mach-O structures/constants used by the isim runtime (layouts per Apple's public ABI). */
#pragma once
#include <stdint.h>

#define MH_MAGIC_64 0xfeedfacfu
#define MH_EXECUTE 2
#define MH_DYLIB 6
#define CPU_TYPE_X86_64 0x01000007
#define LC_REQ_DYLD 0x80000000u
#define LC_SEGMENT_64 0x19
#define LC_ID_DYLIB 0x0d
#define LC_LOAD_DYLIB 0x0c
#define LC_LOAD_WEAK_DYLIB (0x18 | LC_REQ_DYLD)
#define LC_REEXPORT_DYLIB (0x1f | LC_REQ_DYLD)
#define LC_LOAD_UPWARD_DYLIB (0x23 | LC_REQ_DYLD)
#define LC_RPATH (0x1c | LC_REQ_DYLD)
#define LC_DYLD_INFO 0x22
#define LC_DYLD_INFO_ONLY (0x22 | LC_REQ_DYLD)
#define LC_MAIN (0x28 | LC_REQ_DYLD)
#define LC_BUILD_VERSION 0x32
#define LC_DYLD_EXPORTS_TRIE (0x33 | LC_REQ_DYLD)
#define LC_DYLD_CHAINED_FIXUPS (0x34 | LC_REQ_DYLD)
#define PLATFORM_IOSSIMULATOR 7

#define SECTION_TYPE 0xff
#define S_MOD_INIT_FUNC_POINTERS 0x9
#define S_THREAD_LOCAL_VARIABLES 0x13
#define S_INIT_FUNC_OFFSETS 0x16

struct mach_header_64 { uint32_t magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved; };
struct load_command { uint32_t cmd, cmdsize; };
struct segment_command_64 {
    uint32_t cmd, cmdsize; char segname[16];
    uint64_t vmaddr, vmsize, fileoff, filesize;
    uint32_t maxprot, initprot, nsects, flags;
};
struct section_64 {
    char sectname[16], segname[16]; uint64_t addr, size;
    uint32_t offset, align, reloff, nreloc, flags, reserved1, reserved2, reserved3;
};
struct dylib_command { uint32_t cmd, cmdsize, name_off, timestamp, cur, compat; };
struct rpath_command { uint32_t cmd, cmdsize, path_off; };
struct dyld_info_command {
    uint32_t cmd, cmdsize, rebase_off, rebase_size, bind_off, bind_size,
             weak_bind_off, weak_bind_size, lazy_bind_off, lazy_bind_size, export_off, export_size;
};
struct entry_point_command { uint32_t cmd, cmdsize; uint64_t entryoff, stacksize; };
struct build_version_command { uint32_t cmd, cmdsize, platform, minos, sdk, ntools; };
struct linkedit_data_command { uint32_t cmd, cmdsize, dataoff, datasize; };
