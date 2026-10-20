// VideoToolbox (VideoToolboxTest.app, issue #284): compression sessions (H.264 and HEVC; bit rate, key frame
// interval, forced key frames, profile), decompression sessions (BGRA and 420v output, callbacks and handlers,
// refcons, timestamps), pixel transfer sessions (format conversion; normal, letterbox and trim scaling),
// VTCreateCGImageFromCVPixelBuffer, properties and invalidation.
import Foundation
import VideoToolbox
import CoreGraphics

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

func solid(_ c: (UInt8, UInt8, UInt8), _ w: Int = 160, _ h: Int = 120, format: OSType = kCVPixelFormatType_32BGRA) -> CVPixelBuffer {
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, nil, &pb)
    let b = pb!
    CVPixelBufferLockBaseAddress(b, [])
    let base = CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to: UInt8.self), bpr = CVPixelBufferGetBytesPerRow(b)
    for y in 0 ..< h { for x in 0 ..< w { let p = base + y * bpr + x * 4; p[0] = c.2; p[1] = c.1; p[2] = c.0; p[3] = 255 } }
    CVPixelBufferUnlockBaseAddress(b, [])
    return b
}
/// the colour at (x, y) of any pixel buffer, through a pixel transfer to BGRA
func colour(_ b: CVPixelBuffer, _ x: Int, _ y: Int) -> (Int, Int, Int) {
    var bgra = b
    if CVPixelBufferGetPixelFormatType(b) != kCVPixelFormatType_32BGRA {
        var t: VTPixelTransferSession?
        VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &t)
        var out: CVPixelBuffer?
        CVPixelBufferCreate(nil, CVPixelBufferGetWidth(b), CVPixelBufferGetHeight(b), kCVPixelFormatType_32BGRA, nil, &out)
        _ = VTPixelTransferSessionTransferImage(t!, from: b, to: out!)
        bgra = out!
    }
    CVPixelBufferLockBaseAddress(bgra, .readOnly); defer { CVPixelBufferUnlockBaseAddress(bgra, .readOnly) }
    let p = CVPixelBufferGetBaseAddress(bgra)!.assumingMemoryBound(to: UInt8.self) + y * CVPixelBufferGetBytesPerRow(bgra) + x * 4
    return (Int(p[2]), Int(p[1]), Int(p[0]))
}
func near(_ a: (Int, Int, Int), _ b: (Int, Int, Int), _ tol: Int = 40) -> Bool { abs(a.0 - b.0) <= tol && abs(a.1 - b.1) <= tol && abs(a.2 - b.2) <= tol }
let red = (255, 0, 0), blue = (0, 0, 255), black = (0, 0, 0)

final class Collected: @unchecked Sendable { var samples: [CMSampleBuffer] = []; var statuses: [OSStatus] = []; var refcons: [Int] = [] }

/// encodes 20 frames (10 red, 10 blue), key frames every 10 and forced at 15
func encode(_ codec: CMVideoCodecType) -> [CMSampleBuffer] {
    let got = Collected()
    var session: VTCompressionSession?
    let st = VTCompressionSessionCreate(allocator: nil, width: 160, height: 120, codecType: codec, encoderSpecification: nil, imageBufferAttributes: nil,
                                        compressedDataAllocator: nil, outputCallback: { refcon, frameRefcon, status, flags, sb in
        let c = Unmanaged<Collected>.fromOpaque(refcon!).takeUnretainedValue()
        c.statuses.append(status)
        if let sb { c.samples.append(sb) }
        c.refcons.append(Int(bitPattern: frameRefcon))
    }, refcon: Unmanaged.passUnretained(got).toOpaque(), compressionSessionOut: &session)
    guard st == noErr, let s = session else { print("      create \(st)"); return [] }
    VTSessionSetProperty(s, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
    VTSessionSetProperty(s, key: kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: 400_000))
    VTSessionSetProperty(s, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: 10))
    VTSessionSetProperty(s, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: 30))
    if codec == kCMVideoCodecType_H264 { VTSessionSetProperty(s, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel) }
    _ = VTCompressionSessionPrepareToEncodeFrames(s)
    for i in 0 ..< 20 {
        let props: CFDictionary? = i == 15 ? [kVTEncodeFrameOptionKey_ForceKeyFrame as String: true] as CFDictionary : nil
        _ = VTCompressionSessionEncodeFrame(s, imageBuffer: solid(i < 10 ? (255, 0, 0) : (0, 0, 255)), presentationTimeStamp: CMTime(value: Int64(i), timescale: 30),
                                            duration: CMTime(value: 1, timescale: 30), frameProperties: props, sourceFrameRefcon: UnsafeMutableRawPointer(bitPattern: 1000 + i),
                                            infoFlagsOut: nil)
    }
    _ = VTCompressionSessionCompleteFrames(s, untilPresentationTimeStamp: .invalid)
    let name = codec == kCMVideoCodecType_H264 ? "H.264" : "HEVC"
    check(got.samples.count == 20 && got.statuses.allSatisfy { $0 == noErr } && got.refcons == (0 ..< 20).map { 1000 + $0 }, "\(name): 20 frames out, in order, with their refcons")
    let keys = got.samples.enumerated().filter { _isSync($0.element) }.map(\.offset)
    check(keys == [0, 10, 15], "\(name): key frames every 10 and forced at 15 (\(keys))")
    let f = got.samples.first.flatMap { CMSampleBufferGetFormatDescription($0) }
    let dims = f.map { CMVideoFormatDescriptionGetDimensions($0) }
    check(f.map { CMFormatDescriptionGetMediaSubType($0) } == codec && dims?.width == 160 && dims?.height == 120, "\(name): the format description (codec, 160x120)")
    check(got.samples.map { $0.presentationTimeStamp.value } == (0 ..< 20).map { Int64($0) }, "\(name): presentation times kept")
    VTCompressionSessionInvalidate(s)
    check(VTCompressionSessionEncodeFrame(s, imageBuffer: solid((0, 0, 0)), presentationTimeStamp: .zero, duration: .invalid, frameProperties: nil,
                                          sourceFrameRefcon: nil, infoFlagsOut: nil) == kVTInvalidSessionErr, "\(name): an invalidated session refuses frames")
    return got.samples
}
func _isSync(_ sb: CMSampleBuffer) -> Bool {
    guard let a = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [NSDictionary], let d = a.first else { return true }
    return (d[kCMSampleAttachmentKey_NotSync as String] as? Bool) != true
}

final class Frames: @unchecked Sendable { var images: [CVImageBuffer] = []; var times: [Int64] = []; var refcons: [Int] = [] }
func decode(_ samples: [CMSampleBuffer], name: String) {
    guard let f = samples.first.flatMap({ CMSampleBufferGetFormatDescription($0) }) else { check(false, "\(name): nothing to decode"); return }
    // BGRA through the callback record
    let got = Frames()
    var record = VTDecompressionOutputCallbackRecord(decompressionOutputCallback: { refcon, frameRefcon, status, flags, image, pts, duration in
        let g = Unmanaged<Frames>.fromOpaque(refcon!).takeUnretainedValue()
        if status == noErr, let image { g.images.append(image); g.times.append(pts.value); g.refcons.append(Int(bitPattern: frameRefcon)) }
    }, decompressionOutputRefCon: Unmanaged.passUnretained(got).toOpaque())
    var session: VTDecompressionSession?
    let attrs = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA] as CFDictionary
    check(VTDecompressionSessionCreate(allocator: nil, formatDescription: f, decoderSpecification: nil, imageBufferAttributes: attrs, outputCallback: &record,
                                       decompressionSessionOut: &session) == noErr, "\(name): decompression session")
    guard let s = session else { return }
    for (i, sb) in samples.enumerated() {
        _ = VTDecompressionSessionDecodeFrame(s, sampleBuffer: sb, flags: [._EnableAsynchronousDecompression], frameRefcon: UnsafeMutableRawPointer(bitPattern: 500 + i), infoFlagsOut: nil)
    }
    _ = VTDecompressionSessionFinishDelayedFrames(s)
    _ = VTDecompressionSessionWaitForAsynchronousFrames(s)
    check(got.images.count == 20 && got.times == (0 ..< 20).map { Int64($0) } && got.refcons == (0 ..< 20).map { 500 + $0 }, "\(name): 20 frames decoded in order with their refcons")
    check(got.images.first.map { CVPixelBufferGetPixelFormatType($0) == kCVPixelFormatType_32BGRA && CVPixelBufferGetWidth($0) == 160 } == true, "\(name): BGRA 160x120 as asked")
    check(got.images.count == 20 && near(colour(got.images[3], 80, 60), red) && near(colour(got.images[13], 80, 60), blue), "\(name): the pictures (red, then blue)")
    check(VTDecompressionSessionCanAcceptFormatDescription(s, formatDescription: f), "\(name): CanAcceptFormatDescription")
    VTDecompressionSessionInvalidate(s)

    // the default output (420v) through an output handler
    var s2: VTDecompressionSession?
    VTDecompressionSessionCreate(allocator: nil, formatDescription: f, decoderSpecification: nil, imageBufferAttributes: nil, outputCallback: nil, decompressionSessionOut: &s2)
    var yuv: CVImageBuffer?
    for sb in samples.prefix(12) {
        _ = VTDecompressionSessionDecodeFrame(s2!, sampleBuffer: sb, flags: [], infoFlagsOut: nil) { status, _, image, _, _ in if status == noErr { yuv = image } }
    }
    check(yuv.map { CVPixelBufferGetPixelFormatType($0) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange && CVPixelBufferGetPlaneCount($0) == 2 } == true,
          "\(name): 420v (bi-planar) by default")
    check(yuv.map { near(colour($0, 80, 60), blue) } == true, "\(name): the 420v picture")
}

@main enum VideoToolboxTest {
    static func main() {
        check(VTIsHardwareDecodeSupported(kCMVideoCodecType_H264) && VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC), "VTIsHardwareDecodeSupported")
        let h264 = encode(kCMVideoCodecType_H264)
        decode(h264, name: "H.264")
        let hevc = encode(kCMVideoCodecType_HEVC)
        decode(hevc, name: "HEVC")

        // pixel transfer: 160x120 red into 80x80
        var t: VTPixelTransferSession?
        check(VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &t) == noErr, "pixel transfer session")
        let src = solid((255, 0, 0))
        var dst: CVPixelBuffer?
        CVPixelBufferCreate(nil, 80, 80, kCVPixelFormatType_32BGRA, nil, &dst)
        _ = VTPixelTransferSessionTransferImage(t!, from: src, to: dst!)
        check(near(colour(dst!, 40, 2), red) && near(colour(dst!, 40, 40), red), "normal scaling stretches")
        VTSessionSetProperty(t!, key: kVTPixelTransferPropertyKey_ScalingMode, value: kVTScalingMode_Letterbox)
        _ = VTPixelTransferSessionTransferImage(t!, from: src, to: dst!)
        check(near(colour(dst!, 40, 4), black, 10) && near(colour(dst!, 40, 40), red) && near(colour(dst!, 40, 76), black, 10), "letterbox: black bars above and below")
        var yuv: CVPixelBuffer?
        CVPixelBufferCreate(nil, 80, 60, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, nil, &yuv)
        _ = VTPixelTransferSessionTransferImage(t!, from: solid((0, 0, 255)), to: yuv!)
        check(near(colour(yuv!, 40, 30), blue), "BGRA to 420f")
        var value: AnyObject?
        let copied = withUnsafeMutablePointer(to: &value) { VTSessionCopyProperty(t!, key: kVTPixelTransferPropertyKey_ScalingMode, allocator: nil, valueOut: $0) }
        check(copied == noErr && (value as? String) == kVTScalingMode_Letterbox as String, "VTSessionCopyProperty")

        // CGImage
        var image: CGImage?
        check(VTCreateCGImageFromCVPixelBuffer(solid((0, 255, 0), 32, 16), options: nil, imageOut: &image) == noErr && image?.width == 32 && image?.height == 16,
              "VTCreateCGImageFromCVPixelBuffer: 32x16")
        let ctx = CGContext(data: nil, width: 32, height: 16, bitsPerComponent: 8, bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        if let image { ctx.draw(image, in: CGRect(x: 0, y: 0, width: 32, height: 16)) }
        let px = ctx.data!.assumingMemoryBound(to: UInt8.self) + 8 * 128 + 16 * 4
        check(px[0] < 40 && px[1] > 215 && px[2] < 40, "the CGImage draws green")

        print("videotoolbox: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
