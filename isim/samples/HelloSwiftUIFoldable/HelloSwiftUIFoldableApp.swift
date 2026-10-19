// Sample: the iOS 27.1 SwiftUI APIs for foldable devices on isim's devices, none of which folds — onHingeChange
// (never called: no hinge), GeometryProxy.reservedRegions (the Dynamic Island's occlusion, no division; fixed and
// mirrored), \.toolbarVerticalEdge (nil), toolbarVerticalBehavior / toolbarVerticalCompressionBehavior / axisBehavior
// on a toolbar, \.splitArrangementAxis and \.overlayArrangementZIndex inside ArrangementViews, and a
// CameraCaptureAccessory (never available). It prints what the UI test checks.
import SwiftUI

@main
struct HelloSwiftUIFoldableApp: App {
    var body: some Scene { WindowGroup { Root() } }
}

struct Root: View {
    var body: some View {
        if #available(iOS 27.1, *) { Foldable() }
        else { Text("Needs iOS 27.1").onAppear { print("fold ios27.1 no") } }
    }
}

@available(iOS 27.1, *)
struct AxisReadout: View {
    let name: String
    @Environment(\.splitArrangementAxis) var axis
    @Environment(\.overlayArrangementZIndex) var z
    var body: some View {
        Text("\(name) \(axis.map { $0 == .horizontal ? "horizontal" : "vertical" } ?? "none") z\(z)")
            .accessibilityIdentifier("axis-\(name)")
            .onAppear { print("fold \(name) axis \(axis.map { $0 == .horizontal ? "horizontal" : "vertical" } ?? "none") z \(z)") }
    }
}

@available(iOS 27.1, *)
struct Foldable: View {
    @State private var hingeChanges = 0
    @State private var overlay = false
    @State private var teleprompter = true
    @Environment(\.toolbarVerticalEdge) var verticalEdge
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("hinge changes \(hingeChanges)").accessibilityIdentifier("hinge")
                Text("vertical edge \(verticalEdge == nil ? "none" : "some")").accessibilityIdentifier("edge")
                AxisReadout(name: "outside")
                Button(overlay ? "Split" : "Overlay") { overlay.toggle(); print("fold overlay \(overlay)") }
                    .accessibilityIdentifier("toggle")
                Group {
                    if overlay {
                        ArrangementView { AxisReadout(name: "primary") } secondary: { AxisReadout(name: "secondary") }
                            .arrangementViewStyle(.overlay)
                    } else {
                        ArrangementView { AxisReadout(name: "primary") } secondary: { AxisReadout(name: "secondary") }
                    }
                }
                .frame(height: 200)
            }
            .navigationTitle("Foldable")
            .toolbar {
                ToolbarItem(placement: .bottomBar) { Button("Up", systemImage: "chevron.up") {} }
                    .axisBehavior(.verticalPreferred)
            }
            .toolbarVerticalCompressionBehavior(.prefersToolbarItems)
        }
        .toolbarVerticalBehavior(.disabled)
        .onHingeChange { old, new in hingeChanges += 1; print("fold hinge changed \(new.hinge == nil)") }
        .overlay {
            GeometryReader { proxy in
                Color.clear.onAppear {
                    let occ = proxy.reservedRegions(kind: .occlusion)
                    let fixed = proxy.reservedRegions(kind: .occlusion, layoutDirectionBehavior: .fixed)
                    let ltrMirror = proxy.reservedRegions(kind: .occlusion, layoutDirectionBehavior: .mirrors(in: .leftToRight))
                    let division = proxy.reservedRegions(kind: .division, options: .includeInactive)
                    for r in occ { print("fold region \(r.id) \(r.kind) \(Int(r.frame.minX)) \(Int(r.frame.minY)) \(Int(r.frame.width)) \(Int(r.frame.height)) active \(r.isActive)") }
                    let m = ltrMirror.first.map { Int(proxy.size.width - $0.frame.maxX) } ?? -1
                    print("fold regions occlusion \(occ.count) fixed-same \(fixed == occ) ltr-mirrored-x \(m) division \(division.count)")
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .sceneAccessory {
            CameraCaptureAccessory(isEnabled: $teleprompter) { Text("Teleprompter") }
                .onAvailabilityChange { print("fold camera accessory available \($0)") }
        }
        .onAppear { print("fold ios27.1 yes edge \(verticalEdge == nil ? "nil" : "set")") }
    }
}
