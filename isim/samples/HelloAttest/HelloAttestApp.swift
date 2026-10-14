// Sample: isim's simulated Secure Enclave and local DeviceCheck / App Attest. A CryptoKit Secure Enclave key protected
// by Face ID (each signature asks; an LAContext that already authenticated signs without asking again), a DeviceCheck
// token (checked with `isim devicecheck`), and App Attest: the app plays the server too, verifying the attestation
// object (CBOR, x5c, the nonce extension, the key id, the AAGUID) and each assertion (signature, counter). Results are
// printed for tests/ui/test_attest.py.
import SwiftUI
import CryptoKit
import Security
import LocalAuthentication
import DeviceCheck

@main
struct HelloAttestApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

/// a small CBOR reader (what an App Attest server needs: maps, arrays, byte and text strings, integers)
indirect enum CBOR {
    case int(Int), bytes(Data), text(String), array([CBOR]), map([(CBOR, CBOR)])
    subscript(_ key: String) -> CBOR? {
        guard case .map(let m) = self else { return nil }
        return m.first { if case .text(key) = $0.0 { return true }; return false }?.1
    }
    var data: Data? { if case .bytes(let d) = self { return d }; return nil }
    static func decode(_ d: Data) -> CBOR? { var i = d.startIndex; return read(d, &i) }
    static func read(_ d: Data, _ i: inout Data.Index) -> CBOR? {
        guard i < d.endIndex else { return nil }
        let head = d[i]; i += 1
        let major = head >> 5, info = Int(head & 0x1f)
        var n = info
        if info >= 24 {
            let len = [24: 1, 25: 2, 26: 4, 27: 8][info] ?? 0
            guard len > 0, i + len <= d.endIndex else { return nil }
            n = d[i..<(i + len)].reduce(0) { $0 << 8 | Int($1) }; i += len
        }
        switch major {
        case 0: return .int(n)
        case 1: return .int(-1 - n)
        case 2, 3:
            guard i + n <= d.endIndex else { return nil }
            let s = Data(d[i..<(i + n)]); i += n
            return major == 2 ? .bytes(s) : .text(String(decoding: s, as: UTF8.self))
        case 4: var a: [CBOR] = []; for _ in 0..<n { guard let v = read(d, &i) else { return nil }; a.append(v) }; return .array(a)
        case 5:
            var m: [(CBOR, CBOR)] = []
            for _ in 0..<n { guard let k = read(d, &i), let v = read(d, &i) else { return nil }; m.append((k, v)) }
            return .map(m)
        default: return nil
        }
    }
}

/// the app's App Attest "server": what it keeps after verifying an attestation, and its assertion checks
enum AttestServer {
    static let appID = "ISIMTEAM00.dev.isim.samples.HelloAttest"
    static var publicKey: P256.Signing.PublicKey?
    static var counter: UInt32 = 0
    static func find(_ d: Data, _ pat: [UInt8]) -> Int? {
        let a = Array(d)
        guard a.count >= pat.count else { return nil }
        for i in 0...(a.count - pat.count) where Array(a[i..<(i + pat.count)]) == pat { return i }
        return nil
    }
    static func verifyAttestation(_ obj: Data, keyId: String, clientDataHash: Data) {
        guard let cbor = CBOR.decode(obj), case .text(let fmt)? = cbor["fmt"], let auth = cbor["authData"]?.data,
              case .array(let x5c)? = cbor["attStmt"]?["x5c"], let leafDER = x5c.first?.data,
              let leaf = SecCertificateCreateWithData(nil, leafDER as CFData), let leafKey = SecCertificateCopyKey(leaf),
              let raw = SecKeyCopyExternalRepresentation(leafKey, nil) as Data? else { print("attestation: unreadable"); return }
        let a = Array(auth)
        // the nonce: SHA-256(authData ‖ clientDataHash), in the credential certificate's extension 1.2.840.113635.100.8.2
        let nonce = Data(SHA256.hash(data: auth + clientDataHash))
        let oid: [UInt8] = [0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x08, 0x02]
        let nonceOK = find(leafDER, oid).map { find(leafDER[($0 + oid.count)...], Array(nonce)) != nil } ?? false
        let key = try? P256.Signing.PublicKey(x963Representation: raw)
        let keyIdOK = Data(SHA256.hash(data: raw)).base64EncodedString() == keyId
        let rpOK = Data(a[0..<32]) == Data(SHA256.hash(data: Data(appID.utf8)))
        let counter = a[33..<37].reduce(0) { $0 << 8 | UInt32($1) }
        let aaguid = String(decoding: a[37..<53].filter { $0 != 0 }, as: UTF8.self)
        let idLen = Int(a[53]) << 8 | Int(a[54])
        let credOK = Data(a[55..<(55 + idLen)]).base64EncodedString() == keyId
        publicKey = key; self.counter = counter
        print("attestation: fmt=\(fmt) x5c=\(x5c.count) nonce=\(nonceOK) keyId=\(keyIdOK) credentialId=\(credOK) appId=\(rpOK) aaguid=\(aaguid) counter=\(counter) receipt=\(cbor["attStmt"]?["receipt"]?.data != nil)")
        print("attestation object: \(obj.base64EncodedString())")
    }
    static func verifyAssertion(_ obj: Data, clientDataHash: Data) {
        guard let cbor = CBOR.decode(obj), let auth = cbor["authenticatorData"]?.data, let sigDER = cbor["signature"]?.data,
              let key = publicKey, let sig = try? P256.Signing.ECDSASignature(derRepresentation: sigDER) else { print("assertion: unreadable"); return }
        let nonce = Data(SHA256.hash(data: auth + clientDataHash))
        let ok = key.isValidSignature(sig, for: nonce)
        let a = Array(auth), c = a[33..<37].reduce(0) { $0 << 8 | UInt32($1) }
        let rpOK = Data(a[0..<32]) == Data(SHA256.hash(data: Data(appID.utf8)))
        print("assertion: verified=\(ok) appId=\(rpOK) counter=\(c) increased=\(c > counter)")
        counter = c
    }
}

@MainActor final class Model: ObservableObject {
    @Published var enclave = "No key"
    @Published var attest = "Not attested"
    var keyData: Data? {
        get { UserDefaults.standard.object(forKey: "enclaveKey") as? Data }
        set { UserDefaults.standard.set(newValue, forKey: "enclaveKey") }
    }
    var keyId: String?

    func createKey() {
        guard SecureEnclave.isAvailable else { print("enclave: unavailable"); enclave = "No Secure Enclave"; return }
        let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, [.privateKeyUsage, .biometryCurrentSet], nil)!
        do {
            let key = try SecureEnclave.P256.Signing.PrivateKey(accessControl: access)
            keyData = key.dataRepresentation
            enclave = "Key created"
            print("enclave key created: available=true blob=\(key.dataRepresentation.count) public=\(key.publicKey.rawRepresentation.count)")
        } catch { print("enclave create failed: \(error)") }
    }
    /// signing asks for Face ID (the key's access control)
    func sign(context: LAContext? = nil, label: String = "enclave") {
        guard let d = keyData else { print("\(label): no key"); return }
        do {
            let key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: d, authenticationContext: context)
            let message = Data("transfer 10 coins".utf8)
            let sig = try key.signature(for: message)
            enclave = "Signed"
            print("\(label) signature verified: \(key.publicKey.isValidSignature(sig, for: message))")
        } catch {
            enclave = "Not signed"
            print("\(label) sign failed: \((error as NSError).domain) \((error as NSError).code)")
        }
    }
    /// one Face ID for several signatures: an LAContext that already authenticated
    func signWithContext() {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Sign two transfers") { ok, _ in
            DispatchQueue.main.async {
                print("context authenticated: \(ok)")
                self.sign(context: context, label: "context 1")
                self.sign(context: context, label: "context 2")
            }
        }
    }
    func deviceToken() {
        print("devicecheck supported: \(DCDevice.current.isSupported)")
        DCDevice.current.generateToken { token, error in
            if let token { print("device token: \(String(decoding: token, as: UTF8.self))") } else { print("device token failed: \(String(describing: error))") }
        }
    }
    func attestKey() {
        let service = DCAppAttestService.shared
        print("app attest supported: \(service.isSupported)")
        Task {
            do {
                let id = try await service.generateKey()
                let hash = Data(SHA256.hash(data: Data("server challenge 1".utf8)))
                let obj = try await service.attestKey(id, clientDataHash: hash)
                keyId = id
                AttestServer.verifyAttestation(obj, keyId: id, clientDataHash: hash)
                attest = "Attested"
                do { _ = try await service.attestKey(id, clientDataHash: hash) } catch { print("attest again: \((error as NSError).code)") }
            } catch { print("attest failed: \(error)") }
        }
    }
    func assertion(_ n: Int) {
        guard let id = keyId else { print("assertion: no key"); return }
        Task {
            do {
                let hash = Data(SHA256.hash(data: Data("request \(n)".utf8)))
                AttestServer.verifyAssertion(try await DCAppAttestService.shared.generateAssertion(id, clientDataHash: hash), clientDataHash: hash)
                attest = "Assertion \(n)"
            } catch { print("assertion failed: \(error)") }
        }
    }
}

struct ContentView: View {
    @StateObject var model = Model()
    @State private var requests = 0
    var body: some View {
        NavigationStack {
            List {
                Section("Secure Enclave") {
                    Label(model.enclave, systemImage: "lock.shield").accessibilityIdentifier("enclave")
                    Button("Create key (Face ID to use)") { model.createKey() }.accessibilityIdentifier("enclave-create")
                    Button("Sign") { model.sign() }.accessibilityIdentifier("enclave-sign")
                    Button("Sign twice, one Face ID") { model.signWithContext() }.accessibilityIdentifier("enclave-context")
                }
                Section("DeviceCheck") {
                    Button("Device token") { model.deviceToken() }.accessibilityIdentifier("devicecheck")
                }
                Section("App Attest") {
                    Label(model.attest, systemImage: "checkmark.circle.fill").accessibilityIdentifier("attest-status")
                    Button("Attest a new key") { model.attestKey() }.accessibilityIdentifier("attest")
                    Button("Signed request") { requests += 1; model.assertion(requests) }.accessibilityIdentifier("assert")
                }
            }
            .navigationTitle("Attest")
        }
        .onAppear { print("launched; secure enclave available: \(SecureEnclave.isAvailable)") }
    }
}
