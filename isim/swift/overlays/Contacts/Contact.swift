// isim Contacts (self-authored, iOS API names): CNContact and its values.
import Foundation

@objc public protocol CNKeyDescriptor: NSObjectProtocol {}
extension NSString: CNKeyDescriptor {}
/// key descriptors returned by formatters / ContactsUI (a list of contact keys)
final class _CNKeys: NSObject, CNKeyDescriptor {
    let keys: [String]
    init(_ keys: [String]) { self.keys = keys }
}
func _cnKeyStrings(_ d: [CNKeyDescriptor]) -> Set<String> {
    var s = Set<String>()
    for k in d {
        if let k = k as? _CNKeys { s.formUnion(k.keys) }
        else if let k = k as? NSString { s.insert(k as String) }
    }
    return s
}

public let CNContactIdentifierKey = "identifier"
public let CNContactTypeKey = "contactType"
public let CNContactNamePrefixKey = "namePrefix"
public let CNContactGivenNameKey = "givenName"
public let CNContactMiddleNameKey = "middleName"
public let CNContactFamilyNameKey = "familyName"
public let CNContactPreviousFamilyNameKey = "previousFamilyName"
public let CNContactNameSuffixKey = "nameSuffix"
public let CNContactNicknameKey = "nickname"
public let CNContactPhoneticGivenNameKey = "phoneticGivenName"
public let CNContactPhoneticMiddleNameKey = "phoneticMiddleName"
public let CNContactPhoneticFamilyNameKey = "phoneticFamilyName"
public let CNContactOrganizationNameKey = "organizationName"
public let CNContactDepartmentNameKey = "departmentName"
public let CNContactJobTitleKey = "jobTitle"
public let CNContactBirthdayKey = "birthday"
public let CNContactNonGregorianBirthdayKey = "nonGregorianBirthday"
public let CNContactNoteKey = "note"
public let CNContactImageDataKey = "imageData"
public let CNContactThumbnailImageDataKey = "thumbnailImageData"
public let CNContactImageDataAvailableKey = "imageDataAvailable"
public let CNContactPhoneNumbersKey = "phoneNumbers"
public let CNContactEmailAddressesKey = "emailAddresses"
public let CNContactPostalAddressesKey = "postalAddresses"
public let CNContactDatesKey = "dates"
public let CNContactUrlAddressesKey = "urlAddresses"
public let CNContactRelationsKey = "contactRelations"
public let CNContactSocialProfilesKey = "socialProfiles"
public let CNContactInstantMessageAddressesKey = "instantMessageAddresses"

public let CNLabelHome = "_$!<Home>!$_"
public let CNLabelWork = "_$!<Work>!$_"
public let CNLabelSchool = "_$!<School>!$_"
public let CNLabelOther = "_$!<Other>!$_"
public let CNLabelEmailiCloud = "iCloud"
public let CNLabelURLAddressHomePage = "_$!<HomePage>!$_"
public let CNLabelDateAnniversary = "_$!<Anniversary>!$_"
public let CNLabelPhoneNumberiPhone = "iPhone"
public let CNLabelPhoneNumberAppleWatch = "_$!<AppleWatch>!$_"
public let CNLabelPhoneNumberMobile = "_$!<Mobile>!$_"
public let CNLabelPhoneNumberMain = "_$!<Main>!$_"
public let CNLabelPhoneNumberHomeFax = "_$!<HomeFAX>!$_"
public let CNLabelPhoneNumberWorkFax = "_$!<WorkFAX>!$_"
public let CNLabelPhoneNumberOtherFax = "_$!<OtherFAX>!$_"
public let CNLabelPhoneNumberPager = "_$!<Pager>!$_"

@objc public enum CNContactType: Int, Sendable { case person = 0, organization }
@objc public enum CNContactSortOrder: Int, Sendable { case none = 0, userDefault, givenName, familyName }

public let CNErrorDomain = "CNErrorDomain"
public struct CNError: CustomNSError, LocalizedError, Sendable {
    public enum Code: Int, Sendable {
        case communicationError = 1, dataAccessAuthorizationDenied = 2, authorizationDenied = 100, noAccessableWritableContainers = 101
        case unauthorizedKeys = 102, featureDisabledByUser = 103, featureNotAvailable = 104, recordDoesNotExist = 200
        case insertedRecordAlreadyExists = 201, containmentCycle = 202, containmentScope = 203, parentRecordDoesNotExist = 204
        case recordIdentifierInvalid = 205, recordNotWritable = 206, parentContainerNotWritable = 207
        case validationMultipleErrors = 300, validationTypeMismatch = 301, validationConfigurationError = 302
        case predicateInvalid = 400, policyViolation = 500, vCardMalformed = 700, vCardSummarizationError = 701
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { CNErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: errorDescription ?? ""] }
    public var errorDescription: String? {
        switch code {
        case .authorizationDenied: return "Access Denied"
        case .recordDoesNotExist: return "Updated Record Does Not Exist"
        default: return "Contacts error \(code.rawValue)"
        }
    }
    public static var authorizationDenied: Code { .authorizationDenied }
    public static var recordDoesNotExist: Code { .recordDoesNotExist }
}

// MARK: - Values

open class CNPhoneNumber: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    public let stringValue: String
    public init(stringValue string: String) { stringValue = string }
    public convenience init?(stringValue: String?) { guard let stringValue else { return nil }; self.init(stringValue: stringValue) }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) { coder.encode(stringValue as NSString, forKey: "stringValue") }
    public required init?(coder: NSCoder) { stringValue = (coder.decodeObject(forKey: "stringValue") as? String) ?? "" }
    var digits: String { String(stringValue.filter(\.isNumber)) }
    open override func isEqual(_ object: Any?) -> Bool { (object as? CNPhoneNumber)?.stringValue == stringValue }
    open override var hash: Int { stringValue.hashValue }
    open override var description: String { "<CNPhoneNumber: stringValue=\(stringValue)>" }
}

open class CNPostalAddress: NSObject, NSCopying, NSMutableCopying, NSSecureCoding, @unchecked Sendable {
    var d = _CNAddress()
    open var street: String { d.street }
    open var subLocality: String { d.subLocality }
    open var city: String { d.city }
    open var subAdministrativeArea: String { d.subAdministrativeArea }
    open var state: String { d.state }
    open var postalCode: String { d.postalCode }
    open var country: String { d.country }
    open var isoCountryCode: String { d.isoCountryCode }
    public override init() { super.init() }
    init(_ d: _CNAddress) { self.d = d }
    public func copy(with zone: OpaquePointer? = nil) -> Any { CNPostalAddress(d) }
    public func mutableCopy(with zone: OpaquePointer? = nil) -> Any { let m = CNMutablePostalAddress(); m.d = d; return m }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {}
    public required init?(coder: NSCoder) { super.init() }
    open override func isEqual(_ object: Any?) -> Bool { (object as? CNPostalAddress)?.d == d }
    open override var hash: Int { d.street.hashValue ^ d.city.hashValue }
    open class func localizedString(forKey key: String) -> String {
        ["street": "Street", "city": "City", "state": "State", "postalCode": "ZIP", "country": "Country"][key] ?? key
    }
}
open class CNMutablePostalAddress: CNPostalAddress, @unchecked Sendable {
    open override var street: String { get { d.street } set { d.street = newValue } }
    open override var subLocality: String { get { d.subLocality } set { d.subLocality = newValue } }
    open override var city: String { get { d.city } set { d.city = newValue } }
    open override var subAdministrativeArea: String { get { d.subAdministrativeArea } set { d.subAdministrativeArea = newValue } }
    open override var state: String { get { d.state } set { d.state = newValue } }
    open override var postalCode: String { get { d.postalCode } set { d.postalCode = newValue } }
    open override var country: String { get { d.country } set { d.country = newValue } }
    open override var isoCountryCode: String { get { d.isoCountryCode } set { d.isoCountryCode = newValue } }
}

public enum CNPostalAddressFormatterStyle: Int, Sendable { case mailingAddress = 0 }
open class CNPostalAddressFormatter: Formatter, @unchecked Sendable {
    open var style: CNPostalAddressFormatterStyle = .mailingAddress
    open class func string(from postalAddress: CNPostalAddress, style: CNPostalAddressFormatterStyle) -> String {
        let line2 = [postalAddress.city, [postalAddress.state, postalAddress.postalCode].filter { !$0.isEmpty }.joined(separator: " ")]
            .filter { !$0.isEmpty }.joined(separator: " ")
        return [postalAddress.street, line2, postalAddress.country].filter { !$0.isEmpty }.joined(separator: "\n")
    }
    open func string(from postalAddress: CNPostalAddress) -> String { Self.string(from: postalAddress, style: style) }
}

open class CNSocialProfile: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    public let urlString: String, username: String, userIdentifier: String, service: String
    public init(urlString: String?, username: String?, userIdentifier: String?, service: String?) {
        self.urlString = urlString ?? ""; self.username = username ?? ""; self.userIdentifier = userIdentifier ?? ""; self.service = service ?? ""
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {}
    public required init?(coder: NSCoder) { urlString = ""; username = ""; userIdentifier = ""; service = "" }
}
open class CNInstantMessageAddress: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    public let username: String, service: String
    public init(username: String, service: String) { self.username = username; self.service = service }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {}
    public required init?(coder: NSCoder) { username = ""; service = "" }
}
open class CNContactRelation: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    public let name: String
    public init(name: String) { self.name = name }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {}
    public required init?(coder: NSCoder) { name = "" }
}

open class CNLabeledValue<ValueType: NSCopying & NSSecureCoding>: NSObject, NSCopying, @unchecked Sendable {
    public let identifier: String
    public let label: String?
    public let value: ValueType
    public required init(label: String?, value: ValueType) { identifier = UUID().uuidString; self.label = label; self.value = value }
    init(id: String, label: String?, value: ValueType) { identifier = id; self.label = label; self.value = value }
    open func settingLabel(_ label: String?) -> Self { Self.init(label: label, value: value) }
    open func settingValue(_ value: ValueType) -> Self { Self.init(label: label, value: value) }
    open func settingLabel(_ label: String?, value: ValueType) -> Self { Self.init(label: label, value: value) }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open class func localizedString(forLabel label: String) -> String {
        let names = [CNLabelHome: "home", CNLabelWork: "work", CNLabelSchool: "school", CNLabelOther: "other", CNLabelPhoneNumberMobile: "mobile",
                     CNLabelPhoneNumberMain: "main", CNLabelPhoneNumberHomeFax: "home fax", CNLabelPhoneNumberWorkFax: "work fax",
                     CNLabelPhoneNumberOtherFax: "other fax", CNLabelPhoneNumberPager: "pager", CNLabelURLAddressHomePage: "homepage",
                     CNLabelDateAnniversary: "anniversary", CNLabelPhoneNumberAppleWatch: "Apple Watch"]
        if let n = names[label] { return n }
        if label.hasPrefix("_$!<") && label.hasSuffix(">!$_") { return String(label.dropFirst(4).dropLast(4)).lowercased() }
        return label
    }
}

// MARK: - Contact data

struct _CNAddress: Codable, Equatable {
    var street = "", subLocality = "", city = "", subAdministrativeArea = "", state = "", postalCode = "", country = "", isoCountryCode = ""
}
struct _CNLabeled<T: Codable & Equatable>: Codable, Equatable { var id: String; var label: String?; var value: T }
struct _CNDay: Codable, Equatable { var year: Int?; var month: Int?; var day: Int? }

struct _CNData: Codable, Equatable {
    var id = UUID().uuidString + ":ABPerson"
    var type = 0
    var namePrefix = "", givenName = "", middleName = "", familyName = "", previousFamilyName = "", nameSuffix = "", nickname = ""
    var phoneticGivenName = "", phoneticMiddleName = "", phoneticFamilyName = ""
    var organizationName = "", departmentName = "", jobTitle = ""
    var birthday: _CNDay?
    var note = ""
    var imageData: Data?
    var phones: [_CNLabeled<String>] = []
    var emails: [_CNLabeled<String>] = []
    var urls: [_CNLabeled<String>] = []
    var addresses: [_CNLabeled<_CNAddress>] = []
    var dates: [_CNLabeled<_CNDay>] = []
    var relations: [_CNLabeled<String>] = []
    var container = "isim-local"
    var groups: [String] = []
    var modified: Double = 0
}

extension _CNDay {
    init(_ c: DateComponents) { year = c.year; month = c.month; day = c.day }
    var components: DateComponents { var c = DateComponents(); c.calendar = Calendar(identifier: .gregorian); c.year = year; c.month = month; c.day = day; return c }
}

open class CNContact: NSObject, NSCopying, NSMutableCopying, NSSecureCoding, @unchecked Sendable {
    var d: _CNData
    /// keys fetched (nil: all, e.g. new contacts)
    var fetched: Set<String>?

    public override init() { d = _CNData(); fetched = nil; super.init() }
    init(_ d: _CNData, keys: Set<String>?) { self.d = d; fetched = keys }
    public func copy(with zone: OpaquePointer? = nil) -> Any { CNContact(d, keys: fetched) }
    public func mutableCopy(with zone: OpaquePointer? = nil) -> Any { CNMutableContact(d, keys: fetched) }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {}
    public required init?(coder: NSCoder) { d = _CNData(); super.init() }

    /// like iOS: reading a property that was not fetched raises CNPropertyNotFetchedException
    func need(_ key: String) {
        guard let f = fetched, !f.contains(key) else { return }
        NSLog("*** Terminating app due to uncaught exception 'CNPropertyNotFetchedException', reason: 'A property was not requested when contact was fetched.' (key %@)", key)
        fatalError("CNPropertyNotFetchedException: \(key) was not requested when the contact was fetched")
    }
    open func isKeyAvailable(_ key: String) -> Bool { fetched?.contains(key) ?? true }
    open func areKeysAvailable(_ keyDescriptors: [CNKeyDescriptor]) -> Bool { fetched == nil || _cnKeyStrings(keyDescriptors).isSubset(of: fetched!) }

    open var identifier: String { d.id }
    open var contactType: CNContactType { need(CNContactTypeKey); return CNContactType(rawValue: d.type) ?? .person }
    open var namePrefix: String { need(CNContactNamePrefixKey); return d.namePrefix }
    open var givenName: String { need(CNContactGivenNameKey); return d.givenName }
    open var middleName: String { need(CNContactMiddleNameKey); return d.middleName }
    open var familyName: String { need(CNContactFamilyNameKey); return d.familyName }
    open var previousFamilyName: String { need(CNContactPreviousFamilyNameKey); return d.previousFamilyName }
    open var nameSuffix: String { need(CNContactNameSuffixKey); return d.nameSuffix }
    open var nickname: String { need(CNContactNicknameKey); return d.nickname }
    open var phoneticGivenName: String { need(CNContactPhoneticGivenNameKey); return d.phoneticGivenName }
    open var phoneticMiddleName: String { need(CNContactPhoneticMiddleNameKey); return d.phoneticMiddleName }
    open var phoneticFamilyName: String { need(CNContactPhoneticFamilyNameKey); return d.phoneticFamilyName }
    open var organizationName: String { need(CNContactOrganizationNameKey); return d.organizationName }
    open var departmentName: String { need(CNContactDepartmentNameKey); return d.departmentName }
    open var jobTitle: String { need(CNContactJobTitleKey); return d.jobTitle }
    open var birthday: DateComponents? { need(CNContactBirthdayKey); return d.birthday?.components }
    open var nonGregorianBirthday: DateComponents? { nil }
    open var note: String { need(CNContactNoteKey); return d.note }
    open var imageData: Data? { need(CNContactImageDataKey); return d.imageData }
    open var thumbnailImageData: Data? { need(CNContactThumbnailImageDataKey); return d.imageData }
    open var imageDataAvailable: Bool { need(CNContactImageDataAvailableKey); return d.imageData != nil }
    open var phoneNumbers: [CNLabeledValue<CNPhoneNumber>] {
        need(CNContactPhoneNumbersKey); return d.phones.map { CNLabeledValue(id: $0.id, label: $0.label, value: CNPhoneNumber(stringValue: $0.value)) }
    }
    open var emailAddresses: [CNLabeledValue<NSString>] {
        need(CNContactEmailAddressesKey); return d.emails.map { CNLabeledValue(id: $0.id, label: $0.label, value: $0.value as NSString) }
    }
    open var urlAddresses: [CNLabeledValue<NSString>] {
        need(CNContactUrlAddressesKey); return d.urls.map { CNLabeledValue(id: $0.id, label: $0.label, value: $0.value as NSString) }
    }
    open var postalAddresses: [CNLabeledValue<CNPostalAddress>] {
        need(CNContactPostalAddressesKey); return d.addresses.map { CNLabeledValue(id: $0.id, label: $0.label, value: CNPostalAddress($0.value)) }
    }
    open var contactRelations: [CNLabeledValue<CNContactRelation>] {
        need(CNContactRelationsKey); return d.relations.map { CNLabeledValue(id: $0.id, label: $0.label, value: CNContactRelation(name: $0.value)) }
    }
    open var socialProfiles: [CNLabeledValue<CNSocialProfile>] { need(CNContactSocialProfilesKey); return [] }
    open var instantMessageAddresses: [CNLabeledValue<CNInstantMessageAddress>] { need(CNContactInstantMessageAddressesKey); return [] }

    open func isUnifiedWithContact(withIdentifier contactIdentifier: String) -> Bool { contactIdentifier == d.id }
    open override func isEqual(_ object: Any?) -> Bool { (object as? CNContact)?.d == d }
    open override var hash: Int { d.id.hashValue }
    open override var description: String { "<CNContact: identifier=\(d.id), givenName=\(d.givenName), familyName=\(d.familyName)>" }

    open class func localizedString(forKey key: String) -> String {
        ["givenName": "First name", "familyName": "Last name", "middleName": "Middle name", "organizationName": "Company", "jobTitle": "Job title",
         "phoneNumbers": "Phone", "emailAddresses": "Email", "postalAddresses": "Address", "birthday": "Birthday", "note": "Notes",
         "nickname": "Nickname", "urlAddresses": "URL", "departmentName": "Department"][key] ?? key
    }
    open class func comparator(forNameSortOrder sortOrder: CNContactSortOrder) -> (Any, Any) -> ComparisonResult {
        { a, b in
            guard let a = a as? CNContact, let b = b as? CNContact else { return .orderedSame }
            let ka = _CNSort.key(a.d, sortOrder), kb = _CNSort.key(b.d, sortOrder)
            return ka < kb ? .orderedAscending : ka > kb ? .orderedDescending : .orderedSame
        }
    }
    open class func descriptorForAllComparatorKeys() -> CNKeyDescriptor { _CNKeys([CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey]) }

    // MARK: predicates (evaluated against the full stored contact)
    open class func predicateForContacts(matchingName name: String) -> NSPredicate {
        let words = name.lowercased().split(separator: " ").map(String.init)
        return NSPredicate { obj, _ in
            guard let c = obj as? CNContact else { return false }
            let names = [c.d.givenName, c.d.middleName, c.d.familyName, c.d.nickname, c.d.organizationName].map { $0.lowercased() }
            return !words.isEmpty && words.allSatisfy { w in names.contains { $0.hasPrefix(w) } }
        }
    }
    open class func predicateForContacts(withIdentifiers identifiers: [String]) -> NSPredicate {
        let ids = Set(identifiers)
        return NSPredicate { obj, _ in ids.contains((obj as? CNContact)?.d.id ?? "") }
    }
    open class func predicateForContacts(matching phoneNumber: CNPhoneNumber) -> NSPredicate {
        let want = phoneNumber.digits
        return NSPredicate { obj, _ in
            (obj as? CNContact)?.d.phones.contains { CNPhoneNumber(stringValue: $0.value).digits.hasSuffix(want) || want.hasSuffix(CNPhoneNumber(stringValue: $0.value).digits) } ?? false
        }
    }
    open class func predicateForContacts(matchingEmailAddress emailAddress: String) -> NSPredicate {
        let want = emailAddress.lowercased()
        return NSPredicate { obj, _ in (obj as? CNContact)?.d.emails.contains { $0.value.lowercased() == want } ?? false }
    }
    open class func predicateForContactsInGroup(withIdentifier groupIdentifier: String) -> NSPredicate {
        NSPredicate { obj, _ in (obj as? CNContact)?.d.groups.contains(groupIdentifier) ?? false }
    }
    open class func predicateForContactsInContainer(withIdentifier containerIdentifier: String) -> NSPredicate {
        NSPredicate { obj, _ in (obj as? CNContact)?.d.container == containerIdentifier }
    }
}

enum _CNSort {
    static func key(_ d: _CNData, _ order: CNContactSortOrder) -> String {
        let first = d.givenName.isEmpty ? d.organizationName : d.givenName
        let last = d.familyName.isEmpty ? (d.givenName.isEmpty ? d.organizationName : d.givenName) : d.familyName
        switch order {
        case .givenName: return (first + " " + d.familyName).lowercased()
        default: return (last + " " + d.givenName).lowercased()
        }
    }
}

open class CNMutableContact: CNContact, @unchecked Sendable {
    open override var contactType: CNContactType { get { super.contactType } set { d.type = newValue.rawValue } }
    open override var namePrefix: String { get { super.namePrefix } set { d.namePrefix = newValue } }
    open override var givenName: String { get { super.givenName } set { d.givenName = newValue } }
    open override var middleName: String { get { super.middleName } set { d.middleName = newValue } }
    open override var familyName: String { get { super.familyName } set { d.familyName = newValue } }
    open override var previousFamilyName: String { get { super.previousFamilyName } set { d.previousFamilyName = newValue } }
    open override var nameSuffix: String { get { super.nameSuffix } set { d.nameSuffix = newValue } }
    open override var nickname: String { get { super.nickname } set { d.nickname = newValue } }
    open override var phoneticGivenName: String { get { super.phoneticGivenName } set { d.phoneticGivenName = newValue } }
    open override var phoneticMiddleName: String { get { super.phoneticMiddleName } set { d.phoneticMiddleName = newValue } }
    open override var phoneticFamilyName: String { get { super.phoneticFamilyName } set { d.phoneticFamilyName = newValue } }
    open override var organizationName: String { get { super.organizationName } set { d.organizationName = newValue } }
    open override var departmentName: String { get { super.departmentName } set { d.departmentName = newValue } }
    open override var jobTitle: String { get { super.jobTitle } set { d.jobTitle = newValue } }
    open override var birthday: DateComponents? { get { super.birthday } set { d.birthday = newValue.map(_CNDay.init) } }
    open override var note: String { get { super.note } set { d.note = newValue } }
    open override var imageData: Data? { get { super.imageData } set { d.imageData = newValue } }
    open override var phoneNumbers: [CNLabeledValue<CNPhoneNumber>] {
        get { super.phoneNumbers } set { d.phones = newValue.map { _CNLabeled(id: $0.identifier, label: $0.label, value: $0.value.stringValue) } }
    }
    open override var emailAddresses: [CNLabeledValue<NSString>] {
        get { super.emailAddresses } set { d.emails = newValue.map { _CNLabeled(id: $0.identifier, label: $0.label, value: $0.value as String) } }
    }
    open override var urlAddresses: [CNLabeledValue<NSString>] {
        get { super.urlAddresses } set { d.urls = newValue.map { _CNLabeled(id: $0.identifier, label: $0.label, value: $0.value as String) } }
    }
    open override var postalAddresses: [CNLabeledValue<CNPostalAddress>] {
        get { super.postalAddresses } set { d.addresses = newValue.map { _CNLabeled(id: $0.identifier, label: $0.label, value: $0.value.d) } }
    }
    open override var contactRelations: [CNLabeledValue<CNContactRelation>] {
        get { super.contactRelations } set { d.relations = newValue.map { _CNLabeled(id: $0.identifier, label: $0.label, value: $0.value.name) } }
    }
    public override init() { super.init() }
    override init(_ d: _CNData, keys: Set<String>?) { super.init(d, keys: keys) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
}

// MARK: - Formatter

@objc public enum CNContactFormatterStyle: Int, Sendable { case fullName = 0, phoneticFullName }
@objc public enum CNContactDisplayNameOrder: Int, Sendable { case userDefault = 0, givenNameFirst, familyNameFirst }
open class CNContactFormatter: Formatter, @unchecked Sendable {
    open var style: CNContactFormatterStyle = .fullName
    open class func descriptorForRequiredKeys(for style: CNContactFormatterStyle) -> CNKeyDescriptor {
        _CNKeys([CNContactNamePrefixKey, CNContactGivenNameKey, CNContactMiddleNameKey, CNContactFamilyNameKey, CNContactNameSuffixKey,
                 CNContactOrganizationNameKey, CNContactTypeKey, CNContactPhoneticGivenNameKey, CNContactPhoneticFamilyNameKey])
    }
    open class func string(from contact: CNContact, style: CNContactFormatterStyle) -> String? {
        let d = contact.d
        if style == .phoneticFullName { let s = [d.phoneticGivenName, d.phoneticFamilyName].filter { !$0.isEmpty }.joined(separator: " "); return s.isEmpty ? nil : s }
        let s = [d.namePrefix, d.givenName, d.middleName, d.familyName].filter { !$0.isEmpty }.joined(separator: " ") + (d.nameSuffix.isEmpty ? "" : " " + d.nameSuffix)
        if !s.trimmingCharacters(in: .whitespaces).isEmpty { return s }
        return d.organizationName.isEmpty ? nil : d.organizationName
    }
    open func string(from contact: CNContact) -> String? { Self.string(from: contact, style: style) }
    open class func nameOrder(for contact: CNContact) -> CNContactDisplayNameOrder { .givenNameFirst }
    open class func delimiter(for contact: CNContact) -> String { " " }
}
