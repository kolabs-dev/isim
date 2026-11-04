// isim AppIntents: Apple's value model (issue #850). Every value a parameter or an entity property can hold conforms to
// _IntentValue: its ValueType is the value once optionality and collections are taken away (Int for Int?, the entity
// for [Entity]), its UnwrappedType the value without the optional ([Entity] for [Entity]?), its Specification the
// resolvers that turn other values into it. Apple's initializer overloads of IntentParameter, EntityProperty and
// IntentParameterContext (ParameterOverloads.swift, generated) are constrained on them
// (`where Value.ValueType == Int`), so an app's `@Parameter var count: Int` picks the Int overloads (control styles,
// ranges), `[Entity]` the collection ones. AppEntity and AppEnum refine it, as in Apple's SDK (since isim 0.35: apps
// built with 0.34 or earlier that use AppIntents must be rebuilt; isim/abi/epochs.txt).
// Also here: the resolver protocols and builder, and the small value and option types the overloads take.
import Foundation
import CoreLocation
import SwiftUI

/// A value an intent parameter or entity property holds (Apple's underscored protocol, which their API names).
public protocol _IntentValue {
    /// the value without optionality and collections (Int for Int?, Entity for [Entity])
    associatedtype ValueType: _IntentValue = Self
    /// the value without optionality ([Entity] for [Entity]?)
    associatedtype UnwrappedType: _IntentValue = Self
    /// the resolvers that make this value from others
    associatedtype Specification: ResolverSpecification = EmptyResolverSpecification<Self>
    static var defaultResolverSpecification: Specification { get }
}
extension _IntentValue where Specification == EmptyResolverSpecification<Self> {
    public static var defaultResolverSpecification: EmptyResolverSpecification<Self> { EmptyResolverSpecification() }
}
/// A value that can stand for an intent value (a Transferable, a custom value type); Apple's protocol.
public protocol _IntentValueRepresentable {}
/// A value the system's own intents take (Apple's protocol).
public protocol _SystemIntentValue: _IntentValue {}

extension Optional: _IntentValue where Wrapped: _IntentValue {
    public typealias ValueType = Wrapped.ValueType
    public typealias UnwrappedType = Wrapped
}
extension Array: _IntentValue where Element: _IntentValue {
    public typealias ValueType = Element.ValueType
    public typealias UnwrappedType = [Element]
}

extension String: _IntentValue {}
extension Int: _IntentValue {}
extension Double: _IntentValue {}
extension Bool: _IntentValue {}
extension Date: _IntentValue {}
extension DateComponents: _IntentValue {}
extension URL: _IntentValue {}
extension AttributedString: _IntentValue {}
extension Duration: _IntentValue {}
extension Measurement: _IntentValue {}
extension Calendar.RecurrenceRule: _IntentValue {}
extension CLPlacemark: _IntentValue {}
extension IntentPerson: _IntentValue {}
extension IntentFile: _IntentValue {}
extension IntentCurrencyAmount: _IntentValue {}

// MARK: - resolvers

/// Turns one kind of value into a parameter's value (`@Parameter(…) { SomeResolver() }`).
public protocol Resolver: Hashable, Sendable {
    associatedtype Input: _IntentValue
    associatedtype Output: _IntentValue, Sendable
    func resolve(from input: Input, context: IntentParameterContext<Output>) async throws -> Output?
}
/// The resolvers of a parameter, in order.
public protocol ResolverSpecification: Hashable, Sendable, Sequence where Element == any Resolver {}

/// No resolvers: the value is taken as given.
public struct EmptyResolverSpecification<Value>: ResolverSpecification where Value: _IntentValue {
    public init() {}
    public func makeIterator() -> IndexingIterator<[any Resolver]> { [any Resolver]().makeIterator() }
}

/// a resolver list a builder made
public struct _IsimResolverList: ResolverSpecification {
    let resolvers: [any Resolver]
    init(_ resolvers: [any Resolver]) { self.resolvers = resolvers }
    public func makeIterator() -> IndexingIterator<[any Resolver]> { resolvers.makeIterator() }
    public static func == (a: Self, b: Self) -> Bool { a.resolvers.map { AnyHashable($0) } == b.resolvers.map { AnyHashable($0) } }
    public func hash(into h: inout Hasher) { for r in resolvers { h.combine(AnyHashable(r)) } }
}

/// Builds a parameter's resolvers (`resolvers:` of the IntentParameter overloads).
@resultBuilder public enum ResolverSpecificationBuilder<Property> where Property: _IntentValue {
    /// the resolvers of one block, in order
    public struct Specification<Output, each R>: ResolverSpecification where Output: _IntentValue, repeat each R: Resolver {
        let resolvers: [any Resolver]
        init(_resolvers: [any Resolver]) { resolvers = _resolvers }
        public func makeIterator() -> IndexingIterator<[any Resolver]> { resolvers.makeIterator() }
        public static func == (a: Self, b: Self) -> Bool { a.resolvers.map { AnyHashable($0) } == b.resolvers.map { AnyHashable($0) } }
        public func hash(into h: inout Hasher) { for r in resolvers { h.combine(AnyHashable(r)) } }
    }
    public static func buildExpression<ResolverType>(_ expression: ResolverType) -> ResolverType
        where Property == ResolverType.Output, ResolverType: Resolver { expression }
    public static func buildPartialBlock<R>(first: R) -> Specification<Property, R> where R: Resolver { Specification(_resolvers: [first]) }
    public static func buildPartialBlock<each Accumulated, R>(accumulated: Specification<Property, repeat each Accumulated>, next: R)
        -> Specification<Property, repeat each Accumulated, R> where R: Resolver {
        Specification(_resolvers: accumulated.resolvers + [next])
    }
    public static func buildBlock() -> some ResolverSpecification { _IsimResolverList([]) }
    public static func buildBlock<R0>(_ r0: R0) -> some ResolverSpecification where R0: Resolver { _IsimResolverList([r0]) }
    public static func buildBlock<R0, R1>(_ r0: R0, _ r1: R1) -> some ResolverSpecification where R0: Resolver, R1: Resolver {
        _IsimResolverList([r0, r1])
    }
    public static func buildBlock<R0, R1, R2>(_ r0: R0, _ r1: R1, _ r2: R2) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver { _IsimResolverList([r0, r1, r2]) }
    public static func buildBlock<R0, R1, R2, R3>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver { _IsimResolverList([r0, r1, r2, r3]) }
    public static func buildBlock<R0, R1, R2, R3, R4>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver { _IsimResolverList([r0, r1, r2, r3, r4]) }
    public static func buildBlock<R0, R1, R2, R3, R4, R5>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver { _IsimResolverList([r0, r1, r2, r3, r4, r5]) }
    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5, _ r6: R6)
        -> some ResolverSpecification where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver {
        _IsimResolverList([r0, r1, r2, r3, r4, r5, r6])
    }
    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5, _ r6: R6, _ r7: R7)
        -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver, R7: Resolver {
        _IsimResolverList([r0, r1, r2, r3, r4, r5, r6, r7])
    }
    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5, _ r6: R6,
                                                                      _ r7: R7, _ r8: R8) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver, R7: Resolver, R8: Resolver {
        _IsimResolverList([r0, r1, r2, r3, r4, r5, r6, r7, r8])
    }
    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5, _ r6: R6,
                                                                          _ r7: R7, _ r8: R8, _ r9: R9) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver, R7: Resolver, R8: Resolver,
              R9: Resolver {
        _IsimResolverList([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9])
    }
    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5,
                                                                               _ r6: R6, _ r7: R7, _ r8: R8, _ r9: R9, _ r10: R10)
        -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver, R7: Resolver, R8: Resolver,
              R9: Resolver, R10: Resolver {
        _IsimResolverList([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10])
    }
    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4, _ r5: R5,
                                                                                    _ r6: R6, _ r7: R7, _ r8: R8, _ r9: R9, _ r10: R10,
                                                                                    _ r11: R11) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver, R7: Resolver, R8: Resolver,
              R9: Resolver, R10: Resolver, R11: Resolver {
        _IsimResolverList([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11])
    }
    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4,
                                                                                         _ r5: R5, _ r6: R6, _ r7: R7, _ r8: R8, _ r9: R9,
                                                                                         _ r10: R10, _ r11: R11, _ r12: R12)
        -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver, R7: Resolver, R8: Resolver,
              R9: Resolver, R10: Resolver, R11: Resolver, R12: Resolver {
        _IsimResolverList([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12])
    }
    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, R13>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3, _ r4: R4,
                                                                                              _ r5: R5, _ r6: R6, _ r7: R7, _ r8: R8,
                                                                                              _ r9: R9, _ r10: R10, _ r11: R11, _ r12: R12,
                                                                                              _ r13: R13) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver, R7: Resolver, R8: Resolver,
              R9: Resolver, R10: Resolver, R11: Resolver, R12: Resolver, R13: Resolver {
        _IsimResolverList([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13])
    }
    public static func buildBlock<R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, R13, R14>(_ r0: R0, _ r1: R1, _ r2: R2, _ r3: R3,
                                                                                                   _ r4: R4, _ r5: R5, _ r6: R6, _ r7: R7,
                                                                                                   _ r8: R8, _ r9: R9, _ r10: R10,
                                                                                                   _ r11: R11, _ r12: R12, _ r13: R13,
                                                                                                   _ r14: R14) -> some ResolverSpecification
        where R0: Resolver, R1: Resolver, R2: Resolver, R3: Resolver, R4: Resolver, R5: Resolver, R6: Resolver, R7: Resolver, R8: Resolver,
              R9: Resolver, R10: Resolver, R11: Resolver, R12: Resolver, R13: Resolver, R14: Resolver {
        _IsimResolverList([r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14])
    }
}

// MARK: - what the overloads take

/// Whether a parameter takes the previous action's result in Shortcuts.
public enum InputConnectionBehavior: Hashable, Sendable {
    case `default`, never, connectToPreviousIntentResult
}
/// How many values a collection parameter takes.
public struct IntentCollectionSize: Hashable, Sendable {
    let min: Int, max: Int
    public init(exactly: Int) { min = exactly; max = exactly }
    public init(min: Int, max: Int) { self.min = min; self.max = max }
}
/// A widget size, as a parameter's value (`size:` per family).
public enum IntentWidgetFamily: Hashable, Sendable, _IntentValue {
    case systemSmall, systemMedium, systemLarge, systemExtraLarge, systemExtraLargePortrait
    case accessoryCircular, accessoryRectangular, accessoryInline, accessoryCorner
}
/// A payment method (Apple Pay, a card, an account) as a parameter's value.
public struct IntentPaymentMethod: Hashable, Sendable, _IntentValue {
    public enum PaymentType: Hashable, Sendable { case unknown, checking, savings, brokerage, debit, credit, prepaid, store, applePay }
    public let paymentType: PaymentType
    public let name: String?
    public let identificationHint: String?
    public let icon: DisplayRepresentation.Image?
    public init(type: PaymentType, name: LocalizedStringResource? = nil, identificationHint: String? = nil, icon: DisplayRepresentation.Image? = nil) {
        paymentType = type; self.name = name?.description; self.identificationHint = identificationHint; self.icon = icon
    }
    public static func == (a: Self, b: Self) -> Bool { a.paymentType == b.paymentType && a.name == b.name && a.identificationHint == b.identificationHint }
    public func hash(into h: inout Hasher) { h.combine(paymentType); h.combine(name); h.combine(identificationHint) }
}
/// What the person searched for (a ShowInAppSearchResultsIntent's criteria).
public struct StringSearchCriteria: Hashable, Sendable, _IntentValue {
    public var term: String
    public init(term: String) { self.term = term }
}
/// Entities by identifier, resolved when needed (iOS 27): a parameter or property of many entities.
public struct EntityCollection<Entity>: @unchecked Sendable, _IntentValue where Entity: AppEntity {
    public typealias ValueType = Entity
    public typealias UnwrappedType = EntityCollection<Entity>
    public var identifiers: [Entity.ID]
    public init(identifiers: [Entity.ID] = []) { self.identifiers = identifiers }
    public init(entities: [Entity]) { identifiers = entities.map(\.id) }
    public var count: Int { identifiers.count }
    public var isEmpty: Bool { identifiers.isEmpty }
    public mutating func append(_ identifier: Entity.ID) { identifiers.append(identifier) }
    public mutating func append(_ entity: Entity) { identifiers.append(entity.id) }
    public mutating func append(contentsOf newIdentifiers: [Entity.ID]) { identifiers += newIdentifiers }
    public mutating func append(contentsOf entities: [Entity]) { identifiers += entities.map(\.id) }
    public mutating func remove(_ identifier: Entity.ID) { identifiers.removeAll { $0 == identifier } }
    public mutating func remove(_ entity: Entity) { remove(entity.id) }
    public func contains(_ identifier: Entity.ID) -> Bool { identifiers.contains(identifier) }
    public func contains(_ entity: Entity) -> Bool { contains(entity.id) }
    /// the entities, from the entity's default query
    public func resolvedEntities() async throws -> [Entity] {
        let ids = identifiers.compactMap { $0 as? Entity.DefaultQuery.Entity.ID }
        return try await Entity.defaultQuery.entities(for: ids).compactMap { $0 as? Entity }
    }
}
extension Bool {
    /// What a Boolean parameter's two values are called (“On” / “Off”).
    public struct IntentDisplayName: Sendable {
        public let `true`: LocalizedStringResource
        public let `false`: LocalizedStringResource
        public init(true: LocalizedStringResource, false: LocalizedStringResource) { self.true = `true`; self.false = `false` }
    }
}
extension String {
    /// The keyboard and editing options of a String parameter's text field.
    public struct IntentInputOptions: Sendable {
        public enum KeyboardType: Hashable, Sendable { case `default`, asciiCapable, numbersAndPunctuation, URL, numberPad }
        public enum CapitalizationType: Hashable, Sendable { case none, sentences, words, allCharacters }
        public var keyboardType: KeyboardType
        public var capitalizationType: CapitalizationType
        public var multiline: Bool
        public var autocorrect: Bool
        public var smartQuotes: Bool
        public var smartDashes: Bool
        public init(keyboardType: KeyboardType = .default, capitalizationType: CapitalizationType = .sentences, multiline: Bool = false,
                    autocorrect: Bool = true, smartQuotes: Bool = true, smartDashes: Bool = true) {
            self.keyboardType = keyboardType; self.capitalizationType = capitalizationType; self.multiline = multiline
            self.autocorrect = autocorrect; self.smartQuotes = smartQuotes; self.smartDashes = smartDashes
        }
    }
}

// MARK: - IntentParameterContext

/// What a resolver knows about the parameter it resolves for: its options (control style, range, unit, …), and the
/// requests it can make of the person.
public struct IntentParameterContext<Value>: @unchecked Sendable where Value: _IntentValue, Value: Sendable {
    let _parameter: IntentParameter<Value>?
    let _options: [String: Any]
    init(_ parameter: IntentParameter<Value>?) { _parameter = parameter; _options = parameter?._options ?? [:] }
    func _isimOption<T>(_ keys: String...) -> T? {
        for k in keys { if let v = _options[k] as? T { return v } }
        return nil
    }
    @MainActor public func requestValue(_ dialog: IntentDialog? = nil) async throws -> Value.ValueType {
        guard let p = _parameter else { throw _IsimIntentError.noRun }
        return try await p.requestValue(dialog)
    }
    @MainActor public func requestDisambiguation(among itemsToDisambiguate: [Value.ValueType], dialog: IntentDialog? = nil) async throws -> Value.ValueType {
        guard let p = _parameter else { throw _IsimIntentError.noRun }
        return try await p.requestDisambiguation(among: itemsToDisambiguate, dialog: dialog)
    }
    @MainActor public func requestConfirmation(for itemToConfirm: Value.ValueType, dialog: IntentDialog? = nil) async throws -> Bool {
        guard let p = _parameter else { throw _IsimIntentError.noRun }
        return try await p.requestConfirmation(for: itemToConfirm, dialog: dialog)
    }
    @MainActor public func requestConfirmation<ViewType: View>(for itemToConfirm: Value.ValueType, dialog: IntentDialog? = nil, view: ViewType) async throws -> Bool {
        guard let p = _parameter else { throw _IsimIntentError.noRun }
        return try await p.requestConfirmation(for: itemToConfirm, dialog: dialog, view: view)
    }
    @MainActor public func requestConfirmation<ViewType: View>(for itemToConfirm: Value.ValueType, dialog: IntentDialog? = nil,
                                                               @ViewBuilder view: () -> ViewType) async throws -> Bool {
        guard let p = _parameter else { throw _IsimIntentError.noRun }
        return try await p.requestConfirmation(for: itemToConfirm, dialog: dialog, view: view())
    }
    public func needsValueError(_ dialog: IntentDialog? = nil) -> AppIntentError {
        _parameter?.needsValueError(dialog) ?? AppIntentError(code: "needsValue", message: dialog?.text ?? "")
    }
    public func needsDisambiguationError(among itemsToDisambiguate: [Value.ValueType], dialog: IntentDialog? = nil) -> AppIntentError {
        _parameter?.needsDisambiguationError(among: itemsToDisambiguate, dialog: dialog) ?? AppIntentError(code: "needsValue", message: dialog?.text ?? "")
    }
}

// MARK: - durations

extension IntentParameter.DurationUnit {
    /// a Swift Duration of `v` of this unit
    func _isimDuration(_ v: Double) -> Swift.Duration {
        switch self {
        case .hours: return .seconds(v * 3600)
        case .minutes: return .seconds(v * 60)
        case .seconds: return .seconds(v)
        case .milliseconds: return .seconds(v / 1e3)
        case .microseconds: return .seconds(v / 1e6)
        case .nanoseconds: return .seconds(v / 1e9)
        case .picoseconds: return .seconds(v / 1e12)
        }
    }
}
