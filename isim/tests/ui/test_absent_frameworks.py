"""`isim build` names iOS frameworks isim does not have (fixture AbsentFramework, issue #211): a Swift `import` or
an Objective-C `@import` of one fails with a message naming the framework and linking its coverage area in
docs/COVERAGE.md (out of scope for frameworks deprecated in iOS 17 or earlier), not only "no such module"; linking
one warns the same way; code behind `#if canImport` builds without it."""
import re
import shutil
import subprocess

import pytest
from isimtest import ISIM, ROOT

FIX = ROOT / "tests/fixtures/AbsentFramework"
COVERAGE = "https://github.com/kolabs-dev/isim/blob/main/docs/COVERAGE.md"


@pytest.fixture
def src(tmp_path):
    d = tmp_path / "AbsentFramework"
    shutil.copytree(FIX, d)
    return d


def build(src, *settings):
    p = subprocess.run([str(ISIM), "build", "-project", "AbsentFramework.xcodeproj", "-o", str(src / "build"), *settings],
                       cwd=src, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace", timeout=900)
    return p.returncode, p.stdout


def test_builds_without_the_framework(launch, src):
    rc, log = build(src)
    assert rc == 0, log
    assert re.search(r"warning: CarPlay is an iOS framework isim does not implement yet.*" + re.escape(f"{COVERAGE}#system")
                     + r".*\(not linked\)", log), f"linking CarPlay.framework warns with its coverage: {log[-2000:]}"
    app = launch(src / "build" / "AbsentFramework.app")
    app.wait_log(r"absent: canImport\(ARKit\) false objc ok")
    assert app.quit() == 0


def test_swift_import(src):
    rc, log = build(src, "SWIFT_ACTIVE_COMPILATION_CONDITIONS=USE_ARKIT")
    assert rc != 0
    assert "no such module 'ARKit'" in log, log[-2000:]
    assert re.search(r"isim build: error: ARKit is an iOS framework isim does not implement yet, so code that uses it does "
                     r"not build on isim\. Its coverage: " + re.escape(f"{COVERAGE}#games"), log), log[-2000:]
    assert "#if canImport(ARKit)" in log


def test_out_of_scope_import(src):
    rc, log = build(src, "SWIFT_ACTIVE_COMPILATION_CONDITIONS=USE_GLKIT")
    assert rc != 0
    assert re.search(r"isim build: error: GLKit is an iOS framework isim does not include: deprecated in iOS 12, so it is "
                     r"out of isim's scope \(" + re.escape(f"{COVERAGE}#out-of-scope"), log), log[-2000:]


def test_objc_import(src):
    rc, log = build(src, "GCC_PREPROCESSOR_DEFINITIONS=USE_CARPLAY=1")
    assert rc != 0
    assert re.search(r"isim build: error: CarPlay is an iOS framework isim does not implement yet.*" + re.escape(f"{COVERAGE}#system"),
                     log), log[-2000:]
