import UIKit

/// A custom view configured from IB: user defined runtime attributes (layer.cornerRadius, an @IBInspectable).
final class RoundedView: UIView {
    @IBInspectable var cornerTag: String = "" { didSet { accessibilityValue = cornerTag } }
    private(set) var codedInit = false
    required init?(coder: NSCoder) {           // only init(coder:): IB must not call init(frame:)
        super.init(coder: coder)
        codedInit = true
    }
}

final class ControlsViewController: UIViewController, UIFontPickerViewControllerDelegate {
    @IBOutlet weak var volumeLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var toggle: UISwitch!
    @IBOutlet weak var stepper: UIStepper!
    @IBOutlet weak var segments: UISegmentedControl!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var progress: UIProgressView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var roundedView: RoundedView!
    @IBOutlet var allLabels: [UILabel]!

    override func viewDidLoad() {
        super.viewDidLoad()
        print("controls: viewDidLoad slider=\(slider.value) [\(slider.minimumValue),\(slider.maximumValue)] switch=\(toggle.isOn) "
              + "stepper=\(stepper.value)/\(stepper.maximumValue) segment=\(segments.selectedSegmentIndex)/\(segments.numberOfSegments) "
              + "progress=\(progress.progress) spinning=\(spinner.isAnimating) labels=\(allLabels.count) "
              + "corner=\(roundedView.layer.cornerRadius) tag=\(roundedView.cornerTag) codedInit=\(roundedView.codedInit) "
              + "field=\(nameField.placeholder ?? "nil")")
    }

    private func status(_ s: String) { statusLabel.text = s; print("controls: \(s)") }

    @IBAction func sliderChanged(_ sender: UISlider) { volumeLabel.text = String(format: "Volume %.0f%%", sender.value * 100); status("slider \(String(format: "%.2f", sender.value))") }
    @IBAction func toggled(_ sender: UISwitch) { status("switch \(sender.isOn)") }
    @IBAction func stepped(_ sender: UIStepper) { status("stepper \(Int(sender.value))") }
    @IBAction func segmentChanged(_ sender: UISegmentedControl) { status("segment \(sender.selectedSegmentIndex)") }
    @IBAction func nameChanged(_ sender: UITextField) { status("name \(sender.text ?? "")") }
    @IBAction func apply(_ sender: UIButton) { status("apply tapped (\(sender.configuration?.title ?? sender.currentTitle ?? "?"))") }
    @IBAction func badgeTapped(_ sender: UITapGestureRecognizer) { status("rounded view tapped") }

    @IBAction func openProfile(_ sender: Any) {
        let vc = ProfileViewController(nibName: "ProfileViewController", bundle: nil)
        vc.greeting = "Profile (explicit nib)"
        navigationController?.pushViewController(vc, animated: true)
    }
    @IBAction func openDefaultNib(_ sender: Any) {
        let vc = ProfileViewController()       // nibName nil: the nib named after the class is used
        vc.greeting = "Profile (default nib)"
        present(vc, animated: true)
    }
    @IBAction func openFonts(_ sender: Any) {
        let picker = UIFontPickerViewController()
        picker.delegate = self
        present(picker, animated: true)
    }
    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        guard let d = viewController.selectedFontDescriptor else { return }
        let family = d.object(forKey: .family) as? String ?? "?"
        statusLabel.font = UIFont(descriptor: d, size: 17)
        status("font \(family)")
        viewController.dismiss(animated: true)
    }
    func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController) { status("font picker cancelled") }
}

final class ProfileViewController: UIViewController {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    var greeting = "Profile"
    override func viewDidLoad() {
        super.viewDidLoad()
        nameLabel.text = greeting
        print("profile: viewDidLoad nibName=\(nibName ?? "nil") label=\(nameLabel != nil) button=\(closeButton?.currentTitle ?? "nil")")
    }
    @IBAction func close(_ sender: Any) {
        print("profile: close")
        if presentingViewController != nil { dismiss(animated: true) } else { navigationController?.popViewController(animated: true) }
    }
}
