# TipKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (391 of 391, exact) · **Rows:** 10: 10 ✅ · **iOS:** 17.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [TipKit](https://developer.apple.com/documentation/tipkit) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted. isim's own Swift overlay (`isim/swift/overlays/TipKit`) evaluates the tips' rules and keeps
  the datastore; isim's SwiftUI draws the tips. The `#Rule` and `@Parameter` macros come from isim's `TipKitMacros`
  compiler plugin (`isim/swift/macro-support/TipKitMacros.swift`). The plugin keeps a rule's predicate a Swift closure;
  Apple's turns it into a Foundation `Predicate`.
- **Objective-C / C interface:** Swift only, as on iOS.
- **Versus Apple's Simulator:** the same eligibility. The datastore sits in the app's container (`Library/Application
  Support/TipKit/Tips.plist`), so a scratch `ISIM_DATA` starts with no tips seen. CloudKit sync is not simulated.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Datastore: `Tips.configure(_:)`, `Tips.ConfigurationOption` (`datastoreLocation(_:)`: `.applicationDefault`, `.groupContainer(identifier:)`, `.url(_:)`; `displayFrequency(_:)`: `.immediate` … `.monthly`; `cloudKitContainer(_:)`), `Tips.resetDatastore()`, `TipKitError` | ✅ | 17.0 | adapted: a property list in the app's container (or the app group's, or the URL's) keeps the parameters, the events' donations and each tip's state (first shown, display count, time on screen, invalidation). A second `configure` throws `tipsDatastoreAlreadyConfigured`; a group container without its entitlement throws `missingGroupContainerEntitlements`. The CloudKit container is accepted, but nothing syncs. Tested (HelloTips: test_tips, per iOS version) |
| `Tip` (`id`, `title`, `message`, `image`, `rules`, `options`, `actions`, `status`, `statusUpdates`, `shouldDisplay`, `shouldDisplayUpdates`, `invalidate(reason:)`, `resetEligibility()`), `AnyTip`, `Tips.Status`, `Tips.InvalidationReason` | ✅ | 17.0 | adapted: a tip is available when the datastore is configured, it is not invalidated, all its rules hold, its options allow it, and (for a tip not shown yet) the display frequency has passed since another tip first appeared. Closing a tip invalidates it with `.tipClosed`; the status updates stream yields each change. Tested (HelloTips: test_tips, test_display_frequency) |
| Rules and parameters: `#Rule(_:_:)`, `@Parameter` (`Tips.Parameter`, `Tips.ParameterOption.transient`), `Tips.Rule` | ✅ | 17.0 | adapted: `#Rule(Self.$param) { $0 == true }` reads the parameter's value; `#Rule(Self.event) { $0.donations.donatedWithin(.week).count >= 3 }` reads the event. Parameters are kept in the datastore (`.transient`: in memory). Tested (HelloTips: test_tips) |
| Events: `Tips.Event` (`init(id:)`, `init(id:donationLimit:)`, `donations`, `donate()`, `donate(_:)`, `sendDonation(_:)` (iOS 18), `deleteDonations()`), `Tips.Event.Donation` (`date`, the donation info's members), `Tips.DonationLimit`, `Tips.DonationTimeRange`, `Tips.EmptyDonation`, `donatedWithin(_:)` | ✅ | 17.0 | adapted: donations are kept with their date and info, within the limit's count and age. Tested (HelloTips: test_tips) |
| Options: `Tips.MaxDisplayCount`, `Tips.MaxDisplayDuration`, `Tips.IgnoresDisplayFrequency` | ✅ | 17.0 | adapted: a tip shown its maximum number of times, or for its maximum time on screen, is invalidated (`.displayCountExceeded`, `.displayDurationExceeded`); `IgnoresDisplayFrequency(true)` shows a new tip without waiting for the display frequency. Tested (HelloTips: test_display_frequency) |
| Testing: `Tips.showAllTipsForTesting()`, `showTipsForTesting(_:)`, `hideAllTipsForTesting()`, `hideTipsForTesting(_:)` | ✅ | 17.0 | adapted: shown or hidden whatever their rules say |
| `TipView` (`init(_:arrowEdge:action:)`, `init(_:isPresented:arrowEdge:action:)`, `init(_:isPresented:arrowEdge:anchorID:action:)` (iOS 26)), `View.popoverTip(_:arrowEdge:action:)` and its `isPresented:attachmentAnchor:` variants (iOS 18), `tipAnchor(_:)` (iOS 26) | ✅ | 17.0 | adapted: drawn like iOS's. The image (36 pt) is in the accent colour beside the title (headline) and message (secondary), with a close button (xmark) and the actions below dividers, on the grouped background colour (in a List, the row is the card). A popover tip is a popover with an arrow, also on iPhone. A tap outside it closes it, and the tap does nothing else. iOS 26: rounder corners. A view counts each appearance and its time on screen. Accessibility identifiers: `tip-ID` (the title), `tipclose-ID`, `tipaction-ID-ACTION`. `anchorID` / `tipAnchor`: the tip shows inline rather than pointing at the anchor. Tested (HelloTips: test_tips, per iOS version) |
| `TipGroup` (`init(_:_:)`, `Priority` `.firstAvailable` / `.ordered`, `currentTip`, `currentTipUpdates`) | ✅ | 18.0 | adapted: `.firstAvailable` gives the first available tip; `.ordered` gives the first tip not invalidated, once it is available. Tested (HelloTips: test_tip_group_and_uikit) |
| Styling: `TipViewStyle`, `TipViewStyleConfiguration`, `MiniTipViewStyle` (`.miniTip`), `tipViewStyle(_:)`, `tipBackground(_:)`, `tipCornerRadius(_:antialiased:)`, `tipImageSize(_:)`, `tipImageStyle(_:)` (1–3 styles), `tipBackgroundInteraction(_:)` (iOS 18) | ✅ | 17.0 | adapted: through the environment, to the tip views below them |
| UIKit: `TipUIView`, `TipUIPopoverViewController`, `TipUICollectionViewCell`, `TipUICollectionReusableView` (`configureTip(_:arrowEdge:actionHandler:)`; `backgroundColor`, `backgroundStyle`, `cornerRadius`, `imageSize`, `imageStyle`, `viewStyle`) | ✅ | 17.0 | adapted: SwiftUI tip views hosted in UIKit. The popover controller stays a popover in compact widths (its presentation delegate declines adaptation, unless the app sets `presentationDelegate`). Tested (HelloTips: test_tip_group_and_uikit) |

`TipNSView` and `TipNSPopover` are macOS-only.

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
