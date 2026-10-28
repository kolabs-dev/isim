# AlarmKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [AlarmKit](https://developer.apple.com/documentation/alarmkit) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted (`isim/swift/overlays/AlarmKit`, the alert in `isim/runtime/shell_alarms.inc`):
  - `AlarmManager` keeps the app's alarms in the device data (`Library/isim/Alarms/<bundle ID>.json`; `isim alarms
    list` prints them) and tells the shell when each goes off. The shell keeps the time, so an alarm goes off whether
    or not its app runs, and its sound plays in Silent Mode like iOS's alarms;
  - the alert: a banner at the top while the device is in use (in the Dynamic Island's black on iPhones that have
    one; tapping it opens the full-screen alert), the full-screen alert on the Lock Screen and in StandBy (the time,
    the title, the secondary button in the alarm's tint, Stop). Script ids: `alarm-banner`, `alarm-secondary`,
    `alarm-stop`; `dump` lists them under `IsimAlarmBanner` / `IsimAlarmAlert`;
  - Stop runs the configuration's `stopIntent` in the app and ends the alarm (a weekly alarm is scheduled again); the
    secondary button starts the post-alert countdown (`.countdown`: snooze, repeat) or runs the `secondaryIntent`
    (`.custom`). An answer given while the app was not running reaches it the next time it uses `AlarmManager` (iOS
    launches the app in the background to run the intent);
  - countdowns and paused timers are the app's Live Activity (`AlarmAttributes<Metadata>`, with
    `AlarmPresentationState` as the content state) when the app supports Live Activities, drawn by its widget
    extension's `ActivityConfiguration` on the Lock Screen and in the Dynamic Island like any Live Activity;
  - authorization: the first `schedule` (or `requestAuthorization()`) shows "“App” Would Like to Schedule Alarms and
    Timers" with `NSAlarmKitUsageDescription`, remembered per app; `ISIM_ALARMKIT_PERMISSION=allow|deny` answers
    without the alert.
- **Objective-C / C interface:** Swift only, like Apple's.
- **Versus Apple's Simulator:** isim shows the alarm alert and plays the alarm's sound. Not kept across app runs: the
  intents and the Live Activity handle (an alarm an earlier run scheduled still goes off and stops, without running
  its intent).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `AlarmManager` (`shared`, `schedule(id:configuration:)`, `alarms`, `alarmUpdates`, `AlarmUpdates`, `cancel`, `stop`, `countdown`, `pause`, `resume`, `AlarmError`) | ✅ | 26.0 | adapted: the alarms are in the device data, the shell rings them (shell_alarms.inc). `countdown(id:)` starts the post-alert countdown of an alerting alarm (the pre-alert one of a scheduled alarm); pause / resume keep the elapsed time; a weekly alarm is scheduled again when it stops; at most 64 alarms per app (`maximumLimitReached`; Apple does not document its limit). Tested: test_alarms (HelloAlarms, iOS 26 and 27) |
| `AlarmManager.requestAuthorization()`, `authorizationState`, `authorizationUpdates`, `AuthorizationState`, `AlarmAuthorizationStateUpdates` | ✅ | 26.0 | adapted: the system's alert with `NSAlarmKitUsageDescription`; `ISIM_ALARMKIT_PERMISSION`. Tested: test_alarms, test_alarms_denied |
| `AlarmManager.AlarmConfiguration` (`init(countdownDuration:schedule:attributes:stopIntent:secondaryIntent:sound:)`, `alarm(...)`, `timer(duration:...)`), `AlertConfiguration.AlertSound` | ✅ | 26.0 | the intents run in the app (`LiveActivityIntent.perform()`); `.named` sounds come from the app bundle or `Library/Sounds`, else isim's alarm tone. Tested: test_alarms |
| `AlarmConfiguration` with `appEntityIdentifier` | 🟡 | 27.0 | the entity is kept; isim's Siri and Shortcuts do not show alarms |
| `Alarm` (`id`, `state`, `schedule`, `countdownDuration`, `State`, `Schedule` (`fixed`, `relative`: `Relative`, `Time`, `Recurrence`), `CountdownDuration`) | ✅ | 26.0 | relative schedules go off at the next matching time in the current calendar, weekly on the given weekdays. Tested: test_alarms |
| `AlarmAttributes` (`presentation`, `metadata`, `tintColor`, `ContentState`), `AlarmMetadata`, `AlarmPresentationState` (`Mode`: `alert`, `countdown`, `paused`) | ✅ | 26.0 | the Live Activity's attributes and content state, Codable (colours as their RGBA components, strings resolved). Tested: test_alarms (the countdown Live Activity) |
| `AlarmPresentation` (`Alert`, `Countdown`, `Paused`, `SecondaryButtonBehavior`), `AlarmButton` | ✅ | 26.0 | the alert's title, Stop and secondary buttons (text, symbol); the countdown and paused titles and buttons go to the Live Activity. `Alert.init(title:secondaryButton:secondaryButtonBehavior:)` (26.1) gives the system's Stop. Tested: test_alarms |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
