#pragma once
/* isim Security for C and Objective-C: SecKey (RSA and EC keys through the host's OpenSSL) and SecRandom, from the
   Security Swift overlay (Security.framework re-exports libswiftSecurity.dylib). A SecKeyRef is a CF object (CFRetain /
   CFRelease). Swift uses the overlay; these declarations are hidden from Swift. Not available from C yet: the keychain
   (SecItem*), certificates, trust and SecAccessControl. */
#include <CoreFoundation/CoreFoundation.h>
#if !defined(__swift__)
__BEGIN_DECLS
typedef int32_t OSStatus;
typedef struct __SecKey *SecKeyRef;
typedef const struct __SecRandom *SecRandomRef;
typedef CFStringRef SecKeyAlgorithm;
enum { errSecSuccess = 0, errSecParam = -50, errSecAllocate = -108, errSecDecode = -26275, errSecUnimplemented = -4, errSecNotAvailable = -25291 };
typedef CF_ENUM(CFIndex, SecKeyOperationType) {
    kSecKeyOperationTypeSign = 0, kSecKeyOperationTypeVerify = 1, kSecKeyOperationTypeEncrypt = 2, kSecKeyOperationTypeDecrypt = 3,
    kSecKeyOperationTypeKeyExchange = 4,
};
extern const SecRandomRef kSecRandomDefault;
int SecRandomCopyBytes(SecRandomRef rnd, size_t count, void *bytes);

extern const CFStringRef kSecAttrKeyType, kSecAttrKeyTypeRSA, kSecAttrKeyTypeEC, kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits,
    kSecAttrEffectiveKeySize, kSecAttrKeyClass, kSecAttrKeyClassPublic, kSecAttrKeyClassPrivate, kSecAttrKeyClassSymmetric,
    kSecAttrApplicationTag, kSecAttrApplicationLabel, kSecAttrIsPermanent, kSecAttrIsSensitive, kSecAttrIsExtractable,
    kSecAttrCanEncrypt, kSecAttrCanDecrypt, kSecAttrCanDerive, kSecAttrCanSign, kSecAttrCanVerify, kSecAttrCanWrap,
    kSecAttrCanUnwrap, kSecAttrTokenID, kSecAttrTokenIDSecureEnclave, kSecPrivateKeyAttrs, kSecPublicKeyAttrs;
extern const SecKeyAlgorithm kSecKeyAlgorithmRSASignatureRaw, kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256,
    kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256,
    kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA384, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512,
    kSecKeyAlgorithmRSASignatureDigestPSSSHA256, kSecKeyAlgorithmRSASignatureMessagePSSSHA1, kSecKeyAlgorithmRSASignatureMessagePSSSHA256,
    kSecKeyAlgorithmRSASignatureMessagePSSSHA384, kSecKeyAlgorithmRSASignatureMessagePSSSHA512, kSecKeyAlgorithmECDSASignatureDigestX962SHA256,
    kSecKeyAlgorithmECDSASignatureMessageX962SHA256, kSecKeyAlgorithmECDSASignatureMessageX962SHA384,
    kSecKeyAlgorithmECDSASignatureMessageX962SHA512, kSecKeyAlgorithmRSAEncryptionRaw, kSecKeyAlgorithmRSAEncryptionPKCS1,
    kSecKeyAlgorithmRSAEncryptionOAEPSHA1, kSecKeyAlgorithmRSAEncryptionOAEPSHA256, kSecKeyAlgorithmRSAEncryptionOAEPSHA512,
    kSecKeyAlgorithmECDHKeyExchangeStandard;

SecKeyRef SecKeyCreateRandomKey(CFDictionaryRef parameters, CFErrorRef *error) CF_RETURNS_RETAINED;
SecKeyRef SecKeyCreateWithData(CFDataRef keyData, CFDictionaryRef attributes, CFErrorRef *error) CF_RETURNS_RETAINED;
SecKeyRef SecKeyCopyPublicKey(SecKeyRef key) CF_RETURNS_RETAINED;
CFDataRef SecKeyCopyExternalRepresentation(SecKeyRef key, CFErrorRef *error) CF_RETURNS_RETAINED;
CFDictionaryRef SecKeyCopyAttributes(SecKeyRef key) CF_RETURNS_RETAINED;
size_t SecKeyGetBlockSize(SecKeyRef key);
Boolean SecKeyIsAlgorithmSupported(SecKeyRef key, SecKeyOperationType operation, SecKeyAlgorithm algorithm);
CFDataRef SecKeyCreateSignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error) CF_RETURNS_RETAINED;
Boolean SecKeyVerifySignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef signedData, CFDataRef signature, CFErrorRef *error);
CFDataRef SecKeyCreateEncryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef plaintext, CFErrorRef *error) CF_RETURNS_RETAINED;
CFDataRef SecKeyCreateDecryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef ciphertext, CFErrorRef *error) CF_RETURNS_RETAINED;
__END_DECLS
#endif
