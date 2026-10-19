// HelloCoreAnimation, -layers: Core Animation layer features, one page per area (PAGE=contents|text|emitter|transform|
// scroll|transition|valuefn|raster):
// - contents: contentsCenter (9-slice), contentsRect, contentsScale, gravities;
// - text: CATextLayer truncation (none, start, middle, end; wrapped);
// - emitter: CAEmitterLayer sub-cells (fireworks with trails) and 3D emission (emissionLatitude);
// - transform: CATransformLayer (a shared 3D space, depth-sorted) against a plain layer (flattened), a 3D box;
// - scroll: CAScrollLayer scroll(to:), scrollMode, scrollRectToVisible / visibleRect;
// - transition: CATransition fade, push, moveIn, reveal, paused half-way;
// - valuefn: CAValueFunction rotate / translate / scale (basic and keyframe), paused half-way;
// - raster: shouldRasterize / rasterizationScale, and filters / compositingFilter (not applied, like iOS).
// The pages print what the UI test checks.
import UIKit
import QuartzCore
import CoreImage

private func f2(_ v: CGFloat) -> String { String(format: "%.2f", Double(v)) }

/// A bitmap of `size` pixels (scale 1) drawn by `draw`.
private func bitmap(_ size: CGSize, _ draw: (CGContext) -> Void) -> CGImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext) }.cgImage!
}
private func fill(_ c: CGContext, _ color: UIColor, _ r: CGRect) { c.setFillColor(color.cgColor); c.fill(r) }

/// A plain layer of a colour.
private func box(_ frame: CGRect, _ color: UIColor) -> CALayer {
    let l = CALayer()
    l.frame = frame
    l.backgroundColor = color.cgColor
    return l
}

final class LayersViewController: UIViewController {
    let page = ProcessInfo.processInfo.environment["PAGE"] ?? "contents"
    var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        switch page {
        case "text": text()
        case "emitter": emitter()
        case "transform": transform()
        case "scroll": scroll()
        case "transition": transition()
        case "valuefn": valueFunctions()
        case "raster": raster()
        default: contents()
        }
    }

    // MARK: contents

    func contents() {
        let root = view.layer
        // a 30 x 30 px frame: black, with a white 10 x 10 centre
        let frame = bitmap(CGSize(width: 30, height: 30)) { c in
            fill(c, .black, CGRect(x: 0, y: 0, width: 30, height: 30)); fill(c, .white, CGRect(x: 10, y: 10, width: 10, height: 10))
        }
        let nine = CALayer()
        nine.frame = CGRect(x: 20, y: 100, width: 150, height: 90)
        nine.contents = frame
        nine.contentsCenter = CGRect(x: 1.0 / 3, y: 1.0 / 3, width: 1.0 / 3, height: 1.0 / 3)   // corners stay 10 pt
        root.addSublayer(nine)
        let plain = CALayer()
        plain.frame = CGRect(x: 220, y: 100, width: 150, height: 90)
        plain.contents = frame                                                              // scaled as a whole
        root.addSublayer(plain)
        // contentsRect: the right half (blue) of a red | blue image
        let halves = bitmap(CGSize(width: 60, height: 30)) { c in
            fill(c, .red, CGRect(x: 0, y: 0, width: 30, height: 30)); fill(c, .blue, CGRect(x: 30, y: 0, width: 30, height: 30))
        }
        let part = CALayer()
        part.frame = CGRect(x: 20, y: 230, width: 150, height: 90)
        part.contents = halves
        part.contentsRect = CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        root.addSublayer(part)
        // contentsScale 2: a 40 px square is 20 pt, centred
        let red = bitmap(CGSize(width: 40, height: 40)) { c in fill(c, .red, CGRect(x: 0, y: 0, width: 40, height: 40)) }
        let scaled = box(CGRect(x: 220, y: 230, width: 150, height: 90), .lightGray)
        scaled.contents = red
        scaled.contentsScale = 2
        scaled.contentsGravity = .center
        root.addSublayer(scaled)
        // gravity bottomLeft: Core Animation's bottom is the top edge on iOS (its gravities are y-up)
        let corner = box(CGRect(x: 20, y: 360, width: 150, height: 90), .lightGray)
        corner.contents = red
        corner.contentsScale = 2
        corner.contentsGravity = .bottomLeft
        root.addSublayer(corner)
        // resizeAspect: the 2:1 image fills the width, centred vertically
        let aspect = box(CGRect(x: 220, y: 360, width: 150, height: 90), .lightGray)
        aspect.contents = halves
        aspect.contentsGravity = .resizeAspect
        root.addSublayer(aspect)
        print("contents ready")
    }

    // MARK: text

    func text() {
        let sentence = "The quick brown fox jumps over the lazy dog"
        var layers: [(String, CATextLayer)] = []
        for (i, mode) in [CATextLayerTruncationMode.none, .start, .middle, .end].enumerated() {
            let t = CATextLayer()
            t.frame = CGRect(x: 20, y: 100 + CGFloat(i) * 40, width: 170, height: 24)
            t.string = sentence
            t.fontSize = 17
            t.foregroundColor = UIColor.black.cgColor
            t.truncationMode = mode
            view.layer.addSublayer(t)
            layers.append((mode.rawValue, t))
        }
        let wrapped = CATextLayer()
        wrapped.frame = CGRect(x: 20, y: 280, width: 170, height: 44)                    // two lines of 17 pt text
        wrapped.string = sentence + ", again and again and again"
        wrapped.fontSize = 17
        wrapped.foregroundColor = UIColor.black.cgColor
        wrapped.isWrapped = true
        wrapped.truncationMode = .end
        view.layer.addSublayer(wrapped)
        layers.append(("wrapped", wrapped))
        let rich = CATextLayer()
        rich.frame = CGRect(x: 20, y: 340, width: 170, height: 24)
        rich.string = NSAttributedString(string: sentence, attributes: [.font: UIFont.boldSystemFont(ofSize: 17), .foregroundColor: UIColor.blue])
        rich.truncationMode = .middle
        view.layer.addSublayer(rich)
        layers.append(("attributed", rich))
        report({ layers.allSatisfy { $0.1._isim_drawnString != nil } }) {
            for (name, l) in layers {
                let s = l._isim_drawnString
                print("text \(name): \((s as? NSAttributedString)?.string ?? (s as? String) ?? "-")")
            }
        }
    }

    // MARK: emitter

    func emitter() {
        let dot = bitmap(CGSize(width: 8, height: 8)) { c in c.setFillColor(UIColor.white.cgColor); c.fillEllipse(in: CGRect(x: 0, y: 0, width: 8, height: 8)) }
        // fireworks: red rockets going up, each leaving a trail (white trail cells take the rocket's red and scale)
        let fireworks = CAEmitterLayer()
        fireworks.frame = CGRect(x: 0, y: 0, width: 200, height: 600)
        fireworks.emitterPosition = CGPoint(x: 100, y: 560)
        let rocket = CAEmitterCell()
        rocket.name = "rocket"
        rocket.contents = dot
        rocket.color = UIColor.red.cgColor
        rocket.birthRate = 3
        rocket.lifetime = 2.5
        rocket.velocity = 180
        rocket.emissionLongitude = -.pi / 2
        rocket.emissionRange = .pi / 12
        let trail = CAEmitterCell()
        trail.name = "trail"
        trail.contents = dot
        trail.birthRate = 40
        trail.lifetime = 0.6
        trail.velocity = 20
        trail.emissionRange = .pi
        trail.yAcceleration = 30
        trail.scale = 0.6
        rocket.emitterCells = [trail]
        fireworks.emitterCells = [rocket]
        view.layer.addSublayer(fireworks)
        // emissionLatitude π/2: the particles leave the layer's plane, straight at the viewer, and hardly move on it
        let out = CAEmitterLayer()
        out.frame = CGRect(x: 200, y: 0, width: 202, height: 600)
        out.emitterPosition = CGPoint(x: 100, y: 300)
        let cell = CAEmitterCell()
        cell.name = "out"
        cell.contents = dot
        cell.color = UIColor.blue.cgColor
        cell.birthRate = 30
        cell.lifetime = 3
        cell.velocity = 150
        cell.emissionLatitude = .pi / 2
        out.emitterCells = [cell]
        view.layer.addSublayer(out)
        report(after: 1.2, { fireworks._isim_particleCount(ofCell: "trail") > 0 }) {
            print("emitter rockets>0 \(fireworks._isim_particleCount(ofCell: "rocket") > 0) trails>0 \(fireworks._isim_particleCount(ofCell: "trail") > 0) out>0 \(out._isim_particleCount(ofCell: "out") > 0)")
        }
    }

    // MARK: transform layer

    func transform() {
        // red behind (zPosition -20), blue in front (+20), overlapping; the container turned half a turn about y
        func scene(_ container: CALayer, x: CGFloat) {
            container.frame = CGRect(x: x, y: 120, width: 140, height: 140)
            let back = box(CGRect(x: 10, y: 10, width: 90, height: 90), .red); back.zPosition = -20
            let front = box(CGRect(x: 40, y: 40, width: 90, height: 90), .blue); front.zPosition = 20
            container.addSublayer(back); container.addSublayer(front)
            container.transform = CATransform3DMakeRotation(.pi, 0, 1, 0)
            view.layer.addSublayer(container)
        }
        scene(CALayer(), x: 40)               // flattened: blue stays on top of red, then the picture is turned over
        scene(CATransformLayer(), x: 220)     // a 3D space: turned around, red is now in front
        // a box seen in perspective: front (green), right side (orange) and top (purple) faces
        let stage = CALayer()
        stage.frame = CGRect(x: 100, y: 380, width: 200, height: 200)
        var persp = CATransform3DIdentity; persp.m34 = -1 / 500
        stage.sublayerTransform = persp
        let cube = CATransformLayer()
        cube.frame = stage.bounds
        let s: CGFloat = 100
        func face(_ color: UIColor, _ t: CATransform3D) {
            let f = box(CGRect(x: 50, y: 50, width: s, height: s), color)
            f.transform = t
            cube.addSublayer(f)
        }
        face(.systemGreen, CATransform3DMakeTranslation(0, 0, s / 2))
        face(.systemOrange, CATransform3DRotate(CATransform3DMakeTranslation(s / 2, 0, 0), .pi / 2, 0, 1, 0))
        face(.systemPurple, CATransform3DRotate(CATransform3DMakeTranslation(0, -s / 2, 0), .pi / 2, 1, 0, 0))
        cube.transform = CATransform3DRotate(CATransform3DMakeRotation(-.pi / 7, 0, 1, 0), -.pi / 8, 1, 0, 0)
        stage.addSublayer(cube)
        view.layer.addSublayer(stage)
        print("transform ready")
    }

    // MARK: scroll layer

    func scroll() {
        func quadrants() -> CALayer {
            let content = CALayer()
            content.frame = CGRect(x: 0, y: 0, width: 400, height: 200)
            content.addSublayer(box(CGRect(x: 0, y: 0, width: 200, height: 100), .red))
            content.addSublayer(box(CGRect(x: 200, y: 0, width: 200, height: 100), .green))
            content.addSublayer(box(CGRect(x: 0, y: 100, width: 200, height: 100), .blue))
            content.addSublayer(box(CGRect(x: 200, y: 100, width: 200, height: 100), .orange))
            return content
        }
        func scroller(y: CGFloat) -> CAScrollLayer {
            let s = CAScrollLayer()
            s.frame = CGRect(x: 100, y: y, width: 200, height: 100)
            s.masksToBounds = true
            view.layer.addSublayer(s)
            return s
        }
        let both = scroller(y: 100)
        both.addSublayer(quadrants())
        both.scroll(to: CGPoint(x: 200, y: 100))                                         // the orange quadrant
        let across = scroller(y: 230)
        across.addSublayer(quadrants())
        across.scrollMode = .horizontally
        across.scroll(to: CGPoint(x: 200, y: 100))                                       // y stays: the green one
        let visible = scroller(y: 360)
        let content = quadrants()
        visible.addSublayer(content)
        let target = box(CGRect(x: 300, y: 150, width: 20, height: 20), .black)
        content.addSublayer(target)
        target.scrollRectToVisible(target.bounds)                                         // the least scroll showing it
        let v = content.visibleRect
        func r(_ x: CGFloat) -> Int { Int(x.rounded()) }
        print("scroll origin \(r(visible.bounds.minX)) \(r(visible.bounds.minY)) visibleRect \(r(v.minX)) \(r(v.minY)) \(r(v.width)) \(r(v.height))")
        content.scroll(CGPoint(x: 10, y: 20))                                             // scrollPoint: that point at the origin
        print("scroll point origin \(r(visible.bounds.minX)) \(r(visible.bounds.minY))")
        content.scrollRectToVisible(CGRect(x: 300, y: 150, width: 20, height: 20))
        print("scroll ready")
    }

    // MARK: transition

    func transition() {
        let kinds: [(CATransitionType, CATransitionSubtype?)] = [(.fade, nil), (.push, .fromRight), (.moveIn, .fromTop), (.reveal, .fromLeft)]
        let squares = kinds.enumerated().map { i, _ in box(CGRect(x: 20 + CGFloat(i) * 95, y: 140, width: 80, height: 80), .red) }
        for s in squares { view.layer.addSublayer(s) }
        // once red is on screen: each square turns blue through its transition, paused half-way
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for (s, kind) in zip(squares, kinds) {
                s.speed = 0
                s.timeOffset = 0
                let t = CATransition()
                t.type = kind.0
                t.subtype = kind.1
                t.duration = 1
                s.add(t, forKey: "change")
                s.backgroundColor = UIColor.blue.cgColor
                s.timeOffset = 0.5
            }
            CATransaction.commit()
            print("transition ready")
        }
    }

    // MARK: value functions

    func valueFunctions() {
        func paused(_ frame: CGRect, _ color: UIColor, _ anim: CAAnimation, at t: CFTimeInterval) -> CALayer {
            let l = box(frame, color)
            l.speed = 0
            anim.duration = 1
            l.add(anim, forKey: "vf")
            l.timeOffset = t
            view.layer.addSublayer(l)
            return l
        }
        let rotate = CABasicAnimation(keyPath: "transform")
        rotate.valueFunction = CAValueFunction(name: .rotateZ)
        rotate.fromValue = 0; rotate.toValue = Double.pi / 2
        let bar = paused(CGRect(x: 100, y: 180, width: 200, height: 20), .red, rotate, at: 0.5)        // 45°
        let move = CABasicAnimation(keyPath: "transform")
        move.valueFunction = CAValueFunction(name: .translateX)
        move.fromValue = 0; move.toValue = 100
        let mover = paused(CGRect(x: 20, y: 320, width: 60, height: 60), .blue, move, at: 0.5)          // 50 pt right
        let grow = CABasicAnimation(keyPath: "transform")
        grow.valueFunction = CAValueFunction(name: .scale)
        grow.fromValue = [1, 1, 1]; grow.toValue = [2, 3, 1]
        let grower = paused(CGRect(x: 250, y: 320, width: 40, height: 40), .green, grow, at: 0.5)        // 1.5 x 2
        let spin = CAKeyframeAnimation(keyPath: "transform")
        spin.valueFunction = CAValueFunction(name: .rotateZ)
        spin.values = [0, 1, 3]
        let spinner = paused(CGRect(x: 170, y: 480, width: 60, height: 10), .purple, spin, at: 0.75)    // 2 rad
        report({ bar.presentation() != nil }) {
            func t(_ l: CALayer) -> CATransform3D { l.presentation()?.transform ?? CATransform3DIdentity }
            print("vf rotateZ m11 \(f2(t(bar).m11)) m12 \(f2(t(bar).m12))")
            print("vf translateX m41 \(f2(t(mover).m41))")
            print("vf scale m11 \(f2(t(grower).m11)) m22 \(f2(t(grower).m22)) m33 \(f2(t(grower).m33))")
            print("vf keyframe angle \(f2(atan2(t(spinner).m12, t(spinner).m11)))")
            print("vf model identity \(CATransform3DIsIdentity(bar.transform))")
        }
    }

    // MARK: rasterization, filters

    func raster() {
        // 1 pt black / white stripes
        func stripes(_ frame: CGRect) -> CALayer {
            let l = box(frame, .white)
            for x in stride(from: 0, to: frame.width, by: 2) { l.addSublayer(box(CGRect(x: x, y: 0, width: 1, height: frame.height), .black)) }
            view.layer.addSublayer(l)
            return l
        }
        _ = stripes(CGRect(x: 20, y: 120, width: 160, height: 80))                        // drawn directly
        let coarse = stripes(CGRect(x: 220, y: 120, width: 160, height: 80))             // a bitmap at 1/4 resolution: grey
        coarse.shouldRasterize = true
        coarse.rasterizationScale = 0.25
        let sharp = stripes(CGRect(x: 20, y: 240, width: 160, height: 80))               // at the screen's scale: as drawn
        sharp.shouldRasterize = true
        sharp.rasterizationScale = UIScreen.main.scale
        let faded = stripes(CGRect(x: 220, y: 240, width: 160, height: 80))              // opacity applies to the bitmap
        faded.shouldRasterize = true
        faded.rasterizationScale = UIScreen.main.scale
        faded.opacity = 0.5
        // filters and compositingFilter: not supported on layers in iOS, so stored and not applied
        view.layer.addSublayer(box(CGRect(x: 20, y: 380, width: 360, height: 100), .blue))
        let filtered = box(CGRect(x: 60, y: 400, width: 120, height: 60), .red)
        filtered.filters = [CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 10]) as Any]
        view.layer.addSublayer(filtered)
        let multiplied = box(CGRect(x: 220, y: 400, width: 120, height: 60), .red)
        multiplied.compositingFilter = "multiplyBlendMode"
        view.layer.addSublayer(multiplied)
        print("raster ready filters \(filtered.filters?.count ?? 0) compositing \(multiplied.compositingFilter as? String ?? "-")")
    }

    /// Calls `then` once `ready` holds (checked each frame, from `after` seconds on).
    func report(after delay: TimeInterval = 0, _ ready: @escaping () -> Bool, then: @escaping () -> Void) {
        let start = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] t in
            guard Date().timeIntervalSince(start) >= delay, ready() else { return }
            t.invalidate(); self?.timer = nil
            then()
        }
    }
}
