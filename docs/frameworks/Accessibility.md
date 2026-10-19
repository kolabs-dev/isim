# Accessibility

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Accessibility & Info.plist](../COVERAGE.md#a11y) · **Apple:** [Accessibility](https://developer.apple.com/documentation/accessibility) · **Issues:** [`area:a11y`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aa11y)

## How isim implements it

- **Approach:** isim's own Objective-C framework (`isim/frameworks/Accessibility`); the assistive technologies it
  feeds are isim's simulated VoiceOver, Switch Control and Voice Control in UIKit (`isim/frameworks/UIKit/UIAccessibilityRuntime.m`,
  script commands `voiceover …` in [SCRIPTING.md](../SCRIPTING.md)).
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/Accessibility`; Swift imports them (`AXCustomContent.Importance`).
- **Versus Apple's Simulator:** Apple's Simulator has no VoiceOver; isim's speaks to the log (`isim: VoiceOver: "…"`)
  and, with audio, through espeak-ng.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `AXCustomContent` (`init(label:value:)`, `init(attributedLabel:attributedValue:)`, `label`, `value`, `attributedLabel`, `attributedValue`, `importance`), `AXCustomContent.Importance`, `AXCustomContentProvider` (`accessibilityCustomContent`, `accessibilityCustomContentBlock`), `AXCustomContentReturnBlock` | ✅ | ≤17 | adapted: isim's VoiceOver reads an element's custom content (its `accessibilityCustomContent` or block, or SwiftUI's `accessibilityCustomContent`): high-importance entries after the element's description ("label, value"), default-importance ones one at a time in the rotor's More Content. NSCopying / NSSecureCoding. Tested through SwiftUI (HelloSwiftUI -accessibility, test_swiftui_accessibility) |
| The rest of the framework (`AXChart` / audio graphs, `AXBrailleMap`, math, the settings and notifications) | ❌ | ≤17 | not provided yet (issues #325, #425, #426) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
