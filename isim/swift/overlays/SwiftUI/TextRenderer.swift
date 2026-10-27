// isim SwiftUI (iOS 18): TextRenderer and Text.Layout — `View.textRenderer(_:)`, `TextProxy`, `TextAttribute` and
// `Text.customAttribute(_:)`, and GraphicsContext's `draw(_:options:)` of a line, run or run slice.
// Adapted: text under a renderer is laid out by isim's rich-text layout (Text+Formatting.swift: words placed on lines,
// wrapped to the width); that becomes a Text.Layout of lines, runs (a line's consecutive characters with one style
// and the same custom attributes) and one slice per character, measured with the run's font. The renderer draws the
// layout into a GraphicsContext (Canvas.swift) over the text's frame grown by its displayPadding; its animatableData
// animates like any Animatable view's.
import UIKit
import isim_host

/// A value attached to text with `Text.customAttribute(_:)`, read back from a layout's runs.
@available(iOS 18.0, *)
public protocol TextAttribute: Hashable {}

extension Text {
    /// The text with a custom attribute (for a TextRenderer: `run[T.self]`).
    @available(iOS 18.0, *)
    public func customAttribute<T: TextAttribute>(_ value: T) -> Text {
        var t = self
        t._x.custom[ObjectIdentifier(T.self)] = AnyHashable(value)
        return t
    }
}

/// Draws text from its layout.
@available(iOS 18.0, *)
public protocol TextRenderer: Animatable {
    func draw(layout: Text.Layout, in ctx: inout GraphicsContext)
    func sizeThatFits(proposal: ProposedViewSize, text: TextProxy) -> CGSize
    var displayPadding: EdgeInsets { get }
}
@available(iOS 18.0, *)
extension TextRenderer {
    public func sizeThatFits(proposal: ProposedViewSize, text: TextProxy) -> CGSize { text.sizeThatFits(proposal) }
    public var displayPadding: EdgeInsets { EdgeInsets() }
}

/// The text a renderer sizes.
@available(iOS 18.0, *)
public struct TextProxy {
    let size: @MainActor (ProposedViewSize) -> CGSize
    /// The text's own size for a proposal.
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { MainActor.assumeIsolated { size(proposal) } }
}

extension Text {
    /// Laid-out text: its lines.
    @available(iOS 18.0, *)
    public struct Layout: RandomAccessCollection {
        public typealias Element = Line
        public typealias Index = Int
        let lines: [Line]
        /// Whether lines were left out (a line limit).
        public var isTruncated: Bool
        public var startIndex: Int { 0 }
        public var endIndex: Int { lines.count }
        public subscript(i: Int) -> Line { lines[i] }

        /// A character's offset in the text.
        public struct CharacterIndex: Comparable, Hashable, Strideable, Sendable {
            let value: Int
            public static func < (a: CharacterIndex, b: CharacterIndex) -> Bool { a.value < b.value }
            public func distance(to other: CharacterIndex) -> Int { other.value - value }
            public func advanced(by n: Int) -> CharacterIndex { CharacterIndex(value: value + n) }
        }
        public struct DrawingOptions: OptionSet, Sendable {
            public let rawValue: UInt32
            public init(rawValue: UInt32) { self.rawValue = rawValue }
            public static var disablesSubpixelQuantization: DrawingOptions { DrawingOptions(rawValue: 1) }
        }
        /// Typographic bounds: from the baseline origin, a width and the ascent / descent / leading around it.
        public struct TypographicBounds: Equatable, Sendable {
            public var origin: CGPoint
            public var width: CGFloat
            public var ascent: CGFloat
            public var descent: CGFloat
            public var leading: CGFloat
            public init() { origin = .zero; width = 0; ascent = 0; descent = 0; leading = 0 }
            init(origin: CGPoint, width: CGFloat, ascent: CGFloat, descent: CGFloat, leading: CGFloat) {
                self.origin = origin; self.width = width; self.ascent = ascent; self.descent = descent; self.leading = leading
            }
            /// The box from ascent to descent.
            public var rect: CGRect { CGRect(x: origin.x, y: origin.y - ascent, width: width, height: ascent + descent) }
        }

        /// A line: its runs.
        public struct Line: RandomAccessCollection {
            public typealias Element = Run
            public typealias Index = Int
            let runs: [Run]
            /// The baseline's start.
            public var origin: CGPoint
            public var typographicBounds: TypographicBounds
            public var startIndex: Int { 0 }
            public var endIndex: Int { runs.count }
            public subscript(i: Int) -> Run { runs[i] }
        }

        /// One glyph (isim: a character) placed on its baseline.
        struct _Glyph {
            let text: String, x: CGFloat, width: CGFloat, index: Int
        }

        /// A run of characters with one style: its slices, one per character.
        public struct Run: RandomAccessCollection {
            public typealias Element = RunSlice
            public typealias Index = Int
            let glyphs: [_Glyph]
            let baseline: CGFloat
            let font: UIFont, color: UIColor, italic: Bool
            let custom: [ObjectIdentifier: AnyHashable]
            public var layoutDirection: LayoutDirection
            public var startIndex: Int { 0 }
            public var endIndex: Int { glyphs.count }
            public subscript(i: Int) -> RunSlice { RunSlice(run: self, indices: i..<(i + 1)) }
            public var typographicBounds: TypographicBounds { bounds(0..<glyphs.count) }
            public var characterIndices: [CharacterIndex] { glyphs.map { CharacterIndex(value: $0.index) } }
            /// The run's custom attribute of type T.
            public subscript<T: TextAttribute>(key: T.Type) -> T? { custom[ObjectIdentifier(T.self)]?.base as? T }
            func bounds(_ r: Range<Int>) -> TypographicBounds {
                guard let f = glyphs[safe: r.lowerBound], let l = glyphs[safe: r.upperBound - 1] else {
                    return TypographicBounds(origin: CGPoint(x: glyphs.first?.x ?? 0, y: baseline), width: 0, ascent: font.ascender, descent: -font.descender, leading: font.leading)
                }
                return TypographicBounds(origin: CGPoint(x: f.x, y: baseline), width: l.x + l.width - f.x, ascent: font.ascender, descent: -font.descender, leading: font.leading)
            }
        }

        /// A part of a run (isim: whole characters).
        public struct RunSlice {
            public var run: Run
            public var indices: Range<Int>
            public init(run: Run, indices: Range<Int>) { self.run = run; self.indices = indices }
            public var typographicBounds: TypographicBounds { run.bounds(indices) }
            public var characterIndices: [CharacterIndex] { indices.compactMap { run.glyphs[safe: $0] }.map { CharacterIndex(value: $0.index) } }
            public subscript<T: TextAttribute>(key: T.Type) -> T? { run[key] }
        }
    }
}

extension Array {
    fileprivate subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

@available(iOS 18.0, *)
extension GraphicsContext {
    /// Draws a line of text from a layout.
    public func draw(_ line: Text.Layout.Line, options: Text.Layout.DrawingOptions = .init()) {
        for run in line { draw(run, options: options) }
    }
    /// Draws a run of text from a layout.
    public func draw(_ run: Text.Layout.Run, options: Text.Layout.DrawingOptions = .init()) {
        draw(Text.Layout.RunSlice(run: run, indices: 0..<run.count), options: options)
    }
    /// Draws a slice of a run.
    public func draw(_ slice: Text.Layout.RunSlice, options: Text.Layout.DrawingOptions = .init()) {
        let run = slice.run
        let glyphs = slice.indices.compactMap { run.glyphs[safe: $0] }
        guard !glyphs.isEmpty else { return }
        let color = run.color.withAlphaComponent(run.color.cgColor.alpha * opacity)
        let attrs: [NSAttributedString.Key: Any] = [.font: run.font, .foregroundColor: color]
        _withState {
            for g in glyphs {
                (g.text as NSString).draw(at: CGPoint(x: g.x, y: run.baseline - run.font.ascender), withAttributes: attrs)
            }
        }
    }
}

// MARK: - The renderer in the environment

/// A TextRenderer, type-erased.
struct _AnyTextRenderer {
    /// draws the rendered-text node's layout
    let draw: @MainActor (_RenderedTextNode, inout GraphicsContext) -> Void
    /// sizes it for a proposal, given the text's own size
    let size: @MainActor (ProposedViewSize, @escaping @MainActor (ProposedViewSize) -> CGSize) -> CGSize
    let padding: EdgeInsets
    @available(iOS 18.0, *)
    init<R: TextRenderer>(_ r: R) {
        draw = { node, ctx in r.draw(layout: node.layout, in: &ctx) }
        size = { p, own in r.sizeThatFits(proposal: p, text: TextProxy(size: own)) }
        padding = r.displayPadding
    }
}
struct _TextRendererKey: EnvironmentKey { static var defaultValue: _AnyTextRenderer? { nil } }
extension EnvironmentValues {
    var _textRenderer: _AnyTextRenderer? { get { self[_TextRendererKey.self] } set { self[_TextRendererKey.self] = newValue } }
}

@available(iOS 18.0, *)
/// The view `textRenderer(_:)` makes: its renderer animates (Animatable), the content's text draws with it.
struct _TextRendererView<R: TextRenderer, Content: View>: View, _PrimitiveView, Animatable {
    var renderer: R
    let content: Content
    var body: Never { fatalError() }
    var animatableData: R.AnimatableData {
        get { renderer.animatableData }
        set { renderer.animatableData = newValue }
    }
    func _makeNode(_ ctx: _Context) -> _Node {
        let r = renderer
        return _resolve(content, ctx.child("tr").with { $0._textRenderer = _AnyTextRenderer(r) })
    }
}

extension View {
    /// Draws the text in this view with `renderer`.
    @available(iOS 18.0, *)
    public func textRenderer<T: TextRenderer>(_ renderer: T) -> some View { _TextRendererView(renderer: renderer, content: self) }
}

/// Text drawn by a TextRenderer: laid out by a rich-text node, drawn on a canvas.
final class _RenderedTextNode: _Node {
    let rich: _RichTextNode, renderer: _AnyTextRenderer, env: EnvironmentValues
    init(path: String, rich: _RichTextNode, renderer: _AnyTextRenderer, env: EnvironmentValues) {
        self.rich = rich; self.renderer = renderer; self.env = env
        super.init(path: path, children: [])
    }
    override var layoutPriority: Double { rich.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let rich = rich
        return renderer.size(ProposedViewSize(width: p.width, height: p.height)) { q in rich.sizeThatFits(_Proposal(width: q.width, height: q.height)) }
    }
    var textSize = CGSize.zero
    override func place(_ rect: CGRect) {
        let pad = renderer.padding
        frame = CGRect(x: rect.minX - pad.leading, y: rect.minY - pad.top, width: rect.width + pad.leading + pad.trailing, height: rect.height + pad.top + pad.bottom)
        textSize = rect.size
        rich.place(CGRect(origin: .zero, size: rect.size))
    }
    /// The rich layout as a Text.Layout (in the text's coordinates).
    @available(iOS 18.0, *)
    var layout: Text.Layout {
        var lines: [Text.Layout.Line] = []
        let ltr: LayoutDirection = isRTL ? .rightToLeft : .leftToRight
        for pl in rich.placedLines {
            var runs: [Text.Layout.Run] = []
            var glyphs: [Text.Layout._Glyph] = [], cur = -1
            func flush() {
                guard cur >= 0, !glyphs.isEmpty else { glyphs = []; return }
                let r = rich.runs[cur]
                runs.append(Text.Layout.Run(glyphs: glyphs, baseline: pl.baseline - r.baseline, font: r.font, color: r.color, italic: r.italic, custom: r.custom, layoutDirection: ltr))
                glyphs = []
            }
            for p in rich.placed[pl.pieces] {
                if p.run != cur { flush(); cur = p.run }
                let r = rich.runs[p.run]
                if r.image != nil { continue }
                var prefix = "", k = 0
                for ch in p.text {
                    let x0 = _RichTextNode.width(prefix, r)
                    prefix.append(ch)
                    let x1 = _RichTextNode.width(prefix, r)
                    glyphs.append(Text.Layout._Glyph(text: String(ch), x: p.frame.minX + x0, width: x1 - x0, index: p.start + k))
                    k += 1
                }
            }
            flush()
            let minX = runs.compactMap { $0.glyphs.first?.x }.min() ?? 0
            let maxX = runs.compactMap { $0.glyphs.last.map { $0.x + $0.width } }.max() ?? minX
            let leading = runs.map { $0.font.leading }.max() ?? 0
            lines.append(Text.Layout.Line(runs: runs, origin: CGPoint(x: minX, y: pl.baseline),
                                          typographicBounds: Text.Layout.TypographicBounds(origin: CGPoint(x: minX, y: pl.baseline), width: maxX - minX,
                                                                                           ascent: pl.ascent, descent: pl.descent, leading: leading)))
        }
        return Text.Layout(lines: lines, isTruncated: rich.truncated)
    }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUICanvasView(frame: .zero) }
        let draw = renderer.draw, pad = renderer.padding
        v.renderer = { [self] ctx, _ in
            ctx.translateBy(x: pad.leading, y: pad.top)
            MainActor.assumeIsolated { draw(self, &ctx) }
        }
        v.env = env
        v.isAccessibilityElement = true
        v.accessibilityLabel = rich.plain
        v.setNeedsDisplay()
        return v
    }
}
