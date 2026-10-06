// Sample: SwiftUI hardware-keyboard and focus APIs on isim — .keyboardShortcut (Cmd+S, cancelAction),
// .onKeyPress (arrow keys and characters), .inspector, .defaultFocus, @FocusedValue / .focusedSceneValue,
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
    enum Field: Hashable { case name }
    @State private var ups = 0
    @State private var letters = ""
    @State private var showInspector = false
    @FocusState private var focus: Field?
    var body: some View {
        VStack(spacing: 16) {
            Button("Save") { print("saved") }.keyboardShortcut("s")
            Button("Cancel") { print("cancelled") }.keyboardShortcut(.cancelAction)
            Text("ups \(ups) letters \(letters)").accessibilityIdentifier("counter")
                .onKeyPress(.upArrow) { ups += 1; print("up \(ups)"); return .handled }
                .onKeyPress(characters: .letters) { press in letters += press.characters; print("letter \(press.characters)"); return .handled }
            TextField("Name", text: .constant("")).focused($focus, equals: .name).textFieldStyle(.roundedBorder)
                .defaultFocus($focus, .name)
            Button("Inspector") { showInspector = true }.accessibilityIdentifier("open-inspector")
            Badge()
            SelectionReader()
        }
        .padding()
        .focusedSceneValue(\.selection, "item 2")
        .inspector(isPresented: $showInspector) { Text("Inspector").accessibilityIdentifier("inspector") }
        .onChange(of: focus) { _, f in print("focus \(f == .name ? "name" : "none")") }
    }
}
