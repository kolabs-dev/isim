// isim Vision: what the iOS 18 Swift requests share (issue #852): compute devices (kept per stage, not used: isim runs
// every request on the CPU), StatefulRequest, TargetedRequest and TargetedImageRequestHandler, CoreMLModelContainer,
// VideoProcessor (the video's frames from AVAssetImageGenerator at each request's cadence); the iOS 26 lens smudge
// heuristic and the iOS 27 GenerateIterativeSegmentationRequest (region growing from the seeds) and
// DownloadableAssetsRequest (isim's engines need no downloads: always ready).
import UIKit
import CoreImage
import CoreML
import AVFoundation

// MARK: - compute devices

/// A request's compute devices; requests compare equal whatever their devices.
struct _VNDevices: Hashable, @unchecked Sendable {
    var map: [ComputeStage: MLComputeDevice] = [:]
    static func == (a: _VNDevices, b: _VNDevices) -> Bool { true }
    func hash(into h: inout Hasher) {}
}
protocol _VNComputeDevices {
    var _devices: _VNDevices { get set }
}
extension VisionRequest {
    public var supportedComputeStageDevices: [ComputeStage: [MLComputeDevice]] {
        [.main: [.cpu(MLCPUComputeDevice())], .postProcessing: [.cpu(MLCPUComputeDevice())]]
    }
    public func computeDevice(for computeStage: ComputeStage) -> MLComputeDevice? { (self as? _VNComputeDevices)?._devices.map[computeStage] }
    public mutating func setComputeDevice(_ computeDevice: MLComputeDevice?, for computeStage: ComputeStage) {
        guard var s = self as? _VNComputeDevices else { return }
        s._devices.map[computeStage] = computeDevice
        if let back = s as? Self { self = back }
    }
}

// MARK: - stateful and targeted requests

/// Requests that look at a sequence of frames and keep state between them (classes: perform the same one on each frame).
public protocol StatefulRequest: VisionRequest {
    var frameAnalysisSpacing: CMTime { get }
    var minimumLatencyFrameCount: Int { get }
}
extension StatefulRequest {
    public var minimumLatencyFrameCount: Int { 1 }
    /// the same request (stateful requests are compared by identity)
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if Self.self is AnyClass { return (lhs as AnyObject) === (rhs as AnyObject) }
        return lhs.descriptor == rhs.descriptor
    }
    public func hash(into hasher: inout Hasher) {
        if Self.self is AnyClass { hasher.combine(ObjectIdentifier(self as AnyObject)) } else { hasher.combine(descriptor) }
    }
}

/// Requests that compare two images: the handler's source with its target.
public protocol TargetedRequest: VisionRequest {}

/// Performs targeted requests on two images (isim: Apple's SDK has no targeted request types yet, so every request
/// throws VisionError.unsupportedRequest).
public final class TargetedImageRequestHandler: @unchecked Sendable {
    let _source: () -> VNImageRequestHandler
    let _target: () -> VNImageRequestHandler
    init(_ s: @escaping () -> VNImageRequestHandler, _ t: @escaping () -> VNImageRequestHandler) { _source = s; _target = t }
    public convenience init(source: CGImage, target: CGImage, orientation: CGImagePropertyOrientation? = nil) {
        self.init({ VNImageRequestHandler(cgImage: source, orientation: orientation ?? .up) }, { VNImageRequestHandler(cgImage: target, orientation: orientation ?? .up) })
    }
    public convenience init(source: CIImage, target: CIImage, orientation: CGImagePropertyOrientation? = nil) {
        self.init({ VNImageRequestHandler(ciImage: source, orientation: orientation ?? .up) }, { VNImageRequestHandler(ciImage: target, orientation: orientation ?? .up) })
    }
    public convenience init(source: CVPixelBuffer, target: CVPixelBuffer, orientation: CGImagePropertyOrientation? = nil) {
        self.init({ VNImageRequestHandler(cvPixelBuffer: source, orientation: orientation ?? .up) }, { VNImageRequestHandler(cvPixelBuffer: target, orientation: orientation ?? .up) })
    }
    public convenience init(source: CMSampleBuffer, target: CMSampleBuffer, orientation: CGImagePropertyOrientation? = nil) {
        self.init({ VNImageRequestHandler(cmSampleBuffer: source, orientation: orientation ?? .up) }, { VNImageRequestHandler(cmSampleBuffer: target, orientation: orientation ?? .up) })
    }
    public convenience init(source: Data, target: Data, orientation: CGImagePropertyOrientation? = nil) {
        self.init({ VNImageRequestHandler(data: source, orientation: orientation ?? .up) }, { VNImageRequestHandler(data: target, orientation: orientation ?? .up) })
    }
    public convenience init(sourceURL: URL, targetURL: URL, orientation: CGImagePropertyOrientation? = nil) {
        self.init({ VNImageRequestHandler(url: sourceURL, orientation: orientation ?? .up) }, { VNImageRequestHandler(url: targetURL, orientation: orientation ?? .up) })
    }
    func _unsupported(_ request: any TargetedRequest) -> VisionError { VisionError.unsupportedRequest("\(request) is not supported on isim") }
    public func perform<T: TargetedRequest>(_ request: T) async throws -> T.Result { throw _unsupported(request) }
    func _one<T: TargetedRequest>(_ request: T) throws -> T.Result { throw _unsupported(request) }
    public func perform<each T: TargetedRequest>(_ request: repeat each T) async throws -> (repeat (each T).Result) {
        (repeat try _one(each request))
    }
    @available(iOS 18.0, *)
    public func performAll(_ requests: some Collection<any TargetedRequest>) -> some AsyncSequence<VisionResult, Never> {
        let results: [VisionResult] = requests.map { .error($0, _unsupported($0)) }
        return AsyncStream<VisionResult> { c in
            for r in results { c.yield(r) }
            c.finish()
        }
    }
}

// MARK: - Core ML

/// A Core ML model for CoreMLRequest (isim: its requests fail with unsupportedRequest: no Apple model runtime).
public struct CoreMLModelContainer: @unchecked Sendable {
    let model: MLModel
    public var inputImageFeatureName: String
    let featureProvider: (any MLFeatureProvider)?
    public init(model: MLModel, featureProvider: (any MLFeatureProvider)? = nil) throws {
        self.model = model; self.featureProvider = featureProvider
        inputImageFeatureName = model.modelDescription.inputDescriptionsByName.values.first { $0.type == .image }?.name ?? ""
    }
}

// MARK: - helpers for the generated requests

/// the observation as a VN one, keeping its uuid (the trackers report it)
func _vnObject(_ o: any BoundingBoxProviding & VisionObservation) -> VNDetectedObjectObservation {
    let v = VNDetectedObjectObservation(boundingBox: o.boundingBox.cgRect)
    v._uuid = o.uuid
    return v
}
func _vnQuad(_ o: any QuadrilateralProviding & VisionObservation) -> VNRectangleObservation {
    let v = VNRectangleObservation(requestRevision: 1, topLeft: o.topLeft.cgPoint, topRight: o.topRight.cgPoint,
                                   bottomRight: o.bottomRight.cgPoint, bottomLeft: o.bottomLeft.cgPoint)
    v._uuid = o.uuid
    return v
}
extension VNImageRequestHandler {
    /// the handler's image, oriented and cropped to the region of interest
    func _image(_ roi: CGRect) throws -> _VNImage {
        guard let img = _load() else { throw VisionError.invalidImage("the image could not be read") }
        return img.oriented(_orientation).cropped(roi).0
    }
}

/// isim's lens smudge heuristic: a smudged lens blurs the whole picture, so the confidence falls as the image's
/// sharpness (the variance of its Laplacian, on luma at 256 pixels) rises.
func _vnSmudge(_ img: _VNImage) -> Float {
    let s = max(1, max(img.width, img.height) / 256), W = img.width / s, H = img.height / s
    guard W > 2, H > 2 else { return 0 }
    var g = [Float](repeating: 0, count: W * H)
    for y in 0..<H { for x in 0..<W {
        let i = ((y * s) * img.width + x * s) * 4
        g[y * W + x] = (0.114 * Float(img.bgra[i]) + 0.587 * Float(img.bgra[i + 1]) + 0.299 * Float(img.bgra[i + 2])) / 255
    } }
    var sum: Float = 0, sum2: Float = 0, n: Float = 0
    for y in 1..<(H - 1) { for x in 1..<(W - 1) {
        let l = 4 * g[y * W + x] - g[y * W + x - 1] - g[y * W + x + 1] - g[(y - 1) * W + x] - g[(y + 1) * W + x]
        sum += l; sum2 += l * l; n += 1
    } }
    let variance = sum2 / n - (sum / n) * (sum / n)
    return max(0, min(1, 1 - variance / 0.002))
}

// MARK: - video

/// Runs requests on a video's frames.
public final class VideoProcessor: @unchecked Sendable {
    public enum Cadence: Hashable, Sendable { case frameInterval(Int), timeInterval(CMTime) }
    struct _Entry {
        let request: any VisionRequest
        let key: AnyHashable
        let cadence: Cadence?
        let deliver: (Any?, Error?) -> Void
        let finish: (Error?) -> Void
    }
    let _url: URL
    var _entries: [_Entry] = []
    var _task: Task<Void, Never>?
    let _lock = NSLock()
    public init(_ videoURL: URL) { _url = videoURL }
    /// the request's results, one per analysed frame, as the analysis goes
    @available(iOS 18.0, *)
    public func addRequest<T: VisionRequest>(_ request: T, cadence: Cadence? = nil) async throws -> some AsyncSequence<T.Result, any Error> {
        guard request is _VNSwiftRequest else { throw VisionError.unsupportedRequest("\(request) is not supported on isim") }
        let (stream, c) = AsyncThrowingStream<T.Result, any Error>.makeStream()
        _lock.lock(); defer { _lock.unlock() }
        guard !_entries.contains(where: { $0.key == AnyHashable(request) }) else { throw VisionError.invalidOperation("the request is already added") }
        _entries.append(_Entry(request: request, key: AnyHashable(request), cadence: cadence,
                               deliver: { v, e in if let e { c.finish(throwing: e) } else if let v = v as? T.Result { c.yield(v) } },
                               finish: { e in c.finish(throwing: e) }))
        return stream
    }
    public func removeRequest(_ request: any VisionRequest) async -> Bool {
        _lock.lock(); defer { _lock.unlock() }
        guard let i = _entries.firstIndex(where: { $0.key == AnyHashable(request) }) else { return false }
        _entries.remove(at: i).finish(nil)
        return true
    }
    public func cancel() async {
        _lock.lock(); let t = _task; _lock.unlock()
        t?.cancel()
        await t?.value
    }
    /// starts analysing the frames of the time range (the whole video by default) in the background
    public func startAnalysis(of timeRange: CMTimeRange? = nil) {
        _lock.lock(); defer { _lock.unlock() }
        guard _task == nil else { return }
        let url = _url
        _task = Task.detached { [self] in
            let asset = AVURLAsset(url: url)
            guard let track = asset.tracks(withMediaType: .video).first else {
                self._finishAll(VisionError.invalidImage("the video has no video track")); return
            }
            let fps = Double(track.nominalFrameRate > 0 ? track.nominalFrameRate : 30)
            let start = timeRange.map { $0.start.isNumeric ? $0.start.seconds : 0 } ?? 0
            let end = timeRange.flatMap { $0.duration.isNumeric && $0.duration.seconds > 0 ? start + $0.duration.seconds : nil } ?? asset.duration.seconds
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            var next: [AnyHashable: Double] = [:]
            var t = start
            while t < end, !Task.isCancelled {
                self._lock.lock(); let entries = self._entries; self._lock.unlock()
                if entries.isEmpty { break }
                let due = entries.filter { (next[$0.key] ?? start) <= t + 1e-6 }
                if !due.isEmpty {
                    guard let frame = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) else { break }
                    let h = VNImageRequestHandler(cgImage: frame)
                    for e in due {
                        do { e.deliver(try (e.request as! _VNSwiftRequest)._run(h), nil) } catch { e.deliver(nil, VisionError._from(error)) }
                        let step: Double
                        switch e.cadence {
                        case .frameInterval(let n)?: step = Double(max(1, n)) / fps
                        case .timeInterval(let d)?: step = max(0.001, d.seconds)
                        case nil: step = 1 / fps
                        }
                        next[e.key] = t + step
                    }
                }
                t = entries.map { next[$0.key] ?? start }.min() ?? end
            }
            self._finishAll(Task.isCancelled ? VisionError.requestCancelled("the analysis was cancelled") : nil)
        }
    }
    func _finishAll(_ e: Error?) {
        _lock.lock(); let entries = _entries; _entries = []; _lock.unlock()
        for x in entries { x.finish(e) }
    }
}

// MARK: - iOS 27

/// The status of the assets a request downloads (isim's engines need none).
@available(iOS 27.0, *)
public enum DownloadableAssetsRequestStatus: @unchecked Sendable {
    case ready, downloading, notReady, error(any Error)
}
@available(iOS 27.0, *)
public protocol DownloadableAssetsRequest {
    var assetStatus: DownloadableAssetsRequestStatus { get async }
    func downloadAssets() async throws
    func downloadAssets(progress: consuming Subprogress) async throws
}
@available(iOS 27.0, *)
extension DownloadableAssetsRequest {
    public var assetStatus: DownloadableAssetsRequestStatus { get async { .ready } }
    public func downloadAssets() async throws {}
    public func downloadAssets(progress: consuming Subprogress) async throws { _ = consume progress }
}

/// Segments the object the seeds point at, refining with included and excluded points (isim: region growing on colour
/// from the seeds, at most 256 pixels across; excluded points cut their region out).
public final class GenerateIterativeSegmentationRequest: ImageProcessingRequest, _VNSwiftRequest, _VNComputeDevices, @unchecked Sendable {
    public enum Revision: Hashable, Sendable, Comparable { case revision1 }
    public enum QualityLevel: Hashable, Sendable { case accurate, balanced, fast }
    public typealias Result = PixelBufferObservation?
    public let revision: Revision
    public static let supportedRevisions: [Revision] = [.revision1]
    public var regionOfInterest: NormalizedRect = .fullImage
    public var qualityLevel: QualityLevel = .balanced
    var _devices = _VNDevices()
    var _box: NormalizedRect?
    var _included: [NormalizedPoint] = []
    var _excluded: [NormalizedPoint] = []
    var _scribble: CVPixelBuffer?
    let _lock = NSLock()
    public init(seedBox: NormalizedRect, _ revision: Revision? = nil) { _box = seedBox; self.revision = revision ?? .revision1 }
    public init(seedPoint: NormalizedPoint, _ revision: Revision? = nil) { _included = [seedPoint]; self.revision = revision ?? .revision1 }
    @available(iOS 26.0, *)
    public init(seedScribbleBuffer: CVReadOnlyPixelBuffer, _ revision: Revision? = nil) {
        _scribble = seedScribbleBuffer.withUnsafeBuffer { $0 }; self.revision = revision ?? .revision1
    }
    public func addIncludedPoint(_ point: NormalizedPoint) throws {
        guard (0...1).contains(point.x), (0...1).contains(point.y) else { throw VisionError.invalidArgument("the point is outside the image") }
        _lock.lock(); _included.append(point); _lock.unlock()
    }
    public func addExcludedPoint(_ point: NormalizedPoint) throws {
        guard (0...1).contains(point.x), (0...1).contains(point.y) else { throw VisionError.invalidArgument("the point is outside the image") }
        _lock.lock(); _excluded.append(point); _lock.unlock()
    }
    public static func == (lhs: GenerateIterativeSegmentationRequest, rhs: GenerateIterativeSegmentationRequest) -> Bool { lhs === rhs }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
    public var descriptor: RequestDescriptor { .generateIterativeSegmentationRequest(revision) }
    public var description: String { "GenerateIterativeSegmentationRequest(\(revision))" }
    func _run(_ handler: VNImageRequestHandler) throws -> Any {
        _lock.lock(); let box = _box, inc = _included, exc = _excluded, scribble = _scribble; _lock.unlock()
        let img = try handler._image(regionOfInterest.cgRect)
        let side = qualityLevel == .fast ? 128 : 256
        let s = max(1, max(img.width, img.height) / side), W = max(1, img.width / s), H = max(1, img.height / s)
        func colour(_ x: Int, _ y: Int) -> SIMD3<Float> {
            let i = ((y * s) * img.width + x * s) * 4
            return SIMD3(Float(img.bgra[i + 2]), Float(img.bgra[i + 1]), Float(img.bgra[i])) / 255
        }
        func px(_ p: NormalizedPoint) -> (Int, Int) { (min(W - 1, max(0, Int(p.x * CGFloat(W)))), min(H - 1, max(0, Int((1 - p.y) * CGFloat(H))))) }
        /* seeds: the box's middle, the points, or the scribble's set pixels */
        var seeds: [(Int, Int)] = inc.map(px)
        if let b = box { seeds.append(px(NormalizedPoint(x: b.origin.x + b.width / 2, y: b.origin.y + b.height / 2))) }
        if let sb = scribble {
            for y in stride(from: 0, to: H, by: 2) { for x in stride(from: 0, to: W, by: 2) {
                if _vnSample(sb, NormalizedPoint(x: (CGFloat(x) + 0.5) / CGFloat(W), y: 1 - (CGFloat(y) + 0.5) / CGFloat(H))) > 0.5 { seeds.append((x, y)) }
            } }
        }
        guard !seeds.isEmpty else { return Optional<PixelBufferObservation>.none as Any }
        var mean = SIMD3<Float>(repeating: 0)
        for (x, y) in seeds { mean += colour(x, y) }
        mean /= Float(seeds.count)
        let limit: (Int, Int, Int, Int) = box.map { b in
            let (x0, y1) = px(NormalizedPoint(x: b.origin.x, y: b.origin.y)), (x1, y0) = px(NormalizedPoint(x: b.origin.x + b.width, y: b.origin.y + b.height))
            return (x0, y0, x1, y1)
        } ?? (0, 0, W - 1, H - 1)
        func grow(_ from: [(Int, Int)], _ ref: SIMD3<Float>) -> [Bool] {
            var m = [Bool](repeating: false, count: W * H), stack = from
            while let (x, y) = stack.popLast() {
                guard x >= limit.0, x <= limit.2, y >= limit.1, y <= limit.3, !m[y * W + x] else { continue }
                let d = colour(x, y) - ref
                guard (d * d).sum().squareRoot() < 0.25 else { continue }
                m[y * W + x] = true
                stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            }
            return m
        }
        var mask = grow(seeds, mean)
        for p in exc {
            let (x, y) = px(p)
            let cut = grow([(x, y)], colour(x, y))
            for i in mask.indices where cut[i] { mask[i] = false }
        }
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, W, H, kCVPixelFormatType_OneComponent8, nil, &pb)
        guard let buffer = pb else { throw VisionError.pixelBufferCreationFailed(kCVReturnError) }
        CVPixelBufferLockBaseAddress(buffer, [])
        let base = CVPixelBufferGetBaseAddress(buffer)!, bpr = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<H { for x in 0..<W { base.storeBytes(of: mask[y * W + x] ? 255 : 0, toByteOffset: y * bpr + x, as: UInt8.self) } }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return Optional(PixelBufferObservation(buffer: buffer, descriptor: descriptor)) as Any
    }
    func _result(_ value: Any?, _ error: Error?) -> VisionResult {
        if let error { return .error(self, error) }
        return .generateIterativeSegmentation(self, value as? PixelBufferObservation? ?? nil)
    }
}
