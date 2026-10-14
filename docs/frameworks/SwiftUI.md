# SwiftUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 58.7% of Apple's iOS API (4015 of 6841, exact) · **Rows:** 98% (241: 234 ✅ 5 🟡 2 ❌) · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [SwiftUI & Charts](../COVERAGE.md#swiftui) · **Apple:** [SwiftUI](https://developer.apple.com/documentation/swiftui) · **Issues:** [`area:swiftui`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aswiftui)

## How isim implements it

- **Adapted:** isim's own engine (`isim/swift/overlays/SwiftUI`).
- Views evaluate into a node tree, are laid out with SwiftUI's proposal model, and are mounted as isim's UIKit views.
- Shapes, `Canvas` and gradients draw through cairo.
- Shaders are missing: they need Metal, which isim does not have.

## API


### App & scenes

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `App` protocol, `@main` | ✅ | ≤17 | |
| `WindowGroup` | ✅ | ≤17 | one window; `title` ignored |
| Several scenes in `body`, `Settings`, `DocumentGroup`, `Window` | ✅ | ≤17 | several `WindowGroup`s (`id:`, `for:`) and scene modifiers in `body`, `if` / `else` and `if #available` between scenes; the first group is shown (tested, HelloScenes). `Settings`/`Window` are macOS-only (not provided, like the iOS SDK). `DocumentGroup(newDocument:editor:)` / `(viewing:viewer:)` with `FileDocument` (a value; binding edits are undoable and autosaved) or `ReferenceFileDocument` (saved from snapshots; changes count through `\.undoManager` registrations and `objectWillChange`), `FileDocumentConfiguration` / `ReferenceFileDocumentConfiguration`, `\.documentConfiguration`, `\.undoManager`: on UIKit's `UIDocumentViewController` (iOS 18: the launch view with the app's name on its accent colour, Create Document, the document browser; the editor under the navigation bar with the document's name, back and undo / redo); contents are `FileWrapper`s. Tested (HelloDocumentGroup, OS matrix) |
| `@Environment(\.scenePhase)` | ✅ | ≤17 | active / inactive / background |
| `@UIApplicationDelegateAdaptor` | ✅ | ≤17 | launch callbacks, every other `UIApplicationDelegate` method forwarded (ObjC forwarding), a scene delegate class from its `configurationForConnecting` gets the scene callbacks SwiftUI does not handle. Tested (HelloScenes) |
| `UIHostingController` | ✅ | ≤17 | |
| `.onOpenURL` | ✅ | ≤17 | URLs of the app's `CFBundleURLTypes` schemes (and universal links without an `onContinueUserActivity` handler) opened by other apps (`Link`, `openURL`, `UIApplication.open`) or the script's `openurl`, on a cold launch (delivered once the handler's view renders) or while running. Tested (HelloScenes → HelloSwiftUIControls under `isim boot`) |
| `.onContinueUserActivity`, `.handlesExternalEvents` | ✅ | ≤17 | `.onContinueUserActivity` (Spotlight, universal links; queued until a handler registers), `.userActivity(_:isActive:_:)` advertises/indexes; `.handlesExternalEvents` accepted (one scene). Tested (HelloScenes) |
| `.backgroundTask` | ✅ | ≤17 | `.appRefresh(id)` runs when the request is launched (script `bgtask BUNDLE ID`), also in a background launch; `.urlSession(id)` runs where a UIKit app's `handleEventsForBackgroundURLSession` would (the session's events follow), also after a relaunch for unfinished transfers, where the action can recreate the session. Tested (HelloScenes: test_scenes, test_transfers) |
| `openWindow` / `dismissWindow` | ✅ | ≤17 | iPad + `UIApplicationSupportsMultipleScenes`: each WindowGroup window is a UIKit scene session: `openWindow(id:)` / `(value:)` / `(id:value:)` opens the group in a new window beside the current one (split view, see UIKit's multiple scenes) or brings back the one already showing that group and value; `WindowGroup(for:)` content gets the value as a binding (changing it changes the window's value); `dismissWindow()` closes the view's own window, `dismissWindow(id:)` / `(value:)` those of a group; windows come back on relaunch with their group and value. iPhone: ignored like iOS; `supportsMultipleWindows`. Tested (HelloScenes) |
| `#Preview` / `PreviewProvider` | 🟡 | ≤17 | adapted: `#Preview` (SwiftUI views, UIViews, UIViewControllers; names, traits) and `PreviewProvider` (+ `previewDisplayName` / `previewLayout` / `previewDevice` / `previewInterfaceOrientation`) compile and type-check: isim's PreviewsMacros plugin expands each `#Preview` into a `DeveloperToolsSupport.PreviewRegistry` type like Xcode's, plus an exported entry point; `isim preview App.app [NAME\|INDEX\|--list] [-o FILE.png]` renders one `#Preview` to a screenshot (the app runs alone in UIKit's preview mode) laid out by its traits (the device, `.sizeThatFitsLayout` and `.fixedLayout` centred on a grey canvas; orientation traits not applied: use `--device`). No live canvas; `PreviewProvider` previews are not rendered and their modifiers change nothing. Tested: HelloToolchain (UIKit) and HelloSwiftUI (SwiftUI, PreviewProvider) build with previews; `isim preview` (test_previews). Missing: `@Previewable`, `PreviewModifier` / `PreviewTrait.modifier`, widget and Live Activity previews (`#Preview(as:widget:timeline:)`) |

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
| `@FocusedValue`, `@FocusedBinding` | ✅ | ≤17 | a `.focusedValue` is seen while its view or one inside it has focus (the innermost value of a key wins), a `.focusedSceneValue` while its scene is shown; readers update when focus moves. Tested (HelloKeys) |
| `PreferenceKey`, `.preference`, `.onPreferenceChange`, anchor preferences | ✅ | ≤17 | values reduce up the laid-out tree (incl. GeometryReader backgrounds), `transformPreference`, `anchorPreference` / `transformAnchorPreference` with `overlayPreferenceValue` / `backgroundPreferenceValue` and `proxy[anchor]`; tested (HelloLayout) |
| `Transaction`, `withTransaction` | ✅ | ≤17 | the animation / `disablesAnimations` / `isContinuous` / `tracksVelocity` / `scrollTargetAnchor`, custom `TransactionKey` values (and `@Entry`), `withTransaction(_:_:)` and the key path form, `.transaction { }` (its changes apply to the views inside), `.transaction(value:_:)`, `.transaction(_:body:)`, `addAnimationCompletion`; `UIViewRepresentableContext.transaction`. Tested (HelloContainers) |

### Views & controls

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `Text` (verbatim, `LocalizedStringKey` with interpolation, font/weight/italic/color) | ✅ | ≤17 | `Text(_:tableName:bundle:comment:)` looks the key up in that table and bundle; `Text(LocalizedStringResource)` resolves like `String(localized:)`. Tested (HelloSwiftUIImageText: test_swiftui_image_text) |
| `Font` (text styles, `system`, `custom` incl. `relativeTo:`, `Font(CTFont)`, `Font(UIFont)`, `weight`, `width`, `italic`, `monospaced`) | 🟡 | ≤17 | `custom(_:size:relativeTo:)` scales with Dynamic Type like its text style; `Font(CTFont)` uses the face with that PostScript name at its size, `Font(UIFont)` the font itself (bold / italic / monospaced still apply). `width(_:)` reaches UIKit's `systemFont(ofSize:weight:width:)`, which draws the default face (adapted: no condensed or expanded system face on Linux). Tested (HelloSwiftUIImageText: test_swiftui_image_text, test_font_relative_to_dynamic_type) |
| `Text + Text` concatenation | ✅ | ≤17 | parts keep their own font/colour/weight; mixed styles laid out word by word (adapted); tested (HelloText) |
| `Text(date, style:)`, `Text(_:format:)`, `Text(timerInterval:)` | ✅ | ≤17 | `.time/.date/.relative/.offset/.timer` styles (relative ones re-render every second), date ranges, `Text(_:format:)` with Foundation format styles, `\(value, format:)` / `\(date, style:)` interpolation, `Text(_:formatter:)`; tested (HelloText) |
| Markdown in `Text`, `AttributedString` | ✅ | ≤17 | string literals parse `**bold**`, `*italic*`, `***both***`, `` `code` ``, `~~strike~~`, `[links](url)` (tap opens through `openURL`); `Text(AttributedString)` maps presentation intents, links and the SwiftUI attribute scope (`foregroundColor`, `font`, underline/strikethrough, kern, baselineOffset); tested (HelloText). Italic is a sheared glyph run (isim fonts have no italic faces) |
| `Text(Image)` (inline images in text, `Text + Text`, Canvas `draw(Text)`) | ✅ | ≤17 | symbols take the text's font size, weight and colour; laid out as words in rich text; tested (HelloSourceCompat). SF Symbols without a stand-in icon draw as a placeholder |
| `strikethrough`, `underline`, `kerning`, `tracking`, `textCase`, `baselineOffset` | ✅ | ≤17 | on `Text` and as view modifiers; lines are hairline views, kerning places glyphs one by one (`tracking` = `kerning`), line patterns drawn solid; tested (HelloText) |
| `lineLimit`, `multilineTextAlignment` | ✅ | ≤17 | |
| `truncationMode`, `minimumScaleFactor`, `allowsTightening` | ✅ | ≤17 | head / middle / tail truncation of one-line text, `minimumScaleFactor` shrinks one-line text to fit, `allowsTightening` draws a slightly long line with its letters closer together (up to 5% of the size) before truncating (UILabel `allowsDefaultTighteningForTruncation`). Tested (HelloSwiftUIControls) |
| `Image` (asset/bundle name, `uiImage:`), `resizable`, `renderingMode`, `interpolation` | ✅ | ≤17 | named images load from the given bundle; `Image(_:bundle:label:)` is an accessibility element with that label and the image trait, `Image(decorative:bundle:)` is hidden from accessibility; `Image(_:scale:orientation:label:)` / `Image(decorative:scale:orientation:)` draw a `CGImage` at that scale, turned / mirrored by `Image.Orientation`. Tested (HelloSwiftUIImageText: test_swiftui_image_text) |
| `Image(_: ImageResource)`, `Color(_: ColorResource)` (Xcode's generated asset symbols: `Image(.logo)`, `Color(.brand)`, `.foregroundStyle(.brand)`) | ✅ | ≤17 | load the asset catalog image / color (light and dark variants). `Color(_: UIColor)` is a disfavoured overload, so `Color(.brand)` picks the `ColorResource` when the generated `UIColor` member has the same name. Tested (HelloAssetSymbols: test_asset_symbols, test_asset_symbols_dark) |
| `Image(systemName:)` | 🟡 | ≤17 | the same stand-in drawings as `UIImage(systemName:)` (not Apple's SF Symbols); `.font` / `.fontWeight` set size and stroke weight. `variableValue:` (also on the named initialisers) lights the levels of `wifi`, `cellularbars` and `speaker.wave.*` (adapted, see UIKit); other symbols draw as without a value. Tested (HelloSwiftUIImageText: test_swiftui_variable_symbols_differ) |
| `imageScale`, `symbolRenderingMode`, `symbolVariant`, `symbolEffect` | ✅ | ≤17 | `imageScale`; `symbolVariant` (`.fill`, `.circle`, `.square`, `.slash`, combined) picks the variant symbol; `symbolRenderingMode` (also `Image.symbolRenderingMode`) `.monochrome` / `.hierarchical` / `.palette` (the `foregroundStyle(_:_:)` / `(_:_:_:)` colours) / `.multicolor` through UIKit's symbol configurations (see UIKit: rendering modes, adapted to isim's two-layer stand-in symbols); `symbolEffect`: adapted like UIKit's — bounce, pulse, variable colour, scale, appear / disappear, replace (content transition), iOS 18 wiggle / rotate / breathe animate the whole symbol, with `SymbolEffectOptions` repeats and speed. Tested (HelloSwiftUIControls, OS matrix; HelloEffects) |
| `AsyncImage` | ✅ | ≤17 | URLSession (http(s), file, data URLs); phases, `content:placeholder:`; decoded through a temporary file; tested (HelloPickers) |
| `Label` | ✅ | ≤17 | |
| `Button` (action, label, role) | ✅ | ≤17 | |
| Button styles: `.plain`, `.borderless`, `.bordered`, `.borderedProminent`, custom `ButtonStyle` | ✅ | ≤17 | |
| `PrimitiveButtonStyle`, `.controlSize`, `.buttonBorderShape` | ✅ | ≤17 | primitive styles build the whole button and call `trigger()`; control size sets bordered padding/font; capsule / rounded / circle shapes; tested (HelloPickers) |
| `Toggle` (switch) | ✅ | ≤17 | |
| `toggleStyle` (`.button`, `.checkbox`, custom) | ✅ | ≤17 | `.switch`, `.button` (tinted when on) and custom `ToggleStyle`s (`.checkbox` is macOS-only); `.button` tested (HelloPickers) |
| `Slider` | ✅ | ≤17 | UISlider; step, value labels, onEditingChanged; tested |
| `Stepper` | ✅ | ≤17 | value/bounds/step and onIncrement/onDecrement; tested |
| `Picker` (menu, segmented, wheel, inline, navigationLink styles) | ✅ | ≤17 | all five styles; `.wheel` is a snapping scroll-wheel drawn by isim (no UIPickerView); tested (HelloForms, HelloPickers) |
| `DatePicker`, `MultiDatePicker` | ✅ | ≤17 | `DatePicker`: compact (date / time pills open the calendar or the time wheel in a popover, like iOS; picking a day closes it), graphical (month grid, month paging, time row), wheel; `.date` / `.hourAndMinute`; ranges; `labelsHidden`. `MultiDatePicker`: a month calendar toggling days in a `Set<DateComponents>`, `in:` ranges (days outside disabled). Tested (HelloPickers, HelloSwiftUIControls, OS matrix) |
| `ColorPicker` | ✅ | ≤17 | UIKit's colour well, presenting UIKit's colour picker (grid, spectrum, sliders, opacity, saved colours, eyedropper; see UIKit `UIColorPickerViewController`), like iOS; `Color` and `CGColor` bindings, `supportsOpacity`. Tested (HelloPickers) |
| `TextField` (String binding, placeholder, `axis: .vertical` multi-line) | ✅ | ≤17 | `prompt` ignored |
| `TextField(value:format:)`, `TextField(value:formatter:)` | ✅ | ≤17 | parseable format styles and NumberFormatter / DateFormatter values, parsed on Return or end of editing (unparseable text reverts); tested (HelloPickers) |
| `SecureField` | ✅ | ≤17 | |
| `TextEditor` | ✅ | ≤17 | multi-line field that fills its frame; tested (HelloPickers) |
| `ProgressView` | ✅ | ≤17 | UIProgressView bar / spinning UIActivityIndicatorView; labels and current-value labels, `.linear` / `.circular` / custom `ProgressViewStyle`; label tested (HelloPickers) |
| `Gauge` | ✅ | ≤17 | linear capacity (default), `.accessoryLinear`, `.accessoryCircular`, `.accessoryCircularCapacity`, custom `GaugeStyle`; tested (HelloPickers) |
| `Link` | ✅ | ≤17 | opens through `openURL` |
| `ShareLink` | ✅ | ≤17 | presents UIKit's share sheet (`UIActivityViewController`: Copy, Save Image, Print, the installed apps' Share and Action extensions) with the item(s): URLs, strings, `Transferable` values (their first exported type as text, a URL, an image or a file), `items:`, `subject` / `message`, `SharePreview`. Tested (HelloPickers, HelloSwiftUIControls, OS matrix) |
| `Menu` | ✅ | ≤17 | pop-up menu with sections, submenus, pickers, destructive buttons; tested |
| `Divider`, `Spacer`, `EmptyView`, `Color` as a view | ✅ | ≤17 | |
| `LabeledContent` | ✅ | ≤17 | |
| `ContentUnavailableView` | ✅ | 17.0 | icon, title, description, actions; `.search` / `.search(text:)`; tested (HelloPickers) |
| `ControlGroup`, `GroupBox`, `DisclosureGroup`, `OutlineGroup` | ✅ | ≤17 | disclosure rows expand/collapse (own state or `isExpanded:` binding; in a List the content follows as indented rows); `OutlineGroup` and `List(_:children:)` build the tree; control groups share one bordered row (`controlGroupStyle` ignored); tested (HelloPickers) |
| `EditButton`, `PasteButton`, `RenameButton` | ✅ | ≤17 | `EditButton` toggles `\.editMode` (tested, HelloLists); `PasteButton` is UIKit's paste control: enabled while the pasteboard has an accepted type, a tap pastes without the "Allow Paste" prompt and delivers `Transferable` payloads or item providers (tested, HelloSwiftUIControls); `RenameButton` runs `.renameAction { }` or focuses `.renameAction($focus)` (tested) |
| `VideoPlayer` (AVKit) | ✅ | ≤17 | with `videoOverlay`: see AVKit (tested there) |
| `Map` (MapKit) | ✅ | ≤17 | iOS 17 MapContent + iOS 14 `coordinateRegion` API on isim's MKMapView, with map controls: see the MapKit rows; tested (HelloMaps) |
| `SceneView` (SceneKit) | ❌ | ≤17 | needs SceneKit, a 3D renderer isim does not have (see the SceneKit row); not part of SwiftUI itself |
| `SpriteView` | ✅ | ≤17 | see SpriteKit |

### Containers & layout

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `VStack`, `HStack`, `ZStack` (alignment, spacing) | ✅ | ≤17 | |
| `Spacer(minLength:)`, `layoutPriority`, `fixedSize` | ✅ | ≤17 | |
| `LazyVStack`, `LazyHStack` | ✅ | ≤17 | adapted: all views are laid out (not created on demand), like stacks; sections splice their header, rows and footer; `pinnedViews` `.sectionHeaders` stick to the top (leading) edge of the scroll view while their section passes under it and are pushed away by the next, `.sectionFooters` to the bottom (trailing) edge. Tested (HelloContainers: LazyVStack header / footer pinning, LazyHStack) |
| `LazyVGrid` (`GridItem` fixed / flexible / adaptive) | ✅ | ≤17 | columns: fixed sizes, flexible ones share the rest within their bounds, adaptive ones repeat as many times as fit; `GridItem.spacing` between columns (default 8), the grid's `spacing` between rows, `GridItem.alignment` in the cells, the grid's alignment; sections (the header and footer span the grid, items start a new row), `pinnedViews`; `LazyHGrid` the same across rows. Eager layout (adapted). Tested (HelloContainers, HelloLayout) |
| `LazyHGrid` | ✅ | ≤17 | `init(rows:)` with fixed / flexible / adaptive rows, items flow down then across; laid out eagerly; tested (HelloLayout) |
| `Grid`, `GridRow` | ✅ | ≤17 | column widths from the widest cells, flexible cells share the rest; `gridCellColumns`, `gridColumnAlignment`, `gridCellAnchor`, `gridCellUnsizedAxes`, row alignment, full-width non-row views; tested (HelloLayout) |
| `ScrollView` (vertical, horizontal) | ✅ | ≤17 | |
| `ScrollViewReader`, `scrollTo` | ✅ | ≤17 | |
| `scrollIndicators`, `scrollDisabled`, `scrollBounceBehavior` | ✅ | ≤17 | `scrollIndicators(.hidden / .never)` hides the indicators (the view dump says "indicators hidden"), `scrollDisabled`, `scrollBounceBehavior(.basedOnSize)`: content that fits does not bounce. Tested (HelloContainers, HelloLayout) |
| `scrollPosition`, `scrollTargetBehavior` (paging), `scrollTransition`, `onScrollGeometryChange` | ✅ | ≤17 | `.paging` (UIScrollView paging), `.viewAligned` + `scrollTargetLayout()` (snaps to children), custom `ScrollTargetBehavior.updateTarget`, `scrollPosition(id:)` both ways; tested (HelloLayout). `scrollTransition` (identity while visible, interpolated towards the edge phase as the view leaves; `.animated`, thresholds) and iOS 18 `onScrollGeometryChange` / `onScrollVisibilityChange`; tested (HelloEffects) |
| `List` (content builder, sections, data, selection) | ✅ | ≤17 | list styles below; `List(data)`, `List(data, children:)`, `List(selection:)` single (tested via NavigationSplitView) and multiple (selection circles in edit mode, rows make room; tested, HelloContainers) |
| `listStyle`, `listRowBackground`, `listRowSeparator`, `listSectionSpacing`, `scrollContentBackground` | ✅ | ≤17 | UITableView's looks: `.automatic` / `.insetGrouped` (cards inset 20 pt), `.grouped` (full width, section hairlines), `.plain` (system background, bold headers on a grey band that stick to the top, separators under every row), `.inset` (plain, rows inset), `.sidebar` (no separators, large bold headers, rounded selection); `listRowBackground`, `listRowInsets`, `listRowSeparator(_:edges:)` / `listRowSeparatorTint`, `listSectionSeparator` / `Tint`, `listRowSpacing` (each row its own card), `listSectionSpacing` (`.default` / `.compact` / custom, on the list or a section), `scrollContentBackground(.hidden)`, `headerProminence(.increased)`, `listItemTint`, `defaultMinListRowHeight` / `defaultMinListHeaderHeight`, `Section(isExpanded:)` (sidebar and plain headers collapse it). Tested (HelloContainers, OS matrix) |
| `.onDelete`, `.onMove`, `.swipeActions`, edit mode | ✅ | ≤17 | swipe to delete, leading/trailing swipe actions (tint, full swipe), edit mode delete buttons and reorder handles; tested (HelloLists) |
| `Form` | ✅ | ≤17 | inset-grouped rows; `formStyle` ignored |
| `Section` (header, footer) | ✅ | ≤17 | |
| `ForEach` (`id:`, `Identifiable`, `Range`) | ✅ | ≤17 | |
| `Group`, `AnyView`, `if`/`switch` in builders | ✅ | ≤17 | |
| `GeometryReader`, `GeometryProxy.size`, `frame(in: .local/.global)`, safe-area insets | ✅ | ≤17 | |
| Named coordinate spaces | ✅ | ≤17 | `.coordinateSpace(name:)` / `.coordinateSpace(.named(_))`, `.named`, `.global`, `.local`, `.scrollView`: GeometryReader and onGeometryChange frames measured from the views (geometry effects such as `.offset` included); content laid out before its views exist gets the frame of the previous render and the graph renders again when a frame changes (also while an enclosing scroll view scrolls), like SwiftUI re-evaluating geometry; DragGesture / SpatialTapGesture locations in any space; `GeometryProxy.safeAreaInsets`. Tested (HelloContainers) |
| `ViewThatFits` | ✅ | ≤17 | first child whose ideal size fits (per axis); tested (HelloLayout) |
| `Layout` protocol, `AnyLayout` | ✅ | ≤17 | `sizeThatFits` / `placeSubviews` with subviews' `sizeThatFits` / `dimensions` / `place(at:anchor:proposal:)`, caches, `layoutValue`; `AnyLayout` switching keeps child state; `HStackLayout` / `VStackLayout` / `ZStackLayout` / `GridLayout`; tested (HelloLayout). Spacing preferences are a fixed 8 pt; not animatable |
| `containerRelativeFrame` | ✅ | ≤17 | relative to the nearest container: a scroll view, a list, the content area of a navigation stack or tab view, a split view column, else the window's safe area; `count:span:spacing:` and closure forms. Tested (HelloLayout, HelloContainers) |
| `frame` (fixed, min/ideal/max, alignment), `padding`, `aspectRatio`, `offset` | ✅ | ≤17 | |
| `position`, `alignmentGuide` | ✅ | ≤17 | `position` centres the view at a point; explicit guides and custom `AlignmentID`s line up views in HStack / VStack / ZStack, also through nested stacks; tested (HelloLayout) |
| `ignoresSafeArea`, `edgesIgnoringSafeArea` | ✅ | ≤17 | |
| `safeAreaInset`, `safeAreaPadding`, `contentMargins` | ✅ | ≤17 | `safeAreaInset` lays the inset view at the edge; a scroll view or list filling the content extends beneath it with its content inset by it (the last rows scroll out from under it), other content is laid out in the rest; `safeAreaPadding`: content insets for scroll views and lists, padding for other views; `contentMargins` `.scrollContent` (content) / `.scrollIndicators` (indicator insets) / `.automatic`. Tested (HelloContainers, HelloLayout) |
| `overlay`, `background` (view, shape style, `in:` shape), `zIndex` | ✅ | ≤17 | |
| `Group(subviews:)`, `ForEach(subviews:)`, `containerValue`, `@Entry` | ✅ | 18.0 | `Group(subviews:)` / `ForEach(subviews:)` (`Subview`, `SubviewsCollection`, slices), `Group(sections:)` / `ForEach(sections:)` (`SectionConfiguration`: header, content, footer, container values; loose views form sections), `ContainerValueKey` / `ContainerValues` / `.containerValue` (on views, ForEach and sections); the content splits into views like a stack would (ForEach, conditionals, custom views' bodies); a subview placed under another environment resolves again there. `@Entry` (isim's SwiftUIMacros compiler plugin) in EnvironmentValues, ContainerValues, FocusedValues and Transaction. Tested (HelloContainers) |

### Navigation & presentation

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `NavigationStack` (root, path `[D]` / `NavigationPath`) | ✅ | ≤17 | nav bar with large/inline title and back button; push slides in from the trailing edge, pop slides out (a picture of the leaving level), swipe from the leading edge drags back; tested (HelloNavStack, HelloLists) |
| `NavigationLink(destination:)`, `NavigationLink(value:)` | ✅ | ≤17 | |
| `navigationDestination(for:)` | ✅ | ≤17 | |
| `navigationDestination(isPresented:)`, `navigationDestination(item:)` | ✅ | ≤17 | pushes while presented; back / `dismiss` reset the binding; tested (HelloLists) |
| `NavigationView` | ✅ | ≤17 | stack style |
| `NavigationSplitView` | ✅ | ≤17 | iPhone: the columns as a stack, a `List(selection:)` choice shows the next column (tested, HelloLists, HelloSplit). iPad: columns side by side, each with its own navigation bar, a sidebar button, `columnVisibility` binding, `navigationSplitViewColumnWidth`, `.balanced` / `.prominentDetail` (the sidebar floats over the columns), `preferredCompactColumn`; tested (HelloSplit) |
| `navigationTitle`, `navigationBarTitleDisplayMode` | ✅ | ≤17 | |
| `navigationBarBackButtonHidden` | ✅ | ≤17 | hides the back button and the edge swipe back; tested (HelloNavStack) |
| `.toolbar` with `ToolbarItem` / `ToolbarItemGroup` | ✅ | ≤17 | leading / trailing items side by side (iOS 26+: one glass capsule per group), `.principal`, `.secondaryAction` (a "More" menu), `.bottomBar` / `.status` bar, `.keyboard` bar on the keyboard, `ToolbarTitleMenu` / `toolbarTitleMenu`, `toolbarRole(.editor)` (back button without title); tested (HelloNavStack) |
| `toolbarBackground`, `toolbarColorScheme`, `toolbar(.hidden)` | ✅ | ≤17 | navigation bar background colour / visibility and colour scheme (tested, HelloNavStack); `toolbar(.hidden, for: .navigationBar / .tabBar / .bottomBar)` (tested, HelloLists, HelloTabs); bottom bar background |
| `TabView` (tab bar, `.tabItem`, `.badge`, selection) | ✅ | ≤17 | material tab bar, SF Symbol items, badges, selection, iOS 18 `Tab`; tested |
| `TabView` `.tabViewStyle(.page)` | ✅ | ≤17 | swipe paging with page dots; tested |
| `.sheet(isPresented:)` / `.sheet(item:)` | ✅ | ≤17 | page sheet with swipe-down dismiss; content gets the environment + `dismiss`; tested (HelloPresentations) |
| `.fullScreenCover` | ✅ | ≤17 | slides up full screen (zoom with `navigationTransition`); tested |
| `.popover` | ✅ | ≤17 | an anchored popover with its arrow on `arrowEdge`, sized to the content (iPad); on iPhone a sheet, or a popover with `presentationCompactAdaptation(.popover / .none)`; `popover(item:)`; tested (HelloSheets) |
| `.alert` | ✅ | ≤17 | title, message, button roles (UIAlertController); `TextField` / `SecureField` actions become the alert's text fields (the bindings get the text before the action runs); tested (HelloPresentations, HelloSheets) |
| `.confirmationDialog` | ✅ | ≤17 | action sheet with Cancel; tested |
| `presentationDetents`, `presentationDragIndicator`, `interactiveDismissDisabled` | ✅ | ≤17 | adapted: sheets with detents other than `.large` are isim-drawn cards (`.medium`, `.large`, `.fraction`, `.height`; drag between detents or down to dismiss; selection binding); `interactiveDismissDisabled` keeps them on taps outside and drags; `presentationBackgroundInteraction(.enabled / .enabled(upThrough:))`: no dimming, the page behind takes taps; `presentationCornerRadius`, `presentationBackground`; tested (HelloLists, HelloPickers, HelloSheets). `presentationContentInteraction` stored |
| `@Environment(\.dismiss)` | ✅ | ≤17 | closes sheets / covers (tested, HelloPresentations), pops navigation levels and resets `navigationDestination` bindings (tested, HelloLists) |
| `.searchable` | ✅ | ≤17 | search field under the List's large title (above other content), Cancel, `isSearching`, `dismissSearch`, `.onSubmit(of: .search)`; filtering and Cancel tested (HelloLists); `searchSuggestions` (shown in place of the results while searching; `searchCompletion` fills the field) and `searchScopes` (segmented scope bar, `activation:`) tested (HelloNavStack) |
| `.refreshable` | ✅ | ≤17 | pull past 60 pt and release: spinner while the async action runs (List tested, HelloLists; ScrollView unverified) |
| `.inspector` | ✅ | 17.0 | iPad: a trailing column beside the content (`inspectorColumnWidth`; tested, HelloSheets); iPhone: a sheet, as in compact width (tested, HelloKeys) |
| `@Environment(\.openURL)` | ✅ | ≤17 | |
| `Tab(_:systemImage:value:role:)`, `TabRole.search` | ✅ | 18.0 | with `--os 26`/`27` the search tab sits apart on its own glass circle; selected, the bar turns into a circle with the tab to go back to and the search tab's `.searchable` field on glass (its text, prompt, submit and `isSearching`), riding above the keyboard; with 18 an ordinary tab. Tested (HelloOSVersions, HelloTabs) |
| `TabRole.prominent` | ✅ | 27.0 | apart at the trailing end on a glass circle tinted with the tab view's tint, its icon white. Tested (HelloTabs, `--os 27`) |
| `TabSection`, `.sidebarAdaptable` sidebar, `tabViewCustomization` | ✅ | 18.0 | `TabSection` (flat in the tab bar; headed groups in the sidebar); `.sidebarAdaptable` on iPad: a sidebar button by the top tab bar shows the sidebar; `tabViewCustomization` (`TabViewCustomization`: tab sidebar / tab bar visibility, section tab order, resets; Codable, `@AppStorage`) with `customizationID`, `customizationBehavior`, `defaultVisibility`: the sidebar's Edit mode hides tabs (a check circle; hidden from the sidebar and the tab bar) and moves them within their section (a handle), the tab bar and sidebar follow. Adapted: no dragging tabs into the tab bar. Tested (HelloTabs) |
| `navigationTransition(_:)` (`.automatic`, `.zoom(sourceID:in:)`), `matchedTransitionSource(id:in:)` | ✅ | 18.0 | adapted: `.zoom` grows the pushed level / full-screen cover out of the source view and shrinks it back on pop / dismiss (no morphing of the source); tested (HelloNavStack, HelloSheets). Sheets keep their slide |
| `NavigationTransition.crossFade` | ✅ | 27.0 | the pushed level fades in, the popped one out (unverified) |
| `presentationSizing` (`.form`, `.page`, `.fitted`) | ✅ | 18.0 | iPad: a centred form card, the page card, or a form card sized to the content; iPhone: page sheets, like iOS; `.form` tested (HelloSheets) |
| `tabBarMinimizeBehavior`, `tabViewBottomAccessory` | ✅ | 26.0 | the accessory is a glass capsule above the floating tab bar (`tabViewBottomAccessoryPlacement` `.expanded`); `.onScrollDown` / `.onScrollUp` shrink the bar to the selected tab's circle while the selected tab is dragged (the accessory moves beside it, `.inline`); tapping the circle expands it; tested (HelloTabs) |
| `ToolbarSpacer` | ✅ | 26.0 | splits toolbar groups (iOS 26+: one glass capsule per group); fixed 8 pt or flexible; tested (HelloTabs) |
| `visibilityPriority(_:)` on toolbar content, `ToolbarItemVisibilityPriority` | ✅ | 27.0 | trailing items that do not fit move to an overflow ("…") menu, lowest priority first; tested (HelloTabs) |
| `ToolbarOverflowMenu` | ✅ | 27.0 | its content joins the overflow menu with the items that did not fit; tested (HelloTabs) |
| `ToolbarItemPlacement.topBarPinnedTrailing` | ✅ | 27.0 | at the trailing edge, never moved to the overflow menu; tested (HelloTabs) |
| `toolbarMinimizationBehavior(_:for:)` | ✅ | 27.0 | while the content is dragged: the bottom bar slides away, the navigation bar fades; tested (HelloTabs) |
| `ReadableDocument` / `WritableDocument` (URL-based documents) | ✅ | 27.0 | `ReadableDocument`, `WritableDocument`, `Document`, `DocumentReader` / `DocumentWriter`, `FileWrapperDocumentReader` / `FileWrapperDocumentWriter`, `DocumentReadConfiguration` / `DocumentWriteConfiguration`, `URLDocumentConfiguration`, `DocumentCreationContext` / `DocumentCreationSource`, `DocumentGroup(allowCreating:editor:makeDocument:)` and `(viewer:makeReadableDocument:)` (signatures from Apple's documentation; `@ContentBuilder` closures are `@ViewBuilder`): the document is made and read when it opens (reader, then `apply(snapshot:previous:)`), saves take a snapshot for the writer with the previous one. Not provided: `makeFileCoordinator()` (no `NSFileCoordinator`), the SwiftData forms. Tested (HelloDocumentGroup, `--os 27`) |
| `ArrangementView`, `ArrangementViewStyle` (`.automatic`, `.split` / `axes(_:)`, `.overlay`, custom styles), `splitArrangementLayoutRatio` / `splitArrangementLayoutSize` / `splitArrangementFixedLayoutSize`, `overlayArrangementEdge`; reserved regions, hinge, vertical toolbars | 🟡 | 27.1 | iOS 27.1 (beta) APIs for foldable iPhones, as they behave on isim's devices, none of which folds. Adapted: the split style stacks primary over secondary in compact width portrait and puts them side by side otherwise (within `axes`), the view with the higher `layoutPriority` sized first from its ratio, size or ideal size and the other taking the rest (halves when neither asks); the overlay style fills both, the primary on top, and never turns side by side, so `overlayArrangementEdge` has no effect; custom styles get the configuration's primary and secondary. Missing (iOS 27.1): SwiftUI's own `DeviceHinge` / `DeviceHingeContext` / `onHingeChange`, `GeometryProxy.reservedRegions`, `toolbarVerticalBehavior` / `toolbarVerticalCompressionBehavior` / `ToolbarItemAxisBehavior` / `toolbarVerticalEdge`, `splitArrangementAxis`, `overlayArrangementZIndex`, `CameraCaptureAccessory`. Tested (HelloSwiftUIArrangements, iPhone 17 and iPad Pro under iOS 27.1) |

### Modifiers & visual effects

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `font`, `foregroundColor`, `foregroundStyle` (Color, `.primary`…`.quaternary`, `.tint`) | ✅ | ≤17 | |
| `tint`, `accentColor` | ✅ | ≤17 | |
| `opacity`, `hidden`, `disabled` | ✅ | ≤17 | |
| `cornerRadius`, `clipShape` (any shape; built-in shapes as a rounded clip, others clip to their path) | ✅ | ≤17 | custom-shape clip tested (HelloDrawing) |
| `clipped()` | ✅ | ≤17 | clips to the frame; tested (HelloEffects) |
| `mask` | ✅ | ≤17 | a shape clips to its path; any other view masks by its alpha (gradients, text, images); tested (HelloEffects) |
| `shadow` | ✅ | ≤17 | a blurred, offset shadow of the content's shape (its alpha), not of the frame; tested (HelloEffects) |
| `rotationEffect`, `scaleEffect`, `offset` | ✅ | ≤17 | offset content is drawn and hit-tested at its new position |
| `transformEffect` | ✅ | ≤17 | |
| `rotation3DEffect` | ✅ | ≤17 | true perspective: the rotated corners define a homography drawn through the view's `transform3D` (y-axis rotation tested) |
| `projectionEffect`, `ProjectionTransform` | ✅ | ≤17 | non-affine transforms drawn with perspective through `transform3D` (unverified) |
| `GeometryEffect` (custom, animatable), `ignoredByLayout` | ✅ | ≤17 | custom shear tested |
| `blur`, `brightness`, `contrast`, `saturation`, `grayscale`, `colorMultiply`, `hueRotation`, `colorInvert`, `luminanceToAlpha`, `blendMode` | ✅ | ≤17 | adapted (colour matrix, box blur, cairo blend operators; `plusDarker` ≈ multiply); animatable with `withAnimation`; tested (HelloEffects) |
| `drawingGroup`, `compositingGroup` | ✅ | ≤17 | the view renders as one group before its opacity, blend mode and effects; tested (HelloEffects) |
| `visualEffect(_:)` (`EmptyVisualEffect`, `VisualEffect`: offset, scale, rotation, 3D rotation, opacity, blur, colour effects), `GeometryProxy.frame(in: .scrollView)` | ✅ | 17.0 | evaluated from live geometry after each render and while an enclosing scroll view scrolls (layout unaffected); tested (HelloEffects) |
| `border(_:width:)` | ✅ | ≤17 | drawn inside the frame |
| `allowsHitTesting` | ✅ | ≤17 | |
| `contentShape` | ✅ | ≤17 | touches only inside the shape, including empty areas of it (`.interaction` kind; other kinds accepted); tested (HelloEffects) |
| `id(_:)` | ✅ | ≤17 | resets state |
| `tag` | ✅ | ≤17 | explicit, and implicit from ForEach ids |
| `statusBarHidden`, `preferredColorScheme` | ✅ | ≤17 | |
| `persistentSystemOverlays`, `defersSystemGestures` | ✅ | ≤17 | `.hidden`: the home indicator fades 2 s after the last touch and returns on a touch; deferred bottom edge: the first swipe up goes to the app, a second one goes home (device shell); tested (HelloEffects) |
| `sensoryFeedback` | ✅ | 17.0 | adapted: like the iOS Simulator there are no haptics; the matching UIKit feedback generator runs and logs `isim: haptic …` (trigger, condition and closure forms); tested (HelloEffects) |
| `keyboardType`, `autocorrectionDisabled`, `textInputAutocapitalization`, `submitLabel` | ✅ | ≤17 | the keyboard type picks the layout (see UIKit) |
| `textFieldStyle`, `labelStyle` | ✅ | ≤17 | `.roundedBorder` / `.plain` fields; `.iconOnly` / `.titleOnly` / `.titleAndIcon` and custom `LabelStyle`s; tested (HelloPickers) |
| `pickerStyle`, `datePickerStyle`, `progressViewStyle`, `gaugeStyle` | ✅ | ≤17 | see the controls above; tested (HelloForms, HelloPickers) |
| `ViewModifier`, `.modifier` | ✅ | ≤17 | |
| `redacted`, `privacySensitive` | ✅ | ≤17 | `.placeholder` draws text as grey bars and images as grey boxes (tested, HelloPickers); `privacySensitive` content is redacted under `.redacted(reason: .privacy)` (tested, HelloEffects) |
| `badge`, `help`, `contextMenu` | ✅ | ≤17 | `badge` on tabs and list rows, `contextMenu` (long press -> pop-up menu) tested (HelloLists); `contextMenu(menuItems:preview:)` lifts the preview over a dimmed screen with the menu under it (tested, HelloEffects); `help` is the accessibility hint (no tooltips on iPhone) |
| `glassEffect(_:in:)`, `Glass` (`.regular`, `.clear`, `.identity`, `tint`, `interactive`) | ✅ | 26.0 | adapted: isim's Liquid Glass drawing behind the view (the backdrop lightly blurred and refracted near the rim — lensing — a translucent, tinted body, top glow and specular rim) in rectangles, rounded rectangles, circles, capsules (other shapes: a capsule); interactive glass grows a little and brightens while touched, without taking the touch from the controls under it. Tested (HelloOSVersions, HelloTabs) |
| `GlassEffectContainer`, `glassEffectID`, `glassEffectUnion`, `glassEffectTransition` (`matchedGeometry`, `materialize`, `identity`) | ✅ | 26.0 | adapted: the container draws its glass shapes together as one signed distance field: shapes closer than its spacing flow into one another (smooth union) and morph frame by frame as they move; shapes with the same union id draw as one shape over their bounding box. Inserted or removed with an animation, a shape with a `glassEffectID` grows out of the shape with the same id or the nearest one and shrinks back into it (`matchedGeometry`), fades in place (`materialize`) or pops (`identity`), timed by the view's own transition. Merged groups show in view dumps as `isim-glass-union-N`. Tested (HelloTabs: merging, union, morphing in and out mid-animation) |
| `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)` | ✅ | 26.0 | glass capsule (prominent: tinted, white label); bordered styles become capsules with `--os 26`/`27`; the glass is interactive (grows and brightens while pressed). Adapted; tested (HelloOSVersions) |
| `scrollEdgeEffectStyle(_:for:)`, `scrollEdgeEffectHidden`, `backgroundExtensionEffect()` | ✅ | 26.0 | adapted: `.hard` gives the scrolled navigation / bottom bar an opaque edge with a divider, `.soft` the fade, hidden none (tested, HelloTabs); background extension: blurred mirror images of the view fill the safe area beside it (under the status bar, beside it in landscape), behind the content; tested (HelloTabs) |
| `Animatable()` macro, `Slider` tick marks, `TextEditor` with `AttributedString` | ✅ | 26.0 | `@Animatable` / `@AnimatableIgnored` (isim's SwiftUIMacros plugin: `animatableData` from the stored vars; tested, HelloContainers); `Slider` ticks (`SliderTick`, `SliderTickBuilder`, `SliderTickContentForEach`, `ticks:` / `tick:`; a stepped slider shows its steps), `neutralValue`, `enabledBounds` on UIKit's slider track configuration (tick labels accepted, not drawn, like UIKit's titles); `TextEditor(text: Binding<AttributedString>, selection:)`: runs drawn with their SwiftUI / Foundation attributes, typing takes the attributes before it, `AttributedTextSelection` follows and sets the selection (no formatting menu). Tested (HelloSwiftUIControls, OS matrix) |
| `swipeActionsContainer()`, `swipeActions` on any view (iOS 27 form), `reorderable()`, `reorderContainer(for:isEnabled:move:)` | ✅ | 27.0 | `swipeActions` on a view outside a List: dragging reveals the actions (full swipe runs the first); `swipeActionsContainer()` keeps one open at a time; tested (HelloEffects). Reordering in stacks, grids and layouts: `reorderable()` / `reorderable(collectionID:)` on a ForEach, `reorderContainer(for:isEnabled:move:)` and the `in:` / `itemID:` forms, `ReorderDifference` (sources, destination before an item or at the end of a collection); adapted: a long press lifts the item (scaled, with a shadow) and it follows the finger, the other items of its collection make room, the drop calls `move` (animated); between collections the target collection does not make room; `DropSession.reorderDestination` missing. Tested (HelloContainers, `--os 27`) |
| `asyncImageURLSession(_:)`, `AsyncImage(request:)` | ✅ | 27.0 | AsyncImages inside load with the given session; the request initializers load the `URLRequest`; tested (HelloTabs) |

### Shapes, paths, gradients & materials

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `Rectangle`, `RoundedRectangle`, `Circle`, `Capsule` | ✅ | ≤17 | color fills use a view with a corner radius; other paints draw the path |
| Custom `Shape` (`path(in:)`) | ✅ | ≤17 | shape inits and `path(in:)` are not main-actor isolated, like SwiftUI |
| `Path` (move/line/quad/curve, `addArc` (center and tangent forms), `addRelativeArc`, rects, rounded rects, ellipses, `Path { }`, `Path(CGPath)`, `cgPath`) | ✅ | ≤17 | arcs become cubic curves |
| `Path` queries (`boundingRect`, `contains(_:eoFill:)`, `trimmedPath`, `applying`, `offsetBy`, string form) | ✅ | ≤17 | |
| `Path.strokedPath`, boolean operations (`union`, `intersection`, …), `Shape.union` etc. | ✅ | ≤17 | adapted: curves are flattened (0.2 pt) and regions combined by a slab sweep into polygon outlines: `union`, `intersection`, `subtracting`, `symmetricDifference`, `normalized` (both fill rules), `lineIntersection` / `lineSubtraction`; `strokedPath` outlines the stroke (width, caps, joins, miter limit, dashes); the same on shapes. Tested (HelloShapes) |
| `fill` (colors, any style, `FillStyle(eoFill:)`) | ✅ | ≤17 | |
| `stroke` / `stroke(style:)` with `StrokeStyle` (width, caps, joins, miter limit, dashes, dash phase) | ✅ | ≤17 | dashes tested; joins and miter limit unverified |
| `trim(from:to:)` | ✅ | ≤17 | exact on curves (arc length) |
| `Ellipse`, `UnevenRoundedRectangle` | ✅ | ≤17 | |
| `ContainerRelativeShape` | ✅ | ≤17 | the shape of the nearest `.containerShape(_:)`, made concentric (a rounded rectangle's radius minus the distance to the container's edge; other shapes inset); outside one, the frame's rectangle. Tested (HelloShapes) |
| `InsettableShape` (`inset(by:)`, `strokeBorder`) | ✅ | ≤17 | |
| `AnyShape` | ✅ | ≤17 | |
| Shape `.offset`, `.rotation`, `.scale`, `.transform`, `.size` | ✅ | ≤17 | offset and rotation tested; scale/transform/size unverified |
| `fill(_:).stroke(_:)` on a filled shape (iOS 17) | ✅ | ≤17 | the fill with the stroke centred on its edge. Tested (HelloShapes) |
| `LinearGradient`, `RadialGradient`, `AngularGradient` / `conicGradient`, `EllipticalGradient`, `Gradient` (colors, stops) | ✅ | ≤17 | as views and shape styles |
| Gradients in `fill`, `foregroundStyle`, `background`, `background(_:in:)`, `overlay` | ✅ | ≤17 | gradient strokes unverified |
| `Color.gradient` (`AnyGradient`) | ✅ | ≤17 | a top-to-bottom gradient a little lighter at the top (approximates Apple's) |
| Text with a gradient `foregroundStyle` | ✅ | ≤17 | the gradient (linear, radial, angular, any shape style) fills the glyphs, across the text's frame. Tested (HelloShapes, HelloDrawing) |
| `Material` (`.ultraThinMaterial` … `.bar`) | ✅ | ≤17 | real backdrop blur (UIVisualEffectView) |
| `Color` (system colors, RGB/HSB/white, `Color(uiColor:)`, asset colors) | ✅ | ≤17 | |
| `ImagePaint` (`.image(_:sourceRect:scale:)`) | ✅ | ≤17 | tiles fills; image strokes are not drawn |
| `Canvas` / `GraphicsContext` (fill/stroke paths with colors, styles and gradients, text, images, transforms, opacity, clip, `drawLayer`) | 🟡 | ≤17 | filters, blend modes, `clipToLayer` and symbols are accepted and not drawn. Missing: `addFilter` and `clipToLayer` do nothing, `resolveSymbol` returns nil (so `Canvas(symbols:)` content is not drawn) |
| Shaders (`ShaderLibrary`, `.colorEffect`, `.layerEffect`, `.distortionEffect`) | ❌ | ≤17 | need Metal, which isim does not have |
| `MeshGradient`, `Color.mix(with:by:)` | ✅ | 18.0 | adapted: the mesh is rasterized by isim (points or Bézier points, smooth Catmull-Rom or bilinear colours, background), as a view and a shape style; `Color.mix` in Oklab (`.perceptual`) or sRGB (`.device`); `Color.Resolved` / `resolve(in:)` (iOS 17). Tested (HelloShapes) |

### Animation

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `withAnimation` (incl. `completion:`) | ✅ | ≤17 | animates the next render (frames, opacity, transforms, colors) |
| `.animation(_:value:)` | ✅ | ≤17 | animates its subtree when the value changes |
| Curves & springs (`.easeInOut`, `.spring`, `.bouncy`, `.snappy`, `.smooth`, `timingCurve`, `interpolatingSpring`), repeat/delay/speed | ✅ | ≤17 | standard curves, exact cubic Bézier `timingCurve` / `UnitCurve`, damped springs from duration + bounce or mass / stiffness / damping (`Spring` values, velocity, settling duration), `repeatCount` (autoreversing plays) / `repeatForever`, delay, speed, on UIKit's animation engine. Tested (HelloShapes: positions over time) |
| Transitions (`.opacity`, `.scale`, `.slide`, `.move`, `.offset`, `.push`, `asymmetric`, `combined`) | ✅ | ≤17 | insertion and removal of each kind play from / to where the view is (not riding along with its container's change): fade, scale about the anchor, slide in from the leading edge and out to the trailing one, move from an edge, offset, push (moving and fading), asymmetric, combined; `.animation(_:)` on a transition. Tested (HelloShapes: positions, sizes and opacity over time) |
| `matchedGeometryEffect` | ✅ | ≤17 | an inserted view moves and scales from its match's frame while the removed one moves to the new frame, the two cross-fading; `isSource: false` views take the source's frame, position or size (`properties`, `anchor`) while both are on screen; `@Namespace` IDs stay the same across updates. Adapted: the size change is a scale of the content (laid out at its own size). Tested (HelloShapes) |
| `contentTransition` (`.numericText`, `.interpolate`) | ✅ | ≤17 | in an animated update, `.numericText` rolls the old text out (up, or down when counting down) and the new one in; `.opacity` / `.interpolate` cross-fade; `.symbolEffect` scales a replaced symbol; numeric text tested (HelloEffects) |
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
| `simultaneousGesture`, `highPriorityGesture`, `simultaneously(with:)`, `sequenced(before:)`, `exclusively(before:)`, `map` | ✅ | ≤17 | composition (magnify+rotate together, long press before drag, double tap before single); nested gestures compete like SwiftUI's: a view's gesture or tap wins over its parent's `.gesture` (which waits for it to fail), `highPriorityGesture` wins over the gestures and taps inside it, `simultaneousGesture` fires with them; `including:` masks (`.gesture`, `.subviews`, `.none`) and `isEnabled:`. Tested (HelloSwiftUIGestures) |
| `MagnifyGesture`, `RotateGesture` (+ `MagnificationGesture`, `RotationGesture`) | ✅ | ≤17 | two fingers from isim's multi-touch (Option-drag, script `pinch`/`rotate2`); magnification/rotation, velocity, start anchor/location; tested (HelloSwiftUIGestures) |
| `SpatialTapGesture` | ✅ | ≤17 | location in local/global space; tested (HelloSwiftUIGestures) |
| `sequenced`, `exclusively`, `simultaneously(with:)`, `.updating` | ✅ | ≤17 | built on UIKit recognizers; tested (HelloSwiftUIGestures) |

### Lifecycle, async & events

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `onAppear`, `onDisappear` | ✅ | ≤17 | |
| `.task`, `.task(id:)` | ✅ | ≤17 | cancelled on disappear |
| `onChange(of:)` (old/new, `initial:`) | ✅ | ≤17 | |
| `Scene.onChange(of:initial:)` (e.g. `scenePhase`) | ✅ | ≤17 | adapted: wraps the scene's root view in `onChange`; tested (HelloSourceCompat) |
| `onReceive` | ✅ | ≤17 | |
| `onSubmit` | ✅ | ≤17 | |
| `onKeyPress`, `keyboardShortcut` | ✅ | ≤17 | shortcuts on buttons become UIKeyCommands (incl. `defaultAction`/`cancelAction`); `onKeyPress` key/characters/phases forms: the handlers on the focused view and its ancestors get the presses, innermost first (none while nothing has focus); Tab / Shift-Tab not taken by a handler move focus. Tested (HelloKeys) |
| `onGeometryChange`, `onContinuousHover`, `onHover` | ✅ | ≤17 | `onGeometryChange` (size, frames in any coordinate space; tested, HelloLayout); `onHover` / `onContinuousHover` (location in a coordinate space, `.ended`) on UIKit's hover recognizer: the iPad pointer or the host mouse without a button (script `hover X Y`); `hoverEffect(.automatic / .highlight / .lift)` and `hoverEffectDisabled` as iPad pointer effects. Tested (HelloSwiftUIControls) |

### Focus & keyboard

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `focused(_:)`, `focused(_:equals:)` | ✅ | ≤17 | |
| `focusable`, `defaultFocus`, `focusSection` | ✅ | ≤17 | `.focusable()` views take focus (a tap, Tab, or their `.focused` binding) as the first responder and show a focus ring in the tint colour (`.focusEffectDisabled()` hides it); Tab / Shift-Tab move between focusable views and text fields in reading order, a `.focusSection()`'s items staying together; `defaultFocus` sets the focus binding on appear. Tested (HelloKeys) |
| `scrollDismissesKeyboard` | ✅ | ≤17 | the scroll views inside (ScrollView, List / Form, the attributed TextEditor) take the mode as UIKit's `keyboardDismissMode`: `.automatic` dismisses as soon as a drag scrolls (a TextEditor: interactively), like iOS 16 and later; `.immediately`, `.interactively` (adapted: the keyboard goes when the drag reaches it, it does not follow the finger), `.never`. Tested (HelloSwiftUIControls) |
| Form scrolls the focused field above the keyboard | ✅ | ≤17 | |

### Environment values

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `colorScheme`, `locale`, `font`, `isEnabled`, `lineLimit`, `multilineTextAlignment` | ✅ | ≤17 | |
| `horizontalSizeClass`, `verticalSizeClass`, `displayScale` | ✅ | ≤17 | |
| `layoutDirection` | ✅ | ≤17 | the app's direction (its localization, Xcode's right-to-left pseudolanguage, `ISIM_LAYOUT_DIRECTION`) or `.environment(\.layoutDirection, …)` for a subtree; right to left mirrors each container's placements like SwiftUI (stacks run right to left, leading alignment / padding / insets on the right, custom `Layout`s see `subviews.layoutDirection` and are mirrored), leading text aligns right, UIKit controls inside get the semantic direction, `flipsForRightToLeftLayoutDirection`. Content a view draws (text, images, shapes) is not mirrored. Tested (HelloSwiftUIControls: app-wide and in a subtree) |
| `calendar`, `timeZone`, `dynamicTypeSize`, `colorSchemeContrast` | ✅ | ≤17 | `dynamicTypeSize` and `colorSchemeContrast` follow Settings > Accessibility (Larger Text, Increase Contrast); text styles (`.body`, `.headline`, …) scale with Dynamic Type; tested (HelloAccessibility) |
| `editMode`, `isPresented`, `isSearching`, `presentationMode` | ✅ | ≤17 | `editMode` (a window-wide binding, or your own via `.environment`) and `isPresented` (tested, HelloLists); `isSearching` follows the search field of the enclosing `.searchable`; `presentationMode` (`isPresented`, `dismiss()`) in presented content; a dismissed presentation's views get `onDisappear` and their tasks are cancelled. Tested (HelloSwiftUIControls) |
| `accessibilityReduceMotion` and other accessibility values | ✅ | ≤17 | `accessibilityReduceMotion`, `accessibilityReduceTransparency`, `accessibilityDifferentiateWithoutColor`, `accessibilityVoiceOverEnabled`, `legibilityWeight` from Settings > Accessibility; tested (HelloAccessibility). `accessibilityInvertColors` always false |
| `requestReview` | ✅ | ≤17 | see StoreKit |

### Accessibility

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `accessibilityIdentifier` | ✅ | ≤17 | |
| `accessibilityLabel` | ✅ | ≤17 | stored on the UIKit view |
| `.draggable`, `.dropDestination`, `.onDrag`, `.onDrop` | ✅ | ≤17 | Transferable payloads / NSItemProviders through UIDragInteraction/UIDropInteraction (long press to lift); `isTargeted`; `preview:` views lift under the finger instead of the view (the lifting preview, see UIKit's `previewForLifting`). Tested (HelloDragDrop: String draggable with a custom preview → dropDestination) |
| `accessibilityHint`, `accessibilityHidden` | ✅ | ≤17 | set on the mounted UIKit view; VoiceOver reads hints and skips hidden views; tested (HelloAccessibility) |
| `accessibilityValue`, `accessibilityAddTraits`, `accessibilityElement(children:)`, `accessibilityAction`, `accessibilityAdjustableAction`, `accessibilitySortPriority` | ✅ | ≤17 | feed the UIKit accessibility tree (value, traits, `.combine`/`.ignore` label from the children's text, `.contain` grouping, default and named actions, adjustable increments, sort priority); tested (HelloAccessibility: value, header trait, combine, adjustable, hidden; HelloSwiftUIControls: sort priority, named actions through VoiceOver's action and Actions rotor) |

### UIKit interop

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `UIViewRepresentable` (coordinator, update, dismantle) | ✅ | ≤17 | |
| `UIViewControllerRepresentable` | ✅ | ≤17 | |
| `UIHostingController` in UIKit apps | ✅ | ≤17 | |
| `sizeThatFits(_:uiView:context:)` on representables | ✅ | ≤17 | also `sizeThatFits(_:uiViewController:context:)`; tested (HelloKeys) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
2826 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`AccessibilityActionCategory`](https://developer.apple.com/documentation/swiftui/accessibilityactioncategory)
- [`static let `default`: AccessibilityActionCategory`](https://developer.apple.com/documentation/swiftui/accessibilityactioncategory/default)
- [`static let edit: AccessibilityActionCategory`](https://developer.apple.com/documentation/swiftui/accessibilityactioncategory/edit)
- [`init(_:)`](https://developer.apple.com/documentation/swiftui/accessibilityactioncategory/init(_:))
- [`AccessibilityAttachmentModifier`](https://developer.apple.com/documentation/swiftui/accessibilityattachmentmodifier)
- [`AccessibilityCustomContentKey`](https://developer.apple.com/documentation/swiftui/accessibilitycustomcontentkey)
- [`init(_:)`](https://developer.apple.com/documentation/swiftui/accessibilitycustomcontentkey/init(_:))
- [`init(_:id:)`](https://developer.apple.com/documentation/swiftui/accessibilitycustomcontentkey/init(_:id:))
- [`AccessibilityDirectTouchOptions`](https://developer.apple.com/documentation/swiftui/accessibilitydirecttouchoptions)
- [`init(rawValue: AccessibilityDirectTouchOptions.RawValue)`](https://developer.apple.com/documentation/swiftui/accessibilitydirecttouchoptions/init(rawvalue:))
- [`static let requiresActivation: AccessibilityDirectTouchOptions`](https://developer.apple.com/documentation/swiftui/accessibilitydirecttouchoptions/requiresactivation)
- [`static let silentOnTouch: AccessibilityDirectTouchOptions`](https://developer.apple.com/documentation/swiftui/accessibilitydirecttouchoptions/silentontouch)
- [`AccessibilityFocusState`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate)
- [`AccessibilityFocusState.Binding`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate/binding)
- [`var projectedValue: AccessibilityFocusState<Value>.Binding`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate/binding/projectedvalue)
- [`var wrappedValue: Value`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate/binding/wrappedvalue)
- [`init()`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate/init())
- [`init(for:)`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate/init(for:))
- [`var projectedValue: AccessibilityFocusState<Value>.Binding`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate/projectedvalue)
- [`var wrappedValue: Value`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate/wrappedvalue)
- [`AccessibilityHeadingLevel`](https://developer.apple.com/documentation/swiftui/accessibilityheadinglevel)
- [`case h1`](https://developer.apple.com/documentation/swiftui/accessibilityheadinglevel/h1)
- [`case h2`](https://developer.apple.com/documentation/swiftui/accessibilityheadinglevel/h2)
- [`case h3`](https://developer.apple.com/documentation/swiftui/accessibilityheadinglevel/h3)
- [`case h4`](https://developer.apple.com/documentation/swiftui/accessibilityheadinglevel/h4)
- [`case h5`](https://developer.apple.com/documentation/swiftui/accessibilityheadinglevel/h5)
- [`case h6`](https://developer.apple.com/documentation/swiftui/accessibilityheadinglevel/h6)
- [`case unspecified`](https://developer.apple.com/documentation/swiftui/accessibilityheadinglevel/unspecified)
- [`AccessibilityLabeledPairRole`](https://developer.apple.com/documentation/swiftui/accessibilitylabeledpairrole)
- [`case content`](https://developer.apple.com/documentation/swiftui/accessibilitylabeledpairrole/content)
- [`case label`](https://developer.apple.com/documentation/swiftui/accessibilitylabeledpairrole/label)
- [`AccessibilityRotorContent`](https://developer.apple.com/documentation/swiftui/accessibilityrotorcontent)
- [`Body`](https://developer.apple.com/documentation/swiftui/accessibilityrotorcontent/body-swift.associatedtype)
- [`var body: Self.Body`](https://developer.apple.com/documentation/swiftui/accessibilityrotorcontent/body-swift.property)
- [`AccessibilityRotorContentBuilder`](https://developer.apple.com/documentation/swiftui/accessibilityrotorcontentbuilder)
- [`static buildBlock(_:)`](https://developer.apple.com/documentation/swiftui/accessibilityrotorcontentbuilder/buildblock(_:))
- [`static func buildExpression<Content>(Content) -> Content`](https://developer.apple.com/documentation/swiftui/accessibilityrotorcontentbuilder/buildexpression(_:))
- [`static func buildIf<Content>(Content?) -> some AccessibilityRotorContent`](https://developer.apple.com/documentation/swiftui/accessibilityrotorcontentbuilder/buildif(_:))
- [`AccessibilityRotorEntry`](https://developer.apple.com/documentation/swiftui/accessibilityrotorentry)
- [`init<L>(L, ID, in: Namespace.ID, textRange: Range<String.Index>?, prepare: () -> Void)`](https://developer.apple.com/documentation/swiftui/accessibilityrotorentry/init(_:_:in:textrange:prepare:))
- [`init(_:id:in:textRange:prepare:)`](https://developer.apple.com/documentation/swiftui/accessibilityrotorentry/init(_:id:in:textrange:prepare:))
- [`init(_:id:textRange:prepare:)`](https://developer.apple.com/documentation/swiftui/accessibilityrotorentry/init(_:id:textrange:prepare:))
- [`init(_:textRange:prepare:)`](https://developer.apple.com/documentation/swiftui/accessibilityrotorentry/init(_:textrange:prepare:))
- [`AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor)
- [`static var boldText: AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/boldtext)
- [`static var headings: AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/headings)
- [`static func headings(level: AccessibilityHeadingLevel) -> AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/headings(level:))
- [`static var images: AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/images)
- [`static var italicText: AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/italictext)
- [`static var landmarks: AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/landmarks)
- [`static var links: AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/links)
- [`static func links(visited: Bool) -> AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/links(visited:))
- [`static var lists: AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/lists)
- [`static var misspelledWords: AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/misspelledwords)
- [`static var tables: AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/tables)
- [`static var textFields: AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/textfields)
- [`static var underlineText: AccessibilitySystemRotor`](https://developer.apple.com/documentation/swiftui/accessibilitysystemrotor/underlinetext)
- [`AccessibilityTechnologies`](https://developer.apple.com/documentation/swiftui/accessibilitytechnologies)
- [`init()`](https://developer.apple.com/documentation/swiftui/accessibilitytechnologies/init())
- [`static let switchControl: AccessibilityTechnologies`](https://developer.apple.com/documentation/swiftui/accessibilitytechnologies/switchcontrol)
- [`static let voiceOver: AccessibilityTechnologies`](https://developer.apple.com/documentation/swiftui/accessibilitytechnologies/voiceover)
- [`AccessibilityTextContentType`](https://developer.apple.com/documentation/swiftui/accessibilitytextcontenttype)
- [`static let console: AccessibilityTextContentType`](https://developer.apple.com/documentation/swiftui/accessibilitytextcontenttype/console)
- [`static let fileSystem: AccessibilityTextContentType`](https://developer.apple.com/documentation/swiftui/accessibilitytextcontenttype/filesystem)
- [`static let messaging: AccessibilityTextContentType`](https://developer.apple.com/documentation/swiftui/accessibilitytextcontenttype/messaging)
- [`static let narrative: AccessibilityTextContentType`](https://developer.apple.com/documentation/swiftui/accessibilitytextcontenttype/narrative)
- [`static let plain: AccessibilityTextContentType`](https://developer.apple.com/documentation/swiftui/accessibilitytextcontenttype/plain)
- [`static let sourceCode: AccessibilityTextContentType`](https://developer.apple.com/documentation/swiftui/accessibilitytextcontenttype/sourcecode)
- [`static let spreadsheet: AccessibilityTextContentType`](https://developer.apple.com/documentation/swiftui/accessibilitytextcontenttype/spreadsheet)
- [`static let wordProcessing: AccessibilityTextContentType`](https://developer.apple.com/documentation/swiftui/accessibilitytextcontenttype/wordprocessing)
- [`static let isTabBar: AccessibilityTraits`](https://developer.apple.com/documentation/swiftui/accessibilitytraits/istabbar)
- [`AccessibilityZoomGestureAction`](https://developer.apple.com/documentation/swiftui/accessibilityzoomgestureaction)
- [`AccessibilityZoomGestureAction.Direction`](https://developer.apple.com/documentation/swiftui/accessibilityzoomgestureaction/direction-swift.enum)
- [`case zoomIn`](https://developer.apple.com/documentation/swiftui/accessibilityzoomgestureaction/direction-swift.enum/zoomin)
- [`case zoomOut`](https://developer.apple.com/documentation/swiftui/accessibilityzoomgestureaction/direction-swift.enum/zoomout)
- [`let direction: AccessibilityZoomGestureAction.Direction`](https://developer.apple.com/documentation/swiftui/accessibilityzoomgestureaction/direction-swift.property)
- [`let location: UnitPoint`](https://developer.apple.com/documentation/swiftui/accessibilityzoomgestureaction/location)
- [`let point: CGPoint`](https://developer.apple.com/documentation/swiftui/accessibilityzoomgestureaction/point)
- [`ActionSheet`](https://developer.apple.com/documentation/swiftui/actionsheet)
- [`ActionSheet.Button`](https://developer.apple.com/documentation/swiftui/actionsheet/button)
- [`init(title: Text, message: Text?, buttons: [ActionSheet.Button])`](https://developer.apple.com/documentation/swiftui/actionsheet/init(title:message:buttons:))
- [`Alert`](https://developer.apple.com/documentation/swiftui/alert)
- [`Alert.Button`](https://developer.apple.com/documentation/swiftui/alert/button)
- [`static func cancel((() -> Void)?) -> Alert.Button`](https://developer.apple.com/documentation/swiftui/alert/button/cancel(_:))
- [`static func cancel(Text, action: (() -> Void)?) -> Alert.Button`](https://developer.apple.com/documentation/swiftui/alert/button/cancel(_:action:))
- [`static func `default`(Text, action: (() -> Void)?) -> Alert.Button`](https://developer.apple.com/documentation/swiftui/alert/button/default(_:action:))
- [`static func destructive(Text, action: (() -> Void)?) -> Alert.Button`](https://developer.apple.com/documentation/swiftui/alert/button/destructive(_:action:))
- [`init(title: Text, message: Text?, dismissButton: Alert.Button?)`](https://developer.apple.com/documentation/swiftui/alert/init(title:message:dismissbutton:))
- [`init(title: Text, message: Text?, primaryButton: Alert.Button, secondaryButton: Alert.Button)`](https://developer.apple.com/documentation/swiftui/alert/init(title:message:primarybutton:secondarybutton:))
- [`static var centerFirstTextBaseline: Alignment`](https://developer.apple.com/documentation/swiftui/alignment/centerfirsttextbaseline)
- [`static var centerLastTextBaseline: Alignment`](https://developer.apple.com/documentation/swiftui/alignment/centerlasttextbaseline)
- [`static var leadingFirstTextBaseline: Alignment`](https://developer.apple.com/documentation/swiftui/alignment/leadingfirsttextbaseline)
- [`static var leadingLastTextBaseline: Alignment`](https://developer.apple.com/documentation/swiftui/alignment/leadinglasttextbaseline)
- [`static var trailingFirstTextBaseline: Alignment`](https://developer.apple.com/documentation/swiftui/alignment/trailingfirsttextbaseline)
- [`static var trailingLastTextBaseline: Alignment`](https://developer.apple.com/documentation/swiftui/alignment/trailinglasttextbaseline)
- [`init(_:)`](https://developer.apple.com/documentation/swiftui/anchor/source/init(_:))
- [`AnimatableValues`](https://developer.apple.com/documentation/swiftui/animatablevalues)
- [`init(repeat each Value)`](https://developer.apple.com/documentation/swiftui/animatablevalues/init(_:))
- [`var magnitudeSquared: Double`](https://developer.apple.com/documentation/swiftui/animatablevalues/magnitudesquared)
- [`var value: (repeat each Value)`](https://developer.apple.com/documentation/swiftui/animatablevalues/value)
- [`func animate<V>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V?`](https://developer.apple.com/documentation/swiftui/animation/animate(value:time:context:))
- [`var base: any CustomAnimation`](https://developer.apple.com/documentation/swiftui/animation/base)
- [`init<A>(A)`](https://developer.apple.com/documentation/swiftui/animation/init(_:))
- [`func logicallyComplete(after: TimeInterval) -> Animation`](https://developer.apple.com/documentation/swiftui/animation/logicallycomplete(after:))
- [`func shouldMerge<V>(previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext<V>) -> Bool`](https://developer.apple.com/documentation/swiftui/animation/shouldmerge(previous:value:time:context:))
- [`func velocity<V>(value: V, time: TimeInterval, context: AnimationContext<V>) -> V?`](https://developer.apple.com/documentation/swiftui/animation/velocity(value:time:context:))
- [`AnimationContext`](https://developer.apple.com/documentation/swiftui/animationcontext)
- [`var environment: EnvironmentValues`](https://developer.apple.com/documentation/swiftui/animationcontext/environment)
- [`var isLogicallyComplete: Bool`](https://developer.apple.com/documentation/swiftui/animationcontext/islogicallycomplete)
- [`var state: AnimationState<Value>`](https://developer.apple.com/documentation/swiftui/animationcontext/state)
- [`func withState<T>(AnimationState<T>) -> AnimationContext<T>`](https://developer.apple.com/documentation/swiftui/animationcontext/withstate(_:))
- [`AnimationState`](https://developer.apple.com/documentation/swiftui/animationstate)
- [`init()`](https://developer.apple.com/documentation/swiftui/animationstate/init())
- [`subscript<K>(K.Type) -> K.Value`](https://developer.apple.com/documentation/swiftui/animationstate/subscript(_:))
- [`AnimationStateKey`](https://developer.apple.com/documentation/swiftui/animationstatekey)
- [`static var defaultValue: Self.Value`](https://developer.apple.com/documentation/swiftui/animationstatekey/defaultvalue)
- [`Value`](https://developer.apple.com/documentation/swiftui/animationstatekey/value)
- [`func colorSpace(Gradient.ColorSpace) -> AnyGradient`](https://developer.apple.com/documentation/swiftui/anygradient/colorspace(_:))
- [`AnyNavigationTransition`](https://developer.apple.com/documentation/swiftui/anynavigationtransition)
- [`init(some NavigationTransition)`](https://developer.apple.com/documentation/swiftui/anynavigationtransition/init(_:))
- [`AnyScrollTargetBehavior`](https://developer.apple.com/documentation/swiftui/anyscrolltargetbehavior)
- [`var base: any ScrollTargetBehavior`](https://developer.apple.com/documentation/swiftui/anyscrolltargetbehavior/base)
- [`init(some ScrollTargetBehavior)`](https://developer.apple.com/documentation/swiftui/anyscrolltargetbehavior/init(_:))
- [`AnyTabContent`](https://developer.apple.com/documentation/swiftui/anytabcontent)
- [`init<T>(T)`](https://developer.apple.com/documentation/swiftui/anytabcontent/init(_:))
- [`init<T>(T)`](https://developer.apple.com/documentation/swiftui/anytransition/init(_:))
- [`static func modifier<E>(active: E, identity: E) -> AnyTransition`](https://developer.apple.com/documentation/swiftui/anytransition/modifier(active:identity:))
- [`AssistiveAccess`](https://developer.apple.com/documentation/swiftui/assistiveaccess)
- [`init(content: () -> Content)`](https://developer.apple.com/documentation/swiftui/assistiveaccess/init(content:))
- [`AsymmetricTransition`](https://developer.apple.com/documentation/swiftui/asymmetrictransition)
- [`init(insertion: Insertion, removal: Removal)`](https://developer.apple.com/documentation/swiftui/asymmetrictransition/init(insertion:removal:))
- [`var insertion: Insertion`](https://developer.apple.com/documentation/swiftui/asymmetrictransition/insertion)
- [`var removal: Removal`](https://developer.apple.com/documentation/swiftui/asymmetrictransition/removal)
- [`AttributedTextFormatting`](https://developer.apple.com/documentation/swiftui/attributedtextformatting)
- [`AttributedTextFormatting.AnyDefinition`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/anydefinition)
- [`init<D>(D)`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/anydefinition/init(_:))
- [`AttributedTextFormatting.AttributeContainerProxy`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/attributecontainerproxy)
- [`AttributedTextFormatting.AttributeContainerProxy.Scoped`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/attributecontainerproxy/scoped)
- [`subscript(dynamicMember:)`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/attributecontainerproxy/scoped/subscript(dynamicmember:))
- [`subscript(_:)`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/attributecontainerproxy/subscript(_:))
- [`subscript(dynamicMember:)`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/attributecontainerproxy/subscript(dynamicmember:))
- [`AttributedTextFormatting.DefinitionBuilder`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/definitionbuilder)
- [`static func buildBlock<S>() -> AttributedTextFormatting.EmptyDefinition<S>`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/definitionbuilder/buildblock())
- [`static func buildBlock<D>(D) -> D`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/definitionbuilder/buildblock(_:))
- [`static func buildBlock<F, each D>(F, repeat each D) -> AttributedTextFormatting.TupleDefinition<F.Scope, F, repeat each D>`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/definitionbuilder/buildblock(_:_:))
- [`static func buildEither<T, F>(first: T) -> _ConditionalContent<T, F>`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/definitionbuilder/buildeither(first:))
- [`static func buildEither<T, F>(second: F) -> _ConditionalContent<T, F>`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/definitionbuilder/buildeither(second:))
- [`static func buildExpression<D>(D) -> D`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/definitionbuilder/buildexpression(_:))
- [`static func buildIf<D>(D?) -> D?`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/definitionbuilder/buildif(_:))
- [`static func buildLimitedAvailability<D>(D) -> AttributedTextFormatting.AnyDefinition<Scope>`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/definitionbuilder/buildlimitedavailability(_:))
- [`AttributedTextFormatting.EmptyDefinition`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/emptydefinition)
- [`init()`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/emptydefinition/init())
- [`AttributedTextFormatting.Transferable`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/transferable)
- [`init(text: AttributedString, in: EnvironmentValues)`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/transferable/init(text:in:))
- [`AttributedTextFormatting.TupleDefinition`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/tupledefinition)
- [`init(definition: repeat each Definition)`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/tupledefinition/init(definition:))
- [`AttributedTextFormatting.ValueConstraint`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/valueconstraint)
- [`init(for:values:default:)`](https://developer.apple.com/documentation/swiftui/attributedtextformatting/valueconstraint/init(for:values:default:))
- [`AttributedTextFormattingDefinition`](https://developer.apple.com/documentation/swiftui/attributedtextformattingdefinition)
- [`var body: Self.Body`](https://developer.apple.com/documentation/swiftui/attributedtextformattingdefinition/body-1b01t)
- [`var body: Self`](https://developer.apple.com/documentation/swiftui/attributedtextformattingdefinition/body-48m9l)
- [`Body`](https://developer.apple.com/documentation/swiftui/attributedtextformattingdefinition/body-swift.associatedtype)
- [`func constrain(_:)`](https://developer.apple.com/documentation/swiftui/attributedtextformattingdefinition/constrain(_:))
- [`Scope`](https://developer.apple.com/documentation/swiftui/attributedtextformattingdefinition/scope)
- [`AttributedTextFormattingDefinition.ValueConstraint`](https://developer.apple.com/documentation/swiftui/attributedtextformattingdefinition/valueconstraint)
- [`func affinity(in: AttributedString) -> TextSelectionAffinity`](https://developer.apple.com/documentation/swiftui/attributedtextselection/affinity(in:))
- [`AttributedTextSelection.Attributes`](https://developer.apple.com/documentation/swiftui/attributedtextselection/attributes)
- [`func attributes(in: AttributedString) -> AttributedTextSelection.Attributes<AttributedString>`](https://developer.apple.com/documentation/swiftui/attributedtextselection/attributes(in:))
- [`subscript(_:)`](https://developer.apple.com/documentation/swiftui/attributedtextselection/attributes/subscript(_:))
- [`func typingAttributes(in: AttributedString) -> AttributeContainer`](https://developer.apple.com/documentation/swiftui/attributedtextselection/typingattributes(in:))
- [`AttributedTextValueConstraint`](https://developer.apple.com/documentation/swiftui/attributedtextvalueconstraint)
- [`AttributeKey`](https://developer.apple.com/documentation/swiftui/attributedtextvalueconstraint/attributekey)
- [`AttributedTextValueConstraint.Attributes`](https://developer.apple.com/documentation/swiftui/attributedtextvalueconstraint/attributes)
- [`func constrain(inout Self.Attributes)`](https://developer.apple.com/documentation/swiftui/attributedtextvalueconstraint/constrain(_:))
- [`AutomaticDisclosureGroupStyle`](https://developer.apple.com/documentation/swiftui/automaticdisclosuregroupstyle)
- [`init()`](https://developer.apple.com/documentation/swiftui/automaticdisclosuregroupstyle/init())
- [`AutomaticHoverEffect`](https://developer.apple.com/documentation/swiftui/automatichovereffect)
- [`init()`](https://developer.apple.com/documentation/swiftui/automatichovereffect/init())
- [`AutomaticLabeledContentStyle`](https://developer.apple.com/documentation/swiftui/automaticlabeledcontentstyle)
- [`init()`](https://developer.apple.com/documentation/swiftui/automaticlabeledcontentstyle/init())
- [`AutomaticTableStyle`](https://developer.apple.com/documentation/swiftui/automatictablestyle)
- [`AutomaticTextEditorStyle`](https://developer.apple.com/documentation/swiftui/automatictexteditorstyle)
- [`init()`](https://developer.apple.com/documentation/swiftui/automatictexteditorstyle/init())
- [`AXChartDescriptorRepresentable`](https://developer.apple.com/documentation/swiftui/axchartdescriptorrepresentable)
- [`func makeChartDescriptor() -> AXChartDescriptor`](https://developer.apple.com/documentation/swiftui/axchartdescriptorrepresentable/makechartdescriptor())
- [`func updateChartDescriptor(AXChartDescriptor)`](https://developer.apple.com/documentation/swiftui/axchartdescriptorrepresentable/updatechartdescriptor(_:))
- [`func updateChartDescriptor(AXChartDescriptor)`](https://developer.apple.com/documentation/swiftui/axchartdescriptorrepresentable/updatechartdescriptor(_:)-7cxy6)
- [`BackgroundProminence`](https://developer.apple.com/documentation/swiftui/backgroundprominence)
- [`static let increased: BackgroundProminence`](https://developer.apple.com/documentation/swiftui/backgroundprominence/increased)
- [`static let standard: BackgroundProminence`](https://developer.apple.com/documentation/swiftui/backgroundprominence/standard)
- [`static func processingTask(String) -> BackgroundTask<Void, Void>`](https://developer.apple.com/documentation/swiftui/backgroundtask/processingtask(_:))
- [`BadgeProminence`](https://developer.apple.com/documentation/swiftui/badgeprominence)
- [`static let decreased: BadgeProminence`](https://developer.apple.com/documentation/swiftui/badgeprominence/decreased)
- [`static let increased: BadgeProminence`](https://developer.apple.com/documentation/swiftui/badgeprominence/increased)
- [`static let standard: BadgeProminence`](https://developer.apple.com/documentation/swiftui/badgeprominence/standard)
- [`func animation(Animation?) -> Binding<Value>`](https://developer.apple.com/documentation/swiftui/binding/animation(_:))
- [`var id: Value.ID`](https://developer.apple.com/documentation/swiftui/binding/id)
- [`var id: Value.ID`](https://developer.apple.com/documentation/swiftui/binding/id)
- [`var transaction: Transaction`](https://developer.apple.com/documentation/swiftui/binding/transaction)
- [`func transaction(Transaction) -> Binding<Value>`](https://developer.apple.com/documentation/swiftui/binding/transaction(_:))
- [`BlurReplaceTransition`](https://developer.apple.com/documentation/swiftui/blurreplacetransition)
- [`var configuration: BlurReplaceTransition.Configuration`](https://developer.apple.com/documentation/swiftui/blurreplacetransition/configuration-swift.property)
- [`BlurReplaceTransition.Configuration`](https://developer.apple.com/documentation/swiftui/blurreplacetransition/configuration-swift.struct)
- [`static let downUp: BlurReplaceTransition.Configuration`](https://developer.apple.com/documentation/swiftui/blurreplacetransition/configuration-swift.struct/downup)
- [`static let upUp: BlurReplaceTransition.Configuration`](https://developer.apple.com/documentation/swiftui/blurreplacetransition/configuration-swift.struct/upup)
- [`init(configuration: BlurReplaceTransition.Configuration)`](https://developer.apple.com/documentation/swiftui/blurreplacetransition/init(configuration:))
- [`BorderedTextFieldStyle`](https://developer.apple.com/documentation/swiftui/borderedtextfieldstyle)
- [`init()`](https://developer.apple.com/documentation/swiftui/borderedtextfieldstyle/init())
- [`ButtonRepeatBehavior`](https://developer.apple.com/documentation/swiftui/buttonrepeatbehavior)
- [`static let automatic: ButtonRepeatBehavior`](https://developer.apple.com/documentation/swiftui/buttonrepeatbehavior/automatic)
- [`static let disabled: ButtonRepeatBehavior`](https://developer.apple.com/documentation/swiftui/buttonrepeatbehavior/disabled)
- [`static let enabled: ButtonRepeatBehavior`](https://developer.apple.com/documentation/swiftui/buttonrepeatbehavior/enabled)
- [`static let close: ButtonRole`](https://developer.apple.com/documentation/swiftui/buttonrole/close)
- [`static let confirm: ButtonRole`](https://developer.apple.com/documentation/swiftui/buttonrole/confirm)
- [`ButtonSizing`](https://developer.apple.com/documentation/swiftui/buttonsizing)
- [`ButtonSizing`](https://developer.apple.com/documentation/swiftui/buttonsizing)
- [`static var automatic: ButtonSizing`](https://developer.apple.com/documentation/swiftui/buttonsizing/automatic)
- [`static var automatic: ButtonSizing`](https://developer.apple.com/documentation/swiftui/buttonsizing/automatic)
- [`static var fitted: ButtonSizing`](https://developer.apple.com/documentation/swiftui/buttonsizing/fitted)
- [`static var fitted: ButtonSizing`](https://developer.apple.com/documentation/swiftui/buttonsizing/fitted)
- [`static var flexible: ButtonSizing`](https://developer.apple.com/documentation/swiftui/buttonsizing/flexible)
- [`static var flexible: ButtonSizing`](https://developer.apple.com/documentation/swiftui/buttonsizing/flexible)
- [`CameraCaptureAccessory`](https://developer.apple.com/documentation/swiftui/cameracaptureaccessory)
- [`init(content: () -> Content)`](https://developer.apple.com/documentation/swiftui/cameracaptureaccessory/init(content:))
- [`init(isEnabled: Binding<Bool>, content: () -> Content)`](https://developer.apple.com/documentation/swiftui/cameracaptureaccessory/init(isenabled:content:))
- [`var colorMode: ColorRenderingMode`](https://developer.apple.com/documentation/swiftui/canvas/colormode)
- [`var isOpaque: Bool`](https://developer.apple.com/documentation/swiftui/canvas/isopaque)
- [`var renderer: (inout GraphicsContext, CGSize) -> Void`](https://developer.apple.com/documentation/swiftui/canvas/renderer)
- [`var rendersAsynchronously: Bool`](https://developer.apple.com/documentation/swiftui/canvas/rendersasynchronously)
- [`var symbols: Symbols`](https://developer.apple.com/documentation/swiftui/canvas/symbols)
- [`var cgColor: CGColor?`](https://developer.apple.com/documentation/swiftui/color/cgcolor)
- [`func exposureAdjust(Double) -> Color`](https://developer.apple.com/documentation/swiftui/color/exposureadjust(_:))
- [`func headroom(Double?) -> Color`](https://developer.apple.com/documentation/swiftui/color/headroom(_:))
- [`Color.ResolvedHDR`](https://developer.apple.com/documentation/swiftui/color/resolvedhdr)
- [`var blue: Float`](https://developer.apple.com/documentation/swiftui/color/resolvedhdr/blue)
- [`var green: Float`](https://developer.apple.com/documentation/swiftui/color/resolvedhdr/green)
- [`var headroom: Float?`](https://developer.apple.com/documentation/swiftui/color/resolvedhdr/headroom)
- [`init(Color.Resolved, headroom: Float?)`](https://developer.apple.com/documentation/swiftui/color/resolvedhdr/init(_:headroom:))
- [`var linearBlue: Float`](https://developer.apple.com/documentation/swiftui/color/resolvedhdr/linearblue)
- [`var linearGreen: Float`](https://developer.apple.com/documentation/swiftui/color/resolvedhdr/lineargreen)
- [`var linearRed: Float`](https://developer.apple.com/documentation/swiftui/color/resolvedhdr/linearred)
- [`var opacity: Float`](https://developer.apple.com/documentation/swiftui/color/resolvedhdr/opacity)
- [`var red: Float`](https://developer.apple.com/documentation/swiftui/color/resolvedhdr/red)
- [`func resolveHDR(in: EnvironmentValues) -> Color.ResolvedHDR`](https://developer.apple.com/documentation/swiftui/color/resolvehdr(in:))
- [`static var transferRepresentation: some TransferRepresentation`](https://developer.apple.com/documentation/swiftui/color/transferrepresentation)
- [`ColorMatrix`](https://developer.apple.com/documentation/swiftui/colormatrix)
- [`var a1: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/a1)
- [`var a2: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/a2)
- [`var a3: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/a3)
- [`var a4: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/a4)
- [`var a5: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/a5)
- [`var b1: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/b1)
- [`var b2: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/b2)
- [`var b3: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/b3)
- [`var b4: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/b4)
- [`var b5: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/b5)
- [`var g1: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/g1)
- [`var g2: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/g2)
- [`var g3: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/g3)
- [`var g4: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/g4)
- [`var g5: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/g5)
- [`init()`](https://developer.apple.com/documentation/swiftui/colormatrix/init())
- [`var r1: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/r1)
- [`var r2: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/r2)
- [`var r3: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/r3)
- [`var r4: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/r4)
- [`var r5: Float`](https://developer.apple.com/documentation/swiftui/colormatrix/r5)
- [`init?(UIUserInterfaceStyle)`](https://developer.apple.com/documentation/swiftui/colorscheme/init(_:))
- [`init?(UIAccessibilityContrast)`](https://developer.apple.com/documentation/swiftui/colorschemecontrast/init(_:))
- [`ColumnNavigationViewStyle`](https://developer.apple.com/documentation/swiftui/columnnavigationviewstyle)
- [`CommandGroup`](https://developer.apple.com/documentation/swiftui/commandgroup)
- [`init(after: CommandGroupPlacement, addition: () -> Content)`](https://developer.apple.com/documentation/swiftui/commandgroup/init(after:addition:))
- [`init(before: CommandGroupPlacement, addition: () -> Content)`](https://developer.apple.com/documentation/swiftui/commandgroup/init(before:addition:))
- [`init(replacing: CommandGroupPlacement, addition: () -> Content)`](https://developer.apple.com/documentation/swiftui/commandgroup/init(replacing:addition:))
- [`CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement)
- [`static let appInfo: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/appinfo)
- [`static let appSettings: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/appsettings)
- [`static let appTermination: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/apptermination)
- [`static let appVisibility: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/appvisibility)
- [`static let help: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/help)
- [`static let importExport: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/importexport)
- [`static let newItem: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/newitem)
- [`static let pasteboard: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/pasteboard)
- [`static let printItem: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/printitem)
- [`static let saveItem: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/saveitem)
- [`static let sidebar: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/sidebar)
- [`static let systemServices: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/systemservices)
- [`static let textEditing: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/textediting)
- [`static let textFormatting: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/textformatting)
- [`static let toolbar: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/toolbar)
- [`static let undoRedo: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/undoredo)
- [`static let windowArrangement: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/windowarrangement)
- [`static let windowSize: CommandGroupPlacement`](https://developer.apple.com/documentation/swiftui/commandgroupplacement/windowsize)
- [`CommandMenu`](https://developer.apple.com/documentation/swiftui/commandmenu)
- [`init(_:content:)`](https://developer.apple.com/documentation/swiftui/commandmenu/init(_:content:))
- [`Commands`](https://developer.apple.com/documentation/swiftui/commands)
- [`Body`](https://developer.apple.com/documentation/swiftui/commands/body-swift.associatedtype)
- [`var body: Self.Body`](https://developer.apple.com/documentation/swiftui/commands/body-swift.property)
- [`CommandsBuilder`](https://developer.apple.com/documentation/swiftui/commandsbuilder)
- [`static func buildBlock() -> EmptyCommands`](https://developer.apple.com/documentation/swiftui/commandsbuilder/buildblock())
- … and 2526 more (`isim/data/api-coverage.json.gz`)

</details>
<!-- /generated:missing -->
