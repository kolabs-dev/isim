#!/usr/bin/env bash
# Toolchain + test runner (HelloToolchain sample): the app built from a workspace with a static library, a
# dynamic framework, local packages depending on each other, an XCFramework and .xcconfig files runs and shows
# values from all of them; `isim test` runs the hosted unit tests (Swift + ObjC XCTest), the Swift Testing
# bundle and the XCUITest bundle and reports success; deliberately failing tests (skipped by the scheme, selected
# with -only-testing) are reported as failures with exit status 65; Release configuration; arm64-only
# XCFrameworks are rejected with a clear message.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
root=$PWD
shots=out/test-shots/HelloToolchain; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$root/out/test-data/toolchain; rm -rf "$ISIM_DATA"
export ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1
proj=samples/HelloToolchain
work=$root/out/projects/HelloToolchain
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early

applog=$(ISIM_SCRIPT="wait 1; dump; shot $shots/app.png; quit" timeout 60 out/bin/isim run out/apps/HelloToolchain.app 2>&1); rc=$?
check "app runs (framework, static lib, packages, XCFramework, ObjC<->Swift)" \
  'grep -q "HelloToolchain: «Hello, isim» | MathKit 5 · XCFramework 7 · Units 20000 | debug+xcconfig · Howdy · objc score 42" <<<"$applog"'
check "framework embedded and loaded through @rpath" '[ -x out/apps/HelloToolchain.app/Frameworks/Greeter.framework/Greeter ] && [ ! -d out/apps/HelloToolchain.app/Frameworks/Greeter.framework/Headers ]'
check "package resource bundle in the app" '[ -f out/apps/HelloToolchain.app/Units_Units.bundle/units.json ]'
check "xcconfig conditional setting -> bundle id" 'python3 -c "import plistlib,sys; i=plistlib.load(open(\"out/apps/HelloToolchain.app/Info.plist\",\"rb\")); sys.exit(0 if i[\"CFBundleIdentifier\"]==\"dev.isim.samples.HelloToolchain\" and i[\"ToolchainGreeting\"]==\"Howdy\" else 1)"'
check "app exits cleanly" '[ $rc = 0 ]'

# the whole scheme: hosted unit tests, Swift Testing, UI tests
res=$root/out/test-data/toolchain-results; rm -rf "$res"
tlog=$(cd "$proj" && timeout 900 ../../out/bin/isim test -workspace HelloToolchain.xcworkspace -scheme HelloToolchain -o "$work" -resultBundlePath "$res" 2>&1); trc=$?
echo "$tlog" > "$shots/test.log"
check "isim test succeeds (exit 0)"                 '[ $trc = 0 ] && grep -q "^\*\* TEST SUCCEEDED \*\*" <<<"$tlog"'
check "hosted Swift XCTest passes"                  'grep -q "Test Case .-\[AppTests.ModelTests testLinkedLibraries\]. passed" <<<"$tlog"'
check "@testable + xcconfig + package resources"    'grep -q "testBuildSettings\]. passed" <<<"$tlog" && grep -q "testPackageResources\]. passed" <<<"$tlog"'
check "expectations, inverted, async, fulfillment"  '( for t in testExpectation testInvertedExpectation testAsync testAsyncFulfillment; do grep -q "ModelTests $t\]. passed" <<<"$tlog" || exit 1; done )'
check "XCTSkip (Swift and ObjC)"                    'grep -q "ModelTests testSkipped\]. skipped" <<<"$tlog" && grep -q "ObjCTests testObjCSkip\]. skipped" <<<"$tlog"'
check "measure reports an average"                  'grep -q "testMeasure\]. measured \[Time, seconds\] average:" <<<"$tlog"'
check "setUp/tearDown order"                        'grep -q "ModelTests testZLifecycleOrder\]. passed" <<<"$tlog"'
check "ObjC XCTestCase in the same bundle"          'grep -q "Test Case .-\[ObjCTests testCalculator\]. passed" <<<"$tlog"'
check "ObjC XCTAssertThrows (@try/@catch)"          'grep -q "Test Case .-\[ObjCTests testExceptions\]. passed" <<<"$tlog"'
check "scheme skips the failing classes"            '! grep -q "ExpectedFailureTests\|ExpectedObjCFailureTests" <<<"$tlog"'
check "XCTest summary"                              'grep -Eq "Executed 1[0-9] tests, with 2 tests skipped and 0 failures" <<<"$tlog"'
check "Swift Testing runs @Test / @Suite"           'grep -q "Test conversion() passed" <<<"$tlog" && grep -q "with 3 test cases passed" <<<"$tlog" && grep -q "Suite UnitsSuite passed" <<<"$tlog"'
check "Swift Testing skips FailingSuite (scheme)"   '! grep -q "deliberateFailure" <<<"$tlog"'
check "XCUITest: launch args/env, tap, typeText"    '( for t in testLaunchShowsLibraries testTapIncrements testTypeText testSwitchAndQueries testRelaunchResetsState; do grep -q "AppUITests $t\]. passed" <<<"$tlog" || exit 1; done )'
check "JUnit / xUnit reports written"               'grep -q "<testcase classname=\"AppTests.ModelTests\" name=\"testAsync\"" "$res/AppTests.junit.xml" && grep -q "testcase" "$res/AppSwiftTests.swift-testing.xml" && [ -s "$res/AppUITests.log" ]'

# deliberately failing tests are reported as failures
flog=$(cd "$proj" && timeout 600 ../../out/bin/isim test -workspace HelloToolchain.xcworkspace -scheme HelloToolchain -o "$work" \
  -only-testing:AppTests/ExpectedFailureTests -only-testing:AppTests/ExpectedObjCFailureTests -only-testing:AppSwiftTests/FailingSuite -only-testing:AppUITests/ExpectedUIFailureTests 2>&1); frc=$?
echo "$flog" > "$shots/failing.log"
check "failing run exits 65 with TEST FAILED"       '[ $frc = 65 ] && grep -q "^\*\* TEST FAILED \*\*" <<<"$flog"'
check "XCTAssertEqual failure with file:line"       'grep -Eq "ModelTests.swift:[0-9]+: error: -\[AppTests.ExpectedFailureTests testEqualFails\] : XCTAssertEqual failed: \(\"5\"\) is not equal to \(\"6\"\) - deliberate" <<<"$flog"'
check "thrown error recorded"                       'grep -q "testThrownError\] : caught error" <<<"$flog" && grep -q "testThrownError\]. failed" <<<"$flog"'
check "continueAfterFailure = false stops"          'grep -q "first failure" <<<"$flog" && ! grep -q "never reached" <<<"$flog"'
check "unfulfilled expectation times out"           'grep -q "Exceeded timeout of 0.2 seconds, with unfulfilled expectations: \"never fulfilled\"" <<<"$flog"'
check "uncaught NSException recorded"               'grep -q "testUncaughtException\] : failed: caught \"NSInternalInconsistencyException\", \"deliberate exception\"" <<<"$flog" && ! grep -q "not reached" <<<"$flog"'
check "only the selected tests ran"                 'grep -Eq "Executed 5 tests, with 5 failures" <<<"$flog" && ! grep -q "testLinkedLibraries" <<<"$flog"'
check "Swift Testing failure reported"              'grep -q "Expectation failed: (Units.convert(1) → 10000) == 1" <<<"$flog" && grep -q "Test deliberateFailure() failed" <<<"$flog"'
check "XCUITest: tapping a missing element fails"   'grep -q "Failed to tap: No matches found" <<<"$flog" && grep -q "ExpectedUIFailureTests testMissingButton\]. failed" <<<"$flog"'

# Release configuration (no DEBUG condition) from the same project
rlog=$(cd "$proj" && ../../out/bin/isim build -project HelloToolchain.xcodeproj -target HelloToolchain -configuration Release -o "$work-release" 2>&1 | tail -2)
relog=$(ISIM_SCRIPT="wait 1; quit" timeout 60 out/bin/isim run "$work-release/HelloToolchain.app" 2>&1)
check "Release configuration build"                 'grep -q "release+xcconfig" <<<"$relog"'

# an XCFramework without an x86_64 simulator slice is rejected with a clear message
arm=$root/out/test-data/toolchain-arm/Arm.xcframework; rm -rf "$(dirname "$arm")"; mkdir -p "$arm/ios-arm64_arm64-simulator"
python3 - "$arm" <<'PY'
import plistlib, sys
plistlib.dump({'AvailableLibraries': [
    {'LibraryIdentifier': 'ios-arm64', 'LibraryPath': 'libArm.a', 'SupportedArchitectures': ['arm64'], 'SupportedPlatform': 'ios'},
    {'LibraryIdentifier': 'ios-arm64_arm64-simulator', 'LibraryPath': 'libArm.a', 'SupportedArchitectures': ['arm64'],
     'SupportedPlatform': 'ios', 'SupportedPlatformVariant': 'simulator'}], 'XCFrameworkFormatVersion': '1.0'}, open(sys.argv[1] + '/Info.plist', 'wb'))
PY
amsg=$(python3 -c "import importlib.util,sys; s=importlib.util.spec_from_file_location('b','out/bin/isim-build.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); m.xcframework_slice(sys.argv[1])" "$arm" 2>&1)
check "arm64-only XCFramework rejected"             'grep -q "Arm.xcframework has no x86_64 iOS-simulator slice (it has: ios-arm64 (arm64), ios-arm64_arm64-simulator (arm64))" <<<"$amsg"'

[ $fail = 0 ] || { echo "--- isim test log"; grep -v "^ " <<<"$tlog" | tail -60; echo "--- failing run"; tail -40 <<<"$flog"; }
exit $fail
