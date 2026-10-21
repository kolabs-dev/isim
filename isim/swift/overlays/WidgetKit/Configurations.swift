// isim WidgetKit: more ways to configure widgets and Live Activities.
// - IntentConfiguration / IntentTimelineProvider (iOS 14): a widget configured by a SiriKit custom intent (an INIntent
//   subclass from an .intentdefinition). Edit Widget lists the intent's parameters from the definition in the extension's
//   bundle (enums with their cases, Booleans, strings, numbers, custom types by display string), or from the class's
//   @NSManaged properties when the bundle has none; the chosen values are set on the intent the provider gets.
// - IntentRecommendation / AppIntentRecommendation and recommendations(): preconfigured intents. Adapted: listed with the
//   extension's widgets (the log names them); on iOS the system shows them where a widget cannot be configured
//   (watchOS), which isim does not have.
// - WidgetAccentedRenderingMode (iOS 18): how an Image draws on the tinted Home Screen (renderingMode .accented): in full
//   colour, desaturated, desaturated in the tint, or in the tint (like widgetAccentable).
// - ActivityFamily, supplementalActivityFamilies(_:) and EnvironmentValues.activityFamily (iOS 18): a Live Activity is
//   drawn .medium on the Lock Screen; one that also supports .small is drawn at the small size too (Apple Watch's Smart
//   Stack, CarPlay: isim has neither, so the presentation is saved as small.png next to the others).
// - WidgetPushHandler / WidgetPushInfo / pushHandler(_:) (iOS 26): the extension's handler gets a push token for its
//   widgets; a push with "apns-push-type": "widgets" (`push BUNDLE FILE`) reloads them, like Apple's push service.
import Foundation
import SwiftUI
import AppIntents
import Intents
import ObjectiveC

// MARK: - SiriKit intent configuration

public protocol IntentTimelineProvider {
    associatedtype Entry: TimelineEntry
    associatedtype Intent: INIntent
    typealias Context = TimelineProviderContext
    func placeholder(in context: Context) -> Entry
    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void)
    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void)
    @available(iOS 16.0, *)
    func recommendations() -> [IntentRecommendation<Intent>]
}
extension IntentTimelineProvider {
    @available(iOS 16.0, *)
    public func recommendations() -> [IntentRecommendation<Intent>] { [] }
}

/// a preconfigured SiriKit intent and its description
@available(iOS 16.0, *)
public struct IntentRecommendation<T: INIntent> {
    let intent: T
    let text: String
    public init(intent: T, description: LocalizedStringKey) { self.intent = intent; text = _wkKeyText(description) }
    public init(intent: T, description: Text) { self.intent = intent; text = _wkText(description) }
    public init<S: StringProtocol>(intent: T, description: S) { self.intent = intent; text = String(description) }
    public init(intent: T, description: LocalizedStringResource) { self.intent = intent; text = String(localized: description) }
}
/// a preconfigured widget configuration intent and its description
@available(iOS 16.0, *)
public struct AppIntentRecommendation<Intent: WidgetConfigurationIntent> {
    let intent: Intent
    let text: String
    public init(intent: Intent, description: LocalizedStringKey) { self.intent = intent; text = _wkKeyText(description) }
    public init(intent: Intent, description: Text) { self.intent = intent; text = _wkText(description) }
    public init(intent: Intent, description: some StringProtocol) { self.intent = intent; text = String(description) }
    public init(intent: Intent, description: LocalizedStringResource) { self.intent = intent; text = String(localized: description) }
}
extension AppIntentTimelineProvider {
    @available(iOS 16.0, *)
    public func recommendations() -> [AppIntentRecommendation<Intent>] { [] }
}
func _wkKeyText(_ k: LocalizedStringKey) -> String {
    let s = "\(k)"                                       /* LocalizedStringKey(key: "…", …) */
    guard let r = s.range(of: "key: \""), let e = s[r.upperBound...].firstIndex(of: "\"") else { return s }
    return String(s[r.upperBound..<e])
}
func _wkText(_ t: Text) -> String {
    let m = Mirror(reflecting: t)
    for c in m.children { if let s = c.value as? String { return s } }
    return "\(t)"
}

public struct IntentConfiguration<Intent: INIntent, Content: View>: WidgetConfiguration, _WKConfig {
    var spec: _WKWidgetSpec
    public init<Provider: IntentTimelineProvider>(kind: String, intent: Intent.Type, provider: Provider,
                                                  @ViewBuilder content: @escaping (Provider.Entry) -> Content) where Provider.Intent == Intent {
        spec = _WKWidgetSpec(kind: kind, timeline: { ctx, config in      /* the configuration chosen in Edit Widget (else the intent's defaults) */
            let intent = _wkINIntent(Intent.self, config)
            let tl: Timeline<Provider.Entry> = await withCheckedContinuation { k in provider.getTimeline(for: intent, in: ctx) { k.resume(returning: $0) } }
            return (tl.entries.map { e in _wkEntry(e.date) { AnyView(content(e)) } }, tl.policy)
        }, placeholder: { ctx in AnyView(content(provider.placeholder(in: ctx))) }, snapshot: { ctx, config in
            let intent = _wkINIntent(Intent.self, config)
            let e: Provider.Entry = await withCheckedContinuation { k in provider.getSnapshot(for: intent, in: ctx) { k.resume(returning: $0) } }
            return _wkEntry(e.date) { AnyView(content(e)) }
        }, params: { config in
            let d = _wkDefinition(Intent.self)
            return (d?["INIntentTitle"] as? String ?? NSStringFromClass(Intent.self), d?["INIntentDescription"] as? String ?? "",
                    _wkINParameters(_wkINIntent(Intent.self, config)))
        }, render: { e in (e as? Provider.Entry).map { AnyView(content($0)) } })
        if #available(iOS 16.0, *) { spec.recommendations = provider.recommendations().map(\.text) }
    }
    var _widgets: [_WKWidgetSpec] { [spec] }
}

/// the intent definition (from the .intentdefinition files in the extension's bundle) of an INIntent subclass
func _wkDefinition(_ cls: AnyClass) -> [String: Any]? {
    let name = NSStringFromClass(cls)
    for path in Bundle.main.paths(forResourcesOfType: "intentdefinition", inDirectory: nil) {
        guard let d = NSDictionary(contentsOfFile: path) as? [String: Any] else { continue }
        for i in d["INIntents"] as? [[String: Any]] ?? [] {
            let cn = i["INIntentClassName"] as? String ?? ((i["INIntentName"] as? String ?? "") + "Intent")
            if cn == name || name.hasSuffix("." + cn) {
                var r = i; r["$enums"] = d["INEnums"]; return r
            }
        }
    }
    return nil
}
/// a stored value of an intent (the Intents framework keeps @NSManaged parameters with the object)
func _wkGet(_ o: NSObject, _ key: String) -> Any? {
    let sel = NSSelectorFromString("_get:")
    guard o.responds(to: sel) else { return o.value(forKey: key) }
    return o.perform(sel, with: key)?.takeUnretainedValue()
}
func _wkSetValue(_ o: NSObject, _ value: Any?, _ key: String) {
    let sel = NSSelectorFromString("_set:forKey:")
    if o.responds(to: sel) { _ = o.perform(sel, with: value, with: key) } else { o.setValue(value, forKey: key) }
}
/// the parameters Edit Widget shows: from the definition, else the class's properties
struct _WKINParam { let name, title, kind: String; let choices: [[String]]; let objectType: String? }
func _wkINParamList(_ cls: AnyClass) -> [_WKINParam] {
    if let d = _wkDefinition(cls) {
        let enums = d["$enums"] as? [[String: Any]] ?? []
        return (d["INIntentParameters"] as? [[String: Any]] ?? []).compactMap { p in
            guard let name = p["INIntentParameterName"] as? String else { return nil }
            let title = p["INIntentParameterDisplayName"] as? String ?? name.capitalized
            if let e = p["INIntentParameterEnumType"] as? String {
                let values = enums.first { $0["INEnumName"] as? String == e }?["INEnumValues"] as? [[String: Any]] ?? []
                let choices = values.compactMap { v -> [String]? in
                    guard let i = v["INEnumValueIndex"] as? Int, i != 0 else { return nil }
                    return [String(i), v["INEnumValueDisplayName"] as? String ?? v["INEnumValueName"] as? String ?? String(i)]
                }
                return _WKINParam(name: name, title: title, kind: "enum", choices: choices, objectType: nil)
            }
            let kind = ["Boolean": "bool", "Integer": "int", "Decimal": "double", "Object": "string"][p["INIntentParameterType"] as? String ?? ""] ?? "string"
            return _WKINParam(name: name, title: title, kind: kind, choices: [], objectType: p["INIntentParameterObjectType"] as? String)
        }
    }
    var out: [_WKINParam] = [], n: UInt32 = 0
    guard let props = class_copyPropertyList(cls, &n) else { return [] }
    defer { free(props) }
    for i in 0..<Int(n) {
        let name = String(cString: property_getName(props[i]))
        let attrs = property_getAttributes(props[i]).map { String(cString: $0) } ?? ""
        let kind = attrs.hasPrefix("TB") || attrs.hasPrefix("Tc") ? "bool" : attrs.hasPrefix("T@\"NSString\"") ? "string"
                 : attrs.hasPrefix("Td") || attrs.hasPrefix("Tf") ? "double" : attrs.hasPrefix("T@") ? "string" : "int"
        out.append(_WKINParam(name: name, title: name.prefix(1).uppercased() + name.dropFirst(), kind: kind, choices: [], objectType: nil))
    }
    return out
}
/// a configuration intent with the values chosen in Edit Widget (by parameter name)
func _wkINIntent<I: INIntent>(_ t: I.Type, _ config: [String: Any]) -> I {
    let intent = I()
    guard !config.isEmpty else { return intent }
    for p in _wkINParamList(t) {
        guard let raw = config[p.name] else { continue }
        let s = "\(raw)"
        var v: Any?
        switch p.kind {
        case "bool": v = NSNumber(value: s == "true" || s == "1")
        case "int", "enum": v = Int(s).map { NSNumber(value: $0) }
        case "double": v = Double(s).map { NSNumber(value: $0) }
        default:
            if let ot = p.objectType, let c = NSClassFromString(ot) as? INObject.Type { v = c.init(identifier: s, display: s) }
            else if let ot = p.objectType, let c = (Bundle.main.classNamed(ot) ?? _wkSwiftClass(ot)) as? INObject.Type { v = c.init(identifier: s, display: s) }
            else { v = s }
        }
        _wkSetValue(intent, v, p.name)
    }
    return intent
}
func _wkSwiftClass(_ name: String) -> AnyClass? {
    let module = (Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? "").replacingOccurrences(of: " ", with: "_")
    return NSClassFromString("\(module).\(name)")
}
@MainActor func _wkINParameters(_ intent: INIntent) -> [[String: Any]] {
    _wkINParamList(type(of: intent)).map { p in
        var info: [String: Any] = ["name": p.name, "title": p.title, "kind": p.kind, "optional": true]
        if !p.choices.isEmpty { info["choices"] = p.choices }
        let v = _wkGet(intent, p.name)
        if let o = v as? INObject { info["value"] = o.displayString }
        else if let n = v as? NSNumber { info["value"] = p.kind == "bool" ? (n.boolValue ? "true" : "false") : n.stringValue }
        else if let x = v { info["value"] = "\(x)" }
        return info
    }
}

// MARK: - accented images (the tinted Home Screen)

@available(iOS 18.0, *)
public struct WidgetAccentedRenderingMode: Hashable, Sendable {
    let raw: Int
    /// in the tint, like widgetAccentable content
    public static let accented = WidgetAccentedRenderingMode(raw: 0)
    /// greyscale
    public static let desaturated = WidgetAccentedRenderingMode(raw: 1)
    /// greyscale, then in the tint
    public static let accentedDesaturated = WidgetAccentedRenderingMode(raw: 2)
    /// as drawn, in full colour
    public static let fullColor = WidgetAccentedRenderingMode(raw: 3)
}
extension Image {
    /// how the image draws in the accented rendering (adapted: the host draws the widget once more without these images
    /// and puts their pixels back in the mode's colours)
    @available(iOS 18.0, *)
    public func widgetAccentedRenderingMode(_ renderingMode: WidgetAccentedRenderingMode?) -> some View {
        guard let m = renderingMode else { return self.opacity(1) }
        if m == .accented { return self.opacity(_WKHost.hidingAccentable ? 0 : 1) }
        _WKHost.usedImageModes.insert(m.raw)
        return self.opacity(_WKHost.hidingImageModes.contains(m.raw) ? 0 : 1)
    }
}

// MARK: - Live Activity families

@available(iOS 18.0, *)
public enum ActivityFamily: Sendable, Hashable {
    /// Apple Watch's Smart Stack, CarPlay
    case small
    /// the Lock Screen
    case medium
}
struct _ActivityFamilyKey: EnvironmentKey { static var defaultValue: String { "medium" } }
extension EnvironmentValues {
    var _isimActivityFamily: String { get { self[_ActivityFamilyKey.self] } set { self[_ActivityFamilyKey.self] = newValue } }
    @available(iOS 18.0, *)
    public var activityFamily: ActivityFamily {
        get { self[_ActivityFamilyKey.self] == "small" ? .small : .medium }
        set { self[_ActivityFamilyKey.self] = newValue == .small ? "small" : "medium" }
    }
}
extension WidgetConfiguration {
    /// the Live Activity's sizes besides the Lock Screen's (.medium)
    @available(iOS 18.0, *)
    public func supplementalActivityFamilies(_ families: [ActivityFamily]) -> some WidgetConfiguration {
        _ModifiedConfiguration(base: self, activity: { $0.families = Set(families.map { $0 == .small ? "small" : "medium" }).union(["medium"]) })
    }
}

// MARK: - widget pushes

@available(iOS 26.0, *)
public struct WidgetPushInfo: Sendable, Hashable {
    /// the device token the app's server sends widget pushes to
    public let token: Data
}
@available(iOS 26.0, *)
public protocol WidgetPushHandler {
    init()
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo])
}
extension WidgetConfiguration {
    /// the handler that gets the push token for this widget; pushes with the `widgets` push type reload it
    @available(iOS 26.0, *)
    public func pushHandler(_ handler: any WidgetPushHandler.Type) -> some WidgetConfiguration {
        _ModifiedConfiguration(base: self) { $0.pushHandler = { h in
            let token = _wkPushToken()
            handler.init().pushTokenDidChange(WidgetPushInfo(token: token), widgets: h)
            return token
        } }
    }
}
/// the extension's widget push token: stable for the app on this device (32 bytes from its bundle identifier)
func _wkPushToken() -> Data {
    let id = Array(((Bundle.main.bundleIdentifier ?? "") + "|widgets").utf8)
    var out = Data()
    for salt in 0..<4 {                                   /* FNV-1a, 4 x 64 bits */
        var h: UInt64 = 0xcbf29ce484222325 &+ UInt64(salt) &* 0x100000001b3
        for b in id { h ^= UInt64(b); h = h &* 0x100000001b3 }
        withUnsafeBytes(of: h.bigEndian) { out.append(contentsOf: $0) }
    }
    return out
}
