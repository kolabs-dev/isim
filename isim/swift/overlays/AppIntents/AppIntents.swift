// isim AppIntents: intents, parameters, results, entities and enums, App Shortcuts, and SwiftUI's Button(intent:) /
// Toggle(isOn:intent:).
// Intents run in-process: in the app (controls, or a request from the system: Siri, the Shortcuts app, Spotlight —
// System.swift), or in a widget extension for interactive widgets (WidgetKit runs the intent of the tapped button, then
// reloads the widget's timeline, like iOS 17).
// App Shortcuts (AppShortcutsProvider) are read by the system from the app: the home screen starts the app's
// executable in a metadata mode (System.swift, adapted: Apple extracts them at build time into Metadata.appintents)
// and lists them in the Shortcuts app, matches their phrases in the simulated Siri and shows them in Spotlight.
// The protocols the system looks up at run time keep their conformances in apps compiled with -O
// (@_alwaysEmitConformanceMetadata, as Apple's AppIntents does), even for intents nothing references.
// Focus filters (SetFocusFilterIntent): Focus.swift.
// Not on isim: App Intents extensions, parameter summaries, intent donations.
import Foundation
import SwiftUI

// MARK: - strings

// LocalizedStringResource is Foundation's (as on Apple platforms). isim 0.5.0 declared it here; Foundation's keeps that
// mangling (@_originallyDefinedIn) and this library re-exports Foundation, so apps built with 0.5.0 still link.
extension String {
    /// 0.5.0's String(localized:) for the AppIntents type (Foundation's public one is used by new code)
    @usableFromInline init(localized r: LocalizedStringResource) { self = r.description }
}

public struct IntentDescription: ExpressibleByStringLiteral, Sendable {
    public let text: String
    public var categoryName: String? { _category }
    public var searchKeywords: [String] { _keywords }
    let _category: String?
    let _keywords: [String]
    public init(stringLiteral value: String) { text = value; _category = nil; _keywords = [] }
    public init(_ text: LocalizedStringResource, categoryName: LocalizedStringResource? = nil) {
        self.text = text.description; _category = categoryName?.description; _keywords = []
    }
    public init(_ text: LocalizedStringResource, categoryName: LocalizedStringResource? = nil, searchKeywords: [LocalizedStringResource],
                resultValueName: LocalizedStringResource? = nil) {
        self.text = text.description; _category = categoryName?.description; _keywords = searchKeywords.map { $0.description }
    }
}
public struct IntentDialog: ExpressibleByStringInterpolation, Sendable, CustomStringConvertible {
    public let text: String
    public init(stringLiteral value: String) { text = value }
    public init(stringInterpolation: DefaultStringInterpolation) { text = String(stringInterpolation: stringInterpolation) }
    public init(_ r: LocalizedStringResource) { text = r.description }
    /// the full text is shown (isim shows the full form; Siri on iOS speaks the supporting one when it shows a snippet)
    public init(full: LocalizedStringResource, supporting: LocalizedStringResource) { text = full.description }
    public init(full: LocalizedStringResource, systemImageName: String) { text = full.description }
    public var description: String { text }
}

// MARK: - intents and results

public protocol IntentResult {}
public protocol ReturnsValue<Value>: IntentResult { associatedtype Value }
public protocol ProvidesDialog: IntentResult {}
public protocol OpensIntent: IntentResult {}
public protocol ShowsSnippetView: IntentResult {}
public struct _IntentResultValue<Value>: IntentResult, ReturnsValue, ProvidesDialog, ShowsSnippetView, OpensIntent {
    public let value: Value?
    public let dialog: IntentDialog?
    var _snippet: AnyView? = nil
    var _opens: (any AppIntent)? = nil
    public init(value: Value?, dialog: IntentDialog?) { self.value = value; self.dialog = dialog }
    init(value: Value?, dialog: IntentDialog?, snippet: AnyView?, opens: (any AppIntent)?) {
        self.value = value; self.dialog = dialog; _snippet = snippet; _opens = opens
    }
}
extension IntentResult {
    public static func result() -> _IntentResultValue<Void> where Self == _IntentResultValue<Void> { .init(value: nil, dialog: nil) }
    public static func result(dialog: IntentDialog) -> _IntentResultValue<Void> where Self == _IntentResultValue<Void> { .init(value: nil, dialog: dialog) }
    public static func result<V>(value: V) -> _IntentResultValue<V> where Self == _IntentResultValue<V> { .init(value: value, dialog: nil) }
    public static func result<V>(value: V, dialog: IntentDialog) -> _IntentResultValue<V> where Self == _IntentResultValue<V> { .init(value: value, dialog: dialog) }
    public static func result<Content: View>(dialog: IntentDialog, @ViewBuilder view: () -> Content) -> _IntentResultValue<Void> where Self == _IntentResultValue<Void> {
        .init(value: nil, dialog: dialog, snippet: AnyView(view()), opens: nil)
    }
    public static func result<Content: View>(@ViewBuilder view: () -> Content) -> _IntentResultValue<Void> where Self == _IntentResultValue<Void> {
        .init(value: nil, dialog: nil, snippet: AnyView(view()), opens: nil)
    }
    public static func result<V, Content: View>(value: V, dialog: IntentDialog, @ViewBuilder view: () -> Content) -> _IntentResultValue<V> where Self == _IntentResultValue<V> {
        .init(value: value, dialog: dialog, snippet: AnyView(view()), opens: nil)
    }
    public static func result<I: AppIntent>(opensIntent: I) -> _IntentResultValue<Void> where Self == _IntentResultValue<Void> {
        .init(value: nil, dialog: nil, snippet: nil, opens: opensIntent)
    }
    public static func result<I: AppIntent>(opensIntent: I, dialog: IntentDialog) -> _IntentResultValue<Void> where Self == _IntentResultValue<Void> {
        .init(value: nil, dialog: dialog, snippet: nil, opens: opensIntent)
    }
    public static func result<V, I: AppIntent>(value: V, opensIntent: I) -> _IntentResultValue<V> where Self == _IntentResultValue<V> {
        .init(value: value, dialog: nil, snippet: nil, opens: opensIntent)
    }
}

/// Whether an intent may run while the device is locked (isim's Siri asks to unlock first when it is not allowed).
public enum IntentAuthenticationPolicy: Sendable {
    case alwaysAllowed, requiresAuthentication, requiresLocalDeviceAuthentication
}

@_alwaysEmitConformanceMetadata public protocol AppIntent: Sendable {
    associatedtype PerformResult: IntentResult
    static var title: LocalizedStringResource { get }
    static var description: IntentDescription? { get }
    static var openAppWhenRun: Bool { get }
    static var isDiscoverable: Bool { get }
    static var authenticationPolicy: IntentAuthenticationPolicy { get }
    init()
    @MainActor func perform() async throws -> PerformResult
}
extension AppIntent {
    public static var description: IntentDescription? { nil }
    public static var openAppWhenRun: Bool { false }
    public static var isDiscoverable: Bool { true }
    public static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
}
/// intents that configure a widget (AppIntentConfiguration)
public protocol WidgetConfigurationIntent: AppIntent {}
extension WidgetConfigurationIntent {
    @MainActor public func perform() async throws -> some IntentResult { _IntentResultValue<Void>(value: nil, dialog: nil) }
}
public protocol SetValueIntent: AppIntent { associatedtype ValueType; var value: ValueType { get set } }
public protocol AudioPlaybackIntent: AppIntent {}
public protocol LiveActivityIntent: AppIntent {}
public protocol ForegroundContinuableIntent: AppIntent {}
/// Opens the app to an entity (the system runs it in the app, in the foreground).
public protocol OpenIntent: AppIntent {
    associatedtype Value: AppEntity
    var target: Value { get set }
}
extension OpenIntent {
    public static var openAppWhenRun: Bool { true }
}

/// The verb of a confirmation's button.
public struct ConfirmationActionName: Sendable, Equatable {
    public let title: String
    init(_ t: String) { title = t }
    public static let add = Self("Add"), addData = Self("Add"), book = Self("Book"), buy = Self("Buy"), call = Self("Call")
    public static let `continue` = Self("Continue"), `do` = Self("Do It"), go = Self("Go"), order = Self("Order"), open = Self("Open")
    public static let pay = Self("Pay"), post = Self("Post"), request = Self("Request"), run = Self("Run"), search = Self("Search")
    public static let send = Self("Send"), set = Self("Set"), share = Self("Share"), start = Self("Start"), toggle = Self("Toggle"), view = Self("View")
    public static func custom(acceptLabel: LocalizedStringResource, acceptAlternatives: [LocalizedStringResource] = [], denyLabel: LocalizedStringResource,
                              denyAlternatives: [LocalizedStringResource] = [], destructive: Bool = false) -> Self { Self(acceptLabel.description) }
}

extension AppIntent {
    /// Asks the person to confirm before the intent goes on (Siri / the Shortcuts run UI), showing a result's dialog and
    /// snippet; throws when they cancel.
    @MainActor public func requestConfirmation(result: some IntentResult, confirmationActionName: ConfirmationActionName = .go, showPrompt: Bool = true) async throws {
        let r = result as? any _ResultCarrying
        try await _IsimRun.confirm(dialog: r?._dialog?.text, snippet: r?._snippetView, action: confirmationActionName.title)
    }
    @MainActor public func requestConfirmation(actionName: ConfirmationActionName = .go, dialog: IntentDialog? = nil) async throws {
        try await _IsimRun.confirm(dialog: dialog?.text, snippet: nil, action: actionName.title)
    }
    @MainActor public func requestConfirmation<Content: View>(actionName: ConfirmationActionName = .go, dialog: IntentDialog? = nil,
                                                              @ViewBuilder content: () -> Content) async throws {
        try await _IsimRun.confirm(dialog: dialog?.text, snippet: AnyView(content()), action: actionName.title)
    }
}

/// Runs an intent and logs its result: controls (Button(intent:)) and interactive widgets, which show no dialog.
@MainActor public func _isimPerform<I: AppIntent>(_ intent: I) async {
    NSLog("isim AppIntents: performing %@", String(describing: I.title.description))
    do {
        let r = try await intent.perform()
        if let d = (r as? any _DialogCarrying)?._dialog { NSLog("isim AppIntents: %@ -> “%@”", I.title.description, d.text) }
    } catch { NSLog("isim AppIntents: %@ failed: %@", I.title.description, "\(error)") }
}
protocol _DialogCarrying { var _dialog: IntentDialog? { get } }
extension _IntentResultValue: _DialogCarrying { var _dialog: IntentDialog? { dialog } }
protocol _ResultCarrying: _DialogCarrying {
    var _snippetView: AnyView? { get }
    var _opensIntent: (any AppIntent)? { get }
    var _valueAny: Any? { get }
}
extension _IntentResultValue: _ResultCarrying {
    var _snippetView: AnyView? { _snippet }
    var _opensIntent: (any AppIntent)? { _opens }
    var _valueAny: Any? { Value.self == Void.self ? nil : value.map { $0 as Any } }
}

// MARK: - parameters

/// Optional value types (a parameter of an optional type is not required)
protocol _IsimOptional { static var _isimNone: Any { get }; static var _isimWrapped: Any.Type { get }; var _isimUnwrapped: Any? { get } }
extension Optional: _IsimOptional {
    static var _isimNone: Any { Optional<Wrapped>.none as Any }
    static var _isimWrapped: Any.Type { Wrapped.self }
    var _isimUnwrapped: Any? { self.map { $0 as Any } }
}

@propertyWrapper
public final class IntentParameter<Value>: @unchecked Sendable {
    var _value: Value?
    public let title: LocalizedStringResource
    let _description: LocalizedStringResource?
    let _requestValueDialog: IntentDialog?
    public var wrappedValue: Value {
        get {
            if let v = _value { return v }
            if let none = (Value.self as? _IsimOptional.Type)?._isimNone as? Value { return none }
            fatalError("isim AppIntents: the parameter “\(title.description)” has no value (ask for it with requestValue() or give it a default)")
        }
        set { _value = newValue }
    }
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default value: Value) {
        self.title = title; _description = description; _requestValueDialog = nil; _value = value
    }
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil) where Value: ExpressibleByNilLiteral {
        self.title = title; _description = description; _requestValueDialog = nil; _value = nil
    }
    /// a required parameter: the system asks for it before perform() when it has no value
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil) {
        self.title = title; _description = description; _requestValueDialog = nil; _value = nil
    }
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog?) {
        self.title = title; _description = description; _requestValueDialog = requestValueDialog; _value = nil
    }
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default value: Value, requestValueDialog: IntentDialog?) {
        self.title = title; _description = description; _requestValueDialog = requestValueDialog; _value = value
    }
    public init(title: LocalizedStringResource, default value: Value, inclusiveRange: (Value, Value)) {
        self.title = title; _description = nil; _requestValueDialog = nil; _value = value
    }
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default value: Value, inclusiveRange: (Value, Value),
                requestValueDialog: IntentDialog?) {
        self.title = title; _description = description; _requestValueDialog = requestValueDialog; _value = value
    }
    public init(wrappedValue: Value, title: LocalizedStringResource) { self.title = title; _description = nil; _requestValueDialog = nil; _value = wrappedValue }
    public var projectedValue: IntentParameter<Value> { self }
    public var description: LocalizedStringResource? { _description }

    /// Asks the person for the value (Siri / the Shortcuts run UI) and keeps it.
    @MainActor public func requestValue(_ dialog: IntentDialog? = nil) async throws -> Value {
        let v = try await _IsimRun.ask(self, dialog: dialog?.text ?? _requestValueDialog?.text, among: nil)
        guard let typed = _IsimValues.cast(v, to: Value.self) else { throw _IsimIntentError.cancelled }
        _value = typed
        return typed
    }
    /// Asks the person to choose one of several values.
    @MainActor public func requestDisambiguation(among values: [Value], dialog: IntentDialog? = nil) async throws -> Value {
        let v = try await _IsimRun.ask(self, dialog: dialog?.text ?? "Which one?", among: values.map { $0 as Any })
        guard let typed = _IsimValues.cast(v, to: Value.self) else { throw _IsimIntentError.cancelled }
        _value = typed
        return typed
    }
    /// Asks the person to confirm a value: true when they do.
    @MainActor public func requestConfirmation(for value: Value, dialog: IntentDialog? = nil) async throws -> Bool {
        do {
            try await _IsimRun.confirm(dialog: dialog?.text ?? "Did you mean \(_IsimValues.describe(value))?", snippet: nil, action: "Yes", cancel: "No")
            return true
        } catch _IsimIntentError.cancelled { return false }
    }
    /// Thrown from perform(): the system asks for the value, then runs perform() again.
    public func needsValueError(_ dialog: IntentDialog? = nil) -> some Error { _IsimNeedsValue(parameter: self, dialog: dialog?.text) }
}
public typealias Parameter = IntentParameter

struct _IsimNeedsValue: Error, CustomStringConvertible, @unchecked Sendable {
    let parameter: AnyObject
    let dialog: String?
    var description: String { "needsValue" }
}
enum _IsimIntentError: Error, CustomStringConvertible {
    case cancelled, noRun
    var description: String { self == .cancelled ? "cancelled" : "no one to ask (the intent was not run by the system)" }
}

/// a parameter seen without its value type (System.swift)
protocol _IsimAnyParameter: AnyObject {
    var _isimTitle: String { get }
    var _isimPrompt: String? { get }
    var _isimHasValue: Bool { get }
    var _isimOptional: Bool { get }
    var _isimValueType: Any.Type { get }
    var _isimCurrent: Any? { get }
    func _isimSet(_ v: Any?) -> Bool
}
extension IntentParameter: _IsimAnyParameter {
    var _isimTitle: String { title.description }
    var _isimPrompt: String? { _requestValueDialog?.text }
    var _isimHasValue: Bool {
        guard let v = _value else { return false }
        if let o = v as? _IsimOptional { return o._isimUnwrapped != nil }
        return true
    }
    var _isimOptional: Bool { Value.self is _IsimOptional.Type }
    var _isimValueType: Any.Type { (Value.self as? _IsimOptional.Type)?._isimWrapped ?? Value.self }
    var _isimCurrent: Any? {
        guard let v = _value else { return nil }
        if let o = v as? _IsimOptional { return o._isimUnwrapped }
        return v
    }
    func _isimSet(_ v: Any?) -> Bool {
        guard let v else { if _isimOptional { _value = nil; return true }; return false }
        guard let typed = _IsimValues.cast(v, to: Value.self) else { return false }
        _value = typed
        return true
    }
}

// MARK: - entities and enums

public struct DisplayRepresentation: ExpressibleByStringLiteral, Sendable {
    public let title: LocalizedStringResource
    public var subtitle: LocalizedStringResource?
    public var image: DisplayRepresentation.Image? { _image }
    var _image: DisplayRepresentation.Image?
    public init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil, image: DisplayRepresentation.Image? = nil) {
        self.title = title; self.subtitle = subtitle; _image = image
    }
    public init(stringLiteral value: String) { title = LocalizedStringResource(String.LocalizationValue(value)) }
    public struct Image: Sendable {
        public let systemName: String?
        public init(systemName: String) { self.systemName = systemName }
        public init(named name: String) { systemName = nil }
    }
}
public struct TypeDisplayRepresentation: ExpressibleByStringLiteral, Sendable {
    public let name: LocalizedStringResource
    public init(name: LocalizedStringResource) { self.name = name }
    public init(name: LocalizedStringResource, numericFormat: LocalizedStringResource) { self.name = name }
    public init(stringLiteral value: String) { name = LocalizedStringResource(String.LocalizationValue(value)) }
}
public protocol AppValue {}
@_alwaysEmitConformanceMetadata public protocol AppEnum: CaseIterable, RawRepresentable, Hashable, AppValue, Sendable where RawValue == String {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { get }
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] { get }
}
/// How the system finds entities: suggestedEntities() for its lists and App Shortcut phrases, entities(for:) by id.
@_alwaysEmitConformanceMetadata public protocol EntityQuery: Sendable {
    associatedtype Entity: AppEntity = _IsimNoEntity
    init()
    func entities(for identifiers: [Entity.ID]) async throws -> [Entity]
    func suggestedEntities() async throws -> [Entity]
}
extension EntityQuery {
    public func entities(for identifiers: [Entity.ID]) async throws -> [Entity] { [] }
    public func suggestedEntities() async throws -> [Entity] { [] }
}
/// Entities found from what the person typed or said.
public protocol EntityStringQuery: EntityQuery {
    func entities(matching string: String) async throws -> [Entity]
}
/// Small sets of entities the system can list completely.
public protocol EnumerableEntityQuery: EntityQuery {
    func allEntities() async throws -> [Entity]
}
@_alwaysEmitConformanceMetadata public protocol AppEntity: Identifiable, Sendable {
    associatedtype DefaultQuery: EntityQuery
    static var typeDisplayRepresentation: TypeDisplayRepresentation { get }
    var displayRepresentation: DisplayRepresentation { get }
    static var defaultQuery: DefaultQuery { get }
}
/// the default entity of a query that names none (isim: keeps queries written for isim before 0.17 compiling)
public struct _IsimNoEntity: AppEntity {
    public var id: String
    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Entity" }
    public var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: LocalizedStringResource(String.LocalizationValue(id))) }
    public static var defaultQuery: _IsimNoEntityQuery { _IsimNoEntityQuery() }
}
public struct _IsimNoEntityQuery: EntityQuery {
    public typealias Entity = _IsimNoEntity
    public init() {}
}

// MARK: - App Shortcuts

/// `\(.applicationName)` in an App Shortcut phrase
public enum AppShortcutPhraseToken: Sendable { case applicationName }

public struct AppShortcutPhrase<Intent: AppIntent>: ExpressibleByStringInterpolation, Sendable {
    public let text: String
    /// the phrase with ${applicationName} and ${parameter} placeholders (resolved when the system reads it)
    let _template: @Sendable () -> String
    public init(stringLiteral value: String) { text = value; _template = { value } }
    public init(stringInterpolation: AppShortcutPhraseInterpolation) { text = stringInterpolation.text; let t = stringInterpolation.text; _template = { t } }
    public init(stringInterpolation: StringInterpolation) {
        let parts = stringInterpolation.parts
        text = parts.map { if case .text(let s) = $0 { return s } else { return "${…}" } }.joined()
        _template = {
            let probe = Intent()
            return parts.map { part -> String in
                switch part {
                case .text(let s): return s
                case .app: return "${applicationName}"
                case .parameter(let kp): return "${" + (_IsimReflection.parameterName(probe, keyPath: kp) ?? "?") + "}"
                }
            }.joined()
        }
    }
    enum _Part: @unchecked Sendable { case text(String), app, parameter(AnyKeyPath) }
    public struct StringInterpolation: StringInterpolationProtocol {
        var parts: [_Part] = []
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ s: String) { parts.append(.text(s)) }
        public mutating func appendInterpolation(_ token: AppShortcutPhraseToken) { parts.append(.app) }
        public mutating func appendInterpolation<Value>(_ keyPath: KeyPath<Intent, IntentParameter<Value>>) { parts.append(.parameter(keyPath)) }
    }
}
/// isim before 0.17: phrases were plain text (every interpolation became ${applicationName})
public struct AppShortcutPhraseInterpolation: StringInterpolationProtocol {
    var text = ""
    public init(literalCapacity: Int, interpolationCount: Int) {}
    public mutating func appendLiteral(_ s: String) { text += s }
    public mutating func appendInterpolation(_ v: Any) { text += "${applicationName}" }
}
public struct AppShortcut: Sendable {
    public let title: String
    let _intent: any AppIntent
    let _phrases: [@Sendable () -> String]
    let _shortTitle: String?
    let _systemImageName: String?
    public init<I: AppIntent>(intent: I, phrases: [AppShortcutPhrase<I>], shortTitle: LocalizedStringResource, systemImageName: String) {
        title = shortTitle.description; _intent = intent; _phrases = phrases.map { $0._template }; _shortTitle = shortTitle.description; _systemImageName = systemImageName
    }
    public init<I: AppIntent>(intent: I, phrases: [AppShortcutPhrase<I>]) {
        title = I.title.description; _intent = intent; _phrases = phrases.map { $0._template }; _shortTitle = nil; _systemImageName = nil
    }
}
@resultBuilder public struct AppShortcutsBuilder {
    public static func buildBlock(_ s: AppShortcut...) -> [AppShortcut] { s }
    public static func buildExpression(_ s: AppShortcut) -> AppShortcut { s }
}
@_alwaysEmitConformanceMetadata public protocol AppShortcutsProvider {
    @AppShortcutsBuilder static var appShortcuts: [AppShortcut] { get }
    static var shortcutTileColor: ShortcutTileColor { get }
}
extension AppShortcutsProvider {
    public static var shortcutTileColor: ShortcutTileColor { .blue }
    /// Tells the system the entities App Shortcut phrases can name changed (it asks suggestedEntities() again).
    public static func updateAppShortcutParameters() {
        let shortcuts = appShortcuts
        Task { @MainActor in await _IsimMetadata.updateParameters(shortcuts) }
    }
}
public enum ShortcutTileColor: Sendable { case red, orange, yellow, lime, grape, purple, pink, teal, blue, navy, lightBlue, gray, grayBlue, grayGreen, grayBrown, tangerine }

// MARK: - SwiftUI controls that run intents

/// intents started by controls and not finished yet (WidgetKit waits for them before reloading a widget)
public enum _IsimIntentControls {
    nonisolated(unsafe) public static var running = 0
}
extension Button {
    public init<I: AppIntent>(intent: I, @ViewBuilder label: () -> Label) {
        self.init(action: { _IsimIntentControls.running += 1; Task { @MainActor in await _isimPerform(intent); _IsimIntentControls.running -= 1 } }, label: label)
    }
}
extension Button where Label == Text {
    public init<I: AppIntent>(_ title: LocalizedStringKey, intent: I) { self.init(intent: intent) { Text(title) } }
}
extension Toggle {
    public init<I: AppIntent>(isOn: Bool, intent: I, @ViewBuilder label: () -> Label) {
        self.init(isOn: Binding(get: { isOn }, set: { _ in _IsimIntentControls.running += 1; Task { @MainActor in await _isimPerform(intent); _IsimIntentControls.running -= 1 } }), label: label)
    }
}
