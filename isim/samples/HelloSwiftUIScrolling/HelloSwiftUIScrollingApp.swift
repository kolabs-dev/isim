// Sample: SwiftUI list rows and scroll views on isim — deleteDisabled / moveDisabled / selectionDisabled rows,
// ScrollPosition, onScrollPhaseChange, defaultScrollAnchor, scrollClipDisabled, scrollIndicatorsFlash, and a search
// field with tokens (suggested tokens, searchCompletion with a token) bound to a FocusState with searchFocused.
// The page comes from the environment: PAGE=list (default), select, scroll, anchor, search.
import SwiftUI

@main
struct HelloSwiftUIScrollingApp: App {
    var body: some Scene { WindowGroup { Root() } }
}

let env = ProcessInfo.processInfo.environment

struct Root: View {
    var body: some View {
        switch env["PAGE"] ?? "list" {
        case "select": SelectPage()
        case "scroll": if #available(iOS 18.0, *) { ScrollPage() } else { Text("iOS 18") }
        case "anchor": if #available(iOS 18.0, *) { AnchorPage() } else { Text("iOS 18") }
        case "search": if #available(iOS 18.0, *) { SearchPage() } else { Text("iOS 18") }
        default: EditPage()
        }
    }
}

// MARK: - Rows that cannot be deleted, moved or selected

struct EditPage: View {
    @State var fruits = ["Apple", "Banana", "Locked", "Cherry"]
    var body: some View {
        NavigationStack {
            List {
                ForEach(fruits, id: \.self) { f in
                    Text(f)
                        .deleteDisabled(f == "Locked")
                        .moveDisabled(f == "Locked")
                }
                .onDelete { fruits.remove(atOffsets: $0); print("order \(fruits.joined(separator: ","))") }
                .onMove { fruits.move(fromOffsets: $0, toOffset: $1); print("order \(fruits.joined(separator: ","))") }
            }
            .navigationTitle("Fruits")
            .toolbar { EditButton() }
        }
    }
}

struct SelectPage: View {
    @State var picked: String?
    var body: some View {
        NavigationStack {
            List(selection: $picked) {
                ForEach(["Red", "Green", "Blue"], id: \.self) { c in
                    Text(c).accessibilityIdentifier("pick-\(c)")
                        .selectionDisabled(c == "Green")
                }
            }
            .navigationTitle("Colors")
            .onChange(of: picked) { print("picked \(picked ?? "none")") }
        }
    }
}

// MARK: - ScrollPosition and phases

@available(iOS 18.0, *)
struct ScrollPage: View {
    @State var position = ScrollPosition(idType: Int.self)
    @State var flashes = 0
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button("Top") { position.scrollTo(edge: .top) }.accessibilityIdentifier("to-top")
                Button("Row 20") { position.scrollTo(id: 20) }.accessibilityIdentifier("to-20")
                Button("Bottom") { position.scrollTo(edge: .bottom) }.accessibilityIdentifier("to-bottom")
                Button("y 300") { position.scrollTo(y: 300) }.accessibilityIdentifier("to-y")
                Button("Flash") { flashes += 1 }.accessibilityIdentifier("flash")
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<40, id: \.self) { i in
                        Text("Row \(i)").frame(maxWidth: .infinity, minHeight: 50).background(i % 2 == 0 ? Color.blue.opacity(0.15) : Color.clear)
                    }
                }
                .scrollTargetLayout()
            }
            .accessibilityIdentifier("scroller")
            .scrollPosition($position)
            .scrollIndicatorsFlash(trigger: flashes)
            .onScrollPhaseChange { old, new, context in
                print("phase \(old) -> \(new)\(new == .decelerating || (old == .interacting && new == .idle) ? context.velocity == nil ? " no velocity" : " velocity" : "")")
            }
            .onScrollGeometryChange(for: Int.self, of: { Int($0.contentOffset.y.rounded()) }) { _, y in print("offset \(y)") }
            .onChange(of: position) {
                print("position id \(position.viewID(type: Int.self).map(String.init) ?? "none") edge \(position.edge.map { "\($0)" } ?? "none") user \(position.isPositionedByUser)")
            }
        }
    }
}

// MARK: - Default anchors, clipping

@available(iOS 18.0, *)
struct AnchorPage: View {
    @State var messages = (1...20).map { "Message \($0)" }
    var body: some View {
        VStack(spacing: 8) {
            Button("Add") { messages.append("Message \(messages.count + 1)") }.accessibilityIdentifier("add")
            // a chat: starts at the bottom and stays there as messages arrive
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(messages, id: \.self) { m in Text(m).frame(maxWidth: .infinity, minHeight: 40) }
                }
            }
            .frame(height: 300)
            .defaultScrollAnchor(.bottom)
            .onScrollGeometryChange(for: Int.self, of: { Int(($0.contentSize.height - $0.contentOffset.y - $0.containerSize.height).rounded()) }) { _, d in
                print("from bottom \(d)")
            }
            // small content centred in its scroll view
            ScrollView {
                Text("Centred").accessibilityIdentifier("centred")
            }
            .frame(height: 120)
            .border(Color.gray)
            .accessibilityIdentifier("small")
            .defaultScrollAnchor(.center, for: .alignment)
            // content that draws outside its scroll view
            ScrollView(.horizontal) {
                HStack { ForEach(0..<8) { i in Color.orange.frame(width: 60, height: 60) } }
                    .offset(y: -40)
            }
            .frame(height: 60)
            .scrollClipDisabled()
            .padding(.top, 50)
            .accessibilityIdentifier("unclipped")
        }
        .onAppear { print("anchor page") }
    }
}

// MARK: - Search tokens, searchFocused

struct ColorToken: Identifiable, Hashable {
    let name: String, symbol: String
    var id: String { name }
}
let allColors = [ColorToken(name: "Red", symbol: "flame"), ColorToken(name: "Green", symbol: "leaf"), ColorToken(name: "Blue", symbol: "drop")]

@available(iOS 18.0, *)
struct SearchPage: View {
    @State var text = ""
    @State var tokens: [ColorToken] = []
    @State var suggested = [allColors[0], allColors[2]]
    @FocusState var focused: Bool
    var body: some View {
        NavigationStack {
            List(allColors.filter { c in tokens.isEmpty || tokens.contains(c) }) { c in Label(c.name, systemImage: c.symbol) }
                .navigationTitle("Colors")
                .searchable(text: $text, tokens: $tokens, suggestedTokens: $suggested, prompt: "Colors") { t in
                    Label(t.name, systemImage: t.symbol)
                }
                .searchSuggestions {
                    ForEach(allColors.filter { !text.isEmpty && $0.name.lowercased().hasPrefix(text.lowercased()) }) { c in
                        Text(c.name).accessibilityIdentifier("complete-\(c.name)").searchCompletion(c)
                    }
                }
                .searchFocused($focused)
                .toolbar { Button(focused ? "Done" : "Find") { focused.toggle() }.accessibilityIdentifier("toggle-focus") }
        }
        .onChange(of: focused) { print("search focused \(focused)") }
        .onChange(of: tokens) { print("tokens \(tokens.map(\.name).joined(separator: ","))") }
        .onChange(of: text) { print("text '\(text)'") }
    }
}
