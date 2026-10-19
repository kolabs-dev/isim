// Sample: GraphicsContext's filters, layer clips, blend modes and symbols on isim. Row 1: grayscale, colorMatrix
// (red and blue swapped), alphaThreshold (a soft dot made solid), alphaMultiply, luminanceToAlpha. Row 2:
// projectionTransform, a half colorInvert, two filters in order, the multiply blend mode. Row 3: clipToLayer (a
// circle, its inverse, at half opacity, and text as the mask of a gradient). Row 4: Canvas symbols drawn by tag.
// Everything sits at fixed screen positions so the UI test can check pixels.
import SwiftUI

@main
struct HelloCanvasEffectsApp: App {
    var body: some Scene { WindowGroup { Effects() } }
}

extension View {
    func at(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View { frame(width: w, height: h).offset(x: x, y: y) }
}

let red = Color(red: 1, green: 0, blue: 0), blue = Color(red: 0, green: 0, blue: 1), yellow = Color(red: 1, green: 1, blue: 0)
func square(_ x: CGFloat, _ s: CGFloat = 60) -> Path { Path(CGRect(x: x, y: 0, width: s, height: s)) }

struct Effects: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            Canvas { ctx, _ in                                       // row 1: filters
                var g = ctx; g.addFilter(.grayscale(1))
                g.fill(square(0), with: .color(red))
                var m = ctx; var swap = ColorMatrix()
                swap.r1 = 0; swap.r3 = 1; swap.b1 = 1; swap.b3 = 0
                m.addFilter(.colorMatrix(swap))
                m.fill(square(70), with: .color(blue))
                var t = ctx; t.addFilter(.alphaThreshold(min: 0.5, color: Color(red: 0, green: 0.8, blue: 0)))
                t.fill(Path(ellipseIn: CGRect(x: 140, y: 0, width: 60, height: 60)),
                       with: .radialGradient(Gradient(colors: [.black, .black.opacity(0)]), center: CGPoint(x: 170, y: 30), startRadius: 0, endRadius: 30))
                var a = ctx; a.addFilter(.alphaMultiply(Color(red: 0.5, green: 0, blue: 1)))
                a.fill(square(210), with: .color(red))
                var l = ctx; l.addFilter(.luminanceToAlpha)
                l.fill(square(280), with: .color(.white))
            }.at(20, 100, 350, 60)
            Canvas { ctx, _ in                                       // row 2: transforms, order, blending
                var p = ctx; p.addFilter(.projectionTransform(ProjectionTransform(CGAffineTransform(translationX: 30, y: 0))))
                p.fill(square(0, 40), with: .color(blue))
                var i = ctx; i.addFilter(.colorInvert(0.5))
                i.fill(square(90), with: .color(red))
                var o = ctx; o.addFilter(.colorMultiply(Color(red: 1, green: 0, blue: 0))); o.addFilter(.colorInvert())
                o.fill(square(160), with: .color(.white))          // white × red = red, then inverted: cyan
                ctx.fill(square(230), with: .color(blue))
                var b = ctx; b.blendMode = .multiply
                b.fill(Path(CGRect(x: 260, y: 0, width: 60, height: 60)), with: .color(yellow))
            }.at(20, 190, 350, 60)
            Canvas { ctx, _ in                                       // row 3: clipToLayer
                var c = ctx
                c.clipToLayer { $0.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: 60, height: 60)), with: .color(.black)) }
                c.fill(Path(CGRect(x: 0, y: 0, width: 80, height: 60)), with: .color(red))
                var inv = ctx
                inv.clipToLayer(options: .inverse) { $0.fill(Path(ellipseIn: CGRect(x: 90, y: 0, width: 60, height: 60)), with: .color(.black)) }
                inv.fill(Path(CGRect(x: 90, y: 0, width: 80, height: 60)), with: .color(red))
                var half = ctx
                half.clipToLayer(opacity: 0.5) { $0.fill(Path(CGRect(x: 180, y: 0, width: 40, height: 60)), with: .color(.black)) }
                half.fill(Path(CGRect(x: 180, y: 0, width: 40, height: 60)), with: .color(red))
                var text = ctx
                text.clipToLayer { $0.draw(Text("ISIM").font(.system(size: 44, weight: .black)), at: CGPoint(x: 290, y: 30)) }
                text.fill(Path(CGRect(x: 230, y: 0, width: 120, height: 60)),
                          with: .linearGradient(Gradient(colors: [red, blue]), startPoint: CGPoint(x: 230, y: 0), endPoint: CGPoint(x: 350, y: 0)))
            }.at(20, 280, 350, 60)
            Canvas { ctx, _ in                                       // row 4: symbols
                guard let dot = ctx.resolveSymbol(id: 1), let label = ctx.resolveSymbol(id: "label") else { return }
                for x in stride(from: 15, through: 135, by: 40) { ctx.draw(dot, at: CGPoint(x: x, y: 15)) }
                ctx.draw(label, in: CGRect(x: 180, y: 0, width: label.size.width, height: label.size.height))
                var faded = ctx; faded.opacity = 0.5
                faded.draw(dot, in: CGRect(x: 0, y: 40, width: 60, height: 20))
                print("symbol dot \(Int(dot.size.width))x\(Int(dot.size.height)) label \(label.size.width > 0) missing \(ctx.resolveSymbol(id: 99) == nil)")
            } symbols: {
                Circle().fill(Color(red: 1, green: 0.5, blue: 0)).frame(width: 30, height: 30).tag(1)
                Text("Symbol").font(.system(size: 20, weight: .bold)).foregroundStyle(blue).tag("label")
            }.at(20, 370, 350, 60)
        }
        .ignoresSafeArea()
    }
}
