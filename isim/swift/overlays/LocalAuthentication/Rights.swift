// LARight (iOS 16): authorization as a right that is authorized with Face ID / Touch ID / the passcode, and rights
// persisted per app (LARightStore) with a P-256 key and an optional secret only an authorized right can use.
// Adapted: the keys are isim's Security keys (SecKey, P-256) kept with the app's rights in its container
// (Library/LocalAuthentication/rights.plist), not in a Secure Enclave; a right made with .biometryCurrentSet stops
// authorizing once the enrolled faces / fingers change (`biometry enrolled off`, then `on`).
import Foundation
import Security

// MARK: - Requirements

@objc(LABiometryFallbackRequirement) open class LABiometryFallbackRequirement: NSObject, @unchecked Sendable {
    let passcode: Bool
    init(passcode: Bool) { self.passcode = passcode }
    open class var `default`: LABiometryFallbackRequirement { LABiometryFallbackRequirement(passcode: false) }
    open class var devicePasscode: LABiometryFallbackRequirement { LABiometryFallbackRequirement(passcode: true) }
}

@objc(LAAuthenticationRequirement) open class LAAuthenticationRequirement: NSObject, @unchecked Sendable {
    /// "default": biometry or the passcode; "biometry": biometry only; "currentSet": biometry, this enrollment only
    let kind: String, fallback: Bool
    public required init(_isimKind kind: String, fallback: Bool) { self.kind = kind; self.fallback = fallback }
    open class var `default`: LAAuthenticationRequirement { LAAuthenticationRequirement(_isimKind: "default", fallback: true) }
    open class var biometry: LAAuthenticationRequirement { LAAuthenticationRequirement(_isimKind: "biometry", fallback: false) }
    open class var biometryCurrentSet: LAAuthenticationRequirement { LAAuthenticationRequirement(_isimKind: "currentSet", fallback: false) }
    open class func biometry(fallback: LABiometryFallbackRequirement) -> Self { Self(_isimKind: "biometry", fallback: fallback.passcode) }
    var policy: LAPolicy { fallback ? .deviceOwnerAuthentication : .deviceOwnerAuthenticationWithBiometrics }
}

// MARK: - LARight

@objc(LARight) open class LARight: NSObject, @unchecked Sendable {
    @objc(LARightState) public enum State: Int, Sendable { case unknown = 0, authorizing = 1, authorized = 2, notAuthorized = 3 }

    @objc open dynamic private(set) var state: State = .unknown
    open var tag: Int = 0
    let requirement: LAAuthenticationRequirement
    /// a persisted .biometryCurrentSet right: the enrollment it was saved under
    var enrollment: Int?
    var context = LAContext()

    public override init() { requirement = .default; super.init() }
    public init(requirement: LAAuthenticationRequirement) { self.requirement = requirement; super.init() }

    func availability() -> Error? {
        var e: NSError?
        let ctx = LAContext()
        if !ctx.canEvaluatePolicy(requirement.policy, error: &e) { return e }
        if requirement.kind == "currentSet", let n = enrollment, n != _LADevice.enrollment {
            return LAError(.invalidContext, message: "The biometric enrollment changed since the right was saved.")
        }
        return nil
    }

    open func checkCanAuthorize(completion: @escaping @Sendable (Error?) -> Void) {
        let e = availability()
        DispatchQueue.global().async { completion(e) }
    }
    open func checkCanAuthorize() async throws {
        if let e = availability() { throw e }
    }

    open func authorize(localizedReason: String, completion: @escaping @Sendable (Error?) -> Void) {
        if let e = availability() { setState(.notAuthorized); DispatchQueue.global().async { completion(e) }; return }
        setState(.authorizing)
        let ctx = LAContext()
        ctx.evaluatePolicy(requirement.policy, localizedReason: localizedReason) { [self] ok, e in
            if ok { context = ctx }
            setState(ok ? .authorized : .notAuthorized)
            NSLog("isim LocalAuthentication: right %@", ok ? "authorized" : "not authorized")
            completion(ok ? nil : e)
        }
    }
    open func authorize(localizedReason: String) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            authorize(localizedReason: localizedReason) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }

    open func deauthorize(completion: @escaping @Sendable () -> Void) {
        context.invalidate()
        context = LAContext()
        setState(.notAuthorized)
        DispatchQueue.global().async { completion() }
    }
    open func deauthorize() async {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in deauthorize { k.resume() } }
    }

    func setState(_ s: State) {
        if Thread.isMainThread { state = s } else { DispatchQueue.main.sync { state = s } }
    }
    func requireAuthorized() throws {
        guard state == .authorized else { throw LAError(.authenticationFailed, message: "The right is not authorized.") }
    }
}

// MARK: - Keys and the secret of a persisted right

@objc(LAPublicKey) open class LAPublicKey: NSObject, @unchecked Sendable {
    let key: SecKey
    init(_ key: SecKey) { self.key = key }

    open func exportBytes(completion: @escaping @Sendable (Data?, Error?) -> Void) {
        var e: Unmanaged<CFError>?
        let d = SecKeyCopyExternalRepresentation(key, &e) as Data?
        DispatchQueue.global().async { completion(d, d == nil ? LAError(.invalidContext) : nil) }
    }
    open func exportBytes() async throws -> Data {
        guard let d = SecKeyCopyExternalRepresentation(key, nil) as Data? else { throw LAError(.invalidContext) }
        return d
    }
    open func canEncrypt(using algorithm: SecKeyAlgorithm) -> Bool { SecKeyIsAlgorithmSupported(key, .encrypt, algorithm) }
    open func encrypt(_ data: Data, algorithm: SecKeyAlgorithm, completion: @escaping @Sendable (Data?, Error?) -> Void) {
        let r = Result { try encrypt(data, algorithm) }
        DispatchQueue.global().async { completion(try? r.get(), r.error) }
    }
    open func encrypt(_ data: Data, algorithm: SecKeyAlgorithm) async throws -> Data { try encrypt(data, algorithm) }
    func encrypt(_ data: Data, _ algorithm: SecKeyAlgorithm) throws -> Data {
        var e: Unmanaged<CFError>?
        guard let d = SecKeyCreateEncryptedData(key, algorithm, data as CFData, &e) as Data? else { throw _LAKeyError(e) }
        return d
    }
    open func canVerify(using algorithm: SecKeyAlgorithm) -> Bool { SecKeyIsAlgorithmSupported(key, .verify, algorithm) }
    open func verify(_ signedData: Data, signature: Data, algorithm: SecKeyAlgorithm, completion: @escaping @Sendable (Error?) -> Void) {
        let r = Result { try verify(signedData, signature, algorithm) }
        DispatchQueue.global().async { completion(r.error) }
    }
    open func verify(_ signedData: Data, signature: Data, algorithm: SecKeyAlgorithm) async throws { try verify(signedData, signature, algorithm) }
    func verify(_ signedData: Data, _ signature: Data, _ algorithm: SecKeyAlgorithm) throws {
        var e: Unmanaged<CFError>?
        guard SecKeyVerifySignature(key, algorithm, signedData as CFData, signature as CFData, &e) else { throw _LAKeyError(e) }
    }
}

@objc(LAPrivateKey) open class LAPrivateKey: NSObject, @unchecked Sendable {
    let key: SecKey
    unowned let right: LARight
    public let publicKey: LAPublicKey
    init(_ key: SecKey, right: LARight) { self.key = key; self.right = right; publicKey = LAPublicKey(SecKeyCopyPublicKey(key)!) }

    open func canSign(using algorithm: SecKeyAlgorithm) -> Bool { SecKeyIsAlgorithmSupported(key, .sign, algorithm) }
    open func sign(_ data: Data, algorithm: SecKeyAlgorithm, completion: @escaping @Sendable (Data?, Error?) -> Void) {
        let r = Result { try sign(data, algorithm) }
        DispatchQueue.global().async { completion(try? r.get(), r.error) }
    }
    open func sign(_ data: Data, algorithm: SecKeyAlgorithm) async throws -> Data { try sign(data, algorithm) }
    func sign(_ data: Data, _ algorithm: SecKeyAlgorithm) throws -> Data {
        try right.requireAuthorized()
        var e: Unmanaged<CFError>?
        guard let d = SecKeyCreateSignature(key, algorithm, data as CFData, &e) as Data? else { throw _LAKeyError(e) }
        return d
    }
    open func canDecrypt(using algorithm: SecKeyAlgorithm) -> Bool { SecKeyIsAlgorithmSupported(key, .decrypt, algorithm) }
    open func decrypt(_ data: Data, algorithm: SecKeyAlgorithm, completion: @escaping @Sendable (Data?, Error?) -> Void) {
        let r = Result { try decrypt(data, algorithm) }
        DispatchQueue.global().async { completion(try? r.get(), r.error) }
    }
    open func decrypt(_ data: Data, algorithm: SecKeyAlgorithm) async throws -> Data { try decrypt(data, algorithm) }
    func decrypt(_ data: Data, _ algorithm: SecKeyAlgorithm) throws -> Data {
        try right.requireAuthorized()
        var e: Unmanaged<CFError>?
        guard let d = SecKeyCreateDecryptedData(key, algorithm, data as CFData, &e) as Data? else { throw _LAKeyError(e) }
        return d
    }
    open func canExchangeKeys(using algorithm: SecKeyAlgorithm) -> Bool { SecKeyIsAlgorithmSupported(key, .keyExchange, algorithm) }
    open func exchangeKeys(publicKey: Data, algorithm: SecKeyAlgorithm, parameters: [AnyHashable: Any],
                           completion: @escaping @Sendable (Data?, Error?) -> Void) {
        let r = Result { try exchange(publicKey, algorithm, parameters) }
        DispatchQueue.global().async { completion(try? r.get(), r.error) }
    }
    open func exchangeKeys(publicKey: Data, algorithm: SecKeyAlgorithm, parameters: [AnyHashable: Any]) async throws -> Data {
        try exchange(publicKey, algorithm, parameters)
    }
    func exchange(_ peer: Data, _ algorithm: SecKeyAlgorithm, _ parameters: [AnyHashable: Any]) throws -> Data {
        try right.requireAuthorized()
        let attrs: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeyClass as String: kSecAttrKeyClassPublic]
        var e: Unmanaged<CFError>?
        guard let other = SecKeyCreateWithData(peer as CFData, attrs as CFDictionary, &e),
              let d = SecKeyCopyKeyExchangeResult(key, algorithm, other, parameters as NSDictionary as CFDictionary, &e) as Data? else { throw _LAKeyError(e) }
        return d
    }
}

func _LAKeyError(_ e: Unmanaged<CFError>?) -> Error { e.map { $0.takeRetainedValue() as Error } ?? LAError(.invalidContext) }

extension Result where Failure == Error {
    var error: Error? { if case .failure(let e) = self { return e }; return nil }
}

@objc(LASecret) open class LASecret: NSObject, @unchecked Sendable {
    let data: Data?
    unowned let right: LARight
    init(_ data: Data?, right: LARight) { self.data = data; self.right = right }
    open func loadData(completion: @escaping @Sendable (Data?, Error?) -> Void) {
        let r = Result { try loadNow() }
        DispatchQueue.global().async { completion(try? r.get(), r.error) }
    }
    open func load() async throws -> Data { try loadNow() }
    func loadNow() throws -> Data {
        try right.requireAuthorized()
        guard let data else { throw LAError(.invalidContext, message: "The right was saved without a secret.") }
        return data
    }
}

@objc(LAPersistedRight) open class LAPersistedRight: LARight, @unchecked Sendable {
    let identifier: String
    private var _key: LAPrivateKey!
    private var _secret: LASecret!
    open var key: LAPrivateKey { _key }
    open var secret: LASecret { _secret }
    init(identifier: String, requirement: LAAuthenticationRequirement, key: SecKey, secret: Data?, enrollment: Int?) {
        self.identifier = identifier
        super.init(requirement: requirement)
        self.enrollment = enrollment
        _key = LAPrivateKey(key, right: self)
        _secret = LASecret(secret, right: self)
    }
}

// MARK: - LARightStore

@objc(LARightStore) open class LARightStore: NSObject, @unchecked Sendable {
    static let _shared = LARightStore()
    open class var shared: LARightStore { _shared }
    let lock = NSLock()

    var path: String { (NSHomeDirectory() as NSString).appendingPathComponent("Library/LocalAuthentication/rights.plist") }
    func load() -> [String: [String: Any]] {
        guard let d = FileManager.default.contents(atPath: path),
              let p = try? PropertyListSerialization.propertyList(from: d, format: nil) as? [String: [String: Any]] else { return [:] }
        return p
    }
    func store(_ all: [String: [String: Any]]) {
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        if let d = try? PropertyListSerialization.data(fromPropertyList: all, format: .binary, options: 0) { FileManager.default.createFile(atPath: path, contents: d) }
    }
    func make(_ id: String, _ e: [String: Any]) -> LAPersistedRight? {
        let attrs: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeyClass as String: kSecAttrKeyClassPrivate]
        guard let keyData = e["key"] as? Data, let key = SecKeyCreateWithData(keyData as CFData, attrs as CFDictionary, nil) else { return nil }
        let req = LAAuthenticationRequirement(_isimKind: e["requirement"] as? String ?? "default", fallback: e["fallback"] as? Bool ?? true)
        return LAPersistedRight(identifier: id, requirement: req, key: key, secret: e["secret"] as? Data, enrollment: e["enrollment"] as? Int)
    }

    func right(_ id: String) throws -> LAPersistedRight {
        lock.lock(); defer { lock.unlock() }
        guard let e = load()[id], let r = make(id, e) else { throw LAError(.invalidContext, message: "No right with the identifier \(id).") }
        return r
    }
    func save(_ right: LARight, _ id: String, _ secret: Data?) throws -> LAPersistedRight {
        lock.lock(); defer { lock.unlock() }
        var all = load()
        guard all[id] == nil else { throw LAError(.invalidContext, message: "A right with the identifier \(id) is already saved.") }
        let params: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits as String: 256]
        var err: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(params as CFDictionary, &err), let keyData = SecKeyCopyExternalRepresentation(key, &err) as Data? else {
            throw _LAKeyError(err)
        }
        var e: [String: Any] = ["key": keyData, "requirement": right.requirement.kind, "fallback": right.requirement.fallback]
        if let secret { e["secret"] = secret }
        if right.requirement.kind == "currentSet" { e["enrollment"] = _LADevice.enrollment }
        all[id] = e
        store(all)
        NSLog("isim LocalAuthentication: right %@ saved (%@ key, secret: %@)", id, "P-256", secret == nil ? "no" : "yes")
        return make(id, e)!
    }
    func remove(_ id: String?) {
        lock.lock(); defer { lock.unlock() }
        var all = load()
        if let id { all[id] = nil } else { all = [:] }
        store(all)
    }

    open func right(forIdentifier identifier: String, completion: @escaping @Sendable (LAPersistedRight?, Error?) -> Void) {
        let r = Result { try right(identifier) }
        DispatchQueue.global().async { completion(try? r.get(), r.error) }
    }
    open func right(forIdentifier identifier: String) async throws -> LAPersistedRight { try right(identifier) }
    open func saveRight(_ right: LARight, identifier: String, completion: @escaping @Sendable (LAPersistedRight?, Error?) -> Void) {
        let r = Result { try save(right, identifier, nil) }
        DispatchQueue.global().async { completion(try? r.get(), r.error) }
    }
    open func saveRight(_ right: LARight, identifier: String) async throws -> LAPersistedRight { try save(right, identifier, nil) }
    open func saveRight(_ right: LARight, identifier: String, secret: Data, completion: @escaping @Sendable (LAPersistedRight?, Error?) -> Void) {
        let r = Result { try save(right, identifier, secret) }
        DispatchQueue.global().async { completion(try? r.get(), r.error) }
    }
    open func saveRight(_ right: LARight, identifier: String, secret: Data) async throws -> LAPersistedRight { try save(right, identifier, secret) }
    open func removeRight(_ right: LAPersistedRight, completion: @escaping @Sendable (Error?) -> Void) {
        remove(right.identifier); DispatchQueue.global().async { completion(nil) }
    }
    open func removeRight(_ right: LAPersistedRight) async throws { remove(right.identifier) }
    open func removeRight(forIdentifier identifier: String, completion: @escaping @Sendable (Error?) -> Void) {
        remove(identifier); DispatchQueue.global().async { completion(nil) }
    }
    open func removeRight(forIdentifier identifier: String) async throws { remove(identifier) }
    open func removeAllRights(completion: @escaping @Sendable (Error?) -> Void) {
        remove(nil); DispatchQueue.global().async { completion(nil) }
    }
    open func removeAllRights() async throws { remove(nil) }
}
