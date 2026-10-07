// isim AppIntents: intents, parameters, results and SwiftUI's Button(intent:) / Toggle(isOn:intent:).
// Intents run in-process: in the app, or in a widget extension for interactive widgets (WidgetKit runs the
// intent of the tapped button, then reloads the widget's timeline, like iOS 17).
// Not on isim: Siri, the Shortcuts app, App Shortcuts surfaced in Spotlight (AppShortcutsProvider compiles; its
// shortcuts are not listed anywhere), Focus filters, entity queries from the system.
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
    public init(stringLiteral value: String) { text = value }
    public init(_ text: LocalizedStringResource, categoryName: LocalizedStringResource? = nil) { self.text = text.description }
}
public struct IntentDialog: ExpressibleByStringInterpolation, Sendable, CustomStringConvertible {
    public let text: String
    public init(stringLiteral value: String) { text = value }
    public init(stringInterpolation: DefaultStringInterpolation) { text = String(stringInterpolation: stringInterpolation) }
    public init(_ r: LocalizedStringResource) { text = r.description }
    public var description: String { text }
}

// MARK: - intents and results

public protocol IntentResult {}
public protocol ReturnsValue<Value>: IntentResult { associatedtype Value }
public protocol ProvidesDialog: IntentResult {}
public protocol OpensIntent: IntentResult {}
public protocol ShowsSnippetView: IntentResult {}
public struct _IntentResultValue<Value>: IntentResult, ReturnsValue, ProvidesDialog, ShowsSnippetView {
    public let value: Value?
    public let dialog: IntentDialog?
}
extension IntentResult {
    public static func result() -> _IntentResultValue<Void> where Self == _IntentResultValue<Void> { .init(value: nil, dialog: nil) }
    public static func result(dialog: IntentDialog) -> _IntentResultValue<Void> where Self == _IntentResultValue<Void> { .init(value: nil, dialog: dialog) }
    public static func result<V>(value: V) -> _IntentResultValue<V> where Self == _IntentResultValue<V> { .init(value: value, dialog: nil) }
    public static func result<V>(value: V, dialog: IntentDialog) -> _IntentResultValue<V> where Self == _IntentResultValue<V> { .init(value: value, dialog: dialog) }
    public static func result<Content: View>(dialog: IntentDialog, @ViewBuilder view: () -> Content) -> _IntentResultValue<Void> where Self == _IntentResultValue<Void> { .init(value: nil, dialog: dialog) }
}

public protocol AppIntent: Sendable {
    associatedtype PerformResult: IntentResult
    static var title: LocalizedStringResource { get }
    static var description: IntentDescription? { get }
    static var openAppWhenRun: Bool { get }
    static var isDiscoverable: Bool { get }
    init()
    @MainActor func perform() async throws -> PerformResult
}
extension AppIntent {
    public static var description: IntentDescription? { nil }
    public static var openAppWhenRun: Bool { false }
    public static var isDiscoverable: Bool { true }
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

/// Runs an intent and logs its result (isim: there is no Siri/Shortcuts UI to show the dialog).
@MainActor public func _isimPerform<I: AppIntent>(_ intent: I) async {
    NSLog("isim AppIntents: performing %@", String(describing: I.title.description))
    do {
        let r = try await intent.perform()
        if let d = (r as? any _DialogCarrying)?._dialog { NSLog("isim AppIntents: %@ -> “%@”", I.title.description, d.text) }
    } catch { NSLog("isim AppIntents: %@ failed: %@", I.title.description, "\(error)") }
}
protocol _DialogCarrying { var _dialog: IntentDialog? { get } }
extension _IntentResultValue: _DialogCarrying { var _dialog: IntentDialog? { dialog } }

// MARK: - parameters

@propertyWrapper
public final class IntentParameter<Value>: @unchecked Sendable {
    public var wrappedValue: Value
    public let title: LocalizedStringResource
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default value: Value) { self.title = title; wrappedValue = value }
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil) where Value: ExpressibleByNilLiteral { self.title = title; wrappedValue = nil }
    public init(title: LocalizedStringResource, default value: Value, inclusiveRange: (Value, Value)) { self.title = title; wrappedValue = value }
    public init(wrappedValue: Value, title: LocalizedStringResource) { self.title = title; self.wrappedValue = wrappedValue }
    public var projectedValue: IntentParameter<Value> { self }
}
public typealias Parameter = IntentParameter

// MARK: - entities and enums (types only: the system does not query them on isim)

public struct DisplayRepresentation: ExpressibleByStringLiteral, Sendable {
    public let title: LocalizedStringResource
    public var subtitle: LocalizedStringResource?
    public init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil, image: DisplayRepresentation.Image? = nil) { self.title = title; self.subtitle = subtitle }
    public init(stringLiteral value: String) { title = LocalizedStringResource(String.LocalizationValue(value)) }
    public struct Image: Sendable { public init(systemName: String) {} }
}
public struct TypeDisplayRepresentation: ExpressibleByStringLiteral, Sendable {
    public let name: LocalizedStringResource
    public init(name: LocalizedStringResource) { self.name = name }
    public init(stringLiteral value: String) { name = LocalizedStringResource(String.LocalizationValue(value)) }
}
public protocol AppValue {}
public protocol AppEnum: CaseIterable, RawRepresentable, Hashable, AppValue, Sendable where RawValue == String {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { get }
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] { get }
}
public protocol EntityQuery: Sendable { init() }
public protocol AppEntity: Identifiable, Sendable {
    associatedtype DefaultQuery: EntityQuery
    static var typeDisplayRepresentation: TypeDisplayRepresentation { get }
    var displayRepresentation: DisplayRepresentation { get }
    static var defaultQuery: DefaultQuery { get }
}

// MARK: - App Shortcuts (compile; not surfaced on isim)

public struct AppShortcutPhrase<Intent: AppIntent>: ExpressibleByStringInterpolation, Sendable {
    public let text: String
    public init(stringLiteral value: String) { text = value }
    public init(stringInterpolation: AppShortcutPhraseInterpolation) { text = stringInterpolation.text }
}
public struct AppShortcutPhraseInterpolation: StringInterpolationProtocol {
    var text = ""
    public init(literalCapacity: Int, interpolationCount: Int) {}
    public mutating func appendLiteral(_ s: String) { text += s }
    public mutating func appendInterpolation(_ v: Any) { text += "${applicationName}" }
}
public struct AppShortcut: Sendable {
    public let title: String
    public init<I: AppIntent>(intent: I, phrases: [AppShortcutPhrase<I>], shortTitle: LocalizedStringResource, systemImageName: String) { title = shortTitle.description }
    public init<I: AppIntent>(intent: I, phrases: [AppShortcutPhrase<I>]) { title = I.title.description }
}
@resultBuilder public struct AppShortcutsBuilder {
    public static func buildBlock(_ s: AppShortcut...) -> [AppShortcut] { s }
    public static func buildExpression(_ s: AppShortcut) -> AppShortcut { s }
}
public protocol AppShortcutsProvider {
    @AppShortcutsBuilder static var appShortcuts: [AppShortcut] { get }
    static var shortcutTileColor: ShortcutTileColor { get }
}
extension AppShortcutsProvider {
    public static var shortcutTileColor: ShortcutTileColor { .blue }
    public static func updateAppShortcutParameters() {}
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
