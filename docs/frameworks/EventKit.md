# EventKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 78.5% of Apple's iOS API (307 of 391, exact) · **Rows:** 7: 5 ✅ 1 🟡 1 ❌ · **iOS:** 4.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [EventKit](https://developer.apple.com/documentation/eventkit) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Adapted:** a calendar database in `ISIM_DATA`.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| EventKit / EventKitUI (calendars, reminders) | 🟡 | ≤17 | adapted: calendar database in `$ISIM_DATA/Library/Calendar` (default "Calendar" and "Reminders" lists); iOS 17 access alerts (full / write-only events, full reminders); events, reminders, date/completion predicates, save/remove, store-changed notification; `EKEventEditViewController` basic form (title, location, all-day; dates shown, not editable) saves without access like iOS 17; recurrence, alarms, locations and attendees: rows below; no Birthdays/Holidays calendars. Tested (HelloPersonal, iOS 17–27). Missing: virtual conferences |
| Objective-C interface (`EventKit.framework`): `EKEventStore` (access requests, calendars, saving and removing events and reminders, predicates, fetching), `EKEvent`, `EKReminder`, `EKCalendarItem`, `EKCalendar`, `EKSource`, `EKAlarm`, `EKRecurrenceRule` / `EKRecurrenceEnd`, `EKErrorDomain`, `EKEventStoreChangedNotification` | ✅ | ≤17 | adapted: headers over the Swift overlay's classes (Apple's Objective-C names). Also the recurrence, alarm, location and participant types below. Not from Objective-C yet: virtual conferences. Tested (HelloPersonalObjC, tests/ui/test_personal_objc.py) |
| Recurrence: `EKRecurrenceRule` (`init(recurrenceWith:interval:daysOfTheWeek:daysOfTheMonth:monthsOfTheYear:weeksOfTheYear:daysOfTheYear:setPositions:end:)`, `daysOfTheWeek`, `daysOfTheMonth`, `monthsOfTheYear`, `weeksOfTheYear`, `daysOfTheYear`, `setPositions`, `firstDayOfTheWeek`, `calendarIdentifier`), `EKRecurrenceDayOfWeek` (week numbers), `EKWeekday`; recurring events expanded in `events(matching:)`; `EKSpan` on occurrences; `occurrenceDate`, `isDetached` | ✅ | ≤17 | adapted, like iOS's calendar: a date-range predicate (`predicateForEvents`) returns each occurrence of a recurring event in the range, all with the series' `eventIdentifier`; daily, weekly (days of the week), monthly (days of the month, the nth weekday, set positions) and yearly (months, days of the year, weeks) rules, ended by a date or a count. Saving an occurrence with `.thisEvent` detaches it (`isDetached`), with `.futureEvents` ends the series before it and starts a new one; removing one adds an exception, `.futureEvents` ends the series. One rule per item, as on iOS. Tested (HelloPersonal: test_eventkit_recurrence_alarms_attendees, every iOS version; HelloPersonalObjC) |
| Alarms: `EKAlarm` (`relativeOffset`, `absoluteDate`, `structuredLocation`, `proximity`, `type`, `emailAddress`, `soundName`), `EKAlarmProximity`, `EKAlarmType` | ✅ | ≤17 | adapted: display and sound alarms of events (each occurrence) and reminders (due date) fire while an app that uses EventKit runs, as Calendar's (or Reminders') alert banner at the top (a tap or a swipe up dismisses it, gone after 5 s; `isim EventKit: alarm` in the log); isim has no Calendar daemon, so alarms due while no such app runs are not shown later. Location (proximity) alarms are stored but never fire. Tested (HelloPersonal: the Coffee alarm's banner) |
| `EKStructuredLocation` (`init(title:)`, `title`, `geoLocation`, `radius`; `init(mapItem:)` with MapKit), `EKEvent.structuredLocation` | ✅ | ≤17 | stored with the event; setting it also sets `location` to its title. Tested (HelloPersonal, HelloPersonalObjC) |
| Attendees: `EKParticipant` (`url`, `name`, `participantStatus`, `participantRole`, `participantType`, `isCurrentUser`, `contactPredicate`), `EKParticipantStatus` / `Role` / `Type`, `EKCalendarItem.attendees` / `hasAttendees`, `EKEvent.organizer`, `EKEvent.status` | ✅ | ≤17 | read from the calendar database (an invitation from an account), as on iOS, where apps cannot add attendees; `contactPredicate` matches the participant's email address in Contacts. `organizer` was an `AnyObject?` placeholder before 0.28 (ABI note in `isim/abi/allowlist.txt`). Tested (HelloPersonal: a seeded invitation) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `EKVirtualConferenceDescriptor`, `EKVirtualConferenceProvider`, `EKVirtualConferenceRoomTypeDescriptor` (3 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
84 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var supportedEventAvailabilities: EKCalendarEventAvailabilityMask`](https://developer.apple.com/documentation/eventkit/ekcalendar/supportedeventavailabilities)
- [`EKCalendarEventAvailabilityMask`](https://developer.apple.com/documentation/eventkit/ekcalendareventavailabilitymask)
- [`static var busy: EKCalendarEventAvailabilityMask`](https://developer.apple.com/documentation/eventkit/ekcalendareventavailabilitymask/busy)
- [`static var free: EKCalendarEventAvailabilityMask`](https://developer.apple.com/documentation/eventkit/ekcalendareventavailabilitymask/free)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/eventkit/ekcalendareventavailabilitymask/init(rawvalue:))
- [`static var tentative: EKCalendarEventAvailabilityMask`](https://developer.apple.com/documentation/eventkit/ekcalendareventavailabilitymask/tentative)
- [`static var unavailable: EKCalendarEventAvailabilityMask`](https://developer.apple.com/documentation/eventkit/ekcalendareventavailabilitymask/unavailable)
- [`static var alarmGreaterThanRecurrence: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/alarmgreaterthanrecurrence)
- [`static var alarmProximityNotSupported: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/alarmproximitynotsupported)
- [`static var calendarDoesNotAllowEvents: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/calendardoesnotallowevents)
- [`static var calendarDoesNotAllowReminders: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/calendardoesnotallowreminders)
- [`static var calendarHasNoSource: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/calendarhasnosource)
- [`static var calendarIsImmutable: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/calendarisimmutable)
- [`static var calendarReadOnly: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/calendarreadonly)
- [`static var calendarSourceCannotBeModified: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/calendarsourcecannotbemodified)
- [`case last`](https://developer.apple.com/documentation/eventkit/ekerror/code/last)
- [`static var datesInverted: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/datesinverted)
- [`static var durationGreaterThanRecurrence: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/durationgreaterthanrecurrence)
- [`static var eventNotMutable: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/eventnotmutable)
- [`static var eventStoreNotAuthorized: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/eventstorenotauthorized)
- [`static var internalFailure: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/internalfailure)
- [`static var invalidEntityType: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/invalidentitytype)
- [`static var invalidInviteReplyCalendar: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/invalidinvitereplycalendar)
- [`static var invalidSpan: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/invalidspan)
- [`static var invitesCannotBeMoved: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/invitescannotbemoved)
- [`static var last: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/last)
- [`static var noCalendar: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/nocalendar)
- [`static var noEndDate: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/noenddate)
- [`static var noStartDate: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/nostartdate)
- [`static var notificationCollectionMismatch: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/notificationcollectionmismatch)
- [`static var notificationSavedWithoutCollection: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/notificationsavedwithoutcollection)
- [`static var notificationsCollectionFlagNotSet: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/notificationscollectionflagnotset)
- [`static var objectBelongsToDifferentStore: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/objectbelongstodifferentstore)
- [`static var osNotSupported: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/osnotsupported)
- [`static var priorityIsInvalid: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/priorityisinvalid)
- [`static var procedureAlarmsNotMutable: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/procedurealarmsnotmutable)
- [`static var recurringReminderRequiresDueDate: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/recurringreminderrequiresduedate)
- [`static var reminderAlarmContainsEmailOrUrl: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/reminderalarmcontainsemailorurl)
- [`static var reminderLocationsNotSupported: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/reminderlocationsnotsupported)
- [`static var sourceDoesNotAllowCalendarAddDelete: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/sourcedoesnotallowcalendaradddelete)
- [`static var sourceDoesNotAllowEvents: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/sourcedoesnotallowevents)
- [`static var sourceDoesNotAllowReminders: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/sourcedoesnotallowreminders)
- [`static var sourceMismatch: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/sourcemismatch)
- [`static var startDateCollidesWithOtherOccurrence: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/startdatecollideswithotheroccurrence)
- [`static var startDateTooFarInFuture: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/startdatetoofarinfuture)
- [`static var structuredLocationsNotSupported: EKError.Code`](https://developer.apple.com/documentation/eventkit/ekerror/structuredlocationsnotsupported)
- [`EKEventSearchCallback`](https://developer.apple.com/documentation/eventkit/ekeventsearchcallback)
- [`func calendarItems(withExternalIdentifier: String) -> [EKCalendarItem]`](https://developer.apple.com/documentation/eventkit/ekeventstore/calendaritems(withexternalidentifier:))
- [`var delegateSources: [EKSource]`](https://developer.apple.com/documentation/eventkit/ekeventstore/delegatesources)
- [`EKEventStore.EventStoreChanged`](https://developer.apple.com/documentation/eventkit/ekeventstore/eventstorechanged)
- [`init()`](https://developer.apple.com/documentation/eventkit/ekeventstore/eventstorechanged/init())
- [`func source(withIdentifier: String) -> EKSource?`](https://developer.apple.com/documentation/eventkit/ekeventstore/source(withidentifier:))
- [`EKEventStoreRequestAccessCompletionHandler`](https://developer.apple.com/documentation/eventkit/ekeventstorerequestaccesscompletionhandler)
- [`func abRecord(with: ABAddressBook) -> ABRecord?`](https://developer.apple.com/documentation/eventkit/ekparticipant/abrecord(with:))
- [`EKParticipantScheduleStatus`](https://developer.apple.com/documentation/eventkit/ekparticipantschedulestatus)
- [`case cannotDeliver`](https://developer.apple.com/documentation/eventkit/ekparticipantschedulestatus/cannotdeliver)
- [`case delivered`](https://developer.apple.com/documentation/eventkit/ekparticipantschedulestatus/delivered)
- [`case deliveryFailed`](https://developer.apple.com/documentation/eventkit/ekparticipantschedulestatus/deliveryfailed)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/eventkit/ekparticipantschedulestatus/init(rawvalue:))
- [`case none`](https://developer.apple.com/documentation/eventkit/ekparticipantschedulestatus/none)
- [`case noPrivileges`](https://developer.apple.com/documentation/eventkit/ekparticipantschedulestatus/noprivileges)
- [`case pending`](https://developer.apple.com/documentation/eventkit/ekparticipantschedulestatus/pending)
- [`case recipientNotAllowed`](https://developer.apple.com/documentation/eventkit/ekparticipantschedulestatus/recipientnotallowed)
- [`case recipientNotRecognized`](https://developer.apple.com/documentation/eventkit/ekparticipantschedulestatus/recipientnotrecognized)
- [`case sent`](https://developer.apple.com/documentation/eventkit/ekparticipantschedulestatus/sent)
- [`EKVirtualConferenceDescriptor`](https://developer.apple.com/documentation/eventkit/ekvirtualconferencedescriptor)
- [`var conferenceDetails: String?`](https://developer.apple.com/documentation/eventkit/ekvirtualconferencedescriptor/conferencedetails)
- [`init(title: String?, URLDescriptors: [EKVirtualConferenceURLDescriptor], conferenceDetails: String?)`](https://developer.apple.com/documentation/eventkit/ekvirtualconferencedescriptor/init(title:urldescriptors:conferencedetails:)-1a9zt)
- [`init(title: String?, urlDescriptors: [EKVirtualConferenceURLDescriptor], conferenceDetails: String?)`](https://developer.apple.com/documentation/eventkit/ekvirtualconferencedescriptor/init(title:urldescriptors:conferencedetails:)-4yf7)
- [`var title: String?`](https://developer.apple.com/documentation/eventkit/ekvirtualconferencedescriptor/title)
- [`var urlDescriptors: [EKVirtualConferenceURLDescriptor]`](https://developer.apple.com/documentation/eventkit/ekvirtualconferencedescriptor/urldescriptors)
- [`EKVirtualConferenceProvider`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceprovider)
- [`func fetchAvailableRoomTypes(completionHandler: ([EKVirtualConferenceRoomTypeDescriptor]?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceprovider/fetchavailableroomtypes(completionhandler:))
- [`func fetchVirtualConference(identifier: EKVirtualConferenceRoomTypeIdentifier, completionHandler: (EKVirtualConferenceDescriptor?, (any Error)?) -> Void)`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceprovider/fetchvirtualconference(identifier:completionhandler:))
- [`EKVirtualConferenceRoomTypeDescriptor`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceroomtypedescriptor)
- [`var identifier: EKVirtualConferenceRoomTypeIdentifier`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceroomtypedescriptor/identifier)
- [`init(title: String, identifier: EKVirtualConferenceRoomTypeIdentifier)`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceroomtypedescriptor/init(title:identifier:))
- [`var title: String`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceroomtypedescriptor/title)
- [`EKVirtualConferenceRoomTypeIdentifier`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceroomtypeidentifier)
- [`EKVirtualConferenceURLDescriptor`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceurldescriptor)
- [`init(title: String?, url: URL)`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceurldescriptor/init(title:url:)-8l9d9)
- [`init(title: String?, URL: URL)`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceurldescriptor/init(title:url:)-alzy)
- [`var title: String?`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceurldescriptor/title)
- [`var url: URL`](https://developer.apple.com/documentation/eventkit/ekvirtualconferenceurldescriptor/url)

</details>
<!-- /generated:missing -->
