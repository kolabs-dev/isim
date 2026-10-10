// iOS 26 typed UIKit notification messages (NotificationCenter.MainActorMessage) and their identifiers, e.g.
//     NotificationCenter.default.addObserver(of: UIScreen.self, for: .keyboardWillShow) { message in … message.endFrame … }
// Each wraps the UIKit notification of the same name: makeMessage reads its object and userInfo, makeNotification
// builds it for the notification's observers. Generated (one shape per message, from Apple's declarations); the focus
// system and pointer lock messages come with those types.
import Foundation
import CoreGraphics

@available(iOS 26.0, *)
extension UIApplication {
    public struct DidFinishLaunchingMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.didFinishLaunchingNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIApplication {
    public struct DidBecomeActiveMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.didBecomeActiveNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIApplication {
    public struct DidEnterBackgroundMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.didEnterBackgroundNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIApplication {
    public struct WillEnterForegroundMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.willEnterForegroundNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIApplication {
    public struct WillResignActiveMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.willResignActiveNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIApplication {
    public struct WillTerminateMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.willTerminateNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIApplication {
    public struct DidReceiveMemoryWarningMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.didReceiveMemoryWarningNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIApplication {
    public struct SignificantTimeChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.significantTimeChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIApplication {
    public struct BackgroundRefreshStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.backgroundRefreshStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIApplication {
    public struct UserDidTakeScreenshotMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.userDidTakeScreenshotNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIApplication {
    public struct ProtectedDataWillBecomeUnavailableMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.protectedDataWillBecomeUnavailableNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIApplication {
    public struct ProtectedDataDidBecomeAvailableMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIApplication.protectedDataDidBecomeAvailableNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIDevice {
    public struct BatteryLevelDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIDevice
        public static var name: Foundation.Notification.Name { UIDevice.batteryLevelDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIDevice {
    public struct BatteryStateDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIDevice
        public static var name: Foundation.Notification.Name { UIDevice.batteryStateDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIDevice {
    public struct OrientationDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIDevice
        public static var name: Foundation.Notification.Name { UIDevice.orientationDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIDevice {
    public struct ProximityStateDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIDevice
        public static var name: Foundation.Notification.Name { UIDevice.proximityStateDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIScreen {
    public struct BrightnessDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScreen
        public static var name: Foundation.Notification.Name { UIScreen.brightnessDidChangeNotification }
        public var screen: UIScreen
        public init(screen: UIScreen) { self.screen = screen }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let screen = n.object as? UIScreen else { return nil }
            return Self(screen: screen)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.screen) }
    }
}
@available(iOS 26.0, *)
extension UIScreen {
    public struct CapturedDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScreen
        public static var name: Foundation.Notification.Name { UIScreen.capturedDidChangeNotification }
        public var screen: UIScreen
        public init(screen: UIScreen) { self.screen = screen }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let screen = n.object as? UIScreen else { return nil }
            return Self(screen: screen)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.screen) }
    }
}
@available(iOS 26.0, *)
extension UIScreen {
    public struct ModeDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScreen
        public static var name: Foundation.Notification.Name { UIScreen.modeDidChangeNotification }
        public var screen: UIScreen
        public init(screen: UIScreen) { self.screen = screen }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let screen = n.object as? UIScreen else { return nil }
            return Self(screen: screen)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.screen) }
    }
}
@available(iOS 26.0, *)
extension UIScreen {
    public struct ReferenceDisplayModeStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScreen
        public static var name: Foundation.Notification.Name { UIScreen.referenceDisplayModeStatusDidChangeNotification }
        public var screen: UIScreen
        public init(screen: UIScreen) { self.screen = screen }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let screen = n.object as? UIScreen else { return nil }
            return Self(screen: screen)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.screen) }
    }
}
@available(iOS 26.0, *)
extension UIWindow {
    public struct DidBecomeVisibleMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIWindow
        public static var name: Foundation.Notification.Name { UIWindow.didBecomeVisibleNotification }
        public var window: UIWindow
        public init(window: UIWindow) { self.window = window }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let window = n.object as? UIWindow else { return nil }
            return Self(window: window)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.window) }
    }
}
@available(iOS 26.0, *)
extension UIWindow {
    public struct DidBecomeHiddenMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIWindow
        public static var name: Foundation.Notification.Name { UIWindow.didBecomeHiddenNotification }
        public var window: UIWindow
        public init(window: UIWindow) { self.window = window }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let window = n.object as? UIWindow else { return nil }
            return Self(window: window)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.window) }
    }
}
@available(iOS 26.0, *)
extension UIWindow {
    public struct DidBecomeKeyMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIWindow
        public static var name: Foundation.Notification.Name { UIWindow.didBecomeKeyNotification }
        public var window: UIWindow
        public init(window: UIWindow) { self.window = window }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let window = n.object as? UIWindow else { return nil }
            return Self(window: window)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.window) }
    }
}
@available(iOS 26.0, *)
extension UIWindow {
    public struct DidResignKeyMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIWindow
        public static var name: Foundation.Notification.Name { UIWindow.didResignKeyNotification }
        public var window: UIWindow
        public init(window: UIWindow) { self.window = window }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let window = n.object as? UIWindow else { return nil }
            return Self(window: window)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.window) }
    }
}
@available(iOS 26.0, *)
extension UIScene {
    public struct WillConnectMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScene
        public static var name: Foundation.Notification.Name { UIScene.willConnectNotification }
        public var scene: UIScene
        public init(scene: UIScene) { self.scene = scene }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let scene = n.object as? UIScene else { return nil }
            return Self(scene: scene)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.scene) }
    }
}
@available(iOS 26.0, *)
extension UIScene {
    public struct DidActivateMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScene
        public static var name: Foundation.Notification.Name { UIScene.didActivateNotification }
        public var scene: UIScene
        public init(scene: UIScene) { self.scene = scene }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let scene = n.object as? UIScene else { return nil }
            return Self(scene: scene)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.scene) }
    }
}
@available(iOS 26.0, *)
extension UIScene {
    public struct WillDeactivateMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScene
        public static var name: Foundation.Notification.Name { UIScene.willDeactivateNotification }
        public var scene: UIScene
        public init(scene: UIScene) { self.scene = scene }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let scene = n.object as? UIScene else { return nil }
            return Self(scene: scene)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.scene) }
    }
}
@available(iOS 26.0, *)
extension UIScene {
    public struct WillEnterForegroundMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScene
        public static var name: Foundation.Notification.Name { UIScene.willEnterForegroundNotification }
        public var scene: UIScene
        public init(scene: UIScene) { self.scene = scene }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let scene = n.object as? UIScene else { return nil }
            return Self(scene: scene)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.scene) }
    }
}
@available(iOS 26.0, *)
extension UIScene {
    public struct DidEnterBackgroundMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScene
        public static var name: Foundation.Notification.Name { UIScene.didEnterBackgroundNotification }
        public var scene: UIScene
        public init(scene: UIScene) { self.scene = scene }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let scene = n.object as? UIScene else { return nil }
            return Self(scene: scene)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.scene) }
    }
}
@available(iOS 26.0, *)
extension UIScene {
    public struct SystemProtectionDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScene
        public static var name: Foundation.Notification.Name { UIScene.systemProtectionDidChangeNotification }
        public var scene: UIScene
        public init(scene: UIScene) { self.scene = scene }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let scene = n.object as? UIScene else { return nil }
            return Self(scene: scene)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.scene) }
    }
}
@available(iOS 26.0, *)
extension UITextField {
    public struct TextDidBeginEditingMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UITextField
        public static var name: Foundation.Notification.Name { UITextField.textDidBeginEditingNotification }
        public var textField: UITextField
        public init(textField: UITextField) { self.textField = textField }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let textField = n.object as? UITextField else { return nil }
            return Self(textField: textField)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.textField) }
    }
}
@available(iOS 26.0, *)
extension UITextField {
    public struct TextDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UITextField
        public static var name: Foundation.Notification.Name { UITextField.textDidChangeNotification }
        public var textField: UITextField
        public init(textField: UITextField) { self.textField = textField }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let textField = n.object as? UITextField else { return nil }
            return Self(textField: textField)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.textField) }
    }
}
@available(iOS 26.0, *)
extension UITextField {
    public struct TextDidEndEditingMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UITextField
        public static var name: Foundation.Notification.Name { UITextField.textDidEndEditingNotification }
        public var reason: UITextField.DidEndEditingReason?
        public var textField: UITextField
        public init(reason: UITextField.DidEndEditingReason?, textField: UITextField) { self.reason = reason; self.textField = textField }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            let reason: UITextField.DidEndEditingReason? = (n.userInfo?[UITextField.didEndEditingReasonUserInfoKey] as? Int).flatMap { UITextField.DidEndEditingReason(rawValue: $0) }
            guard let textField = n.object as? UITextField else { return nil }
            return Self(reason: reason, textField: textField)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge(m.reason.map { [UITextField.didEndEditingReasonUserInfoKey: $0.rawValue] } ?? [:] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: m.textField, userInfo: info)
        }
    }
}
@available(iOS 26.0, *)
extension UITextView {
    public struct TextDidBeginEditingMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UITextView
        public static var name: Foundation.Notification.Name { UITextView.textDidBeginEditingNotification }
        public var textView: UITextView
        public init(textView: UITextView) { self.textView = textView }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let textView = n.object as? UITextView else { return nil }
            return Self(textView: textView)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.textView) }
    }
}
@available(iOS 26.0, *)
extension UITextView {
    public struct TextDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UITextView
        public static var name: Foundation.Notification.Name { UITextView.textDidChangeNotification }
        public var textView: UITextView
        public init(textView: UITextView) { self.textView = textView }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let textView = n.object as? UITextView else { return nil }
            return Self(textView: textView)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.textView) }
    }
}
@available(iOS 26.0, *)
extension UITextView {
    public struct TextDidEndEditingMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UITextView
        public static var name: Foundation.Notification.Name { UITextView.textDidEndEditingNotification }
        public var textView: UITextView
        public init(textView: UITextView) { self.textView = textView }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let textView = n.object as? UITextView else { return nil }
            return Self(textView: textView)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.textView) }
    }
}
@available(iOS 26.0, *)
extension UITableView {
    public struct SelectionDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UITableView
        public static var name: Foundation.Notification.Name { UITableView.selectionDidChangeNotification }
        public var tableView: UITableView
        public init(tableView: UITableView) { self.tableView = tableView }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let tableView = n.object as? UITableView else { return nil }
            return Self(tableView: tableView)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.tableView) }
    }
}
@available(iOS 26.0, *)
extension UIViewController {
    public struct ShowDetailTargetDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIViewController
        public static var name: Foundation.Notification.Name { UIViewController.showDetailTargetDidChangeNotification }
        public var viewController: UIViewController
        public init(viewController: UIViewController) { self.viewController = viewController }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let viewController = n.object as? UIViewController else { return nil }
            return Self(viewController: viewController)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.viewController) }
    }
}
@available(iOS 26.0, *)
extension UIDocument {
    public struct StateChangedMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIDocument
        public static var name: Foundation.Notification.Name { UIDocument.stateChangedNotification }
        public var document: UIDocument
        public init(document: UIDocument) { self.document = document }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let document = n.object as? UIDocument else { return nil }
            return Self(document: document)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: m.document) }
    }
}
@available(iOS 26.0, *)
extension UIDocument {
    public struct DidMoveToWritableLocationMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIDocument
        public static var name: Foundation.Notification.Name { UIDocument.didMoveToWritableLocationNotification }
        public var document: UIDocument
        public var oldURL: URL
        public init(document: UIDocument, oldURL: URL) { self.document = document; self.oldURL = oldURL }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            guard let document = n.object as? UIDocument else { return nil }
            guard let oldURL = n.userInfo?[UIDocument.didMoveToWritableLocationOldURLKey] as? URL else { return nil }
            return Self(document: document, oldURL: oldURL)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge([UIDocument.didMoveToWritableLocationOldURLKey: m.oldURL] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: m.document, userInfo: info)
        }
    }
}
@available(iOS 26.0, *)
extension UIPasteboard {
    public struct ChangedMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIPasteboard
        public static var name: Foundation.Notification.Name { UIPasteboard.changedNotification }
        public var typesAdded: [String]
        public var typesRemoved: [String]
        public init(typesAdded: [String], typesRemoved: [String]) { self.typesAdded = typesAdded; self.typesRemoved = typesRemoved }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            let typesAdded: [String] = (n.userInfo?[UIPasteboard.changedTypesAddedUserInfoKey] as? [String]) ?? []
            let typesRemoved: [String] = (n.userInfo?[UIPasteboard.changedTypesRemovedUserInfoKey] as? [String]) ?? []
            return Self(typesAdded: typesAdded, typesRemoved: typesRemoved)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge([UIPasteboard.changedTypesAddedUserInfoKey: m.typesAdded] as [AnyHashable: Any]) { $1 }
            info.merge([UIPasteboard.changedTypesRemovedUserInfoKey: m.typesRemoved] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: nil, userInfo: info)
        }
    }
}
@available(iOS 26.0, *)
extension UIPasteboard {
    public struct RemovedMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIPasteboard
        public static var name: Foundation.Notification.Name { UIPasteboard.removedNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UITextInputMode {
    public struct CurrentInputModeDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UITextInputMode
        public static var name: Foundation.Notification.Name { UITextInputMode.currentInputModeDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIResponder {
    public struct KeyboardWillShowMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScreen
        public static var name: Foundation.Notification.Name { UIResponder.keyboardWillShowNotification }
        public var beginFrame: CGRect
        public var endFrame: CGRect
        public var animationDuration: TimeInterval
        public var animationCurve: UIView.AnimationCurve
        public var isLocal: Bool
        public var screen: UIScreen
        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) { self.beginFrame = beginFrame; self.endFrame = endFrame; self.animationDuration = animationDuration; self.animationCurve = animationCurve; self.isLocal = isLocal; self.screen = screen }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            let beginFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let endFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let animationDuration: TimeInterval = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0
            let animationCurve: UIView.AnimationCurve = (n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int).flatMap { UIView.AnimationCurve(rawValue: $0) } ?? .easeInOut
            let isLocal: Bool = (n.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool) ?? true
            let screen: UIScreen = (n.object as? UIScreen) ?? UIScreen.main
            return Self(beginFrame: beginFrame, endFrame: endFrame, animationDuration: animationDuration, animationCurve: animationCurve, isLocal: isLocal, screen: screen)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge([UIResponder.keyboardFrameBeginUserInfoKey: NSValue(cgRect: m.beginFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: m.endFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationDurationUserInfoKey: m.animationDuration] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationCurveUserInfoKey: m.animationCurve.rawValue] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardIsLocalUserInfoKey: m.isLocal] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: m.screen, userInfo: info)
        }
    }
}
@available(iOS 26.0, *)
extension UIResponder {
    public struct KeyboardDidShowMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScreen
        public static var name: Foundation.Notification.Name { UIResponder.keyboardDidShowNotification }
        public var beginFrame: CGRect
        public var endFrame: CGRect
        public var animationDuration: TimeInterval
        public var animationCurve: UIView.AnimationCurve
        public var isLocal: Bool
        public var screen: UIScreen
        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) { self.beginFrame = beginFrame; self.endFrame = endFrame; self.animationDuration = animationDuration; self.animationCurve = animationCurve; self.isLocal = isLocal; self.screen = screen }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            let beginFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let endFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let animationDuration: TimeInterval = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0
            let animationCurve: UIView.AnimationCurve = (n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int).flatMap { UIView.AnimationCurve(rawValue: $0) } ?? .easeInOut
            let isLocal: Bool = (n.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool) ?? true
            let screen: UIScreen = (n.object as? UIScreen) ?? UIScreen.main
            return Self(beginFrame: beginFrame, endFrame: endFrame, animationDuration: animationDuration, animationCurve: animationCurve, isLocal: isLocal, screen: screen)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge([UIResponder.keyboardFrameBeginUserInfoKey: NSValue(cgRect: m.beginFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: m.endFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationDurationUserInfoKey: m.animationDuration] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationCurveUserInfoKey: m.animationCurve.rawValue] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardIsLocalUserInfoKey: m.isLocal] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: m.screen, userInfo: info)
        }
    }
}
@available(iOS 26.0, *)
extension UIResponder {
    public struct KeyboardWillHideMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScreen
        public static var name: Foundation.Notification.Name { UIResponder.keyboardWillHideNotification }
        public var beginFrame: CGRect
        public var endFrame: CGRect
        public var animationDuration: TimeInterval
        public var animationCurve: UIView.AnimationCurve
        public var isLocal: Bool
        public var screen: UIScreen
        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) { self.beginFrame = beginFrame; self.endFrame = endFrame; self.animationDuration = animationDuration; self.animationCurve = animationCurve; self.isLocal = isLocal; self.screen = screen }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            let beginFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let endFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let animationDuration: TimeInterval = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0
            let animationCurve: UIView.AnimationCurve = (n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int).flatMap { UIView.AnimationCurve(rawValue: $0) } ?? .easeInOut
            let isLocal: Bool = (n.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool) ?? true
            let screen: UIScreen = (n.object as? UIScreen) ?? UIScreen.main
            return Self(beginFrame: beginFrame, endFrame: endFrame, animationDuration: animationDuration, animationCurve: animationCurve, isLocal: isLocal, screen: screen)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge([UIResponder.keyboardFrameBeginUserInfoKey: NSValue(cgRect: m.beginFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: m.endFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationDurationUserInfoKey: m.animationDuration] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationCurveUserInfoKey: m.animationCurve.rawValue] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardIsLocalUserInfoKey: m.isLocal] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: m.screen, userInfo: info)
        }
    }
}
@available(iOS 26.0, *)
extension UIResponder {
    public struct KeyboardDidHideMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScreen
        public static var name: Foundation.Notification.Name { UIResponder.keyboardDidHideNotification }
        public var beginFrame: CGRect
        public var endFrame: CGRect
        public var animationDuration: TimeInterval
        public var animationCurve: UIView.AnimationCurve
        public var isLocal: Bool
        public var screen: UIScreen
        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) { self.beginFrame = beginFrame; self.endFrame = endFrame; self.animationDuration = animationDuration; self.animationCurve = animationCurve; self.isLocal = isLocal; self.screen = screen }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            let beginFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let endFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let animationDuration: TimeInterval = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0
            let animationCurve: UIView.AnimationCurve = (n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int).flatMap { UIView.AnimationCurve(rawValue: $0) } ?? .easeInOut
            let isLocal: Bool = (n.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool) ?? true
            let screen: UIScreen = (n.object as? UIScreen) ?? UIScreen.main
            return Self(beginFrame: beginFrame, endFrame: endFrame, animationDuration: animationDuration, animationCurve: animationCurve, isLocal: isLocal, screen: screen)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge([UIResponder.keyboardFrameBeginUserInfoKey: NSValue(cgRect: m.beginFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: m.endFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationDurationUserInfoKey: m.animationDuration] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationCurveUserInfoKey: m.animationCurve.rawValue] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardIsLocalUserInfoKey: m.isLocal] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: m.screen, userInfo: info)
        }
    }
}
@available(iOS 26.0, *)
extension UIResponder {
    public struct KeyboardWillChangeFrameMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScreen
        public static var name: Foundation.Notification.Name { UIResponder.keyboardWillChangeFrameNotification }
        public var beginFrame: CGRect
        public var endFrame: CGRect
        public var animationDuration: TimeInterval
        public var animationCurve: UIView.AnimationCurve
        public var isLocal: Bool
        public var screen: UIScreen
        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) { self.beginFrame = beginFrame; self.endFrame = endFrame; self.animationDuration = animationDuration; self.animationCurve = animationCurve; self.isLocal = isLocal; self.screen = screen }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            let beginFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let endFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let animationDuration: TimeInterval = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0
            let animationCurve: UIView.AnimationCurve = (n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int).flatMap { UIView.AnimationCurve(rawValue: $0) } ?? .easeInOut
            let isLocal: Bool = (n.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool) ?? true
            let screen: UIScreen = (n.object as? UIScreen) ?? UIScreen.main
            return Self(beginFrame: beginFrame, endFrame: endFrame, animationDuration: animationDuration, animationCurve: animationCurve, isLocal: isLocal, screen: screen)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge([UIResponder.keyboardFrameBeginUserInfoKey: NSValue(cgRect: m.beginFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: m.endFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationDurationUserInfoKey: m.animationDuration] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationCurveUserInfoKey: m.animationCurve.rawValue] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardIsLocalUserInfoKey: m.isLocal] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: m.screen, userInfo: info)
        }
    }
}
@available(iOS 26.0, *)
extension UIResponder {
    public struct KeyboardDidChangeFrameMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIScreen
        public static var name: Foundation.Notification.Name { UIResponder.keyboardDidChangeFrameNotification }
        public var beginFrame: CGRect
        public var endFrame: CGRect
        public var animationDuration: TimeInterval
        public var animationCurve: UIView.AnimationCurve
        public var isLocal: Bool
        public var screen: UIScreen
        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) { self.beginFrame = beginFrame; self.endFrame = endFrame; self.animationDuration = animationDuration; self.animationCurve = animationCurve; self.isLocal = isLocal; self.screen = screen }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            let beginFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let endFrame: CGRect = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let animationDuration: TimeInterval = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0
            let animationCurve: UIView.AnimationCurve = (n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int).flatMap { UIView.AnimationCurve(rawValue: $0) } ?? .easeInOut
            let isLocal: Bool = (n.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool) ?? true
            let screen: UIScreen = (n.object as? UIScreen) ?? UIScreen.main
            return Self(beginFrame: beginFrame, endFrame: endFrame, animationDuration: animationDuration, animationCurve: animationCurve, isLocal: isLocal, screen: screen)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge([UIResponder.keyboardFrameBeginUserInfoKey: NSValue(cgRect: m.beginFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: m.endFrame)] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationDurationUserInfoKey: m.animationDuration] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardAnimationCurveUserInfoKey: m.animationCurve.rawValue] as [AnyHashable: Any]) { $1 }
            info.merge([UIResponder.keyboardIsLocalUserInfoKey: m.isLocal] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: m.screen, userInfo: info)
        }
    }
}
@available(iOS 26.0, *)
extension UIContentSizeCategory {
    public struct DidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIApplication
        public static var name: Foundation.Notification.Name { UIContentSizeCategory.didChangeNotification }
        public var contentSize: String
        public var screen: UIScreen
        public init(contentSize: String, screen: UIScreen) { self.contentSize = contentSize; self.screen = screen }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            let contentSize: String = (n.userInfo?[UIContentSizeCategory.newValueUserInfoKey] as? String) ?? UIApplication.shared.preferredContentSizeCategory.rawValue
            let screen: UIScreen = UIScreen.main
            return Self(contentSize: contentSize, screen: screen)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge([UIContentSizeCategory.newValueUserInfoKey: m.contentSize] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: UIApplication.shared, userInfo: info)
        }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct VoiceOverStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.voiceOverStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct SwitchControlStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.switchControlStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct ReduceMotionStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.reduceMotionStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct ReduceTransparencyStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.reduceTransparencyStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct BoldTextStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.boldTextStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct DarkerSystemColorsStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.darkerSystemColorsStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct ClosedCaptioningStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.closedCaptioningStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct GrayscaleStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.grayscaleStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct InvertColorsStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.invertColorsStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct AssistiveTouchStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.assistiveTouchStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct GuidedAccessStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.guidedAccessStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct MonoAudioStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.monoAudioStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct SpeakScreenStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.speakScreenStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct SpeakSelectionStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.speakSelectionStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct HearingDevicePairedEarDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.hearingDevicePairedEarDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct ShakeToUndoDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.shakeToUndoDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct ButtonShapesEnabledStatusDidChangeMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.buttonShapesEnabledStatusDidChangeNotification }
        public init() {}
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? { Self() }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification { Foundation.Notification(name: name, object: nil) }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct AnnouncementDidFinishMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.announcementDidFinishNotification }
        public var announcement: String
        public var wasSuccessful: Bool
        public init(announcement: String, wasSuccessful: Bool) { self.announcement = announcement; self.wasSuccessful = wasSuccessful }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            let announcement: String = (n.userInfo?[UIAccessibility.announcementStringValueUserInfoKey] as? String) ?? ""
            let wasSuccessful: Bool = (n.userInfo?[UIAccessibility.announcementWasSuccessfulUserInfoKey] as? Bool) ?? false
            return Self(announcement: announcement, wasSuccessful: wasSuccessful)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge([UIAccessibility.announcementStringValueUserInfoKey: m.announcement] as [AnyHashable: Any]) { $1 }
            info.merge([UIAccessibility.announcementWasSuccessfulUserInfoKey: m.wasSuccessful] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: nil, userInfo: info)
        }
    }
}
@available(iOS 26.0, *)
extension UIAccessibility {
    public struct ElementFocusedMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIAccessibility
        public static var name: Foundation.Notification.Name { UIAccessibility.elementFocusedNotification }
        public var element: AnyObject?
        public init(element: AnyObject?) { self.element = element }
        @MainActor public static func makeMessage(_ n: Foundation.Notification) -> Self? {
            let element: AnyObject? = n.userInfo?[UIAccessibility.focusedElementUserInfoKey] as AnyObject?
            return Self(element: element)
        }
        @MainActor public static func makeNotification(_ m: Self) -> Foundation.Notification {
            var info: [AnyHashable: Any] = [:]
            info.merge(m.element.map { [UIAccessibility.focusedElementUserInfoKey: $0] } ?? [:] as [AnyHashable: Any]) { $1 }
            return Foundation.Notification(name: name, object: nil, userInfo: info)
        }
    }
}

@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.DidFinishLaunchingMessage> {
    public static var didFinishLaunching: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.DidBecomeActiveMessage> {
    public static var didBecomeActive: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.DidEnterBackgroundMessage> {
    public static var didEnterBackground: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.WillEnterForegroundMessage> {
    public static var willEnterForeground: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.WillResignActiveMessage> {
    public static var willResignActive: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.WillTerminateMessage> {
    public static var willTerminate: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.DidReceiveMemoryWarningMessage> {
    public static var didReceiveMemoryWarning: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.SignificantTimeChangeMessage> {
    public static var significantTimeChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.BackgroundRefreshStatusDidChangeMessage> {
    public static var backgroundRefreshStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.UserDidTakeScreenshotMessage> {
    public static var userDidTakeScreenshot: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.ProtectedDataWillBecomeUnavailableMessage> {
    public static var protectedDataWillBecomeUnavailable: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIApplication.ProtectedDataDidBecomeAvailableMessage> {
    public static var protectedDataDidBecomeAvailable: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIDevice.BatteryLevelDidChangeMessage> {
    public static var batteryLevelDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIDevice.BatteryStateDidChangeMessage> {
    public static var batteryStateDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIDevice.OrientationDidChangeMessage> {
    public static var orientationDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIDevice.ProximityStateDidChangeMessage> {
    public static var proximityStateDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIScreen.BrightnessDidChangeMessage> {
    public static var brightnessDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIScreen.CapturedDidChangeMessage> {
    public static var capturedDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIScreen.ModeDidChangeMessage> {
    public static var modeDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIScreen.ReferenceDisplayModeStatusDidChangeMessage> {
    public static var referenceDisplayModeStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIWindow.DidBecomeVisibleMessage> {
    public static var didBecomeVisible: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIWindow.DidBecomeHiddenMessage> {
    public static var didBecomeHidden: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIWindow.DidBecomeKeyMessage> {
    public static var didBecomeKey: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIWindow.DidResignKeyMessage> {
    public static var didResignKey: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIScene.WillConnectMessage> {
    public static var willConnect: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIScene.DidActivateMessage> {
    public static var didActivate: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIScene.WillDeactivateMessage> {
    public static var willDeactivate: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIScene.WillEnterForegroundMessage> {
    public static var willEnterForeground: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIScene.DidEnterBackgroundMessage> {
    public static var didEnterBackground: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIScene.SystemProtectionDidChangeMessage> {
    public static var systemProtectionDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UITextField.TextDidBeginEditingMessage> {
    public static var textDidBeginEditing: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UITextField.TextDidChangeMessage> {
    public static var textDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UITextField.TextDidEndEditingMessage> {
    public static var textDidEndEditing: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UITextView.TextDidBeginEditingMessage> {
    public static var textDidBeginEditing: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UITextView.TextDidChangeMessage> {
    public static var textDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UITextView.TextDidEndEditingMessage> {
    public static var textDidEndEditing: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UITableView.SelectionDidChangeMessage> {
    public static var selectionDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIViewController.ShowDetailTargetDidChangeMessage> {
    public static var showDetailTargetDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIDocument.StateChangedMessage> {
    public static var stateChanged: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIDocument.DidMoveToWritableLocationMessage> {
    public static var didMoveToWritableLocation: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIPasteboard.ChangedMessage> {
    public static var changed: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIPasteboard.RemovedMessage> {
    public static var removed: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UITextInputMode.CurrentInputModeDidChangeMessage> {
    public static var currentInputModeDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIResponder.KeyboardWillShowMessage> {
    public static var keyboardWillShow: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIResponder.KeyboardDidShowMessage> {
    public static var keyboardDidShow: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIResponder.KeyboardWillHideMessage> {
    public static var keyboardWillHide: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIResponder.KeyboardDidHideMessage> {
    public static var keyboardDidHide: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIResponder.KeyboardWillChangeFrameMessage> {
    public static var keyboardWillChangeFrame: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIResponder.KeyboardDidChangeFrameMessage> {
    public static var keyboardDidChangeFrame: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIContentSizeCategory.DidChangeMessage> {
    public static var contentSizeCategoryDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.VoiceOverStatusDidChangeMessage> {
    public static var voiceOverStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.SwitchControlStatusDidChangeMessage> {
    public static var switchControlStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.ReduceMotionStatusDidChangeMessage> {
    public static var reduceMotionStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.ReduceTransparencyStatusDidChangeMessage> {
    public static var reduceTransparencyStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.BoldTextStatusDidChangeMessage> {
    public static var boldTextStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.DarkerSystemColorsStatusDidChangeMessage> {
    public static var darkerSystemColorsStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.ClosedCaptioningStatusDidChangeMessage> {
    public static var closedCaptioningStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.GrayscaleStatusDidChangeMessage> {
    public static var grayscaleStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.InvertColorsStatusDidChangeMessage> {
    public static var invertColorsStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.AssistiveTouchStatusDidChangeMessage> {
    public static var assistiveTouchStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.GuidedAccessStatusDidChangeMessage> {
    public static var guidedAccessStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.MonoAudioStatusDidChangeMessage> {
    public static var monoAudioStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.SpeakScreenStatusDidChangeMessage> {
    public static var speakScreenStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.SpeakSelectionStatusDidChangeMessage> {
    public static var speakSelectionStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.HearingDevicePairedEarDidChangeMessage> {
    public static var hearingDevicePairedEarDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.ShakeToUndoDidChangeMessage> {
    public static var shakeToUndoDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.ButtonShapesEnabledStatusDidChangeMessage> {
    public static var buttonShapesEnabledStatusDidChange: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.AnnouncementDidFinishMessage> {
    public static var announcementDidFinish: Self { .init() }
}
@available(iOS 26.0, *) extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<UIAccessibility.ElementFocusedMessage> {
    public static var elementFocused: Self { .init() }
}
