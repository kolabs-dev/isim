// Sample: SwiftUI navigation chrome on isim — NavigationStack push/pop animations and the edge swipe back, zoom and
// cross-fade navigation transitions (iOS 18 / 27), toolbar placements (leading, several trailing items, principal,
// secondaryAction "More" menu, bottom bar + status, keyboard bar), toolbarTitleMenu, toolbarRole(.editor),
// navigationBarBackButtonHidden with a custom back button.
import SwiftUI

@main
struct HelloNavStackApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

enum Route: Hashable { case detail(Int), zoom, editor, custom, bottom, fade, search }

struct RootView: View {
    @State private var path: [Route] = []
    @State private var log = "none"
    @Namespace private var ns
    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Push") {
                    NavigationLink("Detail 1", value: Route.detail(1)).accessibilityIdentifier("push-detail")
                    NavigationLink(value: Route.zoom) {
                        HStack { Color.orange.frame(width: 44, height: 44).cornerRadius(8); Text("Zoom") }
                            .modifier(ZoomSource(ns: ns))
                    }.accessibilityIdentifier("push-zoom")
                    NavigationLink("Editor role", value: Route.editor).accessibilityIdentifier("push-editor")
                    NavigationLink("Custom back", value: Route.custom).accessibilityIdentifier("push-custom")
                    NavigationLink("Bottom bar", value: Route.bottom).accessibilityIdentifier("push-bottom")
                    NavigationLink("Cross-fade", value: Route.fade).accessibilityIdentifier("push-fade")
                    NavigationLink("Search", value: Route.search).accessibilityIdentifier("push-search")
                }
                Section("State") { LabeledContent("Last", value: log) }
            }
            .navigationTitle("Stack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Edit") { log = "edit"; print("tb: edit") }.accessibilityIdentifier("tb-edit") }
                ToolbarItem(placement: .topBarTrailing) { Button { log = "add"; print("tb: add") } label: { Image(systemName: "plus") }.accessibilityIdentifier("tb-add") }
                ToolbarItem(placement: .primaryAction) { Button { log = "share"; print("tb: share") } label: { Image(systemName: "square.and.arrow.up") }.accessibilityIdentifier("tb-share") }
                ToolbarItem(placement: .secondaryAction) { Button("Archive") { log = "archive"; print("tb: archive") } }
                ToolbarItem(placement: .secondaryAction) { Button("Duplicate") { log = "duplicate" } }
            }
            .toolbarTitleMenu {
                Button("Rename") { log = "rename"; print("title menu: rename") }
                Button("Move") { log = "move" }
            }
            .navigationDestination(for: Route.self) { r in
                switch r {
                case .detail(let n): DetailView(n: n, path: $path)
                case .zoom: ZoomView().modifier(ZoomTransition(ns: ns))
                case .editor: Text("Editing").navigationTitle("Editor").toolbarRole(.editor).accessibilityIdentifier("editor-page")
                case .custom: CustomBackView()
                case .bottom: BottomBarView()
                case .fade: Text("Faded in").navigationTitle("Fade").modifier(FadeTransition()).accessibilityIdentifier("fade-page")
                case .search: SearchPage()
                }
            }
        }
        .onChange(of: path) { _, p in print("path \(p.count)") }
    }
}

struct ZoomSource: ViewModifier {
    let ns: Namespace.ID
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) { content.matchedTransitionSource(id: "card", in: ns) } else { content }
    }
}
struct ZoomTransition: ViewModifier {
    let ns: Namespace.ID
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) { content.navigationTransition(.zoom(sourceID: "card", in: ns)) } else { content }
    }
}
struct FadeTransition: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) { content.navigationTransition(.crossFade) } else { content }
    }
}

struct DetailView: View {
    let n: Int
    @Binding var path: [Route]
    var body: some View {
        VStack(spacing: 20) {
            Text("Detail \(n)").font(.largeTitle).accessibilityIdentifier("detail-\(n)")
            Button("Next") { path.append(.detail(n + 1)) }.accessibilityIdentifier("next-\(n)")
            Button("Pop to root") { path.removeAll() }.accessibilityIdentifier("root-\(n)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.85, green: 0.92, blue: 1))
        .navigationTitle("Detail \(n)")
        .toolbar { ToolbarItem(placement: .principal) { Text("Principal \(n)").font(.headline).accessibilityIdentifier("principal") } }
        .toolbarBackground(Color.yellow, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct ZoomView: View {
    var body: some View {
        Color.orange.overlay { Text("Zoomed").font(.largeTitle).accessibilityIdentifier("zoom-page") }
            .navigationTitle("Zoom")
    }
}

struct CustomBackView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Text("No back button").accessibilityIdentifier("custom-page")
            .navigationTitle("Custom")
            .navigationBarBackButtonHidden(true)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() }.accessibilityIdentifier("custom-close") } }
    }
}

struct BottomBarView: View {
    @State private var text = ""
    @State private var count = 0
    var body: some View {
        VStack {
            TextField("Type here", text: $text).textFieldStyle(.roundedBorder).padding().accessibilityIdentifier("field")
            Text("Count \(count)")
            Spacer()
        }
        .navigationTitle("Bottom")
        .toolbar {
            ToolbarItem(placement: .bottomBar) { Button { count -= 1 } label: { Image(systemName: "minus") }.accessibilityIdentifier("bb-minus") }
            ToolbarItem(placement: .status) { Text("\(count) items").font(.caption).accessibilityIdentifier("bb-status") }
            ToolbarItem(placement: .bottomBar) { Button { count += 1; print("bottom: plus \(count)") } label: { Image(systemName: "plus") }.accessibilityIdentifier("bb-plus") }
            ToolbarItem(placement: .keyboard) { Button("Done") { print("keyboard: done") }.accessibilityIdentifier("kb-done") }
        }
    }
}

/// searchable with suggestions (searchCompletion fills the field) and a scope bar.
struct SearchPage: View {
    @State private var text = ""
    @State private var scope = 0
    let fruits = ["Apple", "Apricot", "Banana", "Cherry"]
    var body: some View {
        List(fruits.filter { text.isEmpty || $0.localizedCaseInsensitiveContains(text) }, id: \.self) { Text($0).accessibilityIdentifier("result-\($0)") }
            .navigationTitle("Search")
            .searchable(text: $text, prompt: "Fruit")
            .searchSuggestions {
                if text.isEmpty {
                    Text("Apple").searchCompletion("Apple").accessibilityIdentifier("suggest-Apple")
                    Text("Cherry").searchCompletion("Cherry").accessibilityIdentifier("suggest-Cherry")
                }
            }
            .searchScopes($scope) { Text("All").tag(0); Text("Red").tag(1); Text("Yellow").tag(2) }
            .onChange(of: text) { _, t in print("search text \(t)") }
            .onChange(of: scope) { _, s in print("scope \(s)") }
    }
}
