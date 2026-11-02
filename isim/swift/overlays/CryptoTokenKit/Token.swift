// isim CryptoTokenKit: token drivers, tokens and token sessions (issue #743). A persistent token extension
// (NSExtensionPointIdentifier com.apple.ctk-tokens) names its driver class (NSExtensionPrincipalClass, a
// TKSmartCardTokenDriver or TKTokenDriver subclass) and its class ID (NSExtensionAttributes com.apple.ctk.class-id). isim
// runs it in the process that uses the token (TokenHost.swift): the driver creates a TKSmartCardToken for an inserted
// virtual card, the token fills its TKTokenKeychainContents, and Security's keychain lists them (kSecAttrTokenID). Using
// a token key creates a TKTokenSession; its delegate signs, decrypts or agrees on keys, and asks for authentication
// (TKTokenAuthOperation) when the card needs the PIN. Adapted: Apple runs the extension in its own process.
import Foundation
import Security
internal import CommonCrypto

@objc(TKTokenOperation) public enum TKTokenOperation: Int, Sendable {
    case none = 0, readData = 1, signData = 2, decryptData = 3, performKeyExchange = 4
}
public typealias TKTokenOperationConstraint = Any

// MARK: - keys, algorithms

/// the algorithm an operation asks for; the token answers which ones it can use
@objc(TKTokenKeyAlgorithm) open class TKTokenKeyAlgorithm: NSObject {
    let requested: SecKeyAlgorithm
    /// the algorithm the token accepted in supportsAlgorithm (the data is converted to it)
    var accepted: SecKeyAlgorithm?
    init(_ requested: SecKeyAlgorithm) { self.requested = requested; super.init() }
    open func isAlgorithm(_ algorithm: SecKeyAlgorithm) -> Bool {
        let yes = (algorithm.rawValue as String) == (requested.rawValue as String)
        if yes { accepted = algorithm }
        return yes
    }
    /// true when the requested algorithm is this one or can be converted to it (a message algorithm to its digest form,
    /// a digest with a hash to the plain digest; a cofactor or X9.63 key exchange to the standard one)
    open func supportsAlgorithm(_ algorithm: SecKeyAlgorithm) -> Bool {
        if isAlgorithm(algorithm) { return true }
        guard TKTokenKeyAlgorithm.convert(requested, to: algorithm, Data()) != nil else { return false }
        accepted = algorithm
        return true
    }
    // Objective-C: SecKeyAlgorithm is a CFStringRef
    @objc(isAlgorithm:) func _objcIsAlgorithm(_ algorithm: String) -> Bool { isAlgorithm(SecKeyAlgorithm(rawValue: algorithm as CFString)) }
    @objc(supportsAlgorithm:) func _objcSupportsAlgorithm(_ algorithm: String) -> Bool { supportsAlgorithm(SecKeyAlgorithm(rawValue: algorithm as CFString)) }
    /// the data for `target` from data for `from`, or nil when it cannot be converted
    static func convert(_ from: SecKeyAlgorithm, to target: SecKeyAlgorithm, _ data: Data) -> Data? {
        let f = from.rawValue as String, t = target.rawValue as String
        if f == t { return data }
        let fp = f.split(separator: ":").map(String.init), tp = t.split(separator: ":").map(String.init)
        if fp.count >= 3, tp.count == 3, fp[1] == "keyexchange", tp[1] == "keyexchange", fp[2] == tp[2] { return data }   // ECDH:KDFX963:SHA256 -> ECDH
        guard fp.count >= 4, tp.count >= 4, fp[1] == "sign", tp[1] == "sign", fp[2] == tp[2] else { return nil }
        let fKind = fp[3], tKind = tp[3]
        if fKind.hasPrefix("message-"), tKind == "digest-" + fKind.dropFirst(8) {          // message-X962:SHA256 -> digest-X962(:SHA256)
            guard fp.count >= 5, tp.count == 4 || tp[4] == fp[4] else { return nil }
            return _tkDigest(fp[4], data)
        }
        if fKind.hasPrefix("digest-"), tKind == fKind, fp.count >= 5, tp.count == 4 { return data }   // digest-X962:SHA256 -> digest-X962
        return nil
    }
}

func _tkDigest(_ hash: String, _ data: Data) -> Data? {
    let d = [UInt8](data)
    var out = [UInt8](repeating: 0, count: 64)
    let n: Int
    switch hash {
    case "SHA1": n = 20; _ = CC_SHA1(d, CC_LONG(d.count), &out)
    case "SHA224": n = 28; _ = CC_SHA224(d, CC_LONG(d.count), &out)
    case "SHA256": n = 32; _ = CC_SHA256(d, CC_LONG(d.count), &out)
    case "SHA384": n = 48; _ = CC_SHA384(d, CC_LONG(d.count), &out)
    case "SHA512": n = 64; _ = CC_SHA512(d, CC_LONG(d.count), &out)
    default: return nil
    }
    return Data(out.prefix(n))
}

@objc(TKTokenKeyExchangeParameters) open class TKTokenKeyExchangeParameters: NSObject {
    @objc open var requestedSize: Int { _requestedSize }
    @objc open var sharedInfo: Data? { _sharedInfo }
    let _requestedSize: Int, _sharedInfo: Data?
    init(requestedSize: Int, sharedInfo: Data?) { _requestedSize = requestedSize; _sharedInfo = sharedInfo; super.init() }
}

// MARK: - keychain items

@objc(TKTokenKeychainItem) open class TKTokenKeychainItem: NSObject {
    @objc public let objectID: Any
    @objc open var label: String?
    /// constraints by operation (NSNumber of a TKTokenOperation): what using the item for it requires
    @objc open var constraints: [NSNumber: Any]?
    @objc(initWithObjectID:) public init(objectID: Any) { self.objectID = objectID; super.init() }
}

@objc(TKTokenKeychainCertificate) open class TKTokenKeychainCertificate: TKTokenKeychainItem {
    @objc public let data: Data
    public init?(certificate certificateRef: SecCertificate, objectID: Any) {
        data = SecCertificateCopyData(certificateRef) as Data
        super.init(objectID: objectID)
    }
    /// Objective-C: a SecCertificateRef
    @objc(initWithCertificate:objectID:) convenience init?(_objcCertificate ref: UnsafeRawPointer, objectID: Any) {
        self.init(certificate: Unmanaged<SecCertificate>.fromOpaque(ref).takeUnretainedValue(), objectID: objectID)
    }
    @objc(initWithObjectID:) public override init(objectID: Any) { data = Data(); super.init(objectID: objectID) }
}

@objc(TKTokenKeychainKey) open class TKTokenKeychainKey: TKTokenKeychainItem {
    @objc open var keyType: String = kSecAttrKeyTypeECSECPrimeRandom as String
    @objc open var keySizeInBits: Int = 0
    @objc open var applicationTag: Data?
    @objc open var publicKeyData: Data?
    @objc open var publicKeyHash: Data?
    @objc open var canDecrypt = false
    @objc open var canSign = false
    @objc open var canPerformKeyExchange = false
    @objc open var isSuitableForLogin: Bool {
        @objc(isSuitableForLogin) get { _login }
        @objc(setSuitableForLogin:) set { _login = newValue }
    }
    private var _login = false
    /// a key for the certificate's public key (its type, size, public key and hash), or with nil a key to describe
    @objc(initWithCertificate:objectID:) convenience init?(_objcCertificate ref: UnsafeRawPointer?, objectID: Any) {
        self.init(certificate: ref.map { Unmanaged<SecCertificate>.fromOpaque($0).takeUnretainedValue() }, objectID: objectID)
    }
    public init?(certificate certificateRef: SecCertificate?, objectID: Any) {
        super.init(objectID: objectID)
        guard let c = certificateRef else { return }
        guard let pub = SecCertificateCopyKey(c), let attrs = SecKeyCopyAttributes(pub) as? [String: Any],
              let raw = SecKeyCopyExternalRepresentation(pub, nil) as Data? else { return nil }
        keyType = attrs[kSecAttrKeyType as String] as? String ?? keyType
        keySizeInBits = attrs[kSecAttrKeySizeInBits as String] as? Int ?? 0
        publicKeyData = raw
        publicKeyHash = attrs[kSecAttrApplicationLabel as String] as? Data
    }
    @objc(initWithObjectID:) public override init(objectID: Any) { super.init(objectID: objectID) }
}

@objc(TKTokenKeychainContents) open class TKTokenKeychainContents: NSObject {
    private(set) var _items: [TKTokenKeychainItem] = []
    @objc open var items: [TKTokenKeychainItem] { _items }
    override init() { super.init() }
    /// replaces the token's items (as the token reads them from its card)
    @objc(fillWithItems:) open func fill(with items: [TKTokenKeychainItem]) { _items = items }
    @objc(keyForObjectID:error:) open func key(forObjectID objectID: Any) throws -> TKTokenKeychainKey {
        guard let k = _items.first(where: { _tkSameObject($0.objectID, objectID) }) as? TKTokenKeychainKey else {
            throw _tkError(.objectNotFound, "the token has no key \(objectID)")
        }
        return k
    }
    @objc(certificateForObjectID:error:) open func certificate(forObjectID objectID: Any) throws -> TKTokenKeychainCertificate {
        guard let c = _items.first(where: { _tkSameObject($0.objectID, objectID) }) as? TKTokenKeychainCertificate else {
            throw _tkError(.objectNotFound, "the token has no certificate \(objectID)")
        }
        return c
    }
}

func _tkSameObject(_ a: Any, _ b: Any) -> Bool { (a as AnyObject).isEqual(b as AnyObject) }

// MARK: - authentication

@objc(TKTokenAuthOperation) open class TKTokenAuthOperation: NSObject, NSSecureCoding {
    public override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {}
    public required init?(coder: NSCoder) { super.init() }
    /// called when the user has answered (the PIN or password is set); subclasses finish the authentication
    @objc(finishWithError:) open func finish() throws {}
}

@objc(TKTokenPasswordAuthOperation) open class TKTokenPasswordAuthOperation: TKTokenAuthOperation {
    @objc open var password: String?
}

@objc(TKTokenSmartCardPINAuthOperation) open class TKTokenSmartCardPINAuthOperation: TKTokenAuthOperation {
    @objc open var pinFormat = TKSmartCardPINFormat()
    @objc(APDUTemplate) open var apduTemplate: Data?
    @objc(PINByteOffset) open var pinByteOffset = 0
    @objc open var smartCard: TKSmartCard?
    @objc(PIN) open var pin: String?
    /// sends the APDU template with the PIN at pinByteOffset (in pinFormat) to the card; SW 9000 authenticates
    open override func finish() throws {
        guard let card = smartCard, let template = apduTemplate, let pin else { return }
        guard pinFormat.valid(pin) else { throw _tkError(.authenticationFailed, "the PIN does not match the PIN format") }
        var apdu = [UInt8](template)
        let block = pinFormat.block(pin)
        guard pinByteOffset >= 0, pinByteOffset + block.count <= apdu.count else { throw _tkError(.badParameter, "the PIN does not fit the APDU template") }
        apdu.replaceSubrange(pinByteOffset..<(pinByteOffset + block.count), with: block)
        let r = try card.exchange(apdu)
        guard r.suffix(2) == [0x90, 0x00] else {
            throw _tkError(.authenticationFailed, String(format: "the card refused the PIN (SW %02X%02X)", r.count >= 2 ? r[r.count - 2] : 0, r.last ?? 0))
        }
    }
}

// MARK: - drivers

@objc(TKTokenDriverDelegate) public protocol TKTokenDriverDelegate: NSObjectProtocol {
    @objc(tokenDriver:tokenForConfiguration:error:) optional func tokenDriver(_ driver: TKTokenDriver, tokenFor configuration: TKToken.Configuration) throws -> TKToken
    @objc(tokenDriver:terminateToken:) optional func tokenDriver(_ driver: TKTokenDriver, terminateToken token: TKToken)
}

@objc(TKSmartCardTokenDriverDelegate) public protocol TKSmartCardTokenDriverDelegate: TKTokenDriverDelegate {
    @objc(tokenDriver:createTokenForSmartCard:AID:error:)
    func tokenDriver(_ driver: TKSmartCardTokenDriver, createTokenFor smartCard: TKSmartCard, aid AID: Data?) throws -> TKSmartCardToken
}

@objc(TKTokenDriver) open class TKTokenDriver: NSObject {
    public typealias ClassID = String
    private weak var _delegate: TKTokenDriverDelegate?
    /// the delegate; a driver that implements the delegate protocol is its own delegate unless another is set
    @objc open weak var delegate: TKTokenDriverDelegate? {
        get { _delegate ?? (self as? TKTokenDriverDelegate) }
        set { _delegate = newValue }
    }
    /// the class ID of the extension the driver comes from
    var classID: String = ""
    public override init() { super.init() }

    /// the configuration of a token driver class and its tokens (kept in the device data)
    @objc(TKTokenDriverConfiguration) open class Configuration: NSObject, @unchecked Sendable {
        @objc public let classID: ClassID
        private var _tokens: [TKToken.InstanceID: TKToken.Configuration] = [:]
        init(classID: ClassID) {
            self.classID = classID
            super.init()
            for id in _TKTokenConfigStore.instances(classID) { _tokens[id] = TKToken.Configuration(classID: classID, instanceID: id) }
        }
        @objc open var tokenConfigurations: [TKToken.InstanceID: TKToken.Configuration] { _tokens }
        /// the configurations of the token drivers this app contains
        @objc open class var driverConfigurations: [ClassID: Configuration] {
            var out: [ClassID: Configuration] = [:]
            for x in _TKTokenHost.shared.extensions(ownOnly: true) { out[x.classID] = Configuration(classID: x.classID) }
            return out
        }
        @objc(addTokenConfigurationForTokenInstanceID:) open func addTokenConfiguration(for instanceID: TKToken.InstanceID) -> TKToken.Configuration {
            if let c = _tokens[instanceID] { return c }
            _TKTokenConfigStore.add(classID, instanceID)
            let c = TKToken.Configuration(classID: classID, instanceID: instanceID)
            _tokens[instanceID] = c
            return c
        }
        @objc(removeTokenConfigurationForTokenInstanceID:) open func removeTokenConfiguration(for instanceID: TKToken.InstanceID) {
            _TKTokenConfigStore.remove(classID, instanceID)
            _tokens[instanceID] = nil
        }
    }
}

@objc(TKSmartCardTokenDriver) open class TKSmartCardTokenDriver: TKTokenDriver {}

// MARK: - tokens

@objc(TKTokenDelegate) public protocol TKTokenDelegate: NSObjectProtocol {
    @objc(token:createSessionWithError:) func createSession(_ token: TKToken) throws -> TKTokenSession
    @objc(token:terminateSession:) optional func token(_ token: TKToken, terminateSession session: TKTokenSession)
}

@objc(TKToken) open class TKToken: NSObject {
    public typealias InstanceID = String
    public typealias ObjectID = Any
    @objc public let tokenDriver: TKTokenDriver
    let instanceID: InstanceID
    private weak var _delegate: TKTokenDelegate?
    /// the delegate; a token that implements TKTokenDelegate is its own delegate unless another is set
    @objc open weak var delegate: TKTokenDelegate? {
        get { _delegate ?? (self as? TKTokenDelegate) }
        set { _delegate = newValue }
    }
    private let _contents = TKTokenKeychainContents()
    @objc open var keychainContents: TKTokenKeychainContents? { _contents }
    @objc(initWithTokenDriver:instanceID:) public init(tokenDriver: TKTokenDriver, instanceID: InstanceID) {
        self.tokenDriver = tokenDriver; self.instanceID = instanceID
        super.init()
    }
    /// the token's ID: its driver's class ID and its instance ID
    var tokenID: String { "\(tokenDriver.classID):\(instanceID)" }
    @objc open var configuration: Configuration {
        TKTokenDriver.Configuration(classID: tokenDriver.classID).addTokenConfiguration(for: instanceID)
    }

    /// a token's configuration: data the app keeps for it and the keychain items it shows while the token is absent
    @objc(TKTokenConfiguration) open class Configuration: NSObject, @unchecked Sendable {
        let classID: String
        @objc public let instanceID: InstanceID
        init(classID: String, instanceID: InstanceID) { self.classID = classID; self.instanceID = instanceID; super.init() }
        @objc open var configurationData: Data? {
            get { _TKTokenConfigStore.data(classID, instanceID) }
            set { _TKTokenConfigStore.setData(classID, instanceID, newValue) }
        }
        private var _items: [TKTokenKeychainItem] = []
        @objc open var keychainItems: [TKTokenKeychainItem] {
            get { _items }
            set { _items = newValue }
        }
        @objc(keyForObjectID:error:) open func key(for objectID: Any) throws -> TKTokenKeychainKey {
            guard let k = _items.first(where: { _tkSameObject($0.objectID, objectID) }) as? TKTokenKeychainKey else {
                throw _tkError(.objectNotFound, "the configuration has no key \(objectID)")
            }
            return k
        }
        @objc(certificateForObjectID:error:) open func certificate(for objectID: Any) throws -> TKTokenKeychainCertificate {
            guard let c = _items.first(where: { _tkSameObject($0.objectID, objectID) }) as? TKTokenKeychainCertificate else {
                throw _tkError(.objectNotFound, "the configuration has no certificate \(objectID)")
            }
            return c
        }
    }
}

@objc(TKSmartCardToken) open class TKSmartCardToken: TKToken {
    @objc(AID) public let aid: Data?
    let smartCard: TKSmartCard
    @objc(initWithSmartCard:AID:instanceID:tokenDriver:)
    public init(smartCard: TKSmartCard, aid AID: Data?, instanceID: String, tokenDriver: TKSmartCardTokenDriver) {
        self.smartCard = smartCard; aid = AID
        super.init(tokenDriver: tokenDriver, instanceID: instanceID)
    }
    @available(*, deprecated, renamed: "init(smartCard:aid:instanceID:tokenDriver:)")
    public convenience init(smartCard: TKSmartCard, AID: Data?, instanceID: String, tokenDriver: TKSmartCardTokenDriver) {
        self.init(smartCard: smartCard, aid: AID, instanceID: instanceID, tokenDriver: tokenDriver)
    }
}

// MARK: - sessions

@objc(TKTokenSessionDelegate) public protocol TKTokenSessionDelegate: NSObjectProtocol {
    @objc(tokenSession:supportsOperation:usingKey:algorithm:)
    optional func tokenSession(_ session: TKTokenSession, supports operation: TKTokenOperation, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) -> Bool
    @objc(tokenSession:beginAuthForOperation:constraint:error:)
    optional func tokenSession(_ session: TKTokenSession, beginAuthFor operation: TKTokenOperation, constraint: Any) throws -> TKTokenAuthOperation
    @objc(tokenSession:signData:usingKey:algorithm:error:)
    optional func tokenSession(_ session: TKTokenSession, sign dataToSign: Data, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) throws -> Data
    @objc(tokenSession:decryptData:usingKey:algorithm:error:)
    optional func tokenSession(_ session: TKTokenSession, decrypt ciphertext: Data, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) throws -> Data
    @objc(tokenSession:performKeyExchangeWithPublicKey:usingKey:algorithm:parameters:error:)
    optional func tokenSession(_ session: TKTokenSession, performKeyExchange otherPartyPublicKeyData: Data, keyObjectID objectID: Any,
                               algorithm: TKTokenKeyAlgorithm, parameters: TKTokenKeyExchangeParameters) throws -> Data
}

@objc(TKTokenSession) open class TKTokenSession: NSObject {
    @objc public let token: TKToken
    private weak var _delegate: TKTokenSessionDelegate?
    /// the delegate; a session that implements TKTokenSessionDelegate is its own delegate unless another is set
    @objc open weak var delegate: TKTokenSessionDelegate? {
        get { _delegate ?? (self as? TKTokenSessionDelegate) }
        set { _delegate = newValue }
    }
    @objc(initWithToken:) public init(token: TKToken) { self.token = token; super.init() }
}

@objc(TKSmartCardTokenSession) open class TKSmartCardTokenSession: TKTokenSession {
    /// the token's card, in an exclusive session while the session works (isim begins it before each operation)
    @objc open var smartCard: TKSmartCard {
        guard let t = token as? TKSmartCardToken else { fatalError("TKSmartCardTokenSession needs a TKSmartCardToken") }
        return t.smartCard
    }
    @objc(getSmartCardWithError:) open func getSmartCard() throws -> TKSmartCard {
        guard let t = token as? TKSmartCardToken else { throw _tkError(.communicationError, "the token has no smart card") }
        guard t.smartCard.isValid else { throw _tkError(.communicationError, "the card was removed") }
        return t.smartCard
    }
}

// MARK: - registration (iOS 26)

/// smart card tokens the user allows to sign in to the device (isim keeps the list in the device data)
@available(iOS 26.0, *)
@objc(TKSmartCardTokenRegistrationManager) open class TKSmartCardTokenRegistrationManager: NSObject, @unchecked Sendable {
    @objc(defaultManager) public static let `default` = TKSmartCardTokenRegistrationManager()
    private override init() { super.init() }
    @objc open var registeredSmartCardTokens: [String] { _TKTokenConfigStore.registered() }
    @objc(registerSmartCardWithTokenID:promptMessage:error:) open func registerSmartCard(tokenID: String, promptMessage: String) throws {
        guard TKTokenWatcher.current()[tokenID] != nil else { throw _tkError(.tokenNotFound, "the token \(tokenID) is not inserted") }
        NSLog("isim CryptoTokenKit: registering %@ (%@)", tokenID, promptMessage)
        _TKTokenConfigStore.register(tokenID, true)
    }
    @objc(unregisterSmartCardWithTokenID:error:) open func unregisterSmartCard(tokenID: String) throws {
        guard registeredSmartCardTokens.contains(tokenID) else { throw _tkError(.tokenNotFound, "the token \(tokenID) is not registered") }
        _TKTokenConfigStore.register(tokenID, false)
    }
}
