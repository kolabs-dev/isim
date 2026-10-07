// Sample: SwiftUI visual effects on isim — colour filters (grayscale, saturation, brightness, contrast, hueRotation,
// colorMultiply, colorInvert, luminanceToAlpha), blendMode, blur, drop shadows of the content, alpha masks, clipped(),
// compositingGroup, contentShape hit testing, an animated filter, and the iOS 17 geometry effects visualEffect and
// scrollTransition inside a ScrollView.
import SwiftUI

@main
struct HelloEffectsApp: App {
    var body: some Scene { WindowGroup { EffectsView() } }
}

let pureRed = Color(red: 1, green: 0, blue: 0)
let pureBlue = Color(red: 0, green: 0, blue: 1)

struct Tile<Content: View>: View {
    let id: String
    @ViewBuilder let content: Content
    var body: some View { content.frame(width: 60, height: 60).accessibilityIdentifier(id) }
}

struct EffectsView: View {
    @State private var shapeTaps = 0
    @State private var faded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Effects").font(.headline)
            HStack(spacing: 10) {
                Tile(id: "t-gray") { pureRed.grayscale(1) }
                Tile(id: "t-sat") { pureRed.saturation(0) }
                Tile(id: "t-bright") { Color.black.brightness(0.5) }
                Tile(id: "t-contrast") { pureRed.contrast(0) }
                Tile(id: "t-hue") { pureRed.hueRotation(.degrees(120)) }
            }
            HStack(spacing: 10) {
                Tile(id: "t-mult") { Color.white.colorMultiply(pureBlue) }
                Tile(id: "t-invert") { Color.white.colorInvert() }
                Tile(id: "t-luma") { ZStack { Color(red: 1, green: 1, blue: 0); Color.black.luminanceToAlpha() } }
                Tile(id: "t-blend") { ZStack { Color(red: 1, green: 1, blue: 0); Color(red: 0, green: 1, blue: 1).blendMode(.multiply) } }
                Tile(id: "t-blur") { pureRed.frame(width: 30, height: 30).blur(radius: 6) }
            }
            HStack(spacing: 10) {
                Tile(id: "t-shadow") { Circle().fill(pureBlue).frame(width: 40, height: 40).shadow(color: .black, radius: 0, x: 8, y: 8) }
                Tile(id: "t-mask") { pureRed.mask(LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)) }
                Tile(id: "t-clip") { Color(red: 0, green: 0.8, blue: 0).frame(width: 100, height: 100).frame(width: 40, height: 40).clipped() }
                Tile(id: "t-group") {
                    ZStack { pureRed.frame(width: 40, height: 40).offset(x: -10); pureBlue.frame(width: 40, height: 40).offset(x: 10) }
                        .compositingGroup().opacity(0.5)
                }
                Tile(id: "t-fade") { pureRed.grayscale(faded ? 1 : 0) }
            }
            HStack(spacing: 16) {
                Color.orange.frame(width: 80, height: 80).contentShape(Circle())
                    .onTapGesture { shapeTaps += 1; print("shape tapped \(shapeTaps)") }
                    .accessibilityIdentifier("t-shape")
                    .overlay(alignment: .topLeading) { Color.clear.frame(width: 8, height: 8).accessibilityIdentifier("t-shape-corner") }
                VStack(alignment: .leading) {
                    Text("Shape taps: \(shapeTaps)")
                    Button("Fade") { withAnimation(.linear(duration: 2)) { faded.toggle() } }.accessibilityIdentifier("fade")
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { i in
                        Text("Row \(i)").foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(pureBlue)
                            .scrollTransition { content, phase in content.opacity(phase.isIdentity ? 1 : 0) }
                            .visualEffect { content, proxy in
                                if i == 2 { print("ve row2 \(Int(proxy.frame(in: .scrollView).minY))") }
                                return content.brightness(0)
                            }
                            .accessibilityIdentifier("row-\(i)")
                    }
                }
            }
            .frame(width: 300, height: 160)
            .border(Color.gray)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
