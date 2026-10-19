// Sample: Quick Look from SwiftUI on isim (issue #237) — quickLookPreview(_:) over one URL and quickLookPreview(_:in:)
// over the app's files (starting at the selected one), HTML rendered by WebKit, RTF as rich text, and
// QLPreviewSceneActivationConfiguration activated from a UIWindowScene.ActivationAction.
import SwiftUI
import QuickLook
import UIKit

let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let html = docs.appendingPathComponent("1-page.html"), rtf = docs.appendingPathComponent("2-letter.rtf"),
    text = docs.appendingPathComponent("3-notes.txt")

func writeFiles() {
    try? """
    <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
    <body style="margin:16px; font-family:sans-serif"><h1 style="color:rgb(255,0,0)">Hello HTML</h1>
    <div style="width:200px; height:100px; background:rgb(0,0,255)"></div><p>Rendered, not <code>&lt;source&gt;</code>.</p></body></html>
    """.write(to: html, atomically: true, encoding: .utf8)
    try? #"""
    {\rtf1\ansi\deff0{\fonttbl{\f0\fswiss Helvetica;}{\f1\fmodern Courier;}}{\colortbl;\red255\green0\blue0;\red0\green0\blue255;}
    \pard\qc\b\fs48 Quick Look\b0\par
    \pard\fs28 Plain, {\b bold}, {\i italic}, {\ul underlined} and {\cf1 red} text.\par
    {\f1 monospaced} \u8364? caf\'e9\par
    {\cf2\fs96 Blue}\par}
    """#.write(to: rtf, atomically: true, encoding: .utf8)
    try? "Plain text.".write(to: text, atomically: true, encoding: .utf8)
}

@main
struct QuickLookApp: App {
    init() { writeFiles() }
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @State var url: URL?
    @State var selection: URL?
    let files = [html, rtf, text]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Preview the page") { url = html }.accessibilityIdentifier("html")
            Button("Preview all, from the letter") { selection = rtf }.accessibilityIdentifier("all")
            SceneButton(files: files).frame(height: 44).accessibilityIdentifier("scene-host")
            Spacer()
        }
        .padding()
        .quickLookPreview($url)
        .quickLookPreview($selection, in: files)
        .onChange(of: url) { _, u in print("url=\(u?.lastPathComponent ?? "nil")") }
        .onChange(of: selection) { _, u in print("selection=\(u?.lastPathComponent ?? "nil")") }
    }
}

/// a UIKit button whose primary action opens Quick Look's preview scene at the second file
struct SceneButton: UIViewRepresentable {
    let files: [URL]
    func makeUIView(context: Context) -> UIButton {
        let files = files
        let action = UIWindowScene.ActivationAction { _ in
            let options = QLPreviewSceneOptions()
            options.initialPreviewIndex = 1
            print("scene configuration for \(files.count) files")
            return QLPreviewSceneActivationConfiguration(itemsAt: files, options: options)
        }
        let b = UIButton(primaryAction: action)
        b.setTitle("Open the preview scene", for: .normal)
        b.contentHorizontalAlignment = .leading
        b.accessibilityIdentifier = "scene"
        return b
    }
    func updateUIView(_ uiView: UIButton, context: Context) {}
}
