//
//  ViewController.swift
//  HelloCounterSwift
//
//  The template's empty view controller, filled in with the same counter UI as the
//  Objective-C HelloCounter sample.
//

import UIKit

class ViewController: UIViewController {

    private let countLabel = UILabel()
    private let hintLabel = UILabel()
    private var count = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.backgroundColor = .systemBackground

        let title = UILabel()
        title.text = "Hello from Swift on Linux"
        title.font = .preferredFont(forTextStyle: .title1)
        title.textAlignment = .center

        countLabel.font = .monospacedDigitSystemFont(ofSize: 72, weight: .bold)
        countLabel.textColor = .systemOrange
        countLabel.textAlignment = .center

        hintLabel.font = .preferredFont(forTextStyle: .footnote)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        var config = UIButton.Configuration.filled()
        config.title = "Tap me"
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.baseBackgroundColor = .systemOrange
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 28, bottom: 12, trailing: 28)
        let tap = UIButton(configuration: config, primaryAction: nil)
        tap.addTarget(self, action: #selector(increment(_:)), for: .touchUpInside)

        let reset = UIButton(type: .system)
        reset.setTitle("Reset", for: .normal)
        reset.addTarget(self, action: #selector(resetCount(_:)), for: .touchUpInside)

        let darkLabel = UILabel()
        darkLabel.text = "Dark appearance"
        let darkSwitch = UISwitch()
        darkSwitch.addTarget(self, action: #selector(toggleDark(_:)), for: .valueChanged)
        let darkRow = UIStackView(arrangedSubviews: [darkLabel, darkSwitch])
        darkRow.axis = .horizontal
        darkRow.spacing = 12
        darkRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [title, countLabel, tap, reset, darkRow, hintLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.setCustomSpacing(32, after: reset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            stack.widthAnchor.constraint(equalTo: safe.widthAnchor, constant: -40),
        ])
        updateLabels()
    }

    private func updateLabels() {
        countLabel.text = "\(count)"
        hintLabel.text = count == 0
            ? "Swift · UIKit · running on Linux in isim"
            : "You tapped \(count) time\(count == 1 ? "" : "s")"
    }

    @objc private func increment(_ sender: UIButton) {
        count += 1
        NSLog("HelloCounterSwift: count = %ld", count)
        updateLabels()
    }

    @objc private func resetCount(_ sender: UIButton) {
        count = 0
        updateLabels()
    }

    @objc private func toggleDark(_ sender: UISwitch) {
        view.window?.overrideUserInterfaceStyle = sender.isOn ? .dark : .light
    }
}
