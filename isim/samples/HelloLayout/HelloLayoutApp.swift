// Sample: SwiftUI layout on isim — Grid/GridRow, LazyHGrid, ViewThatFits, a custom Layout (flow) and AnyLayout,
// alignment guides (built-in and custom AlignmentID), position, containerRelativeFrame, safeAreaInset, preferences
// (PreferenceKey, anchors), onGeometryChange, @ScaledMetric, and scroll behaviours (paging, view-aligned snapping,
// scrollPosition, scrollDisabled, contentMargins).
import SwiftUI

@main
struct HelloLayoutApp: App {
    var body: some Scene { WindowGroup { Root() } }
}

struct Root: View {
    var body: some View {
        TabView {
            GridTab().tabItem { Label("Grid", systemImage: "square.grid.2x2") }
            AlignTab().tabItem { Label("Align", systemImage: "circle") }
            ScrollTab().tabItem { Label("Scroll", systemImage: "list.bullet") }
        }
    }
}

/// Wraps its children onto new lines when a row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        return CGSize(width: rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(bounds.width, subviews) {
            for (i, x) in row.items { subviews[i].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + row.y), proposal: .unspecified) }
        }
    }
    struct Row { var items: [(Int, CGFloat)] = []; var width: CGFloat = 0; var y: CGFloat = 0; var height: CGFloat = 0 }
    func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for (i, s) in subviews.enumerated() {
            let size = s.sizeThatFits(.unspecified)
            if rows[rows.count - 1].width > 0 && rows[rows.count - 1].width + spacing + size.width > maxWidth {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            let x = rows[rows.count - 1].width > 0 ? rows[rows.count - 1].width + spacing : 0
            rows[rows.count - 1].items.append((i, x))
            rows[rows.count - 1].width = x + size.width
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}

struct GridTab: View {
    @State private var vertical = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Fruit").bold()
                        Text("Qty").bold().gridColumnAlignment(.trailing)
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    GridRow { Text("Apples"); Text("12").accessibilityIdentifier("qty-apples") }
                    GridRow { Text("Kiwi"); Text("7").accessibilityIdentifier("qty-kiwi") }
                    GridRow { Text("All fruit, both columns").gridCellColumns(2).accessibilityIdentifier("span") }
                }
                .accessibilityIdentifier("grid")
                ScrollView(.horizontal) {
                    LazyHGrid(rows: [GridItem(.fixed(30)), GridItem(.fixed(30))], spacing: 10) {
                        ForEach(0..<6) { i in Text("H\(i)").frame(width: 40).accessibilityIdentifier("h\(i)") }
                    }
                }
                .frame(height: 70)
                HStack {
                    ViewThatFits { Text("A rather long label that cannot fit"); Text("Short") }
                        .frame(width: 120).accessibilityIdentifier("fits-narrow")
                    ViewThatFits { Text("Wide label"); Text("W") }.accessibilityIdentifier("fits-wide")
                }
                FlowLayout {
                    ForEach(["swift", "ui", "layout", "protocol", "on", "isim", "wraps", "tags"], id: \.self) { t in
                        Text(t).padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.2), in: Capsule()).accessibilityIdentifier("tag-\(t)")
                    }
                }
                .frame(width: 200, alignment: .leading)
                let layout = vertical ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())
                layout {
                    Text("One").accessibilityIdentifier("any-1")
                    Text("Two").accessibilityIdentifier("any-2")
                }
                Button("Switch layout") { vertical.toggle() }.accessibilityIdentifier("switch")
            }
            .padding()
        }
    }
}

struct MidAccount: AlignmentID { static func defaultValue(in d: ViewDimensions) -> CGFloat { d[.leading] } }
extension HorizontalAlignment { static let midAccount = HorizontalAlignment(MidAccount.self) }

struct MaxWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
struct SelectedBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = value ?? nextValue() }
}

struct AlignTab: View {
    @State private var maxWidth: CGFloat = 0
    @State private var wide = false
    @ScaledMetric var avatar: CGFloat = 40
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading) {
                Text("Leading").accessibilityIdentifier("guide-a")
                Text("Indented").alignmentGuide(.leading) { _ in -24 }.accessibilityIdentifier("guide-b")
            }
            VStack(alignment: .midAccount) {
                HStack { Text("User:"); Text("kim").alignmentGuide(.midAccount) { d in d[.leading] }.accessibilityIdentifier("acct-1") }
                HStack { Text("Password:"); Text("****").alignmentGuide(.midAccount) { d in d[.leading] }.accessibilityIdentifier("acct-2") }
            }
            ZStack { Circle().fill(Color.red).frame(width: 20, height: 20).position(x: 50, y: 30).accessibilityIdentifier("dot") }
                .frame(width: 200, height: 60).background(Color.gray.opacity(0.2))
            VStack(alignment: .leading) {
                Text("a").background(GeometryReader { g in Color.clear.preference(key: MaxWidthKey.self, value: g.size.width) })
                Text("a much longer one").background(GeometryReader { g in Color.clear.preference(key: MaxWidthKey.self, value: g.size.width) })
            }
            .onPreferenceChange(MaxWidthKey.self) { w in maxWidth = w; print("max width \(Int(w))") }
            Text("widest \(Int(maxWidth))").accessibilityIdentifier("widest")
            HStack(spacing: 30) {
                Text("First"); Text("Second").anchorPreference(key: SelectedBoundsKey.self, value: .bounds) { $0 }; Text("Third")
            }
            .overlayPreferenceValue(SelectedBoundsKey.self) { anchor in
                GeometryReader { g in
                    if let anchor {
                        let r = g[anchor]
                        Rectangle().fill(Color.blue.opacity(0.3)).frame(width: r.width, height: 3).offset(x: r.minX, y: r.maxY).accessibilityIdentifier("underline")
                    }
                }
            }
            Text(wide ? "wider and wider text" : "narrow")
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { w in print("geometry width \(Int(w))") }
                .onTapGesture { wide.toggle() }
                .accessibilityIdentifier("geo")
            AvatarSize().environment(\.dynamicTypeSize, .xxxLarge)
            Text("avatar \(Int(avatar))").accessibilityIdentifier("avatar-default")
            Color.clear.frame(height: 50)
                .safeAreaInset(edge: .bottom, spacing: 4) { Text("Inset bar").accessibilityIdentifier("inset-bar") }
                .accessibilityIdentifier("inset-host")
        }
        .padding()
    }
}
struct AvatarSize: View {
    @ScaledMetric(relativeTo: .body) var size: CGFloat = 34
    var body: some View { Text("scaled \(Int(size))").accessibilityIdentifier("avatar-xxxl") }
}

struct ScrollTab: View {
    @State private var position: Int? = nil
    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<4) { i in
                        Text("Page \(i)").frame(maxWidth: .infinity).containerRelativeFrame(.vertical)
                            .background(i % 2 == 0 ? Color.orange.opacity(0.3) : Color.green.opacity(0.3))
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .frame(height: 150)
            .accessibilityIdentifier("pager")
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(0..<12) { i in Text("Row \(i)").frame(maxWidth: .infinity, minHeight: 50).background(Color.gray.opacity(0.2)).id(i) }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position)
            .frame(height: 200)
            .accessibilityIdentifier("aligned")
            Text("position \(position.map(String.init) ?? "none")").accessibilityIdentifier("position")
            HStack {
                Button("Go to 8") { position = 8 }.accessibilityIdentifier("go8")
            }
            ScrollView { VStack { ForEach(0..<10) { Text("Locked \($0)") } } }
                .scrollDisabled(true).frame(height: 60).accessibilityIdentifier("locked")
            ScrollView(.horizontal) { HStack { ForEach(0..<6) { Text("M\($0)").accessibilityIdentifier("m\($0)") } } }
                .contentMargins(.horizontal, 30)
        }
        .onChange(of: position) { _, p in print("position \(p.map(String.init) ?? "none")") }
    }
}
