# BackgroundTasks

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 58.7% of Apple's iOS API (37 of 63, exact) · **Rows:** 60% (5: 3 ✅ 2 ❌) · **iOS:** 13.0+
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
| Types not yet in isim (iOS 26) | ❌ | 26.0 | not implemented, found by the 2026-10 sweep: `BGContinuedProcessingTask`, `BGContinuedProcessingTaskRequest` (2 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
26 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`BGContinuedProcessingTask`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask)
- [`var subtitle: String`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask/subtitle)
- [`var title: String`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask/title)
- [`func updateTitle(String, subtitle: String)`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask/updatetitle(_:subtitle:))
- [`BGContinuedProcessingTaskRequest`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest)
- [`init(identifier: String, title: String, subtitle: String)`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/init(identifier:title:subtitle:))
- [`var requiredResources: BGContinuedProcessingTaskRequest.Resources`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/requiredresources)
- [`BGContinuedProcessingTaskRequest.Resources`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/resources)
- [`static var gpu: BGContinuedProcessingTaskRequest.Resources`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/resources/gpu)
- [`init(rawValue: Int)`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/resources/init(rawvalue:))
- [`var strategy: BGContinuedProcessingTaskRequest.SubmissionStrategy`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/strategy)
- [`BGContinuedProcessingTaskRequest.SubmissionStrategy`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/submissionstrategy)
- [`case fail`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/submissionstrategy/fail)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/submissionstrategy/init(rawvalue:))
- [`case queue`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/submissionstrategy/queue)
- [`var subtitle: String`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/subtitle)
- [`var title: String`](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/title)
- [`BGHealthResearchTask`](https://developer.apple.com/documentation/backgroundtasks/bghealthresearchtask)
- [`BGHealthResearchTaskRequest`](https://developer.apple.com/documentation/backgroundtasks/bghealthresearchtaskrequest)
- [`var protectionTypeOfRequiredData: NSString`](https://developer.apple.com/documentation/backgroundtasks/bghealthresearchtaskrequest/protectiontypeofrequireddata)
- [`case immediateRunIneligible`](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/error/code/immediaterunineligible)
- [`case immediateRunIneligible`](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/error/code/immediaterunineligible)
- [`static var immediateRunIneligible: BGTaskScheduler.Error.Code`](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/error/immediaterunineligible)
- [`class let errorDomain: String`](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/errordomain)
- [`func submitTaskRequest(BGTaskRequest, completionHandler: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/submittaskrequest(_:completionhandler:))
- [`class var supportedResources: BGContinuedProcessingTaskRequest.Resources`](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/supportedresources)

</details>
<!-- /generated:missing -->
