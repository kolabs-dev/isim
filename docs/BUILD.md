# Building isim

`isim/build.py` is the single entry point: it writes a Ninja graph (`isim/out/build.ninja`) and runs it.

```bash
isim/build.py fetch            # pinned Swift / LLVM sources into third_party/ (once)
isim/build.py                  # everything
isim/build.py runtime          # a part: runtime, sdk-c, swift-core, overlays, swift, apps
isim/build.py out/apps/HelloTable.app/HelloTable   # or any output
isim/build.py test             # the tests (docs/TESTING.md)
isim/build.py package 0.9.0    # a release tarball in isim/dist/
```

Ninja runs a step only when one of its inputs changed and runs independent steps in parallel (Swift compiles share a
pool sized by memory). A build with nothing to do takes about 0.15 s; one changed framework file recompiles that file
and relinks.

## The graph (`isim/buildlib/`)

| File | Builds |
|---|---|
| `graph.py` | host runtime (`isim-runtime`, `isim-webkit`), SDK headers, `.tbd` stubs, the Objective-C frameworks, tools |
| `swift.py` | the Swift core (stdlib, runtime, libc++, Concurrency, Observation, Synchronization, Distributed, Regex), the overlays (`OVERLAYS` table), Swift Testing |
| `apps.py` | samples, self-test apps (`tests/*`), system apps |
| `act.py` | small actions the edges run (mirror files, `.tbd` generation, keep unchanged outputs' timestamps) |
| `fetch.py`, `package.py` | third-party pins; release packaging |

Changes do not cascade needlessly: steps that rewrite an output with the same content keep its old timestamp (Ninja
`restat`), so a comment-only change in an overlay recompiles that overlay and nothing else. Apps depend on the SDK's
interface (headers, Swift module files, `.tbd` stubs), not on framework implementations.

## Warnings are errors

isim's own code builds without warnings, and a new warning fails the build: the host runtime, the Objective-C
frameworks, the Swift overlays, the samples and the test apps compile with `-Werror` (C, Objective-C) or
`-warnings-as-errors` (Swift). Deprecations stay warnings (`-Wno-error=deprecated-declarations`,
`-Wwarning DeprecatedDeclaration`). Upstream code (the Swift stdlib, Swift Testing) builds with `-suppress-warnings`.
A compiler newer than CI's may warn about more; `ISIM_WERROR=0 isim/build.py` builds with warnings left as warnings.

## Adding things

- **A sample**: a directory in `isim/samples` with Swift files and an `Info.plist` builds as `<Dir>.app` with no
  build code. Anything else (extensions, generated resources, Objective-C, Xcode projects) is a function in
  `buildlib/apps.py` registered with `@app("samples/<Dir>", ...)`.
- **A framework** (Objective-C): sources in `isim/frameworks/<Name>`, headers in `isim/sdk-src/Frameworks/<Name>`,
  and a line in `FRAMEWORKS` (`graph.py`).
- **A Swift overlay**: `isim/swift/overlays/<Name>.swift` (or a directory) and a line in `OVERLAYS` (`swift.py`) with
  the modules and frameworks it links.
- **An Objective-C interface for a Swift overlay** (WebKit, StoreKit, AVFoundation…): give the classes Apple's names
  (`@objc(WKWebView)`) and members Apple's selectors, add the old `_TtC…` class symbols to `OBJC_NAMES` (`swift.py`),
  headers in `isim/sdk-src/Frameworks/<Name>` wrapped in `#if !defined(__swift__)`, C constants or categories in
  `isim/frameworks/<Name>`, and a line in `SWIFT_FRAMEWORKS` (`graph.py`): the framework re-exports the overlay.
  Every Swift-implemented framework needs one (AGENTS.md).
- **Its coverage page**: `docs/frameworks/<Name>.md` from `docs/frameworks/_template.md` (how isim implements it, the
  rows), with the module in its area in `isim/data/frameworks.json`. The generated parts of the page are filled in by
  `isim/tools/coverage-summary.py` at the next release.

## Coverage numbers

`isim/tools/api-coverage.py` compares isim's SDK with a snapshot of Apple's documentation
(`isim/data/apple-api/apple-api.json.gz`; [API-SWEEP.md](API-SWEEP.md)):

```bash
isim/tools/api-coverage.py snapshot              # refresh Apple's data (network; after an Apple SDK release)
isim/tools/api-coverage.py measure               # exact, from the built SDK's symbol graphs (the Swift toolchain)
isim/tools/api-coverage.py measure --names       # without a build: by name, a lower bound on what is missing
isim/tools/coverage-summary.py                   # docs/COVERAGE.md and the pages' generated parts
```

The Release workflow runs `measure` and `coverage-summary.py` and commits the results in the release pull request;
pull requests do not, so they don't conflict.

## CI

CI restores `isim/out` from a cache. A checkout gives every file a new modification time, so `build.py ci` first gives
files whose content matches the last cached build their recorded timestamps back (`out/srcstate.json`); Ninja then
rebuilds only what changed. Ninja never deletes an output that left the graph, so `build.py ci` also removes SDK binaries the graph no
longer builds (with their `.swiftmodule` or `.framework`): a cached `out/` cannot carry a removed library into a release
tarball or ABI baseline.

## Claude Code cloud environments

A [Claude Code cloud environment](https://code.claude.com/docs/en/claude-code-on-the-web) (claude.ai/code) can build
and test isim like CI. In the environment's settings (Edit environment):

- **Setup script:** paste [`isim/ci/cloud-setup.sh`](../isim/ci/cloud-setup.sh). It installs CI's packages
  (`isim/ci/Dockerfile`; keep the two in step), clang 22, SDL3 and Swift 6.2.4 from swift.org (`swiftc` on `PATH`).
- **Environment variables:**

  | Variable | Why |
  |---|---|
  | `SDL_AUDIO_DRIVER=dummy` | required: the container has no sound device (CI's image sets it too) |
  | `WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1` | required for the web tests: WebKitGTK's sandbox cannot create namespaces in the container (CI's image sets it too) |
  | `ISIM_TEST_JOBS=4` | optional: test workers, as many as the container's CPUs (the default is half), like CI |
  | `ISIM_WAIT_SCALE=3` | optional, with `ISIM_TEST_JOBS`: longer test waits on a busy machine, like CI |

In a session, run `isim/build.py fetch` once before the first build. Each session builds
`isim/out` from scratch (the first `build.py` takes a while; later builds are incremental). Tests use a scratch
`ISIM_DATA`.
