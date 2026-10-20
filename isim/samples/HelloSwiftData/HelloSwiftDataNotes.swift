// HelloSwiftData's schema migration (issue #300): notes in their own store (notes.store), version 1 (title, body) and
// version 2 (body renamed text, a word count), migrated by a plan with a custom stage. HELLOSWIFTDATA_NOTES=v1 seeds
// version 1, =v2 opens the store with version 2 (the stage runs), =v1again opens it with version 1 again (refused:
// the store is newer). A model actor adds and renames trips off the main thread.
import Foundation
import SwiftData

enum NotesV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Note.self] }
    @Model final class Note {
        var title: String
        var body: String
        init(title: String, body: String) { self.title = title; self.body = body }
    }
}

enum NotesV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Note.self] }
    @Model final class Note {
        var title: String
        @Attribute(originalName: "body") var text: String
        var words: Int = 0
        init(title: String, text: String) { self.title = title; self.text = text }
    }
}

enum NotesPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [NotesV1.self, NotesV2.self] }
    static var stages: [MigrationStage] {
        [.custom(fromVersion: NotesV1.self, toVersion: NotesV2.self,
                 willMigrate: { context in
                     for n in try context.fetch(FetchDescriptor<NotesV1.Note>()) { n.title = n.title.uppercased() }
                     log("notes: will migrate \(try context.fetchCount(FetchDescriptor<NotesV1.Note>())) notes")
                 },
                 didMigrate: { context in
                     for n in try context.fetch(FetchDescriptor<NotesV2.Note>()) { n.words = n.text.split(separator: " ").count }
                 })]
    }
}

@MainActor func notes(_ phase: String) {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let url = dir.appendingPathComponent("notes.store")
    do {
        switch phase {
        case "v1":
            let c = try ModelContainer(for: Schema(versionedSchema: NotesV1.self), migrationPlan: NotesPlan.self, configurations: [ModelConfiguration(url: url)])
            c.mainContext.insert(NotesV1.Note(title: "groceries", body: "milk eggs bread"))
            c.mainContext.insert(NotesV1.Note(title: "idea", body: "a simulator for linux"))
            try c.mainContext.save()
            log("notes v1: \(try c.mainContext.fetch(FetchDescriptor<NotesV1.Note>()).map { "\($0.title)=\($0.body)" })")
        case "v2":
            let c = try ModelContainer(for: Schema(versionedSchema: NotesV2.self), migrationPlan: NotesPlan.self, configurations: [ModelConfiguration(url: url)])
            log("notes v2: \(try c.mainContext.fetch(FetchDescriptor<NotesV2.Note>(sortBy: [SortDescriptor(\.title)])).map { "\($0.title) words=\($0.words) text=\($0.text)" })")
        default:
            _ = try ModelContainer(for: Schema(versionedSchema: NotesV1.self), migrationPlan: NotesPlan.self, configurations: [ModelConfiguration(url: url)])
            log("notes \(phase): opened?!")
        }
    } catch { log("notes \(phase): \(error)") }
}

@ModelActor actor Importer {
    func addTrip(_ name: String, days: Double) throws -> String {
        let t = Trip(name: name, start: epoch + days * day, kind: .work, budget: Budget(amount: 100, currency: "EUR"))
        modelContext.insert(t)
        try modelContext.save()
        return "\(Thread.isMainThread ? "main" : "background") \(t.persistentModelID.isTemporary ? "temporary" : "stored")"
    }
    func rename(_ id: PersistentIdentifier, to name: String) throws -> Bool {
        guard let t = self[id, as: Trip.self] else { return false }
        t.name = name
        try modelContext.save()
        return true
    }
}
