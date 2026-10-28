// isim AVFoundation: portrait effects and semantic segmentation mattes, and camera calibration data (issue #382).
// Adapted: the simulated scene's mattes come from grey images like its depth (white: the person, or the hair, skin,
// teeth or glasses): ISIM_CAMERA_MATTE for the portrait matte (without it, the near part of ISIM_CAMERA_DEPTH, closer
// than 1 m) and ISIM_CAMERA_MATTE_HAIR / _SKIN / _TEETH / _GLASSES for the semantic ones (without one, an empty matte).
// Mattes are 8-bit at half the photo's size, mirrored with the photo. Calibration data describes isim's simulated lens:
// a pinhole with the format's field of view, centred, without distortion.
import UIKit
import ImageIO
import simd
import isim_host

/// a one-component 8-bit pixel buffer of w x h from `f(x, y)` (0...1)
func _matteBuffer(_ w: Int, _ h: Int, _ f: (Int, Int) -> Float) -> CVPixelBuffer? {
    guard let b = CVBuffer(_width: w, height: h, format: kCVPixelFormatType_OneComponent8) else { return nil }
    let base = CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to: UInt8.self), bpr = CVPixelBufferGetBytesPerRow(b)
    for y in 0..<h { for x in 0..<w { base[y * bpr + x] = UInt8(max(0, min(255, (f(x, y) * 255).rounded()))) } }
    return b
}
/// a pixel buffer's bytes as an auxiliary-image dictionary (kCGImageAuxiliaryDataInfo*)
func _auxDictionary(_ b: CVPixelBuffer) -> [AnyHashable: Any] {
    let h = CVPixelBufferGetHeight(b), bpr = CVPixelBufferGetBytesPerRow(b)
    return ["kCGImageAuxiliaryDataInfoData": Data(bytes: CVPixelBufferGetBaseAddress(b)!, count: bpr * h),
            "kCGImageAuxiliaryDataInfoDataDescription": ["Width": CVPixelBufferGetWidth(b), "Height": h, "BytesPerRow": bpr, "PixelFormat": Int(b._format)]]
}
func _auxBuffer(_ d: [AnyHashable: Any]) -> CVPixelBuffer? {
    guard let data = d["kCGImageAuxiliaryDataInfoData"] as? Data, let desc = d["kCGImageAuxiliaryDataInfoDataDescription"] as? [String: Any],
          let w = desc["Width"] as? Int, let h = desc["Height"] as? Int, let bpr = desc["BytesPerRow"] as? Int,
          let b = CVBuffer(_width: w, height: h, format: OSType((desc["PixelFormat"] as? Int) ?? Int(kCVPixelFormatType_OneComponent8))), data.count >= bpr * h else { return nil }
    let dst = CVPixelBufferGetBaseAddress(b)!, dbpr = CVPixelBufferGetBytesPerRow(b)
    data.withUnsafeBytes { s in for y in 0..<h { (dst + y * dbpr).copyMemory(from: s.baseAddress! + y * bpr, byteCount: min(bpr, dbpr)) } }
    return b
}
/// an 8-bit matte turned / flipped by an Exif orientation (1...8)
func _oriented(_ b: CVPixelBuffer, _ o: CGImagePropertyOrientation) -> CVPixelBuffer {
    let w = CVPixelBufferGetWidth(b), h = CVPixelBufferGetHeight(b)
    let swap = o.rawValue >= 5
    let ow = swap ? h : w, oh = swap ? w : h
    let src = CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to: UInt8.self), sbpr = CVPixelBufferGetBytesPerRow(b)
    return _matteBuffer(ow, oh) { x, y in
        // the source pixel shown at (x, y) of the oriented image
        let (sx, sy): (Int, Int)
        switch o {
        case .upMirrored: (sx, sy) = (w - 1 - x, y)
        case .down: (sx, sy) = (w - 1 - x, h - 1 - y)
        case .downMirrored: (sx, sy) = (x, h - 1 - y)
        case .leftMirrored: (sx, sy) = (y, x)
        case .right: (sx, sy) = (y, h - 1 - x)
        case .rightMirrored: (sx, sy) = (w - 1 - y, h - 1 - x)
        case .left: (sx, sy) = (w - 1 - y, x)
        default: (sx, sy) = (x, y)
        }
        return Float(src[sy * sbpr + sx]) / 255
    } ?? b
}

/// A matte separating the person from the background (for portrait effects).
public final class AVPortraitEffectsMatte: NSObject, @unchecked Sendable {
    public let mattingImage: CVPixelBuffer
    init(_ b: CVPixelBuffer) { mattingImage = b }
    public var pixelFormatType: OSType { mattingImage._format }
    public convenience init(fromDictionaryRepresentation imageSourceAuxDataInfoDictionary: [AnyHashable: Any]) throws {
        guard let b = _auxBuffer(imageSourceAuxDataInfoDictionary) else { throw AVError(.malformedDepth, reason: "not a portrait effects matte") }
        self.init(b)
    }
    public func applyingExifOrientation(_ exifOrientation: CGImagePropertyOrientation) -> Self { Self(_oriented(mattingImage, exifOrientation)) }
    public func replacingPortraitEffectsMatte(with pixelBuffer: CVPixelBuffer) throws -> Self {
        guard pixelBuffer._format == kCVPixelFormatType_OneComponent8 else { throw AVError(.malformedDepth, reason: "a portrait effects matte is kCVPixelFormatType_OneComponent8") }
        return Self(pixelBuffer)
    }
    public func dictionaryRepresentation(forAuxiliaryDataType outAuxDataType: AutoreleasingUnsafeMutablePointer<NSString?>?) -> [AnyHashable: Any]? {
        outAuxDataType?.pointee = kCGImageAuxiliaryDataTypePortraitEffectsMatte as NSString
        return _auxDictionary(mattingImage)
    }
}

/// A matte of one kind of region of the person: hair, skin, teeth or glasses.
public final class AVSemanticSegmentationMatte: NSObject, @unchecked Sendable {
    public struct MatteType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let hair = MatteType(rawValue: "AVSemanticSegmentationMatteTypeHair")
        public static let skin = MatteType(rawValue: "AVSemanticSegmentationMatteTypeSkin")
        public static let teeth = MatteType(rawValue: "AVSemanticSegmentationMatteTypeTeeth")
        @available(iOS 14.1, *) public static let glasses = MatteType(rawValue: "AVSemanticSegmentationMatteTypeGlasses")
        static let all: [MatteType] = [.hair, .skin, .teeth, MatteType(rawValue: "AVSemanticSegmentationMatteTypeGlasses")]
        var _auxType: CFString {
            switch rawValue {
            case MatteType.hair.rawValue: return kCGImageAuxiliaryDataTypeSemanticSegmentationHairMatte
            case MatteType.skin.rawValue: return kCGImageAuxiliaryDataTypeSemanticSegmentationSkinMatte
            case MatteType.teeth.rawValue: return kCGImageAuxiliaryDataTypeSemanticSegmentationTeethMatte
            default: return kCGImageAuxiliaryDataTypeSemanticSegmentationGlassesMatte
            }
        }
        var _env: String { "ISIM_CAMERA_MATTE_" + rawValue.replacingOccurrences(of: "AVSemanticSegmentationMatteType", with: "").uppercased() }
    }
    public let matteType: MatteType
    public let mattingImage: CVPixelBuffer
    init(_ t: MatteType, _ b: CVPixelBuffer) { matteType = t; mattingImage = b }
    public var pixelFormatType: OSType { mattingImage._format }
    public convenience init(fromImageSourceAuxiliaryDataType imageSourceAuxiliaryDataType: CFString, dictionaryRepresentation imageSourceAuxDataInfoDictionary: [AnyHashable: Any]) throws {
        guard let t = MatteType.all.first(where: { ($0._auxType as String) == (imageSourceAuxiliaryDataType as String) }),
              let b = _auxBuffer(imageSourceAuxDataInfoDictionary) else { throw AVError(.malformedDepth, reason: "not a semantic segmentation matte") }
        self.init(t, b)
    }
    public func applyingExifOrientation(_ exifOrientation: CGImagePropertyOrientation) -> Self { Self(matteType, _oriented(mattingImage, exifOrientation)) }
    public func replacingSemanticSegmentationMatte(with pixelBuffer: CVPixelBuffer) throws -> Self {
        guard pixelBuffer._format == kCVPixelFormatType_OneComponent8 else { throw AVError(.malformedDepth, reason: "a semantic segmentation matte is kCVPixelFormatType_OneComponent8") }
        return Self(matteType, pixelBuffer)
    }
    public func dictionaryRepresentation(forAuxiliaryDataType outAuxDataType: AutoreleasingUnsafeMutablePointer<NSString?>?) -> [AnyHashable: Any]? {
        outAuxDataType?.pointee = matteType._auxType as NSString
        return _auxDictionary(mattingImage)
    }
}

/// The simulated lens: a centred pinhole with the format's field of view and no distortion.
public final class AVCameraCalibrationData: NSObject, @unchecked Sendable {
    public let intrinsicMatrix: matrix_float3x3
    public let intrinsicMatrixReferenceDimensions: CGSize
    public let extrinsicMatrix: matrix_float4x3
    public let pixelSize: Float
    public let lensDistortionLookupTable: Data?
    public let inverseLensDistortionLookupTable: Data?
    public let lensDistortionCenter: CGPoint
    /// for frames of `size` taken with a horizontal field of view of `fov` degrees by a camera `offset` meters from the reference
    init(size: CGSize, fov: Float, offset: Float = 0) {
        let w = Float(size.width), h = Float(size.height)
        let f = (max(w, h) / 2) / tan(fov * .pi / 360)
        intrinsicMatrix = matrix_float3x3(columns: (SIMD3(f, 0, 0), SIMD3(0, f, 0), SIMD3(w / 2, h / 2, 1)))
        intrinsicMatrixReferenceDimensions = size
        extrinsicMatrix = matrix_float4x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1), SIMD3(offset, 0, 0)))
        pixelSize = 0.0012 * 4032 / max(w, h)                          // millimetres: a 1.2 µm sensor pixel at 4032 px
        let table = Data(count: 42 * MemoryLayout<Float>.size)        // zeros: no distortion
        lensDistortionLookupTable = table; inverseLensDistortionLookupTable = table
        lensDistortionCenter = CGPoint(x: size.width / 2, y: size.height / 2)
    }
}

/// The simulated scene's mattes (images like ISIM_CAMERA_DEPTH, read once).
enum _MatteScene {
    nonisolated(unsafe) static var _cache: [String: (w: Int, h: Int, v: [Float])?] = [:]
    static let lock = NSLock()
    static func source(_ env: String) -> (w: Int, h: Int, v: [Float])? {
        lock.lock(); defer { lock.unlock() }
        if let c = _cache[env] { return c }
        var r: (w: Int, h: Int, v: [Float])?
        if let path = ProcessInfo.processInfo.environment[env], !path.isEmpty {
            r = _onMainSync {
                var fw = 0.0, fh = 0.0
                let hd = isim_image_load(path, &fw, &fh)
                guard hd > 0, fw >= 1, fh >= 1 else { NSLog("isim AVFoundation: cannot read %@=%@", env, path); return nil }
                defer { isim_image_free(hd) }
                let w = Int(fw), h = Int(fh)
                var px = [UInt8](repeating: 0, count: w * h * 4)
                _ = isim_image_read_bgra(hd, 0, 0, Int32(w), Int32(h), &px)
                var v = [Float](repeating: 0, count: w * h)
                for i in 0..<(w * h) { v[i] = Float((Int(px[i * 4]) * 29 + Int(px[i * 4 + 1]) * 150 + Int(px[i * 4 + 2]) * 77) >> 8) / 255 }
                return (w, h, v)
            }
        }
        _cache[env] = r
        return r
    }
    static func sample(_ s: (w: Int, h: Int, v: [Float]), _ x: Int, _ y: Int, _ w: Int, _ h: Int, _ mirrored: Bool) -> Float {
        var sx = x * s.w / max(1, w), sy = y * s.h / max(1, h)
        if mirrored { sx = s.w - 1 - sx }
        sx = max(0, min(s.w - 1, sx)); sy = max(0, min(s.h - 1, sy))
        return s.v[sy * s.w + sx]
    }
    /// the portrait matte at w x h: ISIM_CAMERA_MATTE, else whatever is nearer than 1 m in the depth scene; nil without either
    static func portrait(_ w: Int, _ h: Int, mirrored: Bool) -> CVPixelBuffer? {
        if let s = source("ISIM_CAMERA_MATTE") { return _matteBuffer(w, h) { sample(s, $0, $1, w, h, mirrored) } }
        guard let d = _DepthScene.source() else { return nil }
        let disp = (w: d.w, h: d.h, v: d.disparity)
        return _matteBuffer(w, h) { x, y in sample(disp, x, y, w, h, mirrored) > 1 ? 1 : 0 }     // disparity > 1: closer than 1 m
    }
    static func semantic(_ t: AVSemanticSegmentationMatte.MatteType, _ w: Int, _ h: Int, mirrored: Bool) -> CVPixelBuffer? {
        if let s = source(t._env) { return _matteBuffer(w, h) { sample(s, $0, $1, w, h, mirrored) } }
        return _matteBuffer(w, h) { _, _ in 0 }
    }
}
