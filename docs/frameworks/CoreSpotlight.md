# CoreSpotlight

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (788 of 788, exact) · **Rows:** 8: 8 ✅ · **iOS:** 9.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [CoreSpotlight](https://developer.apple.com/documentation/corespotlight) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Adapted:** a per-app plist index (`<isim data>/Library/Spotlight/<bundle id>.plist`) that the home screen's search
  reads. Each item keeps every attribute of its attribute set (and its custom attributes), so `CSSearchQuery` runs
  Spotlight's query language over them and `CSUserQuery` searches what the user types.
- **Adapted:** Spotlight asking the app: `isim spotlight reindex|items|throttle APP` reaches the running app's
  `CSSearchableIndexDelegate` (a Darwin notification and a request file), else the app's index extension, which
  SpringBoard runs as a helper process. Import extensions run for documents of the types they declare in the app's
  Documents. Summaries (iOS 18) are the text content's first two sentences (isim has no Apple Intelligence model).
- Protection classes are kept, not enforced (isim's files have no data protection).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Spotlight (`CSSearchableItem`), `NSUserActivity` indexing | ✅ | ≤17 | adapted: `CSSearchableIndex` index/delete (ids, domains, all), named indexes with a protection class, batches with a client state (`beginBatch`, `endBatch(withClientState:)`, `endIndexBatch(expectedClientState:newClientState:)` with `mismatchedClientState`, `fetchLastClientState`), `isUpdate` items that merge into the indexed one, `fetchData(forBundleIdentifier:itemIdentifier:contentType:)`, async variants; activities with `isEligibleForSearch`; the home screen's Spotlight finds them and continues `CSSearchableItemActionType` / the activity in the app. Tested (homescreen, HelloScenes, tests/ui/test_spotlight_index.py) |
| `CSSearchableItemAttributeSet`: all of Apple's attributes, `CSPerson`, `CSCustomAttributeKey`, `CSLocalizedString` | ✅ | ≤17 | adapted: the 188 attributes (general, documents, media, images, events, places, messages, …) are stored with the item, custom attributes with `setValue(_:forCustomKey:)`; `init(contentType:)`, `sharedItemContentType`, `NSSecureCoding`. Tested (tests/ui/test_spotlight_index.py: HelloSpotlight) |
| `CSSearchQuery`, `CSSearchQueryContext`, `CSSearchQueryError` | ✅ | ≤17 | adapted: Spotlight's query language over the app's items: `==`, `!=`, `<`, `>`, `<=`, `>=`, `InRange`, `&&`, `\|\|`, `!`, `*` wildcards with the `c`, `d`, `w`, `t` modifiers, `$time.now`/`today`/`yesterday`/… with offsets, `kMDItem…` names and `*` for any text attribute; the context's `fetchAttributes`, `filterQueries` and `sourceOptions`; `foundItemCount`, `cancel()`, the `results` async sequence (iOS 18); an invalid query fails with `invalidQuery` (-2002). Tested (tests/ui/test_spotlight_index.py) |
| `CSUserQuery`, `CSUserQueryContext`, `CSSuggestion` | ✅ | 18.0 | adapted: word-prefix search of what the user types over titles, descriptions, keywords and the other text attributes, ranked (engagement and recency raise a result), with suggestions; `responses` / `suggestions` async sequences, `userEngaged`; no semantic search (`disableSemanticSearch` has no effect). Tested (tests/ui/test_spotlight_index.py) |
| `CSSearchableIndexDelegate`, `CSIndexExtensionRequestHandler`, `CSImportExtension`, `updateListenerOptions` | ✅ | ≤17 | adapted: reindex all / some identifiers, items by identifier (iOS 18), throttling, from `isim spotlight`; the running app's delegate answers, else its index extension (`com.apple.spotlight.index`); import extensions (`com.apple.spotlight.import`, `CSSupportedContentTypes`) fill in the attributes of new or changed documents in Documents, which are indexed with the file's URL and leave the index when the file is deleted; items with `.summarization` get a `textContentSummary` and the delegate's `searchableItemsDidUpdate` (iOS 18; the first two sentences). Tested (tests/ui/test_spotlight_index.py) |
| Objective-C interface (`CoreSpotlight.framework`): every class above, `CSSearchableIndexDelegate`, the constants, `CSIndexErrorDomain` and `CSSearchQueryErrorDomain` | ✅ | ≤17 | adapted: headers over the Swift overlay's classes (Apple's Objective-C names and selectors), `initWithContentType:` with UniformTypeIdentifiers' `UTType`. Tested (HelloServicesObjC, tests/ui/test_services_objc.py) |
| `SpotlightSearchTool` (iOS 27, a Foundation Models `Tool`): `Configuration` (sources, `Guide` / `GuidanceLevel` / `GuidanceProfile` / `ContentDomain` / `FormatLevel`, `contactResolver`, `customStages`, `maximumResponseSize`), `searchResults` / `SearchReply` (content, status, tokens); the pipeline: `SearchSource` (`coreSpotlight`, `files`), `CoreSpotlightSource`, `FileSource`, `CustomStage`, `SearchPipelineData` / `SearchPipelineDataType`, `SearchableItem`, `ScoredSearchableItem`, `SearchResultsTable`, `SearchCount`, `SearchStatistic`, `SearchTextResult`, `SearchableItemAttribute` (Apple's 176 attributes), `ContactResolver`, `ResolvedContact` | ✅ | 27.0 | adapted: the model's arguments (`query`: words or a Spotlight query, `groupBy`, `limit`; Apple's own argument schema is not documented) run as a `CSSearchQuery` over the app's index (words match the title, display name, description, text and keywords) and as a name search of the file source's folders; custom stages then transform the results in order, as their input types allow; each call is a reply on `searchResults` and its summary is the tool's output. The guide and the resolved contact go into the tool's description. Tested (HelloSpotlight, test_spotlight_index.py: test_spotlight_search_tool) |
| `CSSearchableIndexDescription` (a class, iOS 18; `protectionClass` iOS 27), `CSSearchableItem(appEntity:)` / `(appEntity:priority:)` (and their iOS 27 async forms), `relatedAppEntityIdentifier` on items and attribute sets, `CSSearchableItemAttributeSet.associateAppEntity(_:priority:)` | ✅ | 18.0 | adapted: the item carries the entity (it opens it when chosen in Spotlight). `CSSearchableIndexDescription` was a struct in isim's AppIntents before 0.35 (an ABI break, isim/abi/epochs.txt). Proposed: no test exercises these yet |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
