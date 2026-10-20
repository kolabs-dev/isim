# SceneKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 0.0% of Apple's iOS API (0 of 84, approximate, by name) · **Rows:** 1: 1 ❌ · **iOS:** 8.0+
<!-- /generated:header -->

**Area:** [Games & 3D](../COVERAGE.md#games) · **Apple:** [SceneKit](https://developer.apple.com/documentation/scenekit) · **Issues:** [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

## How isim implements it

- `isim/swift/overlays/SceneKit/SceneKit.swift`: the scene graph and the view, without a 3D renderer. Nodes hold
  their transforms (position, orientation, scale, Euler angles, world transforms) and children; SceneKit's vector and
  matrix types and functions convert to and from simd. `SCNView` runs SceneKit's render loop and calls its delegate,
  but draws only its background colour. It is enough for apps (and ARKit's `ARSCNView`) to build and run.
- Not yet (#330): the renderer, geometry, materials, lights, cameras, actions, physics and scene files (`.scn`, `.dae`,
  `.usdz`). `SCNScene(named:)` returns nil.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `SCNNode` (`position`, `eulerAngles`, `orientation`, `rotation`, `scale`, `transform`, the `simd` variants, `worldTransform` / `worldPosition`, `convertPosition`, `addChildNode`, `insertChildNode`, `removeFromParentNode`, `replaceChildNode`, `childNode(withName:recursively:)`, `childNodes(passingTest:)`, `enumerateChildNodes`, `enumerateHierarchy`, `clone`, `isHidden`, `opacity`, copying and secure coding) | 🟡 | ≤17 | adapted: the transform is kept as translation, rotation and scale (`transform` decomposes into them); Euler angles follow SceneKit's order (roll, then yaw, then pitch); `geometry`, `light`, `camera`, constraints and actions are not there yet (#330); tested (HelloAR: world positions, Euler angles, clone, removal) |
| `SCNScene` (`rootNode`, `isPaused`, attributes, secure coding), `SCNVector3`, `SCNVector4`, `SCNQuaternion`, `SCNMatrix4` and its functions (`SCNMatrix4MakeTranslation` / `Scale` / `Rotation`, `Mult`, `Invert`, `Translate`, `Scale`, `Rotate`, `IsIdentity`, `ToMat4` / `FromMat4`, `SCNVector3Make`, …) | 🟡 | ≤17 | stub for scene files: `SCNScene(named:)` is nil and `init(url:)` throws; the math is complete; tested (HelloAR: translation, scale, inverse) |
| `SCNView` (`scene`, `delegate`, `isPlaying`, `loops`, `rendersContinuously`, `preferredFramesPerSecond`, `allowsCameraControl`, `antialiasingMode`, `play` / `pause` / `stop`, `snapshot`), `SCNSceneRenderer`, `SCNSceneRendererDelegate` | 🟡 | ≤17 | stub for drawing (the background colour only, #330); adapted: the render loop runs at `preferredFramesPerSecond` while playing or rendering continuously and calls the delegate's update, animation, physics, constraint and render callbacks in SceneKit's order; `projectPoint` / `unprojectPoint` pass points through; tested (HelloAR: the render loop's updates) |
| Geometry, materials, lights, cameras, actions, physics, scene files, `SceneView` (SwiftUI), `SK3DNode` | ❌ | ≤17 | the 3D renderer: #330 |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
