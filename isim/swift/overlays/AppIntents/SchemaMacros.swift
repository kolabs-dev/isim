// isim AppIntents: types made to conform to an App Intents schema, for Siri with Apple Intelligence (iOS 18:
// @AssistantIntent(schema:) / @AssistantEntity / @AssistantEnum; iOS 26: @AppIntent(schema:) / @AppEntity / @AppEnum).
// The macros (AppIntentsMacros plugin) record the schema's name on the type ("photos.openAsset"); the app's intent
// metadata lists it, and Siri and Shortcuts run the intent as any other. Adapted: isim has no Apple Intelligence that
// would call schema intents by their schema, and the compiler does not check a type against the schema's shape
// (its required parameters and properties), as Apple's build does.
import Foundation

/// a type that conforms to a schema: its name ("mail.sendDraft")
public protocol _IsimSchemaConforming { static var _isimSchemaName: String { get } }

@available(iOS 18.0, *)
@_alwaysEmitConformanceMetadata public protocol AssistantSchemaIntent: AppIntent, _IsimSchemaConforming { static var isAssistantOnly: Bool { get } }
@available(iOS 18.0, *)
@_alwaysEmitConformanceMetadata public protocol AssistantSchemaEntity: AppEntity, _IsimSchemaConforming { static var isAssistantOnly: Bool { get } }
@available(iOS 18.0, *)
@_alwaysEmitConformanceMetadata public protocol AssistantSchemaEnum: AppEnum, _IsimSchemaConforming { static var isAssistantOnly: Bool { get } }
@available(iOS 18.0, *)
extension AssistantSchemaIntent { public static var isAssistantOnly: Bool { false } }
@available(iOS 18.0, *)
extension AssistantSchemaEntity { public static var isAssistantOnly: Bool { false } }
@available(iOS 18.0, *)
extension AssistantSchemaEnum { public static var isAssistantOnly: Bool { false } }
/// iOS 18.0's names for the conforming kinds
@available(iOS 18.0, *)
public protocol AssistantIntent: AssistantSchemaIntent {}
@available(iOS 18.0, *)
public protocol AssistantEntity: AssistantSchemaEntity {}
@available(iOS 18.0, *)
public protocol AssistantEnum: AssistantSchemaEnum {}

/// a schema as a value (`AssistantSchema(.photos.openAsset)`)
@available(iOS 18.0, *)
public struct AssistantSchema: Sendable {
    public struct IntentSchema: Sendable { let name: String }
    public struct EntitySchema: Sendable { let name: String }
    public struct EnumSchema: Sendable { let name: String }
    let name: String
    public init(_ schema: some AssistantSchemas.Intent) { name = schema._isimSchemaName }
    public init(_ schema: some AssistantSchemas.Entity) { name = schema._isimSchemaName }
    public init(_ schema: some AssistantSchemas.Enum) { name = schema._isimSchemaName }
}

@available(iOS 18.0, *)
@attached(extension, conformances: AssistantSchemaIntent, names: named(_isimSchemaName))
public macro AssistantIntent<T: AssistantSchemas.Intent>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "SchemaMacro")
@available(iOS 18.0, *)
@attached(extension, conformances: AssistantSchemaEntity, names: named(_isimSchemaName))
public macro AssistantEntity<T: AssistantSchemas.Entity>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "SchemaMacro")
@available(iOS 18.0, *)
@attached(extension, conformances: AssistantSchemaEnum, names: named(_isimSchemaName))
public macro AssistantEnum<T: AssistantSchemas.Enum>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "SchemaMacro")

@available(iOS 26.0, *)
@attached(extension, conformances: _IsimSchemaConforming, names: named(_isimSchemaName))
public macro AppIntent<T: AppSchemaIntent>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "SchemaMacro")
@available(iOS 26.0, *)
@attached(extension, conformances: _IsimSchemaConforming, names: named(_isimSchemaName))
public macro AppEntity<T: AppSchemaEntity>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "SchemaMacro")
@available(iOS 26.0, *)
@attached(extension, conformances: _IsimSchemaConforming, names: named(_isimSchemaName))
public macro AppEnum<T: AppSchemaEnum>(schema: T) = #externalMacro(module: "AppIntentsMacros", type: "SchemaMacro")
