# Testing: findings and proposal

Status: **proposal** (2026-10-07). The prototype in `isim/tests/py/` runs today; nothing else here is adopted yet.

## What we have

- `isim/test.sh` runs 99 suites in parallel (`ISIM_TEST_JOBS`, default 8), each with its own scratch device data.
- 89 suites are bash scripts (`tests/ui/*.sh`, `tests/*/run.sh`, ~3,600 lines, 1,286 checks). They launch an app with a
  fixed script (`ISIM_SCRIPT="wait 1; tapid x; wait 0.8; dump; …"`), collect its output, then grep it.
- A few suites are self-tests inside an app (FoundationTest, SwiftLibrariesTest, …) that print `N/M passed`.

## Measurements

| | Value |
|---|---|
| Full suite, 8 jobs (default) | 219 s |
| Full suite, 16 jobs | 127 s, no flaky suites |
| Sum of all suite times | 1,448 s |
| Fixed `wait` seconds in the scripts | 1,157 s (**~80% of all test time is sleeping**) |
| Longest suites | HelloPush 74 s, HelloStore 64 s, HelloOSVersions 60 s, HelloBackground 47 s |
| `build.sh` with nothing changed | **492 s**: Swift overlays 311 s (always rebuilt), ~100 samples 157 s |

Problems in the scripts:
- **Duplication.** Helpers are copied: `check` (85 scripts), `px` (25), `run` (22), `has`/`is` (11).
- **Fragile checks.**
  - Checks grep the textual view dump with regexes and count `UIWindow` lines to find "the 4th dump".
  - The `pipefail` + `grep -q` race made checks fail randomly until it was fixed.
- **Slow pixel checks.** Each pixel check spawns an ImageMagick process.
- **Fixed sleeps only.** A script cannot wait for something to happen, so every step sleeps long enough for the
  slowest machine. Under load, steps still race, which is what causes most flakiness.
- **Late output.** App output was block-buffered through a pipe, so it was visible only when the app exited.
  The prototype branch fixes this: the runtime line-buffers `stdout`.

## Proposal

### 1. Python tests with condition waits (prototype included)

The `isimtest` driver (`isim/tests/py/isimtest.py`) runs an app headless with a live control channel
(`--control FIFO`) and drives it step by step:

```python
def test_navigation(launch):
    app = launch("HelloNavigation")
    app.wait_for(id="book-3").tap()                # polls the accessibility snapshot (`dump FILE`)
    app.wait_log("detail 3 appears")               # waits for a line in the app's output
    assert app.wait_for(id="bar-Favorite").enabled
    shot = app.screenshot()                        # a Pillow image; pixels in points
```

- **Waiting.** `wait_for(id=/label=/type=, gone=)`, `wait_log(regex, count=)`, `snapshot()` and `find()` replace
  sleeps and greps. A test waits exactly as long as the app needs.
- **Pixels.** Screenshots open in Pillow, so a test can check any number of pixels without spawning processes.
- **pytest.** Fixtures (`launch`) handle scratch device data, device and iOS version (`--os`, `--device`); quitting
  and cleanup are automatic. pytest also brings readable failures, `-k` to select tests, JUnit XML for CI and
  `pytest-xdist` for parallel runs.
- **Measured.** The navigation suite went from 12.0 s (shell) to **3.6 s** with the same checks; source-compat is
  about the same (its time is the app launch).

Migration:
1. Add `isim/tests/requirements.txt` (pytest, pytest-xdist, Pillow). `test.sh` creates `isim/out/pyenv` on first use
   and runs `pytest -n auto tests/py` as part of the pool; the CI image installs the Arch packages.
2. Port suites longest first (Push, Store, OSVersions, Background, Safari, …). One module per sample, with one app
   launch shared by several test functions (module-scoped fixture), so failures point at a behaviour instead of a
   whole suite. Delete each shell script when its port passes.
3. Wrap the in-app self-tests (`N/M passed`) in thin pytest tests, so `pytest` is the single entry point.
4. Run the OS matrix as pytest parametrization (`--os 17 18 26 27` → one test id per version).

### 2. Make the suite faster now (small changes)

- **More jobs.** Raise the default `ISIM_TEST_JOBS` to half the CPUs, at most 16: 219 s → 127 s, measured.
- **Longest first.** `test.sh` now records every suite's time (`out/test-logs/times.tsv`). Starting the longest
  suites first makes the wall time about max(longest suite, total ÷ jobs) ≈ 90 s.
- **Split the long poles.** Push, Store and OSVersions each run several independent scenarios one after another.

### 3. Runtime support for tests

- **Animations off.** An `ISIM_ANIMATIONS=0` switch (like disabling animations for UI tests on iOS) would make
  UIKit/SwiftUI animations complete at once. Most remaining sleeps wait for animations.
- **No launch screen.** `ISIM_SKIP_LAUNCH_SCREEN=1` would drop the launch-screen fade, about 0.5 s on every launch.
- **Atomic snapshots.** `dump FILE` should write a temporary file and rename it, so readers never see half a
  snapshot.

### 4. Incremental build (the biggest cost in the edit → test loop)

- **Swift overlays.** Skip a module when its sources and its dependencies' interfaces are unchanged (a stamp per
  module). That is 311 s → ~0 s when Swift is untouched.
- **Samples.** Rebuild only when their sources or the SDK changed.
- **Target.** A no-change `build.sh` under 30 s, and a one-file change rebuilds only what depends on it.

### Expected result

| | Now | After 2 | After 1–4 |
|---|---|---|---|
| No-change build + full tests | ~12 min | ~10 min | ~2 min |
| Full tests only | 219 s | ~90 s | ~60 s (condition waits) |
