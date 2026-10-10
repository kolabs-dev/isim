// Sample: TextKit on isim (UIKit) — TextKit 1 (NSTextStorage + NSLayoutManager + NSTextContainer laid out and drawn by
// a custom view: line fragments, glyph and character queries, bounding rects; the storage delegate on edits), an
// NSTextStorage subclass with its own backing store highlighting #tags in a TextKit 1 text view, TextKit 2 (a text
// view's NSTextLayoutManager / NSTextContentStorage: layout fragments, line fragments, text segments, rendering
// attributes), an inline image attachment, attachment view providers with the iOS 27 reuse policies and the layout
// manager delegate's provider cache, a standalone viewport layout controller delegate, and the switch to TextKit 1.
import UIKit

func log(_ s: String) { print("htk \(s)") }
func r1(_ v: CGFloat) -> String { String(format: "%.0f", v) }
func rect(_ r: CGRect) -> String { "\(r1(r.minX)),\(r1(r.minY)) \(r1(r.width))x\(r1(r.height))" }

/// draws a TextKit 1 stack (glyphs and backgrounds) at the container origin
final class TK1View: UIView {
    let storage = NSTextStorage()
    let layoutManager = NSLayoutManager()
    let container = NSTextContainer(size: CGSize(width: 180, height: .greatestFiniteMagnitude))
    override init(frame: CGRect) {
        super.init(frame: frame)
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        backgroundColor = .systemGray6
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        let range = layoutManager.glyphRange(for: container)
        layoutManager.drawBackground(forGlyphRange: range, at: .zero)
        layoutManager.drawGlyphs(forGlyphRange: range, at: .zero)
    }
}

/// an NSTextStorage with its own backing store that colours #tags
final class TagStorage: NSTextStorage {
    private let backing = NSMutableAttributedString()
    override var string: String { backing.string }
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        backing.attributes(at: location, effectiveRange: range)
    }
    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backing.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
        endEditing()
    }
    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }
    override func processEditing() {
        let all = NSRange(location: 0, length: (string as NSString).length)
        backing.removeAttribute(.foregroundColor, range: all)
        let rx = try! NSRegularExpression(pattern: "#\\w+")
        for m in rx.matches(in: string, range: all) { backing.addAttribute(.foregroundColor, value: UIColor.systemRed, range: m.range) }
        edited(.editedAttributes, range: all, changeInLength: 0)
        super.processEditing()
    }
}

/// an attachment's view: a coloured square that counts how often it was made
var madeViews = 0
final class BadgeProvider: NSTextAttachmentViewProvider {
    override func loadView() {
        madeViews += 1
        let v = UIView()
        v.backgroundColor = .systemOrange
        v.accessibilityIdentifier = "badge-\(madeViews)"
        view = v
    }
}

/// a standalone TextKit 2 stack whose viewport delegate draws each fragment into its own layer
final class FragmentsView: UIView, NSTextViewportLayoutControllerDelegate {
    let contentStorage = NSTextContentStorage()
    let layoutManager = NSTextLayoutManager()
    var configured = 0
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentStorage.addTextLayoutManager(layoutManager)
        layoutManager.textContainer = NSTextContainer(size: CGSize(width: frame.width, height: 0))
        layoutManager.textViewportLayoutController.delegate = self
        backgroundColor = .systemGray6
    }
    required init?(coder: NSCoder) { fatalError() }
    func viewportBounds(for c: NSTextViewportLayoutController) -> CGRect { bounds }
    func textViewportLayoutControllerWillLayout(_ c: NSTextViewportLayoutController) { configured = 0; layer.sublayers?.forEach { $0.removeFromSuperlayer() } }
    func textViewportLayoutController(_ c: NSTextViewportLayoutController, configureRenderingSurfaceFor f: NSTextLayoutFragment) {
        configured += 1
        let l = FragmentLayer(fragment: f)
        layer.addSublayer(l)
        l.setNeedsDisplay()
    }
    func textViewportLayoutControllerDidLayout(_ c: NSTextViewportLayoutController) {
        log("viewport configured \(configured) range \(c.viewportRange.map { contentStorage.offset(from: contentStorage.documentRange.location, to: $0.endLocation) } ?? -1)")
    }
    override func layoutSubviews() { super.layoutSubviews(); layoutManager.textViewportLayoutController.layoutViewport() }
}
final class FragmentLayer: CALayer {
    let fragment: NSTextLayoutFragment
    init(fragment: NSTextLayoutFragment) { self.fragment = fragment; super.init(); frame = fragment.layoutFragmentFrame }
    override init(layer: Any) { fragment = (layer as! FragmentLayer).fragment; super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(in ctx: CGContext) { fragment.draw(at: .zero, in: ctx) }
}

final class Delegate: NSObject, NSTextLayoutManagerDelegate {
    var cached: [ObjectIdentifier: NSTextAttachmentViewProvider] = [:]
    @available(iOS 27, *)
    func textLayoutManager(_ m: NSTextLayoutManager, cacheTextAttachmentViewProvider p: NSTextAttachmentViewProvider, for a: NSTextAttachment) {
        cached[ObjectIdentifier(a)] = p
    }
    @available(iOS 27, *)
    func textLayoutManager(_ m: NSTextLayoutManager, retrieveCachedTextAttachmentViewProviderFor a: NSTextAttachment) -> NSTextAttachmentViewProvider? {
        cached[ObjectIdentifier(a)]
    }
}

final class ViewController: UIViewController {
    let tk1 = TK1View(frame: CGRect(x: 10, y: 60, width: 180, height: 150))
    let tagsView: UITextView = {
        let storage = TagStorage()
        let lm = NSLayoutManager(); storage.addLayoutManager(lm)
        let c = NSTextContainer(size: .zero); lm.addTextContainer(c)
        let tv = UITextView(frame: CGRect(x: 200, y: 60, width: 180, height: 70), textContainer: c)
        tv.font = .systemFont(ofSize: 17)
        tv.accessibilityIdentifier = "tags"
        return tv
    }()
    let tk2 = UITextView(frame: CGRect(x: 200, y: 140, width: 180, height: 70))
    let attachments = UITextView(frame: CGRect(x: 10, y: 220, width: 180, height: 120))
    let keeper = UITextView(frame: CGRect(x: 200, y: 220, width: 180, height: 120))
    let fragments = FragmentsView(frame: CGRect(x: 10, y: 350, width: 370, height: 90))
    let delegate = Delegate()

    override func viewDidLoad() {
        view.backgroundColor = .systemBackground
        for v in [tk1, tagsView, tk2, attachments, keeper, fragments] as [UIView] { view.addSubview(v) }
        textKit1()
        tagsView.text = "Hello #isim"
        textKit2()
        attachmentViews()
        fragments.contentStorage.attributedString = NSAttributedString(string: "One\nTwo\nThree\nFour", attributes: [.font: UIFont.systemFont(ofSize: 15)])
        let buttons: [(String, Selector)] = [("Edit", #selector(edit)), ("Scroll", #selector(scroll)), ("Switch", #selector(switchKit))]
        for (i, (name, sel)) in buttons.enumerated() {
            let b = UIButton(type: .system); b.setTitle(name, for: .normal)
            b.frame = CGRect(x: 10 + CGFloat(i) * 90, y: 450, width: 80, height: 36)
            b.accessibilityIdentifier = "btn-\(name)"; b.addTarget(self, action: sel, for: .touchUpInside)
            view.addSubview(b)
        }
    }

    func textKit1() {
        let ps = NSMutableParagraphStyle(); ps.alignment = .center; ps.paragraphSpacingBefore = 6
        let s = NSMutableAttributedString(string: "TextKit lays this paragraph out on several lines.\n", attributes: [.font: UIFont.systemFont(ofSize: 15)])
        s.append(NSAttributedString(string: "Centred", attributes: [.font: UIFont.boldSystemFont(ofSize: 17), .paragraphStyle: ps, .backgroundColor: UIColor.systemYellow]))
        tk1.storage.setAttributedString(s)
        let lm = tk1.layoutManager
        var lines = 0
        lm.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: lm.numberOfGlyphs)) { _, used, _, range, _ in
            lines += 1
            if lines == 1 { log("tk1 first line range \(range.location)+\(range.length) used x \(r1(used.minX))") }
        }
        log("tk1 glyphs \(lm.numberOfGlyphs) lines \(lines) container range \(lm.glyphRange(for: tk1.container).length) used \(rect(lm.usedRect(for: tk1.container)))")
        let centred = (s.string as NSString).range(of: "Centred")
        let box = lm.boundingRect(forGlyphRange: centred, in: tk1.container)
        log("tk1 centred box mid \(r1(box.midX)) of \(r1(tk1.container.size.width))")
        let i = lm.characterIndex(for: CGPoint(x: box.minX + 2, y: box.midY), in: tk1.container, fractionOfDistanceBetweenInsertionPoints: nil)
        log("tk1 index at centred \(i == centred.location)")
        tk1.storage.delegate = StorageLog.shared
        tk1.storage.replaceCharacters(in: NSRange(location: 0, length: 7), with: "TK")
        var after = 0
        lm.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: lm.numberOfGlyphs)) { _, _, _, _, _ in after += 1 }
        log("tk1 after edit glyphs \(lm.numberOfGlyphs) lines \(after)")
    }

    func textKit2() {
        tk2.font = .systemFont(ofSize: 15)
        tk2.text = "First paragraph here.\nSecond one, with a word to colour."
        tk2.accessibilityIdentifier = "tk2"
        guard let tlm = tk2.textLayoutManager, let cs = tlm.textContentManager as? NSTextContentStorage else { log("tk2 missing"); return }
        var frags = 0, lines = 0
        tlm.enumerateTextLayoutFragments(from: tlm.documentRange.location, options: [.ensuresLayout]) { f in
            frags += 1; lines += f.textLineFragments.count
            return true
        }
        log("tk2 fragments \(frags) lines \(lines) storage \(cs.textStorage === tk2.textStorage) container \(tlm.textContainer === tk2.textContainer)")
        let word = (tk2.text as NSString).range(of: "colour")
        if let start = cs.location(tlm.documentRange.location, offsetBy: word.location), let end = cs.location(start, offsetBy: word.length),
           let range = NSTextRange(location: start, end: end) {
            var segments = 0
            tlm.enumerateTextSegments(in: range, type: .standard, options: []) { _, frame, _, _ in segments += 1; log("tk2 segment \(rect(frame))"); return true }
            log("tk2 segments \(segments)")
            tlm.addRenderingAttribute(.foregroundColor, value: UIColor.systemGreen, for: range)
        }
        log("tk2 usage height \(r1(tlm.usageBoundsForTextContainer.height))")
    }

    func attachmentViews() {
        NSTextAttachment.registerViewProviderClass(BadgeProvider.self, forFileType: "dev.isim.badge")
        // an image inline (TextKit 1 drawing)
        let star = NSTextAttachment(image: UIImage(systemName: "star.fill")!.withTintColor(.systemPurple))
        star.bounds = CGRect(x: 0, y: -4, width: 24, height: 24)
        let s1 = NSMutableAttributedString(string: "Star ", attributes: [.font: UIFont.systemFont(ofSize: 17)])
        s1.append(NSAttributedString(attachment: star))
        tk1.storage.append(NSAttributedString(string: "\n"))
        tk1.storage.append(s1)
        // view providers in two TextKit 2 views; the right one keeps its views (iOS 27)
        for (tv, name) in [(attachments, "plain"), (keeper, "keeper")] {
            let badge = NSTextAttachment(data: nil, ofType: "dev.isim.badge")
            badge.bounds = CGRect(x: 0, y: 0, width: 30, height: 20)
            let s = NSMutableAttributedString(string: "Badge ", attributes: [.font: UIFont.systemFont(ofSize: 17)])
            s.append(NSAttributedString(attachment: badge))
            s.append(NSAttributedString(string: String(repeating: "\nline", count: 20), attributes: [.font: UIFont.systemFont(ofSize: 17)]))
            tv.attributedText = s
            tv.isEditable = false
            tv.accessibilityIdentifier = name
        }
        if #available(iOS 27, *) {
            keeper.register([.onScrollingOutOfViewport, .onEditingInlineParagraphs], forTextAttachmentViewProviderType: BadgeProvider.self)
            attachments.textLayoutManager?.delegate = delegate
        }
    }

    func badgeView(_ tv: UITextView) -> UIView? { tv.subviews.first { $0.accessibilityIdentifier?.hasPrefix("badge-") == true } }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [self] in
            log("badges plain \(badgeView(attachments) != nil) keeper \(badgeView(keeper) != nil) made \(madeViews)")
            log("tags \(tagsView.textStorage is TagStorage) red \(tagsView.textStorage.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? UIColor == .systemRed)")
        }
    }
    @objc func edit() {
        tagsView.textStorage.append(NSAttributedString(string: " #tk"))
        let keeperBadge = badgeView(keeper), plainBadge = badgeView(attachments)
        for tv in [keeper, attachments] { tv.textStorage.replaceCharacters(in: NSRange(location: 0, length: 5), with: "Chip") }
        DispatchQueue.main.async { [self] in
            view.layoutIfNeeded()
            log("edit keeper same view \(badgeView(keeper) === keeperBadge && keeperBadge != nil) plain same view \(badgeView(attachments) === plainBadge) made \(madeViews)")
            log("tags red \(tagsView.textStorage.attribute(.foregroundColor, at: (tagsView.text as NSString).length - 1, effectiveRange: nil) as? UIColor == .systemRed)")
        }
    }
    @objc func scroll() {
        let keeperBadge = badgeView(keeper)
        for tv in [keeper, attachments] { tv.setContentOffset(CGPoint(x: 0, y: 300), animated: false); tv.layoutIfNeeded() }
        log("scrolled keeper kept \(badgeView(keeper) === keeperBadge && keeperBadge != nil) plain kept \(badgeView(attachments) != nil)")
    }
    @objc func switchKit() {
        let before = tk2.textLayoutManager != nil
        _ = tk2.layoutManager
        log("switch textLayoutManager before \(before) after \(tk2.textLayoutManager != nil) glyphs \(tk2.layoutManager.numberOfGlyphs)")
    }
}

final class StorageLog: NSObject, NSTextStorageDelegate {
    static let shared = StorageLog()
    func textStorage(_ ts: NSTextStorage, willProcessEditing m: NSTextStorage.EditActions, range: NSRange, changeInLength d: Int) {
        log("storage will process chars \(m.contains(.editedCharacters)) range \(range.location)+\(range.length) delta \(d)")
    }
    func textStorage(_ ts: NSTextStorage, didProcessEditing m: NSTextStorage.EditActions, range: NSRange, changeInLength d: Int) {
        log("storage did process")
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
