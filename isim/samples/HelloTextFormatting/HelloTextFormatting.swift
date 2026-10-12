// Sample: the rest of the text APIs of #9, each logged with "fm".
// - Notes: a text view that allows editing attributes; its edit menu's Format opens the text formatting panel, whose
//   changes apply to the selection (bold, lists, alignment). Writing Tools settings (unavailable in isim, as on an
//   iPhone without Apple Intelligence)
// - Panel: a formatting panel of its own (custom groups and styles) whose changes reach the delegate as ChangeValue
// - Reply: a text field with a conversation context; a smart reply suggestion inserted
// - TextKit: tab stops and a numbered list drawn in a text view, list markers, selection navigation over a TextKit 2
//   layout manager, adaptive image glyphs, Core Text alignment conversions
import UIKit
import CoreText

func log(_ s: String) { print("fm \(s)") }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: FormatViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class FormatViewController: UIViewController, UITextViewDelegate {
    let notes = UITextView(), reply = UITextField(), table = UITextView()
    var panelDelegate: AnyObject?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Format"
        view.backgroundColor = .systemBackground
        notes.frame = CGRect(x: 16, y: 100, width: 340, height: 110); notes.accessibilityIdentifier = "notes"
        notes.font = .systemFont(ofSize: 17)
        notes.text = "Groceries for the week\napples\npears"
        notes.allowsEditingTextAttributes = true
        notes.delegate = self
        view.addSubview(notes)
        reply.frame = CGRect(x: 16, y: 220, width: 340, height: 36); reply.accessibilityIdentifier = "reply"; reply.borderStyle = .roundedRect
        view.addSubview(reply)
        table.frame = CGRect(x: 16, y: 266, width: 340, height: 150); table.accessibilityIdentifier = "table"; table.isEditable = false
        view.addSubview(table)
        let panel = UIButton(type: .system); panel.setTitle("Panel", for: .normal); panel.accessibilityIdentifier = "panel"
        panel.frame = CGRect(x: 16, y: 426, width: 80, height: 44)
        panel.addAction(UIAction { [weak self] _ in self?.showPanel() }, for: .touchUpInside)
        view.addSubview(panel)
        let check = UIButton(type: .system); check.setTitle("Check", for: .normal); check.accessibilityIdentifier = "check"
        check.frame = CGRect(x: 110, y: 426, width: 80, height: 44)
        check.addAction(UIAction { [weak self] _ in self?.report() }, for: .touchUpInside)
        view.addSubview(check)

        writingTools()
        conversation()
        textKit()
        log("ready")
    }

    // MARK: Writing Tools
    func writingTools() {
        if #available(iOS 18.0, *) {
            notes.writingToolsBehavior = .complete
            notes.allowedWritingToolsResultOptions = [.plainText, .list]
            log("writing tools behavior complete \(notes.writingToolsBehavior == .complete) options \(notes.allowedWritingToolsResultOptions.rawValue) active \(notes.isWritingToolsActive)")
        }
        if #available(iOS 18.2, *) {
            let c = UIWritingToolsCoordinator(delegate: nil)
            c.preferredBehavior = .limited
            notes.addInteraction(c)
            log("writing tools available \(UIWritingToolsCoordinator.isWritingToolsAvailable) state inactive \(c.state == .inactive) behavior none \(c.behavior == .none) view \(c.view === notes)")
        }
    }

    // MARK: Conversation context and suggestions
    func conversation() {
        guard #available(iOS 18.4, *) else { return }
        let entry = UIConversationContext.Entry()
        entry.text = "Lunch tomorrow?"; entry.senderIdentifier = "amy"; entry.primaryRecipientIdentifiers = ["me"]
        let context = UIConversationContext()
        context.conversationEntries = [entry]; context.selfIdentifiers = ["me"]
        var amy = PersonNameComponents(); amy.givenName = "Amy"
        context.participantNameByIdentifier = ["amy": amy]
        reply.conversationContext = context
        let copy = context.copy() as! UIConversationContext
        let input: UITextInput = reply
        input.insert?(UISmartReplySuggestion(smartReply: "Sounds good"))
        log("conversation entries \(copy.conversationEntries.count) first \(copy.conversationEntries.first?.text ?? "") sender \(copy.conversationEntries.first?.senderIdentifier ?? "") kept \(reply.conversationContext === context) reply \(reply.text ?? "")")
        if #available(iOS 26.0, *) {
            let mail = UIMailConversationContext.MailEntry()
            mail.kind = .personal; mail.text = "See attached"
            let thread = UIMailConversationContext(); thread.conversationEntries = [mail]; thread.responseSubject = "Re: plans"
            log("mail kind personal \((thread.conversationEntries.first as? UIMailConversationContext.MailEntry)?.kind == .personal) subject \(thread.responseSubject)")
        }
    }

    // MARK: TextKit
    func textKit() {
        let style = NSMutableParagraphStyle()
        log("tabs default \(style.tabStops.count) first \(Int(style.tabStops.first?.location ?? 0)) interval \(Int(style.defaultTabInterval))")
        let decimal = NSTextTab(textAlignment: .right, location: 250, options: [.columnTerminators: NSTextTab.columnTerminators(for: Locale(identifier: "en_US"))])
        style.tabStops = [decimal, NSTextTab(textAlignment: .left, location: 110)]
        style.addTabStop(NSTextTab(textAlignment: .center, location: 180))
        log("tabs \(style.tabStops.map { String(Int($0.location)) }.joined(separator: " "))")
        style.removeTabStop(NSTextTab(textAlignment: .center, location: 180))
        log("tabs after remove \(style.tabStops.map { String(Int($0.location)) }.joined(separator: " "))")

        let roman = NSTextList(markerFormat: .lowercaseRoman, options: 0)
        let alpha = NSTextList(markerFormat: NSTextList.MarkerFormat("({upper-alpha})"), options: 0)
        let disc = NSTextList(markerFormat: .disc, options: 0)
        log("markers \(roman.marker(forItemNumber: 4)) \(alpha.marker(forItemNumber: 28)) \(disc.marker(forItemNumber: 1)) ordered \(roman.isOrdered) \(disc.isOrdered)")
        let numbered = NSTextList(markerFormat: NSTextList.MarkerFormat("{decimal}."), options: 0)
        let item = NSMutableParagraphStyle(); item.textLists = [numbered]; item.headIndent = 28; item.firstLineHeadIndent = 28
        let text = NSMutableAttributedString(string: "Item\tQty\tPrice\nApples\t3\t1.50\nPears\t12\t10.25\n", attributes: [.font: UIFont.systemFont(ofSize: 15), .paragraphStyle: style])
        text.append(NSAttributedString(string: "first\nsecond\nthird", attributes: [.font: UIFont.systemFont(ofSize: 15), .paragraphStyle: item]))
        table.attributedText = text
        log("text lists \(item.textLists.count) element \(NSTextListElement(contents: NSAttributedString(string: "milk"), markerAttributes: nil, textList: numbered, children: nil).attributedString.string.debugDescription)")

        // selection navigation over a TextKit 2 layout manager
        let storage = NSTextContentStorage(), manager = NSTextLayoutManager()
        storage.addTextLayoutManager(manager)
        manager.textContainer = NSTextContainer(size: CGSize(width: 300, height: 0))
        storage.attributedString = NSAttributedString(string: "Hello brave world. Second one.\nNext paragraph", attributes: [.font: UIFont.systemFont(ofSize: 15)])
        let nav = manager.textSelectionNavigation
        let start = manager.documentRange.location
        func off(_ l: NSTextLocation?) -> Int { l.map { manager.offset(from: start, to: $0) } ?? -1 }
        func span(_ s: NSTextSelection?) -> String { guard let r = s?.textRanges.first else { return "nil" }; return "\(off(r.location))-\(off(r.endLocation))" }
        var sel = NSTextSelection(location: start, affinity: .downstream)
        var steps: [String] = []
        for _ in 0..<2 { if let n = nav.destinationSelection(for: sel, direction: .forward, destination: .word, extending: false, confined: false) { sel = n; steps.append(span(n)) } }
        let extended = nav.destinationSelection(for: sel, direction: .forward, destination: .word, extending: true, confined: false)
        let back = nav.destinationSelection(for: extended!, direction: .left, destination: .character, extending: false, confined: false)
        let paragraphEnd = nav.destinationSelection(for: NSTextSelection(location: start, affinity: .downstream), direction: .forward, destination: .paragraph, extending: false, confined: false)
        let docEnd = nav.destinationSelection(for: sel, direction: .forward, destination: .document, extending: false, confined: false)
        let word = nav.textSelection(for: .word, enclosing: NSTextSelection(location: manager.location(start, offsetBy: 8)!, affinity: .downstream))
        let deletion = nav.deletionRanges(for: sel, direction: .backward, destination: .word, allowsDecomposition: false)
        let insertion = nav.resolvedInsertionLocation(for: sel, writingDirection: .leftToRight)
        log("navigation words \(steps.joined(separator: " ")) extend \(span(extended)) collapse \(span(back)) paragraph \(span(paragraphEnd)) end \(span(docEnd)) word \(span(word)) delete \(deletion.map { "\(off($0.location))-\(off($0.endLocation))" }.joined(separator: ",")) insert \(off(insertion))")
        let line = manager.lineFragmentRange(for: CGPoint(x: 5, y: 5), inContainerAt: start)
        var carets = 0
        manager.enumerateCaretOffsetsInLineFragment(at: start) { _, _, _, _ in carets += 1 }
        log("line \(line.map { "\(off($0.location))-\(off($0.endLocation))" } ?? "nil") carets \(carets) direction ltr \(manager.baseWritingDirection(at: start) == .leftToRight)")

        if #available(iOS 18.0, *) {
            let a = NSAdaptiveImageGlyph(imageContent: Data([1, 2, 3])), b = NSAdaptiveImageGlyph(imageContent: Data([1, 2, 3]))
            log("glyph id \(a.contentIdentifier.count) same \(a.contentIdentifier == b.contentIdentifier) bytes \(a.imageContent.count)")
        }
        log("ct alignment \(NSTextAlignment(CTTextAlignment.right) == .right) \(CTTextAlignment(NSTextAlignment.center) == .center) orientation \(NSTextContainer(size: .zero).layoutOrientation == .horizontal)")
    }

    // MARK: The formatting panel
    func showPanel() {
        guard #available(iOS 18.0, *) else { return }
        let groups = [UITextFormattingViewController.ComponentGroup(components: [.init(componentKey: .formattingStyles, preferredSize: .regular)]),
                      UITextFormattingViewController.ComponentGroup(components: [.init(componentKey: .fontAttributes, preferredSize: .regular)]),
                      UITextFormattingViewController.ComponentGroup(components: [.init(componentKey: .listStyles, preferredSize: .small),
                                                                                 .init(componentKey: .textAlignment, preferredSize: .small)])]
        let configuration = UITextFormattingViewController.Configuration(groups: groups)
        configuration.formattingStyles = [.init(styleKey: "loud", title: "Loud", attributes: [.font: UIFont.boldSystemFont(ofSize: 20)]),
                                          .init(styleKey: "quiet", title: "Quiet", attributes: [.font: UIFont.systemFont(ofSize: 13)])]
        let panel = UITextFormattingViewController(configuration: configuration)
        var descriptor = UITextFormattingViewController.FormattingDescriptor()
        descriptor.underlinePresent = false; descriptor.textAlignments = [.center]
        panel.formattingDescriptor = descriptor
        let d = PanelDelegate(); panelDelegate = d; panel.delegate = d
        log("panel groups \(panel.configuration.groups.count) styles \(configuration.formattingStyles?.count ?? 0) center \(panel.formattingDescriptor?.textAlignments.contains(.center) ?? false) natural \(UITextFormattingViewController.TextAlignment.center.nsTextAlignment == .center)")
        if let sheet = panel.sheetPresentationController { sheet.detents = [.medium()] }
        present(panel, animated: true)
    }

    func textViewDidChange(_ textView: UITextView) { log("notes changed") }

    func report() {
        let s = notes.attributedText!
        let font = s.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let bold = font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
        let lists = (s.attribute(.paragraphStyle, at: s.length - 1, effectiveRange: nil) as? NSParagraphStyle)?.textLists.count ?? 0
        let centered = (s.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment == .center
        log("notes bold \(bold) lists \(lists) centered \(centered)")
    }
}

@available(iOS 18.0, *)
final class PanelDelegate: NSObject, UITextFormattingViewController.Delegate {
    func textFormattingViewController(_ viewController: UITextFormattingViewController, didChangeValue changeValue: UITextFormattingViewController.ChangeValue) {
        switch changeValue {
        case .underline(let on): log("change underline \(on)")
        case .font(let f): log("change font bold \(f.fontDescriptor.symbolicTraits.contains(.traitBold))")
        case .textList(let l): log("change list \(l?.rawValue ?? "none")")
        case .textAlignment(let a): log("change alignment \(a.rawValue)")
        case .formattingStyle(let k): log("change style \(k)")
        default: log("change other")
        }
    }
    func textFormattingDidFinish(_ viewController: UITextFormattingViewController) { log("panel finished") }
}
