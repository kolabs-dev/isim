// isim's PreviewsMacros compiler plugin (self-authored; built for the Swift toolchain's host, loaded from
// out/swift/host/plugins): `#Preview` (SwiftUI views, UIViews, UIViewControllers) expands into a type conforming to
// DeveloperToolsSupport.PreviewRegistry whose makePreview() builds a Preview with the name, traits and body closure, so
// the body is type-checked like in Xcode. There is no preview canvas on isim.
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum PreviewExpansion {
    static func expand(_ node: some FreestandingMacroExpansionSyntax, _ context: some MacroExpansionContext,
                       label: String) -> [DeclSyntax] {
        var name: ExprSyntax = "nil"
        var traits: [ExprSyntax] = []
        var body: ExprSyntax? = node.trailingClosure.map { ExprSyntax($0) }
        var inTraits = false
        for (i, arg) in node.arguments.enumerated() {
            switch arg.label?.text {
            case nil where i == 0 && !inTraits: name = arg.expression
            case nil where inTraits: traits.append(arg.expression)
            case "traits": inTraits = true; traits.append(arg.expression)
            case "body": body = arg.expression; inTraits = false
            default: inTraits = false
            }
        }
        guard let body else { return [] }        // the compiler reports the missing body argument
        let type = context.makeUniqueName("Preview")
        let loc = context.location(of: node)
        let file: ExprSyntax = loc.map { ExprSyntax($0.file) } ?? "#fileID"
        let line: ExprSyntax = loc.map { ExprSyntax($0.line) } ?? "#line"
        let column: ExprSyntax = loc.map { ExprSyntax($0.column) } ?? "0"
        let traitList = traits.map(\.description).joined(separator: ", ")
        return ["""
            struct \(type): DeveloperToolsSupport.PreviewRegistry {
                static let fileID: String = \(file)
                static let line: Int = \(line)
                static let column: Int = \(column)
                @MainActor static func makePreview() throws -> DeveloperToolsSupport.Preview {
                    DeveloperToolsSupport.Preview(\(raw: label): \(name), traits: [\(raw: traitList)], body: \(body))
                }
            }
            """]
    }
}

public struct SwiftUIView: DeclarationMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        PreviewExpansion.expand(node, context, label: "_isimView")
    }
}
public struct UIKitView: DeclarationMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        PreviewExpansion.expand(node, context, label: "_isimUIView")
    }
}
public struct UIKitViewController: DeclarationMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        PreviewExpansion.expand(node, context, label: "_isimViewController")
    }
}

@main
struct PreviewsMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [SwiftUIView.self, UIKitView.self, UIKitViewController.self]
}
