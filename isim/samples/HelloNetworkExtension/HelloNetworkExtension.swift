// Sample: NetworkExtension's managers on isim (issue #424). Buttons join a Wi-Fi network with NEHotspotConfigurationManager
// (iOS's join alert; the configured SSIDs), add a personal IKEv2 VPN with NEVPNManager (iOS's "Would Like to Add VPN
// Configurations" alert) and connect / disconnect it (NEVPNStatusDidChange), save a packet tunnel configuration with
// NETunnelProviderManager and start its session, save an app push configuration matching the simulated Wi-Fi
// (NEAppPushManager.isActive), and on iOS 26 save a URL filter configuration (NEURLFilterManager). Everything is logged
// with the "ne:" prefix; tunnels are simulated (no traffic is routed).
//   isim run out/apps/HelloNetworkExtension.app
import UIKit
import NetworkExtension

func log(_ s: String) { print("ne: " + s) }
/// shows a result in the status label
func showStatus(_ s: String) { DispatchQueue.main.async { MainActor.assumeIsolated { ViewController.current?.status.text = s } } }
let statusNames = ["invalid", "disconnected", "connecting", "connected", "reasserting", "disconnecting"]

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: ViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class ViewController: UIViewController, NEAppPushDelegate {
    static weak var current: ViewController?
    let status = UILabel()
    var push: NEAppPushManager?
    var activeObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        ViewController.current = self
        title = "Network Tools"
        view.backgroundColor = .systemGroupedBackground
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (t, id, sel) in [("Join “Café Wi-Fi”", "join", #selector(join)),
                             ("Join with a short password", "join-bad", #selector(joinBad)),
                             ("Forget “Café Wi-Fi”", "forget", #selector(forget)),
                             ("Add VPN", "vpn-add", #selector(addVPN)),
                             ("Connect VPN", "vpn-connect", #selector(connectVPN)),
                             ("Disconnect VPN", "vpn-disconnect", #selector(disconnectVPN)),
                             ("Remove VPN", "vpn-remove", #selector(removeVPN)),
                             ("Start packet tunnel", "tunnel", #selector(startTunnel)),
                             ("Save app push", "push", #selector(savePush)),
                             ("Save URL filter", "filter", #selector(saveFilter))] as [(String, String, Selector)] {
            var c = UIButton.Configuration.filled(); c.title = t; c.cornerStyle = .large
            let b = UIButton(configuration: c); b.accessibilityIdentifier = id
            b.addTarget(self, action: sel, for: .touchUpInside)
            b.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(b)
        }
        status.text = "–"; status.textAlignment = .center; status.numberOfLines = 2; status.accessibilityIdentifier = "status"
        stack.addArrangedSubview(status)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: .main) { n in
            guard let c = n.object as? NEVPNConnection else { return }
            let s = statusNames[c.status.rawValue]
            log("vpn status \(s)\(c is NETunnelProviderSession ? " (tunnel)" : "")")
            showStatus("VPN \(s)")
        }
        // what earlier launches saved
        NEVPNManager.shared().loadFromPreferences { _ in
            let m = NEVPNManager.shared()
            log("vpn loaded \(m.localizedDescription ?? "none") enabled=\(m.isEnabled) server=\(m.protocolConfiguration?.serverAddress ?? "-")")
        }
        NEHotspotConfigurationManager.shared.getConfiguredSSIDs { log("configured SSIDs \($0)") }
    }

    // MARK: hotspots
    @objc func join() {
        let c = NEHotspotConfiguration(ssid: "Café Wi-Fi", passphrase: "espresso-42", isWEP: false)
        c.joinOnce = false
        NEHotspotConfigurationManager.shared.apply(c) { error in
            log("join error \(error.map { "\(($0 as NSError).domain) \(($0 as NSError).code)" } ?? "none")")
            NEHotspotConfigurationManager.shared.getConfiguredSSIDs { ssids in
                log("configured SSIDs \(ssids)")
                showStatus(error == nil ? "joined Café Wi-Fi" : "not joined")
            }
        }
    }
    @objc func joinBad() {
        NEHotspotConfigurationManager.shared.apply(NEHotspotConfiguration(ssid: "Lobby", passphrase: "short", isWEP: false)) { error in
            let code = (error as NSError?)?.code ?? -1
            log("short password error \(code) invalidWPA=\(code == NEHotspotConfigurationError.invalidWPAPassphrase.rawValue)")
        }
    }
    @objc func forget() {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: "Café Wi-Fi")
        NEHotspotConfigurationManager.shared.getConfiguredSSIDs { log("configured SSIDs \($0)") }
    }

    // MARK: personal VPN
    @objc func addVPN() {
        let m = NEVPNManager.shared()
        m.loadFromPreferences { _ in
            let p = NEVPNProtocolIKEv2()
            p.serverAddress = "vpn.example.com"
            p.remoteIdentifier = "vpn.example.com"
            p.localIdentifier = "ada"
            p.authenticationMethod = .sharedSecret
            p.sharedSecretReference = Data("secret-ref".utf8)
            p.ikeSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256GCM
            p.ikeSecurityAssociationParameters.diffieHellmanGroup = .group19
            p.deadPeerDetectionRate = .high
            m.protocolConfiguration = p
            m.localizedDescription = "Example VPN"
            m.isEnabled = true
            let rule = NEOnDemandRuleConnect(); rule.interfaceTypeMatch = .wiFi
            m.onDemandRules = [rule]
            m.saveToPreferences { error in
                log("vpn save error \(error.map { "\(($0 as NSError).domain) \(($0 as NSError).code)" } ?? "none")")
                showStatus(error == nil ? "VPN added" : "VPN not added")
            }
        }
    }
    @objc func connectVPN() {
        let m = NEVPNManager.shared()
        m.loadFromPreferences { _ in
            do {
                try m.connection.startVPNTunnel()
                log("vpn start requested")
            } catch { log("vpn start error \((error as NSError).domain) \((error as NSError).code)") }
        }
    }
    @objc func disconnectVPN() { NEVPNManager.shared().connection.stopVPNTunnel() }
    @objc func removeVPN() {
        NEVPNManager.shared().removeFromPreferences { error in log("vpn removed error \(error.map { "\(($0 as NSError).code)" } ?? "none")") }
    }

    // MARK: packet tunnel
    @objc func startTunnel() {
        NETunnelProviderManager.loadAllFromPreferences { managers, _ in
            let m = managers?.first ?? NETunnelProviderManager()
            log("tunnel managers \(managers?.count ?? 0)")
            let p = NETunnelProviderProtocol()
            p.providerBundleIdentifier = "dev.isim.samples.HelloNetworkExtension.Tunnel"
            p.serverAddress = "tunnel.example.com"
            p.providerConfiguration = ["mtu": 1400]
            m.protocolConfiguration = p
            m.localizedDescription = "Example Tunnel"
            m.isEnabled = true
            m.saveToPreferences { error in
                log("tunnel save error \(error.map { "\(($0 as NSError).code)" } ?? "none")")
                m.loadFromPreferences { _ in
                    do {
                        try (m.connection as? NETunnelProviderSession)?.startTunnel(options: ["reason": "sample" as NSString])
                        log("tunnel routing \(m.routingMethod.rawValue)")
                    } catch { log("tunnel start error \((error as NSError).code)") }
                }
            }
        }
    }

    // MARK: app push
    @objc func savePush() {
        let m = NEAppPushManager()
        m.localizedDescription = "Example Push"
        m.providerBundleIdentifier = "dev.isim.samples.HelloNetworkExtension.Push"
        m.providerConfiguration = ["host": "push.example.com"]
        m.matchSSIDs = ["isim", "Office"]
        m.isEnabled = true
        m.delegate = self
        activeObservation = m.observe(\.isActive, options: [.new]) { m, _ in log("push active \(m.isActive)") }
        m.saveToPreferences { error in
            log("push save error \(error.map { "\(($0 as NSError).code)" } ?? "none")")
            NEAppPushManager.loadAllFromPreferences { all, _ in log("push managers \(all?.count ?? 0) active \(all?.first?.isActive ?? false)") }
        }
        push = m
    }
    func appPushManager(_ manager: NEAppPushManager, didReceiveIncomingCallWithUserInfo userInfo: [AnyHashable: Any]) {
        log("incoming call \(userInfo)")
    }

    // MARK: URL filter (iOS 26)
    @objc func saveFilter() {
        guard #available(iOS 26.0, *) else { log("url filter needs iOS 26"); status.text = "needs iOS 26"; return }
        Task {
            let f = NEURLFilterManager.shared
            do {
                try await f.loadFromPreferences()
                try f.setConfiguration(pirServerURL: URL(string: "https://pir.example.com")!, pirPrivacyPassIssuerURL: nil,
                                       pirAuthenticationToken: "token", controlProviderBundleIdentifier: "dev.isim.samples.HelloNetworkExtension.Filter")
                f.localizedDescription = "Example Filter"
                f.isEnabled = true
                try await f.saveToPreferences()
                log("url filter saved status \(f.status) error \(f.lastDisconnectError.map { "\($0)" } ?? "none")")
                status.text = "filter \(f.status)"
            } catch { log("url filter error \(error)") }
        }
    }
}
