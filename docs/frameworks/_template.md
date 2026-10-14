# <Module>

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [<Area name>](../COVERAGE.md#<area key>) · **Apple:** [<Module>](https://developer.apple.com/documentation/<module>) · **Issues:** [`area:<area key>`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3A<area key>)

## How isim implements it

- **Approach:** passthrough to which host library, or isim's own engine (the files), or a stub; what is simulated
  (`ISIM_*` variables in SYSTEM-PROMPTS.md, script commands in SCRIPTING.md).
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/<Module>`, or "Swift only".
- **Versus Apple's Simulator:** what matches, what differs.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `SomeAPI` (members…) | ✅ | ≤17 | adapted: …; tested (HelloSomething, test_something) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
