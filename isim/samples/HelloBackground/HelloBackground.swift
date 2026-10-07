// HelloBackground: background execution on isim (UIKit, Swift).
// A timer that ticks twice a second shows whether the app runs: without anything keeping it running the app is
// suspended a few seconds after going home (the ticks stop) and resumes when it comes back. Background audio
// (UIBackgroundModes audio + the playback category) and background location updates (UIBackgroundModes location +
// allowsBackgroundLocationUpdates, with the blue status-bar indicator) keep it running. Haptics and system sounds
// are logged (no hardware, like the Simulator).
import UIKit
import AVFoundation
import CoreLocation
import AudioToolbox

func log(_ s: String) { NSLog("HelloBackground: %@", s) }

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
    func applicationDidEnterBackground(_ application: UIApplication) { log("entered background") }
    func applicationWillEnterForeground(_ application: UIApplication) { log("entering foreground") }
}

class ViewController: UIViewController, CLLocationManagerDelegate {
    let ticks = UILabel(), status = UILabel()
    var count = 0
    var player: AVAudioPlayer?
    let location = CLLocationManager()
    var fixes = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Background"; title.font = .boldSystemFont(ofSize: 32)
        ticks.text = "Ticks 0"; ticks.accessibilityIdentifier = "ticks"
        status.text = "Idle"; status.accessibilityIdentifier = "status"
        let stack = UIStackView(arrangedSubviews: [title, ticks, status,
            button("Play Audio", "play") { [weak self] in self?.play() },
            button("Stop Audio", "stop") { [weak self] in self?.player?.stop(); log("audio stopped"); self?.status.text = "Audio stopped" },
            button("Track Location", "track") { [weak self] in self?.track() },
            button("Stop Location", "untrack") { [weak self] in self?.location.stopUpdatingLocation(); log("location stopped") },
            button("Haptics", "haptics") { [weak self] in self?.haptics() }])
        stack.axis = .vertical; stack.spacing = 12; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        ])
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.count += 1
            self.ticks.text = "Ticks \(self.count)"
            if self.count % 2 == 0 { log("tick \(self.count) state=\(UIApplication.shared.applicationState == .background ? "background" : "foreground")") }
        }
        location.delegate = self
    }
    func button(_ t: String, _ id: String, _ action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system, primaryAction: UIAction(title: t) { _ in action() })
        b.accessibilityIdentifier = id
        b.titleLabel?.font = .systemFont(ofSize: 20)
        return b
    }
    /// a looping 440 Hz tone (WAV data made here), with the playback category
    func play() {
        let rate = 44100, n = rate / 2
        var pcm = Data()
        for i in 0..<n { var s = Int16(sin(Double(i) * 2 * .pi * 440 / Double(rate)) * 12000); pcm.append(Data(bytes: &s, count: 2)) }
        func u32(_ v: UInt32) -> Data { var x = v.littleEndian; return Data(bytes: &x, count: 4) }
        func u16(_ v: UInt16) -> Data { var x = v.littleEndian; return Data(bytes: &x, count: 2) }
        var wav = Data("RIFF".utf8)
        wav.append(u32(UInt32(36 + pcm.count))); wav.append(Data("WAVEfmt ".utf8))
        wav.append(u32(16)); wav.append(u16(1)); wav.append(u16(1)); wav.append(u32(UInt32(rate))); wav.append(u32(UInt32(rate * 2)))
        wav.append(u16(2)); wav.append(u16(16)); wav.append(Data("data".utf8)); wav.append(u32(UInt32(pcm.count))); wav.append(pcm)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            player = try AVAudioPlayer(data: wav)
            player?.numberOfLoops = -1
            player?.play()
            log("audio playing (playback category)")
            status.text = "Playing"
        } catch { log("audio failed: \(error)") }
    }
    func track() {
        location.requestWhenInUseAuthorization()
        location.allowsBackgroundLocationUpdates = true
        location.startUpdatingLocation()
        log("tracking location in the background")
        status.text = "Tracking"
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        fixes += 1
        log("location \(fixes) state=\(UIApplication.shared.applicationState == .background ? "background" : "foreground")")
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { log("location error \(error)") }
    func haptics() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UISelectionFeedbackGenerator().selectionChanged()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        AudioServicesPlaySystemSound(1104)
        log("haptics done")
    }
}
