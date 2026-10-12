// isim WidgetKit: Control Center controls (iOS 18 ControlWidget). Adapted.
//
// A ControlWidget lives in the widget extension's WidgetBundle (or is its @main). Like widgets, the extension runs as a
// short-lived helper process the home screen starts (ISIM_WIDGET_REQUEST); for controls the request's mode is
//   controls      evaluate every control (its value provider's currentValue, else previewValue; the template the
//                 content closure builds) and describe it for the system in <out>/controls.txt
//   control-run   run the tapped control's action in this process (a toggle's SetValueIntent gets the new value
//                 first), then describe the controls again
// The system (the shell) draws the controls itself in the iOS style: the label's SF Symbol and title (found by laying
// out the label view and reading its text and symbol), the value text, the tint when on. Control Center's edit mode
// lists them in its "Add a Control" gallery; they can also go on the Lock Screen and the Action button.
// Not on isim: per-control configuration UI (AppIntentControlConfiguration uses the intent's default parameters),
// push-updated controls (ControlPushHandler), controls in other apps' Shortcuts.
import Foundation
import UIKit
import SwiftUI
import AppIntents
import isim_host

// MARK: - protocols

@available(iOS 18.0, *)
public protocol ControlWidget {
    associatedtype Body: ControlWidgetConfiguration
    @ControlWidgetConfigurationBuilder var body: Body { get }
    init()
}
@available(iOS 18.0, *)
public protocol ControlWidgetConfiguration {}
@available(iOS 18.0, *)
public protocol ControlWidgetTemplate {}

@available(iOS 18.0, *)
@resultBuilder public struct ControlWidgetConfigurationBuilder {
    public static func buildBlock<C: ControlWidgetConfiguration>(_ c: C) -> C { c }
}
@available(iOS 18.0, *)
@resultBuilder public struct ControlWidgetTemplateBuilder {
    public static func buildBlock<T: ControlWidgetTemplate>(_ t: T) -> T { t }
}

/// A control's value (StaticControlConfiguration's provider).
@available(iOS 18.0, *)
public protocol ControlValueProvider: Sendable {
    associatedtype Value
    var previewValue: Value { get }
    func currentValue() async throws -> Value
}
/// A control's value for a configuration intent (AppIntentControlConfiguration's provider).
@available(iOS 18.0, *)
public protocol AppIntentControlValueProvider: Sendable {
    associatedtype Value
    associatedtype Configuration: ControlConfigurationIntent
    func previewValue(configuration: Configuration) -> Value
    func currentValue(configuration: Configuration) async throws -> Value
}

// MARK: - what the system needs of a control

/// a built template: what it shows and what it does
struct _CWTemplate {
    var toggle = false, isOn = false
    var label: AnyView = AnyView(EmptyView()), valueLabel: AnyView?
    var tint: Color?
    var run: @MainActor (_ newValue: Bool) async -> Void = { _ in }
}
protocol _CWTemplateConvertible { @MainActor func _template() -> _CWTemplate }
struct _CWSpec {
    var kind: String
    var name = "", description = ""
    var make: @MainActor () async -> (_CWTemplate, hint: String?)
}
protocol _CWConfig { var _controls: [_CWSpec] { get } }
/// the label modifiers record what they are given while the content closure builds the template
@MainActor enum _CWCapture { static var hint: String?; static var status: String? }

// MARK: - configurations

@available(iOS 18.0, *)
public struct StaticControlConfiguration<Content: ControlWidgetTemplate>: ControlWidgetConfiguration, _CWConfig {
    let spec: _CWSpec
    public init(kind: String, @ControlWidgetTemplateBuilder content: @escaping () -> Content) {
        spec = _CWSpec(kind: kind) { _CWHost.build { content() } }
    }
    public init<Provider: ControlValueProvider>(kind: String, provider: Provider, @ControlWidgetTemplateBuilder content: @escaping (Provider.Value) -> Content) {
        spec = _CWSpec(kind: kind) {
            let v: Provider.Value
            do { v = try await provider.currentValue() } catch { NSLog("isim WidgetKit: control %@: currentValue failed (%@); using previewValue", kind, "\(error)"); v = provider.previewValue }
            return _CWHost.build { content(v) }
        }
    }
    var _controls: [_CWSpec] { [spec] }
}
@available(iOS 18.0, *)
public struct AppIntentControlConfiguration<Intent: ControlConfigurationIntent, Content: ControlWidgetTemplate>: ControlWidgetConfiguration, _CWConfig {
    let spec: _CWSpec
    /// isim: the intent's default parameters (no per-control configuration UI)
    public init<Provider: AppIntentControlValueProvider>(kind: String, intent: Intent.Type = Intent.self, provider: Provider,
                                                         @ControlWidgetTemplateBuilder content: @escaping (Provider.Value) -> Content) where Provider.Configuration == Intent {
        spec = _CWSpec(kind: kind) {
            let cfg = Intent(), v: Provider.Value
            do { v = try await provider.currentValue(configuration: cfg) } catch { v = provider.previewValue(configuration: cfg) }
            return _CWHost.build { content(v) }
        }
    }
    public init(kind: String, intent: Intent.Type = Intent.self, @ControlWidgetTemplateBuilder content: @escaping (Intent) -> Content) {
        spec = _CWSpec(kind: kind) { _CWHost.build { content(Intent()) } }
    }
    var _controls: [_CWSpec] { [spec] }
}
@available(iOS 18.0, *)
public struct _ModifiedControlConfiguration<C: ControlWidgetConfiguration>: ControlWidgetConfiguration, _CWConfig {
    let base: C; let edit: (inout _CWSpec) -> Void
    var _controls: [_CWSpec] { ((base as? _CWConfig)?._controls ?? []).map { var s = $0; edit(&s); return s } }
}
@available(iOS 18.0, *)
extension ControlWidgetConfiguration {
    /// the name the "Add a Control" gallery shows
    public func displayName(_ name: LocalizedStringResource) -> some ControlWidgetConfiguration { _ModifiedControlConfiguration(base: self) { $0.name = String(localized: name) } }
    public func description(_ text: LocalizedStringResource) -> some ControlWidgetConfiguration { _ModifiedControlConfiguration(base: self) { $0.description = String(localized: text) } }
    /// isim: controls use their intent's default parameters (no configuration prompt)
    public func promptsForUserConfiguration() -> some ControlWidgetConfiguration { self }
}

// MARK: - templates

@available(iOS 18.0, *)
public struct ControlWidgetButton<Label: View, ActionLabel: View, Action: AppIntent>: ControlWidgetTemplate, _CWTemplateConvertible {
    let action: Action, label: Label, actionLabel: ((Bool) -> ActionLabel)?
    public init(action: Action, @ViewBuilder label: () -> Label) where ActionLabel == EmptyView { self.action = action; self.label = label(); actionLabel = nil }
    public init(action: Action, @ViewBuilder label: () -> Label, @ViewBuilder actionLabel: @escaping (Bool) -> ActionLabel) {
        self.action = action; self.label = label(); self.actionLabel = actionLabel
    }
    func _template() -> _CWTemplate {
        let a = action
        return _CWTemplate(toggle: false, isOn: false, label: AnyView(label), valueLabel: actionLabel.map { AnyView($0(false)) }) { _ in await _isimPerform(a) }
    }
}
@available(iOS 18.0, *)
public struct ControlWidgetToggle<Label: View, ValueLabel: View, Action: SetValueIntent>: ControlWidgetTemplate, _CWTemplateConvertible where Action.ValueType == Bool {
    let isOn: Bool, action: Action, label: Label, valueLabel: ((Bool) -> ValueLabel)?
    public init(isOn: Bool, action: Action, @ViewBuilder label: () -> Label) where ValueLabel == EmptyView {
        self.isOn = isOn; self.action = action; self.label = label(); valueLabel = nil
    }
    public init(isOn: Bool, action: Action, @ViewBuilder label: () -> Label, @ViewBuilder valueLabel: @escaping (Bool) -> ValueLabel) {
        self.isOn = isOn; self.action = action; self.label = label(); self.valueLabel = valueLabel
    }
    public init(_ titleKey: LocalizedStringKey, isOn: Bool, action: Action, @ViewBuilder valueLabel: @escaping (Bool) -> ValueLabel) where Label == Text {
        self.init(isOn: isOn, action: action, label: { Text(titleKey) }, valueLabel: valueLabel)
    }
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, isOn: Bool, action: Action, @ViewBuilder valueLabel: @escaping (Bool) -> ValueLabel) where Label == Text {
        self.init(isOn: isOn, action: action, label: { Text(title) }, valueLabel: valueLabel)
    }
    public init(_ titleKey: LocalizedStringKey, systemImage: String, isOn: Bool, action: Action) where Label == SwiftUI.Label<Text, Image>, ValueLabel == EmptyView {
        self.init(isOn: isOn, action: action) { SwiftUI.Label(titleKey, systemImage: systemImage) }
    }
    func _template() -> _CWTemplate {
        let a = action
        return _CWTemplate(toggle: true, isOn: isOn, label: AnyView(label), valueLabel: valueLabel.map { AnyView($0(isOn)) }) { v in
            var intent = a
            intent.value = v
            await _isimPerform(intent)
        }
    }
}
@available(iOS 18.0, *)
public struct _TintedControlTemplate<T: ControlWidgetTemplate>: ControlWidgetTemplate, _CWTemplateConvertible {
    let base: T, tint: Color?
    func _template() -> _CWTemplate { var t = (base as? _CWTemplateConvertible)?._template() ?? _CWTemplate(); t.tint = tint; return t }
}
@available(iOS 18.0, *)
extension ControlWidgetTemplate {
    /// the colour of the control's symbol (and on-state) when it is on
    public func tint(_ color: Color?) -> some ControlWidgetTemplate { _TintedControlTemplate(base: self, tint: color) }
}
extension View {
    /// what the system says the control does (the Action button and Lock Screen show it)
    @available(iOS 18.0, *)
    public func controlWidgetActionHint(_ hint: LocalizedStringKey) -> some View { _CWHost.captureHint(hint); return self }
    @available(iOS 18.0, *) @_disfavoredOverload
    public func controlWidgetActionHint<S: StringProtocol>(_ hint: S) -> some View { _CWHost.captureHint(String(hint)); return self }
    @available(iOS 18.0, *)
    public func controlWidgetActionHint(_ hint: Text) -> some View { _CWHost.captureHint(hint); return self }
    /// a status the system shows briefly after the action
    @available(iOS 18.0, *)
    public func controlWidgetStatus(_ status: LocalizedStringKey) -> some View { MainActor.assumeIsolated { _CWCapture.status = _CWHost.text(of: Text(status)) }; return self }
}

// MARK: - ControlWidget in a WidgetBundle

@available(iOS 18.0, *)
public struct _CWBox: WidgetConfiguration, _WKConfig, _CWConfig { let specs: [_CWSpec]; var _controls: [_CWSpec] { specs } }
/// a ControlWidget as a member of a WidgetBundle
@available(iOS 18.0, *)
public struct _ControlWidgetAdapter<C: ControlWidget>: Widget {
    let control: C
    public init() { control = C() }
    init(_ c: C) { control = c }
    public var body: _CWBox { _CWBox(specs: (control.body as? _CWConfig)?._controls ?? []) }
}
/// a widget whose type is erased (an `if` or `if #available` in a WidgetBundle)
public struct _AnyWidget: Widget {
    let config: (any WidgetConfiguration)?
    public init() { config = nil }
    init(_ c: (any WidgetConfiguration)?) { config = c }
    public var body: _WidgetList { _WidgetList(items: config.map { [$0] } ?? []) }
}
extension WidgetBundleBuilder {
    public static func buildExpression<W: Widget>(_ w: W) -> W { w }
    @available(iOS 18.0, *)
    public static func buildExpression<C: ControlWidget>(_ c: C) -> _ControlWidgetAdapter<C> { _ControlWidgetAdapter(c) }
    public static func buildOptional(_ w: _AnyWidget?) -> _AnyWidget { w ?? _AnyWidget(nil) }
    @_disfavoredOverload public static func buildOptional<W: Widget>(_ w: W?) -> _AnyWidget { _AnyWidget(w?.body) }
    public static func buildEither<W: Widget>(first w: W) -> _AnyWidget { _AnyWidget(w.body) }
    public static func buildEither<W: Widget>(second w: W) -> _AnyWidget { _AnyWidget(w.body) }
    public static func buildLimitedAvailability<W: Widget>(_ w: W) -> _AnyWidget { _AnyWidget(w.body) }
}
@available(iOS 18.0, *)
extension ControlWidget {
    /// a control as the extension's only entry point
    @MainActor public static func main() { _WKHost.run([_CWBox(specs: (Self().body as? _CWConfig)?._controls ?? [])]) }
}

// MARK: - ControlCenter

@available(iOS 18.0, *)
public struct ControlInfo: Sendable, Hashable, CustomStringConvertible {
    public let kind: String
    public var description: String { "ControlInfo(kind: \(kind))" }
}
@available(iOS 18.0, *)
public final class ControlCenter: @unchecked Sendable {
    public static let shared = ControlCenter()
    /// asks the system for the controls' values again (it runs the extension)
    public func reloadControls(ofKind kind: String) { isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "control-reload", nil, kind); NSLog("isim WidgetKit: reload controls of %@", kind) }
    public func reloadAllControls() { isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "control-reload", nil, "*"); NSLog("isim WidgetKit: reload all controls") }
    /// this app's controls the person added (Control Center, Lock Screen, Action button)
    public func currentControls() async throws -> [ControlInfo] {
        let data = ProcessInfo.processInfo.environment["ISIM_DATA"] ?? ""
        var app = Bundle.main.bundlePath
        if app.hasSuffix(".appex"), let r = app.range(of: ".app/PlugIns/") { app = String(app[..<r.lowerBound]) + ".app" }
        let me = (app as NSString).lastPathComponent
        var kinds: [String] = []
        for file in ["ControlCenter.txt", "LockScreenControls.txt", "ActionButton.txt"] {
            let text = (try? String(contentsOfFile: data + "/Library/isim/" + file, encoding: .utf8)) ?? ""
            for line in text.split(separator: "\n") {
                let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                if f.count >= 3, f[0] == "app", (f[1] as NSString).lastPathComponent == me, !kinds.contains(f[2]) { kinds.append(f[2]) }
            }
        }
        return kinds.map { ControlInfo(kind: $0) }
    }
}

// MARK: - the extension process

@MainActor enum _CWHost {
    @available(iOS 18.0, *)
    static func build<T: ControlWidgetTemplate>(_ content: () -> T) -> (_CWTemplate, hint: String?) {
        _CWCapture.hint = nil; _CWCapture.status = nil
        let t = content()
        return ((t as? _CWTemplateConvertible)?._template() ?? _CWTemplate(), _CWCapture.hint)
    }
    nonisolated static func captureHint(_ k: LocalizedStringKey) { MainActor.assumeIsolated { _CWCapture.hint = text(of: Text(k)) } }
    nonisolated static func captureHint(_ s: String) { MainActor.assumeIsolated { _CWCapture.hint = s } }
    nonisolated static func captureHint(_ t: Text) { MainActor.assumeIsolated { _CWCapture.hint = text(of: t) } }
    /// the texts and the first SF Symbol a view shows (laid out, not drawn)
    static func describe(_ v: AnyView) -> (texts: [String], symbol: String?) {
        let host = UIHostingController(rootView: v)
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 120)
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        var texts: [String] = [], symbol: String?
        func walk(_ u: UIView) {
            if let l = u as? UILabel, let t = l.text, !t.isEmpty { texts.append(t) }
            let sel = NSSelectorFromString("_isim_symbolName")             /* UIImage(systemName:) remembers its name (isim UIKit) */
            if symbol == nil, let iv = u as? UIImageView, let img = iv.image, img.responds(to: sel), let s = img.perform(sel).takeUnretainedValue() as? String { symbol = s }
            for s in u.subviews { walk(s) }
        }
        walk(host.view)
        return (texts, symbol)
    }
    static func text(of t: Text) -> String { describe(AnyView(t)).texts.joined(separator: " ") }
    static func hex(_ c: Color?) -> String {
        guard let c else { return "" }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard c.uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return "" }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    static func controls(_ configs: [_WKConfig]) -> [_CWSpec] {
        func walk(_ c: Any) -> [_CWSpec] {
            if let cw = c as? _CWConfig { return cw._controls }
            if let l = c as? _WidgetList { return l.items.flatMap { walk($0) } }
            return []
        }
        return configs.flatMap { walk($0) }
    }
    /// one line per control: kind, name, type, symbol, title, value, tint, on, action hint, description (separated by 0x1e)
    static func describeAll(_ specs: [_CWSpec], out: String) async {
        var lines: [String] = []
        for s in specs {
            let (t, hint) = await s.make()
            let label = describe(t.label), value = t.valueLabel.map { describe($0) }
            let symbol = value?.symbol ?? label.symbol ?? (t.toggle ? "switch.2" : "circle")
            let title = label.texts.first ?? s.name
            var valueText = value?.texts.joined(separator: " ") ?? ""
            if valueText.isEmpty && t.toggle { valueText = t.isOn ? "On" : "Off" }
            let clean = { (x: String) in x.replacingOccurrences(of: "\u{1e}", with: " ").replacingOccurrences(of: "\n", with: " ") }
            let fields = [s.kind, s.name.isEmpty ? title : s.name, t.toggle ? "toggle" : "button", symbol, title, valueText, hex(t.tint), t.isOn ? "1" : "0", hint ?? "", s.description]
            lines.append("control=" + fields.map(clean).joined(separator: "\u{1e}"))
            NSLog("isim WidgetKit: control %@ (%@): %@ %@%@", s.kind, t.toggle ? "toggle" : "button", title, valueText, t.toggle ? (t.isOn ? " [on]" : " [off]") : "")
        }
        try? (lines.joined(separator: "\n") + "\n").write(toFile: (out as NSString).appendingPathComponent("controls.txt"), atomically: true, encoding: .utf8)
        NSLog("isim WidgetKit: %ld control(s)", specs.count)
    }
    static func handle(mode: String, request req: [String: Any], out: String) async {
        let specs = controls(_WKHost.configs)
        switch mode {
        case "controls":
            await describeAll(specs, out: out)
        case "control-run":
            let kind = req["control"] as? String ?? ""
            guard let s = specs.first(where: { $0.kind == kind }) else { NSLog("isim WidgetKit: no control of kind %@", kind); await describeAll(specs, out: out); return }
            let (t, _) = await s.make()
            let newValue = (req["value"] as? Bool) ?? !t.isOn
            NSLog("isim WidgetKit: running control %@%@", kind, t.toggle ? (newValue ? " (turn on)" : " (turn off)") : "")
            _IsimIntentControls.running += 1
            await t.run(newValue)
            _IsimIntentControls.running -= 1
            await describeAll(specs, out: out)
        default:
            NSLog("isim WidgetKit: unknown request %@", mode)
        }
    }
}
