// isim SwiftUI: label, text field and toggle styles (`.labelStyle(.iconOnly / .titleOnly / custom)`,
// `.textFieldStyle(.roundedBorder / .plain)`, `.toggleStyle(.switch / .button / custom)`), `redacted(reason:)` /
// `unredacted()` / `privacySensitive()`, and `help(_:)` (no tooltips on iPhone: kept as the accessibility hint).
import UIKit

// MARK: - LabelStyle

public struct LabelStyleConfiguration {
    public struct Title: View, _PrimitiveView { let make: @MainActor (_Context) -> _Node; public var body: Never { fatalError() }; func _makeNode(_ ctx: _Context) -> _Node { make(ctx) } }
    public struct Icon: View, _PrimitiveView { let make: @MainActor (_Context) -> _Node; public var body: Never { fatalError() }; func _makeNode(_ ctx: _Context) -> _Node { make(ctx) } }
    public var title: Title
    public var icon: Icon
}
public protocol LabelStyle {
    associatedtype Body: View
    typealias Configuration = LabelStyleConfiguration
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body
}
public struct DefaultLabelStyle: LabelStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct IconOnlyLabelStyle: LabelStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.icon } }
public struct TitleOnlyLabelStyle: LabelStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.title } }
public struct TitleAndIconLabelStyle: LabelStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
extension LabelStyle where Self == DefaultLabelStyle { public static var automatic: DefaultLabelStyle { .init() } }
extension LabelStyle where Self == IconOnlyLabelStyle { public static var iconOnly: IconOnlyLabelStyle { .init() } }
extension LabelStyle where Self == TitleOnlyLabelStyle { public static var titleOnly: TitleOnlyLabelStyle { .init() } }
extension LabelStyle where Self == TitleAndIconLabelStyle { public static var titleAndIcon: TitleAndIconLabelStyle { .init() } }
/// nil: the default (title and icon side by side).
struct _LabelStyleKey: EnvironmentKey { static var defaultValue: (@MainActor (LabelStyleConfiguration) -> any View)? { nil } }
struct _LabelStyleKindKey: EnvironmentKey { static var defaultValue: Int { 0 } }
extension EnvironmentValues {
    var _labelStyle: (@MainActor (LabelStyleConfiguration) -> any View)? { get { self[_LabelStyleKey.self] } set { self[_LabelStyleKey.self] = newValue } }
    /// the stock style for controls that draw their own label (PasteButton): 0 title and icon, 1 title only, 2 icon only
    var _labelStyleKind: Int { get { self[_LabelStyleKindKey.self] } set { self[_LabelStyleKindKey.self] = newValue } }
}
extension View {
    public func labelStyle<S: LabelStyle>(_ style: S) -> some View {
        _env { e in
            if style is DefaultLabelStyle || style is TitleAndIconLabelStyle { e._labelStyle = nil }
            else { e._labelStyle = { style.makeBody(configuration: $0) } }
            e._labelStyleKind = style is TitleOnlyLabelStyle ? 1 : style is IconOnlyLabelStyle ? 2 : 0
        }
    }
}
/// Called by Label: a label style in the environment builds the label.
@MainActor func _styledLabel<T: View, I: View>(_ title: T, _ icon: I, _ ctx: _Context) -> _Node? {
    guard let style = ctx.environment._labelStyle else { return nil }
    let config = LabelStyleConfiguration(title: .init(make: { c in _resolve(title, c.with { $0._labelStyle = nil }) }),
                                         icon: .init(make: { c in _resolve(icon, c.with { $0._labelStyle = nil }) }))
    return _resolve(style(config), ctx.child("lstyle").with { $0._labelStyle = nil })
}

// MARK: - TextFieldStyle

public protocol TextFieldStyle {}
public struct DefaultTextFieldStyle: TextFieldStyle { public init() {} }
public struct PlainTextFieldStyle: TextFieldStyle { public init() {} }
public struct RoundedBorderTextFieldStyle: TextFieldStyle { public init() {} }
extension TextFieldStyle where Self == DefaultTextFieldStyle { public static var automatic: DefaultTextFieldStyle { .init() } }
extension TextFieldStyle where Self == PlainTextFieldStyle { public static var plain: PlainTextFieldStyle { .init() } }
extension TextFieldStyle where Self == RoundedBorderTextFieldStyle { public static var roundedBorder: RoundedBorderTextFieldStyle { .init() } }
extension View {
    /// `.roundedBorder` draws the field in a rounded border (UITextField's rounded-rect style).
    public func textFieldStyle<S: TextFieldStyle>(_ style: S) -> some View {
        _env { $0._textTraits.roundedBorder = style is RoundedBorderTextFieldStyle }
    }
}

// MARK: - ToggleStyle

public struct ToggleStyleConfiguration {
    public struct Label: View, _PrimitiveView { let make: @MainActor (_Context) -> _Node; public var body: Never { fatalError() }; func _makeNode(_ ctx: _Context) -> _Node { make(ctx) } }
    public let label: Label
    @Binding public var isOn: Bool
    public var isMixed: Bool = false
    init(label: Label, isOn: Binding<Bool>) { self.label = label; _isOn = isOn }
}
public protocol ToggleStyle {
    associatedtype Body: View
    typealias Configuration = ToggleStyleConfiguration
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body
}
public struct DefaultToggleStyle: ToggleStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct SwitchToggleStyle: ToggleStyle { public init() {}; public init(tint: Color) {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
/// A button that shows its on state with a tinted background.
public struct ButtonToggleStyle: ToggleStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { _ToggleButton(configuration: configuration) }
}
struct _ToggleButton: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\._tint) var tint
    var body: some View {
        let on = configuration.isOn
        let t = tint ?? .accentColor
        Button { configuration.$isOn.wrappedValue.toggle() } label: {
            configuration.label
                .foregroundStyle(on ? Color.white : t)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(on ? t : Color("fill") { .tertiarySystemFill }, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
extension ToggleStyle where Self == DefaultToggleStyle { public static var automatic: DefaultToggleStyle { .init() } }
extension ToggleStyle where Self == SwitchToggleStyle { public static var `switch`: SwitchToggleStyle { .init() } }
extension ToggleStyle where Self == ButtonToggleStyle { public static var button: ButtonToggleStyle { .init() } }
struct _ToggleStyleKey: EnvironmentKey { static var defaultValue: (@MainActor (ToggleStyleConfiguration) -> any View)? { nil } }
extension EnvironmentValues {
    var _toggleStyle: (@MainActor (ToggleStyleConfiguration) -> any View)? { get { self[_ToggleStyleKey.self] } set { self[_ToggleStyleKey.self] = newValue } }
}
extension View {
    public func toggleStyle<S: ToggleStyle>(_ style: S) -> some View {
        _env { e in
            if style is DefaultToggleStyle || style is SwitchToggleStyle { e._toggleStyle = nil }
            else { e._toggleStyle = { style.makeBody(configuration: $0) } }
        }
    }
}
/// Called by Toggle: a toggle style in the environment builds the toggle.
@MainActor func _styledToggle<L: View>(_ label: L, _ isOn: Binding<Bool>, _ ctx: _Context) -> _Node? {
    guard let style = ctx.environment._toggleStyle else { return nil }
    let config = ToggleStyleConfiguration(label: .init(make: { c in _resolve(label, c.with { $0._toggleStyle = nil }) }), isOn: isOn)
    return _resolve(style(config), ctx.child("tstyle").with { $0._toggleStyle = nil })
}

// MARK: - Redaction

public struct RedactionReasons: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let placeholder = RedactionReasons(rawValue: 1), privacy = RedactionReasons(rawValue: 2), invalidated = RedactionReasons(rawValue: 4)
}
struct _RedactionKey: EnvironmentKey { static var defaultValue: RedactionReasons { [] } }
struct _PrivacySensitiveKey: EnvironmentKey { static var defaultValue: Bool { false } }
extension EnvironmentValues {
    var _privacySensitive: Bool { get { self[_PrivacySensitiveKey.self] } set { self[_PrivacySensitiveKey.self] = newValue } }
    /// content drawn as placeholders: `.redacted(reason: .placeholder)`, or `.privacy` on privacySensitive content
    var _redactsContent: Bool { redactionReasons.contains(.placeholder) || (redactionReasons.contains(.privacy) && _privacySensitive) }
    public var redactionReasons: RedactionReasons { get { self[_RedactionKey.self] } set { self[_RedactionKey.self] = newValue } }
}
extension View {
    /// `.placeholder`: text inside is drawn as grey bars of the text's size.
    public func redacted(reason: RedactionReasons) -> some View { _env { $0.redactionReasons.formUnion(reason) } }
    public func unredacted() -> some View { _env { $0.redactionReasons = [] } }
    /// Marks content as private: it is redacted (text as grey bars, images as grey boxes) under `.redacted(reason: .privacy)`.
    public func privacySensitive(_ sensitive: Bool = true) -> some View { _env { $0._privacySensitive = sensitive } }
    /// Help text: iPhone shows no tooltips; kept for accessibility like iOS.
    public func help(_ text: Text) -> some View { accessibilityHint(text) }
    public func help(_ key: LocalizedStringKey) -> some View { accessibilityHint(Text(key)) }
    @_disfavoredOverload public func help<S: StringProtocol>(_ text: S) -> some View { accessibilityHint(Text(text)) }
}
/// A redacted text: a rounded grey bar per line.
final class _RedactedTextNode: _WrapperNode {
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { UIView() }
        v.backgroundColor = UIColor.systemGray4
        v.layer.cornerRadius = 4
        v.isUserInteractionEnabled = false
        return v
    }
    override func mountChildren(_ g: _Graph, in view: UIView) {}
}
