// Sample: SwiftUI modal presentations on isim — sheet (with the presenter's environment object and
// @Environment(\.dismiss)), sheet(item:), fullScreenCover, alert with actions + message, confirmationDialog.
import SwiftUI

final class Store: ObservableObject {
    @Published var count = 0 { didSet { print("count \(count)") } }
}
struct Fruit: Identifiable { let id: String }

@main
struct HelloPresentationsApp: App {
    @StateObject private var store = Store()
    var body: some Scene { WindowGroup { RootView().environmentObject(store) } }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var showSheet = false
    @State private var fruit: Fruit?
    @State private var showCover = false
    @State private var showAlert = false
    @State private var showDialog = false
    @State private var last = "none"
    var body: some View {
        NavigationStack {
            List {
                Section("Modals") {
                    Button("Open sheet") { showSheet = true }.accessibilityIdentifier("open-sheet")
                    Button("Open item sheet") { fruit = Fruit(id: "kiwi") }.accessibilityIdentifier("open-item")
                    Button("Open cover") { showCover = true }.accessibilityIdentifier("open-cover")
                    Button("Show alert") { showAlert = true }.accessibilityIdentifier("open-alert")
                    Button("Show dialog") { showDialog = true }.accessibilityIdentifier("open-dialog")
                }
                Section("State") {
                    LabeledContent("Count", value: "\(store.count)")
                    LabeledContent("Last action", value: last)
                }
            }
            .navigationTitle("Presentations")
        }
        .sheet(isPresented: $showSheet, onDismiss: { print("sheet dismissed") }) { SheetView() }
        .sheet(item: $fruit) { f in Text("Fruit: \(f.id)").padding() }
        .fullScreenCover(isPresented: $showCover) { CoverView() }
        .alert("Delete everything?", isPresented: $showAlert) {
            Button("Delete", role: .destructive) { last = "deleted"; print("alert: delete") }
            Button("Cancel", role: .cancel) { last = "cancelled" }
        } message: { Text("This cannot be undone.") }
        .confirmationDialog("Pick a size", isPresented: $showDialog, titleVisibility: .visible) {
            Button("Small") { last = "small"; print("dialog: small") }
            Button("Large") { last = "large" }
        }
        .onChange(of: showSheet) { _, v in print("showSheet \(v)") }
    }
}

struct SheetView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Sheet count \(store.count)")
                Button("Increment") { store.count += 1 }.accessibilityIdentifier("sheet-inc")
                Button("Close") { dismiss() }.accessibilityIdentifier("sheet-close")
            }
            .navigationTitle("Sheet")
        }
    }
}

struct CoverView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Color.indigo.ignoresSafeArea()
            Button("Close cover") { dismiss() }.foregroundStyle(.white).accessibilityIdentifier("cover-close")
        }
    }
}
