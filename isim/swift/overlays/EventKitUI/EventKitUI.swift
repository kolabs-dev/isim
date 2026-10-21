// isim EventKitUI (self-authored, iOS API names): EKEventEditViewController — a basic "New Event" form (title,
// location, start/end shown, all-day switch) that saves into the device calendar without the app needing calendar
// access, like iOS 17+ (the real controller runs out of process). EKEventViewController shows an event's details.
@_spi(isim) import EventKit
import UIKit

@objc public enum EKEventEditViewAction: Int, Sendable { case canceled = 0, saved, deleted
    @available(*, deprecated, renamed: "canceled") public static var cancelled: EKEventEditViewAction { .canceled } }

@objc public protocol EKEventEditViewDelegate: NSObjectProtocol {
    @objc(eventEditViewController:didCompleteWithAction:) func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction)
    @objc optional func eventEditViewControllerDefaultCalendar(forNewEvents controller: EKEventEditViewController) -> EKCalendar
}

@objc(EKEventEditViewController) open class EKEventEditViewController: UINavigationController {
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
        guard let d = editViewDelegate else { presentingViewController?.dismiss(animated: true, completion: nil); return }
        // Swift apps built with isim 0.22 or earlier implement it under Swift's selector (eventEditViewController:didCompleteWith:)
        let old = NSSelectorFromString("eventEditViewController:didCompleteWith:")
        if !d.responds(to: #selector(EKEventEditViewDelegate.eventEditViewController(_:didCompleteWith:))), let o = d as? NSObject, o.responds(to: old) {
            typealias Send = @convention(c) (AnyObject, Selector, AnyObject, Int) -> Void
            unsafeBitCast(o.method(for: old), to: Send.self)(o, old, self, action.rawValue)
        } else {
            d.eventEditViewController(self, didCompleteWith: action)
        }
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
    @objc(eventViewController:didCompleteWithAction:) func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction)
}
@objc(EKEventViewController) open class EKEventViewController: UIViewController {
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

// MARK: - EKCalendarChooser

@objc public enum EKCalendarChooserSelectionStyle: Int, Sendable { case single = 0, multiple }
@objc public enum EKCalendarChooserDisplayStyle: Int, Sendable { case allCalendars = 0, writableCalendarsOnly }

@objc public protocol EKCalendarChooserDelegate: NSObjectProtocol {
    @objc optional func calendarChooserSelectionDidChange(_ calendarChooser: EKCalendarChooser)
    @objc optional func calendarChooserDidFinish(_ calendarChooser: EKCalendarChooser)
    @objc optional func calendarChooserDidCancel(_ calendarChooser: EKCalendarChooser)
}

/// lists the device's calendars (or reminder lists) with a checkmark on the selected ones; push it on a navigation
/// controller to get its Done and Cancel buttons
@objc(EKCalendarChooser) open class EKCalendarChooser: UIViewController, UITableViewDataSource, UITableViewDelegate {
    open private(set) var selectionStyle: EKCalendarChooserSelectionStyle
    let displayStyle: EKCalendarChooserDisplayStyle
    let entityType: EKEntityType
    let store: EKEventStore
    open weak var delegate: EKCalendarChooserDelegate?
    open var showsDoneButton = false { didSet { updateButtons() } }
    open var showsCancelButton = false { didSet { updateButtons() } }
    open var selectedCalendars: Set<EKCalendar> = [] { didSet { if isViewLoaded { table.reloadData() } } }
    let table = UITableView(frame: .zero, style: .insetGrouped)
    var calendars: [EKCalendar] = []

    public convenience init(selectionStyle: EKCalendarChooserSelectionStyle, displayStyle: EKCalendarChooserDisplayStyle, eventStore: EKEventStore) {
        self.init(selectionStyle: selectionStyle, displayStyle: displayStyle, entityType: .event, eventStore: eventStore)
    }
    public init(selectionStyle: EKCalendarChooserSelectionStyle, displayStyle: EKCalendarChooserDisplayStyle, entityType: EKEntityType, eventStore: EKEventStore) {
        self.selectionStyle = selectionStyle; self.displayStyle = displayStyle; self.entityType = entityType; store = eventStore
        super.init(nibName: nil, bundle: nil)
    }
    public required init?(coder: NSCoder) { fatalError("EKCalendarChooser is made in code") }

    open override func viewDidLoad() {
        super.viewDidLoad()
        title = entityType == .reminder ? "Lists" : selectionStyle == .single ? "Choose Calendar" : "Calendars"
        view.backgroundColor = .systemGroupedBackground
        calendars = store._isimCalendars(for: entityType).filter { displayStyle == .allCalendars || $0.allowsContentModifications }
        table.dataSource = self; table.delegate = self
        table.accessibilityIdentifier = "calendar-chooser"
        table.frame = view.bounds; table.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(table)
        updateButtons()
    }
    func updateButtons() {
        guard isViewLoaded else { return }
        navigationItem.leftBarButtonItem = showsCancelButton ? item("Cancel", false, "calendar-chooser-cancel", #selector(isimEKChooserCancel)) : nil
        navigationItem.rightBarButtonItem = showsDoneButton ? item("Done", true, "calendar-chooser-done", #selector(isimEKChooserDone)) : nil
    }
    func item(_ t: String, _ bold: Bool, _ id: String, _ sel: Selector) -> UIBarButtonItem {
        let b = UIButton(type: .system)
        b.setTitle(t, for: .normal)
        b.titleLabel?.font = bold ? .systemFont(ofSize: 17, weight: .semibold) : .systemFont(ofSize: 17)
        b.addTarget(self, action: sel, for: .touchUpInside)
        b.accessibilityIdentifier = id
        b.sizeToFit()
        return UIBarButtonItem(customView: b)
    }
    @objc func isimEKChooserDone() { delegate?.calendarChooserDidFinish?(self) }
    @objc func isimEKChooserCancel() { delegate?.calendarChooserDidCancel?(self) }

    public func numberOfSections(in tableView: UITableView) -> Int { 1 }
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "On My iPhone" }
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { calendars.count }
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cal = calendars[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = cal.title
        // the calendar's colour as a dot, like Calendar's list
        cell.imageView?.image = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { _ in
            UIColor(cgColor: cal.cgColor).setFill(); UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 12, height: 12)).fill()
        }
        cell.accessoryType = selectedCalendars.contains(cal) ? .checkmark : .none
        cell.accessibilityIdentifier = "calendar-" + cal.title
        return cell
    }
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cal = calendars[indexPath.row]
        if selectionStyle == .single { selectedCalendars = [cal] }
        else if selectedCalendars.contains(cal) { selectedCalendars.remove(cal) } else { selectedCalendars.insert(cal) }
        delegate?.calendarChooserSelectionDidChange?(self)
    }
}
