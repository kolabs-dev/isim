// isim SwiftUI: the rest of SwiftUI's own EnvironmentValues (issue #868) and the small types they hold. Values that
// modifiers already keep (text traits, scroll options, focus and hover effects, keyboard shortcuts, Dynamic Type) are
// read from there; the others are stored by the modifiers that set them. Settings isim does not simulate (Assistive
// Access, Switch Control, button shapes, ...) read their iOS defaults.
import UIKit

// MARK: - types

/// How prominent the background a view sits on is (iOS 17): views over an increased background draw quieter.
public struct BackgroundProminence: Hashable, Sendable {
    let raw: Int
    public static let standard = BackgroundProminence(raw: 0)
    public static let increased = BackgroundProminence(raw: 1)
}
/// How buttons size themselves in their container (iOS 26).
public struct ButtonSizing: Hashable, Sendable {
    let raw: Int
    public static let automatic = ButtonSizing(raw: 0), fitted = ButtonSizing(raw: 1), flexible = ButtonSizing(raw: 2)
}
/// Whether materials look active (iOS 26; the window's key state elsewhere).
public struct MaterialActiveAppearance: Hashable, Sendable {
    let raw: Int
    public static let automatic = MaterialActiveAppearance(raw: 0), active = MaterialActiveAppearance(raw: 1)
    public static let inactive = MaterialActiveAppearance(raw: 2), matchWindow = MaterialActiveAppearance(raw: 3)
}
/// Where search suggestions appear (iOS 16).
public struct SearchSuggestionsPlacement: Equatable, Sendable {
    let raw: Int
    public static let automatic = SearchSuggestionsPlacement(raw: 0), content = SearchSuggestionsPlacement(raw: 1), menu = SearchSuggestionsPlacement(raw: 2)
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let content = Set(rawValue: 1 << 0), menu = Set(rawValue: 1 << 1)
    }
}
/// The size of sidebar rows (iOS 16, the system setting on iPad).
public enum SidebarRowSize: Hashable, Sendable { case small, medium, large }
/// Whether a view opens when a drag hovers over it (iOS 17).
public struct SpringLoadingBehavior: Hashable, Sendable {
    let raw: Int
    public static let automatic = SpringLoadingBehavior(raw: 0), enabled = SpringLoadingBehavior(raw: 1), disabled = SpringLoadingBehavior(raw: 2)
}
/// How SF Symbols fill their colours (iOS 26).
public struct SymbolColorRenderingMode: Hashable, Sendable {
    let raw: Int
    public static let flat = SymbolColorRenderingMode(raw: 0), gradient = SymbolColorRenderingMode(raw: 1)
}
/// How a variable-value SF Symbol shows its value (iOS 26).
public struct SymbolVariableValueMode: Hashable, Sendable {
    let raw: Int
    public static let color = SymbolVariableValueMode(raw: 0), draw = SymbolVariableValueMode(raw: 1)
}
/// How toolbar items show their labels (iOS 18).
public struct ToolbarLabelStyle: Hashable, Sendable {
    let raw: Int
    public static let automatic = ToolbarLabelStyle(raw: 0), iconOnly = ToolbarLabelStyle(raw: 1)
    public static let titleAndIcon = ToolbarLabelStyle(raw: 2), titleOnly = ToolbarLabelStyle(raw: 3)
}
/// Where the navigation title sits in the toolbar (iOS 26; it is centred on iPhone).
public struct ToolbarTitleAlignment: Hashable, Sendable {
    let raw: Int
    public static let automatic = ToolbarTitleAlignment(raw: 0), leading = ToolbarTitleAlignment(raw: 1), center = ToolbarTitleAlignment(raw: 2)
}
/// How much Writing Tools a text view offers (iOS 18).
public struct WritingToolsBehavior: Hashable, Sendable {
    let raw: Int
    public static let automatic = WritingToolsBehavior(raw: 0), complete = WritingToolsBehavior(raw: 1)
    public static let limited = WritingToolsBehavior(raw: 2), disabled = WritingToolsBehavior(raw: 3)
}
/// The text size categories before DynamicTypeSize (iOS 13).
public enum ContentSizeCategory: Hashable, CaseIterable, Sendable {
    case extraSmall, small, medium, large, extraLarge, extraExtraLarge, extraExtraExtraLarge
    case accessibilityMedium, accessibilityLarge, accessibilityExtraLarge, accessibilityExtraExtraLarge, accessibilityExtraExtraExtraLarge
    public var isAccessibilityCategory: Bool { self >= .accessibilityMedium }
    public init?(_ uiSizeCategory: UIContentSizeCategory) {
        let ui: [UIContentSizeCategory] = [.extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
                                           .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
                                           .accessibilityExtraExtraExtraLarge]
        guard let i = ui.firstIndex(of: uiSizeCategory) else { return nil }
        self = ContentSizeCategory.allCases[i]
    }
    public init(_ dynamicTypeSize: DynamicTypeSize) { self = ContentSizeCategory.allCases[DynamicTypeSize.allCases.firstIndex(of: dynamicTypeSize) ?? 3] }
    var _dynamicTypeSize: DynamicTypeSize { DynamicTypeSize.allCases[ContentSizeCategory.allCases.firstIndex(of: self) ?? 3] }
}
extension ContentSizeCategory: Comparable {
    public static func < (a: ContentSizeCategory, b: ContentSizeCategory) -> Bool {
        (allCases.firstIndex(of: a) ?? 0) < (allCases.firstIndex(of: b) ?? 0)
    }
}
extension UIContentSizeCategory {
    public init(_ sizeCategory: ContentSizeCategory?) {
        let ui: [UIContentSizeCategory] = [.extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
                                           .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
                                           .accessibilityExtraExtraExtraLarge]
        self = sizeCategory.flatMap { ContentSizeCategory.allCases.firstIndex(of: $0) }.map { ui[$0] } ?? .unspecified
    }
}

// MARK: - keys

struct _AXAssistiveAccessKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _AXDimFlashingKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _AXEnabledKey: EnvironmentKey { static var defaultValue: Bool { UIAccessibility.isVoiceOverRunning } }
struct _AXLargeContentViewerKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _AXPlayAnimatedImagesKey: EnvironmentKey { static var defaultValue: Bool { true } }
struct _AXCrossFadeKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _AXQuickActionsKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _AXReduceHighlightingKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _AXShowBordersKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _AXButtonShapesKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _AXSwitchControlKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _DynamicRangeEnvKey: EnvironmentKey { static var defaultValue: AnyHashable? { nil } }
struct _AppearsActiveKey: EnvironmentKey { static var defaultValue: Bool { true } }
struct _BackgroundMaterialKey: EnvironmentKey { static var defaultValue: Material? { nil } }
struct _BackgroundProminenceKey: EnvironmentKey { static var defaultValue: BackgroundProminence { .standard } }
struct _ButtonSizingKey: EnvironmentKey { static var defaultValue: ButtonSizing { .automatic } }
struct _ContentTransitionEnvKey: EnvironmentKey { static var defaultValue: ContentTransition { .identity } }
struct _ContentTransitionDrawingGroupKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _IsFocusedEnvKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _LuminanceReducedKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _SceneCapturedKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _TabBarSectionsKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _TabSidebarAvailableKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _LabelIconWidthKey: EnvironmentKey { static var defaultValue: CGFloat? { nil } }
struct _LineHeightEnvKey: EnvironmentKey { static var defaultValue: AttributedString.LineHeight? { nil } }
struct _LineSpacingEnvKey: EnvironmentKey { static var defaultValue: CGFloat { 0 } }
struct _MaterialActiveKey: EnvironmentKey { static var defaultValue: MaterialActiveAppearance { .automatic } }
struct _MenuOrderEnvKey: EnvironmentKey { static var defaultValue: MenuOrder { .automatic } }
struct _SearchSuggestionsPlacementKey: EnvironmentKey { static var defaultValue: SearchSuggestionsPlacement { .automatic } }
struct _SidebarRowSizeKey: EnvironmentKey { static var defaultValue: SidebarRowSize { .medium } }
struct _SpringLoadingKey: EnvironmentKey { static var defaultValue: SpringLoadingBehavior { .automatic } }
struct _SymbolColorModeKey: EnvironmentKey { static var defaultValue: SymbolColorRenderingMode? { nil } }
struct _SymbolVariableModeKey: EnvironmentKey { static var defaultValue: SymbolVariableValueMode? { nil } }
struct _ReducedResourceKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _ToolbarLabelStyleKey: EnvironmentKey { static var defaultValue: ToolbarLabelStyle? { nil } }
struct _ToolbarTitleAlignmentKey: EnvironmentKey { static var defaultValue: ToolbarTitleAlignment { .automatic } }
struct _WritingToolsKey: EnvironmentKey { static var defaultValue: WritingToolsBehavior? { nil } }
struct _RemoteScenesKey: EnvironmentKey { static var defaultValue: Bool { false } }

extension EnvironmentValues {
    // Settings > Accessibility (isim does not simulate these settings: they read iOS's defaults)
    public var accessibilityAssistiveAccessEnabled: Bool { get { self[_AXAssistiveAccessKey.self] } set { self[_AXAssistiveAccessKey.self] = newValue } }
    public var accessibilityDimFlashingLights: Bool { get { self[_AXDimFlashingKey.self] } set { self[_AXDimFlashingKey.self] = newValue } }
    public var accessibilityEnabled: Bool { get { self[_AXEnabledKey.self] } set { self[_AXEnabledKey.self] = newValue } }
    public var accessibilityLargeContentViewerEnabled: Bool { get { self[_AXLargeContentViewerKey.self] } set { self[_AXLargeContentViewerKey.self] = newValue } }
    public var accessibilityPlayAnimatedImages: Bool { get { self[_AXPlayAnimatedImagesKey.self] } set { self[_AXPlayAnimatedImagesKey.self] = newValue } }
    public var accessibilityPrefersCrossFadeTransitions: Bool { get { self[_AXCrossFadeKey.self] } set { self[_AXCrossFadeKey.self] = newValue } }
    public var accessibilityQuickActionsEnabled: Bool { get { self[_AXQuickActionsKey.self] } set { self[_AXQuickActionsKey.self] = newValue } }
    public var accessibilityReduceHighlightingEffects: Bool { get { self[_AXReduceHighlightingKey.self] } set { self[_AXReduceHighlightingKey.self] = newValue } }
    public var accessibilityShowBorders: Bool { get { self[_AXShowBordersKey.self] } set { self[_AXShowBordersKey.self] = newValue } }
    public var accessibilityShowButtonShapes: Bool { get { self[_AXButtonShapesKey.self] } set { self[_AXButtonShapesKey.self] = newValue } }
    public var accessibilitySwitchControlEnabled: Bool { get { self[_AXSwitchControlKey.self] } set { self[_AXSwitchControlKey.self] = newValue } }

    @available(iOS 26.0, *)
    public var allowedDynamicRange: Image.DynamicRange? { get { self[_DynamicRangeEnvKey.self]?.base as? Image.DynamicRange } set { self[_DynamicRangeEnvKey.self] = newValue.map { AnyHashable($0) } } }
    public var appearsActive: Bool { get { self[_AppearsActiveKey.self] } set { self[_AppearsActiveKey.self] = newValue } }
    public var autocorrectionDisabled: Bool { get { _textTraits.autocorrectionDisabled } set { _textTraits.autocorrectionDisabled = newValue } }
    public var disableAutocorrection: Bool? { get { _textTraits.autocorrectionDisabled } set { _textTraits.autocorrectionDisabled = newValue ?? false } }
    public var backgroundMaterial: Material? { get { self[_BackgroundMaterialKey.self] } set { self[_BackgroundMaterialKey.self] = newValue } }
    public var backgroundProminence: BackgroundProminence { get { self[_BackgroundProminenceKey.self] } set { self[_BackgroundProminenceKey.self] = newValue } }
    public var buttonSizing: ButtonSizing { get { self[_ButtonSizingKey.self] } set { self[_ButtonSizingKey.self] = newValue } }
    public var contentTransition: ContentTransition { get { self[_ContentTransitionEnvKey.self] } set { self[_ContentTransitionEnvKey.self] = newValue } }
    public var contentTransitionAddsDrawingGroup: Bool { get { self[_ContentTransitionDrawingGroupKey.self] } set { self[_ContentTransitionDrawingGroupKey.self] = newValue } }

    // scrolling: the options .scrollIndicators / .scrollBounceBehavior / .scrollDisabled / .scrollDismissesKeyboard keep
    public var horizontalScrollIndicatorVisibility: ScrollIndicatorVisibility {
        get { _scrollOptions.indicators.map { $0 ? .visible : .hidden } ?? .automatic }
        set { _scrollOptions.indicators = newValue.id == 0 ? nil : newValue.id == 1 }
    }
    public var verticalScrollIndicatorVisibility: ScrollIndicatorVisibility {
        get { horizontalScrollIndicatorVisibility }
        set { horizontalScrollIndicatorVisibility = newValue }
    }
    public var horizontalScrollBounceBehavior: ScrollBounceBehavior {
        get { _scrollOptions.bounceBasedOnSize ? .basedOnSize : .automatic }
        set { _scrollOptions.bounceBasedOnSize = newValue.id == 2 }
    }
    public var verticalScrollBounceBehavior: ScrollBounceBehavior {
        get { horizontalScrollBounceBehavior }
        set { horizontalScrollBounceBehavior = newValue }
    }
    public var isScrollEnabled: Bool { get { !_scrollOptions.disabled } set { _scrollOptions.disabled = !newValue } }
    public var scrollDismissesKeyboardMode: ScrollDismissesKeyboardMode {
        get { [ScrollDismissesKeyboardMode.automatic, .immediately, .interactively, .never][max(0, min(3, _scrollOptions.keyboard))] }
        set { _scrollOptions.keyboard = newValue.id }
    }

    // focus, hover, keyboard
    public var isFocused: Bool { get { self[_IsFocusedEnvKey.self] } set { self[_IsFocusedEnvKey.self] = newValue } }
    public var isFocusEffectEnabled: Bool { get { !_focusEffectDisabled } set { _focusEffectDisabled = !newValue } }
    public var isHoverEffectEnabled: Bool { get { !_hoverEffectDisabled } set { _hoverEffectDisabled = !newValue } }
    public var keyboardShortcut: KeyboardShortcut? { get { _keyboardShortcut } set { _keyboardShortcut = newValue } }

    public var isLuminanceReduced: Bool { get { self[_LuminanceReducedKey.self] } set { self[_LuminanceReducedKey.self] = newValue } }
    public var isSceneCaptured: Bool { get { self[_SceneCapturedKey.self] } set { self[_SceneCapturedKey.self] = newValue } }
    public var isTabBarShowingSections: Bool { get { self[_TabBarSectionsKey.self] } set { self[_TabBarSectionsKey.self] = newValue } }
    public var isTabViewSidebarAvailable: Bool { get { self[_TabSidebarAvailableKey.self] } set { self[_TabSidebarAvailableKey.self] = newValue } }
    public var labelReservedIconWidth: CGFloat? { get { self[_LabelIconWidthKey.self] } set { self[_LabelIconWidthKey.self] = newValue } }
    public var lineHeight: AttributedString.LineHeight? { get { self[_LineHeightEnvKey.self] } set { self[_LineHeightEnvKey.self] = newValue } }
    public var lineSpacing: CGFloat { get { self[_LineSpacingEnvKey.self] } set { self[_LineSpacingEnvKey.self] = newValue } }
    public var materialActiveAppearance: MaterialActiveAppearance { get { self[_MaterialActiveKey.self] } set { self[_MaterialActiveKey.self] = newValue } }
    public var menuOrder: MenuOrder { get { self[_MenuOrderEnvKey.self] } set { self[_MenuOrderEnvKey.self] = newValue } }
    /// one device pixel in points (1 / the screen's scale)
    @MainActor public var pixelLength: CGFloat { 1 / max(1, UIScreen.main.scale) }
    public var searchSuggestionsPlacement: SearchSuggestionsPlacement { get { self[_SearchSuggestionsPlacementKey.self] } set { self[_SearchSuggestionsPlacementKey.self] = newValue } }
    public var sidebarRowSize: SidebarRowSize { get { self[_SidebarRowSizeKey.self] } set { self[_SidebarRowSizeKey.self] = newValue } }
    /// the Dynamic Type size, in the older categories
    public var sizeCategory: ContentSizeCategory { get { ContentSizeCategory(dynamicTypeSize) } set { dynamicTypeSize = newValue._dynamicTypeSize } }
    public var springLoadingBehavior: SpringLoadingBehavior { get { self[_SpringLoadingKey.self] } set { self[_SpringLoadingKey.self] = newValue } }
    public var symbolColorRenderingMode: SymbolColorRenderingMode? { get { self[_SymbolColorModeKey.self] } set { self[_SymbolColorModeKey.self] = newValue } }
    public var symbolVariableValueMode: SymbolVariableValueMode? { get { self[_SymbolVariableModeKey.self] } set { self[_SymbolVariableModeKey.self] = newValue } }
    public var systemPrefersReducedResourceUsage: Bool { get { self[_ReducedResourceKey.self] } set { self[_ReducedResourceKey.self] = newValue } }
    public var toolbarLabelStyle: ToolbarLabelStyle? { get { self[_ToolbarLabelStyleKey.self] } set { self[_ToolbarLabelStyleKey.self] = newValue } }
    public var toolbarTitleAlignment: ToolbarTitleAlignment { get { self[_ToolbarTitleAlignmentKey.self] } set { self[_ToolbarTitleAlignmentKey.self] = newValue } }
    public var writingToolsBehavior: WritingToolsBehavior? { get { self[_WritingToolsKey.self] } set { self[_WritingToolsKey.self] = newValue } }
    public var supportsRemoteScenes: Bool { get { self[_RemoteScenesKey.self] } set { self[_RemoteScenesKey.self] = newValue } }
}

// MARK: - the modifiers that set them

extension View {
    @available(iOS 26.0, *)
    public func allowedDynamicRange(_ range: Image.DynamicRange?) -> some View { environment(\.allowedDynamicRange, range) }
    public func buttonSizing(_ sizing: ButtonSizing) -> some View { environment(\.buttonSizing, sizing) }
    public func labelReservedIconWidth(_ width: CGFloat) -> some View { environment(\.labelReservedIconWidth, width) }
    public func lineHeight(_ lineHeight: AttributedString.LineHeight?) -> some View { environment(\.lineHeight, lineHeight) }
    public func materialActiveAppearance(_ appearance: MaterialActiveAppearance) -> some View { environment(\.materialActiveAppearance, appearance) }
    public func springLoadingBehavior(_ behavior: SpringLoadingBehavior) -> some View { environment(\.springLoadingBehavior, behavior) }
    public func symbolColorRenderingMode(_ mode: SymbolColorRenderingMode?) -> some View { environment(\.symbolColorRenderingMode, mode) }
    public func symbolVariableValueMode(_ mode: SymbolVariableValueMode?) -> some View { environment(\.symbolVariableValueMode, mode) }
    public func toolbarTitleAlignment(_ alignment: ToolbarTitleAlignment) -> some View { environment(\.toolbarTitleAlignment, alignment) }
    public func writingToolsBehavior(_ behavior: WritingToolsBehavior) -> some View { environment(\.writingToolsBehavior, behavior) }
    /// iOS 13 (deprecated): the colour scheme for this view and its children
    public func colorScheme(_ colorScheme: ColorScheme) -> some View { environment(\.colorScheme, colorScheme) }
    /// iOS 13 (deprecated)
    public func disableAutocorrection(_ disable: Bool?) -> some View { autocorrectionDisabled(disable ?? false) }
}
