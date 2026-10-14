// isim Contacts for Objective-C (sdk-src/Frameworks/Contacts): the classes carry Apple's Objective-C names and these
// members Apple's selectors. CNLabeledValue is a generic Swift class here, which Objective-C cannot see, so Contacts.m
// has Objective-C's CNLabeledValue and converts at the contact's labeled-value properties, through the _isim_ members
// below ([identifier, label or NSNull, value] triples).
import Foundation

func _cnTriples<V>(_ values: [CNLabeledValue<V>]) -> [[Any]] { values.map { [$0.identifier, ($0.label as Any?) ?? NSNull(), $0.value] } }
func _cnLabeled<V>(_ pairs: [[Any]], _ type: V.Type) -> [CNLabeledValue<V>] {
    pairs.compactMap { p in
        guard p.count == 2, let v = p[1] as? V else { return nil }
        return CNLabeledValue(label: p[0] as? String, value: v)
    }
}

extension CNContact {
    @objc(identifier) var _objc_identifier: String { identifier }
    @objc(contactType) var _objc_contactType: CNContactType { contactType }
    @objc(namePrefix) var _objc_namePrefix: String { namePrefix }
    @objc(givenName) var _objc_givenName: String { givenName }
    @objc(middleName) var _objc_middleName: String { middleName }
    @objc(familyName) var _objc_familyName: String { familyName }
    @objc(previousFamilyName) var _objc_previousFamilyName: String { previousFamilyName }
    @objc(nameSuffix) var _objc_nameSuffix: String { nameSuffix }
    @objc(nickname) var _objc_nickname: String { nickname }
    @objc(organizationName) var _objc_organizationName: String { organizationName }
    @objc(departmentName) var _objc_departmentName: String { departmentName }
    @objc(jobTitle) var _objc_jobTitle: String { jobTitle }
    @objc(birthday) var _objc_birthday: DateComponents? { birthday }
    @objc(note) var _objc_note: String { note }
    @objc(imageData) var _objc_imageData: Data? { imageData }
    @objc(thumbnailImageData) var _objc_thumbnailImageData: Data? { thumbnailImageData }
    @objc(imageDataAvailable) var _objc_imageDataAvailable: Bool { imageDataAvailable }
    @objc(_isim_phoneNumbers) var _isim_phoneNumbers: [[Any]] { _cnTriples(phoneNumbers) }
    @objc(_isim_emailAddresses) var _isim_emailAddresses: [[Any]] { _cnTriples(emailAddresses) }
    @objc(_isim_urlAddresses) var _isim_urlAddresses: [[Any]] { _cnTriples(urlAddresses) }
    @objc(_isim_postalAddresses) var _isim_postalAddresses: [[Any]] { _cnTriples(postalAddresses) }
    @objc(isKeyAvailable:) func _objc_isKeyAvailable(_ key: String) -> Bool { isKeyAvailable(key) }
    @objc(areKeysAvailable:) func _objc_areKeysAvailable(_ keys: [CNKeyDescriptor]) -> Bool { areKeysAvailable(keys) }
    @objc(isUnifiedWithContactWithIdentifier:) func _objc_isUnified(_ id: String) -> Bool { isUnifiedWithContact(withIdentifier: id) }
    @objc(localizedStringForKey:) class func _objc_localizedString(_ key: String) -> String { localizedString(forKey: key) }
    @objc(descriptorForAllComparatorKeys) class func _objc_descriptorForAllComparatorKeys() -> CNKeyDescriptor { descriptorForAllComparatorKeys() }
    @objc(predicateForContactsMatchingName:) class func _objc_matchingName(_ name: String) -> NSPredicate { predicateForContacts(matchingName: name) }
    @objc(predicateForContactsWithIdentifiers:) class func _objc_withIdentifiers(_ ids: [String]) -> NSPredicate {
        predicateForContacts(withIdentifiers: ids)
    }
    @objc(predicateForContactsMatchingPhoneNumber:) class func _objc_matchingPhone(_ n: CNPhoneNumber) -> NSPredicate { predicateForContacts(matching: n) }
    @objc(predicateForContactsMatchingEmailAddress:) class func _objc_matchingEmail(_ e: String) -> NSPredicate {
        predicateForContacts(matchingEmailAddress: e)
    }
}

extension CNMutableContact {
    @objc(setContactType:) func _objc_setContactType(_ v: CNContactType) { contactType = v }
    @objc(setNamePrefix:) func _objc_setNamePrefix(_ v: String) { namePrefix = v }
    @objc(setGivenName:) func _objc_setGivenName(_ v: String) { givenName = v }
    @objc(setMiddleName:) func _objc_setMiddleName(_ v: String) { middleName = v }
    @objc(setFamilyName:) func _objc_setFamilyName(_ v: String) { familyName = v }
    @objc(setPreviousFamilyName:) func _objc_setPreviousFamilyName(_ v: String) { previousFamilyName = v }
    @objc(setNameSuffix:) func _objc_setNameSuffix(_ v: String) { nameSuffix = v }
    @objc(setNickname:) func _objc_setNickname(_ v: String) { nickname = v }
    @objc(setOrganizationName:) func _objc_setOrganizationName(_ v: String) { organizationName = v }
    @objc(setDepartmentName:) func _objc_setDepartmentName(_ v: String) { departmentName = v }
    @objc(setJobTitle:) func _objc_setJobTitle(_ v: String) { jobTitle = v }
    @objc(setBirthday:) func _objc_setBirthday(_ v: DateComponents?) { birthday = v }
    @objc(setNote:) func _objc_setNote(_ v: String) { note = v }
    @objc(setImageData:) func _objc_setImageData(_ v: Data?) { imageData = v }
    @objc(_isim_setPhoneNumbers:) func _isim_setPhoneNumbers(_ v: [[Any]]) { phoneNumbers = _cnLabeled(v, CNPhoneNumber.self) }
    @objc(_isim_setEmailAddresses:) func _isim_setEmailAddresses(_ v: [[Any]]) { emailAddresses = _cnLabeled(v, NSString.self) }
    @objc(_isim_setUrlAddresses:) func _isim_setUrlAddresses(_ v: [[Any]]) { urlAddresses = _cnLabeled(v, NSString.self) }
    @objc(_isim_setPostalAddresses:) func _isim_setPostalAddresses(_ v: [[Any]]) { postalAddresses = _cnLabeled(v, CNPostalAddress.self) }
}

extension CNPhoneNumber {
    @objc(phoneNumberWithStringValue:) class func _objc_phoneNumber(_ s: String) -> CNPhoneNumber { CNPhoneNumber(stringValue: s) }
    @objc(initWithStringValue:) convenience init(_objcStringValue s: String) { self.init(stringValue: s) }
    @objc(stringValue) var _objc_stringValue: String { stringValue }
}

extension CNPostalAddress {
    @objc(street) var _objc_street: String { street }
    @objc(subLocality) var _objc_subLocality: String { subLocality }
    @objc(city) var _objc_city: String { city }
    @objc(subAdministrativeArea) var _objc_subAdministrativeArea: String { subAdministrativeArea }
    @objc(state) var _objc_state: String { state }
    @objc(postalCode) var _objc_postalCode: String { postalCode }
    @objc(country) var _objc_country: String { country }
    @objc(ISOCountryCode) var _objc_isoCountryCode: String { isoCountryCode }
}
extension CNMutablePostalAddress {
    @objc(setStreet:) func _objc_setStreet(_ v: String) { street = v }
    @objc(setSubLocality:) func _objc_setSubLocality(_ v: String) { subLocality = v }
    @objc(setCity:) func _objc_setCity(_ v: String) { city = v }
    @objc(setSubAdministrativeArea:) func _objc_setSubAdministrativeArea(_ v: String) { subAdministrativeArea = v }
    @objc(setState:) func _objc_setState(_ v: String) { state = v }
    @objc(setPostalCode:) func _objc_setPostalCode(_ v: String) { postalCode = v }
    @objc(setCountry:) func _objc_setCountry(_ v: String) { country = v }
    @objc(setISOCountryCode:) func _objc_setISOCountryCode(_ v: String) { isoCountryCode = v }
}

extension CNContactFormatter {
    @objc(stringFromContact:style:) class func _objc_string(_ contact: CNContact, style: CNContactFormatterStyle) -> String? {
        string(from: contact, style: style)
    }
    @objc(descriptorForRequiredKeysForStyle:) class func _objc_descriptor(_ style: CNContactFormatterStyle) -> CNKeyDescriptor {
        descriptorForRequiredKeys(for: style)
    }
}

extension CNContactFetchRequest {
    @objc(initWithKeysToFetch:) convenience init(_objcKeys keys: [CNKeyDescriptor]) { self.init(keysToFetch: keys) }
    @objc(predicate) var _objc_predicate: NSPredicate? { get { predicate } set { predicate = newValue } }
    @objc(keysToFetch) var _objc_keysToFetch: [CNKeyDescriptor] { get { keysToFetch } set { keysToFetch = newValue } }
    @objc(mutableObjects) var _objc_mutableObjects: Bool { get { mutableObjects } set { mutableObjects = newValue } }
    @objc(unifyResults) var _objc_unifyResults: Bool { get { unifyResults } set { unifyResults = newValue } }
    @objc(sortOrder) var _objc_sortOrder: CNContactSortOrder { get { sortOrder } set { sortOrder = newValue } }
}

extension CNSaveRequest {
    @objc(addContact:toContainerWithIdentifier:) func _objc_add(_ c: CNMutableContact, toContainerWithIdentifier id: String?) {
        add(c, toContainerWithIdentifier: id)
    }
    @objc(updateContact:) func _objc_update(_ c: CNMutableContact) { update(c) }
    @objc(deleteContact:) func _objc_delete(_ c: CNMutableContact) { delete(c) }
    @objc(transactionAuthor) var _objc_transactionAuthor: String? { get { transactionAuthor } set { transactionAuthor = newValue } }
}

extension CNContactStore {
    @objc(authorizationStatusForEntityType:) class func _objc_authorizationStatus(_ t: CNEntityType) -> CNAuthorizationStatus {
        authorizationStatus(for: t)
    }
    @objc(requestAccessForEntityType:completionHandler:)
    func _objc_requestAccess(_ t: CNEntityType, completionHandler: @escaping @convention(block) (Bool, NSError?) -> Void) {
        requestAccess(for: t) { ok, e in completionHandler(ok, e.map { $0 as NSError }) }
    }
    @objc(unifiedContactsMatchingPredicate:keysToFetch:error:)
    func _objc_unifiedContacts(_ p: NSPredicate, keysToFetch keys: [CNKeyDescriptor]) throws -> [CNContact] {
        try unifiedContacts(matching: p, keysToFetch: keys)
    }
    @objc(unifiedContactWithIdentifier:keysToFetch:error:)
    func _objc_unifiedContact(_ id: String, keysToFetch keys: [CNKeyDescriptor]) throws -> CNContact {
        try unifiedContact(withIdentifier: id, keysToFetch: keys)
    }
    @objc(enumerateContactsWithFetchRequest:error:usingBlock:)
    func _objc_enumerate(_ r: CNContactFetchRequest, usingBlock block: (CNContact, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        try enumerateContacts(with: r, usingBlock: block)
    }
    @objc(executeSaveRequest:error:) func _objc_execute(_ r: CNSaveRequest) throws { try execute(r) }
    @objc(defaultContainerIdentifier) func _objc_defaultContainerIdentifier() -> String { defaultContainerIdentifier() }
}
