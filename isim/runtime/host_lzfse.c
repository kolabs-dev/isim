/* isim: Apple's reference LZFSE encoder and decoder (https://github.com/lzfse/lzfse, lzfse-1.0, BSD-3-Clause), fetched
 * into third_party/lzfse by build.py fetch and compiled here as one unit, with its own warnings silenced. */
#include <stdlib.h>
#include "host_lzfse.h"

#if __has_include("../../third_party/lzfse/src/lzfse.h")
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wall"
#pragma GCC diagnostic ignored "-Wextra"
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wsign-compare"
#pragma GCC diagnostic ignored "-Wimplicit-fallthrough"
#include "../../third_party/lzfse/src/lzfse_decode.c"
#include "../../third_party/lzfse/src/lzfse_decode_base.c"
#include "../../third_party/lzfse/src/lzfse_encode.c"
#include "../../third_party/lzfse/src/lzfse_encode_base.c"
#include "../../third_party/lzfse/src/lzfse_fse.c"
#include "../../third_party/lzfse/src/lzvn_decode_base.c"
#include "../../third_party/lzfse/src/lzvn_encode_base.c"
#pragma GCC diagnostic pop

size_t isim_lzfse_encode_scratch_size(void) { return lzfse_encode_scratch_size(); }
size_t isim_lzfse_decode_scratch_size(void) { return lzfse_decode_scratch_size(); }
size_t isim_lzfse_encode(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, void *scratch) {
    return lzfse_encode_buffer(dst, dcap, src, slen, scratch);   /* NULL scratch: lzfse allocates its own */
}
size_t isim_lzfse_decode(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, void *scratch) {
    return lzfse_decode_buffer(dst, dcap, src, slen, scratch);
}
#else
size_t isim_lzfse_encode_scratch_size(void) { return 1; }
size_t isim_lzfse_decode_scratch_size(void) { return 1; }
size_t isim_lzfse_encode(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, void *scratch) { return 0; }
size_t isim_lzfse_decode(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, void *scratch) { return 0; }
#endif
