// isim: the ad attribution state that SKAdNetwork (StoreKit) and AdAttributionKit share, compiled into both: like
// iOS, conversion value updates from either API apply to the same postbacks.
//
// Adapted: isim has no App Store installs from ads, so no real attribution happens. Updates are checked like iOS
// (fine values 0-63; locking a conversion window closes it, later updates go to the next of the three windows; time
// is compressed: a window stays open until the app locks it) and recorded per app in
// $ISIM_DATA/Library/isim/AdAttribution/<bundle id>.json. Development postbacks — what Settings › Developer ›
// Development Postbacks creates on a device — are made with `isim adattribution` (isim-adattribution.py): an
// app's updates fill its development postbacks in $ISIM_DATA/Library/isim/AdAttribution/postbacks.json, and
// `isim adattribution transmit` sends the eligible ones to their server URL.
import Foundation

enum _IsimAttribution {
    static let lock = NSLock()
    static var dir: URL {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? (NSHomeDirectory() as NSString).appendingPathComponent(".local/share/isim")
        return URL(fileURLWithPath: data).appendingPathComponent("Library/isim/AdAttribution")
    }
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "app" }

    static func readJSON(_ url: URL) -> Any? { (try? Data(contentsOf: url)).flatMap { try? JSONSerialization.jsonObject(with: $0) } }
    static func writeJSON(_ v: Any, _ url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        if let d = try? JSONSerialization.data(withJSONObject: v, options: [.prettyPrinted, .sortedKeys]) { try? d.write(to: url) }
    }

    /// records an impression (AdAttributionKit) in the app's state
    static func recordImpression(_ info: [String: Any]) {
        lock.lock(); defer { lock.unlock() }
        let f = dir.appendingPathComponent("\(bundleID).json")
        var state = readJSON(f) as? [String: Any] ?? [:]
        var list = state["impressions"] as? [[String: Any]] ?? []
        list.append(info)
        state["impressions"] = list
        writeJSON(state, f)
    }

    /// a conversion value update: false when the value is invalid (0-63) or the window is locked
    @discardableResult
    static func update(api: String, fine: Int, coarse: String?, lockWindow: Bool, tag: String? = nil) -> Bool {
        guard (0...63).contains(fine) else {
            print("isim: \(api): conversion value \(fine) is not between 0 and 63")
            return false
        }
        lock.lock(); defer { lock.unlock() }
        let f = dir.appendingPathComponent("\(bundleID).json")
        var state = readJSON(f) as? [String: Any] ?? [:]
        // three conversion windows; locking one closes it (iOS then sends its postback early) and later updates go to
        // the next one. isim compresses time: a window stays open until the app locks it.
        let window = state["window"] as? Int ?? 0
        guard window < 3 else {
            print("isim: \(api): all three conversion windows are locked: conversion value \(fine) ignored")
            return true
        }
        state["fine"] = fine
        state["coarse"] = coarse ?? NSNull()
        if lockWindow { state["window"] = window + 1 }
        var updates = state["updates"] as? [[String: Any]] ?? []
        updates.append(["window": window, "api": api, "fine": fine, "coarse": coarse ?? NSNull(), "lock": lockWindow, "tag": tag ?? NSNull(),
                        "time": Date().timeIntervalSince1970])
        state["updates"] = updates
        writeJSON(state, f)
        // development postbacks of this app (isim adattribution): the open window takes the value
        let pf = dir.appendingPathComponent("postbacks.json")
        if var all = readJSON(pf) as? [[String: Any]] {
            var touched = 0
            for i in all.indices where all[i]["bundle"] as? String == bundleID {
                if let t = all[i]["tag"] as? String, !t.isEmpty, t != tag { continue }
                var windows = all[i]["windows"] as? [[String: Any]] ?? []
                guard let w = windows.firstIndex(where: { $0["sent"] as? Bool != true && $0["locked"] as? Bool != true }) else { continue }
                windows[w]["conversion-value"] = fine
                windows[w]["coarse-conversion-value"] = coarse ?? NSNull()
                windows[w]["locked"] = lockWindow
                all[i]["windows"] = windows
                touched += 1
            }
            if touched > 0 { writeJSON(all, pf) }
        }
        print("isim: \(api): conversion value \(fine)\(coarse.map { " coarse \($0)" } ?? "")\(lockWindow ? " (window locked)" : "") recorded"
              + " (no ad attribution on isim; development postbacks: isim adattribution)")
        return true
    }
}
