# WidgetKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 66.5% of Apple's iOS API (177 of 266, exact) · **Rows:** 9: 5 ✅ 1 🟡 3 ❌ · **iOS:** 14.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [WidgetKit](https://developer.apple.com/documentation/widgetkit) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Adapted:** widget extensions run as helper processes, and isim's SwiftUI renders their entries into images that the home screen and lock screen draw.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| WidgetKit (home/lock screen widgets, timelines) | 🟡 | ≤17 | widget extensions (`@main` Widget/WidgetBundle, entry `_NSExtensionMain`) run as helper processes: `StaticConfiguration` / `AppIntentConfiguration`, `TimelineProvider` / `AppIntentTimelineProvider`, entries rendered by isim SwiftUI into images, shown by date, reload by policy and `WidgetCenter.reloadTimelines`; widget gallery (Edit Home Screen > +) with each widget's snapshot (`getSnapshot` / `snapshot(for:in:)`, `context.isPreview`), small/medium/large on the home screen, `supportedFamilies`; a new widget shows `placeholder(in:)` redacted (`.redacted(reason: .placeholder)`) until its first timeline arrives; `containerBackground`, `contentMarginsDisabled`, `widgetContentMargins`, `widgetFamily`; interactive widgets (`Button(intent:)` runs the AppIntent in the extension, then reloads); a tap elsewhere opens the app with `widgetURL`, a `Link` with its URL; widget menu (long press): Edit Widget shows the `WidgetConfigurationIntent`'s `@Parameter`s (AppEnum choices, Bool, String, Int, Double; adapted: read by reflection) and the timeline reloads with the chosen values, Remove Widget; Lock Screen accessory widgets (`accessoryCircular` / `accessoryRectangular` under the clock, up to four units, `accessoryInline` next to the date) added in the Lock Screen editor (long press on the Lock Screen; adapted: no wallpaper gallery step), rendered with `widgetRenderingMode` `.vibrant` (adapted: luminance as white opacity), `showsWidgetContainerBackground` false, `AccessoryWidgetBackground`; a tap opens the app; `.accented` on the iOS 18+ tinted Home Screen (adapted: `widgetAccentable` content in the tint, the rest white, on a dark tinted background); StandBy (script `standby on`: landscape, the first two small widgets side by side, full colour without their container backgrounds; an empty side shows a clock); `WidgetCenter.currentConfigurations` (home screen pages and Lock Screen). Stub: `TimelineEntry.relevance` is kept, there are no Smart Stacks; AppEntity parameters are not offered in Edit Widget; no StandBy night mode. Tested (HelloWidgets: test_widgets, test_widgets_lockscreen) |
| Widget and Live Activity previews (`#Preview(_:as:widget:timeline:)`, `#Preview(_:as:widget:timelineProvider:)`, `#Preview(_:as:using:widget:timelineProvider:)`, `#Preview(_:as:using:widget:contentStates:)`, `PreviewTimelineBuilder`, `PreviewActivityBuilder`, `ActivityPreviewViewKind`, `WidgetPreviewContext`) | ✅ | ≤17 | adapted: isim's PreviewsMacros plugin expands them like SwiftUI's `#Preview`; `isim preview App.app --list` finds them in the widget extension and `isim preview App.app NAME` renders every timeline entry (from the `timeline:` builder, or the provider's timeline; with `using:` the intent's) or every Live Activity content state (`.content`: the Lock Screen presentation on its tint; `.dynamicIsland(.compact / .expanded / .minimal)`) the way the widget extension renders them for the home screen, captioned, one under another on a grey canvas (Xcode's canvas shows one at a time with a timeline scrubber). `previewContext(WidgetPreviewContext(family:))` frames a view at the family's size. Tested (HelloWidgets: test_widget_previews) |
| SiriKit intent configuration: `IntentConfiguration`, `IntentTimelineProvider`, `IntentRecommendation` / `AppIntentRecommendation` and `recommendations()`, `WidgetInfo` | ✅ | ≤17 | adapted: a widget configured by a SiriKit custom intent (an `INIntent` subclass from an `.intentdefinition`) renders like an `AppIntentConfiguration` one. Edit Widget lists the intent's parameters from the `.intentdefinition` in the extension's bundle (enums with their cases, Booleans, strings, numbers, custom types by display string), or from the class's `@NSManaged` properties when there is none; the chosen values are set on the intent the provider gets (`getSnapshot` / `getTimeline(for:in:completion:)`). Recommendations are listed with the extension's widgets (the log names them; on iOS the system uses them where a widget cannot be configured, which isim does not have). `WidgetInfo` (the type `currentConfigurations` returns) has `widgetConfigurationIntent(of:)` with the values chosen in Edit Widget; its `configuration` (an IntentConfiguration's intent) is nil on isim. Tested (HelloWidgets: test_intent_configured_widget, per iOS version) |
| Accented images: `WidgetAccentedRenderingMode`, `Image.widgetAccentedRenderingMode(_:)` | ✅ | 18.0 | adapted: on the tinted Home Screen (accented rendering) the host draws the widget once more without each mode's images and puts their pixels back: `.fullColor` as drawn, `.desaturated` grey, `.accentedDesaturated` grey in the tint, `.accented` in the tint (like `widgetAccentable`). Tested (HelloWidgets: test_accented_image_modes) |
| Live Activity sizes: `ActivityFamily`, `supplementalActivityFamilies(_:)`, `EnvironmentValues.activityFamily` | ✅ | 18.0 | adapted: the Lock Screen presentation is `.medium`; an activity that supports `.small` is also drawn at the small size (172 × 76 pt, `activityFamily` `.small`) and saved as `small.png` beside the other presentations. isim has no Apple Watch Smart Stack or CarPlay to show it. Tested (HelloWidgets: test_small_live_activity) |
| Widget pushes: `WidgetPushHandler`, `WidgetPushInfo`, `pushHandler(_:)` | ✅ | 26.0 | adapted: the extension's handler gets a push token (stable per app on the device) with the widgets in use the first time one of them renders; a push with `"apns-push-type": "widgets"` (`push BUNDLE_ID FILE`, docs/SCRIPTING.md) reloads that app's widgets that have a push handler, like Apple's push service. No server or device token is involved. Tested (HelloWidgets: test_widget_push) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `WidgetLocation` (1 type; with its members under "Not yet in isim") |
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `ControlPushHandler`, `ControlPushInfo`, `WidgetRelevance`, `WidgetRelevanceAttribute`, `WidgetRelevanceGroup` (5 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 26) | ❌ | 26.0 | not implemented, found by the 2026-10 sweep: `LevelOfDetail`, `WidgetMountingStyle` (2 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
89 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`ActivityPreviewViewKind.DynamicIslandPreviewViewState`](https://developer.apple.com/documentation/widgetkit/activitypreviewviewkind/dynamicislandpreviewviewstate)
- [`case compact`](https://developer.apple.com/documentation/widgetkit/activitypreviewviewkind/dynamicislandpreviewviewstate/compact)
- [`case expanded`](https://developer.apple.com/documentation/widgetkit/activitypreviewviewkind/dynamicislandpreviewviewstate/expanded)
- [`case minimal`](https://developer.apple.com/documentation/widgetkit/activitypreviewviewkind/dynamicislandpreviewviewstate/minimal)
- [`init<Provider>(kind: String, provider: Provider, content: (Provider.Value) -> Content)`](https://developer.apple.com/documentation/widgetkit/appintentcontrolconfiguration/init(kind:provider:content:))
- [`func relevance() async -> WidgetRelevance<Self.Intent>`](https://developer.apple.com/documentation/widgetkit/appintenttimelineprovider/relevance())
- [`func relevance() async -> WidgetRelevance<Self.Intent>`](https://developer.apple.com/documentation/widgetkit/appintenttimelineprovider/relevance()-9vl5j)
- [`func configurationIntent<Intent>(of: Intent.Type) -> Intent?`](https://developer.apple.com/documentation/widgetkit/controlinfo/configurationintent(of:))
- [`var id: String`](https://developer.apple.com/documentation/widgetkit/controlinfo/id)
- [`var pushInfo: ControlPushInfo?`](https://developer.apple.com/documentation/widgetkit/controlinfo/pushinfo)
- [`ControlPushHandler`](https://developer.apple.com/documentation/widgetkit/controlpushhandler)
- [`init()`](https://developer.apple.com/documentation/widgetkit/controlpushhandler/init())
- [`func pushTokensDidChange(controls: [ControlInfo])`](https://developer.apple.com/documentation/widgetkit/controlpushhandler/pushtokensdidchange(controls:))
- [`ControlPushInfo`](https://developer.apple.com/documentation/widgetkit/controlpushinfo)
- [`let token: Data`](https://developer.apple.com/documentation/widgetkit/controlpushinfo/token)
- [`init(LocalizedStringResource, action: Action, actionLabel: (Bool) -> ActionLabel)`](https://developer.apple.com/documentation/widgetkit/controlwidgetbutton/init(_:action:actionlabel:)-1kxch)
- [`init(some StringProtocol, action: Action, actionLabel: (Bool) -> ActionLabel)`](https://developer.apple.com/documentation/widgetkit/controlwidgetbutton/init(_:action:actionlabel:)-4sgji)
- [`init(LocalizedStringKey, action: Action, actionLabel: (Bool) -> ActionLabel)`](https://developer.apple.com/documentation/widgetkit/controlwidgetbutton/init(_:action:actionlabel:)-67uvw)
- [`ControlWidgetButtonDefaultActionLabel`](https://developer.apple.com/documentation/widgetkit/controlwidgetbuttondefaultactionlabel)
- [`ControlWidgetToggleDefaultLabel`](https://developer.apple.com/documentation/widgetkit/controlwidgettoggledefaultlabel)
- [`DynamicIslandExpandedContent`](https://developer.apple.com/documentation/widgetkit/dynamicislandexpandedcontent)
- [`static func buildPartialBlock<C0, C1>(accumulated: DynamicIslandExpandedContent<C0>, next: DynamicIslandExpandedContent<C1>) -> DynamicIslandExpandedContent<some View>
`](https://developer.apple.com/documentation/widgetkit/dynamicislandexpandedcontentbuilder/buildpartialblock(accumulated:next:)-39sr0)
- [`static func buildPartialBlock<C0, C1>(accumulated: DynamicIslandExpandedContent<C0>, next: DynamicIslandExpandedRegion<C1>) -> DynamicIslandExpandedContent<some View>
`](https://developer.apple.com/documentation/widgetkit/dynamicislandexpandedcontentbuilder/buildpartialblock(accumulated:next:)-3jswv)
- [`static func buildPartialBlock<C>(first: DynamicIslandExpandedRegion<C>) -> DynamicIslandExpandedContent<some View>
`](https://developer.apple.com/documentation/widgetkit/dynamicislandexpandedcontentbuilder/buildpartialblock(first:)-5j108)
- [`static func buildPartialBlock<C>(first: DynamicIslandExpandedContent<C>) -> DynamicIslandExpandedContent<some View>
`](https://developer.apple.com/documentation/widgetkit/dynamicislandexpandedcontentbuilder/buildpartialblock(first:)-74hpw)
- [`func contentMargins(Edge.Set, Double) -> DynamicIslandExpandedRegion<Content>`](https://developer.apple.com/documentation/widgetkit/dynamicislandexpandedregion/contentmargins(_:_:))
- [`DynamicIslandExpandedRegionVerticalPlacement`](https://developer.apple.com/documentation/widgetkit/dynamicislandexpandedregionverticalplacement)
- [`static let belowIfTooWide: DynamicIslandExpandedRegionVerticalPlacement`](https://developer.apple.com/documentation/widgetkit/dynamicislandexpandedregionverticalplacement/belowiftoowide)
- [`static let `default`: DynamicIslandExpandedRegionVerticalPlacement`](https://developer.apple.com/documentation/widgetkit/dynamicislandexpandedregionverticalplacement/default)
- [`static let compactLeading: DynamicIslandMode`](https://developer.apple.com/documentation/widgetkit/dynamicislandmode/compactleading)
- [`static let compactTrailing: DynamicIslandMode`](https://developer.apple.com/documentation/widgetkit/dynamicislandmode/compacttrailing)
- [`func relevance() async -> WidgetRelevance<Self.Intent>`](https://developer.apple.com/documentation/widgetkit/intenttimelineprovider/relevance())
- [`func relevance() async -> WidgetRelevance<Self.Intent>`](https://developer.apple.com/documentation/widgetkit/intenttimelineprovider/relevance()-4bbqo)
- [`LevelOfDetail`](https://developer.apple.com/documentation/widgetkit/levelofdetail)
- [`static let `default`: LevelOfDetail`](https://developer.apple.com/documentation/widgetkit/levelofdetail/default)
- [`static let simplified: LevelOfDetail`](https://developer.apple.com/documentation/widgetkit/levelofdetail/simplified)
- [`let NSUserActivityTypeLiveActivity: String`](https://developer.apple.com/documentation/widgetkit/nsuseractivitytypeliveactivity)
- [`static func buildPartialBlock(accumulated: [A.ContentState], next: [A.ContentState]) -> [A.ContentState]`](https://developer.apple.com/documentation/widgetkit/previewactivitybuilder/buildpartialblock(accumulated:next:))
- [`static func buildPartialBlock(accumulated: [A.ContentState], next: [A.ContentState]) -> [A.ContentState]`](https://developer.apple.com/documentation/widgetkit/previewactivitybuilder/buildpartialblock(accumulated:next:))
- [`static func buildPartialBlock(first: [A.ContentState]) -> [A.ContentState]`](https://developer.apple.com/documentation/widgetkit/previewactivitybuilder/buildpartialblock(first:))
- [`static func buildPartialBlock(first: [A.ContentState]) -> [A.ContentState]`](https://developer.apple.com/documentation/widgetkit/previewactivitybuilder/buildpartialblock(first:))
- [`static func buildPartialBlock(accumulated: [any TimelineEntry], next: [any TimelineEntry]) -> [any TimelineEntry]`](https://developer.apple.com/documentation/widgetkit/previewtimelinebuilder/buildpartialblock(accumulated:next:))
- [`static func buildPartialBlock(accumulated: [any TimelineEntry], next: [any TimelineEntry]) -> [any TimelineEntry]`](https://developer.apple.com/documentation/widgetkit/previewtimelinebuilder/buildpartialblock(accumulated:next:))
- [`static func buildPartialBlock(first: [any TimelineEntry]) -> [any TimelineEntry]`](https://developer.apple.com/documentation/widgetkit/previewtimelinebuilder/buildpartialblock(first:))
- [`static func buildPartialBlock(first: [any TimelineEntry]) -> [any TimelineEntry]`](https://developer.apple.com/documentation/widgetkit/previewtimelinebuilder/buildpartialblock(first:))
- [`SupportedActivityFamiliesEnvironmentKey`](https://developer.apple.com/documentation/widgetkit/supportedactivityfamiliesenvironmentkey)
- [`func relevance() async -> WidgetRelevance<Void>`](https://developer.apple.com/documentation/widgetkit/timelineprovider/relevance())
- [`func relevance() async -> WidgetRelevance<Void>`](https://developer.apple.com/documentation/widgetkit/timelineprovider/relevance()-7036j)
- [`let environmentVariants: TimelineProviderContext.EnvironmentVariants`](https://developer.apple.com/documentation/widgetkit/timelineprovidercontext/environmentvariants-swift.property)
- [`TimelineProviderContext.EnvironmentVariants`](https://developer.apple.com/documentation/widgetkit/timelineprovidercontext/environmentvariants-swift.struct)
- [`subscript<T>(WritableKeyPath<EnvironmentValues, T>) -> [T]?`](https://developer.apple.com/documentation/widgetkit/timelineprovidercontext/environmentvariants-swift.struct/subscript(_:))
- [`subscript<T>(dynamicMember _: WritableKeyPath<EnvironmentValues, T>) -> [T]?`](https://developer.apple.com/documentation/widgetkit/timelineprovidercontext/environmentvariants-swift.struct/subscript(dynamicmember:))
- [`func currentConfigurations() async throws -> [WidgetInfo]`](https://developer.apple.com/documentation/widgetkit/widgetcenter/currentconfigurations())
- [`var currentPushInfo: WidgetPushInfo?`](https://developer.apple.com/documentation/widgetkit/widgetcenter/currentpushinfo)
- [`func invalidateConfigurationRecommendations()`](https://developer.apple.com/documentation/widgetkit/widgetcenter/invalidateconfigurationrecommendations())
- [`func invalidateRelevance(ofKind: String)`](https://developer.apple.com/documentation/widgetkit/widgetcenter/invalidaterelevance(ofkind:))
- [`WidgetCenter.UserInfoKey`](https://developer.apple.com/documentation/widgetkit/widgetcenter/userinfokey)
- [`static let activityID: String`](https://developer.apple.com/documentation/widgetkit/widgetcenter/userinfokey/activityid)
- [`static let family: String`](https://developer.apple.com/documentation/widgetkit/widgetcenter/userinfokey/family)
- [`static let kind: String`](https://developer.apple.com/documentation/widgetkit/widgetcenter/userinfokey/kind)
- [`case systemExtraLargePortrait`](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemextralargeportrait)
- [`let configuration: INIntent?`](https://developer.apple.com/documentation/widgetkit/widgetinfo/configuration)
- [`let family: WidgetFamily`](https://developer.apple.com/documentation/widgetkit/widgetinfo/family)
- [`var id: WidgetInfo`](https://developer.apple.com/documentation/widgetkit/widgetinfo/id)
- [`var id: WidgetInfo`](https://developer.apple.com/documentation/widgetkit/widgetinfo/id)
- [`let kind: String`](https://developer.apple.com/documentation/widgetkit/widgetinfo/kind)
- [`func widgetConfigurationIntent<Intent>(of: Intent.Type) -> Intent?`](https://developer.apple.com/documentation/widgetkit/widgetinfo/widgetconfigurationintent(of:))
- [`WidgetLocation`](https://developer.apple.com/documentation/widgetkit/widgetlocation)
- [`static let carPlay: WidgetLocation`](https://developer.apple.com/documentation/widgetkit/widgetlocation/carplay)
- [`static let homeScreen: WidgetLocation`](https://developer.apple.com/documentation/widgetkit/widgetlocation/homescreen)
- [`static let iPhoneWidgetsOnMac: WidgetLocation`](https://developer.apple.com/documentation/widgetkit/widgetlocation/iphonewidgetsonmac)
- [`static let lockScreen: WidgetLocation`](https://developer.apple.com/documentation/widgetkit/widgetlocation/lockscreen)
- [`static let standBy: WidgetLocation`](https://developer.apple.com/documentation/widgetkit/widgetlocation/standby)
- [`WidgetMountingStyle`](https://developer.apple.com/documentation/widgetkit/widgetmountingstyle)
- [`static let elevated: WidgetMountingStyle`](https://developer.apple.com/documentation/widgetkit/widgetmountingstyle/elevated)
- [`static let recessed: WidgetMountingStyle`](https://developer.apple.com/documentation/widgetkit/widgetmountingstyle/recessed)
- [`WidgetRelevance`](https://developer.apple.com/documentation/widgetkit/widgetrelevance)
- [`init([WidgetRelevanceAttribute<Configuration>])`](https://developer.apple.com/documentation/widgetkit/widgetrelevance/init(_:))
- [`WidgetRelevanceAttribute`](https://developer.apple.com/documentation/widgetkit/widgetrelevanceattribute)
- [`init(configuration: Configuration, context: RelevantContext)`](https://developer.apple.com/documentation/widgetkit/widgetrelevanceattribute/init(configuration:context:)-8325r)
- [`init(configuration: Configuration, context: RelevantContext)`](https://developer.apple.com/documentation/widgetkit/widgetrelevanceattribute/init(configuration:context:)-8jxhs)
- [`init(configuration: Configuration, group: WidgetRelevanceGroup)`](https://developer.apple.com/documentation/widgetkit/widgetrelevanceattribute/init(configuration:group:)-5yh17)
- [`init(configuration: Configuration, group: WidgetRelevanceGroup)`](https://developer.apple.com/documentation/widgetkit/widgetrelevanceattribute/init(configuration:group:)-93jm5)
- [`init(context: RelevantContext)`](https://developer.apple.com/documentation/widgetkit/widgetrelevanceattribute/init(context:))
- [`init(group: WidgetRelevanceGroup)`](https://developer.apple.com/documentation/widgetkit/widgetrelevanceattribute/init(group:))
- [`WidgetRelevanceGroup`](https://developer.apple.com/documentation/widgetkit/widgetrelevancegroup)
- [`static let automatic: WidgetRelevanceGroup`](https://developer.apple.com/documentation/widgetkit/widgetrelevancegroup/automatic)
- [`static func named(String) -> WidgetRelevanceGroup`](https://developer.apple.com/documentation/widgetkit/widgetrelevancegroup/named(_:))
- [`static let ungrouped: WidgetRelevanceGroup`](https://developer.apple.com/documentation/widgetkit/widgetrelevancegroup/ungrouped)

</details>
<!-- /generated:missing -->
