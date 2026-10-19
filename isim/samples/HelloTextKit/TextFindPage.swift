// HelloTextKit, -find: text interactions for a custom text input and find and replace (#9), each logged with "tf".
// - Canvas: a view with its own text storage adopting UITextInput, given the system's gestures by UITextInteraction
//   (a tap places the cursor, a double tap selects a word) and its cursor / selection by the interaction's
//   selection display; the loupe session and the drop position animator
// - Notes: a text view with the find interaction (the navigator: count, next, replace all; Cmd+F)
import UIKit

private func log(_ s: String) { print("tf \(s)") }

// MARK: - a custom text input (one line, fixed-width characters)
private final class Pos: UITextPosition { let i: Int; init(_ i: Int) { self.i = i } }
private final class Rng: UITextRange {
    let a: Pos, b: Pos
    init(_ a: Int, _ b: Int) { self.a = Pos(min(a, b)); self.b = Pos(max(a, b)) }
    override var start: UITextPosition { a }
    override var end: UITextPosition { b }
    override var isEmpty: Bool { a.i == b.i }
}
private final class SelRect: UITextSelectionRect {
    let r: CGRect
    init(_ r: CGRect) { self.r = r }
    override var rect: CGRect { r }
}
private final class Canvas: UIView, UITextInput {
    var text = "hello wide world"
    var sel = Rng(0, 0)
    let cw: CGFloat = 12, lineH: CGFloat = 24
    weak var inputDelegate: UITextInputDelegate?
    lazy var tokenizer: UITextInputTokenizer = UITextInputStringTokenizer(textInput: self)
    override var canBecomeFirstResponder: Bool { true }
    override func draw(_ rect: CGRect) {
        (text as NSString).draw(at: CGPoint(x: 0, y: 2), withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 20, weight: .regular), .foregroundColor: UIColor.label])
    }
    // UIKeyInput
    var hasText: Bool { !text.isEmpty }
    func insertText(_ t: String) { replace(sel, withText: t) }
    func deleteBackward() { if sel.isEmpty, sel.a.i > 0 { sel = Rng(sel.a.i - 1, sel.a.i) }; replace(sel, withText: "") }
    // UITextInput
    func text(in range: UITextRange) -> String? { let r = range as! Rng; return String(Array(text)[r.a.i..<r.b.i]) }
    func replace(_ range: UITextRange, withText t: String) {
        let r = range as! Rng; var c = Array(text); c.replaceSubrange(r.a.i..<r.b.i, with: Array(t)); text = String(c)
        sel = Rng(r.a.i + t.count, r.a.i + t.count); setNeedsDisplay()
    }
    var selectedTextRange: UITextRange? { get { sel } set { if let r = newValue as? Rng { sel = r; log("canvas selection \(sel.a.i)-\(sel.b.i)") } } }
    var markedTextRange: UITextRange? { nil }
    var markedTextStyle: [NSAttributedString.Key: Any]?
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {}
    func unmarkText() {}
    var beginningOfDocument: UITextPosition { Pos(0) }
    var endOfDocument: UITextPosition { Pos(text.count) }
    func textRange(from a: UITextPosition, to b: UITextPosition) -> UITextRange? { Rng((a as! Pos).i, (b as! Pos).i) }
    func position(from p: UITextPosition, offset: Int) -> UITextPosition? { let i = (p as! Pos).i + offset; return i < 0 || i > text.count ? nil : Pos(i) }
    func position(from p: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        position(from: p, offset: direction == .left ? -offset : offset)
    }
    func compare(_ a: UITextPosition, to b: UITextPosition) -> ComparisonResult {
        let x = (a as! Pos).i, y = (b as! Pos).i; return x < y ? .orderedAscending : x > y ? .orderedDescending : .orderedSame
    }
    func offset(from a: UITextPosition, to b: UITextPosition) -> Int { (b as! Pos).i - (a as! Pos).i }
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? { direction == .left ? range.start : range.end }
    func characterRange(byExtending p: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? { nil }
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection { .leftToRight }
    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
    func firstRect(for range: UITextRange) -> CGRect { let r = range as! Rng; return CGRect(x: CGFloat(r.a.i) * cw, y: 0, width: CGFloat(r.b.i - r.a.i) * cw, height: lineH) }
    func caretRect(for p: UITextPosition) -> CGRect { CGRect(x: CGFloat((p as! Pos).i) * cw, y: 2, width: 2, height: lineH - 4) }
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { [SelRect(firstRect(for: range))] }
    func closestPosition(to point: CGPoint) -> UITextPosition? { Pos(max(0, min(text.count, Int((point.x / cw).rounded())))) }
    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? { closestPosition(to: point) }
    func characterRange(at point: CGPoint) -> UITextRange? { nil }
}

final class FindViewController: UIViewController, UITextInteractionDelegate {
    private let canvas = Canvas(), notes = UITextView()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Find"
        view.backgroundColor = .systemBackground
        canvas.frame = CGRect(x: 16, y: 110, width: 300, height: 28); canvas.accessibilityIdentifier = "canvas"; canvas.backgroundColor = .secondarySystemBackground
        view.addSubview(canvas)
        let interaction = UITextInteraction(for: .editable)
        interaction.delegate = self
        canvas.addInteraction(interaction)
        log("interaction mode \(interaction.textInteractionMode == .editable) gestures \(interaction.gesturesForFailureRequirements.count) input \(interaction.textInput === canvas)")
        notes.frame = CGRect(x: 16, y: 160, width: 340, height: 140); notes.accessibilityIdentifier = "notes"
        notes.font = .systemFont(ofSize: 17)
        notes.text = "the cat and the dog and the bird"
        if #available(iOS 16.0, *) { notes.isFindInteractionEnabled = true }
        view.addSubview(notes)
        let find = UIButton(type: .system); find.setTitle("Find", for: .normal); find.accessibilityIdentifier = "find"
        find.frame = CGRect(x: 16, y: 310, width: 80, height: 44)
        find.addAction(UIAction { [weak self] _ in
            if #available(iOS 16.0, *) {
                self?.notes.findInteraction?.searchText = "the"
                self?.notes.findInteraction?.presentFindNavigator(showingReplace: true)
            }
        }, for: .touchUpInside)
        view.addSubview(find)
        let check = UIButton(type: .system); check.setTitle("Check", for: .normal); check.accessibilityIdentifier = "check"
        check.frame = CGRect(x: 110, y: 310, width: 80, height: 44)
        check.addAction(UIAction { [weak self] _ in self?.report() }, for: .touchUpInside)
        view.addSubview(check)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 17.0, *) {
            let loupe = UITextLoupeSession.begin(at: CGPoint(x: 20, y: 10), fromSelectionWidgetView: nil, in: canvas)
            loupe?.move(to: CGPoint(x: 40, y: 10), withCaretRect: .null, trackingCaret: false)
            loupe?.invalidate()
            log("loupe \(loupe != nil)")
            let cursor = UIStandardTextCursorView(frame: .zero)
            canvas.addSubview(cursor)
            let animator = UITextCursorDropPositionAnimator(textCursorView: cursor, textInput: canvas)
            animator.placeCursor(at: canvas.position(from: canvas.beginningOfDocument, offset: 5)!, animated: false)
            log("drop cursor x \(Int(cursor.frame.minX))")
            cursor.removeFromSuperview()
        }
        log("ready")
    }
    func report() {
        if #available(iOS 16.0, *) {
            let s = notes.findInteraction?.activeFindSession
            log("notes \(notes.text ?? "") session \(s != nil) visible \(notes.findInteraction?.isFindNavigatorVisible ?? false)")
        }
    }
    func interactionWillBegin(_ interaction: UITextInteraction) { log("interaction will begin") }
    func interactionDidEnd(_ interaction: UITextInteraction) { log("interaction did end") }
}
