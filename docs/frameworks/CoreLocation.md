# CoreLocation

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 83.0% of Apple's iOS API (409 of 493, exact) · **Rows:** 5: 3 ✅ 2 ❌ · **iOS:** 2.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [CoreLocation](https://developer.apple.com/documentation/corelocation) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Adapted:** a simulated location and routes, isim's own gazetteer for geocoding, and `CLMonitor` state kept in `ISIM_DATA`.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| CoreLocation (`CLLocationManager`, authorization, updates, geocoding) | ✅ | ≤17 | permission alert (Allow Once / While Using / Don't Allow, Always upgrade) remembered per app; simulated location (adapted): Apple Park by default, `ISIM_LOCATION=lat,lon` or a looping route, `location LAT LON`/`location none` script commands; `requestLocation`, `CLLocationUpdate.liveUpdates`, `CLServiceSession`; `CLGeocoder` answers offline from a small built-in gazetteer (other places: `geocodeFoundNoResult`); no heading (like the Simulator); missing usage string: request ignored + logged |
| Region monitoring, beacons, visits | ✅ | ≤17 | `CLCircularRegion` monitoring (enter/exit, `requestState`); `CLMonitor` (iOS 17 actor: circular-geographic and beacon-identity conditions, `events`, records kept in `ISIM_DATA`, 20 conditions); iBeacons from the simulated radio (`beacon UUID MAJOR MINOR [immediate\|near\|far] [RSSI]` script command or `ISIM_BEACONS`): ranging (`startRangingBeacons(satisfying:)` and the deprecated region forms), beacon regions, `CLBeaconRegion.peripheralData`; `CLVisit` arrivals and departures detected from the simulated location (adapted: a stay within 50 m for `ISIM_VISIT_SECONDS`, default 120 s). Tested (`test_location.py`: circular regions, `test_beacons_visits_monitor`) |
| Objective-C interface (`CoreLocation.framework`): `CLLocationManager` (authorization, updates, heading, visits, region monitoring), `CLLocationManagerDelegate`, `CLLocation`, `CLHeading`, `CLVisit`, `CLRegion` / `CLCircularRegion`, `CLPlacemark`, `CLGeocoder`, `CLLocationCoordinate2D` and its functions, the accuracy constants, `kCLErrorDomain` | ✅ | ≤17 | adapted: headers over the Swift overlay's classes (Apple's Objective-C names); `CLLocationCoordinate2D` members are Objective-C categories over the overlay (it is a Swift struct there). The delegate's selectors are now Apple's (`locationManager:didChangeAuthorizationStatus:`, `...forRegion:` ...); Swift apps built with 0.22 or earlier still get their delegate calls under Swift's selectors. Not from Objective-C yet: beacons, `CLMonitor`. Tested (HelloPersonalObjC, tests/ui/test_personal_objc.py) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `CLLocationPushServiceError`, `CLLocationPushServiceError.Code`, `CLLocationPushServiceExtension` (3 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 27) | ❌ | 27.0 | not implemented, found by the 2026-10 sweep: `CLBodyIdentifiable` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
84 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var CL_TARGET_SUPPORTS_CONDITIONS: Int32`](https://developer.apple.com/documentation/corelocation/cl_target_supports_conditions)
- [`case maritime`](https://developer.apple.com/documentation/corelocation/clactivitytype/maritime)
- [`CLBackgroundActivitySession.Diagnostic`](https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3/diagnostic)
- [`var authorizationDenied: Bool`](https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3/diagnostic/authorizationdenied)
- [`var authorizationDeniedGlobally: Bool`](https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3/diagnostic/authorizationdeniedglobally)
- [`var authorizationRequestInProgress: Bool`](https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3/diagnostic/authorizationrequestinprogress)
- [`var authorizationRestricted: Bool`](https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3/diagnostic/authorizationrestricted)
- [`var insufficientlyInUse: Bool`](https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3/diagnostic/insufficientlyinuse)
- [`var serviceSessionRequired: Bool`](https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3/diagnostic/servicesessionrequired)
- [`CLBackgroundActivitySession.Diagnostics`](https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3/diagnostics-swift.class)
- [`CLBackgroundActivitySession.Diagnostics.Iterator`](https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3/diagnostics-swift.class/iterator)
- [`var diagnostics: CLBackgroundActivitySession.Diagnostics`](https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3/diagnostics-swift.property)
- [`CLBodyIdentifiable`](https://developer.apple.com/documentation/corelocation/clbodyidentifiable)
- [`CLBodyIdentifiable`](https://developer.apple.com/documentation/corelocation/clbodyidentifiable)
- [`CLBodyIdentifiable`](https://developer.apple.com/documentation/corelocation/clbodyidentifiable)
- [`var alternateRegion: CLRegion?`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/alternateregion)
- [`static var deferredAccuracyTooLow: CLError.Code`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/deferredaccuracytoolow)
- [`static var deferredCanceled: CLError.Code`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/deferredcanceled)
- [`static var deferredDistanceFiltered: CLError.Code`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/deferreddistancefiltered)
- [`static var deferredFailed: CLError.Code`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/deferredfailed)
- [`static var deferredNotUpdatingLocation: CLError.Code`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/deferrednotupdatinglocation)
- [`static var geocodeFoundPartialResult: CLError.Code`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/geocodefoundpartialresult)
- [`static var historicalLocationError: CLError.Code`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/historicallocationerror)
- [`static var rangingFailure: CLError.Code`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/rangingfailure)
- [`static var rangingUnavailable: CLError.Code`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/rangingunavailable)
- [`static var regionMonitoringResponseDelayed: CLError.Code`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/regionmonitoringresponsedelayed)
- [`static var regionMonitoringSetupDelayed: CLError.Code`](https://developer.apple.com/documentation/corelocation/clerror-swift.struct/regionmonitoringsetupdelayed)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/corelocation/clfloor/init(coder:))
- [`CLGeocodeCompletionHandler`](https://developer.apple.com/documentation/corelocation/clgeocodecompletionhandler)
- [`func geocodePostalAddress(CNPostalAddress, completionHandler: ([CLPlacemark]?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/corelocation/clgeocoder/geocodepostaladdress(_:completionhandler:))
- [`func geocodePostalAddress(CNPostalAddress, preferredLocale: Locale?, completionHandler: ([CLPlacemark]?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/corelocation/clgeocoder/geocodepostaladdress(_:preferredlocale:completionhandler:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/corelocation/clheading/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/corelocation/cllocation/init(coder:))
- [`var headingBody: (any CLBodyIdentifiable)?`](https://developer.apple.com/documentation/corelocation/cllocationmanager/headingbody)
- [`var headingBody: (any CLBodyIdentifiable)?`](https://developer.apple.com/documentation/corelocation/cllocationmanager/headingbody)
- [`var headingBody: (any CLBodyIdentifiable)?`](https://developer.apple.com/documentation/corelocation/cllocationmanager/headingbody)
- [`func startMonitoringLocationPushes(completion: ((Data?, (any Error)?) -> Void)?)`](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringlocationpushes(completion:))
- [`func stopMonitoringLocationPushes()`](https://developer.apple.com/documentation/corelocation/cllocationmanager/stopmonitoringlocationpushes())
- [`CLLocationPushServiceError`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct)
- [`CLLocationPushServiceError.Code`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code)
- [`CLLocationPushServiceError.Code`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/init(rawvalue:))
- [`case missingEntitlement`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/missingentitlement)
- [`case missingEntitlement`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/missingentitlement)
- [`case missingPushExtension`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/missingpushextension)
- [`case missingPushExtension`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/missingpushextension)
- [`case missingPushServerEnvironment`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/missingpushserverenvironment)
- [`case missingPushServerEnvironment`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/missingpushserverenvironment)
- [`case unknown`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/unknown)
- [`case unknown`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/unknown)
- [`case unsupportedPlatform`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/unsupportedplatform)
- [`case unsupportedPlatform`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/code/unsupportedplatform)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/errordomain)
- [`static var missingEntitlement: CLLocationPushServiceError.Code`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/missingentitlement)
- [`static var missingPushExtension: CLLocationPushServiceError.Code`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/missingpushextension)
- [`static var missingPushServerEnvironment: CLLocationPushServiceError.Code`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/missingpushserverenvironment)
- [`static var unknown: CLLocationPushServiceError.Code`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/unknown)
- [`static var unsupportedPlatform: CLLocationPushServiceError.Code`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerror-swift.struct/unsupportedplatform)
- [`let CLLocationPushServiceErrorDomain: String`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceerrordomain)
- [`CLLocationPushServiceExtension`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceextension)
- [`func didReceiveLocationPushPayload([String : Any], completion: () -> Void)`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceextension/didreceivelocationpushpayload(_:completion:))
- [`func serviceExtensionWillTerminate()`](https://developer.apple.com/documentation/corelocation/cllocationpushserviceextension/serviceextensionwillterminate())
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/corelocation/cllocationsourceinformation/init(coder:))
- [`case maritime`](https://developer.apple.com/documentation/corelocation/cllocationupdate/liveconfiguration/maritime)
- [`static var defaultResolverSpecification: EmptyResolverSpecification<CLPlacemark>`](https://developer.apple.com/documentation/corelocation/clplacemark/defaultresolverspecification)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/corelocation/clplacemark/init(coder:))
- [`var postalAddress: CNPostalAddress?`](https://developer.apple.com/documentation/corelocation/clplacemark/postaladdress)
- [`CLPlacemark.Specification`](https://developer.apple.com/documentation/corelocation/clplacemark/specification)
- [`CLPlacemark.UnwrappedType`](https://developer.apple.com/documentation/corelocation/clplacemark/unwrappedtype)
- [`CLPlacemark.ValueType`](https://developer.apple.com/documentation/corelocation/clplacemark/valuetype)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/corelocation/clregion/init(coder:))
- [`CLServiceSession.Diagnostic`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostic)
- [`var alwaysAuthorizationDenied: Bool`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostic/alwaysauthorizationdenied)
- [`var authorizationDenied: Bool`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostic/authorizationdenied)
- [`var authorizationDeniedGlobally: Bool`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostic/authorizationdeniedglobally)
- [`var authorizationRequestInProgress: Bool`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostic/authorizationrequestinprogress)
- [`var authorizationRestricted: Bool`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostic/authorizationrestricted)
- [`var fullAccuracyDenied: Bool`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostic/fullaccuracydenied)
- [`var insufficientlyInUse: Bool`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostic/insufficientlyinuse)
- [`var serviceSessionRequired: Bool`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostic/servicesessionrequired)
- [`CLServiceSession.Diagnostics`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostics-swift.class)
- [`CLServiceSession.Diagnostics.Iterator`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostics-swift.class/iterator)
- [`var diagnostics: CLServiceSession.Diagnostics`](https://developer.apple.com/documentation/corelocation/clservicesession-pt7n/diagnostics-swift.property)

</details>
<!-- /generated:missing -->
