import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `#stringify(x)` -> `(x, "x")` (the Xcode macro template's example).
public struct StringifyMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax,
                                 in context: some MacroExpansionContext) -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else { fatalError("#stringify needs an argument") }
        return "(\(argument), \(literal: argument.description))"
    }
}

/// `@CaseCount` on an enum adds `static let caseCount` (attached member macro); anything else is a compile error.
public struct CaseCountMacro: MemberMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax,
                                 conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let e = declaration.as(EnumDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: MacroExpansionErrorMessage("@CaseCount only applies to enums")))
            return []
        }
        let count = e.memberBlock.members.compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }.reduce(0) { $0 + $1.elements.count }
        return ["static let caseCount = \(literal: count)"]
    }
}

@main
struct CoreMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [StringifyMacro.self, CaseCountMacro.self]
}
