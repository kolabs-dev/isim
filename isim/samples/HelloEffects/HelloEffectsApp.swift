// Sample: SwiftUI visual effects on isim — colour filters (grayscale, saturation, brightness, contrast, hueRotation,
// colorMultiply, colorInvert, luminanceToAlpha), blendMode, blur, drop shadows of the content, alpha masks, clipped(),
// compositingGroup, contentShape hit testing, an animated filter, and the iOS 17 geometry effects visualEffect and
// scrollTransition inside a ScrollView, onScrollGeometryChange / onScrollVisibilityChange (iOS 18), contentTransition
// (.numericText) and symbol effects.
import SwiftUI

@main
struct HelloEffectsApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

struct RootView: View {
    @State private var page = 0
    var body: some View {
        if page == 0 { EffectsView(next: { page = 1 }) } else { MoreView() }
    }
}

let pureRed = Color(red: 1, green: 0, blue: 0)
let pureBlue = Color(red: 0, green: 0, blue: 1)

struct Tile<Content: View>: View {
    let id: String
    @ViewBuilder let content: Content
    var body: some View { content.frame(width: 60, height: 60).accessibilityIdentifier(id) }
}

struct EffectsView: View {
    let next: () -> Void
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
                    Button("More") { next() }.accessibilityIdentifier("next")
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
                            .modifier(RowVisibility(index: i))
                            .accessibilityIdentifier("row-\(i)")
                    }
                }
            }
            .frame(width: 300, height: 160)
            .border(Color.gray)
            .modifier(ScrollWatch())
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// iOS 18 scroll geometry: the first visible row while scrolling, and row 0's visibility.
struct ScrollWatch: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Int.self, of: { Int($0.contentOffset.y / 40) }) { _, row in print("scroll row \(row)") }
        } else { content }
    }
}
struct RowVisibility: ViewModifier {
    let index: Int
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), index == 0 { content.onScrollVisibilityChange { v in print("row0 visible \(v)") } } else { content }
    }
}

/// Haptics (logged), privacy redaction, an auto-hidden home indicator, deferred edge gestures and a context menu preview.
struct MoreView: View {
    @State private var count = 0
    @State private var redact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("More effects").font(.headline)
            Button("Haptic \(count)") { withAnimation(.easeInOut(duration: 0.4)) { count += 1 } }
                .sensoryFeedback(.success, trigger: count)
                .sensoryFeedback(.impact(weight: .heavy), trigger: count) { _, new in new > 1 }
                .accessibilityIdentifier("haptic")
            HStack(spacing: 24) {
                Text("\(count)").font(.largeTitle).contentTransition(.numericText()).accessibilityIdentifier("count-text")
                Image(systemName: "star.fill").font(.largeTitle).foregroundStyle(.orange).symbolEffect(.bounce, value: count).accessibilityIdentifier("bounce-star")
                Image(systemName: "heart.fill").font(.largeTitle).foregroundStyle(.red).symbolEffect(.pulse).accessibilityIdentifier("pulse-heart")
            }
            Toggle("Redact private", isOn: $redact).accessibilityIdentifier("redact")
            HStack(spacing: 12) {
                Image(systemName: "star.fill").font(.largeTitle).foregroundStyle(.yellow).privacySensitive().accessibilityIdentifier("private-image")
                Text("Account 1234").privacySensitive().accessibilityIdentifier("private-text")
                Text("Public").accessibilityIdentifier("public-text")
            }
            .redacted(reason: redact ? .privacy : [])
            Text("Press and hold").padding().background(Color.yellow.opacity(0.4))
                .contextMenu {
                    Button("Copy") { print("menu: copy") }
                    Button("Share") { print("menu: share") }
                } preview: {
                    Text("Preview card").font(.title).padding(30).background(Color.mint)
                }
                .accessibilityIdentifier("menu-source")
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .bottom)
    }
}
