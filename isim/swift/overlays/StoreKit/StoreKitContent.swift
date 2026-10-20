// isim StoreKit: the iOS 18 store content of SubscriptionStoreView — StoreContent and its builder, option groups
// (SubscriptionOptionGroup, SubscriptionOptionGroupSet), sections (SubscriptionOptionSection) and their styles (tabs,
// links) — and the subscription relationships a store shows (iOS 17). Self-authored, iOS API names. Adapted: the
// content resolves into groups and sections of the group's plans, drawn by SubscriptionStoreView (StoreKitViews.swift).
import SwiftUI

// MARK: - relationships

extension Product {
    /// Which plans a subscription store shows a subscriber, relative to their current plan (all plans before they
    /// subscribe).
    public struct SubscriptionRelationship: Hashable, Sendable {
        let bits: Int
        public static let upgrade = SubscriptionRelationship(bits: 1)
        public static let downgrade = SubscriptionRelationship(bits: 2)
        public static let crossgrade = SubscriptionRelationship(bits: 4)
        public static let current = SubscriptionRelationship(bits: 8)
        public static let all = SubscriptionRelationship(bits: 15)
        /// whether plan `p` is shown to a subscriber of `current` (group levels: 1 is the highest)
        func shows(_ p: _SKItem, current: String?, cfg: _SKConfig) -> Bool {
            guard let current, let c = cfg.item(current) else { return true }
            if p.id == current { return bits & 8 != 0 }
            if p.groupLevel < c.groupLevel { return bits & 1 != 0 }
            if p.groupLevel > c.groupLevel { return bits & 2 != 0 }
            return bits & 4 != 0
        }
    }
}

// MARK: - store content

/// Content of a subscription store (iOS 18): option groups and sections of the group's plans.
@MainActor public protocol StoreContent {
    associatedtype Body: StoreContent
    @StoreContentBuilder var body: Body { get }
}
extension Never: StoreContent {}

/// what store content resolves to
indirect enum _SKContentNode {
    /// plans matching `filter` (or the children's), under a tab or link titled `title` / `label`
    case group(title: String?, label: AnyView?, marketing: AnyView?, filter: ((Product) -> Bool)?, children: [_SKContentNode], mods: _SKContentMods)
    /// the plans matching `filter`, one group per key
    case groupSet(key: (Product) -> AnyHashable, label: (AnyHashable) -> AnyView, marketing: ((AnyHashable) -> AnyView)?, mods: _SKContentMods)
    /// plans under a header and footer
    case section(title: String?, header: AnyView?, footer: AnyView?, filter: (Product) -> Bool, mods: _SKContentMods)
}

/// store content modifiers, applied to the content they modify
struct _SKContentMods {
    var groupStyle: String?
    var buttonLabel: SubscriptionStoreButtonLabel?
    var buttons: [String: Visibility] = [:]
    var control: String?
    var controlBody: (@MainActor (SubscriptionStoreControlStyleConfiguration) -> AnyView)?
    func merged(over outer: _SKContentMods) -> _SKContentMods {
        var m = self
        m.groupStyle = groupStyle ?? outer.groupStyle; m.buttonLabel = buttonLabel ?? outer.buttonLabel; m.control = control ?? outer.control
        m.controlBody = controlBody ?? outer.controlBody
        m.buttons = outer.buttons.merging(buttons) { _, mine in mine }
        return m
    }
}

/// content that resolves itself (the built-in kinds); other content resolves its body
@MainActor protocol _SKPrimitiveStoreContent { func _skNodes(_ mods: _SKContentMods) -> [_SKContentNode] }

@MainActor func _skResolve<C: StoreContent>(_ c: C, _ mods: _SKContentMods = _SKContentMods()) -> [_SKContentNode] {
    if let p = c as? _SKPrimitiveStoreContent { return p._skNodes(mods) }
    if C.Body.self == Never.self { return [] }
    return _skResolve(c.body, mods)
}

@MainActor @resultBuilder public struct StoreContentBuilder {
    public static func buildBlock<each Content: StoreContent>(_ content: repeat each Content) -> TupleStoreContent<repeat each Content> {
        TupleStoreContent(value: (repeat each content))
    }
    public static func buildExpression<Content: StoreContent>(_ content: Content) -> Content { content }
    public static func buildIf<Content: StoreContent>(_ content: Content?) -> Content? { content }
    public static func buildEither<TrueContent: StoreContent, FalseContent: StoreContent>(first: TrueContent) -> _ConditionalStoreContent<TrueContent, FalseContent> {
        _ConditionalStoreContent(storage: .first(first))
    }
    public static func buildEither<TrueContent: StoreContent, FalseContent: StoreContent>(second: FalseContent) -> _ConditionalStoreContent<TrueContent, FalseContent> {
        _ConditionalStoreContent(storage: .second(second))
    }
    public static func buildLimitedAvailability(_ content: any StoreContent) -> _AnyStoreContent { _AnyStoreContent(content) }
}

public struct TupleStoreContent<each Content: StoreContent>: StoreContent, _SKPrimitiveStoreContent {
    public let value: (repeat each Content)
    public init(value: (repeat each Content)) { self.value = value }
    public var body: Never { return fatalError("primitive store content") }
    func _skNodes(_ mods: _SKContentMods) -> [_SKContentNode] {
        var out: [_SKContentNode] = []
        for c in repeat each value { out += _skResolve(c, mods) }
        return out
    }
}

/// isim: `if`/`else` in store content (iOS: SwiftUI's _ConditionalContent, which isim keeps for views only)
public struct _ConditionalStoreContent<TrueContent: StoreContent, FalseContent: StoreContent>: StoreContent, _SKPrimitiveStoreContent {
    enum Storage { case first(TrueContent), second(FalseContent) }
    let storage: Storage
    public var body: Never { return fatalError("primitive store content") }
    func _skNodes(_ mods: _SKContentMods) -> [_SKContentNode] {
        switch storage { case .first(let c): return _skResolve(c, mods); case .second(let c): return _skResolve(c, mods) }
    }
}

/// isim: availability-checked store content (buildLimitedAvailability)
public struct _AnyStoreContent: StoreContent, _SKPrimitiveStoreContent {
    let resolve: @MainActor (_SKContentMods) -> [_SKContentNode]
    init(_ c: any StoreContent) { resolve = { m in _skOpen(c, m) } }
    public var body: Never { return fatalError("primitive store content") }
    func _skNodes(_ mods: _SKContentMods) -> [_SKContentNode] { resolve(mods) }
}
@MainActor func _skOpen<C: StoreContent>(_ c: C, _ m: _SKContentMods) -> [_SKContentNode] { _skResolve(c, m) }

extension Optional: StoreContent where Wrapped: StoreContent {
    public var body: Never { return fatalError("primitive store content") }
}
extension Optional: _SKPrimitiveStoreContent where Wrapped: StoreContent {
    func _skNodes(_ mods: _SKContentMods) -> [_SKContentNode] { map { _skResolve($0, mods) } ?? [] }
}

/// store content with modifiers (subscriptionStoreOptionGroupStyle, subscriptionStoreButtonLabel, storeButton, ...)
public struct _SKModifiedStoreContent<Content: StoreContent>: StoreContent, _SKPrimitiveStoreContent {
    let content: Content
    let mods: _SKContentMods
    public var body: Never { return fatalError("primitive store content") }
    func _skNodes(_ outer: _SKContentMods) -> [_SKContentNode] { _skResolve(content, mods.merged(over: outer)) }
}

extension StoreContent {
    func _skModified(_ f: (inout _SKContentMods) -> Void) -> _SKModifiedStoreContent<Self> {
        var m = _SKContentMods(); f(&m)
        return _SKModifiedStoreContent(content: self, mods: m)
    }
    public func subscriptionStoreOptionGroupStyle<S: SubscriptionOptionGroupStyle>(_ style: S) -> some StoreContent { _skModified { $0.groupStyle = style._skGroupStyle } }
    public func subscriptionStoreButtonLabel(_ label: SubscriptionStoreButtonLabel) -> some StoreContent { _skModified { $0.buttonLabel = label } }
    public func storeButton(_ visibility: Visibility, for buttonKinds: StoreButtonKind...) -> some StoreContent {
        _skModified { m in for k in buttonKinds { m.buttons[k.name] = visibility } }
    }
    public func subscriptionStoreControlStyle<S: SubscriptionStoreControlStyle>(_ style: S) -> some StoreContent {
        _skModified { m in
            m.control = style._skControl
            if S.Body.self != Never.self { m.controlBody = { c in AnyView(style.makeBody(configuration: c)) } }
        }
    }
}

// MARK: - option groups

/// How SubscriptionStoreView shows option groups: tabs (a segmented control) or links (a list that opens each group).
@MainActor public protocol SubscriptionOptionGroupStyle { var _skGroupStyle: String { get } }
extension SubscriptionOptionGroupStyle { public var _skGroupStyle: String { "automatic" } }
public struct AutomaticSubscriptionOptionGroupStyle: SubscriptionOptionGroupStyle { public init() {}; public var _skGroupStyle: String { "automatic" } }
public struct TabsSubscriptionOptionGroupStyle: SubscriptionOptionGroupStyle { public init() {}; public var _skGroupStyle: String { "tabs" } }
public struct LinksSubscriptionOptionGroupStyle: SubscriptionOptionGroupStyle { public init() {}; public var _skGroupStyle: String { "links" } }
extension SubscriptionOptionGroupStyle where Self == AutomaticSubscriptionOptionGroupStyle { public static var automatic: Self { .init() } }
extension SubscriptionOptionGroupStyle where Self == TabsSubscriptionOptionGroupStyle { public static var tabs: Self { .init() } }
extension SubscriptionOptionGroupStyle where Self == LinksSubscriptionOptionGroupStyle { public static var links: Self { .init() } }

extension View {
    /// how the subscription store's option groups are shown (tabs or links)
    public func subscriptionStoreOptionGroupStyle<S: SubscriptionOptionGroupStyle>(_ style: S) -> some View { environment(\._skGroupStyle, style._skGroupStyle) }
}
struct _SKGroupStyleKey: EnvironmentKey { static var defaultValue: String { "automatic" } }
extension EnvironmentValues {
    var _skGroupStyle: String { get { self[_SKGroupStyleKey.self] } set { self[_SKGroupStyleKey.self] = newValue } }
}

/// A group's tab or link title, when the group has no label of its own.
public struct AutomaticSubscriptionOptionGroupLabel: View {
    let title: String
    public var body: some View { Text(verbatim: title) }
}

/// A group of plans (a tab or a link of the store), from a filter or from its sections.
public struct SubscriptionOptionGroup<Content: StoreContent, Label: View, MarketingContent: View>: StoreContent, _SKPrimitiveStoreContent {
    let title: String?
    let label: (() -> Label)?
    let marketing: (() -> MarketingContent)?
    let content: (() -> Content)?
    let filter: ((Product) -> Bool)?
    init(title: String?, label: (() -> Label)?, marketing: (() -> MarketingContent)?, content: (() -> Content)?, filter: ((Product) -> Bool)?) {
        self.title = title; self.label = label; self.marketing = marketing; self.content = content; self.filter = filter
    }
    public var body: Never { return fatalError("primitive store content") }
    func _skNodes(_ mods: _SKContentMods) -> [_SKContentNode] {
        [.group(title: title, label: label.map { AnyView($0()) }, marketing: marketing.map { AnyView($0()) }, filter: filter,
                children: content.map { _skResolve($0(), mods) } ?? [], mods: mods)]
    }
}

extension SubscriptionOptionGroup where Label == AutomaticSubscriptionOptionGroupLabel, MarketingContent == Never {
    public init(_ title: LocalizedStringKey, @StoreContentBuilder content: @escaping () -> Content) {
        self.init(title: _skString(title), label: nil, marketing: nil, content: content, filter: nil)
    }
    public init<S: StringProtocol>(_ title: S, @StoreContentBuilder content: @escaping () -> Content) {
        self.init(title: String(title), label: nil, marketing: nil, content: content, filter: nil)
    }
}
extension SubscriptionOptionGroup where Label == AutomaticSubscriptionOptionGroupLabel {
    public init(_ title: LocalizedStringKey, @StoreContentBuilder content: @escaping () -> Content, @ViewBuilder marketingContent: @escaping () -> MarketingContent) {
        self.init(title: _skString(title), label: nil, marketing: marketingContent, content: content, filter: nil)
    }
    public init<S: StringProtocol>(_ title: S, @StoreContentBuilder content: @escaping () -> Content, @ViewBuilder marketingContent: @escaping () -> MarketingContent) {
        self.init(title: String(title), label: nil, marketing: marketingContent, content: content, filter: nil)
    }
}
extension SubscriptionOptionGroup where Content == Never, Label == AutomaticSubscriptionOptionGroupLabel, MarketingContent == Never {
    public init(_ title: LocalizedStringKey, isIncluded: @escaping (Product) -> Bool) {
        self.init(title: _skString(title), label: nil, marketing: nil, content: nil, filter: isIncluded)
    }
    public init<S: StringProtocol>(_ title: S, isIncluded: @escaping (Product) -> Bool) {
        self.init(title: String(title), label: nil, marketing: nil, content: nil, filter: isIncluded)
    }
}
extension SubscriptionOptionGroup where Content == Never, Label == AutomaticSubscriptionOptionGroupLabel {
    public init(_ title: LocalizedStringKey, isIncluded: @escaping (Product) -> Bool, @ViewBuilder marketingContent: @escaping () -> MarketingContent) {
        self.init(title: _skString(title), label: nil, marketing: marketingContent, content: nil, filter: isIncluded)
    }
    public init<S: StringProtocol>(_ title: S, isIncluded: @escaping (Product) -> Bool, @ViewBuilder marketingContent: @escaping () -> MarketingContent) {
        self.init(title: String(title), label: nil, marketing: marketingContent, content: nil, filter: isIncluded)
    }
}
extension SubscriptionOptionGroup where Label == Never, MarketingContent == Never {
    public init(@StoreContentBuilder content: @escaping () -> Content) { self.init(title: nil, label: nil, marketing: nil, content: content, filter: nil) }
}
extension SubscriptionOptionGroup where MarketingContent == Never {
    public init(@StoreContentBuilder content: @escaping () -> Content, @ViewBuilder label: @escaping () -> Label) {
        self.init(title: nil, label: label, marketing: nil, content: content, filter: nil)
    }
}
extension SubscriptionOptionGroup {
    public init(@StoreContentBuilder content: @escaping () -> Content, @ViewBuilder label: @escaping () -> Label, @ViewBuilder marketingContent: @escaping () -> MarketingContent) {
        self.init(title: nil, label: label, marketing: marketingContent, content: content, filter: nil)
    }
}
extension SubscriptionOptionGroup where Label == Never {
    public init(@StoreContentBuilder content: @escaping () -> Content, @ViewBuilder marketingContent: @escaping () -> MarketingContent) {
        self.init(title: nil, label: nil, marketing: marketingContent, content: content, filter: nil)
    }
}
extension SubscriptionOptionGroup where Content == Never, Label == Never, MarketingContent == Never {
    public init(isIncluded: @escaping (Product) -> Bool) { self.init(title: nil, label: nil, marketing: nil, content: nil, filter: isIncluded) }
}
extension SubscriptionOptionGroup where Content == Never, MarketingContent == Never {
    public init(isIncluded: @escaping (Product) -> Bool, @ViewBuilder label: @escaping () -> Label) {
        self.init(title: nil, label: label, marketing: nil, content: nil, filter: isIncluded)
    }
}
extension SubscriptionOptionGroup where Content == Never {
    public init(isIncluded: @escaping (Product) -> Bool, @ViewBuilder label: @escaping () -> Label, @ViewBuilder marketingContent: @escaping () -> MarketingContent) {
        self.init(title: nil, label: label, marketing: marketingContent, content: nil, filter: isIncluded)
    }
}
extension SubscriptionOptionGroup where Content == Never, Label == Never {
    public init(isIncluded: @escaping (Product) -> Bool, @ViewBuilder marketingContent: @escaping () -> MarketingContent) {
        self.init(title: nil, label: nil, marketing: marketingContent, content: nil, filter: isIncluded)
    }
}

/// One option group per value of `groupedBy` over the store's plans (e.g. by billing period).
public struct SubscriptionOptionGroupSet<GroupID: Hashable, Label: View, MarketingContent: View>: StoreContent, _SKPrimitiveStoreContent {
    let key: (Product) -> GroupID
    let label: (GroupID) -> Label
    let marketing: ((GroupID) -> MarketingContent)?
    public var body: Never { return fatalError("primitive store content") }
    func _skNodes(_ mods: _SKContentMods) -> [_SKContentNode] {
        let k = key, l = label, m = marketing
        return [.groupSet(key: { AnyHashable(k($0)) }, label: { AnyView(l($0.base as! GroupID)) },
                          marketing: m.map { m in { AnyView(m($0.base as! GroupID)) } }, mods: mods)]
    }
}
extension SubscriptionOptionGroupSet where MarketingContent == Never {
    public init(idType: GroupID.Type = GroupID.self, groupedBy: @escaping (Product) -> GroupID, @ViewBuilder label: @escaping (GroupID) -> Label) {
        key = groupedBy; self.label = label; marketing = nil
    }
}
extension SubscriptionOptionGroupSet {
    public init(idType: GroupID.Type = GroupID.self, groupedBy: @escaping (Product) -> GroupID, @ViewBuilder label: @escaping (GroupID) -> Label,
                @ViewBuilder marketingContent: @escaping (GroupID) -> MarketingContent) {
        key = groupedBy; self.label = label; marketing = marketingContent
    }
}

/// Plans under a header and a footer, in the store or in an option group.
public struct SubscriptionOptionSection<Header: View, Content: StoreContent, Footer: View>: StoreContent, _SKPrimitiveStoreContent {
    let title: String?
    let header: (() -> Header)?
    let footer: () -> Footer
    let filter: (Product) -> Bool
    public var body: Never { return fatalError("primitive store content") }
    func _skNodes(_ mods: _SKContentMods) -> [_SKContentNode] {
        [.section(title: title, header: header.map { AnyView($0()) }, footer: AnyView(footer()), filter: filter, mods: mods)]
    }
}
extension SubscriptionOptionSection where Header == Text, Content == Never {
    public init(_ titleKey: LocalizedStringKey, isIncluded: @escaping (Product) -> Bool, @ViewBuilder footer: @escaping () -> Footer) {
        title = _skString(titleKey); header = nil; self.footer = footer; filter = isIncluded
    }
    public init<S: StringProtocol>(_ title: S, isIncluded: @escaping (Product) -> Bool, @ViewBuilder footer: @escaping () -> Footer) {
        self.title = String(title); header = nil; self.footer = footer; filter = isIncluded
    }
}
extension SubscriptionOptionSection where Content == Never {
    public init(isIncluded: @escaping (Product) -> Bool, @ViewBuilder header: @escaping () -> Header, @ViewBuilder footer: @escaping () -> Footer) {
        title = nil; self.header = header; self.footer = footer; filter = isIncluded
    }
}

/// a localized string key's text (isim resolves the key in the main bundle)
func _skString(_ key: LocalizedStringKey) -> String {
    let k = Mirror(reflecting: key).children.first { $0.label == "key" }?.value as? String ?? "\(key)"
    return Bundle.main.localizedString(forKey: k, value: k, table: nil)
}
