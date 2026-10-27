// isim Vision: tracking, image registration and optical flow (issue #373), isim's own CPU algorithms (adapted):
//   - VNTrackObjectRequest / VNTrackRectangleRequest: the object's patch in the previous frame is found again in the
//     next one by normalized cross-correlation over a search window around it (translation only: the box keeps its
//     size; a rectangle's corners move with it). The confidence is the correlation.
//   - VNTranslationalImageRegistrationRequest: the shift between the two images, by sum-of-squared-differences search
//     on an image pyramid; VNHomographicImageRegistrationRequest refines it into a homography by Gauss–Newton
//     (Lucas–Kanade) over the pixels. The targeted image is the floating image, the handler's image the reference.
//   - VNGenerateOpticalFlowRequest: dense pyramidal block matching with subpixel refinement; each output pixel is the motion (dx, dy) in pixels
//     of the output, rows top first, y down, of the targeted image's content to the handler's image.
//   - the VNTrack…Request forms (iOS 17) are the same between a VNSequenceRequestHandler's consecutive frames.
// The state of a stateful request lives in the request, so a request should be performed by one sequence handler.
import UIKit
import CoreImage
import simd

/// Requests that see the whole frame (the region of interest does not crop it).
protocol _VNWholeFrame {}

// MARK: - stateful and tracking requests

@objc(VNStatefulRequest) open class VNStatefulRequest: VNImageBasedRequest, _VNWholeFrame, @unchecked Sendable {
    /// how often frames are analysed (isim analyses every frame it is given)
    public let frameAnalysisSpacing: CMTime
    /// the frames needed before the first result
    @objc open var minimumLatencyFrameCount: Int { 1 }
    public init(frameAnalysisSpacing: CMTime, completionHandler: VNRequestCompletionHandler?) {
        self.frameAnalysisSpacing = frameAnalysisSpacing
        super.init(completionHandler: completionHandler)
    }
    @objc public override convenience init() { self.init(frameAnalysisSpacing: .zero, completionHandler: nil) }
    @objc public override convenience init(completionHandler: VNRequestCompletionHandler?) { self.init(frameAnalysisSpacing: .zero, completionHandler: completionHandler) }
    /// the previous frame, for the VNTrack… forms
    var _previous: _VNImage?
}

@objc public enum VNRequestTrackingLevel: UInt, Sendable { case accurate = 0, fast = 1 }

@objc(VNTrackingRequest) open class VNTrackingRequest: VNImageBasedRequest, _VNWholeFrame, @unchecked Sendable {
    /// the object to track: set it to the last result to go on from there (or to a new box to start again)
    @objc open var inputObservation: VNDetectedObjectObservation { didSet { _restart = true } }
    @objc open var trackingLevel: VNRequestTrackingLevel = .accurate
    /// true on the last frame: the tracker's state is released after it
    @objc open var isLastFrame: Bool {
        @objc(isLastFrame) get { _lastFrame }
        @objc(setLastFrame:) set { _lastFrame = newValue }
    }
    var _lastFrame = false
    var _restart = true
    var _gray: _VNGray?
    var _last: VNDetectedObjectObservation?
    init(observation: VNDetectedObjectObservation, completionHandler: VNRequestCompletionHandler?) {
        inputObservation = observation
        super.init(completionHandler: completionHandler)
    }
    /// how many trackers of this kind can run at once
    @objc(supportedNumberOfTrackersAndReturnError:) open func supportedNumber(ofTrackersAndReturnError error: NSErrorPointer) -> Int { 16 }

    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let gray = _VNGray(img, maxSide: trackingLevel == .fast ? 192 : 320)
        let from = (!_restart ? _last : nil) ?? inputObservation, start = from.boundingBox
        guard start.width > 0, start.height > 0, start.minX < 1, start.minY < 1, start.maxX > 0, start.maxY > 0 else {
            throw _vnError(.invalidArgument, "the input observation's bounding box is empty or outside the image")
        }
        var dx = 0.0, dy = 0.0, score: Float = 1
        if let prev = _gray, prev.width == gray.width, prev.height == gray.height {
            (dx, dy, score) = _vnTrack(prev, start, gray)
        }
        let o = _moved(from, by: dx, dy)
        o._uuid = inputObservation.uuid
        o.confidence = max(0, min(1, score))
        _restart = false
        if isLastFrame { _gray = nil; _last = nil } else { _gray = gray; _last = o }
        return [o]
    }
    /// `from` moved by (dx, dy), normalized, y up
    func _moved(_ from: VNDetectedObjectObservation, by dx: Double, _ dy: Double) -> VNDetectedObjectObservation {
        VNDetectedObjectObservation(boundingBox: from.boundingBox.offsetBy(dx: dx, dy: dy))
    }
}

@objc(VNTrackObjectRequest) open class VNTrackObjectRequest: VNTrackingRequest, @unchecked Sendable {
    @objc(initWithDetectedObjectObservation:) public init(detectedObjectObservation observation: VNDetectedObjectObservation) {
        super.init(observation: observation, completionHandler: nil)
    }
    @objc(initWithDetectedObjectObservation:completionHandler:)
    public init(detectedObjectObservation observation: VNDetectedObjectObservation, completionHandler: VNRequestCompletionHandler?) {
        super.init(observation: observation, completionHandler: completionHandler)
    }
}

@objc(VNTrackRectangleRequest) open class VNTrackRectangleRequest: VNTrackingRequest, @unchecked Sendable {
    @objc(initWithRectangleObservation:) public convenience init(rectangleObservation observation: VNRectangleObservation) {
        self.init(rectangleObservation: observation, completionHandler: nil)
    }
    @objc(initWithRectangleObservation:completionHandler:)
    public init(rectangleObservation observation: VNRectangleObservation, completionHandler: VNRequestCompletionHandler?) {
        super.init(observation: observation, completionHandler: completionHandler)
    }
    override func _moved(_ base: VNDetectedObjectObservation, by dx: Double, _ dy: Double) -> VNDetectedObjectObservation {
        let from = base as? VNRectangleObservation ?? VNRectangleObservation(boundingBox: base.boundingBox)
        let o = VNRectangleObservation(boundingBox: from.boundingBox.offsetBy(dx: dx, dy: dy))
        func m(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + dx, y: p.y + dy) }
        o._topLeft = m(from.topLeft); o._topRight = m(from.topRight); o._bottomLeft = m(from.bottomLeft); o._bottomRight = m(from.bottomRight)
        return o
    }
}

/// Where the patch `box` (normalized, y up) of `prev` is in `cur`: the move (normalized, y up) and the correlation.
func _vnTrack(_ prev: _VNGray, _ box: CGRect, _ cur: _VNGray) -> (Double, Double, Float) {
    let W = prev.width, H = prev.height
    let x0 = max(0, Int((box.minX * Double(W)).rounded())), x1 = min(W, Int((box.maxX * Double(W)).rounded()))
    let y0 = max(0, Int(((1 - box.maxY) * Double(H)).rounded())), y1 = min(H, Int(((1 - box.minY) * Double(H)).rounded()))
    guard x1 - x0 >= 2, y1 - y0 >= 2 else { return (0, 0, 0) }
    /* the template: up to 32 x 32 samples of the patch, zero mean */
    let nx = min(32, x1 - x0), ny = min(32, y1 - y0)
    var pts: [(Int, Int)] = [], t: [Float] = []
    for j in 0..<ny { for i in 0..<nx {
        let x = x0 + i * (x1 - x0 - 1) / max(1, nx - 1), y = y0 + j * (y1 - y0 - 1) / max(1, ny - 1)
        pts.append((x, y)); t.append(prev[x, y])
    } }
    let tm = t.reduce(0, +) / Float(t.count)
    for k in t.indices { t[k] -= tm }
    let tn = t.reduce(0) { $0 + $1 * $1 }.squareRoot()
    func score(_ dx: Int, _ dy: Int) -> Float {
        var c = [Float](repeating: 0, count: pts.count), m: Float = 0
        for (k, p) in pts.enumerated() {
            let v = cur[min(W - 1, max(0, p.0 + dx)), min(H - 1, max(0, p.1 + dy))]
            c[k] = v; m += v
        }
        m /= Float(c.count)
        var dot: Float = 0, cn: Float = 0
        for k in c.indices { let v = c[k] - m; dot += v * t[k]; cn += v * v }
        if tn < 1e-4 || cn < 1e-4 { return tn < 1e-4 && cn < 1e-4 ? 1 : 0 }   // flat patches match flat places
        return dot / (tn * cn.squareRoot())
    }
    let R = max(6, Int(Double(max(x1 - x0, y1 - y0)) * 0.75)), step = max(1, R / 10)
    var best = (0, 0, score(0, 0))
    for dy in stride(from: -R, through: R, by: step) { for dx in stride(from: -R, through: R, by: step) {
        let s = score(dx, dy)
        if s > best.2 + 1e-5 || (abs(s - best.2) <= 1e-5 && abs(dx) + abs(dy) < abs(best.0) + abs(best.1)) { best = (dx, dy, s) }
    } }
    var refined = best
    for dy in (best.1 - step)...(best.1 + step) { for dx in (best.0 - step)...(best.0 + step) {
        let s = score(dx, dy)
        if s > refined.2 + 1e-5 { refined = (dx, dy, s) }
    } }
    return (Double(refined.0) / Double(W), -Double(refined.1) / Double(H), refined.2)
}

// MARK: - targeted requests

@objc(VNTargetedImageRequest) open class VNTargetedImageRequest: VNImageBasedRequest, @unchecked Sendable {
    let _loadTarget: () -> _VNImage?
    let _targetOrientation: CGImagePropertyOrientation
    init(_ load: @escaping () -> _VNImage?, _ orientation: CGImagePropertyOrientation, _ completionHandler: VNRequestCompletionHandler?) {
        _loadTarget = load; _targetOrientation = orientation
        super.init(completionHandler: completionHandler)
    }
    public convenience init(targetedCGImage cgImage: CGImage, options: [VNImageOption: Any] = [:], completionHandler: VNRequestCompletionHandler? = nil) {
        self.init(targetedCGImage: cgImage, orientation: .up, options: options, completionHandler: completionHandler)
    }
    public convenience init(targetedCGImage cgImage: CGImage, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:],
                            completionHandler: VNRequestCompletionHandler? = nil) {
        self.init({ _VNImage.from(cgImage: cgImage) }, orientation, completionHandler)
    }
    public convenience init(targetedCIImage ciImage: CIImage, options: [VNImageOption: Any] = [:], completionHandler: VNRequestCompletionHandler? = nil) {
        self.init(targetedCIImage: ciImage, orientation: .up, options: options, completionHandler: completionHandler)
    }
    public convenience init(targetedCIImage ciImage: CIImage, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:],
                            completionHandler: VNRequestCompletionHandler? = nil) {
        self.init({ CIContext().createCGImage(ciImage, from: ciImage.extent).flatMap(_VNImage.from(cgImage:)) }, orientation, completionHandler)
    }
    public convenience init(targetedCVPixelBuffer pixelBuffer: CVPixelBuffer, options: [VNImageOption: Any] = [:], completionHandler: VNRequestCompletionHandler? = nil) {
        self.init(targetedCVPixelBuffer: pixelBuffer, orientation: .up, options: options, completionHandler: completionHandler)
    }
    public convenience init(targetedCVPixelBuffer pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:],
                            completionHandler: VNRequestCompletionHandler? = nil) {
        self.init({ _VNImage(width: pixelBuffer._width, height: pixelBuffer._height, bgra: pixelBuffer._bgra()) }, orientation, completionHandler)
    }
    public convenience init(targetedCMSampleBuffer sampleBuffer: CMSampleBuffer, options: [VNImageOption: Any] = [:], completionHandler: VNRequestCompletionHandler? = nil) {
        self.init(targetedCMSampleBuffer: sampleBuffer, orientation: .up, options: options, completionHandler: completionHandler)
    }
    public convenience init(targetedCMSampleBuffer sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:],
                            completionHandler: VNRequestCompletionHandler? = nil) {
        self.init({ sampleBuffer.imageBuffer.map { _VNImage(width: $0._width, height: $0._height, bgra: $0._bgra()) } }, orientation, completionHandler)
    }
    public convenience init(targetedImageURL imageURL: URL, options: [VNImageOption: Any] = [:], completionHandler: VNRequestCompletionHandler? = nil) {
        self.init(targetedImageURL: imageURL, orientation: .up, options: options, completionHandler: completionHandler)
    }
    public convenience init(targetedImageURL imageURL: URL, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:],
                            completionHandler: VNRequestCompletionHandler? = nil) {
        self.init({ (try? Data(contentsOf: imageURL)).flatMap(_VNImage.from(data:)) }, orientation, completionHandler)
    }
    public convenience init(targetedImageData imageData: Data, options: [VNImageOption: Any] = [:], completionHandler: VNRequestCompletionHandler? = nil) {
        self.init(targetedImageData: imageData, orientation: .up, options: options, completionHandler: completionHandler)
    }
    public convenience init(targetedImageData imageData: Data, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:],
                            completionHandler: VNRequestCompletionHandler? = nil) {
        self.init({ _VNImage.from(data: imageData) }, orientation, completionHandler)
    }
    /// the targeted image, upright, cropped like the handler's image
    func _target() throws -> _VNImage {
        guard let t = _loadTarget() else { throw _vnError(.invalidImage, "the targeted image could not be read") }
        return t.oriented(_targetOrientation).cropped(regionOfInterest).0
    }
}

@objc(VNImageRegistrationRequest) open class VNImageRegistrationRequest: VNTargetedImageRequest, @unchecked Sendable {}

@objc(VNImageAlignmentObservation) open class VNImageAlignmentObservation: VNObservation, @unchecked Sendable {}
@objc(VNImageTranslationAlignmentObservation) open class VNImageTranslationAlignmentObservation: VNImageAlignmentObservation, @unchecked Sendable {
    /// the translation (pixels, lower-left origin) that moves the floating image onto the reference image
    @objc open var alignmentTransform: CGAffineTransform
    init(alignmentTransform: CGAffineTransform) { self.alignmentTransform = alignmentTransform; super.init() }
}
@objc(VNImageHomographicAlignmentObservation) open class VNImageHomographicAlignmentObservation: VNImageAlignmentObservation, @unchecked Sendable {
    /// the homography (pixels, lower-left origin; column-major, applied to (x, y, 1)) that warps the floating image
    /// onto the reference image
    open var warpTransform: matrix_float3x3
    init(warpTransform: matrix_float3x3) { self.warpTransform = warpTransform; super.init() }
}

@objc(VNTranslationalImageRegistrationRequest) open class VNTranslationalImageRegistrationRequest: VNImageRegistrationRequest, @unchecked Sendable {
    override func _run(_ img: _VNImage) throws -> [VNObservation] { [_vnTranslationObservation(reference: img, floating: try _target())] }
}
@objc(VNHomographicImageRegistrationRequest) open class VNHomographicImageRegistrationRequest: VNImageRegistrationRequest, @unchecked Sendable {
    override func _run(_ img: _VNImage) throws -> [VNObservation] { [_vnHomographyObservation(reference: img, floating: try _target())] }
}

@objc(VNTrackTranslationalImageRegistrationRequest) open class VNTrackTranslationalImageRegistrationRequest: VNStatefulRequest, @unchecked Sendable {
    /// the previous frame aligned onto this one (no result for the first frame)
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        defer { _previous = img }
        guard let prev = _previous else { return [] }
        return [_vnTranslationObservation(reference: img, floating: prev)]
    }
}
@objc(VNTrackHomographicImageRegistrationRequest) open class VNTrackHomographicImageRegistrationRequest: VNStatefulRequest, @unchecked Sendable {
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        defer { _previous = img }
        guard let prev = _previous else { return [] }
        return [_vnHomographyObservation(reference: img, floating: prev)]
    }
}

/// a grey image of `img` resampled to w x h (area average)
private func _vnGray(_ img: _VNImage, _ w: Int, _ h: Int) -> _VNGray {
    let g = _VNGray(img)
    if g.width == w && g.height == h { return g }
    return g.resized(w, h)
}
extension _VNGray {
    func resized(_ W: Int, _ H: Int) -> _VNGray {
        var out = [Float](repeating: 0, count: W * H)
        for y in 0..<H {
            let y0 = y * height / H, y1 = max(y0 + 1, (y + 1) * height / H)
            for x in 0..<W {
                let x0 = x * width / W, x1 = max(x0 + 1, (x + 1) * width / W)
                var s: Float = 0
                for sy in y0..<y1 { for sx in x0..<x1 { s += v[sy * width + sx] } }
                out[y * W + x] = s / Float((y1 - y0) * (x1 - x0))
            }
        }
        return _VNGray(width: W, height: H, v: out)
    }
    func half() -> _VNGray { resized(max(1, width / 2), max(1, height / 2)) }
    /// bilinear sample (x, y in pixels; outside: nil)
    func sample(_ x: Float, _ y: Float) -> Float? {
        guard x >= 0, y >= 0, x <= Float(width - 1), y <= Float(height - 1) else { return nil }
        let x0 = min(width - 2, Int(x)), y0 = min(height - 2, Int(y))
        let fx = x - Float(x0), fy = y - Float(y0)
        let a = v[y0 * width + x0], b = v[y0 * width + x0 + 1], c = v[(y0 + 1) * width + x0], d = v[(y0 + 1) * width + x0 + 1]
        return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
    }
}

/// a pyramid, finest first (the finest has its longer side at most `maxSide`)
private func _vnPyramid(_ img: _VNImage, _ w: Int, _ h: Int, minSide: Int = 24) -> [_VNGray] {
    var levels = [_vnGray(img, w, h)]
    while min(levels.last!.width, levels.last!.height) / 2 >= minSide { levels.append(levels.last!.half()) }
    return levels
}
private func _vnSize(_ img: _VNImage, _ maxSide: Int) -> (Int, Int) {
    let s = min(1, Double(maxSide) / Double(max(img.width, img.height)))
    return (max(1, Int((Double(img.width) * s).rounded())), max(1, Int((Double(img.height) * s).rounded())))
}

/// The shift d (finest-level pixels, y down) with floating(p + d) ≈ reference(p).
private func _vnShift(_ ref: [_VNGray], _ flt: [_VNGray]) -> (Int, Int) {
    var d = (0, 0)
    for level in stride(from: ref.count - 1, through: 0, by: -1) {
        let r = ref[level], f = flt[level]
        let coarsest = level == ref.count - 1
        let R = coarsest ? max(2, max(r.width, r.height) / 3) : 2
        if !coarsest { d = (d.0 * 2, d.1 * 2) }
        var best = (d.0, d.1, Float.infinity)
        for dy in (d.1 - R)...(d.1 + R) { for dx in (d.0 - R)...(d.0 + R) {
            let xa = max(0, -dx), xb = min(r.width, f.width - dx), ya = max(0, -dy), yb = min(r.height, f.height - dy)
            guard xb - xa >= r.width / 3, yb - ya >= r.height / 3 else { continue }
            var s: Float = 0
            for y in ya..<yb { for x in xa..<xb { let e = f.v[(y + dy) * f.width + x + dx] - r.v[y * r.width + x]; s += e * e } }
            s /= Float((xb - xa) * (yb - ya))
            if s < best.2 - 1e-7 || (abs(s - best.2) <= 1e-7 && abs(dx) + abs(dy) < abs(best.0) + abs(best.1)) { best = (dx, dy, s) }
        } }
        d = (best.0, best.1)
    }
    return d
}

func _vnTranslationObservation(reference: _VNImage, floating: _VNImage) -> VNImageTranslationAlignmentObservation {
    let (w, h) = _vnSize(reference, 256)
    let d = _vnShift(_vnPyramid(reference, w, h), _vnPyramid(floating, w, h))
    let kx = Double(reference.width) / Double(w), ky = Double(reference.height) / Double(h)
    /* the floating image moved by -d lands on the reference; y up */
    return VNImageTranslationAlignmentObservation(alignmentTransform: CGAffineTransform(translationX: -Double(d.0) * kx, y: Double(d.1) * ky))
}

/// Solves A x = b (n x n, row-major) by Gaussian elimination with partial pivoting.
private func _vnSolve(_ A: [Double], _ b: [Double], _ n: Int) -> [Double]? {
    var a = A, x = b
    for c in 0..<n {
        var p = c
        for r in c + 1..<n where abs(a[r * n + c]) > abs(a[p * n + c]) { p = r }
        guard abs(a[p * n + c]) > 1e-12 else { return nil }
        if p != c { for k in 0..<n { a.swapAt(c * n + k, p * n + k) }; x.swapAt(c, p) }
        for r in 0..<n where r != c {
            let f = a[r * n + c] / a[c * n + c]
            if f == 0 { continue }
            for k in c..<n { a[r * n + k] -= f * a[c * n + k] }
            x[r] -= f * x[c]
        }
    }
    return (0..<n).map { x[$0] / a[$0 * n + $0] }
}

func _vnHomographyObservation(reference: _VNImage, floating: _VNImage) -> VNImageHomographicAlignmentObservation {
    let (w, h) = _vnSize(reference, 256)
    let ref = _vnPyramid(reference, w, h), flt = _vnPyramid(floating, w, h)
    let d = _vnShift(ref, flt)
    /* H maps reference pixels (finest level, y down, centred and scaled by s) to floating ones; starts at the shift */
    let s = Double(max(w, h)) / 2, cx = Double(w) / 2, cy = Double(h) / 2
    var p = [0, 0, Double(d.0) / s, 0, 0, Double(d.1) / s, 0, 0]
    for level in stride(from: min(2, ref.count - 1), through: 0, by: -1) {
        let r = ref[level], f = flt[level], k = Double(1 << level)       // finest pixels per pixel of this level
        let step = max(1, Int((Double(r.width * r.height) / 6000).squareRoot()))
        for _ in 0..<10 {
            var A = [Double](repeating: 0, count: 64), b = [Double](repeating: 0, count: 8), n = 0
            for y in stride(from: 1, to: r.height - 1, by: step) { for x in stride(from: 1, to: r.width - 1, by: step) {
                let u = (Double(x) * k - cx) / s, v = (Double(y) * k - cy) / s
                let a1 = (1 + p[0]) * u + p[1] * v + p[2], b1 = p[3] * u + (1 + p[4]) * v + p[5], c1 = p[6] * u + p[7] * v + 1
                guard abs(c1) > 1e-6 else { continue }
                let wx = a1 / c1, wy = b1 / c1
                let fx = Float((wx * s + cx) / k), fy = Float((wy * s + cy) / k)
                guard let i0 = f.sample(fx, fy), let ixp = f.sample(fx + 1, fy), let ixm = f.sample(fx - 1, fy),
                      let iyp = f.sample(fx, fy + 1), let iym = f.sample(fx, fy - 1) else { continue }
                let e = Double(i0 - r.v[y * r.width + x])
                let gx = Double(ixp - ixm) / 2 * s / k, gy = Double(iyp - iym) / 2 * s / k     // per normalized unit
                let J = [gx * u / c1, gx * v / c1, gx / c1, gy * u / c1, gy * v / c1, gy / c1,
                         -(gx * wx + gy * wy) * u / c1, -(gx * wx + gy * wy) * v / c1]
                for i in 0..<8 { b[i] -= J[i] * e; for j in 0..<8 { A[i * 8 + j] += J[i] * J[j] } }
                n += 1
            } }
            guard n >= 16 else { break }
            for i in 0..<8 { A[i * 9] *= 1.0001; A[i * 9] += 1e-9 }
            guard let delta = _vnSolve(A, b, 8) else { break }
            for i in 0..<8 { p[i] += delta[i] }
            if delta.map(abs).max()! < 1e-5 { break }
        }
    }
    /* reference -> floating in original pixels, y up: F K T Hn T^-1 K^-1 F; the warp is its inverse */
    let kx = Double(reference.width) / Double(w), ky = Double(reference.height) / Double(h), H = Double(reference.height)
    let Hn = simd_double3x3(rows: [SIMD3(1 + p[0], p[1], p[2]), SIMD3(p[3], 1 + p[4], p[5]), SIMD3(p[6], p[7], 1)])
    let T = simd_double3x3(rows: [SIMD3(s * kx, 0, cx * kx), SIMD3(0, s * ky, cy * ky), SIMD3(0, 0, 1)])
    let F = simd_double3x3(rows: [SIMD3(1, 0, 0), SIMD3(0, -1, H), SIMD3(0, 0, 1)])
    var M = (F * T * Hn * T.inverse * F).inverse
    M = M * (1 / M[2][2])
    let m = matrix_float3x3(columns: (SIMD3<Float>(Float(M[0][0]), Float(M[0][1]), Float(M[0][2])),
                                      SIMD3<Float>(Float(M[1][0]), Float(M[1][1]), Float(M[1][2])),
                                      SIMD3<Float>(Float(M[2][0]), Float(M[2][1]), Float(M[2][2]))))
    return VNImageHomographicAlignmentObservation(warpTransform: m)
}

// MARK: - optical flow

@objc(VNGenerateOpticalFlowRequest) open class VNGenerateOpticalFlowRequest: VNTargetedImageRequest, @unchecked Sendable {
    @objc(VNGenerateOpticalFlowRequestComputationAccuracy) public enum ComputationAccuracy: UInt, Sendable { case low = 0, medium = 1, high = 2, veryHigh = 3 }
    /// the size of the flow field: its longer side is 160 (low), 256, 384 or 512 (very high) pixels, or the image's
    @objc open var computationAccuracy: ComputationAccuracy = .medium
    /// kCVPixelFormatType_TwoComponent32Float or kCVPixelFormatType_TwoComponent16Half
    @objc open var outputPixelFormat: OSType = kCVPixelFormatType_TwoComponent32Float
    /// isim has no network: the output is always the flow
    @objc open var keepNetworkOutput = false
    @objc open override class var supportedRevisions: IndexSet { IndexSet([1, 2]) }
    @objc open override class var defaultRevision: Int { 2 }
    @objc open override class var currentRevision: Int { 2 }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        [try _vnFlowObservation(from: try _target(), to: img, accuracy: computationAccuracy.rawValue, format: outputPixelFormat)]
    }
}

@objc(VNTrackOpticalFlowRequest) open class VNTrackOpticalFlowRequest: VNStatefulRequest, @unchecked Sendable {
    @objc(VNTrackOpticalFlowRequestComputationAccuracy) public enum ComputationAccuracy: UInt, Sendable { case low = 0, medium = 1, high = 2, veryHigh = 3 }
    @objc open var computationAccuracy: ComputationAccuracy = .medium
    @objc open var outputPixelFormat: OSType = kCVPixelFormatType_TwoComponent32Float
    @objc open var keepNetworkOutput = false
    /// the flow from the previous frame to this one (no result for the first frame)
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        defer { _previous = img }
        guard let prev = _previous else { return [] }
        return [try _vnFlowObservation(from: prev, to: img, accuracy: computationAccuracy.rawValue, format: outputPixelFormat)]
    }
}

/// box sum of radius r (clamped edges), separable
private func _vnBox(_ a: [Float], _ w: Int, _ h: Int, _ r: Int) -> [Float] {
    var t = [Float](repeating: 0, count: a.count), o = t
    for y in 0..<h { for x in 0..<w { var s: Float = 0; for k in -r...r { s += a[y * w + min(w - 1, max(0, x + k))] }; t[y * w + x] = s } }
    for y in 0..<h { for x in 0..<w { var s: Float = 0; for k in -r...r { s += t[min(h - 1, max(0, y + k)) * w + x] }; o[y * w + x] = s } }
    return o
}

func _vnFlowObservation(from target: _VNImage, to image: _VNImage, accuracy: UInt, format: OSType) throws -> VNPixelBufferObservation {
    guard format == kCVPixelFormatType_TwoComponent32Float || format == kCVPixelFormatType_TwoComponent16Half else {
        throw _vnError(.invalidOption, "the optical flow's output pixel format must be kCVPixelFormatType_TwoComponent32Float or kCVPixelFormatType_TwoComponent16Half")
    }
    let (w, h) = _vnSize(image, [160, 256, 384, 512][Int(min(accuracy, 3))])
    let I1 = _vnPyramid(target, w, h, minSide: 16), I2 = _vnPyramid(image, w, h, minSide: 16)
    /* flow on I2's grid: I2(p) ≈ I1(p - f(p)), from the coarsest level down */
    var u = [Float](repeating: 0, count: I2.last!.width * I2.last!.height), v = u
    for level in stride(from: I2.count - 1, through: 0, by: -1) {
        let a = I1[level], b = I2[level], W = b.width, H = b.height
        if level != I2.count - 1 {      // upsample the coarser flow
            let cw = I2[level + 1].width, ch = I2[level + 1].height
            var nu = [Float](repeating: 0, count: W * H), nv = nu
            for y in 0..<H { for x in 0..<W {
                let i = min(ch - 1, y * ch / H) * cw + min(cw - 1, x * cw / W)
                nu[y * W + x] = u[i] * Float(W) / Float(cw); nv[y * W + x] = v[i] * Float(H) / Float(ch)
            } }
            u = nu; v = nv
        }
        /* block matching around the coarser estimate: for each offset within ±R, the sum of squared differences
           over a (2r+1)² window; the best offset (ties: the smaller change), refined by a parabola through its
           neighbours' costs */
        let R = 3, r = 4, n = 2 * R + 1
        let bu = u.map { Int($0.rounded()) }, bv = v.map { Int($0.rounded()) }
        var costs = [[Float]](repeating: [], count: n * n)
        for j in 0..<n { for i in 0..<n {
            let dx = i - R, dy = j - R
            var d = [Float](repeating: 0, count: W * H)
            for y in 0..<H { for x in 0..<W {
                let k = y * W + x
                let sx = min(W - 1, max(0, x - bu[k] - dx)), sy = min(H - 1, max(0, y - bv[k] - dy))
                let e = b.v[k] - a.v[sy * W + sx]
                d[k] = e * e
            } }
            let penalty = 1e-4 * Float(dx * dx + dy * dy)
            costs[j * n + i] = _vnBox(d, W, H, r).map { $0 + penalty }
        } }
        func para(_ m: Float, _ c: Float, _ p: Float) -> Float {
            let den = m - 2 * c + p
            return den > 1e-6 ? max(-0.5, min(0.5, (m - p) / (2 * den))) : 0
        }
        for k in 0..<(W * H) {
            var best = 0
            for o in 1..<(n * n) where costs[o][k] < costs[best][k] { best = o }
            let j = best / n, i = best % n, c = costs[best][k]
            let fx = i > 0 && i < n - 1 ? para(costs[j * n + i - 1][k], c, costs[j * n + i + 1][k]) : 0
            let fy = j > 0 && j < n - 1 ? para(costs[(j - 1) * n + i][k], c, costs[(j + 1) * n + i][k]) : 0
            u[k] = Float(bu[k] + i - R) + fx
            v[k] = Float(bv[k] + j - R) + fy
        }
    }
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, w, h, format, nil, &pb)
    guard let buffer = pb else { throw _vnError(.outOfMemory, "the optical flow could not be allocated") }
    CVPixelBufferLockBaseAddress(buffer, [])
    if let base = CVPixelBufferGetBaseAddress(buffer) {
        let bpr = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<h { for x in 0..<w {
            let row = base.advanced(by: y * bpr), i = y * w + x
            if format == kCVPixelFormatType_TwoComponent32Float {
                row.storeBytes(of: u[i], toByteOffset: x * 8, as: Float.self); row.storeBytes(of: v[i], toByteOffset: x * 8 + 4, as: Float.self)
            } else {
                row.storeBytes(of: _isimHalf(u[i]), toByteOffset: x * 4, as: UInt16.self)
                row.storeBytes(of: _isimHalf(v[i]), toByteOffset: x * 4 + 2, as: UInt16.self)
            }
        } }
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])
    return VNPixelBufferObservation(pixelBuffer: buffer, featureName: nil)
}
