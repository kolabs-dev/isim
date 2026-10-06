// Sample: SwiftUI input controls and tabs on isim — TabView (tab bar with badge, page style), Form with
// @AppStorage, Toggle, Slider, Stepper, Picker (menu, segmented, navigationLink, inline), ProgressView, Menu.
import SwiftUI

enum Flavor: String, CaseIterable, Identifiable { case vanilla, chocolate, strawberry; var id: String { rawValue } }
enum Size: Int, CaseIterable { case small, medium, large }

@main
struct HelloFormsApp: App {
    var body: some Scene { WindowGroup { RootTabs() } }
}

struct RootTabs: View {
    @State private var tab = "settings"
    var body: some View {
        TabView(selection: $tab) {
            SettingsForm()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag("settings")
            PagesView()
                .tabItem { Label("Pages", systemImage: "square.grid.2x2") }
                .tag("pages")
            Text("Inbox is empty")
                .tabItem { Label("Inbox", systemImage: "envelope") }
                .badge(3)
                .tag("inbox")
        }
        .onChange(of: tab) { _, t in print("tab \(t)") }
    }
}

struct SettingsForm: View {
    @AppStorage("notifications") private var notifications = true
    @AppStorage("volume") private var volume = 0.5
    @AppStorage("flavor") private var flavor = Flavor.vanilla
    @State private var count = 2
    @State private var size = Size.medium
    @State private var unit = "km"
    @State private var theme = "System"
    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Toggle("Notifications", isOn: $notifications).accessibilityIdentifier("notif")
                    Stepper("Copies: \(count)", value: $count, in: 0...5).accessibilityIdentifier("copies")
                    Picker("Flavor", selection: $flavor) {
                        ForEach(Flavor.allCases) { f in Text(f.rawValue.capitalized).tag(f) }
                    }
                    Picker("Theme", selection: $theme) {
                        ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) }
                    }.pickerStyle(.navigationLink)
                }
                Section("Volume") {
                    Slider(value: $volume, in: 0...1) { Text("Volume") } minimumValueLabel: {
                        Image(systemName: "minus")
                    } maximumValueLabel: { Image(systemName: "plus") }
                    ProgressView(value: volume)
                    Text("Volume \(Int(volume * 100))%")
                }
                Section("Size") {
                    Picker("Size", selection: $size) {
                        Text("Small").tag(Size.small); Text("Medium").tag(Size.medium); Text("Large").tag(Size.large)
                    }.pickerStyle(.segmented)
                }
                Section("Units") {
                    Picker("Units", selection: $unit) {
                        Text("Kilometers").tag("km"); Text("Miles").tag("mi")
                    }.pickerStyle(.inline)
                }
                Section { HStack { Text("Syncing"); Spacer(); ProgressView() } }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Reset", role: .destructive) { count = 0; print("menu: reset") }
                        Picker("Size", selection: $size) {
                            Text("Small").tag(Size.small); Text("Large").tag(Size.large)
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityIdentifier("more")
                }
            }
        }
        .onChange(of: count) { _, v in print("count \(v)") }
        .onChange(of: flavor) { _, v in print("flavor \(v.rawValue)") }
        .onChange(of: notifications) { _, v in print("notifications \(v)") }
        .onChange(of: size) { _, v in print("size \(v)") }
        .onChange(of: unit) { _, v in print("unit \(v)") }
        .onChange(of: theme) { _, v in print("theme \(v)") }
    }
}

struct PagesView: View {
    @State private var page = 0
    var body: some View {
        TabView(selection: $page) {
            ForEach(0..<3) { i in
                ZStack {
                    [Color.orange, Color.teal, Color.purple][i]
                    Text("Page \(i + 1)").font(.largeTitle.bold()).foregroundStyle(.white)
                }
                .tag(i)
            }
        }
        .tabViewStyle(.page)
        .onChange(of: page) { _, p in print("page \(p)") }
    }
}
