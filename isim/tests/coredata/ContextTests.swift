// Contexts: notifications, child contexts, background contexts and merging, merge policies, reset;
// batch requests; NSFetchedResultsController; lightweight migration; async perform.
import Foundation
import CoreData
import UIKit

func contextTests() {
    let c = makeContainer()
    let view = c.viewContext
    // ObjectsDidChange / DidSave notifications
    var changed: [String: Int] = [:]
    let o1 = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: view, queue: nil) { n in
        for k in [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey] { changed[k, default: 0] += (n.userInfo?[k] as? Set<NSManagedObject>)?.count ?? 0 }
    }
    var saved: Set<NSManagedObject> = []
    let o2 = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: view, queue: nil) { n in
        saved = n.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
    }
    let a = Author(context: view); a.name = "Notified"
    view.processPendingChanges()
    check(changed[NSInsertedObjectsKey] == 1, "ObjectsDidChange: inserted object")
    try? view.save()
    check(saved.count == 1 && saved.first === a, "DidSave notification carries the inserted objects")
    a.name = "Notified 2"
    spin()
    check(changed[NSUpdatedObjectsKey] == 1, "ObjectsDidChange posted at the end of the event (updated)")
    try? view.save()
    NotificationCenter.default.removeObserver(o1); NotificationCenter.default.removeObserver(o2)

    // child context: changes stay in the child until it saves
    let child = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    child.parent = view
    let ca = child.object(with: a.objectID) as! Author
    ca.name = "From child"
    let cb = Book(context: child); cb.title = "Child book"; cb.author = ca
    check(a.name == "Notified 2" && a.books?.count == 0, "child edits are invisible to the parent before the child saves")
    let childSeesOwn = (try? child.fetch((Book.fetchRequest() as NSFetchRequest<Book>)))?.count
    check(childSeesOwn == 1, "child fetch sees its own unsaved insert")
    do { try child.save() } catch { check(false, "child save: \(error)") }
    check(a.name == "From child" && a.books?.count == 1 && view.hasChanges, "child save pushes into the parent (parent now has unsaved changes)")
    let parentBook = (a.books?.anyObject() as? Book)
    check(parentBook?.title == "Child book" && parentBook?.objectID == cb.objectID, "child-inserted object appears in the parent with the same ID")
    try? view.save()
    let probe = makeContainer(c.persistentStoreCoordinator.persistentStores[0].url!.lastPathComponent)
    check((try? probe.viewContext.count(for: (Book.fetchRequest() as NSFetchRequest<Book>))) == 1, "parent save writes the child's object to the store")

    // background context + automaticallyMergesChangesFromParent on the view context
    view.automaticallyMergesChangesFromParent = true
    var bgDone = false
    c.performBackgroundTask { bg in
        let b = Book(context: bg); b.title = "Background"
        let mine = bg.object(with: a.objectID) as! Author
        b.author = mine
        mine.name = "Merged"
        try? bg.save()
        bgDone = true
    }
    check(waitFor { bgDone && a.name == "Merged" }, "background save merges into the viewContext (automaticallyMergesChangesFromParent)")
    check(a.books?.count == 2, "merged to-many relationship (\(a.books?.count ?? -1))")

    // mergeChanges(fromContextDidSave:) between two root contexts
    let other = c.newBackgroundContext()
    var note: Notification?
    let o3 = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: other, queue: nil) { note = $0 }
    other.performAndWait {
        let x = other.object(with: a.objectID) as! Author
        x.name = "Via notification"
        try? other.save()
    }
    NotificationCenter.default.removeObserver(o3)
    let manual = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    manual.persistentStoreCoordinator = c.persistentStoreCoordinator
    let ma = try? manual.existingObject(with: a.objectID) as? Author
    _ = ma?.name
    if let note {
        ma?.managedObjectContext?.mergeChanges(fromContextDidSave: note)
    }
    check(ma?.name == "Via notification", "mergeChanges(fromContextDidSave:) refreshes an object")
    _ = waitFor { a.name == "Via notification" }

    // merge policies: two contexts edit the same object
    let ctxA = c.newBackgroundContext(), ctxB = c.newBackgroundContext()
    var e1: NSError?, e2: NSError?, final = ""
    ctxA.performAndWait { (ctxA.object(with: a.objectID) as! Author).name = "A wins?" }
    ctxB.performAndWait { (ctxB.object(with: a.objectID) as! Author).name = "B"; _ = (ctxB.object(with: a.objectID) as! Author).name; try? ctxB.save() }
    ctxA.performAndWait { do { try ctxA.save() } catch { e1 = error as NSError } }
    check(e1?.code == NSManagedObjectMergeError, "NSErrorMergePolicy: conflicting save fails (133020)")
    ctxA.performAndWait {
        ctxA.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        do { try ctxA.save() } catch { e2 = error as NSError }
    }
    let check1 = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    check1.persistentStoreCoordinator = c.persistentStoreCoordinator
    check1.performAndWait { final = (try? check1.existingObject(with: a.objectID) as? Author)?.name ?? "" }
    check(e2 == nil && final == "A wins?", "mergeByPropertyObjectTrump: this context's values win (\(final))")
    let ctxC = c.newBackgroundContext(), ctxD = c.newBackgroundContext()
    ctxC.performAndWait { _ = (ctxC.object(with: a.objectID) as! Author).name; (ctxC.object(with: a.objectID) as! Author).name = "C" }
    ctxD.performAndWait { (ctxD.object(with: a.objectID) as! Author).name = "D"; try? ctxD.save() }
    ctxC.performAndWait { ctxC.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump; try? ctxC.save() }
    check1.performAndWait { check1.reset(); final = (try? check1.existingObject(with: a.objectID) as? Author)?.name ?? "" }
    check(final == "D", "mergeByPropertyStoreTrump: the store's values win (\(final))")

    // reset / refresh
    let before = view.registeredObjects.count
    view.reset()
    check(before > 0 && view.registeredObjects.isEmpty && !view.hasChanges, "reset() forgets registered objects")
    let reloaded = try? view.existingObject(with: a.objectID) as? Author
    view.refresh(reloaded!, mergeChanges: false)
    check(reloaded?.isFault == true && reloaded?.name == "D", "refresh(_:mergeChanges: false) turns the object into a fault that reloads")
}

func batchTests() {
    let c = makeContainer()
    let ctx = c.viewContext
    for i in 0..<10 { let b = Book(context: ctx); b.title = "B\(i)"; b.pages = Int32(i * 10) }
    try? ctx.save()
    let upd = NSBatchUpdateRequest(entityName: "Book")
    upd.predicate = NSPredicate(format: "pages >= 50")
    upd.propertiesToUpdate = ["borrowed": true]
    upd.resultType = .updatedObjectsCountResultType
    let ur = try? ctx.execute(upd) as? NSBatchUpdateResult
    check((ur?.result as? NSNumber)?.intValue == 5, "NSBatchUpdateRequest updates rows in the store (count result)")
    let del = NSBatchDeleteRequest(fetchRequest: { let r = NSFetchRequest<NSFetchRequestResult>(entityName: "Book"); r.predicate = NSPredicate(format: "pages < 30"); return r }())
    del.resultType = .resultTypeObjectIDs
    let dr = try? ctx.execute(del) as? NSBatchDeleteResult
    let deleted = dr?.result as? [NSManagedObjectID] ?? []
    check(deleted.count == 3, "NSBatchDeleteRequest deletes rows (object IDs result)")
    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: deleted], into: [ctx])
    ctx.reset()
    let borrowed = (Book.fetchRequest() as NSFetchRequest<Book>); borrowed.predicate = NSPredicate(format: "borrowed == YES")
    check((try? ctx.count(for: (Book.fetchRequest() as NSFetchRequest<Book>))) == 7 && (try? ctx.count(for: borrowed)) == 5, "store reflects batch update + delete")
}

final class FRCDelegate: NSObject, NSFetchedResultsControllerDelegate {
    var events: [String] = []
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) { events.append("will") }
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        let t = (anObject as? Book)?.title ?? "?"
        switch type {
        case .insert: events.append("insert \(t) \(newIndexPath!.section)/\(newIndexPath!.item)")
        case .delete: events.append("delete \(t) \(indexPath!.section)/\(indexPath!.item)")
        case .move: events.append("move \(t)")
        case .update: events.append("update \(t)")
        @unknown default: break
        }
    }
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        events.append("\(type == .insert ? "insert" : "delete") section \(sectionInfo.name)")
    }
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) { events.append("did") }
}
final class SnapshotDelegate: NSObject, NSFetchedResultsControllerDelegate {
    var last: NSDiffableDataSourceSnapshot<String, NSManagedObjectID>?
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        last = snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
    }
}

func fetchedResultsControllerTests() {
    let c = makeContainer()
    let ctx = c.viewContext
    for (t, g) in [("Alpha", "A"), ("Apex", "A"), ("Beta", "B")] { let n = Novel(context: ctx); n.title = t; n.genre = g }
    try? ctx.save()
    let req = (Novel.fetchRequest() as NSFetchRequest<Novel>)
    req.sortDescriptors = [NSSortDescriptor(key: "genre", ascending: true), NSSortDescriptor(key: "title", ascending: true)]
    let frc = NSFetchedResultsController(fetchRequest: req, managedObjectContext: ctx, sectionNameKeyPath: "genre", cacheName: nil)
    let d = FRCDelegate()
    frc.delegate = d
    check((try? frc.performFetch()) != nil && frc.sections?.map { $0.name } == ["A", "B"] && frc.sections?[0].numberOfObjects == 2, "NSFetchedResultsController sections by key path")
    check(frc.object(at: IndexPath(item: 1, section: 0)).title == "Apex" && frc.indexPath(forObject: frc.fetchedObjects![2]) == IndexPath(item: 0, section: 1),
          "object(at:) / indexPath(forObject:)")
    let n = Novel(context: ctx); n.title = "Gamma"; n.genre = "C"
    ctx.processPendingChanges()
    check(d.events == ["will", "insert section C", "insert Gamma 2/0", "did"], "delegate: section + object insert (\(d.events))")
    d.events = []
    (frc.fetchedObjects?[0])?.title = "Alpha 2"
    ctx.processPendingChanges()
    check(d.events == ["will", "update Alpha 2", "did"], "delegate: update (\(d.events))")
    d.events = []
    ctx.delete(frc.fetchedObjects![2])
    ctx.processPendingChanges()
    check(d.events == ["will", "delete section B", "delete Beta 1/0", "did"], "delegate: delete with its section (\(d.events))")

    let sd = SnapshotDelegate()
    let frc2 = NSFetchedResultsController(fetchRequest: req, managedObjectContext: ctx, sectionNameKeyPath: "genre", cacheName: nil)
    frc2.delegate = sd
    try? frc2.performFetch()
    let z = Novel(context: ctx); z.title = "Zeta"; z.genre = "A"
    ctx.processPendingChanges()
    check(sd.last?.sectionIdentifiers == ["A", "C"] && sd.last?.itemIdentifiers(inSection: "A").count == 3 && sd.last?.itemIdentifiers.contains(z.objectID) == true,
          "controller(_:didChangeContentWith:) snapshot bridged to NSDiffableDataSourceSnapshot")
    ctx.rollback()
}

func migrationTests() {
    func entity(_ name: String, _ props: [NSPropertyDescription]) -> NSEntityDescription {
        let e = NSEntityDescription(); e.name = name; e.properties = props; return e
    }
    let v1 = NSManagedObjectModel(); v1.entities = [entity("Mig", [attr("title", .stringAttributeType)])]
    let v2 = NSManagedObjectModel()
    v2.entities = [entity("Mig", [attr("title", .stringAttributeType), attr("score", .integer64AttributeType, defaultValue: 5)]),
                   entity("Extra", [attr("x", .stringAttributeType)])]
    let url = storeDir.appendingPathComponent("Migrate.sqlite")
    let p1 = NSPersistentStoreCoordinator(managedObjectModel: v1)
    _ = try? p1.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
    let c1 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType); c1.persistentStoreCoordinator = p1
    let m = NSManagedObject(entity: v1.entitiesByName["Mig"]!, insertInto: c1); m.setValue("kept", forKey: "title")
    try? c1.save()
    _ = try? p1.remove(p1.persistentStores[0])

    let p2 = NSPersistentStoreCoordinator(managedObjectModel: v2)
    var err: NSError?
    do { _ = try p2.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil) } catch { err = error as NSError }
    check(err?.code == NSPersistentStoreIncompatibleVersionHashError, "opening with a changed model without migration options fails (134100)")
    let opts = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
    let store = try? p2.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: opts)
    let c2 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType); c2.persistentStoreCoordinator = p2
    let rows = (try? c2.fetch(NSFetchRequest<NSManagedObject>(entityName: "Mig"))) ?? []
    check(store != nil && rows.count == 1 && rows.first?.value(forKey: "title") as? String == "kept" && (rows.first?.value(forKey: "score") as? NSNumber)?.intValue == 5,
          "lightweight migration: data kept, added attribute gets its default")
    let x = NSManagedObject(entity: v2.entitiesByName["Extra"]!, insertInto: c2); x.setValue("new", forKey: "x")
    check((try? c2.save()) != nil, "lightweight migration: added entity is usable")
}

func asyncTests() {
    let c = makeContainer()
    var result: Int?, bgName: String?
    Task { @MainActor in
        let ctx = c.viewContext
        result = await ctx.perform { () -> Int in
            let a = Author(context: ctx); a.name = "Async"
            try? ctx.save()
            return (try? ctx.count(for: (Author.fetchRequest() as NSFetchRequest<Author>))) ?? -1
        }
        bgName = try? await c.performBackgroundTask { bg in
            try bg.fetch((Author.fetchRequest() as NSFetchRequest<Author>)).first?.name
        }
    }
    check(waitFor { result != nil && bgName != nil }, "async perform / performBackgroundTask complete")
    check(result == 1 && bgName == "Async", "async perform returns the block's value")
}
