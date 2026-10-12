// isim's SwiftUIMacros compiler plugin (self-authored; built for the Swift toolchain's host, loaded from
// out/swift/host/plugins):
// - `@Entry var name: Type = default` in an extension of EnvironmentValues, ContainerValues, FocusedValues or
//   Transaction: a private key type (`__Key_name`) with the default value and the get / set accessors through it;
// - `@Animatable` on a struct: `Animatable` conformance with `animatableData` built from its stored `var`s (an
//   `AnimatablePair` chain), leaving out `@AnimatableIgnored` ones.
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct MacroMessage: Error, CustomStringConvertible { let description: String }

/// The extended type around a declaration (EnvironmentValues, ...), by name.
func extendedTypeName(_ context: some MacroExpansionContext) -> String? {
    for decl in context.lexicalContext {
        if let ext = decl.as(ExtensionDeclSyntax.self) {
            let name = ext.extendedType.trimmedDescription
            return name.split(separator: ".").last.map(String.init) ?? name
        }
    }
    return nil
}

/// The single binding of `@Entry var x: T = v`: name, type, default value.
func entryBinding(_ decl: some DeclSyntaxProtocol) throws -> (name: String, type: TypeSyntax?, value: ExprSyntax?) {
    guard let v = decl.as(VariableDeclSyntax.self), let b = v.bindings.first, let id = b.pattern.as(IdentifierPatternSyntax.self) else {
        throw MacroMessage(description: "@Entry applies to a stored `var name: Type = default`")
    }
    return (id.identifier.text, b.typeAnnotation?.type, b.initializer?.value)
}

public struct EntryMacro: AccessorMacro, PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        let (name, _, _) = try entryBinding(declaration)
        return ["get { self[__Key_\(raw: name).self] }", "set { self[__Key_\(raw: name).self] = newValue }"]
    }
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        let (name, type, value) = try entryBinding(declaration)
        let container = extendedTypeName(context) ?? "EnvironmentValues"
        let proto: String
        switch container {
        case "ContainerValues": proto = "SwiftUI.ContainerValueKey"
        case "FocusedValues": proto = "SwiftUI.FocusedValueKey"
        case "Transaction": proto = "SwiftUI.TransactionKey"
        default: proto = "SwiftUI.EnvironmentKey"
        }
        // a FocusedValues entry is declared optional (`var x: T?`); its key's Value is T
        var valueType = type?.trimmedDescription
        if container == "FocusedValues", let t = valueType {
            if t.hasSuffix("?") { valueType = String(t.dropLast()) }
            else if t.hasPrefix("Optional<"), t.hasSuffix(">") { valueType = String(t.dropFirst(9).dropLast()) }
            return ["""
                private struct __Key_\(raw: name): \(raw: proto) {
                    typealias Value = \(raw: valueType ?? "Never")
                }
                """]
        }
        guard let valueType else { throw MacroMessage(description: "@Entry needs a type annotation (var \(name): Type = ...)") }
        let def = value?.trimmedDescription ?? (valueType.hasSuffix("?") || valueType.hasPrefix("Optional<") ? "nil" : nil)
        guard let def else { throw MacroMessage(description: "@Entry needs a default value (var \(name): \(valueType) = ...)") }
        return ["""
            private struct __Key_\(raw: name): \(raw: proto) {
                static var defaultValue: \(raw: valueType) { \(raw: def) }
            }
            """]
    }
}

public struct AnimatableMacro: ExtensionMacro, MemberMacro {
    /// The stored instance `var`s with a type annotation, minus `@AnimatableIgnored` ones.
    static func animatedProperties(_ decl: some DeclGroupSyntax) -> [(String, String)] {
        var out: [(String, String)] = []
        for m in decl.memberBlock.members {
            guard let v = m.decl.as(VariableDeclSyntax.self), v.bindingSpecifier.tokenKind == .keyword(.var) else { continue }
            if v.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }) { continue }
            if v.attributes.contains(where: { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "AnimatableIgnored" }) { continue }
            for b in v.bindings {
                guard b.accessorBlock == nil || b.accessorBlock.map({ a -> Bool in
                    if case .accessors(let list) = a.accessors { return list.contains { $0.accessorSpecifier.tokenKind == .keyword(.willSet) || $0.accessorSpecifier.tokenKind == .keyword(.didSet) } }
                    return false
                }) == true else { continue }                  // computed properties are not animated
                guard let id = b.pattern.as(IdentifierPatternSyntax.self), let t = b.typeAnnotation?.type else { continue }
                out.append((id.identifier.text, t.trimmedDescription))
            }
        }
        return out
    }
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax, providingExtensionsOf type: some TypeSyntaxProtocol,
                                 conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        protocols.isEmpty ? [] : [try ExtensionDeclSyntax("extension \(type.trimmed): SwiftUI.Animatable {}")]
    }
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, conformingTo protocols: [TypeSyntax],
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        let props = animatedProperties(declaration)
        if props.isEmpty {
            return ["var animatableData: SwiftUI.EmptyAnimatableData { get { SwiftUI.EmptyAnimatableData() } set {} }"]
        }
        // a, b, c -> AnimatablePair<A, AnimatablePair<B, C>>
        func type(_ p: ArraySlice<(String, String)>) -> String {
            p.count == 1 ? p.first!.1 : "SwiftUI.AnimatablePair<\(p.first!.1), \(type(p.dropFirst()))>"
        }
        func value(_ p: ArraySlice<(String, String)>) -> String {
            p.count == 1 ? "self.\(p.first!.0)" : "SwiftUI.AnimatablePair(self.\(p.first!.0), \(value(p.dropFirst())))"
        }
        var sets: [String] = []
        for (i, (name, _)) in props.enumerated() {
            let path = String(repeating: ".second", count: i) + (i == props.count - 1 ? "" : ".first")
            sets.append("self.\(name) = newValue\(path)")
        }
        let all = props[...]
        return ["""
            var animatableData: \(raw: type(all)) {
                get { \(raw: value(all)) }
                set { \(raw: sets.joined(separator: "; ")) }
            }
            """]
    }
}

/// `@AnimatableIgnored`: a marker read by `@Animatable`; it expands to nothing.
public struct AnimatableIgnoredMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}

@main
struct SwiftUIMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [EntryMacro.self, AnimatableMacro.self, AnimatableIgnoredMacro.self]
}
