// Core Media from Swift (CoreMediaTest.app, issue #383): time range and time mapping functions and their dictionaries,
// CMSimpleQueue, CMBufferQueue (ordering, timestamps, end of data, triggers, validation, the iOS 13 Swift API),
// sample buffer copies, and video format descriptions (clean aperture, presentation size, matching image buffers,
// QuickTime image descriptions).
import Foundation
import CoreMedia
import CoreVideo

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}
func t(_ v: Int64, _ s: Int32 = 1) -> CMTime { CMTime(value: v, timescale: s) }
func r(_ start: Int64, _ duration: Int64) -> CMTimeRange { CMTimeRange(start: t(start), duration: t(duration)) }

/// a CF buffer for the queues: an NSDictionary with its times in seconds
func buffer(pts: Int64, duration: Int64 = 1, dts: Int64? = nil, ready: Bool = true, size: Int = 10) -> CMBuffer {
    ["pts": pts, "dur": duration, "dts": dts ?? pts, "ready": ready, "size": size] as NSDictionary
}
func field(_ b: CMBuffer, _ k: String) -> Int64 { ((b as! NSDictionary)[k] as! NSNumber).int64Value }

func timeRanges() {
    check(CMTimeRangeContainsTimeRange(r(0, 10), otherRange: r(2, 3)), "CMTimeRangeContainsTimeRange: inside")
    check(CMTimeRangeContainsTimeRange(r(0, 10), otherRange: r(0, 10)), "CMTimeRangeContainsTimeRange: equal ranges")
    check(!CMTimeRangeContainsTimeRange(r(0, 10), otherRange: r(8, 3)), "CMTimeRangeContainsTimeRange: overlapping the end")
    check(CMTIMERANGE_IS_VALID(r(0, 1)) && CMTIMERANGE_IS_INVALID(.invalid) && CMTIMERANGE_IS_EMPTY(r(3, 0)) &&
          CMTIMERANGE_IS_INDEFINITE(CMTimeRange(start: .indefinite, duration: t(1))), "CMTIMERANGE_IS_* macros")
    check(CMTIME_IS_VALID(t(1)) && CMTIME_IS_INVALID(.invalid) && CMTIME_IS_NUMERIC(t(2)) && CMTIME_IS_POSITIVEINFINITY(.positiveInfinity) &&
          CMTIME_IS_NEGATIVEINFINITY(.negativeInfinity) && CMTIME_IS_INDEFINITE(.indefinite), "CMTIME_IS_* macros")
    check(CMTimeMapTimeFromRangeToRange(t(15), fromRange: r(10, 10), toRange: r(100, 20)) == t(110), "CMTimeMapTimeFromRangeToRange: 15 in 10..20 -> 110 in 100..120")
    check(CMTimeMapDurationFromRangeToRange(t(5), fromRange: r(0, 10), toRange: r(0, 20)) == t(10), "CMTimeMapDurationFromRangeToRange doubles")
    check(CMTimeFoldIntoRange(t(23), foldRange: r(10, 5)) == t(13), "CMTimeFoldIntoRange: 23 into 10..15 -> 13")
    check(CMTimeFoldIntoRange(t(7), foldRange: r(10, 5)) == t(12), "CMTimeFoldIntoRange: before the range")
    check(CMTimeClampToRange(t(30), range: r(0, 10)) == t(10), "CMTimeClampToRange")

    let range = CMTimeRange(start: t(1, 30), duration: t(90, 30))
    let d = CMTimeRangeCopyAsDictionary(range, allocator: nil)!
    check(CMTimeRangeMakeFromDictionary(d) == range, "CMTimeRangeCopyAsDictionary / MakeFromDictionary round trip")
    check(((d as NSDictionary)[kCMTimeRangeStartKey as String] as? NSDictionary)?[kCMTimeScaleKey as String] as? Int == 30, "the range dictionary's start timescale")
    check(CMTimeMakeFromDictionary(CMTimeCopyAsDictionary(t(7, 600), allocator: nil)) == t(7, 600), "CMTimeCopyAsDictionary round trip")
    check((CMTimeRangeCopyDescription(allocator: nil, range: r(1, 2))! as String) == "{{1/1 = 1.000}, {2/1 = 2.000}}", "CMTimeRangeCopyDescription")

    let m = CMTimeMappingMake(source: r(0, 10), target: r(5, 10))
    check(m.source == r(0, 10) && m.target == r(5, 10), "CMTimeMappingMake")
    check(CMTimeMappingMake(source: .invalid, target: r(0, 1)) == .invalid, "CMTimeMappingMake with an invalid range: .invalid")
    let empty = CMTimeMappingMakeEmpty(target: r(3, 4))
    check(!empty.source.start.isValid && empty.source.duration == t(4) && empty.target == r(3, 4), "CMTimeMappingMakeEmpty")
    check(CMTimeMappingMakeFromDictionary(CMTimeMappingCopyAsDictionary(m, allocator: nil)!) == m, "CMTimeMapping dictionary round trip")
    check((CMTimeMappingCopyDescription(allocator: nil, mapping: m)! as String).hasPrefix("{source = {{0/1"), "CMTimeMappingCopyDescription")
    check(CMTimeMapping() == .invalid, "CMTimeMapping() is invalid")
}

func simpleQueues() {
    var q: CMSimpleQueue?
    check(CMSimpleQueueCreate(allocator: nil, capacity: 3, queueOut: &q) == noErr && q != nil, "CMSimpleQueueCreate")
    check(CMSimpleQueueCreate(allocator: nil, capacity: 0, queueOut: &q) == kCMSimpleQueueError_ParameterOutOfRange, "CMSimpleQueueCreate: capacity 0")
    _ = CMSimpleQueueCreate(allocator: nil, capacity: 3, queueOut: &q)
    let queue = q!
    let p = (1...4).map { UnsafeRawPointer(bitPattern: $0 * 16)! }
    for e in p.prefix(3) { _ = CMSimpleQueueEnqueue(queue, element: e) }
    check(CMSimpleQueueEnqueue(queue, element: p[3]) == kCMSimpleQueueError_QueueIsFull, "CMSimpleQueueEnqueue on a full queue")
    check(CMSimpleQueueGetCount(queue) == 3 && CMSimpleQueueGetCapacity(queue) == 3 && queue.fullness == 1, "count, capacity, fullness")
    check(CMSimpleQueueGetHead(queue) == p[0] && CMSimpleQueueDequeue(queue) == p[0] && CMSimpleQueueDequeue(queue) == p[1], "FIFO order")
    _ = CMSimpleQueueEnqueue(queue, element: p[3])                 // wraps around
    check(CMSimpleQueueDequeue(queue) == p[2] && CMSimpleQueueDequeue(queue) == p[3] && CMSimpleQueueDequeue(queue) == nil, "after wrapping")
    _ = CMSimpleQueueEnqueue(queue, element: p[0])
    check(CMSimpleQueueReset(queue) == noErr && queue.count == 0 && queue.head == nil, "CMSimpleQueueReset")
    check(CMSimpleQueueGetTypeID() == CMSimpleQueue.typeID && CFGetTypeID(queue) == CMSimpleQueueGetTypeID(), "CMSimpleQueueGetTypeID and CFGetTypeID")

    let s = try? CMSimpleQueue(capacity: 1)
    try? s?.enqueue(p[0])
    var threw = false
    do { try s?.enqueue(p[1]) } catch { threw = (error as NSError).code == Int(kCMSimpleQueueError_QueueIsFull) }
    check(threw, "CMSimpleQueue.enqueue throws queueIsFull")
    check((try? CMSimpleQueue(capacity: 0)) == nil, "CMSimpleQueue(capacity: 0) throws")
}

func bufferQueues() {
    // the C-style API: callbacks with a refcon, sorted by presentation time
    var callbacks = CMBufferCallbacks(version: 1, refcon: nil,
                                      getDecodeTimeStamp: { b, _ in t(field(b, "dts")) },
                                      getPresentationTimeStamp: { b, _ in t(field(b, "pts")) },
                                      getDuration: { b, _ in t(field(b, "dur")) },
                                      isDataReady: { b, _ in field(b, "ready") != 0 },
                                      compare: { a, b, _ in field(a, "pts") < field(b, "pts") ? .compareLessThan : field(a, "pts") > field(b, "pts") ? .compareGreaterThan : .compareEqualTo },
                                      dataBecameReadyNotification: nil,
                                      getSize: { b, _ in Int(field(b, "size")) })
    var bq: CMBufferQueue?
    check(CMBufferQueueCreate(allocator: nil, capacity: 0, callbacks: &callbacks, queueOut: &bq) == noErr, "CMBufferQueueCreate")
    let q = bq!
    var fired: [String] = []
    final class Box { var fired: [String] = [] }
    let box = Box()
    let refcon = Unmanaged.passUnretained(box).toOpaque()
    var durationToken: CMBufferQueueTriggerToken?
    check(CMBufferQueueInstallTrigger(q, callback: { r, _ in Unmanaged<Box>.fromOpaque(r!).takeUnretainedValue().fired.append("duration>=3") }, refcon: refcon,
                                      condition: kCMBufferQueueTrigger_WhenDurationBecomesGreaterThanOrEqualTo, time: t(3), triggerTokenOut: &durationToken) == noErr,
          "CMBufferQueueInstallTrigger")
    var countToken: CMBufferQueueTriggerToken?
    _ = CMBufferQueueInstallTriggerHandlerWithIntegerThreshold(q, kCMBufferQueueTrigger_WhenBufferCountBecomesLessThan, 1, &countToken) { _ in fired.append("empty") }
    var eodToken: CMBufferQueueTriggerToken?
    _ = CMBufferQueueInstallTriggerHandler(q, kCMBufferQueueTrigger_WhenEndOfDataReached, .invalid, &eodToken) { _ in fired.append("eod") }
    check(CMBufferQueueInstallTrigger(q, callback: nil, refcon: nil, condition: kCMBufferQueueTrigger_WhenDurationBecomesLessThan, time: .invalid,
                                      triggerTokenOut: nil) == kCMBufferQueueError_BadTriggerDuration, "a duration trigger needs a numeric time")

    for pts: Int64 in [5, 2, 9, 2] { _ = CMBufferQueueEnqueue(q, buffer: buffer(pts: pts, dts: 10 - pts)) }
    check(CMBufferQueueGetBufferCount(q) == 4 && !CMBufferQueueIsEmpty(q), "four buffers queued")
    check(q.buffers.map { field($0, "pts") } == [2, 2, 5, 9], "ordered by the compare callback (stable)")
    check(CMBufferQueueGetDuration(q) == t(4), "CMBufferQueueGetDuration: the sum")
    check(CMBufferQueueGetMinPresentationTimeStamp(q) == t(2) && CMBufferQueueGetMaxPresentationTimeStamp(q) == t(9), "min and max PTS")
    check(CMBufferQueueGetFirstPresentationTimeStamp(q) == t(2) && CMBufferQueueGetEndPresentationTimeStamp(q) == t(10), "first and end PTS")
    check(CMBufferQueueGetFirstDecodeTimeStamp(q) == t(8) && CMBufferQueueGetMinDecodeTimeStamp(q) == t(1), "first and min DTS")
    check(CMBufferQueueGetTotalSize(q) == 40, "CMBufferQueueGetTotalSize")
    check(box.fired == ["duration>=3"], "the duration trigger fired once, on the third buffer")
    check(CMBufferQueueTestTrigger(q, triggerToken: durationToken!), "CMBufferQueueTestTrigger")

    var seen: [Int64] = []
    _ = CMBufferQueueCallForEachBuffer(q, callback: { b, _ in seen.append(field(b, "pts")); return noErr }, refcon: nil)
    check(seen == [2, 2, 5, 9], "CMBufferQueueCallForEachBuffer")
    check(CMBufferQueueGetHead(q).map { field($0, "pts") } == 2 && CMBufferQueueDequeue(q).map { field($0, "pts") } == 2, "CMBufferQueueGetHead / Dequeue")
    check(CMBufferQueueMarkEndOfData(q) == noErr && CMBufferQueueContainsEndOfData(q) && !CMBufferQueueIsAtEndOfData(q), "end of data marked")
    check(CMBufferQueueEnqueue(q, buffer: buffer(pts: 1)) == kCMBufferQueueError_EnqueueAfterEndOfData, "no enqueue after end of data")
    while CMBufferQueueDequeue(q) != nil {}
    check(CMBufferQueueIsAtEndOfData(q) && fired == ["empty", "eod"], "draining fires the count and end-of-data triggers")
    check(CMBufferQueueRemoveTrigger(q, triggerToken: durationToken!) == noErr &&
          CMBufferQueueRemoveTrigger(q, triggerToken: durationToken!) == kCMBufferQueueError_InvalidTriggerToken, "CMBufferQueueRemoveTrigger")
    _ = CMBufferQueueReset(q)
    check(!CMBufferQueueContainsEndOfData(q) && CMBufferQueueEnqueue(q, buffer: buffer(pts: 1, ready: false)) == noErr, "reset clears end of data")
    check(CMBufferQueueDequeueIfDataReady(q) == nil && CMBufferQueueDequeue(q) != nil, "CMBufferQueueDequeueIfDataReady skips a buffer that is not ready")

    // validation
    _ = CMBufferQueueSetValidationHandler(q) { _, b in field(b, "size") > 100 ? -1 : noErr }
    check(CMBufferQueueEnqueue(q, buffer: buffer(pts: 1, size: 500)) == kCMBufferQueueError_InvalidBuffer, "the validation handler rejects a buffer")

    // the iOS 13 Swift API, with the sample-buffer handlers
    do {
        let sq = try CMBufferQueue(capacity: 2, handlers: .outputPTSSortedSampleBuffers)
        var resets = 0
        let token = try sq.installTrigger(condition: .whenReset) { _ in resets += 1 }
        for pts: Int64 in [3, 1] {
            var timing = CMSampleTimingInfo(duration: t(1, 30), presentationTimeStamp: t(pts, 30), decodeTimeStamp: .invalid)
            var sb: CMSampleBuffer?
            CMSampleBufferCreateReady(allocator: nil, dataBuffer: CMBlockBuffer(_bytes: [1, 2, 3]), formatDescription: nil, sampleCount: 1,
                                      sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sb)
            try sq.enqueue(sb!)
        }
        check((sq.head as? CMSampleBuffer)?.presentationTimeStamp == t(1, 30), "outputPTSSortedSampleBuffers: the earliest first")
        check(sq.duration == t(2, 30) && sq.totalSize == 6 && sq.bufferCount == 2, "sample-buffer handlers: duration and size")
        var full = false
        do { try sq.enqueue(sq.head!) } catch { full = (error as NSError).code == Int(kCMBufferQueueError_QueueIsFull) }
        check(full, "a queue with capacity 2 is full")
        var resetSeen = 0
        try sq.reset { _ in resetSeen += 1 }
        check(resetSeen == 2 && sq.isEmpty && resets == 1 && !sq.testTrigger(token), "reset(_:) hands back the buffers and fires whenReset")
        let h = CMBufferQueue.Handlers { b in b.getDuration { _ in t(2) } }.withHandlers { b in b.getSize { _ in 7 } }
        let hq = try CMBufferQueue(handlers: h)
        try hq.enqueue(buffer(pts: 0))
        check(hq.duration == t(2) && hq.totalSize == 7, "Handlers(withHandlers:) and withHandlers(_:)")
    } catch { check(false, "the Swift buffer queue API: \(error)") }
    check(CMBufferQueueGetTypeID() == CMBufferQueue.typeID && CFGetTypeID(q) == CMBufferQueueGetTypeID(), "CMBufferQueueGetTypeID and CFGetTypeID")
}

func sampleBufferCopies() {
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, 64, 48, kCVPixelFormatType_32BGRA, nil, &pb)
    var fd: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pb!, formatDescriptionOut: &fd)
    var timing = CMSampleTimingInfo(duration: t(1, 30), presentationTimeStamp: t(10, 30), decodeTimeStamp: .invalid)
    var sb: CMSampleBuffer?
    CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pb!, formatDescription: fd!, sampleTiming: &timing, sampleBufferOut: &sb)
    CMSetAttachment(sb!, key: kCMSampleBufferAttachmentKey_ResetDecoderBeforeDecoding, value: kCFBooleanTrue, attachmentMode: kCMAttachmentMode_ShouldPropagate)
    var copy: CMSampleBuffer?
    check(CMSampleBufferCreateCopy(allocator: nil, sampleBuffer: sb!, sampleBufferOut: &copy) == noErr && copy !== sb, "CMSampleBufferCreateCopy: a new buffer")
    check(copy?.imageBuffer === pb && copy?.presentationTimeStamp == t(10, 30), "the copy shares the image buffer and timing")
    check(CMGetAttachment(copy!, key: kCMSampleBufferAttachmentKey_ResetDecoderBeforeDecoding, attachmentModeOut: nil) != nil, "the copy has the attachments")
    CMRemoveAttachment(copy!, key: kCMSampleBufferAttachmentKey_ResetDecoderBeforeDecoding)
    check(CMGetAttachment(sb!, key: kCMSampleBufferAttachmentKey_ResetDecoderBeforeDecoding, attachmentModeOut: nil) != nil, "copies of the attachments, not the same dictionary")
    var newTiming = CMSampleTimingInfo(duration: t(2, 30), presentationTimeStamp: t(99, 30), decodeTimeStamp: .invalid)
    var retimed: CMSampleBuffer?
    check(CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sb!, sampleTimingEntryCount: 1, sampleTimingArray: &newTiming, sampleBufferOut: &retimed) == noErr &&
          retimed?.presentationTimeStamp == t(99, 30) && retimed?.duration == t(2, 30) && sb!.presentationTimeStamp == t(10, 30), "CMSampleBufferCreateCopyWithNewTiming")

    // compressed samples: one timing entry per sample
    var timings = (0..<3).map { CMSampleTimingInfo(duration: t(1, 30), presentationTimeStamp: t(Int64($0), 30), decodeTimeStamp: t(Int64($0), 30)) }
    var sizes = [2, 2, 2]
    var c: CMSampleBuffer?
    CMSampleBufferCreateReady(allocator: nil, dataBuffer: CMBlockBuffer(_bytes: [0, 1, 2, 3, 4, 5]), formatDescription: nil, sampleCount: 3,
                              sampleTimingEntryCount: 3, sampleTimingArray: &timings, sampleSizeEntryCount: 3, sampleSizeArray: &sizes, sampleBufferOut: &c)
    var shifted = timings.map { CMSampleTimingInfo(duration: $0.duration, presentationTimeStamp: $0.presentationTimeStamp + t(1), decodeTimeStamp: $0.decodeTimeStamp + t(1)) }
    var c2: CMSampleBuffer?
    _ = CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: c!, sampleTimingEntryCount: 3, sampleTimingArray: &shifted, sampleBufferOut: &c2)
    check(c2?.presentationTimeStamp == t(30, 30) && c2?.numSamples == 3 && c2?.sampleSize(at: 2) == 2 && (try? c2?.sampleTimingInfos())??.last?.presentationTimeStamp == t(32, 30),
          "a retimed copy of three compressed samples")
    check(CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: c!, sampleTimingEntryCount: 2, sampleTimingArray: &shifted, sampleBufferOut: &c2) ==
          kCMSampleBufferError_InvalidEntryCount, "two timing entries for three samples: kCMSampleBufferError_InvalidEntryCount")
}

func videoFormats() {
    let ext: [String: Any] = [
        kCMFormatDescriptionExtension_CleanAperture as String: [kCMFormatDescriptionKey_CleanApertureWidth as String: 1440, kCMFormatDescriptionKey_CleanApertureHeight as String: 1080,
                                                                kCMFormatDescriptionKey_CleanApertureHorizontalOffset as String: 0, kCMFormatDescriptionKey_CleanApertureVerticalOffset as String: 0],
        kCMFormatDescriptionExtension_PixelAspectRatio as String: [kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing as String: 4,
                                                                   kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing as String: 3],
        kCMFormatDescriptionExtension_FormatName as String: "H.264",
        kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String: ["avcC": Data([1, 0x64, 0, 0x1f, 0xff, 0xe0, 0])]]
    var fd: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreate(allocator: nil, codecType: kCMVideoCodecType_H264, width: 1600, height: 1080, extensions: ext as CFDictionary, formatDescriptionOut: &fd)
    let f = fd!
    check(CMVideoFormatDescriptionGetCleanAperture(f, originIsAtTopLeft: true) == CGRect(x: 80, y: 0, width: 1440, height: 1080), "CMVideoFormatDescriptionGetCleanAperture: centred")
    check(CMVideoFormatDescriptionGetPresentationDimensions(f, usePixelAspectRatio: false, useCleanAperture: false) == CGSize(width: 1600, height: 1080),
          "presentation dimensions: the coded size")
    check(CMVideoFormatDescriptionGetPresentationDimensions(f, usePixelAspectRatio: true, useCleanAperture: true) == CGSize(width: 1920, height: 1080),
          "presentation dimensions: clean aperture and 4:3 pixels -> 1920x1080")
    check(f.presentationDimensions() == CGSize(width: 1920, height: 1080) && f.cleanAperture(originIsAtTopLeft: false).width == 1440, "the CMFormatDescription methods")
    check((CMVideoFormatDescriptionGetExtensionKeysCommonWithImageBuffers() as NSArray).contains(kCMFormatDescriptionExtension_CleanAperture as String),
          "the extension keys common with image buffers")

    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, 32, 16, kCVPixelFormatType_32BGRA, nil, &pb)
    var pfd: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pb!, formatDescriptionOut: &pfd)
    check(CMVideoFormatDescriptionMatchesImageBuffer(pfd!, imageBuffer: pb!), "a format made from an image buffer matches it")
    CVBufferSetAttachment(pb!, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
    check(!pfd!.matchesImageBuffer(pb!), "a different attachment: no match")
    var other: CVPixelBuffer?
    CVPixelBufferCreate(nil, 33, 16, kCVPixelFormatType_32BGRA, nil, &other)
    check(!CMVideoFormatDescriptionMatchesImageBuffer(pfd!, imageBuffer: other!), "a different size: no match")

    var block: CMBlockBuffer?
    check(CMVideoFormatDescriptionCopyAsBigEndianImageDescriptionBlockBuffer(allocator: nil, videoFormatDescription: f, stringEncoding: CFStringBuiltInEncodings.UTF8.rawValue,
                                                                             flavor: .isoFamily, blockBufferOut: &block) == noErr, "CopyAsBigEndianImageDescriptionBlockBuffer")
    let bytes = block!._bytes
    let size = bytes[0..<4].reduce(0) { $0 << 8 | Int($1) }
    check(size == bytes.count && bytes.count > 86 && Array(bytes[4..<8]) == Array("avc1".utf8) && bytes[32] == 0x06 && bytes[33] == 0x40, "the image description: size, 'avc1', width 1600")
    var back: CMVideoFormatDescription?
    check(CMVideoFormatDescriptionCreateFromBigEndianImageDescriptionBlockBuffer(allocator: nil, bigEndianImageDescriptionBlockBuffer: block!,
                                                                                 stringEncoding: CFStringBuiltInEncodings.UTF8.rawValue, flavor: .isoFamily,
                                                                                 formatDescriptionOut: &back) == noErr, "CreateFromBigEndianImageDescriptionBlockBuffer")
    if let b = back {
        check(b.mediaSubType == kCMVideoCodecType_H264 && b.dimensions == CMVideoDimensions(width: 1600, height: 1080), "parsed back: codec and size")
        check(b._atom("avcC") == [1, 0x64, 0, 0x1f, 0xff, 0xe0, 0], "parsed back: the avcC atom")
        check(b.presentationDimensions() == CGSize(width: 1920, height: 1080), "parsed back: pasp and clap")
        check((CMFormatDescriptionGetExtension(b, extensionKey: kCMFormatDescriptionExtension_FormatName) as? String) == "H.264", "parsed back: the format name")
    }
    var swapped = bytes
    check(CMSwapBigEndianImageDescriptionToHost(&swapped, swapped.count) == noErr && swapped[32] == 0x40 && swapped[33] == 0x06 &&
          CMSwapHostEndianImageDescriptionToBig(&swapped, swapped.count) == noErr && swapped == bytes, "CMSwap...ImageDescription round trip")
    var bad: CMVideoFormatDescription?
    check(CMVideoFormatDescriptionCreateFromBigEndianImageDescriptionData(allocator: nil, bigEndianImageDescriptionData: bytes, size: 20, stringEncoding: 0,
                                                                         flavor: nil, formatDescriptionOut: &bad) == kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription,
          "a truncated image description is rejected")
    check(CMImageDescriptionFlavor(rawValue: "ISOFamily" as CFString) == .isoFamily, "CMImageDescriptionFlavor")
}

@main
struct CoreMediaTest {
    static func main() {
        timeRanges()
        simpleQueues()
        bufferQueues()
        sampleBufferCopies()
        videoFormats()
        print("coremedia: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
