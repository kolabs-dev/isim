# SceneKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 64.1% of Apple's iOS API (1069 of 1668, exact) · **Rows:** 18: 9 ✅ 8 🟡 1 ❌ · **iOS:** 8.0+
<!-- /generated:header -->

**Area:** [Games & 3D](../COVERAGE.md#games) · **Apple:** [SceneKit](https://developer.apple.com/documentation/scenekit) · **Issues:** [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

## How isim implements it

- **Adapted:** isim's Swift implementation (`isim/swift/overlays/SceneKit`) draws scenes with isim's Metal, which runs
  on the CPU (see [Metal](Metal.md)).
  - SceneKit's shaders (`isim/frameworks/SceneKit/SceneKit.metal`) are compiled for the CPU by `tools/mslc.py` when the
    SDK is built, into `usr/lib/isim/scenekit`. The renderer loads them from `$ISIM_ROOT`.
  - **Lighting:** per pixel, in linear colour (UIColors are sRGB, as on iOS). The lighting models are SceneKit's:
    constant, Lambert, Blinn, Phong and physically based (Cook-Torrance). The shadow-only model is not drawn.
  - **Lights:** ambient, omni, directional and spot (cone and attenuation), with intensity and temperature; up to 8 per
    frame besides the ambient ones. `autoenablesDefaultLighting` adds SceneKit's omni light at the point of view.
  - **Materials:** colours, numbers and images (with mipmaps) for diffuse, ambient, specular, emission, transparent
    (A-one and RGB-zero), multiply, metalness, roughness and ambient occlusion. Also blend modes, culling,
    double-sidedness, wireframe fill, depth reads and writes, vertex colours, and the diffuse contents transform's
    scale and offset.
  - **Fog:** the scene's fog.
  - **Background:** a colour, or an image filling the view.
- **Frames:** each frame walks the scene graph and applies constraints. It draws opaque geometry front to back, then
  transparent geometry back to front, each by rendering order, with a depth buffer.
- **The view and renderers:**
  - `SCNView` draws into its `CAMetalLayer` (`bgra8Unorm_srgb`). Its render loop runs at `preferredFramesPerSecond`: it
    runs actions, animations and physics, calls the delegate in SceneKit's order, and redraws when the scene changed,
    or always while playing or rendering continuously.
  - `SCNRenderer` draws into an app's Metal render pass, or into an image.
  - **The point of view:** the renderer's, else the scene's first camera, else a default camera that frames the scene
    from +z.
  - **Camera control:** `allowsCameraControl` orbits a copy of the camera with one finger and zooms with a pinch.
- **Geometry:**
  - `SCNGeometry` reads its sources (float, half, double and normalized integer components, any stride) and elements
    (triangles, strips, lines, points; polygons become triangle fans).
  - The built-in shapes have Apple's dimensions, segment counts, texture coordinates and elements (one per face
    group, so materials apply face by face).
- **Actions, animations and constraints:**
  - Actions run on nodes, in sequences, groups and repeats.
  - Core Animation animations (`CABasicAnimation`, `CAKeyframeAnimation`, `CAAnimationGroup`) and `SCNAnimation` play
    on nodes' position, scale, rotation, orientation, Euler angles, opacity and transform key paths (and their
    components).
  - Constraints apply before drawing: look-at, billboard, distance, transform and replicator.
- **Physics:** isim's own solver (SceneKit uses Bullet). It has gravity, forces, impulses and damping; sphere and box
  shapes (other shapes use their bounding box); collisions with restitution and friction; masks; resting; and the
  contact delegate.
- **Hit tests:**
  - `hitTest(_:options:)` and `hitTestWithSegment(from:to:options:)` cast rays against geometry's triangles. They return
    the coordinates, normals, face index and texture coordinates.
  - `projectPoint` / `unprojectPoint` and the frustum tests use the camera that last drew.
- **Scene files:** Wavefront `.obj` with its `.mtl` materials and textures, through `SCNScene(named:)`,
  `SCNScene(url:)` and `SCNSceneSource`. Scenes that `write(to:)` archived (`.scn`, isim's keyed archive) load back.
- **SwiftUI and SpriteKit:**
  - `SceneView` is an `SCNView` in a SwiftUI hierarchy.
  - SpriteKit's [`SK3DNode`](SpriteKit.md) draws its scene with an `SCNRenderer`.
- **Versus Apple's Simulator:**
  - Frames are drawn by the CPU, so large views animate at fewer frames per second.
  - Multisampling holds one sample per pixel (not antialiased).
  - No shadows, reflections (floors, the lighting environment), normal or displacement maps.
  - No post effects (HDR, bloom, depth of field, SSAO), shader modifiers, `SCNProgram` or `SCNTechnique`. They are kept,
    not run.
  - No morphers, skinning or particle systems.
  - `SCNText` and `SCNShape` are not provided.
  - Chamfers and corner radii are not rounded.
  - Implicit animation in `SCNTransaction`: changes apply at once, and the completion block runs after the duration.
  - Nodes have no separate presentation copy: animations and constraints write the nodes, and an animation that ends
    puts back the value it started from.
- **ABI:** the SceneKit overlay (and ARKit's, which builds on it) is built with library evolution from 0.31.0. Apps
  built with an earlier isim that use SceneKit or ARKit must be rebuilt (`isim/abi/epochs.txt`).
- **Objective-C:** `#import <SceneKit/SceneKit.h>`, `-framework SceneKit` (`isim/sdk-src/Frameworks/SceneKit`,
  [#560](https://github.com/kolabs-dev/isim/issues/560), and #330 for the renderer's classes).
  - `SCNVector3`, `SCNVector4` and `SCNMatrix4` are C structs with the overlay's layout.
  - SceneKit's functions, constants and class factories are in `frameworks/SceneKit/SceneKit.m`.
  - Properties and methods that take structs or simd values go through categories over `_isim_` entry points
    (`swift/overlays/SceneKit/ObjC.swift`).
  - Objective-C `SCNSceneRendererDelegate` and `SCNPhysicsContactDelegate` objects are held through forwarding boxes.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `SCNNode` (transforms and their `simd` variants, `pivot`, world transforms and positions, `worldUp` / `worldRight` / `worldFront`, `look(at:)`, `localTranslate` / `localRotate` / `rotate(by:aroundTarget:)`, `convertPosition` / `convertVector` / `convertTransform`, the hierarchy, `clone`, `geometry`, `light`, `camera`, `physicsBody`, `constraints`, `isHidden`, `opacity`, `renderingOrder`, `categoryBitMask`, `isPaused`, `boundingBox` / `boundingSphere`, `hitTestWithSegment(from:to:options:)`, copying and secure coding) | ✅ | ≤17 | adapted: the transform is kept as translation, rotation and scale; Euler angles follow SceneKit's order; `presentation` is the node itself. Tested (HelloSceneKit, HelloAR, SceneKitObjCTest) |
| `SCNScene` (`rootNode`, `background`, fog, `physicsWorld`, `isPaused`, attributes, `init(named:)`, `init(url:options:)`, `write(to:options:delegate:progressHandler:)`, secure coding), `SCNSceneSource` | 🟡 | ≤17 | adapted: Wavefront `.obj` / `.mtl` and isim's own `.scn` archives load; Apple's `.scn` / `.dae` as Xcode compiles them, USDZ and Model I/O do not; `lightingEnvironment` is kept, not used. Tested (HelloSceneKit: an OBJ file with two materials) |
| `SCNVector3`, `SCNVector4`, `SCNQuaternion`, `SCNMatrix4` and their functions, `NSValue(scnVector3:)` / `scnVector3Value` and the vector 4 / matrix forms | ✅ | ≤17 | the math is complete; tested (HelloAR, ARSceneObjCTest) |
| `SCNView` (`scene`, `pointOfView`, `delegate`, `isPlaying`, `loops`, `rendersContinuously`, `preferredFramesPerSecond`, `allowsCameraControl`, `autoenablesDefaultLighting`, `antialiasingMode`, `backgroundColor`, `play` / `pause` / `stop`, `snapshot()`, `hitTest(_:options:)`, `projectPoint` / `unprojectPoint`, `isNode(_:insideFrustumOf:)`, `nodesInsideFrustum(of:)`, `device`, `commandQueue`, `currentRenderCommandEncoder`), `SCNSceneRenderer`, `SCNSceneRendererDelegate` | ✅ | ≤17 | adapted: drawn by isim's Metal on the CPU into a `CAMetalLayer`, one sample per pixel; camera control orbits and zooms (the camera controller's other modes are not provided). Tested (HelloSceneKit: pixels, picking, projection, snapshot) |
| `SCNRenderer` (`init(device:options:)`, `render(atTime:viewport:commandBuffer:passDescriptor:)`, `render(withViewport:commandBuffer:passDescriptor:)`, `snapshot(atTime:with:antialiasingMode:)`, `update(atTime:)`, `nextFrameTime`) | ✅ | ≤17 | adapted: renders into the app's own Metal pass (isim's Metal on the CPU). Tested (HelloSceneKit, SceneKitObjCTest: snapshots) |
| `SCNGeometry` (`sources`, `elements`, `materials`, `firstMaterial`, `material(named:)`, insert / remove / replace, `boundingBox` / `boundingSphere`), `SCNGeometrySource` (vertices, normals, texture coordinates, `init(data:semantic:…)`, `init(buffer:vertexFormat:…)`), `SCNGeometryElement` (indices of 1, 2 or 4 bytes, `primitiveRange`, `pointSize`) | ✅ | ≤17 | adapted: triangles, strips, lines and points are drawn; polygons become triangle fans; `subdivisionLevel` and `levelsOfDetail` are kept, not applied. Tested (SceneKitObjCTest: a triangle from sources) |
| `SCNBox`, `SCNSphere`, `SCNPlane`, `SCNPyramid`, `SCNCylinder`, `SCNCone`, `SCNTorus`, `SCNTube`, `SCNCapsule`, `SCNFloor` | 🟡 | ≤17 | adapted: Apple's dimensions, segment counts and elements; chamfers and corner radii are not rounded, `isGeodesic` spheres are UV spheres, floors do not reflect (an endless floor is drawn 1000 units across). Tested (HelloSceneKit) |
| `SCNText`, `SCNShape` | ❌ | ≤17 | not yet: extruded text and paths |
| `SCNMaterial` (lighting models, `diffuse` / `ambient` / `specular` / `emission` / `transparent` / `multiply` / `metalness` / `roughness` / `ambientOcclusion`, `shininess`, `transparency`, `transparencyMode`, `isDoubleSided`, `cullMode`, `fillMode`, `blendMode`, `locksAmbientWithDiffuse`, depth reads and writes, `colorBufferWriteMask`), `SCNMaterialProperty` (`contents`: colours, numbers, images, image names, URLs, `MTLTexture`; `intensity`, `contentsTransform`, wrap modes, filters) | 🟡 | ≤17 | adapted: per-pixel lighting in linear colour; `normal`, `displacement`, `reflective`, `selfIllumination` and clear coat are kept, not drawn; shader modifiers and `SCNProgram` are kept, not run; the contents transform's scale and offset apply to the diffuse map. Tested (HelloSceneKit: Blinn with a checkerboard, physically based, transparent OBJ material) |
| `SCNLight` (`type`: ambient, omni, directional, spot; `color`, `intensity`, `temperature`, attenuation, spot angles, `categoryBitMask`) | 🟡 | ≤17 | adapted: up to 8 omni / directional / spot lights a frame; shadows (`castsShadow` and its settings), IES, probe and area lights are kept, not drawn. Tested (HelloSceneKit) |
| `SCNCamera` (`fieldOfView`, `projectionDirection`, `focalLength` / `sensorHeight`, `zNear` / `zFar`, `automaticallyAdjustsZRange`, `usesOrthographicProjection`, `orthographicScale`, `projectionTransform`) | 🟡 | ≤17 | adapted: post effects (HDR, exposure, bloom, depth of field, motion blur, SSAO, grain, colour grading) are kept, not drawn. Tested (HelloSceneKit, SceneKitObjCTest) |
| `SCNAction` (move, rotate, scale, fade, hide, remove, wait, run block, custom, sequence, group, repeat, `reversed()`, timing modes and functions, `speed`), `SCNActionable` | ✅ | ≤17 | adapted: rotateBy turns about the node's own axes. Tested (HelloSceneKit, SceneKitObjCTest: completion handlers, keys) |
| `SCNAnimatable` (`addAnimation(_:forKey:)` with `CABasicAnimation` / `CAKeyframeAnimation` / `CAAnimationGroup` or `SCNAnimation`, `SCNAnimationPlayer`, remove, keys), `SCNAnimation`, `SCNTimingFunction`, `SCNTransaction` | 🟡 | ≤17 | adapted: node transform and opacity key paths; the animation writes the node and an animation that ends puts back its start value; `CAAnimationDelegate` and `animationDidStart` / `animationDidStop` are called; `SCNTransaction` applies changes at once (no implicit animation) and runs `completionBlock` after `animationDuration`; animations in scene files are not read. Tested (HelloSceneKit: a CABasicAnimation on `position.y`) |
| `SCNLookAtConstraint`, `SCNBillboardConstraint`, `SCNDistanceConstraint`, `SCNTransformConstraint`, `SCNReplicatorConstraint` | ✅ | ≤17 | adapted: solved each frame before drawing, with `influenceFactor`. Tested (HelloSceneKit, SceneKitObjCTest: a camera aimed by a look-at constraint) |
| `SCNPhysicsWorld` (`gravity`, `speed`, `timeStep`, `contactDelegate`, `contactTest`, `rayTestWithSegment`), `SCNPhysicsBody` (static, dynamic, kinematic; mass, friction, restitution, damping, velocity, forces, impulses, torques, masks, resting), `SCNPhysicsShape`, `SCNPhysicsContact`, `SCNPhysicsContactDelegate` | 🟡 | ≤17 | adapted: isim's solver: sphere and box shapes (others use their bounding box), boxes collide aligned with the world axes, contacts do not make bodies spin; ray tests use bounding volumes; behaviors (joints), fields and vehicles are not simulated. Tested (HelloSceneKit, SceneKitObjCTest: a ball falling onto a floor, the contact delegate) |
| `SCNHitTestResult`, `SCNHitTestOption` (first found, back-face culling, bounding box only, ignore children / hidden, category mask, root node, search mode) | ✅ | ≤17 | adapted: rays against triangles. Tested (HelloSceneKit, SceneKitObjCTest) |
| `SceneView` (SwiftUI) | ✅ | ≤17 | an `SCNView` in a SwiftUI hierarchy (scene, point of view, options, frame rate, antialiasing mode, delegate); `technique` is kept, not run. Tested (HelloSceneKit) |
| Objective-C: the classes above under Apple's names and their class factories (`+boxWithWidth:height:length:chamferRadius:`, `+nodeWithGeometry:`, `+material`, `+light`, `+camera`, `+geometrySourceWithVertices:count:`, …), the constants (`SCNLightTypeOmni`, `SCNLightingModelBlinn`, `SCNGeometrySourceSemanticVertex`, `SCNHitTest…Key`, `SCNPhysicsShape…`), the enums, `SCNPhysicsContactDelegate`, `SCNVector3` / `SCNVector4` / `SCNMatrix4` and their functions, `NSValue (SceneKitAdditions)` | 🟡 | ≤17 | adapted: the Swift classes under Apple's Objective-C names, not subclassable from Objective-C; struct members through categories; the delegates through forwarding boxes; `SCNTransformConstraint`'s blocks, `SCNSceneSource` and `SCNPhysicsWorld`'s tests are Swift-only. Tested (SceneKitObjCTest, ARSceneObjCTest) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
599 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var SCN_ENABLE_METAL: Int32`](https://developer.apple.com/documentation/scenekit/scn_enable_metal)
- [`var SCN_ENABLE_METAL: Int32`](https://developer.apple.com/documentation/scenekit/scn_enable_metal)
- [`var SCN_ENABLE_OPENGL: Int32`](https://developer.apple.com/documentation/scenekit/scn_enable_opengl)
- [`var SCN_ENABLE_OPENGL: Int32`](https://developer.apple.com/documentation/scenekit/scn_enable_opengl)
- [`SCNAccelerationConstraint`](https://developer.apple.com/documentation/scenekit/scnaccelerationconstraint)
- [`var damping: CGFloat`](https://developer.apple.com/documentation/scenekit/scnaccelerationconstraint/damping)
- [`var decelerationDistance: CGFloat`](https://developer.apple.com/documentation/scenekit/scnaccelerationconstraint/decelerationdistance)
- [`var maximumLinearAcceleration: CGFloat`](https://developer.apple.com/documentation/scenekit/scnaccelerationconstraint/maximumlinearacceleration)
- [`var maximumLinearVelocity: CGFloat`](https://developer.apple.com/documentation/scenekit/scnaccelerationconstraint/maximumlinearvelocity)
- [`class func javaScriptAction(withScript: String, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/javascriptaction(withscript:duration:))
- [`class func playAudio(SCNAudioSource, waitForCompletion: Bool) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/playaudio(_:waitforcompletion:))
- [`func animation(forKey: String) -> CAAnimation?`](https://developer.apple.com/documentation/scenekit/scnanimatable/animation(forkey:))
- [`func isAnimationPaused(forKey: String) -> Bool`](https://developer.apple.com/documentation/scenekit/scnanimatable/isanimationpaused(forkey:))
- [`func pauseAnimation(forKey: String)`](https://developer.apple.com/documentation/scenekit/scnanimatable/pauseanimation(forkey:))
- [`func resumeAnimation(forKey: String)`](https://developer.apple.com/documentation/scenekit/scnanimatable/resumeanimation(forkey:))
- [`func setAnimationSpeed(CGFloat, forKey: String)`](https://developer.apple.com/documentation/scenekit/scnanimatable/setanimationspeed(_:forkey:))
- [`var animationEvents: [SCNAnimationEvent]?`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/animationevents)
- [`var animationEvents: [SCNAnimationEvent]?`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/animationevents)
- [`SCNAnimationEvent`](https://developer.apple.com/documentation/scenekit/scnanimationevent)
- [`convenience init(keyTime: CGFloat, block: SCNAnimationEventBlock)`](https://developer.apple.com/documentation/scenekit/scnanimationevent/init(keytime:block:))
- [`SCNAnimationEventBlock`](https://developer.apple.com/documentation/scenekit/scnanimationeventblock)
- [`case multisampling16X`](https://developer.apple.com/documentation/scenekit/scnantialiasingmode/multisampling16x)
- [`case multisampling8X`](https://developer.apple.com/documentation/scenekit/scnantialiasingmode/multisampling8x)
- [`SCNAudioPlayer`](https://developer.apple.com/documentation/scenekit/scnaudioplayer)
- [`var audioNode: AVAudioNode?`](https://developer.apple.com/documentation/scenekit/scnaudioplayer/audionode)
- [`var audioSource: SCNAudioSource?`](https://developer.apple.com/documentation/scenekit/scnaudioplayer/audiosource)
- [`var didFinishPlayback: (() -> Void)?`](https://developer.apple.com/documentation/scenekit/scnaudioplayer/didfinishplayback)
- [`convenience init(AVAudioNode: AVAudioNode)`](https://developer.apple.com/documentation/scenekit/scnaudioplayer/init(avaudionode:)-1xsj6)
- [`init(avAudioNode: AVAudioNode)`](https://developer.apple.com/documentation/scenekit/scnaudioplayer/init(avaudionode:)-4u514)
- [`init(AVAudioNode: AVAudioNode)`](https://developer.apple.com/documentation/scenekit/scnaudioplayer/init(avaudionode:)-6dktc)
- [`init(source: SCNAudioSource)`](https://developer.apple.com/documentation/scenekit/scnaudioplayer/init(source:))
- [`var willStartPlayback: (() -> Void)?`](https://developer.apple.com/documentation/scenekit/scnaudioplayer/willstartplayback)
- [`SCNAudioSource`](https://developer.apple.com/documentation/scenekit/scnaudiosource)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/scenekit/scnaudiosource/init(coder:))
- [`convenience init?(fileNamed: String)`](https://developer.apple.com/documentation/scenekit/scnaudiosource/init(filenamed:))
- [`convenience init?(named: String)`](https://developer.apple.com/documentation/scenekit/scnaudiosource/init(named:))
- [`init?(url: URL)`](https://developer.apple.com/documentation/scenekit/scnaudiosource/init(url:)-3qyjs)
- [`init?(URL: URL)`](https://developer.apple.com/documentation/scenekit/scnaudiosource/init(url:)-8cknu)
- [`var isPositional: Bool`](https://developer.apple.com/documentation/scenekit/scnaudiosource/ispositional)
- [`func load()`](https://developer.apple.com/documentation/scenekit/scnaudiosource/load())
- [`var loops: Bool`](https://developer.apple.com/documentation/scenekit/scnaudiosource/loops)
- [`var rate: Float`](https://developer.apple.com/documentation/scenekit/scnaudiosource/rate)
- [`var reverbBlend: Float`](https://developer.apple.com/documentation/scenekit/scnaudiosource/reverbblend)
- [`var shouldStream: Bool`](https://developer.apple.com/documentation/scenekit/scnaudiosource/shouldstream)
- [`var volume: Float`](https://developer.apple.com/documentation/scenekit/scnaudiosource/volume)
- [`SCNAvoidOccluderConstraint`](https://developer.apple.com/documentation/scenekit/scnavoidoccluderconstraint)
- [`var bias: CGFloat`](https://developer.apple.com/documentation/scenekit/scnavoidoccluderconstraint/bias)
- [`var delegate: any SCNAvoidOccluderConstraintDelegate`](https://developer.apple.com/documentation/scenekit/scnavoidoccluderconstraint/delegate)
- [`convenience init(target: SCNNode?)`](https://developer.apple.com/documentation/scenekit/scnavoidoccluderconstraint/init(target:))
- [`var occluderCategoryBitMask: Int`](https://developer.apple.com/documentation/scenekit/scnavoidoccluderconstraint/occludercategorybitmask)
- [`var target: SCNNode?`](https://developer.apple.com/documentation/scenekit/scnavoidoccluderconstraint/target)
- [`SCNAvoidOccluderConstraintDelegate`](https://developer.apple.com/documentation/scenekit/scnavoidoccluderconstraintdelegate)
- [`func avoidOccluderConstraint(SCNAvoidOccluderConstraint, didAvoidOccluder: SCNNode, for: SCNNode)`](https://developer.apple.com/documentation/scenekit/scnavoidoccluderconstraintdelegate/avoidoccluderconstraint(_:didavoidoccluder:for:))
- [`func avoidOccluderConstraint(SCNAvoidOccluderConstraint, shouldAvoidOccluder: SCNNode, for: SCNNode) -> Bool`](https://developer.apple.com/documentation/scenekit/scnavoidoccluderconstraintdelegate/avoidoccluderconstraint(_:shouldavoidoccluder:for:))
- [`SCNBindingBlock`](https://developer.apple.com/documentation/scenekit/scnbindingblock)
- [`SCNBufferBindingBlock`](https://developer.apple.com/documentation/scenekit/scnbufferbindingblock)
- [`SCNBufferFrequency`](https://developer.apple.com/documentation/scenekit/scnbufferfrequency)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnbufferfrequency/init(rawvalue:))
- [`case perFrame`](https://developer.apple.com/documentation/scenekit/scnbufferfrequency/perframe)
- [`case perNode`](https://developer.apple.com/documentation/scenekit/scnbufferfrequency/pernode)
- [`case perShadable`](https://developer.apple.com/documentation/scenekit/scnbufferfrequency/pershadable)
- [`SCNBufferStream`](https://developer.apple.com/documentation/scenekit/scnbufferstream)
- [`func writeBytes(UnsafeRawPointer, count: Int)`](https://developer.apple.com/documentation/scenekit/scnbufferstream/writebytes(_:count:))
- [`var aperture: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/aperture)
- [`var focalBlurRadius: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/focalblurradius)
- [`var focalDistance: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/focaldistance)
- [`var focalSize: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/focalsize)
- [`var xFov: Double`](https://developer.apple.com/documentation/scenekit/scncamera/xfov)
- [`var yFov: Double`](https://developer.apple.com/documentation/scenekit/scncamera/yfov)
- [`SCNCameraControlConfiguration`](https://developer.apple.com/documentation/scenekit/scncameracontrolconfiguration)
- [`var allowsTranslation: Bool`](https://developer.apple.com/documentation/scenekit/scncameracontrolconfiguration/allowstranslation)
- [`var autoSwitchToFreeCamera: Bool`](https://developer.apple.com/documentation/scenekit/scncameracontrolconfiguration/autoswitchtofreecamera)
- [`var flyModeVelocity: CGFloat`](https://developer.apple.com/documentation/scenekit/scncameracontrolconfiguration/flymodevelocity)
- [`var panSensitivity: CGFloat`](https://developer.apple.com/documentation/scenekit/scncameracontrolconfiguration/pansensitivity)
- [`var rotationSensitivity: CGFloat`](https://developer.apple.com/documentation/scenekit/scncameracontrolconfiguration/rotationsensitivity)
- [`var truckSensitivity: CGFloat`](https://developer.apple.com/documentation/scenekit/scncameracontrolconfiguration/trucksensitivity)
- [`SCNCameraController`](https://developer.apple.com/documentation/scenekit/scncameracontroller)
- [`var automaticTarget: Bool`](https://developer.apple.com/documentation/scenekit/scncameracontroller/automatictarget)
- [`func beginInteraction(CGPoint, withViewport: CGSize)`](https://developer.apple.com/documentation/scenekit/scncameracontroller/begininteraction(_:withviewport:))
- [`func clearRoll()`](https://developer.apple.com/documentation/scenekit/scncameracontroller/clearroll())
- [`func continueInteraction(CGPoint, withViewport: CGSize, sensitivity: CGFloat)`](https://developer.apple.com/documentation/scenekit/scncameracontroller/continueinteraction(_:withviewport:sensitivity:))
- [`var delegate: (any SCNCameraControllerDelegate)?`](https://developer.apple.com/documentation/scenekit/scncameracontroller/delegate)
- [`func dolly(by: Float, onScreenPoint: CGPoint, viewport: CGSize)`](https://developer.apple.com/documentation/scenekit/scncameracontroller/dolly(by:onscreenpoint:viewport:))
- [`func dolly(toTarget: Float)`](https://developer.apple.com/documentation/scenekit/scncameracontroller/dolly(totarget:))
- [`func endInteraction(CGPoint, withViewport: CGSize, velocity: CGPoint)`](https://developer.apple.com/documentation/scenekit/scncameracontroller/endinteraction(_:withviewport:velocity:))
- [`func frameNodes([SCNNode])`](https://developer.apple.com/documentation/scenekit/scncameracontroller/framenodes(_:))
- [`var inertiaEnabled: Bool`](https://developer.apple.com/documentation/scenekit/scncameracontroller/inertiaenabled)
- [`var inertiaFriction: Float`](https://developer.apple.com/documentation/scenekit/scncameracontroller/inertiafriction)
- [`var interactionMode: SCNInteractionMode`](https://developer.apple.com/documentation/scenekit/scncameracontroller/interactionmode)
- [`var isInertiaRunning: Bool`](https://developer.apple.com/documentation/scenekit/scncameracontroller/isinertiarunning)
- [`var maximumHorizontalAngle: Float`](https://developer.apple.com/documentation/scenekit/scncameracontroller/maximumhorizontalangle)
- [`var maximumVerticalAngle: Float`](https://developer.apple.com/documentation/scenekit/scncameracontroller/maximumverticalangle)
- [`var minimumHorizontalAngle: Float`](https://developer.apple.com/documentation/scenekit/scncameracontroller/minimumhorizontalangle)
- [`var minimumVerticalAngle: Float`](https://developer.apple.com/documentation/scenekit/scncameracontroller/minimumverticalangle)
- [`var pointOfView: SCNNode?`](https://developer.apple.com/documentation/scenekit/scncameracontroller/pointofview)
- [`func roll(by: Float, aroundScreenPoint: CGPoint, viewport: CGSize)`](https://developer.apple.com/documentation/scenekit/scncameracontroller/roll(by:aroundscreenpoint:viewport:))
- [`func rollAroundTarget(Float)`](https://developer.apple.com/documentation/scenekit/scncameracontroller/rollaroundtarget(_:))
- [`func rotateBy(x: Float, y: Float)`](https://developer.apple.com/documentation/scenekit/scncameracontroller/rotateby(x:y:))
- [`func stopInertia()`](https://developer.apple.com/documentation/scenekit/scncameracontroller/stopinertia())
- [`var target: SCNVector3`](https://developer.apple.com/documentation/scenekit/scncameracontroller/target)
- [`func translateInCameraSpaceBy(x: Float, y: Float, z: Float)`](https://developer.apple.com/documentation/scenekit/scncameracontroller/translateincameraspaceby(x:y:z:))
- [`var worldUp: SCNVector3`](https://developer.apple.com/documentation/scenekit/scncameracontroller/worldup)
- [`SCNCameraControllerDelegate`](https://developer.apple.com/documentation/scenekit/scncameracontrollerdelegate)
- [`func cameraInertiaDidEnd(for: SCNCameraController)`](https://developer.apple.com/documentation/scenekit/scncameracontrollerdelegate/camerainertiadidend(for:))
- [`func cameraInertiaWillStart(for: SCNCameraController)`](https://developer.apple.com/documentation/scenekit/scncameracontrollerdelegate/camerainertiawillstart(for:))
- [`SCNChamferMode`](https://developer.apple.com/documentation/scenekit/scnchamfermode)
- [`case back`](https://developer.apple.com/documentation/scenekit/scnchamfermode/back)
- [`case both`](https://developer.apple.com/documentation/scenekit/scnchamfermode/both)
- [`case front`](https://developer.apple.com/documentation/scenekit/scnchamfermode/front)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnchamfermode/init(rawvalue:))
- [`let SCNConsistencyElementIDErrorKey: String`](https://developer.apple.com/documentation/scenekit/scnconsistencyelementiderrorkey)
- [`let SCNConsistencyElementTypeErrorKey: String`](https://developer.apple.com/documentation/scenekit/scnconsistencyelementtypeerrorkey)
- [`var SCNConsistencyInvalidArgumentError: Int`](https://developer.apple.com/documentation/scenekit/scnconsistencyinvalidargumenterror)
- [`var SCNConsistencyInvalidCountError: Int`](https://developer.apple.com/documentation/scenekit/scnconsistencyinvalidcounterror)
- [`var SCNConsistencyInvalidURIError: Int`](https://developer.apple.com/documentation/scenekit/scnconsistencyinvalidurierror)
- [`let SCNConsistencyLineNumberErrorKey: String`](https://developer.apple.com/documentation/scenekit/scnconsistencylinenumbererrorkey)
- [`var SCNConsistencyMissingAttributeError: Int`](https://developer.apple.com/documentation/scenekit/scnconsistencymissingattributeerror)
- [`var SCNConsistencyMissingElementError: Int`](https://developer.apple.com/documentation/scenekit/scnconsistencymissingelementerror)
- [`var SCNConsistencyXMLSchemaValidationError: Int`](https://developer.apple.com/documentation/scenekit/scnconsistencyxmlschemavalidationerror)
- [`static let showFeaturePoints: SCNDebugOptions`](https://developer.apple.com/documentation/scenekit/scndebugoptions/showfeaturepoints)
- [`static let showWorldOrigin: SCNDebugOptions`](https://developer.apple.com/documentation/scenekit/scndebugoptions/showworldorigin)
- [`let SCNDetailedErrorsKey: String`](https://developer.apple.com/documentation/scenekit/scndetailederrorskey)
- [`let SCNErrorDomain: String`](https://developer.apple.com/documentation/scenekit/scnerrordomain)
- [`func SCNExportJavaScriptModule(JSContext)`](https://developer.apple.com/documentation/scenekit/scnexportjavascriptmodule(_:))
- [`SCNFieldForceEvaluator`](https://developer.apple.com/documentation/scenekit/scnfieldforceevaluator)
- [`SCNFloat`](https://developer.apple.com/documentation/scenekit/scnfloat)
- [`var geometrySourceChannels: [NSNumber]?`](https://developer.apple.com/documentation/scenekit/scngeometry/geometrysourcechannels)
- [`var tessellator: SCNGeometryTessellator?`](https://developer.apple.com/documentation/scenekit/scngeometry/tessellator)
- [`SCNGeometryTessellator`](https://developer.apple.com/documentation/scenekit/scngeometrytessellator)
- [`var edgeTessellationFactor: CGFloat`](https://developer.apple.com/documentation/scenekit/scngeometrytessellator/edgetessellationfactor)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/scenekit/scngeometrytessellator/init(coder:))
- [`var insideTessellationFactor: CGFloat`](https://developer.apple.com/documentation/scenekit/scngeometrytessellator/insidetessellationfactor)
- [`var isAdaptive: Bool`](https://developer.apple.com/documentation/scenekit/scngeometrytessellator/isadaptive)
- [`var isScreenSpace: Bool`](https://developer.apple.com/documentation/scenekit/scngeometrytessellator/isscreenspace)
- [`var maximumEdgeLength: CGFloat`](https://developer.apple.com/documentation/scenekit/scngeometrytessellator/maximumedgelength)
- [`var smoothingMode: SCNTessellationSmoothingMode`](https://developer.apple.com/documentation/scenekit/scngeometrytessellator/smoothingmode)
- [`var tessellationFactorScale: CGFloat`](https://developer.apple.com/documentation/scenekit/scngeometrytessellator/tessellationfactorscale)
- [`var tessellationPartitionMode: MTLTessellationPartitionMode`](https://developer.apple.com/documentation/scenekit/scngeometrytessellator/tessellationpartitionmode)
- [`SCNIKConstraint`](https://developer.apple.com/documentation/scenekit/scnikconstraint)
- [`var chainRootNode: SCNNode`](https://developer.apple.com/documentation/scenekit/scnikconstraint/chainrootnode)
- [`init(chainRootNode: SCNNode)`](https://developer.apple.com/documentation/scenekit/scnikconstraint/init(chainrootnode:))
- [`class func inverseKinematicsConstraint(chainRootNode: SCNNode) -> Self`](https://developer.apple.com/documentation/scenekit/scnikconstraint/inversekinematicsconstraint(chainrootnode:))
- [`func maxAllowedRotationAngle(forJoint: SCNNode) -> CGFloat`](https://developer.apple.com/documentation/scenekit/scnikconstraint/maxallowedrotationangle(forjoint:))
- [`func setMaxAllowedRotationAngle(CGFloat, forJoint: SCNNode)`](https://developer.apple.com/documentation/scenekit/scnikconstraint/setmaxallowedrotationangle(_:forjoint:))
- [`var targetPosition: SCNVector3`](https://developer.apple.com/documentation/scenekit/scnikconstraint/targetposition)
- [`SCNInteractionMode`](https://developer.apple.com/documentation/scenekit/scninteractionmode)
- [`case fly`](https://developer.apple.com/documentation/scenekit/scninteractionmode/fly)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scninteractionmode/init(rawvalue:))
- [`case orbitAngleMapping`](https://developer.apple.com/documentation/scenekit/scninteractionmode/orbitanglemapping)
- [`case orbitArcball`](https://developer.apple.com/documentation/scenekit/scninteractionmode/orbitarcball)
- [`case orbitCenteredArcball`](https://developer.apple.com/documentation/scenekit/scninteractionmode/orbitcenteredarcball)
- [`case orbitTurntable`](https://developer.apple.com/documentation/scenekit/scninteractionmode/orbitturntable)
- [`case pan`](https://developer.apple.com/documentation/scenekit/scninteractionmode/pan)
- [`case truck`](https://developer.apple.com/documentation/scenekit/scninteractionmode/truck)
- [`SCNLayer`](https://developer.apple.com/documentation/scenekit/scnlayer)
- [`var scene: SCNScene?`](https://developer.apple.com/documentation/scenekit/scnlayer/scene)
- [`var areaPolygonVertices: [NSValue]?`](https://developer.apple.com/documentation/scenekit/scnlight/areapolygonvertices)
- [`func attribute(forKey: String) -> Any?`](https://developer.apple.com/documentation/scenekit/scnlight/attribute(forkey:))
- [`func setAttribute(Any?, forKey: String)`](https://developer.apple.com/documentation/scenekit/scnlight/setattribute(_:forkey:))
- [`SCNLightAreaType`](https://developer.apple.com/documentation/scenekit/scnlightareatype)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnlightareatype/init(rawvalue:))
- [`case polygon`](https://developer.apple.com/documentation/scenekit/scnlightareatype/polygon)
- [`case rectangle`](https://developer.apple.com/documentation/scenekit/scnlightareatype/rectangle)
- [`let SCNLightAttenuationEndKey: String`](https://developer.apple.com/documentation/scenekit/scnlightattenuationendkey)
- [`let SCNLightAttenuationFalloffExponentKey: String`](https://developer.apple.com/documentation/scenekit/scnlightattenuationfalloffexponentkey)
- [`let SCNLightAttenuationStartKey: String`](https://developer.apple.com/documentation/scenekit/scnlightattenuationstartkey)
- [`SCNLightProbeType`](https://developer.apple.com/documentation/scenekit/scnlightprobetype)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnlightprobetype/init(rawvalue:))
- [`case irradiance`](https://developer.apple.com/documentation/scenekit/scnlightprobetype/irradiance)
- [`case radiance`](https://developer.apple.com/documentation/scenekit/scnlightprobetype/radiance)
- [`SCNLightProbeUpdateType`](https://developer.apple.com/documentation/scenekit/scnlightprobeupdatetype)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnlightprobeupdatetype/init(rawvalue:))
- [`case never`](https://developer.apple.com/documentation/scenekit/scnlightprobeupdatetype/never)
- [`case realtime`](https://developer.apple.com/documentation/scenekit/scnlightprobeupdatetype/realtime)
- [`let SCNLightShadowFarClippingKey: String`](https://developer.apple.com/documentation/scenekit/scnlightshadowfarclippingkey)
- [`let SCNLightShadowNearClippingKey: String`](https://developer.apple.com/documentation/scenekit/scnlightshadownearclippingkey)
- [`let SCNLightSpotInnerAngleKey: String`](https://developer.apple.com/documentation/scenekit/scnlightspotinneranglekey)
- [`let SCNLightSpotOuterAngleKey: String`](https://developer.apple.com/documentation/scenekit/scnlightspotouteranglekey)
- [`class func precomputedLightingEnvironmentContents(with: Data) throws -> Any`](https://developer.apple.com/documentation/scenekit/scnmaterialproperty/precomputedlightingenvironmentcontents(with:)-2cwpt)
- [`class func precomputedLightingEnvironmentContents(with: URL) throws -> Any`](https://developer.apple.com/documentation/scenekit/scnmaterialproperty/precomputedlightingenvironmentcontents(with:)-5f6ar)
- [`class func precomputedLightingEnvironmentData(forContents: Any, device: (any MTLDevice)?) throws -> Data`](https://developer.apple.com/documentation/scenekit/scnmaterialproperty/precomputedlightingenvironmentdata(forcontents:device:))
- [`func SCNMatrix4FromGLKMatrix4(GLKMatrix4) -> SCNMatrix4`](https://developer.apple.com/documentation/scenekit/scnmatrix4fromglkmatrix4(_:))
- [`func SCNMatrix4FromGLKMatrix4(GLKMatrix4) -> SCNMatrix4`](https://developer.apple.com/documentation/scenekit/scnmatrix4fromglkmatrix4(_:))
- [`func SCNMatrix4ToGLKMatrix4(SCNMatrix4) -> GLKMatrix4`](https://developer.apple.com/documentation/scenekit/scnmatrix4toglkmatrix4(_:))
- [`func SCNMatrix4ToGLKMatrix4(SCNMatrix4) -> GLKMatrix4`](https://developer.apple.com/documentation/scenekit/scnmatrix4toglkmatrix4(_:))
- [`let SCNModelTransform: String`](https://developer.apple.com/documentation/scenekit/scnmodeltransform)
- [`let SCNModelViewProjectionTransform: String`](https://developer.apple.com/documentation/scenekit/scnmodelviewprojectiontransform)
- [`let SCNModelViewTransform: String`](https://developer.apple.com/documentation/scenekit/scnmodelviewtransform)
- [`SCNMorpher`](https://developer.apple.com/documentation/scenekit/scnmorpher)
- [`var calculationMode: SCNMorpherCalculationMode`](https://developer.apple.com/documentation/scenekit/scnmorpher/calculationmode)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/scenekit/scnmorpher/init(coder:))
- [`func setWeight(CGFloat, forTargetAt: Int)`](https://developer.apple.com/documentation/scenekit/scnmorpher/setweight(_:fortargetat:))
- [`func setWeight(CGFloat, forTargetNamed: String)`](https://developer.apple.com/documentation/scenekit/scnmorpher/setweight(_:fortargetnamed:))
- [`var targets: [SCNGeometry]`](https://developer.apple.com/documentation/scenekit/scnmorpher/targets)
- [`var unifiesNormals: Bool`](https://developer.apple.com/documentation/scenekit/scnmorpher/unifiesnormals)
- [`func weight(forTargetAt: Int) -> CGFloat`](https://developer.apple.com/documentation/scenekit/scnmorpher/weight(fortargetat:))
- [`func weight(forTargetNamed: String) -> CGFloat`](https://developer.apple.com/documentation/scenekit/scnmorpher/weight(fortargetnamed:))
- [`var weights: [NSNumber]`](https://developer.apple.com/documentation/scenekit/scnmorpher/weights)
- [`SCNMorpherCalculationMode`](https://developer.apple.com/documentation/scenekit/scnmorphercalculationmode)
- [`case additive`](https://developer.apple.com/documentation/scenekit/scnmorphercalculationmode/additive)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnmorphercalculationmode/init(rawvalue:))
- [`case normalized`](https://developer.apple.com/documentation/scenekit/scnmorphercalculationmode/normalized)
- [`func addAudioPlayer(SCNAudioPlayer)`](https://developer.apple.com/documentation/scenekit/scnnode/addaudioplayer(_:))
- [`func addParticleSystem(SCNParticleSystem)`](https://developer.apple.com/documentation/scenekit/scnnode/addparticlesystem(_:))
- [`var audioPlayers: [SCNAudioPlayer]`](https://developer.apple.com/documentation/scenekit/scnnode/audioplayers)
- [`var entity: GKEntity?`](https://developer.apple.com/documentation/scenekit/scnnode/entity)
- [`var filters: [CIFilter]?`](https://developer.apple.com/documentation/scenekit/scnnode/filters)
- [`var morpher: SCNMorpher?`](https://developer.apple.com/documentation/scenekit/scnnode/morpher)
- [`var particleSystems: [SCNParticleSystem]?`](https://developer.apple.com/documentation/scenekit/scnnode/particlesystems)
- [`var physicsField: SCNPhysicsField?`](https://developer.apple.com/documentation/scenekit/scnnode/physicsfield)
- [`func removeAllAudioPlayers()`](https://developer.apple.com/documentation/scenekit/scnnode/removeallaudioplayers())
- [`func removeAllParticleSystems()`](https://developer.apple.com/documentation/scenekit/scnnode/removeallparticlesystems())
- [`func removeAudioPlayer(SCNAudioPlayer)`](https://developer.apple.com/documentation/scenekit/scnnode/removeaudioplayer(_:))
- [`func removeParticleSystem(SCNParticleSystem)`](https://developer.apple.com/documentation/scenekit/scnnode/removeparticlesystem(_:))
- [`var rendererDelegate: (any SCNNodeRendererDelegate)?`](https://developer.apple.com/documentation/scenekit/scnnode/rendererdelegate)
- [`var skinner: SCNSkinner?`](https://developer.apple.com/documentation/scenekit/scnnode/skinner)
- [`SCNNodeRendererDelegate`](https://developer.apple.com/documentation/scenekit/scnnoderendererdelegate)
- [`func renderNode(SCNNode, renderer: SCNRenderer, arguments: [String : Any])`](https://developer.apple.com/documentation/scenekit/scnnoderendererdelegate/rendernode(_:renderer:arguments:))
- [`let SCNNormalTransform: String`](https://developer.apple.com/documentation/scenekit/scnnormaltransform)
- [`SCNParticleBirthDirection`](https://developer.apple.com/documentation/scenekit/scnparticlebirthdirection)
- [`case constant`](https://developer.apple.com/documentation/scenekit/scnparticlebirthdirection/constant)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnparticlebirthdirection/init(rawvalue:))
- [`case random`](https://developer.apple.com/documentation/scenekit/scnparticlebirthdirection/random)
- [`case surfaceNormal`](https://developer.apple.com/documentation/scenekit/scnparticlebirthdirection/surfacenormal)
- [`SCNParticleBirthLocation`](https://developer.apple.com/documentation/scenekit/scnparticlebirthlocation)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnparticlebirthlocation/init(rawvalue:))
- [`case surface`](https://developer.apple.com/documentation/scenekit/scnparticlebirthlocation/surface)
- [`case vertex`](https://developer.apple.com/documentation/scenekit/scnparticlebirthlocation/vertex)
- [`case volume`](https://developer.apple.com/documentation/scenekit/scnparticlebirthlocation/volume)
- [`SCNParticleBlendMode`](https://developer.apple.com/documentation/scenekit/scnparticleblendmode)
- [`case additive`](https://developer.apple.com/documentation/scenekit/scnparticleblendmode/additive)
- [`case alpha`](https://developer.apple.com/documentation/scenekit/scnparticleblendmode/alpha)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnparticleblendmode/init(rawvalue:))
- [`case multiply`](https://developer.apple.com/documentation/scenekit/scnparticleblendmode/multiply)
- [`case replace`](https://developer.apple.com/documentation/scenekit/scnparticleblendmode/replace)
- [`case screen`](https://developer.apple.com/documentation/scenekit/scnparticleblendmode/screen)
- [`case subtract`](https://developer.apple.com/documentation/scenekit/scnparticleblendmode/subtract)
- [`SCNParticleEvent`](https://developer.apple.com/documentation/scenekit/scnparticleevent)
- [`case birth`](https://developer.apple.com/documentation/scenekit/scnparticleevent/birth)
- [`case collision`](https://developer.apple.com/documentation/scenekit/scnparticleevent/collision)
- [`case death`](https://developer.apple.com/documentation/scenekit/scnparticleevent/death)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnparticleevent/init(rawvalue:))
- [`SCNParticleEventBlock`](https://developer.apple.com/documentation/scenekit/scnparticleeventblock)
- [`SCNParticleImageSequenceAnimationMode`](https://developer.apple.com/documentation/scenekit/scnparticleimagesequenceanimationmode)
- [`case autoReverse`](https://developer.apple.com/documentation/scenekit/scnparticleimagesequenceanimationmode/autoreverse)
- [`case clamp`](https://developer.apple.com/documentation/scenekit/scnparticleimagesequenceanimationmode/clamp)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnparticleimagesequenceanimationmode/init(rawvalue:))
- [`case `repeat``](https://developer.apple.com/documentation/scenekit/scnparticleimagesequenceanimationmode/repeat)
- [`SCNParticleInputMode`](https://developer.apple.com/documentation/scenekit/scnparticleinputmode)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnparticleinputmode/init(rawvalue:))
- [`case overDistance`](https://developer.apple.com/documentation/scenekit/scnparticleinputmode/overdistance)
- [`case overLife`](https://developer.apple.com/documentation/scenekit/scnparticleinputmode/overlife)
- [`case overOtherProperty`](https://developer.apple.com/documentation/scenekit/scnparticleinputmode/overotherproperty)
- [`SCNParticleModifierBlock`](https://developer.apple.com/documentation/scenekit/scnparticlemodifierblock)
- [`SCNParticleModifierStage`](https://developer.apple.com/documentation/scenekit/scnparticlemodifierstage)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnparticlemodifierstage/init(rawvalue:))
- [`case postCollision`](https://developer.apple.com/documentation/scenekit/scnparticlemodifierstage/postcollision)
- [`case postDynamics`](https://developer.apple.com/documentation/scenekit/scnparticlemodifierstage/postdynamics)
- [`case preCollision`](https://developer.apple.com/documentation/scenekit/scnparticlemodifierstage/precollision)
- [`case preDynamics`](https://developer.apple.com/documentation/scenekit/scnparticlemodifierstage/predynamics)
- [`SCNParticleOrientationMode`](https://developer.apple.com/documentation/scenekit/scnparticleorientationmode)
- [`case billboardScreenAligned`](https://developer.apple.com/documentation/scenekit/scnparticleorientationmode/billboardscreenaligned)
- [`case billboardViewAligned`](https://developer.apple.com/documentation/scenekit/scnparticleorientationmode/billboardviewaligned)
- [`case billboardYAligned`](https://developer.apple.com/documentation/scenekit/scnparticleorientationmode/billboardyaligned)
- [`case free`](https://developer.apple.com/documentation/scenekit/scnparticleorientationmode/free)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnparticleorientationmode/init(rawvalue:))
- [`SCNParticlePropertyController`](https://developer.apple.com/documentation/scenekit/scnparticlepropertycontroller)
- [`var animation: CAAnimation`](https://developer.apple.com/documentation/scenekit/scnparticlepropertycontroller/animation)
- [`convenience init(animation: CAAnimation)`](https://developer.apple.com/documentation/scenekit/scnparticlepropertycontroller/init(animation:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/scenekit/scnparticlepropertycontroller/init(coder:))
- [`var inputBias: CGFloat`](https://developer.apple.com/documentation/scenekit/scnparticlepropertycontroller/inputbias)
- [`var inputMode: SCNParticleInputMode`](https://developer.apple.com/documentation/scenekit/scnparticlepropertycontroller/inputmode)
- [`var inputOrigin: SCNNode?`](https://developer.apple.com/documentation/scenekit/scnparticlepropertycontroller/inputorigin)
- [`var inputProperty: SCNParticleSystem.ParticleProperty?`](https://developer.apple.com/documentation/scenekit/scnparticlepropertycontroller/inputproperty)
- [`var inputScale: CGFloat`](https://developer.apple.com/documentation/scenekit/scnparticlepropertycontroller/inputscale)
- [`SCNParticleSortingMode`](https://developer.apple.com/documentation/scenekit/scnparticlesortingmode)
- [`case distance`](https://developer.apple.com/documentation/scenekit/scnparticlesortingmode/distance)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnparticlesortingmode/init(rawvalue:))
- [`case none`](https://developer.apple.com/documentation/scenekit/scnparticlesortingmode/none)
- [`case oldestFirst`](https://developer.apple.com/documentation/scenekit/scnparticlesortingmode/oldestfirst)
- [`case projectedDepth`](https://developer.apple.com/documentation/scenekit/scnparticlesortingmode/projecteddepth)
- [`case youngestFirst`](https://developer.apple.com/documentation/scenekit/scnparticlesortingmode/youngestfirst)
- [`SCNParticleSystem`](https://developer.apple.com/documentation/scenekit/scnparticlesystem)
- [`var acceleration: SCNVector3`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/acceleration)
- [`func addModifier(forProperties: [SCNParticleSystem.ParticleProperty], at: SCNParticleModifierStage, modifier: SCNParticleModifierBlock)`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/addmodifier(forproperties:at:modifier:))
- [`var birthDirection: SCNParticleBirthDirection`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/birthdirection)
- [`var birthLocation: SCNParticleBirthLocation`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/birthlocation)
- [`var birthRate: CGFloat`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/birthrate)
- [`var birthRateVariation: CGFloat`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/birthratevariation)
- [`var blendMode: SCNParticleBlendMode`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/blendmode)
- [`var colliderNodes: [SCNNode]?`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/collidernodes)
- [`var dampingFactor: CGFloat`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/dampingfactor)
- [`var emissionDuration: CGFloat`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/emissionduration)
- [`var emissionDurationVariation: CGFloat`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/emissiondurationvariation)
- [`var emitterShape: SCNGeometry?`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/emittershape)
- [`var emittingDirection: SCNVector3`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/emittingdirection)
- [`var fresnelExponent: CGFloat`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/fresnelexponent)
- [`func handle(SCNParticleEvent, forProperties: [SCNParticleSystem.ParticleProperty], handler: SCNParticleEventBlock)`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/handle(_:forproperties:handler:))
- [`var idleDuration: CGFloat`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/idleduration)
- [`var idleDurationVariation: CGFloat`](https://developer.apple.com/documentation/scenekit/scnparticlesystem/idledurationvariation)
- … and 299 more (`isim/data/api-coverage.json.gz`)

</details>
<!-- /generated:missing -->
