// isim ContactsUI for Objective-C (sdk-src/Frameworks/ContactsUI): the classes carry Apple's Objective-C names and these
// members Apple's selectors. The delegate protocols are @objc with Apple's selectors, so Objective-C delegates are used
// as they are.
import UIKit
@_spi(isim) import Contacts

extension CNContactProperty {
    @objc(contact) var _objc_contact: CNContact { contact }
    @objc(key) var _objc_key: String { key }
    @objc(value) var _objc_value: Any? { value }
    @objc(identifier) var _objc_identifier: String? { identifier }
    @objc(label) var _objc_label: String? { label }
}

extension CNContactPickerViewController {
    @objc(delegate) var _objc_delegate: CNContactPickerDelegate? { get { delegate } set { delegate = newValue } }
    @objc(displayedPropertyKeys) var _objc_displayedPropertyKeys: [String]? { get { displayedPropertyKeys } set { displayedPropertyKeys = newValue } }
    @objc(predicateForEnablingContact) var _objc_predicateForEnablingContact: NSPredicate? {
        get { predicateForEnablingContact } set { predicateForEnablingContact = newValue }
    }
    @objc(predicateForSelectionOfContact) var _objc_predicateForSelectionOfContact: NSPredicate? {
        get { predicateForSelectionOfContact } set { predicateForSelectionOfContact = newValue }
    }
    @objc(predicateForSelectionOfProperty) var _objc_predicateForSelectionOfProperty: NSPredicate? {
        get { predicateForSelectionOfProperty } set { predicateForSelectionOfProperty = newValue }
    }
}

extension CNContactViewController {
    @objc(viewControllerForContact:) class func _objc_forContact(_ c: CNContact) -> CNContactViewController { CNContactViewController(for: c) }
    @objc(viewControllerForUnknownContact:) class func _objc_forUnknown(_ c: CNContact) -> CNContactViewController {
        CNContactViewController(forUnknownContact: c)
    }
    @objc(viewControllerForNewContact:) class func _objc_forNew(_ c: CNContact?) -> CNContactViewController { CNContactViewController(forNewContact: c) }
    @objc(descriptorForRequiredKeys) class func _objc_descriptorForRequiredKeys() -> CNKeyDescriptor { descriptorForRequiredKeys() }
    @objc(delegate) var _objc_delegate: CNContactViewControllerDelegate? { get { delegate } set { delegate = newValue } }
    @objc(contactStore) var _objc_contactStore: CNContactStore? { get { contactStore } set { contactStore = newValue } }
    @objc(contact) var _objc_contact: CNContact { contact }
    @objc(allowsEditing) var _objc_allowsEditing: Bool { get { allowsEditing } set { allowsEditing = newValue } }
    @objc(allowsActions) var _objc_allowsActions: Bool { get { allowsActions } set { allowsActions = newValue } }
    @objc(displayedPropertyKeys) var _objc_displayedPropertyKeys: [String]? { get { displayedPropertyKeys } set { displayedPropertyKeys = newValue } }
    @objc(message) var _objc_message: String? { get { message } set { message = newValue } }
    @objc(alternateName) var _objc_alternateName: String? { get { alternateName } set { alternateName = newValue } }
}
