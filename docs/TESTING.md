# Testing

isim's tests are pytest suites under `isim/tests` (one `test_*.py` per sample or area). Run them with:

```bash
isim/build.py test                    # every test, in parallel (build first: isim/build.py)
isim/build.py test -k navigation      # pytest arguments pass through
OS_MATRIX=1 isim/build.py test        # also run os_matrix tests under iOS 17, 18, 26 and 27
```

`build.py test` uses the virtualenv `isim/out/pyenv` (created from `isim/requirements.txt`: pytest, pytest-xdist,
pytest-rerunfailures, Pillow, ninja) and runs pytest with `ISIM_TEST_JOBS` workers (default half the CPUs, 2–16). A failed
test is retried once (`ISIM_TEST_RETRY=0` turns that off); tests that only passed on the retry are listed as flaky.
The longest tests start first (times of the last run are kept in `out/test-durations.json`).

## Writing a test

The `isimtest` driver runs an app headless on scratch device data with a live control channel and drives it step by
step. Tests wait for conditions, never for fixed times:

```python
def test_navigation(launch):
    app = launch("HelloNavigation")                # out/apps/HelloNavigation.app, quit after the test
    app.wait_for(id="book-3").tap()                # polls the accessibility snapshot
    app.wait_log("detail 3 appears")               # waits for a line in the app's output
    assert app.wait_for(id="bar-Favorite").enabled
    assert is_red(app.screenshot().getpixel((20, 120)))   # a Pillow image, pixels in points
```

- **Fixtures.** `launch` (per test) and `launch_module` (one app shared by a module's tests; those tests run on one
  xdist worker, `--dist loadgroup`) start apps; `launch(None, install=[...])` boots the device with apps installed.
  `ios` gives the test's iOS version and device.
- **Waits.** `wait_for(id=/label=/type=, gone=)`, `wait_log(regex, count=)`, `wait_view` (view tree; `wait_view(visible("id"), gone=True)`
  for a view that is gone or hidden),
  `wait_dump` (system UI under `isim boot`), `wait_still` (no change for a moment, e.g. after a transition),
  `wait_shot` / `wait_shot_still` (screenshots) and `wait_until(condition)`.
- **Self-tests.** Apps that test themselves (FoundationTest, SwiftConcurrencyTest, …) print `N/M passed`;
  `selftest("FoundationTest")` runs one and requires N == M.
- **Markers.** `@pytest.mark.os_matrix` runs a test once per iOS version with `--os-matrix` (see below).
- **Missing tools.** A test that needs an optional host tool (ffmpeg, zbar, tesseract, …) skips when it is missing.

Tests run with `ISIM_SKIP_LAUNCH_SCREEN=1` and, where a test asks for it, `ISIM_ANIMATIONS=0`
(see [SYSTEM-PROMPTS.md](SYSTEM-PROMPTS.md)).

## Which tests run under every iOS version (`os_matrix`)

isim emulates iOS 17, 18, 26 and 27 (`--os`, [IOS-VERSIONS.md](IOS-VERSIONS.md)), and much of the system UI it draws
changes between them (Liquid Glass on 26 / 27, iOS 18's controls, iOS 17's older behaviour). A test that only runs
on the default version can pass while another version is broken, so mark it `@pytest.mark.os_matrix` when it:

- **drives or checks system UI that differs by version:** navigation bars and back buttons, tab bars, toolbars,
  search bars, sheets / popovers / full-screen presentations, alerts, action sheets, menus, context menus, table and
  collection list styles, controls (buttons, switches, segmented controls, sliders, steppers, pickers), the keyboard,
  and the screens isim draws for the system (photo / document / colour / font pickers, the share sheet, print
  options, Quick Look, the camera);
- **asserts on frames, pixels or screenshots** of that chrome (positions and sizes differ between versions);
- **uses version-dependent code paths:** `@available(iOS 18 / 26 / 27, *)` APIs, anything that reads the reported
  version (`ISIM_OS_VERSION`, `isim_ui_glass()`, `sys_os()` in the shell), deprecated-in-a-version behaviour;
- **is a self-test of Foundation / Swift behaviour** that changed between iOS releases.

Do not mark tests that are the same everywhere: pure computation and drawing (Core Graphics, `UIBezierPath`, fonts),
data APIs (Codable, URL, archives), the loader, the test harness, host tools.

When a test is marked:

- it runs under iOS 17 (iPhone 15), 18 (iPhone 16 Pro), 26 and 27 (iPhone 17); use the `ios` fixture
  (`launch` already passes it) rather than a fixed `--device`, since iPhone 17 does not run iOS 17 / 18;
- it must pass under all four; where a feature does not exist in a version, `pytest.skip` with the reason (as the
  iOS 17 exclusions do);
- CI runs them in its **os matrix** job (in parallel with the main job; both must pass for `ci / build and test`);
  run `OS_MATRIX=1 isim/build.py test` locally first and put the result in the pull request's description.

Quick check while writing a test: if the code under test calls `isim_ui_glass()` / `sys_os()` or reads
`ISIM_OS_VERSION` (`grep -rn "isim_ui_glass\|sys_os()\|ISIM_OS_VERSION" isim/frameworks isim/runtime isim/swift`),
or the test looks at system chrome, mark it.

## CI

`.github/workflows/ci.yml` builds isim and runs every test plus the ABI check in a stock Ubuntu 24.04 image
(`isim/ci/Dockerfile`), so CI also proves isim works on an ordinary Linux. A second job, **os matrix**, runs in
parallel and runs the `os_matrix` tests under iOS 17, 18, 26 and 27 (`build.py ci test -- -m os_matrix`); the
commit status `ci / build and test` is posted when both are done and passes only if both do. For pull requests it runs only on demand: Actions → CI → Run
workflow on the PR's branch. Pushes to `main` run it automatically, which keeps `main`'s build cache fresh: a
branch's first run starts from it. The build directory is cached; `build.py ci` gives sources whose content is unchanged
their cached timestamps back (a checkout gives every file a new one), so Ninja rebuilds only what the branch changed; JUnit results and failure screenshots are uploaded as artifacts.

To reproduce CI locally:

```bash
docker build -t isim-ci isim/ci
docker run --rm -v "$PWD:$PWD" -w "$PWD" -v /var/run/docker.sock:/var/run/docker.sock isim-ci python3 isim/build.py ci
```
