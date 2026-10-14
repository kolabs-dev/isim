# CallKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 80.6% of Apple's iOS API (257 of 319, exact) · **Rows:** 100% (1: 1 ✅) · **iOS:** 10.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [CallKit](https://developer.apple.com/documentation/callkit) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Adapted:** the shell draws the call UI (`isim/runtime/shell_calls.inc`), with a synthesized ringtone. There is no telephony.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Calls (CallKit) | ✅ | ≤17 | adapted: isim has no telephony; the app's calls get the system call UI drawn by the shell. `CXProvider` (`reportNewIncomingCall` + async, `reportCall(with:updated:)`, `reportCall(with:endedAt:reason:)`, `reportOutgoingCall(…startedConnectingAt:)` / `(…connectedAt:)`, `invalidate`, configuration: name, ringtone, video, call groups) and `CXProviderDelegate` (every action, `provider(_:execute:)`, `didActivate` / `didDeactivate` of the audio session); an incoming call shows as a banner while the device is in use (in the Dynamic Island's black) or full screen with "slide to answer" on the Lock Screen, with the ringtone (silent in Silent Mode); answered, the call screen: speaker (`AVAudioSession` route override), mute, hold (`supportsHolding`), keypad (DTMF with `supportsDTMF`), the app's button, End; Home hides it behind the green call indicator (the Dynamic Island's phone and duration). `CXCallController` requests are checked like iOS (`CXErrorCodeRequestTransactionError`: empty transaction, unknown call, call exists, maximum call groups, no provider) and performed by the app's provider; `CXCallObserver` sees the app's calls (not other apps'); calls keep the app running in the background. Stub: Call Directory extensions are never run (`reloadExtension` fails with `extensionDisabled`, status disabled, like iOS before the user turns one on). Not drawn: video calls (the video button is shown, no video UI), call merging. Tested (HelloCalls: test_calls, OS matrix) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
62 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var CXCallDirectoryPhoneNumberMax: CXCallDirectoryPhoneNumber`](https://developer.apple.com/documentation/callkit/cxcalldirectoryphonenumbermax)
- [`CXError`](https://developer.apple.com/documentation/callkit/cxerror)
- [`CXError.Code`](https://developer.apple.com/documentation/callkit/cxerror/code)
- [`CXError.Code`](https://developer.apple.com/documentation/callkit/cxerror/code)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/callkit/cxerror/code/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/callkit/cxerror/code/init(rawvalue:))
- [`case invalidArgument`](https://developer.apple.com/documentation/callkit/cxerror/code/invalidargument)
- [`case invalidArgument`](https://developer.apple.com/documentation/callkit/cxerror/code/invalidargument)
- [`case missingVoIPBackgroundMode`](https://developer.apple.com/documentation/callkit/cxerror/code/missingvoipbackgroundmode)
- [`case missingVoIPBackgroundMode`](https://developer.apple.com/documentation/callkit/cxerror/code/missingvoipbackgroundmode)
- [`case unentitled`](https://developer.apple.com/documentation/callkit/cxerror/code/unentitled)
- [`case unentitled`](https://developer.apple.com/documentation/callkit/cxerror/code/unentitled)
- [`case unknownError`](https://developer.apple.com/documentation/callkit/cxerror/code/unknownerror)
- [`case unknownError`](https://developer.apple.com/documentation/callkit/cxerror/code/unknownerror)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/callkit/cxerror/errordomain)
- [`static var invalidArgument: CXError.Code`](https://developer.apple.com/documentation/callkit/cxerror/invalidargument)
- [`static var missingVoIPBackgroundMode: CXError.Code`](https://developer.apple.com/documentation/callkit/cxerror/missingvoipbackgroundmode)
- [`static var unentitled: CXError.Code`](https://developer.apple.com/documentation/callkit/cxerror/unentitled)
- [`static var unknownError: CXError.Code`](https://developer.apple.com/documentation/callkit/cxerror/unknownerror)
- [`static var currentlyLoading: CXErrorCodeCallDirectoryManagerError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodecalldirectorymanagererror-swift.struct/currentlyloading)
- [`static var duplicateEntries: CXErrorCodeCallDirectoryManagerError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodecalldirectorymanagererror-swift.struct/duplicateentries)
- [`static var entriesOutOfOrder: CXErrorCodeCallDirectoryManagerError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodecalldirectorymanagererror-swift.struct/entriesoutoforder)
- [`static var loadingInterrupted: CXErrorCodeCallDirectoryManagerError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodecalldirectorymanagererror-swift.struct/loadinginterrupted)
- [`static var maximumEntriesExceeded: CXErrorCodeCallDirectoryManagerError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodecalldirectorymanagererror-swift.struct/maximumentriesexceeded)
- [`static var unexpectedIncrementalRemoval: CXErrorCodeCallDirectoryManagerError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodecalldirectorymanagererror-swift.struct/unexpectedincrementalremoval)
- [`static var unknown: CXErrorCodeCallDirectoryManagerError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodecalldirectorymanagererror-swift.struct/unknown)
- [`static var callIsProtected: CXErrorCodeIncomingCallError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodeincomingcallerror-swift.struct/callisprotected)
- [`case filteredBySensitiveParticipants`](https://developer.apple.com/documentation/callkit/cxerrorcodeincomingcallerror-swift.struct/code/filteredbysensitiveparticipants)
- [`case filteredBySensitiveParticipants`](https://developer.apple.com/documentation/callkit/cxerrorcodeincomingcallerror-swift.struct/code/filteredbysensitiveparticipants)
- [`static var filteredBySensitiveParticipants: CXErrorCodeIncomingCallError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodeincomingcallerror-swift.struct/filteredbysensitiveparticipants)
- [`static var filteredDuringRestrictedSharingMode: CXErrorCodeIncomingCallError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodeincomingcallerror-swift.struct/filteredduringrestrictedsharingmode)
- [`CXErrorCodeNotificationServiceExtensionError`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct)
- [`CXErrorCodeNotificationServiceExtensionError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/code)
- [`CXErrorCodeNotificationServiceExtensionError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/code)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/code/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/code/init(rawvalue:))
- [`case invalidClientProcess`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/code/invalidclientprocess)
- [`case invalidClientProcess`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/code/invalidclientprocess)
- [`case missingNotificationFilteringEntitlement`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/code/missingnotificationfilteringentitlement)
- [`case missingNotificationFilteringEntitlement`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/code/missingnotificationfilteringentitlement)
- [`case unknown`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/code/unknown)
- [`case unknown`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/code/unknown)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/errordomain)
- [`static var invalidClientProcess: CXErrorCodeNotificationServiceExtensionError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/invalidclientprocess)
- [`static var missingNotificationFilteringEntitlement: CXErrorCodeNotificationServiceExtensionError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/missingnotificationfilteringentitlement)
- [`static var unknown: CXErrorCodeNotificationServiceExtensionError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcodenotificationserviceextensionerror-swift.struct/unknown)
- [`static var callIsProtected: CXErrorCodeRequestTransactionError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcoderequesttransactionerror-swift.struct/callisprotected)
- [`static var unentitled: CXErrorCodeRequestTransactionError.Code`](https://developer.apple.com/documentation/callkit/cxerrorcoderequesttransactionerror-swift.struct/unentitled)
- [`class func reportNewIncomingVoIPPushPayload([AnyHashable : Any], completion: (((any Error)?) -> Void)?)`](https://developer.apple.com/documentation/callkit/cxprovider/reportnewincomingvoippushpayload(_:completion:))
- [`var supportsAudioTranslation: Bool`](https://developer.apple.com/documentation/callkit/cxproviderconfiguration/supportsaudiotranslation)
- [`CXSetTranslatingCallAction`](https://developer.apple.com/documentation/callkit/cxsettranslatingcallaction)
- [`func fulfill(using: CXTranslationEngine)`](https://developer.apple.com/documentation/callkit/cxsettranslatingcallaction/fulfill(using:))
- [`init(call: UUID, isTranslating: Bool, localLanguage: String, remoteLanguage: String)`](https://developer.apple.com/documentation/callkit/cxsettranslatingcallaction/init(call:istranslating:locallanguage:remotelanguage:))
- [`init(callUUID: UUID, isTranslating: Bool, localLanguage: String, remoteLanguage: String)`](https://developer.apple.com/documentation/callkit/cxsettranslatingcallaction/init(calluuid:istranslating:locallanguage:remotelanguage:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/callkit/cxsettranslatingcallaction/init(coder:))
- [`var isTranslating: Bool`](https://developer.apple.com/documentation/callkit/cxsettranslatingcallaction/istranslating)
- [`var localLanguage: String`](https://developer.apple.com/documentation/callkit/cxsettranslatingcallaction/locallanguage)
- [`var remoteLanguage: String`](https://developer.apple.com/documentation/callkit/cxsettranslatingcallaction/remotelanguage)
- [`CXTranslationEngine`](https://developer.apple.com/documentation/callkit/cxtranslationengine)
- [`case custom`](https://developer.apple.com/documentation/callkit/cxtranslationengine/custom)
- [`case `default``](https://developer.apple.com/documentation/callkit/cxtranslationengine/default)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/callkit/cxtranslationengine/init(rawvalue:))

</details>
<!-- /generated:missing -->
