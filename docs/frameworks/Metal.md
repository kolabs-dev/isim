# Metal

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 0.0% of Apple's iOS API (0 of 3742, approximate, by name) · **Rows:** 1: 1 ❌ · **iOS:** 8.0+
<!-- /generated:header -->

**Area:** [GPU](../COVERAGE.md#gpu) · **Apple:** [Metal](https://developer.apple.com/documentation/metal) · **Issues:** [`area:gpu`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agpu)

## How isim implements it

- **Adapted: Metal on the CPU** ([#328](https://github.com/kolabs-dev/isim/issues/328)). `MTLCreateSystemDefaultDevice()` returns
  an `MTLDevice` named "isim CPU". Its resources are memory of the process, in every storage mode, and compute work runs
  on the CPU (`isim/frameworks/Metal`, Objective-C with Apple's headers in `isim/sdk-src/Frameworks/Metal`; Apple's
  Swift forms with arrays and ranges in `isim/swift/overlays/Metal`).
- **Kernels:** Metal Shading Language is translated to C++ by isim's compiler (`isim/tools/mslc.py`).
  - The C++ uses isim's `metal_stdlib` (`isim/sdk-src/metal/include/__isim_metal.h`):
    - vectors as clang ext_vector types, so swizzles work, and matrices as classes;
    - the math, geometric, integer, relational and packing functions;
    - atomics, including `atomic_float`;
    - `texture1d` / `texture2d` / `texture2d_array` / `texture3d` / `texture_buffer`, with read, write and sample
      (nearest and bilinear filtering, the address modes, mip levels) for the 8, 16 and 32-bit color formats;
    - constexpr samplers, `threadgroup_barrier`, and the SIMD-group functions (SIMD groups of one thread).
  - Each kernel gets an entry point that binds its `[[buffer(n)]]`, `[[texture(n)]]`, `[[sampler(n)]]` and
    `[[threadgroup(n)]]` arguments and the thread-position attributes; `[[function_constant(n)]]` declarations take
    the values of `MTLFunctionConstantValues`.
  - clang builds the C++ into a guest dylib (`isim cc`).
  - `isim build` compiles an app's `.metal` files into `default.metallib.dylib`, next to `default.metallib`, which
    stays isim's text format and holds the sources Core Image reads. `isim metal-compile` runs the same compiler.
  - `makeLibrary(source:options:)` (and a `default.metallib` without its dylib) compiles at run time through the host
    (`runtime/host_metal.c`) into the app's Caches folder. When the host has no clang, that is a compile error
    (`MTLLibraryError.compileFailure`). Apple-built metallibs (GPU code) cannot run (`MTLLibraryError.unsupported`).
- **Dispatches** run on a pool of worker threads, one per CPU (up to 16) (`MTLDispatch.c`). Each worker runs one
  threadgroup at a time, so threadgroup memory is the worker's. The threads of a group run one after another; a kernel
  that calls `threadgroup_barrier` runs them as fibers that switch at each barrier. Command buffers run in commit order
  on their queue's background thread, then call their completed handlers.
- **Versus a device:** no GPU. `threadExecutionWidth` is 1. The supported families are Apple 1–4 and Common 1–2, the
  compute features isim has. Render pipelines, `MTKView` and `CAMetalLayer` come with
  [#329](https://github.com/kolabs-dev/isim/issues/329).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `MTLCreateSystemDefaultDevice()`, `MTLDevice` (name, limits, `supportsFamily`, queues, buffers, textures, samplers, libraries, compute pipelines, async variants) | 🟡 | ≤17 | adapted: the CPU ("isim CPU"); no heaps, fences, events, argument encoders, indirect command buffers or render pipelines (#329). Tested (MetalObjCTest, HelloMetal) |
| `MTLBuffer` (`contents`, `length`, `makeBuffer(bytes:)`, `makeBuffer(bytesNoCopy:)`, `gpuAddress`, textures from buffers) | ✅ | ≤17 | adapted: process memory in every storage mode. Tested (MetalObjCTest, HelloMetal) |
| `MTLTexture`, `MTLTextureDescriptor` (1D, 2D, arrays, cube, 3D, mip levels, `replace(region:)`, `getBytes`, views) | 🟡 | ≤17 | adapted: linear storage; kernels read and write the 8, 16 and 32-bit color formats, packed 565 and 10-10-10-2; compressed formats are stored but read as zero; no multisampling. Tested (MetalObjCTest, HelloMetal) |
| `MTLSamplerState`, `MTLSamplerDescriptor`; constexpr `sampler` in kernels | ✅ | ≤17 | nearest and bilinear filtering, the address modes, border colors, mip filters; no anisotropy or compare functions. Tested (MetalObjCTest) |
| `MTLLibrary`, `MTLFunction`, `MTLCompileOptions` (macros), `MTLFunctionConstantValues`, `MTLFunctionConstant`, `MTLLibraryError` | ✅ | ≤17 | adapted: kernels translated to C++ and compiled for the CPU (`tools/mslc.py`); default.metallib from isim build; source compiled at run time. Tested (MetalObjCTest, HelloMetal) |
| `MTLComputePipelineState`, `MTLComputePipelineDescriptor`, `MTLComputeCommandEncoder` (buffers, bytes, textures, samplers, threadgroup memory, `dispatchThreadgroups`, `dispatchThreads` with non-uniform groups, indirect dispatch) | ✅ | ≤17 | adapted: threadgroups on worker threads, fibers at barriers, SIMD width 1; reflection is empty. Tested (MetalObjCTest, HelloMetal) |
| `MTLCommandQueue`, `MTLCommandBuffer` (status, scheduled and completed handlers, `waitUntilCompleted`, timestamps), `MTLBlitCommandEncoder` (copies, fills, `generateMipmaps`) | ✅ | ≤17 | adapted: buffers run in commit order on the queue's background thread; mipmaps box-filtered for 8-bit and float formats. Tested (MetalObjCTest, HelloMetal) |
| Metal Shading Language (types, math, atomics, textures, barriers, SIMD-group functions) | 🟡 | ≤17 | adapted: C++ against isim's `metal_stdlib`; no ray tracing, mesh shaders, argument buffers, `imageblock`s or quad-group functions; `bool` vectors are `char` vectors. Tested (MetalObjCTest) |
| Render pipelines, `MTLRenderCommandEncoder`, drawables, MetalKit, `CAMetalLayer` | ❌ | ≤17 | [#329](https://github.com/kolabs-dev/isim/issues/329) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
