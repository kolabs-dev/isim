// isim Network framework: the Security protocol objects TLS uses beyond sec_protocol_options_t (Connection.swift) —
// identities (a TLS server's, a client certificate), certificates and trust objects carrying the peer's certificate
// chain, so a verify block can evaluate or pin it with SecTrust.
@_exported import Foundation
import Security
import isim_host

/// an identity for TLS: a certificate (with the rest of its chain) and its private key
public final class sec_identity_t: @unchecked Sendable {
    let identity: SecIdentity
    let certificates: [SecCertificate]
    init(_ i: SecIdentity, _ certs: [SecCertificate]) { identity = i; certificates = certs }

    /// the identity as OpenSSL reads it: the certificate, the other certificates of its chain, the private key (PEM)
    var pem: String? {
        func block(_ label: String, _ der: Data) -> String {
            "-----BEGIN \(label)-----\n" + der.base64EncodedString(options: .lineLength64Characters) + "\n-----END \(label)-----\n"
        }
        var cert: SecCertificate?, key: SecKey?
        guard SecIdentityCopyCertificate(identity, &cert) == errSecSuccess, let cert, SecIdentityCopyPrivateKey(identity, &key) == errSecSuccess, let key,
              let raw = SecKeyCopyExternalRepresentation(key, nil) as Data? else { return nil }
        var text = block("CERTIFICATE", SecCertificateCopyData(cert) as Data)
        for c in certificates where c != cert { text += block("CERTIFICATE", SecCertificateCopyData(c) as Data) }
        let attrs = SecKeyCopyAttributes(key) as? [String: Any]
        let ec = (attrs?[kSecAttrKeyType as String] as? String) == (kSecAttrKeyTypeEC as String)
        var der = [UInt8](repeating: 0, count: 8192), n = der.count
        let bytes = [UInt8](raw)
        guard bytes.withUnsafeBufferPointer({ r in der.withUnsafeMutableBufferPointer { isim_pki_key_der(ec ? 1 : 0, r.baseAddress!, r.count, $0.baseAddress, &n) } }) == 1 else { return nil }
        return text + block(ec ? "EC PRIVATE KEY" : "RSA PRIVATE KEY", Data(der[0..<n]))
    }
}
public func sec_identity_create(_ identity: SecIdentity) -> sec_identity_t? { sec_identity_t(identity, []) }
public func sec_identity_create_with_certificates(_ identity: SecIdentity, _ certificates: CFArray) -> sec_identity_t? {
    sec_identity_t(identity, (certificates as? [SecCertificate]) ?? [])
}
public func sec_identity_copy_ref(_ identity: sec_identity_t) -> Unmanaged<SecIdentity>? { Unmanaged.passRetained(identity.identity) }
public func sec_identity_copy_certificates_ref(_ identity: sec_identity_t) -> Unmanaged<CFArray>? {
    identity.certificates.isEmpty ? nil : Unmanaged.passRetained(identity.certificates as CFArray)
}

/// a certificate of a TLS peer
public final class sec_certificate_t: @unchecked Sendable {
    let certificate: SecCertificate
    init(_ c: SecCertificate) { certificate = c }
}
public func sec_certificate_create(_ certificate: SecCertificate) -> sec_certificate_t? { sec_certificate_t(certificate) }
public func sec_certificate_copy_ref(_ certificate: sec_certificate_t) -> Unmanaged<SecCertificate> { Unmanaged.passRetained(certificate.certificate) }

public func sec_trust_create(_ trust: SecTrust) -> sec_trust_t? {
    let t = sec_trust_t(host: nil)
    t.trust = trust
    return t
}
/// the peer's certificate chain as a SecTrust with the SSL policy for the server's name (evaluate it, or pin a certificate)
public func sec_trust_copy_ref(_ trust: sec_trust_t) -> Unmanaged<SecTrust> {
    if let t = trust.trust { return Unmanaged.passRetained(t) }
    let certs = trust.certificates.compactMap { SecCertificateCreateWithData(nil, $0 as CFData) }
    var out: SecTrust?
    _ = SecTrustCreateWithCertificates(certs as CFArray, SecPolicyCreateSSL(true, trust.host.map { $0 as CFString }), &out)
    trust.trust = out
    return Unmanaged.passRetained(out!)
}

public func sec_protocol_options_set_local_identity(_ options: sec_protocol_options_t, _ identity: sec_identity_t) { options.identity = identity }
public func sec_protocol_options_set_max_tls_protocol_version(_ options: sec_protocol_options_t, _ version: tls_protocol_version_t) { options.maxVersion = version }
public func sec_protocol_options_append_tls_ciphersuite(_ options: sec_protocol_options_t, _ ciphersuite: UInt16) {}
public func sec_protocol_options_set_tls_resumption_enabled(_ options: sec_protocol_options_t, _ resumptionEnabled: Bool) {}
public func sec_protocol_options_set_tls_tickets_enabled(_ options: sec_protocol_options_t, _ ticketsEnabled: Bool) {}
public func sec_protocol_options_set_challenge_block(_ options: sec_protocol_options_t,
                                                     _ challengeBlock: @escaping (sec_protocol_metadata_t, @escaping (sec_identity_t?) -> Void) -> Void,
                                                     _ queue: DispatchQueue) {
    options.challengeBlock = challengeBlock; options.challengeQueue = queue
}
/// the peer's certificates, leaf first
@discardableResult
public func sec_protocol_metadata_access_peer_certificate_chain(_ metadata: sec_protocol_metadata_t, _ handler: (sec_certificate_t) -> Void) -> Bool {
    let certs = metadata.peerCertificates.compactMap { SecCertificateCreateWithData(nil, $0 as CFData) }
    for c in certs { handler(sec_certificate_t(c)) }
    return !certs.isEmpty
}
