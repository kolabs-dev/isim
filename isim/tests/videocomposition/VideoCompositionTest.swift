// AVFoundation video compositions (VideoCompositionTest.app, issue #381): instructions with layer instructions
// (opacity ramps for a cross-fade, transforms, crops, background colors) exported from a two-track composition, a
// custom AVVideoCompositing class with its own instruction class, Core Image filtering read through
// AVAssetReaderVideoCompositionOutput, the Core Animation tool (post-processing layers on the video's clock, an extra
// layer track), validation and the iOS 26 configuration types. Pixels are checked on the encoded output (H.264, so
// with a tolerance).
import Foundation
import AVFoundation
import CoreImage
import UIKit

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}
let tmp = FileManager.default.temporaryDirectory
let W = 160, H = 120

typealias RGB = (r: Int, g: Int, b: Int)
func near(_ c: RGB?, _ t: RGB, _ tol: Int = 40) -> Bool {
    guard let c else { return false }
    return abs(c.r - t.r) <= tol && abs(c.g - t.g) <= tol && abs(c.b - t.b) <= tol
}
func show(_ c: RGB?) -> String { c.map { "(\($0.r),\($0.g),\($0.b))" } ?? "nil" }

/// a BGRA frame: `fill` everywhere, `mark` in the top-left 20x20 square
func frame(_ fill: RGB, mark: RGB? = nil) -> CVPixelBuffer {
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, W, H, kCVPixelFormatType_32BGRA, nil, &pb)
    let b = pb!
    CVPixelBufferLockBaseAddress(b, [])
    let base = CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to: UInt8.self), bpr = CVPixelBufferGetBytesPerRow(b)
    for y in 0..<H {
        for x in 0..<W {
            let c = (x < 20 && y < 20) ? (mark ?? fill) : fill
            let p = base + y * bpr + x * 4
            p[0] = UInt8(c.b); p[1] = UInt8(c.g); p[2] = UInt8(c.r); p[3] = 255
        }
    }
    CVPixelBufferUnlockBaseAddress(b, [])
    return b
}
/// a 2 s movie at 10 frames per second
func movie(_ name: String, _ fill: RGB, mark: RGB? = nil) -> URL {
    let url = tmp.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: url)
    let w = try! AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
    w.add(input)
    w.startWriting(); w.startSession(atSourceTime: .zero)
    let f = frame(fill, mark: mark)
    for i in 0..<20 { adaptor.append(f, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: 10)) }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    w.finishWriting { done.signal() }
    done.wait()
    return url
}

/// the decoded frames of a file's video (BGRA) with their times
func frames(of url: URL) -> [(Double, CVPixelBuffer)] {
    let asset = AVURLAsset(url: url)
    guard let r = try? AVAssetReader(asset: asset), let t = asset.tracks(withMediaType: .video).first else { return [] }
    let o = AVAssetReaderTrackOutput(track: t, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    r.add(o); r.startReading()
    var out: [(Double, CVPixelBuffer)] = []
    while let sb = o.copyNextSampleBuffer() { if let pb = sb.imageBuffer { out.append((sb.presentationTimeStamp.seconds, pb)) } }
    return out
}
func pixel(_ pb: CVPixelBuffer, _ x: Int, _ y: Int) -> RGB {
    CVPixelBufferLockBaseAddress(pb, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    let p = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self) + y * CVPixelBufferGetBytesPerRow(pb) + x * 4
    return (Int(p[2]), Int(p[1]), Int(p[0]))
}
/// the pixel at (x, y) of the frame shown at time t
func pixel(_ fs: [(Double, CVPixelBuffer)], at t: Double, _ x: Int, _ y: Int) -> RGB? {
    guard let f = fs.last(where: { $0.0 <= t + 1e-3 }) ?? fs.first else { return nil }
    return pixel(f.1, x, y)
}
func export(_ asset: AVAsset, _ vc: AVVideoComposition, _ name: String) -> (URL, AVAssetExportSession) {
    let url = tmp.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: url)
    let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)!
    s.outputURL = url; s.outputFileType = .mov; s.videoComposition = vc
    let done = DispatchSemaphore(value: 0)
    s.exportAsynchronously { done.signal() }
    done.wait()
    return (url, s)
}
func range(_ a: Double, _ b: Double) -> CMTimeRange { CMTimeRange(start: CMTime(seconds: a, preferredTimescale: 600), end: CMTime(seconds: b, preferredTimescale: 600)) }

let red: RGB = (255, 0, 0), blue: RGB = (0, 0, 255), white: RGB = (255, 255, 255), green: RGB = (0, 255, 0)

// MARK: - instructions: a cross-fade, a transform, a crop
func instructions() {
    let a = AVURLAsset(url: movie("red.mov", red)), b = AVURLAsset(url: movie("blue.mov", blue, mark: white))
    let comp = AVMutableComposition()
    let ta = comp.addMutableTrack(withMediaType: .video, preferredTrackID: 1)!, tb = comp.addMutableTrack(withMediaType: .video, preferredTrackID: 2)!
    try! ta.insertTimeRange(range(0, 2), of: a.tracks(withMediaType: .video)[0], at: .zero)
    try! tb.insertTimeRange(range(0, 2), of: b.tracks(withMediaType: .video)[0], at: CMTime(seconds: 1, preferredTimescale: 600))
    check(abs(comp.duration.seconds - 3) < 0.01, "the composition lasts 3 s (\(comp.duration.seconds))")

    let la = AVMutableVideoCompositionLayerInstruction(assetTrack: ta), lb = AVMutableVideoCompositionLayerInstruction(assetTrack: tb)
    check(la.trackID == 1 && lb.trackID == 2, "layer instructions name their tracks")
    la.setOpacityRamp(fromStartOpacity: 1, toEndOpacity: 0, timeRange: range(1, 2))
    // B moves 40 px right and is cropped to its left 100 px for the last second
    lb.setTransform(.identity, at: .zero)
    lb.setTransform(CGAffineTransform(translationX: 40, y: 0), at: CMTime(seconds: 2, preferredTimescale: 600))
    lb.setCropRectangle(CGRect(x: 0, y: 0, width: 100, height: H), at: CMTime(seconds: 2, preferredTimescale: 600))
    var s: Float = -1, e: Float = -1, tr = CMTimeRange.invalid
    check(la.getOpacityRamp(for: CMTime(seconds: 1.5, preferredTimescale: 600), startOpacity: &s, endOpacity: &e, timeRange: &tr) && s == 1 && e == 0
          && abs(tr.start.seconds - 1) < 1e-6 && abs(tr.duration.seconds - 1) < 1e-6, "getOpacityRamp: the ramp in effect (\(s) to \(e), \(tr.start.seconds)+\(tr.duration.seconds))")
    check(la.getOpacityRamp(for: CMTime(seconds: 0.5, preferredTimescale: 600), startOpacity: &s, endOpacity: &e, timeRange: &tr) && s == 1 && e == 1,
          "getOpacityRamp: 1 before the first ramp")
    check(!la.getOpacityRamp(for: CMTime(seconds: 2.5, preferredTimescale: 600), startOpacity: &s, endOpacity: &e, timeRange: nil), "getOpacityRamp: false past the last ramp")
    var t0 = CGAffineTransform(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0), t1 = t0
    check(lb.getTransformRamp(for: CMTime(seconds: 2.5, preferredTimescale: 600), start: &t0, end: &t1, timeRange: nil) && t0.tx == 40 && t1.tx == 40,
          "getTransformRamp: a held transform")

    let i1 = AVMutableVideoCompositionInstruction(); i1.timeRange = range(0, 1); i1.layerInstructions = [la]
    let i2 = AVMutableVideoCompositionInstruction(); i2.timeRange = range(1, 2); i2.layerInstructions = [la, lb]
    let i3 = AVMutableVideoCompositionInstruction(); i3.timeRange = range(2, 3); i3.layerInstructions = [lb]
    i3.backgroundColor = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
    check(i2.requiredSourceTrackIDs?.compactMap { ($0 as? NSNumber)?.int32Value } == [1, 2], "requiredSourceTrackIDs are the layer instructions' tracks")
    check(i1.enablePostProcessing && i1.containsTweening && i1.passthroughTrackID == kCMPersistentTrackID_Invalid, "instruction defaults")
    let vc = AVMutableVideoComposition()
    vc.renderSize = CGSize(width: W, height: H); vc.frameDuration = CMTime(value: 1, timescale: 10)
    vc.instructions = [i1, i2, i3]
    let copy = vc.copy() as! AVVideoComposition
    check(copy.instructions.count == 3 && !(copy is AVMutableVideoComposition) && vc.mutableCopy() is AVMutableVideoComposition, "copy and mutableCopy")
    check(vc.isValid(for: comp, timeRange: CMTimeRange(start: .zero, duration: comp.duration), validationDelegate: nil), "the composition is valid")

    let (url, session) = export(comp, vc, "crossfade.mov")
    check(session.status == .completed, "export with instructions completes (\(session.error.map { "\($0)" } ?? "ok"))")
    let fs = frames(of: url)
    check(fs.count >= 28 && fs.count <= 31, "30 frames at 10 per second (\(fs.count))")
    let p05 = pixel(fs, at: 0.5, 80, 60), p15 = pixel(fs, at: 1.5, 80, 60), p25 = pixel(fs, at: 2.5, 80, 60)
    check(near(p05, red), "0.5 s: track 1 alone \(show(p05))")
    check(near(p15, (128, 0, 128), 50), "1.5 s: track 1 half faded over track 2 \(show(p15))")
    check(near(pixel(fs, at: 1.95, 80, 60), blue, 50), "1.95 s: track 1 faded out \(show(pixel(fs, at: 1.95, 80, 60)))")
    check(near(pixel(fs, at: 1.5, 10, 10), (255, 128, 128), 50), "1.5 s: track 2's mark, top left, through track 1 \(show(pixel(fs, at: 1.5, 10, 10)))")
    check(near(p25, blue), "2.5 s: track 2 moved \(show(p25))")
    check(near(pixel(fs, at: 2.5, 50, 10), white), "2.5 s: the mark moved 40 px right \(show(pixel(fs, at: 2.5, 50, 10)))")
    check(near(pixel(fs, at: 2.5, 20, 60), green), "2.5 s: the background color left of the moved track \(show(pixel(fs, at: 2.5, 20, 60)))")
    check(near(pixel(fs, at: 2.5, 150, 60), green), "2.5 s: the crop shows the background \(show(pixel(fs, at: 2.5, 150, 60)))")

    // instructions that leave a gap: invalid, and the export fails like iOS's
    final class Delegate: NSObject, AVVideoCompositionValidationHandling, @unchecked Sendable {
        var empty: [CMTimeRange] = []
        func videoComposition(_ videoComposition: AVVideoComposition, shouldContinueValidatingAfterFindingEmptyTimeRange timeRange: CMTimeRange) -> Bool {
            empty.append(timeRange); return true
        }
    }
    let gap = AVMutableVideoComposition()
    gap.renderSize = vc.renderSize; gap.frameDuration = vc.frameDuration
    gap.instructions = [i1, i3]
    let d = Delegate()
    let gapValid = gap.isValid(for: comp, timeRange: CMTimeRange(start: .zero, duration: comp.duration), validationDelegate: d)
    check(!gapValid && d.empty.count == 1
          && abs((d.empty.first?.start.seconds ?? 0) - 1) < 1e-6, "a gap between instructions is reported (\(d.empty.map { "\($0.start.seconds)-\($0.end.seconds)" }))")
    let (_, failed) = export(comp, gap, "gap.mov")
    check(failed.status == .failed && (failed.error as NSError?)?.code == AVError.Code.invalidVideoComposition.rawValue,
          "an export with a gap fails with AVError.invalidVideoComposition (\((failed.error as NSError?)?.code ?? 0))")

    // propertiesOf: the render size, frame rate and one instruction over the asset
    let p = AVMutableVideoComposition(propertiesOf: comp)
    let pi = p.instructions.first as? AVVideoCompositionInstruction
    check(p.renderSize == CGSize(width: W, height: H) && p.frameDuration == CMTime(value: 1, timescale: 10), "propertiesOf: render size and frame duration")
    check(p.instructions.count == 1 && pi?.layerInstructions.map(\.trackID) == [1, 2] && abs((pi?.timeRange.duration.seconds ?? 0) - 3) < 0.01,
          "propertiesOf: one instruction with both tracks over the composition")
}

// MARK: - a custom compositor
final class InvertInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let trackID: CMPersistentTrackID
    init(_ r: CMTimeRange, _ id: CMPersistentTrackID) { timeRange = r; trackID = id }
    var enablePostProcessing: Bool { false }
    var containsTweening: Bool { false }
    var requiredSourceTrackIDs: [NSValue]? { [NSNumber(value: trackID)] }
    var passthroughTrackID: CMPersistentTrackID { kCMPersistentTrackID_Invalid }
}
final class InvertCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    nonisolated(unsafe) static var contexts = 0, requests = 0, times: [Double] = [], sources: Set<[Int32]> = []
    nonisolated(unsafe) static var size = CGSize.zero
    let queue = DispatchQueue(label: "invert")
    var sourcePixelBufferAttributes: [String: any Sendable]? { [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA]] }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] { [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA]] }
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) { Self.contexts += 1; Self.size = newRenderContext.size }
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        queue.async {                                               // finishes on another queue, like most compositors
            Self.requests += 1
            Self.times.append(request.compositionTime.seconds)
            Self.sources.insert(request.sourceTrackIDs.map(\.int32Value))
            guard let ins = request.videoCompositionInstruction as? InvertInstruction, let src = request.sourceFrame(byTrackID: ins.trackID),
                  let out = request.renderContext.newPixelBuffer() else {
                request.finish(with: NSError(domain: "InvertCompositor", code: 1)); return
            }
            CVPixelBufferLockBaseAddress(src, .readOnly); CVPixelBufferLockBaseAddress(out, [])
            let s = CVPixelBufferGetBaseAddress(src)!.assumingMemoryBound(to: UInt8.self), d = CVPixelBufferGetBaseAddress(out)!.assumingMemoryBound(to: UInt8.self)
            let sb = CVPixelBufferGetBytesPerRow(src), db = CVPixelBufferGetBytesPerRow(out)
            for y in 0..<CVPixelBufferGetHeight(out) {
                for x in 0..<CVPixelBufferGetWidth(out) {
                    for c in 0..<3 { d[y * db + x * 4 + c] = 255 - s[y * sb + x * 4 + c] }
                    d[y * db + x * 4 + 3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(out, []); CVPixelBufferUnlockBaseAddress(src, .readOnly)
            request.finish(withComposedVideoFrame: out)
        }
    }
}
func custom() {
    let asset = AVURLAsset(url: movie("red2.mov", red))
    let vc = AVMutableVideoComposition()
    vc.renderSize = CGSize(width: W, height: H); vc.frameDuration = CMTime(value: 1, timescale: 10)
    vc.customVideoCompositorClass = InvertCompositor.self
    vc.instructions = [InvertInstruction(range(0, 2), asset.tracks(withMediaType: .video)[0].trackID)]
    check(vc.customVideoCompositorClass == InvertCompositor.self, "customVideoCompositorClass")
    let (url, session) = export(asset, vc, "inverted.mov")
    check(session.status == .completed, "export through a custom compositor completes (\(session.error.map { "\($0)" } ?? "ok"))")
    let fs = frames(of: url)
    check(near(pixel(fs, at: 1, 80, 60), (0, 255, 255)), "the compositor's frames: red inverted to cyan \(show(pixel(fs, at: 1, 80, 60)))")
    check(InvertCompositor.contexts == 1 && InvertCompositor.size == CGSize(width: W, height: H), "renderContextChanged with the render size")
    check(InvertCompositor.requests == 20 && InvertCompositor.times.first == 0 && abs((InvertCompositor.times.last ?? 0) - 1.9) < 1e-6,
          "one request per frame at its composition time (\(InvertCompositor.requests), last \(InvertCompositor.times.last ?? -1))")
    check(InvertCompositor.sources == [[asset.tracks(withMediaType: .video)[0].trackID]], "requests carry the instruction's source tracks")
    check(session.customVideoCompositor is InvertCompositor, "the export session's customVideoCompositor")

    // the reader's video composition output: the compositor instance it made
    let r = try! AVAssetReader(asset: asset)
    let o = AVAssetReaderVideoCompositionOutput(videoTracks: asset.tracks(withMediaType: .video), videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    o.videoComposition = vc
    r.add(o); r.startReading()
    var n = 0, first: RGB?
    while let sb = o.copyNextSampleBuffer() { if n == 0, let pb = sb.imageBuffer { first = pixel(pb, 80, 60) }; n += 1 }
    check(o.customVideoCompositor is InvertCompositor && n == 20 && near(first, (0, 255, 255)),
          "AVAssetReaderVideoCompositionOutput composes through the custom compositor (\(n) frames, \(show(first)))")
}

// MARK: - Core Image filtering
func coreImage() {
    let asset = AVURLAsset(url: movie("blue2.mov", blue, mark: white))
    final class Seen: @unchecked Sendable { var times: [Double] = []; var sizes: Set<String> = [] }
    let seen = Seen()
    let vc = AVVideoComposition(asset: asset) { req in
        seen.times.append(req.compositionTime.seconds); seen.sizes.insert("\(Int(req.renderSize.width))x\(Int(req.renderSize.height))")
        let inverted = req.sourceImage.applyingFilter("CIColorInvert")
        req.finish(with: inverted, context: nil)
    }
    check(vc.renderSize == CGSize(width: W, height: H), "the CI composition's render size is the track's")
    let r = try! AVAssetReader(asset: asset)
    let o = AVAssetReaderVideoCompositionOutput(videoTracks: asset.tracks(withMediaType: .video), videoSettings: nil)
    o.videoComposition = vc
    r.add(o); r.startReading()
    var fs: [(Double, CVPixelBuffer)] = []
    while let sb = o.copyNextSampleBuffer() { if let pb = sb.imageBuffer { fs.append((sb.presentationTimeStamp.seconds, pb)) } }
    check(fs.count == 20 && seen.times.count == 20 && seen.sizes == ["\(W)x\(H)"], "the handler sees every frame at the render size (\(fs.count), \(seen.times.count), \(seen.sizes))")
    check(near(pixel(fs, at: 0.5, 80, 60), (255, 255, 0)), "CIColorInvert: blue to yellow \(show(pixel(fs, at: 0.5, 80, 60)))")
    check(near(pixel(fs, at: 0.5, 10, 10), (0, 0, 0)), "the mark stays top left (white to black) \(show(pixel(fs, at: 0.5, 10, 10)))")

    // AVAssetImageGenerator composes the frame too (no encoding: exact colors)
    let g = AVAssetImageGenerator(asset: asset)
    g.videoComposition = vc
    var actual = CMTime.zero
    if let img = try? g.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: &actual) {
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: -80, y: -60, width: img.width, height: img.height))
        check(img.width == W && img.height == H && near((Int(px[0]), Int(px[1]), Int(px[2])), (255, 255, 0), 8) && abs(actual.seconds - 1) < 1e-6,
              "AVAssetImageGenerator with a video composition: \(img.width)x\(img.height) (\(px[0]),\(px[1]),\(px[2])) at \(actual.seconds)")
    } else { check(false, "AVAssetImageGenerator with a video composition") }

    // iOS 26: the async applier
    if #available(iOS 26.0, *) {
        let sem = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var vc: AVVideoComposition? }
        let box = Box()
        Task {
            box.vc = try? await AVVideoComposition(applyingFiltersTo: asset) { p in
                AVCIImageFilteringResult(resultImage: p.sourceImage.applyingFilter("CIColorInvert"))
            }
            sem.signal()
        }
        sem.wait()
        if let avc = box.vc {
            let (url, session) = export(asset, avc, "applier.mov")
            let af = frames(of: url)
            check(session.status == .completed && near(pixel(af, at: 0.5, 80, 60), (255, 255, 0)),
                  "AVVideoComposition(applyingFiltersTo:applier:) \(show(pixel(af, at: 0.5, 80, 60)))")
        } else { check(false, "AVVideoComposition(applyingFiltersTo:applier:)") }
    }
}

// MARK: - the Core Animation tool
func animationTool() {
    let asset = AVURLAsset(url: movie("red3.mov", red))
    let vc = AVMutableVideoComposition(propertiesOf: asset)
    let parent = CALayer(), video = CALayer()
    parent.frame = CGRect(x: 0, y: 0, width: W, height: H); video.frame = parent.frame
    parent.addSublayer(video)
    // a yellow box at y 0: the bottom of the video (the tool's layers have their origin at the bottom left, as on iOS)
    let box = CALayer(); box.frame = CGRect(x: 0, y: 0, width: 40, height: 30); box.backgroundColor = UIColor.yellow.cgColor
    parent.addSublayer(box)
    // a white box fading in over the first second of the video
    let fade = CALayer(); fade.frame = CGRect(x: 120, y: 90, width: 40, height: 30); fade.backgroundColor = UIColor.white.cgColor
    let a = CABasicAnimation(keyPath: "opacity")
    a.fromValue = 0; a.toValue = 1; a.duration = 1; a.beginTime = AVCoreAnimationBeginTimeAtZero; a.fillMode = .both
    fade.add(a, forKey: "fade")
    fade.opacity = 1
    parent.addSublayer(fade)
    vc.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: video, in: parent)
    let (url, session) = export(asset, vc, "animated.mov")
    check(session.status == .completed, "export with the Core Animation tool completes (\(session.error.map { "\($0)" } ?? "ok"))")
    let fs = frames(of: url)
    check(near(pixel(fs, at: 1, 80, 60), red), "the video shows in the video layer \(show(pixel(fs, at: 1, 80, 60)))")
    check(near(pixel(fs, at: 1, 10, 110), (255, 255, 0)), "a layer at y 0 is at the bottom of the frame \(show(pixel(fs, at: 1, 10, 110)))")
    check(near(pixel(fs, at: 1, 10, 10), red), "and not at the top \(show(pixel(fs, at: 1, 10, 10)))")
    let early = pixel(fs, at: 0.1, 140, 10), mid = pixel(fs, at: 0.5, 140, 10), late = pixel(fs, at: 1.5, 140, 10)
    check(near(early, (255, 26, 26), 45) && near(mid, (255, 128, 128), 45) && near(late, white), "the animation runs on the video's clock: \(show(early)) \(show(mid)) \(show(late))")
    check(fade.animation(forKey: "fade") != nil, "the animation stays on the layer (the display does not end it)")

    // geometry-flipped: a layer at y 0 is at the top
    parent.isGeometryFlipped = true
    let (furl, fsession) = export(asset, vc, "flipped.mov")
    let ff = frames(of: furl)
    check(fsession.status == .completed && near(pixel(ff, at: 1, 10, 10), (255, 255, 0)) && near(pixel(ff, at: 1, 10, 110), red),
          "a geometry-flipped parent puts y 0 at the top \(show(pixel(ff, at: 1, 10, 10)))")

    // an extra layer as a source track
    let magenta = CALayer(); magenta.frame = CGRect(x: 0, y: 0, width: W, height: H); magenta.backgroundColor = UIColor.magenta.cgColor
    let extra = AVMutableVideoComposition(propertiesOf: asset)
    extra.animationTool = AVVideoCompositionCoreAnimationTool(additionalLayer: magenta, asTrackID: 99)
    let li = AVMutableVideoCompositionLayerInstruction(); li.trackID = 99
    li.setCropRectangle(CGRect(x: 0, y: 0, width: 80, height: H), at: .zero)
    let base = AVMutableVideoCompositionLayerInstruction(assetTrack: asset.tracks(withMediaType: .video)[0])
    let ins = AVMutableVideoCompositionInstruction(); ins.timeRange = range(0, 2); ins.layerInstructions = [li, base]
    extra.instructions = [ins]
    let (eurl, esession) = export(asset, extra, "extra.mov")
    let ef = frames(of: eurl)
    check(esession.status == .completed && near(pixel(ef, at: 1, 40, 60), (255, 0, 255)) && near(pixel(ef, at: 1, 120, 60), red),
          "an additional layer track composed over the video \(show(pixel(ef, at: 1, 40, 60))) \(show(pixel(ef, at: 1, 120, 60)))")
}

// MARK: - iOS 26 configurations
func configurations() {
    guard #available(iOS 26.0, *) else { print("configurations: iOS 26 only"); return }
    var lc = AVVideoCompositionLayerInstruction.Configuration(trackID: 7)
    lc.addOpacityRamp(.init(timeRange: range(0, 1), start: 0, end: 1))
    lc.setTransform(CGAffineTransform(scaleX: 2, y: 2), at: .zero)
    let l = AVVideoCompositionLayerInstruction(configuration: lc)
    check(l.trackID == 7 && l.opacityRamp(at: CMTime(seconds: 0.5, preferredTimescale: 600))?.end == 1
          && l.transformRamp(at: .zero)?.start.a == 2 && lc.opacityRamp(at: CMTime(seconds: 3, preferredTimescale: 600)) == nil, "AVVideoCompositionLayerInstruction.Configuration")
    let ic = AVVideoCompositionInstruction.Configuration(layerInstructions: [l], timeRange: range(0, 2))
    let i = AVVideoCompositionInstruction(configuration: ic)
    check(i.layerInstructions.count == 1 && abs(i.timeRange.duration.seconds - 2) < 1e-6 && i.enablePostProcessing, "AVVideoCompositionInstruction.Configuration")
    let video = CALayer(), parent = CALayer()
    let tc = AVVideoCompositionCoreAnimationTool.Configuration(postProcessingAsVideoLayer: video, containingLayer: parent)
    check(tc.layers.count == 1 && tc.containingLayer === parent, "AVVideoCompositionCoreAnimationTool.Configuration")
    _ = AVVideoCompositionCoreAnimationTool(configuration: tc)
}

@main enum VideoCompositionTest {
    static func main() {
        DispatchQueue.global().async {        // the main queue stays free: the Core Animation tool draws there
            instructions()
            custom()
            coreImage()
            animationTool()
            configurations()
            print("VideoCompositionTest: \(checks - failures)/\(checks) passed")
            exit(failures == 0 ? 0 : 1)
        }
        dispatchMain()
    }
}
