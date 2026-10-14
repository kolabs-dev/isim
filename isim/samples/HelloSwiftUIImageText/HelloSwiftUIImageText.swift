// Sample: SwiftUI's Image, Font and Text initialisers (issue #209), each checked by a "hsit" log line.
// - Image(decorative:bundle:), Image(_:bundle:label:): a bundle image without or with an accessibility label
// - Image(_:scale:orientation:label:): a 60 x 30 px CGImage at scale 1 turned right (30 x 60 pt)
// - Image(systemName:variableValue:): wifi at 0, 0.5 and 1 (isim lights Adwaita's signal levels)
// - Font(CTFont), Font(UIFont), Font.custom(_:size:relativeTo:) (scales with Dynamic Type), Font.width(_:)
// - Text(LocalizedStringResource), Text(_:tableName:bundle:comment:) from the Menu table
import SwiftUI
import CoreText

func log(_ s: String) { print("hsit \(s)") }

/// A 60 x 30 px image: red left half, blue right half.
func halves() -> CGImage {
    let ctx = CGContext(data: nil, width: 60, height: 30, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: 30, height: 30))
    ctx.setFillColor(red: 0, green: 0, blue: 1, alpha: 1); ctx.fill(CGRect(x: 30, y: 0, width: 30, height: 30))
    return ctx.makeImage()!
}

struct ContentView: View {
    let ctFont = CTFontCreateWithName("Georgia-Bold" as CFString, 21, nil)
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(decorative: "star", bundle: .main).accessibilityIdentifier("decorative")
                    Image("star", bundle: .main, label: Text("Gold star")).accessibilityIdentifier("labelled")
                    Image(halves(), scale: 1, orientation: .right, label: Text("Halves")).accessibilityIdentifier("cg")
                    Image(decorative: halves(), scale: 2).accessibilityIdentifier("cg-decorative")
                }
                HStack(spacing: 16) {
                    Image(systemName: "wifi", variableValue: 0).accessibilityIdentifier("wifi-0")
                    Image(systemName: "wifi", variableValue: 0.5).accessibilityIdentifier("wifi-half")
                    Image(systemName: "wifi", variableValue: 1).accessibilityIdentifier("wifi-1")
                    Image(systemName: "speaker.wave.3.fill", variableValue: 0.4).accessibilityIdentifier("speaker")
                }
                .font(.title)
                Text("Core Text font").font(Font(ctFont)).accessibilityIdentifier("ctfont")
                Text("UIKit font").font(Font(UIFont.italicSystemFont(ofSize: 19))).accessibilityIdentifier("uifont")
                Text("Custom, relative to title").font(.custom("AvenirNext-Regular", size: 20, relativeTo: .title)).accessibilityIdentifier("relative")
                Text("Condensed width").font(.body.width(.condensed)).accessibilityIdentifier("width")
                Text(LocalizedStringResource("resource.title")).accessibilityIdentifier("resource")
                Text("greeting", tableName: "Menu").accessibilityIdentifier("table")
                Text("greeting").accessibilityIdentifier("default-table")
            }
            .padding()
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { report() } }
    }
}

/// Logs what each view became: its frame, font, text and accessibility.
@MainActor func report() {
    guard let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
    func walk(_ v: UIView) {
        if let id = v.accessibilityIdentifier {
            let f = v.convert(v.bounds, to: window)
            var line = "\(id) size=\(Int(f.width))x\(Int(f.height)) element=\(v.isAccessibilityElement) label=\(v.accessibilityLabel ?? "-")"
            if v.accessibilityTraits.contains(.image) { line += " trait=image" }
            if let l = v as? UILabel, let font = l.font { line += " font=\(font.fontName) size=\(font.pointSize) text=\(l.text ?? "")" }
            log(line)
        }
        v.subviews.forEach(walk)
    }
    walk(window)
    log("Font.Width.condensed=\(Font.Width.condensed.value)")
    log("reported")
}

@main
struct HelloSwiftUIImageTextApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
