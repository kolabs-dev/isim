// isim SwiftUI: more accessibility — AccessibilityFocusState and accessibilityFocused, accessibilityHeading,
// accessibilityCustomContent (the Accessibility framework's AXCustomContent), accessibilityChildren /
// accessibilityRepresentation (synthetic elements from views that are not drawn), accessibilityLinkedGroup, rotors
// (AccessibilityRotorEntry, AccessibilityRotorContent, AccessibilitySystemRotor), accessibilityScrollAction,
// accessibilityZoomAction and accessibilityDirectTouch. Like the other modifiers they set UIKit accessibility state on
// the mounted views, through isim UIKit's hooks, so isim's VoiceOver reads them (UIAccessibilityRuntime.m).
// Signatures from Apple's documentation; `@ContentBuilder` closures (Xcode 27) are `@ViewBuilder` or
// `@AccessibilityRotorContentBuilder`, as before Xcode 27.
import UIKit
import Accessibility

// MARK: - AccessibilityAttachmentModifier

/// The modifier of the accessibility modifiers that return `ModifiedContent` (heading, custom content, scroll / zoom
/// actions, direct touch): its steps apply to the content in order.
public struct AccessibilityAttachmentModifier: ViewModifier {
    var steps: [@MainActor (AnyView) -> AnyView] = []
    func adding(_ f: @escaping @MainActor (AnyView) -> AnyView) -> AccessibilityAttachmentModifier { var m = self; m.steps.append(f); return m }
    public func body(content: Content) -> some View { steps.reduce(AnyView(content)) { $1($0) } }
}
extension View {
    func _attached(_ f: @escaping @MainActor (AnyView) -> AnyView) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier().adding(f))
    }
    func _axApply(_ apply: @escaping (UIView) -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        _attached { AnyView($0._axElementApply(apply)) }
    }
    /// Applies to the view's accessibility element once the views are mounted: the view itself when it is one, else
    /// the first element inside it (a button, a Text under padding and frames).
    func _axElementApply(_ apply: @escaping (UIView) -> Void) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("ax"))
            let g = ctx.graph
            n.accessibilityApply.append { v in g.postRender.append { [weak v] in if let v { apply(_axTargetView(v)) } } }
            return n
        }
    }
}
/// A view's accessibility element: itself, or the first view inside it that is one (else itself).
@MainActor func _axTargetView(_ v: UIView) -> UIView {
    func find(_ x: UIView) -> UIView? {
        if x.isAccessibilityElement { return x }
        for s in x.subviews { if let f = find(s) { return f } }
        return nil
    }
    return find(v) ?? v
}
@MainActor extension ModifiedContent where Content: View, Modifier == AccessibilityAttachmentModifier {
    func _axApply(_ apply: @escaping (UIView) -> Void) -> ModifiedContent<Content, Modifier> {
        ModifiedContent(content: content, modifier: modifier.adding { AnyView($0._axElementApply(apply)) })
    }
}

// MARK: - Focus

/// The assistive technologies a focus state follows.
public struct AccessibilityTechnologies: SetAlgebra, Sendable {
    var bits: UInt8
    public init() { bits = 0 }
    init(bits: UInt8) { self.bits = bits }
    public static let voiceOver = AccessibilityTechnologies(bits: 1)
    public static let switchControl = AccessibilityTechnologies(bits: 2)
    public func union(_ o: AccessibilityTechnologies) -> AccessibilityTechnologies { .init(bits: bits | o.bits) }
    public func intersection(_ o: AccessibilityTechnologies) -> AccessibilityTechnologies { .init(bits: bits & o.bits) }
    public func symmetricDifference(_ o: AccessibilityTechnologies) -> AccessibilityTechnologies { .init(bits: bits ^ o.bits) }
    public func contains(_ m: AccessibilityTechnologies) -> Bool { bits & m.bits == m.bits }
    @discardableResult public mutating func insert(_ m: AccessibilityTechnologies) -> (inserted: Bool, memberAfterInsert: AccessibilityTechnologies) {
        let had = contains(m); bits |= m.bits; return (!had, m)
    }
    @discardableResult public mutating func remove(_ m: AccessibilityTechnologies) -> AccessibilityTechnologies? {
        let had = intersection(m); bits &= ~m.bits; return had.bits == 0 ? nil : had
    }
    @discardableResult public mutating func update(with m: AccessibilityTechnologies) -> AccessibilityTechnologies? {
        let had = contains(m); bits |= m.bits; return had ? m : nil
    }
    public mutating func formUnion(_ o: AccessibilityTechnologies) { bits |= o.bits }
    public mutating func formIntersection(_ o: AccessibilityTechnologies) { bits &= o.bits }
    public mutating func formSymmetricDifference(_ o: AccessibilityTechnologies) { bits ^= o.bits }
}

/// A value SwiftUI keeps equal to where VoiceOver's focus is (its element focused: true / the matching value), and
/// that moves the focus when set. Setting it to false or nil does not move VoiceOver's focus away (isim: adapted).
@propertyWrapper
public struct AccessibilityFocusState<Value: Hashable>: DynamicProperty, _DynamicProperty {
    final class Box { var storage: _StateStorage<Value>?; let initial: Value; weak var graph: _Graph?; init(_ v: Value) { initial = v } }
    let box: Box
    public init() where Value == Bool { box = Box(false) }
    public init<T: Hashable>() where Value == T? { box = Box(nil) }
    public init(for technologies: AccessibilityTechnologies) where Value == Bool { box = Box(false) }
    public init<T: Hashable>(for technologies: AccessibilityTechnologies) where Value == T? { box = Box(nil) }
    public var wrappedValue: Value {
        get { box.storage?.value ?? box.initial }
        nonmutating set { if let s = box.storage, s.value != newValue { s.value = newValue; box.graph?.invalidate() } }
    }
    public var projectedValue: Binding { Binding(box: box) }
    @propertyWrapper
    public struct Binding {
        let box: Box
        public var wrappedValue: Value {
            get { box.storage?.value ?? box.initial }
            nonmutating set { if let s = box.storage, s.value != newValue { s.value = newValue; box.graph?.invalidate() } }
        }
        public var projectedValue: Binding { self }
    }
    func _install(_ ctx: _Context, label: String) {
        let key = ctx.path + "#" + label
        if let s = ctx.graph.storage[key] as? _StateStorage<Value> { box.storage = s }
        else { let s = _StateStorage(box.initial); ctx.graph.storage[key] = s; box.storage = s }
        ctx.graph.usedKeys.insert(key)
        box.graph = ctx.graph
    }
}

extension View {
    /// Binds the element's VoiceOver focus to `condition`.
    public func accessibilityFocused(_ condition: AccessibilityFocusState<Bool>.Binding) -> some View {
        _axFocus(get: { condition.wrappedValue }, set: { condition.wrappedValue = $0 })
    }
    /// Binds the element's VoiceOver focus to `binding` having `value`.
    public func accessibilityFocused<Value: Hashable>(_ binding: AccessibilityFocusState<Value>.Binding, equals value: Value) -> some View {
        _axFocus(get: { binding.wrappedValue == value }, set: { focused in
            if focused { binding.wrappedValue = value }
            else if binding.wrappedValue == value, let none = Optional<Any>.none as? Value { binding.wrappedValue = none }
        })
    }
    func _axFocus(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("axf"))
            let g = ctx.graph
            n.accessibilityApply.append { v in
                g.postRender.append { [weak v] in
                    guard let v else { return }
                    let t = _axTargetView(v)
                    let h: @convention(block) (Bool) -> Void = { focused in MainActor.assumeIsolated { if get() != focused { set(focused) } } }
                    t.perform(NSSelectorFromString("_isim_setAccessibilityFocusHandler:"), with: h as AnyObject)
                    // the value asks for the focus: move VoiceOver there
                    if get(), UIAccessibility.isVoiceOverRunning, !t.accessibilityElementIsFocused() {
                        UIAccessibility.post(notification: .layoutChanged, argument: t)
                    }
                }
            }
            return n
        }
    }
}

// MARK: - Headings

/// The level of a heading.
@frozen public enum AccessibilityHeadingLevel: UInt, Sendable {
    case unspecified, h1, h2, h3, h4, h5, h6
}
/// A heading level from 1 to 6 is spoken with the heading ("Heading level 2"); like UIKit's heading level attribute it
/// marks the element as a header.
@MainActor func _headingApply(_ level: AccessibilityHeadingLevel) -> (UIView) -> Void {
    { v in
        let text = v.accessibilityLabel ?? ""
        guard level != .unspecified else { return }
        v.accessibilityTraits.insert(.header)
        v.accessibilityAttributedLabel = NSAttributedString(string: text, attributes: [.accessibilityTextHeadingLevel: NSNumber(value: level.rawValue)])
    }
}
extension View {
    /// Sets the level of this heading.
    public func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _axApply(_headingApply(level)) }
}
@MainActor extension ModifiedContent where Content: View, Modifier == AccessibilityAttachmentModifier {
    public func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> ModifiedContent<Content, Modifier> { _axApply(_headingApply(level)) }
}
extension Text {
    /// Sets the level of this heading.
    public func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> Text { var t = self; t._x.axHeading = level; return t }
}

// MARK: - Custom content

/// The identifier and label of an entry of custom content.
public struct AccessibilityCustomContentKey: Equatable {
    let label: String, id: String
    public init(_ labelKey: LocalizedStringKey) { label = labelKey.resolved(); id = label }
    @available(iOS 26.0, *)
    @_disfavoredOverload
    public init(_ label: LocalizedStringResource) { self.label = String(localized: label); id = self.label }
    public init(_ label: Text, id: String) { self.label = label.string; self.id = id }
    public init(_ labelKey: LocalizedStringKey, id: String) { label = labelKey.resolved(); self.id = id }
    @_disfavoredOverload
    public init(_ label: LocalizedStringResource, id: String) { self.label = String(localized: label); self.id = id }
}
/// The custom content of a view, by identifier (a later entry with the same identifier replaces the earlier one).
final class _AXContentBox: NSObject { var items: [(id: String, content: AXCustomContent)] = [] }
nonisolated(unsafe) private var _kAXContent: UInt8 = 0
@MainActor func _customContentApply(_ key: AccessibilityCustomContentKey, _ value: String?, _ importance: AXCustomContent.Importance) -> (UIView) -> Void {
    { v in
        let box = objc_getAssociatedObject(v, &_kAXContent) as? _AXContentBox ?? _AXContentBox()
        objc_setAssociatedObject(v, &_kAXContent, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        box.items.removeAll { $0.id == key.id }
        if let value {
            let c = AXCustomContent(label: key.label, value: value)
            c.importance = importance
            box.items.append((key.id, c))
        }
        v.perform(NSSelectorFromString("_isim_setAccessibilityCustomContent:"), with: box.items.map(\.content) as NSArray)
    }
}
extension View {
    /// Adds a label and value VoiceOver reads after the element (high importance) or in the rotor's More Content.
    /// A nil value removes the entry with the key's identifier.
    public func accessibilityCustomContent(_ key: AccessibilityCustomContentKey, _ value: Text?, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        _axApply(_customContentApply(key, value?.string, importance))
    }
    public func accessibilityCustomContent(_ key: AccessibilityCustomContentKey, _ valueKey: LocalizedStringKey, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityCustomContent(key, Text(valueKey), importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent<V: StringProtocol>(_ key: AccessibilityCustomContentKey, _ value: V, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityCustomContent(key, Text(value), importance: importance)
    }
    public func accessibilityCustomContent(_ label: Text, _ value: Text, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityCustomContent(AccessibilityCustomContentKey(label, id: label.string), value, importance: importance)
    }
    public func accessibilityCustomContent(_ labelKey: LocalizedStringKey, _ value: Text, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityCustomContent(AccessibilityCustomContentKey(labelKey), value, importance: importance)
    }
    public func accessibilityCustomContent(_ labelKey: LocalizedStringKey, _ valueKey: LocalizedStringKey, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityCustomContent(AccessibilityCustomContentKey(labelKey), Text(valueKey), importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent<V: StringProtocol>(_ labelKey: LocalizedStringKey, _ value: V, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityCustomContent(AccessibilityCustomContentKey(labelKey), Text(value), importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent(_ key: AccessibilityCustomContentKey, _ valueResource: LocalizedStringResource, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityCustomContent(key, Text(valueResource), importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent(_ label: LocalizedStringResource, _ value: Text, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityCustomContent(AccessibilityCustomContentKey(label, id: String(localized: label)), value, importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent(_ label: LocalizedStringResource, _ valueResource: LocalizedStringResource, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityCustomContent(label, Text(valueResource), importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent<V: StringProtocol>(_ label: LocalizedStringResource, _ value: V, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityCustomContent(label, Text(value), importance: importance)
    }
}
@MainActor extension ModifiedContent where Content: View, Modifier == AccessibilityAttachmentModifier {
    public func accessibilityCustomContent(_ key: AccessibilityCustomContentKey, _ value: Text?, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Content, Modifier> {
        _axApply(_customContentApply(key, value?.string, importance))
    }
    public func accessibilityCustomContent(_ key: AccessibilityCustomContentKey, _ valueKey: LocalizedStringKey, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Content, Modifier> {
        accessibilityCustomContent(key, Text(valueKey), importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent<V: StringProtocol>(_ key: AccessibilityCustomContentKey, _ value: V, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Content, Modifier> {
        accessibilityCustomContent(key, Text(value), importance: importance)
    }
    public func accessibilityCustomContent(_ label: Text, _ value: Text, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Content, Modifier> {
        accessibilityCustomContent(AccessibilityCustomContentKey(label, id: label.string), value, importance: importance)
    }
    public func accessibilityCustomContent(_ labelKey: LocalizedStringKey, _ value: Text, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Content, Modifier> {
        accessibilityCustomContent(AccessibilityCustomContentKey(labelKey), value, importance: importance)
    }
    public func accessibilityCustomContent(_ labelKey: LocalizedStringKey, _ valueKey: LocalizedStringKey, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Content, Modifier> {
        accessibilityCustomContent(AccessibilityCustomContentKey(labelKey), Text(valueKey), importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent<V: StringProtocol>(_ labelKey: LocalizedStringKey, _ value: V, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Content, Modifier> {
        accessibilityCustomContent(AccessibilityCustomContentKey(labelKey), Text(value), importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent(_ key: AccessibilityCustomContentKey, _ valueResource: LocalizedStringResource, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Content, Modifier> {
        accessibilityCustomContent(key, Text(valueResource), importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent(_ label: LocalizedStringResource, _ value: Text, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Content, Modifier> {
        accessibilityCustomContent(AccessibilityCustomContentKey(label, id: String(localized: label)), value, importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent(_ label: LocalizedStringResource, _ valueResource: LocalizedStringResource, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Content, Modifier> {
        accessibilityCustomContent(label, Text(valueResource), importance: importance)
    }
    @_disfavoredOverload
    public func accessibilityCustomContent<V: StringProtocol>(_ label: LocalizedStringResource, _ value: V, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Content, Modifier> {
        accessibilityCustomContent(label, Text(value), importance: importance)
    }
}

// MARK: - Children and representation

/// A view whose accessibility comes from other views: those are laid out in its frame and mounted, not drawn and not
/// touchable (a layer mask hides them), so they make the accessibility elements in its place.
final class _AXReplacementNode: _Node {
    let content: _Node, synthetic: _Node, replacesElement: Bool
    init(path: String, content: _Node, synthetic: _Node, replacesElement: Bool) {
        self.content = content; self.synthetic = synthetic; self.replacesElement = replacesElement
        super.init(path: path, children: [content, synthetic])
    }
    override var layoutPriority: Double { content.layoutPriority }
    override var isSpacer: Bool { content.isSpacer }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { content.sizeThatFits(p) }
    override func place(_ rect: CGRect) {
        frame = rect
        let b = CGRect(origin: .zero, size: rect.size)
        content.place(b)
        synthetic.place(b)
    }
    override func mountView(_ g: _Graph) -> UIView { g.view(viewKey) { _PassthroughView() } }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        let host = g.view(path + "/axhost|host") { _AXSyntheticHost() }
        host.frame = view.bounds
        g.mount(content, in: view, order: 0)
        let contentView = view.subviews.last { $0 !== host }
        if view.subviews.last !== host { view.addSubview(host) }
        // the content's own elements give way (accessibilityChildren keeps the content as their container)
        contentView?.accessibilityElementsHidden = true
        g.mount(synthetic, in: host, order: 0)
    }
}
/// The views of accessibilityChildren / accessibilityRepresentation: in the accessibility tree, not on screen.
final class _AXSyntheticHost: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.mask = CALayer()                  // an empty mask: nothing is drawn
        accessibilityIdentifier = "isim-accessibility-representation"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
extension View {
    /// Replaces the accessibility children of this view with the elements of `children` (not drawn).
    public func accessibilityChildren<V: View>(@ViewBuilder children: () -> V) -> some View {
        let kids = children()
        return _modify { ctx, c in
            _AXReplacementNode(path: ctx.path, content: _resolve(c, ctx.child("axc")), synthetic: _resolve(kids, ctx.child("axkids")), replacesElement: false)
        }
    }
    /// Replaces the accessibility elements of this view with those of `representation` (not drawn).
    public func accessibilityRepresentation<V: View>(@ViewBuilder representation: () -> V) -> some View {
        let rep = representation()
        return _modify { ctx, c in
            _AXReplacementNode(path: ctx.path, content: _resolve(c, ctx.child("axc")), synthetic: _resolve(rep, ctx.child("axrep")), replacesElement: true)
        }
    }
    /// Links elements so VoiceOver goes from one to the next (isim: they follow each other in VoiceOver's order).
    public func accessibilityLinkedGroup<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        let key = "\(namespace.value)#\(id)"
        return _axElementApply { v in v.perform(NSSelectorFromString("_isim_setAccessibilityLinkedGroup:"), with: key as NSString) }
    }
}

// MARK: - Scroll, zoom, direct touch

/// The direction and point of an assistive technology's zoom gesture.
public struct AccessibilityZoomGestureAction {
    @frozen public enum Direction: Hashable, Sendable { case zoomIn, zoomOut }
    public let direction: Direction
    /// The gesture's point, normalized to the element's frame.
    public let location: UnitPoint
    /// The gesture's point in the window.
    public let point: CGPoint
}
/// What a direct touch area does under an assistive technology.
public struct AccessibilityDirectTouchOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    /// Touches reach the area at once, without VoiceOver speaking it.
    public static let silentOnTouch = AccessibilityDirectTouchOptions(rawValue: 1)
    /// Touches reach the area only after VoiceOver activated it (a double tap).
    public static let requiresActivation = AccessibilityDirectTouchOptions(rawValue: 2)
}
@MainActor func _scrollApply(_ handler: @escaping (Edge) -> Void) -> (UIView) -> Void {
    let block: @convention(block) (Int) -> Bool = { d in
        // VoiceOver's three-finger swipe moves the content: up shows what is below
        let edge: Edge
        switch UIAccessibilityScrollDirection(rawValue: d) ?? .next {
        case .up, .next: edge = .bottom
        case .down, .previous: edge = .top
        case .left: edge = .trailing
        case .right: edge = .leading
        @unknown default: edge = .bottom
        }
        MainActor.assumeIsolated { handler(edge) }
        return true
    }
    return { v in v.perform(NSSelectorFromString("_isim_setAccessibilityScrollHandler:"), with: block as AnyObject) }
}
@MainActor func _zoomApply(_ handler: @escaping (AccessibilityZoomGestureAction) -> Void) -> (UIView) -> Void {
    { v in
        let block: @convention(block) (Bool, CGPoint) -> Bool = { [weak v] zoomIn, p in
            MainActor.assumeIsolated {
                let f = v?.accessibilityFrame ?? .zero
                let loc = UnitPoint(x: f.width > 0 ? (p.x - f.minX) / f.width : 0.5, y: f.height > 0 ? (p.y - f.minY) / f.height : 0.5)
                handler(AccessibilityZoomGestureAction(direction: zoomIn ? .zoomIn : .zoomOut, location: loc, point: p))
            }
            return true
        }
        v.perform(NSSelectorFromString("_isim_setAccessibilityZoomHandler:"), with: block as AnyObject)
        v.accessibilityTraits.insert(.supportsZoom)
    }
}
@MainActor func _directTouchApply(_ on: Bool, _ options: AccessibilityDirectTouchOptions) -> (UIView) -> Void {
    { v in
        if on { v.accessibilityTraits.insert(.allowsDirectInteraction) } else { v.accessibilityTraits.remove(.allowsDirectInteraction) }
        v.accessibilityDirectTouchOptions = UIAccessibilityDirectTouchOptions(rawValue: options.rawValue)
    }
}
extension View {
    /// Runs `handler` with the edge to scroll to when VoiceOver scrolls (a three-finger swipe) on this element.
    public func accessibilityScrollAction(_ handler: @escaping (Edge) -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _axApply(_scrollApply(handler)) }
    /// Runs `handler` when VoiceOver's zoom gesture (the Zoom rotor) zooms this element.
    public func accessibilityZoomAction(_ handler: @escaping (AccessibilityZoomGestureAction) -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { _axApply(_zoomApply(handler)) }
    /// Makes this element a direct touch area: under VoiceOver its touches go to the app.
    public func accessibilityDirectTouch(_ isDirectTouchArea: Bool = true, options: AccessibilityDirectTouchOptions = []) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        _axApply(_directTouchApply(isDirectTouchArea, options))
    }
}
@MainActor extension ModifiedContent where Content: View, Modifier == AccessibilityAttachmentModifier {
    public func accessibilityScrollAction(_ handler: @escaping (Edge) -> Void) -> ModifiedContent<Content, Modifier> { _axApply(_scrollApply(handler)) }
    public func accessibilityZoomAction(_ handler: @escaping (AccessibilityZoomGestureAction) -> Void) -> ModifiedContent<Content, Modifier> { _axApply(_zoomApply(handler)) }
    public func accessibilityDirectTouch(_ isDirectTouchArea: Bool = true, options: AccessibilityDirectTouchOptions = []) -> ModifiedContent<Content, Modifier> {
        _axApply(_directTouchApply(isDirectTouchArea, options))
    }
}

// MARK: - Rotors

/// An entry of a rotor: its element (by id: a ForEach element or a view with `.id(_:)`, or `accessibilityRotorEntry(id:in:)`
/// in a namespace; without an id, the element the rotor is on), its label, an optional text range (not navigated by
/// isim's VoiceOver) and `prepare`, run before VoiceOver moves to it.
struct _RotorEntryInfo {
    let label: String
    let id: AnyHashable?
    let namespace: Namespace.ID?
    let prepare: () -> Void
}
@MainActor @preconcurrency public protocol AccessibilityRotorContent {
    associatedtype Body: AccessibilityRotorContent
    @AccessibilityRotorContentBuilder var body: Body { get }
}
extension Never: AccessibilityRotorContent {}
/// Rotor content that lists its entries directly.
protocol _RotorEntries { @MainActor var _rotorEntries: [_RotorEntryInfo] { get } }
@MainActor func _collectRotorEntries(_ c: any AccessibilityRotorContent) -> [_RotorEntryInfo] {
    if let e = c as? _RotorEntries { return e._rotorEntries }
    func open<C: AccessibilityRotorContent>(_ c: C) -> [_RotorEntryInfo] { _collectRotorEntries(c.body) }
    return open(c)
}
public struct AccessibilityRotorEntry<ID: Hashable>: AccessibilityRotorContent, _RotorEntries {
    let info: _RotorEntryInfo
    public var body: Never { return fatalError() }
    var _rotorEntries: [_RotorEntryInfo] { [info] }
    init(label: String, id: AnyHashable?, namespace: Namespace.ID? = nil, prepare: @escaping () -> Void) {
        info = _RotorEntryInfo(label: label, id: id, namespace: namespace, prepare: prepare)
    }
    // entries of the element the rotor is on (a text range in it)
    public init(_ label: Text? = nil, textRange: Range<String.Index>, prepare: @escaping () -> Void = {}) where ID == Never {
        self.init(label: label?.string ?? "", id: nil, prepare: prepare)
    }
    public init(_ labelKey: LocalizedStringKey, textRange: Range<String.Index>, prepare: @escaping () -> Void = {}) where ID == Never {
        self.init(label: labelKey.resolved(), id: nil, prepare: prepare)
    }
    @_disfavoredOverload
    public init<L: StringProtocol>(_ label: L, textRange: Range<String.Index>, prepare: @escaping () -> Void = {}) where ID == Never {
        self.init(label: String(label), id: nil, prepare: prepare)
    }
    @_disfavoredOverload
    public init(_ label: LocalizedStringResource, textRange: Range<String.Index>, prepare: @escaping () -> Void = {}) where ID == Never {
        self.init(label: String(localized: label), id: nil, prepare: prepare)
    }
    // entries of an identified element
    public init(_ label: Text, id: ID, textRange: Range<String.Index>? = nil, prepare: @escaping () -> Void = {}) {
        self.init(label: label.string, id: AnyHashable(id), prepare: prepare)
    }
    public init(_ labelKey: LocalizedStringKey, id: ID, textRange: Range<String.Index>? = nil, prepare: @escaping () -> Void = {}) {
        self.init(label: labelKey.resolved(), id: AnyHashable(id), prepare: prepare)
    }
    @_disfavoredOverload
    public init<L: StringProtocol>(_ label: L, id: ID, textRange: Range<String.Index>? = nil, prepare: @escaping () -> Void = {}) {
        self.init(label: String(label), id: AnyHashable(id), prepare: prepare)
    }
    @_disfavoredOverload
    public init(_ label: LocalizedStringResource, id: ID, textRange: Range<String.Index>? = nil, prepare: @escaping () -> Void = {}) {
        self.init(label: String(localized: label), id: AnyHashable(id), prepare: prepare)
    }
    // entries of an element identified in a namespace (accessibilityRotorEntry(id:in:))
    public init(_ label: Text, id: ID, in namespace: Namespace.ID, textRange: Range<String.Index>? = nil, prepare: @escaping () -> Void = {}) {
        self.init(label: label.string, id: AnyHashable(id), namespace: namespace, prepare: prepare)
    }
    public init(_ labelKey: LocalizedStringKey, id: ID, in namespace: Namespace.ID, textRange: Range<String.Index>? = nil, prepare: @escaping () -> Void = {}) {
        self.init(label: labelKey.resolved(), id: AnyHashable(id), namespace: namespace, prepare: prepare)
    }
    @_disfavoredOverload
    public init<L: StringProtocol>(_ label: L, _ id: ID, in namespace: Namespace.ID, textRange: Range<String.Index>? = nil, prepare: @escaping () -> Void = {}) {
        self.init(label: String(label), id: AnyHashable(id), namespace: namespace, prepare: prepare)
    }
    @_disfavoredOverload
    public init(_ label: LocalizedStringResource, id: ID, in namespace: Namespace.ID, textRange: Range<String.Index>? = nil, prepare: @escaping () -> Void = {}) {
        self.init(label: String(localized: label), id: AnyHashable(id), namespace: namespace, prepare: prepare)
    }
}
/// Several rotor entries.
public struct _RotorContentList: AccessibilityRotorContent, _RotorEntries {
    let items: [any AccessibilityRotorContent]
    public var body: Never { return fatalError() }
    var _rotorEntries: [_RotorEntryInfo] { items.flatMap { _collectRotorEntries($0) } }
}
@resultBuilder public struct AccessibilityRotorContentBuilder {
    public static func buildBlock<Content: AccessibilityRotorContent>(_ content: Content) -> some AccessibilityRotorContent { content }
    public static func buildBlock<each Content: AccessibilityRotorContent>(_ content: repeat each Content) -> some AccessibilityRotorContent {
        var items: [any AccessibilityRotorContent] = []
        for c in repeat each content { items.append(c) }
        return _RotorContentList(items: items)
    }
    public static func buildIf<Content: AccessibilityRotorContent>(_ content: Content?) -> some AccessibilityRotorContent {
        _RotorContentList(items: content.map { [$0] } ?? [])
    }
    public static func buildExpression<Content: AccessibilityRotorContent>(_ content: Content) -> Content { content }
}
extension ForEach: AccessibilityRotorContent, _RotorEntries where Content: AccessibilityRotorContent {
    public var body: Never { return fatalError() }
    var _rotorEntries: [_RotorEntryInfo] { data.flatMap { _collectRotorEntries(content($0)) } }
    public init(_ data: Data, @AccessibilityRotorContentBuilder content: @escaping (Data.Element) -> Content) where ID == Data.Element.ID, Data.Element: Identifiable {
        self.init(_data: data, _id: { $0.id }, _content: content)
    }
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @AccessibilityRotorContentBuilder content: @escaping (Data.Element) -> Content) {
        self.init(_data: data, _id: { $0[keyPath: id] }, _content: content)
    }
    public init(_ data: Range<Int>, @AccessibilityRotorContentBuilder content: @escaping (Int) -> Content) where Data == Range<Int>, ID == Int {
        self.init(_data: data, _id: { $0 }, _content: content)
    }
}

/// A system rotor that a rotor of the app replaces.
public struct AccessibilitySystemRotor: Sendable {
    let type: UIAccessibilityCustomRotor.SystemRotorType
    public static var textFields: AccessibilitySystemRotor { .init(type: .textField) }
    public static var boldText: AccessibilitySystemRotor { .init(type: .boldText) }
    public static var italicText: AccessibilitySystemRotor { .init(type: .italicText) }
    public static var underlineText: AccessibilitySystemRotor { .init(type: .underlineText) }
    public static var misspelledWords: AccessibilitySystemRotor { .init(type: .misspelledWord) }
    public static var headings: AccessibilitySystemRotor { .init(type: .heading) }
    public static func headings(level: AccessibilityHeadingLevel) -> AccessibilitySystemRotor {
        let types: [UIAccessibilityCustomRotor.SystemRotorType] = [.heading, .headingLevel1, .headingLevel2, .headingLevel3, .headingLevel4, .headingLevel5, .headingLevel6]
        return .init(type: types[Int(level.rawValue)])
    }
    public static var links: AccessibilitySystemRotor { .init(type: .link) }
    public static func links(visited: Bool) -> AccessibilitySystemRotor { .init(type: visited ? .visitedLink : .link) }
    public static var images: AccessibilitySystemRotor { .init(type: .image) }
    public static var landmarks: AccessibilitySystemRotor { .init(type: .landmark) }
    public static var lists: AccessibilitySystemRotor { .init(type: .list) }
    public static var tables: AccessibilitySystemRotor { .init(type: .table) }
}

/// Views by rotor id: ForEach elements and `.id(_:)` (their tag), and accessibilityRotorEntry(id:in:) (namespace#id).
final class _AXRotorTargets {
    var views: [AnyHashable: WeakBox] = [:]
    final class WeakBox { weak var view: UIView?; init(_ v: UIView) { view = v } }
}
/// The accessibility element of a view: itself, or the first element inside it.
@MainActor func _axElement(_ v: UIView) -> NSObject {
    if v.isAccessibilityElement { return v }
    for s in v.subviews where !s.isHidden { let e = _axElement(s); if e !== s || s.isAccessibilityElement { return e } }
    return v
}
extension View {
    /// Ties this view's element to a rotor entry with `id` in `namespace`.
    public func accessibilityRotorEntry<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        let key = AnyHashable("\(namespace.value)#\(AnyHashable(id))")
        return _modify { ctx, c in
            let n = _resolve(c, ctx.child("axre"))
            let g = ctx.graph
            n.accessibilityApply.append { v in g.axRotorTargets.views[key] = _AXRotorTargets.WeakBox(v) }
            return n
        }
    }
    func _rotor(name: String, system: UIAccessibilityCustomRotor.SystemRotorType?, entries: @escaping @MainActor () -> [_RotorEntryInfo]) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("axrot"))
            let g = ctx.graph
            n.accessibilityApply.append { [weak g] v in
                let search: UIAccessibilityCustomRotor.Search = { [weak v, weak g] p in
                    MainActor.assumeIsolated {
                        guard let v, let g else { return nil }
                        // each entry's element (an entry without an id: the element the rotor is on)
                        let items: [(e: _RotorEntryInfo, el: NSObject)] = entries().compactMap { e in
                            guard let id = e.id else { return (e, _axElement(v)) }
                            let key: AnyHashable = e.namespace.map { AnyHashable("\($0.value)#\(id)") } ?? id
                            let view = g.axRotorTargets.views[key]?.view ?? g.axRotorTargets.views[AnyHashable("\(id)")]?.view
                            return view.map { (e, _axElement($0)) }
                        }
                        guard !items.isEmpty else { return nil }
                        let cur = p.currentItem.targetElement as? NSObject
                        let i = cur.flatMap { c in items.firstIndex { $0.el === c } }
                        let next = p.searchDirection == .next ? (i.map { $0 + 1 } ?? 0) : (i.map { $0 - 1 } ?? items.count - 1)
                        guard next >= 0, next < items.count else { return nil }
                        items[next].e.prepare()
                        return UIAccessibilityCustomRotorItemResult(targetElement: items[next].el, targetRange: nil)
                    }
                }
                let rotor = system.map { UIAccessibilityCustomRotor(systemType: $0, itemSearch: search) } ?? UIAccessibilityCustomRotor(name: name, itemSearch: search)
                v.accessibilityCustomRotors = (v.accessibilityCustomRotors ?? []).filter { $0.name != rotor.name } + [rotor]
            }
            return n
        }
    }
    // content builder
    public func accessibilityRotor<Content: AccessibilityRotorContent>(_ label: Text, @AccessibilityRotorContentBuilder entries: @escaping () -> Content) -> some View {
        _rotor(name: label.string, system: nil) { _collectRotorEntries(entries()) }
    }
    public func accessibilityRotor<Content: AccessibilityRotorContent>(_ labelKey: LocalizedStringKey, @AccessibilityRotorContentBuilder entries: @escaping () -> Content) -> some View {
        accessibilityRotor(Text(labelKey), entries: entries)
    }
    public func accessibilityRotor<Content: AccessibilityRotorContent>(_ systemRotor: AccessibilitySystemRotor, @AccessibilityRotorContentBuilder entries: @escaping () -> Content) -> some View {
        _rotor(name: "", system: systemRotor.type) { _collectRotorEntries(entries()) }
    }
    @_disfavoredOverload
    public func accessibilityRotor<L: StringProtocol, Content: AccessibilityRotorContent>(_ label: L, @AccessibilityRotorContentBuilder entries: @escaping () -> Content) -> some View {
        accessibilityRotor(Text(label), entries: entries)
    }
    @_disfavoredOverload
    public func accessibilityRotor<Content: AccessibilityRotorContent>(_ label: LocalizedStringResource, @AccessibilityRotorContentBuilder entries: @escaping () -> Content) -> some View {
        accessibilityRotor(Text(label), entries: entries)
    }
    // entries from a collection, with an id key path
    public func accessibilityRotor<EntryModel, ID: Hashable>(_ rotorLabel: Text, entries: [EntryModel], entryID: KeyPath<EntryModel, ID>, entryLabel: KeyPath<EntryModel, String>) -> some View {
        _rotor(name: rotorLabel.string, system: nil) { entries.map { _RotorEntryInfo(label: $0[keyPath: entryLabel], id: AnyHashable($0[keyPath: entryID]), namespace: nil, prepare: {}) } }
    }
    public func accessibilityRotor<EntryModel, ID: Hashable>(_ rotorLabelKey: LocalizedStringKey, entries: [EntryModel], entryID: KeyPath<EntryModel, ID>, entryLabel: KeyPath<EntryModel, String>) -> some View {
        accessibilityRotor(Text(rotorLabelKey), entries: entries, entryID: entryID, entryLabel: entryLabel)
    }
    public func accessibilityRotor<EntryModel, ID: Hashable>(_ systemRotor: AccessibilitySystemRotor, entries: [EntryModel], entryID: KeyPath<EntryModel, ID>, entryLabel: KeyPath<EntryModel, String>) -> some View {
        _rotor(name: "", system: systemRotor.type) { entries.map { _RotorEntryInfo(label: $0[keyPath: entryLabel], id: AnyHashable($0[keyPath: entryID]), namespace: nil, prepare: {}) } }
    }
    @_disfavoredOverload
    public func accessibilityRotor<L: StringProtocol, EntryModel, ID: Hashable>(_ rotorLabel: L, entries: [EntryModel], entryID: KeyPath<EntryModel, ID>, entryLabel: KeyPath<EntryModel, String>) -> some View {
        accessibilityRotor(Text(rotorLabel), entries: entries, entryID: entryID, entryLabel: entryLabel)
    }
    @_disfavoredOverload
    public func accessibilityRotor<EntryModel, ID: Hashable>(_ rotorLabelResource: LocalizedStringResource, entries: [EntryModel], entryID: KeyPath<EntryModel, ID>, entryLabel: KeyPath<EntryModel, String>) -> some View {
        accessibilityRotor(Text(rotorLabelResource), entries: entries, entryID: entryID, entryLabel: entryLabel)
    }
    // entries from Identifiable values
    public func accessibilityRotor<EntryModel: Identifiable>(_ rotorLabel: Text, entries: [EntryModel], entryLabel: KeyPath<EntryModel, String>) -> some View {
        accessibilityRotor(rotorLabel, entries: entries, entryID: \.id, entryLabel: entryLabel)
    }
    public func accessibilityRotor<EntryModel: Identifiable>(_ rotorLabelKey: LocalizedStringKey, entries: [EntryModel], entryLabel: KeyPath<EntryModel, String>) -> some View {
        accessibilityRotor(Text(rotorLabelKey), entries: entries, entryID: \.id, entryLabel: entryLabel)
    }
    public func accessibilityRotor<EntryModel: Identifiable>(_ systemRotor: AccessibilitySystemRotor, entries: [EntryModel], entryLabel: KeyPath<EntryModel, String>) -> some View {
        accessibilityRotor(systemRotor, entries: entries, entryID: \.id, entryLabel: entryLabel)
    }
    @_disfavoredOverload
    public func accessibilityRotor<L: StringProtocol, EntryModel: Identifiable>(_ rotorLabel: L, entries: [EntryModel], entryLabel: KeyPath<EntryModel, String>) -> some View {
        accessibilityRotor(Text(rotorLabel), entries: entries, entryID: \.id, entryLabel: entryLabel)
    }
    @_disfavoredOverload
    public func accessibilityRotor<EntryModel: Identifiable>(_ rotorLabelResource: LocalizedStringResource, entries: [EntryModel], entryLabel: KeyPath<EntryModel, String>) -> some View {
        accessibilityRotor(Text(rotorLabelResource), entries: entries, entryID: \.id, entryLabel: entryLabel)
    }
    // text ranges of this element
    public func accessibilityRotor(_ label: Text, textRanges: [Range<String.Index>]) -> some View {
        _rotor(name: label.string, system: nil) { textRanges.map { _ in _RotorEntryInfo(label: "", id: nil, namespace: nil, prepare: {}) } }
    }
    public func accessibilityRotor(_ labelKey: LocalizedStringKey, textRanges: [Range<String.Index>]) -> some View { accessibilityRotor(Text(labelKey), textRanges: textRanges) }
    public func accessibilityRotor(_ systemRotor: AccessibilitySystemRotor, textRanges: [Range<String.Index>]) -> some View {
        _rotor(name: "", system: systemRotor.type) { textRanges.map { _ in _RotorEntryInfo(label: "", id: nil, namespace: nil, prepare: {}) } }
    }
    @_disfavoredOverload
    public func accessibilityRotor<L: StringProtocol>(_ label: L, textRanges: [Range<String.Index>]) -> some View { accessibilityRotor(Text(label), textRanges: textRanges) }
    @_disfavoredOverload
    public func accessibilityRotor(_ label: LocalizedStringResource, textRanges: [Range<String.Index>]) -> some View { accessibilityRotor(Text(label), textRanges: textRanges) }
}
