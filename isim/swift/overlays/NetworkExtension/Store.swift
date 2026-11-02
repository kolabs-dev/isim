// isim NetworkExtension (issue #424): the managers' configurations, stored per app in the device data like iOS keeps
// them in the system's preferences (`Library/NetworkExtension/<bundle id>.plist`), so they survive relaunches, and the
// permission alerts iOS shows before an app adds a VPN or joins a Wi-Fi network.
//
// Adapted throughout: isim does not run tunnels, filters or push providers. A packet tunnel needs a host TUN device and
// privileges, so a connection only goes through its states (connecting, connected, disconnecting, disconnected) without
// carrying traffic, and provider extensions are not launched. The device's Wi-Fi network is simulated: its name is
// ISIM_WIFI_SSID (default "isim"), which NEAppPushManager matches.
import UIKit

enum _NE {
    static var bundleID: String { _Privacy.bundleID }
    static var path: String {
        (_Privacy.deviceDir("Library/NetworkExtension") as NSString).appendingPathComponent(bundleID + ".plist")
    }
    /// the app's stored configurations: kind -> list of property-list dictionaries
    static func all() -> [String: Any] { NSDictionary(contentsOfFile: path) as? [String: Any] ?? [:] }
    static func load(_ kind: String) -> [[String: Any]] { all()[kind] as? [[String: Any]] ?? [] }
    static func save(_ kind: String, _ items: [[String: Any]]) {
        var d = all()
        d[kind] = items.isEmpty ? nil : items
        if !(d as NSDictionary).write(toFile: path, atomically: true) { NSLog("isim NetworkExtension: cannot write %@", path) }
    }
    /// replaces (or adds) the configuration with this identifier
    static func upsert(_ kind: String, _ id: String, _ item: [String: Any]) {
        var items = load(kind).filter { $0["identifier"] as? String != id }
        var item = item
        item["identifier"] = id
        items.append(item)
        save(kind, items)
    }
    static func remove(_ kind: String, _ id: String) -> Bool {
        let items = load(kind)
        let kept = items.filter { $0["identifier"] as? String != id }
        save(kind, kept)
        return kept.count != items.count
    }

    /// the simulated Wi-Fi network the device is on
    static var wifiSSID: String { _Privacy.env("ISIM_WIFI_SSID") ?? "isim" }

    /// iOS's one-time permission before an app adds configurations: remembered per app; ISIM_VPN_PERMISSION=allow|deny
    /// answers it without the alert
    @MainActor static func permission(_ key: String, title: String, message: String, done: @escaping (Bool) -> Void) {
        if let s = _Privacy.stored(key) { done(s == 1); return }
        if let s = _Privacy.scripted("VPN") {
            let ok = s == "allow" || s == "1" || s == "yes"
            _Privacy.store(key, ok ? 1 : 0)
            done(ok); return
        }
        _Privacy.alert(title, message, [("Don’t Allow", .cancel), ("Allow", .default)]) { i in
            _Privacy.store(key, i == 1 ? 1 : 0)
            NSLog("isim NetworkExtension: %@ %@", title, i == 1 ? "allowed" : "not allowed")
            done(i == 1)
        }
    }
}

// property-list helpers
extension Dictionary where Key == String, Value == Any {
    func _ne<T>(_ k: String, _ d: T) -> T { self[k] as? T ?? d }
}
