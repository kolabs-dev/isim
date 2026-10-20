// Core Data self-test, issue #302: merge and constraint conflicts handed to the merge policy (NSMergeConflict,
// NSConstraintConflict, an NSMergePolicy subclass), asynchronous fetches, query generations, derived and composite
// attributes, fetch indexes, an NSIncrementalStore subclass, remote change notifications, the Core Spotlight delegate.
import Foundation
import CoreData
import CoreSpotlight

/// Counts the version conflicts it resolves, then merges like mergeByPropertyObjectTrump.
final class CountingPolicy: NSMergePolicy {
    var seen = 0
    override func resolve(optimisticLockingVersionConflicts list: [NSMergeConflict]) throws {
        seen += list.count
        try super.resolve(optimisticLockingVersionConflicts: list)
    }
}
/// Resolves a constraint conflict by renaming the new object instead of merging it into the stored one.
final class RenamingPolicy: NSMergePolicy {
    override func resolve(constraintConflicts list: [NSConstraintConflict]) throws {
        for c in list { for o in c.conflictingObjects { o.setValue("\(o.value(forKey: "name") as? String ?? "") (2)", forKey: "name") } }
    }
}

func classesStore(_ name: String, _ m: NSManagedObjectModel) -> NSPersistentStoreCoordinator {
    let url = storeDir.appendingPathComponent("\(name).sqlite")
    let psc = NSPersistentStoreCoordinator(managedObjectModel: m)
    do { _ = try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil) }
    catch { check(false, "\(name) store: \(error)") }
    return psc
}
func context(_ psc: NSPersistentStoreCoordinator) -> NSManagedObjectContext {
    let c = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType); c.persistentStoreCoordinator = psc; return c
}

func conflictTests() {
    let m = model([("Note", [attr("title", .stringAttributeType)]), ("Tag", [attr("name", .stringAttributeType)])])
    m.entitiesByName["Tag"]!.uniquenessConstraints = [["name"]]
    let psc = classesStore("Conflicts", m)
    let seed = context(psc)
    var noteID: NSManagedObjectID!
    seed.performAndWait {
        let n = NSManagedObject(entity: m.entitiesByName["Note"]!, insertInto: seed); n.setValue("start", forKey: "title")
        let t = NSManagedObject(entity: m.entitiesByName["Tag"]!, insertInto: seed); t.setValue("swift", forKey: "name")
        try? seed.save(); noteID = n.objectID
    }
    func edit(_ c: NSManagedObjectContext, _ title: String, save: Bool) {
        c.performAndWait { let n = c.object(with: noteID); _ = n.value(forKey: "title"); n.setValue(title, forKey: "title"); if save { try? c.save() } }
    }

    // NSErrorMergePolicy: the save fails, its conflictList holds NSMergeConflict objects
    let a = context(psc), b = context(psc)
    edit(a, "from A", save: false); edit(b, "from B", save: true)
    var saveError: NSError?
    a.performAndWait { do { try a.save() } catch { saveError = error as NSError } }
    let mc = (saveError?.userInfo[NSPersistentStoreSaveConflictsErrorKey] as? [Any])?.first as? NSMergeConflict
    check(saveError?.code == NSManagedObjectMergeError && mc?.sourceObject.objectID == noteID, "a version conflict's conflictList holds an NSMergeConflict")
    check(mc?.oldVersionNumber == 1 && mc?.newVersionNumber == 2 && mc?.persistedSnapshot?["title"] as? String == "from B"
          && mc?.cachedSnapshot?["title"] as? String == "start" && mc?.objectSnapshot?["title"] as? String == "from A",
          "NSMergeConflict: versions and the persisted, cached and object snapshots")

    // an NSMergePolicy subclass gets the conflicts, and super merges them
    let counting = CountingPolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    var saved = false, title = ""
    a.performAndWait { a.mergePolicy = counting; saved = (try? a.save()) != nil }
    seed.performAndWait { seed.reset(); title = seed.object(with: noteID).value(forKey: "title") as? String ?? "" }
    check(saved && counting.seen == 1 && title == "from A", "an NSMergePolicy subclass resolves version conflicts (\(counting.seen), \(title))")

    // uniqueness constraints: NSConstraintConflict, then a subclass that resolves them its own way
    let c = context(psc)
    var cc: NSConstraintConflict?
    c.performAndWait {
        let t = NSManagedObject(entity: m.entitiesByName["Tag"]!, insertInto: c); t.setValue("swift", forKey: "name")
        do { try c.save() } catch { cc = ((error as NSError).userInfo[NSPersistentStoreSaveConflictsErrorKey] as? [Any])?.first as? NSConstraintConflict }
    }
    check(cc?.constraint == ["name"] && cc?.constraintValues["name"] as? String == "swift" && cc?.databaseObject != nil
          && cc?.databaseSnapshot?["name"] as? String == "swift" && cc?.conflictingObjects.count == 1, "a uniqueness conflict is an NSConstraintConflict")
    var names: [String] = []
    c.performAndWait {
        c.mergePolicy = RenamingPolicy(merge: .errorMergePolicyType)
        saved = (try? c.save()) != nil
        names = ((try? c.fetch(NSFetchRequest<NSManagedObject>(entityName: "Tag"))) ?? []).compactMap { $0.value(forKey: "name") as? String }.sorted()
    }
    check(saved && names == ["swift", "swift (2)"], "an NSMergePolicy subclass resolves constraint conflicts (\(names))")
}

func asyncFetchTests() {
    let m = model([("Item", [attr("n", .integer64AttributeType)])])
    let psc = classesStore("Async", m)
    let c = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType); c.persistentStoreCoordinator = psc
    for i in 0..<5 { NSManagedObject(entity: m.entitiesByName["Item"]!, insertInto: c).setValue(i, forKey: "n") }
    try? c.save()
    let request = NSFetchRequest<NSManagedObject>(entityName: "Item"); request.predicate = NSPredicate(format: "n >= 2")
    var delivered: [NSManagedObject]?, onMain = false
    let asyncRequest = NSAsynchronousFetchRequest(fetchRequest: request) { result in delivered = result.finalResult; onMain = Thread.isMainThread }
    let result = (try? c.execute(asyncRequest)) as? NSAsynchronousFetchResult<NSManagedObject>
    check(result != nil && result?.finalResult == nil && delivered == nil, "NSAsynchronousFetchRequest returns its result before the fetch runs")
    check(waitFor { delivered != nil } && delivered?.count == 3 && onMain && result?.finalResult?.count == 3
          && result?.managedObjectContext === c && result?.progress?.isFinished == true && result?.operationError == nil,
          "the asynchronous fetch completes on the context's queue, with its progress finished")
    var called = false
    let cancelled = (try? c.execute(NSAsynchronousFetchRequest(fetchRequest: request) { _ in called = true })) as? NSAsynchronousFetchResult<NSManagedObject>
    cancelled?.cancel()
    spin(0.3)
    check(!called && cancelled?.finalResult == nil && cancelled?.progress?.isCancelled == true, "a cancelled asynchronous fetch does not run")
}

func queryGenerationTests() {
    let m = model([("Item", [attr("n", .integer64AttributeType)])])
    let psc = classesStore("Generations", m)
    let writer = context(psc)
    var firstID: NSManagedObjectID!
    func add(_ n: Int) { writer.performAndWait { let o = NSManagedObject(entity: m.entitiesByName["Item"]!, insertInto: writer); o.setValue(n, forKey: "n"); try? writer.save(); if firstID == nil { firstID = o.objectID } } }
    func count(_ c: NSManagedObjectContext) -> Int {
        var n = -1, fetched = -2
        c.performAndWait {
            n = (try? c.count(for: NSFetchRequest<NSManagedObject>(entityName: "Item"))) ?? -1
            fetched = (try? c.fetch(NSFetchRequest<NSManagedObject>(entityName: "Item")))?.count ?? -2
        }
        return n == fetched ? n : -3
    }
    add(1); add(2)
    let pinned = context(psc), loose = context(psc)
    var token: NSQueryGenerationToken?
    pinned.performAndWait { try? pinned.setQueryGenerationFrom(.current); token = pinned.queryGenerationToken }
    check(token != nil && token != NSQueryGenerationToken.current && count(pinned) == 2, "setQueryGenerationFrom(.current) pins a context to a snapshot")
    add(3)
    writer.performAndWait { writer.object(with: firstID).setValue(10, forKey: "n"); try? writer.save() }
    var faulted = 0
    pinned.performAndWait { faulted = (pinned.object(with: firstID).value(forKey: "n") as? Int) ?? -1 }
    check(count(pinned) == 2 && faulted == 1 && count(loose) == 3, "a pinned context keeps reading its generation: fetches, counts and faults")
    let shared = context(psc)
    shared.performAndWait { try? shared.setQueryGenerationFrom(token!) }
    check(count(shared) == 2 && shared.queryGenerationToken == token, "another context pins to the same generation token")
    pinned.performAndWait { pinned.reset() }
    check(count(pinned) == 3 && pinned.queryGenerationToken != nil && pinned.queryGenerationToken != token, "reset moves a pinned context to the current generation")
    pinned.performAndWait { try? pinned.setQueryGenerationFrom(nil) }
    check(pinned.queryGenerationToken == nil, "setQueryGenerationFrom(nil) unpins")
    let memory = NSPersistentStoreCoordinator(managedObjectModel: m)
    _ = try? memory.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
    let mc = context(memory)
    var memoryError: Error?
    mc.performAndWait { do { try mc.setQueryGenerationFrom(.current) } catch { memoryError = error } }
    check(memoryError != nil, "in-memory stores have no query generations")
}

import SQLite3
/// The names and SQL of the indexes SQLite has for a store's file.
func sqliteIndexes(_ url: URL) -> [String: String] {
    var db: OpaquePointer?, out: [String: String] = [:]
    guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return out }
    var st: OpaquePointer?
    sqlite3_prepare_v2(db, "SELECT name, sql FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL", -1, &st, nil)
    while sqlite3_step(st) == SQLITE_ROW { out[String(cString: sqlite3_column_text(st, 0))] = String(cString: sqlite3_column_text(st, 1)) }
    sqlite3_finalize(st); sqlite3_close(db)
    return out
}

func attributeKindTests() {
    let location = NSCompositeAttributeDescription()
    location.name = "location"
    location.elements = [attr("latitude", .doubleAttributeType), attr("longitude", .doubleAttributeType), attr("label", .stringAttributeType), attr("id", .UUIDAttributeType)]
    let upper = NSDerivedAttributeDescription()
    upper.name = "upperName"; upper.attributeType = .stringAttributeType
    upper.derivationExpression = NSExpression(format: "uppercase:(name)")
    let m = model([("Place", [attr("name", .stringAttributeType), attr("visits", .integer64AttributeType), location, upper])])
    let place = m.entitiesByName["Place"]!
    let byName = NSFetchIndexDescription(name: "byName", elements: [NSFetchIndexElementDescription(property: place.propertiesByName["name"]!, collationType: .binary)])
    let visits = NSFetchIndexElementDescription(property: place.propertiesByName["visits"]!, collationType: .binary)
    visits.isAscending = false
    let popular = NSFetchIndexDescription(name: "popular", elements: [visits])
    popular.partialIndexPredicate = NSPredicate(format: "visits > 10")
    place.indexes = [byName, popular]
    check(location.attributeType == .compositeAttributeType && byName.entity === place && visits.indexDescription === popular && visits.propertyName == "visits",
          "NSCompositeAttributeDescription and NSFetchIndexDescription describe the model")

    let psc = classesStore("Kinds", m)
    let c = context(psc)
    let id = UUID()
    c.performAndWait {
        for (name, lat, n) in [("Oslo", 59.9, 3), ("Lima", -12.0, 40)] {
            let o = NSManagedObject(entity: place, insertInto: c)
            o.setValue(name, forKey: "name"); o.setValue(n, forKey: "visits")
            o.setValue(["latitude": lat, "longitude": 10.7, "label": "\(name) centre", "id": id], forKey: "location")
        }
        try? c.save()
    }
    let fresh = context(psc)
    var oslo: [String: Any]?, upperNames: [String] = [], south: [String] = []
    fresh.performAndWait {
        let all = (try? fresh.fetch(NSFetchRequest<NSManagedObject>(entityName: "Place"))) ?? []
        oslo = all.first { $0.value(forKey: "name") as? String == "Oslo" }?.value(forKey: "location") as? [String: Any]
        upperNames = all.compactMap { $0.value(forKey: "upperName") as? String }.sorted()
        let r = NSFetchRequest<NSManagedObject>(entityName: "Place"); r.predicate = NSPredicate(format: "location.latitude < 0")
        south = ((try? fresh.fetch(r)) ?? []).compactMap { $0.value(forKey: "name") as? String }
    }
    check(oslo?["latitude"] as? Double == 59.9 && oslo?["label"] as? String == "Oslo centre" && oslo?["id"] as? UUID == id,
          "a composite attribute's dictionary survives the store")
    check(south == ["Lima"], "fetches filter on a composite attribute's elements")
    check(upperNames == ["LIMA", "OSLO"], "NSDerivedAttributeDescription values are computed on save")
    let indexes = sqliteIndexes(storeDir.appendingPathComponent("Kinds.sqlite"))
    check(indexes["Z_PLACE_BYNAME"]?.contains("ZNAME ASC") == true && indexes["Z_PLACE_POPULAR"]?.contains("ZVISITS DESC") == true
          && indexes["Z_PLACE_POPULAR"]?.contains("WHERE") == true, "fetch indexes are SQLite indexes, partial with a predicate (\(indexes.keys.sorted()))")
    let compiled = NSManagedObjectModel.mergedModel(from: [Bundle.main])?.entitiesByName["Author"]?.indexes.first
    check(compiled?.name == "byName" && compiled?.elements.first?.property?.name == "name"
          && sqliteIndexes(storeDir.appendingPathComponent("History2.sqlite"))["Z_AUTHOR_BYNAME"] != nil, "an .xcdatamodel's <fetchIndex> is compiled and indexed")
}

/// An incremental store over a dictionary (entity -> reference -> values; to-one relationships as references), like an
/// app's store over a web service or a file format.
final class DictionaryStore: NSIncrementalStore {
    static var rows: [String: [String: [String: Any]]] = [:]
    static var registeredIDs = 0
    var next = 1
    override func loadMetadata() throws { metadata = [NSStoreTypeKey: "DictionaryStore", NSStoreUUIDKey: "dictionary-store"] }
    func ref(_ id: NSManagedObjectID) -> String { referenceObject(for: id) as? String ?? "" }
    override func execute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext?) throws -> Any {
        if let fetch = request as? NSFetchRequest<NSFetchRequestResult>, let entity = fetch.entity, let context {
            var objects = (Self.rows[entity.name!] ?? [:]).keys.sorted().map { context.object(with: newObjectID(for: entity, referenceObject: $0)) }
            if let p = fetch.predicate { objects = objects.filter { p.evaluate(with: $0) } }
            if let s = fetch.sortDescriptors, !s.isEmpty { objects = (objects as NSArray).sortedArray(using: s) as? [NSManagedObject] ?? objects }
            return objects
        }
        if let save = request as? NSSaveChangesRequest {
            for o in (save.insertedObjects ?? []).union(save.updatedObjects ?? []) {
                var values: [String: Any] = [:]
                for (k, _) in o.entity.attributesByName { if let v = o.value(forKey: k) { values[k] = v } }
                for (k, r) in o.entity.relationshipsByName where !r.isToMany { if let d = o.value(forKey: k) as? NSManagedObject { values[k] = ref(d.objectID) } }
                Self.rows[o.entity.name!, default: [:]][ref(o.objectID)] = values
            }
            for o in save.deletedObjects ?? [] { Self.rows[o.entity.name!]?[ref(o.objectID)] = nil }
            return [Any]()
        }
        throw NSError(domain: "DictionaryStore", code: 1)
    }
    override func newValuesForObject(with objectID: NSManagedObjectID, with context: NSManagedObjectContext) throws -> NSIncrementalStoreNode {
        guard let row = Self.rows[objectID.entity.name!]?[ref(objectID)] else { throw NSError(domain: "DictionaryStore", code: 2) }
        var values: [String: Any] = [:]
        for (k, v) in row {
            if let r = objectID.entity.relationshipsByName[k], let d = r.destinationEntity { values[k] = newObjectID(for: d, referenceObject: v) } else { values[k] = v }
        }
        return NSIncrementalStoreNode(objectID: objectID, withValues: values, version: 1)
    }
    override func newValue(forRelationship relationship: NSRelationshipDescription, forObjectWith objectID: NSManagedObjectID, with context: NSManagedObjectContext?) throws -> Any {
        guard let dest = relationship.destinationEntity, let inverse = relationship.inverseRelationship?.name else { return NSNull() }
        let mine = ref(objectID)
        return (Self.rows[dest.name!] ?? [:]).filter { $0.value[inverse] as? String == mine }.keys.sorted().map { newObjectID(for: dest, referenceObject: $0) }
    }
    override func obtainPermanentIDs(for array: [NSManagedObject]) throws -> [NSManagedObjectID] {
        array.map { o in defer { next += 1 }; return newObjectID(for: o.entity, referenceObject: "\(o.entity.name!.lowercased())-\(next)") }
    }
    override func managedObjectContextDidRegisterObjects(with objectIDs: [NSManagedObjectID]) { Self.registeredIDs += objectIDs.count }
}

func incrementalStoreTests() {
    NSPersistentStoreCoordinator.registerStoreClass(DictionaryStore.self, forStoreType: "DictionaryStore")
    let m = model([("Shelf", [attr("name", .stringAttributeType)]), ("Card", [attr("title", .stringAttributeType)])])
    relate(m, "Shelf", "cards", "Card", toMany: true, inverse: "shelf", inverseToMany: false)
    let psc = NSPersistentStoreCoordinator(managedObjectModel: m)
    var store: NSPersistentStore?
    do { store = try psc.addPersistentStore(ofType: "DictionaryStore", configurationName: nil, at: nil, options: nil) } catch { check(false, "add an incremental store: \(error)") }
    check(store is DictionaryStore && store?.type == "DictionaryStore" && store?.identifier == "dictionary-store"
          && NSPersistentStoreCoordinator.registeredStoreTypes["DictionaryStore"] != nil, "registerStoreClass(_:forStoreType:) and an NSIncrementalStore's metadata")
    let c = context(psc)
    var shelfID: NSManagedObjectID!
    c.performAndWait {
        let shelf = NSManagedObject(entity: m.entitiesByName["Shelf"]!, insertInto: c); shelf.setValue("Kitchen", forKey: "name")
        for t in ["Tea", "Coffee", "Jam"] {
            let card = NSManagedObject(entity: m.entitiesByName["Card"]!, insertInto: c); card.setValue(t, forKey: "title"); card.setValue(shelf, forKey: "shelf")
        }
        do { try c.save() } catch { check(false, "save to an incremental store: \(error)") }
        shelfID = shelf.objectID
    }
    check(DictionaryStore.rows["Card"]?.count == 3 && DictionaryStore.rows["Card"]?["card-2"]?["shelf"] as? String == "shelf-1" && !shelfID.isTemporaryID,
          "saves reach the store as an NSSaveChangesRequest, with obtainPermanentIDs(for:)")
    let fresh = context(psc)
    var titles: [String] = [], shelfName = "", cardCount = 0, uriRoundTrip = false
    fresh.performAndWait {
        let r = NSFetchRequest<NSManagedObject>(entityName: "Card")
        r.predicate = NSPredicate(format: "title != %@", "Jam"); r.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        let cards = (try? fresh.fetch(r)) ?? []
        titles = cards.compactMap { $0.value(forKey: "title") as? String }
        shelfName = (cards.first?.value(forKey: "shelf") as? NSManagedObject)?.value(forKey: "name") as? String ?? ""
        cardCount = (fresh.object(with: shelfID).value(forKey: "cards") as? Set<NSManagedObject>)?.count ?? -1
        uriRoundTrip = psc.managedObjectID(forURIRepresentation: shelfID.uriRepresentation()) == shelfID
    }
    check(titles == ["Coffee", "Tea"] && shelfName == "Kitchen" && cardCount == 3,
          "fetches, faults and relationships go through the incremental store (\(titles), \(shelfName), \(cardCount))")
    check(uriRoundTrip && shelfID.uriRepresentation().absoluteString.hasSuffix("/Shelf/pshelf-1") && DictionaryStore.registeredIDs > 0,
          "reference objects in object IDs and URIs; contexts report the IDs they register")
    fresh.performAndWait {
        let cards = (try? fresh.fetch(NSFetchRequest<NSManagedObject>(entityName: "Card"))) ?? []
        cards.first { $0.value(forKey: "title") as? String == "Jam" }.map { fresh.delete($0) }
        cards.first { $0.value(forKey: "title") as? String == "Tea" }?.setValue("Green tea", forKey: "title")
        try? fresh.save()
    }
    let left = DictionaryStore.rows["Card"]?.values.compactMap { $0["title"] as? String }.sorted() ?? []
    check(left == ["Coffee", "Green tea"], "updates and deletes reach the incremental store (\(left))")
}

func remoteChangeTests() {
    let m = model([("Item", [attr("n", .integer64AttributeType)])])
    let url = storeDir.appendingPathComponent("Remote.sqlite")
    let options: [String: Any] = [NSPersistentStoreRemoteChangeNotificationPostOptionKey: true, NSPersistentHistoryTrackingKey: true]
    let watched = NSPersistentStoreCoordinator(managedObjectModel: m)
    _ = try? watched.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
    let lock = NSLock()
    var notes: [Notification] = []
    let observer = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: watched, queue: nil) { n in lock.lock(); notes.append(n); lock.unlock() }
    defer { NotificationCenter.default.removeObserver(observer) }
    let other = NSPersistentStoreCoordinator(managedObjectModel: m)                  /* another coordinator writes the file */
    _ = try? other.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: [NSPersistentHistoryTrackingKey: true])
    let c = context(other)
    c.performAndWait { NSManagedObject(entity: m.entitiesByName["Item"]!, insertInto: c).setValue(1, forKey: "n"); try? c.save() }
    let arrived = waitFor { lock.lock(); defer { lock.unlock() }; return !notes.isEmpty }
    lock.lock(); let info = notes.first?.userInfo; lock.unlock()
    check(arrived && info?[NSStoreUUIDKey] as? String == watched.persistentStores.first?.identifier
          && (info?[NSPersistentStoreURLKey] as? URL)?.lastPathComponent == "Remote.sqlite" && info?[NSPersistentHistoryTokenKey] is NSPersistentHistoryToken,
          "NSPersistentStoreRemoteChange is posted for another coordinator's write, with the store and a history token")
}

/// Adds a content description to the default attribute set.
final class RecipeSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {
    override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        let set = super.attributeSet(for: object)
        set?.contentDescription = "Recipe"
        return set
    }
}

func spotlightTests() {
    let name = attr("name", .stringAttributeType); name.isIndexedBySpotlight = true
    let m = model([("Recipe", [name, attr("secret", .stringAttributeType)])])
    let description = NSPersistentStoreDescription(url: storeDir.appendingPathComponent("Spotlight.sqlite"))
    let container = NSPersistentContainer(name: "Spotlight", managedObjectModel: m)
    container.persistentStoreDescriptions = [description]
    container.loadPersistentStores { _, error in if let error { check(false, "spotlight store: \(error)") } }
    let c = container.viewContext
    func add(_ n: String) -> NSManagedObject { let o = NSManagedObject(entity: m.entitiesByName["Recipe"]!, insertInto: c); o.setValue(n, forKey: "name"); o.setValue("x", forKey: "secret"); return o }
    let pancakes = add("Pancakes"); try? c.save()
    let delegate = RecipeSpotlightDelegate(forStoreWith: description, coordinator: container.persistentStoreCoordinator)
    let data = ProcessInfo.processInfo.environment["ISIM_DATA"] ?? ""
    let file = "\(data)/Library/Spotlight/\(Bundle.main.bundleIdentifier ?? "unknown").plist"
    func items() -> [[String: Any]] {
        ((NSDictionary(contentsOfFile: file) as? [String: Any])?["items"] as? [[String: Any]] ?? []).filter { $0["domain"] as? String == delegate.domainIdentifier() }
    }
    func titles() -> [String] { items().compactMap { $0["title"] as? String }.sorted() }
    delegate.startSpotlightIndexing()
    check(delegate.isIndexingEnabled && waitFor { titles() == ["Pancakes"] } && items().first?["description"] as? String == "Recipe"
          && items().first?["id"] as? String == pancakes.objectID.uriRepresentation().absoluteString,
          "NSCoreDataCoreSpotlightDelegate indexes the store's objects, through a subclass's attributeSet(for:) (\(titles()))")
    _ = add("Waffles"); try? c.save()
    check(waitFor { titles() == ["Pancakes", "Waffles"] }, "saves update the Spotlight index (\(titles()))")
    c.delete(pancakes); try? c.save()
    check(waitFor { titles() == ["Waffles"] }, "deleted objects leave the Spotlight index")
    delegate.stopSpotlightIndexing()
    var deleted = false
    delegate.deleteSpotlightIndex { _ in deleted = true }
    check(!delegate.isIndexingEnabled && waitFor { deleted && items().isEmpty }, "stopSpotlightIndexing and deleteSpotlightIndex")
}
