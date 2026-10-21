# EventKitUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 53.1% of Apple's iOS API (26 of 49, exact) · **Rows:** 2: 1 ✅ 1 ❌ · **iOS:** 4.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [EventKit UI](https://developer.apple.com/documentation/eventkitui) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Adapted:** the event editor and calendar chooser drawn by isim. Rows: [EventKit](EventKit.md).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Objective-C interface (`EventKitUI.framework`): `EKEventEditViewController` and `EKEventEditViewDelegate`, `EKEventViewController` and `EKEventViewDelegate`, `EKCalendarChooser` and `EKCalendarChooserDelegate` | ✅ | ≤17 | adapted: headers over the Swift overlay's classes (Apple's Objective-C names). The delegates' selectors are now Apple's (`...didCompleteWithAction:`); Swift apps built with 0.22 or earlier still get the editor's call. Tested (HelloPersonalObjC: the editor, tests/ui/test_personal_objc.py) |
| `EKCalendarChooser` (`init(selectionStyle:displayStyle:eventStore:)`, `init(selectionStyle:displayStyle:entityType:eventStore:)`, `selectionStyle`, `selectedCalendars`, `showsDoneButton`, `showsCancelButton`, `delegate`), `EKCalendarChooserDelegate`, `EKCalendarChooserSelectionStyle`, `EKCalendarChooserDisplayStyle` | ✅ | ≤17 | adapted: drawn in the app (on iOS it runs out of process), so it lists the device's calendars (or reminder lists) without calendar access: the calendar's colour, a checkmark on the selected ones, single or multiple selection, writable calendars only; Done and Cancel in its navigation bar call the delegate. Tested (HelloPersonal: test_eventkit_recurrence_alarms_attendees) |

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
