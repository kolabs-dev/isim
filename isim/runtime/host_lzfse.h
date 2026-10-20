/* isim: Apple's reference LZFSE (third_party/lzfse, BSD-3-Clause), built into the runtime by host_lzfse.c. Same
 * contract as lzfse_encode_buffer / lzfse_decode_buffer (0: failure; a NULL scratch is allocated here); everything
 * returns 0 when the runtime was built without the sources (build.py fetch). */
#ifndef ISIM_HOST_LZFSE_H
#define ISIM_HOST_LZFSE_H
#include <stddef.h>
#include <stdint.h>

size_t isim_lzfse_encode(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, void *scratch);
size_t isim_lzfse_decode(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, void *scratch);
size_t isim_lzfse_encode_scratch_size(void);
size_t isim_lzfse_decode_scratch_size(void);
#endif
