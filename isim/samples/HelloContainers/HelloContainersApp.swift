// Sample: SwiftUI containers on isim — list styles (plain, grouped, inset, inset grouped, sidebar) and row / section
// modifiers (listRowBackground, listRowInsets, listRowSeparator, listSectionSpacing, listRowSpacing,
// scrollContentBackground, headerProminence, Section(isExpanded:)), List multiple selection, lazy stacks and grids
// with pinned section headers / footers, scroll indicators and bounce behaviour.
// The page comes from the environment: PAGE=list (LIST_STYLE=plain|grouped|inset|insetGrouped|sidebar|automatic),
// selection, pinned, grid, hstack, scroll, spacing, spaces, subviews (custom containers, container values, @Entry,
// @Animatable), insets (safeAreaInset, safeAreaPadding, contentMargins), crf (containerRelativeFrame in a stack).
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
        case "subviews": SubviewsPage()
        case "insets": InsetsPage()
        case "crf": RelativeFramePage()
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

// MARK: - Custom containers (iOS 18): Group(subviews:), ForEach(sections:), container values, @Entry

extension ContainerValues { @Entry var cardTint: Color = .gray }
extension EnvironmentValues { @Entry var greeting: String = "Hello" }
extension Transaction { @Entry var origin: String = "unknown" }

/// Lays its content out as cards: a count, each view on a tinted card (its cardTint), the first one again in big type.
struct CardStack<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 6) {
            Group(subviews: content) { subviews in
                Text("\(subviews.count) cards").accessibilityIdentifier("card-count")
                ForEach(subviews) { s in
                    s.padding(6).frame(maxWidth: .infinity).background(s.containerValues.cardTint.opacity(0.4))
                }
                if let first = subviews.first {
                    first.font(.largeTitle)
                }
            }
        }
    }
}
/// Each section of its content: the header in bold, the items, how many there were.
struct SectionSummary<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(sections: content) { section in
                section.header.bold()
                ForEach(section.content) { item in item.padding(.leading, 12) }
                Text("\(section.content.count) in \(section.containerValues.cardTint == .red ? "red" : "plain") section")
                    .accessibilityIdentifier("section-count-\(section.content.count)")
            }
        }
    }
}
struct Greeting: View {
    @Environment(\.greeting) var greeting
    var body: some View { Text("\(greeting), world").accessibilityIdentifier("greeting") }
}
@available(iOS 26.0, *)
@Animatable
struct Ring: Shape {
    var progress: Double
    var width: CGFloat
    @AnimatableIgnored var label: String = "ring"
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) / 2 - width,
                 startAngle: .degrees(0), endAngle: .degrees(360 * progress), clockwise: false)
        return p
    }
}

struct SubviewsPage: View {
    @State private var flag = false
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CardStack {
                    Text("Alpha").accessibilityIdentifier("alpha")
                    Text("Beta").containerValue(\.cardTint, .red).accessibilityIdentifier("beta")
                    ForEach(["Gamma", "Delta"], id: \.self) { Text($0).accessibilityIdentifier($0.lowercased()) }
                }
                SectionSummary {
                    Section("Fruit") { Text("Apple"); Text("Pear") }
                    Section { Text("Leek") } header: { Text("Veg") }
                        .containerValue(\.cardTint, .red)
                    Text("Loose")
                }
                Greeting()
                Greeting().environment(\.greeting, "Hi")
                Text(flag ? "on" : "off")
                    .transaction { t in print("transaction origin \(t.origin), animated \(t.animation != nil)") }
                    .accessibilityIdentifier("flag")
                Button("Toggle") { withTransaction(\.origin, "button") { flag.toggle() } }.accessibilityIdentifier("toggle")
                Button("Animate") { withAnimation(.easeIn) { flag.toggle() } }.accessibilityIdentifier("animate")
            }
            .padding()
        }
        .onAppear {
            if #available(iOS 26.0, *) {
                var r = Ring(progress: 0.25, width: 4)
                print("ring data \(r.animatableData.first) \(r.animatableData.second)")
                r.animatableData = AnimatablePair(0.5, 8)
                print("ring set \(r.progress) \(r.width) \(r.label)")
            }
        }
    }
}

// MARK: - Safe area insets and padding, content margins, containerRelativeFrame

struct InsetsPage: View {
    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<20) { i in Text("Item \(i)").frame(maxWidth: .infinity, minHeight: 40).accessibilityIdentifier("item-\(i)") }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Bottom bar").frame(maxWidth: .infinity, minHeight: 50).background(Color.orange.opacity(0.8)).accessibilityIdentifier("bottom-bar")
            }
            .frame(height: 300)
            .accessibilityIdentifier("inset-scroll")
            List { ForEach(0..<10) { i in Text("Row \(i)").accessibilityIdentifier("prow-\(i)") } }
                .safeAreaPadding(.top, 30)
                .frame(height: 200)
                .accessibilityIdentifier("padded-list")
            Text("Padded").safeAreaPadding(.horizontal, 40).background(Color.yellow).accessibilityIdentifier("padded-text")
            ScrollView { VStack { ForEach(0..<20) { Text("M\($0)") } } }
                .contentMargins(.vertical, 20, for: .scrollIndicators)
                .frame(height: 120)
                .accessibilityIdentifier("margins-scroll")
        }
    }
}

struct RelativeFramePage: View {
    var body: some View {
        NavigationStack {
            Color.teal
                .containerRelativeFrame([.horizontal, .vertical]) { length, _ in length / 2 }
                .accessibilityIdentifier("half")
                .navigationTitle("Relative")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
