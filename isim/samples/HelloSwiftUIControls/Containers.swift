// HelloSwiftUIControls pages for container styles and focus: PAGE=styles (a custom GroupBoxStyle, DisclosureGroupStyle
// and LabeledContentStyle, EquatableView, @FocusedObject from focusedObject / focusedSceneObject, navigationSubtitle on
// iOS 26). The app's commands (CommandMenu "Tools", CommandGroup after .newItem) are in the main menu on every page.
import SwiftUI
import Combine

struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.label.font(.caption.bold()).foregroundStyle(.white)
            configuration.content.foregroundStyle(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("card-box")
    }
}
struct ArrowDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            Button { configuration.isExpanded.toggle() } label: {
                HStack { Text(configuration.isExpanded ? "▼" : "▶"); configuration.label }
            }
            .accessibilityIdentifier("arrow-disclosure")
            if configuration.isExpanded { configuration.content.padding(.leading, 24) }
        }
    }
}
struct StackedLabeledStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            configuration.label.font(.caption).foregroundStyle(.secondary)
            configuration.content
        }
        .accessibilityIdentifier("stacked-labeled")
    }
}
struct Badge: View, Equatable {
    let count: Int
    var body: some View { Text("Badge \(count)").accessibilityIdentifier("badge-view") }
}
final class Draft: ObservableObject {
    let name: String
    @Published var text = ""
    init(_ name: String) { self.name = name }
}
struct FocusedDraftLabel: View {
    @FocusedObject var draft: Draft?
    var body: some View { Text("focused \(draft?.name ?? "none")").accessibilityIdentifier("focused-draft") }
}

struct StylesPage: View {
    @State var expanded = false
    @StateObject var title = Draft("Title")
    @StateObject var notes = Draft("Notes")
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextField("Title", text: $title.text).textFieldStyle(.roundedBorder).focusedObject(title).accessibilityIdentifier("title-field")
                TextField("Notes", text: $notes.text).textFieldStyle(.roundedBorder).focusedObject(notes).accessibilityIdentifier("notes-field")
                FocusedDraftLabel()
                GroupBox("Weather") { Text("Sunny, 24°") }.groupBoxStyle(CardGroupBoxStyle())
                GroupBox("Plain") { Text("Default style") }.accessibilityIdentifier("plain-box")
                DisclosureGroup("More", isExpanded: $expanded) { Text("Hidden details").accessibilityIdentifier("details") }
                    .disclosureGroupStyle(ArrowDisclosureStyle())
                LabeledContent("Version", value: "2.1").labeledContentStyle(StackedLabeledStyle())
                Badge(count: 3).equatable()
            }
            .padding()
            .navigationTitle("Styles")
            .modifier(Subtitle())
        }
        .onChange(of: expanded) { print("expanded \(expanded)") }
    }
}
struct Subtitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) { content.navigationSubtitle("4 containers") } else { content }
    }
}

/// The app's main menu additions.
struct ControlsCommands: Commands {
    var body: some Commands {
        CommandMenu("Tools") {
            Button("Refresh Data") { print("command refresh") }.keyboardShortcut("k", modifiers: [.command, .shift])
            Divider()
            Button("Reset") { print("command reset") }
        }
        CommandGroup(after: .newItem) {
            Button("New Draft") { print("command new draft") }
        }
    }
}
