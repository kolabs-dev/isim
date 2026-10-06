// Sample: SwiftUI lists and navigation on isim — onDelete / onMove / EditButton, swipeActions, contextMenu, row
// badges, .searchable, .refreshable, navigationDestination(isPresented:), NavigationSplitView with List(selection:),
// toolbar visibility and background, sheet detents.
import SwiftUI

@main
struct HelloListsApp: App {
    var body: some Scene { WindowGroup { Root() } }
}

struct Root: View {
    var body: some View {
        TabView {
            FruitList().tabItem { Label("Fruits", systemImage: "list.bullet") }
            SplitDemo().tabItem { Label("Split", systemImage: "sidebar.left") }
            MoreDemo().tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}

struct FruitList: View {
    @State private var fruits = ["Apple", "Banana", "Cherry", "Date"]
    @State private var query = ""
    @State private var showDetail = false
    @State private var refreshes = 0
    @State private var picked: String? = nil
    @Environment(\.editMode) var editMode
    var shown: [String] { query.isEmpty ? fruits : fruits.filter { $0.lowercased().hasPrefix(query.lowercased()) } }
    var body: some View {
        NavigationStack {
            List {
                Section("Fruits") {
                    ForEach(shown, id: \.self) { f in
                        Text(f).accessibilityIdentifier("fruit-\(f)")
                            .badge(f == "Apple" ? 3 : 0)
                            .swipeActions(edge: .leading) { Button("Pin") { print("pin \(f)") }.tint(.orange) }
                            .contextMenu { Button("Copy") { print("copy \(f)") } }
                    }
                    .onDelete { offsets in
                        let gone = offsets.map { shown[$0] }
                        fruits.removeAll { gone.contains($0) }
                        print("deleted \(gone.joined(separator: ","))")
                    }
                    .onMove { from, to in
                        fruits.move(fromOffsets: from, toOffset: to)
                        print("order \(fruits.joined(separator: ","))")
                    }
                }
                Section {
                    Button("Show detail") { showDetail = true }
                    Button("Open item") { picked = "Kiwi" }
                    Text("refreshed \(refreshes)").accessibilityIdentifier("refresh-count")
                    Text(editMode?.wrappedValue.isEditing == true ? "editing" : "not editing").accessibilityIdentifier("edit-state")
                }
            }
            .navigationTitle("Fruits")
            .toolbar { EditButton() }
            .searchable(text: $query, prompt: "Find fruit")
            .refreshable { refreshes += 1; print("refreshed \(refreshes)") }
            .navigationDestination(isPresented: $showDetail) { DetailView() }
            .navigationDestination(item: $picked) { item in Text("Item \(item)").accessibilityIdentifier("item-page") }
            .onChange(of: picked) { _, p in print("picked \(p ?? "nil")") }
            .onChange(of: query) { _, q in print("query \(q)") }
        }
    }
}
struct DetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.isPresented) var isPresented
    var body: some View {
        VStack(spacing: 12) {
            Text("Detail page").accessibilityIdentifier("detail")
            Text(isPresented ? "presented" : "root").accessibilityIdentifier("presented")
            Button("Close") { dismiss() }.accessibilityIdentifier("close-detail")
        }
        .navigationTitle("Detail")
    }
}

struct Flavor: Identifiable, Hashable { let id: Int; let name: String }
struct SplitDemo: View {
    let flavors = [Flavor(id: 1, name: "Mint"), Flavor(id: 2, name: "Lemon"), Flavor(id: 3, name: "Cocoa")]
    @State private var selection: Flavor.ID? = nil
    var body: some View {
        NavigationSplitView {
            List(flavors, selection: $selection) { f in Text(f.name) }
                .navigationTitle("Flavors")
        } detail: {
            let name = flavors.first { $0.id == selection }?.name ?? "none"
            Text("Selected \(name)").accessibilityIdentifier("split-detail")
                .navigationTitle(name)
        }
        .onChange(of: selection) { _, s in print("selection \(s.map(String.init) ?? "nil")") }
    }
}

struct MoreDemo: View {
    @State private var sheet = false
    @State private var detent = PresentationDetent.medium
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Button("Open sheet") { sheet = true }.accessibilityIdentifier("open-sheet")
                NavigationLink("Full screen page") {
                    Text("No bars here").accessibilityIdentifier("barless")
                        .toolbar(.hidden, for: .navigationBar)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            .navigationTitle("More")
            .toolbarBackground(Color.yellow, for: .navigationBar)
        }
        .sheet(isPresented: $sheet, onDismiss: { print("sheet dismissed") }) {
            VStack(spacing: 12) {
                Text("Half sheet").font(.headline).accessibilityIdentifier("sheet-title")
                Text(detent == .large ? "large" : "medium").accessibilityIdentifier("detent-name")
            }
            .padding()
            .presentationDetents([.medium, .large], selection: $detent)
            .presentationDragIndicator(.visible)
        }
    }
}
