import CoreData

/// Like Xcode's "Use Core Data" template: one NSPersistentContainer named after the model, with persistent history
/// tracking on (the history is kept in the store's file, so each launch sees the earlier launches' transactions),
/// remote change notifications, an asynchronous fetch at launch, and the items' titles indexed in Spotlight.
struct PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer
    let spotlight: NSCoreDataCoreSpotlightDelegate

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HelloCoreData")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        let description = container.persistentStoreDescriptions.first!
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.loadPersistentStores { description, error in
            if let error = error as NSError? { fatalError("Unresolved error \(error), \(error.userInfo)") }
            print("store loaded \(description.url?.lastPathComponent ?? "?")")
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.transactionAuthor = "app"
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: nil as NSPersistentHistoryToken?)
        let history = ((try? container.viewContext.execute(request)) as? NSPersistentHistoryResult)?.result as? [NSPersistentHistoryTransaction] ?? []
        print("launch history \(history.count) transactions, authors \(Set(history.compactMap(\.author)).sorted().joined(separator: ","))")
        let count = (try? container.viewContext.count(for: Item.fetchRequest() as NSFetchRequest<Item>)) ?? -1
        print("launch items \(count)")
        let asyncFetch = NSAsynchronousFetchRequest(fetchRequest: Item.fetchRequest() as NSFetchRequest<Item>) { result in
            print("async fetch \(result.finalResult?.count ?? -1) items")
        }
        _ = try? container.viewContext.execute(asyncFetch)
        NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator, queue: nil) { note in
            print("remote change \((note.userInfo?[NSPersistentStoreURLKey] as? URL)?.lastPathComponent ?? "?"), history token \(note.userInfo?[NSPersistentHistoryTokenKey] != nil)")
        }
        spotlight = NSCoreDataCoreSpotlightDelegate(forStoreWith: description, coordinator: container.persistentStoreCoordinator)
        NotificationCenter.default.addObserver(forName: .NSCoreDataCoreSpotlightDelegateIndexDidUpdate, object: spotlight, queue: nil) { _ in
            print("spotlight index updated")
        }
        spotlight.startSpotlightIndexing()
    }
}
