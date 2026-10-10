// Sample: SwiftUI gestures on isim — MagnifyGesture and RotateGesture together (simultaneously), SpatialTapGesture,
// a long press sequenced before a drag with @GestureState (resets when the gesture ends), and a double tap that wins
// over a single tap (exclusively). Two-finger gestures: Option-drag on the host, or the script's pinch / rotate2.
// PAGE=priority: nested gestures — a child's gesture wins over its parent's, highPriorityGesture, simultaneousGesture
// and gesture masks.
import SwiftUI

@main
struct GesturesApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.environment["PAGE"] == "priority" { PriorityView() } else { ContentView() }
        }
    }
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

/// Each row: a parent (grey, 300 x 70) around a child (blue, 80 x 40 on its trailing side), both with a tap gesture.
struct PriorityView: View {
    func child(_ name: String) -> some View {
        Color.blue.frame(width: 80, height: 40).onTapGesture { print("\(name) child") }.accessibilityIdentifier("\(name)-child")
    }
    func parent<C: View>(_ name: String, @ViewBuilder _ c: () -> C) -> some View {
        HStack { Spacer(); c() }.padding(.horizontal, 15).frame(width: 300, height: 70).background(Color.gray.opacity(0.2))
    }
    var body: some View {
        VStack(spacing: 14) {
            parent("normal") { child("normal") }
                .onTapGesture { print("normal parent") }
            parent("high") { child("high") }
                .highPriorityGesture(TapGesture().onEnded { print("high parent") })
            parent("simul") { child("simul") }
                .simultaneousGesture(TapGesture().onEnded { print("simul parent") })
            parent("own") { child("own") }
                .gesture(TapGesture().onEnded { print("own parent") }, including: .gesture)
            parent("subviews") { child("subviews") }
                .gesture(TapGesture().onEnded { print("subviews parent") }, including: .subviews)
            parent("off") { child("off") }
                .gesture(TapGesture().onEnded { print("off parent") }, isEnabled: false)
            parent("drag") { child("drag") }
                .gesture(DragGesture(minimumDistance: 10).onEnded { _ in print("drag parent") })
        }
    }
}
