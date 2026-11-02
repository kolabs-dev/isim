# CarPlay

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 99.1% of Apple's iOS API (1257 of 1269, exact) · **Rows:** 16: 11 ✅ 5 🟡 · **iOS:** 12.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [CarPlay](https://developer.apple.com/documentation/carplay) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted (`isim/swift/overlays/CarPlay`). A simulated CarPlay screen draws the app's templates:
  - the script command `carplay connect [WxH[@S]]` connects it (800x480 at scale 2 by default) to the running app. The
    app needs a CarPlay entitlement: audio, communication, maps, EV charging, fueling, parking, quick food ordering,
    driving task, public safety or voice-based conversation. Without one, CarPlay does not show the app;
  - the scene manifest's `CPTemplateApplicationSceneSessionRoleApplication` configuration connects a
    `CPTemplateApplicationScene`. Its delegate gets the `CPInterfaceController`, and a navigation app also gets the
    `CPWindow` its map draws in. Apps with only iOS 12's `CPApplicationDelegate` get the same;
  - isim draws the templates in CarPlay's style, on a window of the CarPlay screen that never appears on the device
    (`Screen.swift`, `Views.swift`):
    - CarPlay's status bar on the leading edge: the time, the signal, the app, the home button;
    - the navigation bar, the template and the tab bar, with presented alerts and action sheets over them;
    - for a navigation app, its CPWindow under the map template's buttons, trip previews, guidance card, estimates,
      navigation alerts and panels;
  - each app category may use only its own templates. Another raises `NSInvalidArgumentException`, as on iOS;
  - the stack is at most 5 templates deep (a deeper push fails with an error);
  - Now Playing shows MPNowPlayingInfoCenter's info, and its buttons send the app's MPRemoteCommandCenter commands;
  - `carplay tap|taptext|back|scroll|search|pan|dump|shot` drive and read the screen. `carplay style|limit|park` set
    the car's content style, limited user interfaces and parked state. All are in SCRIPTING.md.
- **Objective-C / C interface:** `isim/sdk-src/Frameworks/CarPlay/CarPlay.h` over the overlay's `@objc` classes, with
  Apple's selectors (`setEnabled:`, `sharedTemplate`, …), the constants and the `NSStringFromCP…` functions.
  Swift only in isim:
  - `CPPlaybackConfiguration`'s times (`CMTime` is a Swift struct in isim's CoreMedia);
  - `CPPointOfInterestTemplateDelegate` (`MKCoordinateRegion` is one in isim's MapKit).
- **Versus Apple's Simulator:**
  - Apple's Simulator shows CarPlay in a window of its own (I/O > External Displays > CarPlay). isim's CarPlay screen
    is read with `carplay shot` and driven with `carplay tap`; it has no window of its own yet;
  - the dashboard and instrument cluster scenes connect, but isim's car has no display to draw them on.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `CPTemplateApplicationScene`, `CPTemplateApplicationSceneDelegate`, `CPWindow`, `UISceneSession.Role.carTemplateApplication` | ✅ | ≤17 | adapted: connected by `carplay connect`; tested (HelloCarPlay, test_carplay_audio, test_carplay_navigation) |
| `CPInterfaceController` (root, push, pop, pop to, present, dismiss, the async forms, `carTraitCollection`, the delegate) | ✅ | ≤17 | adapted: the category's templates, a stack of at most 5; tested (HelloCarPlay, test_carplay_audio) |
| `CPListTemplate`, `CPListSection`, `CPListItem`, `CPListImageRowItem`, `CPAssistantCellConfiguration`, `CPMessageListItem` | ✅ | ≤17 | adapted: drawn and selectable, the handler's completion; tested (HelloCarPlay, test_carplay_audio) |
| `CPGridTemplate`, `CPGridButton`, `CPTabBarTemplate` | ✅ | ≤17 | adapted; tested (HelloCarPlay, test_carplay_audio) |
| `CPNowPlayingTemplate` (`shared`, the buttons, Up Next, album artist, observers) | ✅ | ≤17 | adapted: MPNowPlayingInfoCenter's info, MPRemoteCommandCenter's commands; tested (HelloCarPlay, test_carplay_audio) |
| `CPAlertTemplate`, `CPActionSheetTemplate`, `CPAlertAction`, `CPBarButton`, `CPButton`, `CPTextButton` | ✅ | ≤17 | adapted; tested (HelloCarPlay, test_carplay_audio) |
| `CPMapTemplate` (bar buttons, map buttons, trip previews, estimates, panning, the delegate) | ✅ | ≤17 | adapted: over the app's CPWindow; tested (HelloCarPlay's navigation app, test_carplay_navigation) |
| `CPTrip`, `CPRouteChoice`, `CPTravelEstimates`, `CPTripPreviewTextConfiguration`, `CPMapButton` | ✅ | ≤17 | adapted; tested (HelloCarPlay's navigation app, test_carplay_navigation) |
| `CPNavigationSession`, `CPManeuver`, `CPNavigationAlert` | ✅ | ≤17 | adapted: the guidance card, the trip's estimates and End, alerts with their actions; tested (HelloCarPlay's navigation app, test_carplay_navigation) |
| `CPSearchTemplate` | ✅ | ≤17 | adapted: `carplay search TEXT` types the text, the results list; tested (HelloCarPlay's navigation app, test_carplay_navigation) |
| `CPLane`, `CPLaneGuidance`, `CPRouteInformation`, `CPManeuverType`, `CPJunctionType`, `CPTrafficSide` | 🟡 | 17.4 | adapted: kept and shown in the guidance card's symbol, lanes not drawn; proposed |
| `CPInformationTemplate`, `CPPointOfInterestTemplate`, `CPContactTemplate`, `CPVoiceControlTemplate` | 🟡 | ≤17 | adapted: drawn and tappable; proposed |
| `CPSessionConfiguration` | 🟡 | ≤17 | adapted: `carplay style`, `carplay limit`; proposed |
| `CPDashboardController`, `CPTemplateApplicationDashboardScene`, `CPInstrumentClusterController`, `CPTemplateApplicationInstrumentClusterScene` | 🟡 | ≤17 | adapted: the scenes connect, nothing draws them; proposed |
| the iOS 26 additions (`CPListImageRowItem` elements, `CPListTemplateDetailsHeader`, `CPThumbnailImage`, sports modes, `CPMapPanel`, `CPRouteSegment`, `CPNavigationWaypoint`, `CPRouteDetail`) | 🟡 | 26.0 | adapted: kept and drawn in simple forms; proposed |
| Objective-C interface (`CarPlay.h`) | ✅ | ≤17 | adapted: the overlay's classes with Apple's selectors; tested (HelloServicesObjC, test_services_objc) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
12 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`CPBarButton.Type`](https://developer.apple.com/documentation/carplay/cpbarbutton/type)
- [`case image`](https://developer.apple.com/documentation/carplay/cpbarbutton/type/image)
- [`init?(rawValue: UInt)`](https://developer.apple.com/documentation/carplay/cpbarbutton/type/init(rawvalue:))
- [`case text`](https://developer.apple.com/documentation/carplay/cpbarbutton/type/text)
- [`func panelDidHide(CPMapPanel)`](https://developer.apple.com/documentation/carplay/cpmappanel/delegate-swift.protocol/paneldidhide(_:))
- [`func panelDidShow(CPMapPanel)`](https://developer.apple.com/documentation/carplay/cpmappanel/delegate-swift.protocol/paneldidshow(_:))
- [`static var down: CPMapTemplate.PanDirection`](https://developer.apple.com/documentation/carplay/cpmaptemplate/pandirection/down)
- [`init(rawValue: Int)`](https://developer.apple.com/documentation/carplay/cpmaptemplate/pandirection/init(rawvalue:))
- [`static var left: CPMapTemplate.PanDirection`](https://developer.apple.com/documentation/carplay/cpmaptemplate/pandirection/left)
- [`static var right: CPMapTemplate.PanDirection`](https://developer.apple.com/documentation/carplay/cpmaptemplate/pandirection/right)
- [`static var up: CPMapTemplate.PanDirection`](https://developer.apple.com/documentation/carplay/cpmaptemplate/pandirection/up)
- [`var entryPoints: [CPLocationCoordinate3D]`](https://developer.apple.com/documentation/carplay/cpnavigationwaypoint/entrypoints-obhb)

</details>
<!-- /generated:missing -->
