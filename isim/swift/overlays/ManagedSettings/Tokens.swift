// isim ManagedSettings (adapted): what Screen Time restricts and how the app names it. Applications, web domains
// and activity categories reach an app as opaque tokens (from FamilyControls' picker): on isim a token holds a random
// identifier that the device's Screen Time registry (<isim data>/Library/isim/ScreenTime/tokens.json) maps to the
// bundle identifier, domain or category, which the system side (the home screen, the extensions) reads and the app
// cannot. The settings an app sets live per app and store in …/ScreenTime/Stores/<bundle id>/<store>.json; the home
// screen applies the shields (system/SpringBoard/SBScreenTime.m).
import Foundation

// MARK: - tokens

/// an opaque token of an application, web domain or activity category the user picked
public struct Token<T>: Codable, Hashable, Sendable {
    let data: Data
    init(_data: Data) { data = _data }
    public init(from decoder: any Decoder) throws { data = try decoder.singleValueContainer().decode(Data.self) }
    public func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(data) }
    var _id: String { String(decoding: data, as: UTF8.self) }
}
public typealias ApplicationToken = Token<Application>
public typealias WebDomainToken = Token<WebDomain>
public typealias ActivityCategoryToken = Token<ActivityCategory>

// MARK: - what tokens stand for

public struct Application: Codable, Hashable, Sendable {
    /// the app's bundle identifier: nil when the app knows it only by its token (outside Screen Time's extensions)
    public let bundleIdentifier: String?
    public let token: ApplicationToken?
    public let localizedDisplayName: String?
    public init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
        token = _IsimScreenTime.applicationToken(bundleIdentifier)
        localizedDisplayName = _IsimScreenTime.isRevealed ? _IsimScreenTime.appName(bundleIdentifier) : nil
    }
    public init(token: ApplicationToken) {
        self.token = token
        let b = _IsimScreenTime.isRevealed ? _IsimScreenTime.bundle(for: token) : nil
        bundleIdentifier = b
        localizedDisplayName = b.flatMap(_IsimScreenTime.appName)
    }
}

public struct WebDomain: Codable, Hashable, Sendable {
    public let domain: String?
    public let token: WebDomainToken?
    public init(domain: String) { self.domain = domain; token = _IsimScreenTime.webDomainToken(domain) }
    public init(token: WebDomainToken) {
        self.token = token
        domain = _IsimScreenTime.isRevealed ? _IsimScreenTime.domain(for: token) : nil
    }
}

public struct ActivityCategory: Codable, Hashable, Sendable {
    public let token: ActivityCategoryToken?
    public let localizedDisplayName: String?
    public init(token: ActivityCategoryToken) {
        self.token = token
        localizedDisplayName = _IsimScreenTime.isRevealed ? _IsimScreenTime.category(for: token).map(_IsimScreenTime.categoryName) : nil
    }
}

// MARK: - the device's Screen Time registry (isim-internal; shared by FamilyControls, DeviceActivity, ManagedSettingsUI)

public enum _IsimScreenTime {
    public static var dataDir: String {
        ProcessInfo.processInfo.environment["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 }
            ?? ((ProcessInfo.processInfo.environment["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
    }
    public static var root: String {
        let p = (dataDir as NSString).appendingPathComponent("Library/isim/ScreenTime")
        try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true)
        return p
    }
    public static func path(_ name: String) -> String { (root as NSString).appendingPathComponent(name) }
    public static func readJSON<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let d = FileManager.default.contents(atPath: path(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
    public static func writeJSON<T: Encodable>(_ value: T, _ name: String) {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        let p = path(name)
        try? FileManager.default.createDirectory(atPath: (p as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        if let d = try? e.encode(value) { FileManager.default.createFile(atPath: p, contents: d) }
    }
    static let lock = NSLock()

    /// whether this process may see what tokens stand for: Screen Time's extensions (a monitor, a report, a shield),
    /// which iOS runs sandboxed, not the app
    public static var isRevealed: Bool {
        if ProcessInfo.processInfo.environment["ISIM_EXTENSION_REQUEST"] != nil { return true }
        return Bundle.main.bundlePath.hasSuffix(".appex") || _revealed
    }
    nonisolated(unsafe) public static var _revealed = false

    // ---- tokens ----
    struct Registry: Codable { var applications: [String: String] = [:]; var webDomains: [String: String] = [:]; var categories: [String: String] = [:] }
    static func token(_ kind: WritableKeyPath<Registry, [String: String]>, _ value: String) -> Data {
        lock.lock(); defer { lock.unlock() }
        var r = readJSON(Registry.self, "tokens.json") ?? Registry()
        if let id = r[keyPath: kind].first(where: { $0.value == value })?.key { return Data(id.utf8) }
        let id = UUID().uuidString
        r[keyPath: kind][id] = value
        writeJSON(r, "tokens.json")
        return Data(id.utf8)
    }
    static func value(_ kind: KeyPath<Registry, [String: String]>, _ data: Data) -> String? {
        (readJSON(Registry.self, "tokens.json") ?? Registry())[keyPath: kind][String(decoding: data, as: UTF8.self)]
    }
    public static func applicationToken(_ bundle: String) -> ApplicationToken { Token(_data: token(\.applications, bundle)) }
    public static func webDomainToken(_ domain: String) -> WebDomainToken { Token(_data: token(\.webDomains, domain.lowercased())) }
    public static func categoryToken(_ category: String) -> ActivityCategoryToken { Token(_data: token(\.categories, category)) }
    public static func bundle(for t: ApplicationToken) -> String? { value(\.applications, t.data) }
    public static func domain(for t: WebDomainToken) -> String? { value(\.webDomains, t.data) }
    public static func category(for t: ActivityCategoryToken) -> String? { value(\.categories, t.data) }
    public static func tokenID<T>(_ t: Token<T>) -> String { t._id }
    /// the token with an identifier (as the home screen names it in an extension request)
    public static func token<T>(id: String) -> Token<T> { Token(_data: Data(id.utf8)) }

    // ---- the device's apps and Screen Time's categories ----
    public static let categories: [(id: String, name: String)] = [
        ("social", "Social"), ("games", "Games"), ("entertainment", "Entertainment"), ("creativity", "Creativity"),
        ("productivity-finance", "Productivity & Finance"), ("education", "Education"), ("information-reading", "Information & Reading"),
        ("health-fitness", "Health & Fitness"), ("utilities", "Utilities"), ("shopping-food", "Shopping & Food"), ("travel", "Travel"),
        ("other", "Other")]
    public static func categoryName(_ id: String) -> String { categories.first { $0.id == id }?.name ?? "Other" }
    /// Screen Time's category of an app type (LSApplicationCategoryType)
    public static func category(ofAppType t: String?) -> String {
        let kind = (t ?? "").replacingOccurrences(of: "public.app-category.", with: "")
        switch kind {
        case let k where k.hasSuffix("-games") || k == "games": return "games"
        case "social-networking": return "social"
        case "entertainment", "music": return "entertainment"
        case "photography", "graphics-design", "video": return "creativity"
        case "productivity", "finance", "business": return "productivity-finance"
        case "education", "kids": return "education"
        case "news", "books", "reference", "magazines-and-newspapers": return "information-reading"
        case "healthcare-fitness", "medical", "sports": return "health-fitness"
        case "utilities", "developer-tools": return "utilities"
        case "shopping", "food-and-drink", "lifestyle": return "shopping-food"
        case "travel", "navigation", "weather": return "travel"
        default: return "other"
        }
    }
    public struct App: Sendable { public let bundle: String; public let name: String; public let category: String; public let path: String }
    /// the apps installed on the device
    public static func installedApps() -> [App] {
        let env = ProcessInfo.processInfo.environment
        let dir = env["ISIM_APPS"].flatMap { $0.isEmpty ? nil : $0 } ?? (dataDir as NSString).appendingPathComponent("Applications")
        var out: [App] = []
        for n in ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted() where n.hasSuffix(".app") {
            let p = (dir as NSString).appendingPathComponent(n)
            guard let info = NSDictionary(contentsOfFile: (p as NSString).appendingPathComponent("Info.plist")) as? [String: Any],
                  let b = info["CFBundleIdentifier"] as? String else { continue }
            let name = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? b
            out.append(App(bundle: b, name: name, category: category(ofAppType: info["LSApplicationCategoryType"] as? String), path: p))
        }
        return out
    }
    public static func appName(_ bundle: String) -> String? { installedApps().first { $0.bundle == bundle }?.name }

    // ---- authorization (FamilyControls writes it; DeviceActivity and the home screen read it) ----
    public static func authorization(_ bundle: String) -> String? { (readJSON([String: String].self, "authorization.json") ?? [:])[bundle] }
    public static func setAuthorization(_ bundle: String, _ status: String?) {
        lock.lock(); defer { lock.unlock() }
        var a = readJSON([String: String].self, "authorization.json") ?? [:]
        a[bundle] = status
        writeJSON(a, "authorization.json")
    }
    /// the app this process belongs to (an extension's containing app)
    public static var appBundle: String {
        let main = Bundle.main
        if main.bundlePath.hasSuffix(".appex") {
            let app = ((main.bundlePath as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
            if let b = Bundle(path: app)?.bundleIdentifier { return b }
        }
        return main.bundleIdentifier ?? "unknown"
    }

    /// Screen Time's clock: now, moved by `isim screentime clock +MINUTES`
    public static var now: Date {
        let off = (readJSON([String: Double].self, "clock.json") ?? [:])["offset"] ?? 0
        return Date().addingTimeInterval(off)
    }
}
