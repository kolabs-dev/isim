// Sample: personal data on isim — Contacts (permission alert, the seeded address book, predicates, save requests,
// unfetched-key safety), ContactsUI (contact picker, new-contact form), EventKit (calendar/reminders access, saving
// events and reminders, predicates) and EventKitUI (the New Event form).
import SwiftUI
import Contacts
import ContactsUI
import EventKit
import EventKitUI

@main
struct HelloPersonalApp: App {
    @StateObject private var model = PersonalModel()
    var body: some Scene { WindowGroup { ContentView(model: model) } }
}

@MainActor func topController() -> UIViewController? {
    var vc = UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController
    while let p = vc?.presentedViewController { vc = p }
    return vc
}

final class PersonalModel: NSObject, ObservableObject, CNContactPickerDelegate, CNContactViewControllerDelegate, EKEventEditViewDelegate {
    let contacts = CNContactStore()
    let events = EKEventStore()
    @Published var contactText = "—"
    @Published var picked = "Nobody picked"
    @Published var calendarText = "—"
    var eventStoreChange: NSObjectProtocol?

    // MARK: Contacts
    func requestContacts() {
        contacts.requestAccess(for: .contacts) { ok, error in
            let s = CNContactStore.authorizationStatus(for: .contacts)
            print("contacts access \(ok) status \(s.rawValue) error \((error as? CNError)?.code.rawValue ?? 0)")
            DispatchQueue.main.async { self.listContacts() }
        }
    }
    func listContacts() {
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let req = CNContactFetchRequest(keysToFetch: keys)
        req.sortOrder = .givenName
        var names: [String] = []
        do {
            try contacts.enumerateContacts(with: req) { c, _ in names.append("\(c.givenName) \(c.familyName)") }
            print("contacts \(names.count): \(names.joined(separator: ", "))")
            let kate = try contacts.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: "kate"), keysToFetch: keys)
            if let k = kate.first {
                print("kate phone \(k.phoneNumbers.first?.value.stringValue ?? "-") label \(CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: k.phoneNumbers.first?.label ?? "")) emailKeyAvailable \(k.isKeyAvailable(CNContactEmailAddressesKey))")
            }
            let byPhone = try contacts.unifiedContacts(matching: CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: "8885555512")), keysToFetch: keys)
            print("byPhone \(byPhone.map { $0.givenName })")
            contactText = "\(names.count) contacts"
        } catch {
            print("contacts error \((error as? CNError)?.code.rawValue ?? -1)")
            contactText = "No access"
        }
    }
    func addContact() {
        let c = CNMutableContact()
        c.givenName = "Ada"; c.familyName = "Lovelace"; c.organizationName = "Analytical Engines"
        c.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "(555) 010-1815"))]
        let addr = CNMutablePostalAddress(); addr.street = "12 St James's Square"; addr.city = "London"; addr.country = "United Kingdom"
        c.postalAddresses = [CNLabeledValue(label: CNLabelHome, value: addr)]
        let save = CNSaveRequest(); save.add(c, toContainerWithIdentifier: nil)
        do {
            try contacts.execute(save)
            let found = try contacts.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: "Ada Love"),
                                                     keysToFetch: [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPostalAddressesKey as CNKeyDescriptor])
            print("added \(found.map { CNContactFormatter.string(from: $0, style: .fullName) ?? "?" }) city \(found.first?.postalAddresses.first?.value.city ?? "-")")
            // update with only some keys fetched: the rest is kept
            if let m = found.first?.mutableCopy() as? CNMutableContact {
                m.familyName = "King"
                let up = CNSaveRequest(); up.update(m); try contacts.execute(up)
                let again = try contacts.unifiedContact(withIdentifier: m.identifier, keysToFetch: [CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor])
                print("updated \(again.familyName) phone kept \(again.phoneNumbers.first?.value.stringValue ?? "-")")
            }
            listContacts()
        } catch { print("add error \((error as? CNError)?.code.rawValue ?? -1)") }
    }
    @MainActor func pickContact() {
        let picker = CNContactPickerViewController()
        picker.delegate = self
        topController()?.present(picker, animated: true)
    }
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        picked = "\(contact.givenName) \(contact.familyName)"
        print("picked \(picked) phones \(contact.phoneNumbers.count)")
    }
    func contactPickerDidCancel(_ picker: CNContactPickerViewController) { print("picker cancelled") }
    @MainActor func newContact() {
        let vc = CNContactViewController(forNewContact: nil)
        vc.delegate = self
        topController()?.present(UINavigationController(rootViewController: vc), animated: true)
    }
    func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
        print("new contact \(contact.map { "\($0.givenName) \($0.familyName)" } ?? "cancelled")")
        viewController.dismiss(animated: true)
    }

    // MARK: Calendar
    func requestCalendar() {
        events.requestFullAccessToEvents { ok, error in
            print("calendar access \(ok) status \(EKEventStore.authorizationStatus(for: .event).rawValue)")
            DispatchQueue.main.async { self.listEvents() }
        }
    }
    func requestWriteOnlyCalendar() {
        events.requestWriteOnlyAccessToEvents { ok, _ in
            DispatchQueue.main.async {
                let e = EKEvent(eventStore: self.events)
                e.title = "Write-only event"
                e.startDate = Date().addingTimeInterval(7200); e.endDate = e.startDate.addingTimeInterval(1800)
                e.calendar = self.events.defaultCalendarForNewEvents
                let saved = (try? self.events.save(e, span: .thisEvent)) != nil
                print("calendar write-only \(ok) status \(EKEventStore.authorizationStatus(for: .event).rawValue) read \(self.events.calendars(for: .event).count) saved \(saved)")
            }
        }
    }
    func requestReminders() {
        events.requestFullAccessToReminders { ok, _ in
            print("reminders access \(ok)")
            DispatchQueue.main.async {
                guard ok, let list = self.events.defaultCalendarForNewReminders() else { return }
                let r = EKReminder(eventStore: self.events)
                r.title = "Buy milk"; r.calendar = list
                r.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
                do { try self.events.save(r, commit: true) } catch { print("reminder error \(error)") }
                self.events.fetchReminders(matching: self.events.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)) { rs in
                    print("reminders \(rs?.map { $0.title ?? "" } ?? []) in \(list.title)")
                    guard let saved = rs?.first else { return }
                    saved.completionDate = Date()
                    try? self.events.save(saved, commit: true)
                    let completed = self.events.predicateForCompletedReminders(withCompletionDateStarting: Date().addingTimeInterval(-60), ending: Date().addingTimeInterval(60), calendars: [list])
                    self.events.fetchReminders(matching: completed) { done in
                        print("completed reminders \(done?.map { $0.title ?? "" } ?? [])")
                        try? self.events.remove(saved, commit: true)
                        self.events.fetchReminders(matching: self.events.predicateForReminders(in: nil)) { left in
                            print("reminders after remove \(left?.count ?? -1)")
                        }
                    }
                }
            }
        }
    }
    func addEvent() {
        eventStoreChange = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: events, queue: .main) { _ in
            print("event store changed")
        }
        let e = EKEvent(eventStore: events)
        e.title = "Team lunch"; e.location = "Caffè Macs"
        e.startDate = Date().addingTimeInterval(3600); e.endDate = e.startDate.addingTimeInterval(3600)
        e.calendar = events.defaultCalendarForNewEvents
        e.addAlarm(EKAlarm(relativeOffset: -300))
        e.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 2, end: nil))
        do { try events.save(e, span: .thisEvent); print("saved event \(e.eventIdentifier != nil) in \(e.calendar?.title ?? "-")") }
        catch { print("save event error \((error as? EKError)?.code.rawValue ?? -1)") }
        if let stored = events.event(withIdentifier: e.eventIdentifier) {
            print("event metadata alarms \(stored.alarms?.first?.relativeOffset ?? 0) recurrence \(stored.recurrenceRules?.first?.frequency.rawValue ?? -1)/\(stored.recurrenceRules?.first?.interval ?? 0)")
        }
        let removed = EKEvent(eventStore: events)
        removed.title = "Remove me"; removed.startDate = e.startDate; removed.endDate = e.endDate; removed.calendar = e.calendar
        do {
            try events.save(removed, span: .thisEvent)
            try events.remove(removed, span: .thisEvent)
            print("event removed \(events.event(withIdentifier: removed.eventIdentifier) == nil)")
        } catch { print("remove event error \(error)") }
        listEvents()
    }
    func listEvents() {
        let p = events.predicateForEvents(withStart: Date().addingTimeInterval(-86400), end: Date().addingTimeInterval(7 * 86400), calendars: nil)
        let list = events.events(matching: p)
        print("calendars \(events.calendars(for: .event).map(\.title)) events \(list.map { $0.title ?? "" })")
        calendarText = "\(list.count) events"
    }
    @MainActor func editEvent() {
        let vc = EKEventEditViewController()
        vc.eventStore = events
        vc.editViewDelegate = self
        topController()?.present(vc, animated: true)
    }
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        print("edit \(action == .saved ? "saved" : "canceled") \(controller.event?.title ?? "") location \(controller.event?.location ?? "-") allDay \(controller.event?.isAllDay ?? false)")
        controller.dismiss(animated: true)
        listEvents()
    }
}

struct ContentView: View {
    @ObservedObject var model: PersonalModel
    var body: some View {
        NavigationStack {
            List {
                Section("Contacts") {
                    Text(model.contactText).accessibilityIdentifier("contactText")
                    Text(model.picked).accessibilityIdentifier("picked")
                    Button("Access Contacts") { model.requestContacts() }.accessibilityIdentifier("contactsAccess")
                    Button("Add Ada") { model.addContact() }.accessibilityIdentifier("addContact")
                    Button("Pick a Contact") { model.pickContact() }.accessibilityIdentifier("pickContact")
                    Button("New Contact Form") { model.newContact() }.accessibilityIdentifier("newContact")
                }
                Section("Calendar") {
                    Text(model.calendarText).accessibilityIdentifier("calendarText")
                    Button("Access Calendar") { model.requestCalendar() }.accessibilityIdentifier("calendarAccess")
                    Button("Write-only Calendar") { model.requestWriteOnlyCalendar() }.accessibilityIdentifier("calendarWriteOnly")
                    Button("Add Lunch") { model.addEvent() }.accessibilityIdentifier("addEvent")
                    Button("New Event Form") { model.editEvent() }.accessibilityIdentifier("editEvent")
                    Button("Reminders") { model.requestReminders() }.accessibilityIdentifier("reminders")
                }
            }
            .navigationTitle("Personal")
        }
    }
}
