// SwiftUI sample for isim: state, forms, navigation, text input, focus, toolbar, tasks.
// Other pages, by launch argument: -gestures (Gestures.swift), -arrangements (iOS 27.1 ArrangementView,
// Arrangements.swift), -accessibility (VoiceOver, Accessibility.swift), -bars, -bars-shapes, -bars-search, -bars-tabs
// (iOS 26 bars and shapes, Bars26.swift).
import SwiftUI

@main
struct HelloSwiftUIApp: App {
    var body: some Scene {
        WindowGroup { page }
    }

    @ViewBuilder var page: some View {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-gestures") { GesturesPage() }
        else if args.contains("-arrangements") { ArrangementsPage() }
        else if args.contains("-accessibility") { AXDemo() }
        else if let a = args.first(where: { $0.hasPrefix("-bars") }) { BarsDemo(page: String(a.dropFirst(6))) }
        else { ContentView() }
    }
}

struct ContentView: View {
    @State private var count = 0
    @State private var name = ""
    @State private var notify = true
    @State private var loaded = "loading…"
    @FocusState private var editing: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "circle.grid.3x3.fill").font(.largeTitle).foregroundStyle(.blue)
                        Text("Hello, SwiftUI on isim").font(.title2.bold())
                        Text("A Form with sections, rows and state.").foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
                Section("Counter") {
                    LabeledContent("Count", value: "\(count)")
                    Button("Increment", systemImage: "plus") { count += 1 }
                        .accessibilityIdentifier("increment")
                    if count > 0 {
                        Button("Reset", role: .destructive) { count = 0 }
                            .accessibilityIdentifier("reset")
                    }
                }
                Section {
                    TextField("Your name", text: $name)
                        .focused($editing)
                        .accessibilityIdentifier("name-field")
                    Toggle("Notifications", isOn: $notify)
                } header: { Text("Profile") } footer: { Text(name.isEmpty ? "Type your name." : "Hello, \(name)!") }
                Section("More") {
                    NavigationLink("Details") { DetailView(count: count) }
                    Label(loaded, systemImage: "checkmark.circle")
                }
            }
            .navigationTitle("Hello")
            .onChange(of: count) { old, new in print("HelloSwiftUI: count \(old) -> \(new)") }
            .onChange(of: editing) { _, now in print("HelloSwiftUI: editing \(now)") }
            .task {
                try? await Task.sleep(for: .milliseconds(200))
                loaded = "Loaded by .task"
                print("HelloSwiftUI: task finished")
            }
            .toolbar {
                if editing {
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { editing = false }.accessibilityIdentifier("done") }
                }
            }
        }
    }
}

struct DetailView: View {
    let count: Int
    var body: some View {
        List {
            Section("Details") {
                Text("The counter is at \(count).")
                Text("This screen was pushed with a NavigationLink.")
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Previews (Xcode's canvas; on isim they compile and type-check)
#Preview { ContentView() }
#Preview("Detail", traits: .sizeThatFitsLayout) {
    let n = 3
    return DetailView(count: n)
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().previewDisplayName("Content").previewInterfaceOrientation(.portrait)
    }
}
