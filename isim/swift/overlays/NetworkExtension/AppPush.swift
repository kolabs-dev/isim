// isim NetworkExtension (issue #424): NEAppPushManager, the configuration of a local push connectivity provider (iOS 14).
// Saved and loaded per app; `isActive` is true while the enabled configuration matches the device's simulated Wi-Fi
// network (ISIM_WIFI_SSID, default "isim"). Adapted: the provider extension is not launched, so no incoming call reaches
// the delegate.
import UIKit

public let NEAppPushErrorDomain = "NEAppPushErrorDomain"

public struct NEAppPushManagerError: CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable { case configurationInvalid = 1, configurationNotLoaded = 2, internalError = 3, inactiveSession = 4 }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { NEAppPushErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [:] }
    public static var configurationInvalid: Code { .configurationInvalid }
    public static var configurationNotLoaded: Code { .configurationNotLoaded }
    public static var internalError: Code { .internalError }
    public static var inactiveSession: Code { .inactiveSession }
}

@objc(NEPrivateLTENetwork) open class NEPrivateLTENetwork: NSObject, NSCopying, @unchecked Sendable {
    @objc open var mobileCountryCode: String
    @objc open var mobileNetworkCode: String
    @objc open var trackingAreaCode: String?
    @objc(initWithMobileCountryCode:mobileNetworkCode:trackingAreaCode:)
    public init(mobileCountryCode: String, mobileNetworkCode: String, trackingAreaCode: String?) {
        self.mobileCountryCode = mobileCountryCode; self.mobileNetworkCode = mobileNetworkCode; self.trackingAreaCode = trackingAreaCode
    }
    public override convenience init() { self.init(mobileCountryCode: "", mobileNetworkCode: "", trackingAreaCode: nil) }
    public func copy(with zone: NSZone? = nil) -> Any {
        NEPrivateLTENetwork(mobileCountryCode: mobileCountryCode, mobileNetworkCode: mobileNetworkCode, trackingAreaCode: trackingAreaCode)
    }
}

@objc(NEAppPushDelegate) public protocol NEAppPushDelegate: NSObjectProtocol {
    @objc(appPushManager:didReceiveIncomingCallWithUserInfo:)
    func appPushManager(_ manager: NEAppPushManager, didReceiveIncomingCallWithUserInfo userInfo: [AnyHashable: Any] )
}

@available(iOS 14.0, *)
@objc(NEAppPushManager) open class NEAppPushManager: NSObject, @unchecked Sendable {
    @objc open var matchSSIDs: [String] = []
    @objc open var matchPrivateLTENetworks: [NEPrivateLTENetwork] = []
    @objc open var matchEthernet = false
    @available(iOS 27.0, *)
    @objc open var matchMissionCriticalService: Bool { get { _missionCritical } set { _missionCritical = newValue } }
    var _missionCritical = false
    open var providerConfiguration: [String: Any] = [:]
    @objc(providerConfiguration) var _objcProviderConfiguration: [String: Any] {
        get { providerConfiguration } set { providerConfiguration = newValue }
    }
    @objc open var providerBundleIdentifier: String?
    @objc open weak var delegate: NEAppPushDelegate?
    @objc open var localizedDescription: String?
    @objc open var isEnabled: Bool { @objc(isEnabled) get { _enabled } @objc(setEnabled:) set { _enabled = newValue } }
    var _enabled = false
    var identifier = UUID().uuidString
    var loaded = false
    /// active while enabled, saved and on a matching network (dynamic: KVO-observable, as on iOS)
    @objc open dynamic private(set) var isActive: Bool {
        @objc(isActive) get { _active }
        set { _active = newValue }
    }
    var _active = false

    public override init() {}

    var plist: [String: Any] {
        var d: [String: Any] = ["enabled": _enabled, "ssids": matchSSIDs, "ethernet": matchEthernet, "missionCritical": _missionCritical,
                                "lte": matchPrivateLTENetworks.map { ["mcc": $0.mobileCountryCode, "mnc": $0.mobileNetworkCode, "tac": $0.trackingAreaCode ?? ""] }]
        d["name"] = localizedDescription; d["provider"] = providerBundleIdentifier
        if PropertyListSerialization.propertyList(providerConfiguration, isValidFor: .binary) { d["providerConfiguration"] = providerConfiguration }
        return d
    }
    func read(_ p: [String: Any]) {
        identifier = p._ne("identifier", identifier)
        _enabled = p._ne("enabled", false); matchSSIDs = p._ne("ssids", []); matchEthernet = p._ne("ethernet", false)
        _missionCritical = p._ne("missionCritical", false)
        matchPrivateLTENetworks = (p["lte"] as? [[String: String]] ?? []).map {
            NEPrivateLTENetwork(mobileCountryCode: $0["mcc"] ?? "", mobileNetworkCode: $0["mnc"] ?? "", trackingAreaCode: ($0["tac"] ?? "").isEmpty ? nil : $0["tac"])
        }
        localizedDescription = p["name"] as? String; providerBundleIdentifier = p["provider"] as? String
        providerConfiguration = p["providerConfiguration"] as? [String: Any] ?? [:]
        loaded = true
        updateActive()
    }
    func updateActive() {
        let on = loaded && _enabled && matchSSIDs.contains(_NE.wifiSSID)
        if on != _active {
            willChangeValue(forKey: "isActive"); _active = on; didChangeValue(forKey: "isActive")
            NSLog("isim NetworkExtension: app push provider %@ %@ (Wi-Fi “%@”; the provider is not launched)",
                  providerBundleIdentifier ?? "-", on ? "active" : "inactive", _NE.wifiSSID)
        }
    }

    @objc(loadAllFromPreferencesWithCompletionHandler:)
    open class func loadAllFromPreferences(completionHandler: @escaping @Sendable ([NEAppPushManager]?, Error?) -> Void) {
        let all = _NE.load("apppush").map { p -> NEAppPushManager in let m = NEAppPushManager(); m.read(p); return m }
        DispatchQueue.main.async { completionHandler(all, nil) }
    }
    @objc(loadFromPreferencesWithCompletionHandler:)
    open func loadFromPreferences(completionHandler: @escaping @Sendable (Error?) -> Void) {
        let p = _NE.load("apppush").first { $0["identifier"] as? String == identifier }
        if let p { read(p) }
        DispatchQueue.main.async { completionHandler(p == nil ? NEAppPushManagerError(.configurationNotLoaded) : nil) }
    }
    @objc(saveToPreferencesWithCompletionHandler:)
    open func saveToPreferences(completionHandler: @escaping @Sendable (Error?) -> Void) {
        guard !(providerBundleIdentifier ?? "").isEmpty, !matchSSIDs.isEmpty || !matchPrivateLTENetworks.isEmpty || matchEthernet else {
            DispatchQueue.main.async { completionHandler(NEAppPushManagerError(.configurationInvalid)) }; return
        }
        _NE.upsert("apppush", identifier, plist)
        loaded = true
        NSLog("isim NetworkExtension: saved app push configuration “%@” for %@", localizedDescription ?? "-", matchSSIDs.joined(separator: ", "))
        _Privacy.onMain { [self] in updateActive() }
        DispatchQueue.main.async { completionHandler(nil) }
    }
    @objc(removeFromPreferencesWithCompletionHandler:)
    open func removeFromPreferences(completionHandler: @escaping @Sendable (Error?) -> Void) {
        let removed = _NE.remove("apppush", identifier)
        loaded = false
        _Privacy.onMain { [self] in updateActive() }
        DispatchQueue.main.async { completionHandler(removed ? nil : NEAppPushManagerError(.configurationNotLoaded)) }
    }
}
