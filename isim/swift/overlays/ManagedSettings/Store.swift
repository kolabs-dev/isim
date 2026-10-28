// isim ManagedSettings: ManagedSettingsStore. A store's settings live in <isim data>/Library/isim/ScreenTime/
// Stores/<bundle id>/<store name>.json (each group as set; `active` for iOS 26.5's isActive). Adapted: the home screen
// applies the shield settings of the stores of apps Screen Time authorized (SBScreenTime.m); the other settings are
// kept and reported (the effective values are the strictest across the device's stores) but not enforced by the
// system apps.
import Foundation
import Combine

open class ManagedSettingsStore: ObservableObject {
    public struct Name: RawRepresentable, Hashable, Codable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let `default` = Name("default")
    }

    struct _Settings: Codable, Equatable {
        var account = AccountSettings(), application = ApplicationSettings(), appStore = AppStoreSettings(), cellular = CellularSettings()
        var dateAndTime = DateAndTimeSettings(), gameCenter = GameCenterSettings(), media = MediaSettings(), passcode = PasscodeSettings()
        var safari = SafariSettings(), shield = ShieldSettings(), siri = SiriSettings(), webContent = WebContentSettings()
        var active = true
    }

    let _name: Name
    /// the app's default store
    public init() { _name = .default; _refreshEffective() }
    /// one of the app's named stores (each app may have up to 50)
    public convenience init(named name: ManagedSettingsStore.Name) { self.init(_name: name) }
    init(_name name: Name) { _name = name; _refreshEffective() }

    static func dir(_ bundle: String = _IsimScreenTime.appBundle) -> String { "Stores/\(bundle)" }
    var _file: String { "\(Self.dir())/\(_name.rawValue).json" }
    func _load() -> _Settings { _IsimScreenTime.readJSON(_Settings.self, _file) ?? _Settings() }
    func _update(_ body: (inout _Settings) -> Void) {
        _IsimScreenTime.lock.lock()
        var s = _load()
        body(&s)
        _IsimScreenTime.writeJSON(s, _file)
        _IsimScreenTime.lock.unlock()
        _refreshEffective()
        NSLog("isim ManagedSettings: %@ store “%@” updated", _IsimScreenTime.appBundle, _name.rawValue)
    }

    // MARK: the settings groups
    public var account: AccountSettings { get { _load().account } set { _update { $0.account = newValue } } }
    public var application: ApplicationSettings { get { _load().application } set { _update { $0.application = newValue } } }
    public var appStore: AppStoreSettings { get { _load().appStore } set { _update { $0.appStore = newValue } } }
    public var cellular: CellularSettings { get { _load().cellular } set { _update { $0.cellular = newValue } } }
    public var dateAndTime: DateAndTimeSettings { get { _load().dateAndTime } set { _update { $0.dateAndTime = newValue } } }
    public var gameCenter: GameCenterSettings { get { _load().gameCenter } set { _update { $0.gameCenter = newValue } } }
    public var media: MediaSettings { get { _load().media } set { _update { $0.media = newValue } } }
    public var passcode: PasscodeSettings { get { _load().passcode } set { _update { $0.passcode = newValue } } }
    public var safari: SafariSettings { get { _load().safari } set { _update { $0.safari = newValue } } }
    public var shield: ShieldSettings { get { _load().shield } set { _update { $0.shield = newValue } } }
    public var siri: SiriSettings { get { _load().siri } set { _update { $0.siri = newValue } } }
    public var webContent: WebContentSettings { get { _load().webContent } set { _update { $0.webContent = newValue } } }

    /// removes every setting of this store
    @available(iOS 16.0, *)
    open func clearAllSettings() { _update { s in let active = s.active; s = _Settings(); s.active = active } }

    // MARK: iOS 26.5: the app's stores
    /// whether the store's settings apply (an inactive store keeps them without applying them)
    @available(iOS 26.5, *)
    open var isActive: Bool { get { _load().active } set { _update { $0.active = newValue } } }
    @available(iOS 26.5, *)
    open func deleteStore() {
        try? FileManager.default.removeItem(atPath: _IsimScreenTime.path(_file))
        _refreshEffective()
    }
    /// the app's stores
    @available(iOS 26.5, *)
    public static var stores: Set<ManagedSettingsStore.Name> {
        let d = _IsimScreenTime.path(dir())
        return Set(((try? FileManager.default.contentsOfDirectory(atPath: d)) ?? []).filter { $0.hasSuffix(".json") }
                    .map { Name(($0 as NSString).deletingPathExtension) })
    }
    @available(iOS 26.5, *)
    public static func deleteStores(_ storeNames: Set<ManagedSettingsStore.Name>) {
        for n in storeNames { ManagedSettingsStore(named: n).deleteStore() }
    }
    /// renews tokens that expired (isim's tokens do not expire: they are kept as they are)
    @available(iOS 26.5, *)
    public static func refresh(_ tokens: inout [ApplicationToken]) throws {}
    @available(iOS 26.5, *)
    public static func refresh(_ tokens: inout [WebDomainToken]) throws {}
    @available(iOS 26.5, *)
    public static func refresh(_ tokens: inout [ActivityCategoryToken]) throws {}
    /// posted when the app's tokens expired and need refresh (never on isim)
    @available(iOS 26.5, *)
    public struct TokenExpiryMessage: NotificationCenter.AsyncMessage, Sendable {
        public typealias Subject = ManagedSettingsStore
    }

    // MARK: effective values (the strictest across the device's active stores)
    @Published public private(set) var effectiveMaximumMovieRating: Int = 1000
    @Published public private(set) var effectiveMaximumTVShowRating: Int = 1000
    @Published public private(set) var effectiveDenyExplicitContent: Bool = false

    func _refreshEffective() {
        var movie = 1000, tv = 1000, explicit = false
        for s in Self._allActive() {
            movie = min(movie, s.media.maximumMovieRating ?? 1000)
            tv = min(tv, s.media.maximumTVShowRating ?? 1000)
            explicit = explicit || (s.media.denyExplicitContent ?? false)
        }
        if effectiveMaximumMovieRating != movie { effectiveMaximumMovieRating = movie }
        if effectiveMaximumTVShowRating != tv { effectiveMaximumTVShowRating = tv }
        if effectiveDenyExplicitContent != explicit { effectiveDenyExplicitContent = explicit }
    }
    static func _allActive() -> [_Settings] {
        let base = _IsimScreenTime.path("Stores")
        var out: [_Settings] = []
        for app in (try? FileManager.default.contentsOfDirectory(atPath: base)) ?? [] {
            for f in (try? FileManager.default.contentsOfDirectory(atPath: (base as NSString).appendingPathComponent(app))) ?? [] where f.hasSuffix(".json") {
                if let s = _IsimScreenTime.readJSON(_Settings.self, "Stores/\(app)/\(f)"), s.active { out.append(s) }
            }
        }
        return out
    }
}
