// Sample: UIKit controls on isim — UISlider, UIStepper, UISegmentedControl, UIProgressView,
// UIActivityIndicatorView, UIPageControl, UISwitch and a UIButton with a pop-up UIMenu.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ControlsViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class ControlsViewController: UIViewController {
    let valueLabel = UILabel()
    let slider = UISlider()
    let stepper = UIStepper()
    let segments = UISegmentedControl(items: ["Day", "Week", "Month"])
    let progress = UIProgressView(progressViewStyle: .default)
    let spinner = UIActivityIndicatorView(style: .medium)
    let pages = UIPageControl()
    let toggle = UISwitch()
    let menuButton = UIButton(type: .system)
    var sort = "Name"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let title = UILabel(); title.text = "Controls"; title.font = .systemFont(ofSize: 34, weight: .bold)

        slider.minimumValue = 0; slider.maximumValue = 100; slider.value = 25
        slider.accessibilityIdentifier = "slider"
        slider.addTarget(self, action: #selector(changed(_:)), for: .valueChanged)

        stepper.minimumValue = 0; stepper.maximumValue = 5; stepper.value = 2
        stepper.accessibilityIdentifier = "stepper"
        stepper.addTarget(self, action: #selector(changed(_:)), for: .valueChanged)

        segments.selectedSegmentIndex = 0
        segments.accessibilityIdentifier = "segments"
        segments.addTarget(self, action: #selector(changed(_:)), for: .valueChanged)

        progress.progress = 0.25
        spinner.startAnimating()
        spinner.accessibilityIdentifier = "spinner"

        pages.numberOfPages = 4; pages.currentPage = 1
        pages.accessibilityIdentifier = "pages"
        pages.addTarget(self, action: #selector(changed(_:)), for: .valueChanged)

        toggle.isOn = true
        toggle.accessibilityIdentifier = "toggle"
        toggle.addTarget(self, action: #selector(changed(_:)), for: .valueChanged)

        menuButton.setTitle("Sort: Name", for: .normal)
        menuButton.accessibilityIdentifier = "menu-button"
        menuButton.showsMenuAsPrimaryAction = true
        rebuildMenu()

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        valueLabel.textColor = .secondaryLabel
        valueLabel.accessibilityIdentifier = "values"
        updateLabel()

        let stepperRow = UIStackView(arrangedSubviews: [label("Stepper"), stepper]); stepperRow.spacing = 12
        let toggleRow = UIStackView(arrangedSubviews: [label("Switch"), toggle]); toggleRow.spacing = 12
        let spinnerRow = UIStackView(arrangedSubviews: [label("Loading"), spinner]); spinnerRow.spacing = 12
        let stack = UIStackView(arrangedSubviews: [title, label("Slider"), slider, stepperRow, segments, label("Progress"), progress,
                                                   spinnerRow, pages, toggleRow, menuButton, valueLabel])
        stack.axis = .vertical; stack.spacing = 14; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }
    func label(_ t: String) -> UILabel { let l = UILabel(); l.text = t; l.font = .systemFont(ofSize: 17); return l }

    func rebuildMenu() {
        let options = ["Name", "Date", "Size"].map { name in
            UIAction(title: name, state: name == sort ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.sort = name
                self.menuButton.setTitle("Sort: \(name)", for: .normal)
                print("menu: \(name)")
                self.rebuildMenu(); self.updateLabel()
            }
        }
        let delete = UIAction(title: "Delete All", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in print("menu: delete") }
        menuButton.menu = UIMenu(title: "Sort by", children: [UIMenu(title: "", options: .displayInline, children: options), delete])
    }

    @objc func changed(_ sender: UIControl) {
        progress.progress = slider.value / 100
        print("changed \(sender.accessibilityIdentifier ?? "?")")
        updateLabel()
    }
    func updateLabel() {
        valueLabel.text = "slider=\(Int(slider.value)) stepper=\(Int(stepper.value)) segment=\(segments.selectedSegmentIndex) page=\(pages.currentPage) switch=\(toggle.isOn) sort=\(sort)"
        print(valueLabel.text!)
    }
}
