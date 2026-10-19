// HelloSwiftUI pages for iOS 26 additions, by launch argument: -bars (safeAreaBar), -bars-shapes (ConcentricRectangle
// in a container shape and against the screen's corners, sliderThumbVisibility, labelIconToTitleSpacing), -bars-search
// (searchToolbarBehavior(.minimize), DefaultToolbarItem(kind: .search)), -bars-tabs (tabViewSearchActivation).
import SwiftUI

struct BarsDemo: View {
    let page: String
    var body: some View {
        if #available(iOS 26.0, *) {
            switch page {
            case "shapes": BarsShapesPage()
            case "search": BarsSearchPage()
            case "tabs": BarsTabsPage()
            default: BarsBarPage()
            }
        } else {
            Text("iOS 26")
        }
    }
}

@available(iOS 26.0, *)
struct BarsBarPage: View {
    var body: some View {
        NavigationStack {
            List(1...40, id: \.self) { i in Text("Item \(i)") }
                .navigationTitle("Items")
                .safeAreaBar(edge: .bottom) {
                    Text("40 items").font(.headline).padding(12).accessibilityIdentifier("total-bar")
                }
        }
    }
}

@available(iOS 26.0, *)
struct BarsShapesPage: View {
    @State var level = 0.4
    var body: some View {
        VStack(spacing: 24) {
            // concentric with a 30 pt container 10 pt inside it: 20 pt corners
            ConcentricRectangle()
                .fill(.blue)
                .padding(10)
                .frame(width: 200, height: 120)
                .background(Color.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 30))
                .containerShape(RoundedRectangle(cornerRadius: 30))
                .accessibilityIdentifier("concentric")
            ConcentricRectangle(corners: .concentric(minimum: 12), isUniform: true)
                .fill(.green)
                .frame(width: 200, height: 60)
                .accessibilityIdentifier("screen-concentric")
            Slider(value: $level).sliderThumbVisibility(.hidden).frame(width: 240).accessibilityIdentifier("level")
            Label("Inbox", systemImage: "tray").labelIconToTitleSpacing(24).accessibilityIdentifier("wide-label")
            Label("Inbox", systemImage: "tray").accessibilityIdentifier("label")
        }
        .onChange(of: level) { print("level \(String(format: "%.2f", level))") }
    }
}

@available(iOS 26.0, *)
struct BarsSearchPage: View {
    @State var text = ""
    var body: some View {
        NavigationStack {
            List(["Apple", "Banana", "Cherry"].filter { text.isEmpty || $0.contains(text) }, id: \.self) { Text($0) }
                .navigationTitle("Fruit")
                .searchable(text: $text)
                .searchToolbarBehavior(.minimize)
                .toolbar {
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                }
        }
        .onChange(of: text) { print("query \(text)") }
    }
}

@available(iOS 26.0, *)
struct BarsTabsPage: View {
    @State var query = ""
    @State var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: 0) { Text("Home page") }
            Tab("Search", systemImage: "magnifyingglass", value: 1, role: .search) {
                NavigationStack { List(["Kiwi", "Lime"], id: \.self) { Text($0) }.navigationTitle("Search") }
                    .searchable(text: $query)
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
    }
}
