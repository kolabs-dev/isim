import AVFoundation
import Core           // macros from the local package's macro target (CoreMacros)
import UIKit
import UserNotifications

final class ViewController: UIViewController, UITextFieldDelegate {
    private var model = Model()
    private let countLabel = UILabel()
    private let echoLabel = UILabel()
    private let field = UITextField()
    private let permissionLabel = UILabel()
    private let lifecycleLabel = UILabel()
    private var backgroundCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Toolchain"
        view.backgroundColor = .systemBackground
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-startCount"), i + 1 < args.count, let n = Int(args[i + 1]) { model.count = n }
        let mode = ProcessInfo.processInfo.environment["UITEST_MODE"] ?? "normal"

        func label(_ text: String, _ id: String) -> UILabel {
            let l = UILabel(); l.text = text; l.accessibilityIdentifier = id; l.numberOfLines = 0; return l
        }
        let greeting = label(Model.greeting("isim"), "greeting")
        greeting.font = .preferredFont(forTextStyle: .title2)
        let sums = label("MathKit \(Model.mathKitSum()) · XCFramework \(Model.xcframeworkSum()) · Units \(Model.units())", "sums")
        let flavor = label("\(Model.buildFlavor) · \(Model.greetingWord) · \(Model.legacy())", "flavor")
        let modeLabel = label("mode: \(mode)", "mode")
        countLabel.accessibilityIdentifier = "count"
        echoLabel.accessibilityIdentifier = "echo"
        echoLabel.text = "echo: -"
        let button = UIButton(type: .system)
        button.setTitle("Add", for: .normal)
        button.accessibilityIdentifier = "increment"
        button.addTarget(self, action: #selector(add), for: .touchUpInside)
        field.placeholder = "Name"
        field.borderStyle = .roundedRect
        field.accessibilityIdentifier = "name"
        field.delegate = self
        let toggle = UISwitch()
        toggle.accessibilityIdentifier = "toggle"
        // UI tests: system permission alerts (SpringBoard's on iOS), app lifecycle, a screen of gestures
        func action(_ title: String, _ id: String, _ handler: @escaping () -> Void) -> UIButton {
            let b = UIButton(type: .system, primaryAction: UIAction(title: title) { _ in handler() })
            b.accessibilityIdentifier = id
            return b
        }
        permissionLabel.accessibilityIdentifier = "permission"
        permissionLabel.text = "permission: -"
        lifecycleLabel.accessibilityIdentifier = "lifecycle"
        lifecycleLabel.text = "background: 0"
        let notify = action("Notify Me", "notify") { [weak self] in self?.requestNotifications() }
        let camera = action("Use Camera", "camera") { [weak self] in self?.requestCamera() }
        let gestures = action("Gestures", "gestures") { [weak self] in
            self?.navigationController?.pushViewController(GesturesViewController(), animated: true)
        }
        let multitouch = action("Multitouch", "multitouch") { [weak self] in
            self?.navigationController?.pushViewController(MultitouchViewController(), animated: true)
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.backgroundCount += 1
                self.lifecycleLabel.text = "background: \(self.backgroundCount)"
            }
        }
        let stack = UIStackView(arrangedSubviews: [greeting, sums, flavor, modeLabel, countLabel, button, field, echoLabel, toggle,
                                                   notify, camera, gestures, multitouch, permissionLabel, lifecycleLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            field.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        refresh()
        print("HelloToolchain: \(greeting.text!) | \(sums.text!) | \(flavor.text!)")
        let (value, code) = #stringify(Model.mathKitSum() * 2)
        print("HelloToolchain macros: \(code) = \(value), \(Flavor.caseCount) flavors")
    }

    @objc private func add() { model.increment(); refresh() }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { self.permissionLabel.text = "notifications: \(granted ? "allowed" : "denied")" }
        }
    }
    private func requestCamera() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { self.permissionLabel.text = "camera: \(granted ? "allowed" : "denied")" }
        }
    }
    private func refresh() { countLabel.text = "Count: \(model.count)" }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        echoLabel.text = "echo: \(textField.text ?? "")"
        textField.resignFirstResponder()
        return true
    }
}

/// UI tests' gestures: swipes, long press, a slider, taps and drags at coordinates, a scrolling table.
final class GesturesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let status = UILabel()
    private let slider = UISlider()
    private let table = UITableView()
    private let topRow = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Gestures"
        view.backgroundColor = .systemBackground
        status.accessibilityIdentifier = "status"
        status.text = "status: -"
        slider.accessibilityIdentifier = "slider"
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50
        slider.addTarget(self, action: #selector(slid), for: .valueChanged)
        let hold = UIButton(type: .system)
        hold.setTitle("Hold Me", for: .normal)
        hold.accessibilityIdentifier = "hold"
        let press = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        press.minimumPressDuration = 0.5
        hold.addGestureRecognizer(press)
        let swipeArea = UIView()
        swipeArea.accessibilityIdentifier = "swipeArea"
        swipeArea.backgroundColor = .secondarySystemBackground
        for d: UISwipeGestureRecognizer.Direction in [.up, .down, .left, .right] {
            let g = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            g.direction = d
            swipeArea.addGestureRecognizer(g)
        }
        let pad = UIView()
        pad.accessibilityIdentifier = "pad"
        pad.backgroundColor = .tertiarySystemBackground
        pad.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(padTapped(_:))))
        pad.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(padDragged(_:))))
        topRow.accessibilityIdentifier = "topRow"
        topRow.text = "top row: 0"
        table.accessibilityIdentifier = "list"
        table.dataSource = self
        table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        let stack = UIStackView(arrangedSubviews: [status, slider, hold, swipeArea, pad, topRow, table])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            swipeArea.heightAnchor.constraint(equalToConstant: 110),
            pad.heightAnchor.constraint(equalToConstant: 110),
        ])
    }

    @objc private func slid() { status.text = "slider: \(Int(slider.value.rounded()))" }
    @objc private func held(_ g: UILongPressGestureRecognizer) { if g.state == .began { status.text = "long press" } }
    @objc private func swiped(_ g: UISwipeGestureRecognizer) {
        let name = g.direction == .up ? "up" : g.direction == .down ? "down" : g.direction == .left ? "left" : "right"
        status.text = "swipe \(name)"
    }
    @objc private func padTapped(_ g: UITapGestureRecognizer) {
        let p = g.location(in: g.view)
        status.text = "tap \(Int(p.x / 10)) \(Int(p.y / 10))"            // in tens of points
    }
    @objc private func padDragged(_ g: UIPanGestureRecognizer) {
        guard g.state == .ended else { return }
        let t = g.translation(in: g.view)
        status.text = "drag \(Int((t.x / 10).rounded())) \(Int((t.y / 10).rounded()))"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 60 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        c.textLabel?.text = "Row \(indexPath.row)"
        return c
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        topRow.text = "top row: \(table.indexPathsForVisibleRows?.first?.row ?? 0)"
    }
}

/// UI tests' multi-touch gestures (pinch, rotation, two-finger and triple taps), a drag onto a target, a control
/// that fails an accessibility audit (tiny and unlabelled) and the device appearance.
final class MultitouchViewController: UIViewController {
    private let status = UILabel()
    private let appearance = UILabel()
    private let canvas = UIView()
    private let chip = UILabel()
    private let target = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Multitouch"
        view.backgroundColor = .systemBackground
        status.accessibilityIdentifier = "status"
        status.text = "status: -"
        appearance.accessibilityIdentifier = "appearance"
        canvas.accessibilityIdentifier = "canvas"
        canvas.backgroundColor = .secondarySystemBackground
        canvas.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:))))
        canvas.addGestureRecognizer(UIRotationGestureRecognizer(target: self, action: #selector(rotated(_:))))
        let twoFinger = UITapGestureRecognizer(target: self, action: #selector(twoFingerTapped))
        twoFinger.numberOfTouchesRequired = 2
        canvas.addGestureRecognizer(twoFinger)
        let triple = UITapGestureRecognizer(target: self, action: #selector(tripleTapped))
        triple.numberOfTapsRequired = 3
        canvas.addGestureRecognizer(triple)
        for g in canvas.gestureRecognizers ?? [] { g.delegate = self }
        chip.text = "Chip"
        chip.accessibilityIdentifier = "chip"
        chip.textAlignment = .center
        chip.backgroundColor = .systemYellow
        chip.isUserInteractionEnabled = true
        chip.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
        target.text = "Target"
        target.accessibilityIdentifier = "target"
        target.textAlignment = .center
        target.backgroundColor = .systemTeal
        let tiny = UIButton(type: .system)
        tiny.setImage(UIImage(systemName: "info.circle"), for: .normal)
        tiny.accessibilityIdentifier = "tiny"
        tiny.accessibilityLabel = ""
        let row = UIStackView(arrangedSubviews: [chip, target, tiny])
        row.spacing = 40
        row.alignment = .center
        let stack = UIStackView(arrangedSubviews: [status, appearance, canvas, row])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            canvas.heightAnchor.constraint(equalToConstant: 260),
            chip.widthAnchor.constraint(equalToConstant: 80), chip.heightAnchor.constraint(equalToConstant: 60),
            target.widthAnchor.constraint(equalToConstant: 100), target.heightAnchor.constraint(equalToConstant: 60),
            tiny.widthAnchor.constraint(equalToConstant: 20), tiny.heightAnchor.constraint(equalToConstant: 20),
        ])
        showAppearance()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (vc: MultitouchViewController, _) in vc.showAppearance() }
    }

    private func showAppearance() {
        appearance.text = "appearance: \(traitCollection.userInterfaceStyle == .dark ? "dark" : "light")"
    }
    @objc private func pinched(_ g: UIPinchGestureRecognizer) {
        if g.state == .ended { status.text = String(format: "pinch %.1f", g.scale) }
    }
    @objc private func rotated(_ g: UIRotationGestureRecognizer) {
        if g.state == .ended, abs(g.rotation) > 0.2 { status.text = "rotate \(Int((g.rotation * 180 / .pi).rounded()))" }
    }
    @objc private func twoFingerTapped() { status.text = "two-finger tap" }
    @objc private func tripleTapped() { status.text = "triple tap" }
    @objc private func dragged(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: view)
        chip.transform = CGAffineTransform(translationX: t.x, y: t.y)
        guard g.state == .ended else { return }
        let center = chip.superview!.convert(chip.center, to: view)
        let hit = target.superview!.convert(target.frame, to: view).contains(CGPoint(x: center.x + t.x, y: center.y + t.y))
        status.text = hit ? "dropped on target" : "dropped"
        chip.transform = .identity
    }
}

extension MultitouchViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

/// The package macros at work: @CaseCount adds `caseCount`.
@CaseCount
enum Flavor { case vanilla, chocolate, strawberry }

// Previews (Xcode's canvas; on isim they compile and type-check)
#Preview("Toolchain") { ViewController() }
#Preview(traits: .landscapeLeft) {
    let label = UILabel()
    label.text = "landscape"
    return label
}

