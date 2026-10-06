// isim SwiftUI: the parts of Text / TextField that sit on Foundation's FormatStyle and AttributedString —
// `Text(_:format:)`, `"\(value, format:)"` interpolation, `TextField(value:format:)`, `Text(AttributedString)` and the
// SwiftUI attribute scope (font, foregroundColor, backgroundColor, underline/strikethrough, kern, tracking,
// baselineOffset). Compiled only when isim's Foundation overlay provides those types (build-overlays.sh defines
// ISIM_FOUNDATION_FORMATSTYLE / ISIM_FOUNDATION_ATTRIBUTEDSTRING when it finds them).
import UIKit

#if ISIM_FOUNDATION_FORMATSTYLE
extension Text {
    public init<F: FormatStyle>(_ input: F.FormatInput, format: F) where F.FormatInput: Equatable, F.FormatOutput == String {
        self.init(verbatim: format.format(input))
    }
}
extension LocalizedStringKey.StringInterpolation {
    public mutating func appendInterpolation<F: FormatStyle>(_ input: F.FormatInput, format: F) where F.FormatInput: Equatable, F.FormatOutput == String {
        key += "%@"; arguments.append(format.format(input))
    }
}
extension TextField where Label == Text {
    /// Edits a value through a parseable format style: the text is parsed on commit (Return / focus loss).
    public init<F: ParseableFormatStyle>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil)
    where F.FormatOutput == String {
        self.init(titleKey.resolved(), _valueBinding: _formatBinding(value, format: format))
    }
    @_disfavoredOverload
    public init<S: StringProtocol, F: ParseableFormatStyle>(_ title: S, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil)
    where F.FormatOutput == String {
        self.init(String(title), _valueBinding: _formatBinding(value, format: format))
    }
}
func _formatBinding<F: ParseableFormatStyle>(_ value: Binding<F.FormatInput>, format: F) -> _ValueText where F.FormatOutput == String {
    _ValueText(display: { format.format(value.wrappedValue) }, commit: { s in
        guard let v = try? format.parseStrategy.parse(s) else { return false }
        value.wrappedValue = v; return true
    })
}
#endif

#if ISIM_FOUNDATION_ATTRIBUTEDSTRING
extension AttributeScopes {
    public var swiftUI: SwiftUIAttributes.Type { SwiftUIAttributes.self }
    public struct SwiftUIAttributes: AttributeScope {
        public let font: FontAttribute
        public let foregroundColor: ForegroundColorAttribute
        public let backgroundColor: BackgroundColorAttribute
        public let strikethroughStyle: StrikethroughStyleAttribute
        public let underlineStyle: UnderlineStyleAttribute
        public let kern: KerningAttribute
        public let tracking: TrackingAttribute
        public let baselineOffset: BaselineOffsetAttribute
        public let foundation: AttributeScopes.FoundationAttributes
        public enum FontAttribute: AttributedStringKey { public typealias Value = Font; public static let name = "SwiftUI.Font" }
        public enum ForegroundColorAttribute: AttributedStringKey { public typealias Value = Color; public static let name = "SwiftUI.ForegroundColor" }
        public enum BackgroundColorAttribute: AttributedStringKey { public typealias Value = Color; public static let name = "SwiftUI.BackgroundColor" }
        public enum StrikethroughStyleAttribute: AttributedStringKey { public typealias Value = Text.LineStyle; public static let name = "SwiftUI.StrikethroughStyle" }
        public enum UnderlineStyleAttribute: AttributedStringKey { public typealias Value = Text.LineStyle; public static let name = "SwiftUI.UnderlineStyle" }
        public enum KerningAttribute: AttributedStringKey { public typealias Value = CGFloat; public static let name = "SwiftUI.Kern" }
        public enum TrackingAttribute: AttributedStringKey { public typealias Value = CGFloat; public static let name = "SwiftUI.Tracking" }
        public enum BaselineOffsetAttribute: AttributedStringKey { public typealias Value = CGFloat; public static let name = "SwiftUI.BaselineOffset" }
    }
}
extension AttributeDynamicLookup {
    public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.SwiftUIAttributes, T>) -> T { self[T.self] }
}

extension Text {
    /// An attributed string: links, bold/italic/code/strikethrough presentation intents (from Markdown) and the
    /// SwiftUI attributes become text runs.
    public init(_ attributedContent: AttributedString) {
        let a = attributedContent
        var parts: [Text] = []
        for run in a.runs {
            var t = Text(verbatim: String(a[run.range].characters))
            t._x.markdown = false
            let s = AttributeScopes.SwiftUIAttributes.self
            if let f = run.attributes[s.FontAttribute.self] { t.font = f }
            if let c = run.attributes[s.ForegroundColorAttribute.self] { t.color = c }
            if let u = run.attributes[s.UnderlineStyleAttribute.self] { t._x.underline = _TextLine(active: true, color: u.color) }
            if let st = run.attributes[s.StrikethroughStyleAttribute.self] { t._x.strike = _TextLine(active: true, color: st.color) }
            if let k = run.attributes[s.KerningAttribute.self] ?? run.attributes[s.TrackingAttribute.self] { t._x.kerning = k }
            if let b = run.attributes[s.BaselineOffsetAttribute.self] { t._x.baseline = b }
            if let intent = run.attributes[AttributeScopes.FoundationAttributes.InlinePresentationIntentAttribute.self] {
                if intent.contains(.stronglyEmphasized) { t.weight = .bold }
                if intent.contains(.emphasized) { t.italicFlag = true }
                if intent.contains(.code) { t._x.design = .monospaced }
                if intent.contains(.strikethrough) { t._x.strike = _TextLine(active: true, color: nil) }
            }
            if let url = run.attributes[AttributeScopes.FoundationAttributes.LinkAttribute.self] { t._x.link = url }
            parts.append(t)
        }
        if parts.count == 1 { self = parts[0] } else { self.init(verbatim: ""); _x.parts = parts }
    }
}
#endif
