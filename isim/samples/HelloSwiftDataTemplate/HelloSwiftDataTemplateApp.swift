// Sample: Xcode's iOS App template with SwiftData storage (issue #227): the app's shared ModelContainer from a
// Schema and a ModelConfiguration, ContentView's @Query list with add and delete, and #Preview's in-memory container.
// At launch it also logs "sd" lines: fetches with a predicate, sort, offset and limit, rollback and delete(model:where:).
import SwiftUI
import SwiftData

@main
struct HelloSwiftDataTemplateApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() { MainActor.assumeIsolated { fetchChecks() } }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

func log(_ s: String) { print("sd \(s)"); fflush(stdout) }

@MainActor func fetchChecks() {
    let container = try! ModelContainer(for: Score.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    for (p, n) in [("ana", 30), ("bo", 10), ("cy", 50), ("di", 20), ("ed", 40)] { context.insert(Score(player: p, points: n)) }
    log("schema \(container.schema.entityNames) configs=\(container.configurations.count) memory=\(container.configurations[0].isStoredInMemoryOnly)")
    func names(_ d: FetchDescriptor<Score>) -> String { ((try? context.fetch(d)) ?? []).map(\.player).joined(separator: ",") }
    log("insertion-order \(names(FetchDescriptor<Score>()))")
    log("sorted \(names(FetchDescriptor(sortBy: [SortDescriptor(\Score.points, order: .reverse)])))")
    log("filtered \(names(FetchDescriptor(predicate: #Predicate<Score> { $0.points >= 30 }, sortBy: [SortDescriptor(\Score.player)])))")
    var page = FetchDescriptor<Score>(sortBy: [SortDescriptor(\Score.points)])
    page.fetchOffset = 1; page.fetchLimit = 2
    log("page \(names(page)) count=\((try? context.fetchCount(FetchDescriptor<Score>())) ?? -1)")
    try? context.save()
    context.insert(Score(player: "fay", points: 60))
    if let bo = try? context.fetch(FetchDescriptor(predicate: #Predicate<Score> { $0.player == "bo" })).first { context.delete(bo) }
    context.rollback()
    log("rollback \(names(FetchDescriptor<Score>())) changes=\(context.hasChanges)")
    try? context.delete(model: Score.self, where: #Predicate { $0.points < 25 })
    log("delete-where \(names(FetchDescriptor<Score>()))")
    let first = try! context.fetch(FetchDescriptor<Score>()).first!
    log("identity id=\(first.id == first.persistentModelID) context=\(first.modelContext === context) hashable=\(Set([first, first]).count)")
}
