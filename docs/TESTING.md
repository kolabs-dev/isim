# Testing

isim's tests are pytest suites under `isim/tests` (one `test_*.py` per sample or area). Run them with:

```bash
isim/test.sh                          # every test, in parallel
isim/test.sh -k navigation            # pytest arguments pass through
OS_MATRIX=1 isim/test.sh              # also run os_matrix tests under iOS 17, 18, 26 and 27
```

`test.sh` creates a virtualenv in `isim/out/pyenv` from `isim/tests/requirements.txt` (pytest, pytest-xdist,
pytest-rerunfailures, Pillow) and runs pytest with `ISIM_TEST_JOBS` workers (default half the CPUs, 2–16). A failed
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

- **Fixtures.** `launch` (per test) and `launch_module` (one app shared by a module's tests) start apps;
  `launch(None, install=[...])` boots the device with apps installed. `ios` gives the test's iOS version and device.
- **Waits.** `wait_for(id=/label=/type=, gone=)`, `wait_log(regex, count=)`, `wait_view` (view tree),
  `wait_dump` (system UI under `isim boot`), `wait_still` (no change for a moment, e.g. after a transition),
  `wait_shot` / `wait_shot_still` (screenshots) and `wait_until(condition)`.
- **Self-tests.** Apps that test themselves (FoundationTest, SwiftConcurrencyTest, …) print `N/M passed`;
  `selftest("FoundationTest")` runs one and requires N == M.
- **Markers.** `@pytest.mark.os_matrix` runs a test once per iOS version with `--os-matrix`.
- **Missing tools.** A test that needs an optional host tool (ffmpeg, zbar, tesseract, …) skips when it is missing.

Tests run with `ISIM_SKIP_LAUNCH_SCREEN=1` and, where a test asks for it, `ISIM_ANIMATIONS=0`
(see [SYSTEM-PROMPTS.md](SYSTEM-PROMPTS.md)).

## CI

`.github/workflows/ci.yml` builds isim and runs every test plus the ABI check in a stock Ubuntu 24.04 image
(`isim/ci/Dockerfile`), so CI also proves isim works on an ordinary Linux. It runs only on demand: Actions → CI → Run
workflow on a pull request's branch. The build is cached by content (`isim/tools/fresh.py`), so a run rebuilds only
what the branch changed; JUnit results and failure screenshots are uploaded as artifacts.

To reproduce CI locally:

```bash
docker build -t isim-ci isim/ci
docker run --rm -v "$PWD:$PWD" -w "$PWD" -v /var/run/docker.sock:/var/run/docker.sock isim-ci isim/ci/run.sh
```
