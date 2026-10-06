// isim SwiftUI: input controls on UIKit's — Slider (UISlider), Stepper (UIStepper), Picker (segmented =
// UISegmentedControl; menu = pop-up UIMenu; inline rows with checkmarks; navigationLink page; wheel shown as
// a menu), Menu (pop-up UIMenu with sections, submenus and pickers) and ProgressView.
import UIKit

// MARK: - Slider

public struct Slider<Label: View, ValueLabel: View>: View, _PrimitiveView {
    let value: Binding<Double>, bounds: ClosedRange<Double>, step: Double?
    let onEditingChanged: (Bool) -> Void
    let label: Label?, minLabel: ValueLabel?, maxLabel: ValueLabel?
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let tint = (ctx.environment._tint ?? .accentColor).uiColor
        let s = _SliderNode(path: ctx.path + "/slider", value: value, bounds: bounds, step: step, onEditingChanged: onEditingChanged,
                            tint: tint, enabled: ctx.environment.isEnabled)
        guard let minLabel, let maxLabel else { return s }
        return _StackNode(path: ctx.path, axis: .horizontal, spacing: 8, alignment: .center,
                          children: [_resolve(minLabel, ctx.child("min")), s, _resolve(maxLabel, ctx.child("max"))])
    }
}
extension Slider {
    static func _double<V: BinaryFloatingPoint>(_ b: Binding<V>) -> Binding<Double> {
        Binding(get: { Double(b.wrappedValue) }, set: { b.wrappedValue = V($0) })
    }
}
extension Slider where Label == EmptyView, ValueLabel == EmptyView {
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, onEditingChanged: @escaping (Bool) -> Void = { _ in })
    where V.Stride: BinaryFloatingPoint {
        self.value = Slider._double(value); self.bounds = Double(bounds.lowerBound)...Double(bounds.upperBound); step = nil
        self.onEditingChanged = onEditingChanged; label = nil; minLabel = nil; maxLabel = nil
    }
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in })
    where V.Stride: BinaryFloatingPoint {
        self.value = Slider._double(value); self.bounds = Double(bounds.lowerBound)...Double(bounds.upperBound); self.step = Double(step)
        self.onEditingChanged = onEditingChanged; label = nil; minLabel = nil; maxLabel = nil
    }
}
extension Slider where ValueLabel == EmptyView {
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label,
                                        onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {
        self.value = Slider._double(value); self.bounds = Double(bounds.lowerBound)...Double(bounds.upperBound); step = nil
        self.onEditingChanged = onEditingChanged; self.label = label(); minLabel = nil; maxLabel = nil
    }
}
extension Slider {
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label,
                                        @ViewBuilder minimumValueLabel: () -> ValueLabel, @ViewBuilder maximumValueLabel: () -> ValueLabel,
                                        onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {
        self.value = Slider._double(value); self.bounds = Double(bounds.lowerBound)...Double(bounds.upperBound); step = nil
        self.onEditingChanged = onEditingChanged; self.label = label(); minLabel = minimumValueLabel(); maxLabel = maximumValueLabel()
    }
}

final class _SliderNode: _Node {
    let value: Binding<Double>, bounds: ClosedRange<Double>, step: Double?, onEditingChanged: (Bool) -> Void, tint: UIColor, enabled: Bool
    init(path: String, value: Binding<Double>, bounds: ClosedRange<Double>, step: Double?, onEditingChanged: @escaping (Bool) -> Void, tint: UIColor, enabled: Bool) {
        self.value = value; self.bounds = bounds; self.step = step; self.onEditingChanged = onEditingChanged; self.tint = tint; self.enabled = enabled
        super.init(path: path, children: [])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 200, height: 31) }
    override var isSpacer: Bool { false }
    override func mountView(_ g: _Graph) -> UIView {
        let s = g.view(viewKey) { _SUISlider(frame: .zero) }
        s.node = self
        s.minimumValue = Float(bounds.lowerBound); s.maximumValue = Float(bounds.upperBound)
        if !s.isTracking { s.value = Float(value.wrappedValue) }
        s.minimumTrackTintColor = tint
        s.isEnabled = enabled
        return s
    }
}
final class _SUISlider: UISlider {
    var node: _SliderNode?
    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(changed), for: .valueChanged)
        addTarget(self, action: #selector(began), for: .touchDown)
        addTarget(self, action: #selector(ended), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc func changed() {
        guard let n = node else { return }
        var v = Double(value)
        if let st = n.step, st > 0 { v = n.bounds.lowerBound + ((v - n.bounds.lowerBound) / st).rounded() * st }
        n.value.wrappedValue = min(n.bounds.upperBound, max(n.bounds.lowerBound, v))
    }
    @objc func began() { node?.onEditingChanged(true) }
    @objc func ended() { node?.onEditingChanged(false) }
}

// MARK: - Stepper

public struct Stepper<Label: View>: View, _PrimitiveView {
    let label: Label
    let onIncrement: (() -> Void)?, onDecrement: (() -> Void)?
    let canIncrement: Bool, canDecrement: Bool
    let onEditingChanged: (Bool) -> Void
    public var body: Never { fatalError() }
    public init(@ViewBuilder label: () -> Label, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.label = label(); self.onIncrement = onIncrement; self.onDecrement = onDecrement
        canIncrement = onIncrement != nil; canDecrement = onDecrement != nil; self.onEditingChanged = onEditingChanged
    }
    public init<V: Strideable>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label,
                               onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.label = label(); self.onEditingChanged = onEditingChanged
        let v = value.wrappedValue
        canIncrement = v < bounds.upperBound; canDecrement = v > bounds.lowerBound
        onIncrement = { value.wrappedValue = min(bounds.upperBound, value.wrappedValue.advanced(by: step)) }
        onDecrement = { value.wrappedValue = max(bounds.lowerBound, value.wrappedValue.advanced(by: -step)) }
    }
    public init<V: Strideable>(value: Binding<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.label = label(); self.onEditingChanged = onEditingChanged
        canIncrement = true; canDecrement = true
        onIncrement = { value.wrappedValue = value.wrappedValue.advanced(by: step) }
        onDecrement = { value.wrappedValue = value.wrappedValue.advanced(by: -step) }
    }
    func _makeNode(_ ctx: _Context) -> _Node {
        let l = _resolve(label, ctx.child("label"))
        let st = _StepperNode(path: ctx.path + "/stepper", canInc: canIncrement && ctx.environment.isEnabled, canDec: canDecrement && ctx.environment.isEnabled,
                              inc: onIncrement, dec: onDecrement)
        return _StackNode(path: ctx.path, axis: .horizontal, spacing: 8, alignment: .center, children: [l, _SpacerNode(path: ctx.path + "/sp", minLength: 8), st])
    }
}
extension Stepper where Label == Text {
    public init<V: Strideable>(_ titleKey: LocalizedStringKey, value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1,
                               onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(value: value, in: bounds, step: step, label: { Text(titleKey) }, onEditingChanged: onEditingChanged)
    }
    @_disfavoredOverload public init<S: StringProtocol, V: Strideable>(_ title: S, value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1,
                               onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(value: value, in: bounds, step: step, label: { Text(title) }, onEditingChanged: onEditingChanged)
    }
    public init<V: Strideable>(_ titleKey: LocalizedStringKey, value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(value: value, step: step, label: { Text(titleKey) }, onEditingChanged: onEditingChanged)
    }
    @_disfavoredOverload public init<S: StringProtocol, V: Strideable>(_ title: S, value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(value: value, step: step, label: { Text(title) }, onEditingChanged: onEditingChanged)
    }
    public init(_ titleKey: LocalizedStringKey, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(label: { Text(titleKey) }, onIncrement: onIncrement, onDecrement: onDecrement, onEditingChanged: onEditingChanged)
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(label: { Text(title) }, onIncrement: onIncrement, onDecrement: onDecrement, onEditingChanged: onEditingChanged)
    }
}
final class _StepperNode: _Node {
    let canInc: Bool, canDec: Bool, inc: (() -> Void)?, dec: (() -> Void)?
    init(path: String, canInc: Bool, canDec: Bool, inc: (() -> Void)?, dec: (() -> Void)?) {
        self.canInc = canInc; self.canDec = canDec; self.inc = inc; self.dec = dec; super.init(path: path, children: [])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: 94, height: 32) }
    override func mountView(_ g: _Graph) -> UIView {
        let s = g.view(viewKey) { _SUIStepper(frame: .zero) }
        s.node = self
        // the UIStepper steps around 0; the sign of the change says which button was tapped
        s.minimumValue = canDec ? -1 : 0; s.maximumValue = canInc ? 1 : 0; s.value = 0
        return s
    }
}
final class _SUIStepper: UIStepper {
    var node: _StepperNode?
    override init(frame: CGRect) { super.init(frame: frame); addTarget(self, action: #selector(changed), for: .valueChanged) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc func changed() {
        let v = value; value = 0
        if v > 0 { node?.inc?() } else if v < 0 { node?.dec?() }
    }
}

// MARK: - Picker

public protocol PickerStyle {}
public struct DefaultPickerStyle: PickerStyle { public init() {} }
public struct SegmentedPickerStyle: PickerStyle { public init() {} }
public struct MenuPickerStyle: PickerStyle { public init() {} }
public struct InlinePickerStyle: PickerStyle { public init() {} }
public struct WheelPickerStyle: PickerStyle { public init() {} }
public struct NavigationLinkPickerStyle: PickerStyle { public init() {} }
public struct PalettePickerStyle: PickerStyle { public init() {} }
extension PickerStyle where Self == DefaultPickerStyle { public static var automatic: DefaultPickerStyle { .init() } }
extension PickerStyle where Self == SegmentedPickerStyle { public static var segmented: SegmentedPickerStyle { .init() } }
extension PickerStyle where Self == MenuPickerStyle { public static var menu: MenuPickerStyle { .init() } }
extension PickerStyle where Self == InlinePickerStyle { public static var inline: InlinePickerStyle { .init() } }
extension PickerStyle where Self == WheelPickerStyle { public static var wheel: WheelPickerStyle { .init() } }
extension PickerStyle where Self == NavigationLinkPickerStyle { public static var navigationLink: NavigationLinkPickerStyle { .init() } }
extension PickerStyle where Self == PalettePickerStyle { public static var palette: PalettePickerStyle { .init() } }
enum _PickerKind { case automatic, segmented, menu, inline, navigationLink }
struct _PickerStyleKey: EnvironmentKey { static var defaultValue: _PickerKind { .automatic } }
extension EnvironmentValues { var _pickerStyle: _PickerKind { get { self[_PickerStyleKey.self] } set { self[_PickerStyleKey.self] = newValue } } }
extension View {
    public func pickerStyle<S: PickerStyle>(_ style: S) -> some View {
        let k: _PickerKind
        switch style {
        case is SegmentedPickerStyle, is PalettePickerStyle: k = .segmented
        case is InlinePickerStyle: k = .inline
        case is NavigationLinkPickerStyle: k = .navigationLink
        case is MenuPickerStyle, is WheelPickerStyle: k = .menu            // isim: wheels show as menus
        default: k = .automatic
        }
        return _env { $0._pickerStyle = k }
    }
}

struct _PickerOption { let tag: AnyHashable; let title: String; let image: UIImage? }
@MainActor func _tagged(_ n: _Node) -> AnyHashable? {
    var x: _Node? = n
    while let c = x { if let t = c.tag { return t }; x = c.children.count == 1 ? c.children[0] : nil }
    return nil
}
@MainActor func _firstImage(_ n: _Node) -> UIImage? {
    if let i = n as? _ImageNode { return i.image }
    for c in n.children { if let i = _firstImage(c) { return i } }
    return nil
}
@MainActor func _pickerOptions(_ n: _Node) -> [_PickerOption] {
    _flatten([n]).compactMap { c in
        guard let t = _tagged(c) else { return nil }
        return _PickerOption(tag: t, title: _collectText(c).joined(separator: " "), image: _firstImage(c))
    }
}
/// A resolved picker: Menu content turns it into an inline section with checkmarks.
final class _PickerNode: _WrapperNode {
    let title: String, options: [_PickerOption], current: AnyHashable, select: (AnyHashable) -> Void
    init(path: String, child: _Node, title: String, options: [_PickerOption], current: AnyHashable, select: @escaping (AnyHashable) -> Void) {
        self.title = title; self.options = options; self.current = current; self.select = select
        super.init(path: path, child: child)
    }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override var transparent: Bool { false }
    var menu: UIMenu {
        UIMenu(title: "", options: .displayInline, children: options.map { o in
            UIAction(title: o.title, image: o.image, state: o.tag == current ? .on : .off) { [select] _ in select(o.tag) }
        })
    }
}

public struct Picker<Label: View, SelectionValue: Hashable, Content: View>: View, _PrimitiveView {
    let selection: Binding<SelectionValue>, label: Label, content: Content
    public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.selection = selection; self.content = content(); self.label = label()
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let options = _pickerOptions(_resolve(content, ctx.child("options")))
        let current = AnyHashable(selection.wrappedValue)
        let sel = selection
        let select: (AnyHashable) -> Void = { if let v = $0.base as? SelectionValue { sel.wrappedValue = v } }
        let labelNode = _resolve(label, ctx.child("label"))
        let title = _collectText(labelNode).joined(separator: " ")
        let currentTitle = options.first { $0.tag == current }?.title ?? ""
        let env = ctx.environment
        var kind = env._pickerStyle
        if kind == .navigationLink && ctx.nav == nil { kind = .menu }
        let visual: _Node
        switch kind {
        case .segmented:
            visual = _SegmentedNode(path: ctx.path + "/seg", titles: options.map(\.title), selected: options.firstIndex { $0.tag == current },
                                    onSelect: { i in if i < options.count { select(options[i].tag) } }, enabled: env.isEnabled)
        case .inline:
            let rows = options.enumerated().map { i, o -> _Node in
                let row = _resolve(HStack {
                    Text(verbatim: o.title).foregroundStyle(.primary)
                    Spacer()
                    if o.tag == current { Image(systemName: "checkmark").foregroundStyle(.tint).font(.body.weight(.semibold)) }
                }, ctx.child("row\(i)").with { $0._inList = env._inList })
                return _ButtonNode(path: ctx.path + "/row\(i)", child: row, action: { select(o.tag) }, inList: env._inList, enabled: env.isEnabled)
            }
            return _GroupNode(path: ctx.path + "/inline", children: rows)        // rows splice into the List
        case .navigationLink:
            let page = _PickerPage(title: title, options: options, current: current, select: select)
            visual = _resolve(NavigationLink(destination: page) {
                HStack { _NodeView(node: labelNode); Spacer(); Text(verbatim: currentTitle).foregroundStyle(.secondary) }
            }, ctx.child("nav"))
        case .menu, .automatic:
            let pickerMenu = { () -> UIMenu in
                UIMenu(title: "", children: options.map { o in
                    UIAction(title: o.title, image: o.image, state: o.tag == current ? .on : .off) { _ in select(o.tag) }
                })
            }
            let valueNode = _resolve(HStack(spacing: 5) {
                Text(verbatim: currentTitle)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 13, weight: .semibold))
            }.foregroundStyle(env._inList ? AnyShapeStyle(HierarchicalShapeStyle.secondary) : AnyShapeStyle(TintShapeStyle())), ctx.child("value"))
            let button = _MenuNode(path: ctx.path + "/menu", child: valueNode, build: pickerMenu, primaryAction: nil, enabled: env.isEnabled)
            visual = env._inList
                ? _StackNode(path: ctx.path + "/row", axis: .horizontal, spacing: 8, alignment: .center,
                             children: [labelNode, _SpacerNode(path: ctx.path + "/sp", minLength: 8), button])
                : button
        }
        return _PickerNode(path: ctx.path, child: visual, title: title, options: options, current: current, select: select)
    }
}
extension Picker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, content: content) { Text(titleKey) }
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, content: content) { Text(title) }
    }
}

/// Shows an already-resolved node inside a view builder.
struct _NodeView: View, _PrimitiveView {
    let node: _Node
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { node }
}

/// The page a navigationLink picker pushes: the options with a checkmark; choosing one goes back.
struct _PickerPage: View {
    let title: String, options: [_PickerOption], current: AnyHashable, select: (AnyHashable) -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        List {
            ForEach(Array(options.enumerated()), id: \.offset) { _, o in
                Button { select(o.tag); dismiss() } label: {
                    HStack {
                        Text(verbatim: o.title).foregroundStyle(.primary)
                        Spacer()
                        if o.tag == current { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

final class _SegmentedNode: _Node {
    let titles: [String], selected: Int?, onSelect: (Int) -> Void, enabled: Bool
    init(path: String, titles: [String], selected: Int?, onSelect: @escaping (Int) -> Void, enabled: Bool) {
        self.titles = titles; self.selected = selected; self.onSelect = onSelect; self.enabled = enabled
        super.init(path: path, children: [])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let l = UILabel(); l.font = .systemFont(ofSize: 13, weight: .semibold)
        let natural = titles.map { t -> CGFloat in l.text = t; return l.sizeThatFits(CGSize(width: 1000, height: 100)).width + 24 }.max() ?? 40
        return CGSize(width: p.width ?? natural * CGFloat(max(1, titles.count)), height: 32)
    }
    override func mountView(_ g: _Graph) -> UIView {
        let s = g.view(viewKey) { _SUISegmented(items: titles) }
        s.node = self
        if s.titles != titles {
            s.removeAllSegments()
            for (i, t) in titles.enumerated() { s.insertSegment(withTitle: t, at: i, animated: false) }
            s.titles = titles
        }
        let want = selected ?? UISegmentedControl.noSegment
        if s.selectedSegmentIndex != want { s.selectedSegmentIndex = want }
        s.isEnabled = enabled
        return s
    }
}
final class _SUISegmented: UISegmentedControl {
    var node: _SegmentedNode?
    var titles: [String] = []
    override init(items: [Any]?) {
        super.init(items: items)
        titles = items as? [String] ?? []
        addTarget(self, action: #selector(changed), for: .valueChanged)
    }
    override init(frame: CGRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc func changed() { node?.onSelect(selectedSegmentIndex) }
}

// MARK: - Menu

/// Builds UIMenu children from resolved menu content: buttons, nested Menus, Pickers, Sections and Dividers.
@MainActor func _menuElements(_ n: _Node) -> [UIMenuElement] {
    var groups: [[UIMenuElement]] = [[]]
    func walk(_ n: _Node) {
        switch n {
        case let b as _ButtonNode:
            let a = UIAction(title: _collectText(b).joined(separator: " "), image: _firstImage(b),
                             attributes: b.role == .destructive ? .destructive : (b.enabled ? [] : .disabled)) { [action = b.action] _ in action() }
            groups[groups.count - 1].append(a)
        case let m as _MenuNode:
            let sub = m.build()
            groups[groups.count - 1].append(UIMenu(title: _collectText(m.child).joined(separator: " "), image: _firstImage(m.child), children: sub.children))
        case let p as _PickerNode:
            groups.append([p.menu]); groups.append([])
        case let s as _SectionNode:
            groups.append([]); for r in s.rows { walk(r) }; groups.append([])
        case is _DividerNode:
            groups.append([])
        default:
            for c in n.children { walk(c) }
        }
    }
    walk(n)
    let nonEmpty = groups.filter { !$0.isEmpty }
    if nonEmpty.count <= 1 { return nonEmpty.first ?? [] }
    return nonEmpty.map { g in g.count == 1 && g[0] is UIMenu && (g[0] as! UIMenu).options.contains(.displayInline) ? g[0] : UIMenu(title: "", options: .displayInline, children: g) }
}

final class _MenuNode: _WrapperNode {
    let build: () -> UIMenu, primaryAction: (() -> Void)?, enabled: Bool
    init(path: String, child: _Node, build: @escaping () -> UIMenu, primaryAction: (() -> Void)?, enabled: Bool) {
        self.build = build; self.primaryAction = primaryAction; self.enabled = enabled
        super.init(path: path, child: child)
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let c = g.view(viewKey) { _SUIControl(frame: .zero) }
        let build = self.build, primary = primaryAction
        c.action = { [weak c] in
            guard let c else { return }
            if let primary { primary() } else { c._isim_present(build(), from: c.bounds) }
        }
        c.isEnabled = enabled
        c.alpha = enabled ? 1 : 0.4
        return c
    }
}

public struct Menu<Label: View, Content: View>: View, _PrimitiveView {
    let content: Content, label: Label, primaryAction: (() -> Void)?
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) { self.content = content(); self.label = label(); primaryAction = nil }
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label, primaryAction: @escaping () -> Void) {
        self.content = content(); self.label = label(); self.primaryAction = primaryAction
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let env = ctx.environment
        let labelNode = _resolve(label, ctx.child("label").with { $0._foreground = $0._foreground ?? $0._tint ?? .accentColor })
        let contentNode = _resolve(content, ctx.child("content").with { $0._inList = false })
        let title = _collectText(labelNode).joined(separator: " ")
        let build = { UIMenu(title: "", children: _menuElements(contentNode)) }
        _ = title
        return _MenuNode(path: ctx.path, child: labelNode, build: build, primaryAction: primaryAction, enabled: env.isEnabled)
    }
}
extension Menu where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.init(content: content) { Text(titleKey) } }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) { self.init(content: content) { Text(title) } }
}
extension Menu where Label == SwiftUI.Label<Text, Image> {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content) {
        self.init(content: content) { SwiftUI.Label(titleKey, systemImage: systemImage) }
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage: String, @ViewBuilder content: () -> Content) {
        self.init(content: content) { SwiftUI.Label(title, systemImage: systemImage) }
    }
}
public protocol MenuStyle {}
public struct DefaultMenuStyle: MenuStyle { public init() {} }
public struct BorderlessButtonMenuStyle: MenuStyle { public init() {} }
public struct ButtonMenuStyle: MenuStyle { public init() {} }
extension MenuStyle where Self == DefaultMenuStyle { public static var automatic: DefaultMenuStyle { .init() } }
extension MenuStyle where Self == ButtonMenuStyle { public static var button: ButtonMenuStyle { .init() } }
extension View {
    public func menuStyle<S: MenuStyle>(_ style: S) -> some View { self }
    public func menuOrder(_ order: MenuOrder) -> some View { self }
}
public struct MenuOrder: Sendable { public static let automatic = MenuOrder(), priority = MenuOrder(), fixed = MenuOrder() }
