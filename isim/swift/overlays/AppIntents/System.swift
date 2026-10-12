// isim AppIntents: what the system does with an app's intents (adapted).
//
// - Finding them: the Swift runtime's protocol conformance records (__swift5_proto) of the app's images list the types
//   conforming to AppShortcutsProvider and AppIntent (Apple's build step, which isim does not have, reads them from
//   the compiler and writes Metadata.appintents).
// - Metadata mode: the home screen starts the app's executable with ISIM_EXTENSION_REQUEST { mode = appintents-list;
//   out = PATH } (UIApplicationMain calls isim_appintents_list_main before launching anything); the app writes its
//   App Shortcuts (phrases with ${applicationName} / ${parameter} placeholders, short titles, symbols, tile color) and
//   its intents (titles, descriptions, parameters with their kinds and choices: AppEnum cases, suggestedEntities())
//   to PATH and exits.
// - Running one: the "isim-intent:<dir>/request.plist" launch marker (UIKit; the app is started in the background, or in
//   the foreground for openAppWhenRun / OpenIntent) calls isim_appintents_run_request. Missing required parameters
//   are asked for, then perform() runs; requestValue / requestDisambiguation / requestConfirmation / needsValueError
//   ask the person. Questions and the result go through the run directory (the intent run protocol, documented in
//   frameworks/Intents/INSiriRunner.m and system/SpringBoard/SBSiri.m): step-N.plist { type = value | choice |
//   confirm | result; ... } from the app, answer-N.plist from the system. Snippet views are drawn to PNGs (snippet-N.png).
// The entry point other system features can reuse is the request: { kind = appintent; intent = Module.TypeName;
// shortcut = index (optional: the App Shortcut's own intent instance); params = { name = value or entity id }; dir }.
import Foundation
import SwiftUI
import UIKit
import Darwin

// MARK: - reflection

enum _IsimReflection {
    /// the @Parameter properties of an intent, in declaration order
    static func parameters(of intent: Any) -> [(name: String, param: _IsimAnyParameter)] {
        var out: [(String, _IsimAnyParameter)] = []
        for c in Mirror(reflecting: intent).children {
            guard let label = c.label, let p = c.value as? _IsimAnyParameter else { continue }
            out.append((label.hasPrefix("_") ? String(label.dropFirst()) : label, p))
        }
        return out
    }
    /// the property name of `\.$parameter` (the key path's parameter object is found among the intent's)
    static func parameterName<Root>(_ intent: Root, keyPath: AnyKeyPath) -> String? {
        guard let obj = intent[keyPath: keyPath] as AnyObject? else { return nil }
        return parameters(of: intent).first { $0.param === obj }?.name
    }
}

// MARK: - conformance records

enum _IsimConformances {
    private typealias GetSect = @convention(c) (UnsafeRawPointer, UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafeMutablePointer<UInt>) -> UnsafeMutableRawPointer?
    private typealias ImageCount = @convention(c) () -> UInt32
    private typealias ImageHeader = @convention(c) (UInt32) -> UnsafeRawPointer?
    private typealias ImageName = @convention(c) (UInt32) -> UnsafePointer<CChar>?
    private typealias Accessor = @convention(c) (Int) -> UnsafeRawPointer?
    private static func fn<T>(_ name: String, _ type: T.Type) -> T? {
        guard let p = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
        return unsafeBitCast(p, to: type)
    }
    private static func direct(_ p: UnsafeRawPointer) -> UnsafeRawPointer? {
        let v = p.load(as: Int32.self)
        return v == 0 ? nil : p + Int(v)
    }
    private static func indirectable(_ p: UnsafeRawPointer) -> UnsafeRawPointer? {
        let v = p.load(as: Int32.self)
        if v == 0 { return nil }
        if v & 1 != 0 { return (p + Int(v & ~1)).load(as: UnsafeRawPointer?.self) }
        return p + Int(v)
    }
    private static func name(_ context: UnsafeRawPointer) -> String? {
        guard let n = direct(context + 8) else { return nil }
        return String(cString: n.assumingMemoryBound(to: CChar.self))
    }
    nonisolated(unsafe) private static var cache: [String: [Any.Type]] = [:]
    /// non-generic types of the app (its executable and the frameworks in its bundle) conforming to Module.proto
    static func types(conformingTo proto: String, module: String = "AppIntents") -> [Any.Type] {
        if let c = cache[proto] { return c }
        guard let getsect = fn("getsectiondata", GetSect.self), let count = fn("_dyld_image_count", ImageCount.self),
              let header = fn("_dyld_get_image_header", ImageHeader.self), let imageName = fn("_dyld_get_image_name", ImageName.self) else { return [] }
        let bundle = Bundle.main.bundlePath
        var out: [Any.Type] = []
        for i in 0..<count() {
            guard let cn = imageName(i), String(cString: cn).hasPrefix(bundle), let mh = header(i) else { continue }
            var size: UInt = 0
            guard let sec = getsect(mh, "__TEXT", "__swift5_proto", &size) else { continue }
            for off in stride(from: 0, to: Int(size), by: 4) {
                guard let desc = direct(UnsafeRawPointer(sec) + off), let p = indirectable(desc) else { continue }
                guard name(p) == proto, let parent = indirectable(p + 4), name(parent) == module else { continue }
                let flags = (desc + 12).load(as: UInt32.self)
                var typeDesc: UnsafeRawPointer?
                switch (flags >> 3) & 7 {
                case 0: typeDesc = direct(desc + 4)
                case 1: typeDesc = direct(desc + 4).flatMap { $0.load(as: UnsafeRawPointer?.self) }
                default: continue                                     // Objective-C classes
                }
                guard let td = typeDesc else { continue }
                let tflags = td.load(as: UInt32.self)
                guard tflags & 0x80 == 0, [16, 17, 18].contains(tflags & 0x1F) else { continue }   // generic types have no plain accessor
                guard let acc = direct(td + 12), let md = unsafeBitCast(acc, to: Accessor.self)(0) else { continue }
                out.append(unsafeBitCast(md, to: Any.Type.self))
            }
        }
        cache[proto] = out
        return out
    }
    static var providers: [any AppShortcutsProvider.Type] { types(conformingTo: "AppShortcutsProvider").compactMap { $0 as? any AppShortcutsProvider.Type } }
    static var intents: [any AppIntent.Type] { types(conformingTo: "AppIntent").compactMap { $0 as? any AppIntent.Type } }
}
func _isimTypeName(_ t: Any.Type) -> String { String(reflecting: t) }

// MARK: - values

extension AppEnum {
    static func _isimCases() -> [_IsimOption] {
        allCases.map { _IsimOption(id: $0.rawValue, title: caseDisplayRepresentations[$0]?.title.description ?? $0.rawValue,
                                   subtitle: caseDisplayRepresentations[$0]?.subtitle?.description ?? "", value: $0) }
    }
    var _isimTitle: String { Self.caseDisplayRepresentations[self]?.title.description ?? rawValue }
}
extension AppEntity {
    var _isimOption: _IsimOption {
        _IsimOption(id: "\(id)", title: displayRepresentation.title.description, subtitle: displayRepresentation.subtitle?.description ?? "", value: self)
    }
    static func _isimSuggested() async -> [_IsimOption] {
        var found: [any AppEntity] = ((try? await defaultQuery.suggestedEntities()) ?? []).map { $0 as any AppEntity }
        if found.isEmpty, let all = defaultQuery as? any EnumerableEntityQuery, let a = try? await all.allEntities() { found = a.map { $0 as any AppEntity } }
        return found.map { $0._isimOption }
    }
    static func _isimTypedID(_ s: String) -> DefaultQuery.Entity.ID? {
        if let v = s as? DefaultQuery.Entity.ID { return v }
        if let u = UUID(uuidString: s), let v = u as? DefaultQuery.Entity.ID { return v }
        if let i = Int(s), let v = i as? DefaultQuery.Entity.ID { return v }
        return nil
    }
    static func _isimFind(_ id: String) async -> _IsimOption? {
        if let typed = _isimTypedID(id), let e = try? await defaultQuery.entities(for: [typed]).first { return (e as any AppEntity)._isimOption }
        return await _isimSuggested().first { $0.id == id }
    }
    static func _isimMatching(_ text: String) async -> [_IsimOption] {
        if let q = defaultQuery as? any EntityStringQuery, let found = try? await q.entities(matching: text), !found.isEmpty {
            return found.map { ($0 as any AppEntity)._isimOption }
        }
        let t = text.lowercased()
        return await _isimSuggested().filter { $0.title.lowercased() == t || $0.title.lowercased().contains(t) || $0.id.lowercased() == t }
    }
}
struct _IsimOption: @unchecked Sendable {
    let id: String, title: String, subtitle: String
    let value: Any
    var plist: [String: Any] { ["id": id, "title": title, "subtitle": subtitle] }
}

enum _IsimValues {
    enum Kind {
        case string, integer, decimal, boolean, date, url
        case enumeration(any AppEnum.Type), entity(any AppEntity.Type), unsupported(String)
        var name: String {
            switch self {
            case .string: return "string"; case .integer: return "integer"; case .decimal: return "decimal"; case .boolean: return "boolean"
            case .date: return "date"; case .url: return "url"; case .enumeration: return "enum"; case .entity: return "entity"
            case .unsupported(let t): return "unsupported:" + t
            }
        }
        var isChoice: Bool { switch self { case .enumeration, .entity, .boolean: return true; default: return false } }
    }
    static func kind(_ t: Any.Type) -> Kind {
        if t == String.self { return .string }
        if t == Int.self { return .integer }
        if t == Double.self || t == Float.self { return .decimal }
        if t == Bool.self { return .boolean }
        if t == Date.self { return .date }
        if t == URL.self { return .url }
        if let e = t as? any AppEnum.Type { return .enumeration(e) }
        if let e = t as? any AppEntity.Type { return .entity(e) }
        return .unsupported(String(reflecting: t))
    }
    static func cast<V>(_ v: Any, to: V.Type) -> V? {
        if let x = v as? V { return x }
        if let o = v as? _IsimOptional, let u = o._isimUnwrapped { return u as? V }
        return nil
    }
    static func describe(_ v: Any) -> String {
        if let o = v as? _IsimOptional { return o._isimUnwrapped.map(describe) ?? "" }
        if let e = v as? any AppEntity { return e.displayRepresentation.title.description }
        if let e = v as? any AppEnum { return e._isimTitle }
        if let b = v as? Bool { return b ? "Yes" : "No" }
        if let d = v as? Date { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: d) }
        if let s = v as? String { return s }
        return "\(v)"
    }
    static func options(_ k: Kind) async -> [_IsimOption] {
        switch k {
        case .enumeration(let e): return e._isimCases()
        case .entity(let e): return await e._isimSuggested()
        case .boolean: return [_IsimOption(id: "true", title: "Yes", subtitle: "", value: true), _IsimOption(id: "false", title: "No", subtitle: "", value: false)]
        default: return []
        }
    }
    /// a value from an id (App Shortcut phrases, presets) or from what the person typed
    static func value(_ s: String, _ k: Kind) async -> Any? {
        let t = s.trimmingCharacters(in: .whitespaces)
        switch k {
        case .string: return t
        case .integer: return Int(t) ?? Double(t).map { Int($0) } ?? _words[t.lowercased()]
        case .decimal: return Double(t) ?? _words[t.lowercased()].map { Double($0) }
        case .boolean: return ["true", "yes", "on", "1", "y", "ok"].contains(t.lowercased()) ? true : ["false", "no", "off", "0", "n"].contains(t.lowercased()) ? false : nil
        case .url: return URL(string: t)
        case .date:
            let f = ISO8601DateFormatter()
            if let d = f.date(from: t) { return d }
            switch t.lowercased() { case "today", "now": return Date(); case "tomorrow": return Date().addingTimeInterval(86400); default: return nil }
        case .enumeration(let e):
            let l = t.lowercased()
            return e._isimCases().first { $0.id.lowercased() == l || $0.title.lowercased() == l }?.value
        case .entity(let e):
            if let o = await e._isimFind(t) { return o.value }
            return await e._isimMatching(t).first?.value
        case .unsupported: return nil
        }
    }
    static let _words = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
                         "fifteen": 15, "twenty": 20, "thirty": 30, "forty-five": 45, "sixty": 60]
    static func prompt(_ title: String, _ k: Kind) -> String {
        let t = title.lowercased()
        switch k {
        case .enumeration, .entity: return "Which \(t)?"
        case .boolean: return "\(title)?"
        case .integer, .decimal: return "What’s the \(t)?"
        default: return "What’s the \(t)?"
        }
    }
}

// MARK: - the run directory

@MainActor final class _IsimChannel {
    let dir: String
    var step = 0
    init(dir: String) { self.dir = dir }
    func path(_ name: String, _ n: Int) -> String { (dir as NSString).appendingPathComponent("\(name)-\(n).plist") }
    @discardableResult func write(_ d: [String: Any]) -> Int {
        step += 1
        (d as NSDictionary).write(toFile: path("step", step), atomically: true)
        return step
    }
    func ask(_ d: [String: Any]) async -> [String: Any] {
        let n = write(d)
        NSLog("isim AppIntents: asking (%@): %@", d["type"] as? String ?? "", d["prompt"] as? String ?? "")
        for _ in 0..<(20 * 300) {
            if let a = NSDictionary(contentsOfFile: path("answer", n)) as? [String: Any] { return a }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return ["kind": "cancel"]
    }
}

@MainActor enum _IsimRun {
    static var channel: _IsimChannel?
    static var names: [ObjectIdentifier: String] = [:]
    static var width: CGFloat = 358
    static var snippets = 0

    /// asks for a parameter's value: a choice for enums, entities and Booleans (or `among` the given values), else text
    static func ask(_ p: _IsimAnyParameter, dialog: String?, among: [Any]?) async throws -> Any {
        guard let ch = channel else {
            NSLog("isim AppIntents: %@ needs a value, but the intent was not run by the system (no one to ask)", p._isimTitle)
            throw _IsimIntentError.noRun
        }
        let k = _IsimValues.kind(p._isimValueType)
        let name = names[ObjectIdentifier(p)] ?? ""
        let prompt = dialog ?? p._isimPrompt ?? _IsimValues.prompt(p._isimTitle, k)
        var options: [_IsimOption]
        if let among { options = among.enumerated().map { _IsimOption(id: "\($0.offset)", title: _IsimValues.describe($0.element), subtitle: "", value: $0.element) } }
        else { options = await _IsimValues.options(k) }
        if !options.isEmpty || among != nil {
            let a = await ch.ask(["type": "choice", "param": name, "prompt": prompt, "options": options.map { $0.plist }, "kind": k.name,
                                  "text": (k.isChoice && among == nil) ? false : true])
            if a["kind"] as? String == "option", let i = a["index"] as? Int, i >= 0, i < options.count { return options[i].value }
            if a["kind"] as? String == "text", let t = a["text"] as? String {          /* said or typed instead of tapped */
                let l = t.lowercased()
                if let o = options.first(where: { $0.title.lowercased() == l || $0.id.lowercased() == l }) { return o.value }
                if among == nil, let v = await _IsimValues.value(t, k) { return v }
            }
            throw _IsimIntentError.cancelled
        }
        let a = await ch.ask(["type": "value", "param": name, "prompt": prompt, "kind": k.name])
        guard a["kind"] as? String == "text", let t = a["text"] as? String, let v = await _IsimValues.value(t, k) else { throw _IsimIntentError.cancelled }
        return v
    }
    /// asks to confirm; throws _IsimIntentError.cancelled when the person cancels (nothing to ask: goes on)
    static func confirm(dialog: String?, snippet: AnyView?, action: String, cancel: String = "Cancel") async throws {
        guard let ch = channel else { NSLog("isim AppIntents: confirmation “%@” (not run by the system: goes on)", dialog ?? ""); return }
        var step: [String: Any] = ["type": "confirm", "prompt": dialog ?? "Do you want to continue?", "action": action, "cancel": cancel]
        if let s = snippet, let png = render(s) { step["snippet"] = png }
        let a = await ch.ask(step)
        if a["kind"] as? String != "confirm" { throw _IsimIntentError.cancelled }
    }
    /// a snippet view drawn into the run directory (PNG at 3x, as wide as Siri's card)
    static func render(_ view: AnyView) -> String? {
        guard let ch = channel else { return nil }
        let host = UIHostingController(rootView: AnyView(view.frame(width: width).fixedSize(horizontal: false, vertical: true)))
        var size = host.sizeThatFits(in: CGSize(width: width, height: 2000))
        size.width = width; size.height = min(max(size.height, 20), 600)
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.backgroundColor = .clear
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 3; fmt.opaque = false
        let data = UIGraphicsImageRenderer(size: size, format: fmt).pngData { _ in
            _ = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        snippets += 1
        let file = (ch.dir as NSString).appendingPathComponent("snippet-\(snippets).png")
        guard (try? data.write(to: URL(fileURLWithPath: file))) != nil else { return nil }
        NSLog("isim AppIntents: snippet view %.0f x %.0f", size.width, size.height)
        return file
    }
}

// MARK: - running a request from the system

@MainActor private func _perform<I: AppIntent>(_ intent: I) async throws -> any IntentResult { try await intent.perform() }

@MainActor enum _IsimRunner {
    static func intentType(_ name: String) -> (any AppIntent.Type)? {
        _IsimConformances.intents.first { _isimTypeName($0) == name }
    }
    static func shortcut(_ index: Int) -> AppShortcut? {
        let all = _IsimConformances.providers.flatMap { $0.appShortcuts }
        return index >= 0 && index < all.count ? all[index] : nil
    }
    static func run(_ path: String) async {
        guard let req = NSDictionary(contentsOfFile: path) as? [String: Any] else { NSLog("isim AppIntents: no request at %@", path); return }
        let ch = _IsimChannel(dir: req["dir"] as? String ?? (path as NSString).deletingLastPathComponent)
        let app = UIApplication.shared
        var task = app.beginBackgroundTask(withName: "AppIntent") {}
        defer { if task != .invalid { app.endBackgroundTask(task); task = .invalid } }
        let appName = req["appName"] as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "the app"
        if let w = req["width"] as? Double { _IsimRun.width = CGFloat(w) }
        var intent: (any AppIntent)?
        if let i = req["shortcut"] as? Int, let s = shortcut(i) { intent = s._intent }
        else if let name = req["intent"] as? String, let t = intentType(name) { intent = t.init() }
        guard let intent else {
            NSLog("isim AppIntents: no intent %@ in the app", req["intent"] as? String ?? "")
            ch.write(["type": "result", "outcome": "failure", "dialog": "Sorry, \(appName) can’t do that."]); return
        }
        let title = type(of: intent).title.description
        let params = _IsimReflection.parameters(of: intent)
        _IsimRun.names = Dictionary(params.map { (ObjectIdentifier($0.param), $0.name) }, uniquingKeysWith: { a, _ in a })
        _IsimRun.channel = ch
        defer { _IsimRun.channel = nil }
        NSLog("isim AppIntents: %@ runs “%@” (%@)", req["source"] as? String ?? "the system", title, _isimTypeName(type(of: intent)))
        for (name, v) in req["params"] as? [String: String] ?? [:] {
            guard let p = params.first(where: { $0.name == name })?.param else { continue }
            if let value = await _IsimValues.value(v, _IsimValues.kind(p._isimValueType)), p._isimSet(value) {
                NSLog("isim AppIntents: %@ = %@", name, _IsimValues.describe(value))
            }
        }
        do {
            for (name, p) in params where !p._isimOptional && !p._isimHasValue {
                let v = try await _IsimRun.ask(p, dialog: nil, among: nil)
                _ = p._isimSet(v)
                NSLog("isim AppIntents: %@ = %@", name, _IsimValues.describe(v))
            }
            var performed: (any IntentResult)?
            var attempts = 0
            while performed == nil {
                do { performed = try await _perform(intent) }
                catch let e as _IsimNeedsValue where attempts < 4 {      /* needsValueError(): ask, then perform again */
                    attempts += 1
                    guard let p = e.parameter as? _IsimAnyParameter else { throw e }
                    let v = try await _IsimRun.ask(p, dialog: e.dialog, among: nil)
                    _ = p._isimSet(v)
                }
            }
            guard let result = performed else { return }
            var step: [String: Any] = ["type": "result", "outcome": "success", "dialog": ""]
            var r = result as? any _ResultCarrying
            if let opened = r?._opensIntent {                          /* .result(opensIntent:): it runs next, in the foreground */
                NSLog("isim AppIntents: opens “%@”", type(of: opened).title.description)
                step["open"] = true
                if let r2 = try? await _perform(opened) as? any _ResultCarrying, r?._dialog == nil { r = r2 }
            }
            if let d = r?._dialog?.text { step["dialog"] = d }
            if let v = r?._valueAny { step["value"] = _IsimValues.describe(v) }
            if let s = r?._snippetView, let png = _IsimRun.render(s) { step["snippet"] = png }
            if type(of: intent).openAppWhenRun { step["open"] = true }
            NSLog("isim AppIntents: %@ -> “%@”", title, step["dialog"] as? String ?? "")
            ch.write(step)
        } catch _IsimIntentError.cancelled {
            NSLog("isim AppIntents: %@ cancelled", title)
            ch.write(["type": "result", "outcome": "cancelled", "dialog": ""])
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            NSLog("isim AppIntents: %@ failed: %@", title, message)
            ch.write(["type": "result", "outcome": "failure", "dialog": (error as? LocalizedError)?.errorDescription ?? "Sorry, there was a problem with \(appName).",
                      "error": message])
        }
    }
}
@_cdecl("isim_appintents_run_request") public func _isim_appintents_run_request(_ path: UnsafePointer<CChar>) {
    let p = String(cString: path)
    Task { @MainActor in await _IsimRunner.run(p) }
}

// MARK: - metadata (what the system reads)

@MainActor enum _IsimMetadata {
    static func colorName(_ c: ShortcutTileColor) -> String { "\(c)" }
    static func paramInfo(_ name: String, _ p: _IsimAnyParameter) async -> [String: Any] {
        let k = _IsimValues.kind(p._isimValueType)
        var d: [String: Any] = ["name": name, "title": p._isimTitle, "kind": k.name, "optional": p._isimOptional, "hasValue": p._isimHasValue]
        if let pr = p._isimPrompt { d["prompt"] = pr }
        if let v = p._isimCurrent { d["value"] = _IsimValues.describe(v) }
        let opts = await _IsimValues.options(k)
        if !opts.isEmpty { d["options"] = opts.prefix(50).map { $0.plist } }
        return d
    }
    static func intentInfo(_ t: any AppIntent.Type) async -> [String: Any] {
        let probe = t.init()
        var params: [[String: Any]] = []
        for (n, p) in _IsimReflection.parameters(of: probe) { params.append(await paramInfo(n, p)) }
        var d: [String: Any] = ["title": t.title.description, "openAppWhenRun": t.openAppWhenRun, "discoverable": t.isDiscoverable,
                                "authentication": ["alwaysAllowed", "requiresAuthentication", "requiresLocalDeviceAuthentication"][policyIndex(t.authenticationPolicy)],
                                "parameters": params, "widgetConfiguration": probe is any WidgetConfigurationIntent, "open": probe is any OpenIntent]
        if let desc = t.description { d["description"] = desc.text; if !desc.searchKeywords.isEmpty { d["keywords"] = desc.searchKeywords } }
        return d
    }
    static func policyIndex(_ p: IntentAuthenticationPolicy) -> Int { switch p { case .alwaysAllowed: return 0; case .requiresAuthentication: return 1; case .requiresLocalDeviceAuthentication: return 2 } }
    static func shortcutsInfo() async -> ([[String: Any]], String?) {
        var out: [[String: Any]] = []
        var color: String?
        var index = 0
        for prov in _IsimConformances.providers {
            color = color ?? colorName(prov.shortcutTileColor)
            for s in prov.appShortcuts {
                let t = type(of: s._intent)
                var d: [String: Any] = ["index": index, "intent": _isimTypeName(t), "title": t.title.description, "shortTitle": s._shortTitle ?? s.title,
                                        "phrases": s._phrases.map { $0() }]
                if let img = s._systemImageName { d["image"] = img }
                var preset: [String: String] = [:]
                for (n, p) in _IsimReflection.parameters(of: s._intent) where p._isimHasValue {
                    if let v = p._isimCurrent { preset[n] = (v as? any AppEntity).map { "\($0.id)" } ?? (v as? any AppEnum)?.rawValue ?? _IsimValues.describe(v) }
                }
                if !preset.isEmpty { d["params"] = preset }
                out.append(d)
                index += 1
            }
        }
        return (out, color)
    }
    static func write(_ out: String) async {
        let (shortcuts, color) = await shortcutsInfo()
        var intents: [String: Any] = [:]
        for t in _IsimConformances.intents { intents[_isimTypeName(t)] = await intentInfo(t) }
        var m: [String: Any] = ["linksAppIntents": true, "shortcuts": shortcuts, "intents": intents, "date": Date()]
        if let color { m["tileColor"] = color }
        (m as NSDictionary).write(toFile: out, atomically: true)
        NSLog("isim AppIntents: %ld App Shortcut(s), %ld intent(s)", shortcuts.count, intents.count)
    }
    /// updateAppShortcutParameters(): the values entity parameters of App Shortcut phrases can take, for the system
    static func updateParameters(_ shortcuts: [AppShortcut]) async {
        var values: [String: Any] = [:]
        for s in shortcuts {
            let t = type(of: s._intent), probe = t.init()
            for (n, p) in _IsimReflection.parameters(of: probe) {
                let k = _IsimValues.kind(p._isimValueType)
                guard case .entity = k else { continue }
                values[_isimTypeName(t) + "." + n] = await _IsimValues.options(k).map { $0.plist }
            }
        }
        let dir = (NSHomeDirectory() as NSString).appendingPathComponent("Library/isim")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        (["parameters": values, "date": Date()] as NSDictionary).write(toFile: (dir as NSString).appendingPathComponent("AppShortcutParameters.plist"), atomically: true)
        NSLog("isim AppIntents: App Shortcut parameters updated (%ld parameter(s))", values.count)
    }
}
@_cdecl("isim_appintents_list_main") public func _isim_appintents_list_main(_ path: UnsafePointer<CChar>) -> Int32 {
    guard let req = NSDictionary(contentsOfFile: String(cString: path)) as? [String: Any], let out = req["out"] as? String else { return 2 }
    Task { @MainActor in
        await _IsimMetadata.write(out)
        fflush(nil)
        exit(0)
    }
    while true { RunLoop.main.run(until: .distantFuture) }
}

/// the app's own App Shortcut for an intent type (SiriTipView), its first phrase with the app's name
@MainActor func _isimPhrase(for t: any AppIntent.Type) -> String? {
    let name = _isimTypeName(t)
    for prov in _IsimConformances.providers {
        for s in prov.appShortcuts where _isimTypeName(type(of: s._intent)) == name {
            guard let p = s._phrases.first?() else { continue }
            let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
            var out = p.replacingOccurrences(of: "${applicationName}", with: app)
            while let r = out.range(of: "${"), let e = out[r.upperBound...].firstIndex(of: "}") { out.replaceSubrange(r.lowerBound...e, with: "…") }
            return out
        }
    }
    return nil
}
