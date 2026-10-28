# SwiftUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 69.6% of Apple's iOS API (4722 of 6783, exact) · **Rows:** 304: 293 ✅ 7 🟡 4 ❌ · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [SwiftUI & Charts](../COVERAGE.md#swiftui) · **Apple:** [SwiftUI](https://developer.apple.com/documentation/swiftui) · **Issues:** [`area:swiftui`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aswiftui)

## How isim implements it

- **Adapted:** isim's own engine (`isim/swift/overlays/SwiftUI`).
- Views evaluate into a node tree, are laid out with SwiftUI's proposal model, and are mounted as isim's UIKit views.
- Shapes, `Canvas` and gradients draw through cairo.
- Shaders run on the CPU: isim's Metal compiler builds an app's `[[stitchable]]` functions, and the effect runs them
  per pixel over the view's rendered content (see the Shaders row).

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
| `#Preview` / `PreviewProvider` | 🟡 | ≤17 | adapted: `#Preview` (SwiftUI views, UIViews, UIViewControllers; names, traits) and `PreviewProvider` (+ `previewDisplayName` / `previewLayout` / `previewDevice` / `previewInterfaceOrientation`) compile and type-check: isim's PreviewsMacros plugin expands each `#Preview` into a `DeveloperToolsSupport.PreviewRegistry` type like Xcode's, plus an exported entry point; `isim preview App.app [NAME\|INDEX\|--list] [-o FILE.png]` renders one `#Preview` to a screenshot (the app runs alone in UIKit's preview mode) laid out by its traits (the device, `.sizeThatFitsLayout` and `.fixedLayout` centred on a grey canvas; orientation traits not applied: use `--device`). No live canvas; `PreviewProvider` previews are not rendered and their modifiers change nothing. Tested: HelloToolchain (UIKit) and HelloSwiftUI (SwiftUI, PreviewProvider) build with previews; `isim preview` (test_previews). Widget and Live Activity previews: see WidgetKit. Missing: `@Previewable`, `PreviewModifier` / `PreviewTrait.modifier` |
| `@Previewable`, `PreviewModifier` (`makeSharedContext()`, `body(content:context:)`), `PreviewModifierContent`, `PreviewTrait.modifier(_:)` | ✅ | ≤17 | adapted (PreviewModifier is iOS 18): the #Preview expansion (isim's PreviewsMacros plugin) moves a body's `@Previewable` variables into a view whose body is the rest, so `$state` bindings work; `isim preview` wraps the content in the trait's modifiers, outermost first, each type's shared context made once (asynchronously, before the content shows). Tested (HelloSwiftUI "Counter" and "Themed" previews: test_previews) |

### State & data flow

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `@State` | ✅ | ≤17 | stored per structural position |
| `@Binding`, `Binding(get:set:)`, `.constant`, dynamic-member bindings | ✅ | ≤17 | |
| `ObservableObject` + `@Published` | ✅ | ≤17 | isim Combine |
| `@StateObject`, `@ObservedObject` | ✅ | ≤17 | |
| `@EnvironmentObject`, `.environmentObject` | ✅ | ≤17 | |
| `@Environment(keyPath)`, custom `EnvironmentKey`, `.environment(_:_:)` (on views and scenes) | ✅ | ≤17 | `Scene.environment(_:_:)` sets the value for the scene's views (SwiftData's `.modelContainer` on a `WindowGroup`); tested (HelloSwiftDataTemplate) |
| `@Observable` macro / Observation | ✅ | 17.0 | Observation built from Swift sources; macro via the toolchain plugin; renders track reads; tested (HelloObservation) |
| `@Bindable`, `@Environment(Model.self)` | ✅ | 17.0 | plus `.environment(_:)` for Observable objects; tested |
| `@AppStorage` | ✅ | ≤17 | Bool/Int/Double/String/URL/Data/RawRepresentable/optionals; persists; tested (HelloForms) |
| `@SceneStorage` | ✅ | ≤17 | saved with the scene's state restoration activity (Bool/Int/Double/String) and restored on the next launch unless the app was closed in the app switcher. Tested (HelloScenes) |
| `@FocusState` (Bool and Hashable) | ✅ | ≤17 | |
| `@Namespace` | ✅ | ≤17 | |
| `@GestureState` | ✅ | ≤17 | set through `.updating`, reset when the gesture ends or is cancelled; tested (HelloSwiftUI -gestures) |
| `@ScaledMetric` | ✅ | ≤17 | scales with `dynamicTypeSize`, which follows Settings > Accessibility > Larger Text; tested (HelloLayout, HelloAccessibility) |
| `@FocusedValue`, `@FocusedBinding` | ✅ | ≤17 | a `.focusedValue` is seen while its view or one inside it has focus (the innermost value of a key wins), a `.focusedSceneValue` while its scene is shown; readers update when focus moves. Tested (HelloKeys) |
| `@FocusedObject`, `focusedObject(_:)`, `focusedSceneObject(_:)` | ✅ | ≤17 | the observable object of the focused view (or one around it; the innermost wins), else of the scene; `$object.property` bindings through `FocusedObject.Wrapper`. Its own changes do not re-render the views that read it (isim does not subscribe to the object). Tested (HelloSwiftUIControls PAGE=styles: test_styles_and_focused_object) |
| `commands(content:)` with `CommandMenu`, `CommandGroup` (`before:` / `after:` / `replacing:`), `CommandGroupPlacement`, `Commands`, `CommandsBuilder`, `EmptyCommands` | ✅ | ≤17 | **adapted**: added to the app's main menu (UIMenuSystem, through `buildMenu(with:)` on SwiftUI's application delegate): the iPad menu bar and the keyboard shortcuts overlay, the `mainmenu` script command. A CommandMenu is its own menu before Window; a group goes before, after or instead of the standard group (placements without a group in isim's menu are skipped). Buttons become actions, a button with a `.keyboardShortcut` a key command that works from the hardware keyboard. Tested (HelloSwiftUIControls: test_commands) |
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
| `AsyncImage` | ✅ | ≤17 | URLSession (http(s), file, data URLs); phases, `content:placeholder:`; decoded through a temporary file; tested (HelloForms -pickers) |
| `Label` | ✅ | ≤17 | |
| `labelIconToTitleSpacing(_:)`, `\.labelIconToTitleSpacing` | ✅ | 26.0 | the space between a Label's icon and title (otherwise 8 pt, 14 pt in a List). Tested (HelloSwiftUI -bars: test_shapes_slider_label) |
| `Button` (action, label, role) | ✅ | ≤17 | |
| Button styles: `.plain`, `.borderless`, `.bordered`, `.borderedProminent`, custom `ButtonStyle` | ✅ | ≤17 | |
| `PrimitiveButtonStyle`, `.controlSize`, `.buttonBorderShape` | ✅ | ≤17 | primitive styles build the whole button and call `trigger()`; control size sets bordered padding/font; capsule / rounded / circle shapes; tested (HelloForms -pickers) |
| `Toggle` (switch) | ✅ | ≤17 | |
| `toggleStyle` (`.button`, `.checkbox`, custom) | ✅ | ≤17 | `.switch`, `.button` (tinted when on) and custom `ToggleStyle`s (`.checkbox` is macOS-only); `.button` tested (HelloForms -pickers) |
| `Slider` | ✅ | ≤17 | UISlider; step, value labels, onEditingChanged; tested |
| `sliderThumbVisibility(_:)` | ✅ | 26.0 | **adapted**: `.hidden` is UIKit's thumbless slider (a thicker track the finger drags anywhere). Tested (HelloSwiftUI -bars) |
| `Stepper` | ✅ | ≤17 | value/bounds/step and onIncrement/onDecrement; tested |
| `Picker` (menu, segmented, wheel, inline, navigationLink styles) | ✅ | ≤17 | all five styles; `.wheel` is a snapping scroll-wheel drawn by isim (no UIPickerView); tested (HelloForms, HelloForms -pickers) |
| `DatePicker`, `MultiDatePicker` | ✅ | ≤17 | `DatePicker`: compact (date / time pills open the calendar or the time wheel in a popover, like iOS; picking a day closes it), graphical (month grid, month paging, time row), wheel; `.date` / `.hourAndMinute`; ranges; `labelsHidden`. `MultiDatePicker`: a month calendar toggling days in a `Set<DateComponents>`, `in:` ranges (days outside disabled). Tested (HelloForms -pickers, HelloSwiftUIControls, OS matrix) |
| `ColorPicker` | ✅ | ≤17 | UIKit's colour well, presenting UIKit's colour picker (grid, spectrum, sliders, opacity, saved colours, eyedropper; see UIKit `UIColorPickerViewController`), like iOS; `Color` and `CGColor` bindings, `supportsOpacity`. Tested (HelloForms -pickers) |
| `TextField` (String binding, placeholder, `axis: .vertical` multi-line) | ✅ | ≤17 | `prompt:` is the placeholder (it takes the title's place, like iOS), in `init(_:text:prompt:)`, `(_:text:prompt:axis:)`, their `StringProtocol` forms and `init(text:prompt:label:)` / `(text:prompt:axis:label:)` (the label view is not drawn on iOS). Tested (HelloFileDialogs) |
| `TextField(value:format:)`, `TextField(value:formatter:)` | ✅ | ≤17 | parseable format styles and NumberFormatter / DateFormatter values, parsed on Return or end of editing (unparseable text reverts); tested (HelloForms -pickers) |
| `SecureField` | ✅ | ≤17 | `prompt:` is the placeholder (`init(_:text:prompt:)`, `init(text:prompt:label:)`); tested (HelloFileDialogs) |
| `TextEditor` | ✅ | ≤17 | multi-line field that fills its frame; tested (HelloForms -pickers) |
| `TextRenderer`, `Text.Layout` (`Line`, `Run`, `RunSlice`, `TypographicBounds`, `CharacterIndex`, `DrawingOptions`, `isTruncated`), `View.textRenderer(_:)`, `TextProxy`, `TextAttribute`, `Text.customAttribute(_:)`, `GraphicsContext.draw(_:options:)` of a line, run or slice | ✅ | 18.0 | adapted: text under a renderer is laid out by isim's rich-text layout (words on lines, wrapped, line limits) into lines, runs (consecutive characters with one style and the same custom attributes) and one slice per character, measured with the run's font. The renderer draws the layout into a GraphicsContext over the text's frame grown by its `displayPadding`; its `animatableData` animates; `sizeThatFits(proposal:text:)` sizes the text. Inline images are left out of the layout. Tested (HelloText -rendering: `test_text_rendering.py`) |
| `TextSelection` (`Indices`, `isInsertion`, `affinity`), `TextSelectionAffinity`, `textSelectionAffinity(_:)`, `TextField(_:text:selection:prompt:axis:)`, `TextField(text:selection:prompt:axis:label:)`, `TextEditor(text:selection:)` | ✅ | 18.0 | adapted: the binding follows the text view's selection and moves it when set. A multi-selection selects from its first range to its last (the text views have one selection); the affinity is recorded. `TextEditor(text:selection:)` edits the string in the attributed editor. Tested (`test_text_rendering.py`) |
| `AttributedTextFormattingDefinition`, `AttributedTextValueConstraint`, `AttributedTextFormatting` (`ValueConstraint`, `DefinitionBuilder`, `AttributeContainerProxy`, `EmptyDefinition`, `TupleDefinition`, `AnyDefinition`, `Transferable`), `View.attributedTextFormattingDefinition(_:)` | ✅ | 26.0 | adapted: an attributed `TextEditor` applies the definition's constraints to every run after each edit and to text it is given; each constraint sets only its own attribute. `DefinitionBuilder.buildEither` returns `AnyDefinition` (Apple's returns `_ConditionalContent`, which in isim is a View only: widening it would change every SwiftUI app's ABI). `Transferable` exports the plain characters. Tested (`test_text_rendering.py`) |
| `textEditorStyle(_:)`, `TextEditorStyle` (`.automatic`, `.plain`) | ✅ | 17.0 | **adapted**: iOS's two styles look the same (a plain editor, no border), and isim draws that for both; a custom style's body is not used (its configuration has nothing to show). Tested (HelloSwiftUIControls builds with it) |
| `ProgressView` | ✅ | ≤17 | UIProgressView bar / spinning UIActivityIndicatorView; labels and current-value labels, `.linear` / `.circular` / custom `ProgressViewStyle`; label tested (HelloForms -pickers) |
| `Gauge` | ✅ | ≤17 | linear capacity (default), `.accessoryLinear`, `.accessoryCircular`, `.accessoryCircularCapacity`, custom `GaugeStyle`; tested (HelloForms -pickers) |
| `Link` | ✅ | ≤17 | opens through `openURL` |
| `ShareLink` | ✅ | ≤17 | presents UIKit's share sheet (`UIActivityViewController`: Copy, Save Image, Print, the installed apps' Share and Action extensions) with the item(s): URLs, strings, `Transferable` values (their first exported type as text, a URL, an image or a file), `items:`, `subject` / `message`, `SharePreview`. Tested (HelloForms -pickers, HelloSwiftUIControls, OS matrix) |
| `Menu` | ✅ | ≤17 | pop-up menu with sections, submenus, pickers, destructive buttons; tested |
| `menuStyle(_:)`, `MenuStyle` (`makeBody(configuration:)`, `.automatic`, `.button`), `MenuStyleConfiguration`, `Menu(_: MenuStyleConfiguration)` | ✅ | ≤17 | a custom style's body is shown with the menu's label and content in its configuration (`Menu(configuration)` makes the menu); `.button` draws the label with the button style around (`.buttonStyle(.borderedProminent)`), taps still open the menu. Tested (HelloSwiftUIControls: test_control_options) |
| `menuIndicator(_:)`, `\.menuIndicatorVisibility` | ✅ | 15.0 | **adapted**: `.visible` puts an up-down chevron after Menu labels; `.automatic` and `.hidden` show none (iOS menus have none by default). Tested (HelloSwiftUIControls) |
| `buttonRepeatBehavior(_:)`, `ButtonRepeatBehavior`, `\.buttonRepeatBehavior` | ✅ | 17.0 | **adapted**: a held button fires on touch down, then every 0.1 s after half a second, and not again on release. Tested (HelloSwiftUIControls: `holdid`) |
| `backgroundStyle(_:)`, `\.backgroundStyle` | ✅ | 16.0 | what `.background` (BackgroundStyle) stands for inside; without it, the system background colour. Tested (HelloSwiftUIControls) |
| `labelsVisibility(_:)`, `\.labelsVisibility` | ✅ | 18.0 | `.hidden` works as `labelsHidden()` (Toggle, DatePicker, ColorPicker). Tested (HelloSwiftUIControls) |
| `onPencilDoubleTap(perform:)`, `onPencilSqueeze(perform:)`, `PencilDoubleTapGestureValue`, `PencilSqueezeGestureValue`, `PencilSqueezeGesturePhase`, `PencilHoverPose`, `PencilPreferredAction`, `\.preferredPencilDoubleTapAction`, `\.preferredPencilSqueezeAction` | ✅ | 17.5 | a UIPencilInteraction on the view: the `pencil tap` / `pencil squeeze` script commands (the simulated Apple Pencil) call them, with the hover pose when `pencil hover` is on; a squeeze is `.active`, then `.ended`. The preferred actions come from Settings › Apple Pencil. Tested (HelloSwiftUIControls) |
| `geometryGroup()`, `dialogSeverity(_:)` (`DialogSeverity`), `dialogIcon(_:)`, `typesettingLanguage(_:isEnabled:)` (View and Text, `TypesettingLanguage`) | ✅ | 17.0 | **adapted**: kept, nothing changes on screen. isim already places and animates a view's subviews relative to it (geometryGroup); iOS dialogs look the same whatever the severity and icon (macOS shows them); isim's text uses the same line metrics for every language. Run in HelloSwiftUIControls |
| `Divider`, `Spacer`, `EmptyView`, `Color` as a view | ✅ | ≤17 | |
| `LabeledContent` | ✅ | ≤17 | |
| `labeledContentStyle(_:)`, `LabeledContentStyle`, `LabeledContentStyleConfiguration`, `AutomaticLabeledContentStyle`, `LabeledContent(_: LabeledContentStyleConfiguration)` | ✅ | ≤17 | a custom style's body gets the label and the content; `LabeledContent(configuration)` draws them the default way. Tested (HelloSwiftUIControls PAGE=styles) |
| `ContentUnavailableView` | ✅ | 17.0 | icon, title, description, actions; `.search` / `.search(text:)`; tested (HelloForms -pickers) |
| `ControlGroup`, `GroupBox`, `DisclosureGroup`, `OutlineGroup` | ✅ | ≤17 | disclosure rows expand/collapse (own state or `isExpanded:` binding; in a List the content follows as indented rows); `OutlineGroup` and `List(_:children:)` build the tree; control groups share one bordered row (`controlGroupStyle` ignored); tested (HelloForms -pickers) |
| `groupBoxStyle(_:)`, `GroupBoxStyle`, `GroupBoxStyleConfiguration`, `DefaultGroupBoxStyle`, `GroupBox(_: GroupBoxStyleConfiguration)`; `disclosureGroupStyle(_:)`, `DisclosureGroupStyle`, `DisclosureGroupStyleConfiguration` (`isExpanded` binding), `AutomaticDisclosureGroupStyle` | ✅ | ≤17 | a custom style's body is drawn with the container's label and content (and the disclosure group's expansion state, which the style can toggle); the default styles draw iOS's look. Tested (HelloSwiftUIControls PAGE=styles) |
| `EquatableView`, `equatable()` | ✅ | ≤17 | **adapted**: the content is shown as is; isim evaluates it on every update (SwiftUI skips it while equal), which changes nothing on screen. Tested (HelloSwiftUIControls PAGE=styles) |
| `EditButton`, `PasteButton`, `RenameButton` | ✅ | ≤17 | `EditButton` toggles `\.editMode` (tested, HelloLists); `PasteButton` is UIKit's paste control: enabled while the pasteboard has an accepted type, a tap pastes without the "Allow Paste" prompt and delivers `Transferable` payloads or item providers (tested, HelloSwiftUIControls); `RenameButton` runs `.renameAction { }` or focuses `.renameAction($focus)` (tested) |
| `VideoPlayer` (AVKit) | ✅ | ≤17 | with `videoOverlay`: see AVKit (tested there) |
| `Map` (MapKit) | ✅ | ≤17 | iOS 17 MapContent + iOS 14 `coordinateRegion` API on isim's MKMapView, with map controls: see the MapKit rows; tested (HelloMaps) |
| `SceneView` (SceneKit) | ✅ | ≤17 | in the SceneKit overlay (an `SCNView` in the hierarchy), as on iOS where it comes with SceneKit: see [SceneKit](SceneKit.md) (issue #330). Tested (HelloSceneKit) |
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
| `ScrollPosition`, `scrollPosition(_:anchor:)` | ✅ | 18.0 | **adapted**: the binding scrolls the first ScrollView inside to a view's id (`scrollTargetLayout()` children or `.id(_:)`, with the anchor; top / leading by default), an edge, a point or x / y; after a user drag it becomes `isPositionedByUser` with `viewID` of the first row at the top (when its id is of the position's `idType`). `x` / `y` (iOS 26). Lists keep their own scroll view and do not take it. Tested (HelloSwiftUIScrolling: test_scroll_position_and_phases) |
| `onScrollPhaseChange` (both forms), `ScrollPhase`, `ScrollPhaseChangeContext` | ✅ | 18.0 | **adapted**: from the UIScrollView delegate; a drag goes `idle → interacting` (isim's UIScrollView has no tracking state before the drag starts, so `.tracking` is never reported), then `decelerating` (with the release velocity in points per second) or `idle`; an animated programmatic scroll is `animating`. Tested (HelloSwiftUIScrolling: test_scroll_position_and_phases) |
| `defaultScrollAnchor(_:)`, `defaultScrollAnchor(_:for:)`, `ScrollAnchorRole` | ✅ | ≤17 | **adapted** (the role form and `ScrollAnchorRole` are iOS 18): `.initialOffset` sets where the ScrollView starts, `.sizeChanges` keeps that part in place when the content grows or shrinks, `.alignment` places content smaller than the scroll view; without a role, all three. Tested (HelloSwiftUIScrolling: test_default_anchor_and_clipping) |
| `scrollClipDisabled(_:)`, `scrollIndicatorsFlash(trigger:)`, `scrollIndicatorsFlash(onAppear:)` | ✅ | ≤17 | **adapted**: the ScrollView's `clipsToBounds` (content draws and takes touches outside); the flash is UIScrollView's `flashScrollIndicators()` when the value changes or when the scroll view first appears (logged `isim SwiftUI: flashed scroll indicators`). ScrollViews only, not Lists. Tested (HelloSwiftUIScrolling) |
| `List` (content builder, sections, data, selection) | ✅ | ≤17 | list styles below; `List(data)`, `List(data, children:)`, `List(selection:)` single (tested via NavigationSplitView) and multiple (selection circles in edit mode, rows make room; tested, HelloContainers) |
| `Table` (data, `of:rows:`, `children:` outline forms; `selection:` single and multiple; `sortOrder:`; `columnCustomization:`), `TableColumn` (`value:`, `comparator:`, `sortUsing:`, `width`), `TableColumnContent` (`alignment`, `customizationID`, `defaultVisibility`, `disabledCustomizationBehavior`), `TableColumnBuilder`, `TupleTableColumnContent`, `TableColumnForEach`, `TableColumnAlignment`, `TableColumnCustomization`, `TableColumnCustomizationBehavior`, `TableRow`, `TableRowContent` (`contextMenu`, `draggable`, `dropDestination`, `onHover`, `itemProvider`, `selectionDisabled`), `DynamicTableRowContent` (`onInsert`, `dropDestination`), `TableRowBuilder`, `TupleTableRowContent`, `TableForEachContent`, `TableOutlineGroupContent`, `DisclosureTableRow`, `EmptyTableRowContent`, `TableStyle` (`.automatic`, `.inset`, `.bordered`, `alternatesRowBackgrounds`), `tableColumnHeaders(_:)` | ✅ | ≤17 | adapted, as on iOS: in a compact width (iPhone) a table is a List of its first column; in a regular width (iPad) it shows a header row and the columns side by side (fixed, ideal or shared widths within min / max). Tapping a sortable column's header puts its comparator first in `sortOrder`, and a second tap reverses it; the app sorts its data, as with SwiftUI. Selection, context menus, drag and drop and hover work as in a List. Outline rows show expanded and indented (`DisclosureTableRow` follows `isExpanded`). Columns are shown or hidden by the customization's visibility and ordered by it; it isn't edited interactively. `itemProvider` has no effect (use `draggable`). The row and column builders' `buildEither` return isim types (`_ConditionalTableRowContent`, `TupleTableColumnContent`), not `_ConditionalContent`, which in isim is a View only. Tested (HelloLists -table: `test_swiftui_table.py`, iPhone and iPad) |
| `listStyle`, `listRowBackground`, `listRowSeparator`, `listSectionSpacing`, `scrollContentBackground` | ✅ | ≤17 | UITableView's looks: `.automatic` / `.insetGrouped` (cards inset 20 pt), `.grouped` (full width, section hairlines), `.plain` (system background, bold headers on a grey band that stick to the top, separators under every row), `.inset` (plain, rows inset), `.sidebar` (no separators, large bold headers, rounded selection); `listRowBackground`, `listRowInsets`, `listRowSeparator(_:edges:)` / `listRowSeparatorTint`, `listSectionSeparator` / `Tint`, `listRowSpacing` (each row its own card), `listSectionSpacing` (`.default` / `.compact` / custom, on the list or a section), `scrollContentBackground(.hidden)`, `headerProminence(.increased)`, `listItemTint`, `defaultMinListRowHeight` / `defaultMinListHeaderHeight`, `Section(isExpanded:)` (sidebar and plain headers collapse it). Tested (HelloContainers, OS matrix) |
| `.onDelete`, `.onMove`, `.swipeActions`, edit mode | ✅ | ≤17 | swipe to delete, leading/trailing swipe actions (tint, full swipe), edit mode delete buttons and reorder handles; tested (HelloLists) |
| `deleteDisabled(_:)`, `moveDisabled(_:)`, `selectionDisabled(_:)` | ✅ | ≤17 | **adapted**: on a List row (or every row of a ForEach): no swipe-to-delete and no delete control in edit mode; no reorder handle (the row still counts for the indices `onMove` gets); in `List(selection:)` tapping the row does not select it and edit mode shows no selection circle. Tested (HelloSwiftUIScrolling: test_row_flags, test_selection_disabled) |
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
| `position`, `alignmentGuide` | ✅ | ≤17 | `position` centres the view at a point; explicit guides and custom `AlignmentID`s line up views in HStack / VStack / ZStack, also through nested stacks; looking for guides no longer measures the stacks (deeply nested stacks took seconds to lay out); tested (HelloLayout, HelloApplePay's sheet) |
| `ignoresSafeArea`, `edgesIgnoringSafeArea` | ✅ | ≤17 | |
| `safeAreaInset`, `safeAreaPadding`, `contentMargins` | ✅ | ≤17 | `safeAreaInset` lays the inset view at the edge; a scroll view or list filling the content extends beneath it with its content inset by it (the last rows scroll out from under it), other content is laid out in the rest; `safeAreaPadding`: content insets for scroll views and lists, padding for other views; `contentMargins` `.scrollContent` (content) / `.scrollIndicators` (indicator insets) / `.automatic`. Tested (HelloContainers, HelloLayout) |
| `safeAreaBar(edge:alignment:spacing:content:)` (vertical and horizontal edges) | ✅ | 26.0 | **adapted**: a `safeAreaInset` (the content and scroll views beside it are inset by it) with the iOS 26 scroll-edge fade behind it, from the screen edge to 16 pt past the bar (the horizontal form has no fade). Tested (HelloSwiftUI -bars: test_safe_area_bar) |
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
| `navigationSubtitle(_:)` (Text, LocalizedStringKey, StringProtocol) | ✅ | 26.0 | **adapted**: 15 pt secondary text under the large title (List or other content), and 12 pt under the inline title in the bar. Tested (HelloSwiftUIControls PAGE=styles, iOS 26) |
| `navigationBarBackButtonHidden` | ✅ | ≤17 | hides the back button and the edge swipe back; tested (HelloNavStack) |
| `.toolbar` with `ToolbarItem` / `ToolbarItemGroup` | ✅ | ≤17 | leading / trailing items side by side (iOS 26+: one glass capsule per group), `.principal`, `.secondaryAction` (a "More" menu), `.bottomBar` / `.status` bar, `.keyboard` bar on the keyboard, `ToolbarTitleMenu` / `toolbarTitleMenu`, `toolbarRole(.editor)` (back button without title); tested (HelloNavStack) |
| `DefaultToolbarItem(kind:placement:)`, `ToolbarDefaultItemKind` (`.search`, `.title`, `.sidebarToggle`) | ✅ | 26.0 | **adapted**: `.search` is a magnifier button (`toolbar-search`) at the placement that starts the stack's `.searchable` (its field stays under the title); `.title` and `.sidebarToggle` add nothing, the title and the split view's sidebar button staying where isim's bars show them. Tested (HelloSwiftUI -bars: test_search_minimize) |
| A `Label` in a toolbar | ✅ | ≤17 | shows its icon only, as on iOS (a label style set by the app wins; menu items keep their titles); the title stays the button's accessibility label. Tested (HelloSwiftDataTemplate: the template's Add Item button) |
| `toolbarBackground`, `toolbarColorScheme`, `toolbar(.hidden)` | ✅ | ≤17 | navigation bar background colour / visibility and colour scheme (tested, HelloNavStack); `toolbar(.hidden, for: .navigationBar / .tabBar / .bottomBar)` (tested, HelloLists, HelloTabs); bottom bar background |
| `toolbarVisibility(_:for:)`, `toolbarBackgroundVisibility(_:for:)` | ✅ | 18.0 | iOS 18's names for `toolbar(_:for:)` and `toolbarBackground(_:for:)` with a visibility, same behaviour. Run in HelloSwiftUIControls |
| `TabView` (tab bar, `.tabItem`, `.badge`, selection) | ✅ | ≤17 | material tab bar, SF Symbol items, badges, selection, iOS 18 `Tab`; tested |
| `badgeProminence(_:)`, `BadgeProminence`, `\.badgeProminence` | ✅ | 17.0 | List row badges: `.increased` is white on a red capsule, `.decreased` dimmer (tertiary) text, `.standard` secondary text. Tab bar badges keep their look. Tested (HelloSwiftUIControls: test_list_options) |
| `navigationLinkIndicatorVisibility(_:)`, `\.navigationLinkIndicatorVisibility` | ✅ | 17.0 | `.hidden` leaves out the chevron of NavigationLink rows in a List. Tested (HelloSwiftUIControls) |
| `TabView` `.tabViewStyle(.page)` | ✅ | ≤17 | swipe paging with page dots; tested |
| `.sheet(isPresented:)` / `.sheet(item:)` | ✅ | ≤17 | page sheet with swipe-down dismiss; content gets the environment + `dismiss`; tested (HelloSheets -presentations) |
| `.fullScreenCover` | ✅ | ≤17 | slides up full screen (zoom with `navigationTransition`); tested |
| `.popover` | ✅ | ≤17 | an anchored popover with its arrow on `arrowEdge`, sized to the content (iPad); on iPhone a sheet, or a popover with `presentationCompactAdaptation(.popover / .none)`; `popover(item:)`; tested (HelloSheets) |
| `.alert` | ✅ | ≤17 | title, message, button roles (UIAlertController); `TextField` / `SecureField` actions become the alert's text fields (the bindings get the text before the action runs); tested (HelloSheets -presentations, HelloSheets) |
| `.confirmationDialog` | ✅ | ≤17 | action sheet with Cancel; tested |
| `fileImporter`, `fileExporter`, `fileMover` | ✅ | ≤17 | adapted: present UIKit's `UIDocumentPickerViewController` (isim's Files browser). `fileImporter` (one file, or `allowsMultipleSelection`, with `onCancellation`) opens the files in place: the URLs are security-scoped, as on iOS. `fileExporter` writes a `FileDocument`, a collection of them, or a `ReferenceFileDocument` (from its snapshot) to a temporary file named `defaultFilename` ("Untitled", numbered for a collection), with the content type's extension, and exports a copy of it. `fileMover` moves one file or several. `isPresented` goes back to `false` when the picker closes, before the completion runs. Not provided yet: the `fileDialog…` modifiers (`fileDialogDefaultDirectory`, `fileDialogConfirmationLabel`, `fileDialogMessage`, …), `fileExporterFilenameLabel`. Tested (HelloFileDialogs) |
| `presentationDetents`, `presentationDragIndicator`, `interactiveDismissDisabled` | ✅ | ≤17 | adapted: sheets with detents other than `.large` are isim-drawn cards (`.medium`, `.large`, `.fraction`, `.height`; drag between detents or down to dismiss; selection binding); `interactiveDismissDisabled` keeps them on taps outside and drags; `presentationBackgroundInteraction(.enabled / .enabled(upThrough:))`: no dimming, the page behind takes taps; `presentationCornerRadius`, `presentationBackground`; tested (HelloLists, HelloForms -pickers, HelloSheets). `presentationContentInteraction` stored |
| `@Environment(\.dismiss)` | ✅ | ≤17 | closes sheets / covers (tested, HelloSheets -presentations), pops navigation levels and resets `navigationDestination` bindings (tested, HelloLists) |
| `.searchable` | ✅ | ≤17 | search field under the List's large title (above other content), Cancel, `isSearching`, `dismissSearch`, `.onSubmit(of: .search)`; filtering and Cancel tested (HelloLists); `searchSuggestions` (shown in place of the results while searching; `searchCompletion` fills the field) and `searchScopes` (segmented scope bar, `activation:`) tested (HelloNavStack) |
| `searchable(text:tokens:…)` (with `suggestedTokens:`, `isPresented:`, `editableTokens:`; every prompt form), `searchCompletion(_ token:)` | ✅ | ≤17 | **adapted**: the search field is a UISearchTextField; each token shows as a tinted token in it, from the token view's text and image; Delete at the start of the text removes the last one; suggested tokens are the suggestion rows (`search-token-suggestion-N`) while the text is empty; a `searchCompletion(token)` suggestion row adds its token and clears the text. Editable tokens get a binding but are not edited in place. `placement` is ignored, as for `.searchable`. Tested (HelloSwiftUIScrolling: test_search_tokens_and_focus) |
| `searchFocused(_:)`, `searchFocused(_:equals:)` | ✅ | 18.0 | the nearest `.searchable`'s field (applied around it or inside its content): focusing the field sets the binding, setting it moves the keyboard to or from the field. Tested (HelloSwiftUIScrolling: test_search_tokens_and_focus) |
| `.refreshable` | ✅ | ≤17 | pull past 60 pt and release: spinner while the async action runs (List tested, HelloLists; ScrollView unverified) |
| `.inspector` | ✅ | 17.0 | iPad: a trailing column beside the content (`inspectorColumnWidth`; tested, HelloSheets); iPhone: a sheet, as in compact width (tested, HelloKeys) |
| `@Environment(\.openURL)` | ✅ | ≤17 | |
| `Tab(_:systemImage:value:role:)`, `TabRole.search` | ✅ | 18.0 | with `--os 26`/`27` the search tab sits apart on its own glass circle; selected, the bar turns into a circle with the tab to go back to and the search tab's `.searchable` field on glass (its text, prompt, submit and `isSearching`), riding above the keyboard; with 18 an ordinary tab. Tested (HelloOSVersions, HelloTabs) |
| `searchToolbarBehavior(_:)` (`SearchToolbarBehavior`), `tabViewSearchActivation(_:)` (`TabSearchActivation`) | ✅ | 26.0 | **adapted**: `.minimize` collapses the search field to a round magnifier button (`search-minimized`) until searching; `.searchTabSelection` focuses the tab bar's search field when the search tab is selected (iPhone). Tested (HelloSwiftUI -bars) |
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
| `ArrangementView`, `ArrangementViewStyle` (`.automatic`, `.split` / `axes(_:)`, `.overlay`, custom styles), `splitArrangementLayoutRatio` / `splitArrangementLayoutSize` / `splitArrangementFixedLayoutSize`, `overlayArrangementEdge`; reserved regions, hinge, vertical toolbars | 🟡 | 27.1 | iOS 27.1 (beta) APIs for foldable iPhones, as they behave on isim's devices, none of which folds. Adapted: the split style stacks primary over secondary in compact width portrait and puts them side by side otherwise (within `axes`), the view with the higher `layoutPriority` sized first from its ratio, size or ideal size and the other taking the rest (halves when neither asks); the overlay style fills both, the primary on top, and never turns side by side, so `overlayArrangementEdge` has no effect; custom styles get the configuration's primary and secondary. Inside an arrangement `\.splitArrangementAxis` is the split's axis (decided when it resolves, from the size class and the window's orientation; nil outside a split) and `\.overlayArrangementZIndex` the overlay's order (proposed: the primary 1, on top, the secondary 0; Apple does not document the values). The rest of the iOS 27.1 foldable API, as on a device that does not fold: `DeviceHinge` (`angle`, `status`: `.closed` / `.partiallyOpen` / `.fullyOpen`), `DeviceHingeContext` (`hinge` is nil) and `onHingeChange(isEnabled:_:)` (never called: the context never changes); `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)` with `ReservedRegion` (`ID`, `Kind`, `QueryOptions`) and `LayoutDirectionBehavior` (iOS 17): UIKit's regions of the window moved into the view (the Dynamic Island's or the notch's occlusion, no division), mirrored as asked in a right-to-left window; `toolbarVerticalBehavior`, `toolbarVerticalCompressionBehavior`, `ToolbarContent.axisBehavior` (`ToolbarItemAxisBehavior`) are kept and change nothing (no vertical bar), `\.toolbarVerticalEdge` is nil; `CameraCaptureAccessory` (never available: isim has no capture session to present it in) through the iOS 27 `SceneAccessoryContent` / `onAvailabilityChange` / `View.sceneAccessory` (its closures take a builder of isim's in place of Xcode 27's `@ContentBuilder`; SwiftUI presents no scene accessories yet). Not provided: `ToolbarItemAxisBehavior` on `CustomizableToolbarContent` (isim has no customizable toolbars). Tested (HelloSwiftUI -arrangements and HelloSwiftUIFoldable, iPhone 17 and iPad Pro under iOS 27.1) |

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
| `keyboardType`, `autocorrectionDisabled`, `textInputAutocapitalization`, `submitLabel`, `textContentType` | ✅ | ≤17 | the keyboard type picks the layout (see UIKit); `textContentType(_:)` sets the field's `UITextContentType`, which drives isim's AutoFill (UIKit `textContentType`). Tested (HelloFileDialogs) |
| `textFieldStyle`, `labelStyle` | ✅ | ≤17 | `.roundedBorder` / `.plain` fields; `.iconOnly` / `.titleOnly` / `.titleAndIcon` and custom `LabelStyle`s; tested (HelloForms -pickers) |
| `pickerStyle`, `datePickerStyle`, `progressViewStyle`, `gaugeStyle` | ✅ | ≤17 | see the controls above; tested (HelloForms, HelloForms -pickers) |
| `ViewModifier`, `.modifier` | ✅ | ≤17 | |
| `redacted`, `privacySensitive` | ✅ | ≤17 | `.placeholder` draws text as grey bars and images as grey boxes (tested, HelloForms -pickers); `privacySensitive` content is redacted under `.redacted(reason: .privacy)` (tested, HelloEffects) |
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
| `Path.strokedPath`, boolean operations (`union`, `intersection`, …), `Shape.union` etc. | ✅ | ≤17 | adapted: curves are flattened (0.2 pt) and regions combined by a slab sweep into polygon outlines: `union`, `intersection`, `subtracting`, `symmetricDifference`, `normalized` (both fill rules), `lineIntersection` / `lineSubtraction`; `strokedPath` outlines the stroke (width, caps, joins, miter limit, dashes); the same on shapes. Tested (HelloDrawing -shapes) |
| `fill` (colors, any style, `FillStyle(eoFill:)`) | ✅ | ≤17 | |
| `stroke` / `stroke(style:)` with `StrokeStyle` (width, caps, joins, miter limit, dashes, dash phase) | ✅ | ≤17 | dashes tested; joins and miter limit unverified |
| `trim(from:to:)` | ✅ | ≤17 | exact on curves (arc length) |
| `Ellipse`, `UnevenRoundedRectangle` | ✅ | ≤17 | |
| `ContainerRelativeShape` | ✅ | ≤17 | the shape of the nearest `.containerShape(_:)`, made concentric (a rounded rectangle's radius minus the distance to the container's edge; other shapes inset); outside one, the frame's rectangle. Tested (HelloDrawing -shapes) |
| `ConcentricRectangle` (all initializers), `Edge.Corner`, `Edge.Corner.Set`, `Edge.Corner.Style` (`.fixed`, `.concentric`, `.concentric(minimum:)`, literals) | ✅ | 26.0 | **adapted**: each concentric corner is the container's radius minus the view's distance from that corner (at least the minimum): the nearest `.containerShape(_:)`, otherwise the screen's rounded corners (the radius UIKit's concentric `UICornerConfiguration` uses); uniform corners share the smallest; circular arcs. Without a view (`path(in:)`), fixed corners and the minimums. Tested (HelloSwiftUI -bars: test_shapes_slider_label) |
| `InsettableShape` (`inset(by:)`, `strokeBorder`) | ✅ | ≤17 | |
| `AnyShape` | ✅ | ≤17 | |
| Shape `.offset`, `.rotation`, `.scale`, `.transform`, `.size` | ✅ | ≤17 | offset and rotation tested; scale/transform/size unverified |
| `fill(_:).stroke(_:)` on a filled shape (iOS 17) | ✅ | ≤17 | the fill with the stroke centred on its edge. Tested (HelloDrawing -shapes) |
| `LinearGradient`, `RadialGradient`, `AngularGradient` / `conicGradient`, `EllipticalGradient`, `Gradient` (colors, stops) | ✅ | ≤17 | as views and shape styles |
| Gradients in `fill`, `foregroundStyle`, `background`, `background(_:in:)`, `overlay` | ✅ | ≤17 | gradient strokes unverified |
| `Color.gradient` (`AnyGradient`) | ✅ | ≤17 | a top-to-bottom gradient a little lighter at the top (approximates Apple's) |
| Text with a gradient `foregroundStyle` | ✅ | ≤17 | the gradient (linear, radial, angular, any shape style) fills the glyphs, across the text's frame. Tested (HelloDrawing -shapes, HelloDrawing) |
| `Material` (`.ultraThinMaterial` … `.bar`) | ✅ | ≤17 | real backdrop blur (UIVisualEffectView) |
| `Color` (system colors, RGB/HSB/white, `Color(uiColor:)`, asset colors) | ✅ | ≤17 | |
| `ImagePaint` (`.image(_:sourceRect:scale:)`) | ✅ | ≤17 | tiles fills; image strokes are not drawn |
| `Canvas` / `GraphicsContext` (fill/stroke paths with colors, styles and gradients, text, images, transforms, opacity, clip, `drawLayer`, `addFilter`, `clipToLayer`, blend modes, symbols) | ✅ | ≤17 | adapted. `addFilter` / `GraphicsContext.Filter`: each filter is a pass of isim's host effects on the drawing, in the order added: `blur`, `shadow`, `colorMultiply`, `grayscale`, `hueRotation`, `saturation`, `brightness`, `contrast`, `colorInvert(_:)` (partial amounts too), `colorMatrix` (`ColorMatrix`; isim applies it to unpremultiplied components, with or without `isPremultiplied`), `alphaMultiply`, `luminanceToAlpha`, `alphaThreshold` (two colour-matrix passes) and `projectionTransform` (its affine part transforms the drawing). `clipToLayer(opacity:options:content:)` draws the content offscreen at the screen's scale and masks later drawing with its alpha (`.inverse` too). `blendMode`: each drawing is composited with it, except `clear`, `copy`, `sourceIn`, `sourceOut`, `destinationIn`, `destinationAtop` and `xor` (drawn normally). `resolveSymbol(id:)` finds the `symbols` view with that tag (mounted hidden, at its ideal size) and `draw(_:at:anchor:)` / `draw(_:in:)` draw its view hierarchy. Not provided: the shader filters (`colorShader`, `distortionShader`, `layerShader`; they need Metal), shadow options, the perspective of a non-affine `projectionTransform`. Tested (HelloCanvasEffects; `blur` / `shadow` through Charts, HelloCharts -styling) |
| Shaders (`ShaderLibrary`, `ShaderFunction`, `Shader`, `Shader.Argument`, `.colorEffect(_:isEnabled:)`, `.layerEffect(_:maxSampleOffset:isEnabled:)`, `.distortionEffect(_:maxSampleOffset:isEnabled:)`) | ✅ | 17.0 | adapted. `isim build` compiles the app's `.metal` files for the CPU (Metal, issue #328) and the `[[stitchable]]` functions get an entry point that binds the position, the pixel's color (colorEffect) or `SwiftUI::Layer` (layerEffect, from `<SwiftUI/SwiftUI_Metal.h>`; `sample` is bilinear) and the arguments in order: `float` … `float4`, `color` (premultiplied `half4`), `floatArray` / `colorArray` (a pointer and a count), `data`, `image` (a `texture2d<half>`) and `boundingRect`. The view draws into an offscreen group (extended by `maxSampleOffset`), and the function runs once per pixel at the screen's scale; a distortion samples the group bilinearly at the position returned. `ShaderLibrary.default` and `.bundle(_:)` load `default.metallib.dylib`; `init(url:)` and `init(data:)` take isim's metallib, compiled at first use into Caches (an Apple GPU metallib cannot run and is logged). `dithersColor` is ignored. Not provided: the shader `VisualEffect`s and `GraphicsContext` shader filters. Tested (HelloShaders: tint, color-array stripes, a TimelineView-animated pulse, isEnabled, mirror with `boundingRect`, wave, pixelation, layer sampling) |
| `MeshGradient`, `Color.mix(with:by:)` | ✅ | 18.0 | adapted: the mesh is rasterized by isim (points or Bézier points, smooth Catmull-Rom or bilinear colours, background), as a view and a shape style; `Color.mix` in Oklab (`.perceptual`) or sRGB (`.device`); `Color.Resolved` / `resolve(in:)` (iOS 17). Tested (HelloDrawing -shapes) |

### Animation

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `withAnimation` (incl. `completion:`) | ✅ | ≤17 | animates the next render (frames, opacity, transforms, colors) |
| `.animation(_:value:)` | ✅ | ≤17 | animates its subtree when the value changes |
| Curves & springs (`.easeInOut`, `.spring`, `.bouncy`, `.snappy`, `.smooth`, `timingCurve`, `interpolatingSpring`), repeat/delay/speed | ✅ | ≤17 | standard curves, exact cubic Bézier `timingCurve` / `UnitCurve`, damped springs from duration + bounce or mass / stiffness / damping (`Spring` values, velocity, settling duration), `repeatCount` (autoreversing plays) / `repeatForever`, delay, speed, on UIKit's animation engine. Tested (HelloDrawing -shapes: positions over time) |
| Transitions (`.opacity`, `.scale`, `.slide`, `.move`, `.offset`, `.push`, `asymmetric`, `combined`) | ✅ | ≤17 | insertion and removal of each kind play from / to where the view is (not riding along with its container's change): fade, scale about the anchor, slide in from the leading edge and out to the trailing one, move from an edge, offset, push (moving and fading), asymmetric, combined; `.animation(_:)` on a transition. Tested (HelloDrawing -shapes: positions, sizes and opacity over time) |
| `Transition` (`TransitionPhase`, `TransitionProperties`, `apply`, `animation`, `combined`), the built-in types (`OpacityTransition`, `ScaleTransition`, `MoveTransition`, `OffsetTransition`, `PushTransition`, `SlideTransition`, `IdentityTransition`, `AsymmetricTransition`), `View.transition(_: some Transition)`, `AnyTransition(_:)` | ✅ | 17.0 | adapted: the built-in types play as the transitions above. A custom transition's body is resolved over a placeholder for `willAppear` and `didDisappear`, and the opacity, scale, rotation, offset and blur it applies become the view's state before insertion and after removal; other modifiers in its body apply at `identity` only. Tested (HelloDrawing -shapes, PAGE=custom: `test_shapes.py::test_custom_transitions`) |
| `AnyTransition.modifier(active:identity:)` | ✅ | ≤17 | adapted: the active modifier's opacity, scale, rotation, offset and blur, relative to the identity modifier's; tested (`test_custom_transitions`) |
| `BlurReplaceTransition` (`.blurReplace`, `.downUp`, `.upUp`) | ✅ | 17.0 | adapted: blurs (10 pt), scales (in from 0.8; out to 0.8, or to 1.2 with `.upUp`) and fades; the blur follows the transition's animation frame by frame. Tested (`test_custom_transitions`) |
| `CustomAnimation`, `Animation(_:)`, `AnimationContext`, `AnimationState`, `AnimationStateKey`, `Animation.base` / `animate` / `velocity` / `shouldMerge` / `logicallyComplete(after:)`, `Binding.animation(_:)` | ✅ | 17.0 | adapted: isim animates with UIKit's engine, so a custom animation is sampled for a unit value (120 times a second, until it returns nil, at most 10 s) into a timing curve that every animated property follows. Its state works within the sampling; `velocity` and `shouldMerge` are offered but running animations are not retargeted with them. Isim's own curves are exposed as a `CustomAnimation` through `base`. Tested (`test_custom_transitions`, played by a custom animation) |
| `matchedGeometryEffect` | ✅ | ≤17 | an inserted view moves and scales from its match's frame while the removed one moves to the new frame, the two cross-fading; `isSource: false` views take the source's frame, position or size (`properties`, `anchor`) while both are on screen; `@Namespace` IDs stay the same across updates. Adapted: the size change is a scale of the content (laid out at its own size). Tested (HelloDrawing -shapes) |
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
| `DragGesture` (`onChanged`/`onEnded`, translation, velocity, predicted end) | ✅ | ≤17 | UIKit recognizers on the wrapped view; `.local`/`.global` coordinate spaces; tested (HelloSwiftUI -gestures, HelloDrawing) |
| `Optional: Gesture` (`.gesture(enabled ? g : nil)`) | ✅ | ≤17 | nil installs no recognizer; tested (HelloSourceCompat) |
| `simultaneousGesture`, `highPriorityGesture`, `simultaneously(with:)`, `sequenced(before:)`, `exclusively(before:)`, `map` | ✅ | ≤17 | composition (magnify+rotate together, long press before drag, double tap before single); nested gestures compete like SwiftUI's: a view's gesture or tap wins over its parent's `.gesture` (which waits for it to fail), `highPriorityGesture` wins over the gestures and taps inside it, `simultaneousGesture` fires with them; `including:` masks (`.gesture`, `.subviews`, `.none`) and `isEnabled:`. Tested (HelloSwiftUI -gestures) |
| `MagnifyGesture`, `RotateGesture` (+ `MagnificationGesture`, `RotationGesture`) | ✅ | ≤17 | two fingers from isim's multi-touch (Option-drag, script `pinch`/`rotate2`); magnification/rotation, velocity, start anchor/location; tested (HelloSwiftUI -gestures) |
| `SpatialTapGesture` | ✅ | ≤17 | location in local/global space; tested (HelloSwiftUI -gestures) |
| `sequenced`, `exclusively`, `simultaneously(with:)`, `.updating` | ✅ | ≤17 | built on UIKit recognizers; tested (HelloSwiftUI -gestures) |

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
| `onDrop(of:delegate:)`, `DropDelegate`, `DropInfo`, `DropProposal`, `DropOperation` | ✅ | ≤17 | a UIDropInteraction asks the delegate: `validateDrop` (with the types), `dropEntered`, `dropUpdated` (its proposal's operation; copy without one), `dropExited`, `performDrop` with the location and the item providers. Tested (HelloDragDrop: test_drop_delegate) |
| `accessibilityHint`, `accessibilityHidden` | ✅ | ≤17 | set on the mounted UIKit view; VoiceOver reads hints and skips hidden views; tested (HelloAccessibility) |
| `accessibilityValue`, `accessibilityAddTraits`, `accessibilityElement(children:)`, `accessibilityAction`, `accessibilityAdjustableAction`, `accessibilitySortPriority` | ✅ | ≤17 | feed the UIKit accessibility tree (value, traits, `.combine`/`.ignore` label from the children's text, `.contain` grouping, default and named actions, adjustable increments, sort priority); tested (HelloAccessibility: value, header trait, combine, adjustable, hidden; HelloSwiftUIControls: sort priority, named actions through VoiceOver's action and Actions rotor) |
| `AccessibilityFocusState` (`init()`, `init(for:)`, `Binding`), `AccessibilityTechnologies`, `accessibilityFocused(_:)` / `(_:equals:)` | ✅ | ≤17 | adapted: VoiceOver focusing the element sets the value (true / the matching value) and leaving it clears it; setting it moves VoiceOver's focus there (a layout-changed notification after the update). Setting false / nil does not move the focus away; the technologies are not told apart. Tested (HelloSwiftUI -accessibility) |
| `accessibilityHeading(_:)` (View, `ModifiedContent`, `Text`), `AccessibilityHeadingLevel` | ✅ | ≤17 | adapted: levels 1–6 give the element the header trait and UIKit's heading level attribute, so VoiceOver says "Heading level N" (the Headings rotor finds them); `.unspecified` changes nothing. Tested (HelloSwiftUI -accessibility) |
| `accessibilityCustomContent(_:_:importance:)` (the 11 overloads, View and `ModifiedContent`), `AccessibilityCustomContentKey` | ✅ | ≤17 | as Accessibility's `AXCustomContent` on the element (see [Accessibility](Accessibility.md)): VoiceOver reads high-importance entries with the element and the others in the rotor's More Content; an entry replaces one with the same key identifier, a nil value removes it. Tested (HelloSwiftUI -accessibility) |
| `accessibilityChildren(children:)`, `accessibilityRepresentation(representation:)` | ✅ | ≤17 | adapted: the views are laid out in the modified view's frame and mounted under an empty layer mask (not drawn, not touchable), so they make the accessibility elements in its place (a `Slider` representation is adjustable and drives its binding); the content's own elements are hidden. Tested (HelloSwiftUI -accessibility) |
| `accessibilityLinkedGroup(id:in:)` | ✅ | ≤17 | adapted: the group's elements follow its first one in VoiceOver's order (iOS's text navigation across them is not simulated). Tested (HelloSwiftUI -accessibility) |
| `accessibilityRotor` (content builder, `entries:entryID:entryLabel:`, Identifiable `entries:entryLabel:`, `textRanges:`; Text / key / `StringProtocol` / `LocalizedStringResource` / `AccessibilitySystemRotor`), `accessibilityRotorEntry(id:in:)`, `AccessibilityRotorEntry`, `AccessibilityRotorContent`, `AccessibilityRotorContentBuilder`, `AccessibilitySystemRotor`, `ForEach` of rotor entries | ✅ | ≤17 | a `UIAccessibilityCustomRotor` on the view (a system rotor replaces VoiceOver's, e.g. Headings): its entries find their elements by `ForEach` id, `.id(_:)` or namespace entry; `prepare` runs before VoiceOver moves; entries without an id (text ranges) are the element itself, the ranges are not navigated. Not provided: `Group` of rotor entries (isim's `Group` takes views only). Tested (HelloSwiftUI -accessibility) |
| `accessibilityScrollAction(_:)`, `accessibilityZoomAction(_:)`, `AccessibilityZoomGestureAction`, `accessibilityDirectTouch(_:options:)`, `AccessibilityDirectTouchOptions`, `AccessibilityAttachmentModifier` | ✅ | ≤17 | VoiceOver's three-finger scroll (`voiceover scroll`: down → `.top`, up → `.bottom`, left → `.trailing`, right → `.leading`; proposed, Apple doesn't document the mapping) and zoom (`voiceover zoom in\|out`, at the element's activation point) run the handlers; a direct touch area's touches reach the app under VoiceOver (`silentOnTouch`: without speaking; `requiresActivation`: after a VoiceOver activation). Tested (HelloSwiftUI -accessibility) |

### UIKit interop

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `UIViewRepresentable` (coordinator, update, dismantle) | ✅ | ≤17 | |
| `UIViewControllerRepresentable` | ✅ | ≤17 | |
| `UIHostingController` in UIKit apps | ✅ | ≤17 | its view's `intrinsicContentSize` and `sizeThatFits(_:)` are the content's ideal size (`UIView.noIntrinsicMetric` along an axis the content fills), so Auto Layout and `UIStackView` size it (adapted). Tested (HelloInterfaceStyle) |
| `UIHostingController.sizingOptions`, `UIHostingControllerSizingOptions` | ✅ | ≤17 | `.preferredContentSize` keeps `preferredContentSize` at the ideal size after each render, `.intrinsicContentSize` invalidates the view's intrinsic size when it changes (adapted). Tested (HelloInterfaceStyle) |
| `sizeThatFits(_:uiView:context:)` on representables | ✅ | ≤17 | also `sizeThatFits(_:uiViewController:context:)`; tested (HelloKeys) |
| `UIHostingConfiguration` | ✅ | 16.0 | adapted: a `UIContentConfiguration` whose content view hosts the SwiftUI views (isim's real UIKit views): the content inset by the cell's layout margins or `margins(_:_:)` (both forms), the background (`background(_:)` with a shape style, `background(content:)`) filling the cell, `minSize(width:height:)` / `minSize()` (the default: 44 pt tall); the cell sizes to the content through UIKit's fitting pass (wrapping text grows the row). Not bridged: list swipe actions and separator alignment. Tested (HelloSwiftUIInterop) |
| `ImageRenderer` | ✅ | 16.0 | adapted: `uiImage` / `cgImage` draw the content (at its size for `proposedSize`, its ideal size by default) with `drawHierarchy` at `scale` (`isOpaque`); `render(rasterizationScale:renderer:)` draws it into any `CGContext` with a bottom-left origin (a PDF context too); `objectWillChange` (`PassthroughSubject<Void, Never>`) fires when a property or the content's state changes. Every isim view is drawn (no placeholders); `colorMode` and `allowedDynamicRange` (`Image.DynamicRange`, iOS 26) do not change the 8-bit sRGB output. Not provided: the `Observable` conformance and `isObservationEnabled`. Tested (HelloSwiftUIInterop) |
| `gesture(_:)` with one | ✅ | 18.0 | `makeCoordinator(converter:)` and `makeUIGestureRecognizer(context:)` run once, `updateUIGestureRecognizer` on every update, SwiftUI's target calls `handleUIGestureRecognizerAction` with the latest value; `UIGestureRecognizerRepresentableContext` (`converter`, `coordinator`) and `UIGestureRecognizerRepresentableCoordinateSpaceConverter` (`localLocation` / `localTranslation` / `localVelocity`, `location(in:)`, `translation(in:)` / `velocity(in:)` for pans, `convert(globalPoint:to:)`, in local, global and named spaces). Tested (HelloSwiftUIInterop) |
| `UIHostingSceneDelegate`, `UISceneSessionActivationRequest(hostingDelegateClass:…)` | ✅ | 26.0 | adapted: when UIKit connects a scene to a delegate class that conforms (a `UISceneConfiguration`'s `delegateClass`, or one of the four request initializers, nil when `rootScene` has no matching window group), SwiftUI makes its window for the requested `WindowGroup` (the first by default; `id:` / `value:`) before the delegate's own `scene(_:willConnectTo:options:)`, and the delegate keeps every UIKit callback. Also `UIApplication.activateSceneSession(for:)` without an error handler. A second window needs an iPad, as with `openWindow`. Tested (HelloSwiftUIInterop, iPhone and iPad under iOS 26) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `AccessibilityAttachmentModifier`, `AccessibilityCustomContentKey`, `AccessibilityDirectTouchOptions`, `AccessibilityFocusState`, `AccessibilityHeadingLevel`, `AccessibilityLabeledPairRole`, `AccessibilityRotorContent`, `AccessibilityRotorContentBuilder`, `AccessibilityRotorEntry`, `AccessibilitySystemRotor`, `AccessibilityTechnologies`, `AccessibilityTextContentType`, `AccessibilityZoomGestureAction`, `ActionSheet`, `Alert`, `AnimationContext`, `AnimationState`, `AnimationStateKey`, `AsymmetricTransition`, `AXChartDescriptorRepresentable`, `BackgroundProminence`, `ColorMatrix`, `ContentSizeCategory`, `ContextMenu`, `ControlGroupStyleConfiguration`, `CustomAnimation`, `CustomizableToolbarContent`, `CustomPresentationDetent`, `DefaultDateProgressLabel`, `DisclosureTableRow`, `DismissBehavior`, `DocumentBaseBox`, `DynamicTableRowContent`, `EditableCollectionContent`, `EditActions`, `EmptyModifier`, `EmptyTableRowContent`, `EmptyWidgetConfiguration`, `EnvironmentalModifier`, `FileDialogBrowserOptions`, `FillShapeView`, `FormStyleConfiguration` and 69 more (111 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `AccessibilityActionCategory`, `AnyScrollTargetBehavior`, `AnyTabContent`, `ContentToolbarPlacement`, `CustomHoverEffect`, `DefaultDocumentGroupLaunchActions`, `DocumentGroupLaunchScene`, `DocumentLaunchGeometryProxy`, `DocumentLaunchView`, `EmptyControlWidgetConfiguration`, `EmptyControlWidgetTemplate`, `FixedTextVariant`, `ForEachSectionCollection`, `ForEachSubviewCollection`, `GroupElementsOfContent`, `GroupSectionsOfContent`, `HandGestureShortcut`, `MaterialActiveAppearance`, `NewDocumentButton`, `PresentationSizingContext`, `PresentationSizingRoot`, `PreviewModifierContent`, `SceneRestorationBehavior`, `ScrollContentOffsetAdjustmentBehavior`, `ScrollInputBehavior`, `ScrollInputKind`, `ScrollTargetBehaviorProperties`, `ScrollTargetBehaviorPropertiesContext`, `SizeDependentTextVariant`, `SpatialEventCollection`, `SpatialEventGesture`, `SystemFormatStyle`, `TabContent`, `TabContentBuilder`, `TextProxy`, `TextSelection`, `TextSelectionAffinity`, `TextVariantPreference`, `TimeDataSource`, `ToolbarLabelStyle`, `UIGestureRecognizerRepresentable`, `WindowManagerRole`, `WindowToolbarFullScreenVisibility`, `WritingToolsBehavior` (43 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 26) | ❌ | 26.0 | not implemented, found by the 2026-10 sweep: `AnimatableValues`, `AssistiveAccess`, `AttributedTextFormatting`, `AttributedTextFormattingDefinition`, `AttributedTextValueConstraint`, `ButtonSizing`, `DebugReplaceableView`, `DefaultButtonLabel`, `DragConfiguration`, `DragSession`, `DropConfiguration`, `FindContext`, `RectangleCornerInsets`, `RoundedRectangularShape`, `RoundedRectangularShapeCorners`, `SymbolColorRenderingMode`, `SymbolVariableValueMode`, `TextInputFormattingControlPlacement`, `TupleContent`, `UIHostingSceneDelegate` (20 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 27) | ❌ | 27.0 | not implemented, found by the 2026-10 sweep: `AnyNavigationTransition`, `ContentMarginGuide`, `DefaultNewDocumentButtonLabel`, `ExternalNonInteractiveAccessory`, `GestureInputKinds`, `ReservedRegion`, `SceneAccessoryContent`, `TextInputBorderShape`, `ToolbarMinimizationRestoration`, `ToolbarMinimizationSafeAreaAdjustment`, `ToolbarTitleAlignment`, `ToolbarVerticalBehavior`, `ToolbarVerticalCompressionBehavior` (13 types; with their members under "Not yet in isim") |
| `ContainerBackgroundPlacement` in isim's WidgetKit module | 🟡 | ≤17 | adapted: implemented, but declared in isim's WidgetKit overlay instead of SwiftUI (Apple's module), so code that imports only SwiftUI does not see it; the 2026-10 sweep counts it missing from SwiftUI |
| `ControlWidget`, `ControlWidgetConfiguration`, `ControlWidgetConfigurationBuilder`, `ControlWidgetTemplate`, `ControlWidgetTemplateBuilder` in isim's WidgetKit module | 🟡 | 18.0 | adapted: implemented, but declared in isim's WidgetKit overlay instead of SwiftUI (Apple's module), so code that imports only SwiftUI does not see them; the 2026-10 sweep counts them missing from SwiftUI |
| `FetchRequest`, `FetchedResults` in isim's CoreData module | 🟡 | ≤17 | adapted: implemented, but declared in isim's CoreData overlay instead of SwiftUI (Apple's module), so code that imports only SwiftUI does not see them; the 2026-10 sweep counts them missing from SwiftUI |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
2061 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`AccessibilityActionCategory`](https://developer.apple.com/documentation/swiftui/accessibilityactioncategory)
- [`static let `default`: AccessibilityActionCategory`](https://developer.apple.com/documentation/swiftui/accessibilityactioncategory/default)
- [`static let edit: AccessibilityActionCategory`](https://developer.apple.com/documentation/swiftui/accessibilityactioncategory/edit)
- [`init(_:)`](https://developer.apple.com/documentation/swiftui/accessibilityactioncategory/init(_:))
- [`AccessibilityLabeledPairRole`](https://developer.apple.com/documentation/swiftui/accessibilitylabeledpairrole)
- [`case content`](https://developer.apple.com/documentation/swiftui/accessibilitylabeledpairrole/content)
- [`case label`](https://developer.apple.com/documentation/swiftui/accessibilitylabeledpairrole/label)
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
- [`static func interactiveSpring(duration: TimeInterval, extraBounce: Double, blendDuration: TimeInterval) -> Animation`](https://developer.apple.com/documentation/swiftui/animation/interactivespring(duration:extrabounce:blendduration:))
- [`func colorSpace(Gradient.ColorSpace) -> AnyGradient`](https://developer.apple.com/documentation/swiftui/anygradient/colorspace(_:))
- [`AnyNavigationTransition`](https://developer.apple.com/documentation/swiftui/anynavigationtransition)
- [`init(some NavigationTransition)`](https://developer.apple.com/documentation/swiftui/anynavigationtransition/init(_:))
- [`AnyScrollTargetBehavior`](https://developer.apple.com/documentation/swiftui/anyscrolltargetbehavior)
- [`var base: any ScrollTargetBehavior`](https://developer.apple.com/documentation/swiftui/anyscrolltargetbehavior/base)
- [`init(some ScrollTargetBehavior)`](https://developer.apple.com/documentation/swiftui/anyscrolltargetbehavior/init(_:))
- [`AnyTabContent`](https://developer.apple.com/documentation/swiftui/anytabcontent)
- [`init<T>(T)`](https://developer.apple.com/documentation/swiftui/anytabcontent/init(_:))
- [`AssistiveAccess`](https://developer.apple.com/documentation/swiftui/assistiveaccess)
- [`init(content: () -> Content)`](https://developer.apple.com/documentation/swiftui/assistiveaccess/init(content:))
- [`func constrain(_:)`](https://developer.apple.com/documentation/swiftui/attributedtextformattingdefinition/constrain(_:))
- [`func affinity(in: AttributedString) -> TextSelectionAffinity`](https://developer.apple.com/documentation/swiftui/attributedtextselection/affinity(in:))
- [`AttributedTextSelection.Attributes`](https://developer.apple.com/documentation/swiftui/attributedtextselection/attributes)
- [`func attributes(in: AttributedString) -> AttributedTextSelection.Attributes<AttributedString>`](https://developer.apple.com/documentation/swiftui/attributedtextselection/attributes(in:))
- [`subscript(_:)`](https://developer.apple.com/documentation/swiftui/attributedtextselection/attributes/subscript(_:))
- [`init(insertionPoint: AttributedString.Index, typingAttributes: AttributeContainer?)`](https://developer.apple.com/documentation/swiftui/attributedtextselection/init(insertionpoint:typingattributes:))
- [`func typingAttributes(in: AttributedString) -> AttributeContainer`](https://developer.apple.com/documentation/swiftui/attributedtextselection/typingattributes(in:))
- [`AutomaticHoverEffect`](https://developer.apple.com/documentation/swiftui/automatichovereffect)
- [`init()`](https://developer.apple.com/documentation/swiftui/automatichovereffect/init())
- [`AXChartDescriptorRepresentable`](https://developer.apple.com/documentation/swiftui/axchartdescriptorrepresentable)
- [`func makeChartDescriptor() -> AXChartDescriptor`](https://developer.apple.com/documentation/swiftui/axchartdescriptorrepresentable/makechartdescriptor())
- [`func updateChartDescriptor(AXChartDescriptor)`](https://developer.apple.com/documentation/swiftui/axchartdescriptorrepresentable/updatechartdescriptor(_:))
- [`func updateChartDescriptor(AXChartDescriptor)`](https://developer.apple.com/documentation/swiftui/axchartdescriptorrepresentable/updatechartdescriptor(_:)-7cxy6)
- [`BackgroundProminence`](https://developer.apple.com/documentation/swiftui/backgroundprominence)
- [`static let increased: BackgroundProminence`](https://developer.apple.com/documentation/swiftui/backgroundprominence/increased)
- [`static let standard: BackgroundProminence`](https://developer.apple.com/documentation/swiftui/backgroundprominence/standard)
- [`static func processingTask(String) -> BackgroundTask<Void, Void>`](https://developer.apple.com/documentation/swiftui/backgroundtask/processingtask(_:))
- [`static func urlSession(matching: (String) -> Bool) -> BackgroundTask<String, Void>`](https://developer.apple.com/documentation/swiftui/backgroundtask/urlsession(matching:))
- [`var id: Value.ID`](https://developer.apple.com/documentation/swiftui/binding/id)
- [`var id: Value.ID`](https://developer.apple.com/documentation/swiftui/binding/id)
- [`init(_:)`](https://developer.apple.com/documentation/swiftui/binding/init(_:))
- [`subscript(_:)`](https://developer.apple.com/documentation/swiftui/binding/subscript(_:))
- [`var transaction: Transaction`](https://developer.apple.com/documentation/swiftui/binding/transaction)
- [`func transaction(Transaction) -> Binding<Value>`](https://developer.apple.com/documentation/swiftui/binding/transaction(_:))
- [`BorderedTextFieldStyle`](https://developer.apple.com/documentation/swiftui/borderedtextfieldstyle)
- [`init()`](https://developer.apple.com/documentation/swiftui/borderedtextfieldstyle/init())
- [`init(PrimitiveButtonStyleConfiguration)`](https://developer.apple.com/documentation/swiftui/button/init(_:))
- [`init(_:image:action:)`](https://developer.apple.com/documentation/swiftui/button/init(_:image:action:))
- [`init(_:image:role:action:)`](https://developer.apple.com/documentation/swiftui/button/init(_:image:role:action:))
- [`init(_:image:role:intent:)`](https://developer.apple.com/documentation/swiftui/button/init(_:image:role:intent:))
- [`init(_:role:intent:)`](https://developer.apple.com/documentation/swiftui/button/init(_:role:intent:))
- [`init(_:systemImage:role:intent:)`](https://developer.apple.com/documentation/swiftui/button/init(_:systemimage:role:intent:))
- [`init(role: ButtonRole, action: () -> Void)`](https://developer.apple.com/documentation/swiftui/button/init(role:action:))
- [`init(role: ButtonRole?, intent: some AppIntent, label: () -> Label)`](https://developer.apple.com/documentation/swiftui/button/init(role:intent:label:))
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
- [`init?(UIUserInterfaceStyle)`](https://developer.apple.com/documentation/swiftui/colorscheme/init(_:))
- [`init?(UIAccessibilityContrast)`](https://developer.apple.com/documentation/swiftui/colorschemecontrast/init(_:))
- [`ColumnNavigationViewStyle`](https://developer.apple.com/documentation/swiftui/columnnavigationviewstyle)
- [`static func buildBlock<C0, C1>(C0, C1) -> some Commands`](https://developer.apple.com/documentation/swiftui/commandsbuilder/buildblock(_:_:))
- [`static func buildBlock<C0, C1, C2>(C0, C1, C2) -> some Commands`](https://developer.apple.com/documentation/swiftui/commandsbuilder/buildblock(_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3>(C0, C1, C2, C3) -> some Commands`](https://developer.apple.com/documentation/swiftui/commandsbuilder/buildblock(_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4>(C0, C1, C2, C3, C4) -> some Commands`](https://developer.apple.com/documentation/swiftui/commandsbuilder/buildblock(_:_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4, C5>(C0, C1, C2, C3, C4, C5) -> some Commands`](https://developer.apple.com/documentation/swiftui/commandsbuilder/buildblock(_:_:_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4, C5, C6>(C0, C1, C2, C3, C4, C5, C6) -> some Commands`](https://developer.apple.com/documentation/swiftui/commandsbuilder/buildblock(_:_:_:_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7>(C0, C1, C2, C3, C4, C5, C6, C7) -> some Commands`](https://developer.apple.com/documentation/swiftui/commandsbuilder/buildblock(_:_:_:_:_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8>(C0, C1, C2, C3, C4, C5, C6, C7, C8) -> some Commands`](https://developer.apple.com/documentation/swiftui/commandsbuilder/buildblock(_:_:_:_:_:_:_:_:_:))
- [`static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8, C9>(C0, C1, C2, C3, C4, C5, C6, C7, C8, C9) -> some Commands`](https://developer.apple.com/documentation/swiftui/commandsbuilder/buildblock(_:_:_:_:_:_:_:_:_:_:))
- [`ContainerBackgroundPlacement`](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement)
- [`static let navigation: ContainerBackgroundPlacement`](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement/navigation)
- [`static let navigationSplitView: ContainerBackgroundPlacement`](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement/navigationsplitview)
- [`static var subscriptionStore: ContainerBackgroundPlacement`](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement/subscriptionstore)
- [`static var subscriptionStoreFullHeight: ContainerBackgroundPlacement`](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement/subscriptionstorefullheight)
- [`static var subscriptionStoreHeader: ContainerBackgroundPlacement`](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement/subscriptionstoreheader)
- [`static let widget: ContainerBackgroundPlacement`](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement/widget)
- [`func hasTag<V>(V) -> Bool`](https://developer.apple.com/documentation/swiftui/containervalues/hastag(_:))
- [`func tag<V>(for: V.Type) -> V?`](https://developer.apple.com/documentation/swiftui/containervalues/tag(for:))
- [`ContentBuilder`](https://developer.apple.com/documentation/swiftui/contentbuilder)
- [`ContentMarginGuide`](https://developer.apple.com/documentation/swiftui/contentmarginguide)
- [`static var container: ContentMarginGuide`](https://developer.apple.com/documentation/swiftui/contentmarginguide/container)
- [`ContentSizeCategory`](https://developer.apple.com/documentation/swiftui/contentsizecategory)
- [`static func < (ContentSizeCategory, ContentSizeCategory) -> Bool`](https://developer.apple.com/documentation/swiftui/contentsizecategory/_(_:_:)-1iyos)
- [`static func > (ContentSizeCategory, ContentSizeCategory) -> Bool`](https://developer.apple.com/documentation/swiftui/contentsizecategory/_(_:_:)-61nui)
- [`static func <= (ContentSizeCategory, ContentSizeCategory) -> Bool`](https://developer.apple.com/documentation/swiftui/contentsizecategory/_=(_:_:)-3lvd8)
- [`static func >= (ContentSizeCategory, ContentSizeCategory) -> Bool`](https://developer.apple.com/documentation/swiftui/contentsizecategory/_=(_:_:)-3tkt4)
- [`case accessibilityExtraExtraExtraLarge`](https://developer.apple.com/documentation/swiftui/contentsizecategory/accessibilityextraextraextralarge)
- [`case accessibilityExtraExtraLarge`](https://developer.apple.com/documentation/swiftui/contentsizecategory/accessibilityextraextralarge)
- [`case accessibilityExtraLarge`](https://developer.apple.com/documentation/swiftui/contentsizecategory/accessibilityextralarge)
- [`case accessibilityLarge`](https://developer.apple.com/documentation/swiftui/contentsizecategory/accessibilitylarge)
- [`case accessibilityMedium`](https://developer.apple.com/documentation/swiftui/contentsizecategory/accessibilitymedium)
- [`case extraExtraExtraLarge`](https://developer.apple.com/documentation/swiftui/contentsizecategory/extraextraextralarge)
- [`case extraExtraLarge`](https://developer.apple.com/documentation/swiftui/contentsizecategory/extraextralarge)
- [`case extraLarge`](https://developer.apple.com/documentation/swiftui/contentsizecategory/extralarge)
- [`case extraSmall`](https://developer.apple.com/documentation/swiftui/contentsizecategory/extrasmall)
- [`init?(UIContentSizeCategory)`](https://developer.apple.com/documentation/swiftui/contentsizecategory/init(_:))
- [`var isAccessibilityCategory: Bool`](https://developer.apple.com/documentation/swiftui/contentsizecategory/isaccessibilitycategory)
- [`case large`](https://developer.apple.com/documentation/swiftui/contentsizecategory/large)
- [`case medium`](https://developer.apple.com/documentation/swiftui/contentsizecategory/medium)
- [`case small`](https://developer.apple.com/documentation/swiftui/contentsizecategory/small)
- [`ContentToolbarPlacement`](https://developer.apple.com/documentation/swiftui/contenttoolbarplacement)
- [`static let tabViewSidebar: ContentToolbarPlacement`](https://developer.apple.com/documentation/swiftui/contenttoolbarplacement/tabviewsidebar)
- [`init(_:image:description:)`](https://developer.apple.com/documentation/swiftui/contentunavailableview/init(_:image:description:))
- [`ContextMenu`](https://developer.apple.com/documentation/swiftui/contextmenu)
- [`init(menuItems: () -> MenuItems)`](https://developer.apple.com/documentation/swiftui/contextmenu/init(menuitems:))
- [`init(ControlGroupStyleConfiguration)`](https://developer.apple.com/documentation/swiftui/controlgroup/init(_:))
- [`init(_:content:)`](https://developer.apple.com/documentation/swiftui/controlgroup/init(_:content:))
- [`init(_:image:content:)`](https://developer.apple.com/documentation/swiftui/controlgroup/init(_:image:content:))
- [`init(_:systemImage:content:)`](https://developer.apple.com/documentation/swiftui/controlgroup/init(_:systemimage:content:))
- [`Body`](https://developer.apple.com/documentation/swiftui/controlgroupstyle/body)
- [`ControlGroupStyle.Configuration`](https://developer.apple.com/documentation/swiftui/controlgroupstyle/configuration)
- [`func makeBody(configuration: Self.Configuration) -> Self.Body`](https://developer.apple.com/documentation/swiftui/controlgroupstyle/makebody(configuration:))
- [`static var menu: MenuControlGroupStyle`](https://developer.apple.com/documentation/swiftui/controlgroupstyle/menu)
- [`ControlGroupStyleConfiguration`](https://developer.apple.com/documentation/swiftui/controlgroupstyleconfiguration)
- [`let content: ControlGroupStyleConfiguration.Content`](https://developer.apple.com/documentation/swiftui/controlgroupstyleconfiguration/content-swift.property)
- [`ControlGroupStyleConfiguration.Content`](https://developer.apple.com/documentation/swiftui/controlgroupstyleconfiguration/content-swift.struct)
- [`let label: ControlGroupStyleConfiguration.Label`](https://developer.apple.com/documentation/swiftui/controlgroupstyleconfiguration/label-swift.property)
- [`ControlGroupStyleConfiguration.Label`](https://developer.apple.com/documentation/swiftui/controlgroupstyleconfiguration/label-swift.struct)
- [`ControlWidget`](https://developer.apple.com/documentation/swiftui/controlwidget)
- [`Body`](https://developer.apple.com/documentation/swiftui/controlwidget/body-swift.associatedtype)
- [`var body: Self.Body`](https://developer.apple.com/documentation/swiftui/controlwidget/body-swift.property)
- [`init()`](https://developer.apple.com/documentation/swiftui/controlwidget/init())
- [`static func main()`](https://developer.apple.com/documentation/swiftui/controlwidget/main())
- [`ControlWidgetConfiguration`](https://developer.apple.com/documentation/swiftui/controlwidgetconfiguration)
- [`Body`](https://developer.apple.com/documentation/swiftui/controlwidgetconfiguration/body-swift.associatedtype)
- [`var body: Self.Body`](https://developer.apple.com/documentation/swiftui/controlwidgetconfiguration/body-swift.property)
- [`func description(LocalizedStringResource) -> some ControlWidgetConfiguration`](https://developer.apple.com/documentation/swiftui/controlwidgetconfiguration/description(_:))
- [`func displayName(LocalizedStringResource) -> some ControlWidgetConfiguration`](https://developer.apple.com/documentation/swiftui/controlwidgetconfiguration/displayname(_:))
- [`func promptsForUserConfiguration() -> some ControlWidgetConfiguration`](https://developer.apple.com/documentation/swiftui/controlwidgetconfiguration/promptsforuserconfiguration())
- [`func pushHandler(any ControlPushHandler.Type) -> some ControlWidgetConfiguration`](https://developer.apple.com/documentation/swiftui/controlwidgetconfiguration/pushhandler(_:))
- [`ControlWidgetConfigurationBuilder`](https://developer.apple.com/documentation/swiftui/controlwidgetconfigurationbuilder)
- [`static func buildBlock<Content>(Content) -> some ControlWidgetConfiguration`](https://developer.apple.com/documentation/swiftui/controlwidgetconfigurationbuilder/buildblock(_:))
- [`static func buildExpression<Content>(Content) -> Content`](https://developer.apple.com/documentation/swiftui/controlwidgetconfigurationbuilder/buildexpression(_:))
- [`ControlWidgetTemplate`](https://developer.apple.com/documentation/swiftui/controlwidgettemplate)
- [`Body`](https://developer.apple.com/documentation/swiftui/controlwidgettemplate/body-swift.associatedtype)
- [`var body: Self.Body`](https://developer.apple.com/documentation/swiftui/controlwidgettemplate/body-swift.property)
- [`func disabled(Bool) -> some ControlWidgetTemplate`](https://developer.apple.com/documentation/swiftui/controlwidgettemplate/disabled(_:))
- [`func privacySensitive(Bool) -> some ControlWidgetTemplate`](https://developer.apple.com/documentation/swiftui/controlwidgettemplate/privacysensitive(_:))
- [`func tint(Color?) -> some ControlWidgetTemplate`](https://developer.apple.com/documentation/swiftui/controlwidgettemplate/tint(_:))
- [`ControlWidgetTemplateBuilder`](https://developer.apple.com/documentation/swiftui/controlwidgettemplatebuilder)
- [`static func buildBlock<Content>(Content) -> some ControlWidgetTemplate`](https://developer.apple.com/documentation/swiftui/controlwidgettemplatebuilder/buildblock(_:))
- [`static func buildExpression<Content>(Content) -> Content`](https://developer.apple.com/documentation/swiftui/controlwidgettemplatebuilder/buildexpression(_:))
- [`var isGlobal: Bool`](https://developer.apple.com/documentation/swiftui/coordinatespace/isglobal)
- [`var isLocal: Bool`](https://developer.apple.com/documentation/swiftui/coordinatespace/islocal)
- [`CustomHoverEffect`](https://developer.apple.com/documentation/swiftui/customhovereffect)
- [`static var automatic: AutomaticHoverEffect`](https://developer.apple.com/documentation/swiftui/customhovereffect/automatic)
- [`Body`](https://developer.apple.com/documentation/swiftui/customhovereffect/body)
- [`func body(content: Self.Content) -> Self.Body`](https://developer.apple.com/documentation/swiftui/customhovereffect/body(content:))
- [`func body(content: Self.Content) -> Self.Body`](https://developer.apple.com/documentation/swiftui/customhovereffect/body(content:)-1hbi3)
- [`CustomHoverEffect.Content`](https://developer.apple.com/documentation/swiftui/customhovereffect/content)
- [`static var highlight: HighlightHoverEffect`](https://developer.apple.com/documentation/swiftui/customhovereffect/highlight)
- [`func hoverEffectDisabled(Bool) -> some CustomHoverEffect`](https://developer.apple.com/documentation/swiftui/customhovereffect/hovereffectdisabled(_:))
- [`static var lift: LiftHoverEffect`](https://developer.apple.com/documentation/swiftui/customhovereffect/lift)
- [`CustomizableToolbarContent`](https://developer.apple.com/documentation/swiftui/customizabletoolbarcontent)
- [`func axisBehavior(ToolbarItemAxisBehavior) -> some CustomizableToolbarContent`](https://developer.apple.com/documentation/swiftui/customizabletoolbarcontent/axisbehavior(_:))
- [`func contentMarginsRemoved(Bool) -> some CustomizableToolbarContent`](https://developer.apple.com/documentation/swiftui/customizabletoolbarcontent/contentmarginsremoved(_:))
- [`func customizationBehavior(ToolbarCustomizationBehavior) -> some CustomizableToolbarContent`](https://developer.apple.com/documentation/swiftui/customizabletoolbarcontent/customizationbehavior(_:))
- [`func defaultCustomization(Visibility, options: ToolbarCustomizationOptions) -> some CustomizableToolbarContent`](https://developer.apple.com/documentation/swiftui/customizabletoolbarcontent/defaultcustomization(_:options:))
- [`func hidden(Bool) -> some CustomizableToolbarContent`](https://developer.apple.com/documentation/swiftui/customizabletoolbarcontent/hidden(_:))
- [`func matchedTransitionSource(id: some Hashable, in: Namespace.ID) -> some CustomizableToolbarContent`](https://developer.apple.com/documentation/swiftui/customizabletoolbarcontent/matchedtransitionsource(id:in:))
- [`func sharedBackgroundVisibility(Visibility) -> some CustomizableToolbarContent`](https://developer.apple.com/documentation/swiftui/customizabletoolbarcontent/sharedbackgroundvisibility(_:))
- [`func visibilityPriority(ToolbarItemVisibilityPriority) -> some CustomizableToolbarContent`](https://developer.apple.com/documentation/swiftui/customizabletoolbarcontent/visibilitypriority(_:))
- [`CustomPresentationDetent`](https://developer.apple.com/documentation/swiftui/custompresentationdetent)
- [`CustomPresentationDetent.Context`](https://developer.apple.com/documentation/swiftui/custompresentationdetent/context)
- [`static func height(in: Self.Context) -> CGFloat?`](https://developer.apple.com/documentation/swiftui/custompresentationdetent/height(in:))
- [`Body`](https://developer.apple.com/documentation/swiftui/datepickerstyle/body)
- [`DatePickerStyle.Configuration`](https://developer.apple.com/documentation/swiftui/datepickerstyle/configuration)
- [`func makeBody(configuration: Self.Configuration) -> Self.Body`](https://developer.apple.com/documentation/swiftui/datepickerstyle/makebody(configuration:))
- [`DatePickerStyleConfiguration`](https://developer.apple.com/documentation/swiftui/datepickerstyleconfiguration)
- [`var $selection: Binding<Date>`](https://developer.apple.com/documentation/swiftui/datepickerstyleconfiguration/$selection)
- [`var displayedComponents: DatePickerComponents`](https://developer.apple.com/documentation/swiftui/datepickerstyleconfiguration/displayedcomponents)
- [`let label: DatePickerStyleConfiguration.Label`](https://developer.apple.com/documentation/swiftui/datepickerstyleconfiguration/label-swift.property)
- [`DatePickerStyleConfiguration.Label`](https://developer.apple.com/documentation/swiftui/datepickerstyleconfiguration/label-swift.struct)
- [`var maximumDate: Date?`](https://developer.apple.com/documentation/swiftui/datepickerstyleconfiguration/maximumdate)
- [`var minimumDate: Date?`](https://developer.apple.com/documentation/swiftui/datepickerstyleconfiguration/minimumdate)
- [`var selection: Date`](https://developer.apple.com/documentation/swiftui/datepickerstyleconfiguration/selection)
- [`DebugReplaceableView`](https://developer.apple.com/documentation/swiftui/debugreplaceableview)
- [`DebugReplaceableView`](https://developer.apple.com/documentation/swiftui/debugreplaceableview)
- [`DefaultButtonLabel`](https://developer.apple.com/documentation/swiftui/defaultbuttonlabel)
- [`DefaultDateProgressLabel`](https://developer.apple.com/documentation/swiftui/defaultdateprogresslabel)
- [`DefaultDocumentGroupLaunchActions`](https://developer.apple.com/documentation/swiftui/defaultdocumentgrouplaunchactions)
- [`init()`](https://developer.apple.com/documentation/swiftui/defaultdocumentgrouplaunchactions/init())
- [`DefaultNavigationViewStyle`](https://developer.apple.com/documentation/swiftui/defaultnavigationviewstyle)
- [`init()`](https://developer.apple.com/documentation/swiftui/defaultnavigationviewstyle/init())
- [`DefaultNewDocumentButtonLabel`](https://developer.apple.com/documentation/swiftui/defaultnewdocumentbuttonlabel)
- [`DefaultShareLinkLabel`](https://developer.apple.com/documentation/swiftui/defaultsharelinklabel)
- [`DefaultTabLabel`](https://developer.apple.com/documentation/swiftui/defaulttablabel)
- [`DefaultTabLabel`](https://developer.apple.com/documentation/swiftui/defaulttablabel)
- [`DisabledTextSelectability`](https://developer.apple.com/documentation/swiftui/disabledtextselectability)
- [`var $isExpanded: Binding<Bool>`](https://developer.apple.com/documentation/swiftui/disclosuregroupstyleconfiguration/$isexpanded)
- [`DismissBehavior`](https://developer.apple.com/documentation/swiftui/dismissbehavior)
- [`static let destructive: DismissBehavior`](https://developer.apple.com/documentation/swiftui/dismissbehavior/destructive)
- [`static let interactive: DismissBehavior`](https://developer.apple.com/documentation/swiftui/dismissbehavior/interactive)
- [`DocumentBaseBox`](https://developer.apple.com/documentation/swiftui/documentbasebox)
- [`var base: Self.Document?`](https://developer.apple.com/documentation/swiftui/documentbasebox/base)
- [`Document`](https://developer.apple.com/documentation/swiftui/documentbasebox/document)
- [`init(editing:contentType:editor:prepareDocument:)`](https://developer.apple.com/documentation/swiftui/documentgroup/init(editing:contenttype:editor:preparedocument:))
- [`init(editing: UTType, migrationPlan: any SchemaMigrationPlan.Type, editor: () -> Content, prepareDocument: (ModelContext) -> Void)`](https://developer.apple.com/documentation/swiftui/documentgroup/init(editing:migrationplan:editor:preparedocument:))
- [`init(viewing:contentType:viewer:)`](https://developer.apple.com/documentation/swiftui/documentgroup/init(viewing:contenttype:viewer:))
- [`init(viewing: UTType, migrationPlan: any SchemaMigrationPlan.Type, viewer: () -> Content)`](https://developer.apple.com/documentation/swiftui/documentgroup/init(viewing:migrationplan:viewer:))
- [`DocumentGroupLaunchScene`](https://developer.apple.com/documentation/swiftui/documentgrouplaunchscene)
- [`init(_:_:background:)`](https://developer.apple.com/documentation/swiftui/documentgrouplaunchscene/init(_:_:background:))
- [`init(_:_:background:backgroundAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentgrouplaunchscene/init(_:_:background:backgroundaccessoryview:))
- [`init(_:_:background:backgroundAccessoryView:overlayAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentgrouplaunchscene/init(_:_:background:backgroundaccessoryview:overlayaccessoryview:))
- [`init(_:_:background:overlayAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentgrouplaunchscene/init(_:_:background:overlayaccessoryview:))
- [`init(_:backgroundStyle:_:)`](https://developer.apple.com/documentation/swiftui/documentgrouplaunchscene/init(_:backgroundstyle:_:))
- [`init(_:backgroundStyle:_:backgroundAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentgrouplaunchscene/init(_:backgroundstyle:_:backgroundaccessoryview:))
- [`init(_:backgroundStyle:_:backgroundAccessoryView:overlayAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentgrouplaunchscene/init(_:backgroundstyle:_:backgroundaccessoryview:overlayaccessoryview:))
- [`init(_:backgroundStyle:_:overlayAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentgrouplaunchscene/init(_:backgroundstyle:_:overlayaccessoryview:))
- [`DocumentLaunchGeometryProxy`](https://developer.apple.com/documentation/swiftui/documentlaunchgeometryproxy)
- [`var frame: CGRect`](https://developer.apple.com/documentation/swiftui/documentlaunchgeometryproxy/frame)
- [`var titleViewFrame: CGRect`](https://developer.apple.com/documentation/swiftui/documentlaunchgeometryproxy/titleviewframe)
- [`DocumentLaunchView`](https://developer.apple.com/documentation/swiftui/documentlaunchview)
- [`var body: some View`](https://developer.apple.com/documentation/swiftui/documentlaunchview/body)
- [`init(_:for:_:onDocumentOpen:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:_:ondocumentopen:))
- [`init(_:for:_:onDocumentOpen:background:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:_:ondocumentopen:background:))
- [`init(_:for:_:onDocumentOpen:background:backgroundAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:_:ondocumentopen:background:backgroundaccessoryview:))
- [`init(_:for:_:onDocumentOpen:background:backgroundAccessoryView:overlayAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:_:ondocumentopen:background:backgroundaccessoryview:overlayaccessoryview:))
- [`init(_:for:_:onDocumentOpen:background:overlayAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:_:ondocumentopen:background:overlayaccessoryview:))
- [`init(_:for:_:onDocumentOpen:backgroundAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:_:ondocumentopen:backgroundaccessoryview:))
- [`init(_:for:_:onDocumentOpen:backgroundAccessoryView:overlayAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:_:ondocumentopen:backgroundaccessoryview:overlayaccessoryview:))
- [`init(_:for:_:onDocumentOpen:overlayAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:_:ondocumentopen:overlayaccessoryview:))
- [`init(_:for:backgroundStyle:_:onDocumentOpen:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:backgroundstyle:_:ondocumentopen:))
- [`init(_:for:backgroundStyle:_:onDocumentOpen:backgroundAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:backgroundstyle:_:ondocumentopen:backgroundaccessoryview:))
- [`init(_:for:backgroundStyle:_:onDocumentOpen:backgroundAccessoryView:overlayAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:backgroundstyle:_:ondocumentopen:backgroundaccessoryview:overlayaccessoryview:))
- [`init(_:for:backgroundStyle:_:onDocumentOpen:overlayAccessoryView:)`](https://developer.apple.com/documentation/swiftui/documentlaunchview/init(_:for:backgroundstyle:_:ondocumentopen:overlayaccessoryview:))
- [`DoubleColumnNavigationViewStyle`](https://developer.apple.com/documentation/swiftui/doublecolumnnavigationviewstyle)
- [`init()`](https://developer.apple.com/documentation/swiftui/doublecolumnnavigationviewstyle/init())
- [`DragConfiguration`](https://developer.apple.com/documentation/swiftui/dragconfiguration)
- [`init(allowMove: Bool)`](https://developer.apple.com/documentation/swiftui/dragconfiguration/init(allowmove:))
- [`init(operationsWithinApp: DragConfiguration.OperationsWithinApp, operationsOutsideApp: DragConfiguration.OperationsOutsideApp)`](https://developer.apple.com/documentation/swiftui/dragconfiguration/init(operationswithinapp:operationsoutsideapp:))
- [`var operationsOutsideApp: DragConfiguration.OperationsOutsideApp`](https://developer.apple.com/documentation/swiftui/dragconfiguration/operationsoutsideapp-swift.property)
- [`DragConfiguration.OperationsOutsideApp`](https://developer.apple.com/documentation/swiftui/dragconfiguration/operationsoutsideapp-swift.struct)
- [`init(allowCopy: Bool)`](https://developer.apple.com/documentation/swiftui/dragconfiguration/operationsoutsideapp-swift.struct/init(allowcopy:))
- [`var operationsWithinApp: DragConfiguration.OperationsWithinApp`](https://developer.apple.com/documentation/swiftui/dragconfiguration/operationswithinapp-swift.property)
- [`DragConfiguration.OperationsWithinApp`](https://developer.apple.com/documentation/swiftui/dragconfiguration/operationswithinapp-swift.struct)
- [`init(allowMove: Bool)`](https://developer.apple.com/documentation/swiftui/dragconfiguration/operationswithinapp-swift.struct/init(allowmove:))
- [`init(minimumDistance: CGFloat, coordinateSpace: some CoordinateSpaceProtocol, inputKinds: GestureInputKinds)`](https://developer.apple.com/documentation/swiftui/draggesture/init(minimumdistance:coordinatespace:inputkinds:))
- [`DragSession`](https://developer.apple.com/documentation/swiftui/dragsession)
- [`func draggedItemIDs<ItemID>(for: ItemID.Type) -> [ItemID]`](https://developer.apple.com/documentation/swiftui/dragsession/draggeditemids(for:))
- [`var draggedItemIndex: Int`](https://developer.apple.com/documentation/swiftui/dragsession/draggeditemindex)
- [`var id: DragSession.ID`](https://developer.apple.com/documentation/swiftui/dragsession/id-swift.property)
- [`DragSession.ID`](https://developer.apple.com/documentation/swiftui/dragsession/id-swift.struct)
- … and 1761 more (`isim/data/api-coverage.json.gz`)

</details>
<!-- /generated:missing -->
