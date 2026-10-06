// Sample: SwiftUI text on isim — Text + Text, Markdown (bold, italic, code, strikethrough, links), live date and
// timer text, formatter text, decorations (underline, strikethrough, kerning, baseline offset), textCase,
// truncationMode, minimumScaleFactor and SF Symbol modifiers (imageScale, symbolVariant).
import SwiftUI

@main
struct HelloTextApp: App {
    var body: some Scene { WindowGroup { TextGallery() } }
}

struct TextGallery: View {
    // fixed dates so the output is predictable: 2026-01-02 15:04 UTC
    static let fixed = Date(timeIntervalSince1970: 1_767_366_240)
    @State private var start = Date()
    @State private var opened = ""
    static let attributed: AttributedString = {
        var a = (try? AttributedString(markdown: "Plain, **strong** and [a site](https://isim.dev)")) ?? AttributedString("markdown failed")
        var red = AttributedString(" red")
        red.foregroundColor = .red
        a.append(red)
        return a
    }()
    static let currency: NumberFormatter = { let f = NumberFormatter(); f.numberStyle = .decimal; f.minimumFractionDigits = 2; f.maximumFractionDigits = 2; return f }()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                (Text("Hello, ") + Text("World").bold() + Text("!").foregroundColor(.red))
                    .accessibilityIdentifier("concat")
                Text("**Bold**, *italic*, `code`, ~~gone~~ and [a link](https://example.com/docs)")
                    .accessibilityIdentifier("markdown")
                Text(verbatim: "**not markdown**").accessibilityIdentifier("verbatim")
                Text(Self.fixed, style: .date).accessibilityIdentifier("date")
                Text(start.addingTimeInterval(-125), style: .relative).accessibilityIdentifier("relative")
                Text(timerInterval: start...start.addingTimeInterval(300)).accessibilityIdentifier("timer")
                Text(1234.5 as NSNumber, formatter: Self.currency).accessibilityIdentifier("formatter")
                Text("Due \(Self.fixed, style: .date)").accessibilityIdentifier("interp")
                Text("shouting").textCase(.uppercase).accessibilityIdentifier("upper")
                Text("Underlined").underline().accessibilityIdentifier("underline")
                Text("Struck").strikethrough(color: .red).accessibilityIdentifier("strike")
                Text("SPACED").kerning(6).accessibilityIdentifier("kerned")
                HStack(alignment: .top, spacing: 0) {
                    Text("x")
                    Text("2").font(.caption).baselineOffset(8)
                }.accessibilityIdentifier("superscript")
                Text("The quick brown fox jumps over the lazy dog")
                    .lineLimit(1).truncationMode(.middle).frame(width: 160, alignment: .leading)
                    .accessibilityIdentifier("middle")
                Text("Scaled down to fit the width").font(.title).lineLimit(1).minimumScaleFactor(0.4)
                    .frame(width: 150).accessibilityIdentifier("scaled")
                HStack(spacing: 12) {
                    Image(systemName: "star").imageScale(.small).accessibilityIdentifier("star-small")
                    Image(systemName: "star").accessibilityIdentifier("star-medium")
                    Image(systemName: "star").imageScale(.large).accessibilityIdentifier("star-large")
                    Image(systemName: "heart").symbolVariant(.fill).foregroundStyle(.pink)
                    Text("Wrapped markdown: this **long sentence** keeps *going* so that the words wrap onto a second line")
                        .accessibilityIdentifier("wrapped")
                }
                Text(1234.5, format: .number).accessibilityIdentifier("format-number")
                Text(0.25, format: .percent).accessibilityIdentifier("format-percent")
                Text("Total \(19.99, format: .currency(code: "USD"))").accessibilityIdentifier("format-interp")
                Text(Self.attributed).accessibilityIdentifier("attributed")
                Text(opened).accessibilityIdentifier("opened")
            }
            .padding()
        }
        .environment(\.openURL, OpenURLAction { url in
            print("open \(url.absoluteString)")
            opened = "opened \(url.host ?? "")"
            return .handled
        })
    }
}
