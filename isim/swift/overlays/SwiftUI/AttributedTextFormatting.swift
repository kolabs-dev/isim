// isim SwiftUI (iOS 26): rich text formatting definitions — `AttributedTextFormattingDefinition`,
// `AttributedTextValueConstraint`, `AttributedTextFormatting` (ValueConstraint, the definition builder, the
// attribute container proxy, Transferable) and `View.attributedTextFormattingDefinition(_:)`.
// Adapted: an attributed TextEditor (AttributedEditor.swift) under a definition applies its constraints to every run of
// its text after each edit and when its text is set: each constraint sees a run's attributes in the definition's
// scope and decides the value of its own attribute.
import UIKit
import CoreTransferable
import UniformTypeIdentifiers

/// Which attributes an attributed text editor's text may have, and how they are constrained.
@available(iOS 26.0, *)
public protocol AttributedTextFormattingDefinition<Scope> {
    associatedtype Scope: AttributeScope
    associatedtype Body: AttributedTextFormattingDefinition<Scope>
    @AttributedTextFormatting.DefinitionBuilder<Scope> var body: Body { get }
}

/// A constraint on one attribute's value.
@available(iOS 26.0, *)
public protocol AttributedTextValueConstraint<Scope>: AttributedTextFormattingDefinition where Body == Self {
    associatedtype AttributeKey: AttributedStringKey where AttributeKey.Value: Sendable
    typealias Attributes = AttributedTextFormatting.AttributeContainerProxy<Scope>
    /// Sets the constrained attribute's value from the run's attributes.
    func constrain(_ container: inout Attributes)
}
@available(iOS 26.0, *)
extension AttributedTextValueConstraint {
    public var body: Self { self }
}
@available(iOS 26.0, *)
extension AttributedTextFormattingDefinition {
    /// A constraint allowing `values` of an attribute (others become `default`).
    public typealias ValueConstraint<AttributeKey: AttributedStringKey> = AttributedTextFormatting.ValueConstraint<Scope, AttributeKey>
        where AttributeKey.Value: Hashable & Sendable
}

@available(iOS 26.0, *)
public enum AttributedTextFormatting {
    /// A run's attributes, by the scope's key paths.
    @dynamicMemberLookup
    public struct AttributeContainerProxy<Scope: AttributeScope> {
        var container: AttributeContainer
        init(_ container: AttributeContainer) { self.container = container }
        public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<Scope, K>) -> K.Value? where K.Value: Sendable {
            get { container[K.self] }
            set { container[K.self] = newValue }
        }
        public subscript<K: AttributedStringKey>(_ key: K.Type) -> K.Value? where K.Value: Sendable {
            get { container[K.self] }
            set { container[K.self] = newValue }
        }
        /// The attributes of a nested scope (`container.swiftUI`).
        public subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> Scoped<S> {
            get { Scoped(container: container) }
            set { container = newValue.container }
        }
        @dynamicMemberLookup
        public struct Scoped<S: AttributeScope> {
            var container: AttributeContainer
            public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<S, K>) -> K.Value? where K.Value: Sendable {
                get { container[K.self] }
                set { container[K.self] = newValue }
            }
        }
    }

    /// Allows only some values of an attribute; any other value becomes `default`.
    public struct ValueConstraint<Scope: AttributeScope, AttributeKey: AttributedStringKey>: AttributedTextValueConstraint
        where AttributeKey.Value: Hashable & Sendable {
        let values: Set<AttributeKey.Value>
        let defaultValue: AttributeKey.Value?
        public init(for key: KeyPath<Scope, AttributeKey>, values: Set<AttributeKey.Value>, default: AttributeKey.Value?) {
            self.values = values; defaultValue = `default`
        }
        public func constrain(_ container: inout Attributes) {
            if let v = container[AttributeKey.self], values.contains(v) { return }
            container[AttributeKey.self] = defaultValue
        }
    }

    /// No constraints.
    public struct EmptyDefinition<Scope: AttributeScope>: AttributedTextFormattingDefinition, _DefinitionGroup {
        public init() {}
        public var body: Self { self }
        var _members: [any AttributedTextFormattingDefinition] { [] }
    }
    /// Several definitions together.
    public struct TupleDefinition<Scope: AttributeScope, each Definition: AttributedTextFormattingDefinition>: AttributedTextFormattingDefinition, _DefinitionGroup {
        let definitions: (repeat each Definition)
        public init(definition: repeat each Definition) { definitions = (repeat each definition) }
        public var body: Self { self }
        var _members: [any AttributedTextFormattingDefinition] {
            var out: [any AttributedTextFormattingDefinition] = []
            for d in repeat each definitions { out.append(d) }
            return out
        }
    }
    /// A definition, type-erased.
    public struct AnyDefinition<Scope: AttributeScope>: AttributedTextFormattingDefinition, _DefinitionGroup {
        let base: any AttributedTextFormattingDefinition
        public init<D: AttributedTextFormattingDefinition>(_ definition: D) where D.Scope == Scope { base = definition }
        public var body: Self { self }
        var _members: [any AttributedTextFormattingDefinition] { [base] }
    }

    @resultBuilder
    public struct DefinitionBuilder<Scope: AttributeScope> {
        public static func buildBlock<S: AttributeScope>() -> EmptyDefinition<S> { EmptyDefinition() }
        public static func buildBlock<D: AttributedTextFormattingDefinition>(_ d: D) -> D { d }
        public static func buildBlock<F: AttributedTextFormattingDefinition, each D: AttributedTextFormattingDefinition>(_ first: F, _ rest: repeat each D)
            -> TupleDefinition<F.Scope, F, repeat each D> {
            TupleDefinition(definition: first, repeat each rest)
        }
        public static func buildExpression<D: AttributedTextFormattingDefinition>(_ d: D) -> D { d }
        public static func buildIf<D: AttributedTextFormattingDefinition>(_ d: D?) -> D? { d }
        // (Apple's returns _ConditionalContent<T, F>; isim's _ConditionalContent is a View only, and widening it would
        // change every SwiftUI app's ABI: a type-erased definition instead)
        public static func buildEither<T: AttributedTextFormattingDefinition>(first: T) -> AnyDefinition<T.Scope> { AnyDefinition(first) }
        public static func buildEither<F: AttributedTextFormattingDefinition>(second: F) -> AnyDefinition<F.Scope> { AnyDefinition(second) }
        public static func buildLimitedAvailability<D: AttributedTextFormattingDefinition>(_ d: D) -> AnyDefinition<Scope> where D.Scope == Scope {
            AnyDefinition(d)
        }
    }

    /// Attributed text for copy and paste: its plain characters and its attributes as an RTF-like archive (isim:
    /// the characters as plain text).
    public struct Transferable: CoreTransferable.Transferable, Sendable {
        let text: AttributedString
        public init(text: AttributedString, in environment: EnvironmentValues) { self.text = text }
        public static var transferRepresentation: some TransferRepresentation {
            ProxyRepresentation(exporting: { (t: AttributedTextFormatting.Transferable) in String(t.text.characters) })
        }
    }
}

@available(iOS 26.0, *)
extension Optional: AttributedTextFormattingDefinition where Wrapped: AttributedTextFormattingDefinition {
    public typealias Scope = Wrapped.Scope
    public var body: Self { self }
}
@available(iOS 26.0, *)
extension Optional: _DefinitionGroup where Wrapped: AttributedTextFormattingDefinition {
    var _members: [any AttributedTextFormattingDefinition] { map { [$0] } ?? [] }
}
/// Definitions made of other definitions (isim walks them for their constraints).
@available(iOS 26.0, *)
protocol _DefinitionGroup { var _members: [any AttributedTextFormattingDefinition] { get } }

/// One constraint, type-erased: applied to a run's attributes.
struct _AnyValueConstraint {
    let apply: (inout AttributeContainer) -> Void
}
@available(iOS 26.0, *)
func _openConstraint<C: AttributedTextValueConstraint>(_ c: C) -> _AnyValueConstraint {
    _AnyValueConstraint { container in
        var proxy = AttributedTextFormatting.AttributeContainerProxy<C.Scope>(container)
        c.constrain(&proxy)
        container[C.AttributeKey.self] = proxy.container[C.AttributeKey.self]        // (only its own attribute)
    }
}
@available(iOS 26.0, *)
func _definitionBody<D: AttributedTextFormattingDefinition>(_ d: D) -> any AttributedTextFormattingDefinition { d.body }
/// Every constraint in a definition, in order.
@available(iOS 26.0, *)
func _constraints(_ d: any AttributedTextFormattingDefinition) -> [_AnyValueConstraint] {
    if let g = d as? _DefinitionGroup { return g._members.flatMap(_constraints) }
    if let c = d as? any AttributedTextValueConstraint { return [_openConstraint(c)] }
    return _constraints(_definitionBody(d))
}
/// Applies the constraints to every run of `text`.
func _constrain(_ text: inout AttributedString, _ constraints: [_AnyValueConstraint]) {
    guard !constraints.isEmpty else { return }
    for run in text.runs {
        var attrs = run.attributes
        let before = attrs
        for c in constraints { c.apply(&attrs) }
        if attrs != before { text[run.range].setAttributes(attrs) }
    }
}

struct _FormattingDefinitionKey: EnvironmentKey { static var defaultValue: [_AnyValueConstraint]? { nil } }
extension EnvironmentValues {
    var _formattingConstraints: [_AnyValueConstraint]? {
        get { self[_FormattingDefinitionKey.self] }
        set { self[_FormattingDefinitionKey.self] = newValue }
    }
}
extension View {
    /// Constrains the attributes of the rich text that attributed text editors in this view edit.
    @available(iOS 26.0, *)
    public func attributedTextFormattingDefinition<D: AttributedTextFormattingDefinition>(_ definition: D) -> some View {
        _env { $0._formattingConstraints = _constraints(definition) }
    }
}
