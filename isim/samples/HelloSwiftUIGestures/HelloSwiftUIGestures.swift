// Sample: SwiftUI gestures on isim — MagnifyGesture and RotateGesture together (simultaneously), SpatialTapGesture,
// a long press sequenced before a drag with @GestureState (resets when the gesture ends), and a double tap that wins
// over a single tap (exclusively). Two-finger gestures: Option-drag on the host, or the script's pinch / rotate2.
import SwiftUI

@main
struct GesturesApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @State private var scale: CGFloat = 1
    @State private var angle: Angle = .zero
    @GestureState private var liveScale: CGFloat = 1
    @GestureState private var dragOffset: CGSize = .zero
    @State private var position: CGSize = .zero
    @State private var taps = ""

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 16).fill(Color.orange)
                .frame(width: 120, height: 120)
                .scaleEffect(scale * liveScale)
                .rotationEffect(angle)
                .frame(width: 360, height: 240)
                .background(Color.gray.opacity(0.15))
                .gesture(
                    MagnifyGesture()
                        .updating($liveScale) { v, s, _ in s = v.magnification }
                        .onEnded { v in scale *= v.magnification; print(String(format: "magnify ended %.2f", v.magnification)) }
                        .simultaneously(with: RotateGesture().onEnded { v in angle += v.rotation; print(String(format: "rotate ended %.0f", v.rotation.degrees)) })
                )
                .accessibilityIdentifier("stage")

            Circle().fill(Color.blue).frame(width: 60, height: 60)
                .offset(x: position.width + dragOffset.width, y: position.height + dragOffset.height)
                .gesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .updating($dragOffset) { value, state, _ in
                            if case .second(true, let drag?) = value { state = drag.translation }
                        }
                        .onEnded { value in
                            if case .second(true, let drag?) = value {
                                position.width += drag.translation.width; position.height += drag.translation.height
                                print(String(format: "moved by %.0f,%.0f", drag.translation.width, drag.translation.height))
                            }
                        }
                )
                .frame(width: 360, height: 120)
                .accessibilityIdentifier("puck")
            Text("offset \(Int(dragOffset.width)) live, \(Int(position.width)) kept").accessibilityIdentifier("offset")

            Text(taps.isEmpty ? "Tap me" : taps).frame(width: 200, height: 60).background(Color.green.opacity(0.3))
                .gesture(TapGesture(count: 2).onEnded { taps = "double"; print("double tap") }
                    .exclusively(before: SpatialTapGesture().onEnded { v in taps = "single"; print(String(format: "single tap at %.0f,%.0f", v.location.x, v.location.y)) }))
                .accessibilityIdentifier("taps")
        }
    }
}
