// HelloTextKit, -extras: text field, text view, responder, text input and keyboard members from the documentation sweep (#9),
// each logged with "tx".
// - Fields: left and right views, the clear button, a subclass that pads its text rect, an attributed placeholder,
//   default text attributes, a background image, math expression completion (12*3= offers 36)
// - Text view: a rounded border, text highlights (a colour scheme, a subclass drawing them), money and physical value
//   detection, alignment and attribute conversion edit actions, inserting attributed text, attributed text in a range
// - Responder: an input view controller, reloadInputViews, remote control events, the input assistant item (iPad
//   shortcuts bar), F-key commands, the text input mode
// - Keyboard: the supplementary lexicon, grammar checking, text placeholders, the text input context
import UIKit

private func log(_ s: String) { print("tx \(s)") }

private final class PaddedField: UITextField {
    override func textRect(forBounds bounds: CGRect) -> CGRect { bounds.insetBy(dx: 24, dy: 4) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { bounds.insetBy(dx: 24, dy: 4) }
}
/* a field whose keyboard is an input view controller's view, with a remembered keyboard context */
private final class PickerField: UITextField {
    let controller: UIInputViewController = {
        let c = UIInputViewController()
        let v = UIInputView(frame: CGRect(x: 0, y: 0, width: 320, height: 180), inputViewStyle: .keyboard)
        let b = UIButton(type: .system); b.setTitle("Pick", for: .normal); b.frame = CGRect(x: 20, y: 20, width: 80, height: 44)
        b.accessibilityIdentifier = "pick"
        v.addSubview(b)
        c.inputView = v
        return c
    }()
    var swapped = false
    override var inputViewController: UIInputViewController? { swapped ? nil : controller }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        (controller.inputView?.subviews.first as? UIButton)?.addAction(UIAction { [weak self] _ in self?.pick() }, for: .touchUpInside)
    }
    /* the keyboard comes back: the input views are read again */
    func pick() {
        text = "picked"; swapped = true
        log("picked")
        reloadInputViews()
    }
    override var textInputContextIdentifier: String? { "dev.isim.picker" }
}
private final class HighlightTextView: UITextView {
    var drawn = 0
    @available(iOS 18.0, *)
    override func drawTextHighlightBackground(for textRange: UITextRange, origin: CGPoint) {
        drawn += 1
        if drawn == 1 { log("highlight drawn for \(text(in: textRange) ?? "")") }
        super.drawTextHighlightBackground(for: textRange, origin: origin)
    }
}

final class TextViewController: UIViewController {
    private let search = UITextField(), padded = PaddedField(), fancy = UITextField(), math = UITextField(), picker = PickerField()
    private let notes = HighlightTextView(), detect = UITextView()

    override var canBecomeFirstResponder: Bool { true }
    override var keyCommands: [UIKeyCommand]? { [UIKeyCommand(title: "Help", action: #selector(help(_:)), input: UIKeyCommand.f1)] }
    @objc func help(_ sender: UIKeyCommand) { log("f1 help localized \(sender.allowsAutomaticLocalization)") }
    override func remoteControlReceived(with event: UIEvent?) { log("remote control \(event?.subtype.rawValue ?? -1) type \(event?.type == .remoteControl)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Text"
        view.backgroundColor = .systemBackground
        var y: CGFloat = 110
        func place(_ v: UIView, _ h: CGFloat, _ id: String) { v.frame = CGRect(x: 16, y: y, width: 340, height: h); v.accessibilityIdentifier = id; view.addSubview(v); y += h + 10 }

        // overlays and the clear button
        search.borderStyle = .roundedRect; search.placeholder = "Search"
        let glass = UIImageView(image: UIImage(systemName: "magnifyingglass")); glass.frame = CGRect(x: 0, y: 0, width: 28, height: 20); glass.contentMode = .center
        search.leftView = glass; search.leftViewMode = .always
        let info = UIButton(type: .infoLight); info.frame = CGRect(x: 0, y: 0, width: 30, height: 30); info.accessibilityIdentifier = "search-info"
        search.rightView = info; search.rightViewMode = .unlessEditing
        search.clearButtonMode = .whileEditing
        search.text = "isim"
        place(search, 36, "search")
        // padding through textRect(forBounds:)
        padded.borderStyle = .line; padded.placeholder = "Padded"
        place(padded, 36, "padded")
        // attributed placeholder, default attributes, background image
        fancy.attributedPlaceholder = NSAttributedString(string: "Orange placeholder", attributes: [.foregroundColor: UIColor.systemOrange])
        fancy.defaultTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: UIColor.systemIndigo]
        fancy.borderStyle = .none
        fancy.background = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { c in UIColor.systemYellow.withAlphaComponent(0.3).setFill(); c.fill(CGRect(x: 0, y: 0, width: 10, height: 10)) }
        place(fancy, 36, "fancy")
        // math completion
        math.borderStyle = .roundedRect; math.placeholder = "Math"
        if #available(iOS 18.0, *) { math.mathExpressionCompletionType = .yes }
        math.addAction(UIAction { [weak self] _ in
            DispatchQueue.main.async { log("math input mode \(self?.math.textInputMode?.primaryLanguage ?? "none")") }
        }, for: .editingDidBegin)
        place(math, 36, "math")
        picker.borderStyle = .roundedRect; picker.placeholder = "Picker"
        place(picker, 36, "picker")
        // highlights and a rounded border
        notes.borderStyle = .roundedRect
        notes.font = .systemFont(ofSize: 17)
        notes.allowsEditingTextAttributes = true
        let a = NSMutableAttributedString(string: "Remember the milk and the bread", attributes: [.font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor.label])
        if #available(iOS 18.0, *) {
            a.addAttributes([.textHighlightStyle: NSAttributedString.TextHighlightStyle.default, .textHighlightColorScheme: NSAttributedString.TextHighlightColorScheme.pink],
                            range: NSRange(location: 13, length: 4))
        }
        notes.attributedText = a
        place(notes, 90, "notes")
        // money and physical values
        detect.isEditable = false
        detect.dataDetectorTypes = [.money, .physicalValue]
        detect.font = .systemFont(ofSize: 17)
        detect.text = "It costs $12.50 and weighs 3 kg."
        place(detect, 60, "detect")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let b = search.bounds
        log("search text rect x \(Int(search.textRect(forBounds: b).minX)) left view \(Int(search.leftViewRect(forBounds: b).width)) right view \(Int(search.rightViewRect(forBounds: b).minX)) shown \(info(search.rightView))")
        log("padded text rect x \(Int(padded.textRect(forBounds: padded.bounds).minX)) placeholder \(Int(padded.placeholderRect(forBounds: padded.bounds).minX))")
        log("fancy font \(fancy.font?.pointSize ?? 0) placeholder \(fancy.attributedPlaceholder?.string ?? "-") attributed \(fancy.attributedText?.length ?? -1)")
        // edit actions on the text view
        notes.selectedRange = NSRange(location: 0, length: 8)
        if #available(iOS 26.0, *) {
            log("can align \(notes.canPerformAction(#selector(UIResponderStandardEditActions.alignCenter(_:)), withSender: nil))")
            notes.alignCenter(nil)
        }
        notes.updateTextAttributes { attrs in var a = attrs; a[.font] = UIFont.boldSystemFont(ofSize: 17); return a }
        let ps = notes.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let bold = (notes.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
        log("aligned \(ps?.alignment == .center) bold \(bold)")
        if #available(iOS 18.0, *) {
            let r = notes.textRange(from: notes.beginningOfDocument, to: notes.position(from: notes.beginningOfDocument, offset: 8)!)!
            log("attributed in range \(notes.attributedText(in: r).string)")
            notes.selectedRange = NSRange(location: notes.text.count, length: 0)
            notes.insertAttributedText(NSAttributedString(string: "!", attributes: [.foregroundColor: UIColor.systemRed]))
            log("inserted \(notes.text.hasSuffix("!")) red \((notes.textStorage.attribute(.foregroundColor, at: notes.text.count - 1, effectiveRange: nil) as? UIColor) == UIColor.systemRed)")
        }
        if #available(iOS 26.0, *) { log("selected ranges \(notes.selectedRanges.count)") }
        // text placeholders, the input context, the lexicon, grammar
        let p = notes.insertTextPlaceholder(with: CGSize(width: 40, height: 20))
        log("placeholder rects \(p.rects.count)")
        notes.remove(p)
        UITextInputContext.current().isHardwareKeyboardInputExpected = true
        log("hardware expected \(UITextInputContext.current().isHardwareKeyboardInputExpected)")
        UIInputViewController().requestSupplementaryLexicon { lex in
            log("lexicon \(lex.entries.map { "\($0.userInput)=\($0.documentText)" }.joined(separator: ","))")
        }
        if #available(iOS 26.0, *) {
            UITextChecker().requestGrammarChecking(of: "i saw a apple. the the end", range: NSRange(location: 0, length: 26), waitForAllResults: true) { results in
                log("grammar \(results.count) fixes \(results.compactMap { ($0.grammarDetails?.first?[NSGrammarCorrections] as? [String])?.first }.joined(separator: ","))")
            }
        }
        // remote control events
        UIApplication.shared.beginReceivingRemoteControlEvents()
        becomeFirstResponder()
        log("input mode \(textInputMode?.primaryLanguage ?? "none") assistant hides \(math.inputAssistantItem.allowsHidingShortcuts)")
        // the iPad shortcuts bar: a Bold item for the math field
        let bold2 = UIBarButtonItem(title: "Bold", primaryAction: UIAction { _ in log("assistant bold") })
        bold2.accessibilityIdentifier = "bold"
        math.inputAssistantItem.leadingBarButtonGroups = [UIBarButtonItemGroup(barButtonItems: [bold2], representativeItem: nil)]
        log("ready")
    }
    func info(_ v: UIView?) -> Bool { v?.superview != nil }
}
