import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)], animation: .default)
    private var items: FetchedResults<Item>

    @SectionedFetchRequest(sectionIdentifier: \Item.group, sortDescriptors: [NSSortDescriptor(key: "group", ascending: true), NSSortDescriptor(key: "timestamp", ascending: true)])
    private var sections: SectionedFetchResults<String?, Item>

    @State private var starredOnly = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button("Add") { addItem() }.accessibilityIdentifier("add")
                        Spacer()
                        Button("Add in background") { addInBackground() }.accessibilityIdentifier("addBackground")
                    }
                    Toggle("Starred only", isOn: $starredOnly).accessibilityIdentifier("starredOnly")
                }
                Section("Items") {
                    if items.isEmpty { Text("No items").accessibilityIdentifier("empty") }
                    ForEach(items) { item in ItemRow(item: item, delete: { delete(item) }) }
                }
                Section {
                    Text("count \(items.count)").accessibilityIdentifier("count")
                    Text("groups " + sections.map { "\($0.id ?? "-"):\($0.count)" }.joined(separator: " ")).accessibilityIdentifier("groups")
                }
            }
            .navigationTitle("Core Data")
        }
        .onChange(of: starredOnly) { _, on in
            items.nsPredicate = on ? NSPredicate(format: "starred == YES") : nil
            print("filter starred \(on)")
        }
    }

    private func addItem() {
        let n = ((try? viewContext.count(for: Item.fetchRequest() as NSFetchRequest<Item>)) ?? 0) + 1
        let item = Item(context: viewContext)
        item.timestamp = Date()
        item.title = "Item \(n)"
        item.group = n % 2 == 1 ? "odd" : "even"
        save("added \(item.title ?? "")")
    }

    private func addInBackground() {
        PersistenceController.shared.container.performBackgroundTask { ctx in
            let item = Item(context: ctx)
            item.timestamp = Date()
            item.title = "Background item"
            item.group = "bg"
            try? ctx.save()
            print("background saved")
        }
    }

    private func delete(_ item: Item) {
        let title = item.title ?? ""
        viewContext.delete(item)
        save("deleted \(title)")
    }

    private func save(_ what: String) {
        do { try viewContext.save(); print(what) }
        catch { print("save failed \(error)") }
    }
}

struct ItemRow: View {
    @ObservedObject var item: Item
    let delete: () -> Void
    var body: some View {
        HStack {
            Button(item.starred ? "★" : "☆") { item.starred.toggle(); try? item.managedObjectContext?.save() }
                .accessibilityIdentifier("star-" + id)
            Text(item.title ?? "?").accessibilityIdentifier("title-" + id)
            Spacer()
            Button("Delete") { delete() }.accessibilityIdentifier("delete-" + id)
        }
    }
    private var id: String { (item.title ?? "").replacingOccurrences(of: " ", with: "_") }
}
