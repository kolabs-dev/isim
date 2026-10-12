// isim AppIntents: Focus filters (SetFocusFilterIntent) and the configuration intent of controls. Adapted.
//
// iOS finds an app's Focus filters in metadata Xcode extracts at build time; isim finds them at run time in the app's
// Swift conformance records (the types conforming to SetFocusFilterIntent, read from the binary's __swift5_proto
// section). The home screen asks the app once, headless (ISIM_WIDGET_REQUEST with mode focus-filters): the app lists
// each filter's title, description and @Parameters (Bool, String, Int, Double, AppEnum, and optionals of these).
// Settings > Focus > <Focus> > Focus Filters configures them. When that Focus turns on, the system runs the filter's
// perform() in the app with the configured values (a running app gets "focus-filter FILE"; otherwise it is launched
// in the background with isim-focus-filter:FILE); when it turns off, perform() runs again with the default values.
// `current` is the filter in effect, and appContext's notificationFilterPredicate is evaluated against
// UNNotificationContent.filterCriteria while that Focus is on (non-matching notifications are delivered quietly).
// UIKit calls isim_appintents_launch(0) before the app launches and isim_appintents_launch(1) after.
import Foundation
import Darwin

/// intents that configure a control (AppIntentControlConfiguration)
@available(iOS 18.0, *)
public protocol ControlConfigurationIntent: AppIntent {}
@available(iOS 18.0, *)
extension ControlConfigurationIntent {
    @MainActor public func perform() async throws -> some IntentResult { _IntentResultValue<Void>(value: nil, dialog: nil) }
}

// MARK: - Focus filters

/// What the app tells the system while its Focus filter is in effect.
public struct FocusFilterAppContext: @unchecked Sendable {
    /// notifications whose filterCriteria does not match are delivered quietly
    public var notificationFilterPredicate: NSPredicate?
    public init(notificationFilterPredicate: NSPredicate? = nil) { self.notificationFilterPredicate = notificationFilterPredicate }
}

public protocol SetFocusFilterIntent: AppIntent {
    var displayRepresentation: DisplayRepresentation { get }
    var appContext: FocusFilterAppContext { get }
}
extension SetFocusFilterIntent {
    public var appContext: FocusFilterAppContext { FocusFilterAppContext() }
    /// the filter in effect (the configured values while its Focus is on; the defaults otherwise)
    public static var current: Self { get async throws { _IsimFocus.current(Self.self) } }
}

// MARK: - parameters, type-erased

protocol _IsimParameter: AnyObject {
    var _isimTitle: String { get }
    var _isimValue: Any { get }
    var _isimValueType: Any.Type { get }
    func _isimSet(_ v: Any) -> Bool
}
extension IntentParameter: _IsimParameter {
    var _isimTitle: String { title.description }
    var _isimValue: Any { wrappedValue }
    var _isimValueType: Any.Type { Value.self }
    func _isimSet(_ v: Any) -> Bool { if let x = v as? Value { wrappedValue = x; return true }; return false }
}
protocol _IsimOptional { static var _isimWrapped: Any.Type { get }; var _isimUnwrapped: Any? { get } }
extension Optional: _IsimOptional {
    static var _isimWrapped: Any.Type { Wrapped.self }
    var _isimUnwrapped: Any? { self.map { $0 as Any } }
}

enum _IsimFocus {
    static let protocolSymbol = "$s10AppIntents20SetFocusFilterIntentMp"

    // the types conforming to SetFocusFilterIntent in the loaded images
    nonisolated(unsafe) static var found: [any SetFocusFilterIntent.Type]?
    static func filterTypes() -> [any SetFocusFilterIntent.Type] {
        if let f = found { return f }
        var out: [any SetFocusFilterIntent.Type] = []
        let dflt = UnsafeMutableRawPointer(bitPattern: -2)
        typealias Count = @convention(c) () -> UInt32
        typealias Header = @convention(c) (UInt32) -> UnsafeRawPointer?
        typealias Section = @convention(c) (UnsafeRawPointer, UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafeMutablePointer<UInt>) -> UnsafeRawPointer?
        typealias Accessor = @convention(c) (Int) -> UnsafeRawPointer?
        guard let proto = dlsym(dflt, protocolSymbol).map(UnsafeRawPointer.init), let cp = dlsym(dflt, "_dyld_image_count"),
              let hp = dlsym(dflt, "_dyld_get_image_header"), let sp = dlsym(dflt, "getsectiondata") else {
            NSLog("isim AppIntents: cannot look for Focus filters (no image or section lookup)"); found = []; return []
        }
        let count = unsafeBitCast(cp, to: Count.self), header = unsafeBitCast(hp, to: Header.self), section = unsafeBitCast(sp, to: Section.self)
        func rel(_ p: UnsafeRawPointer) -> UnsafeRawPointer { p + Int(p.load(as: Int32.self)) }
        for i in 0..<count() {
            guard let mh = header(i) else { continue }
            var size: UInt = 0
            guard let sec = section(mh, "__TEXT", "__swift5_proto", &size) else { continue }
            for k in 0..<Int(size) / 4 {
                let entry = sec + k * 4
                let desc = rel(entry)                                      /* ProtocolConformanceDescriptor */
                let pv = desc.load(as: Int32.self)
                var p = desc + Int(pv & ~1)
                if pv & 1 != 0 { guard let q = p.load(as: UnsafeRawPointer?.self) else { continue }; p = q }
                guard p == proto else { continue }
                let flags = (desc + 12).load(as: UInt32.self)
                let typeKind = (flags >> 3) & 7
                let tref = desc + 4
                var ctx: UnsafeRawPointer
                switch typeKind {
                case 0: ctx = rel(tref)
                case 1: guard let q = rel(tref).load(as: UnsafeRawPointer?.self) else { continue }; ctx = q
                default: continue
                }
                let cflags = ctx.load(as: UInt32.self)
                guard cflags & 0x80 == 0, [16, 17, 18].contains(cflags & 0x1f) else { continue }   /* non-generic class/struct/enum */
                let accessorPtr = rel(ctx + 12)
                let accessor = unsafeBitCast(accessorPtr, to: Accessor.self)
                guard let meta = accessor(0) else { continue }
                if let t = unsafeBitCast(meta, to: Any.Type.self) as? any SetFocusFilterIntent.Type { out.append(t) }
            }
        }
        found = out
        return out
    }
    static func name(_ t: Any.Type) -> String { String(reflecting: t) }
    static func type(named n: String) -> (any SetFocusFilterIntent.Type)? { filterTypes().first { name($0) == n } }

    static func parameters(_ inst: Any) -> [(name: String, param: _IsimParameter)] {
        Mirror(reflecting: inst).children.compactMap { c in
            guard let p = c.value as? _IsimParameter, var n = c.label else { return nil }
            if n.hasPrefix("_") { n.removeFirst() }
            return (n, p)
        }
    }
    // values <-> property lists
    static func plistValue(_ v: Any) -> Any? {
        var v = v
        if let o = v as? _IsimOptional { guard let u = o._isimUnwrapped else { return nil }; v = u }
        if let e = v as? any AppEnum { return e.rawValue }
        if v is Bool || v is String || v is Int || v is Double { return v }
        return nil
    }
    static func enumValue<E: AppEnum>(_ t: E.Type, _ raw: String) -> Any? { E(rawValue: raw) }
    static func enumCases<E: AppEnum>(_ t: E.Type) -> [[String]] {
        E.allCases.map { [$0.rawValue, E.caseDisplayRepresentations[$0]?.title.description ?? $0.rawValue] }
    }
    static func set(_ p: _IsimParameter, _ plist: Any) {
        var t = p._isimValueType
        if let o = t as? _IsimOptional.Type { t = o._isimWrapped }
        var v: Any? = plist
        if let e = t as? any AppEnum.Type, let raw = plist as? String { v = enumValue(e, raw) }
        else if t == Int.self, let n = plist as? NSNumber { v = n.intValue }
        else if t == Double.self, let n = plist as? NSNumber { v = n.doubleValue }
        else if t == Bool.self, let n = plist as? NSNumber { v = n.boolValue }
        if let v, !p._isimSet(v) { NSLog("isim AppIntents: Focus filter parameter: cannot set %@", "\(v)") }
    }
    static func kind(_ p: _IsimParameter) -> (String, [[String]]) {
        var t = p._isimValueType
        if let o = t as? _IsimOptional.Type { t = o._isimWrapped }
        if let e = t as? any AppEnum.Type { return ("enum", enumCases(e)) }
        if t == Bool.self { return ("bool", []) }
        if t == Int.self { return ("int", []) }
        if t == Double.self { return ("double", []) }
        return ("string", [])
    }
    static func instance(_ t: any SetFocusFilterIntent.Type, params: [String: Any]) -> any SetFocusFilterIntent {
        let inst = t.init()
        for (n, p) in parameters(inst) { if let v = params[n] { set(p, v) } }
        return inst
    }
    static func defaultsKey(_ t: Any.Type) -> String { "_ISIMFocusFilter." + name(t) }
    static func current<T: SetFocusFilterIntent>(_ t: T.Type) -> T {
        let params = UserDefaults.standard.dictionary(forKey: defaultsKey(t)) ?? [:]
        return instance(t, params: params) as! T
    }

    /// mode focus-filters: describe this app's filters for Settings
    static func list(out: String) {
        var filters: [[String: Any]] = []
        for t in filterTypes() {
            let inst = t.init()
            var params: [[String: Any]] = []
            for (n, p) in parameters(inst) {
                let (k, cases) = kind(p)
                var d: [String: Any] = ["name": n, "title": p._isimTitle, "kind": k]
                if !cases.isEmpty { d["cases"] = cases }
                if let v = plistValue(p._isimValue) { d["default"] = v }
                params.append(d)
            }
            filters.append(["type": name(t), "title": t.title.description, "description": t.description?.text ?? "", "params": params])
        }
        let dir = (out as NSString)
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true, attributes: nil)
        (["filters": filters] as NSDictionary).write(toFile: dir.appendingPathComponent("focus-filters.plist"), atomically: true)
        NSLog("isim AppIntents: %ld Focus filter(s)", filters.count)
    }

    /// the system turned a Focus on or off: run the filter (sidecar: type, params, active, focus)
    @MainActor static func apply(_ file: String) async {
        guard let d = NSDictionary(contentsOfFile: file) as? [String: Any], let tn = d["type"] as? String else { NSLog("isim AppIntents: no Focus filter request in %@", file); return }
        guard let t = type(named: tn) else { NSLog("isim AppIntents: no Focus filter %@ in this app", tn); return }
        let active = d["active"] as? Bool ?? false, focus = d["focus"] as? String ?? "Focus"
        let params = active ? (d["params"] as? [String: Any] ?? [:]) : [:]
        let inst = instance(t, params: params)
        let ud = UserDefaults.standard
        if active { ud.set(params, forKey: defaultsKey(t)) } else { ud.removeObject(forKey: defaultsKey(t)) }
        NSLog("isim AppIntents: Focus filter %@ (%@ %@): perform()", t.title.description, focus, active ? "on" : "off")
        do {
            let ctx = try await run(inst)
            if active, let p = ctx.notificationFilterPredicate { ud.set(p.predicateFormat, forKey: "_ISIMFocusNotificationFilter"); NSLog("isim AppIntents: notification filter %@", p.predicateFormat) }
            else { ud.removeObject(forKey: "_ISIMFocusNotificationFilter") }
        } catch { NSLog("isim AppIntents: Focus filter %@ failed: %@", t.title.description, "\(error)") }
        ud.synchronize()
        try? FileManager.default.removeItem(atPath: file)
    }
    @MainActor static func run<T: SetFocusFilterIntent>(_ i: T) async throws -> FocusFilterAppContext {
        let r = try await i.perform()
        if let dlg = (r as? any _DialogCarrying)?._dialog { NSLog("isim AppIntents: %@ -> “%@”", T.title.description, dlg.text) }
        return i.appContext
    }
}

/// UIKit's launch hook: phase 0 before the app launches (1: handled, exit), phase 1 after it launched
@_cdecl("isim_appintents_launch")
public func _isimAppIntentsLaunch(_ phase: Int32) -> Int32 {
    let env = ProcessInfo.processInfo.environment
    if phase == 0 {
        guard let r = env["ISIM_WIDGET_REQUEST"], let req = NSDictionary(contentsOfFile: r) as? [String: Any], req["mode"] as? String == "focus-filters" else { return 0 }
        _IsimFocus.list(out: req["out"] as? String ?? NSTemporaryDirectory())
        return 1
    }
    NotificationCenter.default.addObserver(forName: Notification.Name("_IsimSystemEvent"), object: nil, queue: nil) { n in
        guard let t = n.object as? String, t.hasPrefix("focus-filter ") else { return }
        let file = String(t.dropFirst(13))
        Task { @MainActor in await _IsimFocus.apply(file) }
    }
    if let u = env["ISIM_LAUNCH_URL"], u.hasPrefix("isim-focus-filter:") {
        let file = String(u.dropFirst(18))
        Task { @MainActor in await _IsimFocus.apply(file) }
    }
    return 0
}
