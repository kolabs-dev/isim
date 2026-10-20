// Sample: SwiftData persistence on isim — models in the on-disk store (Application Support/default.store) that
// survive a relaunch: attributes (Codable structs, enums, arrays, optionals, dates), relationships with inverses
// (named and inferred), delete rules (cascade, nullify, deny), @Attribute(.unique) and #Unique upserts, #Index,
// @Transient, a second ModelContext on the same store, rollback, the didSave notification, and an @Query list that
// refreshes when a model's property changes. The first launch seeds the store; later launches check what it kept.
// Every step is printed ("sd2 ..."), so tests/ui/test_swiftdata.py can check it.
import SwiftUI
import SwiftData

struct Budget: Codable, Hashable { var amount: Double; var currency: String }
enum Kind: String, Codable { case work, leisure }

@Model final class Trip {
    #Unique<Trip>([\.name])
    #Index<Trip>([\.start], [\.name, \.start])
    var name: String
    var start: Date
    var kind: Kind
    var budget: Budget
    var tags: [String] = []
    var note: String?
    @Relationship(deleteRule: .cascade, inverse: \Stop.trip) var stops: [Stop] = []
    var traveler: Traveler?
    @Transient var views = 0
    init(name: String, start: Date, kind: Kind, budget: Budget) {
        self.name = name; self.start = start; self.kind = kind; self.budget = budget
    }
}

@Model final class Stop {
    var place: String
    var order: Int
    var trip: Trip?
    init(place: String, order: Int) { self.place = place; self.order = order }
}

@Model final class Traveler {
    @Attribute(.unique) var email: String
    var name: String
    @Relationship(deleteRule: .deny) var trips: [Trip] = []
    init(email: String, name: String) { self.email = email; self.name = name }
}

func log(_ s: String) { print("sd2 \(s)"); fflush(stdout) }
let day: TimeInterval = 86_400
let epoch = Date(timeIntervalSince1970: 1_800_000_000)

@MainActor func describe(_ c: ModelContext) -> String {
    let trips = (try? c.fetch(FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.start)]))) ?? []
    return trips.map { t in
        "\(t.name)[\(t.kind.rawValue) \(Int(t.budget.amount))\(t.budget.currency) tags=\(t.tags.joined(separator: "+")) note=\(t.note ?? "-") " +
            "stops=\(t.stops.sorted { $0.order < $1.order }.map(\.place).joined(separator: ">")) by=\(t.traveler?.name ?? "-")]"
    }.joined(separator: " ")
}

@MainActor func seed(_ c: ModelContext) {
    let ana = Traveler(email: "ana@example.com", name: "Ana"), bo = Traveler(email: "bo@example.com", name: "Bo")
    let lisbon = Trip(name: "Lisbon", start: epoch, kind: .leisure, budget: Budget(amount: 900, currency: "EUR"))
    let tokyo = Trip(name: "Tokyo", start: epoch + 30 * day, kind: .work, budget: Budget(amount: 3000, currency: "JPY"))
    tokyo.tags = ["conference", "spring"]; tokyo.note = "keynote"
    c.insert(lisbon); c.insert(tokyo)
    // relationships set either side keep their inverses
    let alfama = Stop(place: "Alfama", order: 1), belem = Stop(place: "Belem", order: 2)
    lisbon.stops.append(alfama)
    belem.trip = lisbon
    tokyo.stops = [Stop(place: "Shibuya", order: 1)]
    lisbon.traveler = ana
    bo.trips.append(tokyo)
    log("inverses: alfama.trip=\(alfama.trip?.name ?? "-") lisbon.stops=\(lisbon.stops.count) ana.trips=\(ana.trips.map(\.name)) tokyo.traveler=\(tokyo.traveler?.name ?? "-") bo inserted=\(bo.modelContext != nil)")
    try! c.save()
    // uniqueness: the same name (and email) updates the stored model
    c.insert(Trip(name: "Lisbon", start: epoch, kind: .leisure, budget: Budget(amount: 1200, currency: "EUR")))
    c.insert(Traveler(email: "ana@example.com", name: "Ana Silva"))
    try! c.save()
    let trips = (try? c.fetchCount(FetchDescriptor<Trip>())) ?? -1, people = (try? c.fetchCount(FetchDescriptor<Traveler>())) ?? -1
    log("upsert: trips=\(trips) travelers=\(people)")
    log("seeded: \(describe(c))")
}

@MainActor func check(_ container: ModelContainer) {
    let c = container.mainContext
    log("relaunch: \(describe(c))")
    let byStart = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.start)])
    let first = try! c.fetch(byStart).first!
    log("identity: same=\(first === (try! c.fetch(byStart).first!)) id=\(first.persistentModelID.entityName) temporary=\(first.persistentModelID.isTemporary) transient=\(first.views)")
    // another context on the same store
    let other = ModelContext(container)
    other.insert(Trip(name: "Oslo", start: epoch + 60 * day, kind: .leisure, budget: Budget(amount: 500, currency: "NOK")))
    var saved = 0
    let o = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: other, queue: nil) { n in
        saved = (n.userInfo?[ModelContext.NotificationKey.insertedIdentifiers.rawValue] as? [PersistentIdentifier])?.count ?? -1
    }
    try! other.save()
    NotificationCenter.default.removeObserver(o)
    log("other context: inserted=\(saved) main sees=\(describe(c).contains("Oslo"))")
    // deny: a traveler with trips cannot be deleted
    let ana = try! c.fetch(FetchDescriptor<Traveler>(predicate: #Predicate { $0.email == "ana@example.com" })).first!
    c.delete(ana)
    do { try c.save(); log("deny: saved?!") } catch {
        log("deny: \(error) still=\(c.hasChanges)")
        c.rollback()
        log("rollback: ana=\(ana.name) trips=\(ana.trips.map(\.name)) changes=\(c.hasChanges)")
    }
    // cascade: the trip's stops go with it; nullify: Bo's trips lose it
    guard let tokyo = try! c.fetch(FetchDescriptor<Trip>(predicate: #Predicate { $0.name == "Tokyo" })).first, let bo = tokyo.traveler else {
        log("cascade: Tokyo was deleted on an earlier launch"); return
    }
    c.delete(tokyo)
    try! c.save()
    log("cascade: stops=\((try? c.fetchCount(FetchDescriptor<Stop>())) ?? -1) bo.trips=\(bo.trips.map(\.name)) trips=\(describe(c))")
}

@main struct HelloSwiftDataApp: App {
    let container: ModelContainer = {
        let schema = Schema([Trip.self])
        let c = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
        let config = c.configurations.first!
        log("schema: \(schema.entities.map(\.name).sorted()) unique=\(schema.entitiesByName["Trip"]!.uniquenessConstraints) " +
            "indices=\(schema.entitiesByName["Trip"]!.indices) store=\(config.url.lastPathComponent) memory=\(config.isStoredInMemoryOnly)")
        return c
    }()

    init() {
        let c = container
        MainActor.assumeIsolated {
            let empty = ((try? c.mainContext.fetchCount(FetchDescriptor<Trip>())) ?? 0) == 0
            if empty { seed(c.mainContext) } else { check(c) }
            log("store file: \(FileManager.default.fileExists(atPath: c.configurations.first!.url.path))")
        }
    }

    var body: some Scene {
        WindowGroup { TripList() }
            .modelContainer(container)
    }
}

struct TripList: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.start) private var trips: [Trip]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(trips) { t in
                Text("\(t.name): \(t.stops.count) stops").accessibilityIdentifier("trip-\(t.name)")
            }
            Button("Rename the first trip") {
                trips.first?.name = "Porto"
                log("renamed: \(trips.map(\.name))")
            }
            .accessibilityIdentifier("rename")
        }
        .padding()
    }
}
