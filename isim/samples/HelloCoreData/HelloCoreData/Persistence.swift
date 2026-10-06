import CoreData

/// Like Xcode's "Use Core Data" template: one NSPersistentContainer named after the model.
struct PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HelloCoreData")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { description, error in
            if let error = error as NSError? { fatalError("Unresolved error \(error), \(error.userInfo)") }
            print("store loaded \(description.url?.lastPathComponent ?? "?")")
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        let count = (try? container.viewContext.count(for: Item.fetchRequest() as NSFetchRequest<Item>)) ?? -1
        print("launch items \(count)")
    }
}
