// Core Image's iOS 18/26 filters and HDR (CoreImageHDRTest.app, issue #380): the new reductions, the maximum scale
// transform, the blurred rounded rectangle and rounded QR code generators, CISystemToneMap, corner smoothness, content
// headroom and average light level, calculateHDRStats, Lab conversion, CIImage(depthData:) and the new constants.
import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}
func near(_ a: Float, _ b: Float, _ tol: Float = 1e-3) -> Bool { abs(a - b) <= tol }

/// no color management: values as computed
let raw = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
func pixels(_ im: CIImage, _ r: CGRect, context: CIContext = raw) -> [Float] {
    var out = [Float](repeating: 0, count: Int(r.width * r.height) * 4)
    out.withUnsafeMutableBytes { context.render(im, toBitmap: $0.baseAddress!, rowBytes: Int(r.width) * 16, bounds: r, format: .RGBAf, colorSpace: nil) }
    return out
}
func pixel(_ im: CIImage, _ x: CGFloat = 0, _ y: CGFloat = 0) -> [Float] { pixels(im, CGRect(x: x, y: y, width: 1, height: 1)) }
func solid(_ r: Float, _ g: Float, _ b: Float, _ a: Float = 1, _ rect: CGRect) -> CIImage {
    CIImage(color: CIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))).cropped(to: rect)
}
/// a float RGBA bitmap (top-down rows) from per-pixel values
func bitmap(_ w: Int, _ h: Int, _ f: (Int, Int) -> [Float]) -> CIImage {
    var px: [Float] = []
    for y in 0..<h { for x in 0..<w { px += f(x, y) } }
    let d = px.withUnsafeBytes { Data($0) }
    return CIImage(bitmapData: d, bytesPerRow: w * 16, size: CGSize(width: w, height: h), format: .RGBAf, colorSpace: nil)
}

@main enum CoreImageHDRTest {
    static func main() {
        guard #available(iOS 26.0, *) else { print("CoreImageHDRTest: needs iOS 26"); exit(1) }
        reductions()
        geometry()
        generators()
        hdr()
        constants()
        print("CoreImageHDRTest: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }

    @available(iOS 26.0, *)
    static func reductions() {
        let back = solid(0, 0, 0, 1, CGRect(x: 0, y: 0, width: 100, height: 100))
        let square = solid(1, 0, 0, 1, CGRect(x: 10, y: 20, width: 30, height: 40)).composited(over: back)
        let b = CIFilter.areaBoundsRed()
        b.inputImage = square; b.extent = square.extent
        let bounds = pixel(b.outputImage!)
        check(bounds == [10, 20, 30, 40], "CIAreaBoundsRed: x, y, width, height (\(bounds))")
        let half = solid(1, 0, 0, 1, CGRect(x: 0, y: 0, width: 50, height: 100)).composited(over: solid(0.5, 0, 0, 1, CGRect(x: 0, y: 0, width: 100, height: 100)))
        let am = CIFilter.areaAverageMaximumRed()
        am.inputImage = half; am.extent = half.extent
        let v = pixel(am.outputImage!)
        check(near(v[0], 0.75) && near(v[1], 1) && v[3] == 1, "CIAreaAverageMaximumRed: average and maximum (\(v))")
        // alpha weighted: an invisible red half (alpha 0) does not count, the opaque white half does
        let mixed = bitmap(2, 1) { x, _ in x == 0 ? [1, 0, 0, 0] : [1, 1, 1, 1] }
        let h = CIFilter.areaAlphaWeightedHistogram()
        h.inputImage = mixed; h.extent = mixed.extent; h.count = 4; h.scale = 1
        let bins = pixels(h.outputImage!, CGRect(x: 0, y: 0, width: 4, height: 1))
        check(near(bins[12], 1) && near(bins[13], 1) && near(bins[0], 0) && near(bins[1], 0), "CIAreaAlphaWeightedHistogram: weighted by alpha (\(bins))")
    }

    @available(iOS 26.0, *)
    static func geometry() {
        // a 4x4 black image with one bright pixel: halved, the maximum keeps it (Lanczos would average it away)
        let dot = bitmap(4, 4) { x, y in x == 1 && y == 2 ? [1, 1, 1, 1] : [0, 0, 0, 1] }
        let m = CIFilter.maximumScaleTransform()
        m.inputImage = dot; m.scale = 0.5; m.aspectRatio = 1
        let out = m.outputImage!
        let p = pixels(out, CGRect(x: 0, y: 0, width: 2, height: 2))
        // the bright pixel (column 1, top-down row 2 = y 1 from the bottom) lands in the bottom-left output pixel
        check(out.extent == CGRect(x: 0, y: 0, width: 2, height: 2) && p[8] == 1 && p[0] == 0 && p[4] == 0 && p[12] == 0,
              "CIMaximumScaleTransform keeps the maximum (\(p))")
    }

    @available(iOS 26.0, *)
    static func generators() {
        let g = CIFilter.blurredRoundedRectangleGenerator()
        g.extent = CGRect(x: 0, y: 0, width: 100, height: 60); g.radius = 20; g.sigma = 5; g.color = CIColor(red: 1, green: 1, blue: 1)
        let im = g.outputImage!
        let center = pixel(im, 50, 30), edge = pixel(im, 50, 0), out = pixel(im, -12, 30)
        check(im.extent.minX <= -15 && near(center[3], 1, 0.01) && edge[3] > 0.3 && edge[3] < 0.7 && out[3] < 0.05,
              "CIBlurredRoundedRectangleGenerator: blurred edges (center \(center[3]), edge \(edge[3]), outside \(out[3]))")
        // smoothness: continuous corners start earlier, so a point near the corner is less covered
        func cornerCoverage(_ s: Float) -> Float {
            let r = CIFilter.roundedRectangleGenerator()
            r.extent = CGRect(x: 0, y: 0, width: 100, height: 100); r.radius = 30; r.color = .white; r.smoothness = s
            return pixel(r.outputImage!, 1, 20)[3]
        }
        let c0 = cornerCoverage(0), c1 = cornerCoverage(1)
        check(abs(c1 - c0) > 0.2, "roundedRectangleGenerator smoothness (corner coverage \(c0) -> \(c1))")
        let stroke = CIFilter.roundedRectangleStrokeGenerator()
        stroke.extent = CGRect(x: 0, y: 0, width: 100, height: 100); stroke.radius = 30; stroke.width = 4; stroke.smoothness = 1
        check(stroke.outputImage != nil, "roundedRectangleStrokeGenerator smoothness")

        let q = CIFilter.roundedQRCodeGenerator()
        q.message = Data("isim rounded QR".utf8); q.correctionLevel = "H"; q.scale = 8; q.roundedMarkers = 3; q.roundedData = true
        q.color0 = CIColor(red: 0, green: 0, blue: 0.5); q.color1 = CIColor(red: 1, green: 1, blue: 1)
        let qr = q.outputImage!
        let w = qr.extent.width
        let margin = pixel(qr, 2, w - 3), eye = pixel(qr, 8 + 3.5 * 8, w - 8 - 3.5 * 8)
        check(Int(w) % 8 == 0 && w >= 25 * 8 && margin[0] > 0.9 && near(eye[2], 0.5, 0.05) && eye[0] < 0.05,
              "CIRoundedQRCodeGenerator: colors, margin, finder eye (\(Int(w)) px)")
        if let det = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil),
           let f = det.features(in: qr.transformed(by: CGAffineTransform(scaleX: 1, y: 1))).first as? CIQRCodeFeature {
            check(f.messageString == "isim rounded QR", "the rounded QR code decodes (\(f.messageString ?? "nil"))")
        } else { print("SKIP  decoding: no QR decoder on the host") }
        q.centerSpaceSize = 0.3
        let hole = pixel(q.outputImage!, w / 2, w / 2)
        check(hole[0] > 0.9, "centerSpaceSize clears the middle")
    }

    @available(iOS 26.0, *)
    static func hdr() {
        let bright = bitmap(2, 2) { x, y in x == 0 && y == 0 ? [3, 3, 3, 1] : [0.5, 0.5, 0.5, 1] }
        guard let stats = raw.calculateHDRStats(for: bright) else { check(false, "calculateHDRStats"); return }
        check(near(Float(stats.contentHeadroom), 3) && near(stats.contentAverageLightLevel, 1.125),
              "calculateHDRStats: headroom \(stats.contentHeadroom), average \(stats.contentAverageLightLevel)")
        let tagged = bright.settingContentHeadroom(4).settingContentAverageLightLevel(0.25)
        check(tagged.contentHeadroom == 4 && tagged.contentAverageLightLevel == 0.25 && bright.contentAverageLightLevel == 0,
              "settingContentHeadroom, settingContentAverageLightLevel")
        func mapped(_ range: CIDynamicRangeOption?) -> (Float, CGFloat) {
            let t = CIFilter.systemToneMap()
            t.inputImage = tagged; t.displayHeadroom = 2; t.preferredDynamicRange = range
            let o = t.outputImage!
            return (pixel(o, 0, 1)[0], o.contentHeadroom)
        }
        let (high, hh) = mapped(.high), (std, sh) = mapped(.standard), (ch, _) = mapped(.constrainedHigh)
        check(high <= 2.001 && high > 1.5 && hh == 2 && std <= 1.001 && sh == 1 && ch <= 2.001,
              "CISystemToneMap: high \(high) (\(hh)), standard \(std) (\(sh)), constrainedHigh \(ch)")
        let lab = pixel(solid(1, 1, 1, 1, CGRect(x: 0, y: 0, width: 4, height: 4)).convertingWorkingSpaceToLab(), 1, 1)
        let back = pixel(solid(1, 1, 1, 1, CGRect(x: 0, y: 0, width: 4, height: 4)).convertingWorkingSpaceToLab().convertingLabToWorkingSpace(), 1, 1)
        check(near(lab[0], 100, 0.5) && abs(lab[1]) < 0.5 && near(back[0], 1, 0.01), "Lab conversion: white is L 100 (\(lab[0])), and back")
        check(bright.insertingTiledIntermediate().extent == bright.extent, "insertingTiledIntermediate")
        // depth: a 2x2 DepthFloat32 map
        var values: [Float] = [1, 2, 3, 4]
        let data = Data(bytes: &values, count: 16)
        let rep: [AnyHashable: Any] = ["kCGImageAuxiliaryDataInfoData": data,
                                       "kCGImageAuxiliaryDataInfoDataDescription": ["Width": 2, "Height": 2, "BytesPerRow": 8, "PixelFormat": Int(kCVPixelFormatType_DepthFloat32)]]
        if let depth = try? AVDepthData(fromDictionaryRepresentation: rep), let im = CIImage(depthData: depth) {
            let p = pixels(im, CGRect(x: 0, y: 0, width: 2, height: 2))
            check(im.extent.size == CGSize(width: 2, height: 2) && p[0] == 1 && p[12] == 4 && im.depthData === depth,
                  "CIImage(depthData:) shows the map and keeps the depth data (\(p[0]), \(p[12]))")
        } else { check(false, "CIImage(depthData:)") }
    }

    @available(iOS 26.0, *)
    static func constants() {
        check(CIDynamicRangeOption.standard.rawValue == "standard" && CIDynamicRangeOption.high.rawValue == "high", "CIDynamicRangeOption")
        check(kCIInputPoint0Key == "inputPoint0" && kCIInputThresholdKey == "inputThreshold" && kCIInputColor1Key == "inputColor1", "iOS 26 input keys")
        check(CIQRCodeDescriptor.ErrorCorrectionLevel.levelH.rawValue == Int(UInt8(ascii: "H")) && CIDataMatrixCodeDescriptor.ECCVersion.v200.rawValue == 200,
              "CIQRCodeDescriptor.ErrorCorrectionLevel, CIDataMatrixCodeDescriptor.ECCVersion")
        var px = [UInt8](repeating: 0, count: 4)
        raw.render(solid(1, 0.5, 0, 1, CGRect(x: 0, y: 0, width: 1, height: 1)), toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBX8, colorSpace: nil)
        check(px[0] == 255 && (127...128).contains(px[1]) && px[2] == 0, "CIFormat.RGBX8 (\(px))")
        let median: any CIFilter & CIMedian = CIFilter.median()
        let lab: any CIFilter & CIConvertLab = CIFilter.convertRGBtoLab()
        let km = CIFilter.kMeans()
        km.inputMeans = nil
        check(median.name == "CIMedianFilter" && lab.normalize == false && km.inputMeans == nil, "CIMedian, CIConvertLab, CIKMeans.inputMeans")
        check(CIContextOption.memoryTarget.rawValue == "memory_target" && CIImageOption.contentAverageLightLevel.rawValue.isEmpty == false
              && CIImageOption.providerTileSize.rawValue == "tile_size", "CIContextOption.memoryTarget, CIImageOption constants")
    }
}
