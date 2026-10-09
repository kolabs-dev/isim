# AGENTS.md

Guidance for AI coding agents (and people) working on isim, an iOS-compatible simulator and toolchain for Linux.
Code lives in `isim/`; see the [README](README.md) for what isim is and how it is used.

## Rules

- **Be honest about compatibility.**
  - Never falsify SDK or Xcode metadata to make an incompatible build look compatible.
  - Never quietly retarget an app to macOS or Linux and call that iOS compatibility.
- **Label what you implement.** Behaviour is *passthrough* (the host's function with the same ABI), *adapted*
  (isim's translation of Apple's behaviour) or a *stub*. Results are *verified* (a test checks it) or *proposed*.
- **No secrets in the repo.** Signing keys, certificates, provisioning profiles and API credentials stay local: never in
  source, logs, commits or issues.
- **ABI stability.** Apps built with older isim releases should keep running.
  - By default, never remove an exported symbol.
  - `python3 isim/tools/abi-check.py` compares the SDK with every recorded release (`isim/abi/`).
  - Swift overlays are built with library evolution (`EVOLUTION` in `isim/buildlib/swift.py`), so their types can
    change layout without breaking apps.
  - **Breaking on purpose is allowed** when keeping an old ABI would cost more than a rebuild: a large workaround,
    a lot of code kept only for old binaries, or an API that has to stay wrong (a placeholder type, a signature that
    differs from Apple's) to stay compatible. Prefer clean, honest code and ask users to rebuild over carrying shims.
    Cheap compatibility (a re-exported getter under the old name, one alias) is still worth keeping.
  - A deliberate break needs:
    - an entry, with the reason, in `isim/abi/epochs.txt` (a whole library) or `isim/abi/allowlist.txt` (single
      symbols); the comment says what must be rebuilt, from which version;
    - a minor (or major) release, never a patch release;
    - a line in the PR title or description saying which apps must be rebuilt (the release notes are generated from
      the PRs), and a note in the README's compatibility row when the break hits most apps (e.g. every Swift app).
  - Batch breaks: when one release already breaks a library, fold other pending breaks of it into the same release
    so users rebuild once.
- **Look and feel like real iOS.** isim's system UI (bars, controls, keyboards, sheets, alerts, menus, Liquid Glass,
  the home screen and Settings) mimics the real iOS of the version being emulated (`--os 17|18|26|27`): sizes,
  spacing, fonts, colours, materials and motion. Work from Apple's Human Interface Guidelines and from screenshots of
  real devices or Apple's Simulator, and compare isim's own samples against them. The look also follows the
  **device** (`--device`): iPhones with the Dynamic Island versus those with a notch or a Home button (status bar
  height and content, safe areas, corner radii, the home indicator), Plus / Pro Max sizes, and iPad (sidebars,
  popovers instead of sheets, the pointer, multitasking). Test system UI on the devices it differs on.
  Where isim looks or behaves differently from iOS, that is a bug: fix it, or open an issue labelled `look-and-feel`
  (see Issues) with a screenshot of isim, a reference screenshot or description of iOS, and where the drawing lives.
- **Never touch the user's device data.** Tests and experiments use a scratch `ISIM_DATA`, never
  `~/.local/share/isim`.

## Build and test

```bash
isim/build.py fetch              # pinned Swift / LLVM sources into third_party/ (once)
isim/build.py                    # build (Ninja; a no-op build takes well under a second)
isim/build.py test               # all tests (pytest, parallel); -k NAME for a subset
OS_MATRIX=1 isim/build.py test   # also run the version-sensitive tests under iOS 17, 18, 26 and 27
python3 isim/tools/abi-check.py  # exported symbols against every release
```

- [docs/BUILD.md](docs/BUILD.md) covers the build graph (`isim/buildlib/`), adding samples, frameworks and Swift
  overlays.
- [docs/TESTING.md](docs/TESTING.md) covers writing tests with the `isimtest` driver.
- **Waits:** tests wait for conditions (`wait_for`, `wait_log`, `wait_view`, `wait_shot`), never for fixed times, so
  they hold up on slow or busy machines.

## Workflow

- **Branches and PRs.** Make every change on a branch and open a pull request. Merges into `main` are squashed.
- **Local checks first.** Before opening a PR, run the full local build, `isim/build.py test`, `OS_MATRIX=1` when the
  change is version-sensitive, and the ABI check. Put the results in the PR description.
- **Screenshots.** When a change is visible (UI, drawing, system UI), attach screenshots of isim's own samples to the
  PR: reference them in the body as `![what it shows](./name.png)` and upload them with
  `gh pr edit <PR> --body-file body.md --attach ./name.png` (run where the files are; `gh` rewrites the references).
- **CI.** CI runs a stock Ubuntu 24.04 image: one build job (build, ABI check), then four test jobs in parallel, one
  per iOS version (iOS 18 runs every test; 17, 26 and 27 the `os_matrix` tests), then the status.
  - On a PR, start it by hand: Actions → CI → Run workflow, on the PR's branch.
  - Its commit status `ci / build and test` is required to merge.
  - Pushes to `main` run it automatically.
- **When you add or change an API:**
  - update its row in [docs/COVERAGE.md](docs/COVERAGE.md) (status, notes, the test that verifies it) and the summary
    tables (`isim/tools/coverage-summary.py`);
  - add or extend a sample app (`isim/samples/`) and a pytest test (`isim/tests/`);
  - check each supported iOS version: 17, 18, 26 and 27 ([docs/IOS-VERSIONS.md](docs/IOS-VERSIONS.md)): mark tests of
    version-dependent behaviour (system UI, chrome frames / pixels, `@available` APIs) `@pytest.mark.os_matrix` and run
    `OS_MATRIX=1` locally (CI's test job of each iOS version runs them too). The rules: [docs/TESTING.md](docs/TESTING.md#which-tests-run-under-every-ios-version-os_matrix).
- **Issues.** A bug that is not fixed right away gets a GitHub issue with enough context to fix it later: symptom,
  reproduction, where to look. Missing API coverage is tracked by one issue per COVERAGE.md area (label `coverage`).
  - **Every issue has at least one label** from the table below (several when they apply, e.g. `bug` and
    `performance`). When none fits, create a new label (`gh label create NAME --description ... --color ...`) and
    add it to the table in the same PR or right after.

| Label | Use it for |
|---|---|
| `bug` | something isim does wrong (a crash, a wrong result, a hang) |
| `enhancement` | new functionality |
| `coverage` | API coverage toward 100%, one issue per COVERAGE.md area (with `enhancement`) |
| `look-and-feel` | isim's UI does not look or behave like real iOS of that version (with a reference screenshot) |
| `performance` | correct but too slow (an O(n) lookup, a slow load) |
| `flaky-test` | a test that passes or fails intermittently |
| `ci` | the CI workflows, runners and caches |
| `abi` | ABI stability: deliberate breaks, baselines, `abi-check.py` |
| `documentation` | docs (`docs/`, AGENTS.md, README) |
| `duplicate`, `invalid`, `wontfix`, `question`, `help wanted`, `good first issue` | GitHub's defaults, for triage |

## Releases

Releases are made by the Release workflow (`.github/workflows/release.yml`):

1. **Start it on `main`:** Actions → Release → Run workflow, choosing patch, minor or major. It runs only when CI passed
   on `main`'s head.
2. **What it does:**
   - sets the next version after the latest tag (`isim/build.py version patch|minor|major`);
   - builds and packages it (`isim/build.py package X.Y.Z`) and smoke-tests the tarball;
   - records the ABI baseline;
   - opens a "Release X.Y.Z" pull request (`isim/VERSION`, the README's examples, `isim/abi/vX.Y.Z.txt.gz`) and starts
     CI on it.

   A dry run stops after the smoke test and keeps the tarball as an artifact.
3. **Merge that pull request.** The merge publishes the tag `vX.Y.Z` and the GitHub release, with the tarball and notes
   generated by GitHub.

## Docs

| Doc | Covers |
|---|---|
| [docs/BUILD.md](docs/BUILD.md) | building, the Ninja graph, adding things |
| [docs/TESTING.md](docs/TESTING.md) | the test driver, CI |
| [docs/COVERAGE.md](docs/COVERAGE.md) | API coverage per framework and per iOS version |
| [docs/IOS-VERSIONS.md](docs/IOS-VERSIONS.md) | `--os 17\|18\|26\|27` and what changes per version |
| [docs/SCRIPTING.md](docs/SCRIPTING.md) | script commands and the `--control` channel |
| [docs/SYSTEM-PROMPTS.md](docs/SYSTEM-PROMPTS.md) | environment variables, simulated hardware |
| [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) | why App Store upload from Linux is blocked |
