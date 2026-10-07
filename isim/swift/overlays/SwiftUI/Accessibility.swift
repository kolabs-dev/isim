// isim SwiftUI: accessibility modifiers and environment values. Modifiers set UIKit accessibility properties on the
// views SwiftUI mounts, so they feed the same accessibility tree as UIKit (isim's VoiceOver, `dump` with
// ISIM_DUMP_ACCESSIBILITY=1). Environment values follow Settings > Accessibility.
import UIKit

public struct AccessibilityTraits: OptionSet, Sendable {
    public var rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static let isButton = AccessibilityTraits(rawValue: UIAccessibilityTraits.button.rawValue)
    public static let isHeader = AccessibilityTraits(rawValue: UIAccessibilityTraits.header.rawValue)
    public static let isSelected = AccessibilityTraits(rawValue: UIAccessibilityTraits.selected.rawValue)
    public static let isLink = AccessibilityTraits(rawValue: UIAccessibilityTraits.link.rawValue)
    public static let isSearchField = AccessibilityTraits(rawValue: UIAccessibilityTraits.searchField.rawValue)
    public static let isImage = AccessibilityTraits(rawValue: UIAccessibilityTraits.image.rawValue)
    public static let playsSound = AccessibilityTraits(rawValue: UIAccessibilityTraits.playsSound.rawValue)
    public static let isKeyboardKey = AccessibilityTraits(rawValue: UIAccessibilityTraits.keyboardKey.rawValue)
    public static let isStaticText = AccessibilityTraits(rawValue: UIAccessibilityTraits.staticText.rawValue)
    public static let isSummaryElement = AccessibilityTraits(rawValue: UIAccessibilityTraits.summaryElement.rawValue)
    public static let updatesFrequently = AccessibilityTraits(rawValue: UIAccessibilityTraits.updatesFrequently.rawValue)
    public static let startsMediaSession = AccessibilityTraits(rawValue: UIAccessibilityTraits.startsMediaSession.rawValue)
    public static let allowsDirectInteraction = AccessibilityTraits(rawValue: UIAccessibilityTraits.allowsDirectInteraction.rawValue)
    public static let causesPageTurn = AccessibilityTraits(rawValue: UIAccessibilityTraits.causesPageTurn.rawValue)
    public static let isToggle = AccessibilityTraits(rawValue: UIAccessibilityTraits.toggleButton.rawValue)
    public static let isModal = AccessibilityTraits(rawValue: 1 << 62)
    var uikit: UIAccessibilityTraits { UIAccessibilityTraits(rawValue: rawValue & ~(1 << 62)) }
}
public struct AccessibilityChildBehavior: Hashable, Sendable {
    let kind: Int
    public static let ignore = AccessibilityChildBehavior(kind: 0), contain = AccessibilityChildBehavior(kind: 1), combine = AccessibilityChildBehavior(kind: 2)
}
public enum AccessibilityAdjustmentDirection: Sendable { case increment, decrement }
public struct AccessibilityActionKind: Equatable, Sendable {
    let name: String
    public static let `default` = AccessibilityActionKind(name: "default"), escape = AccessibilityActionKind(name: "escape"), magicTap = AccessibilityActionKind(name: "magicTap")
    public init(named name: Text) { self.name = name.string }
    init(name: String) { self.name = name }
}

@MainActor func _accessibilityTexts(_ n: _Node) -> [String] {
    var out: [String] = []
    func walk(_ x: _Node) {
        if let l = x.accessibilityLabel { out.append(l); return }
        let kids = _flatten(x.children)
        if kids.isEmpty { out += _collectText(x) } else { for c in kids { walk(c) } }
    }
    walk(n)
    return out
}

extension View {
    func _accessibility(deepest: Bool = true, _ apply: @escaping (UIView) -> Void) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("ax"))
            if deepest { _tagDeepest(n) { $0.accessibilityApply.append(apply) } } else { n.accessibilityApply.append(apply) }
            return n
        }
    }
    public func accessibilityValue(_ value: Text) -> some View { let s = value.string; return _accessibility { $0.accessibilityValue = s } }
    public func accessibilityValue(_ key: LocalizedStringKey) -> some View { accessibilityValue(Text(key)) }
    @_disfavoredOverload public func accessibilityValue<S: StringProtocol>(_ value: S) -> some View { accessibilityValue(Text(value)) }
    public func accessibilityHint(_ hint: Text) -> some View { let s = hint.string; return _accessibility { $0.accessibilityHint = s } }
    public func accessibilityHint(_ key: LocalizedStringKey) -> some View { accessibilityHint(Text(key)) }
    @_disfavoredOverload public func accessibilityHint<S: StringProtocol>(_ hint: S) -> some View { accessibilityHint(Text(hint)) }
    public func accessibilityHidden(_ hidden: Bool) -> some View {
        _accessibility(deepest: false) { $0.accessibilityElementsHidden = hidden; if hidden { $0.isAccessibilityElement = false } }
    }
    public func accessibilityAddTraits(_ traits: AccessibilityTraits) -> some View {
        _accessibility { v in v.accessibilityTraits = v.accessibilityTraits.union(traits.uikit); if traits.contains(.isModal) { v.accessibilityViewIsModal = true } }
    }
    public func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> some View {
        _accessibility { v in v.accessibilityTraits = v.accessibilityTraits.subtracting(traits.uikit) }
    }
    /// `.ignore` / `.combine`: the container is one element labelled with its children's text; `.contain`: a group.
    public func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("axe"))
            let label = _accessibilityTexts(n).joined(separator: ", ")
            n.accessibilityApply.append { v in
                if children == .contain { v.isAccessibilityElement = false; v.shouldGroupAccessibilityChildren = true; return }
                v.isAccessibilityElement = true
                if v.accessibilityLabel == nil, !label.isEmpty { v.accessibilityLabel = label }
            }
            return n
        }
    }
    public func accessibilitySortPriority(_ p: Double) -> some View {
        _accessibility(deepest: false) { v in v.perform(NSSelectorFromString("_isim_setAccessibilitySortPriority:"), with: NSNumber(value: p)) }
    }
    public func accessibilityAction(_ kind: AccessibilityActionKind = .default, _ handler: @escaping () -> Void) -> some View {
        if kind == .default {
            let block: @convention(block) () -> Bool = { MainActor.assumeIsolated { handler() }; return true }
            return AnyView(_accessibility { v in v.perform(NSSelectorFromString("_isim_setAccessibilityActivateHandler:"), with: block as AnyObject) })
        }
        let name = kind.name
        return AnyView(_accessibility { v in
            let a = UIAccessibilityCustomAction(name: name) { _ in MainActor.assumeIsolated { handler() }; return true }
            v.accessibilityCustomActions = (v.accessibilityCustomActions ?? []).filter { $0.name != name } + [a]
        })
    }
    public func accessibilityAction(named name: Text, _ handler: @escaping () -> Void) -> some View { accessibilityAction(AccessibilityActionKind(named: name), handler) }
    public func accessibilityAction(named key: LocalizedStringKey, _ handler: @escaping () -> Void) -> some View { accessibilityAction(named: Text(key), handler) }
    @_disfavoredOverload public func accessibilityAction<S: StringProtocol>(named name: S, _ handler: @escaping () -> Void) -> some View { accessibilityAction(named: Text(name), handler) }
    public func accessibilityAdjustableAction(_ handler: @escaping (AccessibilityAdjustmentDirection) -> Void) -> some View {
        let block: @convention(block) (Int) -> Void = { d in MainActor.assumeIsolated { handler(d > 0 ? .increment : .decrement) } }
        return _accessibility { v in v.perform(NSSelectorFromString("_isim_setAccessibilityAdjustHandler:"), with: block as AnyObject) }
    }
    public func accessibilityShowsLargeContentViewer() -> some View { _accessibility { $0.showsLargeContentViewer = true } }
    public func accessibilityRespondsToUserInteraction(_ r: Bool = true) -> some View { _accessibility { $0.accessibilityRespondsToUserInteraction = r } }
    public func accessibilityInputLabels(_ labels: [Text]) -> some View { let l = labels.map { $0.string }; return _accessibility { $0.accessibilityUserInputLabels = l } }
}

// MARK: - environment values from Settings > Accessibility
struct _ReduceMotionKey: EnvironmentKey { static var defaultValue: Bool { UIAccessibility.isReduceMotionEnabled } }
struct _ReduceTransparencyKey: EnvironmentKey { static var defaultValue: Bool { UIAccessibility.isReduceTransparencyEnabled } }
struct _DifferentiateKey: EnvironmentKey { static var defaultValue: Bool { UIAccessibility.shouldDifferentiateWithoutColor } }
struct _VoiceOverKey: EnvironmentKey { static var defaultValue: Bool { UIAccessibility.isVoiceOverRunning } }
struct _InvertColorsKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _LegibilityKey: EnvironmentKey { static var defaultValue: LegibilityWeight { UIAccessibility.isBoldTextEnabled ? .bold : .regular } }
public enum LegibilityWeight: Hashable, Sendable { case regular, bold }
extension EnvironmentValues {
    public var accessibilityReduceMotion: Bool { get { self[_ReduceMotionKey.self] } set { self[_ReduceMotionKey.self] = newValue } }
    public var accessibilityReduceTransparency: Bool { get { self[_ReduceTransparencyKey.self] } set { self[_ReduceTransparencyKey.self] = newValue } }
    public var accessibilityDifferentiateWithoutColor: Bool { get { self[_DifferentiateKey.self] } set { self[_DifferentiateKey.self] = newValue } }
    public var accessibilityVoiceOverEnabled: Bool { get { self[_VoiceOverKey.self] } set { self[_VoiceOverKey.self] = newValue } }
    public var accessibilityInvertColors: Bool { get { self[_InvertColorsKey.self] } set { self[_InvertColorsKey.self] = newValue } }
    public var legibilityWeight: LegibilityWeight? { get { self[_LegibilityKey.self] } set { self[_LegibilityKey.self] = newValue ?? .regular } }
}
/// The system Dynamic Type size (Settings > Accessibility > Display & Text Size > Larger Text)
@MainActor func _systemDynamicTypeSize() -> DynamicTypeSize {
    let all: [UIContentSizeCategory] = [.extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
                                        .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge]
    let i = all.firstIndex(of: UIApplication.shared.preferredContentSizeCategory) ?? 3
    return DynamicTypeSize.allCases[i]
}
