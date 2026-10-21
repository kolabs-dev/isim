// Host compiler plugin for isim's TipKit macros (self-authored):
// - #Rule(Self.$parameter) { $0 == true } and #Rule(Self.event) { $0.donations.count >= 3 } become a Tips.Rule built
//   from the input and the predicate closure (`TipKit.Tips.Rule(_isimInput: …, …)`), which isim evaluates whenever a tip's
//   eligibility is asked for. Apple's expansion turns the closure into a Foundation Predicate; this one keeps it a closure.
// - @Parameter static var isLoggedIn: Bool = false (or @Parameter(.transient)) makes the property read and write the
//   tips datastore through its `$isLoggedIn` peer, a Tips.Parameter with the declared default.
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct TipKitMessage: Error, CustomStringConvertible { let description: String }

public struct RuleMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let input = node.arguments.first?.expression else { throw TipKitMessage(description: "#Rule needs a parameter or an event") }
        let closure = node.trailingClosure?.trimmedDescription
            ?? (node.arguments.count > 1 ? node.arguments.last!.expression.trimmedDescription : nil)
        guard let body = closure else { throw TipKitMessage(description: "#Rule needs a predicate closure") }
        return "TipKit.Tips.Rule(_isimInput: \(raw: input.trimmedDescription), \(raw: body))"
    }
}

public struct ParameterMacro: AccessorMacro, PeerMacro {
    static func binding(_ declaration: some DeclSyntaxProtocol) throws -> (name: String, type: String, initial: String, isStatic: Bool) {
        guard let v = declaration.as(VariableDeclSyntax.self), let b = v.bindings.first,
              let name = b.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            throw TipKitMessage(description: "@Parameter applies to a `static var name: Type = default`")
        }
        let type = b.typeAnnotation?.type.trimmedDescription ?? ""
        let initial = b.initializer?.value.trimmedDescription ?? ""
        if type.isEmpty || initial.isEmpty { throw TipKitMessage(description: "@Parameter needs a type and a default value (`static var \(name): Bool = false`)") }
        let isStatic = v.modifiers.contains { $0.name.tokenKind == .keyword(.static) }
        return (name, type, initial, isStatic)
    }
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        let b = try binding(declaration)
        return ["get { $\(raw: b.name).wrappedValue }", "set { $\(raw: b.name).wrappedValue = newValue }"]
    }
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        let b = try binding(declaration)
        var options = "[]"
        if case .argumentList(let args) = node.arguments, !args.isEmpty {
            options = "[" + args.map(\.expression.trimmedDescription).joined(separator: ", ") + "]"
        }
        let access = (declaration.as(VariableDeclSyntax.self)?.modifiers ?? []).filter {
            [.keyword(.public), .keyword(.internal), .keyword(.fileprivate), .keyword(.private), .keyword(.package)].contains($0.name.tokenKind)
        }.map(\.trimmedDescription).joined(separator: " ")
        let prefix = (access.isEmpty ? "" : access + " ") + (b.isStatic ? "static " : "")
        return ["\(raw: prefix)let $\(raw: b.name): TipKit.Tips.Parameter<\(raw: b.type)> = TipKit.Tips.Parameter(Self.self, \(literal: b.name), \(raw: b.initial), \(raw: options))"]
    }
}

@main
struct TipKitMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [RuleMacro.self, ParameterMacro.self]
}
