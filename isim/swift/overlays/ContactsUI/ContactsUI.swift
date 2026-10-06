// isim ContactsUI (self-authored, iOS API names): the contact picker (a sectioned list of the device address book;
// like iOS it runs outside the app's Contacts permission) and CNContactViewController (a contact card, and a basic
// new-contact form).
@_spi(isim) import Contacts
import UIKit

open class CNContactProperty: NSObject, NSCopying, @unchecked Sendable {
    public let contact: CNContact
    public let key: String
    public let value: Any?
    public let identifier: String?
    public let label: String?
    init(contact: CNContact, key: String, value: Any?, identifier: String?, label: String?) {
        self.contact = contact; self.key = key; self.value = value; self.identifier = identifier; self.label = label
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
}

@objc public protocol CNContactPickerDelegate: NSObjectProtocol {
    @objc optional func contactPickerDidCancel(_ picker: CNContactPickerViewController)
    @objc(contactPicker:didSelectContact:) optional func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact)
    @objc(contactPicker:didSelectContactProperty:) optional func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty)
    @objc(contactPicker:didSelectContacts:) optional func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact])
    @objc(contactPicker:didSelectContactProperties:) optional func contactPicker(_ picker: CNContactPickerViewController, didSelectContactProperties contactProperties: [CNContactProperty])
}

open class CNContactPickerViewController: UIViewController {
    open weak var delegate: CNContactPickerDelegate?
    open var displayedPropertyKeys: [String]?
    open var predicateForEnablingContact: NSPredicate?
    open var predicateForSelectionOfContact: NSPredicate?
    open var predicateForSelectionOfProperty: NSPredicate?
    let nav = UINavigationController()

    public override init(nibName: String?, bundle: Bundle?) { super.init(nibName: nil, bundle: nil) }
    public convenience init() { self.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let multi = delegate?.responds(to: #selector(CNContactPickerDelegate.contactPicker(_:didSelect:) as ((CNContactPickerDelegate) -> ((CNContactPickerViewController, [CNContact]) -> Void)?))) == true
        nav.viewControllers = [_CNPickerList(picker: self, multiple: multi)]
        addChild(nav)
        nav.view.frame = view.bounds
        nav.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(nav.view)
        nav.didMove(toParent: self)
    }
    open override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); nav.view.frame = view.bounds }

    var wantsProperty: Bool {
        delegate?.responds(to: #selector(CNContactPickerDelegate.contactPicker(_:didSelect:) as ((CNContactPickerDelegate) -> ((CNContactPickerViewController, CNContactProperty) -> Void)?))) == true
    }
    func finish(_ body: @escaping () -> Void) {
        if let p = presentingViewController { p.dismiss(animated: true, completion: body) } else { body() }
    }
    func cancel() { finish { self.delegate?.contactPickerDidCancel?(self) } }
    func picked(_ c: CNContact) {
        NSLog("isim ContactsUI: picked %@", CNContactStore._isimFullName(c))
        finish { self.delegate?.contactPicker?(self, didSelect: c) }
    }
    func picked(_ cs: [CNContact]) { finish { self.delegate?.contactPicker?(self, didSelect: cs) } }
    func picked(_ p: CNContactProperty) {
        NSLog("isim ContactsUI: picked %@ of %@", p.key, CNContactStore._isimFullName(p.contact))
        finish { self.delegate?.contactPicker?(self, didSelect: p) }
    }
}

final class _CNPickerList: UITableViewController {
    weak var picker: CNContactPickerViewController?
    let multiple: Bool
    var sections: [(String, [CNContact])] = []
    var chosen: Set<String> = []
    init(picker: CNContactPickerViewController, multiple: Bool) {
        self.picker = picker; self.multiple = multiple
        super.init(style: .plain)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Contacts"
        navigationItem.leftBarButtonItem = _CNUI.barButton("Cancel", id: "contacts-picker-cancel", self, #selector(isimCNUICancel))
        if multiple { navigationItem.rightBarButtonItem = _CNUI.barButton("Done", bold: true, id: "contacts-picker-done", self, #selector(isimCNUIDone)) }
        var groups: [String: [CNContact]] = [:]
        for c in CNContactStore._isimAllContacts() {
            let k = CNContactStore._isimSortKey(c)
            let letter = k.first.map { $0.isLetter ? String($0).uppercased() : "#" } ?? "#"
            groups[letter, default: []].append(c)
        }
        sections = groups.keys.sorted().map { ($0, groups[$0]!) }
    }
    @objc func isimCNUICancel() { picker?.cancel() }
    @objc func isimCNUIDone() {
        let all = sections.flatMap(\.1).filter { chosen.contains($0.identifier) }
        picker?.picked(all)
    }
    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].1.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].0 }
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? { sections.map(\.0) }
    func contact(_ ip: IndexPath) -> CNContact { sections[ip.section].1[ip.row] }
    func enabled(_ c: CNContact) -> Bool { picker?.predicateForEnablingContact?.evaluate(with: c) ?? true }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = contact(indexPath)
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = CNContactStore._isimFullName(c)
        if !enabled(c) { cell.textLabel?.textColor = .secondaryLabel }
        if multiple { cell.accessoryType = chosen.contains(c.identifier) ? .checkmark : .none }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let c = contact(indexPath)
        guard enabled(c), let picker else { return }
        if multiple {
            if chosen.contains(c.identifier) { chosen.remove(c.identifier) } else { chosen.insert(c.identifier) }
            tableView.reloadData(); return
        }
        let selectsContact = picker.predicateForSelectionOfContact?.evaluate(with: c) ?? !picker.wantsProperty
        if selectsContact { picker.picked(c); return }
        navigationController?.pushViewController(_CNCard(contact: c, picker: picker), animated: true)
    }
}

enum _CNUI {
    @MainActor static func barButton(_ title: String, bold: Bool = false, id: String? = nil, _ target: Any?, _ action: Selector) -> UIBarButtonItem {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = bold ? .systemFont(ofSize: 17, weight: .semibold) : .systemFont(ofSize: 17)
        b.addTarget(target, action: action, for: .touchUpInside)
        b.accessibilityIdentifier = id
        b.sizeToFit()
        return UIBarButtonItem(customView: b)
    }
    static func rows(_ c: CNContact) -> [(key: String, label: String, value: String, id: String?, raw: Any)] {
        var r: [(String, String, String, String?, Any)] = []
        for p in c.phoneNumbers { r.append((CNContactPhoneNumbersKey, p.label.map { CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: $0) } ?? "phone", p.value.stringValue, p.identifier, p.value)) }
        for e in c.emailAddresses { r.append((CNContactEmailAddressesKey, e.label.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) } ?? "email", e.value as String, e.identifier, e.value)) }
        for a in c.postalAddresses {
            r.append((CNContactPostalAddressesKey, a.label.map { CNLabeledValue<CNPostalAddress>.localizedString(forLabel: $0) } ?? "address",
                      CNPostalAddressFormatter.string(from: a.value, style: .mailingAddress), a.identifier, a.value))
        }
        for u in c.urlAddresses { r.append((CNContactUrlAddressesKey, u.label.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) } ?? "url", u.value as String, u.identifier, u.value)) }
        if let b = c.birthday, let date = Calendar(identifier: .gregorian).date(from: b) {
            let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .none
            r.append((CNContactBirthdayKey, "birthday", f.string(from: date), nil, b))
        }
        if !c.note.isEmpty { r.append((CNContactNoteKey, "notes", c.note, nil, c.note)) }
        return r
    }
}

/// a contact card (used by CNContactViewController and by the picker's property selection)
final class _CNCard: UITableViewController {
    let contact: CNContact
    weak var picker: CNContactPickerViewController?
    lazy var rows = _CNUI.rows(contact)
    init(contact: CNContact, picker: CNContactPickerViewController?) {
        self.contact = contact; self.picker = picker
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 1 : rows.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = CNContactStore._isimFullName(contact)
            cell.textLabel?.font = .systemFont(ofSize: 28, weight: .semibold)
            cell.textLabel?.textAlignment = .center
            let org = [contact.jobTitle, contact.organizationName].filter { !$0.isEmpty }.joined(separator: ", ")
            cell.detailTextLabel?.text = org.isEmpty ? nil : org
            cell.detailTextLabel?.textAlignment = .center
            cell.selectionStyle = .none
            return cell
        }
        let r = rows[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = r.label
        cell.textLabel?.font = .systemFont(ofSize: 13)
        cell.detailTextLabel?.text = r.value
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.textColor = r.key == CNContactPhoneNumbersKey || r.key == CNContactEmailAddressesKey ? .systemBlue : .label
        cell.detailTextLabel?.font = .systemFont(ofSize: 17)
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1, let picker else { return }
        let r = rows[indexPath.row]
        picker.picked(CNContactProperty(contact: contact, key: r.key, value: r.raw, identifier: r.id, label: nil))
    }
}

// MARK: - CNContactViewController

@objc public protocol CNContactViewControllerDelegate: NSObjectProtocol {
    @objc optional func contactViewController(_ viewController: CNContactViewController, shouldPerformDefaultActionFor property: CNContactProperty) -> Bool
    @objc optional func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?)
}

open class CNContactViewController: UIViewController, UITextFieldDelegate {
    open weak var delegate: CNContactViewControllerDelegate?
    open var contactStore: CNContactStore?
    open var allowsEditing = true
    open var allowsActions = true
    open var shouldShowLinkedContacts = false
    open var displayedPropertyKeys: [String]?
    open var message: String?
    open var alternateName: String?
    open var parentGroup: CNGroup?
    open var parentContainer: CNContainer?
    public private(set) var contact: CNContact
    let isNew: Bool
    var fields: [String: UITextField] = [:]

    open class func descriptorForRequiredKeys() -> CNKeyDescriptor { CNContactVCardSerialization.descriptorForRequiredKeys() }

    public init(for contact: CNContact) { self.contact = contact; isNew = false; super.init(nibName: nil, bundle: nil) }
    public init(forUnknownContact contact: CNContact) { self.contact = contact; isNew = false; super.init(nibName: nil, bundle: nil) }
    public init(forNewContact contact: CNContact?) { self.contact = contact ?? CNMutableContact(); isNew = true; super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { contact = CNContact(); isNew = false; super.init(coder: coder) }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        if isNew { buildForm() } else { buildCard() }
    }
    func buildCard() {
        let card = _CNCard(contact: contact, picker: nil)
        addChild(card)
        card.view.frame = view.bounds
        card.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(card.view)
        card.didMove(toParent: self)
    }
    func buildForm() {
        title = "New Contact"
        navigationItem.leftBarButtonItem = _CNUI.barButton("Cancel", id: "contact-cancel", self, #selector(isimCNUIFormCancel))
        navigationItem.rightBarButtonItem = _CNUI.barButton("Done", bold: true, id: "contact-done", self, #selector(isimCNUIFormDone))
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        let c = contact
        let initial = [("givenName", "First name", c.givenName), ("familyName", "Last name", c.familyName), ("organizationName", "Company", c.organizationName),
                       ("phone", "Phone", c.phoneNumbers.first?.value.stringValue ?? ""), ("email", "Email", (c.emailAddresses.first?.value as String?) ?? "")]
        for (key, placeholder, value) in initial {
            let f = UITextField()
            f.placeholder = placeholder
            f.text = value
            f.borderStyle = .roundedRect
            f.accessibilityIdentifier = "contact-field-\(key)"
            f.delegate = self
            f.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(f)
            fields[key] = f
        }
    }
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool { textField.resignFirstResponder(); return true }
    @objc func isimCNUIFormCancel() { delegate?.contactViewController?(self, didCompleteWith: nil) }
    @objc func isimCNUIFormDone() {
        for f in fields.values { _ = f.resignFirstResponder() }
        let m = contact.mutableCopy() as! CNMutableContact
        m.givenName = fields["givenName"]?.text ?? ""
        m.familyName = fields["familyName"]?.text ?? ""
        m.organizationName = fields["organizationName"]?.text ?? ""
        if let p = fields["phone"]?.text, !p.isEmpty { m.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: p))] }
        if let e = fields["email"]?.text, !e.isEmpty { m.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: e as NSString)] }
        // like iOS, the contact view controller saves the new contact itself (it runs outside the app's permission)
        CNContactStore._isimSave(m)
        contact = m.copy() as! CNContact
        NSLog("isim ContactsUI: saved new contact %@", CNContactStore._isimFullName(m))
        delegate?.contactViewController?(self, didCompleteWith: contact)
    }
}
