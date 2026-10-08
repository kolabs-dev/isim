// Source-compatibility patterns that compile with Apple's SDK and must compile and work on isim too
// (each was found building real apps; tests/ui/test_sourcecompat.py checks them).
import SwiftUI
import UIKit

/// colours in nonisolated statics: Color is Sendable and not main-actor isolated
enum Palette {
    static let ink = Color(red: 0.9, green: 0.1, blue: 0.1)
    static let rule = Color(red: 0.1, green: 0.2, blue: 0.9)
}
/// Bundle is Sendable (like the `Bundle.module` accessor Swift packages generate)
enum Resources { static let bundle: Bundle = .main }

struct ContentView: View {
    @State private var dragEnabled = true
    @State private var drags = 0
    let haptic = UIImpactFeedbackGenerator(style: .soft)
    var body: some View {
        VStack(spacing: 24) {
            Text(Image(systemName: "star.fill")).font(.system(size: 40)).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("star-text")
            (Text(Image(systemName: "star.fill")) + Text(" Favorites")).accessibilityIdentifier("favorites")
            Divider().overlay(Palette.rule).frame(width: 200)
            Canvas { ctx, size in
                ctx.draw(Text(Image(systemName: "star.fill")).font(.system(size: 30, weight: .heavy)).foregroundStyle(Palette.ink),
                         at: CGPoint(x: size.width / 2, y: size.height / 2))
            }
            .frame(width: 80, height: 80).accessibilityIdentifier("canvas")
            Color.gray.frame(width: 200, height: 100)
                .gesture(dragEnabled ? DragGesture().onEnded { _ in drags += 1; print("compat drag \(drags)") } : nil)
                .accessibilityIdentifier("drag-area")
            Button("Disable drag") { dragEnabled = false; print("compat drag disabled") }.accessibilityIdentifier("disable")
            Button("Haptic") { haptic.impactOccurred(intensity: 0.5); print("compat haptic") }.accessibilityIdentifier("haptic")
        }
        .onAppear { print("compat statics \(Palette.ink == Palette.ink) bundle=\(Resources.bundle.bundleIdentifier ?? "-")") }
    }
}

@main struct HelloSourceCompatApp: App {
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup { ContentView() }
            .onChange(of: phase, initial: true) { _, p in print("compat scene phase \(p)") }
    }
}
