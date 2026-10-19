// HelloSwiftUIControls pages for small SwiftUI view options: PAGE=badges (badgeProminence on List row badges,
// navigationLinkIndicatorVisibility, toolbarBackgroundVisibility) and PAGE=options (buttonRepeatBehavior,
// backgroundStyle, menuIndicator, menuStyle (.button and a custom style), labelsVisibility, textEditorStyle,
// toolbarVisibility, Apple Pencil double-tap and squeeze, and the options iOS keeps without showing them:
// geometryGroup, dialogSeverity, dialogIcon, typesettingLanguage).
import SwiftUI

@available(iOS 18.0, *)
struct OptionsListPage: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Inbox").accessibilityIdentifier("inbox").badge(5).badgeProminence(.increased)
                Text("Drafts").accessibilityIdentifier("drafts").badge(2)
                Text("Archive").badge(12).badgeProminence(.decreased)
                NavigationLink { Text("Settings page") } label: { Text("Settings").accessibilityIdentifier("settings") }
                NavigationLink { Text("About page") } label: { Text("About").accessibilityIdentifier("about") }
                    .navigationLinkIndicatorVisibility(.hidden)
            }
            .navigationTitle("Mail")
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        }
    }
}

struct RedMenuStyle: MenuStyle {
    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration).foregroundStyle(.red).accessibilityIdentifier("custom-menu")
    }
}

@available(iOS 18.0, *)
struct OptionsControlsPage: View {
    @State var count = 0
    @State var wifi = true
    @State var notes = "Notes"
    @State var asking = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Button("Step") { count += 1; print("count \(count)") }
                    .buttonRepeatBehavior(.enabled)
                    .accessibilityIdentifier("step")
                Text("Count \(count)").geometryGroup()
                Rectangle().fill(.background).frame(width: 120, height: 30)
                    .accessibilityIdentifier("swatch")
                    .backgroundStyle(.orange)
                HStack(spacing: 24) {
                    Menu("Plain") { Button("One") { print("picked One") } }.accessibilityIdentifier("plain-menu")
                    Menu("Sort") { Button("Name") { print("sort Name") } }.menuIndicator(.visible).accessibilityIdentifier("sort-menu")
                }
                Menu("Filter") { Button("All") { print("filter All") } }
                    .menuStyle(.button).buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("button-menu")
                Menu("Custom") { Button("Two") { print("picked Two") } }.menuStyle(RedMenuStyle())
                Toggle("Wi-Fi", isOn: $wifi).labelsVisibility(.hidden).frame(width: 60)
                TextEditor(text: $notes).textEditorStyle(.plain).frame(height: 60).border(Color.gray)
                Text("ภาษาไทย").typesettingLanguage(.explicit(Locale.Language(identifier: "th")))
                Button("Delete…") { asking = true }
                    .confirmationDialog("Delete everything?", isPresented: $asking) { Button("Delete", role: .destructive) {} }
                    .dialogSeverity(.critical)
                    .dialogIcon(Image(systemName: "trash"))
                Text("Pencil").padding().border(Color.blue)
                    .onPencilDoubleTap { value in print("pencil double tap \(value.hoverPose == nil ? "no pose" : "pose")") }
                    .onPencilSqueeze { phase in
                        switch phase {
                        case .active: print("pencil squeeze active")
                        case .ended: print("pencil squeeze ended")
                        case .failed: print("pencil squeeze failed")
                        @unknown default: break
                        }
                    }
            }
            .navigationTitle("Options")
            .toolbarVisibility(.visible, for: .navigationBar)
        }
    }
}
