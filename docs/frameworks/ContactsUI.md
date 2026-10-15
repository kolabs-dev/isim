# ContactsUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 79.2% of Apple's iOS API (38 of 48, exact) · **Rows:** 0% (1: 1 ❌) · **iOS:** 9.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [Contacts UI](https://developer.apple.com/documentation/contactsui) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Adapted:** pickers and the contact view drawn by isim over its address book. Rows: [Contacts](Contacts.md).

## API

| API / feature | Status | iOS | Notes |
| Objective-C interface (`ContactsUI.framework`): `CNContactPickerViewController` and `CNContactPickerDelegate`, `CNContactViewController` and `CNContactViewControllerDelegate`, `CNContactProperty` | ✅ | ≤17 | adapted: headers over the Swift overlay's classes (Apple's Objective-C names). `CNContactViewControllerDelegate`'s selectors are now Apple's (`contactViewController:didCompleteWithContact:`); Swift apps built with 0.22 or earlier still get the call. Tested (HelloPersonalObjC: the picker, tests/ui/test_personal_objc.py) |
|---|---|---|---|
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `ContactAccessButton` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
10 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`func highlightProperty(withKey: String, identifier: String?)`](https://developer.apple.com/documentation/contactsui/cncontactviewcontroller/highlightproperty(withkey:identifier:))
- [`ContactAccessButton`](https://developer.apple.com/documentation/contactsui/contactaccessbutton)
- [`ContactAccessButton.Caption`](https://developer.apple.com/documentation/contactsui/contactaccessbutton/caption)
- [`case defaultText`](https://developer.apple.com/documentation/contactsui/contactaccessbutton/caption/defaulttext)
- [`case email`](https://developer.apple.com/documentation/contactsui/contactaccessbutton/caption/email)
- [`case phone`](https://developer.apple.com/documentation/contactsui/contactaccessbutton/caption/phone)
- [`init(queryString: String, ignoredEmails: Set<String>?, ignoredPhoneNumbers: Set<String>?, approvalCallback: (([String]) -> Void)?)`](https://developer.apple.com/documentation/contactsui/contactaccessbutton/init(querystring:ignoredemails:ignoredphonenumbers:approvalcallback:))
- [`ContactAccessButton.Style`](https://developer.apple.com/documentation/contactsui/contactaccessbutton/style)
- [`static let automatic: ContactAccessButton.Style`](https://developer.apple.com/documentation/contactsui/contactaccessbutton/style/automatic)
- [`init(imageTrailingEdgePadding: CGFloat?, imageWidth: CGFloat?, imageColor: Color?)`](https://developer.apple.com/documentation/contactsui/contactaccessbutton/style/init(imagetrailingedgepadding:imagewidth:imagecolor:))

</details>
<!-- /generated:missing -->
