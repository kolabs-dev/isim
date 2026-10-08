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

## Adding things

- **A sample**: a directory in `isim/samples` with Swift files and an `Info.plist` builds as `<Dir>.app` with no
  build code. Anything else (extensions, generated resources, Objective-C, Xcode projects) is a function in
  `buildlib/apps.py` registered with `@app("samples/<Dir>", ...)`.
- **A framework** (Objective-C): sources in `isim/frameworks/<Name>`, headers in `isim/sdk-src/Frameworks/<Name>`,
  and a line in `FRAMEWORKS` (`graph.py`).
- **A Swift overlay**: `isim/swift/overlays/<Name>.swift` (or a directory) and a line in `OVERLAYS` (`swift.py`) with
  the modules and frameworks it links.

## CI

CI restores `isim/out` from a cache. A checkout gives every file a new modification time, so `build.py ci` first gives
files whose content matches the last cached build their recorded timestamps back (`out/srcstate.json`); Ninja then
rebuilds only what changed.
