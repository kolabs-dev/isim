// CNContactStore: the device address book ($ISIM_DATA/Library/AddressBook/contacts.json, seeded with the Simulator's
// sample contacts on first use), the permission alert (remembered per app) and save requests.
// Automation: ISIM_CONTACTS_PERMISSION=allow|limited|deny answers the alert without showing it.
import UIKit

@objc public enum CNEntityType: Int, Sendable { case contacts = 0 }
@objc public enum CNAuthorizationStatus: Int, Sendable { case notDetermined = 0, restricted, denied, authorized, limited }
@objc public enum CNContainerType: Int, Sendable { case unassigned = 0, local, exchange, cardDAV }

public let CNContactStoreDidChangeNotification = "CNContactStoreDidChangeNotification"
extension Notification.Name {
    public static let CNContactStoreDidChange = Notification.Name(CNContactStoreDidChangeNotification)
}

open class CNContainer: NSObject, @unchecked Sendable {
    public let identifier: String, name: String, type: CNContainerType
    init(identifier: String, name: String, type: CNContainerType) { self.identifier = identifier; self.name = name; self.type = type }
    open class func predicateForContainers(withIdentifiers identifiers: [String]) -> NSPredicate {
        NSPredicate { obj, _ in identifiers.contains((obj as? CNContainer)?.identifier ?? "") }
    }
    open class func predicateForContainerOfContact(withIdentifier contactIdentifier: String) -> NSPredicate { NSPredicate(value: true) }
}
open class CNGroup: NSObject, NSCopying, NSMutableCopying, @unchecked Sendable {
    public internal(set) var identifier: String
    var _name: String
    open var name: String { _name }
    init(identifier: String, name: String) { self.identifier = identifier; _name = name }
    public override init() { identifier = UUID().uuidString + ":ABGroup"; _name = "" }
    public func copy(with zone: OpaquePointer? = nil) -> Any { CNGroup(identifier: identifier, name: _name) }
    public func mutableCopy(with zone: OpaquePointer? = nil) -> Any { let g = CNMutableGroup(); g.identifier = identifier; g._name = _name; return g }
}
open class CNMutableGroup: CNGroup, @unchecked Sendable {
    open override var name: String { get { _name } set { _name = newValue } }
}

open class CNFetchRequest: NSObject, @unchecked Sendable {}
open class CNContactFetchRequest: CNFetchRequest, @unchecked Sendable {
    open var predicate: NSPredicate?
    open var keysToFetch: [CNKeyDescriptor]
    open var mutableObjects = false
    open var unifyResults = true
    open var sortOrder: CNContactSortOrder = .none
    public init(keysToFetch: [CNKeyDescriptor]) { self.keysToFetch = keysToFetch }
}

open class CNSaveRequest: NSObject, @unchecked Sendable {
    enum Op { case add(CNMutableContact, String?), update(CNMutableContact), delete(CNMutableContact), addGroup(CNMutableGroup), deleteGroup(CNMutableGroup)
        case addMember(CNContact, CNGroup), removeMember(CNContact, CNGroup) }
    var ops: [Op] = []
    open var transactionAuthor: String?
    open var shouldRefetchContacts = true
    public override init() { super.init() }
    open func add(_ contact: CNMutableContact, toContainerWithIdentifier identifier: String?) { ops.append(.add(contact, identifier)) }
    open func update(_ contact: CNMutableContact) { ops.append(.update(contact)) }
    open func delete(_ contact: CNMutableContact) { ops.append(.delete(contact)) }
    open func add(_ group: CNMutableGroup, toContainerWithIdentifier identifier: String?) { ops.append(.addGroup(group)) }
    open func delete(_ group: CNMutableGroup) { ops.append(.deleteGroup(group)) }
    open func addMember(_ contact: CNContact, to group: CNGroup) { ops.append(.addMember(contact, group)) }
    open func removeMember(_ contact: CNContact, from group: CNGroup) { ops.append(.removeMember(contact, group)) }
}

struct _CNBook: Codable {
    var contacts: [_CNData] = []
    var groups: [String: String] = [:]          // identifier -> name
}

enum _CNDB {
    static var path: String { (_Privacy.deviceDir("Library/AddressBook") as NSString).appendingPathComponent("contacts.json") }
    static func load() -> _CNBook {
        if let b = _Privacy.readJSON(_CNBook.self, path) { return b }
        let b = _CNBook(contacts: seed(), groups: [:])
        save(b)
        NSLog("isim Contacts: created the address book with %d sample contacts at %@", b.contacts.count, path)
        return b
    }
    static func save(_ b: _CNBook) { _Privacy.writeJSON(b, path) }

    /// the Simulator's sample contacts
    static func seed() -> [_CNData] {
        func person(_ given: String, _ family: String, middle: String = "", suffix: String = "", nickname: String = "", org: String = "", job: String = "",
                    phones: [(String, String)], emails: [(String, String)], address: (String, String, String, String, String)?, birthday: (Int, Int, Int)? = nil,
                    url: String? = nil) -> _CNData {
            var d = _CNData()
            d.givenName = given; d.familyName = family; d.middleName = middle; d.nameSuffix = suffix; d.nickname = nickname
            d.organizationName = org; d.jobTitle = job
            d.phones = phones.map { _CNLabeled(id: UUID().uuidString, label: $0.0, value: $0.1) }
            d.emails = emails.map { _CNLabeled(id: UUID().uuidString, label: $0.0, value: $0.1) }
            if let a = address {
                d.addresses = [_CNLabeled(id: UUID().uuidString, label: a.0,
                                          value: _CNAddress(street: a.1, city: a.2, state: a.3, postalCode: a.4, country: "USA", isoCountryCode: "us"))]
            }
            if let b = birthday { d.birthday = _CNDay(year: b.0, month: b.1, day: b.2) }
            if let url { d.urls = [_CNLabeled(id: UUID().uuidString, label: CNLabelHome, value: url)] }
            d.modified = Date().timeIntervalSince1970
            return d
        }
        return [
            person("Kate", "Bell", org: "Creative Consulting", job: "Producer",
                   phones: [(CNLabelPhoneNumberMobile, "(555) 564-8583"), (CNLabelPhoneNumberMain, "(415) 555-3695")],
                   emails: [(CNLabelWork, "kate-bell@mac.com")], address: (CNLabelWork, "165 Davis Street", "Hillsborough", "CA", "94010"),
                   birthday: (1978, 1, 20), url: "www.icloud.com"),
            person("Daniel", "Higgins", suffix: "Jr.",
                   phones: [(CNLabelHome, "555-478-7672"), (CNLabelPhoneNumberMobile, "(408) 555-5270"), (CNLabelPhoneNumberHomeFax, "(408) 555-3514")],
                   emails: [(CNLabelHome, "d-higgins@mac.com")], address: (CNLabelHome, "332 Laguna Street", "Corte Madera", "CA", "94925")),
            person("John", "Appleseed",
                   phones: [(CNLabelPhoneNumberMobile, "888-555-5512"), (CNLabelHome, "888-555-1212")],
                   emails: [(CNLabelWork, "John-Appleseed@mac.com")], address: (CNLabelWork, "3494 Kuhl Avenue", "Atlanta", "GA", "30303"),
                   birthday: (1980, 6, 22)),
            person("Anna", "Haro", nickname: "Annie",
                   phones: [(CNLabelHome, "555-522-8243")], emails: [(CNLabelHome, "anna-haro@mac.com")],
                   address: (CNLabelHome, "1001  Leavenworth Street", "Sausalito", "CA", "94965"), birthday: (1985, 8, 29)),
            person("Hank", "Zakroff", middle: "M.", org: "Financial Services Inc.", job: "Portfolio Manager",
                   phones: [(CNLabelWork, "(555) 766-4823"), (CNLabelOther, "(707) 555-1854")], emails: [(CNLabelWork, "hank-zakroff@mac.com")],
                   address: (CNLabelWork, "1741 Kearny Street", "San Rafael", "CA", "94901")),
            person("David", "Taylor", phones: [(CNLabelHome, "555-610-6679")], emails: [],
                   address: (CNLabelHome, "1747 Steuart Street", "Tiburon", "CA", "94920"), birthday: (1998, 6, 15)),
        ]
    }
}

enum _CNAuth {
    static var status: CNAuthorizationStatus {
        _Privacy.stored("contacts").flatMap { CNAuthorizationStatus(rawValue: $0) } ?? .notDetermined
    }
    static var limitedIDs: Set<String> {
        get { Set((UserDefaults.standard.array(forKey: "_ISIMPrivacy.contacts.limited") as? [String]) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: "_ISIMPrivacy.contacts.limited") }
    }
    static var authorized: Bool { status == .authorized || status == .limited }
}

open class CNContactStore: NSObject, @unchecked Sendable {
    public override init() { super.init() }

    open class func authorizationStatus(for entityType: CNEntityType) -> CNAuthorizationStatus { _CNAuth.status }

    open func requestAccess(for entityType: CNEntityType, completionHandler: @escaping (Bool, Error?) -> Void) {
        let done: (CNAuthorizationStatus) -> Void = { s in
            let ok = s == .authorized || s == .limited
            _Privacy.reply { completionHandler(ok, ok ? nil : CNError(.authorizationDenied)) }
        }
        let s = _CNAuth.status
        if s != .notDetermined { done(s); return }
        guard let purpose = _Privacy.usage("NSContactsUsageDescription", "Contacts") else { done(.denied); return }
        _Privacy.onMain {
            func answer(_ s: CNAuthorizationStatus) {
                _Privacy.store("contacts", s.rawValue)
                NSLog("isim Contacts: access %@ for %@", s == .authorized ? "allowed" : s == .limited ? "limited" : "denied", _Privacy.appName)
                done(s)
            }
            if let sc = _Privacy.scripted("CONTACTS") {
                switch sc {
                case "deny", "denied", "no", "0": answer(.denied)
                case "limited": _CNAuth.limitedIDs = []; answer(_Privacy.osMajor >= 18 ? .limited : .authorized)
                default: answer(.authorized)
                }
                return
            }
            let title = "“\(_Privacy.appName)” Would Like to Access Your Contacts"
            if _Privacy.osMajor >= 18 {
                // iOS 18 adds limited access (adapted: one alert stands in for iOS 18's two-step prompt)
                _Privacy.alert(title, purpose, [("Limit Access…", .default), ("Allow Full Access", .default), ("Don’t Allow", .default)]) { i in
                    switch i {
                    case 0:
                        _CNSelection.present(all: _CNDB.load().contacts, selected: []) { ids in
                            _CNAuth.limitedIDs = ids
                            answer(.limited)
                        }
                    case 1: answer(.authorized)
                    default: answer(.denied)
                    }
                }
            } else {
                _Privacy.alert(title, purpose, [("Don’t Allow", .default), ("OK", .default)]) { i in answer(i == 1 ? .authorized : .denied) }
            }
        }
    }
    open func requestAccess(for entityType: CNEntityType) async throws -> Bool {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Bool, Error>) in
            requestAccess(for: entityType) { ok, e in if let e { k.resume(throwing: e) } else { k.resume(returning: ok) } }
        }
    }

    func readable() throws -> [_CNData] {
        guard _CNAuth.authorized else { throw CNError(.authorizationDenied) }
        let all = _CNDB.load().contacts
        if _CNAuth.status == .limited { let ids = _CNAuth.limitedIDs; return all.filter { ids.contains($0.id) } }
        return all
    }
    func materialize(_ d: [_CNData], _ keys: [CNKeyDescriptor], mutable: Bool = false) -> [CNContact] {
        let k = _cnKeyStrings(keys).union([CNContactIdentifierKey])
        return d.map { mutable ? CNMutableContact($0, keys: k) : CNContact($0, keys: k) }
    }

    // MARK: fetching
    open func unifiedContacts(matching predicate: NSPredicate, keysToFetch keys: [CNKeyDescriptor]) throws -> [CNContact] {
        let all = try readable()
        let hits = all.filter { predicate.evaluate(with: CNContact($0, keys: nil)) }
        return materialize(hits, keys)
    }
    open func unifiedContact(withIdentifier identifier: String, keysToFetch keys: [CNKeyDescriptor]) throws -> CNContact {
        guard let d = try readable().first(where: { $0.id == identifier }) else { throw CNError(.recordDoesNotExist) }
        return materialize([d], keys)[0]
    }
    open func unifiedMeContactWithKeys(toFetch keys: [CNKeyDescriptor]) throws -> CNContact { throw CNError(.recordDoesNotExist) }
    open func enumerateContacts(with fetchRequest: CNContactFetchRequest, usingBlock block: (CNContact, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        var all = try readable()
        if let p = fetchRequest.predicate { all = all.filter { p.evaluate(with: CNContact($0, keys: nil)) } }
        if fetchRequest.sortOrder != .none { all.sort { _CNSort.key($0, fetchRequest.sortOrder) < _CNSort.key($1, fetchRequest.sortOrder) } }
        var stop = ObjCBool(false)
        for c in materialize(all, fetchRequest.keysToFetch, mutable: fetchRequest.mutableObjects) {
            block(c, &stop)
            if stop.boolValue { break }
        }
    }
    open func containers(matching predicate: NSPredicate?) throws -> [CNContainer] {
        guard _CNAuth.authorized else { throw CNError(.authorizationDenied) }
        return [CNContainer(identifier: "isim-local", name: "", type: .local)]
    }
    open func groups(matching predicate: NSPredicate?) throws -> [CNGroup] {
        guard _CNAuth.authorized else { throw CNError(.authorizationDenied) }
        return _CNDB.load().groups.map { CNGroup(identifier: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
    }
    open func defaultContainerIdentifier() -> String { "isim-local" }
    open var currentHistoryToken: Data? { Data("\(_CNDB.load().contacts.count)".utf8) }

    // MARK: saving
    open func execute(_ saveRequest: CNSaveRequest) throws {
        guard _CNAuth.authorized else { throw CNError(.authorizationDenied) }
        var book = _CNDB.load()
        var limited = _CNAuth.limitedIDs
        for op in saveRequest.ops {
            switch op {
            case .add(let c, let container):
                if book.contacts.contains(where: { $0.id == c.d.id }) { throw CNError(.insertedRecordAlreadyExists) }
                var d = c.d; d.container = container ?? "isim-local"; d.modified = Date().timeIntervalSince1970
                book.contacts.append(d)
                limited.insert(d.id)                 // apps with limited access see what they add
            case .update(let c):
                guard let i = book.contacts.firstIndex(where: { $0.id == c.d.id }) else { throw CNError(.recordDoesNotExist) }
                if _CNAuth.status == .limited && !limited.contains(c.d.id) { throw CNError(.recordDoesNotExist) }
                var d = c.d; d.modified = Date().timeIntervalSince1970
                // keys that were not fetched keep their stored values
                if let f = c.fetched { d = _CNMerge.merge(stored: book.contacts[i], changed: d, keys: f) }
                book.contacts[i] = d
            case .delete(let c):
                guard book.contacts.contains(where: { $0.id == c.d.id }) else { throw CNError(.recordDoesNotExist) }
                book.contacts.removeAll { $0.id == c.d.id }
                limited.remove(c.d.id)
            case .addGroup(let g): book.groups[g.identifier] = g.name
            case .deleteGroup(let g): book.groups[g.identifier] = nil
            case .addMember(let c, let g):
                if let i = book.contacts.firstIndex(where: { $0.id == c.d.id }), !book.contacts[i].groups.contains(g.identifier) { book.contacts[i].groups.append(g.identifier) }
            case .removeMember(let c, let g):
                if let i = book.contacts.firstIndex(where: { $0.id == c.d.id }) { book.contacts[i].groups.removeAll { $0 == g.identifier } }
            }
        }
        _CNDB.save(book)
        if _CNAuth.status == .limited { _CNAuth.limitedIDs = limited }
        NotificationCenter.default.post(name: .CNContactStoreDidChange, object: self)
    }

    /// isim's ContactsUI reads the whole address book (its pickers run outside the app's permission, like iOS)
    @_spi(isim) public static func _isimAllContacts() -> [CNContact] {
        _CNDB.load().contacts.sorted { _CNSort.key($0, .familyName) < _CNSort.key($1, .familyName) }.map { CNContact($0, keys: nil) }
    }
    @_spi(isim) public static func _isimSave(_ contact: CNContact) {
        var book = _CNDB.load()
        var d = contact.d; d.modified = Date().timeIntervalSince1970
        if let i = book.contacts.firstIndex(where: { $0.id == d.id }) { book.contacts[i] = d } else { book.contacts.append(d) }
        _CNDB.save(book)
        NotificationCenter.default.post(name: .CNContactStoreDidChange, object: nil)
    }
    @_spi(isim) public static func _isimFullName(_ c: CNContact) -> String { CNContactFormatter.string(from: CNContact(c.d, keys: nil), style: .fullName) ?? "No Name" }
    @_spi(isim) public static func _isimSortKey(_ c: CNContact) -> String { _CNSort.key(c.d, .familyName) }
}

enum _CNMerge {
    static func merge(stored: _CNData, changed: _CNData, keys: Set<String>) -> _CNData {
        var d = stored
        func k(_ key: String) -> Bool { keys.contains(key) }
        if k(CNContactTypeKey) { d.type = changed.type }
        if k(CNContactNamePrefixKey) { d.namePrefix = changed.namePrefix }
        if k(CNContactGivenNameKey) { d.givenName = changed.givenName }
        if k(CNContactMiddleNameKey) { d.middleName = changed.middleName }
        if k(CNContactFamilyNameKey) { d.familyName = changed.familyName }
        if k(CNContactNameSuffixKey) { d.nameSuffix = changed.nameSuffix }
        if k(CNContactNicknameKey) { d.nickname = changed.nickname }
        if k(CNContactOrganizationNameKey) { d.organizationName = changed.organizationName }
        if k(CNContactDepartmentNameKey) { d.departmentName = changed.departmentName }
        if k(CNContactJobTitleKey) { d.jobTitle = changed.jobTitle }
        if k(CNContactBirthdayKey) { d.birthday = changed.birthday }
        if k(CNContactNoteKey) { d.note = changed.note }
        if k(CNContactImageDataKey) { d.imageData = changed.imageData }
        if k(CNContactPhoneNumbersKey) { d.phones = changed.phones }
        if k(CNContactEmailAddressesKey) { d.emails = changed.emails }
        if k(CNContactUrlAddressesKey) { d.urls = changed.urls }
        if k(CNContactPostalAddressesKey) { d.addresses = changed.addresses }
        if k(CNContactRelationsKey) { d.relations = changed.relations }
        d.modified = changed.modified
        return d
    }
}

// MARK: - vCard

open class CNContactVCardSerialization: NSObject {
    open class func descriptorForRequiredKeys() -> CNKeyDescriptor {
        _CNKeys([CNContactGivenNameKey, CNContactFamilyNameKey, CNContactMiddleNameKey, CNContactNamePrefixKey, CNContactNameSuffixKey,
                 CNContactOrganizationNameKey, CNContactJobTitleKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactPostalAddressesKey,
                 CNContactUrlAddressesKey, CNContactBirthdayKey, CNContactNicknameKey, CNContactNoteKey])
    }
    open class func data(with contacts: [Any]) throws -> Data {
        var out = ""
        for case let c as CNContact in contacts {
            let d = c.d
            out += "BEGIN:VCARD\r\nVERSION:3.0\r\n"
            out += "PRODID:-//Apple Inc.//iPhone OS 18.0//EN\r\n"
            out += "N:\(d.familyName);\(d.givenName);\(d.middleName);\(d.namePrefix);\(d.nameSuffix)\r\n"
            out += "FN:\(CNContactFormatter.string(from: c, style: .fullName) ?? "")\r\n"
            if !d.nickname.isEmpty { out += "NICKNAME:\(d.nickname)\r\n" }
            if !d.organizationName.isEmpty { out += "ORG:\(d.organizationName);\(d.departmentName)\r\n" }
            if !d.jobTitle.isEmpty { out += "TITLE:\(d.jobTitle)\r\n" }
            func type(_ l: String?) -> String { (l.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) } ?? "other").uppercased().replacingOccurrences(of: " ", with: "") }
            for p in d.phones { out += "TEL;type=\(type(p.label));type=VOICE:\(p.value)\r\n" }
            for e in d.emails { out += "EMAIL;type=INTERNET;type=\(type(e.label)):\(e.value)\r\n" }
            for a in d.addresses { out += "ADR;type=\(type(a.label)):;;\(a.value.street);\(a.value.city);\(a.value.state);\(a.value.postalCode);\(a.value.country)\r\n" }
            for u in d.urls { out += "URL;type=\(type(u.label)):\(u.value)\r\n" }
            if let b = d.birthday, let y = b.year, let m = b.month, let dd = b.day { out += String(format: "BDAY:%04d-%02d-%02d\r\n", y, m, dd) }
            if !d.note.isEmpty { out += "NOTE:\(d.note)\r\n" }
            out += "END:VCARD\r\n"
        }
        return Data(out.utf8)
    }
    open class func contacts(with data: Data) throws -> [CNContact] {
        guard let text = String(data: data, encoding: .utf8), text.contains("BEGIN:VCARD") else { throw CNError(.vCardMalformed) }
        var result: [CNContact] = []
        var cur: CNMutableContact?
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            guard let colon = line.firstIndex(of: ":") else { continue }
            let head = String(line[..<colon]).uppercased(), value = String(line[line.index(after: colon)...])
            let name = head.split(separator: ";").first.map(String.init) ?? head
            let label: String = head.contains("HOME") ? CNLabelHome : head.contains("WORK") ? CNLabelWork : head.contains("CELL") || head.contains("MOBILE") ? CNLabelPhoneNumberMobile : CNLabelOther
            switch name {
            case "BEGIN": cur = CNMutableContact()
            case "END": if let c = cur { result.append(c.copy() as! CNContact) }; cur = nil
            case "N":
                let p = value.components(separatedBy: ";")
                cur?.familyName = p.count > 0 ? p[0] : ""; cur?.givenName = p.count > 1 ? p[1] : ""; cur?.middleName = p.count > 2 ? p[2] : ""
            case "NICKNAME": cur?.nickname = value
            case "ORG": cur?.organizationName = value.components(separatedBy: ";").first ?? value
            case "TITLE": cur?.jobTitle = value
            case "TEL": cur?.phoneNumbers.append(CNLabeledValue(label: label, value: CNPhoneNumber(stringValue: value)))
            case "EMAIL": cur?.emailAddresses.append(CNLabeledValue(label: label, value: value as NSString))
            case "NOTE": cur?.note = value
            default: break
            }
        }
        return result
    }
}

// MARK: - Limited access selection (iOS 18)

@MainActor final class _CNSelection: UITableViewController {
    let all: [_CNData]
    var selected: Set<String>
    let done: (Set<String>) -> Void
    init(all: [_CNData], selected: Set<String>, done: @escaping (Set<String>) -> Void) {
        self.all = all.sorted { _CNSort.key($0, .familyName) < _CNSort.key($1, .familyName) }; self.selected = selected; self.done = done
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }
    static func present(all: [_CNData], selected: Set<String>, done: @escaping (Set<String>) -> Void) {
        guard let top = _Privacy.topController() else { done(selected); return }
        let nav = UINavigationController(rootViewController: _CNSelection(all: all, selected: selected, done: done))
        nav.isModalInPresentation = true
        top.present(nav, animated: true, completion: nil)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Contacts"
        navigationItem.leftBarButtonItem = _Privacy.barButton("Cancel", id: "contacts-select-cancel", self, #selector(isimCNCancel))
        navigationItem.rightBarButtonItem = _Privacy.barButton("Continue", bold: true, id: "contacts-select-done", self, #selector(isimCNDone))
    }
    @objc func isimCNCancel() { let d = done; _Privacy.dismiss(self) { d([]) } }
    @objc func isimCNDone() { let d = done, s = selected; _Privacy.dismiss(self) { d(s) } }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { all.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "Share contacts with “\(_Privacy.appName)”" }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = UITableViewCell(style: .default, reuseIdentifier: nil)
        let d = all[indexPath.row]
        c.textLabel?.text = CNContactFormatter.string(from: CNContact(d, keys: nil), style: .fullName) ?? "No Name"
        c.accessoryType = selected.contains(d.id) ? .checkmark : .none
        return c
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let id = all[indexPath.row].id
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        tableView.reloadData()
    }
}
