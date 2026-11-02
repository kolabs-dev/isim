// isim NetworkExtension (issue #424): NETunnelProviderManager (an app's packet tunnel provider configurations, any number
// per app, also per-app VPN), NETunnelProviderProtocol and NETunnelProviderSession. Adapted: the provider extension is not
// launched (a packet tunnel needs a host TUN device and privileges, issue #424): starting a session goes connecting ->
// connected like NEVPNConnection, and provider messages get no response.
import UIKit

@objc public enum NETunnelProviderRoutingMethod: Int, Sendable { case destinationIP = 1, sourceApplication = 2, networkRule = 3 }

@objc(NETunnelProviderProtocol) open class NETunnelProviderProtocol: NEVPNProtocol, @unchecked Sendable {
    /// the provider's own settings (property-list values)
    open var providerConfiguration: [String: Any]?
    @objc(providerConfiguration) var _objcProviderConfiguration: [String: Any]? {
        get { providerConfiguration } set { providerConfiguration = newValue }
    }
    @objc open var providerBundleIdentifier: String?
    override var kind: String { "tunnel" }
    override var plist: [String: Any] {
        var d = super.plist
        d["providerConfiguration"] = providerConfiguration.flatMap { PropertyListSerialization.propertyList($0, isValidFor: .binary) ? $0 : nil }
        d["providerBundleIdentifier"] = providerBundleIdentifier
        return d
    }
    override func read(_ p: [String: Any]) {
        super.read(p)
        providerConfiguration = p["providerConfiguration"] as? [String: Any]
        providerBundleIdentifier = p["providerBundleIdentifier"] as? String
    }
    /// iOS asks for the provider (the extension bundle identifier); the server address is free text
    override var isValid: Bool { !(providerBundleIdentifier ?? "").isEmpty }
}

@objc(NEAppRule) open class NEAppRule: NSObject, NSCopying, @unchecked Sendable {
    @objc open private(set) var matchSigningIdentifier: String
    @objc open private(set) var matchDesignatedRequirement: String = ""
    @objc open var matchPath: String?
    @objc open var matchDomains: [Any]?
    @objc open var matchTools: [NEAppRule]?
    @objc(initWithSigningIdentifier:) public init(signingIdentifier: String) { matchSigningIdentifier = signingIdentifier }
    @objc(initWithSigningIdentifier:designatedRequirement:) public init(signingIdentifier: String, designatedRequirement: String) {
        matchSigningIdentifier = signingIdentifier; matchDesignatedRequirement = designatedRequirement
    }
    public func copy(with zone: NSZone? = nil) -> Any {
        let c = NEAppRule(signingIdentifier: matchSigningIdentifier, designatedRequirement: matchDesignatedRequirement)
        c.matchPath = matchPath; c.matchDomains = matchDomains; c.matchTools = matchTools; return c
    }
}

@objc(NETunnelProviderSession) open class NETunnelProviderSession: NEVPNConnection, @unchecked Sendable {
    @objc(startTunnelWithOptions:andReturnError:) open func startTunnel(options: [String: Any]? = nil) throws {
        guard let m = _manager, m.saved else { throw NEVPNError(.configurationInvalid) }
        guard m.isEnabled else { throw NEVPNError(.configurationDisabled) }
        guard status == .disconnected || status == .invalid else { return }
        NSLog("isim NetworkExtension: the provider %@ is not launched (simulated tunnel)",
              (m.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier ?? "-")
        start(m)
    }
    @objc open func stopTunnel() { stopVPNTunnel() }
    @objc(sendProviderMessage:returnError:responseHandler:)
    open func sendProviderMessage(_ messageData: Data, responseHandler: (@Sendable (Data?) -> Void)? = nil) throws {
        guard status == .connected else { throw NEVPNError(.configurationInvalid) }
        NSLog("isim NetworkExtension: provider message (%ld bytes) not delivered: the provider is not running", messageData.count)
        DispatchQueue.main.async { responseHandler?(nil) }
    }
}

@objc(NETunnelProviderManager) open class NETunnelProviderManager: NEVPNManager, @unchecked Sendable {
    @objc open var routingMethod: NETunnelProviderRoutingMethod { perApp ? .sourceApplication : .destinationIP }
    var perApp = false
    @objc open var safariDomains: [String] = []
    @objc open var mailDomains: [String] = []
    @objc open var calendarDomains: [String] = []
    @objc open var contactsDomains: [String] = []
    @objc open var associatedDomains: [String] = []
    @objc open var excludedDomains: [String] = []
    @objc open var appRules: [NEAppRule] = []

    public required init() {
        super.init(kind: "tunnel", identifier: UUID().uuidString)
        connection = NETunnelProviderSession()
        connection._manager = self
    }
    @objc open class func forPerAppVPN() -> Self { let m = self.init(); m.perApp = true; return m }
    @objc open func copyAppRules() -> [NEAppRule]? { perApp ? appRules.map { $0.copy() as! NEAppRule } : nil }

    override var plist: [String: Any] {
        var d = super.plist
        d["perApp"] = perApp
        d["domains"] = ["safari": safariDomains, "mail": mailDomains, "calendar": calendarDomains, "contacts": contactsDomains,
                        "associated": associatedDomains, "excluded": excludedDomains]
        d["appRules"] = appRules.map(\.matchSigningIdentifier)
        return d
    }
    override func read(_ p: [String: Any]) {
        super.read(p)
        perApp = p._ne("perApp", false)
        let dom = p["domains"] as? [String: [String]] ?? [:]
        safariDomains = dom["safari"] ?? []; mailDomains = dom["mail"] ?? []; calendarDomains = dom["calendar"] ?? []
        contactsDomains = dom["contacts"] ?? []; associatedDomains = dom["associated"] ?? []; excludedDomains = dom["excluded"] ?? []
        appRules = (p["appRules"] as? [String] ?? []).map(NEAppRule.init(signingIdentifier:))
    }

    /// the app's tunnel configurations, as saved
    @objc(loadAllFromPreferencesWithCompletionHandler:)
    open class func loadAllFromPreferences(completionHandler: @escaping @Sendable ([NETunnelProviderManager]?, Error?) -> Void) {
        let managers = _NE.load("tunnel").map { p -> NETunnelProviderManager in
            let m = NETunnelProviderManager()
            m.identifier = p._ne("identifier", m.identifier)
            m.read(p)
            return m
        }
        DispatchQueue.main.async { completionHandler(managers, nil) }
    }
}
