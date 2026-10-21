// Sample: personal data on isim — Contacts (permission alert, the seeded address book, predicates, save requests,
// unfetched-key safety), ContactsUI (contact picker, new-contact form), EventKit (calendar/reminders access, saving
// events and reminders, predicates, recurring events and their occurrences, structured locations, alarms, attendees)
// and EventKitUI (the New Event form, the calendar chooser).
import SwiftUI
import Contacts
import ContactsUI
import EventKit
import CoreLocation
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

final class PersonalModel: NSObject, ObservableObject, CNContactPickerDelegate, CNContactViewControllerDelegate, EKEventEditViewDelegate,
                           EKCalendarChooserDelegate {
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

    // MARK: Recurrence, spans, locations, alarms, attendees
    /// next Monday at 9:00 (a fixed weekday, so the occurrences below are the same every run)
    var nextMonday: Date {
        let c = Calendar.current
        var d = c.startOfDay(for: Date().addingTimeInterval(86400))
        while c.component(.weekday, from: d) != 2 { d = c.date(byAdding: .day, value: 1, to: d)! }
        return c.date(bySettingHour: 9, minute: 0, second: 0, of: d)!
    }
    func occurrences(_ title: String, _ from: Date, _ days: Int) -> [EKEvent] {
        events.events(matching: events.predicateForEvents(withStart: from, end: from.addingTimeInterval(Double(days) * 86400), calendars: nil))
            .filter { $0.title.hasPrefix(title) }
    }
    func weekdays(_ list: [EKEvent]) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE"
        return list.map { f.string(from: $0.startDate) }.joined(separator: ",")
    }
    func recurring() {
        let cal = events.defaultCalendarForNewEvents
        let monday = nextMonday
        // weekly on Monday, Wednesday and Friday, six times
        let standup = EKEvent(eventStore: events)
        standup.title = "Standup"; standup.calendar = cal
        standup.startDate = monday; standup.endDate = monday.addingTimeInterval(900)
        let rule = EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, daysOfTheWeek: [EKRecurrenceDayOfWeek(.monday), EKRecurrenceDayOfWeek(.wednesday), EKRecurrenceDayOfWeek(.friday)],
                                    daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: EKRecurrenceEnd(occurrenceCount: 6))
        standup.addRecurrenceRule(rule)
        do { try events.save(standup, span: .futureEvents) } catch { print("recurring save error \(error)") }
        var list = occurrences("Standup", monday, 21)
        print("recurring \(list.count) \(weekdays(list)) one id \(Set(list.map(\.eventIdentifier)).count == 1) rule \(standup.recurrenceRules?.first?.daysOfTheWeek?.map(\.description).joined(separator: ",") ?? "-")")
        // the second Tuesday of each month, three times; the last day of each month
        let club = EKEvent(eventStore: events)
        club.title = "Book club"; club.calendar = cal
        club.startDate = monday; club.endDate = monday.addingTimeInterval(3600)
        club.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, daysOfTheWeek: [EKRecurrenceDayOfWeek(.tuesday, weekNumber: 2)], daysOfTheMonth: nil,
                                                monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: EKRecurrenceEnd(occurrenceCount: 3)))
        try? events.save(club, span: .futureEvents)
        let clubs = occurrences("Book club", monday, 120)
        let c = Calendar.current
        print("monthly \(clubs.count) second tuesdays \(clubs.allSatisfy { c.component(.weekday, from: $0.startDate) == 3 && (8...14).contains(c.component(.day, from: $0.startDate)) })")
        let rent = EKEvent(eventStore: events)
        rent.title = "Rent"; rent.calendar = cal; rent.startDate = monday; rent.endDate = monday.addingTimeInterval(600)
        rent.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, daysOfTheWeek: nil, daysOfTheMonth: [-1], monthsOfTheYear: nil,
                                                weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: EKRecurrenceEnd(occurrenceCount: 2)))
        try? events.save(rent, span: .futureEvents)
        let rents = occurrences("Rent", monday, 70)
        print("month ends \(rents.count) last days \(rents.allSatisfy { c.component(.day, from: $0.startDate.addingTimeInterval(86400)) == 1 })")
        // this occurrence only: moved an hour later (detached); one removed; the rest of the series from the fifth
        let wednesday = list[1]
        wednesday.title = "Standup (moved)"
        wednesday.startDate = wednesday.startDate.addingTimeInterval(3600); wednesday.endDate = wednesday.endDate.addingTimeInterval(3600)
        try? events.save(wednesday, span: .thisEvent)
        list = occurrences("Standup", monday, 21)
        print("detached \(list.filter(\.isDetached).map(\.title!)) count \(list.count) series \(list.filter { !$0.isDetached }.count)")
        if let friday = list.first(where: { !$0.isDetached && c.component(.weekday, from: $0.startDate) == 6 }) { try? events.remove(friday, span: .thisEvent) }
        list = occurrences("Standup", monday, 21)
        print("after removing one \(list.count) \(weekdays(list))")
        if list.count > 3 { try? events.remove(list[3], span: .futureEvents) }
        list = occurrences("Standup", monday, 21)
        print("after removing future \(list.count) \(weekdays(list))")
        // a structured location and a location alarm (stored; proximity alarms do not fire on isim)
        let place = EKStructuredLocation(title: "Apple Park")
        place.geoLocation = CLLocation(latitude: 37.3349, longitude: -122.00902); place.radius = 150
        guard let series = events.event(withIdentifier: standup.eventIdentifier) else { return }
        series.structuredLocation = place
        let arrive = EKAlarm(relativeOffset: 0); arrive.structuredLocation = place; arrive.proximity = .enter
        let mail = EKAlarm(relativeOffset: -600); mail.emailAddress = "ada@example.com"
        series.alarms = [arrive, mail]
        try? events.save(series, span: .futureEvents)
        if let back = events.event(withIdentifier: standup.eventIdentifier), let loc = back.structuredLocation, let g = loc.geoLocation {
            print(String(format: "location %@ %.4f,%.4f radius %.0f text %@ alarms %@", loc.title ?? "-", g.coordinate.latitude, g.coordinate.longitude, loc.radius,
                         back.location ?? "-", (back.alarms ?? []).map { "\($0.proximity.rawValue)/\($0.type.rawValue)" }.joined(separator: ",")))
        }
        // attendees come from the calendar (an invitation in the seeded database)
        let all = events.events(matching: events.predicateForEvents(withStart: Date().addingTimeInterval(-86400 * 2), end: Date().addingTimeInterval(86400 * 30), calendars: nil))
        if let review = all.first(where: { $0.hasAttendees }) {
            let people = (review.attendees ?? []).map { "\($0.name ?? "-") \($0.participantStatus.rawValue)/\($0.participantRole.rawValue)/\($0.participantType.rawValue)" }
            print("attendees \(review.title!) \(people.joined(separator: ", ")) organizer \(review.organizer?.name ?? "-") \(review.organizer?.url.absoluteString ?? "-")")
        }
        // an alarm two seconds from now fires as Calendar's alert
        let coffee = EKEvent(eventStore: events)
        coffee.title = "Coffee"; coffee.location = "Caffè Macs"; coffee.calendar = cal
        coffee.startDate = Date().addingTimeInterval(62); coffee.endDate = coffee.startDate.addingTimeInterval(1800)
        coffee.addAlarm(EKAlarm(relativeOffset: -60))
        do { try events.save(coffee, span: .thisEvent); print("alarm set") } catch { print("alarm error \(error)") }
    }
    @MainActor func chooseCalendars() {
        let chooser = EKCalendarChooser(selectionStyle: .multiple, displayStyle: .allCalendars, entityType: .event, eventStore: events)
        chooser.showsDoneButton = true; chooser.showsCancelButton = true
        chooser.delegate = self
        topController()?.present(UINavigationController(rootViewController: chooser), animated: true)
    }
    func calendarChooserSelectionDidChange(_ calendarChooser: EKCalendarChooser) {
        print("chooser selected \(calendarChooser.selectedCalendars.map(\.title).sorted())")
    }
    func calendarChooserDidFinish(_ calendarChooser: EKCalendarChooser) {
        print("chooser finished \(calendarChooser.selectedCalendars.map(\.title).sorted())")
        calendarChooser.dismiss(animated: true)
    }
    func calendarChooserDidCancel(_ calendarChooser: EKCalendarChooser) { print("chooser cancelled"); calendarChooser.dismiss(animated: true) }
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
                    Button("Recurring Events") { model.recurring() }.accessibilityIdentifier("recurring")
                    Button("Choose Calendars") { model.chooseCalendars() }.accessibilityIdentifier("chooseCalendars")
                }
            }
            .navigationTitle("Personal")
        }
    }
}
