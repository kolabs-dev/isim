# CoreTelephony

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 46.4% of Apple's iOS API (78 of 168, exact) · **Rows:** 7: 1 ✅ 4 🧩 2 ❌ · **iOS:** 4.0+
<!-- /generated:header -->

**Area:** [Web, network & communication](../COVERAGE.md#web) · **Apple:** [Core Telephony](https://developer.apple.com/documentation/coretelephony) · **Issues:** [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

## How isim implements it

- **Stub,** like the Simulator: there is no cellular radio. Rows: [SystemConfiguration](SystemConfiguration.md).
- **Objective-C / C interface:** isim's Objective-C framework (`isim/frameworks/CoreTelephony`, header in
  `isim/sdk-src/Frameworks/CoreTelephony`); Swift imports it through the header.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `CTTelephonyNetworkInfo`, `CTCarrier`, radio access technology constants and notifications | 🧩 | ≤17 | stub, like the Simulator: no carriers, no radio access technology (`nil`), no change notifications. Tested (HelloSystemObjC) |
| `CTCellularData` (`restrictedState`, `cellularDataRestrictionDidUpdateNotifier`), `CTCellularDataRestrictedState` | 🧩 | ≤17 | stub, like the Simulator: the state is `restrictedStateUnknown` and no change is ever reported. Tested (HelloNetwork from Swift, tests/ui/test_network.py; HelloSystemObjC, tests/ui/test_system_objc.py) |
| `CTSubscriberInfo` (`subscribers()`, deprecated `subscriber()`), `CTSubscriber` (`identifier`, `carrierToken`, `refreshCarrierToken()`, `isSIMInserted`, `delegate`), `CTSubscriberDelegate`, `CTSubscriberTokenRefreshed` | 🧩 | ≤17 | stub, like the Simulator: no SIM, so `subscribers()` is empty; the deprecated `subscriber()` gives one with an empty identifier, no carrier token and `isSIMInserted` false; its delegate is never called. Tested (HelloNetwork, HelloSystemObjC) |
| `CTCellularPlanProvisioning` (`supportsCellularPlan()`, `supportsEmbeddedSIM`, `addPlan(with:completionHandler:)`), `CTCellularPlanProvisioningRequest` (`NSSecureCoding`), `CTCellularPlanProvisioningAddPlanResult` | 🧩 | ≤17 | stub: no eSIM, so `supportsCellularPlan()` is false and `addPlan(with:)` completes with `.fail` (logged). Tested (HelloSystemObjC) |
| `CTError`, `kCTErrorDomainNoError` / `POSIX` / `Mach` | ✅ | ≤17 | Apple's C struct and constants. Tested (HelloSystemObjC) |
| Types not yet in isim (iOS 26) | ❌ | 26.0 | not implemented, found by the 2026-10 sweep: `CTCellularPlanCapability`, `CTCellularPlanProperties`, `CTCellularPlanStatus`, `CTSlicingManager` (4 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 27) | ❌ | 27.0 | not implemented, found by the 2026-10 sweep: `CTQuickSwitchManager`, `CTQuickSwitchManager.Delegate`, `CTQuickSwitchState` (3 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
90 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`CTCellularPlanCapability`](https://developer.apple.com/documentation/coretelephony/ctcellularplancapability)
- [`case dataAndVoice`](https://developer.apple.com/documentation/coretelephony/ctcellularplancapability/dataandvoice)
- [`case dataOnly`](https://developer.apple.com/documentation/coretelephony/ctcellularplancapability/dataonly)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coretelephony/ctcellularplancapability/init(rawvalue:))
- [`CTCellularPlanProperties`](https://developer.apple.com/documentation/coretelephony/ctcellularplanproperties)
- [`var associatedIccid: String?`](https://developer.apple.com/documentation/coretelephony/ctcellularplanproperties/associatediccid)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/coretelephony/ctcellularplanproperties/init(coder:))
- [`CTCellularPlanProperties.lifecycle`](https://developer.apple.com/documentation/coretelephony/ctcellularplanproperties/lifecycle)
- [`var expirationDate: DateComponents`](https://developer.apple.com/documentation/coretelephony/ctcellularplanproperties/lifecycle/expirationdate)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/coretelephony/ctcellularplanproperties/lifecycle/init(coder:))
- [`var lifecycleProperties: CTCellularPlanProperties.lifecycle?`](https://developer.apple.com/documentation/coretelephony/ctcellularplanproperties/lifecycleproperties)
- [`var simCapability: CTCellularPlanCapability`](https://developer.apple.com/documentation/coretelephony/ctcellularplanproperties/simcapability)
- [`var supportedRegionCodes: [Locale.Region]`](https://developer.apple.com/documentation/coretelephony/ctcellularplanproperties/supportedregioncodes-yhu5)
- [`func update(CTCellularPlanProperties, completionHandler: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctcellularplanprovisioning/update(_:completionhandler:))
- [`CTCellularPlanStatus`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatus)
- [`class func checkValidity(ofToken: String, completionHandler: (Bool, (any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatus/checkvalidity(oftoken:completionhandler:))
- [`class func getAuthorizationStatus(forPhoneNumber: String, completion: (CTCellularPlanStatusAuthorization, (any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatus/getauthorizationstatus(forphonenumber:completion:))
- [`class func getHintForPhoneNumber(String, completion: (CTCellularPlanStatusAvailability, CTCellularPlanStatusAvailabilityConfidence, (any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatus/gethintforphonenumber(_:completion:))
- [`class func getTokenWithCompletion((String?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatus/gettokenwithcompletion(_:))
- [`class func requestAuthorization(forPhoneNumber: String, completion: (CTCellularPlanStatusAuthorization, (any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatus/requestauthorization(forphonenumber:completion:))
- [`CTCellularPlanStatusAuthorization`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusauthorization)
- [`case authorized`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusauthorization/authorized)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusauthorization/init(rawvalue:))
- [`case notAuthorized`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusauthorization/notauthorized)
- [`case notSupported`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusauthorization/notsupported)
- [`case restricted`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusauthorization/restricted)
- [`CTCellularPlanStatusAvailability`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusavailability)
- [`case available`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusavailability/available)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusavailability/init(rawvalue:))
- [`case unavailable`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusavailability/unavailable)
- [`CTCellularPlanStatusAvailabilityConfidence`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusavailabilityconfidence)
- [`case high`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusavailabilityconfidence/high)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusavailabilityconfidence/init(rawvalue:))
- [`case low`](https://developer.apple.com/documentation/coretelephony/ctcellularplanstatusavailabilityconfidence/low)
- [`CTQuickSwitchManager`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager)
- [`var delegate: (any CTQuickSwitchManager.Delegate)?`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/delegate-swift.property)
- [`var delegate: (any CTQuickSwitchManager.Delegate)?`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/delegate-swift.property)
- [`CTQuickSwitchManager.Delegate`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/delegate-swift.protocol)
- [`func quickSwitchManager(CTQuickSwitchManager, didChangeTo: CTQuickSwitchState)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/delegate-swift.protocol/quickswitchmanager(_:didchangeto:))
- [`func quickSwitchManager(CTQuickSwitchManager, didChangeTo: CTQuickSwitchState)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/delegate-swift.protocol/quickswitchmanager(_:didchangeto:))
- [`func quickSwitchManager(CTQuickSwitchManager, didChangeTo: CTQuickSwitchState)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/delegate-swift.protocol/quickswitchmanager(_:didchangeto:))
- [`func getDeviceState((CTQuickSwitchState, (any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/getdevicestate(_:))
- [`func getDeviceState((CTQuickSwitchState, (any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/getdevicestate(_:))
- [`func getPhoneNumberState(forSuffix: String, completion: (CTQuickSwitchState, (any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/getphonenumberstate(forsuffix:completion:))
- [`func getPhoneNumberState(forSuffix: String, completion: (CTQuickSwitchState, (any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/getphonenumberstate(forsuffix:completion:))
- [`class func registerForLaunch(onQuickSwitchStateEvents: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/registerforlaunch(onquickswitchstateevents:))
- [`class func registerForLaunch(onQuickSwitchStateEvents: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/registerforlaunch(onquickswitchstateevents:))
- [`class func unregisterForLaunch(onQuickSwitchStateEvents: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/unregisterforlaunch(onquickswitchstateevents:))
- [`class func unregisterForLaunch(onQuickSwitchStateEvents: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchmanager/unregisterforlaunch(onquickswitchstateevents:))
- [`CTQuickSwitchState`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate)
- [`CTQuickSwitchState`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate)
- [`case active`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate/active)
- [`case active`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate/active)
- [`case failed`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate/failed)
- [`case failed`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate/failed)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate/init(rawvalue:))
- [`case notEnrolled`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate/notenrolled)
- [`case notEnrolled`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate/notenrolled)
- [`case passive`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate/passive)
- [`case passive`](https://developer.apple.com/documentation/coretelephony/ctquickswitchstate/passive)
- [`CTSlicingManager`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager)
- [`func activatePreferredSliceForCategory(CTSlicingManager.AppCategory) async throws`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/activatepreferredsliceforcategory(_:))
- [`var activeSlices: [CTSlicingManager.Slice]`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/activeslices)
- [`CTSlicingManager.AppCategory`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/appcategory)
- [`static var allCases: [CTSlicingManager.AppCategory]`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/appcategory/allcases)
- [`case communication`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/appcategory/communication)
- [`var description: String`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/appcategory/description)
- [`case gaming`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/appcategory/gaming)
- [`case missionCritical`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/appcategory/missioncritical)
- [`case streaming`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/appcategory/streaming)
- [`var availableSliceAppCategories: [CTSlicingManager.AppCategory]`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/availablesliceappcategories)
- [`func disableSlicing() async throws`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/disableslicing())
- [`static let shared: CTSlicingManager`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/shared)
- [`CTSlicingManager.Slice`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/slice)
- [`let appCategory: CTSlicingManager.AppCategory`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/slice/appcategory)
- [`let networkInterfaceName: String`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/slice/networkinterfacename)
- [`let trafficClass: CTSlicingManager.TrafficClass?`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/slice/trafficclass)
- [`CTSlicingManager.TrafficClass`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/trafficclass)
- [`case any`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/trafficclass/any)
- [`case avStreaming`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/trafficclass/avstreaming)
- [`case background`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/trafficclass/background)
- [`var description: String`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/trafficclass/description)
- [`case responsiveAV`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/trafficclass/responsiveav)
- [`case responsiveData`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/trafficclass/responsivedata)
- [`case signaling`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/trafficclass/signaling)
- [`case video`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/trafficclass/video)
- [`case voice`](https://developer.apple.com/documentation/coretelephony/ctslicingmanager/trafficclass/voice)
- [`CTTelephonyNetworkInfo.RadioAccessTechnologyDidChangeMessage`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/radioaccesstechnologydidchangemessage)
- [`var serviceIdentifier: String`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/radioaccesstechnologydidchangemessage/serviceidentifier)

</details>
<!-- /generated:missing -->
