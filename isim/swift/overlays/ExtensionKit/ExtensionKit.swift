// isim ExtensionKit (partial): AppExtensionScene, the scene protocol that frameworks' extension scenes refine
// (DeviceActivity's DeviceActivityReportScene, issue #409). Hosting an app extension's scene in another app's view
// (EXHostViewController, AppExtensionSceneConfiguration, PrimitiveAppExtensionScene) is not in isim yet.
import Foundation

@MainActor @preconcurrency public protocol AppExtensionScene {}
