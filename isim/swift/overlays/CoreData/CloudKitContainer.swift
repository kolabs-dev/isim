// NSPersistentCloudKitContainer on isim: an NSPersistentContainer that keeps the store on the device and does NOT
// mirror it to CloudKit (no iCloud sync; isim's CloudKit is local too). Apps that use it load their stores, save
// and fetch exactly like with NSPersistentContainer; cloudKitContainerOptions are accepted and remembered.
import Foundation

open class NSPersistentCloudKitContainerOptions: NSObject {
    public let containerIdentifier: String
    /// CKDatabase.Scope raw value (2 = private, the default; 1 = public, 3 = shared)
    open var databaseScopeRawValue: Int = 2
    public init(containerIdentifier: String) { self.containerIdentifier = containerIdentifier }
}

let _isimCloudKitOptionsKey = "NSPersistentCloudKitContainerOptionsKey"

extension NSPersistentStoreDescription {
    /// the CloudKit container the store would mirror to (isim: remembered, not mirrored)
    public var cloudKitContainerOptions: NSPersistentCloudKitContainerOptions? {
        get { options[_isimCloudKitOptionsKey] as? NSPersistentCloudKitContainerOptions }
        set { setOption(newValue, forKey: _isimCloudKitOptionsKey) }
    }
}

open class NSPersistentCloudKitContainer: NSPersistentContainer {
    public struct SchemaInitializationOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let dryRun = SchemaInitializationOptions(rawValue: 1 << 1)
        public static let printSchema = SchemaInitializationOptions(rawValue: 1 << 2)
    }
    public static let eventChangedNotification = Notification.Name("NSPersistentCloudKitContainerEventChangedNotification")
    nonisolated(unsafe) static var logged = false

    public override init(name: String, managedObjectModel model: NSManagedObjectModel) {
        super.init(name: name, managedObjectModel: model)
        for d in persistentStoreDescriptions where d.cloudKitContainerOptions == nil {
            d.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud." + (Bundle.main.bundleIdentifier ?? "app"))
        }
        if !NSPersistentCloudKitContainer.logged {
            NSPersistentCloudKitContainer.logged = true
            NSLog("isim CoreData: NSPersistentCloudKitContainer \"%@\" keeps its store on the device (local, no iCloud sync)", name)
        }
    }

    /// nothing to create in a local container; logs what iOS would upload
    open func initializeCloudKitSchema(options: SchemaInitializationOptions = []) throws {
        let entities = managedObjectModel.entities.compactMap { $0.name }.sorted()
        NSLog("isim CoreData: initializeCloudKitSchema: %d record types (CD_%@) — local, nothing uploaded", entities.count, entities.joined(separator: ", CD_"))
    }
    open func canUpdateRecord(forManagedObjectWith objectID: NSManagedObjectID) -> Bool { true }
    open func canDeleteRecord(forManagedObjectWith objectID: NSManagedObjectID) -> Bool { true }
    open func canModifyManagedObjects(in store: NSPersistentStore) -> Bool { true }
}
