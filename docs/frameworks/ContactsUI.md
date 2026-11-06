# ContactsUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 95.2% of Apple's iOS API (40 of 42, exact) · **Rows:** 2: 2 ✅ · **iOS:** 9.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [Contacts UI](https://developer.apple.com/documentation/contactsui) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Adapted:** pickers and the contact view drawn by isim over its address book. Rows: [Contacts](Contacts.md).

## API

| API / feature | Status | iOS | Notes |
| Objective-C interface (`ContactsUI.framework`): `CNContactPickerViewController` and `CNContactPickerDelegate`, `CNContactViewController` and `CNContactViewControllerDelegate`, `CNContactProperty` | ✅ | ≤17 | adapted: headers over the Swift overlay's classes (Apple's Objective-C names). `CNContactViewControllerDelegate`'s selectors are now Apple's (`contactViewController:didCompleteWithContact:`); Swift apps built with 0.22 or earlier still get the call. Tested (HelloPersonalObjC: the picker, tests/ui/test_personal_objc.py) |
|---|---|---|---|
| `ContactAccessButton` (`init(queryString:ignoredEmails:ignoredPhoneNumbers:approvalCallback:)`, `Caption`, `Style`), `contactAccessButtonCaption(_:)`, `contactAccessButtonStyle(_:)`, `contactAccessPicker(isPresented:completionHandler:)` | ✅ | 18.0 | adapted: for apps with limited Contacts access. The button shows the device contact that best matches the search (by name, then phone number, then email) and that the app cannot read yet, with its email or phone number, and a plus; a tap shares it (an app that has not asked yet gets limited access to it, as on iOS), says Added and calls the callback with its identifier. Contacts with an ignored email or phone number are skipped. The picker is the limited-access selection list over the contacts not shared yet; the handler gets the ones added. Like iOS's, both run outside the app's permission. Tested (HelloPersonal: Limited Access, tests/ui/test_personal.py `test_contact_access_button`, `os_matrix`) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
2 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`func highlightProperty(withKey: String, identifier: String?)`](https://developer.apple.com/documentation/contactsui/cncontactviewcontroller/highlightproperty(withkey:identifier:))
- [`convenience init(forContact: CNContact)`](https://developer.apple.com/documentation/contactsui/cncontactviewcontroller/init(forcontact:))

</details>
<!-- /generated:missing -->
