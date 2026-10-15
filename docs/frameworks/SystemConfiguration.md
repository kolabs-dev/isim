# SystemConfiguration

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 20.4% of Apple's iOS API (29 of 142, exact) · **Rows:** 2: 1 ✅ 1 ❌ · **iOS:** 2.0+
<!-- /generated:header -->

**Area:** [Web, network & communication](../COVERAGE.md#web) · **Apple:** [SystemConfiguration](https://developer.apple.com/documentation/systemconfiguration) · **Issues:** [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

## How isim implements it

- **Passthrough:** reachability comes from the host's connectivity, polled every 2 s.
- CoreTelephony is a stub like the Simulator's: there is no cellular radio.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| SystemConfiguration (`SCNetworkReachability*`), CoreTelephony (`CTTelephonyNetworkInfo`, `CTCarrier`) | ✅ | ≤17 | reachability from the host's connectivity (polled every 2 s); no cellular service, like the Simulator. Tested: test_system_objc |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `SCBondStatus`, `SCDynamicStore`, `SCDynamicStoreContext`, `SCNetworkConnection`, `SCNetworkConnectionContext`, `SCNetworkConnectionPPPStatus`, `SCNetworkConnectionStatus`, `SCNetworkInterface`, `SCNetworkProtocol`, `SCNetworkService`, `SCNetworkSet`, `SCPreferences`, `SCPreferencesContext`, `SCPreferencesNotification` (14 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
113 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`AuthorizationRef`](https://developer.apple.com/documentation/systemconfiguration/authorizationref)
- [`let kCFErrorDomainSystemConfiguration: CFString`](https://developer.apple.com/documentation/systemconfiguration/kcferrordomainsystemconfiguration)
- [`var kSCBondStatusLinkInvalid: Int`](https://developer.apple.com/documentation/systemconfiguration/kscbondstatuslinkinvalid)
- [`var kSCBondStatusNoPartner: Int`](https://developer.apple.com/documentation/systemconfiguration/kscbondstatusnopartner)
- [`var kSCBondStatusNotInActiveGroup: Int`](https://developer.apple.com/documentation/systemconfiguration/kscbondstatusnotinactivegroup)
- [`var kSCBondStatusOK: Int`](https://developer.apple.com/documentation/systemconfiguration/kscbondstatusok)
- [`var kSCBondStatusUnknown: Int`](https://developer.apple.com/documentation/systemconfiguration/kscbondstatusunknown)
- [`var kSCNetworkConnectionBytesIn: String`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkconnectionbytesin)
- [`var kSCNetworkConnectionBytesOut: String`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkconnectionbytesout)
- [`var kSCNetworkConnectionErrorsIn: String`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkconnectionerrorsin)
- [`var kSCNetworkConnectionErrorsOut: String`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkconnectionerrorsout)
- [`var kSCNetworkConnectionPacketsIn: String`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkconnectionpacketsin)
- [`var kSCNetworkConnectionPacketsOut: String`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkconnectionpacketsout)
- [`var kSCNetworkConnectionSelectionOptionOnDemandHostName: String`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkconnectionselectionoptionondemandhostname)
- [`var kSCNetworkConnectionSelectionOptionOnDemandRetry: String`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkconnectionselectionoptionondemandretry)
- [`var kSCNetworkFlagsConnectionAutomatic: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsconnectionautomatic)
- [`var kSCNetworkFlagsConnectionAutomatic: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsconnectionautomatic)
- [`var kSCNetworkFlagsConnectionRequired: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsconnectionrequired)
- [`var kSCNetworkFlagsConnectionRequired: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsconnectionrequired)
- [`var kSCNetworkFlagsInterventionRequired: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsinterventionrequired)
- [`var kSCNetworkFlagsInterventionRequired: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsinterventionrequired)
- [`var kSCNetworkFlagsIsDirect: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsisdirect)
- [`var kSCNetworkFlagsIsDirect: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsisdirect)
- [`var kSCNetworkFlagsIsLocalAddress: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsislocaladdress)
- [`var kSCNetworkFlagsIsLocalAddress: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsislocaladdress)
- [`var kSCNetworkFlagsReachable: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsreachable)
- [`var kSCNetworkFlagsReachable: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagsreachable)
- [`var kSCNetworkFlagsTransientConnection: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagstransientconnection)
- [`var kSCNetworkFlagsTransientConnection: Int`](https://developer.apple.com/documentation/systemconfiguration/kscnetworkflagstransientconnection)
- [`var kSCStatusAccessError: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusaccesserror)
- [`var kSCStatusFailed: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusfailed)
- [`var kSCStatusInvalidArgument: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusinvalidargument)
- [`var kSCStatusKeyExists: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatuskeyexists)
- [`var kSCStatusLocked: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatuslocked)
- [`var kSCStatusMaxLink: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusmaxlink)
- [`var kSCStatusNeedLock: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusneedlock)
- [`var kSCStatusNoConfigFile: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusnoconfigfile)
- [`var kSCStatusNoKey: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusnokey)
- [`var kSCStatusNoLink: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusnolink)
- [`var kSCStatusNoPrefsSession: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusnoprefssession)
- [`var kSCStatusNoStoreServer: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusnostoreserver)
- [`var kSCStatusNoStoreSession: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusnostoresession)
- [`var kSCStatusNotifierActive: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusnotifieractive)
- [`var kSCStatusOK: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusok)
- [`var kSCStatusPrefsBusy: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusprefsbusy)
- [`var kSCStatusReachabilityUnknown: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusreachabilityunknown)
- [`var kSCStatusStale: Int`](https://developer.apple.com/documentation/systemconfiguration/kscstatusstale)
- [`SCBondInterface`](https://developer.apple.com/documentation/systemconfiguration/scbondinterface)
- [`SCBondStatus`](https://developer.apple.com/documentation/systemconfiguration/scbondstatus)
- [`func SCCopyLastError() -> CFError`](https://developer.apple.com/documentation/systemconfiguration/sccopylasterror())
- [`SCDynamicStore`](https://developer.apple.com/documentation/systemconfiguration/scdynamicstore)
- [`SCDynamicStoreCallBack`](https://developer.apple.com/documentation/systemconfiguration/scdynamicstorecallback)
- [`SCDynamicStoreContext`](https://developer.apple.com/documentation/systemconfiguration/scdynamicstorecontext)
- [`var copyDescription: ((UnsafeRawPointer) -> Unmanaged<CFString>)?`](https://developer.apple.com/documentation/systemconfiguration/scdynamicstorecontext/copydescription)
- [`var info: UnsafeMutableRawPointer?`](https://developer.apple.com/documentation/systemconfiguration/scdynamicstorecontext/info)
- [`init()`](https://developer.apple.com/documentation/systemconfiguration/scdynamicstorecontext/init())
- [`init(version: CFIndex, info: UnsafeMutableRawPointer?, retain: ((UnsafeRawPointer) -> UnsafeRawPointer)?, release: ((UnsafeRawPointer) -> Void)?, copyDescription: ((UnsafeRawPointer) -> Unmanaged<CFString>)?)`](https://developer.apple.com/documentation/systemconfiguration/scdynamicstorecontext/init(version:info:retain:release:copydescription:))
- [`var release: ((UnsafeRawPointer) -> Void)?`](https://developer.apple.com/documentation/systemconfiguration/scdynamicstorecontext/release)
- [`var retain: ((UnsafeRawPointer) -> UnsafeRawPointer)?`](https://developer.apple.com/documentation/systemconfiguration/scdynamicstorecontext/retain)
- [`var version: CFIndex`](https://developer.apple.com/documentation/systemconfiguration/scdynamicstorecontext/version)
- [`func SCError() -> Int32`](https://developer.apple.com/documentation/systemconfiguration/scerror())
- [`func SCErrorString(Int32) -> UnsafePointer<CChar>`](https://developer.apple.com/documentation/systemconfiguration/scerrorstring(_:))
- [`SCNetworkConnection`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnection)
- [`SCNetworkConnectionCallBack`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectioncallback)
- [`SCNetworkConnectionContext`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectioncontext)
- [`var copyDescription: ((UnsafeRawPointer) -> Unmanaged<CFString>)?`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectioncontext/copydescription)
- [`var info: UnsafeMutableRawPointer?`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectioncontext/info)
- [`init()`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectioncontext/init())
- [`init(version: CFIndex, info: UnsafeMutableRawPointer?, retain: ((UnsafeRawPointer) -> UnsafeRawPointer)?, release: ((UnsafeRawPointer) -> Void)?, copyDescription: ((UnsafeRawPointer) -> Unmanaged<CFString>)?)`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectioncontext/init(version:info:retain:release:copydescription:))
- [`var release: ((UnsafeRawPointer) -> Void)?`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectioncontext/release)
- [`var retain: ((UnsafeRawPointer) -> UnsafeRawPointer)?`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectioncontext/retain)
- [`var version: CFIndex`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectioncontext/version)
- [`SCNetworkConnectionFlags`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionflags)
- [`SCNetworkConnectionPPPStatus`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus)
- [`case authenticating`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/authenticating)
- [`case connected`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/connected)
- [`case connectingLink`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/connectinglink)
- [`case dialOnTraffic`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/dialontraffic)
- [`case disconnected`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/disconnected)
- [`case disconnectingLink`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/disconnectinglink)
- [`case holdingLinkOff`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/holdinglinkoff)
- [`init?(rawValue: Int32)`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/init(rawvalue:))
- [`case initializing`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/initializing)
- [`case negotiatingLink`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/negotiatinglink)
- [`case negotiatingNetwork`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/negotiatingnetwork)
- [`case suspended`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/suspended)
- [`case terminating`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/terminating)
- [`case waitingForCallBack`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/waitingforcallback)
- [`case waitingForRedial`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionpppstatus/waitingforredial)
- [`SCNetworkConnectionStatus`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionstatus)
- [`case connected`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionstatus/connected)
- [`case connecting`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionstatus/connecting)
- [`case disconnected`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionstatus/disconnected)
- [`case disconnecting`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionstatus/disconnecting)
- [`init?(rawValue: Int32)`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionstatus/init(rawvalue:))
- [`case invalid`](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectionstatus/invalid)
- [`SCNetworkInterface`](https://developer.apple.com/documentation/systemconfiguration/scnetworkinterface)
- [`SCNetworkProtocol`](https://developer.apple.com/documentation/systemconfiguration/scnetworkprotocol)
- [`SCNetworkService`](https://developer.apple.com/documentation/systemconfiguration/scnetworkservice)
- [`SCNetworkSet`](https://developer.apple.com/documentation/systemconfiguration/scnetworkset)
- [`SCPreferences`](https://developer.apple.com/documentation/systemconfiguration/scpreferences)
- [`SCPreferencesCallBack`](https://developer.apple.com/documentation/systemconfiguration/scpreferencescallback)
- [`SCPreferencesContext`](https://developer.apple.com/documentation/systemconfiguration/scpreferencescontext)
- [`var copyDescription: ((UnsafeRawPointer) -> Unmanaged<CFString>)?`](https://developer.apple.com/documentation/systemconfiguration/scpreferencescontext/copydescription)
- [`var info: UnsafeMutableRawPointer?`](https://developer.apple.com/documentation/systemconfiguration/scpreferencescontext/info)
- [`init()`](https://developer.apple.com/documentation/systemconfiguration/scpreferencescontext/init())
- [`init(version: CFIndex, info: UnsafeMutableRawPointer?, retain: ((UnsafeRawPointer) -> UnsafeRawPointer)?, release: ((UnsafeRawPointer) -> Void)?, copyDescription: ((UnsafeRawPointer) -> Unmanaged<CFString>)?)`](https://developer.apple.com/documentation/systemconfiguration/scpreferencescontext/init(version:info:retain:release:copydescription:))
- [`var release: ((UnsafeRawPointer) -> Void)?`](https://developer.apple.com/documentation/systemconfiguration/scpreferencescontext/release)
- [`var retain: ((UnsafeRawPointer) -> UnsafeRawPointer)?`](https://developer.apple.com/documentation/systemconfiguration/scpreferencescontext/retain)
- [`var version: CFIndex`](https://developer.apple.com/documentation/systemconfiguration/scpreferencescontext/version)
- [`SCPreferencesNotification`](https://developer.apple.com/documentation/systemconfiguration/scpreferencesnotification)
- [`init(rawValue: UInt32)`](https://developer.apple.com/documentation/systemconfiguration/scpreferencesnotification/init(rawvalue:))
- [`SCVLANInterface`](https://developer.apple.com/documentation/systemconfiguration/scvlaninterface)

</details>
<!-- /generated:missing -->
