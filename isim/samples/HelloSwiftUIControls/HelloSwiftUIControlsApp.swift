// Sample: SwiftUI views and controls on isim — SF Symbol rendering modes (monochrome, hierarchical, palette,
// multicolor), symbolVariant, imageScale and every symbol effect; truncationMode, minimumScaleFactor and
// allowsTightening; MultiDatePicker; PasteButton (UIKit's paste control); ShareLink with Transferable items and a
// SharePreview (UIKit's share sheet); RenameButton / renameAction.
// iOS 26: Slider tick marks, neutral value and enabled bounds; TextEditor editing an AttributedString with a selection.
// Opens controlsplus:// URLs (onOpenURL prints them; HelloScenes links here).
// PAGE=env: \.isSearching in a searchable list, \.presentationMode / \.isPresented in a sheet.
// PAGE=ax: accessibilitySortPriority and named accessibility actions (drive it with isim's VoiceOver).
// PAGE=hover: onHover, onContinuousHover, hoverEffect (drive the pointer with the script's `hover X Y`).
// The page comes from the environment: PAGE=symbols|effects|text|dates|paste|share|rename|ticks|rich|env|ax|hover.
import SwiftUI
import UniformTypeIdentifiers

@main
struct HelloSwiftUIControlsApp: App {
    var body: some Scene { WindowGroup { Root().onOpenURL { url in print("opened \(url.absoluteString)") } } }
}

let env = ProcessInfo.processInfo.environment

struct Root: View {
    var body: some View {
        switch env["PAGE"] ?? "symbols" {
        case "effects": EffectsPage()
        case "text": TextPage()
        case "dates": DatesPage()
        case "paste": PastePage()
        case "share": SharePage()
        case "rename": RenamePage()
        case "env": EnvPage()
        case "ax": AxPage()
        case "hover": HoverPage()
        case "ticks": if #available(iOS 26.0, *) { TicksPage() } else { Text("iOS 26") }
        case "rich": if #available(iOS 26.0, *) { RichPage() } else { Text("iOS 26") }
        default: SymbolsPage()
        }
    }
}

struct SymbolsPage: View {
    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 24) {
                Image(systemName: "heart.circle").symbolRenderingMode(.monochrome).foregroundStyle(.blue).accessibilityIdentifier("mono")
                Image(systemName: "heart.circle").symbolRenderingMode(.hierarchical).foregroundStyle(.blue).accessibilityIdentifier("hier")
                Image(systemName: "heart.circle").symbolRenderingMode(.palette).foregroundStyle(.red, .green).accessibilityIdentifier("palette")
                Image(systemName: "heart.fill").symbolRenderingMode(.multicolor).accessibilityIdentifier("multi")
            }
            .font(.system(size: 60))
            HStack(spacing: 24) {
                Image(systemName: "star").accessibilityIdentifier("star-plain")
                Image(systemName: "star").symbolVariant(.fill).accessibilityIdentifier("star-fill")
                Image(systemName: "star").symbolVariant(.circle).accessibilityIdentifier("star-circle")
                Image(systemName: "star").symbolVariant(.circle.fill).accessibilityIdentifier("star-circle-fill")
            }
            .font(.system(size: 50))
            .foregroundStyle(.orange)
            HStack(spacing: 24) {
                Image(systemName: "bell").imageScale(.small).accessibilityIdentifier("bell-small")
                Image(systemName: "bell").imageScale(.medium).accessibilityIdentifier("bell-medium")
                Image(systemName: "bell").imageScale(.large).accessibilityIdentifier("bell-large")
            }
            .font(.title)
        }
    }
}

/// The iOS 18 symbol effects (breathe, rotate, wiggle on bumps) where the OS has them.
struct Effect18: ViewModifier {
    let kind: Int, bumps: Int
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            switch kind {
            case 0: content.symbolEffect(.breathe)
            case 1: content.symbolEffect(.rotate)
            default: content.symbolEffect(.wiggle, value: bumps)
            }
        } else { content }
    }
}

struct EffectsPage: View {
    @State private var active = false
    @State private var bumps = 0
    @State private var replaced = false
    var body: some View {
        VStack(spacing: 30) {
            HStack(spacing: 40) {
                Image(systemName: "wifi").symbolEffect(.variableColor.iterative).accessibilityIdentifier("fx-variable")
                Image(systemName: "heart.fill").modifier(Effect18(kind: 0, bumps: 0)).accessibilityIdentifier("fx-breathe")
                Image(systemName: "gear").modifier(Effect18(kind: 1, bumps: 0)).accessibilityIdentifier("fx-rotate")
            }
            HStack(spacing: 40) {
                Image(systemName: "star.fill").symbolEffect(.scale.up, isActive: active).accessibilityIdentifier("fx-scale")
                Image(systemName: "bolt.fill").symbolEffect(.disappear, isActive: active).accessibilityIdentifier("fx-disappear")
                Image(systemName: "bell.fill").modifier(Effect18(kind: 2, bumps: bumps)).accessibilityIdentifier("fx-wiggle")
                Image(systemName: "flame.fill").symbolEffect(.bounce, options: .repeat(3), value: bumps).accessibilityIdentifier("fx-bounce")
            }
            Image(systemName: replaced ? "checkmark.circle.fill" : "xmark.circle.fill")
                .contentTransition(.symbolEffect(.replace))
                .accessibilityIdentifier("fx-replace")
            HStack {
                Button("Activate") { active.toggle() }.accessibilityIdentifier("activate")
                Button("Bump") { bumps += 1 }.accessibilityIdentifier("bump")
                Button("Replace") { withAnimation { replaced.toggle() } }.accessibilityIdentifier("replace")
            }
        }
        .font(.system(size: 50))
        .foregroundStyle(.blue)
        .onChange(of: replaced) { _, r in print("replaced \(r)") }
    }
}

struct TextPage: View {
    let long = "The quick brown fox jumps over the lazy dog"
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(long).lineLimit(1).truncationMode(.head).frame(width: 200, alignment: .leading).accessibilityIdentifier("head")
            Text(long).lineLimit(1).truncationMode(.middle).frame(width: 200, alignment: .leading).accessibilityIdentifier("middle")
            Text(long).lineLimit(1).truncationMode(.tail).frame(width: 200, alignment: .leading).accessibilityIdentifier("tail")
            Text(long).lineLimit(1).minimumScaleFactor(0.5).frame(width: 250, alignment: .leading).background(Color.yellow.opacity(0.3)).accessibilityIdentifier("scaled")
            Text("Tightened text here!").lineLimit(1).allowsTightening(true).frame(width: 152, alignment: .leading).background(Color.green.opacity(0.3)).accessibilityIdentifier("tight")
            Text("Tightened text here!").lineLimit(1).frame(width: 152, alignment: .leading).background(Color.red.opacity(0.2)).accessibilityIdentifier("loose")
        }
        .font(.body)
        .padding()
    }
}

struct DatesPage: View {
    @State private var days: Set<DateComponents> = []
    var body: some View {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let end = cal.date(from: DateComponents(year: 2026, month: 5, day: 25))!
        VStack(spacing: 12) {
            MultiDatePicker("Trips", selection: $days, in: start..<end).accessibilityIdentifier("multi")
            Text("days \(days.compactMap(\.day).sorted().map(String.init).joined(separator: ","))").accessibilityIdentifier("days")
        }
        .padding()
        .onChange(of: days) { _, d in print("days \(d.compactMap(\.day).sorted().map(String.init).joined(separator: ","))") }
    }
}

struct PastePage: View {
    @State private var pasted = "nothing"
    var body: some View {
        VStack(spacing: 20) {
            Button("Copy hello") { UIPasteboard.general.string = "hello from the pasteboard" }.accessibilityIdentifier("copy")
            PasteButton(payloadType: String.self) { strings in
                pasted = strings.joined(separator: "|")
                print("pasted \(pasted)")
            }
            .accessibilityIdentifier("paste")
            Text("pasted \(pasted)").accessibilityIdentifier("pasted")
        }
    }
}

/// A Transferable note shared as plain text.
struct Note: Transferable {
    var text: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { note in Data(note.text.utf8) }
    }
}

struct SharePage: View {
    var body: some View {
        VStack(spacing: 20) {
            ShareLink(item: Note(text: "A note to share"), preview: SharePreview("My note")) { Text("Share note") }
                .accessibilityIdentifier("share-note")
            ShareLink(items: ["first", "second"]) { Text("Share two") }
                .accessibilityIdentifier("share-two")
            ShareLink("Share link", item: URL(string: "https://example.com/page")!, subject: Text("A page"), message: Text("Look at this"))
                .accessibilityIdentifier("share-url")
        }
    }
}

struct RenamePage: View {
    @State private var name = "Untitled"
    @FocusState private var editing: Bool
    var body: some View {
        VStack(spacing: 20) {
            TextField("Name", text: $name).focused($editing).textFieldStyle(.roundedBorder).padding(.horizontal).accessibilityIdentifier("name")
            Text(editing ? "editing" : "not editing").accessibilityIdentifier("state")
            RenameButton().accessibilityIdentifier("rename")
            RenameButton().renameAction { print("custom rename") }.accessibilityIdentifier("rename-custom")
        }
        .renameAction($editing)
    }
}

@available(iOS 26.0, *)
struct TicksPage: View {
    @State var stepped = 2.0
    @State var custom = 0.0
    @State var neutral = 0.0
    @State var bounded = 50.0
    var body: some View {
        VStack(spacing: 24) {
            Slider(value: $stepped, in: 0...4, step: 1).accessibilityIdentifier("stepped")
            Slider(value: $custom, in: 0...10) { Text("Speed") } ticks: {
                SliderTick(0)
                SliderTick(5) { Text("Mid") }
                SliderTick(10)
            }
            .accessibilityIdentifier("custom")
            Slider(value: $neutral, in: -1...1, neutralValue: 0).accessibilityIdentifier("neutral")
            Slider(value: $bounded, in: 0...100, enabledBounds: 20...80) { Text("Bounded") } ticks: {
                SliderTickContentForEach([20.0, 50.0, 80.0], id: \.self) { SliderTick($0) }
            }
            .accessibilityIdentifier("bounded")
            Text(String(format: "stepped %.0f custom %.1f neutral %.2f bounded %.0f", stepped, custom, neutral, bounded)).accessibilityIdentifier("values")
        }
        .padding(24)
        .onChange(of: stepped) { print(String(format: "stepped %.2f", stepped)) }
        .onChange(of: bounded) { print(String(format: "bounded %.0f", bounded)) }
        .onChange(of: neutral) { print(String(format: "neutral %.2f", neutral)) }
    }
}

@available(iOS 26.0, *)
struct RichPage: View {
    @State var text: AttributedString = {
        var a = AttributedString("Hello ")
        var w = AttributedString("world")
        w.foregroundColor = .red
        w.font = .body.bold()
        a.append(w)
        return a
    }()
    @State var selection = AttributedTextSelection()
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $text, selection: $selection).frame(height: 120).border(.gray).accessibilityIdentifier("editor")
            Button("Select Hello") {
                if let r = text.range(of: "Hello") { selection = AttributedTextSelection(range: r) }
            }
            .accessibilityIdentifier("select")
            Button("Underline selection") {
                if case .ranges(let rs) = selection.indices(in: text) { for r in rs.ranges { text[r].underlineStyle = .single } }
            }
            .accessibilityIdentifier("underline")
            Text(text).accessibilityIdentifier("preview")
        }
        .padding(24)
        .onChange(of: text) {
            let runs = text.runs.map { r in "\(String(text[r.range].characters))\(r.foregroundColor == .red ? "[red]" : "")\(r.underlineStyle != nil ? "[u]" : "")" }
            print("text " + runs.joined(separator: "|"))
        }
        .onChange(of: selection) {
            switch selection.indices(in: text) {
            case .insertionPoint(let i): print("caret \(text.characters.distance(from: text.startIndex, to: i))")
            case .ranges(let rs): print("selected " + rs.ranges.map { String(text[$0].characters) }.joined(separator: ","))
            }
        }
    }
}

struct EnvPage: View {
    @State var query = ""
    @State var sheet = false
    var body: some View {
        NavigationStack {
            List {
                SearchState()
                Button("Show sheet") { sheet = true }.accessibilityIdentifier("show-sheet")
                ForEach(["Apple", "Banana", "Cherry"].filter { query.isEmpty || $0.contains(query) }, id: \.self) { Text($0) }
            }
            .searchable(text: $query)
            .navigationTitle("Environment")
        }
        .sheet(isPresented: $sheet) { SheetContent() }
    }
}
/// Reads \.isSearching (it is inside the searchable list).
struct SearchState: View {
    @Environment(\.isSearching) var searching
    var body: some View {
        Text(searching ? "searching" : "not searching").accessibilityIdentifier("search-state")
            .onChange(of: searching) { _, s in print("isSearching \(s)") }
    }
}
struct SheetContent: View {
    @Environment(\.presentationMode) var mode
    @Environment(\.isPresented) var presented
    var body: some View {
        VStack(spacing: 20) {
            Text("presented \(presented ? "yes" : "no") mode \(mode.wrappedValue.isPresented ? "yes" : "no")").accessibilityIdentifier("sheet-state")
            Button("Done") { mode.wrappedValue.dismiss() }.accessibilityIdentifier("sheet-done")
        }
        .onDisappear { print("sheet gone") }
    }
}

struct AxPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Second").accessibilitySortPriority(1)
            Text("First").accessibilitySortPriority(2)
            Text("Mail")
                .accessibilityAction(named: "Archive") { print("archived") }
                .accessibilityAction(named: Text("Flag")) { print("flagged") }
        }
    }
}

struct HoverPage: View {
    @State var inside = false
    @State var location = "none"
    var body: some View {
        VStack(spacing: 30) {
            Text(inside ? "hovering" : "not hovering").frame(width: 200, height: 80)
                .background(inside ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                .onHover { inside = $0; print("hover \($0)") }
                .accessibilityIdentifier("hover-box")
            Text("at \(location)").frame(width: 200, height: 80).background(Color.orange.opacity(0.2))
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p): location = "\(Int(p.x)),\(Int(p.y))"
                    case .ended: location = "none"; print("continuous ended")
                    }
                }
                .accessibilityIdentifier("track-box")
            HStack(spacing: 40) {
                Button("Highlight") {}.hoverEffect(.highlight).accessibilityIdentifier("highlight-button")
                Button("Lift") {}.hoverEffect(.lift).accessibilityIdentifier("lift-button")
            }
        }
    }
}
