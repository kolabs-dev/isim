// isim WebKit: connection to the web engine process.
//
// Pages are rendered by real WebKit — the host's WebKitGTK 6.0 running in isim's helper process
// (out/bin/isim-webkit, see isim/runtime/isim-webkit.c and host_web.c) on a private, invisible display.
// This file speaks its line protocol: commands go out with isim_web_send, events come back on a
// reader thread and are handled on the main queue by the WKWebView they belong to.
import Foundation
import isim_host

enum _WKProto {
    static func esc(_ s: String) -> String {
        var o = ""
        o.reserveCapacity(s.utf8.count)
        for c in s.unicodeScalars {
            switch c {
            case "\\": o += "\\\\"
            case "\n": o += "\\n"
            case "\t": o += "\\t"
            case "\r": o += "\\r"
            default: o.unicodeScalars.append(c)
            }
        }
        return o
    }
    static func unesc(_ s: Substring) -> String {
        guard s.contains("\\") else { return String(s) }
        var o = "", it = s.unicodeScalars.makeIterator()
        while let c = it.next() {
            if c == "\\", let n = it.next() {
                switch n { case "n": o += "\n"; case "t": o += "\t"; case "r": o += "\r"; default: o.unicodeScalars.append(n) }
            } else { o.unicodeScalars.append(c) }
        }
        return o
    }
    static func num(_ d: Double) -> String {
        if d == d.rounded() && abs(d) < 1e15 { return String(Int(d)) }
        return String(d)
    }
}

final class _WKEngine: @unchecked Sendable {
    static let shared = _WKEngine()
    private var started = false
    private(set) var available = false
    private(set) var unavailableReason = ""
    private(set) var engineVersion = ""
    private var views: [Int: _WKWeakView] = [:]
    private var nextID = 0
    /// request id -> completion for "done"/"js"/... replies addressed to a store rather than a view
    var storeCallbacks: [Int: (String) -> Void] = [:]
    private var nextReq = 1_000_000

    /// Starts the engine (once). false if the host has no WebKitGTK helper.
    func start() -> Bool {
        if started { return available }
        started = true
        var why = [CChar](repeating: 0, count: 512)
        available = isim_web_available(&why, Int32(why.count)) != 0
        if !available {
            unavailableReason = String(cString: why)
            print("isim: WKWebView: \(unavailableReason)")
            return false
        }
        DispatchQueue(label: "isim.WebKit.engine").async { self.readLoop() }
        return true
    }
    private func readLoop() {
        while true {
            guard let p = isim_web_next(1.0) else { continue }
            let line = String(cString: p)
            isim_web_free(p)
            DispatchQueue.main.async { MainActor.assumeIsolated { self.handle(line) } }
        }
    }
    func register(_ v: WKWebView) -> Int {
        nextID += 1
        views[nextID] = _WKWeakView(v)
        return nextID
    }
    func unregister(_ id: Int) { views[id] = nil }
    func newRequestID() -> Int { nextReq += 1; return nextReq }

    func send(_ fields: [String]) {
        guard available else { return }
        let line = fields.map(_WKProto.esc).joined(separator: "\t")
        line.withCString { isim_web_send($0) }
    }

    @MainActor private func handle(_ line: String) {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return }
        let ev = String(parts[0]), id = Int(parts[1]) ?? 0
        let f = parts.dropFirst(2).map(_WKProto.unesc)
        switch ev {
        case "hello": engineVersion = f.joined(separator: " ")
        case "exited":
            available = false
            unavailableReason = "the web engine process exited"
            for w in views.values { w.view?._engineExited() }
        default:
            if id == 0 {
                if ev == "scheme", f.count >= 2 { _WKSchemeRouter.request(id: Int(f[0]) ?? 0, viewID: 0, json: f[1]) }
                return
            }
            if ev == "scheme", f.count >= 2 { _WKSchemeRouter.request(id: Int(f[0]) ?? 0, viewID: id, json: f[1]); return }
            if ev == "done", f.count >= 1, let req = Int(f[0]), let cb = storeCallbacks.removeValue(forKey: req) {
                cb(f.count > 1 ? f[1] : ""); return
            }
            views[id]?.view?._event(ev, f)
        }
    }
}

final class _WKWeakView { weak var view: WKWebView?; init(_ v: WKWebView) { view = v } }

/// JSON text from the engine -> Foundation objects as WKWebView reports them (NSNumber/String/Array/Dictionary/NSNull)
func _wkJSONValue(_ json: String) -> Any? {
    if json == "undefined" { return nil }
    guard let d = json.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
}
/// a Swift/Foundation value -> JSON text for the engine (nil -> "undefined")
func _wkJSONText(_ v: Any?) -> String {
    guard let v else { return "undefined" }
    if v is NSNull { return "null" }
    if let d = v as? Date { return _wkJSONText(d.timeIntervalSince1970 * 1000) }
    if let s = v as? String, let d = try? JSONSerialization.data(withJSONObject: s, options: [.fragmentsAllowed]) { return String(decoding: d, as: UTF8.self) }
    if JSONSerialization.isValidJSONObject(v), let d = try? JSONSerialization.data(withJSONObject: v, options: [.fragmentsAllowed]) {
        return String(decoding: d, as: UTF8.self)
    }
    if let d = try? JSONSerialization.data(withJSONObject: v, options: [.fragmentsAllowed]) { return String(decoding: d, as: UTF8.self) }
    return "null"
}
func _wkJSONObject(_ json: String) -> [String: Any] {
    (_wkJSONValue(json) as? [String: Any]) ?? [:]
}
