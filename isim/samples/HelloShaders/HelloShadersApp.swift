// Sample: SwiftUI shaders on isim (issue #327). [[stitchable]] Metal functions in Shaders.metal, compiled for the CPU by
// isim build, applied with colorEffect (a tint, stripes from a color array, a pulse animated by a TimelineView),
// distortionEffect (a mirror using .boundingRect, a wave) and layerEffect (pixelation, red and blue swapped), plus a
// disabled effect, and Swift Float16 conversions. tests/ui/test_shaders.py checks the tiles' pixels.
import SwiftUI

@main
struct HelloShadersApp: App {
    var body: some Scene { WindowGroup { ShadersView() } }
}

let red = Color(red: 1, green: 0, blue: 0), green = Color(red: 0, green: 1, blue: 0), blue = Color(red: 0, green: 0, blue: 1)

/// red on the left half, green on the right
struct Halves: View {
    var body: some View { HStack(spacing: 0) { red; green } }
}

struct Tile<Content: View>: View {
    let id: String, title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 4) {
            content.frame(width: 100, height: 60).accessibilityIdentifier(id)
            Text(title).font(.caption)
        }
    }
}

struct ShadersView: View {
    static let start = Date()
    var body: some View {
        VStack(spacing: 16) {
            Text("Shaders").font(.title.bold())
            HStack(spacing: 16) {
                Tile(id: "s-tint", title: "colorEffect") {
                    red.colorEffect(ShaderLibrary.tint(.color(blue), .float(1)))
                }
                Tile(id: "s-stripes", title: "colorArray") {
                    Color.white.colorEffect(ShaderLibrary.default.stripes(.float(25), .colorArray([red, green])))
                }
                Tile(id: "s-off", title: "isEnabled: false") {
                    red.colorEffect(ShaderLibrary.tint(.color(blue), .float(1)), isEnabled: false)
                }
            }
            HStack(spacing: 16) {
                Tile(id: "s-mirror", title: "distortionEffect") {
                    Halves().distortionEffect(ShaderLibrary.mirror(.boundingRect), maxSampleOffset: .zero)
                }
                Tile(id: "s-wave", title: "wave") {
                    Halves().distortionEffect(ShaderLibrary.wave(.float(10)), maxSampleOffset: CGSize(width: 10, height: 0))
                }
                Tile(id: "s-plain", title: "no effect") { Halves() }
            }
            HStack(spacing: 16) {
                Tile(id: "s-pixelate", title: "layerEffect") {
                    LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)
                        .layerEffect(ShaderLibrary.pixelate(.float(20)), maxSampleOffset: .zero)
                }
                Tile(id: "s-swap", title: "swap red, blue") {
                    Halves().layerEffect(ShaderLibrary.swapRB(), maxSampleOffset: .zero)
                }
                Tile(id: "s-pulse", title: "animated") {
                    TimelineView(.animation) { context in
                        red.colorEffect(ShaderLibrary.pulse(.float(context.date.timeIntervalSince(Self.start))))
                    }
                }
            }
            Text("Metal shaders run on the CPU").font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {
            // the half-precision conversions shaders use (and Swift's Float16): compiler-rt's Darwin calling convention
            let h = Float16(Float(0.1)), d = Float16(Double(2.5))
            print("shaders float16 \(Float(h)) \(Double(d)) \(h.bitPattern)")
            print("shaders ready")
        }
    }
}
