// Sample: isim's local CloudKit (no iCloud sync) and MetricKit. Saves typed records, queries with predicates,
// sort descriptors and cursors, fetches, a serverRecordChanged conflict and its resolution, an atomic batch in a
// custom zone, change tokens, cascading deletes, subscriptions with in-process push delivery to the app delegate,
// NSPersistentCloudKitContainer, and MetricKit payloads (delivered by the `metrickit` script command / `isim metrickit`).
// Results are printed for tests/ui/cloudkit.sh.
import UIKit
import CloudKit
import CoreData
import CoreLocation
import MetricKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, MXMetricManagerSubscriber {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: CloudViewController())
        window?.makeKeyAndVisible()
        MXMetricManager.shared.add(self)
        print("metrickit: subscribed, past payloads \(MXMetricManager.shared.pastPayloads.count)")
        return true
    }
    // CloudKit subscription pushes (isim: delivered in-process)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let n = CKNotification(fromRemoteNotificationDictionary: userInfo) else { completionHandler(.noData); return }
        if n.notificationType == .query, let q = CKQueryNotification(fromRemoteNotificationDictionary: userInfo) {
            let reason = [1: "created", 2: "updated", 3: "deleted"][q.queryNotificationReason.rawValue] ?? "?"
            print("push: query subscription=\(n.subscriptionID ?? "-") reason=\(reason) record=\(q.recordID?.recordName ?? "-") title=\(q.recordFields?["title"] as? String ?? "-") alert=\(n.alertBody ?? "-")")
        } else {
            print("push: \(n.notificationType == .database ? "database" : "zone") subscription=\(n.subscriptionID ?? "-")")
        }
        completionHandler(.newData)
    }
    func didReceive(_ payloads: [MXMetricPayload]) {
        for p in payloads {
            let json = String(decoding: p.jsonRepresentation(), as: UTF8.self)
            print("metrickit: metric payload app=\(p.latestApplicationVersion) cpu=\(p.cpuMetrics.map { "\($0.cumulativeCPUTime.value) \($0.cumulativeCPUTime.unit.symbol)" } ?? "-") peakMemory=\(p.memoryMetrics?.peakMemoryUsage.value ?? -1) launchBuckets=\(p.applicationLaunchMetrics?.histogrammedTimeToFirstDraw.totalBucketCount ?? 0) exits=\(p.applicationExitMetrics?.foregroundExitData.cumulativeNormalAppExitCount ?? -1) json=\(json.contains("\"cpuMetrics\"") && json.contains("\"cumulativeCPUTime\" : \"100 s\""))")
        }
    }
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for p in payloads {
            let c = p.crashDiagnostics?.first
            print("metrickit: diagnostic payload crashes=\(p.crashDiagnostics?.count ?? 0) signal=\(c?.signal?.intValue ?? -1) hangs=\(p.hangDiagnostics?.count ?? 0) callStack=\(c.map { $0.callStackTree.jsonRepresentation().count > 20 } ?? false) json=\(String(decoding: p.jsonRepresentation(), as: UTF8.self).contains("crashDiagnostics"))")
        }
    }
}

final class CloudViewController: UIViewController {
    let container = CKContainer.default()
    var db: CKDatabase { container.privateCloudDatabase }
    let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CloudKit"
        view.backgroundColor = .systemGroupedBackground
        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        status.text = "local CloudKit · no iCloud sync"; status.textColor = .secondaryLabel; status.textAlignment = .center
        status.accessibilityIdentifier = "status"
        stack.addArrangedSubview(status)
        for (title, id, action) in [("Save notes", "save", save), ("Query (paged)", "query", query), ("Fetch typed values", "fetch", fetch),
                                    ("Conflict + resolve", "conflict", conflict), ("Subscribe + push", "subscribe", subscribe),
                                    ("Zone, atomic batch, changes", "zone", zone), ("Delete (cascade)", "delete", delete),
                                    ("Core Data + CloudKit container", "coredata", coreData), ("List records", "list", list)] as [(String, String, () -> Void)] {
            var cfg = UIButton.Configuration.filled()
            cfg.title = title
            let b = UIButton(configuration: cfg, primaryAction: UIAction { _ in action() })
            b.accessibilityIdentifier = id
            b.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(b)
        }
        Task {
            let s = try? await container.accountStatus()
            let names = [0: "couldNotDetermine", 1: "available", 2: "restricted", 3: "noAccount", 4: "temporarilyUnavailable"]
            print("container: \(container.containerIdentifier ?? "-") account=\(names[s?.rawValue ?? 0] ?? "?")")
            do { let id = try await container.userRecordID(); print("user record: \(id.recordName.hasPrefix("_"))") }
            catch { print("user record error: \(code(error))") }
            status.text = "account: \(names[s?.rawValue ?? 0] ?? "?")"
        }
    }

    func code(_ e: Error) -> String {
        if let ck = e as? CKError { return "CKError \(ck.code.rawValue)" }
        return "\((e as NSError).domain) \((e as NSError).code)"
    }
    func note(_ name: String, _ title: String, _ count: Int, zone: CKRecordZone.ID = .default) -> CKRecord {
        let r = CKRecord(recordType: "Note", recordID: CKRecord.ID(recordName: name, zoneID: zone))
        r["title"] = title
        r["count"] = count
        r["rating"] = Double(count) + 0.5
        r["tags"] = ["isim", "note\(count)"]
        r["created"] = Date(timeIntervalSince1970: 1_700_000_000 + Double(count))
        r["blob"] = Data([1, 2, 3, UInt8(count)])
        r["place"] = CLLocation(latitude: 37.33 + Double(count), longitude: -122.0)
        return r
    }

    func save() {
        Task {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("photo.txt")
            try? Data("asset bytes".utf8).write(to: file)
            let recs = [note("n1", "First", 1), note("n2", "Second", 2), note("n3", "Third", 3)]
            recs[0]["photo"] = CKAsset(fileURL: file)
            recs[1]["parent"] = CKRecord.Reference(recordID: recs[0].recordID, action: .deleteSelf)
            do {
                let (saved, _) = try await db.modifyRecords(saving: recs, deleting: [], savePolicy: .allKeys)
                let ok = saved.values.filter { if case .success = $0 { return true } else { return false } }.count
                let tag = (try? saved[recs[0].recordID]?.get())?.recordChangeTag
                print("saved \(ok) notes; changeTag=\(tag != nil) changedKeys(before)=\(recs[0].changedKeys().count)")
            } catch { print("save error: \(code(error))") }
        }
    }

    func query() {
        let q = CKQuery(recordType: "Note", predicate: NSPredicate(format: "count >= %d", 2))
        q.sortDescriptors = [NSSortDescriptor(key: "count", ascending: false)]
        let op = CKQueryOperation(query: q)
        op.resultsLimit = 1
        var page1: [String] = []
        op.recordMatchedBlock = { _, r in if let rec = try? r.get() { page1.append(rec["title"] as? String ?? "?") } }
        op.queryResultBlock = { [db] result in
            guard case .success(let cursor) = result, let cursor else { print("query error or no cursor: \(result)"); return }
            print("query page 1: \(page1.joined(separator: ",")) cursor=true")
            Task {
                let (rest, more) = try await db.records(continuingMatchFrom: cursor)
                print("query page 2: \(rest.compactMap { try? $0.1.get()["title"] as? String }.joined(separator: ",")) more=\(more != nil)")
                let all = try await db.records(matching: CKQuery(recordType: "Note", predicate: NSPredicate(format: "title BEGINSWITH %@ OR tags CONTAINS %@", "Fi", "note3")))
                print("query or/contains: \(all.matchResults.compactMap { try? $0.1.get()["title"] as? String }.sorted().joined(separator: ","))")
                do { _ = try await db.records(matching: CKQuery(recordType: "Missing", predicate: NSPredicate(value: true))) }
                catch { print("query unknown type: \(self.code(error))") }
            }
        }
        db.add(op)
    }

    func fetch() {
        Task {
            do {
                let r = try await db.record(for: CKRecord.ID(recordName: "n1"))
                let loc = r["place"] as? CLLocation
                let asset = r["photo"] as? CKAsset
                let assetText = asset?.fileURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "-"
                print("fetched: title=\(r["title"] as? String ?? "-") count=\(r["count"] as? Int ?? -1) rating=\(r["rating"] as? Double ?? -1) tags=\((r["tags"] as? [String])?.joined(separator: "+") ?? "-") created=\((r["created"] as? Date)?.timeIntervalSince1970 ?? 0) blob=\((r["blob"] as? Data)?.count ?? 0) lat=\(loc.map { String(format: "%.2f", $0.coordinate.latitude) } ?? "-") asset=\(assetText) type=\(r.recordType) dates=\(r.creationDate != nil && r.modificationDate != nil)")
                let coder = NSKeyedArchiver(requiringSecureCoding: true)
                r.encodeSystemFields(with: coder)
                let un = try NSKeyedUnarchiver(forReadingFrom: coder.encodedData)
                let sys = CKRecord(coder: un)
                print("system fields: \(sys?.recordID.recordName ?? "-") tag=\(sys?.recordChangeTag == r.recordChangeTag) keys=\(sys?.allKeys().count ?? -1)")
                do { _ = try await db.record(for: CKRecord.ID(recordName: "nope")) } catch CKError.unknownItem { print("fetch missing: unknownItem") }
            } catch { print("fetch error: \(code(error))") }
        }
    }

    func conflict() {
        Task {
            do {
                let a = try await db.record(for: CKRecord.ID(recordName: "n2"))
                let b = try await db.record(for: CKRecord.ID(recordName: "n2"))
                a["title"] = "Second (phone)"
                _ = try await db.save(a)
                b["title"] = "Second (stale)"
                do { _ = try await db.save(b) } catch let e as CKError where e.code == .serverRecordChanged {
                    let server = e.serverRecord!
                    print("conflict: serverRecordChanged server=\(server["title"] as? String ?? "-") client=\(e.clientRecord?["title"] as? String ?? "-")")
                    server["title"] = "Second (merged)"
                    let merged = try await db.save(server)
                    print("conflict resolved: \(merged["title"] as? String ?? "-")")
                }
                // changedKeys policy: only the changed key is written over the server's version
                let c = CKRecord(recordType: "Note", recordID: CKRecord.ID(recordName: "n2"))
                c["count"] = 20
                let op = CKModifyRecordsOperation(recordsToSave: [c], recordIDsToDelete: nil)
                op.savePolicy = .changedKeys
                op.perRecordSaveBlock = { _, r in if let s = try? r.get() { print("changedKeys save: title=\(s["title"] as? String ?? "-") count=\(s["count"] as? Int ?? -1)") } }
                db.add(op)
            } catch { print("conflict error: \(code(error))") }
        }
    }

    func subscribe() {
        Task {
            do {
                let sub = CKQuerySubscription(recordType: "Note", predicate: NSPredicate(format: "title BEGINSWITH %@", "Urgent"), subscriptionID: "urgent-notes",
                                              options: [.firesOnRecordCreation, .firesOnRecordUpdate])
                let info = CKSubscription.NotificationInfo()
                info.alertBody = "An urgent note changed"; info.shouldSendContentAvailable = true; info.desiredKeys = ["title"]
                sub.notificationInfo = info
                _ = try await db.save(sub)
                _ = try await db.save(CKDatabaseSubscription(subscriptionID: "everything"))
                let subs = try await db.allSubscriptions()
                print("subscriptions: \(subs.map { $0.subscriptionID }.sorted().joined(separator: ","))")
                _ = try await db.save(note("u1", "Urgent: call back", 9))
                _ = try await db.save(note("p1", "Plain", 10))
            } catch { print("subscribe error: \(code(error))") }
        }
    }

    func zone() {
        Task {
            do {
                let work = CKRecordZone(zoneName: "Work")
                _ = try await db.save(work)
                let zones = try await db.allRecordZones()
                print("zones: \(zones.map { $0.zoneID.zoneName }.joined(separator: ","))")
                let good = note("w1", "Plan", 1, zone: work.zoneID)
                let bad = note("w2", "Broken", 2, zone: work.zoneID)
                bad["photo"] = CKAsset(fileURL: URL(fileURLWithPath: "/nonexistent/file.png"))
                let (results, _) = try await db.modifyRecords(saving: [good, bad], deleting: [], atomically: true)
                let codes = [good, bad].map { r -> String in
                    if case .failure(let e) = results[r.recordID]! { return code(e) } else { return "ok" }
                }
                print("atomic batch: \(codes.joined(separator: ","))")
                _ = try await db.modifyRecords(saving: [note("w1", "Plan", 1, zone: work.zoneID), note("w3", "Ship", 3, zone: work.zoneID)], deleting: [])
                var token: CKServerChangeToken?
                var changed: [String] = []
                let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: [work.zoneID], configurationsByRecordZoneID: nil)
                op.recordWasChangedBlock = { id, _ in changed.append(id.recordName) }
                op.recordZoneFetchResultBlock = { [db] _, r in
                    token = try? r.get().serverChangeToken
                    print("zone changes: \(changed.sorted().joined(separator: ","))")
                    Task {
                        _ = try await db.deleteRecord(withID: CKRecord.ID(recordName: "w3", zoneID: work.zoneID))
                        let cfg = CKFetchRecordZoneChangesOperation.ZoneConfiguration(previousServerChangeToken: token)
                        let op2 = CKFetchRecordZoneChangesOperation(recordZoneIDs: [work.zoneID], configurationsByRecordZoneID: [work.zoneID: cfg])
                        var deleted: [String] = [], changed2: [String] = []
                        op2.recordWasChangedBlock = { id, _ in changed2.append(id.recordName) }
                        op2.recordWithIDWasDeletedBlock = { id, type in deleted.append("\(id.recordName):\(type)") }
                        op2.fetchRecordZoneChangesResultBlock = { _ in print("zone changes since token: changed=\(changed2.count) deleted=\(deleted.joined(separator: ","))") }
                        db.add(op2)
                    }
                }
                db.add(op)
            } catch { print("zone error: \(code(error))") }
        }
    }

    func delete() {
        Task {
            do {
                try await db.deleteRecord(withID: CKRecord.ID(recordName: "n1"))
                let left = try await db.records(for: [CKRecord.ID(recordName: "n1"), CKRecord.ID(recordName: "n2")])
                let state = ["n1", "n2"].map { n -> String in
                    if case .failure(let e) = left[CKRecord.ID(recordName: n)]! { return "\(n)=\(code(e))" } else { return "\(n)=present" }
                }
                print("deleted n1 (cascade): \(state.joined(separator: " "))")
            } catch { print("delete error: \(code(error))") }
        }
    }

    func list() {
        Task {
            do {
                let all = try await db.records(matching: CKQuery(recordType: "Note", predicate: NSPredicate(value: true)))
                print("records: \(all.matchResults.compactMap { try? $0.1.get().recordID.recordName }.sorted().joined(separator: ","))")
            } catch { print("list error: \(code(error))") }
        }
    }

    func coreData() {
        let e = NSEntityDescription(); e.name = "Item"; e.managedObjectClassName = "NSManagedObject"
        let a = NSAttributeDescription(); a.name = "name"; a.attributeType = .stringAttributeType; a.isOptional = true
        e.properties = [a]
        let m = NSManagedObjectModel(); m.entities = [e]
        let c = NSPersistentCloudKitContainer(name: "Items", managedObjectModel: m)
        let d = c.persistentStoreDescriptions.first!
        d.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.dev.isim.samples.HelloCloudKit")
        d.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        c.loadPersistentStores { desc, err in
            print("coredata store: loaded=\(err == nil) options=\(desc.cloudKitContainerOptions?.containerIdentifier ?? "-")")
        }
        try? c.initializeCloudKitSchema(options: .dryRun)
        let obj = NSEntityDescription.insertNewObject(forEntityName: "Item", into: c.viewContext)
        obj.setValue("Synced locally", forKey: "name")
        try? c.viewContext.save()
        let n = (try? c.viewContext.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "Item"))) ?? -1
        print("coredata: items=\(n) isContainer=\((c as NSPersistentContainer) is NSPersistentCloudKitContainer)")
    }
}
