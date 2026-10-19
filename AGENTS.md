# AGENTS.md

Guidance for AI coding agents (and people) working on isim, an iOS-compatible simulator and toolchain for Linux.
Code lives in `isim/`; see the [README](README.md) for what isim is and how it is used.

## Rules

- **Be honest about compatibility.**
  - Never falsify SDK or Xcode metadata to make an incompatible build look compatible.
  - Never quietly retarget an app to macOS or Linux and call that iOS compatibility.
- **Only Apple's SDK.** isim re-implements what belongs to iOS: Apple's frameworks, system UI and tools. It never
  re-implements, stubs or stands in for third-party libraries (Google Mobile Ads, Google UMP, Firebase, AppLovin,
  Meta, …), even closed-source ones. Apps get those from their own packages, which `isim build` fetches and builds
  (source, or an `.xcframework`'s simulator slice); when one does not run on isim, fix the iOS API it needs, or record
  the gap (its framework page in docs/frameworks/, a `coverage` issue). Sample apps may use third-party libraries to
  show how they run on isim.
- **Label what you implement.** Behaviour is *passthrough* (the host's function with the same ABI), *adapted*
  (isim's translation of Apple's behaviour) or a *stub*. Results are *verified* (a test checks it) or *proposed*.
- **No secrets in the repo.** Signing keys, certificates, provisioning profiles and API credentials stay local: never in
  source, logs, commits or issues.
- **Match Apple's API exactly.** Same names, kinds and signatures as Apple's SDK, so iOS code compiles unchanged: a
  class stays a class, an enum stays an enum, and no `AnyObject?` or `Int` placeholders stand in for Apple's types.
  `isim/tools/api-coverage.py` (exact mode) lists what differs.
- **Objective-C and C too.** Every framework isim implements in Swift also gets Apple's Objective-C/C interface:
  headers in `isim/sdk-src/Frameworks/<Name>` over the Swift classes (`SWIFT_FRAMEWORKS` in `isim/buildlib/graph.py`).
  Most binary SDKs, and many apps, are Objective-C.
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
- **Keep the host runtime portable** (native Windows later: issue #491). isim runs on Linux today; new host code in
  `isim/runtime` must not make another host OS harder:
  - operating-system services (starting processes, opening things on the desktop, shared memory, IPC, control
    channels, the runtime's own path) go through the platform layer, `runtime/platform.h`: no new `fork`/`exec`,
    `posix_spawn`, `memfd_create`, `socketpair`, `mkfifo`, `/proc` or `xdg-open` elsewhere. A service it lacks is added
    to `platform.h` and `platform_posix.c`;
  - every host function a symbol table hands to guests is marked `ISIM_GUEST_ABI` (definition and prototypes), and
    function pointers the host calls guest code through are typed `ISIM_GUEST_CALLBACK`;
  - libSystem code that implements a Darwin API over a Linux one says so: `/* linux-only: what it implements */`;
  - `isim/tools/portability-check.py` (run by the CI build and `test_portability.py`) enforces this against
    `isim/data/portability-baseline.txt`, which may only shrink. Details: [docs/BUILD.md](docs/BUILD.md#portability).
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
python3 isim/tools/portability-check.py   # host code stays portable (docs/BUILD.md, "Portability")
```

- [docs/BUILD.md](docs/BUILD.md) covers the build graph (`isim/buildlib/`), adding samples, frameworks and Swift
  overlays.
- [docs/TESTING.md](docs/TESTING.md) covers writing tests with the `isimtest` driver.
- **Waits:** tests wait for conditions (`wait_for`, `wait_log`, `wait_view`, `wait_shot`), never for fixed times, so
  they hold up on slow or busy machines.

## Workflow

- **Branches and PRs.** Make every change on a branch and open a pull request. Merges into `main` are squashed.
- **Local checks first.** Before opening a PR, run the full local build, `isim/build.py test`, `OS_MATRIX=1` when the
  change is version-sensitive, the ABI check and the portability check. Put the results in the PR description.
- **Screenshots on applicable PRs.** When a change has a meaningful visual result (UI, drawing, system UI), include
  authentic screenshots of isim's own samples in the PR. Capture the changed state in a test or scripted sample when
  practical; do not use mockups or unrelated images. Screenshot-only evidence is not required for non-visual changes.
  They live on the `screenshots` branch, which holds only images shown in PRs (no code, never merged):
  - add them in a folder named after the PR number (`screenshots:<PR>/<name>.png`), in a commit on that branch alone
    (e.g. a separate clone or worktree with `git checkout screenshots`), and push it;
  - show them in the PR body or a PR comment as
    `![what it shows](https://github.com/kolabs-dev/isim/blob/screenshots/<PR>/<name>.png?raw=true)`;
  - never delete or rename files there (the PRs that show them would break), and never commit screenshots to a PR's
    own branch (the squash merge would put them in `main`).
- **CI.** CI runs a stock Ubuntu 24.04 image: one build job (build, ABI check), then four test jobs in parallel, one
  per iOS version (iOS 18 runs every test; 17, 26 and 27 the `os_matrix` tests), then the status.
  - On a PR, start it by hand: Actions → CI → Run workflow, on the PR's branch.
  - Its commit status `ci / build and test` is required to merge.
  - Pushes to `main` run it automatically.
- **When you add or change an API:**
  - update its row on its framework page, `docs/frameworks/<Module>.md` (status, iOS version, notes with the
    passthrough / adapted / stub label, the test that verifies it). Create the page from `docs/frameworks/_template.md`
    when the framework has none, with the module in `isim/data/frameworks.json`;
  - tick its item in the `coverage` issue that lists it;
  - add or extend a sample app (`isim/samples/`) and a pytest test (`isim/tests/`);
  - keep it usable by AI agents: anything a person can do in the device window (a button, a gesture, a menu item) is
    also a script command in [docs/SCRIPTING.md](docs/SCRIPTING.md) or an `isim` subcommand, with text or file
    output; update [docs/AI-AGENTS.md](docs/AI-AGENTS.md) when it changes the agent workflow;
  - check each supported iOS version: 17, 18, 26 and 27 ([docs/IOS-VERSIONS.md](docs/IOS-VERSIONS.md)): mark tests of
    version-dependent behaviour (system UI, chrome frames / pixels, `@available` APIs) `@pytest.mark.os_matrix` and run
    `OS_MATRIX=1` locally (CI's test job of each iOS version runs them too). The rules: [docs/TESTING.md](docs/TESTING.md#which-tests-run-under-every-ios-version-os_matrix).
- **Coverage.** The goal is 100% of the iOS API ([docs/COVERAGE.md](docs/COVERAGE.md)).
  - **Scope:** every framework Apple documents for iOS is tracked, unless it is Apple-platform-only and completely
    impossible to replicate on Linux. Deprecated APIs are in scope while they are usable in some iOS 17–27 (deprecated
    in iOS 18 or later); those deprecated in iOS 17 or earlier are out of scope.
  - **Work is split into small `coverage` issues** (S ≤ 1 day, M 2–3 days, L ≤ 1 week), one per batch of APIs, each
    description a checklist with a link to Apple's documentation per item. There are no parent issues or sub-issues;
    `area:*` labels group them. Use the "Coverage batch" issue form. Claim an issue (assign yourself or comment) before
    starting, so two agents don't take the same batch.
  - **No conflicts between pull requests:** edit rows and prose on the framework pages only. Never edit the generated
    parts by hand (between `<!-- generated:… -->` markers in COVERAGE.md and the pages, `isim/data/api-coverage.json.gz`)
    and don't regenerate them in a pull request. The Release workflow rebuilds them with
    `isim/tools/api-coverage.py measure` and `isim/tools/coverage-summary.py`.
  - **Sweeps:** re-run the documentation sweep ([docs/API-SWEEP.md](docs/API-SWEEP.md)) after each Apple SDK release and
    before each minor release; it refreshes the Apple snapshot and the "Not yet in isim" lists.
- **Issues.** A bug that is not fixed right away gets a GitHub issue with enough context to fix it later: symptom,
  reproduction, where to look. Missing API coverage: see Coverage above.
  - **Every issue has at least one label** from the table below (several when they apply, e.g. `bug` and
    `performance`). When none fits, create a new label (`gh label create NAME --description ... --color ...`) and
    add it to the table in the same PR or right after.

| Label | Use it for |
|---|---|
| `bug` | something isim does wrong (a crash, a wrong result, a hang) |
| `enhancement` | new functionality |
| `coverage` | API coverage toward 100%: one small batch of APIs per issue, a checklist (with `enhancement`) |
| `area:<key>` | the COVERAGE.md area of a `coverage` issue (`area:uikit`, `area:media`, …; keys in `isim/data/frameworks.json`) |
| `size:S`, `size:M`, `size:L` | a `coverage` issue's size: up to 1 day, 2–3 days, up to 1 week |
| `wave:0` … `wave:4` | the order of `coverage` work: 0 docs and measurement, 1 unblocks whole kinds of apps, 2 common frameworks, 3 GPU, 4 the rest |
| `objc-interface` | an Objective-C / C interface for a framework isim implements in Swift |
| `blocked` | cannot be done yet; the issue says why |
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
   - refreshes the coverage numbers (`isim/tools/api-coverage.py measure` on the built SDK, then
     `isim/tools/coverage-summary.py`);
   - opens a "Release X.Y.Z" pull request (`isim/VERSION`, the README's examples, `isim/abi/vX.Y.Z.txt.gz`, the coverage
     data and the generated parts of `docs/COVERAGE.md` and `docs/frameworks/`) and starts
     CI on it.

   A dry run stops after the smoke test and keeps the tarball as an artifact.
3. **Merge that pull request.** The merge publishes the tag `vX.Y.Z` and the GitHub release, with the tarball and notes
   generated by GitHub.

## Docs

| Doc | Covers |
|---|---|
| [docs/BUILD.md](docs/BUILD.md) | building, the Ninja graph, adding things |
| [docs/TESTING.md](docs/TESTING.md) | the test driver, CI |
| [docs/COVERAGE.md](docs/COVERAGE.md) | API coverage: the index of every iOS framework, summaries per area and per iOS version |
| [docs/frameworks/](docs/frameworks/) | one page per framework: how isim implements it, its rows, what it still lacks |
| [docs/API-SWEEP.md](docs/API-SWEEP.md) | how coverage is measured against Apple's documentation, and how to repeat it |
| [docs/IOS-VERSIONS.md](docs/IOS-VERSIONS.md) | `--os 17\|18\|26\|27` and what changes per version |
| [docs/SCRIPTING.md](docs/SCRIPTING.md) | script commands and the `--control` channel |
| [docs/AI-AGENTS.md](docs/AI-AGENTS.md) | developing apps with AI coding agents |
| [docs/SYSTEM-PROMPTS.md](docs/SYSTEM-PROMPTS.md) | environment variables, simulated hardware |
| [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) | why App Store upload from Linux is blocked |
