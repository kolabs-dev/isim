// Programmatic models, every attribute type through SQLite, @NSManaged scalars, persistence across "relaunch",
// in-memory stores, value transformers and the compiled (momc) model with generated classes.
import Foundation
import CoreData
import Combine

@objc(Gadget) final class Gadget: NSManagedObject {
    @NSManaged var i16: Int16
    @NSManaged var i32: Int32
    @NSManaged var i64: Int64
    @NSManaged var dbl: Double
    @NSManaged var flt: Float
    @NSManaged var flag: Bool
    @NSManaged var boxed: NSNumber?
    @NSManaged var name: String?
    @NSManaged var when: Date?
    @NSManaged var blob: Data?
    @NSManaged var uuid: UUID?
    @NSManaged var link: URL?
    @NSManaged var dec: NSNumber?
    @NSManaged var info: NSDictionary?
    var awoke = false
    override func awakeFromInsert() { super.awakeFromInsert(); awoke = true; setPrimitiveValue("fresh", forKey: "name") }
}

func attr(_ name: String, _ type: NSAttributeType, optional: Bool = true, defaultValue: Any? = nil) -> NSAttributeDescription {
    let a = NSAttributeDescription()
    a.name = name; a.attributeType = type; a.isOptional = optional; a.defaultValue = defaultValue
    return a
}

func gadgetModel() -> NSManagedObjectModel {
    let e = NSEntityDescription()
    e.name = "Gadget"
    e.managedObjectClassName = NSStringFromClass(Gadget.self)
    let info = attr("info", .transformableAttributeType)
    info.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
    e.properties = [attr("i16", .integer16AttributeType, defaultValue: 7), attr("i32", .integer32AttributeType), attr("i64", .integer64AttributeType),
                    attr("dbl", .doubleAttributeType), attr("flt", .floatAttributeType), attr("flag", .booleanAttributeType, defaultValue: true),
                    attr("boxed", .integer64AttributeType), attr("name", .stringAttributeType), attr("when", .dateAttributeType),
                    attr("blob", .binaryDataAttributeType), attr("uuid", .UUIDAttributeType), attr("link", .URIAttributeType),
                    attr("dec", .decimalAttributeType), info]
    let m = NSManagedObjectModel()
    m.entities = [e]
    return m
}

func valueTransformerTests() {
    let neg = ValueTransformer(forName: .negateBooleanTransformerName)
    check((neg?.transformedValue(NSNumber(value: true)) as? NSNumber)?.boolValue == false, "ValueTransformer: NSNegateBoolean")
    let sec = ValueTransformer(forName: .secureUnarchiveFromDataTransformerName)
    let data = sec?.reverseTransformedValue(["a": 1] as NSDictionary) as? Data
    let back = data.flatMap { sec?.transformedValue($0) } as? NSDictionary
    check(data != nil && back?["a"] as? Int == 1, "NSSecureUnarchiveFromDataTransformer round trip")
}

func programmaticModelTests() {
    let model = gadgetModel()
    let url = storeDir.appendingPathComponent("Gadgets.sqlite")
    func open() -> (NSPersistentStoreCoordinator, NSManagedObjectContext) {
        let psc = NSPersistentStoreCoordinator(managedObjectModel: model)
        do { _ = try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil) }
        catch { check(false, "addPersistentStore SQLite: \(error)") }
        let ctx = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        ctx.persistentStoreCoordinator = psc
        return (psc, ctx)
    }
    var (psc, ctx) = open()
    let g = Gadget(context: ctx)
    check(g.awoke && g.name == "fresh" && g.i16 == 7 && g.flag, "init(context:), awakeFromInsert, default values")
    check(g.objectID.isTemporaryID && g.isInserted && ctx.hasChanges, "new object: temporary ID, inserted, context has changes")
    let when = Date(timeIntervalSinceReferenceDate: 700_000_000.25)
    let uuid = UUID()
    g.i16 = -12; g.i32 = 1_000_000; g.i64 = 9_000_000_000_000; g.dbl = 3.25; g.flt = 1.5; g.flag = false
    g.boxed = 42; g.name = "Widget ✓"; g.when = when; g.blob = Data([1, 2, 3]); g.uuid = uuid
    g.link = URL(string: "https://example.com/a?b=c"); g.dec = 12.5; g.info = ["k": "v", "n": 3] as NSDictionary
    g.i64 += 1
    check(g.i64 == 9_000_000_000_001 && g.dbl == 3.25 && g.flt == 1.5 && !g.flag, "@NSManaged scalar accessors (Int64, Double, Float, Bool)")
    do { try ctx.save() } catch { check(false, "save: \(error)") }
    check(!g.objectID.isTemporaryID && !ctx.hasChanges && g.objectID.uriRepresentation().absoluteString.hasPrefix("x-coredata://"),
          "save: permanent ID \(g.objectID.uriRepresentation().absoluteString)")
    let uri = g.objectID.uriRepresentation()

    // "relaunch": a new coordinator on the same file
    ctx.reset()
    _ = try? psc.remove(psc.persistentStores[0])
    (psc, ctx) = open()
    let req = NSFetchRequest<Gadget>(entityName: "Gadget")
    let all = (try? ctx.fetch(req)) ?? []
    let r = all.first
    check(all.count == 1 && r !== g, "store reopened: 1 row fetched into a new object")
    check(r?.i16 == -12 && r?.i32 == 1_000_000 && r?.i64 == 9_000_000_000_001 && r?.dbl == 3.25 && r?.flt == 1.5 && r?.flag == false,
          "integers, Double, Float, Bool survive SQLite")
    check(r?.boxed == 42 && r?.name == "Widget ✓" && r?.when == when && r?.blob == Data([1, 2, 3]), "NSNumber, String, Date, Binary survive SQLite")
    check(r?.uuid == uuid && r?.link == URL(string: "https://example.com/a?b=c") && r?.dec?.doubleValue == 12.5, "UUID, URI, Decimal survive SQLite")
    check(r?.info?["k"] as? String == "v" && r?.info?["n"] as? Int == 3, "Transformable (NSSecureUnarchiveFromData) survives SQLite")
    if let oid = psc.managedObjectID(forURIRepresentation: uri) {
        check((try? ctx.existingObject(with: oid)) === r, "managedObjectID(forURIRepresentation:) + existingObject(with:)")
    } else { check(false, "managedObjectID(forURIRepresentation:)") }
    let meta = psc.metadata(for: psc.persistentStores[0])
    check(meta[NSStoreUUIDKey] as? String == psc.persistentStores[0].identifier && psc.persistentStores[0].type == NSSQLiteStoreType, "store metadata: UUID, type")

    // value changes, changedValues, rollback
    r?.name = "Changed"
    check(r?.isUpdated == true && r?.changedValues()["name"] as? String == "Changed" && r?.committedValues(forKeys: ["name"])["name"] as? String == "Widget ✓",
          "changedValues / committedValues(forKeys:)")
    ctx.rollback()
    check(r?.name == "Widget ✓" && !ctx.hasChanges, "rollback restores committed values")

    // KVO on a managed property
    final class Obs: NSObject {
        var seen: [String] = []
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            seen.append("\(keyPath ?? ""):\(change?[.newKey] ?? "nil")")
        }
    }
    let obs = Obs()
    r?.addObserver(obs, forKeyPath: "name", options: [.new], context: nil)
    r?.name = "Observed"
    r?.removeObserver(obs, forKeyPath: "name")
    check(obs.seen == ["name:Observed"], "KVO on an @NSManaged property: \(obs.seen)")
    ctx.rollback()

    // ObservableObject: objectWillChange fires for a modeled property
    var fired = 0
    let sub = r?.objectWillChange.sink { fired += 1 }
    r?.i32 = 5
    check(fired == 1, "NSManagedObject.objectWillChange (ObservableObject) fires on set")
    sub?.cancel()
    ctx.rollback()

    // in-memory stores
    let mem = NSPersistentStoreCoordinator(managedObjectModel: model)
    let s1 = try? mem.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
    let mctx = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    mctx.persistentStoreCoordinator = mem
    let mg = NSEntityDescription.insertNewObject(forEntityName: "Gadget", into: mctx) as? Gadget
    mg?.name = "mem"
    try? mctx.save()
    mctx.reset()
    check(s1?.type == NSInMemoryStoreType && (try? mctx.count(for: NSFetchRequest<Gadget>(entityName: "Gadget"))) == 1,
          "NSInMemoryStoreType: insertNewObject(forEntityName:into:), save, count")
    let devnull = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
    let c2 = NSPersistentContainer(name: "Gadgets", managedObjectModel: model)
    c2.persistentStoreDescriptions = [devnull]
    var loadError: Error?
    c2.loadPersistentStores { _, e in loadError = e }
    check(loadError == nil && (try? c2.viewContext.count(for: NSFetchRequest<Gadget>(entityName: "Gadget"))) == 0, "/dev/null SQLite store is an empty in-memory store")
}

func compiledModelTests() {
    let momd = Bundle.main.url(forResource: "TestModel", withExtension: "momd")
    check(momd != nil, "isim momc compiled TestModel.momd into the bundle")
    let v1 = momd.flatMap { NSManagedObjectModel(contentsOf: $0.appendingPathComponent("TestModel.mom")) }
    let current = momd.flatMap { NSManagedObjectModel(contentsOf: $0) }
    check(v1?.entitiesByName.count == 2 && v1?.versionIdentifiers.contains("v1") == true, "model version 1 (.mom) loads")
    check(current?.entitiesByName.count == 5 && current?.versionIdentifiers.contains("v2") == true, "momd loads the current version (.xccurrentversion)")
    guard let m = current else { return }
    let book = m.entitiesByName["Book"]!, novel = m.entitiesByName["Novel"]!, shelf = m.entitiesByName["Shelf"]!
    check(novel.superentity === book && book.subentities.contains(novel) && novel.attributesByName["title"] != nil, "entity inheritance (Novel : Book)")
    let auth = book.relationshipsByName["author"]!
    check(auth.inverseRelationship?.name == "books" && auth.deleteRule == .nullifyDeleteRule && !auth.isToMany &&
          auth.inverseRelationship?.deleteRule == .cascadeDeleteRule && auth.inverseRelationship?.isToMany == true, "relationships, inverses, delete rules")
    check(shelf.relationshipsByName["featured"]?.isOrdered == true && shelf.relationshipsByName["books"]?.deleteRule == .denyDeleteRule, "ordered relationship, deny rule")
    let pages = book.attributesByName["pages"]!
    check(pages.attributeType == .integer32AttributeType && (pages.defaultValue as? NSNumber)?.intValue == 0 && book.attributesByName["tags"]?.attributeType == .transformableAttributeType,
          "attribute types and defaults from the .xcdatamodel")
    check(m.fetchRequestTemplate(forName: "LongBooks")?.predicate?.predicateFormat == "pages > 300", "fetch request template")
    check(m.entitiesByName["Publisher"]?.propertiesByName["authorsA"] is NSFetchedPropertyDescription, "fetched property")
    check(NSClassFromString("Author") == Author.self && (Author.fetchRequest() as NSFetchRequest<Author>).entityName == "Author", "codegen (class): @objc(Author) class + fetchRequest()")
}
