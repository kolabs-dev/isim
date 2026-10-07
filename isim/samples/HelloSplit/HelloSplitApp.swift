// Sample: NavigationSplitView on isim — iPad: three columns side by side (sidebar, content, detail) with selection,
// the sidebar button, columnVisibility, column widths and the prominentDetail style; iPhone: the columns as a stack.
import SwiftUI

@main
struct HelloSplitApp: App {
    var body: some Scene { WindowGroup { SplitRoot() } }
}

struct SplitRoot: View {
    @State private var visibility = NavigationSplitViewVisibility.all
    @State private var folder: String? = "Inbox"
    @State private var item: Int? = nil
    @State private var prominent = false
    let folders = ["Inbox", "Archive", "Trash"]
    var body: some View {
        let split = NavigationSplitView(columnVisibility: $visibility) {
            List(folders, id: \.self, selection: $folder) { f in Text(f).accessibilityIdentifier("folder-\(f)") }
                .navigationTitle("Folders")
                .navigationSplitViewColumnWidth(240)
        } content: {
            List(1...4, id: \.self, selection: $item) { i in Text("\(folder ?? "-") \(i)").accessibilityIdentifier("item-\(i)") }
                .navigationTitle(folder ?? "None")
        } detail: {
            VStack(spacing: 16) {
                Text(item.map { "Message \($0) in \(folder ?? "-")" } ?? "Nothing selected").accessibilityIdentifier("detail-text")
                Button("Detail only") { visibility = .detailOnly }.accessibilityIdentifier("detail-only")
                Button("All columns") { visibility = .all }.accessibilityIdentifier("all-columns")
                Button("Prominent detail") { prominent.toggle() }.accessibilityIdentifier("prominent")
            }
            .navigationTitle("Detail")
        }
        .onChange(of: visibility) { _, v in print("visibility \(v == .all ? "all" : v == .detailOnly ? "detailOnly" : v == .doubleColumn ? "doubleColumn" : "automatic")") }
        .onChange(of: item) { _, i in print("item \(i ?? 0)") }
        if prominent { split.navigationSplitViewStyle(.prominentDetail) } else { split.navigationSplitViewStyle(.balanced) }
    }
}
