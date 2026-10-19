// isim SwiftUI: container styles — GroupBoxStyle, DisclosureGroupStyle, LabeledContentStyle (a custom style's body
// gets the container's label and content in its configuration; `GroupBox(configuration)` / `LabeledContent(configuration)`
// draw them the default way), EquatableView / equatable(), and @FocusedObject with focusedObject / focusedSceneObject.
import UIKit
import Combine

struct _AnyContainerStyle { let make: @MainActor (Any) -> any View }
struct _GroupBoxStyleKey: EnvironmentKey { static var defaultValue: _AnyContainerStyle? { nil } }
struct _DisclosureGroupStyleKey: EnvironmentKey { static var defaultValue: _AnyContainerStyle? { nil } }
struct _LabeledContentStyleKey: EnvironmentKey { static var defaultValue: _AnyContainerStyle? { nil } }
extension EnvironmentValues {
    var _groupBoxStyle: _AnyContainerStyle? { get { self[_GroupBoxStyleKey.self] } set { self[_GroupBoxStyleKey.self] = newValue } }
    var _disclosureGroupStyle: _AnyContainerStyle? { get { self[_DisclosureGroupStyleKey.self] } set { self[_DisclosureGroupStyleKey.self] = newValue } }
    var _labeledContentStyle: _AnyContainerStyle? { get { self[_LabeledContentStyleKey.self] } set { self[_LabeledContentStyleKey.self] = newValue } }
}

// MARK: - GroupBoxStyle

public struct GroupBoxStyleConfiguration {
    public struct Label: View, _PrimitiveView {
        let make: @MainActor (_Context) -> _Node
        public var body: Never { fatalError() }
        func _makeNode(_ ctx: _Context) -> _Node { make(ctx) }
    }
    public struct Content: View, _PrimitiveView {
        let make: @MainActor (_Context) -> _Node
        public var body: Never { fatalError() }
        func _makeNode(_ ctx: _Context) -> _Node { make(ctx) }
    }
    public let label: Label
    public let content: Content
}
public protocol GroupBoxStyle {
    associatedtype Body: View
    typealias Configuration = GroupBoxStyleConfiguration
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body
}
/// iOS's group box: a rounded secondary background, the label in headline type above the content.
public struct DefaultGroupBoxStyle: GroupBoxStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { GroupBox(configuration) }
}
extension GroupBoxStyle where Self == DefaultGroupBoxStyle { public static var automatic: DefaultGroupBoxStyle { .init() } }
extension GroupBox where Label == GroupBoxStyleConfiguration.Label, Content == GroupBoxStyleConfiguration.Content {
    public init(_ configuration: GroupBoxStyleConfiguration) { self.content = configuration.content; self.label = configuration.label }
}
extension View {
    public func groupBoxStyle<S: GroupBoxStyle>(_ style: S) -> some View {
        _env { $0._groupBoxStyle = _AnyContainerStyle(make: { style.makeBody(configuration: $0 as! GroupBoxStyleConfiguration) }) }
    }
}
/// GroupBox's body: the style around (with the label and content), or the default look.
struct _GroupBoxBody: View, _PrimitiveView {
    let label: AnyView?, content: AnyView
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        if let style = ctx.environment._groupBoxStyle {
            let label = self.label ?? AnyView(EmptyView()), content = self.content
            let config = GroupBoxStyleConfiguration(label: .init(make: { _resolve(label, $0) }), content: .init(make: { _resolve(content, $0) }))
            return _resolve(style.make(config), ctx.child("gbstyle").with { $0._groupBoxStyle = nil })
        }
        let box = VStack(alignment: .leading, spacing: 8) {
            if let label { label.font(.headline) }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color("groupbox") { .secondarySystemBackground }, in: RoundedRectangle(cornerRadius: 10))
        return _resolve(box, ctx)
    }
}

// MARK: - DisclosureGroupStyle

public struct DisclosureGroupStyleConfiguration {
    public struct Label: View, _PrimitiveView {
        let make: @MainActor (_Context) -> _Node
        public var body: Never { fatalError() }
        func _makeNode(_ ctx: _Context) -> _Node { make(ctx) }
    }
    public struct Content: View, _PrimitiveView {
        let make: @MainActor (_Context) -> _Node
        public var body: Never { fatalError() }
        func _makeNode(_ ctx: _Context) -> _Node { make(ctx) }
    }
    public let label: Label
    public let content: Content
    /// Whether the group is expanded (`$isExpanded` is its binding).
    @Binding public var isExpanded: Bool
}
public protocol DisclosureGroupStyle {
    associatedtype Body: View
    typealias Configuration = DisclosureGroupStyleConfiguration
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body
}
/// iOS's disclosure group: the label with a chevron that turns; the content below while expanded.
public struct AutomaticDisclosureGroupStyle: DisclosureGroupStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        DisclosureGroup(isExpanded: configuration.$isExpanded) { configuration.content } label: { configuration.label }
    }
}
extension DisclosureGroupStyle where Self == AutomaticDisclosureGroupStyle { public static var automatic: AutomaticDisclosureGroupStyle { .init() } }
extension View {
    public func disclosureGroupStyle<S: DisclosureGroupStyle>(_ style: S) -> some View {
        _env { $0._disclosureGroupStyle = _AnyContainerStyle(make: { style.makeBody(configuration: $0 as! DisclosureGroupStyleConfiguration) }) }
    }
}

// MARK: - LabeledContentStyle

public struct LabeledContentStyleConfiguration {
    public struct Label: View, _PrimitiveView {
        let make: @MainActor (_Context) -> _Node
        public var body: Never { fatalError() }
        func _makeNode(_ ctx: _Context) -> _Node { make(ctx) }
    }
    public struct Content: View, _PrimitiveView {
        let make: @MainActor (_Context) -> _Node
        public var body: Never { fatalError() }
        func _makeNode(_ ctx: _Context) -> _Node { make(ctx) }
    }
    public let label: Label
    public let content: Content
}
public protocol LabeledContentStyle {
    associatedtype Body: View
    typealias Configuration = LabeledContentStyleConfiguration
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body
}
/// iOS's labeled content: the label leading, the content trailing in secondary color.
public struct AutomaticLabeledContentStyle: LabeledContentStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { LabeledContent(configuration) }
}
extension LabeledContentStyle where Self == AutomaticLabeledContentStyle { public static var automatic: AutomaticLabeledContentStyle { .init() } }
extension LabeledContent where Label == LabeledContentStyleConfiguration.Label, Content == LabeledContentStyleConfiguration.Content {
    public init(_ configuration: LabeledContentStyleConfiguration) { self.label = configuration.label; self.content = configuration.content }
}
extension View {
    public func labeledContentStyle<S: LabeledContentStyle>(_ style: S) -> some View {
        _env { $0._labeledContentStyle = _AnyContainerStyle(make: { style.makeBody(configuration: $0 as! LabeledContentStyleConfiguration) }) }
    }
}

// MARK: - EquatableView

/// A view that SwiftUI re-evaluates only when it is not equal to its previous value. isim (adapted): the content
/// is evaluated on every update; what it shows is the same.
public struct EquatableView<Content: Equatable & View>: View {
    public var content: Content
    public init(content: Content) { self.content = content }
    public var body: some View { content }
}
extension View where Self: Equatable {
    public func equatable() -> EquatableView<Self> { EquatableView(content: self) }
}

// MARK: - FocusedObject

enum _FocusedObjectKey<T> {}
/// The observable object a focused view (or the scene) published with focusedObject / focusedSceneObject.
@propertyWrapper public struct FocusedObject<ObjectType: ObservableObject>: DynamicProperty {
    @dynamicMemberLookup public struct Wrapper {
        let object: ObjectType
        public subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, T>) -> Binding<T> {
            let o = object
            return Binding(get: { o[keyPath: keyPath] }, set: { o[keyPath: keyPath] = $0 })
        }
    }
    public init() {}
    @MainActor public var wrappedValue: ObjectType? { _FocusedStore.shared.current.values[ObjectIdentifier(_FocusedObjectKey<ObjectType>.self)] as? ObjectType }
    @MainActor public var projectedValue: Wrapper? { wrappedValue.map { Wrapper(object: $0) } }
}
extension View {
    /// The object @FocusedObject sees while this view, or one inside it, has focus.
    public func focusedObject<T: ObservableObject>(_ object: T) -> some View { _focusedObject(object, scene: false) }
    public func focusedObject<T: ObservableObject>(_ object: T?) -> some View { _focusedObject(object, scene: false) }
    /// The object @FocusedObject sees while the scene is shown.
    public func focusedSceneObject<T: ObservableObject>(_ object: T) -> some View { _focusedObject(object, scene: true) }
    public func focusedSceneObject<T: ObservableObject>(_ object: T?) -> some View { _focusedObject(object, scene: true) }
    func _focusedObject<T: ObservableObject>(_ object: T?, scene: Bool) -> some View {
        _modify { ctx, c in
            let st = _FocusedStore.shared
            st.note(ctx.graph)
            if let object { st.add(ctx.graph, .init(path: ctx.path, key: ObjectIdentifier(_FocusedObjectKey<T>.self), value: object, scene: scene)) }
            return _resolve(c, ctx.child("fo"))
        }
    }
}
