"""pytest setup for isim's tests (run them with `isim/build.py test`).

- `launch` fixture: start an app headless on scratch device data and drive it (isimtest.App); quit at the end.
- `ios` fixture: the iOS version / device for the test. Tests marked `os_matrix` run once per version with
  --os-matrix (iPhone 15 for iOS 17, iPhone 16 Pro for 18, iPhone 17 for 26 and 27).
- Longest tests first: durations of the last run (out/test-durations.json) order the collection, so a parallel run
  ends close to max(longest test, total / workers).
- The summary lists tests that only passed on a rerun (flaky), with their first attempt's failure (in full in
  out/pytest/flaky.txt), and the slowest tests.
"""
import json
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from isimtest import APPS, App, ROOT  # noqa: E402

DURATIONS = ROOT / "out" / "test-durations.json"
FLAKY_LOG = ROOT / "out" / "pytest" / "flaky.txt"
MATRIX = {"17": "iphone15", "18": "iphone16pro", "26": "iphone17", "27": "iphone17"}


def pytest_addoption(parser):
    parser.addoption("--os", default=os.environ.get("ISIM_OS_VERSION"), help="iOS version to run the apps under")
    parser.addoption("--device", default=None, help="device preset (default: ISIM_TEST_DEVICE or iphone16pro)")
    parser.addoption("--os-matrix", action="store_true", default=os.environ.get("OS_MATRIX") == "1",
                     help="also run os_matrix tests under iOS 17, 18, 26 and 27")


def pytest_generate_tests(metafunc):
    if "ios" not in metafunc.fixturenames:
        return
    if not (metafunc.config.getoption("--os-matrix") and metafunc.definition.get_closest_marker("os_matrix")):
        return                                       # one run, with --os / --device
    versions = [None, *MATRIX]
    metafunc.parametrize("ios", versions, ids=["default" if v is None else f"ios{v}" for v in versions],
                         indirect=True, scope="module")


@pytest.fixture(scope="module")
def ios(request):
    """(os_version, device) for this test: the matrix version, else --os / --device."""
    v = getattr(request, "param", None)
    if v:
        return v, MATRIX[v]
    return request.config.getoption("--os"), request.config.getoption("--device")


@pytest.fixture
def device_data(tmp_path):
    """A scratch device data directory (never the user's ~/.local/share/isim)."""
    d = tmp_path / "data"
    d.mkdir()
    return d


@pytest.fixture
def launch(device_data, ios):
    """launch("HelloNavigation", **options) -> isimtest.App, quit automatically at the end of the test."""
    apps = []
    os_version, device = ios

    def _launch(name, **kw):
        """name: an app in out/apps (or an .app Path); None boots the device (with install=[apps])."""
        for n in ([name] if isinstance(name, str) else []) + list(kw.get("install", ())):
            if not (APPS / f"{n}.app").is_dir():
                pytest.skip(f"{n}.app is not built")
        kw.setdefault("os_version", os_version)
        kw.setdefault("device", device)
        kw.setdefault("data", device_data)
        app = App(name, **kw).__enter__()
        apps.append(app)
        return app

    yield _launch
    for app in apps:
        app.quit()


@pytest.fixture(scope="module")
def launch_module(ios, tmp_path_factory):
    """launch for module-scoped fixtures (one app run shared by a module's tests): --os / --device apply (and the OS
    matrix, for modules marked os_matrix), and each call gets its own scratch device data unless data= is given. Apps
    quit at the end of the module. The module's tests run on one xdist worker (an xdist_group per module, build.py test
    --dist loadgroup), so the app runs once."""
    apps = []
    os_version, device = ios

    def _launch(name, **kw):
        for n in ([name] if isinstance(name, str) else []) + list(kw.get("install", ())):
            if not (APPS / f"{n}.app").is_dir():
                pytest.skip(f"{n}.app is not built")
        kw.setdefault("os_version", os_version)
        kw.setdefault("device", device)
        kw.setdefault("data", tmp_path_factory.mktemp("data"))
        app = App(name, **kw).__enter__()
        apps.append(app)
        return app

    yield _launch
    for app in apps:
        app.quit()


# ---- longest first ----
def pytest_collection_modifyitems(config, items):
    for it in items:                                 # one worker per module-shared app run (build.py test: --dist loadgroup)
        if "launch_module" in getattr(it, "fixturenames", ()):
            it.add_marker(pytest.mark.xdist_group(it.module.__name__))
    try:
        known = json.loads(DURATIONS.read_text())
    except (OSError, ValueError):
        return
    unknown = max(known.values(), default=60)       # new tests first: they may be long
    items.sort(key=lambda it: -known.get(it.nodeid, unknown))


_durations = {}


def pytest_runtest_logreport(report):
    if report.when == "call" or (report.when == "setup" and report.outcome != "passed"):
        _durations[report.nodeid] = _durations.get(report.nodeid, 0) + report.duration


def pytest_sessionfinish(session, exitstatus):
    if hasattr(session.config, "workerinput") or not _durations:
        return                                       # xdist workers: the controller records the durations
    try:
        known = json.loads(DURATIONS.read_text())
    except (OSError, ValueError):
        known = {}
    known.update({k: round(v, 2) for k, v in _durations.items()})
    DURATIONS.parent.mkdir(parents=True, exist_ok=True)
    DURATIONS.write_text(json.dumps(known, indent=0, sort_keys=True))


def _failure_line(report):
    """the assertion / exception line of a failed report"""
    crash = getattr(report.longrepr, "reprcrash", None)
    if crash is not None and crash.message:
        return crash.message.splitlines()[0]
    text = str(report.longrepr or "").strip().splitlines()
    return text[-1] if text else "(no message)"


def _failure_text(report):
    """a failed report's traceback and captured output, under a header"""
    out = [f"===== {report.nodeid} ({report.when}) =====", str(report.longrepr or "").rstrip()]
    out += [f"----- {name} -----\n{content.rstrip()}" for name, content in report.sections]
    return "\n".join(out) + "\n\n"


def pytest_terminal_summary(terminalreporter, exitstatus, config):
    tr = terminalreporter
    first = {}                                       # a rerun test's first (failed) attempt
    for r in tr.stats.get("rerun", []):
        first.setdefault(r.nodeid, r)
    failed = {r.nodeid for r in tr.stats.get("failed", [])}
    flaky = sorted(set(first) - failed)
    for nodeid in flaky:
        tr.write_line(f"FLAKY (passed on rerun): {nodeid}")
        tr.write_line(f"  first attempt: {_failure_line(first[nodeid])}")
    if flaky:                                        # the first attempts' full output (CI keeps out/pytest/*.txt)
        FLAKY_LOG.parent.mkdir(parents=True, exist_ok=True)
        FLAKY_LOG.write_text("".join(_failure_text(first[n]) for n in flaky))
        tr.write_line(f"first attempts of the flaky tests: {FLAKY_LOG}")
    slow = sorted(_durations.items(), key=lambda kv: -kv[1])[:5]
    if slow:
        tr.write_line("slowest: " + ", ".join(f"{n.split('::')[-1]} {d:.0f} s" for n, d in slow))
    if tr.stats.get("passed") or tr.stats.get("failed") or tr.stats.get("error"):
        tr.write_line("ALL TESTS PASSED" if exitstatus == 0 else "SOME TESTS FAILED")
