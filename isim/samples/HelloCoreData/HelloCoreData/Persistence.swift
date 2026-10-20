import CoreData

/// Like Xcode's "Use Core Data" template: one NSPersistentContainer named after the model, with persistent history
/// tracking on (the history is kept in the store's file, so each launch sees the earlier launches' transactions).
struct PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HelloCoreData")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.persistentStoreDescriptions.first!.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
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
    }
}
