"""Toolchain + test runner (HelloToolchain): the app built from a workspace with a static library, a dynamic framework,
local packages depending on each other, an XCFramework and .xcconfig files runs and shows values from all of them;
`isim test` runs the hosted unit tests (Swift + ObjC XCTest), the Swift Testing bundle and the XCUITest bundle and
reports success; deliberately failing tests (skipped by the scheme, selected with -only-testing) are reported as
failures with exit status 65; Release configuration; arm64-only XCFrameworks are rejected with a clear message.
Port of tests/ui/toolchain.sh."""
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


def isim(device_data, *args, timeout=900):
    env = dict(os.environ, ISIM_DATA=str(device_data), ISIM_DEVICE=DEFAULT_DEVICE, ISIM_HEADLESS="1",
               ISIM_SHOT_SCALE="1")
    p = subprocess.run([str(ISIM), *args], cwd=PROJ, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True, errors="replace", timeout=timeout)
    return p.returncode, p.stdout


def test_app(launch):
    app = launch("HelloToolchain")
    app.wait_log(r"HelloToolchain: «Hello, isim» \| MathKit 5 · XCFramework 7 · Units 20000 \| debug\+xcconfig · Howdy · "
                 r"objc score 42")                         # framework, static lib, packages, XCFramework, ObjC<->Swift
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
    assert not has(r"ExpectedFailureTests|ExpectedObjCFailureTests"), "the scheme skips the failing classes"
    assert has(r"Executed 1[0-9] tests, with 2 tests skipped and 0 failures"), "XCTest summary"
    assert has(r"Test conversion\(\) passed") and has(r"with 3 test cases passed") and has(r"Suite UnitsSuite passed"), \
        "Swift Testing runs @Test / @Suite"
    assert not has(r"deliberateFailure"), "Swift Testing skips FailingSuite (scheme)"
    for t in ("testLaunchShowsLibraries", "testTapIncrements", "testTypeText", "testSwitchAndQueries",
              "testRelaunchResetsState"):
        assert has(rf"AppUITests {t}\]. passed"), f"XCUITest: launch args/env, tap, typeText: {t}"
    junit = (res / "AppTests.junit.xml").read_text()
    assert '<testcase classname="AppTests.ModelTests" name="testAsync"' in junit and \
        "testcase" in (res / "AppSwiftTests.swift-testing.xml").read_text() and \
        (res / "AppUITests.log").stat().st_size > 0, "JUnit / xUnit reports written"


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
    assert has(r"Executed 5 tests, with 5 failures") and not has(r"testLinkedLibraries"), "only the selected tests ran"
    assert has(r"Expectation failed: \(Units\.convert\(1\) → 10000\) == 1") and has(r"Test deliberateFailure\(\) failed"), \
        "Swift Testing failure reported"
    assert has(r"Failed to tap: No matches found") and has(r"ExpectedUIFailureTests testMissingButton\]. failed"), \
        "XCUITest: tapping a missing element fails"


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
