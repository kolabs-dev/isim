# isim API coverage

This tracks how much of the iOS SDK isim covers (iOS 17, 18, 26 and 27, selected with `--os`), so you can follow progress as features land.
It lists what an app developer reaches for, including everything isim does **not** have yet. Statuses come from
reading isim's headers (`isim/sdk-src`), implementations (`isim/frameworks`, `isim/swift/overlays`) and their comments, not from guesses.

Last updated: 2026-10-07

**Legend**

| Mark | Meaning |
|---|---|
| ✅ | Implemented: works like iOS for normal use |
| 🟡 | Partial: exists but simplified or missing notable behaviour (the note says what) |
| 🧩 | Stub: the API exists so apps compile and run, but it does nothing real |
| ❌ | Missing: not in isim yet (code using it does not compile, or aborts at run time) |

"Unverified" in a note means the code exists but no isim test exercises that behaviour.
Coverage % = (✅ + 0.5 × 🟡) / all rows in that area. Stubs count as zero.
The **iOS** column is the version that introduced the API (`≤17`: iOS 17 or earlier). The per-version summary counts a row
toward iOS N when it was introduced at or before N, so newer versions add their rows (mostly still ❌).

## Summary

| Area | ✅ | 🟡 | 🧩 | ❌ | Rows | Coverage |
|---|---:|---:|---:|---:|---:|---:|
| **UIKit** | 130 | 57 | 10 | 18 | 215 | 74% |
| &nbsp;&nbsp;↳ Application & scenes | 10 | 8 | 5 | 1 | 24 | 58% |
| &nbsp;&nbsp;↳ View controllers & presentation | 19 | 9 | 0 | 3 | 31 | 76% |
| &nbsp;&nbsp;↳ Views & controls | 33 | 17 | 2 | 8 | 60 | 69% |
| &nbsp;&nbsp;↳ Layout | 16 | 2 | 0 | 1 | 19 | 89% |
| &nbsp;&nbsp;↳ Animation | 8 | 4 | 0 | 0 | 12 | 83% |
| &nbsp;&nbsp;↳ Gestures & touches | 11 | 2 | 0 | 0 | 13 | 92% |
| &nbsp;&nbsp;↳ Text input & keyboard | 9 | 3 | 2 | 0 | 14 | 75% |
| &nbsp;&nbsp;↳ Drawing, images & symbols | 14 | 3 | 0 | 2 | 19 | 82% |
| &nbsp;&nbsp;↳ Haptics & feedback | 2 | 0 | 1 | 0 | 3 | 67% |
| &nbsp;&nbsp;↳ Accessibility | 4 | 3 | 0 | 0 | 7 | 79% |
| &nbsp;&nbsp;↳ Drag & drop | 1 | 2 | 0 | 0 | 3 | 67% |
| &nbsp;&nbsp;↳ Appearance & dark mode | 3 | 4 | 0 | 3 | 10 | 50% |
| **SwiftUI** | 152 | 57 | 16 | 12 | 237 | 76% |
| &nbsp;&nbsp;↳ App & scenes | 6 | 4 | 0 | 1 | 11 | 73% |
| &nbsp;&nbsp;↳ State & data flow | 15 | 2 | 0 | 0 | 17 | 94% |
| &nbsp;&nbsp;↳ Views & controls | 31 | 8 | 0 | 0 | 39 | 90% |
| &nbsp;&nbsp;↳ Containers & layout | 18 | 8 | 1 | 1 | 28 | 79% |
| &nbsp;&nbsp;↳ Navigation & presentation | 14 | 13 | 6 | 4 | 37 | 55% |
| &nbsp;&nbsp;↳ Modifiers & visual effects | 17 | 8 | 7 | 2 | 34 | 62% |
| &nbsp;&nbsp;↳ Shapes, paths, gradients & materials | 18 | 3 | 0 | 3 | 24 | 81% |
| &nbsp;&nbsp;↳ Animation | 7 | 3 | 1 | 0 | 11 | 77% |
| &nbsp;&nbsp;↳ Gestures | 6 | 1 | 0 | 1 | 8 | 81% |
| &nbsp;&nbsp;↳ Lifecycle, async & events | 6 | 2 | 0 | 0 | 8 | 88% |
| &nbsp;&nbsp;↳ Focus & keyboard | 2 | 1 | 1 | 0 | 4 | 62% |
| &nbsp;&nbsp;↳ Environment values | 5 | 2 | 0 | 0 | 7 | 86% |
| &nbsp;&nbsp;↳ Accessibility | 3 | 2 | 0 | 0 | 5 | 80% |
| &nbsp;&nbsp;↳ UIKit interop | 4 | 0 | 0 | 0 | 4 | 100% |
| Swift Charts | 12 | 2 | 0 | 2 | 16 | 81% |
| **Foundation** | 57 | 22 | 1 | 1 | 81 | 84% |
| &nbsp;&nbsp;↳ Strings & text | 10 | 5 | 0 | 0 | 15 | 83% |
| &nbsp;&nbsp;↳ Collections & values | 9 | 3 | 0 | 0 | 12 | 88% |
| &nbsp;&nbsp;↳ Encoding & serialization | 8 | 0 | 0 | 0 | 8 | 100% |
| &nbsp;&nbsp;↳ Dates, calendars & formatters | 5 | 6 | 0 | 0 | 11 | 73% |
| &nbsp;&nbsp;↳ Files, bundles & preferences | 6 | 3 | 0 | 0 | 9 | 83% |
| &nbsp;&nbsp;↳ Notifications, timers & threads | 7 | 2 | 0 | 0 | 9 | 89% |
| &nbsp;&nbsp;↳ Networking | 12 | 3 | 1 | 1 | 17 | 79% |
| **Swift runtime, stdlib & concurrency** | 35 | 4 | 0 | 0 | 39 | 95% |
| &nbsp;&nbsp;↳ Combine | 14 | 0 | 0 | 0 | 14 | 100% |
| &nbsp;&nbsp;↳ Dispatch | 4 | 2 | 0 | 0 | 6 | 83% |
| Objective-C runtime & C library | 14 | 3 | 0 | 0 | 17 | 91% |
| Core Graphics | 16 | 6 | 0 | 0 | 22 | 86% |
| Core Text | 4 | 3 | 0 | 0 | 7 | 79% |
| QuartzCore / Core Animation | 15 | 5 | 1 | 0 | 21 | 83% |
| Core Image, ImageIO & Metal | 2 | 1 | 0 | 2 | 5 | 50% |
| SpriteKit | 22 | 18 | 5 | 1 | 46 | 67% |
| GameKit (Game Center) | 10 | 4 | 3 | 1 | 18 | 67% |
| GameController, GameplayKit, SceneKit, RealityKit & ARKit | 13 | 8 | 1 | 4 | 26 | 65% |
| AVFoundation & audio | 19 | 19 | 3 | 3 | 44 | 65% |
| Photos, Vision, Core ML & camera | 5 | 7 | 2 | 0 | 14 | 61% |
| StoreKit | 20 | 9 | 0 | 0 | 29 | 84% |
| Ads & privacy (AppTrackingTransparency, Google Mobile Ads, UMP) | 2 | 0 | 3 | 1 | 6 | 33% |
| Data & persistence | 14 | 6 | 0 | 3 | 23 | 74% |
| Identity & security | 9 | 2 | 2 | 0 | 13 | 77% |
| Notifications & background work | 8 | 3 | 0 | 1 | 12 | 79% |
| App extensions & system integration | 3 | 3 | 0 | 3 | 9 | 50% |
| Location & maps | 2 | 5 | 0 | 0 | 7 | 64% |
| Personal data & device sensors | 4 | 2 | 0 | 0 | 6 | 83% |
| Web & communication | 8 | 6 | 0 | 2 | 16 | 69% |
| Logging & diagnostics | 5 | 1 | 2 | 1 | 9 | 61% |
| Platform & tooling | 31 | 15 | 1 | 4 | 51 | 75% |
| **All areas** | **612** | **268** | **50** | **59** | **989** | **75%** |

### Per iOS version

Coverage of the APIs each version has: a row counts toward iOS N when it was introduced at or before N (rows in parentheses).

| Area | iOS 17 | iOS 18 | iOS 26 | iOS 27 |
|---|---:|---:|---:|---:|
| UIKit | 78% (201) | 77% (204) | 75% (211) | 74% (215) |
| SwiftUI | 82% (214) | 80% (220) | 79% (227) | 76% (237) |
| Swift Charts | 87% (15) | 81% (16) | 81% (16) | 81% (16) |
| Foundation | 84% (81) | 84% (81) | 84% (81) | 84% (81) |
| Swift runtime, stdlib & concurrency | 95% (39) | 95% (39) | 95% (39) | 95% (39) |
| Objective-C runtime & C library | 91% (17) | 91% (17) | 91% (17) | 91% (17) |
| Core Graphics | 86% (22) | 86% (22) | 86% (22) | 86% (22) |
| Core Text | 79% (7) | 79% (7) | 79% (7) | 79% (7) |
| QuartzCore / Core Animation | 83% (21) | 83% (21) | 83% (21) | 83% (21) |
| Core Image, ImageIO & Metal | 50% (5) | 50% (5) | 50% (5) | 50% (5) |
| SpriteKit | 67% (46) | 67% (46) | 67% (46) | 67% (46) |
| GameKit (Game Center) | 71% (17) | 71% (17) | 67% (18) | 67% (18) |
| GameController, GameplayKit, SceneKit, RealityKit & ARKit | 65% (26) | 65% (26) | 65% (26) | 65% (26) |
| AVFoundation & audio | 65% (44) | 65% (44) | 65% (44) | 65% (44) |
| Photos, Vision, Core ML & camera | 61% (14) | 61% (14) | 61% (14) | 61% (14) |
| StoreKit | 84% (29) | 84% (29) | 84% (29) | 84% (29) |
| Ads & privacy (AppTrackingTransparency, Google Mobile Ads, UMP) | 33% (6) | 33% (6) | 33% (6) | 33% (6) |
| Data & persistence | 74% (23) | 74% (23) | 74% (23) | 74% (23) |
| Identity & security | 77% (13) | 77% (13) | 77% (13) | 77% (13) |
| Notifications & background work | 79% (12) | 79% (12) | 79% (12) | 79% (12) |
| App extensions & system integration | 50% (9) | 50% (9) | 50% (9) | 50% (9) |
| Location & maps | 64% (7) | 64% (7) | 64% (7) | 64% (7) |
| Personal data & device sensors | 83% (6) | 83% (6) | 83% (6) | 83% (6) |
| Web & communication | 73% (15) | 73% (15) | 69% (16) | 69% (16) |
| Logging & diagnostics | 61% (9) | 61% (9) | 61% (9) | 61% (9) |
| Platform & tooling | 77% (49) | 76% (50) | 75% (51) | 75% (51) |
| **All areas** | **78%** (947) | **77%** (958) | **76%** (975) | **75%** (989) |

---

## UIKit

### Application & scenes

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `UIApplicationMain`, `@main` app delegate | ✅ | ≤17 | Xcode App template lifecycle |
| `UIApplicationDelegate` launch/active/background/terminate callbacks | ✅ | ≤17 | apps background and resume from the home screen |
| Scene manifest, `UIWindowSceneDelegate`, `UIWindowScene` | ✅ | ≤17 | one scene per app |
| `UIView.drawHierarchy(in:afterScreenUpdates:)` | 🟡 | ≤17 | draws the view tree into the current image context (used for widget rendering; tested through HelloWidgets) |
| Multiple scenes / windows (iPad multi-window, `requestSceneSessionActivation`) | ❌ | ≤17 | `supportsMultipleScenes` exists; only one scene is ever created; `requestSceneSessionActivation` logs and calls the error handler (stub) |
| `UIWindow` (`makeKeyAndVisible`, `rootViewController`, `windowLevel`) | ✅ | ≤17 | |
| `UIScreen.main` (bounds, scale, nativeBounds, maximumFramesPerSecond) | ✅ | ≤17 | per-device presets |
| `UIScreen.brightness` | 🧩 | ≤17 | stored only |
| `UIDevice` (name, model, systemVersion, userInterfaceIdiom) | 🟡 | ≤17 | systemVersion is the emulated API level (`ISIM_OS_VERSION`, default 18.0) |
| Device orientation, rotation, `supportedInterfaceOrientations` | ✅ | ≤17 | Ctrl+Left/Right or script `rotate`; Info.plist/delegate/VC masks (containers use their visible child; no plist key = portrait, adapted), `requestGeometryUpdate`, device notifications, landscape screen through the shell; tested (HelloRotation) |
| Application/scene lifecycle notifications (`didBecomeActiveNotification`, …) | ✅ | ≤17 | |
| `open(_:options:)` / `canOpenURL` | 🟡 | ≤17 | URLs of installed apps' schemes and universal links open those apps through the home screen (`universalLinksOnly` honoured), `canOpenURL` sees installed schemes (tested, HelloSystem); `app-settings:` opens Settings; other http(s)/mailto open on the host only with `ISIM_OPEN_URLS=1` |
| Incoming URLs (custom URL schemes, `application(_:open:)`, scene URL contexts) | ✅ | ≤17 | `CFBundleURLTypes` routing (script `openurl URL`, other apps' `open`), `scene(_:openURLContexts:)` and `connectionOptions.urlContexts` on cold launch, `application(_:open:options:)` for apps without scenes, SwiftUI `onOpenURL`. Tested (HelloSystem) |
| Universal links, `NSUserActivity`, Handoff | 🟡 | ≤17 | adapted: one `NSUserActivity` (Foundation): `becomeCurrent` indexes `isEligibleForSearch` activities for the home screen's Spotlight; continuing one calls `scene(_:continue:)` / `application(_:continue:restorationHandler:)` (or `connectionOptions.userActivities` / launch options on a cold launch) and SwiftUI `onContinueUserActivity` (else `onOpenURL`). Universal links: `applinks:` domains (incl. `*.` wildcards, `?mode=`) from the app's archived-expanded-entitlements.xcent (written by `isim build` from `CODE_SIGN_ENTITLEMENTS`); `openurl https://…` (script, or `isim openurl` with `--control`) — under `isim boot` the home screen opens the app that claims the domain (also for `UIApplication.open` from other apps), with `isim run` the running app gets links of its own domains, other web URLs "open in Safari" (logged). No AASA fetch (all paths match), no Handoff. Tested (HelloSystem, HelloSafari, HelloScenes) |
| `applicationIconBadgeNumber` | 🧩 | ≤17 | stored; no badge on the home-screen icon |
| `isIdleTimerDisabled` | 🧩 | ≤17 | stored; the device never locks by itself (lock: Ctrl+L / script `lock`) |
| Status bar (`prefersStatusBarHidden`, `preferredStatusBarStyle`) | 🟡 | ≤17 | hide works (SwiftUI `statusBarHidden`); style/appearance updates unverified |
| `beginBackgroundTask`, background fetch/modes | 🟡 | ≤17 | adapted: isim does not suspend apps; `beginBackgroundTask(withName:expirationHandler:)` / `endBackgroundTask` / `backgroundTimeRemaining` with expiration after `ISIM_BACKGROUND_TASK_SECONDS` (30) in the background; apps launched into the background (BackgroundTasks) get `.background` state and connect their scene on first foreground. Background fetch: script `bgtask BUNDLE --fetch` calls `performFetchWithCompletionHandler` (unverified). Tested (HelloSystem) |
| State restoration (`stateRestorationActivity`, restoration IDs) | 🟡 | ≤17 | scene-based: `stateRestorationActivity(for:)` saved when the scene goes to the background (app container), `session.stateRestorationActivity` + `scene(_:restoreInteractionStateWith:)` on the next launch; discarded when the app is closed in the app switcher (like iOS). Tested (HelloSystem). View-controller restoration (restoration identifiers, `encodeRestorableState`) ❌ |
| Home-screen quick actions (`UIApplicationShortcutItem`) | ✅ | ≤17 | static (Info.plist `UIApplicationShortcutItems`, localized titles, icon types/symbols) + dynamic `UIApplication.shortcutItems` (saved in the container); listed in the icon's long-press menu (max 4); cold launch: `launchOptions[.shortcutItem]` / `connectionOptions.shortcutItem`; warm: `windowScene(_:performActionFor:)` / `application(_:performActionFor:)`. Tested (HelloSystem, HelloScenes) |
| Alternate app icons (`setAlternateIconName`) | ✅ | ≤17 | Info.plist `CFBundleAlternateIcons` (icon files or asset-catalog sets; `isim build` adds them for `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` / include-all, unverified), `supportsAlternateIcons`, `alternateIconName`, the system alert, errors for unknown names / background; the home screen shows the chosen icon. Tested (HelloSystem) |
| Memory warnings (`didReceiveMemoryWarning`) | 🧩 | ≤17 | method exists; never sent |
| Remote notification registration | 🧩 | ≤17 | `registerForRemoteNotifications` fails with NSCocoaErrorDomain 3010 through `didFailToRegisterForRemoteNotificationsWithError` (no APNs on isim) |
| `UIPasteboard` | 🟡 | ≤17 | `general` + named pasteboards: strings, URLs, images, colors, items, `changeCount`, `hasStrings`…, change notification; strings/URLs are shared between the apps of the device (stored in its data directory); text views Cut/Copy/Paste through it; tested (HelloTransitions share sheet, HelloTextEditing edit menu and Ctrl+V). No paste prompt |

### View controllers & presentation

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `UIViewController` lifecycle (`loadView`, `viewDidLoad`, appear/disappear, layout callbacks) | ✅ | ≤17 | |
| Child view-controller containment | ✅ | ≤17 | |
| `init(nibName:bundle:)` / storyboard-instantiated controllers | ✅ | ≤17 | `init(nibName:bundle:)` loads `<Name>.nib` (explicit name, else one named after the class / class minus "Controller"), `nibName`/`nibBundle`, `init?(coder:)` through an IB coder (Swift classes that only implement `init(coder:)` work: UIKit initializers run without dispatching to app overrides), lazy storyboard views, `storyboard`, `performSegue(withIdentifier:sender:)`, `shouldPerformSegue`, `prepare(for:sender:)`, unwind (`canPerformUnwindSegueAction`, `@IBAction func x(_ segue:)`); tested (HelloStoryboards). `allowedChildrenForUnwinding` / `unwind(for:towards:)` are not consulted |
| `UIStoryboard`, `UIStoryboardSegue`, `UINib`, `Bundle.loadNibNamed`, `awakeFromNib` | 🟡 | ≤17 | `UIStoryboard(name:bundle:)`, `instantiateInitialViewController(creator:)`, `instantiateViewController(withIdentifier:)` / `(identifier:creator:)` (creator unverified), storyboard references (unverified), segue kinds show/push/showDetail/presentation/modal (+ modal styles), embed, relationship (root/viewControllers), unwind, custom segue classes (unverified); triggered by controls, bar button items, gesture recognizers, table/collection cell selection; `UINib(nibName:bundle:).instantiate(withOwner:options:)` with external objects (unverified), `register(_:forCellReuseIdentifier:)` for nibs and storyboard prototypes; tested (HelloStoryboards). Missing: `@IBSegueAction`, popover anchors, size-class variations (base values used), `nibWithData` of Apple binary nibs |
| Full-screen modal (`.fullScreen`, `.overFullScreen`, `.currentContext`, `.overCurrentContext`) | ✅ | ≤17 | slides up; `.fullScreen`/`.currentContext` send the presenter viewWillDisappear/viewDidAppear, the "over" styles keep it; context styles cover the `definesPresentationContext` controller; tested (HelloTransitions; context styles unverified) |
| Page / form sheet (`.automatic`, `.pageSheet`, `.formSheet`) | ✅ | ≤17 | iOS 15+ card look, presenter shrinks behind it at the large detent, swipe-down dismiss (presentation controller delegate: should/will/did dismiss, did attempt), iPad centered card (tap outside or swipe down dismisses; `preferredContentSize` for form sheets, unverified); tested on iPhone and iPad (HelloTransitions, HelloPresentations) |
| `isModalInPresentation` | ✅ | ≤17 | rubber-bands instead of dismissing |
| `UISheetPresentationController` (detents, grabber, largest undimmed detent) | ✅ | ≤17 | `.medium()`, `.large()`, `.custom(identifier:resolver:)`, grabber, dimming above `largestUndimmedDetentIdentifier` (touches pass through below it), `selectedDetentIdentifier` + `animateChanges`, dragging between detents with the delegate callback, `prefersScrollingExpandsWhenScrolledToEdge`; tested (HelloTransitions). iPad keeps centered cards (no detents) |
| Popover presentation (`UIPopoverPresentationController`) | ✅ | ≤17 | iPhone adapts to a sheet unless the adaptive delegate returns `.none`; real popovers: card with an arrow towards `sourceView`/`sourceRect` or `barButtonItem`, `permittedArrowDirections`, `preferredContentSize`, tap outside to dismiss (delegate), `passthroughViews`; tested (HelloTransitions; bar button anchoring unverified) |
| `modalTransitionStyle` (cross dissolve, flip, partial curl) | 🟡 | ≤17 | cross dissolve fades; flip horizontal is adapted (2D fold/unfold, no perspective); partial curl is shown as cover vertical (adapted); tested (HelloTransitions) |
| Custom transitions (`UIViewControllerTransitioningDelegate`, interactive) | ✅ | ≤17 | animators with a transition context (container, from/to views and controllers, final frames, `completeTransition`), custom `UIPresentationController` subclasses (frame, will/did begin/end, container layout), `transitionCoordinator.animate(alongsideTransition:)`, `UIPercentDrivenInteractiveTransition` (update/finish/cancel; scrubs the animator's UIView animations or its interruptible animator); tested (HelloTransitions) |
| `UINavigationController` (push/pop, back swipe) | ✅ | ≤17 | push/pop/popTo, parallax animation, back button, left-edge back swipe, delegate; tested (HelloNavigation) |
| `UINavigationItem` (title, bar button items, search controller, large titles) | ✅ | ≤17 | title, titleView, left/right bar button items, back title, large title display mode |
| `UITabBarController` | ✅ | ≤17 | tab bar, selection, delegate, badges, hidesBottomBarWhenPushed, tap-again pops to root; tested |
| `UISplitViewController` | 🟡 | ≤17 | collapsed on iPhone into one navigation stack (`topColumnForCollapsingToProposedTopColumn`, classic `collapseSecondary`, `.compact` column), `showDetailViewController` pushes, `show/hideColumn`; regular width (iPad): primary + secondary columns side by side; tested on iPhone and iPad (HelloTransitions). No display-mode button behaviour, no overlay/displace, no collapse/expand on size changes |
| `UIPageViewController` | ✅ | ≤17 | scroll style with paging (horizontal/vertical, inter-page spacing), data source neighbours, delegate will/did transition, page dots (presentation count/index), animated `setViewControllers`; tested (HelloTransitions). Page curl is shown as scroll (adapted) |
| `UIAlertController` `.alert` | ✅ | ≤17 | iOS 17/18 metrics, preferred action |
| `UIAlertController` `.actionSheet` | 🟡 | ≤17 | drawn as a bottom sheet; iPad popover anchoring unverified |
| `UIAlertController.addTextField` | ✅ | ≤17 | grouped fields in the card, first one focused, card stays above the keyboard; `UIAlertAction.isEnabled` updates its button live; tested (HelloTransitions) |
| `UIActivityViewController` (share sheet) | 🟡 | ≤17 | sheet with an item preview, Copy (to `UIPasteboard.general`) and `applicationActivities` (`UIActivity` subclasses), `excludedActivityTypes`, `UIActivityItemSource`, `completionWithItemsHandler`; tested (HelloTransitions). No other apps to share to (no AirDrop/Messages/Mail rows) |
| `UISearchController` | 🟡 | ≤17 | in `navigationItem.searchController`: bar below the (large) title, collapses on scroll (`hidesSearchBarWhenScrolling`); activating hides the navigation bar, shows Cancel, dims the content (`obscuresBackgroundDuringPresentation`), calls the results updater per keystroke, restores the scroll position on cancel; tested (HelloInputs). Results controller and standalone use unverified; no animated bar transition |
| `UIImagePickerController` (camera/library) | ❌ | ≤17 | |
| `UIDocumentPickerViewController` / `UIDocumentBrowserViewController` | ❌ | ≤17 | |
| `UIColorPickerViewController` | 🟡 | ≤17 | grid (tested, via UIColorWell), spectrum and RGB sliders, opacity, delegate callbacks; no eyedropper or saved colors; spectrum/sliders unverified |
| `UIFontPickerViewController` | 🟡 | ≤17 | searchable list of the iOS font families (+ installed app fonts) drawn in their own face, `selectedFontDescriptor`, delegate pick/cancel, minimal `UIFontDescriptor` (`family`/`name`/`size`, `UIFont(descriptor:size:)`); tested (HelloStoryboards). No faces list (`includeFaces`), no `filteredTraits` |
| `UIReferenceLibraryViewController`, `QLPreviewController` | ❌ | ≤17 | |
| `UIInputViewController` (custom keyboard extension) | ✅ | ≤17 | loaded in-process; no Full Access |
| `overrideUserInterfaceStyle` | ✅ | ≤17 | |
| `setEditing(_:animated:)`, `editButtonItem` | ✅ | ≤17 | Edit/Done item; `UITableViewController` forwards to its table; tested (HelloTable) |
| `preferredContentSize` | 🟡 | ≤17 | sizes popovers (tested) and iPad form sheets; notifies the parent and presentation controller |
| `UIContentUnavailableConfiguration` | ✅ | 17.0 | `.empty()`, `.loading()`, `.search()`; image/text/secondary text/buttons; `contentUnavailableConfiguration`, `setNeedsUpdateContentUnavailableConfiguration`, `updateContentUnavailableConfiguration(using:)` (search text from the search controller), `UIContentUnavailableView`; tested (HelloTransitions). A class here, not a struct (adapted) |

### Views & controls

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `UIView` hierarchy, frames/bounds/center, hit-testing, coordinate conversion | ✅ | ≤17 | |
| Autoresizing masks | ✅ | ≤17 | |
| `transform` (2D affine: translate/scale/rotate) | ✅ | ≤17 | about the view's center |
| 3D transforms (`CATransform3D`, perspective) | ✅ | ≤17 | `layer.transform`, `view.transform3D`, `sublayerTransform`; affine results drawn directly, perspective (m34 / non-affine) by rendering the layer/view offscreen and warping it onto its projected quad (host homography warp); `isDoubleSided`. Layers are flattened per level (no shared 3D space / depth sorting beyond `zPosition` order). Tested (HelloCoreAnimation: a rotated card is a trapezoid) |
| Background color, alpha (group opacity), hidden, `clipsToBounds` | ✅ | ≤17 | software rendering (cairo) |
| `layer.cornerRadius`, border, `cornerCurve` | ✅ | ≤17 | |
| Layer shadows (`shadowColor/Opacity/Radius/Offset`, `shadowPath`) | ✅ | ≤17 | Gaussian-like blur (3-pass box, sigma = radius/2) of `shadowPath` or, for views, the background shape; standalone layers shadow their whole content (sublayers included). A view with a clear background and no `shadowPath` casts no shadow (iOS shadows its content). Tested (HelloCoreAnimation falloff pixels) |
| `layer.mask`, `mask` view | ✅ | ≤17 | content drawn through the mask layer's / mask view's alpha (any layer kind: shape, gradient, image contents). Tested (circle shape mask, half-width mask view) |
| `draw(_:)` custom drawing with `UIGraphicsGetCurrentContext` | ✅ | ≤17 | |
| `tintColor` / `tintColorDidChange` | 🟡 | ≤17 | tint inheritance details unverified |
| `contentMode` | 🟡 | ≤17 | used by image views; all modes unverified |
| `UILabel` (font, color, alignment, multi-line, line break, `adjustsFontSizeToFitWidth`) | ✅ | ≤17 | Pango text; Adwaita Sans stands in for SF Pro, so metrics differ slightly |
| `UILabel.attributedText` | ✅ | ≤17 | fonts, colours, background, kern, underline, strikethrough, baseline offset, paragraph alignment/line spacing (Pango markup); tested (HelloImages). Attachments and shadows are not drawn |
| `UIButton` system/custom, title/color/image per state | ✅ | ≤17 | `imageView` returns nil |
| `UIButton.Configuration` (plain/tinted/gray/filled/bordered*, subtitle, image padding, corner style, size) | 🟡 | ≤17 | no `configurationUpdateHandler`, attributed titles or activity indicator |
| Button menus (`menu`, `showsMenuAsPrimaryAction`), pop-up buttons | ✅ | ≤17 | UIButton.menu + showsMenuAsPrimaryAction, UIBarButtonItem menus; tested |
| `UIControl` target-action, `UIAction`, control events/states | ✅ | ≤17 | |
| `UIImageView` | ✅ | ≤17 | PNG/JPEG/… via gdk-pixbuf, SVG via librsvg |
| Animated images (`animationImages`, `UIImage.animatedImage`) | ✅ | ≤17 | `UIImage.animatedImage(with:duration:)` / `animatedImageNamed`, `UIImageView.animationImages` / duration / repeat count / `startAnimating`; an animated `image` plays by itself; frames advanced per display frame; tested (HelloImaging). `highlightedAnimationImages` unverified |
| `UITextField` | 🟡 | ≤17 | caret always at the end: no selection, cursor movement, copy/paste |
| `UITextView` | 🟡 | ≤17 | plain text, editable/scrollable, self-sizing when `isScrollEnabled = false`, delegate (should/did begin/end, `shouldChangeTextIn`, did change), notifications, keyboard traits, tap places the caret, `selectedRange`, `scrollRangeToVisible`; tested (HelloInputs). No attributed text, selection UI, edit menu or data detectors (stored) |
| `UISwitch` | ✅ | ≤17 | |
| `UISlider` | ✅ | ≤17 | thumb drag, continuous/non-continuous, track tints; tested (HelloControls) |
| `UIStepper` | ✅ | ≤17 | min/max/step/wraps; tested |
| `UISegmentedControl` | ✅ | ≤17 | titles/images, sliding selection, momentary, per-segment enable; tested |
| `UIPickerView` | ✅ | ≤17 | wheels drawn on a cylinder behind the selection band, drag/fling/tap a row, `selectRow`, reload, title rows, row widths/heights; tested (HelloInputs). `viewForRow` views unverified |
| `UIDatePicker` | ✅ | ≤17 | `.time`/`.date`/`.dateAndTime`/`.countDownTimer` (`.yearAndMonth` unverified); wheels (cyclic, invalid days spin back), compact (pills open a calendar or time popover), inline calendar (+ time pill); min/max dates, `minuteInterval`; tested (HelloInputs). Device locale/time zone are used; the `locale`/`timeZone` properties are stored only |
| `UIProgressView` | ✅ | ≤17 | default and bar styles |
| `UIActivityIndicatorView` | ✅ | ≤17 | medium/large, spins (CADisplayLink) |
| `UIPageControl` | ✅ | ≤17 | tap to page; tested |
| `UIColorWell` | ✅ | ≤17 | rainbow ring + color, presents the color picker, `.valueChanged`; tested (HelloInputs) |
| `UIScrollView` | 🟡 | ≤17 | pan (one finger, or the centroid of two), rubber-banding, deceleration, insets, delegate, `isPagingEnabled`, `scrollViewWillEndDragging(_:withVelocity:targetContentOffset:)`; pinch zooming (`viewForZooming`, min/max/`zoomScale`, `bouncesZoom` spring back, `setZoomScale(_:animated:)`, `zoom(to:animated:)`, zoom delegate calls); tested (HelloMultiTouch). The zoomed view's `frame` stays its untransformed frame (UIKit reports the scaled one); paging unverified outside collection-view carousels |
| `UITableView` (cells, sections, editing, swipe actions) | 🟡 | ≤17 | plain/grouped/inset grouped, cell reuse, self-sizing rows, sticky headers, header/footer titles and views, selection, swipe to delete + custom trailing actions, edit mode delete, animated inserts/deletes/moves, `performBatchUpdates`, `scrollToRow`, `UITableViewController`, drag to reorder / drop (see Drag & drop); tested (HelloTable, HelloDragDrop). Missing: leading swipe actions, section index, prefetching, nibs |
| `UITableViewDiffableDataSource` | ✅ | ≤17 | snapshots diffed into animated row inserts/deletes; reload/reconfigure; tested (HelloTable) |
| `UICollectionView` + `UICollectionViewFlowLayout` | 🟡 | ≤17 | cell/supplementary reuse, flow layout (both directions, delegate sizes/insets/spacing, headers/footers, pinned headers, estimated sizes), multiple selection, animated inserts/deletes/moves, `performBatchUpdates`, `scrollToItem`, `UICollectionViewController`; drag/drop delegates (unverified); tested (HelloCollection). Missing: prefetching, decoration views, custom layout transitions, nibs |
| `UICollectionViewCompositionalLayout` | 🟡 | ≤17 | items, nested horizontal/vertical groups (repeating, `count:`), fractional/absolute/estimated sizes, fixed/flexible spacing, content insets, boundary headers/footers (pinning), section provider + environment, orthogonal scrolling (continuous, paging, group paging); tested (HelloCollection). Missing: horizontal scroll direction, decoration items, `visibleItemsInvalidationHandler`, custom group providers |
| `UICollectionViewDiffableDataSource`, `NSDiffableDataSourceSnapshot` | 🟡 | ≤17 | snapshots diffed into animated item inserts/deletes, reconfigure, supplementary provider, `CellRegistration`/`SupplementaryRegistration`; tested (HelloCollection). Missing: `NSDiffableDataSourceSectionSnapshot` (outlines), reordering handlers, async apply |
| List cells (`UICollectionLayoutListConfiguration`, `UIListContentConfiguration`, cell accessories) | 🟡 | ≤17 | list layouts (plain, grouped, inset grouped, sidebar colours), supplementary headers/footers, separators, self-sizing rows, `UICollectionViewListCell` accessories (disclosure, checkmark, detail, delete, reorder, outline, label, custom view); tested (HelloCollection). `UIListContentConfiguration` is a class here, not a struct (adapted). Missing: list swipe actions, outline expansion, custom `UIContentConfiguration` views |
| `UIStackView` (axis, spacing, custom spacing, alignment, distribution) | ✅ | ≤17 | arranged as Auto Layout constraints |
| `UIVisualEffectView` + `UIBlurEffect` (system materials) | ✅ | ≤17 | real backdrop blur + light/dark tint; no saturation boost |
| `UIVibrancyEffect` | 🧩 | ≤17 | content drawn normally |
| `UIMenu`, `UIContextMenuInteraction` (context menus, previews) | 🟡 | ≤17 | UIMenu pop-ups for UIButton.menu (sections, checkmarks, destructive, submenus); no context-menu previews |
| `UIToolbar`, `UIBarButtonItem` | ✅ | ≤17 | system items, titles, images, primary actions, menus, flexible/fixed spaces; tested |
| `UINavigationBar` (standalone, appearance) | 🟡 | ≤17 | large titles collapsing on scroll, scroll-edge transparency, appearances (basic), UIAppearance proxies (tint tested) |
| `UITabBar` | ✅ | ≤17 | items, badges, selected/unselected tints; no "More" tab beyond 5 items |
| `UISearchBar` | ✅ | ≤17 | search field (magnifier, placeholder, clear button, search return key), Cancel button, delegate, keyboard traits; tested (HelloInputs). Scope bar and bar styles unverified |
| `UIRefreshControl` | ✅ | ≤17 | `scrollView.refreshControl` / `UITableViewController.refreshControl`: pull past the threshold starts refreshing (`.valueChanged`), spinner stays until `endRefreshing()`; tested (HelloInputs). No `attributedTitle` (no NSAttributedString) |
| `UIEditMenuInteraction` (copy/paste menu) | ❌ | ≤17 | |
| `UIAppearance` proxies (`UINavigationBar.appearance()`) | 🟡 | ≤17 | adapted (no message forwarding): proxies are offscreen instances; changed appearance properties (colors, bar appearances, title attributes, fonts, translucency, …) apply when a view first enters a window unless it set them itself; `whenContainedInInstancesOf:` and trait style; tested (HelloInputs). Per-state setters (`setTitleTextAttributes(_:for:)`) and `UIBarItem` proxies not applied |
| `UIInputView`, `inputView` / `inputAccessoryView` | 🟡 | ≤17 | custom keyboards work; arbitrary input views unverified |
| `UIPointerInteraction`, `UIPencilInteraction`, Apple Pencil | ❌ | ≤17 | |
| `UIGlassEffect` (`.regular`/`.clear`, `tintColor`, `isInteractive`), `UIGlassContainerEffect` | 🟡 | 26.0 | adapted: isim's glass drawing (light backdrop blur, translucent body, specular rim) in the effect view's bounds and `cornerRadius`; interactive glass brightens while touched; containers do not merge or morph shapes |
| `UIButton.Configuration` `.glass()`, `.prominentGlass()`, `.clearGlass()`, `.prominentClearGlass()` | 🟡 | 26.0 | adapted: glass capsule (prominent: tinted with the tint colour, white label); tested (HelloOSVersions) |
| `UIBackgroundExtensionView` | 🧩 | 26.0 | the content view fills the view; isim has no sidebars/inspectors to extend under |
| `UIScrollEdgeEffect` (scroll view edge effects) | ❌ | 26.0 | bars draw their own edge fade under `--os 26`/`27` |
| `UIBarButtonItem.badge` | ❌ | 26.0 | |
| `UITab`, `UITabGroup`, `UITabBarController.Mode.tabSidebar` (sidebar-adaptable tabs) | ❌ | 18.0 | the iPad tab bar look of iOS 18 is drawn (see Appearance), the API is not |
| `UIDragInteraction.allowsPointerDragBeforeLiftDelay` | ❌ | 27.0 | |
| `NSTextTable`/`NSTextBlock` in UIKit, `UITextAttachmentViewProviderReusePolicy`, viewport rendering surfaces | ❌ | 27.0 | |
| `UIArrangementViewController`, `UIView.ReservedRegion`, `UIHingeInteraction`, vertical bar placement | ❌ | 27.1 | iPhone Duo APIs (iOS 27.1 beta) |

### Layout

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Auto Layout (`NSLayoutConstraint`, activate/deactivate, priorities, inequalities) | ✅ | ≤17 | Cassowary solver, rebuilt per layout pass |
| Layout anchors (`NSLayoutXAxisAnchor`, `…YAxis…`, `NSLayoutDimension`, system spacing) | ✅ | ≤17 | |
| Visual Format Language (`constraints(withVisualFormat:)`) | ✅ | ≤17 | spacing (standard 8/20), sizes, metrics, view references, relations, priorities, alignment/direction options; tested (HelloConstraints) |
| Intrinsic content size, hugging / compression resistance | ✅ | ≤17 | |
| `systemLayoutSizeFitting` | ✅ | ≤17 | |
| `UILayoutGuide`, `safeAreaLayoutGuide`, `layoutMarginsGuide` | ✅ | ≤17 | per-device safe areas |
| `additionalSafeAreaInsets` (container insets propagate to children) | ✅ | ≤17 | navigation/tab bars; scroll views adjust |
| `readableContentGuide` | 🟡 | ≤17 | exists; width rules unverified |
| `keyboardLayoutGuide` | ✅ | ≤17 | follows keyboard show/hide/frame changes (animated), bottom safe area when hidden (`usesBottomSafeArea`); tested (HelloConstraints). Undocked/floating keyboards do not exist on isim |
| Layout margins, `directionalLayoutMargins` | ✅ | ≤17 | |
| `UIScrollView` `contentLayoutGuide` / `frameLayoutGuide` | ✅ | ≤17 | |
| Trait collections (style, idiom, size classes, display scale) | ✅ | ≤17 | |
| `traitCollectionDidChange` | ✅ | ≤17 | |
| `registerForTraitChanges` (iOS 17), custom traits | 🟡 | 17.0 | handler, target/action and Swift generic forms for style, size classes, idiom, display scale (checked every frame); tested (HelloConstraints). No custom traits / `traitOverrides` |
| Size classes | ✅ | ≤17 | fixed per device (portrait) |
| Dynamic Type: `preferredFont(forTextStyle:)` | ✅ | ≤17 | sized for the content size category (Settings > Accessibility > Display & Text Size, 12 sizes); Bold Text makes system fonts heavier; tested (HelloAccessibility) |
| Dynamic Type size changes, `UIFontMetrics`, `adjustsFontForContentSizeCategory` | ✅ | ≤17 | category changes repost `UIContentSizeCategory.didChangeNotification`, refit labels/text views/fields that adjust (text-style and `UIFontMetrics` fonts), `preferredContentSizeCategory` on the app and trait collections, `isAccessibilityCategory`; tested (HelloAccessibility). `traitCollectionDidChange` gets no previous collection |
| Right-to-left layout, `semanticContentAttribute` | ❌ | ≤17 | |
| Rotation layout (`viewWillTransition(to:with:)`) | ✅ | ≤17 | coordinator alongside/completion, size classes, side safe areas; tested (HelloRotation). Landscape nav bars keep portrait height |

### Animation

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `UIView.animate(withDuration:…)` | ✅ | ≤17 | frame/center/bounds, alpha, transform, backgroundColor and layer corner radius/border/shadow interpolate |
| Timing curves (ease in/out, linear) | ✅ | ≤17 | |
| Spring animations (damping/velocity; iOS 17 `springDuration`/`bounce`) | ✅ | ≤17 | |
| Delay, repeat, autoreverse, begin-from-current-state | ✅ | ≤17 | retargets from the current value |
| `performWithoutAnimation`, `areAnimationsEnabled` | ✅ | ≤17 | |
| Constraint animations (`layoutIfNeeded` in an animation block) | 🟡 | ≤17 | frames set inside the block animate; unverified end to end |
| `UIView.transition(with:)` | 🟡 | ≤17 | adapted: flips and curls squash the view to its axis and unfold it (2D, no perspective) with the changes applied at the midpoint; cross dissolve fades out and back in (no snapshot cross-fade); tested (HelloAnimations) |
| `transition(from:to:)` | ✅ | ≤17 | cross dissolve between the views, flips/curls as above (2D), `.showHideTransitionViews` or replacement in the superview; tested (HelloAnimations) |
| `animateKeyframes` / `addKeyframe` | ✅ | ≤17 | keyframe segments per property on one timeline, overall curve from the options, discrete mode; cubic/paced modes interpolate linearly; tested (HelloAnimations) |
| `UIViewPropertyAnimator` (interruptible, scrubbable) | ✅ | ≤17 | start/pause/stop/finish(at:), `fractionComplete` scrubbing, `isReversed`, add animations/completions, `pausesOnCompletion`, cubic/spring timing parameters, `runningPropertyAnimator`; `layer.presentation()` reports in-flight values; tested (HelloAnimations). `continueAnimation` ignores new timing parameters (duration factor only) |
| Layer property animations (cornerRadius, shadow, …) | 🟡 | ≤17 | a view's layer animates corner radius, border width/color and shadow opacity/radius/offset in UIView/property-animator blocks (tested: radius, border); Core Animation objects (`CABasicAnimation`, keyframes, springs, groups, transitions) also animate a view's layer (position, bounds, transform incl. `transform.rotation.z`, opacity, colours, corner radius, border, shadow); see QuartzCore |
| UIKit Dynamics (`UIDynamicAnimator`, behaviors) | 🟡 | ≤17 | gravity, collision (reference bounds + insets, segment and path boundaries, item–item, contact delegate), snap, push (continuous / instantaneous), attachment (spring or rigid, item or anchor), `UIDynamicItemBehavior` (elasticity, friction, density, resistance, anchored, linear/angular velocity), actions, pause/resume delegate. Adapted: items collide as axis-aligned rectangles and collisions never spin them; ellipse/path collision bounds use the rectangle. Tested: gravity + collision (falls, rests on the boundary); others unverified |

### Gestures & touches

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `touchesBegan/Moved/Ended/Cancelled`, responder chain | ✅ | ≤17 | |
| Multi-touch | ✅ | ≤17 | a second finger like the Simulator's: Option-drag mirrors it around the screen centre (pinch/rotate), Option+Shift-drag moves both (two-finger pan), grey finger circles while Option is held; scripts `pinch`, `rotate2`, `twofinger`; UITouch sets, `UIEvent.allTouches`, `isMultipleTouchEnabled`, `numberOfTouches`/`location(ofTouch:)`; tested (HelloMultiTouch). At most two fingers |
| `UITapGestureRecognizer` | ✅ | ≤17 | |
| `UIPanGestureRecognizer` (translation, velocity) | ✅ | ≤17 | |
| `UILongPressGestureRecognizer` | ✅ | ≤17 | |
| `UISwipeGestureRecognizer` | ✅ | ≤17 | directions, delegate, failure requirements; tested (HelloGestures) |
| `UIPinchGestureRecognizer`, `UIRotationGestureRecognizer` | ✅ | ≤17 | scale/rotation (settable, relative from then on), velocity, centroid location; 2-touch `UIPanGestureRecognizer` (`minimumNumberOfTouches`/`maximumNumberOfTouches`); tested (HelloMultiTouch) |
| `UIScreenEdgePanGestureRecognizer` | ✅ | ≤17 | starts only within 20 pt of `edges`; tested (HelloGestures) |
| `UIHoverGestureRecognizer`, `UIPointerInteraction`, `UIPencilInteraction` | 🟡 | ≤17 | hover from host mouse motion without a button (script `hover X Y`) on every device; iPad pointer (dot, highlight / lift / hover effects, region request/enter/exit, `UIButton.isPointerInteractionEnabled`); tested (HelloMultiTouch). Pencil: honest stub, never gets taps; pointer shapes/beam not drawn |
| `UIGestureRecognizerDelegate` (simultaneous recognition, `require(toFail:)`) | 🟡 | ≤17 | `gestureRecognizerShouldBegin`, `shouldReceive(_ touch:)`, `shouldRecognizeSimultaneouslyWith` (with exclusive recognizers), `UIView.gestureRecognizerShouldBegin`, `require(toFail:)` for discrete recognizers (tested: single vs double tap); `shouldRequireFailure(of:)` overrides are not consulted |
| Custom `UIGestureRecognizer` subclasses | ✅ | ≤17 | `UIGestureRecognizerSubclass`: touches callbacks, settable `state` sends actions, `reset`; tested (HelloGestures) |
| Shake / motion events | ✅ | ≤17 | `motionBegan/Ended` (shake) via Ctrl+Shift+Z or the script command `shake`; tested (HelloGestures) |
| Hardware keys (`UIKeyCommand`, `pressesBegan`) | ✅ | ≤17 | host keyboard → `UIPress`/`UIKey` (HID usage, modifiers) on the responder chain; `keyCommands`/`addKeyCommand` matched before typing; tested (HelloGestures). No discoverability HUD |

### Text input & keyboard

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| System keyboard (English US: letters/numbers/symbols, shift, auto-capitalization, return-key titles) | ✅ | ≤17 | |
| Keyboard types (number pad, decimal, email, URL, phone) | 🟡 | ≤17 | trait stored; always the full keyboard |
| Other languages, emoji keyboard | ✅ | ≤17 | built-in English (US), Portuguese (Brazil), Spanish (ñ), French (AZERTY), German (QWERTZ + üöä) and Emoji keyboards enabled in Settings > General > Keyboard > Keyboards (AppleKeyboards, default English + Emoji), globe / emoji key and list, localized space/return keys, accent popups on long press, `UITextInputMode.activeInputModes`; tested (HelloTextEditing) |
| Autocorrection, predictive bar, spell checking, `UITextChecker` | 🟡 | ≤17 | `UITextChecker` over small built-in word lists (en/pt/es/fr/de): misspelled = unknown and one edit from a listed word; guesses, completions, learn/ignore; predictive bar (typed word, corrections, completions) and autocorrection on space/punctuation from the on-screen keyboard; red dotted underline while editing; Settings toggles; tested (HelloTextEditing). Small dictionaries, no learning from typing, no inline predictions |
| Selection, caret movement, loupe, copy/paste/edit menu | ✅ | ≤17 | tap places the caret at a word boundary, double tap selects a word, triple tap a paragraph, long press shows the loupe and moves the caret, selection handles drag; edit menu (Cut, Copy, Paste, Select, Select All, Replace… with guesses; delegate `editMenuForTextIn`), `UIEditMenuInteraction`, `UIMenuController`; arrows, Shift-select, Option/Cmd jumps, Cmd/Ctrl+A/C/X/V, forward delete; UITextField, UITextView and SwiftUI TextField/TextEditor; tested (HelloTextEditing). No floating cursor, no undo |
| `UITextFieldDelegate` | ✅ | ≤17 | |
| Secure text entry | ✅ | ≤17 | bullets |
| Keyboard notifications (`keyboardWillShow…`, frame/duration user info) | ✅ | ≤17 | |
| `keyboardDismissMode` (on drag / interactive) | 🟡 | ≤17 | unverified |
| Typing from the host keyboard | ✅ | ≤17 | `ISIM_SOFTWARE_KEYBOARD=0` hides the on-screen one |
| Custom keyboard extensions (globe key, keyboard list) | ✅ | ≤17 | |
| `UITextInput` positions/ranges, marked text (IME) | ✅ | ≤17 | positions, ranges, `selectedTextRange`, `text(in:)`, `replace(_:withText:)`, caret/first/selection rects, `closestPosition`, `UITextInputStringTokenizer`, `inputDelegate`; marked text from the host IME (SDL text editing) or script `compose TEXT`, underlined, committed by `insertText`; custom keyboards' document proxy sees the selection; tested (HelloTextEditing) |
| Password AutoFill, `textContentType`, one-time codes | 🧩 | ≤17 | trait stored; no AutoFill |
| Dictation, Scribble | 🧩 | ≤17 | the keyboard's mic key logs that dictation is unavailable; Settings shows dictation off; no Scribble |

### Drawing, images & symbols

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `UIBezierPath` (rect, oval, rounded rect, arcs, curves, fill, stroke) | 🟡 | ≤17 | no dashes, line caps/joins, `addClip`, `contains` |
| `UIRectFill`, `UIRectFrame` | ✅ | ≤17 | |
| `UIGraphicsImageRenderer` / `UIGraphicsBeginImageContext` (offscreen drawing) | ✅ | ≤17 | image/pngData/jpegData renderers, formats (scale, opaque), renderer context helpers, nested contexts; tested (HelloImages). Backdrop blur inside an offscreen context reads the screen |
| `UIGraphicsPDFRenderer`, `UIGraphicsBeginPDFContextToData/File` | ✅ | ≤17 | cairo PDF surface; UIKit drawing (fills, text, images) goes to the page; `pdfData`, multiple pages, `beginPage(withBounds:)`; tested (HelloQuartz, read back with CGPDFDocument). `writePDF(to:)` unverified; links/destinations ignored |
| Printing (`UIPrintInteractionController`) | ❌ | ≤17 | |
| `UIImage(named:)` (bundle + asset catalog, 1x/2x/3x, dark variants) | ✅ | ≤17 | |
| `UIImage(contentsOfFile:)`, `UIImage(cgImage:)` | ✅ | ≤17 | |
| `UIImage(data:)` | ✅ | ≤17 | PNG/JPEG/GIF/SVG via the host decoders, with `scale:`; tested (HelloImages) |
| `pngData()` / `jpegData()` | ✅ | ≤17 | `UIImagePNGRepresentation`/`UIImageJPEGRepresentation` (JPEG composites transparency over black, as iOS does); tested (HelloImages) |
| `resizableImage(withCapInsets:resizingMode:)`, `withHorizontallyFlippedOrientation`, `imageOrientation` | ✅ | ≤17 | nine slices (caps fixed, edges/center stretched or tiled), orientations drawn rotated/mirrored with swapped sizes for left/right; tested (HelloImaging). Tile mode and `stretchableImage` unverified; `imageFlippedForRightToLeftLayoutDirection` returns the image (isim is LTR) |
| `withTintColor`, rendering modes (template/original) | ✅ | ≤17 | |
| SF Symbols (`UIImage(systemName:)`) | 🟡 | ≤17 | stand-in drawings, not Apple's SF Symbols artwork (Apple licenses it for its own platforms only, so isim cannot ship or copy it): about 170 common names are isim's own procedural glyphs (`isim/runtime/host_symbols.inc`: heart, star, bell, envelope, person, arrows, chevrons, media controls, weather, ...) and about 220 more map to the host's Adwaita symbolic icons. Variants compose for any drawn glyph: `.fill` (solid shape), `.circle` / `.square` / `.triangle` / `.rectangle` (enclosure; with `.fill` the glyph is cut out), `.slash`. Shapes and proportions differ from iOS; names without a stand-in draw a dashed placeholder and are reported once on stderr; `UIImage(systemName:)` never returns nil. Tested (HelloSymbols: 170 names, none draws the placeholder, `.fill` differs from the outline) |
| `UIImage.SymbolConfiguration` (point size, weight, scale, text style) | ✅ | ≤17 | weight thickens or thins the strokes of drawn glyphs (Adwaita icons keep their weight); `configurationWithFont:` takes the font's weight; tested (HelloSymbols) |
| Symbol rendering modes (hierarchical, palette, multicolor), symbol effects | ❌ | ≤17 | |
| `UIColor` (RGB/HSB/white, system & semantic colors, dynamic provider) | ✅ | ≤17 | Apple HIG light/dark values |
| Named asset-catalog colors (light/dark) | ✅ | ≤17 | |
| `UIFont` (system weights, italic, monospaced, monospaced digits, metrics) | 🟡 | ≤17 | Adwaita Sans substitutes SF Pro; `fontDescriptor` missing |
| Custom fonts (`UIAppFonts`) | ✅ | ≤17 | registered at launch |
| `NSString.draw(in:withAttributes:)`, `boundingRect(with:)` | ✅ | ≤17 | NSString and NSAttributedString drawing/measuring, `NSParagraphStyle`, `NSStringDrawingOptions`; tested (HelloImages). `NSShadow` is accepted, not drawn |

### Haptics & feedback

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `UIImpactFeedbackGenerator`, `UISelectionFeedbackGenerator`, `UINotificationFeedbackGenerator` | 🧩 | ≤17 | no haptics, like Apple's Simulator; each feedback is logged (`isim: haptic impact (heavy)`). Tested (background) |
| Core Haptics (`CHHapticEngine`) | ✅ | ≤17 | like Apple's Simulator there is no haptic hardware: `capabilitiesForHardware().supportsHaptics` is false. Engine, events, parameters, parameter curves, patterns (incl. AHAP dictionaries/files, `exportDictionary`), players and advanced players (pause/resume/seek/loop/rate, completion handlers, `notifyWhenPlayersFinished`) are modelled and timed; playback is logged on stderr, never felt or heard. Tested (HelloCoreAnimation) |
| `AudioServicesPlaySystemSound` / vibration | ✅ | ≤17 | System Sound Services (AudioToolbox): sound files play through the host audio; `kSystemSoundID_Vibrate` is logged (no haptics, like the Simulator). Tested (background) |

### Accessibility

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `accessibilityIdentifier` | ✅ | ≤17 | drives isim's scripted tests (`tapid`) |
| `accessibilityLabel/Hint/Value/Traits`, `isAccessibilityElement`, containers | ✅ | ≤17 | the accessibility tree: elements in reading order (top-to-bottom, left-to-right), `accessibilityElements` order, `UIAccessibilityElement`, `accessibilityViewIsModal`, `shouldGroupAccessibilityChildren`, frames/activation points, UIKit defaults for controls (switch, slider, text fields); `dump` shows `ax=` descriptions with `ISIM_DUMP_ACCESSIBILITY=1`; tested (HelloAccessibility) |
| VoiceOver (simulated), Switch Control, Voice Control | 🟡 | ≤17 | isim VoiceOver: Settings > Accessibility > VoiceOver or script `voiceover on/off/next/prev/activate/increment/decrement/action/escape/read`; black focus cursor, description logged and spoken with the host espeak-ng, tap / double tap / swipe gestures, activation by tap, adjustable values, custom actions; tested (HelloAccessibility). No rotor gestures, no Switch/Voice Control |
| `UIAccessibility.isVoiceOverRunning`, `isReduceMotionEnabled`, `isBoldTextEnabled` & co. | ✅ | ≤17 | follow Settings > Accessibility (VoiceOver, Reduce Motion, Bold Text, Increase Contrast → `isDarkerSystemColorsEnabled`/`accessibilityContrast`, Reduce Transparency, Differentiate Without Color) with their change notifications; tested (HelloAccessibility). Invert colors / grayscale always off |
| `UIAccessibility.post(notification:)`, custom actions, rotors | 🟡 | ≤17 | announcement / screenChanged / layoutChanged / pageScrolled logged and handled by VoiceOver (spoken, refocus), `announcementDidFinishNotification`; `UIAccessibilityCustomAction` (handler and target/selector); tested (HelloAccessibility). `UIAccessibilityCustomRotor` stored only (unverified) |
| Larger Text sizes, Bold Text, Increase Contrast, Reduce Transparency settings | ✅ | ≤17 | Settings > Accessibility pages write the device preferences every app reads; tested (HelloAccessibility via preferences). Colors don't change for Increase Contrast; materials don't turn opaque |
| Large Content Viewer | 🟡 | ≤17 | `UILargeContentViewerInteraction` + `showsLargeContentViewer`/`largeContentTitle`/`largeContentImage`: HUD on long press at accessibility sizes (unverified) |

### Drag & drop

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `UIDragInteraction`, `UIDropInteraction` | ✅ | ≤17 | within the app: long press lifts (script `longdrag X1 Y1 X2 Y2 HOLD SECS`), the snapshot preview follows the finger, drop targets get canHandle/enter/update/exit/performDrop/conclude, sessions (`items`, `location(in:)`, `localDragSession`, `loadObjects(ofClass:)` incl. `String`), drag delegate lift/move/end callbacks; tested (HelloDragDrop). No drags between apps; lift previews are snapshots (`UIView.snapshotView(afterScreenUpdates:)`) |
| Table/collection view drag & drop | 🟡 | ≤17 | `dragDelegate`/`dropDelegate`/`dragInteractionEnabled`/`hasActiveDrag`: local moves go to the data source's `moveRowAt`/`moveItemAt`, other drops to `performDropWith` (coordinator with destination and items); tested for UITableView (HelloDragDrop); collection views unverified; no insertion gap animation |
| `NSItemProvider` | 🟡 | ≤17 | data/file representations, `loadObject(ofClass:)` (UIImage, NSString/String), `loadDataRepresentation`, UTType overloads (tested through PHPicker and drag and drop); lives in isim's UniformTypeIdentifiers module (re-exported by UIKit), not Foundation |

### Appearance & dark mode

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Light / dark appearance (`--dark`, Settings > Display & Brightness) | ✅ | ≤17 | |
| Dynamic colors resolve per trait collection | ✅ | ≤17 | |
| Live appearance switch while the app runs | 🟡 | ≤17 | shell notifies apps; per-view refresh unverified |
| `overrideUserInterfaceStyle` (view, controller) | ✅ | ≤17 | |
| Accent color from the asset catalog (`AccentColor`) | 🟡 | ≤17 | used by SwiftUI's `accentColor`; UIKit global tint unverified |
| Liquid Glass system look (`--os 26`/`27`) | 🟡 | 26.0 | adapted: floating glass tab bar (iPhone), glass back button and bar button items (Done items prominent), scroll-edge fade instead of the bar material, glass alerts (300 pt, corner 34, leading text, capsule buttons, preferred action filled), glass menus and action sheets, rounder sheets/popovers, 63×28 switch with a pill thumb, capsule configuration buttons; tested by pixels (HelloOSVersions) |
| iPadOS 18 tab bar (floating capsule at the top, titles only) | 🟡 | 18.0 | adapted: drawn by `UITabBarController` and SwiftUI `TabView` on iPads with `--os 18` (glass with `--os 26`/`27`); no sidebar |
| iOS 27 appearance refresh (Liquid Glass updates, tint slider) | ❌ | 27.0 | not specified in detail by Apple's documentation; `--os 27` uses the iOS 26 look |
| Observable objects tracked in `layoutSubviews` (automatic invalidation) | ❌ | 26.0 | |
| SF Symbols iOS 18 effects (wiggle, breathe, rotate), `UIUpdateLink`, zoom transition (`preferredTransition`) | ❌ | 18.0 | |

---

## SwiftUI

isim's SwiftUI is an independent re-implementation (Apple's is closed source): views evaluate into a node tree,
are laid out with SwiftUI-style proposals, and render as UIKit views.

### App & scenes

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `App` protocol, `@main` | ✅ | ≤17 | |
| `WindowGroup` | ✅ | ≤17 | one window; `title`/`id` ignored |
| Several scenes in `body`, `Settings`, `DocumentGroup`, `Window` | 🟡 | ≤17 | several `WindowGroup`s (`id:`, `for:`) and scene modifiers in `body`; the first group is shown. `Settings`/`Window` are macOS-only (not provided, like the iOS SDK); `DocumentGroup` ❌. Tested (HelloScenes) |
| `@Environment(\.scenePhase)` | ✅ | ≤17 | active / inactive / background |
| `@UIApplicationDelegateAdaptor` | ✅ | ≤17 | launch callbacks, every other `UIApplicationDelegate` method forwarded (ObjC forwarding), a scene delegate class from its `configurationForConnecting` gets the scene callbacks SwiftUI does not handle. Tested (HelloScenes) |
| `UIHostingController` | ✅ | ≤17 | |
| `.onOpenURL` | 🟡 | ≤17 | delivered from isim's URL handling; inter-app routing unverified |
| `.onContinueUserActivity`, `.handlesExternalEvents` | ✅ | ≤17 | `.onContinueUserActivity` (Spotlight, universal links; queued until a handler registers), `.userActivity(_:isActive:_:)` advertises/indexes; `.handlesExternalEvents` accepted (one scene). Tested (HelloScenes) |
| `.backgroundTask` | 🟡 | ≤17 | `.appRefresh(id)` runs when the request is launched (script `bgtask BUNDLE ID`), also in a background launch; `.urlSession` accepted, not delivered. Tested (HelloScenes) |
| `openWindow` / `dismissWindow` | 🟡 | ≤17 | adapted: iPad + `UIApplicationSupportsMultipleScenes`: the requested `WindowGroup` replaces the window's content, `dismissWindow` goes back (isim shows one window per app); iPhone: ignored like iOS; `supportsMultipleWindows`. Tested (HelloScenes) |
| `#Preview` / `PreviewProvider` | ❌ | ≤17 | no preview canvas; `#Preview` does not compile |

### State & data flow

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `@State` | ✅ | ≤17 | stored per structural position |
| `@Binding`, `Binding(get:set:)`, `.constant`, dynamic-member bindings | ✅ | ≤17 | |
| `ObservableObject` + `@Published` | ✅ | ≤17 | isim Combine |
| `@StateObject`, `@ObservedObject` | ✅ | ≤17 | |
| `@EnvironmentObject`, `.environmentObject` | ✅ | ≤17 | |
| `@Environment(keyPath)`, custom `EnvironmentKey`, `.environment(_:_:)` | ✅ | ≤17 | |
| `@Observable` macro / Observation | ✅ | 17.0 | Observation built from Swift sources; macro via the toolchain plugin; renders track reads; tested (HelloObservation) |
| `@Bindable`, `@Environment(Model.self)` | ✅ | 17.0 | plus `.environment(_:)` for Observable objects; tested |
| `@AppStorage` | ✅ | ≤17 | Bool/Int/Double/String/URL/Data/RawRepresentable/optionals; persists; tested (HelloForms) |
| `@SceneStorage` | ✅ | ≤17 | saved with the scene's state restoration activity (Bool/Int/Double/String) and restored on the next launch unless the app was closed in the app switcher. Tested (HelloScenes) |
| `@FocusState` (Bool and Hashable) | ✅ | ≤17 | |
| `@Namespace` | ✅ | ≤17 | |
| `@GestureState` | ✅ | ≤17 | set through `.updating`, reset when the gesture ends or is cancelled; tested (HelloSwiftUIGestures) |
| `@ScaledMetric` | ✅ | ≤17 | scales with `dynamicTypeSize`, which follows Settings > Accessibility > Larger Text; tested (HelloLayout, HelloAccessibility) |
| `@FocusedValue`, `@FocusedBinding` | 🟡 | ≤17 | with `.focusedValue`/`.focusedSceneValue`; values are scene-wide (no per-focus chain, adapted); tested (HelloKeys) |
| `PreferenceKey`, `.preference`, `.onPreferenceChange`, anchor preferences | ✅ | ≤17 | values reduce up the laid-out tree (incl. GeometryReader backgrounds), `transformPreference`, `anchorPreference` / `transformAnchorPreference` with `overlayPreferenceValue` / `backgroundPreferenceValue` and `proxy[anchor]`; tested (HelloLayout) |
| `Transaction`, `withTransaction` | 🟡 | ≤17 | carries the animation / `disablesAnimations`; custom transaction keys missing |

### Views & controls

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `Text` (verbatim, `LocalizedStringKey` with interpolation, font/weight/italic/color) | ✅ | ≤17 | |
| `Text + Text` concatenation | ✅ | ≤17 | parts keep their own font/colour/weight; mixed styles laid out word by word (adapted); tested (HelloText) |
| `Text(date, style:)`, `Text(_:format:)`, `Text(timerInterval:)` | ✅ | ≤17 | `.time/.date/.relative/.offset/.timer` styles (relative ones re-render every second), date ranges, `Text(_:format:)` with Foundation format styles, `\(value, format:)` / `\(date, style:)` interpolation, `Text(_:formatter:)`; tested (HelloText) |
| Markdown in `Text`, `AttributedString` | ✅ | ≤17 | string literals parse `**bold**`, `*italic*`, `***both***`, `` `code` ``, `~~strike~~`, `[links](url)` (tap opens through `openURL`); `Text(AttributedString)` maps presentation intents, links and the SwiftUI attribute scope (`foregroundColor`, `font`, underline/strikethrough, kern, baselineOffset); tested (HelloText). Italic is a sheared glyph run (isim fonts have no italic faces) |
| `Text(Image)` (inline images in text, `Text + Text`, Canvas `draw(Text)`) | ✅ | ≤17 | symbols take the text's font size, weight and colour; laid out as words in rich text; tested (HelloSourceCompat). SF Symbols without a stand-in icon draw as a placeholder |
| `strikethrough`, `underline`, `kerning`, `tracking`, `textCase`, `baselineOffset` | ✅ | ≤17 | on `Text` and as view modifiers; lines are hairline views, kerning places glyphs one by one (`tracking` = `kerning`), line patterns drawn solid; tested (HelloText) |
| `lineLimit`, `multilineTextAlignment` | ✅ | ≤17 | |
| `truncationMode`, `minimumScaleFactor`, `allowsTightening` | 🟡 | ≤17 | head/middle/tail truncation of one-line text (tested), `minimumScaleFactor` shrinks one-line labels to fit (screenshot only); `allowsTightening` is stored, no effect |
| `Image` (asset/bundle name, `uiImage:`), `resizable`, `renderingMode`, `interpolation` | ✅ | ≤17 | |
| `Image(systemName:)` | 🟡 | ≤17 | the same stand-in drawings as `UIImage(systemName:)` (not Apple's SF Symbols); `.font` / `.fontWeight` set size and stroke weight |
| `imageScale`, `symbolRenderingMode`, `symbolVariant`, `symbolEffect` | 🟡 | ≤17 | `imageScale` sizes symbols (tested); `symbolVariant` appends `.fill`/`.circle`/... to the symbol name (unverified); `symbolRenderingMode` accepted, ignored; `symbolEffect` missing |
| `AsyncImage` | ✅ | ≤17 | URLSession (http(s), file, data URLs); phases, `content:placeholder:`; decoded through a temporary file (isim's UIImage has no `init(data:)`); tested (HelloPickers) |
| `Label` | ✅ | ≤17 | |
| `Button` (action, label, role) | ✅ | ≤17 | |
| Button styles: `.plain`, `.borderless`, `.bordered`, `.borderedProminent`, custom `ButtonStyle` | ✅ | ≤17 | |
| `PrimitiveButtonStyle`, `.controlSize`, `.buttonBorderShape` | ✅ | ≤17 | primitive styles build the whole button and call `trigger()`; control size sets bordered padding/font; capsule / rounded / circle shapes; tested (HelloPickers) |
| `Toggle` (switch) | ✅ | ≤17 | |
| `toggleStyle` (`.button`, `.checkbox`, custom) | ✅ | ≤17 | `.switch`, `.button` (tinted when on) and custom `ToggleStyle`s (`.checkbox` is macOS-only); `.button` tested (HelloPickers) |
| `Slider` | ✅ | ≤17 | UISlider; step, value labels, onEditingChanged; tested |
| `Stepper` | ✅ | ≤17 | value/bounds/step and onIncrement/onDecrement; tested |
| `Picker` (menu, segmented, wheel, inline, navigationLink styles) | ✅ | ≤17 | all five styles; `.wheel` is a snapping scroll-wheel drawn by isim (no UIPickerView); tested (HelloForms, HelloPickers) |
| `DatePicker`, `MultiDatePicker` | 🟡 | ≤17 | `DatePicker`: compact (date/time pills open a calendar or time wheel in a sheet — iOS uses a popover), graphical (month grid, month paging, time row), wheel; `.date` / `.hourAndMinute`; ranges; `labelsHidden`; tested (HelloPickers). `MultiDatePicker` missing |
| `ColorPicker` | 🟡 | ≤17 | colour well opening a sheet with iOS's colour grid and an opacity slider (no spectrum/sliders pages, no eyedropper); `Color` and `CGColor` bindings; tested (HelloPickers) |
| `TextField` (String binding, placeholder, `axis: .vertical` multi-line) | ✅ | ≤17 | `prompt` ignored |
| `TextField(value:format:)`, `TextField(value:formatter:)` | ✅ | ≤17 | parseable format styles and NumberFormatter / DateFormatter values, parsed on Return or end of editing (unparseable text reverts); tested (HelloPickers) |
| `SecureField` | ✅ | ≤17 | |
| `TextEditor` | ✅ | ≤17 | multi-line field that fills its frame; tested (HelloPickers) |
| `ProgressView` | ✅ | ≤17 | UIProgressView bar / spinning UIActivityIndicatorView; labels and current-value labels, `.linear` / `.circular` / custom `ProgressViewStyle`; label tested (HelloPickers) |
| `Gauge` | ✅ | ≤17 | linear capacity (default), `.accessoryLinear`, `.accessoryCircular`, `.accessoryCircularCapacity`, custom `GaugeStyle`; tested (HelloPickers) |
| `Link` | ✅ | ≤17 | opens through `openURL` |
| `ShareLink` | 🟡 | ≤17 | opens a share sheet showing the item; isim has no share destinations (adapted) ; tested (HelloPickers) |
| `Menu` | ✅ | ≤17 | pop-up menu with sections, submenus, pickers, destructive buttons; tested |
| `Divider`, `Spacer`, `EmptyView`, `Color` as a view | ✅ | ≤17 | |
| `LabeledContent` | ✅ | ≤17 | |
| `ContentUnavailableView` | ✅ | 17.0 | icon, title, description, actions; `.search` / `.search(text:)`; tested (HelloPickers) |
| `ControlGroup`, `GroupBox`, `DisclosureGroup`, `OutlineGroup` | ✅ | ≤17 | disclosure rows expand/collapse (own state or `isExpanded:` binding; in a List the content follows as indented rows); `OutlineGroup` and `List(_:children:)` build the tree; control groups share one bordered row (`controlGroupStyle` ignored); tested (HelloPickers) |
| `EditButton`, `PasteButton`, `RenameButton` | 🟡 | ≤17 | `EditButton` toggles `\.editMode` (tested, HelloLists); `PasteButton` is a stub (no pasteboard on isim: shown disabled, tested); `RenameButton` missing |
| `VideoPlayer` (AVKit), `Map` (MapKit), `SceneView` | 🟡 | ≤17 | `Map` (iOS 17 MapContent + iOS 14 `coordinateRegion` API) on isim's MKMapView: tested (HelloMaps). `VideoPlayer` see AVKit; `SceneView` missing |
| `SpriteView` | ✅ | ≤17 | see SpriteKit |

### Containers & layout

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `VStack`, `HStack`, `ZStack` (alignment, spacing) | ✅ | ≤17 | |
| `Spacer(minLength:)`, `layoutPriority`, `fixedSize` | ✅ | ≤17 | |
| `LazyVStack`, `LazyHStack` | 🟡 | ≤17 | laid out like plain stacks; `pinnedViews` ignored |
| `LazyVGrid` (`GridItem` fixed / flexible / adaptive) | 🟡 | ≤17 | `pinnedViews` ignored |
| `LazyHGrid` | ✅ | ≤17 | `init(rows:)` with fixed / flexible / adaptive rows, items flow down then across; laid out eagerly; tested (HelloLayout) |
| `Grid`, `GridRow` | ✅ | ≤17 | column widths from the widest cells, flexible cells share the rest; `gridCellColumns`, `gridColumnAlignment`, `gridCellAnchor`, `gridCellUnsizedAxes`, row alignment, full-width non-row views; tested (HelloLayout) |
| `ScrollView` (vertical, horizontal) | ✅ | ≤17 | |
| `ScrollViewReader`, `scrollTo` | ✅ | ≤17 | |
| `scrollIndicators`, `scrollDisabled`, `scrollBounceBehavior` | 🟡 | ≤17 | `scrollDisabled` tested (HelloLayout); hidden indicators and `.basedOnSize` bounce unverified |
| `scrollPosition`, `scrollTargetBehavior` (paging), `scrollTransition`, `onScrollGeometryChange` | 🟡 | ≤17 | `.paging` (UIScrollView paging), `.viewAligned` + `scrollTargetLayout()` (snaps to children), custom `ScrollTargetBehavior.updateTarget`, `scrollPosition(id:)` both ways; tested (HelloLayout). `scrollTransition`, `onScrollGeometryChange` missing |
| `List` (content builder, sections, data, selection) | 🟡 | ≤17 | inset-grouped look; `List(data)`, `List(data, children:)`, `List(selection:)` single (tested via NavigationSplitView) and multiple (circles in edit mode, unverified) |
| `listStyle`, `listRowBackground`, `listRowSeparator`, `listSectionSpacing`, `scrollContentBackground` | 🧩 | ≤17 | accepted, ignored |
| `.onDelete`, `.onMove`, `.swipeActions`, edit mode | ✅ | ≤17 | swipe to delete, leading/trailing swipe actions (tint, full swipe), edit mode delete buttons and reorder handles; tested (HelloLists) |
| `Form` | ✅ | ≤17 | inset-grouped rows; `formStyle` ignored |
| `Section` (header, footer) | ✅ | ≤17 | |
| `ForEach` (`id:`, `Identifiable`, `Range`) | ✅ | ≤17 | |
| `Group`, `AnyView`, `if`/`switch` in builders | ✅ | ≤17 | |
| `GeometryReader`, `GeometryProxy.size`, `frame(in: .local/.global)`, safe-area insets | ✅ | ≤17 | |
| Named coordinate spaces | 🟡 | ≤17 | `.named` falls back to global |
| `ViewThatFits` | ✅ | ≤17 | first child whose ideal size fits (per axis); tested (HelloLayout) |
| `Layout` protocol, `AnyLayout` | ✅ | ≤17 | `sizeThatFits` / `placeSubviews` with subviews' `sizeThatFits` / `dimensions` / `place(at:anchor:proposal:)`, caches, `layoutValue`; `AnyLayout` switching keeps child state; `HStackLayout` / `VStackLayout` / `ZStackLayout` / `GridLayout`; tested (HelloLayout). Spacing preferences are a fixed 8 pt; not animatable |
| `containerRelativeFrame` | 🟡 | ≤17 | relative to the nearest scroll view, else the window's safe area (navigation/tab content are not containers of their own); `count:span:spacing:` and closure forms; tested (HelloLayout) |
| `frame` (fixed, min/ideal/max, alignment), `padding`, `aspectRatio`, `offset` | ✅ | ≤17 | |
| `position`, `alignmentGuide` | ✅ | ≤17 | `position` centres the view at a point; explicit guides and custom `AlignmentID`s line up views in HStack / VStack / ZStack, also through nested stacks; tested (HelloLayout) |
| `ignoresSafeArea`, `edgesIgnoringSafeArea` | ✅ | ≤17 | |
| `safeAreaInset`, `safeAreaPadding`, `contentMargins` | 🟡 | ≤17 | `safeAreaInset` lays the inset view at the edge and the content in the rest (content does not scroll beneath it); `safeAreaPadding` is padding; `contentMargins` pads scroll view content; inset and margins tested (HelloLayout) |
| `overlay`, `background` (view, shape style, `in:` shape), `zIndex` | ✅ | ≤17 | |
| `Group(subviews:)`, `ForEach(subviews:)`, `containerValue`, `@Entry` | ❌ | 18.0 | |

### Navigation & presentation

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `NavigationStack` (root, path `[D]` / `NavigationPath`) | 🟡 | ≤17 | nav bar with large/inline title and back button; push/pop not animated, no edge-swipe back |
| `NavigationLink(destination:)`, `NavigationLink(value:)` | ✅ | ≤17 | |
| `navigationDestination(for:)` | ✅ | ≤17 | |
| `navigationDestination(isPresented:)`, `navigationDestination(item:)` | ✅ | ≤17 | pushes while presented; back / `dismiss` reset the binding; tested (HelloLists) |
| `NavigationView` | ✅ | ≤17 | stack style |
| `NavigationSplitView` | 🟡 | ≤17 | iPhone (compact) behaviour only: columns as a stack, a `List(selection:)` choice shows the next column; tested (HelloLists). No side-by-side columns (iPad), `columnVisibility` ignored |
| `navigationTitle`, `navigationBarTitleDisplayMode` | ✅ | ≤17 | |
| `navigationBarBackButtonHidden` | 🧩 | ≤17 | ignored |
| `.toolbar` with `ToolbarItem` / `ToolbarItemGroup` | 🟡 | ≤17 | top-bar leading/trailing only; `.principal`, `.bottomBar`, `.keyboard` not placed as on iOS |
| `toolbarBackground`, `toolbarColorScheme`, `toolbar(.hidden)` | 🟡 | ≤17 | `toolbar(.hidden, for: .navigationBar / .tabBar)` tested (HelloLists); bar background colour / visibility and colour scheme applied to the navigation bar (unverified) |
| `TabView` (tab bar, `.tabItem`, `.badge`, selection) | ✅ | ≤17 | material tab bar, SF Symbol items, badges, selection, iOS 18 `Tab`; tested |
| `TabView` `.tabViewStyle(.page)` | ✅ | ≤17 | swipe paging with page dots; tested |
| `.sheet(isPresented:)` / `.sheet(item:)` | ✅ | ≤17 | page sheet with swipe-down dismiss; content gets the environment + `dismiss`; tested (HelloPresentations) |
| `.fullScreenCover` | ✅ | ≤17 | slides up full screen; tested |
| `.popover` | 🟡 | ≤17 | shown as a sheet (iPhone behaviour); no arrow popovers on iPad |
| `.alert` | 🟡 | ≤17 | title, message, button roles (UIAlertController); no text fields in alerts; tested |
| `.confirmationDialog` | ✅ | ≤17 | action sheet with Cancel; tested |
| `presentationDetents`, `presentationDragIndicator`, `interactiveDismissDisabled` | 🟡 | ≤17 | adapted: sheets with detents other than `.large` are isim-drawn cards over a dimmed backdrop (`.medium`, `.large`, `.fraction`, `.height`; drag between detents or down to dismiss; selection binding); tested (HelloLists, HelloPickers). `interactiveDismissDisabled` on detent cards unverified |
| `@Environment(\.dismiss)` | ✅ | ≤17 | closes sheets / covers (tested, HelloPresentations), pops navigation levels and resets `navigationDestination` bindings (tested, HelloLists) |
| `.searchable` | 🟡 | ≤17 | search field under the List's large title (above other content), Cancel, `isSearching`, `dismissSearch`, `.onSubmit(of: .search)`; filtering and Cancel tested (HelloLists). Suggestions and scopes are ignored |
| `.refreshable` | ✅ | ≤17 | pull past 60 pt and release: spinner while the async action runs (List tested, HelloLists; ScrollView unverified) |
| `.inspector` | ✅ | 17.0 | presented as a sheet, as in compact width on iPhone; tested (HelloKeys) |
| `@Environment(\.openURL)` | ✅ | ≤17 | |
| `Tab(_:systemImage:value:role:)`, `TabRole.search` | 🟡 | 18.0 | with `--os 26`/`27` the search tab sits apart on its own glass circle; with 18 an ordinary tab; tested (HelloOSVersions) |
| `TabRole.prominent` | 🟡 | 27.0 | like `.search`: apart at the trailing end on a glass circle |
| `TabSection`, `.sidebarAdaptable` sidebar, `tabViewCustomization` | ❌ | 18.0 | `.sidebarAdaptable` is accepted and shows the tab bar |
| `navigationTransition(_:)` (`.automatic`, `.zoom(sourceID:in:)`), `matchedTransitionSource(id:in:)` | 🧩 | 18.0 | accepted; the default push/sheet animation is used |
| `NavigationTransition.crossFade` | 🧩 | 27.0 | accepted; the default animation is used |
| `presentationSizing` (`.form`, `.page`) | ❌ | 18.0 | |
| `tabBarMinimizeBehavior`, `tabViewBottomAccessory` | 🧩 | 26.0 | the tab bar stays expanded; the accessory is not shown |
| `ToolbarSpacer` | 🟡 | 26.0 | a fixed 8 pt gap or a flexible one |
| `visibilityPriority(_:)` on toolbar content, `ToolbarItemVisibilityPriority` | 🧩 | 27.0 | accepted; isim's bars do not overflow |
| `ToolbarOverflowMenu` | 🟡 | 27.0 | a trailing ellipsis menu with the content |
| `ToolbarItemPlacement.topBarPinnedTrailing` | 🟡 | 27.0 | same as `.topBarTrailing` |
| `toolbarMinimizationBehavior(_:for:)` | 🧩 | 27.0 | toolbars stay expanded |
| `ReadableDocument` / `WritableDocument` (URL-based documents) | ❌ | 27.0 | |
| `ArrangementView`, reserved regions, hinge (`onHingeChange`), vertical toolbars | ❌ | 27.1 | iPhone Duo APIs (iOS 27.1 beta) |

### Modifiers & visual effects

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `font`, `foregroundColor`, `foregroundStyle` (Color, `.primary`…`.quaternary`, `.tint`) | ✅ | ≤17 | |
| `tint`, `accentColor` | ✅ | ≤17 | |
| `opacity`, `hidden`, `disabled` | ✅ | ≤17 | |
| `cornerRadius`, `clipShape` (any shape; built-in shapes as a rounded clip, others clip to their path) | ✅ | ≤17 | custom-shape clip tested (HelloDrawing) |
| `clipped()` | 🧩 | ≤17 | returns the view unchanged |
| `mask` | 🟡 | ≤17 | clips to the mask's shape (any shape's path); no alpha masks |
| `shadow` | 🟡 | ≤17 | layer-shadow approximation |
| `rotationEffect`, `scaleEffect`, `offset` | ✅ | ≤17 | offset content is drawn and hit-tested at its new position |
| `transformEffect` | ✅ | ≤17 | |
| `rotation3DEffect` | ✅ | ≤17 | true perspective: the rotated corners define a homography drawn through the view's `transform3D` (y-axis rotation tested) |
| `projectionEffect`, `ProjectionTransform` | ✅ | ≤17 | non-affine transforms drawn with perspective through `transform3D` (unverified) |
| `GeometryEffect` (custom, animatable), `ignoredByLayout` | ✅ | ≤17 | custom shear tested |
| `blur`, `brightness`, `contrast`, `saturation`, `grayscale`, `colorMultiply`, `hueRotation`, `blendMode` | 🧩 | ≤17 | accepted, no effect |
| `drawingGroup`, `compositingGroup` | 🧩 | ≤17 | |
| `allowsHitTesting` | ✅ | ≤17 | |
| `contentShape` | 🧩 | ≤17 | ignored |
| `id(_:)` | ✅ | ≤17 | resets state |
| `tag` | ✅ | ≤17 | explicit, and implicit from ForEach ids |
| `statusBarHidden`, `preferredColorScheme` | ✅ | ≤17 | |
| `persistentSystemOverlays`, `defersSystemGestures` | 🧩 | ≤17 | |
| `sensoryFeedback` | 🧩 | ≤17 | no haptics |
| `keyboardType`, `autocorrectionDisabled`, `textInputAutocapitalization`, `submitLabel` | ✅ | ≤17 | keyboard type is stored only (see UIKit) |
| `textFieldStyle`, `labelStyle` | ✅ | ≤17 | `.roundedBorder` / `.plain` fields; `.iconOnly` / `.titleOnly` / `.titleAndIcon` and custom `LabelStyle`s; tested (HelloPickers) |
| `pickerStyle`, `datePickerStyle`, `progressViewStyle`, `gaugeStyle` | ✅ | ≤17 | see the controls above; tested (HelloForms, HelloPickers) |
| `ViewModifier`, `.modifier` | ✅ | ≤17 | |
| `redacted`, `privacySensitive` | 🟡 | ≤17 | `.redacted(reason: .placeholder)` draws text as grey bars (tested, HelloPickers); images are not redacted; `privacySensitive` has no effect |
| `badge`, `help`, `contextMenu` | 🟡 | ≤17 | `badge` on tabs and list rows, `contextMenu` (long press -> pop-up menu) tested (HelloLists); preview ignored; `help` missing |
| `glassEffect(_:in:)`, `Glass` (`.regular`, `.clear`, `.identity`, `tint`, `interactive`) | 🟡 | 26.0 | adapted: isim's glass drawing behind the view in rectangles, rounded rectangles, circles, capsules (other shapes: a capsule); no lensing; tested (HelloOSVersions) |
| `GlassEffectContainer`, `glassEffectID`, `glassEffectUnion` | 🟡 | 26.0 | shapes draw separately: no merging or morphing |
| `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)` | 🟡 | 26.0 | glass capsule (prominent: tinted, white label); bordered styles become capsules with `--os 26`/`27`; tested |
| `scrollEdgeEffectStyle(_:for:)`, `backgroundExtensionEffect()` | 🧩 | 26.0 | accepted, no effect |
| `Animatable()` macro, `Slider` tick marks, `TextEditor` with `AttributedString` | ❌ | 26.0 | |
| `swipeActionsContainer()`, `swipeActions` on any view (iOS 27 form), `reorderable()`, `reorderContainer(for:isEnabled:move:)` | ❌ | 27.0 | `swipeActionsContainer()` is accepted (stub); List rows keep their swipe actions |
| `asyncImageURLSession(_:)`, `AsyncImage(request:)` | 🟡 | 27.0 | the modifier is accepted (images load with the shared session); the request initializers are missing |

### Shapes, paths, gradients & materials

Shapes, paths, gradients and Canvas draw through libisim_host (cairo); tested by HelloDrawing (`tests/ui/drawing.sh`, pixel checks).

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `Rectangle`, `RoundedRectangle`, `Circle`, `Capsule` | ✅ | ≤17 | color fills use a view with a corner radius; other paints draw the path |
| Custom `Shape` (`path(in:)`) | ✅ | ≤17 | shape inits and `path(in:)` are not main-actor isolated, like SwiftUI |
| `Path` (move/line/quad/curve, `addArc` (center and tangent forms), `addRelativeArc`, rects, rounded rects, ellipses, `Path { }`, `Path(CGPath)`, `cgPath`) | ✅ | ≤17 | arcs become cubic curves |
| `Path` queries (`boundingRect`, `contains(_:eoFill:)`, `trimmedPath`, `applying`, `offsetBy`, string form) | ✅ | ≤17 | |
| `Path.strokedPath`, boolean operations (`union`, `intersection`, …), `Shape.union` etc. | ❌ | ≤17 | |
| `fill` (colors, any style, `FillStyle(eoFill:)`) | ✅ | ≤17 | |
| `stroke` / `stroke(style:)` with `StrokeStyle` (width, caps, joins, miter limit, dashes, dash phase) | ✅ | ≤17 | dashes tested; joins and miter limit unverified |
| `trim(from:to:)` | ✅ | ≤17 | exact on curves (arc length) |
| `Ellipse`, `UnevenRoundedRectangle` | ✅ | ≤17 | |
| `ContainerRelativeShape` | 🟡 | ≤17 | the frame's rectangle (isim has no container shapes) |
| `InsettableShape` (`inset(by:)`, `strokeBorder`) | ✅ | ≤17 | |
| `AnyShape` | ✅ | ≤17 | |
| Shape `.offset`, `.rotation`, `.scale`, `.transform`, `.size` | ✅ | ≤17 | offset and rotation tested; scale/transform/size unverified |
| `fill(_:).stroke(_:)` on a filled shape (iOS 17) | 🟡 | ≤17 | drawn as an overlay (unverified) |
| `LinearGradient`, `RadialGradient`, `AngularGradient` / `conicGradient`, `EllipticalGradient`, `Gradient` (colors, stops) | ✅ | ≤17 | as views and shape styles |
| Gradients in `fill`, `foregroundStyle`, `background`, `background(_:in:)`, `overlay` | ✅ | ≤17 | gradient strokes unverified |
| `Color.gradient` (`AnyGradient`) | ✅ | ≤17 | a top-to-bottom gradient a little lighter at the top (approximates Apple's) |
| Text with a gradient `foregroundStyle` | 🟡 | ≤17 | drawn in the gradient's first color (tested); no gradient across the glyphs |
| `Material` (`.ultraThinMaterial` … `.bar`) | ✅ | ≤17 | real backdrop blur (UIVisualEffectView) |
| `Color` (system colors, RGB/HSB/white, `Color(uiColor:)`, asset colors) | ✅ | ≤17 | |
| `ImagePaint` (`.image(_:sourceRect:scale:)`) | ✅ | ≤17 | tiles fills; image strokes are not drawn |
| `Canvas` / `GraphicsContext` (fill/stroke paths with colors, styles and gradients, text, images, transforms, opacity, clip, `drawLayer`) | ✅ | ≤17 | filters, blend modes, `clipToLayer` and symbols are accepted and not drawn |
| Shaders (`ShaderLibrary`, `.colorEffect`, `.layerEffect`, `.distortionEffect`) | ❌ | ≤17 | need Metal, which isim does not have |
| `MeshGradient`, `Color.mix(with:by:)` | ❌ | 18.0 | |

### Animation

Landed 2026-10-05 (commit d0dcb9b, `swift/overlays/SwiftUI/Animation.swift`): an animated update runs the view updates
inside UIKit's animation engine, so frames, opacity, transforms and colors interpolate. Animatable data (shape trims
and paths, custom `Animatable` shapes/views/modifiers, shape colors and gradients) interpolates per frame in the same
updates (`Animatable.swift`, same timing curves); HelloDrawing checks those half-way through a 2 s linear animation.

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `withAnimation` (incl. `completion:`) | ✅ | ≤17 | animates the next render (frames, opacity, transforms, colors) |
| `.animation(_:value:)` | ✅ | ≤17 | animates its subtree when the value changes |
| Curves & springs (`.easeInOut`, `.spring`, `.bouncy`, `.snappy`, `.smooth`, `timingCurve`, `interpolatingSpring`), repeat/delay/speed | 🟡 | ≤17 | mapped onto UIKit curves/springs; custom timing curves approximated (unverified) |
| Transitions (`.opacity`, `.scale`, `.slide`, `.move`, `.offset`, `.push`, `asymmetric`, `combined`) | 🟡 | ≤17 | insertion and removal play; each kind unverified |
| `matchedGeometryEffect` | 🟡 | ≤17 | an inserted view moves from the matched view's old frame; no simultaneous source/target |
| `contentTransition` (`.numericText`, `.interpolate`) | 🧩 | ≤17 | text content is not animated |
| Animating shape `trim`, paths, colors, gradients | ✅ | ≤17 | trim, custom path, fill color and gradient stops tested mid-animation |
| `Animatable` / `animatableData` (`VectorArithmetic`, `AnimatablePair`), `AnimatableModifier` | ✅ | ≤17 | custom shape and modifier tested; repeating animations of animatable data unverified |
| `phaseAnimator`, `PhaseAnimator` | ✅ | ≤17 | continuous cycling tested; `trigger:` form unverified |
| `keyframeAnimator`, `KeyframeAnimator`, `KeyframeTimeline` (`LinearKeyframe`, `SpringKeyframe`, `CubicKeyframe`, `MoveKeyframe`, `UnitCurve`) | ✅ | ≤17 | trigger form, linear/move/cubic values tested; spring keyframes and the repeating form unverified; keyframe velocities ignored |
| `TimelineView` (`.animation`, `.periodic`, `.everyMinute`, `.explicit`) | ✅ | ≤17 | `.periodic` and `.animation` tested; `.everyMinute`/`.explicit` unverified |

### Gestures

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `onTapGesture(count:)`, `TapGesture`, `onTapGesture(coordinateSpace:perform:)` | ✅ | ≤17 | |
| `onLongPressGesture`, `LongPressGesture` | ✅ | ≤17 | |
| `DragGesture` (`onChanged`/`onEnded`, translation, velocity, predicted end) | ✅ | ≤17 | UIKit recognizers on the wrapped view; `.local`/`.global` coordinate spaces; tested (HelloSwiftUIGestures, HelloDrawing) |
| `Optional: Gesture` (`.gesture(enabled ? g : nil)`) | ✅ | ≤17 | nil installs no recognizer; tested (HelloSourceCompat) |
| `simultaneousGesture`, `highPriorityGesture`, `simultaneously(with:)`, `sequenced(before:)`, `exclusively(before:)`, `map` | 🟡 | ≤17 | composition tested (HelloSwiftUIGestures: magnify+rotate together, long press before drag, double tap before single); `highPriorityGesture` and gesture masks behave like `.gesture` |
| `MagnifyGesture`, `RotateGesture` (+ `MagnificationGesture`, `RotationGesture`) | ✅ | ≤17 | two fingers from isim's multi-touch (Option-drag, script `pinch`/`rotate2`); magnification/rotation, velocity, start anchor/location; tested (HelloSwiftUIGestures) |
| `SpatialTapGesture` | ✅ | ≤17 | location in local/global space; tested (HelloSwiftUIGestures) |
| `sequenced`, `exclusively`, `simultaneously(with:)`, `.updating` | ❌ | ≤17 | |

### Lifecycle, async & events

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `onAppear`, `onDisappear` | ✅ | ≤17 | |
| `.task`, `.task(id:)` | ✅ | ≤17 | cancelled on disappear |
| `onChange(of:)` (old/new, `initial:`) | ✅ | ≤17 | |
| `Scene.onChange(of:initial:)` (e.g. `scenePhase`) | ✅ | ≤17 | adapted: wraps the scene's root view in `onChange`; tested (HelloSourceCompat) |
| `onReceive` | ✅ | ≤17 | |
| `onSubmit` | ✅ | ≤17 | |
| `onKeyPress`, `keyboardShortcut` | 🟡 | ≤17 | shortcuts on buttons become UIKeyCommands (incl. `defaultAction`/`cancelAction`); `onKeyPress` key/characters/phases forms; tested (HelloKeys). No focus routing: every onKeyPress on screen sees presses, innermost first (adapted) |
| `onGeometryChange`, `onContinuousHover`, `onHover` | 🟡 | ≤17 | `onGeometryChange` (size; `frame(in: .global)` is approximate) tested (HelloLayout); hover modifiers missing |

### Focus & keyboard

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `focused(_:)`, `focused(_:equals:)` | ✅ | ≤17 | |
| `focusable`, `defaultFocus`, `focusSection` | 🟡 | ≤17 | `defaultFocus` sets the focus binding on appear (tested, HelloKeys); `focusable`/`focusSection` accepted, no effect (no focus engine for non-text views) |
| `scrollDismissesKeyboard` | 🧩 | ≤17 | ignored |
| Form scrolls the focused field above the keyboard | ✅ | ≤17 | |

### Environment values

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `colorScheme`, `locale`, `font`, `isEnabled`, `lineLimit`, `multilineTextAlignment` | ✅ | ≤17 | |
| `horizontalSizeClass`, `verticalSizeClass`, `displayScale` | ✅ | ≤17 | |
| `layoutDirection` | 🟡 | ≤17 | value exists; RTL layout not implemented |
| `calendar`, `timeZone`, `dynamicTypeSize`, `colorSchemeContrast` | ✅ | ≤17 | `dynamicTypeSize` and `colorSchemeContrast` follow Settings > Accessibility (Larger Text, Increase Contrast); text styles (`.body`, `.headline`, …) scale with Dynamic Type; tested (HelloAccessibility) |
| `editMode`, `isPresented`, `isSearching`, `presentationMode` | 🟡 | ≤17 | `editMode` (a window-wide binding, or your own via `.environment`) and `isPresented` tested (HelloLists); `isSearching`, `presentationMode` unverified |
| `accessibilityReduceMotion` and other accessibility values | ✅ | ≤17 | `accessibilityReduceMotion`, `accessibilityReduceTransparency`, `accessibilityDifferentiateWithoutColor`, `accessibilityVoiceOverEnabled`, `legibilityWeight` from Settings > Accessibility; tested (HelloAccessibility). `accessibilityInvertColors` always false |
| `requestReview` | ✅ | ≤17 | see StoreKit |

### Accessibility

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `accessibilityIdentifier` | ✅ | ≤17 | |
| `accessibilityLabel` | ✅ | ≤17 | stored on the UIKit view |
| `.draggable`, `.dropDestination`, `.onDrag`, `.onDrop` | 🟡 | ≤17 | Transferable payloads / NSItemProviders through UIDragInteraction/UIDropInteraction (long press to lift); `isTargeted`; tested (HelloDragDrop: String draggable → dropDestination). Custom previews ignored |
| `accessibilityHint`, `accessibilityHidden` | ✅ | ≤17 | set on the mounted UIKit view; VoiceOver reads hints and skips hidden views; tested (HelloAccessibility) |
| `accessibilityValue`, `accessibilityAddTraits`, `accessibilityElement(children:)`, `accessibilityAction`, `accessibilityAdjustableAction`, `accessibilitySortPriority` | 🟡 | ≤17 | feed the UIKit accessibility tree (value, traits, `.combine`/`.ignore` label from the children's text, `.contain` grouping, default and named actions, adjustable increments, sort priority); tested (HelloAccessibility: value, header trait, combine, adjustable, hidden). Named actions and sort priority unverified |

### UIKit interop

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `UIViewRepresentable` (coordinator, update, dismantle) | ✅ | ≤17 | |
| `UIViewControllerRepresentable` | ✅ | ≤17 | |
| `UIHostingController` in UIKit apps | ✅ | ≤17 | |
| `sizeThatFits(_:uiView:context:)` on representables | ✅ | ≤17 | also `sizeThatFits(_:uiViewController:context:)`; tested (HelloKeys) |

---

## Swift Charts

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `Chart` view (`Chart { }`, `Chart(data) { }`, `ForEach` of marks, `if`/`else` content), `import Charts` | ✅ | ≤17 | isim's own implementation on its SwiftUI (`swift/overlays/Charts`; `if`/`else` content unverified); tested by HelloCharts (`tests/ui/charts.sh`, measured in the screenshot) |
| `BarMark` (vertical, horizontal, ranges, date bins with `unit:`, `width`/`height`) | ✅ | ≤17 | |
| Bar stacking (`.standard`), grouping (`position(by:)`) | ✅ | ≤17 | `.normalized`/`.center` stacking unverified |
| `LineMark` (`series:`, `interpolationMethod`), `PointMark` | ✅ | ≤17 | linear and catmullRom drawn in the test; step/cardinal/monotone unverified |
| `symbol(_:)`, `symbol(by:)`, `symbolSize` | 🟡 | ≤17 | basic symbol shapes (circle, square, triangle, diamond, pentagon, plus, cross); unverified; `symbol { view }` missing |
| `AreaMark` (stacked series, `yStart`/`yEnd`) | ✅ | ≤17 | stacking of several series unverified |
| `RuleMark`, `RectangleMark` | ✅ | ≤17 | |
| `SectorMark` (pie, donut `innerRadius`, `outerRadius`, `angularInset`) | ✅ | ≤17 | `angularInset` unverified; corner radius ignored |
| `PlottableValue.value(_:_:)`, `Plottable` (numbers, strings, dates, `RawRepresentable` enums) | ✅ | ≤17 | |
| `foregroundStyle(by:)` with the default palette and a legend, `chartForegroundStyleScale`, `chartLegend` | ✅ | ≤17 | `chartLegend(position: .top)` and custom legend content unverified |
| Axes: `chartXAxis`/`chartYAxis` (`.hidden`, `AxisMarks` position and values, `AxisGridLine`, `AxisTick`, `AxisValueLabel` with custom content), date axes | ✅ | ≤17 | `AxisTick` unverified; `AxisValueLabel(format:)` missing (no `FormatStyle` on isim) |
| Scales: `chartXScale`/`chartYScale(domain:)` (ranges, category lists, `.automatic(includesZero:reversed:)`) | ✅ | ≤17 | log/sqrt/power scale types are drawn linear |
| `annotation(position:alignment:spacing:)` | ✅ | ≤17 | |
| `chartXAxisLabel`, `chartYAxisLabel` | 🟡 | ≤17 | simple placement (unverified) |
| `chartOverlay`/`chartBackground` (`ChartProxy`), selection (`chartXSelection`), scrolling (`chartScrollableAxes`) | ❌ | ≤17 | |
| `chartPlotStyle`, vectorized plots (`BarPlot`, `LinePlot`, iOS 18), `Chart3D` | ❌ | 18.0 | |

---

## Foundation

isim's Foundation is self-authored: an Objective-C framework plus a Swift overlay (value types such as `Data`,
`Date`, `URL`, `Calendar` are pure Swift).

### Strings & text

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `String` ⇄ `NSString` bridging | ✅ | ≤17 | copies instead of lazy bridging |
| `NSString` / `NSMutableString` API (search, replace, case, trimming, components, paths) | 🟡 | ≤17 | search options (case/diacritic-insensitive, anchored, backwards, regex), Unicode case mapping, substring/line enumeration; comparisons are code-point ordered, not locale-aware |
| `String(format:)`, `NSLog` | ✅ | ≤17 | |
| String encodings (`data(using:)`, `String(data:encoding:)`, `String(contentsOf:)`) | ✅ | ≤17 | |
| `CharacterSet` | ✅ | ≤17 | BMP only |
| `NSAttributedString`, `NSMutableAttributedString` | ✅ | ≤17 | Foundation keys only (UIKit's font/color keys belong to UIKit); `mutableString` is a snapshot |
| `AttributedString`, `AttributeContainer`, attribute scopes, runs | 🟡 | ≤17 | Foundation scope (link, inline/presentation intents, imageURL, ...); no Codable, no iOS 17 invalidation/inheritance rules |
| `AttributedString(markdown:)` | 🟡 | ≤17 | CommonMark + GFM blocks/inlines as presentation intents; no reference links, extended attributes or source positions |
| `NSRegularExpression`, `NSTextCheckingResult` | ✅ | ≤17 | host PCRE2 (close to ICU syntax); templates, named groups, options |
| `NSDataDetector` | 🟡 | ≤17 | links, phone numbers, dates; addresses and transit info are not detected |
| `Scanner` | ✅ | ≤17 | ObjC and Swift (`scanString`, `scanInt`, `scanDouble`, `scanDecimal`, `currentIndex`) APIs |
| `String(localized:)`, `NSLocalizedString`, `Bundle.localizedString` | ✅ | ≤17 | |
| `LocalizedStringResource` | ✅ | ≤17 | Foundation's (also used by AppIntents); `String(localized:)` resolves it with the bundle/table/locale lookup, plurals included. Tested: HelloSharedData (en, ru) |
| String Catalogs (`.xcstrings`) | 🟡 | ≤17 | compiled to `.strings` + `.stringsdict`: plural variations and substitutions (`%#@name@`, `argNum`, `%arg`) keep every category; device/width variations use `other`/the first value. Tested: HelloSharedData (catalog compiled by isim build's compiler) |
| `.stringsdict` plural rules | ✅ | ≤17 | `NSStringPluralRuleType` with `zero` + CLDR integer categories for en, de, es, it, nl, sv, fr, pt (BR/PT), ru, uk, be, pl, cs, sk, hr, sr, ar, he, ro, ja, zh, ko, ...; applied by `localizedStringWithFormat:` / `stringWithFormat:` / `String(format:)` / `String(localized:)`, positional variables too. Isim finds the entry by the format text (strings bridge to Swift by copying). Tested: HelloSharedData |

### Collections & values

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `NSArray`, `NSDictionary`, `NSSet` (+ mutable), literals, fast enumeration, sorting | ✅ | ≤17 | |
| `NSOrderedSet`, `NSCountedSet`, `NSIndexSet` / `IndexSet`, `NSCache`, `NSHashTable`, `NSMapTable`, `NSPointerArray` | ✅ | ≤17 | `NSCache` evicts by count/cost limits only (no memory-pressure purging); weak tables use ObjC weak references |
| `IndexPath` / `NSIndexPath` (+ UIKit `row`/`section`/`item`) | ✅ | ≤17 | value type bridged to NSIndexPath; tested (HelloTable) |
| `NSNumber`, `NSValue` (CG geometry), `NSNull` | ✅ | ≤17 | |
| `UUID` | ✅ | ≤17 | |
| `Decimal` | 🟡 | ≤17 | 38 significant digits, exact arithmetic, `NSDecimalRound`/`NSDecimalAdd`..., `pow`; no `NSDecimalNumber`, does not bridge to an Objective-C object |
| `NSError`, `LocalizedError`, `CustomNSError`, `RecoverableError`, `CocoaError` | ✅ | ≤17 | Swift errors bridge through the Swift runtime's NSError box: `domain`/`code` from the error (raw values, `errorDomain`/`errorCode`), `userInfo` from `errorUserInfo` + `errorDescription`/`failureReason`/`recoverySuggestion`/`helpAnchor` + recovery options; `localizedDescription` matches iOS (default "The operation couldn’t be completed. (domain error n.)"); `as? MyError` works after a round trip through Objective-C; NSErrors of the Cocoa / URL domains bridge to `CocoaError` / `URLError` (`catch CocoaError.fileReadNoSuchFile`); `NSError.setUserInfoValueProvider(forDomain:)`, `localizedRecoverySuggestion`, `localizedRecoveryOptions`, `helpAnchor`, `underlyingErrors`. Tested (tests/swift-foundation, tests/foundation). `POSIXError`/`MachError` missing |
| `NSPredicate`, `NSExpression` (format strings, `filtered(using:)`) | 🟡 | ≤17 | comparisons, string operators (`CONTAINS[cd]`, `LIKE`, `MATCHES`, ...), aggregates, `ANY`/`ALL`, key paths, block predicates; no subqueries or function expressions; the `#Predicate` macro is not available |
| `NSSortDescriptor`, `SortDescriptor`, `KeyPathComparator`, `sorted(using:)` | ✅ | ≤17 | |
| Key-value coding (`value(forKey:)`, key paths, collection operators) and observing (KVO, `observe(\.x)`, `publisher(for:)`) | ✅ | ≤17 | KVO wraps setters; `@objc dynamic` Swift properties observable |
| `UndoManager` | ✅ | ≤17 | groups, run-loop grouping, redo, action names, `registerUndo(withTarget:handler:)` |
| `Progress` | 🟡 | ≤17 | units, children, KVO on `fractionCompleted`, localized description; no publishing/file progress |

### Encoding & serialization

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `JSONEncoder` / `JSONDecoder` (key/date/data/float strategies, output formatting) | ✅ | ≤17 | |
| `JSONSerialization` | ✅ | ≤17 | NSNumber/NSNull like Apple |
| `PropertyListEncoder` / `PropertyListDecoder` | ✅ | ≤17 | XML and binary |
| `PropertyListSerialization` | ✅ | ≤17 | XML, binary, OpenStep (read) |
| Reading XML plists (`NSDictionary(contentsOfFile:)`, Info.plist) | ✅ | ≤17 | |
| Binary plists | ✅ | ≤17 | read and written (Info.plist, user defaults, serialization) |
| `NSKeyedArchiver` / `NSKeyedUnarchiver`, `NSCoding`, `NSSecureCoding` | ✅ | ≤17 | Apple's keyed-archive format (bplist `$objects`/`$top`), shared references and cycles, allowed classes, class name mapping |
| `ValueTransformer` (`NSValueTransformer`), `NSSecureUnarchiveFromDataTransformer` | ✅ | ≤17 | named registry (class names register on first use), negate/is-nil built-ins, keyed-archive transformers. Tested: CoreDataTest |

### Dates, calendars & formatters

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `Date`, `TimeInterval`, `Date.now` | ✅ | ≤17 | |
| `Calendar`, `DateComponents`, `DateInterval` | 🟡 | ≤17 | Gregorian + ISO 8601; other calendars compute as Gregorian |
| `TimeZone` (named zones, DST) | ✅ | ≤17 | Settings > Date & Time or the host's zone; changes apply live (`NSSystemTimeZoneDidChange`, `resetSystemTimeZone`) |
| `Locale` (identifiers, language/region, separators, currency, `Locale.Language`) | ✅ | ≤17 | |
| `DateFormatter` (styles, `dateFormat`, templates, parsing) | 🟡 | ≤17 | built-in CLDR subset: en, pt, es, fr, de, it, ja names and ~40 regions; other languages fall back to English names |
| `NumberFormatter` (decimal, currency, percent, scientific, spell-out, ordinal, rounding, parsing) | 🟡 | ≤17 | ICU-style rounding; locale data limited to the built-in regions; spell-out English only |
| `ISO8601DateFormatter` | ✅ | ≤17 | |
| `RelativeDateTimeFormatter`, `DateComponentsFormatter`, `DateIntervalFormatter` | 🟡 | ≤17 | localized for the built-in languages |
| `.formatted()` / `FormatStyle` (dates, ISO 8601, relative, intervals, numbers, currency, percent, lists, byte counts, durations, measurements) and parse strategies | 🟡 | ≤17 | follows the device region; same locale data limits as the formatters |
| `Measurement`, `Unit*`, `MeasurementFormatter` | 🟡 | ≤17 | 22 unit families with conversion; locale-preferred units for length, mass, temperature, speed, volume; unit names localized for the built-in languages |
| `ByteCountFormatter`, `PersonNameComponentsFormatter`, `ListFormatter` | ✅ | ≤17 | |

### Files, bundles & preferences

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| App sandbox container (Documents, Library, Caches, tmp) | ✅ | ≤17 | per app, under `ISIM_DATA` |
| `FileManager` (exists, create, remove, copy, move, list, `urls(for:in:)`, temporary directory) | 🟡 | ≤17 | no attributes, enumerators, symlinks, `replaceItem` |
| `Data(contentsOf:)`, `Data.write(to:)` | ✅ | ≤17 | |
| `FileHandle`, `InputStream` / `OutputStream` | 🟡 | ≤17 | files, memory and standard I/O; `readabilityHandler` on a thread; no sockets / bound stream pairs |
| App Group containers (`containerURL(forSecurityApplicationGroupIdentifier:)`) | ✅ | ≤17 | `<isim data>/Shared/AppGroup/<id>`, shared by apps and their extensions; `UserDefaults(suiteName:)` uses it. Tested (HelloWidgets: the widget extension and the app share a counter) |
| iCloud Drive / ubiquity containers (`url(forUbiquityContainerIdentifier:)`, `ubiquityIdentityToken`) | 🟡 | ≤17 | **local, no iCloud sync**: `<isim data>/Mobile Documents/<container>/Documents`; nil when `ISIM_ICLOUD=noAccount`. No `NSMetadataQuery`, file coordination or download states. Tested: HelloSharedData |
| `Bundle` (main, by path/id, resources, Info.plist, localizations) | ✅ | ≤17 | |
| `UserDefaults` (standard, suites, register defaults, argument domain) | ✅ | ≤17 | persisted as an XML plist in the container |
| `NSUbiquitousKeyValueStore` | ✅ | ≤17 | **local, no iCloud sync**: a plist per store under `<isim data>/Mobile Documents/KeyValueStore`; another process (or the host) writing it posts `didChangeExternallyNotification` (server change, changed keys) within 0.5 s. Tested: HelloSharedData |

### Notifications, timers & threads

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `NotificationCenter` (selector, block, Combine publisher) | ✅ | ≤17 | |
| `NotificationQueue` | ✅ | ≤17 | `.now`, `.asap` (end of the run-loop pass), `.whenIdle` (shortly after), coalescing on name/sender, `dequeueNotifications`; one queue per thread. Tested: HelloSharedData |
| `DistributedNotificationCenter` | N/A | ≤17 | macOS only (not in the iOS SDK) |
| `Timer` (block / target-selector, repeating, `RunLoop.add`) | ✅ | ≤17 | the run loop keeps scheduled timers alive until invalidated |
| `RunLoop` | 🟡 | ≤17 | main run loop only; modes ignored |
| `Thread` (main checks, detach, sleep, name) | ✅ | ≤17 | |
| `OperationQueue` | 🟡 | ≤17 | block operations only; no `Operation` subclasses or dependencies |
| `NSLock`, `NSRecursiveLock`, `NSCondition` | ✅ | ≤17 | |
| `ProcessInfo` (environment, arguments, processor count, uptime) | ✅ | ≤17 | |
| `ProcessInfo.thermalState`, `isLowPowerModeEnabled`, `physicalMemory`, `operatingSystemVersion`, activities | ✅ | ≤17 | a simulated iPhone: always `.nominal`, never Low Power Mode, memory per device model |

### Networking

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `URL` (parsing, components, file URLs, path helpers, percent encoding) | ✅ | ≤17 | RFC 3986 relative resolution, IPv6 hosts, `appending(queryItems:)`, `init(string:encodingInvalidCharacters:)` |
| `URLComponents`, `URLQueryItem` | ✅ | ≤17 | parse/build, percent-encoded and decoded accessors, `queryItems` encoding like Apple's (`+` kept); tested |
| `URLRequest` (method, headers, body, timeout, cache policy, cookies flag) | ✅ | ≤17 | tested |
| `URLResponse`, `HTTPURLResponse` (status, `allHeaderFields`, `value(forHTTPHeaderField:)`, MIME type, length) | ✅ | ≤17 | tested |
| `URLError` (codes, `failingURL`, `catch URLError.code`, NSError bridging) | ✅ | ≤17 | host errors mapped (refused, DNS, timeout, TLS, offline, cancelled); tested |
| `URLSession` data/download/upload tasks (completion and async) | ✅ | ≤17 | Swift API; HTTP/HTTPS through the host's libcurl (dlopen'd, needed at run time); handlers on the session's background `delegateQueue`; cancellation; redirects; `ISIM_NETWORK=offline` simulates no network; tested (self-test + HelloNetwork) |
| `URLSession` delegates (data, download, redirect, completion) | ✅ | ≤17 | Swift protocols with default implementations (Apple's are `@objc` optional methods); tested; `didCreateTask`, `willCacheResponse` unverified |
| `bytes(from:)` / `bytes(for:)`, `AsyncBytes.lines` | ✅ | ≤17 | `lines` skips empty lines like Apple's; tested |
| `URLSessionConfiguration` (`.default`, `.ephemeral`, timeouts, extra headers, cache/cookie settings) | ✅ | ≤17 | `timeoutIntervalForRequest` is an idle timeout as on iOS; `waitsForConnectivity`, `allowsCellularAccess` and service types are stored only |
| `file:` and `data:` URLs in `URLSession` | ✅ | ≤17 | tested |
| `URLSessionWebSocketTask` | 🟡 | ≤17 | send/receive text and data, ping, close codes; needs a libcurl with WebSocket support (7.86+); the negotiated subprotocol is not reported; tested (text echo); ping and close handshake unverified |
| Authentication challenges (`didReceive challenge`, `URLCredential`, `URLProtectionSpace`), certificate pinning | 🟡 | ≤17 | HTTP Basic and Digest (MD5, qop=auth) through the task delegate (completion and async forms), `previousFailureCount`, `URLCredentialStorage` default credentials (in memory), 401 without a credential; server-trust challenge before each HTTPS request (`.useCredential` + `URLCredential(trust:)` accepts the certificate, cancel → -999). Adapted: `SecTrust` names the host only, so certificate pinning cannot inspect certificates; no client certificates, NTLM or proxies. Tested (HelloConnections) |
| `URLSessionTaskMetrics`, task `progress`, resumable downloads (`resumeData`) | ✅ | ≤17 | metrics per transaction from libcurl timings (lookup, connect, TLS, request, response; protocol, addresses, reused connection, local-cache loads), redirect count; `progress` (bytes, KVO `fractionCompleted`); `cancel(byProducingResumeData:)`, failed downloads' `NSURLSessionDownloadTaskResumeData`, `downloadTask(withResumeData:)` with `Range`/`If-Range` and `didResumeAtOffset`. Tested (HelloConnections). Resumable uploads not supported |
| Background `URLSession` | 🧩 | ≤17 | `background(withIdentifier:)` sessions run like default sessions while the app runs |
| `HTTPCookie`, `HTTPCookieStorage` | ✅ | ≤17 | Set-Cookie parsing (domain, path, expiry, secure); `shared` persists in the app container; ephemeral sessions get a private jar; tested; accept policies unverified |
| `URLCache`, `CachedURLResponse` | 🟡 | ≤17 | in memory only (nothing written to disk); max-age/Expires/heuristic freshness, ETag/Last-Modified revalidation, request cache policies; tested |
| Objective-C `NSURLSession`, `NSURLRequest`, `NSURLComponents`, `NSHTTPCookie` | ❌ | ≤17 | the networking API is Swift-only |

---

## Swift runtime, stdlib & concurrency

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Swift 6.2 language and `libswiftCore` (stdlib + runtime, ObjC interop) | ✅ | ≤17 | built on Linux from swift-6.2.4 sources |
| Reflection (`Mirror`, type names), dynamic casts, existentials | ✅ | ≤17 | |
| Swift classes subclassing Objective-C classes, `@objc`, `#selector` | ✅ | ≤17 | |
| `SIMD` vector types | ✅ | ≤17 | |
| Unicode-correct `String` / `Character` | ✅ | ≤17 | stdlib |
| `async`/`await`, `Task`, cancellation | ✅ | ≤17 | tested |
| `actor`, `@MainActor`, `MainActor.run` | ✅ | ≤17 | tested |
| `withTaskGroup`, `withThrowingTaskGroup`, `async let` | ✅ | ≤17 | |
| `@TaskLocal` | ✅ | ≤17 | tested |
| Continuations (`withCheckedContinuation`) | ✅ | ≤17 | tested |
| `AsyncSequence`, `AsyncStream`, `AsyncThrowingStream` | ✅ | ≤17 | |
| `Clock`, `ContinuousClock`, `Duration`, `Task.sleep(for:)` | ✅ | ≤17 | tested |
| Swift 6 strict concurrency checking | ✅ | ≤17 | compile time |
| Observation (`@Observable`, `withObservationTracking`) | ✅ | 17.0 | libswiftObservation (upstream sources, isim pthread hooks) |
| `Regex`, regex literals, `RegexBuilder` (`_StringProcessing`) | ✅ | ≤17 | built from swift-experimental-string-processing (swift-6.2.4); bare `/.../` literals need `-enable-bare-slash-regex` or Swift 6 mode like Xcode |
| `Synchronization` (`Mutex`, `Atomic`, `WordPair`, `AtomicLazyReference`) | ✅ | ≤17 | built from the Swift 6.2.4 sources (iOS 18+ like Apple); `Mutex` on isim's `os_unfair_lock`; 128-bit atomics. Tested: SwiftExtrasTest |
| Distributed actors (`Distributed`, `LocalTestingDistributedActorSystem`) | ✅ | ≤17 | built from the Swift 6.2.4 sources; distributed calls, `resolve(id:using:)`, thrown errors. Tested: SwiftExtrasTest |
| C++ interop (`-cxx-interoperability-mode=default`) | 🟡 | ≤17 | user C++ (structs, classes, operators, static members, `enum class`, templates through inline functions, `.cpp` code) works; the C++ standard library is not importable (`import CxxStdlib`, `std::string`/`std::vector`: libc++'s headers do not build as a Clang module against isim's C headers). Tested: tests/swift-cxx |
| Swift macros from packages | 🟡 | ≤17 | `@Observable` works (toolchain plugin); `#Preview` and package macro targets unverified |

### Combine

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `Publisher`, `Subscriber`, `Subscription`, demand | ✅ | ≤17 | isim's own implementation |
| `PassthroughSubject`, `CurrentValueSubject` | ✅ | ≤17 | |
| `@Published`, `ObservableObject`, `objectWillChange` | ✅ | ≤17 | |
| `Just`, `Future`, `Deferred`, `Empty`, `Fail`, `Publishers.Sequence` | ✅ | ≤17 | |
| `sink`, `assign(to:on:)`, `assign(to:)`, `AnyCancellable`, `store(in:)` | ✅ | ≤17 | |
| `map`, `tryMap`, `compactMap`, `filter`, `flatMap`, `removeDuplicates`, `first`, `prefix`, `dropFirst` | ✅ | ≤17 | |
| `merge`, `combineLatest`, `debounce`, `receive(on:)`, `share`, `handleEvents`, `eraseToAnyPublisher`, `setFailureType` | ✅ | ≤17 | |
| `autoconnect`, `ConnectablePublisher` | ✅ | ≤17 | |
| `zip`, `scan`, `reduce`, `collect` (all / count / time), `delay`, `throttle`, `timeout`, `buffer`, `count`, `min`/`max`, `contains`, `allSatisfy`, `first(where:)`, `last`, `output(at:/in:)`, `prefix`/`drop(while:)`, `drop`/`prefix(untilOutputFrom:)`, `append`/`prepend`, `measureInterval`, `subscribe(on:)`, `multicast`/`makeConnectable`, `Record`, `MergeMany`, `CombineLatest3/4`, `Zip3/4`, `try*` variants | ✅ | ≤17 | operators take unlimited demand upstream and queue for the subscriber (Apple propagates demand); `Publishers.Sequence` is lazy and demand-driven. Tested: SwiftExtrasTest |
| `catch`, `tryCatch`, `retry`, `replaceError`, `replaceEmpty`, `mapError`, `assertNoFailure`, `switchToLatest`, `flatMap(maxPublishers:)`, `decode`/`encode` (JSON/property-list coders are `TopLevelDecoder`/`Encoder`) | ✅ | ≤17 | Tested: SwiftExtrasTest |
| `.values` (`AsyncPublisher` / `AsyncThrowingPublisher`), `print`, `breakpoint`, `handleEvents` (all hooks) | ✅ | ≤17 | `.values` buffers (Apple requests one value per `next()`, so a fast PassthroughSubject loses values there, not on isim). Tested: SwiftExtrasTest |
| Foundation publishers: `Timer.publish`, `NotificationCenter.publisher`; RunLoop/DispatchQueue schedulers | ✅ | ≤17 | |
| `URLSession.dataTaskPublisher` | ✅ | ≤17 | tested |
| KVO publisher (`publisher(for: \.keyPath)`) | ✅ | ≤17 | Foundation KVO; tested with `AVPlayer.timeControlStatus` (HelloVideo) |

### Dispatch

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Main, global and custom serial/concurrent queues, `async`/`sync`/`asyncAfter` | ✅ | ≤17 | |
| Barriers, `DispatchWorkItem`, `dispatchPrecondition`, queue-specific values | ✅ | ≤17 | |
| `DispatchGroup`, `DispatchSemaphore`, `concurrentPerform` / `dispatch_apply` | ✅ | ≤17 | |
| Timer sources (`DispatchSource.makeTimerSource`) | ✅ | ≤17 | |
| User-data (add/or/replace), read/write, signal, process, file-system-object and memory-pressure sources; registration handlers | 🟡 | ≤17 | a monitor thread polls fds; process exit via `kill(pid, 0)` and file events via `fstat` every 50 ms (renames via /proc); write sources report 1, not the free space; memory pressure and Mach sources never fire. Tested: SwiftExtrasTest |
| `DispatchData`, `DispatchIO` (stream / random, `read`/`write`, high/low water, `close`, class `read`/`write`) | 🟡 | ≤17 | Swift API only (no C `dispatch_data_t`/`dispatch_io_t`); `setInterval` ignored. Tested: SwiftExtrasTest |

---

## Objective-C runtime & C library

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Message sending, classes, categories, protocols, `+load`/`+initialize` | ✅ | ≤17 | |
| ARC, weak references, autorelease pools, blocks | ✅ | ≤17 | |
| Associated objects, method swizzling (`method_exchangeImplementations`), introspection | ✅ | ≤17 | |
| `@synchronized`, properties, fast enumeration | ✅ | ≤17 | |
| Objective-C literals (`@[…]`, `@{…}`, `@42`, `@2.5`, `@YES`, boxed `@(…)`), including clang 23's constant literals: `NSConstantArray`, `NSConstantDictionary`, `NSConstantIntegerNumber`/`NSConstantDoubleNumber`/`NSConstantFloatNumber`, `__kCFBooleanTrue`/`__kCFBooleanFalse`, `__NSArray0__struct`/`__NSDictionary0__struct` | ✅ | ≤17 | static objects in the app's data segment; they are immortal (retain/release/autorelease do nothing, `copy` returns them) and are full NSArray/NSDictionary/NSNumber instances: equality and hashes match objects built at run time, fast enumeration, `mutableCopy`, KVC, keyed archives (archived as NSArray/NSDictionary/NSNumber), property lists, JSON, `description`, Swift bridging (`as! [Any]`, `as? [String: Any]`, `as? Int/Double/Float/Bool`). File-scope literals (`static NSArray *t = @[…]`) work. `+numberWithBool:` returns the kCFBoolean singletons, as on iOS. A key written twice in one constant dictionary literal (clang warns) is kept twice; lookups return the last value. Tested: tests/objc-literals (built with clang 23, or the committed prebuilt app with older clangs) |
| Dynamic method resolution (`+resolveInstanceMethod:`, `+resolveClassMethod:`), property introspection (`class_getProperty`, `class_copyPropertyList`, `property_getAttributes`) | ✅ | ≤17 | also consulted by `respondsToSelector:` / `class_getMethodImplementation`. Tested: CoreDataTest (`@NSManaged` accessors) |
| Message forwarding (`forwardingTargetForSelector:`, `methodSignatureForSelector:`/`forwardInvocation:`, `doesNotRecognizeSelector:`, `_objc_msgForward(_stret)`) | ✅ | ≤17 | lookup misses go to forwarding trampolines that capture the x86_64 argument registers + stack; int/char/short/BOOL/long, float/double, small structs (CGPoint, CGSize, NSRange, mixed int/float), stack-spilled args, `CGRect`/large-struct `stret` results; class methods too; unrecognized selectors raise `NSInvalidArgumentException` (iOS message). `respondsToSelector:` does not consult forwarding (like iOS). x87 `long double` results unsupported. Tested: tests/objc-runtime |
| `NSMethodSignature`, `NSInvocation` (`invoke`, `invokeWithTarget:`, `invokeUsingIMP:`, get/set argument & return value, `retainArguments`), `NSGetSizeAndAlignment` | ✅ | ≤17 | SysV classification of ObjC type encodings; Swift-unavailable as on iOS. Tested: tests/objc-runtime |
| `NSProxy` | ✅ | ≤17 | root class; `isKindOfClass:`/`isMemberOfClass:`/`respondsToSelector:`/`conformsToProtocol:` forwarded as invocations. Tested: tests/objc-runtime (proxies to a custom class and to `NSMutableString`) |
| `@try`/`@catch`/`@finally`/`@throw`, `@throw;` rethrow, `NSException` `raise`, `@synchronized` unlock on throw, ARC cleanups (`-fobjc-arc-exceptions`) | ✅ | ≤17 | host libgcc two-phase unwinder over FDEs synthesized from each image's compact unwind info (`__unwind_info`; DWARF-mode entries re-encoded from `__eh_frame`), `__objc_personality_v0` LSDA parser, `OBJC_EHTYPE` class matching; nested, rethrown and other-thread exceptions, exceptions passing through forwarding/`NSInvocation` frames. Swift async frames are not unwound. Tested: tests/objc-runtime |
| Uncaught exceptions (`*** Terminating app due to uncaught exception …`, first throw call stack, `NSSetUncaughtExceptionHandler`, `callStackReturnAddresses`/`callStackSymbols`) | ✅ | ≤17 | SIGABRT like iOS; an NSException raised by ObjC code called from Swift is not catchable by Swift `do/catch` (same as iOS) and terminates with the report. Tested: tests/objc-runtime (ObjCUncaught, SwiftUncaught) |
| C++ exceptions (`throw`/`try`/`catch`) | 🟡 | ≤17 | C++ frames (`__gxx_personality_v0`) run cleanups and `catch (...)` for Objective-C exceptions passing through (unverified); throwing C++ exceptions needs a libc++abi built with exceptions/RTTI (isim's libc++ is `-fno-exceptions`); the `_Unwind_*` entry points are already exported for it |
| libc / POSIX (stdio, malloc, string, pthreads, time, files) | ✅ | ≤17 | host glibc with Darwin layouts |
| `pipe`, `pread`/`pwrite`, `dup`/`dup2`, `kill`, `signal`/`raise` with Darwin signal numbers (`SIGUSR1` = 30, ...); Swift `open`/`fcntl`/`ioctl` and `SIG_IGN`/`SIG_DFL` | ✅ | ≤17 | numbers translated to the host's and back for handlers. Tested: SwiftExtrasTest (pipe sources, `raise(SIGUSR1)`) |
| `errno` from Swift | ✅ | ≤17 | provided by the Foundation overlay (no Swift Darwin overlay) |
| `dlopen` of app-bundled dylibs/frameworks | 🟡 | ≤17 | used for keyboard extensions; embedded frameworks unverified |
| Mach APIs (`mach_absolute_time` ✅; ports, tasks) | 🟡 | ≤17 | timing only |

---

## Core Graphics

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Geometry (`CGRect`/`CGPoint`/`CGSize` functions, Swift helpers) | ✅ | ≤17 | `CGFloat` is a typealias of `Double` |
| `CGAffineTransform` | ✅ | ≤17 | |
| `CGContext` paths: rects, ellipses, arcs, lines, curves; fill, EO fill, stroke | ✅ | ≤17 | via host cairo; even-odd fill tested (HelloDrawing) |
| Graphics state, CTM (translate/scale/rotate/concat), alpha, line width/cap/join/miter limit | ✅ | ≤17 | caps/joins/miter limit unverified |
| Clipping (`clip`, `clip(using: .evenOdd)`, `clip(to: rect)`) | ✅ | ≤17 | even-odd clip unverified |
| `CGPath` / `CGMutablePath` (build, bounding box, contains, apply) | ✅ | ≤17 | |
| `CGColor` (RGB, gray, copy with alpha, components in their space, `converted(to:)`) | ✅ | ≤17 | gray colors keep 2 components; tested (HelloQuartz) |
| `CGColorSpace` (sRGB, Display P3, linear, gray, CMYK, pattern) | 🟡 | ≤17 | colors in other spaces are converted to sRGB for drawing (P3 exact conversion, out-of-gamut clamped; no wide-color output); tested (HelloQuartz) |
| Pattern colors (`CGPattern`, `setFillPattern`) | 🟡 | ≤17 | colored patterns: the cell is drawn once (2x) and tiled; pattern space is relative to the current CTM; tested (HelloQuartz). Uncolored patterns and stroke patterns unverified |
| `CGImage` (from UIImage, crop, draw into context) | ✅ | ≤17 | decoded by the host |
| `CGImage` from raw bytes (`CGDataProvider`, `CGImageCreate`, `CGImageMaskCreate`, `masking`, `dataProvider`) | ✅ | ≤17 | 8 bits per component (RGB(A/X) in any order, gray, gray+alpha, alpha only, masks, decode arrays); 16-bit/float layouts are refused with a log; decoded images report premultiplied RGBA bytes; tested (HelloQuartz) |
| `CGBitmapContext` (`CGContext(data:...)`, pixel read/write, `makeImage`) | ✅ | ≤17 | draws into app memory (zero-copy for BGRA/A8, converted in/out for RGBA and gray), y-up like iOS; `UIGraphicsPushContext` makes UIKit draw into it; tested (HelloQuartz) |
| `CGGradient`, `CGShading` (`CGFunction`) | ✅ | ≤17 | linear/radial with before/after extension; shadings sampled at 64 steps; tested (HelloQuartz). One-sided radial extension approximated |
| Line dashes (`setLineDash`) | ✅ | ≤17 | tested (HelloDrawing) |
| Shadows (`setShadow`) | 🟡 | ≤17 | operations drawn as a group, alpha blurred with a 3-pass box blur and offset in base space; tested (HelloQuartz). On PDF contexts the shadow is not blurred |
| Blend modes, transparency layers | ✅ | ≤17 | blend modes map to cairo operators (`plusDarker` approximated); layers composite with the outer alpha/shadow; multiply and layer tested (HelloQuartz) |
| Clip to mask (`clip(to:mask:)`) | ✅ | ≤17 | alpha of masks with alpha, luminance of opaque masks; tested (HelloQuartz) |
| Text drawing in CG (Core Text lines/frames, text matrix/position) | ✅ | ≤17 | glyphs drawn y-up through the text matrix (upside down in UIKit's flipped space, as on iOS); `CGContextShowTextAtPoint` (deprecated) unverified; text drawing modes other than fill/invisible draw as fill |
| `CGContext` queries (`ctm`, `boundingBoxOfClipPath`, `path`, `isPathEmpty`, conversions) | 🟡 | ≤17 | unverified; `replacePathWithStrokedPath` is a no-op |
| PDF contexts (`CGContext(consumer:mediaBox:)`, `beginPDFPage`, `closePDF`) | ✅ | ≤17 | cairo PDF surface, y-up pages; tested (HelloQuartz) |
| `CGPDFDocument` / `CGPDFPage` (read, `drawPDFPage`) | 🟡 | ≤17 | through the host's poppler-glib when installed (fails to open otherwise); box rects are the media box; tested (HelloQuartz) |
| `CGFont` | 🟡 | ≤17 | a font name only (no glyph tables); unverified |

## Core Text

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `CTFont` by name, size, names, metrics, character set | ✅ | ≤17 | unknown names fall back to the system font; iOS font names missing on the host keep their weight/slant on the substitute |
| `CTFontManagerRegisterFontsForURL` | ✅ | ≤17 | process scope |
| `CTFontDescriptor`, symbolic traits, font features | 🟡 | ≤17 | descriptors are attribute dictionaries; bold/italic/mono traits; OpenType feature tags and a few AAT selectors go to the shaper; glyph advances are estimates; unverified |
| `CTLine` (create, typographic bounds, offsets/indices, truncation, draw) | ✅ | ≤17 | laid out by Pango (HarfBuzz); tested (HelloQuartz); truncation unverified |
| `CTRun` (glyphs, positions, advances, string indices, attributes) | 🟡 | ≤17 | runs are Pango glyph items; glyph ids are HarfBuzz's for the substituted font; counts tested (HelloQuartz) |
| `CTFramesetter` / `CTFrame` (frames in a path's bounding box, line origins, suggest size) | ✅ | ≤17 | rectangular paths only (bounding box); tested (HelloQuartz) |
| `CTParagraphStyle` | 🟡 | ≤17 | alignment and line spacing; others stored; unverified |

## QuartzCore / Core Animation

Core Animation lives in isim's UIKit (`import QuartzCore` re-exports it). Layers render every frame with cairo from
their presentation copies (model + running animations); there is no separate render server.

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `CALayer` basics (frame, bounds, position, anchorPoint, corner radius/curve, `maskedCorners`, border, background, opacity, `masksToBounds`, hidden) | ✅ | ≤17 | standalone layer trees keep their own geometry; a view's layer reports the view's (anchorPoint of a view's layer is stored, not applied). `cornerCurve` continuous draws circular corners. Tested (HelloCoreAnimation, HelloVideo) |
| `zPosition`, `transform`, `sublayerTransform`, `convert(_:from:/to:)`, `hitTest`, `contains` | ✅ | ≤17 | zPosition orders siblings (no depth buffer); conversions through the full 4x4 chain. Ordering/conversion unverified |
| Layer shadows | ✅ | ≤17 | blurred, `shadowPath` (see UIKit) |
| `mask` | ✅ | ≤17 | see UIKit |
| `magnificationFilter` / `minificationFilter` | ✅ | ≤17 | nearest affects image drawing |
| Sublayers, custom drawing (`draw(in:)`, delegate `draw(_:in:)`/`display(_:)`/`layoutSublayers(of:)`), `setNeedsDisplay`/`setNeedsLayout` | ✅ | ≤17 | content is redrawn every frame; display/layout run when flagged. Tested (sublayers, AVPlayerLayer in HelloVideo) |
| `contents` (CGImage / UIImage), `contentsGravity`, `contentsRect`, `contentsScale` | 🟡 | ≤17 | all gravities; `contentsCenter` (9-slice) stored, not applied; unverified |
| `CAShapeLayer` | ✅ | ≤17 | path fill (rules) and stroke (width, caps, joins, miter, dashes + phase), `strokeStart`/`strokeEnd` trimming along the path length, animatable path (same-structure paths morph, others switch half-way). Tested (strokeEnd half-way pixels) |
| `CAGradientLayer` | ✅ | ≤17 | axial, radial (ellipse from startPoint reaching endPoint), conic; `locations`; animatable colours/locations/points. Tested (axial pixels); radial/conic unverified |
| `CATextLayer` | 🟡 | ≤17 | NSString/NSAttributedString, font (UIFont, name), size, colour, alignment, wrapping; truncation modes stored |
| `CAReplicatorLayer` | ✅ | ≤17 | `instanceCount`, `instanceTransform` (perspective too), `instanceDelay`, `instanceColor` + RGBA offsets. Tested (5 copies) |
| `CAEmitterLayer`, `CAEmitterCell` | 🟡 | ≤17 | adapted: 2D particle simulation (point/line/rectangle/circle shapes, birth rate, lifetime, velocity, emission angle/range, acceleration, scale/spin/colour speeds and ranges, additive render mode); nested `emitterCells` and 3D emission stored only. Tested (particles spawn) |
| `CATransformLayer`, `CAScrollLayer` | 🟡 | ≤17 | transform layer renders like a plain layer (no shared 3D space); scroll layer scrolls its bounds. Unverified |
| `CABasicAnimation`, `CAKeyframeAnimation`, `CASpringAnimation`, `CAAnimationGroup` | ✅ | ≤17 | from/to/by (missing end = current presentation value), additive, cumulative, keyframe values or path, keyTimes, timingFunctions, linear/discrete/paced/cubic modes, rotationMode; damped-spring physics with settlingDuration and perceptual duration/bounce; groups; key paths incl. `transform.rotation.z`, `position.x`, `bounds.size`, custom KVC keys. Tested (keyframe positions at times, spring, group, view-layer rotation) |
| CAMediaTiming (`beginTime`, `duration`, `speed`, `timeOffset`, `repeatCount`/`repeatDuration`, `autoreverses`, `fillMode`, `isRemovedOnCompletion`); layer timing (`speed = 0` pausing, `convertTime`) | ✅ | ≤17 | Tested (paused layer + timeOffset, fillMode forwards) |
| Animation delegate, `add(_:forKey:)`, `removeAnimation(forKey:)`, `animation(forKey:)`, `animationKeys()`, `presentation()`/`model()` | ✅ | ≤17 | Tested |
| `CATransition` | 🟡 | ≤17 | fade, push, moveIn, reveal with subtypes: the previous on-screen appearance (a snapshot when added) leaves while the new state comes in; unverified |
| `CATransaction`, implicit animations, `CAMediaTimingFunction` | ✅ | ≤17 | begin/commit, duration, timing function, `setDisableActions`, completion blocks (wait for the transaction's animations), implicit 0.25 s animations for standalone layers only (not a view's layer, as on iOS), `actions`/delegate `action(for:forKey:)`/NSNull; custom control-point curves. Tested |
| `CADisplayLink` | ✅ | ≤17 | fires once per frame while added; keeps the run loop at 60 fps |
| `CATransform3D` | ✅ | ≤17 | full 4x4 math (make/translate/scale/rotate/concat/invert/isAffine/affine conversions), NSValue boxing and Swift bridging. Tested |
| `CAValueFunction`, `filters`/`compositingFilter`, `shouldRasterize` | 🧩 | ≤17 | stored, not applied |

## Core Image, ImageIO & Metal

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Core Image (`CIImage`, `CIFilter`, `CIContext`, `CIFilterBuiltins`) | 🟡 | ≤17 | CPU renderer (adapted): premultiplied sRGB floats instead of Apple's linear working space. Filters: CIGaussianBlur, CIColorControls, CISepiaTone, CIPhotoEffect* (approximations), CIColorInvert, CIColorMatrix, CIAffineTransform, CICrop, CISourceOver/CIMultiplyCompositing, CIQRCodeGenerator, CICheckerboardGenerator, CIConstantColorGenerator, CILinearGradient, CIVignette; transforms, crops, clamping, `UIImage(ciImage:)`; tested (HelloImaging, QR decoded with zbarimg). Other built-in filters missing (`CIFilter(name:)` returns nil), no custom kernels |
| ImageIO `CGImageSource` (types, count, properties, frames, thumbnails, EXIF orientation) | ✅ | ≤17 | PNG/JPEG/GIF/WebP/BMP/TIFF/ICO via gdk-pixbuf; GIF delays/loop count; thumbnails with max size and orientation transform; tested (HelloImaging). HEIC/AVIF through the host's ffmpeg (unverified); incremental sources unverified |
| ImageIO `CGImageDestination` (PNG, JPEG, animated GIF) | ✅ | ≤17 | GIF palette: exact up to 255 colors, else a color cube; tested (HelloImaging). Other types (HEIC, TIFF) are refused |
| Metal, MetalKit (`MTLDevice`, `MTKView`) | ❌ | ≤17 | no GPU API |
| OpenGL ES / GLKit | ❌ | ≤17 | |

---

## SpriteKit

isim's SpriteKit is its own Swift implementation, drawn with cairo on the CPU (no Metal). Tested by `tests/ui/spritekit.sh` (HelloSpriteKit) and `tests/ui/spritekit2.sh` (HelloSpriteKit2).

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `SKView`, `SKScene` (size, scale modes, anchor point, background, frame loop, delegate) | ✅ | ≤17 | 60 fps; per frame: `update`, actions, physics, constraints, particles, `didFinishUpdate` |
| `SKNode` tree (position, z-order, scale, rotation, alpha, hidden, name lookup, `enumerateChildNodes`) | ✅ | ≤17 | |
| `SKSpriteNode` (texture, color, color blend, anchor, size, blend modes) | ✅ | ≤17 | |
| `centerRect` (9-slice), `normalTexture`, lighting/shadow masks | 🧩 | ≤17 | stored, not drawn |
| `SKWarpGeometryGrid`, `SKWarpable` (`warpGeometry`, `subdivisionLevels`) on sprites | ✅ | ≤17 | drawn as a triangle mesh (each grid cell subdivided 2^levels per side, bilinear, at most ~2k triangles; each texture triangle mapped affinely); trapezoid warp checked by pixels. On `SKEffectNode` ❌ (sprites only) |
| `SKAction.warp(to:duration:)`, `animate(withWarps:times:)`, `animate(withWarps:times:restore:)` | ✅ | ≤17 | interpolate destination positions; warps must share the grid shape |
| `SKShapeNode` (path, rect, rounded rect, circle, ellipse, points, spline, fill/stroke, line width, glow, blend mode, `lineLength`) | 🟡 | ≤17 | line cap/join/miter, fill/stroke textures and shaders ignored |
| `SKLabelNode` (font, size, color, alignment, multi-line, color blend, blend mode) | ✅ | ≤17 | |
| `SKLabelNode.attributedText`, `init(attributedText:)` | ✅ | ≤17 | drawn by UIKit's attributed string drawing: per-run font, color, kerning, underline/strike, paragraph alignment and line spacing (red/blue runs checked by pixels); `fontName`/`fontColor` ignored as on iOS |
| `SKTexture` (`imageNamed:` incl. atlases, `init(rect:in:)`, `textureRect`, filtering, `preload`) | 🟡 | ≤17 | no noise textures; `cgImage()` returns nil |
| `SKTexture(data:size:)`, `(data:size:flipped:)`, `(data:size:rowLength:alignment:)` | 🟡 | ≤17 | RGBA8 straight alpha, first row at the bottom unless flipped; `data:size:` tested, the others unverified |
| `SKMutableTexture` (`init(size:)`, `modifyPixelData`) | ✅ | ≤17 | RGBA8 buffer (first row at the bottom) uploaded to the host after each block; pixel format argument ignored |
| `SKTextureAtlas` (`.atlas` folders, `textureNamed`, `textureNames`, `preload`, `init(dictionary:)`) | ✅ | ≤17 | picks the @2x/@3x file for the screen |
| `.spriteatlas` in asset catalogs | 🟡 | ≤17 | `isim build` lists them for `SKTextureAtlas(named:)`; unverified in an app |
| `SKAction` (move, rotate, scale, fade, colorize, resize, sequence, group, repeat, wait, run block, custom, follow path, speed, timing modes) | ✅ | ≤17 | |
| `SKAction.reversed()` | ✅ | ≤17 | move/rotate/scale/resize/fade/speed `by`, fadeIn↔fadeOut, hide↔unhide, sequence (reversed order), group (aligned to end together), repeat / repeatForever, texture animation, follow path, volume/mass/charge/strength/falloff `by`; `to` actions, colorize, physics impulses etc. return themselves like iOS; easeIn↔easeOut |
| Physics, field and audio actions (`applyForce`/`applyImpulse`/`applyTorque`, `changeMass`/`changeCharge`, `strength`/`falloff`, `play`/`pause`/`stop`, `changeVolume`) | 🟡 | ≤17 | unverified; playback rate, panning, reverb, obstruction/occlusion and `reach` actions only wait |
| `SKAction.playSoundFileNamed` | ✅ | ≤17 | through isim's AVFoundation (PCM CAF/WAV; compressed formats via the host's ffmpeg/GStreamer); overlapping plays mix |
| `SKAudioNode` | 🟡 | ≤17 | looping playback and volume; not positional (`isPositional` ignored); `avAudioNode` not connected to an engine; unverified |
| Touch handling in scenes/nodes | ✅ | ≤17 | via SKView |
| `SKTransition` / `presentScene(_:transition:)` | ✅ | ≤17 | crossFade, fade (with color), push, moveIn, reveal, doorway, doors open/close, flips; pauses incoming/outgoing scenes. `SKTransition(ciFilter:)` ❌ |
| `SpriteView` (SwiftUI) | ✅ | ≤17 | scene, transition, paused, options, debug options |
| `SKCameraNode` (position/rotation/scale drive the view, children as HUD, `contains`, `containedNodeSet`) | 🟡 | ≤17 | `SKScene.camera` is typed `SKNode?` (iOS: `SKCameraNode?`) to keep isim's ABI |
| `SKPhysicsWorld` (gravity, speed, `contactDelegate`, joints, `body(at:)`, `body(in:)`, ray casts) | 🟡 | ≤17 | `contactDelegate` is typed `AnyObject?` (ABI); `sampleFields(at:)` ❌ |
| `SKPhysicsBody` shapes (circle, rectangle, polygon, edge, edge chain/loop, compound) | 🟡 | ≤17 | concave polygons use their convex hull; texture-based bodies use the bounding rectangle |
| `SKPhysicsBody` dynamics (mass/density/area, friction, restitution, damping, velocity, forces, impulses, torque, `allowsRotation`, `pinned`, `affectedByGravity`, `isResting`) | ✅ | ≤17 | 150 points per meter like SpriteKit; sequential impulses without warm starting (tall stacks settle less firmly than Box2D) |
| Category / collision / contact bit masks, `SKPhysicsContact`, `didBegin` / `didEnd` | ✅ | ≤17 | collision response is per body, as in SpriteKit; static bodies moved by actions push dynamic ones |
| `usesPreciseCollisionDetection` | 🟡 | ≤17 | more substeps instead of continuous collision detection |
| `SKPhysicsJoint` (pin, fixed, spring, limit, sliding) | 🟡 | ≤17 | pin, limit and spring tested; fixed and sliding unverified; `reactionForce`/`reactionTorque` approximate |
| `SKFieldNode` (linear/radial gravity, spring, drag, vortex, velocity, noise, turbulence, electric, magnetic, custom; `SKRegion`) | 🟡 | ≤17 | radial gravity tested; the others are unverified approximations; fields do not act on particles |
| `SKEmitterNode` (birth rate, lifetime, position range, speed, emission angle, acceleration, alpha/scale/rotation/color + ranges, speeds and keyframe sequences, blend modes, texture, `targetNode`, `advanceSimulationTime`, `resetSimulation`) | ✅ | ≤17 | simulated on the CPU; `particleAction`, `shader` and field interaction ignored |
| `SKKeyframeSequence` | ✅ | ≤17 | linear, spline (smoothstep), step; clamp/loop |
| `.sks` files (`SKNode(fileNamed:)`, `SKScene(fileNamed:)`, `SKEmitterNode(fileNamed:)`) | 🟡 | ≤17 | binary keyed archives read by isim's own decoder; SpriteKit's private archive keys are matched by property name, so only archives laid out like isim's test files are known to load (no Xcode-made .sks was available to verify); scenes: nodes, sprites, labels, simple shapes, emitters, camera, crop/effect nodes; no actions, physics bodies or tile maps from files |
| `SKCropNode` | ✅ | ≤17 | alpha mask from the mask node |
| `SKEffectNode` | 🟡 | ≤17 | children composited as a group (alpha, blend mode); Core Image filters ❌; `shouldRasterize` has no effect |
| `SKShader`, `SKUniform`, `SKAttribute` | 🧩 | ≤17 | stored, not run (no GPU) |
| `SKLightNode` | 🧩 | ≤17 | stored; nothing is lit or shadowed |
| `SKConstraint`, `SKRange` (position, distance, orientation, rotation, scale) | 🟡 | ≤17 | orientation tested; others unverified |
| `SKReachConstraints`, inverse kinematics | 🧩 | ≤17 | stored; reach actions only wait |
| `SKTileMapNode`, `SKTileSet`, `SKTileGroup`, `SKTileDefinition` | 🟡 | ≤17 | grid maps built in code (fill, set/get, tile indices and centers, animated definitions); unverified; no tile sets from files, no automapping; isometric/hex drawn as a grid |
| `SKReferenceNode` | 🟡 | ≤17 | loads an .sks file's children; unverified |
| `SKView` debug overlays (`showsFPS`, `showsNodeCount`, `showsDrawCount`, `showsPhysics`) | 🟡 | ≤17 | node count tested; `showsPhysics` outlines bodies (unverified); `showsFields` ignored |
| `SKView.texture(from:)` | 🧩 | ≤17 | returns nil |
| `SKVideoNode` (`init(avPlayer:)`, `init(fileNamed:)`, `init(url:)`, `play`, `pause`, `size`, `anchorPoint`) | ✅ | ≤17 | draws isim AVPlayer's current frame (host ffmpeg decodes); size defaults to the video size; red→green clip checked by pixels |
| `SKTransformNode` (`xRotation`/`yRotation`/`zRotation`, euler angles, `quaternion`, `rotationMatrix`) | ✅ | ≤17 | R = Rx·Ry·Rz, children projected orthographically (no perspective); width halving at 60° checked by pixels |
| `SK3DNode`, `SKRenderer` | ❌ | ≤17 | |

## GameKit (Game Center)

isim's Game Center is local: one player per device, no Apple servers. App Store Connect metadata (titles,
descriptions, points, recurrence, sets) comes from an isim-only `isim-GameCenter.json` next to the `.xcodeproj`
(see [GAMECENTER.md](GAMECENTER.md)); without it titles are derived from identifiers. Tested by `tests/ui/gamecenter.sh`.

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `GKLocalPlayer.local.authenticateHandler` | ✅ | ≤17 | signed-in state from Settings > Game Center; "Welcome back" banner |
| Player identity (`alias`, `displayName`, `gamePlayerID`, `teamPlayerID`) | ✅ | ≤17 | nickname from Settings |
| Player photos (`loadPhoto`) | ✅ | ≤17 | generated monogram (initials on a gray circle), like the default Game Center avatar |
| Leaderboards: `GKLeaderboard.submitScore`, `loadLeaderboards`, `loadEntries` | 🟡 | ≤17 | stored per app on the device; you are the only entry; titles and sort order (high/low) from the configuration |
| Recurring leaderboards (`type`, `startDate`, `nextStartDate`, `duration`, `loadPreviousOccurrence`) | ✅ | ≤17 | local occurrences from `start` + `duration` in the configuration (any ISO 8601 duration, e.g. PT6S for tests); dashboard shows "resets in" |
| Leaderboard sets (`GKLeaderboardSet`, `GKGameCenterViewController(leaderboardSetID:)`) | ✅ | ≤17 | from the configuration; shown in the dashboard |
| Leaderboard / set images (`loadImage`) | 🟡 | ≤17 | image file from the configuration, else a generated placeholder |
| Achievements: `GKAchievement.report`, `loadAchievements`, `resetAchievements`, completion banner | ✅ | ≤17 | local |
| `GKAchievementDescription` (titles, descriptions, points, hidden, images) | ✅ | ≤17 | from the configuration; images: configured file or generated medal; `rarityPercent` is nil |
| Dashboard UI (`GKGameCenterViewController`, leaderboards/achievements/sets states) | ✅ | ≤17 | iOS-style SwiftUI dashboard; achievement descriptions and points; not-started configured achievements listed, hidden ones hidden |
| `GKAccessPoint` | ✅ | ≤17 | floating monogram bubble at the configured corner while active and signed in; tapping opens the dashboard; hidden while Game Center UI is shown; `showHighlights` ignored |
| Friends (`loadFriends`, `loadFriendsAuthorizationStatus`, recent players) | 🧩 | ≤17 | always an empty list (no other players) |
| Friend requests (`GKFriendRequestComposeViewController`, `presentFriendRequestCreator`) | 🟡 | ≤17 | composer UI works; the request is never sent |
| Saved games (`saveGameData`, `fetchSavedGames`, `deleteSavedGames`, `resolveConflictingSavedGames`, `GKLocalPlayerListener`) | ✅ | ≤17 | stored in the device data (`Library/GameCenter/<bundle id>`), survives app deletion; conflicts come from `isim gamecenter <app> conflict` (no second device) |
| Real-time multiplayer (`GKMatchmaker`, `GKMatch`, `GKMatchmakerViewController`) | 🟡 | ≤17 | matchmaker UI shows and cancels; finding players always fails (no other players, no loopback match) |
| Turn-based multiplayer (`GKTurnBasedMatch`, `GKTurnBasedMatchmakerViewController`) | 🧩 | ≤17 | UI finds nobody; `loadMatches` is empty (unverified) |
| Challenges, invites | 🧩 | ≤17 | `GKChallenge.loadReceivedChallenges` is empty; invites never arrive (unverified) |
| Game activities (iOS 26 `GKGameActivity`) | ❌ | 26.0 | |

## GameController, GameplayKit, SceneKit, RealityKit & ARKit

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `GCController` (`controllers()`, `current`, connect / disconnect / current notifications, `playerIndex`) | ✅ | ≤17 | virtual controller and host gamepads |
| `GCExtendedGamepad`, `GCMicroGamepad` (buttons, d-pad, thumbsticks, triggers, value / pressed / touched handlers) | ✅ | ≤17 | tested with the virtual controller |
| Physical game controllers on the host | ✅ | ≤17 | SDL3 gamepads (Xbox / PlayStation / Switch / generic via SDL's mapping database) polled at 60 Hz: each becomes a `GCController` with `GCExtendedGamepad` (+ micro profile), `vendorName` from SDL, `productCategory` from the SDL pad type; `ISIM_GAMEPADS=0` disables. Tested through an SDL virtual joystick (`gamepad` script command), not a physical pad |
| Gamepad rumble (`GCDeviceHaptics`) | ❌ | ≤17 | no CoreHaptics; the host side (`isim_gamepad_rumble`) exists but is not reachable from apps |
| `GCKeyboard.coalesced`, `GCKeyboardInput` (`button(forKeyCode:)`, `keyChangedHandler`, `isAnyKeyPressed`), `GCKeyCode` | ✅ | ≤17 | the host keyboard; key presses and releases arrive as USB HID usages (scripts: `keydown`/`keyup`) |
| `GCVirtualController` (iOS 15) | 🟡 | ≤17 | thumbsticks, d-pad, A/B/X/Y, shoulders, triggers and menu drawn over the key window; element configurations only hide elements (custom paths ignored) |
| `GCMouse`, motion, haptics, light, battery | 🧩 | ≤17 | no mice; the others are nil |
| SceneKit (`SCNView`, `SCNScene`, `SceneView`) | ❌ | ≤17 | |
| RealityKit | ❌ | ≤17 | |
| ARKit | ❌ | ≤17 | no camera or sensors |
| `GKStateMachine`, `GKState` | ✅ | ≤17 | |
| `GKEntity`, `GKComponent`, `GKComponentSystem`, `GKSKNodeComponent`, `SKNode.entity` | ✅ | ≤17 | |
| `GKRandomSource`, `GKARC4RandomSource`, `GKMersenneTwisterRandomSource`, `GKLinearCongruentialRandomSource`, `arrayByShufflingObjects` | 🟡 | ≤17 | MT19937 matches the reference generator; ARC4 is RC4; LCG is the 64-bit MMIX generator; seeded sequences are not checked against iOS's |
| `GKRandomDistribution`, `GKGaussianDistribution`, `GKShuffledDistribution` | ✅ | ≤17 | |
| `GKGraph`, `GKGridGraph`, `GKGraphNode`, `GKGraphNode2D/3D`, `findPath` (A*) | ✅ | ≤17 | |
| `GKObstacleGraph`, `GKPolygonObstacle` (`bufferRadius`, `connectUsingObstacles` incl. ignoring variants, `lock`/`unlockConnection`, `nodes(forObstacle:)`, `nodeClass`), `SKNode.obstacles(fromNodeBounds:)` | ✅ | ≤17 | visibility graph between buffered (mitered) corners; paths, locking and custom node classes tested; ignoring variants unverified; `obstacles(fromNodePhysicsBodies:)` / `(fromSpriteTextures:)` ❌ |
| `GKMeshGraph` (`triangulate`, `triangulationMode`, `triangle(at:)`, `connectUsingObstacles`) | 🟡 | ≤17 | Delaunay (Bowyer-Watson) with extra points along obstacle edges, triangles inside buffered obstacles dropped — not a constrained triangulation, so thin obstacles can be cut across; paths tested |
| `GKCircleObstacle`, `GKSphereObstacle`, `GKGoal.toAvoid(_ obstacles:)` | 🟡 | ≤17 | unverified |
| `GKNoise`, `GKNoiseMap`, noise sources (Perlin, billow, ridged, Voronoi, constant, cylinders, spheres, checkerboard) | 🟡 | ≤17 | own algorithms (values differ from iOS); no `SKTexture(noiseMap:)`; unverified |
| `GKAgent2D`, `GKGoal`, `GKBehavior`, `GKPath` | 🟡 | ≤17 | simple steering (seek tested; flee, intercept, wander, target speed, avoid, separate/align/cohere, follow/stay on path unverified); `GKAgent3D` ❌ |
| `GKRuleSystem`, `GKRule` | 🟡 | ≤17 | block-based rules, facts with grades; `NSPredicate` rules ❌; unverified |
| `GKGameModel` / `GKGameModelPlayer` / `GKGameModelUpdate`, `GKMinmaxStrategist` (`maxLookAheadDepth`, `randomSource` tie-breaks, `bestMove`, `randomMove`) | ✅ | ≤17 | alpha-beta on copies (`unapplyGameModelUpdate` not used); win / block / perfect tic-tac-toe self-play tested |
| `GKMonteCarloStrategist` (`budget`, `explorationParameter`) | ✅ | ≤17 | UCT with random playouts; win / block tested |
| `GKDecisionTree`, `GKDecisionNode` (value / predicate / weight branches; learned from examples) | 🟡 | ≤17 | ID3 (categorical, numeric thresholds) tested; unseen answers fall back to the majority action; `export(to:)` / `init(url:)` ❌ |
| `GKQuadtree`, `GKOctree` (add at point / in quad or box, `elements(at:)`, `elements(in:)`, remove) | ✅ | ≤17 | `elements(in:)` returns elements overlapping the query (iOS: whole cells); removal matches `isEqual` |
| `GKRTree` (add / remove / query, half / linear / quadratic / reduce-overlap splits) | ✅ | ≤17 | Guttman R-tree; all four strategies checked against brute force |

---

## AVFoundation & audio

Media decoding, speech and recording use host tools in child processes: **ffmpeg/ffprobe** (video, compressed audio,
thumbnails, AAC encoding, export, asset reader/writer, the simulated camera; GStreamer's `gst-launch-1.0` also decodes
audio files), **espeak-ng** or espeak (speech). QR/barcode scanning loads the host's **libzbar** when present.
Headless test runs are silent (no audio device); timing, frames and callbacks still run. HelloMedia's test plays through
SDL's silent "dummy" device and checks the mixed output captured with `ISIM_AUDIO_TAP`.

Labels in the notes: *passthrough* = a host tool does the real work; *adapted* = isim's own approximation;
*stub* = API only. *Tested* = checked by a UI test (pixels or printed values); *unverified* = code exists, no test.

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `AVAudioSession` (category, mode, `setActive`, record permission) | 🟡 | ≤17 | accepted; record permission always granted; preferred sample rate / buffer duration ignored |
| `AVAudioSession` interruptions, route changes (`currentRoute`, `interruptionNotification`, `routeChangeNotification`, `overrideOutputAudioPort`) | ✅ | adapted: events come from the `audio interrupt begin\|end [resume]` / `audio route NAME` script command (no phone calls or headsets on the host); interruptions pause `AVAudioPlayer`s like iOS; tested (HelloMedia): began/ended with shouldResume, headphones in (reason 1) and out (reason 2) |
| `AVAudioPlayer` (play, pause, stop, seek, loops, volume, delegate) | ✅ | ≤17 | real channel count; `play(atTime:)`; tested |
| `AVAudioPlayer` `rate`, `pan`, metering | 🟡 | ≤17 | adapted: `enableRate` + rate 0.5–2 time-stretches with isim's overlap-add (pitch kept; tested: position runs 2× at rate 2); pan is a stereo balance in the mixer (tested: pan −1 leaves the right channel silent in the output tap); `averagePower`/`peakPower` are dBFS of the last 50 ms of the file at the play position (tested: −9/−6 dB for a 0.5 sine), not of the device output |
| `AVAudioEngine`, `AVAudioPlayerNode`, `AVAudioMixerNode` | 🟡 | ≤17 | buffer/file scheduling and mixing; connections build effect chains; offline manual rendering (`enableManualRenderingMode`, `renderOffline`) tested; no 3D audio |
| `AVAudioFile`, `AVAudioPCMBuffer`, `AVAudioFormat` | ✅ | ≤17 | reads PCM CAF/WAV itself and compressed formats via the host decoder; writes WAV/CAF, and m4a/AAC (and other extensions) via host ffmpeg (HelloAudio) |
| Compressed audio decoding (AAC/M4A, MP3, ALAC) | ✅ | ≤17 | decoded by the host's ffmpeg or gst-launch-1.0 (48 kHz stereo); needs one of them installed; mono sources come out ~3 dB quieter (ffmpeg upmix) |
| Effects (`AVAudioUnitReverb`, `AVAudioUnitEQ`, `AVAudioUnitTimePitch`, `AVAudioUnitVarispeed`, `AVAudioUnitDelay`, `AVAudioUnitDistortion`) | 🟡 | ≤17 | adapted: isim's own DSP (Freeverb-style reverb, RBJ biquads, overlap-add time stretch), applied when a buffer starts, so parameter changes affect the next buffer; tested offline (HelloAudio); varispeed unverified |
| Taps (`installTap`) | 🟡 | ≤17 | input node (real time) and main mixer during offline rendering; no taps on real-time output |
| Recording (`AVAudioRecorder`, `AVAudioEngine.inputNode`) | 🟡 | ≤17 | input is `ISIM_AUDIO_INPUT=<file>` (played into the mic in real time — tested) or `=mic` (host capture via ffmpeg-pulse/arecord, unverified); silence otherwise — the host microphone is never opened unless asked; metering is RMS/peak of recent input |
| `AVPlayer`, `AVPlayerItem` (status, duration, `currentTime`, `seek`, rate, `timeControlStatus`, volume/mute) | ✅ | ≤17 | host ffmpeg decodes frames (≤960 px) and streams the soundtrack to the mixer; local files tested; http(s) URLs go to ffmpeg too (unverified); only rate 1 plays sound, no reverse playback |
| Time observers (`addPeriodicTimeObserver`, `addBoundaryTimeObserver`), `AVPlayerItemDidPlayToEndTime`, `actionAtItemEnd` | ✅ | ≤17 | evaluated once per display frame |
| `AVQueuePlayer`, `AVPlayerLooper` | ✅ | ≤17 | |
| `AVPlayerLayer` (`player`, `videoGravity`, `isReadyForDisplay`, `videoRect`) | ✅ | ≤17 | a CALayer drawn by UIKit's renderer: as a sublayer or a view's `layerClass` |
| `AVAsset`/`AVURLAsset` (duration, tracks, `naturalSize`, `nominalFrameRate`, `load(_:)`, `loadTracks`) | ✅ | ≤17 | probed with ffprobe; no metadata, no preferred transform |
| `AVAssetImageGenerator` (thumbnails) | ✅ | ≤17 | one frame via host ffmpeg; tolerances ignored |
| `CMTime`, `CMTimeRange` (CoreMedia) | ✅ | ≤17 | arithmetic, comparison, conversion, `NSValue(time:)` |
| `CMSampleBuffer`, `CMFormatDescription`, `CMBlockBuffer`, CoreVideo `CVPixelBuffer` (+ pools) | 🟡 | ≤17 | adapted: a sample buffer holds one decoded frame (CVPixelBuffer in main memory: BGRA/ARGB/RGBA/24RGB/L008/420v/420f) or interleaved PCM; accessor functions, `CMSampleBufferCopyPCMDataIntoAudioBufferList`; tested through capture, reader and writer; no compressed samples, no IOSurface/Metal texture caches, no CMClock |
| AVKit `AVPlayerViewController` | 🟡 | ≤17 | iOS 17-style controls (play/pause, ±10 s, scrubber, elapsed/remaining, mute, close when presented, auto-hide); no picture in picture, AirPlay, speed menu UI or info panels |
| SwiftUI `VideoPlayer` (with `videoOverlay`) | ✅ | ≤17 | the overlay does not take touches |
| Picture in picture (`AVPictureInPictureController`), `AVRoutePickerView` | 🧩 | ≤17 | PiP reports unsupported; route picker is an empty view |
| Capture: `AVCaptureDevice` (discovery, formats, `lockForConfiguration`), `AVCaptureSession`, `AVCaptureDeviceInput`, camera permission | ✅ | ≤17 | adapted: no camera unless `ISIM_CAMERA` is set (like the Simulator); then a back and a front camera show the picture, video (looped) or host webcam (`ISIM_CAMERA=webcam`, ffmpeg v4l2, unverified) decoded by ffmpeg at ≤1280 px, 30 fps; access goes through the privacy alert (tested: alert, allow, deny → −11852); device settings are stored but do not change the feed |
| `AVCaptureVideoPreviewLayer` (gravity, mirroring, coordinate conversion, `transformedMetadataObject`) | ✅ | ≤17 | tested: preview pixels, black until access is granted |
| `AVCapturePhotoOutput` | 🟡 | ≤17 | captures the newest frame: JPEG `fileDataRepresentation` (also when HEVC is asked for: no HEIF encoder), `cgImageRepresentation`, pixel buffer for pixel-format settings; tested; no flash, RAW, Live Photos or depth |
| `AVCaptureVideoDataOutput` (sample buffers, late-frame dropping) | ✅ | ≤17 | 420v (default), 420f or BGRA buffers (BT.601); tested (BGRA frames, colour of an image and a video source) |
| `AVCaptureMetadataOutput` (QR codes, barcodes) | 🟡 | ≤17 | passthrough: the host's libzbar decodes QR, EAN/UPC, Code 39/93/128, I2of5, Codabar, DataBar, PDF417 (no Aztec / Data Matrix / Micro QR); tested: a real QR code decoded with corners and preview coordinates; without zbar no types are available (logged); no faces/bodies |
| `AVCaptureMovieFileOutput` | 🟡 | ≤17 | records the camera frames to H.264 .mov/.mp4 through ffmpeg (no sound); `maxRecordedDuration`; tested (1 s recording) |
| Microphone capture device (`AVCaptureDevice` for `.audio`), `AVCaptureAudioDataOutput`, multi-cam, depth | ❌ | ≤17 | the microphone is `ISIM_AUDIO_INPUT` for AVAudioRecorder/AVAudioEngine/AudioQueue instead |
| `AVSpeechSynthesizer`, `AVSpeechUtterance`, `AVSpeechSynthesisVoice` | 🟡 | ≤17 | adapted: host espeak-ng voices (rate/pitch/volume/voice mapped); delegate start/finish/pause/continue/cancel; `willSpeakRangeOfSpeechString` approximated by word length; `write(_:toBufferCallback:)` renders PCM; without a TTS engine utterances run silently with a logged message |
| `AVMutableComposition` / `AVMutableCompositionTrack` (insert, insert empty, remove, scale, segments) | ✅ | ≤17 | adapted: an edit list of (file, source range, destination time) rendered by one ffmpeg filter graph on export; tested: insert in the middle, remove, scale (speed); no layer instructions or opacity ramps (`AVMutableVideoComposition` only sets render size / frame rate) |
| `AVAssetExportSession` (presets, `exportAsynchronously`, `export()`, iOS 18 `export(to:as:)`, progress, cancel, time range) | ✅ | ≤17 | passthrough: ffmpeg (x264/AAC; libx265 for HEVC presets when available; Passthrough stream-copies plain assets); tested: composition export with pixels of 3 frames, AppleM4A, missing output URL; `AVMutableAudioMix` applies a constant volume only |
| `AVAssetReader`, `AVAssetReaderTrackOutput` | 🟡 | ≤17 | passthrough: decoded video frames (BGRA or 420) and linear PCM (16/24/32-bit int or float) of local AVURLAssets; tested; compositions must be exported first (throws); no audio-mix / video-composition outputs |
| `AVAssetWriter`, `AVAssetWriterInput`, `AVAssetWriterInputPixelBufferAdaptor` | 🟡 | ≤17 | passthrough: frames and PCM are spooled and encoded by ffmpeg at `finishWriting` (H.264/HEVC/JPEG, AAC/ALAC/FLAC/LPCM); tested (30 frames + AAC → .mov); frame timing is reduced to a constant frame rate; no metadata or passthrough of compressed samples |
| AudioToolbox System Sound Services (`AudioServicesCreateSystemSoundID`, `PlaySystemSound`, completions) | 🟡 | ≤17 | sounds from files play; built-in IDs (e.g. 1104) play a synthesized click/chime instead of Apple's recordings |
| `kSystemSoundID_Vibrate`, `AudioServicesPlayAlertSound` vibration | 🧩 | ≤17 | logged only (no haptics on the host) |
| Audio File Services (`AudioFileOpenURL`, `AudioFileCreateWithURL`, properties, read/write bytes and packets) | ✅ | ≤17 | PCM WAV/AIFF/CAF read and written directly; compressed files are decoded by the host (then presented as 48 kHz float, adapted); tested |
| Extended Audio File Services (`ExtAudioFile*`: client format, read, write, seek) | ✅ | ≤17 | client-format conversion (sample type, channels, rate); compressed file types are written as PCM and encoded by ffmpeg on dispose (unverified); tested: WAV → 48 kHz mono float, CAF write |
| Audio Converter Services (`AudioConverterNew`, `ConvertBuffer`, `FillComplexBuffer`) | 🟡 | ≤17 | linear PCM ↔ linear PCM (format, channels, linear-interpolation resampling); tested; converters to/from AAC and other compressed formats return `kAudioConverterErr_FormatNotSupported` (tested) |
| Audio Queue Services (output and input queues, buffers, start/pause/stop, volume, current time, level metering, `IsRunning` listener) | 🟡 | ≤17 | adapted: output through the host mixer, paced in real time (silently when headless); input from `ISIM_AUDIO_INPUT`; tested (callbacks, time, input peak); play rate / pitch / pan parameters are accepted but not applied; no processing taps |
| Audio Units (`AudioComponent`, `AUGraph`, `AudioUnitRender`) | ❌ | ≤17 | |
| MediaPlayer `MPNowPlayingInfoCenter` | 🟡 | ≤17 | stored and logged; Control Center's Now Playing module shows "Not Playing" (the info is not passed to the shell) |
| MediaPlayer `MPRemoteCommandCenter` | 🟡 | ≤17 | handlers and selector targets; commands come from the `remote NAME [ARG]` script/control command (tested: play, skip, seek, disabled command) |
| `MPVolumeView` | 🧩 | ≤17 | a slider that does not change the host volume |
| Music library (`MPMediaLibrary`, `MPMediaQuery`, `MPMusicPlayerController`), MusicKit | ❌ | ≤17 | |

## Photos, Vision, Core ML & camera

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| PhotosUI `PhotosPicker` / `PHPickerViewController` | ✅ | ≤17 | grid of the device photo library outside the app's permission; single/multiple selection, `NSItemProvider` results, `PhotosPickerItem.loadTransferable(type:)` for `Data` and `Image` (tested; custom `Transferable` types compile, unverified at run time); images only (the library has no videos) |
| Photos (`PHPhotoLibrary`, `PHAsset`, saving images) | ✅ | ≤17 | device library in `$ISIM_DATA/Media` seeded with 6 generated sample pictures (stand-ins for the Simulator's); permission alert (full / limited with selection / add-only) remembered per app; fetch with sort/limit, smart albums (Recents, Favorites), `PHImageManager` scaling, `PHAssetChangeRequest` create/favorite/delete (with confirmation), change observers; images only |
| `UIImageWriteToSavedPhotosAlbum` | ✅ | ≤17 | add-only permission alert, completion selector called with nil/error |
| UniformTypeIdentifiers (`UTType`), CoreTransferable (`Transferable`, `DataRepresentation`, `FileRepresentation`, `ProxyRepresentation`) | 🟡 | ≤17 | fixed table of common system types with conformance, extensions and MIME types; Transferable import/export through data; `Data`, `String`, `URL`, SwiftUI `Image` conform; no drag & drop / ShareLink / pasteboard integration |
| Vision: `VNImageRequestHandler` (CGImage, CIImage, CVPixelBuffer, CMSampleBuffer, URL, Data; orientation), `VNSequenceRequestHandler`, requests/observations, `regionOfInterest`, geometry helpers | ✅ | ≤17 | tested: orientation and region of interest; coordinates normalized with a lower-left origin like iOS |
| Vision `VNDetectBarcodesRequest` | 🟡 | ≤17 | passthrough: host libzbar (QR, EAN/UPC, Code 39/93/128, I2of5, Codabar, DataBar, PDF417; no Aztec / Data Matrix / Micro QR); tested: payloads and boxes of two real QR codes; without zbar the request fails with a clear error |
| Vision `VNRecognizeTextRequest` | 🟡 | ≤17 | passthrough: the host's `tesseract` (line observations, word boxes, confidence); `.fast` and `.accurate` run the same engine; unverified with tesseract (not on the test host); without it the request fails with a clear error (tested) |
| Vision face/body/rectangle detection, classification, feature prints, `VNCoreMLRequest` | 🧩 | ≤17 | stub: no host detector or Apple models; requests fail with `VNErrorCode.unsupportedRequest` and a message (tested for faces) |
| Core ML data API (`MLMultiArray`, `MLFeatureValue`, `MLDictionaryFeatureProvider`, `MLArrayBatchProvider`, `MLModelConfiguration`, `MLModelDescription`) | ✅ | ≤17 | tested (shapes, strides, subscripts, feature values) |
| Core ML `MLModel` loading and prediction | 🟡 | ≤17 | adapted: Apple's compiled `.mlmodelc` format is undocumented and needs Apple's runtime, so Xcode-compiled models fail to load with a clear error (tested); `MLModel.compileModel(at:)` turns a `.mlmodel` spec into an isim `.mlmodelc`; descriptions are read for every model type; predictions run for GLM regressors/classifiers only (tested); neural networks, ML programs, trees and pipelines fail with a clear error (tested) |
| NaturalLanguage `NLTokenizer`, `NLLanguageRecognizer` | 🟡 | ≤17 | adapted: rule-based (Unicode classes, abbreviations; scripts + stop words for 14 Latin-script languages); tested on 6 languages; no Apple statistical models |
| NaturalLanguage `NLTagger` | 🟡 | ≤17 | adapted: tokenType, language, script; lexicalClass from a small English lexicon and suffix rules; sentimentScore from a word list; tested; nameType and lemma give no tags; `NLEmbedding`/`NLModel` unavailable |
| Speech `SFSpeechRecognizer` (authorization, URL and buffer requests, tasks, transcriptions) | 🟡 | ≤17 | permission alert tested; recognition passthrough to whisper.cpp (`ISIM_WHISPER_MODEL`) or Vosk (`ISIM_VOSK_MODEL`) when installed, one final result (unverified: neither on the test host); otherwise `isAvailable` is false and tasks fail with a clear error (tested) |
| VisionKit (`DataScannerViewController`, `VNDocumentCameraViewController`, `ImageAnalyzer`) | 🧩 | ≤17 | stub: `isSupported` is false (like the Simulator); `startScanning` throws `.unsupported` (tested) |

---

## StoreKit

Local StoreKit testing, like Xcode's: products come from the project's `.storekit` configuration; nothing is
charged, nothing reaches Apple, transactions are `.verified` and JWS/receipts are local and **unsigned**.
The ledger lives in the app container (`Library/isim/StoreKit/ledger.json`); `isim storekit <app> ...` is the
Transaction Manager. Tested by `tests/ui/store.sh` (HelloStore sample).

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| StoreKit configuration files (`.storekit` selected by the scheme) | ✅ | ≤17 | copied into the bundle by `isim build`; products, subscription groups, offers, `_timeRate`, `_storefront` |
| `Product.products(for:)` (id, type, display name, description, price, display price) | ✅ | ≤17 | prices shown in USD |
| `Product.purchase()` with confirmation sheet | ✅ | ≤17 | always succeeds when confirmed; `.pending` (Ask to Buy) never happens; owned non-consumables / current plan show the iOS notice |
| Purchase options (`appAccountToken`, `quantity`) | ✅ | ≤17 | stored on the transaction |
| `Transaction.currentEntitlements`, `all`, `latest(for:)`, `currentEntitlement(for:)`, `unfinished` | ✅ | ≤17 | `all` leaves out finished consumables (unless `SKIncludeConsumableInAppPurchaseHistory`) |
| `Transaction.updates` | ✅ | ≤17 | unfinished transactions at launch, renewals, refunds, offer-code redemptions, Transaction Manager changes |
| `Transaction.finish()` | ✅ | ≤17 | unfinished transactions are delivered again at the next launch |
| `VerificationResult` | ✅ | ≤17 | always `.verified`; `jwsRepresentation` is an unsigned local token (`alg: none`) |
| `AppStore.sync()` (restore) | 🟡 | ≤17 | re-reads the local ledger (no account to sync) |
| `AppStore.canMakePayments` | ✅ | ≤17 | |
| Consumables / non-consumables | ✅ | ≤17 | |
| Auto-renewable subscriptions: `Product.SubscriptionInfo` (group, period, level, group name) | ✅ | ≤17 | |
| Subscription status (`status`, `Status.updates`, `RenewalInfo`, `RenewalState`) | ✅ | ≤17 | subscribed / expired / revoked / billing retry; one status per group (no Family Sharing) |
| Renewals on an accelerated clock | ✅ | ≤17 | Xcode time rate from `.storekit` `_timeRate` (SKTestSession.TimeRate order; mapping unverified against Xcode) or `ISIM_STOREKIT_TIME_RATE` (`month=4`, `renewal=10`, names); renews while the app runs and catches up at launch |
| Expiration, cancel (auto-renew off), billing issues | 🟡 | ≤17 | expiry and cancel tested; billing retry via `isim storekit billing-issue` unverified; no grace period |
| Upgrade / downgrade / crossgrade within a group | ✅ | ≤17 | upgrades (and same-period crossgrades) immediate, `isUpgraded` set; downgrades at the next renewal |
| Introductory offers (free trial, pay as you go, pay up front), `isEligibleForIntroOffer` | ✅ | ≤17 | eligible until the first subscription in the group |
| Promotional offers (`.promotionalOffer(...)`) | 🟡 | ≤17 | from `.storekit` `adHocOffers`; the signature is not verified locally |
| Win-back offers (`.winBackOffer`) | 🟡 | ≤17 | from `winbackOffers`; eligible only after a lapsed subscription; no automatic win-back sheet |
| Offer codes (`presentOfferCodeRedeemSheet`, `offerCodeRedemption`) | 🟡 | ≤17 | redeem sheet; codes are the `.storekit` `codeOffers` reference names / IDs; subscriptions only |
| Refunds (`beginRefundRequest`, `refundRequestSheet`), `revocationDate` / `revocationReason` | ✅ | ≤17 | refund sheet; local requests are approved at once; revoked transactions arrive in `Transaction.updates` |
| `showManageSubscriptions`, `manageSubscriptionsSheet` | ✅ | ≤17 | iOS-style sheet: status, change plan, cancel |
| StoreKit views (`StoreView`, `ProductView`, `SubscriptionStoreView`) | 🟡 | ≤17 | iOS-like look; styles compact/regular/large; `storeButton`, `onInAppPurchaseCompletion/Start`, `subscriptionStatusTask`, `currentEntitlementTask`; custom control styles, policies and promotional icons ignored |
| `AppTransaction` | 🟡 | ≤17 | local: original app version = CFBundleVersion at first launch on this device; environment `.xcode`; unsigned |
| `SKStoreReviewController.requestReview`, `@Environment(\.requestReview)` | ✅ | ≤17 | development-style rating card, at most 3 times per 365 days; nothing sent |
| StoreKit 1 (`SKProductsRequest`, `SKProduct`/`SKProductDiscount`, `SKPaymentQueue`, observers, `finishTransaction`, restore) | ✅ | ≤17 | shares the StoreKit 2 ledger; renewals reach the observer |
| App receipt (`Bundle.main.appStoreReceiptURL`, `SKReceiptRefreshRequest`) | 🟡 | ≤17 | a local, unsigned JSON summary — not PKCS #7; receipt validation rejects it |
| `SKOverlay`, `SKStoreProductViewController` | 🟡 | ≤17 | placeholder overlay card / product page (the App Store isn't available) |
| Transaction Manager (refund, expire, cancel, clear) | ✅ | ≤17 | `isim storekit <app> list\|refund\|expire\|cancel\|resume\|billing-issue\|delete\|clear`; the running app picks changes up within 0.5 s |

## Ads & privacy (AppTrackingTransparency, Google Mobile Ads, UMP)

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ATTrackingManager.requestTrackingAuthorization`, `trackingAuthorizationStatus` | ✅ | ≤17 | iOS-style prompt; choice persists per app; missing usage string is logged |
| `ASIdentifierManager` (IDFA, `isAdvertisingTrackingEnabled`) | ✅ | ≤17 | all zeros unless the app's ATT answer is Allow; then a random per-device UUID kept in the device data (stable across apps and launches, new after `isim reset`). Nothing is sent. Tested: HelloSignIn |
| Google Mobile Ads stand-in (`MobileAds.start`, `BannerView`, `InterstitialAd`, `RewardedAd`, `AppOpenAd`) | 🧩 | ≤17 | builds and runs; every ad load fails with "unavailable on isim" |
| Google UMP stand-in (`ConsentInformation`, `ConsentForm`) | 🧩 | ≤17 | succeeds without a form; `canRequestAds` is false |
| Privacy manifests (`PrivacyInfo.xcprivacy`) | 🧩 | ≤17 | copied into the bundle; not checked |
| Other ad/analytics SDKs (Firebase, AppLovin, Meta, …) | ❌ | ≤17 | binary SDKs are not run; no stand-ins |

---

## Data & persistence

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Core Data: stack (`NSPersistentContainer`, `NSPersistentStoreCoordinator`, `NSPersistentStoreDescription`) | ✅ | ≤17 | isim's Objective-C `CoreData` framework (+ Swift overlay). Container finds `<name>.momd` in the main bundle; SQLite store in Library/Application Support/`<name>`.sqlite; `/dev/null` URL or `NSInMemoryStoreType` = in-memory. Store layout is isim's own (see docs/COREDATA.md). Tested: CoreDataTest, HelloCoreData |
| Core Data: models (`NSManagedObjectModel`, `NSEntityDescription`, attributes, relationships, inheritance) | ✅ | ≤17 | Built in code or loaded from isim-compiled models. All attribute types incl. UUID, URI, Date, Binary, Decimal (as NSNumber/REAL), Transformable (value transformer data); to-one/to-many/ordered/many-to-many with inverses; fetch request templates, fetched properties, configurations. Tested: CoreDataTest |
| Core Data: `.xcdatamodeld` in Xcode projects + codegen | ✅ | ≤17 | `isim build` compiles `.xcdatamodeld`/`.xcdatamodel` (versions, `.xccurrentversion`) to `<Name>.momd` in **isim's own model format** (XML plists; not Apple's binary .mom) and generates the Swift that Xcode's Class Definition / Category codegen makes (`@NSManaged` properties, `fetchRequest()`, to-many accessors). Decimal attributes generate `NSNumber?` (isim has no NSDecimalNumber). Tested: CoreDataTest, HelloCoreData |
| Core Data: `NSManagedObject` (`@NSManaged` accessors, faults, KVC/KVO, `changedValues`, validation) | ✅ | ≤17 | Dynamic accessors via `+resolveInstanceMethod:` typed from the property's declared type (scalars, objects, `add<Key>Object:` & co., ordered accessors, `primitive<Key>`); `ObservableObject` + `Identifiable`; lazy faults (`object(with:)`, to-many loaded on first access); validation: mandatory, min/max, regex, validation predicates, `validate<Key>:error:`, relationship counts, deny. Tested: CoreDataTest |
| Core Data: `NSManagedObjectContext` (insert/delete/save/rollback/reset/refresh, delete rules, notifications) | ✅ | ≤17 | Cascade/nullify/deny/no-action; `ObjectsDidChange` (end of event / `processPendingChanges`), `WillSave`/`DidSave`; `perform`/`performAndWait` (+ async `perform`, `performBackgroundTask`), main/private queues; parent/child contexts; `automaticallyMergesChangesFromParent` (children and sibling root contexts); `mergeChanges(fromContextDidSave:)`, `mergeChanges(fromRemoteContextSave:into:)`; permanent IDs + `URIRepresentation`. Tested: CoreDataTest |
| Core Data: merge policies | 🟡 | ≤17 | Optimistic locking per row; error, object-trump, store-trump, overwrite, rollback policies decide per object (property-level merge simplified). Uniqueness constraints are parsed but not enforced. Tested: error, object trump, store trump |
| Core Data: `NSFetchRequest` (predicates, sorting, limits, result types) | ✅ | ≤17 | Comparisons, BEGINSWITH/ENDSWITH/CONTAINS/LIKE (`[c]` for ASCII), IN, BETWEEN, AND/OR/NOT, `nil`, to-one/SELF equality run as SQL; anything else (key paths across relationships, `@count`, ANY, custom selectors) is evaluated in memory; pending changes (inserted/updated/deleted) always included. Managed objects, object IDs, dictionaries (`propertiesToFetch`, `NSExpressionDescription` aggregates, group by), counts; `count(for:)`; `execute()` in perform blocks. `fetchBatchSize`/prefetching accepted, everything is fetched at once. Tested: CoreDataTest |
| Core Data: `NSBatchDeleteRequest` / `NSBatchUpdateRequest` | 🟡 | ≤17 | Run directly in SQLite (no delete rules; dangling to-one keys and join rows cleared); merge results with `mergeChanges(fromRemoteContextSave:into:)`. `NSBatchInsertRequest` missing. Tested: CoreDataTest |
| Core Data: `NSFetchedResultsController` | ✅ | ≤17 | Sections by key path, index titles, `object(at:)`/`indexPath(forObject:)`; delegate insert/delete/move/update + section changes, or `controller(_:didChangeContentWith:)` with an `NSDiffableDataSourceSnapshotReference` that bridges to `NSDiffableDataSourceSnapshot<String, NSManagedObjectID>`. No cache. Tested: CoreDataTest |
| Core Data: SwiftUI (`@FetchRequest`, `FetchedResults`, `@SectionedFetchRequest`, `\.managedObjectContext`) | ✅ | ≤17 | Re-fetches on context changes (saves, merges) with the request's animation; `nsPredicate`/`nsSortDescriptors` settable; Swift `SortDescriptor`s sort in memory. Tested: HelloCoreData |
| Core Data: migration | 🟡 | ≤17 | Lightweight only (`shouldMigrateStoreAutomatically` + `shouldInferMappingModelAutomatically`, the defaults): added entities/attributes/relationships, renaming identifiers; removed properties are left in the store; changed attribute types keep stored values; no mapping models / `NSMigrationManager` / staged migration. Tested: CoreDataTest |
| Core Data: persistent history, derived attributes, `NSBatchInsertRequest`, undo | ❌ | ≤17 | `undoManager` is stored but changes are not registered with it |
| Core Data: `NSPersistentCloudKitContainer`, `NSPersistentCloudKitContainerOptions`, `cloudKitContainerOptions` | 🟡 | ≤17 | adapted: an `NSPersistentContainer` subclass whose store stays on the device — **local, no iCloud mirroring**; options are remembered, `initializeCloudKitSchema` only logs, `canUpdateRecord`/… return true, no `eventChangedNotification` events. Tested: HelloCloudKit (load, save, count) |
| SwiftData (`@Model`, `ModelContainer`, `@Query`) | ❌ | 17.0 | needs Apple's Swift macros (`@Model`, `#Predicate`), which isim cannot build; Core Data is the supported persistence framework |
| CloudKit: containers, account (`CKContainer.default()`, `accountStatus`, `userRecordID`, `ISIM_ICLOUD=noAccount`) | ✅ | **local, no iCloud sync**: a simulated account; `ISIM_ICLOUD=noAccount\|restricted\|temporarilyUnavailable` changes the status, and private/shared operations (and public writes) fail with `CKError.notAuthenticated`. Default container `iCloud.<bundle id>`. Tested: HelloCloudKit |
| CloudKit: records (`CKRecord` typed values, `CKAsset`, `CKRecord.Reference`, `CLLocation`, lists, `changedKeys`, change tags, dates, `encodeSystemFields`) | ✅ | ≤17 | stored per container/database as JSON in `$ISIM_DATA/Library/isim/CloudKit/<container>/`; assets copied into the store; `.deleteSelf` references cascade; values read back as Objective-C-style values (`as? String/Int/Double/Date/[String]`). `encryptedValues` are stored like other fields (not encrypted at rest). Tested: HelloCloudKit (relaunch persistence) |
| CloudKit: `CKDatabase` save/fetch/delete (+ async), `records(matching:)`, `modifyRecords`, `CKQuery` (NSPredicate + sort), `CKQueryOperation` (cursor, `resultsLimit`), `CKModifyRecordsOperation` (save policies, atomic), `CKFetchRecordsOperation`, `CKError` | ✅ | ≤17 | `serverRecordChanged` with server/client records, `.changedKeys`/`.allKeys`, atomic batches in custom zones (`batchRequestFailed`), `unknownItem` for missing records/types, `partialFailure`. Predicates use isim's NSPredicate (no `distanceToLocation:`); `CKOperation` is not an `NSOperation` (isim has none): add operations to a database/container. Tested: HelloCloudKit |
| CloudKit: zones, change tokens (`CKRecordZone`, `CKFetchDatabaseChangesOperation`, `CKFetchRecordZoneChangesOperation`) | 🟡 | ≤17 | custom zones in the private database, zone changes and deletions since a `CKServerChangeToken`; no `moreComing` paging. Tested: HelloCloudKit (zone changes); database changes unverified |
| CloudKit: subscriptions (`CKQuerySubscription`, `CKDatabaseSubscription`, `CKRecordZoneSubscription`, `CKNotification`) | 🟡 | ≤17 | saved and listed; changes made **in this process** that match send a CloudKit-style push payload in-process to `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` (no APNs; other processes' changes don't notify; no banner for `alertBody`). Tested: HelloCloudKit (query + database) |
| CloudKit: sharing (`CKShare`, `UICloudSharingController`), `CKSyncEngine`, user discovery | ❌ | ≤17 | |
| SQLite (`sqlite3` C API, `import SQLite3`) | ✅ | ≤17 | `/usr/lib/libsqlite3.dylib` forwards to the host's `libsqlite3.so.0` (loaded on first use; a function the host's SQLite lacks stops the app with a message). Tested: SecurityTest, HelloSecurity |
| Keychain passwords (`SecItemAdd/CopyMatching/Update/Delete`, generic + internet passwords) | ✅ | ≤17 | Swift (isim's Security module; Objective-C callers not yet). iOS attribute keys, duplicate detection, return data/attributes/persistent refs, match limits, access groups (default: bundle id). Stored per access group in `$ISIM_DATA/Library/Keychains` (0600 JSON, not encrypted; survives app deletion, erased by `isim reset`). `SecAccessControl` flags stored, not enforced |
| Keychain keys, certificates, identities (`kSecClassKey` / `Certificate` / `Identity`, `kSecValueRef`, `kSecReturnRef`, `kSecAttrIsPermanent`) | ✅ | ≤17 | same store as passwords; Apple's primary keys (duplicates detected), tag/label/issuer/serial queries; identities keep their private key with the certificate. Tested: SecurityTest |

## Identity & security

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Sign in with Apple (`ASAuthorizationAppleIDProvider`, `ASAuthorizationController`, `ASAuthorizationAppleIDButton`, `SignInWithAppleButton`) | ✅ | ≤17 | **local simulation, no Apple servers**: iOS-style sheet (Apple ID / Apple Account wording by `ISIM_OS_VERSION`, name, Share/Hide My Email, Continue/close) for a fake account in the device data; returning users get the short sheet without name/email. `identityToken` is an **unsigned JWT (`alg: none`, issuer `isim-local-simulation`)** and `authorizationCode` a random local string — servers that verify Apple signatures reject them. `getCredentialState` authorized/revoked/notFound per app; `isim appleid <app> revoke` posts `credentialRevokedNotification` to the running app. Buttons: black/white/whiteOutline, sign in/continue/sign up, isim-drawn logo. Tested: HelloSignIn |
| `ASWebAuthenticationSession` (OAuth) | ✅ | ≤17 | iOS's “Wants to Use … to Sign In” alert (skipped when ephemeral), the page in a browser sheet on isim's WKWebView (real WebKit), callback by custom scheme or (iOS 17.4) https host+path — links, forms and server redirects; Cancel → `canceledLogin`; `presentationContextProvider` errors; SwiftUI `webAuthenticationSession` environment action. Tested against a local OAuth page (HelloSafari). Non-ephemeral sessions share SFSafariViewController's in-memory data, not Safari's |
| Passkeys (`ASAuthorizationPlatformPublicKeyCredentialProvider` registration + assertion) | ✅ | ≤17 | real WebAuthn data: P-256 key (CryptoKit), CBOR attestation object with format `none` (AAGUID zero, COSE key), clientDataJSON with origin `https://<rp>`, assertion signature over authData ‖ SHA-256(clientDataJSON) that verifies. Keys kept unencrypted in the device data (not synced). iOS-style save/sign-in sheets; no passkey → canceled (no nearby-device QR); `preferImmediatelyAvailableCredentials` → `notInteractive`. Security keys (`ASAuthorizationSecurityKey…`), PRF/large blob missing. Tested: HelloSignIn |
| Password sign-in (`ASAuthorizationPasswordProvider`, `ASPasswordCredential`) | 🟡 | ≤17 | offers the app's own internet passwords from isim's keychain in a chooser sheet; no iCloud Keychain/Passwords app, no QuickType AutoFill bar, `performAutoFillAssistedRequests` behaves like `preferImmediatelyAvailableCredentials`. Tested: HelloSignIn |
| LocalAuthentication (Face ID / Touch ID, `LAContext`) | ✅ | `canEvaluatePolicy`/`evaluatePolicy` (+ async), `LAError`, `biometryType` from the device (Face ID; Touch ID on iPhone SE and non-Pro iPads). Face ID permission alert (`NSFaceIDUsageDescription`, remembered), simulated scan alert (Matching / Non-matching / Cancel), passcode fallback; `ISIM_BIOMETRY=match\|nomatch\|cancel`, `ISIM_BIOMETRY_ENROLLED=0`. Reply on a background queue like iOS |
| CryptoKit (SHA-2, HMAC, AES-GCM, ChaChaPoly, P256, Curve25519) | ✅ | ≤17 | also P384/P521, `Insecure.MD5/SHA1`, HKDF, `SharedSecret` HKDF/X9.63 KDFs, ECDSA DER, public keys raw/X9.63/compressed/DER/PEM. AES/ChaCha/EC on the host's OpenSSL `libcrypto.so.3`. Byte inputs are `ContiguousBytes` (isim's Foundation has no `DataProtocol`). Known-answer tests from the RFCs/NIST |
| CryptoKit: HPKE (RFC 9180, all modes; P-256/384/521 and X25519 KEMs; AES-GCM, ChaChaPoly, export-only), `AES.KeyWrap`, compact representations, private-key PKCS#8 DER/PEM (reads SEC1 too) | ✅ | ≤17 | HPKE opens messages sealed by OpenSSL's independent implementation; RFC 3394 vector. Tested: SecurityTest |
| CryptoKit: Secure Enclave | 🧩 | ≤17 | `SecureEnclave.isAvailable` is false and keys throw, like a Simulator without one |
| CommonCrypto (`CC_SHA*`, `CC_MD5`, `CCHmac`, `CCCrypt`/`CCCryptor`, `CCKeyDerivationPBKDF`, `CCRandomGenerateBytes`) | ✅ | ≤17 | in libSystem like iOS; contexts copyable; AES (ECB/CBC/CTR/CFB/OFB) and 3DES via the host's OpenSSL, other ciphers `kCCUnimplemented`. Known-answer tests |
| Security: `SecRandomCopyBytes`, `SecCopyErrorMessageString` | ✅ | ≤17 | |
| Security: `SecKey` (RSA 1024-8192, EC P-256/384/521: create, import/export in Apple's formats, sign/verify incl. PSS and RFC 4754, RSA PKCS#1/OAEP encryption, ECDH + X9.63 KDF, attributes) | ✅ | ≤17 | host OpenSSL; no Secure Enclave (`kSecAttrTokenIDSecureEnclave` fails with `errSecUnimplemented`); ECIES algorithms unsupported. Tested: SecurityTest (interoperates with CryptoKit) |
| Security: certificates and trust (`SecCertificate`, `SecPolicy`, `SecTrust` create/anchors/verify date/evaluate (sync, async), chain, exceptions, `SecPKCS12Import`, `SecIdentity`) | 🟡 | ≤17 | host OpenSSL; system anchors are the host's CA store (Apple's trust policies — CT, key-size rules, revocation — are not applied); a URLSession challenge's trust names the host only (no chain) and evaluates as trusted because libcurl checks the server. Tested: SecurityTest (test CA, wildcard host, expired, self-signed, wrong password) |
| DeviceCheck / App Attest | 🧩 | ≤17 | `isSupported` is false and calls fail with `DCError.featureUnsupported`, like the Simulator |

## Notifications & background work

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| UserNotifications: authorization request | ✅ | ≤17 | the iOS permission alert, answer remembered per app; provisional authorization; `notificationSettings()`; `ISIM_NOTIFICATION_PERMISSION=allow\|deny`. No per-app page in isim Settings |
| Local notifications (`UNNotificationRequest`, time/calendar triggers) | 🟡 | ≤17 | time-interval and calendar (`DateComponents`) triggers, repeating, pending/delivered lists, persisted across launches; fire while the app runs, and a suspended app is woken when one is due (adapted: the app delivers it, not a system scheduler). Tested (systemui, push). Not delivered while the app is not running |
| Notification presentation (banners, Notification Center, foreground delegate, sounds, attachments) | 🟡 | ≤17 | `willPresent`/`didReceive` (+ async); iOS-style banner in the app or, for a backgrounded or not-running app, drawn by the shell over the screen; tap opens the app with the default action. Notification Center and the lock screen list them (open, clear; `removeDeliveredNotifications`); Focus hides banners. Image attachments (`UNNotificationAttachment`, copied to the attachment store) show as thumbnails. Sounds are logged, not played. Tested (systemui, push). No grouping by thread |
| Notification actions and categories (`UNNotificationCategory`, `UNNotificationAction`, `UNTextInputNotificationAction`) | ✅ | ≤17 | long press (`holdid nc-item-ID`) expands a notification: the category's actions (destructive in red), text input with a reply field, `.foreground` actions open the app, background actions run as a background task (the app is launched in the background when needed), `.customDismissAction` sends the dismiss action; responses reach the delegate even after a relaunch (adapted: the shell draws the expanded view). Tested (push) |
| Push notifications (registration, device token, payloads) | ✅ | ≤17 | adapted, like the Simulator (Xcode 14+): `registerForRemoteNotifications` gives a 32-byte device token (needs the `aps-environment` entitlement; `ISIM_PUSH_REGISTRATION=fail`); payloads from `isim push [BUNDLE] file\|-`, the `push` script command or a dropped `.apns` file (`Simulator Target Bundle`); no APNs. alert (title/subtitle/body, loc keys), badge, sound, category, thread-id, `content-available` (`didReceiveRemoteNotification:fetchCompletionHandler:` as a background task; a closed app is launched in the background with UIBackgroundModes remote-notification), `mutable-content`; launch options carry the payload; not-running apps' alerts are shown by the system. Tested (push) |
| Notification Service extensions (`UNNotificationServiceExtension`) | ✅ | ≤17 | run as a helper process before display for `mutable-content` pushes with an alert; the modified content and attachments are shown; `serviceExtensionTimeWillExpire` after 30 s (`ISIM_NOTIFICATION_SERVICE_SECONDS`), then the best attempt or the original. Tested (push) |
| Notification Content extensions (`UNNotificationContentExtension`, UserNotificationsUI) | 🟡 | ≤17 | for the categories in `UNNotificationExtensionCategory`: the view controller gets `didReceive(_:)` in a helper process and its view is rendered into the expanded notification (size from `UNNotificationExtensionInitialContentSizeRatio` / `preferredContentSize`, `UNNotificationExtensionDefaultContentHidden`). Adapted: a snapshot, not interactive; `didReceive(_:completionHandler:)` is not called (responses go to the app), media buttons not drawn. Tested (push) |
| App icon badges (`setBadgeCount`, `applicationIconBadgeNumber`, aps.badge) | ✅ | ≤17 | red badge on the home-screen icon when the app may badge (`UNAuthorizationOptionBadge`); set by the app, by a push (system) or by a delivered notification; 0 clears it. Tested (push) |
| BackgroundTasks (`BGAppRefreshTask`, `BGProcessingTask`) | ✅ | ≤17 | `register` (checks `BGTaskSchedulerPermittedIdentifiers`), `submit` (checks `UIBackgroundModes`, errors), pending/cancel; no scheduler decides when — like Xcode's `_simulateLaunchForTaskWithIdentifier`, the script/control command `bgtask BUNDLE-ID TASK-ID` launches a pending task, starting the app in the background (or resuming a suspended one); tasks keep the app running until completed or expired (`ISIM_BACKGROUND_TASK_SECONDS`). Tested (HelloSystem) |
| App suspension in the background | ✅ | ≤17 | adapted: under `isim boot` an app is suspended (its process stopped: timers and run loop stop) a few seconds after going to the background (`ISIM_SUSPEND_SECONDS`, default 5; `ISIM_SUSPEND=0` never), unless a background task, background audio or location keeps it running; any system event (push, task, action, foreground) resumes it. iOS suspends right after the app's background work ends. Tested (background, push) |
| Background audio, location modes | ✅ | ≤17 | audio: UIBackgroundModes `audio` + a playback/playAndRecord category keeps playing after going home (without it the session is interrupted); location: UIBackgroundModes `location` + `allowsBackgroundLocationUpdates` (or `CLBackgroundActivitySession`) keeps updates coming, with the blue status-bar indicator (When In Use, or `showsBackgroundLocationIndicator`; tap opens the app). Tested (background) |
| VoIP (PushKit, CallKit) | ❌ | ≤17 | |

## App extensions & system integration

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Custom keyboard extensions | ✅ | ≤17 | built, embedded and hosted in-process |
| WidgetKit (home/lock screen widgets, timelines) | 🟡 | ≤17 | widget extensions (`@main` Widget/WidgetBundle, entry `_NSExtensionMain`) run as helper processes: `StaticConfiguration` / `AppIntentConfiguration` (default intent), `TimelineProvider` / `AppIntentTimelineProvider`, entries rendered by isim SwiftUI into images, shown by date, reload by policy and `WidgetCenter.reloadTimelines`; widget gallery (Edit Home Screen > +), small/medium/large on the home screen; `containerBackground`, `widgetFamily`; interactive widgets (`Button(intent:)` runs the AppIntent in the extension, then reloads). Tested (HelloWidgets). No lock-screen accessory widgets, widget editing (intent parameters), placeholder/snapshot UI, StandBy |
| ActivityKit (Live Activities, Dynamic Island) | 🟡 | ≤17 | `Activity.request/update/end`, `activities`, `ActivityAuthorizationInfo` (NSSupportsLiveActivities); the widget extension's `ActivityConfiguration` renders the lock-screen view (with `activityBackgroundTint`) and the Dynamic Island compact/minimal/expanded regions; the shell draws them on the lock screen and around the island (compact when the app is not in front; tap / script `island` expands). Tested (HelloWidgets). No push updates, alerts, stale dates shown, minimal multi-activity layout |
| App Intents (Shortcuts, Siri, Spotlight, interactive widgets, `AppShortcutsProvider`) | 🟡 | ≤17 | `AppIntent` (perform, results, dialogs), `@Parameter`, `AppEnum`/`AppEntity`/`EntityQuery` types, `Button(intent:)` / `Toggle(isOn:intent:)` (in apps and interactive widgets — tested, HelloWidgets). Stubs: `AppShortcutsProvider`/`AppShortcut` compile but nothing lists them (no Shortcuts app, Siri or App Shortcuts in Spotlight) |
| SiriKit (Intents) | ❌ | ≤17 | |
| Share / Action extensions (`NSExtensionContext`, `NSExtensionItem`, `SLComposeServiceViewController`) | ✅ | ≤17 | adapted: `UIActivityViewController` lists the app's own and installed apps' Share (app row) and Action (list) extensions whose `NSExtensionActivationRule` accepts the items (dictionary rules evaluated; predicate strings accepted); the extension is loaded into the host app's process (iOS: its own process) and its view controller presented as a sheet, with one `NSExtensionItem` (content text, `NSItemProvider` attachments for text, URLs, images, data); `completeRequest` / `cancelRequest` return to the host's completion handler with the returned items. Social's compose sheet (Post / Cancel, configuration items, characters remaining). `NSItemProvider` is Swift-only on isim; no Photos/Files share flows. Tested (share) |
| Spotlight (`CSSearchableItem`), `NSUserActivity` indexing | ✅ | ≤17 | CoreSpotlight `CSSearchableIndex` index/delete (ids, domains, all), `CSSearchableItemAttributeSet` (title, description, keywords); activities with `isEligibleForSearch`; the home screen's Spotlight finds them and continues `CSSearchableItemActionType` / the activity in the app. Tested (homescreen, HelloScenes). `CSSearchQuery` is a stub (no results) |
| App Clips | ❌ | ≤17 | |
| Focus filters, Control Center controls | ❌ | ≤17 | Control Center exists (shell) but apps cannot add controls; Focus is one Do Not Disturb toggle (hides banners), no Focus filters |

## Location & maps

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| CoreLocation (`CLLocationManager`, authorization, updates, geocoding) | ✅ | ≤17 | permission alert (Allow Once / While Using / Don't Allow, Always upgrade) remembered per app; simulated location (adapted): Apple Park by default, `ISIM_LOCATION=lat,lon` or a looping route, `location LAT LON`/`location none` script commands; `requestLocation`, `CLLocationUpdate.liveUpdates`, `CLServiceSession`; `CLGeocoder` answers offline from a small built-in gazetteer (other places: `geocodeFoundNoResult`); no heading (like the Simulator); missing usage string: request ignored + logged |
| Region monitoring, beacons, visits | 🟡 | ≤17 | `CLCircularRegion` monitoring (enter/exit, `requestState`) tested; beacons ranging unavailable and no visits, like the Simulator; `CLMonitor` (iOS 17) missing |
| MapKit `MKMapView` (region, camera, map types, gestures, conversion) | 🟡 | ≤17 | adapted offline basemap: land colour, lat/lon graticule with labels and a built-in list of world cities/landmarks, or raster tiles from a local cache (`ISIM_MAP_TILES` or `$ISIM_DATA/Library/Maps/Tiles/{z}/{x}/{y}.png`, never downloaded); no coastlines/roads; north-up and flat (heading/pitch stored only); drag to pan, double-tap zoom (no pinch), changes not animated; zoom range/boundary honoured. Tested (HelloMaps) |
| MapKit annotations (`MKAnnotation`, `MKPointAnnotation`, `MKMarkerAnnotationView`, `MKAnnotationView`, user location, selection, callouts) | ✅ | ≤17 | iOS-style balloon markers (tint, glyph text/image, title, bigger when selected), image views, reuse/registration, callouts with accessory controls, `didSelect`/`didDeselect`, blue user-location dot from the simulated Core Location. `MKAnnotation`/delegates are Swift protocols (title defaults to nil). Clustering and dragging not supported. Tested |
| MapKit overlays (`MKPolyline`, `MKPolygon`, `MKCircle`, renderers, `MKTileOverlay`) | 🟡 | ≤17 | path renderers (fill/stroke/width), geodesic polylines, tile overlays (file URLs; others through URLSession); dash patterns and polygon holes are not drawn; custom `draw(_:zoomScale:in:)` renderers are not called. Tested (polyline, circle, polygon) |
| MapKit search, directions, Look Around, snapshots | 🟡 | ≤17 | `MKLocalSearch`/`MKLocalSearchCompleter` answer offline from Core Location's gazetteer + the basemap's cities (else `placemarkNotFound`); `MKDirections` fails with `directionsNotFound` (no routing data); Look Around finds no scene; `MKMapSnapshotter` renders the offline basemap. Search, directions, snapshot tested; completer unverified |
| SwiftUI `Map` (`Marker`, `Annotation`, `MapPolyline`, `MapPolygon`, `MapCircle`, `UserAnnotation`, `MapCameraPosition`, selection, `mapStyle`, `onMapCameraChange`) | 🟡 | ≤17 | on MKMapView; Annotation content is SwiftUI in a hosted view; `mapControls` accepted but not drawn; legacy `Map(coordinateRegion:annotationItems:)` with `MapMarker`/`MapPin`/`MapAnnotation` unverified. Tested (markers, annotation, overlays, selection, position, camera change) |

## Personal data & device sensors

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Contacts / ContactsUI | ✅ | ≤17 | address book in `$ISIM_DATA/Library/AddressBook` seeded with the Simulator's sample contacts; permission alert (iOS 18: limited access with a selection list; iOS 17: Don't Allow/OK); fetch requests, name/phone/email/identifier predicates, save requests (add/update/delete, groups), unfetched keys raise like iOS, formatter, vCard; `CNContactPickerViewController` list (contact/property/multi selection), `CNContactViewController` card and a basic new-contact form; no images, no linked contacts |
| EventKit / EventKitUI (calendars, reminders) | 🟡 | ≤17 | calendar database in `$ISIM_DATA/Library/Calendar` (default "Calendar" and "Reminders" lists); iOS 17 access alerts (full / write-only events, full reminders); events, reminders, date/completion predicates, save/remove, store-changed notification; `EKEventEditViewController` basic form (title, location, all-day; dates shown, not editable) saves without access like iOS 17; recurrence rules and alarms stored but not expanded/fired; no Birthdays/Holidays calendars |
| HealthKit | ✅ | ≤17 | `isHealthDataAvailable` true on iPhone; Health Access sheet (per-type write/read switches, Turn On All) remembered per app; quantity/category samples stored in `$ISIM_DATA/Library/Health`, unit conversion, sample/statistics/statistics-collection/observer queries; read denial hidden like iOS; no workouts, characteristics unset, no clinical records |
| Core Motion (accelerometer, gyroscope, pedometer) | 🟡 | ≤17 | adapted: a device held upright at rest (gravity (0,-1,0), no rotation) for accelerometer/gyro/magnetometer/device-motion push and pull updates; `ISIM_MOTION=unavailable` reports no sensors like the Simulator; pedometer, activity, altimeter unavailable (Simulator); shake stays a UIKit motion event |
| Core Bluetooth | ✅ | ≤17 | like the Simulator: managers report `.unsupported`, scans log iOS's API MISUSE and find nothing |
| Core NFC | ✅ | ≤17 | like the Simulator: `readingAvailable` false; sessions are invalidated with `readerErrorUnsupportedFeature` |

## Web & communication

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| WebKit `WKWebView` rendering and loading (`load`, `loadHTMLString`, `loadFileURL`, `load(_:mimeType:…)`, back/forward, reload, KVO `title`/`url`/`isLoading`/`estimatedProgress`/`canGoBack`) | ✅ | ≤17 | real WebKit: the host's WebKitGTK 6.0 in a helper process (`isim-webkit`, private invisible broadway display) renders frames at the screen scale; iOS-style user agent; history includes `loadHTMLString` pages. Adapted: no 980-px mobile viewport (pages lay out at the view width), `load` sends GET + headers only. Needs `webkitgtk-6.0` + `gtk4-broadwayd` on the host (else a placeholder and a failed navigation). Tested (HelloWeb) |
| WebKit delegates (`WKNavigationDelegate` action/response policy, start/commit/finish/fail; `WKUIDelegate` alert/confirm/prompt, `createWebViewWith`) | ✅ | ≤17 | completion and async forms; cancelled links; JavaScript panels through the app's UI delegate (none → dismissed like iOS). Tested; `createWebViewWith`, process termination unverified |
| WebKit JavaScript bridge (`evaluateJavaScript`, `callAsyncJavaScript`, content worlds, `WKUserScript`, `WKScriptMessageHandler`(`WithReply`), `WKURLSchemeHandler`) | ✅ | ≤17 | results converted like iOS (dictionaries, arrays, numbers, `WKError.javaScriptExceptionOccurred`, unsupported types); isolated worlds; replies to page promises. Tested |
| WebKit input, scrolling, website data (`WKWebsiteDataStore`, `WKHTTPCookieStore`), snapshots | 🟡 | ≤17 | adapted input: taps, typing (system keyboard on focused fields) and scrolling become DOM events from an isolated world (`isTrusted` false); no text selection, `<select>` pickers, pinch zoom or context menus. `scrollView` mirrors page scrolling. Cookies get/set/delete and data removal; `takeSnapshot`. `find` unverified; `createPDF`/web archives fail. Tested (typing, scrolling, cookies, snapshot) |
| SwiftUI `WebView` / `WebPage` (iOS 26) | ❌ | 26.0 | wrap WKWebView in `UIViewRepresentable` |
| SafariServices (`SFSafariViewController`) | ✅ | ≤17 | iOS 17-style chrome (Done/Close/Cancel, domain + lock, “aA” button (cosmetic), back/forward/share/Open in Safari toolbar) on isim's WKWebView; delegate initial load / redirect / finish; tint colors; `DataStore.clearWebsiteData`. Adapted: its own in-memory website data (not Safari's), Reader and bar collapsing not real, Open in Safari logged. Tested (HelloSafari) |
| MessageUI (`MFMailComposeViewController`, `MFMessageComposeViewController`) | ✅ | ≤17 | like the Simulator `canSendMail()`/`canSendText()` are false (presenting shows nothing); `ISIM_MAIL=1` / `ISIM_MESSAGES=1` give the device accounts: iOS 17-style composers prefilled from the API, Send / Cancel → Delete or Save Draft, results to the delegates; nothing is sent — mails become `.eml` files in `$ISIM_DATA/Library/Mail/{Outbox,Drafts}`, messages JSON in `Library/SMS/Outbox`. Tested |
| Network framework `NWPathMonitor` (`pathUpdateHandler`, `currentPath`, `for await`) | ✅ | ≤17 | mirrors the host's connectivity (Wi-Fi/Ethernet), polled every 2 s; tested |
| Network framework `NWConnection`, `NWListener`, `NWEndpoint`, `NWParameters` (TCP, UDP) | ✅ | ≤17 | host sockets; states (`waiting` on refused/DNS failure), send/receive/receiveMessage, final messages, `currentPath` endpoints, UDP listener connections, TCP options. Tested (HelloConnections) |
| Network framework TLS (`NWProtocolTLS`, `sec_protocol_options` verify block, ALPN) | 🟡 | ≤17 | client connections through the host's OpenSSL (CA store + host name, or the app's verify block; ALPN, minimum version, negotiated version/ALPN metadata); `sec_trust_t` carries no certificates; TLS listeners (server identities), DTLS and QUIC not provided. Tested |
| Network framework Bonjour (`NWListener.service`, `NWBrowser`, `.service` endpoints, TXT records) | 🟡 | ≤17 | adapted: a local registry shared by the apps of this isim device (`$ISIM_DATA/Library/isim/Bonjour`), not multicast DNS — no other machines. Tested |
| Network framework `NWProtocolWebSocket`, `NWProtocolFramer`, `NWConnectionGroup` | ❌ | ≤17 | use URLSessionWebSocketTask |
| BSD sockets (`socket`, `bind`/`listen`/`accept`, `connect`, `send`/`recv`, `getaddrinfo`, `inet_pton`, `poll`/`select`, `getifaddrs`) | ✅ | ≤17 | Darwin structs, constants and errno translated to the host's; tested (TCP server + client, socketpair, poll, select, getifaddrs, `SO_RCVTIMEO`); `read`/`write` errno translated too; UDP unverified |
| `fcntl`, `ioctl` (e.g. non-blocking sockets) | 🟡 | ≤17 | C/Objective-C only: Swift cannot call these variadic functions without a Swift Darwin overlay |
| MultipeerConnectivity | 🟡 | ≤17 | adapted: peers on the same isim device (other apps or the same app) over loopback TCP and the local Bonjour registry: advertiser/browser, discovery info, invitations with context, session state, data (reliable/unreliable alike), resources; `MCBrowserViewController` list and `MCAdvertiserAssistant` alert unverified; no streams, no security identities. Tested (HelloConnections) |
| Universal Links / Associated Domains | 🟡 | ≤17 | local simulation: `applinks:` (incl. `*.` wildcards, `?mode=`) from archived-expanded-entitlements.xcent; https links opened by other apps or `openurl` go to the app that claims the domain (home screen under `isim boot`; the running app with `isim run`) as `NSUserActivityTypeBrowsingWeb`, others to "Safari"; no AASA files (offline). Tested (HelloSystem, HelloSafari) |

## Logging & diagnostics

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `print`, `NSLog`, `debugPrint` | ✅ | ≤17 | to the terminal running isim |
| `os.Logger`, `os_log`, `OSLog` (Swift) | ✅ | ≤17 | levels, `OSLogMessage` interpolation with privacy (strings/objects `<private>` unless `.public`; `.private(mask: .hash)`), number/bool formatting, printf-style `os_log` with `%{public}`; stderr in `log stream` compact style. `ISIM_LOG_PRIVATE=1` shows private values, `ISIM_LOG_LEVEL` filters |
| `os_log` C macros (Objective-C), `os_log_create` | ✅ | ≤17 | clang's `__builtin_os_log_format` buffers decoded by isim's libSystem; same output and privacy rules as Swift |
| Signposts (`OSSignposter`, `os_signpost`) | 🧩 | ≤17 | accepted, not recorded |
| `OSLogStore` (reading logs back) | 🧩 | ≤17 | throws |
| `os_unfair_lock`, `OSAllocatedUnfairLock` | ✅ | ≤17 | futex-backed, with owner checks |
| MetricKit (`MXMetricManager`, subscribers, `MXMetricPayload`/`MXDiagnosticPayload`, metrics, diagnostics, `jsonRepresentation`) | 🟡 | ≤17 | like the Simulator, nothing is measured and nothing arrives by itself; the `metrickit` script/control command or `isim metrickit` (Xcode's Debug > Simulate MetricKit Payloads) delivers one fixed sample metric payload and one diagnostic payload (crash, hang, CPU, disk-write, launch) to running apps' subscribers within 0.5 s. `pastPayloads` empty; display metrics nil. Tested: HelloCloudKit |
| Crash reporting (crash logs, `NSSetUncaughtExceptionHandler` reports) | ❌ | ≤17 | |
| `assert`, `precondition`, `fatalError` messages | ✅ | ≤17 | |

---

## Platform & tooling

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Compile ObjC/C for iOS on Linux (`isim cc`) | ✅ | ≤17 | clang/lld; simulator x86_64 and device arm64 Mach-O |
| Compile Swift (`isim swiftc`) | ✅ | ≤17 | Docker `swift:6.2` image |
| `isim build` for Xcode projects (`.xcodeproj`, targets, schemes, configurations, build settings) | ✅ | ≤17 | `-scheme` (BuildAction), `-configuration Debug/Release` (Debug: `-Onone`, SwiftOnoneSupport built for isim), `SETTING=VALUE` overrides, target dependencies; tested (HelloToolchain: Debug and Release) |
| Workspaces (`-workspace`, `.xcworkspace`, cross-project dependencies) | ✅ | ≤17 | projects of `contents.xcworkspacedata`, schemes of the workspace or its projects, products found across projects (implicit dependencies), `PBXContainerItemProxy` into referenced projects (unverified); tested (HelloToolchain builds from its workspace) |
| `.xcconfig` files (`#include`, `$(inherited)`, conditional settings) | ✅ | ≤17 | project/target base configurations; `KEY[sdk=iphonesimulator*]`/`[config=…]`/`[arch=…]`; tested (HelloToolchain: bundle id from a conditional setting, Info.plist key, compilation conditions) |
| Mixed Swift / Objective-C targets (bridging header, `<Module>-Swift.h`) | ✅ | ≤17 | `SWIFT_OBJC_BRIDGING_HEADER`, generated header in `DerivedSources` (and a framework's `Headers/`), frameworks import their umbrella header into their own Swift (`-import-underlying-module`); tested (HelloToolchain app and Greeter framework) |
| Shell script build phases | 🟡 | ≤17 | run only with `-run-script-phases` (they often call macOS tools; unverified); CocoaPods `[CP]` phases always skipped |
| App extensions in projects (`.appex`, embedded in `PlugIns/`) | ✅ | ≤17 | keyboards and Share/Action extensions run in their host app; widget and notification (service, content) extensions run as helper processes; other extension types are built but not hosted |
| Static libraries / framework targets in projects | ✅ | ≤17 | static libraries (`.a`, headers via copy-files `include/$(PRODUCT_NAME)`, module map with `DEFINES_MODULE`), dynamic frameworks (`@rpath/Name.framework/Name`, Headers/Modules, Swift module, resources, embedded in `Frameworks/` without headers), static frameworks and dylibs (unverified), resource bundles (unverified); tested (HelloToolchain: MathKit, Greeter) |
| Local Swift packages | ✅ | ≤17 | Swift and C/ObjC targets (module map from `include/` or the target's own), `swiftSettings`/`cSettings` (define, unsafeFlags, headerSearchPath), resources (`process`/`copy`) in `<Package>_<Target>.bundle` with a generated `Bundle.module`, local `binaryTarget` XCFrameworks (unverified); tested (HelloToolchain: Units -> Core -> CCore, units.json) |
| Remote Swift packages (GitHub dependencies) | 🟡 | ≤17 | never downloaded: built from a local checkout in `-package-cache DIR` / `$ISIM_PACKAGE_CACHE` (`DIR/<name>` or `DIR/checkouts/<name>`, e.g. Xcode's SourcePackages; unverified), or an isim stand-in (Google Mobile Ads); remote `binaryTarget`s only from an extracted XCFramework in the cache |
| Package-to-package dependencies | ✅ | ≤17 | `.package(path:)` and products of dependency packages (`.product(name:package:)`, by name); tested (HelloToolchain: Units depends on Core) |
| Binary `.xcframework`s | 🟡 | ≤17 | the x86_64 iOS-simulator slice is linked (static library or framework; dynamic frameworks embedded, universal binaries thinned); arm64-only XCFrameworks are rejected with a clear message (isim runs x86_64 simulator code only, so vendor SDKs shipping only arm64 slices cannot run); tested (HelloToolchain: Sum.xcframework; arm64-only rejection). Prebuilt dynamic frameworks from Xcode are unverified |
| CocoaPods / Carthage | 🟡 | ≤17 | no `pod install`/`carthage` on isim: an existing Pods workspace builds through workspace support (Pods project targets, `.xcconfig`, `[CP]` phases replaced by isim's embedding) and Carthage output through XCFrameworks — both unverified with real projects |
| Asset catalogs (images, colors, app icon) | ✅ | ≤17 | compiled to isim's own format (not `Assets.car`) |
| Info.plist (`$(VARS)`, `INFOPLIST_KEY_*`) | ✅ | ≤17 | never claims Xcode/SDK identity |
| Entitlements | 🧩 | ≤17 | not enforced or signed |
| App icons on the home screen | ✅ | ≤17 | from the asset catalog, `CFBundleIconFiles`, or the alternate icon the app chose |
| Launch screen (`UILaunchScreen` dictionary, LaunchScreen storyboard) | ✅ | ≤17 | shown in-app while the app launches (above its windows, no touches), fades out ≥ 0.25 s after launch (`ISIM_LAUNCH_SCREEN_SECS`); `UILaunchStoryboardName` (and `~iphone`/`~ipad`) initial controller; dictionary: `UIColorName`, `UIImageName`, `UIImageRespectsSafeAreaInsets`, `UINavigationBar`/`UITabBar`/`UIToolbar`; tested (HelloStoryboards). Not a cached snapshot like iOS; the home screen does not show it before the process starts |
| Storyboards / XIBs (`UIMainStoryboardFile`, `UISceneStoryboardFile`, nibs) | 🟡 | ≤17 | `isim build` compiles `.storyboard`/`.xib` (Xcode 15/16 XML) with isim's ibtool (`isim/tools/ibtool.py`) into isim's own archive format (`<Name>.storyboardc/isim-storyboard.plist`, `<Name>.nib/isim-nib.plist` — not Apple's binary nibs). Scenes: view/navigation/tab bar/table view/collection view (unverified)/page view (unverified) controllers; views and standard controls with their attributes (frames, autoresizing, colors incl. system/named, fonts incl. text styles, images incl. SF Symbols, button configurations, segments, text input traits, accessibility, runtime attributes, tags); Auto Layout (safe area/margins/scroll guides, priorities, multipliers, placeholders removed); outlets, outlet collections, actions, segues, prototype cells; `UIMainStoryboardFile` / `UISceneStoryboardFile` windows; tested (HelloStoryboards). Missing: static table cells (compiled, not shown), size classes/variations, `@IBDesignable` rendering, localized storyboards' `.strings` |
| Localization (`.xcstrings`, `.lproj/.strings`, app language from Settings) | 🟡 | ≤17 | plurals limited (see Foundation) |
| `isim test` (xcodebuild-style test runs) | ✅ | ≤17 | scheme Testables (skipped tests honored), `-only-testing:`/`-skip-testing:`, Xcode console format, `** TEST SUCCEEDED/FAILED **`, exit 65 on failures, `-resultBundlePath DIR` (logs + JUnit/xUnit XML; not an `.xcresult`); hosted tests run inside the app (`TEST_HOST`, bundle in `PlugIns/`), others in isim's `xctest` runner; tested (HelloToolchain, passing and deliberately failing runs) |
| Unit tests: XCTest (ObjC and Swift) | ✅ | ≤17 | ObjC-runtime discovery (`test*` methods; Swift `throws`/`async` variants), setUp/tearDown (class, `WithError`, `async`), teardown blocks, assertions (ObjC macros with `@try/@catch` for `XCTAssertThrows*`; Swift functions incl. accuracy, identity, `XCTAssertThrowsError`, `XCTUnwrap`), uncaught NSExceptions and thrown Swift errors recorded, `continueAfterFailure = false` (interruption exception), expectations (`wait(for:)`, `waitForExpectations`, inverted, notification/predicate (unverified), `fulfillment(of:)`, enforced order (unverified)), `XCTWaiter`, `XCTSkip`/`XCTSkipIf`, `measure` (10 runs, average; no baselines), `XCTestObservation` (unverified); tested (HelloToolchain) |
| Swift Testing (`import Testing`, `@Test`, `@Suite`, `#expect`, `#require`) | ✅ | ≤17 | swift-testing 6.2.4 built for isim (`isim/swift/build-testing.sh`); parameterized tests, async tests, filters/skips from `isim test`, xUnit output; tests run serially by default (`ISIM_SWIFT_TESTING_PARALLEL=1` runs them in parallel, which intermittently aborts with a mutex used after destruction — under investigation); exit tests unavailable (no process spawning, as on iOS); tested (HelloToolchain: AppSwiftTests) |
| UI tests (XCUITest) | 🟡 | ≤17 | `XCUIApplication` launches the TEST_TARGET_NAME app as its own simulator process (launch arguments/environment, terminate, state); element queries by type/identifier/label/predicate on accessibility snapshots (`dump FILE`), `exists`, `waitForExistence`, `label`/`value`/`placeholderValue`/`isHittable`/`hasFocus`, `tap`, `typeText`, switches; tested (HelloToolchain). `swipe*`, `press(forDuration:)`, `adjust(toNormalizedSliderPosition:)`, coordinates, `XCUIDevice` orientation/home are unverified; no keyboard/keys elements, no system alerts/springboard; `;` cannot be typed |
| Scripted automation (`--script`/`--control`: tap, type, screenshot, dump) | ✅ | ≤17 | |
| Device presets: iPhone SE, 13 mini, 14, 15, 15 Plus, 15 Pro Max, 16 Pro, 16 Pro Max, 17, Air, 17 Pro, 17 Pro Max | ✅ | ≤17 | safe areas, Dynamic Island, rounded corners |
| iPad presets: mini, Air 11", Pro 11", Pro 13" | 🟡 | ≤17 | run iPhone-style; no multitasking or pointer |
| Rotation / landscape | ❌ | ≤17 | |
| Multiple iOS versions (`--os`: reported version and look) | 🟡 | ≤17 | iOS 17, 18, 26, 27: version, availability and the look follow `--os` (see the rows above); iOS 27-specific visuals not done |
| Home screen: launch, background/resume, home gesture (swipe up / Ctrl+Shift+H), delete apps | ✅ | ≤17 | apps run as separate processes |
| Home screen: folders, App Library, widgets, rearranging icons, Spotlight | ✅ | ≤17 | edit mode: drag to rearrange, drop on an icon to make a folder (named from `LSApplicationCategoryType`); folders open; App Library page (categories, search); widgets in grid cells on any page (gallery); Spotlight (pull down on any page, Search button, script `spotlight`). Tested (homescreen, widgets, homepages). No folder renaming, dragging out of folders, jiggle animation |
| Home screen pages | ✅ | ≤17 | 4×6 grid pages on iPhone (iPad: 6 columns), the dock fixed across pages; paging with rubber-banding at the ends, velocity snapping and a spring settle; page dots above the dock (tap / scrub to switch; one page: the Search button); edit mode: hold a dragged icon at the screen edge to turn the page, drops on a full page push the overflow to the next page, a new page past the last one, empty pages removed on Done; Edit Pages (tap the dots in edit mode): thumbnails with checkmarks to hide/show pages; saved in `Library/SpringBoard/IconState.plist` (pages, hidden, known apps); new apps go to the first page with space, or only to the App Library (Settings > Home Screen & App Library > App Library Only); script `homepage N|library`, `swipehome left|right`, `drag … secs hold`; `dump` shows "page X of N". Tested (homepages: 52 apps). No reordering of pages in Edit Pages, no page deletion button |
| App switcher / multitasking | ✅ | ≤17 | swipe up and hold, Ctrl+Shift+H twice, script `switcher`: cards of running apps (last frames) in recent order; swipe a card up to close the app (scene sessions discarded), tap to switch. Tested (systemui). No Slide Over / Split View |
| Lock screen, Notification Center, Control Center | ✅ | ≤17 | lock (Ctrl+L, script `lock`): apps go to the background, clock, notifications and Live Activities; swipe up / `unlock`. Notification Center (pull down from the top): list, open (didReceive), clear. Control Center (pull down at the top right): Wi-Fi / Airplane Mode make the network unavailable (NWPathMonitor, URLSession), Dark Mode (the global setting), orientation lock, Focus (hides banners); brightness dims the screen; cellular, Bluetooth, mirroring, volume, flashlight, timer are cosmetic. Tested (systemui) |
| Settings app: General (About, Date & Time, Keyboard, Language & Region), Display & Brightness, Game Center, per-app pages | 🟡 | ≤17 | only the settings isim implements |
| Settings bundles (`Settings.bundle` for app pages) | ✅ | ≤17 | the app's page in Settings: PSGroupSpecifier (header/footer), PSTextFieldSpecifier (secure), PSToggleSwitchSpecifier (True/FalseValue), PSMultiValueSpecifier, PSRadioGroupSpecifier (unverified), PSSliderSpecifier, PSTitleValueSpecifier, PSChildPaneSpecifier, StringsTable localization; written to the app's `UserDefaults` domain (re-read when the app returns to the foreground, posting "NSUserDefaultsDidChangeNotification" by name — the constant is not declared yet); tested (HelloStoryboards). Apps with keyboard extensions keep the Keyboards page instead |
| System keyboard + keyboard extensions | ✅ | ≤17 | English (US) only |
| Light/dark mode, screenshots (F12), zoom | ✅ | ≤17 | |
| Audio output | ✅ | ≤17 | SDL3 mixer |
| Device build (arm64 executables) | 🟡 | ≤17 | executables link; `.app` bundle not finished |
| Code signing, `.ipa` packaging | ❌ | ≤17 | candidates: rcodesign, zsign |
| Upload to App Store Connect / TestFlight | ❌ | ≤17 | blocked: requires builds from current Xcode/SDK |
| Linux release tarballs (GitHub Releases) | ✅ | ≤17 | self-contained, glibc 2.35+ |
| Xcode-like project view / IDE | ❌ | ≤17 | planned; the CLI covers it today |
| `--os 17`, `18`, `26`, `27` (`ISIM_OS_VERSION`), remembered per device data | ✅ | ≤17 | `UIDevice.systemVersion`, `ProcessInfo` (`operatingSystemVersion`, `isOperatingSystemAtLeast`), Settings > About, `isim version`/`isim devices`; Xcode-like pairing: an explicit version older than the device's first iOS is rejected, otherwise the nearest valid one is used; tested (osversions.sh) |
| `#available` / `if #available` / `@available` follow the selected version | ✅ | ≤17 | libswiftCore built with OS versioning: Swift checks and Objective-C `@available` call isim's `__isPlatformVersionAtLeast`; tested for 18/26/27 under each `--os` |
| SDK availability annotations (`API_AVAILABLE(ios(N))`, `@available(iOS N, *)`) | 🟡 | ≤17 | real clang availability attributes in isim's headers; iOS 18/26/27 APIs isim implements are annotated (others carry none) |
| Lock Screen and Control Center look per version | 🟡 | ≤17 | adapted: iOS 17/18 bold Lock Screen clock, iOS 26/27 tall glass numerals and glass buttons; Control Center: iOS 17 modules, iOS 18 redesign (round toggles, rounder modules, edit/power buttons, page column), iOS 26/27 glass modules and lighter dimming; tested by pixels (osversions.sh) |
| Home Screen icon appearance (dark, tinted) | 🟡 | 18.0 | `ISIM_ICON_STYLE=dark` or `tinted` (`ISIM_ICON_TINT`); the app's own variants when present, else derived; no Customize sheet |
| Home Screen clear icons, glass dock and icon rims | 🟡 | 26.0 | `ISIM_ICON_STYLE=clear`; glass dock and specular icon edges with `--os 26`/`27` |
