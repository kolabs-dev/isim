// HelloLists -table: a SwiftUI Table of people — sortable Name and Age columns (tap a header on iPad), a City column,
// single selection; -rows: the same people as TableRows with a context menu, and an outline table (children:).
// On iPhone a table shows its first column as a list; on iPad its columns. Logs "table ..." lines.
import SwiftUI

struct Person: Identifiable, Hashable {
    let id: Int
    var name: String
    var age: Int
    var city: String
}

struct Folder: Identifiable {
    let id: String
    var size: Int
    var children: [Folder]?
}

func tlog(_ s: String) { print("table \(s)") }

struct TablePage: View {
    @State var people = [Person(id: 1, name: "Chloe", age: 31, city: "Lisbon"), Person(id: 2, name: "Ada", age: 36, city: "London"),
                         Person(id: 3, name: "Ben", age: 25, city: "Berlin"), Person(id: 4, name: "Dara", age: 42, city: "Dublin")]
    @State var sortOrder = [KeyPathComparator(\Person.name)]
    @State var selection: Person.ID? = nil
    let rowsForm = ProcessInfo.processInfo.arguments.contains("-rows")
    static let tree = [Folder(id: "Documents", size: 3, children: [Folder(id: "Taxes", size: 2, children: nil), Folder(id: "Notes", size: 1, children: nil)]),
                       Folder(id: "Music", size: 5, children: nil)]
    var body: some View {
        NavigationStack {
            Group {
                if rowsForm { rowsTables } else { sortedTable }
            }
            .navigationTitle("People")
        }
        .onAppear { people.sort(using: sortOrder); tlog("order \(people.map(\.name).joined(separator: ","))") }
    }
    var sortedTable: some View {
        Table(people, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name)
            TableColumn("Age", value: \.age) { Text("\($0.age)") }
                .width(80)
            TableColumn("City", value: \.city)
        }
        .onChange(of: sortOrder) {
            people.sort(using: sortOrder)
            tlog("order \(people.map(\.name).joined(separator: ",")) by \(sortOrder.first.map { $0.order == .forward ? "forward" : "reverse" } ?? "none")")
        }
        .onChange(of: selection) { tlog("selected \(people.first { $0.id == selection }?.name ?? "none")") }
    }
    var rowsTables: some View {
        VStack {
            Table(of: Person.self) {
                TableColumn("Name") { Text($0.name).accessibilityIdentifier("person-\($0.name)") }
                TableColumn("City", value: \.city)
            } rows: {
                ForEach(people) { p in
                    TableRow(p).contextMenu { Button("Greet \(p.name)") { tlog("greet \(p.name)") } }
                }
            }
            Table(Self.tree, children: \.children) {
                TableColumn("Folder", value: \.id)
                TableColumn("Size") { Text("\($0.size)") }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
}
