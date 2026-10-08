// Sample: UIBezierPath on isim — dashes, line caps and joins, clipping (addClip), hit testing (contains, even-odd),
// rounded corners per corner, reversing, transforms, current point, blend mode / alpha, copying and secure coding.
// The screen shows each feature as a tile; the checks render paths into bitmaps and print PASS / FAIL lines.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = BezierViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

var checks = 0, failures = 0
func check(_ ok: Bool, _ what: String) {
    checks += 1
    if !ok { failures += 1 }
    print("\(ok ? "PASS" : "FAIL")  \(what)")
}

/// draws with UIKit into a w x h bitmap (1 pt = 1 px) and returns its RGBA bytes, row 0 at the top
func render(_ w: Int, _ h: Int, _ draw: () -> Void) -> [UInt8] {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { _ in draw() }
    var bytes = [UInt8](repeating: 0, count: w * h * 4)
    bytes.withUnsafeMutableBytes { buf in
        let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return bytes
}
/// alpha of the pixel at (x, y)
func alpha(_ px: [UInt8], _ w: Int, _ x: Int, _ y: Int) -> Int { Int(px[(y * w + x) * 4 + 3]) }

func runChecks() {
    // dashes: 10 on, 10 off along a horizontal line
    let dashed = render(100, 10) {
        let p = UIBezierPath(); p.move(to: CGPoint(x: 0, y: 5)); p.addLine(to: CGPoint(x: 100, y: 5))
        p.lineWidth = 4; p.setLineDash([10, 10], count: 2, phase: 0)
        UIColor.black.setStroke(); p.stroke()
    }
    check(alpha(dashed, 100, 5, 5) > 200 && alpha(dashed, 100, 15, 5) == 0 && alpha(dashed, 100, 25, 5) > 200,
          "setLineDash: 10 on, 10 off (\(alpha(dashed, 100, 5, 5)) \(alpha(dashed, 100, 15, 5)) \(alpha(dashed, 100, 25, 5)))")
    let p0 = UIBezierPath(); p0.setLineDash([3, 4, 5], count: 3, phase: 2)
    var pattern = [CGFloat](repeating: 0, count: 3); var count = 0; var phase: CGFloat = 0
    p0.getLineDash(&pattern, count: &count, phase: &phase)
    check(pattern == [3, 4, 5] && count == 3 && phase == 2, "getLineDash returns the pattern, count and phase")

    // caps: a 10-wide line from x=10 to x=50; round and square caps reach 5 past the ends, butt caps do not
    func cap(_ style: CGLineCap) -> [UInt8] {
        render(60, 20) {
            let p = UIBezierPath(); p.move(to: CGPoint(x: 10, y: 10)); p.addLine(to: CGPoint(x: 50, y: 10))
            p.lineWidth = 10; p.lineCapStyle = style; UIColor.black.setStroke(); p.stroke()
        }
    }
    let butt = cap(.butt), round = cap(.round), square = cap(.square)
    let caps = [alpha(butt, 60, 7, 10), alpha(round, 60, 7, 10), alpha(round, 60, 5, 5), alpha(square, 60, 5, 5)]
    check(caps[0] == 0 && caps[1] > 200 && caps[2] == 0 && caps[3] > 200, "lineCapStyle: butt / round / square (\(caps))")

    // joins: a right angle at (40, 40); the miter fills the outer corner, round only near it, bevel cuts it
    func join(_ style: CGLineJoin) -> [UInt8] {
        render(60, 60) {
            let p = UIBezierPath(); p.move(to: CGPoint(x: 10, y: 40)); p.addLine(to: CGPoint(x: 40, y: 40)); p.addLine(to: CGPoint(x: 40, y: 10))
            p.lineWidth = 10; p.lineJoinStyle = style; UIColor.black.setStroke(); p.stroke()
        }
    }
    let miter = join(.miter), rjoin = join(.round), bevel = join(.bevel)
    let joins = [alpha(miter, 60, 44, 44), alpha(rjoin, 60, 44, 44), alpha(rjoin, 60, 42, 42), alpha(bevel, 60, 44, 44), alpha(bevel, 60, 41, 41)]
    check(joins[0] > 200 && joins[1] == 0 && joins[2] > 200 && joins[3] == 0 && joins[4] > 200, "lineJoinStyle: miter / round / bevel (\(joins))")

    // addClip: a rect filled inside an oval clip only paints the oval
    let clipped = render(40, 40) {
        UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 40, height: 40)).addClip()
        UIColor.black.setFill(); UIBezierPath(rect: CGRect(x: 0, y: 0, width: 40, height: 40)).fill()
    }
    check(alpha(clipped, 40, 20, 20) > 200 && alpha(clipped, 40, 2, 2) == 0, "addClip clips to the path")

    // contains: nonzero vs even-odd on two nested rects drawn the same way round
    let donut = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
    donut.append(UIBezierPath(rect: CGRect(x: 25, y: 25, width: 50, height: 50)))
    let nonzero = donut.contains(CGPoint(x: 50, y: 50))
    donut.usesEvenOddFillRule = true
    check(nonzero && !donut.contains(CGPoint(x: 50, y: 50)) && donut.contains(CGPoint(x: 10, y: 10)) && !donut.contains(CGPoint(x: 150, y: 50)),
          "contains: nonzero and even-odd fill rules")
    let ring = render(100, 100) { UIColor.black.setFill(); donut.fill() }
    check(alpha(ring, 100, 50, 50) == 0 && alpha(ring, 100, 10, 10) > 200, "usesEvenOddFillRule fills a ring")

    // per-corner rounding: only the top-left corner is round
    let corner = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 60), byRoundingCorners: .topLeft,
                              cornerRadii: CGSize(width: 20, height: 20))
    check(!corner.contains(CGPoint(x: 2, y: 2)) && corner.contains(CGPoint(x: 98, y: 2)) && corner.contains(CGPoint(x: 2, y: 58)),
          "init(roundedRect:byRoundingCorners:cornerRadii:)")

    // current point, reversing, transforms, bounds
    let open = UIBezierPath(); open.move(to: CGPoint(x: 1, y: 2)); open.addLine(to: CGPoint(x: 30, y: 2))
    open.addCurve(to: CGPoint(x: 30, y: 40), controlPoint1: CGPoint(x: 50, y: 2), controlPoint2: CGPoint(x: 50, y: 40))
    check(open.currentPoint == CGPoint(x: 30, y: 40), "currentPoint is the last point")
    let reversed = open.reversing()
    check(reversed.currentPoint == CGPoint(x: 1, y: 2) && reversed.bounds == open.bounds, "reversing() ends at the start, same bounds")
    let closed = UIBezierPath(rect: CGRect(x: 5, y: 6, width: 10, height: 10))
    check(closed.currentPoint == CGPoint(x: 5, y: 6), "currentPoint after closePath is the subpath's start")
    let moved = closed.copy() as! UIBezierPath
    moved.apply(CGAffineTransform(translationX: 10, y: 20))
    check(moved.bounds == CGRect(x: 15, y: 26, width: 10, height: 10) && closed.bounds == CGRect(x: 5, y: 6, width: 10, height: 10),
          "apply(_:) transforms a copy, not the original (\(moved.bounds))")
    check(UIBezierPath().isEmpty && UIBezierPath().bounds.isNull && !closed.isEmpty, "isEmpty / bounds of an empty path")

    // fill(with:alpha:): half-transparent paint
    let half = render(10, 10) { UIColor.black.setFill(); UIBezierPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10)).fill(with: .normal, alpha: 0.5) }
    check(abs(alpha(half, 10, 5, 5) - 128) <= 2, "fill(with:alpha:) (alpha \(alpha(half, 10, 5, 5)))")

    // copying and secure coding keep the path and its line settings
    let styled = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 30, height: 20))
    styled.lineWidth = 3; styled.lineCapStyle = .round; styled.lineJoinStyle = .bevel; styled.setLineDash([2, 3], count: 2, phase: 1)
    let copy = styled.copy() as! UIBezierPath
    var n = 0; copy.getLineDash(nil, count: &n, phase: nil)
    check(copy.bounds == styled.bounds && copy.lineWidth == 3 && copy.lineCapStyle == .round && n == 2, "copy keeps the path and line settings")
    let data = try? NSKeyedArchiver.archivedData(withRootObject: styled, requiringSecureCoding: true)
    let back = data.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIBezierPath.self, from: $0) }
    var bn = 0; back?.getLineDash(nil, count: &bn, phase: nil)
    check(back?.bounds == styled.bounds && back?.lineWidth == 3 && back?.lineJoinStyle == .bevel && bn == 2,
          "NSSecureCoding round trip")
    // CGPath bridging
    let viaCG = UIBezierPath(cgPath: styled.cgPath)
    check(viaCG.bounds == styled.bounds, "init(cgPath:) / cgPath")

    print("bezier checks: \(checks - failures)/\(checks) passed")
}

/// one tile per feature, for the screen
final class TilesView: UIView {
    override func draw(_ rect: CGRect) {
        UIColor.systemBackground.setFill(); UIRectFill(bounds)
        let tint = UIColor.systemBlue, orange = UIColor.systemOrange
        func label(_ s: String, _ x: CGFloat, _ y: CGFloat) {
            (s as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.secondaryLabel])
        }
        // dashes
        label("dashes", 20, 10)
        for (i, d) in [[12.0, 6.0], [2.0, 6.0], [16.0, 4.0, 2.0, 4.0]].enumerated() {
            let p = UIBezierPath(); p.move(to: CGPoint(x: 20, y: 40 + i * 18)); p.addLine(to: CGPoint(x: 180, y: 40 + i * 18))
            p.lineWidth = 4; p.lineCapStyle = i == 1 ? .round : .butt; p.setLineDash(d.map { CGFloat($0) }, count: d.count, phase: 0)
            tint.setStroke(); p.stroke()
        }
        // caps
        label("butt / round / square caps", 200, 10)
        for (i, c) in [CGLineCap.butt, .round, .square].enumerated() {
            let p = UIBezierPath(); p.move(to: CGPoint(x: 220, y: 40 + i * 20)); p.addLine(to: CGPoint(x: 340, y: 40 + i * 20))
            p.lineWidth = 12; p.lineCapStyle = c; orange.setStroke(); p.stroke()
        }
        // joins
        label("miter / round / bevel joins", 20, 110)
        for (i, j) in [CGLineJoin.miter, .round, .bevel].enumerated() {
            let x = 30 + CGFloat(i) * 110
            let p = UIBezierPath(); p.move(to: CGPoint(x: x, y: 200)); p.addLine(to: CGPoint(x: x + 40, y: 140)); p.addLine(to: CGPoint(x: x + 80, y: 200))
            p.lineWidth = 16; p.lineJoinStyle = j; tint.setStroke(); p.stroke()
        }
        // clip
        label("addClip (oval)", 20, 220)
        UIGraphicsGetCurrentContext()?.saveGState()
        UIBezierPath(ovalIn: CGRect(x: 20, y: 245, width: 150, height: 100)).addClip()
        for k in 0..<12 { (k % 2 == 0 ? orange : tint).setFill(); UIBezierPath(rect: CGRect(x: 20 + CGFloat(k) * 13, y: 245, width: 13, height: 100)).fill() }
        UIGraphicsGetCurrentContext()?.restoreGState()
        // even-odd
        label("even-odd ring", 200, 220)
        let ring = UIBezierPath(ovalIn: CGRect(x: 220, y: 245, width: 100, height: 100))
        ring.append(UIBezierPath(ovalIn: CGRect(x: 245, y: 270, width: 50, height: 50)))
        ring.usesEvenOddFillRule = true; tint.setFill(); ring.fill()
        // corners
        label("two rounded corners", 20, 360)
        let corners = UIBezierPath(roundedRect: CGRect(x: 20, y: 385, width: 150, height: 80), byRoundingCorners: [.topLeft, .bottomRight],
                                   cornerRadii: CGSize(width: 30, height: 30))
        orange.setFill(); corners.fill()
        // blend + alpha
        label("multiply, alpha 0.6", 200, 360)
        tint.setFill(); UIBezierPath(ovalIn: CGRect(x: 210, y: 385, width: 80, height: 80)).fill()
        orange.setFill(); UIBezierPath(ovalIn: CGRect(x: 250, y: 385, width: 80, height: 80)).fill(with: .multiply, alpha: 0.6)
    }
}

final class BezierViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let tiles = TilesView()
        tiles.accessibilityIdentifier = "tiles"
        tiles.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tiles)
        NSLayoutConstraint.activate([
            tiles.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tiles.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tiles.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tiles.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        runChecks()
    }
}
