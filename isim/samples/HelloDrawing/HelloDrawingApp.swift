// Sample: SwiftUI drawing and animation on isim — custom Shapes and Paths, fill rules, stroke styles,
// trims, insets, shape transforms, gradients (linear, radial, angular, elliptical, Color.gradient),
// clipping to custom shapes, Canvas, TimelineView, animatable shapes/colors, phase and keyframe
// animations, and projection effects. Items sit at fixed screen positions so the UI test can check pixels.
import SwiftUI

@main
struct HelloDrawingApp: App {
    var body: some Scene { WindowGroup { Gallery() } }
}

struct Gallery: View {
    @State private var page = 0
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            if page == 0 { ShapesPage() } else { MotionPage() }
            Button(page == 0 ? "Motion" : "Shapes") { page = 1 - page }
                .accessibilityIdentifier("next")
                .frame(width: 120, height: 44)
                .offset(x: 140, y: 800)
        }
        .ignoresSafeArea()
        .onAppear { PathChecks.run() }
    }
}

/// Places a view at a fixed position (points from the screen's top-left).
extension View {
    func at(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View { frame(width: w, height: h).offset(x: x, y: y) }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A horizontal bar whose filled fraction animates (custom animatableData).
struct Bar: Shape {
    var fraction: CGFloat
    var animatableData: CGFloat { get { fraction } set { fraction = newValue } }
    func path(in rect: CGRect) -> Path { Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width * fraction, height: rect.height)) }
}

struct ShapesPage: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            // custom Shape, even-odd Path, Ellipse
            Triangle().fill(Color.red).at(20, 80, 100, 100)
            Path { p in
                p.addRect(CGRect(x: 0, y: 0, width: 100, height: 100))
                p.addRect(CGRect(x: 30, y: 30, width: 40, height: 40))
            }.fill(Color.blue, style: FillStyle(eoFill: true)).at(140, 80, 100, 100)
            Ellipse().fill(Color.green).at(260, 80, 120, 60)
            // gradients
            LinearGradient(colors: [Color(red: 1, green: 0, blue: 0), Color(red: 0, green: 0, blue: 1)], startPoint: .leading, endPoint: .trailing)
                .at(20, 200, 160, 40)
            Circle().fill(RadialGradient(colors: [.white, .black], center: .center, startRadius: 0, endRadius: 40)).at(200, 200, 80, 80)
            Circle().fill(AngularGradient(colors: [Color(red: 1, green: 0, blue: 0), Color(red: 0, green: 1, blue: 0), Color(red: 0, green: 0, blue: 1), Color(red: 1, green: 0, blue: 0)], center: .center))
                .at(300, 200, 80, 80)
            // stroke styles, uneven corners, trim, strokeBorder
            Rectangle().stroke(Color.black, style: StrokeStyle(lineWidth: 4, dash: [10, 10])).at(20, 300, 160, 40)
            UnevenRoundedRectangle(topLeadingRadius: 30).fill(Color.orange).at(200, 300, 80, 60)
            Circle().trim(from: 0, to: 0.5).stroke(Color.purple, lineWidth: 8).at(300, 290, 80, 80)
            Circle().strokeBorder(Color.purple, lineWidth: 10).at(20, 380, 80, 80)
            // clipping to a custom shape
            Color.teal.clipShape(Triangle()).at(120, 380, 80, 80)
            // Canvas
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(x: 0, y: 0, width: 50, height: 50)), with: .color(Color(red: 1, green: 0, blue: 0)))
                var moved = ctx
                moved.translateBy(x: 80, y: 0)
                moved.fill(Path(CGRect(x: 0, y: 0, width: 30, height: 30)), with: .color(Color(red: 0, green: 0.5, blue: 0)))
                var faded = ctx
                faded.opacity = 0.5
                faded.fill(Path(CGRect(x: 0, y: 60, width: 40, height: 40)), with: .color(Color(red: 0, green: 0, blue: 1)))
                var clipped = ctx
                clipped.clip(to: Path(ellipseIn: CGRect(x: 120, y: 50, width: 40, height: 40)))
                clipped.fill(Path(CGRect(x: 100, y: 40, width: 60, height: 60)),
                             with: .linearGradient(Gradient(colors: [.yellow, .orange]), startPoint: CGPoint(x: 100, y: 0), endPoint: CGPoint(x: 160, y: 0)))
                ctx.draw(Text("Canvas").font(.system(size: 12)), at: CGPoint(x: 80, y: 80))
            }.at(220, 380, 160, 100).accessibilityIdentifier("canvas")
            // more styles
            Rectangle().fill(Color.blue.gradient).at(20, 480, 100, 40)
            Rectangle().foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0, blue: 0), Color(red: 1, green: 1, blue: 0)], startPoint: .leading, endPoint: .trailing))
                .at(140, 480, 100, 40)
            EllipticalGradient(colors: [Color(red: 0, green: 1, blue: 0), Color(red: 0, green: 0, blue: 0)]).at(260, 480, 120, 40)
            Text("Gradient").frame(width: 100, height: 30)
                .background(LinearGradient(colors: [Color(red: 0, green: 1, blue: 1), Color(red: 1, green: 0, blue: 1)], startPoint: .top, endPoint: .bottom))
                .at(20, 600, 100, 30)
            // projection effects and shape transforms
            Rectangle().fill(Color.green).rotation3DEffect(.degrees(60), axis: (x: 0, y: 1, z: 0)).at(20, 540, 100, 40)
            Rectangle().fill(Color.blue).transformEffect(CGAffineTransform(translationX: 30, y: 0)).at(140, 540, 60, 40)
            Rectangle().rotation(.degrees(45)).fill(Color.pink).at(280, 545, 60, 60)
            AnyShape(Capsule()).fill(Color.indigo).at(140, 600, 100, 30)
            Circle().offset(x: 20).fill(Color.brown).at(280, 640, 40, 40)
            Rectangle().inset(by: 10).fill(Color.mint).at(140, 650, 60, 60)
        }
    }
}

struct MotionPage: View {
    @State private var progress: CGFloat = 0
    @State private var fraction: CGFloat = 0.1
    @State private var warm = false
    @State private var bounce = 0
    var body: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.periodic(from: Date(), by: 0.5)) { context in
                Text("tick \(Ticks.count(context.date))").accessibilityIdentifier("tick")
            }.at(20, 70, 200, 30)
            Circle().trim(from: 0, to: progress).stroke(Color.purple, style: StrokeStyle(lineWidth: 10, lineCap: .butt))
                .at(20, 120, 100, 100)
            Bar(fraction: fraction).fill(Color.blue).at(140, 120, 240, 40)
            Triangle().fill(warm ? Color(red: 0, green: 0, blue: 1) : Color(red: 1, green: 0, blue: 0)).at(140, 170, 60, 60)
            Rectangle().fill(LinearGradient(colors: warm ? [.orange, .yellow] : [.blue, .cyan], startPoint: .leading, endPoint: .trailing)).at(220, 170, 160, 40)
            Button("Animate") {
                print("animate tapped"); withAnimation(.linear(duration: 2)) { progress = 1; fraction = 1; warm = true }
            }.accessibilityIdentifier("animate").at(20, 240, 120, 44)
            Text("phase").phaseAnimator([0, 1, 2]) { content, phase in
                content.opacity(phase == 1 ? 0.5 : 1).overlay { PhaseProbe(phase: phase) }
            } animation: { _ in .linear(duration: 0.3) }
            .at(20, 300, 100, 30)
            Text("bounce").keyframeAnimator(initialValue: 0.0, trigger: bounce) { content, y in
                content.offset(y: y).overlay { KeyframeProbe(value: y) }
            } keyframes: { _ in
                KeyframeTrack { LinearKeyframe(60.0, duration: 1); LinearKeyframe(0.0, duration: 1) }
            }
            .at(160, 300, 100, 30)
            Button("Bounce") { bounce += 1; print("bounce tapped") }.accessibilityIdentifier("bounce").at(280, 240, 100, 44)
            Canvas { ctx, size in
                ctx.stroke(Path { p in p.addArc(center: CGPoint(x: 50, y: 50), radius: 40, startAngle: .zero, endAngle: .degrees(270), clockwise: false) },
                           with: .color(.black), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }.at(20, 380, 100, 100)
        }
    }
}

enum Ticks {
    static var first: Date?
    static func count(_ d: Date) -> Int { if first == nil { first = d }; return Int((d.timeIntervalSince(first!) * 2).rounded()) }
}
struct PhaseProbe: View {
    let phase: Int
    var body: some View { Color.clear.onChange(of: phase, initial: true) { print("phase \(phase)") } }
}
struct KeyframeProbe: View {
    let value: Double
    var body: some View { Color.clear.onChange(of: Int(value), initial: false) { if Int(value) % 10 == 0 { print("keyframe \(Int(value))") } } }
}

/// Path and shape geometry checks printed to the log.
enum PathChecks {
    static func run() {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 100, y: 0)); p.addLine(to: CGPoint(x: 100, y: 50)); p.closeSubpath()
        print("path description: \(p.description)")
        print("path bounds: \(p.boundingRect)")
        print("path contains inside: \(p.contains(CGPoint(x: 80, y: 10))) outside: \(p.contains(CGPoint(x: 10, y: 40)))")
        let half = Path(CGRect(x: 0, y: 0, width: 100, height: 100)).trimmedPath(from: 0, to: 0.5)
        print("trimmed: \(half.description)")
        let round = Path(Path(ellipseIn: CGRect(x: 0, y: 0, width: 20, height: 20)).cgPath)
        print("from CGPath bounds: \(round.boundingRect.integral)")
        print("parsed: \(Path("0 0 m 10 0 l 10 10 l h")?.description ?? "nil")")
        var arc = Path()
        arc.addArc(center: .zero, radius: 10, startAngle: .zero, endAngle: .degrees(90), clockwise: false)
        print("arc end: \(arc.currentPoint.map { "\(Int($0.x.rounded())),\(Int($0.y.rounded()))" } ?? "nil")")
        let t = KeyframeTimeline(initialValue: 0.0) {
            KeyframeTrack { LinearKeyframe(10.0, duration: 1); MoveKeyframe(50.0); CubicKeyframe(0.0, duration: 1) }
        }
        print("timeline duration \(t.duration) at 0.5: \(t.value(time: 0.5)) at 1.5: \(t.value(time: 1.5) > 0 && t.value(time: 1.5) < 50) end: \(t.value(time: 3))")
        print("unit curve easeIn 0.5: \(UnitCurve.easeIn.value(at: 0.5) < 0.5)")
        print("rect contains: \(Rectangle().path(in: CGRect(x: 0, y: 0, width: 10, height: 10)).contains(CGPoint(x: 5, y: 5)))")
    }
}
