#pragma once
#include <stdint.h>
struct mach_header { uint32_t magic; int32_t cputype, cpusubtype; uint32_t filetype, ncmds, sizeofcmds, flags; };
struct mach_header_64 { uint32_t magic; int32_t cputype, cpusubtype; uint32_t filetype, ncmds, sizeofcmds, flags, reserved; };
#define MH_MAGIC_64 0xfeedfacf
#define MH_EXECUTE 0x2
#define MH_DYLIB 0x6
struct load_command { uint32_t cmd, cmdsize; };
struct section_64 { char sectname[16], segname[16]; uint64_t addr, size; uint32_t offset, align, reloff, nreloc, flags, reserved1, reserved2, reserved3; };
#define LC_SEGMENT_64 0x19
#define LC_SYMTAB 0x2
#define LC_DYSYMTAB 0xb
struct segment_command_64 { uint32_t cmd, cmdsize; char segname[16]; uint64_t vmaddr, vmsize, fileoff, filesize; int32_t maxprot, initprot; uint32_t nsects, flags; };
struct symtab_command { uint32_t cmd, cmdsize, symoff, nsyms, stroff, strsize; };
struct dysymtab_command { uint32_t cmd, cmdsize, ilocalsym, nlocalsym, iextdefsym, nextdefsym, iundefsym, nundefsym, tocoff, ntoc, modtaboff, nmodtab, extrefsymoff, nextrefsyms, indirectsymoff, nindirectsyms, extreloff, nextrel, locreloff, nlocrel; };
struct segment_command { uint32_t cmd, cmdsize; char segname[16]; uint32_t vmaddr, vmsize, fileoff, filesize; int32_t maxprot, initprot; uint32_t nsects, flags; };
struct section { char sectname[16], segname[16]; uint32_t addr, size, offset, align, reloff, nreloc, flags, reserved1, reserved2; };
#define LC_SEGMENT 0x1
#define SECTION_TYPE 0x000000ff
#define SECTION_ATTRIBUTES 0xffffff00
#define S_REGULAR 0x0
#define S_NON_LAZY_SYMBOL_POINTERS 0x6
#define S_LAZY_SYMBOL_POINTERS 0x7
#define S_SYMBOL_STUBS 0x8
#define S_MOD_INIT_FUNC_POINTERS 0x9
#define S_THREAD_LOCAL_VARIABLE_POINTERS 0x14
#define S_INIT_FUNC_OFFSETS 0x16
#define INDIRECT_SYMBOL_LOCAL 0x80000000
#define INDIRECT_SYMBOL_ABS 0x40000000
#define SEG_LINKEDIT "__LINKEDIT"
#define SEG_DATA "__DATA"
#define SEG_TEXT "__TEXT"
