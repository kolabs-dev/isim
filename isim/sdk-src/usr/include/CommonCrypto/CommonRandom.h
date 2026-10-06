/* isim SDK (self-authored): CommonCrypto random bytes (the host's getrandom). */
#pragma once
#include <_isim_cdefs.h>
#include <stddef.h>
#include <CommonCrypto/CommonCryptoError.h>
__BEGIN_DECLS
typedef CCCryptorStatus CCRNGStatus;
CCRNGStatus CCRandomGenerateBytes(void *bytes, size_t count);
__END_DECLS
