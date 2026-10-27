// Host compiler plugin for isim's StateReporting macros (self-authored):
// - @ReportableMetadata on a struct adds `metadataDictionary` (each stored instance property as a
//   ReportableMetadataValue under its name or its @ReportableMetadataKey("key"); @ReportableMetadataIgnored ones and
//   nil optionals are left out) and the ReportableMetadata conformance.
// - @ReportableMetadataKey / @ReportableMetadataIgnored only mark properties for it: they expand to nothing.
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct StateReportingMessage: Error, CustomStringConvertible { let description: String }

public struct ReportableMetadataMacro: MemberMacro, ExtensionMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax,
                                 conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) || declaration.is(ClassDeclSyntax.self) else {
            throw StateReportingMessage(description: "@ReportableMetadata applies to a struct or a class")
        }
        var lines: [String] = []
        for member in declaration.memberBlock.members {
            guard let v = member.decl.as(VariableDeclSyntax.self),
                  !v.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }) else { continue }
            var key: String? = nil, ignored = false
            for attr in v.attributes {
                guard let a = attr.as(AttributeSyntax.self) else { continue }
                let name = a.attributeName.trimmedDescription
                if name == "ReportableMetadataIgnored" { ignored = true }
                if name == "ReportableMetadataKey", case .argumentList(let args) = a.arguments, let first = args.first {
                    key = first.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
                }
            }
            if ignored { continue }
            for b in v.bindings {
                guard let id = b.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
                if let acc = b.accessorBlock {                         // computed (a getter), not stored
                    if case .getter = acc.accessors { continue }
                    if case .accessors(let list) = acc.accessors,
                       list.contains(where: { $0.accessorSpecifier.tokenKind == .keyword(.get) }) { continue }
                }
                let type = b.typeAnnotation?.type.trimmedDescription ?? ""
                let k = key ?? id
                if type.hasSuffix("?") || type.hasPrefix("Optional<") {
                    lines.append("if let v = self.\(id) { d[\"\(k)\"] = ReportableMetadataValue(v) }")
                } else {
                    lines.append("d[\"\(k)\"] = ReportableMetadataValue(self.\(id))")
                }
            }
        }
        let access = declaration.modifiers.contains { $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.open) } ? "public " : ""
        let body = lines.isEmpty ? "[:]" : (["var d: [String: ReportableMetadataValue] = [:]"] + lines + ["return d"]).joined(separator: "\n")
        return ["\(raw: access)var metadataDictionary: [String: ReportableMetadataValue] {\n\(raw: body)\n}"]
    }
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax, providingExtensionsOf type: some TypeSyntaxProtocol,
                                 conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        if protocols.isEmpty { return [] }                          // already conforms
        return [try ExtensionDeclSyntax("extension \(type.trimmed): StateReporting.ReportableMetadata {}")]
    }
}

public struct ReportableMetadataMarkerMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}

@main
struct StateReportingMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [ReportableMetadataMacro.self, ReportableMetadataMarkerMacro.self]
}
