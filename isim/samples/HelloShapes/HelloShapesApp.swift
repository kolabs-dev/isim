// Sample: SwiftUI shapes, styles and animation timing on isim — path boolean operations (`union`, `intersection`,
// `subtracting`, `symmetricDifference`, `lineIntersection`) and `strokedPath`; `fill().stroke()`; text filled with a
// gradient; `ContainerRelativeShape` inside `.containerShape`; `MeshGradient` and `Color.mix`; timing curves, springs
// and `repeatCount`; every transition kind; matchedGeometryEffect (an inserted view moving from its match, and a view
// following its source with `isSource: false`).
// The page comes from the environment: PAGE=ops|fills|mesh|curves|transitions|matched.
import SwiftUI

@main
struct HelloShapesApp: App {
    var body: some Scene { WindowGroup { Root() } }
}

let env = ProcessInfo.processInfo.environment

struct Root: View {
    var body: some View {
        switch env["PAGE"] ?? "ops" {
        case "fills": FillsPage()
        case "mesh": if #available(iOS 18.0, *) { MeshPage() }
        case "curves": CurvesPage()
        case "transitions": TransitionsPage()
        case "matched": MatchedPage()
        default: OpsPage()
        }
    }
}

func r(_ rect: CGRect) -> String { String(format: "%.0f %.0f %.0f %.0f", rect.minX, rect.minY, rect.width, rect.height) }

/// Two overlapping 80 pt circles (the second 40 pt to the right) combined in each way.
struct OpsPage: View {
    let a = Circle(), b = Circle().offset(x: 40)
    static let pa = Path(ellipseIn: CGRect(x: 0, y: 0, width: 80, height: 80))
    static let pb = Path(ellipseIn: CGRect(x: 40, y: 0, width: 80, height: 80))
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            row("union", Self.pa.union(Self.pb))
            row("intersection", Self.pa.intersection(Self.pb))
            row("subtracting", Self.pa.subtracting(Self.pb))
            row("xor", Self.pa.symmetricDifference(Self.pb))
            row("stroked", Path(CGRect(x: 10, y: 10, width: 100, height: 60)).strokedPath(StrokeStyle(lineWidth: 10)))
            HStack(spacing: 20) {
                Rectangle().intersection(Circle()).fill(.purple).frame(width: 80, height: 80).accessibilityIdentifier("shape-ops")
                Path { p in p.move(to: CGPoint(x: 0, y: 40)); p.addLine(to: CGPoint(x: 120, y: 40)) }
                    .lineIntersection(Path(ellipseIn: CGRect(x: 30, y: 10, width: 60, height: 60)))
                    .stroke(.orange, lineWidth: 6).frame(width: 120, height: 80).accessibilityIdentifier("line-ops")
            }
        }
        .padding()
        .onAppear {
            print("union \(r(Self.pa.union(Self.pb).boundingRect))")
            print("intersection \(r(Self.pa.intersection(Self.pb).boundingRect))")
            print("subtracting \(r(Self.pa.subtracting(Self.pb).boundingRect))")
            let s = Path(CGRect(x: 10, y: 10, width: 100, height: 60)).strokedPath(StrokeStyle(lineWidth: 10))
            print("stroked \(r(s.boundingRect)) inside=\(s.contains(CGPoint(x: 60, y: 40))) edge=\(s.contains(CGPoint(x: 10, y: 40)))")
            let line = Path { p in p.move(to: CGPoint(x: 0, y: 40)); p.addLine(to: CGPoint(x: 120, y: 40)) }
                .lineIntersection(Path(ellipseIn: CGRect(x: 30, y: 10, width: 60, height: 60)))
            print("line \(r(line.boundingRect))")
        }
    }
    func row(_ id: String, _ p: Path) -> some View {
        p.fill(.blue).frame(width: 120, height: 80).accessibilityIdentifier(id)
    }
}

struct FillsPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Circle().fill(.yellow).stroke(.red, lineWidth: 10).frame(width: 100, height: 100).accessibilityIdentifier("fill-stroke")
            Text("Gradient").font(.system(size: 60, weight: .black))
                .foregroundStyle(LinearGradient(colors: [.red, .blue], startPoint: .leading, endPoint: .trailing))
                .accessibilityIdentifier("grad-text")
            ZStack {
                ContainerRelativeShape().fill(.blue).padding(20).accessibilityIdentifier("relative")
            }
            .frame(width: 200, height: 120)
            .background(.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 40))
            .containerShape(RoundedRectangle(cornerRadius: 40))
            .accessibilityIdentifier("container")
            ContainerRelativeShape().fill(.green).frame(width: 120, height: 40).accessibilityIdentifier("no-container")
        }
    }
}

@available(iOS 18.0, *)
struct MeshPage: View {
    var body: some View {
        VStack(spacing: 20) {
            MeshGradient(width: 2, height: 2, points: [[0, 0], [1, 0], [0, 1], [1, 1]], colors: [.red, .green, .blue, .yellow])
                .frame(width: 200, height: 200).accessibilityIdentifier("mesh")
            Circle().fill(MeshGradient(width: 2, height: 2, points: [[0, 0], [1, 0], [0, 1], [1, 1]], colors: [.red, .red, .blue, .blue]))
                .frame(width: 80, height: 80).accessibilityIdentifier("mesh-fill")
            HStack(spacing: 0) {
                Color.red.frame(width: 60, height: 60)
                Color.red.mix(with: .blue, by: 0.5, in: .device).frame(width: 60, height: 60).accessibilityIdentifier("mix-device")
                Color.red.mix(with: .blue, by: 0.5).frame(width: 60, height: 60).accessibilityIdentifier("mix-perceptual")
                Color.blue.frame(width: 60, height: 60)
            }
        }
        .onAppear {
            let e = EnvironmentValues()
            func show(_ c: Color.Resolved) -> String { String(format: "%.2f %.2f %.2f", c.red, c.green, c.blue) }
            print("mix device \(show(Color(red: 1, green: 0, blue: 0).mix(with: Color(red: 0, green: 0, blue: 1), by: 0.5, in: .device).resolve(in: e)))")
            print("mix perceptual \(show(Color(red: 1, green: 0, blue: 0).mix(with: Color(red: 0, green: 0, blue: 1), by: 0.5).resolve(in: e)))")
            print("resolved \(show(Color(red: 0.25, green: 0.5, blue: 1).resolve(in: e)))")
        }
    }
}

/// Boxes that move 240 pt right (from x 16) when Go is tapped: linear, a slow-start custom timing curve, a bouncy spring, a
/// linear move repeated three times with autoreverse, and an interpolating spring.
struct CurvesPage: View {
    @State var right = false
    let d = Double(env["DURATION"] ?? "3") ?? 3
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Go") { right.toggle() }.accessibilityIdentifier("go")
            box("linear", .red, .linear(duration: d))
            box("custom", .blue, .timingCurve(0.9, 0, 1, 1, duration: d))
            box("spring", .green, .spring(duration: d, bounce: 0.6))
            box("repeat", .orange, .linear(duration: d / 3).repeatCount(3, autoreverses: true))
            box("interp", .purple, .interpolatingSpring(mass: 1, stiffness: 30, damping: 2))
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .onAppear {
            let c = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.9, y: 0), endControlPoint: UnitPoint(x: 1, y: 1))
            print(String(format: "curve %.3f %.3f %.3f", c.value(at: 0.25), c.value(at: 0.5), c.value(at: 0.9)))
            let s = Spring(duration: 1, bounce: 0.6)
            print(String(format: "spring peak %.3f", (1...200).map { s.value(target: 1.0, time: Double($0) / 100) }.max()!))
            let p = Spring(mass: 1, stiffness: 100, damping: 20)
            print(String(format: "critical %.3f", p.dampingRatio))
        }
    }
    func box(_ id: String, _ c: Color, _ a: Animation) -> some View {
        c.frame(width: 40, height: 40).offset(x: right ? 240 : 0).animation(a, value: right).accessibilityIdentifier(id)
    }
}

/// Eight slots (120 x 90), each showing a 60 pt square with one transition while `shown`; Toggle animates linearly.
struct TransitionsPage: View {
    @State var shown = env["SHOWN"] == "1"
    let d = Double(env["DURATION"] ?? "2") ?? 2
    static let kinds: [(String, Color, AnyTransition)] = [
        ("opacity", Color(red: 1, green: 0, blue: 0), .opacity),
        ("scale", Color(red: 0, green: 0.6, blue: 0), .scale),
        ("slide", Color(red: 0, green: 0, blue: 1), .slide),
        ("move", Color(red: 1, green: 0.5, blue: 0), .move(edge: .top)),
        ("offset", Color(red: 0.5, green: 0, blue: 0.5), .offset(x: 40, y: 0)),
        ("push", Color(red: 0, green: 0.5, blue: 0.5), .push(from: .trailing)),
        ("asymmetric", Color(red: 0.6, green: 0.3, blue: 0), .asymmetric(insertion: .scale, removal: .opacity)),
        ("combined", Color(red: 1, green: 0, blue: 1), AnyTransition.opacity.combined(with: .scale(scale: 0.5))),
    ]
    var body: some View {
        VStack(spacing: 10) {
            Button("Toggle") { withAnimation(.linear(duration: d)) { shown.toggle() } }.accessibilityIdentifier("toggle")
            LazyVGrid(columns: [GridItem(.fixed(120), spacing: 30), GridItem(.fixed(120))], spacing: 20) {
                ForEach(Self.kinds, id: \.0) { name, color, t in
                    ZStack {
                        if shown { color.frame(width: 60, height: 60).transition(t) }
                    }
                    .frame(width: 120, height: 90)
                    .accessibilityIdentifier("slot-\(name)")
                }
            }
        }
    }
}

struct MatchedPage: View {
    @Namespace var ns
    @State var big = false
    @State var selected = 0
    let d = Double(env["DURATION"] ?? "2") ?? 2
    var body: some View {
        VStack(spacing: 30) {
            Button("Grow") { withAnimation(.linear(duration: d)) { big.toggle() } }.accessibilityIdentifier("grow")
            ZStack(alignment: .topLeading) {
                Color.clear
                if big {
                    Color.blue.frame(width: 200, height: 120).matchedGeometryEffect(id: "card", in: ns)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).accessibilityIdentifier("card-big")
                } else {
                    Color.blue.frame(width: 60, height: 60).matchedGeometryEffect(id: "card", in: ns).accessibilityIdentifier("card-small")
                }
            }
            .frame(width: 300, height: 220)
            .background(Color.gray.opacity(0.15))
            HStack(spacing: 12) {
                ForEach(0..<3) { i in
                    Text(["One", "Two", "Three"][i]).padding(.horizontal, i == 2 ? 30 : 14).padding(.vertical, 8)
                        .matchedGeometryEffect(id: i, in: ns)
                        .onTapGesture { withAnimation(.linear(duration: d)) { selected = i } }
                        .accessibilityIdentifier("tab-\(i)")
                }
            }
            .background(Capsule().fill(Color.orange.opacity(0.5)).matchedGeometryEffect(id: selected, in: ns, isSource: false).accessibilityIdentifier("highlight"))
        }
    }
}
