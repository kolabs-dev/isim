# EventKitUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 53.1% of Apple's iOS API (26 of 49, exact) · **iOS:** 4.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [EventKit UI](https://developer.apple.com/documentation/eventkitui) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Adapted:** the event editor and calendar chooser drawn by isim. Rows: [EventKit](EventKit.md).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `EKCalendarChooser` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
23 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`EKCalendarChooser`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooser)
- [`var delegate: (any EKCalendarChooserDelegate)?`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooser/delegate)
- [`init(selectionStyle: EKCalendarChooserSelectionStyle, displayStyle: EKCalendarChooserDisplayStyle, entityType: EKEntityType, eventStore: EKEventStore)`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooser/init(selectionstyle:displaystyle:entitytype:eventstore:))
- [`init(selectionStyle: EKCalendarChooserSelectionStyle, displayStyle: EKCalendarChooserDisplayStyle, eventStore: EKEventStore)`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooser/init(selectionstyle:displaystyle:eventstore:))
- [`var selectedCalendars: Set<EKCalendar>`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooser/selectedcalendars)
- [`var selectionStyle: EKCalendarChooserSelectionStyle`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooser/selectionstyle)
- [`var showsCancelButton: Bool`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooser/showscancelbutton)
- [`var showsDoneButton: Bool`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooser/showsdonebutton)
- [`EKCalendarChooserDelegate`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserdelegate)
- [`func calendarChooserDidCancel(EKCalendarChooser)`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserdelegate/calendarchooserdidcancel(_:))
- [`func calendarChooserDidFinish(EKCalendarChooser)`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserdelegate/calendarchooserdidfinish(_:))
- [`func calendarChooserSelectionDidChange(EKCalendarChooser)`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserdelegate/calendarchooserselectiondidchange(_:))
- [`EKCalendarChooserDisplayStyle`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserdisplaystyle)
- [`case allCalendars`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserdisplaystyle/allcalendars)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserdisplaystyle/init(rawvalue:))
- [`case writableCalendarsOnly`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserdisplaystyle/writablecalendarsonly)
- [`EKCalendarChooserSelectionStyle`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserselectionstyle)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserselectionstyle/init(rawvalue:))
- [`case multiple`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserselectionstyle/multiple)
- [`case single`](https://developer.apple.com/documentation/eventkitui/ekcalendarchooserselectionstyle/single)
- [`var EKUI_IS_IOS: Int32`](https://developer.apple.com/documentation/eventkitui/ekui_is_ios)
- [`var EKUI_IS_SIMULATOR: Int32`](https://developer.apple.com/documentation/eventkitui/ekui_is_simulator)
- [`func EventKitUIBundle() -> Bundle!`](https://developer.apple.com/documentation/eventkitui/eventkituibundle())

</details>
<!-- /generated:missing -->
