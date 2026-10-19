// isim SwiftUI: small iOS 17 / 18 view options — badgeProminence (List row badges), buttonRepeatBehavior,
// backgroundStyle (what `.background` stands for), menuIndicator, labelsVisibility, navigationLinkIndicatorVisibility,
// toolbarVisibility / toolbarBackgroundVisibility (Navigation+More.swift), menuStyle (custom MenuStyle bodies, `.button`),
// textEditorStyle, Apple Pencil double-tap and squeeze (onPencilDoubleTap / onPencilSqueeze on a UIPencilInteraction),
// and the options iOS keeps but does not show: geometryGroup, dialogSeverity, dialogIcon, typesettingLanguage.
import UIKit

// MARK: - Environment (internal keys; the public properties carry Apple's availability)

struct _BadgeProminenceKey: EnvironmentKey { static var defaultValue: Int { 0 } }
struct _ButtonRepeatKey: EnvironmentKey { static var defaultValue: Int { 0 } }
struct _BackgroundStyleKey: EnvironmentKey { static var defaultValue: AnyShapeStyle? { nil } }
struct _MenuIndicatorKey: EnvironmentKey { static var defaultValue: Visibility { .automatic } }
struct _NavigationLinkIndicatorKey: EnvironmentKey { static var defaultValue: Visibility { .automatic } }
struct _DialogSeverityKey: EnvironmentKey { static var defaultValue: Int { 0 } }
struct _DialogIconKey: EnvironmentKey { static var defaultValue: Image? { nil } }
struct _MenuStyleKey: EnvironmentKey { static var defaultValue: _AnyMenuStyle? { nil } }
extension EnvironmentValues {
    /// badgeProminence: 0 standard, 1 increased, 2 decreased
    var _badgeProminence: Int { get { self[_BadgeProminenceKey.self] } set { self[_BadgeProminenceKey.self] = newValue } }
    /// buttonRepeatBehavior: 0 automatic, 1 enabled, 2 disabled
    var _buttonRepeat: Int { get { self[_ButtonRepeatKey.self] } set { self[_ButtonRepeatKey.self] = newValue } }
    var _backgroundStyle: AnyShapeStyle? { get { self[_BackgroundStyleKey.self] } set { self[_BackgroundStyleKey.self] = newValue } }
    var _navigationLinkIndicator: Visibility { get { self[_NavigationLinkIndicatorKey.self] } set { self[_NavigationLinkIndicatorKey.self] = newValue } }
    var _dialogSeverity: Int { get { self[_DialogSeverityKey.self] } set { self[_DialogSeverityKey.self] = newValue } }
    var _dialogIcon: Image? { get { self[_DialogIconKey.self] } set { self[_DialogIconKey.self] = newValue } }
    var _menuStyle: _AnyMenuStyle? { get { self[_MenuStyleKey.self] } set { self[_MenuStyleKey.self] = newValue } }

    @available(iOS 17.0, *)
    public var badgeProminence: BadgeProminence {
        get { BadgeProminence(id: _badgeProminence) }
        set { _badgeProminence = newValue.id }
    }
    @available(iOS 17.0, *)
    public var buttonRepeatBehavior: ButtonRepeatBehavior {
        get { ButtonRepeatBehavior(id: _buttonRepeat) }
        set { _buttonRepeat = newValue.id }
    }
    @available(iOS 16.0, *)
    public var backgroundStyle: AnyShapeStyle? {
        get { _backgroundStyle }
        set { _backgroundStyle = newValue }
    }
    public var menuIndicatorVisibility: Visibility {
        get { self[_MenuIndicatorKey.self] }
        set { self[_MenuIndicatorKey.self] = newValue }
    }
    @available(iOS 18.0, *)
    public var labelsVisibility: Visibility {
        get { _labelsHidden ? .hidden : .automatic }
        set { _labelsHidden = newValue == .hidden }
    }
    @available(iOS 17.0, *)
    public var navigationLinkIndicatorVisibility: Visibility {
        get { _navigationLinkIndicator }
        set { _navigationLinkIndicator = newValue }
    }
    @available(iOS 17.5, *)
    public var preferredPencilDoubleTapAction: PencilPreferredAction { PencilPreferredAction(UIPencilInteraction.preferredTapAction) }
    @available(iOS 17.5, *)
    public var preferredPencilSqueezeAction: PencilPreferredAction { PencilPreferredAction(UIPencilInteraction.preferredSqueezeAction) }
}

// MARK: - Badges, buttons, backgrounds, labels, links

/// How prominent a List row's badge is: increased is white on a red capsule, decreased is dimmer.
@available(iOS 17.0, *)
public struct BadgeProminence: Hashable, Sendable {
    let id: Int
    public static let standard = BadgeProminence(id: 0)
    public static let increased = BadgeProminence(id: 1)
    public static let decreased = BadgeProminence(id: 2)
}
/// Whether a held button repeats its action.
@available(iOS 17.0, *)
public struct ButtonRepeatBehavior: Hashable, Sendable {
    let id: Int
    public static let automatic = ButtonRepeatBehavior(id: 0)
    public static let enabled = ButtonRepeatBehavior(id: 1)
    public static let disabled = ButtonRepeatBehavior(id: 2)
}
/// The first button in a resolved node (a primitive button style's body).
@MainActor func _firstButton(_ n: _Node) -> _ButtonNode? {
    if let b = n as? _ButtonNode { return b }
    for c in n.children { if let b = _firstButton(c) { return b } }
    return nil
}

extension View {
    @available(iOS 17.0, *)
    public func badgeProminence(_ prominence: BadgeProminence) -> some View { _env { $0._badgeProminence = prominence.id } }
    /// Buttons inside repeat their action while held: once on touch down, then every 0.1 s after half a second.
    @available(iOS 17.0, *)
    public func buttonRepeatBehavior(_ behavior: ButtonRepeatBehavior) -> some View { _env { $0._buttonRepeat = behavior.id } }
    /// What `.background` (BackgroundStyle) stands for inside.
    @available(iOS 16.0, *)
    public func backgroundStyle<S: ShapeStyle>(_ style: S) -> some View { _env { $0._backgroundStyle = AnyShapeStyle(style) } }
    /// `.visible` adds an up-down chevron after Menu labels inside.
    public func menuIndicator(_ visibility: Visibility) -> some View { _env { $0.menuIndicatorVisibility = visibility } }
    /// `.hidden` hides the labels of controls inside, like labelsHidden().
    @available(iOS 18.0, *)
    public func labelsVisibility(_ visibility: Visibility) -> some View { _env { $0._labelsHidden = visibility == .hidden } }
    /// `.hidden` leaves out the chevron of NavigationLink rows in Lists inside.
    @available(iOS 17.0, *)
    public func navigationLinkIndicatorVisibility(_ visibility: Visibility) -> some View { _env { $0._navigationLinkIndicator = visibility } }
}

// MARK: - Kept but not shown on iOS

/// How important a dialog is (macOS shows critical ones with a caution badge; iOS dialogs look the same).
@available(iOS 17.0, *)
public struct DialogSeverity: Equatable, Sendable {
    let id: Int
    public static let automatic = DialogSeverity(id: 0)
    public static let standard = DialogSeverity(id: 1)
    public static let critical = DialogSeverity(id: 2)
}
/// The language whose line height and spacing text uses.
@available(iOS 17.0, *)
public struct TypesettingLanguage: Sendable, Equatable {
    let language: Locale.Language?
    public static let automatic = TypesettingLanguage(language: nil)
    public static func explicit(_ language: Locale.Language) -> TypesettingLanguage { TypesettingLanguage(language: language) }
}
struct _TypesettingLanguageKey: EnvironmentKey { static var defaultValue: Locale.Language? { nil } }
extension EnvironmentValues {
    var _typesettingLanguage: Locale.Language? { get { self[_TypesettingLanguageKey.self] } set { self[_TypesettingLanguageKey.self] = newValue } }
}
extension View {
    /// Isolates the view's geometry for animations: isim already places and animates a view's subviews relative to it.
    @available(iOS 17.0, *)
    public func geometryGroup() -> some View { _modify { ctx, c in _resolve(c, ctx.child("geo")) } }
    @available(iOS 17.0, *)
    public func dialogSeverity(_ severity: DialogSeverity) -> some View { _env { $0._dialogSeverity = severity.id } }
    @available(iOS 17.0, *)
    public func dialogIcon(_ icon: Image?) -> some View { _env { $0._dialogIcon = icon } }
    @available(iOS 17.0, *)
    public func typesettingLanguage(_ language: Locale.Language, isEnabled: Bool = true) -> some View {
        _env { if isEnabled { $0._typesettingLanguage = language } }
    }
    @available(iOS 17.0, *)
    public func typesettingLanguage(_ language: TypesettingLanguage, isEnabled: Bool = true) -> some View {
        _env { if isEnabled { $0._typesettingLanguage = language.language } }
    }
}
extension Text {
    @available(iOS 17.0, *)
    public func typesettingLanguage(_ language: Locale.Language, isEnabled: Bool = true) -> Text { self }
    @available(iOS 17.0, *)
    public func typesettingLanguage(_ language: TypesettingLanguage, isEnabled: Bool = true) -> Text { self }
}

// MARK: - TextEditorStyle

/// The look of a TextEditor. iOS has two, and they look the same: a plain editor without a border.
@available(iOS 17.0, *)
public protocol TextEditorStyle {
    associatedtype Body: View
    typealias Configuration = TextEditorStyleConfiguration
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body
}
@available(iOS 17.0, *)
public struct TextEditorStyleConfiguration {}
@available(iOS 17.0, *)
public struct AutomaticTextEditorStyle: TextEditorStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
@available(iOS 17.0, *)
public struct PlainTextEditorStyle: TextEditorStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
@available(iOS 17.0, *)
extension TextEditorStyle where Self == AutomaticTextEditorStyle { public static var automatic: AutomaticTextEditorStyle { .init() } }
@available(iOS 17.0, *)
extension TextEditorStyle where Self == PlainTextEditorStyle { public static var plain: PlainTextEditorStyle { .init() } }
extension View {
    @available(iOS 17.0, *)
    public func textEditorStyle(_ style: some TextEditorStyle) -> some View { self }
}

// MARK: - MenuStyle

/// A Menu's label and content, for a custom MenuStyle (`Menu(configuration)` shows them as a menu).
public struct MenuStyleConfiguration {
    public struct Label: View, _PrimitiveView {
        let make: @MainActor (_Context) -> _Node
        public var body: Never { fatalError() }
        func _makeNode(_ ctx: _Context) -> _Node { make(ctx) }
    }
    public struct Content: View, _PrimitiveView {
        let make: @MainActor (_Context) -> _Node
        public var body: Never { fatalError() }
        func _makeNode(_ ctx: _Context) -> _Node { make(ctx) }
    }
    let label: Label, content: Content
    let primaryAction: (() -> Void)?
}
struct _AnyMenuStyle {
    /// 0 default, 1 button (the label drawn as a button with the button style around), 2 custom
    let kind: Int
    let make: @MainActor (MenuStyleConfiguration) -> any View
}
extension Menu where Label == MenuStyleConfiguration.Label, Content == MenuStyleConfiguration.Content {
    /// The menu of a MenuStyle's configuration, for its makeBody.
    public init(_ configuration: MenuStyleConfiguration) {
        if let p = configuration.primaryAction { self.init(content: { configuration.content }, label: { configuration.label }, primaryAction: p) }
        else { self.init(content: { configuration.content }, label: { configuration.label }) }
    }
}
extension View {
    public func menuStyle<S: MenuStyle>(_ style: S) -> some View {
        let kind = S.self == DefaultMenuStyle.self || S.self == BorderlessButtonMenuStyle.self ? 0 : S.self == ButtonMenuStyle.self ? 1 : 2
        return _env { $0._menuStyle = kind == 0 ? nil : _AnyMenuStyle(kind: kind, make: { style.makeBody(configuration: $0) }) }
    }
}

// MARK: - Apple Pencil

/// What the person chose in Settings › Apple Pencil for a double-tap or a squeeze.
@available(iOS 17.5, *)
public struct PencilPreferredAction: Equatable, Sendable {
    let id: Int
    init(_ a: UIPencilPreferredAction) { id = a.rawValue }
    public static let ignore = PencilPreferredAction(.ignore)
    public static let switchEraser = PencilPreferredAction(.switchEraser)
    public static let switchPrevious = PencilPreferredAction(.switchPrevious)
    public static let showColorPalette = PencilPreferredAction(.showColorPalette)
    public static let showInkAttributes = PencilPreferredAction(.showInkAttributes)
    public static let showContextualPalette = PencilPreferredAction(.showContextualPalette)
    public static let runSystemShortcut = PencilPreferredAction(.runSystemShortcut)
}
/// Where the Pencil hovered when it was tapped or squeezed.
@available(iOS 17.5, *)
public struct PencilHoverPose: Equatable, Sendable {
    public let location: CGPoint
    public let zDistance: CGFloat
    public let anchor: UnitPoint
    public let azimuth: Angle
    public let altitude: Angle
    public let roll: Angle
}
@available(iOS 17.5, *)
public struct PencilDoubleTapGestureValue: Equatable, Sendable {
    public let hoverPose: PencilHoverPose?
}
@available(iOS 17.5, *)
public struct PencilSqueezeGestureValue: Equatable, Sendable {
    public let hoverPose: PencilHoverPose?
}
@available(iOS 17.5, *)
public enum PencilSqueezeGesturePhase: Equatable, Sendable {
    case active(PencilSqueezeGestureValue)
    case ended(PencilSqueezeGestureValue)
    case failed
}
@available(iOS 17.5, *)
@MainActor func _hoverPose(_ p: UIPencilHoverPose?, in v: UIView) -> PencilHoverPose? {
    guard let p else { return nil }
    let loc = v.convert(p.location, from: nil)
    let b = v.bounds
    return PencilHoverPose(location: loc, zDistance: p.zOffset,
                           anchor: UnitPoint(x: b.width > 0 ? loc.x / b.width : 0, y: b.height > 0 ? loc.y / b.height : 0),
                           azimuth: .radians(p.azimuthAngle), altitude: .radians(p.altitudeAngle), roll: .radians(p.rollAngle))
}
/// onPencilDoubleTap / onPencilSqueeze: a UIPencilInteraction on the view.
final class _PencilNode: _WrapperNode {
    var tap: ((NSObject?, UIView) -> Void)?
    var squeeze: ((Int, NSObject?, UIView) -> Void)?
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIPencilView(frame: .zero) }
        if v.interactions.isEmpty { v.addInteraction(UIPencilInteraction(delegate: v)) }
        if let t = tap { v.tap = t }
        if let s = squeeze { v.squeeze = s }
        return v
    }
}
final class _SUIPencilView: _PassthroughViewBase, UIPencilInteractionDelegate {
    var tap: ((NSObject?, UIView) -> Void)?
    var squeeze: ((Int, NSObject?, UIView) -> Void)?
    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap t: UIPencilInteraction.Tap) { tap?(t.hoverPose, self) }
    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze s: UIPencilInteraction.Squeeze) { squeeze?(s.phase.rawValue, s.hoverPose, self) }
}
/// The pencil node for the modified view (both modifiers on one view share it).
@MainActor func _pencilNode(_ ctx: _Context, _ c: some View) -> _PencilNode {
    let n = _resolve(c, ctx.child("pencil"))
    if let p = n as? _PencilNode { return p }
    return _PencilNode(path: ctx.path, child: n)
}
extension View {
    /// Calls `action` when the Apple Pencil is double-tapped (`pencil tap` in a script).
    @available(iOS 17.5, *)
    public func onPencilDoubleTap(perform action: @escaping (_ value: PencilDoubleTapGestureValue) -> Void) -> some View {
        _modify { ctx, c in
            let n = _pencilNode(ctx, c)
            n.tap = { pose, v in action(PencilDoubleTapGestureValue(hoverPose: _hoverPose(pose as? UIPencilHoverPose, in: v))) }
            return n
        }
    }
    /// Calls `action` with the phases of an Apple Pencil squeeze (`pencil squeeze` in a script): active, then ended.
    @available(iOS 17.5, *)
    public func onPencilSqueeze(perform action: @escaping (_ phase: PencilSqueezeGesturePhase) -> Void) -> some View {
        _modify { ctx, c in
            let n = _pencilNode(ctx, c)
            n.squeeze = { phase, pose, v in
                let value = PencilSqueezeGestureValue(hoverPose: _hoverPose(pose as? UIPencilHoverPose, in: v))
                switch phase {
                case 0, 1: action(.active(value))
                case 2: action(.ended(value))
                default: action(.failed)
                }
            }
            return n
        }
    }
}
