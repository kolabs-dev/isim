// Host compiler plugin for isim's App Intents schema macros (self-authored): @AssistantIntent(schema:),
// @AssistantEntity(schema:), @AssistantEnum(schema:) and iOS 26's @AppIntent(schema:), @AppEntity(schema:),
// @AppEnum(schema:) add the conformance their declaration names (AssistantSchemaIntent, …) and the schema's name as a
// static `_isimSchemaName` ("photos.openAsset", from the argument `.photos.openAsset`), which the app's intent metadata
// lists. Apple's expansion also checks the type against the schema's shape; this one does not.
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct AppIntentsMessage: Error, CustomStringConvertible { let description: String }

public struct SchemaMacro: ExtensionMacro {
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax,
                                 providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax],
                                 in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        guard case .argumentList(let args) = node.arguments, let schema = args.first(where: { $0.label?.text == "schema" }) else {
            throw AppIntentsMessage(description: "@\(node.attributeName.trimmedDescription) needs schema:")
        }
        var name = schema.expression.trimmedDescription
        for prefix in ["AssistantSchemas.Intent.", "AssistantSchemas.Entity.", "AssistantSchemas.Enum.", "AppSchemaIntent.", "AppSchemaEntity.", "AppSchemaEnum."]
        where name.hasPrefix(prefix) { name = String(name.dropFirst(prefix.count)) }
        if name.hasPrefix(".") { name.removeFirst() }
        let conformance = protocols.map(\.trimmedDescription).joined(separator: ", ")
        let header = conformance.isEmpty ? "extension \(type.trimmedDescription)" : "extension \(type.trimmedDescription): \(conformance)"
        let decl: DeclSyntax = """
            \(raw: header) {
                public static var _isimSchemaName: String { \(literal: name) }
            }
            """
        guard let ext = decl.as(ExtensionDeclSyntax.self) else { return [] }
        return [ext]
    }
}

@main
struct AppIntentsMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [SchemaMacro.self]
}
