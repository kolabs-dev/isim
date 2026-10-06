// Sample: SwiftUI pickers and controls on isim — DatePicker (compact, graphical, wheel), wheel Picker, ColorPicker,
// TextField(value:formatter:), TextEditor, Gauge, ProgressView styles, GroupBox, DisclosureGroup, OutlineGroup,
// ControlGroup, ContentUnavailableView, ShareLink, PasteButton, AsyncImage, controlSize, buttonBorderShape and a
// PrimitiveButtonStyle.
import SwiftUI

@main
struct HelloPickersApp: App {
    var body: some Scene { WindowGroup { Root() } }
}

func stamp(_ d: Date, _ parts: Set<Calendar.Component>) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: d)
    func two(_ v: Int?) -> String { let x = v ?? 0; return x < 10 ? "0\(x)" : "\(x)" }
    var s: [String] = []
    if parts.contains(.day) { s.append("\(c.year ?? 0)-\(two(c.month))-\(two(c.day))") }
    if parts.contains(.hour) { s.append("\(two(c.hour)):\(two(c.minute))") }
    return s.joined(separator: " ")
}
let base = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9, minute: 30))!

struct Root: View {
    var body: some View {
        TabView {
            DatesTab().tabItem { Label("Dates", systemImage: "calendar") }
            InputsTab().tabItem { Label("Inputs", systemImage: "slider.horizontal.3") }
            ViewsTab().tabItem { Label("Views", systemImage: "square.grid.2x2") }
        }
    }
}

struct DatesTab: View {
    @State private var start = base
    @State private var day = base
    @State private var alarm = base
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DatePicker("Start", selection: $start)
                Text("start \(stamp(start, [.day, .hour]))").accessibilityIdentifier("start-value")
                DatePicker("Day", selection: $day, displayedComponents: .date).datePickerStyle(.graphical)
                Text("day \(stamp(day, [.day]))").accessibilityIdentifier("day-value")
                DatePicker("Alarm", selection: $alarm, displayedComponents: .hourAndMinute).datePickerStyle(.wheel).labelsHidden()
                    .accessibilityIdentifier("alarm")
                Text("alarm \(stamp(alarm, [.hour]))").accessibilityIdentifier("alarm-value")
            }
            .padding()
        }
        .onChange(of: start) { _, v in print("start \(stamp(v, [.day, .hour]))") }
        .onChange(of: day) { _, v in print("day \(stamp(v, [.day]))") }
        .onChange(of: alarm) { _, v in print("alarm \(stamp(v, [.hour]))") }
    }
}

struct InputsTab: View {
    @State private var fruit = "Banana"
    @State private var color = Color.blue
    @State private var qty = 3
    @State private var notes = "First line"
    static let number: NumberFormatter = { let f = NumberFormatter(); f.numberStyle = .decimal; return f }()
    var body: some View {
        Form {
            Section("Wheel") {
                Picker("Fruit", selection: $fruit) {
                    ForEach(["Apple", "Banana", "Cherry", "Date", "Elderberry"], id: \.self) { Text($0) }
                }
                .pickerStyle(.wheel)
                Text("fruit \(fruit)").accessibilityIdentifier("fruit-value")
            }
            Section("Values") {
                ColorPicker("Tint", selection: $color)
                TextField("Quantity", value: $qty, formatter: Self.number).accessibilityIdentifier("qty")
                Text("qty \(qty)").accessibilityIdentifier("qty-value")
            }
            Section("Notes") {
                TextEditor(text: $notes).frame(height: 90).accessibilityIdentifier("notes")
                Text("notes \(notes.count) chars").accessibilityIdentifier("notes-value")
            }
        }
        .onChange(of: fruit) { _, v in print("fruit \(v)") }
        .onChange(of: color) { _, _ in print("color changed") }
        .onChange(of: qty) { _, v in print("qty \(v)") }
    }
}

struct FileItem: Identifiable {
    let name: String
    var children: [FileItem]?
    var id: String { name }
}
let tree = [FileItem(name: "Documents", children: [FileItem(name: "Resume.pdf"), FileItem(name: "Taxes", children: [FileItem(name: "2025.pdf")])]),
            FileItem(name: "Notes.txt")]

/// A primitive style: the button fires on a long press only.
struct LongPressButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(8).background(Color.orange.opacity(0.3), in: Capsule())
            .onLongPressGesture(minimumDuration: 0.4) { configuration.trigger() }
    }
}

struct ViewsTab: View {
    @State private var expanded = false
    @State private var taps = 0
    @State private var progress = 0.25
    static let pixel = URL(string: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGElEQVR4nGP476BAEmIY1TAaSgrDNmkAAHmWXxAbW7gfAAAAAElFTkSuQmCC")
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Gauge(value: 0.4) { Text("Battery") } currentValueLabel: { Text("40%") }.accessibilityIdentifier("gauge-linear")
                HStack(spacing: 20) {
                    Gauge(value: 72, in: 0...100) { Text("BPM") } currentValueLabel: { Text("72") }
                        .gaugeStyle(.accessoryCircular)
                    Gauge(value: 0.5) { Text("Half") } currentValueLabel: { Text("50") }
                        .gaugeStyle(.accessoryCircularCapacity)
                    ProgressView().progressViewStyle(.circular)
                }
                ProgressView("Downloading", value: progress).accessibilityIdentifier("progress")
                GroupBox("Account") { Text("Signed in as Kim").accessibilityIdentifier("groupbox-body") }
                DisclosureGroup("Advanced", isExpanded: $expanded) {
                    Text("Hidden option").accessibilityIdentifier("advanced-body")
                }
                .accessibilityIdentifier("advanced")
                OutlineGroup(tree, children: \.children) { item in Text(item.name) }
                ControlGroup {
                    Button("Cut") { print("control cut") }
                    Button("Copy") { print("control copy") }
                }
                HStack {
                    Button("Mini") {}.buttonStyle(.bordered).controlSize(.mini).accessibilityIdentifier("btn-mini")
                    Button("Large") {}.buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule).accessibilityIdentifier("btn-large")
                    Button("Hold") { taps += 1; print("long press \(taps)") }.buttonStyle(LongPressButtonStyle()).accessibilityIdentifier("hold")
                }
                HStack {
                    ShareLink(item: URL(string: "https://example.com/item")!)
                    PasteButton(payloadType: String.self) { _ in }
                    AsyncImage(url: Self.pixel) { img in img.resizable().frame(width: 32, height: 32) } placeholder: { ProgressView() }
                        .accessibilityIdentifier("async")
                }
                ContentUnavailableView("No Mail", systemImage: "tray", description: Text("New messages appear here."))
                    .frame(height: 200)
            }
            .padding()
        }
    }
}
