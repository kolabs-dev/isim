#pragma once
/* isim Security for C and Objective-C: SecKey (RSA and EC keys through the host's OpenSSL) and SecRandom, from the
   Security Swift overlay (Security.framework re-exports libswiftSecurity.dylib). A SecKeyRef is a CF object (CFRetain /
   CFRelease). The keychain (SecItem*, the same items Swift code sees) and SecAccessControl: items whose access control
   asks for the device owner show LocalAuthentication's prompt when their data is read. Certificates, policies, trust
   (Apple's rules over the host's OpenSSL) and identities, SecPKCS12Import. Swift uses the overlay; these declarations
   are hidden from Swift. */
#include <CoreFoundation/CoreFoundation.h>
#if !defined(__swift__)
__BEGIN_DECLS
typedef int32_t OSStatus;
typedef struct __SecKey *SecKeyRef;
typedef const struct __SecRandom *SecRandomRef;
typedef CFStringRef SecKeyAlgorithm;
enum {
    errSecSuccess = 0, errSecUnimplemented = -4, errSecIO = -36, errSecParam = -50, errSecAllocate = -108, errSecUserCanceled = -128,
    errSecBadReq = -909, errSecNotAvailable = -25291, errSecReadOnly = -25292, errSecAuthFailed = -25293, errSecNoSuchKeychain = -25294,
    errSecDuplicateItem = -25299, errSecItemNotFound = -25300, errSecInteractionNotAllowed = -25308, errSecDecode = -26275,
    errSecMissingEntitlement = -34018, errSecCertificateExpired = -67818, errSecCertificateNotValidYet = -67819,
    errSecNotTrusted = -67843, errSecHostNameMismatch = -67602, errSecVerifyFailed = -67808, errSecInvalidCertificateRef = -67723,
    errSecPkcs12VerifyFailure = -25264, errSecPassphraseRequired = -25260, errSecCertificateRevoked = -67820,
    errSecIncompleteCertRevocationCheck = -67635,
};
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

/* the keychain */
extern const CFStringRef kSecClass, kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate,
    kSecClassKey, kSecClassIdentity, kSecAttrAccessible, kSecAttrAccessibleWhenUnlocked,
    kSecAttrAccessibleAfterFirstUnlock, kSecAttrAccessibleAlways, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    kSecAttrAccessibleAlwaysThisDeviceOnly, kSecAttrAccessControl, kSecAttrAccessGroup, kSecAttrSynchronizable,
    kSecAttrSynchronizableAny, kSecAttrCreationDate, kSecAttrModificationDate, kSecAttrDescription, kSecAttrComment,
    kSecAttrCreator, kSecAttrType, kSecAttrLabel, kSecAttrIsInvisible, kSecAttrIsNegative, kSecAttrAccount,
    kSecAttrService, kSecAttrGeneric, kSecAttrSecurityDomain, kSecAttrServer, kSecAttrProtocol,
    kSecAttrAuthenticationType, kSecAttrPort, kSecAttrPath, kSecAttrProtocolFTP, kSecAttrProtocolHTTP,
    kSecAttrProtocolHTTPS, kSecAttrProtocolSSH, kSecAttrProtocolSMTP, kSecAttrProtocolIMAP,
    kSecAttrAuthenticationTypeDefault, kSecAttrAuthenticationTypeHTTPBasic, kSecAttrAuthenticationTypeHTTPDigest,
    kSecAttrAuthenticationTypeHTMLForm, kSecMatchLimit, kSecMatchLimitOne, kSecMatchLimitAll,
    kSecMatchCaseInsensitive, kSecReturnData, kSecReturnAttributes, kSecReturnRef, kSecReturnPersistentRef,
    kSecValueData, kSecValueRef, kSecValuePersistentRef, kSecUseDataProtectionKeychain, kSecUseAuthenticationUI,
    kSecUseAuthenticationUIAllow, kSecUseAuthenticationUIFail, kSecUseAuthenticationUISkip,
    kSecUseAuthenticationContext, kSecUseOperationPrompt;
OSStatus SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result);
OSStatus SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result);
OSStatus SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate);
OSStatus SecItemDelete(CFDictionaryRef query);
CFStringRef SecCopyErrorMessageString(OSStatus status, void *reserved) CF_RETURNS_RETAINED;

/* access control */
typedef struct __SecAccessControl *SecAccessControlRef;
typedef CF_OPTIONS(CFOptionFlags, SecAccessControlCreateFlags) {
    kSecAccessControlUserPresence = 1u << 0, kSecAccessControlBiometryAny = 1u << 1, kSecAccessControlTouchIDAny = 1u << 1,
    kSecAccessControlBiometryCurrentSet = 1u << 3, kSecAccessControlTouchIDCurrentSet = 1u << 3, kSecAccessControlDevicePasscode = 1u << 4,
    kSecAccessControlWatch = 1u << 5, kSecAccessControlOr = 1u << 14, kSecAccessControlAnd = 1u << 15,
    kSecAccessControlPrivateKeyUsage = 1u << 30, kSecAccessControlApplicationPassword = 1u << 31,
};
CFTypeID SecAccessControlGetTypeID(void);
CFTypeID SecKeyGetTypeID(void);

/* certificates, policies, trust, identities */
typedef struct __SecCertificate *SecCertificateRef;
typedef struct __SecPolicy *SecPolicyRef;
typedef struct __SecTrust *SecTrustRef;
typedef struct __SecIdentity *SecIdentityRef;
typedef CF_ENUM(uint32_t, SecTrustResultType) {
    kSecTrustResultInvalid = 0, kSecTrustResultProceed = 1, kSecTrustResultConfirm = 2, kSecTrustResultDeny = 3,
    kSecTrustResultUnspecified = 4, kSecTrustResultRecoverableTrustFailure = 5, kSecTrustResultFatalTrustFailure = 6,
    kSecTrustResultOtherError = 7,
};
CFTypeID SecCertificateGetTypeID(void);
SecCertificateRef SecCertificateCreateWithData(CFAllocatorRef allocator, CFDataRef data) CF_RETURNS_RETAINED;
CFDataRef SecCertificateCopyData(SecCertificateRef certificate) CF_RETURNS_RETAINED;
CFStringRef SecCertificateCopySubjectSummary(SecCertificateRef certificate) CF_RETURNS_RETAINED;
OSStatus SecCertificateCopyCommonName(SecCertificateRef certificate, CFStringRef *commonName);
SecKeyRef SecCertificateCopyKey(SecCertificateRef certificate) CF_RETURNS_RETAINED;
CFDataRef SecCertificateCopySerialNumberData(SecCertificateRef certificate, CFErrorRef *error) CF_RETURNS_RETAINED;
CFTypeID SecPolicyGetTypeID(void);
SecPolicyRef SecPolicyCreateSSL(Boolean server, CFStringRef hostname) CF_RETURNS_RETAINED;
SecPolicyRef SecPolicyCreateBasicX509(void) CF_RETURNS_RETAINED;
CFTypeID SecTrustGetTypeID(void);
OSStatus SecTrustCreateWithCertificates(CFTypeRef certificates, CFTypeRef policies, SecTrustRef *trust);
OSStatus SecTrustSetPolicies(SecTrustRef trust, CFTypeRef policies);
OSStatus SecTrustSetAnchorCertificates(SecTrustRef trust, CFArrayRef anchorCertificates);
OSStatus SecTrustSetAnchorCertificatesOnly(SecTrustRef trust, Boolean anchorCertificatesOnly);
OSStatus SecTrustSetVerifyDate(SecTrustRef trust, CFDateRef verifyDate);
OSStatus SecTrustSetNetworkFetchAllowed(SecTrustRef trust, Boolean allowFetch);
bool SecTrustEvaluateWithError(SecTrustRef trust, CFErrorRef *error);
OSStatus SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result) __attribute__((deprecated("use SecTrustEvaluateWithError")));
OSStatus SecTrustGetTrustResult(SecTrustRef trust, SecTrustResultType *result);
CFIndex SecTrustGetCertificateCount(SecTrustRef trust);
CFArrayRef SecTrustCopyCertificateChain(SecTrustRef trust) CF_RETURNS_RETAINED;
SecKeyRef SecTrustCopyKey(SecTrustRef trust) CF_RETURNS_RETAINED;
CFDataRef SecTrustCopyExceptions(SecTrustRef trust) CF_RETURNS_RETAINED;
bool SecTrustSetExceptions(SecTrustRef trust, CFDataRef exceptions);
CFTypeID SecIdentityGetTypeID(void);
OSStatus SecIdentityCopyCertificate(SecIdentityRef identityRef, SecCertificateRef *certificateRef);
OSStatus SecIdentityCopyPrivateKey(SecIdentityRef identityRef, SecKeyRef *privateKeyRef);
extern const CFStringRef kSecImportExportPassphrase, kSecImportItemLabel, kSecImportItemKeyID, kSecImportItemTrust,
    kSecImportItemCertChain, kSecImportItemIdentity;
OSStatus SecPKCS12Import(CFDataRef pkcs12_data, CFDictionaryRef options, CFArrayRef *items);
SecAccessControlRef SecAccessControlCreateWithFlags(CFAllocatorRef allocator, CFTypeRef protection, SecAccessControlCreateFlags flags,
                                                    CFErrorRef *error) CF_RETURNS_RETAINED;
__END_DECLS
#endif
