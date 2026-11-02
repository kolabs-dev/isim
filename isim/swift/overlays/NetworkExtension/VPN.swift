// isim NetworkExtension (issue #424): NEVPNManager (the app's personal VPN, IKEv2 or IPsec), its protocols, on-demand
// rules and NEVPNConnection. The configuration is saved for the app after iOS's "Would Like to Add VPN Configurations"
// alert (once per app; ISIM_VPN_PERMISSION=allow|deny answers it). Adapted: starting the connection goes
// connecting -> connected without a tunnel (no traffic is routed), and stopping goes disconnecting -> disconnected;
// NEVPNStatusDidChange is posted for each state, as on iOS.
import UIKit

public let NEVPNErrorDomain = "NEVPNErrorDomain"
public let NEVPNConnectionErrorDomain = "NEVPNConnectionErrorDomain"
public let NEVPNConnectionStartOptionUsername = "username"
public let NEVPNConnectionStartOptionPassword = "password"

extension NSNotification.Name {
    /// posted with the NEVPNConnection whose status changed (isim's name string is proposed)
    public static let NEVPNStatusDidChange = NSNotification.Name("NEVPNStatusDidChangeNotification")
    /// posted when a VPN configuration of the app changes (isim's name string is proposed)
    public static let NEVPNConfigurationChange = NSNotification.Name("NEVPNConfigurationChangeNotification")
}

public struct NEVPNError: CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        case configurationInvalid = 1, configurationDisabled, connectionFailed, configurationStale, configurationReadWriteFailed, configurationUnknown
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { NEVPNErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [:] }
    public static var configurationInvalid: Code { .configurationInvalid }
    public static var configurationDisabled: Code { .configurationDisabled }
    public static var connectionFailed: Code { .connectionFailed }
    public static var configurationStale: Code { .configurationStale }
    public static var configurationReadWriteFailed: Code { .configurationReadWriteFailed }
    public static var configurationUnknown: Code { .configurationUnknown }
}

@objc public enum NEVPNConnectionError: Int, Error, Sendable {
    case overslept = 1, noNetworkAvailable, unrecoverableNetworkChange, configurationFailed, serverAddressResolutionFailed,
         serverNotResponding, serverDead, authenticationFailed, clientCertificateInvalid, clientCertificateNotYetValid,
         clientCertificateExpired, pluginFailed, configurationNotFound, pluginDisabled, negotiationFailed, serverDisconnected,
         serverCertificateInvalid, serverCertificateNotYetValid, serverCertificateExpired
}

@objc public enum NEVPNStatus: Int, Sendable {
    case invalid = 0, disconnected, connecting, connected, reasserting, disconnecting
}

// MARK: proxies

@objc(NEProxyServer) open class NEProxyServer: NSObject, NSCopying, @unchecked Sendable {
    @objc open private(set) var address: String
    @objc open private(set) var port: Int
    @objc open var authenticationRequired = false
    @objc open var username: String?
    @objc open var password: String?
    @objc(initWithAddress:port:) public init(address: String, port: Int) { self.address = address; self.port = port }
    public func copy(with zone: NSZone? = nil) -> Any {
        let c = NEProxyServer(address: address, port: port)
        c.authenticationRequired = authenticationRequired; c.username = username; c.password = password
        return c
    }
    var plist: [String: Any] { ["address": address, "port": port, "auth": authenticationRequired, "username": username ?? ""] }
    convenience init?(plist: [String: Any]?) {
        guard let p = plist, let a = p["address"] as? String else { return nil }
        self.init(address: a, port: p._ne("port", 0))
        authenticationRequired = p._ne("auth", false)
        username = (p["username"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}

@objc(NEProxySettings) open class NEProxySettings: NSObject, NSCopying, @unchecked Sendable {
    @objc open var autoProxyConfigurationEnabled = false
    @objc(proxyAutoConfigurationURL) open var proxyAutoConfigurationURL: URL?
    @objc open var proxyAutoConfigurationJavaScript: String?
    @objc(HTTPEnabled) open var httpEnabled = false
    @objc(HTTPServer) open var httpServer: NEProxyServer?
    @objc(HTTPSEnabled) open var httpsEnabled = false
    @objc(HTTPSServer) open var httpsServer: NEProxyServer?
    @objc open var excludeSimpleHostnames = false
    @objc open var exceptionList: [String]?
    @objc open var matchDomains: [String]?
    public override init() {}
    public func copy(with zone: NSZone? = nil) -> Any { NEProxySettings(plist: plist) }
    var plist: [String: Any] {
        var d: [String: Any] = ["auto": autoProxyConfigurationEnabled, "http": httpEnabled, "https": httpsEnabled, "simple": excludeSimpleHostnames]
        d["pacURL"] = proxyAutoConfigurationURL?.absoluteString; d["pacJS"] = proxyAutoConfigurationJavaScript
        d["httpServer"] = httpServer?.plist; d["httpsServer"] = httpsServer?.plist
        d["exceptions"] = exceptionList; d["matchDomains"] = matchDomains
        return d
    }
    convenience init(plist p: [String: Any]) {
        self.init()
        autoProxyConfigurationEnabled = p._ne("auto", false); httpEnabled = p._ne("http", false); httpsEnabled = p._ne("https", false)
        excludeSimpleHostnames = p._ne("simple", false)
        proxyAutoConfigurationURL = (p["pacURL"] as? String).flatMap(URL.init(string:)); proxyAutoConfigurationJavaScript = p["pacJS"] as? String
        httpServer = NEProxyServer(plist: p["httpServer"] as? [String: Any]); httpsServer = NEProxyServer(plist: p["httpsServer"] as? [String: Any])
        exceptionList = p["exceptions"] as? [String]; matchDomains = p["matchDomains"] as? [String]
    }
}

// MARK: protocols

@objc(NEVPNProtocol) open class NEVPNProtocol: NSObject, NSCopying, @unchecked Sendable {
    @objc open var serverAddress: String?
    @objc open var username: String?
    @objc open var passwordReference: Data?
    @objc open var identityReference: Data?
    @objc open var identityData: Data?
    @objc open var identityDataPassword: String?
    @objc open var disconnectOnSleep = false
    @objc open var proxySettings: NEProxySettings?
    @objc open var includeAllNetworks = false
    @objc open var excludeLocalNetworks = false
    @objc open var excludeCellularServices = true
    @objc open var excludeAPNs = true
    @objc open var excludeDeviceCommunication = true
    @objc open var enforceRoutes = false
    @objc open var sliceUUID: String?
    public override init() {}
    public func copy(with zone: NSZone? = nil) -> Any { NEVPNProtocol._make(plist) }

    /// the kind stored with the configuration
    var kind: String { "base" }
    var plist: [String: Any] {
        var d: [String: Any] = ["kind": kind, "disconnectOnSleep": disconnectOnSleep, "includeAllNetworks": includeAllNetworks,
                                "excludeLocalNetworks": excludeLocalNetworks, "excludeCellularServices": excludeCellularServices,
                                "excludeAPNs": excludeAPNs, "excludeDeviceCommunication": excludeDeviceCommunication, "enforceRoutes": enforceRoutes]
        d["serverAddress"] = serverAddress; d["username"] = username; d["passwordReference"] = passwordReference
        d["identityReference"] = identityReference; d["identityData"] = identityData; d["sliceUUID"] = sliceUUID
        d["proxy"] = proxySettings?.plist
        return d
    }
    func read(_ p: [String: Any]) {
        serverAddress = p["serverAddress"] as? String; username = p["username"] as? String
        passwordReference = p["passwordReference"] as? Data; identityReference = p["identityReference"] as? Data
        identityData = p["identityData"] as? Data; sliceUUID = p["sliceUUID"] as? String
        disconnectOnSleep = p._ne("disconnectOnSleep", false); includeAllNetworks = p._ne("includeAllNetworks", false)
        excludeLocalNetworks = p._ne("excludeLocalNetworks", false); excludeCellularServices = p._ne("excludeCellularServices", true)
        excludeAPNs = p._ne("excludeAPNs", true); excludeDeviceCommunication = p._ne("excludeDeviceCommunication", true)
        enforceRoutes = p._ne("enforceRoutes", false)
        proxySettings = (p["proxy"] as? [String: Any]).map(NEProxySettings.init(plist:))
    }
    static func _make(_ p: [String: Any]) -> NEVPNProtocol {
        let o: NEVPNProtocol
        switch p["kind"] as? String {
        case "ikev2": o = NEVPNProtocolIKEv2()
        case "ipsec": o = NEVPNProtocolIPSec()
        case "tunnel": o = NETunnelProviderProtocol()
        default: o = NEVPNProtocol()
        }
        o.read(p)
        return o
    }
    /// what iOS checks before saving
    var isValid: Bool { !(serverAddress ?? "").isEmpty }
}

@objc public enum NEVPNIKEAuthenticationMethod: Int, Sendable { case none = 0, certificate = 1, sharedSecret = 2 }

@objc(NEVPNProtocolIPSec) open class NEVPNProtocolIPSec: NEVPNProtocol, @unchecked Sendable {
    @objc open var authenticationMethod: NEVPNIKEAuthenticationMethod = .none
    @objc open var useExtendedAuthentication = false
    @objc open var sharedSecretReference: Data?
    @objc open var localIdentifier: String?
    @objc open var remoteIdentifier: String?
    override var kind: String { "ipsec" }
    override var plist: [String: Any] {
        var d = super.plist
        d["auth"] = authenticationMethod.rawValue; d["xauth"] = useExtendedAuthentication
        d["sharedSecretReference"] = sharedSecretReference; d["localIdentifier"] = localIdentifier; d["remoteIdentifier"] = remoteIdentifier
        return d
    }
    override func read(_ p: [String: Any]) {
        super.read(p)
        authenticationMethod = NEVPNIKEAuthenticationMethod(rawValue: p._ne("auth", 0)) ?? .none
        useExtendedAuthentication = p._ne("xauth", false)
        sharedSecretReference = p["sharedSecretReference"] as? Data
        localIdentifier = p["localIdentifier"] as? String; remoteIdentifier = p["remoteIdentifier"] as? String
    }
}

@objc public enum NEVPNIKEv2EncryptionAlgorithm: Int, Sendable {
    case algorithmAES128 = 3, algorithmAES256 = 4, algorithmAES128GCM = 5, algorithmAES256GCM = 6, algorithmChaCha20Poly1305 = 7
}
@objc public enum NEVPNIKEv2IntegrityAlgorithm: Int, Sendable { case SHA256 = 3, SHA384 = 4, SHA512 = 5 }
@objc public enum NEVPNIKEv2DeadPeerDetectionRate: Int, Sendable { case none = 0, low, medium, high }
@objc public enum NEVPNIKEv2DiffieHellmanGroup: Int, Sendable {
    case groupInvalid = 0, group14 = 14, group15, group16, group17, group18, group19, group20, group21, group31 = 31, group32
}
@objc public enum NEVPNIKEv2CertificateType: Int, Sendable { case RSA = 1, ECDSA256, ECDSA384, ECDSA521, ed25519, RSAPSS }
@objc public enum NEVPNIKEv2TLSVersion: Int, Sendable { case versionDefault = 0, version1_0, version1_1, version1_2, version1_3 }
@objc public enum NEVPNIKEv2PostQuantumKeyExchangeMethod: Int, Sendable { case methodNone = 0, method36 = 36, method37 = 37 }

@objc(NEVPNIKEv2SecurityAssociationParameters) open class NEVPNIKEv2SecurityAssociationParameters: NSObject, NSCopying, @unchecked Sendable {
    @objc open var encryptionAlgorithm: NEVPNIKEv2EncryptionAlgorithm = .algorithmAES256
    @objc open var integrityAlgorithm: NEVPNIKEv2IntegrityAlgorithm = .SHA256
    @objc open var diffieHellmanGroup: NEVPNIKEv2DiffieHellmanGroup = .group14
    @objc open var lifetimeMinutes: Int32 = 1440
    /// the post-quantum key exchanges, as NEVPNIKEv2PostQuantumKeyExchangeMethod raw values (Objective-C: NSNumbers)
    open var postQuantumKeyExchangeMethods: [NEVPNIKEv2PostQuantumKeyExchangeMethod] = []
    @objc(postQuantumKeyExchangeMethods) var _objcPQ: [NSNumber] {
        get { postQuantumKeyExchangeMethods.map { NSNumber(value: $0.rawValue) } }
        set { postQuantumKeyExchangeMethods = newValue.compactMap { NEVPNIKEv2PostQuantumKeyExchangeMethod(rawValue: Int($0.intValue)) } }
    }
    public override init() {}
    public func copy(with zone: NSZone? = nil) -> Any { let c = NEVPNIKEv2SecurityAssociationParameters(); c.read(plist); return c }
    var plist: [String: Any] {
        ["enc": encryptionAlgorithm.rawValue, "int": integrityAlgorithm.rawValue, "dh": diffieHellmanGroup.rawValue,
         "life": Int(lifetimeMinutes), "pq": postQuantumKeyExchangeMethods.map(\.rawValue)]
    }
    func read(_ p: [String: Any]?) {
        guard let p else { return }
        encryptionAlgorithm = NEVPNIKEv2EncryptionAlgorithm(rawValue: p._ne("enc", 4)) ?? .algorithmAES256
        integrityAlgorithm = NEVPNIKEv2IntegrityAlgorithm(rawValue: p._ne("int", 3)) ?? .SHA256
        diffieHellmanGroup = NEVPNIKEv2DiffieHellmanGroup(rawValue: p._ne("dh", 14)) ?? .group14
        lifetimeMinutes = Int32(p._ne("life", 1440))
        postQuantumKeyExchangeMethods = (p["pq"] as? [Int] ?? []).compactMap(NEVPNIKEv2PostQuantumKeyExchangeMethod.init(rawValue:))
    }
}

@objc(NEVPNIKEv2PPKConfiguration) open class NEVPNIKEv2PPKConfiguration: NSObject, NSCopying, @unchecked Sendable {
    @objc open private(set) var identifier: String
    @objc open private(set) var keychainReference: Data
    @objc open var isMandatory: Bool { @objc(isMandatory) get { _mandatory } @objc(setIsMandatory:) set { _mandatory = newValue } }
    var _mandatory = true
    @objc(initWithIdentifier:keychainReference:) public init(identifier: String, keychainReference: Data) {
        self.identifier = identifier; self.keychainReference = keychainReference
    }
    public func copy(with zone: NSZone? = nil) -> Any {
        let c = NEVPNIKEv2PPKConfiguration(identifier: identifier, keychainReference: keychainReference); c._mandatory = _mandatory; return c
    }
}

@objc(NEVPNProtocolIKEv2) open class NEVPNProtocolIKEv2: NEVPNProtocolIPSec, @unchecked Sendable {
    @objc open var deadPeerDetectionRate: NEVPNIKEv2DeadPeerDetectionRate = .medium
    @objc open var serverCertificateIssuerCommonName: String?
    @objc open var serverCertificateCommonName: String?
    @objc open var certificateType: NEVPNIKEv2CertificateType = .RSA
    @objc open var useConfigurationAttributeInternalIPSubnet = false
    @objc(IKESecurityAssociationParameters) open private(set) var ikeSecurityAssociationParameters = NEVPNIKEv2SecurityAssociationParameters()
    @objc open private(set) var childSecurityAssociationParameters = NEVPNIKEv2SecurityAssociationParameters()
    @objc open var disableMOBIKE = false
    @objc open var disableRedirect = false
    @objc open var enablePFS = false
    @objc open var allowPostQuantumKeyExchangeFallback = false
    @objc open var enableRevocationCheck = false
    @objc open var strictRevocationCheck = false
    @objc open var minimumTLSVersion: NEVPNIKEv2TLSVersion = .versionDefault
    @objc open var maximumTLSVersion: NEVPNIKEv2TLSVersion = .versionDefault
    @objc open var enableFallback = false
    @objc open var mtu: Int = 0
    @objc open var ppkConfiguration: NEVPNIKEv2PPKConfiguration?
    override var kind: String { "ikev2" }
    override var plist: [String: Any] {
        var d = super.plist
        d["dpd"] = deadPeerDetectionRate.rawValue; d["issuerCN"] = serverCertificateIssuerCommonName; d["serverCN"] = serverCertificateCommonName
        d["certType"] = certificateType.rawValue; d["internalSubnet"] = useConfigurationAttributeInternalIPSubnet
        d["ikeSA"] = ikeSecurityAssociationParameters.plist; d["childSA"] = childSecurityAssociationParameters.plist
        d["noMOBIKE"] = disableMOBIKE; d["noRedirect"] = disableRedirect; d["pfs"] = enablePFS; d["pqFallback"] = allowPostQuantumKeyExchangeFallback
        d["revocation"] = enableRevocationCheck; d["strictRevocation"] = strictRevocationCheck
        d["minTLS"] = minimumTLSVersion.rawValue; d["maxTLS"] = maximumTLSVersion.rawValue; d["fallback"] = enableFallback; d["mtu"] = mtu
        if let ppk = ppkConfiguration { d["ppk"] = ["id": ppk.identifier, "ref": ppk.keychainReference, "mandatory": ppk.isMandatory] }
        return d
    }
    override func read(_ p: [String: Any]) {
        super.read(p)
        deadPeerDetectionRate = NEVPNIKEv2DeadPeerDetectionRate(rawValue: p._ne("dpd", 2)) ?? .medium
        serverCertificateIssuerCommonName = p["issuerCN"] as? String; serverCertificateCommonName = p["serverCN"] as? String
        certificateType = NEVPNIKEv2CertificateType(rawValue: p._ne("certType", 1)) ?? .RSA
        useConfigurationAttributeInternalIPSubnet = p._ne("internalSubnet", false)
        ikeSecurityAssociationParameters.read(p["ikeSA"] as? [String: Any]); childSecurityAssociationParameters.read(p["childSA"] as? [String: Any])
        disableMOBIKE = p._ne("noMOBIKE", false); disableRedirect = p._ne("noRedirect", false); enablePFS = p._ne("pfs", false)
        allowPostQuantumKeyExchangeFallback = p._ne("pqFallback", false)
        enableRevocationCheck = p._ne("revocation", false); strictRevocationCheck = p._ne("strictRevocation", false)
        minimumTLSVersion = NEVPNIKEv2TLSVersion(rawValue: p._ne("minTLS", 0)) ?? .versionDefault
        maximumTLSVersion = NEVPNIKEv2TLSVersion(rawValue: p._ne("maxTLS", 0)) ?? .versionDefault
        enableFallback = p._ne("fallback", false); mtu = p._ne("mtu", 0)
        if let k = p["ppk"] as? [String: Any], let id = k["id"] as? String, let ref = k["ref"] as? Data {
            ppkConfiguration = NEVPNIKEv2PPKConfiguration(identifier: id, keychainReference: ref)
            ppkConfiguration?.isMandatory = k._ne("mandatory", true)
        }
    }
}

// MARK: on-demand rules

@objc public enum NEOnDemandRuleAction: Int, Sendable { case connect = 1, disconnect, evaluateConnection, ignore }
@objc public enum NEOnDemandRuleInterfaceType: Int, Sendable { case any = 0, ethernet, wiFi, cellular }
@objc public enum NEEvaluateConnectionRuleAction: Int, Sendable { case connectIfNeeded = 1, neverConnect }

@objc(NEEvaluateConnectionRule) open class NEEvaluateConnectionRule: NSObject, NSCopying, @unchecked Sendable {
    @objc open private(set) var action: NEEvaluateConnectionRuleAction
    @objc open private(set) var matchDomains: [String]
    @objc open var useDNSServers: [String]?
    @objc open var probeURL: URL?
    @objc(initWithMatchDomains:andAction:) public init(matchDomains domains: [String], andAction action: NEEvaluateConnectionRuleAction) {
        matchDomains = domains; self.action = action
    }
    public func copy(with zone: NSZone? = nil) -> Any {
        let c = NEEvaluateConnectionRule(matchDomains: matchDomains, andAction: action); c.useDNSServers = useDNSServers; c.probeURL = probeURL; return c
    }
}

@objc(NEOnDemandRule) open class NEOnDemandRule: NSObject, NSCopying, @unchecked Sendable {
    @objc open var action: NEOnDemandRuleAction { .ignore }
    @objc(DNSSearchDomainMatch) open var dnsSearchDomainMatch: [String]?
    @objc(DNSServerAddressMatch) open var dnsServerAddressMatch: [String]?
    @objc open var interfaceTypeMatch: NEOnDemandRuleInterfaceType = .any
    @objc(SSIDMatch) open var ssidMatch: [String]?
    @objc open var probeURL: URL?
    public override init() {}
    public func copy(with zone: NSZone? = nil) -> Any { NEOnDemandRule._make(plist) }
    var plist: [String: Any] {
        var d: [String: Any] = ["action": action.rawValue, "interface": interfaceTypeMatch.rawValue]
        d["dnsSearch"] = dnsSearchDomainMatch; d["dnsServers"] = dnsServerAddressMatch; d["ssids"] = ssidMatch; d["probe"] = probeURL?.absoluteString
        if let e = self as? NEOnDemandRuleEvaluateConnection, let rules = e.connectionRules {
            d["rules"] = rules.map { r -> [String: Any] in
                var x: [String: Any] = ["domains": r.matchDomains, "action": r.action.rawValue]
                x["dns"] = r.useDNSServers; x["probe"] = r.probeURL?.absoluteString
                return x
            }
        }
        return d
    }
    static func _make(_ p: [String: Any]) -> NEOnDemandRule {
        let r: NEOnDemandRule
        switch NEOnDemandRuleAction(rawValue: p._ne("action", 4)) ?? .ignore {
        case .connect: r = NEOnDemandRuleConnect()
        case .disconnect: r = NEOnDemandRuleDisconnect()
        case .evaluateConnection:
            let e = NEOnDemandRuleEvaluateConnection()
            e.connectionRules = (p["rules"] as? [[String: Any]])?.map { x in
                let c = NEEvaluateConnectionRule(matchDomains: x._ne("domains", []), andAction: NEEvaluateConnectionRuleAction(rawValue: x._ne("action", 1)) ?? .connectIfNeeded)
                c.useDNSServers = x["dns"] as? [String]; c.probeURL = (x["probe"] as? String).flatMap(URL.init(string:))
                return c
            }
            r = e
        case .ignore: r = NEOnDemandRuleIgnore()
        }
        r.interfaceTypeMatch = NEOnDemandRuleInterfaceType(rawValue: p._ne("interface", 0)) ?? .any
        r.dnsSearchDomainMatch = p["dnsSearch"] as? [String]; r.dnsServerAddressMatch = p["dnsServers"] as? [String]
        r.ssidMatch = p["ssids"] as? [String]; r.probeURL = (p["probe"] as? String).flatMap(URL.init(string:))
        return r
    }
}
@objc(NEOnDemandRuleConnect) open class NEOnDemandRuleConnect: NEOnDemandRule, @unchecked Sendable {
    @objc open override var action: NEOnDemandRuleAction { .connect }
}
@objc(NEOnDemandRuleDisconnect) open class NEOnDemandRuleDisconnect: NEOnDemandRule, @unchecked Sendable {
    @objc open override var action: NEOnDemandRuleAction { .disconnect }
}
@objc(NEOnDemandRuleIgnore) open class NEOnDemandRuleIgnore: NEOnDemandRule, @unchecked Sendable {
    @objc open override var action: NEOnDemandRuleAction { .ignore }
}
@objc(NEOnDemandRuleEvaluateConnection) open class NEOnDemandRuleEvaluateConnection: NEOnDemandRule, @unchecked Sendable {
    @objc open override var action: NEOnDemandRuleAction { .evaluateConnection }
    @objc open var connectionRules: [NEEvaluateConnectionRule]?
}

// MARK: the manager and its connection

@objc(NEVPNConnection) open class NEVPNConnection: NSObject, @unchecked Sendable {
    @objc open internal(set) var status: NEVPNStatus = .invalid
    @objc open internal(set) var connectedDate: Date?
    @objc open var manager: NEVPNManager { _manager! }
    weak var _manager: NEVPNManager?
    var lastError: Error?
    var generation = 0

    func set(_ s: NEVPNStatus) {
        guard s != status else { return }
        status = s
        connectedDate = s == .connected ? Date() : s == .disconnected || s == .invalid ? nil : connectedDate
        NSLog("isim NetworkExtension: %@ status %@", _manager?.localizedDescription ?? "VPN", ["invalid", "disconnected", "connecting", "connected", "reasserting", "disconnecting"][s.rawValue])
        _Privacy.onMain { NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: self) }
    }

    @objc(startVPNTunnelAndReturnError:) open func startVPNTunnel() throws { try startVPNTunnel(options: nil) }
    @objc(startVPNTunnelWithOptions:andReturnError:) open func startVPNTunnel(options: [String: NSObject]? = nil) throws {
        guard let m = _manager, m.saved else { throw NEVPNError(.configurationInvalid) }
        guard m.isEnabled else { throw NEVPNError(.configurationDisabled) }
        guard status == .disconnected || status == .invalid else { return }
        lastError = nil
        start(m)
    }
    /// simulated: connecting, then connected after a moment (no tunnel)
    func start(_ m: NEVPNManager) {
        generation += 1
        let g = generation
        set(.connecting)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            guard g == generation, status == .connecting else { return }
            NSLog("isim NetworkExtension: %@ connected to %@ (simulated: no tunnel)", m.localizedDescription ?? "VPN",
                  m.protocolConfiguration?.serverAddress ?? (m.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier ?? "-")
            set(.connected)
        }
    }
    @objc open func stopVPNTunnel() {
        guard status == .connecting || status == .connected || status == .reasserting else { return }
        generation += 1
        let g = generation
        set(.disconnecting)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in if g == generation { set(.disconnected) } }
    }
    @objc(fetchLastDisconnectErrorWithCompletionHandler:)
    open func fetchLastDisconnectError(completionHandler: @escaping @Sendable (Error?) -> Void) {
        let e = lastError
        DispatchQueue.main.async { completionHandler(e) }
    }
}

@objc(NEVPNManager) open class NEVPNManager: NSObject, @unchecked Sendable {
    static let _shared = NEVPNManager(kind: "vpn", identifier: "personal")
    @objc(sharedManager) open class func shared() -> NEVPNManager { _shared }

    let storeKind: String
    var identifier: String
    var saved = false
    @objc open var onDemandRules: [NEOnDemandRule]?
    @objc open var isOnDemandEnabled: Bool { @objc(isOnDemandEnabled) get { _onDemand } @objc(setOnDemandEnabled:) set { _onDemand = newValue } }
    var _onDemand = false
    @objc open var localizedDescription: String?
    @objc(protocol) open var `protocol`: NEVPNProtocol? { get { protocolConfiguration } set { protocolConfiguration = newValue } }
    @objc open var protocolConfiguration: NEVPNProtocol?
    @objc open internal(set) var connection: NEVPNConnection
    @objc open var isEnabled: Bool { @objc(isEnabled) get { _enabled } @objc(setEnabled:) set { _enabled = newValue } }
    var _enabled = false

    init(kind: String, identifier: String) {
        storeKind = kind; self.identifier = identifier
        connection = NEVPNConnection()
        super.init()
        connection._manager = self
    }

    var plist: [String: Any] {
        var d: [String: Any] = ["enabled": _enabled, "onDemand": _onDemand]
        d["name"] = localizedDescription; d["protocol"] = protocolConfiguration?.plist
        d["rules"] = onDemandRules?.map(\.plist)
        return d
    }
    func read(_ p: [String: Any]) {
        _enabled = p._ne("enabled", false); _onDemand = p._ne("onDemand", false)
        localizedDescription = p["name"] as? String
        protocolConfiguration = (p["protocol"] as? [String: Any]).map(NEVPNProtocol._make)
        onDemandRules = (p["rules"] as? [[String: Any]])?.map(NEOnDemandRule._make)
        saved = true
        if connection.status == .invalid { connection.set(.disconnected) }
    }

    @objc(loadFromPreferencesWithCompletionHandler:)
    open func loadFromPreferences(completionHandler: @escaping @Sendable (Error?) -> Void) {
        if let p = _NE.load(storeKind).first(where: { $0["identifier"] as? String == identifier }) { read(p) }
        DispatchQueue.main.async { completionHandler(nil) }
    }
    @objc(saveToPreferencesWithCompletionHandler:)
    open func saveToPreferences(completionHandler: (@Sendable (Error?) -> Void)? = nil) {
        let done: @Sendable (Error?) -> Void = { e in DispatchQueue.main.async { completionHandler?(e) } }
        guard let proto = protocolConfiguration, proto.isValid else {
            NSLog("isim NetworkExtension: %@ configuration is invalid (no protocol or server)", localizedDescription ?? "VPN")
            done(NEVPNError(.configurationInvalid)); return
        }
        let app = _Privacy.appName
        _Privacy.onMain { [self] in
            _NE.permission("NetworkExtension.vpn", title: "“\(app)” Would Like to Add VPN Configurations",
                           message: "All network activity on this iPhone may be filtered or monitored when using VPN.") { [self] ok in
                guard ok else { done(NEVPNError(.configurationReadWriteFailed)); return }
                _NE.upsert(storeKind, identifier, plist)
                saved = true
                if connection.status == .invalid { connection.set(.disconnected) }
                NSLog("isim NetworkExtension: saved VPN configuration “%@” (%@)", localizedDescription ?? "-", proto.kind)
                NotificationCenter.default.post(name: .NEVPNConfigurationChange, object: self)
                done(nil)
            }
        }
    }
    @objc(removeFromPreferencesWithCompletionHandler:)
    open func removeFromPreferences(completionHandler: (@Sendable (Error?) -> Void)? = nil) {
        let removed = _NE.remove(storeKind, identifier)
        connection.stopVPNTunnel()
        saved = false
        connection.set(.invalid)
        NSLog("isim NetworkExtension: removed VPN configuration “%@”", localizedDescription ?? "-")
        _Privacy.onMain { NotificationCenter.default.post(name: .NEVPNConfigurationChange, object: self) }
        DispatchQueue.main.async { completionHandler?(removed ? nil : NEVPNError(.configurationInvalid)) }
    }
}
