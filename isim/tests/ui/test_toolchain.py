"""Toolchain + test runner (HelloToolchain): the app built from a workspace with a static library, a dynamic framework,
local packages depending on each other, an XCFramework and .xcconfig files runs and shows values from all of them;
`isim test` runs the hosted unit tests (Swift + ObjC XCTest), the Swift Testing bundle and the XCUITest bundle and
reports success; deliberately failing tests (skipped by the scheme, selected with -only-testing) are reported as
failures with exit status 65; Release configuration; arm64-only XCFrameworks are rejected with a clear message.
A Swift package on its own (issue #619): `isim test` in the Units package's folder runs its .testTarget (XCTest with
@testable import and Bundle.module, an XCTestCase made with init(), Swift Testing) like `xcodebuild test -scheme
Units`; `isim build -list` lists a package's schemes (one per product, one for the package) and a product's scheme
tests only the test targets that depend on it. Port of tests/ui/toolchain.sh."""
import json
import os
import plistlib
import re
import subprocess
import sys
from pathlib import Path

import pytest
from isimtest import APPS, DEFAULT_DEVICE, ISIM, ROOT, exclusive, need_apps

PROJ = ROOT / "samples/HelloToolchain"
WORK = ROOT / "out/projects/HelloToolchain"                    # shared build products (incremental across runs)
APP = APPS / "HelloToolchain.app"


@pytest.fixture(autouse=True)
def built():
    need_apps("HelloToolchain")


def isim(device_data, *args, timeout=900, cwd=PROJ, env=None):
    env = dict(os.environ, ISIM_DATA=str(device_data), ISIM_DEVICE=DEFAULT_DEVICE, ISIM_HEADLESS="1",
               ISIM_SHOT_SCALE="1", **(env or {}))
    p = subprocess.run([str(ISIM), *args], cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True, errors="replace", timeout=timeout)
    return p.returncode, p.stdout


def test_app(launch):
    app = launch("HelloToolchain")
    app.wait_log(r"HelloToolchain: «Hello, isim» \| MathKit 5 · XCFramework 7 · Units 20000 \| debug\+xcconfig · Howdy · "
                 r"objc score 42")                         # framework, static lib, packages, XCFramework, ObjC<->Swift
    app.wait_log(r"HelloToolchain macros: Model\.mathKitSum\(\) \* 2 = 10, 3 flavors")   # package macro target (expression +
                                                                                    # attached member macro); #Preview compiles
    assert app.quit() == 0
    fw = APP / "Frameworks/Greeter.framework"
    assert os.access(fw / "Greeter", os.X_OK) and not (fw / "Headers").exists(), \
        "the framework is embedded (loaded through @rpath), without headers"
    assert (APP / "Units_Units.bundle/units.json").is_file(), "package resource bundle in the app"
    info = plistlib.loads((APP / "Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == "dev.isim.samples.HelloToolchain" and info["ToolchainGreeting"] == "Howdy", \
        "xcconfig conditional setting -> bundle id"


def test_scheme(device_data, tmp_path):
    res = tmp_path / "results"
    with exclusive("toolchain-build"):
        rc, log = isim(device_data, "test", "-workspace", "HelloToolchain.xcworkspace", "-scheme", "HelloToolchain",
                       "-o", str(WORK), "-resultBundlePath", str(res))
    tail = "\n".join(l for l in log.splitlines() if not l.startswith(" "))[-6000:]
    assert rc == 0 and re.search(r"^\*\* TEST SUCCEEDED \*\*", log, re.M), f"isim test succeeds (exit {rc})\n{tail}"
    has = lambda rx: re.search(rx, log, re.M) is not None
    assert has(r"Test Case .-\[AppTests\.ModelTests testLinkedLibraries\]. passed"), "hosted Swift XCTest passes"
    assert has(r"testBuildSettings\]. passed") and has(r"testPackageResources\]. passed"), \
        "@testable + xcconfig + package resources"
    for t in ("testExpectation", "testInvertedExpectation", "testAsync", "testAsyncFulfillment"):
        assert has(rf"ModelTests {t}\]. passed"), f"expectations, inverted, async, fulfillment: {t}"
    assert has(r"ModelTests testSkipped\]. skipped") and has(r"ObjCTests testObjCSkip\]. skipped"), "XCTSkip (Swift, ObjC)"
    assert has(r"testMeasure\]. measured \[Time, seconds\] average:"), "measure reports an average"
    assert has(r"ModelTests testZLifecycleOrder\]. passed"), "setUp/tearDown order"
    assert has(r"Test Case .-\[ObjCTests testCalculator\]. passed"), "ObjC XCTestCase in the same bundle"
    assert has(r"Test Case .-\[ObjCTests testExceptions\]. passed"), "ObjC XCTAssertThrows (@try/@catch)"
    for t in ("testActivities", "testExpectedFailures", "testRecordIssue", "testKeyPathExpectation", "testDarwinNotification"):
        assert has(rf"IssueTests {t}\]. passed"), f"issues, expected failures, activities, expectations: {t}"
    assert has(r"Test Case .-\[ObjCTests testObjCIssues\]. passed"), "the Objective-C interface (XCTContext, XCTExpectFailure*, XCTMutableIssue)"
    assert has(r"^    t = +[0-9.]+s Add numbers$") and has(r"^    t = +[0-9.]+s     Attach the operands$"), "activities, nested"
    assert has(r"testExpectedFailures\] : Expected failure: addition is off by one: XCTAssertEqual failed") and \
        has(r"Expected failure: known bug 42: failed - bug 42"), "expected failures are reported, not failures"
    assert not has(r"error: .*IssueTests"), "no issue of IssueTests fails it"
    assert not has(r"ExpectedFailureTests|ExpectedObjCFailureTests"), "the scheme skips the failing classes"
    assert has(r"Executed 2[0-9] tests, with 2 tests skipped and 0 failures"), "XCTest summary"
    assert has(r"Test conversion\(\) passed") and has(r"with 3 test cases passed") and has(r"Suite UnitsSuite passed"), \
        "Swift Testing runs @Test / @Suite"
    assert not has(r"deliberateFailure"), "Swift Testing skips FailingSuite (scheme)"
    for t in ("testLaunchShowsLibraries", "testTapIncrements", "testTypeText", "testSwitchAndQueries",
              "testRelaunchResetsState"):
        assert has(rf"AppUITests {t}\]. passed"), f"XCUITest: launch args/env, tap, typeText: {t}"
    for t, what in (("testTypeSemicolon", "typeText with ';'"), ("testKeyboardKeys", "keyboard and key elements"),
                    ("testSystemAlertOnSpringboard", "a permission alert under com.apple.springboard"),
                    ("testInterruptionMonitor", "addUIInterruptionMonitor"), ("testHomeAndActivate", "home + activate"),
                    ("testRotation", "XCUIDevice orientation set + read back"),
                    ("testGestures", "swipes, press(forDuration:), slider, coordinates, table scrolling")):
        assert has(rf"AppUITests {t}\]. passed"), f"XCUITest: {what} ({t})"
    assert has(r"interrupting element .*Would Like to Access the Camera.*Camera permission"), "the monitor is reported"
    for t, what in (("testPinchRotateAndTaps", "pinch, rotate, twoFingerTap, tap(withNumberOfTaps:numberOfTouches:)"),
                    ("testDragToElement", "press(forDuration:thenDragTo:) an element, with a velocity and a hold"),
                    ("testSwipeVelocities", "swipes with XCUIGestureVelocity"), ("testSnapshot", "XCUIElementSnapshot"),
                    ("testAccessibilityAudit", "performAccessibilityAudit"), ("testResetAuthorizationStatus", "resetAuthorizationStatus(for:)"),
                    ("testAppearance", "XCUIDevice.appearance")):
        assert has(rf"AppMultitouchUITests {t}\]. passed"), f"XCUITest: {what} ({t})"
    junit = (res / "AppTests.junit.xml").read_text()
    assert '<testcase classname="AppTests.ModelTests" name="testAsync"' in junit and \
        "testcase" in (res / "AppSwiftTests.swift-testing.xml").read_text() and \
        (res / "AppUITests.log").stat().st_size > 0, "JUnit / xUnit reports written"
    # Swift Testing attachments (Attachment.record; Data, Encodable and file URLs through the Foundation overlay)
    att = res / "AppSwiftTests.attachments" / "SwiftTesting"
    assert has(r"Test attachments\(\) passed"), "the attachments test"
    names = sorted(p.name for p in att.iterdir()) if att.is_dir() else []
    assert names == ["magic.bin", "table.csv", "unit.json", "units.txt"], names
    # XCTAttachments added to activities (Swift and Objective-C) are kept with their tests
    kept = {p.name: p.read_text() for p in (res / "AppTests.attachments").rglob("*.txt")}
    assert kept.get("operands.txt") == "20 + 22" and kept.get("objc.txt") == "from Objective-C", sorted(kept)
    assert (att / "units.txt").read_text() == "kilo = 1000" and (att / "magic.bin").read_bytes() == b"ISIM"
    assert '"factor"' in (att / "unit.json").read_text() and (att / "table.csv").read_text().startswith("name,factor")


def test_failing_tests(device_data):
    with exclusive("toolchain-build"):
        rc, log = isim(device_data, "test", "-workspace", "HelloToolchain.xcworkspace", "-scheme", "HelloToolchain",
                       "-o", str(WORK), "-only-testing:AppTests/ExpectedFailureTests",
                       "-only-testing:AppTests/ExpectedObjCFailureTests", "-only-testing:AppSwiftTests/FailingSuite",
                       "-only-testing:AppUITests/ExpectedUIFailureTests", timeout=600)
    has = lambda rx: re.search(rx, log, re.M) is not None
    assert rc == 65 and has(r"^\*\* TEST FAILED \*\*"), f"a failing run exits 65 with TEST FAILED (exit {rc})\n{log[-4000:]}"
    assert has(r'ModelTests\.swift:[0-9]+: error: -\[AppTests\.ExpectedFailureTests testEqualFails\] : XCTAssertEqual failed: '
               r'\("5"\) is not equal to \("6"\) - deliberate'), "XCTAssertEqual failure with file:line"
    assert has(r"testThrownError\] : caught error") and has(r"testThrownError\]. failed"), "thrown error recorded"
    assert has(r"first failure") and not has(r"never reached"), "continueAfterFailure = false stops"
    assert has(r'Exceeded timeout of 0\.2 seconds, with unfulfilled expectations: "never fulfilled"'), \
        "unfulfilled expectation times out"
    assert has(r'testUncaughtException\] : failed: caught "NSInternalInconsistencyException", "deliberate exception"') \
        and not has(r"not reached"), "uncaught NSException recorded"
    assert has(r"testUnmatchedExpectedFailure\] : Failed due to unmatched expected failure: a bug that is fixed"), \
        "a strict XCTExpectFailure that matches nothing fails"
    assert has(r"Executed 6 tests, with 6 failures") and not has(r"testLinkedLibraries"), "only the selected tests ran"
    assert has(r"Expectation failed: \(Units\.convert\(1\) → 10000\) == 1") and has(r"Test deliberateFailure\(\) failed"), \
        "Swift Testing failure reported"
    assert has(r"Failed to tap: No matches found") and has(r"ExpectedUIFailureTests testMissingButton\]. failed"), \
        "XCUITest: tapping a missing element fails"


def test_test_plans(device_data):
    """test plans (.xctestplan): the HelloToolchainPlans scheme has no Testables, only TestPlans; its default plan Unit
    runs its enabled targets (AppTests, AppSwiftTests; AppUITests disabled) once per configuration with its skipped
    tests, environment, arguments and the French configuration's language; -testPlan Failures runs its selected test;
    -showTestPlans lists them."""
    with exclusive("toolchain-build"):
        rc, shown = isim(device_data, "test", "-workspace", "HelloToolchain.xcworkspace", "-scheme", "HelloToolchainPlans", "-showTestPlans")
        assert rc == 0 and "\tUnit (default)" in shown and "\tFailures" in shown, shown
        rc, log = isim(device_data, "test", "-workspace", "HelloToolchain.xcworkspace", "-scheme", "HelloToolchainPlans",
                       "-o", str(WORK))
        tail = "\n".join(l for l in log.splitlines() if not l.startswith(" "))[-5000:]
        assert rc == 0 and re.search(r"^\*\* TEST SUCCEEDED \*\*", log, re.M), f"the default plan succeeds (exit {rc})\n{tail}"
        has = lambda rx: re.search(rx, log, re.M) is not None
        assert has(r'test plan Unit, configuration "English"') and has(r'test plan Unit, configuration "French"'), "both configurations"
        assert has(r"plan options: Unit / English argument true language en") and \
            has(r"plan options: Unit / French argument true language fr"), "environment, arguments, language per configuration"
        assert not has(r"PLAN_DISABLED") and not has(r"ExpectedFailureTests") and not has(r"AppUITests"), \
            "skipped tests and the disabled target do not run"
        assert has(r"Suite UnitsSuite passed") and not has(r"deliberateFailure"), "Swift Testing with the plan's skips"

        rc, log = isim(device_data, "test", "-workspace", "HelloToolchain.xcworkspace", "-scheme", "HelloToolchainPlans",
                       "-testPlan", "Failures", "-o", str(WORK), timeout=600)
        has = lambda rx: re.search(rx, log, re.M) is not None
        assert rc == 65 and has(r"ExpectedFailureTests testEqualFails\]. failed") and has(r"Executed 1 test, with 1 failure"), \
            f"-testPlan Failures runs its one selected (failing) test\n{log[-3000:]}"

        rc, log = isim(device_data, "test", "-workspace", "HelloToolchain.xcworkspace", "-scheme", "HelloToolchainPlans",
                       "-only-test-configuration", "French", "-only-testing:AppTests/ModelTests/testPlanOptions", "-o", str(WORK))
        assert rc == 0 and "language fr" in log and 'configuration "English"' not in log, log[-2000:]


def test_release_configuration(launch, device_data):
    with exclusive("toolchain-build"):
        rc, log = isim(device_data, "build", "-project", "HelloToolchain.xcodeproj", "-target", "HelloToolchain",
                       "-configuration", "Release", "-o", f"{WORK}-release")
    assert rc == 0, log[-3000:]
    app = launch(Path(f"{WORK}-release/HelloToolchain.app"))
    app.wait_log(r"release\+xcconfig")                                  # Release configuration build (no DEBUG)
    app.quit()


def test_arm64_only_xcframework_rejected(tmp_path):
    arm = tmp_path / "Arm.xcframework"
    (arm / "ios-arm64_arm64-simulator").mkdir(parents=True)
    (arm / "Info.plist").write_bytes(plistlib.dumps({"AvailableLibraries": [
        {"LibraryIdentifier": "ios-arm64", "LibraryPath": "libArm.a", "SupportedArchitectures": ["arm64"],
         "SupportedPlatform": "ios"},
        {"LibraryIdentifier": "ios-arm64_arm64-simulator", "LibraryPath": "libArm.a", "SupportedArchitectures": ["arm64"],
         "SupportedPlatform": "ios", "SupportedPlatformVariant": "simulator"}], "XCFrameworkFormatVersion": "1.0"}))
    code = ("import importlib.util, sys; s = importlib.util.spec_from_file_location('b', sys.argv[1]); "
            "m = importlib.util.module_from_spec(s); s.loader.exec_module(m); m.xcframework_slice(sys.argv[2])")
    out = subprocess.run([sys.executable, "-c", code, str(ROOT / "out/bin/isim-build.py"), str(arm)],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout
    assert "Arm.xcframework has no x86_64 iOS-simulator slice (it has: ios-arm64 (arm64), ios-arm64_arm64-simulator (arm64))" \
        in out, out


def test_package_tests(device_data, tmp_path):
    units = PROJ / "Packages/Units"
    out = str(tmp_path / "build")                                     # (not <package>/.build/isim: keeps the sample clean)
    rc, log = isim(device_data, "build", "-list", "-o", out, cwd=units)
    assert rc == 0 and re.search(r'^Information about workspace "Units":\n    Schemes:\n        Units$', log, re.M), log
    rc, log = isim(device_data, "test", "-scheme", "Units", "-o", out, cwd=units)
    tail = log[-6000:]
    assert rc == 0 and re.search(r"^\*\* TEST SUCCEEDED \*\*", log, re.M), f"the package's tests pass (exit {rc})\n{tail}"
    for t in ("testTableFromBundleModule", "testConvertThroughCore", "testInternalSymbol", "testMakesAnotherTestCase"):
        assert re.search(rf"Test Case .-\[UnitsTests\.UnitsTests {t}\]. passed", log), f"{t} passes\n{tail}"
    assert "Executed 5 tests, with 0 failures" in log and re.search(r"Test swiftTestingConvert\(\) passed", log), tail
    res = tmp_path / "results"
    rc, log = isim(device_data, "test", "-scheme", "Units", "-o", out, "-resultBundlePath", str(res),
                   "-only-testing:UnitsTests/UnitsTests/testFailsOnRequest", cwd=units, env={"UNITS_FAIL": "1"})
    assert rc == 65 and re.search(r"^\*\* TEST FAILED \*\*", log, re.M), f"a failing package test exits 65 (exit {rc})\n{log[-4000:]}"
    assert "Executed 1 test, with 1 failure" in log and "UNITS_FAIL is set" in log, log[-4000:]
    assert 'failures="1"' in (res / "UnitsTests.junit.xml").read_text()


def test_package_schemes(device_data, tmp_path):
    pkg = tmp_path / "Shapes"
    files = {
        "Package.swift": """// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "Shapes",
    platforms: [.iOS(.v17)],
    products: [.library(name: "Square", targets: ["Square"]), .library(name: "Circle", targets: ["Circle"])],
    targets: [
        .target(name: "Square"), .target(name: "Circle"),
        .testTarget(name: "SquareTests", dependencies: ["Square"]),
        .testTarget(name: "CircleTests", dependencies: ["Circle"]),
    ]
)
""",
        "Sources/Square/Square.swift": "public func area(side: Int) -> Int { side * side }\n",
        "Sources/Circle/Circle.swift": "public func diameter(radius: Int) -> Int { 2 * radius }\n",
        "Tests/SquareTests/SquareTests.swift": "import XCTest\nimport Square\n"
            "final class SquareTests: XCTestCase { func testArea() { XCTAssertEqual(area(side: 3), 9) } }\n",
        "Tests/CircleTests/CircleTests.swift": "import XCTest\nimport Circle\n"
            "final class CircleTests: XCTestCase { func testDiameter() { XCTAssertEqual(diameter(radius: 2), 4) } }\n",
    }
    for name, text in files.items():
        (pkg / name).parent.mkdir(parents=True, exist_ok=True)
        (pkg / name).write_text(text)
    rc, log = isim(device_data, "build", "-package-path", str(pkg), "-list", "-json", cwd=tmp_path)
    assert rc == 0, log
    assert json.loads(log[log.index("{"):])["workspace"] == {"name": "Shapes", "schemes": ["Circle", "Square", "Shapes", "Shapes-Package"]}
    out = str(tmp_path / "build")
    rc, log = isim(device_data, "test", "-scheme", "Square", "-o", out, cwd=pkg)
    assert rc == 0 and re.search(r"-\[SquareTests\.SquareTests testArea\]. passed", log), log[-4000:]
    assert "CircleTests" not in log, "a product's scheme runs only the test targets that depend on it"
    rc, log = isim(device_data, "test", "-scheme", "Shapes-Package", "-o", out, cwd=pkg)
    assert rc == 0 and re.search(r"CircleTests testDiameter\]. passed", log) and re.search(r"SquareTests testArea\]. passed", log), log[-4000:]
    rc, log = isim(device_data, "test", "-scheme", "Triangle", "-o", out, cwd=pkg)
    assert rc != 0 and "package Shapes has no scheme named Triangle (schemes: Circle, Square, Shapes, Shapes-Package)" in log, log
