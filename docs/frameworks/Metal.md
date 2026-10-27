# Metal

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 33.8% of Apple's iOS API (1280 of 3786, exact) · **Rows:** 14: 10 ✅ 4 🟡 · **iOS:** 8.0+
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
| `MTLCreateSystemDefaultDevice()`, `MTLDevice` (name, limits, `supportsFamily`, queues, buffers, textures, samplers, libraries, compute and render pipelines, depth-stencil states, async variants) | 🟡 | ≤17 | adapted: the CPU ("isim CPU"); `newFence` returns a fence with nothing to wait for (a queue's buffers run in order; issue #365); no heaps, events, argument encoders or indirect command buffers. Tested (MetalObjCTest, MetalRenderObjCTest, HelloMetal, HelloMetalKit) |
| `MTLBuffer` (`contents`, `length`, `makeBuffer(bytes:)`, `makeBuffer(bytesNoCopy:)`, `gpuAddress`, textures from buffers) | ✅ | ≤17 | adapted: process memory in every storage mode. Tested (MetalObjCTest, HelloMetal) |
| `MTLTexture`, `MTLTextureDescriptor` (1D, 2D, arrays, cube, 3D, mip levels, `replace(region:)`, `getBytes`, views) | 🟡 | ≤17 | adapted: linear storage; views of a format, or of some levels and slices, share the parent's memory (issue #365, tested by MPSTest's sub-images); kernels read and write the 8, 16 and 32-bit color formats, packed 565 and 10-10-10-2; compressed formats are stored but read as zero; multisample textures (`sampleCount` 2 or 4) hold one sample per pixel. Tested (MetalObjCTest, MetalRenderObjCTest, HelloMetal) |
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
2506 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`MTL4AccelerationStructureBoundingBoxGeometryDescriptor`](https://developer.apple.com/documentation/metal/mtl4accelerationstructureboundingboxgeometrydescriptor)
- [`var boundingBoxBuffer: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructureboundingboxgeometrydescriptor/boundingboxbuffer)
- [`var boundingBoxCount: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructureboundingboxgeometrydescriptor/boundingboxcount)
- [`var boundingBoxStride: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructureboundingboxgeometrydescriptor/boundingboxstride)
- [`MTL4AccelerationStructureCurveGeometryDescriptor`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor)
- [`var controlPointBuffer: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/controlpointbuffer)
- [`var controlPointCount: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/controlpointcount)
- [`var controlPointFormat: MTLAttributeFormat`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/controlpointformat)
- [`var controlPointStride: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/controlpointstride)
- [`var curveBasis: MTLCurveBasis`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/curvebasis)
- [`var curveEndCaps: MTLCurveEndCaps`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/curveendcaps)
- [`var curveType: MTLCurveType`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/curvetype)
- [`var indexBuffer: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/indexbuffer)
- [`var indexType: MTLIndexType`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/indextype)
- [`var radiusBuffer: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/radiusbuffer)
- [`var radiusFormat: MTLAttributeFormat`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/radiusformat)
- [`var radiusStride: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/radiusstride)
- [`var segmentControlPointCount: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/segmentcontrolpointcount)
- [`var segmentCount: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructurecurvegeometrydescriptor/segmentcount)
- [`MTL4AccelerationStructureDescriptor`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuredescriptor)
- [`MTL4AccelerationStructureGeometryDescriptor`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuregeometrydescriptor)
- [`var allowDuplicateIntersectionFunctionInvocation: Bool`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuregeometrydescriptor/allowduplicateintersectionfunctioninvocation)
- [`var intersectionFunctionTableOffset: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuregeometrydescriptor/intersectionfunctiontableoffset)
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuregeometrydescriptor/label)
- [`var opaque: Bool`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuregeometrydescriptor/opaque)
- [`var primitiveDataBuffer: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuregeometrydescriptor/primitivedatabuffer)
- [`var primitiveDataElementSize: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuregeometrydescriptor/primitivedataelementsize)
- [`var primitiveDataStride: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuregeometrydescriptor/primitivedatastride)
- [`MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotionboundingboxgeometrydescriptor)
- [`var boundingBoxBuffers: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotionboundingboxgeometrydescriptor/boundingboxbuffers)
- [`var boundingBoxCount: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotionboundingboxgeometrydescriptor/boundingboxcount)
- [`var boundingBoxStride: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotionboundingboxgeometrydescriptor/boundingboxstride)
- [`MTL4AccelerationStructureMotionCurveGeometryDescriptor`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor)
- [`var controlPointBuffers: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/controlpointbuffers)
- [`var controlPointCount: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/controlpointcount)
- [`var controlPointFormat: MTLAttributeFormat`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/controlpointformat)
- [`var controlPointStride: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/controlpointstride)
- [`var curveBasis: MTLCurveBasis`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/curvebasis)
- [`var curveEndCaps: MTLCurveEndCaps`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/curveendcaps)
- [`var curveType: MTLCurveType`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/curvetype)
- [`var indexBuffer: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/indexbuffer)
- [`var indexType: MTLIndexType`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/indextype)
- [`var radiusBuffers: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/radiusbuffers)
- [`var radiusFormat: MTLAttributeFormat`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/radiusformat)
- [`var radiusStride: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/radiusstride)
- [`var segmentControlPointCount: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/segmentcontrolpointcount)
- [`var segmentCount: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotioncurvegeometrydescriptor/segmentcount)
- [`MTL4AccelerationStructureMotionTriangleGeometryDescriptor`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotiontrianglegeometrydescriptor)
- [`var indexBuffer: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotiontrianglegeometrydescriptor/indexbuffer)
- [`var indexType: MTLIndexType`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotiontrianglegeometrydescriptor/indextype)
- [`var transformationMatrixBuffer: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotiontrianglegeometrydescriptor/transformationmatrixbuffer)
- [`var transformationMatrixLayout: MTLMatrixLayout`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotiontrianglegeometrydescriptor/transformationmatrixlayout)
- [`var triangleCount: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotiontrianglegeometrydescriptor/trianglecount)
- [`var vertexBuffers: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotiontrianglegeometrydescriptor/vertexbuffers)
- [`var vertexFormat: MTLAttributeFormat`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotiontrianglegeometrydescriptor/vertexformat)
- [`var vertexStride: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuremotiontrianglegeometrydescriptor/vertexstride)
- [`MTL4AccelerationStructureTriangleGeometryDescriptor`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuretrianglegeometrydescriptor)
- [`var indexBuffer: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuretrianglegeometrydescriptor/indexbuffer)
- [`var indexType: MTLIndexType`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuretrianglegeometrydescriptor/indextype)
- [`var transformationMatrixBuffer: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuretrianglegeometrydescriptor/transformationmatrixbuffer)
- [`var transformationMatrixLayout: MTLMatrixLayout`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuretrianglegeometrydescriptor/transformationmatrixlayout)
- [`var triangleCount: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuretrianglegeometrydescriptor/trianglecount)
- [`var vertexBuffer: MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuretrianglegeometrydescriptor/vertexbuffer)
- [`var vertexFormat: MTLAttributeFormat`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuretrianglegeometrydescriptor/vertexformat)
- [`var vertexStride: Int`](https://developer.apple.com/documentation/metal/mtl4accelerationstructuretrianglegeometrydescriptor/vertexstride)
- [`MTL4AlphaToCoverageState`](https://developer.apple.com/documentation/metal/mtl4alphatocoveragestate)
- [`case disabled`](https://developer.apple.com/documentation/metal/mtl4alphatocoveragestate/disabled)
- [`case enabled`](https://developer.apple.com/documentation/metal/mtl4alphatocoveragestate/enabled)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/metal/mtl4alphatocoveragestate/init(rawvalue:))
- [`MTL4AlphaToOneState`](https://developer.apple.com/documentation/metal/mtl4alphatoonestate)
- [`case disabled`](https://developer.apple.com/documentation/metal/mtl4alphatoonestate/disabled)
- [`case enabled`](https://developer.apple.com/documentation/metal/mtl4alphatoonestate/enabled)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/metal/mtl4alphatoonestate/init(rawvalue:))
- [`MTL4Archive`](https://developer.apple.com/documentation/metal/mtl4archive)
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4archive/label)
- [`func makeBinaryFunction(descriptor: MTL4BinaryFunctionDescriptor) throws -> any MTL4BinaryFunction`](https://developer.apple.com/documentation/metal/mtl4archive/makebinaryfunction(descriptor:))
- [`func makeComputePipelineState(descriptor: MTL4ComputePipelineDescriptor, dynamicLinkingDescriptor: MTL4PipelineStageDynamicLinkingDescriptor?) throws -> any MTLComputePipelineState`](https://developer.apple.com/documentation/metal/mtl4archive/makecomputepipelinestate(descriptor:dynamiclinkingdescriptor:))
- [`func makeRenderPipelineState(descriptor: MTL4PipelineDescriptor, dynamicLinkingDescriptor: MTL4RenderPipelineDynamicLinkingDescriptor?) throws -> any MTLRenderPipelineState`](https://developer.apple.com/documentation/metal/mtl4archive/makerenderpipelinestate(descriptor:dynamiclinkingdescriptor:))
- [`MTL4ArgumentTable`](https://developer.apple.com/documentation/metal/mtl4argumenttable)
- [`var device: any MTLDevice`](https://developer.apple.com/documentation/metal/mtl4argumenttable/device)
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4argumenttable/label)
- [`func setAddress(MTLGPUAddress, attributeStride: Int, index: Int)`](https://developer.apple.com/documentation/metal/mtl4argumenttable/setaddress(_:attributestride:index:))
- [`func setAddress(MTLGPUAddress, index: Int)`](https://developer.apple.com/documentation/metal/mtl4argumenttable/setaddress(_:index:))
- [`func setResource(MTLResourceID, bufferIndex: Int)`](https://developer.apple.com/documentation/metal/mtl4argumenttable/setresource(_:bufferindex:))
- [`func setSamplerState(MTLResourceID, index: Int)`](https://developer.apple.com/documentation/metal/mtl4argumenttable/setsamplerstate(_:index:))
- [`func setTexture(MTLResourceID, index: Int)`](https://developer.apple.com/documentation/metal/mtl4argumenttable/settexture(_:index:))
- [`MTL4ArgumentTableDescriptor`](https://developer.apple.com/documentation/metal/mtl4argumenttabledescriptor)
- [`var initializeBindings: Bool`](https://developer.apple.com/documentation/metal/mtl4argumenttabledescriptor/initializebindings)
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4argumenttabledescriptor/label)
- [`var maxBufferBindCount: Int`](https://developer.apple.com/documentation/metal/mtl4argumenttabledescriptor/maxbufferbindcount)
- [`var maxSamplerStateBindCount: Int`](https://developer.apple.com/documentation/metal/mtl4argumenttabledescriptor/maxsamplerstatebindcount)
- [`var maxTextureBindCount: Int`](https://developer.apple.com/documentation/metal/mtl4argumenttabledescriptor/maxtexturebindcount)
- [`var supportAttributeStrides: Bool`](https://developer.apple.com/documentation/metal/mtl4argumenttabledescriptor/supportattributestrides)
- [`MTL4BinaryFunction`](https://developer.apple.com/documentation/metal/mtl4binaryfunction)
- [`var functionType: MTLFunctionType`](https://developer.apple.com/documentation/metal/mtl4binaryfunction/functiontype)
- [`var name: String?`](https://developer.apple.com/documentation/metal/mtl4binaryfunction/name)
- [`MTL4BinaryFunctionDescriptor`](https://developer.apple.com/documentation/metal/mtl4binaryfunctiondescriptor)
- [`var functionDescriptor: MTL4FunctionDescriptor`](https://developer.apple.com/documentation/metal/mtl4binaryfunctiondescriptor/functiondescriptor)
- [`var name: String`](https://developer.apple.com/documentation/metal/mtl4binaryfunctiondescriptor/name)
- [`var options: MTL4BinaryFunctionOptions`](https://developer.apple.com/documentation/metal/mtl4binaryfunctiondescriptor/options)
- [`MTL4BinaryFunctionOptions`](https://developer.apple.com/documentation/metal/mtl4binaryfunctionoptions)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/metal/mtl4binaryfunctionoptions/init(rawvalue:))
- [`static var pipelineIndependent: MTL4BinaryFunctionOptions`](https://developer.apple.com/documentation/metal/mtl4binaryfunctionoptions/pipelineindependent)
- [`MTL4BlendState`](https://developer.apple.com/documentation/metal/mtl4blendstate)
- [`case disabled`](https://developer.apple.com/documentation/metal/mtl4blendstate/disabled)
- [`case enabled`](https://developer.apple.com/documentation/metal/mtl4blendstate/enabled)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/metal/mtl4blendstate/init(rawvalue:))
- [`case unspecialized`](https://developer.apple.com/documentation/metal/mtl4blendstate/unspecialized)
- [`MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4bufferrange)
- [`var bufferAddress: MTLGPUAddress`](https://developer.apple.com/documentation/metal/mtl4bufferrange/bufferaddress)
- [`init()`](https://developer.apple.com/documentation/metal/mtl4bufferrange/init())
- [`init(bufferAddress: MTLGPUAddress, length: UInt64)`](https://developer.apple.com/documentation/metal/mtl4bufferrange/init(bufferaddress:length:))
- [`var length: UInt64`](https://developer.apple.com/documentation/metal/mtl4bufferrange/length)
- [`func MTL4BufferRangeMake(MTLGPUAddress, UInt64) -> MTL4BufferRange`](https://developer.apple.com/documentation/metal/mtl4bufferrangemake(_:_:))
- [`MTL4CommandAllocator`](https://developer.apple.com/documentation/metal/mtl4commandallocator)
- [`func allocatedSize() -> UInt64`](https://developer.apple.com/documentation/metal/mtl4commandallocator/allocatedsize())
- [`var device: any MTLDevice`](https://developer.apple.com/documentation/metal/mtl4commandallocator/device)
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4commandallocator/label)
- [`func reset()`](https://developer.apple.com/documentation/metal/mtl4commandallocator/reset())
- [`MTL4CommandAllocatorDescriptor`](https://developer.apple.com/documentation/metal/mtl4commandallocatordescriptor)
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4commandallocatordescriptor/label)
- [`MTL4CommandBuffer`](https://developer.apple.com/documentation/metal/mtl4commandbuffer)
- [`func beginCommandBuffer(allocator: any MTL4CommandAllocator)`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/begincommandbuffer(allocator:))
- [`func beginCommandBuffer(allocator: any MTL4CommandAllocator, options: MTL4CommandBufferOptions)`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/begincommandbuffer(allocator:options:))
- [`var device: any MTLDevice`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/device)
- [`func endCommandBuffer()`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/endcommandbuffer())
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/label)
- [`func makeComputeCommandEncoder() -> (any MTL4ComputeCommandEncoder)?`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/makecomputecommandencoder())
- [`func makeMachineLearningCommandEncoder() -> (any MTL4MachineLearningCommandEncoder)?`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/makemachinelearningcommandencoder())
- [`func makeRenderCommandEncoder(descriptor: MTL4RenderPassDescriptor, options: MTL4RenderEncoderOptions) -> (any MTL4RenderCommandEncoder)?`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/makerendercommandencoder(descriptor:options:))
- [`func popDebugGroup()`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/popdebuggroup())
- [`func pushDebugGroup(String)`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/pushdebuggroup(_:))
- [`func resolveCounterHeap(any MTL4CounterHeap, range: Range<Int>, buffer: MTL4BufferRange, fenceToWait: (any MTLFence)?, fenceToUpdate: (any MTLFence)?)`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/resolvecounterheap(_:range:buffer:fencetowait:fencetoupdate:))
- [`func useResidencySet(any MTLResidencySet)`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/useresidencyset(_:))
- [`func useResidencySets([any MTLResidencySet])`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/useresidencysets(_:))
- [`func writeTimestamp(counterHeap: any MTL4CounterHeap, index: Int)`](https://developer.apple.com/documentation/metal/mtl4commandbuffer/writetimestamp(counterheap:index:))
- [`MTL4CommandBufferOptions`](https://developer.apple.com/documentation/metal/mtl4commandbufferoptions)
- [`var logState: (any MTLLogState)?`](https://developer.apple.com/documentation/metal/mtl4commandbufferoptions/logstate)
- [`MTL4CommandEncoder`](https://developer.apple.com/documentation/metal/mtl4commandencoder)
- [`func barrier(afterEncoderStages: MTLStages, beforeEncoderStages: MTLStages, visibilityOptions: MTL4VisibilityOptions)`](https://developer.apple.com/documentation/metal/mtl4commandencoder/barrier(afterencoderstages:beforeencoderstages:visibilityoptions:))
- [`func barrier(afterQueueStages: MTLStages, beforeStages: MTLStages, visibilityOptions: MTL4VisibilityOptions)`](https://developer.apple.com/documentation/metal/mtl4commandencoder/barrier(afterqueuestages:beforestages:visibilityoptions:))
- [`func barrier(afterStages: MTLStages, beforeQueueStages: MTLStages, visibilityOptions: MTL4VisibilityOptions)`](https://developer.apple.com/documentation/metal/mtl4commandencoder/barrier(afterstages:beforequeuestages:visibilityoptions:))
- [`var commandBuffer: (any MTL4CommandBuffer)?`](https://developer.apple.com/documentation/metal/mtl4commandencoder/commandbuffer)
- [`func endEncoding()`](https://developer.apple.com/documentation/metal/mtl4commandencoder/endencoding())
- [`func insertDebugSignpost(String)`](https://developer.apple.com/documentation/metal/mtl4commandencoder/insertdebugsignpost(_:))
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4commandencoder/label)
- [`func popDebugGroup()`](https://developer.apple.com/documentation/metal/mtl4commandencoder/popdebuggroup())
- [`func pushDebugGroup(String)`](https://developer.apple.com/documentation/metal/mtl4commandencoder/pushdebuggroup(_:))
- [`func updateFence(any MTLFence, afterEncoderStages: MTLStages)`](https://developer.apple.com/documentation/metal/mtl4commandencoder/updatefence(_:afterencoderstages:))
- [`func waitForFence(any MTLFence, beforeEncoderStages: MTLStages)`](https://developer.apple.com/documentation/metal/mtl4commandencoder/waitforfence(_:beforeencoderstages:))
- [`MTL4CommandQueue`](https://developer.apple.com/documentation/metal/mtl4commandqueue)
- [`func addResidencySet(any MTLResidencySet)`](https://developer.apple.com/documentation/metal/mtl4commandqueue/addresidencyset(_:))
- [`func addResidencySets([any MTLResidencySet])`](https://developer.apple.com/documentation/metal/mtl4commandqueue/addresidencysets(_:))
- [`func commit([any MTL4CommandBuffer], options: MTL4CommitOptions?)`](https://developer.apple.com/documentation/metal/mtl4commandqueue/commit(_:options:))
- [`func copyMappings(sourceBuffer: any MTLBuffer, destinationBuffer: any MTLBuffer, operations: [MTL4CopySparseBufferMappingOperation])`](https://developer.apple.com/documentation/metal/mtl4commandqueue/copymappings(sourcebuffer:destinationbuffer:operations:))
- [`func copyMappings(sourceTexture: any MTLTexture, destinationTexture: any MTLTexture, operations: [MTL4CopySparseTextureMappingOperation])`](https://developer.apple.com/documentation/metal/mtl4commandqueue/copymappings(sourcetexture:destinationtexture:operations:))
- [`var device: any MTLDevice`](https://developer.apple.com/documentation/metal/mtl4commandqueue/device)
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4commandqueue/label)
- [`func removeResidencySet(any MTLResidencySet)`](https://developer.apple.com/documentation/metal/mtl4commandqueue/removeresidencyset(_:))
- [`func removeResidencySets([any MTLResidencySet])`](https://developer.apple.com/documentation/metal/mtl4commandqueue/removeresidencysets(_:))
- [`func signalDrawable(any MTLDrawable)`](https://developer.apple.com/documentation/metal/mtl4commandqueue/signaldrawable(_:))
- [`func signalEvent(any MTLEvent, value: UInt64)`](https://developer.apple.com/documentation/metal/mtl4commandqueue/signalevent(_:value:))
- [`func updateMappings(buffer: any MTLBuffer, heap: (any MTLHeap)?, operations: [MTL4UpdateSparseBufferMappingOperation])`](https://developer.apple.com/documentation/metal/mtl4commandqueue/updatemappings(buffer:heap:operations:))
- [`func updateMappings(texture: any MTLTexture, heap: (any MTLHeap)?, operations: [MTL4UpdateSparseTextureMappingOperation])`](https://developer.apple.com/documentation/metal/mtl4commandqueue/updatemappings(texture:heap:operations:))
- [`func waitForDrawable(any MTLDrawable)`](https://developer.apple.com/documentation/metal/mtl4commandqueue/waitfordrawable(_:))
- [`func waitForEvent(any MTLEvent, value: UInt64)`](https://developer.apple.com/documentation/metal/mtl4commandqueue/waitforevent(_:value:))
- [`MTL4CommandQueueDescriptor`](https://developer.apple.com/documentation/metal/mtl4commandqueuedescriptor)
- [`var feedbackQueue: dispatch_queue_t?`](https://developer.apple.com/documentation/metal/mtl4commandqueuedescriptor/feedbackqueue)
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4commandqueuedescriptor/label)
- [`MTL4CommandQueueError`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct)
- [`static var accessRevoked: MTL4CommandQueueError.Code`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/accessrevoked)
- [`MTL4CommandQueueError.Code`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/code)
- [`case accessRevoked`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/code/accessrevoked)
- [`case deviceRemoved`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/code/deviceremoved)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/code/init(rawvalue:))
- [`case `internal``](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/code/internal)
- [`case none`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/code/none)
- [`case notPermitted`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/code/notpermitted)
- [`case outOfMemory`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/code/outofmemory)
- [`case timeout`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/code/timeout)
- [`static var deviceRemoved: MTL4CommandQueueError.Code`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/deviceremoved)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/errordomain)
- [`static var `internal`: MTL4CommandQueueError.Code`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/internal)
- [`static var none: MTL4CommandQueueError.Code`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/none)
- [`static var notPermitted: MTL4CommandQueueError.Code`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/notpermitted)
- [`static var outOfMemory: MTL4CommandQueueError.Code`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/outofmemory)
- [`static var timeout: MTL4CommandQueueError.Code`](https://developer.apple.com/documentation/metal/mtl4commandqueueerror-swift.struct/timeout)
- [`let MTL4CommandQueueErrorDomain: String`](https://developer.apple.com/documentation/metal/mtl4commandqueueerrordomain)
- [`MTL4CommitFeedback`](https://developer.apple.com/documentation/metal/mtl4commitfeedback)
- [`var error: (any Error)?`](https://developer.apple.com/documentation/metal/mtl4commitfeedback/error)
- [`var gpuEndTime: CFTimeInterval`](https://developer.apple.com/documentation/metal/mtl4commitfeedback/gpuendtime)
- [`var gpuStartTime: CFTimeInterval`](https://developer.apple.com/documentation/metal/mtl4commitfeedback/gpustarttime)
- [`MTL4CommitFeedbackHandler`](https://developer.apple.com/documentation/metal/mtl4commitfeedbackhandler)
- [`MTL4CommitOptions`](https://developer.apple.com/documentation/metal/mtl4commitoptions)
- [`func addFeedbackHandler(MTL4CommitFeedbackHandler)`](https://developer.apple.com/documentation/metal/mtl4commitoptions/addfeedbackhandler(_:))
- [`MTL4Compiler`](https://developer.apple.com/documentation/metal/mtl4compiler)
- [`var device: any MTLDevice`](https://developer.apple.com/documentation/metal/mtl4compiler/device)
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4compiler/label)
- [`func makeBinaryFunction(descriptor: MTL4BinaryFunctionDescriptor, compilerTaskOptions: MTL4CompilerTaskOptions?) throws -> any MTL4BinaryFunction`](https://developer.apple.com/documentation/metal/mtl4compiler/makebinaryfunction(descriptor:compilertaskoptions:)-5o46e)
- [`func makeBinaryFunction(descriptor: MTL4BinaryFunctionDescriptor, compilerTaskOptions: MTL4CompilerTaskOptions?) async throws -> any MTL4BinaryFunction`](https://developer.apple.com/documentation/metal/mtl4compiler/makebinaryfunction(descriptor:compilertaskoptions:)-hkc4)
- [`func makeComputePipelineState(descriptor: MTL4ComputePipelineDescriptor, dynamicLinkingDescriptor: MTL4PipelineStageDynamicLinkingDescriptor?, compilerTaskOptions: MTL4CompilerTaskOptions?) async throws -> any MTLComputePipelineState`](https://developer.apple.com/documentation/metal/mtl4compiler/makecomputepipelinestate(descriptor:dynamiclinkingdescriptor:compilertaskoptions:)-19x)
- [`func makeComputePipelineState(descriptor: MTL4ComputePipelineDescriptor, dynamicLinkingDescriptor: MTL4PipelineStageDynamicLinkingDescriptor?, compilerTaskOptions: MTL4CompilerTaskOptions?) throws -> any MTLComputePipelineState`](https://developer.apple.com/documentation/metal/mtl4compiler/makecomputepipelinestate(descriptor:dynamiclinkingdescriptor:compilertaskoptions:)-7dqdm)
- [`func makeDynamicLibrary(library: any MTLLibrary) throws -> any MTLDynamicLibrary`](https://developer.apple.com/documentation/metal/mtl4compiler/makedynamiclibrary(library:))
- [`func makeDynamicLibrary(library: any MTLLibrary) async throws -> any MTLDynamicLibrary`](https://developer.apple.com/documentation/metal/mtl4compiler/makedynamiclibrary(library:)-7f4yz)
- [`func makeDynamicLibrary(url: URL) throws -> any MTLDynamicLibrary`](https://developer.apple.com/documentation/metal/mtl4compiler/makedynamiclibrary(url:))
- [`func makeDynamicLibrary(url: URL) async throws -> any MTLDynamicLibrary`](https://developer.apple.com/documentation/metal/mtl4compiler/makedynamiclibrary(url:)-18tis)
- [`func makeLibrary(descriptor: MTL4LibraryDescriptor) throws -> any MTLLibrary`](https://developer.apple.com/documentation/metal/mtl4compiler/makelibrary(descriptor:))
- [`func makeLibrary(descriptor: MTL4LibraryDescriptor) async throws -> any MTLLibrary`](https://developer.apple.com/documentation/metal/mtl4compiler/makelibrary(descriptor:)-6c46o)
- [`func makeMachineLearningPipelineState(descriptor: MTL4MachineLearningPipelineDescriptor) async throws -> any MTL4MachineLearningPipelineState`](https://developer.apple.com/documentation/metal/mtl4compiler/makemachinelearningpipelinestate(descriptor:)-36hxx)
- [`func makeMachineLearningPipelineState(descriptor: MTL4MachineLearningPipelineDescriptor) throws -> any MTL4MachineLearningPipelineState`](https://developer.apple.com/documentation/metal/mtl4compiler/makemachinelearningpipelinestate(descriptor:)-909v1)
- [`func makeRenderPipelineState(descriptor: MTL4PipelineDescriptor, dynamicLinkingDescriptor: MTL4RenderPipelineDynamicLinkingDescriptor?, compilerTaskOptions: MTL4CompilerTaskOptions?) async throws -> any MTLRenderPipelineState`](https://developer.apple.com/documentation/metal/mtl4compiler/makerenderpipelinestate(descriptor:dynamiclinkingdescriptor:compilertaskoptions:)-66wsk)
- [`func makeRenderPipelineState(descriptor: MTL4PipelineDescriptor, dynamicLinkingDescriptor: MTL4RenderPipelineDynamicLinkingDescriptor?, compilerTaskOptions: MTL4CompilerTaskOptions?) throws -> any MTLRenderPipelineState`](https://developer.apple.com/documentation/metal/mtl4compiler/makerenderpipelinestate(descriptor:dynamiclinkingdescriptor:compilertaskoptions:)-84kox)
- [`func makeRenderPipelineStateBySpecialization(descriptor: MTL4PipelineDescriptor, pipeline: any MTLRenderPipelineState) throws -> any MTLRenderPipelineState`](https://developer.apple.com/documentation/metal/mtl4compiler/makerenderpipelinestatebyspecialization(descriptor:pipeline:)-2636j)
- [`func makeRenderPipelineStateBySpecialization(descriptor: MTL4PipelineDescriptor, pipeline: any MTLRenderPipelineState) async throws -> any MTLRenderPipelineState`](https://developer.apple.com/documentation/metal/mtl4compiler/makerenderpipelinestatebyspecialization(descriptor:pipeline:)-7s2wp)
- [`var pipelineDataSetSerializer: (any MTL4PipelineDataSetSerializer)?`](https://developer.apple.com/documentation/metal/mtl4compiler/pipelinedatasetserializer)
- [`MTL4CompilerDescriptor`](https://developer.apple.com/documentation/metal/mtl4compilerdescriptor)
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4compilerdescriptor/label)
- [`var pipelineDataSetSerializer: (any MTL4PipelineDataSetSerializer)?`](https://developer.apple.com/documentation/metal/mtl4compilerdescriptor/pipelinedatasetserializer)
- [`MTL4CompilerTaskOptions`](https://developer.apple.com/documentation/metal/mtl4compilertaskoptions)
- [`var lookupArchives: [any MTL4Archive]?`](https://developer.apple.com/documentation/metal/mtl4compilertaskoptions/lookuparchives)
- [`MTL4CompilerTaskStatus`](https://developer.apple.com/documentation/metal/mtl4compilertaskstatus)
- [`case compiling`](https://developer.apple.com/documentation/metal/mtl4compilertaskstatus/compiling)
- [`case finished`](https://developer.apple.com/documentation/metal/mtl4compilertaskstatus/finished)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/metal/mtl4compilertaskstatus/init(rawvalue:))
- [`case none`](https://developer.apple.com/documentation/metal/mtl4compilertaskstatus/none)
- [`case scheduled`](https://developer.apple.com/documentation/metal/mtl4compilertaskstatus/scheduled)
- [`MTL4ComputeCommandEncoder`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder)
- [`func build(destinationAccelerationStructure: any MTLAccelerationStructure, descriptor: MTL4AccelerationStructureDescriptor, scratchBuffer: MTL4BufferRange)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/build(destinationaccelerationstructure:descriptor:scratchbuffer:))
- [`func copy(sourceAccelerationStructure: any MTLAccelerationStructure, destinationAccelerationStructure: any MTLAccelerationStructure)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copy(sourceaccelerationstructure:destinationaccelerationstructure:))
- [`func copy(sourceBuffer: any MTLBuffer, sourceOffset: Int, destinationBuffer: any MTLBuffer, destinationOffset: Int, size: Int)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copy(sourcebuffer:sourceoffset:destinationbuffer:destinationoffset:size:))
- [`func copy(sourceBuffer: any MTLBuffer, sourceOffset: Int, sourceBytesPerRow: Int, sourceBytesPerImage: Int, sourceSize: MTLSize, destinationTexture: any MTLTexture, destinationSlice: Int, destinationLevel: Int, destinationOrigin: MTLOrigin, options: MTLBlitOption)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copy(sourcebuffer:sourceoffset:sourcebytesperrow:sourcebytesperimage:sourcesize:destinationtexture:destinationslice:destinationlevel:destinationorigin:options:))
- [`func copy(sourceTensor: any MTLTensor, sourceOrigin: MTLTensorExtents, sourceDimensions: MTLTensorExtents, destinationTensor: any MTLTensor, destinationOrigin: MTLTensorExtents, destinationDimensions: MTLTensorExtents)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copy(sourcetensor:sourceorigin:sourcedimensions:destinationtensor:destinationorigin:destinationdimensions:))
- [`func copy(sourceTensor: any MTLTensor, sourceOrigin: MTLTensorExtents, sourceDimensions: MTLTensorExtents, sourcePlane: MTLTensorPlaneType, destinationTensor: any MTLTensor, destinationOrigin: MTLTensorExtents, destinationDimensions: MTLTensorExtents, destinationPlane: MTLTensorPlaneType)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copy(sourcetensor:sourceorigin:sourcedimensions:sourceplane:destinationtensor:destinationorigin:destinationdimensions:destinationplane:))
- [`func copy(sourceTexture: any MTLTexture, destinationTexture: any MTLTexture)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copy(sourcetexture:destinationtexture:))
- [`func copy(sourceTexture: any MTLTexture, sourceSlice: Int, sourceLevel: Int, destinationTexture: any MTLTexture, destinationSlice: Int, destinationLevel: Int, sliceCount: Int, levelCount: Int)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copy(sourcetexture:sourceslice:sourcelevel:destinationtexture:destinationslice:destinationlevel:slicecount:levelcount:))
- [`func copy(sourceTexture: any MTLTexture, sourceSlice: Int, sourceLevel: Int, sourceOrigin: MTLOrigin, sourceSize: MTLSize, destinationBuffer: any MTLBuffer, destinationOffset: Int, destinationBytesPerRow: Int, destinationBytesPerImage: Int, options: MTLBlitOption)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copy(sourcetexture:sourceslice:sourcelevel:sourceorigin:sourcesize:destinationbuffer:destinationoffset:destinationbytesperrow:destinationbytesperimage:options:))
- [`func copy(sourceTexture: any MTLTexture, sourceSlice: Int, sourceLevel: Int, sourceOrigin: MTLOrigin, sourceSize: MTLSize, destinationTexture: any MTLTexture, destinationSlice: Int, destinationLevel: Int, destinationOrigin: MTLOrigin)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copy(sourcetexture:sourceslice:sourcelevel:sourceorigin:sourcesize:destinationtexture:destinationslice:destinationlevel:destinationorigin:))
- [`func copyAndCompact(sourceAccelerationStructure: any MTLAccelerationStructure, destinationAccelerationStructure: any MTLAccelerationStructure)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copyandcompact(sourceaccelerationstructure:destinationaccelerationstructure:))
- [`func copyCommands(sourceBuffer: any MTLIndirectCommandBuffer, sourceRange: Range<Int>, destinationBuffer: any MTLIndirectCommandBuffer, destinationIndex: Int)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/copycommands(sourcebuffer:sourcerange:destinationbuffer:destinationindex:))
- [`func dispatchThreadgroups(indirectBuffer: MTLGPUAddress, threadsPerThreadgroup: MTLSize)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/dispatchthreadgroups(indirectbuffer:threadsperthreadgroup:))
- [`func dispatchThreadgroups(threadgroupsPerGrid: MTLSize, threadsPerThreadgroup: MTLSize)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/dispatchthreadgroups(threadgroupspergrid:threadsperthreadgroup:))
- [`func dispatchThreads(indirectBuffer: MTLGPUAddress)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/dispatchthreads(indirectbuffer:))
- [`func dispatchThreads(threadsPerGrid: MTLSize, threadsPerThreadgroup: MTLSize)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/dispatchthreads(threadspergrid:threadsperthreadgroup:))
- [`func executeCommands(buffer: any MTLIndirectCommandBuffer, indirectBuffer: MTLGPUAddress)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/executecommands(buffer:indirectbuffer:))
- [`func executeCommands(buffer: any MTLIndirectCommandBuffer, range: Range<Int>)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/executecommands(buffer:range:))
- [`func fill(buffer: any MTLBuffer, range: Range<Int>, value: UInt8)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/fill(buffer:range:value:))
- [`func generateMipmaps(texture: any MTLTexture)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/generatemipmaps(texture:))
- [`func optimizeCommands(buffer: any MTLIndirectCommandBuffer, range: Range<Int>)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/optimizecommands(buffer:range:))
- [`func optimizeContents(forCPUAccess: any MTLTexture)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/optimizecontents(forcpuaccess:))
- [`func optimizeContents(forCPUAccess: any MTLTexture, slice: Int, level: Int)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/optimizecontents(forcpuaccess:slice:level:))
- [`func optimizeContents(forGPUAccess: any MTLTexture)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/optimizecontents(forgpuaccess:))
- [`func optimizeContents(forGPUAccess: any MTLTexture, slice: Int, level: Int)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/optimizecontents(forgpuaccess:slice:level:))
- [`func refit(sourceAccelerationStructure: any MTLAccelerationStructure, descriptor: MTL4AccelerationStructureDescriptor, destinationAccelerationStructure: (any MTLAccelerationStructure)?, scratchBuffer: MTL4BufferRange, options: MTLAccelerationStructureRefitOptions)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/refit(sourceaccelerationstructure:descriptor:destinationaccelerationstructure:scratchbuffer:options:))
- [`func resetCommands(buffer: any MTLIndirectCommandBuffer, range: Range<Int>)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/resetcommands(buffer:range:))
- [`func setArgumentTable((any MTL4ArgumentTable)?)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/setargumenttable(_:))
- [`func setComputePipelineState(any MTLComputePipelineState)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/setcomputepipelinestate(_:))
- [`func setImageblockSize(width: Int, height: Int)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/setimageblocksize(width:height:))
- [`func setThreadgroupMemoryLength(Int, index: Int)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/setthreadgroupmemorylength(_:index:))
- [`func stages() -> MTLStages`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/stages())
- [`func writeCompactedSize(sourceAccelerationStructure: any MTLAccelerationStructure, destinationBuffer: MTL4BufferRange)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/writecompactedsize(sourceaccelerationstructure:destinationbuffer:))
- [`func writeTimestamp(granularity: MTL4TimestampGranularity, counterHeap: any MTL4CounterHeap, index: Int)`](https://developer.apple.com/documentation/metal/mtl4computecommandencoder/writetimestamp(granularity:counterheap:index:))
- [`MTL4ComputePipelineDescriptor`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor)
- [`var computeFunctionDescriptor: MTL4FunctionDescriptor?`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor/computefunctiondescriptor)
- [`var contentionRelief: MTLContentionRelief`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor/contentionrelief)
- [`var forwardProgressUsage: MTLForwardProgressUsage`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor/forwardprogressusage)
- [`var maxTotalThreadsPerThreadgroup: Int`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor/maxtotalthreadsperthreadgroup)
- [`var optimizeForPersistentKernel: Bool`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor/optimizeforpersistentkernel)
- [`var requiredThreadsPerThreadgroup: MTLSize`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor/requiredthreadsperthreadgroup)
- [`func reset()`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor/reset())
- [`var staticLinkingDescriptor: MTL4StaticLinkingDescriptor?`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor/staticlinkingdescriptor)
- [`var supportBinaryLinking: Bool`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor/supportbinarylinking)
- [`var supportIndirectCommandBuffers: MTL4IndirectCommandBufferSupportState`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor/supportindirectcommandbuffers)
- [`var threadGroupSizeIsMultipleOfThreadExecutionWidth: Bool`](https://developer.apple.com/documentation/metal/mtl4computepipelinedescriptor/threadgroupsizeismultipleofthreadexecutionwidth)
- [`MTL4CopySparseBufferMappingOperation`](https://developer.apple.com/documentation/metal/mtl4copysparsebuffermappingoperation)
- [`var destinationOffset: Int`](https://developer.apple.com/documentation/metal/mtl4copysparsebuffermappingoperation/destinationoffset)
- [`init()`](https://developer.apple.com/documentation/metal/mtl4copysparsebuffermappingoperation/init())
- [`init(sourceRange: NSRange, destinationOffset: Int)`](https://developer.apple.com/documentation/metal/mtl4copysparsebuffermappingoperation/init(sourcerange:destinationoffset:))
- [`var sourceRange: NSRange`](https://developer.apple.com/documentation/metal/mtl4copysparsebuffermappingoperation/sourcerange)
- [`MTL4CopySparseTextureMappingOperation`](https://developer.apple.com/documentation/metal/mtl4copysparsetexturemappingoperation)
- [`var destinationLevel: Int`](https://developer.apple.com/documentation/metal/mtl4copysparsetexturemappingoperation/destinationlevel)
- [`var destinationOrigin: MTLOrigin`](https://developer.apple.com/documentation/metal/mtl4copysparsetexturemappingoperation/destinationorigin)
- [`var destinationSlice: Int`](https://developer.apple.com/documentation/metal/mtl4copysparsetexturemappingoperation/destinationslice)
- [`init()`](https://developer.apple.com/documentation/metal/mtl4copysparsetexturemappingoperation/init())
- [`init(sourceRegion: MTLRegion, sourceLevel: Int, sourceSlice: Int, destinationOrigin: MTLOrigin, destinationLevel: Int, destinationSlice: Int)`](https://developer.apple.com/documentation/metal/mtl4copysparsetexturemappingoperation/init(sourceregion:sourcelevel:sourceslice:destinationorigin:destinationlevel:destinationslice:))
- [`var sourceLevel: Int`](https://developer.apple.com/documentation/metal/mtl4copysparsetexturemappingoperation/sourcelevel)
- [`var sourceRegion: MTLRegion`](https://developer.apple.com/documentation/metal/mtl4copysparsetexturemappingoperation/sourceregion)
- [`var sourceSlice: Int`](https://developer.apple.com/documentation/metal/mtl4copysparsetexturemappingoperation/sourceslice)
- [`MTL4CounterHeap`](https://developer.apple.com/documentation/metal/mtl4counterheap)
- [`var count: Int`](https://developer.apple.com/documentation/metal/mtl4counterheap/count)
- [`func invalidateCounterRange(Range<Int>)`](https://developer.apple.com/documentation/metal/mtl4counterheap/invalidatecounterrange(_:))
- [`var label: String?`](https://developer.apple.com/documentation/metal/mtl4counterheap/label)
- [`func resolveCounterRange(Range<Int>) throws -> Data?`](https://developer.apple.com/documentation/metal/mtl4counterheap/resolvecounterrange(_:))
- [`var type: MTL4CounterHeapType`](https://developer.apple.com/documentation/metal/mtl4counterheap/type)
- [`MTL4CounterHeapDescriptor`](https://developer.apple.com/documentation/metal/mtl4counterheapdescriptor)
- [`var count: Int`](https://developer.apple.com/documentation/metal/mtl4counterheapdescriptor/count)
- [`var type: MTL4CounterHeapType`](https://developer.apple.com/documentation/metal/mtl4counterheapdescriptor/type)
- [`MTL4CounterHeapType`](https://developer.apple.com/documentation/metal/mtl4counterheaptype)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/metal/mtl4counterheaptype/init(rawvalue:))
- [`case invalid`](https://developer.apple.com/documentation/metal/mtl4counterheaptype/invalid)
- [`case timestamp`](https://developer.apple.com/documentation/metal/mtl4counterheaptype/timestamp)
- … and 2206 more (`isim/data/api-coverage.json.gz`)

</details>
<!-- /generated:missing -->
