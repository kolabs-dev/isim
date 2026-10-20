// Core Data self-test, issue #301: persistent history kept in the store's file (it survives reopening the store and
// filters by the request's fetch request), the migration pipeline (an NSEntityMigrationPolicy subclass, relationships
// re-created between destination instances, migrating in place) and staged migration (a custom stage's handlers on the
// old and new models, then a lightweight stage).
import Foundation
import CoreData

func historyAcrossReopenTests() {
    let url = storeDir.appendingPathComponent("History2.sqlite")
    func open() -> NSPersistentContainer {
        let c = NSPersistentContainer(name: "TestModel")
        let d = NSPersistentStoreDescription(url: url)
        d.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        c.persistentStoreDescriptions = [d]
        c.loadPersistentStores { _, error in if let error { check(false, "history store: \(error)") } }
        return c
    }
    func history(_ c: NSPersistentContainer, after token: NSPersistentHistoryToken? = nil, _ configure: (NSPersistentHistoryChangeRequest) -> Void = { _ in }) -> [NSPersistentHistoryTransaction] {
        let r = NSPersistentHistoryChangeRequest.fetchHistory(after: token)
        configure(r)
        return ((try? c.viewContext.execute(r)) as? NSPersistentHistoryResult)?.result as? [NSPersistentHistoryTransaction] ?? []
    }
    var c = open()
    c.viewContext.transactionAuthor = "app"
    let a = Author(context: c.viewContext); a.name = "Kept"
    try? c.viewContext.save()
    a.name = "Kept 2"; try? c.viewContext.save()
    let other = c.newBackgroundContext()
    other.transactionAuthor = "widget"
    other.performAndWait { let b = Author(context: other); b.name = "Widget"; try? other.save() }
    for s in c.persistentStoreCoordinator.persistentStores { try? c.persistentStoreCoordinator.remove(s) }

    c = open()       // another coordinator: the history is in the file
    let all = history(c)
    check(all.count == 3 && all.map { $0.author ?? "-" } == ["app", "app", "widget"], "persistent history survives reopening the store")
    let update = all.count > 1 ? all[1].changes?.first : nil
    check(update?.changeType == .update && update?.updatedProperties?.map(\.name) == ["name"], "history changes name their updated properties")
    check(all.first?.bundleID == Bundle.main.bundleIdentifier && !(all.first?.processID ?? "").isEmpty, "history transactions record the bundle and process")
    let byAuthor = history(c) { r in
        let f = NSFetchRequest<NSFetchRequestResult>(); f.predicate = NSPredicate(format: "author == %@", "widget"); r.fetchRequest = f
    }
    check(byAuthor.count == 1 && byAuthor.first?.changes?.first?.changeType == .insert, "history fetch filters by its fetch request")
    let changes = NSPersistentHistoryChangeRequest.fetchHistory(after: nil as NSPersistentHistoryToken?)
    changes.resultType = .changesOnly
    let list = ((try? c.viewContext.execute(changes)) as? NSPersistentHistoryResult)?.result as? [NSPersistentHistoryChange] ?? []
    check(list.count == 3 && list.allSatisfy { $0.transaction != nil }, "history changes-only results keep their transactions")
    if let token = all.last?.token { _ = try? c.viewContext.execute(NSPersistentHistoryChangeRequest.deleteHistory(before: token)) }
    check(history(c).count == 1, "history deletes before a token")
}

/// Joins first and last name into the new model's fullName.
@objc(FullNamePolicy) final class FullNamePolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
        let d = manager.destinationInstances(forEntityMappingName: mapping.name, sourceInstances: [sInstance]).first
        let first = sInstance.value(forKey: "first") as? String ?? "", last = sInstance.value(forKey: "last") as? String ?? ""
        d?.setValue("\(first) \(last)", forKey: "fullName")
    }
}

func model(_ entities: [(String, [NSPropertyDescription])]) -> NSManagedObjectModel {
    let m = NSManagedObjectModel()
    m.entities = entities.map { name, props in let e = NSEntityDescription(); e.name = name; e.properties = props; return e }
    return m
}
func relate(_ m: NSManagedObjectModel, _ from: String, _ name: String, _ to: String, toMany: Bool, inverse: String, inverseToMany: Bool) {
    let a = NSRelationshipDescription(), b = NSRelationshipDescription()
    a.name = name; a.destinationEntity = m.entitiesByName[to]; a.maxCount = toMany ? 0 : 1; a.isOptional = true
    b.name = inverse; b.destinationEntity = m.entitiesByName[from]; b.maxCount = inverseToMany ? 0 : 1; b.isOptional = true
    a.inverseRelationship = b; b.inverseRelationship = a
    m.entitiesByName[from]!.properties += [a]; m.entitiesByName[to]!.properties += [b]
}

func migrationPipelineTests() {
    let v1 = model([("Person", [attr("first", .stringAttributeType), attr("last", .stringAttributeType)]), ("Pet", [attr("name", .stringAttributeType)])])
    relate(v1, "Person", "pets", "Pet", toMany: true, inverse: "owner", inverseToMany: false)
    let v2 = model([("Person", [attr("fullName", .stringAttributeType)]), ("Pet", [attr("name", .stringAttributeType)])])
    relate(v2, "Person", "pets", "Pet", toMany: true, inverse: "owner", inverseToMany: false)
    let url = storeDir.appendingPathComponent("Pipeline.sqlite")
    let p1 = NSPersistentStoreCoordinator(managedObjectModel: v1)
    _ = try? p1.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
    let c1 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType); c1.persistentStoreCoordinator = p1
    let ada = NSManagedObject(entity: v1.entitiesByName["Person"]!, insertInto: c1); ada.setValue("Ada", forKey: "first"); ada.setValue("Lovelace", forKey: "last")
    for n in ["Rex", "Tom"] {
        let pet = NSManagedObject(entity: v1.entitiesByName["Pet"]!, insertInto: c1); pet.setValue(n, forKey: "name"); pet.setValue(ada, forKey: "owner")
    }
    try? c1.save()
    _ = try? p1.remove(p1.persistentStores[0])

    guard let mapping = try? NSMappingModel.inferredMappingModel(forSourceModel: v1, destinationModel: v2) else { check(false, "inferred mapping"); return }
    let personMapping = mapping.entityMappings.first { $0.destinationEntityName == "Person" }
    check(personMapping?.mappingType == .transformEntityMappingType && mapping.entityMappings.first { $0.destinationEntityName == "Pet" }?.mappingType == .copyEntityMappingType,
          "inferred mapping: transform and copy entity mappings")
    personMapping?.entityMigrationPolicyClassName = "FullNamePolicy"
    let manager = NSMigrationManager(sourceModel: v1, destinationModel: v2)
    var migrated = false
    do {
        try manager.migrateStore(from: url, sourceType: NSSQLiteStoreType, options: nil, with: mapping, toDestinationURL: url, destinationType: NSSQLiteStoreType, destinationOptions: nil)
        migrated = true
    } catch { check(false, "migrateStore: \(error)") }
    check(migrated && manager.migrationProgress == 1, "NSMigrationManager migrates a store in place through an entity migration policy")
    let p2 = NSPersistentStoreCoordinator(managedObjectModel: v2)
    _ = try? p2.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
    let c2 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType); c2.persistentStoreCoordinator = p2
    let people = (try? c2.fetch(NSFetchRequest<NSManagedObject>(entityName: "Person"))) ?? []
    let pets = (people.first?.value(forKey: "pets") as? Set<NSManagedObject>)?.compactMap { $0.value(forKey: "name") as? String }.sorted() ?? []
    check(people.count == 1 && people.first?.value(forKey: "fullName") as? String == "Ada Lovelace", "the policy's createDestinationInstances sets the new attribute")
    check(pets == ["Rex", "Tom"], "relationships are re-created between destination instances")
}

func stagedMigrationTests() {
    let s1 = model([("Item", [attr("title", .stringAttributeType)])])
    let s2 = model([("Item", [attr("title", .stringAttributeType), attr("length", .integer64AttributeType, defaultValue: 0)])])
    let s3 = model([("Item", [attr("title", .stringAttributeType), attr("length", .integer64AttributeType, defaultValue: 0), attr("label", .stringAttributeType)])])
    let url = storeDir.appendingPathComponent("Staged.sqlite")
    let p1 = NSPersistentStoreCoordinator(managedObjectModel: s1)
    _ = try? p1.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
    let c1 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType); c1.persistentStoreCoordinator = p1
    for t in ["apple", "kiwi"] { let o = NSManagedObject(entity: s1.entitiesByName["Item"]!, insertInto: c1); o.setValue(t, forKey: "title") }
    try? c1.save()
    _ = try? p1.remove(p1.persistentStores[0])

    var will = 0, did = 0
    let custom = NSCustomMigrationStage(migratingFrom: NSManagedObjectModelReference(model: s1, versionChecksum: s1.versionChecksum),
                                        to: NSManagedObjectModelReference(model: s2, versionChecksum: s2.versionChecksum))
    custom.label = "s1 to s2"
    custom.willMigrateHandler = { manager, _ in
        let ctx = manager.container!.viewContext
        for o in try ctx.fetch(NSFetchRequest<NSManagedObject>(entityName: "Item")) { o.setValue((o.value(forKey: "title") as! String).uppercased(), forKey: "title") }
        try ctx.save(); will += 1
    }
    custom.didMigrateHandler = { manager, _ in
        let ctx = manager.container!.viewContext
        for o in try ctx.fetch(NSFetchRequest<NSManagedObject>(entityName: "Item")) { o.setValue((o.value(forKey: "title") as! String).count, forKey: "length") }
        try ctx.save(); did += 1
    }
    let lightweight = NSLightweightMigrationStage([s2.versionChecksum])
    let staged = NSStagedMigrationManager([custom, lightweight])
    let c = NSPersistentContainer(name: "Staged", managedObjectModel: s3)
    let d = NSPersistentStoreDescription(url: url)
    d.setOption(staged, forKey: NSPersistentStoreStagedMigrationManagerOptionKey)
    c.persistentStoreDescriptions = [d]
    var loadError: Error?
    c.loadPersistentStores { _, e in loadError = e }
    let items = (try? c.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "Item"))) ?? []
    let summary = items.map { "\($0.value(forKey: "title") as? String ?? "?")=\(($0.value(forKey: "length") as? NSNumber)?.intValue ?? -1)" }.sorted()
    check(loadError == nil && will == 1 && did == 1, "staged migration runs the custom stage's handlers once each")
    check(summary == ["APPLE=5", "KIWI=4"] && items.allSatisfy { $0.value(forKey: "label") == nil }, "staged migration: custom stage, then the lightweight stage to the final model")
}
