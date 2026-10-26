# RealityKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 0.0% of Apple's iOS API (0 of 7592, approximate, by name) · **Rows:** 1: 1 ❌ · **iOS:** 13.0+
<!-- /generated:header -->

**Area:** [Games & 3D](../COVERAGE.md#games) · **Apple:** [RealityKit](https://developer.apple.com/documentation/realitykit) · **Issues:** [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

## How isim implements it

- **Adapted:** isim's Swift implementation (`isim/swift/overlays/RealityKit`, [#331](https://github.com/kolabs-dev/isim/issues/331)) is an entity-component system over isim's [SceneKit](SceneKit.md). SceneKit's renderer draws it with isim's Metal on the CPU. Without AR.
  - **Entities and components.** Each entity is backed by a SceneKit node, which holds its transform.
  - **What the components set on that node:**
    - `ModelComponent`: the node's geometry and materials;
    - the light components: SceneKit lights, with RealityKit's lumens and lux scaled to SceneKit's intensities;
    - `PerspectiveCameraComponent`: the node's camera;
    - `CollisionComponent` and `PhysicsBodyComponent`: a SceneKit physics body, simulated by isim's SceneKit solver;
    - `OpacityComponent`: the node's opacity.
  - **Materials** become SceneKit materials:
    - `SimpleMaterial` and `PhysicallyBasedMaterial` use the physically based model;
    - `UnlitMaterial` uses the constant model;
    - `OcclusionMaterial` writes only depth.
  - **The frame loop.** The view's render loop drives the frames. Each frame runs the registered systems, then publishes `SceneEvents.Update`. SceneKit's physics contacts become `CollisionEvents`.
- **Views.**
  - SwiftUI's `RealityView` uses a virtual camera, over a transparent background.
  - `ARView` works with `cameraMode = .nonAR`. The AR camera mode shows black, as in the Simulator, since there is no camera.
  - **The camera** is the scene's `PerspectiveCamera`, or else a default camera that frames the content.
  - **Lighting.** RealityKit's default image-based lighting is approximated by an ambient light. SceneKit's default light is added while the scene has no lights.
  - **Camera controls.** `.realityViewCameraControls(.orbit)` orbits and zooms.
- **Scene files.** `Entity.load(named:)` reads Wavefront `.obj` files with their `.mtl` materials (through SceneKit). `.reality` and USD files are proprietary or not supported, so loading them throws.
- **Versus a device or Apple's Simulator:**
  - frames are drawn by the CPU;
  - there is no image-based lighting, shadows, grounding shadows, post effects, `ShaderGraphMaterial` or `CustomMaterial`;
  - collision shapes are spheres and boxes (other shapes use their bounding box), and physics is isim's solver, not RealityKit's;
  - there are no skeletal or file animations: only `move(to:…)`;
  - `MeshResource.generateText` is not provided;
  - rounded box corners are not rounded.
- **Objective-C:** none. RealityKit is Swift-only on iOS.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `Entity` (`name`, `id`, `children` / `ChildCollection`, `parent`, `addChild` / `removeChild` / `removeFromParent` / `setParent` with `preservingWorldTransform`, `isEnabled` / `isEnabledInHierarchy` / `isActive` / `isAnchored`, `scene`, `anchor`, `findEntity(named:)`, `clone(recursive:)`, `components` / `ComponentSet`) | ✅ | ≤17 | adapted: backed by a SceneKit node. Tested (HelloRealityKit) |
| `Transform`, `HasTransform` (`transform`, `position` / `orientation` / `scale` and their `relativeTo:` forms, `transformMatrix(relativeTo:)`, `convert(position:/direction:/transform:)`, `look(at:from:upVector:relativeTo:forward:)`, `visualBounds(recursive:relativeTo:excludeInactive:)`), `BoundingBox` | ✅ | ≤17 | Tested (HelloRealityKit: look-at cameras and lights, bounds) |
| `Component` (`registerComponent()`), `System` (`registerSystem()`, `update(context:)`), `SceneUpdateContext`, `EntityQuery`, `QueryPredicate` (`.has`, `&&`, `\|\|`, `!`), `QueryResult` | ✅ | ≤17 | adapted: systems run once a frame, in registration order; `dependencies` are kept, not used. Tested (HelloRealityKit: a custom spin component and system) |
| `Scene` (`anchors`, `addAnchor` / `removeAnchor`, `findEntity(named:)`, `performQuery`, `subscribe(to:on:_:)`, `publisher(for:on:)`, `raycast`), `SceneEvents` (`Update`, `AnchoredStateChanged`, `DidAddEntity`), `CollisionEvents` (`Began`, `Updated`, `Ended`), `AnimationEvents` (`PlaybackCompleted`), `EventSubscription` | ✅ | ≤17 | adapted: collision events from SceneKit's physics contacts; raycasts hit models' triangles. Tested (HelloRealityKit: collision and animation events) |
| `ModelEntity`, `ModelComponent`, `HasModel`, `MeshResource` (`generateBox`, `generateSphere`, `generatePlane` (width × height, width × depth), `generateCylinder`, `generateCone`, `generate(from:)`, `bounds`), `MeshDescriptor` (positions, normals, texture coordinates, triangles / triangles and quads / polygons, per-face materials), `MeshBuffers` | 🟡 | ≤17 | adapted: SceneKit geometry; rounded corners are not rounded; `generateText` is not provided. Tested (HelloRealityKit) |
| `SimpleMaterial`, `UnlitMaterial`, `PhysicallyBasedMaterial` (base colour, metallic, roughness, emissive colour and intensity, blending and opacity, face culling, textures; normal, ambient occlusion, specular and clear coat kept), `OcclusionMaterial`, `TextureResource` (`generate(from:options:)`, `load(named:)`, `init(image:options:)`), `MaterialParameters.Texture` | 🟡 | ≤17 | adapted: SceneKit's physically based and constant lighting models; `ShaderGraphMaterial`, `CustomMaterial` and video materials are not provided. Tested (HelloRealityKit) |
| `PointLight` / `PointLightComponent`, `DirectionalLight` / `DirectionalLightComponent`, `SpotLight` / `SpotLightComponent`, `PerspectiveCamera` / `PerspectiveCameraComponent` | 🟡 | ≤17 | adapted: SceneKit lights (lumens and lux scaled to SceneKit's intensities, attenuation radius); shadows are kept, not drawn. Tested (HelloRealityKit) |
| `CollisionComponent`, `ShapeResource` (box, sphere, capsule, convex), `CollisionFilter` / `CollisionGroup`, `PhysicsBodyComponent`, `PhysicsMotionComponent`, `PhysicsMaterialResource`, `PhysicsMassProperties`, `HasPhysicsBody` (`addForce`, `applyLinearImpulse`, `applyAngularImpulse`) | 🟡 | ≤17 | adapted: SceneKit physics (isim's solver: spheres and boxes); joints and force effects are not provided. Tested (HelloRealityKit: a ball falling onto the floor) |
| `Entity.move(to:relativeTo:duration:timingFunction:)`, `AnimationPlaybackController`, `AnimationTimingFunction` | 🟡 | ≤17 | adapted: transform animations only; `availableAnimations` is empty (scene files' animations are not read). Tested (HelloRealityKit) |
| `AnchorEntity` (`world:`, `.world(transform:)`, `.camera`), `AnchoringComponent` | 🟡 | ≤17 | adapted: without AR, every anchor is placed in the world. Tested (HelloRealityKit) |
| `RealityView` (`make` / `update`, placeholder), `RealityViewCameraContent` (`add`, `remove`, `entities`, `camera`, `subscribe`, `project`), `realityViewCameraControls` | ✅ | ≤17 | adapted: a virtual camera; the AR cameras show black (no camera). Tested (HelloRealityKit) |
| `ARView` (`cameraMode` `.nonAR`, `scene`, `environment.background`, `entity(at:)`, `entities(at:)`, `hitTest`, `ray(through:)`, `project`, `unproject(_:ontoPlane:)`, `snapshot`, `cameraTransform`) | 🟡 | ≤17 | adapted: the AR mode shows black, as in the Simulator; skyboxes and environment maps cannot be loaded; `installGestures` is not provided. Tested (HelloRealityKit: picking and projection) |
| `Entity.load(named:in:)`, `Entity.loadModel(named:in:)`, `Entity(named:in:)` | 🟡 | ≤17 | adapted: Wavefront `.obj` (with `.mtl`); `.reality` and USD files throw. Tested (HelloRealityKit) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
