# MessageUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 66.3% of Apple's iOS API (55 of 83, exact) · **Rows:** 50% (2: 1 ✅ 1 ❌) · **iOS:** 3.0+
<!-- /generated:header -->

**Area:** [Web, network & communication](../COVERAGE.md#web) · **Apple:** [MessageUI](https://developer.apple.com/documentation/messageui) · **Issues:** [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

## How isim implements it

- **Adapted:** the composers write `.eml` and JSON files into an outbox.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| MessageUI (`MFMailComposeViewController`, `MFMessageComposeViewController`) | ✅ | ≤17 | like the Simulator `canSendMail()`/`canSendText()` are false (presenting shows nothing); `ISIM_MAIL=1` / `ISIM_MESSAGES=1` give the device accounts: iOS 17-style composers prefilled from the API, Send / Cancel → Delete or Save Draft, results to the delegates; nothing is sent — mails become `.eml` files in `$ISIM_DATA/Library/Mail/{Outbox,Drafts}`, messages JSON in `Library/SMS/Outbox`. Tested |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `MFComposeAssistantViewController`, `MFComposeAssistantViewControllerDelegate`, `MFMailComposeControllerDeferredAction`, `MFMailDraft`, `WritingAssistant` (5 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
28 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`MFComposeAssistantViewController`](https://developer.apple.com/documentation/messageui/mfcomposeassistantviewcontroller)
- [`init(delegate: any MFComposeAssistantViewControllerDelegate)`](https://developer.apple.com/documentation/messageui/mfcomposeassistantviewcontroller/init(delegate:))
- [`MFComposeAssistantViewControllerDelegate`](https://developer.apple.com/documentation/messageui/mfcomposeassistantviewcontrollerdelegate)
- [`func composeAssistantViewController(MFComposeAssistantViewController, didComposeDraft: MFMailDraft)`](https://developer.apple.com/documentation/messageui/mfcomposeassistantviewcontrollerdelegate/composeassistantviewcontroller(_:didcomposedraft:))
- [`MFMailComposeControllerDeferredAction`](https://developer.apple.com/documentation/messageui/mfmailcomposecontrollerdeferredaction)
- [`case addMissingRecipients`](https://developer.apple.com/documentation/messageui/mfmailcomposecontrollerdeferredaction/addmissingrecipients)
- [`case adjustInsertionPoint`](https://developer.apple.com/documentation/messageui/mfmailcomposecontrollerdeferredaction/adjustinsertionpoint)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/messageui/mfmailcomposecontrollerdeferredaction/init(rawvalue:))
- [`case none`](https://developer.apple.com/documentation/messageui/mfmailcomposecontrollerdeferredaction/none)
- [`func insertCollaborationItemProvider(NSItemProvider, completionHandler: (Bool) -> Void)`](https://developer.apple.com/documentation/messageui/mfmailcomposeviewcontroller/insertcollaborationitemprovider(_:completionhandler:))
- [`MFMailDraft`](https://developer.apple.com/documentation/messageui/mfmaildraft)
- [`var body: NSAttributedString`](https://developer.apple.com/documentation/messageui/mfmaildraft/body)
- [`var cc: [String]`](https://developer.apple.com/documentation/messageui/mfmaildraft/cc)
- [`var from: String?`](https://developer.apple.com/documentation/messageui/mfmaildraft/from)
- [`init(subject: String, body: NSAttributedString, from: String, to: [String], cc: [String])`](https://developer.apple.com/documentation/messageui/mfmaildraft/init(subject:body:from:to:cc:))
- [`var subject: String`](https://developer.apple.com/documentation/messageui/mfmaildraft/subject)
- [`var to: [String]`](https://developer.apple.com/documentation/messageui/mfmaildraft/to)
- [`var attachments: [[AnyHashable : Any]]?`](https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller/attachments)
- [`func insertCollaborationItemProvider(NSItemProvider) -> Bool`](https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller/insertcollaborationitemprovider(_:))
- [`func setUPIVerificationCodeSendCompletion((Bool) -> Void)`](https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller/setupiverificationcodesendcompletion(_:))
- [`MFMessageComposeViewController.TextMessageAvailabilityDidChangeMessage`](https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller/textmessageavailabilitydidchangemessage)
- [`var canSendText: Bool`](https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller/textmessageavailabilitydidchangemessage/cansendtext)
- [`init(canSendText: Bool)`](https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller/textmessageavailabilitydidchangemessage/init(cansendtext:))
- [`static func makeMessage(Notification) -> MFMessageComposeViewController.TextMessageAvailabilityDidChangeMessage?`](https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller/textmessageavailabilitydidchangemessage/makemessage(_:))
- [`static func makeNotification(MFMessageComposeViewController.TextMessageAvailabilityDidChangeMessage) -> Notification`](https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller/textmessageavailabilitydidchangemessage/makenotification(_:))
- [`static var name: Notification.Name`](https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller/textmessageavailabilitydidchangemessage/name)
- [`MFMessageComposeViewController.TextMessageAvailabilityDidChangeMessage.Subject`](https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller/textmessageavailabilitydidchangemessage/subject)
- [`WritingAssistant`](https://developer.apple.com/documentation/messageui/writingassistant)

</details>
<!-- /generated:missing -->
