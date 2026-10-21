// isim AppIntents: entity kinds (IndexedEntity in Spotlight, UniqueAppEntity, TransientAppEntity), URL representations
// (URLRepresentableEntity / Enum / Intent, OpenURLIntent), and intent kinds (CameraCaptureIntent, AudioRecordingIntent,
// SnippetIntent, AppIntentsPackage).
// - Indexed entities go into the home screen's Spotlight with CoreSpotlight's other items; choosing one runs the app's
//   OpenIntent for that entity type with the entity as its target (in the foreground), or, without one, continues
//   CSSearchableItemActionType in the app, as iOS does.
// - An OpenURLIntent opens its URL like UIApplication.open: the app that claims it (universal links, custom schemes).
//   A URLRepresentableIntent that is also an OpenIntent opens its URL instead of performing.
// - AppIntentsPackage: isim finds every type's intents through the conformance records (System.swift), so packages
//   need no listing; includedPackages is kept for the API.
import Foundation
import UIKit
import SwiftUI
import CoreSpotlight

// MARK: - IndexedEntity

@available(iOS 18.0, *)
@_alwaysEmitConformanceMetadata public protocol IndexedEntity: AppEntity {
    var attributeSet: CSSearchableItemAttributeSet { get }
    var hideInSpotlight: Bool { get }
}
@available(iOS 18.0, *)
extension IndexedEntity {
    /// the title and subtitle of the entity's display representation
    public var defaultAttributeSet: CSSearchableItemAttributeSet {
        let a = CSSearchableItemAttributeSet(contentType: .content)
        a.title = displayRepresentation.title.description
        a.displayName = a.title
        a.contentDescription = displayRepresentation.subtitle?.description
        return a
    }
    public var attributeSet: CSSearchableItemAttributeSet { defaultAttributeSet }
    public var hideInSpotlight: Bool { false }
    var _isimSearchableItem: CSSearchableItem {
        let item = CSSearchableItem(uniqueIdentifier: "appentity:\(_isimTypeName(Self.self)):\(id)", domainIdentifier: "appentity:\(_isimTypeName(Self.self))",
                                    attributeSet: attributeSet)
        item._isimAppEntity = ["type": _isimTypeName(Self.self), "id": "\(id)"]
        return item
    }
}

@available(iOS 18.0, *)
public protocol IndexedEntityQuery: EntityQuery {
    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws
    func reindexEntities(for identifiers: [Entity.ID], indexDescription: CSSearchableIndexDescription) async throws
}
/// describes the index a query reindexes (iOS 18)
@available(iOS 18.0, *)
public struct CSSearchableIndexDescription: Sendable {
    public let name: String
    init(name: String) { self.name = name }
}
@available(iOS 18.0, *)
extension IndexedEntityQuery where Entity: IndexedEntity {
    /// suggested entities are indexed again (isim has no index maintenance of its own to call it)
    public func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        try await CSSearchableIndex.default().indexAppEntities(try await suggestedEntities().map { $0 })
    }
    public func reindexEntities(for identifiers: [Entity.ID], indexDescription: CSSearchableIndexDescription) async throws {
        try await CSSearchableIndex.default().indexAppEntities(try await entities(for: identifiers))
    }
}

@available(iOS 18.0, *)
extension CSSearchableIndex {
    /// the entities in Spotlight (those not hidden)
    public func indexAppEntities<T: IndexedEntity>(_ entities: [T], priority: Int = 0) async throws {
        let shown = entities.filter { !$0.hideInSpotlight }
        try await indexSearchableItems(shown.map { $0._isimSearchableItem })
        NSLog("isim AppIntents: %ld %@ entit%@ indexed in Spotlight", shown.count, T.typeDisplayRepresentation.name.description, shown.count == 1 ? "y" : "ies")
    }
    public func deleteAppEntities<T: IndexedEntity>(identifiedBy identifiers: [T.ID], ofType type: T.Type) async throws {
        try await deleteSearchableItems(withIdentifiers: identifiers.map { "appentity:\(_isimTypeName(T.self)):\($0)" })
    }
    public func deleteAppEntities<T: IndexedEntity>(ofType type: T.Type) async throws {
        try await deleteSearchableItems(withDomainIdentifiers: ["appentity:\(_isimTypeName(T.self))"])
    }
}
@available(iOS 18.0, *)
extension CSSearchableItem {
    /// the item opens the entity (the app's OpenIntent for its type) when chosen in Spotlight
    public func associateAppEntity<T: IndexedEntity>(_ entity: T, priority: Int = 0) {
        _isimAppEntity = ["type": _isimTypeName(T.self), "id": "\(entity.id)"]
    }
}

// MARK: - unique and transient entities

/// an entity there is only one of (the app's settings, the current session): its query returns it
@available(iOS 18.0, *)
@_alwaysEmitConformanceMetadata public protocol UniqueAppEntity: AppEntity where DefaultQuery: UniqueAppEntityQuery {}
@available(iOS 18.0, *)
public protocol UniqueAppEntityQuery: EntityQuery {
    associatedtype Unique: AppEntity
    func uniqueEntity() async throws -> Unique
}
@available(iOS 18.0, *)
extension UniqueAppEntityQuery where Entity == Unique {
    public func entities(for identifiers: [Unique.ID]) async throws -> [Unique] { [try await uniqueEntity()] }
    public func suggestedEntities() async throws -> [Unique] { [try await uniqueEntity()] }
}
/// the query of a unique entity made by a closure
@available(iOS 18.0, *)
public struct UniqueAppEntityProvider<Entity: AppEntity>: UniqueAppEntityQuery, @unchecked Sendable {
    public typealias Unique = Entity
    let make: () async throws -> Entity
    public init(_ make: @escaping () async throws -> Entity) { self.make = make }
    /// EntityQuery's init: a provider made by the system has no entity to give
    public init() { make = { throw AppIntentError.Unrecoverable.entityNotFound } }
    public func uniqueEntity() async throws -> Entity { try await make() }
}

/// an entity with no query: made by the app as a parameter or result value (its properties are @Property)
@_alwaysEmitConformanceMetadata public protocol TransientAppEntity: AppEntity {
    init()
}
public struct _IsimTransientQuery<Entity: AppEntity>: EntityQuery {
    public init() {}
    public func entities(for identifiers: [Entity.ID]) async throws -> [Entity] { [] }
}
extension TransientAppEntity where DefaultQuery == _IsimTransientQuery<Self> {
    public static var defaultQuery: _IsimTransientQuery<Self> { _IsimTransientQuery() }
}
extension TransientAppEntity {
    /// transient entities have no identity of their own
    public var id: String { _isimTypeName(Self.self) }
}

// MARK: - URL representations

/// a URL template: "https://example.com/items/\(.id)" (an entity's id or property), "\(.self)" (an enum's raw value)
public struct EntityURLRepresentation<Entity: AppEntity>: ExpressibleByStringInterpolation, Sendable {
    let parts: [Part]
    enum Part: @unchecked Sendable { case text(String), value(PartialKeyPath<Entity>) }
    public struct StringInterpolation: StringInterpolationProtocol {
        var parts: [Part] = []
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) { parts.append(.text(literal)) }
        public mutating func appendInterpolation<V>(_ keyPath: KeyPath<Entity, V>) { parts.append(.value(keyPath)) }
    }
    public init(stringLiteral value: String) { parts = [.text(value)] }
    public init(stringInterpolation: StringInterpolation) { parts = stringInterpolation.parts }
    public init(_ template: String) { parts = [.text(template)] }
    func url(_ e: Entity) -> URL? {
        URL(string: parts.map { part -> String in
            switch part {
            case .text(let t): return t
            case .value(let kp): return _isimURLParameter(e[keyPath: kp])
            }
        }.joined())
    }
}
public struct EnumURLRepresentation<Enum: AppEnum>: ExpressibleByStringInterpolation, Sendable {
    public struct EnumSingleURLRepresentation: ExpressibleByStringLiteral, Sendable {
        let template: String
        public init(stringLiteral value: String) { template = value }
    }
    let template: String?
    let perCase: [Enum: EnumSingleURLRepresentation]
    public struct StringInterpolation: StringInterpolationProtocol {
        var text = ""
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) { text += literal }
        public mutating func appendInterpolation(_ keyPath: KeyPath<Enum, Enum>) { text += "{value}" }
    }
    public init(stringLiteral value: String) { template = value; perCase = [:] }
    public init(stringInterpolation: StringInterpolation) { template = stringInterpolation.text; perCase = [:] }
    public init(_ template: String) { self.template = template; perCase = [:] }
    public init(_ cases: [Enum: EnumSingleURLRepresentation]) { template = nil; perCase = cases }
    func url(_ e: Enum) -> URL? {
        if let c = perCase[e] { return URL(string: c.template) }
        return template.flatMap { URL(string: $0.replacingOccurrences(of: "{value}", with: _isimURLParameter(e))) }
    }
}
public struct IntentURLRepresentation<Intent: AppIntent>: ExpressibleByStringInterpolation, Sendable {
    let parts: [Part]
    enum Part: @unchecked Sendable { case text(String), parameter(PartialKeyPath<Intent>) }
    public struct StringInterpolation: StringInterpolationProtocol {
        var parts: [Part] = []
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) { parts.append(.text(literal)) }
        public mutating func appendInterpolation<V>(_ keyPath: KeyPath<Intent, V>) { parts.append(.parameter(keyPath)) }
    }
    public init(stringLiteral value: String) { parts = [.text(value)] }
    public init(stringInterpolation: StringInterpolation) { parts = stringInterpolation.parts }
    public init(_ template: String) { parts = [.text(template)] }
    func url(_ i: Intent) -> URL? {
        URL(string: parts.map { part -> String in
            switch part {
            case .text(let t): return t
            case .parameter(let kp): return _isimURLParameter(i[keyPath: kp])
            }
        }.joined())
    }
}

/// how a value appears in a URL representation
public protocol CustomURLRepresentationParameterConvertible {
    var urlRepresentationParameter: String? { get }
}
func _isimURLParameter(_ v: Any) -> String {
    let raw: String
    if let c = v as? CustomURLRepresentationParameterConvertible, let s = c.urlRepresentationParameter { raw = s }
    else if let o = v as? _IsimOptional { return o._isimUnwrapped.map(_isimURLParameter) ?? "" }
    else if let e = v as? any AppEntity { raw = "\(e.id)" }
    else if let e = v as? any AppEnum { raw = e.rawValue }
    else { raw = "\(v)" }
    return raw.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? raw
}

@available(iOS 18.0, *)
@_alwaysEmitConformanceMetadata public protocol URLRepresentableEntity: AppEntity {
    typealias URLRepresentation = EntityURLRepresentation<Self>
    static var urlRepresentation: URLRepresentation { get }
}
@available(iOS 18.0, *)
extension URLRepresentableEntity {
    public var urlRepresentation: URL? { Self.urlRepresentation.url(self) }
}
@available(iOS 18.0, *)
@_alwaysEmitConformanceMetadata public protocol URLRepresentableEnum: AppEnum {
    typealias URLRepresentation = EnumURLRepresentation<Self>
    static var urlRepresentation: URLRepresentation { get }
}
@available(iOS 18.0, *)
extension URLRepresentableEnum {
    public var urlRepresentation: URL? { Self.urlRepresentation.url(self) }
}
/// an intent that stands for a URL: as an OpenIntent, the system opens the URL instead of performing it
@available(iOS 18.0, *)
@_alwaysEmitConformanceMetadata public protocol URLRepresentableIntent: AppIntent {
    typealias URLRepresentation = IntentURLRepresentation<Self>
    static var urlRepresentation: URLRepresentation { get }
}
@available(iOS 18.0, *)
extension URLRepresentableIntent {
    public var urlRepresentation: URL? { Self.urlRepresentation.url(self) }
}
@available(iOS 18.0, *)
extension URLRepresentableIntent where Self: OpenIntent, Self.Value: URLRepresentableEntity {
    /// the target's URL
    public static var urlRepresentation: URLRepresentation { "" }
    public var urlRepresentation: URL? { target.urlRepresentation }
}

/// opens a URL (as the result of another intent: `.result(opensIntent: OpenURLIntent(url))`)
@available(iOS 18.0, *)
public struct OpenURLIntent: AppIntent {
    public static var title: LocalizedStringResource { "Open URL" }
    public static var isDiscoverable: Bool { false }
    @Parameter(title: "URL") public var url: URL
    public init() {}
    public init(_ url: URL) { self.init(); self.url = url }
    public init(urlRepresentable entity: some URLRepresentableEntity) async throws {
        guard let u = entity.urlRepresentation else { throw AppIntentError.Unrecoverable.unknown }
        self.init(u)
    }
    public init(urlRepresentable value: some URLRepresentableEnum) throws {
        guard let u = value.urlRepresentation else { throw AppIntentError.Unrecoverable.unknown }
        self.init(u)
    }
    @MainActor public func perform() async throws -> some IntentResult {
        _IsimOpenURL.open(url)
        return _IntentResultValue<Void>(value: nil, dialog: nil)
    }
}
@MainActor enum _IsimOpenURL {
    static func open(_ url: URL) {
        NSLog("isim AppIntents: opens %@", url.absoluteString)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    /// a URLRepresentableIntent that is an OpenIntent opens its URL instead of performing
    static func url(for intent: any AppIntent) -> URL? {
        guard #available(iOS 18.0, *), intent is any OpenIntent, let r = intent as? any URLRepresentableIntent else { return nil }
        return r.urlRepresentation
    }
}

// MARK: - intent kinds

/// an intent that opens the app's camera experience (from the Lock Screen and Control Center on iOS 18); isim runs it in
/// the app, in the foreground. appContext is kept in the app's container for the capture extension to read
@available(iOS 18.0, *)
@_alwaysEmitConformanceMetadata public protocol CameraCaptureIntent: AppIntent {
    associatedtype AppContext: Codable & Sendable = Never
}
@available(iOS 18.0, *)
extension CameraCaptureIntent {
    public static var openAppWhenRun: Bool { true }
    static var _isimContextPath: String {
        (NSHomeDirectory() as NSString).appendingPathComponent("Library/isim/CameraCaptureContext-\(_isimTypeName(Self.self)).json")
    }
    public static var appContext: AppContext? {
        get async { FileManager.default.contents(atPath: _isimContextPath).flatMap { try? JSONDecoder().decode(AppContext.self, from: $0) } }
    }
    public static func updateAppContext(_ context: AppContext?) async throws {
        let p = _isimContextPath
        try? FileManager.default.createDirectory(atPath: (p as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        if let context { FileManager.default.createFile(atPath: p, contents: try JSONEncoder().encode(context)) }
        else { try? FileManager.default.removeItem(atPath: p) }
    }
}
/// an intent that records audio: like iOS, it may start recording in the background (it should start a Live Activity)
@available(iOS 18.0, *)
@_alwaysEmitConformanceMetadata public protocol AudioRecordingIntent: AppIntent {}

/// the packages (frameworks, Swift packages) whose intents an app or package includes
public protocol AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { get }
}
extension AppIntentsPackage {
    public static var includedPackages: [any AppIntentsPackage.Type] { [] }
}

// MARK: - snippet intents (iOS 26)

/// an intent whose result is an interactive snippet: Siri shows its view, and buttons in it (Button(intent:)) run
/// other intents, after which the snippet is performed again and redrawn
@available(iOS 26.0, *)
@_alwaysEmitConformanceMetadata public protocol SnippetIntent: AppIntent where PerformResult: ShowsSnippetView {}
@available(iOS 26.0, *)
extension SnippetIntent {
    public static var isDiscoverable: Bool { false }
    /// asks the system to perform the snippet intent again and redraw its view
    public static func reload() {
        NSLog("isim AppIntents: snippet %@ reloads", _isimTypeName(Self.self))
        Task { @MainActor in await _IsimSnippets.reload(_isimTypeName(Self.self)) }
    }
}
@available(iOS 26.0, *)
public protocol ShowsSnippetIntent: IntentResult {}
@available(iOS 26.0, *)
extension _IntentResultValue: ShowsSnippetIntent {}
/// a snippet intent that shows nothing
@available(iOS 26.0, *)
public struct EmptySnippetIntent: SnippetIntent {
    public static var title: LocalizedStringResource { "Empty Snippet" }
    public init() {}
    @MainActor public func perform() async throws -> some IntentResult & ShowsSnippetView { _IntentResultValue<Void>(value: nil, dialog: nil) }
}
extension IntentResult {
    @available(iOS 26.0, *)
    public static func result<S: SnippetIntent>(snippetIntent: S) -> _IntentResultValue<Void> where Self == _IntentResultValue<Void> {
        var r = _IntentResultValue<Void>(value: nil, dialog: nil)
        r._snippetIntent = snippetIntent
        return r
    }
    @available(iOS 26.0, *)
    public static func result<S: SnippetIntent>(dialog: IntentDialog, snippetIntent: S) -> _IntentResultValue<Void> where Self == _IntentResultValue<Void> {
        var r = _IntentResultValue<Void>(value: nil, dialog: dialog)
        r._snippetIntent = snippetIntent
        return r
    }
    @available(iOS 26.0, *)
    public static func result<V, S: SnippetIntent>(value: V, dialog: IntentDialog, snippetIntent: S) -> _IntentResultValue<V> where Self == _IntentResultValue<V> {
        var r = _IntentResultValue<V>(value: value, dialog: dialog)
        r._snippetIntent = snippetIntent
        return r
    }
}

/// the snippet intents on screen: reload() performs them again and redraws (snippet-N.png in the run directory)
@MainActor enum _IsimSnippets {
    static var shown: [String: any AppIntent] = [:]
    static func view(_ intent: any AppIntent) async -> AnyView? {
        guard let r = try? await _performAny(intent) as? any _ResultCarrying else { return nil }
        return r._snippetView
    }
    static func reload(_ type: String) async {
        guard let intent = shown[type], let v = await view(intent), let png = _IsimRun.render(v) else { return }
        _IsimRun.channel?.write(["type": "snippet", "snippet": png])
        NSLog("isim AppIntents: snippet %@ redrawn", type)
    }
}
@MainActor func _performAny<I: AppIntent>(_ intent: I) async throws -> any IntentResult { try await intent.perform() }
