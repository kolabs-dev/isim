// Shared by isim's privacy-gated frameworks (Core Location, Contacts, EventKit, Photos, HealthKit, camera, ...):
// compiled into each of those modules (build-overlays.sh PRIVACY list), so everything here is internal.
//
// Permission answers are remembered per app in the app's container (UserDefaults), like iOS keeps them until the
// app is deleted. Shared device data (address book, calendars, photo library, health samples, the simulated
// location) lives under the device data directory: $ISIM_DATA or ~/.local/share/isim, like the Simulator's
// device `data` folder.
//
// Automation: ISIM_<SERVICE>_PERMISSION answers a prompt without showing it (see each framework), and scripts can
// tap the alert buttons (`taptext Allow While Using App`).
import UIKit

enum _Privacy {
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "this app"
    }
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "unknown" }

    /// the app's purpose string for a privacy key, or nil (logged like iOS logs it)
    static func usage(_ key: String, _ framework: String) -> String? {
        if let s = Bundle.main.object(forInfoDictionaryKey: key) as? String, !s.isEmpty { return s }
        NSLog("isim %@: this app has attempted to access privacy-sensitive data without a usage description. The app's Info.plist must contain an %@ key with a string value explaining to the user how the app uses this data (iOS would terminate the app; isim reports the access as denied)", framework, key)
        return nil
    }

    /// reported iOS version (ISIM_OS_VERSION, default 18.0): some prompts changed between releases
    static var osMajor: Int {
        let v = getenv("ISIM_OS_VERSION").map { String(cString: $0) } ?? "18.0"
        return Int(v.split(separator: ".").first ?? "18") ?? 18
    }

    /// ISIM_<NAME>_PERMISSION, lowercased
    static func scripted(_ name: String) -> String? {
        guard let v = getenv("ISIM_\(name)_PERMISSION") else { return nil }
        let s = String(cString: v).lowercased()
        return s.isEmpty ? nil : s
    }
    static func env(_ name: String) -> String? {
        guard let v = getenv(name) else { return nil }
        let s = String(cString: v)
        return s.isEmpty ? nil : s
    }

    // MARK: remembered answers (the app container)
    static func stored(_ key: String) -> Int? { UserDefaults.standard.object(forKey: "_ISIMPrivacy." + key) as? Int }
    static func store(_ key: String, _ value: Int?) {
        if let value { UserDefaults.standard.set(value, forKey: "_ISIMPrivacy." + key) }
        else { UserDefaults.standard.removeObject(forKey: "_ISIMPrivacy." + key) }
        UserDefaults.standard.synchronize()
    }

    // MARK: device data
    static var dataDir: String {
        if let d = env("ISIM_DATA") { return d }
        return ((env("HOME") ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
    }
    /// a directory under the device data, created on demand
    static func deviceDir(_ sub: String) -> String {
        let p = (dataDir as NSString).appendingPathComponent(sub)
        try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true, attributes: nil)
        return p
    }
    static func readJSON<T: Decodable>(_ type: T.Type, _ path: String) -> T? {
        guard let d = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
    static func writeJSON<T: Encodable>(_ value: T, _ path: String) {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let d = try? e.encode(value) else { NSLog("isim: cannot encode %@", path); return }
        if !FileManager.default.createFile(atPath: path, contents: d, attributes: nil) { NSLog("isim: cannot write %@", path) }
    }

    // MARK: UI
    @MainActor static func topController() -> UIViewController? {
        var vc = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }
    /// shows an iOS-style permission alert; `buttons` are (title, style); calls `done` with the tapped index
    @MainActor static func alert(_ title: String, _ message: String?, _ buttons: [(String, UIAlertAction.Style)], _ done: @escaping (Int) -> Void) {
        guard let vc = topController() else { NSLog("isim: no window to show “%@”", title); done(-1); return }
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        for (i, b) in buttons.enumerated() { a.addAction(UIAlertAction(title: b.0, style: b.1) { _ in done(i) }) }
        vc.present(a, animated: true, completion: nil)
    }
    /// runs `body` on the main thread (now if already there)
    static func onMain(_ body: @escaping @MainActor () -> Void) {
        if Thread.isMainThread { MainActor.assumeIsolated { body() } }
        else { DispatchQueue.main.async { MainActor.assumeIsolated { body() } } }
    }
    /// replies on a background queue, like the iOS frameworks' completion handlers
    static func reply(_ body: @escaping @Sendable () -> Void) { DispatchQueue.global().async { body() } }
}

/// a `@Sendable` box for values crossing into completion handlers
final class _Box<T>: @unchecked Sendable { var value: T; init(_ v: T) { value = v } }
