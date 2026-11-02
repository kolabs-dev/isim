// isim NetworkExtension (issue #424): NEHotspotConfigurationManager. `apply` checks the configuration as iOS does
// (SSID and passphrase rules), asks the person with iOS's alert to join the network and remembers it in the app's
// configured SSIDs; nothing joins a real network (isim's device has its simulated Wi-Fi). ISIM_HOTSPOT_PERMISSION=allow|deny
// answers the alert. Apps need the com.apple.developer.networking.HotspotConfiguration entitlement (else
// NEHotspotConfigurationError.systemConfiguration, as iOS answers).
import UIKit
import Security

public let NEHotspotConfigurationErrorDomain = "NEHotspotConfigurationErrorDomain"

@objc public enum NEHotspotConfigurationError: Int, Error, Sendable {
    case invalid = 0, invalidSSID, invalidWPAPassphrase, invalidWEPPassphrase, invalidEAPSettings, invalidHS20Settings,
         invalidHS20DomainName, userDenied, `internal`, pending, systemConfiguration, unknown, joinOnceNotSupported,
         alreadyAssociated, applicationIsNotInForeground, invalidSSIDPrefix, userUnauthorized, systemDenied
}
extension NEHotspotConfigurationError: CustomNSError {
    public static var errorDomain: String { NEHotspotConfigurationErrorDomain }
    public var errorCode: Int { rawValue }
}

@objc(NEHotspotHS20Settings) open class NEHotspotHS20Settings: NSObject, NSCopying, @unchecked Sendable {
    @objc open private(set) var domainName: String
    @objc open var isRoamingEnabled: Bool {
        @objc(isRoamingEnabled) get { _roaming } @objc(setRoamingEnabled:) set { _roaming = newValue }
    }
    var _roaming: Bool
    @objc open var roamingConsortiumOIs: [String] = []
    @objc open var naiRealmNames: [String] = []
    @objc(MCCAndMNCs) open var mccAndMNCs: [String] = []
    @objc(initWithDomainName:roamingEnabled:) public init(domainName: String, roamingEnabled: Bool) {
        self.domainName = domainName; _roaming = roamingEnabled
    }
    public func copy(with zone: NSZone? = nil) -> Any {
        let c = NEHotspotHS20Settings(domainName: domainName, roamingEnabled: _roaming)
        c.roamingConsortiumOIs = roamingConsortiumOIs; c.naiRealmNames = naiRealmNames; c.mccAndMNCs = mccAndMNCs
        return c
    }
}

@objc(NEHotspotEAPSettings) open class NEHotspotEAPSettings: NSObject, NSCopying, @unchecked Sendable {
    @objc(NEHotspotConfigurationEAPType) public enum EAPType: Int, Sendable {
        case EAPTLS = 13, EAPTTLS = 21, EAPPEAP = 25, EAPFAST = 43
    }
    @objc(NEHotspotConfigurationTTLSInnerAuthenticationType) public enum TTLSInnerAuthenticationType: Int, Sendable {
        case eapttlsInnerAuthenticationPAP = 0, eapttlsInnerAuthenticationCHAP, eapttlsInnerAuthenticationMSCHAP,
             eapttlsInnerAuthenticationMSCHAPv2, eapttlsInnerAuthenticationEAP
    }
    @objc(NEHotspotConfigurationEAPTLSVersion) public enum TLSVersion: Int, Sendable {
        case _1_0 = 0, _1_1 = 1, _1_2 = 2
    }
    @objc open var supportedEAPTypes: [NSNumber] = []
    @objc open var username = ""
    @objc open var outerIdentity = ""
    @objc open var ttlsInnerAuthenticationType: TTLSInnerAuthenticationType = .eapttlsInnerAuthenticationMSCHAPv2
    @objc open var password = ""
    @objc open var trustedServerNames: [String] = []
    @objc open var isTLSClientCertificateRequired: Bool {
        @objc(isTLSClientCertificateRequired) get { _clientCert } @objc(setTlsClientCertificateRequired:) set { _clientCert = newValue }
    }
    var _clientCert = false
    @objc open var preferredTLSVersion: TLSVersion = ._1_2
    var identity: SecIdentity?
    var trustedCertificates: [Any] = []
    public override init() {}
    /// the client identity for EAP-TLS (from the app's keychain)
    open func setIdentity(_ identity: SecIdentity) -> Bool { self.identity = identity; return true }
    /// Objective-C passes a SecIdentityRef (isim's SecIdentity object)
    @objc(setIdentity:) func _objcSetIdentity(_ identity: UnsafeRawPointer) -> Bool {
        setIdentity(Unmanaged<SecIdentity>.fromOpaque(identity).takeUnretainedValue())
    }
    @objc(setTrustedServerCertificates:) open func setTrustedServerCertificates(_ certificates: [Any]) -> Bool {
        trustedCertificates = certificates; return true
    }
    public func copy(with zone: NSZone? = nil) -> Any {
        let c = NEHotspotEAPSettings()
        c.supportedEAPTypes = supportedEAPTypes; c.username = username; c.outerIdentity = outerIdentity
        c.ttlsInnerAuthenticationType = ttlsInnerAuthenticationType; c.password = password
        c.trustedServerNames = trustedServerNames; c._clientCert = _clientCert; c.preferredTLSVersion = preferredTLSVersion
        c.identity = identity; c.trustedCertificates = trustedCertificates
        return c
    }
    /// iOS's checks: at least one EAP type, credentials for the types that need them
    var isValid: Bool {
        guard !supportedEAPTypes.isEmpty, supportedEAPTypes.allSatisfy({ EAPType(rawValue: Int($0.intValue)) != nil }) else { return false }
        let needsPassword = supportedEAPTypes.contains { Int($0.intValue) != EAPType.EAPTLS.rawValue }
        return !needsPassword || (!username.isEmpty && !password.isEmpty) || identity != nil
    }
}

@objc(NEHotspotConfiguration) open class NEHotspotConfiguration: NSObject, NSCopying, @unchecked Sendable {
    @objc(SSID) open private(set) var ssid: String = ""
    @objc(SSIDPrefix) open private(set) var ssidPrefix: String = ""
    @objc open var joinOnce = false
    @objc open var lifeTimeInDays: NSNumber = 0
    @objc open var hidden = false
    var passphrase: String?
    var isWEP = false
    var eap: NEHotspotEAPSettings?
    var hs20: NEHotspotHS20Settings?

    @objc(initWithSSID:) public init(ssid: String) { self.ssid = ssid }
    @objc(initWithSSID:passphrase:isWEP:) public init(ssid: String, passphrase: String, isWEP: Bool) {
        self.ssid = ssid; self.passphrase = passphrase; self.isWEP = isWEP
    }
    @objc(initWithSSID:eapSettings:) public init(ssid: String, eapSettings: NEHotspotEAPSettings) {
        self.ssid = ssid; eap = eapSettings.copy() as? NEHotspotEAPSettings
    }
    @objc(initWithHS20Settings:eapSettings:) public init(hs20Settings: NEHotspotHS20Settings, eapSettings: NEHotspotEAPSettings) {
        hs20 = hs20Settings.copy() as? NEHotspotHS20Settings; eap = eapSettings.copy() as? NEHotspotEAPSettings
    }
    @objc(initWithSSIDPrefix:) public init(ssidPrefix: String) { self.ssidPrefix = ssidPrefix }
    @objc(initWithSSIDPrefix:passphrase:isWEP:) public init(ssidPrefix: String, passphrase: String, isWEP: Bool) {
        self.ssidPrefix = ssidPrefix; self.passphrase = passphrase; self.isWEP = isWEP
    }
    // the names Swift imports Apple's SDK under, too (SSID: / SSIDPrefix: / HS20Settings:)
    public convenience init(SSID: String) { self.init(ssid: SSID) }
    public convenience init(SSID: String, passphrase: String, isWEP: Bool) { self.init(ssid: SSID, passphrase: passphrase, isWEP: isWEP) }
    public convenience init(SSID: String, eapSettings: NEHotspotEAPSettings) { self.init(ssid: SSID, eapSettings: eapSettings) }
    public convenience init(HS20Settings: NEHotspotHS20Settings, eapSettings: NEHotspotEAPSettings) { self.init(hs20Settings: HS20Settings, eapSettings: eapSettings) }
    public convenience init(SSIDPrefix: String) { self.init(ssidPrefix: SSIDPrefix) }
    public convenience init(SSIDPrefix: String, passphrase: String, isWEP: Bool) { self.init(ssidPrefix: SSIDPrefix, passphrase: passphrase, isWEP: isWEP) }

    public func copy(with zone: NSZone? = nil) -> Any {
        let c = NEHotspotConfiguration(ssid: ssid)
        c.ssidPrefix = ssidPrefix; c.joinOnce = joinOnce; c.lifeTimeInDays = lifeTimeInDays; c.hidden = hidden
        c.passphrase = passphrase; c.isWEP = isWEP; c.eap = eap; c.hs20 = hs20
        return c
    }

    /// the network's name as iOS shows it in the alert
    var displayName: String { hs20?.domainName ?? (ssid.isEmpty ? ssidPrefix : ssid) }

    /// iOS's validation (NEHotspotConfigurationManager.apply)
    func validate() -> NEHotspotConfigurationError? {
        if let hs20 {
            if hs20.domainName.isEmpty { return .invalidHS20DomainName }
            if hs20.roamingConsortiumOIs.isEmpty && hs20.naiRealmNames.isEmpty && hs20.mccAndMNCs.isEmpty && hs20.domainName.count < 3 { return .invalidHS20Settings }
            if let eap, !eap.isValid { return .invalidEAPSettings }
            return nil
        }
        if ssid.isEmpty && ssidPrefix.isEmpty { return .invalidSSID }
        if !ssid.isEmpty && ssid.utf8.count > 32 { return .invalidSSID }
        if ssid.isEmpty && (ssidPrefix.utf8.count < 3 || ssidPrefix.utf8.count > 32) { return .invalidSSIDPrefix }
        if let p = passphrase {
            if isWEP {
                let hex = p.allSatisfy(\.isHexDigit)
                if !([5, 13].contains(p.utf8.count) || (hex && [10, 26].contains(p.utf8.count))) { return .invalidWEPPassphrase }
            } else if p.utf8.count < 8 || p.utf8.count > 64 || (p.utf8.count == 64 && !p.allSatisfy(\.isHexDigit)) {
                return .invalidWPAPassphrase
            }
        }
        if let eap, !eap.isValid { return .invalidEAPSettings }
        return nil
    }
}

@objc(NEHotspotConfigurationManager) open class NEHotspotConfigurationManager: NSObject, @unchecked Sendable {
    static let _shared = NEHotspotConfigurationManager()
    @objc(sharedManager) open class var shared: NEHotspotConfigurationManager { _shared }

    static var entitled: Bool {
        let xcent = (Bundle.main.bundlePath as NSString).appendingPathComponent("archived-expanded-entitlements.xcent")
        return ((NSDictionary(contentsOfFile: xcent) as? [String: Any])?["com.apple.developer.networking.HotspotConfiguration"] as? Bool) == true
    }

    /// joins the network (simulated) after the person agrees, and remembers it for the app
    @objc(applyConfiguration:completionHandler:)
    open func apply(_ configuration: NEHotspotConfiguration, completionHandler: (@Sendable (Error?) -> Void)? = nil) {
        let finish: @Sendable (NEHotspotConfigurationError?) -> Void = { e in
            DispatchQueue.main.async { completionHandler?(e.map { NSError(domain: NEHotspotConfigurationErrorDomain, code: $0.rawValue) }) }
        }
        guard NEHotspotConfigurationManager.entitled else {
            NSLog("isim NetworkExtension: the app does not have the com.apple.developer.networking.HotspotConfiguration entitlement")
            finish(.systemConfiguration); return
        }
        if let e = configuration.validate() { NSLog("isim NetworkExtension: hotspot configuration invalid (%ld)", e.rawValue); finish(e); return }
        let c = configuration.copy() as! NEHotspotConfiguration
        let name = c.displayName
        if !c.ssid.isEmpty && c.ssid == _NE.wifiSSID { finish(.alreadyAssociated); return }
        let join: @Sendable (Bool) -> Void = { ok in
            guard ok else { NSLog("isim NetworkExtension: joining “%@” declined", name); finish(.userDenied); return }
            if !c.joinOnce {
                var item: [String: Any] = ["ssid": c.ssid, "ssidPrefix": c.ssidPrefix, "hidden": c.hidden, "lifeTimeInDays": c.lifeTimeInDays.intValue,
                                           "security": c.eap != nil ? "EAP" : c.passphrase == nil ? "open" : c.isWEP ? "WEP" : "WPA"]
                if let d = c.hs20?.domainName { item["hs20DomainName"] = d }
                _NE.upsert("hotspots", c.hs20?.domainName ?? (c.ssid.isEmpty ? "prefix:" + c.ssidPrefix : c.ssid), item)
            }
            NSLog("isim NetworkExtension: joined Wi-Fi network “%@”%@ (simulated)", name, c.joinOnce ? " once" : "")
            finish(nil)
        }
        if let s = _Privacy.scripted("HOTSPOT") { join(s == "allow" || s == "1" || s == "yes"); return }
        let app = _Privacy.appName
        _Privacy.onMain {
            _Privacy.alert("“\(app)” Wants to Join Wi-Fi Network “\(name)”", nil, [("Cancel", .cancel), ("Join", .default)]) { i in join(i == 1) }
        }
    }

    /// the SSIDs of the networks this app configured (not those it joined once)
    @objc(getConfiguredSSIDsWithCompletionHandler:)
    open func getConfiguredSSIDs(completionHandler: @escaping @Sendable ([String]) -> Void) {
        let ssids = _NE.load("hotspots").compactMap { $0["ssid"] as? String }.filter { !$0.isEmpty }
        DispatchQueue.main.async { completionHandler(ssids) }
    }
    @objc(removeConfigurationForSSID:) open func removeConfiguration(forSSID SSID: String) {
        if _NE.remove("hotspots", SSID) { NSLog("isim NetworkExtension: removed Wi-Fi configuration “%@”", SSID) }
    }
    @objc(removeConfigurationForHS20DomainName:) open func removeConfiguration(forHS20DomainName domainName: String) {
        if _NE.remove("hotspots", domainName) { NSLog("isim NetworkExtension: removed Hotspot 2.0 configuration “%@”", domainName) }
    }
}
