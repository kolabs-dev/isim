# XCTest

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 66.7% of Apple's iOS API (285 of 427, exact) · **Rows:** 15: 9 ✅ 4 🟡 2 ❌ · **iOS:** None+
<!-- /generated:header -->

**Area:** [Developer tools](../COVERAGE.md#devtools) · **Apple:** [XCTest](https://developer.apple.com/documentation/xctest) · **Issues:** [`area:devtools`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Adevtools)

## How isim implements it

- **Adapted:** an Objective-C framework (`isim/frameworks/XCTest`) with a Swift overlay and isim's own `xctest` runner.
- XCUITest runs the app under test as a second isim process, driven over the control channel.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `isim test` (xcodebuild-style test runs) | ✅ | ≤17 | scheme Testables (skipped tests honored), `-only-testing:`/`-skip-testing:`, Xcode console format, `** TEST SUCCEEDED/FAILED **`, exit 65 on failures, `-resultBundlePath DIR` (logs + JUnit/xUnit XML; not an `.xcresult`); hosted tests run inside the app (`TEST_HOST`, bundle in `PlugIns/`), others in isim's `xctest` runner; tested (HelloToolchain, passing and deliberately failing runs) |
| Swift packages on their own (`isim test` / `isim build` in a package folder or with `-package-path DIR`) | ✅ | ≤17 | adapted, like `xcodebuild` in a package directory: schemes per product plus one named after the package (also `<Package>-Package`; `isim build -list [-json]` lists them); the package's scheme runs every `.testTarget`, a product's scheme the test targets depending on its targets; each test target is linked with its dependencies into `<Target>.xctest` (by default in `<package>/.build/isim`) and runs in isim's `xctest` runner with isim's iOS XCTest and Swift Testing (not swift-corelibs-xctest: `XCTestCase()` works, `@testable import`, `Bundle.module`); `-only-testing:` / `-skip-testing:`, `-resultBundlePath`, exit 65 on failures; no test plans. Tested (HelloToolchain's Units package, a two-product package: test_package_tests, test_package_schemes) |
| Test plans (`.xctestplan`; `isim test -testPlan`, `-showTestPlans`, `-only-test-configuration` / `-skip-test-configuration`) | ✅ | ≤17 | a scheme's `TestPlans`: `-testPlan NAME`, else the default plan when the scheme has no Testables (before: "has no test targets"); the plan's enabled test targets with their skipped and selected tests, its default options and each configuration's (environment variables, arguments; `language` / `region` become `ISIM_LANGUAGES` / `ISIM_LOCALE`), run once per configuration (result files get the configuration's name). Not applied: code coverage, test repetition, timeouts and the other execution options. Tested (HelloToolchain, its plans scheme: test_test_plans) |
| Unit tests: XCTest (ObjC and Swift) | 🟡 | ≤17 | ObjC-runtime discovery (`test*` methods; Swift `throws`/`async` variants), setUp/tearDown (class, `WithError`, `async`), teardown blocks, assertions (ObjC macros with `@try/@catch` for `XCTAssertThrows*`; Swift functions incl. accuracy, identity, `XCTAssertThrowsError`, `XCTUnwrap`), uncaught NSExceptions and thrown Swift errors recorded, `continueAfterFailure = false` (interruption exception), expectations (`wait(for:)`, `waitForExpectations`, inverted, notification/predicate (unverified), `fulfillment(of:)`, enforced order (unverified)), `XCTWaiter`, `XCTSkip`/`XCTSkipIf`, `measure` (10 runs, average; no baselines), `XCTestObservation` (unverified); tested (HelloToolchain). Issues, expected failures and activities: rows below; `.xctestplan` schemes are not read |
| Issues (`XCTIssue`, `XCTIssueReference`, `XCTMutableIssue`, `XCTestCase.record(_:)` / `-recordIssue:`, `XCTSourceCodeContext`, `XCTSourceCodeLocation`, `XCTSourceCodeFrame`, `XCTSourceCodeSymbolInfo`, `XCTestObservation` `testCase(_:didRecord:)`) | ✅ | ≤17 | adapted: every failure (assertions, thrown errors, uncaught exceptions, timeouts) is an issue that goes through `record(_:)`, so overrides see and can change it; the Swift `XCTIssue` struct bridges to `XCTIssueReference`; the context captures the call stack, symbolicated with dladdr (no file and line per frame); an issue's attachments are kept with the test. Tested (HelloToolchain `IssueTests`, `ObjCTests testObjCIssues`: test_toolchain.py::test_scheme) |
| Expected failures (`XCTExpectFailure` with options, `enabled:` / `strict:` / `issueMatcher:`, with and without a failing block; `XCTExpectedFailure`, `XCTExpectedFailure.Options`, `nonStrict()`; Objective-C `XCTExpectFailure*` functions) | ✅ | ≤17 | adapted: a matched issue is printed as `Expected failure: REASON: DESCRIPTION` (not an error) and reported to observers; a strict scope that matches nothing records `Failed due to unmatched expected failure: REASON` (`.unmatchedExpectedFailure`); a scope without a block lasts until the end of the test. Tested (test_toolchain.py::test_scheme, test_failing_tests) |
| Activities (`XCTContext.runActivity(named:block:)`, `+runActivityNamed:block:`, `XCTActivity`) | ✅ | ≤17 | adapted: each activity is printed when it starts (`    t =     0.01s NAME`, nested ones indented, like Xcode's console); attachments added to an activity are kept with its test. Tested (test_toolchain.py::test_scheme) |
| `XCTKeyPathExpectation`, `keyValueObservingExpectation(for:keyPath:expectedValue:)` / `(for:keyPath:handler:)`, `XCTDarwinNotificationExpectation` | ✅ | ≤17 | adapted: key-value observing of the object (fulfilled at the expected value, on any change without one, or when the handler says so); Darwin notifications through isim's notify (posts within the process). Tested (test_toolchain.py::test_scheme) |
| Attachments (`XCTAttachment`, `XCTActivity`, `XCTestCase.add(_:)`) | ✅ | ≤17 | adapted: `init(data:)`, `init(data:uniformTypeIdentifier:)`, `init(string:)`, `init(contentsOfFile:)`, `init(image:)`, `init(screenshot:)`, `name`, `uniformTypeIdentifier`, `lifetime` (`.keepAlways`, `.deleteOnSuccess`, the default: kept when the test fails), `userInfo`; with `isim test -resultBundlePath DIR` each kept attachment is saved as `DIR/<bundle>.attachments/<Class>/<test>/<name>.<ext>` (Swift Testing's attachments in `DIR/<bundle>.attachments/SwiftTesting/`, see Testing.md) and named in the console (`Attachment 'NAME' saved: PATH`; not an `.xcresult`); tested (`isim new --tests`: Xcode's launch test attaches its screenshot, test_new_project.py) |
| Performance metrics (`measure(metrics:)`, `measure(options:)`, `XCTMetric`, `XCTClockMetric`, `XCTApplicationLaunchMetric`, `XCTMeasureOptions`, `defaultMetrics`, `defaultMeasureOptions`) | 🟡 | ≤17 | adapted: the block runs `iterationCount` times (default 5) and its wall-clock time is reported per metric in Xcode's console format (`measured [Clock Monotonic Time, s]`, `[Duration (AppLaunch), s]`: the block launches the app, timed until it shows a window with content; `waitUntilResponsive` measures the same); no baselines; `invocationOptions` (manual start/stop), CPU, memory, storage and signpost metrics are not in isim; tested (`isim new --tests`: Xcode's `testLaunchPerformance`, test_new_project.py) |
| UI tests (XCUITest) | 🟡 | ≤17 | `XCUIApplication` launches the TEST_TARGET_NAME app as its own simulator process (launch arguments/environment, terminate, `state` incl. `.runningBackground`, `activate()` back from the background); element queries by type/identifier/label/predicate on accessibility snapshots (`dump FILE`), `exists`, `waitForExistence`, `label`/`value`/`placeholderValue`/`isHittable`/`hasFocus`; `tap`, `typeText` (any text, `;` included: the control channel's `\;`), switches, `swipeUp/Down/Left/Right`, `press(forDuration:)`, `adjust(toNormalizedSliderPosition:)`, `coordinate(withNormalizedOffset:)` + `withOffset` `tap` / `press(forDuration:thenDragTo:)` (a held press, then the drag); the system keyboard as `keyboards` / `keys` (`app.keys["a"]`, `"shift"`, `"delete"`, `"more"`, `"space"`; return is `keyboards.buttons["Return"]`); system permission alerts (notifications, camera/microphone, photos, location, contacts, calendars, paste…) under `XCUIApplication(bundleIdentifier: "com.apple.springboard")`, not the app, and `addUIInterruptionMonitor(withDescription:handler:)` / `removeUIInterruptionMonitor` (adapted: isim draws these alerts in the app process; SpringBoard holds only them, no home-screen icons); `XCUIDevice.orientation` set and read back from the app's `UIDevice.orientation`, `press(.home)` sends the app to the background (no home screen under `isim test`); `.volumeUp/.volumeDown` are ignored (stub: device-only on iOS, like Apple's Simulator); tested (HelloToolchain `AppUITests`: the notification prompt through springboard, the camera prompt through a monitor; `tests/ui/test_toolchain.py::test_scheme`). Multi-touch gestures, velocities, element snapshots, accessibility audits, privacy resets and the device appearance: [XCUIAutomation](XCUIAutomation.md) |
| Screenshots (`XCUIScreenshot`, `XCUIScreenshotProviding`, `XCUIScreen.main` / `.screens`, `XCUIElement.screenshot()`) | ✅ | ≤17 | adapted: the app's process draws its screen (script command `shot`), `image` sized in points (its scale is the screenshot's), `pngRepresentation`; an element's screenshot is its frame of the app's; `XCUIScreen.main` shows the most recently launched or activated app; tested (`isim new --tests`, test_new_project.py) |
| `runsForEachTargetApplicationUIConfiguration` | 🟡 | ≤17 | adapted: a class property tests override (Xcode's launch-test template does); the test runs once, in the device's current configuration, not once per appearance and orientation |
| `XCUIApplication.launch()` from a new instance | ✅ | ≤17 | one process per app, like iOS: a new `XCUIApplication()` refers to the running app, and `launch()` terminates it first, whichever instance launched it (before, each new instance started another copy) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `XCTApplicationLaunchMetric`, `XCTClockMetric`, `XCTCPUMetric`, `XCTestLog`, `XCTestObserver`, `XCTestProbe`, `XCTMeasureOptions`, `XCTMemoryMetric`, `XCTOSSignpostMetric`, `XCTPerformanceMeasurement`, `XCTPerformanceMeasurementTimestamp`, `XCTStorageMetric` (12 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 26) | ❌ | 26.0 | not implemented, found by the 2026-10 sweep: `XCTHitchMetric` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
142 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var XCT_UI_TESTING_AVAILABLE: Int32`](https://developer.apple.com/documentation/xctest/xct_ui_testing_available)
- [`func XCTAssertEqualWithAccuracy<T>(@autoclosure () throws -> T, @autoclosure () throws -> T, accuracy: T, @autoclosure () -> String, file: StaticString, line: UInt)`](https://developer.apple.com/documentation/xctest/xctassertequalwithaccuracy(_:_:accuracy:_:file:line:))
- [`func XCTAssertNotEqualWithAccuracy<T>(@autoclosure () throws -> T, @autoclosure () throws -> T, T, @autoclosure () -> String, file: StaticString, line: UInt)`](https://developer.apple.com/documentation/xctest/xctassertnotequalwithaccuracy(_:_:_:_:file:line:))
- [`XCTAttachment.ImageQuality`](https://developer.apple.com/documentation/xctest/xctattachment/imagequality)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/xctest/xctattachment/imagequality/init(rawvalue:))
- [`case low`](https://developer.apple.com/documentation/xctest/xctattachment/imagequality/low)
- [`case medium`](https://developer.apple.com/documentation/xctest/xctattachment/imagequality/medium)
- [`case original`](https://developer.apple.com/documentation/xctest/xctattachment/imagequality/original)
- [`XCTCPUMetric`](https://developer.apple.com/documentation/xctest/xctcpumetric)
- [`init()`](https://developer.apple.com/documentation/xctest/xctcpumetric/init())
- [`init(application: XCUIApplication)`](https://developer.apple.com/documentation/xctest/xctcpumetric/init(application:))
- [`init(limitingToCurrentThread: Bool)`](https://developer.apple.com/documentation/xctest/xctcpumetric/init(limitingtocurrentthread:))
- [`class var defaultPerformanceMetrics: [XCTPerformanceMetric]`](https://developer.apple.com/documentation/xctest/xctestcase/defaultperformancemetrics)
- [`var invocation: NSInvocation?`](https://developer.apple.com/documentation/xctest/xctestcase/invocation)
- [`func invokeTest()`](https://developer.apple.com/documentation/xctest/xctestcase/invoketest())
- [`func measureMetrics([XCTPerformanceMetric], automaticallyStartMeasuring: Bool, for: () -> Void)`](https://developer.apple.com/documentation/xctest/xctestcase/measuremetrics(_:automaticallystartmeasuring:for:))
- [`func startMeasuring()`](https://developer.apple.com/documentation/xctest/xctestcase/startmeasuring())
- [`func stopMeasuring()`](https://developer.apple.com/documentation/xctest/xctestcase/stopmeasuring())
- [`class var testInvocations: [NSInvocation]`](https://developer.apple.com/documentation/xctest/xctestcase/testinvocations)
- [`let XCTestedUnitPath: String`](https://developer.apple.com/documentation/xctest/xctestedunitpath)
- [`XCTestError`](https://developer.apple.com/documentation/xctest/xctesterror)
- [`XCTestError.Code`](https://developer.apple.com/documentation/xctest/xctesterror/code)
- [`XCTestError.Code`](https://developer.apple.com/documentation/xctest/xctesterror/code)
- [`case failureWhileWaiting`](https://developer.apple.com/documentation/xctest/xctesterror/code/failurewhilewaiting)
- [`case failureWhileWaiting`](https://developer.apple.com/documentation/xctest/xctesterror/code/failurewhilewaiting)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/xctest/xctesterror/code/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/xctest/xctesterror/code/init(rawvalue:))
- [`case timeoutWhileWaiting`](https://developer.apple.com/documentation/xctest/xctesterror/code/timeoutwhilewaiting)
- [`case timeoutWhileWaiting`](https://developer.apple.com/documentation/xctest/xctesterror/code/timeoutwhilewaiting)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/xctest/xctesterror/errordomain)
- [`static var failureWhileWaiting: XCTestError.Code`](https://developer.apple.com/documentation/xctest/xctesterror/failurewhilewaiting)
- [`static var timeoutWhileWaiting: XCTestError.Code`](https://developer.apple.com/documentation/xctest/xctesterror/timeoutwhilewaiting)
- [`let XCTestErrorDomain: String`](https://developer.apple.com/documentation/xctest/xctesterrordomain)
- [`let XCTestErrorDomain: String`](https://developer.apple.com/documentation/xctest/xctesterrordomain)
- [`XCTestLog`](https://developer.apple.com/documentation/xctest/xctestlog)
- [`var logFileHandle: FileHandle!`](https://developer.apple.com/documentation/xctest/xctestlog/logfilehandle)
- [`func testLog(withFormat: String!, arguments: CVaListPointer)`](https://developer.apple.com/documentation/xctest/xctestlog/testlog(withformat:arguments:))
- [`func testSuite(XCTestSuite, didFailWithDescription: String, inFile: String?, atLine: Int)`](https://developer.apple.com/documentation/xctest/xctestobservation/testsuite(_:didfailwithdescription:infile:atline:))
- [`func testSuite(XCTestSuite, didRecord: XCTExpectedFailure)`](https://developer.apple.com/documentation/xctest/xctestobservation/testsuite(_:didrecord:)-1xjkv)
- [`func testSuite(XCTestSuite, didRecord: XCTIssue)`](https://developer.apple.com/documentation/xctest/xctestobservation/testsuite(_:didrecord:)-3rk9k)
- [`XCTestObserver`](https://developer.apple.com/documentation/xctest/xctestobserver)
- [`func startObserving()`](https://developer.apple.com/documentation/xctest/xctestobserver/startobserving())
- [`func stopObserving()`](https://developer.apple.com/documentation/xctest/xctestobserver/stopobserving())
- [`func testCaseDidFail(XCTestRun!, withDescription: String!, inFile: String!, atLine: Int)`](https://developer.apple.com/documentation/xctest/xctestobserver/testcasedidfail(_:withdescription:infile:atline:))
- [`func testCaseDidStart(XCTestRun!)`](https://developer.apple.com/documentation/xctest/xctestobserver/testcasedidstart(_:))
- [`func testCaseDidStop(XCTestRun!)`](https://developer.apple.com/documentation/xctest/xctestobserver/testcasedidstop(_:))
- [`func testSuiteDidStart(XCTestRun!)`](https://developer.apple.com/documentation/xctest/xctestobserver/testsuitedidstart(_:))
- [`func testSuiteDidStop(XCTestRun!)`](https://developer.apple.com/documentation/xctest/xctestobserver/testsuitedidstop(_:))
- [`let XCTestObserverClassKey: String`](https://developer.apple.com/documentation/xctest/xctestobserverclasskey)
- [`XCTestProbe`](https://developer.apple.com/documentation/xctest/xctestprobe)
- [`class func isTesting() -> Bool`](https://developer.apple.com/documentation/xctest/xctestprobe/istesting())
- [`func record(XCTIssue)`](https://developer.apple.com/documentation/xctest/xctestrun/record(_:))
- [`func recordFailure(withDescription: String, inFile: String?, atLine: Int, expected: Bool)`](https://developer.apple.com/documentation/xctest/xctestrun/recordfailure(withdescription:infile:atline:expected:))
- [`let XCTestScopeAll: String`](https://developer.apple.com/documentation/xctest/xctestscopeall)
- [`let XCTestScopeKey: String`](https://developer.apple.com/documentation/xctest/xctestscopekey)
- [`let XCTestScopeNone: String`](https://developer.apple.com/documentation/xctest/xctestscopenone)
- [`let XCTestScopeSelf: String`](https://developer.apple.com/documentation/xctest/xctestscopeself)
- [`func addTestRun(XCTestRun)`](https://developer.apple.com/documentation/xctest/xctestsuiterun/addtestrun(_:))
- [`let XCTestToolKey: String`](https://developer.apple.com/documentation/xctest/xctesttoolkey)
- [`XCTHitchMetric`](https://developer.apple.com/documentation/xctest/xcthitchmetric)
- [`init(application: XCUIApplication)`](https://developer.apple.com/documentation/xctest/xcthitchmetric/init(application:))
- [`var isFailure: Bool`](https://developer.apple.com/documentation/xctest/xctissue-swift.struct/isfailure)
- [`var severity: XCTIssue.Severity`](https://developer.apple.com/documentation/xctest/xctissue-swift.struct/severity-swift.property)
- [`XCTIssue.Severity`](https://developer.apple.com/documentation/xctest/xctissue-swift.struct/severity-swift.typealias)
- [`var isFailure: Bool`](https://developer.apple.com/documentation/xctest/xctissuereference/isfailure)
- [`XCTIssueReference.Severity`](https://developer.apple.com/documentation/xctest/xctissuereference/severity-swift.enum)
- [`case error`](https://developer.apple.com/documentation/xctest/xctissuereference/severity-swift.enum/error)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/xctest/xctissuereference/severity-swift.enum/init(rawvalue:))
- [`case warning`](https://developer.apple.com/documentation/xctest/xctissuereference/severity-swift.enum/warning)
- [`var severity: XCTIssueReference.Severity`](https://developer.apple.com/documentation/xctest/xctissuereference/severity-swift.property)
- [`XCTKeyPathExpectation.AsynchronousFilter`](https://developer.apple.com/documentation/xctest/xctkeypathexpectation/asynchronousfilter)
- [`let options: NSKeyValueObservingOptions`](https://developer.apple.com/documentation/xctest/xctkeypathexpectation/options)
- [`XCTKeyPathExpectation.Predicate`](https://developer.apple.com/documentation/xctest/xctkeypathexpectation/predicate)
- [`XCTKeyPathExpectation.SynchronousFilter`](https://developer.apple.com/documentation/xctest/xctkeypathexpectation/synchronousfilter)
- [`XCTKVOExpectation.Handler`](https://developer.apple.com/documentation/xctest/xctkvoexpectation/handler-swift.typealias)
- [`var invocationOptions: XCTMeasureOptions.InvocationOptions`](https://developer.apple.com/documentation/xctest/xctmeasureoptions/invocationoptions-swift.property)
- [`XCTMeasureOptions.InvocationOptions`](https://developer.apple.com/documentation/xctest/xctmeasureoptions/invocationoptions-swift.struct)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/xctest/xctmeasureoptions/invocationoptions-swift.struct/init(rawvalue:))
- [`static var manuallyStart: XCTMeasureOptions.InvocationOptions`](https://developer.apple.com/documentation/xctest/xctmeasureoptions/invocationoptions-swift.struct/manuallystart)
- [`static var manuallyStop: XCTMeasureOptions.InvocationOptions`](https://developer.apple.com/documentation/xctest/xctmeasureoptions/invocationoptions-swift.struct/manuallystop)
- [`XCTMemoryMetric`](https://developer.apple.com/documentation/xctest/xctmemorymetric)
- [`init()`](https://developer.apple.com/documentation/xctest/xctmemorymetric/init())
- [`init(application: XCUIApplication)`](https://developer.apple.com/documentation/xctest/xctmemorymetric/init(application:))
- [`func didStopMeasuring()`](https://developer.apple.com/documentation/xctest/xctmetric/didstopmeasuring())
- [`func reportMeasurements(from: XCTPerformanceMeasurementTimestamp, to: XCTPerformanceMeasurementTimestamp) throws -> [XCTPerformanceMeasurement]`](https://developer.apple.com/documentation/xctest/xctmetric/reportmeasurements(from:to:))
- [`func willBeginMeasuring()`](https://developer.apple.com/documentation/xctest/xctmetric/willbeginmeasuring())
- [`XCTMutableIssue`](https://developer.apple.com/documentation/xctest/xctmutableissue)
- [`func add(XCTAttachment)`](https://developer.apple.com/documentation/xctest/xctmutableissue/add(_:))
- [`var associatedError: (any Error)?`](https://developer.apple.com/documentation/xctest/xctmutableissue/associatederror)
- [`var attachments: [XCTAttachment]`](https://developer.apple.com/documentation/xctest/xctmutableissue/attachments)
- [`var compactDescription: String`](https://developer.apple.com/documentation/xctest/xctmutableissue/compactdescription)
- [`var detailedDescription: String?`](https://developer.apple.com/documentation/xctest/xctmutableissue/detaileddescription)
- [`var severity: XCTIssueReference.Severity`](https://developer.apple.com/documentation/xctest/xctmutableissue/severity)
- [`var sourceCodeContext: XCTSourceCodeContext`](https://developer.apple.com/documentation/xctest/xctmutableissue/sourcecodecontext)
- [`var type: XCTIssueReference.IssueType`](https://developer.apple.com/documentation/xctest/xctmutableissue/type)
- [`var notificationCenter: NotificationCenter`](https://developer.apple.com/documentation/xctest/xctnsnotificationexpectation/notificationcenter)
- [`var observedObject: Any?`](https://developer.apple.com/documentation/xctest/xctnsnotificationexpectation/observedobject)
- [`XCTOSSignpostMetric`](https://developer.apple.com/documentation/xctest/xctossignpostmetric)
- [`class var customNavigationTransitionMetric: any XCTMetric`](https://developer.apple.com/documentation/xctest/xctossignpostmetric/customnavigationtransitionmetric)
- [`init(subsystem: String, category: String, name: String)`](https://developer.apple.com/documentation/xctest/xctossignpostmetric/init(subsystem:category:name:))
- [`class var navigationTransitionMetric: any XCTMetric`](https://developer.apple.com/documentation/xctest/xctossignpostmetric/navigationtransitionmetric)
- [`class var scrollDecelerationMetric: any XCTMetric`](https://developer.apple.com/documentation/xctest/xctossignpostmetric/scrolldecelerationmetric)
- [`class var scrollDraggingMetric: any XCTMetric`](https://developer.apple.com/documentation/xctest/xctossignpostmetric/scrolldraggingmetric)
- [`class var scrollingAndDecelerationMetric: any XCTMetric`](https://developer.apple.com/documentation/xctest/xctossignpostmetric/scrollinganddecelerationmetric)
- [`XCTPerformanceMeasurement`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement)
- [`var displayName: String`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/displayname)
- [`var doubleValue: Double`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/doublevalue)
- [`var identifier: String`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/identifier)
- [`init(identifier: String, displayName: String, doubleValue: Double, unitSymbol: String)`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/init(identifier:displayname:doublevalue:unitsymbol:))
- [`convenience init(identifier: String, displayName: String, doubleValue: Double, unitSymbol: String, polarity: XCTPerformanceMeasurement.Polarity)`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/init(identifier:displayname:doublevalue:unitsymbol:polarity:))
- [`convenience init(identifier: String, displayName: String, value: Measurement<Unit>)`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/init(identifier:displayname:value:))
- [`convenience init(identifier: String, displayName: String, value: Measurement<Unit>, polarity: XCTPerformanceMeasurement.Polarity)`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/init(identifier:displayname:value:polarity:))
- [`XCTPerformanceMeasurement.Polarity`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/polarity-swift.enum)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/polarity-swift.enum/init(rawvalue:))
- [`case prefersLarger`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/polarity-swift.enum/preferslarger)
- [`case prefersSmaller`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/polarity-swift.enum/preferssmaller)
- [`case unspecified`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/polarity-swift.enum/unspecified)
- [`var polarity: XCTPerformanceMeasurement.Polarity`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/polarity-swift.property)
- [`var unitSymbol: String`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/unitsymbol)
- [`var value: Measurement<Unit>`](https://developer.apple.com/documentation/xctest/xctperformancemeasurement/value)
- [`XCTPerformanceMeasurementTimestamp`](https://developer.apple.com/documentation/xctest/xctperformancemeasurementtimestamp)
- [`var absoluteTime: UInt64`](https://developer.apple.com/documentation/xctest/xctperformancemeasurementtimestamp/absolutetime)
- [`var absoluteTimeNanoSeconds: UInt64`](https://developer.apple.com/documentation/xctest/xctperformancemeasurementtimestamp/absolutetimenanoseconds)
- [`var date: Date`](https://developer.apple.com/documentation/xctest/xctperformancemeasurementtimestamp/date)
- [`convenience init()`](https://developer.apple.com/documentation/xctest/xctperformancemeasurementtimestamp/init())
- [`init(absoluteTime: UInt64, date: Date)`](https://developer.apple.com/documentation/xctest/xctperformancemeasurementtimestamp/init(absolutetime:date:))
- [`XCTPerformanceMetric`](https://developer.apple.com/documentation/xctest/xctperformancemetric)
- [`init(String)`](https://developer.apple.com/documentation/xctest/xctperformancemetric/init(_:))
- [`init(rawValue: String)`](https://developer.apple.com/documentation/xctest/xctperformancemetric/init(rawvalue:))
- [`static let wallClockTime: XCTPerformanceMetric`](https://developer.apple.com/documentation/xctest/xctperformancemetric/wallclocktime)
- [`func XCTSelfTestMain() -> Int32`](https://developer.apple.com/documentation/xctest/xctselftestmain())
- [`XCTStorageMetric`](https://developer.apple.com/documentation/xctest/xctstoragemetric)
- [`init()`](https://developer.apple.com/documentation/xctest/xctstoragemetric/init())
- [`init(application: XCUIApplication)`](https://developer.apple.com/documentation/xctest/xctstoragemetric/init(application:))
- [`var delegate: (any XCTWaiterDelegate)?`](https://developer.apple.com/documentation/xctest/xctwaiter/delegate)
- [`func fulfillment(of: [XCTestExpectation], timeout: TimeInterval, enforceOrder: Bool) async -> XCTWaiter.Result`](https://developer.apple.com/documentation/xctest/xctwaiter/fulfillment(of:timeout:enforceorder:)-swift.method)
- [`class func fulfillment(of: [XCTestExpectation], timeout: TimeInterval, enforceOrder: Bool) async -> XCTWaiter.Result`](https://developer.apple.com/documentation/xctest/xctwaiter/fulfillment(of:timeout:enforceorder:)-swift.type.method)
- [`XCTWaiterDelegate`](https://developer.apple.com/documentation/xctest/xctwaiterdelegate)
- [`func nestedWaiter(XCTWaiter, wasInterruptedByTimedOutWaiter: XCTWaiter)`](https://developer.apple.com/documentation/xctest/xctwaiterdelegate/nestedwaiter(_:wasinterruptedbytimedoutwaiter:))
- [`func waiter(XCTWaiter, didFulfillInvertedExpectation: XCTestExpectation)`](https://developer.apple.com/documentation/xctest/xctwaiterdelegate/waiter(_:didfulfillinvertedexpectation:))
- [`func waiter(XCTWaiter, didTimeoutWithUnfulfilledExpectations: [XCTestExpectation])`](https://developer.apple.com/documentation/xctest/xctwaiterdelegate/waiter(_:didtimeoutwithunfulfilledexpectations:))
- [`func waiter(XCTWaiter, fulfillmentDidViolateOrderingConstraintsFor: XCTestExpectation, requiredExpectation: XCTestExpectation)`](https://developer.apple.com/documentation/xctest/xctwaiterdelegate/waiter(_:fulfillmentdidviolateorderingconstraintsfor:requiredexpectation:))

</details>
<!-- /generated:missing -->
