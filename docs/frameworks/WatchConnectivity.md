# WatchConnectivity

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 48.4% of Apple's iOS API (59 of 122, exact) · **Rows:** 1: 1 🧩 · **iOS:** 9.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Approach:** stub, like Apple's Simulator with no paired watch simulator (`isim/frameworks/WatchConnectivity`).
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/WatchConnectivity` (the framework is
  Objective-C).
- **Versus Apple's Simulator:** the same: the session is supported and activates; nothing is paired, installed or
  reachable.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `WCSession` (`isSupported`, `default`, `delegate`, `activate()`, `activationState`, `isPaired`, `isWatchAppInstalled`, `isReachable`, `isComplicationEnabled`, `sendMessage`, `sendMessageData`, `applicationContext`, `updateApplicationContext(_:)`, `receivedApplicationContext`, `transferUserInfo`, `transferCurrentComplicationUserInfo`, `transferFile`, the outstanding transfers), `WCSessionDelegate`, `WCSessionActivationState`, `WCSessionFile`, `WCSessionFileTransfer`, `WCSessionUserInfoTransfer`, `WCError` | 🧩 | ≤17 | stub: activation completes as activated; messages fail with `notReachable`, `updateApplicationContext` throws `deviceNotPaired`, and user-info and file transfers finish with `deviceNotPaired`. Tested (HelloAccessories: test_devices) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
63 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`WCError`](https://developer.apple.com/documentation/watchconnectivity/wcerror)
- [`WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code)
- [`WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code)
- [`case companionAppNotInstalled`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/companionappnotinstalled)
- [`case companionAppNotInstalled`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/companionappnotinstalled)
- [`case deliveryFailed`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/deliveryfailed)
- [`case deliveryFailed`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/deliveryfailed)
- [`case deviceNotPaired`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/devicenotpaired)
- [`case deviceNotPaired`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/devicenotpaired)
- [`case fileAccessDenied`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/fileaccessdenied)
- [`case fileAccessDenied`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/fileaccessdenied)
- [`case genericError`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/genericerror)
- [`case genericError`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/genericerror)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/init(rawvalue:))
- [`case insufficientSpace`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/insufficientspace)
- [`case insufficientSpace`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/insufficientspace)
- [`case invalidParameter`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/invalidparameter)
- [`case invalidParameter`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/invalidparameter)
- [`case messageReplyFailed`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/messagereplyfailed)
- [`case messageReplyFailed`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/messagereplyfailed)
- [`case messageReplyTimedOut`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/messagereplytimedout)
- [`case messageReplyTimedOut`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/messagereplytimedout)
- [`case notReachable`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/notreachable)
- [`case notReachable`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/notreachable)
- [`case payloadTooLarge`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/payloadtoolarge)
- [`case payloadTooLarge`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/payloadtoolarge)
- [`case payloadUnsupportedTypes`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/payloadunsupportedtypes)
- [`case payloadUnsupportedTypes`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/payloadunsupportedtypes)
- [`case sessionInactive`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/sessioninactive)
- [`case sessionInactive`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/sessioninactive)
- [`case sessionMissingDelegate`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/sessionmissingdelegate)
- [`case sessionMissingDelegate`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/sessionmissingdelegate)
- [`case sessionNotActivated`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/sessionnotactivated)
- [`case sessionNotActivated`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/sessionnotactivated)
- [`case sessionNotSupported`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/sessionnotsupported)
- [`case sessionNotSupported`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/sessionnotsupported)
- [`case transferTimedOut`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/transfertimedout)
- [`case transferTimedOut`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/transfertimedout)
- [`case watchAppNotInstalled`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/watchappnotinstalled)
- [`case watchAppNotInstalled`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/watchappnotinstalled)
- [`case watchOnlyApp`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/watchonlyapp)
- [`case watchOnlyApp`](https://developer.apple.com/documentation/watchconnectivity/wcerror/code/watchonlyapp)
- [`static var companionAppNotInstalled: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/companionappnotinstalled)
- [`static var deliveryFailed: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/deliveryfailed)
- [`static var deviceNotPaired: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/devicenotpaired)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/watchconnectivity/wcerror/errordomain)
- [`static var fileAccessDenied: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/fileaccessdenied)
- [`static var genericError: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/genericerror)
- [`static var insufficientSpace: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/insufficientspace)
- [`static var invalidParameter: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/invalidparameter)
- [`static var messageReplyFailed: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/messagereplyfailed)
- [`static var messageReplyTimedOut: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/messagereplytimedout)
- [`static var notReachable: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/notreachable)
- [`static var payloadTooLarge: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/payloadtoolarge)
- [`static var payloadUnsupportedTypes: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/payloadunsupportedtypes)
- [`static var sessionInactive: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/sessioninactive)
- [`static var sessionMissingDelegate: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/sessionmissingdelegate)
- [`static var sessionNotActivated: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/sessionnotactivated)
- [`static var sessionNotSupported: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/sessionnotsupported)
- [`static var transferTimedOut: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/transfertimedout)
- [`static var watchAppNotInstalled: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/watchappnotinstalled)
- [`static var watchOnlyApp: WCError.Code`](https://developer.apple.com/documentation/watchconnectivity/wcerror/watchonlyapp)

</details>
<!-- /generated:missing -->
