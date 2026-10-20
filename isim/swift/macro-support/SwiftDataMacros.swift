// Host compiler plugin for isim's SwiftData model macros (self-authored), expanding like Apple's:
// - `@Model` on a class: `@_PersistedProperty` on each stored `var` (not `@Transient`, static, lazy or computed); the
//   backing data (`_$backingData`, `persistentBackingData`), `schemaMetadata` (each property's name, key path, default
//   value and its `@Attribute` / `@Relationship` options), `init(backingData:)`, the observation registrar, and the
//   `PersistentModel` and `Observable` conformances;
// - `@_PersistedProperty`: get / set accessors over the backing data, with observation (and an init accessor for a
//   property's initial value), and the `_name` peer. Unlike Apple's, the init accessor initializes no storage: the
//   compiler gives macro-made init accessors no implicit `= nil`, so optionals would have to be set in every
//   initializer; a property an initializer leaves unset is found when it is read;
// - `#Unique<T>(...)` / `#Index<T>(...)`: the model's uniqueness constraints and indexes as static key paths;
// - `@ModelActor` on an actor: its model executor, container and `init(modelContainer:)`.
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct SwiftDataMessage: Error, CustomStringConvertible { let description: String }

/// A stored property @Model persists: name, type, default value, the @Attribute / @Relationship attribute.
struct PersistedProperty {
    let name: String, type: String?, initializer: String?
    let attribute: AttributeSyntax?, relationship: AttributeSyntax?
}

func attributeName(_ a: AttributeSyntax) -> String {
    let n = a.attributeName.trimmedDescription
    return n.split(separator: ".").last.map(String.init) ?? n
}

/// the persisted property of a member, if it is one
func persistedProperty(_ member: some DeclSyntaxProtocol) -> PersistedProperty? {
    guard let v = member.as(VariableDeclSyntax.self), v.bindingSpecifier.tokenKind == .keyword(.var), v.bindings.count == 1,
          let b = v.bindings.first, let id = b.pattern.as(IdentifierPatternSyntax.self) else { return nil }
    if v.modifiers.contains(where: { ["static", "class", "lazy"].contains($0.name.text) }) { return nil }
    let attrs = v.attributes.compactMap { $0.as(AttributeSyntax.self) }
    if attrs.contains(where: { attributeName($0) == "Transient" }) { return nil }
    if let accessors = b.accessorBlock {
        // a computed property (`{ expr }`, `get`) is not stored; observers (willSet / didSet) are
        guard case .accessors(let list) = accessors.accessors,
              list.allSatisfy({ ["willSet", "didSet"].contains($0.accessorSpecifier.text) }) else { return nil }
    }
    let name = id.identifier.text
    if name.hasPrefix("_$") { return nil }
    return PersistedProperty(name: name, type: b.typeAnnotation?.type.trimmedDescription, initializer: b.initializer?.value.trimmedDescription,
                             attribute: attrs.first { attributeName($0) == "Attribute" }, relationship: attrs.first { attributeName($0) == "Relationship" })
}

public struct ModelMacro: MemberMacro, MemberAttributeMacro, ExtensionMacro {
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax,
                                 providingAttributesFor member: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AttributeSyntax] {
        guard persistedProperty(member) != nil else { return [] }
        return ["@_PersistedProperty"]
    }

    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax,
                                 conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let cls = declaration.as(ClassDeclSyntax.self) else { throw SwiftDataMessage(description: "@Model applies to a class") }
        let type = cls.name.text
        let props = declaration.memberBlock.members.compactMap { persistedProperty($0.decl) }
        let metadata = props.map { p -> String in
            var meta = "nil"
            if let a = p.attribute { meta = "SwiftData.Schema.Attribute(\(a.arguments?.trimmedDescription ?? ""))" }
            if let r = p.relationship { meta = "SwiftData.Schema.Relationship(\(r.arguments?.trimmedDescription ?? ""))" }
            return "SwiftData.Schema.PropertyMetadata(name: \"\(p.name)\", keypath: \\\(type).\(p.name), defaultValue: \(p.initializer ?? "nil"), metadata: \(meta))"
        }
        return [
            "private var _$backingData: any SwiftData.BackingData<\(raw: type)> = \(raw: type).createBackingData()",
            """
            public var persistentBackingData: any SwiftData.BackingData<\(raw: type)> {
                get { _$backingData }
                set { _$backingData = newValue }
            }
            """,
            """
            public static var schemaMetadata: [SwiftData.Schema.PropertyMetadata] {
                [\(raw: metadata.joined(separator: ",\n"))]
            }
            """,
            """
            public required init(backingData: any SwiftData.BackingData<\(raw: type)>) {
                self.persistentBackingData = backingData
            }
            """,
            "private let _$observationRegistrar = Observation.ObservationRegistrar()",
            """
            internal nonisolated func access<_M>(keyPath: KeyPath<\(raw: type), _M>) {
                _$observationRegistrar.access(self, keyPath: keyPath)
            }
            """,
            """
            internal nonisolated func withMutation<_M, _MR>(keyPath: KeyPath<\(raw: type), _M>, _ mutation: () throws -> _MR) rethrows -> _MR {
                try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
            }
            """,
        ]
    }

    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax,
                                 providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax],
                                 in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        [try ExtensionDeclSyntax("extension \(type): SwiftData.PersistentModel {}"),
         try ExtensionDeclSyntax("extension \(type): Observation.Observable {}")]
    }
}

/// A stored property of a @Model class, kept in its backing data.
public struct PersistedPropertyMacro: AccessorMacro, PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        guard let p = persistedProperty(declaration) else { return [] }
        let n = p.name
        var root = ""
        for decl in context.lexicalContext { if let c = decl.as(ClassDeclSyntax.self) { root = c.name.text; break } }
        let accessors: [AccessorDeclSyntax?] = [
            // an initial value (`var tags: [String] = []`) goes through the init accessor into the backing data
            p.initializer == nil ? nil : """
            @storageRestrictions(accesses: _$backingData)
            init(initialValue) {
                _$backingData.setValue(forKey: \\.\(raw: n), to: initialValue)
            }
            """,
            """
            get {
                _$observationRegistrar.access(self, keyPath: \\\(raw: root).\(raw: n))
                return self.getValue(forKey: \\\(raw: root).\(raw: n))
            }
            """,
            """
            set {
                _$observationRegistrar.withMutation(of: self, keyPath: \\\(raw: root).\(raw: n)) {
                    self.setValue(forKey: \\\(raw: root).\(raw: n), to: newValue)
                }
            }
            """,
        ]
        return accessors.compactMap { $0 }
    }
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let p = persistedProperty(declaration) else { return [] }
        return ["private var _\(raw: p.name): SwiftData._SwiftDataNoType = SwiftData._SwiftDataNoType()"]
    }
}

public struct NoOpPropertyMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}

/// `#Unique<T>([\.a, \.b], [\.c])` / `#Index<T>(...)`: static key paths the model's schema reads
func keyPathLists(_ node: some FreestandingMacroExpansionSyntax, _ context: some MacroExpansionContext, member: String, macro: String) throws -> [DeclSyntax] {
    var type = node.genericArgumentClause?.arguments.first?.argument.trimmedDescription
    if type == nil {
        for decl in context.lexicalContext { if let c = decl.as(ClassDeclSyntax.self) { type = c.name.text; break } }
    }
    guard let type else { throw SwiftDataMessage(description: "#\(macro) goes in a @Model class (or names it: #\(macro)<Model>(...))") }
    let lists = node.arguments.map { $0.expression.trimmedDescription }.joined(separator: ", ")
    return ["""
        public static var \(raw: member): [[AnyKeyPath]] {
            let lists: [[PartialKeyPath<\(raw: type)>]] = [\(raw: lists)]
            return lists.map { $0.map { $0 as AnyKeyPath } }
        }
        """]
}
public struct UniqueMacro: DeclarationMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        try keyPathLists(node, context, member: "_isimUniquenessConstraints", macro: "Unique")
    }
}
public struct IndexMacro: DeclarationMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        try keyPathLists(node, context, member: "_isimIndexes", macro: "Index")
    }
}

/// `@ModelActor` on an actor: the model executor (a DefaultSerialModelExecutor over a new context of the container),
/// the container, `init(modelContainer:)` and the ModelActor conformance.
public struct ModelActorMacro: MemberMacro, ExtensionMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax,
                                 conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard declaration.is(ActorDeclSyntax.self) else { throw SwiftDataMessage(description: "@ModelActor applies to an actor") }
        return [
            "nonisolated let modelExecutor: any SwiftData.ModelExecutor",
            "nonisolated let modelContainer: SwiftData.ModelContainer",
            """
            init(modelContainer: SwiftData.ModelContainer) {
                let modelContext = SwiftData.ModelContext(modelContainer)
                self.modelExecutor = SwiftData.DefaultSerialModelExecutor(modelContext: modelContext)
                self.modelContainer = modelContainer
            }
            """,
        ]
    }
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax,
                                 providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax],
                                 in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        [try ExtensionDeclSyntax("extension \(type): SwiftData.ModelActor {}")]
    }
}

@main struct SwiftDataMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [ModelMacro.self, PersistedPropertyMacro.self, NoOpPropertyMacro.self, UniqueMacro.self, IndexMacro.self, ModelActorMacro.self]
}
