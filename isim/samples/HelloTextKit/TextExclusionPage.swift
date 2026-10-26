// HelloTextKit, -exclusion: text flowing around NSTextContainer.exclusionPaths (issue #332). A UITextView (TextKit 2)
// wraps its text around a circle (an orange view behind the clear text view) and continues on both sides of it; a
// TextKit 1 stack (NSLayoutManager drawn by TK1View) wraps around a square at its top left corner. The line fragments
// of both are logged ("hex ..." lines: none crosses its path, some sit side by side), with the container's
// lineFragmentRect(forProposedRect:) for a band across the circle, for tests/ui/test_text_exclusion.py.
import UIKit

private func log(_ s: String) { print("hex \(s)") }
private func r0(_ r: CGRect) -> String { String(format: "%.0f,%.0f %.0fx%.0f", r.minX, r.minY, r.width, r.height) }
private let words = "Text flows around shapes on iOS: a text container's exclusion paths cut holes into the area its lines may use, "
    + "so a paragraph wraps around an image or a pull quote and carries on beside it, line after line, until the shape ends "
    + "and the lines take the whole width again. "

final class ExclusionViewController: UIViewController {
    let text = UITextView(frame: CGRect(x: 16, y: 70, width: 360, height: 330))
    let circle = UIView(frame: CGRect(x: 16 + 110, y: 70 + 90, width: 140, height: 140))
    let tk1 = TK1View(frame: CGRect(x: 16, y: 420, width: 360, height: 200))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        circle.backgroundColor = .systemOrange
        circle.layer.cornerRadius = 70
        circle.accessibilityIdentifier = "circle"
        view.addSubview(circle)
        text.backgroundColor = .clear
        text.isEditable = false
        text.font = .systemFont(ofSize: 15)
        text.textContainerInset = .zero
        text.text = words + words + words
        text.accessibilityIdentifier = "flow"
        // container coordinates: the text view's, less its inset (zero here)
        text.textContainer.exclusionPaths = [UIBezierPath(ovalIn: CGRect(x: 110, y: 90, width: 140, height: 140))]
        view.addSubview(text)

        let square = CGRect(x: 0, y: 0, width: 90, height: 70)
        tk1.container.size = CGSize(width: 360, height: 200)
        tk1.container.exclusionPaths = [UIBezierPath(rect: square)]
        tk1.storage.setAttributedString(NSAttributedString(string: words + words, attributes: [.font: UIFont.systemFont(ofSize: 13)]))
        tk1.accessibilityIdentifier = "tk1"
        let box = UIView(frame: square.offsetBy(dx: tk1.frame.minX, dy: tk1.frame.minY))
        box.backgroundColor = .systemTeal
        view.addSubview(tk1)
        view.addSubview(box)

        // TextKit 1: the line fragments around the square
        let lm = tk1.layoutManager
        var lines: [CGRect] = []
        lm.enumerateLineFragments(forGlyphRange: lm.glyphRange(for: tk1.container)) { rect, used, _, _, _ in lines.append(used) }
        let crossing = lines.filter { $0.insetBy(dx: 1, dy: 1).intersects(square) }.count
        let beside = lines.filter { $0.minX >= square.maxX }.count
        log("tk1 simple \(tk1.container.isSimpleRectangularTextContainer) lines \(lines.count) crossing \(crossing) beside \(beside) first \(r0(lines.first ?? .zero))")
        let usedRect = lm.usedRect(for: tk1.container)
        log("tk1 laid \(lm.characterIndexForGlyph(at: NSMaxRange(lm.glyphRange(for: tk1.container)))) of \(tk1.storage.length) used \(r0(usedRect))")
        // the point under a line beside the square finds a character on that line
        if let l = lines.first(where: { $0.minX >= square.maxX }) {
            let i = lm.characterIndex(for: CGPoint(x: l.midX, y: l.midY), in: tk1.container, fractionOfDistanceBetweenInsertionPoints: nil)
            var lr = NSRange()
            let r = lm.lineFragmentUsedRect(forGlyphAt: lm.glyphIndexForCharacter(at: i), effectiveRange: &lr)
            log("tk1 hit same line \(abs(r.minY - l.minY) < 1 && abs(r.minX - l.minX) < 1)")
        }

        // the container's line fragment for a band across the circle: the free span left of it, the rest remaining
        var remaining = CGRect.zero
        let band = CGRect(x: 0, y: 150, width: 360, height: 18)
        let frag = text.textContainer.lineFragmentRect(forProposedRect: band, at: 0, writingDirection: .leftToRight, remaining: &remaining)
        log("proposed \(r0(frag)) remaining \(r0(remaining)) simple \(text.textContainer.isSimpleRectangularTextContainer)")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // TextKit 2: the text view's line fragments, in container coordinates
        guard let tlm = text.textLayoutManager else { log("tk2 none"); return }
        let oval = UIBezierPath(ovalIn: CGRect(x: 110, y: 90, width: 140, height: 140))
        var lines: [CGRect] = []
        tlm.enumerateTextLayoutFragments(from: tlm.documentRange.location, options: [.ensuresLayout]) { f in
            for l in f.textLineFragments where l.characterRange.length > 0 {
                let b = l.typographicBounds.offsetBy(dx: f.layoutFragmentFrame.minX, dy: f.layoutFragmentFrame.minY)
                lines.append(b)
            }
            return true
        }
        // a line crosses the circle when a point of its text box is inside the oval
        let crossing = lines.filter { b in
            stride(from: b.minX + 2, to: b.maxX - 2, by: 2).contains { oval.contains(CGPoint(x: $0, y: b.midY)) }
        }.count
        let rows = Dictionary(grouping: lines, by: { Int($0.minY.rounded()) })
        let sideBySide = rows.values.filter { $0.count > 1 }.count
        log("tk2 lines \(lines.count) crossing \(crossing) rows with two \(sideBySide)")
    }
}
