// Captions (issue #877, part 2): AVCaption and AVMutableCaption with their styled ranges (colors, font weight and
// style, decorations, text combine, ruby), regions, groups and the grouper, the renderer, the format conformer and the
// conversion validator.
//
// Adapted: the styles are kept as runs over the text's UTF-16 ranges (like Apple's NSRange setters). The renderer
// draws the active captions with UIKit text drawing into the context given. The validator and conformer check the
// rules isim knows for CEA-608 (mediaSubType 'c608': 32 characters per row) and time ranges.
import Foundation
import CoreMedia
import CoreGraphics
import UIKit

// MARK: - geometry

/// how a caption dimension is measured
@objc public enum AVCaptionUnitsType: Int, Sendable { case unspecified = 0, cells, percent }
public struct AVCaptionDimension: Equatable, Sendable {
    public var value: CGFloat
    public var units: AVCaptionUnitsType
    public init() { value = 0; units = .unspecified }
    public init(value: CGFloat, units: AVCaptionUnitsType) { self.value = value; self.units = units }
}
public struct AVCaptionPoint: Equatable, Sendable {
    public var x: AVCaptionDimension
    public var y: AVCaptionDimension
    public init() { x = AVCaptionDimension(); y = AVCaptionDimension() }
    public init(x: AVCaptionDimension, y: AVCaptionDimension) { self.x = x; self.y = y }
}
public struct AVCaptionSize: Equatable, Sendable {
    public var width: AVCaptionDimension
    public var height: AVCaptionDimension
    public init() { width = AVCaptionDimension(); height = AVCaptionDimension() }
    public init(width: AVCaptionDimension, height: AVCaptionDimension) { self.width = width; self.height = height }
}
func _pct(_ v: CGFloat) -> AVCaptionDimension { AVCaptionDimension(value: v, units: .percent) }

// MARK: - regions

/// Where on the video a caption is shown
@available(iOS 18.0, *)
@objc(AVCaptionRegion) open class AVCaptionRegion: NSObject, NSCopying, NSMutableCopying, NSSecureCoding, @unchecked Sendable {
    @objc public enum DisplayAlignment: Int, Sendable { case before = 0, center, after }
    @objc public enum WritingMode: Int, Sendable { case leftToRightAndTopToBottom = 0, topToBottomAndRightToLeft = 2 }
    @objc public enum Scroll: Int, Sendable { case none = 0, rollUp }
    public class var supportsSecureCoding: Bool { true }
    var _identifier: String?
    var _origin = AVCaptionPoint(), _size = AVCaptionSize()
    var _scroll = Scroll.none, _alignment = DisplayAlignment.before, _writing = WritingMode.leftToRightAndTopToBottom
    open var identifier: String? { _identifier }
    open var origin: AVCaptionPoint { _origin }
    open var size: AVCaptionSize { _size }
    open var scroll: Scroll { _scroll }
    open var displayAlignment: DisplayAlignment { _alignment }
    open var writingMode: WritingMode { _writing }
    override init() { super.init() }
    static func _make(_ id: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, align: DisplayAlignment, writing: WritingMode = .leftToRightAndTopToBottom) -> AVCaptionRegion {
        let r = AVCaptionRegion(); r._identifier = id
        r._origin = AVCaptionPoint(x: _pct(x), y: _pct(y)); r._size = AVCaptionSize(width: _pct(w), height: _pct(h))
        r._alignment = align; r._writing = writing
        return r
    }
    /// the iTT (iTunes Timed Text) regions and SubRip's bottom region
    open class var appleITTTop: AVCaptionRegion { _make("top", x: 0, y: 0, w: 100, h: 15, align: .before) }
    open class var appleITTBottom: AVCaptionRegion { _make("bottom", x: 0, y: 85, w: 100, h: 15, align: .after) }
    open class var appleITTLeft: AVCaptionRegion { _make("left", x: 0, y: 0, w: 15, h: 100, align: .before, writing: .topToBottomAndRightToLeft) }
    open class var appleITTRight: AVCaptionRegion { _make("right", x: 85, y: 0, w: 15, h: 100, align: .after, writing: .topToBottomAndRightToLeft) }
    open class var subRipTextBottom: AVCaptionRegion { _make("subrip-bottom", x: 0, y: 85, w: 100, h: 15, align: .after) }
    func _copy<T: AVCaptionRegion>(into r: T) -> T {
        r._identifier = _identifier; r._origin = _origin; r._size = _size; r._scroll = _scroll; r._alignment = _alignment; r._writing = _writing
        return r
    }
    open func copy(with zone: NSZone? = nil) -> Any { _copy(into: AVCaptionRegion()) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { _copy(into: AVMutableCaptionRegion()) }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? AVCaptionRegion else { return false }
        return o._identifier == _identifier && o._origin == _origin && o._size == _size && o._scroll == _scroll && o._alignment == _alignment && o._writing == _writing
    }
    open override var hash: Int { _identifier?.hashValue ?? 0 }
    open func encode(with coder: NSCoder) {
        coder.encode(_identifier, forKey: "identifier")
        for (k, d) in [("x", _origin.x), ("y", _origin.y), ("w", _size.width), ("h", _size.height)] {
            coder.encode(Double(d.value), forKey: k); coder.encode(d.units.rawValue, forKey: k + "u")
        }
        coder.encode(_scroll.rawValue, forKey: "scroll"); coder.encode(_alignment.rawValue, forKey: "align"); coder.encode(_writing.rawValue, forKey: "writing")
    }
    public required init?(coder: NSCoder) {
        super.init()
        _identifier = coder.decodeObject(forKey: "identifier") as? String
        func d(_ k: String) -> AVCaptionDimension {
            AVCaptionDimension(value: CGFloat(coder.decodeDouble(forKey: k)), units: AVCaptionUnitsType(rawValue: coder.decodeInteger(forKey: k + "u")) ?? .unspecified)
        }
        _origin = AVCaptionPoint(x: d("x"), y: d("y")); _size = AVCaptionSize(width: d("w"), height: d("h"))
        _scroll = Scroll(rawValue: coder.decodeInteger(forKey: "scroll")) ?? .none
        _alignment = DisplayAlignment(rawValue: coder.decodeInteger(forKey: "align")) ?? .before
        _writing = WritingMode(rawValue: coder.decodeInteger(forKey: "writing")) ?? .leftToRightAndTopToBottom
    }
}
@available(iOS 18.0, *)
@objc(AVMutableCaptionRegion) open class AVMutableCaptionRegion: AVCaptionRegion, @unchecked Sendable {
    public override init() { super.init() }
    public init(identifier: String) { super.init(); _identifier = identifier }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override var origin: AVCaptionPoint { get { _origin } set { _origin = newValue } }
    open override var size: AVCaptionSize { get { _size } set { _size = newValue } }
    open override var scroll: Scroll { get { _scroll } set { _scroll = newValue } }
    open override var displayAlignment: DisplayAlignment { get { _alignment } set { _alignment = newValue } }
    open override var writingMode: WritingMode { get { _writing } set { _writing = newValue } }
}

// MARK: - styled runs

/// a value over UTF-16 ranges of the caption text
struct _CaptionRuns<V> {
    var runs: [(NSRange, V)] = []
    mutating func set(_ v: V, _ r: NSRange) { remove(r); runs.append((r, v)); runs.sort { $0.0.location < $1.0.location } }
    mutating func remove(_ r: NSRange) {
        var out: [(NSRange, V)] = []
        for (x, v) in runs {
            let a = x.location, b = x.location + x.length, c = r.location, d = r.location + r.length
            if b <= c || a >= d { out.append((x, v)); continue }
            if a < c { out.append((NSRange(location: a, length: c - a), v)) }
            if b > d { out.append((NSRange(location: d, length: b - d), v)) }
        }
        runs = out
    }
    /// the value at a UTF-16 offset and the range it covers (the gap between runs when none)
    func at(_ i: Int, length: Int) -> (V?, NSRange) {
        if let (r, v) = runs.first(where: { NSLocationInRange(i, $0.0) }) { return (v, r) }
        let start = runs.filter { $0.0.location + $0.0.length <= i }.map { $0.0.location + $0.0.length }.max() ?? 0
        let end = runs.filter { $0.0.location > i }.map(\.0.location).min() ?? length
        return (nil, NSRange(location: start, length: max(0, end - start)))
    }
}

// MARK: - captions

/// A caption: text shown over a time range, in a region, with styled ranges
@available(iOS 18.0, *)
@objc(AVCaption) open class AVCaption: NSObject, NSCopying, NSMutableCopying, NSSecureCoding, @unchecked Sendable {
    @objc public enum Animation: Int, Sendable { case none = 0, characterReveal }
    @objc public enum TextAlignment: Int, Sendable { case start = 0, end, center, left, right }
    @objc public enum FontWeight: Int, Sendable { case unknown = 0, normal, bold }
    @objc public enum FontStyle: Int, Sendable { case unknown = 0, normal, italic }
    @objc public enum TextCombine: Int, Sendable { case all = -1, none = 0, oneDigit = 1, twoDigits = 2, threeDigits = 3, fourDigits = 4 }
    public struct Decoration: OptionSet, Hashable, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static var underline: Decoration { Decoration(rawValue: 1) }
        public static var lineThrough: Decoration { Decoration(rawValue: 2) }
        public static var overline: Decoration { Decoration(rawValue: 4) }
    }
    /// ruby text (furigana) over a range of the caption
    @objc(AVCaptionRuby) public final class Ruby: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
        @objc public enum Position: Int, Sendable { case before = 0, after }
        @objc public enum Alignment: Int, Sendable { case start = 0, center, distributeSpaceBetween, distributeSpaceAround }
        public static var supportsSecureCoding: Bool { true }
        public let text: String
        public let position: Position
        public let alignment: Alignment
        public init(text: String) { self.text = text; position = .before; alignment = .center }
        public convenience init(text: String, position: Position, alignment: Alignment) { self.init(text, position, alignment) }
        init(_ t: String, _ p: Position, _ a: Alignment) { text = t; position = p; alignment = a }
        public func copy(with zone: NSZone? = nil) -> Any { self }
        public func encode(with coder: NSCoder) { coder.encode(text, forKey: "text"); coder.encode(position.rawValue, forKey: "p"); coder.encode(alignment.rawValue, forKey: "a") }
        public init?(coder: NSCoder) {
            text = coder.decodeObject(forKey: "text") as? String ?? ""
            position = Position(rawValue: coder.decodeInteger(forKey: "p")) ?? .before
            alignment = Alignment(rawValue: coder.decodeInteger(forKey: "a")) ?? .center
        }
        public override func isEqual(_ o: Any?) -> Bool { (o as? Ruby).map { $0.text == text && $0.position == position && $0.alignment == alignment } ?? false }
    }
    public class var supportsSecureCoding: Bool { true }
    var _text: String
    var _timeRange: CMTimeRange
    var _region: AVCaptionRegion?
    var _alignment = TextAlignment.start, _animation = Animation.none
    var _textColor = _CaptionRuns<CGColor>(), _background = _CaptionRuns<CGColor>()
    var _weight = _CaptionRuns<FontWeight>(), _style = _CaptionRuns<FontStyle>(), _decoration = _CaptionRuns<Decoration>()
    var _combine = _CaptionRuns<TextCombine>(), _ruby = _CaptionRuns<Ruby>()
    public init(_ text: String, timeRange: CMTimeRange) { _text = text; _timeRange = timeRange; super.init() }
    open var text: String { _text }
    open var timeRange: CMTimeRange { _timeRange }
    open var region: AVCaptionRegion? { _region }
    open var textAlignment: TextAlignment { _alignment }
    open var animation: Animation { _animation }
    func _offset(_ i: String.Index) -> Int { _text.utf16.distance(from: _text.startIndex, to: i) }
    func _range(_ r: NSRange) -> Range<String.Index> {
        Range(r, in: _text) ?? _text.startIndex..<_text.startIndex
    }
    func _at<V>(_ runs: _CaptionRuns<V>, _ i: String.Index) -> (V?, Range<String.Index>) {
        let (v, r) = runs.at(_offset(i), length: _text.utf16.count)
        return (v, _range(r))
    }
    open func textColor(at index: String.Index) -> (CGColor?, Range<String.Index>) { _at(_textColor, index) }
    open func backgroundColor(at index: String.Index) -> (CGColor?, Range<String.Index>) { _at(_background, index) }
    open func fontWeight(at index: String.Index) -> (FontWeight, Range<String.Index>) { let (v, r) = _at(_weight, index); return (v ?? .normal, r) }
    open func fontStyle(at index: String.Index) -> (FontStyle, Range<String.Index>) { let (v, r) = _at(_style, index); return (v ?? .normal, r) }
    open func decoration(at index: String.Index) -> (Decoration, Range<String.Index>) { let (v, r) = _at(_decoration, index); return (v ?? [], r) }
    open func textCombine(at index: String.Index) -> (TextCombine, Range<String.Index>) { let (v, r) = _at(_combine, index); return (v ?? .none, r) }
    open func ruby(at index: String.Index) -> (Ruby?, Range<String.Index>) { _at(_ruby, index) }
    func _copy<T: AVCaption>(into c: T) -> T {
        c._region = _region; c._alignment = _alignment; c._animation = _animation
        c._textColor = _textColor; c._background = _background; c._weight = _weight; c._style = _style
        c._decoration = _decoration; c._combine = _combine; c._ruby = _ruby
        return c
    }
    open func copy(with zone: NSZone? = nil) -> Any { _copy(into: AVCaption(_text, timeRange: _timeRange)) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { _copy(into: AVMutableCaption(_text, timeRange: _timeRange)) }
    open override func isEqual(_ o: Any?) -> Bool {
        guard let c = o as? AVCaption else { return false }
        return c._text == _text && CMTimeRangeEqual(c._timeRange, _timeRange) && (c._region == _region || c._region?.isEqual(_region) == true)
            && c._alignment == _alignment && c._animation == _animation
    }
    open override var hash: Int { _text.hashValue }
    /// coding keeps the text, time range, region, alignment and animation (the styled runs are not archived)
    open func encode(with coder: NSCoder) {
        coder.encode(_text, forKey: "text")
        coder.encode(_timeRange.start.seconds, forKey: "start"); coder.encode(_timeRange.duration.seconds, forKey: "duration")
        coder.encode(_region, forKey: "region"); coder.encode(_alignment.rawValue, forKey: "align"); coder.encode(_animation.rawValue, forKey: "anim")
    }
    public required init?(coder: NSCoder) {
        _text = coder.decodeObject(forKey: "text") as? String ?? ""
        _timeRange = CMTimeRange(start: CMTime(seconds: coder.decodeDouble(forKey: "start"), preferredTimescale: 600),
                                 duration: CMTime(seconds: coder.decodeDouble(forKey: "duration"), preferredTimescale: 600))
        super.init()
        _region = coder.decodeObject(forKey: "region") as? AVCaptionRegion
        _alignment = TextAlignment(rawValue: coder.decodeInteger(forKey: "align")) ?? .start
        _animation = Animation(rawValue: coder.decodeInteger(forKey: "anim")) ?? .none
    }
}

@available(iOS 18.0, *)
@objc(AVMutableCaption) open class AVMutableCaption: AVCaption, @unchecked Sendable {
    public init(text: String, timeRange: CMTimeRange) { super.init(text, timeRange: timeRange) }
    public override init(_ text: String, timeRange: CMTimeRange) { super.init(text, timeRange: timeRange) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override var text: String { get { _text } set { _text = newValue } }
    open override var timeRange: CMTimeRange { get { _timeRange } set { _timeRange = newValue } }
    open override var region: AVCaptionRegion? { get { _region } set { _region = newValue?.copy() as? AVCaptionRegion } }
    open override var textAlignment: TextAlignment { get { _alignment } set { _alignment = newValue } }
    open override var animation: Animation { get { _animation } set { _animation = newValue } }
    open func setTextColor(_ color: CGColor, in range: NSRange) { _textColor.set(color, range) }
    open func removeTextColor(in range: NSRange) { _textColor.remove(range) }
    open func setBackgroundColor(_ color: CGColor, in range: NSRange) { _background.set(color, range) }
    open func removeBackgroundColor(in range: NSRange) { _background.remove(range) }
    open func setFontWeight(_ w: FontWeight, in range: NSRange) { _weight.set(w, range) }
    open func removeFontWeight(in range: NSRange) { _weight.remove(range) }
    open func setFontStyle(_ s: FontStyle, in range: NSRange) { _style.set(s, range) }
    open func removeFontStyle(in range: NSRange) { _style.remove(range) }
    open func setDecoration(_ d: Decoration, in range: NSRange) { _decoration.set(d, range) }
    open func removeDecoration(in range: NSRange) { _decoration.remove(range) }
    open func setTextCombine(_ c: TextCombine, in range: NSRange) { _combine.set(c, range) }
    open func removeTextCombine(in range: NSRange) { _combine.remove(range) }
    open func setRuby(_ r: Ruby, in range: NSRange) { _ruby.set(r, range) }
    open func removeRuby(in range: NSRange) { _ruby.remove(range) }
}

// MARK: - groups

/// the captions shown together over a time range
@available(iOS 18.0, *)
@objc(AVCaptionGroup) open class AVCaptionGroup: NSObject, @unchecked Sendable {
    public let captions: [AVCaption]
    public let timeRange: CMTimeRange
    public init(captions: [AVCaption], timeRange: CMTimeRange) { self.captions = captions; self.timeRange = timeRange }
    public convenience init(timeRange: CMTimeRange) { self.init(captions: [], timeRange: timeRange) }
}
/// Splits captions into groups at every time a caption starts or ends
@available(iOS 18.0, *)
@objc(AVCaptionGrouper) open class AVCaptionGrouper: NSObject, @unchecked Sendable {
    var _captions: [AVCaption] = []
    var _flushed = CMTime.zero
    public override init() { super.init() }
    open func add(_ input: AVCaption) { _captions.append(input) }
    /// the groups that end by `upTo` (the gaps between captions are empty groups); later captions stay for the next flush
    open func flushAddedCaptions(upTo upToTime: CMTime) -> [AVCaptionGroup] {
        var cuts = Set<CMTime>()
        for c in _captions { cuts.insert(c.timeRange.start); cuts.insert(c.timeRange.end) }
        let times = cuts.filter { $0 > _flushed && $0 <= upToTime }.sorted()
        var groups: [AVCaptionGroup] = []
        var start = _captions.map(\.timeRange.start).filter { $0 >= _flushed }.min() ?? _flushed
        for t in times where t > start {
            let range = CMTimeRange(start: start, end: t)
            let active = _captions.filter { $0.timeRange.start <= start && $0.timeRange.end >= t }
            groups.append(AVCaptionGroup(captions: active, timeRange: range))
            start = t
        }
        _flushed = max(_flushed, times.last ?? _flushed)
        _captions.removeAll { $0.timeRange.end <= _flushed }
        return groups
    }
}

// MARK: - rendering

/// Draws the captions active at a time into a context (UIKit text drawing; bold, italic, colors and underline)
@available(iOS 18.0, *)
@objc(AVCaptionRenderer) open class AVCaptionRenderer: NSObject, @unchecked Sendable {
    /// a stretch of time over which the rendered captions do not change
    @objc(AVCaptionRendererScene) public final class Scene: NSObject, @unchecked Sendable {
        public let timeRange: CMTimeRange
        public let hasActiveCaptions: Bool
        public let needsPeriodicRefresh: Bool
        init(_ r: CMTimeRange, _ active: Bool, _ refresh: Bool) { timeRange = r; hasActiveCaptions = active; needsPeriodicRefresh = refresh }
    }
    public override init() { super.init() }
    open var captions: [AVCaption] = []
    open var bounds = CGRect.zero
    /// the scenes over a time range: one per stretch between caption starts and ends
    open func captionSceneChanges(in consideredTimeRange: CMTimeRange) -> [Scene] {
        var cuts = Set<CMTime>([consideredTimeRange.start, consideredTimeRange.end])
        for c in captions { for t in [c.timeRange.start, c.timeRange.end] where consideredTimeRange.containsTime(t) { cuts.insert(t) } }
        let times = cuts.sorted()
        return zip(times, times.dropFirst()).map { a, b in
            let active = captions.filter { $0.timeRange.start <= a && $0.timeRange.end >= b }
            return Scene(CMTimeRange(start: a, end: b), !active.isEmpty, active.contains { $0.animation == .characterReveal })
        }
    }
    /// draws the captions active at `time`: each in its region (the bottom of the bounds by default)
    open func render(in ctx: CGContext, for time: CMTime) {
        let active = captions.filter { $0.timeRange.containsTime(time) }
        guard !active.isEmpty, bounds.width > 0, bounds.height > 0 else { return }
        UIGraphicsPushContext(ctx); defer { UIGraphicsPopContext() }
        let size = max(12, bounds.height / 15)
        for (n, c) in active.enumerated() {
            let r = c.region ?? AVCaptionRegion.appleITTBottom
            func v(_ d: AVCaptionDimension, _ total: CGFloat) -> CGFloat { d.units == .percent ? d.value / 100 * total : d.value }
            var frame = CGRect(x: bounds.minX + v(r.origin.x, bounds.width), y: bounds.minY + v(r.origin.y, bounds.height),
                               width: v(r.size.width, bounds.width), height: v(r.size.height, bounds.height))
            if frame.width <= 0 || frame.height <= 0 { frame = CGRect(x: bounds.minX, y: bounds.maxY - size * 2, width: bounds.width, height: size * 1.5) }
            frame.origin.y -= CGFloat(n) * size * 1.3
            let shown = c.animation == .characterReveal
                ? String(c.text.prefix(Int(Double(c.text.count) * min(1, max(0, (time - c.timeRange.start).seconds / max(0.001, c.timeRange.duration.seconds))))))
                : c.text
            let s = NSMutableAttributedString(string: shown, attributes: [.font: UIFont.systemFont(ofSize: size), .foregroundColor: UIColor.white])
            var i = shown.startIndex
            while i < shown.endIndex {
                let (w, wr) = c.fontWeight(at: i), (st, _) = c.fontStyle(at: i), (col, _) = c.textColor(at: i), (bg, _) = c.backgroundColor(at: i), (dec, _) = c.decoration(at: i)
                let end = min(wr.upperBound, shown.endIndex)
                let nr = NSRange(i..<max(end, shown.index(after: i)), in: shown)
                var traits: UIFontDescriptor.SymbolicTraits = []
                if w == .bold { traits.insert(.traitBold) }
                if st == .italic { traits.insert(.traitItalic) }
                if !traits.isEmpty, let d = UIFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits(traits) { s.addAttribute(.font, value: UIFont(descriptor: d, size: size), range: nr) }
                if let col { s.addAttribute(.foregroundColor, value: UIColor(cgColor: col), range: nr) }
                if let bg { s.addAttribute(.backgroundColor, value: UIColor(cgColor: bg), range: nr) }
                if dec.contains(.underline) { s.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nr) }
                if dec.contains(.lineThrough) { s.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: nr) }
                i = max(end, shown.index(after: i))
            }
            let p = NSMutableParagraphStyle()
            switch c.textAlignment { case .center: p.alignment = .center; case .right, .end: p.alignment = .right; default: p.alignment = .left }
            s.addAttribute(.paragraphStyle, value: p, range: NSRange(location: 0, length: s.length))
            s.draw(in: frame)
        }
    }
    /// iOS 26.4: a sample of how captions look with a caption style profile (isim: the default style)
    @available(iOS 26.4, *)
    open class func captionPreview(forProfileID profileID: String, extendedLanguageTag: String?, renderSize: CGSize) -> NSAttributedString {
        NSAttributedString(string: "Subtitles look like this", attributes: [.font: UIFont.systemFont(ofSize: max(12, renderSize.height / 15)), .foregroundColor: UIColor.white,
                                                                              .backgroundColor: UIColor.black.withAlphaComponent(0.75)])
    }
}

// MARK: - conversion settings, conformer and validator

@available(iOS 18.0, *)
public struct AVCaptionSettingsKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let mediaType = Self(rawValue: "AVCaptionMediaTypeKey")
    public static let mediaSubType = Self(rawValue: "AVCaptionMediaSubTypeKey")
    public static let timeCodeFrameDuration = Self(rawValue: "AVCaptionTimeCodeFrameDurationKey")
    public static let useDropFrameTimeCode = Self(rawValue: "AVCaptionUseDropFrameTimeCodeKey")
}
/// CEA-608 (closed captions): 32 characters per row, times on frame boundaries
let _cea608SubType: FourCharCode = 0x6336_3038                                              // 'c608'
@available(iOS 18.0, *)
func _isCEA608(_ s: [AVCaptionSettingsKey: Any]) -> Bool {
    if let v = s[.mediaSubType] as? NSNumber { return v.uint32Value == _cea608SubType }
    if let v = s[.mediaSubType] as? FourCharCode { return v == _cea608SubType }
    return false
}
@available(iOS 18.0, *)
func _frameDuration(_ s: [AVCaptionSettingsKey: Any]) -> CMTime {
    if let t = s[.timeCodeFrameDuration] as? CMTime { return t }
    if let v = s[.timeCodeFrameDuration] as? NSValue { return v.timeValue }
    return CMTime(value: 1001, timescale: 30000)
}

/// Makes captions fit a caption format's rules
@available(iOS 18.0, *)
@objc(AVCaptionFormatConformer) open class AVCaptionFormatConformer: NSObject, @unchecked Sendable {
    let _settings: [AVCaptionSettingsKey: Any]
    public init(conversionSettings: [AVCaptionSettingsKey: Any]) { _settings = conversionSettings; super.init() }
    open var conformsCaptionsToTimeRange = false
    /// CEA-608: the text cut to 32 characters per row and, with conformsCaptionsToTimeRange, the times on frame boundaries
    open func conformedCaption(for caption: AVCaption) throws -> AVCaption {
        let m = caption.mutableCopy() as! AVMutableCaption
        if _isCEA608(_settings) {
            m.text = m.text.split(separator: "\n", omittingEmptySubsequences: false).map { String($0.prefix(32)) }.joined(separator: "\n")
        }
        if conformsCaptionsToTimeRange {
            let f = _frameDuration(_settings)
            func snap(_ t: CMTime) -> CMTime { CMTimeMultiply(f, multiplier: Int32((t.seconds / f.seconds).rounded())) }
            m.timeRange = CMTimeRange(start: snap(m.timeRange.start), end: snap(m.timeRange.end))
        }
        return m.copy() as! AVCaption
    }
}

@available(iOS 18.0, *)
@objc(AVCaptionConversionAdjustment) open class AVCaptionConversionAdjustment: NSObject, @unchecked Sendable {
    public struct AdjustmentType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let timeRange = Self(rawValue: "AVCaptionConversionAdjustmentTypeTimeRange")
    }
    public let adjustmentType: AdjustmentType
    init(_ t: AdjustmentType) { adjustmentType = t }
}
@available(iOS 18.0, *)
@objc(AVCaptionConversionTimeRangeAdjustment) open class AVCaptionConversionTimeRangeAdjustment: AVCaptionConversionAdjustment, @unchecked Sendable {
    public let startTimeOffset: CMTime
    public let durationOffset: CMTime
    init(start: CMTime, duration: CMTime) { startTimeOffset = start; durationOffset = duration; super.init(.timeRange) }
}
@available(iOS 18.0, *)
@objc(AVCaptionConversionWarning) open class AVCaptionConversionWarning: NSObject, @unchecked Sendable {
    public struct WarningType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let excessMediaData = Self(rawValue: "AVCaptionConversionWarningTypeExcessMediaData")
    }
    public let warningType: WarningType
    public let rangeOfCaptions: NSRange
    public let adjustment: AVCaptionConversionAdjustment?
    init(_ t: WarningType, _ r: NSRange, _ a: AVCaptionConversionAdjustment?) { warningType = t; rangeOfCaptions = r; adjustment = a }
}
/// Checks whether captions can be converted to a format: captions cut off by the time range get a time-range
/// adjustment; CEA-608 rows over 32 characters are excess media data.
@available(iOS 18.0, *)
@objc(AVCaptionConversionValidator) open class AVCaptionConversionValidator: NSObject, @unchecked Sendable {
    @objc public enum Status: Int, Sendable { case unknown = 0, validating, completed, stopped }
    public let captions: [AVCaption]
    public let timeRange: CMTimeRange
    let _settings: [AVCaptionSettingsKey: Any]
    open private(set) var status = Status.unknown
    open private(set) var warnings: [AVCaptionConversionWarning] = []
    let _lock = NSLock()
    public init(captions: [AVCaption], timeRange: CMTimeRange, conversionSettings: [AVCaptionSettingsKey: Any]) {
        self.captions = captions; self.timeRange = timeRange; _settings = conversionSettings
        super.init()
    }
    /// reports each warning, then nil when done (on a background queue)
    open func validateCaptionConversion(warningHandler handler: @escaping (AVCaptionConversionWarning?) -> Void) {
        _lock.lock(); status = .validating; _lock.unlock()
        DispatchQueue.global().async {
            for (i, c) in self.captions.enumerated() {
                self._lock.lock(); let stopped = self.status == .stopped; self._lock.unlock()
                if stopped { return }
                var found: [AVCaptionConversionWarning] = []
                let r = c.timeRange.intersection(self.timeRange)
                if !CMTimeRangeEqual(r, c.timeRange) {
                    let adj = AVCaptionConversionTimeRangeAdjustment(start: r.start - c.timeRange.start, duration: r.duration - c.timeRange.duration)
                    found.append(AVCaptionConversionWarning(.excessMediaData, NSRange(location: i, length: 1), adj))
                }
                if _isCEA608(self._settings), c.text.split(separator: "\n").contains(where: { $0.count > 32 }) {
                    found.append(AVCaptionConversionWarning(.excessMediaData, NSRange(location: i, length: 1), nil))
                }
                for w in found { self._lock.lock(); self.warnings.append(w); self._lock.unlock(); handler(w) }
            }
            self._lock.lock(); self.status = .completed; self._lock.unlock()
            handler(nil)
        }
    }
    open func stopValidating() { _lock.lock(); if status == .validating { status = .stopped }; _lock.unlock() }
}

// MARK: - Objective-C (AVEditing.h)
@available(iOS 18.0, *)
extension AVCaptionRegion {
    @objc(appleITTTopRegion) class var _objc_top: AVCaptionRegion { appleITTTop }
    @objc(appleITTBottomRegion) class var _objc_bottom: AVCaptionRegion { appleITTBottom }
    @objc(appleITTLeftRegion) class var _objc_left: AVCaptionRegion { appleITTLeft }
    @objc(appleITTRightRegion) class var _objc_right: AVCaptionRegion { appleITTRight }
    @objc(subRipTextBottomRegion) class var _objc_subRip: AVCaptionRegion { subRipTextBottom }
    @objc(identifier) var _objc_identifier: String? { identifier }
}
@available(iOS 18.0, *)
extension AVMutableCaptionRegion {
    @objc(initWithIdentifier:) convenience init(_objc identifier: String) { self.init(identifier: identifier) }
}
@available(iOS 18.0, *)
extension AVCaption {
    @objc(text) var _objc_text: String { text }
    @objc(region) var _objc_region: AVCaptionRegion? { region }
    @objc(textAlignment) var _objc_alignment: TextAlignment { textAlignment }
}
@available(iOS 18.0, *)
extension AVMutableCaption {
    @objc(setText:) func _objc_setText(_ t: String) { text = t }
    @objc(setRegion:) func _objc_setRegion(_ r: AVCaptionRegion?) { region = r }
    @objc(setTextAlignment:) func _objc_setAlignment(_ a: TextAlignment) { textAlignment = a }
    @objc(setTextColor:inRange:) func _objc_setTextColor(_ c: CGColor, _ r: NSRange) { setTextColor(c, in: r) }
    @objc(removeTextColorInRange:) func _objc_removeTextColor(_ r: NSRange) { removeTextColor(in: r) }
    @objc(setBackgroundColor:inRange:) func _objc_setBackground(_ c: CGColor, _ r: NSRange) { setBackgroundColor(c, in: r) }
    @objc(removeBackgroundColorInRange:) func _objc_removeBackground(_ r: NSRange) { removeBackgroundColor(in: r) }
    @objc(setFontWeight:inRange:) func _objc_setWeight(_ w: FontWeight, _ r: NSRange) { setFontWeight(w, in: r) }
    @objc(removeFontWeightInRange:) func _objc_removeWeight(_ r: NSRange) { removeFontWeight(in: r) }
    @objc(setFontStyle:inRange:) func _objc_setStyle(_ s: FontStyle, _ r: NSRange) { setFontStyle(s, in: r) }
    @objc(removeFontStyleInRange:) func _objc_removeStyle(_ r: NSRange) { removeFontStyle(in: r) }
    @objc(setDecoration:inRange:) func _objc_setDecoration(_ d: UInt, _ r: NSRange) { setDecoration(Decoration(rawValue: d), in: r) }
    @objc(removeDecorationInRange:) func _objc_removeDecoration(_ r: NSRange) { removeDecoration(in: r) }
}
@available(iOS 18.0, *)
extension AVCaptionGroup {
    @objc(captions) var _objc_captions: [AVCaption] { captions }
}
@available(iOS 18.0, *)
extension AVCaptionGrouper {
    @objc(addCaption:) func _objc_add(_ c: AVCaption) { add(c) }
}
