// CloudKit share links in a Swift app (CloudKitShareSwiftTest, issue #575): a scene-based UIKit app. On a normal launch
// it saves a share in its container and logs the link; relaunched with the link (isim-cloudkit-share:<link>, as the home
// screen does), it reads UIScene.ConnectionOptions.cloudKitShareMetadata (CKShare.Metadata) and accepts the share.
import UIKit
import CloudKit

func say(_ s: String) { NSLog("CKShareLinkSwift: %@", s) }

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        say("launch options key \(UIApplication.LaunchOptionsKey.cloudKitShareMetadata.rawValue)")
        return true
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let w = UIWindow(windowScene: scene as! UIWindowScene)
        w.rootViewController = UIViewController()
        w.makeKeyAndVisible()
        window = w
        let container = CKContainer.default()
        if let metadata: CKShare.Metadata = connectionOptions.cloudKitShareMetadata {
            say("scene options share \(metadata.share.recordID.recordName) role \(metadata.participantRole.rawValue)")
            Task {
                let share = try await container.accept(metadata)
                say("accepted \(type(of: share)) public \(share.publicPermission.rawValue)")
            }
            return
        }
        say("scene options share none")
        Task {
            let zone = CKRecordZone(zoneName: "Shared")
            _ = try await container.privateCloudDatabase.save(zone)
            let root = CKRecord(recordType: "List", recordID: CKRecord.ID(recordName: "todo", zoneID: zone.zoneID))
            let share = CKShare(rootRecord: root)
            share.publicPermission = .readOnly
            let (saved, _) = try await container.privateCloudDatabase.modifyRecords(saving: [root, share], deleting: [])
            let url = saved.compactMap { try? $0.1.get() as? CKShare }.first?.url
            say("share url \(url?.absoluteString ?? "nil")")
        }
    }
}
