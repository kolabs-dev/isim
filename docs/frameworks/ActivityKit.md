# ActivityKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 56.0% of Apple's iOS API (61 of 109, exact) · **Rows:** 1: 1 ✅ · **iOS:** 16.1+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [ActivityKit](https://developer.apple.com/documentation/activitykit) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Adapted:** Live Activities are records that the shell draws on the lock screen and in the Dynamic Island.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| ActivityKit (Live Activities, Dynamic Island) | ✅ | ≤17 | `Activity.request/update/end`, `activities` (also those started by a push or an earlier run), `ActivityAuthorizationInfo` (NSSupportsLiveActivities); the widget extension's `ActivityConfiguration` renders the lock-screen view (with `activityBackgroundTint`, `widgetURL`: a tap opens the app) and the Dynamic Island compact/minimal/expanded regions, `DynamicIsland.contentMargins(_:_:for: DynamicIslandMode)` (expanded: 22 / 14 pt by default); the shell draws them on the lock screen (several, by relevance) and around the island: compact for one activity, minimal for two (the most relevant attached, the other detached on the trailing side; estimated geometry), tap / script `island` expands; `contentUpdates`, `activityStateUpdates` (active → stale → ended → dismissed), `staleDate` (rendered again with `context.isStale` when it passes); `update(_:alertConfiguration:)` and push alerts: the island expands for 4 s (no island: a banner), on the lock screen the activity lights up; dismissal policies `.immediate`, `.after(date)`, `.default` (out of the island at once, on the lock screen until then, at most 4 h); push updates (adapted: the home screen stands in for APNs): `pushType: .token`, `pushToken`, `pushTokenUpdates`, `isim push` / script `push` with a liveactivity payload (`aps.event` update / end / start, `content-state`, `timestamp` (older ones ignored), `stale-date`, `dismissal-date`, `relevance-score`, `alert`), push-to-start (iOS 17.2: `pushToStartToken`, `pushToStartTokenUpdates`, `attributes-type` / `attributes`, `Activity.activityUpdates`). Not on isim: broadcast channel pushes (`pushType: .channel`), `frequentPushesEnabled`, Live Activities in StandBy. Tested (HelloWidgets: test_widgets, test_live_activity_push) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
48 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`Activity.ActivityStateUpdates.Element`](https://developer.apple.com/documentation/activitykit/activity/activitystateupdates-swift.struct/element)
- [`Activity.ActivityStateUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activity/activitystateupdates-swift.struct/iterator)
- [`func makeAsyncIterator() -> Activity<Attributes>.ActivityStateUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activity/activitystateupdates-swift.struct/makeasynciterator())
- [`Activity.ActivityUpdates.Element`](https://developer.apple.com/documentation/activitykit/activity/activityupdates-swift.struct/element)
- [`Activity.ActivityUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activity/activityupdates-swift.struct/iterator)
- [`func makeAsyncIterator() -> Activity<Attributes>.ActivityUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activity/activityupdates-swift.struct/makeasynciterator())
- [`Activity.ContentState`](https://developer.apple.com/documentation/activitykit/activity/contentstate-swift.typealias)
- [`Activity.ContentUpdates.Element`](https://developer.apple.com/documentation/activitykit/activity/contentupdates-swift.struct/element)
- [`Activity.ContentUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activity/contentupdates-swift.struct/iterator)
- [`func makeAsyncIterator() -> Activity<Attributes>.ContentUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activity/contentupdates-swift.struct/makeasynciterator())
- [`Activity.PushTokenUpdates.Element`](https://developer.apple.com/documentation/activitykit/activity/pushtokenupdates-swift.struct/element)
- [`Activity.PushTokenUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activity/pushtokenupdates-swift.struct/iterator)
- [`func makeAsyncIterator() -> Activity<Attributes>.PushTokenUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activity/pushtokenupdates-swift.struct/makeasynciterator())
- [`func previewContext(Self.ContentState, isStale: Bool, viewKind: ActivityPreviewViewKind) -> some View`](https://developer.apple.com/documentation/activitykit/activityattributes/previewcontext(_:isstale:viewkind:))
- [`case attributesTooLarge`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/attributestoolarge)
- [`case denied`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/denied)
- [`var errorCode: Int`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/errorcode)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/errordomain)
- [`var failureReason: String?`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/failurereason)
- [`case globalMaximumExceeded`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/globalmaximumexceeded)
- [`case malformedActivityIdentifier`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/malformedactivityidentifier)
- [`case missingProcessIdentifier`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/missingprocessidentifier)
- [`case persistenceFailure`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/persistencefailure)
- [`case reconnectNotPermitted`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/reconnectnotpermitted)
- [`var recoverySuggestion: String?`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/recoverysuggestion)
- [`case targetMaximumExceeded`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/targetmaximumexceeded)
- [`case unentitled`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/unentitled)
- [`case unsupported`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/unsupported)
- [`case unsupportedTarget`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/unsupportedtarget)
- [`case visibility`](https://developer.apple.com/documentation/activitykit/activityauthorizationerror/visibility)
- [`let activityEnablementUpdates: ActivityAuthorizationInfo.ActivityEnablementUpdates`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/activityenablementupdates-swift.property)
- [`ActivityAuthorizationInfo.ActivityEnablementUpdates`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/activityenablementupdates-swift.struct)
- [`ActivityAuthorizationInfo.ActivityEnablementUpdates.Element`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/activityenablementupdates-swift.struct/element)
- [`ActivityAuthorizationInfo.ActivityEnablementUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/activityenablementupdates-swift.struct/iterator)
- [`func next() async -> Bool?`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/activityenablementupdates-swift.struct/iterator/next())
- [`func makeAsyncIterator() -> ActivityAuthorizationInfo.ActivityEnablementUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/activityenablementupdates-swift.struct/makeasynciterator())
- [`let frequentPushEnablementUpdates: ActivityAuthorizationInfo.FrequentPushEnablementUpdates`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/frequentpushenablementupdates-swift.property)
- [`ActivityAuthorizationInfo.FrequentPushEnablementUpdates`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/frequentpushenablementupdates-swift.struct)
- [`ActivityAuthorizationInfo.FrequentPushEnablementUpdates.Element`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/frequentpushenablementupdates-swift.struct/element)
- [`ActivityAuthorizationInfo.FrequentPushEnablementUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/frequentpushenablementupdates-swift.struct/iterator)
- [`func next() async -> Bool?`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/frequentpushenablementupdates-swift.struct/iterator/next())
- [`func makeAsyncIterator() -> ActivityAuthorizationInfo.FrequentPushEnablementUpdates.Iterator`](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/frequentpushenablementupdates-swift.struct/makeasynciterator())
- [`ActivityStyle`](https://developer.apple.com/documentation/activitykit/activitystyle)
- [`case standard`](https://developer.apple.com/documentation/activitykit/activitystyle/standard)
- [`case transient`](https://developer.apple.com/documentation/activitykit/activitystyle/transient)
- [`var body: LocalizedStringResource`](https://developer.apple.com/documentation/activitykit/alertconfiguration/body)
- [`var sound: AlertConfiguration.AlertSound`](https://developer.apple.com/documentation/activitykit/alertconfiguration/sound)
- [`var title: LocalizedStringResource`](https://developer.apple.com/documentation/activitykit/alertconfiguration/title)

</details>
<!-- /generated:missing -->
