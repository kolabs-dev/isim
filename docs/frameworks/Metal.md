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
- **Render pipelines** ([#329](https://github.com/kolabs-dev/isim/issues/329)):
  - **Entry points:** the compiler gives each `vertex` function an entry point for one vertex. It binds
    `[[stage_in]]` from the vertex descriptor's attributes (any `MTLVertexFormat`), `[[vertex_id]]`, `[[instance_id]]`,
    the base vertex and instance, and buffers, textures and samplers. It also generates an interpolation of the
    function's output struct (`[[flat]]` members are taken from the provoking vertex).
  - Each `fragment` function gets one entry point for one fragment. It binds `[[stage_in]]` (matched to the vertex
    outputs by `[[user(name)]]`, else by member name), `[[position]]`, `[[front_facing]]`, `[[point_coord]]` and
    `[[color(n)]]` inputs, and it writes `[[color(n)]]` and `[[depth(...)]]` outputs. `discard_fragment()` ends the
    fragment.
  - **Rasterizer:** isim's rasterizer (`isim/frameworks/Metal/MTLRaster.c`) runs a draw in phases:
    1. the vertex function, in parallel;
    2. primitive assembly, then clipping at the near and far planes and a guard band, in clip space;
    3. culling and winding;
    4. 64×64-pixel tiles in parallel, each drawing its primitives in order. Triangles use the top-left rule on a
       1/256-pixel grid with perspective-correct interpolation; lines are 1 pixel wide; points are squares of their
       `[[point_size]]`.
  - Each fragment then goes through the depth and stencil tests (late when the function writes the depth), the
    fragment function, blending (every `MTLBlendFactor` but the dual-source ones, every `MTLBlendOperation`), the write
    mask, and sRGB encoding on `_srgb` targets.
  - Render passes clear and resolve their attachments. A multisample texture holds one sample per pixel, so rendering
    is not antialiased (adapted).
  - Derivatives (`dfdx`, `dfdy`, `fwidth`) are 0, and implicit-LOD sampling in fragment functions uses mip level 0.
  - `CAMetalLayer` and `CAMetalDisplayLink` are QuartzCore's (see [QuartzCore](QuartzCore.md)); `MTKView` and
    `MTKTextureLoader` are MetalKit's (see [MetalKit](MetalKit.md)).
- **Versus a device:** no GPU. `threadExecutionWidth` is 1. The supported families are Apple 1–4 and Common 1–2, the
  compute and render features isim has.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `MTLCreateSystemDefaultDevice()`, `MTLDevice` (name, limits, `supportsFamily`, queues, buffers, textures, samplers, libraries, compute and render pipelines, depth-stencil states, async variants) | 🟡 | ≤17 | adapted: the CPU ("isim CPU"); no heaps, fences, events, argument encoders or indirect command buffers. Tested (MetalObjCTest, MetalRenderObjCTest, HelloMetal, HelloMetalKit) |
| `MTLBuffer` (`contents`, `length`, `makeBuffer(bytes:)`, `makeBuffer(bytesNoCopy:)`, `gpuAddress`, textures from buffers) | ✅ | ≤17 | adapted: process memory in every storage mode. Tested (MetalObjCTest, HelloMetal) |
| `MTLTexture`, `MTLTextureDescriptor` (1D, 2D, arrays, cube, 3D, mip levels, `replace(region:)`, `getBytes`, views) | 🟡 | ≤17 | adapted: linear storage; kernels read and write the 8, 16 and 32-bit color formats, packed 565 and 10-10-10-2; compressed formats are stored but read as zero; multisample textures (`sampleCount` 2 or 4) hold one sample per pixel. Tested (MetalObjCTest, MetalRenderObjCTest, HelloMetal) |
| `MTLSamplerState`, `MTLSamplerDescriptor`; constexpr `sampler` in kernels | ✅ | ≤17 | nearest and bilinear filtering, the address modes, border colors, mip filters, compare functions (`depth2d::sample_compare`); no anisotropy. Tested (MetalObjCTest, MetalRenderObjCTest) |
| `MTLLibrary`, `MTLFunction`, `MTLCompileOptions` (macros), `MTLFunctionConstantValues`, `MTLFunctionConstant`, `MTLLibraryError` | ✅ | ≤17 | adapted: kernels translated to C++ and compiled for the CPU (`tools/mslc.py`); default.metallib from isim build; source compiled at run time. Tested (MetalObjCTest, HelloMetal) |
| `MTLComputePipelineState`, `MTLComputePipelineDescriptor`, `MTLComputeCommandEncoder` (buffers, bytes, textures, samplers, threadgroup memory, `dispatchThreadgroups`, `dispatchThreads` with non-uniform groups, indirect dispatch) | ✅ | ≤17 | adapted: threadgroups on worker threads, fibers at barriers, SIMD width 1; reflection is empty. Tested (MetalObjCTest, HelloMetal) |
| `MTLCommandQueue`, `MTLCommandBuffer` (status, scheduled and completed handlers, `waitUntilCompleted`, timestamps), `MTLBlitCommandEncoder` (copies, fills, `generateMipmaps`) | ✅ | ≤17 | adapted: buffers run in commit order on the queue's background thread; mipmaps box-filtered for 8-bit and float formats. Tested (MetalObjCTest, HelloMetal) |
| Metal Shading Language (types, math, atomics, textures, barriers, SIMD-group functions) | 🟡 | ≤17 | adapted: C++ against isim's `metal_stdlib`; no ray tracing, mesh shaders, argument buffers, `imageblock`s or quad-group functions; `bool` vectors are `char` vectors. Tested (MetalObjCTest) |
| `MTLRenderPipelineState`, `MTLRenderPipelineDescriptor` (vertex and fragment functions, `MTLVertexDescriptor`, color attachments with blending and write masks, depth and stencil formats, `rasterizationEnabled`), `MTLRenderPipelineReflection` | ✅ | ≤17 | adapted: the functions run on the CPU through isim's rasterizer; a fragment input the vertex function does not write is an error at creation, as on a device; reflection is empty; dual-source blending and alpha to coverage are not provided. Tested (MetalRenderObjCTest, HelloMetalKit) |
| `MTLRenderPassDescriptor` (color, depth and stencil attachments, load and store actions, clear values, multisample resolve, `visibilityResultBuffer`) | ✅ | ≤17 | adapted: a multisample attachment holds one sample per pixel; resolving copies it. Tested (MetalRenderObjCTest) |
| `MTLRenderCommandEncoder` (vertex and fragment buffers, bytes, textures and samplers; viewport, scissor, cull mode, winding, fill mode, depth clip mode, depth bias, blend color, depth-stencil state, stencil references, visibility results; `drawPrimitives`, `drawIndexedPrimitives`, instancing, base vertex and instance, indirect draws) | ✅ | ≤17 | adapted: isim's tile rasterizer on the worker threads (points, lines, line strips, triangles, triangle strips); one viewport and scissor rectangle. Tested (MetalRenderObjCTest, HelloMetalKit) |
| `MTLDepthStencilState`, `MTLDepthStencilDescriptor`, `MTLStencilDescriptor` | ✅ | ≤17 | the depth test and write, the stencil test and operations with read and write masks, per face. Tested (MetalRenderObjCTest) |
| Metal Shading Language for rendering: `vertex` / `fragment` functions, `[[stage_in]]`, `[[position]]`, `[[flat]]`, `[[user(name)]]`, `[[point_size]]`, `[[color(n)]]`, `[[depth(...)]]`, `[[front_facing]]`, `[[point_coord]]`, `discard_fragment`, `depth2d` (`sample_compare`), `texturecube`, `texture2d_ms` | 🟡 | ≤17 | adapted: one fragment at a time, so `dfdx` / `dfdy` / `fwidth` are 0 and implicit-LOD sampling uses mip level 0; no tessellation, amplification, raster order groups or programmable blending beyond `[[color(n)]]` inputs. Tested (MetalRenderObjCTest, HelloMetalKit) |
| `MTLDrawable`, `presentDrawable` | ✅ | ≤17 | presented when the command buffer completes (its rendering is done). Tested (HelloMetalKit) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
