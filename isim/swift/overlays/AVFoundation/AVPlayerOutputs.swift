// isim AVFoundation: media selection and player item outputs. Self-authored, iOS API names.
// - Media selection groups come from the asset's streams (the host's ffprobe): an audible group when it has two or
//   more audio streams, a legible group when it has subtitle streams (mov_text / tx3g, WebVTT, SRT, SSA). Choosing an
//   audio option plays that soundtrack; choosing a subtitle option feeds AVPlayerItemLegibleOutput and draws the
//   subtitles in AVPlayerLayer (adapted: one style, white text on a translucent box, like iOS's default).
// - AVPlayerItemVideoOutput hands out the frames the player decodes (BGRA, at most 960 points on a side).
// - AVPlayerItemLegibleOutput delivers subtitle cues (ffmpeg converts the stream to WebVTT; text without styling).
// - AVPlayerItemMetadataOutput delivers timed ID3 metadata of MPEG-TS files (HLS segments), read by isim's own TS
//   reader, as playback passes it.
// - The access and error logs record isim's own playback of the item (file and progressive URLs; no HLS variants).
import UIKit
import isim_host

// MARK: - characteristics

extension AVMediaCharacteristic {
    public static let containsOnlyForcedSubtitles = AVMediaCharacteristic(rawValue: "AVMediaCharacteristicContainsOnlyForcedSubtitles")
    public static let transcribesSpokenDialogForAccessibility = AVMediaCharacteristic(rawValue: "public.accessibility.transcribes-spoken-dialog")
    public static let describesMusicAndSoundForAccessibility = AVMediaCharacteristic(rawValue: "public.accessibility.describes-music-and-sound")
    public static let describesVideoForAccessibility = AVMediaCharacteristic(rawValue: "public.accessibility.describes-video")
    public static let easyToRead = AVMediaCharacteristic(rawValue: "public.easy-to-read")
    public static let isMainProgramContent = AVMediaCharacteristic(rawValue: "public.main-program-content")
    public static let isAuxiliaryContent = AVMediaCharacteristic(rawValue: "public.auxiliary-content")
    public static let isOriginalContent = AVMediaCharacteristic(rawValue: "public.original-content")
    public static let languageTranslation = AVMediaCharacteristic(rawValue: "public.translation")
    public static let dubbedTranslation = AVMediaCharacteristic(rawValue: "public.translation.dubbed")
    public static let voiceOverTranslation = AVMediaCharacteristic(rawValue: "public.translation.voice-over")
    public static let frameBased = AVMediaCharacteristic(rawValue: "AVMediaCharacteristicFrameBased")
    public static let usesWideGamutColorSpace = AVMediaCharacteristic(rawValue: "AVMediaCharacteristicUsesWideGamutColorSpace")
    public static let containsHDRVideo = AVMediaCharacteristic(rawValue: "AVMediaCharacteristicContainsHDRVideo")
    public static let containsAlphaChannel = AVMediaCharacteristic(rawValue: "AVMediaCharacteristicContainsAlphaChannel")
}

// MARK: - streams

/// isim: one stream of a media file, from the host's ffprobe
struct _AVStream: Sendable {
    var index = 0, typeIndex = 0
    var type = "", codec = ""
    var language: String?, title: String?
    var isDefault = false, forced = false
    static func list(_ url: URL) -> [_AVStream] {
        var out: UnsafeMutablePointer<CChar>? = nil
        var len = 0
        let path = url.isFileURL ? url.path : url.absoluteString
        guard isim_media_streams(path, &out, &len) != 0, let p = out else { return [] }
        defer { isim_media_free(p) }
        var streams: [_AVStream] = [], counts: [String: Int] = [:]
        for line in String(cString: p).split(separator: "\n") {
            var s = _AVStream()
            for field in line.split(separator: "|") {
                let kv = field.split(separator: "=", maxSplits: 1).map(String.init)
                guard kv.count == 2 else { continue }
                switch kv[0] {
                case "index": s.index = Int(kv[1]) ?? 0
                case "codec_type": s.type = kv[1]
                case "codec_name": s.codec = kv[1]
                case "disposition:default": s.isDefault = kv[1] == "1"
                case "disposition:forced": s.forced = kv[1] == "1"
                case "tag:language": s.language = kv[1] == "und" ? nil : kv[1]
                case "tag:title": s.title = kv[1]
                default: break
                }
            }
            s.typeIndex = counts[s.type, default: 0]
            counts[s.type] = s.typeIndex + 1
            streams.append(s)
        }
        return streams
    }
    /// ISO 639-2 (three letters, as in MP4 and Matroska) to the two-letter code of a locale identifier
    var localeIdentifier: String? {
        guard let l = language else { return nil }
        let map = ["eng": "en", "fra": "fr", "fre": "fr", "spa": "es", "deu": "de", "ger": "de", "ita": "it", "por": "pt", "jpn": "ja",
                   "zho": "zh", "chi": "zh", "kor": "ko", "rus": "ru", "nld": "nl", "dut": "nl", "swe": "sv", "nor": "nb", "dan": "da",
                   "fin": "fi", "pol": "pl", "tur": "tr", "ara": "ar", "heb": "he", "hin": "hi", "ell": "el", "gre": "el", "ces": "cs",
                   "cze": "cs", "hun": "hu", "ukr": "uk", "tha": "th", "vie": "vi", "ind": "id", "cat": "ca", "ron": "ro", "rum": "ro"]
        return map[l] ?? l
    }
}

// MARK: - media selection

open class AVMediaSelectionOption: NSObject, NSCopying, @unchecked Sendable {
    let _stream: _AVStream
    weak var _group: AVMediaSelectionGroup?
    init(_ s: _AVStream) { _stream = s }
    open var mediaType: AVMediaType { _stream.type == "audio" ? .audio : .subtitle }
    /// the codec's four-character code (mp4a, ac-3, tx3g, wvtt, ...)
    open var mediaSubTypes: [NSNumber] {
        let codes = ["aac": "mp4a", "ac3": "ac-3", "eac3": "ec-3", "mp3": ".mp3", "opus": "opus", "flac": "fLaC", "alac": "alac",
                     "mov_text": "tx3g", "webvtt": "wvtt", "subrip": "text", "ass": "ssa ", "ssa": "ssa ", "eia_608": "c608"]
        let s = codes[_stream.codec] ?? String((_stream.codec + "    ").prefix(4))
        let v = s.utf8.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        return [NSNumber(value: v)]
    }
    open var isPlayable: Bool { true }
    open var extendedLanguageTag: String? { _stream.localeIdentifier }
    open var locale: Locale? { _stream.localeIdentifier.map { Locale(identifier: $0) } }
    open var displayName: String { displayName(with: Locale.current) }
    open func displayName(with locale: Locale) -> String {
        let language = _stream.localeIdentifier.flatMap { locale.localizedString(forLanguageCode: $0) }
        var name = language ?? _stream.title ?? (mediaType == .audio ? "Unknown" : "Unknown")
        if hasMediaCharacteristic(.containsOnlyForcedSubtitles) { name += " Forced" }
        return name
    }
    open func hasMediaCharacteristic(_ c: AVMediaCharacteristic) -> Bool {
        switch c {
        case .audible: return _stream.type == "audio"
        case .legible: return _stream.type == "subtitle"
        case .containsOnlyForcedSubtitles: return _stream.type == "subtitle" && _stream.forced
        case .isMainProgramContent: return _stream.isDefault || !_stream.forced
        default: return false
        }
    }
    /// the stream's title as common metadata
    open var commonMetadata: [AVMetadataItem] {
        guard let t = _stream.title else { return [] }
        let item = AVMutableMetadataItem()
        item.identifier = .commonIdentifierTitle
        item.value = t as NSString
        return [item]
    }
    open var availableMetadataFormats: [String] { [] }
    open func metadata(forFormat format: String) -> [AVMetadataItem] { [] }
    open func associatedMediaSelectionOption(in mediaSelectionGroup: AVMediaSelectionGroup) -> AVMediaSelectionOption? { nil }
    open func propertyList() -> Any { ["isimStream": _stream.index] }
    open func copy(with zone: NSZone? = nil) -> Any { self }
    open override func isEqual(_ object: Any?) -> Bool { (object as? AVMediaSelectionOption)?._stream.index == _stream.index }
    open override var hash: Int { _stream.index }
    open override var description: String { "<AVMediaSelectionOption \(mediaType.rawValue) \(displayName)>" }
}

open class AVMediaSelectionGroup: NSObject, NSCopying, @unchecked Sendable {
    public let options: [AVMediaSelectionOption]
    let _characteristic: AVMediaCharacteristic
    init(_ c: AVMediaCharacteristic, _ options: [AVMediaSelectionOption]) {
        _characteristic = c; self.options = options
        super.init()
        for o in options { o._group = self }
    }
    /// the stream marked default; the first audio option (audio always plays); none for subtitles
    open var defaultOption: AVMediaSelectionOption? {
        options.first { $0._stream.isDefault && ($0._stream.type == "audio" || $0._stream.forced) } ?? (_characteristic == .audible ? options.first : nil)
    }
    open var allowsEmptySelection: Bool { _characteristic == .legible }
    open func mediaSelectionOption(withPropertyList plist: Any) -> AVMediaSelectionOption? {
        guard let i = (plist as? [String: Any])?["isimStream"] as? Int else { return nil }
        return options.first { $0._stream.index == i }
    }
    open func copy(with zone: NSZone? = nil) -> Any { self }
    open class func playableMediaSelectionOptions(from options: [AVMediaSelectionOption]) -> [AVMediaSelectionOption] { options.filter(\.isPlayable) }
    open class func mediaSelectionOptions(from options: [AVMediaSelectionOption], filteredAndSortedAccordingToPreferredLanguages languages: [String]) -> [AVMediaSelectionOption] {
        var out: [AVMediaSelectionOption] = []
        for l in languages {
            let code = Locale(identifier: l).language.languageCode?.identifier ?? l
            for o in options where o.extendedLanguageTag == code && !out.contains(o) { out.append(o) }
        }
        return out
    }
    open class func mediaSelectionOptions(from options: [AVMediaSelectionOption], with locale: Locale) -> [AVMediaSelectionOption] {
        let code = locale.language.languageCode?.identifier
        return options.filter { $0.extendedLanguageTag == code }
    }
    open class func mediaSelectionOptions(from options: [AVMediaSelectionOption], withMediaCharacteristics c: [AVMediaCharacteristic]) -> [AVMediaSelectionOption] {
        options.filter { o in c.allSatisfy { o.hasMediaCharacteristic($0) } }
    }
    open class func mediaSelectionOptions(from options: [AVMediaSelectionOption], withoutMediaCharacteristics c: [AVMediaCharacteristic]) -> [AVMediaSelectionOption] {
        options.filter { o in !c.contains { o.hasMediaCharacteristic($0) } }
    }
}

/// The options chosen in each group of an asset.
open class AVMediaSelection: NSObject, NSCopying, NSMutableCopying, @unchecked Sendable {
    open var asset: AVAsset? { _asset }
    weak var _asset: AVAsset?
    var _chosen: [String: AVMediaSelectionOption?] = [:]          // by characteristic; nil value: none (explicit)
    init(asset: AVAsset?) { _asset = asset }
    open func selectedMediaOption(in group: AVMediaSelectionGroup) -> AVMediaSelectionOption? {
        if let c = _chosen[group._characteristic.rawValue] { return c }
        return group.defaultOption
    }
    open func mediaSelectionCriteriaCanBeAppliedAutomatically(to group: AVMediaSelectionGroup) -> Bool { _chosen[group._characteristic.rawValue] == nil }
    open func copy(with zone: NSZone? = nil) -> Any { let c = AVMediaSelection(asset: _asset); c._chosen = _chosen; return c }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { let c = AVMutableMediaSelection(asset: _asset); c._chosen = _chosen; return c }
}
open class AVMutableMediaSelection: AVMediaSelection, @unchecked Sendable {
    open func select(_ option: AVMediaSelectionOption?, in group: AVMediaSelectionGroup) { _chosen[group._characteristic.rawValue] = .some(option) }
}

extension AVAsset {
    var _mediaStreams: [_AVStream] {
        if let s = _streamCache { return s }
        let s = _url.map { _AVStream.list($0) } ?? []
        _streamCache = s
        return s
    }
    /// .audible when the asset has two or more audio streams, .legible when it has subtitles
    public var availableMediaCharacteristicsWithMediaSelectionOptions: [AVMediaCharacteristic] {
        var c: [AVMediaCharacteristic] = []
        if mediaSelectionGroup(forMediaCharacteristic: .audible) != nil { c.append(.audible) }
        if mediaSelectionGroup(forMediaCharacteristic: .legible) != nil { c.append(.legible) }
        return c
    }
    public func mediaSelectionGroup(forMediaCharacteristic c: AVMediaCharacteristic) -> AVMediaSelectionGroup? {
        if let g = _groupCache[c.rawValue] { return g }
        let streams = _mediaStreams
        let g: AVMediaSelectionGroup?
        switch c {
        case .audible:
            let a = streams.filter { $0.type == "audio" }
            g = a.count >= 2 ? AVMediaSelectionGroup(.audible, a.map(AVMediaSelectionOption.init)) : nil
        case .legible:
            let s = streams.filter { $0.type == "subtitle" }
            g = s.isEmpty ? nil : AVMediaSelectionGroup(.legible, s.map(AVMediaSelectionOption.init))
        default: g = nil
        }
        _groupCache[c.rawValue] = g
        return g
    }
    public var preferredMediaSelection: AVMediaSelection { AVMediaSelection(asset: self) }
    public var allMediaSelections: [AVMediaSelection] {
        let groups = availableMediaCharacteristicsWithMediaSelectionOptions.compactMap { mediaSelectionGroup(forMediaCharacteristic: $0) }
        // each combination of one option per group
        var combos: [[String: AVMediaSelectionOption?]] = [[:]]
        for g in groups {
            let choices: [AVMediaSelectionOption?] = (g.allowsEmptySelection ? [nil] : []) + g.options.map { Optional($0) }
            combos = combos.flatMap { c in choices.map { o in var n = c; n[g._characteristic.rawValue] = .some(o); return n } }
        }
        return combos.map { c in let s = AVMediaSelection(asset: self); s._chosen = c; return s }
    }
    public func loadMediaSelectionGroup(for mediaCharacteristic: AVMediaCharacteristic,
                                      completionHandler: @escaping @Sendable (AVMediaSelectionGroup?, Error?) -> Void) {
        DispatchQueue.global().async { completionHandler(self.mediaSelectionGroup(forMediaCharacteristic: mediaCharacteristic), nil) }
    }
    public func loadMediaSelectionGroup(for mediaCharacteristic: AVMediaCharacteristic) async throws -> AVMediaSelectionGroup? {
        await withCheckedContinuation { k in
            DispatchQueue.global().async { k.resume(returning: self.mediaSelectionGroup(forMediaCharacteristic: mediaCharacteristic)) }
        }
    }
}

extension AVPlayerItem {
    public var currentMediaSelection: AVMediaSelection { let s = AVMediaSelection(asset: asset); s._chosen = _chosen; return s }
    public func select(_ option: AVMediaSelectionOption?, in group: AVMediaSelectionGroup) {
        if let option, !group.options.contains(option) { return }
        let before = _audioIndex
        _chosen[group._characteristic.rawValue] = .some(option)
        if group._characteristic == .legible { _loadCues() }
        if _audioIndex != before, let p = _player, p.currentItem === self, status == .readyToPlay { p._openMedia(at: p._now()) }
        NotificationCenter.default.post(name: AVPlayerItem.mediaSelectionDidChangeNotification, object: self)
    }
    public func selectMediaOptionAutomatically(in group: AVMediaSelectionGroup) {
        _chosen[group._characteristic.rawValue] = nil
        let preferred = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, filteredAndSortedAccordingToPreferredLanguages: Locale.preferredLanguages)
        if group._characteristic == .audible, let o = preferred.first { _chosen[group._characteristic.rawValue] = .some(o) }
        if group._characteristic == .legible {
            // automatic subtitles: only forced ones in the preferred language, as with the default accessibility settings
            let forced = group.options.filter { $0._stream.forced }
            if let o = AVMediaSelectionGroup.mediaSelectionOptions(from: forced, filteredAndSortedAccordingToPreferredLanguages: Locale.preferredLanguages).first {
                _chosen[group._characteristic.rawValue] = .some(o)
            }
            _loadCues()
        }
        if let p = _player, p.currentItem === self, status == .readyToPlay { p._openMedia(at: p._now()) }
    }
    public static let mediaSelectionDidChangeNotification = Notification.Name("AVPlayerItemMediaSelectionDidChangeNotification")
    /// the audio stream to play (0-based among audio streams; -1: the default one)
    var _audioIndex: Int32 {
        guard let g = asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
              let o = currentMediaSelection.selectedMediaOption(in: g) else { return -1 }
        return Int32(o._stream.typeIndex)
    }
    var _legibleOption: AVMediaSelectionOption? {
        guard let g = asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return nil }
        return currentMediaSelection.selectedMediaOption(in: g)
    }
    func _loadCues() {
        guard let o = _legibleOption, let url = asset._url else { _cues = []; _player?._layersChanged(); return }
        let index = Int32(o._stream.typeIndex)
        let path = url.isFileURL ? url.path : url.absoluteString
        DispatchQueue.global().async { [weak self] in
            let cues = _AVCue.load(path, index)
            DispatchQueue.main.async {
                guard let self, self._legibleOption === o else { return }
                self._cues = cues
                for case let out as AVPlayerItemLegibleOutput in self._outputs { out._last = nil }
                self._player?._layersChanged()
            }
        }
    }
    /// the subtitle cues showing at `t`
    func _activeCues(_ t: Double) -> [_AVCue] { _cues.filter { $0.start <= t && t < $0.end } }

    // outputs
    public var outputs: [AVPlayerItemOutput] { _outputs }
    public func add(_ output: AVPlayerItemOutput) {
        guard !_outputs.contains(where: { $0 === output }) else { return }
        _outputs.append(output); output._item = self
        if output is AVPlayerItemMetadataOutput { _loadTimedMetadata() }
        _player?._layersChanged()
    }
    public func remove(_ output: AVPlayerItemOutput) {
        _outputs.removeAll { $0 === output }
        if output._item === self { output._item = nil }
        _player?._layersChanged()
    }
    var _suppressesPlayerRendering: Bool { _outputs.contains { $0.suppressesPlayerRendering } }
    /// called by the player each display frame while it plays, and after seeks
    func _outputsTick(_ t: Double, flushed: Bool) {
        for o in _outputs { o._tick(t, flushed: flushed) }
    }
    func _loadTimedMetadata() {
        guard _timedMetadata == nil, let url = asset._url, url.isFileURL else { return }
        _timedMetadata = []
        DispatchQueue.global().async { [weak self] in
            let groups = _ID3Reader.groups(url)
            DispatchQueue.main.async { self?._timedMetadata = groups }
        }
    }
}

// MARK: - subtitle cues

struct _AVCue: Sendable, Equatable {
    var start: Double, end: Double, text: String
    static func load(_ path: String, _ index: Int32) -> [_AVCue] {
        var out: UnsafeMutablePointer<CChar>? = nil
        var len = 0
        guard isim_media_subtitles(path, index, &out, &len) != 0, let p = out else { return [] }
        defer { isim_media_free(p) }
        return parseWebVTT(String(cString: p))
    }
    static func seconds(_ s: Substring) -> Double? {
        let parts = s.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard let last = parts.last, let sec = Double(last.replacingOccurrences(of: ",", with: ".")) else { return nil }
        var t = sec, mul = 60.0
        for p in parts.dropLast().reversed() { t += (Double(p) ?? 0) * mul; mul *= 60 }
        return t
    }
    /// WebVTT cues (timing line "a --> b settings", then text lines); tags such as <i> are removed
    static func parseWebVTT(_ text: String) -> [_AVCue] {
        var cues: [_AVCue] = []
        let blocks = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n\n")
        for b in blocks {
            let lines = b.split(separator: "\n", omittingEmptySubsequences: false)
            guard let i = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let timing = lines[i].components(separatedBy: "-->")
            guard timing.count == 2, let a = seconds(Substring(timing[0])),
                  let e = seconds(Substring(timing[1].split(separator: " ", omittingEmptySubsequences: true).first ?? "")) else { continue }
            var body = lines[(i + 1)...].joined(separator: "\n")
            while let r = body.range(of: "<[^>]*>", options: .regularExpression) { body.removeSubrange(r) }
            body = body.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&nbsp;", with: "\u{A0}")
            body = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty { cues.append(_AVCue(start: a, end: e, text: body)) }
        }
        return cues
    }
}

// MARK: - outputs

/// A source of an item's media data while it plays.
@objc(AVPlayerItemOutput) open class AVPlayerItemOutput: NSObject, @unchecked Sendable {
    weak var _item: AVPlayerItem?
    public override init() { super.init() }
    /// rendering through AVPlayerLayer stops while this output is attached (the app draws the frames itself)
    open var suppressesPlayerRendering = false
    /// host times are nanoseconds of the uptime clock (CACurrentMediaTime × 10⁹ on isim)
    open func itemTime(forHostTime hostTimeInSeconds: CFTimeInterval) -> CMTime {
        guard let item = _item else { return .invalid }
        let now = isim_time()
        let rate = Double(item._player?.currentItem === item ? item._player!.rate : 0)
        return CMTime(seconds: max(0, item.currentTime().seconds + (hostTimeInSeconds - now) * rate), preferredTimescale: 600)
    }
    open func itemTime(forMachAbsoluteTime machAbsoluteTime: Int64) -> CMTime { itemTime(forHostTime: Double(machAbsoluteTime) / 1e9) }
    func _tick(_ t: Double, flushed: Bool) {}
}

// The delegate protocols are Swift protocols with default (empty) implementations, which stand in for Objective-C's
// optional methods: their methods take CMTime, a Swift struct in isim.
/// isim: what the pull and push delegates share (one requirement, so a class can adopt both)
public protocol _AVPlayerItemOutputDelegate: NSObjectProtocol {
    func outputSequenceWasFlushed(_ output: AVPlayerItemOutput)
}
extension _AVPlayerItemOutputDelegate {
    public func outputSequenceWasFlushed(_ output: AVPlayerItemOutput) {}
}
public protocol AVPlayerItemOutputPullDelegate: _AVPlayerItemOutputDelegate {
    func outputMediaDataWillChange(_ sender: AVPlayerItemOutput)
}
extension AVPlayerItemOutputPullDelegate {
    public func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {}
}
public protocol AVPlayerItemOutputPushDelegate: _AVPlayerItemOutputDelegate {}

/// The decoded video frames, as BGRA pixel buffers the app pulls at the times it draws.
@objc(AVPlayerItemVideoOutput) open class AVPlayerItemVideoOutput: AVPlayerItemOutput, @unchecked Sendable {
    let _attributes: [String: Any]?
    public init(pixelBufferAttributes: [String: Any]?) { _attributes = pixelBufferAttributes; super.init() }
    public convenience init(outputSettings: [String: Any]?) { self.init(pixelBufferAttributes: outputSettings) }
    public convenience override init() { self.init(pixelBufferAttributes: nil) }
    open private(set) weak var delegate: AVPlayerItemOutputPullDelegate?
    open private(set) var delegateQueue: DispatchQueue?
    open func setDelegate(_ delegate: AVPlayerItemOutputPullDelegate?, queue delegateQueue: DispatchQueue?) {
        self.delegate = delegate; self.delegateQueue = delegateQueue
    }
    var _copiedPTS = -1.0
    var _wantsNotification = false
    open func requestNotificationOfMediaDataChange(withAdvanceInterval interval: TimeInterval) { _wantsNotification = true }
    var _session: Int32 { _item.flatMap { item in item._player?.currentItem === item ? item._player?._media : nil } ?? 0 }
    open func hasNewPixelBuffer(forItemTime itemTime: CMTime) -> Bool {
        var pts = 0.0
        guard _session != 0, isim_media_frame_pixels(_session, nil, 0, nil, nil, &pts) != 0 else { return false }
        return pts != _copiedPTS
    }
    open func copyPixelBuffer(forItemTime itemTime: CMTime, itemTimeForDisplay outItemTimeForDisplay: UnsafeMutablePointer<CMTime>?) -> CVPixelBuffer? {
        var w: Int32 = 0, h: Int32 = 0, pts = 0.0
        let session = _session
        guard session != 0, isim_media_frame_pixels(session, nil, 0, &w, &h, &pts) != 0, w > 0, h > 0 else { return nil }
        var pb: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, Int(w), Int(h), kCVPixelFormatType_32BGRA, nil, &pb) == kCVReturnSuccess, let pb else { return nil }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        let rowBytes = CVPixelBufferGetBytesPerRow(pb), base = CVPixelBufferGetBaseAddress(pb)!
        if rowBytes == Int(w) * 4 {
            _ = isim_media_frame_pixels(session, base, rowBytes * Int(h), nil, nil, &pts)
        } else {
            var tmp = [UInt8](repeating: 0, count: Int(w) * Int(h) * 4)
            _ = isim_media_frame_pixels(session, &tmp, tmp.count, nil, nil, &pts)
            tmp.withUnsafeBytes { src in for y in 0..<Int(h) { (base + y * rowBytes).copyMemory(from: src.baseAddress! + y * Int(w) * 4, byteCount: Int(w) * 4) } }
        }
        _copiedPTS = pts
        outItemTimeForDisplay?.pointee = CMTime(seconds: pts, preferredTimescale: 600)
        return pb
    }
    override func _tick(_ t: Double, flushed: Bool) {
        if flushed {
            _copiedPTS = -1
            if let d = delegate { _call { d.outputSequenceWasFlushed(self) } }
        }
        if _wantsNotification, hasNewPixelBuffer(forItemTime: .zero), let d = delegate {
            _wantsNotification = false
            _call { d.outputMediaDataWillChange(self) }
        }
    }
    func _call(_ f: @escaping () -> Void) { if let q = delegateQueue, q !== DispatchQueue.main { q.async(execute: f) } else { f() } }
}

public struct AVPlayerItemLegibleOutput_TextStylingResolution: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}
public protocol AVPlayerItemLegibleOutputPushDelegate: AVPlayerItemOutputPushDelegate {
    func legibleOutput(_ output: AVPlayerItemLegibleOutput, didOutputAttributedStrings strings: [NSAttributedString],
                       nativeSampleBuffers nativeSamples: [Any], forItemTime itemTime: CMTime)
}
extension AVPlayerItemLegibleOutputPushDelegate {
    public func legibleOutput(_ output: AVPlayerItemLegibleOutput, didOutputAttributedStrings strings: [NSAttributedString],
                              nativeSampleBuffers nativeSamples: [Any], forItemTime itemTime: CMTime) {}
}

/// The text of the selected subtitles, pushed to the delegate as cues start and end.
@objc(AVPlayerItemLegibleOutput) open class AVPlayerItemLegibleOutput: AVPlayerItemOutput, @unchecked Sendable {
    public struct TextStylingResolution: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let `default` = TextStylingResolution(rawValue: "AVPlayerItemLegibleOutputTextStylingResolutionDefault")
        public static let sourceAndRulesOnly = TextStylingResolution(rawValue: "AVPlayerItemLegibleOutputTextStylingResolutionSourceAndRulesOnly")
    }
    public override init() { _nativeSubtypes = []; super.init() }
    /// subtitles of these types would be delivered as native sample buffers; isim delivers text for every type
    public init(mediaSubtypesForNativeRepresentation subtypes: [NSNumber]) { _nativeSubtypes = subtypes; super.init() }
    let _nativeSubtypes: [NSNumber]
    open private(set) weak var delegate: AVPlayerItemLegibleOutputPushDelegate?
    open private(set) var delegateQueue: DispatchQueue?
    open func setDelegate(_ delegate: AVPlayerItemLegibleOutputPushDelegate?, queue delegateQueue: DispatchQueue?) {
        self.delegate = delegate; self.delegateQueue = delegateQueue
    }
    /// deliver this many seconds before the text shows
    open var advanceIntervalForDelegateInvocation: TimeInterval = 0
    open var textStylingResolution: TextStylingResolution = .default
    var _last: [_AVCue]?
    override func _tick(_ t: Double, flushed: Bool) {
        guard let item = _item else { return }
        if flushed, let d = delegate { _call { d.outputSequenceWasFlushed(self) }; _last = nil }
        let at = t + advanceIntervalForDelegateInvocation
        let now = item._activeCues(at)
        guard now != _last else { return }
        let first = _last == nil
        _last = now
        if first && now.isEmpty { return }
        let strings = now.map { NSAttributedString(string: $0.text) }
        let time = CMTime(seconds: now.first?.start ?? at, preferredTimescale: 600)
        guard let d = delegate else { return }
        _call { d.legibleOutput(self, didOutputAttributedStrings: strings, nativeSampleBuffers: [], forItemTime: time) }
    }
    func _call(_ f: @escaping () -> Void) { if let q = delegateQueue, q !== DispatchQueue.main { q.async(execute: f) } else { f() } }
}

// MARK: - timed metadata

open class AVTimedMetadataGroup: NSObject, NSCopying, NSMutableCopying, @unchecked Sendable {
    var _items: [AVMetadataItem]
    var _timeRange: CMTimeRange
    public init(items: [AVMetadataItem], timeRange: CMTimeRange) { _items = items; _timeRange = timeRange }
    open var items: [AVMetadataItem] { _items }
    open var timeRange: CMTimeRange { _timeRange }
    open func copy(with zone: NSZone? = nil) -> Any { AVTimedMetadataGroup(items: _items, timeRange: _timeRange) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { AVMutableTimedMetadataGroup(items: _items, timeRange: _timeRange) }
}
open class AVMutableTimedMetadataGroup: AVTimedMetadataGroup, @unchecked Sendable {
    open override var items: [AVMetadataItem] { get { _items } set { _items = newValue } }
    open override var timeRange: CMTimeRange { get { _timeRange } set { _timeRange = newValue } }
}

public protocol AVPlayerItemMetadataOutputPushDelegate: AVPlayerItemOutputPushDelegate {
    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], from track: AVPlayerItemTrack?)
}
extension AVPlayerItemMetadataOutputPushDelegate {
    public func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], from track: AVPlayerItemTrack?) {}
}

/// Timed metadata (ID3 in MPEG-TS) pushed to the delegate as playback reaches it.
@objc(AVPlayerItemMetadataOutput) open class AVPlayerItemMetadataOutput: AVPlayerItemOutput, @unchecked Sendable {
    let _identifiers: [String]?
    public init(identifiers: [String]?) { _identifiers = identifiers; super.init() }
    public convenience override init() { self.init(identifiers: nil) }
    open private(set) weak var delegate: AVPlayerItemMetadataOutputPushDelegate?
    open private(set) var delegateQueue: DispatchQueue?
    open func setDelegate(_ delegate: AVPlayerItemMetadataOutputPushDelegate?, queue delegateQueue: DispatchQueue?) {
        self.delegate = delegate; self.delegateQueue = delegateQueue
    }
    open var advanceIntervalForDelegateInvocation: TimeInterval = 0
    var _delivered = -1.0
    override func _tick(_ t: Double, flushed: Bool) {
        guard let item = _item, let all = item._timedMetadata else { return }
        if flushed { _delivered = t - 1e-6; if let d = delegate { _call { d.outputSequenceWasFlushed(self) } } }
        let at = t + advanceIntervalForDelegateInvocation
        let due = all.filter { $0.timeRange.start.seconds > _delivered && $0.timeRange.start.seconds <= at }
        guard !due.isEmpty else { return }
        _delivered = at
        let groups = due.compactMap { g -> AVTimedMetadataGroup? in
            guard let ids = _identifiers else { return g }
            let items = g.items.filter { $0.identifier.map { ids.contains($0.rawValue) } ?? false }
            return items.isEmpty ? nil : AVTimedMetadataGroup(items: items, timeRange: g.timeRange)
        }
        guard !groups.isEmpty, let d = delegate else { return }
        let track = item.tracks.first { $0.assetTrack?.mediaType == .metadata }
        _call { d.metadataOutput(self, didOutputTimedMetadataGroups: groups, from: track) }
    }
    func _call(_ f: @escaping () -> Void) { if let q = delegateQueue, q !== DispatchQueue.main { q.async(execute: f) } else { f() } }
}

/// isim: timed ID3 tags in an MPEG transport stream (the PMT's metadata streams, type 0x15 or a private stream with an
/// 'ID3 ' registration), with their presentation times, as AVTimedMetadataGroups of id3 items.
enum _ID3Reader {
    static func groups(_ url: URL) -> [AVTimedMetadataGroup] {
        guard let d = try? Data(contentsOf: url), d.count >= 188, d[0] == 0x47 else { return [] }
        let b = [UInt8](d)
        var pmtPIDs: Set<Int> = [], id3PIDs: Set<Int> = []
        var pes: [Int: [UInt8]] = [:]
        var groups: [AVTimedMetadataGroup] = []
        var firstPTS: Double?
        func finish(_ pid: Int) {
            guard let p = pes[pid], p.count >= 9, p[0] == 0, p[1] == 0, p[2] == 1 else { return }
            let flags = p[7], hlen = Int(p[8])
            var pts: Double?
            if flags & 0x80 != 0, p.count >= 14 {
                let v = (UInt64(p[9] & 0x0E) << 29) | (UInt64(p[10]) << 22) | (UInt64(p[11] & 0xFE) << 14) | (UInt64(p[12]) << 7) | (UInt64(p[13]) >> 1)
                pts = Double(v) / 90000
            }
            let body = Array(p[min(p.count, 9 + hlen)...])
            let items = id3Items(body)
            guard !items.isEmpty, let t = pts else { return }
            groups.append(AVTimedMetadataGroup(items: items, timeRange: CMTimeRange(start: CMTime(seconds: t, preferredTimescale: 90000), duration: .invalid)))
        }
        var o = 0
        while o + 188 <= b.count {
            defer { o += 188 }
            guard b[o] == 0x47 else { continue }
            let start = b[o + 1] & 0x40 != 0
            let pid = Int(b[o + 1] & 0x1F) << 8 | Int(b[o + 2])
            let afc = (b[o + 3] >> 4) & 3
            var p = o + 4
            if afc & 2 != 0 { p += 1 + Int(b[o + 4]) }
            guard afc & 1 != 0, p < o + 188 else { continue }
            let payload = Array(b[p..<(o + 188)])
            if pid == 0, start {                                   // PAT
                let sec = Array(payload[(1 + Int(payload[0]))...])
                let len = Int(sec[1] & 0x0F) << 8 | Int(sec[2])
                var i = 8
                while i + 4 <= min(sec.count, 3 + len - 4) {
                    let prog = Int(sec[i]) << 8 | Int(sec[i + 1]), pmt = Int(sec[i + 2] & 0x1F) << 8 | Int(sec[i + 3])
                    if prog != 0 { pmtPIDs.insert(pmt) }
                    i += 4
                }
            } else if pmtPIDs.contains(pid), start {               // PMT: find the ID3 streams
                let sec = Array(payload[(1 + Int(payload[0]))...])
                guard sec.count > 12 else { continue }
                let len = Int(sec[1] & 0x0F) << 8 | Int(sec[2])
                let infoLen = Int(sec[10] & 0x0F) << 8 | Int(sec[11])
                var i = 12 + infoLen
                let end = min(sec.count, 3 + len - 4)
                while i + 5 <= end {
                    let type = sec[i], epid = Int(sec[i + 1] & 0x1F) << 8 | Int(sec[i + 2])
                    let esLen = Int(sec[i + 3] & 0x0F) << 8 | Int(sec[i + 4])
                    let desc = Array(sec[(i + 5)..<min(end, i + 5 + esLen)])
                    let hasID3 = desc.count >= 6 && (0..<(desc.count - 3)).contains { k in desc[k] == 0x49 && desc[k + 1] == 0x44 && desc[k + 2] == 0x33 }
                    if type == 0x15 || (type == 0x06 && hasID3) { id3PIDs.insert(epid) }
                    i += 5 + esLen
                }
            } else if id3PIDs.contains(pid) {
                if start { finish(pid); pes[pid] = payload } else { pes[pid, default: []] += payload }
            } else if start, firstPTS == nil, payload.count >= 14, payload[0] == 0, payload[1] == 0, payload[2] == 1, payload[7] & 0x80 != 0 {
                let v = (UInt64(payload[9] & 0x0E) << 29) | (UInt64(payload[10]) << 22) | (UInt64(payload[11] & 0xFE) << 14) | (UInt64(payload[12]) << 7) | (UInt64(payload[13]) >> 1)
                firstPTS = Double(v) / 90000
            }
        }
        for pid in id3PIDs { finish(pid) }
        // times relative to the start of the media (the first audio / video PES), as the player's item times are
        let base = firstPTS ?? groups.map { $0.timeRange.start.seconds }.min() ?? 0
        return groups.map { g in
            let t = max(0, g.timeRange.start.seconds - base)
            for i in g.items { i._time = CMTime(seconds: t, preferredTimescale: 90000) }
            return AVTimedMetadataGroup(items: g.items, timeRange: CMTimeRange(start: CMTime(seconds: t, preferredTimescale: 90000), duration: .invalid))
        }.sorted { $0.timeRange.start.seconds < $1.timeRange.start.seconds }
    }
    /// the frames of an ID3v2.3 / v2.4 tag: text frames (T***), TXXX, PRIV, COMM, WXXX and others as data
    static func id3Items(_ b: [UInt8]) -> [AVMetadataItem] {
        guard b.count >= 10, b[0] == 0x49, b[1] == 0x44, b[2] == 0x33 else { return [] }
        let version = b[3]
        func syncsafe(_ i: Int) -> Int { Int(b[i]) << 21 | Int(b[i + 1]) << 14 | Int(b[i + 2]) << 7 | Int(b[i + 3]) }
        let size = syncsafe(6)
        var i = 10, items: [AVMetadataItem] = []
        let end = min(b.count, 10 + size)
        while i + 10 <= end {
            let id = String(decoding: b[i..<(i + 4)], as: UTF8.self)
            guard id.first?.isLetter == true || id.first?.isNumber == true else { break }
            let len = version >= 4 ? syncsafe(i + 4) : Int(b[i + 4]) << 24 | Int(b[i + 5]) << 16 | Int(b[i + 6]) << 8 | Int(b[i + 7])
            let body = Array(b[(i + 10)..<min(end, i + 10 + len)])
            i += 10 + len
            let item = AVMutableMetadataItem()
            item.identifier = AVMetadataIdentifier(rawValue: "id3/\(id)")
            func text(_ bytes: ArraySlice<UInt8>, _ enc: UInt8) -> String {
                let raw = Array(bytes)
                let s: String?
                switch enc {
                case 1, 2: s = String(data: Data(raw), encoding: enc == 1 ? .utf16 : .utf16BigEndian)
                case 3: s = String(decoding: raw, as: UTF8.self)
                default: s = String(data: Data(raw), encoding: .isoLatin1)
                }
                return (s ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
            }
            if id.hasPrefix("T"), let enc = body.first {
                var value = text(body.dropFirst(), enc)
                if id == "TXXX", let z = value.firstIndex(of: "\0") {       // description \0 value
                    item.extraAttributes = [.info: String(value[..<z])]
                    value = String(value[value.index(after: z)...]).trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                }
                item.value = value as NSString
            } else if id == "PRIV", let z = body.firstIndex(of: 0) {
                item.extraAttributes = [.info: String(decoding: body[..<z], as: UTF8.self)]
                item.value = Data(body[(z + 1)...]) as NSData
            } else {
                item.value = Data(body) as NSData
            }
            items.append(item)
        }
        return items
    }
}

// MARK: - access and error logs

@objc(AVPlayerItemAccessLogEvent) open class AVPlayerItemAccessLogEvent: NSObject, NSCopying, @unchecked Sendable {
    open internal(set) var numberOfMediaRequests = 1
    open internal(set) var playbackStartDate: Date?
    open internal(set) var uri: String?
    open internal(set) var serverAddress: String?
    open internal(set) var numberOfServerAddressChanges = 0
    open internal(set) var playbackSessionID: String?
    open internal(set) var playbackStartOffset: TimeInterval = 0
    open internal(set) var segmentsDownloadedDuration: TimeInterval = 0
    open internal(set) var durationWatched: TimeInterval = 0
    open internal(set) var numberOfStalls = 0
    open internal(set) var numberOfBytesTransferred: Int64 = 0
    open internal(set) var transferDuration: TimeInterval = 0
    open internal(set) var observedBitrate: Double = 0
    open internal(set) var indicatedBitrate: Double = 0
    open internal(set) var indicatedAverageBitrate: Double = 0
    open internal(set) var averageVideoBitrate: Double = 0
    open internal(set) var averageAudioBitrate: Double = 0
    open internal(set) var numberOfDroppedVideoFrames = 0
    open internal(set) var startupTime: TimeInterval = 0
    open internal(set) var downloadOverdue = 0
    open internal(set) var observedMaxBitrate: Double = 0
    open internal(set) var observedMinBitrate: Double = 0
    open internal(set) var observedBitrateStandardDeviation: Double = 0
    open internal(set) var playbackType: String?
    open internal(set) var mediaRequestsWWAN = 0
    open internal(set) var switchBitrate: Double = 0
    public override init() { super.init() }
    open func copy(with zone: NSZone? = nil) -> Any { self }
}
@objc(AVPlayerItemAccessLog) open class AVPlayerItemAccessLog: NSObject, NSCopying, @unchecked Sendable {
    public let events: [AVPlayerItemAccessLogEvent]
    init(events: [AVPlayerItemAccessLogEvent]) { self.events = events }
    open var extendedLogDataStringEncoding: UInt { String.Encoding.utf8.rawValue }
    /// W3C extended log format, like iOS
    open func extendedLogData() -> Data? {
        var s = "#Version: 1.0\n#Software: isim AVFoundation\n#Date: \(ISO8601DateFormatter().string(from: Date()))\n"
        s += "#Fields: date time uri cs-guid s-ip s-ip-changes sc-count c-duration-watched c-start-time c-observed-bitrate sc-indicated-bitrate c-stalls c-frames-dropped c-startup-time\n"
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC"); f.dateFormat = "yyyy/MM/dd HH:mm:ss.SSS"
        for e in events {
            let date = e.playbackStartDate.map { f.string(from: $0) } ?? "- -"
            s += "\(date) \(e.uri ?? "-") \(e.playbackSessionID ?? "-") \(e.serverAddress ?? "-") \(e.numberOfServerAddressChanges) \(e.numberOfMediaRequests) "
            s += "\(String(format: "%.3f", e.durationWatched)) \(String(format: "%.3f", e.playbackStartOffset)) \(Int(e.observedBitrate)) \(Int(e.indicatedBitrate)) "
            s += "\(e.numberOfStalls) \(e.numberOfDroppedVideoFrames) \(String(format: "%.3f", e.startupTime))\n"
        }
        return Data(s.utf8)
    }
    open func copy(with zone: NSZone? = nil) -> Any { self }
}
@objc(AVPlayerItemErrorLogEvent) open class AVPlayerItemErrorLogEvent: NSObject, NSCopying, @unchecked Sendable {
    open internal(set) var date: Date?
    open internal(set) var uri: String?
    open internal(set) var serverAddress: String?
    open internal(set) var playbackSessionID: String?
    open internal(set) var errorStatusCode = 0
    open internal(set) var errorDomain = ""
    open internal(set) var errorComment: String?
    open internal(set) var allHTTPResponseHeaderFields: [String: String]?
    public override init() { super.init() }
    open func copy(with zone: NSZone? = nil) -> Any { self }
}
@objc(AVPlayerItemErrorLog) open class AVPlayerItemErrorLog: NSObject, NSCopying, @unchecked Sendable {
    public let events: [AVPlayerItemErrorLogEvent]
    init(events: [AVPlayerItemErrorLogEvent]) { self.events = events }
    open var extendedLogDataStringEncoding: UInt { String.Encoding.utf8.rawValue }
    open func extendedLogData() -> Data? {
        var s = "#Version: 1.0\n#Software: isim AVFoundation\n#Fields: date time uri cs-guid s-ip status domain comment\n"
        for e in events {
            s += "\(e.date.map { ISO8601DateFormatter().string(from: $0) } ?? "-") \(e.uri ?? "-") \(e.playbackSessionID ?? "-") \(e.serverAddress ?? "-") "
            s += "\(e.errorStatusCode) \(e.errorDomain) \"\(e.errorComment ?? "")\"\n"
        }
        return Data(s.utf8)
    }
    open func copy(with zone: NSZone? = nil) -> Any { self }
}

extension AVPlayerItem {
    /// one event per playback of the item (from the first play to now)
    public func accessLog() -> AVPlayerItemAccessLog? { _accessEvents.isEmpty ? nil : AVPlayerItemAccessLog(events: _accessEvents) }
    public func errorLog() -> AVPlayerItemErrorLog? { _errorEvents.isEmpty ? nil : AVPlayerItemErrorLog(events: _errorEvents) }
    /// the player started playing this item: a new access log event
    func _logPlaybackStarted(requested: Double) {
        guard _accessEvents.isEmpty || _accessEvents.last?.playbackSessionID != _sessionID else { return }
        let e = AVPlayerItemAccessLogEvent()
        e.playbackStartDate = Date()
        let url = (asset as? AVURLAsset)?.url ?? asset._url           // the app's URL (not a resource loader's file)
        e.uri = url?.absoluteString
        e.playbackSessionID = _sessionID
        e.playbackType = url?.isFileURL == true ? "FILE" : "VOD"
        e.serverAddress = url?.isFileURL == true ? nil : url?.host
        e.playbackStartOffset = currentTime().seconds
        if let u = asset._url, u.isFileURL, let size = (try? FileManager.default.attributesOfItem(atPath: u.path))?[.size] as? NSNumber {
            e.numberOfBytesTransferred = size.int64Value
            if let d = _durationSeconds, d > 0 { e.indicatedBitrate = Double(size.int64Value) * 8 / d; e.indicatedAverageBitrate = e.indicatedBitrate }
            e.observedBitrate = e.indicatedBitrate; e.observedMaxBitrate = e.indicatedBitrate; e.observedMinBitrate = e.indicatedBitrate
            e.segmentsDownloadedDuration = _durationSeconds ?? 0
        }
        _playRequested = requested
        _accessEvents.append(e)
        NotificationCenter.default.post(name: AVPlayerItem.newAccessLogEntryNotification, object: self)
    }
    func _logWatched(_ seconds: Double) { _accessEvents.last?.durationWatched += max(0, seconds) }
    func _logFirstFrame() {
        guard let e = _accessEvents.last, e.startupTime == 0, _playRequested > 0 else { return }
        e.startupTime = max(0.001, isim_time() - _playRequested)
    }
    func _logError(_ error: Error?) {
        let ns = error as NSError?
        let e = AVPlayerItemErrorLogEvent()
        e.date = Date(); e.uri = ((asset as? AVURLAsset)?.url ?? asset._url)?.absoluteString; e.playbackSessionID = _sessionID
        e.errorDomain = ns?.domain ?? AVFoundationErrorDomain
        e.errorStatusCode = ns?.code ?? -11800
        e.errorComment = ns?.localizedFailureReason ?? ns?.localizedDescription
        _errorEvents.append(e)
        NotificationCenter.default.post(name: AVPlayerItem.newErrorLogEntryNotification, object: self)
    }
}

// MARK: - rate change reasons

extension AVPlayer {
    public struct RateDidChangeReason: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let setRateCalled = RateDidChangeReason(rawValue: "AVPlayerRateDidChangeReasonSetRateCalled")
        public static let setRateFailed = RateDidChangeReason(rawValue: "AVPlayerRateDidChangeReasonSetRateFailed")
        public static let audioSessionInterrupted = RateDidChangeReason(rawValue: "AVPlayerRateDidChangeReasonAudioSessionInterrupted")
        public static let appBackgrounded = RateDidChangeReason(rawValue: "AVPlayerRateDidChangeReasonAppBackgrounded")
    }
    public static let rateDidChangeReasonKey = "AVPlayerRateDidChangeReasonKey"
    public static let rateDidChangeOriginatingParticipantKey = "AVPlayerRateDidChangeOriginatingParticipantKey"
    func _postRateChange(_ reason: RateDidChangeReason) {
        NotificationCenter.default.post(name: AVPlayer.rateDidChangeNotification, object: self, userInfo: [AVPlayer.rateDidChangeReasonKey: reason])
    }
}

// MARK: - subtitles in AVPlayerLayer

extension AVPlayerLayer {
    /// the selected subtitles over the video: white text on a translucent rounded box near the bottom of the picture
    func _drawSubtitles(_ item: AVPlayerItem, _ t: Double, in video: CGRect, _ ctx: CGContext) {
        let cues = item._activeCues(t)
        guard !cues.isEmpty else { return }
        let text = cues.map(\.text).joined(separator: "\n")
        let size = max(12, min(30, video.height * 0.075))
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: UIColor.white]
        let maxWidth = video.width * 0.9
        let box = (text as NSString).boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                                 options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        let pad = size * 0.3
        let w = ceil(box.width) + pad * 2, h = ceil(box.height) + pad
        let r = CGRect(x: video.midX - w / 2, y: video.maxY - video.height * 0.06 - h, width: w, height: h)
        UIGraphicsPushContext(ctx)
        UIColor(white: 0, alpha: 0.6).setFill()
        UIBezierPath(roundedRect: r, cornerRadius: size * 0.25).fill()
        let para = NSMutableParagraphStyle(); para.alignment = .center
        var a = attrs; a[.paragraphStyle] = para
        (text as NSString).draw(with: CGRect(x: r.minX + pad, y: r.minY + pad / 2, width: w - pad * 2, height: h), options: .usesLineFragmentOrigin, attributes: a, context: nil)
        UIGraphicsPopContext()
    }
}
