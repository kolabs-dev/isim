// isim SwiftUI: more controls and containers — TextEditor, TextField(value:formatter:), ProgressView (labels,
// `.linear` / `.circular` / custom ProgressViewStyle), Gauge (+ gaugeStyle), GroupBox, DisclosureGroup, OutlineGroup,
// ControlGroup, ContentUnavailableView, ShareLink (share sheet), PasteButton (no pasteboard on isim: disabled),
// AsyncImage (URLSession), `.controlSize`, `.buttonBorderShape`, PrimitiveButtonStyle.
// Most are composed from other SwiftUI views (adapted: drawn by isim, not UIKit's private controls).
import UIKit

// MARK: - TextEditor

/// Multi-line text editing that fills the space it is offered (a vertical TextField underneath).
public struct TextEditor: View {
    let text: Binding<String>
    public init(text: Binding<String>) { self.text = text }
    public var body: some View {
        TextField("", text: text, axis: .vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - TextField(value:formatter:)

/// A value edited as text: shown formatted, parsed back on commit (Return or end of editing).
struct _ValueText {
    let display: () -> String
    let commit: (String) -> Bool
}
extension TextField where Label == Text {
    init(_ title: String, _valueBinding vt: _ValueText) {
        self.init(placeholder: title, text: Binding(get: vt.display, set: { _ in }), axis: .horizontal, secure: false)
        _commit = vt
    }
    /// `TextField("Amount", value: $amount, formatter: numberFormatter)` — NumberFormatter and DateFormatter values.
    public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Formatter, prompt: Text? = nil) {
        self.init(titleKey.resolved(), _valueBinding: _formatterBinding(value, formatter))
    }
    @_disfavoredOverload public init<S: StringProtocol, V>(_ title: S, value: Binding<V>, formatter: Formatter, prompt: Text? = nil) {
        self.init(String(title), _valueBinding: _formatterBinding(value, formatter))
    }
}
func _formatterBinding<V>(_ value: Binding<V>, _ formatter: Formatter) -> _ValueText {
    _ValueText(display: { formatter.string(for: value.wrappedValue as AnyObject) ?? "\(value.wrappedValue)" }, commit: { s in
        var parsed: Any?
        if let nf = formatter as? NumberFormatter, let n = nf.number(from: s) {
            switch V.self {
            case is Int.Type: parsed = n.integerValue
            case is Int?.Type: parsed = Optional(n.integerValue)
            case is Double.Type: parsed = n.doubleValue
            case is Double?.Type: parsed = Optional(n.doubleValue)
            case is Float.Type: parsed = n.floatValue
            case is CGFloat.Type: parsed = CGFloat(n.doubleValue)
            default: parsed = n
            }
        } else if let df = formatter as? DateFormatter, let d = df.date(from: s) { parsed = d }
        guard let p = parsed, let v = p as? V else { return false }
        value.wrappedValue = v
        return true
    })
}

// MARK: - ProgressView

public struct ProgressView<Label: View, CurrentValueLabel: View>: View, _PrimitiveView {
    let value: Double?, total: Double
    let label: Label?, currentValueLabel: CurrentValueLabel?
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let fraction = value.map { min(1, max(0, $0 / max(total, .ulpOfOne))) }
        let env = ctx.environment
        if let style = env._progressStyle.custom {
            let config = ProgressViewStyleConfiguration(fractionCompleted: fraction, label: label.map { .init(node: _resolve($0, ctx.child("label"))) },
                                                        currentValueLabel: currentValueLabel.map { .init(node: _resolve($0, ctx.child("cvl"))) })
            return _resolve(style(config), ctx.child("style").with { $0._progressStyle = _ProgressStyleBox() })
        }
        let circular = env._progressStyle.kind == 2 || (env._progressStyle.kind == 0 && fraction == nil)
        let bar = _ProgressNode(path: ctx.path + "/bar", fraction: circular ? nil : (fraction ?? 0), tint: (env._tint ?? .accentColor).uiColor)
        let l = label.map { _resolve($0, ctx.child("label")) }.flatMap { _collectText($0).isEmpty && !($0 is _ImageNode) ? nil : $0 }
        let cv = currentValueLabel.map { _resolve($0, ctx.child("cvl").with { $0.font = $0.font ?? .footnote; $0._foreground = $0._foreground ?? .secondary }) }
        if l == nil && cv == nil { return bar }
        if circular {
            return _StackNode(path: ctx.path, axis: .vertical, spacing: 8, alignment: .center,
                              children: [bar] + [l].compactMap { $0 })
        }
        return _StackNode(path: ctx.path, axis: .vertical, spacing: 6, alignment: .leading, children: [l, bar, cv].compactMap { $0 })
    }
}
extension ProgressView where Label == EmptyView, CurrentValueLabel == EmptyView {
    public init() { value = nil; total = 1; label = nil; currentValueLabel = nil }
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0) { self.value = value.map(Double.init); self.total = Double(total); label = nil; currentValueLabel = nil }
    /// Progress through a time interval (re-rendered every second while shown).
    public init(timerInterval: ClosedRange<Date>, countsDown: Bool = true) {
        let span = timerInterval.upperBound.timeIntervalSince(timerInterval.lowerBound)
        let done = min(max(Date().timeIntervalSince(timerInterval.lowerBound), 0), span)
        self.value = countsDown ? span - done : done; self.total = max(span, 1); label = nil; currentValueLabel = nil
    }
}
extension ProgressView where CurrentValueLabel == EmptyView {
    public init(@ViewBuilder label: () -> Label) { value = nil; total = 1; self.label = label(); currentValueLabel = nil }
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0, @ViewBuilder label: () -> Label) {
        self.value = value.map(Double.init); self.total = Double(total); self.label = label(); currentValueLabel = nil
    }
}
extension ProgressView {
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {
        self.value = value.map(Double.init); self.total = Double(total); self.label = label(); self.currentValueLabel = currentValueLabel()
    }
    public init(_ configuration: ProgressViewStyleConfiguration) where Label == ProgressViewStyleConfiguration.Label, CurrentValueLabel == ProgressViewStyleConfiguration.CurrentValueLabel {
        value = configuration.fractionCompleted; total = 1; label = configuration.label; currentValueLabel = configuration.currentValueLabel
    }
}
extension ProgressView where Label == Text, CurrentValueLabel == EmptyView {
    public init(_ titleKey: LocalizedStringKey) { value = nil; total = 1; label = Text(titleKey); currentValueLabel = nil }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S) { value = nil; total = 1; label = Text(title); currentValueLabel = nil }
    public init<V: BinaryFloatingPoint>(_ titleKey: LocalizedStringKey, value: V?, total: V = 1.0) {
        self.value = value.map(Double.init); self.total = Double(total); label = Text(titleKey); currentValueLabel = nil
    }
    @_disfavoredOverload public init<S: StringProtocol, V: BinaryFloatingPoint>(_ title: S, value: V?, total: V = 1.0) {
        self.value = value.map(Double.init); self.total = Double(total); label = Text(title); currentValueLabel = nil
    }
}
final class _ProgressNode: _Node {
    let fraction: Double?, tint: UIColor
    init(path: String, fraction: Double?, tint: UIColor) { self.fraction = fraction; self.tint = tint; super.init(path: path, children: []) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        fraction == nil ? CGSize(width: 20, height: 20) : CGSize(width: min(p.width ?? 100, 1e6), height: 4)
    }
    override func mountView(_ g: _Graph) -> UIView {
        if let f = fraction {                                  // determinate: UIProgressView
            let v = g.view(viewKey + "/bar") { UIProgressView(progressViewStyle: .default) }
            v.progress = Float(f); v.progressTintColor = tint
            return v
        }
        let v = g.view(viewKey + "/spin") { UIActivityIndicatorView(style: .medium) }   // indeterminate: spinning
        if !v.isAnimating { v.startAnimating() }
        return v
    }
}

public struct ProgressViewStyleConfiguration {
    public struct Label: View, _PrimitiveView { let node: _Node; public var body: Never { fatalError() }; func _makeNode(_ ctx: _Context) -> _Node { node } }
    public struct CurrentValueLabel: View, _PrimitiveView { let node: _Node; public var body: Never { fatalError() }; func _makeNode(_ ctx: _Context) -> _Node { node } }
    public let fractionCompleted: Double?
    public var label: Label?
    public var currentValueLabel: CurrentValueLabel?
}
public protocol ProgressViewStyle {
    associatedtype Body: View
    typealias Configuration = ProgressViewStyleConfiguration
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body
}
public struct DefaultProgressViewStyle: ProgressViewStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { ProgressView(configuration).progressViewStyle(_KindStyle(kind: 0)) }
}
public struct LinearProgressViewStyle: ProgressViewStyle {
    public init() {}
    public init(tint: Color) {}
    public func makeBody(configuration: Configuration) -> some View { ProgressView(configuration).progressViewStyle(_KindStyle(kind: 1)) }
}
public struct CircularProgressViewStyle: ProgressViewStyle {
    public init() {}
    public init(tint: Color) {}
    public func makeBody(configuration: Configuration) -> some View { ProgressView(configuration).progressViewStyle(_KindStyle(kind: 2)) }
}
struct _KindStyle: ProgressViewStyle { let kind: Int; func makeBody(configuration: Configuration) -> some View { EmptyView() } }
extension ProgressViewStyle where Self == DefaultProgressViewStyle { public static var automatic: DefaultProgressViewStyle { .init() } }
extension ProgressViewStyle where Self == LinearProgressViewStyle { public static var linear: LinearProgressViewStyle { .init() } }
extension ProgressViewStyle where Self == CircularProgressViewStyle { public static var circular: CircularProgressViewStyle { .init() } }
struct _ProgressStyleBox { var kind = 0; var custom: (@MainActor (ProgressViewStyleConfiguration) -> any View)? = nil }
struct _ProgressStyleKey: EnvironmentKey { static var defaultValue: _ProgressStyleBox { _ProgressStyleBox() } }
extension EnvironmentValues { var _progressStyle: _ProgressStyleBox { get { self[_ProgressStyleKey.self] } set { self[_ProgressStyleKey.self] = newValue } } }
extension View {
    public func progressViewStyle<S: ProgressViewStyle>(_ style: S) -> some View {
        let box: _ProgressStyleBox
        switch style {
        case let k as _KindStyle: box = _ProgressStyleBox(kind: k.kind)
        case is DefaultProgressViewStyle: box = _ProgressStyleBox(kind: 0)
        case is LinearProgressViewStyle: box = _ProgressStyleBox(kind: 1)
        case is CircularProgressViewStyle: box = _ProgressStyleBox(kind: 2)
        default: box = _ProgressStyleBox(kind: 0, custom: { style.makeBody(configuration: $0) })
        }
        return _env { $0._progressStyle = box }
    }
}

// MARK: - Gauge

public struct Gauge<Label: View, CurrentValueLabel: View, BoundsLabel: View, MarkedValueLabels: View>: View {
    let fraction: Double
    let label: Label, current: CurrentValueLabel?, minLabel: BoundsLabel?, maxLabel: BoundsLabel?
    @Environment(\._gaugeStyle) var style
    @Environment(\._tint) var tint
    public init<V: BinaryFloatingPoint>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label,
                                        @ViewBuilder currentValueLabel: () -> CurrentValueLabel,
                                        @ViewBuilder minimumValueLabel: () -> BoundsLabel, @ViewBuilder maximumValueLabel: () -> BoundsLabel)
    where MarkedValueLabels == EmptyView {
        fraction = Gauge._fraction(value, bounds); self.label = label(); current = currentValueLabel(); minLabel = minimumValueLabel(); maxLabel = maximumValueLabel()
    }
    static func _fraction<V: BinaryFloatingPoint>(_ v: V, _ b: ClosedRange<V>) -> Double {
        let span = Double(b.upperBound - b.lowerBound)
        return span > 0 ? min(1, max(0, Double(v - b.lowerBound) / span)) : 0
    }
    public var body: some View {
        let config = GaugeStyleConfiguration(value: fraction, label: .init(view: AnyView(label)),
                                             currentValueLabel: current.map { .init(view: AnyView($0)) },
                                             minimumValueLabel: minLabel.map { .init(view: AnyView($0)) },
                                             maximumValueLabel: maxLabel.map { .init(view: AnyView($0)) })
        let t = tint ?? .accentColor
        switch style.kind {
        case .custom(let make): AnyView(make(config))
        case .circular(let capacity): AnyView(_CircularGauge(config: config, capacity: capacity, tint: t))
        case .linear(let capacity): AnyView(_LinearGauge(config: config, capacity: capacity, tint: t))
        }
    }
}
extension Gauge where CurrentValueLabel == EmptyView, BoundsLabel == EmptyView, MarkedValueLabels == EmptyView {
    public init<V: BinaryFloatingPoint>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label) {
        fraction = Gauge._fraction(value, bounds); self.label = label(); current = nil; minLabel = nil; maxLabel = nil
    }
}
extension Gauge where BoundsLabel == EmptyView, MarkedValueLabels == EmptyView {
    public init<V: BinaryFloatingPoint>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {
        fraction = Gauge._fraction(value, bounds); self.label = label(); current = currentValueLabel(); minLabel = nil; maxLabel = nil
    }
}
public struct GaugeStyleConfiguration {
    public struct Label: View { let view: AnyView; public var body: some View { view } }
    public struct CurrentValueLabel: View { let view: AnyView; public var body: some View { view } }
    public struct MinimumValueLabel: View { let view: AnyView; public var body: some View { view } }
    public struct MaximumValueLabel: View { let view: AnyView; public var body: some View { view } }
    public var value: Double
    public var label: Label
    public var currentValueLabel: CurrentValueLabel?
    public var minimumValueLabel: MinimumValueLabel?
    public var maximumValueLabel: MaximumValueLabel?
    init(value: Double, label: Label, currentValueLabel: CurrentValueLabel?, minimumValueLabel: MinimumValueLabel?, maximumValueLabel: MaximumValueLabel?) {
        self.value = value; self.label = label; self.currentValueLabel = currentValueLabel
        self.minimumValueLabel = minimumValueLabel; self.maximumValueLabel = maximumValueLabel
    }
}
public protocol GaugeStyle {
    associatedtype Body: View
    typealias Configuration = GaugeStyleConfiguration
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body
}
public struct DefaultGaugeStyle: GaugeStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct LinearCapacityGaugeStyle: GaugeStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct AccessoryLinearGaugeStyle: GaugeStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct AccessoryLinearCapacityGaugeStyle: GaugeStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct AccessoryCircularGaugeStyle: GaugeStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct AccessoryCircularCapacityGaugeStyle: GaugeStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
extension GaugeStyle where Self == DefaultGaugeStyle { public static var automatic: DefaultGaugeStyle { .init() } }
extension GaugeStyle where Self == LinearCapacityGaugeStyle { public static var linearCapacity: LinearCapacityGaugeStyle { .init() } }
extension GaugeStyle where Self == AccessoryLinearGaugeStyle { public static var accessoryLinear: AccessoryLinearGaugeStyle { .init() } }
extension GaugeStyle where Self == AccessoryLinearCapacityGaugeStyle { public static var accessoryLinearCapacity: AccessoryLinearCapacityGaugeStyle { .init() } }
extension GaugeStyle where Self == AccessoryCircularGaugeStyle { public static var accessoryCircular: AccessoryCircularGaugeStyle { .init() } }
extension GaugeStyle where Self == AccessoryCircularCapacityGaugeStyle { public static var accessoryCircularCapacity: AccessoryCircularCapacityGaugeStyle { .init() } }
struct _GaugeStyleBox {
    enum Kind { case linear(capacity: Bool), circular(capacity: Bool), custom(@MainActor (GaugeStyleConfiguration) -> any View) }
    var kind: Kind = .linear(capacity: true)
}
struct _GaugeStyleKey: EnvironmentKey { static var defaultValue: _GaugeStyleBox { _GaugeStyleBox() } }
extension EnvironmentValues { var _gaugeStyle: _GaugeStyleBox { get { self[_GaugeStyleKey.self] } set { self[_GaugeStyleKey.self] = newValue } } }
extension View {
    public func gaugeStyle<S: GaugeStyle>(_ style: S) -> some View {
        let k: _GaugeStyleBox.Kind
        switch style {
        case is DefaultGaugeStyle, is LinearCapacityGaugeStyle, is AccessoryLinearCapacityGaugeStyle: k = .linear(capacity: true)
        case is AccessoryLinearGaugeStyle: k = .linear(capacity: false)
        case is AccessoryCircularGaugeStyle: k = .circular(capacity: false)
        case is AccessoryCircularCapacityGaugeStyle: k = .circular(capacity: true)
        default: k = .custom({ style.makeBody(configuration: $0) })
        }
        return _env { $0._gaugeStyle = _GaugeStyleBox(kind: k) }
    }
}
/// Track with a filled capacity bar (or a marker dot for `.accessoryLinear`), label above, bounds at the ends.
struct _LinearGauge: View {
    let config: GaugeStyleConfiguration, capacity: Bool, tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { config.label; Spacer(); config.currentValueLabel.foregroundStyle(.secondary) }
            HStack(spacing: 6) {
                config.minimumValueLabel.font(.caption).foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color("gauge-track") { .systemFill }).frame(width: geo.size.width, height: 6)
                        if capacity {
                            Capsule().fill(tint).frame(width: max(6, geo.size.width * config.value), height: 6).accessibilityIdentifier("gauge-fill")
                        } else {
                            Circle().fill(tint).frame(width: 10, height: 10).offset(x: (geo.size.width - 10) * config.value).accessibilityIdentifier("gauge-fill")
                        }
                    }.frame(height: 10)
                }.frame(height: 10)
                config.maximumValueLabel.font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
/// A 270° ring (open at the bottom) with a fill arc or a marker, the current value in the middle.
struct _CircularGauge: View {
    let config: GaugeStyleConfiguration, capacity: Bool, tint: Color
    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: capacity ? 1 : 0.75).stroke(Color("gauge-track") { .systemFill }, lineWidth: 6)
                .rotationEffect(.degrees(capacity ? -90 : 135))
            Circle().trim(from: 0, to: (capacity ? 1 : 0.75) * config.value).stroke(tint, lineWidth: 6)
                .rotationEffect(.degrees(capacity ? -90 : 135)).accessibilityIdentifier("gauge-arc")
            VStack(spacing: 0) {
                config.currentValueLabel.font(.system(size: 15, weight: .semibold))
                if !capacity { config.label.font(.caption2).foregroundStyle(.secondary) }
            }
        }
        .frame(width: 58, height: 58)
    }
}

// MARK: - GroupBox, ControlGroup, ContentUnavailableView

public struct GroupBox<Label: View, Content: View>: View {
    let label: Label?, content: Content
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) { self.content = content(); self.label = label() }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label { label.font(.headline) }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color("groupbox") { .secondarySystemBackground }, in: RoundedRectangle(cornerRadius: 10))
    }
}
extension GroupBox where Label == EmptyView {
    public init(@ViewBuilder content: () -> Content) { self.content = content(); label = nil }
}
extension GroupBox where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.content = content(); label = Text(titleKey) }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) { self.content = content(); label = Text(title) }
}

/// Buttons side by side on one bordered background (iOS's control group).
public struct ControlGroup<Content: View>: View, _PrimitiveView {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public init<L: View>(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> L) { self.content = content() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        // each control gets an equal share of the row
        let items = _flatten([_resolve(content, ctx.child("c").with { $0._inList = false })]).enumerated().map { i, n -> _Node in
            let f = _FrameNode(path: ctx.path + "/cell\(i)", child: _PaddingNode(path: ctx.path + "/pad\(i)", insets: EdgeInsets(top: 8, bottom: 8), child: n))
            f.maxWidth = .infinity
            return f
        }
        let row = _StackNode(path: ctx.path + "/row", axis: .horizontal, spacing: 0, alignment: .center, children: items)
        return _BackgroundNode(path: ctx.path, color: nil, cornerRadius: 0,
                               background: _ShapeNode(path: ctx.path + "/bg", kind: .rounded(10), color: Color("control-group") { .tertiarySystemFill }), child: row)
    }
}
public protocol ControlGroupStyle {}
public struct AutomaticControlGroupStyle: ControlGroupStyle { public init() {} }
public struct NavigationControlGroupStyle: ControlGroupStyle { public init() {} }
public struct PaletteControlGroupStyle: ControlGroupStyle { public init() {} }
public struct CompactMenuControlGroupStyle: ControlGroupStyle { public init() {} }
extension ControlGroupStyle where Self == AutomaticControlGroupStyle { public static var automatic: AutomaticControlGroupStyle { .init() } }
extension ControlGroupStyle where Self == NavigationControlGroupStyle { public static var navigation: NavigationControlGroupStyle { .init() } }
extension ControlGroupStyle where Self == PaletteControlGroupStyle { public static var palette: PaletteControlGroupStyle { .init() } }
extension ControlGroupStyle where Self == CompactMenuControlGroupStyle { public static var compactMenu: CompactMenuControlGroupStyle { .init() } }
extension View { public func controlGroupStyle<S: ControlGroupStyle>(_ style: S) -> some View { self } }

public struct ContentUnavailableView<Label: View, Description: View, Actions: View>: View {
    let label: Label, description: Description?, actions: Actions?
    public init(@ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description = { EmptyView() }, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.label = label(); self.description = description(); self.actions = actions()
    }
    public var body: some View {
        VStack(spacing: 8) {
            label._verticalLabels()
            description.font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            actions.padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
struct _VerticalLabel {}
extension ContentUnavailableView where Label == SwiftUI.Label<Text, Image>, Description == Text?, Actions == EmptyView {
    public init(_ titleKey: LocalizedStringKey, systemImage name: String, description: Text? = nil) {
        self.label = SwiftUI.Label(titleKey, systemImage: name); self.description = description; actions = nil
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage name: String, description: Text? = nil) {
        self.label = SwiftUI.Label(title, systemImage: name); self.description = description; actions = nil
    }
}
extension ContentUnavailableView where Label == SwiftUI.Label<Text, Image>, Description == Text?, Actions == EmptyView {
    /// "No Results" (for an empty search).
    public static var search: ContentUnavailableView<SwiftUI.Label<Text, Image>, Text?, EmptyView> {
        ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("Check the spelling or try a new search."))
    }
    public static func search(text: String) -> ContentUnavailableView<SwiftUI.Label<Text, Image>, Text?, EmptyView> {
        ContentUnavailableView("No Results for “\(text)”", systemImage: "magnifyingglass", description: Text("Check the spelling or try a new search."))
    }
}
extension View {
    func _verticalLabels() -> some View {
        // ContentUnavailableView: a big icon above a bold title
        _env { $0._verticalLabel = true }
    }
}
struct _VerticalLabelKey: EnvironmentKey { static var defaultValue: Bool { false } }
extension EnvironmentValues { var _verticalLabel: Bool { get { self[_VerticalLabelKey.self] } set { self[_VerticalLabelKey.self] = newValue } } }

// MARK: - DisclosureGroup, OutlineGroup

/// A row with a chevron that shows or hides its content; in a List the content rows follow it as rows.
public struct DisclosureGroup<Label: View, Content: View>: View, _PrimitiveView {
    let label: Label, content: Content, isExpanded: Binding<Bool>?
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) { self.content = content(); self.label = label(); isExpanded = nil }
    public init(isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content(); self.label = label(); self.isExpanded = isExpanded
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let key = ctx.path + "#expanded", g = ctx.graph
        let st = (g.storage[key] as? _StateStorage<Bool>) ?? { let s = _StateStorage(false); g.storage[key] = s; return s }()
        g.usedKeys.insert(key)
        let binding = isExpanded ?? Binding(get: { st.value }, set: { [weak g] v in st.value = v; g?.invalidate() })
        let open = binding.wrappedValue
        let inList = ctx.environment._inList
        let tint = ctx.environment._tint ?? .accentColor
        let header = HStack {
            _NodeView(node: _resolve(label, ctx.child("label").with { $0._inList = inList }))
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(inList ? tint : tint).rotationEffect(.degrees(open ? 90 : 0))
        }
        let headerNode = _ButtonNode(path: ctx.path + "/header", child: _resolve(header.foregroundStyle(.primary), ctx.child("hdr")),
                                     action: { withAnimation(.easeInOut(duration: 0.2)) { binding.wrappedValue.toggle() } }, inList: inList, enabled: ctx.environment.isEnabled)
        guard open else { return inList ? _GroupNode(path: ctx.path, children: [headerNode]) : headerNode }
        let body = _resolve(content, ctx.child("content"))
        if inList {
            // content rows are indented under the header like iOS's outline rows
            let rows = _flatten([body]).enumerated().map { i, r in _PaddingNode(path: ctx.path + "/indent\(i)", insets: EdgeInsets(leading: 20), child: r) as _Node }
            return _GroupNode(path: ctx.path, children: [headerNode] + rows)
        }
        return _StackNode(path: ctx.path, axis: .vertical, spacing: 8, alignment: Alignment(horizontal: .leading, vertical: .center),
                          children: [headerNode, _PaddingNode(path: ctx.path + "/indent", insets: EdgeInsets(leading: 16), child: body)])
    }
}
extension DisclosureGroup where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.init(content: content) { Text(titleKey) } }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) { self.init(content: content) { Text(title) } }
    public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.init(isExpanded: isExpanded, content: content) { Text(titleKey) }
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.init(isExpanded: isExpanded, content: content) { Text(title) }
    }
}

/// A tree: items with children become disclosure groups (`OutlineGroup(data, children: \.children) { ... }`).
public struct OutlineGroup<Data: RandomAccessCollection, ID: Hashable, Parent: View, Leaf: View, Subgroup: View>: View, _PrimitiveView {
    let data: Data, id: (Data.Element) -> ID, children: (Data.Element) -> Data?, content: (Data.Element) -> Leaf
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _GroupNode(path: ctx.path, children: data.map { e in
            let row = AnyView(_OutlineNode(element: e, id: id, children: children, content: content))
            let n = _resolve(row, ctx.child("id:\(id(e))"))
            if n.tag == nil { n.tag = AnyHashable(id(e)) }
            return n
        })
    }
}
struct _OutlineNode<E, ID: Hashable, Leaf: View>: View {
    let element: E, id: (E) -> ID, children: (E) -> [E]?, content: (E) -> Leaf
    init<D: RandomAccessCollection>(element: E, id: @escaping (E) -> ID, children: @escaping (E) -> D?, content: @escaping (E) -> Leaf) where D.Element == E {
        self.element = element; self.id = id; self.children = { children($0).map(Array.init) }; self.content = content
    }
    init(element: E, id: @escaping (E) -> ID, children: @escaping (E) -> [E]?, content: @escaping (E) -> Leaf, _ plain: Void) {
        self.element = element; self.id = id; self.children = children; self.content = content
    }
    var body: some View {
        if let kids = children(element) {
            DisclosureGroup {
                ForEach(kids.indices, id: \.self) { i in
                    _OutlineNode(element: kids[i], id: id, children: children, content: content, ()).id(id(kids[i]))
                }
            } label: { content(element) }
        } else {
            content(element)
        }
    }
}
extension OutlineGroup where ID == Data.Element.ID, Parent == Leaf, Subgroup == DisclosureGroup<Parent, OutlineSubgroupChildren>, Data.Element: Identifiable {
    public init(_ data: Data, children: KeyPath<Data.Element, Data?>, @ViewBuilder content: @escaping (Data.Element) -> Leaf) {
        self.data = data; self.id = { $0.id }; self.children = { $0[keyPath: children] }; self.content = content
    }
}
extension OutlineGroup where Parent == Leaf, Subgroup == DisclosureGroup<Parent, OutlineSubgroupChildren> {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, children: KeyPath<Data.Element, Data?>, @ViewBuilder content: @escaping (Data.Element) -> Leaf) {
        self.data = data; self.id = { $0[keyPath: id] }; self.children = { $0[keyPath: children] }; self.content = content
    }
}
public struct OutlineSubgroupChildren: View { public var body: some View { EmptyView() } }
extension List where SelectionValue == Never {
    /// A hierarchical list: `List(items, children: \.children) { item in ... }`.
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, children: KeyPath<Data.Element, Data?>, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent)
    where Content == OutlineGroup<Data, Data.Element.ID, RowContent, RowContent, DisclosureGroup<RowContent, OutlineSubgroupChildren>>, Data.Element: Identifiable {
        self.init { OutlineGroup(data, children: children, content: rowContent) }
    }
}

// MARK: - ShareLink, PasteButton

/// Shows a share sheet with the item. isim has no other apps or share extensions to send it to; the sheet offers
/// the item and a Done button (and logs the share to the console).
public struct ShareLink<Label: View>: View {
    let item: String, subject: Text?, message: Text?, label: Label
    @State private var open = false
    public var body: some View {
        Button { print("isim: share \(item)"); open = true } label: { label }
            .sheet(isPresented: $open) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text("Share").font(.headline); Spacer(); Button("Done") { open = false }.accessibilityIdentifier("share-done") }
                    if let subject { subject.font(.subheadline.weight(.semibold)) }
                    Text(verbatim: item).accessibilityIdentifier("share-item")
                    if let message { message.foregroundStyle(.secondary) }
                    Text("No share destinations on isim").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                }.padding().presentationDetents([.medium])
            }
    }
}
extension ShareLink {
    public init(item: URL, subject: Text? = nil, message: Text? = nil, @ViewBuilder label: () -> Label) {
        self.item = item.absoluteString; self.subject = subject; self.message = message; self.label = label()
    }
    public init<S: StringProtocol>(item: S, subject: Text? = nil, message: Text? = nil, @ViewBuilder label: () -> Label) {
        self.item = String(item); self.subject = subject; self.message = message; self.label = label()
    }
}
extension ShareLink where Label == SwiftUI.Label<Text, Image> {
    public init(item: URL, subject: Text? = nil, message: Text? = nil) {
        self.init(item: item, subject: subject, message: message) { SwiftUI.Label("Share", systemImage: "square.and.arrow.up") }
    }
    @_disfavoredOverload public init<S: StringProtocol>(item: S, subject: Text? = nil, message: Text? = nil) {
        self.init(item: item, subject: subject, message: message) { SwiftUI.Label("Share", systemImage: "square.and.arrow.up") }
    }
    public init(_ titleKey: LocalizedStringKey, item: URL, subject: Text? = nil, message: Text? = nil) {
        self.init(item: item, subject: subject, message: message) { SwiftUI.Label(titleKey, systemImage: "square.and.arrow.up") }
    }
    @_disfavoredOverload public init<T: StringProtocol>(_ title: T, item: URL, subject: Text? = nil, message: Text? = nil) {
        self.init(item: item, subject: subject, message: message) { SwiftUI.Label(title, systemImage: "square.and.arrow.up") }
    }
}

/// Stub: isim has no pasteboard, so the Paste button is shown disabled and never delivers anything.
public struct PasteButton: View {
    public init<T>(payloadType: T.Type, onPaste: @escaping ([T]) -> Void) {}
    public init(supportedContentTypes: [Any], payloadAction: @escaping ([Any]) -> Void) {}
    public var body: some View {
        Button {} label: { SwiftUI.Label("Paste", systemImage: "doc.on.clipboard") }.disabled(true)
    }
}

// MARK: - AsyncImage

public enum AsyncImagePhase: Sendable {
    case empty
    case success(Image)
    case failure(Error)
    public var image: Image? { if case .success(let i) = self { return i }; return nil }
    public var error: Error? { if case .failure(let e) = self { return e }; return nil }
}
extension Image: @unchecked Sendable {}

final class _AsyncImageState: _AnyStorage {
    var url: URL?
    var phase: AsyncImagePhase = .empty
    var task: Task<Void, Never>?
    deinit { task?.cancel() }
}
struct _AsyncImageError: Error, CustomStringConvertible { let description: String }

/// Loads with URLSession (http(s), file and data URLs) and decodes with UIImage(data:scale:).
public struct AsyncImage<Content: View>: View, _PrimitiveView {
    let url: URL?, scale: CGFloat, make: @MainActor (AsyncImagePhase) -> AnyView
    var request: URLRequest? = nil            // iOS 27 request initializers
    public var body: Never { fatalError() }
    public init(url: URL?, scale: CGFloat = 1) where Content == Image {
        self.url = url; self.scale = scale
        make = { phase in phase.image.map { AnyView($0) } ?? AnyView(Color("async-placeholder") { .secondarySystemFill }) }
    }
    public init<I: View, P: View>(url: URL?, scale: CGFloat = 1, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P)
    where Content == _ConditionalContent<I, P> {
        self.url = url; self.scale = scale
        make = { phase in phase.image.map { AnyView(content($0)) } ?? AnyView(placeholder()) }
    }
    public init(url: URL?, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url; self.scale = scale
        make = { AnyView(content($0)) }
    }
    func _makeNode(_ ctx: _Context) -> _Node {
        let key = ctx.path + "#asyncimage", g = ctx.graph
        let st = (g.storage[key] as? _AsyncImageState) ?? { let s = _AsyncImageState(); g.storage[key] = s; return s }()
        g.usedKeys.insert(key)
        let session = ctx.environment._asyncImageSession ?? .shared, req = request
        if st.url != url {
            st.url = url; st.phase = .empty; st.task?.cancel()
            if let url {
                st.task = Task { @MainActor [weak st, weak g] in
                    let phase: AsyncImagePhase
                    do {
                        // asyncImageURLSession (iOS 27): the given session; AsyncImage(request:): the request
                        let (data, _) = try await session.data(for: req ?? URLRequest(url: url))
                        let img = UIImage(data: data, scale: scale)
                        phase = img.map { .success(Image(uiImage: $0)) } ?? .failure(_AsyncImageError(description: "isim: the data at \(url) is not an image"))
                    } catch { phase = .failure(error) }
                    guard let st, !Task.isCancelled, st.url == url else { return }
                    st.phase = phase
                    if case .success = phase { print("AsyncImage loaded \(url.lastPathComponent)") }
                    g?.invalidate()
                }
            }
        }
        return _resolve(make(st.phase), ctx.child("phase"))
    }
}

@available(iOS 27.0, *)
extension AsyncImage {
    /// Loads `request` (headers, cache policy) with the view's URL session (asyncImageURLSession).
    public init(request: URLRequest?, scale: CGFloat = 1) where Content == Image {
        self.init(url: request?.url, scale: scale); self.request = request
    }
    public init<I: View, P: View>(request: URLRequest?, scale: CGFloat = 1, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P)
    where Content == _ConditionalContent<I, P> {
        self.init(url: request?.url, scale: scale, content: content, placeholder: placeholder); self.request = request
    }
    public init(request: URLRequest?, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.init(url: request?.url, scale: scale, transaction: transaction, content: content); self.request = request
    }
}
struct _AsyncImageSessionKey: EnvironmentKey { static var defaultValue: URLSession? { nil } }
extension EnvironmentValues { var _asyncImageSession: URLSession? { get { self[_AsyncImageSessionKey.self] } set { self[_AsyncImageSessionKey.self] = newValue } } }

// MARK: - controlSize, buttonBorderShape, PrimitiveButtonStyle

public enum ControlSize: Hashable, CaseIterable, Sendable { case mini, small, regular, large, extraLarge }
public struct ButtonBorderShape: Equatable, Sendable {
    enum Kind: Equatable { case automatic, capsule, rounded(CGFloat?), circle }
    let kind: Kind
    public static let automatic = ButtonBorderShape(kind: .automatic), capsule = ButtonBorderShape(kind: .capsule)
    public static let roundedRectangle = ButtonBorderShape(kind: .rounded(nil)), circle = ButtonBorderShape(kind: .circle)
    public static func roundedRectangle(radius: CGFloat) -> ButtonBorderShape { ButtonBorderShape(kind: .rounded(radius)) }
}
struct _ControlSizeKey: EnvironmentKey { static var defaultValue: ControlSize { .regular } }
struct _BorderShapeKey: EnvironmentKey { static var defaultValue: ButtonBorderShape { .automatic } }
extension EnvironmentValues {
    public var controlSize: ControlSize { get { self[_ControlSizeKey.self] } set { self[_ControlSizeKey.self] = newValue } }
    var _buttonBorderShape: ButtonBorderShape { get { self[_BorderShapeKey.self] } set { self[_BorderShapeKey.self] = newValue } }
}
extension View {
    public func controlSize(_ size: ControlSize) -> some View { _env { $0.controlSize = size } }
    public func buttonBorderShape(_ shape: ButtonBorderShape) -> some View { _env { $0._buttonBorderShape = shape } }
}
/// The bordered button styles' body: padding by control size, background in the border shape.
struct _BorderedButtonBody: View {
    let configuration: ButtonStyleConfiguration, prominent: Bool
    @Environment(\.controlSize) var size
    @Environment(\._buttonBorderShape) var shape
    @Environment(\._tint) var tint
    var body: some View {
        let (h, v, r): (CGFloat, CGFloat, CGFloat) = {
            switch size {
            case .mini: return (8, 3, 6)
            case .small: return (10, 5, 7)
            case .regular: return (12, 7, 8)
            case .large: return (20, 14, 12)
            case .extraLarge: return (24, 17, 14)
            }
        }()
        let fill: Color = prominent ? (configuration.role == .destructive ? .red : (tint ?? .accentColor)) : Color("fill") { .tertiarySystemFill }
        let label = configuration.label
            .font(size == .large || size == .extraLarge ? .body.weight(prominent ? .semibold : .regular) : nil)
            .foregroundStyle(prominent ? Color.white : (configuration.role == .destructive ? .red : (tint ?? .accentColor)))
            .padding(.horizontal, shape.kind == .circle ? v : h).padding(.vertical, v)
        return Group {
            switch shape.kind {
            case .capsule: label.background(fill, in: Capsule())
            case .circle: label.background(fill, in: Circle())
            case .rounded(let radius): label.background(fill, in: RoundedRectangle(cornerRadius: radius ?? r))
            case .automatic:                                // iOS 26+: bordered buttons are capsules
                if _isimGlassLook { label.background(fill, in: Capsule()) } else { label.background(fill, in: RoundedRectangle(cornerRadius: r)) }
            }
        }
        .opacity(configuration.isPressed ? (prominent ? 0.6 : 0.5) : 1)
    }
}

public struct PrimitiveButtonStyleConfiguration {
    public struct Label: View, _PrimitiveView { let make: @MainActor (_Context) -> _Node; public var body: Never { fatalError() }; func _makeNode(_ ctx: _Context) -> _Node { make(ctx) } }
    public let role: ButtonRole?
    public let label: Label
    let action: () -> Void
    /// Runs the button's action.
    public func trigger() { action() }
}
public protocol PrimitiveButtonStyle {
    associatedtype Body: View
    typealias Configuration = PrimitiveButtonStyleConfiguration
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body
}
struct _AnyPrimitiveButtonStyle { let make: @MainActor (PrimitiveButtonStyleConfiguration) -> any View }
struct _PrimitiveButtonStyleKey: EnvironmentKey { static var defaultValue: _AnyPrimitiveButtonStyle? { nil } }
extension EnvironmentValues {
    var _primitiveButtonStyle: _AnyPrimitiveButtonStyle? { get { self[_PrimitiveButtonStyleKey.self] } set { self[_PrimitiveButtonStyleKey.self] = newValue } }
}
extension View {
    /// A style that builds the whole button, including how it is triggered (`configuration.trigger()`).
    public func buttonStyle<S: PrimitiveButtonStyle>(_ style: S) -> some View {
        _env { $0._primitiveButtonStyle = _AnyPrimitiveButtonStyle(make: { style.makeBody(configuration: $0) }); $0._buttonStyle = nil }
    }
}
/// Called by Button: a primitive style in the environment builds the button.
@MainActor func _primitiveButton<L: View>(_ label: L, role: ButtonRole?, action: @escaping () -> Void, _ ctx: _Context) -> _Node? {
    guard let style = ctx.environment._primitiveButtonStyle, !ctx.environment._inList else { return nil }
    let body = style.make(PrimitiveButtonStyleConfiguration(role: role, label: .init(make: { c in _resolve(label, c.with { $0._primitiveButtonStyle = nil }) }), action: action))
    return _resolve(body, ctx.child("pstyle").with { $0._primitiveButtonStyle = nil })
}
