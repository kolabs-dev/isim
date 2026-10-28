# VisualIntelligence

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Imaging, photos & ML](../COVERAGE.md#ml) · **Apple:** [VisualIntelligence](https://developer.apple.com/documentation/visualintelligence) · **Issues:** [`area:ml`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aml)

## How isim implements it

- **Approach:** isim's Swift overlay (`isim/swift/overlays/VisualIntelligence`) and AppIntents' `IntentValueQuery`
  (`isim/swift/overlays/AppIntents/ValueQueries.swift`). On iOS 26 Visual Intelligence classifies what the camera or
  the screen shows and asks the apps' value queries over `SemanticContentDescriptor` for matching results. isim has no
  classifier: the `visualintelligence LABEL[,LABEL...]` script command ([SCRIPTING.md](../SCRIPTING.md)) says what is
  seen. SpringBoard asks every app whose metadata lists a query over `SemanticContentDescriptor` (the app runs in the
  background, like an App Intent), and logs each app's results:
  `SpringBoard: Visual Intelligence: APP: TITLE (SUBTITLE), ...` or `no results`.
- **Objective-C / C interface:** Swift only (as on iOS).
- **Results sheet:** once every app has answered, the results show in a sheet over the screen, a tab per app that found
  something, with its results' titles and subtitles; choosing one opens it with the app's `OpenIntent` for the
  result's entity type (the entity as its target), or opens the app when it has none (#691). The sheet's sizes are
  estimated from Apple's documentation screenshots; there is no "More results" link. Script ids: `vi-sheet`, `vi-tab-N`,
  `vi-result-N`, `vi-close`.
- **Versus Apple's Simulator:** there is no camera or screen classifier: the labels are script input. `pixelBuffer` is not there yet (CoreVideo's
  `CVReadOnlyPixelBuffer`, iOS 26, is not in isim).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `SemanticContentDescriptor` (`labels`) | ✅ | 26.0 | adapted: the labels the `visualintelligence` command gives; tested (HelloImagePlayground, test_visual_intelligence) |
| `SemanticContentDescriptor.pixelBuffer`, `defaultResolverSpecification` | ❌ | 26.0 | not yet (`CVReadOnlyPixelBuffer`, AppIntents' resolver specifications) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
