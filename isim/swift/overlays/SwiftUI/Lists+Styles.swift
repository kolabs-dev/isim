// isim SwiftUI: list styles and row / section modifiers — `listStyle` (`.automatic` / `.insetGrouped`, `.grouped`,
// `.plain`, `.inset`, `.sidebar`), `listRowBackground`, `listRowInsets`, `listRowSeparator` / `listRowSeparatorTint`,
// `listSectionSeparator`, `listRowSpacing`, `listSectionSpacing`, `scrollContentBackground`, `headerProminence`,
// `listItemTint`, `defaultMinListRowHeight` / `defaultMinListHeaderHeight` and `Section(isExpanded:)`.
// The list itself is Navigation.swift's _ListNode; the looks follow UITableView's styles (isim's UIKit metrics).
import UIKit

// MARK: - Styles

public protocol ListStyle {}
/// 0 automatic (inset grouped on iOS), 1 plain, 2 grouped, 3 inset, 4 sidebar, 5 inset grouped
protocol _ListStyleKind { var _kind: Int { get } }
public struct DefaultListStyle: ListStyle, _ListStyleKind { public init() {}; var _kind: Int { 0 } }
public struct PlainListStyle: ListStyle, _ListStyleKind { public init() {}; var _kind: Int { 1 } }
public struct GroupedListStyle: ListStyle, _ListStyleKind { public init() {}; var _kind: Int { 2 } }
public struct InsetListStyle: ListStyle, _ListStyleKind { public init() {}; var _kind: Int { 3 } }
public struct SidebarListStyle: ListStyle, _ListStyleKind { public init() {}; var _kind: Int { 4 } }
public struct InsetGroupedListStyle: ListStyle, _ListStyleKind { public init() {}; var _kind: Int { 5 } }
extension ListStyle where Self == DefaultListStyle { public static var automatic: DefaultListStyle { .init() } }
extension ListStyle where Self == PlainListStyle { public static var plain: PlainListStyle { .init() } }
extension ListStyle where Self == GroupedListStyle { public static var grouped: GroupedListStyle { .init() } }
extension ListStyle where Self == InsetListStyle { public static var inset: InsetListStyle { .init() } }
extension ListStyle where Self == SidebarListStyle { public static var sidebar: SidebarListStyle { .init() } }
extension ListStyle where Self == InsetGroupedListStyle { public static var insetGrouped: InsetGroupedListStyle { .init() } }

public protocol FormStyle {}
public struct AutomaticFormStyle: FormStyle { public init() {} }
public struct GroupedFormStyle: FormStyle { public init() {} }
public struct ColumnsFormStyle: FormStyle { public init() {} }
extension FormStyle where Self == AutomaticFormStyle { public static var automatic: AutomaticFormStyle { .init() } }
extension FormStyle where Self == GroupedFormStyle { public static var grouped: GroupedFormStyle { .init() } }
extension FormStyle where Self == ColumnsFormStyle { public static var columns: ColumnsFormStyle { .init() } }

public struct ListSectionSpacing: Sendable {
    let value: CGFloat?           // nil: the style's default
    public static let `default` = ListSectionSpacing(value: nil)
    public static let compact = ListSectionSpacing(value: 20)
    public static func custom(_ spacing: CGFloat) -> ListSectionSpacing { ListSectionSpacing(value: spacing) }
}

/// The look a list is drawn with (set by the modifiers, read by _makeList).
struct _ListLook {
    var kind = 0
    var hidesBackground = false
    var sectionSpacing: CGFloat?
    var rowSpacing: CGFloat?
    var minRowHeight: CGFloat = 44
    var minHeaderHeight: CGFloat?
    var plainLike: Bool { kind == 1 || kind == 3 }
    var grouped: Bool { kind == 0 || kind == 2 || kind == 5 }
    var sidebar: Bool { kind == 4 }
    /// the card's horizontal margin: inset grouped / inset / sidebar rows are inset from the edges
    var margin: CGFloat { kind == 1 || kind == 2 ? 0 : kind == 4 ? 10 : 20 }
    var cornerRadius: CGFloat { kind == 1 || kind == 2 ? 0 : 10 }
    var background: UIColor { hidesBackground ? .clear : plainLike ? .systemBackground : .systemGroupedBackground }
    var cardColor: UIColor { plainLike || sidebar ? .clear : .secondarySystemGroupedBackground }
}
struct _ListLookKey: EnvironmentKey { static var defaultValue: _ListLook { _ListLook() } }
struct _HeaderProminenceKey: EnvironmentKey { static var defaultValue: Prominence { .standard } }
struct _ListItemTintKey: EnvironmentKey { static var defaultValue: Color? { nil } }
struct _SectionSpacingKey: EnvironmentKey { static var defaultValue: CGFloat? { nil } }
extension EnvironmentValues {
    var _listLook: _ListLook { get { self[_ListLookKey.self] } set { self[_ListLookKey.self] = newValue } }
    public var headerProminence: Prominence { get { self[_HeaderProminenceKey.self] } set { self[_HeaderProminenceKey.self] = newValue } }
    var _listItemTint: Color? { get { self[_ListItemTintKey.self] } set { self[_ListItemTintKey.self] = newValue } }
    var _sectionSpacing: CGFloat? { get { self[_SectionSpacingKey.self] } set { self[_SectionSpacingKey.self] = newValue } }
    public var defaultMinListRowHeight: CGFloat { get { self[_ListLookKey.self].minRowHeight } set { self[_ListLookKey.self].minRowHeight = newValue } }
    public var defaultMinListHeaderHeight: CGFloat? { get { self[_ListLookKey.self].minHeaderHeight } set { self[_ListLookKey.self].minHeaderHeight = newValue } }
}

extension View {
    public func listStyle<S: ListStyle>(_ style: S) -> some View {
        let kind = (style as? _ListStyleKind)?._kind ?? 0
        return _env { $0._listLook.kind = kind }
    }
    /// (kept for apps built against isim 0.14 and older, which accepted any value here)
    @_disfavoredOverload public func listStyle<S>(_ style: S) -> some View {
        let kind = (style as? _ListStyleKind)?._kind ?? 0
        return _env { $0._listLook.kind = kind }
    }
    public func formStyle<S: FormStyle>(_ style: S) -> some View { self }
    @_disfavoredOverload public func formStyle<S>(_ style: S) -> some View { self }
    /// `.hidden`: the list (or form, or text editor) draws no background of its own, so what is behind it shows.
    public func scrollContentBackground(_ visibility: Visibility) -> some View {
        _env { $0._listLook.hidesBackground = visibility == .hidden; $0._scrollBackgroundHidden = visibility == .hidden }
    }
    public func listRowSpacing(_ spacing: CGFloat?) -> some View { _env { $0._listLook.rowSpacing = spacing } }
    public func listSectionSpacing(_ spacing: ListSectionSpacing) -> some View { _env { $0._sectionSpacing = spacing.value } }
    public func listSectionSpacing(_ spacing: CGFloat) -> some View { _env { $0._sectionSpacing = spacing } }
    public func headerProminence(_ p: Prominence) -> some View { _env { $0.headerProminence = p } }
    /// The tint of the list rows' icons (Label icons, row symbols) inside this view.
    public func listItemTint(_ tint: Color?) -> some View { _env { $0._listItemTint = tint } }
    public func listItemTint(_ tint: ListItemTint?) -> some View { _env { $0._listItemTint = tint?.color } }

    // row modifiers: applied to a row, a ForEach or a Section (then to each of its rows)
    public func listRowBackground<V: View>(_ view: V?) -> some View {
        let v = view.map { AnyView($0) }
        return _rowOptions { o, ctx, path in
            guard let v else { o.background = nil; o.backgroundSet = true; return }
            let n = _resolve(v, ctx.child(path).with { $0._inList = false })
            o.background = n; o.backgroundSet = true
        }
    }
    public func listRowInsets(_ insets: EdgeInsets?) -> some View { _rowOptions { o, _, _ in o.insets = insets; o.insetsSet = true } }
    public func listRowSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View {
        _rowOptions { o, _, _ in
            let hidden = visibility == .hidden ? true : visibility == .visible ? false : nil
            if edges.contains(.top) { o.topSeparator = hidden }
            if edges.contains(.bottom) { o.bottomSeparator = hidden }
        }
    }
    public func listRowSeparatorTint(_ color: Color?, edges: VerticalEdge.Set = .all) -> some View {
        _rowOptions { o, _, _ in
            if edges.contains(.top) { o.topTint = color }
            if edges.contains(.bottom) { o.bottomTint = color }
        }
    }
    public func listSectionSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View {
        _sectionOptions { s in
            let hidden = visibility == .hidden
            if edges.contains(.top) { s.topSeparatorHidden = hidden }
            if edges.contains(.bottom) { s.bottomSeparatorHidden = hidden }
        }
    }
    public func listSectionSeparatorTint(_ color: Color?, edges: VerticalEdge.Set = .all) -> some View { _sectionOptions { $0.separatorTint = color } }

    /// Row options: wraps the row, or each row of a ForEach / Section the modifier is applied to.
    func _rowOptions(_ set: @escaping @MainActor (_ListRowOptions, _Context, String) -> Void) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("lro"))
            var k = 0
            @MainActor func wrap(_ r: _Node) -> _Node {
                let o = (r as? _ListRowOptionsNode) ?? _ListRowOptionsNode(path: r.path + "/lro", child: r)
                set(o.options, ctx, "lrobg\(k)"); k += 1
                return o
            }
            if let s = n as? _SectionNode { s.rows = s.rows.map(wrap); s.children = s.rows; return s }
            if n is _GroupNode { n.children = n.children.map(wrap); return n }
            return wrap(n)
        }
    }
    func _sectionOptions(_ set: @escaping @MainActor (_SectionNode) -> Void) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("lso"))
            if let s = n as? _SectionNode { set(s) } else if let l = n as? _ListNode { for s in l.sections { set(s) } }
            return n
        }
    }
}
struct _ScrollBackgroundHiddenKey: EnvironmentKey { static var defaultValue: Bool { false } }
extension EnvironmentValues { var _scrollBackgroundHidden: Bool { get { self[_ScrollBackgroundHiddenKey.self] } set { self[_ScrollBackgroundHiddenKey.self] = newValue } } }

public struct ListItemTint: Sendable {
    let color: Color?
    public static func fixed(_ tint: Color) -> ListItemTint { ListItemTint(color: tint) }
    public static func preferred(_ tint: Color) -> ListItemTint { ListItemTint(color: tint) }
    public static let monochrome = ListItemTint(color: .gray)
}

/// A row's own options (innermost modifier wins).
final class _ListRowOptions {
    var background: _Node?
    var backgroundSet = false
    var insets: EdgeInsets?
    var insetsSet = false
    var topSeparator: Bool?, bottomSeparator: Bool?           // true: hidden, false: shown, nil: automatic
    var topTint: Color?, bottomTint: Color?
}
final class _ListRowOptionsNode: _WrapperNode {
    let options = _ListRowOptions()
    override init(path: String, child: _Node) { super.init(path: path, child: child); tag = child.tag; badge = child.badge }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}
/// The options that apply to a row: the innermost modifier of each kind wins.
@MainActor func _listRowOptions(_ row: _Node) -> _ListRowOptions {
    let out = _ListRowOptions()
    var x: _Node? = row
    while let n = x {
        if let o = (n as? _ListRowOptionsNode)?.options {
            if o.backgroundSet { out.background = o.background; out.backgroundSet = true }
            if o.insetsSet { out.insets = o.insets; out.insetsSet = true }
            if let t = o.topSeparator { out.topSeparator = t }
            if let b = o.bottomSeparator { out.bottomSeparator = b }
            if let t = o.topTint { out.topTint = t }
            if let b = o.bottomTint { out.bottomTint = b }
        }
        x = n.children.count == 1 && !(n is _StackNode) ? n.children[0] : nil
    }
    return out
}

// MARK: - Section(isExpanded:)

extension Section where Parent == Text, Footer == EmptyView {
    /// A collapsible section (iOS 17): the header shows a chevron and toggles the binding.
    public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.init(header: Text(titleKey), content: content(), footer: nil, isExpanded: isExpanded)
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.init(header: Text(title), content: content(), footer: nil, isExpanded: isExpanded)
    }
}
extension Section where Footer == EmptyView {
    public init(isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) {
        self.init(header: header(), content: content(), footer: nil, isExpanded: isExpanded)
    }
}
