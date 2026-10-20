// isim's FoundationModelsMacros compiler plugin (self-authored; built for the Swift toolchain's host, loaded from
// out/swift/host/plugins):
// - `@Generable(description:)` on a struct: `generationSchema` (its stored properties, with the descriptions and guides
//   of their `@Guide` attributes), `init(_: GeneratedContent)`, `generatedContent` and a `PartiallyGenerated` struct
//   (every property optional); on an enum without associated values: a choice of its case names;
// - `@Guide(...)`: read by `@Generable`, expands to nothing.
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct GenerableMessage: Error, CustomStringConvertible { let description: String }

/// `description:` of an attribute, as written
func descriptionArgument(_ node: AttributeSyntax) -> String? {
    guard case .argumentList(let args) = node.arguments else { return nil }
    return args.first { $0.label?.text == "description" }?.expression.trimmedDescription
}

struct GenerableProperty {
    let name: String, type: String, description: String?, guides: [String], regex: Bool
}

/// the stored properties of a struct, with their @Guide attributes
func generableProperties(_ decl: some DeclGroupSyntax) -> [GenerableProperty] {
    var out: [GenerableProperty] = []
    for m in decl.memberBlock.members {
        guard let v = m.decl.as(VariableDeclSyntax.self),
              !v.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }) else { continue }
        var desc: String? = nil, guides: [String] = [], regex = false
        for a in v.attributes {
            guard let attr = a.as(AttributeSyntax.self), attr.attributeName.trimmedDescription.hasSuffix("Guide") else { continue }
            desc = descriptionArgument(attr)
            if case .argumentList(let args) = attr.arguments {
                for arg in args where arg.label == nil {
                    let e = arg.expression
                    if e.is(RegexLiteralExprSyntax.self) || e.trimmedDescription.hasPrefix("Regex") || e.trimmedDescription.hasPrefix("#/") {
                        regex = true; guides.append(e.trimmedDescription)
                    } else {
                        guides.append(e.trimmedDescription)
                    }
                }
            }
        }
        for b in v.bindings {
            /* stored only: no accessors other than observers */
            if let acc = b.accessorBlock {
                if case .getter = acc.accessors { continue }
                if case .accessors(let list) = acc.accessors, list.contains(where: { ["get", "set", "_read", "_modify"].contains($0.accessorSpecifier.text) }) { continue }
            }
            guard let id = b.pattern.as(IdentifierPatternSyntax.self), let t = b.typeAnnotation?.type else { continue }
            out.append(GenerableProperty(name: id.identifier.text, type: t.trimmedDescription, description: desc, guides: guides, regex: regex))
        }
    }
    return out
}

/// `T?` -> T, `Optional<T>` -> T; `[T]` -> Array<T> (so `.PartiallyGenerated` can follow it)
func strippedOptional(_ t: String) -> (String, Bool) {
    if t.hasSuffix("?") { return (String(t.dropLast()), true) }
    if t.hasPrefix("Optional<") && t.hasSuffix(">") { return (String(t.dropFirst(9).dropLast()), true) }
    return (t, false)
}
func memberAccessible(_ t: String) -> String {
    if t.hasPrefix("[") && t.hasSuffix("]") {
        let inner = String(t.dropFirst().dropLast())
        var depth = 0, colon = false
        for c in inner { if "[<(".contains(c) { depth += 1 } else if "]>)".contains(c) { depth -= 1 } else if c == ":" && depth == 0 { colon = true } }
        return colon ? "Dictionary<\(String(inner.map { $0 == ":" ? "," : $0 }))>" : "Array<\(memberAccessible(inner))>"
    }
    return t
}
func quoted(_ s: String) -> String {
    var out = "\""
    for c in s { if c == "\\" || c == "\"" { out.append("\\") }; out.append(c) }
    return out + "\""
}

/// the members of a Generable type: its schema and PartiallyGenerated in the type, `init(_:)` and `generatedContent` in
/// the extension (so a struct keeps its memberwise initializer)
func generableParts(_ node: AttributeSyntax, _ declaration: some DeclGroupSyntax) throws -> (members: [DeclSyntax], extensionMembers: [String]) {
    let desc = descriptionArgument(node) ?? "nil"
    if let e = declaration.as(EnumDeclSyntax.self) {
        var cases: [String] = []
        for m in e.memberBlock.members {
            guard let c = m.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for el in c.elements {
                if el.parameterClause != nil {
                    throw GenerableMessage(description: "@Generable on isim supports enums whose cases have no associated values (\(el.name.text) has some)")
                }
                cases.append(el.name.text)
            }
        }
        let list = cases.map(quoted).joined(separator: ", ")
        let decode = cases.map { "case \(quoted($0)): self = .\($0)" }.joined(separator: "\n")
        let encode = cases.map { "case .\($0): return FoundationModels.GeneratedContent(\(quoted($0)))" }.joined(separator: "\n")
        return (["nonisolated static var generationSchema: FoundationModels.GenerationSchema { FoundationModels.GenerationSchema(type: Self.self, description: \(raw: desc), anyOf: [\(raw: list)]) }"], [
            """
            nonisolated init(_ content: FoundationModels.GeneratedContent) throws {
                switch try content.value(String.self) {
                \(decode)
                default: throw FoundationModels.LanguageModelSession.GenerationError.decodingFailure(.init(debugDescription: "\\(content.jsonString) is not a case of \\(Self.self)"))
                }
            }
            """,
            """
            nonisolated var generatedContent: FoundationModels.GeneratedContent {
                switch self {
                \(encode)
                }
            }
            """,
        ])
    }
    guard declaration.is(StructDeclSyntax.self) else {
        throw GenerableMessage(description: "@Generable applies to a struct or an enum")
    }
    let props = generableProperties(declaration)
    let schemaProps = props.map { p -> String in
        let d = p.description.map { ", description: \($0)" } ?? ""
        if p.regex { return "FoundationModels.GenerationSchema.Property(name: \(quoted(p.name))\(d), type: String.self, guides: [\(p.guides.joined(separator: ", "))])" }
        let g = p.guides.isEmpty ? "" : ", guides: [\(p.guides.joined(separator: ", "))]"
        return "FoundationModels.GenerationSchema.Property(name: \(quoted(p.name))\(d), type: (\(p.type)).self\(g))"
    }.joined(separator: ",\n")
    let decode = props.map { "self.\($0.name) = try content.value((\($0.type)).self, forProperty: \(quoted($0.name)))" }.joined(separator: "\n")
    let encode = props.isEmpty ? "[:]" : "[" + props.map { "\(quoted($0.name)): self.\($0.name)" }.joined(separator: ", ") + "]"
    let partialProps = props.map { p -> String in
        let (base, _) = strippedOptional(p.type)
        return "var \(p.name): \(memberAccessible(base)).PartiallyGenerated?"
    }.joined(separator: "\n")
    let partialDecode = props.map { p -> String in
        let (base, _) = strippedOptional(p.type)
        return "self.\(p.name) = try content.value(Optional<\(memberAccessible(base)).PartiallyGenerated>.self, forProperty: \(quoted(p.name)))"
    }.joined(separator: "\n")
    return ([
        """
        nonisolated static var generationSchema: FoundationModels.GenerationSchema {
            FoundationModels.GenerationSchema(type: Self.self, description: \(raw: desc), properties: [
                \(raw: schemaProps)
            ])
        }
        """,
        """
        nonisolated struct PartiallyGenerated: Identifiable, FoundationModels.ConvertibleFromGeneratedContent {
            var id: FoundationModels.GenerationID
            \(raw: partialProps)
            nonisolated init(_ content: FoundationModels.GeneratedContent) throws {
                self.id = content.id ?? FoundationModels.GenerationID()
                \(raw: partialDecode)
            }
        }
        """,
    ], [
        """
        nonisolated init(_ content: FoundationModels.GeneratedContent) throws {
            \(decode)
        }
        """,
        """
        nonisolated var generatedContent: FoundationModels.GeneratedContent {
            FoundationModels.GeneratedContent(properties: \(encode))
        }
        """,
    ])
}

public struct GenerableMacro: MemberMacro, ExtensionMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax,
                                 conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        try generableParts(node, declaration).members
    }
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax,
                                 providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax],
                                 in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        let body = try generableParts(node, declaration).extensionMembers.joined(separator: "\n")
        return [try ExtensionDeclSyntax("extension \(type.trimmed): FoundationModels.Generable {\n\(raw: body)\n}")]
    }
}
public struct GuideMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}

@main struct FoundationModelsMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [GenerableMacro.self, GuideMacro.self]
}
