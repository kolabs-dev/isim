// isim EventKitUI (self-authored, iOS API names): EKEventEditViewController — a basic "New Event" form (title,
// location, start/end shown, all-day switch) that saves into the device calendar without the app needing calendar
// access, like iOS 17+ (the real controller runs out of process). EKEventViewController shows an event's details.
@_spi(isim) import EventKit
import UIKit

@objc public enum EKEventEditViewAction: Int, Sendable { case canceled = 0, saved, deleted
    @available(*, deprecated, renamed: "canceled") public static var cancelled: EKEventEditViewAction { .canceled } }

@objc public protocol EKEventEditViewDelegate: NSObjectProtocol {
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction)
    @objc optional func eventEditViewControllerDefaultCalendar(forNewEvents controller: EKEventEditViewController) -> EKCalendar
}

open class EKEventEditViewController: UINavigationController {
    open weak var editViewDelegate: EKEventEditViewDelegate?
    open var eventStore: EKEventStore!
    open var event: EKEvent?
    let form = _EKEditForm()

    public override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        form.owner = self
        viewControllers = [form]
    }
    public convenience init() { self.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func viewDidLoad() {
        super.viewDidLoad()
        form.owner = self
        if viewControllers.isEmpty { viewControllers = [form] }
    }
    open func cancelEditing() { finish(.canceled) }
    func finish(_ action: EKEventEditViewAction) {
        if let d = editViewDelegate { d.eventEditViewController(self, didCompleteWith: action) }
        else { presentingViewController?.dismiss(animated: true, completion: nil) }
    }
}

final class _EKEditForm: UIViewController, UITextFieldDelegate {
    weak var owner: EKEventEditViewController?
    var titleField = UITextField(), locationField = UITextField()
    let allDay = UISwitch()
    var event: EKEvent!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        guard let owner else { return }
        if owner.eventStore == nil { owner.eventStore = EKEventStore() }
        let isNew = owner.event == nil || owner.eventStore.event(withIdentifier: owner.event!.eventIdentifier) == nil
        event = owner.event ?? EKEvent(eventStore: owner.eventStore)
        if event.startDate == nil {
            let start = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 / 3600).rounded(.up) * 3600)
            event.startDate = start; event.endDate = start.addingTimeInterval(3600)
        }
        title = isNew ? "New Event" : "Edit Event"
        navigationItem.leftBarButtonItem = button("Cancel", false, "event-cancel", #selector(isimEKCancel))
        navigationItem.rightBarButtonItem = button(isNew ? "Add" : "Done", true, "event-add", #selector(isimEKSave))
        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        for (f, p, v, id) in [(titleField, "Title", event.title ?? "", "event-title"), (locationField, "Location or Video Call", event.location ?? "", "event-location")] {
            f.placeholder = p; f.text = v; f.borderStyle = .roundedRect; f.accessibilityIdentifier = id; f.delegate = self
            f.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(f)
        }
        let row = UIStackView(); row.axis = .horizontal
        let l = UILabel(); l.text = "All-day"
        allDay.isOn = event.isAllDay; allDay.accessibilityIdentifier = "event-allday"
        row.addArrangedSubview(l); row.addArrangedSubview(allDay)
        stack.addArrangedSubview(row)
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        for (name, d) in [("Starts", event.startDate!), ("Ends", event.endDate!)] {
            let lab = UILabel(); lab.text = "\(name)  \(f.string(from: d))"; lab.accessibilityIdentifier = "event-\(name.lowercased())"
            stack.addArrangedSubview(lab)
        }
    }
    func button(_ t: String, _ bold: Bool, _ id: String, _ sel: Selector) -> UIBarButtonItem {
        let b = UIButton(type: .system)
        b.setTitle(t, for: .normal)
        b.titleLabel?.font = bold ? .systemFont(ofSize: 17, weight: .semibold) : .systemFont(ofSize: 17)
        b.addTarget(self, action: sel, for: .touchUpInside)
        b.accessibilityIdentifier = id
        b.sizeToFit()
        return UIBarButtonItem(customView: b)
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { textField.resignFirstResponder(); return true }
    @objc func isimEKCancel() { owner?.finish(.canceled) }
    @objc func isimEKSave() {
        guard let owner else { return }
        titleField.resignFirstResponder(); locationField.resignFirstResponder()
        event.title = (titleField.text ?? "").isEmpty ? "New Event" : titleField.text
        event.location = (locationField.text ?? "").isEmpty ? nil : locationField.text
        event.isAllDay = allDay.isOn
        if event.calendar == nil, let c = owner.editViewDelegate?.eventEditViewControllerDefaultCalendar?(forNewEvents: owner) { event.calendar = c }
        do {
            try owner.eventStore._isimSaveWithoutAccess(event)
            owner.event = event
            NSLog("isim EventKitUI: saved event “%@”", event.title ?? "")
            owner.finish(.saved)
        } catch { NSLog("isim EventKitUI: could not save the event: %@", "\(error)") }
    }
}

@objc public enum EKEventViewAction: Int, Sendable { case done = 0, responded, deleted }
@objc public protocol EKEventViewDelegate: NSObjectProtocol {
    func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction)
}
open class EKEventViewController: UIViewController {
    open weak var delegate: EKEventViewDelegate?
    open var event: EKEvent!
    open var allowsEditing = true
    open var allowsCalendarPreview = false
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Event Details"
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = event?.isAllDay == true ? .none : .short
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        let t = UILabel(); t.text = event?.title; t.font = .systemFont(ofSize: 22, weight: .semibold); stack.addArrangedSubview(t)
        if let loc = event?.location { let l = UILabel(); l.text = loc; stack.addArrangedSubview(l) }
        if let s = event?.startDate { let l = UILabel(); l.numberOfLines = 0; l.text = f.string(from: s); stack.addArrangedSubview(l) }
        if let c = event?.calendar { let l = UILabel(); l.text = "Calendar: \(c.title)"; l.textColor = .secondaryLabel; stack.addArrangedSubview(l) }
    }
}
