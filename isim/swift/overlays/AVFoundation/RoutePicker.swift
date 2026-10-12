// isim AVFoundation: the audio route picker that AVKit's AVRoutePickerView and MediaPlayer's MPVolumeView route button
// present (self-authored, adapted). Like iOS's AirPlay card: the device itself and the routes isim simulates — wired
// headphones when the `audio route headphones` command plugged them in, and one AirPlay speaker ("AirPlay Speaker";
// its sound still comes out of the host). Picking one changes AVAudioSession's current route and posts the route
// change. Rows have accessibility identifiers (route-iphone, route-headphones, route-airplay) for scripts.
import UIKit

final class _RoutePickerController: UIViewController {
    var onDismiss: (() -> Void)?
    let card = UIView()
    static var routes: [(id: String, name: String, symbol: String, port: AVAudioSession.Port)] {
        let current = _AudioSessionEvents.route.outputs.first?.portType
        var r: [(String, String, String, AVAudioSession.Port)] = [("iphone", UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone",
                                                                   UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone", .builtInSpeaker)]
        if current == .headphones || current == .bluetoothA2DP { r.append(("headphones", current == .bluetoothA2DP ? "Bluetooth Headphones" : "Headphones", "headphones", current!)) }
        r.append(("airplay", "AirPlay Speaker", "hifispeaker.fill", .airPlay))
        return r.map { (id: $0.0, name: $0.1, symbol: $0.2, port: $0.3) }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        let dismiss = UIButton(type: .custom)
        dismiss.frame = view.bounds; dismiss.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dismiss.accessibilityIdentifier = "route-picker-background"
        dismiss.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(dismiss)
        let routes = Self.routes
        let current = _AudioSessionEvents.route.outputs.first?.portType
        let w: CGFloat = 300, rowH: CGFloat = 52
        card.frame = CGRect(x: 0, y: 0, width: w, height: 56 + rowH * CGFloat(routes.count) + 10)
        card.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.17, alpha: 0.97) : UIColor(white: 0.97, alpha: 0.97) }
        card.layer.cornerRadius = 26
        card.layer.shadowOpacity = 0.18; card.layer.shadowRadius = 20; card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.accessibilityIdentifier = "route-picker"
        view.addSubview(card)
        let title = UILabel(frame: CGRect(x: 0, y: 16, width: w, height: 24))
        title.text = "AirPlay"; title.textAlignment = .center; title.font = .systemFont(ofSize: 17, weight: .semibold)
        card.addSubview(title)
        for (i, r) in routes.enumerated() {
            let row = UIButton(type: .custom)
            row.frame = CGRect(x: 8, y: 52 + CGFloat(i) * rowH, width: w - 16, height: rowH)
            row.accessibilityIdentifier = "route-\(r.id)"
            row.accessibilityLabel = r.name
            row.tag = i
            row.addTarget(self, action: #selector(pick(_:)), for: .touchUpInside)
            let icon = UIImageView(image: UIImage(systemName: r.symbol))
            icon.tintColor = .label; icon.contentMode = .center
            icon.frame = CGRect(x: 12, y: 0, width: 30, height: rowH)
            row.addSubview(icon)
            let name = UILabel(frame: CGRect(x: 54, y: 0, width: w - 120, height: rowH))
            name.text = r.name; name.font = .systemFont(ofSize: 17)
            row.addSubview(name)
            let selected = r.port == current || (r.port == .builtInSpeaker && current == .builtInReceiver)
            let check = UIImageView(image: UIImage(systemName: selected ? "checkmark.circle.fill" : "circle"))
            check.tintColor = selected ? .systemBlue : .tertiaryLabel
            check.frame = CGRect(x: w - 16 - 40, y: (rowH - 24) / 2, width: 24, height: 24)
            row.addSubview(check)
            card.addSubview(row)
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        card.center = CGPoint(x: view.bounds.midX, y: view.bounds.height - view.safeAreaInsets.bottom - card.bounds.height / 2 - 24)
    }
    @objc func pick(_ sender: UIButton) {
        let r = Self.routes[sender.tag]
        let name = r.port == .airPlay ? "airplay" : r.port == .builtInSpeaker ? "speaker" : r.port == .bluetoothA2DP ? "bluetooth" : "headphones"
        NSLog("isim AVFoundation: route picker chose %@", r.name)
        _AudioSessionEvents.setRoute(name, reason: r.port == .builtInSpeaker ? .override : nil)
        close()
    }
    @objc func close() { dismiss(animated: true) { self.onDismiss?() } }
}

extension AVAudioSession {
    /// isim: presents the audio route picker (AVRoutePickerView, MPVolumeView); `done` runs when it closes.
    @MainActor public static func _isimShowRoutePicker(from view: UIView, done: (() -> Void)? = nil) {
        _AudioSessionEvents.start()
        var top = view.window?.rootViewController
        while let p = top?.presentedViewController { top = p }
        guard let presenter = top else { done?(); return }
        let vc = _RoutePickerController()
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        vc.onDismiss = done
        presenter.present(vc, animated: true)
    }
}
