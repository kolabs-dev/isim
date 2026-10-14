// Sample: the Info.plist keys iOS checks (issue #233). Each line it prints ("ip ...") is what the app sees:
// canOpenURL for declared (LSApplicationQueriesSchemes), undeclared, system and its own URL schemes; whether it may
// have several scenes (UIRequiresFullScreen on iPad); Core Bluetooth, Core Motion and Core NFC with or without their
// usage descriptions; Bonjour browsing and advertising of declared and undeclared types (NSBonjourServices). The test
// runs copies of the app with Info.plist variants. UIRequiredDeviceCapabilities is checked by `isim install`.
import UIKit
import CoreBluetooth
import CoreMotion
import CoreNFC
import Network

func say(_ s: String) { print("ip " + s); fflush(stdout) }

final class Checks: NSObject, CBCentralManagerDelegate, NFCNDEFReaderSessionDelegate {
    var central: CBCentralManager?
    var nfc: NFCNDEFReaderSession?
    var browsers: [NWBrowser] = []
    var listener: NWListener?

    func run() {
        let app = UIApplication.shared
        for u in ["fb://profile", "twitter://user", "https://example.com", "tel:5550100", "helloinfoplist://self"] {
            say("can open \(u) \(app.canOpenURL(URL(string: u)!))")
        }
        say("multiple scenes \(app.supportsMultipleScenes)")

        central = CBCentralManager(delegate: self, queue: .main)
        say("bluetooth authorization \(CBManager.authorization.rawValue)")
        CMPedometer().queryPedometerData(from: Date(timeIntervalSinceNow: -3600), to: Date()) { _, e in
            say("pedometer status \(CMPedometer.authorizationStatus().rawValue) error \((e as NSError?)?.code ?? 0)")
        }
        nfc = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: true)
        nfc?.begin()

        for type in ["_isim-declared._tcp", "_isim-undeclared._tcp"] {
            let b = NWBrowser(for: .bonjour(type: type, domain: nil), using: .tcp)
            b.stateUpdateHandler = { state in
                switch state {
                case .ready: say("browse \(type) ready")
                case .failed(let e): say("browse \(type) failed \(e)")
                default: break
                }
            }
            b.start(queue: .main)
            browsers.append(b)
        }
        if let l = try? NWListener(using: .tcp) {
            l.service = NWListener.Service(name: "Undeclared", type: "_isim-undeclared._tcp")
            l.newConnectionHandler = { $0.cancel() }
            l.stateUpdateHandler = { state in
                if case .failed(let e) = state { say("advertise _isim-undeclared._tcp failed \(e)") }
                if case .ready = state { say("advertise _isim-undeclared._tcp ready") }
            }
            l.start(queue: .main)
            listener = l
        }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) { say("bluetooth state \(central.state.rawValue)") }
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        say("nfc invalidated \((error as NSError).code)")
    }
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}
}

final class ViewController: UIViewController {
    let checks = Checks()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Info.plist checks"
        label.font = .preferredFont(forTextStyle: .title2)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                     label.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        checks.run()
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: ws)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: nil, sessionRole: session.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}
