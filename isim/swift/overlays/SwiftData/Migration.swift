// isim SwiftData: versioned schemas and migration plans. The store records its schema version; opening it with a
// plan runs the plan's stages from that version. Adapted: isim's JSON rows need no rewrite for lightweight changes
// (added properties take their defaults, removed ones are dropped, `originalName` reads a renamed property), so a
// lightweight stage only records the new version; a custom stage gets a context over its old models (willMigrate),
// then over its new ones (didMigrate).
import Foundation

/// A version of an app's schema: its models and version number.
public protocol VersionedSchema {
    static var versionIdentifier: Schema.Version { get }
    static var models: [any PersistentModel.Type] { get }
}

/// The versions of an app's schema, oldest first, and the stages between them.
public protocol SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { get }
    static var stages: [MigrationStage] { get }
}

/// A step from one schema version to the next.
public enum MigrationStage {
    case lightweight(fromVersion: any VersionedSchema.Type, toVersion: any VersionedSchema.Type)
    case custom(fromVersion: any VersionedSchema.Type, toVersion: any VersionedSchema.Type,
                willMigrate: ((ModelContext) throws -> Void)?, didMigrate: ((ModelContext) throws -> Void)?)

    var from: any VersionedSchema.Type {
        switch self { case .lightweight(let f, _), .custom(let f, _, _, _): return f }
    }
    var to: any VersionedSchema.Type {
        switch self { case .lightweight(_, let t), .custom(_, let t, _, _): return t }
    }
}

extension Schema {
    public convenience init(versionedSchema: any VersionedSchema.Type) {
        self.init(versionedSchema.models, version: versionedSchema.versionIdentifier)
    }
}

enum _Migration {
    /// brings the store up to the schema's version with the plan (or just records the version without one)
    static func run(_ store: _SQLStore, schema: Schema, plan: (any SchemaMigrationPlan.Type)?, configuration: ModelConfiguration) throws {
        let current = store.version
        guard let plan else {
            if current == nil || current! < schema.version { store.version = schema.version }
            return
        }
        guard var version = current else { store.version = schema.version; return }
        let known = plan.schemas.map { $0.versionIdentifier }
        if version > schema.version || !known.contains(version) && version > (known.max() ?? schema.version) {
            NSLog("SwiftData: the store's schema %@ is newer than the plan's", version.description)
            throw SwiftDataError.backwardMigration
        }
        while version < schema.version {
            guard let stage = plan.stages.first(where: { $0.from.versionIdentifier == version }) else {
                NSLog("SwiftData: no migration stage from schema %@", version.description)
                throw SwiftDataError.loadIssueModelContainer
            }
            NSLog("SwiftData: migrating the store from schema %@ to %@", version.description, stage.to.versionIdentifier.description)
            if case .custom(let from, let to, let will, let did) = stage {
                if let will { try migrate(store, Schema(versionedSchema: from), configuration, will) }
                store.version = to.versionIdentifier
                if let did { try migrate(store, Schema(versionedSchema: to), configuration, did) }
            }
            store.version = stage.to.versionIdentifier
            version = stage.to.versionIdentifier
        }
    }
    /// runs a stage's closure with a context over one version's models, and saves
    static func migrate(_ store: _SQLStore, _ schema: Schema, _ configuration: ModelConfiguration, _ body: (ModelContext) throws -> Void) throws {
        let container = ModelContainer(migrating: schema, store: store, configuration: configuration)
        let context = ModelContext(container)
        try body(context)
        try context.save()
    }
}
