# isim API coverage

This tracks how much of the iOS 17/18 SDK isim covers, so you can follow progress as features land.
It lists what an app developer reaches for, including everything isim does **not** have yet. Statuses come from
reading isim's headers (`isim/sdk-src`), implementations (`isim/frameworks`, `isim/swift/overlays`) and their comments, not from guesses.

Last updated: 2026-10-05

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
| **UIKit** | 70 | 25 | 10 | 91 | 196 | 42% |
| &nbsp;&nbsp;↳ Application & scenes | 6 | 4 | 4 | 9 | 23 | 35% |
| &nbsp;&nbsp;↳ View controllers & presentation | 7 | 2 | 1 | 19 | 29 | 28% |
| &nbsp;&nbsp;↳ Views & controls | 19 | 8 | 1 | 23 | 51 | 45% |
| &nbsp;&nbsp;↳ Layout | 11 | 1 | 1 | 5 | 18 | 64% |
| &nbsp;&nbsp;↳ Animation | 5 | 2 | 0 | 5 | 12 | 50% |
| &nbsp;&nbsp;↳ Gestures & touches | 4 | 0 | 0 | 9 | 13 | 31% |
| &nbsp;&nbsp;↳ Text input & keyboard | 6 | 2 | 1 | 5 | 14 | 50% |
| &nbsp;&nbsp;↳ Drawing, images & symbols | 8 | 3 | 0 | 7 | 18 | 53% |
| &nbsp;&nbsp;↳ Haptics & feedback | 0 | 0 | 1 | 2 | 3 | 0% |
| &nbsp;&nbsp;↳ Accessibility | 1 | 1 | 1 | 4 | 7 | 21% |
| &nbsp;&nbsp;↳ Drag & drop | 0 | 0 | 0 | 3 | 3 | 0% |
| &nbsp;&nbsp;↳ Appearance & dark mode | 3 | 2 | 0 | 0 | 5 | 80% |
| **SwiftUI** | 88 | 22 | 14 | 70 | 194 | 51% |
| &nbsp;&nbsp;↳ App & scenes | 4 | 1 | 0 | 6 | 11 | 41% |
| &nbsp;&nbsp;↳ State & data flow | 11 | 2 | 0 | 4 | 17 | 71% |
| &nbsp;&nbsp;↳ Views & controls | 17 | 2 | 1 | 18 | 38 | 47% |
| &nbsp;&nbsp;↳ Containers & layout | 12 | 4 | 2 | 9 | 27 | 52% |
| &nbsp;&nbsp;↳ Navigation & presentation | 10 | 5 | 1 | 7 | 23 | 54% |
| &nbsp;&nbsp;↳ Modifiers & visual effects | 11 | 2 | 7 | 4 | 24 | 50% |
| &nbsp;&nbsp;↳ Shapes, paths, gradients & materials | 3 | 1 | 0 | 5 | 9 | 39% |
| &nbsp;&nbsp;↳ Animation | 2 | 3 | 1 | 6 | 12 | 29% |
| &nbsp;&nbsp;↳ Gestures | 3 | 1 | 0 | 3 | 7 | 50% |
| &nbsp;&nbsp;↳ Lifecycle, async & events | 5 | 0 | 0 | 2 | 7 | 71% |
| &nbsp;&nbsp;↳ Focus & keyboard | 2 | 0 | 1 | 1 | 4 | 50% |
| &nbsp;&nbsp;↳ Environment values | 3 | 1 | 0 | 3 | 7 | 50% |
| &nbsp;&nbsp;↳ Accessibility | 2 | 0 | 1 | 1 | 4 | 50% |
| &nbsp;&nbsp;↳ UIKit interop | 3 | 0 | 0 | 1 | 4 | 75% |
| Swift Charts | 0 | 0 | 0 | 3 | 3 | 0% |
| **Foundation** | 25 | 9 | 1 | 30 | 65 | 45% |
| &nbsp;&nbsp;↳ Strings & text | 5 | 2 | 0 | 5 | 12 | 50% |
| &nbsp;&nbsp;↳ Collections & values | 4 | 1 | 0 | 5 | 10 | 45% |
| &nbsp;&nbsp;↳ Encoding & serialization | 3 | 0 | 1 | 3 | 7 | 43% |
| &nbsp;&nbsp;↳ Dates, calendars & formatters | 3 | 3 | 0 | 5 | 11 | 41% |
| &nbsp;&nbsp;↳ Files, bundles & preferences | 4 | 1 | 0 | 4 | 9 | 50% |
| &nbsp;&nbsp;↳ Notifications, timers & threads | 5 | 2 | 0 | 2 | 9 | 67% |
| &nbsp;&nbsp;↳ Networking | 1 | 0 | 0 | 6 | 7 | 14% |
| **Swift runtime, stdlib & concurrency** | 27 | 1 | 0 | 9 | 37 | 74% |
| &nbsp;&nbsp;↳ Combine | 9 | 0 | 0 | 4 | 13 | 69% |
| &nbsp;&nbsp;↳ Dispatch | 4 | 0 | 0 | 1 | 5 | 80% |
| Objective-C runtime & C library | 5 | 2 | 0 | 2 | 9 | 67% |
| Core Graphics | 8 | 0 | 0 | 8 | 16 | 50% |
| Core Text | 2 | 0 | 0 | 2 | 4 | 50% |
| QuartzCore / Core Animation | 2 | 2 | 0 | 5 | 9 | 33% |
| Core Image, ImageIO & Metal | 0 | 0 | 0 | 4 | 4 | 0% |
| SpriteKit | 9 | 1 | 3 | 5 | 18 | 53% |
| GameKit (Game Center) | 4 | 1 | 3 | 6 | 14 | 32% |
| GameController, SceneKit, RealityKit & ARKit | 0 | 0 | 0 | 5 | 5 | 0% |
| AVFoundation & audio | 1 | 4 | 0 | 9 | 14 | 21% |
| Photos, Vision, Core ML & camera | 0 | 0 | 0 | 7 | 7 | 0% |
| StoreKit | 8 | 2 | 3 | 8 | 21 | 43% |
| Ads & privacy (AppTrackingTransparency, Google Mobile Ads, UMP) | 1 | 0 | 3 | 2 | 6 | 17% |
| Data & persistence | 0 | 0 | 0 | 5 | 5 | 0% |
| Identity & security | 0 | 0 | 0 | 7 | 7 | 0% |
| Notifications & background work | 0 | 0 | 0 | 7 | 7 | 0% |
| App extensions & system integration | 1 | 0 | 0 | 8 | 9 | 11% |
| Location & maps | 0 | 0 | 0 | 3 | 3 | 0% |
| Personal data & device sensors | 0 | 0 | 0 | 6 | 6 | 0% |
| Web & communication | 0 | 0 | 0 | 7 | 7 | 0% |
| Logging & diagnostics | 2 | 0 | 0 | 2 | 4 | 50% |
| Platform & tooling | 15 | 6 | 1 | 14 | 36 | 50% |
| **All areas** | **268** | **75** | **38** | **325** | **706** | **43%** |

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
| Remote notification registration | ❌ | see UserNotifications |
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
| `UINavigationController` (push/pop, back swipe) | ❌ | SwiftUI `NavigationStack` has its own bar |
| `UINavigationItem` (title, bar button items, search controller, large titles) | 🧩 | `title` stored; nothing displays it |
| `UITabBarController` | ❌ | |
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
| `setEditing(_:animated:)`, `editButtonItem` | ❌ | |
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
| Button menus (`menu`, `showsMenuAsPrimaryAction`), pop-up buttons | ❌ | |
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
| `UIScrollView` | 🟡 | one-finger pan, rubber-banding, deceleration, insets, delegate; no zooming, no paging animation |
| `UITableView` (cells, sections, editing, swipe actions) | ❌ | biggest UIKit gap for list apps |
| `UITableViewDiffableDataSource` | ❌ | |
| `UICollectionView` + `UICollectionViewFlowLayout` | ❌ | |
| `UICollectionViewCompositionalLayout` | ❌ | |
| `UICollectionViewDiffableDataSource`, `NSDiffableDataSourceSnapshot` | ❌ | |
| List cells (`UICollectionLayoutListConfiguration`, `UIListContentConfiguration`, cell accessories) | ❌ | |
| `UIStackView` (axis, spacing, custom spacing, alignment, distribution) | ✅ | arranged as Auto Layout constraints |
| `UIVisualEffectView` + `UIBlurEffect` (system materials) | ✅ | real backdrop blur + light/dark tint; no saturation boost |
| `UIVibrancyEffect` | 🧩 | content drawn normally |
| `UIMenu`, `UIContextMenuInteraction` (context menus, previews) | 🟡 | UIMenu pop-ups for UIButton.menu (sections, checkmarks, destructive, submenus); no context-menu previews |
| `UIToolbar`, `UIBarButtonItem` | ❌ | |
| `UINavigationBar` (standalone, appearance) | ❌ | |
| `UITabBar` | ❌ | |
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
| `UIGestureRecognizerDelegate` (simultaneous recognition, `require(toFail:)`) | ❌ | not in the header |
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
| `@ScaledMetric` | ❌ | |
| `@FocusedValue`, `@FocusedBinding` | ❌ | |
| `PreferenceKey`, `.preference`, `.onPreferenceChange`, anchor preferences | ❌ | |
| `Transaction`, `withTransaction` | 🟡 | carries the animation / `disablesAnimations`; custom transaction keys missing |

### Views & controls

| API / feature | Status | Notes |
|---|---|---|
| `Text` (verbatim, `LocalizedStringKey` with interpolation, font/weight/italic/color) | ✅ | |
| `Text + Text` concatenation | ❌ | |
| `Text(date, style:)`, `Text(_:format:)`, `Text(timerInterval:)` | ❌ | |
| Markdown in `Text`, `AttributedString` | ❌ | |
| `strikethrough`, `underline`, `kerning`, `tracking`, `textCase`, `baselineOffset` | ❌ | |
| `lineLimit`, `multilineTextAlignment` | ✅ | |
| `truncationMode`, `minimumScaleFactor`, `allowsTightening` | ❌ | |
| `Image` (asset/bundle name, `uiImage:`), `resizable`, `renderingMode`, `interpolation` | ✅ | |
| `Image(systemName:)` | 🟡 | substitute glyphs, not SF Symbols |
| `imageScale`, `symbolRenderingMode`, `symbolVariant`, `symbolEffect` | ❌ | |
| `AsyncImage` | ❌ | needs networking |
| `Label` | ✅ | |
| `Button` (action, label, role) | ✅ | |
| Button styles: `.plain`, `.borderless`, `.bordered`, `.borderedProminent`, custom `ButtonStyle` | ✅ | |
| `PrimitiveButtonStyle`, `.controlSize`, `.buttonBorderShape` | ❌ | |
| `Toggle` (switch) | ✅ | |
| `toggleStyle` (`.button`, `.checkbox`, custom) | 🧩 | accepted, ignored |
| `Slider` | ✅ | UISlider; step, value labels, onEditingChanged; tested |
| `Stepper` | ✅ | value/bounds/step and onIncrement/onDecrement; tested |
| `Picker` (menu, segmented, wheel, inline, navigationLink styles) | 🟡 | menu, segmented, inline, navigationLink styles; wheel shown as a menu; tested |
| `DatePicker`, `MultiDatePicker` | ❌ | |
| `ColorPicker` | ❌ | |
| `TextField` (String binding, placeholder, `axis: .vertical` multi-line) | ✅ | `prompt` ignored |
| `TextField(value:format:)` | ❌ | |
| `SecureField` | ✅ | |
| `TextEditor` | ❌ | |
| `ProgressView` | ✅ | UIProgressView bar / spinning UIActivityIndicatorView |
| `Gauge` | ❌ | |
| `Link` | ✅ | opens through `openURL` |
| `ShareLink` | ❌ | |
| `Menu` | ✅ | pop-up menu with sections, submenus, pickers, destructive buttons; tested |
| `Divider`, `Spacer`, `EmptyView`, `Color` as a view | ✅ | |
| `LabeledContent` | ✅ | |
| `ContentUnavailableView` | ❌ | |
| `ControlGroup`, `GroupBox`, `DisclosureGroup`, `OutlineGroup` | ❌ | |
| `EditButton`, `PasteButton`, `RenameButton` | ❌ | |
| `VideoPlayer` (AVKit), `Map` (MapKit), `SceneView` | ❌ | |
| `SpriteView` | ✅ | see SpriteKit |

### Containers & layout

| API / feature | Status | Notes |
|---|---|---|
| `VStack`, `HStack`, `ZStack` (alignment, spacing) | ✅ | |
| `Spacer(minLength:)`, `layoutPriority`, `fixedSize` | ✅ | |
| `LazyVStack`, `LazyHStack` | 🟡 | laid out like plain stacks; `pinnedViews` ignored |
| `LazyVGrid` (`GridItem` fixed / flexible / adaptive) | 🟡 | `pinnedViews` ignored |
| `LazyHGrid` | ❌ | a typealias of `LazyVGrid`; `init(rows:)` does not exist |
| `Grid`, `GridRow` | ❌ | |
| `ScrollView` (vertical, horizontal) | ✅ | |
| `ScrollViewReader`, `scrollTo` | ✅ | |
| `scrollIndicators`, `scrollDisabled`, `scrollBounceBehavior` | 🧩 | accepted, ignored |
| `scrollPosition`, `scrollTargetBehavior` (paging), `scrollTransition`, `onScrollGeometryChange` | ❌ | |
| `List` (content builder, sections) | 🟡 | inset-grouped look; no `List(data)`, selection or editing |
| `listStyle`, `listRowBackground`, `listRowSeparator`, `listSectionSpacing`, `scrollContentBackground` | 🧩 | accepted, ignored |
| `.onDelete`, `.onMove`, `.swipeActions`, edit mode | ❌ | |
| `Form` | ✅ | inset-grouped rows; `formStyle` ignored |
| `Section` (header, footer) | ✅ | |
| `ForEach` (`id:`, `Identifiable`, `Range`) | ✅ | |
| `Group`, `AnyView`, `if`/`switch` in builders | ✅ | |
| `GeometryReader`, `GeometryProxy.size`, `frame(in: .local/.global)`, safe-area insets | ✅ | |
| Named coordinate spaces | 🟡 | `.named` falls back to global |
| `ViewThatFits` | ❌ | |
| `Layout` protocol, `AnyLayout` | ❌ | |
| `containerRelativeFrame` | ❌ | |
| `frame` (fixed, min/ideal/max, alignment), `padding`, `aspectRatio`, `offset` | ✅ | |
| `position`, `alignmentGuide` | ❌ | |
| `ignoresSafeArea`, `edgesIgnoringSafeArea` | ✅ | |
| `safeAreaInset`, `safeAreaPadding`, `contentMargins` | ❌ | |
| `overlay`, `background` (view, shape style, `in:` shape), `zIndex` | ✅ | |

### Navigation & presentation

| API / feature | Status | Notes |
|---|---|---|
| `NavigationStack` (root, path `[D]` / `NavigationPath`) | 🟡 | nav bar with large/inline title and back button; push/pop not animated, no edge-swipe back |
| `NavigationLink(destination:)`, `NavigationLink(value:)` | ✅ | |
| `navigationDestination(for:)` | ✅ | |
| `navigationDestination(isPresented:)`, `navigationDestination(item:)` | ❌ | |
| `NavigationView` | ✅ | stack style |
| `NavigationSplitView` | ❌ | |
| `navigationTitle`, `navigationBarTitleDisplayMode` | ✅ | |
| `navigationBarBackButtonHidden` | 🧩 | ignored |
| `.toolbar` with `ToolbarItem` / `ToolbarItemGroup` | 🟡 | top-bar leading/trailing only; `.principal`, `.bottomBar`, `.keyboard` not placed as on iOS |
| `toolbarBackground`, `toolbarColorScheme`, `toolbar(.hidden)` | ❌ | |
| `TabView` (tab bar, `.tabItem`, `.badge`, selection) | ✅ | material tab bar, SF Symbol items, badges, selection, iOS 18 `Tab`; tested |
| `TabView` `.tabViewStyle(.page)` | ✅ | swipe paging with page dots; tested |
| `.sheet(isPresented:)` / `.sheet(item:)` | ✅ | page sheet with swipe-down dismiss; content gets the environment + `dismiss`; tested (HelloPresentations) |
| `.fullScreenCover` | ✅ | slides up full screen; tested |
| `.popover` | 🟡 | shown as a sheet (iPhone behaviour); no arrow popovers on iPad |
| `.alert` | 🟡 | title, message, button roles (UIAlertController); no text fields in alerts; tested |
| `.confirmationDialog` | ✅ | action sheet with Cancel; tested |
| `presentationDetents`, `presentationDragIndicator`, `interactiveDismissDisabled` | ❌ | |
| `@Environment(\.dismiss)` | 🟡 | pops the navigation stack; nothing else to dismiss |
| `.searchable` | ❌ | |
| `.refreshable` | ❌ | |
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
| `pickerStyle`, `datePickerStyle`, `progressViewStyle`, `gaugeStyle` | ❌ | |
| `ViewModifier`, `.modifier` | ✅ | |
| `redacted`, `privacySensitive` | ❌ | |
| `badge`, `help`, `contextMenu` | ❌ | |

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
| `onGeometryChange`, `onContinuousHover`, `onHover` | ❌ | |

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
| `calendar`, `timeZone`, `dynamicTypeSize`, `colorSchemeContrast` | ❌ | |
| `editMode`, `isPresented`, `isSearching`, `presentationMode` | ❌ | |
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
| `TimeZone` (named zones, DST) | ✅ | Settings > Date & Time or the host's zone |
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
| `Timer` (block / target-selector, repeating, `RunLoop.add`) | ✅ | |
| `RunLoop` | 🟡 | main run loop only; modes ignored |
| `Thread` (main checks, detach, sleep, name) | ✅ | |
| `OperationQueue` | 🟡 | block operations only; no `Operation` subclasses or dependencies |
| `NSLock`, `NSRecursiveLock`, `NSCondition` | ✅ | |
| `ProcessInfo` (environment, arguments, processor count, uptime) | ✅ | |
| `ProcessInfo.thermalState`, `isLowPowerModeEnabled` | ❌ | |

### Networking

| API / feature | Status | Notes |
|---|---|---|
| `URL` (parsing, components, file URLs, path helpers, percent encoding) | ✅ | |
| `URLComponents`, `URLQueryItem` | ❌ | |
| `URLRequest`, `HTTPURLResponse` | ❌ | |
| `URLSession` data/download/upload tasks (completion and async) | ❌ | the biggest Foundation gap |
| `URLSessionWebSocketTask` | ❌ | |
| Background `URLSession` | ❌ | |
| `URLCache`, `HTTPCookieStorage` | ❌ | |

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
| `URLSession.dataTaskPublisher`, KVO publisher | ❌ | |

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

| API / feature | Status | Notes |
|---|---|---|
| `SKView`, `SKScene` (size, scale modes, anchor point, background, update loop, delegate) | ✅ | software rendered at 60 fps |
| `SKNode` tree (position, z-order, scale, rotation, alpha, hidden, name lookup, `enumerateChildNodes`) | ✅ | |
| `SKSpriteNode` (texture, color, color blend, anchor, `centerRect`) | ✅ | |
| `SKShapeNode` (path, rect, circle, fill/stroke, line width) | ✅ | |
| `SKLabelNode` (font, size, color, alignment, multi-line) | ✅ | |
| `SKTexture` (`imageNamed:`, sub-rect, filtering) | ✅ | |
| `SKAction` (move, rotate, scale, fade, colorize, resize, sequence, group, repeat, wait, run block, custom, timing modes) | ✅ | |
| `SKAction.playSoundFileNamed` | 🧩 | completes silently |
| Touch handling in scenes/nodes | ✅ | via SKView |
| `SKTransition` / `presentScene(_:transition:)` | 🧩 | presents without the transition effect |
| `SpriteView` (SwiftUI) | ✅ | |
| `camera` | 🟡 | typed as `SKNode`; no `SKCameraNode` class |
| `SKPhysicsBody`, contacts, joints, fields | ❌ | `SKPhysicsWorld` exists so scenes that configure it run |
| `SKEmitterNode` (particles, `.sks` emitters) | ❌ | |
| `.sks` scene files (`SKScene(fileNamed:)`) | 🧩 | logs and returns an empty scene |
| `SKTextureAtlas` / `.atlas` folders | ❌ | |
| `SKCropNode`, `SKEffectNode`, `SKShader`, `SKLightNode`, `SKTileMapNode`, `SKVideoNode`, `SKReferenceNode` | ❌ | |
| `SKConstraint`, `SKAudioNode` | ❌ | |

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

## GameController, SceneKit, RealityKit & ARKit

| API / feature | Status | Notes |
|---|---|---|
| GameController (`GCController`, `GCKeyboard`, virtual controller) | ❌ | |
| SceneKit (`SCNView`, `SCNScene`, `SceneView`) | ❌ | |
| RealityKit | ❌ | |
| ARKit | ❌ | no camera or sensors |
| GameplayKit (state machines, random sources, pathfinding) | ❌ | |

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
| SQLite (`sqlite3` C API) | ❌ | not in the SDK |
| Keychain (`SecItemAdd/CopyMatching/Update/Delete`) | ❌ | |

## Identity & security

| API / feature | Status | Notes |
|---|---|---|
| Sign in with Apple (`ASAuthorizationAppleIDProvider`, `SignInWithAppleButton`) | ❌ | |
| `ASWebAuthenticationSession` (OAuth) | ❌ | |
| Passkeys, password AutoFill (`ASAuthorizationController`) | ❌ | |
| LocalAuthentication (Face ID / Touch ID, `LAContext`) | ❌ | |
| CryptoKit (SHA-2, HMAC, AES-GCM, ChaChaPoly, P256, Curve25519) | ❌ | |
| CommonCrypto, Security (`SecRandomCopyBytes`, certificates, trust) | ❌ | |
| DeviceCheck / App Attest | ❌ | |

## Notifications & background work

| API / feature | Status | Notes |
|---|---|---|
| UserNotifications: authorization request | ❌ | |
| Local notifications (`UNNotificationRequest`, time/calendar triggers) | ❌ | |
| Notification presentation (banners, Notification Center, actions, foreground delegate) | ❌ | |
| Push notifications (APNs registration, remote payloads) | ❌ | |
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
| Network framework (`NWConnection`, `NWPathMonitor`) | ❌ | |
| BSD sockets (`socket`, `getaddrinfo`) | ❌ | not exported by isim's libSystem |
| MultipeerConnectivity | ❌ | |
| Universal Links / Associated Domains | ❌ | |

## Logging & diagnostics

| API / feature | Status | Notes |
|---|---|---|
| `print`, `NSLog`, `debugPrint` | ✅ | to the terminal running isim |
| `os.Logger`, `os_log`, `OSLog`, signposts | ❌ | `os` module not provided |
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
