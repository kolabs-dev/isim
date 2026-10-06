// Relationships (inverses, to-many accessors, ordered, many-to-many), delete rules, validation and fetching
// on the compiled TestModel through NSPersistentContainer.
import Foundation
import CoreData

/// codeGenerationType="category": the class is written by hand, the properties are generated.
@objc(Publisher) public class Publisher: NSManagedObject {}

var containerCount = 0
func makeContainer(_ file: String? = nil) -> NSPersistentContainer {
    let c = NSPersistentContainer(name: "TestModel")
    containerCount += 1
    let url = storeDir.appendingPathComponent(file ?? "graph-\(containerCount).sqlite")
    c.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]
    var err: Error?
    c.loadPersistentStores { _, e in err = e }
    if let err { check(false, "loadPersistentStores: \(err)") }
    return c
}

func relationshipTests() {
    let defaultURL = NSPersistentContainer.defaultDirectoryURL()
    check(defaultURL.path.hasSuffix("Library/Application Support"), "defaultDirectoryURL is Library/Application Support")
    let c = makeContainer()
    let ctx = c.viewContext
    let a = Author(context: ctx); a.name = "Ann"
    let b1 = Book(context: ctx); b1.title = "One"
    let b2 = Book(context: ctx); b2.title = "Two"
    b1.author = a
    check((a.books as? Set<Book>) == [b1], "to-one set maintains the inverse to-many")
    a.addToBooks(b2)
    check(b2.author === a && a.books?.count == 2, "generated addToBooks(_:) (add<Key>Object:) maintains the inverse")
    a.removeFromBooks(b1)
    check(b1.author == nil && a.books?.count == 1, "removeFromBooks(_:) nullifies the inverse")
    a.addToBooks(NSSet(array: [b1]))
    let a2 = Author(context: ctx); a2.name = "Bob"
    b1.author = a2
    check(a.books?.count == 1 && a2.books?.contains(b1) == true, "moving a book between authors updates both sides")
    let s = Shelf(context: ctx); s.label = "Top"
    s.addToBooks(b1); s.addToBooks(b2)
    check(b1.shelves?.contains(s) == true && b2.shelves?.count == 1, "many-to-many inverse maintenance")
    s.addToFeatured(b2); s.addToFeatured(b1); s.insertIntoFeatured(Book(context: ctx), at: 0)
    (s.featured?.firstObject as? Book)?.title = "Zero"
    let mset = a2.mutableSetValue(forKey: "books")
    let b3 = Book(context: ctx); b3.title = "Three"
    mset.add(b3)
    check(b3.author === a2 && a2.books?.count == 2, "mutableSetValue(forKey:) proxy writes through")
    let n = Novel(context: ctx); n.title = "Saga"; n.genre = "Fantasy"; n.author = a
    let p = Publisher(context: ctx); p.name = "Pub"
    b2.isbn = UUID(); b2.tags = ["x", "y"]; b2.pages = 120; b2.rating = 4.5; b2.borrowed = true; b2.sold = 99
    do { try ctx.save() } catch { check(false, "graph save: \(error)") }

    // reload everything through a second container on the same file
    let url = c.persistentStoreCoordinator.persistentStores[0].url!
    let c2 = NSPersistentContainer(name: "TestModel")
    c2.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]
    c2.loadPersistentStores { _, _ in }
    let ctx2 = c2.viewContext
    let shelves = (try? ctx2.fetch((Shelf.fetchRequest() as NSFetchRequest<Shelf>))) ?? []
    let s2 = shelves.first
    check((s2?.featured?.array as? [Book])?.map { $0.title ?? "" } == ["Zero", "Two", "One"], "ordered to-many keeps its order in the store")
    check(s2?.books?.count == 2 && (s2?.books?.allObjects as? [Book])?.allSatisfy { $0.shelves?.contains(s2!) == true } == true, "many-to-many reloads both sides")
    let ann = (try? ctx2.fetch({ let r = (Author.fetchRequest() as NSFetchRequest<Author>); r.predicate = NSPredicate(format: "name == %@", "Ann"); return r }()))?.first
    check(ann?.books?.count == 2 && ann?.isFault == false, "to-many loaded lazily from the store (\(ann?.books?.count ?? -1))")
    let two = (ann?.books as? Set<Book>)?.first { $0.title == "Two" }
    check(two?.tags == ["x", "y"] && two?.pages == 120 && two?.rating == 4.5 && two?.borrowed == true && two?.sold == 99 && two?.isbn == b2.isbn,
          "generated attribute types reload (Transformable [String], Int32, Double, Bool, NSNumber, UUID)")
    let saga = (ann?.books as? Set<Book>)?.first { $0.title == "Saga" }
    check(saga is Novel && (saga as? Novel)?.genre == "Fantasy", "sub-entity object reloads as its class (Novel)")
    let pub = (try? ctx2.fetch((Publisher.fetchRequest() as NSFetchRequest<Publisher>)))?.first
    check(pub?.name == "Pub", "codegen (category): hand-written class + generated properties")
    let fetched = pub?.value(forKey: "authorsA") as? [Author]
    check(fetched?.map { $0.name } == ["Ann"], "fetched property (name BEGINSWITH 'A')")

    // object(with:) gives a fault that fires on access
    let bob = (try? ctx2.fetch({ let r = (Author.fetchRequest() as NSFetchRequest<Author>); r.predicate = NSPredicate(format: "name == 'Bob'"); return r }()))!.first!
    let ctx3 = c2.newBackgroundContext()
    ctx3.performAndWait {
        let f = ctx3.object(with: bob.objectID) as! Author
        let wasFault = f.isFault
        check(wasFault && f.name == "Bob" && !f.isFault, "object(with:) returns a fault that fires on access")
    }

    // delete rules
    ctx2.delete(ann!)
    check(ann!.isDeleted && (ann!.books as? Set<Book>)?.allSatisfy { $0.isDeleted } == true, "cascade delete marks the author's books deleted")
    ctx2.rollback()
    let one = (try? ctx2.fetch({ let r = (Book.fetchRequest() as NSFetchRequest<Book>); r.predicate = NSPredicate(format: "title == 'One'"); return r }()))?.first
    let owner = one?.author
    ctx2.delete(one!)
    check(owner?.books?.contains(one!) == false && s2?.books?.contains(one!) == false, "nullify removes the deleted book from its author and shelf")
    let err: NSError? = { do { try ctx2.save(); return nil } catch { return error as NSError } }()
    check(err == nil, "save after nullify")
    ctx2.delete(s2!)
    let denied: NSError? = { do { try ctx2.save(); return nil } catch { return error as NSError } }()
    check(denied?.code == NSValidationRelationshipDeniedDeleteError, "deny rule: deleting a shelf with books fails (\(denied?.code ?? 0))")
    ctx2.rollback()

    // validation
    let nameless = Author(context: ctx2)
    let missing: NSError? = { do { try ctx2.save(); return nil } catch { return error as NSError } }()
    check(missing?.code == NSValidationMissingMandatoryPropertyError && missing?.userInfo[NSValidationKeyErrorKey] as? String == "name",
          "validation: missing mandatory attribute (1570)")
    nameless.name = "Ok"
    let big = Book(context: ctx2); big.pages = 9000
    let tooBig: NSError? = { do { try ctx2.save(); return nil } catch { return error as NSError } }()
    check(tooBig?.code == NSValidationNumberTooLargeError, "validation: maxValue (1610)")
    big.pages = 10
    check((try? ctx2.save()) != nil, "save after fixing validation errors")
}

func fetchTests() {
    let c = makeContainer()
    let ctx = c.viewContext
    let names = ["Ada", "alan", "Barbara", "Edsger", "Grace", "Linus", "ken"]
    var authors: [Author] = []
    for (i, n) in names.enumerated() {
        let a = Author(context: ctx); a.name = n
        a.born = Date(timeIntervalSinceReferenceDate: Double(i) * 1000)
        for k in 0..<i { let b = Book(context: ctx); b.title = "\(n) \(k)"; b.pages = Int32(100 * (k + 1)); b.author = a; b.rating = Double(k) }
        authors.append(a)
    }
    try? ctx.save()
    func titles(_ format: String, _ args: Any..., sort: String = "name", limit: Int = 0, offset: Int = 0) -> [String] {
        let r = (Author.fetchRequest() as NSFetchRequest<Author>)
        r.predicate = NSPredicate(format: format, argumentArray: args)
        r.sortDescriptors = [NSSortDescriptor(key: sort, ascending: true)]
        r.fetchLimit = limit; r.fetchOffset = offset
        return ((try? ctx.fetch(r)) ?? []).map { $0.name ?? "" }
    }
    check(titles("name == %@", "Grace") == ["Grace"], "SQL: ==")
    check(titles("name BEGINSWITH[c] %@", "a") == ["Ada", "alan"], "SQL: BEGINSWITH[c]")
    check(titles("name CONTAINS %@", "r") == ["Barbara", "Edsger", "Grace"], "SQL: CONTAINS")
    check(titles("name ENDSWITH 'a'") == ["Ada", "Barbara"], "SQL: ENDSWITH")
    check(titles("name IN %@", ["ken", "Ada", "zzz"]) == ["Ada", "ken"], "SQL: IN")
    check(titles("born BETWEEN %@", [Date(timeIntervalSinceReferenceDate: 1000), Date(timeIntervalSinceReferenceDate: 3000)]) == ["Barbara", "Edsger", "alan"], "SQL: BETWEEN dates")
    check(titles("NOT (name == 'Ada') AND (name LIKE 'B*' OR name LIKE[c] 'K?N')") == ["Barbara", "ken"], "SQL: NOT, AND, OR, LIKE")
    check(titles("born > %@", Date(timeIntervalSinceReferenceDate: 4500), limit: 1) == ["Linus"], "SQL: date >, fetchLimit")
    check(titles("TRUEPREDICATE", limit: 2, offset: 2) == ["Edsger", "Grace"], "fetchOffset + fetchLimit")
    check(titles("books.@count >= 5") == ["Linus", "ken"], "in memory: @count key path")
    check(titles("ANY books.pages > 400") == ["Linus", "ken"], "in memory: ANY over a to-many")
    let bookReq = (Book.fetchRequest() as NSFetchRequest<Book>)
    bookReq.predicate = NSPredicate(format: "author == %@ AND pages >= 200", authors[3])
    bookReq.sortDescriptors = [NSSortDescriptor(key: "pages", ascending: false)]
    check(((try? ctx.fetch(bookReq)) ?? []).map { $0.title ?? "" } == ["Edsger 2", "Edsger 1"], "SQL: to-one == object, sort descending")
    let byAuthorName = (Book.fetchRequest() as NSFetchRequest<Book>)
    byAuthorName.predicate = NSPredicate(format: "author.name == 'Grace' AND title ENDSWITH '0'")
    check(((try? ctx.fetch(byAuthorName)) ?? []).map { $0.title ?? "" } == ["Grace 0"], "mixed: key path through to-one (memory) AND SQL part")
    let none = (Author.fetchRequest() as NSFetchRequest<Author>); none.predicate = NSPredicate(format: "born == nil")
    check((try? ctx.count(for: none)) == 0, "SQL: == nil, count(for:)")
    check((try? ctx.count(for: (Book.fetchRequest() as NSFetchRequest<Book>))) == 21, "count(for:) all books")

    // pending changes are included
    let newbie = Author(context: ctx); newbie.name = "Aaron"
    authors[0].name = "Zed"
    ctx.delete(authors[6])
    check(titles("TRUEPREDICATE") == ["Aaron", "Barbara", "Edsger", "Grace", "Linus", "Zed", "alan"], "fetch includes unsaved inserts, updates and deletes")
    check(titles("name BEGINSWITH 'A'") == ["Aaron"], "unsaved changes are matched by the predicate")
    ctx.rollback()

    // result types
    let ids = NSFetchRequest<NSManagedObjectID>(entityName: "Author")
    ids.resultType = .managedObjectIDResultType
    check((try? ctx.fetch(ids))?.count == 7, "resultType .managedObjectIDResultType")
    let dicts = NSFetchRequest<NSDictionary>(entityName: "Book")
    dicts.resultType = .dictionaryResultType
    dicts.propertiesToFetch = ["title", "pages"]
    dicts.predicate = NSPredicate(format: "title == 'Ken 0' OR title == 'ken 0'")
    let d = (try? ctx.fetch(dicts))?.first
    check(d?["title"] as? String == "ken 0" && (d?["pages"] as? NSNumber)?.intValue == 100 && d?.count == 2, "resultType .dictionaryResultType + propertiesToFetch")
    let sum = NSExpressionDescription(); sum.name = "total"
    sum.expression = NSExpression(forFunction: "sum:", arguments: [NSExpression(forKeyPath: "pages")]); sum.expressionResultType = .integer64AttributeType
    let agg = NSFetchRequest<NSDictionary>(entityName: "Book"); agg.resultType = .dictionaryResultType; agg.propertiesToFetch = [sum]
    check(((try? ctx.fetch(agg))?.first?["total"] as? NSNumber)?.intValue == 5600, "aggregate expression (sum:) in a dictionary fetch")
    let cnt = NSFetchRequest<NSNumber>(entityName: "Book"); cnt.resultType = .countResultType
    check((try? ctx.fetch(cnt))?.first?.intValue == 21, "resultType .countResultType")
    let tmpl = c.managedObjectModel.fetchRequestFromTemplate(withName: "LongBooks", substitutionVariables: [:])
    check((tmpl.flatMap { try? ctx.count(for: $0) }) == 6, "fetch request template (pages > 300)")
    let n = Novel(context: ctx); n.title = "Novel"
    let all = (Book.fetchRequest() as NSFetchRequest<Book>), only = (Book.fetchRequest() as NSFetchRequest<Book>); only.includesSubentities = false
    check((try? ctx.count(for: all)) == 22 && (try? ctx.count(for: only)) == 21, "includesSubentities")
    ctx.rollback()
    let swiftSorted = authors.sorted { ($0.name ?? "") < ($1.name ?? "") }.map { $0.name! }
    let r = (Author.fetchRequest() as NSFetchRequest<Author>); r.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))]
    check(((try? ctx.fetch(r)) ?? []).map { $0.name! } == ["Ada", "alan", "Barbara", "Edsger", "Grace", "ken", "Linus"] && swiftSorted.count == 7,
          "sort with a selector (in memory)")
    // NSFetchRequest.execute() inside perform
    let bg = c.newBackgroundContext()
    var executed = 0
    bg.performAndWait { executed = (try? (Author.fetchRequest() as NSFetchRequest<Author>).execute())?.count ?? -1 }
    check(executed == 7, "NSFetchRequest.execute() in performAndWait on a private-queue context")
}
