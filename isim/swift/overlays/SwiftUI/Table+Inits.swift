// isim SwiftUI: Table's initialisers (Table.swift): from data, from rows (of:), outline data (children:), each with
// single or multiple selection, a sort order and column customization. (Generated pattern: every form builds the
// table from its rows, columns and the optional bindings.)
import UIKit

extension Table {
    public init<Data>(_ data: Data, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: nil, sort: nil, customization: nil)
    }
    public init<Data>(_ data: Data, selection: Binding<Value.ID?>, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: _tableSelection(selection), sort: nil, customization: nil)
    }
    public init<Data>(_ data: Data, selection: Binding<Set<Value.ID>>, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: _tableSelection(selection), sort: nil, customization: nil)
    }
    public init<Data, Sort>(_ data: Data, sortOrder: Binding<[Sort]>, @TableColumnBuilder<Value, Sort> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value, Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: nil, sort: _tableSort(sortOrder), customization: nil)
    }
    public init<Data, Sort>(_ data: Data, selection: Binding<Value.ID?>, sortOrder: Binding<[Sort]>, @TableColumnBuilder<Value, Sort> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value, Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: nil)
    }
    public init<Data, Sort>(_ data: Data, selection: Binding<Set<Value.ID>>, sortOrder: Binding<[Sort]>, @TableColumnBuilder<Value, Sort> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value, Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: nil)
    }
    public init<Data>(_ data: Data, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: nil, sort: nil, customization: columnCustomization)
    }
    public init<Data>(_ data: Data, selection: Binding<Value.ID?>, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: _tableSelection(selection), sort: nil, customization: columnCustomization)
    }
    public init<Data>(_ data: Data, selection: Binding<Set<Value.ID>>, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: _tableSelection(selection), sort: nil, customization: columnCustomization)
    }
    public init<Data, Sort>(_ data: Data, sortOrder: Binding<[Sort]>, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Sort> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value, Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: nil, sort: _tableSort(sortOrder), customization: columnCustomization)
    }
    public init<Data, Sort>(_ data: Data, selection: Binding<Value.ID?>, sortOrder: Binding<[Sort]>, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Sort> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value, Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: columnCustomization)
    }
    public init<Data, Sort>(_ data: Data, selection: Binding<Set<Value.ID>>, sortOrder: Binding<[Sort]>, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Sort> columns: () -> Columns) where Rows == TableForEachContent<Data>, Data: RandomAccessCollection, Data.Element == Value, Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: TableForEachContent(data: data), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: columnCustomization)
    }
    public init(of valueType: Value.Type, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.init(rows: rows(), columns: columns(), selection: nil, sort: nil, customization: nil)
    }
    public init(of valueType: Value.Type, selection: Binding<Value.ID?>, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.init(rows: rows(), columns: columns(), selection: _tableSelection(selection), sort: nil, customization: nil)
    }
    public init(of valueType: Value.Type, selection: Binding<Set<Value.ID>>, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.init(rows: rows(), columns: columns(), selection: _tableSelection(selection), sort: nil, customization: nil)
    }
    public init<Sort>(of valueType: Value.Type, sortOrder: Binding<[Sort]>, @TableColumnBuilder<Value, Sort> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) where Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: rows(), columns: columns(), selection: nil, sort: _tableSort(sortOrder), customization: nil)
    }
    public init<Sort>(of valueType: Value.Type, selection: Binding<Value.ID?>, sortOrder: Binding<[Sort]>, @TableColumnBuilder<Value, Sort> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) where Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: rows(), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: nil)
    }
    public init<Sort>(of valueType: Value.Type, selection: Binding<Set<Value.ID>>, sortOrder: Binding<[Sort]>, @TableColumnBuilder<Value, Sort> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) where Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: rows(), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: nil)
    }
    public init(of valueType: Value.Type, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.init(rows: rows(), columns: columns(), selection: nil, sort: nil, customization: columnCustomization)
    }
    public init(of valueType: Value.Type, selection: Binding<Value.ID?>, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.init(rows: rows(), columns: columns(), selection: _tableSelection(selection), sort: nil, customization: columnCustomization)
    }
    public init(of valueType: Value.Type, selection: Binding<Set<Value.ID>>, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Never> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) {
        self.init(rows: rows(), columns: columns(), selection: _tableSelection(selection), sort: nil, customization: columnCustomization)
    }
    public init<Sort>(of valueType: Value.Type, sortOrder: Binding<[Sort]>, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Sort> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) where Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: rows(), columns: columns(), selection: nil, sort: _tableSort(sortOrder), customization: columnCustomization)
    }
    public init<Sort>(of valueType: Value.Type, selection: Binding<Value.ID?>, sortOrder: Binding<[Sort]>, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Sort> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) where Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: rows(), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: columnCustomization)
    }
    public init<Sort>(of valueType: Value.Type, selection: Binding<Set<Value.ID>>, sortOrder: Binding<[Sort]>, columnCustomization: Binding<TableColumnCustomization<Value>>, @TableColumnBuilder<Value, Sort> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) where Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: rows(), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: columnCustomization)
    }
    public init<Data>(_ data: Data, children: KeyPath<Value, Data?>, columnCustomization: Binding<TableColumnCustomization<Value>>? = nil, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableOutlineGroupContent<Data>, Data: RandomAccessCollection, Data.Element == Value {
        self.init(rows: TableOutlineGroupContent(data: data, children: children), columns: columns(), selection: nil, sort: nil, customization: columnCustomization)
    }
    public init<Data>(_ data: Data, children: KeyPath<Value, Data?>, selection: Binding<Value.ID?>, columnCustomization: Binding<TableColumnCustomization<Value>>? = nil, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableOutlineGroupContent<Data>, Data: RandomAccessCollection, Data.Element == Value {
        self.init(rows: TableOutlineGroupContent(data: data, children: children), columns: columns(), selection: _tableSelection(selection), sort: nil, customization: columnCustomization)
    }
    public init<Data>(_ data: Data, children: KeyPath<Value, Data?>, selection: Binding<Set<Value.ID>>, columnCustomization: Binding<TableColumnCustomization<Value>>? = nil, @TableColumnBuilder<Value, Never> columns: () -> Columns) where Rows == TableOutlineGroupContent<Data>, Data: RandomAccessCollection, Data.Element == Value {
        self.init(rows: TableOutlineGroupContent(data: data, children: children), columns: columns(), selection: _tableSelection(selection), sort: nil, customization: columnCustomization)
    }
    public init<Data, Sort>(_ data: Data, children: KeyPath<Value, Data?>, sortOrder: Binding<[Sort]>, columnCustomization: Binding<TableColumnCustomization<Value>>? = nil, @TableColumnBuilder<Value, Sort> columns: () -> Columns) where Rows == TableOutlineGroupContent<Data>, Data: RandomAccessCollection, Data.Element == Value, Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: TableOutlineGroupContent(data: data, children: children), columns: columns(), selection: nil, sort: _tableSort(sortOrder), customization: columnCustomization)
    }
    public init<Data, Sort>(_ data: Data, children: KeyPath<Value, Data?>, selection: Binding<Value.ID?>, sortOrder: Binding<[Sort]>, columnCustomization: Binding<TableColumnCustomization<Value>>? = nil, @TableColumnBuilder<Value, Sort> columns: () -> Columns) where Rows == TableOutlineGroupContent<Data>, Data: RandomAccessCollection, Data.Element == Value, Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: TableOutlineGroupContent(data: data, children: children), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: columnCustomization)
    }
    public init<Data, Sort>(_ data: Data, children: KeyPath<Value, Data?>, selection: Binding<Set<Value.ID>>, sortOrder: Binding<[Sort]>, columnCustomization: Binding<TableColumnCustomization<Value>>? = nil, @TableColumnBuilder<Value, Sort> columns: () -> Columns) where Rows == TableOutlineGroupContent<Data>, Data: RandomAccessCollection, Data.Element == Value, Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: TableOutlineGroupContent(data: data, children: children), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: columnCustomization)
    }
    public init<Sort>(sortOrder: Binding<[Sort]>, @TableColumnBuilder<Value, Sort> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) where Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: rows(), columns: columns(), selection: nil, sort: _tableSort(sortOrder), customization: nil)
    }
    public init<Sort>(selection: Binding<Value.ID?>, sortOrder: Binding<[Sort]>, @TableColumnBuilder<Value, Sort> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) where Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: rows(), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: nil)
    }
    public init<Sort>(selection: Binding<Set<Value.ID>>, sortOrder: Binding<[Sort]>, @TableColumnBuilder<Value, Sort> columns: () -> Columns, @TableRowBuilder<Value> rows: () -> Rows) where Sort: SortComparator, Sort.Compared == Value, Columns.TableColumnSortComparator == Sort {
        self.init(rows: rows(), columns: columns(), selection: _tableSelection(selection), sort: _tableSort(sortOrder), customization: nil)
    }
}
