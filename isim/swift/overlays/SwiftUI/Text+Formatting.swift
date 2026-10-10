// isim SwiftUI: rich Text — `Text + Text`, live date and timer text (`Text(date, style:)`, `Text(timerInterval:)`),
// formatter text, Markdown in localized string literals (bold, italic, code, strikethrough, links), decorations
// (underline, strikethrough, kerning/tracking, baseline offset, monospaced), `textCase`, `truncationMode`,
// `minimumScaleFactor`, `allowsTightening`, and the SF Symbol modifiers (`imageScale`, `symbolVariant`,
// `symbolRenderingMode`).
//
// Adapted rendering: isim's text engine draws one font and colour per label and has no attributed strings, so text
// with mixed styles is laid out here word by word (one UILabel per styled word) inside a container UILabel that
// carries the whole string (`dump` and `taptext` see it). Italics are drawn as a sheared label (isim's fonts have no
// italic faces); underline / strikethrough are hairline views; kerning places the characters one by one.
import UIKit

// MARK: - Text attributes

/// Per-Text extras (concatenation, live content, decorations). Unset values inherit from the enclosing Text / view.
struct _TextExtras {
    var parts: [Text]? = nil
    var live: _LiveText? = nil
    var underline: _TextLine? = nil
    var strike: _TextLine? = nil
    var kerning: CGFloat? = nil
    var baseline: CGFloat? = nil
    var design: Font.Design? = nil
    var link: URL? = nil
    var markdown = true
    var image: Image? = nil          // Text(Image(...)): an inline image (SF Symbols scale with the font)
}
struct _TextLine { let active: Bool; let color: Color? }

/// Text whose content depends on the time (relative dates, timers): re-rendered every second.
final class _LiveText {
    let make: (Date) -> String
    let ticks: Bool
    init(ticks: Bool, _ make: @escaping (Date) -> String) { self.make = make; self.ticks = ticks }
}

/// Text styling that view modifiers put in the environment (applies to every Text inside).
struct _TextEnvStyle {
    var weight: Font.Weight? = nil
    var italic = false
    var underline: _TextLine? = nil
    var strike: _TextLine? = nil
    var kerning: CGFloat? = nil
    var baseline: CGFloat? = nil
    var design: Font.Design? = nil
    var textCase: Text.Case? = nil
    var truncation: Text.TruncationMode = .tail
    var minimumScale: CGFloat = 1
    var tightening = false
}
struct _TextEnvKey: EnvironmentKey { static var defaultValue: _TextEnvStyle { _TextEnvStyle() } }
extension EnvironmentValues {
    var _textStyle: _TextEnvStyle { get { self[_TextEnvKey.self] } set { self[_TextEnvKey.self] = newValue } }
    public var textCase: Text.Case? { get { _textStyle.textCase } set { _textStyle.textCase = newValue } }
    public var truncationMode: Text.TruncationMode { get { _textStyle.truncation } set { _textStyle.truncation = newValue } }
    public var minimumScaleFactor: CGFloat { get { _textStyle.minimumScale } set { _textStyle.minimumScale = newValue } }
    public var allowsTightening: Bool { get { _textStyle.tightening } set { _textStyle.tightening = newValue } }
}

extension Text {
    /// An image inside text (`Text(Image(systemName: "star")) + Text(" Favorites")`): symbols take the text's font
    /// size, weight and colour.
    public init(_ image: Image) { self.init(verbatim: ""); _x.image = image }
}

extension Text {
    public enum Case: Hashable, Sendable { case uppercase, lowercase }
    public enum TruncationMode: Hashable, Sendable { case head, tail, middle }
    public struct LineStyle: Hashable, Sendable {
        public struct Pattern: Hashable, Sendable {
            let id: Int
            public static let solid = Pattern(id: 0), dot = Pattern(id: 1), dash = Pattern(id: 2), dashDot = Pattern(id: 3), dashDotDot = Pattern(id: 4)
        }
        let pattern: Pattern, color: Color?
        public init(pattern: Pattern = .solid, color: Color? = nil) { self.pattern = pattern; self.color = color }
        public static let single = LineStyle()
    }

    /// `Text("a") + Text("b").bold()`: the parts keep their own styles; modifiers on the sum apply to all parts.
    public static func + (lhs: Text, rhs: Text) -> Text {
        var t = Text(verbatim: "")
        t._x.parts = lhs._flatParts + rhs._flatParts
        return t
    }
    var _flatParts: [Text] {
        // a plain sum (no styling of its own) splices its parts; a styled one stays a group
        if let p = _x.parts, font == nil, color == nil, weight == nil, !italicFlag, _x.underline == nil, _x.strike == nil,
           _x.kerning == nil, _x.baseline == nil, _x.design == nil { return p }
        return [self]
    }

    public func underline(_ isActive: Bool = true, color: Color? = nil) -> Text { var t = self; t._x.underline = _TextLine(active: isActive, color: color); return t }
    public func underline(_ isActive: Bool = true, pattern: LineStyle.Pattern, color: Color? = nil) -> Text { underline(isActive, color: color) }
    public func strikethrough(_ isActive: Bool = true, color: Color? = nil) -> Text { var t = self; t._x.strike = _TextLine(active: isActive, color: color); return t }
    public func strikethrough(_ isActive: Bool = true, pattern: LineStyle.Pattern, color: Color? = nil) -> Text { strikethrough(isActive, color: color) }
    public func kerning(_ kerning: CGFloat) -> Text { var t = self; t._x.kerning = kerning; return t }
    public func tracking(_ tracking: CGFloat) -> Text { var t = self; t._x.kerning = tracking; return t }
    public func baselineOffset(_ offset: CGFloat) -> Text { var t = self; t._x.baseline = offset; return t }
    public func monospaced(_ isActive: Bool = true) -> Text { var t = self; t._x.design = isActive ? .monospaced : .default; return t }
    public func monospacedDigit() -> Text { self }
    public func fontDesign(_ design: Font.Design?) -> Text { var t = self; t._x.design = design; return t }
    public func fontWidth(_ width: Font.Width?) -> Text { self }
    public func textScale(_ scale: Text.Scale, isEnabled: Bool = true) -> Text { self }
    public struct Scale: Hashable, Sendable { let id: Int; public static let `default` = Scale(id: 0), secondary = Scale(id: 1) }
}

// MARK: - Dates, timers, formatters

extension Text {
    /// How `Text(_:style:)` shows a date. `.relative`, `.offset` and `.timer` update every second.
    public struct DateStyle: Hashable, Sendable {
        let id: Int
        public static let time = DateStyle(id: 0), date = DateStyle(id: 1), relative = DateStyle(id: 2), offset = DateStyle(id: 3), timer = DateStyle(id: 4)
    }
    public init(_ date: Date, style: DateStyle) {
        self.init(verbatim: "")
        _x.live = _LiveText(ticks: style.id >= 2) { now in _dateText(date, style, now: now) }
    }
    /// A date range, e.g. "10:00 AM – 11:30 AM" (same day) or "Oct 6, 2026 – Oct 8, 2026".
    public init(_ dates: ClosedRange<Date>) {
        self.init(verbatim: _rangeText(dates.lowerBound, dates.upperBound))
    }
    public init(_ interval: DateInterval) { self.init(interval.start...interval.end) }
    /// A live timer: the time left in (countsDown) or elapsed since the start of the interval, e.g. "4:59".
    public init(timerInterval: ClosedRange<Date>, pauseTime: Date? = nil, countsDown: Bool = true, showsHours: Bool = true) {
        self.init(verbatim: "")
        _x.live = _LiveText(ticks: pauseTime == nil) { now in
            let t = min(max(pauseTime ?? now, timerInterval.lowerBound), timerInterval.upperBound)
            let secs = countsDown ? timerInterval.upperBound.timeIntervalSince(t) : t.timeIntervalSince(timerInterval.lowerBound)
            return _clock(countsDown ? secs.rounded(.up) : secs.rounded(.down), showsHours: showsHours)
        }
    }
    /// Formatter text: `Text(price as NSNumber, formatter: currency)`.
    public init<Subject: NSObject>(_ subject: Subject, formatter: Formatter) {
        self.init(verbatim: formatter.string(for: subject) ?? "")
    }
    @_disfavoredOverload public init<Subject>(_ subject: Subject, formatter: Formatter) {      // Date, Int, ... (bridged)
        self.init(verbatim: formatter.string(for: subject as AnyObject) ?? "")
    }
}

@MainActor let _shortTime: DateFormatter = { let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short; return f }()
@MainActor let _longDate: DateFormatter = { let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .none; return f }()
@MainActor let _mediumDate: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f }()

func _clock(_ seconds: Double, showsHours: Bool = true) -> String {
    let s = Int(max(0, seconds))
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    func two(_ v: Int) -> String { v < 10 ? "0\(v)" : "\(v)" }
    if showsHours && h > 0 { return "\(h):\(two(m)):\(two(sec))" }
    return "\(showsHours ? m : m + h * 60):\(two(sec))"
}
/// "2 hr, 5 min" — the two largest units, like SwiftUI's relative style.
func _relative(_ seconds: Double) -> String {
    var s = Int(abs(seconds).rounded())
    let units: [(Int, String, String)] = [(86400 * 365, "yr", "yr"), (86400 * 30, "mth", "mth"), (86400 * 7, "wk", "wk"), (86400, "day", "days"), (3600, "hr", "hr"), (60, "min", "min"), (1, "sec", "sec")]
    var out: [String] = []
    for (size, one, many) in units where out.count < 2 {
        let n = s / size
        if n > 0 || (out.isEmpty && size == 1) { out.append("\(n) \(n == 1 ? one : many)"); s -= n * size }
        else if !out.isEmpty { break }
    }
    return out.joined(separator: ", ")
}
@MainActor func _dateText(_ date: Date, _ style: Text.DateStyle, now: Date) -> String {
    switch style.id {
    case 0: return _shortTime.string(from: date)
    case 1: return _longDate.string(from: date)
    case 2: return _relative(date.timeIntervalSince(now))
    case 3: let d = date.timeIntervalSince(now); return (d < 0 ? "-" : "+") + _relative(d)
    default: return _clock(abs(now.timeIntervalSince(date)))
    }
}
@MainActor func _rangeText(_ a: Date, _ b: Date) -> String {
    if Calendar.current.isDate(a, inSameDayAs: b) { return _shortTime.string(from: a) + " – " + _shortTime.string(from: b) }
    return _mediumDate.string(from: a) + " – " + _mediumDate.string(from: b)
}

extension LocalizedStringKey.StringInterpolation {
    public mutating func appendInterpolation(_ date: Date, style: Text.DateStyle) {
        let s = MainActor.assumeIsolated { _dateText(date, style, now: Date()) }
        key += "%@"; arguments.append(s)
    }
    public mutating func appendInterpolation<Subject: NSObject>(_ subject: Subject, formatter: Formatter) {
        key += "%@"; arguments.append(formatter.string(for: subject) ?? "")
    }
    public mutating func appendInterpolation(_ text: Text) { key += "%@"; arguments.append(text.string) }
}

/// Re-renders the graph every second while a live text is shown (released with the text's position).
final class _TextTicker: _AnyStorage {
    var timer: Timer?
    init(_ g: _Graph) {
        super.init()
        timer = Timer._isimScheduledTimer(withTimeInterval: 1, repeats: true) { [weak g] _ in
            MainActor.assumeIsolated { g?.invalidate() }
        }
    }
    deinit { timer?.invalidate() }
}

// MARK: - Markdown (CommonMark inline subset, as SwiftUI applies to string literals)

struct _MDStyle: Equatable { var bold = false, italic = false, strike = false, code = false; var link: URL? = nil }

/// Parses `**bold**`, `*italic*` / `_italic_`, `***both***`, `~~strike~~`, `` `code` ``, `[text](url)` and `\` escapes.
/// Returns nil when the string has no markup (the common case).
func _parseMarkdown(_ s: String) -> [(String, _MDStyle)]? {
    let chars = Array(s)
    guard chars.contains(where: { "*_~`[\\".contains($0) }) else { return nil }
    var out: [(String, _MDStyle)] = []
    func emit(_ t: String, _ st: _MDStyle) {
        if t.isEmpty { return }
        if let last = out.last, last.1 == st { out[out.count - 1].0 += t } else { out.append((t, st)) }
    }
    func isWord(_ c: Character?) -> Bool { c.map { $0.isLetter || $0.isNumber } ?? false }
    func find(_ delim: [Character], from: Int, end: Int) -> Int? {
        var j = from
        while j + delim.count <= end {
            if chars[j] == "\\" { j += 2; continue }
            if chars[j] == "`" {                               // code spans are opaque
                if let c = (j + 1..<end).first(where: { chars[$0] == "`" }) { j = c + 1; continue }
            }
            if chars[j] == delim[0] {
                var m = 0
                while j + m < end, chars[j + m] == delim[0] { m += 1 }
                let after: Character? = j + m < chars.count ? chars[j + m] : nil
                if m == delim.count, j > from, !chars[j - 1].isWhitespace, !(delim[0] == "_" && isWord(after)) { return j }
                j += m; continue
            }
            j += 1
        }
        return nil
    }
    func parse(_ start: Int, _ end: Int, _ st: _MDStyle) {
        var i = start, text = ""
        while i < end {
            let c = chars[i]
            if c == "\\", i + 1 < end, chars[i + 1].isPunctuation || chars[i + 1].isSymbol { text.append(chars[i + 1]); i += 2; continue }
            if c == "`", let close = (i + 1..<end).first(where: { chars[$0] == "`" }) {
                emit(text, st); text = ""
                var cs = st; cs.code = true
                emit(String(chars[i + 1..<close]), cs); i = close + 1; continue
            }
            if c == "[", let mid = (i + 1..<end).first(where: { chars[$0] == "]" }), mid + 1 < end, chars[mid + 1] == "(",
               let close = (mid + 2..<end).first(where: { chars[$0] == ")" }) {
                let url = URL(string: String(chars[mid + 2..<close]).trimmingCharacters(in: .whitespaces))
                emit(text, st); text = ""
                var ls = st; ls.link = url
                parse(i + 1, mid, ls); i = close + 1; continue
            }
            if c == "*" || c == "_" || c == "~" {
                var n = 0
                while i + n < end, chars[i + n] == c { n += 1 }
                let prev: Character? = i > 0 ? chars[i - 1] : nil
                let next: Character? = i + n < end ? chars[i + n] : nil
                let opens = (next.map { !$0.isWhitespace } ?? false) && !(c == "_" && isWord(prev))
                var matched = false
                if opens {
                    let lens: [Int] = c == "~" ? (n == 2 ? [2] : []) : Array(stride(from: min(n, 3), through: 1, by: -1))
                    for len in lens {
                        guard let close = find(Array(repeating: c, count: len), from: i + n, end: end) else { continue }
                        text += String(repeating: c, count: n - len)        // unmatched extra delimiters stay literal
                        emit(text, st); text = ""
                        var inner = st
                        if c == "~" { inner.strike = true } else { if len >= 2 { inner.bold = true }; if len != 2 { inner.italic = true } }
                        parse(i + n, close, inner)
                        i = close + len; matched = true; break
                    }
                }
                if !matched { text += String(repeating: c, count: n); i += n }
                continue
            }
            text.append(c); i += 1
        }
        emit(text, st)
    }
    parse(0, chars.count, _MDStyle())
    if out.count == 1 && out[0].1 == _MDStyle() && out[0].0 == s { return nil }
    return out
}

// MARK: - Resolution into runs

struct _TextRun {
    var text: String
    var image: UIImage? = nil        // an inline image run (Text(Image)); laid out like a word
    var font: UIFont
    var color: UIColor
    var italic = false
    var underline: UIColor? = nil
    var strike: UIColor? = nil
    var kerning: CGFloat = 0
    var baseline: CGFloat = 0
    var link: URL? = nil
    var code = false
    func sameStyle(_ o: _TextRun) -> Bool {
        font == o.font && color == o.color && italic == o.italic && underline == o.underline && strike == o.strike
            && kerning == o.kerning && baseline == o.baseline && link == o.link && code == o.code && image === o.image
    }
    var plain: Bool { image == nil && !italic && underline == nil && strike == nil && kerning == 0 && baseline == 0 && link == nil && !code }
}

/// Inherited text attributes (outer Text, then the view environment).
struct _TextInherit {
    var font: Font?, color: Color?, weight: Font.Weight?, italic = false
    var underline: _TextLine?, strike: _TextLine?, kerning: CGFloat?, baseline: CGFloat?, design: Font.Design?
    func merged(with t: Text) -> _TextInherit {
        var m = self
        if let f = t.font { m.font = f }
        if let c = t.color { m.color = c }
        if let w = t.weight { m.weight = w }
        if t.italicFlag { m.italic = true }
        if let u = t._x.underline { m.underline = u }
        if let s = t._x.strike { m.strike = s }
        if let k = t._x.kerning { m.kerning = k }
        if let b = t._x.baseline { m.baseline = b }
        if let d = t._x.design { m.design = d }
        return m
    }
}

extension Text {
    /// The text's content as plain characters (live text at the current time).
    var _plain: String {
        if let p = _x.parts { return p.map(\._plain).joined() }
        if _x.image != nil { return "" }
        if let l = _x.live { return MainActor.assumeIsolated { l.make(Date()) } }
        switch storage {
        case .verbatim(let s): return s
        case .localized(let k, let b):
            let s = k.resolved(b)
            return _parseMarkdown(s).map { $0.map(\.0).joined() } ?? s
        }
    }
    var _hasLive: Bool { _x.live?.ticks == true || (_x.parts?.contains { $0._hasLive } ?? false) }
}

@MainActor func _textRuns(_ t: Text, _ inherit: _TextInherit, _ env: EnvironmentValues) -> [_TextRun] {
    let a = inherit.merged(with: t)
    if let parts = t._x.parts { return parts.flatMap { _textRuns($0, a, env) } }
    if let img = t._x.image {
        var f = a.font ?? env.font ?? .body
        if let w = a.weight ?? env._textStyle.weight { f.weight = w }
        var e = env; e.font = f
        if let c = a.color { e._foreground = c }
        let color = a.color ?? env._foreground ?? .primary
        var run = _TextRun(text: "", font: f.uiFont, color: color.uiColor)
        run.image = _uiImage(img, e)
        run.baseline = a.baseline ?? env._textStyle.baseline ?? 0
        return [run]
    }
    var segments: [(String, _MDStyle)]
    if let l = t._x.live { segments = [(l.make(Date()), _MDStyle())] }
    else {
        switch t.storage {
        case .verbatim(let s): segments = [(s, _MDStyle())]
        case .localized(let k, let b):
            let s = k.resolved(b)
            segments = (t._x.markdown ? _parseMarkdown(s) : nil) ?? [(s, _MDStyle())]
        }
    }
    let tint = env._tint ?? .accentColor
    return segments.map { text, md in
        var f = a.font ?? env.font ?? .body
        if let w = a.weight ?? env._textStyle.weight { f.weight = w }
        if md.bold { f.weight = f.weight.value >= Font.Weight.bold.value ? .heavy : .bold }
        if let d = a.design ?? env._textStyle.design { f.design = d }
        if md.code { f.design = .monospaced }
        let link = md.link ?? t._x.link
        let color = link != nil ? tint : (a.color ?? env._foreground ?? .primary)
        var run = _TextRun(text: text, font: f.uiFont, color: color.uiColor)
        run.italic = a.italic || f.isItalic || env._textStyle.italic || md.italic
        func line(_ l: _TextLine?) -> UIColor? { l.flatMap { $0.active ? ($0.color ?? color).uiColor : nil } }
        run.underline = line(a.underline ?? env._textStyle.underline)
        run.strike = md.strike ? color.uiColor : line(a.strike ?? env._textStyle.strike)
        run.kerning = a.kerning ?? env._textStyle.kerning ?? 0
        run.baseline = a.baseline ?? env._textStyle.baseline ?? 0
        run.link = link
        run.code = md.code
        return run
    }
}

/// Builds the node for a Text: a plain label when the whole text has one style, else a rich (word-laid-out) text.
@MainActor func _makeTextNode(_ t: Text, _ ctx: _Context) -> _Node {
    let env = ctx.environment
    if t._hasLive {
        let key = ctx.path + "#tick"
        if ctx.graph.storage[key] == nil { ctx.graph.storage[key] = _TextTicker(ctx.graph) }
        ctx.graph.usedKeys.insert(key)
    }
    var runs = _textRuns(t, _TextInherit(), env)
    let textCase: Text.Case? = env._textStyle.textCase ?? (env._sectionHeader ? .uppercase : nil)
    if let c = textCase { for i in runs.indices { runs[i].text = c == .uppercase ? runs[i].text.uppercased() : runs[i].text.lowercased() } }
    let lines = env._lineRange
    let style = env._textStyle
    if env._redactsContent, let first = runs.first {       // .redacted(reason: .placeholder) (Styles.swift)
        let n = _TextNode(path: ctx.path + "/redacted", text: runs.map(\.text).joined(), font: first.font, color: first.color, minLines: lines.0, maxLines: lines.1,
                          alignment: env.multilineTextAlignment)
        return _RedactedTextNode(path: ctx.path, child: n)
    }
    if let first = runs.first, runs.allSatisfy({ $0.plain && $0.sameStyle(first) }) {
        let n = _TextNode(path: ctx.path, text: runs.map(\.text).joined(), font: first.font, color: first.color, minLines: lines.0, maxLines: lines.1,
                          alignment: env.multilineTextAlignment)
        n.truncation = style.truncation; n.minimumScale = style.minimumScale; n.tightening = style.tightening
        n.contentTransition = env._contentTransition
        return n
    }
    if runs.isEmpty { return _TextNode(path: ctx.path, text: "", font: (env.font ?? .body).uiFont, color: UIColor.label, minLines: lines.0, maxLines: lines.1, alignment: env.multilineTextAlignment) }
    let open = env.openURL
    return _RichTextNode(path: ctx.path, runs: runs, maxLines: lines.1, minLines: lines.0, alignment: env.multilineTextAlignment, open: { open($0) })
}

/// Shortens a one-line string to fit `width` with an ellipsis at the head, middle or tail.
@MainActor func _truncate(_ s: String, font: UIFont, width: CGFloat, mode: Text.TruncationMode) -> String {
    let l = _measureLabel
    l.font = font; l.numberOfLines = 1
    func w(_ x: String) -> CGFloat { l.text = x; return l.sizeThatFits(CGSize(width: 0, height: 1e6)).width }
    if width <= 0 || w(s) <= width + 0.5 { return s }
    let chars = Array(s)
    var lo = 0, hi = chars.count, best = "…"
    while lo <= hi {
        let keep = (lo + hi) / 2
        let cand: String
        switch mode {
        case .head: cand = "…" + String(chars.suffix(keep))
        case .tail: cand = String(chars.prefix(keep)) + "…"
        case .middle: cand = String(chars.prefix((keep + 1) / 2)) + "…" + String(chars.suffix(keep / 2))
        }
        if w(cand) <= width + 0.5 { best = cand; lo = keep + 1 } else { hi = keep - 1 }
    }
    return best
}

// MARK: - Rich text layout

final class _RichTextNode: _Node {
    let runs: [_TextRun], maxLines: Int?, minLines: Int?, alignment: TextAlignment, open: (URL) -> Void
    struct Piece { let run: Int; let text: String; let width: CGFloat; let hasBreak: Bool; let trailingSpace: CGFloat }
    struct Placed { let run: Int; let text: String; let frame: CGRect }
    var pieces: [Piece] = []
    var placed: [Placed] = []
    var plain: String { runs.map(\.text).joined() }
    init(path: String, runs: [_TextRun], maxLines: Int?, minLines: Int?, alignment: TextAlignment, open: @escaping (URL) -> Void) {
        self.runs = runs; self.maxLines = maxLines; self.minLines = minLines; self.alignment = alignment; self.open = open
        super.init(path: path, children: [])
        pieces = makePieces()
    }
    static func width(_ s: String, _ r: _TextRun) -> CGFloat {
        if s.isEmpty { return 0 }
        let l = _measureLabel
        l.font = r.font; l.numberOfLines = 1; l.text = s
        return l.sizeThatFits(CGSize(width: 0, height: 1e6)).width + r.kerning * CGFloat(s.count)
    }
    func makePieces() -> [Piece] {
        // words keep their trailing spaces (measured separately so a line can end without them)
        var out: [Piece] = []
        for (ri, r) in runs.enumerated() {
            if let im = r.image { out.append(Piece(run: ri, text: "\u{FFFC}", width: ceil(im.size.width), hasBreak: false, trailingSpace: 0)); continue }
            var word = "", spaces = ""
            func flush(_ brk: Bool) {
                if !word.isEmpty || !spaces.isEmpty || brk {
                    out.append(Piece(run: ri, text: word, width: _RichTextNode.width(word, r), hasBreak: brk,
                                     trailingSpace: spaces.isEmpty ? 0 : _RichTextNode.width("x" + spaces, r) - _RichTextNode.width("x", r)))
                }
                word = ""; spaces = ""
            }
            for c in r.text {
                if c == "\n" { flush(true) }
                else if c == " " || c == "\t" { spaces.append(" ") }
                else { if !spaces.isEmpty { flush(false) }; word.append(c) }
            }
            flush(false)
        }
        return out
    }
    func lineHeight(_ r: _TextRun) -> CGFloat { ceil(r.font.lineHeight) }
    /// Breaks the pieces into lines no wider than `maxWidth`.
    func layout(_ maxWidth: CGFloat?) -> (lines: [[Int]], widths: [CGFloat], heights: [CGFloat]) {
        var lines: [[Int]] = [[]], widths: [CGFloat] = [0], ends: [CGFloat] = [0]
        for (i, p) in pieces.enumerated() {
            let cur = lines.count - 1
            if let mw = maxWidth, !lines[cur].isEmpty, ends[cur] + p.width > mw + 0.5 {
                lines.append([]); widths.append(0); ends.append(0)
            }
            let k = lines.count - 1
            lines[k].append(i)
            widths[k] = ends[k] + p.width
            ends[k] = widths[k] + p.trailingSpace
            if p.hasBreak { lines.append([]); widths.append(0); ends.append(0) }
        }
        if lines.count > 1, lines.last!.isEmpty, !(pieces.last?.hasBreak ?? false) { lines.removeLast(); widths.removeLast() }
        if let m = maxLines, m > 0, lines.count > m { lines = Array(lines.prefix(m)); widths = Array(widths.prefix(m)) }
        let heights = lines.map { l in l.map { lineHeight(runs[pieces[$0].run]) }.max() ?? (runs.first.map { lineHeight($0) } ?? 20) }
        return (lines, widths, heights)
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let mw = p.width.flatMap { $0 >= 1e6 ? nil : $0 }
        let (_, widths, heights) = layout(mw)
        var h = heights.reduce(0, +)
        if let mn = minLines, heights.count < mn { h += CGFloat(mn - heights.count) * (heights.last ?? 20) }
        let w = ceil(widths.max() ?? 0)
        return CGSize(width: mw.map { min(w, $0) } ?? w, height: ceil(h))
    }
    override func place(_ rect: CGRect) {
        frame = rect
        let (lines, widths, heights) = layout(rect.width)
        placed = []
        var y: CGFloat = 0
        for (li, line) in lines.enumerated() {
            let lw = widths[li]
            var x: CGFloat = alignment == .center ? (rect.width - lw) / 2 : alignment == .trailing ? rect.width - lw : 0
            let asc = line.map { runs[pieces[$0].run].font.ascender }.max() ?? 0
            for (k, pi) in line.enumerated() {
                let p = pieces[pi], r = runs[p.run]
                let lh = lineHeight(r)
                let top = y + (asc - r.font.ascender) - r.baseline
                placed.append(Placed(run: p.run, text: p.text, frame: CGRect(x: x, y: top, width: ceil(p.width), height: lh)))
                x += p.width + (k == line.count - 1 ? 0 : p.trailingSpace)
            }
            y += heights[li]
        }
    }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIRichLabel(frame: .zero) }
        v.text = plain
        v.node = self
        v.isUserInteractionEnabled = runs.contains { $0.link != nil }
        v.rebuild(placed, runs)
        return v
    }
}

/// The container: a UILabel carrying the whole string (for dump / taptext / accessibility) that draws nothing
/// itself; its word labels and decoration lines are subviews.
final class _SUIRichLabel: UILabel {
    var node: _RichTextNode?
    override func drawText(in rect: CGRect) {}
    func rebuild(_ placed: [_RichTextNode.Placed], _ runs: [_TextRun]) {
        for s in subviews { s.removeFromSuperview() }
        let hair = 1 / max(1, UIScreen.main.scale)
        for p in placed where !p.text.isEmpty {
            let r = runs[p.run]
            if let im = r.image {
                let iv = UIImageView(frame: CGRect(x: p.frame.minX, y: p.frame.midY - im.size.height / 2, width: im.size.width, height: im.size.height))
                iv.image = im
                addSubview(iv)
                continue
            }
            var f = p.frame
            if r.code { f = f.insetBy(dx: -2, dy: 0) }
            if r.code {
                let bg = UIView(frame: f)
                bg.backgroundColor = .tertiarySystemFill; bg.layer.cornerRadius = 3
                addSubview(bg)
            }
            if r.kerning != 0 {
                // characters one by one, spaced by the kerning
                var x = p.frame.minX
                for ch in p.text {
                    let s = String(ch)
                    let l = UILabel(frame: CGRect(x: x, y: p.frame.minY, width: ceil(_RichTextNode.width(s, r) - r.kerning) + 1, height: p.frame.height))
                    l.text = s; l.font = r.font; l.textColor = r.color
                    if r.italic { l.transform = CGAffineTransform(a: 1, b: 0, c: -0.2, d: 1, tx: 0, ty: 0) }
                    addSubview(l)
                    x += _RichTextNode.width(s, r)
                }
            } else {
                let l = UILabel(frame: p.frame)
                l.text = p.text; l.font = r.font; l.textColor = r.color
                if r.italic { l.transform = CGAffineTransform(a: 1, b: 0, c: -0.2, d: 1, tx: 0, ty: 0) }
                addSubview(l)
            }
            let baseY = p.frame.minY + r.font.ascender
            if let c = r.underline {
                let u = UIView(frame: CGRect(x: p.frame.minX, y: baseY + 2, width: p.frame.width, height: max(1, hair)))
                u.backgroundColor = c; addSubview(u)
            }
            if let c = r.strike {
                let s = UIView(frame: CGRect(x: p.frame.minX, y: baseY - r.font.xHeight / 2, width: p.frame.width, height: max(1, hair)))
                s.backgroundColor = c; addSubview(s)
            }
            if let url = r.link {
                // a tappable area per link word (a control, so taps work inside scroll views and lists)
                let c = _SUIControl(frame: p.frame.insetBy(dx: -2, dy: -4))
                c.action = { [weak self] in self?.node?.open(url) }
                addSubview(c)
            }
        }
    }
}

// MARK: - View-level text modifiers

extension View {
    public func textCase(_ textCase: Text.Case?) -> some View { _env { $0._textStyle.textCase = textCase } }
    public func truncationMode(_ mode: Text.TruncationMode) -> some View { _env { $0._textStyle.truncation = mode } }
    public func minimumScaleFactor(_ factor: CGFloat) -> some View { _env { $0._textStyle.minimumScale = factor } }
    public func allowsTightening(_ flag: Bool) -> some View { _env { $0._textStyle.tightening = flag } }
    public func bold(_ isActive: Bool = true) -> some View { _env { if isActive { $0._textStyle.weight = .bold } } }
    public func italic(_ isActive: Bool = true) -> some View { _env { if isActive { $0._textStyle.italic = true } } }
    public func fontWeight(_ weight: Font.Weight?) -> some View { _env { $0._textStyle.weight = weight } }
    public func fontDesign(_ design: Font.Design?) -> some View { _env { $0._textStyle.design = design } }
    public func fontWidth(_ width: Font.Width?) -> some View { self }
    public func monospaced(_ isActive: Bool = true) -> some View { _env { $0._textStyle.design = isActive ? .monospaced : nil } }
    public func underline(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) -> some View {
        _env { $0._textStyle.underline = _TextLine(active: isActive, color: color) }
    }
    public func strikethrough(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) -> some View {
        _env { $0._textStyle.strike = _TextLine(active: isActive, color: color) }
    }
    public func kerning(_ kerning: CGFloat) -> some View { _env { $0._textStyle.kerning = kerning } }
    public func tracking(_ tracking: CGFloat) -> some View { _env { $0._textStyle.kerning = tracking } }
    public func baselineOffset(_ offset: CGFloat) -> some View { _env { $0._textStyle.baseline = offset } }
    public func lineSpacing(_ spacing: CGFloat) -> some View { self }
    public func textSelection<S>(_ selectability: S) -> some View { self }
    public func dynamicTypeSize(_ size: DynamicTypeSize) -> some View { _env { $0.dynamicTypeSize = size } }
    public func dynamicTypeSize<T: RangeExpression>(_ range: T) -> some View where T.Bound == DynamicTypeSize { self }
}

// MARK: - SF Symbol modifiers

public struct SymbolRenderingMode: Hashable, Sendable {
    let id: Int
    public static let monochrome = SymbolRenderingMode(id: 0), multicolor = SymbolRenderingMode(id: 1)
    public static let hierarchical = SymbolRenderingMode(id: 2), palette = SymbolRenderingMode(id: 3)
}
public struct SymbolVariants: Hashable, Sendable {
    let suffixes: [String]
    public static let none = SymbolVariants(suffixes: [])
    public static let fill = SymbolVariants(suffixes: ["fill"]), circle = SymbolVariants(suffixes: ["circle"])
    public static let square = SymbolVariants(suffixes: ["square"]), rectangle = SymbolVariants(suffixes: ["rectangle"])
    public static let slash = SymbolVariants(suffixes: ["slash"])
    public var fill: SymbolVariants { SymbolVariants(suffixes: suffixes + ["fill"]) }
    public var circle: SymbolVariants { SymbolVariants(suffixes: ["circle"] + suffixes) }
    public var square: SymbolVariants { SymbolVariants(suffixes: ["square"] + suffixes) }
    public var slash: SymbolVariants { SymbolVariants(suffixes: ["slash"] + suffixes) }
    public func contains(_ other: SymbolVariants) -> Bool { other.suffixes.allSatisfy(suffixes.contains) }
}
struct _ImageScaleKey: EnvironmentKey { static var defaultValue: Image.Scale { .medium } }
struct _SymbolVariantsKey: EnvironmentKey { static var defaultValue: SymbolVariants { .none } }
struct _SymbolRenderingKey: EnvironmentKey { static var defaultValue: SymbolRenderingMode? { nil } }
extension EnvironmentValues {
    public var imageScale: Image.Scale { get { self[_ImageScaleKey.self] } set { self[_ImageScaleKey.self] = newValue } }
    public var symbolVariants: SymbolVariants { get { self[_SymbolVariantsKey.self] } set { self[_SymbolVariantsKey.self] = newValue } }
    public var symbolRenderingMode: SymbolRenderingMode? { get { self[_SymbolRenderingKey.self] } set { self[_SymbolRenderingKey.self] = newValue } }
}
extension View {
    public func imageScale(_ scale: Image.Scale) -> some View { _env { $0.imageScale = scale } }
    public func symbolVariant(_ variant: SymbolVariants) -> some View { _env { $0.symbolVariants = variant } }
    public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> some View { _env { $0.symbolRenderingMode = mode } }
}
extension Image {
    public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> Image { var i = self; i.symbolMode = mode; return i }
}
struct _PaletteKey: EnvironmentKey { static var defaultValue: [Color]? { nil } }
extension EnvironmentValues { var _palette: [Color]? { get { self[_PaletteKey.self] } set { self[_PaletteKey.self] = newValue } } }
extension View {
    /// Primary and secondary styles: the palette of `.palette` symbols (and the primary foreground).
    public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle>(_ primary: S1, _ secondary: S2) -> some View {
        _modify { ctx, c in
            let env = ctx.environment
            return _resolve(c, ctx.child("e").with { $0._foreground = _color(of: primary, env); $0._palette = [_color(of: primary, env), _color(of: secondary, env)] })
        }
    }
    public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle, S3: ShapeStyle>(_ primary: S1, _ secondary: S2, _ tertiary: S3) -> some View {
        _modify { ctx, c in
            let env = ctx.environment
            return _resolve(c, ctx.child("e").with {
                $0._foreground = _color(of: primary, env); $0._palette = [_color(of: primary, env), _color(of: secondary, env), _color(of: tertiary, env)]
            })
        }
    }
}
/// A symbol configuration with the rendering mode; true when the symbol carries its own colours (not a template).
@MainActor func _symbolRendering(_ base: UIImage.SymbolConfiguration, _ mode: SymbolRenderingMode?, _ env: EnvironmentValues) -> (UIImage.SymbolConfiguration, Bool) {
    let fg = (env._foreground ?? .primary).uiColor
    switch mode?.id {
    case 1: return (base.applying(UIImage.SymbolConfiguration.preferringMulticolor()), true)
    case 2: return (base.applying(UIImage.SymbolConfiguration(hierarchicalColor: fg)), true)
    case 3:
        // palette: the foreground styles' colours (one style: its colour for every layer)
        let colors = env._palette?.map(\.uiColor) ?? [fg]
        return (base.applying(UIImage.SymbolConfiguration(paletteColors: colors)), true)
    default: return (base, false)
    }
}
/// The symbol name with the environment's variants ("heart" + .fill -> "heart.fill") when such a symbol exists.
@MainActor func _symbolName(_ name: String, _ env: EnvironmentValues) -> String {
    let v = env.symbolVariants.suffixes
    if v.isEmpty { return name }
    let full = ([name] + v.filter { !name.split(separator: ".").contains(Substring($0)) }).joined(separator: ".")
    return UIImage(systemName: full) != nil ? full : name
}
@MainActor func _symbolConfig(_ font: UIFont, _ env: EnvironmentValues) -> UIImage.SymbolConfiguration {
    let base = UIImage.SymbolConfiguration(font: font)
    switch env.imageScale {
    case .small: return base.applying(UIImage.SymbolConfiguration(scale: .small))
    case .large: return base.applying(UIImage.SymbolConfiguration(scale: .large))
    default: return base
    }
}

// MARK: - Dynamic type & other environment values

public enum DynamicTypeSize: Hashable, Comparable, CaseIterable, Sendable {
    case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge, accessibility1, accessibility2, accessibility3, accessibility4, accessibility5
    public var isAccessibilitySize: Bool { self >= .accessibility1 }
}
public enum ColorSchemeContrast: Hashable, CaseIterable, Sendable { case standard, increased }
struct _DynamicTypeKey: EnvironmentKey { static var defaultValue: DynamicTypeSize { MainActor.assumeIsolated { _systemDynamicTypeSize() } } }
struct _CalendarKey: EnvironmentKey { static var defaultValue: Calendar { Calendar.current } }
struct _TimeZoneKey: EnvironmentKey { static var defaultValue: TimeZone { TimeZone.current } }
struct _ContrastKey: EnvironmentKey { static var defaultValue: ColorSchemeContrast { UIAccessibility.isDarkerSystemColorsEnabled ? .increased : .standard } }
extension EnvironmentValues {
    public var dynamicTypeSize: DynamicTypeSize { get { self[_DynamicTypeKey.self] } set { self[_DynamicTypeKey.self] = newValue } }
    public var calendar: Calendar { get { self[_CalendarKey.self] } set { self[_CalendarKey.self] = newValue } }
    public var timeZone: TimeZone { get { self[_TimeZoneKey.self] } set { self[_TimeZoneKey.self] = newValue } }
    public var colorSchemeContrast: ColorSchemeContrast { get { self[_ContrastKey.self] } set { self[_ContrastKey.self] = newValue } }
}
