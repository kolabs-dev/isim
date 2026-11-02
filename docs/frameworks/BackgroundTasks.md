# BackgroundTasks

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 92.1% of Apple's iOS API (58 of 63, exact) · **Rows:** 7: 6 ✅ 1 ❌ · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [BackgroundTasks](https://developer.apple.com/documentation/backgroundtasks) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Adapted:** there is no scheduler; tasks run on the `bgtask` script command. Apps in the background are suspended, like on iOS.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| BackgroundTasks (`BGAppRefreshTask`, `BGProcessingTask`) | ✅ | ≤17 | `register` (checks `BGTaskSchedulerPermittedIdentifiers`), `submit` (checks `UIBackgroundModes`, errors), pending/cancel; no scheduler decides when — like Xcode's `_simulateLaunchForTaskWithIdentifier`, the script/control command `bgtask BUNDLE-ID TASK-ID` launches a pending task, starting the app in the background (or resuming a suspended one); tasks keep the app running until completed or expired (`ISIM_BACKGROUND_TASK_SECONDS`). Tested (HelloSystem) |
| App suspension in the background | ✅ | ≤17 | adapted: under `isim boot` an app is suspended (its process stopped: timers and run loop stop) a few seconds after going to the background (`ISIM_SUSPEND_SECONDS`, default 5; `ISIM_SUSPEND=0` never), unless a background task, background audio or location keeps it running; any system event (push, task, action, foreground) resumes it. iOS suspends right after the app's background work ends. Tested (background, push) |
| Background audio, location modes | ✅ | ≤17 | audio: UIBackgroundModes `audio` + a playback/playAndRecord category keeps playing after going home (without it the session is interrupted); location: UIBackgroundModes `location` + `allowsBackgroundLocationUpdates` (or `CLBackgroundActivitySession`) keeps updates coming, with the blue status-bar indicator (When In Use, or `showsBackgroundLocationIndicator`; tap opens the app). Tested (background) |
| Objective-C interface (`BackgroundTasks.framework`): `BGTaskScheduler` (`sharedScheduler`, `registerForTaskWithIdentifier:usingQueue:launchHandler:`, `submitTaskRequest:error:`, cancel, pending requests), `BGAppRefreshTaskRequest`, `BGProcessingTaskRequest`, `BGTask` (`expirationHandler`, `setTaskCompletedWithSuccess:`), `BGTaskSchedulerErrorDomain` | ✅ | ≤17 | adapted: headers over the Swift overlay's classes (Apple's Objective-C names); the launch handler runs on the queue it was registered with. Tested (HelloServicesObjC: `bgtask` runs it, tests/ui/test_services_objc.py) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `BGHealthResearchTask`, `BGHealthResearchTaskRequest` (2 types; with their members under "Not yet in isim") |
| Continued processing tasks (`BGContinuedProcessingTaskRequest`, `BGContinuedProcessingTask`) | ✅ | 26.0 | adapted: a request submitted in the foreground (its identifier matching a `BUNDLE-ID.CONTEXT.*` wildcard in `BGTaskSchedulerPermittedIdentifiers`; the launch handler registered for it or the wildcard) starts at once and goes on in the background with no time limit; two run at a time, then `.queue` waits (listed by `pendingTaskRequests`) and `.fail` throws `immediateRunIneligible`; `requiredResources` checked against `BGTaskScheduler.supportedResources` (`.gpu` on iPad). The system's Live Activity is the shell's (`isim/runtime/shell_bgtasks.inc`): the app's icon and name, `title`, `subtitle` (`updateTitle(_:subtitle:)`) and `progress` (`ProgressReporting`) on the Lock Screen and in the Dynamic Island while the app is not in front, with a cancel button (`bgtask-cancel`) that runs the `expirationHandler`. Tested (HelloSystem, tests/ui/test_continued_processing.py) |
| Objective-C interface for continued processing: `BGContinuedProcessingTaskRequest` (`initWithIdentifier:title:subtitle:`, `strategy`, `requiredResources`), `BGContinuedProcessingTask` (`updateTitle:subtitle:`, `progress`), `+[BGTaskScheduler supportedResources]`, `BGTaskSchedulerErrorCodeImmediateRunIneligible` | ✅ | 26.0 | adapted: headers over the Swift overlay's classes |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
5 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`BGHealthResearchTask`](https://developer.apple.com/documentation/backgroundtasks/bghealthresearchtask)
- [`BGHealthResearchTaskRequest`](https://developer.apple.com/documentation/backgroundtasks/bghealthresearchtaskrequest)
- [`var protectionTypeOfRequiredData: NSString`](https://developer.apple.com/documentation/backgroundtasks/bghealthresearchtaskrequest/protectiontypeofrequireddata)
- [`class let errorDomain: String`](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/errordomain)
- [`func submitTaskRequest(BGTaskRequest, completionHandler: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/submittaskrequest(_:completionhandler:))

</details>
<!-- /generated:missing -->
