# MultipeerConnectivity

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 94.0% of Apple's iOS API (125 of 133, exact) · **Rows:** 2: 2 ✅ · **iOS:** 7.0+
<!-- /generated:header -->

**Area:** [Web, network & communication](../COVERAGE.md#web) · **Apple:** [MultipeerConnectivity](https://developer.apple.com/documentation/multipeerconnectivity) · **Issues:** [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

## How isim implements it

- **Adapted:** Bonjour plus TCP between isim devices.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| MultipeerConnectivity | ✅ | ≤17 | adapted: no peer-to-peer radio; advertisers are Bonjour services (this device's registry and multicast DNS, so other isim devices on the network too) and peers talk over TCP: advertiser/browser, discovery info, invitations with context, session state, data (reliable/unreliable alike), resources, byte streams (`startStream` → the peer's `InputStream`), security identities (certificate chains exchanged, proof of the private key, `didReceiveCertificate` accepts or refuses), `MCBrowserViewController` (Connecting / Connected, Done at `minimumNumberOfPeers`) and `MCAdvertiserAssistant` (invitation alert, delegate). Not encrypted, and no interoperation with real iOS devices (Apple's wire protocol is private). Tested (test_connections, test_connections_mcui) |
| Objective-C interface (`MultipeerConnectivity.framework`): `MCPeerID`, `MCSession` (send data, resources, streams), `MCNearbyServiceAdvertiser`, `MCNearbyServiceBrowser`, `MCBrowserViewController`, `MCAdvertiserAssistant`, their delegate protocols, `MCErrorDomain` | ✅ | ≤17 | adapted: headers over the Swift overlay's classes (Apple's Objective-C names); Objective-C delegates are wrapped for the overlay's Swift delegate protocols. Tested (HelloServicesObjC: an advertiser and a browser in one app connect and exchange data, tests/ui/test_services_objc.py) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
8 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`static var cancelled: MCError.Code`](https://developer.apple.com/documentation/multipeerconnectivity/mcerror/cancelled)
- [`static var invalidParameter: MCError.Code`](https://developer.apple.com/documentation/multipeerconnectivity/mcerror/invalidparameter)
- [`static var notConnected: MCError.Code`](https://developer.apple.com/documentation/multipeerconnectivity/mcerror/notconnected)
- [`static var timedOut: MCError.Code`](https://developer.apple.com/documentation/multipeerconnectivity/mcerror/timedout)
- [`static var unavailable: MCError.Code`](https://developer.apple.com/documentation/multipeerconnectivity/mcerror/unavailable)
- [`static var unknown: MCError.Code`](https://developer.apple.com/documentation/multipeerconnectivity/mcerror/unknown)
- [`static var unsupported: MCError.Code`](https://developer.apple.com/documentation/multipeerconnectivity/mcerror/unsupported)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/multipeerconnectivity/mcpeerid/init(coder:))

</details>
<!-- /generated:missing -->
