// isim SwiftUI: primitive views and value types.
import UIKit

// MARK: - Geometry types

public enum Axis: Int8, CaseIterable, Sendable {
    case horizontal, vertical
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let horizontal = Set(rawValue: 1), vertical = Set(rawValue: 2)
    }
}
public enum Edge: Int8, CaseIterable, Sendable {
    case top, leading, bottom, trailing
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public init(_ e: Edge) { self.rawValue = 1 << e.rawValue }
        public static let top = Set(.top), leading = Set(.leading), bottom = Set(.bottom), trailing = Set(.trailing)
        public static let all: Set = [.top, .leading, .bottom, .trailing]
        public static let horizontal: Set = [.leading, .trailing], vertical: Set = [.top, .bottom]
    }
}
public struct EdgeInsets: Equatable, Sendable {
    public var top, leading, bottom, trailing: CGFloat
    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top; self.leading = leading; self.bottom = bottom; self.trailing = trailing
    }
}
public struct HorizontalAlignment: Equatable, Sendable {
    let id: Int
    public static let leading = HorizontalAlignment(id: 0), center = HorizontalAlignment(id: 1), trailing = HorizontalAlignment(id: 2)
    public static let listRowSeparatorLeading = HorizontalAlignment(id: 0), listRowSeparatorTrailing = HorizontalAlignment(id: 2)
}
public struct VerticalAlignment: Equatable, Sendable {
    let id: Int
    public static let top = VerticalAlignment(id: 0), center = VerticalAlignment(id: 1), bottom = VerticalAlignment(id: 2)
    public static let firstTextBaseline = VerticalAlignment(id: 0), lastTextBaseline = VerticalAlignment(id: 2)
}
public struct Alignment: Equatable, Sendable {
    public var horizontal: HorizontalAlignment
    public var vertical: VerticalAlignment
    public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) { self.horizontal = horizontal; self.vertical = vertical }
    public static let center = Alignment(horizontal: .center, vertical: .center)
    public static let leading = Alignment(horizontal: .leading, vertical: .center)
    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)
    public static let top = Alignment(horizontal: .center, vertical: .top)
    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)
    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)
    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)
    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}
public enum TextAlignment: Hashable, CaseIterable, Sendable { case leading, center, trailing }

// MARK: - Color & styles

public protocol ShapeStyle {}

public struct Color: View, ShapeStyle, Hashable, CustomStringConvertible, _PrimitiveView {
    let provider: _ColorProvider
    final class _ColorProvider: Hashable {
        let make: () -> UIColor; let name: String
        init(_ name: String, _ make: @escaping () -> UIColor) { self.name = name; self.make = make }
        static func == (a: _ColorProvider, b: _ColorProvider) -> Bool { a === b || a.name == b.name }
        func hash(into h: inout Hasher) { h.combine(name) }
    }
    init(_ name: String, _ make: @escaping () -> UIColor) { provider = _ColorProvider(name, make) }
    public init(uiColor: UIColor) { provider = _ColorProvider("\(ObjectIdentifier(uiColor))") { uiColor } }
    public init(_ uiColor: UIColor) { self.init(uiColor: uiColor) }
    public init(_ name: String, bundle: Bundle? = nil) {
        provider = _ColorProvider("named:" + name) { UIColor(named: name, in: bundle, compatibleWith: nil) ?? .systemPink }
    }
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        provider = _ColorProvider("rgb\(red),\(green),\(blue),\(opacity)") { UIColor(red: red, green: green, blue: blue, alpha: opacity) }
    }
    public init(white: Double, opacity: Double = 1) { provider = _ColorProvider("w\(white),\(opacity)") { UIColor(white: white, alpha: opacity) } }
    public enum RGBColorSpace: Hashable, Sendable { case sRGB, sRGBLinear, displayP3 }
    public init(_ space: RGBColorSpace, red: Double, green: Double, blue: Double, opacity: Double = 1) { self.init(red: red, green: green, blue: blue, opacity: opacity) }
    public init(_ space: RGBColorSpace, white: Double, opacity: Double = 1) { self.init(white: white, opacity: opacity) }
    public init(hue: Double, saturation: Double, brightness: Double, opacity: Double = 1) {
        provider = _ColorProvider("hsb\(hue),\(saturation),\(brightness),\(opacity)") { UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: opacity) }
    }
    public init(cgColor: CGColor) { self.init(uiColor: UIColor(cgColor: cgColor)) }
    public var uiColor: UIColor { provider.make() }
    public var description: String { provider.name }
    public func opacity(_ o: Double) -> Color { let base = self; return Color("\(provider.name)@\(o)") { base.uiColor.withAlphaComponent(o) } }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ColorNode(path: ctx.path, color: self) }

    public static let red = Color("red") { .systemRed }
    public static let orange = Color("orange") { .systemOrange }
    public static let yellow = Color("yellow") { .systemYellow }
    public static let green = Color("green") { .systemGreen }
    public static let mint = Color("mint") { .systemMint }
    public static let teal = Color("teal") { .systemTeal }
    public static let cyan = Color("cyan") { .systemCyan }
    public static let blue = Color("blue") { .systemBlue }
    public static let indigo = Color("indigo") { .systemIndigo }
    public static let purple = Color("purple") { .systemPurple }
    public static let pink = Color("pink") { .systemPink }
    public static let brown = Color("brown") { .systemBrown }
    public static let white = Color("white") { .white }
    public static let gray = Color("gray") { .systemGray }
    public static let black = Color("black") { .black }
    public static let clear = Color("clear") { .clear }
    public static let primary = Color("primary") { .label }
    public static let secondary = Color("secondary") { .secondaryLabel }
    public static var accentColor: Color { Color("accent") { _accentUIColor() } }
}
@MainActor func _accentUIColor() -> UIColor {
    if let name = Bundle.main.object(forInfoDictionaryKey: "ISIMGlobalAccentColorName") as? String, let c = UIColor(named: name) { return c }
    if let c = UIColor(named: "AccentColor") { return c }
    return .systemBlue
}

public struct HierarchicalShapeStyle: ShapeStyle, Sendable {
    let level: Int
    public static let primary = HierarchicalShapeStyle(level: 0), secondary = HierarchicalShapeStyle(level: 1)
    public static let tertiary = HierarchicalShapeStyle(level: 2), quaternary = HierarchicalShapeStyle(level: 3)
    var color: Color { [Color.primary, .secondary, Color("tertiary") { .tertiaryLabel }, Color("quaternary") { .quaternaryLabel }][level] }
}
public struct TintShapeStyle: ShapeStyle, Sendable { public init() {} }
/// A type-erased shape style.
public struct AnyShapeStyle: ShapeStyle {
    let base: any ShapeStyle
    public init<S: ShapeStyle>(_ style: S) { base = style }
}
extension ShapeStyle where Self == Color {
    public static var red: Color { Color.red }
    public static var orange: Color { Color.orange }
    public static var yellow: Color { Color.yellow }
    public static var green: Color { Color.green }
    public static var blue: Color { Color.blue }
    public static var purple: Color { Color.purple }
    public static var pink: Color { Color.pink }
    public static var gray: Color { Color.gray }
    public static var white: Color { Color.white }
    public static var black: Color { Color.black }
    public static var clear: Color { Color.clear }
    public static var accentColor: Color { Color.accentColor }
}
extension ShapeStyle where Self == HierarchicalShapeStyle {
    public static var primary: HierarchicalShapeStyle { HierarchicalShapeStyle.primary }
    public static var secondary: HierarchicalShapeStyle { HierarchicalShapeStyle.secondary }
    public static var tertiary: HierarchicalShapeStyle { HierarchicalShapeStyle.tertiary }
    public static var quaternary: HierarchicalShapeStyle { HierarchicalShapeStyle.quaternary }
}
extension ShapeStyle where Self == TintShapeStyle {
    public static var tint: TintShapeStyle { TintShapeStyle() }
}
@MainActor func _color(of style: any ShapeStyle, _ env: EnvironmentValues) -> Color {
    switch style {
    case let c as Color: return c
    case let h as HierarchicalShapeStyle:
        if h.level == 0 { return env._foreground ?? .primary }
        return h.color
    case is TintShapeStyle: return env._tint ?? .accentColor
    case let a as AnyShapeStyle: return _color(of: a.base, env)
    case let f as _ColorFallback: return f._fallbackColor(env)
    case is ForegroundStyle: return env._foreground ?? .primary
    default: return .primary
    }
}

// MARK: - Font

public struct Font: Hashable, Sendable {
    public enum TextStyle: CaseIterable, Sendable { case largeTitle, title, title2, title3, headline, subheadline, body, callout, footnote, caption, caption2 }
    public struct Weight: Hashable, Sendable {
        let value: CGFloat
        public static let ultraLight = Weight(value: -0.8), thin = Weight(value: -0.6), light = Weight(value: -0.4), regular = Weight(value: 0)
        public static let medium = Weight(value: 0.23), semibold = Weight(value: 0.3), bold = Weight(value: 0.4), heavy = Weight(value: 0.56), black = Weight(value: 0.62)
    }
    public enum Design: Hashable, Sendable { case `default`, serif, rounded, monospaced }
    var size: CGFloat
    var weight: Weight
    var design: Design = .default
    var isItalic = false
    var customName: String?
    var weightSet = false
    static func style(_ s: TextStyle) -> Font {
        switch s {
        case .largeTitle: return Font(size: 34, weight: .regular)
        case .title: return Font(size: 28, weight: .regular)
        case .title2: return Font(size: 22, weight: .regular)
        case .title3: return Font(size: 20, weight: .regular)
        case .headline: return Font(size: 17, weight: .semibold)
        case .subheadline: return Font(size: 15, weight: .regular)
        case .body: return Font(size: 17, weight: .regular)
        case .callout: return Font(size: 16, weight: .regular)
        case .footnote: return Font(size: 13, weight: .regular)
        case .caption: return Font(size: 12, weight: .regular)
        case .caption2: return Font(size: 11, weight: .regular)
        }
    }
    public static let largeTitle = style(.largeTitle), title = style(.title), title2 = style(.title2), title3 = style(.title3)
    public static let headline = style(.headline), subheadline = style(.subheadline), body = style(.body), callout = style(.callout)
    public static let footnote = style(.footnote), caption = style(.caption), caption2 = style(.caption2)
    public static func system(_ style: TextStyle, design: Design? = nil, weight: Weight? = nil) -> Font {
        var f = Font.style(style); if let d = design { f.design = d }; if let w = weight { f.weight = w }; return f
    }
    public static func system(size: CGFloat, weight: Weight? = nil, design: Design? = nil) -> Font {
        Font(size: size, weight: weight ?? .regular, design: design ?? .default)
    }
    public func bold() -> Font { var f = self; f.weight = .bold; f.weightSet = true; return f }
    public func weight(_ w: Weight) -> Font { var f = self; f.weight = w; f.weightSet = true; return f }
    /// A font by PostScript or family name (bundled with UIAppFonts or installed); falls back to the system font.
    public static func custom(_ name: String, size: CGFloat) -> Font { var f = Font(size: size, weight: .regular); f.customName = name; return f }
    public static func custom(_ name: String, size: CGFloat, relativeTo style: TextStyle) -> Font { custom(name, size: size) }
    public static func custom(_ name: String, fixedSize: CGFloat) -> Font { custom(name, size: fixedSize) }
    public func monospacedDigit() -> Font { self }
    public func leading(_ l: Leading) -> Font { self }
    public enum Leading: Sendable { case standard, tight, loose }
    public func width(_ w: Width) -> Font { self }
    public struct Width: Hashable, Sendable { let v: Double; public static let compressed = Width(v: -0.3), condensed = Width(v: -0.2), standard = Width(v: 0), expanded = Width(v: 0.2) }
    public func italic() -> Font { var f = self; f.isItalic = true; return f }
    public func monospaced() -> Font { var f = self; f.design = .monospaced; return f }
    static let weightNames: [(CGFloat, String)] = [(-0.8, "Thin"), (-0.6, "ExtraLight"), (-0.4, "Light"), (0, "Regular"), (0.23, "Medium"),
                                                   (0.3, "SemiBold"), (0.4, "Bold"), (0.56, "ExtraBold"), (0.62, "Black")]
    var uiFont: UIFont {
        if let name = customName {
            if weightSet, weight.value != 0, let wn = Font.weightNames.first(where: { $0.0 == weight.value })?.1 {
                let base = name.split(separator: "-").first.map(String.init) ?? name
                if let f = UIFont(name: "\(base)-\(wn)", size: size) { return f }
            }
            if let f = UIFont(name: name, size: size) { return f }
        }
        if design == .monospaced { return UIFont.monospacedSystemFont(ofSize: size, weight: UIFont.Weight(rawValue: weight.value)) }
        return UIFont.systemFont(ofSize: size, weight: UIFont.Weight(rawValue: weight.value))
    }
}

// MARK: - Localized strings

public struct LocalizedStringKey: Equatable, ExpressibleByStringInterpolation, Sendable {
    let key: String
    let arguments: [String]
    public init(_ value: String) { key = value; arguments = [] }
    public init(stringLiteral value: String) { key = value; arguments = [] }
    public init(stringInterpolation: StringInterpolation) { key = stringInterpolation.key; arguments = stringInterpolation.arguments }
    public struct StringInterpolation: StringInterpolationProtocol {
        var key = "", arguments: [String] = []
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ s: String) { key += s.replacingOccurrences(of: "%", with: "%%") }
        public mutating func appendInterpolation(_ s: String) { key += "%@"; arguments.append(s) }
        public mutating func appendInterpolation<T: BinaryInteger>(_ v: T) { key += "%lld"; arguments.append(String(v)) }
        public mutating func appendInterpolation<T>(_ v: T) { key += "%@"; arguments.append(String(describing: v)) }
    }
    func resolved(_ bundle: Bundle? = nil) -> String {
        let format = (bundle ?? .main).localizedString(forKey: key, value: nil, table: nil)
        return arguments.isEmpty ? format : _format(format, arguments)
    }
}
func _format(_ format: String, _ args: [String]) -> String {
    var out = "", argIndex = 0
    var i = format.startIndex
    while i < format.endIndex {
        let c = format[i]
        if c == "%", format.index(after: i) < format.endIndex {
            var j = format.index(after: i)
            if format[j] == "%" { out += "%"; i = format.index(after: j); continue }
            var digits = ""
            while j < format.endIndex, format[j].isNumber { digits.append(format[j]); j = format.index(after: j) }
            var position: Int? = nil
            if j < format.endIndex, format[j] == "$" { position = Int(digits).map { $0 - 1 }; j = format.index(after: j) }
            while j < format.endIndex, "lhqzt".contains(format[j]) { j = format.index(after: j) }
            if j < format.endIndex {
                let idx = position ?? argIndex
                if position == nil { argIndex += 1 }
                out += idx < args.count ? args[idx] : ""
                i = format.index(after: j); continue
            }
        }
        out.append(c); i = format.index(after: i)
    }
    return out
}

// MARK: - Text

public struct Text: View, Equatable, _PrimitiveView {
    enum Storage: Equatable { case verbatim(String), localized(LocalizedStringKey, Bundle?) }
    let storage: Storage
    var font: Font?
    var color: Color?
    var weight: Font.Weight?
    var italicFlag = false
    public init(verbatim content: String) { storage = .verbatim(content) }
    @_disfavoredOverload public init<S: StringProtocol>(_ content: S) { storage = .verbatim(String(content)) }
    public init(_ key: LocalizedStringKey, tableName: String? = nil, bundle: Bundle? = nil, comment: StaticString? = nil) { storage = .localized(key, bundle) }
    public static func == (a: Text, b: Text) -> Bool { a.storage == b.storage && a.font == b.font && a.color == b.color }
    var string: String {
        switch storage { case .verbatim(let s): return s; case .localized(let k, let b): return k.resolved(b) }
    }
    public func font(_ f: Font?) -> Text { var t = self; t.font = f; return t }
    public func foregroundColor(_ c: Color?) -> Text { var t = self; t.color = c; return t }
    public func foregroundStyle<S: ShapeStyle>(_ s: S) -> Text { var t = self; t.color = s as? Color ?? (s as? HierarchicalShapeStyle)?.color ?? (s as? _ColorFallback)?._fallbackColor(EnvironmentValues()); return t }
    public func bold(_ active: Bool = true) -> Text { var t = self; if active { t.weight = .bold }; return t }
    public func fontWeight(_ w: Font.Weight?) -> Text { var t = self; t.weight = w; return t }
    public func italic(_ active: Bool = true) -> Text { var t = self; t.italicFlag = active; return t }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        var f = font ?? ctx.environment.font ?? .body
        if let w = weight { f.weight = w }
        let color = self.color ?? ctx.environment._foreground ?? .primary
        let lines = ctx.environment._lineRange
        let shown = ctx.environment._sectionHeader ? string.uppercased() : string     // inset-grouped section headers
        return _TextNode(path: ctx.path, text: shown, font: f.uiFont, color: color.uiColor, minLines: lines.0, maxLines: lines.1,
                         alignment: ctx.environment.multilineTextAlignment)
    }
}

@MainActor let _measureLabel = UILabel()
final class _TextNode: _Node {
    let text: String, font: UIFont, color: UIColor, minLines: Int?, maxLines: Int?, alignment: TextAlignment
    init(path: String, text: String, font: UIFont, color: UIColor, minLines: Int?, maxLines: Int?, alignment: TextAlignment) {
        self.text = text; self.font = font; self.color = color; self.minLines = minLines; self.maxLines = maxLines; self.alignment = alignment
        super.init(path: path, children: [])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let l = _measureLabel
        l.text = text; l.font = font; l.numberOfLines = maxLines ?? 0
        let w = p.width ?? 1e6
        var s = l.sizeThatFits(CGSize(width: w >= 1e6 ? 0 : max(1, w), height: 1e6))
        if w < 1e6 {
            // the label is drawn at its own (measured) width: make that width wrap exactly like the measurement
            s.width = min(w, ceil(s.width) + 1)
            let again = l.sizeThatFits(CGSize(width: s.width, height: 1e6))
            s.height = max(s.height, again.height)
        }
        if let mn = minLines { s.height = max(s.height, CGFloat(mn) * ceil(font.lineHeight)) }
        return CGSize(width: ceil(s.width), height: ceil(s.height))
    }
    override func mountView(_ g: _Graph) -> UIView {
        let l = g.view(viewKey) { UILabel() }
        l.text = text; l.font = font; l.textColor = color; l.numberOfLines = maxLines ?? 0
        l.textAlignment = alignment == .center ? .center : alignment == .trailing ? .right : .left
        return l
    }
}

// MARK: - Image

public struct Image: View, _PrimitiveView {
    enum Source { case system(String), named(String, Bundle?), ui(UIImage) }
    let source: Source
    var isResizable = false
    var renderingMode: TemplateRenderingMode?
    var interpolationMode: Interpolation?
    public enum TemplateRenderingMode: Sendable { case template, original }
    public enum Scale: Sendable { case small, medium, large }
    public init(systemName: String) { source = .system(systemName) }
    public init(_ name: String, bundle: Bundle? = nil) { source = .named(name, bundle) }
    public init(uiImage: UIImage) { source = .ui(uiImage) }
    public func resizable() -> Image { var i = self; i.isResizable = true; return i }
    public func renderingMode(_ m: TemplateRenderingMode?) -> Image { var i = self; i.renderingMode = m; return i }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let font = (ctx.environment.font ?? .body).uiFont
        var img: UIImage?
        var template = false
        switch source {
        case .system(let n): img = UIImage(systemName: n, withConfiguration: UIImage.SymbolConfiguration(font: font)); template = true
        case .named(let n, _): img = UIImage(named: n)
        case .ui(let u): img = u
        }
        if renderingMode == .template { template = true } else if renderingMode == .original { template = false }
        let color = (ctx.environment._foreground ?? .primary).uiColor
        let node = _ImageNode(path: ctx.path, image: img, tint: template ? color : nil, resizable: isResizable)
        node.nearest = interpolationMode == Interpolation.none
        return node
    }
}
final class _ImageNode: _Node {
    let image: UIImage?, tint: UIColor?, resizable: Bool
    var nearest = false
    init(path: String, image: UIImage?, tint: UIColor?, resizable: Bool) {
        self.image = image; self.tint = tint; self.resizable = resizable; super.init(path: path, children: [])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let s = image?.size ?? .zero
        if resizable { return CGSize(width: p.width ?? s.width, height: p.height ?? s.height) }
        return s
    }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { UIImageView() }
        v.image = tint != nil ? image?.withRenderingMode(.alwaysTemplate) : image?.withRenderingMode(.alwaysOriginal)
        if let t = tint { v.tintColor = t }
        v.contentMode = resizable ? .scaleToFill : .center
        v.layer.magnificationFilter = nearest ? .nearest : .linear
        return v
    }
}

// MARK: - Stacks, Spacer, Divider

public struct VStack<Content: View>: View, _PrimitiveView {
    let alignment: HorizontalAlignment, spacing: CGFloat?, content: Content
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _StackNode(path: ctx.path, axis: .vertical, spacing: spacing, alignment: Alignment(horizontal: alignment, vertical: .center), children: [_resolve(content, ctx.child("c"))])
    }
}
public struct HStack<Content: View>: View, _PrimitiveView {
    let alignment: VerticalAlignment, spacing: CGFloat?, content: Content
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment; self.spacing = spacing; self.content = content()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _StackNode(path: ctx.path, axis: .horizontal, spacing: spacing, alignment: Alignment(horizontal: .center, vertical: alignment), children: [_resolve(content, ctx.child("c"))])
    }
}
public struct ZStack<Content: View>: View, _PrimitiveView {
    let alignment: Alignment, content: Content
    public init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) { self.alignment = alignment; self.content = content() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ZStackNode(path: ctx.path, alignment: alignment, children: [_resolve(content, ctx.child("c"))]) }
}
public struct Spacer: View, _PrimitiveView {
    let minLength: CGFloat?
    public init(minLength: CGFloat? = nil) { self.minLength = minLength }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _SpacerNode(path: ctx.path, minLength: minLength) }
}
public struct Divider: View, _PrimitiveView {
    public init() {}
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _DividerNode(path: ctx.path, children: []) }
}

// MARK: - Label

public struct Label<Title: View, Icon: View>: View, _PrimitiveView {
    let title: Title, icon: Icon
    public init(@ViewBuilder title: () -> Title, @ViewBuilder icon: () -> Icon) { self.title = title(); self.icon = icon() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        // in lists the icon is tinted and sits in a fixed-width column (UIKit list cell layout)
        let inList = ctx.environment._inList
        let iconCtx = inList ? ctx.child("icon").with { if $0._foreground == nil { $0._foreground = $0._tint ?? .accentColor } } : ctx.child("icon")
        let iconNode = _resolve(icon, iconCtx)
        let titleNode = _resolve(title, ctx.child("title"))
        let column: _Node
        if inList {
            let f = _FrameNode(path: ctx.path + "/iconframe", child: iconNode)
            f.width = 28
            column = f
        } else { column = iconNode }
        return _StackNode(path: ctx.path, axis: .horizontal, spacing: inList ? 14 : 8, alignment: .center, children: [column, titleNode])
    }
}
extension Label where Title == Text, Icon == Image {
    public init(_ titleKey: LocalizedStringKey, systemImage name: String) { self.init(title: { Text(titleKey) }, icon: { Image(systemName: name) }) }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage name: String) { self.init(title: { Text(title) }, icon: { Image(systemName: name) }) }
    public init(_ titleKey: LocalizedStringKey, image name: String) { self.init(title: { Text(titleKey) }, icon: { Image(name) }) }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, image name: String) { self.init(title: { Text(title) }, icon: { Image(name) }) }
}

// MARK: - Button & Link

public struct ButtonRole: Equatable, Sendable {
    let id: Int
    public static let destructive = ButtonRole(id: 1), cancel = ButtonRole(id: 2)
}

public struct Button<Label: View>: View, _PrimitiveView {
    let label: Label, action: () -> Void, role: ButtonRole?
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) { self.action = action; self.label = label(); self.role = nil }
    public init(role: ButtonRole?, action: @escaping () -> Void, @ViewBuilder label: () -> Label) { self.action = action; self.label = label(); self.role = role }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let env = ctx.environment
        let tint: Color = role == .destructive ? .red : (env._tint ?? .accentColor)
        if let style = env._buttonStyle, !env._inList {
            // custom ButtonStyle: the style draws the label; the pressed state lives in the graph
            let key = ctx.path + "#pressed"
            let g = ctx.graph
            let st = (g.storage[key] as? _StateStorage<Bool>) ?? { let x = _StateStorage(false); g.storage[key] = x; return x }()
            g.usedKeys.insert(key)
            let labelNode = _resolve(label, ctx.child("label").with { $0._buttonStyle = nil })
            let body = style.make(ButtonStyleConfiguration(role: role, label: .init(node: labelNode), isPressed: st.value))
            let bnode = _ButtonNode(path: ctx.path, child: _resolve(body, ctx.child("style").with { $0._buttonStyle = nil }), action: action, inList: false, enabled: env.isEnabled)
            bnode.role = role
            bnode.onPressed = { [weak g] p in if st.value != p { st.value = p; g?.invalidate() } }
            return bnode
        }
        let labelCtx = ctx.child("label").with { $0._foreground = $0._foreground ?? tint }
        let node = _resolve(label, labelCtx)
        let b = _ButtonNode(path: ctx.path, child: node, action: action, inList: env._inList, enabled: env.isEnabled)
        b.role = role
        return b
    }
}
extension Button where Label == Text {
    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) { self.init(action: action) { Text(titleKey) } }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, action: @escaping () -> Void) { self.init(action: action) { Text(title) } }
    public init(_ titleKey: LocalizedStringKey, role: ButtonRole?, action: @escaping () -> Void) { self.init(role: role, action: action) { Text(titleKey) } }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, role: ButtonRole?, action: @escaping () -> Void) { self.init(role: role, action: action) { Text(title) } }
}
extension Button where Label == SwiftUI.Label<Text, Image> {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) {
        self.init(action: action) { SwiftUI.Label(titleKey, systemImage: systemImage) }
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage: String, action: @escaping () -> Void) {
        self.init(action: action) { SwiftUI.Label(title, systemImage: systemImage) }
    }
    public init(_ titleKey: LocalizedStringKey, systemImage: String, role: ButtonRole?, action: @escaping () -> Void) {
        self.init(role: role, action: action) { SwiftUI.Label(titleKey, systemImage: systemImage) }
    }
}

final class _ButtonNode: _WrapperNode {
    let action: () -> Void, inList: Bool, enabled: Bool
    var role: ButtonRole?
    var onPressed: ((Bool) -> Void)?
    init(path: String, child: _Node, action: @escaping () -> Void, inList: Bool, enabled: Bool) {
        self.action = action; self.inList = inList; self.enabled = enabled
        super.init(path: path, child: child)
        rowAction = enabled ? action : nil
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        // a button that is a whole list row is handled by the row (full-width highlight); nested ones are controls
        let c = g.view(viewKey) { _SUIControl(frame: .zero) }
        c.action = action
        c.isEnabled = enabled
        c.onPressed = onPressed
        c.alpha = enabled || onPressed != nil ? 1 : 0.4
        return c
    }
}

/// Tappable container: dims while pressed, fires on touch up inside.
final class _SUIControl: UIControl {
    var action: (() -> Void)?
    /// set for custom button styles: they show the pressed state themselves
    var onPressed: ((Bool) -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(fire), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc func fire() { action?() }
    override var isHighlighted: Bool {
        didSet {
            if let p = onPressed { if isHighlighted != oldValue { p(isHighlighted) } }
            else { for s in subviews { s.alpha = isHighlighted ? 0.25 : 1 } }
        }
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled, self.point(inside: point, with: event) else { return nil }
        return self
    }
}

public struct Link<Label: View>: View, _PrimitiveView {
    let destination: URL, label: Label
    public init(destination: URL, @ViewBuilder label: () -> Label) { self.destination = destination; self.label = label() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let open = ctx.environment.openURL, url = destination
        let button = Button(action: { open(url) }, label: { label })
        return button._makeNode(ctx)
    }
}
extension Link where Label == Text {
    public init(_ titleKey: LocalizedStringKey, destination: URL) { self.init(destination: destination) { Text(titleKey) } }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, destination: URL) { self.init(destination: destination) { Text(title) } }
}

// MARK: - TextField

public struct TextInputAutocapitalization: Equatable, Sendable {
    let value: UITextAutocapitalizationType
    public static let never = TextInputAutocapitalization(value: .none), words = TextInputAutocapitalization(value: .words)
    public static let sentences = TextInputAutocapitalization(value: .sentences), characters = TextInputAutocapitalization(value: .allCharacters)
}
public struct SubmitLabel: Equatable, Sendable {
    let value: UIReturnKeyType
    public static let done = SubmitLabel(value: .done), go = SubmitLabel(value: .go), send = SubmitLabel(value: .send)
    public static let join = SubmitLabel(value: .join), route = SubmitLabel(value: .route), search = SubmitLabel(value: .search)
    public static let `return` = SubmitLabel(value: .default), next = SubmitLabel(value: .next), `continue` = SubmitLabel(value: .continue)
}

public struct TextField<Label: View>: View, _PrimitiveView {
    let placeholder: String, text: Binding<String>, axis: Axis, secure: Bool
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let env = ctx.environment
        return _TextFieldNode(path: ctx.path, placeholder: placeholder, text: text, axis: axis, secure: secure,
                              font: (env.font ?? .body).uiFont, traits: env._textTraits, lines: env._lineRange,
                              focus: ctx.graph.focusLink(for: ctx.path), inList: env._inList, graph: ctx.graph)
    }
}
extension TextField where Label == Text {
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>) { self.placeholder = titleKey.resolved(); self.text = text; self.axis = .horizontal; self.secure = false }
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, axis: Axis) { self.placeholder = titleKey.resolved(); self.text = text; self.axis = axis; self.secure = false }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>) { self.placeholder = String(title); self.text = text; self.axis = .horizontal; self.secure = false }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>, axis: Axis) { self.placeholder = String(title); self.text = text; self.axis = axis; self.secure = false }
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?) { self.init(titleKey, text: text) }
}
public struct SecureField<Label: View>: View, _PrimitiveView {
    let field: TextField<Label>
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { field._makeNode(ctx) }
}
extension SecureField where Label == Text {
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>) { field = TextField(placeholder: titleKey.resolved(), text: text, axis: .horizontal, secure: true) }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>) { field = TextField(placeholder: String(title), text: text, axis: .horizontal, secure: true) }
}

/// Connects a TextField position to a @FocusState binding (set by .focused()).
final class _FocusLink {
    let get: () -> Bool, set: (Bool) -> Void
    init(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) { self.get = get; self.set = set }
}

final class _TextFieldNode: _Node {
    let placeholder: String, text: Binding<String>, axis: Axis, secure: Bool, font: UIFont, traits: _TextTraits
    let lines: (Int?, Int?), focus: _FocusLink?, inList: Bool
    weak var graph: _Graph?
    init(path: String, placeholder: String, text: Binding<String>, axis: Axis, secure: Bool, font: UIFont, traits: _TextTraits,
         lines: (Int?, Int?), focus: _FocusLink?, inList: Bool, graph: _Graph) {
        self.placeholder = placeholder; self.text = text; self.axis = axis; self.secure = secure; self.font = font; self.traits = traits
        self.lines = lines; self.focus = focus; self.inList = inList; self.graph = graph
        super.init(path: path, children: [])
    }
    var minLines: Int { axis == .vertical ? (lines.0 ?? 1) : 1 }
    var maxLines: Int { axis == .vertical ? (lines.1 ?? 0) : 1 }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let w = min(p.width ?? 200, 1e6)
        let line = ceil(font.lineHeight)
        var h = line * CGFloat(minLines)
        if axis == .vertical {
            let l = _measureLabel
            l.text = text.wrappedValue.isEmpty ? placeholder : text.wrappedValue; l.font = font; l.numberOfLines = maxLines
            h = max(h, ceil(l.sizeThatFits(CGSize(width: w, height: 1e6)).height))
        }
        return CGSize(width: w, height: h)
    }
    override func mountView(_ g: _Graph) -> UIView {
        let f = g.view(viewKey) { _SUITextField(frame: .zero) }
        f.node = self
        if f.text != text.wrappedValue { f.text = text.wrappedValue }
        f.placeholder = placeholder
        f.font = font
        f.isSecureTextEntry = secure
        f.keyboardType = traits.keyboardType
        f.autocorrectionType = traits.autocorrectionDisabled ? UITextAutocorrectionType.no : UITextAutocorrectionType.default
        if let a = traits.autocapitalization { f.autocapitalizationType = a.value }
        f.returnKeyType = traits.submitLabel
        if axis == .vertical { f._isim_setLineLimitMin(minLines, max: maxLines) }
        if let focus = focus {
            let want = focus.get()
            g.postRender.append { [weak f] in
                guard let f = f else { return }
                if want && !f.isFirstResponder { _ = f.becomeFirstResponder() }
                else if !want && f.isFirstResponder { _ = f.resignFirstResponder() }
            }
        }
        return f
    }
}

final class _SUITextField: UITextField {
    var node: _TextFieldNode?
    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(changed), for: .editingChanged)
        addTarget(self, action: #selector(began), for: .editingDidBegin)
        addTarget(self, action: #selector(ended), for: .editingDidEnd)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc func changed() { node?.text.wrappedValue = text ?? "" }
    override func insertText(_ t: String) {
        if t == "\n", let n = node, n.axis != .vertical, let g = n.graph, let submit = g.submitAction(for: n.path) { submit(); return }
        super.insertText(t)
    }
    @objc func began() { if let f = node?.focus, !f.get() { f.set(true) } }
    @objc func ended() { if let f = node?.focus, f.get() { f.set(false) } }
}
