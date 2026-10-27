// HelloText -rendering: text drawn by a TextRenderer (iOS 18) from its Text.Layout (lines, runs with a custom
// attribute, one slice per character, a line limit), selection bindings of a TextField and a TextEditor (TextSelection),
// and a rich TextEditor under an AttributedTextFormattingDefinition (iOS 26). Each logs "tr ..." lines.
import SwiftUI

func tr(_ s: String) { print("tr \(s)") }

/// Marks the text a renderer highlights.
@available(iOS 18.0, *)
struct Highlight: TextAttribute {}

/// Draws every other character `amount` points lower and a yellow box behind highlighted runs.
@available(iOS 18.0, *)
struct WaveRenderer: TextRenderer {
    var amount: Double
    var animatableData: Double { get { amount } set { amount = newValue } }
    var displayPadding: EdgeInsets { EdgeInsets(top: 0, leading: 0, bottom: amount, trailing: 0) }
    nonisolated(unsafe) static var logged = false
    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            for run in line {
                if run[Highlight.self] != nil { ctx.fill(Path(run.typographicBounds.rect), with: .color(Color(red: 1, green: 0.85, blue: 0))) }
                for (i, slice) in run.enumerated() {
                    var c = ctx
                    if i % 2 == 1 { c.translateBy(x: 0, y: amount) }
                    c.draw(slice)
                }
            }
        }
        if !Self.logged {
            Self.logged = true
            let runs = layout.map { $0.count }, chars = layout.flatMap { $0 }.map { $0.count }.reduce(0, +)
            let start = layout.first?.first?.characterIndices.first            // (the text's first character: offset 0)
            let hl = layout.flatMap { $0 }.filter { $0[Highlight.self] != nil }.map { run in
                run.characterIndices.map { i in start.map { "\($0.distance(to: i))" } ?? "?" }.joined(separator: ",")
            }
            tr("wave lines \(layout.count) runs \(runs) characters \(chars) highlighted [\(hl.joined(separator: ";"))]")
        }
    }
}

/// Draws each line in its own colour and reports the layout's lines.
@available(iOS 18.0, *)
struct LineRenderer: TextRenderer {
    nonisolated(unsafe) static var logged = false
    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let colors: [Color] = [Color(red: 1, green: 0, blue: 0), Color(red: 0, green: 0, blue: 1)]
        for (i, line) in layout.enumerated() {
            var c = ctx
            c.opacity = 1
            c.fill(Path(CGRect(x: line.typographicBounds.rect.minX, y: line.typographicBounds.rect.maxY, width: line.typographicBounds.width, height: 2)),
                   with: .color(colors[i % 2]))
            c.draw(line)
        }
        if !Self.logged {
            Self.logged = true
            let ys = layout.map { String(format: "%.0f", $0.origin.y) }.joined(separator: ",")
            tr("lines \(layout.count) truncated \(layout.isTruncated) baselines \(ys)")
        }
    }
    func sizeThatFits(proposal: ProposedViewSize, text: TextProxy) -> CGSize {
        let s = text.sizeThatFits(proposal)
        return CGSize(width: s.width, height: s.height + 4)            // room for the last line's rule
    }
}

/// Colours are red or blue (others become blue); no underlines.
@available(iOS 26.0, *)
struct Palette: AttributedTextFormattingDefinition {
    struct Scope: AttributeScope {
        let foregroundColor: AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute
        let underlineStyle: AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute
    }
    var body: some AttributedTextFormattingDefinition<Scope> {
        ValueConstraint(for: \.foregroundColor, values: [.red, .blue], default: .blue)
        NoUnderline()
    }
}
@available(iOS 26.0, *)
struct NoUnderline: AttributedTextValueConstraint {
    typealias Scope = Palette.Scope
    typealias AttributeKey = AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute
    func constrain(_ container: inout Attributes) { container.underlineStyle = nil }
}

@available(iOS 18.0, *)
struct RenderingPage: View {
    @State var name = "Hello World"
    @State var selection: TextSelection? = nil
    @State var notes = "notes"
    @State var notesSelection: TextSelection? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            (Text("Wavy ") + Text("text").customAttribute(Highlight()) + Text(" here"))
                .font(.system(size: 34, weight: .bold))
                .textRenderer(WaveRenderer(amount: 8))
                .accessibilityIdentifier("wave")
            Text("one two three four five six seven eight nine ten eleven twelve")
                .font(.system(size: 20))
                .lineLimit(2)
                .frame(width: 200, alignment: .leading)
                .textRenderer(LineRenderer())
                .accessibilityIdentifier("lines")
            TextField("Name", text: $name, selection: $selection)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("field")
            HStack {
                Button("Select World") { if let r = name.range(of: "World") { selection = TextSelection(range: r) } }.accessibilityIdentifier("select-world")
                Button("Start") { notesSelection = TextSelection(insertionPoint: notes.startIndex) }.accessibilityIdentifier("notes-start")
            }
            TextEditor(text: $notes, selection: $notesSelection)
                .frame(height: 60)
                .border(Color.gray)
                .accessibilityIdentifier("notes")
            if #available(iOS 26.0, *) { RichEditor() }
        }
        .padding()
        .onChange(of: selection) {
            guard let s = selection, case .selection(let r) = s.indices else { return }
            tr("field selection \(name.distance(from: name.startIndex, to: r.lowerBound))..<\(name.distance(from: name.startIndex, to: r.upperBound)) '\(name[r])' insertion \(s.isInsertion)")
        }
        .onChange(of: name) { tr("field text '\(name)'") }
        .onChange(of: notes) { tr("notes text '\(notes)'") }
    }
}

/// A rich text editor whose colours and underlines the Palette definition constrains.
@available(iOS 26.0, *)
struct RichEditor: View {
    @State var rich: AttributedString = {
        var a = AttributedString("green red")
        a.foregroundColor = .green
        if let r = a.range(of: "red") { a[r].foregroundColor = .red; a[r].underlineStyle = .single }
        return a
    }()
    @State var richSelection = AttributedTextSelection()
    var body: some View {
        TextEditor(text: $rich, selection: $richSelection)
            .attributedTextFormattingDefinition(Palette())
            .frame(height: 60)
            .border(Color.gray)
            .accessibilityIdentifier("rich")
            .onChange(of: rich, initial: true) {
                let runs = rich.runs.map { run in
                    let c = run.foregroundColor.map { $0 == .red ? "red" : $0 == .blue ? "blue" : "other" } ?? "none"
                    return "\(String(rich[run.range].characters))=\(c)\(run.underlineStyle != nil ? "+underline" : "")"
                }
                tr("rich \(runs.joined(separator: " | "))")
            }
    }
}
