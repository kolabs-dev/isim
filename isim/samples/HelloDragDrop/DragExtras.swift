// HelloDragDrop, -extras: part 11 of #9, each logged with "dg" (run on iPad: text dragging and the pointer are iPad features).
// - Text drag and drop: the selected word of one text view dragged into another (UITextDraggable / UITextDroppable,
//   their delegates); a paste delegate that uppercases what is pasted
// - Table drops with a placeholder row (UITableViewDropPlaceholder, commitInsertion)
// - A spring-loaded button that fires while a drag rests on it
// - Hover styles (highlight with a rounded shape, lift) and shapes resolved against bounds
// - A UIKit trait bridged into SwiftUI's environment (UITraitBridgedEnvironmentKey)
// - Auto Layout extras (anchorWithOffset, system spacing inequalities, tracking layout guide constraints) and traits
import UIKit
import SwiftUI

private func log(_ s: String) { print("dg \(s)") }

struct GreetingTrait: UITraitDefinition { static let defaultValue = "hello" }
struct GreetingKey: EnvironmentKey { static let defaultValue = "unbridged" }
extension GreetingKey: UITraitBridgedEnvironmentKey {
    static func read(from traitCollection: UITraitCollection) -> String { traitCollection[GreetingTrait.self] }
    static func write(to mutableTraits: inout any UIMutableTraits, value: String) { mutableTraits[GreetingTrait.self] = value }
}
extension EnvironmentValues {
    var greeting: String { get { self[GreetingKey.self] } set { self[GreetingKey.self] = newValue } }
}
struct GreetingView: View {
    @Environment(\.greeting) var greeting
    var body: some View { Text(greeting).onAppear { log("bridged \(greeting)") } }
}

final class Upper: NSObject, UITextPasteDelegate {
    func textPasteConfigurationSupporting(_ t: UITextPasteConfigurationSupporting, transform item: UITextPasteItem) {
        _ = item.itemProvider.loadObject(ofClass: NSString.self) { _, _ in }
        item.setStringResult((UIPasteboard.general.string ?? "").uppercased())
    }
}

final class DragExtrasViewController: UIViewController, UIDragInteractionDelegate, UITableViewDataSource, UITableViewDropDelegate,
                                UITextDragDelegate, UITextDropDelegate {
    let source = UILabel(), notes = UITextView(), target = UITextView(), table = UITableView(), spring = UIButton(type: .system)
    let paste = UITextField(), pasteButton = UIButton(type: .system), hover = UIView(), lift = UIView()
    var rows = ["one", "two"]
    let upper = Upper()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        source.frame = CGRect(x: 40, y: 120, width: 160, height: 44); source.text = "Drag me"; source.accessibilityIdentifier = "source"
        source.isUserInteractionEnabled = true; source.backgroundColor = .secondarySystemBackground; source.textAlignment = .center
        source.addInteraction(UIDragInteraction(delegate: self))
        notes.frame = CGRect(x: 40, y: 200, width: 400, height: 120); notes.accessibilityIdentifier = "notes"
        notes.font = .systemFont(ofSize: 20); notes.text = "alpha beta gamma"; notes.backgroundColor = .secondarySystemBackground
        notes.textDragDelegate = self
        target.frame = CGRect(x: 40, y: 340, width: 400, height: 120); target.accessibilityIdentifier = "target"
        target.font = .systemFont(ofSize: 20); target.text = "start "; target.backgroundColor = .tertiarySystemBackground
        target.textDropDelegate = self
        table.frame = CGRect(x: 460, y: 120, width: 340, height: 300); table.accessibilityIdentifier = "table"
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell"); table.dataSource = self; table.dropDelegate = self
        spring.frame = CGRect(x: 460, y: 440, width: 160, height: 44); spring.setTitle("Spring", for: .normal); spring.accessibilityIdentifier = "spring"
        spring.isSpringLoaded = true
        spring.addAction(UIAction { _ in log("spring button fired") }, for: .touchUpInside)
        hover.frame = CGRect(x: 40, y: 500, width: 160, height: 80); hover.backgroundColor = .systemTeal; hover.accessibilityIdentifier = "hover"
        lift.frame = CGRect(x: 220, y: 500, width: 160, height: 80); lift.backgroundColor = .systemPink; lift.accessibilityIdentifier = "lift"
        if #available(iOS 17.0, *) {
            hover.hoverStyle = UIHoverStyle(effect: .highlight, shape: .rect(cornerRadius: 12))
            lift.hoverStyle = UIHoverStyle(effect: .lift, shape: .capsule)
        }
        paste.frame = CGRect(x: 40, y: 620, width: 300, height: 36); paste.borderStyle = .roundedRect; paste.accessibilityIdentifier = "paste"
        paste.pasteDelegate = upper
        pasteButton.frame = CGRect(x: 360, y: 620, width: 120, height: 36); pasteButton.setTitle("Paste", for: .normal); pasteButton.accessibilityIdentifier = "pastebtn"
        pasteButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            UIPasteboard.general.string = "shout"
            self.paste.becomeFirstResponder(); self.paste.paste(nil)
            log("pasted field \(self.paste.text ?? "")")
        }, for: .touchUpInside)
        for v in [source, notes, target, table, spring, hover, lift, paste, pasteButton] as [UIView] { view.addSubview(v) }
        let host = UIHostingController(rootView: GreetingView())
        host.traitOverrides[GreetingTrait.self] = "bonjour"
        addChild(host); host.view.frame = CGRect(x: 500, y: 620, width: 200, height: 36); view.addSubview(host.view); host.didMove(toParent: self)
        layoutAndTraits()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        notes.selectedRange = NSRange(location: 6, length: 4)        // "beta"
        if let r = notes.selectedTextRange {
            let rect = notes.convert(notes.firstRect(for: r), to: nil)
            log("beta at \(Int(rect.midX)) \(Int(rect.midY))")
        }
        log("text drag enabled \(notes.textDragInteraction?.isEnabled ?? false) drop \(target.textDropInteraction != nil)")
        log("ready")
    }

    func layoutAndTraits() {
        let a = UIView(), b = UIView()
        for v in [a, b] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        NSLayoutConstraint.activate([
            a.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10), a.topAnchor.constraint(equalTo: view.topAnchor, constant: 700),
            a.widthAnchor.constraint(equalToConstant: 50), a.heightAnchor.constraint(equalToConstant: 10),
            b.topAnchor.constraint(equalTo: a.topAnchor), b.heightAnchor.constraint(equalToConstant: 10), b.widthAnchor.constraint(equalToConstant: 20),
            b.leadingAnchor.constraint(greaterThanOrEqualToSystemSpacingAfter: a.trailingAnchor, multiplier: 2),
            a.trailingAnchor.anchorWithOffset(to: b.leadingAnchor).constraint(equalToConstant: 30),
        ])
        view.layoutIfNeeded()
        log("offset gap \(Int(b.frame.minX - a.frame.maxX))")
        let near = view.keyboardLayoutGuide.topAnchor.constraint(equalTo: a.bottomAnchor)
        let away = a.heightAnchor.constraint(equalToConstant: 12)
        view.keyboardLayoutGuide.setConstraints([near], activeWhenNearEdge: .bottom)
        view.keyboardLayoutGuide.setConstraints([away], activeWhenAwayFrom: .top)
        log("tracking near \(near.isActive) away \(away.isActive) listed \(view.keyboardLayoutGuide.constraints(activeWhenNearEdge: .bottom).count)")
        view.keyboardLayoutGuide.removeAllTrackedConstraints()
        log("tracking removed \(near.isActive) \(away.isActive)")
        let c = a.widthAnchor.constraint(equalToConstant: 1); c.shouldBeArchived = true
        log("archived \(c.shouldBeArchived) priorities \(Int(UILayoutPriority.dragThatCanResizeScene.rawValue)) \(Int(UILayoutPriority.sceneSizeStayPut.rawValue))")
        if #available(iOS 17.0, *) {
            let t = view.window?.traitCollection ?? UIScreen.main.traitCollection
            let x = UITraitCollection(imageDynamicRange: .high)
            let y = UITraitCollection(typesettingLanguage: Locale.Language(identifier: "ja"))
            let changed = x.changedTraits(from: UITraitCollection(imageDynamicRange: .standard)).count
            log("traits capture \(t.sceneCaptureState.rawValue) range \(x.imageDynamicRange == .high) language \(y.typesettingLanguage?.minimalIdentifier ?? "") changed \(changed) force \(UITraitCollection(forceTouchCapability: .available).forceTouchCapability == .available)")
            let m = UITraitCollection { $0.sceneCaptureState = .active; $0.imageDynamicRange = .constrainedHigh }
            log("mutations \(m.sceneCaptureState == .active) \(m[UITraitImageDynamicRange.self] == .constrainedHigh)")
        }
    }

    // UIDragInteractionDelegate (the source label)
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        let item = UIDragItem(itemProvider: NSItemProvider(object: "three" as NSString)); item.localObject = "three"
        return [item]
    }

    // table
    func tableView(_ t: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
    func tableView(_ t: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let c = t.dequeueReusableCell(withIdentifier: "cell", for: ip); c.textLabel?.text = rows[ip.row]; return c
    }
    func tableView(_ t: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath ip: IndexPath?) -> UITableViewDropProposal {
        UITableViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
    }
    func tableView(_ t: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard let item = coordinator.items.first?.dragItem else { return }
        let ip = IndexPath(row: rows.count, section: 0)
        let placeholder = UITableViewDropPlaceholder(insertionIndexPath: ip, reuseIdentifier: "cell", rowHeight: 44)
        placeholder.cellUpdateHandler = { $0.textLabel?.text = "Loading…" }
        let context = coordinator.drop(item, to: placeholder)
        _ = item.itemProvider.loadObject(ofClass: NSString.self) { obj, _ in
            let s = (obj as? String) ?? "?"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let ok = context.commitInsertion { self.rows.insert(s, at: $0.row) }
                log("placeholder committed \(ok) rows \(self.rows.joined(separator: ","))")
            }
        }
    }

    // text drag and drop delegates
    func textDraggableView(_ v: UIView & UITextDraggable, itemsForDrag request: UITextDragRequest) -> [UIDragItem] {
        log("text drag request selected \(request.isSelected) items \(request.suggestedItems.count)")
        return request.suggestedItems
    }
    func textDraggableView(_ v: UIView & UITextDraggable, dragSessionDidEnd session: UIDragSession, with operation: UIDropOperation) {
        log("text drag ended \(operation == .copy ? "copy" : operation == .move ? "move" : "other") notes \(notes.text ?? "")")
    }
    func textDroppableView(_ v: UIView & UITextDroppable, proposalForDrop drop: UITextDropRequest) -> UITextDropProposal {
        let p = UITextDropProposal(operation: .copy); p.dropAction = .insert; return p
    }
    func textDroppableView(_ v: UIView & UITextDroppable, willPerformDrop drop: UITextDropRequest) { log("text drop same view \(drop.isSameView)") }
    func textDroppableView(_ v: UIView & UITextDroppable, dropSessionDidEnd session: UIDropSession) { log("target \(target.text ?? "")") }
}

