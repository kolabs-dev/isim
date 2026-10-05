// A small custom keyboard extension (UIInputViewController) used by isim's keyboard test.
import UIKit

class KeyboardViewController: UIInputViewController {
    private var deleteTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1) }
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 6
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            row.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            row.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            view.heightAnchor.constraint(equalToConstant: 60),
        ])
        for text in ["1", "2", "3"] {
            let key = makeKey()
            key.setTitle(text, for: .normal)
            key.accessibilityIdentifier = "key-\(text)"
            key.addAction(UIAction { [weak self] _ in self?.textDocumentProxy.insertText(text) }, for: .touchUpInside)
            row.addArrangedSubview(key)
        }
        let delete = makeKey()
        delete.setImage(UIImage(systemName: "delete.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20)), for: .normal)
        delete.accessibilityIdentifier = "key-delete"
        delete.accessibilityLabel = "Delete"
        delete.addTarget(self, action: #selector(deleteOnce), for: .touchUpInside)
        delete.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(holdDelete(_:))))
        row.addArrangedSubview(delete)
        let hide = makeKey()
        hide.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        hide.accessibilityIdentifier = "key-hide"
        hide.addTarget(self, action: #selector(dismissKeyboard), for: .touchUpInside)
        row.addArrangedSubview(hide)
    }

    private func makeKey() -> UIButton {
        let key = UIButton(type: .custom)
        key.backgroundColor = .white
        key.setTitleColor(.black, for: .normal)
        key.tintColor = .black
        key.titleLabel?.font = .systemFont(ofSize: 24)
        key.layer.cornerRadius = 6
        key.layer.shadowColor = UIColor.black.cgColor
        key.layer.shadowOpacity = 0.2
        key.layer.shadowOffset = CGSize(width: 0, height: 1)
        return key
    }

    @objc private func deleteOnce() { textDocumentProxy.deleteBackward() }

    @objc private func holdDelete(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            NSLog("HelloKeyboard: long press began")
            deleteOnce()
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.deleteOnce() }
            deleteTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        case .ended, .cancelled, .failed:
            NSLog("HelloKeyboard: long press ended")
            deleteTimer?.invalidate()
            deleteTimer = nil
        default: break
        }
    }
}
