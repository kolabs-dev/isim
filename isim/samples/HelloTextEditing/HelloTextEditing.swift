// Sample: text editing on isim — UITextInput (positions, ranges, caret and selection rects), selection gestures
// (double tap selects a word, long press shows the loupe), the edit menu (Cut / Copy / Paste / Select All / Replace…),
// hardware keyboard selection (Shift+arrows, Cmd/Ctrl+C/V), marked text from the IME, keyboards in other languages with
// accent popups, the emoji keyboard, the predictive bar and autocorrection, UITextChecker and UIEditMenuInteraction.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = EditingViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class EditingViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate, UIEditMenuInteractionDelegate {
    let notes = UITextView(), field = UITextField(), card = UILabel()
    var lastSelection = NSRange(location: NSNotFound, length: 0)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let w = view.bounds.width - 40
        notes.frame = CGRect(x: 20, y: 80, width: w, height: 120)
        notes.font = .systemFont(ofSize: 20)
        notes.text = "The quick brown fox jumps over the lazy dog"
        notes.layer.borderWidth = 0.5; notes.layer.borderColor = UIColor.separator.cgColor; notes.layer.cornerRadius = 8
        notes.accessibilityIdentifier = "notes"
        notes.delegate = self
        view.addSubview(notes)

        field.frame = CGRect(x: 20, y: 215, width: w, height: 40)
        field.borderStyle = .roundedRect
        field.placeholder = "Type here"
        field.accessibilityIdentifier = "field"
        field.delegate = self
        field.addTarget(self, action: #selector(fieldChanged), for: .editingChanged)
        view.addSubview(field)

        card.frame = CGRect(x: 20, y: 270, width: w, height: 44)
        card.text = "Tap for a custom edit menu"
        card.textAlignment = .center
        card.backgroundColor = .systemYellow.withAlphaComponent(0.3)
        card.isUserInteractionEnabled = true
        card.accessibilityIdentifier = "card"
        card.addInteraction(UIEditMenuInteraction(delegate: self))
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:))))
        view.addSubview(card)

        // UITextInput geometry (the test taps these points)
        if let start = notes.position(from: notes.beginningOfDocument, offset: 10) {
            let r = notes.caretRect(for: start)
            let p = notes.convert(CGPoint(x: r.midX + 12, y: r.midY), to: nil)
            print(String(format: "brown at %.0f %.0f", p.x, p.y))
        }
        // UITextChecker
        let checker = UITextChecker(), sample = "Ths is a tst of teh checker"
        var from = 0, misspelled: [String] = []
        while true {
            let r = checker.rangeOfMisspelledWord(in: sample, range: NSRange(location: 0, length: (sample as NSString).length), startingAt: from, wrap: false, language: "en_US")
            if r.location == NSNotFound { break }
            let word = (sample as NSString).substring(with: r)
            misspelled.append("\(word)->\(checker.guesses(forWordRange: r, in: sample, language: "en_US")?.first ?? "?")")
            from = r.location + r.length
        }
        print("misspelled: \(misspelled.joined(separator: " "))")
        print("completions for 'hel': \((checker.completions(forPartialWordRange: NSRange(location: 0, length: 3), in: "hel", language: "en_US") ?? []).prefix(3).joined(separator: ","))")
        print("input modes: \(UITextInputMode.activeInputModes.compactMap { $0.primaryLanguage }.joined(separator: ","))")
    }

    // MARK: delegates
    func textViewDidChangeSelection(_ textView: UITextView) {
        let r = textView.selectedRange
        guard r != lastSelection else { return }
        lastSelection = r
        if r.length > 0, let range = textView.selectedTextRange { print("selected \"\(textView.text(in: range) ?? "")\" (\(r.location)+\(r.length))") }
        else { print("caret at \(r.location)") }
    }
    func textViewDidChange(_ textView: UITextView) {
        if let marked = textView.markedTextRange { print("composing \"\(textView.text(in: marked) ?? "")\"") }
        else { print("notes: \(textView.text ?? "")") }
    }
    @objc func fieldChanged() { print("field: \(field.text ?? "")") }

    // MARK: custom edit menu
    @objc func cardTapped(_ g: UITapGestureRecognizer) {
        guard let i = card.interactions.first(where: { $0 is UIEditMenuInteraction }) as? UIEditMenuInteraction else { return }
        i.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: g.location(in: card)))
    }
    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
        UIMenu(children: [UIAction(title: "Hello") { _ in print("menu action Hello") }, UIAction(title: "Share") { _ in print("menu action Share") }])
    }
}
