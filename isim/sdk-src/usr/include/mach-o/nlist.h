#pragma once
#include <stdint.h>
struct nlist { union { uint32_t n_strx; } n_un; uint8_t n_type; uint8_t n_sect; int16_t n_desc; uint32_t n_value; };
struct nlist_64 { union { uint32_t n_strx; } n_un; uint8_t n_type; uint8_t n_sect; uint16_t n_desc; uint64_t n_value; };
#define N_STAB 0xe0
#define N_PEXT 0x10
#define N_TYPE 0x0e
#define N_EXT 0x01
#define N_UNDF 0x0
#define N_ABS 0x2
#define N_SECT 0xe
