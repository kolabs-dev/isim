// isim SwiftUI (iOS 18): TextSelection — the selection binding of `TextField(_:text:selection:prompt:axis:)` and
// `TextEditor(text:selection:)`, `TextSelectionAffinity` and `textSelectionAffinity(_:)`.
// Adapted: the binding follows the text view's selected range (UITextField's UITextInput selection; TextEditor with a
// selection is the attributed text editor over the string, AttributedEditor.swift) and moves it when set. The text
// views have one selection, so a multi-selection selects from its first range's start to its last range's end.
import UIKit

/// A selection in a string: a range (an insertion point when empty) or several ranges.
@available(iOS 18.0, *)
public struct TextSelection: Hashable, Sendable {
    public enum Indices: Hashable, Sendable {
        case selection(Range<String.Index>)
        case multiSelection(RangeSet<String.Index>)
    }
    public var indices: Indices
    /// Which side of a line break an insertion point is drawn on.
    public var affinity: TextSelectionAffinity = .automatic
    public init(range: Range<String.Index>) { indices = .selection(range) }
    public init(insertionPoint: String.Index) { indices = .selection(insertionPoint..<insertionPoint) }
    public init(ranges: RangeSet<String.Index>) { indices = .multiSelection(ranges) }
    /// Whether the selection is an insertion point (no characters).
    public var isInsertion: Bool {
        switch indices {
        case .selection(let r): return r.isEmpty
        case .multiSelection(let rs): return rs.isEmpty
        }
    }
    /// The selection as character offsets in `text` (one span).
    func _offsets(in text: String) -> Range<Int> {
        let r: Range<String.Index>
        switch indices {
        case .selection(let s): r = s
        case .multiSelection(let rs):
            guard let f = rs.ranges.first, let l = rs.ranges.last else { return text.count..<text.count }
            r = f.lowerBound..<l.upperBound
        }
        func offset(_ i: String.Index) -> Int { text.distance(from: text.startIndex, to: min(max(i, text.startIndex), text.endIndex)) }
        return offset(r.lowerBound)..<max(offset(r.lowerBound), offset(r.upperBound))
    }
    init(_offsets o: Range<Int>, in text: String) {
        let n = text.count
        let lo = text.index(text.startIndex, offsetBy: min(o.lowerBound, n)), hi = text.index(text.startIndex, offsetBy: min(o.upperBound, n))
        self.init(range: lo..<hi)
    }
}

/// Which side of a line break an insertion point at it is on.
public enum TextSelectionAffinity: Hashable, Sendable {
    case automatic, upstream, downstream
}

struct _TextSelectionAffinityKey: EnvironmentKey { static var defaultValue: TextSelectionAffinity { .automatic } }
extension EnvironmentValues {
    /// The affinity of insertion points in this environment's text views.
    public var textSelectionAffinity: TextSelectionAffinity {
        get { self[_TextSelectionAffinityKey.self] }
        set { self[_TextSelectionAffinityKey.self] = newValue }
    }
}
extension View {
    /// Sets the affinity of insertion points (isim: recorded; its text views draw an insertion point at a line break
    /// at the start of the next line).
    public func textSelectionAffinity(_ affinity: TextSelectionAffinity) -> some View { environment(\.textSelectionAffinity, affinity) }
}

// MARK: - TextField and TextEditor with a selection

/// A selection binding, type-erased (the text fields' stored properties predate iOS 18): character offsets.
typealias _TextSelectionLink = _AnySelection

@available(iOS 18.0, *)
func _selectionLink(_ selection: Binding<TextSelection?>, text: Binding<String>) -> _TextSelectionLink {
    _AnySelection(get: { selection.wrappedValue?._offsets(in: text.wrappedValue) },
                  set: { o in
                      let s = TextSelection(_offsets: o, in: text.wrappedValue)
                      if selection.wrappedValue?._offsets(in: text.wrappedValue) != o { selection.wrappedValue = s }
                  })
}

extension TextField where Label == Text {
    @available(iOS 18.0, *)
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, selection: Binding<TextSelection?>, prompt: Text? = nil, axis: Axis? = nil) {
        self.init(placeholder: prompt?.string ?? titleKey.resolved(), text: text, axis: axis ?? .horizontal, secure: false)
        _selection = _selectionLink(selection, text: text)
    }
    @available(iOS 18.0, *)
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, selection: Binding<TextSelection?>, prompt: Text? = nil, axis: Axis? = nil) {
        self.init(placeholder: prompt?.string ?? String(title), text: text, axis: axis ?? .horizontal, secure: false)
        _selection = _selectionLink(selection, text: text)
    }
}
extension TextField {
    @available(iOS 18.0, *)
    public init(text: Binding<String>, selection: Binding<TextSelection?>, prompt: Text? = nil, axis: Axis? = nil, @ViewBuilder label: () -> Label) {
        self.init(placeholder: prompt?.string ?? "", text: text, axis: axis ?? .horizontal, secure: false)
        _selection = _selectionLink(selection, text: text)
    }
}

extension TextEditor {
    /// Plain text with a selection binding (isim: edited in the attributed text editor over the string).
    @available(iOS 18.0, *)
    public init(text: Binding<String>, selection: Binding<TextSelection?>) {
        self.text = text
        attributed = Binding(get: { AttributedString(text.wrappedValue) }, set: { text.wrappedValue = String($0.characters) })
        let link = _selectionLink(selection, text: text)
        self.selection = Binding(get: { link }, set: { _ in })
    }
}

/// Keeps a UITextField's selection and a selection link in step (Views.swift's _TextFieldNode).
@MainActor func _syncFieldSelection(_ f: UITextField, _ link: _TextSelectionLink?, text: String) {
    guard let link, let o = link.get(), let r = _utf16Range(o, in: text) else { return }
    let cur = f.selectedTextRange.map { NSRange(location: f.offset(from: f.beginningOfDocument, to: $0.start), length: f.offset(from: $0.start, to: $0.end)) }
    guard cur != r, let a = f.position(from: f.beginningOfDocument, offset: r.location), let b = f.position(from: a, offset: r.length) else { return }
    f.selectedTextRange = f.textRange(from: a, to: b)
}
@MainActor func _fieldSelectionChanged(_ f: UITextField, _ link: _TextSelectionLink?) {
    guard let link, let sel = f.selectedTextRange else { return }
    let t = f.text ?? ""
    let lo = f.offset(from: f.beginningOfDocument, to: sel.start), len = f.offset(from: sel.start, to: sel.end)
    guard let r = Range(NSRange(location: lo, length: len), in: t) else { return }
    let o = t.distance(from: t.startIndex, to: r.lowerBound)..<t.distance(from: t.startIndex, to: r.upperBound)
    if link.get() != o { link.set(o) }
}
