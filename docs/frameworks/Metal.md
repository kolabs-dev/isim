# Metal

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 0.0% of Apple's iOS API (0 of 3742, approximate, by name) · **Rows:** 1: 1 ❌ · **iOS:** 8.0+
<!-- /generated:header -->

**Area:** [GPU](../COVERAGE.md#gpu) · **Apple:** [Metal](https://developer.apple.com/documentation/metal) · **Issues:** [`area:gpu`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agpu)

## How isim implements it

- Not in isim.
- Planned:
  - a CPU path: MSL compiled as C++ against a `metal_stdlib` shim;
  - a Vulkan path: SPIR-V, with Mesa lavapipe in CI.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Metal, MetalKit (`MTLDevice`, `MTKView`) | ❌ | ≤17 | no GPU API |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
