# Accessibility

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 80.4% of Apple's iOS API (213 of 265, exact) · **Rows:** 11: 10 ✅ 1 ❌ · **iOS:** 14.0+
<!-- /generated:header -->

**Area:** [Accessibility & Info.plist](../COVERAGE.md#a11y) · **Apple:** [Accessibility](https://developer.apple.com/documentation/accessibility) · **Issues:** [`area:a11y`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aa11y)

## How isim implements it

- **Approach:** isim's own Objective-C framework (`isim/frameworks/Accessibility`), with a Swift overlay
  (`isim/swift/overlays/Accessibility`) for the Swift-only API; the assistive technologies it
  feeds are isim's simulated VoiceOver, Switch Control and Voice Control in UIKit (`isim/frameworks/UIKit/UIAccessibilityRuntime.m`,
  script commands `voiceover …` in [SCRIPTING.md](../SCRIPTING.md)).
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/Accessibility`; Swift imports them (`AXCustomContent.Importance`).
- **Versus Apple's Simulator:** Apple's Simulator has no VoiceOver; isim's speaks to the log (`isim: VoiceOver: "…"`)
  and, with audio, through espeak-ng.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `AXCustomContent` (`init(label:value:)`, `init(attributedLabel:attributedValue:)`, `label`, `value`, `attributedLabel`, `attributedValue`, `importance`), `AXCustomContent.Importance`, `AXCustomContentProvider` (`accessibilityCustomContent`, `accessibilityCustomContentBlock`), `AXCustomContentReturnBlock` | ✅ | ≤17 | adapted: isim's VoiceOver reads an element's custom content (its `accessibilityCustomContent` or block, or SwiftUI's `accessibilityCustomContent`): high-importance entries after the element's description ("label, value"), default-importance ones one at a time in the rotor's More Content. NSCopying / NSSecureCoding. Tested through SwiftUI (HelloSwiftUI -accessibility, test_swiftui_accessibility) |
| `AccessibilityNotification` (`Announcement` from a `String`, `AttributedString` or `NSAttributedString`; `LayoutChanged`; `ScreenChanged`; `PageScrolled`; each with `post()`) | ✅ | 17.0 | adapted: posted through UIKit's `UIAccessibility.post`, so isim's VoiceOver speaks announcements and page scrolls (and posts `UIAccessibility.announcementDidFinishNotification`), and moves its focus on layout and screen changes; each is logged (`isim: accessibility notification …`). Tested (HelloAccessibility `-extras`, tests/ui/test_accessibility_extras.py) |
| `AccessibilitySettings`: `animatedImagesEnabled`, `prefersHorizontalTextLayout`, `prefersNonBlinkingTextInsertionIndicator`, `isAssistiveAccessEnabled`, `prefersHeadAnchorAlternative` and their `…DidChangeNotification`s; `openSettings(for:)`, `Feature` | ✅ | 18.0 | adapted: the device's Settings > Accessibility values, read like UIKit's `UIAccessibility` settings. Defaults are iOS's: animated images on, the rest off; head-anchored content is visionOS's, so always off. The `accessibility` script command changes them and posts the notifications ([SCRIPTING.md](../SCRIPTING.md)). `openSettings(for:)` opens isim's Settings app at Accessibility. `Feature`'s raw values after `personalVoiceAllowAppsToRequestToUse` (1) are proposed. Tested (HelloAccessibility `-extras`, os_matrix) |
| `AccessibilitySettings` (iOS 26.1–27): `showBordersEnabled`, `prefersActionSliderAlternative`, `isReduceHighlightingEffectsEnabled`, `isApplicationAccessibilityEnabled` (VoiceOver or Switch Control running), `canOpenSettings(for:)`, their notifications, `ApplicationAccessibilityEnabledDidChangeMessage` | ✅ | 26.1 | adapted, like the iOS 18 settings; `canOpenSettings(for:)` is always true. `isApplicationAccessibilityEnabled`'s notification is not posted yet (declared). Not tested by a sample |
| `AXAnimatedImagesEnabled()`, `AXPrefersHorizontalTextLayout()`, `AXAnimatedImagesEnabledDidChangeNotification`, `AXPrefersHorizontalTextLayoutDidChangeNotification` (C, also Swift) | ✅ | 17.0 | the same settings, from C and Objective-C (`<Accessibility/AXSettings.h>`). Tested (`AXAnimatedImagesEnabled` from Swift) |
| Audio graphs: `AXChart` (`accessibilityChartDescriptor`), `AXChartDescriptor` (`init(title:summary:xAxis:yAxis:additionalAxes:series:)`, `attributedTitle`, `summary`, `contentDirection`, `contentFrame`, `series`, `xAxis`, `yAxis`, `additionalAxes`), `AXChartDescriptor.ContentDirection`, `AXDataAxisDescriptor`, `AXNumericDataAxisDescriptor` (`range`, `scaleType`, `gridlinePositions`, `valueDescriptionProvider`), `AXNumericDataAxisDescriptor.ScaleType`, `AXCategoricalDataAxisDescriptor`, `AXDataSeriesDescriptor`, `AXDataPoint` (`init(x:y:additionalValues:label:)`, `AXDataPoint.Value`), `AXDataPointValue` | ✅ | 15.0 | adapted: isim's VoiceOver offers the rotor's Audio Graph on an element with a chart descriptor (`AXChart`, or SwiftUI's `accessibilityChartDescriptor(_:)`): Describe Chart speaks the title, summary, axes (ranges through `valueDescriptionProvider`, or categories) and number of series; Play Audio Graph plays each series through isim's audio, the y value as pitch (220–880 Hz on the y axis' scale, linear or logarithmic), a glide for a continuous series and a tone per point for a discrete one, and logs what it played; Chart Details speaks each series' count, minimum, maximum and mean (iOS shows a full-screen Audio Graph view there). The Objective-C classes are Apple's (`<Accessibility/AXChart.h>`), refined for Swift like Apple's. Tested (HelloSwiftUI `-audiograph`, tests/ui/test_audio_graph.py; Objective-C in HelloServicesObjC) |
| `AXLiveAudioGraph` (`start()`, `updateValue(_:)`, `stop()`) | ✅ | 15.0 | adapted: each value (0…1) plays a short tone at its pitch (220–880 Hz) and is logged. Tested (HelloSwiftUI `-audiograph`) |
| Math: `AXMathExpressionProvider` (`accessibilityMathExpression()`), `AXMathExpression` and `AXMathExpressionNumber`, `Identifier`, `Operator`, `Text`, `Row`, `Fenced`, `Fraction`, `Root`, `SubSuperscript`, `UnderOver`, `Multiscript`, `Table`, `TableRow`, `TableCell` | ✅ | 18.2 | adapted: isim's VoiceOver reads an element's expression after its label, as speech: operators as words ("plus", "equals", "plus or minus"), "start fraction, … over …, end fraction", "square root of …, end root", "squared" / "cubed" / "to the … power", fences as "open paren … close paren". Apple's spellings kept (`denimonatorExpression`). Tested (HelloSwiftUI `-axmath`, tests/ui/test_accessibility_math.py, os_matrix) |
| Braille translation: `AXBrailleTranslator` (`translatePrintText(_:)`, `backTranslateBraille(_:)`), `AXBrailleTable` (`init(identifier:)`, `tables(for:)`, `defaultTable(for:)`, `supportedLocales()`, `languageAgnosticTables()`, `identifier`, `localizedName`, `language`, `locales`, `isEightDot`, `providerIdentifier`, `localizedProviderName`), `AXBrailleTranslationResult` (`resultString`, `inputIndex(forResultIndex:)`) | ✅ | 26.0 | adapted: over the host's liblouis (`runtime/host_braille.c`, loaded when first used; a host dependency like espeak-ng). The tables are liblouis's language tables (`org.liblouis.<file>`); translation gives Unicode braille (U+2800…), back-translation reads it, and the input index comes from liblouis' positions. The default for a locale is six-dot, back-translatable, contracted where there is a choice (Unified English Braille grade 2 for English). Without liblouis there are no tables and translations come back empty (logged). `languageAgnosticTables()` are liblouis' computer braille and NABCC tables. Tested (HelloSwiftUI `-axmath`, iOS 26 and 27) |
| `AXFeatureOverrideSessionManager` (`sharedInstance`, `beginOverrideSession(enabling:disabling:)`, `end(_:)`), `AXFeatureOverrideSession` (`Options`: `voiceOver`, `zoom`, `grayscale`, `invertColors`, `voiceControl`), `AXFeatureOverrideSessionError`, `AXFeatureOverrideSessionErrorDomain` | ✅ | 18.2 | adapted: needs the `com.apple.developer.accessibility.feature-override` entitlement (else `.appNotEntitled`); while a session runs, isim's VoiceOver follows it and `UIAccessibility.isGrayscaleEnabled` / `isInvertColorsEnabled` report it (with their notifications); ending it restores Settings. One session at a time (`.overrideIsAlreadyActive`); ending an ended session gives `.overrideNotFoundForUUID`. isim does not draw the screen in grayscale or inverted; Zoom and Voice Control are recorded only. The options' and error codes' raw values are proposed (Apple does not document them). Tested (HelloSwiftUI `-axmath` without the entitlement; HelloServicesObjC with it) |
| The rest of the framework (`AXBrailleMap` for braille displays, `AccessibilityRequest`, `AccessibilityTechnology`) | ❌ | 15.2 | not provided: isim has no braille displays |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
52 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`AccessibilityRequest`](https://developer.apple.com/documentation/accessibility/accessibilityrequest)
- [`class var current: AccessibilityRequest?`](https://developer.apple.com/documentation/accessibility/accessibilityrequest/current)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/accessibility/accessibilityrequest/init(coder:))
- [`var technology: AccessibilityTechnology`](https://developer.apple.com/documentation/accessibility/accessibilityrequest/technology)
- [`AccessibilityTechnology`](https://developer.apple.com/documentation/accessibility/accessibilitytechnology)
- [`static let automation: AccessibilityTechnology`](https://developer.apple.com/documentation/accessibility/accessibilitytechnology/automation)
- [`static let fullKeyboardAccess: AccessibilityTechnology`](https://developer.apple.com/documentation/accessibility/accessibilitytechnology/fullkeyboardaccess)
- [`static let hoverText: AccessibilityTechnology`](https://developer.apple.com/documentation/accessibility/accessibilitytechnology/hovertext)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/accessibility/accessibilitytechnology/init(rawvalue:))
- [`static let speakScreen: AccessibilityTechnology`](https://developer.apple.com/documentation/accessibility/accessibilitytechnology/speakscreen)
- [`static let switchControl: AccessibilityTechnology`](https://developer.apple.com/documentation/accessibility/accessibilitytechnology/switchcontrol)
- [`static let voiceControl: AccessibilityTechnology`](https://developer.apple.com/documentation/accessibility/accessibilitytechnology/voicecontrol)
- [`static let voiceOver: AccessibilityTechnology`](https://developer.apple.com/documentation/accessibility/accessibilitytechnology/voiceover)
- [`static let zoom: AccessibilityTechnology`](https://developer.apple.com/documentation/accessibility/accessibilitytechnology/zoom)
- [`AXBrailleMap`](https://developer.apple.com/documentation/accessibility/axbraillemap)
- [`var dimensions: CGSize`](https://developer.apple.com/documentation/accessibility/axbraillemap/dimensions)
- [`func height(at: CGPoint) -> Float`](https://developer.apple.com/documentation/accessibility/axbraillemap/height(at:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/accessibility/axbraillemap/init(coder:))
- [`func present(CGImage)`](https://developer.apple.com/documentation/accessibility/axbraillemap/present(_:))
- [`func setHeight(Float, at: CGPoint)`](https://developer.apple.com/documentation/accessibility/axbraillemap/setheight(_:at:))
- [`subscript(CGPoint) -> Float`](https://developer.apple.com/documentation/accessibility/axbraillemap/subscript(_:))
- [`AXBrailleMapRenderer`](https://developer.apple.com/documentation/accessibility/axbraillemaprenderer)
- [`var accessibilityBrailleMapRenderer: (AXBrailleMap) -> Void`](https://developer.apple.com/documentation/accessibility/axbraillemaprenderer/accessibilitybraillemaprenderer)
- [`var accessibilityBrailleMapRenderRegion: CGRect`](https://developer.apple.com/documentation/accessibility/axbraillemaprenderer/accessibilitybraillemaprenderregion)
- [`case bottomToTop`](https://developer.apple.com/documentation/accessibility/axchartdescriptor/contentdirection-swift.enum/bottomtotop)
- [`case leftToRight`](https://developer.apple.com/documentation/accessibility/axchartdescriptor/contentdirection-swift.enum/lefttoright)
- [`case radialClockwise`](https://developer.apple.com/documentation/accessibility/axchartdescriptor/contentdirection-swift.enum/radialclockwise)
- [`case radialCounterClockwise`](https://developer.apple.com/documentation/accessibility/axchartdescriptor/contentdirection-swift.enum/radialcounterclockwise)
- [`case rightToLeft`](https://developer.apple.com/documentation/accessibility/axchartdescriptor/contentdirection-swift.enum/righttoleft)
- [`case topToBottom`](https://developer.apple.com/documentation/accessibility/axchartdescriptor/contentdirection-swift.enum/toptobottom)
- [`AXFeatureOverrideSessionError.Code`](https://developer.apple.com/documentation/accessibility/axfeatureoverridesessionerror-swift.struct/code)
- [`case appNotEntitled`](https://developer.apple.com/documentation/accessibility/axfeatureoverridesessionerror-swift.struct/code/appnotentitled)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/accessibility/axfeatureoverridesessionerror-swift.struct/code/init(rawvalue:))
- [`case overrideIsAlreadyActive`](https://developer.apple.com/documentation/accessibility/axfeatureoverridesessionerror-swift.struct/code/overrideisalreadyactive)
- [`case overrideNotFoundForUUID`](https://developer.apple.com/documentation/accessibility/axfeatureoverridesessionerror-swift.struct/code/overridenotfoundforuuid)
- [`case undefined`](https://developer.apple.com/documentation/accessibility/axfeatureoverridesessionerror-swift.struct/code/undefined)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/accessibility/axfeatureoverridesessionerror-swift.struct/errordomain)
- [`AXMFiHearingDevice`](https://developer.apple.com/documentation/accessibility/axmfihearingdevice)
- [`AXMFiHearingDevice.Ear`](https://developer.apple.com/documentation/accessibility/axmfihearingdevice/ear)
- [`static var both: AXMFiHearingDevice.Ear`](https://developer.apple.com/documentation/accessibility/axmfihearingdevice/ear/both)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/accessibility/axmfihearingdevice/ear/init(rawvalue:))
- [`static var left: AXMFiHearingDevice.Ear`](https://developer.apple.com/documentation/accessibility/axmfihearingdevice/ear/left)
- [`static var right: AXMFiHearingDevice.Ear`](https://developer.apple.com/documentation/accessibility/axmfihearingdevice/ear/right)
- [`static func pairedDeviceIdentifiers() -> [UUID]`](https://developer.apple.com/documentation/accessibility/axmfihearingdevice/paireddeviceidentifiers())
- [`static let pairedUUIDsDidChangeNotification: NSNotification.Name`](https://developer.apple.com/documentation/accessibility/axmfihearingdevice/paireduuidsdidchangenotification)
- [`static func streamingEar() -> AXMFiHearingDevice.Ear`](https://developer.apple.com/documentation/accessibility/axmfihearingdevice/streamingear())
- [`static let streamingEarDidChangeNotification: NSNotification.Name`](https://developer.apple.com/documentation/accessibility/axmfihearingdevice/streamingeardidchangenotification)
- [`static func supportsBidirectionalStreaming() -> Bool`](https://developer.apple.com/documentation/accessibility/axmfihearingdevice/supportsbidirectionalstreaming())
- [`func AXNameFromColor(CGColor) -> String`](https://developer.apple.com/documentation/accessibility/axnamefromcolor(_:))
- [`case linear`](https://developer.apple.com/documentation/accessibility/axnumericdataaxisdescriptor/scaletype-swift.enum/linear)
- [`case ln`](https://developer.apple.com/documentation/accessibility/axnumericdataaxisdescriptor/scaletype-swift.enum/ln)
- [`case log10`](https://developer.apple.com/documentation/accessibility/axnumericdataaxisdescriptor/scaletype-swift.enum/log10)

</details>
<!-- /generated:missing -->
