// HelloSwiftData's history, custom store and observers (issue #399), run when HELLOSWIFTDATA_HISTORY is set:
// - history (iOS 18): chores saved by two authors in history.store, the transactions since a token (inserts, updates
//   with their changed attributes, deletes with the tombstone of a .preserveValueOnDeletion attribute), the token in
//   didSave's user info, and deleteHistory;
// - a custom data store (iOS 18): Apple's JSON-file store sample (a DataStore of DefaultSnapshots in people.json),
//   with UUID identifiers it assigns on save, a relationship, an in-memory predicate and sort, updates and deletes;
// - observers (iOS 27): a ResultsObserver with sections that follows inserts and a filter change, a HistoryObserver
//   that counts saves.
import Foundation
import Observation
import SwiftData

@Model final class Chore {
    var title: String
    @Attribute(.preserveValueOnDeletion) var code: String
    var room: String = "home"
    var done = false
    init(title: String, code: String, room: String = "home") { self.title = title; self.code = code; self.room = room }
}

@Model final class Person {
    var name: String
    var city: String?
    @Relationship(deleteRule: .cascade, inverse: \Pet.owner) var pets: [Pet] = []
    init(name: String, city: String?) { self.name = name; self.city = city }
}

@Model final class Pet {
    var name: String
    var owner: Person?
    init(name: String) { self.name = name }
}

/// a flag set from an observation callback
final class Flag: @unchecked Sendable { var on = false }

let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

@MainActor func historyDemo() {
    let url = support.appendingPathComponent("history.store")
    for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
    let container = try! ModelContainer(for: Schema([Chore.self]), configurations: [ModelConfiguration(url: url)])
    let c = ModelContext(container)
    c.author = "app"
    let water = Chore(title: "Water plants", code: "W1"), rent = Chore(title: "Pay rent", code: "R1")
    c.insert(water); c.insert(rent)
    var announced = false
    let o = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: c, queue: nil) { n in
        announced = (n.userInfo?[ModelContext.NotificationKey.historyTokens.rawValue] as? [String: Any])?.values.first is DefaultHistoryToken
    }
    try! c.save()
    NotificationCenter.default.removeObserver(o)
    let first = try! c.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
    log("history first: transactions=\(first.count) changes=\(first.last?.changes.count ?? 0) author=\(first.last?.author ?? "-") " +
        "bundle=\(first.last?.bundleIdentifier.isEmpty == false) process=\(first.last?.processIdentifier == String(ProcessInfo.processInfo.processIdentifier)) didSave token=\(announced)")
    let token = first.last!.token

    water.done = true
    try! c.save()
    c.delete(rent)
    try! c.save()
    let widget = ModelContext(container)
    widget.author = "widget"
    widget.insert(Chore(title: "Buy milk", code: "M1"))
    try! widget.save()

    let names: [PartialKeyPath<Chore>: String] = [\Chore.title: "title", \Chore.code: "code", \Chore.room: "room", \Chore.done: "done"]
    func describe(_ change: HistoryChange) -> String {
        switch change {
        case .insert(let i): return "insert \(i.changedPersistentIdentifier.entityName)"
        case .update(let u): return "update " + ((u as? DefaultHistoryUpdate<Chore>)?.updatedAttributes.compactMap { names[$0] }.sorted().joined(separator: "+") ?? "?")
        case .delete(let d): return "delete code=\((d as? DefaultHistoryDelete<Chore>)?.tombstone[\Chore.code] as? String ?? "-") title=\((d as? DefaultHistoryDelete<Chore>)?.tombstone[\Chore.title] as? String ?? "-")"
        @unknown default: return "?"
        }
    }
    let since = try! c.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token > token }))
    log("history since: " + since.map { t in "\(t.author ?? "-"):" + t.changes.map(describe).joined(separator: ",") }.joined(separator: " "))
    let byWidget = try! c.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.author == "widget" }))
    var newest = HistoryDescriptor<DefaultHistoryTransaction>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
    newest.fetchLimit = 1
    log("history widget: \(byWidget.count) newest=\(try! c.fetchHistory(newest).first?.author ?? "-")")
    try! c.deleteHistory(HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token <= token }))
    log("history after delete: \(try! c.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).count)")
}

// MARK: - a custom data store: Apple's JSON store sample

struct JSONStoreConfiguration: DataStoreConfiguration {
    typealias Store = JSONStore
    var name: String
    var schema: Schema?
    var fileURL: URL
    init(name: String, schema: Schema? = nil, fileURL: URL) { self.name = name; self.schema = schema; self.fileURL = fileURL }
    static func == (lhs: JSONStoreConfiguration, rhs: JSONStoreConfiguration) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

final class JSONStore: DataStore {
    typealias Configuration = JSONStoreConfiguration
    typealias Snapshot = DefaultSnapshot
    var configuration: JSONStoreConfiguration
    var name: String
    var schema: Schema
    var identifier: String
    init(_ configuration: JSONStoreConfiguration, migrationPlan: (any SchemaMigrationPlan.Type)?) throws {
        self.configuration = configuration
        name = configuration.name
        schema = configuration.schema!
        identifier = configuration.fileURL.lastPathComponent
    }
    func fetch<T>(_ request: DataStoreFetchRequest<T>) throws -> DataStoreFetchResult<T, DefaultSnapshot> where T: PersistentModel {
        if request.descriptor.predicate != nil { throw DataStoreError.preferInMemoryFilter }
        if !request.descriptor.sortBy.isEmpty { throw DataStoreError.preferInMemorySort }
        let objects = try read()
        return DataStoreFetchResult(descriptor: request.descriptor, fetchedSnapshots: Array(objects.values), relatedSnapshots: objects)
    }
    func save(_ request: DataStoreSaveChangesRequest<DefaultSnapshot>) throws -> DataStoreSaveChangesResult<DefaultSnapshot> {
        var remapped: [PersistentIdentifier: PersistentIdentifier] = [:]
        var objects = try read()
        for snapshot in request.inserted {
            let permanent = try PersistentIdentifier.identifier(for: identifier, entityName: snapshot.persistentIdentifier.entityName, primaryKey: UUID())
            objects[permanent] = snapshot.copy(persistentIdentifier: permanent)
            remapped[snapshot.persistentIdentifier] = permanent
        }
        // references to models inserted in the same save get their permanent identifiers too
        for (id, snapshot) in objects { objects[id] = snapshot.copy(persistentIdentifier: id, remappedIdentifiers: remapped) }
        for snapshot in request.updated { objects[snapshot.persistentIdentifier] = snapshot.copy(persistentIdentifier: snapshot.persistentIdentifier, remappedIdentifiers: remapped) }
        for snapshot in request.deleted { objects[snapshot.persistentIdentifier] = nil }
        try write(objects)
        return DataStoreSaveChangesResult<DefaultSnapshot>(for: identifier, remappedIdentifiers: remapped, snapshotsToReregister: [:])
    }
    func read() throws -> [PersistentIdentifier: DefaultSnapshot] {
        guard FileManager.default.fileExists(atPath: configuration.fileURL.path) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let list = try decoder.decode([DefaultSnapshot].self, from: Data(contentsOf: configuration.fileURL))
        return Dictionary(list.map { ($0.persistentIdentifier, $0) }, uniquingKeysWith: { a, _ in a })
    }
    func write(_ objects: [PersistentIdentifier: DefaultSnapshot]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Array(objects.values)).write(to: configuration.fileURL)
    }
}

@MainActor func customStoreDemo() {
    let url = support.appendingPathComponent("people.json")
    try? FileManager.default.removeItem(at: url)
    try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
    let schema = Schema([Person.self, Pet.self])
    func open() -> ModelContext { ModelContext(try! ModelContainer(for: schema, configurations: [JSONStoreConfiguration(name: "people", schema: schema, fileURL: url)])) }
    let c = open()
    let ana = Person(name: "Ana", city: "Lisbon"), bo = Person(name: "Bo", city: "Oslo"), cy = Person(name: "Cy", city: "Lisbon")
    c.insert(ana); c.insert(bo); c.insert(cy)
    ana.pets.append(Pet(name: "Rex"))
    log("custom before save: temporary=\(ana.persistentModelID.isTemporary)")
    try! c.save()
    log("custom saved: temporary=\(ana.persistentModelID.isTemporary) store=\(ana.persistentModelID.storeIdentifier ?? "-") " +
        "file=\((try? String(contentsOf: url, encoding: .utf8))?.contains("Rex") ?? false)")

    // a new container reads the file back; predicates and sorts run in memory (the store asked for that)
    let again = open()
    let lisbon = try! again.fetch(FetchDescriptor<Person>(predicate: #Predicate { $0.city == "Lisbon" }, sortBy: [SortDescriptor(\.name, order: .reverse)]))
    log("custom fetch: \(lisbon.map { "\($0.name) pets=\($0.pets.map(\.name))" }) count=\(try! again.fetchCount(FetchDescriptor<Person>()))")
    let back = again.model(for: ana.persistentModelID) as? Person
    log("custom identity: \(back?.name ?? "-") rex.owner=\(back?.pets.first?.owner?.name ?? "-")")
    lisbon.first { $0.name == "Ana" }?.city = "Porto"
    again.delete(lisbon.first { $0.name == "Cy" }!)
    try! again.save()

    let third = open()
    let people = try! third.fetch(FetchDescriptor<Person>(sortBy: [SortDescriptor(\.name)]))
    log("custom after save: \(people.map { "\($0.name)@\($0.city ?? "-")" }) pets=\(try! third.fetchCount(FetchDescriptor<Pet>()))")
}

// MARK: - observers (iOS 27)

@available(iOS 27.0, *)
@MainActor func observersDemo() {
    let container = try! ModelContainer(for: Schema([Chore.self]), configurations: [ModelConfiguration("observed", isStoredInMemoryOnly: true)])
    let c = container.mainContext
    c.insert(Chore(title: "Wash up", code: "K1", room: "kitchen"))
    c.insert(Chore(title: "Vacuum", code: "L1", room: "living"))
    try! c.save()
    let results = try! ResultsObserver(fetchDescriptor: FetchDescriptor<Chore>(sortBy: [SortDescriptor(\.title)]), sectionBy: \Chore.room, modelContext: c)
    let changed = Flag()
    withObservationTracking { _ = results.results.count } onChange: { changed.on = true }
    let dust = Chore(title: "Dust", code: "L2", room: "living")
    c.insert(dust)
    let at = results.element(at: IndexPath(indexes: [0, 1]))?.title ?? "-"
    let path = results.indexPath(for: dust).map { "\($0[0]).\($0[1])" } ?? "-"
    log("observer: changed=\(changed.on) results=\(results.results.map(\.title)) sections=\(results.sections?.sectionTitles ?? []) " +
        "living=\(results.sections?[sectionTitle: "living"]?.map(\.title) ?? []) at0.1=\(at) dust=\(path)")
    results.filterBy = #Predicate { $0.room == "kitchen" }
    log("observer filtered: \(results.results.map(\.title)) sections=\(results.sections?.count ?? 0)")

    let history = try! HistoryObserver(historyTokens: nil, observedModels: [Chore.self], authors: [], modelContainer: container)
    let counted = Flag()
    withObservationTracking { _ = history.eventCounter } onChange: { counted.on = true }
    try! c.save()
    let other = ModelContext(container)
    other.insert(Chore(title: "Mop", code: "K2", room: "kitchen"))
    try! other.save()
    log("history observer: events=\(history.eventCounter) tracked=\(counted.on)")
}
