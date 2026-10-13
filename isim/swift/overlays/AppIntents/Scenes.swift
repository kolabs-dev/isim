// isim AppIntents: app intents directed to UIKit scenes (iOS 26, "Directing app intents to your app's scenes").
// Before perform(), an intent adopting TargetContentProvidingIntent or UISceneAppIntent goes to the scene whose
// activation conditions take its contentIdentifier (else the foreground scene). For a UISceneAppIntent, the scene
// delegate's scene(_:willPerformAppIntent:) (AppIntentSceneDelegate) runs, else the intent's
// performNavigation(forScene:); uiScene is that scene while it performs. An app launched to run one has it in its
// launch scene's connectionOptions.appIntent (made from the request, before its parameters are filled in).
import Foundation
import UIKit

/// an intent whose content the system routes to the scene that handles its identifier
public protocol TargetContentProvidingIntent: AppIntent {
    var contentIdentifier: String { get }
}
extension TargetContentProvidingIntent {
    /// the intent type's name, like Apple's default (the persistent identifier of the type)
    public var contentIdentifier: String { String(describing: Self.self) }
}
/// an intent directed to a UIKit scene
public protocol UISceneAppIntent: TargetContentProvidingIntent {
    var uiScene: UIScene? { get }
    @MainActor func performNavigation(forScene scene: UIScene)
}
extension UISceneAppIntent {
    public var uiScene: UIScene? { MainActor.assumeIsolated { _IsimSceneIntents.current } }
    @MainActor public func performNavigation(forScene scene: UIScene) {}
}
/// a scene delegate that configures its scene for incoming intents
@MainActor public protocol AppIntentSceneDelegate: UISceneDelegate {
    func scene(_ scene: UIScene, willPerformAppIntent appIntent: any UISceneAppIntent)
}

@MainActor enum _IsimSceneIntents {
    static weak var current: UIScene?
    /// the scene for an intent (before perform); nil when the intent is not directed to scenes
    static func route(_ intent: any AppIntent) -> UIScene? {
        guard let t = intent as? any TargetContentProvidingIntent else { return nil }
        let id = t.contentIdentifier
        let scenes = UIApplication.shared.connectedScenes.filter { $0.session.role == .windowApplication }
        let scene = _isimSceneForTarget(id) ?? scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let scene else { return nil }
        NSLog("isim AppIntents: “%@” goes to scene %@ (content %@)", type(of: intent).title.description, scene.session.persistentIdentifier, id)
        guard let si = intent as? any UISceneAppIntent else { return scene }
        current = scene
        if let d = scene.delegate as? AppIntentSceneDelegate { d.scene(scene, willPerformAppIntent: si) }
        else { si.performNavigation(forScene: scene) }
        return scene
    }
    /// the intent an app was launched to run (the isim-intent: launch marker), when it is directed to scenes
    static func launchIntent(_ marker: String?) -> (any UISceneAppIntent)? {
        guard let m = marker, m.hasPrefix("isim-intent:"),
              let req = NSDictionary(contentsOfFile: String(m.dropFirst(12))) as? [String: Any] else { return nil }
        if let i = req["shortcut"] as? Int, let s = _IsimRunner.shortcut(i) { return s._intent as? any UISceneAppIntent }
        if let name = req["intent"] as? String, let t = _IsimRunner.intentType(name) { return t.init() as? any UISceneAppIntent }
        return nil
    }
}
/// the scene whose activation conditions take a target content identifier (UIKit's routing of user activities)
@MainActor func _isimSceneForTarget(_ id: String) -> UIScene? {
    (UIApplication.shared.perform(NSSelectorFromString("_isim_scenesForTargetContentIdentifier:"), with: id).takeUnretainedValue() as? [UIScene])?.first
}

extension UIScene.ConnectionOptions {
    /// the app intent the scene was created for (iOS 26)
    @MainActor public var appIntent: (any UISceneAppIntent)? {
        _IsimSceneIntents.launchIntent(value(forKey: "_isim_launchMarker") as? String)
    }
}
