// isim AVFoundation: video compositions (issue #381). AVVideoComposition's instructions, layer instructions (transform,
// opacity and crop ramps), custom compositors (AVVideoCompositing), Core Image filtering and the Core Animation tool.
// Adapted: AVAssetExportSession (and AVAssetReaderVideoCompositionOutput, which renders through it) decodes each source
// video track at the output frame rate, hands every frame's request to the compositor (isim's own, drawn with Core
// Graphics, or the app's class), draws the Core Animation tool's layer tree at the frame's time, and encodes the frames
// with ffmpeg next to the audio graph.
import Foundation
import CoreImage
import UIKit
import isim_host

/// a layer animation's beginTime meaning the start of the video (0 would mean the current time, as in Core Animation)
public let AVCoreAnimationBeginTimeAtZero: CFTimeInterval = 1e-100

// MARK: - instructions

public protocol AVVideoCompositionInstructionProtocol: NSObjectProtocol, Sendable {
    var timeRange: CMTimeRange { get }
    var enablePostProcessing: Bool { get }
    var containsTweening: Bool { get }
    var requiredSourceTrackIDs: [NSValue]? { get }
    var passthroughTrackID: CMPersistentTrackID { get }
    var requiredSourceSampleDataTrackIDs: [NSNumber] { get }
}
extension AVVideoCompositionInstructionProtocol {
    public var requiredSourceSampleDataTrackIDs: [NSNumber] { [] }
}

/// isim's compositor's instruction: the layers (top first) over a background color during the time range.
/// isim: requiredSourceTrackIDs is optional here (Apple's class declares it non-optional, which a Swift protocol
/// conformance cannot express).
open class AVVideoCompositionInstruction: NSObject, NSSecureCoding, NSCopying, NSMutableCopying, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    var _timeRange = CMTimeRange.invalid
    var _backgroundColor: CGColor?
    var _layerInstructions: [AVVideoCompositionLayerInstruction] = []
    var _enablePostProcessing = true
    var _requiredSampleData: [NSNumber] = []
    public override init() { super.init() }
    open var timeRange: CMTimeRange { _timeRange }
    open var backgroundColor: CGColor? { _backgroundColor }
    open var layerInstructions: [AVVideoCompositionLayerInstruction] { _layerInstructions }
    open var enablePostProcessing: Bool { _enablePostProcessing }
    open var containsTweening: Bool { true }
    open var requiredSourceTrackIDs: [NSValue]? { _layerInstructions.map { NSNumber(value: $0.trackID) } }
    open var passthroughTrackID: CMPersistentTrackID { kCMPersistentTrackID_Invalid }
    open var requiredSourceSampleDataTrackIDs: [NSNumber] { _requiredSampleData }

    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) {
        coder.encode(_timeRange.start.seconds, forKey: "start"); coder.encode(_timeRange.duration.seconds, forKey: "duration")
        coder.encode(_enablePostProcessing, forKey: "enablePostProcessing")
        coder.encode(_layerInstructions as NSArray, forKey: "layerInstructions")
    }
    public required init?(coder: NSCoder) {
        super.init()
        _timeRange = CMTimeRange(start: CMTime(seconds: coder.decodeDouble(forKey: "start"), preferredTimescale: 600),
                                 duration: CMTime(seconds: coder.decodeDouble(forKey: "duration"), preferredTimescale: 600))
        _enablePostProcessing = coder.decodeBool(forKey: "enablePostProcessing")
        _layerInstructions = coder.decodeObject(forKey: "layerInstructions") as? [AVVideoCompositionLayerInstruction] ?? []
    }
    func _copy(into c: AVVideoCompositionInstruction) -> Any {
        c._timeRange = _timeRange; c._backgroundColor = _backgroundColor; c._layerInstructions = _layerInstructions
        c._enablePostProcessing = _enablePostProcessing; c._requiredSampleData = _requiredSampleData
        return c
    }
    open func copy(with zone: NSZone? = nil) -> Any { _copy(into: AVVideoCompositionInstruction()) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { _copy(into: AVMutableVideoCompositionInstruction()) }
}

open class AVMutableVideoCompositionInstruction: AVVideoCompositionInstruction, @unchecked Sendable {
    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override var timeRange: CMTimeRange { get { _timeRange } set { _timeRange = newValue } }
    open override var backgroundColor: CGColor? { get { _backgroundColor } set { _backgroundColor = newValue } }
    open override var layerInstructions: [AVVideoCompositionLayerInstruction] { get { _layerInstructions } set { _layerInstructions = newValue } }
    open override var enablePostProcessing: Bool { get { _enablePostProcessing } set { _enablePostProcessing = newValue } }
    open override var requiredSourceSampleDataTrackIDs: [NSNumber] { get { _requiredSampleData } set { _requiredSampleData = newValue } }
}

@available(iOS 26.0, *)
extension AVVideoCompositionInstruction {
    public struct Configuration {
        public var backgroundColor: CGColor?
        public var enablePostProcessing: Bool
        public var layerInstructions: [AVVideoCompositionLayerInstruction]
        public var requiredSourceSampleDataTrackIDs: [CMPersistentTrackID]
        public var timeRange: CMTimeRange
        public init(backgroundColor: CGColor? = nil, enablePostProcessing: Bool = true, layerInstructions: [AVVideoCompositionLayerInstruction] = [],
                    requiredSourceSampleDataTrackIDs: [CMPersistentTrackID] = [], timeRange: CMTimeRange = .invalid) {
            self.backgroundColor = backgroundColor; self.enablePostProcessing = enablePostProcessing; self.layerInstructions = layerInstructions
            self.requiredSourceSampleDataTrackIDs = requiredSourceSampleDataTrackIDs; self.timeRange = timeRange
        }
    }
    public convenience init(configuration: Configuration) {
        self.init()
        _backgroundColor = configuration.backgroundColor; _enablePostProcessing = configuration.enablePostProcessing
        _layerInstructions = configuration.layerInstructions; _timeRange = configuration.timeRange
        _requiredSampleData = configuration.requiredSourceSampleDataTrackIDs.map { NSNumber(value: $0) }
    }
}

// MARK: - layer instructions

/// A value held from `start` (seconds), or ramped linearly from `from` to `to` until `end`.
struct _AVRamp<V> {
    var start: Double, end: Double, from: V, to: V
    var range: CMTimeRange {
        CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: end.isFinite ? CMTime(seconds: end - start, preferredTimescale: 600) : .positiveInfinity)
    }
}
struct _AVRamps<V> {
    var list: [_AVRamp<V>] = []
    /// a later setting at the same start replaces the earlier one
    mutating func add(_ r: _AVRamp<V>) {
        list.removeAll { abs($0.start - r.start) < 1e-9 }
        list.append(r)
        list.sort { $0.start < $1.start }
    }
    mutating func set(_ v: V, at t: CMTime) { add(_AVRamp(start: t.isNumeric ? t.seconds : 0, end: .infinity, from: v, to: v)) }
    mutating func ramp(_ a: V, _ b: V, _ r: CMTimeRange) {
        let s = r.start.isNumeric ? r.start.seconds : 0
        add(_AVRamp(start: s, end: r.duration.isNumeric ? s + r.duration.seconds : .infinity, from: a, to: b))
    }
    /// the value at t: the default before the first setting, the last value after a ramp ends
    func value(at t: Double, default d: V, lerp: (V, V, Double) -> V) -> V {
        guard let i = list.lastIndex(where: { $0.start <= t + 1e-9 }) else { return d }
        let r = list[i]
        if !r.end.isFinite || r.end <= r.start { return r.from }
        if t >= r.end { return r.to }
        return lerp(r.from, r.to, (t - r.start) / (r.end - r.start))
    }
    /// the ramp in effect at t (getXRamp): a held value between settings; nil past the end of the last ramp
    func ramp(at t: CMTime, default d: V) -> _AVRamp<V>? {
        guard t.isNumeric else { return nil }
        let s = t.seconds
        guard let i = list.lastIndex(where: { $0.start <= s + 1e-9 }) else {
            return _AVRamp(start: 0, end: list.first?.start ?? .infinity, from: d, to: d)
        }
        let r = list[i]
        if s < r.end || !r.end.isFinite { return r }
        if i + 1 < list.count { return _AVRamp(start: r.end, end: list[i + 1].start, from: r.to, to: r.to) }
        return nil
    }
}
func _avLerp(_ a: CGFloat, _ b: CGFloat, _ f: Double) -> CGFloat { a + (b - a) * CGFloat(f) }
func _avLerp(_ a: CGAffineTransform, _ b: CGAffineTransform, _ f: Double) -> CGAffineTransform {
    CGAffineTransform(a: _avLerp(a.a, b.a, f), b: _avLerp(a.b, b.b, f), c: _avLerp(a.c, b.c, f), d: _avLerp(a.d, b.d, f),
                      tx: _avLerp(a.tx, b.tx, f), ty: _avLerp(a.ty, b.ty, f))
}
func _avLerp(_ a: CGRect, _ b: CGRect, _ f: Double) -> CGRect {
    CGRect(x: _avLerp(a.minX, b.minX, f), y: _avLerp(a.minY, b.minY, f), width: _avLerp(a.width, b.width, f), height: _avLerp(a.height, b.height, f))
}

/// How one track's frames are placed: transform (into the render size), opacity and crop, each held or ramped.
open class AVVideoCompositionLayerInstruction: NSObject, NSSecureCoding, NSCopying, NSMutableCopying, @unchecked Sendable {
    var _trackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    var _transforms = _AVRamps<CGAffineTransform>()
    var _opacities = _AVRamps<Float>()
    var _crops = _AVRamps<CGRect>()
    public override init() { super.init() }
    open var trackID: CMPersistentTrackID { _trackID }

    static func _out<V>(_ r: _AVRamp<V>?, _ a: UnsafeMutablePointer<V>?, _ b: UnsafeMutablePointer<V>?, _ tr: UnsafeMutablePointer<CMTimeRange>?) -> Bool {
        guard let r else { return false }
        a?.pointee = r.from; b?.pointee = r.to; tr?.pointee = r.range
        return true
    }
    open func getTransformRamp(for time: CMTime, start startTransform: UnsafeMutablePointer<CGAffineTransform>?,
                               end endTransform: UnsafeMutablePointer<CGAffineTransform>?, timeRange: UnsafeMutablePointer<CMTimeRange>?) -> Bool {
        Self._out(_transforms.ramp(at: time, default: .identity), startTransform, endTransform, timeRange)
    }
    open func getOpacityRamp(for time: CMTime, startOpacity: UnsafeMutablePointer<Float>?, endOpacity: UnsafeMutablePointer<Float>?,
                             timeRange: UnsafeMutablePointer<CMTimeRange>?) -> Bool {
        Self._out(_opacities.ramp(at: time, default: 1), startOpacity, endOpacity, timeRange)
    }
    open func getCropRectangleRamp(for time: CMTime, startCropRectangle: UnsafeMutablePointer<CGRect>?, endCropRectangle: UnsafeMutablePointer<CGRect>?,
                                   timeRange: UnsafeMutablePointer<CMTimeRange>?) -> Bool {
        Self._out(_crops.ramp(at: time, default: .infinite), startCropRectangle, endCropRectangle, timeRange)
    }
    func _transform(at t: Double) -> CGAffineTransform { _transforms.value(at: t, default: .identity, lerp: _avLerp) }
    func _opacity(at t: Double) -> Float { _opacities.value(at: t, default: 1) { a, b, f in a + (b - a) * Float(f) } }
    func _crop(at t: Double) -> CGRect? {
        let r = _crops.value(at: t, default: .infinite, lerp: _avLerp)
        return r.isInfinite || r.isNull ? nil : r
    }

    public static var supportsSecureCoding: Bool { true }
    open func encode(with coder: NSCoder) { coder.encode(Int(_trackID), forKey: "trackID") }
    public required init?(coder: NSCoder) { super.init(); _trackID = CMPersistentTrackID(coder.decodeInteger(forKey: "trackID")) }
    func _copy(into c: AVVideoCompositionLayerInstruction) -> Any {
        c._trackID = _trackID; c._transforms = _transforms; c._opacities = _opacities; c._crops = _crops
        return c
    }
    open func copy(with zone: NSZone? = nil) -> Any { _copy(into: AVVideoCompositionLayerInstruction()) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { _copy(into: AVMutableVideoCompositionLayerInstruction()) }
}

open class AVMutableVideoCompositionLayerInstruction: AVVideoCompositionLayerInstruction, @unchecked Sendable {
    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    public convenience init(assetTrack track: AVAssetTrack) { self.init(); _trackID = track.trackID }
    open override var trackID: CMPersistentTrackID { get { _trackID } set { _trackID = newValue } }
    open func setTransformRamp(fromStart startTransform: CGAffineTransform, toEnd endTransform: CGAffineTransform, timeRange: CMTimeRange) {
        _transforms.ramp(startTransform, endTransform, timeRange)
    }
    open func setTransform(_ transform: CGAffineTransform, at time: CMTime) { _transforms.set(transform, at: time) }
    open func setOpacityRamp(fromStartOpacity startOpacity: Float, toEndOpacity endOpacity: Float, timeRange: CMTimeRange) {
        _opacities.ramp(startOpacity, endOpacity, timeRange)
    }
    open func setOpacity(_ opacity: Float, at time: CMTime) { _opacities.set(opacity, at: time) }
    open func setCropRectangleRamp(fromStartCropRectangle startCropRectangle: CGRect, toEndCropRectangle endCropRectangle: CGRect, timeRange: CMTimeRange) {
        _crops.ramp(startCropRectangle, endCropRectangle, timeRange)
    }
    open func setCropRectangle(_ cropRectangle: CGRect, at time: CMTime) { _crops.set(cropRectangle, at: time) }
}

@available(iOS 26.0, *)
extension AVVideoCompositionLayerInstruction {
    public struct TransformRamp: Sendable {
        public var timeRange: CMTimeRange
        public var start: CGAffineTransform
        public var end: CGAffineTransform
        public init(timeRange: CMTimeRange, start: CGAffineTransform, end: CGAffineTransform) { self.timeRange = timeRange; self.start = start; self.end = end }
    }
    public struct OpacityRamp: Sendable {
        public var timeRange: CMTimeRange
        public var start: Float
        public var end: Float
        public init(timeRange: CMTimeRange, start: Float, end: Float) { self.timeRange = timeRange; self.start = start; self.end = end }
    }
    public struct CropRectangleRamp: Sendable {
        public var timeRange: CMTimeRange
        public var start: CGRect
        public var end: CGRect
        public init(timeRange: CMTimeRange, start: CGRect, end: CGRect) { self.timeRange = timeRange; self.start = start; self.end = end }
    }
    public struct Configuration {
        public var trackID: CMPersistentTrackID
        var _transforms = _AVRamps<CGAffineTransform>()
        var _opacities = _AVRamps<Float>()
        var _crops = _AVRamps<CGRect>()
        public init(assetTrack: AVAssetTrack) { trackID = assetTrack.trackID }
        public init(trackID: CMPersistentTrackID) { self.trackID = trackID }
        public mutating func setTransform(_ transform: CGAffineTransform, at time: CMTime) { _transforms.set(transform, at: time) }
        public mutating func addTransformRamp(_ ramp: TransformRamp) { _transforms.ramp(ramp.start, ramp.end, ramp.timeRange) }
        public func transformRamp(at time: CMTime) -> TransformRamp? {
            _transforms.ramp(at: time, default: .identity).map { TransformRamp(timeRange: $0.range, start: $0.from, end: $0.to) }
        }
        public mutating func setOpacity(_ opacity: Float, at time: CMTime) { _opacities.set(opacity, at: time) }
        public mutating func addOpacityRamp(_ ramp: OpacityRamp) { _opacities.ramp(ramp.start, ramp.end, ramp.timeRange) }
        public func opacityRamp(at time: CMTime) -> OpacityRamp? {
            _opacities.ramp(at: time, default: 1).map { OpacityRamp(timeRange: $0.range, start: $0.from, end: $0.to) }
        }
        public mutating func setCropRectangle(_ cropRectangle: CGRect, at time: CMTime) { _crops.set(cropRectangle, at: time) }
        public mutating func addCropRectangleRamp(_ ramp: CropRectangleRamp) { _crops.ramp(ramp.start, ramp.end, ramp.timeRange) }
        public func cropRectangleRamp(at time: CMTime) -> CropRectangleRamp? {
            _crops.ramp(at: time, default: .infinite).map { CropRectangleRamp(timeRange: $0.range, start: $0.from, end: $0.to) }
        }
    }
    public convenience init(configuration: Configuration) {
        self.init()
        _trackID = configuration.trackID; _transforms = configuration._transforms; _opacities = configuration._opacities; _crops = configuration._crops
    }
    public func transformRamp(at time: CMTime) -> TransformRamp? {
        _transforms.ramp(at: time, default: .identity).map { TransformRamp(timeRange: $0.range, start: $0.from, end: $0.to) }
    }
    public func opacityRamp(at time: CMTime) -> OpacityRamp? {
        _opacities.ramp(at: time, default: 1).map { OpacityRamp(timeRange: $0.range, start: $0.from, end: $0.to) }
    }
    public func cropRectangleRamp(at time: CMTime) -> CropRectangleRamp? {
        _crops.ramp(at: time, default: .infinite).map { CropRectangleRamp(timeRange: $0.range, start: $0.from, end: $0.to) }
    }
}

// MARK: - custom compositors

public struct AVPixelAspectRatio: Sendable, Hashable {
    public var horizontalSpacing: Int
    public var verticalSpacing: Int
    public init() { horizontalSpacing = 0; verticalSpacing = 0 }
    public init(horizontalSpacing: Int, verticalSpacing: Int) { self.horizontalSpacing = horizontalSpacing; self.verticalSpacing = verticalSpacing }
}
public struct AVEdgeWidths: Sendable, Hashable {
    public var left: CGFloat
    public var top: CGFloat
    public var right: CGFloat
    public var bottom: CGFloat
    public init() { left = 0; top = 0; right = 0; bottom = 0 }
    public init(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) { self.left = left; self.top = top; self.right = right; self.bottom = bottom }
}

public protocol AVVideoCompositing: NSObjectProtocol, Sendable {
    var sourcePixelBufferAttributes: [String: any Sendable]? { get }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] { get }
    var supportsWideColorSourceFrames: Bool { get }
    var supportsHDRSourceFrames: Bool { get }
    var canConformColorOfSourceFrames: Bool { get }
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext)
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest)
    func cancelAllPendingVideoCompositionRequests()
    func anticipateRendering(using renderHint: AVVideoCompositionRenderHint)
    func prerollForRendering(using renderHint: AVVideoCompositionRenderHint)
}
extension AVVideoCompositing {
    public var supportsWideColorSourceFrames: Bool { false }
    public var supportsHDRSourceFrames: Bool { false }
    public var canConformColorOfSourceFrames: Bool { false }
    public func cancelAllPendingVideoCompositionRequests() {}
    public func anticipateRendering(using renderHint: AVVideoCompositionRenderHint) {}
    public func prerollForRendering(using renderHint: AVVideoCompositionRenderHint) {}
}

open class AVVideoCompositionRenderHint: NSObject, @unchecked Sendable {
    let _start: CMTime, _end: CMTime
    init(start: CMTime, end: CMTime) { _start = start; _end = end }
    open var startCompositionTime: CMTime { _start }
    open var endCompositionTime: CMTime { _end }
}

/// The output frames' size and the pool they come from.
open class AVVideoCompositionRenderContext: NSObject, @unchecked Sendable {
    let _size: CGSize
    let _composition: AVVideoComposition
    let _format: OSType
    init(size: CGSize, composition: AVVideoComposition, format: OSType) { _size = size; _composition = composition; _format = format }
    open var size: CGSize { _size }
    open var renderTransform: CGAffineTransform { .identity }
    open var renderScale: Float { _composition.renderScale }
    open var pixelAspectRatio: AVPixelAspectRatio { AVPixelAspectRatio(horizontalSpacing: 1, verticalSpacing: 1) }
    open var edgeWidths: AVEdgeWidths { AVEdgeWidths() }
    open var highQualityRendering: Bool { true }
    open var videoComposition: AVVideoComposition { _composition }
    /// a frame of the render size (32BGRA, or 420 when the compositor's required attributes ask for it)
    open func newPixelBuffer() -> CVPixelBuffer? { CVBuffer(_width: Int(_size.width), height: Int(_size.height), format: _format) }
}

/// One output frame to compose: the source frames of the instruction's tracks at `compositionTime`.
open class AVAsynchronousVideoCompositionRequest: NSObject, NSCopying, @unchecked Sendable {
    let _context: AVVideoCompositionRenderContext
    let _time: CMTime
    let _instruction: any AVVideoCompositionInstructionProtocol
    let _frames: [CMPersistentTrackID: CVPixelBuffer]
    let _done: (Result<CVPixelBuffer, Error>?) -> Void
    let _lock = NSLock()
    var _finished = false
    init(context: AVVideoCompositionRenderContext, time: CMTime, instruction: any AVVideoCompositionInstructionProtocol,
         frames: [CMPersistentTrackID: CVPixelBuffer], done: @escaping (Result<CVPixelBuffer, Error>?) -> Void) {
        _context = context; _time = time; _instruction = instruction; _frames = frames; _done = done
    }
    open var renderContext: AVVideoCompositionRenderContext { _context }
    open var compositionTime: CMTime { _time }
    open var videoCompositionInstruction: any AVVideoCompositionInstructionProtocol { _instruction }
    open var sourceTrackIDs: [NSNumber] { _frames.keys.sorted().map { NSNumber(value: $0) } }
    open var sourceSampleDataTrackIDs: [CMPersistentTrackID] { [] }
    open func sourceFrame(byTrackID trackID: CMPersistentTrackID) -> CVPixelBuffer? { _frames[trackID] }
    /// isim: no timed sample data (metadata) tracks are passed to compositors
    open func sourceSampleBuffer(byTrackID trackID: CMPersistentTrackID) -> CMSampleBuffer? { nil }
    open func sourceTimedMetadata(byTrackID trackID: CMPersistentTrackID) -> AVTimedMetadataGroup? { nil }
    func _finish(_ r: Result<CVPixelBuffer, Error>?) {
        _lock.lock()
        let first = !_finished
        _finished = true
        _lock.unlock()
        if first { _done(r) }
    }
    open func finish(withComposedVideoFrame composedVideoFrame: CVPixelBuffer) { _finish(.success(composedVideoFrame)) }
    open func finish(with error: any Error) { _finish(.failure(error)) }
    open func finishCancelledRequest() { _finish(nil) }
    open func copy(with zone: NSZone? = nil) -> Any { self }
}

/// Core Image filtering (AVVideoComposition(asset:applyingCIFiltersWithHandler:)): the frame as a CIImage.
open class AVAsynchronousCIImageFilteringRequest: NSObject, NSCopying, @unchecked Sendable {
    let _size: CGSize, _time: CMTime, _image: CIImage
    let _done: (Result<(CIImage, CIContext?), Error>) -> Void
    var _finished = false
    init(size: CGSize, time: CMTime, image: CIImage, done: @escaping (Result<(CIImage, CIContext?), Error>) -> Void) {
        _size = size; _time = time; _image = image; _done = done
    }
    open var renderSize: CGSize { _size }
    open var compositionTime: CMTime { _time }
    open var sourceImage: CIImage { _image }
    open func finish(with filteredImage: CIImage, context: CIContext?) {
        guard !_finished else { return }
        _finished = true; _done(.success((filteredImage, context)))
    }
    open func finish(with error: any Error) {
        guard !_finished else { return }
        _finished = true; _done(.failure(error))
    }
    open func copy(with zone: NSZone? = nil) -> Any { self }
}

/// iOS 26: the frame handed to AVVideoComposition(applyingFiltersTo:applier:)'s applier
public struct AVCIImageFilteringParameters: @unchecked Sendable {
    public let sourceImage: CIImage
    public let compositionTime: CMTime
    public let renderSize: CGSize
}
/// iOS 26: the applier's filtered frame, rendered with `ciContext` (or a default context)
public struct AVCIImageFilteringResult: @unchecked Sendable {
    public let resultImage: CIImage
    public let ciContext: CIContext?
    public init(resultImage: CIImage, ciContext: CIContext? = nil) { self.resultImage = resultImage; self.ciContext = ciContext }
}

// MARK: - the Core Animation tool

/// Core Animation in exported video: the composed frame shown in the video layers of a layer tree drawn over it
/// (post-processing), or a layer rendered as an extra source track.
open class AVVideoCompositionCoreAnimationTool: NSObject, @unchecked Sendable {
    let _videoLayers: [CALayer]
    let _containing: CALayer?
    let _additional: CALayer?
    let _additionalTrackID: CMPersistentTrackID
    init(videoLayers: [CALayer], containing: CALayer?, additional: CALayer?, trackID: CMPersistentTrackID) {
        _videoLayers = videoLayers; _containing = containing; _additional = additional; _additionalTrackID = trackID
        super.init()
        for l in [containing, additional].compactMap({ $0 }) { _AVLayerTree.mark(l) }
    }
    public convenience init(additionalLayer layer: CALayer, asTrackID trackID: CMPersistentTrackID) {
        self.init(videoLayers: [], containing: nil, additional: layer, trackID: trackID)
    }
    public convenience init(postProcessingAsVideoLayer videoLayer: CALayer, in animationLayer: CALayer) {
        self.init(videoLayers: [videoLayer], containing: animationLayer, additional: nil, trackID: kCMPersistentTrackID_Invalid)
    }
    public convenience init(postProcessingAsVideoLayers videoLayers: [CALayer], in animationLayer: CALayer) {
        self.init(videoLayers: videoLayers, containing: animationLayer, additional: nil, trackID: kCMPersistentTrackID_Invalid)
    }
}

@available(iOS 26.0, *)
extension AVVideoCompositionCoreAnimationTool {
    public struct Configuration {
        public var containingLayer: CALayer
        public var layers: [CALayer]
        public init(postProcessingAsVideoLayer videoLayer: CALayer, containingLayer: CALayer) { self.containingLayer = containingLayer; layers = [videoLayer] }
        public init(postProcessingAsVideoLayers videoLayers: [CALayer], containingLayer: CALayer) { self.containingLayer = containingLayer; layers = videoLayers }
    }
    public convenience init(configuration: Configuration) {
        self.init(videoLayers: configuration.layers, containing: configuration.containingLayer, additional: nil, trackID: kCMPersistentTrackID_Invalid)
    }
}

/// Draws a tool's layer tree at a video time (CoreAnimation.m), on the main thread like the rest of the layer rendering.
enum _AVLayerTree {
    static func onMain<T>(_ f: () -> T) -> T { Thread.isMainThread ? f() : DispatchQueue.main.sync(execute: f) }
    static func mark(_ l: CALayer) {
        let s = NSSelectorFromString("_isimSetVideoCompositionTree:")
        guard l.responds(to: s) else { return }
        typealias Send = @convention(c) (AnyObject, Selector, Bool) -> Void
        unsafeBitCast(l.method(for: s), to: Send.self)(l, s, true)
    }
    /// the layer `l` (its bounds) drawn `t` seconds into the video into a BGRA frame of w x h
    static func render(_ l: CALayer, at t: Double, into px: UnsafeMutableRawPointer, width w: Int, height h: Int, bytesPerRow bpr: Int) {
        onMain {
            guard let ctx = CGContext(data: px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return }
            ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)        // top-left origin, as layers draw
            let s = NSSelectorFromString("_isimRenderInContext:atTime:")
            if l.responds(to: s) {
                typealias Send = @convention(c) (AnyObject, Selector, CGContext, Double) -> Void
                unsafeBitCast(l.method(for: s), to: Send.self)(l, s, ctx, t)
            } else { l.render(in: ctx) }
        }
    }
}

// MARK: - validation

public protocol AVVideoCompositionValidationHandling: NSObjectProtocol {
    func videoComposition(_ videoComposition: AVVideoComposition, shouldContinueValidatingAfterFindingInvalidValueForKey key: String) -> Bool
    func videoComposition(_ videoComposition: AVVideoComposition, shouldContinueValidatingAfterFindingEmptyTimeRange timeRange: CMTimeRange) -> Bool
    func videoComposition(_ videoComposition: AVVideoComposition,
                          shouldContinueValidatingAfterFindingInvalidTimeRangeIn videoCompositionInstruction: any AVVideoCompositionInstructionProtocol) -> Bool
    func videoComposition(_ videoComposition: AVVideoComposition,
                          shouldContinueValidatingAfterFindingInvalidTrackIDIn videoCompositionInstruction: any AVVideoCompositionInstructionProtocol,
                          layerInstruction: AVVideoCompositionLayerInstruction, asset: AVAsset) -> Bool
}
extension AVVideoCompositionValidationHandling {
    public func videoComposition(_ videoComposition: AVVideoComposition, shouldContinueValidatingAfterFindingInvalidValueForKey key: String) -> Bool { true }
    public func videoComposition(_ videoComposition: AVVideoComposition, shouldContinueValidatingAfterFindingEmptyTimeRange timeRange: CMTimeRange) -> Bool { true }
    public func videoComposition(_ videoComposition: AVVideoComposition,
                                 shouldContinueValidatingAfterFindingInvalidTimeRangeIn videoCompositionInstruction: any AVVideoCompositionInstructionProtocol) -> Bool { true }
    public func videoComposition(_ videoComposition: AVVideoComposition,
                                 shouldContinueValidatingAfterFindingInvalidTrackIDIn videoCompositionInstruction: any AVVideoCompositionInstructionProtocol,
                                 layerInstruction: AVVideoCompositionLayerInstruction, asset: AVAsset) -> Bool { true }
}

// MARK: - the composition

open class AVVideoComposition: NSObject, NSCopying, NSMutableCopying, @unchecked Sendable {
    public struct PerFrameHDRDisplayMetadataPolicy: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let propagate = PerFrameHDRDisplayMetadataPolicy(rawValue: "PerFrameHDRDisplayMetadataPolicyPropagate")
        public static let generate = PerFrameHDRDisplayMetadataPolicy(rawValue: "PerFrameHDRDisplayMetadataPolicyGenerate")
    }
    open var renderSize: CGSize = .zero
    open var frameDuration = CMTime(value: 1, timescale: 30)
    open var renderScale: Float = 1
    var _instructions: [any AVVideoCompositionInstructionProtocol] = []
    var _animationTool: AVVideoCompositionCoreAnimationTool?
    var _compositorClass: (any AVVideoCompositing.Type)?
    var _colorPrimaries: String?, _colorTransferFunction: String?, _colorYCbCrMatrix: String?
    var _frameTimingTrackID = kCMPersistentTrackID_Invalid
    var _sampleDataTrackIDs: [CMPersistentTrackID] = []
    var _hdrPolicy = PerFrameHDRDisplayMetadataPolicy.propagate
    /// AVVideoComposition(asset:applyingCIFiltersWithHandler:)
    var _ciHandler: (@Sendable (AVAsynchronousCIImageFilteringRequest) -> Void)?
    public override init() { super.init() }
    open var instructions: [any AVVideoCompositionInstructionProtocol] { _instructions }
    open var animationTool: AVVideoCompositionCoreAnimationTool? { _animationTool }
    open var customVideoCompositorClass: (any AVVideoCompositing.Type)? { _compositorClass }
    open var colorPrimaries: String? { _colorPrimaries }
    open var colorTransferFunction: String? { _colorTransferFunction }
    open var colorYCbCrMatrix: String? { _colorYCbCrMatrix }
    open var sourceTrackIDForFrameTiming: CMPersistentTrackID { _frameTimingTrackID }
    open var sourceSampleDataTrackIDs: [CMPersistentTrackID] { _sampleDataTrackIDs }
    open var perFrameHDRDisplayMetadataPolicy: PerFrameHDRDisplayMetadataPolicy { _hdrPolicy }

    /// renders through isim's compositor (not just at a size and frame rate)
    var _composites: Bool { !_instructions.isEmpty || _animationTool != nil || _compositorClass != nil || _ciHandler != nil }

    func _copy<T: AVVideoComposition>(into c: T) -> T {
        c.renderSize = renderSize; c.frameDuration = frameDuration; c.renderScale = renderScale
        c._instructions = _instructions; c._animationTool = _animationTool; c._compositorClass = _compositorClass
        c._colorPrimaries = _colorPrimaries; c._colorTransferFunction = _colorTransferFunction; c._colorYCbCrMatrix = _colorYCbCrMatrix
        c._frameTimingTrackID = _frameTimingTrackID; c._sampleDataTrackIDs = _sampleDataTrackIDs; c._hdrPolicy = _hdrPolicy; c._ciHandler = _ciHandler
        return c
    }
    open func copy(with zone: NSZone? = nil) -> Any { _copy(into: AVVideoComposition()) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { _copy(into: AVMutableVideoComposition()) }

    /// render size (the first video track's natural size turned by its preferred transform), frame rate, and one
    /// instruction showing the video tracks (the first on top) at their preferred transforms
    func _fill(from asset: AVAsset, prototype: AVVideoCompositionInstruction? = nil) {
        let videos = asset.tracks(withMediaType: .video)
        if let v = videos.first {
            let r = CGRect(origin: .zero, size: v.naturalSize == .zero ? asset.naturalSize : v.naturalSize).applying(v.preferredTransform)
            renderSize = CGSize(width: abs(r.width), height: abs(r.height))
            if v.nominalFrameRate > 0 { frameDuration = CMTime(value: 1, timescale: Int32(v.nominalFrameRate.rounded())) }
        } else { renderSize = asset.naturalSize }
        let i = AVMutableVideoCompositionInstruction()
        i.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        i.backgroundColor = prototype?.backgroundColor
        i.enablePostProcessing = prototype?.enablePostProcessing ?? true
        i.layerInstructions = videos.map { t in
            let l = AVMutableVideoCompositionLayerInstruction(assetTrack: t)
            l.setTransform(t.preferredTransform, at: .zero)
            return l
        }
        _instructions = videos.isEmpty ? [] : [i]
    }
    public convenience init(propertiesOf asset: AVAsset) { self.init(); _fill(from: asset) }
    open class func videoComposition(withPropertiesOf asset: AVAsset, completionHandler: @escaping @Sendable (AVVideoComposition?, (any Error)?) -> Void) {
        let c = AVVideoComposition(propertiesOf: asset)
        DispatchQueue.global().async { completionHandler(c, nil) }
    }
    open class func videoComposition(withPropertiesOf asset: AVAsset) async throws -> AVVideoComposition { AVVideoComposition(propertiesOf: asset) }
    /// each frame of the asset's video passes through `applier` as a CIImage
    public convenience init(asset: AVAsset, applyingCIFiltersWithHandler applier: @escaping @Sendable (AVAsynchronousCIImageFilteringRequest) -> Void) {
        self.init(propertiesOf: asset)
        _ciHandler = applier
    }
    open class func videoComposition(with asset: AVAsset, applyingCIFiltersWithHandler applier: @escaping @Sendable (AVAsynchronousCIImageFilteringRequest) -> Void,
                                     completionHandler: @escaping @Sendable (AVVideoComposition?, (any Error)?) -> Void) {
        let c = AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: applier)
        DispatchQueue.global().async { completionHandler(c, nil) }
    }
    open class func videoComposition(with asset: AVAsset, applyingCIFiltersWithHandler applier: @escaping @Sendable (AVAsynchronousCIImageFilteringRequest) -> Void) async throws -> AVVideoComposition {
        AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: applier)
    }
    /// iOS 26: each frame passes through the async `applier`
    @available(iOS 26.0, *)
    public convenience init(applyingFiltersTo asset: AVAsset, applier: @escaping @Sendable (AVCIImageFilteringParameters) async throws -> AVCIImageFilteringResult) async throws {
        self.init(asset: asset) { req in
            let r = req
            let p = AVCIImageFilteringParameters(sourceImage: req.sourceImage, compositionTime: req.compositionTime, renderSize: req.renderSize)
            Task.detached {
                do { let out = try await applier(p); r.finish(with: out.resultImage, context: out.ciContext) }
                catch { r.finish(with: error) }
            }
        }
    }

    /// iOS's checks: a positive render size and frame duration, instructions in order without gaps or overlaps covering
    /// the time range, layer instructions naming tracks of the asset
    func _validate(tracks: [AVAssetTrack], duration: CMTime, timeRange: CMTimeRange, delegate: (any AVVideoCompositionValidationHandling)?) -> Bool {
        var ok = true
        func bad(_ go: Bool) -> Bool { ok = false; return go }
        if renderSize.width <= 0 || renderSize.height <= 0, !bad(delegate?.videoComposition(self, shouldContinueValidatingAfterFindingInvalidValueForKey: "renderSize") ?? false) { return false }
        if !(frameDuration.isNumeric && frameDuration.seconds > 0), !bad(delegate?.videoComposition(self, shouldContinueValidatingAfterFindingInvalidValueForKey: "frameDuration") ?? false) { return false }
        if _ciHandler != nil { return ok }
        let r0 = timeRange.start.isNumeric ? timeRange.start.seconds : 0
        let r1 = timeRange.end.isNumeric ? timeRange.end.seconds : (duration.isNumeric ? duration.seconds : 0)
        var t = r0
        for ins in _instructions {
            let a = ins.timeRange.start.seconds, b = ins.timeRange.end.seconds
            if !ins.timeRange.isValid || !(b > a) || a < t - 1e-6 {
                if !bad(delegate?.videoComposition(self, shouldContinueValidatingAfterFindingInvalidTimeRangeIn: ins) ?? false) { return false }
                continue
            }
            if a > t + 1e-6 && a > r0 && t < r1,
               !bad(delegate?.videoComposition(self, shouldContinueValidatingAfterFindingEmptyTimeRange: CMTimeRange(start: CMTime(seconds: t, preferredTimescale: 600), end: ins.timeRange.start)) ?? false) { return false }
            if let i = ins as? AVVideoCompositionInstruction {
                for l in i.layerInstructions where !tracks.contains(where: { $0.trackID == l.trackID }) && l.trackID != _animationTool?._additionalTrackID {
                    if !bad(delegate?.videoComposition(self, shouldContinueValidatingAfterFindingInvalidTrackIDIn: ins, layerInstruction: l,
                                                       asset: tracks.first?.asset ?? AVAsset(_url: nil)) ?? false) { return false }
                }
            }
            t = max(t, b)
        }
        if t < r1 - 1e-3,
           !bad(delegate?.videoComposition(self, shouldContinueValidatingAfterFindingEmptyTimeRange: CMTimeRange(start: CMTime(seconds: t, preferredTimescale: 600), end: CMTime(seconds: r1, preferredTimescale: 600))) ?? false) { return false }
        return ok
    }
    @available(iOS 18.0, *)
    open func isValid(for tracks: [AVAssetTrack], assetDuration duration: CMTime, timeRange: CMTimeRange, validationDelegate: (any AVVideoCompositionValidationHandling)?) -> Bool {
        _validate(tracks: tracks, duration: duration, timeRange: timeRange, delegate: validationDelegate)
    }
    open func isValid(for asset: AVAsset?, timeRange: CMTimeRange, validationDelegate: (any AVVideoCompositionValidationHandling)?) -> Bool {
        _validate(tracks: asset?.tracks ?? [], duration: asset?.duration ?? .zero, timeRange: timeRange, delegate: validationDelegate)
    }
    open func determineValidity(for asset: AVAsset?, timeRange: CMTimeRange, validationDelegate: (any AVVideoCompositionValidationHandling)?,
                                completionHandler: @escaping @Sendable (Bool, (any Error)?) -> Void) {
        let ok = isValid(for: asset, timeRange: timeRange, validationDelegate: validationDelegate)
        DispatchQueue.global().async { completionHandler(ok, nil) }
    }
    open func determineValidity(for asset: AVAsset?, timeRange: CMTimeRange, validationDelegate: (any AVVideoCompositionValidationHandling)?) async throws -> Bool {
        isValid(for: asset, timeRange: timeRange, validationDelegate: validationDelegate)
    }
}

open class AVMutableVideoComposition: AVVideoComposition, @unchecked Sendable {
    public override init() { super.init() }
    public convenience init(propertiesOf asset: AVAsset) { self.init(); _fill(from: asset) }
    public convenience init(propertiesOf asset: AVAsset, prototypeInstruction: AVVideoCompositionInstruction) {
        self.init(); _fill(from: asset, prototype: prototypeInstruction)
    }
    open override class func videoComposition(withPropertiesOf asset: AVAsset, completionHandler: @escaping @Sendable (AVMutableVideoComposition?, (any Error)?) -> Void) {
        let c = AVMutableVideoComposition(propertiesOf: asset)
        DispatchQueue.global().async { completionHandler(c, nil) }
    }
    open class func videoComposition(withPropertiesOf asset: AVAsset, prototypeInstruction: AVVideoCompositionInstruction,
                                     completionHandler: @escaping @Sendable (AVMutableVideoComposition?, (any Error)?) -> Void) {
        let c = AVMutableVideoComposition(propertiesOf: asset, prototypeInstruction: prototypeInstruction)
        DispatchQueue.global().async { completionHandler(c, nil) }
    }
    open override class func videoComposition(with asset: AVAsset, applyingCIFiltersWithHandler applier: @escaping @Sendable (AVAsynchronousCIImageFilteringRequest) -> Void,
                                              completionHandler: @escaping @Sendable (AVMutableVideoComposition?, (any Error)?) -> Void) {
        let c = AVMutableVideoComposition(asset: asset, applyingCIFiltersWithHandler: applier)
        DispatchQueue.global().async { completionHandler(c, nil) }
    }
    open override var instructions: [any AVVideoCompositionInstructionProtocol] { get { _instructions } set { _instructions = newValue } }
    open override var animationTool: AVVideoCompositionCoreAnimationTool? { get { _animationTool } set { _animationTool = newValue } }
    open override var customVideoCompositorClass: (any AVVideoCompositing.Type)? { get { _compositorClass } set { _compositorClass = newValue } }
    open override var colorPrimaries: String? { get { _colorPrimaries } set { _colorPrimaries = newValue } }
    open override var colorTransferFunction: String? { get { _colorTransferFunction } set { _colorTransferFunction = newValue } }
    open override var colorYCbCrMatrix: String? { get { _colorYCbCrMatrix } set { _colorYCbCrMatrix = newValue } }
    open override var sourceTrackIDForFrameTiming: CMPersistentTrackID { get { _frameTimingTrackID } set { _frameTimingTrackID = newValue } }
    open override var sourceSampleDataTrackIDs: [CMPersistentTrackID] { get { _sampleDataTrackIDs } set { _sampleDataTrackIDs = newValue } }
    open override var perFrameHDRDisplayMetadataPolicy: PerFrameHDRDisplayMetadataPolicy { get { _hdrPolicy } set { _hdrPolicy = newValue } }
}

// MARK: - isim's compositor

/// isim's built-in compositor: AVVideoCompositionInstruction's layers drawn with Core Graphics.
final class _AVBuiltInCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    var sourcePixelBufferAttributes: [String: any Sendable]? { [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA] }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] { [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA] }
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let ins = request.videoCompositionInstruction as? AVVideoCompositionInstruction else {
            request.finish(with: _avNSError(.invalidVideoComposition, "isim's video compositor takes AVVideoCompositionInstruction; set customVideoCompositorClass for other instructions"))
            return
        }
        guard let out = request.renderContext.newPixelBuffer(), let base = CVPixelBufferGetBaseAddress(out) else {
            request.finish(with: _avNSError(.exportFailed, "no output frame")); return
        }
        let w = CVPixelBufferGetWidth(out), h = CVPixelBufferGetHeight(out), t = request.compositionTime.seconds
        guard let ctx = CGContext(data: base, width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(out), space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            request.finish(with: _avNSError(.exportFailed, "no drawing context")); return
        }
        ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)        // video coordinates: origin at the top left
        ctx.setFillColor(ins.backgroundColor ?? CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        for l in ins.layerInstructions.reversed() {                       // the first layer instruction is on top
            guard let src = request.sourceFrame(byTrackID: l.trackID), let img = _avImage(src) else { continue }
            let a = l._opacity(at: t)
            guard a > 0 else { continue }
            ctx.saveGState()
            ctx.concatenate(l._transform(at: t))
            if let c = l._crop(at: t) { ctx.clip(to: c) }
            ctx.setAlpha(CGFloat(min(1, a)))
            ctx.interpolationQuality = .high
            let sh = CGFloat(img.height)
            ctx.translateBy(x: 0, y: sh); ctx.scaleBy(x: 1, y: -1)
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: CGFloat(img.width), height: sh))
            ctx.restoreGState()
        }
        request.finish(withComposedVideoFrame: out)
    }
}

/// a CGImage of a pixel buffer's pixels (copied)
func _avImage(_ pb: CVPixelBuffer) -> CGImage? {
    let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
    let data = Data(pb._bgra()) as CFData
    guard w > 0, h > 0, let provider = CGDataProvider(data: data) else { return nil }
    return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
}

/// One source video track decoded at the output frame rate, read in step with the output frames.
final class _AVSourceFrames {
    let trackID: CMPersistentTrackID
    let w: Int, h: Int
    var handle: Int32 = 0
    var temp: URL?
    var current: CVPixelBuffer?
    var ended = false
    let present: (Double) -> Bool
    let format: OSType
    init(trackID: CMPersistentTrackID, width: Int, height: Int, format: OSType, present: @escaping (Double) -> Bool) {
        self.trackID = trackID; w = width; h = height; self.format = format; self.present = present
    }
    deinit {
        if handle > 0 { isim_media_reader_close(handle) }
        if let temp { try? FileManager.default.removeItem(at: temp) }
    }
    /// reads the next frame (call once per output frame)
    func advance() {
        guard handle > 0, !ended else { current = nil; return }
        let n = w * h * 4
        var px = [UInt8](repeating: 0, count: n)
        let got = px.withUnsafeMutableBytes { isim_media_reader_read(handle, $0.baseAddress!, n) }
        guard got == n else { ended = true; current = nil; return }
        current = px.withUnsafeBufferPointer { _pixelBuffer(fromBGRA: $0.baseAddress!, width: w, height: h, format: format) }
    }
    func frame(at t: Double) -> CVPixelBuffer? { present(t) ? current : nil }
}

extension AVAssetExportSession {
    /// The composed frames of [r0, r1] at the video composition's frame rate, spooled for ffmpeg (nil after _fail).
    func _composeFrames(_ vc: AVVideoComposition, from r0: Double, to r1: Double, size: CGSize) -> _RawVideoSink? {
        let fd = vc.frameDuration.isNumeric && vc.frameDuration.seconds > 0 ? vc.frameDuration : CMTime(value: 1, timescale: 30)
        let fr = 1 / fd.seconds
        let W = Int(size.width), H = Int(size.height)
        let tool = vc.animationTool
        guard vc.isValid(for: asset, timeRange: CMTimeRange(start: CMTime(seconds: r0, preferredTimescale: 600), end: CMTime(seconds: r1, preferredTimescale: 600)),
                         validationDelegate: nil), !vc._instructions.isEmpty || vc._ciHandler != nil else {
            _fail(_avNSError(.invalidVideoComposition, "the video composition is not valid for the asset (render size, frame duration, or instructions that do not cover the time range)"))
            return nil
        }
        // the compositor and its render context
        let compositor: any AVVideoCompositing
        if let c = _compositor { compositor = c }
        else if let k = vc.customVideoCompositorClass {
            guard let o = _avMakeCompositor(k) else {
                _fail(_avNSError(.invalidVideoComposition, "the custom video compositor class cannot be instantiated")); return nil
            }
            compositor = o
            _compositor = o
        } else { compositor = _AVBuiltInCompositor() }
        let wanted = compositor.requiredPixelBufferAttributesForRenderContext[kCVPixelBufferPixelFormatTypeKey as String]
        let outFormat = _avFormats(wanted).first { [kCVPixelFormatType_32BGRA, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange].contains($0) } ?? kCVPixelFormatType_32BGRA
        let srcFormat = _avFormats(compositor.sourcePixelBufferAttributes?[kCVPixelBufferPixelFormatTypeKey as String]).first ?? kCVPixelFormatType_32BGRA
        let context = AVVideoCompositionRenderContext(size: size, composition: vc, format: outFormat)
        compositor.renderContextChanged(context)
        let hint = AVVideoCompositionRenderHint(start: CMTime(seconds: r0, preferredTimescale: 600), end: CMTime(seconds: r1, preferredTimescale: 600))
        compositor.prerollForRendering(using: hint)
        // the source tracks
        var sources: [_AVSourceFrames] = []
        for track in asset.tracks(withMediaType: .video) {
            guard let s = _openSource(track, from: r0, to: r1, fps: fr, format: srcFormat) else {
                _fail(_avNSError(.decodeFailed, "isim could not decode video track \(track.trackID) (it needs ffmpeg on the host)")); return nil
            }
            sources.append(s)
        }
        let sink = _RawVideoSink(width: W, height: H)
        let n = max(1, Int(((r1 - r0) / fd.seconds - 1e-6).rounded(.up)))
        let ciContext = vc._ciHandler != nil ? CIContext() : nil
        var extra = [UInt8](repeating: 0, count: tool?._additional != nil ? W * H * 4 : 0)
        for i in 0..<n {
            if _cancel != 0 { return nil }
            let time = CMTime(seconds: r0, preferredTimescale: 600) + CMTimeMultiply(fd, multiplier: Int32(i))
            let t = time.seconds
            for s in sources { s.advance() }
            guard let ins = vc._instructions.first(where: { $0.timeRange.containsTime(time) }) ?? vc._instructions.last(where: { $0.timeRange.start <= time }) ?? vc._instructions.first else {
                _fail(_avNSError(.invalidVideoComposition, "no instruction at \(t) s")); return nil
            }
            var frames: [CMPersistentTrackID: CVPixelBuffer] = [:]
            let required = ins.requiredSourceTrackIDs?.compactMap { ($0 as? NSNumber)?.int32Value }
            for s in sources where required == nil || required!.contains(s.trackID) {
                if let f = s.frame(at: t) { frames[s.trackID] = f }
            }
            if let tool, let l = tool._additional {
                extra.withUnsafeMutableBytes { p in
                    memset(p.baseAddress!, 0, W * H * 4)
                    _AVLayerTree.render(l, at: t, into: p.baseAddress!, width: W, height: H, bytesPerRow: W * 4)
                }
                if let pb = extra.withUnsafeBufferPointer({ _pixelBuffer(fromBGRA: $0.baseAddress!, width: W, height: H, format: srcFormat) }) { frames[tool._additionalTrackID] = pb }
            }
            // compose
            var composed: CVPixelBuffer?
            if ins.passthroughTrackID != kCMPersistentTrackID_Invalid, let f = frames[ins.passthroughTrackID],
               CVPixelBufferGetWidth(f) == W, CVPixelBufferGetHeight(f) == H, tool == nil || !ins.enablePostProcessing {
                composed = f
            } else {
                let sem = DispatchSemaphore(value: 0)
                var result: Result<CVPixelBuffer, Error>??
                let req = AVAsynchronousVideoCompositionRequest(context: context, time: time, instruction: ins, frames: frames) { r in result = r; sem.signal() }
                compositor.startRequest(req)
                sem.wait()
                switch result {
                case .some(.some(.success(let pb))): composed = pb
                case .some(.some(.failure(let e))):
                    let ns = e as NSError
                    _fail(ns.domain == AVFoundationErrorDomain ? e : NSError(domain: AVFoundationErrorDomain, code: AVError.Code.videoCompositorFailed.rawValue,
                                                                              userInfo: [NSLocalizedDescriptionKey: "Operation Stopped", NSUnderlyingErrorKey: ns]))
                    return nil
                default: _cancel = 1; return nil                  // finishCancelledRequest
                }
            }
            guard var frame = composed else { return nil }
            // Core Image filtering
            if let handler = vc._ciHandler, let ciContext {
                let sem = DispatchSemaphore(value: 0)
                var result: Result<(CIImage, CIContext?), Error>?
                let req = AVAsynchronousCIImageFilteringRequest(size: size, time: time, image: CIImage(cvPixelBuffer: frame)) { r in result = r; sem.signal() }
                handler(req)
                sem.wait()
                switch result {
                case .some(.success(let (img, c))):
                    guard let out = CVBuffer(_width: W, height: H, format: kCVPixelFormatType_32BGRA) else { return nil }
                    (c ?? ciContext).render(img, to: out)
                    frame = out
                case .some(.failure(let e)): _fail(e); return nil
                case .none: return nil
                }
            }
            var px = frame._bgra()
            if CVPixelBufferGetWidth(frame) != W || CVPixelBufferGetHeight(frame) != H {
                _fail(_avNSError(.invalidVideoComposition, "the compositor returned a \(CVPixelBufferGetWidth(frame))x\(CVPixelBufferGetHeight(frame)) frame for a \(W)x\(H) render size"))
                return nil
            }
            // the Core Animation tool: the frame in the video layers, the layer tree drawn over it
            if let tool, let root = tool._containing, ins.enablePostProcessing {
                let img = _avImage(frame)
                _AVLayerTree.onMain {
                    CATransaction.begin(); CATransaction.setDisableActions(true)
                    for l in tool._videoLayers { l.contents = img }
                    CATransaction.commit()
                }
                px.withUnsafeMutableBytes { p in
                    memset(p.baseAddress!, 0, W * H * 4)
                    _AVLayerTree.render(root, at: t, into: p.baseAddress!, width: W, height: H, bytesPerRow: W * 4)
                }
            }
            px.withUnsafeBufferPointer { sink.append($0.baseAddress!, time: t) }
            _progress = Double(i + 1) / Double(n) * 0.9
        }
        compositor.cancelAllPendingVideoCompositionRequests()
        return sink
    }

    /// a source track's frames at the output rate: URL assets' first video track straight from the file, other tracks
    /// (composition tracks, further tracks of a file) rendered losslessly first
    func _openSource(_ track: AVAssetTrack, from r0: Double, to r1: Double, fps: Double, format: OSType) -> _AVSourceFrames? {
        var size = track.naturalSize == .zero ? asset.naturalSize : track.naturalSize
        if size == .zero { size = CGSize(width: 640, height: 360) }
        let w = max(2, Int(size.width)), h = max(2, Int(size.height))
        var present: (Double) -> Bool = { _ in true }
        if let ct = track as? AVCompositionTrack {
            let segs = ct._segments.filter { $0._url != nil }.map { ($0._target.start.seconds, $0._target.end.seconds) }
            present = { t in segs.contains { t >= $0.0 - 1e-6 && t < $0.1 - 1e-6 } }
        } else {
            let a = track.timeRange.start.isNumeric ? track.timeRange.start.seconds : 0
            let b = track.timeRange.end.isNumeric && track.timeRange.duration.seconds > 0 ? track.timeRange.end.seconds : .infinity
            present = { t in t >= a - 1e-6 && t < b }
        }
        let s = _AVSourceFrames(trackID: track.trackID, width: w, height: h, format: format, present: present)
        let ordinal = asset.tracks(withMediaType: .video).firstIndex { $0.trackID == track.trackID } ?? 0
        if !(asset is AVComposition), ordinal == 0, let u = asset._url {
            s.handle = isim_media_reader_open(_path(u), 0, r0, r1 - r0, Int32(w), Int32(h), fps, 0)
            return s.handle > 0 ? s : nil
        }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory() + "isim-track-\(UUID().uuidString).mkv")
        s.temp = tmp
        if asset is AVComposition {
            guard let sub = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
            let plain = AVMutableVideoComposition()
            plain.renderSize = CGSize(width: w, height: h); plain.frameDuration = CMTime(seconds: 1 / fps, preferredTimescale: 6000)
            sub.videoComposition = plain
            sub.outputURL = tmp; sub.outputFileType = .mov
            sub.timeRange = CMTimeRange(start: CMTime(seconds: r0, preferredTimescale: 600), end: CMTime(seconds: r1, preferredTimescale: 600))
            sub._lossless = true; sub._wantAudio = false; sub._videoTrackID = track.trackID
            sub._run()
            guard sub.status == .completed else { return nil }
        } else {
            guard let u = asset._url else { return nil }
            let args = ["-y", "-ss", String(format: "%.6f", r0), "-t", String(format: "%.6f", r1 - r0), "-i", _path(u), "-map", "0:v:\(ordinal)", "-an",
                        "-vf", "fps=\(fps),scale=\(w):\(h)", "-c:v", "ffv1", "-pix_fmt", "bgra", "-f", "matroska", tmp.path]
            guard _FFmpeg.run(args) == nil else { return nil }
        }
        s.handle = isim_media_reader_open(tmp.path, 0, 0, 0, Int32(w), Int32(h), fps, 0)
        return s.handle > 0 ? s : nil
    }
}

/// pixel formats named by a pixel buffer attribute (a number or an array of them)
func _avFormats(_ v: Any?) -> [OSType] {
    if let a = v as? [Any] { return a.flatMap { _avFormats($0) } }
    if let n = v as? NSNumber { return [OSType(truncatingIfNeeded: n.int64Value)] }
    if let n = v as? OSType { return [n] }
    if let n = v as? Int { return [OSType(truncatingIfNeeded: n)] }
    return []
}

func _avMakeCompositor(_ k: any AVVideoCompositing.Type) -> (any AVVideoCompositing)? { (k as? NSObject.Type)?.init() as? any AVVideoCompositing }

extension AVAssetImageGenerator {
    /// one frame composed at t (AVAssetExportSession's compositor over [t, t + frame duration])
    func _composedImage(_ vc: AVVideoComposition, at t: Double, actualTime: UnsafeMutablePointer<CMTime>?) throws -> CGImage {
        guard let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { throw _avLoadError(asset) }
        if _compositor == nil, let k = vc.customVideoCompositorClass { _compositor = _avMakeCompositor(k) }
        s._compositor = _compositor
        let fd = vc.frameDuration.isNumeric && vc.frameDuration.seconds > 0 ? vc.frameDuration.seconds : 1.0 / 30
        let d = asset.duration.seconds
        let t0 = d.isFinite && d > 0 ? min(t, max(0, d - fd)) : t
        let size = s._outputSize(asset.naturalSize)
        guard let sink = s._composeFrames(vc, from: t0, to: t0 + fd, size: size) else { throw s.error ?? _avLoadError(asset) }
        let n = sink.width * sink.height * 4
        _ = sink.inputArgs()                                   // flushes the spool
        guard let data = FileManager.default.contents(atPath: sink.path), data.count >= n else { throw _avLoadError(asset) }
        var px = [UInt8](data.prefix(n))
        guard let pb = px.withUnsafeMutableBufferPointer({ _pixelBuffer(fromBGRA: $0.baseAddress!, width: sink.width, height: sink.height, format: kCVPixelFormatType_32BGRA) }),
              var img = _avImage(pb) else { throw _avLoadError(asset) }
        if maximumSize.width > 0 || maximumSize.height > 0 {      // fitted inside maximumSize, like iOS
            let mw = maximumSize.width > 0 ? maximumSize.width : .infinity, mh = maximumSize.height > 0 ? maximumSize.height : .infinity
            let f = min(1, min(mw / CGFloat(img.width), mh / CGFloat(img.height)))
            let w = max(1, Int((CGFloat(img.width) * f).rounded())), h = max(1, Int((CGFloat(img.height) * f).rounded()))
            if f < 1, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                ctx.interpolationQuality = .high
                ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
                if let scaled = ctx.makeImage() { img = scaled }
            }
        }
        px.removeAll()
        actualTime?.pointee = CMTime(seconds: t0, preferredTimescale: 600)
        return img
    }
}
