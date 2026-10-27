// isim SwiftUI: Table — TableColumn / TableColumnContent / TableColumnBuilder, TableRow / TableRowContent /
// TableRowBuilder, ForEach and outline rows, column customization, TableStyle (Table+Inits.swift: the initialisers).
// Adapted, as on iOS: in a compact width (iPhone) a table is a list of its first column; in a regular width (iPad) it
// shows a header row and the columns side by side (sized by their widths), and tapping a sortable column's header sorts
// by it (again: the other way), updating the table's sortOrder. Rows are isim's List rows: selection, context menus,
// drag and drop and hover work as they do in a List. Outline rows (children:, DisclosureTableRow) show expanded,
// indented under their parents.
import UIKit
import UniformTypeIdentifiers
import CoreTransferable

extension Never: @retroactive SortComparator {
    public typealias Compared = Never
    public func compare(_ lhs: Never, _ rhs: Never) -> ComparisonResult {}
    public var order: SortOrder { get { .forward } set {} }
}

// MARK: - Columns

/// The columns of a table.
public protocol TableColumnContent<TableRowValue, TableColumnSortComparator> {
    associatedtype TableRowValue: Identifiable = TableColumnBody.TableRowValue
    associatedtype TableColumnSortComparator: SortComparator = TableColumnBody.TableColumnSortComparator
    associatedtype TableColumnBody: TableColumnContent
    @TableColumnBuilder<TableRowValue, TableColumnSortComparator> var tableColumnBody: TableColumnBody { get }
}
extension Never: TableColumnContent {
    public typealias TableRowValue = Never
    public typealias TableColumnSortComparator = Never
    public var tableColumnBody: Never { return fatalError() }
}

/// One column, as isim lays it out.
struct _TableColumnSpec {
    let label: AnyView
    let cell: @MainActor (Any) -> AnyView
    var width: CGFloat?, minWidth: CGFloat?, idealWidth: CGFloat?, maxWidth: CGFloat?
    var alignment = TableColumnAlignment.automatic
    var comparator: AnyHashable?           // the column's sort comparator (forward), when it sorts
    var sortKey: AnyHashable?              // what identifies it (_sortKey)
    var customizationID: String?
    var defaultVisibility = Visibility.automatic
}
/// Column content isim knows the columns of (else: its tableColumnBody).
protocol _TableColumnSource { var _columns: [_TableColumnSpec] { get } }
func _tableColumns(_ c: any TableColumnContent) -> [_TableColumnSpec] {
    if let s = c as? _TableColumnSource { return s._columns }
    return _tableColumns(_columnBody(c))
}
func _columnBody<C: TableColumnContent>(_ c: C) -> any TableColumnContent { c.tableColumnBody }

/// A column: a label, the view of each row's value, a width and a sort comparator.
public struct TableColumn<RowValue: Identifiable, Sort: SortComparator, Content: View, Label: View>: TableColumnContent, _TableColumnSource {
    public typealias TableRowValue = RowValue
    public typealias TableColumnSortComparator = Sort
    public var tableColumnBody: Never { return fatalError() }
    var spec: _TableColumnSpec
    var _columns: [_TableColumnSpec] { [spec] }
    init(label: Label, content: @escaping (RowValue) -> Content) {
        spec = _TableColumnSpec(label: AnyView(label), cell: { v in AnyView(content(v as! RowValue)) })
    }
    init<C: SortComparator>(label: Label, comparator: C, content: @escaping (RowValue) -> Content) {
        self.init(label: label, content: content)
        var f = comparator; f.order = .forward
        spec.comparator = AnyHashable(f); spec.sortKey = _sortKey(f)
    }
    /// A fixed width (nil: the default).
    public func width(_ width: CGFloat?) -> TableColumn { var c = self; c.spec.width = width; return c }
    /// A flexible width.
    public func width(min: CGFloat? = nil, ideal: CGFloat? = nil, max: CGFloat? = nil) -> TableColumn {
        var c = self; c.spec.width = nil; c.spec.minWidth = min; c.spec.idealWidth = ideal; c.spec.maxWidth = max; return c
    }
    /// The default width.
    public func width() -> TableColumn { var c = self; c.spec.width = nil; c.spec.minWidth = nil; c.spec.idealWidth = nil; c.spec.maxWidth = nil; return c }
}

extension TableColumn where Sort == Never, Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: @escaping (RowValue) -> Content) { self.init(label: Text(titleKey), content: content) }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: @escaping (RowValue) -> Content) { self.init(label: Text(title), content: content) }
    public init(_ text: Text, @ViewBuilder content: @escaping (RowValue) -> Content) { self.init(label: text, content: content) }
}
extension TableColumn where Sort == Never, Content == Text, Label == Text {
    public init(_ titleKey: LocalizedStringKey, value: KeyPath<RowValue, String>) { self.init(label: Text(titleKey)) { Text($0[keyPath: value]) } }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, value: KeyPath<RowValue, String>) { self.init(label: Text(title)) { Text($0[keyPath: value]) } }
    public init(_ text: Text, value: KeyPath<RowValue, String>) { self.init(label: text) { Text($0[keyPath: value]) } }
}
extension TableColumn where Sort == KeyPathComparator<RowValue>, Label == Text {
    public init<V: Comparable>(_ titleKey: LocalizedStringKey, value: KeyPath<RowValue, V>, @ViewBuilder content: @escaping (RowValue) -> Content) {
        self.init(label: Text(titleKey), comparator: KeyPathComparator(value), content: content)
    }
    @_disfavoredOverload public init<S: StringProtocol, V: Comparable>(_ title: S, value: KeyPath<RowValue, V>, @ViewBuilder content: @escaping (RowValue) -> Content) {
        self.init(label: Text(title), comparator: KeyPathComparator(value), content: content)
    }
    public init<V: Comparable>(_ text: Text, value: KeyPath<RowValue, V>, @ViewBuilder content: @escaping (RowValue) -> Content) {
        self.init(label: text, comparator: KeyPathComparator(value), content: content)
    }
    public init<V, C: SortComparator>(_ titleKey: LocalizedStringKey, value: KeyPath<RowValue, V>, comparator: C, @ViewBuilder content: @escaping (RowValue) -> Content)
        where C.Compared == V {
        self.init(label: Text(titleKey), comparator: KeyPathComparator(value, comparator: comparator), content: content)
    }
    @_disfavoredOverload public init<S: StringProtocol, V, C: SortComparator>(_ title: S, value: KeyPath<RowValue, V>, comparator: C,
                                                                           @ViewBuilder content: @escaping (RowValue) -> Content) where C.Compared == V {
        self.init(label: Text(title), comparator: KeyPathComparator(value, comparator: comparator), content: content)
    }
    public init<V, C: SortComparator>(_ text: Text, value: KeyPath<RowValue, V>, comparator: C, @ViewBuilder content: @escaping (RowValue) -> Content)
        where C.Compared == V {
        self.init(label: text, comparator: KeyPathComparator(value, comparator: comparator), content: content)
    }
}
extension TableColumn where Sort == KeyPathComparator<RowValue>, Content == Text, Label == Text {
    public init(_ titleKey: LocalizedStringKey, value: KeyPath<RowValue, String>, comparator: String.StandardComparator = .localizedStandard) {
        self.init(label: Text(titleKey), comparator: KeyPathComparator(value, comparator: comparator)) { Text($0[keyPath: value]) }
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, value: KeyPath<RowValue, String>, comparator: String.StandardComparator = .localizedStandard) {
        self.init(label: Text(title), comparator: KeyPathComparator(value, comparator: comparator)) { Text($0[keyPath: value]) }
    }
    public init(_ text: Text, value: KeyPath<RowValue, String>, comparator: String.StandardComparator = .localizedStandard) {
        self.init(label: text, comparator: KeyPathComparator(value, comparator: comparator)) { Text($0[keyPath: value]) }
    }
}
extension TableColumn where Label == Text {
    /// A column sorted with `comparator`.
    public init(_ titleKey: LocalizedStringKey, sortUsing comparator: Sort, @ViewBuilder content: @escaping (RowValue) -> Content) where Sort.Compared == RowValue {
        var c = comparator; c.order = .forward
        self.init(label: Text(titleKey), comparator: c, content: content)
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, sortUsing comparator: Sort, @ViewBuilder content: @escaping (RowValue) -> Content)
        where Sort.Compared == RowValue {
        var c = comparator; c.order = .forward
        self.init(label: Text(title), comparator: c, content: content)
    }
    public init(_ text: Text, sortUsing comparator: Sort, @ViewBuilder content: @escaping (RowValue) -> Content) where Sort.Compared == RowValue {
        var c = comparator; c.order = .forward
        self.init(label: text, comparator: c, content: content)
    }
}

/// How a column's cells line up.
public struct TableColumnAlignment: Hashable, Sendable {
    let kind: Int
    public static var automatic: TableColumnAlignment { TableColumnAlignment(kind: 0) }
    public static var leading: TableColumnAlignment { TableColumnAlignment(kind: 1) }
    public static var center: TableColumnAlignment { TableColumnAlignment(kind: 2) }
    public static var trailing: TableColumnAlignment { TableColumnAlignment(kind: 3) }
    /// Numbers: trailing in left-to-right text.
    public static var numeric: TableColumnAlignment { TableColumnAlignment(kind: 4) }
    public static func numeric(_ numberingSystem: Locale.NumberingSystem) -> TableColumnAlignment { .numeric }
    var frameAlignment: Alignment { kind == 2 ? .center : kind == 3 || kind == 4 ? .trailing : .leading }
}

/// Which customizations of a column the person may make.
public struct TableColumnCustomizationBehavior: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public init() { rawValue = 0 }
    public static let reorder = TableColumnCustomizationBehavior(rawValue: 1)
    public static let resize = TableColumnCustomizationBehavior(rawValue: 2)
    public static let visibility = TableColumnCustomizationBehavior(rawValue: 4)
    public static var all: TableColumnCustomizationBehavior { [.reorder, .resize, .visibility] }
}

/// A table's column customizations: which columns are shown (by customization ID).
public struct TableColumnCustomization<RowValue: Identifiable>: Equatable, Sendable, Codable {
    var visibility: [String: Int] = [:]          // 0 automatic, 1 visible, 2 hidden
    var order: [String] = []
    public init() {}
    public subscript(visibility id: String) -> Visibility {
        get { switch visibility[id] { case 1?: return .visible; case 2?: return .hidden; default: return .automatic } }
        set { visibility[id] = newValue == .visible ? 1 : newValue == .hidden ? 2 : 0 }
    }
    /// Back to the columns' own order.
    public mutating func resetOrder() { order = [] }
}

/// Column content with one attribute changed.
struct _ModifiedTableColumns<Base: TableColumnContent>: TableColumnContent, _TableColumnSource {
    typealias TableRowValue = Base.TableRowValue
    typealias TableColumnSortComparator = Base.TableColumnSortComparator
    var tableColumnBody: Never { return fatalError() }
    let base: Base, change: (inout _TableColumnSpec) -> Void
    var _columns: [_TableColumnSpec] { _tableColumns(base).map { var s = $0; change(&s); return s } }
}
extension TableColumnContent {
    /// How the column's cells line up.
    public func alignment(_ alignment: TableColumnAlignment) -> some TableColumnContent<TableRowValue, TableColumnSortComparator> {
        _ModifiedTableColumns(base: self) { $0.alignment = alignment }
    }
    /// The column's ID in a TableColumnCustomization.
    public func customizationID(_ id: String) -> some TableColumnContent<TableRowValue, TableColumnSortComparator> {
        _ModifiedTableColumns(base: self) { $0.customizationID = id }
    }
    /// Whether the column shows when its customization does not say.
    public func defaultVisibility(_ visibility: Visibility) -> some TableColumnContent<TableRowValue, TableColumnSortComparator> {
        _ModifiedTableColumns(base: self) { $0.defaultVisibility = visibility }
    }
    /// Customizations the person may not make (isim: tables are not customized interactively).
    public func disabledCustomizationBehavior(_ behavior: TableColumnCustomizationBehavior) -> some TableColumnContent<TableRowValue, TableColumnSortComparator> {
        _ModifiedTableColumns(base: self) { _ in }
    }
}

/// Several columns.
public struct TupleTableColumnContent<RowValue: Identifiable, Sort: SortComparator, T>: TableColumnContent, _TableColumnSource {
    public typealias TableRowValue = RowValue
    public typealias TableColumnSortComparator = Sort
    public var value: T
    let parts: [any TableColumnContent]
    init(value: T, parts: [any TableColumnContent]) { self.value = value; self.parts = parts }
    public var tableColumnBody: Never { return fatalError() }
    var _columns: [_TableColumnSpec] {
        // (a column sorted another way than the table cannot sort it)
        parts.flatMap(_tableColumns).map { s in
            var s = s
            if Sort.self == Never.self { s.comparator = nil }
            else if let c = s.comparator, !(c.base is Sort) { s.comparator = nil }
            return s
        }
    }
}
extension Optional: TableColumnContent where Wrapped: TableColumnContent {
    public typealias TableRowValue = Wrapped.TableRowValue
    public typealias TableColumnSortComparator = Wrapped.TableColumnSortComparator
    public var tableColumnBody: Never { return fatalError() }
}
extension Optional: _TableColumnSource where Wrapped: TableColumnContent {
    var _columns: [_TableColumnSpec] { map { _tableColumns($0) } ?? [] }
}

/// Columns made from data.
public struct TableColumnForEach<Data: RandomAccessCollection, ID: Hashable, RowValue: Identifiable, Sort: SortComparator, Content: TableColumnContent>:
    TableColumnContent, _TableColumnSource where Content.TableRowValue == RowValue, Content.TableColumnSortComparator == Sort {
    public typealias TableRowValue = RowValue
    public typealias TableColumnSortComparator = Sort
    public var data: Data
    public var content: (Data.Element) -> Content
    public var tableColumnBody: Never { return fatalError() }
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @TableColumnBuilder<RowValue, Sort> content: @escaping (Data.Element) -> Content) {
        self.data = data; self.content = content
    }
    var _columns: [_TableColumnSpec] { data.flatMap { _tableColumns(content($0)) } }
}
extension TableColumnForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @TableColumnBuilder<RowValue, Sort> content: @escaping (Data.Element) -> Content) { self.data = data; self.content = content }
}

/// Builds a table's columns.
@resultBuilder
public struct TableColumnBuilder<RowValue: Identifiable, Sort: SortComparator> {
    public static func buildExpression<Content: TableColumnContent>(_ content: Content) -> Content
        where Content.TableRowValue == RowValue, Content.TableColumnSortComparator == Sort { content }
    /// (a column sorted another way, or not at all: its sorting is left out)
    public static func buildExpression<Content: TableColumnContent>(_ content: Content) -> TupleTableColumnContent<RowValue, Sort, Content>
        where Content.TableRowValue == RowValue { TupleTableColumnContent(value: content, parts: [content]) }
    public static func buildBlock<C0: TableColumnContent>(_ c0: C0) -> C0 where C0.TableRowValue == RowValue, C0.TableColumnSortComparator == Sort { c0 }
    public static func buildBlock<C0: TableColumnContent, C1: TableColumnContent>(_ c0: C0, _ c1: C1) -> TupleTableColumnContent<RowValue, Sort, (C0, C1)>
        where C0.TableRowValue == RowValue, C0.TableColumnSortComparator == Sort, C1.TableRowValue == RowValue, C1.TableColumnSortComparator == Sort {
        TupleTableColumnContent(value: (c0, c1), parts: [c0, c1])
    }
    public static func buildBlock<C0: TableColumnContent, C1: TableColumnContent, C2: TableColumnContent>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2)>
        where C0.TableRowValue == RowValue, C0.TableColumnSortComparator == Sort, C1.TableRowValue == RowValue, C1.TableColumnSortComparator == Sort, C2.TableRowValue == RowValue, C2.TableColumnSortComparator == Sort {
        TupleTableColumnContent(value: (c0, c1, c2), parts: [c0, c1, c2])
    }
    public static func buildBlock<C0: TableColumnContent, C1: TableColumnContent, C2: TableColumnContent, C3: TableColumnContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3)>
        where C0.TableRowValue == RowValue, C0.TableColumnSortComparator == Sort, C1.TableRowValue == RowValue, C1.TableColumnSortComparator == Sort, C2.TableRowValue == RowValue, C2.TableColumnSortComparator == Sort, C3.TableRowValue == RowValue, C3.TableColumnSortComparator == Sort {
        TupleTableColumnContent(value: (c0, c1, c2, c3), parts: [c0, c1, c2, c3])
    }
    public static func buildBlock<C0: TableColumnContent, C1: TableColumnContent, C2: TableColumnContent, C3: TableColumnContent, C4: TableColumnContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4)>
        where C0.TableRowValue == RowValue, C0.TableColumnSortComparator == Sort, C1.TableRowValue == RowValue, C1.TableColumnSortComparator == Sort, C2.TableRowValue == RowValue, C2.TableColumnSortComparator == Sort, C3.TableRowValue == RowValue, C3.TableColumnSortComparator == Sort, C4.TableRowValue == RowValue, C4.TableColumnSortComparator == Sort {
        TupleTableColumnContent(value: (c0, c1, c2, c3, c4), parts: [c0, c1, c2, c3, c4])
    }
    public static func buildBlock<C0: TableColumnContent, C1: TableColumnContent, C2: TableColumnContent, C3: TableColumnContent, C4: TableColumnContent, C5: TableColumnContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4, C5)>
        where C0.TableRowValue == RowValue, C0.TableColumnSortComparator == Sort, C1.TableRowValue == RowValue, C1.TableColumnSortComparator == Sort, C2.TableRowValue == RowValue, C2.TableColumnSortComparator == Sort, C3.TableRowValue == RowValue, C3.TableColumnSortComparator == Sort, C4.TableRowValue == RowValue, C4.TableColumnSortComparator == Sort, C5.TableRowValue == RowValue, C5.TableColumnSortComparator == Sort {
        TupleTableColumnContent(value: (c0, c1, c2, c3, c4, c5), parts: [c0, c1, c2, c3, c4, c5])
    }
    public static func buildBlock<C0: TableColumnContent, C1: TableColumnContent, C2: TableColumnContent, C3: TableColumnContent, C4: TableColumnContent, C5: TableColumnContent, C6: TableColumnContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4, C5, C6)>
        where C0.TableRowValue == RowValue, C0.TableColumnSortComparator == Sort, C1.TableRowValue == RowValue, C1.TableColumnSortComparator == Sort, C2.TableRowValue == RowValue, C2.TableColumnSortComparator == Sort, C3.TableRowValue == RowValue, C3.TableColumnSortComparator == Sort, C4.TableRowValue == RowValue, C4.TableColumnSortComparator == Sort, C5.TableRowValue == RowValue, C5.TableColumnSortComparator == Sort, C6.TableRowValue == RowValue, C6.TableColumnSortComparator == Sort {
        TupleTableColumnContent(value: (c0, c1, c2, c3, c4, c5, c6), parts: [c0, c1, c2, c3, c4, c5, c6])
    }
    public static func buildBlock<C0: TableColumnContent, C1: TableColumnContent, C2: TableColumnContent, C3: TableColumnContent, C4: TableColumnContent, C5: TableColumnContent, C6: TableColumnContent, C7: TableColumnContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4, C5, C6, C7)>
        where C0.TableRowValue == RowValue, C0.TableColumnSortComparator == Sort, C1.TableRowValue == RowValue, C1.TableColumnSortComparator == Sort, C2.TableRowValue == RowValue, C2.TableColumnSortComparator == Sort, C3.TableRowValue == RowValue, C3.TableColumnSortComparator == Sort, C4.TableRowValue == RowValue, C4.TableColumnSortComparator == Sort, C5.TableRowValue == RowValue, C5.TableColumnSortComparator == Sort, C6.TableRowValue == RowValue, C6.TableColumnSortComparator == Sort, C7.TableRowValue == RowValue, C7.TableColumnSortComparator == Sort {
        TupleTableColumnContent(value: (c0, c1, c2, c3, c4, c5, c6, c7), parts: [c0, c1, c2, c3, c4, c5, c6, c7])
    }
    public static func buildBlock<C0: TableColumnContent, C1: TableColumnContent, C2: TableColumnContent, C3: TableColumnContent, C4: TableColumnContent, C5: TableColumnContent, C6: TableColumnContent, C7: TableColumnContent, C8: TableColumnContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4, C5, C6, C7, C8)>
        where C0.TableRowValue == RowValue, C0.TableColumnSortComparator == Sort, C1.TableRowValue == RowValue, C1.TableColumnSortComparator == Sort, C2.TableRowValue == RowValue, C2.TableColumnSortComparator == Sort, C3.TableRowValue == RowValue, C3.TableColumnSortComparator == Sort, C4.TableRowValue == RowValue, C4.TableColumnSortComparator == Sort, C5.TableRowValue == RowValue, C5.TableColumnSortComparator == Sort, C6.TableRowValue == RowValue, C6.TableColumnSortComparator == Sort, C7.TableRowValue == RowValue, C7.TableColumnSortComparator == Sort, C8.TableRowValue == RowValue, C8.TableColumnSortComparator == Sort {
        TupleTableColumnContent(value: (c0, c1, c2, c3, c4, c5, c6, c7, c8), parts: [c0, c1, c2, c3, c4, c5, c6, c7, c8])
    }
    public static func buildBlock<C0: TableColumnContent, C1: TableColumnContent, C2: TableColumnContent, C3: TableColumnContent, C4: TableColumnContent, C5: TableColumnContent, C6: TableColumnContent, C7: TableColumnContent, C8: TableColumnContent, C9: TableColumnContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleTableColumnContent<RowValue, Sort, (C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)>
        where C0.TableRowValue == RowValue, C0.TableColumnSortComparator == Sort, C1.TableRowValue == RowValue, C1.TableColumnSortComparator == Sort, C2.TableRowValue == RowValue, C2.TableColumnSortComparator == Sort, C3.TableRowValue == RowValue, C3.TableColumnSortComparator == Sort, C4.TableRowValue == RowValue, C4.TableColumnSortComparator == Sort, C5.TableRowValue == RowValue, C5.TableColumnSortComparator == Sort, C6.TableRowValue == RowValue, C6.TableColumnSortComparator == Sort, C7.TableRowValue == RowValue, C7.TableColumnSortComparator == Sort, C8.TableRowValue == RowValue, C8.TableColumnSortComparator == Sort, C9.TableRowValue == RowValue, C9.TableColumnSortComparator == Sort {
        TupleTableColumnContent(value: (c0, c1, c2, c3, c4, c5, c6, c7, c8, c9), parts: [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9])
    }
    public static func buildIf<C: TableColumnContent>(_ c: C?) -> C? where C.TableRowValue == RowValue, C.TableColumnSortComparator == Sort { c }
    public static func buildEither<T: TableColumnContent>(first: T) -> TupleTableColumnContent<RowValue, Sort, T>
        where T.TableRowValue == RowValue { TupleTableColumnContent(value: first, parts: [first]) }
    public static func buildEither<F: TableColumnContent>(second: F) -> TupleTableColumnContent<RowValue, Sort, F>
        where F.TableRowValue == RowValue { TupleTableColumnContent(value: second, parts: [second]) }
    public static func buildLimitedAvailability<C: TableColumnContent>(_ c: C) -> TupleTableColumnContent<RowValue, Sort, C>
        where C.TableRowValue == RowValue { TupleTableColumnContent(value: c, parts: [c]) }
}

// MARK: - Rows

/// The rows of a table.
public protocol TableRowContent<TableRowValue> {
    associatedtype TableRowValue: Identifiable = TableRowBody.TableRowValue
    associatedtype TableRowBody: TableRowContent
    @TableRowBuilder<TableRowValue> var tableRowBody: TableRowBody { get }
}
extension Never: TableRowContent {
    public typealias TableRowBody = Never
    public var tableRowBody: Never { return fatalError() }
}

/// One row, as isim shows it.
struct _TableRowItem {
    let value: Any
    let id: AnyHashable
    var depth = 0
    var wraps: [@MainActor (AnyView) -> AnyView] = []
    var selectable = true
}
protocol _TableRowSource { var _rows: [_TableRowItem] { get } }
func _tableRows(_ r: any TableRowContent) -> [_TableRowItem] {
    if let s = r as? _TableRowSource { return s._rows }
    return _tableRows(_rowBody(r))
}
func _rowBody<R: TableRowContent>(_ r: R) -> any TableRowContent { r.tableRowBody }

/// A row for a value.
public struct TableRow<Value: Identifiable>: TableRowContent, _TableRowSource {
    public typealias TableRowValue = Value
    let value: Value
    public init(_ value: Value) { self.value = value }
    public var tableRowBody: Never { return fatalError() }
    var _rows: [_TableRowItem] { [_TableRowItem(value: value, id: AnyHashable(value.id))] }
}

/// No rows.
public struct EmptyTableRowContent<Value: Identifiable>: TableRowContent, _TableRowSource {
    public typealias TableRowValue = Value
    public init() {}
    public var tableRowBody: Never { return fatalError() }
    var _rows: [_TableRowItem] { [] }
}

/// Several rows.
public struct TupleTableRowContent<Value: Identifiable, T>: TableRowContent, _TableRowSource {
    public typealias TableRowValue = Value
    public var value: T
    let parts: [any TableRowContent]
    init(value: T, parts: [any TableRowContent]) { self.value = value; self.parts = parts }
    public var tableRowBody: Never { return fatalError() }
    var _rows: [_TableRowItem] { parts.flatMap(_tableRows) }
}

/// A row for each element of a collection.
public struct TableForEachContent<Data: RandomAccessCollection>: TableRowContent, _TableRowSource where Data.Element: Identifiable {
    public typealias TableRowValue = Data.Element
    let data: Data
    public var tableRowBody: Never { return fatalError() }
    var _rows: [_TableRowItem] { data.map { _TableRowItem(value: $0, id: AnyHashable($0.id)) } }
}

/// Rows for a tree: each element, then (indented) its children.
public struct TableOutlineGroupContent<Data: RandomAccessCollection>: TableRowContent, _TableRowSource where Data.Element: Identifiable {
    public typealias TableRowValue = Data.Element
    let data: Data, children: KeyPath<Data.Element, Data?>
    public var tableRowBody: Never { return fatalError() }
    var _rows: [_TableRowItem] {
        var out: [_TableRowItem] = []
        func add(_ d: Data, _ depth: Int) {
            for e in d {
                out.append(_TableRowItem(value: e, id: AnyHashable(e.id), depth: depth))
                if let c = e[keyPath: children] { add(c, depth + 1) }
            }
        }
        add(data, 0)
        return out
    }
}

/// A row that discloses rows under it.
public struct DisclosureTableRow<Label: TableRowContent, Content: TableRowContent>: TableRowContent, _TableRowSource
    where Label.TableRowValue == Content.TableRowValue {
    public typealias TableRowValue = Label.TableRowValue
    let label: Label, content: Content, isExpanded: Binding<Bool>?
    public init<Value>(_ value: Value, isExpanded: Binding<Bool>? = nil, @TableRowBuilder<Value> content: () -> Content)
        where Label == TableRow<Value>, Value == Content.TableRowValue {
        label = TableRow(value); self.content = content(); self.isExpanded = isExpanded
    }
    public var tableRowBody: Never { return fatalError() }
    var _rows: [_TableRowItem] {
        let head = _tableRows(label)
        guard isExpanded?.wrappedValue ?? true else { return head }
        return head + _tableRows(content).map { var r = $0; r.depth += 1; return r }
    }
}

extension ForEach: TableRowContent where Content: TableRowContent {
    public typealias TableRowValue = Content.TableRowValue
    public typealias TableRowBody = Never
    public var tableRowBody: Never { return fatalError() }
}
extension ForEach: _TableRowSource where Content: TableRowContent {
    var _rows: [_TableRowItem] { data.flatMap { _tableRows(content($0)) } }
}
extension ForEach where Content: TableRowContent {
    public init<V>(_ data: Data, @TableRowBuilder<V> content: @escaping (Data.Element) -> Content)
        where ID == Data.Element.ID, Data.Element: Identifiable, V == Content.TableRowValue {
        self.init(_data: data, _id: { $0.id }, _content: content)
    }
    public init<V>(_ data: Data, id: KeyPath<Data.Element, ID>, @TableRowBuilder<V> content: @escaping (Data.Element) -> Content)
        where V == Content.TableRowValue {
        self.init(_data: data, _id: { $0[keyPath: id] }, _content: content)
    }
}

/// Rows made from a collection (they can take inserted items).
public protocol DynamicTableRowContent: TableRowContent {
    associatedtype Data: Collection
    var data: Data { get }
}
extension ForEach: DynamicTableRowContent where Content: TableRowContent {}

extension Optional: TableRowContent where Wrapped: TableRowContent {
    public typealias TableRowValue = Wrapped.TableRowValue
    public typealias TableRowBody = Never
    public var tableRowBody: Never { return fatalError() }
}
extension Optional: _TableRowSource where Wrapped: TableRowContent {
    var _rows: [_TableRowItem] { map { _tableRows($0) } ?? [] }
}

/// Either of two row contents.
public struct _ConditionalTableRowContent<TrueContent: TableRowContent, FalseContent: TableRowContent>: TableRowContent, _TableRowSource
    where TrueContent.TableRowValue == FalseContent.TableRowValue {
    public typealias TableRowValue = TrueContent.TableRowValue
    let rows: [_TableRowItem]
    public var tableRowBody: Never { return fatalError() }
    var _rows: [_TableRowItem] { rows }
}

/// Builds a table's rows.
@resultBuilder
public struct TableRowBuilder<Value: Identifiable> {
    public static func buildExpression<Content: TableRowContent>(_ content: Content) -> Content where Content.TableRowValue == Value { content }
    public static func buildBlock<C: TableRowContent>(_ content: C) -> C where C.TableRowValue == Value { content }
    public static func buildBlock<C0: TableRowContent, C1: TableRowContent>(_ c0: C0, _ c1: C1) -> TupleTableRowContent<Value, (C0, C1)>
        where C0.TableRowValue == Value, C1.TableRowValue == Value {
        TupleTableRowContent(value: (c0, c1), parts: [c0, c1])
    }
    public static func buildBlock<C0: TableRowContent, C1: TableRowContent, C2: TableRowContent>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleTableRowContent<Value, (C0, C1, C2)>
        where C0.TableRowValue == Value, C1.TableRowValue == Value, C2.TableRowValue == Value {
        TupleTableRowContent(value: (c0, c1, c2), parts: [c0, c1, c2])
    }
    public static func buildBlock<C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleTableRowContent<Value, (C0, C1, C2, C3)>
        where C0.TableRowValue == Value, C1.TableRowValue == Value, C2.TableRowValue == Value, C3.TableRowValue == Value {
        TupleTableRowContent(value: (c0, c1, c2, c3), parts: [c0, c1, c2, c3])
    }
    public static func buildBlock<C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4)>
        where C0.TableRowValue == Value, C1.TableRowValue == Value, C2.TableRowValue == Value, C3.TableRowValue == Value, C4.TableRowValue == Value {
        TupleTableRowContent(value: (c0, c1, c2, c3, c4), parts: [c0, c1, c2, c3, c4])
    }
    public static func buildBlock<C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent, C5: TableRowContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4, C5)>
        where C0.TableRowValue == Value, C1.TableRowValue == Value, C2.TableRowValue == Value, C3.TableRowValue == Value, C4.TableRowValue == Value, C5.TableRowValue == Value {
        TupleTableRowContent(value: (c0, c1, c2, c3, c4, c5), parts: [c0, c1, c2, c3, c4, c5])
    }
    public static func buildBlock<C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent, C5: TableRowContent, C6: TableRowContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4, C5, C6)>
        where C0.TableRowValue == Value, C1.TableRowValue == Value, C2.TableRowValue == Value, C3.TableRowValue == Value, C4.TableRowValue == Value, C5.TableRowValue == Value, C6.TableRowValue == Value {
        TupleTableRowContent(value: (c0, c1, c2, c3, c4, c5, c6), parts: [c0, c1, c2, c3, c4, c5, c6])
    }
    public static func buildBlock<C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent, C5: TableRowContent, C6: TableRowContent, C7: TableRowContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4, C5, C6, C7)>
        where C0.TableRowValue == Value, C1.TableRowValue == Value, C2.TableRowValue == Value, C3.TableRowValue == Value, C4.TableRowValue == Value, C5.TableRowValue == Value, C6.TableRowValue == Value, C7.TableRowValue == Value {
        TupleTableRowContent(value: (c0, c1, c2, c3, c4, c5, c6, c7), parts: [c0, c1, c2, c3, c4, c5, c6, c7])
    }
    public static func buildBlock<C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent, C5: TableRowContent, C6: TableRowContent, C7: TableRowContent, C8: TableRowContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4, C5, C6, C7, C8)>
        where C0.TableRowValue == Value, C1.TableRowValue == Value, C2.TableRowValue == Value, C3.TableRowValue == Value, C4.TableRowValue == Value, C5.TableRowValue == Value, C6.TableRowValue == Value, C7.TableRowValue == Value, C8.TableRowValue == Value {
        TupleTableRowContent(value: (c0, c1, c2, c3, c4, c5, c6, c7, c8), parts: [c0, c1, c2, c3, c4, c5, c6, c7, c8])
    }
    public static func buildBlock<C0: TableRowContent, C1: TableRowContent, C2: TableRowContent, C3: TableRowContent, C4: TableRowContent, C5: TableRowContent, C6: TableRowContent, C7: TableRowContent, C8: TableRowContent, C9: TableRowContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleTableRowContent<Value, (C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)>
        where C0.TableRowValue == Value, C1.TableRowValue == Value, C2.TableRowValue == Value, C3.TableRowValue == Value, C4.TableRowValue == Value, C5.TableRowValue == Value, C6.TableRowValue == Value, C7.TableRowValue == Value, C8.TableRowValue == Value, C9.TableRowValue == Value {
        TupleTableRowContent(value: (c0, c1, c2, c3, c4, c5, c6, c7, c8, c9), parts: [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9])
    }
    public static func buildIf<C: TableRowContent>(_ content: C?) -> C? where C.TableRowValue == Value { content }
    public static func buildEither<T: TableRowContent, F: TableRowContent>(first: T) -> _ConditionalTableRowContent<T, F>
        where T.TableRowValue == Value, F.TableRowValue == Value { _ConditionalTableRowContent(rows: _tableRows(first)) }
    public static func buildEither<T: TableRowContent, F: TableRowContent>(second: F) -> _ConditionalTableRowContent<T, F>
        where T.TableRowValue == Value, F.TableRowValue == Value { _ConditionalTableRowContent(rows: _tableRows(second)) }
}

// MARK: - Row modifiers

/// A table row modifier (the rows' view modifiers in isim).
public protocol _TableRowContentModifier {}
extension ModifiedContent: TableRowContent where Content: TableRowContent, Modifier: _TableRowContentModifier {
    public typealias TableRowValue = Content.TableRowValue
    public typealias TableRowBody = Never
    public var tableRowBody: Never { return fatalError() }
}
extension ModifiedContent: _TableRowSource where Content: TableRowContent, Modifier: _TableRowContentModifier {
    var _rows: [_TableRowItem] {
        let rows = _tableRows(content)
        guard let m = modifier as? _TableRowWrap else { return rows }
        return rows.enumerated().map { i, r in var r = r; r.wraps.append(m.wrap(i)); return r }
    }
}
/// A modifier's effect on a row (its index among the content's rows).
protocol _TableRowWrap { func wrap(_ index: Int) -> @MainActor (AnyView) -> AnyView }

public struct ItemProviderTableRowModifier: _TableRowContentModifier, _TableRowWrap {
    let provider: (() -> NSItemProvider?)?
    public var body: some _TableRowContentModifier { self }
    func wrap(_ index: Int) -> @MainActor (AnyView) -> AnyView { { $0 } }      // (isim: rows are dragged with draggable)
}
public struct OnInsertTableRowModifier: _TableRowContentModifier, _TableRowWrap {
    let types: [UTType]
    let insert: (Int, [NSItemProvider]) -> Void
    public var body: some _TableRowContentModifier { self }
    func wrap(_ index: Int) -> @MainActor (AnyView) -> AnyView {
        let types = types, insert = insert
        return { view in AnyView(view.onDrop(of: types, isTargeted: nil) { providers in insert(index, providers); return true }) }
    }
}
public struct _ContextMenuTableRowModifier<MenuContent: View>: _TableRowContentModifier, _TableRowWrap {
    let menu: MenuContent
    func wrap(_ index: Int) -> @MainActor (AnyView) -> AnyView { let m = menu; return { AnyView($0.contextMenu { m }) } }
}
public struct _ContextMenuPreviewTableRowModifier<MenuContent: View, Preview: View>: _TableRowContentModifier, _TableRowWrap {
    let menu: MenuContent, preview: Preview
    func wrap(_ index: Int) -> @MainActor (AnyView) -> AnyView { let m = menu, p = preview; return { AnyView($0.contextMenu(menuItems: { m }, preview: { p })) } }
}

/// Rows with a view modifier on each.
struct _WrappedTableRows<Base: TableRowContent>: TableRowContent, _TableRowSource {
    typealias TableRowValue = Base.TableRowValue
    var tableRowBody: Never { return fatalError() }
    let base: Base
    let wrap: @MainActor (AnyView) -> AnyView
    var selectable = true
    var _rows: [_TableRowItem] { _tableRows(base).map { var r = $0; r.wraps.append(wrap); r.selectable = r.selectable && selectable; return r } }
}

extension TableRowContent {
    public func contextMenu<M: View>(@ViewBuilder menuItems: () -> M) -> ModifiedContent<Self, _ContextMenuTableRowModifier<M>> {
        ModifiedContent(content: self, modifier: _ContextMenuTableRowModifier(menu: menuItems()))
    }
    public func contextMenu<M: View, P: View>(@ViewBuilder menuItems: () -> M, @ViewBuilder preview: () -> P)
        -> ModifiedContent<Self, _ContextMenuPreviewTableRowModifier<M, P>> {
        ModifiedContent(content: self, modifier: _ContextMenuPreviewTableRowModifier(menu: menuItems(), preview: preview()))
    }
    public func itemProvider(_ action: (() -> NSItemProvider?)?) -> ModifiedContent<Self, ItemProviderTableRowModifier> {
        ModifiedContent(content: self, modifier: ItemProviderTableRowModifier(provider: action))
    }
    /// The rows can be dragged with `payload`.
    public func draggable<T: Transferable>(_ payload: @autoclosure @escaping () -> T) -> some TableRowContent<TableRowValue> {
        _WrappedTableRows(base: self, wrap: { AnyView($0.draggable(payload())) })
    }
    /// Items dropped on a row.
    public func dropDestination<T: Transferable>(for payloadType: T.Type = T.self, action: @escaping ([T]) -> Void) -> some TableRowContent<TableRowValue> {
        _WrappedTableRows(base: self, wrap: { AnyView($0.dropDestination(for: payloadType, action: { items, _ in action(items); return true })) })
    }
    public func onHover(perform action: @escaping (Bool) -> Void) -> some TableRowContent<TableRowValue> {
        _WrappedTableRows(base: self, wrap: { AnyView($0.onHover(perform: action)) })
    }
    /// The rows cannot be selected.
    public func selectionDisabled(_ isDisabled: Bool = true) -> some TableRowContent<TableRowValue> {
        _WrappedTableRows(base: self, wrap: { AnyView($0.selectionDisabled(isDisabled)) }, selectable: !isDisabled)
    }
}
extension DynamicTableRowContent {
    /// Items inserted (dropped) at a row: its index and the items' providers.
    public func onInsert(of supportedContentTypes: [UTType], perform action: @escaping (Int, [NSItemProvider]) -> Void) -> ModifiedContent<Self, OnInsertTableRowModifier> {
        ModifiedContent(content: self, modifier: OnInsertTableRowModifier(types: supportedContentTypes, insert: action))
    }
    /// Items dropped at a row: its index and the items.
    public func dropDestination<T: Transferable>(for payloadType: T.Type = T.self, action: @escaping (Int, [T]) -> Void) -> ModifiedContent<Self, OnInsertTableRowModifier> {
        ModifiedContent(content: self, modifier: OnInsertTableRowModifier(types: T.importedContentTypes, insert: { index, providers in
            _loadTransferables(providers, T.self) { action(index, $0) }
        }))
    }
}
final class _LoadBox: @unchecked Sendable { var items: [Any?]; init(_ n: Int) { items = [Any?](repeating: nil, count: n) } }
/// Loads dropped items as T (in order), then calls `done` on the main queue.
func _loadTransferables<T: Transferable>(_ providers: [NSItemProvider], _ type: T.Type, _ done: @escaping ([T]) -> Void) {
    let group = DispatchGroup(), box = _LoadBox(providers.count)
    for (i, p) in providers.enumerated() {
        group.enter()
        _ = p.loadTransferable(type: T.self) { r in
            let v = try? r.get()
            DispatchQueue.main.async { box.items[i] = v as Any?; group.leave() }
        }
    }
    group.notify(queue: .main) { done(box.items.compactMap { $0 as? T }) }
}

// MARK: - Styles

/// How a table looks.
public protocol TableStyle {
    associatedtype Body: View
    typealias Configuration = TableStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}
public struct TableStyleConfiguration {
    let content: AnyView
}
public struct AutomaticTableStyle: TableStyle {
    public func makeBody(configuration: Configuration) -> some View { configuration.content }
}
/// Rows inset from the table's edges.
public struct InsetTableStyle: TableStyle {
    let alternates: Bool
    public init() { alternates = true }
    public init(alternatesRowBackgrounds: Bool) { alternates = alternatesRowBackgrounds }
    public func makeBody(configuration: Configuration) -> some View { configuration.content }
}
/// A border around the table and its cells.
public struct BorderedTableStyle: TableStyle {
    let alternates: Bool
    public init() { alternates = true }
    public init(alternatesRowBackgrounds: Bool) { alternates = alternatesRowBackgrounds }
    public func makeBody(configuration: Configuration) -> some View { configuration.content }
}
extension TableStyle where Self == AutomaticTableStyle { public static var automatic: AutomaticTableStyle { AutomaticTableStyle() } }
extension TableStyle where Self == InsetTableStyle {
    public static var inset: InsetTableStyle { InsetTableStyle() }
    public static func inset(alternatesRowBackgrounds: Bool) -> InsetTableStyle { InsetTableStyle(alternatesRowBackgrounds: alternatesRowBackgrounds) }
}
extension TableStyle where Self == BorderedTableStyle {
    public static var bordered: BorderedTableStyle { BorderedTableStyle() }
    public static func bordered(alternatesRowBackgrounds: Bool) -> BorderedTableStyle { BorderedTableStyle(alternatesRowBackgrounds: alternatesRowBackgrounds) }
}

/// The table look in the environment: 0 automatic, 1 inset, 2 bordered; alternating row backgrounds; header visibility.
struct _TableLook { var kind = 0; var alternates = false; var headers = Visibility.automatic }
struct _TableLookKey: EnvironmentKey { static var defaultValue: _TableLook { _TableLook() } }
extension EnvironmentValues {
    var _tableLook: _TableLook { get { self[_TableLookKey.self] } set { self[_TableLookKey.self] = newValue } }
}
extension View {
    public func tableStyle<S: TableStyle>(_ style: S) -> some View {
        _env {
            $0._tableLook.kind = S.self == InsetTableStyle.self ? 1 : S.self == BorderedTableStyle.self ? 2 : 0
            $0._tableLook.alternates = (style as? InsetTableStyle)?.alternates ?? (style as? BorderedTableStyle)?.alternates ?? false
        }
    }
    /// Whether the table's column headers show.
    public func tableColumnHeaders(_ visibility: Visibility) -> some View { _env { $0._tableLook.headers = visibility } }
}

// MARK: - Table

/// Sorting: the first comparator in effect (its key and order) and a header tap on a column's comparator.
struct _TableSort {
    let first: () -> (key: AnyHashable, order: SortOrder)?
    let tap: (AnyHashable) -> Void
}
/// What identifies a comparator for a column: a key path comparator's key path, else the comparator sorting forward.
protocol _KeyPathKeyed { var _sortKey: AnyHashable { get } }
extension KeyPathComparator: _KeyPathKeyed { var _sortKey: AnyHashable { AnyHashable(keyPath) } }
func _sortKey<C: SortComparator>(_ c: C) -> AnyHashable {
    if let k = c as? _KeyPathKeyed { return k._sortKey }
    var f = c; f.order = .forward
    return AnyHashable(f)
}

/// Rows of values in columns.
public struct Table<Value: Identifiable, Rows: TableRowContent, Columns: TableColumnContent>: View
    where Value == Rows.TableRowValue, Value == Columns.TableRowValue {
    let rows: Rows, columns: Columns
    var _selection: _ListSelection?
    var _sort: _TableSort?
    var _customization: Binding<TableColumnCustomization<Value>>?
    init(rows: Rows, columns: Columns, selection: _ListSelection?, sort: _TableSort?, customization: Binding<TableColumnCustomization<Value>>?) {
        self.rows = rows; self.columns = columns; _selection = selection; _sort = sort; _customization = customization
    }
    public var body: some View {
        _TableBody(rows: _tableRows(rows), columns: visibleColumns, selection: _selection, sort: _sort)
    }
    var visibleColumns: [_TableColumnSpec] {
        let all = _tableColumns(columns)
        let shown = all.filter { c in
            let v = c.customizationID.flatMap { _customization?.wrappedValue[visibility: $0] } ?? .automatic
            return v == .automatic ? c.defaultVisibility != .hidden : v == .visible
        }
        guard let order = _customization?.wrappedValue.order, !order.isEmpty else { return shown }
        return shown.sorted { (order.firstIndex(of: $0.customizationID ?? "") ?? .max) < (order.firstIndex(of: $1.customizationID ?? "") ?? .max) }
    }
}

/// Selection for a table's rows (as a List's).
@MainActor func _tableSelection<ID: Hashable>(_ s: Binding<ID?>) -> _ListSelection {
    _ListSelection(multi: false, isSelected: { s.wrappedValue.map(AnyHashable.init) == $0 }, select: { if let v = $0.base as? ID { s.wrappedValue = v } })
}
@MainActor func _tableSelection<ID: Hashable>(_ s: Binding<Set<ID>>) -> _ListSelection {
    _ListSelection(multi: true, isSelected: { ($0.base as? ID).map { s.wrappedValue.contains($0) } ?? false },
                   select: { if let v = $0.base as? ID { if s.wrappedValue.contains(v) { s.wrappedValue.remove(v) } else { s.wrappedValue.insert(v) } } })
}
func _tableSort<Sort: SortComparator>(_ b: Binding<[Sort]>) -> _TableSort {
    _TableSort(first: { b.wrappedValue.first.map { (_sortKey($0), $0.order) } },
               tap: { column in
                   guard var c = column.base as? Sort else { return }
                   var list = b.wrappedValue
                   let key = _sortKey(c)
                   if let f = list.first, _sortKey(f) == key {           // the sorted column: the other way
                       list[0].order = f.order == .forward ? .reverse : .forward
                   } else {
                       list.removeAll { _sortKey($0) == key }
                       c.order = .forward
                       list.insert(c, at: 0)
                   }
                   b.wrappedValue = list
               })
}

struct _TableBody: View {
    let rows: [_TableRowItem], columns: [_TableColumnSpec]
    let selection: _ListSelection?, sort: _TableSort?
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\._tableLook) var look
    var body: some View {
        if sizeClass == .regular && columns.count > 1 { wide } else { compact }
    }
    /// iPhone: the first column, as a list.
    var compact: some View {
        var l = List {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                row(r, i) { cell(columns.first, r).padding(.leading, CGFloat(r.depth) * 20) }
            }
        }
        l._selection = selection
        return l.accessibilityIdentifier("isim-table")
    }
    /// iPad: a header row and the columns side by side.
    var wide: some View {
        GeometryReader { g in wideList(Self.widths(columns, available: g.size.width - 40)) }
    }
    /// The rows under the header row (a section header, so the list stays the page's scroll view).
    func wideList(_ widths: [CGFloat]) -> some View {
        var l = List {
            Section {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                    row(r, i) {
                        HStack(spacing: 8) {
                            ForEach(Array(columns.enumerated()), id: \.offset) { k, c in
                                cell(c, r).padding(.leading, k == 0 ? CGFloat(r.depth) * 20 : 0)
                                    .frame(width: widths[k], alignment: c.alignment.frameAlignment)
                            }
                        }
                    }
                }
            } header: {
                if look.headers != .hidden {
                    HStack(spacing: 8) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { i, c in header(c, i).frame(width: widths[i], alignment: c.alignment.frameAlignment) }
                    }
                    .textCase(nil)
                }
            }
        }
        l._selection = selection
        return l.listStyle(.plain).overlay { if look.kind == 2 { Rectangle().stroke(Color(uiColor: .separator)) } }
    }
    func cell(_ c: _TableColumnSpec?, _ r: _TableRowItem) -> AnyView { c.map { $0.cell(r.value) } ?? AnyView(EmptyView()) }
    func row(_ r: _TableRowItem, _ i: Int, @ViewBuilder _ content: () -> some View) -> some View {
        var v = AnyView(content().frame(maxWidth: .infinity, alignment: .leading))
        for w in r.wraps { v = w(v) }
        return v.tag(r.id)
            .listRowBackground(look.alternates && i % 2 == 1 ? Color(uiColor: .secondarySystemBackground) : nil)
    }
    /// A column header: its label, sortable columns sort by it when tapped (the sorted one shows a chevron).
    func header(_ c: _TableColumnSpec, _ i: Int) -> some View {
        let first = sort?.first()
        let sorted = c.sortKey != nil && first?.key == c.sortKey
        return Button {
            if let s = sort, let cmp = c.comparator { s.tap(cmp) }
        } label: {
            HStack(spacing: 4) {
                c.label.font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                if sorted { Image(systemName: first?.order == .reverse ? "chevron.down" : "chevron.up").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
            }
        }
        .buttonStyle(.plain)
        .disabled(c.comparator == nil || sort == nil)
        .accessibilityIdentifier("isim-table-header-\(i)")
    }
    /// Column widths: fixed ones, ideal ones, then the rest shared (within min / max).
    static func widths(_ cols: [_TableColumnSpec], available: CGFloat) -> [CGFloat] {
        var w = cols.map { $0.width ?? $0.idealWidth }
        let used = w.compactMap { $0 }.reduce(0, +) + CGFloat(max(0, cols.count - 1)) * 8
        let flexible = w.indices.filter { w[$0] == nil }
        let share = flexible.isEmpty ? 0 : max(0, available - used) / CGFloat(flexible.count)
        for i in flexible { w[i] = min(max(share, cols[i].minWidth ?? 0), cols[i].maxWidth ?? .infinity) }
        return w.map { max(0, $0 ?? 0) }
    }
}

