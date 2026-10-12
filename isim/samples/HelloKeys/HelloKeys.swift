// Sample: SwiftUI hardware-keyboard and focus APIs on isim — .keyboardShortcut (Cmd+S, cancelAction),
// .onKeyPress (arrow keys and characters) on a focusable view, .inspector, .defaultFocus, @FocusedValue /
// .focusedValue / .focusedSceneValue following focus, focusable views in focus sections (Tab moves between them),
// and UIViewRepresentable.sizeThatFits(_:uiView:context:).
import SwiftUI
import UIKit

struct SelectionKey: FocusedValueKey { typealias Value = String }
extension FocusedValues {
    var selection: String? { get { self[SelectionKey.self] } set { self[SelectionKey.self] = newValue } }
}

/// a UIKit view with its own SwiftUI size
struct Badge: UIViewRepresentable {
    func makeUIView(context: Context) -> UILabel { let l = UILabel(); l.text = "badge"; l.backgroundColor = .systemYellow; l.accessibilityIdentifier = "badge"; return l }
    func updateUIView(_ uiView: UILabel, context: Context) {}
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? { CGSize(width: 123, height: 45) }
}

struct SelectionReader: View {
    @FocusedValue(\.selection) var selection
    var body: some View {
        Text("focused: \(selection ?? "none")").accessibilityIdentifier("reader")
            .onChange(of: selection) { _, v in print("focused value \(v ?? "none")") }
    }
}

@main
struct HelloKeysApp: App {
    var body: some Scene { WindowGroup { KeysView() } }
}

struct KeysView: View {
    enum Field: Hashable { case name, counter }
    @State private var ups = 0
    @State private var letters = ""
    @State private var showInspector = false
    @FocusState private var focus: Field?
    var body: some View {
        VStack(spacing: 16) {
            Button("Save") { print("saved") }.keyboardShortcut("s")
            Button("Cancel") { print("cancelled") }.keyboardShortcut(.cancelAction)
            Text("ups \(ups) letters \(letters)").accessibilityIdentifier("counter")
                .padding(6)
                .focusable()
                .focused($focus, equals: .counter)
                .focusedValue(\.selection, "counter")
                .onKeyPress(.upArrow) { ups += 1; print("up \(ups)"); return .handled }
                .onKeyPress(characters: .letters) { press in letters += press.characters; print("letter \(press.characters)"); return .handled }
            Button("Focus counter") { focus = .counter }.accessibilityIdentifier("focus-counter")
            HStack(spacing: 20) {
                VStack { ForEach(["A1", "A2"], id: \.self) { Tile(name: $0) } }.focusSection()
                VStack { ForEach(["B1", "B2"], id: \.self) { Tile(name: $0) } }.focusSection()
            }
            TextField("Name", text: .constant("")).focused($focus, equals: .name).textFieldStyle(.roundedBorder)
                .defaultFocus($focus, .name)
            Button("Inspector") { showInspector = true }.accessibilityIdentifier("open-inspector")
            Badge()
            SelectionReader()
        }
        .padding()
        .focusedSceneValue(\.selection, "item 2")
        .inspector(isPresented: $showInspector) { Text("Inspector").accessibilityIdentifier("inspector") }
        .onChange(of: focus) { _, f in print("focus \(f == .name ? "name" : f == .counter ? "counter" : "none")") }
    }
}

/// A focusable tile that prints when it gets focus.
struct Tile: View {
    let name: String
    @FocusState var focused: Bool
    var body: some View {
        Text(name).frame(width: 60, height: 36).background(Color.gray.opacity(0.2))
            .focusable().focused($focused).accessibilityIdentifier("tile-\(name)")
            .onChange(of: focused) { _, f in if f { print("tile \(name) focused") } }
    }
}
