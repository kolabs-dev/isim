// isim's PreviewsMacros compiler plugin (self-authored; built for the Swift toolchain's host, loaded from
// out/swift/host/plugins): `#Preview` (SwiftUI views, UIViews, UIViewControllers) expands into a type conforming to
// DeveloperToolsSupport.PreviewRegistry whose makePreview() builds a Preview with the name, traits and body closure, so
// the body is type-checked like in Xcode, and an exported entry point for `isim preview` (it renders the preview).
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
        // `isim preview` finds previews by an exported entry point named after where the preview is and its name
        // ("isim_preview_" + the hex of "file|line|name"); the entry builds a view controller showing the preview
        func literal(_ e: ExprSyntax) -> String? {
            guard let s = e.as(StringLiteralExprSyntax.self), s.segments.count == 1, let seg = s.segments.first?.as(StringSegmentSyntax.self) else { return nil }
            return seg.content.text
        }
        let fileText = loc.flatMap { literal(ExprSyntax($0.file)) } ?? "?"
        let lineText = loc.map { $0.line.description } ?? "0"
        let key = "\(fileText)|\(lineText)|\(literal(name) ?? "")"
        let symbol = "isim_preview_" + key.utf8.map { b in let h = String(b, radix: 16); return b < 16 ? "0" + h : h }.joined()
        let entry = context.makeUniqueName("isimPreviewEntry")
        return ["""
            struct \(type): DeveloperToolsSupport.PreviewRegistry {
                static let fileID: String = \(file)
                static let line: Int = \(line)
                static let column: Int = \(column)
                @MainActor static func makePreview() throws -> DeveloperToolsSupport.Preview {
                    DeveloperToolsSupport.Preview(\(raw: label): \(name), traits: [\(raw: traitList)], body: \(body))
                }
            }
            """, """
            @_cdecl("\(raw: symbol)") public func \(entry)() -> UnsafeMutableRawPointer? {
                UnsafeMutableRawPointer(bitPattern: MainActor.assumeIsolated { _isimPreviewEntry(\(type).self) })
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
