# isim API coverage

This tracks how much of the iOS 17/18 SDK isim covers, so you can follow progress as features land.
It lists what an app developer reaches for, including everything isim does **not** have yet. Statuses come from
reading isim's headers (`isim/sdk-src`), implementations (`isim/frameworks`, `isim/swift/overlays`) and their comments, not from guesses.

Last updated: 2026-10-06

**Legend**

| Mark | Meaning |
|---|---|
| ✅ | Implemented: works like iOS for normal use |
| 🟡 | Partial: exists but simplified or missing notable behaviour (the note says what) |
| 🧩 | Stub: the API exists so apps compile and run, but it does nothing real |
| ❌ | Missing: not in isim yet (code using it does not compile, or aborts at run time) |

"Unverified" in a note means the code exists but no isim test exercises that behaviour.
Coverage % = (✅ + 0.5 × 🟡) / all rows in that area. Stubs count as zero.

## Summary

| Area | ✅ | 🟡 | 🧩 | ❌ | Rows | Coverage |
|---|---:|---:|---:|---:|---:|---:|
| **UIKit** | 106 | 41 | 10 | 41 | 198 | 64% |
| &nbsp;&nbsp;↳ Application & scenes | 7 | 5 | 5 | 6 | 23 | 41% |
| &nbsp;&nbsp;↳ View controllers & presentation | 18 | 7 | 0 | 5 | 30 | 72% |
| &nbsp;&nbsp;↳ Views & controls | 29 | 16 | 1 | 5 | 51 | 73% |
| &nbsp;&nbsp;↳ Layout | 13 | 1 | 1 | 4 | 19 | 71% |
| &nbsp;&nbsp;↳ Animation | 8 | 3 | 0 | 1 | 12 | 79% |
| &nbsp;&nbsp;↳ Gestures & touches | 9 | 1 | 0 | 3 | 13 | 73% |
| &nbsp;&nbsp;↳ Text input & keyboard | 6 | 2 | 1 | 5 | 14 | 50% |
| &nbsp;&nbsp;↳ Drawing, images & symbols | 12 | 3 | 0 | 3 | 18 | 75% |
| &nbsp;&nbsp;↳ Haptics & feedback | 0 | 0 | 1 | 2 | 3 | 0% |
| &nbsp;&nbsp;↳ Accessibility | 1 | 1 | 1 | 4 | 7 | 21% |
| &nbsp;&nbsp;↳ Drag & drop | 0 | 0 | 0 | 3 | 3 | 0% |
| &nbsp;&nbsp;↳ Appearance & dark mode | 3 | 2 | 0 | 0 | 5 | 80% |
| **SwiftUI** | 135 | 44 | 11 | 20 | 210 | 75% |
| &nbsp;&nbsp;↳ App & scenes | 4 | 1 | 0 | 6 | 11 | 41% |
| &nbsp;&nbsp;↳ State & data flow | 12 | 3 | 0 | 2 | 17 | 79% |
| &nbsp;&nbsp;↳ Views & controls | 30 | 7 | 0 | 1 | 38 | 88% |
| &nbsp;&nbsp;↳ Containers & layout | 18 | 8 | 1 | 0 | 27 | 81% |
| &nbsp;&nbsp;↳ Navigation & presentation | 13 | 8 | 1 | 1 | 23 | 74% |
| &nbsp;&nbsp;↳ Modifiers & visual effects | 15 | 6 | 6 | 0 | 27 | 67% |
| &nbsp;&nbsp;↳ Shapes, paths, gradients & materials | 18 | 3 | 0 | 2 | 23 | 85% |
| &nbsp;&nbsp;↳ Animation | 7 | 3 | 1 | 0 | 11 | 77% |
| &nbsp;&nbsp;↳ Gestures | 3 | 1 | 0 | 3 | 7 | 50% |
| &nbsp;&nbsp;↳ Lifecycle, async & events | 5 | 1 | 0 | 1 | 7 | 79% |
| &nbsp;&nbsp;↳ Focus & keyboard | 2 | 0 | 1 | 1 | 4 | 50% |
| &nbsp;&nbsp;↳ Environment values | 3 | 3 | 0 | 1 | 7 | 64% |
| &nbsp;&nbsp;↳ Accessibility | 2 | 0 | 1 | 1 | 4 | 50% |
| &nbsp;&nbsp;↳ UIKit interop | 3 | 0 | 0 | 1 | 4 | 75% |
| Swift Charts | 12 | 2 | 0 | 2 | 16 | 81% |
| **Foundation** | 50 | 20 | 1 | 9 | 80 | 75% |
| &nbsp;&nbsp;↳ Strings & text | 8 | 5 | 0 | 2 | 15 | 70% |
| &nbsp;&nbsp;↳ Collections & values | 9 | 3 | 0 | 0 | 12 | 88% |
| &nbsp;&nbsp;↳ Encoding & serialization | 7 | 0 | 0 | 0 | 7 | 100% |
| &nbsp;&nbsp;↳ Dates, calendars & formatters | 5 | 6 | 0 | 0 | 11 | 73% |
| &nbsp;&nbsp;↳ Files, bundles & preferences | 4 | 2 | 0 | 3 | 9 | 56% |
| &nbsp;&nbsp;↳ Notifications, timers & threads | 6 | 2 | 0 | 1 | 9 | 78% |
| &nbsp;&nbsp;↳ Networking | 11 | 2 | 1 | 3 | 17 | 71% |
| **Swift runtime, stdlib & concurrency** | 30 | 1 | 0 | 7 | 38 | 80% |
| &nbsp;&nbsp;↳ Combine | 11 | 0 | 0 | 3 | 14 | 79% |
| &nbsp;&nbsp;↳ Dispatch | 4 | 0 | 0 | 1 | 5 | 80% |
| Objective-C runtime & C library | 6 | 2 | 0 | 2 | 10 | 70% |
| Core Graphics | 9 | 0 | 0 | 7 | 16 | 56% |
| Core Text | 2 | 0 | 0 | 2 | 4 | 50% |
| QuartzCore / Core Animation | 2 | 3 | 0 | 4 | 9 | 39% |
| Core Image, ImageIO & Metal | 0 | 0 | 0 | 4 | 4 | 0% |
| SpriteKit | 15 | 17 | 5 | 3 | 40 | 59% |
| GameKit (Game Center) | 10 | 4 | 3 | 1 | 18 | 67% |
| GameController, GameplayKit, SceneKit, RealityKit & ARKit | 7 | 5 | 1 | 6 | 19 | 50% |
| AVFoundation & audio | 10 | 11 | 3 | 4 | 28 | 55% |
| Photos, Vision, Core ML & camera | 0 | 0 | 0 | 7 | 7 | 0% |
| StoreKit | 20 | 9 | 0 | 0 | 29 | 84% |
| Ads & privacy (AppTrackingTransparency, Google Mobile Ads, UMP) | 1 | 0 | 3 | 2 | 6 | 17% |
| Data & persistence | 2 | 0 | 0 | 4 | 6 | 33% |
| Identity & security | 4 | 0 | 1 | 5 | 10 | 40% |
| Notifications & background work | 1 | 2 | 1 | 3 | 7 | 29% |
| App extensions & system integration | 1 | 0 | 0 | 8 | 9 | 11% |
| Location & maps | 0 | 0 | 0 | 3 | 3 | 0% |
| Personal data & device sensors | 0 | 0 | 0 | 6 | 6 | 0% |
| Web & communication | 2 | 1 | 0 | 6 | 9 | 28% |
| Logging & diagnostics | 5 | 0 | 2 | 1 | 8 | 62% |
| Platform & tooling | 15 | 6 | 1 | 14 | 36 | 50% |
| **All areas** | **445** | **168** | **42** | **171** | **826** | **64%** |

---

## UIKit

### Application & scenes

| API / feature | Status | Notes |
|---|---|---|
| `UIApplicationMain`, `@main` app delegate | ✅ | Xcode App template lifecycle |
| `UIApplicationDelegate` launch/active/background/terminate callbacks | ✅ | apps background and resume from the home screen |
| Scene manifest, `UIWindowSceneDelegate`, `UIWindowScene` | ✅ | one scene per app |
| Multiple scenes / windows (iPad multi-window, `requestSceneSessionActivation`) | ❌ | `supportsMultipleScenes` exists; only one scene is ever created |
| `UIWindow` (`makeKeyAndVisible`, `rootViewController`, `windowLevel`) | ✅ | |
| `UIScreen.main` (bounds, scale, nativeBounds, maximumFramesPerSecond) | ✅ | per-device presets |
| `UIScreen.brightness` | 🧩 | stored only |
| `UIDevice` (name, model, systemVersion, userInterfaceIdiom) | 🟡 | systemVersion is the emulated API level (`ISIM_OS_VERSION`, default 18.0) |
| Device orientation, rotation, `supportedInterfaceOrientations` | ✅ | Ctrl+Left/Right or script `rotate`; Info.plist/delegate/VC masks (containers use their visible child; no plist key = portrait, adapted), `requestGeometryUpdate`, device notifications, landscape screen through the shell; tested (HelloRotation) |
| Application/scene lifecycle notifications (`didBecomeActiveNotification`, …) | ✅ | |
| `open(_:options:)` / `canOpenURL` | 🟡 | logged; `app-settings:` opens Settings; http(s)/mailto open on the host only with `ISIM_OPEN_URLS=1` |
| Incoming URLs (custom URL schemes, `application(_:open:)`, scene URL contexts) | 🟡 | URLs can be delivered to the app (script/control); `CFBundleURLTypes` routing between apps unverified |
| Universal links, `NSUserActivity`, Handoff | ❌ | |
| `applicationIconBadgeNumber` | 🧩 | stored; no badge on the home-screen icon |
| `isIdleTimerDisabled` | 🧩 | no screen lock exists |
| Status bar (`prefersStatusBarHidden`, `preferredStatusBarStyle`) | 🟡 | hide works (SwiftUI `statusBarHidden`); style/appearance updates unverified |
| `beginBackgroundTask`, background fetch/modes | ❌ | |
| State restoration (`stateRestorationActivity`, restoration IDs) | ❌ | |
| Home-screen quick actions (`UIApplicationShortcutItem`) | ❌ | |
| Alternate app icons (`setAlternateIconName`) | ❌ | |
| Memory warnings (`didReceiveMemoryWarning`) | 🧩 | method exists; never sent |
| Remote notification registration | 🧩 | `registerForRemoteNotifications` fails with NSCocoaErrorDomain 3010 through `didFailToRegisterForRemoteNotificationsWithError` (no APNs on isim) |
| `UIPasteboard` | 🟡 | `general` + named pasteboards: strings, URLs, images, colors, items, `changeCount`, `hasStrings`…, change notification; strings/URLs are shared between the apps of the device (stored in its data directory); tested (HelloTransitions share sheet). No paste prompt, no edit-menu copy/paste in text fields |

### View controllers & presentation

| API / feature | Status | Notes |
|---|---|---|
| `UIViewController` lifecycle (`loadView`, `viewDidLoad`, appear/disappear, layout callbacks) | ✅ | |
| Child view-controller containment | ✅ | |
| `init(nibName:bundle:)` / storyboard-instantiated controllers | ❌ | nib name is logged and ignored |
| Full-screen modal (`.fullScreen`, `.overFullScreen`, `.currentContext`, `.overCurrentContext`) | ✅ | slides up; `.fullScreen`/`.currentContext` send the presenter viewWillDisappear/viewDidAppear, the "over" styles keep it; context styles cover the `definesPresentationContext` controller; tested (HelloTransitions; context styles unverified) |
| Page / form sheet (`.automatic`, `.pageSheet`, `.formSheet`) | ✅ | iOS 15+ card look, presenter shrinks behind it at the large detent, swipe-down dismiss (presentation controller delegate: should/will/did dismiss, did attempt), iPad centered card (tap outside or swipe down dismisses; `preferredContentSize` for form sheets, unverified); tested on iPhone and iPad (HelloTransitions, HelloPresentations) |
| `isModalInPresentation` | ✅ | rubber-bands instead of dismissing |
| `UISheetPresentationController` (detents, grabber, largest undimmed detent) | ✅ | `.medium()`, `.large()`, `.custom(identifier:resolver:)`, grabber, dimming above `largestUndimmedDetentIdentifier` (touches pass through below it), `selectedDetentIdentifier` + `animateChanges`, dragging between detents with the delegate callback, `prefersScrollingExpandsWhenScrolledToEdge`; tested (HelloTransitions). iPad keeps centered cards (no detents) |
| Popover presentation (`UIPopoverPresentationController`) | ✅ | iPhone adapts to a sheet unless the adaptive delegate returns `.none`; real popovers: card with an arrow towards `sourceView`/`sourceRect` or `barButtonItem`, `permittedArrowDirections`, `preferredContentSize`, tap outside to dismiss (delegate), `passthroughViews`; tested (HelloTransitions; bar button anchoring unverified) |
| `modalTransitionStyle` (cross dissolve, flip, partial curl) | 🟡 | cross dissolve fades; flip horizontal is adapted (2D fold/unfold, no perspective); partial curl is shown as cover vertical (adapted); tested (HelloTransitions) |
| Custom transitions (`UIViewControllerTransitioningDelegate`, interactive) | ✅ | animators with a transition context (container, from/to views and controllers, final frames, `completeTransition`), custom `UIPresentationController` subclasses (frame, will/did begin/end, container layout), `transitionCoordinator.animate(alongsideTransition:)`, `UIPercentDrivenInteractiveTransition` (update/finish/cancel; scrubs the animator's UIView animations or its interruptible animator); tested (HelloTransitions) |
| `UINavigationController` (push/pop, back swipe) | ✅ | push/pop/popTo, parallax animation, back button, left-edge back swipe, delegate; tested (HelloNavigation) |
| `UINavigationItem` (title, bar button items, search controller, large titles) | ✅ | title, titleView, left/right bar button items, back title, large title display mode |
| `UITabBarController` | ✅ | tab bar, selection, delegate, badges, hidesBottomBarWhenPushed, tap-again pops to root; tested |
| `UISplitViewController` | 🟡 | collapsed on iPhone into one navigation stack (`topColumnForCollapsingToProposedTopColumn`, classic `collapseSecondary`, `.compact` column), `showDetailViewController` pushes, `show/hideColumn`; regular width (iPad): primary + secondary columns side by side; tested on iPhone and iPad (HelloTransitions). No display-mode button behaviour, no overlay/displace, no collapse/expand on size changes |
| `UIPageViewController` | ✅ | scroll style with paging (horizontal/vertical, inter-page spacing), data source neighbours, delegate will/did transition, page dots (presentation count/index), animated `setViewControllers`; tested (HelloTransitions). Page curl is shown as scroll (adapted) |
| `UIAlertController` `.alert` | ✅ | iOS 17/18 metrics, preferred action |
| `UIAlertController` `.actionSheet` | 🟡 | drawn as a bottom sheet; iPad popover anchoring unverified |
| `UIAlertController.addTextField` | ✅ | grouped fields in the card, first one focused, card stays above the keyboard; `UIAlertAction.isEnabled` updates its button live; tested (HelloTransitions) |
| `UIActivityViewController` (share sheet) | 🟡 | sheet with an item preview, Copy (to `UIPasteboard.general`) and `applicationActivities` (`UIActivity` subclasses), `excludedActivityTypes`, `UIActivityItemSource`, `completionWithItemsHandler`; tested (HelloTransitions). No other apps to share to (no AirDrop/Messages/Mail rows) |
| `UISearchController` | 🟡 | in `navigationItem.searchController`: bar below the (large) title, collapses on scroll (`hidesSearchBarWhenScrolling`); activating hides the navigation bar, shows Cancel, dims the content (`obscuresBackgroundDuringPresentation`), calls the results updater per keystroke, restores the scroll position on cancel; tested (HelloInputs). Results controller and standalone use unverified; no animated bar transition |
| `UIImagePickerController` (camera/library) | ❌ | |
| `UIDocumentPickerViewController` / `UIDocumentBrowserViewController` | ❌ | |
| `UIColorPickerViewController` | 🟡 | grid (tested, via UIColorWell), spectrum and RGB sliders, opacity, delegate callbacks; no eyedropper or saved colors; spectrum/sliders unverified |
| `UIFontPickerViewController` | ❌ | |
| `UIReferenceLibraryViewController`, `QLPreviewController` | ❌ | |
| `UIInputViewController` (custom keyboard extension) | ✅ | loaded in-process; no Full Access |
| `overrideUserInterfaceStyle` | ✅ | |
| `setEditing(_:animated:)`, `editButtonItem` | ✅ | Edit/Done item; `UITableViewController` forwards to its table; tested (HelloTable) |
| `preferredContentSize` | 🟡 | sizes popovers (tested) and iPad form sheets; notifies the parent and presentation controller |
| `UIContentUnavailableConfiguration` | ✅ | `.empty()`, `.loading()`, `.search()`; image/text/secondary text/buttons; `contentUnavailableConfiguration`, `setNeedsUpdateContentUnavailableConfiguration`, `updateContentUnavailableConfiguration(using:)` (search text from the search controller), `UIContentUnavailableView`; tested (HelloTransitions). A class here, not a struct (adapted) |

### Views & controls

| API / feature | Status | Notes |
|---|---|---|
| `UIView` hierarchy, frames/bounds/center, hit-testing, coordinate conversion | ✅ | |
| Autoresizing masks | ✅ | |
| `transform` (2D affine: translate/scale/rotate) | ✅ | about the view's center |
| 3D transforms (`CATransform3D`, perspective) | ❌ | |
| Background color, alpha (group opacity), hidden, `clipsToBounds` | ✅ | software rendering (cairo) |
| `layer.cornerRadius`, border, `cornerCurve` | ✅ | |
| Layer shadows (`shadowColor/Opacity/Radius/Offset`) | 🟡 | blur approximated by stacked fills; only under a background shape; no `shadowPath` |
| `layer.mask`, `mask` view | ❌ | |
| `draw(_:)` custom drawing with `UIGraphicsGetCurrentContext` | ✅ | |
| `tintColor` / `tintColorDidChange` | 🟡 | tint inheritance details unverified |
| `contentMode` | 🟡 | used by image views; all modes unverified |
| `UILabel` (font, color, alignment, multi-line, line break, `adjustsFontSizeToFitWidth`) | ✅ | Pango text; Adwaita Sans stands in for SF Pro, so metrics differ slightly |
| `UILabel.attributedText` | ✅ | fonts, colours, background, kern, underline, strikethrough, baseline offset, paragraph alignment/line spacing (Pango markup); tested (HelloImages). Attachments and shadows are not drawn |
| `UIButton` system/custom, title/color/image per state | ✅ | `imageView` returns nil |
| `UIButton.Configuration` (plain/tinted/gray/filled/bordered*, subtitle, image padding, corner style, size) | 🟡 | no `configurationUpdateHandler`, attributed titles or activity indicator |
| Button menus (`menu`, `showsMenuAsPrimaryAction`), pop-up buttons | ✅ | UIButton.menu + showsMenuAsPrimaryAction, UIBarButtonItem menus; tested |
| `UIControl` target-action, `UIAction`, control events/states | ✅ | |
| `UIImageView` | ✅ | PNG/JPEG/… via gdk-pixbuf, SVG via librsvg |
| Animated images (`animationImages`, `UIImage.animatedImage`) | ❌ | |
| `UITextField` | 🟡 | caret always at the end: no selection, cursor movement, copy/paste |
| `UITextView` | 🟡 | plain text, editable/scrollable, self-sizing when `isScrollEnabled = false`, delegate (should/did begin/end, `shouldChangeTextIn`, did change), notifications, keyboard traits, tap places the caret, `selectedRange`, `scrollRangeToVisible`; tested (HelloInputs). No attributed text, selection UI, edit menu or data detectors (stored) |
| `UISwitch` | ✅ | |
| `UISlider` | ✅ | thumb drag, continuous/non-continuous, track tints; tested (HelloControls) |
| `UIStepper` | ✅ | min/max/step/wraps; tested |
| `UISegmentedControl` | ✅ | titles/images, sliding selection, momentary, per-segment enable; tested |
| `UIPickerView` | ✅ | wheels drawn on a cylinder behind the selection band, drag/fling/tap a row, `selectRow`, reload, title rows, row widths/heights; tested (HelloInputs). `viewForRow` views unverified |
| `UIDatePicker` | ✅ | `.time`/`.date`/`.dateAndTime`/`.countDownTimer` (`.yearAndMonth` unverified); wheels (cyclic, invalid days spin back), compact (pills open a calendar or time popover), inline calendar (+ time pill); min/max dates, `minuteInterval`; tested (HelloInputs). Device locale/time zone are used; the `locale`/`timeZone` properties are stored only |
| `UIProgressView` | ✅ | default and bar styles |
| `UIActivityIndicatorView` | ✅ | medium/large, spins (CADisplayLink) |
| `UIPageControl` | ✅ | tap to page; tested |
| `UIColorWell` | ✅ | rainbow ring + color, presents the color picker, `.valueChanged`; tested (HelloInputs) |
| `UIScrollView` | 🟡 | one-finger pan, rubber-banding, deceleration, insets, delegate, `isPagingEnabled`, `scrollViewWillEndDragging(_:withVelocity:targetContentOffset:)`; no zooming; paging unverified outside collection-view carousels |
| `UITableView` (cells, sections, editing, swipe actions) | 🟡 | plain/grouped/inset grouped, cell reuse, self-sizing rows, sticky headers, header/footer titles and views, selection, swipe to delete + custom trailing actions, edit mode delete, animated inserts/deletes/moves, `performBatchUpdates`, `scrollToRow`, `UITableViewController`; tested (HelloTable). Missing: leading swipe actions, drag to reorder, section index, prefetching, nibs |
| `UITableViewDiffableDataSource` | ✅ | snapshots diffed into animated row inserts/deletes; reload/reconfigure; tested (HelloTable) |
| `UICollectionView` + `UICollectionViewFlowLayout` | 🟡 | cell/supplementary reuse, flow layout (both directions, delegate sizes/insets/spacing, headers/footers, pinned headers, estimated sizes), multiple selection, animated inserts/deletes/moves, `performBatchUpdates`, `scrollToItem`, `UICollectionViewController`; tested (HelloCollection). Missing: drag and drop, reordering, prefetching, decoration views, custom layout transitions, nibs |
| `UICollectionViewCompositionalLayout` | 🟡 | items, nested horizontal/vertical groups (repeating, `count:`), fractional/absolute/estimated sizes, fixed/flexible spacing, content insets, boundary headers/footers (pinning), section provider + environment, orthogonal scrolling (continuous, paging, group paging); tested (HelloCollection). Missing: horizontal scroll direction, decoration items, `visibleItemsInvalidationHandler`, custom group providers |
| `UICollectionViewDiffableDataSource`, `NSDiffableDataSourceSnapshot` | 🟡 | snapshots diffed into animated item inserts/deletes, reconfigure, supplementary provider, `CellRegistration`/`SupplementaryRegistration`; tested (HelloCollection). Missing: `NSDiffableDataSourceSectionSnapshot` (outlines), reordering handlers, async apply |
| List cells (`UICollectionLayoutListConfiguration`, `UIListContentConfiguration`, cell accessories) | 🟡 | list layouts (plain, grouped, inset grouped, sidebar colours), supplementary headers/footers, separators, self-sizing rows, `UICollectionViewListCell` accessories (disclosure, checkmark, detail, delete, reorder, outline, label, custom view); tested (HelloCollection). `UIListContentConfiguration` is a class here, not a struct (adapted). Missing: list swipe actions, outline expansion, custom `UIContentConfiguration` views |
| `UIStackView` (axis, spacing, custom spacing, alignment, distribution) | ✅ | arranged as Auto Layout constraints |
| `UIVisualEffectView` + `UIBlurEffect` (system materials) | ✅ | real backdrop blur + light/dark tint; no saturation boost |
| `UIVibrancyEffect` | 🧩 | content drawn normally |
| `UIMenu`, `UIContextMenuInteraction` (context menus, previews) | 🟡 | UIMenu pop-ups for UIButton.menu (sections, checkmarks, destructive, submenus); no context-menu previews |
| `UIToolbar`, `UIBarButtonItem` | ✅ | system items, titles, images, primary actions, menus, flexible/fixed spaces; tested |
| `UINavigationBar` (standalone, appearance) | 🟡 | large titles collapsing on scroll, scroll-edge transparency, appearances (basic), UIAppearance proxies (tint tested) |
| `UITabBar` | ✅ | items, badges, selected/unselected tints; no "More" tab beyond 5 items |
| `UISearchBar` | ✅ | search field (magnifier, placeholder, clear button, search return key), Cancel button, delegate, keyboard traits; tested (HelloInputs). Scope bar and bar styles unverified |
| `UIRefreshControl` | ✅ | `scrollView.refreshControl` / `UITableViewController.refreshControl`: pull past the threshold starts refreshing (`.valueChanged`), spinner stays until `endRefreshing()`; tested (HelloInputs). No `attributedTitle` (no NSAttributedString) |
| `UIEditMenuInteraction` (copy/paste menu) | ❌ | |
| `UIAppearance` proxies (`UINavigationBar.appearance()`) | 🟡 | adapted (no message forwarding): proxies are offscreen instances; changed appearance properties (colors, bar appearances, title attributes, fonts, translucency, …) apply when a view first enters a window unless it set them itself; `whenContainedInInstancesOf:` and trait style; tested (HelloInputs). Per-state setters (`setTitleTextAttributes(_:for:)`) and `UIBarItem` proxies not applied |
| `UIInputView`, `inputView` / `inputAccessoryView` | 🟡 | custom keyboards work; arbitrary input views unverified |
| `UIPointerInteraction`, `UIPencilInteraction`, Apple Pencil | ❌ | |

### Layout

| API / feature | Status | Notes |
|---|---|---|
| Auto Layout (`NSLayoutConstraint`, activate/deactivate, priorities, inequalities) | ✅ | Cassowary solver, rebuilt per layout pass |
| Layout anchors (`NSLayoutXAxisAnchor`, `…YAxis…`, `NSLayoutDimension`, system spacing) | ✅ | |
| Visual Format Language (`constraints(withVisualFormat:)`) | ❌ | |
| Intrinsic content size, hugging / compression resistance | ✅ | |
| `systemLayoutSizeFitting` | ✅ | |
| `UILayoutGuide`, `safeAreaLayoutGuide`, `layoutMarginsGuide` | ✅ | per-device safe areas |
| `additionalSafeAreaInsets` (container insets propagate to children) | ✅ | navigation/tab bars; scroll views adjust |
| `readableContentGuide` | 🟡 | exists; width rules unverified |
| `keyboardLayoutGuide` | ❌ | |
| Layout margins, `directionalLayoutMargins` | ✅ | |
| `UIScrollView` `contentLayoutGuide` / `frameLayoutGuide` | ✅ | |
| Trait collections (style, idiom, size classes, display scale) | ✅ | |
| `traitCollectionDidChange` | ✅ | |
| `registerForTraitChanges` (iOS 17), custom traits | ❌ | |
| Size classes | ✅ | fixed per device (portrait) |
| Dynamic Type: `preferredFont(forTextStyle:)` | ✅ | default (Large) size only |
| Dynamic Type size changes, `UIFontMetrics`, `adjustsFontForContentSizeCategory` | 🧩 | property stored; text size never changes |
| Right-to-left layout, `semanticContentAttribute` | ❌ | |
| Rotation layout (`viewWillTransition(to:with:)`) | ✅ | coordinator alongside/completion, size classes, side safe areas; tested (HelloRotation). Landscape nav bars keep portrait height |

### Animation

| API / feature | Status | Notes |
|---|---|---|
| `UIView.animate(withDuration:…)` | ✅ | frame/center/bounds, alpha, transform, backgroundColor and layer corner radius/border/shadow interpolate |
| Timing curves (ease in/out, linear) | ✅ | |
| Spring animations (damping/velocity; iOS 17 `springDuration`/`bounce`) | ✅ | |
| Delay, repeat, autoreverse, begin-from-current-state | ✅ | retargets from the current value |
| `performWithoutAnimation`, `areAnimationsEnabled` | ✅ | |
| Constraint animations (`layoutIfNeeded` in an animation block) | 🟡 | frames set inside the block animate; unverified end to end |
| `UIView.transition(with:)` | 🟡 | adapted: flips and curls squash the view to its axis and unfold it (2D, no perspective) with the changes applied at the midpoint; cross dissolve fades out and back in (no snapshot cross-fade); tested (HelloAnimations) |
| `transition(from:to:)` | ✅ | cross dissolve between the views, flips/curls as above (2D), `.showHideTransitionViews` or replacement in the superview; tested (HelloAnimations) |
| `animateKeyframes` / `addKeyframe` | ✅ | keyframe segments per property on one timeline, overall curve from the options, discrete mode; cubic/paced modes interpolate linearly; tested (HelloAnimations) |
| `UIViewPropertyAnimator` (interruptible, scrubbable) | ✅ | start/pause/stop/finish(at:), `fractionComplete` scrubbing, `isReversed`, add animations/completions, `pausesOnCompletion`, cubic/spring timing parameters, `runningPropertyAnimator`; `layer.presentation()` reports in-flight values; tested (HelloAnimations). `continueAnimation` ignores new timing parameters (duration factor only) |
| Layer property animations (cornerRadius, shadow, …) | 🟡 | a view's layer animates corner radius, border width/color and shadow opacity/radius/offset in UIView/property-animator blocks (tested: radius, border); no `CABasicAnimation`/`CAKeyframeAnimation` objects |
| UIKit Dynamics (`UIDynamicAnimator`, behaviors) | ❌ | |

### Gestures & touches

| API / feature | Status | Notes |
|---|---|---|
| `touchesBegan/Moved/Ended/Cancelled`, responder chain | ✅ | |
| Multi-touch | ❌ | the mouse is a single finger |
| `UITapGestureRecognizer` | ✅ | |
| `UIPanGestureRecognizer` (translation, velocity) | ✅ | |
| `UILongPressGestureRecognizer` | ✅ | |
| `UISwipeGestureRecognizer` | ✅ | directions, delegate, failure requirements; tested (HelloGestures) |
| `UIPinchGestureRecognizer`, `UIRotationGestureRecognizer` | ❌ | need multi-touch |
| `UIScreenEdgePanGestureRecognizer` | ✅ | starts only within 20 pt of `edges`; tested (HelloGestures) |
| `UIHoverGestureRecognizer` | ❌ | |
| `UIGestureRecognizerDelegate` (simultaneous recognition, `require(toFail:)`) | 🟡 | `gestureRecognizerShouldBegin`, `shouldReceive(_ touch:)`, `shouldRecognizeSimultaneouslyWith` (with exclusive recognizers), `UIView.gestureRecognizerShouldBegin`, `require(toFail:)` for discrete recognizers (tested: single vs double tap); `shouldRequireFailure(of:)` overrides are not consulted |
| Custom `UIGestureRecognizer` subclasses | ✅ | `UIGestureRecognizerSubclass`: touches callbacks, settable `state` sends actions, `reset`; tested (HelloGestures) |
| Shake / motion events | ✅ | `motionBegan/Ended` (shake) via Ctrl+Shift+Z or the script command `shake`; tested (HelloGestures) |
| Hardware keys (`UIKeyCommand`, `pressesBegan`) | ✅ | host keyboard → `UIPress`/`UIKey` (HID usage, modifiers) on the responder chain; `keyCommands`/`addKeyCommand` matched before typing; tested (HelloGestures). No discoverability HUD |

### Text input & keyboard

| API / feature | Status | Notes |
|---|---|---|
| System keyboard (English US: letters/numbers/symbols, shift, auto-capitalization, return-key titles) | ✅ | |
| Keyboard types (number pad, decimal, email, URL, phone) | 🟡 | trait stored; always the full keyboard |
| Other languages, emoji keyboard | ❌ | |
| Autocorrection, predictive bar, spell checking | ❌ | |
| Selection, caret movement, loupe, copy/paste/edit menu | ❌ | |
| `UITextFieldDelegate` | ✅ | |
| Secure text entry | ✅ | bullets |
| Keyboard notifications (`keyboardWillShow…`, frame/duration user info) | ✅ | |
| `keyboardDismissMode` (on drag / interactive) | 🟡 | unverified |
| Typing from the host keyboard | ✅ | `ISIM_SOFTWARE_KEYBOARD=0` hides the on-screen one |
| Custom keyboard extensions (globe key, keyboard list) | ✅ | |
| `UITextInput` positions/ranges, marked text (IME) | ❌ | |
| Password AutoFill, `textContentType`, one-time codes | 🧩 | trait stored; no AutoFill |
| Dictation, Scribble | ❌ | |

### Drawing, images & symbols

| API / feature | Status | Notes |
|---|---|---|
| `UIBezierPath` (rect, oval, rounded rect, arcs, curves, fill, stroke) | 🟡 | no dashes, line caps/joins, `addClip`, `contains` |
| `UIRectFill`, `UIRectFrame` | ✅ | |
| `UIGraphicsImageRenderer` / `UIGraphicsBeginImageContext` (offscreen drawing) | ✅ | image/pngData/jpegData renderers, formats (scale, opaque), renderer context helpers, nested contexts; tested (HelloImages). Backdrop blur inside an offscreen context reads the screen |
| `UIGraphicsPDFRenderer`, printing | ❌ | |
| `UIImage(named:)` (bundle + asset catalog, 1x/2x/3x, dark variants) | ✅ | |
| `UIImage(contentsOfFile:)`, `UIImage(cgImage:)` | ✅ | |
| `UIImage(data:)` | ✅ | PNG/JPEG/GIF/SVG via the host decoders, with `scale:`; tested (HelloImages) |
| `pngData()` / `jpegData()` | ✅ | `UIImagePNGRepresentation`/`UIImageJPEGRepresentation` (JPEG composites transparency over black, as iOS does); tested (HelloImages) |
| `resizableImage(withCapInsets:)`, `withHorizontallyFlippedOrientation` | ❌ | |
| `withTintColor`, rendering modes (template/original) | ✅ | |
| SF Symbols (`UIImage(systemName:)`) | 🟡 | substitutes (procedural shapes / Adwaita symbolic icons), not Apple's glyphs |
| `UIImage.SymbolConfiguration` (point size, weight, scale, text style) | ✅ | |
| Symbol rendering modes (hierarchical, palette, multicolor), symbol effects | ❌ | |
| `UIColor` (RGB/HSB/white, system & semantic colors, dynamic provider) | ✅ | Apple HIG light/dark values |
| Named asset-catalog colors (light/dark) | ✅ | |
| `UIFont` (system weights, italic, monospaced, monospaced digits, metrics) | 🟡 | Adwaita Sans substitutes SF Pro; `fontDescriptor` missing |
| Custom fonts (`UIAppFonts`) | ✅ | registered at launch |
| `NSString.draw(in:withAttributes:)`, `boundingRect(with:)` | ✅ | NSString and NSAttributedString drawing/measuring, `NSParagraphStyle`, `NSStringDrawingOptions`; tested (HelloImages). `NSShadow` is accepted, not drawn |

### Haptics & feedback

| API / feature | Status | Notes |
|---|---|---|
| `UIImpactFeedbackGenerator`, `UISelectionFeedbackGenerator`, `UINotificationFeedbackGenerator` | 🧩 | no haptics, like Apple's Simulator |
| Core Haptics (`CHHapticEngine`) | ❌ | |
| `AudioServicesPlaySystemSound` / vibration | ❌ | |

### Accessibility

| API / feature | Status | Notes |
|---|---|---|
| `accessibilityIdentifier` | ✅ | drives isim's scripted tests (`tapid`) |
| `accessibilityLabel/Hint/Value/Traits`, `isAccessibilityElement` | 🟡 | stored; no assistive technology reads them |
| VoiceOver, Switch Control, Voice Control | ❌ | |
| `UIAccessibility.isVoiceOverRunning`, `isReduceMotionEnabled`, `isBoldTextEnabled` | 🧩 | always off |
| `UIAccessibility.post(notification:)`, custom actions, rotors | ❌ | |
| Larger Text sizes, Bold Text, Increase Contrast, Reduce Transparency settings | ❌ | |
| Large Content Viewer | ❌ | |

### Drag & drop

| API / feature | Status | Notes |
|---|---|---|
| `UIDragInteraction`, `UIDropInteraction` | ❌ | |
| Table/collection view drag & drop | ❌ | |
| `NSItemProvider` | ❌ | |

### Appearance & dark mode

| API / feature | Status | Notes |
|---|---|---|
| Light / dark appearance (`--dark`, Settings > Display & Brightness) | ✅ | |
| Dynamic colors resolve per trait collection | ✅ | |
| Live appearance switch while the app runs | 🟡 | shell notifies apps; per-view refresh unverified |
| `overrideUserInterfaceStyle` (view, controller) | ✅ | |
| Accent color from the asset catalog (`AccentColor`) | 🟡 | used by SwiftUI's `accentColor`; UIKit global tint unverified |

---

## SwiftUI

isim's SwiftUI is an independent re-implementation (Apple's is closed source): views evaluate into a node tree,
are laid out with SwiftUI-style proposals, and render as UIKit views.

### App & scenes

| API / feature | Status | Notes |
|---|---|---|
| `App` protocol, `@main` | ✅ | |
| `WindowGroup` | ✅ | one window; `title`/`id` ignored |
| Several scenes in `body`, `Settings`, `DocumentGroup`, `Window` | ❌ | `SceneBuilder` takes one scene |
| `@Environment(\.scenePhase)` | ✅ | active / inactive / background |
| `@UIApplicationDelegateAdaptor` | ❌ | |
| `UIHostingController` | ✅ | |
| `.onOpenURL` | 🟡 | delivered from isim's URL handling; inter-app routing unverified |
| `.onContinueUserActivity`, `.handlesExternalEvents` | ❌ | |
| `.backgroundTask` | ❌ | |
| `openWindow` / `dismissWindow` | ❌ | |
| `#Preview` / `PreviewProvider` | ❌ | no preview canvas; `#Preview` does not compile |

### State & data flow

| API / feature | Status | Notes |
|---|---|---|
| `@State` | ✅ | stored per structural position |
| `@Binding`, `Binding(get:set:)`, `.constant`, dynamic-member bindings | ✅ | |
| `ObservableObject` + `@Published` | ✅ | isim Combine |
| `@StateObject`, `@ObservedObject` | ✅ | |
| `@EnvironmentObject`, `.environmentObject` | ✅ | |
| `@Environment(keyPath)`, custom `EnvironmentKey`, `.environment(_:_:)` | ✅ | |
| `@Observable` macro / Observation | ✅ | Observation built from Swift sources; macro via the toolchain plugin; renders track reads; tested (HelloObservation) |
| `@Bindable`, `@Environment(Model.self)` | ✅ | plus `.environment(_:)` for Observable objects; tested |
| `@AppStorage` | ✅ | Bool/Int/Double/String/URL/Data/RawRepresentable/optionals; persists; tested (HelloForms) |
| `@SceneStorage` | 🟡 | kept for the app lifetime (not restored across launches) |
| `@FocusState` (Bool and Hashable) | ✅ | |
| `@Namespace` | ✅ | |
| `@GestureState` | ❌ | |
| `@ScaledMetric` | 🟡 | scales with `dynamicTypeSize` (tested); the system text size is always `.large` on isim and fonts do not scale with dynamic type |
| `@FocusedValue`, `@FocusedBinding` | ❌ | |
| `PreferenceKey`, `.preference`, `.onPreferenceChange`, anchor preferences | ✅ | values reduce up the laid-out tree (incl. GeometryReader backgrounds), `transformPreference`, `anchorPreference` / `transformAnchorPreference` with `overlayPreferenceValue` / `backgroundPreferenceValue` and `proxy[anchor]`; tested (HelloLayout) |
| `Transaction`, `withTransaction` | 🟡 | carries the animation / `disablesAnimations`; custom transaction keys missing |

### Views & controls

| API / feature | Status | Notes |
|---|---|---|
| `Text` (verbatim, `LocalizedStringKey` with interpolation, font/weight/italic/color) | ✅ | |
| `Text + Text` concatenation | ✅ | parts keep their own font/colour/weight; mixed styles laid out word by word (adapted); tested (HelloText) |
| `Text(date, style:)`, `Text(_:format:)`, `Text(timerInterval:)` | ✅ | `.time/.date/.relative/.offset/.timer` styles (relative ones re-render every second), date ranges, `Text(_:format:)` with Foundation format styles, `\(value, format:)` / `\(date, style:)` interpolation, `Text(_:formatter:)`; tested (HelloText) |
| Markdown in `Text`, `AttributedString` | ✅ | string literals parse `**bold**`, `*italic*`, `***both***`, `` `code` ``, `~~strike~~`, `[links](url)` (tap opens through `openURL`); `Text(AttributedString)` maps presentation intents, links and the SwiftUI attribute scope (`foregroundColor`, `font`, underline/strikethrough, kern, baselineOffset); tested (HelloText). Italic is a sheared glyph run (isim fonts have no italic faces) |
| `strikethrough`, `underline`, `kerning`, `tracking`, `textCase`, `baselineOffset` | ✅ | on `Text` and as view modifiers; lines are hairline views, kerning places glyphs one by one (`tracking` = `kerning`), line patterns drawn solid; tested (HelloText) |
| `lineLimit`, `multilineTextAlignment` | ✅ | |
| `truncationMode`, `minimumScaleFactor`, `allowsTightening` | 🟡 | head/middle/tail truncation of one-line text (tested), `minimumScaleFactor` shrinks one-line labels to fit (screenshot only); `allowsTightening` is stored, no effect |
| `Image` (asset/bundle name, `uiImage:`), `resizable`, `renderingMode`, `interpolation` | ✅ | |
| `Image(systemName:)` | 🟡 | substitute glyphs, not SF Symbols |
| `imageScale`, `symbolRenderingMode`, `symbolVariant`, `symbolEffect` | 🟡 | `imageScale` sizes symbols (tested); `symbolVariant` appends `.fill`/`.circle`/... to the symbol name (unverified); `symbolRenderingMode` accepted, ignored; `symbolEffect` missing |
| `AsyncImage` | ✅ | URLSession (http(s), file, data URLs); phases, `content:placeholder:`; decoded through a temporary file (isim's UIImage has no `init(data:)`); tested (HelloPickers) |
| `Label` | ✅ | |
| `Button` (action, label, role) | ✅ | |
| Button styles: `.plain`, `.borderless`, `.bordered`, `.borderedProminent`, custom `ButtonStyle` | ✅ | |
| `PrimitiveButtonStyle`, `.controlSize`, `.buttonBorderShape` | ✅ | primitive styles build the whole button and call `trigger()`; control size sets bordered padding/font; capsule / rounded / circle shapes; tested (HelloPickers) |
| `Toggle` (switch) | ✅ | |
| `toggleStyle` (`.button`, `.checkbox`, custom) | ✅ | `.switch`, `.button` (tinted when on) and custom `ToggleStyle`s (`.checkbox` is macOS-only); `.button` tested (HelloPickers) |
| `Slider` | ✅ | UISlider; step, value labels, onEditingChanged; tested |
| `Stepper` | ✅ | value/bounds/step and onIncrement/onDecrement; tested |
| `Picker` (menu, segmented, wheel, inline, navigationLink styles) | ✅ | all five styles; `.wheel` is a snapping scroll-wheel drawn by isim (no UIPickerView); tested (HelloForms, HelloPickers) |
| `DatePicker`, `MultiDatePicker` | 🟡 | `DatePicker`: compact (date/time pills open a calendar or time wheel in a sheet — iOS uses a popover), graphical (month grid, month paging, time row), wheel; `.date` / `.hourAndMinute`; ranges; `labelsHidden`; tested (HelloPickers). `MultiDatePicker` missing |
| `ColorPicker` | 🟡 | colour well opening a sheet with iOS's colour grid and an opacity slider (no spectrum/sliders pages, no eyedropper); `Color` and `CGColor` bindings; tested (HelloPickers) |
| `TextField` (String binding, placeholder, `axis: .vertical` multi-line) | ✅ | `prompt` ignored |
| `TextField(value:format:)`, `TextField(value:formatter:)` | ✅ | parseable format styles and NumberFormatter / DateFormatter values, parsed on Return or end of editing (unparseable text reverts); tested (HelloPickers) |
| `SecureField` | ✅ | |
| `TextEditor` | ✅ | multi-line field that fills its frame; tested (HelloPickers) |
| `ProgressView` | ✅ | UIProgressView bar / spinning UIActivityIndicatorView; labels and current-value labels, `.linear` / `.circular` / custom `ProgressViewStyle`; label tested (HelloPickers) |
| `Gauge` | ✅ | linear capacity (default), `.accessoryLinear`, `.accessoryCircular`, `.accessoryCircularCapacity`, custom `GaugeStyle`; tested (HelloPickers) |
| `Link` | ✅ | opens through `openURL` |
| `ShareLink` | 🟡 | opens a share sheet showing the item; isim has no share destinations (adapted) ; tested (HelloPickers) |
| `Menu` | ✅ | pop-up menu with sections, submenus, pickers, destructive buttons; tested |
| `Divider`, `Spacer`, `EmptyView`, `Color` as a view | ✅ | |
| `LabeledContent` | ✅ | |
| `ContentUnavailableView` | ✅ | icon, title, description, actions; `.search` / `.search(text:)`; tested (HelloPickers) |
| `ControlGroup`, `GroupBox`, `DisclosureGroup`, `OutlineGroup` | ✅ | disclosure rows expand/collapse (own state or `isExpanded:` binding; in a List the content follows as indented rows); `OutlineGroup` and `List(_:children:)` build the tree; control groups share one bordered row (`controlGroupStyle` ignored); tested (HelloPickers) |
| `EditButton`, `PasteButton`, `RenameButton` | 🟡 | `EditButton` toggles `\.editMode` (tested, HelloLists); `PasteButton` is a stub (no pasteboard on isim: shown disabled, tested); `RenameButton` missing |
| `VideoPlayer` (AVKit), `Map` (MapKit), `SceneView` | ❌ | |
| `SpriteView` | ✅ | see SpriteKit |

### Containers & layout

| API / feature | Status | Notes |
|---|---|---|
| `VStack`, `HStack`, `ZStack` (alignment, spacing) | ✅ | |
| `Spacer(minLength:)`, `layoutPriority`, `fixedSize` | ✅ | |
| `LazyVStack`, `LazyHStack` | 🟡 | laid out like plain stacks; `pinnedViews` ignored |
| `LazyVGrid` (`GridItem` fixed / flexible / adaptive) | 🟡 | `pinnedViews` ignored |
| `LazyHGrid` | ✅ | `init(rows:)` with fixed / flexible / adaptive rows, items flow down then across; laid out eagerly; tested (HelloLayout) |
| `Grid`, `GridRow` | ✅ | column widths from the widest cells, flexible cells share the rest; `gridCellColumns`, `gridColumnAlignment`, `gridCellAnchor`, `gridCellUnsizedAxes`, row alignment, full-width non-row views; tested (HelloLayout) |
| `ScrollView` (vertical, horizontal) | ✅ | |
| `ScrollViewReader`, `scrollTo` | ✅ | |
| `scrollIndicators`, `scrollDisabled`, `scrollBounceBehavior` | 🟡 | `scrollDisabled` tested (HelloLayout); hidden indicators and `.basedOnSize` bounce unverified |
| `scrollPosition`, `scrollTargetBehavior` (paging), `scrollTransition`, `onScrollGeometryChange` | 🟡 | `.paging` (UIScrollView paging), `.viewAligned` + `scrollTargetLayout()` (snaps to children), custom `ScrollTargetBehavior.updateTarget`, `scrollPosition(id:)` both ways; tested (HelloLayout). `scrollTransition`, `onScrollGeometryChange` missing |
| `List` (content builder, sections, data, selection) | 🟡 | inset-grouped look; `List(data)`, `List(data, children:)`, `List(selection:)` single (tested via NavigationSplitView) and multiple (circles in edit mode, unverified) |
| `listStyle`, `listRowBackground`, `listRowSeparator`, `listSectionSpacing`, `scrollContentBackground` | 🧩 | accepted, ignored |
| `.onDelete`, `.onMove`, `.swipeActions`, edit mode | ✅ | swipe to delete, leading/trailing swipe actions (tint, full swipe), edit mode delete buttons and reorder handles; tested (HelloLists) |
| `Form` | ✅ | inset-grouped rows; `formStyle` ignored |
| `Section` (header, footer) | ✅ | |
| `ForEach` (`id:`, `Identifiable`, `Range`) | ✅ | |
| `Group`, `AnyView`, `if`/`switch` in builders | ✅ | |
| `GeometryReader`, `GeometryProxy.size`, `frame(in: .local/.global)`, safe-area insets | ✅ | |
| Named coordinate spaces | 🟡 | `.named` falls back to global |
| `ViewThatFits` | ✅ | first child whose ideal size fits (per axis); tested (HelloLayout) |
| `Layout` protocol, `AnyLayout` | ✅ | `sizeThatFits` / `placeSubviews` with subviews' `sizeThatFits` / `dimensions` / `place(at:anchor:proposal:)`, caches, `layoutValue`; `AnyLayout` switching keeps child state; `HStackLayout` / `VStackLayout` / `ZStackLayout` / `GridLayout`; tested (HelloLayout). Spacing preferences are a fixed 8 pt; not animatable |
| `containerRelativeFrame` | 🟡 | relative to the nearest scroll view, else the window's safe area (navigation/tab content are not containers of their own); `count:span:spacing:` and closure forms; tested (HelloLayout) |
| `frame` (fixed, min/ideal/max, alignment), `padding`, `aspectRatio`, `offset` | ✅ | |
| `position`, `alignmentGuide` | ✅ | `position` centres the view at a point; explicit guides and custom `AlignmentID`s line up views in HStack / VStack / ZStack, also through nested stacks; tested (HelloLayout) |
| `ignoresSafeArea`, `edgesIgnoringSafeArea` | ✅ | |
| `safeAreaInset`, `safeAreaPadding`, `contentMargins` | 🟡 | `safeAreaInset` lays the inset view at the edge and the content in the rest (content does not scroll beneath it); `safeAreaPadding` is padding; `contentMargins` pads scroll view content; inset and margins tested (HelloLayout) |
| `overlay`, `background` (view, shape style, `in:` shape), `zIndex` | ✅ | |

### Navigation & presentation

| API / feature | Status | Notes |
|---|---|---|
| `NavigationStack` (root, path `[D]` / `NavigationPath`) | 🟡 | nav bar with large/inline title and back button; push/pop not animated, no edge-swipe back |
| `NavigationLink(destination:)`, `NavigationLink(value:)` | ✅ | |
| `navigationDestination(for:)` | ✅ | |
| `navigationDestination(isPresented:)`, `navigationDestination(item:)` | ✅ | pushes while presented; back / `dismiss` reset the binding; tested (HelloLists) |
| `NavigationView` | ✅ | stack style |
| `NavigationSplitView` | 🟡 | iPhone (compact) behaviour only: columns as a stack, a `List(selection:)` choice shows the next column; tested (HelloLists). No side-by-side columns (iPad), `columnVisibility` ignored |
| `navigationTitle`, `navigationBarTitleDisplayMode` | ✅ | |
| `navigationBarBackButtonHidden` | 🧩 | ignored |
| `.toolbar` with `ToolbarItem` / `ToolbarItemGroup` | 🟡 | top-bar leading/trailing only; `.principal`, `.bottomBar`, `.keyboard` not placed as on iOS |
| `toolbarBackground`, `toolbarColorScheme`, `toolbar(.hidden)` | 🟡 | `toolbar(.hidden, for: .navigationBar / .tabBar)` tested (HelloLists); bar background colour / visibility and colour scheme applied to the navigation bar (unverified) |
| `TabView` (tab bar, `.tabItem`, `.badge`, selection) | ✅ | material tab bar, SF Symbol items, badges, selection, iOS 18 `Tab`; tested |
| `TabView` `.tabViewStyle(.page)` | ✅ | swipe paging with page dots; tested |
| `.sheet(isPresented:)` / `.sheet(item:)` | ✅ | page sheet with swipe-down dismiss; content gets the environment + `dismiss`; tested (HelloPresentations) |
| `.fullScreenCover` | ✅ | slides up full screen; tested |
| `.popover` | 🟡 | shown as a sheet (iPhone behaviour); no arrow popovers on iPad |
| `.alert` | 🟡 | title, message, button roles (UIAlertController); no text fields in alerts; tested |
| `.confirmationDialog` | ✅ | action sheet with Cancel; tested |
| `presentationDetents`, `presentationDragIndicator`, `interactiveDismissDisabled` | 🟡 | adapted: sheets with detents other than `.large` are isim-drawn cards over a dimmed backdrop (`.medium`, `.large`, `.fraction`, `.height`; drag between detents or down to dismiss; selection binding); tested (HelloLists, HelloPickers). `interactiveDismissDisabled` on detent cards unverified |
| `@Environment(\.dismiss)` | ✅ | closes sheets / covers (tested, HelloPresentations), pops navigation levels and resets `navigationDestination` bindings (tested, HelloLists) |
| `.searchable` | 🟡 | search field under the List's large title (above other content), Cancel, `isSearching`, `dismissSearch`, `.onSubmit(of: .search)`; filtering and Cancel tested (HelloLists). Suggestions and scopes are ignored |
| `.refreshable` | ✅ | pull past 60 pt and release: spinner while the async action runs (List tested, HelloLists; ScrollView unverified) |
| `.inspector` | ❌ | |
| `@Environment(\.openURL)` | ✅ | |

### Modifiers & visual effects

| API / feature | Status | Notes |
|---|---|---|
| `font`, `foregroundColor`, `foregroundStyle` (Color, `.primary`…`.quaternary`, `.tint`) | ✅ | |
| `tint`, `accentColor` | ✅ | |
| `opacity`, `hidden`, `disabled` | ✅ | |
| `cornerRadius`, `clipShape` (any shape; built-in shapes as a rounded clip, others clip to their path) | ✅ | custom-shape clip tested (HelloDrawing) |
| `clipped()` | 🧩 | returns the view unchanged |
| `mask` | 🟡 | clips to the mask's shape (any shape's path); no alpha masks |
| `shadow` | 🟡 | layer-shadow approximation |
| `rotationEffect`, `scaleEffect`, `offset` | ✅ | offset content is drawn and hit-tested at its new position |
| `transformEffect` | ✅ | |
| `rotation3DEffect` | 🟡 | drawn as the affine transform that best fits the rotated corners: no perspective foreshortening (y-axis rotation tested) |
| `projectionEffect`, `ProjectionTransform` | 🟡 | affine part exact; perspective terms approximated like rotation3DEffect (unverified) |
| `GeometryEffect` (custom, animatable), `ignoredByLayout` | ✅ | custom shear tested |
| `blur`, `brightness`, `contrast`, `saturation`, `grayscale`, `colorMultiply`, `hueRotation`, `blendMode` | 🧩 | accepted, no effect |
| `drawingGroup`, `compositingGroup` | 🧩 | |
| `allowsHitTesting` | ✅ | |
| `contentShape` | 🧩 | ignored |
| `id(_:)` | ✅ | resets state |
| `tag` | ✅ | explicit, and implicit from ForEach ids |
| `statusBarHidden`, `preferredColorScheme` | ✅ | |
| `persistentSystemOverlays`, `defersSystemGestures` | 🧩 | |
| `sensoryFeedback` | 🧩 | no haptics |
| `keyboardType`, `autocorrectionDisabled`, `textInputAutocapitalization`, `submitLabel` | ✅ | keyboard type is stored only (see UIKit) |
| `textFieldStyle`, `labelStyle` | ✅ | `.roundedBorder` / `.plain` fields; `.iconOnly` / `.titleOnly` / `.titleAndIcon` and custom `LabelStyle`s; tested (HelloPickers) |
| `pickerStyle`, `datePickerStyle`, `progressViewStyle`, `gaugeStyle` | ✅ | see the controls above; tested (HelloForms, HelloPickers) |
| `ViewModifier`, `.modifier` | ✅ | |
| `redacted`, `privacySensitive` | 🟡 | `.redacted(reason: .placeholder)` draws text as grey bars (tested, HelloPickers); images are not redacted; `privacySensitive` has no effect |
| `badge`, `help`, `contextMenu` | 🟡 | `badge` on tabs and list rows, `contextMenu` (long press -> pop-up menu) tested (HelloLists); preview ignored; `help` missing |

### Shapes, paths, gradients & materials

Shapes, paths, gradients and Canvas draw through libisim_host (cairo); tested by HelloDrawing (`tests/ui/drawing.sh`, pixel checks).

| API / feature | Status | Notes |
|---|---|---|
| `Rectangle`, `RoundedRectangle`, `Circle`, `Capsule` | ✅ | color fills use a view with a corner radius; other paints draw the path |
| Custom `Shape` (`path(in:)`) | ✅ | shape inits and `path(in:)` are not main-actor isolated, like SwiftUI |
| `Path` (move/line/quad/curve, `addArc` (center and tangent forms), `addRelativeArc`, rects, rounded rects, ellipses, `Path { }`, `Path(CGPath)`, `cgPath`) | ✅ | arcs become cubic curves |
| `Path` queries (`boundingRect`, `contains(_:eoFill:)`, `trimmedPath`, `applying`, `offsetBy`, string form) | ✅ | |
| `Path.strokedPath`, boolean operations (`union`, `intersection`, …), `Shape.union` etc. | ❌ | |
| `fill` (colors, any style, `FillStyle(eoFill:)`) | ✅ | |
| `stroke` / `stroke(style:)` with `StrokeStyle` (width, caps, joins, miter limit, dashes, dash phase) | ✅ | dashes tested; joins and miter limit unverified |
| `trim(from:to:)` | ✅ | exact on curves (arc length) |
| `Ellipse`, `UnevenRoundedRectangle` | ✅ | |
| `ContainerRelativeShape` | 🟡 | the frame's rectangle (isim has no container shapes) |
| `InsettableShape` (`inset(by:)`, `strokeBorder`) | ✅ | |
| `AnyShape` | ✅ | |
| Shape `.offset`, `.rotation`, `.scale`, `.transform`, `.size` | ✅ | offset and rotation tested; scale/transform/size unverified |
| `fill(_:).stroke(_:)` on a filled shape (iOS 17) | 🟡 | drawn as an overlay (unverified) |
| `LinearGradient`, `RadialGradient`, `AngularGradient` / `conicGradient`, `EllipticalGradient`, `Gradient` (colors, stops) | ✅ | as views and shape styles |
| Gradients in `fill`, `foregroundStyle`, `background`, `background(_:in:)`, `overlay` | ✅ | gradient strokes unverified |
| `Color.gradient` (`AnyGradient`) | ✅ | a top-to-bottom gradient a little lighter at the top (approximates Apple's) |
| Text with a gradient `foregroundStyle` | 🟡 | drawn in the gradient's first color (tested); no gradient across the glyphs |
| `Material` (`.ultraThinMaterial` … `.bar`) | ✅ | real backdrop blur (UIVisualEffectView) |
| `Color` (system colors, RGB/HSB/white, `Color(uiColor:)`, asset colors) | ✅ | |
| `ImagePaint` (`.image(_:sourceRect:scale:)`) | ✅ | tiles fills; image strokes are not drawn |
| `Canvas` / `GraphicsContext` (fill/stroke paths with colors, styles and gradients, text, images, transforms, opacity, clip, `drawLayer`) | ✅ | filters, blend modes, `clipToLayer` and symbols are accepted and not drawn |
| Shaders (`ShaderLibrary`, `.colorEffect`, `.layerEffect`, `.distortionEffect`) | ❌ | need Metal, which isim does not have |

### Animation

Landed 2026-10-05 (commit d0dcb9b, `swift/overlays/SwiftUI/Animation.swift`): an animated update runs the view updates
inside UIKit's animation engine, so frames, opacity, transforms and colors interpolate. Animatable data (shape trims
and paths, custom `Animatable` shapes/views/modifiers, shape colors and gradients) interpolates per frame in the same
updates (`Animatable.swift`, same timing curves); HelloDrawing checks those half-way through a 2 s linear animation.

| API / feature | Status | Notes |
|---|---|---|
| `withAnimation` (incl. `completion:`) | ✅ | animates the next render (frames, opacity, transforms, colors) |
| `.animation(_:value:)` | ✅ | animates its subtree when the value changes |
| Curves & springs (`.easeInOut`, `.spring`, `.bouncy`, `.snappy`, `.smooth`, `timingCurve`, `interpolatingSpring`), repeat/delay/speed | 🟡 | mapped onto UIKit curves/springs; custom timing curves approximated (unverified) |
| Transitions (`.opacity`, `.scale`, `.slide`, `.move`, `.offset`, `.push`, `asymmetric`, `combined`) | 🟡 | insertion and removal play; each kind unverified |
| `matchedGeometryEffect` | 🟡 | an inserted view moves from the matched view's old frame; no simultaneous source/target |
| `contentTransition` (`.numericText`, `.interpolate`) | 🧩 | text content is not animated |
| Animating shape `trim`, paths, colors, gradients | ✅ | trim, custom path, fill color and gradient stops tested mid-animation |
| `Animatable` / `animatableData` (`VectorArithmetic`, `AnimatablePair`), `AnimatableModifier` | ✅ | custom shape and modifier tested; repeating animations of animatable data unverified |
| `phaseAnimator`, `PhaseAnimator` | ✅ | continuous cycling tested; `trigger:` form unverified |
| `keyframeAnimator`, `KeyframeAnimator`, `KeyframeTimeline` (`LinearKeyframe`, `SpringKeyframe`, `CubicKeyframe`, `MoveKeyframe`, `UnitCurve`) | ✅ | trigger form, linear/move/cubic values tested; spring keyframes and the repeating form unverified; keyframe velocities ignored |
| `TimelineView` (`.animation`, `.periodic`, `.everyMinute`, `.explicit`) | ✅ | `.periodic` and `.animation` tested; `.everyMinute`/`.explicit` unverified |

### Gestures

| API / feature | Status | Notes |
|---|---|---|
| `onTapGesture(count:)`, `TapGesture` | ✅ | |
| `onLongPressGesture`, `LongPressGesture` | ✅ | |
| `DragGesture` (`onChanged`/`onEnded`, translation, velocity, predicted end) | ✅ | |
| `simultaneousGesture`, `highPriorityGesture` | 🟡 | treated like `.gesture` |
| `MagnifyGesture`, `RotateGesture` | ❌ | no multi-touch |
| `SpatialTapGesture` | ❌ | |
| `sequenced`, `exclusively`, `simultaneously(with:)`, `.updating` | ❌ | |

### Lifecycle, async & events

| API / feature | Status | Notes |
|---|---|---|
| `onAppear`, `onDisappear` | ✅ | |
| `.task`, `.task(id:)` | ✅ | cancelled on disappear |
| `onChange(of:)` (old/new, `initial:`) | ✅ | |
| `onReceive` | ✅ | |
| `onSubmit` | ✅ | |
| `onKeyPress`, `keyboardShortcut` | ❌ | |
| `onGeometryChange`, `onContinuousHover`, `onHover` | 🟡 | `onGeometryChange` (size; `frame(in: .global)` is approximate) tested (HelloLayout); hover modifiers missing |

### Focus & keyboard

| API / feature | Status | Notes |
|---|---|---|
| `focused(_:)`, `focused(_:equals:)` | ✅ | |
| `focusable`, `defaultFocus`, `focusSection` | ❌ | |
| `scrollDismissesKeyboard` | 🧩 | ignored |
| Form scrolls the focused field above the keyboard | ✅ | |

### Environment values

| API / feature | Status | Notes |
|---|---|---|
| `colorScheme`, `locale`, `font`, `isEnabled`, `lineLimit`, `multilineTextAlignment` | ✅ | |
| `horizontalSizeClass`, `verticalSizeClass`, `displayScale` | ✅ | |
| `layoutDirection` | 🟡 | value exists; RTL layout not implemented |
| `calendar`, `timeZone`, `dynamicTypeSize`, `colorSchemeContrast` | 🟡 | values exist and can be set; `dynamicTypeSize` drives `@ScaledMetric` (tested) but text does not scale; `colorSchemeContrast` is always `.standard` |
| `editMode`, `isPresented`, `isSearching`, `presentationMode` | 🟡 | `editMode` (a window-wide binding, or your own via `.environment`) and `isPresented` tested (HelloLists); `isSearching`, `presentationMode` unverified |
| `accessibilityReduceMotion` and other accessibility values | ❌ | |
| `requestReview` | ✅ | see StoreKit |

### Accessibility

| API / feature | Status | Notes |
|---|---|---|
| `accessibilityIdentifier` | ✅ | |
| `accessibilityLabel` | ✅ | stored on the UIKit view |
| `accessibilityHint`, `accessibilityHidden` | 🧩 | ignored |
| `accessibilityValue`, `accessibilityAddTraits`, `accessibilityElement(children:)`, `accessibilityAction` | ❌ | |

### UIKit interop

| API / feature | Status | Notes |
|---|---|---|
| `UIViewRepresentable` (coordinator, update, dismantle) | ✅ | |
| `UIViewControllerRepresentable` | ✅ | |
| `UIHostingController` in UIKit apps | ✅ | |
| `sizeThatFits(_:uiView:context:)` on representables | ❌ | |

---

## Swift Charts

| API / feature | Status | Notes |
|---|---|---|
| `Chart` view (`Chart { }`, `Chart(data) { }`, `ForEach` of marks, `if`/`else` content), `import Charts` | ✅ | isim's own implementation on its SwiftUI (`swift/overlays/Charts`; `if`/`else` content unverified); tested by HelloCharts (`tests/ui/charts.sh`, measured in the screenshot) |
| `BarMark` (vertical, horizontal, ranges, date bins with `unit:`, `width`/`height`) | ✅ | |
| Bar stacking (`.standard`), grouping (`position(by:)`) | ✅ | `.normalized`/`.center` stacking unverified |
| `LineMark` (`series:`, `interpolationMethod`), `PointMark` | ✅ | linear and catmullRom drawn in the test; step/cardinal/monotone unverified |
| `symbol(_:)`, `symbol(by:)`, `symbolSize` | 🟡 | basic symbol shapes (circle, square, triangle, diamond, pentagon, plus, cross); unverified; `symbol { view }` missing |
| `AreaMark` (stacked series, `yStart`/`yEnd`) | ✅ | stacking of several series unverified |
| `RuleMark`, `RectangleMark` | ✅ | |
| `SectorMark` (pie, donut `innerRadius`, `outerRadius`, `angularInset`) | ✅ | `angularInset` unverified; corner radius ignored |
| `PlottableValue.value(_:_:)`, `Plottable` (numbers, strings, dates, `RawRepresentable` enums) | ✅ | |
| `foregroundStyle(by:)` with the default palette and a legend, `chartForegroundStyleScale`, `chartLegend` | ✅ | `chartLegend(position: .top)` and custom legend content unverified |
| Axes: `chartXAxis`/`chartYAxis` (`.hidden`, `AxisMarks` position and values, `AxisGridLine`, `AxisTick`, `AxisValueLabel` with custom content), date axes | ✅ | `AxisTick` unverified; `AxisValueLabel(format:)` missing (no `FormatStyle` on isim) |
| Scales: `chartXScale`/`chartYScale(domain:)` (ranges, category lists, `.automatic(includesZero:reversed:)`) | ✅ | log/sqrt/power scale types are drawn linear |
| `annotation(position:alignment:spacing:)` | ✅ | |
| `chartXAxisLabel`, `chartYAxisLabel` | 🟡 | simple placement (unverified) |
| `chartOverlay`/`chartBackground` (`ChartProxy`), selection (`chartXSelection`), scrolling (`chartScrollableAxes`) | ❌ | |
| `chartPlotStyle`, vectorized plots (`BarPlot`, `LinePlot`, iOS 18), `Chart3D` | ❌ | |

---

## Foundation

isim's Foundation is self-authored: an Objective-C framework plus a Swift overlay (value types such as `Data`,
`Date`, `URL`, `Calendar` are pure Swift).

### Strings & text

| API / feature | Status | Notes |
|---|---|---|
| `String` ⇄ `NSString` bridging | ✅ | copies instead of lazy bridging |
| `NSString` / `NSMutableString` API (search, replace, case, trimming, components, paths) | 🟡 | search options (case/diacritic-insensitive, anchored, backwards, regex), Unicode case mapping, substring/line enumeration; comparisons are code-point ordered, not locale-aware |
| `String(format:)`, `NSLog` | ✅ | |
| String encodings (`data(using:)`, `String(data:encoding:)`, `String(contentsOf:)`) | ✅ | |
| `CharacterSet` | ✅ | BMP only |
| `NSAttributedString`, `NSMutableAttributedString` | ✅ | Foundation keys only (UIKit's font/color keys belong to UIKit); `mutableString` is a snapshot |
| `AttributedString`, `AttributeContainer`, attribute scopes, runs | 🟡 | Foundation scope (link, inline/presentation intents, imageURL, ...); no Codable, no iOS 17 invalidation/inheritance rules |
| `AttributedString(markdown:)` | 🟡 | CommonMark + GFM blocks/inlines as presentation intents; no reference links, extended attributes or source positions |
| `NSRegularExpression`, `NSTextCheckingResult` | ✅ | host PCRE2 (close to ICU syntax); templates, named groups, options |
| `NSDataDetector` | 🟡 | links, phone numbers, dates; addresses and transit info are not detected |
| `Scanner` | ✅ | ObjC and Swift (`scanString`, `scanInt`, `scanDouble`, `scanDecimal`, `currentIndex`) APIs |
| `String(localized:)`, `NSLocalizedString`, `Bundle.localizedString` | ✅ | |
| `LocalizedStringResource` | ❌ | |
| String Catalogs (`.xcstrings`) | 🟡 | compiled to `.strings`; plural variants use "other" only; device/width variants dropped |
| `.stringsdict` plural rules | ❌ | |

### Collections & values

| API / feature | Status | Notes |
|---|---|---|
| `NSArray`, `NSDictionary`, `NSSet` (+ mutable), literals, fast enumeration, sorting | ✅ | |
| `NSOrderedSet`, `NSCountedSet`, `NSIndexSet` / `IndexSet`, `NSCache`, `NSHashTable`, `NSMapTable`, `NSPointerArray` | ✅ | `NSCache` evicts by count/cost limits only (no memory-pressure purging); weak tables use ObjC weak references |
| `IndexPath` / `NSIndexPath` (+ UIKit `row`/`section`/`item`) | ✅ | value type bridged to NSIndexPath; tested (HelloTable) |
| `NSNumber`, `NSValue` (CG geometry), `NSNull` | ✅ | |
| `UUID` | ✅ | |
| `Decimal` | 🟡 | 38 significant digits, exact arithmetic, `NSDecimalRound`/`NSDecimalAdd`..., `pow`; no `NSDecimalNumber`, does not bridge to an Objective-C object |
| `NSError`, `LocalizedError`, `CustomNSError` | ✅ | |
| `NSPredicate`, `NSExpression` (format strings, `filtered(using:)`) | 🟡 | comparisons, string operators (`CONTAINS[cd]`, `LIKE`, `MATCHES`, ...), aggregates, `ANY`/`ALL`, key paths, block predicates; no subqueries or function expressions; the `#Predicate` macro is not available |
| `NSSortDescriptor`, `SortDescriptor`, `KeyPathComparator`, `sorted(using:)` | ✅ | |
| Key-value coding (`value(forKey:)`, key paths, collection operators) and observing (KVO, `observe(\.x)`, `publisher(for:)`) | ✅ | KVO wraps setters; `@objc dynamic` Swift properties observable |
| `UndoManager` | ✅ | groups, run-loop grouping, redo, action names, `registerUndo(withTarget:handler:)` |
| `Progress` | 🟡 | units, children, KVO on `fractionCompleted`, localized description; no publishing/file progress |

### Encoding & serialization

| API / feature | Status | Notes |
|---|---|---|
| `JSONEncoder` / `JSONDecoder` (key/date/data/float strategies, output formatting) | ✅ | |
| `JSONSerialization` | ✅ | NSNumber/NSNull like Apple |
| `PropertyListEncoder` / `PropertyListDecoder` | ✅ | XML and binary |
| `PropertyListSerialization` | ✅ | XML, binary, OpenStep (read) |
| Reading XML plists (`NSDictionary(contentsOfFile:)`, Info.plist) | ✅ | |
| Binary plists | ✅ | read and written (Info.plist, user defaults, serialization) |
| `NSKeyedArchiver` / `NSKeyedUnarchiver`, `NSCoding`, `NSSecureCoding` | ✅ | Apple's keyed-archive format (bplist `$objects`/`$top`), shared references and cycles, allowed classes, class name mapping |

### Dates, calendars & formatters

| API / feature | Status | Notes |
|---|---|---|
| `Date`, `TimeInterval`, `Date.now` | ✅ | |
| `Calendar`, `DateComponents`, `DateInterval` | 🟡 | Gregorian + ISO 8601; other calendars compute as Gregorian |
| `TimeZone` (named zones, DST) | ✅ | Settings > Date & Time or the host's zone; changes apply live (`NSSystemTimeZoneDidChange`, `resetSystemTimeZone`) |
| `Locale` (identifiers, language/region, separators, currency, `Locale.Language`) | ✅ | |
| `DateFormatter` (styles, `dateFormat`, templates, parsing) | 🟡 | built-in CLDR subset: en, pt, es, fr, de, it, ja names and ~40 regions; other languages fall back to English names |
| `NumberFormatter` (decimal, currency, percent, scientific, spell-out, ordinal, rounding, parsing) | 🟡 | ICU-style rounding; locale data limited to the built-in regions; spell-out English only |
| `ISO8601DateFormatter` | ✅ | |
| `RelativeDateTimeFormatter`, `DateComponentsFormatter`, `DateIntervalFormatter` | 🟡 | localized for the built-in languages |
| `.formatted()` / `FormatStyle` (dates, ISO 8601, relative, intervals, numbers, currency, percent, lists, byte counts, durations, measurements) and parse strategies | 🟡 | follows the device region; same locale data limits as the formatters |
| `Measurement`, `Unit*`, `MeasurementFormatter` | 🟡 | 22 unit families with conversion; locale-preferred units for length, mass, temperature, speed, volume; unit names localized for the built-in languages |
| `ByteCountFormatter`, `PersonNameComponentsFormatter`, `ListFormatter` | ✅ | |

### Files, bundles & preferences

| API / feature | Status | Notes |
|---|---|---|
| App sandbox container (Documents, Library, Caches, tmp) | ✅ | per app, under `ISIM_DATA` |
| `FileManager` (exists, create, remove, copy, move, list, `urls(for:in:)`, temporary directory) | 🟡 | no attributes, enumerators, symlinks, `replaceItem` |
| `Data(contentsOf:)`, `Data.write(to:)` | ✅ | |
| `FileHandle`, `InputStream` / `OutputStream` | 🟡 | files, memory and standard I/O; `readabilityHandler` on a thread; no sockets / bound stream pairs |
| App Group containers (`containerURL(forSecurityApplicationGroupIdentifier:)`) | ❌ | |
| iCloud Drive / ubiquity containers | ❌ | |
| `Bundle` (main, by path/id, resources, Info.plist, localizations) | ✅ | |
| `UserDefaults` (standard, suites, register defaults, argument domain) | ✅ | persisted as an XML plist in the container |
| `NSUbiquitousKeyValueStore` | ❌ | |

### Notifications, timers & threads

| API / feature | Status | Notes |
|---|---|---|
| `NotificationCenter` (selector, block, Combine publisher) | ✅ | |
| `NotificationQueue`, `DistributedNotificationCenter` | ❌ | |
| `Timer` (block / target-selector, repeating, `RunLoop.add`) | ✅ | the run loop keeps scheduled timers alive until invalidated |
| `RunLoop` | 🟡 | main run loop only; modes ignored |
| `Thread` (main checks, detach, sleep, name) | ✅ | |
| `OperationQueue` | 🟡 | block operations only; no `Operation` subclasses or dependencies |
| `NSLock`, `NSRecursiveLock`, `NSCondition` | ✅ | |
| `ProcessInfo` (environment, arguments, processor count, uptime) | ✅ | |
| `ProcessInfo.thermalState`, `isLowPowerModeEnabled`, `physicalMemory`, `operatingSystemVersion`, activities | ✅ | a simulated iPhone: always `.nominal`, never Low Power Mode, memory per device model |

### Networking

| API / feature | Status | Notes |
|---|---|---|
| `URL` (parsing, components, file URLs, path helpers, percent encoding) | ✅ | RFC 3986 relative resolution, IPv6 hosts, `appending(queryItems:)`, `init(string:encodingInvalidCharacters:)` |
| `URLComponents`, `URLQueryItem` | ✅ | parse/build, percent-encoded and decoded accessors, `queryItems` encoding like Apple's (`+` kept); tested |
| `URLRequest` (method, headers, body, timeout, cache policy, cookies flag) | ✅ | tested |
| `URLResponse`, `HTTPURLResponse` (status, `allHeaderFields`, `value(forHTTPHeaderField:)`, MIME type, length) | ✅ | tested |
| `URLError` (codes, `failingURL`, `catch URLError.code`, NSError bridging) | ✅ | host errors mapped (refused, DNS, timeout, TLS, offline, cancelled); tested |
| `URLSession` data/download/upload tasks (completion and async) | ✅ | Swift API; HTTP/HTTPS through the host's libcurl (dlopen'd, needed at run time); handlers on the session's background `delegateQueue`; cancellation; redirects; `ISIM_NETWORK=offline` simulates no network; tested (self-test + HelloNetwork) |
| `URLSession` delegates (data, download, redirect, completion) | ✅ | Swift protocols with default implementations (Apple's are `@objc` optional methods); tested; `didCreateTask`, `willCacheResponse` unverified |
| `bytes(from:)` / `bytes(for:)`, `AsyncBytes.lines` | ✅ | `lines` skips empty lines like Apple's; tested |
| `URLSessionConfiguration` (`.default`, `.ephemeral`, timeouts, extra headers, cache/cookie settings) | ✅ | `timeoutIntervalForRequest` is an idle timeout as on iOS; `waitsForConnectivity`, `allowsCellularAccess` and service types are stored only |
| `file:` and `data:` URLs in `URLSession` | ✅ | tested |
| `URLSessionWebSocketTask` | 🟡 | send/receive text and data, ping, close codes; needs a libcurl with WebSocket support (7.86+); the negotiated subprotocol is not reported; tested (text echo); ping and close handshake unverified |
| Authentication challenges (`didReceive challenge`, `URLCredential`, `URLProtectionSpace`), certificate pinning | ❌ | TLS uses the host's CA store |
| `URLSessionTaskMetrics`, task `progress`, resumable downloads (`resumeData`) | ❌ | |
| Background `URLSession` | 🧩 | `background(withIdentifier:)` sessions run like default sessions while the app runs |
| `HTTPCookie`, `HTTPCookieStorage` | ✅ | Set-Cookie parsing (domain, path, expiry, secure); `shared` persists in the app container; ephemeral sessions get a private jar; tested; accept policies unverified |
| `URLCache`, `CachedURLResponse` | 🟡 | in memory only (nothing written to disk); max-age/Expires/heuristic freshness, ETag/Last-Modified revalidation, request cache policies; tested |
| Objective-C `NSURLSession`, `NSURLRequest`, `NSURLComponents`, `NSHTTPCookie` | ❌ | the networking API is Swift-only |

---

## Swift runtime, stdlib & concurrency

| API / feature | Status | Notes |
|---|---|---|
| Swift 6.2 language and `libswiftCore` (stdlib + runtime, ObjC interop) | ✅ | built on Linux from swift-6.2.4 sources |
| Reflection (`Mirror`, type names), dynamic casts, existentials | ✅ | |
| Swift classes subclassing Objective-C classes, `@objc`, `#selector` | ✅ | |
| `SIMD` vector types | ✅ | |
| Unicode-correct `String` / `Character` | ✅ | stdlib |
| `async`/`await`, `Task`, cancellation | ✅ | tested |
| `actor`, `@MainActor`, `MainActor.run` | ✅ | tested |
| `withTaskGroup`, `withThrowingTaskGroup`, `async let` | ✅ | |
| `@TaskLocal` | ✅ | tested |
| Continuations (`withCheckedContinuation`) | ✅ | tested |
| `AsyncSequence`, `AsyncStream`, `AsyncThrowingStream` | ✅ | |
| `Clock`, `ContinuousClock`, `Duration`, `Task.sleep(for:)` | ✅ | tested |
| Swift 6 strict concurrency checking | ✅ | compile time |
| Observation (`@Observable`, `withObservationTracking`) | ✅ | libswiftObservation (upstream sources, isim pthread hooks) |
| `Regex`, regex literals, `RegexBuilder` (`_StringProcessing`) | ✅ | built from swift-experimental-string-processing (swift-6.2.4); bare `/.../` literals need `-enable-bare-slash-regex` or Swift 6 mode like Xcode |
| `Synchronization` (`Mutex`, `Atomic`) | ❌ | not built |
| Distributed actors | ❌ | |
| C++ interop | ❌ | |
| Swift macros from packages | 🟡 | `@Observable` works (toolchain plugin); `#Preview` and package macro targets unverified |

### Combine

| API / feature | Status | Notes |
|---|---|---|
| `Publisher`, `Subscriber`, `Subscription`, demand | ✅ | isim's own implementation |
| `PassthroughSubject`, `CurrentValueSubject` | ✅ | |
| `@Published`, `ObservableObject`, `objectWillChange` | ✅ | |
| `Just`, `Future`, `Deferred`, `Empty`, `Fail`, `Publishers.Sequence` | ✅ | |
| `sink`, `assign(to:on:)`, `assign(to:)`, `AnyCancellable`, `store(in:)` | ✅ | |
| `map`, `tryMap`, `compactMap`, `filter`, `flatMap`, `removeDuplicates`, `first`, `prefix`, `dropFirst` | ✅ | |
| `merge`, `combineLatest`, `debounce`, `receive(on:)`, `share`, `handleEvents`, `eraseToAnyPublisher`, `setFailureType` | ✅ | |
| `autoconnect`, `ConnectablePublisher` | ✅ | |
| `zip`, `scan`, `reduce`, `collect`, `delay`, `throttle`, `timeout`, `buffer` | ❌ | |
| `catch`, `retry`, `replaceError`, `mapError`, `switchToLatest`, `decode`/`encode` | ❌ | |
| `.values` (async bridge), `print`, `breakpoint` | ❌ | |
| Foundation publishers: `Timer.publish`, `NotificationCenter.publisher`; RunLoop/DispatchQueue schedulers | ✅ | |
| `URLSession.dataTaskPublisher` | ✅ | tested |
| KVO publisher (`publisher(for: \.keyPath)`) | ✅ | Foundation KVO; tested with `AVPlayer.timeControlStatus` (HelloVideo) |

### Dispatch

| API / feature | Status | Notes |
|---|---|---|
| Main, global and custom serial/concurrent queues, `async`/`sync`/`asyncAfter` | ✅ | |
| Barriers, `DispatchWorkItem`, `dispatchPrecondition`, queue-specific values | ✅ | |
| `DispatchGroup`, `DispatchSemaphore`, `concurrentPerform` / `dispatch_apply` | ✅ | |
| Timer sources (`DispatchSource.makeTimerSource`) | ✅ | |
| Read/write/signal/process sources, `DispatchIO`, `DispatchData` | ❌ | |

---

## Objective-C runtime & C library

| API / feature | Status | Notes |
|---|---|---|
| Message sending, classes, categories, protocols, `+load`/`+initialize` | ✅ | |
| ARC, weak references, autorelease pools, blocks | ✅ | |
| Associated objects, method swizzling (`method_exchangeImplementations`), introspection | ✅ | |
| `@synchronized`, properties, fast enumeration | ✅ | |
| Message forwarding (`forwardInvocation:`, `resolveInstanceMethod:`) | ❌ | unknown selectors abort |
| `@try`/`@catch`/`@throw`, C++ exceptions | ❌ | a throw aborts |
| libc / POSIX (stdio, malloc, string, pthreads, time, files) | ✅ | host glibc with Darwin layouts |
| `errno` from Swift | ✅ | provided by the Foundation overlay (no Swift Darwin overlay) |
| `dlopen` of app-bundled dylibs/frameworks | 🟡 | used for keyboard extensions; embedded frameworks unverified |
| Mach APIs (`mach_absolute_time` ✅; ports, tasks) | 🟡 | timing only |

---

## Core Graphics

| API / feature | Status | Notes |
|---|---|---|
| Geometry (`CGRect`/`CGPoint`/`CGSize` functions, Swift helpers) | ✅ | `CGFloat` is a typealias of `Double` |
| `CGAffineTransform` | ✅ | |
| `CGContext` paths: rects, ellipses, arcs, lines, curves; fill, EO fill, stroke | ✅ | via host cairo; even-odd fill tested (HelloDrawing) |
| Graphics state, CTM (translate/scale/rotate/concat), alpha, line width/cap/join/miter limit | ✅ | caps/joins/miter limit unverified |
| Clipping (`clip`, `clip(using: .evenOdd)`, `clip(to: rect)`) | ✅ | even-odd clip unverified |
| `CGPath` / `CGMutablePath` (build, bounding box, contains, apply) | ✅ | |
| `CGColor` (RGB, gray, copy with alpha) | ✅ | |
| `CGColorSpace`, Display P3, pattern colors | ❌ | P3 colors become sRGB |
| `CGImage` (from UIImage, crop, draw into context) | ✅ | decoded by the host |
| `CGImage` from raw bytes (`CGDataProvider`, `CGImageCreate`) | ❌ | |
| `CGBitmapContext` (offscreen drawing, pixel access) | ❌ | |
| `CGGradient`, `CGShading` | ❌ | |
| Line dashes (`setLineDash`) | ✅ | tested (HelloDrawing) |
| Shadows (`setShadow`), blend modes, transparency layers | ❌ | |
| Text drawing in CG | ❌ | |
| PDF documents/contexts | ❌ | |

## Core Text

| API / feature | Status | Notes |
|---|---|---|
| `CTFont` by name, size, names, metrics, character set | ✅ | unknown names fall back to the system font |
| `CTFontManagerRegisterFontsForURL` | ✅ | process scope |
| `CTFontDescriptor`, font features/traits | ❌ | |
| `CTLine`, `CTFramesetter`, `CTRun`, typesetting | ❌ | |

## QuartzCore / Core Animation

| API / feature | Status | Notes |
|---|---|---|
| `CALayer` basics (frame, bounds, corner radius/curve, border, background, opacity, `masksToBounds`, hidden) | 🟡 | minimal; lives in UIKit; a view's layer reports the view's frame/bounds |
| Layer shadows | 🟡 | approximated (see UIKit) |
| `magnificationFilter` / `minificationFilter` | ✅ | nearest affects image drawing |
| Sublayers (`addSublayer`), custom layer drawing (`draw(in:)`, `contents`) | 🟡 | sublayers (add/insert/remove/replace) draw above the view's content and below its subviews; `draw(in:)` overrides run every frame; no `contents`, transforms or z-ordering among subviews (AVPlayerLayer tested in HelloVideo) |
| `CAShapeLayer`, `CAGradientLayer`, `CATextLayer`, `CAReplicatorLayer`, `CAEmitterLayer` | ❌ | |
| `CABasicAnimation`, `CAKeyframeAnimation`, `CASpringAnimation`, `CAAnimationGroup` | ❌ | |
| `CATransaction`, `CAMediaTimingFunction` | ❌ | |
| `CADisplayLink` | ✅ | fires once per frame while added; keeps the run loop at 60 fps |
| `CATransform3D` | ❌ | |

## Core Image, ImageIO & Metal

| API / feature | Status | Notes |
|---|---|---|
| Core Image (`CIImage`, `CIFilter`, `CIContext`) | ❌ | |
| ImageIO (`CGImageSource`, metadata, GIF/HEIC decoding, `CGImageDestination`) | ❌ | UIKit decodes PNG/JPEG/SVG through the host |
| Metal, MetalKit (`MTLDevice`, `MTKView`) | ❌ | no GPU API |
| OpenGL ES / GLKit | ❌ | |

---

## SpriteKit

isim's SpriteKit is its own Swift implementation, drawn with cairo on the CPU (no Metal). Tested by `tests/ui/spritekit.sh` (HelloSpriteKit).

| API / feature | Status | Notes |
|---|---|---|
| `SKView`, `SKScene` (size, scale modes, anchor point, background, frame loop, delegate) | ✅ | 60 fps; per frame: `update`, actions, physics, constraints, particles, `didFinishUpdate` |
| `SKNode` tree (position, z-order, scale, rotation, alpha, hidden, name lookup, `enumerateChildNodes`) | ✅ | |
| `SKSpriteNode` (texture, color, color blend, anchor, size, blend modes) | ✅ | |
| `centerRect` (9-slice), `normalTexture`, lighting/shadow masks, `warpGeometry` | 🧩 | stored, not drawn |
| `SKShapeNode` (path, rect, rounded rect, circle, ellipse, points, spline, fill/stroke, line width, glow, blend mode, `lineLength`) | 🟡 | line cap/join/miter, fill/stroke textures and shaders ignored |
| `SKLabelNode` (font, size, color, alignment, multi-line, color blend, blend mode) | ✅ | |
| `SKLabelNode.attributedText` | ❌ | `NSAttributedString` exists now; SpriteKit does not draw it yet |
| `SKTexture` (`imageNamed:` incl. atlases, `init(rect:in:)`, `textureRect`, filtering, `preload`) | 🟡 | no noise/`data:` textures; `cgImage()` returns nil |
| `SKTextureAtlas` (`.atlas` folders, `textureNamed`, `textureNames`, `preload`, `init(dictionary:)`) | ✅ | picks the @2x/@3x file for the screen |
| `.spriteatlas` in asset catalogs | 🟡 | `isim build` lists them for `SKTextureAtlas(named:)`; unverified in an app |
| `SKAction` (move, rotate, scale, fade, colorize, resize, sequence, group, repeat, wait, run block, custom, follow path, speed, timing modes) | ✅ | |
| `SKAction.reversed()` | ❌ | returns the action unchanged |
| Physics, field and audio actions (`applyForce`/`applyImpulse`/`applyTorque`, `changeMass`/`changeCharge`, `strength`/`falloff`, `play`/`pause`/`stop`, `changeVolume`) | 🟡 | unverified; playback rate, panning, reverb, obstruction/occlusion and `reach` actions only wait |
| `SKAction.playSoundFileNamed` | ✅ | through isim's AVFoundation (PCM CAF/WAV; compressed formats via the host's ffmpeg/GStreamer); overlapping plays mix |
| `SKAudioNode` | 🟡 | looping playback and volume; not positional (`isPositional` ignored); `avAudioNode` not connected to an engine; unverified |
| Touch handling in scenes/nodes | ✅ | via SKView |
| `SKTransition` / `presentScene(_:transition:)` | ✅ | crossFade, fade (with color), push, moveIn, reveal, doorway, doors open/close, flips; pauses incoming/outgoing scenes. `SKTransition(ciFilter:)` ❌ |
| `SpriteView` (SwiftUI) | ✅ | scene, transition, paused, options, debug options |
| `SKCameraNode` (position/rotation/scale drive the view, children as HUD, `contains`, `containedNodeSet`) | 🟡 | `SKScene.camera` is typed `SKNode?` (iOS: `SKCameraNode?`) to keep isim's ABI |
| `SKPhysicsWorld` (gravity, speed, `contactDelegate`, joints, `body(at:)`, `body(in:)`, ray casts) | 🟡 | `contactDelegate` is typed `AnyObject?` (ABI); `sampleFields(at:)` ❌ |
| `SKPhysicsBody` shapes (circle, rectangle, polygon, edge, edge chain/loop, compound) | 🟡 | concave polygons use their convex hull; texture-based bodies use the bounding rectangle |
| `SKPhysicsBody` dynamics (mass/density/area, friction, restitution, damping, velocity, forces, impulses, torque, `allowsRotation`, `pinned`, `affectedByGravity`, `isResting`) | ✅ | 150 points per meter like SpriteKit; sequential impulses without warm starting (tall stacks settle less firmly than Box2D) |
| Category / collision / contact bit masks, `SKPhysicsContact`, `didBegin` / `didEnd` | ✅ | collision response is per body, as in SpriteKit; static bodies moved by actions push dynamic ones |
| `usesPreciseCollisionDetection` | 🟡 | more substeps instead of continuous collision detection |
| `SKPhysicsJoint` (pin, fixed, spring, limit, sliding) | 🟡 | pin, limit and spring tested; fixed and sliding unverified; `reactionForce`/`reactionTorque` approximate |
| `SKFieldNode` (linear/radial gravity, spring, drag, vortex, velocity, noise, turbulence, electric, magnetic, custom; `SKRegion`) | 🟡 | radial gravity tested; the others are unverified approximations; fields do not act on particles |
| `SKEmitterNode` (birth rate, lifetime, position range, speed, emission angle, acceleration, alpha/scale/rotation/color + ranges, speeds and keyframe sequences, blend modes, texture, `targetNode`, `advanceSimulationTime`, `resetSimulation`) | ✅ | simulated on the CPU; `particleAction`, `shader` and field interaction ignored |
| `SKKeyframeSequence` | ✅ | linear, spline (smoothstep), step; clamp/loop |
| `.sks` files (`SKNode(fileNamed:)`, `SKScene(fileNamed:)`, `SKEmitterNode(fileNamed:)`) | 🟡 | binary keyed archives read by isim's own decoder; SpriteKit's private archive keys are matched by property name, so only archives laid out like isim's test files are known to load (no Xcode-made .sks was available to verify); scenes: nodes, sprites, labels, simple shapes, emitters, camera, crop/effect nodes; no actions, physics bodies or tile maps from files |
| `SKCropNode` | ✅ | alpha mask from the mask node |
| `SKEffectNode` | 🟡 | children composited as a group (alpha, blend mode); Core Image filters ❌; `shouldRasterize` has no effect |
| `SKShader`, `SKUniform`, `SKAttribute` | 🧩 | stored, not run (no GPU) |
| `SKLightNode` | 🧩 | stored; nothing is lit or shadowed |
| `SKConstraint`, `SKRange` (position, distance, orientation, rotation, scale) | 🟡 | orientation tested; others unverified |
| `SKReachConstraints`, inverse kinematics | 🧩 | stored; reach actions only wait |
| `SKTileMapNode`, `SKTileSet`, `SKTileGroup`, `SKTileDefinition` | 🟡 | grid maps built in code (fill, set/get, tile indices and centers, animated definitions); unverified; no tile sets from files, no automapping; isometric/hex drawn as a grid |
| `SKReferenceNode` | 🟡 | loads an .sks file's children; unverified |
| `SKView` debug overlays (`showsFPS`, `showsNodeCount`, `showsDrawCount`, `showsPhysics`) | 🟡 | node count tested; `showsPhysics` outlines bodies (unverified); `showsFields` ignored |
| `SKView.texture(from:)` | 🧩 | returns nil |
| `SKVideoNode`, `SKTransformNode`, `SK3DNode`, `SKWarpGeometry`, `SKRenderer`, `SKMutableTexture` | ❌ | |

## GameKit (Game Center)

isim's Game Center is local: one player per device, no Apple servers. App Store Connect metadata (titles,
descriptions, points, recurrence, sets) comes from an isim-only `isim-GameCenter.json` next to the `.xcodeproj`
(see [GAMECENTER.md](GAMECENTER.md)); without it titles are derived from identifiers. Tested by `tests/ui/gamecenter.sh`.

| API / feature | Status | Notes |
|---|---|---|
| `GKLocalPlayer.local.authenticateHandler` | ✅ | signed-in state from Settings > Game Center; "Welcome back" banner |
| Player identity (`alias`, `displayName`, `gamePlayerID`, `teamPlayerID`) | ✅ | nickname from Settings |
| Player photos (`loadPhoto`) | ✅ | generated monogram (initials on a gray circle), like the default Game Center avatar |
| Leaderboards: `GKLeaderboard.submitScore`, `loadLeaderboards`, `loadEntries` | 🟡 | stored per app on the device; you are the only entry; titles and sort order (high/low) from the configuration |
| Recurring leaderboards (`type`, `startDate`, `nextStartDate`, `duration`, `loadPreviousOccurrence`) | ✅ | local occurrences from `start` + `duration` in the configuration (any ISO 8601 duration, e.g. PT6S for tests); dashboard shows "resets in" |
| Leaderboard sets (`GKLeaderboardSet`, `GKGameCenterViewController(leaderboardSetID:)`) | ✅ | from the configuration; shown in the dashboard |
| Leaderboard / set images (`loadImage`) | 🟡 | image file from the configuration, else a generated placeholder |
| Achievements: `GKAchievement.report`, `loadAchievements`, `resetAchievements`, completion banner | ✅ | local |
| `GKAchievementDescription` (titles, descriptions, points, hidden, images) | ✅ | from the configuration; images: configured file or generated medal; `rarityPercent` is nil |
| Dashboard UI (`GKGameCenterViewController`, leaderboards/achievements/sets states) | ✅ | iOS-style SwiftUI dashboard; achievement descriptions and points; not-started configured achievements listed, hidden ones hidden |
| `GKAccessPoint` | ✅ | floating monogram bubble at the configured corner while active and signed in; tapping opens the dashboard; hidden while Game Center UI is shown; `showHighlights` ignored |
| Friends (`loadFriends`, `loadFriendsAuthorizationStatus`, recent players) | 🧩 | always an empty list (no other players) |
| Friend requests (`GKFriendRequestComposeViewController`, `presentFriendRequestCreator`) | 🟡 | composer UI works; the request is never sent |
| Saved games (`saveGameData`, `fetchSavedGames`, `deleteSavedGames`, `resolveConflictingSavedGames`, `GKLocalPlayerListener`) | ✅ | stored in the device data (`Library/GameCenter/<bundle id>`), survives app deletion; conflicts come from `isim gamecenter <app> conflict` (no second device) |
| Real-time multiplayer (`GKMatchmaker`, `GKMatch`, `GKMatchmakerViewController`) | 🟡 | matchmaker UI shows and cancels; finding players always fails (no other players, no loopback match) |
| Turn-based multiplayer (`GKTurnBasedMatch`, `GKTurnBasedMatchmakerViewController`) | 🧩 | UI finds nobody; `loadMatches` is empty (unverified) |
| Challenges, invites | 🧩 | `GKChallenge.loadReceivedChallenges` is empty; invites never arrive (unverified) |
| Game activities (iOS 26 `GKGameActivity`) | ❌ | |

## GameController, GameplayKit, SceneKit, RealityKit & ARKit

| API / feature | Status | Notes |
|---|---|---|
| `GCController` (`controllers()`, `current`, connect / disconnect / current notifications, `playerIndex`) | ✅ | only isim's virtual controller connects |
| `GCExtendedGamepad`, `GCMicroGamepad` (buttons, d-pad, thumbsticks, triggers, value / pressed / touched handlers) | ✅ | tested with the virtual controller |
| Physical game controllers on the host | ❌ | host gamepads are not forwarded to apps |
| `GCKeyboard.coalesced`, `GCKeyboardInput` (`button(forKeyCode:)`, `keyChangedHandler`, `isAnyKeyPressed`), `GCKeyCode` | ✅ | the host keyboard; key presses and releases arrive as USB HID usages (scripts: `keydown`/`keyup`) |
| `GCVirtualController` (iOS 15) | 🟡 | thumbsticks, d-pad, A/B/X/Y, shoulders, triggers and menu drawn over the key window; element configurations only hide elements (custom paths ignored) |
| `GCMouse`, motion, haptics, light, battery | 🧩 | no mice; the others are nil |
| SceneKit (`SCNView`, `SCNScene`, `SceneView`) | ❌ | |
| RealityKit | ❌ | |
| ARKit | ❌ | no camera or sensors |
| `GKStateMachine`, `GKState` | ✅ | |
| `GKEntity`, `GKComponent`, `GKComponentSystem`, `GKSKNodeComponent`, `SKNode.entity` | ✅ | |
| `GKRandomSource`, `GKARC4RandomSource`, `GKMersenneTwisterRandomSource`, `GKLinearCongruentialRandomSource`, `arrayByShufflingObjects` | 🟡 | MT19937 matches the reference generator; ARC4 is RC4; LCG is the 64-bit MMIX generator; seeded sequences are not checked against iOS's |
| `GKRandomDistribution`, `GKGaussianDistribution`, `GKShuffledDistribution` | ✅ | |
| `GKGraph`, `GKGridGraph`, `GKGraphNode`, `GKGraphNode2D/3D`, `findPath` (A*) | ✅ | |
| `GKObstacleGraph`, `GKMeshGraph`, `GKPolygonObstacle` | ❌ | |
| `GKNoise`, `GKNoiseMap`, noise sources (Perlin, billow, ridged, Voronoi, constant, cylinders, spheres, checkerboard) | 🟡 | own algorithms (values differ from iOS); no `SKTexture(noiseMap:)`; unverified |
| `GKAgent2D`, `GKGoal`, `GKBehavior`, `GKPath` | 🟡 | simple steering (seek tested; flee, intercept, wander, target speed, avoid, separate/align/cohere, follow/stay on path unverified); `GKAgent3D` ❌ |
| `GKRuleSystem`, `GKRule` | 🟡 | block-based rules, facts with grades; `NSPredicate` rules ❌; unverified |
| `GKMinmaxStrategist`, `GKMonteCarloStrategist`, `GKDecisionTree`, `GKQuadtree`, `GKRTree` | ❌ | |

---

## AVFoundation & audio

Media decoding, speech and recording use host tools in child processes: **ffmpeg/ffprobe** (video, compressed audio,
thumbnails, AAC encoding; GStreamer's `gst-launch-1.0` also decodes audio files), **espeak-ng** or espeak (speech).
Headless test runs are silent (no audio device); timing, frames and callbacks still run.

| API / feature | Status | Notes |
|---|---|---|
| `AVAudioSession` (category, mode, `setActive`, record permission) | 🟡 | accepted; record permission always granted; no interruptions/route changes |
| `AVAudioPlayer` (play, pause, stop, seek, loops, volume, delegate) | 🟡 | `rate`/`pan`/metering not applied; reports 1 channel |
| `AVAudioEngine`, `AVAudioPlayerNode`, `AVAudioMixerNode` | 🟡 | buffer/file scheduling and mixing; connections build effect chains; offline manual rendering (`enableManualRenderingMode`, `renderOffline`) tested; no 3D audio |
| `AVAudioFile`, `AVAudioPCMBuffer`, `AVAudioFormat` | ✅ | reads PCM CAF/WAV itself and compressed formats via the host decoder; writes WAV/CAF, and m4a/AAC (and other extensions) via host ffmpeg (HelloAudio) |
| Compressed audio decoding (AAC/M4A, MP3, ALAC) | ✅ | decoded by the host's ffmpeg or gst-launch-1.0 (48 kHz stereo); needs one of them installed; mono sources come out ~3 dB quieter (ffmpeg upmix) |
| Effects (`AVAudioUnitReverb`, `AVAudioUnitEQ`, `AVAudioUnitTimePitch`, `AVAudioUnitVarispeed`, `AVAudioUnitDelay`, `AVAudioUnitDistortion`) | 🟡 | adapted: isim's own DSP (Freeverb-style reverb, RBJ biquads, overlap-add time stretch), applied when a buffer starts, so parameter changes affect the next buffer; tested offline (HelloAudio); varispeed unverified |
| Taps (`installTap`) | 🟡 | input node (real time) and main mixer during offline rendering; no taps on real-time output |
| Recording (`AVAudioRecorder`, `AVAudioEngine.inputNode`) | 🟡 | input is `ISIM_AUDIO_INPUT=<file>` (played into the mic in real time — tested) or `=mic` (host capture via ffmpeg-pulse/arecord, unverified); silence otherwise — the host microphone is never opened unless asked; metering is RMS/peak of recent input |
| `AVPlayer`, `AVPlayerItem` (status, duration, `currentTime`, `seek`, rate, `timeControlStatus`, volume/mute) | ✅ | host ffmpeg decodes frames (≤960 px) and streams the soundtrack to the mixer; local files tested; http(s) URLs go to ffmpeg too (unverified); only rate 1 plays sound, no reverse playback |
| Time observers (`addPeriodicTimeObserver`, `addBoundaryTimeObserver`), `AVPlayerItemDidPlayToEndTime`, `actionAtItemEnd` | ✅ | evaluated once per display frame |
| `AVQueuePlayer`, `AVPlayerLooper` | ✅ | |
| `AVPlayerLayer` (`player`, `videoGravity`, `isReadyForDisplay`, `videoRect`) | ✅ | a CALayer drawn by UIKit's renderer: as a sublayer or a view's `layerClass` |
| `AVAsset`/`AVURLAsset` (duration, tracks, `naturalSize`, `nominalFrameRate`, `load(_:)`, `loadTracks`) | ✅ | probed with ffprobe; no metadata, no preferred transform |
| `AVAssetImageGenerator` (thumbnails) | ✅ | one frame via host ffmpeg; tolerances ignored |
| `CMTime`, `CMTimeRange` (CoreMedia) | ✅ | arithmetic, comparison, conversion, `NSValue(time:)`; no sample buffers or clocks |
| AVKit `AVPlayerViewController` | 🟡 | iOS 17-style controls (play/pause, ±10 s, scrubber, elapsed/remaining, mute, close when presented, auto-hide); no picture in picture, AirPlay, speed menu UI or info panels |
| SwiftUI `VideoPlayer` (with `videoOverlay`) | ✅ | the overlay does not take touches |
| Picture in picture (`AVPictureInPictureController`), `AVRoutePickerView` | 🧩 | PiP reports unsupported; route picker is an empty view |
| Capture (`AVCaptureSession`, camera, QR scanning) | ❌ | |
| `AVSpeechSynthesizer`, `AVSpeechUtterance`, `AVSpeechSynthesisVoice` | 🟡 | adapted: host espeak-ng voices (rate/pitch/volume/voice mapped); delegate start/finish/pause/continue/cancel; `willSpeakRangeOfSpeechString` approximated by word length; `write(_:toBufferCallback:)` renders PCM; without a TTS engine utterances run silently with a logged message |
| Composition and export (`AVMutableComposition`, `AVAssetExportSession`, `AVAssetReader`/`Writer`) | ❌ | |
| AudioToolbox System Sound Services (`AudioServicesCreateSystemSoundID`, `PlaySystemSound`, completions) | 🟡 | sounds from files play; built-in IDs (e.g. 1104) play a synthesized click/chime instead of Apple's recordings |
| `kSystemSoundID_Vibrate`, `AudioServicesPlayAlertSound` vibration | 🧩 | logged only (no haptics on the host) |
| Audio Queues, Audio Units, Audio File/Converter services | ❌ | |
| MediaPlayer `MPNowPlayingInfoCenter` | 🟡 | stored and logged; no lock screen/Control Center to show it |
| MediaPlayer `MPRemoteCommandCenter` | 🟡 | handlers and selector targets; commands come from the `remote NAME [ARG]` script/control command (tested: play, skip, seek, disabled command) |
| `MPVolumeView` | 🧩 | a slider that does not change the host volume |
| Music library (`MPMediaLibrary`, `MPMediaQuery`, `MPMusicPlayerController`), MusicKit | ❌ | |

## Photos, Vision, Core ML & camera

| API / feature | Status | Notes |
|---|---|---|
| PhotosUI `PhotosPicker` / `PHPickerViewController` | ❌ | |
| Photos (`PHPhotoLibrary`, `PHAsset`, saving images) | ❌ | |
| `UIImageWriteToSavedPhotosAlbum` | ❌ | |
| Vision (text recognition, barcode, face detection) | ❌ | |
| Core ML (`MLModel`, compiled models) | ❌ | |
| Natural Language, Speech | ❌ | |
| VisionKit (document camera, Live Text, `DataScannerViewController`) | ❌ | |

---

## StoreKit

Local StoreKit testing, like Xcode's: products come from the project's `.storekit` configuration; nothing is
charged, nothing reaches Apple, transactions are `.verified` and JWS/receipts are local and **unsigned**.
The ledger lives in the app container (`Library/isim/StoreKit/ledger.json`); `isim storekit <app> ...` is the
Transaction Manager. Tested by `tests/ui/store.sh` (HelloStore sample).

| API / feature | Status | Notes |
|---|---|---|
| StoreKit configuration files (`.storekit` selected by the scheme) | ✅ | copied into the bundle by `isim build`; products, subscription groups, offers, `_timeRate`, `_storefront` |
| `Product.products(for:)` (id, type, display name, description, price, display price) | ✅ | prices shown in USD |
| `Product.purchase()` with confirmation sheet | ✅ | always succeeds when confirmed; `.pending` (Ask to Buy) never happens; owned non-consumables / current plan show the iOS notice |
| Purchase options (`appAccountToken`, `quantity`) | ✅ | stored on the transaction |
| `Transaction.currentEntitlements`, `all`, `latest(for:)`, `currentEntitlement(for:)`, `unfinished` | ✅ | `all` leaves out finished consumables (unless `SKIncludeConsumableInAppPurchaseHistory`) |
| `Transaction.updates` | ✅ | unfinished transactions at launch, renewals, refunds, offer-code redemptions, Transaction Manager changes |
| `Transaction.finish()` | ✅ | unfinished transactions are delivered again at the next launch |
| `VerificationResult` | ✅ | always `.verified`; `jwsRepresentation` is an unsigned local token (`alg: none`) |
| `AppStore.sync()` (restore) | 🟡 | re-reads the local ledger (no account to sync) |
| `AppStore.canMakePayments` | ✅ | |
| Consumables / non-consumables | ✅ | |
| Auto-renewable subscriptions: `Product.SubscriptionInfo` (group, period, level, group name) | ✅ | |
| Subscription status (`status`, `Status.updates`, `RenewalInfo`, `RenewalState`) | ✅ | subscribed / expired / revoked / billing retry; one status per group (no Family Sharing) |
| Renewals on an accelerated clock | ✅ | Xcode time rate from `.storekit` `_timeRate` (SKTestSession.TimeRate order; mapping unverified against Xcode) or `ISIM_STOREKIT_TIME_RATE` (`month=4`, `renewal=10`, names); renews while the app runs and catches up at launch |
| Expiration, cancel (auto-renew off), billing issues | 🟡 | expiry and cancel tested; billing retry via `isim storekit billing-issue` unverified; no grace period |
| Upgrade / downgrade / crossgrade within a group | ✅ | upgrades (and same-period crossgrades) immediate, `isUpgraded` set; downgrades at the next renewal |
| Introductory offers (free trial, pay as you go, pay up front), `isEligibleForIntroOffer` | ✅ | eligible until the first subscription in the group |
| Promotional offers (`.promotionalOffer(...)`) | 🟡 | from `.storekit` `adHocOffers`; the signature is not verified locally |
| Win-back offers (`.winBackOffer`) | 🟡 | from `winbackOffers`; eligible only after a lapsed subscription; no automatic win-back sheet |
| Offer codes (`presentOfferCodeRedeemSheet`, `offerCodeRedemption`) | 🟡 | redeem sheet; codes are the `.storekit` `codeOffers` reference names / IDs; subscriptions only |
| Refunds (`beginRefundRequest`, `refundRequestSheet`), `revocationDate` / `revocationReason` | ✅ | refund sheet; local requests are approved at once; revoked transactions arrive in `Transaction.updates` |
| `showManageSubscriptions`, `manageSubscriptionsSheet` | ✅ | iOS-style sheet: status, change plan, cancel |
| StoreKit views (`StoreView`, `ProductView`, `SubscriptionStoreView`) | 🟡 | iOS-like look; styles compact/regular/large; `storeButton`, `onInAppPurchaseCompletion/Start`, `subscriptionStatusTask`, `currentEntitlementTask`; custom control styles, policies and promotional icons ignored |
| `AppTransaction` | 🟡 | local: original app version = CFBundleVersion at first launch on this device; environment `.xcode`; unsigned |
| `SKStoreReviewController.requestReview`, `@Environment(\.requestReview)` | ✅ | development-style rating card, at most 3 times per 365 days; nothing sent |
| StoreKit 1 (`SKProductsRequest`, `SKProduct`/`SKProductDiscount`, `SKPaymentQueue`, observers, `finishTransaction`, restore) | ✅ | shares the StoreKit 2 ledger; renewals reach the observer |
| App receipt (`Bundle.main.appStoreReceiptURL`, `SKReceiptRefreshRequest`) | 🟡 | a local, unsigned JSON summary — not PKCS #7; receipt validation rejects it |
| `SKOverlay`, `SKStoreProductViewController` | 🟡 | placeholder overlay card / product page (the App Store isn't available) |
| Transaction Manager (refund, expire, cancel, clear) | ✅ | `isim storekit <app> list\|refund\|expire\|cancel\|resume\|billing-issue\|delete\|clear`; the running app picks changes up within 0.5 s |

## Ads & privacy (AppTrackingTransparency, Google Mobile Ads, UMP)

| API / feature | Status | Notes |
|---|---|---|
| `ATTrackingManager.requestTrackingAuthorization`, `trackingAuthorizationStatus` | ✅ | iOS-style prompt; choice persists per app; missing usage string is logged |
| `ASIdentifierManager` (IDFA) | ❌ | |
| Google Mobile Ads stand-in (`MobileAds.start`, `BannerView`, `InterstitialAd`, `RewardedAd`, `AppOpenAd`) | 🧩 | builds and runs; every ad load fails with "unavailable on isim" |
| Google UMP stand-in (`ConsentInformation`, `ConsentForm`) | 🧩 | succeeds without a form; `canRequestAds` is false |
| Privacy manifests (`PrivacyInfo.xcprivacy`) | 🧩 | copied into the bundle; not checked |
| Other ad/analytics SDKs (Firebase, AppLovin, Meta, …) | ❌ | binary SDKs are not run; no stand-ins |

---

## Data & persistence

| API / feature | Status | Notes |
|---|---|---|
| Core Data (`NSPersistentContainer`, `NSManagedObjectContext`, fetch requests, `@FetchRequest`) | ❌ | |
| SwiftData (`@Model`, `ModelContainer`, `@Query`) | ❌ | needs macros + Observation |
| CloudKit (`CKContainer`, records, subscriptions, `NSPersistentCloudKitContainer`) | ❌ | |
| SQLite (`sqlite3` C API, `import SQLite3`) | ✅ | `/usr/lib/libsqlite3.dylib` forwards to the host's `libsqlite3.so.0` (loaded on first use; a function the host's SQLite lacks stops the app with a message). Tested: SecurityTest, HelloSecurity |
| Keychain passwords (`SecItemAdd/CopyMatching/Update/Delete`, generic + internet passwords) | ✅ | Swift (isim's Security module; Objective-C callers not yet). iOS attribute keys, duplicate detection, return data/attributes/persistent refs, match limits, access groups (default: bundle id). Stored per access group in `$ISIM_DATA/Library/Keychains` (0600 JSON, not encrypted; survives app deletion, erased by `isim reset`). `SecAccessControl` flags stored, not enforced |
| Keychain keys, certificates, identities (`SecKey`, `SecCertificate`, `SecIdentity`) | ❌ | `SecItemAdd` returns `errSecUnimplemented` for these classes |

## Identity & security

| API / feature | Status | Notes |
|---|---|---|
| Sign in with Apple (`ASAuthorizationAppleIDProvider`, `SignInWithAppleButton`) | ❌ | |
| `ASWebAuthenticationSession` (OAuth) | ❌ | |
| Passkeys, password AutoFill (`ASAuthorizationController`) | ❌ | |
| LocalAuthentication (Face ID / Touch ID, `LAContext`) | ✅ | `canEvaluatePolicy`/`evaluatePolicy` (+ async), `LAError`, `biometryType` from the device (Face ID; Touch ID on iPhone SE and non-Pro iPads). Face ID permission alert (`NSFaceIDUsageDescription`, remembered), simulated scan alert (Matching / Non-matching / Cancel), passcode fallback; `ISIM_BIOMETRY=match\|nomatch\|cancel`, `ISIM_BIOMETRY_ENROLLED=0`. Reply on a background queue like iOS |
| CryptoKit (SHA-2, HMAC, AES-GCM, ChaChaPoly, P256, Curve25519) | ✅ | also P384/P521, `Insecure.MD5/SHA1`, HKDF, `SharedSecret` HKDF/X9.63 KDFs, ECDSA DER, public keys raw/X9.63/compressed/DER/PEM. AES/ChaCha/EC on the host's OpenSSL `libcrypto.so.3`. Byte inputs are `ContiguousBytes` (isim's Foundation has no `DataProtocol`). Known-answer tests from the RFCs/NIST |
| CryptoKit: Secure Enclave, HPKE, `AES.KeyWrap`, compact keys, private-key PEM/DER | ❌ | |
| CommonCrypto (`CC_SHA*`, `CC_MD5`, `CCHmac`, `CCCrypt`/`CCCryptor`, `CCKeyDerivationPBKDF`, `CCRandomGenerateBytes`) | ✅ | in libSystem like iOS; contexts copyable; AES (ECB/CBC/CTR/CFB/OFB) and 3DES via the host's OpenSSL, other ciphers `kCCUnimplemented`. Known-answer tests |
| Security: `SecRandomCopyBytes`, `SecCopyErrorMessageString` | ✅ | |
| Security: certificates and trust (`SecCertificate`, `SecTrust`, `SecPolicy`) | ❌ | |
| DeviceCheck / App Attest | 🧩 | `isSupported` is false and calls fail with `DCError.featureUnsupported`, like the Simulator |

## Notifications & background work

| API / feature | Status | Notes |
|---|---|---|
| UserNotifications: authorization request | ✅ | the iOS permission alert, answer remembered per app; provisional authorization; `notificationSettings()`; `ISIM_NOTIFICATION_PERMISSION=allow\|deny`. No per-app page in isim Settings |
| Local notifications (`UNNotificationRequest`, time/calendar triggers) | 🟡 | time-interval and calendar (`DateComponents`) triggers, repeating, pending/delivered lists, persisted across launches; fire while the app runs (foreground, or background under `isim boot`). Not delivered while the app is not running (no system scheduler) |
| Notification presentation (banners, Notification Center, actions, foreground delegate) | 🟡 | `willPresent`/`didReceive` (+ async); iOS-style banner in the app or, for a backgrounded app, drawn by the shell over the home screen; tap opens the app with the default action. No Notification Center list, action buttons, sounds or attachments |
| Push notifications (APNs registration, remote payloads) | 🧩 | registration fails with NSCocoaErrorDomain 3010 |
| Notification Service/Content extensions | ❌ | |
| BackgroundTasks (`BGAppRefreshTask`, `BGProcessingTask`) | ❌ | |
| Background audio, location, VoIP modes | ❌ | |

## App extensions & system integration

| API / feature | Status | Notes |
|---|---|---|
| Custom keyboard extensions | ✅ | built, embedded and hosted in-process |
| WidgetKit (home/lock screen widgets, timelines) | ❌ | |
| ActivityKit (Live Activities, Dynamic Island) | ❌ | |
| App Intents (Shortcuts, Siri, Spotlight, interactive widgets, `AppShortcutsProvider`) | ❌ | |
| SiriKit (Intents) | ❌ | |
| Share / Action extensions | ❌ | "extension point not supported" is logged |
| Spotlight (`CSSearchableItem`), `NSUserActivity` indexing | ❌ | |
| App Clips | ❌ | |
| Focus filters, Control Center controls | ❌ | |

## Location & maps

| API / feature | Status | Notes |
|---|---|---|
| CoreLocation (`CLLocationManager`, authorization, updates, geocoding) | ❌ | |
| Region monitoring, beacons, visits | ❌ | |
| MapKit (`MKMapView`, SwiftUI `Map`, annotations, overlays, directions, search) | ❌ | |

## Personal data & device sensors

| API / feature | Status | Notes |
|---|---|---|
| Contacts / ContactsUI | ❌ | |
| EventKit / EventKitUI (calendars, reminders) | ❌ | |
| HealthKit | ❌ | |
| Core Motion (accelerometer, gyroscope, pedometer) | ❌ | |
| Core Bluetooth | ❌ | |
| Core NFC | ❌ | |

## Web & communication

| API / feature | Status | Notes |
|---|---|---|
| WebKit (`WKWebView`, navigation delegate, JavaScript bridge) | ❌ | |
| SafariServices (`SFSafariViewController`) | ❌ | |
| MessageUI (`MFMailComposeViewController`, `MFMessageComposeViewController`) | ❌ | |
| Network framework `NWPathMonitor` (`pathUpdateHandler`, `currentPath`, `for await`) | ✅ | mirrors the host's connectivity (Wi-Fi/Ethernet), polled every 2 s; tested |
| Network framework `NWConnection`, `NWListener`, `NWBrowser`, `NWEndpoint` | ❌ | |
| BSD sockets (`socket`, `bind`/`listen`/`accept`, `connect`, `send`/`recv`, `getaddrinfo`, `inet_pton`, `poll`/`select`, `getifaddrs`) | ✅ | Darwin structs, constants and errno translated to the host's; tested (TCP server + client, socketpair, poll, select, getifaddrs, `SO_RCVTIMEO`); `read`/`write` errno translated too; UDP unverified |
| `fcntl`, `ioctl` (e.g. non-blocking sockets) | 🟡 | C/Objective-C only: Swift cannot call these variadic functions without a Swift Darwin overlay |
| MultipeerConnectivity | ❌ | |
| Universal Links / Associated Domains | ❌ | |

## Logging & diagnostics

| API / feature | Status | Notes |
|---|---|---|
| `print`, `NSLog`, `debugPrint` | ✅ | to the terminal running isim |
| `os.Logger`, `os_log`, `OSLog` (Swift) | ✅ | levels, `OSLogMessage` interpolation with privacy (strings/objects `<private>` unless `.public`; `.private(mask: .hash)`), number/bool formatting, printf-style `os_log` with `%{public}`; stderr in `log stream` compact style. `ISIM_LOG_PRIVATE=1` shows private values, `ISIM_LOG_LEVEL` filters |
| `os_log` C macros (Objective-C), `os_log_create` | ✅ | clang's `__builtin_os_log_format` buffers decoded by isim's libSystem; same output and privacy rules as Swift |
| Signposts (`OSSignposter`, `os_signpost`) | 🧩 | accepted, not recorded |
| `OSLogStore` (reading logs back) | 🧩 | throws |
| `os_unfair_lock`, `OSAllocatedUnfairLock` | ✅ | futex-backed, with owner checks |
| MetricKit, crash reporting | ❌ | |
| `assert`, `precondition`, `fatalError` messages | ✅ | |

---

## Platform & tooling

| API / feature | Status | Notes |
|---|---|---|
| Compile ObjC/C for iOS on Linux (`isim cc`) | ✅ | clang/lld; simulator x86_64 and device arm64 Mach-O |
| Compile Swift (`isim swiftc`) | ✅ | Docker `swift:6.2` image |
| `isim build` for Xcode projects (`.xcodeproj`, targets, schemes, configurations, build settings) | ✅ | |
| App extensions in projects (`.appex`, embedded in `PlugIns/`) | ✅ | keyboards run; other extension types are built but not hosted |
| Static libraries / framework targets in projects | ❌ | "product type not supported yet" |
| Local Swift packages | ✅ | targets built as modules |
| Remote Swift packages (GitHub dependencies) | 🟡 | not fetched; build only if isim ships a stand-in (Google Mobile Ads today) |
| Package-to-package dependencies | ❌ | "dependencies on other packages are not supported yet" |
| CocoaPods / Carthage / binary `.xcframework`s | ❌ | |
| Asset catalogs (images, colors, app icon) | ✅ | compiled to isim's own format (not `Assets.car`) |
| Info.plist (`$(VARS)`, `INFOPLIST_KEY_*`) | ✅ | never claims Xcode/SDK identity |
| Entitlements | 🧩 | not enforced or signed |
| App icons on the home screen | ✅ | from the asset catalog |
| Launch screen (`UILaunchScreen` dictionary, LaunchScreen storyboard) | ❌ | |
| Storyboards / XIBs (`UIMainStoryboardFile`, `UISceneStoryboardFile`, nibs) | ❌ | needs an ibtool replacement; logged and ignored |
| Localization (`.xcstrings`, `.lproj/.strings`, app language from Settings) | 🟡 | plurals limited (see Foundation) |
| Unit tests (XCTest, Swift Testing), UI tests (XCUITest) | ❌ | test bundles are skipped by `isim build`; isim's own script driver exists |
| Scripted automation (`--script`/`--control`: tap, type, screenshot, dump) | ✅ | |
| Device presets: iPhone SE, 13 mini, 14, 15, 15 Plus, 15 Pro Max, 16 Pro, 16 Pro Max, 17, Air, 17 Pro, 17 Pro Max | ✅ | safe areas, Dynamic Island, rounded corners |
| iPad presets: mini, Air 11", Pro 11", Pro 13" | 🟡 | run iPhone-style; no multitasking or pointer |
| Rotation / landscape | ❌ | |
| Multiple iOS versions (`--os`: reported version and look) | 🟡 | `ISIM_OS_VERSION` changes the reported version; look is always iOS 17/18 |
| Home screen: launch, background/resume, home gesture (swipe up / Ctrl+Shift+H), delete apps | ✅ | apps run as separate processes |
| Home screen: folders, App Library, widgets, rearranging icons, Spotlight | ❌ | |
| App switcher / multitasking | ❌ | |
| Lock screen, Notification Center, Control Center | ❌ | |
| Settings app: General (About, Date & Time, Keyboard, Language & Region), Display & Brightness, Game Center, per-app pages | 🟡 | only the settings isim implements |
| Settings bundles (`Settings.bundle` for app pages) | ❌ | |
| System keyboard + keyboard extensions | ✅ | English (US) only |
| Light/dark mode, screenshots (F12), zoom | ✅ | |
| Audio output | ✅ | SDL3 mixer |
| Device build (arm64 executables) | 🟡 | executables link; `.app` bundle not finished |
| Code signing, `.ipa` packaging | ❌ | candidates: rcodesign, zsign |
| Upload to App Store Connect / TestFlight | ❌ | blocked: requires builds from current Xcode/SDK |
| Linux release tarballs (GitHub Releases) | ✅ | self-contained, glibc 2.35+ |
| Xcode-like project view / IDE | ❌ | planned; the CLI covers it today |
