// isim SwiftUI (iOS 26): rich text editing — `TextEditor(text: Binding<AttributedString>, selection:)` and
// `AttributedTextSelection`. A UITextView shows the attributed string (SwiftUI font, colours, underline,
// strikethrough, kerning, baseline offset, bold / italic / code intents, links); typing replaces the edited characters
// in the AttributedString, the new text taking the attributes before it (the typing attributes); the selection
// binding follows the text view's selection and moves it when set.
import UIKit

/// A selection in an AttributedString: an insertion point or ranges.
@available(iOS 26.0, *)
public struct AttributedTextSelection: Equatable, Sendable {
    @frozen public enum Indices: Equatable, Sendable {
        case insertionPoint(AttributedString.Index)
        case ranges(RangeSet<AttributedString.Index>)
    }
    /// character offsets (nil: the end of the text)
    var range: Range<Int>?
    public init() { range = nil }
    init(offsets: Range<Int>) { range = offsets }
    public init(insertionPoint: AttributedString.Index) { range = nil; pending = .insertionPoint(insertionPoint) }
    public init(range: Range<AttributedString.Index>) { self.range = nil; pending = .ranges(RangeSet(range)) }
    public init(ranges: RangeSet<AttributedString.Index>) { range = nil; pending = .ranges(ranges) }
    /// indices given before the text was known (resolved against the text when used)
    var pending: Indices?
    /// The selection's indices in `text`.
    public func indices(in text: AttributedString) -> Indices {
        if let p = pending { return p }
        let chars = text.characters
        let n = chars.count
        guard let r = range else { return .insertionPoint(text.endIndex) }
        let lo = chars.index(chars.startIndex, offsetBy: min(r.lowerBound, n)), hi = chars.index(chars.startIndex, offsetBy: min(r.upperBound, n))
        return lo == hi ? .insertionPoint(lo) : .ranges(RangeSet(lo..<hi))
    }
    func offsets(in text: AttributedString) -> Range<Int> {
        let chars = text.characters
        switch pending {
        case .insertionPoint(let i)?: let o = chars.distance(from: chars.startIndex, to: i); return o..<o
        case .ranges(let rs)?:
            guard let f = rs.ranges.first, let l = rs.ranges.last else { return chars.count..<chars.count }
            return chars.distance(from: chars.startIndex, to: f.lowerBound)..<chars.distance(from: chars.startIndex, to: l.upperBound)
        case nil: return range ?? chars.count..<chars.count
        }
    }
}
/// The selection binding, type-erased (TextEditor's stored property predates iOS 26).
struct _AnySelection {
    var get: () -> Range<Int>?          // character offsets (nil: none set)
    var set: (Range<Int>) -> Void
}
extension TextEditor {
    /// Rich text: edits change the attributed string; `selection` follows (and sets) the selection.
    @available(iOS 26.0, *)
    public init(text: Binding<AttributedString>, selection: Binding<AttributedTextSelection>? = nil) {
        self.text = Binding(get: { String(text.wrappedValue.characters) }, set: { _ in })
        attributed = text
        if let selection {
            self.selection = Binding(get: {
                _AnySelection(get: { selection.wrappedValue.offsets(in: text.wrappedValue) }, set: { selection.wrappedValue = AttributedTextSelection(offsets: $0) })
            }, set: { _ in })
        }
    }
}

struct _AttributedEditor: View, _PrimitiveView {
    let text: Binding<AttributedString>, selection: Binding<_AnySelection>?
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let n = _AttributedEditorNode(path: ctx.path, text: text, selection: selection?.wrappedValue)
        n.baseFont = (ctx.environment.font ?? .body).uiFont
        n.baseColor = (ctx.environment._foreground ?? .primary).uiColor
        return n
    }
}
final class _AttributedEditorNode: _Node {
    let text: Binding<AttributedString>, selection: _AnySelection?
    var baseFont: UIFont = .systemFont(ofSize: 17), baseColor: UIColor = .label
    init(path: String, text: Binding<AttributedString>, selection: _AnySelection?) {
        self.text = text; self.selection = selection; super.init(path: path, children: [])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 300, height: p.height ?? 200) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIAttributedTextView(frame: .zero, textContainer: nil) }
        v.node = self
        let shown = _nsAttributed(text.wrappedValue, font: baseFont, color: baseColor)
        if !v.attributedText.isEqual(to: shown) {
            let sel = v.selectedRange
            v.attributedText = shown
            v.selectedRange = NSRange(location: min(sel.location, shown.length), length: 0)
        }
        if let s = selection?.get(), let r = _utf16Range(s, in: String(text.wrappedValue.characters)), r != v.selectedRange { v.selectedRange = r }
        v.typingAttributes = _typingAttributes(v)
        return v
    }
}
final class _SUIAttributedTextView: UITextView, UITextViewDelegate {
    var node: _AttributedEditorNode?
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        delegate = self
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func textViewDidChange(_ tv: UITextView) {
        guard let n = node else { return }
        var a = n.text.wrappedValue
        let old = Array(String(a.characters)), new = Array(tv.text ?? "")
        var p = 0
        while p < old.count, p < new.count, old[p] == new[p] { p += 1 }
        var s = 0
        while s < old.count - p, s < new.count - p, old[old.count - 1 - s] == new[new.count - 1 - s] { s += 1 }
        let chars = a.characters
        let lo = chars.index(chars.startIndex, offsetBy: p), hi = chars.index(chars.startIndex, offsetBy: old.count - s)
        // the inserted text takes the attributes of the character before it (or the first one)
        var attrs = AttributeContainer()
        if !a.characters.isEmpty {
            let at = p > 0 ? chars.index(lo, offsetBy: -1) : chars.startIndex
            attrs = a[at..<chars.index(after: at)].runs.first?.attributes ?? AttributeContainer()
        }
        a.replaceSubrange(lo..<hi, with: AttributedString(String(new[p..<(new.count - s)]), attributes: attrs))
        n.text.wrappedValue = a
    }
    func textViewDidChangeSelection(_ tv: UITextView) {
        guard let n = node, let sel = n.selection, let r = Range(tv.selectedRange, in: tv.text ?? "") else { return }
        let t = tv.text ?? ""
        let off = t.distance(from: t.startIndex, to: r.lowerBound)..<t.distance(from: t.startIndex, to: r.upperBound)
        if sel.get() != off { sel.set(off) }
        tv.typingAttributes = _typingAttributes(tv)
    }
}
/// The attributes typed text gets: those before the insertion point.
@MainActor func _typingAttributes(_ tv: UITextView) -> [NSAttributedString.Key: Any] {
    let a = tv.attributedText ?? NSAttributedString()
    guard a.length > 0 else { return tv.typingAttributes }
    let i = max(0, min(a.length - 1, tv.selectedRange.location - 1))
    return a.attributes(at: i, effectiveRange: nil)
}
func _utf16Range(_ r: Range<Int>, in s: String) -> NSRange? {
    let n = s.count
    let lo = s.index(s.startIndex, offsetBy: min(r.lowerBound, n)), hi = s.index(s.startIndex, offsetBy: min(r.upperBound, n))
    return NSRange(lo..<hi, in: s)
}
/// The UIKit attributed string of an AttributedString (SwiftUI and Foundation attributes).
@MainActor func _nsAttributed(_ a: AttributedString, font: UIFont, color: UIColor) -> NSAttributedString {
    let out = NSMutableAttributedString()
    let s = AttributeScopes.SwiftUIAttributes.self
    for run in a.runs {
        var f = run.attributes[s.FontAttribute.self]?.uiFont ?? font
        var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: run.attributes[s.ForegroundColorAttribute.self]?.uiColor ?? color]
        if let intent = run.attributes[AttributeScopes.FoundationAttributes.InlinePresentationIntentAttribute.self] {
            var traits = f.fontDescriptor.symbolicTraits
            if intent.contains(.stronglyEmphasized) { traits.insert(.traitBold) }
            if intent.contains(.emphasized) { traits.insert(.traitItalic) }
            if let d = f.fontDescriptor.withSymbolicTraits(traits) { f = UIFont(descriptor: d, size: f.pointSize) }
            if intent.contains(.code) { f = .monospacedSystemFont(ofSize: f.pointSize, weight: .regular) }
            if intent.contains(.strikethrough) { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        }
        attrs[.font] = f
        if let b = run.attributes[s.BackgroundColorAttribute.self] { attrs[.backgroundColor] = b.uiColor }
        if let u = run.attributes[s.UnderlineStyleAttribute.self] { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue; if let c = u.color { attrs[.underlineColor] = c.uiColor } }
        if let st = run.attributes[s.StrikethroughStyleAttribute.self] { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue; if let c = st.color { attrs[.strikethroughColor] = c.uiColor } }
        if let k = run.attributes[s.KerningAttribute.self] ?? run.attributes[s.TrackingAttribute.self] { attrs[.kern] = k }
        if let b = run.attributes[s.BaselineOffsetAttribute.self] { attrs[.baselineOffset] = b }
        if let url = run.attributes[AttributeScopes.FoundationAttributes.LinkAttribute.self] { attrs[.link] = url }
        out.append(NSAttributedString(string: String(a[run.range].characters), attributes: attrs))
    }
    return out
}
