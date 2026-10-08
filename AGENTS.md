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
- **ABI stability.** Apps built with older isim releases must keep running.
  - Never remove an exported symbol.
  - `python3 isim/tools/abi-check.py` compares the SDK with every recorded release (`isim/abi/`).
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
- **CI.** CI runs a stock Ubuntu 24.04 image: build, ABI check, all tests.
  - On a PR, start it by hand: Actions → CI → Run workflow, on the PR's branch.
  - Its commit status `ci / build and test` is required to merge.
  - Pushes to `main` run it automatically.
- **When you add or change an API:**
  - update its row in [docs/COVERAGE.md](docs/COVERAGE.md) (status, notes, the test that verifies it) and the summary
    tables (`isim/tools/coverage-summary.py`);
  - add or extend a sample app (`isim/samples/`) and a pytest test (`isim/tests/`);
  - check each supported iOS version: 17, 18, 26 and 27 ([docs/IOS-VERSIONS.md](docs/IOS-VERSIONS.md)).
- **Issues.** A bug that is not fixed right away gets a GitHub issue with enough context to fix it later: symptom,
  reproduction, where to look. Missing API coverage is tracked by one issue per COVERAGE.md area (label `coverage`).

## Releases

After significant changes land on `main`:

1. Bump `isim/VERSION` and the version examples in the README, in a PR.
2. Build the tarball with `isim/build.py package X.Y.Z`, and test the package (install it, run a demo app).
3. Tag `vX.Y.Z` on `main` and publish a GitHub release with the tarball, its `.sha256` and release notes.
4. Record the ABI baseline: `python3 isim/tools/abi-check.py --record X.Y.Z <release sdk>`, committed in a PR.

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
