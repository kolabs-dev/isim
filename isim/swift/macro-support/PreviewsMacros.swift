// isim's PreviewsMacros compiler plugin (self-authored; built for the Swift toolchain's host, loaded from
// out/swift/host/plugins): `#Preview` (SwiftUI views, UIViews, UIViewControllers, WidgetKit widgets and Live Activities) expands into a type conforming to
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
        guard var body else { return [] }        // the compiler reports the missing body argument
        let traitList = traits.map(\.description).joined(separator: ", ")
        // @Previewable declarations (SwiftUI): they become the properties of a view whose body is the rest
        var extra: [DeclSyntax] = []
        if label == "_isimView", let closure = body.as(ClosureExprSyntax.self), let wrapped = previewable(closure, context) {
            extra.append(wrapped.view)
            body = "{ \(raw: wrapped.name)() }"
        }
        return extra + declarations(node, context, name: name,
                                    make: "DeveloperToolsSupport.Preview(\(label): \(name), traits: [\(traitList)], body: \(body))")
    }

    /// The view a #Preview body with `@Previewable` variables becomes: those variables as its properties (without
    /// `@Previewable`), the other statements as its body (nil when the body has none).
    static func previewable(_ closure: ClosureExprSyntax, _ context: some MacroExpansionContext) -> (name: String, view: DeclSyntax)? {
        func isPreviewable(_ v: VariableDeclSyntax) -> Bool {
            v.attributes.contains { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "Previewable" }
        }
        var props: [String] = [], rest: [String] = []
        for item in closure.statements {
            if let v = item.item.as(VariableDeclSyntax.self), isPreviewable(v) {
                let attrs = v.attributes.filter { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription != "Previewable" }
                props.append(v.with(\.attributes, attrs).trimmedDescription)
            } else { rest.append(item.trimmedDescription) }
        }
        guard !props.isEmpty else { return nil }
        let name = context.makeUniqueName("PreviewableView").text
        // a lone `return EXPR` is the body's expression (the view builder takes expressions)
        if rest.count == 1, rest[0].hasPrefix("return ") { rest[0] = String(rest[0].dropFirst(7)) }
        return (name, """
            struct \(raw: name): SwiftUI.View {
                \(raw: props.joined(separator: "\n"))
                @SwiftUI.ViewBuilder var body: some SwiftUI.View {
                    \(raw: rest.joined(separator: "\n"))
                }
            }
            """)
    }

    /// WidgetKit's previews (`#Preview(_:as:widget:timeline:)`, `timelineProvider:`, `using:`, `contentStates:`): every
    /// argument and trailing closure is passed on, labelled, to `Preview(_isimWidget:...)`; the first trailing closure is
    /// `widget:`
    static func expandForwarding(_ node: some FreestandingMacroExpansionSyntax, _ context: some MacroExpansionContext) -> [DeclSyntax] {
        var name: ExprSyntax = "nil"
        var args: [String] = []
        for (i, arg) in node.arguments.enumerated() {
            if let l = arg.label?.text { args.append("\(l): \(arg.expression)") }
            else if i == 0 { name = arg.expression }
        }
        if let c = node.trailingClosure { args.append("widget: \(c)") }
        for c in node.additionalTrailingClosures { args.append("\(c.label.text): \(c.closure)") }
        return declarations(node, context, name: name,
                            make: "DeveloperToolsSupport.Preview(_isimWidget: \(name), \(args.joined(separator: ", ")))")
    }

    static func declarations(_ node: some FreestandingMacroExpansionSyntax, _ context: some MacroExpansionContext,
                             name: ExprSyntax, make: String) -> [DeclSyntax] {
        let type = context.makeUniqueName("Preview")
        let loc = context.location(of: node)
        let file: ExprSyntax = loc.map { ExprSyntax($0.file) } ?? "#fileID"
        let line: ExprSyntax = loc.map { ExprSyntax($0.line) } ?? "#line"
        let column: ExprSyntax = loc.map { ExprSyntax($0.column) } ?? "0"
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
                    \(raw: make)
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

public struct WidgetPreview: DeclarationMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        PreviewExpansion.expandForwarding(node, context)
    }
}

/// `@Previewable`: nothing of its own; the #Preview around it moves the declaration (PreviewExpansion.previewable).
public struct PreviewableMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}

@main
struct PreviewsMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [SwiftUIView.self, UIKitView.self, UIKitViewController.self, WidgetPreview.self, PreviewableMacro.self]
}
