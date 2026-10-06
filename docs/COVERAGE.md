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
| **UIKit** | 79 | 32 | 10 | 76 | 197 | 48% |
| &nbsp;&nbsp;↳ Application & scenes | 6 | 4 | 5 | 8 | 23 | 35% |
| &nbsp;&nbsp;↳ View controllers & presentation | 11 | 2 | 0 | 16 | 29 | 41% |
| &nbsp;&nbsp;↳ Views & controls | 23 | 14 | 1 | 13 | 51 | 59% |
| &nbsp;&nbsp;↳ Layout | 12 | 1 | 1 | 5 | 19 | 66% |
| &nbsp;&nbsp;↳ Animation | 5 | 2 | 0 | 5 | 12 | 50% |
| &nbsp;&nbsp;↳ Gestures & touches | 4 | 1 | 0 | 8 | 13 | 35% |
| &nbsp;&nbsp;↳ Text input & keyboard | 6 | 2 | 1 | 5 | 14 | 50% |
| &nbsp;&nbsp;↳ Drawing, images & symbols | 8 | 3 | 0 | 7 | 18 | 53% |
| &nbsp;&nbsp;↳ Haptics & feedback | 0 | 0 | 1 | 2 | 3 | 0% |
| &nbsp;&nbsp;↳ Accessibility | 1 | 1 | 1 | 4 | 7 | 21% |
| &nbsp;&nbsp;↳ Drag & drop | 0 | 0 | 0 | 3 | 3 | 0% |
| &nbsp;&nbsp;↳ Appearance & dark mode | 3 | 2 | 0 | 0 | 5 | 80% |
| **SwiftUI** | 108 | 42 | 13 | 31 | 194 | 66% |
| &nbsp;&nbsp;↳ App & scenes | 4 | 1 | 0 | 6 | 11 | 41% |
| &nbsp;&nbsp;↳ State & data flow | 12 | 3 | 0 | 2 | 17 | 79% |
| &nbsp;&nbsp;↳ Views & controls | 26 | 10 | 1 | 1 | 38 | 82% |
| &nbsp;&nbsp;↳ Containers & layout | 18 | 8 | 1 | 0 | 27 | 81% |
| &nbsp;&nbsp;↳ Navigation & presentation | 13 | 8 | 1 | 1 | 23 | 74% |
| &nbsp;&nbsp;↳ Modifiers & visual effects | 12 | 3 | 7 | 2 | 24 | 56% |
| &nbsp;&nbsp;↳ Shapes, paths, gradients & materials | 3 | 1 | 0 | 5 | 9 | 39% |
| &nbsp;&nbsp;↳ Animation | 2 | 3 | 1 | 6 | 12 | 29% |
| &nbsp;&nbsp;↳ Gestures | 3 | 1 | 0 | 3 | 7 | 50% |
| &nbsp;&nbsp;↳ Lifecycle, async & events | 5 | 1 | 0 | 1 | 7 | 79% |
| &nbsp;&nbsp;↳ Focus & keyboard | 2 | 0 | 1 | 1 | 4 | 50% |
| &nbsp;&nbsp;↳ Environment values | 3 | 3 | 0 | 1 | 7 | 64% |
| &nbsp;&nbsp;↳ Accessibility | 2 | 0 | 1 | 1 | 4 | 50% |
| &nbsp;&nbsp;↳ UIKit interop | 3 | 0 | 0 | 1 | 4 | 75% |
| Swift Charts | 0 | 0 | 0 | 3 | 3 | 0% |
| **Foundation** | 36 | 11 | 2 | 27 | 76 | 55% |
| &nbsp;&nbsp;↳ Strings & text | 5 | 2 | 0 | 5 | 12 | 50% |
| &nbsp;&nbsp;↳ Collections & values | 5 | 1 | 0 | 5 | 11 | 50% |
| &nbsp;&nbsp;↳ Encoding & serialization | 3 | 0 | 1 | 3 | 7 | 43% |
| &nbsp;&nbsp;↳ Dates, calendars & formatters | 3 | 3 | 0 | 5 | 11 | 41% |
| &nbsp;&nbsp;↳ Files, bundles & preferences | 4 | 1 | 0 | 4 | 9 | 50% |
| &nbsp;&nbsp;↳ Notifications, timers & threads | 5 | 2 | 0 | 2 | 9 | 67% |
| &nbsp;&nbsp;↳ Networking | 11 | 2 | 1 | 3 | 17 | 71% |
| **Swift runtime, stdlib & concurrency** | 28 | 1 | 0 | 9 | 38 | 75% |
| &nbsp;&nbsp;↳ Combine | 10 | 0 | 0 | 4 | 14 | 71% |
| &nbsp;&nbsp;↳ Dispatch | 4 | 0 | 0 | 1 | 5 | 80% |
| Objective-C runtime & C library | 6 | 2 | 0 | 2 | 10 | 70% |
| Core Graphics | 8 | 0 | 0 | 8 | 16 | 50% |
| Core Text | 2 | 0 | 0 | 2 | 4 | 50% |
| QuartzCore / Core Animation | 2 | 2 | 0 | 5 | 9 | 33% |
| Core Image, ImageIO & Metal | 0 | 0 | 0 | 4 | 4 | 0% |
| SpriteKit | 15 | 17 | 5 | 3 | 40 | 59% |
| GameKit (Game Center) | 4 | 1 | 3 | 6 | 14 | 32% |
| GameController, GameplayKit, SceneKit, RealityKit & ARKit | 7 | 5 | 1 | 6 | 19 | 50% |
| AVFoundation & audio | 1 | 4 | 0 | 9 | 14 | 21% |
| Photos, Vision, Core ML & camera | 0 | 0 | 0 | 7 | 7 | 0% |
| StoreKit | 8 | 2 | 3 | 8 | 21 | 43% |
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
| **All areas** | **335** | **128** | **45** | **258** | **766** | **52%** |

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
| Device orientation, rotation, `supportedInterfaceOrientations` | ❌ | always portrait |
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
| `UIPasteboard` | ❌ | |

### View controllers & presentation

| API / feature | Status | Notes |
|---|---|---|
| `UIViewController` lifecycle (`loadView`, `viewDidLoad`, appear/disappear, layout callbacks) | ✅ | |
| Child view-controller containment | ✅ | |
| `init(nibName:bundle:)` / storyboard-instantiated controllers | ❌ | nib name is logged and ignored |
| Full-screen modal (`.fullScreen`, `.overFullScreen`) | ✅ | slides up from the bottom |
| Page / form sheet (`.automatic`, `.pageSheet`, `.formSheet`) | 🟡 | iOS 15+ card look, presenter shrinks behind it, swipe-down dismiss, iPad centered card; no detents, no grabber |
| `isModalInPresentation` | ✅ | rubber-bands instead of dismissing |
| `UISheetPresentationController` (detents, grabber, largest undimmed detent) | ❌ | |
| Popover presentation (`UIPopoverPresentationController`) | ❌ | |
| `modalTransitionStyle` (cross dissolve, flip, partial curl) | ❌ | |
| Custom transitions (`UIViewControllerTransitioningDelegate`, interactive) | ❌ | |
| `UINavigationController` (push/pop, back swipe) | ✅ | push/pop/popTo, parallax animation, back button, left-edge back swipe, delegate; tested (HelloNavigation) |
| `UINavigationItem` (title, bar button items, search controller, large titles) | ✅ | title, titleView, left/right bar button items, back title, large title display mode |
| `UITabBarController` | ✅ | tab bar, selection, delegate, badges, hidesBottomBarWhenPushed, tap-again pops to root; tested |
| `UISplitViewController` | ❌ | |
| `UIPageViewController` | ❌ | |
| `UIAlertController` `.alert` | ✅ | iOS 17/18 metrics, preferred action |
| `UIAlertController` `.actionSheet` | 🟡 | drawn as a bottom sheet; iPad popover anchoring unverified |
| `UIAlertController.addTextField` | ❌ | header says "no text fields yet" |
| `UIActivityViewController` (share sheet) | ❌ | |
| `UISearchController` | ❌ | |
| `UIImagePickerController` (camera/library) | ❌ | |
| `UIDocumentPickerViewController` / `UIDocumentBrowserViewController` | ❌ | |
| `UIColorPickerViewController`, `UIFontPickerViewController` | ❌ | |
| `UIReferenceLibraryViewController`, `QLPreviewController` | ❌ | |
| `UIInputViewController` (custom keyboard extension) | ✅ | loaded in-process; no Full Access |
| `overrideUserInterfaceStyle` | ✅ | |
| `setEditing(_:animated:)`, `editButtonItem` | ✅ | Edit/Done item; `UITableViewController` forwards to its table; tested (HelloTable) |
| `preferredContentSize` | ❌ | |
| `UIContentUnavailableConfiguration` | ❌ | |

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
| `UILabel.attributedText` | ❌ | no `NSAttributedString` |
| `UIButton` system/custom, title/color/image per state | ✅ | `imageView` returns nil |
| `UIButton.Configuration` (plain/tinted/gray/filled/bordered*, subtitle, image padding, corner style, size) | 🟡 | no `configurationUpdateHandler`, attributed titles or activity indicator |
| Button menus (`menu`, `showsMenuAsPrimaryAction`), pop-up buttons | ✅ | UIButton.menu + showsMenuAsPrimaryAction, UIBarButtonItem menus; tested |
| `UIControl` target-action, `UIAction`, control events/states | ✅ | |
| `UIImageView` | ✅ | PNG/JPEG/… via gdk-pixbuf, SVG via librsvg |
| Animated images (`animationImages`, `UIImage.animatedImage`) | ❌ | |
| `UITextField` | 🟡 | caret always at the end: no selection, cursor movement, copy/paste |
| `UITextView` | ❌ | |
| `UISwitch` | ✅ | |
| `UISlider` | ✅ | thumb drag, continuous/non-continuous, track tints; tested (HelloControls) |
| `UIStepper` | ✅ | min/max/step/wraps; tested |
| `UISegmentedControl` | ✅ | titles/images, sliding selection, momentary, per-segment enable; tested |
| `UIPickerView` | ❌ | |
| `UIDatePicker` | ❌ | |
| `UIProgressView` | ✅ | default and bar styles |
| `UIActivityIndicatorView` | ✅ | medium/large, spins (CADisplayLink) |
| `UIPageControl` | ✅ | tap to page; tested |
| `UIColorWell` | ❌ | |
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
| `UINavigationBar` (standalone, appearance) | 🟡 | large titles collapsing on scroll, scroll-edge transparency, appearances (basic); no UIAppearance proxies |
| `UITabBar` | ✅ | items, badges, selected/unselected tints; no "More" tab beyond 5 items |
| `UISearchBar` | ❌ | |
| `UIRefreshControl` | ❌ | |
| `UIEditMenuInteraction` (copy/paste menu) | ❌ | |
| `UIAppearance` proxies (`UINavigationBar.appearance()`) | ❌ | |
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
| Rotation layout (`viewWillTransition(to:with:)`) | ❌ | |

### Animation

| API / feature | Status | Notes |
|---|---|---|
| `UIView.animate(withDuration:…)` | ✅ | frame/center/bounds, alpha, transform, backgroundColor interpolate |
| Timing curves (ease in/out, linear) | ✅ | |
| Spring animations (damping/velocity; iOS 17 `springDuration`/`bounce`) | ✅ | |
| Delay, repeat, autoreverse, begin-from-current-state | ✅ | retargets from the current value |
| `performWithoutAnimation`, `areAnimationsEnabled` | ✅ | |
| Constraint animations (`layoutIfNeeded` in an animation block) | 🟡 | frames set inside the block animate; unverified end to end |
| `UIView.transition(with:)` | 🟡 | cross dissolve only (fade-in); flips/curls apply without the effect |
| `transition(from:to:)` | ❌ | |
| `animateKeyframes` / `addKeyframe` | ❌ | |
| `UIViewPropertyAnimator` (interruptible, scrubbable) | ❌ | |
| Layer property animations (cornerRadius, shadow, …) | ❌ | only the view properties above animate |
| UIKit Dynamics (`UIDynamicAnimator`, behaviors) | ❌ | |

### Gestures & touches

| API / feature | Status | Notes |
|---|---|---|
| `touchesBegan/Moved/Ended/Cancelled`, responder chain | ✅ | |
| Multi-touch | ❌ | the mouse is a single finger |
| `UITapGestureRecognizer` | ✅ | |
| `UIPanGestureRecognizer` (translation, velocity) | ✅ | |
| `UILongPressGestureRecognizer` | ✅ | |
| `UISwipeGestureRecognizer` | ❌ | |
| `UIPinchGestureRecognizer`, `UIRotationGestureRecognizer` | ❌ | need multi-touch |
| `UIScreenEdgePanGestureRecognizer` | ❌ | |
| `UIHoverGestureRecognizer` | ❌ | |
| `UIGestureRecognizerDelegate` (simultaneous recognition, `require(toFail:)`) | 🟡 | `gestureRecognizerShouldBegin`, `shouldReceive(_ touch:)`, `shouldRecognizeSimultaneouslyWith` (with exclusive recognizers), `UIView.gestureRecognizerShouldBegin`; no `require(toFail:)`; unverified apart from table swipes |
| Custom `UIGestureRecognizer` subclasses | ❌ | touch hooks are isim-private |
| Shake / motion events | ❌ | |
| Hardware keys (`UIKeyCommand`, `pressesBegan`) | ❌ | host typing goes to text fields only |

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
| `UIGraphicsImageRenderer` / `UIGraphicsBeginImageContext` (offscreen drawing) | ❌ | |
| `UIGraphicsPDFRenderer`, printing | ❌ | |
| `UIImage(named:)` (bundle + asset catalog, 1x/2x/3x, dark variants) | ✅ | |
| `UIImage(contentsOfFile:)`, `UIImage(cgImage:)` | ✅ | |
| `UIImage(data:)` | ❌ | not in the header |
| `pngData()` / `jpegData()` | ❌ | |
| `resizableImage(withCapInsets:)`, `withHorizontallyFlippedOrientation` | ❌ | |
| `withTintColor`, rendering modes (template/original) | ✅ | |
| SF Symbols (`UIImage(systemName:)`) | 🟡 | substitutes (procedural shapes / Adwaita symbolic icons), not Apple's glyphs |
| `UIImage.SymbolConfiguration` (point size, weight, scale, text style) | ✅ | |
| Symbol rendering modes (hierarchical, palette, multicolor), symbol effects | ❌ | |
| `UIColor` (RGB/HSB/white, system & semantic colors, dynamic provider) | ✅ | Apple HIG light/dark values |
| Named asset-catalog colors (light/dark) | ✅ | |
| `UIFont` (system weights, italic, monospaced, monospaced digits, metrics) | 🟡 | Adwaita Sans substitutes SF Pro; `fontDescriptor` missing |
| Custom fonts (`UIAppFonts`) | ✅ | registered at launch |
| `NSString.draw(in:withAttributes:)`, `boundingRect(with:)` | ❌ | |

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
| `Text(date, style:)`, `Text(_:format:)`, `Text(timerInterval:)` | 🟡 | `.time/.date/.relative/.offset/.timer` styles (relative ones re-render every second), date ranges, `\(date, style:)` interpolation and `Text(_:formatter:)` tested (HelloText); `Text(_:format:)` is compiled only once isim Foundation has `FormatStyle` (unverified) |
| Markdown in `Text`, `AttributedString` | 🟡 | string literals parse `**bold**`, `*italic*`, `***both***`, `` `code` ``, `~~strike~~`, `[links](url)` (tap opens through `openURL`); tested. Italic is a sheared glyph run (isim fonts have no italic faces). `Text(AttributedString)` and the SwiftUI attribute scope compile only once isim Foundation has `AttributedString` (unverified) |
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
| `toggleStyle` (`.button`, `.checkbox`, custom) | 🧩 | accepted, ignored |
| `Slider` | ✅ | UISlider; step, value labels, onEditingChanged; tested |
| `Stepper` | ✅ | value/bounds/step and onIncrement/onDecrement; tested |
| `Picker` (menu, segmented, wheel, inline, navigationLink styles) | ✅ | all five styles; `.wheel` is a snapping scroll-wheel drawn by isim (no UIPickerView); tested (HelloForms, HelloPickers) |
| `DatePicker`, `MultiDatePicker` | 🟡 | `DatePicker`: compact (date/time pills open a calendar or time wheel in a sheet — iOS uses a popover), graphical (month grid, month paging, time row), wheel; `.date` / `.hourAndMinute`; ranges; `labelsHidden`; tested (HelloPickers). `MultiDatePicker` missing |
| `ColorPicker` | 🟡 | colour well opening a sheet with iOS's colour grid and an opacity slider (no spectrum/sliders pages, no eyedropper); `Color` and `CGColor` bindings; tested (HelloPickers) |
| `TextField` (String binding, placeholder, `axis: .vertical` multi-line) | ✅ | `prompt` ignored |
| `TextField(value:format:)`, `TextField(value:formatter:)` | 🟡 | `formatter:` (NumberFormatter / DateFormatter) parses on Return or end of editing, reverting unparseable text; tested (HelloPickers). `format:` compiles only once isim Foundation has `ParseableFormatStyle` (unverified) |
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
| `cornerRadius`, `clipShape` (rect, rounded rect, circle, capsule) | ✅ | |
| `clipped()` | 🧩 | returns the view unchanged |
| `mask` | 🟡 | clips to the mask's shape only (no alpha masks) |
| `shadow` | 🟡 | layer-shadow approximation |
| `rotationEffect`, `scaleEffect`, `offset` | ✅ | |
| `rotation3DEffect`, `projectionEffect`, `transformEffect` | ❌ | |
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
| `textFieldStyle`, `labelStyle` | 🧩 | ignored |
| `pickerStyle`, `datePickerStyle`, `progressViewStyle`, `gaugeStyle` | ✅ | see the controls above; tested (HelloForms, HelloPickers) |
| `ViewModifier`, `.modifier` | ✅ | |
| `redacted`, `privacySensitive` | ❌ | |
| `badge`, `help`, `contextMenu` | 🟡 | `badge` on tabs and list rows, `contextMenu` (long press -> pop-up menu) tested (HelloLists); preview ignored; `help` missing |

### Shapes, paths, gradients & materials

| API / feature | Status | Notes |
|---|---|---|
| `Rectangle`, `RoundedRectangle`, `Circle`, `Capsule` | ✅ | |
| `fill`, `stroke`, `strokeBorder`, `trim` | 🟡 | `strokeBorder` is drawn as `stroke`; `StrokeStyle` dashes/caps ignored |
| `Ellipse`, `UnevenRoundedRectangle`, `ContainerRelativeShape` | ❌ | |
| Custom `Shape` (`path(in:)`), `Path` | ❌ | `Shape` has no `path(in:)` requirement |
| `InsettableShape`, `AnyShape`, shape `.offset`/`.rotation`/`.scale` | ❌ | |
| `LinearGradient`, `RadialGradient`, `AngularGradient`, `EllipticalGradient`, `.gradient` | ❌ | |
| `Material` (`.ultraThinMaterial` … `.bar`) | ✅ | real backdrop blur (UIVisualEffectView) |
| `Color` (system colors, RGB/HSB/white, `Color(uiColor:)`, asset colors) | ✅ | |
| `ImagePaint`, shaders (`ShaderLibrary`, `.colorEffect`) | ❌ | |

### Animation

Landed 2026-10-05 (commit d0dcb9b, `swift/overlays/SwiftUI/Animation.swift`): an animated update runs the view updates
inside UIKit's animation engine, so frames, opacity, transforms and colors interpolate. No UI test covers it yet.

| API / feature | Status | Notes |
|---|---|---|
| `withAnimation` (incl. `completion:`) | ✅ | animates the next render (frames, opacity, transforms, colors) |
| `.animation(_:value:)` | ✅ | animates its subtree when the value changes |
| Curves & springs (`.easeInOut`, `.spring`, `.bouncy`, `.snappy`, `.smooth`, `timingCurve`, `interpolatingSpring`), repeat/delay/speed | 🟡 | mapped onto UIKit curves/springs; custom timing curves approximated (unverified) |
| Transitions (`.opacity`, `.scale`, `.slide`, `.move`, `.offset`, `.push`, `asymmetric`, `combined`) | 🟡 | insertion and removal play; each kind unverified |
| `matchedGeometryEffect` | 🟡 | an inserted view moves from the matched view's old frame; no simultaneous source/target |
| `contentTransition` (`.numericText`, `.interpolate`) | 🧩 | text content is not animated |
| Animating shape `trim`, paths, gradients | ❌ | |
| `Animatable` / `animatableData`, `AnimatableModifier` | ❌ | |
| `phaseAnimator` | ❌ | |
| `keyframeAnimator` | ❌ | |
| `TimelineView` | ❌ | |
| `Canvas` | ❌ | |

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
| `Chart` view | ❌ | module not provided |
| Marks (`BarMark`, `LineMark`, `PointMark`, `AreaMark`, `RuleMark`, `RectangleMark`, `SectorMark`) | ❌ | |
| Axes, scales, legends, annotations, selection | ❌ | |

---

## Foundation

isim's Foundation is self-authored: an Objective-C framework plus a Swift overlay (value types such as `Data`,
`Date`, `URL`, `Calendar` are pure Swift).

### Strings & text

| API / feature | Status | Notes |
|---|---|---|
| `String` ⇄ `NSString` bridging | ✅ | copies instead of lazy bridging |
| `NSString` / `NSMutableString` API (search, replace, case, trimming, components, paths) | 🟡 | common subset; comparisons are code-point ordered, not locale-aware |
| `String(format:)`, `NSLog` | ✅ | |
| String encodings (`data(using:)`, `String(data:encoding:)`, `String(contentsOf:)`) | ✅ | |
| `CharacterSet` | ✅ | BMP only |
| `NSAttributedString`, `AttributedString` | ❌ | |
| `NSRegularExpression`, `NSDataDetector` | ❌ | |
| `Scanner` | ❌ | |
| `String(localized:)`, `NSLocalizedString`, `Bundle.localizedString` | ✅ | |
| `LocalizedStringResource` | ❌ | |
| String Catalogs (`.xcstrings`) | 🟡 | compiled to `.strings`; plural variants use "other" only; device/width variants dropped |
| `.stringsdict` plural rules | ❌ | |

### Collections & values

| API / feature | Status | Notes |
|---|---|---|
| `NSArray`, `NSDictionary`, `NSSet` (+ mutable), literals, fast enumeration, sorting | ✅ | |
| `NSOrderedSet`, `NSCountedSet`, `NSIndexSet`, `NSCache`, `NSHashTable`, `NSMapTable` | ❌ | |
| `IndexPath` / `NSIndexPath` (+ UIKit `row`/`section`/`item`) | ✅ | value type bridged to NSIndexPath; tested (HelloTable) |
| `NSNumber`, `NSValue` (CG geometry), `NSNull` | ✅ | |
| `UUID` | ✅ | |
| `Decimal` | 🟡 | Int64 mantissa + exponent; less precision than Apple's 38 digits |
| `NSError`, `LocalizedError`, `CustomNSError` | ✅ | |
| `NSPredicate`, `NSExpression`, `NSSortDescriptor`, `SortDescriptor` | ❌ | |
| Key-value coding (`value(forKey:)`) and observing (KVO, `observe(\.x)`) | ❌ | |
| `UndoManager` | ❌ | |
| `Progress` | ❌ | |

### Encoding & serialization

| API / feature | Status | Notes |
|---|---|---|
| `JSONEncoder` / `JSONDecoder` (key/date/data/float strategies, output formatting) | ✅ | |
| `JSONSerialization` | ✅ | NSNumber/NSNull like Apple |
| `PropertyListEncoder` / `PropertyListDecoder` | ❌ | |
| `PropertyListSerialization` | ❌ | |
| Reading XML plists (`NSDictionary(contentsOfFile:)`, Info.plist) | ✅ | |
| Binary plists | ❌ | logged and rejected |
| `NSKeyedArchiver` / `NSKeyedUnarchiver`, `NSCoding` | 🧩 | `NSCoder` exists so `init(coder:)` compiles; archiving not implemented |

### Dates, calendars & formatters

| API / feature | Status | Notes |
|---|---|---|
| `Date`, `TimeInterval`, `Date.now` | ✅ | |
| `Calendar`, `DateComponents`, `DateInterval` | 🟡 | Gregorian + ISO 8601; other calendars compute as Gregorian |
| `TimeZone` (named zones, DST) | ✅ | Settings > Date & Time or the host's zone; changes apply live (`NSSystemTimeZoneDidChange`, `resetSystemTimeZone`) |
| `Locale` (identifiers, language/region, separators, currency, `Locale.Language`) | ✅ | |
| `DateFormatter` (styles, `dateFormat`, templates) | 🟡 | common patterns; full CLDR data unverified |
| `NumberFormatter` (decimal, currency, percent, digits, grouping) | 🟡 | common styles |
| `ISO8601DateFormatter` | ❌ | |
| `RelativeDateTimeFormatter`, `DateComponentsFormatter`, `DateIntervalFormatter` | ❌ | |
| `.formatted()` / `FormatStyle` (dates, numbers, currency, lists) | ❌ | |
| `Measurement`, `Unit*`, `MeasurementFormatter` | ❌ | |
| `ByteCountFormatter`, `PersonNameComponentsFormatter`, `ListFormatter` | ❌ | |

### Files, bundles & preferences

| API / feature | Status | Notes |
|---|---|---|
| App sandbox container (Documents, Library, Caches, tmp) | ✅ | per app, under `ISIM_DATA` |
| `FileManager` (exists, create, remove, copy, move, list, `urls(for:in:)`, temporary directory) | 🟡 | no attributes, enumerators, symlinks, `replaceItem` |
| `Data(contentsOf:)`, `Data.write(to:)` | ✅ | |
| `FileHandle`, `InputStream` / `OutputStream` | ❌ | |
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
| `ProcessInfo.thermalState`, `isLowPowerModeEnabled` | ❌ | |

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
| `Regex`, regex literals, `RegexBuilder` (`_StringProcessing`) | ❌ | not built yet |
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
| KVO publisher (`publisher(for: \.keyPath)`) | ❌ | |

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
| `CGContext` paths: rects, ellipses, arcs, lines, curves; fill, EO fill, stroke | ✅ | via host cairo |
| Graphics state, CTM (translate/scale/rotate/concat), alpha, line width/cap/join | ✅ | |
| Clipping (`clip`, `clip(to: rect)`) | ✅ | |
| `CGPath` / `CGMutablePath` (build, bounding box, contains, apply) | ✅ | |
| `CGColor` (RGB, gray, copy with alpha) | ✅ | |
| `CGColorSpace`, Display P3, pattern colors | ❌ | P3 colors become sRGB |
| `CGImage` (from UIImage, crop, draw into context) | ✅ | decoded by the host |
| `CGImage` from raw bytes (`CGDataProvider`, `CGImageCreate`) | ❌ | |
| `CGBitmapContext` (offscreen drawing, pixel access) | ❌ | |
| `CGGradient`, `CGShading` | ❌ | |
| Line dashes (`setLineDash`) | ❌ | |
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
| `CALayer` basics (frame, bounds, corner radius/curve, border, background, opacity, `masksToBounds`, hidden) | 🟡 | minimal; lives in UIKit; no sublayer API |
| Layer shadows | 🟡 | approximated (see UIKit) |
| `magnificationFilter` / `minificationFilter` | ✅ | nearest affects image drawing |
| Sublayers (`addSublayer`), custom layer drawing (`draw(in:)`, `contents`) | ❌ | |
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
| `SKLabelNode.attributedText` | ❌ | isim Foundation has no `NSAttributedString` yet |
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

isim's Game Center is local: one player per device, no Apple servers.

| API / feature | Status | Notes |
|---|---|---|
| `GKLocalPlayer.local.authenticateHandler` | ✅ | signed-in state from Settings > Game Center; "Welcome back" banner |
| Player identity (`alias`, `displayName`, `gamePlayerID`, `teamPlayerID`) | ✅ | nickname from Settings |
| Player photos (`loadPhoto`) | 🧩 | returns "not supported" |
| Leaderboards: `GKLeaderboard.submitScore`, `loadLeaderboards`, `loadEntries` | 🟡 | stored per app on the device; you are the only entry; titles derived from IDs |
| Leaderboard sets, recurring leaderboards, leaderboard images | ❌ | |
| Achievements: `GKAchievement.report`, `loadAchievements`, `resetAchievements`, completion banner | ✅ | local |
| `GKAchievementDescription` (titles, images, points) | ❌ | no App Store Connect metadata locally |
| Dashboard UI (`GKGameCenterViewController`, leaderboards/achievements states) | ✅ | iOS-style SwiftUI dashboard |
| `GKAccessPoint` | 🧩 | `isVisible` is always false; `trigger` just runs the handler |
| Friends (`loadFriends`, friend requests) | 🧩 | returns an empty list |
| Real-time multiplayer (`GKMatchmaker`, `GKMatch`, `GKMatchmakerViewController`) | ❌ | |
| Turn-based multiplayer (`GKTurnBasedMatch`) | ❌ | |
| Challenges, invites, activities | ❌ | |
| Saved games (`GKSavedGame`) | ❌ | |

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

| API / feature | Status | Notes |
|---|---|---|
| `AVAudioSession` (category, mode, `setActive`) | 🟡 | accepted; no interruptions/route changes |
| `AVAudioPlayer` (play, pause, stop, seek, loops, volume, delegate) | 🟡 | `rate`/`pan`/metering not applied; reports 1 channel |
| `AVAudioEngine`, `AVAudioPlayerNode`, `AVAudioMixerNode` | 🟡 | buffer/file scheduling and mixing; no effects, taps or 3D audio |
| `AVAudioFile`, `AVAudioPCMBuffer`, `AVAudioFormat` | 🟡 | reads linear-PCM CAF and WAV only |
| Compressed audio decoding (AAC/M4A, MP3, ALAC) | ✅ | decoded by the host's ffmpeg or gst-launch-1.0 (48 kHz stereo); needs one of them installed |
| Effects (`AVAudioUnitReverb`, EQ, time pitch) | ❌ | |
| Recording (`AVAudioRecorder`, input node) | ❌ | |
| `AVPlayer`, `AVPlayerItem`, `AVQueuePlayer`, `AVPlayerLayer` (video/streaming) | ❌ | |
| AVKit (`AVPlayerViewController`, `VideoPlayer`) | ❌ | |
| Capture (`AVCaptureSession`, camera, QR scanning) | ❌ | |
| `AVSpeechSynthesizer` | ❌ | |
| `AVAsset`, export, composition | ❌ | |
| AudioToolbox (`AudioServicesPlaySystemSound`, Audio Queues, Audio Units) | ❌ | |
| MediaPlayer (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`, music library) | ❌ | |

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

Local StoreKit testing, like Xcode's: products come from the project's `.storekit` configuration; nothing is charged.

| API / feature | Status | Notes |
|---|---|---|
| StoreKit configuration files (`.storekit` selected by the scheme) | ✅ | copied into the bundle by `isim build` |
| `Product.products(for:)` (id, type, display name, description, price, display price) | ✅ | |
| `Product.purchase()` with confirmation sheet | ✅ | always succeeds when confirmed; `.pending` never happens |
| Purchase options (`appAccountToken`, `quantity`) | 🧩 | accepted, ignored |
| `Transaction.currentEntitlements`, `all`, `latest(for:)`, `currentEntitlement(for:)` | ✅ | persisted in the app container |
| `Transaction.updates` | 🧩 | always empty (no outside purchases) |
| `Transaction.finish()` | 🧩 | no-op |
| `VerificationResult` | ✅ | always `.verified`, as in local testing |
| `AppStore.sync()` (restore) | 🟡 | no-op; local ledger is already on the device |
| `AppStore.canMakePayments` | ✅ | |
| Consumables / non-consumables | ✅ | |
| Auto-renewable subscriptions (`Product.SubscriptionInfo`, status, renewal, groups, expiration) | ❌ | product type exists; no subscription info or expiry |
| Introductory / promotional / win-back offers, offer codes | ❌ | |
| Refunds (`beginRefundRequest`), `revocationDate` | 🟡 | `revocationDate` is always nil; refund UI missing |
| `showManageSubscriptions`, `AppStore.showManageSubscriptions` | ❌ | |
| StoreKit views (`StoreView`, `ProductView`, `SubscriptionStoreView`) | ❌ | |
| `AppTransaction` | ❌ | |
| `SKStoreReviewController.requestReview`, `@Environment(\.requestReview)` | ✅ | development-style rating card; nothing sent |
| StoreKit 1 (`SKProductsRequest`, `SKPaymentQueue`, `SKPaymentTransactionObserver`) | ❌ | |
| `SKOverlay`, `SKStoreProductViewController` | ❌ | |
| Transaction Manager UI (Xcode's debug tools: refund, expire, clear) | ❌ | |

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
