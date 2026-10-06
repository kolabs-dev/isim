/* isim SDK (self-authored): CommonCrypto PBKDF2. */
#pragma once
#include <_isim_cdefs.h>
#include <stdint.h>
#include <stddef.h>
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonCryptoError.h>
__BEGIN_DECLS
enum { kCCPBKDF2 = 2 };
typedef uint32_t CCPBKDFAlgorithm;
enum {
    kCCPRFHmacAlgSHA1 = 1,
    kCCPRFHmacAlgSHA224 = 2,
    kCCPRFHmacAlgSHA256 = 3,
    kCCPRFHmacAlgSHA384 = 4,
    kCCPRFHmacAlgSHA512 = 5,
};
typedef uint32_t CCPseudoRandomAlgorithm;
int CCKeyDerivationPBKDF(CCPBKDFAlgorithm algorithm, const char *password, size_t passwordLen, const uint8_t *salt,
                         size_t saltLen, CCPseudoRandomAlgorithm prf, unsigned rounds, uint8_t *derivedKey,
                         size_t derivedKeyLen);
unsigned CCCalibratePBKDF(CCPBKDFAlgorithm algorithm, size_t passwordLen, size_t saltLen, CCPseudoRandomAlgorithm prf,
                          size_t derivedKeyLen, uint32_t msec);
__END_DECLS
