// Sample: SwiftUI containers on isim — list styles (plain, grouped, inset, inset grouped, sidebar) and row / section
// modifiers (listRowBackground, listRowInsets, listRowSeparator, listSectionSpacing, listRowSpacing,
// scrollContentBackground, headerProminence, Section(isExpanded:)), List multiple selection, lazy stacks and grids
// with pinned section headers / footers, scroll indicators and bounce behaviour.
// The page comes from the environment: PAGE=list (LIST_STYLE=plain|grouped|inset|insetGrouped|sidebar|automatic),
// selection, pinned, grid, hstack, scroll, spacing, spaces.
import SwiftUI

@main
struct HelloContainersApp: App {
    var body: some Scene { WindowGroup { Root() } }
}

let env = ProcessInfo.processInfo.environment

struct Root: View {
    var body: some View {
        switch env["PAGE"] ?? "list" {
        case "selection": SelectionPage()
        case "pinned": PinnedPage()
        case "grid": GridPage()
        case "hstack": HStackPage()
        case "scroll": ScrollPage()
        case "spacing": SpacingPage()
        case "spaces": SpacesPage()
        default: ListPage()
        }
    }
}

extension View {
    @ViewBuilder func listStyle(named name: String) -> some View {
        switch name {
        case "plain": listStyle(.plain)
        case "grouped": listStyle(.grouped)
        case "inset": listStyle(.inset)
        case "insetGrouped": listStyle(.insetGrouped)
        case "sidebar": listStyle(.sidebar)
        default: listStyle(.automatic)
        }
    }
}

struct ListPage: View {
    @State private var moreShown = true
    var body: some View {
        NavigationStack {
            List {
                Section("Fruits") {
                    Text("Apple").accessibilityIdentifier("apple")
                    Text("Banana").accessibilityIdentifier("banana")
                        .listRowBackground(Color.yellow)
                    Text("Cherry").accessibilityIdentifier("cherry")
                        .listRowSeparator(.hidden, edges: .top)
                    Text("Date").accessibilityIdentifier("date")
                        .listRowSeparatorTint(.red)
                }
                Section {
                    Text("Carrot").accessibilityIdentifier("carrot")
                        .listRowInsets(EdgeInsets(top: 20, leading: 50, bottom: 20, trailing: 20))
                    Label("Leek", systemImage: "leaf").accessibilityIdentifier("leek")
                } header: {
                    Text("Vegetables")
                } footer: {
                    Text("Fresh every day").accessibilityIdentifier("veg-footer")
                }
                Section("More", isExpanded: $moreShown) {
                    ForEach(1...3, id: \.self) { i in Text("Extra \(i)").accessibilityIdentifier("extra-\(i)") }
                }
                Section("Prominent") { Text("Big header").accessibilityIdentifier("big") }
                    .headerProminence(.increased)
            }
            .listStyle(named: env["LIST_STYLE"] ?? "automatic")
            .navigationTitle("Lists")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: moreShown) { _, v in print("more \(v ? "shown" : "hidden")") }
    }
}

struct SpacingPage: View {
    var body: some View {
        List {
            Section { Text("One").accessibilityIdentifier("one"); Text("Two").accessibilityIdentifier("two") }
            Section { Text("Three").accessibilityIdentifier("three") }
        }
        .listRowSpacing(10)
        .listSectionSpacing(.custom(50))
        .scrollContentBackground(.hidden)
        .background(Color.mint)
        .accessibilityIdentifier("spaced")
    }
}

struct Fruit: Identifiable, Hashable { let id: Int; let name: String }

struct SelectionPage: View {
    let fruits = ["Apple", "Banana", "Cherry", "Date"].enumerated().map { Fruit(id: $0.offset, name: $0.element) }
    @State private var selection = Set<Int>()
    @State private var editMode = EditMode.inactive
    var body: some View {
        NavigationStack {
            List(fruits, selection: $selection) { f in
                Text(f.name).accessibilityIdentifier("pick-\(f.name)")
            }
            .navigationTitle("Pick")
            .toolbar { EditButton() }
            .environment(\.editMode, $editMode)
            Text("selected \(selection.sorted().map(String.init).joined(separator: ","))").accessibilityIdentifier("selected")
        }
        .onChange(of: selection) { _, s in print("selected \(s.sorted().map(String.init).joined(separator: ","))") }
    }
}

struct PinnedPage: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders, .sectionFooters]) {
                ForEach(0..<3) { s in
                    Section {
                        ForEach(0..<8) { r in
                            Text("Row \(s).\(r)").frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("row-\(s)-\(r)")
                        }
                    } header: {
                        Text("Header \(s)").frame(maxWidth: .infinity, minHeight: 30).background(Color.orange).accessibilityIdentifier("header-\(s)")
                    } footer: {
                        Text("Footer \(s)").frame(maxWidth: .infinity, minHeight: 24).background(Color.teal).accessibilityIdentifier("footer-\(s)")
                    }
                }
            }
        }
        .accessibilityIdentifier("pinned-scroll")
    }
}

struct GridPage: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.fixed(60), alignment: .leading)], spacing: 12, pinnedViews: .sectionHeaders) {
                ForEach(0..<2) { s in
                    Section {
                        ForEach(0..<12) { i in Text("\(s)-\(i)").frame(height: 40).accessibilityIdentifier("cell-\(s)-\(i)") }
                    } header: {
                        Text("Grid \(s)").frame(maxWidth: .infinity, minHeight: 30).background(Color.purple.opacity(0.4)).accessibilityIdentifier("grid-header-\(s)")
                    }
                }
            }
            .padding(.horizontal)
        }
        .accessibilityIdentifier("grid-scroll")
    }
}

struct HStackPage: View {
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(0..<3) { s in
                    Section {
                        ForEach(0..<5) { i in Text("\(s):\(i)").frame(width: 80, height: 60).accessibilityIdentifier("h-\(s)-\(i)") }
                    } header: {
                        Text("S\(s)").frame(width: 40, height: 60).background(Color.green).accessibilityIdentifier("hheader-\(s)")
                    }
                }
            }
        }
        .frame(height: 80)
        .accessibilityIdentifier("hstack-scroll")
    }
}

extension View {
    /// prints `message` when the scroll view inside is pulled past its top
    @ViewBuilder func logBounce(_ message: String) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: Bool.self, of: { $0.contentOffset.y < -5 }) { _, b in if b { print(message) } }
        } else { self }
    }
}

struct ScrollPage: View {
    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                VStack { ForEach(0..<30) { Text("Visible \($0)").frame(maxWidth: .infinity) } }
            }
            .frame(height: 200)
            .accessibilityIdentifier("indicators-shown")
            ScrollView {
                VStack { ForEach(0..<30) { Text("Hidden \($0)").frame(maxWidth: .infinity) } }
            }
            .scrollIndicators(.hidden)
            .frame(height: 200)
            .accessibilityIdentifier("indicators-hidden")
            ScrollView { Text("Short content").frame(maxWidth: .infinity) }
                .scrollBounceBehavior(.basedOnSize)
                .logBounce("based on size bounced")
                .frame(height: 100)
                .accessibilityIdentifier("bounce-based")
            ScrollView { Text("Short too").frame(maxWidth: .infinity) }
                .logBounce("always bounced")
                .frame(height: 100)
                .accessibilityIdentifier("bounce-always")
        }
    }
}

/// Named coordinate spaces: GeometryReader frames in .named / .global / .scrollView, a drag measured in a named space.
struct SpacesPage: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 60)
            ZStack {
                GeometryReader { g in
                    let f = g.frame(in: .named("box")), w = g.frame(in: .global)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("in box \(Int(f.minX)),\(Int(f.minY))").accessibilityIdentifier("inbox")
                        Text("global \(Int(w.minX)),\(Int(w.minY))").accessibilityIdentifier("inglobal")
                    }
                }
                .frame(width: 150, height: 40)
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named("box")) }) { f in print("changed in box \(Int(f.minX)),\(Int(f.minY))") }
                .offset(x: 30, y: 20)
                Color.blue.opacity(0.3).frame(width: 80, height: 80).accessibilityIdentifier("dragger").offset(x: -90, y: -50)
                    .gesture(DragGesture(coordinateSpace: .named("box")).onEnded { v in print("drag in box \(Int(v.location.x)),\(Int(v.location.y))") })
            }
            .frame(width: 300, height: 200)
            .background(Color.gray.opacity(0.2))
            .coordinateSpace(.named("box"))
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 50)
                    GeometryReader { g in
                        Text("scroll y \(Int(g.frame(in: .scrollView).minY))").accessibilityIdentifier("scroll-y")
                    }
                    .frame(height: 30)
                    Color.clear.frame(height: 600)
                }
            }
            .frame(height: 200)
            .accessibilityIdentifier("spaces-scroll")
        }
    }
}
