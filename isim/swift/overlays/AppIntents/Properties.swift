// isim AppIntents: entity properties and the queries over them, dependencies, parameter summaries, dynamic options, the
// framework's errors and value types (self-authored, iOS API names). What the system does with them is in System.swift:
// properties and summaries go into the metadata the home screen reads (Shortcuts' "Get Details" and its action
// sentences), options providers fill the choices Siri and Shortcuts offer, EntityPropertyQuery answers "Find" requests,
// and AppIntentError's messages are the failure dialogs.
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - entity properties

/// A property of an AppEntity the system can show, filter and sort by (`@Property(title:)` in an entity).
@propertyWrapper
public final class EntityProperty<Value>: @unchecked Sendable {
    var _value: Value?
    let _title: LocalizedStringResource?
    let _identifier: String?
    public var wrappedValue: Value {
        get {
            if let v = _value { return v }
            if let none = (Value.self as? _IsimOptional.Type)?._isimNone as? Value { return none }
            fatalError("isim AppIntents: the entity property “\(_title?.description ?? _identifier ?? "")” has no value")
        }
        set { _value = newValue }
    }
    public var projectedValue: EntityProperty<Value> { self }
    init(_title: LocalizedStringResource?, identifier: String?, value: Value?) { self._title = _title; _identifier = identifier; _value = value }
    public convenience init() { self.init(_title: nil, identifier: nil, value: nil) }
    public convenience init(title: LocalizedStringResource) { self.init(_title: title, identifier: nil, value: nil) }
    public convenience init(identifier: String) { self.init(_title: nil, identifier: identifier, value: nil) }
    public convenience init(identifier: String, title: LocalizedStringResource) { self.init(_title: title, identifier: identifier, value: nil) }
    public convenience init(wrappedValue: Value) { self.init(_title: nil, identifier: nil, value: wrappedValue) }
    public convenience init(wrappedValue: Value, title: LocalizedStringResource) { self.init(_title: title, identifier: nil, value: wrappedValue) }
    public convenience init(wrappedValue: Value, identifier: String, title: LocalizedStringResource) {
        self.init(_title: title, identifier: identifier, value: wrappedValue)
    }
}
extension AppEntity {
    public typealias Property<Value> = EntityProperty<Value>
}
/// Options of an entity property (iOS 26).
public struct EntityPropertyModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let async = EntityPropertyModifiers(rawValue: 1)
    public static let readOnly = EntityPropertyModifiers(rawValue: 2)
}
/// an entity property seen without its value type (System.swift)
protocol _IsimAnyEntityProperty: AnyObject {
    var _isimTitle: String? { get }
    var _isimCurrent: Any? { get }
}
extension EntityProperty: _IsimAnyEntityProperty {
    var _isimTitle: String? { _title?.description ?? _identifier }
    var _isimCurrent: Any? {
        guard let v = _value else { return nil }
        if let o = v as? _IsimOptional { return o._isimUnwrapped }
        return v
    }
}

/// `@ComputedProperty` (iOS 26): a computed entity property the system can read. isim accepts it (the property works in
/// the app); it is not listed in the metadata.
@available(iOS 26.0, *)
@attached(peer)
public macro ComputedProperty() = #externalMacro(module: "SwiftDataMacros", type: "NoOpPropertyMacro")
@available(iOS 26.0, *)
@attached(peer)
public macro ComputedProperty(title: LocalizedStringResource) = #externalMacro(module: "SwiftDataMacros", type: "NoOpPropertyMacro")

// MARK: - dependencies

/// A value the app registers once (AppDependencyManager) and intents, queries and providers use (`@Dependency`).
@propertyWrapper
public final class AppDependency<Value>: @unchecked Sendable {
    let key: AnyHashable?
    let manager: AppDependencyManager
    let fallback: (() async throws -> Value)?
    init(_key key: AnyHashable?, manager: AppDependencyManager, fallback: (() async throws -> Value)?) {
        self.key = key; self.manager = manager; self.fallback = fallback
    }
    public convenience init(key: AnyHashable? = nil, manager: AppDependencyManager = .shared) {
        self.init(_key: key, manager: manager, fallback: nil)
    }
    public convenience init(key: AnyHashable? = nil, manager: AppDependencyManager = .shared, default: @escaping () async throws -> Value) {
        self.init(_key: key, manager: manager, fallback: `default`)
    }
    public convenience init(key: AnyHashable? = nil, manager: AppDependencyManager = .shared, default: @autoclosure @escaping () -> Value) {
        self.init(_key: key, manager: manager, fallback: { `default`() })
    }
    public var wrappedValue: Value {
        do {
            if let v: Value = try manager._resolve(key) { return v }
            if let fallback { return try _isimWait(fallback) }
            throw AppDependencyManager.Error.failedToRetrieveDependency(key ?? AnyHashable(String(reflecting: Value.self)), Value.self)
        } catch {
            fatalError("isim AppIntents: \(error) (add the dependency with AppDependencyManager.shared.add)")
        }
    }
    public var projectedValue: AppDependency<Value> { self }
}
/// `@Dependency` in intents, queries and options providers
public typealias Dependency<Value> = AppDependency<Value>

/// Where an app registers its dependencies: each is made once, when first used.
public final class AppDependencyManager: @unchecked Sendable {
    public static let shared = AppDependencyManager()
    public enum Error: Swift.Error, @unchecked Sendable, CustomStringConvertible {
        case failedToLoadDependency(AnyHashable, any Any.Type)
        case failedToRetrieveDependency(AnyHashable, any Any.Type)
        case incorrectDependencyType(AnyHashable, any Any.Type, any Any.Type)
        public var description: String {
            switch self {
            case .failedToLoadDependency(let k, let t): return "failed to load the dependency \(t) (\(k))"
            case .failedToRetrieveDependency(let k, let t): return "no dependency \(t) (\(k))"
            case .incorrectDependencyType(let k, let t, let got): return "the dependency \(k) is a \(got), not a \(t)"
            }
        }
    }
    private let lock = NSRecursiveLock()
    private var makers: [String: () async throws -> Any] = [:]
    private var made: [String: Any] = [:]
    public init() {}
    private func id(_ t: Any.Type, _ key: AnyHashable?) -> String { key.map { "#\($0)" } ?? String(reflecting: t) }
    private func register(_ t: Any.Type, _ key: AnyHashable?, _ make: @escaping () async throws -> Any) {
        lock.lock(); defer { lock.unlock() }
        let k = id(t, key)
        makers[k] = make; made[k] = nil
    }
    public func add<Dependency>(key: AnyHashable? = nil, dependency: @autoclosure @escaping () -> Dependency) {
        register(Dependency.self, key) { dependency() }
    }
    public func add<Dependency>(key: AnyHashable? = nil, dependency: @autoclosure @escaping () -> () throws -> Dependency) {
        let make = dependency()
        register(Dependency.self, key) { try make() }
    }
    public func add<Dependency>(key: AnyHashable? = nil, dependency: @escaping () async throws -> Dependency) {
        register(Dependency.self, key) { try await dependency() }
    }
    /// the dependency of the type (or key), made the first time; nil when none was added
    func _resolve<T>(_ key: AnyHashable?) throws -> T? {
        lock.lock(); defer { lock.unlock() }
        let k = id(T.self, key)
        if let v = made[k] {
            guard let t = v as? T else { throw Error.incorrectDependencyType(key ?? AnyHashable(k), T.self, type(of: v)) }
            return t
        }
        guard let make = makers[k] else { return nil }
        let v: Any
        do { v = try _isimWait(make) } catch { throw Error.failedToLoadDependency(key ?? AnyHashable(k), T.self) }
        guard let t = v as? T else { throw Error.incorrectDependencyType(key ?? AnyHashable(k), T.self, type(of: v)) }
        made[k] = v
        return t
    }
}
/// runs an async maker to completion from synchronous code (a dependency read in a property getter); the maker must not
/// need the thread it is called on
private final class _IsimWaitBox<T>: @unchecked Sendable { var result: Result<T, Swift.Error>? }
func _isimWait<T>(_ body: @escaping () async throws -> T) throws -> T {
    let box = _IsimWaitBox<T>(), done = DispatchSemaphore(value: 0)
    Task.detached { do { box.result = .success(try await body()) } catch { box.result = .failure(error) }; done.signal() }
    done.wait()
    return try box.result!.get()
}

// MARK: - errors

/// An error that converts to one the system shows (AppIntentError).
public protocol CustomAppIntentErrorConvertible: Error {
    var appIntentError: AppIntentError { get }
}
/// The errors the system understands: their messages are the failure dialogs; `restartPerform` runs perform() again.
public struct AppIntentError: Error, LocalizedError, Equatable, Sendable, CustomLocalizedStringResourceConvertible {
    let code: String
    let message: String
    public var localizedStringResource: LocalizedStringResource { LocalizedStringResource(String.LocalizationValue(message)) }
    public var errorDescription: String? { message }
    var restart: Bool { code == "restartPerform" }
    init(code: String, message: String) { self.code = code; self.message = message }
    public init(description: LocalizedStringResource) { self.init(code: "custom", message: description.description) }
    public init(predefinedError: AppIntentError, description: LocalizedStringResource) {
        self.init(code: predefinedError.code, message: description.description)
    }
    public init(wrapping error: some CustomAppIntentErrorConvertible) { self = error.appIntentError }
    public init(wrapping error: some CustomLocalizedStringResourceConvertible & Error) {
        self.init(code: "custom", message: error.localizedStringResource.description)
    }
    public static func == (a: AppIntentError, b: AppIntentError) -> Bool { a.code == b.code }

    /// perform() runs again (after the app changed something the intent depends on)
    public static var restartPerform: AppIntentError { AppIntentError(code: "restartPerform", message: "") }
    public enum Unrecoverable {
        public static let entityNotFound = AppIntentError(code: "entityNotFound", message: "The item couldn’t be found.")
        public static let featureCurrentlyRestricted = AppIntentError(code: "featureCurrentlyRestricted", message: "This feature is currently restricted.")
        public static let networkFailure = AppIntentError(code: "networkFailure", message: "A network error occurred.")
        public static let notAllowed = AppIntentError(code: "notAllowed", message: "This action isn’t allowed.")
        public static let partialFailure = AppIntentError(code: "partialFailure", message: "Some of the action couldn’t be completed.")
        public static let unknown = AppIntentError(code: "unknown", message: "Something went wrong.")
        public static let unsupportedOnDevice = AppIntentError(code: "unsupportedOnDevice", message: "This action isn’t supported on this device.")
    }
    public enum UserActionRequired {
        public static let accountSetup = AppIntentError(code: "accountSetup", message: "Set up your account to continue.")
        public static let confirmation = AppIntentError(code: "confirmation", message: "Please confirm to continue.")
        public static let signin = AppIntentError(code: "signin", message: "Sign in to continue.")
    }
    public enum PermissionRequired {
        public static let bluetooth = AppIntentError(code: "bluetooth", message: "The app needs access to Bluetooth to do this.")
        public static let contacts = AppIntentError(code: "contacts", message: "The app needs access to your contacts to do this.")
        public static let localNetwork = AppIntentError(code: "localNetwork", message: "The app needs access to the local network to do this.")
        public static let photos = AppIntentError(code: "photos", message: "The app needs access to your photos to do this.")
        public static let siri = AppIntentError(code: "siri", message: "The app needs access to Siri to do this.")
        public static func location(precise: Bool) -> AppIntentError {
            AppIntentError(code: precise ? "preciseLocation" : "location",
                           message: "The app needs access to your \(precise ? "precise " : "")location to do this.")
        }
    }
}

// MARK: - value types

/// A person: an identifier, a name and handles (email addresses, phone numbers).
public struct IntentPerson: Hashable, Sendable, CustomStringConvertible {
    public enum Identifier: Hashable, Sendable { case contact(String), applicationDefined(String), unknown }
    public enum Name: Hashable, Sendable { case displayName(String), components(PersonNameComponents), unknown }
    public enum ParameterMode: Sendable { case contact, email, phone, emailOrPhone }
    public struct Handle: Hashable, Sendable {
        public enum Value: Hashable, Sendable { case applicationDefined(String), emailAddress(String), phoneNumber(String) }
        public enum Label: Hashable, Sendable { case home, homeFax, iPhone, main, mobile, other, pager, school, work, workFax, custom(String) }
        public var value: Value
        public var label: Label
        public init(_ value: Value, label: Label) { self.value = value; self.label = label }
        public init(emailAddress: String, label: Label) { self.init(.emailAddress(emailAddress), label: label) }
        public init(phoneNumber: String, label: Label) { self.init(.phoneNumber(phoneNumber), label: label) }
        public init(applicationDefined: String, label: String?) { self.init(.applicationDefined(applicationDefined), label: label.map { .custom($0) } ?? .other) }
        var _text: String { switch value { case .applicationDefined(let s), .emailAddress(let s), .phoneNumber(let s): return s } }
    }
    public var identifier: Identifier
    public var name: Name
    public var handle: Handle?
    public var aliases: [Handle]
    public var isMe: Bool
    public var image: DisplayRepresentation.Image?
    public init(identifier: Identifier, name: Name, handle: Handle? = nil, aliases: [Handle] = [], isMe: Bool = false,
                image: DisplayRepresentation.Image? = nil) {
        self.identifier = identifier; self.name = name; self.handle = handle; self.aliases = aliases; self.isMe = isMe; self.image = image
    }
    public init(handle: Handle) { self.init(identifier: .unknown, name: .unknown, handle: handle) }
    public var description: String {
        switch name {
        case .displayName(let s): return s
        case .components(let c): return PersonNameComponentsFormatter().string(from: c)
        case .unknown: return handle?._text ?? ""
        }
    }
    public static func == (a: IntentPerson, b: IntentPerson) -> Bool { a.identifier == b.identifier && a.name == b.name && a.handle == b.handle }
    public func hash(into h: inout Hasher) { h.combine(identifier); h.combine(handle) }
}

/// A file passed to or returned by an intent: its data, name and type.
public struct IntentFile: Hashable, Sendable, CustomStringConvertible {
    public enum IntentFileError: Error, Sendable { case failedToLoadData, failedToLoadFile }
    public var data: Data { _data ?? fileURL.flatMap { try? Data(contentsOf: $0) } ?? Data() }
    let _data: Data?
    public var filename: String
    public var type: UTType?
    public var fileURL: URL?
    public var removedOnCompletion = false
    public init(data: Data, filename: String, type: UTType? = nil) { _data = data; self.filename = filename; self.type = type; fileURL = nil }
    public init(fileURL: URL, filename: String? = nil, type: UTType? = nil) {
        _data = nil; self.fileURL = fileURL; self.filename = filename ?? fileURL.lastPathComponent
        self.type = type ?? UTType(filenameExtension: fileURL.pathExtension)
    }
    public var availableContentTypes: [UTType] { type.map { [$0] } ?? [] }
    public func data(contentType: UTType) async throws -> Data {
        guard type.map({ $0.conforms(to: contentType) }) ?? true else { throw IntentFileError.failedToLoadData }
        if let _data { return _data }
        guard let fileURL, let d = try? Data(contentsOf: fileURL) else { throw IntentFileError.failedToLoadData }
        return d
    }
    public func file(contentType: UTType, destinationDirectory: URL? = nil) async throws -> (fileURL: URL, openedInPlace: Bool) {
        if let fileURL, destinationDirectory == nil { return (fileURL, true) }
        let dir = destinationDirectory ?? FileManager.default.temporaryDirectory
        let u = dir.appendingPathComponent(filename)
        do { try await data(contentType: contentType).write(to: u) } catch { throw IntentFileError.failedToLoadFile }
        return (u, false)
    }
    public func withFile<Result>(contentType: UTType, allowOpenInPlace: Bool = false, fileHandler: (URL, Bool) async throws -> Result) async throws -> Result {
        let f = try await file(contentType: contentType, destinationDirectory: allowOpenInPlace ? nil : FileManager.default.temporaryDirectory)
        return try await fileHandler(f.fileURL, f.openedInPlace)
    }
    public var description: String { filename }
}

/// An amount of money in a currency.
public struct IntentCurrencyAmount: Hashable, Sendable, CustomStringConvertible {
    public let amount: Decimal
    public let currencyCode: String
    public init(amount: Decimal, currencyCode: String) { self.amount = amount; self.currencyCode = currencyCode }
    public var description: String { amount.formatted(.currency(code: currencyCode)) }
}

// MARK: - dynamic options

/// What an options provider returns: a list of values, or an IntentItemCollection with titles and sections.
public protocol ResultsCollection {
    associatedtype Result
    var items: [Result] { get }
    var promptLabel: LocalizedStringResource? { get }
    var usesIndexedCollation: Bool { get }
    static var empty: Self { get }
    var _isimItems: [IntentItem<Result>] { get }
}
extension ResultsCollection {
    public var promptLabel: LocalizedStringResource? { nil }
    public var usesIndexedCollation: Bool { false }
    public var _isimItems: [IntentItem<Result>] { items.map { IntentItem($0) } }
}
extension Array: ResultsCollection {
    public typealias Result = Element
    public var items: [Element] { self }
    public static var empty: [Element] { [] }
}
/// One value with how it is shown.
public struct IntentItem<Value>: @unchecked Sendable, Identifiable {
    public let id = UUID()
    public var value: Value
    let _title: LocalizedStringResource?, _subtitle: LocalizedStringResource?, _image: DisplayRepresentation.Image?
    public var description: DisplayRepresentation {
        DisplayRepresentation(title: _title ?? LocalizedStringResource(String.LocalizationValue(_IsimValues.describe(value))), subtitle: _subtitle, image: _image)
    }
    public init(_ value: Value) { self.value = value; _title = nil; _subtitle = nil; _image = nil }
    public init(_ value: Value, title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil, image: DisplayRepresentation.Image? = nil) {
        self.value = value; _title = title; _subtitle = subtitle; _image = image
    }
    @resultBuilder public enum Builder {
        public static func buildBlock() -> [Value] { [] }
        public static func buildBlock(_ items: IntentItem<Value>...) -> [IntentItem<Value>] { items }
        public static func buildBlock(_ items: [IntentItem<Value>]) -> [IntentItem<Value>] { items }
        public static func buildArray(_ items: [[IntentItem<Value>]]) -> [IntentItem<Value>] { items.flatMap { $0 } }
        @_disfavoredOverload public static func buildExpression(_ v: Value) -> IntentItem<Value> { IntentItem(v) }
        public static func buildExpression<ExpressionValue>(_ item: IntentItem<ExpressionValue>) -> IntentItem<ExpressionValue> { item }
    }
}
/// A titled group of values.
public struct IntentItemSection<Result>: @unchecked Sendable {
    public var description: DisplayRepresentation?
    public var items: [IntentItem<Result>]
    public init(items: [IntentItem<Result>]) { description = nil; self.items = items }
    public init(title: LocalizedStringResource, items: [IntentItem<Result>]) { description = DisplayRepresentation(title: title); self.items = items }
    public init(_ title: LocalizedStringResource, items: [IntentItem<Result>]) { self.init(title: title, items: items) }
    public init(_ title: LocalizedStringResource, items: [Result]) { self.init(title: title, items: items.map { IntentItem($0) }) }
    public init(_ title: LocalizedStringResource?, @IntentItem<Result>.Builder itemsBuilder: () -> [IntentItem<Result>]) {
        description = title.map { DisplayRepresentation(title: $0) }; items = itemsBuilder()
    }
    public init(_ title: LocalizedStringResource, subtitle: LocalizedStringResource?, image: DisplayRepresentation.Image?,
                @IntentItem<Result>.Builder itemsBuilder: () -> [IntentItem<Result>]) {
        description = DisplayRepresentation(title: title, subtitle: subtitle, image: image); items = itemsBuilder()
    }
    @resultBuilder public enum Builder {
        public static func buildBlock() -> [IntentItemSection<Result>] { [] }
        public static func buildBlock(_ sections: IntentItemSection<Result>...) -> [IntentItemSection<Result>] { sections }
        public static func buildBlock(_ items: IntentItem<Result>...) -> [IntentItemSection<Result>] { [IntentItemSection(items: items)] }
    }
}
/// The values an options provider offers, in sections, with a prompt.
public struct IntentItemCollection<Result>: ResultsCollection, @unchecked Sendable {
    public var sections: [IntentItemSection<Result>]
    public var promptLabel: LocalizedStringResource?
    public var usesIndexedCollation: Bool
    public init(promptLabel: LocalizedStringResource? = nil, usesIndexedCollation: Bool = false, sections: [IntentItemSection<Result>]) {
        self.sections = sections; self.promptLabel = promptLabel; self.usesIndexedCollation = usesIndexedCollation
    }
    public init(promptLabel: LocalizedStringResource? = nil, usesIndexedCollation: Bool = false, items: [Result]) {
        self.init(promptLabel: promptLabel, usesIndexedCollation: usesIndexedCollation, sections: [IntentItemSection(items: items.map { IntentItem($0) })])
    }
    public init(promptLabel: LocalizedStringResource? = nil, usesIndexedCollation: Bool = false,
                @IntentItemSection<Result>.Builder sectionsBuilder: () -> [IntentItemSection<Result>]) {
        self.init(promptLabel: promptLabel, usesIndexedCollation: usesIndexedCollation, sections: sectionsBuilder())
    }
    public var items: [Result] { sections.flatMap { $0.items.map(\.value) } }
    public static var empty: IntentItemCollection<Result> { IntentItemCollection(sections: []) }
    public var _isimItems: [IntentItem<Result>] { sections.flatMap(\.items) }
}
/// The values a parameter can take, computed when the system asks (`@Parameter(title:optionsProvider:)`).
public protocol DynamicOptionsProvider: Sendable {
    associatedtype Result: ResultsCollection
    associatedtype DefaultValue = Never
    func results() async throws -> Result
    func defaultResult() async -> DefaultValue?
}
extension DynamicOptionsProvider {
    public typealias Item = IntentItem
    public typealias ItemSection = IntentItemSection
    public typealias ItemCollection = IntentItemCollection
    public func defaultResult() async -> DefaultValue? { nil }
    /// the provider's values as the system's options
    func _isimOptions() async -> [_IsimOption] {
        let items = ((try? await results())?._isimItems) ?? []
        return items.enumerated().map { i, item in
            _IsimOption(id: (item.value as? any AppEntity).map { "\($0.id)" } ?? (item.value as? any AppEnum)?.rawValue ?? "\(i)",
                        title: item.description.title.description, subtitle: item.description.subtitle?.description ?? "", value: item.value)
        }
    }
}
extension IntentParameter {
    public convenience init<P: DynamicOptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, optionsProvider: P) {
        self.init(title: title, description: description)
        _optionsProvider = { await optionsProvider._isimOptions() }
    }
    public convenience init<P: DynamicOptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default value: Value,
                                                       optionsProvider: P) {
        self.init(title: title, description: description, default: value)
        _optionsProvider = { await optionsProvider._isimOptions() }
    }
    public convenience init<P: DynamicOptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil,
                                                       requestValueDialog: IntentDialog?, optionsProvider: P) {
        self.init(title: title, description: description, requestValueDialog: requestValueDialog)
        _optionsProvider = { await optionsProvider._isimOptions() }
    }
}

// MARK: - parameter summaries

/// The sentence Shortcuts shows for an action, with its parameters in place (`static var parameterSummary`).
public protocol ParameterSummary {
    associatedtype Intent: AppIntent
    func _isimResolve(_ intent: Intent) -> _IsimSummary?
}
/// a summary resolved for one intent: the sentence (parameters as ${name}) and the parameters listed under it
public struct _IsimSummary { public var sentence: String; public var table: [String] }
extension ParameterSummary {
    /// the summary for an intent of any type (nil when it is not this summary's intent)
    func _isimResolveAny(_ intent: Any) -> _IsimSummary? { (intent as? Intent).flatMap { _isimResolve($0) } }
}

/// The sentence of a summary: text with parameters (`"Open \(\.$book)"`).
public struct ParameterSummaryString<Intent: AppIntent>: ExpressibleByStringInterpolation, ExpressibleByStringLiteral {
    enum Part { case text(String), parameter(AnyKeyPath) }
    let parts: [Part]
    public init(_ string: String) { parts = [.text(string)] }
    public init(stringLiteral value: String) { parts = [.text(value)] }
    public init(stringInterpolation i: StringInterpolation) { parts = i.parts }
    public struct StringInterpolation: StringInterpolationProtocol {
        var parts: [Part] = []
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ s: String) { parts.append(.text(s)) }
        public mutating func appendInterpolation<Value>(_ keyPath: KeyPath<Intent, IntentParameter<Value>>) { parts.append(.parameter(keyPath)) }
    }
    func resolve(_ intent: Intent) -> String {
        parts.map {
            switch $0 {
            case .text(let s): return s
            case .parameter(let kp): return "${" + (_IsimReflection.parameterName(intent, keyPath: kp) ?? "?") + "}"
            }
        }.joined()
    }
}
/// The sentence, and the other parameters (shown below it). `Summary` in an intent.
public struct IntentParameterSummary<Intent: AppIntent>: ParameterSummary {
    let string: ParameterSummaryString<Intent>?
    let table: [PartialKeyPath<Intent>]
    public init() { string = nil; table = [] }
    public init(@ParameterKeyPathsBuilder _ keyPaths: () -> [PartialKeyPath<Intent>]) { string = nil; table = keyPaths() }
    public init(_ string: ParameterSummaryString<Intent>, table: String? = nil) { self.string = string; self.table = [] }
    public init(_ string: ParameterSummaryString<Intent>, table: String? = nil, @ParameterKeyPathsBuilder _ keyPaths: () -> [PartialKeyPath<Intent>]) {
        self.string = string; self.table = keyPaths()
    }
    public func _isimResolve(_ intent: Intent) -> _IsimSummary? {
        _IsimSummary(sentence: string?.resolve(intent) ?? "", table: table.compactMap { _IsimReflection.parameterName(intent, keyPath: $0) })
    }
    @resultBuilder public enum ParameterKeyPathsBuilder {
        public static func buildExpression<ValueType>(_ kp: KeyPath<Intent, IntentParameter<ValueType>>) -> PartialKeyPath<Intent> { kp }
        public static func buildBlock(_ kps: PartialKeyPath<Intent>...) -> [PartialKeyPath<Intent>] { kps }
    }
}
public enum EquatableComparisonOperator: Sendable { case equalTo, notEqualTo }
public enum ComparableComparisonOperator: Sendable { case greaterThan, greaterThanOrEqualTo, lessThan, lessThanOrEqualTo }
public enum HasValueComparisonOperator: Sendable { case hasAnyValue, hasNoValue }
public enum OneOfComparisonOperator: Sendable { case oneOf }
public enum StringComparisonOperator: Sendable { case contains, doesNotContain, hasPrefix, hasSuffix }
/// A summary that depends on a parameter's value. `When` in an intent.
public struct ParameterSummaryWhenCondition<Intent: AppIntent, WhenCondition: ParameterSummary, Otherwise: ParameterSummary>: ParameterSummary
    where WhenCondition.Intent == Intent, Otherwise.Intent == Intent {
    let test: (Intent) -> Bool
    let then: WhenCondition
    let otherwise: Otherwise
    init<V>(_ keyPath: KeyPath<Intent, IntentParameter<V>>, _ when: () -> WhenCondition, _ otherwise: () -> Otherwise, test: @escaping (V?) -> Bool) {
        self.test = { i in
            let v = i[keyPath: keyPath]._value
            if let o = v as? _IsimOptional { return test(o._isimUnwrapped == nil ? nil : v) }
            return test(v)
        }
        then = when(); self.otherwise = otherwise()
    }
    public init<V>(_ keyPath: KeyPath<Intent, IntentParameter<V>>, _ op: HasValueComparisonOperator,
                   @ParameterSummaryBuilder<Intent> _ when: () -> WhenCondition, @ParameterSummaryBuilder<Intent> otherwise: () -> Otherwise) {
        self.init(keyPath, when, otherwise) { ($0 != nil) == (op == .hasAnyValue) }
    }
    public init<V: Equatable>(_ keyPath: KeyPath<Intent, IntentParameter<V>>, _ op: EquatableComparisonOperator, _ value: V,
                              @ParameterSummaryBuilder<Intent> _ when: () -> WhenCondition, @ParameterSummaryBuilder<Intent> otherwise: () -> Otherwise) {
        self.init(keyPath, when, otherwise) { ($0 == value) == (op == .equalTo) }
    }
    public init<V: Comparable>(_ keyPath: KeyPath<Intent, IntentParameter<V>>, _ op: ComparableComparisonOperator, _ value: V,
                               @ParameterSummaryBuilder<Intent> _ when: () -> WhenCondition, @ParameterSummaryBuilder<Intent> otherwise: () -> Otherwise) {
        self.init(keyPath, when, otherwise) { v in
            guard let v else { return false }
            switch op {
            case .greaterThan: return v > value
            case .greaterThanOrEqualTo: return v >= value
            case .lessThan: return v < value
            case .lessThanOrEqualTo: return v <= value
            }
        }
    }
    public init<V: Equatable>(_ keyPath: KeyPath<Intent, IntentParameter<V>>, _ op: OneOfComparisonOperator, _ values: [V],
                              @ParameterSummaryBuilder<Intent> _ when: () -> WhenCondition, @ParameterSummaryBuilder<Intent> otherwise: () -> Otherwise) {
        self.init(keyPath, when, otherwise) { v in v.map { values.contains($0) } ?? false }
    }
    public func _isimResolve(_ intent: Intent) -> _IsimSummary? { test(intent) ? then._isimResolve(intent) : otherwise._isimResolve(intent) }
}
@resultBuilder public enum ParameterSummaryBuilder<Intent: AppIntent> {
    public static func buildExpression<Summary: ParameterSummary>(_ s: Summary) -> Summary where Summary.Intent == Intent { s }
    public static func buildBlock<Summary: ParameterSummary>(_ s: Summary) -> Summary where Summary.Intent == Intent { s }
}
extension AppIntent {
    public typealias Summary = IntentParameterSummary<Self>
    public typealias When<WhenCondition: ParameterSummary, Otherwise: ParameterSummary> = ParameterSummaryWhenCondition<Self, WhenCondition, Otherwise>
        where WhenCondition.Intent == Self, Otherwise.Intent == Self
}
/// the summary of an intent that declares none
public struct _IsimNoSummary<Intent: AppIntent>: ParameterSummary {
    public init() {}
    public func _isimResolve(_ intent: Intent) -> _IsimSummary? { nil }
}

// MARK: - queries over entity properties (Shortcuts' "Find … where …")

public enum EntityQueryComparatorMode: Sendable { case and, or }
/// How a property query's results are sorted.
public struct EntityQuerySort<Entity>: @unchecked Sendable {
    public enum Ordering: Sendable { case ascending, descending }
    public let by: PartialKeyPath<Entity>
    public let order: Ordering
    public init(by: PartialKeyPath<Entity>, order: Ordering = .ascending) { self.by = by; self.order = order }
}

/// One comparison the system can make on a property, and how it becomes the query's own type (an NSPredicate, a
/// closure, …).
public class EntityQueryComparator<Property, PropertyType, InputType, ComparatorMappingType> {
    let _name: String
    /// the comparison with a value from the system (text), in the query's type
    let _make: (String) -> ComparatorMappingType?
    init(_name: String, make: @escaping (String) -> ComparatorMappingType?) { self._name = _name; _make = make }
    init(_name: String, transform: @escaping (InputType) -> ComparatorMappingType) {
        self._name = _name
        _make = { _IsimValues.parse($0, as: InputType.self).map(transform) }
    }
}
public final class EqualToComparator<Property, PropertyType, ComparatorMappingType>: EntityQueryComparator<Property, PropertyType, PropertyType, ComparatorMappingType> {
    public init(mappingTransform: @escaping (PropertyType) -> ComparatorMappingType) { super.init(_name: "equalTo", transform: mappingTransform) }
}
public final class NotEqualToComparator<Property, PropertyType, ComparatorMappingType>: EntityQueryComparator<Property, PropertyType, PropertyType, ComparatorMappingType> {
    public init(mappingTransform: @escaping (PropertyType) -> ComparatorMappingType) { super.init(_name: "notEqualTo", transform: mappingTransform) }
}
public final class LessThanComparator<Property, PropertyType, ComparatorMappingType>: EntityQueryComparator<Property, PropertyType, PropertyType, ComparatorMappingType> {
    public init(mappingTransform: @escaping (PropertyType) -> ComparatorMappingType) { super.init(_name: "lessThan", transform: mappingTransform) }
}
public final class LessThanOrEqualToComparator<Property, PropertyType, ComparatorMappingType>: EntityQueryComparator<Property, PropertyType, PropertyType, ComparatorMappingType> {
    public init(mappingTransform: @escaping (PropertyType) -> ComparatorMappingType) { super.init(_name: "lessThanOrEqualTo", transform: mappingTransform) }
}
public final class GreaterThanComparator<Property, PropertyType, ComparatorMappingType>: EntityQueryComparator<Property, PropertyType, PropertyType, ComparatorMappingType> {
    public init(mappingTransform: @escaping (PropertyType) -> ComparatorMappingType) { super.init(_name: "greaterThan", transform: mappingTransform) }
}
public final class GreaterThanOrEqualToComparator<Property, PropertyType, ComparatorMappingType>: EntityQueryComparator<Property, PropertyType, PropertyType, ComparatorMappingType> {
    public init(mappingTransform: @escaping (PropertyType) -> ComparatorMappingType) { super.init(_name: "greaterThanOrEqualTo", transform: mappingTransform) }
}
/// a text property contains the value, or a list property contains the element
public final class ContainsComparator<Property, PropertyType, InputType, ComparatorMappingType>: EntityQueryComparator<Property, PropertyType, InputType, ComparatorMappingType> {
    init(_ transform: @escaping (InputType) -> ComparatorMappingType) { super.init(_name: "contains", transform: transform) }
}
extension ContainsComparator where PropertyType == String, InputType == String {
    public convenience init(mappingTransform: @escaping (InputType) -> ComparatorMappingType) { self.init(mappingTransform) }
}
extension ContainsComparator where PropertyType == String?, InputType == String {
    public convenience init(mappingTransform: @escaping (InputType) -> ComparatorMappingType) { self.init(mappingTransform) }
}
extension ContainsComparator where PropertyType == [InputType] {
    public convenience init(mappingTransform: @escaping (InputType) -> ComparatorMappingType) { self.init(mappingTransform) }
}
public final class HasPrefixComparator<Property, PropertyType, InputType, ComparatorMappingType>: EntityQueryComparator<Property, PropertyType, InputType, ComparatorMappingType> {
    init(_ transform: @escaping (InputType) -> ComparatorMappingType) { super.init(_name: "hasPrefix", transform: transform) }
}
extension HasPrefixComparator where PropertyType == String, InputType == String {
    public convenience init(mappingTransform: @escaping (InputType) -> ComparatorMappingType) { self.init(mappingTransform) }
}
extension HasPrefixComparator where PropertyType == String?, InputType == String {
    public convenience init(mappingTransform: @escaping (InputType) -> ComparatorMappingType) { self.init(mappingTransform) }
}
public final class HasSuffixComparator<Property, PropertyType, InputType, ComparatorMappingType>: EntityQueryComparator<Property, PropertyType, InputType, ComparatorMappingType> {
    init(_ transform: @escaping (InputType) -> ComparatorMappingType) { super.init(_name: "hasSuffix", transform: transform) }
}
extension HasSuffixComparator where PropertyType == String, InputType == String {
    public convenience init(mappingTransform: @escaping (InputType) -> ComparatorMappingType) { self.init(mappingTransform) }
}
extension HasSuffixComparator where PropertyType == String?, InputType == String {
    public convenience init(mappingTransform: @escaping (InputType) -> ComparatorMappingType) { self.init(mappingTransform) }
}
/// the value is between two others (the system sends them as "low...high")
public final class IsBetweenComparator<Property, PropertyType, InputType, ComparatorMappingType>: EntityQueryComparator<Property, PropertyType, InputType, ComparatorMappingType> {
    public init(mappingTransform: @escaping (InputType, InputType) -> ComparatorMappingType) {
        super.init(_name: "isBetween") { text in
            let ends = text.components(separatedBy: "...")
            guard ends.count == 2, let lo = _IsimValues.parse(ends[0], as: InputType.self), let hi = _IsimValues.parse(ends[1], as: InputType.self) else { return nil }
            return mappingTransform(lo, hi)
        }
    }
}
/// A comparator of a query property, without its kind.
public struct AnyEntityQueryComparator<Entity, Subject, Property, PropertyType, ComparatorMappingType> {
    let name: String
    let make: (String) -> ComparatorMappingType?
    init<InputType>(_ c: EntityQueryComparator<Property, PropertyType, InputType, ComparatorMappingType>) { name = c._name; make = c._make }
}
@resultBuilder public enum EntityQueryComparatorsBuilder<Entity, Subject, Property, PropertyType, ComparatorMappingType> {
    public typealias Comparator = AnyEntityQueryComparator<Entity, Subject, Property, PropertyType, ComparatorMappingType>
    public static func buildExpression(_ c: EntityQueryComparator<Property, PropertyType, PropertyType, ComparatorMappingType>) -> Comparator { Comparator(c) }
    public static func buildExpression<InputType>(_ c: ContainsComparator<Property, PropertyType, InputType, ComparatorMappingType>) -> Comparator { Comparator(c) }
    public static func buildExpression<InputType>(_ c: HasPrefixComparator<Property, PropertyType, InputType, ComparatorMappingType>) -> Comparator { Comparator(c) }
    public static func buildExpression<InputType>(_ c: HasSuffixComparator<Property, PropertyType, InputType, ComparatorMappingType>) -> Comparator { Comparator(c) }
    public static func buildExpression<InputType>(_ c: IsBetweenComparator<Property, PropertyType, InputType, ComparatorMappingType>) -> Comparator { Comparator(c) }
    public static func buildBlock(_ comparators: Comparator...) -> [Comparator] { comparators }
}
/// A property a query can filter on.
public class EntityQueryPropertyDeclaration<Entity, ComparatorMappingType> {
    let _keyPath: AnyKeyPath
    let _comparators: [(name: String, make: (String) -> ComparatorMappingType?)]
    init(_keyPath: AnyKeyPath, comparators: [(name: String, make: (String) -> ComparatorMappingType?)]) {
        self._keyPath = _keyPath; _comparators = comparators
    }
}
/// A property a query can filter on, and how each comparison maps to the query's type. `Property` in a query.
public final class EntityQueryProperty<Entity, Subject, Property, PropertyType, ComparatorMappingType>: EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>
    where Property: EntityProperty<PropertyType> {
    public typealias QueryComparators = EntityQueryComparatorsBuilder<Entity, Subject, Property, PropertyType, ComparatorMappingType>
    public init(_ keyPath: KeyPath<Subject, Property>, entityProvider: @escaping (Entity) -> Subject,
                @QueryComparators comparators: () -> [AnyEntityQueryComparator<Entity, Subject, Property, PropertyType, ComparatorMappingType>]) {
        super.init(_keyPath: keyPath, comparators: comparators().map { ($0.name, $0.make) })
    }
    public convenience init(_ keyPath: KeyPath<Subject, Property>,
                            @QueryComparators comparators: () -> [AnyEntityQueryComparator<Entity, Subject, Property, PropertyType, ComparatorMappingType>])
        where Subject == Entity {
        self.init(keyPath, entityProvider: { $0 }, comparators: comparators)
    }
}
@resultBuilder public enum EntityQueryPropertiesBuilder<Entity, ComparatorMappingType> {
    public static func buildExpression(_ p: EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>) -> EntityQueryPropertyDeclaration<Entity, ComparatorMappingType> { p }
    public static func buildBlock(_ ps: EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>...) -> [EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>] { ps }
}
/// The properties a query can filter on. `QueryProperties` in a query.
public struct EntityQueryProperties<Entity, ComparatorMappingType>: @unchecked Sendable {
    let properties: [EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>]
    public init(@EntityQueryPropertiesBuilder<Entity, ComparatorMappingType> properties: () -> [EntityQueryPropertyDeclaration<Entity, ComparatorMappingType>]) {
        self.properties = properties()
    }
    public subscript(_ i: Int) -> EntityQueryPropertyDeclaration<Entity, ComparatorMappingType> { properties[i] }
}
/// A property results can be sorted by. `SortableBy` in a query.
public struct EntityQuerySortableByProperty<Entity>: @unchecked Sendable {
    let keyPath: PartialKeyPath<Entity>
    public init<Property>(_ keyPath: KeyPath<Entity, Property>) { self.keyPath = keyPath }
}
@resultBuilder public enum EntityQuerySortingOptionsBuilder<Entity> {
    public static func buildExpression(_ s: EntityQuerySortableByProperty<Entity>) -> EntityQuerySortableByProperty<Entity> { s }
    public static func buildBlock(_ ss: EntityQuerySortableByProperty<Entity>...) -> [EntityQuerySortableByProperty<Entity>] { ss }
}
/// The properties results can be sorted by. `SortingOptions` in a query.
public struct EntityQuerySortingOptions<Entity>: @unchecked Sendable {
    let options: [EntityQuerySortableByProperty<Entity>]
    public init() { options = [] }
    public init(@EntityQuerySortingOptionsBuilder<Entity> content: () -> [EntityQuerySortableByProperty<Entity>]) { options = content() }
    public subscript(_ i: Int) -> EntityQuerySortableByProperty<Entity> { options[i] }
}
/// Finds entities by their properties: the system builds the comparisons (Shortcuts' "Find … where …").
public protocol EntityPropertyQuery: EntityQuery {
    associatedtype ComparatorMappingType
    typealias QueryProperties = EntityQueryProperties<Entity, ComparatorMappingType>
    typealias SortingOptions = EntityQuerySortingOptions<Entity>
    typealias SortableBy = EntityQuerySortableByProperty<Entity>
    typealias Sort = EntityQuerySort<Entity>
    typealias ComparatorMode = EntityQueryComparatorMode
    static var properties: QueryProperties { get }
    static var sortingOptions: SortingOptions { get }
    static var findIntentDescription: IntentDescription? { get }
    func entities(matching comparators: [ComparatorMappingType], mode: ComparatorMode, sortedBy: [Sort], limit: Int?) async throws -> [Entity]
}
extension EntityPropertyQuery {
    public typealias Property<Subject, Property, PropertyType> = EntityQueryProperty<Entity, Subject, Property, PropertyType, ComparatorMappingType>
        where Property: EntityProperty<PropertyType>
    public static var sortingOptions: SortingOptions { SortingOptions() }
    public static var findIntentDescription: IntentDescription? { nil }
}

// MARK: - what the system does with properties and property queries (System.swift's metadata and "find" requests)

@MainActor enum _IsimEntityProbe {
    /// an entity of the type (its query's suggested entities), to see its properties
    static func sample(_ t: any AppEntity.Type) async -> (any AppEntity)? { await t._isimSuggested().first?.value as? any AppEntity }
    /// the name of the entity property a key path points at (`\.$title` -> "title")
    static func propertyName(_ sample: Any, _ keyPath: AnyKeyPath) -> String? {
        guard let obj = _isimProject(sample, keyPath) else { return nil }
        for c in Mirror(reflecting: sample).children {
            if let label = c.label, (c.value as AnyObject) === obj { return label.hasPrefix("_") ? String(label.dropFirst()) : label }
        }
        return nil
    }
    static func propertyQuery(_ t: any AppEntity.Type) async -> [String: Any]? {
        guard let sample = await sample(t) else { return nil }
        return _queryInfo(t, sample)
    }
    static func _queryInfo<E: AppEntity>(_ t: E.Type, _ sample: any AppEntity) -> [String: Any]? {
        guard let q = E.defaultQuery as? any EntityPropertyQuery else { return nil }
        return _info(q, sample)
    }
    static func _info<Q: EntityPropertyQuery>(_ q: Q, _ sample: Any) -> [String: Any] {
        let props = Q.properties.properties.map { p -> [String: Any] in
            ["name": propertyName(sample, p._keyPath) ?? "?", "comparators": p._comparators.map(\.name)]
        }
        let sorts = Q.sortingOptions.options.compactMap { propertyName(sample, $0.keyPath) }
        var d: [String: Any] = ["properties": props, "sortable": sorts]
        if let desc = Q.findIntentDescription { d["findDescription"] = desc.text }
        return d
    }
    /// a "find" request: { find = Module.Entity; where = ((property, comparator, value), ...); mode = and|or;
    /// sort = property; order = ascending|descending; limit = n } -> result step with the entities found
    static func find(_ entityName: String, _ req: [String: Any], _ ch: _IsimChannel) async {
        guard let t = _IsimConformances.entities.first(where: { _isimTypeName($0) == entityName }), let sample = await sample(t) else {
            ch.write(["type": "result", "outcome": "failure", "dialog": "No such entity: \(entityName)"]); return
        }
        do {
            let found = try await _find(t, sample, req)
            NSLog("isim AppIntents: find %@: %ld result(s)", t.typeDisplayRepresentation.name.description, found.count)
            ch.write(["type": "result", "outcome": "success", "dialog": "\(found.count) result\(found.count == 1 ? "" : "s")",
                      "entities": found.map { $0._isimOption.plist }])
        } catch {
            ch.write(["type": "result", "outcome": "failure", "dialog": (error as? LocalizedError)?.errorDescription ?? "\(error)"])
        }
    }
    static func _find<E: AppEntity>(_ t: E.Type, _ sample: any AppEntity, _ req: [String: Any]) async throws -> [any AppEntity] {
        guard let q = E.defaultQuery as? any EntityPropertyQuery else { throw AppIntentError.Unrecoverable.notAllowed }
        return try await _run(q, sample, req)
    }
    static func _run<Q: EntityPropertyQuery>(_ q: Q, _ sample: Any, _ req: [String: Any]) async throws -> [any AppEntity] {
        var comparators: [Q.ComparatorMappingType] = []
        for w in req["where"] as? [[String]] ?? [] where w.count == 3 {
            guard let p = Q.properties.properties.first(where: { propertyName(sample, $0._keyPath) == w[0] }),
                  let c = p._comparators.first(where: { $0.name == w[1] })?.make(w[2]) else {
                throw AppIntentError.Unrecoverable.notAllowed
            }
            comparators.append(c)
        }
        var sorts: [EntityQuerySort<Q.Entity>] = []
        if let by = req["sort"] as? String, let o = Q.sortingOptions.options.first(where: { propertyName(sample, $0.keyPath) == by }) {
            sorts.append(EntityQuerySort(by: o.keyPath, order: req["order"] as? String == "descending" ? .descending : .ascending))
        }
        let mode: EntityQueryComparatorMode = req["mode"] as? String == "or" ? .or : .and
        return try await q.entities(matching: comparators, mode: mode, sortedBy: sorts, limit: req["limit"] as? Int).map { $0 as any AppEntity }
    }
}
/// the object a key path reaches in a value (an entity's `$property`)
func _isimProject(_ value: Any, _ keyPath: AnyKeyPath) -> AnyObject? {
    func open<T>(_ v: T) -> AnyObject? { (keyPath as? PartialKeyPath<T>).map { v[keyPath: $0] as AnyObject } }
    return _openExistential(value, do: open)
}
