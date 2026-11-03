// isim AVFoundation for Objective-C (issue #707): compositions, export, readers, writers and video compositions. A CMTime /
// CMTimeRange crosses as a pointer to its C struct (same layout as Swift's), a CVPixelBufferRef / CMSampleBufferRef as the
// Swift object's opaque pointer; the methods with them are Objective-C categories in AVFoundation.m over these `_isim_`
// entry points.
import Foundation
import UIKit
import CoreMedia
import CoreVideo

extension CMTimeRange {
    init(_isimRaw p: UnsafeRawPointer) { self = p.load(as: CMTimeRange.self) }
    func _isimStore(_ p: UnsafeMutableRawPointer) { p.storeBytes(of: self, as: CMTimeRange.self) }
}
func _isimBuffer(_ p: UnsafeMutableRawPointer) -> CVBuffer { Unmanaged<CVBuffer>.fromOpaque(p).takeUnretainedValue() }
func _isimSampleBuffer(_ p: UnsafeMutableRawPointer) -> CMSampleBuffer { Unmanaged<CMSampleBuffer>.fromOpaque(p).takeUnretainedValue() }

// MARK: the Objective-C custom compositor

/// an Objective-C object adopting AVVideoCompositing, seen as Swift's protocol
final class _ObjCCompositorAdapter: NSObject, AVVideoCompositing, @unchecked Sendable {
    let target: NSObject
    init(_ t: NSObject) { target = t }
    private func dict(_ name: String) -> [String: any Sendable]? {
        let sel = NSSelectorFromString(name)
        guard target.responds(to: sel) else { return nil }
        return target.perform(sel)?.takeUnretainedValue() as? [String: any Sendable]
    }
    private func flag(_ name: String) -> Bool {
        let sel = NSSelectorFromString(name)
        guard target.responds(to: sel) else { return false }
        typealias F = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(target.method(for: sel), to: F.self)(target, sel)
    }
    var sourcePixelBufferAttributes: [String: any Sendable]? { dict("sourcePixelBufferAttributes") }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] { dict("requiredPixelBufferAttributesForRenderContext") ?? [:] }
    var supportsWideColorSourceFrames: Bool { flag("supportsWideColorSourceFrames") }
    var supportsHDRSourceFrames: Bool { flag("supportsHDRSourceFrames") }
    var canConformColorOfSourceFrames: Bool { flag("canConformColorOfSourceFrames") }
    func renderContextChanged(_ c: AVVideoCompositionRenderContext) { _isimSend(target, "renderContextChanged:", [c]) }
    func startRequest(_ r: AVAsynchronousVideoCompositionRequest) { _isimSend(target, "startVideoCompositionRequest:", [r]) }
    func cancelAllPendingVideoCompositionRequests() { _isimSend(target, "cancelAllPendingVideoCompositionRequests", []) }
    func anticipateRendering(using h: AVVideoCompositionRenderHint) { _isimSend(target, "anticipateRenderingUsingHint:", [h]) }
    func prerollForRendering(using h: AVVideoCompositionRenderHint) { _isimSend(target, "prerollForRenderingUsingHint:", [h]) }
}

extension AVVideoCompositionRenderContext {
    @objc(size) var _objc_size: CGSize { size }
    @objc(renderScale) var _objc_scale: Float { renderScale }
    @objc(renderTransform) var _objc_transform: CGAffineTransform { renderTransform }
    @objc(highQualityRendering) var _objc_hq: Bool { highQualityRendering }
    @objc(videoComposition) var _objc_vc: AVVideoComposition { videoComposition }
    /// +1, as Apple's newPixelBuffer
    @objc(_isim_newPixelBuffer) func _isimNewPixelBuffer() -> UnsafeMutableRawPointer? { newPixelBuffer().map { Unmanaged.passRetained($0).toOpaque() } }
}
extension AVAsynchronousVideoCompositionRequest {
    @objc(renderContext) var _objc_context: AVVideoCompositionRenderContext { renderContext }
    @objc(_isim_compositionTime:) func _isimTime(_ out: UnsafeMutableRawPointer) { compositionTime._isimStore(out) }
    @objc(sourceTrackIDs) var _objc_sources: [NSNumber] { sourceTrackIDs }
    @objc(videoCompositionInstruction) var _objc_instruction: AnyObject { videoCompositionInstruction }
    @objc(_isim_sourceFrameByTrackID:) func _isimSource(_ id: Int32) -> UnsafeMutableRawPointer? { _isimOpaque(sourceFrame(byTrackID: id)) }
    @objc(_isim_finishWithComposedVideoFrame:) func _isimFinish(_ p: UnsafeMutableRawPointer) { finish(withComposedVideoFrame: _isimBuffer(p)) }
    @objc(finishWithError:) func _objc_finish(_ e: NSError) { finish(with: e) }
    @objc(finishCancelledRequest) func _objc_cancelled() { finishCancelledRequest() }
}

// MARK: video compositions

extension AVVideoComposition {
    @objc(videoCompositionWithPropertiesOfAsset:) class func _objc_make(_ a: AVAsset) -> AVVideoComposition { AVVideoComposition(propertiesOf: a) }
    @objc(renderSize) var _objc_renderSize: CGSize { renderSize }
    @objc(renderScale) var _objc_renderScale: Float { renderScale }
    @objc(instructions) var _objc_instructions: [AnyObject] { instructions.map { $0 as AnyObject } }
    @objc(animationTool) var _objc_tool: AVVideoCompositionCoreAnimationTool? { animationTool }
    @objc(customVideoCompositorClass) var _objc_compositor: AnyClass? { _objcCompositorClass ?? customVideoCompositorClass.map { $0 as AnyClass } }
    @objc(_isim_frameDuration:) func _isimFrameDuration(_ out: UnsafeMutableRawPointer) { frameDuration._isimStore(out) }
}
extension AVMutableVideoComposition {
    @objc(videoComposition) class func _objc_new() -> AVMutableVideoComposition { AVMutableVideoComposition() }
    @objc(videoCompositionWithPropertiesOfAsset:) override class func _objc_make(_ a: AVAsset) -> AVMutableVideoComposition { AVMutableVideoComposition(propertiesOf: a) }
    @objc(setRenderSize:) func _objc_setRenderSize(_ s: CGSize) { renderSize = s }
    @objc(setRenderScale:) func _objc_setRenderScale(_ s: Float) { renderScale = s }
    @objc(setInstructions:) func _objc_setInstructions(_ a: [AnyObject]) { instructions = a.compactMap { $0 as? any AVVideoCompositionInstructionProtocol } }
    @objc(setAnimationTool:) func _objc_setTool(_ t: AVVideoCompositionCoreAnimationTool?) { animationTool = t }
    @objc(setCustomVideoCompositorClass:) func _objc_setCompositor(_ k: AnyClass?) {
        if let k, let swift = k as? any AVVideoCompositing.Type { customVideoCompositorClass = swift; _objcCompositorClass = nil }
        else { customVideoCompositorClass = nil; _objcCompositorClass = k }
    }
    @objc(_isim_setFrameDuration:) func _isimSetFrameDuration(_ p: UnsafeRawPointer) { frameDuration = CMTime(_isimRaw: p) }
}
extension AVVideoCompositionInstruction {
    @objc(_isim_timeRange:) func _isimTimeRange(_ out: UnsafeMutableRawPointer) { timeRange._isimStore(out) }
    @objc(layerInstructions) var _objc_layers: [AVVideoCompositionLayerInstruction] { layerInstructions }
    @objc(backgroundColor) var _objc_background: CGColor? { backgroundColor }
    @objc(enablePostProcessing) var _objc_post: Bool { enablePostProcessing }
}
extension AVMutableVideoCompositionInstruction {
    @objc(videoCompositionInstruction) class func _objc_new() -> AVMutableVideoCompositionInstruction { AVMutableVideoCompositionInstruction() }
    @objc(_isim_setTimeRange:) func _isimSetTimeRange(_ p: UnsafeRawPointer) { timeRange = CMTimeRange(_isimRaw: p) }
    @objc(setLayerInstructions:) func _objc_setLayers(_ a: [AVVideoCompositionLayerInstruction]) { layerInstructions = a }
    @objc(setBackgroundColor:) func _objc_setBackground(_ c: CGColor?) { backgroundColor = c }
    @objc(setEnablePostProcessing:) func _objc_setPost(_ b: Bool) { enablePostProcessing = b }
}
extension AVVideoCompositionLayerInstruction {
    @objc(trackID) var _objc_trackID: Int32 { trackID }
}
extension AVMutableVideoCompositionLayerInstruction {
    @objc(videoCompositionLayerInstruction) class func _objc_new() -> AVMutableVideoCompositionLayerInstruction { AVMutableVideoCompositionLayerInstruction() }
    @objc(videoCompositionLayerInstructionWithAssetTrack:) class func _objc_new(_ t: AVAssetTrack) -> AVMutableVideoCompositionLayerInstruction {
        AVMutableVideoCompositionLayerInstruction(assetTrack: t)
    }
    @objc(setTrackID:) func _objc_setTrackID(_ id: Int32) { trackID = id }
    @objc(_isim_setTransform:atTime:) func _isimSetTransform(_ t: CGAffineTransform, _ p: UnsafeRawPointer) { setTransform(t, at: CMTime(_isimRaw: p)) }
    @objc(_isim_setOpacity:atTime:) func _isimSetOpacity(_ o: Float, _ p: UnsafeRawPointer) { setOpacity(o, at: CMTime(_isimRaw: p)) }
    @objc(_isim_setTransformRampFromStart:toEnd:timeRange:) func _isimRamp(_ a: CGAffineTransform, _ b: CGAffineTransform, _ p: UnsafeRawPointer) {
        setTransformRamp(fromStart: a, toEnd: b, timeRange: CMTimeRange(_isimRaw: p))
    }
    @objc(_isim_setOpacityRampFromStart:toEnd:timeRange:) func _isimOpacityRamp(_ a: Float, _ b: Float, _ p: UnsafeRawPointer) {
        setOpacityRamp(fromStartOpacity: a, toEndOpacity: b, timeRange: CMTimeRange(_isimRaw: p))
    }
    @objc(_isim_setCropRectangle:atTime:) func _isimSetCrop(_ r: CGRect, _ p: UnsafeRawPointer) { setCropRectangle(r, at: CMTime(_isimRaw: p)) }
}
extension AVVideoCompositionCoreAnimationTool {
    @objc(videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:inLayer:) class func _objc_tool(_ v: CALayer, _ p: CALayer) -> AVVideoCompositionCoreAnimationTool {
        AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: v, in: p)
    }
    @objc(videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayers:inLayer:) class func _objc_tool(_ v: [CALayer], _ p: CALayer) -> AVVideoCompositionCoreAnimationTool {
        AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayers: v, in: p)
    }
    @objc(videoCompositionCoreAnimationToolWithAdditionalLayer:asTrackID:) class func _objc_tool(_ l: CALayer, _ id: Int32) -> AVVideoCompositionCoreAnimationTool {
        AVVideoCompositionCoreAnimationTool(additionalLayer: l, asTrackID: id)
    }
}

// MARK: compositions

extension AVAssetTrack {
    @objc(trackID) var _objc_trackID: Int32 { trackID }
    @objc(asset) var _objc_asset: AVAsset? { asset }
    @objc(preferredTransform) var _objc_preferredTransform: CGAffineTransform { preferredTransform }
    @objc(_isim_timeRange:) func _isimTimeRange(_ out: UnsafeMutableRawPointer) { timeRange._isimStore(out) }
}

extension AVCompositionTrackSegment {
    @objc(isEmpty) var _objc_empty: Bool { isEmpty }
    @objc(sourceURL) var _objc_url: URL? { sourceURL }
    @objc(sourceTrackID) var _objc_trackID: Int32 { sourceTrackID }
}
extension AVCompositionTrack {
    @objc(segments) var _objc_segments: [AVCompositionTrackSegment] { segments }
}
extension AVMutableCompositionTrack {
    @objc(_isim_insertTimeRange:ofTrack:atTime:error:) func _isimInsert(_ r: UnsafeRawPointer, _ t: AVAssetTrack, _ at: UnsafeRawPointer) throws {
        try insertTimeRange(CMTimeRange(_isimRaw: r), of: t, at: CMTime(_isimRaw: at))
    }
    @objc(_isim_insertEmptyTimeRange:) func _isimInsertEmpty(_ r: UnsafeRawPointer) { insertEmptyTimeRange(CMTimeRange(_isimRaw: r)) }
    @objc(_isim_removeTimeRange:) func _isimRemove(_ r: UnsafeRawPointer) { removeTimeRange(CMTimeRange(_isimRaw: r)) }
    @objc(_isim_scaleTimeRange:toDuration:) func _isimScale(_ r: UnsafeRawPointer, _ d: UnsafeRawPointer) {
        scaleTimeRange(CMTimeRange(_isimRaw: r), toDuration: CMTime(_isimRaw: d))
    }
    @objc(setPreferredTransform:) func _objc_setTransform(_ t: CGAffineTransform) { preferredTransform = t }
    @objc(naturalTimeScale) var _objc_timescale: Int32 { get { naturalTimeScale } set { naturalTimeScale = newValue } }
}
extension AVMutableComposition {
    @objc(composition) class func _objc_new() -> AVMutableComposition { AVMutableComposition() }
    @objc(addMutableTrackWithMediaType:preferredTrackID:) func _objc_addTrack(_ t: String, _ id: Int32) -> AVMutableCompositionTrack? {
        addMutableTrack(withMediaType: AVMediaType(rawValue: t), preferredTrackID: id)
    }
    @objc(removeTrack:) func _objc_remove(_ t: AVCompositionTrack) { removeTrack(t) }
    @objc(mutableTrackCompatibleWithTrack:) func _objc_compatible(_ t: AVAssetTrack) -> AVMutableCompositionTrack? { mutableTrack(compatibleWith: t) }
    @objc(_isim_insertTimeRange:ofAsset:atTime:error:) func _isimInsert(_ r: UnsafeRawPointer, _ a: AVAsset, _ at: UnsafeRawPointer) throws {
        try insertTimeRange(CMTimeRange(_isimRaw: r), of: a, at: CMTime(_isimRaw: at))
    }
    @objc(_isim_insertEmptyTimeRange:) func _isimInsertEmpty(_ r: UnsafeRawPointer) { insertEmptyTimeRange(CMTimeRange(_isimRaw: r)) }
    @objc(_isim_removeTimeRange:) func _isimRemove(_ r: UnsafeRawPointer) { removeTimeRange(CMTimeRange(_isimRaw: r)) }
    @objc(_isim_scaleTimeRange:toDuration:) func _isimScale(_ r: UnsafeRawPointer, _ d: UnsafeRawPointer) {
        scaleTimeRange(CMTimeRange(_isimRaw: r), toDuration: CMTime(_isimRaw: d))
    }
}
extension AVMutableAudioMix {
    @objc(audioMix) class func _objc_new() -> AVMutableAudioMix { AVMutableAudioMix() }
    @objc(inputParameters) var _objc_params: [AVAudioMixInputParameters] { get { inputParameters } set { inputParameters = newValue } }
}
extension AVMutableAudioMixInputParameters {
    @objc(audioMixInputParametersWithTrack:) class func _objc_new(_ t: AVAssetTrack?) -> AVMutableAudioMixInputParameters { AVMutableAudioMixInputParameters(track: t) }
    @objc(trackID) var _objc_trackID: Int32 { get { trackID } set { trackID = newValue } }
    @objc(_isim_setVolume:atTime:) func _isimSetVolume(_ v: Float, _ p: UnsafeRawPointer) { setVolume(v, at: CMTime(_isimRaw: p)) }
    @objc(_isim_setVolumeRampFromStartVolume:toEndVolume:timeRange:) func _isimRamp(_ a: Float, _ b: Float, _ p: UnsafeRawPointer) {
        setVolumeRamp(fromStartVolume: a, toEndVolume: b, timeRange: CMTimeRange(_isimRaw: p))
    }
}

// MARK: export

extension AVAssetExportSession {
    @objc(exportSessionWithAsset:presetName:) class func _objc_new(_ a: AVAsset, _ p: String) -> AVAssetExportSession? { AVAssetExportSession(asset: a, presetName: p) }
    @objc(initWithAsset:presetName:) convenience init?(_objcAsset a: AVAsset, presetName p: String) { self.init(asset: a, presetName: p) }
    @objc(allExportPresets) class func _objc_all() -> [String] { allExportPresets() }
    @objc(exportPresetsCompatibleWithAsset:) class func _objc_compatible(_ a: AVAsset) -> [String] { exportPresets(compatibleWith: a) }
    @objc(asset) var _objc_asset: AVAsset { asset }
    @objc(presetName) var _objc_preset: String { presetName }
    @objc(outputURL) var _objc_url: URL? { get { outputURL } set { outputURL = newValue } }
    @objc(outputFileType) var _objc_fileType: String? { get { outputFileType?.rawValue } set { outputFileType = newValue.map { AVFileType(rawValue: $0) } } }
    @objc(supportedFileTypes) var _objc_supported: [String] { supportedFileTypes.map(\.rawValue) }
    @objc(shouldOptimizeForNetworkUse) var _objc_optimize: Bool { get { shouldOptimizeForNetworkUse } set { shouldOptimizeForNetworkUse = newValue } }
    @objc(videoComposition) var _objc_vc: AVVideoComposition? { get { videoComposition } set { videoComposition = newValue } }
    @objc(audioMix) var _objc_mix: AVAudioMix? { get { audioMix } set { audioMix = newValue } }
    @objc(fileLengthLimit) var _objc_limit: Int64 { get { fileLengthLimit } set { fileLengthLimit = newValue } }
    @objc(status) var _objc_status: Status { status }
    @objc(error) var _objc_error: NSError? { error.map { $0 as NSError } }
    @objc(progress) var _objc_progress: Float { progress }
    @objc(customVideoCompositor) var _objc_compositor: AnyObject? { (customVideoCompositor as? _ObjCCompositorAdapter)?.target ?? customVideoCompositor }
    @objc(exportAsynchronouslyWithCompletionHandler:) func _objc_export(_ h: @escaping @Sendable () -> Void) { exportAsynchronously(completionHandler: h) }
    @objc(cancelExport) func _objc_cancel() { cancelExport() }
    @objc(_isim_timeRange:) func _isimTimeRange(_ out: UnsafeMutableRawPointer) { timeRange._isimStore(out) }
    @objc(_isim_setTimeRange:) func _isimSetTimeRange(_ p: UnsafeRawPointer) { timeRange = CMTimeRange(_isimRaw: p) }
}

// MARK: readers

extension AVAssetReaderOutput {
    @objc(mediaType) var _objc_mediaType: String { mediaType.rawValue }
    @objc(alwaysCopiesSampleData) var _objc_copies: Bool { get { alwaysCopiesSampleData } set { alwaysCopiesSampleData = newValue } }
    @objc(supportsRandomAccess) var _objc_random: Bool { get { supportsRandomAccess } set { supportsRandomAccess = newValue } }
    /// +1, as Apple's copyNextSampleBuffer
    @objc(_isim_copyNextSampleBuffer) func _isimCopyNext() -> UnsafeMutableRawPointer? { copyNextSampleBuffer().map { Unmanaged.passRetained($0).toOpaque() } }
    @objc(resetForReadingTimeRanges:) func _objc_reset(_ r: [NSValue]) { reset(forReadingTimeRanges: r) }
    @objc(markConfigurationAsFinal) func _objc_final() { markConfigurationAsFinal() }
}
extension AVAssetReaderTrackOutput {
    @objc(assetReaderTrackOutputWithTrack:outputSettings:) class func _objc_new(_ t: AVAssetTrack, _ s: [String: Any]?) -> AVAssetReaderTrackOutput {
        AVAssetReaderTrackOutput(track: t, outputSettings: s)
    }
    @objc(initWithTrack:outputSettings:) convenience init(_objcTrack t: AVAssetTrack, outputSettings s: [String: Any]?) { self.init(track: t, outputSettings: s) }
    @objc(track) var _objc_track: AVAssetTrack { track }
    @objc(outputSettings) var _objc_settings: [String: Any]? { outputSettings }
}
extension AVAssetReaderAudioMixOutput {
    @objc(assetReaderAudioMixOutputWithAudioTracks:audioSettings:) class func _objc_new(_ t: [AVAssetTrack], _ s: [String: Any]?) -> AVAssetReaderAudioMixOutput {
        AVAssetReaderAudioMixOutput(audioTracks: t, audioSettings: s)
    }
    @objc(audioMix) var _objc_mix: AVAudioMix? { get { audioMix } set { audioMix = newValue } }
}
extension AVAssetReaderVideoCompositionOutput {
    @objc(assetReaderVideoCompositionOutputWithVideoTracks:videoSettings:) class func _objc_new(_ t: [AVAssetTrack], _ s: [String: Any]?)
        -> AVAssetReaderVideoCompositionOutput { AVAssetReaderVideoCompositionOutput(videoTracks: t, videoSettings: s) }
    @objc(videoComposition) var _objc_vc: AVVideoComposition? { get { videoComposition } set { videoComposition = newValue } }
    @objc(customVideoCompositor) var _objc_compositor: AnyObject? { (customVideoCompositor as? _ObjCCompositorAdapter)?.target ?? customVideoCompositor }
}
extension AVAssetReader {
    @objc(assetReaderWithAsset:error:) class func _objc_new(_ a: AVAsset) throws -> AVAssetReader { try AVAssetReader(asset: a) }
    @objc(initWithAsset:error:) convenience init(_objcAsset a: AVAsset) throws { try self.init(asset: a) }
    @objc(asset) var _objc_asset: AVAsset { asset }
    @objc(outputs) var _objc_outputs: [AVAssetReaderOutput] { outputs }
    @objc(status) var _objc_status: Status { status }
    @objc(error) var _objc_error: NSError? { error.map { $0 as NSError } }
    @objc(canAddOutput:) func _objc_canAdd(_ o: AVAssetReaderOutput) -> Bool { canAdd(o) }
    @objc(addOutput:) func _objc_add(_ o: AVAssetReaderOutput) { add(o) }
    @objc(startReading) func _objc_start() -> Bool { startReading() }
    @objc(cancelReading) func _objc_cancel() { cancelReading() }
    @objc(_isim_timeRange:) func _isimTimeRange(_ out: UnsafeMutableRawPointer) { timeRange._isimStore(out) }
    @objc(_isim_setTimeRange:) func _isimSetTimeRange(_ p: UnsafeRawPointer) { timeRange = CMTimeRange(_isimRaw: p) }
}

// MARK: writers

extension AVAssetWriterInput {
    @objc(assetWriterInputWithMediaType:outputSettings:) class func _objc_new(_ t: String, _ s: [String: Any]?) -> AVAssetWriterInput {
        AVAssetWriterInput(mediaType: AVMediaType(rawValue: t), outputSettings: s)
    }
    @objc(initWithMediaType:outputSettings:) convenience init(_objcMediaType t: String, outputSettings s: [String: Any]?) {
        self.init(mediaType: AVMediaType(rawValue: t), outputSettings: s)
    }
    @objc(mediaType) var _objc_mediaType: String { mediaType.rawValue }
    @objc(outputSettings) var _objc_settings: [String: Any]? { outputSettings }
    @objc(expectsMediaDataInRealTime) var _objc_realTime: Bool { get { expectsMediaDataInRealTime } set { expectsMediaDataInRealTime = newValue } }
    @objc(transform) var _objc_transform: CGAffineTransform { get { transform } set { transform = newValue } }
    @objc(mediaTimeScale) var _objc_timescale: Int32 { get { mediaTimeScale } set { mediaTimeScale = newValue } }
    @objc(naturalSize) var _objc_naturalSize: CGSize { get { naturalSize } set { naturalSize = newValue } }
    @objc(languageCode) var _objc_language: String? { get { languageCode } set { languageCode = newValue } }
    @objc(isReadyForMoreMediaData) var _objc_ready: Bool { isReadyForMoreMediaData }
    @objc(markAsFinished) func _objc_finished() { markAsFinished() }
    @objc(_isim_appendSampleBuffer:) func _isimAppend(_ p: UnsafeMutableRawPointer) -> Bool { append(_isimSampleBuffer(p)) }
    @objc(requestMediaDataWhenReadyOnQueue:usingBlock:) func _objc_request(_ q: dispatch_queue_t, _ block: @escaping @Sendable () -> Void) {
        let box = _ObjCQueuedDelegate(self, q)
        requestMediaDataWhenReady(on: DispatchQueue.global()) { _isimOn(box.queue) { block() } }
    }
}
extension AVAssetWriterInputPixelBufferAdaptor {
    @objc(assetWriterInputPixelBufferAdaptorWithAssetWriterInput:sourcePixelBufferAttributes:)
    class func _objc_new(_ i: AVAssetWriterInput, _ a: [String: Any]?) -> AVAssetWriterInputPixelBufferAdaptor {
        AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: i, sourcePixelBufferAttributes: a)
    }
    @objc(assetWriterInput) var _objc_input: AVAssetWriterInput { assetWriterInput }
    @objc(sourcePixelBufferAttributes) var _objc_attributes: [String: Any]? { sourcePixelBufferAttributes }
    @objc(_isim_appendPixelBuffer:withPresentationTime:) func _isimAppend(_ p: UnsafeMutableRawPointer, _ t: UnsafeRawPointer) -> Bool {
        append(_isimBuffer(p), withPresentationTime: CMTime(_isimRaw: t))
    }
}
extension AVAssetWriter {
    @objc(assetWriterWithURL:fileType:error:) class func _objc_new(_ u: URL, _ t: String) throws -> AVAssetWriter { try AVAssetWriter(outputURL: u, fileType: AVFileType(rawValue: t)) }
    @objc(initWithURL:fileType:error:) convenience init(_objcURL u: URL, fileType t: String) throws { try self.init(outputURL: u, fileType: AVFileType(rawValue: t)) }
    @objc(outputURL) var _objc_url: URL { outputURL }
    @objc(outputFileType) var _objc_fileType: String { outputFileType.rawValue }
    @objc(availableMediaTypes) var _objc_media: [String] { availableMediaTypes.map(\.rawValue) }
    @objc(inputs) var _objc_inputs: [AVAssetWriterInput] { inputs }
    @objc(status) var _objc_status: Status { status }
    @objc(error) var _objc_error: NSError? { error.map { $0 as NSError } }
    @objc(shouldOptimizeForNetworkUse) var _objc_optimize: Bool { get { shouldOptimizeForNetworkUse } set { shouldOptimizeForNetworkUse = newValue } }
    @objc(canAddInput:) func _objc_canAdd(_ i: AVAssetWriterInput) -> Bool { canAdd(i) }
    @objc(addInput:) func _objc_add(_ i: AVAssetWriterInput) { add(i) }
    @objc(canApplyOutputSettings:forMediaType:) func _objc_canApply(_ s: [String: Any]?, _ t: String) -> Bool { canApply(outputSettings: s, forMediaType: AVMediaType(rawValue: t)) }
    @objc(startWriting) func _objc_start() -> Bool { startWriting() }
    @objc(cancelWriting) func _objc_cancel() { cancelWriting() }
    @objc(finishWritingWithCompletionHandler:) func _objc_finish(_ h: @escaping @Sendable () -> Void) { finishWriting(completionHandler: h) }
    @objc(_isim_startSessionAtSourceTime:) func _isimStart(_ p: UnsafeRawPointer) { startSession(atSourceTime: CMTime(_isimRaw: p)) }
    @objc(_isim_endSessionAtSourceTime:) func _isimEnd(_ p: UnsafeRawPointer) { endSession(atSourceTime: CMTime(_isimRaw: p)) }
}
