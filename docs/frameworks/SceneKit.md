# SceneKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 11.2% of Apple's iOS API (186 of 1668, exact) · **Rows:** 5: 1 ✅ 3 🟡 1 ❌ · **iOS:** 8.0+
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
1482 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`SceneView`](https://developer.apple.com/documentation/scenekit/sceneview)
- [`init(scene: SCNScene?, pointOfView: SCNNode?, options: SceneView.Options, preferredFramesPerSecond: Int, antialiasingMode: SCNAntialiasingMode, delegate: (any SCNSceneRendererDelegate)?, technique: SCNTechnique?)`](https://developer.apple.com/documentation/scenekit/sceneview/init(scene:pointofview:options:preferredframespersecond:antialiasingmode:delegate:technique:))
- [`SceneView.Options`](https://developer.apple.com/documentation/scenekit/sceneview/options)
- [`static let allowsCameraControl: SceneView.Options`](https://developer.apple.com/documentation/scenekit/sceneview/options/allowscameracontrol)
- [`static let autoenablesDefaultLighting: SceneView.Options`](https://developer.apple.com/documentation/scenekit/sceneview/options/autoenablesdefaultlighting)
- [`static let jitteringEnabled: SceneView.Options`](https://developer.apple.com/documentation/scenekit/sceneview/options/jitteringenabled)
- [`static let rendersContinuously: SceneView.Options`](https://developer.apple.com/documentation/scenekit/sceneview/options/renderscontinuously)
- [`static let temporalAntialiasingEnabled: SceneView.Options`](https://developer.apple.com/documentation/scenekit/sceneview/options/temporalantialiasingenabled)
- [`var SCN_ENABLE_METAL: Int32`](https://developer.apple.com/documentation/scenekit/scn_enable_metal)
- [`var SCN_ENABLE_METAL: Int32`](https://developer.apple.com/documentation/scenekit/scn_enable_metal)
- [`var SCN_ENABLE_OPENGL: Int32`](https://developer.apple.com/documentation/scenekit/scn_enable_opengl)
- [`var SCN_ENABLE_OPENGL: Int32`](https://developer.apple.com/documentation/scenekit/scn_enable_opengl)
- [`SCNAccelerationConstraint`](https://developer.apple.com/documentation/scenekit/scnaccelerationconstraint)
- [`var damping: CGFloat`](https://developer.apple.com/documentation/scenekit/scnaccelerationconstraint/damping)
- [`var decelerationDistance: CGFloat`](https://developer.apple.com/documentation/scenekit/scnaccelerationconstraint/decelerationdistance)
- [`var maximumLinearAcceleration: CGFloat`](https://developer.apple.com/documentation/scenekit/scnaccelerationconstraint/maximumlinearacceleration)
- [`var maximumLinearVelocity: CGFloat`](https://developer.apple.com/documentation/scenekit/scnaccelerationconstraint/maximumlinearvelocity)
- [`SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction)
- [`class func customAction(duration: TimeInterval, action: (SCNNode, CGFloat) -> Void) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/customaction(duration:action:))
- [`var duration: TimeInterval`](https://developer.apple.com/documentation/scenekit/scnaction/duration)
- [`class func fadeIn(duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/fadein(duration:))
- [`class func fadeOpacity(by: CGFloat, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/fadeopacity(by:duration:))
- [`class func fadeOpacity(to: CGFloat, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/fadeopacity(to:duration:))
- [`class func fadeOut(duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/fadeout(duration:))
- [`class func group([SCNAction]) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/group(_:))
- [`class func hide() -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/hide())
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/scenekit/scnaction/init(coder:))
- [`class func javaScriptAction(withScript: String, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/javascriptaction(withscript:duration:))
- [`class func move(by: SCNVector3, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/move(by:duration:))
- [`class func move(to: SCNVector3, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/move(to:duration:))
- [`class func moveBy(x: CGFloat, y: CGFloat, z: CGFloat, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/moveby(x:y:z:duration:))
- [`class func playAudio(SCNAudioSource, waitForCompletion: Bool) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/playaudio(_:waitforcompletion:))
- [`class func removeFromParentNode() -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/removefromparentnode())
- [`class func `repeat`(SCNAction, count: Int) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/repeat(_:count:))
- [`class func repeatForever(SCNAction) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/repeatforever(_:))
- [`func reversed() -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/reversed())
- [`class func rotate(by: CGFloat, around: SCNVector3, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/rotate(by:around:duration:))
- [`class func rotate(toAxisAngle: SCNVector4, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/rotate(toaxisangle:duration:))
- [`class func rotateBy(x: CGFloat, y: CGFloat, z: CGFloat, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/rotateby(x:y:z:duration:))
- [`class func rotateTo(x: CGFloat, y: CGFloat, z: CGFloat, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/rotateto(x:y:z:duration:))
- [`class func rotateTo(x: CGFloat, y: CGFloat, z: CGFloat, duration: TimeInterval, usesShortestUnitArc: Bool) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/rotateto(x:y:z:duration:usesshortestunitarc:))
- [`class func run((SCNNode) -> Void) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/run(_:))
- [`class func run((SCNNode) -> Void, queue: dispatch_queue_t) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/run(_:queue:))
- [`class func scale(by: CGFloat, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/scale(by:duration:))
- [`class func scale(to: CGFloat, duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/scale(to:duration:))
- [`class func sequence([SCNAction]) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/sequence(_:))
- [`var speed: CGFloat`](https://developer.apple.com/documentation/scenekit/scnaction/speed)
- [`var timingFunction: SCNActionTimingFunction?`](https://developer.apple.com/documentation/scenekit/scnaction/timingfunction)
- [`var timingMode: SCNActionTimingMode`](https://developer.apple.com/documentation/scenekit/scnaction/timingmode)
- [`class func unhide() -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/unhide())
- [`class func wait(duration: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/wait(duration:))
- [`class func wait(duration: TimeInterval, withRange: TimeInterval) -> SCNAction`](https://developer.apple.com/documentation/scenekit/scnaction/wait(duration:withrange:))
- [`SCNActionable`](https://developer.apple.com/documentation/scenekit/scnactionable)
- [`func action(forKey: String) -> SCNAction?`](https://developer.apple.com/documentation/scenekit/scnactionable/action(forkey:))
- [`var actionKeys: [String]`](https://developer.apple.com/documentation/scenekit/scnactionable/actionkeys)
- [`var hasActions: Bool`](https://developer.apple.com/documentation/scenekit/scnactionable/hasactions)
- [`func removeAction(forKey: String)`](https://developer.apple.com/documentation/scenekit/scnactionable/removeaction(forkey:))
- [`func removeAllActions()`](https://developer.apple.com/documentation/scenekit/scnactionable/removeallactions())
- [`func runAction(SCNAction)`](https://developer.apple.com/documentation/scenekit/scnactionable/runaction(_:))
- [`func runAction(SCNAction, completionHandler: (() -> Void)?)`](https://developer.apple.com/documentation/scenekit/scnactionable/runaction(_:completionhandler:))
- [`func runAction(SCNAction, forKey: String?)`](https://developer.apple.com/documentation/scenekit/scnactionable/runaction(_:forkey:))
- [`func runAction(SCNAction, forKey: String?, completionHandler: (() -> Void)?)`](https://developer.apple.com/documentation/scenekit/scnactionable/runaction(_:forkey:completionhandler:))
- [`SCNActionTimingFunction`](https://developer.apple.com/documentation/scenekit/scnactiontimingfunction)
- [`SCNActionTimingMode`](https://developer.apple.com/documentation/scenekit/scnactiontimingmode)
- [`case easeIn`](https://developer.apple.com/documentation/scenekit/scnactiontimingmode/easein)
- [`case easeInEaseOut`](https://developer.apple.com/documentation/scenekit/scnactiontimingmode/easeineaseout)
- [`case easeOut`](https://developer.apple.com/documentation/scenekit/scnactiontimingmode/easeout)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnactiontimingmode/init(rawvalue:))
- [`case linear`](https://developer.apple.com/documentation/scenekit/scnactiontimingmode/linear)
- [`SCNAnimatable`](https://developer.apple.com/documentation/scenekit/scnanimatable)
- [`func addAnimation(any SCNAnimationProtocol, forKey: String?)`](https://developer.apple.com/documentation/scenekit/scnanimatable/addanimation(_:forkey:))
- [`func addAnimationPlayer(SCNAnimationPlayer, forKey: String?)`](https://developer.apple.com/documentation/scenekit/scnanimatable/addanimationplayer(_:forkey:))
- [`func animation(forKey: String) -> CAAnimation?`](https://developer.apple.com/documentation/scenekit/scnanimatable/animation(forkey:))
- [`var animationKeys: [String]`](https://developer.apple.com/documentation/scenekit/scnanimatable/animationkeys)
- [`func animationPlayer(forKey: String) -> SCNAnimationPlayer?`](https://developer.apple.com/documentation/scenekit/scnanimatable/animationplayer(forkey:))
- [`func isAnimationPaused(forKey: String) -> Bool`](https://developer.apple.com/documentation/scenekit/scnanimatable/isanimationpaused(forkey:))
- [`func pauseAnimation(forKey: String)`](https://developer.apple.com/documentation/scenekit/scnanimatable/pauseanimation(forkey:))
- [`func removeAllAnimations()`](https://developer.apple.com/documentation/scenekit/scnanimatable/removeallanimations())
- [`func removeAllAnimations(withBlendOutDuration: CGFloat)`](https://developer.apple.com/documentation/scenekit/scnanimatable/removeallanimations(withblendoutduration:))
- [`func removeAnimation(forKey: String)`](https://developer.apple.com/documentation/scenekit/scnanimatable/removeanimation(forkey:))
- [`func removeAnimation(forKey: String, blendOutDuration: CGFloat)`](https://developer.apple.com/documentation/scenekit/scnanimatable/removeanimation(forkey:blendoutduration:))
- [`func removeAnimation(forKey: String, fadeOutDuration: CGFloat)`](https://developer.apple.com/documentation/scenekit/scnanimatable/removeanimation(forkey:fadeoutduration:))
- [`func resumeAnimation(forKey: String)`](https://developer.apple.com/documentation/scenekit/scnanimatable/resumeanimation(forkey:))
- [`func setAnimationSpeed(CGFloat, forKey: String)`](https://developer.apple.com/documentation/scenekit/scnanimatable/setanimationspeed(_:forkey:))
- [`SCNAnimation`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class)
- [`SCNAnimation`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class)
- [`var animationDidStart: SCNAnimationDidStartBlock?`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/animationdidstart)
- [`var animationDidStart: SCNAnimationDidStartBlock?`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/animationdidstart)
- [`var animationDidStop: SCNAnimationDidStopBlock?`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/animationdidstop)
- [`var animationDidStop: SCNAnimationDidStopBlock?`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/animationdidstop)
- [`var animationEvents: [SCNAnimationEvent]?`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/animationevents)
- [`var animationEvents: [SCNAnimationEvent]?`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/animationevents)
- [`var autoreverses: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/autoreverses)
- [`var autoreverses: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/autoreverses)
- [`var blendInDuration: TimeInterval`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/blendinduration)
- [`var blendInDuration: TimeInterval`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/blendinduration)
- [`var blendOutDuration: TimeInterval`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/blendoutduration)
- [`var blendOutDuration: TimeInterval`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/blendoutduration)
- [`var duration: TimeInterval`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/duration)
- [`var duration: TimeInterval`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/duration)
- [`var fillsBackward: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/fillsbackward)
- [`var fillsBackward: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/fillsbackward)
- [`var fillsForward: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/fillsforward)
- [`var fillsForward: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/fillsforward)
- [`init(CAAnimation: CAAnimation)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(caanimation:)-3sfjw)
- [`init(CAAnimation: CAAnimation)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(caanimation:)-3sfjw)
- [`init(caAnimation: CAAnimation)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(caanimation:)-4t0rw)
- [`init(caAnimation: CAAnimation)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(caanimation:)-4t0rw)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(coder:))
- [`init(contentsOf: URL)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(contentsof:))
- [`init(contentsOf: URL)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(contentsof:))
- [`init(contentsOfURL: URL)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(contentsofurl:))
- [`init(contentsOfURL: URL)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(contentsofurl:))
- [`init(named: String)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(named:))
- [`init(named: String)`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/init(named:))
- [`var isAdditive: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/isadditive)
- [`var isAdditive: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/isadditive)
- [`var isAppliedOnCompletion: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/isappliedoncompletion)
- [`var isAppliedOnCompletion: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/isappliedoncompletion)
- [`var isCumulative: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/iscumulative)
- [`var isCumulative: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/iscumulative)
- [`var isRemovedOnCompletion: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/isremovedoncompletion)
- [`var isRemovedOnCompletion: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/isremovedoncompletion)
- [`var keyPath: String?`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/keypath)
- [`var keyPath: String?`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/keypath)
- [`var repeatCount: CGFloat`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/repeatcount)
- [`var repeatCount: CGFloat`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/repeatcount)
- [`var startDelay: TimeInterval`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/startdelay)
- [`var startDelay: TimeInterval`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/startdelay)
- [`var timeOffset: TimeInterval`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/timeoffset)
- [`var timeOffset: TimeInterval`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/timeoffset)
- [`var timingFunction: SCNTimingFunction`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/timingfunction)
- [`var timingFunction: SCNTimingFunction`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/timingfunction)
- [`var usesSceneTimeBase: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/usesscenetimebase)
- [`var usesSceneTimeBase: Bool`](https://developer.apple.com/documentation/scenekit/scnanimation-swift.class/usesscenetimebase)
- [`SCNAnimationDidStartBlock`](https://developer.apple.com/documentation/scenekit/scnanimationdidstartblock)
- [`SCNAnimationDidStartBlock`](https://developer.apple.com/documentation/scenekit/scnanimationdidstartblock)
- [`SCNAnimationDidStopBlock`](https://developer.apple.com/documentation/scenekit/scnanimationdidstopblock)
- [`SCNAnimationDidStopBlock`](https://developer.apple.com/documentation/scenekit/scnanimationdidstopblock)
- [`SCNAnimationEvent`](https://developer.apple.com/documentation/scenekit/scnanimationevent)
- [`convenience init(keyTime: CGFloat, block: SCNAnimationEventBlock)`](https://developer.apple.com/documentation/scenekit/scnanimationevent/init(keytime:block:))
- [`SCNAnimationEventBlock`](https://developer.apple.com/documentation/scenekit/scnanimationeventblock)
- [`SCNAnimationPlayer`](https://developer.apple.com/documentation/scenekit/scnanimationplayer)
- [`var animation: SCNAnimation`](https://developer.apple.com/documentation/scenekit/scnanimationplayer/animation)
- [`var blendFactor: CGFloat`](https://developer.apple.com/documentation/scenekit/scnanimationplayer/blendfactor)
- [`init(animation: SCNAnimation)`](https://developer.apple.com/documentation/scenekit/scnanimationplayer/init(animation:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/scenekit/scnanimationplayer/init(coder:))
- [`var paused: Bool`](https://developer.apple.com/documentation/scenekit/scnanimationplayer/paused)
- [`func play()`](https://developer.apple.com/documentation/scenekit/scnanimationplayer/play())
- [`var speed: CGFloat`](https://developer.apple.com/documentation/scenekit/scnanimationplayer/speed)
- [`func stop()`](https://developer.apple.com/documentation/scenekit/scnanimationplayer/stop())
- [`func stop(withBlendOutDuration: TimeInterval)`](https://developer.apple.com/documentation/scenekit/scnanimationplayer/stop(withblendoutduration:))
- [`SCNAnimationProtocol`](https://developer.apple.com/documentation/scenekit/scnanimationprotocol)
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
- [`SCNBillboardAxis`](https://developer.apple.com/documentation/scenekit/scnbillboardaxis)
- [`static var all: SCNBillboardAxis`](https://developer.apple.com/documentation/scenekit/scnbillboardaxis/all)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/scenekit/scnbillboardaxis/init(rawvalue:))
- [`static var X: SCNBillboardAxis`](https://developer.apple.com/documentation/scenekit/scnbillboardaxis/x)
- [`static var Y: SCNBillboardAxis`](https://developer.apple.com/documentation/scenekit/scnbillboardaxis/y)
- [`static var Z: SCNBillboardAxis`](https://developer.apple.com/documentation/scenekit/scnbillboardaxis/z)
- [`SCNBillboardConstraint`](https://developer.apple.com/documentation/scenekit/scnbillboardconstraint)
- [`var freeAxes: SCNBillboardAxis`](https://developer.apple.com/documentation/scenekit/scnbillboardconstraint/freeaxes)
- [`SCNBindingBlock`](https://developer.apple.com/documentation/scenekit/scnbindingblock)
- [`SCNBlendMode`](https://developer.apple.com/documentation/scenekit/scnblendmode)
- [`case add`](https://developer.apple.com/documentation/scenekit/scnblendmode/add)
- [`case alpha`](https://developer.apple.com/documentation/scenekit/scnblendmode/alpha)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnblendmode/init(rawvalue:))
- [`case max`](https://developer.apple.com/documentation/scenekit/scnblendmode/max)
- [`case multiply`](https://developer.apple.com/documentation/scenekit/scnblendmode/multiply)
- [`case replace`](https://developer.apple.com/documentation/scenekit/scnblendmode/replace)
- [`case screen`](https://developer.apple.com/documentation/scenekit/scnblendmode/screen)
- [`case subtract`](https://developer.apple.com/documentation/scenekit/scnblendmode/subtract)
- [`SCNBoundingVolume`](https://developer.apple.com/documentation/scenekit/scnboundingvolume)
- [`SCNBoundingVolume`](https://developer.apple.com/documentation/scenekit/scnboundingvolume)
- [`var boundingBox: (min: SCNVector3, max: SCNVector3)`](https://developer.apple.com/documentation/scenekit/scnboundingvolume/boundingbox)
- [`var boundingBox: (min: SCNVector3, max: SCNVector3)`](https://developer.apple.com/documentation/scenekit/scnboundingvolume/boundingbox)
- [`var boundingSphere: (center: SCNVector3, radius: Float)`](https://developer.apple.com/documentation/scenekit/scnboundingvolume/boundingsphere)
- [`var boundingSphere: (center: SCNVector3, radius: Float)`](https://developer.apple.com/documentation/scenekit/scnboundingvolume/boundingsphere)
- [`SCNBox`](https://developer.apple.com/documentation/scenekit/scnbox)
- [`var chamferRadius: CGFloat`](https://developer.apple.com/documentation/scenekit/scnbox/chamferradius)
- [`var chamferSegmentCount: Int`](https://developer.apple.com/documentation/scenekit/scnbox/chamfersegmentcount)
- [`var height: CGFloat`](https://developer.apple.com/documentation/scenekit/scnbox/height)
- [`var heightSegmentCount: Int`](https://developer.apple.com/documentation/scenekit/scnbox/heightsegmentcount)
- [`convenience init(width: CGFloat, height: CGFloat, length: CGFloat, chamferRadius: CGFloat)`](https://developer.apple.com/documentation/scenekit/scnbox/init(width:height:length:chamferradius:))
- [`var length: CGFloat`](https://developer.apple.com/documentation/scenekit/scnbox/length)
- [`var lengthSegmentCount: Int`](https://developer.apple.com/documentation/scenekit/scnbox/lengthsegmentcount)
- [`var width: CGFloat`](https://developer.apple.com/documentation/scenekit/scnbox/width)
- [`var widthSegmentCount: Int`](https://developer.apple.com/documentation/scenekit/scnbox/widthsegmentcount)
- [`SCNBufferBindingBlock`](https://developer.apple.com/documentation/scenekit/scnbufferbindingblock)
- [`SCNBufferFrequency`](https://developer.apple.com/documentation/scenekit/scnbufferfrequency)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/scenekit/scnbufferfrequency/init(rawvalue:))
- [`case perFrame`](https://developer.apple.com/documentation/scenekit/scnbufferfrequency/perframe)
- [`case perNode`](https://developer.apple.com/documentation/scenekit/scnbufferfrequency/pernode)
- [`case perShadable`](https://developer.apple.com/documentation/scenekit/scnbufferfrequency/pershadable)
- [`SCNBufferStream`](https://developer.apple.com/documentation/scenekit/scnbufferstream)
- [`func writeBytes(UnsafeRawPointer, count: Int)`](https://developer.apple.com/documentation/scenekit/scnbufferstream/writebytes(_:count:))
- [`SCNCamera`](https://developer.apple.com/documentation/scenekit/scncamera)
- [`var aperture: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/aperture)
- [`var apertureBladeCount: Int`](https://developer.apple.com/documentation/scenekit/scncamera/aperturebladecount)
- [`var automaticallyAdjustsZRange: Bool`](https://developer.apple.com/documentation/scenekit/scncamera/automaticallyadjustszrange)
- [`var averageGray: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/averagegray)
- [`var bloomBlurRadius: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/bloomblurradius)
- [`var bloomIntensity: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/bloomintensity)
- [`var bloomIterationCount: Int`](https://developer.apple.com/documentation/scenekit/scncamera/bloomiterationcount)
- [`var bloomIterationSpread: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/bloomiterationspread)
- [`var bloomThreshold: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/bloomthreshold)
- [`var categoryBitMask: Int`](https://developer.apple.com/documentation/scenekit/scncamera/categorybitmask)
- [`var colorFringeIntensity: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/colorfringeintensity)
- [`var colorFringeStrength: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/colorfringestrength)
- [`var colorGrading: SCNMaterialProperty`](https://developer.apple.com/documentation/scenekit/scncamera/colorgrading)
- [`var contrast: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/contrast)
- [`var exposureAdaptationBrighteningSpeedFactor: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/exposureadaptationbrighteningspeedfactor)
- [`var exposureAdaptationDarkeningSpeedFactor: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/exposureadaptationdarkeningspeedfactor)
- [`var exposureOffset: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/exposureoffset)
- [`var fieldOfView: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/fieldofview)
- [`var focalBlurRadius: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/focalblurradius)
- [`var focalBlurSampleCount: Int`](https://developer.apple.com/documentation/scenekit/scncamera/focalblursamplecount)
- [`var focalDistance: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/focaldistance)
- [`var focalLength: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/focallength)
- [`var focalSize: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/focalsize)
- [`var focusDistance: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/focusdistance)
- [`var fStop: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/fstop)
- [`var grainIntensity: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/grainintensity)
- [`var grainIsColored: Bool`](https://developer.apple.com/documentation/scenekit/scncamera/grainiscolored)
- [`var grainScale: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/grainscale)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/scenekit/scncamera/init(coder:))
- [`var maximumExposure: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/maximumexposure)
- [`var minimumExposure: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/minimumexposure)
- [`var motionBlurIntensity: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/motionblurintensity)
- [`var name: String?`](https://developer.apple.com/documentation/scenekit/scncamera/name)
- [`var orthographicScale: Double`](https://developer.apple.com/documentation/scenekit/scncamera/orthographicscale)
- [`var projectionDirection: SCNCameraProjectionDirection`](https://developer.apple.com/documentation/scenekit/scncamera/projectiondirection)
- [`var projectionTransform: SCNMatrix4`](https://developer.apple.com/documentation/scenekit/scncamera/projectiontransform)
- [`func projectionTransform(withViewportSize: CGSize) -> SCNMatrix4`](https://developer.apple.com/documentation/scenekit/scncamera/projectiontransform(withviewportsize:))
- [`var saturation: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/saturation)
- [`var screenSpaceAmbientOcclusionBias: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/screenspaceambientocclusionbias)
- [`var screenSpaceAmbientOcclusionDepthThreshold: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/screenspaceambientocclusiondepththreshold)
- [`var screenSpaceAmbientOcclusionIntensity: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/screenspaceambientocclusionintensity)
- [`var screenSpaceAmbientOcclusionNormalThreshold: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/screenspaceambientocclusionnormalthreshold)
- [`var screenSpaceAmbientOcclusionRadius: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/screenspaceambientocclusionradius)
- [`var sensorHeight: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/sensorheight)
- [`var usesOrthographicProjection: Bool`](https://developer.apple.com/documentation/scenekit/scncamera/usesorthographicprojection)
- [`var vignettingIntensity: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/vignettingintensity)
- [`var vignettingPower: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/vignettingpower)
- [`var wantsDepthOfField: Bool`](https://developer.apple.com/documentation/scenekit/scncamera/wantsdepthoffield)
- [`var wantsExposureAdaptation: Bool`](https://developer.apple.com/documentation/scenekit/scncamera/wantsexposureadaptation)
- [`var wantsHDR: Bool`](https://developer.apple.com/documentation/scenekit/scncamera/wantshdr)
- [`var whiteBalanceTemperature: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/whitebalancetemperature)
- [`var whiteBalanceTint: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/whitebalancetint)
- [`var whitePoint: CGFloat`](https://developer.apple.com/documentation/scenekit/scncamera/whitepoint)
- [`var xFov: Double`](https://developer.apple.com/documentation/scenekit/scncamera/xfov)
- [`var yFov: Double`](https://developer.apple.com/documentation/scenekit/scncamera/yfov)
- [`var zFar: Double`](https://developer.apple.com/documentation/scenekit/scncamera/zfar)
- [`var zNear: Double`](https://developer.apple.com/documentation/scenekit/scncamera/znear)
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
- … and 1182 more (`isim/data/api-coverage.json.gz`)

</details>
<!-- /generated:missing -->
