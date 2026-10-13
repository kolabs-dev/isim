// isim Security for C and Objective-C (sdk-src/Frameworks/Security): the SecKey and SecRandom functions under their C
// names, forwarding to this overlay's implementations (RSA and EC through the host's OpenSSL). A SecKeyRef is the
// overlay's SecKey object (CFRetain / CFRelease work on it); the C constants (kSecAttrKeyType...) are defined with the
// same values in frameworks/Security/Security.m.
import Foundation

private func key(_ p: UnsafeRawPointer) -> SecKey { Unmanaged<SecKey>.fromOpaque(p).takeUnretainedValue() }
private func retained(_ k: SecKey?) -> UnsafeMutableRawPointer? { k.map { Unmanaged.passRetained($0).toOpaque() } }
private func retained(_ d: CFData?) -> CFData? { d.map { Unmanaged.passRetained($0).takeUnretainedValue() } }

@_cdecl("SecKeyCreateRandomKey")
public func _c_SecKeyCreateRandomKey(_ params: CFDictionary, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> UnsafeMutableRawPointer? {
    retained(SecKeyCreateRandomKey(params, error))
}
@_cdecl("SecKeyCreateWithData")
public func _c_SecKeyCreateWithData(_ data: CFData, _ attrs: CFDictionary, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> UnsafeMutableRawPointer? {
    retained(SecKeyCreateWithData(data, attrs, error))
}
@_cdecl("SecKeyCopyPublicKey")
public func _c_SecKeyCopyPublicKey(_ k: UnsafeRawPointer) -> UnsafeMutableRawPointer? { retained(SecKeyCopyPublicKey(key(k))) }
@_cdecl("SecKeyCopyExternalRepresentation")
public func _c_SecKeyCopyExternalRepresentation(_ k: UnsafeRawPointer, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    retained(SecKeyCopyExternalRepresentation(key(k), error))
}
@_cdecl("SecKeyCopyAttributes")
public func _c_SecKeyCopyAttributes(_ k: UnsafeRawPointer) -> CFDictionary? {
    SecKeyCopyAttributes(key(k)).map { Unmanaged.passRetained($0).takeUnretainedValue() }
}
@_cdecl("SecKeyGetBlockSize")
public func _c_SecKeyGetBlockSize(_ k: UnsafeRawPointer) -> Int { SecKeyGetBlockSize(key(k)) }
@_cdecl("SecKeyIsAlgorithmSupported")
public func _c_SecKeyIsAlgorithmSupported(_ k: UnsafeRawPointer, _ op: Int, _ alg: CFString) -> Bool {
    guard let o = SecKeyOperationType(rawValue: op) else { return false }
    return SecKeyIsAlgorithmSupported(key(k), o, SecKeyAlgorithm(rawValue: alg))
}
@_cdecl("SecKeyCreateSignature")
public func _c_SecKeyCreateSignature(_ k: UnsafeRawPointer, _ alg: CFString, _ data: CFData, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    retained(SecKeyCreateSignature(key(k), SecKeyAlgorithm(rawValue: alg), data, error))
}
@_cdecl("SecKeyVerifySignature")
public func _c_SecKeyVerifySignature(_ k: UnsafeRawPointer, _ alg: CFString, _ data: CFData, _ sig: CFData,
                              _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Bool {
    SecKeyVerifySignature(key(k), SecKeyAlgorithm(rawValue: alg), data, sig, error)
}
@_cdecl("SecKeyCreateEncryptedData")
public func _c_SecKeyCreateEncryptedData(_ k: UnsafeRawPointer, _ alg: CFString, _ data: CFData, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    retained(SecKeyCreateEncryptedData(key(k), SecKeyAlgorithm(rawValue: alg), data, error))
}
@_cdecl("SecKeyCreateDecryptedData")
public func _c_SecKeyCreateDecryptedData(_ k: UnsafeRawPointer, _ alg: CFString, _ data: CFData, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? {
    retained(SecKeyCreateDecryptedData(key(k), SecKeyAlgorithm(rawValue: alg), data, error))
}
@_cdecl("SecRandomCopyBytes")
public func _c_SecRandomCopyBytes(_ rnd: OpaquePointer?, _ count: Int, _ bytes: UnsafeMutableRawPointer) -> Int32 { SecRandomCopyBytes(rnd, count, bytes) }
