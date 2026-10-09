// Sample: system pickers and sheets on isim (UIKit) — UIColorPickerViewController (grid, spectrum, sliders, hex,
// saved colors, eyedropper), UIFontPickerViewController (faces, trait and language filters), an action sheet (a
// popover anchored to its button on iPad; tapping outside cancels) and an iPad form sheet sized by
// preferredContentSize (changing it resizes the sheet).
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: PickersViewController())
        window?.makeKeyAndVisible()
        let avenir = UIFont.fontNames(forFamilyName: "Avenir")
        print("fonts: \(UIFont.familyNames.count) families, Avenir \(avenir.count) faces (\(avenir.first ?? "")), Menlo mono \(UIFont(name: "Menlo-Regular", size: 12)?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true), Avenir-Heavy family \(UIFont(name: "Avenir-Heavy", size: 12)?.familyName ?? "nil")")
        return true
    }
}

func hex(_ c: UIColor?) -> String {
    guard let c else { return "nil" }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    c.getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
}

final class PickersViewController: UIViewController, UIColorPickerViewControllerDelegate, UIFontPickerViewControllerDelegate {
    let output = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pickers"
        view.backgroundColor = .systemBackground
        // the lower part of the screen is one color, for the eyedropper
        let patch = UIView()
        patch.backgroundColor = UIColor(red: 1, green: 0.4, blue: 0, alpha: 1)
        patch.accessibilityIdentifier = "patch"
        patch.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(patch)
        NSLayoutConstraint.activate([patch.leadingAnchor.constraint(equalTo: view.leadingAnchor), patch.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                     patch.bottomAnchor.constraint(equalTo: view.bottomAnchor), patch.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4)])
        output.frame = CGRect(x: 20, y: 110, width: 360, height: 30)
        output.accessibilityIdentifier = "output"
        view.addSubview(output)
        let buttons: [(String, (UIButton) -> Void)] = [
            ("color", { [unowned self] _ in
                let p = UIColorPickerViewController()
                p.selectedColor = .systemBlue
                p.delegate = self
                present(p, animated: true)
            }),
            ("font", { [unowned self] _ in presentFonts(UIFontPickerViewController.Configuration()) }),
            ("faces", { [unowned self] _ in
                let c = UIFontPickerViewController.Configuration(); c.includeFaces = true
                presentFonts(c)
            }),
            ("mono", { [unowned self] _ in
                let c = UIFontPickerViewController.Configuration(); c.filteredTraits = .traitMonoSpace
                presentFonts(c)
            }),
            ("greek", { [unowned self] _ in
                let c = UIFontPickerViewController.Configuration()
                c.filteredLanguagesPredicate = UIFontPickerViewController.Configuration.filterPredicate(forFilteredLanguages: ["el"])
                presentFonts(c)
            }),
            ("sheet", { [unowned self] b in
                let a = UIAlertController(title: "Share photo", message: "Choose where to send it", preferredStyle: .actionSheet)
                for t in ["Messages", "Mail"] { a.addAction(UIAlertAction(title: t, style: .default) { _ in print("sheet action \(t)") }) }
                a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in print("sheet cancelled") })
                if let pop = a.popoverPresentationController { pop.sourceView = b; pop.sourceRect = b.bounds }
                print("sheet style \(a.modalPresentationStyle == .popover ? "popover" : "sheet")")
                present(a, animated: true)
            }),
            ("form", { [unowned self] _ in
                let f = FormViewController()
                f.modalPresentationStyle = .formSheet
                f.preferredContentSize = CGSize(width: 420, height: 300)
                present(f, animated: true)
            }),
        ]
        for (i, (name, action)) in buttons.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(name.capitalized, for: .normal)
            b.frame = CGRect(x: 20 + CGFloat(i % 3) * 120, y: 150 + CGFloat(i / 3) * 50, width: 110, height: 40)
            b.accessibilityIdentifier = name
            b.addAction(UIAction { a in action(a.sender as! UIButton) }, for: .primaryActionTriggered)
            view.addSubview(b)
        }
    }
    func presentFonts(_ c: UIFontPickerViewController.Configuration) {
        let p = UIFontPickerViewController(configuration: c)
        p.delegate = self
        present(p, animated: true)
    }
    // color picker
    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        output.text = "color \(hex(color))"
        if !continuously { print("picked color \(hex(color))") }
    }
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) { print("color picker finished \(hex(viewController.selectedColor))") }
    // font picker
    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        let d = viewController.selectedFontDescriptor
        print("picked font \(d?.fontAttributes[.family] as? String ?? "nil") \(d?.fontAttributes[.name] as? String ?? "-") face \(d?.fontAttributes[.face] as? String ?? "-")")
        viewController.dismiss(animated: true)
    }
    func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController) { print("font picker cancelled") }
}

/// an iPad form sheet sized by preferredContentSize
final class FormViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemTeal
        view.accessibilityIdentifier = "form"
        let grow = UIButton(type: .system)
        grow.setTitle("Grow", for: .normal)
        grow.frame = CGRect(x: 20, y: 20, width: 100, height: 40)
        grow.accessibilityIdentifier = "grow"
        grow.addAction(UIAction { [unowned self] _ in preferredContentSize = CGSize(width: 480, height: 360) }, for: .primaryActionTriggered)
        view.addSubview(grow)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("form size \(Int(view.bounds.width))x\(Int(view.bounds.height))")
    }
}
