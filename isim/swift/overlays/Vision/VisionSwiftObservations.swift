// isim Vision: the rest of the iOS 18 Swift API's observations and shared types (issue #852), value types over the
// VN classes' results (adapted, the same engines): classification, contours, Core ML values, documents, objects,
// face landmarks and capture quality, feature prints, the horizon, body, hand and animal poses (PoseProviding), the
// 3D body pose, humans, aesthetics, image alignment, instance masks, optical flow, pixel buffers, recognized objects,
// saliency, text rectangles and trajectories; NormalizedCircle, Joint, Joint3D, ElementType, ImageCropAndScaleAction;
// and the iOS 26 bounding regions (NormalizedRegion: a contour) and lens smudges.
import UIKit
import CoreImage
import CoreML

// MARK: - shared types

public enum ElementType: Hashable, Sendable { case float, double }

public enum ImageCropAndScaleAction: Hashable, Sendable {
    case centerCrop, scaleToFit, scaleToFill, scaleToFitPlus90CCWRotation, scaleToFillPlus90CCWRotation
    var _vn: VNImageCropAndScaleOption {
        switch self {
        case .centerCrop: return .centerCrop
        case .scaleToFit: return .scaleFit
        case .scaleToFill: return .scaleFill
        case .scaleToFitPlus90CCWRotation: return .scaleFitRotate90CCW
        case .scaleToFillPlus90CCWRotation: return .scaleFillRotate90CCW
        }
    }
}

public enum Chirality: Hashable, Sendable { case left, right }

/// A circle in normalized coordinates.
public struct NormalizedCircle: Hashable, Sendable, CustomStringConvertible {
    public let center: NormalizedPoint
    public let radius: CGFloat
    public init(center: NormalizedPoint, radius: CGFloat) { self.center = center; self.radius = radius }
    public static var zero: NormalizedCircle { NormalizedCircle(center: .zero, radius: 0) }
    func _distance(_ p: NormalizedPoint) -> CGFloat { hypot(p.x - center.x, p.y - center.y) }
    public func contains(_ point: NormalizedPoint) -> Bool { _distance(point) <= radius }
    /// whether the point lies in the ring of that width around the circumference (half inside, half outside)
    public func contains(_ point: NormalizedPoint, inCircumferentialRingOfWidth ringWidth: CGFloat) -> Bool { abs(_distance(point) - radius) <= ringWidth / 2 }
    /// the smallest circle around the points (Welzl's algorithm)
    public static func boundingCircle(for points: [NormalizedPoint]) -> NormalizedCircle {
        guard let c = try? VNGeometryUtils.boundingCircle(for: points.map { VNPoint(x: Double($0.x), y: Double($0.y)) }) else { return .zero }
        return NormalizedCircle(c)
    }
    init(_ c: VNCircle) { center = NormalizedPoint(x: CGFloat(c.center.x), y: CGFloat(c.center.y)); radius = CGFloat(c.radius) }
    public var description: String { "NormalizedCircle(center: \(center), radius: \(radius))" }
}

/// A pose's joint: where it is in the image and how sure the detector is.
public struct Joint: Hashable, Sendable, CustomStringConvertible {
    public let jointName: String
    public let location: NormalizedPoint
    public let confidence: Float
    init(jointName: String, location: NormalizedPoint, confidence: Float) { self.jointName = jointName; self.location = location; self.confidence = confidence }
    init(_ name: String, _ p: VNRecognizedPoint) { self.init(jointName: name, location: NormalizedPoint(x: CGFloat(p.x), y: CGFloat(p.y)), confidence: p.confidence) }
    /// the distance between the two joints' locations, in normalized coordinates
    public func distance(to joint: Joint) -> CGFloat { hypot(location.x - joint.location.x, location.y - joint.location.y) }
    public var description: String { "Joint(\(jointName), \(location), \(confidence))" }
}

/// A 3D pose's joint: its position in the scene and relative to its parent joint, in meters.
public struct Joint3D: Hashable, Sendable, CustomStringConvertible {
    public let identifier: String
    public let position: simd_float4x4
    public let localPosition: simd_float4x4
    public let parentJoint: String
    public init(position: simd_float4x4, localPosition: simd_float4x4, identifer: String, parentJoint: String) {
        self.position = position; self.localPosition = localPosition; identifier = identifer; self.parentJoint = parentJoint
    }
    public static func == (a: Joint3D, b: Joint3D) -> Bool {
        a.identifier == b.identifier && a.parentJoint == b.parentJoint && a.position == b.position && a.localPosition == b.localPosition
    }
    public func hash(into h: inout Hasher) {
        h.combine(identifier); h.combine(parentJoint)
        for c in 0..<4 { for r in 0..<4 { h.combine(position[c][r]) } }
    }
    public var description: String { "Joint3D(\(identifier), parent \(parentJoint), at \(position.columns.3.x), \(position.columns.3.y), \(position.columns.3.z))" }
}

/// Observations with a pose: named joints in groups.
public protocol PoseProviding {
    associatedtype PoseJointName: Codable, Hashable, RawRepresentable where PoseJointName.RawValue == String
    associatedtype PoseJointsGroupName: CaseIterable, RawRepresentable where PoseJointsGroupName.RawValue == String
    var availableJointNames: [PoseJointName] { get }
    var availableJointsGroupNames: [PoseJointsGroupName] { get }
    func joint(for jointName: PoseJointName) -> Joint?
    func allJoints(in groupName: PoseJointsGroupName?) -> [PoseJointName: Joint]
}
extension PoseProviding {
    public func allJoints() -> [PoseJointName: Joint] { allJoints(in: nil) }
}

/// The joints of a VN pose observation, under Swift joint names whose raw values are the VN keys.
struct _VNPose<Name: RawRepresentable & Hashable & CaseIterable, Group: RawRepresentable & Hashable & CaseIterable>: Hashable, @unchecked Sendable
    where Name.RawValue == String, Group.RawValue == String {
    let joints: [Name: Joint]
    let order: [Name]
    let groups: [Group: [Name]]
    let _vn: VNRecognizedPointsObservation?
    init(_ o: VNRecognizedPointsObservation, groups: [Group: [Name]]) {
        var j: [Name: Joint] = [:], order: [Name] = []
        for k in o.availableKeys {
            guard let n = Name(rawValue: k.rawValue), let p = try? o.recognizedPoint(forKey: k) else { continue }
            j[n] = Joint("\(n)", p); order.append(n)
        }
        joints = j; self.order = order; self.groups = groups; _vn = o
    }
    func all(in group: Group?) -> [Name: Joint] {
        guard let group else { return joints }
        var out: [Name: Joint] = [:]
        for n in groups[group] ?? [] { if let j = joints[n] { out[n] = j } }
        return out
    }
    func keypoints() throws -> MLMultiArray {
        guard let o = _vn else { throw VisionError.dataUnavailable("no keypoints") }
        do { return try o.keypointsMultiArray() } catch { throw VisionError._from(error) }
    }
    static func == (a: Self, b: Self) -> Bool { a.joints == b.joints && a.order == b.order }
    func hash(into h: inout Hasher) { h.combine(order) }
}

// MARK: - base observations

public struct ClassificationObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let identifier: String
    public init(_ observation: VNClassificationObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNClassificationObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor; identifier = o.identifier
    }
    init(identifier: String, confidence: Float, descriptor: RequestDescriptor?) {
        uuid = UUID(); self.confidence = confidence; timeRange = nil; originatingRequestDescriptor = descriptor; self.identifier = identifier
    }
    /// isim's classifiers have no precision-recall curves
    public var hasPrecisionRecallCurve: Bool { false }
    public func hasMinimumPrecision(_ minimumPrecision: Float, forRecall recall: Float) -> Bool { false }
    public func hasMinimumRecall(_ minimumRecall: Float, forPrecision precision: Float) -> Bool { false }
    public var description: String { "ClassificationObservation(\(identifier), \(confidence))" }
}

public struct DetectedObjectObservation: VisionObservation, BoundingBoxProviding {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let boundingBox: NormalizedRect
    public init(boundingBox: NormalizedRect) { uuid = UUID(); confidence = 1; timeRange = nil; originatingRequestDescriptor = nil; self.boundingBox = boundingBox }
    public init(_ observation: VNDetectedObjectObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNDetectedObjectObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor; boundingBox = NormalizedRect(normalizedRect: o.boundingBox)
    }
    /// the observation as a VN one, for the trackers (same uuid)
    var _vn: VNDetectedObjectObservation { let o = VNDetectedObjectObservation(boundingBox: boundingBox.cgRect); o._uuid = uuid; return o }
    public var description: String { "DetectedObjectObservation(\(boundingBox))" }
}

public struct TextObservation: VisionObservation, QuadrilateralProviding {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let topLeft: NormalizedPoint, topRight: NormalizedPoint, bottomRight: NormalizedPoint, bottomLeft: NormalizedPoint
    public let characterBoxes: [RectangleObservation]?
    public init(_ observation: VNTextObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNTextObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        topLeft = NormalizedPoint(normalizedPoint: o.topLeft); topRight = NormalizedPoint(normalizedPoint: o.topRight)
        bottomRight = NormalizedPoint(normalizedPoint: o.bottomRight); bottomLeft = NormalizedPoint(normalizedPoint: o.bottomLeft)
        characterBoxes = o.characterBoxes?.map { RectangleObservation($0, descriptor: descriptor) }
    }
    public var description: String { "TextObservation(\(boundingBox), \(characterBoxes?.count ?? 0) characters)" }
}

public struct HumanObservation: VisionObservation, BoundingBoxProviding {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let boundingBox: NormalizedRect
    public let isUpperBodyOnly: Bool
    public init(boundingBox: NormalizedRect, revision: DetectHumanRectanglesRequest.Revision? = nil) {
        uuid = UUID(); confidence = 1; timeRange = nil; originatingRequestDescriptor = .detectHumanRectanglesRequest(revision ?? .revision2)
        self.boundingBox = boundingBox; isUpperBodyOnly = false
    }
    public init(_ observation: VNHumanObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNHumanObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        boundingBox = NormalizedRect(normalizedRect: o.boundingBox); isUpperBodyOnly = o.upperBodyOnly
    }
    public var description: String { "HumanObservation(\(boundingBox))" }
}

public struct RecognizedObjectObservation: VisionObservation, BoundingBoxProviding {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let boundingBox: NormalizedRect
    public let labels: [ClassificationObservation]
    public init(_ observation: VNRecognizedObjectObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNRecognizedObjectObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        boundingBox = NormalizedRect(normalizedRect: o.boundingBox); labels = o.labels.map { ClassificationObservation($0, descriptor: descriptor) }
    }
    public var description: String { "RecognizedObjectObservation(\(labels.map(\.identifier)), \(boundingBox))" }
}

// MARK: - contours and regions

public struct ContoursObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    let _vn: VNContoursObservation

    /// A contour: its points (normalized, lower-left origin) and the contours inside it.
    public struct Contour: Hashable, @unchecked Sendable, CustomStringConvertible {
        let _c: VNContour
        init(_ c: VNContour) { _c = c }
        /// a closed region through the points (for bounding regions)
        init(points: [NormalizedPoint]) { _c = VNContour(indexPath: IndexPath(index: 0), points: points.map { SIMD2(Float($0.x), Float($0.y)) }, children: [], aspectRatio: 1) }
        public var indexPath: IndexPath { _c.indexPath }
        public var aspectRatio: Float { _c.aspectRatio }
        public var pointCount: Int { _c.pointCount }
        public var normalizedPoints: [simd_float2] { _c.normalizedPoints }
        public var points: [NormalizedPoint] { _c.normalizedPoints.map { NormalizedPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } }
        public var normalizedPath: CGPath { _c.normalizedPath }
        public var childContours: [Contour] { _c.childContours.map(Contour.init) }
        public var boundingBox: NormalizedRect {
            let p = points
            guard let x0 = p.map(\.x).min(), let x1 = p.map(\.x).max(), let y0 = p.map(\.y).min(), let y1 = p.map(\.y).max() else { return NormalizedRect(x: 0, y: 0, width: 0, height: 0) }
            return NormalizedRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        }
        /// isim: the upright bounding box's corners
        public var boundingQuad: RectangleObservation {
            let b = boundingBox.cgRect
            return RectangleObservation(topLeft: NormalizedPoint(x: b.minX, y: b.maxY), topRight: NormalizedPoint(x: b.maxX, y: b.maxY),
                                        bottomRight: NormalizedPoint(x: b.maxX, y: b.minY), bottomLeft: NormalizedPoint(x: b.minX, y: b.minY))
        }
        public func boundingCircle() -> NormalizedCircle { (try? VNGeometryUtils.boundingCircle(for: _c)).map(NormalizedCircle.init) ?? .zero }
        public func calculateArea(useOrientedArea: Bool = false) -> Double {
            var a = 0.0
            try? VNGeometryUtils.calculateArea(&a, for: _c, orientedArea: useOrientedArea)
            return a
        }
        public func calculatePerimeter() -> Double {
            var p = 0.0
            try? VNGeometryUtils.calculatePerimeter(&p, for: _c)
            return p
        }
        public func polygonApproximation(epsilon: Float) throws -> Contour {
            do { return Contour(try _c.polygonApproximation(epsilon: epsilon)) } catch { throw VisionError._from(error) }
        }
        public static func == (a: Contour, b: Contour) -> Bool { a._c === b._c || (a.indexPath == b.indexPath && a._c.normalizedPoints == b._c.normalizedPoints) }
        public func hash(into h: inout Hasher) { h.combine(indexPath); h.combine(pointCount) }
        public var description: String { "Contour(\(indexPath), \(pointCount) points, \(childContours.count) children)" }
    }

    public init(_ observation: VNContoursObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNContoursObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor; _vn = o
    }
    public var contourCount: Int { _vn.contourCount }
    public var topLevelContours: [Contour] { _vn.topLevelContours.map(Contour.init) }
    public var normalizedPath: CGPath { _vn.normalizedPath }
    public func contourAtIndex(_ index: Int) -> Contour? { (try? _vn.contour(at: index)).map(Contour.init) }
    public func countourAtIndexPath(_ indexPath: IndexPath) -> Contour? { (try? _vn.contour(at: indexPath)).map(Contour.init) }
    public static func == (a: ContoursObservation, b: ContoursObservation) -> Bool { a.uuid == b.uuid }
    public func hash(into h: inout Hasher) { h.combine(uuid) }
    public var description: String { "ContoursObservation(\(contourCount) contours)" }
}

@available(iOS 26.0, *)
public typealias NormalizedRegion = ContoursObservation.Contour

/// Observations with a region that bounds them (iOS 26).
@available(iOS 26.0, *)
public protocol BoundingRegionProviding {
    var boundingRegion: NormalizedRegion { get }
}
extension QuadrilateralProviding {
    /// the quadrilateral as a closed region
    var _quadRegion: ContoursObservation.Contour { ContoursObservation.Contour(points: [topLeft, topRight, bottomRight, bottomLeft]) }
}
@available(iOS 26.0, *)
extension BarcodeObservation: BoundingRegionProviding {
    public var boundingRegion: NormalizedRegion { _quadRegion }
}
@available(iOS 26.0, *)
extension RecognizedTextObservation: BoundingRegionProviding {
    public var boundingRegion: NormalizedRegion { _quadRegion }
}
@available(iOS 26.0, *)
extension DocumentObservation.Container.List: BoundingRegionProviding {
    public var boundingRegion: NormalizedRegion { _rectRegion(_vnUnion(items.flatMap { $0.content.text.lines.map(\.boundingBox) })) }
}
@available(iOS 26.0, *)
extension DocumentObservation.Container.Table: BoundingRegionProviding {
    public var boundingRegion: NormalizedRegion { _rectRegion(_vnUnion(rows.joined().flatMap { $0.content.text.lines.map(\.boundingBox) })) }
}
/// the boxes' union (empty for none)
func _vnUnion(_ boxes: [NormalizedRect]) -> NormalizedRect {
    guard let f = boxes.first else { return NormalizedRect(x: 0, y: 0, width: 0, height: 0) }
    return NormalizedRect(normalizedRect: boxes.dropFirst().reduce(f.cgRect) { $0.union($1.cgRect) })
}
func _rectRegion(_ r: NormalizedRect) -> ContoursObservation.Contour {
    let b = r.cgRect
    return ContoursObservation.Contour(points: [NormalizedPoint(x: b.minX, y: b.maxY), NormalizedPoint(x: b.maxX, y: b.maxY),
                                                NormalizedPoint(x: b.maxX, y: b.minY), NormalizedPoint(x: b.minX, y: b.minY)])
}

// MARK: - pixel buffers

/// The pixel buffer's single-channel value at a normalized point (lower-left origin), as a float.
func _vnSample(_ pb: CVPixelBuffer, _ p: NormalizedPoint, channel: Int = 0) -> Float {
    let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
    guard w > 0, h > 0 else { return 0 }
    let x = min(w - 1, max(0, Int(p.x * CGFloat(w)))), y = min(h - 1, max(0, Int((1 - p.y) * CGFloat(h))))
    CVPixelBufferLockBaseAddress(pb, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(pb) else { return 0 }
    let row = base + y * CVPixelBufferGetBytesPerRow(pb)
    switch CVPixelBufferGetPixelFormatType(pb) {
    case kCVPixelFormatType_OneComponent8: return Float(row.load(fromByteOffset: x, as: UInt8.self)) / 255
    case kCVPixelFormatType_OneComponent32Float: return row.load(fromByteOffset: x * 4, as: Float.self)
    case kCVPixelFormatType_TwoComponent32Float: return row.load(fromByteOffset: (x * 2 + channel) * 4, as: Float.self)
    case kCVPixelFormatType_OneComponent16Half: return Float(row.load(fromByteOffset: x * 2, as: Float16.self))
    case kCVPixelFormatType_TwoComponent16Half: return Float(row.load(fromByteOffset: (x * 2 + channel) * 2, as: Float16.self))
    case kCVPixelFormatType_32BGRA: return Float(row.load(fromByteOffset: x * 4 + 2 - channel, as: UInt8.self)) / 255
    default: return 0
    }
}

public struct PixelBufferObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    let _buffer: CVPixelBuffer
    public init?(_ observation: VNPixelBufferObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNPixelBufferObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor; _buffer = o.pixelBuffer
    }
    init(buffer: CVPixelBuffer, descriptor: RequestDescriptor?) { uuid = UUID(); confidence = 1; timeRange = nil; originatingRequestDescriptor = descriptor; _buffer = buffer }
    @available(iOS 26.0, *)
    public var pixelBuffer: CVReadOnlyPixelBuffer { CVReadOnlyPixelBuffer(unsafeBuffer: _buffer) }
    public var pixelFormat: OSType { CVPixelBufferGetPixelFormatType(_buffer) }
    public var size: CGSize { CGSize(width: CVPixelBufferGetWidth(_buffer), height: CVPixelBufferGetHeight(_buffer)) }
    /// the value at the point: 0...1 for 8-bit masks, the float otherwise
    public func pixel(at point: NormalizedPoint) -> Float { _vnSample(_buffer, point) }
    public func withUnsafePointer<R>(_ body: (UnsafeRawPointer) -> R) -> R {
        CVPixelBufferLockBaseAddress(_buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(_buffer, .readOnly) }
        return body(UnsafeRawPointer(CVPixelBufferGetBaseAddress(_buffer)!))
    }
    /// the buffer as a grayscale (or colour) image
    public var cgImage: CGImage {
        get throws {
            guard let img = CIContext().createCGImage(CIImage(cvPixelBuffer: _buffer), from: CGRect(origin: .zero, size: size)) else {
                throw VisionError.invalidFormat("the pixel buffer cannot be drawn as an image")
            }
            return img
        }
    }
    public static func == (a: PixelBufferObservation, b: PixelBufferObservation) -> Bool { a.uuid == b.uuid }
    public func hash(into h: inout Hasher) { h.combine(uuid) }
    public var description: String { "PixelBufferObservation(\(Int(size.width))x\(Int(size.height)))" }
}

public struct OpticalFlowObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    let _buffer: CVPixelBuffer
    public init?(_ observation: VNPixelBufferObservation) { self.init(observation, descriptor: nil) }
    init?(_ o: VNPixelBufferObservation, descriptor: RequestDescriptor?) {
        let f = CVPixelBufferGetPixelFormatType(o.pixelBuffer)
        guard f == kCVPixelFormatType_TwoComponent32Float || f == kCVPixelFormatType_TwoComponent16Half else { return nil }
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor; _buffer = o.pixelBuffer
    }
    @available(iOS 26.0, *)
    public var pixelBuffer: CVReadOnlyPixelBuffer { CVReadOnlyPixelBuffer(unsafeBuffer: _buffer) }
    public var pixelFormat: OSType { CVPixelBufferGetPixelFormatType(_buffer) }
    public var size: CGSize { CGSize(width: CVPixelBufferGetWidth(_buffer), height: CVPixelBufferGetHeight(_buffer)) }
    /// the motion at the point, in pixels of the flow field (x right, y down)
    public func flow(at point: NormalizedPoint) -> (Float, Float) { (_vnSample(_buffer, point, channel: 0), _vnSample(_buffer, point, channel: 1)) }
    public func withUnsafePointer<R>(_ body: (UnsafeRawPointer) -> R) -> R {
        CVPixelBufferLockBaseAddress(_buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(_buffer, .readOnly) }
        return body(UnsafeRawPointer(CVPixelBufferGetBaseAddress(_buffer)!))
    }
    public static func == (a: OpticalFlowObservation, b: OpticalFlowObservation) -> Bool { a.uuid == b.uuid }
    public func hash(into h: inout Hasher) { h.combine(uuid) }
    public var description: String { "OpticalFlowObservation(\(Int(size.width))x\(Int(size.height)))" }
}

public struct SaliencyImageObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let heatMap: PixelBufferObservation
    public let salientObjects: [RectangleObservation]
    public init?(_ observation: VNSaliencyImageObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNSaliencyImageObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        heatMap = PixelBufferObservation(o, descriptor: descriptor)
        salientObjects = (o.salientObjects ?? []).map { RectangleObservation($0, descriptor: descriptor) }
    }
    public var description: String { "SaliencyImageObservation(\(heatMap.size), \(salientObjects.count) objects)" }
}

public struct InstanceMaskObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let allInstances: IndexSet
    public let allInstancesMask: PixelBufferObservation
    let _vn: VNInstanceMaskObservation
    public init?(_ observation: VNInstanceMaskObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNInstanceMaskObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor; _vn = o
        allInstances = o.allInstances; allInstancesMask = PixelBufferObservation(buffer: o.instanceMask, descriptor: descriptor)
    }
    public func generateMask(for instances: IndexSet) throws -> CVPixelBuffer {
        do { return try _vn.generateMask(forInstances: instances) } catch { throw VisionError._from(error) }
    }
    public func generateMaskedImage(for instances: IndexSet, imageFrom requestHandler: ImageRequestHandler, croppedToInstancesExtent: Bool = false) throws -> CVPixelBuffer {
        do { return try _vn.generateMaskedImage(ofInstances: instances, from: requestHandler._handler(), croppedToInstancesExtent: croppedToInstancesExtent) } catch { throw VisionError._from(error) }
    }
    public func generateScaledMask(for instances: IndexSet, scaledToImageFrom requestHandler: ImageRequestHandler) throws -> CVPixelBuffer {
        do { return try _vn.generateScaledMaskForImage(forInstances: instances, from: requestHandler._handler()) } catch { throw VisionError._from(error) }
    }
    /// the instance at the point (empty for the background)
    public func instanceAtPoint(_ point: NormalizedPoint) -> IndexSet {
        let i = Int(_vnSample(_vn.instanceMask, point) * 255 + 0.5)
        return i > 0 && allInstances.contains(i) ? IndexSet(integer: i) : IndexSet()
    }
    public static func == (a: InstanceMaskObservation, b: InstanceMaskObservation) -> Bool { a.uuid == b.uuid }
    public func hash(into h: inout Hasher) { h.combine(uuid) }
    public var description: String { "InstanceMaskObservation(\(allInstances.count) instances)" }
}

public struct DetectedDocumentObservation: VisionObservation, QuadrilateralProviding {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let topLeft: NormalizedPoint, topRight: NormalizedPoint, bottomRight: NormalizedPoint, bottomLeft: NormalizedPoint
    public init?(_ observation: VNRectangleObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNRectangleObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        topLeft = NormalizedPoint(normalizedPoint: o.topLeft); topRight = NormalizedPoint(normalizedPoint: o.topRight)
        bottomRight = NormalizedPoint(normalizedPoint: o.bottomRight); bottomLeft = NormalizedPoint(normalizedPoint: o.bottomLeft)
    }
    /// isim: the document's quadrilateral filled in a 256 x 256 OneComponent8 mask
    public var globalSegmentationMask: PixelBufferObservation {
        let n = 256
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, n, n, kCVPixelFormatType_OneComponent8, nil, &pb)
        let buffer = pb!
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer), let ctx = CGContext(data: base, width: n, height: n, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                                                                 space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) {
            ctx.setFillColor(gray: 0, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: n, height: n))
            let s = CGFloat(n)
            ctx.move(to: CGPoint(x: topLeft.x * s, y: topLeft.y * s)); ctx.addLine(to: CGPoint(x: topRight.x * s, y: topRight.y * s))
            ctx.addLine(to: CGPoint(x: bottomRight.x * s, y: bottomRight.y * s)); ctx.addLine(to: CGPoint(x: bottomLeft.x * s, y: bottomLeft.y * s))
            ctx.closePath(); ctx.setFillColor(gray: 1, alpha: 1); ctx.fillPath()
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return PixelBufferObservation(buffer: buffer, descriptor: originatingRequestDescriptor)
    }
    public var description: String { "DetectedDocumentObservation(\(boundingBox))" }
}

// MARK: - images

public struct HorizonObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let angle: Measurement<UnitAngle>
    public let transform: CGAffineTransform
    let _vn: VNHorizonObservation
    public init(_ observation: VNHorizonObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNHorizonObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        angle = Measurement(value: Double(o.angle), unit: .radians); transform = o.transform; _vn = o
    }
    public func transform(for imageSize: CGSize) -> CGAffineTransform { _vn.transform(forImageWidth: Int(imageSize.width), height: Int(imageSize.height)) }
    public static func == (a: HorizonObservation, b: HorizonObservation) -> Bool { a.uuid == b.uuid && a.angle == b.angle }
    public func hash(into h: inout Hasher) { h.combine(uuid) }
    public var description: String { "HorizonObservation(\(angle))" }
}

public struct FeaturePrintObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let data: Data
    public let elementCount: Int
    public let elementType: ElementType
    let _vn: VNFeaturePrintObservation
    public init(_ observation: VNFeaturePrintObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNFeaturePrintObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        data = o.data; elementCount = o.elementCount; elementType = o.elementType == .double ? .double : .float; _vn = o
    }
    public func distance(to featurePrint: FeaturePrintObservation) throws -> Double {
        var d: Float = 0
        do { try _vn.computeDistance(&d, to: featurePrint._vn) } catch { throw VisionError._from(error) }
        return Double(d)
    }
    public static func == (a: FeaturePrintObservation, b: FeaturePrintObservation) -> Bool { a.uuid == b.uuid && a.data == b.data }
    public func hash(into h: inout Hasher) { h.combine(uuid) }
    public var description: String { "FeaturePrintObservation(\(elementCount) \(elementType))" }
}

public struct ImageAestheticsScoresObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let overallScore: Float
    public let isUtility: Bool
    public init(_ observation: VNImageAestheticsScoresObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNImageAestheticsScoresObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor; overallScore = o.overallScore; isUtility = o.isUtility
    }
    public var description: String { "ImageAestheticsScoresObservation(\(overallScore), utility \(isUtility))" }
}

public struct SmudgeObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    init(confidence: Float, descriptor: RequestDescriptor?) { uuid = UUID(); self.confidence = confidence; timeRange = nil; originatingRequestDescriptor = descriptor }
    public var description: String { "SmudgeObservation(\(confidence))" }
}

public struct ImageTranslationAlignmentObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let alignmentTransform: CGAffineTransform
    public init(_ observation: VNImageTranslationAlignmentObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNImageTranslationAlignmentObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor; alignmentTransform = o.alignmentTransform
    }
    init(identity descriptor: RequestDescriptor?) { uuid = UUID(); confidence = 0; timeRange = nil; originatingRequestDescriptor = descriptor; alignmentTransform = .identity }
    /// the image moved by the alignment transform
    public func applyTransform(to ciImage: CIImage) -> CIImage { ciImage.transformed(by: alignmentTransform) }
    public static func == (a: Self, b: Self) -> Bool { a.uuid == b.uuid && a.alignmentTransform == b.alignmentTransform }
    public func hash(into h: inout Hasher) { h.combine(uuid) }
    public var description: String { "ImageTranslationAlignmentObservation(tx \(alignmentTransform.tx), ty \(alignmentTransform.ty))" }
}

public struct ImageHomographicAlignmentObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let warpTransform: matrix_float3x3
    public init(_ observation: VNImageHomographicAlignmentObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNImageHomographicAlignmentObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor; warpTransform = o.warpTransform
    }
    init(identity descriptor: RequestDescriptor?) { uuid = UUID(); confidence = 0; timeRange = nil; originatingRequestDescriptor = descriptor; warpTransform = matrix_identity_float3x3 }
    /// isim: the image moved by the homography's affine part (Core Image's perspective filters are not applied)
    public func applyTransform(to ciImage: CIImage) -> CIImage {
        let m = warpTransform
        let w = m.columns.2.z == 0 ? 1 : m.columns.2.z
        return ciImage.transformed(by: CGAffineTransform(a: CGFloat(m.columns.0.x / w), b: CGFloat(m.columns.0.y / w), c: CGFloat(m.columns.1.x / w),
                                                         d: CGFloat(m.columns.1.y / w), tx: CGFloat(m.columns.2.x / w), ty: CGFloat(m.columns.2.y / w)))
    }
    public static func == (a: Self, b: Self) -> Bool { a.uuid == b.uuid && a.warpTransform == b.warpTransform }
    public func hash(into h: inout Hasher) { h.combine(uuid) }
    public var description: String { "ImageHomographicAlignmentObservation(\(warpTransform))" }
}

public struct TrajectoryObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let detectedPoints: [NormalizedPoint]
    public let projectedPoints: [NormalizedPoint]
    public let equationCoefficients: simd_float3
    public let movingAverageRadius: CGFloat
    public init(_ observation: VNTrajectoryObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNTrajectoryObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        detectedPoints = o.detectedPoints.map { NormalizedPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        projectedPoints = o.projectedPoints.map { NormalizedPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        equationCoefficients = o.equationCoefficients; movingAverageRadius = o.movingAverageRadius
    }
    public var description: String { "TrajectoryObservation(\(detectedPoints.count) points, \(equationCoefficients))" }
}

public struct CoreMLFeatureValueObservation: VisionObservation {
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let featureName: String
    public let featureValue: MLSendableFeatureValue
    public init?(_ observation: VNCoreMLFeatureValueObservation) {
        uuid = observation.uuid; confidence = observation.confidence; timeRange = nil; originatingRequestDescriptor = nil
        featureName = observation.featureName; featureValue = MLSendableFeatureValue(observation.featureValue)
    }
    public static func == (a: Self, b: Self) -> Bool { a.uuid == b.uuid }
    public func hash(into h: inout Hasher) { h.combine(uuid) }
    public var description: String { "CoreMLFeatureValueObservation(\(featureName))" }
}

// MARK: - faces

extension FaceObservation {
    /// A face's landmarks: regions of points in the image (normalized, lower-left origin).
    public struct Landmarks2D: Hashable, Sendable {
        public let originatingRequestDescriptor: RequestDescriptor?
        let _regions: [String: Region]
        public struct Region: Hashable, Sendable {
            public enum PointsClassification: Hashable, Sendable { case disconnected, openPath, closedPath }
            public let originatingRequestDescriptor: RequestDescriptor?
            public let points: [NormalizedPoint]
            public let pointsClassification: PointsClassification
            public let precisionEstimatesPerPoint: [Float]?
            init(_ r: VNFaceLandmarkRegion2D?, face: CGRect, descriptor: RequestDescriptor?) {
                originatingRequestDescriptor = descriptor
                points = (r?.normalizedPoints ?? []).map { NormalizedPoint(x: face.minX + $0.x * face.width, y: face.minY + $0.y * face.height) }
                switch r?.pointsClassification {
                case .openPath?: pointsClassification = .openPath
                case .closedPath?: pointsClassification = .closedPath
                default: pointsClassification = .disconnected
                }
                precisionEstimatesPerPoint = r?.precisionEstimatesPerPoint?.map(\.floatValue)
            }
            public func pointsInImageCoordinates(_ imageSize: CGSize, origin: CoordinateOrigin = .lowerLeft) -> [CGPoint] {
                points.map { $0.toImageCoordinates(imageSize, origin: origin) }
            }
        }
        init(_ l: VNFaceLandmarks2D, face: CGRect, descriptor: RequestDescriptor?) {
            originatingRequestDescriptor = descriptor
            let all: [(String, VNFaceLandmarkRegion2D?)] = [("allPoints", l.allPoints), ("faceContour", l.faceContour), ("leftEye", l.leftEye), ("rightEye", l.rightEye),
                ("leftEyebrow", l.leftEyebrow), ("rightEyebrow", l.rightEyebrow), ("nose", l.nose), ("noseCrest", l.noseCrest), ("medianLine", l.medianLine),
                ("outerLips", l.outerLips), ("innerLips", l.innerLips), ("leftPupil", l.leftPupil), ("rightPupil", l.rightPupil)]
            _regions = Dictionary(uniqueKeysWithValues: all.map { ($0.0, Region($0.1, face: face, descriptor: descriptor)) })
        }
        func _r(_ k: String) -> Region { _regions[k]! }
        public var allPoints: Region { _r("allPoints") }
        public var faceContour: Region { _r("faceContour") }
        public var leftEye: Region { _r("leftEye") }
        public var rightEye: Region { _r("rightEye") }
        public var leftEyebrow: Region { _r("leftEyebrow") }
        public var rightEyebrow: Region { _r("rightEyebrow") }
        public var nose: Region { _r("nose") }
        public var noseCrest: Region { _r("noseCrest") }
        public var medianLine: Region { _r("medianLine") }
        public var outerLips: Region { _r("outerLips") }
        public var innerLips: Region { _r("innerLips") }
        public var leftPupil: Region { _r("leftPupil") }
        public var rightPupil: Region { _r("rightPupil") }
    }
    /// How suitable the face is for capture, 0...1.
    public struct CaptureQuality: Hashable, Sendable {
        public let originatingRequestDescriptor: RequestDescriptor?
        public let score: Float
    }
}

// MARK: - poses

public struct HumanBodyPoseObservation: VisionObservation, PoseProviding {
    public enum JointName: String, Codable, CaseIterable, Sendable {
        case nose = "head_joint", leftEye = "left_eye_joint", rightEye = "right_eye_joint", leftEar = "left_ear_joint", rightEar = "right_ear_joint"
        case neck = "neck_1_joint", leftShoulder = "left_shoulder_1_joint", rightShoulder = "right_shoulder_1_joint"
        case leftElbow = "left_forearm_joint", rightElbow = "right_forearm_joint", leftWrist = "left_hand_joint", rightWrist = "right_hand_joint"
        case root = "root", leftHip = "left_upLeg_joint", rightHip = "right_upLeg_joint", leftKnee = "left_leg_joint", rightKnee = "right_leg_joint"
        case leftAnkle = "left_foot_joint", rightAnkle = "right_foot_joint"
    }
    public enum JointsGroupName: String, CaseIterable, Sendable {
        case face = "VNBLKFACE", torso = "VNBLKTORSO", leftArm = "VNBLKLARM", rightArm = "VNBLKRARM", leftLeg = "VNBLKLLEG", rightLeg = "VNBLKRLEG"
        var _members: [JointName] {
            switch self {
            case .face: return [.nose, .leftEye, .rightEye, .leftEar, .rightEar]
            case .torso: return [.neck, .leftShoulder, .rightShoulder, .root, .leftHip, .rightHip]
            case .leftArm: return [.leftShoulder, .leftElbow, .leftWrist]
            case .rightArm: return [.rightShoulder, .rightElbow, .rightWrist]
            case .leftLeg: return [.leftHip, .leftKnee, .leftAnkle]
            case .rightLeg: return [.rightHip, .rightKnee, .rightAnkle]
            }
        }
    }
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    /// isim finds no hands with the body (nil)
    public let leftHand: HumanHandPoseObservation?
    public let rightHand: HumanHandPoseObservation?
    let _pose: _VNPose<JointName, JointsGroupName>
    public init(_ observation: VNHumanBodyPoseObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNHumanBodyPoseObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor; leftHand = nil; rightHand = nil
        _pose = _VNPose(o, groups: Dictionary(uniqueKeysWithValues: JointsGroupName.allCases.map { ($0, $0._members) }))
    }
    public var availableJointNames: [JointName] { _pose.order }
    public var availableJointsGroupNames: [JointsGroupName] { JointsGroupName.allCases }
    public func joint(for jointName: JointName) -> Joint? { _pose.joints[jointName] }
    public func allJoints(in groupName: JointsGroupName? = nil) -> [JointName: Joint] { _pose.all(in: groupName) }
    public var keypoints: MLMultiArray { get throws { try _pose.keypoints() } }
    public var description: String { "HumanBodyPoseObservation(\(_pose.order.count) joints)" }
}

public struct HumanHandPoseObservation: VisionObservation, PoseProviding {
    public enum Chirality: Hashable, Sendable { case left, right }
    public enum JointName: String, Codable, CaseIterable, Sendable {
        case wrist = "VNHLKWRI", thumbCMC = "VNHLKTCMC", thumbMP = "VNHLKTMP", thumbIP = "VNHLKTIP", thumbTip = "VNHLKTTIP"
        case indexMCP = "VNHLKIMCP", indexPIP = "VNHLKIPIP", indexDIP = "VNHLKIDIP", indexTip = "VNHLKITIP"
        case middleMCP = "VNHLKMMCP", middlePIP = "VNHLKMPIP", middleDIP = "VNHLKMDIP", middleTip = "VNHLKMTIP"
        case ringMCP = "VNHLKRMCP", ringPIP = "VNHLKRPIP", ringDIP = "VNHLKRDIP", ringTip = "VNHLKRTIP"
        case littleMCP = "VNHLKPMCP", littlePIP = "VNHLKPPIP", littleDIP = "VNHLKPDIP", littleTip = "VNHLKPTIP"
    }
    public enum JointsGroupName: String, CaseIterable, Sendable {
        case thumb = "VNHLRKT", indexFinger = "VNHLRKI", middleFinger = "VNHLRKM", ringFinger = "VNHLRKR", littleFinger = "VNHLRKP"
        var _members: [JointName] {
            switch self {
            case .thumb: return [.thumbCMC, .thumbMP, .thumbIP, .thumbTip]
            case .indexFinger: return [.indexMCP, .indexPIP, .indexDIP, .indexTip]
            case .middleFinger: return [.middleMCP, .middlePIP, .middleDIP, .middleTip]
            case .ringFinger: return [.ringMCP, .ringPIP, .ringDIP, .ringTip]
            case .littleFinger: return [.littleMCP, .littlePIP, .littleDIP, .littleTip]
            }
        }
    }
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let chirality: Chirality?
    let _pose: _VNPose<JointName, JointsGroupName>
    public init(_ observation: VNHumanHandPoseObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNHumanHandPoseObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        switch o.chirality { case .left: chirality = .left; case .right: chirality = .right; default: chirality = nil }
        _pose = _VNPose(o, groups: Dictionary(uniqueKeysWithValues: JointsGroupName.allCases.map { ($0, $0._members) }))
    }
    public var availableJointNames: [JointName] { _pose.order }
    public var availableJointsGroupNames: [JointsGroupName] { JointsGroupName.allCases }
    public func joint(for jointName: JointName) -> Joint? { _pose.joints[jointName] }
    public func allJoints(in groupName: JointsGroupName? = nil) -> [JointName: Joint] { _pose.all(in: groupName) }
    public var keypoints: MLMultiArray { get throws { try _pose.keypoints() } }
    public var description: String { "HumanHandPoseObservation(\(_pose.order.count) joints)" }
}

public struct AnimalBodyPoseObservation: VisionObservation, PoseProviding {
    public enum JointName: String, Codable, CaseIterable, Sendable {
        case leftEarTop = "animal_joint_left_ear_top", leftEarMiddle = "animal_joint_left_ear_middle", leftEarBottom = "animal_joint_left_ear_bottom"
        case rightEarTop = "animal_joint_right_ear_top", rightEarMiddle = "animal_joint_right_ear_middle", rightEarBottom = "animal_joint_right_ear_bottom"
        case leftEye = "animal_joint_left_eye", rightEye = "animal_joint_right_eye", nose = "animal_joint_nose", neck = "animal_joint_neck"
        case leftFrontElbow = "animal_joint_left_front_elbow", rightFrontElbow = "animal_joint_right_front_elbow"
        case leftFrontKnee = "animal_joint_left_front_knee", rightFrontKnee = "animal_joint_right_front_knee"
        case leftFrontPaw = "animal_joint_left_front_paw", rightFrontPaw = "animal_joint_right_front_paw"
        case leftBackElbow = "animal_joint_left_back_elbow", rightBackElbow = "animal_joint_right_back_elbow"
        case leftBackKnee = "animal_joint_left_back_knee", rightBackKnee = "animal_joint_right_back_knee"
        case leftBackPaw = "animal_joint_left_back_paw", rightBackPaw = "animal_joint_right_back_paw"
        case tailTop = "animal_joint_tail_top", tailMiddle = "animal_joint_tail_middle", tailBottom = "animal_joint_tail_bottom"
    }
    public enum JointsGroupName: String, CaseIterable, Sendable {
        case head = "animal_group_head", trunk = "animal_group_trunk", forelegs = "animal_group_forelegs", hindlegs = "animal_group_hindlegs", tail = "animal_group_tail"
        var _members: [JointName] {
            switch self {
            case .head: return [.leftEarTop, .leftEarMiddle, .leftEarBottom, .rightEarTop, .rightEarMiddle, .rightEarBottom, .leftEye, .rightEye, .nose]
            case .trunk: return [.neck]
            case .forelegs: return [.leftFrontElbow, .rightFrontElbow, .leftFrontKnee, .rightFrontKnee, .leftFrontPaw, .rightFrontPaw]
            case .hindlegs: return [.leftBackElbow, .rightBackElbow, .leftBackKnee, .rightBackKnee, .leftBackPaw, .rightBackPaw]
            case .tail: return [.tailTop, .tailMiddle, .tailBottom]
            }
        }
    }
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    let _pose: _VNPose<JointName, JointsGroupName>
    public init(_ observation: VNAnimalBodyPoseObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNAnimalBodyPoseObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor
        _pose = _VNPose(o, groups: Dictionary(uniqueKeysWithValues: JointsGroupName.allCases.map { ($0, $0._members) }))
    }
    public var availableJointNames: [JointName] { _pose.order }
    public var availableJointsGroupNames: [JointsGroupName] { JointsGroupName.allCases }
    public func joint(for jointName: JointName) -> Joint? { _pose.joints[jointName] }
    public func allJoints(in groupName: JointsGroupName? = nil) -> [JointName: Joint] { _pose.all(in: groupName) }
    public var description: String { "AnimalBodyPoseObservation(\(_pose.order.count) joints)" }
}

public struct HumanBodyPose3DObservation: VisionObservation {
    public enum JointName: String, Codable, CaseIterable, Sendable {
        case root = "human_root_3D", spine = "human_spine_3D", centerShoulder = "human_center_shoulder_3D", centerHead = "human_center_head_3D"
        case topHead = "human_top_head_3D", leftShoulder = "human_left_shoulder_3D", rightShoulder = "human_right_shoulder_3D"
        case leftElbow = "human_left_elbow_3D", rightElbow = "human_right_elbow_3D", leftWrist = "human_left_wrist_3D", rightWrist = "human_right_wrist_3D"
        case leftHip = "human_left_hip_3D", rightHip = "human_right_hip_3D", leftKnee = "human_left_knee_3D", rightKnee = "human_right_knee_3D"
        case leftAnkle = "human_left_ankle_3D", rightAnkle = "human_right_ankle_3D"
        var _vn: VNHumanBodyPose3DObservation.JointName { VNHumanBodyPose3DObservation.JointName(rawValue: VNRecognizedPointKey(rawValue: rawValue)) }
    }
    public enum JointsGroupName: String, CaseIterable, Sendable {
        case head = "human_head_3D", torso = "human_torso_3D", leftArm = "human_left_arm_3D", rightArm = "human_right_arm_3D"
        case leftLeg = "human_left_leg_3D", rightLeg = "human_right_leg_3D"
        var _vn: VNHumanBodyPose3DObservation.JointsGroupName { VNHumanBodyPose3DObservation.JointsGroupName(rawValue: VNRecognizedPointGroupKey(rawValue: rawValue)) }
    }
    public enum EstimationTechnique: Hashable, Sendable { case measured, reference }
    public let uuid: UUID
    public let confidence: Float
    public let timeRange: CMTimeRange?
    public let originatingRequestDescriptor: RequestDescriptor?
    public let bodyHeight: Measurement<UnitLength>
    public let heightEstimationTechnique: EstimationTechnique
    public let cameraOriginMatrix: simd_float4x4
    let _vn: VNHumanBodyPose3DObservation
    public init(_ observation: VNHumanBodyPose3DObservation) { self.init(observation, descriptor: nil) }
    init(_ o: VNHumanBodyPose3DObservation, descriptor: RequestDescriptor?) {
        uuid = o.uuid; confidence = o.confidence; timeRange = nil; originatingRequestDescriptor = descriptor; _vn = o
        bodyHeight = Measurement(value: Double(o.bodyHeight), unit: .meters)
        heightEstimationTechnique = o.heightEstimation == .measured ? .measured : .reference
        cameraOriginMatrix = o.cameraOriginMatrix
    }
    public var availableJointNames: [JointName] { _vn.availableJointNames.compactMap { JointName(rawValue: $0.rawValue.rawValue) } }
    public var availableJointsGroupNames: [JointsGroupName] { JointsGroupName.allCases }
    public func joint(for jointName: JointName) -> Joint3D? {
        guard let p = try? _vn.recognizedPoint(jointName._vn) else { return nil }
        return Joint3D(position: p.position, localPosition: p.localPosition, identifer: "\(jointName)",
                       parentJoint: JointName(rawValue: p.parentJoint.rawValue.rawValue).map { "\($0)" } ?? "")
    }
    public func allJoints(in groupName: JointsGroupName? = nil) -> [JointName: Joint3D] {
        let names = groupName.map { g in ((try? _vn.recognizedPoints(g._vn)) ?? [:]).keys.compactMap { JointName(rawValue: $0.rawValue.rawValue) } } ?? availableJointNames
        var out: [JointName: Joint3D] = [:]
        for n in names { if let j = joint(for: n) { out[n] = j } }
        return out
    }
    /// the joint's parent (the root is its own)
    public func parentJointName(for jointName: JointName) -> JointName {
        _vn.parentJointName(jointName._vn).flatMap { JointName(rawValue: $0.rawValue.rawValue) } ?? jointName
    }
    public func pointInImage(for jointName: JointName) -> NormalizedPoint {
        guard let p = try? _vn.pointInImage(jointName._vn) else { return .zero }
        return NormalizedPoint(x: CGFloat(p.x), y: CGFloat(p.y))
    }
    public func cameraRelativePosition(for jointName: JointName) -> simd_float4x4 { (try? _vn.cameraRelativePosition(jointName._vn)) ?? matrix_identity_float4x4 }
    public static func == (a: Self, b: Self) -> Bool { a.uuid == b.uuid }
    public func hash(into h: inout Hasher) { h.combine(uuid) }
    public var description: String { "HumanBodyPose3DObservation(\(availableJointNames.count) joints, height \(bodyHeight))" }
}
