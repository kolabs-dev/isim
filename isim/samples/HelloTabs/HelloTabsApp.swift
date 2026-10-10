// Sample: TabView and bar features across iOS versions on isim — TabSection and the iPad sidebar (iOS 18), the bottom
// accessory, tab bar minimizing, scroll edge effects, background extension and merging, morphing (glassEffectID) and interactive glass (iOS 26), toolbar overflow
// by visibility priority, pinned trailing items, ToolbarOverflowMenu, ToolbarSpacer and bottom bar minimizing (iOS 27);
// the search tab's .searchable field in the iOS 26 tab bar; PROMINENT=1: a TabRole.prominent tab instead (iOS 27);
// tabViewCustomization kept in @AppStorage (the iPad sidebar's Edit mode hides and moves tabs).
import SwiftUI

@main
struct HelloTabsApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(iOS 18.0, *) { TabsRoot() } else { Text("Needs iOS 18") }
        }
    }
}

@available(iOS 18.0, *)
struct TabsRoot: View {
    @State private var tab = 0
    @AppStorage("tab-customization") private var customization: TabViewCustomization
    var body: some View {
        TabView(selection: $tab) {
            TabSection("Main") {
                Tab("Home", systemImage: "house", value: 0) { HomeTab() }.customizationID("home")
                Tab("Bars", systemImage: "hammer", value: 1) { BarsTab() }.customizationID("bars")
            }
            .customizationID("main")
            TabSection("More") {
                Tab("Glass", systemImage: "circle", value: 2) { GlassTab() }.customizationID("glass")
            }
            .customizationID("more")
            if ProcessInfo.processInfo.environment["PROMINENT"] == "1", #available(iOS 27.0, *) {
                Tab("New", systemImage: "plus", value: 3, role: .prominent) { Text("New item").accessibilityIdentifier("new-tab") }
            } else {
                Tab("Search", systemImage: "magnifyingglass", value: 3, role: .search) { SearchTab() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($customization)
        .modifier(TabExtras())
        .onChange(of: customization) { _, c in
            print("customization main \(c[sectionID: "main"]?.joined(separator: ",") ?? "-") glass \(c[tab: "glass"].tabBarVisibility == .hidden ? "hidden" : "shown")")
        }
        .onChange(of: tab) { _, t in print("tab \(t)") }
    }
}

/// iOS 26: the bottom accessory and minimizing on scroll down.
struct TabExtras: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .tabViewBottomAccessory { AccessoryView() }
                .tabBarMinimizeBehavior(.onScrollDown)
        } else { content }
    }
}
@available(iOS 26.0, *)
struct AccessoryView: View {
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    var body: some View {
        HStack { Image(systemName: "play.fill"); Text(placement == .inline ? "Inline" : "Now Playing") }
            .accessibilityIdentifier("accessory-label")
    }
}

struct HomeTab: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                LinearGradient(colors: [.purple, .orange], startPoint: .top, endPoint: .bottom).frame(height: 160)
                    .modifier(Extension()).accessibilityIdentifier("hero")
                ForEach(0..<40, id: \.self) { i in Text("Home row \(i)").frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("home-\(i)") }
            }
        }
        .accessibilityIdentifier("home-scroll")
    }
}
struct Extension: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) { content.backgroundExtensionEffect() } else { content }
    }
}

struct BarsTab: View {
    var body: some View {
        if #available(iOS 27.0, *) { Bars27() } else {
            NavigationStack { Text("Bars need iOS 27").navigationTitle("Bars") }
        }
    }
}
@available(iOS 27.0, *)
struct Bars27: View {
    var body: some View {
        NavigationStack {
            List {
                // iOS 27: AsyncImage from a URLRequest, loaded with the session set by asyncImageURLSession
                AsyncImage(request: URLRequest(url: URL(string: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEUlEQVR4nGP4z8AARwgWXg4ArpMP8aaUSCMAAAAASUVORK5CYII=")!))
                    .frame(width: 24, height: 24).accessibilityIdentifier("async-request")
                ForEach(0..<40, id: \.self) { i in Text("Bar row \(i)").accessibilityIdentifier("bar-\(i)") }
            }
                .navigationTitle("Bars")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button { print("bars: star") } label: { Image(systemName: "star") }.accessibilityIdentifier("tb-star") }
                        .visibilityPriority(.high)
                    ToolbarItem(placement: .topBarTrailing) { Button("Heart") { print("bars: heart") }.accessibilityIdentifier("tb-heart") }
                        .visibilityPriority(.low)
                    ToolbarItem(placement: .topBarTrailing) { Button { print("bars: bell") } label: { Image(systemName: "bell") }.accessibilityIdentifier("tb-bell") }
                    ToolbarSpacer(.fixed)
                    ToolbarItem(placement: .topBarPinnedTrailing) { Button { print("bars: settings") } label: { Image(systemName: "gear") }.accessibilityIdentifier("tb-pinned") }
                    ToolbarOverflowMenu { Button("Extra") { print("bars: extra") } }
                    ToolbarItem(placement: .bottomBar) { Button("Compose") { print("bars: compose") }.accessibilityIdentifier("bb-compose") }
                }
                .toolbarMinimizationBehavior(.onScrollDown, for: .bottomBar, .navigationBar)
                .scrollEdgeEffectStyle(.hard, for: .top)
                .toolbar(.hidden, for: .tabBar)
        }
        .asyncImageURLSession(URLSession(configuration: .ephemeral))
    }
}

struct GlassTab: View {
    @Namespace private var ns
    @State private var expanded = false
    var body: some View {
        if #available(iOS 26.0, *) {
            VStack(spacing: 30) {
                GlassEffectContainer(spacing: 20) {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil").frame(width: 50, height: 50).glassEffect().accessibilityIdentifier("g-near-1")
                        Image(systemName: "pencil.circle").frame(width: 50, height: 50).glassEffect().accessibilityIdentifier("g-near-2")
                        Color.clear.frame(width: 60, height: 1)
                        Image(systemName: "trash").frame(width: 50, height: 50).glassEffect().accessibilityIdentifier("g-far")
                    }
                }
                GlassEffectContainer {
                    HStack(spacing: 80) {
                        Image(systemName: "star").frame(width: 50, height: 50).glassEffect().glassEffectUnion(id: "pair", namespace: ns).accessibilityIdentifier("g-pair-1")
                        Image(systemName: "heart").frame(width: 50, height: 50).glassEffect().glassEffectUnion(id: "pair", namespace: ns).accessibilityIdentifier("g-pair-2")
                    }
                }
                // glassEffectID: the second shape grows out of the first (and shrinks back into it), slowly
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 40) {
                        Image(systemName: "pencil").frame(width: 50, height: 50).glassEffect().glassEffectID("pencil", in: ns).accessibilityIdentifier("g-morph-a")
                        if expanded {
                            Image(systemName: "note").frame(width: 50, height: 50).glassEffect().glassEffectID("note", in: ns)
                                .glassEffectTransition(.matchedGeometry).accessibilityIdentifier("g-morph-b")
                        }
                    }
                    .frame(width: 240, alignment: .leading)
                }
                HStack(spacing: 30) {
                    Button(expanded ? "Collapse" : "Expand") {
                        withAnimation(.linear(duration: 2.5)) { expanded.toggle() }
                    }.accessibilityIdentifier("g-expand")
                    Image(systemName: "hand.tap").frame(width: 50, height: 50).glassEffect(.regular.interactive()).accessibilityIdentifier("g-interactive")
                        .onLongPressGesture(minimumDuration: 0.4) { reportGlassEdge() }
                }
            }
            .padding(.top, 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.teal.opacity(0.4))
        } else { Text("Glass needs iOS 26") }
    }
}

/// While the interactive glass is held: the colour just outside its right edge, from a render of the window (the
/// glass grows a little while touched).
@MainActor func reportGlassEdge() {
    guard let w = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
    func find(_ v: UIView) -> UIView? { v.accessibilityIdentifier == "g-interactive" ? v : v.subviews.lazy.compactMap(find).first }
    guard let v = find(w) else { return }
    let f = v.convert(v.bounds, to: w), p = CGPoint(x: f.maxX + 1.5, y: f.midY)
    let img = UIGraphicsImageRenderer(bounds: w.bounds, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { _ in
        w.drawHierarchy(in: w.bounds, afterScreenUpdates: false)
    }
    guard let cg = img.cgImage, let data = cg.dataProvider?.data, let b = CFDataGetBytePtr(data) else { return }
    let o = Int(p.y) * cg.bytesPerRow + Int(p.x) * cg.bitsPerPixel / 8
    print("glass held edge \(b[o]) \(b[o + 1]) \(b[o + 2])")
}

/// The search tab: a list filtered by its .searchable (iOS 26: the field is in the tab bar).
struct SearchTab: View {
    @State private var query = ""
    let fruits = ["Apple", "Apricot", "Banana", "Cherry"]
    var body: some View {
        NavigationStack {
            List(fruits.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { Text($0).accessibilityIdentifier("fruit-\($0)") }
                .navigationTitle("Search")
                .accessibilityIdentifier("search-tab")
        }
        .searchable(text: $query)
        .onChange(of: query) { _, q in print("query \(q)") }
    }
}
