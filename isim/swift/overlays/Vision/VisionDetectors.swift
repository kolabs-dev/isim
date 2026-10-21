// isim Vision: requests answered by isim's own CPU detectors (adapted, issue #276), not Apple's neural networks:
//   - VNDetectFaceRectanglesRequest / VNDetectFaceLandmarksRequest: Core Image's Viola-Jones detector (CIDetector,
//     OpenCV's Haar cascades from the host's opencv-data); landmarks are a geometric face model placed by the eyes
//     and the mouth it finds. Without the cascades the requests fail with unsupportedRequest.
//   - VNDetectRectanglesRequest: filled quadrilaterals of either polarity (Otsu threshold, connected components,
//     convex hull, the largest inscribed quadrilateral).
//   - VNDetectTextRectanglesRequest: character-like components grouped into words (no OCR).
//   - VNDetectContoursRequest: Suzuki–Abe border following, outer borders and holes nested.
//   - VNDetectHorizonRequest: the dominant near-horizontal edge direction.
//   - VNGenerateAttentionBasedSaliencyImageRequest: frequency-tuned colour saliency with a centre prior.
import UIKit
import CoreImage

// MARK: - faces

/// where CIDetector looks for OpenCV's cascades (frameworks/CoreImage/CIDetector.m, cascade_path)
private let _vnCascadeDirs = ["/usr/share/opencv4/haarcascades", "/usr/share/opencv/haarcascades", "/usr/local/share/opencv4/haarcascades",
                              "/usr/share/OpenCV/haarcascades"]
private func _vnHaveFaceCascade() -> Bool {
    _vnCascadeDirs.contains { FileManager.default.fileExists(atPath: "\($0)/haarcascade_frontalface_default.xml") }
}

extension _VNImage {
    var cgImage: CGImage? {
        var px = bgra
        return px.withUnsafeMutableBytes { p in
            CGContext(data: p.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)?.makeImage()
        }
    }
}

/// faces found by Core Image, normalized (lower-left origin), with their eyes and mouth in image-normalized points
struct _VNFace { var box: CGRect; var leftEye: CGPoint; var rightEye: CGPoint; var mouth: CGPoint }
private func _vnFaces(_ img: _VNImage) throws -> [_VNFace] {
    guard _vnHaveFaceCascade() else {
        throw _vnError(.unsupportedRequest, "face detection needs OpenCV's Haar cascades (the host's opencv-data package); it is not installed")
    }
    guard let cg = img.cgImage,
          let det = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else { return [] }
    let W = Double(img.width), H = Double(img.height)
    func n(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x / W, y: p.y / H) }
    return det.features(in: CIImage(cgImage: cg)).compactMap { $0 as? CIFaceFeature }.map { f in
        _VNFace(box: CGRect(x: f.bounds.minX / W, y: f.bounds.minY / H, width: f.bounds.width / W, height: f.bounds.height / H),
                leftEye: n(f.leftEyePosition), rightEye: n(f.rightEyePosition), mouth: n(f.mouthPosition))
    }
}

@objc(VNDetectFaceRectanglesRequest) @objcMembers open class VNDetectFaceRectanglesRequest: VNImageBasedRequest, @unchecked Sendable {
    open override class var supportedRevisions: IndexSet { IndexSet([2, 3]) }
    open override class var defaultRevision: Int { 3 }
    open override class var currentRevision: Int { 3 }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        try _vnFaces(img).map { f in
            let o = VNFaceObservation(boundingBox: f.box)
            o._roll = NSNumber(value: Double(atan2((f.rightEye.y - f.leftEye.y) * Double(img.height), (f.rightEye.x - f.leftEye.x) * Double(img.width))))
            return o
        }
    }
}
@objc public enum VNRequestFaceLandmarksConstellation: UInt, Sendable { case constellationNotDefined = 0, constellation65Points = 1, constellation76Points = 2 }
@objc(VNDetectFaceLandmarksRequest) @objcMembers open class VNDetectFaceLandmarksRequest: VNImageBasedRequest, @unchecked Sendable {
    /// faces to find landmarks in (from an earlier face request); nil: detect the faces too
    open var inputFaceObservations: [VNFaceObservation]?
    open var constellation: VNRequestFaceLandmarksConstellation = .constellation65Points
    open override class var supportedRevisions: IndexSet { IndexSet([2, 3]) }
    open override class var defaultRevision: Int { 3 }
    open override class var currentRevision: Int { 3 }
    open class func revision(_ requestRevision: Int, supportsConstellation constellation: VNRequestFaceLandmarksConstellation) -> Bool {
        constellation == .constellation65Points || (constellation == .constellation76Points && requestRevision >= 3)
    }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let found = try _vnFaces(img)
        let faces: [(CGRect, _VNFace?)]
        if let inputs = inputFaceObservations {
            /* each given face, with the detected face that overlaps it most (its eyes and mouth), if any */
            faces = inputs.map { o in
                let best = found.max { a, b in a.box.intersection(o.boundingBox).area < b.box.intersection(o.boundingBox).area }
                return (o.boundingBox, best.flatMap { $0.box.intersection(o.boundingBox).area > 0.3 * o.boundingBox.area ? $0 : nil })
            }
        } else {
            faces = found.map { ($0.box, $0) }
        }
        let aspect = Double(img.width) / Double(max(1, img.height))
        return faces.map { box, f in
            let o = VNFaceObservation(boundingBox: box)
            o._landmarks = VNFaceLandmarks2D(box: box, face: f, imageAspect: aspect, points76: constellation == .constellation76Points)
            if let f { o._roll = NSNumber(value: Double(atan2((f.rightEye.y - f.leftEye.y) / aspect, f.rightEye.x - f.leftEye.x))) }
            return o
        }
    }
}
private extension CGRect { var area: CGFloat { isNull ? 0 : width * height } }

@objc(VNFaceLandmarkRegion) @objcMembers open class VNFaceLandmarkRegion: NSObject, @unchecked Sendable {
    open var requestRevision: Int { 3 }
}
@objc public enum VNPointsClassification: Int, Sendable { case disconnected = 0, openPath = 1, closedPath = 2 }
@objc(VNFaceLandmarkRegion2D) @objcMembers open class VNFaceLandmarkRegion2D: VNFaceLandmarkRegion, @unchecked Sendable {
    let _points: [CGPoint], _box: CGRect
    public let pointsClassification: VNPointsClassification
    init(points: [CGPoint], box: CGRect, classification: VNPointsClassification) { _points = points; _box = box; pointsClassification = classification }
    open var pointCount: Int { _points.count }
    /// the points, normalized to the face's bounding box (lower-left origin)
    @nonobjc open var normalizedPoints: [CGPoint] { _points }
    /// the points in an image of `imageSize` (lower-left origin)
    @nonobjc open func pointsInImage(imageSize: CGSize) -> [CGPoint] {
        _points.map { CGPoint(x: (_box.minX + $0.x * _box.width) * imageSize.width, y: (_box.minY + $0.y * _box.height) * imageSize.height) }
    }
    /// isim: a model's points, not measured ones: a nominal precision of a twentieth of the face
    open var precisionEstimatesPerPoint: [NSNumber]? { _points.map { _ in NSNumber(value: 0.05) } }
    /// C copies of the points for Objective-C (ObjC.swift): 0 normalizedPoints, 1 the last pointsInImageOfSize:
    private var _c: [UnsafeMutablePointer<CGPoint>?] = [nil, nil]
    private let _cLock = NSLock()
    func _cPoints(_ slot: Int, _ points: [CGPoint]) -> UnsafeMutablePointer<CGPoint> {
        _cLock.lock(); defer { _cLock.unlock() }
        if slot == 0, let p = _c[0] { return p }
        let p = _c[slot] ?? UnsafeMutablePointer<CGPoint>.allocate(capacity: max(1, _points.count))
        p.initialize(from: points, count: min(points.count, max(1, _points.count)))
        _c[slot] = p
        return p
    }
    deinit { for p in _c { p?.deallocate() } }
}
@objc(VNFaceLandmarks) @objcMembers open class VNFaceLandmarks: NSObject, @unchecked Sendable {
    open var confidence: VNConfidence { _confidence }
    var _confidence: VNConfidence = 0.5
    open var requestRevision: Int { 3 }
}
/// adapted: a geometric face model (eyes, brows, nose, lips, the jaw) placed by the eyes and the mouth Core Image
/// finds, rotated with the eye line; without them, the average face's proportions in the box
@objc(VNFaceLandmarks2D) @objcMembers open class VNFaceLandmarks2D: VNFaceLandmarks, @unchecked Sendable {
    public let allPoints: VNFaceLandmarkRegion2D?
    public let faceContour: VNFaceLandmarkRegion2D?
    public let leftEye: VNFaceLandmarkRegion2D?
    public let rightEye: VNFaceLandmarkRegion2D?
    public let leftEyebrow: VNFaceLandmarkRegion2D?
    public let rightEyebrow: VNFaceLandmarkRegion2D?
    public let nose: VNFaceLandmarkRegion2D?
    public let noseCrest: VNFaceLandmarkRegion2D?
    public let medianLine: VNFaceLandmarkRegion2D?
    public let outerLips: VNFaceLandmarkRegion2D?
    public let innerLips: VNFaceLandmarkRegion2D?
    public let leftPupil: VNFaceLandmarkRegion2D?
    public let rightPupil: VNFaceLandmarkRegion2D?

    init(box: CGRect, face: _VNFace?, imageAspect: Double, points76: Bool) {
        /* face-box coordinates (0...1, lower-left origin); boxes are measured in a square space so circles stay round */
        func local(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - box.minX) / box.width, y: (p.y - box.minY) / box.height) }
        let le = face.map { local($0.leftEye) } ?? CGPoint(x: 0.3, y: 0.62)
        let re = face.map { local($0.rightEye) } ?? CGPoint(x: 0.7, y: 0.62)
        let mo = face.map { local($0.mouth) } ?? CGPoint(x: 0.5, y: 0.22)
        let sx = box.width * imageAspect, sy = box.height                  // face-box units -> a square space
        let ex = (re.x - le.x) * sx, ey = (re.y - le.y) * sy, d = max(1e-6, (ex * ex + ey * ey).squareRoot())
        let u = CGPoint(x: ex / d, y: ey / d), v = CGPoint(x: -u.y, y: u.x)   // along the eye line, and up the face
        /// `origin` + a·u + b·v (a, b in units of the eye distance), back in face-box coordinates
        func at(_ origin: CGPoint, _ a: Double, _ b: Double) -> CGPoint {
            CGPoint(x: origin.x + (a * u.x + b * v.x) * d / sx, y: origin.y + (a * u.y + b * v.y) * d / sy)
        }
        func ellipse(_ c: CGPoint, _ rx: Double, _ ry: Double, _ n: Int, from: Double = 0, to: Double = 2 * .pi, closed: Bool = true) -> [CGPoint] {
            (0..<n).map { i in
                let t = from + (to - from) * Double(i) / Double(closed ? n : n - 1)
                return at(c, rx * cos(t), ry * sin(t))
            }
        }
        let mid = CGPoint(x: (le.x + re.x) / 2, y: (le.y + re.y) / 2)
        let eyeN = points76 ? 8 : 6
        let leftEyePts = ellipse(le, 0.2, 0.08, eyeN), rightEyePts = ellipse(re, 0.2, 0.08, eyeN)
        let browL = ellipse(at(le, 0, 0.12), 0.24, 0.07, points76 ? 6 : 4, from: .pi, to: 0, closed: false)
        let browR = ellipse(at(re, 0, 0.12), 0.24, 0.07, points76 ? 6 : 4, from: .pi, to: 0, closed: false)
        /* the nose tip sits 60% of the way from the eyes to the mouth */
        let mouthDown = ((mid.x - mo.x) * sx * v.x + (mid.y - mo.y) * sy * v.y) / d   // eye line to mouth, in eye distances
        let tip = at(mid, 0, -0.6 * mouthDown)
        let nosePts = [at(tip, -0.18, 0.12), at(tip, -0.12, -0.02), at(tip, 0, -0.06), at(tip, 0.12, -0.02), at(tip, 0.18, 0.12),
                       at(tip, 0.07, 0.35), at(tip, -0.07, 0.35), at(tip, -0.15, 0.22)]
        let crest = (0..<4).map { i in at(mid, 0, -0.6 * mouthDown * Double(i + 1) / 5) }
        let outer = ellipse(mo, 0.4, 0.13, points76 ? 12 : 10), inner = ellipse(mo, 0.28, 0.04, points76 ? 8 : 6)
        let chin = at(mo, 0, -0.55)
        let median = [at(mid, 0, 0.45), mid, tip, mo, chin]
        /* the jaw: the lower half of an ellipse through the temples and the chin */
        let jawCenter = at(mid, 0, -0.1), jawDown = mouthDown + 0.45
        let contour = ellipse(jawCenter, 1.0, jawDown, points76 ? 17 : 11, from: .pi, to: 2 * .pi, closed: false)
        func region(_ p: [CGPoint], _ k: VNPointsClassification) -> VNFaceLandmarkRegion2D { VNFaceLandmarkRegion2D(points: p, box: box, classification: k) }
        leftEye = region(leftEyePts, .closedPath); rightEye = region(rightEyePts, .closedPath)
        leftEyebrow = region(browL, .openPath); rightEyebrow = region(browR, .openPath)
        nose = region(nosePts, .closedPath); noseCrest = region(crest, .openPath); medianLine = region(median, .openPath)
        outerLips = region(outer, .closedPath); innerLips = region(inner, .closedPath)
        leftPupil = region([le], .disconnected); rightPupil = region([re], .disconnected)
        faceContour = region(contour, .openPath)
        allPoints = region(contour + browL + browR + crest + nosePts + leftEyePts + rightEyePts + outer + inner + [le, re], .disconnected)
        super.init()
        _confidence = face == nil ? 0.3 : 0.7
    }
}

// MARK: - rectangles

@objc(VNDetectRectanglesRequest) @objcMembers open class VNDetectRectanglesRequest: VNImageBasedRequest, @unchecked Sendable {
    open var minimumAspectRatio: VNAspectRatio = 0.5
    open var maximumAspectRatio: VNAspectRatio = 1
    /// degrees a corner may differ from 90
    open var quadratureTolerance: VNDegrees = 30
    /// the shorter side, as a fraction of the image's shorter side
    open var minimumSize: Float = 0.2
    open var minimumConfidence: VNConfidence = 0
    /// 0: any number
    open var maximumObservations = 1
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let g = _VNGray(img, maxSide: 480)
        let W = g.width, H = g.height, t = g.otsu()
        var found: [(VNRectangleObservation, CGFloat)] = []
        for dark in [true, false] {
            let mask = g.v.map { dark ? $0 < t : $0 >= t }
            for c in _vnComponents(mask, W, H) where c.count >= 16 && c.borders(W, H) < 3 {
                let hull = c.hull()
                guard let q = _vnQuad(hull) else { continue }
                /* a rectangle fills its quadrilateral, which covers its hull (a disk's inscribed square does not) */
                let area = _vnPolygonArea(q), fill = Double(c.count) / Double(max(1, area))
                guard fill > 0.85, fill < 1.15, area >= 0.92 * _vnPolygonArea(hull) else { continue }
                /* corner angles, sides, and the aspect of opposite sides' averages */
                var worst = 0.0
                for i in 0..<4 {
                    let a = q[(i + 3) % 4], b = q[i], cc = q[(i + 1) % 4]
                    let v1 = CGPoint(x: a.x - b.x, y: a.y - b.y), v2 = CGPoint(x: cc.x - b.x, y: cc.y - b.y)
                    let ang = acos(max(-1, min(1, (v1.x * v2.x + v1.y * v2.y) / max(1e-9, hypot(v1.x, v1.y) * hypot(v2.x, v2.y))))) * 180 / .pi
                    worst = max(worst, abs(ang - 90))
                }
                guard worst <= Double(quadratureTolerance) else { continue }
                func len(_ i: Int) -> Double { hypot(q[i].x - q[(i + 1) % 4].x, q[i].y - q[(i + 1) % 4].y) }
                let s1 = (len(0) + len(2)) / 2, s2 = (len(1) + len(3)) / 2
                let aspect = min(s1, s2) / max(s1, s2, 1e-9)
                guard aspect >= Double(minimumAspectRatio) - 1e-6, aspect <= Double(maximumAspectRatio) + 1e-6,
                      min(s1, s2) >= Double(minimumSize) * Double(min(W, H)) else { continue }
                let conf = Float(max(0, 1 - abs(1 - fill) * 4) * (1 - worst / 90))
                guard conf >= minimumConfidence else { continue }
                found.append((_vnRectangleObservation(q, W, H, confidence: conf), area))
            }
        }
        found.sort { $0.1 > $1.1 }
        return (maximumObservations > 0 ? Array(found.prefix(maximumObservations)) : found).map(\.0)
    }
}
public typealias VNAspectRatio = Float
public typealias VNDegrees = Float

/// the largest quadrilateral on a convex hull: the diameter's ends, and the points farthest from it on each side
func _vnQuad(_ hull: [CGPoint]) -> [CGPoint]? {
    guard hull.count >= 4 else { return nil }
    var ia = 0, ib = 0, best: CGFloat = -1
    for i in 0..<hull.count { for j in (i + 1)..<hull.count {
        let d = hypot(hull[i].x - hull[j].x, hull[i].y - hull[j].y)
        if d > best { best = d; ia = i; ib = j }
    } }
    let a = hull[ia], b = hull[ib]
    var lo = (0, CGFloat(0)), hi = (0, CGFloat(0))
    for (i, p) in hull.enumerated() {
        let s = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
        if s < lo.1 { lo = (i, s) }
        if s > hi.1 { hi = (i, s) }
    }
    guard lo.1 < 0, hi.1 > 0 else { return nil }
    /* refine: each corner moves to the hull point that grows the quadrilateral most, until none does */
    var q = [ia, hi.0, ib, lo.0].sorted()
    var improved = true, rounds = 0
    while improved && rounds < 8 {
        improved = false; rounds += 1
        for k in 0..<4 {
            var bestArea = _vnPolygonArea(q.map { hull[$0] }), bestI = q[k]
            for i in 0..<hull.count where !q.contains(i) {
                var t = q; t[k] = i; t.sort()
                let ar = _vnPolygonArea(t.map { hull[$0] })
                if ar > bestArea + 1e-9 { bestArea = ar; bestI = i }
            }
            if bestI != q[k] { q[k] = bestI; q.sort(); improved = true }
        }
    }
    return q.map { hull[$0] }
}

/// a quadrilateral in pixels (top-left origin) as an observation: corners normalized, lower-left origin
func _vnRectangleObservation(_ q: [CGPoint], _ W: Int, _ H: Int, confidence: Float) -> VNRectangleObservation {
    let n = q.map { CGPoint(x: $0.x / Double(W), y: 1 - $0.y / Double(H)) }
    let byY = n.sorted { $0.y > $1.y }
    let top = byY.prefix(2).sorted { $0.x < $1.x }, bottom = byY.suffix(2).sorted { $0.x < $1.x }
    let box = n.dropFirst().reduce(CGRect(origin: n[0], size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    let o = VNRectangleObservation(boundingBox: box)
    o._topLeft = top[0]; o._topRight = top[1]; o._bottomLeft = bottom[0]; o._bottomRight = bottom[1]
    o.confidence = confidence
    return o
}

// MARK: - text rectangles

@objc(VNDetectTextRectanglesRequest) @objcMembers open class VNDetectTextRectanglesRequest: VNImageBasedRequest, @unchecked Sendable {
    open var reportCharacterBoxes = false
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let g = _VNGray(img, maxSide: 1200)
        let W = g.width, H = g.height, t = g.otsu()
        /* text is the minority polarity */
        let darkCount = g.v.reduce(0) { $0 + ($1 < t ? 1 : 0) }
        let mask = g.v.map { darkCount * 2 <= W * H ? $0 < t : $0 >= t }
        let minH = max(4, H / 100), maxH = Int(Double(H) * 0.6)
        var chars = _vnComponents(mask, W, H).filter { c in
            c.count >= 6 && c.height >= 2 && c.height <= maxH && c.width <= 3 * c.height + 4 && c.borders(W, H) == 0
        }
        /* dots and accents join the character below or above them that they overlap horizontally */
        chars.sort { $0.count > $1.count }
        var merged: [_VNComponent] = []
        for c in chars {
            if let i = merged.firstIndex(where: { m in
                c.count * 3 < m.count && c.minX < m.maxX + 1 && c.maxX > m.minX - 1 &&
                (m.minY - c.maxY <= m.height / 2 + 1 && m.minY - c.maxY >= -1 || c.minY - m.maxY <= m.height / 2 + 1 && c.minY - m.maxY >= -1)
            }) { merged[i].merge(c) } else { merged.append(c) }
        }
        let glyphs = merged.filter { $0.height >= minH }.sorted { $0.minX < $1.minX }
        /* words: glyphs side by side on a line, closer than a third of their height */
        var words: [[_VNComponent]] = []
        for c in glyphs {
            if let i = words.firstIndex(where: { w in
                guard let last = w.last else { return false }
                let top = max(last.minY, c.minY), bottom = min(last.maxY, c.maxY)
                let overlap = Double(bottom - top + 1) / Double(min(last.height, c.height))
                let hRatio = Double(max(last.height, c.height)) / Double(min(last.height, c.height))
                let lineH = w.map(\.height).max() ?? c.height
                return overlap >= 0.5 && hRatio <= 2.5 && c.minX - last.maxX <= max(2, lineH / 3) && c.minX >= last.minX
            }) { words[i].append(c) } else { words.append([c]) }
        }
        func norm(_ r: CGRect) -> CGRect {
            CGRect(x: r.minX / Double(W), y: 1 - r.maxY / Double(H), width: r.width / Double(W), height: r.height / Double(H))
        }
        return words.filter { $0.count >= 2 || ($0.first.map { $0.height >= 8 } ?? false) }
            .sorted { a, b in a[0].minY != b[0].minY ? a[0].minY < b[0].minY : a[0].minX < b[0].minX }
            .map { w in
                let box = w.dropFirst().reduce(w[0].box) { $0.union($1.box) }
                let o = VNTextObservation(boundingBox: norm(box))
                if reportCharacterBoxes { o._characterBoxes = w.map { VNRectangleObservation(boundingBox: norm($0.box)) } }
                return o
            }
    }
}

// MARK: - contours

@objc(VNDetectContoursRequest) @objcMembers open class VNDetectContoursRequest: VNImageBasedRequest, @unchecked Sendable {
    open var contrastAdjustment: Float = 2
    /// the grey level that separates the two sides (0...1); nil: Otsu's threshold of the image
    open var contrastPivot: NSNumber? = 0.5
    open var detectsDarkOnLight = true
    @available(*, deprecated, renamed: "detectsDarkOnLight")
    open var detectDarkOnLight: Bool { get { detectsDarkOnLight } set { detectsDarkOnLight = newValue } }
    open var maximumImageDimension = 512
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let g = _VNGray(img, maxSide: max(16, maximumImageDimension))
        /* contrast about the pivot, then the pivot divides the two sides (adapted: a hard threshold; the contrast
           adjustment only decides which side mid-tones near the pivot fall on) */
        let pivot = contrastPivot.map { Float(truncating: $0) } ?? g.otsu(), k = max(0.01, contrastAdjustment)
        let mask = g.v.map { v -> Bool in
            let a = min(1, max(0, (v - pivot) * k + pivot))
            return detectsDarkOnLight ? a < pivot : a > pivot
        }
        return [VNContoursObservation(_vnFindContours(mask, g.width, g.height), width: g.width, height: g.height)]
    }
}

/// a border from Suzuki–Abe border following: its pixels (top-left origin), whether it is a hole, and its parent
struct _VNBorder { var points: [SIMD2<Int32>]; var isHole: Bool; var parent: Int }

/// Suzuki & Abe (1985): every border of the mask's 8-connected components and holes, with the hierarchy
/// (index 0 is the frame); points compressed to the ends of straight runs
func _vnFindContours(_ mask: [Bool], _ w: Int, _ h: Int) -> [_VNBorder] {
    let W = w + 2, H = h + 2
    var f = [Int32](repeating: 0, count: W * H)
    for y in 0..<h { for x in 0..<w where mask[y * w + x] { f[(y + 1) * W + x + 1] = 1 } }
    /* neighbours clockwise on screen, starting to the right */
    let dx: [Int] = [1, 1, 0, -1, -1, -1, 0, 1], dy: [Int] = [0, 1, 1, 1, 0, -1, -1, -1]
    func dir(_ fx: Int, _ fy: Int, _ tx: Int, _ ty: Int) -> Int {
        for k in 0..<8 where fx + dx[k] == tx && fy + dy[k] == ty { return k }
        return 0
    }
    var borders = [_VNBorder(points: [], isHole: true, parent: -1)]       // the frame
    var nbd: Int32 = 1
    for y in 1..<(H - 1) {
        var lnbd: Int32 = 1
        for x in 1..<(W - 1) {
            let fij = f[y * W + x]
            var start: (Int, Int)? = nil, hole = false
            if fij == 1 && f[y * W + x - 1] == 0 { start = (x - 1, y) }
            else if fij >= 1 && f[y * W + x + 1] == 0 { start = (x + 1, y); hole = true; if fij > 1 { lnbd = fij } }
            if let (x2s, y2s) = start {
                nbd += 1
                let lb = borders[Int(lnbd) - 1]
                let parent = hole == lb.isHole ? lb.parent : Int(lnbd) - 1
                var pts: [SIMD2<Int32>] = []
                /* 3.1: clockwise from (x2, y2) for a non-zero neighbour */
                let d0 = dir(x, y, x2s, y2s)
                var found = -1
                for k in 0..<8 { let d = (d0 + k) % 8; if f[(y + dy[d]) * W + x + dx[d]] != 0 { found = d; break } }
                if found < 0 {
                    f[y * W + x] = -nbd
                    pts.append(SIMD2(Int32(x - 1), Int32(y - 1)))
                } else {
                    let x1 = x + dx[found], y1 = y + dy[found]
                    var x2 = x1, y2 = y1, x3 = x, y3 = y
                    while true {
                        /* 3.3: counterclockwise around (x3, y3), starting after (x2, y2) */
                        let dStart = dir(x3, y3, x2, y2)
                        var x4 = x3, y4 = y3, rightZeroExamined = false
                        for k in 1...8 {
                            let d = (dStart - k + 8) % 8
                            let nx = x3 + dx[d], ny = y3 + dy[d]
                            if f[ny * W + nx] != 0 { x4 = nx; y4 = ny; break }
                            if d == 0 { rightZeroExamined = true }
                        }
                        /* 3.4 */
                        if rightZeroExamined { f[y3 * W + x3] = -nbd } else if f[y3 * W + x3] == 1 { f[y3 * W + x3] = nbd }
                        pts.append(SIMD2(Int32(x3 - 1), Int32(y3 - 1)))
                        /* 3.5 */
                        if x4 == x && y4 == y && x3 == x1 && y3 == y1 { break }
                        x2 = x3; y2 = y3; x3 = x4; y3 = y4
                    }
                }
                borders.append(_VNBorder(points: _vnCompressChain(pts), isHole: hole, parent: parent))
            }
            let v = f[y * W + x]
            if v != 0 && v != 1 { lnbd = abs(v) }
        }
    }
    return borders
}
/// drops the points in the middle of straight runs
func _vnCompressChain(_ p: [SIMD2<Int32>]) -> [SIMD2<Int32>] {
    guard p.count > 2 else { return p }
    var out: [SIMD2<Int32>] = []
    for i in 0..<p.count {
        let a = p[(i + p.count - 1) % p.count], b = p[i], c = p[(i + 1) % p.count]
        if b &- a != c &- b { out.append(b) }
    }
    return out.isEmpty ? [p[0]] : out
}

@objc(VNContour) @objcMembers open class VNContour: NSObject, NSCopying, @unchecked Sendable {
    public let indexPath: IndexPath
    @nonobjc public let normalizedPoints: [SIMD2<Float>]
    let _children: [VNContour]
    /// width / height of the image the points are normalized to
    public let aspectRatio: Float
    init(indexPath: IndexPath, points: [SIMD2<Float>], children: [VNContour], aspectRatio: Float) {
        self.indexPath = indexPath; normalizedPoints = points; _children = children; self.aspectRatio = aspectRatio
    }
    public func copy(with zone: NSZone? = nil) -> Any { self }
    var _cPoints: UnsafeMutablePointer<SIMD2<Float>>?   // normalizedPoints for Objective-C (ObjC.swift)
    let _lock = NSLock()
    deinit { _cPoints?.deallocate() }
    open var requestRevision: Int { 1 }
    open var pointCount: Int { normalizedPoints.count }
    open var childContourCount: Int { _children.count }
    open var childContours: [VNContour] { _children }
    @objc(childContourAtIndex:error:) open func childContour(at childContourIndex: Int) throws -> VNContour {
        guard _children.indices.contains(childContourIndex) else { throw _vnError(.outOfBoundsError, "no child contour \(childContourIndex)") }
        return _children[childContourIndex]
    }
    open var normalizedPath: CGPath {
        let p = CGMutablePath()
        if let f = normalizedPoints.first {
            p.move(to: CGPoint(x: Double(f.x), y: Double(f.y)))
            for q in normalizedPoints.dropFirst() { p.addLine(to: CGPoint(x: Double(q.x), y: Double(q.y))) }
            p.closeSubpath()
        }
        return p
    }
    /// Douglas–Peucker with `epsilon` in normalized units
    open func polygonApproximation(epsilon: Float) throws -> VNContour {
        VNContour(indexPath: indexPath, points: _vnSimplifyClosed(normalizedPoints, epsilon: epsilon), children: _children, aspectRatio: aspectRatio)
    }
}
@objc(VNContoursObservation) @objcMembers open class VNContoursObservation: VNObservation, @unchecked Sendable {
    public let topLevelContours: [VNContour]
    let _all: [VNContour]
    init(_ borders: [_VNBorder], width: Int, height: Int) {
        let aspect = Float(width) / Float(max(1, height))
        var children = [[Int]](repeating: [], count: borders.count)
        for (i, b) in borders.enumerated() where i > 0 && b.parent >= 0 { children[b.parent].append(i) }
        var all: [VNContour] = []
        func make(_ i: Int, _ path: IndexPath) -> VNContour {
            let kids = children[i].enumerated().map { make($0.element, path.appending($0.offset)) }
            let pts = borders[i].points.map { SIMD2<Float>((Float($0.x) + 0.5) / Float(width), 1 - (Float($0.y) + 0.5) / Float(height)) }
            let c = VNContour(indexPath: path, points: pts, children: kids, aspectRatio: aspect)
            all.append(c)
            return c
        }
        topLevelContours = children[0].enumerated().map { make($0.element, IndexPath(index: $0.offset)) }
        _all = all
        super.init()
    }
    open var contourCount: Int { _all.count }
    open var topLevelContourCount: Int { topLevelContours.count }
    /// every contour, depth first (children before their parent, as found)
    @objc(contourAtIndex:error:) open func contour(at contourIndex: Int) throws -> VNContour {
        guard _all.indices.contains(contourIndex) else { throw _vnError(.outOfBoundsError, "no contour \(contourIndex)") }
        return _all[contourIndex]
    }
    @objc(contourAtIndexPath:error:) open func contour(at indexPath: IndexPath) throws -> VNContour {
        guard let first = indexPath.first, topLevelContours.indices.contains(first) else { throw _vnError(.outOfBoundsError, "no contour at \(indexPath)") }
        var c = topLevelContours[first]
        for i in indexPath.dropFirst() { c = try c.childContour(at: i) }
        return c
    }
    open var normalizedPath: CGPath {
        let p = CGMutablePath()
        for c in _all { p.addPath(c.normalizedPath) }
        return p
    }
}

// MARK: - horizon

@objc(VNDetectHorizonRequest) @objcMembers open class VNDetectHorizonRequest: VNImageBasedRequest, @unchecked Sendable {
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let g0 = _VNGray(img, maxSide: 320)
        let W = g0.width, H = g0.height
        guard W > 6, H > 6 else { return [] }
        /* a light 3x3 blur, then Sobel gradients; a line runs perpendicular to its gradient */
        var b = g0.v
        for y in 1..<(H - 1) { for x in 1..<(W - 1) {
            var sum: Float = 0
            for yy in (y - 1)...(y + 1) { for xx in (x - 1)...(x + 1) { sum += g0.v[yy * W + xx] } }
            b[y * W + x] = sum / 9
        } }
        let g = _VNGray(width: W, height: H, v: b)
        var gxs = [Float](repeating: 0, count: W * H), gys = gxs
        /* histogram of the line directions within 45 degrees of horizontal, weighted by the gradient's magnitude,
           in quarter degrees (Vision's y-up space: counterclockwise positive) */
        var hist = [Double](repeating: 0, count: 361), total = 0.0
        for y in 2..<(H - 2) {
            for x in 2..<(W - 2) {
                let gx = (g[x + 1, y - 1] + 2 * g[x + 1, y] + g[x + 1, y + 1]) - (g[x - 1, y - 1] + 2 * g[x - 1, y] + g[x - 1, y + 1])
                let gy = (g[x - 1, y + 1] + 2 * g[x, y + 1] + g[x + 1, y + 1]) - (g[x - 1, y - 1] + 2 * g[x, y - 1] + g[x + 1, y - 1])
                gxs[y * W + x] = gx; gys[y * W + x] = gy
                let m = Double((gx * gx + gy * gy).squareRoot())
                if m < 0.05 { continue }
                total += m
                guard abs(gy) >= abs(gx) else { continue }
                hist[Int(((atan(Double(gx / gy)) * 180 / .pi + 45) * 4).rounded())] += m
            }
        }
        guard total > 0 else { return [] }
        var smooth = hist
        for i in 0..<hist.count { smooth[i] = (max(0, i - 4)...min(hist.count - 1, i + 4)).reduce(0) { $0 + hist[$1] } }
        guard let peak = smooth.indices.max(by: { smooth[$0] < smooth[$1] }), smooth[peak] > 0.15 * total else { return [] }
        /* refine: the gradient structure tensor of the edge pixels within 4 degrees of the peak */
        let peakDeg = Double(peak) / 4 - 45
        var sxx = 0.0, syy = 0.0, sxy = 0.0
        for i in 0..<(W * H) {
            let gx = Double(gxs[i]), gy = Double(gys[i])
            guard gx * gx + gy * gy >= 0.0025, abs(gy) >= abs(gx), abs(atan(gx / gy) * 180 / .pi - peakDeg) <= 4 else { continue }
            sxx += gx * gx; syy += gy * gy; sxy += gx * gy
        }
        /* the dominant gradient direction is 0.5 atan2(2 sxy, sxx - syy) from the x axis (screen space); the line is
           perpendicular to it, and flipping y turns the screen's clockwise angle into Vision's counterclockwise one */
        let gradient = 0.5 * atan2(2 * sxy, sxx - syy)
        var line = gradient - .pi / 2
        while line <= -.pi / 2 { line += .pi }
        while line > .pi / 2 { line -= .pi }
        let degrees = -line * 180 / .pi
        return [VNHorizonObservation(angle: degrees * .pi / 180, aspect: Double(W) / Double(H))]
    }
}
@objc(VNHorizonObservation) @objcMembers open class VNHorizonObservation: VNObservation, @unchecked Sendable {
    /// radians, counterclockwise from horizontal
    public let angle: CGFloat
    let _aspect: Double
    init(angle: CGFloat, aspect: Double) { self.angle = angle; _aspect = aspect; super.init() }
    /// the rotation that levels the horizon, about the normalized image's center
    open var transform: CGAffineTransform {
        CGAffineTransform(translationX: 0.5, y: 0.5).rotated(by: -angle).translatedBy(x: -0.5, y: -0.5)
    }
    /// the rotation that levels the horizon in an image of that size (pixels), about its center
    open func transform(forImageWidth width: Int, height: Int) -> CGAffineTransform {
        CGAffineTransform(translationX: Double(width) / 2, y: Double(height) / 2).rotated(by: -angle).translatedBy(x: -Double(width) / 2, y: -Double(height) / 2)
    }
}

// MARK: - saliency

@objc(VNPixelBufferObservation) @objcMembers open class VNPixelBufferObservation: VNObservation, @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let featureName: String?
    init(pixelBuffer: CVPixelBuffer, featureName: String?) { self.pixelBuffer = pixelBuffer; self.featureName = featureName; super.init() }
}
@objc(VNSaliencyImageObservation) @objcMembers open class VNSaliencyImageObservation: VNPixelBufferObservation, @unchecked Sendable {
    let _objects: [VNRectangleObservation]
    init(pixelBuffer: CVPixelBuffer, objects: [VNRectangleObservation]) { _objects = objects; super.init(pixelBuffer: pixelBuffer, featureName: nil) }
    open var salientObjects: [VNRectangleObservation]? { _objects }
}
@objc(VNGenerateAttentionBasedSaliencyImageRequest) @objcMembers open class VNGenerateAttentionBasedSaliencyImageRequest: VNImageBasedRequest, @unchecked Sendable {
    open override class var supportedRevisions: IndexSet { IndexSet([1, 2]) }
    open override class var defaultRevision: Int { 2 }
    open override class var currentRevision: Int { 2 }
    override func _run(_ img: _VNImage) throws -> [VNObservation] {
        let N = 68
        /* the image in CIELAB at 68x68 (area average) */
        var lab = [SIMD3<Float>](repeating: .zero, count: N * N)
        func lin(_ c: Float) -> Float { c <= 0.04045 ? c / 12.92 : Float(Foundation.pow(Double((c + 0.055) / 1.055), 2.4)) }
        func fl(_ t: Float) -> Float { t > 0.008856 ? Float(Foundation.pow(Double(t), 1.0 / 3)) : 7.787 * t + 16 / 116 }
        img.bgra.withUnsafeBufferPointer { p in
            for y in 0..<N {
                let y0 = y * img.height / N, y1 = max(y0 + 1, (y + 1) * img.height / N)
                for x in 0..<N {
                    let x0 = x * img.width / N, x1 = max(x0 + 1, (x + 1) * img.width / N)
                    var rgb = SIMD3<Float>.zero
                    for sy in y0..<y1 { for sx in x0..<x1 {
                        let i = (sy * img.width + sx) * 4, a = 255 - Float(p[i + 3])
                        rgb += SIMD3(Float(p[i + 2]) + a, Float(p[i + 1]) + a, Float(p[i]) + a)
                    } }
                    rgb /= Float((y1 - y0) * (x1 - x0)) * 255
                    let r = lin(rgb.x), g = lin(rgb.y), b = lin(rgb.z)
                    let X = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.9505, Y = 0.2126 * r + 0.7152 * g + 0.0722 * b
                    let Z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.089
                    lab[y * N + x] = SIMD3(116 * fl(Y) - 16, 500 * (fl(X) - fl(Y)), 200 * (fl(Y) - fl(Z)))
                }
            }
        }
        /* frequency-tuned saliency (Achanta et al. 2009): distance from the mean colour, after a light blur, with a
           centre prior for where people look first */
        let mean = lab.reduce(SIMD3<Float>.zero, +) / Float(lab.count)
        var sal = [Float](repeating: 0, count: N * N)
        for y in 0..<N {
            for x in 0..<N {
                var s = SIMD3<Float>.zero, n: Float = 0
                for yy in max(0, y - 1)...min(N - 1, y + 1) { for xx in max(0, x - 1)...min(N - 1, x + 1) { s += lab[yy * N + xx]; n += 1 } }
                let d: SIMD3<Float> = s / n - mean
                let cx: Float = (Float(x) + 0.5) / Float(N) - 0.5, cy: Float = (Float(y) + 0.5) / Float(N) - 0.5
                let dist: Float = (d * d).sum().squareRoot()
                let prior: Float = 0.4 + 0.6 * Float(Foundation.exp(Double(-(cx * cx + cy * cy) / 0.18)))
                sal[y * N + x] = dist * prior
            }
        }
        let top = sal.max() ?? 0
        if top > 0 { for i in sal.indices { sal[i] /= top } }
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, N, N, kCVPixelFormatType_OneComponent32Float, nil, &pb)
        guard let buffer = pb else { throw _vnError(.outOfMemory, "the saliency map could not be allocated") }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let bpr = CVPixelBufferGetBytesPerRow(buffer)
            for y in 0..<N { for x in 0..<N { base.advanced(by: y * bpr + x * 4).storeBytes(of: sal[y * N + x], as: Float.self) } }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        /* salient objects: the regions above half the peak, largest first, each with its mean saliency */
        let regions = _vnComponents(sal.map { $0 >= 0.5 }, N, N).filter { $0.count >= 4 }.sorted { $0.count > $1.count }.prefix(3)
        let objects = regions.map { c -> VNRectangleObservation in
            var sum: Float = 0
            for (y, r) in c.rows { for x in r.0...r.1 { sum += sal[y * N + x] } }
            let o = VNRectangleObservation(boundingBox: CGRect(x: Double(c.minX) / Double(N), y: 1 - Double(c.maxY + 1) / Double(N),
                                                               width: Double(c.width) / Double(N), height: Double(c.height) / Double(N)))
            o.confidence = sum / Float(c.count)
            return o
        }
        return [VNSaliencyImageObservation(pixelBuffer: buffer, objects: Array(objects))]
    }
}
