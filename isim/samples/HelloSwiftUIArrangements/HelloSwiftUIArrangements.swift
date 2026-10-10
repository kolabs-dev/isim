// Sample: iOS 27.1 SwiftUI arrangement views on isim's (non-folding) devices — ArrangementView with the automatic,
// split (axes) and overlay styles, splitArrangementLayoutRatio / splitArrangementLayoutSize with layoutPriority,
// overlayArrangementEdge, and a custom ArrangementViewStyle. The buttons in the primary switch the mode.
import SwiftUI

@main
struct HelloSwiftUIArrangementsApp: App {
    var body: some Scene { WindowGroup { Root() } }
}

struct Root: View {
    var body: some View {
        if #available(iOS 27.1, *) { Arranged().onAppear { print("hsarr ios27.1 yes") } }
        else { Text("ArrangementView needs iOS 27.1").onAppear { print("hsarr ios27.1 no") } }
    }
}

@available(iOS 27.1, *)
struct SwappedStyle: ArrangementViewStyle {
    // the secondary on top, then the primary
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) { configuration.secondary; configuration.primary }
    }
}

@available(iOS 27.1, *)
struct Arranged: View {
    @State var mode = "automatic"
    var buttons: some View {
        VStack(spacing: 6) {
            ForEach(["automatic", "ratio", "size", "horizontal", "overlay", "custom"], id: \.self) { m in
                Button(m) { mode = m; print("hsarr mode \(m)") }.buttonStyle(.bordered).accessibilityIdentifier("mode-\(m)")
            }
        }
    }
    var primary: some View {
        ZStack { Color.blue.opacity(0.3).accessibilityIdentifier("primary"); buttons }
    }
    var secondary: some View {
        ZStack { Color.green.opacity(0.5).accessibilityIdentifier("secondary"); Text("Secondary") }
    }
    var body: some View {
        Group {
            switch mode {
            case "ratio":
                ArrangementView { primary.splitArrangementLayoutRatio(0.3).layoutPriority(1) } secondary: { secondary }
            case "size":
                ArrangementView { primary } secondary: { secondary.splitArrangementLayoutSize(idealHeight: 200) }
            case "horizontal":
                ArrangementView { primary } secondary: { secondary }.arrangementViewStyle(.split.axes(.horizontal))
            case "overlay":
                ArrangementView { primary } secondary: { secondary.overlayArrangementEdge(.trailing) }.arrangementViewStyle(.overlay)
            case "custom":
                ArrangementView { primary } secondary: { secondary.frame(height: 150) }.arrangementViewStyle(SwappedStyle())
            default:
                ArrangementView { primary } secondary: { secondary }
            }
        }
        .ignoresSafeArea()
    }
}
